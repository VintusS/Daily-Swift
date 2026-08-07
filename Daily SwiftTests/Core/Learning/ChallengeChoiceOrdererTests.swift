import Testing
@testable import DailySwift

struct ChallengeChoiceOrdererTests {
    private let catalog = LearningCatalogTestFixtures.catalog

    @Test("Every presentation preserves the exact choice identities")
    func preservesChoiceIdentities() throws {
        for challenge in catalog.challenges {
            let presentedChoices = ChallengeChoiceOrderer.orderedChoices(
                for: challenge,
                seed: 42
            )

            #expect(presentedChoices.count == challenge.choices.count)
            #expect(
                Set(presentedChoices.map(\.id))
                    == Set(challenge.choices.map(\.id))
            )
            #expect(
                presentedChoices.contains {
                    $0.id == challenge.correctChoiceID
                }
            )
        }
    }

    @Test("A fixed seed produces a stable presentation order")
    func fixedSeedIsStable() throws {
        let challenge = try #require(
            catalog.challenges.first
        )

        let firstOrder = ChallengeChoiceOrderer.orderedChoices(
            for: challenge,
            seed: 7
        )
        let secondOrder = ChallengeChoiceOrderer.orderedChoices(
            for: challenge,
            seed: 7
        )

        #expect(firstOrder == secondOrder)
    }

    @Test("Different presentations vary the correct answer position")
    func correctAnswerPositionVaries() throws {
        let challenge = try #require(
            catalog.challenges.first
        )

        let correctPositions = Set(
            (0..<64).compactMap { seed in
                ChallengeChoiceOrderer.orderedChoices(
                    for: challenge,
                    seed: UInt64(seed)
                )
                .firstIndex {
                    $0.id == challenge.correctChoiceID
                }
            }
        )

        #expect(correctPositions.count == challenge.choices.count)
    }
}
