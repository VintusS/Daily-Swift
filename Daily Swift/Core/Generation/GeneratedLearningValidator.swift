import Foundation

enum GeneratedLearningValidationLimits {
    static let maximumSourceCards = 4
    static let maximumSourceCardCharacters = 1_200
    static let maximumTopicCharacters = 200
    static let maximumTitleCharacters = 120
    static let maximumObjectiveCharacters = 240
    static let maximumArticleCharacters = 2_400
    static let maximumCodeCharacters = 1_200
    static let maximumQuizPromptCharacters = 500
    static let maximumChoiceCharacters = 300
    static let maximumQuizExplanationCharacters = 1_000
    static let maximumPermittedVerbatimSourceWords = 15
}

enum GeneratedLearningValidationCategory: String, Codable, Equatable,
    Hashable, CaseIterable, Sendable {
    case requiredFieldMissing = "required-field-missing"
    case fieldLimitExceeded = "field-limit-exceeded"
    case sourceCardsMissing = "source-cards-missing"
    case sourceCardLimitExceeded = "source-card-limit-exceeded"
    case sourceCardIdentityDuplicated = "source-card-identity-duplicated"
    case sourceCardHashMismatch = "source-card-hash-mismatch"
    case citationsMissing = "citations-missing"
    case citationDuplicated = "citation-duplicated"
    case citationUnknown = "citation-unknown"
    case choiceCountInvalid = "choice-count-invalid"
    case choiceIdentityDuplicated = "choice-identity-duplicated"
    case choiceTextDuplicated = "choice-text-duplicated"
    case answerKeyMissing = "answer-key-missing"
    case schemaVersionMismatch = "schema-version-mismatch"
    case sourceSetMismatch = "source-set-mismatch"
    case sourceOverlapExceeded = "source-overlap-exceeded"

    var title: String {
        switch self {
        case .requiredFieldMissing:
            "Required generated content is missing"
        case .fieldLimitExceeded:
            "Generated content exceeds a safe limit"
        case .sourceCardsMissing:
            "No exact source passages were supplied"
        case .sourceCardLimitExceeded:
            "Too many source passages were supplied"
        case .sourceCardIdentityDuplicated:
            "A source passage identity is duplicated"
        case .sourceCardHashMismatch:
            "A source passage changed"
        case .citationsMissing:
            "A generated section has no citation"
        case .citationDuplicated:
            "A citation is duplicated"
        case .citationUnknown:
            "A citation cannot be resolved"
        case .choiceCountInvalid:
            "The quiz choice count is invalid"
        case .choiceIdentityDuplicated:
            "A quiz choice identity is duplicated"
        case .choiceTextDuplicated:
            "Quiz choices repeat the same answer"
        case .answerKeyMissing:
            "The generated answer key cannot be resolved"
        case .schemaVersionMismatch:
            "The generated schema is unsupported"
        case .sourceSetMismatch:
            "The generated source identity changed"
        case .sourceOverlapExceeded:
            "Generated content repeats too much source text"
        }
    }
}

struct GeneratedLearningValidationError: Error, Equatable, Sendable {
    let categories: [GeneratedLearningValidationCategory]

    init(_ categories: [GeneratedLearningValidationCategory]) {
        self.categories = Array(Set(categories)).sorted {
            $0.rawValue < $1.rawValue
        }
    }
}

struct GeneratedLearningValidator: Sendable {
    func validate(
        _ request: LanguageModelGenerationRequest
    ) throws {
        let categories = requestCategories(request)
        guard categories.isEmpty else {
            throw GeneratedLearningValidationError(categories)
        }
    }

    func validate(
        _ candidate: LanguageModelGeneratedCandidate,
        for request: LanguageModelGenerationRequest
    ) throws {
        var categories = requestCategories(request)

        appendRequiredAndLimit(
            candidate.providerRuntimeLabel,
            maximum: 240,
            to: &categories
        )
        appendRequiredAndLimit(
            candidate.article.title,
            maximum: GeneratedLearningValidationLimits.maximumTitleCharacters,
            to: &categories
        )
        appendRequiredAndLimit(
            candidate.article.learningObjective,
            maximum: GeneratedLearningValidationLimits.maximumObjectiveCharacters,
            to: &categories
        )
        appendRequiredAndLimit(
            candidate.article.explanation,
            maximum: GeneratedLearningValidationLimits.maximumArticleCharacters,
            to: &categories
        )
        appendRequiredAndLimit(
            candidate.article.exampleCode,
            maximum: GeneratedLearningValidationLimits.maximumCodeCharacters,
            to: &categories
        )
        appendRequiredAndLimit(
            candidate.quiz.prompt,
            maximum: GeneratedLearningValidationLimits.maximumQuizPromptCharacters,
            to: &categories
        )
        appendRequiredAndLimit(
            candidate.quiz.explanation,
            maximum: GeneratedLearningValidationLimits.maximumQuizExplanationCharacters,
            to: &categories
        )

        let knownReferenceIDs = Set(request.sourceCards.map(\.id))
        appendCitationCategories(
            candidate.article.citationReferenceIDs,
            knownReferenceIDs: knownReferenceIDs,
            to: &categories
        )
        appendCitationCategories(
            candidate.quiz.citationReferenceIDs,
            knownReferenceIDs: knownReferenceIDs,
            to: &categories
        )
        appendQuizCategories(candidate.quiz, to: &categories)
        appendSourceOverlapCategories(
            candidate,
            sourceCards: request.sourceCards,
            to: &categories
        )

        guard categories.isEmpty else {
            throw GeneratedLearningValidationError(categories)
        }
    }

    func validate(_ artifact: GeneratedLearningArtifact) throws {
        var categories: [GeneratedLearningValidationCategory] = []
        if artifact.schemaVersion != GeneratedLearningArtifact.currentSchemaVersion {
            categories.append(.schemaVersionMismatch)
        }
        if artifact.promptVersion != GeneratedLearningVersion.prompt
            || artifact.candidateSchemaVersion
                != GeneratedLearningVersion.candidateSchema {
            categories.append(.schemaVersionMismatch)
        }
        appendRequiredAndLimit(
            artifact.topic,
            maximum: GeneratedLearningValidationLimits.maximumTopicCharacters,
            to: &categories
        )
        appendRequiredAndLimit(
            artifact.promptVersion,
            maximum: 120,
            to: &categories
        )
        appendRequiredAndLimit(
            artifact.providerRuntimeLabel,
            maximum: 240,
            to: &categories
        )
        appendRequiredAndLimit(
            artifact.sourceSetHash,
            maximum: 64,
            to: &categories
        )

        let referenceIDs = artifact.sourceReferences.map(\.id)
        if referenceIDs.isEmpty {
            categories.append(.sourceCardsMissing)
        }
        if referenceIDs.count > GeneratedLearningValidationLimits.maximumSourceCards {
            categories.append(.sourceCardLimitExceeded)
        }
        if Set(referenceIDs).count != referenceIDs.count {
            categories.append(.sourceCardIdentityDuplicated)
        }
        for reference in artifact.sourceReferences {
            appendRequiredAndLimit(
                reference.id,
                maximum: 80,
                to: &categories
            )
            appendRequiredAndLimit(
                reference.documentTitle,
                maximum: 300,
                to: &categories
            )
            appendRequiredAndLimit(
                reference.citation.chunkID,
                maximum: 300,
                to: &categories
            )
            if reference.citation.contentHash.count != 64 {
                categories.append(.sourceCardHashMismatch)
            }
        }

        let knownReferenceIDs = Set(referenceIDs)
        appendRequiredAndLimit(
            artifact.article.title,
            maximum: GeneratedLearningValidationLimits.maximumTitleCharacters,
            to: &categories
        )
        appendRequiredAndLimit(
            artifact.article.learningObjective,
            maximum: GeneratedLearningValidationLimits.maximumObjectiveCharacters,
            to: &categories
        )
        appendRequiredAndLimit(
            artifact.article.explanation,
            maximum: GeneratedLearningValidationLimits.maximumArticleCharacters,
            to: &categories
        )
        if let exampleCode = artifact.article.exampleCode {
            appendLimit(
                exampleCode,
                maximum: GeneratedLearningValidationLimits.maximumCodeCharacters,
                to: &categories
            )
        }
        appendRequiredAndLimit(
            artifact.quiz.prompt,
            maximum: GeneratedLearningValidationLimits.maximumQuizPromptCharacters,
            to: &categories
        )
        appendRequiredAndLimit(
            artifact.quiz.explanation,
            maximum: GeneratedLearningValidationLimits.maximumQuizExplanationCharacters,
            to: &categories
        )
        appendCitationCategories(
            artifact.article.citationReferenceIDs,
            knownReferenceIDs: knownReferenceIDs,
            to: &categories
        )
        appendCitationCategories(
            artifact.quiz.citationReferenceIDs,
            knownReferenceIDs: knownReferenceIDs,
            to: &categories
        )
        appendQuizCategories(
            LanguageModelQuizCandidate(
                prompt: artifact.quiz.prompt,
                choices: artifact.quiz.choices,
                answerKeyChoiceID: artifact.quiz.answerKeyChoiceID,
                explanation: artifact.quiz.explanation,
                citationReferenceIDs:
                    artifact.quiz.citationReferenceIDs
            ),
            to: &categories
        )

        let expectedSourceSetHash = Self.sourceSetHash(
            artifact.sourceReferences.map {
                ($0.citation, $0.id)
            }
        )
        if artifact.sourceSetHash != expectedSourceSetHash {
            categories.append(.sourceSetMismatch)
        }

        guard categories.isEmpty else {
            throw GeneratedLearningValidationError(categories)
        }
    }

    func validateSourceOverlap(
        in artifact: GeneratedLearningArtifact,
        against sourceExcerpts: [String]
    ) throws {
        var categories: [GeneratedLearningValidationCategory] = []
        appendSourceOverlapCategories(
            generatedFields: [
                artifact.article.title,
                artifact.article.learningObjective,
                artifact.article.explanation,
                artifact.article.exampleCode ?? "",
                artifact.quiz.prompt,
                artifact.quiz.explanation,
            ] + artifact.quiz.choices.map(\.text),
            sourceTexts: sourceExcerpts,
            to: &categories
        )

        guard categories.isEmpty else {
            throw GeneratedLearningValidationError(categories)
        }
    }

    static func sourceSetHash(
        for cards: [LanguageModelSourceCard]
    ) -> String {
        sourceSetHash(
            cards.map { ($0.citation, $0.id) }
        )
    }

    private static func sourceSetHash(
        _ values: [(SourceCitation, String)]
    ) -> String {
        let identity = values.map { citation, cardID in
            [
                cardID,
                citation.sourceID.uuidString.lowercased(),
                citation.chunkID,
                citation.contentHash.lowercased(),
            ].joined(separator: "|")
        }
        .joined(separator: "\n")
        return SourceTextProcessor.contentHash(for: identity)
    }

    private func requestCategories(
        _ request: LanguageModelGenerationRequest
    ) -> [GeneratedLearningValidationCategory] {
        var categories: [GeneratedLearningValidationCategory] = []
        appendRequiredAndLimit(
            request.topic,
            maximum: GeneratedLearningValidationLimits.maximumTopicCharacters,
            to: &categories
        )
        appendRequiredAndLimit(
            request.swiftVersion,
            maximum: 40,
            to: &categories
        )
        appendRequiredAndLimit(
            request.minimumIOSVersion,
            maximum: 40,
            to: &categories
        )
        appendRequiredAndLimit(
            request.promptVersion,
            maximum: 120,
            to: &categories
        )
        if request.promptVersion != GeneratedLearningVersion.prompt
            || request.candidateSchemaVersion
                != GeneratedLearningVersion.candidateSchema
            || request.artifactSchemaVersion
                != GeneratedLearningArtifact.currentSchemaVersion {
            categories.append(.schemaVersionMismatch)
        }
        if request.sourceCards.isEmpty {
            categories.append(.sourceCardsMissing)
        }
        if request.sourceCards.count
            > GeneratedLearningValidationLimits.maximumSourceCards {
            categories.append(.sourceCardLimitExceeded)
        }

        let ids = request.sourceCards.map(\.id)
        if Set(ids).count != ids.count {
            categories.append(.sourceCardIdentityDuplicated)
        }
        for card in request.sourceCards {
            appendRequiredAndLimit(card.id, maximum: 80, to: &categories)
            appendRequiredAndLimit(
                card.documentTitle,
                maximum: 300,
                to: &categories
            )
            appendRequiredAndLimit(
                card.locationLabel,
                maximum: 300,
                to: &categories
            )
            appendRequiredAndLimit(
                card.text,
                maximum: GeneratedLearningValidationLimits.maximumSourceCardCharacters,
                to: &categories
            )
            if card.contentHash.lowercased()
                != SourceTextProcessor.contentHash(for: card.text) {
                categories.append(.sourceCardHashMismatch)
            }
            if card.citation.contentHash.lowercased()
                != card.contentHash.lowercased() {
                categories.append(.sourceCardHashMismatch)
            }
        }
        return categories
    }

    private func appendCitationCategories(
        _ ids: [String],
        knownReferenceIDs: Set<String>,
        to categories: inout [GeneratedLearningValidationCategory]
    ) {
        if ids.isEmpty {
            categories.append(.citationsMissing)
        }
        if Set(ids).count != ids.count {
            categories.append(.citationDuplicated)
        }
        if ids.contains(where: { !knownReferenceIDs.contains($0) }) {
            categories.append(.citationUnknown)
        }
    }

    private func appendQuizCategories(
        _ quiz: LanguageModelQuizCandidate,
        to categories: inout [GeneratedLearningValidationCategory]
    ) {
        if quiz.choices.count != 3 {
            categories.append(.choiceCountInvalid)
        }
        let ids = quiz.choices.map(\.id)
        if Set(ids).count != ids.count {
            categories.append(.choiceIdentityDuplicated)
        }
        let normalizedTexts = quiz.choices.map {
            $0.text.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: Locale(identifier: "en_US_POSIX")
                )
        }
        if normalizedTexts.contains(where: \.isEmpty) {
            categories.append(.requiredFieldMissing)
        }
        if Set(normalizedTexts).count != normalizedTexts.count {
            categories.append(.choiceTextDuplicated)
        }
        for choice in quiz.choices {
            appendRequiredAndLimit(
                choice.id,
                maximum: 80,
                to: &categories
            )
            appendRequiredAndLimit(
                choice.text,
                maximum: GeneratedLearningValidationLimits.maximumChoiceCharacters,
                to: &categories
            )
        }
        if quiz.choices.filter({
            $0.id == quiz.answerKeyChoiceID
        }).count != 1 {
            categories.append(.answerKeyMissing)
        }
    }

    private func appendSourceOverlapCategories(
        _ candidate: LanguageModelGeneratedCandidate,
        sourceCards: [LanguageModelSourceCard],
        to categories: inout [GeneratedLearningValidationCategory]
    ) {
        appendSourceOverlapCategories(
            generatedFields: [
                candidate.article.title,
                candidate.article.learningObjective,
                candidate.article.explanation,
                candidate.article.exampleCode,
                candidate.quiz.prompt,
                candidate.quiz.explanation,
            ] + candidate.quiz.choices.map(\.text),
            sourceTexts: sourceCards.map(\.text),
            to: &categories
        )
    }

    private func appendSourceOverlapCategories(
        generatedFields: [String],
        sourceTexts: [String],
        to categories: inout [GeneratedLearningValidationCategory]
    ) {
        let windowSize =
            GeneratedLearningValidationLimits
                .maximumPermittedVerbatimSourceWords + 1
        let sourceWindows = Set(
            sourceTexts.flatMap {
                tokenWindows(in: $0, count: windowSize)
            }
        )
        guard !sourceWindows.isEmpty else {
            return
        }

        if generatedFields.contains(where: { field in
            tokenWindows(in: field, count: windowSize).contains {
                sourceWindows.contains($0)
            }
        }) {
            categories.append(.sourceOverlapExceeded)
        }
    }

    private func tokenWindows(
        in value: String,
        count: Int
    ) -> [String] {
        let tokens = value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        guard tokens.count >= count else {
            return []
        }
        return (0...(tokens.count - count)).map { start in
            tokens[start..<(start + count)].joined(separator: " ")
        }
    }

    private func appendRequiredAndLimit(
        _ value: String,
        maximum: Int,
        to categories: inout [GeneratedLearningValidationCategory]
    ) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            categories.append(.requiredFieldMissing)
        }
        appendLimit(value, maximum: maximum, to: &categories)
    }

    private func appendLimit(
        _ value: String,
        maximum: Int,
        to categories: inout [GeneratedLearningValidationCategory]
    ) {
        if value.count > maximum {
            categories.append(.fieldLimitExceeded)
        }
    }
}
