import Foundation
import Observation

enum LearningStudioSessionMode: Equatable, Sendable {
    case persistent
    case temporary
}

enum LearningStudioFailedOperation: Equatable, Sendable {
    case restore
    case appendAttempt
    case updateArticleActivity
    case updatePreferences
    case reset
}

struct LearningStudioRetryableFailure: Equatable, Sendable {
    let storeFailure: LearningProgressStoreFailure
    let operation: LearningStudioFailedOperation
    let sessionMode: LearningStudioSessionMode

    var title: String {
        storeFailure.title
    }

    var message: String {
        storeFailure.message
    }

    var canContinueTemporarily: Bool {
        operation == .restore && sessionMode == .persistent
    }
}

enum LearningStudioState: Equatable, Sendable {
    case loading
    case ready(LearningStudioSessionMode)
    case retryableFailure(LearningStudioRetryableFailure)
}

@MainActor
@Observable
final class LearningStudioViewModel {
    private(set) var state: LearningStudioState = .loading
    private(set) var snapshot: LearningProgressSnapshot = .empty
    private(set) var feedbackByChallengeID: [String: ChallengeFeedback] = [:]
    private(set) var isSaving = false
    private(set) var isResetConfirmationPresented = false

    let catalog: LearningCatalog
    let router: LearningStudioRouter

    @ObservationIgnored
    private let primaryStore: any LearningProgressStoring

    @ObservationIgnored
    private var activeStore: any LearningProgressStoring

    @ObservationIgnored
    private let now: @Sendable () -> Date

    @ObservationIgnored
    private let makeAttemptID: @Sendable () -> UUID

    @ObservationIgnored
    private var activeOperation: Task<Void, Never>?

    @ObservationIgnored
    private var activeOperationID: UUID?

    @ObservationIgnored
    private var mutationQueue: [QueuedLearningMutation] = []

    @ObservationIgnored
    private var projectedSnapshot: LearningProgressSnapshot = .empty

    init(
        catalog: LearningCatalog,
        store: any LearningProgressStoring,
        router: LearningStudioRouter = LearningStudioRouter(),
        now: @escaping @Sendable () -> Date = { .now },
        makeAttemptID: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.catalog = catalog
        primaryStore = store
        activeStore = store
        self.router = router
        self.now = now
        self.makeAttemptID = makeAttemptID
    }

    var evidence: LearningEvidenceSummary {
        LearningProgressProjector.evidence(
            catalog: catalog,
            snapshot: snapshot
        )
    }

    var dailyPlan: DailyLearningPlan {
        catalog.dailyPlan
    }

    var articles: [LearningArticle] {
        catalog.articles
    }

    var challenges: [LearningChallenge] {
        catalog.challenges
    }

    var preferences: LearningPreferences {
        snapshot.preferences
    }

    var sessionMode: LearningStudioSessionMode {
        switch state {
        case .loading:
            .persistent
        case let .ready(mode):
            mode
        case let .retryableFailure(failure):
            failure.sessionMode
        }
    }

    var retryableFailure: LearningStudioRetryableFailure? {
        guard case let .retryableFailure(failure) = state else {
            return nil
        }
        return failure
    }

    var isResetPending: Bool {
        mutationQueue.contains {
            if case .reset = $0.mutation {
                return true
            }
            return false
        }
    }

    var nextDailyStep: DailyLearningStep? {
        dailyPlan.steps.first {
            !evidence.completedDailyStepIDs.contains($0.id)
        }
    }

    var completedDailyStepCount: Int {
        evidence.completedDailyStepCount
    }

    func article(id: String) -> LearningArticle? {
        catalog.article(id: id)
    }

    func challenge(id: String) -> LearningChallenge? {
        catalog.challenge(id: id)
    }

    func articleActivity(for articleID: String) -> ArticleActivity {
        snapshot.activity(for: articleID)
    }

    func isChallengeComplete(_ challengeID: String) -> Bool {
        evidence.completedChallengeIDs.contains(challengeID)
    }

    func feedback(for challengeID: String) -> ChallengeFeedback? {
        feedbackByChallengeID[challengeID]
    }

    func ownsRetryableAttemptFailure(
        challengeID: String
    ) -> Bool {
        guard retryableFailure?.operation == .appendAttempt,
              let queuedMutation = mutationQueue.first,
              case let .appendAttempt(attempt) =
                  queuedMutation.mutation,
              attempt.challengeID == challengeID,
              let feedback = feedbackByChallengeID[challengeID],
              feedback.attemptID == attempt.id else {
            return false
        }
        return feedback.storage == .failed
            || feedback.storage == .pending
    }

    func load() {
        cancelActiveOperation()
        mutationQueue.removeAll()
        state = .loading
        isSaving = false

        let operationID = UUID()
        activeOperationID = operationID
        let store = activeStore

        activeOperation = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let restored = try await store.restore()
                guard isActive(operationID) else {
                    return
                }

                snapshot = restored
                projectedSnapshot = restored
                let selectedTab = LearningStudioTab(
                    rawValue: restored.preferences.selectedTabIdentifier
                ) ?? .today
                router.selectedTab = selectedTab
                finish(
                    operationID,
                    state: .ready(.persistent)
                )
            } catch let failure as LearningProgressStoreFailure {
                fail(
                    operationID,
                    storeFailure: failure,
                    operation: .restore,
                    mode: .persistent
                )
            } catch {
                fail(
                    operationID,
                    storeFailure: .readFailed,
                    operation: .restore,
                    mode: .persistent
                )
            }
        }
    }

    func retry() {
        guard let failure = retryableFailure else {
            return
        }

        if failure.operation == .restore {
            activeStore = primaryStore
            load()
            return
        }

        guard !mutationQueue.isEmpty else {
            return
        }
        markAttemptPendingIfNeeded(mutationQueue[0].mutation)
        startMutationDrain()
    }

    func continueTemporarily() {
        guard retryableFailure?.canContinueTemporarily == true else {
            return
        }

        cancelActiveOperation()
        mutationQueue.removeAll()
        snapshot = .empty
        projectedSnapshot = .empty
        router.selectedTab = .today
        router.resetPaths()
        activeStore = InMemoryLearningProgressStore(snapshot: snapshot)
        state = .ready(.temporary)
    }

    func selectTab(_ tab: LearningStudioTab) {
        guard !isResetPending,
              tab != router.selectedTab else {
            return
        }

        router.selectedTab = tab
        var updated = projectedSnapshot.preferences
        updated.selectedTabIdentifier = tab.rawValue
        updatePreferences(updated)
    }

    func openArticle(_ articleID: String) {
        guard !isResetPending,
              article(id: articleID) != nil else {
            return
        }

        router.openArticle(articleID)
        var activity = projectedSnapshot.activity(for: articleID)
        activity.lastOpenedAt = now()
        var preferences = projectedSnapshot.preferences
        preferences.selectedTabIdentifier =
            LearningStudioTab.library.rawValue
        persist(
            .openArticle(
                activity: activity,
                preferences: preferences
            ),
            operation: .updateArticleActivity,
            mode: sessionMode,
            appliesOptimistically: true
        )
    }

    func openChallenge(_ challengeID: String) {
        guard !isResetPending,
              challenge(id: challengeID) != nil else {
            return
        }
        selectTab(.challenges)
        router.openChallenge(challengeID)
    }

    func openGeneratedLearning() {
        guard !isResetPending else {
            return
        }
        selectTab(.library)
        router.openGeneratedLearning()
    }

    func openGeneratedArticle(_ artifact: GeneratedLearningArtifact) {
        guard !isResetPending else {
            return
        }
        router.openGeneratedArticle(artifact.id)
        var activity = projectedSnapshot.activity(for: artifact.articleID)
        activity.lastOpenedAt = now()
        var preferences = projectedSnapshot.preferences
        preferences.selectedTabIdentifier =
            LearningStudioTab.library.rawValue
        persist(
            .openArticle(
                activity: activity,
                preferences: preferences
            ),
            operation: .updateArticleActivity,
            mode: sessionMode,
            appliesOptimistically: true
        )
    }

    func openGeneratedQuiz(_ artifactID: UUID) {
        guard !isResetPending else {
            return
        }
        selectTab(.challenges)
        router.openGeneratedQuiz(artifactID)
    }

    func openPreferences() {
        guard !isResetPending else {
            return
        }
        selectTab(.progress)
        router.openPreferences()
    }

    @discardableResult
    func submitAnswer(
        challengeID: String,
        selectedChoiceID: String
    ) -> ChallengeFeedback? {
        guard !isResetPending,
              let challenge = challenge(id: challengeID),
              challenge.choices.contains(where: {
                  $0.id == selectedChoiceID
              }) else {
            return nil
        }

        let isCorrect = challenge.correctChoiceID == selectedChoiceID
        let attempt = ChallengeAttempt(
            id: makeAttemptID(),
            challengeID: challengeID,
            selectedChoiceID: selectedChoiceID,
            isCorrect: isCorrect,
            attemptedAt: now()
        )
        let feedback = ChallengeFeedback(
            attemptID: attempt.id,
            challengeID: challengeID,
            selectedChoiceID: selectedChoiceID,
            isCorrect: isCorrect,
            explanation: challenge.explanation,
            storage: .pending
        )
        feedbackByChallengeID[challengeID] = feedback

        persist(
            .appendAttempt(attempt),
            operation: .appendAttempt,
            mode: sessionMode,
            appliesOptimistically: true
        )
        return feedback
    }

    func markArticleRead(_ articleID: String, isRead: Bool) {
        guard !isResetPending,
              article(id: articleID) != nil else {
            return
        }

        var activity = projectedSnapshot.activity(for: articleID)
        activity.lastOpenedAt = activity.lastOpenedAt ?? now()
        activity.completedAt = isRead ? (activity.completedAt ?? now()) : nil
        updateArticleActivity(activity)
    }

    func markGeneratedArticleRead(
        _ articleID: String,
        isRead: Bool
    ) {
        guard !isResetPending else {
            return
        }
        var activity = projectedSnapshot.activity(for: articleID)
        activity.lastOpenedAt = activity.lastOpenedAt ?? now()
        activity.completedAt = isRead ? (activity.completedAt ?? now()) : nil
        updateArticleActivity(activity)
    }

    func setGeneratedArticleBookmark(
        _ articleID: String,
        isBookmarked: Bool
    ) {
        guard !isResetPending else {
            return
        }
        var activity = projectedSnapshot.activity(for: articleID)
        activity.lastOpenedAt = activity.lastOpenedAt ?? now()
        activity.isBookmarked = isBookmarked
        updateArticleActivity(activity)
    }

    @discardableResult
    func submitGeneratedAnswer(
        artifact: GeneratedLearningArtifact,
        selectedChoiceID: String
    ) -> ChallengeFeedback? {
        guard !isResetPending,
              artifact.quiz.choices.contains(where: {
                  $0.id == selectedChoiceID
              }) else {
            return nil
        }
        let challengeID = artifact.quizID
        let matchesAnswerKey = artifact.quiz.answerKeyChoiceID
            == selectedChoiceID
        let attempt = ChallengeAttempt(
            id: makeAttemptID(),
            challengeID: challengeID,
            selectedChoiceID: selectedChoiceID,
            // Generated answer keys are experimental activity, not verified
            // correctness evidence. The selected choice remains available for
            // an answer-key comparison while the artifact exists.
            isCorrect: false,
            attemptedAt: now()
        )
        let feedback = ChallengeFeedback(
            attemptID: attempt.id,
            challengeID: challengeID,
            selectedChoiceID: selectedChoiceID,
            isCorrect: matchesAnswerKey,
            explanation: artifact.quiz.explanation,
            storage: .pending
        )
        feedbackByChallengeID[challengeID] = feedback
        persist(
            .appendAttempt(attempt),
            operation: .appendAttempt,
            mode: sessionMode,
            appliesOptimistically: true
        )
        return feedback
    }

    func setBookmark(
        _ articleID: String,
        isBookmarked: Bool
    ) {
        guard !isResetPending,
              article(id: articleID) != nil else {
            return
        }

        var activity = projectedSnapshot.activity(for: articleID)
        activity.lastOpenedAt = activity.lastOpenedAt ?? now()
        activity.isBookmarked = isBookmarked
        updateArticleActivity(activity)
    }

    func setSoundEnabled(_ isEnabled: Bool) {
        var updated = projectedSnapshot.preferences
        updated.soundEnabled = isEnabled
        updatePreferences(updated)
    }

    func setHapticsEnabled(_ isEnabled: Bool) {
        var updated = projectedSnapshot.preferences
        updated.hapticsEnabled = isEnabled
        updatePreferences(updated)
    }

    func setAnimationsEnabled(_ isEnabled: Bool) {
        var updated = projectedSnapshot.preferences
        updated.animationsEnabled = isEnabled
        updatePreferences(updated)
    }

    func setPreferences(_ preferences: LearningPreferences) {
        guard !isResetPending else {
            return
        }
        var updated = preferences
        updated.selectedTabIdentifier = router.selectedTab.rawValue
        updatePreferences(updated)
    }

    func requestResetConfirmation() {
        guard !isResetPending else {
            return
        }
        isResetConfirmationPresented = true
    }

    func cancelResetConfirmation() {
        isResetConfirmationPresented = false
    }

    @discardableResult
    func confirmReset() -> UUID? {
        guard isResetConfirmationPresented else {
            return nil
        }
        isResetConfirmationPresented = false
        return persist(
            .reset,
            operation: .reset,
            mode: sessionMode,
            appliesOptimistically: false
        )
    }

    func waitForCurrentOperation() async {
        while let operation = activeOperation {
            await operation.value
        }
    }

    func waitForMutation(_ mutationID: UUID) async -> Bool {
        while mutationQueue.contains(where: { $0.id == mutationID }) {
            guard let operation = activeOperation else {
                return false
            }
            await operation.value
        }
        return true
    }

    private func updateArticleActivity(_ activity: ArticleActivity) {
        persist(
            .updateArticleActivity(activity),
            operation: .updateArticleActivity,
            mode: sessionMode,
            appliesOptimistically: true
        )
    }

    private func updatePreferences(_ preferences: LearningPreferences) {
        persist(
            .updatePreferences(preferences),
            operation: .updatePreferences,
            mode: sessionMode,
            appliesOptimistically: true
        )
    }

    @discardableResult
    private func persist(
        _ mutation: PendingLearningMutation,
        operation: LearningStudioFailedOperation,
        mode: LearningStudioSessionMode,
        appliesOptimistically: Bool
    ) -> UUID? {
        guard !mutationQueue.contains(where: {
            if case .reset = $0.mutation {
                return true
            }
            return false
        }) else {
            return nil
        }

        if appliesOptimistically {
            apply(mutation, to: &projectedSnapshot)
        }

        let mutationID = UUID()
        mutationQueue.append(
            QueuedLearningMutation(
                id: mutationID,
                mutation: mutation,
                operation: operation,
                mode: mode
            )
        )

        if activeOperation == nil && retryableFailure == nil {
            startMutationDrain()
        }
        return mutationID
    }

    private func startMutationDrain() {
        guard activeOperation == nil,
              let queuedMutation = mutationQueue.first else {
            return
        }

        if case .retryableFailure = state {
            // Keep the recovery surface visible until this retry succeeds.
        } else {
            state = .ready(queuedMutation.mode)
        }
        isSaving = true
        let operationID = UUID()
        activeOperationID = operationID
        let store = activeStore

        activeOperation = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await execute(
                    queuedMutation.mutation,
                    with: store
                )
                guard isActive(operationID) else {
                    return
                }

                completeMutation(
                    operationID,
                    queuedMutation: queuedMutation
                )
            } catch let failure as LearningProgressStoreFailure {
                markAttemptUnsavedIfNeeded(
                    queuedMutation.mutation
                )
                fail(
                    operationID,
                    storeFailure: failure,
                    operation: queuedMutation.operation,
                    mode: queuedMutation.mode
                )
            } catch {
                markAttemptUnsavedIfNeeded(
                    queuedMutation.mutation
                )
                fail(
                    operationID,
                    storeFailure: queuedMutation.operation == .reset
                        ? .resetFailed
                        : .writeFailed,
                    operation: queuedMutation.operation,
                    mode: queuedMutation.mode
                )
            }
        }
    }

    private func completeMutation(
        _ operationID: UUID,
        queuedMutation: QueuedLearningMutation
    ) {
        guard isActive(operationID),
              mutationQueue.first == queuedMutation else {
            return
        }

        if case let .appendAttempt(attempt) = queuedMutation.mutation,
           let feedback = feedbackByChallengeID[
               attempt.challengeID
           ],
           feedback.attemptID == attempt.id {
            feedbackByChallengeID[attempt.challengeID] =
                ChallengeFeedback(
                    attemptID: feedback.attemptID,
                    challengeID: feedback.challengeID,
                    selectedChoiceID: feedback.selectedChoiceID,
                    isCorrect: feedback.isCorrect,
                    explanation: feedback.explanation,
                    storage: queuedMutation.mode == .persistent
                        ? .saved
                        : .temporary
                )
        }

        if case .reset = queuedMutation.mutation {
            snapshot = .empty
            projectedSnapshot = .empty
            router.selectedTab = .today
            router.resetPaths()
            feedbackByChallengeID.removeAll()
        } else {
            apply(queuedMutation.mutation, to: &snapshot)
        }

        mutationQueue.removeFirst()
        activeOperationID = nil
        activeOperation = nil
        isSaving = false
        state = .ready(queuedMutation.mode)

        if !mutationQueue.isEmpty {
            startMutationDrain()
        }
    }

    private func execute(
        _ mutation: PendingLearningMutation,
        with store: any LearningProgressStoring
    ) async throws {
        switch mutation {
        case let .appendAttempt(attempt):
            try await store.appendAttempt(attempt)
        case let .updateArticleActivity(activity):
            try await store.updateArticleActivity(activity)
        case let .openArticle(activity, preferences):
            try await store.recordArticleOpen(
                activity,
                preferences: preferences
            )
        case let .updatePreferences(preferences):
            try await store.updatePreferences(preferences)
        case .reset:
            try await store.reset()
        }
    }

    private func apply(
        _ mutation: PendingLearningMutation,
        to target: inout LearningProgressSnapshot
    ) {
        switch mutation {
        case let .appendAttempt(attempt):
            guard !target.attempts.contains(where: {
                $0.id == attempt.id
            }) else {
                return
            }
            target.attempts.append(attempt)
        case let .updateArticleActivity(activity):
            target.articleActivities.removeAll {
                $0.articleID == activity.articleID
            }
            target.articleActivities.append(activity)
        case let .openArticle(activity, preferences):
            target.preferences = preferences
            target.articleActivities.removeAll {
                $0.articleID == activity.articleID
            }
            target.articleActivities.append(activity)
        case let .updatePreferences(preferences):
            target.preferences = preferences
        case .reset:
            break
        }
    }

    private func markAttemptUnsavedIfNeeded(
        _ mutation: PendingLearningMutation
    ) {
        guard case let .appendAttempt(attempt) = mutation,
              let feedback = feedbackByChallengeID[
                  attempt.challengeID
              ],
              feedback.attemptID == attempt.id else {
            return
        }

        feedbackByChallengeID[attempt.challengeID] = ChallengeFeedback(
            attemptID: feedback.attemptID,
            challengeID: feedback.challengeID,
            selectedChoiceID: feedback.selectedChoiceID,
            isCorrect: feedback.isCorrect,
            explanation: feedback.explanation,
            storage: .failed
        )
    }

    private func markAttemptPendingIfNeeded(
        _ mutation: PendingLearningMutation
    ) {
        guard case let .appendAttempt(attempt) = mutation,
              let feedback = feedbackByChallengeID[
                  attempt.challengeID
              ],
              feedback.attemptID == attempt.id else {
            return
        }

        feedbackByChallengeID[attempt.challengeID] = ChallengeFeedback(
            attemptID: feedback.attemptID,
            challengeID: feedback.challengeID,
            selectedChoiceID: feedback.selectedChoiceID,
            isCorrect: feedback.isCorrect,
            explanation: feedback.explanation,
            storage: .pending
        )
    }

    private func cancelActiveOperation() {
        activeOperationID = nil
        let operation = activeOperation
        activeOperation = nil
        operation?.cancel()
    }

    private func isActive(_ operationID: UUID) -> Bool {
        activeOperationID == operationID
    }

    private func finish(
        _ operationID: UUID,
        state newState: LearningStudioState
    ) {
        guard isActive(operationID) else {
            return
        }
        state = newState
        isSaving = false
        activeOperationID = nil
        activeOperation = nil
    }

    private func fail(
        _ operationID: UUID,
        storeFailure: LearningProgressStoreFailure,
        operation: LearningStudioFailedOperation,
        mode: LearningStudioSessionMode
    ) {
        finish(
            operationID,
            state: .retryableFailure(
                LearningStudioRetryableFailure(
                    storeFailure: storeFailure,
                    operation: operation,
                    sessionMode: mode
                )
            )
        )
    }
}

private enum PendingLearningMutation: Equatable, Sendable {
    case appendAttempt(ChallengeAttempt)
    case updateArticleActivity(ArticleActivity)
    case openArticle(
        activity: ArticleActivity,
        preferences: LearningPreferences
    )
    case updatePreferences(LearningPreferences)
    case reset
}

private struct QueuedLearningMutation: Equatable, Sendable {
    let id: UUID
    let mutation: PendingLearningMutation
    let operation: LearningStudioFailedOperation
    let mode: LearningStudioSessionMode
}
