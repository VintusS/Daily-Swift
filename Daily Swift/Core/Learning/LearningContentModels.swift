import Foundation

enum LearningDomain: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case swiftLanguage
    case swiftUI
    case concurrency
    case appArchitecture

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .swiftLanguage:
            "Swift"
        case .swiftUI:
            "SwiftUI"
        case .concurrency:
            "Concurrency"
        case .appArchitecture:
            "App Architecture"
        }
    }

    var symbolName: String {
        switch self {
        case .swiftLanguage:
            "swift"
        case .swiftUI:
            "rectangle.3.group"
        case .concurrency:
            "arrow.trianglehead.2.clockwise.rotate.90"
        case .appArchitecture:
            "square.3.layers.3d"
        }
    }
}

enum LearningContentTrust: String, Codable, Hashable, Sendable {
    case projectSeed
    case reviewedCore

    var label: String {
        switch self {
        case .projectSeed:
            "Project Seed"
        case .reviewedCore:
            "Reviewed Core"
        }
    }
}

enum ChallengeKind: String, CaseIterable, Codable, Hashable, Sendable {
    case multipleChoice
    case predictOutput
    case spotTheIssue

    var label: String {
        switch self {
        case .multipleChoice:
            "Multiple choice"
        case .predictOutput:
            "Predict output"
        case .spotTheIssue:
            "Spot the issue"
        }
    }

    var symbolName: String {
        switch self {
        case .multipleChoice:
            "checklist"
        case .predictOutput:
            "text.terminal"
        case .spotTheIssue:
            "ladybug"
        }
    }
}

enum ChallengeDifficulty: String, CaseIterable, Codable, Hashable, Sendable {
    case foundation
    case applied
    case stretch

    var label: String {
        rawValue.capitalized
    }
}

enum ValidationCapability: String, Codable, Hashable, Sendable {
    case deterministic

    var label: String {
        "Deterministically validated"
    }
}

struct LearningArticleSection: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let heading: String
    let body: String
    let code: String?

    init(
        id: String,
        heading: String,
        body: String,
        code: String? = nil
    ) {
        self.id = id
        self.heading = heading
        self.body = body
        self.code = code
    }
}

struct LearningArticle: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let domain: LearningDomain
    let title: String
    let summary: String
    let estimatedMinutes: Int
    let sections: [LearningArticleSection]
    let takeaways: [String]
    let trust: LearningContentTrust
}

struct ChallengeChoice: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let text: String
}

struct LearningChallenge: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let domain: LearningDomain
    let title: String
    let kind: ChallengeKind
    let difficulty: ChallengeDifficulty
    let prompt: String
    let code: String?
    let choices: [ChallengeChoice]
    let correctChoiceID: String
    let explanation: String
    let estimatedMinutes: Int
    let relatedArticleID: String
    let validationCapability: ValidationCapability
}

enum DailyLearningStepContent: Codable, Hashable, Sendable {
    case article(String)
    case challenge(String)

    var identifier: String {
        switch self {
        case let .article(identifier), let .challenge(identifier):
            identifier
        }
    }
}

struct DailyLearningStep: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let estimatedMinutes: Int
    let content: DailyLearningStepContent
}

struct DailyLearningPlan: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let focus: String
    let summary: String
    let steps: [DailyLearningStep]

    var estimatedMinutes: Int {
        steps.reduce(0) { $0 + $1.estimatedMinutes }
    }
}

struct LearningCatalog: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let articles: [LearningArticle]
    let challenges: [LearningChallenge]
    let dailyPlan: DailyLearningPlan

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        articles: [LearningArticle],
        challenges: [LearningChallenge],
        dailyPlan: DailyLearningPlan
    ) {
        self.schemaVersion = schemaVersion
        self.articles = articles
        self.challenges = challenges
        self.dailyPlan = dailyPlan
    }

    func article(id: String) -> LearningArticle? {
        articles.first { $0.id == id }
    }

    func challenge(id: String) -> LearningChallenge? {
        challenges.first { $0.id == id }
    }

    func validated() throws -> LearningCatalog {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw LearningCatalogValidationFailure.unsupportedSchema(
                schemaVersion
            )
        }

        try Self.requireUnique(
            articles.map(\.id),
            kind: .article
        )
        try Self.requireUnique(
            challenges.map(\.id),
            kind: .challenge
        )
        try Self.requireUnique(
            dailyPlan.steps.map(\.id),
            kind: .dailyStep
        )

        for article in articles {
            guard !article.title.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty,
            !article.sections.isEmpty else {
                throw LearningCatalogValidationFailure.emptyArticle(article.id)
            }
        }

        for challenge in challenges {
            guard challenge.choices.count >= 2 else {
                throw LearningCatalogValidationFailure.insufficientChoices(
                    challenge.id
                )
            }
            guard challenge.choices.filter({
                $0.id == challenge.correctChoiceID
            }).count == 1 else {
                throw LearningCatalogValidationFailure.invalidCorrectChoice(
                    challenge.id
                )
            }
            guard article(id: challenge.relatedArticleID) != nil else {
                throw LearningCatalogValidationFailure.missingRelatedArticle(
                    challengeID: challenge.id,
                    articleID: challenge.relatedArticleID
                )
            }
        }

        for step in dailyPlan.steps {
            switch step.content {
            case let .article(identifier):
                guard article(id: identifier) != nil else {
                    throw LearningCatalogValidationFailure.unresolvedDailyStep(
                        step.id
                    )
                }
            case let .challenge(identifier):
                guard challenge(id: identifier) != nil else {
                    throw LearningCatalogValidationFailure.unresolvedDailyStep(
                        step.id
                    )
                }
            }
        }

        return self
    }

    private static func requireUnique(
        _ identifiers: [String],
        kind: LearningCatalogItemKind
    ) throws {
        guard Set(identifiers).count == identifiers.count else {
            throw LearningCatalogValidationFailure.duplicateIdentifier(kind)
        }
    }
}

enum LearningCatalogItemKind: String, Codable, Equatable, Sendable {
    case article
    case challenge
    case dailyStep
}

enum LearningCatalogValidationFailure: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
    case duplicateIdentifier(LearningCatalogItemKind)
    case emptyArticle(String)
    case insufficientChoices(String)
    case invalidCorrectChoice(String)
    case missingRelatedArticle(challengeID: String, articleID: String)
    case unresolvedDailyStep(String)
}
