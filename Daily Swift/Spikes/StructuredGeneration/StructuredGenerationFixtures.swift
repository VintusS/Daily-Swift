#if DEBUG
import Foundation

enum StructuredGenerationFixtures {
    static let sourceCards = [
        StructuredGenerationSourceCard(
            id: "main-actor-state",
            title: "Main-actor view-model state",
            location: StructuredGenerationSourceLocation(
                documentTitle: "Structured Generation Spike Fixture",
                section: "State isolation"
            ),
            rights: .projectAuthored,
            contentHash: "535e5d50fc1c363111a2c2035e9c7c1e754319fe014b4db0b8922d146147db82",
            text: """
            A UI-facing view model is isolated to the main actor. It updates one \
            explicit state value as an operation moves through availability, \
            loading, content, rejection, cancellation, and failure.
            """
        ),
        StructuredGenerationSourceCard(
            id: "stale-result-protection",
            title: "Stale-result protection",
            location: StructuredGenerationSourceLocation(
                documentTitle: "Structured Generation Spike Fixture",
                section: "Repeated requests"
            ),
            rights: .projectAuthored,
            contentHash: "68d1b609465457ca7473961e781e111348c6ceebeeee6fd5b9c1a4eb5d3c0927",
            text: """
            Each generation operation receives a unique identity. A result may \
            update visible state only while its identity still matches the active \
            operation, so an older response cannot replace a newer response.
            """
        ),
        StructuredGenerationSourceCard(
            id: "deterministic-validation",
            title: "Deterministic validation",
            location: StructuredGenerationSourceLocation(
                documentTitle: "Structured Generation Spike Fixture",
                section: "Artifact acceptance"
            ),
            rights: .projectAuthored,
            contentHash: "40e6f797aa9f8a9ed05697c6e8a1e022d53cb32c511917451205b5b13f6f23bd",
            text: """
            Generated artifacts are candidates until deterministic validation \
            confirms bounded fields, resolvable citations, distinct answer \
            choices, and exactly one referenced correct answer.
            """
        ),
        StructuredGenerationSourceCard(
            id: "cooperative-cancellation",
            title: "Cooperative cancellation",
            location: StructuredGenerationSourceLocation(
                documentTitle: "Structured Generation Spike Fixture",
                section: "Cancellation"
            ),
            rights: .projectAuthored,
            contentHash: "35a76a76025907dccdf1cfb9974bf4e91f93292b39263e21194dbe7508c9b95a",
            text: """
            Cancelling a generation task stops work cooperatively. The view \
            model also clears ownership of the cancelled operation so a client \
            that returns late cannot publish its result.
            """
        ),
    ]

    static let request = StructuredGenerationRequest(
        conceptID: "swift-concurrency.main-actor-state",
        difficulty: .intermediate,
        swiftVersion: "6",
        minimumIOSVersion: "26.0",
        promptVersion: "structured-generation-v1",
        schemaVersion: 1,
        sourceCards: sourceCards
    )

    static let validArtifact = StructuredGenerationArtifact(
        schemaVersion: 1,
        promptVersion: "structured-generation-v1",
        modelVersion: "deterministic-fixture-v1",
        swiftVersion: "6",
        minimumIOSVersion: "26.0",
        lesson: StructuredLessonArtifact(
            title: "Keep asynchronous UI state current",
            learningObjective: """
            Explain why a main-actor view model still needs to reject stale \
            asynchronous results.
            """,
            explanation: """
            Main-actor isolation serializes state mutations, but it does not \
            guarantee that asynchronous operations finish in the order they \
            started. Give each request an identity and accept its result only \
            while that identity remains active.
            """,
            exampleCode: """
            guard operationID == activeOperationID else { return }
            state = .content(artifact)
            """,
            citationIDs: [
                "main-actor-state",
                "stale-result-protection",
                "cooperative-cancellation",
            ]
        ),
        exercise: StructuredMultipleChoiceExercise(
            prompt: """
            What prevents an older generation response from replacing a newer \
            response?
            """,
            choices: [
                StructuredGenerationChoice(
                    id: "actor",
                    text: "Running every operation on the main actor"
                ),
                StructuredGenerationChoice(
                    id: "identity",
                    text: "Checking that the response still owns the active operation identity"
                ),
                StructuredGenerationChoice(
                    id: "delay",
                    text: "Adding the same delay to every request"
                ),
            ],
            correctChoiceID: "identity",
            explanation: """
            Actor isolation protects mutation, while the operation identity \
            protects ordering across suspension points.
            """,
            citationIDs: [
                "stale-result-protection",
                "deterministic-validation",
            ]
        )
    )

    static let invalidArtifact = StructuredGenerationArtifact(
        schemaVersion: 1,
        promptVersion: "structured-generation-v1",
        modelVersion: "deterministic-fixture-v1",
        swiftVersion: "6",
        minimumIOSVersion: "26.0",
        lesson: StructuredLessonArtifact(
            title: "Unchecked output",
            learningObjective: "Recognize output that must be rejected.",
            explanation: "This candidate deliberately omits provenance.",
            exampleCode: "state = .content(artifact)",
            citationIDs: []
        ),
        exercise: StructuredMultipleChoiceExercise(
            prompt: "Which answer is correct?",
            choices: [
                StructuredGenerationChoice(id: "first", text: "The same answer"),
                StructuredGenerationChoice(id: "second", text: "The same answer"),
            ],
            correctChoiceID: "missing",
            explanation: "The candidate does not identify a resolvable answer.",
            citationIDs: []
        )
    )

    static var validClient: DeterministicStructuredGenerationClient {
        DeterministicStructuredGenerationClient(
            outcome: .artifact(validArtifact)
        )
    }

    static var invalidClient: DeterministicStructuredGenerationClient {
        DeterministicStructuredGenerationClient(
            outcome: .artifact(invalidArtifact)
        )
    }
}
#endif
