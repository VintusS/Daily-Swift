import Foundation
import SwiftData
import Testing
@testable import DailySwift

@MainActor
struct SwiftDataLearningProgressStoreTests {
    @Test("Learning evidence survives a store round trip")
    func roundTrip() async throws {
        let container = try LearningProgressStoreFactory
            .makeInMemoryContainer()
        let store = SwiftDataLearningProgressStore(
            modelContainer: container
        )
        let attempt = ChallengeAttempt(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            challengeID: "challenge.value-semantics",
            selectedChoiceID: "copy",
            isCorrect: true,
            attemptedAt: Date(timeIntervalSince1970: 100)
        )
        let activity = ArticleActivity(
            articleID: "article.value-semantics",
            isBookmarked: true,
            lastOpenedAt: Date(timeIntervalSince1970: 200),
            completedAt: Date(timeIntervalSince1970: 300)
        )
        let preferences = LearningPreferences(
            soundEnabled: true,
            hapticsEnabled: false,
            animationsEnabled: false,
            selectedTabIdentifier: "progress"
        )

        try await store.appendAttempt(attempt)
        try await store.updateArticleActivity(activity)
        try await store.updatePreferences(preferences)

        let reloadedStore = SwiftDataLearningProgressStore(
            modelContainer: container
        )
        let restored = try await reloadedStore.restore()

        #expect(restored.attempts == [attempt])
        #expect(restored.articleActivities == [activity])
        #expect(restored.preferences == preferences)
    }

    @Test("Attempt appends are historical and idempotent by UUID")
    func attemptsAreAppendOnlyAndIdempotent() async throws {
        let store = try makeStore()
        let firstID = UUID(
            uuidString: "22222222-2222-2222-2222-222222222222"
        )!
        let firstAttempt = ChallengeAttempt(
            id: firstID,
            challengeID: "challenge.optionals",
            selectedChoiceID: "if-let",
            isCorrect: true,
            attemptedAt: Date(timeIntervalSince1970: 100)
        )
        let conflictingDuplicate = ChallengeAttempt(
            id: firstID,
            challengeID: "challenge.changed",
            selectedChoiceID: "force-unwrap",
            isCorrect: false,
            attemptedAt: Date(timeIntervalSince1970: 50)
        )
        let laterAttempt = ChallengeAttempt(
            id: UUID(
                uuidString: "33333333-3333-3333-3333-333333333333"
            )!,
            challengeID: "challenge.optionals",
            selectedChoiceID: "guard-let",
            isCorrect: false,
            attemptedAt: Date(timeIntervalSince1970: 200)
        )

        try await store.appendAttempt(firstAttempt)
        try await store.appendAttempt(conflictingDuplicate)
        try await store.appendAttempt(laterAttempt)
        let restored = try await store.restore()

        #expect(restored.attempts == [firstAttempt, laterAttempt])
    }

    @Test("Article activity upserts by stable article identifier")
    func articleActivityUpserts() async throws {
        let store = try makeStore()
        let initialActivity = ArticleActivity(
            articleID: "article.observation",
            isBookmarked: false,
            lastOpenedAt: Date(timeIntervalSince1970: 100)
        )
        let updatedActivity = ArticleActivity(
            articleID: "article.observation",
            isBookmarked: true,
            lastOpenedAt: Date(timeIntervalSince1970: 200),
            completedAt: Date(timeIntervalSince1970: 300)
        )

        try await store.updateArticleActivity(initialActivity)
        try await store.updateArticleActivity(updatedActivity)
        let restored = try await store.restore()

        #expect(restored.articleActivities == [updatedActivity])
    }

    @Test("Opening an article records activity and tab in one save")
    func articleOpenIsAtomic() async throws {
        let store = try makeStore()
        let activity = ArticleActivity(
            articleID: "article.atomic-open",
            lastOpenedAt: Date(timeIntervalSince1970: 400)
        )
        let preferences = LearningPreferences(
            selectedTabIdentifier: "library"
        )

        try await store.recordArticleOpen(
            activity,
            preferences: preferences
        )
        let restored = try await store.restore()

        #expect(restored.articleActivities == [activity])
        #expect(restored.preferences == preferences)
    }

    @Test("Preferences use one mutable settings record")
    func preferencesRoundTrip() async throws {
        let container = try LearningProgressStoreFactory
            .makeInMemoryContainer()
        let store = SwiftDataLearningProgressStore(
            modelContainer: container
        )
        let firstPreferences = LearningPreferences(
            soundEnabled: true,
            hapticsEnabled: true,
            animationsEnabled: false,
            selectedTabIdentifier: "library"
        )
        let latestPreferences = LearningPreferences(
            soundEnabled: false,
            hapticsEnabled: false,
            animationsEnabled: true,
            selectedTabIdentifier: "challenges"
        )

        try await store.updatePreferences(firstPreferences)
        try await store.updatePreferences(latestPreferences)

        let restored = try await SwiftDataLearningProgressStore(
            modelContainer: container
        )
        .restore()

        #expect(restored.preferences == latestPreferences)

        let inspectionContext = ModelContext(container)
        let recordCount = try inspectionContext.fetchCount(
            FetchDescriptor<LearningPreferencesRecord>()
        )
        #expect(recordCount == 1)
    }

    @Test("Reset removes only learning-progress records")
    func resetIsScopedToLearningProgress() async throws {
        let container = try makeContainerWithSentinel()
        let store = SwiftDataLearningProgressStore(
            modelContainer: container
        )
        let sentinel = PersistenceSentinelRecord(
            identifier: "keep"
        )
        let inspectionContext = ModelContext(container)
        inspectionContext.insert(sentinel)
        try inspectionContext.save()

        try await store.appendAttempt(
            ChallengeAttempt(
                challengeID: "challenge.actors",
                selectedChoiceID: "isolated",
                isCorrect: true
            )
        )
        try await store.updateArticleActivity(
            ArticleActivity(
                articleID: "article.actors",
                isBookmarked: true
            )
        )
        try await store.updatePreferences(
            LearningPreferences(
                selectedTabIdentifier: "progress"
            )
        )

        try await store.reset()
        let restored = try await store.restore()

        #expect(restored == .empty)
        #expect(
            try inspectionContext.fetchCount(
                FetchDescriptor<PersistenceSentinelRecord>()
            ) == 1
        )
    }

    private func makeStore() throws
        -> SwiftDataLearningProgressStore {
        let container = try LearningProgressStoreFactory
            .makeInMemoryContainer()
        return SwiftDataLearningProgressStore(
            modelContainer: container
        )
    }

    private func makeContainerWithSentinel() throws -> ModelContainer {
        let schema = Schema(
            [
                LearningChallengeAttemptRecord.self,
                LearningArticleActivityRecord.self,
                LearningPreferencesRecord.self,
                PersistenceSentinelRecord.self,
            ],
            version: Schema.Version(1, 0, 0)
        )
        let configuration = ModelConfiguration(
            "LearningProgressResetTests",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            configurations: configuration
        )
    }
}

@Model
private final class PersistenceSentinelRecord {
    @Attribute(.unique) var identifier: String

    init(identifier: String) {
        self.identifier = identifier
    }
}
