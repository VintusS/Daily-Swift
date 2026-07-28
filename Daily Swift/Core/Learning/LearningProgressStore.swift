import Foundation

protocol LearningProgressStoring: Sendable {
    func restore() async throws -> LearningProgressSnapshot
    func appendAttempt(_ attempt: ChallengeAttempt) async throws
    func updateArticleActivity(_ activity: ArticleActivity) async throws
    func recordArticleOpen(
        _ activity: ArticleActivity,
        preferences: LearningPreferences
    ) async throws
    func updatePreferences(_ preferences: LearningPreferences) async throws
    func reset() async throws
}

actor InMemoryLearningProgressStore: LearningProgressStoring {
    private var snapshot: LearningProgressSnapshot
    private var restoreOutcomes: [Result<Void, LearningProgressStoreFailure>]
    private var writeOutcomes: [Result<Void, LearningProgressStoreFailure>]
    private var resetOutcomes: [Result<Void, LearningProgressStoreFailure>]

    init(
        snapshot: LearningProgressSnapshot = .empty,
        restoreOutcomes: [Result<Void, LearningProgressStoreFailure>] = [],
        writeOutcomes: [Result<Void, LearningProgressStoreFailure>] = [],
        resetOutcomes: [Result<Void, LearningProgressStoreFailure>] = []
    ) {
        self.snapshot = snapshot
        self.restoreOutcomes = restoreOutcomes
        self.writeOutcomes = writeOutcomes
        self.resetOutcomes = resetOutcomes
    }

    func restore() async throws -> LearningProgressSnapshot {
        try consume(&restoreOutcomes)
        return snapshot
    }

    func appendAttempt(_ attempt: ChallengeAttempt) async throws {
        try consume(&writeOutcomes)
        guard !snapshot.attempts.contains(where: { $0.id == attempt.id }) else {
            return
        }
        snapshot.attempts.append(attempt)
    }

    func updateArticleActivity(_ activity: ArticleActivity) async throws {
        try consume(&writeOutcomes)
        snapshot.articleActivities.removeAll {
            $0.articleID == activity.articleID
        }
        snapshot.articleActivities.append(activity)
    }

    func recordArticleOpen(
        _ activity: ArticleActivity,
        preferences: LearningPreferences
    ) async throws {
        try consume(&writeOutcomes)
        snapshot.preferences = preferences
        snapshot.articleActivities.removeAll {
            $0.articleID == activity.articleID
        }
        snapshot.articleActivities.append(activity)
    }

    func updatePreferences(_ preferences: LearningPreferences) async throws {
        try consume(&writeOutcomes)
        snapshot.preferences = preferences
    }

    func reset() async throws {
        try consume(&resetOutcomes)
        snapshot = .empty
    }

    func currentSnapshot() -> LearningProgressSnapshot {
        snapshot
    }

    private func consume(
        _ outcomes: inout [Result<Void, LearningProgressStoreFailure>]
    ) throws {
        guard !outcomes.isEmpty else {
            return
        }
        try outcomes.removeFirst().get()
    }
}

actor UnavailableLearningProgressStore: LearningProgressStoring {
    private let failure: LearningProgressStoreFailure

    init(failure: LearningProgressStoreFailure) {
        self.failure = failure
    }

    func restore() async throws -> LearningProgressSnapshot {
        throw failure
    }

    func appendAttempt(_ attempt: ChallengeAttempt) async throws {
        throw failure
    }

    func updateArticleActivity(_ activity: ArticleActivity) async throws {
        throw failure
    }

    func recordArticleOpen(
        _ activity: ArticleActivity,
        preferences: LearningPreferences
    ) async throws {
        throw failure
    }

    func updatePreferences(_ preferences: LearningPreferences) async throws {
        throw failure
    }

    func reset() async throws {
        throw failure
    }
}
