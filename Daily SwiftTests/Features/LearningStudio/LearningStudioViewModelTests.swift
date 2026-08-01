import Foundation
import Testing
@testable import DailySwift

@MainActor
struct LearningStudioViewModelTests {
    private let catalog = SeedCurriculumProvider.catalog
    private let fixedDate = Date(timeIntervalSince1970: 1_785_200_000)
    private let fixedAttemptID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000201"
    )!

    @Test("Loading restores evidence and a valid selected tab")
    func loadRestoresSnapshot() async {
        let challenge = catalog.challenges[0]
        let snapshot = LearningProgressSnapshot(
            attempts: [
                ChallengeAttempt(
                    challengeID: challenge.id,
                    selectedChoiceID: challenge.correctChoiceID,
                    isCorrect: true,
                    attemptedAt: fixedDate
                ),
            ],
            preferences: LearningPreferences(
                selectedTabIdentifier:
                    LearningStudioTab.progress.rawValue
            )
        )
        let store = InMemoryLearningProgressStore(snapshot: snapshot)
        let viewModel = makeViewModel(store: store)

        viewModel.load()
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .ready(.persistent))
        #expect(viewModel.router.selectedTab == .progress)
        #expect(viewModel.isChallengeComplete(challenge.id))
    }

    @Test("An invalid selected tab falls back to Today")
    func invalidTabFallsBack() async {
        let store = InMemoryLearningProgressStore(
            snapshot: LearningProgressSnapshot(
                preferences: LearningPreferences(
                    selectedTabIdentifier: "removed-tab"
                )
            )
        )
        let viewModel = makeViewModel(store: store)

        viewModel.load()
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.router.selectedTab == .today)
        #expect(viewModel.state == .ready(.persistent))
    }

    @Test("A failed restore can retry without losing the primary store")
    func restoreRetry() async {
        let store = InMemoryLearningProgressStore(
            restoreOutcomes: [
                .failure(.readFailed),
                .success(()),
            ]
        )
        let viewModel = makeViewModel(store: store)

        viewModel.load()
        await viewModel.waitForCurrentOperation()
        #expect(viewModel.retryableFailure?.operation == .restore)

        viewModel.retry()
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .ready(.persistent))
    }

    @Test("A failed restore can continue in a labeled temporary session")
    func temporaryFallback() async {
        let store = InMemoryLearningProgressStore(
            restoreOutcomes: [.failure(.readFailed)]
        )
        let viewModel = makeViewModel(store: store)

        viewModel.load()
        await viewModel.waitForCurrentOperation()
        viewModel.continueTemporarily()

        let challenge = catalog.challenges[0]
        _ = viewModel.submitAnswer(
            challengeID: challenge.id,
            selectedChoiceID: challenge.correctChoiceID
        )
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .ready(.temporary))
        #expect(viewModel.isChallengeComplete(challenge.id))
    }

    @Test("An incompatible local store fails into recoverable temporary mode")
    func incompatibleStoreFallback() async {
        let store = UnavailableLearningProgressStore(
            failure: .initializationFailed
        )
        let viewModel = makeViewModel(store: store)

        viewModel.load()
        await viewModel.waitForCurrentOperation()

        #expect(
            viewModel.retryableFailure?.storeFailure
                == .initializationFailed
        )
        #expect(viewModel.retryableFailure?.canContinueTemporarily == true)

        viewModel.continueTemporarily()
        #expect(viewModel.state == .ready(.temporary))
    }

    @Test("Wrong and correct answers append exact deterministic evidence")
    func answerEvidence() async {
        let store = InMemoryLearningProgressStore()
        let viewModel = makeViewModel(store: store)
        viewModel.load()
        await viewModel.waitForCurrentOperation()
        let challenge = catalog.challenges[0]
        let wrongChoice = challenge.choices.first {
            $0.id != challenge.correctChoiceID
        }!

        _ = viewModel.submitAnswer(
            challengeID: challenge.id,
            selectedChoiceID: wrongChoice.id
        )
        await viewModel.waitForCurrentOperation()
        #expect(!viewModel.isChallengeComplete(challenge.id))

        _ = viewModel.submitAnswer(
            challengeID: challenge.id,
            selectedChoiceID: challenge.correctChoiceID
        )
        await viewModel.waitForCurrentOperation()

        let stored = await store.currentSnapshot()
        #expect(stored.attempts.count == 2)
        #expect(stored.attempts.filter(\.isCorrect).count == 1)
        #expect(viewModel.isChallengeComplete(challenge.id))
    }

    @Test("Generated completion is saved as activity but excluded from mastery")
    func generatedActivityDoesNotChangeMastery() async {
        let request = GeneratedLearningTestFixtures.request()
        let artifact = GeneratedLearningTestFixtures.artifact(
            request: request,
            candidate: GeneratedLearningTestFixtures.candidate(
                citationReferenceIDs: [request.sourceCards[0].id]
            )
        )
        let store = InMemoryLearningProgressStore()
        let viewModel = makeViewModel(store: store)
        viewModel.load()
        await viewModel.waitForCurrentOperation()

        _ = viewModel.submitGeneratedAnswer(
            artifact: artifact,
            selectedChoiceID: artifact.quiz.answerKeyChoiceID
        )
        await viewModel.waitForCurrentOperation()
        viewModel.markGeneratedArticleRead(
            artifact.articleID,
            isRead: true
        )
        await viewModel.waitForCurrentOperation()

        let stored = await store.currentSnapshot()
        #expect(stored.attempts.count == 1)
        #expect(stored.attempts[0].challengeID == artifact.quizID)
        #expect(!stored.attempts[0].isCorrect)
        #expect(
            stored.attempts[0].selectedChoiceID
                == artifact.quiz.answerKeyChoiceID
        )
        #expect(
            stored.activity(for: artifact.articleID).completedAt
                == fixedDate
        )
        #expect(viewModel.evidence.totalAttempts == 0)
        #expect(viewModel.evidence.correctAttempts == 0)
        #expect(
            !viewModel.evidence.completedChallengeIDs
                .contains(artifact.quizID)
        )
        #expect(
            !viewModel.evidence.readArticleIDs
                .contains(artifact.articleID)
        )

        let restoredViewModel = makeViewModel(store: store)
        restoredViewModel.load()
        await restoredViewModel.waitForCurrentOperation()

        #expect(restoredViewModel.snapshot.attempts.count == 1)
        #expect(
            restoredViewModel.snapshot.attempts[0].selectedChoiceID
                == artifact.quiz.answerKeyChoiceID
        )
        #expect(!restoredViewModel.snapshot.attempts[0].isCorrect)
        #expect(
            restoredViewModel.snapshot
                .activity(for: artifact.articleID).completedAt
                == fixedDate
        )
        #expect(restoredViewModel.evidence.totalAttempts == 0)
        #expect(restoredViewModel.evidence.correctAttempts == 0)
    }

    @Test("Retry reuses a failed attempt instead of duplicating it")
    func attemptRetryIsIdempotent() async {
        let store = InMemoryLearningProgressStore(
            writeOutcomes: [
                .failure(.writeFailed),
                .success(()),
            ]
        )
        let viewModel = makeViewModel(
            store: store,
            makeAttemptID: { self.fixedAttemptID }
        )
        viewModel.load()
        await viewModel.waitForCurrentOperation()
        let challenge = catalog.challenges[0]

        _ = viewModel.submitAnswer(
            challengeID: challenge.id,
            selectedChoiceID: challenge.correctChoiceID
        )
        await viewModel.waitForCurrentOperation()

        #expect(
            viewModel.retryableFailure?.operation == .appendAttempt
        )
        #expect(viewModel.feedback(for: challenge.id)?.wasSaved == false)
        #expect(!viewModel.isChallengeComplete(challenge.id))

        viewModel.retry()
        await viewModel.waitForCurrentOperation()

        let stored = await store.currentSnapshot()
        #expect(stored.attempts.count == 1)
        #expect(stored.attempts[0].id == fixedAttemptID)
        #expect(viewModel.feedback(for: challenge.id)?.wasSaved == true)
    }

    @Test("Article and preference mutations round trip through the store")
    func articleAndPreferencesPersist() async {
        let store = InMemoryLearningProgressStore()
        let viewModel = makeViewModel(store: store)
        viewModel.load()
        await viewModel.waitForCurrentOperation()
        let article = catalog.articles[0]

        viewModel.openArticle(article.id)
        await viewModel.waitForCurrentOperation()
        viewModel.setBookmark(article.id, isBookmarked: true)
        await viewModel.waitForCurrentOperation()
        viewModel.markArticleRead(article.id, isRead: true)
        await viewModel.waitForCurrentOperation()
        viewModel.selectTab(.library)
        await viewModel.waitForCurrentOperation()
        viewModel.setSoundEnabled(true)
        await viewModel.waitForCurrentOperation()

        let stored = await store.currentSnapshot()
        let activity = stored.activity(for: article.id)
        #expect(activity.isBookmarked)
        #expect(activity.completedAt == fixedDate)
        #expect(
            stored.preferences.selectedTabIdentifier
                == LearningStudioTab.library.rawValue
        )
        #expect(stored.preferences.soundEnabled)
    }

    @Test("Repeated bookmark intent stays stable behind a failed write")
    func bookmarkIntentDoesNotInvertBehindFailure() async {
        let store = InMemoryLearningProgressStore(
            writeOutcomes: [
                .failure(.writeFailed),
                .success(()),
                .success(()),
            ]
        )
        let viewModel = makeViewModel(store: store)
        viewModel.load()
        await viewModel.waitForCurrentOperation()
        let article = catalog.articles[0]

        viewModel.setBookmark(article.id, isBookmarked: true)
        await viewModel.waitForCurrentOperation()
        #expect(
            viewModel.retryableFailure?.operation
                == .updateArticleActivity
        )
        #expect(!viewModel.articleActivity(for: article.id).isBookmarked)

        viewModel.setBookmark(article.id, isBookmarked: true)
        viewModel.retry()
        await viewModel.waitForCurrentOperation()

        let stored = await store.currentSnapshot()
        #expect(stored.activity(for: article.id).isBookmarked)
        #expect(viewModel.articleActivity(for: article.id).isBookmarked)
    }

    @Test("Rapid tab and attempt writes drain in FIFO order")
    func rapidMutationsAreSerialized() async throws {
        let store = PreferenceGateLearningProgressStore()
        let viewModel = makeViewModel(store: store)
        viewModel.load()
        await viewModel.waitForCurrentOperation()
        let challenge = catalog.challenges[0]

        viewModel.selectTab(.challenges)
        await store.waitUntilPreferenceWriteStarts()
        _ = viewModel.submitAnswer(
            challengeID: challenge.id,
            selectedChoiceID: challenge.correctChoiceID
        )
        await store.releasePreferenceWrite()
        await viewModel.waitForCurrentOperation()

        let restored = try await store.restore()
        #expect(
            restored.preferences.selectedTabIdentifier
                == LearningStudioTab.challenges.rawValue
        )
        #expect(restored.attempts.count == 1)
        #expect(viewModel.isChallengeComplete(challenge.id))
    }

    @Test("The latest complete preference draft wins rapid updates")
    func completePreferenceDraftsAreSerialized() async {
        let store = InMemoryLearningProgressStore()
        let viewModel = makeViewModel(store: store)
        viewModel.load()
        await viewModel.waitForCurrentOperation()

        viewModel.setPreferences(
            LearningPreferences(
                soundEnabled: true,
                hapticsEnabled: true,
                animationsEnabled: true
            )
        )
        viewModel.setPreferences(
            LearningPreferences(
                soundEnabled: true,
                hapticsEnabled: false,
                animationsEnabled: false
            )
        )
        await viewModel.waitForCurrentOperation()

        let stored = await store.currentSnapshot()
        #expect(stored.preferences.soundEnabled)
        #expect(!stored.preferences.hapticsEnabled)
        #expect(!stored.preferences.animationsEnabled)
    }

    @Test("A field update preserves failed preference intent")
    func preferenceFieldUpdatePreservesFailedIntent() async {
        let store = InMemoryLearningProgressStore(
            writeOutcomes: [
                .failure(.writeFailed),
                .success(()),
                .success(()),
            ]
        )
        let viewModel = makeViewModel(store: store)
        viewModel.load()
        await viewModel.waitForCurrentOperation()

        viewModel.setSoundEnabled(true)
        await viewModel.waitForCurrentOperation()
        #expect(
            viewModel.retryableFailure?.operation
                == .updatePreferences
        )

        viewModel.setHapticsEnabled(true)
        viewModel.retry()
        await viewModel.waitForCurrentOperation()

        let stored = await store.currentSnapshot()
        #expect(stored.preferences.soundEnabled)
        #expect(stored.preferences.hapticsEnabled)
    }

    @Test("Reset waits for persistence before clearing visible evidence")
    func resetProgress() async {
        let challenge = catalog.challenges[0]
        let store = InMemoryLearningProgressStore(
            snapshot: LearningProgressSnapshot(
                attempts: [
                    ChallengeAttempt(
                        challengeID: challenge.id,
                        selectedChoiceID: challenge.correctChoiceID,
                        isCorrect: true,
                        attemptedAt: fixedDate
                    ),
                ]
            )
        )
        let viewModel = makeViewModel(store: store)
        viewModel.load()
        await viewModel.waitForCurrentOperation()

        viewModel.requestResetConfirmation()
        #expect(viewModel.isResetConfirmationPresented)
        viewModel.confirmReset()
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.snapshot == .empty)
        #expect(viewModel.router.selectedTab == .today)
        #expect(await store.currentSnapshot() == .empty)
    }

    @Test("Reset reports pending when an earlier write must retry")
    func resetWaitsBehindFailedMutation() async {
        let store = InMemoryLearningProgressStore(
            writeOutcomes: [
                .failure(.writeFailed),
                .success(()),
            ]
        )
        let viewModel = makeViewModel(store: store)
        viewModel.load()
        await viewModel.waitForCurrentOperation()

        viewModel.setSoundEnabled(true)
        await viewModel.waitForCurrentOperation()
        #expect(
            viewModel.retryableFailure?.operation == .updatePreferences
        )

        viewModel.requestResetConfirmation()
        let resetID = viewModel.confirmReset()
        #expect(resetID != nil)
        let didReset = if let resetID {
            await viewModel.waitForMutation(resetID)
        } else {
            false
        }

        #expect(!didReset)
        #expect(viewModel.isResetPending)
        #expect(viewModel.snapshot == .empty)

        viewModel.retry()
        await viewModel.waitForCurrentOperation()

        #expect(!viewModel.isResetPending)
        #expect(viewModel.snapshot == .empty)
        #expect(await store.currentSnapshot() == .empty)
    }

    private func makeViewModel(
        store: any LearningProgressStoring,
        makeAttemptID: @escaping @Sendable () -> UUID = UUID.init
    ) -> LearningStudioViewModel {
        LearningStudioViewModel(
            catalog: catalog,
            store: store,
            now: { fixedDate },
            makeAttemptID: makeAttemptID
        )
    }
}

private actor PreferenceGateLearningProgressStore:
    LearningProgressStoring {
    private var snapshot = LearningProgressSnapshot.empty
    private var preferenceWriteStarted = false
    private var preferenceWriteReleased = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func restore() async throws -> LearningProgressSnapshot {
        snapshot
    }

    func appendAttempt(_ attempt: ChallengeAttempt) async throws {
        guard !snapshot.attempts.contains(where: {
            $0.id == attempt.id
        }) else {
            return
        }
        snapshot.attempts.append(attempt)
    }

    func updateArticleActivity(
        _ activity: ArticleActivity
    ) async throws {
        snapshot.articleActivities.removeAll {
            $0.articleID == activity.articleID
        }
        snapshot.articleActivities.append(activity)
    }

    func recordArticleOpen(
        _ activity: ArticleActivity,
        preferences: LearningPreferences
    ) async throws {
        snapshot.preferences = preferences
        snapshot.articleActivities.removeAll {
            $0.articleID == activity.articleID
        }
        snapshot.articleActivities.append(activity)
    }

    func updatePreferences(
        _ preferences: LearningPreferences
    ) async throws {
        preferenceWriteStarted = true
        let startWaiters = self.startWaiters
        self.startWaiters.removeAll()
        startWaiters.forEach { $0.resume() }

        if !preferenceWriteReleased {
            await withCheckedContinuation { continuation in
                releaseWaiters.append(continuation)
            }
        }

        try Task.checkCancellation()
        snapshot.preferences = preferences
    }

    func reset() async throws {
        snapshot = .empty
    }

    func waitUntilPreferenceWriteStarts() async {
        guard !preferenceWriteStarted else {
            return
        }

        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func releasePreferenceWrite() {
        preferenceWriteReleased = true
        let releaseWaiters = self.releaseWaiters
        self.releaseWaiters.removeAll()
        releaseWaiters.forEach { $0.resume() }
    }
}
