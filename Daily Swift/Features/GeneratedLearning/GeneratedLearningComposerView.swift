import SwiftUI
import UIKit

struct GeneratedLearningComposerView: View {
    @Bindable var viewModel: GeneratedLearningViewModel
    let documents: [SourceDocument]
    let onOpenArticle: (GeneratedLearningArtifact) -> Void
    let onOpenQuiz: (UUID) -> Void
    let onOpenReviewedLearning: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @AccessibilityFocusState private var statusIsFocused: Bool

    var body: some View {
        List {
            introduction
            topicSection
            sourceSection
            actionSection
            stateSection
            sourceHelpSection
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Generate Learning")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadIfNeeded()
            viewModel.reconcileAvailableSources(
                Set(documents.map(\.id))
            )
        }
        .onChange(of: viewModel.state) { _, state in
            guard let announcement = state.announcement else {
                return
            }
            UIAccessibility.post(
                notification: .announcement,
                argument: announcement
            )
            statusIsFocused = true
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, viewModel.isGenerating {
                viewModel.cancel()
            }
        }
        .onDisappear {
            if viewModel.isGenerating {
                viewModel.cancel()
            }
        }
        .accessibilityIdentifier("generated-learning.composer")
    }

    private var introduction: some View {
        Section {
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.small
            ) {
                Label(
                    "Private on-device generation",
                    systemImage: "sparkles.rectangle.stack"
                )
                .font(StudioTokens.Typography.title)
                .accessibilityAddTraits(.isHeader)

                Text(
                    "Create one article and one quiz from up to four exact passages in your imported sources. Requests run one at a time and stay on this device."
                )
                .font(StudioTokens.Typography.body)
                .foregroundStyle(StudioTokens.Color.secondaryText)

                LearningBadge(
                    "Experimental / User Material",
                    symbol: "flask",
                    role: .warning
                )
            }
            .padding(.vertical, StudioTokens.Spacing.xSmall)
        } footer: {
            Text(
                "Availability is known, but generation quality, latency, memory, energy, and thermal behavior are not benchmarked. Reviewed learning always remains available."
            )
        }
    }

    private var topicSection: some View {
        Section("Learning topic") {
            TextField(
                "For example: actor isolation",
                text: $viewModel.topic,
                axis: .vertical
            )
            .lineLimit(2...4)
            .textInputAutocapitalization(.sentences)
            .disabled(viewModel.isBusy)
            .accessibilityHint(
                "Use words that appear in your imported sources."
            )
            .accessibilityIdentifier("generated-learning.topic")

            Text(
                "\(viewModel.topic.count) of \(GeneratedLearningValidationLimits.maximumTopicCharacters) characters"
            )
            .font(StudioTokens.Typography.caption)
            .foregroundStyle(StudioTokens.Color.secondaryText)
        }
    }

    @ViewBuilder
    private var sourceSection: some View {
        Section {
            if documents.isEmpty {
                ContentUnavailableView(
                    "Import a source first",
                    systemImage: "doc.badge.plus",
                    description: Text(
                        "Import a lawful PDF, TXT, or Markdown file in Library before requesting generated learning."
                    )
                )
                .accessibilityIdentifier("generated-learning.no-sources")
            } else {
                Button {
                    viewModel.clearSourceSelection()
                } label: {
                    HStack {
                        Label("Use all imported sources", systemImage: "books.vertical")
                        Spacer()
                        if viewModel.selectedSourceIDs.isEmpty {
                            Image(systemName: "checkmark")
                                .accessibilityHidden(true)
                        }
                    }
                }
                .disabled(viewModel.isBusy)
                .accessibilityValue(
                    viewModel.selectedSourceIDs.isEmpty
                        ? "Selected"
                        : "Not selected"
                )
                .accessibilityIdentifier("generated-learning.source.all")

                ForEach(documents) { document in
                    Button {
                        viewModel.toggleSource(document.id)
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading) {
                                Text(document.title)
                                Text(document.rightsStatus.label)
                                    .font(StudioTokens.Typography.caption)
                                    .foregroundStyle(
                                        StudioTokens.Color.secondaryText
                                    )
                            }
                            Spacer()
                            if viewModel.selectedSourceIDs.contains(
                                document.id
                            ) {
                                Image(systemName: "checkmark")
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .disabled(viewModel.isBusy)
                    .accessibilityValue(
                        viewModel.selectedSourceIDs.contains(document.id)
                            ? "Selected"
                            : "Not selected"
                    )
                    .accessibilityIdentifier(
                        "generated-learning.source.\(document.id.uuidString.lowercased())"
                    )
                }
            }
        } header: {
            Text("Source scope")
        } footer: {
            Text(
                viewModel.selectedSourceIDs.isEmpty
                    ? "Search includes every current imported source."
                    : "Search is limited to \(viewModel.selectedSourceIDs.count) selected source\(viewModel.selectedSourceIDs.count == 1 ? "" : "s")."
            )
        }
    }

    private var actionSection: some View {
        Section {
            if viewModel.state == .generating {
                HStack(spacing: StudioTokens.Spacing.small) {
                    ProgressView("Generating article and quiz")
                    Spacer()
                    Button("Cancel", role: .cancel) {
                        viewModel.cancel()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("generated-learning.cancel")
                }
            } else if viewModel.state == .cancelling {
                ProgressView("Cancelling safely")
                    .accessibilityIdentifier(
                        "generated-learning.cancelling"
                    )
            } else if viewModel.state == .finalizing {
                ProgressView("Validating and saving")
                    .accessibilityIdentifier(
                        "generated-learning.finalizing"
                    )
            } else {
                Button {
                    viewModel.generate()
                } label: {
                    Label(
                        viewModel.latestArtifact == nil
                            ? "Generate article and quiz"
                            : "Generate another pair",
                        systemImage: "sparkles"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudioPrimaryButtonStyle())
                .disabled(!canGenerate)
                .accessibilityHint(
                    canGenerate
                        ? "Retrieves exact local passages, then starts one foreground on-device request."
                        : "Add a focused topic and import at least one source first."
                )
                .accessibilityIdentifier("generated-learning.generate")
            }
        }
    }

    @ViewBuilder
    private var stateSection: some View {
        Section("Generation status") {
            switch viewModel.state {
            case .loading:
                HStack(spacing: StudioTokens.Spacing.small) {
                    ProgressView()
                    Text("Checking generated history and model availability")
                }
                .accessibilityElement(children: .combine)

            case .ready:
                StatusNotice(
                    role: .information,
                    title: "Ready for a foreground request",
                    message: "Daily Swift will retrieve exact passages before asking the on-device model."
                )
                .accessibilityIdentifier(
                    "generated-learning.status.ready"
                )

            case .generating:
                StatusNotice(
                    role: .information,
                    title: "Generating privately",
                    message: "Keep this screen open. You can cancel without saving partial content."
                )

            case .cancelling:
                StatusNotice(
                    role: .information,
                    title: "Finishing cancellation",
                    message: "Daily Swift is waiting for the current request to stop and confirming that no partial article or quiz remains."
                )

            case .finalizing:
                StatusNotice(
                    role: .information,
                    title: "Validating before save",
                    message: "Generation has finished. Daily Swift is rechecking the exact sources and saving the accepted pair; this short final step cannot be cancelled."
                )
                .accessibilityIdentifier(
                    "generated-learning.status.finalizing"
                )

            case let .generated(artifactID):
                if let artifact = viewModel.artifact(id: artifactID) {
                    generatedSuccess(artifact)
                }

            case .cancelled:
                recoveryNotice(
                    title: "Generation cancelled",
                    message: "No partial article or quiz was saved."
                )
                .accessibilityIdentifier(
                    "generated-learning.status.cancelled"
                )

            case let .unavailable(reason):
                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.small
                ) {
                    recoveryNotice(
                        title: reason.title,
                        message: reason.message
                    )
                    Button("Check availability again") {
                        viewModel.checkAvailability()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(
                        "generated-learning.check-availability"
                    )
                }
                .accessibilityIdentifier(
                    "generated-learning.status.unavailable"
                )

            case let .rejected(categories):
                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.small
                ) {
                    StatusNotice(
                        role: .warning,
                        title: "Generated content was blocked",
                        message: "The candidate failed deterministic presentation checks and was not saved."
                    )
                    ForEach(categories, id: \.rawValue) { category in
                        Label(
                            category.title,
                            systemImage: "exclamationmark.shield"
                        )
                        .font(StudioTokens.Typography.supporting)
                    }
                    fallbackButton
                }
                .accessibilityIdentifier(
                    "generated-learning.status.rejected"
                )

            case let .failed(failure):
                if failure == .storageUnavailable {
                    VStack(
                        alignment: .leading,
                        spacing: StudioTokens.Spacing.small
                    ) {
                        recoveryNotice(
                            title: failure.title,
                            message: failure.message
                        )
                        Button("Retry loading generated history") {
                            Task {
                                await viewModel.reload()
                            }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(
                            "generated-learning.retry-storage"
                        )
                    }
                    .accessibilityIdentifier(
                        "generated-learning.status.storage-unavailable"
                    )
                } else {
                    recoveryNotice(
                        title: failure.title,
                        message: failure.message
                    )
                    .accessibilityIdentifier(
                        "generated-learning.status.failed"
                    )
                }
            }
        }
        .accessibilityFocused($statusIsFocused)
    }

    private func generatedSuccess(
        _ artifact: GeneratedLearningArtifact
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: StudioTokens.Spacing.small
        ) {
            StatusNotice(
                role: .success,
                title: "Article and quiz saved",
                message: "Both artifacts passed structural and exact-citation checks. They remain experimental and do not update mastery."
            )

            Button {
                onOpenArticle(artifact)
            } label: {
                Label("Read generated article", systemImage: "book.pages")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(StudioPrimaryButtonStyle())
            .accessibilityIdentifier("generated-learning.open-article")

            Button {
                onOpenQuiz(artifact.id)
            } label: {
                Label("Complete generated quiz", systemImage: "checklist")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(StudioSecondaryButtonStyle())
            .accessibilityIdentifier("generated-learning.open-quiz")
        }
        .accessibilityIdentifier("generated-learning.status.generated")
    }

    private func recoveryNotice(
        title: String,
        message: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: StudioTokens.Spacing.small
        ) {
            StatusNotice(
                role: .warning,
                title: "\(title)",
                message: "\(message)"
            )
            fallbackButton
        }
    }

    private var fallbackButton: some View {
        Button {
            onOpenReviewedLearning()
        } label: {
            Label("Continue with reviewed learning", systemImage: "checkmark.shield")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(StudioSecondaryButtonStyle())
        .accessibilityIdentifier("generated-learning.fallback")
    }

    private var sourceHelpSection: some View {
        Section {
            Link(
                destination: URL(
                    string: "https://developer.apple.com/documentation/"
                )!
            ) {
                Label(
                    "Open Apple Developer Documentation",
                    systemImage: "safari"
                )
            }

            Link(
                destination: URL(
                    string: "https://www.hackingwithswift.com/"
                )!
            ) {
                Label("Open Hacking with Swift", systemImage: "safari")
            }

            Link(
                destination: URL(
                    string: "https://www.hackingwithswift.com/license"
                )!
            ) {
                Label(
                    "Review Hacking with Swift license",
                    systemImage: "doc.text.magnifyingglass"
                )
            }
        } header: {
            Text("Apple and trusted teaching sources")
        } footer: {
            Text(
                "Daily Swift does not crawl or bundle these sites. Save and import only material you are permitted to use, choose its correct rights status, and keep private generated derivatives on device."
            )
        }
    }

    private var canGenerate: Bool {
        !documents.isEmpty
            && !viewModel.topic.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
            && viewModel.topic.count
                <= GeneratedLearningValidationLimits.maximumTopicCharacters
            && viewModel.canRequestGeneration
    }
}
