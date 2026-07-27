#if DEBUG
import Foundation

enum StructuredGenerationSourceRights: String, Equatable, Sendable {
    case projectAuthored
}

struct StructuredGenerationSourceLocation: Equatable, Sendable {
    let documentTitle: String
    let section: String
}

struct StructuredGenerationSourceCard: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let location: StructuredGenerationSourceLocation
    let rights: StructuredGenerationSourceRights
    let contentHash: String
    let text: String
}

enum StructuredGenerationDifficulty: String, Equatable, Sendable {
    case beginner
    case intermediate
    case advanced
}

struct StructuredGenerationRequest: Equatable, Sendable {
    let conceptID: String
    let difficulty: StructuredGenerationDifficulty
    let swiftVersion: String
    let minimumIOSVersion: String
    let promptVersion: String
    let schemaVersion: Int
    let sourceCards: [StructuredGenerationSourceCard]
}

struct StructuredLessonArtifact: Equatable, Sendable {
    let title: String
    let learningObjective: String
    let explanation: String
    let exampleCode: String
    let citationIDs: [String]
}

struct StructuredGenerationChoice: Identifiable, Equatable, Sendable {
    let id: String
    let text: String
}

struct StructuredMultipleChoiceExercise: Equatable, Sendable {
    let prompt: String
    let choices: [StructuredGenerationChoice]
    let correctChoiceID: String
    let explanation: String
    let citationIDs: [String]
}

struct StructuredGenerationArtifact: Equatable, Sendable {
    let schemaVersion: Int
    let promptVersion: String
    let modelVersion: String
    let swiftVersion: String
    let minimumIOSVersion: String
    let lesson: StructuredLessonArtifact
    let exercise: StructuredMultipleChoiceExercise
}

enum StructuredGenerationAvailability: Equatable, Sendable {
    case available
    case unavailable(StructuredGenerationUnavailability)
}

enum StructuredGenerationUnavailability: Equatable, Sendable {
    case deviceNotSupported
    case intelligenceDisabled
    case modelNotReady
    case languageOrRegionUnsupported
    case other
}

enum StructuredGenerationClientFailure: Error, Equatable, Sendable {
    case contextWindowExceeded
    case safetyGuardrail
    case requestFailed
    case invalidResponse
    case unknown
}
#endif
