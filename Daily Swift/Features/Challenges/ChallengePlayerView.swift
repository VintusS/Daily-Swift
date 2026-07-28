import SwiftUI

struct ChallengePlayerView: View {
    let challenge: LearningChallenge
    let hasSavedCorrectAttempt: Bool
    let currentFeedback: ChallengeFeedback?
    let onSubmit: (String) async -> ChallengeFeedback?
    let onRetrySave: () async -> ChallengeFeedbackStorage
    let onOpenArticle: (String) -> Void

    @State private var selectedChoiceID: String?
    @State private var feedback: ChallengeFeedback?
    @State private var isSubmitting = false
    @State private var choiceOrderSeed = UInt64.random(
        in: UInt64.min...UInt64.max
    )
    @AccessibilityFocusState private var promptIsFocused: Bool
    @AccessibilityFocusState private var feedbackIsFocused: Bool

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.large
            ) {
                metadata

                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.small
                ) {
                    Text(challenge.prompt)
                        .font(StudioTokens.Typography.title)
                        .foregroundStyle(StudioTokens.Color.primaryText)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($promptIsFocused)

                    if let code = challenge.code {
                        SelectableCodeBlock(
                            code,
                            accessibilityLabel: "Challenge code"
                        )
                    }
                }

                VStack(spacing: StudioTokens.Spacing.small) {
                    ForEach(presentedChoices) { choice in
                        ChallengeChoiceButton(
                            choice: choice,
                            isSelected: selectedChoiceID == choice.id,
                            isDisabled: isSubmitting || feedback != nil,
                            onSelect: {
                                selectedChoiceID = choice.id
                                feedback = nil
                            }
                        )
                    }
                }

                if let feedback {
                    ChallengeFeedbackView(
                        feedback: feedback,
                        summaryIsFocused: $feedbackIsFocused,
                        onRetrySave: {
                            let attemptID = feedback.attemptID
                            Task {
                                let storage = await onRetrySave()
                                guard self.feedback?.attemptID
                                    == attemptID else {
                                    return
                                }
                                self.feedback = ChallengeFeedback(
                                    attemptID: feedback.attemptID,
                                    challengeID: feedback.challengeID,
                                    selectedChoiceID: feedback.selectedChoiceID,
                                    isCorrect: feedback.isCorrect,
                                    explanation: feedback.explanation,
                                    storage: storage
                                )
                                feedbackIsFocused = true
                            }
                        }
                    )
                    if !feedback.isCorrect,
                       feedback.storage == .saved
                        || feedback.storage == .temporary {
                        Button {
                            selectedChoiceID = nil
                            self.feedback = nil
                        } label: {
                            Label("Try another answer", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudioSecondaryButtonStyle())
                        .accessibilityIdentifier("challenge.try-again")
                    }

                    Button {
                        onOpenArticle(challenge.relatedArticleID)
                    } label: {
                        Label(
                            "Read the related article",
                            systemImage: "book.pages"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudioSecondaryButtonStyle())
                    .accessibilityIdentifier("challenge.related-article")
                } else {
                    Button {
                        submit()
                    } label: {
                        Label("Check answer", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(
                        StudioPrimaryButtonStyle(isBusy: isSubmitting)
                    )
                    .disabled(selectedChoiceID == nil || isSubmitting)
                    .accessibilityHint(
                        selectedChoiceID == nil
                            ? "Choose an answer first."
                            : "Checks this answer against the bundled answer key."
                    )
                    .accessibilityIdentifier("challenge.submit")
                }
            }
            .frame(maxWidth: 720)
            .padding(StudioTokens.Spacing.medium)
            .padding(.bottom, StudioTokens.Spacing.xLarge)
            .frame(maxWidth: .infinity)
        }
        .background(StudioTokens.Color.groupedCanvas)
        .navigationTitle(challenge.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("challenge.player")
        .task {
            promptIsFocused = true
        }
        .onChange(of: currentFeedback, initial: true) {
            _, updatedFeedback in
            if let updatedFeedback {
                feedback = updatedFeedback
            }
        }
    }

    private var presentedChoices: [ChallengeChoice] {
        ChallengeChoiceOrderer.orderedChoices(
            for: challenge,
            seed: choiceOrderSeed
        )
    }

    private var metadata: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: StudioTokens.Spacing.xSmall) {
                metadataBadges
            }

            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.xSmall
            ) {
                metadataBadges
            }
        }
    }

    @ViewBuilder
    private var metadataBadges: some View {
        LearningBadge(
            challenge.validationCapability.label,
            symbol: "checkmark.shield",
            role: .information
        )
        LearningBadge(
            hasSavedCorrectAttempt ? "Completed" : challenge.kind.label,
            symbol: hasSavedCorrectAttempt
                ? "checkmark.circle.fill"
                : challenge.kind.symbolName,
            role: hasSavedCorrectAttempt ? .success : .neutral
        )
    }

    private func submit() {
        guard let selectedChoiceID else {
            return
        }

        isSubmitting = true
        Task {
            feedback = await onSubmit(selectedChoiceID)
            isSubmitting = false
            feedbackIsFocused = true
        }
    }
}

private struct ChallengeChoiceButton: View {
    let choice: ChallengeChoice
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(
                alignment: .top,
                spacing: StudioTokens.Spacing.small
            ) {
                Image(
                    systemName: isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title3)
                .foregroundStyle(
                    isSelected
                        ? StudioTokens.Color.action
                        : StudioTokens.Color.secondaryText
                )
                .accessibilityHidden(true)

                Text(choice.text)
                    .font(StudioTokens.Typography.body)
                    .foregroundStyle(StudioTokens.Color.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(StudioTokens.Spacing.medium)
            .background(
                isSelected
                    ? StudioTokens.Color.action.opacity(0.10)
                    : StudioTokens.Color.surface,
                in: RoundedRectangle(
                    cornerRadius: StudioTokens.Radius.control,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: StudioTokens.Radius.control,
                    style: .continuous
                )
                .stroke(
                    isSelected
                        ? StudioTokens.Color.action
                        : StudioTokens.Color.separator,
                    lineWidth: isSelected ? 2 : 1
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(choice.text)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("challenge.choice.\(choice.id)")
    }
}

private struct ChallengeFeedbackView: View {
    let feedback: ChallengeFeedback
    @AccessibilityFocusState.Binding var summaryIsFocused: Bool
    let onRetrySave: () -> Void

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: StudioTokens.Spacing.small
        ) {
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.small
            ) {
                Label(
                    feedback.isCorrect ? "Correct" : "Not quite",
                    systemImage: feedback.isCorrect
                        ? "checkmark.circle.fill"
                        : "xmark.circle.fill"
                )
                .font(StudioTokens.Typography.title)
                .foregroundStyle(StudioTokens.Color.primaryText)

                Text(feedback.explanation)
                    .font(StudioTokens.Typography.body)
                    .foregroundStyle(StudioTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                feedback.isCorrect
                    ? "Correct answer"
                    : "Incorrect answer"
            )
            .accessibilityValue(
                "\(feedback.explanation) \(storageDescription)"
            )
            .accessibilityIdentifier(
                feedback.isCorrect
                    ? "challenge.feedback.correct"
                    : "challenge.feedback.incorrect"
            )
            .accessibilityFocused($summaryIsFocused)

            switch feedback.storage {
            case .pending:
                Divider()

                Label(
                    "Saving this attempt",
                    systemImage: "arrow.triangle.2.circlepath"
                )
                .font(StudioTokens.Typography.supporting)
                .foregroundStyle(StudioTokens.Color.primaryText)

            case .failed:
                Divider()

                Label(
                    "Answer checked, but the attempt is not saved.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(StudioTokens.Typography.supporting)
                .foregroundStyle(StudioTokens.Color.primaryText)

                Button("Retry saving", action: onRetrySave)
                    .buttonStyle(StudioSecondaryButtonStyle())
                    .accessibilityIdentifier("challenge.retry-save")

            case .temporary:
                Divider()

                Label(
                    "Recorded for this temporary session only.",
                    systemImage: "clock.arrow.circlepath"
                )
                .font(StudioTokens.Typography.supporting)
                .foregroundStyle(StudioTokens.Color.primaryText)
                .accessibilityIdentifier(
                    "challenge.feedback.temporary-storage"
                )

            case .saved:
                EmptyView()
            }
        }
        .padding(StudioTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            StudioTokens.Color.surface,
            in: RoundedRectangle(
                cornerRadius: StudioTokens.Radius.card,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: StudioTokens.Radius.card,
                style: .continuous
            )
            .stroke(
                feedback.isCorrect
                    ? StudioTokens.Color.success
                    : StudioTokens.Color.error,
                lineWidth: 2
            )
        }
        .accessibilityElement(children: .contain)
    }

    private var storageDescription: String {
        switch feedback.storage {
        case .pending:
            "Saving attempt."
        case .saved:
            "Attempt saved."
        case .temporary:
            "Attempt recorded for this temporary session only."
        case .failed:
            "Attempt not saved. Retry is available."
        }
    }
}
