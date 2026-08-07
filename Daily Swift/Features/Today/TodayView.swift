import SwiftUI

struct TodayView: View {
    let snapshot: LearningProgressSnapshot
    let generatedArtifacts: [GeneratedLearningArtifact]
    let generatedLearningState: GeneratedLearningViewState
    let onGenerateLearning: () -> Void
    let onOpenGeneratedArticle: (GeneratedLearningArtifact) -> Void
    let onOpenGeneratedQuiz: (UUID) -> Void
    let onPrivacy: () -> Void

    private var latestArtifact: GeneratedLearningArtifact? {
        generatedArtifacts.first
    }

    var body: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.large
            ) {
                focusHeader

                generateCard

                if let latestArtifact {
                    currentPairCard(latestArtifact)
                } else {
                    generatedHistoryState
                }

                LearningCard {
                    VStack(
                        alignment: .leading,
                        spacing: StudioTokens.Spacing.small
                    ) {
                        Label(
                            "Your saved learning stays local",
                            systemImage: "iphone"
                        )
                        .font(StudioTokens.Typography.sectionHeading)

                        Text(
                            "Previously generated articles, quizzes, and imported sources remain readable without a connection. Creating a new pair requires compatible on-device generation and enough matching source evidence."
                        )
                        .font(StudioTokens.Typography.supporting)
                        .foregroundStyle(StudioTokens.Color.secondaryText)
                    }
                }
            }
            .frame(maxWidth: 720)
            .padding(StudioTokens.Spacing.medium)
            .padding(.bottom, StudioTokens.Spacing.large)
            .frame(maxWidth: .infinity)
        }
        .background(StudioTokens.Color.groupedCanvas)
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onPrivacy) {
                    Label("Privacy & Data", systemImage: "hand.raised")
                }
                .accessibilityIdentifier("app-shell.privacy")
            }
        }
    }

    private var focusHeader: some View {
        VStack(alignment: .leading, spacing: StudioTokens.Spacing.xSmall) {
            Text("TODAY’S FOCUS")
                .font(StudioTokens.Typography.codeCaption.weight(.bold))
                .foregroundStyle(StudioTokens.Color.primaryText)

            Text("Learn from your sources")
                .font(StudioTokens.Typography.display)
                .foregroundStyle(StudioTokens.Color.primaryText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("app-shell.ready")

            Text(
                "Choose the Swift topic you want next. Daily Swift creates a new cited article and quiz from your private imported material."
            )
            .font(StudioTokens.Typography.body)
            .foregroundStyle(StudioTokens.Color.secondaryText)
        }
    }

    private var generateCard: some View {
        LearningCard {
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.medium
            ) {
                Label(
                    "Create your next article and quiz",
                    systemImage: "sparkles.rectangle.stack"
                )
                .font(StudioTokens.Typography.title)

                Text(
                    "Request another pair whenever you want. Daily Swift adds no generation-count limit; each request still runs one at a time and must pass source and safety checks before it is saved."
                )
                .font(StudioTokens.Typography.supporting)
                .foregroundStyle(StudioTokens.Color.secondaryText)

                Button(action: onGenerateLearning) {
                    Label(
                        generatedArtifacts.isEmpty
                            ? "Generate from your sources"
                            : "Generate another pair",
                        systemImage: "sparkles"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudioPrimaryButtonStyle())
                .accessibilityHint(
                    "Opens a foreground on-device request grounded in imported passages."
                )
                .accessibilityIdentifier("today.generate")
            }
        }
    }

    private func currentPairCard(
        _ artifact: GeneratedLearningArtifact
    ) -> some View {
        let articleIsRead = snapshot.activity(
            for: artifact.articleID
        ).completedAt != nil
        let quizIsComplete = hasSavedAnswerKeyMatch(for: artifact)
        let completedCount = (articleIsRead ? 1 : 0) + (quizIsComplete ? 1 : 0)

        return LearningCard {
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.medium
            ) {
                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.xxSmall
                ) {
                    Text("LATEST GENERATED PAIR")
                        .font(
                            StudioTokens.Typography.codeCaption.weight(.bold)
                        )
                        .foregroundStyle(StudioTokens.Color.secondaryText)

                    Text(artifact.article.title)
                        .font(StudioTokens.Typography.title)
                        .foregroundStyle(StudioTokens.Color.primaryText)

                    Text("Topic: \(artifact.topic)")
                        .font(StudioTokens.Typography.supporting)
                        .foregroundStyle(StudioTokens.Color.secondaryText)
                }

                EvidenceProgressView(
                    title: "Pair progress",
                    completed: completedCount,
                    total: 2,
                    supportingText: completedCount == 2
                        ? "You read the article and matched its generated quiz answer key."
                        : "Read the article and complete its generated quiz."
                )

                Button {
                    onOpenGeneratedArticle(artifact)
                } label: {
                    Label(
                        articleIsRead ? "Review article" : "Read article",
                        systemImage: "book.pages"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudioSecondaryButtonStyle())
                .accessibilityIdentifier("today.open-generated-article")

                Button {
                    onOpenGeneratedQuiz(artifact.id)
                } label: {
                    Label(
                        quizIsComplete ? "Try quiz again" : "Complete quiz",
                        systemImage: "checklist"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudioSecondaryButtonStyle())
                .accessibilityIdentifier("today.open-generated-quiz")
            }
        }
        .accessibilityIdentifier("today.generated-pair")
    }

    @ViewBuilder
    private var generatedHistoryState: some View {
        LearningCard {
            switch generatedLearningState {
            case .loading:
                HStack(spacing: StudioTokens.Spacing.small) {
                    ProgressView()
                    Text("Loading generated learning")
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("today.generated-loading")

            case let .unavailable(reason):
                generatedEmptyState(
                    title: reason.title,
                    message: reason.message,
                    symbol: "iphone.slash"
                )

            case let .failed(failure) where failure == .storageUnavailable:
                generatedEmptyState(
                    title: failure.title,
                    message: failure.message,
                    symbol: "externaldrive.badge.exclamationmark"
                )

            default:
                generatedEmptyState(
                    title: "No generated learning yet",
                    message: "Import a source, choose a topic, and generate your first cited article and quiz.",
                    symbol: "sparkles.rectangle.stack"
                )
            }
        }
        .accessibilityIdentifier("today.generated-empty")
    }

    private func generatedEmptyState(
        title: String,
        message: String,
        symbol: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: StudioTokens.Spacing.small
        ) {
            Label(title, systemImage: symbol)
                .font(StudioTokens.Typography.sectionHeading)

            Text(message)
                .font(StudioTokens.Typography.supporting)
                .foregroundStyle(StudioTokens.Color.secondaryText)
        }
    }

    private func hasSavedAnswerKeyMatch(
        for artifact: GeneratedLearningArtifact
    ) -> Bool {
        snapshot.attempts.contains {
            $0.challengeID == artifact.quizID
                && $0.selectedChoiceID == artifact.quiz.answerKeyChoiceID
        }
    }
}
