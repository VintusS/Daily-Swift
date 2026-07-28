import Foundation
import SwiftData

enum LearningProgressSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            LearningChallengeAttemptRecord.self,
            LearningArticleActivityRecord.self,
            LearningPreferencesRecord.self,
        ]
    }
}

@Model
final class LearningChallengeAttemptRecord {
    @Attribute(.unique) var attemptID: UUID
    var schemaVersion: Int
    var challengeID: String
    var selectedChoiceID: String
    var isCorrect: Bool
    var attemptedAt: Date

    init(attempt: ChallengeAttempt) {
        attemptID = attempt.id
        schemaVersion = attempt.schemaVersion
        challengeID = attempt.challengeID
        selectedChoiceID = attempt.selectedChoiceID
        isCorrect = attempt.isCorrect
        attemptedAt = attempt.attemptedAt
    }

    var domainModel: ChallengeAttempt {
        ChallengeAttempt(
            id: attemptID,
            schemaVersion: schemaVersion,
            challengeID: challengeID,
            selectedChoiceID: selectedChoiceID,
            isCorrect: isCorrect,
            attemptedAt: attemptedAt
        )
    }
}

@Model
final class LearningArticleActivityRecord {
    @Attribute(.unique) var articleID: String
    var isBookmarked: Bool
    var lastOpenedAt: Date?
    var completedAt: Date?

    init(activity: ArticleActivity) {
        articleID = activity.articleID
        isBookmarked = activity.isBookmarked
        lastOpenedAt = activity.lastOpenedAt
        completedAt = activity.completedAt
    }

    func update(with activity: ArticleActivity) {
        isBookmarked = activity.isBookmarked
        lastOpenedAt = activity.lastOpenedAt
        completedAt = activity.completedAt
    }

    var domainModel: ArticleActivity {
        ArticleActivity(
            articleID: articleID,
            isBookmarked: isBookmarked,
            lastOpenedAt: lastOpenedAt,
            completedAt: completedAt
        )
    }
}

@Model
final class LearningPreferencesRecord {
    @Attribute(.unique) var recordID: String
    var soundEnabled: Bool
    var hapticsEnabled: Bool
    var animationsEnabled: Bool
    var selectedTabIdentifier: String

    init(
        recordID: String,
        preferences: LearningPreferences
    ) {
        self.recordID = recordID
        soundEnabled = preferences.soundEnabled
        hapticsEnabled = preferences.hapticsEnabled
        animationsEnabled = preferences.animationsEnabled
        selectedTabIdentifier = preferences.selectedTabIdentifier
    }

    func update(with preferences: LearningPreferences) {
        soundEnabled = preferences.soundEnabled
        hapticsEnabled = preferences.hapticsEnabled
        animationsEnabled = preferences.animationsEnabled
        selectedTabIdentifier = preferences.selectedTabIdentifier
    }

    var domainModel: LearningPreferences {
        LearningPreferences(
            soundEnabled: soundEnabled,
            hapticsEnabled: hapticsEnabled,
            animationsEnabled: animationsEnabled,
            selectedTabIdentifier: selectedTabIdentifier
        )
    }
}
