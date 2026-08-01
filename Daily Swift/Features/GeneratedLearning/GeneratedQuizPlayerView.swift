import SwiftUI

struct GeneratedQuizPlayerView: View {
    let artifact: GeneratedLearningArtifact
    let hasSavedAnswerKeyMatch: Bool
    let currentFeedback: ChallengeFeedback?
    let onSubmit: (String) async -> ChallengeFeedback?
    let onRetrySave: () async -> ChallengeFeedbackStorage
    let onOpenCitation: (SourceCitation) -> Void
    let onOpenArticle: () -> Void

    @State private var selectedChoiceID: String?
    @State private var feedback: ChallengeFeedback?
    @State private var isSubmitting = false
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
                    Text(artifact.quiz.prompt)
                        .font(StudioTokens.Typography.title)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($promptIsFocused)

                    Text(
                        "Choose the answer that matches the generated answer key. This is experimental practice, not verified correctness or mastery evidence."
                    )
                    .font(StudioTokens.Typography.supporting)
                    .foregroundStyle(StudioTokens.Color.secondaryText)
                }

                VStack(spacing: StudioTokens.Spacing.small) {
                    ForEach(artifact.quiz.choices) { choice in
                        generatedChoiceButton(choice)
                    }
                }

                if let feedback {
                    feedbackView(feedback)

                    if !feedback.isCorrect,
                       feedback.storage == .saved
                        || feedback.storage == .temporary {
                        Button {
                            selectedChoiceID = nil
                            self.feedback = nil
                        } label: {
                            Label(
                                "Try another answer",
                                systemImage: "arrow.clockwise"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudioSecondaryButtonStyle())
                        .accessibilityIdentifier(
                            "generated-quiz.try-again"
                        )
                    }
                } else {
                    Button {
                        submit()
                    } label: {
                        Label("Compare with answer key", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(
                        StudioPrimaryButtonStyle(isBusy: isSubmitting)
                    )
                    .disabled(selectedChoiceID == nil || isSubmitting)
                    .accessibilityIdentifier("generated-quiz.submit")
                }

                citationSection

                Button(action: onOpenArticle) {
                    Label(
                        "Read the generated article",
                        systemImage: "book.pages"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudioSecondaryButtonStyle())
                .accessibilityIdentifier("generated-quiz.open-article")
            }
            .frame(maxWidth: 720)
            .padding(StudioTokens.Spacing.medium)
            .padding(.bottom, StudioTokens.Spacing.xLarge)
            .frame(maxWidth: .infinity)
        }
        .background(StudioTokens.Color.groupedCanvas)
        .navigationTitle("Generated Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            promptIsFocused = true
        }
        .onChange(of: currentFeedback, initial: true) {
            _, updatedFeedback in
            if let updatedFeedback {
                feedback = updatedFeedback
            }
        }
        .accessibilityIdentifier("generated-quiz.player")
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
            "Experimental answer key",
            symbol: "flask",
            role: .warning
        )
        LearningBadge(
            hasSavedAnswerKeyMatch ? "Answer key matched" : "Not completed",
            symbol: hasSavedAnswerKeyMatch
                ? "checkmark.circle.fill"
                : "circle"
        )
    }

    private func generatedChoiceButton(
        _ choice: GeneratedLearningQuizChoice
    ) -> some View {
        let isSelected = selectedChoiceID == choice.id
        return Button {
            selectedChoiceID = choice.id
            feedback = nil
        } label: {
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
        .disabled(isSubmitting || feedback != nil)
        .accessibilityLabel(choice.text)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("generated-quiz.choice.\(choice.id)")
    }

    private func feedbackView(
        _ feedback: ChallengeFeedback
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: StudioTokens.Spacing.small
        ) {
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.small
            ) {
                Label(
                    feedback.isCorrect
                        ? "Matches the generated answer key"
                        : "Different from the generated answer key",
                    systemImage: feedback.isCorrect
                        ? "checkmark.circle.fill"
                        : "xmark.circle.fill"
                )
                .font(StudioTokens.Typography.title)

                Text(feedback.explanation)
                    .font(StudioTokens.Typography.body)
                    .fixedSize(horizontal: false, vertical: true)

                Text(storageDescription(feedback.storage))
                    .font(StudioTokens.Typography.supporting)
                    .foregroundStyle(StudioTokens.Color.secondaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                feedback.isCorrect
                    ? "Matches the generated answer key"
                    : "Different from the generated answer key"
            )
            .accessibilityValue(
                "\(feedback.explanation) \(storageDescription(feedback.storage))"
            )
            .accessibilityFocused($feedbackIsFocused)
            .accessibilityIdentifier("generated-quiz.feedback")

            if feedback.storage == .failed {
                Button("Retry saving") {
                    let attemptID = feedback.attemptID
                    Task {
                        let storage = await onRetrySave()
                        guard self.feedback?.attemptID == attemptID else {
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
                .buttonStyle(StudioSecondaryButtonStyle())
                .accessibilityIdentifier("generated-quiz.retry-save")
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
                    : StudioTokens.Color.warning,
                lineWidth: 2
            )
        }
    }

    private var citationSection: some View {
        LearningCard {
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.small
            ) {
                Label("Exact quiz citations", systemImage: "quote.opening")
                    .font(StudioTokens.Typography.title)
                    .accessibilityAddTraits(.isHeader)

                ForEach(quizReferences) { reference in
                    Button {
                        onOpenCitation(reference.citation)
                    } label: {
                        GeneratedCitationLabel(reference: reference)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "generated-quiz.citation.\(reference.id)"
                    )
                }
            }
        }
    }

    private var quizReferences: [GeneratedLearningSourceReference] {
        artifact.quiz.citationReferenceIDs.compactMap {
            artifact.sourceReference(id: $0)
        }
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

    private func storageDescription(
        _ storage: ChallengeFeedbackStorage
    ) -> String {
        switch storage {
        case .pending:
            "Saving this experimental attempt."
        case .saved:
            "Attempt saved as activity evidence. It does not update mastery."
        case .temporary:
            "Attempt recorded for this temporary session only."
        case .failed:
            "Answer compared, but the attempt was not saved."
        }
    }
}
