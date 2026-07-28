import Testing
@testable import DailySwift

struct SeedCurriculumProviderTests {
    private let provider = SeedCurriculumProvider()

    @Test("The project seed is substantial, varied, linked, and valid")
    func projectSeedIsValid() throws {
        let catalog = try provider.loadCatalog()

        #expect(catalog.schemaVersion == LearningCatalog.currentSchemaVersion)
        #expect(catalog.articles.count == 6)
        #expect(catalog.challenges.count == 8)
        #expect(catalog.articles.allSatisfy { $0.trust == .projectSeed })
        #expect(
            Set(catalog.articles.map(\.domain))
                == Set(LearningDomain.allCases)
        )
        #expect(
            Set(catalog.challenges.map(\.domain))
                == Set(LearningDomain.allCases)
        )
        #expect(
            Set(catalog.challenges.map(\.kind))
                == Set(ChallengeKind.allCases)
        )
        #expect(
            LearningDomain.allCases.allSatisfy { domain in
                catalog.challenges.filter { $0.domain == domain }.count == 2
            }
        )

        for article in catalog.articles {
            let bodyLength = article.sections
                .map(\.body)
                .joined()
                .count

            #expect(article.sections.count >= 3)
            #expect(article.takeaways.count >= 3)
            #expect(bodyLength > 500)
            #expect(article.estimatedMinutes >= 4)
        }

        for challenge in catalog.challenges {
            #expect(catalog.article(id: challenge.relatedArticleID) != nil)
            #expect(
                challenge.validationCapability == .deterministic
            )
            #expect(
                Set(challenge.choices.map(\.id)).count
                    == challenge.choices.count
            )
        }

        #expect((4...6).contains(catalog.dailyPlan.steps.count))
        #expect((20...30).contains(catalog.dailyPlan.estimatedMinutes))
    }

    @Test("Duplicate catalog identities fail validation")
    func duplicateIdentifiersAreRejected() throws {
        let seed = try provider.loadCatalog()

        let duplicateArticleCatalog = LearningCatalog(
            articles: seed.articles + [seed.articles[0]],
            challenges: seed.challenges,
            dailyPlan: seed.dailyPlan
        )
        #expect(
            validationFailure(in: duplicateArticleCatalog)
                == .duplicateIdentifier(.article)
        )

        let duplicateChallengeCatalog = LearningCatalog(
            articles: seed.articles,
            challenges: seed.challenges + [seed.challenges[0]],
            dailyPlan: seed.dailyPlan
        )
        #expect(
            validationFailure(in: duplicateChallengeCatalog)
                == .duplicateIdentifier(.challenge)
        )

        let duplicateStepPlan = DailyLearningPlan(
            id: seed.dailyPlan.id,
            title: seed.dailyPlan.title,
            focus: seed.dailyPlan.focus,
            summary: seed.dailyPlan.summary,
            steps: seed.dailyPlan.steps + [seed.dailyPlan.steps[0]]
        )
        let duplicateStepCatalog = LearningCatalog(
            articles: seed.articles,
            challenges: seed.challenges,
            dailyPlan: duplicateStepPlan
        )
        #expect(
            validationFailure(in: duplicateStepCatalog)
                == .duplicateIdentifier(.dailyStep)
        )
    }

    @Test("Dangling challenge and daily-plan references fail validation")
    func danglingReferencesAreRejected() throws {
        let seed = try provider.loadCatalog()
        let challenge = seed.challenges[0]
        let danglingChallenge = replacing(
            challenge,
            relatedArticleID: "missing.article"
        )
        let danglingChallengeCatalog = LearningCatalog(
            articles: seed.articles,
            challenges: [danglingChallenge] + seed.challenges.dropFirst(),
            dailyPlan: seed.dailyPlan
        )

        #expect(
            validationFailure(in: danglingChallengeCatalog)
                == .missingRelatedArticle(
                    challengeID: challenge.id,
                    articleID: "missing.article"
                )
        )

        let unresolvedStep = DailyLearningStep(
            id: "daily.unresolved",
            title: "Unavailable challenge",
            detail: "This fixture deliberately points to missing content.",
            estimatedMinutes: 3,
            content: .challenge("missing.challenge")
        )
        let unresolvedPlan = DailyLearningPlan(
            id: seed.dailyPlan.id,
            title: seed.dailyPlan.title,
            focus: seed.dailyPlan.focus,
            summary: seed.dailyPlan.summary,
            steps: [unresolvedStep]
        )
        let unresolvedPlanCatalog = LearningCatalog(
            articles: seed.articles,
            challenges: seed.challenges,
            dailyPlan: unresolvedPlan
        )

        #expect(
            validationFailure(in: unresolvedPlanCatalog)
                == .unresolvedDailyStep(unresolvedStep.id)
        )
    }

    @Test("Insufficient and ambiguous choices fail validation")
    func invalidChoicesAreRejected() throws {
        let seed = try provider.loadCatalog()
        let challenge = seed.challenges[0]
        let singleChoice = replacing(
            challenge,
            choices: [challenge.choices[0]],
            correctChoiceID: challenge.choices[0].id
        )
        let singleChoiceCatalog = LearningCatalog(
            articles: seed.articles,
            challenges: [singleChoice] + seed.challenges.dropFirst(),
            dailyPlan: seed.dailyPlan
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
                challenge.choices[1]
            ],
            correctChoiceID: challenge.choices[0].id
        )
        let ambiguousChoiceCatalog = LearningCatalog(
            articles: seed.articles,
            challenges: [duplicatedCorrectChoice]
                + seed.challenges.dropFirst(),
            dailyPlan: seed.dailyPlan
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
