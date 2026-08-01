import SwiftUI

struct GeneratedArticleReaderView: View {
    let artifact: GeneratedLearningArtifact
    let activity: ArticleActivity
    let onToggleBookmark: () async -> Void
    let onMarkRead: () async -> Void
    let onOpenCitation: (SourceCitation) -> Void
    let onOpenQuiz: () -> Void

    @State private var isUpdating = false
    @AccessibilityFocusState private var headingIsFocused: Bool

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.large
            ) {
                header

                LearningCard {
                    VStack(
                        alignment: .leading,
                        spacing: StudioTokens.Spacing.small
                    ) {
                        Text("Learning objective")
                            .font(StudioTokens.Typography.title)
                            .accessibilityAddTraits(.isHeader)
                        Text(artifact.article.learningObjective)
                            .font(StudioTokens.Typography.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.small
                ) {
                    Text("Generated explanation")
                        .font(StudioTokens.Typography.title)
                        .accessibilityAddTraits(.isHeader)
                    Text(artifact.article.explanation)
                        .font(StudioTokens.Typography.body)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                    if let exampleCode = artifact.article.exampleCode {
                        SelectableCodeBlock(
                            exampleCode,
                            accessibilityLabel: "Generated example code"
                        )
                    }
                }

                citationSection

                StatusNotice(
                    role: .warning,
                    title: "Experimental content",
                    message: "The article passed structure and exact-citation checks. Its factual claims and code were not independently compiled or verified, and reading it does not update mastery."
                )
                .accessibilityIdentifier(
                    "generated-article.experimental-notice"
                )

                VStack(spacing: StudioTokens.Spacing.small) {
                    Button {
                        update(onMarkRead)
                    } label: {
                        Label(
                            activity.completedAt == nil
                                ? "Mark generated article as read"
                                : "Generated article read",
                            systemImage: activity.completedAt == nil
                                ? "checkmark.circle"
                                : "checkmark.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(
                        StudioPrimaryButtonStyle(isBusy: isUpdating)
                    )
                    .disabled(activity.completedAt != nil || isUpdating)
                    .accessibilityIdentifier(
                        "generated-article.mark-read"
                    )

                    Button(action: onOpenQuiz) {
                        Label(
                            "Complete the generated quiz",
                            systemImage: "checklist"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudioSecondaryButtonStyle())
                    .accessibilityIdentifier("generated-article.open-quiz")
                }
            }
            .frame(maxWidth: 720)
            .padding(StudioTokens.Spacing.medium)
            .padding(.bottom, StudioTokens.Spacing.xLarge)
            .frame(maxWidth: .infinity)
        }
        .background(StudioTokens.Color.canvas)
        .navigationTitle(artifact.article.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    update(onToggleBookmark)
                } label: {
                    Label(
                        activity.isBookmarked
                            ? "Remove bookmark"
                            : "Bookmark generated article",
                        systemImage: activity.isBookmarked
                            ? "bookmark.fill"
                            : "bookmark"
                    )
                }
                .disabled(isUpdating)
                .accessibilityIdentifier("generated-article.bookmark")
            }
        }
        .task {
            headingIsFocused = true
        }
        .accessibilityIdentifier("generated-article.reader")
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

            Text(artifact.article.title)
                .font(StudioTokens.Typography.display)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($headingIsFocused)

            Text(artifact.topic)
                .font(StudioTokens.Typography.body)
                .foregroundStyle(StudioTokens.Color.secondaryText)
        }
    }

    @ViewBuilder
    private var headerBadges: some View {
        LearningBadge(
            artifact.trust.label,
            symbol: "flask",
            role: .warning
        )
        LearningBadge(
            "On-device",
            symbol: "iphone"
        )
    }

    private var citationSection: some View {
        LearningCard {
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.small
            ) {
                Label("Exact article citations", systemImage: "quote.opening")
                    .font(StudioTokens.Typography.title)
                    .accessibilityAddTraits(.isHeader)

                ForEach(articleReferences) { reference in
                    Button {
                        onOpenCitation(reference.citation)
                    } label: {
                        GeneratedCitationLabel(reference: reference)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "generated-article.citation.\(reference.id)"
                    )
                }
            }
        }
    }

    private var articleReferences: [GeneratedLearningSourceReference] {
        artifact.article.citationReferenceIDs.compactMap {
            artifact.sourceReference(id: $0)
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

struct GeneratedCitationLabel: View {
    let reference: GeneratedLearningSourceReference

    var body: some View {
        HStack(
            alignment: .top,
            spacing: StudioTokens.Spacing.small
        ) {
            Image(systemName: "scope")
                .foregroundStyle(StudioTokens.Color.action)
                .accessibilityHidden(true)
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.xxSmall
            ) {
                Text(reference.documentTitle)
                    .font(StudioTokens.Typography.sectionHeading)
                    .foregroundStyle(StudioTokens.Color.primaryText)
                Text(locationLabel)
                    .font(StudioTokens.Typography.supporting)
                    .foregroundStyle(StudioTokens.Color.secondaryText)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StudioTokens.Color.secondaryText)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(reference.documentTitle)
        .accessibilityValue(locationLabel)
        .accessibilityHint("Opens the exact stored source passage.")
    }

    private var locationLabel: String {
        [
            reference.citation.headingLabel,
            reference.citation.location.pageLabel,
            reference.citation.location.lineLabel,
        ]
        .compactMap(\.self)
        .joined(separator: ", ")
    }
}
