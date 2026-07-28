import SwiftUI

struct SourceDocumentDetailView: View {
    let document: SourceDocument
    let chunks: [SourceChunk]
    let isDeleting: Bool
    let onOpenCitation: (SourceCitation) -> Void
    let onDelete: () async -> Bool
    let onDeleted: () -> Void

    @State private var showsDeleteConfirmation = false
    @AccessibilityFocusState private var headingIsFocused: Bool

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
                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Label(
                        isDeleting
                            ? "Deleting source"
                            : "Delete source and passages",
                        systemImage: "trash"
                    )
                }
                .disabled(isDeleting)
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
                    if await onDelete() {
                        onDeleted()
                    }
                }
            }
            .accessibilityIdentifier("source.confirm-delete")
        } message: {
            Text(
                "Daily Swift will remove the stored original, normalized text, metadata, and every derived passage. This cannot be undone."
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
                    "\(chunk.location.lineLabel), \(chunk.location.characterLabel)"
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
            "\(chunk.preview). \(chunk.location.lineLabel), \(chunk.location.characterLabel)"
        )
        .accessibilityHint("Opens the exact stored passage.")
    }
}
