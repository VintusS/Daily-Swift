@testable import DailySwift

enum LearningCatalogTestFixtures {
    static let article = LearningArticle(
        id: "fixture.article",
        domain: .swiftLanguage,
        title: "Fixture Article",
        summary: "A deterministic article used only by unit tests.",
        estimatedMinutes: 2,
        sections: [
            LearningArticleSection(
                id: "fixture.article.section",
                heading: "Fixture Section",
                body: """
                A stable body keeps catalog validation independent of \
                production learning content.
                """
            ),
        ],
        takeaways: ["Fixture takeaway"],
        trust: .reviewedCore
    )

    static let challenge = LearningChallenge(
        id: "fixture.challenge",
        domain: .swiftLanguage,
        title: "Fixture Challenge",
        kind: .multipleChoice,
        difficulty: .foundation,
        prompt: "Which choice is the deterministic fixture answer?",
        code: nil,
        choices: [
            ChallengeChoice(
                id: "correct",
                text: "The correct fixture choice"
            ),
            ChallengeChoice(
                id: "incorrect-a",
                text: "An incorrect fixture choice"
            ),
            ChallengeChoice(
                id: "incorrect-b",
                text: "Another incorrect fixture choice"
            ),
        ],
        correctChoiceID: "correct",
        explanation: "The fixture identifies the correct choice explicitly.",
        estimatedMinutes: 1,
        relatedArticleID: article.id,
        validationCapability: .deterministic
    )

    static let dailyPlan = DailyLearningPlan(
        id: "fixture.plan",
        title: "Fixture Plan",
        focus: "Fixture focus",
        summary: "A deterministic plan used only by unit tests.",
        steps: [
            DailyLearningStep(
                id: "fixture.plan.article",
                title: "Read fixture article",
                detail: "Open the fixture article.",
                estimatedMinutes: 2,
                content: .article(article.id)
            ),
            DailyLearningStep(
                id: "fixture.plan.challenge",
                title: "Complete fixture challenge",
                detail: "Answer the fixture challenge.",
                estimatedMinutes: 1,
                content: .challenge(challenge.id)
            ),
        ]
    )

    static let catalog = LearningCatalog(
        articles: [article],
        challenges: [challenge],
        dailyPlan: dailyPlan
    )
}
