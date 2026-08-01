import Foundation

enum LanguageModelAvailability: Equatable, Sendable {
    case available
    case unavailable(LanguageModelUnavailability)
}

enum LanguageModelUnavailability: String, Codable, Equatable, Sendable {
    case deviceNotSupported
    case intelligenceDisabled
    case modelNotReady
    case languageOrRegionUnsupported
    case other
}

enum LanguageModelProviderFailure: Error, Equatable, Sendable {
    case contextWindowExceeded
    case safetyGuardrail
    case requestFailed
    case invalidResponse
    case concurrentRequest
    case unknown
}

struct LanguageModelSourceCard: Equatable, Sendable {
    let id: String
    let documentTitle: String
    let locationLabel: String
    let rightsStatus: SourceRightsStatus
    let contentHash: String
    let text: String
    let citation: SourceCitation
}

struct LanguageModelGenerationRequest: Equatable, Sendable {
    let topic: String
    let swiftVersion: String
    let minimumIOSVersion: String
    let promptVersion: String
    let candidateSchemaVersion: Int
    let artifactSchemaVersion: Int
    let sourceCards: [LanguageModelSourceCard]
}

struct LanguageModelArticleCandidate: Equatable, Sendable {
    let title: String
    let learningObjective: String
    let explanation: String
    let exampleCode: String
    let citationReferenceIDs: [String]
}

struct LanguageModelQuizCandidate: Equatable, Sendable {
    let prompt: String
    let choices: [GeneratedLearningQuizChoice]
    let answerKeyChoiceID: String
    let explanation: String
    let citationReferenceIDs: [String]
}

struct LanguageModelGeneratedCandidate: Equatable, Sendable {
    let providerRuntimeLabel: String
    let article: LanguageModelArticleCandidate
    let quiz: LanguageModelQuizCandidate
}

protocol LanguageModelProvider: Sendable {
    func availability() async -> LanguageModelAvailability
    func generate(
        _ request: LanguageModelGenerationRequest
    ) async throws -> LanguageModelGeneratedCandidate
}

enum DeterministicLanguageModelMode: Equatable, Sendable {
    case valid
    case uncited
    case duplicateChoices
    case failure(LanguageModelProviderFailure)
}

struct DeterministicLanguageModelProvider: LanguageModelProvider {
    let availabilityState: LanguageModelAvailability
    let mode: DeterministicLanguageModelMode
    let delay: Duration

    init(
        availability: LanguageModelAvailability = .available,
        mode: DeterministicLanguageModelMode = .valid,
        delay: Duration = .zero
    ) {
        availabilityState = availability
        self.mode = mode
        self.delay = delay
    }

    func availability() async -> LanguageModelAvailability {
        availabilityState
    }

    func generate(
        _ request: LanguageModelGenerationRequest
    ) async throws -> LanguageModelGeneratedCandidate {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        guard case .available = availabilityState else {
            throw LanguageModelProviderFailure.requestFailed
        }
        if case let .failure(failure) = mode {
            throw failure
        }

        let citationIDs = mode == .uncited
            ? []
            : request.sourceCards.first.map { [$0.id] } ?? []
        let choiceTexts = mode == .duplicateChoices
            ? ["Use one owner", "Use one owner", "Use global state"]
            : [
                "Give the mutable state one explicit owner",
                "Duplicate the state in every view",
                "Use global state for every feature",
            ]
        let choices = choiceTexts.enumerated().map { index, text in
            GeneratedLearningQuizChoice(
                id: "choice-\(index + 1)",
                text: text
            )
        }

        return LanguageModelGeneratedCandidate(
            providerRuntimeLabel: "deterministic-provider-v1",
            article: LanguageModelArticleCandidate(
                title: "Understanding \(request.topic)",
                learningObjective: "Explain the core idea and apply it in a small Swift example.",
                explanation: "Use the cited imported passage as private study material, then verify each claim at its exact source location.",
                exampleCode: "struct LearningState { var isComplete = false }",
                citationReferenceIDs: citationIDs
            ),
            quiz: LanguageModelQuizCandidate(
                prompt: "Which choice best matches the generated article?",
                choices: choices,
                answerKeyChoiceID: choices[0].id,
                explanation: "The generated answer key selects explicit ownership; open the citation to review the underlying passage.",
                citationReferenceIDs: citationIDs
            )
        )
    }
}

#if DEBUG
actor DeterministicCancellationDrainLanguageModelProvider:
    LanguageModelProvider {
    private let drainDelay: Duration
    private var generationCallCount = 0

    init(drainDelay: Duration = .seconds(2)) {
        self.drainDelay = drainDelay
    }

    func availability() async -> LanguageModelAvailability {
        .available
    }

    func generate(
        _ request: LanguageModelGenerationRequest
    ) async throws -> LanguageModelGeneratedCandidate {
        generationCallCount += 1
        if generationCallCount == 1 {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
            }
            let drain = Task.detached { [drainDelay] in
                try? await Task.sleep(for: drainDelay)
            }
            await drain.value
            try Task.checkCancellation()
        }
        return try await DeterministicLanguageModelProvider()
            .generate(request)
    }
}
#endif
