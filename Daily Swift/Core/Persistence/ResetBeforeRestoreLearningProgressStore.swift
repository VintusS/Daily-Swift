import Foundation

actor ResetBeforeRestoreLearningProgressStore: LearningProgressStoring {
    private let base: any LearningProgressStoring
    private var shouldResetBeforeRestore: Bool

    init(
        base: any LearningProgressStoring,
        shouldResetBeforeRestore: Bool
    ) {
        self.base = base
        self.shouldResetBeforeRestore = shouldResetBeforeRestore
    }

    func restore() async throws -> LearningProgressSnapshot {
        if shouldResetBeforeRestore {
            try await base.reset()
            shouldResetBeforeRestore = false
        }
        return try await base.restore()
    }

    func appendAttempt(_ attempt: ChallengeAttempt) async throws {
        try await base.appendAttempt(attempt)
    }

    func updateArticleActivity(
        _ activity: ArticleActivity
    ) async throws {
        try await base.updateArticleActivity(activity)
    }

    func recordArticleOpen(
        _ activity: ArticleActivity,
        preferences: LearningPreferences
    ) async throws {
        try await base.recordArticleOpen(
            activity,
            preferences: preferences
        )
    }

    func updatePreferences(
        _ preferences: LearningPreferences
    ) async throws {
        try await base.updatePreferences(preferences)
    }

    func reset() async throws {
        try await base.reset()
    }
}
