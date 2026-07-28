import Foundation
import Testing
@testable import DailySwift

struct LearningProgressProjectorTests {
    private let provider = SeedCurriculumProvider()
    private let eventDate = Date(timeIntervalSince1970: 1_000)

    @Test("An empty snapshot produces no completed evidence")
    func emptySnapshotHasNoCompletedEvidence() throws {
        let catalog = try provider.loadCatalog()
        let summary = LearningProgressProjector.evidence(
            catalog: catalog,
            snapshot: .empty
        )

        #expect(summary.completedChallengeIDs.isEmpty)
        #expect(summary.readArticleIDs.isEmpty)
        #expect(summary.completedDailyStepIDs.isEmpty)
        #expect(summary.totalAttempts == 0)
        #expect(summary.correctAttempts == 0)
        #expect(summary.accuracyFraction == nil)
        #expect(summary.domains.count == LearningDomain.allCases.count)
    }

    @Test("Only catalog-backed evidence contributes to projection")
    func projectionIgnoresUnknownContent() throws {
        let catalog = try provider.loadCatalog()
        let challenge = try #require(catalog.challenges.first)
        let article = try #require(catalog.articles.first)
        let snapshot = LearningProgressSnapshot(
            attempts: [
                correctAttempt(for: challenge),
                ChallengeAttempt(
                    challengeID: "missing.challenge",
                    selectedChoiceID: "missing.choice",
                    isCorrect: true,
                    attemptedAt: eventDate
                )
            ],
            articleActivities: [
                ArticleActivity(
                    articleID: article.id,
                    completedAt: eventDate
                ),
                ArticleActivity(
                    articleID: "missing.article",
                    completedAt: eventDate
                )
            ]
        )

        let summary = LearningProgressProjector.evidence(
            catalog: catalog,
            snapshot: snapshot
        )

        #expect(summary.completedChallengeIDs == [challenge.id])
        #expect(summary.readArticleIDs == [article.id])
        #expect(summary.totalAttempts == 1)
        #expect(summary.correctAttempts == 1)
    }

    @Test("Wrong then correct attempts preserve both pieces of evidence")
    func wrongThenCorrectEvidence() throws {
        let catalog = try provider.loadCatalog()
        let challenge = try #require(
            catalog.challenge(id: "swift.value-copy-output")
        )
        let wrongChoice = try #require(
            challenge.choices.first {
                $0.id != challenge.correctChoiceID
            }
        )
        let wrongAttempt = ChallengeAttempt(
            challengeID: challenge.id,
            selectedChoiceID: wrongChoice.id,
            isCorrect: false,
            attemptedAt: eventDate
        )
        let wrongSummary = LearningProgressProjector.evidence(
            catalog: catalog,
            snapshot: LearningProgressSnapshot(
                attempts: [wrongAttempt]
            )
        )

        #expect(
            !wrongSummary.completedChallengeIDs.contains(challenge.id)
        )
        #expect(wrongSummary.totalAttempts == 1)
        #expect(wrongSummary.correctAttempts == 0)

        let correctAttempt = correctAttempt(for: challenge)
        let recoveredSummary = LearningProgressProjector.evidence(
            catalog: catalog,
            snapshot: LearningProgressSnapshot(
                attempts: [wrongAttempt, correctAttempt]
            )
        )

        #expect(
            recoveredSummary.completedChallengeIDs.contains(challenge.id)
        )
        #expect(recoveredSummary.totalAttempts == 2)
        #expect(recoveredSummary.correctAttempts == 1)
        #expect(recoveredSummary.accuracyFraction == 0.5)
    }

    @Test("Completing every ordered step completes the daily plan")
    func dailyPlanCompletion() throws {
        let catalog = try provider.loadCatalog()
        var attempts: [ChallengeAttempt] = []
        var activities: [ArticleActivity] = []

        for step in catalog.dailyPlan.steps {
            switch step.content {
            case let .article(identifier):
                activities.append(
                    ArticleActivity(
                        articleID: identifier,
                        lastOpenedAt: eventDate,
                        completedAt: eventDate
                    )
                )
            case let .challenge(identifier):
                let challenge = try #require(
                    catalog.challenge(id: identifier)
                )
                attempts.append(correctAttempt(for: challenge))
            }
        }

        let summary = LearningProgressProjector.evidence(
            catalog: catalog,
            snapshot: LearningProgressSnapshot(
                attempts: attempts,
                articleActivities: activities
            )
        )
        let expectedStepIDs = Set(catalog.dailyPlan.steps.map(\.id))

        #expect(summary.completedDailyStepIDs == expectedStepIDs)
        #expect(
            summary.completedDailyStepCount
                == catalog.dailyPlan.steps.count
        )
    }

    private func correctAttempt(
        for challenge: LearningChallenge
    ) -> ChallengeAttempt {
        ChallengeAttempt(
            challengeID: challenge.id,
            selectedChoiceID: challenge.correctChoiceID,
            isCorrect: true,
            attemptedAt: eventDate
        )
    }
}
