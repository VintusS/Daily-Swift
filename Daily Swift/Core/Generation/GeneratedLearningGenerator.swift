import Foundation

enum GeneratedLearningFailure: Error, Equatable, Sendable {
    case invalidTopic
    case topicTooLong
    case insufficientEvidence
    case unavailable(LanguageModelUnavailability)
    case sourceUnavailable
    case contextTooLarge
    case safetyGuardrail
    case rejected([GeneratedLearningValidationCategory])
    case storageUnavailable
    case generationFailed
}

protocol GeneratedLearningGenerating: Sendable {
    func availability() async -> LanguageModelAvailability
    func restore() async throws -> [GeneratedLearningArtifact]
    func generate(
        topic: String,
        sourceIDs: Set<UUID>
    ) async throws -> GeneratedLearningArtifact
    func commitArtifact(
        _ artifact: GeneratedLearningArtifact
    ) async throws
    func deleteArtifacts(referencing sourceID: UUID) async throws
    func abortSourceDeletion(id sourceID: UUID) async
}

extension GeneratedLearningGenerating {
    func commitArtifact(
        _ artifact: GeneratedLearningArtifact
    ) async throws {}

    func abortSourceDeletion(id sourceID: UUID) async {}
}

actor GeneratedLearningGenerator: GeneratedLearningGenerating {
    static let promptVersion = GeneratedLearningVersion.prompt
    static let candidateSchemaVersion =
        GeneratedLearningVersion.candidateSchema

    private let retriever: any SourceRetrieving
    private let sourceLibrary: any SourceLibraryServing
    private let provider: any LanguageModelProvider
    private let store: any GeneratedLearningStoring
    private let validator: GeneratedLearningValidator
    private let now: @Sendable () -> Date
    private let makeArtifactID: @Sendable () -> UUID
    private var isProviderRequestInFlight = false
    private var invalidatedSourceIDs: Set<UUID> = []

    init(
        retriever: any SourceRetrieving,
        sourceLibrary: any SourceLibraryServing,
        provider: any LanguageModelProvider,
        store: any GeneratedLearningStoring,
        validator: GeneratedLearningValidator =
            GeneratedLearningValidator(),
        now: @escaping @Sendable () -> Date = { .now },
        makeArtifactID: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.retriever = retriever
        self.sourceLibrary = sourceLibrary
        self.provider = provider
        self.store = store
        self.validator = validator
        self.now = now
        self.makeArtifactID = makeArtifactID
    }

    func availability() async -> LanguageModelAvailability {
        await provider.availability()
    }

    func restore() async throws -> [GeneratedLearningArtifact] {
        let stored: [GeneratedLearningArtifact]
        do {
            stored = try await store.restore()
        } catch {
            throw GeneratedLearningFailure.storageUnavailable
        }

        var validArtifacts: [GeneratedLearningArtifact] = []
        validArtifacts.reserveCapacity(stored.count)
        for artifact in stored {
            guard !Task.isCancelled else {
                throw CancellationError()
            }
            do {
                try validator.validate(artifact)
                try ensureSourcesAreActive(for: artifact)
                let resolvedSources = try await resolveCurrentSources(
                    for: artifact
                )
                try validator.validateSourceOverlap(
                    in: artifact,
                    against: resolvedSources.map(\.excerpt)
                )
                try ensureSourcesAreActive(for: artifact)
                validArtifacts.append(artifact)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue
            }
        }
        return validArtifacts
    }

    func generate(
        topic: String,
        sourceIDs: Set<UUID> = []
    ) async throws -> GeneratedLearningArtifact {
        let cleanTopic = topic.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !cleanTopic.isEmpty else {
            throw GeneratedLearningFailure.invalidTopic
        }
        guard cleanTopic.count
            <= GeneratedLearningValidationLimits.maximumTopicCharacters else {
            throw GeneratedLearningFailure.topicTooLong
        }

        let availability = await provider.availability()
        guard case .available = availability else {
            if case let .unavailable(reason) = availability {
                throw GeneratedLearningFailure.unavailable(reason)
            }
            throw GeneratedLearningFailure.generationFailed
        }
        try Task.checkCancellation()

        let matches: [SourceRetrievalMatch]
        do {
            matches = try await retriever.search(
                SourceRetrievalRequest(
                    query: cleanTopic,
                    sourceIDs: sourceIDs,
                    resultLimit:
                        GeneratedLearningValidationLimits.maximumSourceCards
                )
            )
        } catch let failure {
            switch failure {
            case .cancelled:
                throw CancellationError()
            case .emptyQuery, .queryTooLong, .invalidResultLimit:
                throw GeneratedLearningFailure.invalidTopic
            case .sourceUnavailable, .indexUnavailable:
                throw GeneratedLearningFailure.sourceUnavailable
            }
        }
        guard !matches.isEmpty else {
            throw GeneratedLearningFailure.insufficientEvidence
        }
        guard matches.allSatisfy(\.document.localOnly) else {
            throw GeneratedLearningFailure.sourceUnavailable
        }
        guard Set(matches.map(\.document.id))
            .isDisjoint(with: invalidatedSourceIDs) else {
            throw GeneratedLearningFailure.sourceUnavailable
        }
        try Task.checkCancellation()

        let cards = sourceCards(from: matches)
        let request = LanguageModelGenerationRequest(
            topic: cleanTopic,
            swiftVersion: "6",
            minimumIOSVersion: "26.0",
            promptVersion: Self.promptVersion,
            candidateSchemaVersion: Self.candidateSchemaVersion,
            artifactSchemaVersion:
                GeneratedLearningArtifact.currentSchemaVersion,
            sourceCards: cards
        )
        do {
            try validator.validate(request)
        } catch let failure as GeneratedLearningValidationError {
            throw GeneratedLearningFailure.rejected(failure.categories)
        }

        let candidate: LanguageModelGeneratedCandidate
        do {
            candidate = try await requestCandidate(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as LanguageModelProviderFailure {
            switch failure {
            case .contextWindowExceeded:
                throw GeneratedLearningFailure.contextTooLarge
            case .safetyGuardrail:
                throw GeneratedLearningFailure.safetyGuardrail
            case .invalidResponse:
                throw GeneratedLearningFailure.rejected([
                    .requiredFieldMissing,
                ])
            case .requestFailed, .concurrentRequest, .unknown:
                throw GeneratedLearningFailure.generationFailed
            }
        } catch {
            throw GeneratedLearningFailure.generationFailed
        }
        try Task.checkCancellation()

        do {
            try validator.validate(candidate, for: request)
        } catch let failure as GeneratedLearningValidationError {
            throw GeneratedLearningFailure.rejected(failure.categories)
        }

        let artifact = makeArtifact(
            topic: cleanTopic,
            request: request,
            candidate: candidate
        )
        do {
            try validator.validate(artifact)
        } catch let failure as GeneratedLearningValidationError {
            throw GeneratedLearningFailure.rejected(failure.categories)
        }

        do {
            try ensureSourcesAreActive(for: artifact)
            _ = try await resolveCurrentSources(for: artifact)
            try Task.checkCancellation()
            try ensureSourcesAreActive(for: artifact)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw GeneratedLearningFailure.sourceUnavailable
        }

        return artifact
    }

    func commitArtifact(
        _ artifact: GeneratedLearningArtifact
    ) async throws {
        do {
            try Task.checkCancellation()
            try validator.validate(artifact)
            try ensureSourcesAreActive(for: artifact)
            let resolvedSources = try await resolveCurrentSources(
                for: artifact
            )
            try validator.validateSourceOverlap(
                in: artifact,
                against: resolvedSources.map(\.excerpt)
            )
            try Task.checkCancellation()
            try ensureSourcesAreActive(for: artifact)
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as GeneratedLearningValidationError {
            throw GeneratedLearningFailure.rejected(failure.categories)
        } catch {
            throw GeneratedLearningFailure.sourceUnavailable
        }

        do {
            try Task.checkCancellation()
            try ensureSourcesAreActive(for: artifact)
            try await store.save(artifact)
        } catch is CancellationError {
            try await rollbackArtifact(artifact.id)
            throw CancellationError()
        } catch {
            try? await store.deleteArtifact(id: artifact.id)
            throw GeneratedLearningFailure.storageUnavailable
        }

        do {
            try Task.checkCancellation()
            try ensureSourcesAreActive(for: artifact)
            _ = try await resolveCurrentSources(for: artifact)
            try Task.checkCancellation()
            try ensureSourcesAreActive(for: artifact)
        } catch is CancellationError {
            try await rollbackArtifact(artifact.id)
            throw CancellationError()
        } catch {
            try await rollbackArtifact(artifact.id)
            throw GeneratedLearningFailure.sourceUnavailable
        }
    }

    private func requestCandidate(
        for request: LanguageModelGenerationRequest
    ) async throws -> LanguageModelGeneratedCandidate {
        guard !isProviderRequestInFlight else {
            throw LanguageModelProviderFailure.concurrentRequest
        }
        isProviderRequestInFlight = true
        defer {
            isProviderRequestInFlight = false
        }
        return try await provider.generate(request)
    }

    func deleteArtifacts(referencing sourceID: UUID) async throws {
        invalidatedSourceIDs.insert(sourceID)
        do {
            try await store.deleteArtifacts(referencing: sourceID)
        } catch {
            invalidatedSourceIDs.remove(sourceID)
            throw GeneratedLearningFailure.storageUnavailable
        }
    }

    func abortSourceDeletion(id sourceID: UUID) async {
        invalidatedSourceIDs.remove(sourceID)
    }

    private func sourceCards(
        from matches: [SourceRetrievalMatch]
    ) -> [LanguageModelSourceCard] {
        Array(
            matches.prefix(
                GeneratedLearningValidationLimits.maximumSourceCards
            )
        )
        .enumerated()
        .map { index, match in
            LanguageModelSourceCard(
                id: "source-card-\(index + 1)",
                documentTitle: match.document.title,
                locationLabel: locationLabel(
                    citation: match.citation
                ),
                rightsStatus: match.document.rightsStatus,
                contentHash: match.citation.contentHash,
                text: match.excerpt,
                citation: match.citation
            )
        }
    }

    private func locationLabel(citation: SourceCitation) -> String {
        [
            citation.headingLabel,
            citation.location.pageLabel,
            citation.location.lineLabel,
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
    }

    private func makeArtifact(
        topic: String,
        request: LanguageModelGenerationRequest,
        candidate: LanguageModelGeneratedCandidate
    ) -> GeneratedLearningArtifact {
        GeneratedLearningArtifact(
            id: makeArtifactID(),
            schemaVersion:
                GeneratedLearningArtifact.currentSchemaVersion,
            topic: topic,
            promptVersion: request.promptVersion,
            candidateSchemaVersion: request.candidateSchemaVersion,
            providerRuntimeLabel: candidate.providerRuntimeLabel,
            sourceSetHash:
                GeneratedLearningValidator.sourceSetHash(
                    for: request.sourceCards
                ),
            createdAt: now(),
            trust: .experimentalUserMaterial,
            sourceReferences: request.sourceCards.map {
                GeneratedLearningSourceReference(
                    id: $0.id,
                    documentTitle: $0.documentTitle,
                    rightsStatus: $0.rightsStatus,
                    citation: $0.citation
                )
            },
            article: GeneratedLearningArticle(
                title: candidate.article.title,
                learningObjective: candidate.article.learningObjective,
                explanation: candidate.article.explanation,
                exampleCode: candidate.article.exampleCode
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
                    ? nil
                    : candidate.article.exampleCode,
                citationReferenceIDs:
                    candidate.article.citationReferenceIDs
            ),
            quiz: GeneratedLearningQuiz(
                prompt: candidate.quiz.prompt,
                choices: candidate.quiz.choices,
                answerKeyChoiceID: candidate.quiz.answerKeyChoiceID,
                explanation: candidate.quiz.explanation,
                citationReferenceIDs:
                    candidate.quiz.citationReferenceIDs
            )
        )
    }

    private func resolveCurrentSources(
        for artifact: GeneratedLearningArtifact
    ) async throws -> [ResolvedSourceCitation] {
        var resolvedSources: [ResolvedSourceCitation] = []
        resolvedSources.reserveCapacity(artifact.sourceReferences.count)
        for reference in artifact.sourceReferences {
            let resolved = try await sourceLibrary.resolve(
                reference.citation
            )
            guard resolved.document.title == reference.documentTitle,
                  resolved.document.rightsStatus
                    == reference.rightsStatus,
                  resolved.document.localOnly else {
                throw GeneratedLearningFailure.sourceUnavailable
            }
            resolvedSources.append(resolved)
        }
        return resolvedSources
    }

    private func ensureSourcesAreActive(
        for artifact: GeneratedLearningArtifact
    ) throws {
        let sourceIDs = Set(
            artifact.sourceReferences.map(\.citation.sourceID)
        )
        guard sourceIDs.isDisjoint(with: invalidatedSourceIDs) else {
            throw GeneratedLearningFailure.sourceUnavailable
        }
    }

    private func rollbackArtifact(_ artifactID: UUID) async throws {
        do {
            try await store.deleteArtifact(id: artifactID)
        } catch {
            throw GeneratedLearningFailure.storageUnavailable
        }
    }
}
