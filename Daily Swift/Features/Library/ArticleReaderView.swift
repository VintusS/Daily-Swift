import SwiftUI

struct ArticleReaderView: View {
    let article: LearningArticle
    let activity: ArticleActivity
    let relatedChallenge: LearningChallenge?
    let onOpened: () async -> Void
    let onToggleBookmark: () async -> Void
    let onMarkRead: () async -> Void
    let onOpenChallenge: (String) -> Void

    @State private var isUpdating = false
    @AccessibilityFocusState private var headingIsFocused: Bool

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.large
            ) {
                header

                ForEach(article.sections) { section in
                    VStack(
                        alignment: .leading,
                        spacing: StudioTokens.Spacing.small
                    ) {
                        Text(section.heading)
                            .font(StudioTokens.Typography.title)
                            .foregroundStyle(
                                StudioTokens.Color.primaryText
                            )
                            .accessibilityAddTraits(.isHeader)

                        Text(section.body)
                            .font(StudioTokens.Typography.body)
                            .foregroundStyle(
                                StudioTokens.Color.primaryText
                            )
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)

                        if let code = section.code {
                            SelectableCodeBlock(
                                code,
                                accessibilityLabel: "\(section.heading) code"
                            )
                        }
                    }
                }

                takeaways

                VStack(spacing: StudioTokens.Spacing.small) {
                    Button {
                        update(onMarkRead)
                    } label: {
                        Label(
                            activity.completedAt == nil
                                ? "Mark article as read"
                                : "Article read",
                            systemImage: activity.completedAt == nil
                                ? "checkmark.circle"
                                : "checkmark.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(
                        StudioPrimaryButtonStyle(isBusy: isUpdating)
                    )
                    .disabled(
                        activity.completedAt != nil || isUpdating
                    )
                    .accessibilityIdentifier("article.mark-read")

                    if let relatedChallenge {
                        Button {
                            onOpenChallenge(relatedChallenge.id)
                        } label: {
                            Label(
                                "Practice this concept",
                                systemImage: "checkmark.seal"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudioSecondaryButtonStyle())
                        .accessibilityIdentifier(
                            "article.practice-concept"
                        )
                    }
                }
            }
            .frame(maxWidth: 720)
            .padding(StudioTokens.Spacing.medium)
            .padding(.bottom, StudioTokens.Spacing.xLarge)
            .frame(maxWidth: .infinity)
        }
        .background(StudioTokens.Color.canvas)
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    update(onToggleBookmark)
                } label: {
                    Label(
                        activity.isBookmarked
                            ? "Remove bookmark"
                            : "Bookmark article",
                        systemImage: activity.isBookmarked
                            ? "bookmark.fill"
                            : "bookmark"
                    )
                }
                .disabled(isUpdating)
                .accessibilityIdentifier("article.bookmark")
            }
        }
        .task {
            await onOpened()
            headingIsFocused = true
        }
        .accessibilityIdentifier("article.reader")
    }

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: StudioTokens.Spacing.small
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: StudioTokens.Spacing.xSmall) {
                    headerBadges
                }

                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.xSmall
                ) {
                    headerBadges
                }
            }

            Text(article.title)
                .font(StudioTokens.Typography.display)
                .foregroundStyle(StudioTokens.Color.primaryText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($headingIsFocused)

            Text(article.summary)
                .font(StudioTokens.Typography.body)
                .foregroundStyle(StudioTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var headerBadges: some View {
        LearningBadge(
            article.trust.label,
            symbol: "doc.badge.gearshape",
            role: .information
        )
        LearningBadge(
            "\(article.estimatedMinutes) min",
            symbol: "clock"
        )
    }

    private var takeaways: some View {
        LearningCard {
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.small
            ) {
                Label("Key takeaways", systemImage: "lightbulb")
                    .font(StudioTokens.Typography.title)
                    .foregroundStyle(StudioTokens.Color.primaryText)
                    .accessibilityAddTraits(.isHeader)

                ForEach(
                    Array(article.takeaways.enumerated()),
                    id: \.offset
                ) { index, takeaway in
                    HStack(alignment: .top) {
                        Text("\(index + 1).")
                            .font(
                                StudioTokens.Typography.codeCaption
                                    .weight(.bold)
                            )
                            .foregroundStyle(
                                StudioTokens.Color.primaryText
                            )

                        Text(takeaway)
                            .font(StudioTokens.Typography.body)
                            .foregroundStyle(
                                StudioTokens.Color.primaryText
                            )
                    }
                }
            }
        }
    }

    private func update(
        _ operation: @escaping () async -> Void
    ) {
        guard !isUpdating else {
            return
        }

        isUpdating = true
        Task {
            await operation()
            isUpdating = false
        }
    }
}
