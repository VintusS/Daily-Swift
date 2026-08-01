import SwiftUI

struct SourceDocumentDetailView: View {
    let document: SourceDocument
    let chunks: [SourceChunk]
    let isDeleting: Bool
    let onOpenCitation: (SourceCitation) -> Void
    let onDelete: () async -> Bool
    let onDeleted: () -> Void

    @State private var showsDeleteConfirmation = false
    @State private var isDeletionInProgress = false
    @State private var didFailDeletion = false
    @AccessibilityFocusState private var headingIsFocused: Bool
    @AccessibilityFocusState private var deletionFailureIsFocused: Bool

    var body: some View {
        List {
            Section {
                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.small
                ) {
                    Text(document.title)
                        .font(StudioTokens.Typography.display)
                        .foregroundStyle(StudioTokens.Color.primaryText)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($headingIsFocused)

                    if let author = document.author {
                        LabeledContent("Author", value: author)
                    }
                    if let publisher = document.publisher {
                        LabeledContent("Publisher", value: publisher)
                    }
                    LabeledContent(
                        "Original file",
                        value: document.originFileName
                    )
                    LabeledContent(
                        "Rights",
                        value: document.rightsStatus.label
                    )
                    LabeledContent("Storage", value: "Local only")
                    LabeledContent(
                        "Fingerprint",
                        value: shortHash
                    )
                }
                .padding(.vertical, StudioTokens.Spacing.xSmall)
            } header: {
                Text("Provenance")
            } footer: {
                Text(
                    "Locations refer to the normalized offline copy. The original import and every derived passage are removed together."
                )
            }

            Section {
                ForEach(chunks) { chunk in
                    Button {
                        onOpenCitation(chunk.citation)
                    } label: {
                        SourcePassageRow(chunk: chunk)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "source.open-citation.\(chunk.ordinal)"
                    )
                }
            } header: {
                Text("Exact passages")
            } footer: {
                Text(
                    "\(chunks.count) deterministic \(chunks.count == 1 ? "passage" : "passages"). Open one to verify its stored line and character location."
                )
            }

            Section {
                if didFailDeletion {
                    StatusNotice(
                        role: .error,
                        title: "Deletion was not completed",
                        message: "The source may remain, while generated learning that cited it may already be removed. Try again before assuming all private data is gone."
                    )
                    .accessibilityFocused(
                        $deletionFailureIsFocused
                    )
                    .accessibilityIdentifier(
                        "source.delete-failure"
                    )
                }

                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Label(
                        isDeleting || isDeletionInProgress
                            ? "Deleting source"
                            : "Delete source and passages",
                        systemImage: "trash"
                    )
                }
                .disabled(isDeleting || isDeletionInProgress)
                .accessibilityIdentifier("source.delete")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Source")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Delete this source?",
            isPresented: $showsDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Source", role: .destructive) {
                Task {
                    isDeletionInProgress = true
                    didFailDeletion = false
                    if await onDelete() {
                        onDeleted()
                    } else {
                        isDeletionInProgress = false
                        didFailDeletion = true
                        deletionFailureIsFocused = true
                    }
                }
            }
            .accessibilityIdentifier("source.confirm-delete")
        } message: {
            Text(
                "Daily Swift will remove the stored original, normalized text, metadata, derived passages, and generated article and quiz bodies that cite this source. Source-free experimental activity IDs, selected choices, and read or bookmark timestamps may remain locally and never affect mastery. This cannot be undone."
            )
        }
        .task {
            headingIsFocused = true
        }
        .accessibilityIdentifier("source.detail")
    }

    private var shortHash: String {
        String(document.contentHash.prefix(12))
    }
}

private struct SourcePassageRow: View {
    let chunk: SourceChunk

    var body: some View {
        HStack(
            alignment: .top,
            spacing: StudioTokens.Spacing.small
        ) {
            Image(systemName: "quote.opening")
                .foregroundStyle(StudioTokens.Color.action)
                .accessibilityHidden(true)

            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.xSmall
            ) {
                if let heading = chunk.citation.headingLabel {
                    Text(heading)
                        .font(StudioTokens.Typography.sectionHeading)
                        .foregroundStyle(
                            StudioTokens.Color.primaryText
                        )
                }

                Text(chunk.preview)
                    .font(StudioTokens.Typography.supporting)
                    .foregroundStyle(
                        StudioTokens.Color.secondaryText
                    )
                    .lineLimit(3)

                Text(
                    locationLabel
                )
                .font(StudioTokens.Typography.codeCaption)
                .foregroundStyle(StudioTokens.Color.secondaryText)
            }

            Spacer(minLength: StudioTokens.Spacing.xSmall)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StudioTokens.Color.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(.vertical, StudioTokens.Spacing.xxSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            chunk.citation.headingLabel ?? "Source passage"
        )
        .accessibilityValue(
            "\(chunk.preview). \(locationLabel)"
        )
        .accessibilityHint("Opens the exact stored passage.")
    }

    private var locationLabel: String {
        [
            chunk.location.pageLabel,
            chunk.location.lineLabel,
            chunk.location.characterLabel,
        ]
        .compactMap(\.self)
        .joined(separator: ", ")
    }
}
