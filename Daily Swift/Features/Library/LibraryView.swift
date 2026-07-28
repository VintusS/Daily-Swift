import SwiftUI

struct LibraryView: View {
    let catalog: LearningCatalog
    let snapshot: LearningProgressSnapshot
    let onOpenArticle: (String) -> Void

    @State private var searchText = ""
    @State private var showsBookmarksOnly = false

    private var visibleArticles: [LearningArticle] {
        catalog.articles.filter { article in
            let matchesBookmark = !showsBookmarksOnly
                || snapshot.activity(for: article.id).isBookmarked
            let query = searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let matchesSearch = query.isEmpty
                || article.title.localizedCaseInsensitiveContains(query)
                || article.summary.localizedCaseInsensitiveContains(query)
                || article.domain.title.localizedCaseInsensitiveContains(query)
            return matchesBookmark && matchesSearch
        }
    }

    var body: some View {
        Group {
            if visibleArticles.isEmpty {
                ContentUnavailableView(
                    showsBookmarksOnly
                        ? "No bookmarked articles"
                        : "No matching articles",
                    systemImage: showsBookmarksOnly
                        ? "bookmark"
                        : "magnifyingglass",
                    description: Text(
                        showsBookmarksOnly
                            ? "Bookmark an article and it will remain easy to find here."
                            : "Try another title, topic, or domain."
                    )
                )
            } else {
                List {
                    Section {
                        ForEach(visibleArticles) { article in
                            Button {
                                onOpenArticle(article.id)
                            } label: {
                                ArticleCatalogRow(
                                    article: article,
                                    activity: snapshot.activity(
                                        for: article.id
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(
                                "library.open.\(article.id)"
                            )
                        }
                    } header: {
                        Text("Project-owned learning articles")
                    } footer: {
                        Text(
                            "Project Seed content is bundled for offline testing. It becomes Reviewed Core only after owner review."
                        )
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Library")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search articles"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsBookmarksOnly.toggle()
                } label: {
                    Label(
                        showsBookmarksOnly
                            ? "Show all articles"
                            : "Show bookmarks",
                        systemImage: showsBookmarksOnly
                            ? "books.vertical"
                            : "bookmark"
                    )
                }
                .accessibilityValue(
                    showsBookmarksOnly
                        ? "Bookmarks only"
                        : "All articles"
                )
                .accessibilityIdentifier("library.bookmarks-filter")
            }
        }
        .accessibilityIdentifier("library.screen")
    }
}

private struct ArticleCatalogRow: View {
    let article: LearningArticle
    let activity: ArticleActivity

    var body: some View {
        HStack(
            alignment: .top,
            spacing: StudioTokens.Spacing.small
        ) {
            Image(systemName: article.domain.symbolName)
                .font(.title3)
                .foregroundStyle(StudioTokens.Color.action)
                .frame(minWidth: 30, minHeight: 30)
                .accessibilityHidden(true)

            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.xSmall
            ) {
                HStack(alignment: .firstTextBaseline) {
                    Text(article.title)
                        .font(StudioTokens.Typography.sectionHeading)
                        .foregroundStyle(StudioTokens.Color.primaryText)

                    Spacer()

                    if activity.isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(StudioTokens.Color.action)
                            .accessibilityLabel("Bookmarked")
                    }
                }

                Text(article.summary)
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
        .accessibilityLabel(article.title)
        .accessibilityValue(
            "\(article.summary) \(article.trust.label), \(article.domain.title), \(article.estimatedMinutes) minutes, \(activity.completedAt == nil ? "not read" : "read")\(activity.isBookmarked ? ", bookmarked" : "")"
        )
        .accessibilityHint("Opens the article.")
    }

    @ViewBuilder
    private var metadata: some View {
        LearningBadge(
            article.trust.label,
            symbol: "doc.badge.gearshape",
            role: .information
        )
        LearningBadge(
            activity.completedAt == nil ? "Unread" : "Read",
            symbol: activity.completedAt == nil
                ? "circle"
                : "checkmark.circle.fill",
            role: activity.completedAt == nil ? .neutral : .success
        )
    }
}
