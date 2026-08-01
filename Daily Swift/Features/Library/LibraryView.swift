import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct LibraryView: View {
    let catalog: LearningCatalog
    let snapshot: LearningProgressSnapshot
    let generatedArtifacts: [GeneratedLearningArtifact]
    @Bindable var sourceLibraryViewModel: SourceLibraryViewModel
    @Bindable var sourceRetrievalViewModel: SourceRetrievalViewModel
    let onOpenArticle: (String) -> Void
    let onGenerateLearning: () -> Void
    let onOpenGeneratedArticle: (GeneratedLearningArtifact) -> Void
    let onOpenSource: (UUID) -> Void
    let onOpenCitation: (SourceCitation) -> Void

    @State private var searchText = ""
    @State private var showsBookmarksOnly = false
    @State private var isFileImporterPresented = false
    @State private var isAwaitingFileSelection = false

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

    private var visibleGeneratedArtifacts: [GeneratedLearningArtifact] {
        generatedArtifacts.filter { artifact in
            let activity = snapshot.activity(for: artifact.articleID)
            let matchesBookmark = !showsBookmarksOnly
                || activity.isBookmarked
            let query = searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let matchesSearch = query.isEmpty
                || artifact.article.title
                    .localizedCaseInsensitiveContains(query)
                || artifact.topic.localizedCaseInsensitiveContains(query)
                || artifact.article.learningObjective
                    .localizedCaseInsensitiveContains(query)
            return matchesBookmark && matchesSearch
        }
    }

    private var visibleSources: [SourceDocument] {
        guard !showsBookmarksOnly else {
            return []
        }
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return sourceLibraryViewModel.documents.filter { document in
            query.isEmpty
                || document.title.localizedCaseInsensitiveContains(query)
                || document.originFileName
                    .localizedCaseInsensitiveContains(query)
                || document.author?
                    .localizedCaseInsensitiveContains(query) == true
                || document.publisher?
                    .localizedCaseInsensitiveContains(query) == true
        }
    }

    var body: some View {
        List {
            if !showsBookmarksOnly {
                Section {
                    Button(action: onGenerateLearning) {
                        Label(
                            "Generate article and quiz from sources",
                            systemImage: "sparkles.rectangle.stack"
                        )
                    }
                    .accessibilityHint(
                        "Opens a private, foreground on-device generation request using exact imported passages."
                    )
                    .accessibilityIdentifier(
                        "generated-learning.open-composer"
                    )
                } header: {
                    Text("Generated learning")
                } footer: {
                    Text(
                        "Generated content is experimental user material. It keeps exact citations and never updates mastery."
                    )
                }
            }

            if sourceLibraryViewModel.feedback != .idle {
                Section {
                    SourceLibraryFeedbackNotice(
                        feedback: sourceLibraryViewModel.feedback,
                        onOpenSource: onOpenSource,
                        onDismiss:
                            sourceLibraryViewModel.clearFeedback
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            if !showsBookmarksOnly {
                if sourceLibraryViewModel.state == .ready,
                   !sourceLibraryViewModel.documents.isEmpty {
                    SourceRetrievalSection(
                        query: searchText,
                        documents: sourceLibraryViewModel.documents,
                        viewModel: sourceRetrievalViewModel,
                        onSearch: searchImportedPassages,
                        onOpenCitation: onOpenCitation,
                        onFiltersChanged: searchAfterFilterChange
                    )
                }

                Section {
                    switch sourceLibraryViewModel.state {
                    case .loading:
                        HStack(spacing: StudioTokens.Spacing.small) {
                            ProgressView()
                            Text("Loading imported sources")
                        }
                        .accessibilityElement(children: .combine)

                    case let .failed(failure):
                        VStack(
                            alignment: .leading,
                            spacing: StudioTokens.Spacing.small
                        ) {
                            Text(failure.title)
                                .font(
                                    StudioTokens.Typography.sectionHeading
                                )
                            Text(failure.message)
                                .font(StudioTokens.Typography.supporting)
                                .foregroundStyle(
                                    StudioTokens.Color.secondaryText
                                )
                            Button(
                                "Try Again",
                                action:
                                    sourceLibraryViewModel.retryLoad
                            )
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier(
                                "source-library.retry"
                            )
                        }

                    case .ready:
                        if visibleSources.isEmpty {
                            VStack(
                                alignment: .leading,
                                spacing: StudioTokens.Spacing.small
                            ) {
                                Label(
                                    searchText.isEmpty
                                        ? "No imported sources yet"
                                        : "No matching imported sources",
                                    systemImage: "doc.badge.plus"
                                )
                                .font(
                                    StudioTokens.Typography.sectionHeading
                                )

                                Text(
                                    searchText.isEmpty
                                        ? "Import a lawful PDF, TXT, or Markdown file to keep it private and cite it offline."
                                        : "Try another title, filename, author, or publisher."
                                )
                                .font(StudioTokens.Typography.supporting)
                                .foregroundStyle(
                                    StudioTokens.Color.secondaryText
                                )
                            }
                            .accessibilityIdentifier(
                                "source-library.empty"
                            )
                        } else {
                            ForEach(visibleSources) { document in
                                Button {
                                    onOpenSource(document.id)
                                } label: {
                                    ImportedSourceRow(
                                        document: document,
                                        chunkCount:
                                            sourceLibraryViewModel
                                            .chunks(for: document.id)
                                            .count
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(
                                    "source.open.\(document.id.uuidString.lowercased())"
                                )
                            }
                        }
                    }
                } header: {
                    Text("Private imported sources")
                } footer: {
                    Text(
                        "Imported text stays local. Daily Swift keeps exact provenance and never treats possession as permission to redistribute."
                    )
                }
            }

            if visibleArticles.isEmpty
                && visibleGeneratedArtifacts.isEmpty
                && visibleSources.isEmpty
                && (showsBookmarksOnly
                    || sourceRetrievalViewModel.resultCount == 0) {
                Section {
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
                                : "Try another title, topic, domain, or imported source."
                        )
                    )
                }
            } else {
                if !visibleGeneratedArtifacts.isEmpty {
                    Section {
                        ForEach(visibleGeneratedArtifacts) { artifact in
                            Button {
                                onOpenGeneratedArticle(artifact)
                            } label: {
                                GeneratedArticleHistoryRow(
                                    artifact: artifact,
                                    activity: snapshot.activity(
                                        for: artifact.articleID
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(
                                "generated-article.open.\(artifact.id.uuidString.lowercased())"
                            )
                        }
                    } header: {
                        HStack {
                            Text("Generated articles")
                            Spacer()
                            Text("\(visibleGeneratedArtifacts.count)")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Generated articles")
                        .accessibilityValue(
                            "\(visibleGeneratedArtifacts.count)"
                        )
                        .accessibilityIdentifier(
                            "generated-articles.count"
                        )
                    } footer: {
                        Text(
                            "These private artifacts passed structural and exact-citation checks, not independent factual verification."
                        )
                    }
                }

                if !visibleArticles.isEmpty {
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
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Library")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search articles and passages"
        )
        .onSubmit(of: .search, searchImportedPassages)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isAwaitingFileSelection = true
                    isFileImporterPresented = true
                } label: {
                    Label("Import source", systemImage: "doc.badge.plus")
                }
                .disabled(sourceLibraryViewModel.isImporting)
                .accessibilityIdentifier("source-library.import")
            }

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
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: Self.allowedContentTypes,
            allowsMultipleSelection: false,
            onCompletion: { result in
                isAwaitingFileSelection = false
                sourceLibraryViewModel.receiveFileSelection(result)
            }
        )
        .onChange(of: isFileImporterPresented) {
            wasPresented, isPresented in
            guard wasPresented,
                  !isPresented,
                  isAwaitingFileSelection else {
                return
            }
            isAwaitingFileSelection = false
            sourceLibraryViewModel.recordPickerCancellation()
        }
        .sheet(item: Binding(
            get: { sourceLibraryViewModel.pendingImport },
            set: { newValue in
                if newValue == nil,
                   sourceLibraryViewModel.pendingImport != nil {
                    sourceLibraryViewModel.cancelPendingImport()
                }
            }
        )) { pendingImport in
            SourceImportDetailsView(
                pendingImport: pendingImport,
                isImporting: sourceLibraryViewModel.isImporting,
                onCancel: sourceLibraryViewModel.cancelPendingImport,
                onImport: sourceLibraryViewModel.importPending
            )
        }
        .task {
            await sourceLibraryViewModel.loadIfNeeded()
            reconcileRetrievalSources()
        }
        .onChange(of: searchText) {
            _, _ in
            sourceRetrievalViewModel.queryChanged()
        }
        .onChange(of: sourceLibraryViewModel.snapshot) {
            _, _ in
            reconcileRetrievalSources()
        }
        .onChange(of: sourceRetrievalViewModel.state) {
            _, state in
            guard let announcement = state.announcement else {
                return
            }
            UIAccessibility.post(
                notification: .announcement,
                argument: announcement
            )
        }
        .onChange(of: sourceLibraryViewModel.feedback) {
            _, feedback in
            guard let announcement = feedback.announcement else {
                return
            }
            UIAccessibility.post(
                notification: .announcement,
                argument: announcement
            )
        }
        .accessibilityIdentifier("library.screen")
    }

    private static var allowedContentTypes: [UTType] {
        [UTType.pdf] + ["txt", "md", "markdown"].compactMap {
            UTType(filenameExtension: $0)
        }
    }

    private func searchImportedPassages() {
        guard !showsBookmarksOnly,
              !sourceLibraryViewModel.documents.isEmpty else {
            return
        }
        sourceRetrievalViewModel.search(query: searchText)
    }

    private func searchAfterFilterChange() {
        guard !searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            return
        }
        searchImportedPassages()
    }

    private func reconcileRetrievalSources() {
        sourceRetrievalViewModel.reconcileAvailableSources(
            Set(sourceLibraryViewModel.documents.map(\.id))
        )
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
