import SwiftUI

struct SourceRetrievalSection: View {
    let query: String
    let documents: [SourceDocument]
    @Bindable var viewModel: SourceRetrievalViewModel
    let onSearch: () -> Void
    let onOpenCitation: (SourceCitation) -> Void
    let onFiltersChanged: () -> Void

    @AccessibilityFocusState private var statusIsFocused: Bool

    var body: some View {
        Section {
            filterControl

            switch viewModel.state {
            case .idle:
                Label(
                    cleanQuery.isEmpty
                        ? "Ready to search imported passages offline"
                        : "Submit this concept to search exact passages",
                    systemImage: "text.magnifyingglass"
                )
                .font(StudioTokens.Typography.supporting)
                .foregroundStyle(StudioTokens.Color.secondaryText)
                .accessibilityIdentifier("source-retrieval.idle")

            case .searching:
                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.small
                ) {
                    HStack(spacing: StudioTokens.Spacing.small) {
                        ProgressView()
                        VStack(alignment: .leading) {
                            Text("Searching imported passages")
                                .font(
                                    StudioTokens.Typography.sectionHeading
                                )
                            Text(
                                "Verifying current chunks and exact citations on this device."
                            )
                            .font(StudioTokens.Typography.supporting)
                            .foregroundStyle(
                                StudioTokens.Color.secondaryText
                            )
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityFocused($statusIsFocused)

                    Button(
                        "Cancel Search",
                        role: .cancel,
                        action: viewModel.cancel
                    )
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(
                        "source-retrieval.cancel"
                    )
                }
                .accessibilityIdentifier("source-retrieval.searching")

            case let .results(results):
                Label(
                    "\(results.count) exact \(results.count == 1 ? "passage" : "passages")",
                    systemImage: "checkmark.circle"
                )
                .font(StudioTokens.Typography.sectionHeading)
                .accessibilityFocused($statusIsFocused)
                .accessibilityIdentifier("source-retrieval.results")

                ForEach(
                    Array(results.enumerated()),
                    id: \.element.citation
                ) { offset, result in
                    Button {
                        onOpenCitation(result.citation)
                    } label: {
                        SourceRetrievalResultRow(result: result)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "source-retrieval.result.\(offset)"
                    )
                }

            case .noResults:
                retrievalStatus(
                    title: "No exact passages found",
                    message: "Try a more specific Swift or iOS concept, clear a source filter, or import another lawful source.",
                    symbol: "magnifyingglass"
                )
                .accessibilityFocused($statusIsFocused)
                .accessibilityIdentifier("source-retrieval.no-results")

            case .cancelled:
                retrievalStatus(
                    title: "Search cancelled",
                    message: "No result state was replaced. Imported sources remain available offline.",
                    symbol: "xmark.circle"
                )
                .accessibilityFocused($statusIsFocused)
                .accessibilityIdentifier("source-retrieval.cancelled")

                Button("Search Again", action: onSearch)
                    .buttonStyle(.bordered)
                    .disabled(cleanQuery.isEmpty)
                    .accessibilityIdentifier(
                        "source-retrieval.search-again"
                    )

            case let .failed(failure):
                retrievalStatus(
                    title: failure.title,
                    message: failure.message,
                    symbol: "exclamationmark.triangle"
                )
                .accessibilityFocused($statusIsFocused)
                .accessibilityIdentifier("source-retrieval.failed")

                if failure == .unavailable {
                    Button("Try Again", action: viewModel.retry)
                        .buttonStyle(.bordered)
                        .disabled(cleanQuery.isEmpty)
                        .accessibilityIdentifier(
                            "source-retrieval.retry"
                        )
                }
            }

            if !cleanQuery.isEmpty,
               !viewModel.isSearching {
                Button(action: onSearch) {
                    Label(
                        "Search Imported Passages",
                        systemImage: "magnifyingglass"
                    )
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("source-retrieval.submit")
            }
        } header: {
            Text("Concept search")
        } footer: {
            Label(
                "Search stays on this device and works offline. Results open only after their stored citation is verified.",
                systemImage: "wifi.slash"
            )
            .accessibilityIdentifier("source-retrieval.offline")
        }
        .onChange(of: viewModel.state) {
            _, state in
            switch state {
            case .results, .noResults, .cancelled, .failed:
                statusIsFocused = true
            case .idle, .searching:
                break
            }
        }
    }

    private var cleanQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filterControl: some View {
        Menu {
            Button {
                viewModel.clearSourceFilters()
                onFiltersChanged()
            } label: {
                Label(
                    "All imported sources",
                    systemImage: viewModel.selectedSourceIDs.isEmpty
                        ? "checkmark.circle.fill"
                        : "circle"
                )
            }

            ForEach(documents) { document in
                Button {
                    viewModel.toggleSourceFilter(document.id)
                    onFiltersChanged()
                } label: {
                    Label(
                        document.title,
                        systemImage: viewModel.selectedSourceIDs
                            .contains(document.id)
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                }
            }
        } label: {
            Label(
                filterLabel,
                systemImage: "line.3.horizontal.decrease.circle"
            )
        }
        .accessibilityValue(filterAccessibilityValue)
        .accessibilityHint(
            "Optionally limits concept search to selected imported sources."
        )
        .accessibilityIdentifier("source-retrieval.filters")
    }

    private var filterLabel: String {
        let count = viewModel.selectedSourceIDs.count
        return count == 0
            ? "All imported sources"
            : "\(count) \(count == 1 ? "source" : "sources") selected"
    }

    private var filterAccessibilityValue: String {
        viewModel.selectedSourceIDs.isEmpty
            ? "No source filter"
            : filterLabel
    }

    private func retrievalStatus(
        title: String,
        message: String,
        symbol: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: StudioTokens.Spacing.xSmall
        ) {
            Label(title, systemImage: symbol)
                .font(StudioTokens.Typography.sectionHeading)
                .foregroundStyle(StudioTokens.Color.primaryText)
            Text(message)
                .font(StudioTokens.Typography.supporting)
                .foregroundStyle(StudioTokens.Color.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SourceRetrievalResultRow: View {
    let result: SourceRetrievalMatch

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
                spacing: StudioTokens.Spacing.xSmall
            ) {
                Text(result.document.title)
                    .font(StudioTokens.Typography.sectionHeading)
                    .foregroundStyle(StudioTokens.Color.primaryText)

                if let heading = result.citation.headingLabel {
                    Text(heading)
                        .font(StudioTokens.Typography.supporting)
                        .foregroundStyle(
                            StudioTokens.Color.secondaryText
                        )
                }

                Text(result.excerpt)
                    .font(StudioTokens.Typography.body)
                    .foregroundStyle(StudioTokens.Color.primaryText)
                    .lineLimit(4)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: StudioTokens.Spacing.xSmall) {
                        locationBadges
                    }
                    VStack(
                        alignment: .leading,
                        spacing: StudioTokens.Spacing.xxSmall
                    ) {
                        locationBadges
                    }
                }
            }

            Spacer(minLength: StudioTokens.Spacing.xSmall)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StudioTokens.Color.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(.vertical, StudioTokens.Spacing.xxSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(result.document.title)
        .accessibilityValue(
            [
                result.citation.headingLabel,
                result.excerpt,
                locationLabel,
                "Verified locally",
            ]
            .compactMap(\.self)
            .joined(separator: ". ")
        )
        .accessibilityHint("Opens this exact offline citation.")
    }

    @ViewBuilder
    private var locationBadges: some View {
        if let pageLabel = result.citation.location.pageLabel {
            LearningBadge(pageLabel, symbol: "doc.richtext")
        }
        LearningBadge(
            result.citation.location.lineLabel,
            symbol: "list.number"
        )
        LearningBadge(
            "Offline",
            symbol: "wifi.slash",
            role: .information
        )
    }

    private var locationLabel: String {
        [
            result.citation.location.pageLabel,
            result.citation.location.lineLabel,
            result.citation.location.characterLabel,
        ]
        .compactMap(\.self)
        .joined(separator: ", ")
    }
}
