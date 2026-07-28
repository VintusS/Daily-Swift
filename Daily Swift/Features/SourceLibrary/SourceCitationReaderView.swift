import SwiftUI

struct SourceCitationReaderView: View {
    let citation: SourceCitation
    let resolve: (SourceCitation) async throws -> ResolvedSourceCitation

    @State private var state: CitationReaderState = .loading
    @State private var pdfPage: PDFPagePresentation?
    @AccessibilityFocusState private var passageIsFocused: Bool

    var body: some View {
        Group {
            switch state {
            case .loading:
                ShellProgressView(
                    title: "Opening exact passage",
                    message: "Verifying the offline source and citation."
                )

            case let .content(resolved):
                citationContent(resolved)

            case let .failed(failure):
                ContentUnavailableView {
                    Label(failure.title, systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text(failure.message)
                } actions: {
                    Button("Try Again") {
                        state = .loading
                        Task {
                            await load()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("citation.retry")
                }
            }
        }
        .navigationTitle("Exact Citation")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: citation) {
            await load()
        }
        .sheet(item: $pdfPage) { page in
            PDFPageReaderView(
                fileURL: page.fileURL,
                pageNumber: page.pageNumber
            )
        }
        .accessibilityIdentifier("citation.reader")
    }

    private func citationContent(
        _ resolved: ResolvedSourceCitation
    ) -> some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.large
            ) {
                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.xSmall
                ) {
                    Text(resolved.document.title)
                        .font(StudioTokens.Typography.title)
                        .foregroundStyle(StudioTokens.Color.primaryText)
                        .accessibilityAddTraits(.isHeader)

                    if let heading = resolved.citation.headingLabel {
                        Text(heading)
                            .font(StudioTokens.Typography.supporting)
                            .foregroundStyle(
                                StudioTokens.Color.secondaryText
                            )
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: StudioTokens.Spacing.xSmall) {
                            locationBadges(resolved.citation.location)
                        }
                        VStack(
                            alignment: .leading,
                            spacing: StudioTokens.Spacing.xSmall
                        ) {
                            locationBadges(resolved.citation.location)
                        }
                    }
                }

                LearningCard {
                    VStack(
                        alignment: .leading,
                        spacing: StudioTokens.Spacing.small
                    ) {
                        Label(
                            "Exact stored passage",
                            systemImage: "scope"
                        )
                        .font(StudioTokens.Typography.sectionHeading)
                        .foregroundStyle(StudioTokens.Color.primaryText)
                        .accessibilityAddTraits(.isHeader)

                        Text(resolved.excerpt)
                            .font(StudioTokens.Typography.body)
                            .foregroundStyle(
                                StudioTokens.Color.primaryText
                            )
                            .textSelection(.enabled)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                            .accessibilityFocused($passageIsFocused)
                    }
                }

                if let originalFileURL = resolved.originalFileURL,
                   let pageNumber = resolved.citation.location.startPage {
                    Button {
                        pdfPage = PDFPagePresentation(
                            fileURL: originalFileURL,
                            pageNumber: pageNumber
                        )
                    } label: {
                        Label(
                            "Open \(resolved.citation.location.pageLabel ?? "PDF page")",
                            systemImage: "doc.richtext"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityHint(
                        "Opens the locally stored original PDF at the cited page."
                    )
                    .accessibilityIdentifier("citation.open-pdf-page")
                }

                StatusNotice(
                    role: .information,
                    title: "Verified offline",
                    message: resolved.document.format == .pdf
                        ? "This passage matches the stored chunk hash, normalized-text range, and PDF page provenance."
                        : "This passage matches the stored chunk hash and exact normalized-text range."
                )
            }
            .frame(maxWidth: 720)
            .padding(StudioTokens.Spacing.medium)
            .frame(maxWidth: .infinity)
        }
        .background(StudioTokens.Color.canvas)
    }

    @ViewBuilder
    private func locationBadges(
        _ location: SourceLocation
    ) -> some View {
        if let pageLabel = location.pageLabel {
            LearningBadge(
                pageLabel,
                symbol: "doc.richtext"
            )
        }
        LearningBadge(
            location.lineLabel,
            symbol: "list.number"
        )
        LearningBadge(
            location.characterLabel,
            symbol: "text.cursor"
        )
    }

    private func load() async {
        do {
            let resolved = try await resolve(citation)
            state = .content(resolved)
            passageIsFocused = true
        } catch let failure as SourceLibraryFailure {
            state = .failed(failure)
        } catch {
            state = .failed(.readFailed)
        }
    }
}

private enum CitationReaderState: Equatable {
    case loading
    case content(ResolvedSourceCitation)
    case failed(SourceLibraryFailure)
}

private struct PDFPagePresentation: Identifiable, Equatable {
    let fileURL: URL
    let pageNumber: Int

    var id: String {
        "\(fileURL.path)#\(pageNumber)"
    }
}
