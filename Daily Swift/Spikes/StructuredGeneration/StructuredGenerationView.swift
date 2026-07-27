#if DEBUG
import Accessibility
import SwiftUI

@MainActor
struct StructuredGenerationView: View {
    @State private var provider: StructuredGenerationProvider = .fixture
    @State private var viewModel = StructuredGenerationViewModel(
        request: StructuredGenerationFixtures.request,
        client: StructuredGenerationFixtures.validClient
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introduction
                    providerPicker
                    statusCard
                    controls
                    validationDetails
                    generatedContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Generation spike")
            .accessibilityIdentifier("structured-generation.title")
        }
        .task {
            viewModel.checkAvailability()
        }
        .onChange(of: provider) { _, newProvider in
            viewModel.cancel()
            viewModel = Self.makeViewModel(for: newProvider)
            viewModel.checkAvailability()
        }
        .onChange(of: viewModel.state) { _, _ in
            AccessibilityNotification.Announcement(
                "\(statusTitle). \(statusDetail)"
            )
            .post()
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Packet 000-A")
                .font(.headline)
            Text(
                "Generate one typed lesson and exercise, then block any candidate "
                    + "that fails deterministic validation."
            )
            .foregroundStyle(.secondary)
        }
    }

    private var providerPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Provider")
                .font(.headline)

            Picker("Provider", selection: $provider) {
                ForEach(StructuredGenerationProvider.allCases) { provider in
                    Text(provider.title).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("structured-generation.provider")
        }
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusSymbol)
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.headline)
                Text(statusDetail)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("structured-generation.status")
    }

    @ViewBuilder
    private var validationDetails: some View {
        if case let .rejected(error) = viewModel.state {
            let categories = Array(
                Set(error.failures.map(\.category))
            )
            .sorted { $0.title < $1.title }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(categories, id: \.rawValue) { category in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title)
                                Text(category.rawValue)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }

                    Text(
                        "Only privacy-safe categories are shown. Source and "
                            + "generated text are not included in diagnostics."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Validation checks", systemImage: "checklist.unchecked")
            }
            .accessibilityIdentifier(
                "structured-generation.validation-issues"
            )
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch viewModel.state {
        case .checkingAvailability:
            ProgressView("Checking availability")
                .frame(maxWidth: .infinity, alignment: .leading)

        case .generating:
            HStack(spacing: 12) {
                ProgressView("Generating candidate")
                Button("Cancel", role: .cancel) {
                    viewModel.cancel()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("structured-generation.cancel")
            }

        case .unavailable:
            VStack(alignment: .leading, spacing: 12) {
                if provider == .onDevice {
                    Button("Use deterministic fixture") {
                        provider = .fixture
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("structured-generation.use-fixture")
                }

                Button("Check availability again") {
                    viewModel.checkAvailability()
                }
                .buttonStyle(.bordered)
            }

        case .idle:
            Button("Check availability") {
                viewModel.checkAvailability()
            }
            .buttonStyle(.borderedProminent)

        case .ready, .content, .rejected, .failed, .cancelled:
            Button("Generate candidate") {
                viewModel.generate()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("structured-generation.generate")
        }
    }

    @ViewBuilder
    private var generatedContent: some View {
        if case let .content(artifact) = viewModel.state {
            VStack(alignment: .leading, spacing: 20) {
                lessonCard(artifact.lesson)
                exerciseCard(artifact.exercise)
                Text(
                    "Schema \(artifact.schemaVersion) · "
                        + "Swift \(artifact.swiftVersion) · "
                        + "iOS \(artifact.minimumIOSVersion)+ · "
                        + "\(artifact.promptVersion) · \(artifact.modelVersion)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func lessonCard(
        _ lesson: StructuredLessonArtifact
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(lesson.learningObjective)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(lesson.explanation)
                Text(lesson.exampleCode)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                citationText(lesson.citationIDs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(lesson.title, systemImage: "book.pages")
        }
        .accessibilityIdentifier("structured-generation.lesson")
    }

    private func exerciseCard(
        _ exercise: StructuredMultipleChoiceExercise
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(exercise.prompt)
                    .font(.headline)

                ForEach(exercise.choices) { choice in
                    let isCorrect = choice.id == exercise.correctChoiceID
                    Label(
                        choice.text,
                        systemImage: isCorrect ? "checkmark.circle.fill" : "circle"
                    )
                    .accessibilityLabel(
                        isCorrect
                            ? "Correct answer: \(choice.text)"
                            : "Option: \(choice.text)"
                    )
                }

                Text(exercise.explanation)
                    .foregroundStyle(.secondary)
                citationText(exercise.citationIDs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Structurally validated exercise", systemImage: "checklist")
        }
        .accessibilityIdentifier("structured-generation.exercise")
    }

    private func citationText(_ citationIDs: [String]) -> some View {
        Text("Citations: \(citationIDs.joined(separator: ", "))")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var statusTitle: String {
        switch viewModel.state {
        case .idle:
            "Not checked"
        case .checkingAvailability:
            "Checking availability"
        case .ready:
            "Ready"
        case .unavailable:
            "On-device model unavailable"
        case .generating:
            "Generating"
        case .content:
            "Structurally validated"
        case .rejected:
            "Candidate rejected"
        case .failed:
            "Generation failed"
        case .cancelled:
            "Generation cancelled"
        }
    }

    private var statusDetail: String {
        switch viewModel.state {
        case .idle:
            "Choose a provider and check whether it can generate."
        case .checkingAvailability:
            "The learning fallback remains available during this check."
        case .ready:
            "The selected provider can accept a generation request."
        case let .unavailable(reason):
            unavailabilityDetail(reason)
        case .generating:
            "Source cards stay on device. You can cancel at any time."
        case .content:
            "Both typed artifacts passed the current citation, version-tag, "
                + "and answer-shape checks."
        case let .rejected(error):
            "Blocked before presentation with \(error.failures.count) "
                + "validation issue(s). Review the checks below."
        case let .failed(failure):
            failureDetail(failure)
        case .cancelled:
            "No partial result was shown. A new request can begin immediately."
        }
    }

    private var statusSymbol: String {
        switch viewModel.state {
        case .idle, .checkingAvailability:
            "hourglass"
        case .ready:
            "checkmark.circle"
        case .unavailable:
            "iphone.slash"
        case .generating:
            "sparkles"
        case .content:
            "checkmark.seal.fill"
        case .rejected:
            "exclamationmark.shield"
        case .failed:
            "exclamationmark.triangle"
        case .cancelled:
            "xmark.circle"
        }
    }

    private func unavailabilityDetail(
        _ reason: StructuredGenerationUnavailability
    ) -> String {
        switch reason {
        case .deviceNotSupported:
            "This device cannot run the system model. Use deterministic content."
        case .intelligenceDisabled:
            "Apple Intelligence is disabled. Learning remains available through the fixture."
        case .modelNotReady:
            "The system model is not ready yet. Retry later or use the fixture now."
        case .languageOrRegionUnsupported:
            "The current language or region is unsupported by the system model."
        case .other:
            "The system model is unavailable for an unrecognized reason."
        }
    }

    private func failureDetail(
        _ failure: StructuredGenerationClientFailure
    ) -> String {
        switch failure {
        case .contextWindowExceeded:
            "The bounded request exceeded the available model context."
        case .safetyGuardrail:
            "The system model stopped this request through its safety controls."
        case .requestFailed:
            "The model could not complete the request. Retry or use deterministic content."
        case .invalidResponse:
            "The typed response could not be decoded or mapped safely and was "
                + "not presented."
        case .unknown:
            "An unknown error occurred. No candidate was presented."
        }
    }

    private static func makeViewModel(
        for provider: StructuredGenerationProvider
    ) -> StructuredGenerationViewModel {
        let client: any StructuredGenerationClient
        switch provider {
        case .fixture:
            client = StructuredGenerationFixtures.validClient
        case .onDevice:
            client = FoundationModelGenerationClient()
        }

        return StructuredGenerationViewModel(
            request: StructuredGenerationFixtures.request,
            client: client
        )
    }
}

private enum StructuredGenerationProvider: String, CaseIterable, Identifiable {
    case fixture
    case onDevice

    var id: Self { self }

    var title: String {
        switch self {
        case .fixture:
            "Fixture"
        case .onDevice:
            "On-device"
        }
    }
}

#Preview {
    StructuredGenerationView()
}
#endif
