#if DEBUG
import CryptoKit
import Foundation

enum StructuredGenerationValidationLimits {
    static let maximumSourceCards = 4
    static let maximumSourceCardCharacters = 1_200
    static let minimumChoiceCount = 2
    static let maximumChoiceCount = 6
    static let maximumTitleCharacters = 120
    static let maximumLearningObjectiveCharacters = 240
    static let maximumExplanationCharacters = 1_600
    static let maximumExampleCodeCharacters = 1_200
    static let maximumExercisePromptCharacters = 500
    static let maximumChoiceCharacters = 300
    static let maximumExerciseExplanationCharacters = 800
}

enum StructuredGenerationRequiredField: Equatable, Sendable {
    case conceptID
    case swiftVersion
    case minimumIOSVersion
    case promptVersion
    case sourceCardID(index: Int)
    case sourceCardTitle(cardID: String)
    case sourceDocumentTitle(cardID: String)
    case sourceSection(cardID: String)
    case sourceCardContentHash(cardID: String)
    case sourceCardText(cardID: String)
    case modelVersion
    case lessonTitle
    case learningObjective
    case lessonExplanation
    case exampleCode
    case exercisePrompt
    case exerciseExplanation
    case choiceID(index: Int)
    case choiceText(choiceID: String)
    case correctChoiceID
}

enum StructuredGenerationBoundedField: Equatable, Sendable {
    case sourceCardText(cardID: String)
    case lessonTitle
    case learningObjective
    case lessonExplanation
    case exampleCode
    case exercisePrompt
    case choiceText(choiceID: String)
    case exerciseExplanation
}

enum StructuredGenerationCitationScope: Equatable, Sendable {
    case lesson
    case exercise
}

enum StructuredGenerationValidationFailure: Equatable, Sendable {
    case emptyRequiredField(StructuredGenerationRequiredField)
    case noSourceCards
    case tooManySourceCards(actual: Int, maximum: Int)
    case duplicateSourceCardID(String)
    case invalidSourceCardContentHash(cardID: String)
    case sourceCardContentHashMismatch(cardID: String)
    case fieldTooLong(
        StructuredGenerationBoundedField,
        actual: Int,
        maximum: Int
    )
    case schemaVersionMismatch(expected: Int, actual: Int)
    case promptVersionMismatch(expected: String, actual: String)
    case swiftVersionMismatch(expected: String, actual: String)
    case minimumIOSVersionMismatch(expected: String, actual: String)
    case missingCitations(StructuredGenerationCitationScope)
    case duplicateCitation(
        scope: StructuredGenerationCitationScope,
        cardID: String
    )
    case unknownCitation(
        scope: StructuredGenerationCitationScope,
        cardID: String
    )
    case uncitedSourceCard(cardID: String)
    case tooFewChoices(actual: Int, minimum: Int)
    case tooManyChoices(actual: Int, maximum: Int)
    case duplicateChoiceID(String)
    case duplicateChoiceText(String)
    case correctChoiceNotFound(String)
}

struct StructuredGenerationValidationError: Error, Equatable, Sendable {
    let failures: [StructuredGenerationValidationFailure]

    init(failures: [StructuredGenerationValidationFailure]) {
        self.failures = failures
    }
}

struct StructuredGenerationValidator: Sendable {
    func validate(
        _ request: StructuredGenerationRequest
    ) throws {
        let failures = requestFailures(in: request)
        guard failures.isEmpty else {
            throw StructuredGenerationValidationError(failures: failures)
        }
    }

    func validate(
        _ artifact: StructuredGenerationArtifact,
        for request: StructuredGenerationRequest
    ) throws -> StructuredGenerationArtifact {
        let failures = failures(in: artifact, for: request)
        guard failures.isEmpty else {
            throw StructuredGenerationValidationError(failures: failures)
        }
        return artifact
    }

    func failures(
        in artifact: StructuredGenerationArtifact,
        for request: StructuredGenerationRequest
    ) -> [StructuredGenerationValidationFailure] {
        var failures = requestFailures(in: request)

        if artifact.schemaVersion != request.schemaVersion {
            failures.append(
                .schemaVersionMismatch(
                    expected: request.schemaVersion,
                    actual: artifact.schemaVersion
                )
            )
        }
        if artifact.promptVersion != request.promptVersion {
            failures.append(
                .promptVersionMismatch(
                    expected: request.promptVersion,
                    actual: artifact.promptVersion
                )
            )
        }
        if isBlank(artifact.modelVersion) {
            failures.append(.emptyRequiredField(.modelVersion))
        }
        if artifact.swiftVersion != request.swiftVersion {
            failures.append(
                .swiftVersionMismatch(
                    expected: request.swiftVersion,
                    actual: artifact.swiftVersion
                )
            )
        }
        if artifact.minimumIOSVersion != request.minimumIOSVersion {
            failures.append(
                .minimumIOSVersionMismatch(
                    expected: request.minimumIOSVersion,
                    actual: artifact.minimumIOSVersion
                )
            )
        }

        failures.append(contentsOf: lessonFailures(in: artifact.lesson))
        failures.append(contentsOf: exerciseFailures(in: artifact.exercise))

        let knownCardIDs = Set(request.sourceCards.map(\.id))
        failures.append(
            contentsOf: citationFailures(
                artifact.lesson.citationIDs,
                scope: .lesson,
                knownCardIDs: knownCardIDs
            )
        )
        failures.append(
            contentsOf: citationFailures(
                artifact.exercise.citationIDs,
                scope: .exercise,
                knownCardIDs: knownCardIDs
            )
        )
        let citedCardIDs = Set(
            artifact.lesson.citationIDs + artifact.exercise.citationIDs
        )
        for card in request.sourceCards where !citedCardIDs.contains(card.id) {
            failures.append(.uncitedSourceCard(cardID: card.id))
        }

        return failures
    }

    private func requestFailures(
        in request: StructuredGenerationRequest
    ) -> [StructuredGenerationValidationFailure] {
        var failures: [StructuredGenerationValidationFailure] = []

        if isBlank(request.conceptID) {
            failures.append(.emptyRequiredField(.conceptID))
        }
        if isBlank(request.swiftVersion) {
            failures.append(.emptyRequiredField(.swiftVersion))
        }
        if isBlank(request.minimumIOSVersion) {
            failures.append(.emptyRequiredField(.minimumIOSVersion))
        }
        if isBlank(request.promptVersion) {
            failures.append(.emptyRequiredField(.promptVersion))
        }
        if request.sourceCards.isEmpty {
            failures.append(.noSourceCards)
        }
        if request.sourceCards.count > StructuredGenerationValidationLimits.maximumSourceCards {
            failures.append(
                .tooManySourceCards(
                    actual: request.sourceCards.count,
                    maximum: StructuredGenerationValidationLimits.maximumSourceCards
                )
            )
        }

        var seenCardIDs = Set<String>()
        for (index, card) in request.sourceCards.enumerated() {
            if isBlank(card.id) {
                failures.append(.emptyRequiredField(.sourceCardID(index: index)))
            } else if !seenCardIDs.insert(card.id).inserted {
                failures.append(.duplicateSourceCardID(card.id))
            }
            if isBlank(card.title) {
                failures.append(.emptyRequiredField(.sourceCardTitle(cardID: card.id)))
            }
            if isBlank(card.location.documentTitle) {
                failures.append(
                    .emptyRequiredField(.sourceDocumentTitle(cardID: card.id))
                )
            }
            if isBlank(card.location.section) {
                failures.append(
                    .emptyRequiredField(.sourceSection(cardID: card.id))
                )
            }
            if isBlank(card.contentHash) {
                failures.append(
                    .emptyRequiredField(.sourceCardContentHash(cardID: card.id))
                )
            } else if !isSHA256HexDigest(card.contentHash) {
                failures.append(.invalidSourceCardContentHash(cardID: card.id))
            } else if card.contentHash.lowercased() != sha256(for: card.text) {
                failures.append(
                    .sourceCardContentHashMismatch(cardID: card.id)
                )
            }
            if isBlank(card.text) {
                failures.append(.emptyRequiredField(.sourceCardText(cardID: card.id)))
            }
            appendLengthFailure(
                for: card.text,
                field: .sourceCardText(cardID: card.id),
                maximum: StructuredGenerationValidationLimits.maximumSourceCardCharacters,
                to: &failures
            )
        }

        return failures
    }

    private func lessonFailures(
        in lesson: StructuredLessonArtifact
    ) -> [StructuredGenerationValidationFailure] {
        var failures: [StructuredGenerationValidationFailure] = []

        appendRequiredAndLengthFailures(
            for: lesson.title,
            requiredField: .lessonTitle,
            boundedField: .lessonTitle,
            maximum: StructuredGenerationValidationLimits.maximumTitleCharacters,
            to: &failures
        )
        appendRequiredAndLengthFailures(
            for: lesson.learningObjective,
            requiredField: .learningObjective,
            boundedField: .learningObjective,
            maximum: StructuredGenerationValidationLimits.maximumLearningObjectiveCharacters,
            to: &failures
        )
        appendRequiredAndLengthFailures(
            for: lesson.explanation,
            requiredField: .lessonExplanation,
            boundedField: .lessonExplanation,
            maximum: StructuredGenerationValidationLimits.maximumExplanationCharacters,
            to: &failures
        )
        appendRequiredAndLengthFailures(
            for: lesson.exampleCode,
            requiredField: .exampleCode,
            boundedField: .exampleCode,
            maximum: StructuredGenerationValidationLimits.maximumExampleCodeCharacters,
            to: &failures
        )

        return failures
    }

    private func exerciseFailures(
        in exercise: StructuredMultipleChoiceExercise
    ) -> [StructuredGenerationValidationFailure] {
        var failures: [StructuredGenerationValidationFailure] = []

        appendRequiredAndLengthFailures(
            for: exercise.prompt,
            requiredField: .exercisePrompt,
            boundedField: .exercisePrompt,
            maximum: StructuredGenerationValidationLimits.maximumExercisePromptCharacters,
            to: &failures
        )
        appendRequiredAndLengthFailures(
            for: exercise.explanation,
            requiredField: .exerciseExplanation,
            boundedField: .exerciseExplanation,
            maximum: StructuredGenerationValidationLimits.maximumExerciseExplanationCharacters,
            to: &failures
        )

        if exercise.choices.count < StructuredGenerationValidationLimits.minimumChoiceCount {
            failures.append(
                .tooFewChoices(
                    actual: exercise.choices.count,
                    minimum: StructuredGenerationValidationLimits.minimumChoiceCount
                )
            )
        }
        if exercise.choices.count > StructuredGenerationValidationLimits.maximumChoiceCount {
            failures.append(
                .tooManyChoices(
                    actual: exercise.choices.count,
                    maximum: StructuredGenerationValidationLimits.maximumChoiceCount
                )
            )
        }

        var seenChoiceIDs = Set<String>()
        var seenChoiceTexts = Set<String>()
        for (index, choice) in exercise.choices.enumerated() {
            if isBlank(choice.id) {
                failures.append(.emptyRequiredField(.choiceID(index: index)))
            } else if !seenChoiceIDs.insert(choice.id).inserted {
                failures.append(.duplicateChoiceID(choice.id))
            }

            let normalizedText = choice.text.normalizedForValidation
            if normalizedText.isEmpty {
                failures.append(.emptyRequiredField(.choiceText(choiceID: choice.id)))
            } else if !seenChoiceTexts.insert(normalizedText).inserted {
                failures.append(.duplicateChoiceText(choice.text))
            }
            appendLengthFailure(
                for: choice.text,
                field: .choiceText(choiceID: choice.id),
                maximum: StructuredGenerationValidationLimits.maximumChoiceCharacters,
                to: &failures
            )
        }

        if isBlank(exercise.correctChoiceID) {
            failures.append(.emptyRequiredField(.correctChoiceID))
        } else if !seenChoiceIDs.contains(exercise.correctChoiceID) {
            failures.append(.correctChoiceNotFound(exercise.correctChoiceID))
        }

        return failures
    }

    private func citationFailures(
        _ citationIDs: [String],
        scope: StructuredGenerationCitationScope,
        knownCardIDs: Set<String>
    ) -> [StructuredGenerationValidationFailure] {
        guard !citationIDs.isEmpty else {
            return [.missingCitations(scope)]
        }

        var failures: [StructuredGenerationValidationFailure] = []
        var seenCitationIDs = Set<String>()
        for cardID in citationIDs {
            if !seenCitationIDs.insert(cardID).inserted {
                failures.append(.duplicateCitation(scope: scope, cardID: cardID))
            }
            if !knownCardIDs.contains(cardID) {
                failures.append(.unknownCitation(scope: scope, cardID: cardID))
            }
        }
        return failures
    }

    private func appendRequiredAndLengthFailures(
        for value: String,
        requiredField: StructuredGenerationRequiredField,
        boundedField: StructuredGenerationBoundedField,
        maximum: Int,
        to failures: inout [StructuredGenerationValidationFailure]
    ) {
        if isBlank(value) {
            failures.append(.emptyRequiredField(requiredField))
        }
        appendLengthFailure(
            for: value,
            field: boundedField,
            maximum: maximum,
            to: &failures
        )
    }

    private func appendLengthFailure(
        for value: String,
        field: StructuredGenerationBoundedField,
        maximum: Int,
        to failures: inout [StructuredGenerationValidationFailure]
    ) {
        guard value.count > maximum else {
            return
        }
        failures.append(
            .fieldTooLong(field, actual: value.count, maximum: maximum)
        )
    }

    private func isBlank(_ value: String) -> Bool {
        value.normalizedForValidation.isEmpty
    }

    private func isSHA256HexDigest(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy(\.isHexDigit)
    }

    private func sha256(for value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private extension String {
    var normalizedForValidation: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
#endif
