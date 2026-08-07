import Foundation
import Testing
@testable import DailySwift

struct GeneratedQuizChoiceOrdererTests {
    @Test("A fixed artifact identity produces one stable choice order")
    func fixedArtifactIdentityIsStable() {
        let artifactID = Self.artifactID(1)

        let firstOrder = GeneratedQuizChoiceOrderer.orderedChoices(
            Self.choices,
            artifactID: artifactID
        )
        let secondOrder = GeneratedQuizChoiceOrderer.orderedChoices(
            Self.choices,
            artifactID: artifactID
        )

        #expect(firstOrder == secondOrder)
    }

    @Test("Every generated order preserves exact choice identities")
    func everyOrderPreservesChoiceIdentities() {
        let expectedChoices = Self.choices.sorted { $0.id < $1.id }

        for index in 1...64 {
            let orderedChoices =
                GeneratedQuizChoiceOrderer.orderedChoices(
                    Self.choices,
                    artifactID: Self.artifactID(index)
                )

            #expect(
                orderedChoices.sorted { $0.id < $1.id }
                    == expectedChoices
            )
        }
    }

    @Test("Generated identities vary the correct answer position")
    func generatedIdentitiesVaryCorrectAnswerPosition() {
        let correctPositions = Set(
            (1...64).compactMap { index in
                GeneratedQuizChoiceOrderer.orderedChoices(
                    Self.choices,
                    artifactID: Self.artifactID(index)
                )
                .firstIndex { $0.id == Self.answerKeyChoiceID }
            }
        )

        #expect(correctPositions == Set(Self.choices.indices))
    }

    @Test("Generation persists one order and restoration never reshuffles it")
    func generatedOrderIsPersistedAndRestoredExactly() async throws {
        let candidate = GeneratedLearningTestFixtures.candidate(
            choices: Self.choices,
            answerKeyChoiceID: Self.answerKeyChoiceID
        )
        let artifactID = try #require(
            (1...64)
                .map(Self.artifactID)
                .first { artifactID in
                    GeneratedQuizChoiceOrderer.orderedChoices(
                        candidate.quiz.choices,
                        artifactID: artifactID
                    ) != candidate.quiz.choices
                }
        )
        let expectedChoices =
            GeneratedQuizChoiceOrderer.orderedChoices(
                candidate.quiz.choices,
                artifactID: artifactID
            )
        let sourceLibrary = SourceLibraryFixtures.service()
        let store = InMemoryGeneratedLearningStore()
        let generator = GeneratedLearningGenerator(
            retriever: DirectScanSourceRetriever(
                sourceLibrary: sourceLibrary
            ),
            sourceLibrary: sourceLibrary,
            provider: FixedGeneratedQuizProvider(candidate: candidate),
            store: store,
            now: { Date(timeIntervalSince1970: 1_785_200_000) },
            makeArtifactID: { artifactID }
        )

        let artifact = try await generator.generate(
            topic: "actor isolation",
            sourceIDs: [SourceLibraryFixtures.sourceID]
        )

        #expect(artifact.id == artifactID)
        #expect(artifact.quiz.choices == expectedChoices)
        #expect(artifact.quiz.choices != candidate.quiz.choices)
        #expect(
            artifact.quiz.answerKeyChoiceID
                == candidate.quiz.answerKeyChoiceID
        )
        #expect(
            artifact.quiz.choices.contains {
                $0.id == artifact.quiz.answerKeyChoiceID
            }
        )

        try await generator.commitArtifact(artifact)

        #expect(try await store.restore() == [artifact])
        #expect(try await generator.restore() == [artifact])
    }

    private static let answerKeyChoiceID = "choice-2"

    private static let choices = [
        GeneratedLearningQuizChoice(
            id: "choice-1",
            text: "Duplicate mutable state in every view"
        ),
        GeneratedLearningQuizChoice(
            id: answerKeyChoiceID,
            text: "Give mutable state one explicit owner"
        ),
        GeneratedLearningQuizChoice(
            id: "choice-3",
            text: "Use global state for every feature"
        ),
    ]

    private static func artifactID(_ index: Int) -> UUID {
        UUID(
            uuidString: String(
                format: "76000000-0000-0000-0000-%012d",
                index
            )
        )!
    }
}

private struct FixedGeneratedQuizProvider: LanguageModelProvider {
    let candidate: LanguageModelGeneratedCandidate

    func availability() async -> LanguageModelAvailability {
        .available
    }

    func generate(
        _ request: LanguageModelGenerationRequest
    ) async throws -> LanguageModelGeneratedCandidate {
        candidate
    }
}
