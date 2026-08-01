import Foundation
import Testing
@testable import DailySwift

struct GeneratedLearningGeneratorTests {
    @Test("A valid deterministic pair preserves exact citations and is saved")
    func validGenerationIsCitedAndDurable() async throws {
        let sourceLibrary = SourceLibraryFixtures.service()
        let store = InMemoryGeneratedLearningStore()
        let generator = makeGenerator(
            retriever: DirectScanSourceRetriever(
                sourceLibrary: sourceLibrary
            ),
            sourceLibrary: sourceLibrary,
            store: store
        )

        let artifact = try await generator.generate(
            topic: "actor isolation",
            sourceIDs: [SourceLibraryFixtures.sourceID]
        )

        #expect(!artifact.sourceReferences.isEmpty)
        #expect(
            artifact.sourceReferences.count
                <= GeneratedLearningValidationLimits.maximumSourceCards
        )
        #expect(
            artifact.sourceReferences.allSatisfy {
                $0.citation.sourceID == SourceLibraryFixtures.sourceID
            }
        )
        #expect(!artifact.article.citationReferenceIDs.isEmpty)
        #expect(!artifact.quiz.citationReferenceIDs.isEmpty)

        let citedReferenceIDs = Set(
            artifact.article.citationReferenceIDs
                + artifact.quiz.citationReferenceIDs
        )
        for referenceID in citedReferenceIDs {
            let reference = try #require(
                artifact.sourceReference(id: referenceID)
            )
            let resolved = try await sourceLibrary.resolve(
                reference.citation
            )
            #expect(resolved.document.title == reference.documentTitle)
            #expect(
                resolved.document.rightsStatus == reference.rightsStatus
            )
            #expect(
                SourceTextProcessor.contentHash(for: resolved.excerpt)
                    == reference.citation.contentHash
            )
        }

        try GeneratedLearningValidator().validate(artifact)
        #expect(try await store.restore().isEmpty)
        try await generator.commitArtifact(artifact)
        #expect(try await store.restore() == [artifact])
        #expect(try await generator.restore() == [artifact])
    }

    @Test("Source cards preserve the first four ordered exact matches")
    func sourceCardRequestContract() async throws {
        let resolvedSources = (1...5).map {
            GeneratedLearningRequestFixture.resolvedSource(index: $0)
        }
        let sourceLibrary = ResolvedCitationSourceLibrary(
            sources: resolvedSources
        )
        let matches = resolvedSources.enumerated().map { index, resolved in
            SourceRetrievalMatch(
                document: resolved.document,
                citation: resolved.citation,
                excerpt: resolved.excerpt,
                score: Double(10 - index),
                matchedTerms: ["actor"]
            )
        }
        let provider = RecordingLanguageModelProvider()
        let generator = makeGenerator(
            retriever: InMemorySourceRetriever(
                outcomes: [.success(matches)]
            ),
            sourceLibrary: sourceLibrary,
            provider: provider,
            store: InMemoryGeneratedLearningStore()
        )

        let artifact = try await generator.generate(
            topic: "actor isolation",
            sourceIDs: []
        )
        let request = try #require(await provider.recordedRequest())

        #expect(request.sourceCards.count == 4)
        #expect(
            request.sourceCards.map(\.id)
                == [
                    "source-card-1",
                    "source-card-2",
                    "source-card-3",
                    "source-card-4",
                ]
        )
        #expect(
            request.sourceCards.map(\.documentTitle)
                == resolvedSources.prefix(4).map(\.document.title)
        )
        #expect(
            request.sourceCards.map(\.rightsStatus)
                == resolvedSources.prefix(4).map(
                    \.document.rightsStatus
                )
        )
        #expect(
            request.sourceCards.map(\.text)
                == resolvedSources.prefix(4).map(\.excerpt)
        )
        #expect(
            request.sourceCards.map(\.contentHash)
                == resolvedSources.prefix(4).map(
                    \.citation.contentHash
                )
        )
        #expect(
            request.sourceCards.map(\.citation)
                == resolvedSources.prefix(4).map(\.citation)
        )
        #expect(artifact.sourceReferences.count == 4)
        #expect(
            !artifact.sourceReferences.contains {
                $0.citation.sourceID
                    == resolvedSources[4].document.id
            }
        )
    }

    @Test("Every private provider failure maps without saving an artifact")
    func providerFailureMapping() async throws {
        let cases: [
            (
                LanguageModelProviderFailure,
                GeneratedLearningFailure
            )
        ] = [
            (.contextWindowExceeded, .contextTooLarge),
            (.safetyGuardrail, .safetyGuardrail),
            (
                .invalidResponse,
                .rejected([.requiredFieldMissing])
            ),
            (.requestFailed, .generationFailed),
            (.concurrentRequest, .generationFailed),
            (.unknown, .generationFailed),
        ]

        for (providerFailure, expectedFailure) in cases {
            let sourceLibrary = SourceLibraryFixtures.service()
            let store = InMemoryGeneratedLearningStore()
            let generator = makeGenerator(
                retriever: DirectScanSourceRetriever(
                    sourceLibrary: sourceLibrary
                ),
                sourceLibrary: sourceLibrary,
                provider: DeterministicLanguageModelProvider(
                    mode: .failure(providerFailure)
                ),
                store: store
            )

            await #expect(throws: expectedFailure) {
                try await generator.generate(
                    topic: "actor isolation",
                    sourceIDs: [SourceLibraryFixtures.sourceID]
                )
            }
            #expect(try await store.restore().isEmpty)
        }
    }

    @Test("No retrieved passage produces insufficient evidence")
    func noMatches() async throws {
        let store = InMemoryGeneratedLearningStore()
        let generator = makeGenerator(
            retriever: InMemorySourceRetriever(
                outcomes: [.success([])]
            ),
            store: store
        )

        await #expect(
            throws: GeneratedLearningFailure.insufficientEvidence
        ) {
            try await generator.generate(
                topic: "actor isolation",
                sourceIDs: []
            )
        }
        #expect(try await store.restore().isEmpty)
    }

    @Test("Provider unavailability stops before generation and persistence")
    func providerUnavailable() async throws {
        let store = InMemoryGeneratedLearningStore()
        let generator = makeGenerator(
            provider: DeterministicLanguageModelProvider(
                availability: .unavailable(.modelNotReady)
            ),
            store: store
        )

        await #expect(
            throws: GeneratedLearningFailure.unavailable(.modelNotReady)
        ) {
            try await generator.generate(
                topic: "actor isolation",
                sourceIDs: []
            )
        }
        #expect(try await store.restore().isEmpty)
    }

    @Test("Invalid provider output is rejected and never saved")
    func invalidProviderOutputIsNotSaved() async throws {
        let sourceLibrary = SourceLibraryFixtures.service()
        let store = InMemoryGeneratedLearningStore()
        let generator = GeneratedLearningGenerator(
            retriever: DirectScanSourceRetriever(
                sourceLibrary: sourceLibrary
            ),
            sourceLibrary: sourceLibrary,
            provider: DeterministicLanguageModelProvider(
                mode: .uncited
            ),
            store: store
        )

        do {
            _ = try await generator.generate(
                topic: "actor isolation",
                sourceIDs: []
            )
            Issue.record("Expected uncited provider output to be rejected")
        } catch let failure as GeneratedLearningFailure {
            if case let .rejected(categories) = failure {
                #expect(categories.contains(.citationsMissing))
            } else {
                Issue.record("Expected a generated learning rejection")
            }
        } catch {
            Issue.record("Expected a generated learning rejection")
        }

        #expect(try await store.restore().isEmpty)
    }

    @Test("Restore retains only artifacts whose exact sources still resolve")
    func restoreValidatesExactSources() async throws {
        let sourceLibrary = SourceLibraryFixtures.service()
        let citation = try #require(
            SourceLibraryFixtures.chunks.first?.citation
        )
        let resolved = try await sourceLibrary.resolve(citation)
        let validArtifact = GeneratedLearningTestFixtures.artifact(
            id: UUID(
                uuidString: "73000000-0000-0000-0000-000000000001"
            )!,
            document: resolved.document,
            citation: resolved.citation,
            excerpt: resolved.excerpt,
            createdAt: Date(timeIntervalSince1970: 1_785_200_001)
        )
        let mismatchedArtifact = GeneratedLearningTestFixtures.artifact(
            id: UUID(
                uuidString: "73000000-0000-0000-0000-000000000002"
            )!,
            document: resolved.document,
            citation: resolved.citation,
            excerpt: resolved.excerpt,
            documentTitle: "Changed private source title",
            createdAt: Date(timeIntervalSince1970: 1_785_200_002)
        )
        let store = InMemoryGeneratedLearningStore(
            artifacts: [mismatchedArtifact, validArtifact]
        )
        let generator = makeGenerator(
            sourceLibrary: sourceLibrary,
            store: store
        )

        let restored = try await generator.restore()

        #expect(restored == [validArtifact])
    }

    @Test("Restore rejects persisted content that exceeds source overlap")
    func restoreReappliesSourceOverlapGate() async throws {
        let sourceID = UUID(
            uuidString: "73100000-0000-0000-0000-000000000001"
        )!
        let sourceText = "Actors protect mutable state by allowing one explicit owner to serialize every update before another task can observe the resulting stored value safely."
        let sourceHash = SourceTextProcessor.contentHash(for: sourceText)
        let document = SourceDocument(
            id: sourceID,
            title: "Synthetic overlap notes",
            author: nil,
            publisher: nil,
            originFileName: "synthetic-overlap.md",
            rightsStatus: .openLicensed,
            contentHash: sourceHash,
            importedAt: Date(timeIntervalSince1970: 1_785_200_000),
            format: .markdown,
            byteCount: Data(sourceText.utf8).count
        )
        let chunks = SourceTextProcessor.chunks(
            sourceID: sourceID,
            sourceContentHash: sourceHash,
            normalizedText: sourceText,
            format: .markdown
        )
        let sourceLibrary = InMemorySourceLibraryService(
            snapshot: SourceLibrarySnapshot(
                documents: [document],
                chunks: chunks
            ),
            normalizedTextBySourceID: [sourceID: sourceText]
        )
        let citation = try #require(chunks.first?.citation)
        let resolved = try await sourceLibrary.resolve(citation)
        let card = GeneratedLearningTestFixtures.sourceCard(
            documentTitle: document.title,
            rightsStatus: document.rightsStatus,
            text: resolved.excerpt,
            citation: citation
        )
        let request = GeneratedLearningTestFixtures.request(
            sourceCards: [card]
        )
        let artifact = GeneratedLearningTestFixtures.artifact(
            request: request,
            candidate: GeneratedLearningTestFixtures.candidate(
                citationReferenceIDs: [card.id],
                articleExplanation: resolved.excerpt
            )
        )
        let generator = makeGenerator(
            sourceLibrary: sourceLibrary,
            store: InMemoryGeneratedLearningStore(
                artifacts: [artifact]
            )
        )

        #expect(try await generator.restore().isEmpty)
    }

    @Test("Deleting a source cascades only to its generated artifacts")
    func deletionCascade() async throws {
        let textCitation = try #require(
            SourceLibraryFixtures.chunks.first?.citation
        )
        let pdfCitation = try #require(
            SourceLibraryFixtures.pdfChunks.first?.citation
        )
        let textResolved = try await SourceLibraryFixtures.service().resolve(
            textCitation
        )
        let pdfResolved = try await SourceLibraryFixtures.pdfService().resolve(
            pdfCitation
        )
        let textArtifact = GeneratedLearningTestFixtures.artifact(
            id: UUID(
                uuidString: "74000000-0000-0000-0000-000000000001"
            )!,
            document: textResolved.document,
            citation: textResolved.citation,
            excerpt: textResolved.excerpt,
            createdAt: Date(timeIntervalSince1970: 1_785_200_001)
        )
        let pdfArtifact = GeneratedLearningTestFixtures.artifact(
            id: UUID(
                uuidString: "74000000-0000-0000-0000-000000000002"
            )!,
            document: pdfResolved.document,
            citation: pdfResolved.citation,
            excerpt: pdfResolved.excerpt,
            createdAt: Date(timeIntervalSince1970: 1_785_200_002)
        )
        let store = InMemoryGeneratedLearningStore(
            artifacts: [textArtifact, pdfArtifact]
        )
        let generator = makeGenerator(store: store)

        try await generator.deleteArtifacts(
            referencing: SourceLibraryFixtures.sourceID
        )

        let remaining = try await store.restore()
        #expect(remaining == [pdfArtifact])
    }

    @Test("Source deletion invalidates an in-flight generation before save")
    func deletionInvalidatesInFlightGeneration() async throws {
        let sourceLibrary = SourceLibraryFixtures.service()
        let provider = SuspendedLanguageModelProvider()
        let store = InMemoryGeneratedLearningStore()
        let generator = makeGenerator(
            retriever: DirectScanSourceRetriever(
                sourceLibrary: sourceLibrary
            ),
            sourceLibrary: sourceLibrary,
            provider: provider,
            store: store
        )
        let generation = Task {
            try await generator.generate(
                topic: "actor isolation",
                sourceIDs: [SourceLibraryFixtures.sourceID]
            )
        }

        await provider.waitUntilRequestStarts()
        try await generator.deleteArtifacts(
            referencing: SourceLibraryFixtures.sourceID
        )
        await provider.resume()

        await #expect(throws: GeneratedLearningFailure.sourceUnavailable) {
            _ = try await generation.value
        }
        #expect(try await store.restore().isEmpty)
    }

    @Test("A source changed during model work is revalidated before save")
    func sourceFreshnessIsRevalidatedBeforeCommit() async throws {
        let sourceLibrary = SourceLibraryFixtures.service()
        let provider = SuspendedLanguageModelProvider()
        let store = InMemoryGeneratedLearningStore()
        let generator = makeGenerator(
            retriever: DirectScanSourceRetriever(
                sourceLibrary: sourceLibrary
            ),
            sourceLibrary: sourceLibrary,
            provider: provider,
            store: store
        )
        let generation = Task {
            try await generator.generate(
                topic: "actor isolation",
                sourceIDs: [SourceLibraryFixtures.sourceID]
            )
        }

        await provider.waitUntilRequestStarts()
        try await sourceLibrary.delete(
            sourceID: SourceLibraryFixtures.sourceID
        )
        await provider.resume()

        await #expect(throws: GeneratedLearningFailure.sourceUnavailable) {
            _ = try await generation.value
        }
        #expect(try await store.restore().isEmpty)
    }

    @Test("Cancellation after persistence rolls back the exact artifact")
    func cancellationAtCommitBoundaryRollsBack() async throws {
        let sourceLibrary = SourceLibraryFixtures.service()
        let store = SuspendedGeneratedLearningStore()
        let generator = makeGenerator(
            retriever: DirectScanSourceRetriever(
                sourceLibrary: sourceLibrary
            ),
            sourceLibrary: sourceLibrary,
            store: store
        )
        let artifact = try await generator.generate(
            topic: "actor isolation",
            sourceIDs: [SourceLibraryFixtures.sourceID]
        )
        let commit = Task {
            try await generator.commitArtifact(artifact)
        }

        await store.waitUntilSaveCommits()
        commit.cancel()
        await store.resumeSave()

        do {
            try await commit.value
            Issue.record("Expected cancellation at the commit boundary")
        } catch is CancellationError {
            // The exact artifact must be removed before cancellation returns.
        } catch {
            Issue.record("Expected CancellationError after rollback")
        }
        #expect(try await store.restore().isEmpty)
    }

    @Test("A source changed before finalization prevents persistence")
    func sourceFreshnessIsRevalidatedAtFinalization() async throws {
        let sourceLibrary = SourceLibraryFixtures.service()
        let store = InMemoryGeneratedLearningStore()
        let generator = makeGenerator(
            retriever: DirectScanSourceRetriever(
                sourceLibrary: sourceLibrary
            ),
            sourceLibrary: sourceLibrary,
            store: store
        )
        let artifact = try await generator.generate(
            topic: "actor isolation",
            sourceIDs: [SourceLibraryFixtures.sourceID]
        )
        try await sourceLibrary.delete(
            sourceID: SourceLibraryFixtures.sourceID
        )

        await #expect(throws: GeneratedLearningFailure.sourceUnavailable) {
            try await generator.commitArtifact(artifact)
        }
        #expect(try await store.restore().isEmpty)
    }

    private func makeGenerator(
        retriever: any SourceRetrieving = InMemorySourceRetriever(),
        sourceLibrary: any SourceLibraryServing =
            SourceLibraryFixtures.service(),
        provider: any LanguageModelProvider =
            DeterministicLanguageModelProvider(),
        store: any GeneratedLearningStoring
    ) -> GeneratedLearningGenerator {
        GeneratedLearningGenerator(
            retriever: retriever,
            sourceLibrary: sourceLibrary,
            provider: provider,
            store: store,
            now: { Date(timeIntervalSince1970: 1_785_200_000) },
            makeArtifactID: {
                UUID(
                    uuidString: "75000000-0000-0000-0000-000000000001"
                )!
            }
        )
    }
}

private enum GeneratedLearningRequestFixture {
    static func resolvedSource(index: Int) -> ResolvedSourceCitation {
        let sourceID = UUID(
            uuidString: String(
                format: "73200000-0000-0000-0000-%012d",
                index
            )
        )!
        let text = "Source passage \(index) explains actor isolation with distinct private evidence."
        let hash = SourceTextProcessor.contentHash(for: text)
        let rights: SourceRightsStatus = index.isMultiple(of: 2)
            ? .lawfullyPossessedPrivateCopy
            : .openLicensed
        let document = SourceDocument(
            id: sourceID,
            title: "Ordered source \(index)",
            author: nil,
            publisher: nil,
            originFileName: "ordered-source-\(index).md",
            rightsStatus: rights,
            contentHash: hash,
            importedAt: Date(timeIntervalSince1970: 1_785_200_000),
            format: .markdown,
            byteCount: Data(text.utf8).count
        )
        let citation = SourceCitation(
            sourceID: sourceID,
            chunkID: "ordered-source-chunk-\(index)",
            headingPath: ["Actor isolation", "Passage \(index)"],
            location: SourceLocation(
                startLine: index,
                endLine: index,
                startCharacter: 0,
                endCharacter: text.count
            ),
            contentHash: hash
        )
        return ResolvedSourceCitation(
            document: document,
            citation: citation,
            excerpt: text,
            originalFileURL: nil
        )
    }
}

private actor ResolvedCitationSourceLibrary: SourceLibraryServing {
    private let sourcesByCitation: [
        SourceCitation: ResolvedSourceCitation
    ]

    init(sources: [ResolvedSourceCitation]) {
        sourcesByCitation = Dictionary(
            uniqueKeysWithValues: sources.map {
                ($0.citation, $0)
            }
        )
    }

    func restore() async throws -> SourceLibrarySnapshot {
        SourceLibrarySnapshot(
            documents: sourcesByCitation.values.map(\.document),
            chunks: []
        )
    }

    func importSource(
        _ request: SourceImportRequest
    ) async throws -> SourceDocument {
        throw SourceLibraryFailure.unreadableFile
    }

    func resolve(
        _ citation: SourceCitation
    ) async throws -> ResolvedSourceCitation {
        guard let source = sourcesByCitation[citation] else {
            throw SourceLibraryFailure.citationMissing
        }
        return source
    }

    func delete(sourceID: UUID) async throws {}
}

private actor RecordingLanguageModelProvider: LanguageModelProvider {
    private var request: LanguageModelGenerationRequest?

    func availability() async -> LanguageModelAvailability {
        .available
    }

    func generate(
        _ request: LanguageModelGenerationRequest
    ) async throws -> LanguageModelGeneratedCandidate {
        self.request = request
        return try await DeterministicLanguageModelProvider()
            .generate(request)
    }

    func recordedRequest() -> LanguageModelGenerationRequest? {
        request
    }
}

private actor SuspendedLanguageModelProvider: LanguageModelProvider {
    private var didStart = false
    private var canResume = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var resumeWaiters: [CheckedContinuation<Void, Never>] = []

    func availability() async -> LanguageModelAvailability {
        .available
    }

    func generate(
        _ request: LanguageModelGenerationRequest
    ) async throws -> LanguageModelGeneratedCandidate {
        didStart = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
        if !canResume {
            await withCheckedContinuation { continuation in
                resumeWaiters.append(continuation)
            }
        }
        try Task.checkCancellation()
        return try await DeterministicLanguageModelProvider()
            .generate(request)
    }

    func waitUntilRequestStarts() async {
        guard !didStart else {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func resume() {
        canResume = true
        let waiters = resumeWaiters
        resumeWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

private actor SuspendedGeneratedLearningStore:
    GeneratedLearningStoring {
    private var artifacts: [GeneratedLearningArtifact] = []
    private var didCommitSave = false
    private var canResumeSave = false
    private var commitWaiters: [CheckedContinuation<Void, Never>] = []
    private var resumeWaiters: [CheckedContinuation<Void, Never>] = []

    func restore() async throws -> [GeneratedLearningArtifact] {
        artifacts
    }

    func save(_ artifact: GeneratedLearningArtifact) async throws {
        artifacts.removeAll { $0.id == artifact.id }
        artifacts.append(artifact)
        didCommitSave = true
        let waiters = commitWaiters
        commitWaiters.removeAll()
        waiters.forEach { $0.resume() }
        if !canResumeSave {
            await withCheckedContinuation { continuation in
                resumeWaiters.append(continuation)
            }
        }
    }

    func deleteArtifact(id: UUID) async throws {
        artifacts.removeAll { $0.id == id }
    }

    func deleteArtifacts(referencing sourceID: UUID) async throws {
        artifacts.removeAll { $0.references(sourceID: sourceID) }
    }

    func waitUntilSaveCommits() async {
        guard !didCommitSave else {
            return
        }
        await withCheckedContinuation { continuation in
            commitWaiters.append(continuation)
        }
    }

    func resumeSave() {
        canResumeSave = true
        let waiters = resumeWaiters
        resumeWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}
