#if DEBUG
import Foundation

protocol StructuredGenerationClient: Sendable {
    func availability() async -> StructuredGenerationAvailability
    func generate(
        _ request: StructuredGenerationRequest
    ) async throws -> StructuredGenerationArtifact
}

enum StructuredGenerationFakeOutcome: Equatable, Sendable {
    case artifact(StructuredGenerationArtifact)
    case failure(StructuredGenerationClientFailure)
}

struct DeterministicStructuredGenerationClient: StructuredGenerationClient {
    let availabilityState: StructuredGenerationAvailability
    let outcome: StructuredGenerationFakeOutcome
    let delay: Duration

    init(
        availability: StructuredGenerationAvailability = .available,
        outcome: StructuredGenerationFakeOutcome,
        delay: Duration = .zero
    ) {
        availabilityState = availability
        self.outcome = outcome
        self.delay = delay
    }

    func availability() async -> StructuredGenerationAvailability {
        availabilityState
    }

    func generate(
        _ request: StructuredGenerationRequest
    ) async throws -> StructuredGenerationArtifact {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }

        switch outcome {
        case let .artifact(artifact):
            return artifact
        case let .failure(failure):
            throw failure
        }
    }
}
#endif
