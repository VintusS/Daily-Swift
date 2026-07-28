import SwiftUI
import UIKit

@MainActor
struct LearningStudioView: View {
    @State private var viewModel: LearningStudioViewModel
    @State private var sourceLibraryViewModel: SourceLibraryViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onPrivacy: () -> Void

    init(
        viewModel: LearningStudioViewModel,
        sourceLibraryViewModel: SourceLibraryViewModel,
        onPrivacy: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        _sourceLibraryViewModel = State(
            initialValue: sourceLibraryViewModel
        )
        self.onPrivacy = onPrivacy
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ShellProgressView(
                    title: "Preparing your learning studio",
                    message: "Loading your private, on-device learning evidence."
                )

            case .ready:
                tabContainer

            case let .retryableFailure(failure):
                if failure.operation == .restore {
                    LearningStoreRecoveryView(
                        failure: failure,
                        onRetry: retry,
                        onContinueTemporarily: continueTemporarily
                    )
                } else if shouldPresentPersistenceBanner(for: failure) {
                    tabContainer
                        .safeAreaInset(edge: .top, spacing: 0) {
                            LearningPersistenceBanner(
                                failure: failure,
                                isRetrying: viewModel.isSaving,
                                onRetry: retry
                            )
                        }
                } else {
                    tabContainer
                }
            }
        }
        .task {
            if case .loading = viewModel.state {
                viewModel.load()
                await viewModel.waitForCurrentOperation()
            }
        }
        .onChange(of: viewModel.retryableFailure) {
            previousFailure, currentFailure in
            guard previousFailure?.operation != .restore,
                  previousFailure != nil,
                  currentFailure == nil else {
                return
            }
            UIAccessibility.post(
                notification: .announcement,
                argument: "Learning change saved."
            )
        }
    }

    private var tabContainer: some View {
        TabView(selection: selectedTab) {
            NavigationStack(path: path(for: .today)) {
                TodayView(
                    catalog: viewModel.catalog,
                    evidence: viewModel.evidence,
                    onContinue: openNextDailyStep,
                    onOpenStep: open,
                    onPrivacy: onPrivacy
                )
                .navigationDestination(
                    for: LearningStudioRoute.self,
                    destination: destination
                )
            }
            .tag(LearningStudioTab.today)
            .tabItem {
                Label(
                    LearningStudioTab.today.title,
                    systemImage: LearningStudioTab.today.symbolName
                )
            }
            .accessibilityIdentifier("tab.today")

            NavigationStack(path: path(for: .challenges)) {
                ChallengesView(
                    catalog: viewModel.catalog,
                    evidence: viewModel.evidence,
                    onOpenChallenge: viewModel.openChallenge
                )
                .navigationDestination(
                    for: LearningStudioRoute.self,
                    destination: destination
                )
            }
            .tag(LearningStudioTab.challenges)
            .tabItem {
                Label(
                    LearningStudioTab.challenges.title,
                    systemImage: LearningStudioTab.challenges.symbolName
                )
            }
            .accessibilityIdentifier("tab.challenges")

            NavigationStack(path: path(for: .library)) {
                LibraryView(
                    catalog: viewModel.catalog,
                    snapshot: viewModel.snapshot,
                    sourceLibraryViewModel: sourceLibraryViewModel,
                    onOpenArticle: viewModel.openArticle,
                    onOpenSource: viewModel.router.openSource
                )
                .navigationDestination(
                    for: LearningStudioRoute.self,
                    destination: destination
                )
            }
            .tag(LearningStudioTab.library)
            .tabItem {
                Label(
                    LearningStudioTab.library.title,
                    systemImage: LearningStudioTab.library.symbolName
                )
            }
            .accessibilityIdentifier("tab.library")

            NavigationStack(path: path(for: .progress)) {
                LearningProgressView(
                    catalog: viewModel.catalog,
                    snapshot: viewModel.snapshot,
                    evidence: viewModel.evidence,
                    isTemporarySession:
                        viewModel.sessionMode == .temporary,
                    onOpenPreferences: viewModel.openPreferences,
                    onPrivacy: onPrivacy
                )
                .navigationDestination(
                    for: LearningStudioRoute.self,
                    destination: destination
                )
            }
            .tag(LearningStudioTab.progress)
            .tabItem {
                Label(
                    LearningStudioTab.progress.title,
                    systemImage: LearningStudioTab.progress.symbolName
                )
            }
            .accessibilityIdentifier("tab.progress")
        }
        .tint(StudioTokens.Color.action)
        .accessibilityIdentifier("learning-studio.tabs")
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.sessionMode == .temporary {
                TemporaryLearningSessionBanner()
            }
        }
        .transaction { transaction in
            if reduceMotion || !viewModel.preferences.animationsEnabled {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }

    private var selectedTab: Binding<LearningStudioTab> {
        Binding(
            get: { viewModel.router.selectedTab },
            set: { viewModel.selectTab($0) }
        )
    }

    private func shouldPresentPersistenceBanner(
        for failure: LearningStudioRetryableFailure
    ) -> Bool {
        guard failure.operation == .appendAttempt,
              viewModel.router.selectedTab == .challenges,
              case let .challenge(challengeID) =
                  viewModel.router.challengesPath.last,
              viewModel.ownsRetryableAttemptFailure(
                  challengeID: challengeID
              ) else {
            return true
        }
        return false
    }

    private func path(
        for tab: LearningStudioTab
    ) -> Binding<[LearningStudioRoute]> {
        Binding(
            get: {
                switch tab {
                case .today:
                    viewModel.router.todayPath
                case .challenges:
                    viewModel.router.challengesPath
                case .library:
                    viewModel.router.libraryPath
                case .progress:
                    viewModel.router.progressPath
                }
            },
            set: {
                viewModel.router.replacePath($0, for: tab)
            }
        )
    }

    @ViewBuilder
    private func destination(
        for route: LearningStudioRoute
    ) -> some View {
        switch route {
        case let .article(articleID):
            if let article = viewModel.article(id: articleID) {
                ArticleReaderView(
                    article: article,
                    activity: viewModel.articleActivity(
                        for: articleID
                    ),
                    relatedChallenge: viewModel.challenges.first {
                        $0.relatedArticleID == articleID
                    },
                    onOpened: {},
                    onToggleBookmark: {
                        viewModel.setBookmark(
                            articleID,
                            isBookmarked:
                                !viewModel.articleActivity(
                                    for: articleID
                                ).isBookmarked
                        )
                        await viewModel.waitForCurrentOperation()
                    },
                    onMarkRead: {
                        viewModel.markArticleRead(
                            articleID,
                            isRead: true
                        )
                        await viewModel.waitForCurrentOperation()
                    },
                    onOpenChallenge: viewModel.openChallenge
                )
            } else {
                MissingLearningContentView(kind: "article")
            }

        case let .challenge(challengeID):
            if let challenge = viewModel.challenge(id: challengeID) {
                ChallengePlayerView(
                    challenge: challenge,
                    hasSavedCorrectAttempt: viewModel
                        .isChallengeComplete(challengeID),
                    currentFeedback: viewModel.feedback(
                        for: challengeID
                    ),
                    onSubmit: { selectedChoiceID in
                        _ = viewModel.submitAnswer(
                            challengeID: challengeID,
                            selectedChoiceID: selectedChoiceID
                        )
                        await viewModel.waitForCurrentOperation()
                        return viewModel.feedback(for: challengeID)
                    },
                    onRetrySave: {
                        viewModel.retry()
                        await viewModel.waitForCurrentOperation()
                        return viewModel.feedback(
                            for: challengeID
                        )?.storage ?? .failed
                    },
                    onOpenArticle: viewModel.openArticle
                )
            } else {
                MissingLearningContentView(kind: "challenge")
            }

        case let .sourceDocument(sourceID):
            if let document = sourceLibraryViewModel.document(
                id: sourceID
            ) {
                SourceDocumentDetailView(
                    document: document,
                    chunks: sourceLibraryViewModel.chunks(
                        for: sourceID
                    ),
                    isDeleting:
                        sourceLibraryViewModel.deletingSourceID
                            == sourceID,
                    onOpenCitation:
                        viewModel.router.openCitation,
                    onDelete: {
                        await sourceLibraryViewModel.delete(
                            sourceID: sourceID
                        )
                    },
                    onDeleted:
                        viewModel.router.returnToLibraryRoot
                )
            } else {
                MissingLearningContentView(kind: "source")
            }

        case let .sourceCitation(citation):
            SourceCitationReaderView(
                citation: citation,
                resolve: sourceLibraryViewModel.resolve
            )

        case .preferences:
            InteractionPreferencesView(
                preferences: viewModel.preferences,
                isResetting: viewModel.isSaving
                    || viewModel.isResetPending,
                isTemporarySession:
                    viewModel.sessionMode == .temporary,
                onSoundChanged: viewModel.setSoundEnabled,
                onHapticsChanged: viewModel.setHapticsEnabled,
                onAnimationsChanged:
                    viewModel.setAnimationsEnabled,
                onReset: resetProgress,
                onPrivacy: onPrivacy
            )
        }
    }

    private func openNextDailyStep() {
        guard let step = viewModel.nextDailyStep
            ?? viewModel.dailyPlan.steps.first else {
            return
        }
        open(step)
    }

    private func open(_ step: DailyLearningStep) {
        switch step.content {
        case let .article(identifier):
            viewModel.openArticle(identifier)
        case let .challenge(identifier):
            viewModel.openChallenge(identifier)
        }
    }

    private func retry() {
        viewModel.retry()
    }

    private func continueTemporarily() {
        viewModel.continueTemporarily()
    }

    private func resetProgress() async -> Bool {
        viewModel.requestResetConfirmation()
        guard let mutationID = viewModel.confirmReset() else {
            return false
        }
        return await viewModel.waitForMutation(mutationID)
    }
}

private struct TemporaryLearningSessionBanner: View {
    var body: some View {
        HStack(
            alignment: .top,
            spacing: StudioTokens.Spacing.small
        ) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(StudioTokens.Color.primaryText)
                .accessibilityHidden(true)

            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.xxSmall
            ) {
                Text("Temporary learning session")
                    .font(StudioTokens.Typography.sectionHeading)

                Text(
                    "You can read and practice, but this session disappears when the app closes."
                )
                .font(StudioTokens.Typography.supporting)
                .foregroundStyle(StudioTokens.Color.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(StudioTokens.Spacing.small)
        .background(.bar)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("learning-studio.temporary")
    }
}

private struct MissingLearningContentView: View {
    let kind: String

    var body: some View {
        ContentUnavailableView(
            "This \(kind) is no longer available",
            systemImage: "questionmark.folder",
            description: Text(
                "Return to the tab root to choose current bundled content."
            )
        )
        .navigationTitle("Unavailable")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LearningStoreRecoveryView: View {
    let failure: LearningStudioRetryableFailure
    let onRetry: () -> Void
    let onContinueTemporarily: () -> Void
    @AccessibilityFocusState private var headingIsFocused: Bool

    var body: some View {
        ZStack {
            StudioBackground()

            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.large
                ) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(StudioTokens.Color.warning)
                        .accessibilityHidden(true)

                    Text(failure.title)
                        .font(StudioTokens.Typography.display)
                        .foregroundStyle(StudioTokens.Color.primaryText)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($headingIsFocused)
                        .accessibilityIdentifier(
                            "learning-studio.failure"
                        )

                    Text(failure.message)
                        .font(StudioTokens.Typography.body)
                        .foregroundStyle(
                            StudioTokens.Color.secondaryText
                        )

                    Button(action: onRetry) {
                        Label("Retry restoring", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudioPrimaryButtonStyle())
                    .accessibilityHint(
                        "Attempts to load the saved learning evidence again."
                    )
                    .accessibilityIdentifier("learning-studio.retry")

                    if failure.canContinueTemporarily {
                        Button(action: onContinueTemporarily) {
                            Label(
                                "Continue temporarily",
                                systemImage: "clock.arrow.circlepath"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudioSecondaryButtonStyle())
                        .accessibilityHint(
                            "Opens all bundled learning content without saving this session."
                        )
                        .accessibilityIdentifier(
                            "learning-studio.continue-temporarily"
                        )
                    }
                }
                .frame(maxWidth: 620)
                .padding(StudioTokens.Spacing.large)
                .frame(maxWidth: .infinity)
            }
        }
        .task {
            headingIsFocused = true
        }
    }
}

private struct LearningPersistenceBanner: View {
    let failure: LearningStudioRetryableFailure
    let isRetrying: Bool
    let onRetry: () -> Void
    @AccessibilityFocusState private var messageIsFocused: Bool

    var body: some View {
        VStack(spacing: StudioTokens.Spacing.xSmall) {
            Label(
                failure.title,
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(StudioTokens.Typography.sectionHeading)
            .foregroundStyle(StudioTokens.Color.primaryText)
            .accessibilityFocused($messageIsFocused)

            Text(failure.message)
                .font(StudioTokens.Typography.supporting)
                .foregroundStyle(StudioTokens.Color.secondaryText)

            Button("Retry save", action: onRetry)
                .buttonStyle(
                    StudioSecondaryButtonStyle(isBusy: isRetrying)
                )
                .disabled(isRetrying)
                .accessibilityIdentifier("learning-studio.banner-retry")
        }
        .frame(maxWidth: .infinity)
        .padding(StudioTokens.Spacing.small)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("learning-studio.save-failure")
        .task {
            messageIsFocused = true
        }
    }
}
