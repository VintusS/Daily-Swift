import SwiftUI

struct GeneratedArticleHistoryRow: View {
    let artifact: GeneratedLearningArtifact
    let activity: ArticleActivity

    var body: some View {
        HStack(
            alignment: .top,
            spacing: StudioTokens.Spacing.small
        ) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.title3)
                .foregroundStyle(StudioTokens.Color.warning)
                .frame(minWidth: 30, minHeight: 30)
                .accessibilityHidden(true)

            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.xSmall
            ) {
                HStack(alignment: .firstTextBaseline) {
                    Text(artifact.article.title)
                        .font(StudioTokens.Typography.sectionHeading)
                        .foregroundStyle(StudioTokens.Color.primaryText)

                    Spacer()

                    if activity.completedAt != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(StudioTokens.Color.primaryText)
                            .accessibilityLabel("Read")
                    }
                }

                Text(artifact.topic)
                    .font(StudioTokens.Typography.supporting)
                    .foregroundStyle(StudioTokens.Color.secondaryText)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: StudioTokens.Spacing.xSmall) {
                        metadata
                    }
                    VStack(
                        alignment: .leading,
                        spacing: StudioTokens.Spacing.xxSmall
                    ) {
                        metadata
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StudioTokens.Color.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(.vertical, StudioTokens.Spacing.xxSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(artifact.article.title)
        .accessibilityValue(
            "\(artifact.topic). Experimental user material. \(activity.completedAt == nil ? "Not read" : "Read")\(activity.isBookmarked ? ", Bookmarked" : "")"
        )
        .accessibilityHint("Opens the generated article.")
    }

    @ViewBuilder
    private var metadata: some View {
        LearningBadge(
            "Experimental",
            symbol: "flask",
            role: .warning
        )
        LearningBadge(
            "\(artifact.sourceReferences.count) source\(artifact.sourceReferences.count == 1 ? "" : "s")",
            symbol: "quote.opening"
        )
    }
}

struct GeneratedQuizHistoryRow: View {
    let artifact: GeneratedLearningArtifact
    let hasAnswerKeyMatch: Bool

    var body: some View {
        HStack(
            alignment: .top,
            spacing: StudioTokens.Spacing.small
        ) {
            Image(systemName: "flask")
                .font(.title3)
                .foregroundStyle(StudioTokens.Color.warning)
                .frame(minWidth: 30, minHeight: 30)
                .accessibilityHidden(true)

            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.xSmall
            ) {
                HStack(alignment: .firstTextBaseline) {
                    Text(artifact.article.title)
                        .font(StudioTokens.Typography.sectionHeading)
                        .foregroundStyle(StudioTokens.Color.primaryText)

                    Spacer()

                    if hasAnswerKeyMatch {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(StudioTokens.Color.primaryText)
                            .accessibilityLabel("Answer key matched")
                    }
                }

                Text(artifact.quiz.prompt)
                    .font(StudioTokens.Typography.supporting)
                    .foregroundStyle(StudioTokens.Color.secondaryText)

                LearningBadge(
                    "Experimental answer key",
                    symbol: "checkmark.questionmark",
                    role: .warning
                )
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StudioTokens.Color.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(.vertical, StudioTokens.Spacing.xxSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(artifact.article.title)
        .accessibilityValue(
            "\(artifact.quiz.prompt). Experimental answer key. \(hasAnswerKeyMatch ? "Matched" : "Not matched")"
        )
        .accessibilityHint("Opens the generated quiz.")
    }
}
