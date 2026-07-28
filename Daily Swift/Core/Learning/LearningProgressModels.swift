import Foundation

struct ChallengeAttempt: Identifiable, Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let id: UUID
    let schemaVersion: Int
    let challengeID: String
    let selectedChoiceID: String
    let isCorrect: Bool
    let attemptedAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = Self.currentSchemaVersion,
        challengeID: String,
        selectedChoiceID: String,
        isCorrect: Bool,
        attemptedAt: Date = .now
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.challengeID = challengeID
        self.selectedChoiceID = selectedChoiceID
        self.isCorrect = isCorrect
        self.attemptedAt = attemptedAt
    }
}

struct ArticleActivity: Identifiable, Codable, Equatable, Sendable {
    let articleID: String
    var isBookmarked: Bool
    var lastOpenedAt: Date?
    var completedAt: Date?

    var id: String {
        articleID
    }

    init(
        articleID: String,
        isBookmarked: Bool = false,
        lastOpenedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.articleID = articleID
        self.isBookmarked = isBookmarked
        self.lastOpenedAt = lastOpenedAt
        self.completedAt = completedAt
    }
}

struct LearningPreferences: Codable, Equatable, Sendable {
    var soundEnabled: Bool
    var hapticsEnabled: Bool
    var animationsEnabled: Bool
    var selectedTabIdentifier: String

    init(
        soundEnabled: Bool = false,
        hapticsEnabled: Bool = true,
        animationsEnabled: Bool = true,
        selectedTabIdentifier: String = "today"
    ) {
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        self.animationsEnabled = animationsEnabled
        self.selectedTabIdentifier = selectedTabIdentifier
    }
}

struct LearningProgressSnapshot: Equatable, Sendable {
    var attempts: [ChallengeAttempt]
    var articleActivities: [ArticleActivity]
    var preferences: LearningPreferences

    init(
        attempts: [ChallengeAttempt] = [],
        articleActivities: [ArticleActivity] = [],
        preferences: LearningPreferences = LearningPreferences()
    ) {
        self.attempts = attempts
        self.articleActivities = articleActivities
        self.preferences = preferences
    }

    static let empty = LearningProgressSnapshot()

    func activity(for articleID: String) -> ArticleActivity {
        articleActivities.first { $0.articleID == articleID }
            ?? ArticleActivity(articleID: articleID)
    }
}

enum ChallengeFeedbackStorage: Equatable, Sendable {
    case pending
    case saved
    case temporary
    case failed
}

struct ChallengeFeedback: Equatable, Sendable {
    let attemptID: UUID
    let challengeID: String
    let selectedChoiceID: String
    let isCorrect: Bool
    let explanation: String
    let storage: ChallengeFeedbackStorage

    var wasSaved: Bool {
        storage == .saved
    }
}

struct DomainEvidenceSummary: Identifiable, Equatable, Sendable {
    let domain: LearningDomain
    let completedChallenges: Int
    let totalChallenges: Int
    let readArticles: Int
    let totalArticles: Int
    let correctAttempts: Int
    let totalAttempts: Int

    var id: LearningDomain {
        domain
    }

    var completionFraction: Double {
        let completed = completedChallenges + readArticles
        let total = totalChallenges + totalArticles
        guard total > 0 else {
            return 0
        }
        return Double(completed) / Double(total)
    }
}

struct LearningEvidenceSummary: Equatable, Sendable {
    let completedChallengeIDs: Set<String>
    let readArticleIDs: Set<String>
    let totalAttempts: Int
    let correctAttempts: Int
    let completedDailyStepIDs: Set<String>
    let domains: [DomainEvidenceSummary]

    var completedDailyStepCount: Int {
        completedDailyStepIDs.count
    }

    var accuracyFraction: Double? {
        guard totalAttempts > 0 else {
            return nil
        }
        return Double(correctAttempts) / Double(totalAttempts)
    }
}

enum LearningProgressStoreFailure: Error, Equatable, Sendable {
    case initializationFailed
    case readFailed
    case writeFailed
    case resetFailed

    var title: String {
        switch self {
        case .initializationFailed:
            "Learning data is unavailable"
        case .readFailed:
            "Progress could not be restored"
        case .writeFailed:
            "Your latest change was not saved"
        case .resetFailed:
            "Progress could not be reset"
        }
    }

    var message: String {
        switch self {
        case .initializationFailed:
            "You can retry or continue in a clearly marked temporary session."
        case .readFailed:
            "Your stored data was left unchanged. Try restoring it again."
        case .writeFailed:
            "The learning activity remains visible for now. Retry before leaving the app."
        case .resetFailed:
            "No stored learning evidence was intentionally removed."
        }
    }
}
