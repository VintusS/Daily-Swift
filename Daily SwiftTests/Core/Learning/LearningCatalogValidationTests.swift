import Testing
@testable import DailySwift

struct LearningCatalogValidationTests {
    private let catalog = LearningCatalogTestFixtures.catalog

    @Test("The generated-only production catalog contains no bundled learning")
    func generatedOnlyCatalogIsEmptyAndValid() throws {
        let generatedOnly = try LearningCatalog.generatedOnly.validated()

        #expect(
            generatedOnly.schemaVersion
                == LearningCatalog.currentSchemaVersion
        )
        #expect(generatedOnly.articles.isEmpty)
        #expect(generatedOnly.challenges.isEmpty)
        #expect(generatedOnly.dailyPlan.steps.isEmpty)
    }

    @Test("Duplicate catalog identities fail validation")
    func duplicateIdentifiersAreRejected() {
        let duplicateArticleCatalog = LearningCatalog(
            articles: catalog.articles + [catalog.articles[0]],
            challenges: catalog.challenges,
            dailyPlan: catalog.dailyPlan
        )
        #expect(
            validationFailure(in: duplicateArticleCatalog)
                == .duplicateIdentifier(.article)
        )

        let duplicateChallengeCatalog = LearningCatalog(
            articles: catalog.articles,
            challenges: catalog.challenges + [catalog.challenges[0]],
            dailyPlan: catalog.dailyPlan
        )
        #expect(
            validationFailure(in: duplicateChallengeCatalog)
                == .duplicateIdentifier(.challenge)
        )

        let duplicateStepPlan = DailyLearningPlan(
            id: catalog.dailyPlan.id,
            title: catalog.dailyPlan.title,
            focus: catalog.dailyPlan.focus,
            summary: catalog.dailyPlan.summary,
            steps: catalog.dailyPlan.steps + [catalog.dailyPlan.steps[0]]
        )
        let duplicateStepCatalog = LearningCatalog(
            articles: catalog.articles,
            challenges: catalog.challenges,
            dailyPlan: duplicateStepPlan
        )
        #expect(
            validationFailure(in: duplicateStepCatalog)
                == .duplicateIdentifier(.dailyStep)
        )
    }

    @Test("Dangling challenge and daily-plan references fail validation")
    func danglingReferencesAreRejected() {
        let challenge = catalog.challenges[0]
        let danglingChallenge = replacing(
            challenge,
            relatedArticleID: "missing.article"
        )
        let danglingChallengeCatalog = LearningCatalog(
            articles: catalog.articles,
            challenges: [danglingChallenge],
            dailyPlan: catalog.dailyPlan
        )

        #expect(
            validationFailure(in: danglingChallengeCatalog)
                == .missingRelatedArticle(
                    challengeID: challenge.id,
                    articleID: "missing.article"
                )
        )

        let unresolvedStep = DailyLearningStep(
            id: "fixture.unresolved",
            title: "Unavailable challenge",
            detail: "This fixture deliberately points to missing content.",
            estimatedMinutes: 1,
            content: .challenge("missing.challenge")
        )
        let unresolvedPlan = DailyLearningPlan(
            id: catalog.dailyPlan.id,
            title: catalog.dailyPlan.title,
            focus: catalog.dailyPlan.focus,
            summary: catalog.dailyPlan.summary,
            steps: [unresolvedStep]
        )
        let unresolvedPlanCatalog = LearningCatalog(
            articles: catalog.articles,
            challenges: catalog.challenges,
            dailyPlan: unresolvedPlan
        )

        #expect(
            validationFailure(in: unresolvedPlanCatalog)
                == .unresolvedDailyStep(unresolvedStep.id)
        )
    }

    @Test("Insufficient and ambiguous choices fail validation")
    func invalidChoicesAreRejected() {
        let challenge = catalog.challenges[0]
        let singleChoice = replacing(
            challenge,
            choices: [challenge.choices[0]],
            correctChoiceID: challenge.choices[0].id
        )
        let singleChoiceCatalog = LearningCatalog(
            articles: catalog.articles,
            challenges: [singleChoice],
            dailyPlan: catalog.dailyPlan
        )

        #expect(
            validationFailure(in: singleChoiceCatalog)
                == .insufficientChoices(challenge.id)
        )

        let duplicatedCorrectChoice = replacing(
            challenge,
            choices: [
                challenge.choices[0],
                challenge.choices[0],
                challenge.choices[1],
            ],
            correctChoiceID: challenge.choices[0].id
        )
        let ambiguousChoiceCatalog = LearningCatalog(
            articles: catalog.articles,
            challenges: [duplicatedCorrectChoice],
            dailyPlan: catalog.dailyPlan
        )

        #expect(
            validationFailure(in: ambiguousChoiceCatalog)
                == .invalidCorrectChoice(challenge.id)
        )
    }

    private func validationFailure(
        in catalog: LearningCatalog
    ) -> LearningCatalogValidationFailure? {
        do {
            _ = try catalog.validated()
            return nil
        } catch let failure as LearningCatalogValidationFailure {
            return failure
        } catch {
            return nil
        }
    }

    private func replacing(
        _ challenge: LearningChallenge,
        choices: [ChallengeChoice]? = nil,
        correctChoiceID: String? = nil,
        relatedArticleID: String? = nil
    ) -> LearningChallenge {
        LearningChallenge(
            id: challenge.id,
            domain: challenge.domain,
            title: challenge.title,
            kind: challenge.kind,
            difficulty: challenge.difficulty,
            prompt: challenge.prompt,
            code: challenge.code,
            choices: choices ?? challenge.choices,
            correctChoiceID: correctChoiceID
                ?? challenge.correctChoiceID,
            explanation: challenge.explanation,
            estimatedMinutes: challenge.estimatedMinutes,
            relatedArticleID: relatedArticleID
                ?? challenge.relatedArticleID,
            validationCapability: challenge.validationCapability
        )
    }
}
