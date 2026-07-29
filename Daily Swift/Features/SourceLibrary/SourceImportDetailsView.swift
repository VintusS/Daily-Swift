import SwiftUI

struct SourceImportDetailsView: View {
    let pendingImport: PendingSourceImport
    let isImporting: Bool
    let onCancel: () -> Void
    let onImport: (SourceImportMetadata) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var author = ""
    @State private var publisher = ""
    @State private var rightsStatus: SourceRightsStatus?
    @State private var importTask: Task<Void, Never>?

    init(
        pendingImport: PendingSourceImport,
        isImporting: Bool,
        onCancel: @escaping () -> Void,
        onImport: @escaping (SourceImportMetadata) async -> Void
    ) {
        self.pendingImport = pendingImport
        self.isImporting = isImporting
        self.onCancel = onCancel
        self.onImport = onImport
        _title = State(initialValue: pendingImport.suggestedTitle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    LabeledContent(
                        "File",
                        value: pendingImport.fileURL.lastPathComponent
                    )

                    TextField("Title", text: $title)
                        .textContentType(.name)
                        .accessibilityIdentifier("source-import.title")

                    TextField(
                        "Author, if known",
                        text: $author
                    )
                    .textContentType(.name)
                    .accessibilityIdentifier("source-import.author")

                    TextField(
                        "Publisher, if known",
                        text: $publisher
                    )
                    .textContentType(.organizationName)
                    .accessibilityIdentifier("source-import.publisher")
                }

                Section {
                    Picker("Rights status", selection: $rightsStatus) {
                        Text("Choose a rights status")
                            .tag(nil as SourceRightsStatus?)
                        ForEach(SourceRightsStatus.allCases) { status in
                            Text(status.label)
                                .tag(status as SourceRightsStatus?)
                        }
                    }
                    .accessibilityIdentifier("source-import.rights")

                    if let rightsStatus {
                        Text(rightsStatus.detail)
                            .font(StudioTokens.Typography.supporting)
                            .foregroundStyle(
                                StudioTokens.Color.secondaryText
                            )
                    }
                } header: {
                    Text("Permission")
                } footer: {
                    Text(
                        "Import only material you have the right to use. The source remains local to this device."
                    )
                }

                Section {
                    Label(
                        "Daily Swift will copy this source into private app storage so citations remain available offline.",
                        systemImage: "lock.doc"
                    )
                    .font(StudioTokens.Typography.supporting)
                }
            }
            .navigationTitle("Import Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        isImporting
                            ? "Cancel Import"
                            : "Cancel"
                    ) {
                        if isImporting {
                            importTask?.cancel()
                        } else {
                            onCancel()
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("source-import.cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if isImporting {
                            ProgressView()
                                .accessibilityLabel("Importing source")
                        } else {
                            Text("Import")
                        }
                    }
                    .disabled(!canImport || isImporting)
                    .accessibilityIdentifier("source-import.confirm")
                }
            }
            .interactiveDismissDisabled(isImporting)
            .onDisappear {
                importTask?.cancel()
            }
            .accessibilityIdentifier("source-import.details")
        }
    }

    private var canImport: Bool {
        !title.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty && rightsStatus != nil
    }

    private func submit() {
        guard let rightsStatus else {
            return
        }
        importTask = Task {
            await onImport(
                SourceImportMetadata(
                    title: title,
                    author: author,
                    publisher: publisher,
                    rightsStatus: rightsStatus
                )
            )
            dismiss()
            importTask = nil
        }
    }
}
