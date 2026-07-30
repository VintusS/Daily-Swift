#if DEBUG
import Accessibility
import SwiftUI

@MainActor
struct StructuredGenerationView: View {
    @State private var provider: StructuredGenerationProvider = .fixture
    @State private var benchmarkEntryID =
        StructuredGenerationBenchmarkPlan.warmUp.id
    @State private var deviceSnapshot =
        StructuredGenerationDeviceSnapshot.capture()
    @State private var viewModel = StructuredGenerationViewModel(
        request: StructuredGenerationFixtures.request,
        client: StructuredGenerationFixtures.validClient
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introduction
                    deviceEnvironment
                    benchmarkControls
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
            refreshDeviceSnapshot()
            viewModel.checkAvailability()
        }
        .onChange(of: provider) { _, newProvider in
            replaceViewModel(for: newProvider)
        }
        .onChange(of: benchmarkEntryID) { _, _ in
            replaceViewModel(for: provider)
        }
        .onChange(of: viewModel.state) { _, _ in
            refreshDeviceSnapshot()
            AccessibilityNotification.Announcement(
                "\(statusTitle). \(statusDetail)"
            )
            .post()
        }
    }

    private var selectedBenchmarkEntry: StructuredGenerationBenchmarkEntry {
        StructuredGenerationBenchmarkPlan.entries.first {
            $0.id == benchmarkEntryID
        } ?? StructuredGenerationBenchmarkPlan.warmUp
    }

    private var selectedRequest: StructuredGenerationRequest {
        StructuredGenerationBenchmarkPlan.request(
            for: selectedBenchmarkEntry
        )
    }

    private var requestSize: FoundationModelRequestSize? {
        try? FoundationModelGenerationClient.requestSize(for: selectedRequest)
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

    private var deviceEnvironment: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                measurementRow(
                    "Hardware",
                    value: deviceSnapshot.hardwareIdentifier
                )
                measurementRow(
                    "Operating system",
                    value: deviceSnapshot.operatingSystem
                )
                measurementRow(
                    "Locale / region",
                    value: "\(deviceSnapshot.localeIdentifier) / "
                        + deviceSnapshot.regionIdentifier
                )
                measurementRow(
                    "Model availability",
                    value: modelAvailabilitySummary
                )
                measurementRow(
                    "Power / battery",
                    value: "\(deviceSnapshot.powerState) / "
                        + deviceSnapshot.batteryLevel
                )
                measurementRow(
                    "Thermal state",
                    value: deviceSnapshot.thermalState
                )

                Button("Refresh environment") {
                    refreshDeviceSnapshot()
                    if provider == .onDevice {
                        viewModel.checkAvailability()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
                .accessibilityIdentifier(
                    "structured-generation.refresh-environment"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Physical-device environment", systemImage: "iphone")
        }
        .accessibilityIdentifier(
            "structured-generation.device-environment"
        )
    }

    private var benchmarkControls: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Benchmark step", selection: $benchmarkEntryID) {
                    ForEach(StructuredGenerationBenchmarkPlan.entries) { entry in
                        Text("\(entry.title): \(entry.sourceCardSummary)")
                            .tag(entry.id)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier(
                    "structured-generation.benchmark-step"
                )

                Text(
                    "\(selectedBenchmarkEntry.sourceCardSummary) · "
                        + "\(selectedRequest.sourceCards.count) bounded "
                        + "source card(s)"
                )
                .font(.subheadline)

                benchmarkNavigation

                if let requestSize {
                    VStack(alignment: .leading, spacing: 6) {
                        measurementRow(
                            "Instructions",
                            value: "\(requestSize.instructionsUTF8Bytes) bytes"
                        )
                        measurementRow(
                            "Rendered prompt",
                            value: "\(requestSize.promptUTF8Bytes) bytes"
                        )
                        measurementRow(
                            "Runtime schema JSON",
                            value: "\(requestSize.schemaJSONBytes) bytes"
                        )
                        measurementRow(
                            "Declared total",
                            value: "\(requestSize.totalUTF8Bytes) bytes"
                        )
                    }
                    .accessibilityIdentifier(
                        "structured-generation.request-size"
                    )
                } else {
                    Text("Request size could not be calculated.")
                        .foregroundStyle(.secondary)
                }

                Text(
                    "Warm-up is unscored. Runs 1–30 use the frozen order. "
                        + "Screen recording and Instruments remain the "
                        + "authoritative timing and memory evidence."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Device evidence run", systemImage: "list.number")
        }
        .accessibilityIdentifier("structured-generation.benchmark")
    }

    private var benchmarkNavigation: some View {
        HStack(spacing: 12) {
            Button("Previous") {
                moveBenchmarkSelection(by: -1)
            }
            .buttonStyle(.bordered)
            .disabled(benchmarkEntryID == 0 || isBusy)

            Button(
                benchmarkEntryID == 0 ? "Start run 1" : "Next"
            ) {
                moveBenchmarkSelection(by: 1)
            }
            .buttonStyle(.bordered)
            .disabled(benchmarkEntryID == 30 || isBusy)
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
            .pickerStyle(.menu)
            .accessibilityIdentifier("structured-generation.provider")

            if provider == .invalidFixture {
                Text(
                    "This fixture is intentionally invalid and uncited. "
                        + "Generate it to verify that presentation is blocked."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
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
        return switch viewModel.state {
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

    private var modelAvailabilitySummary: String {
        guard provider == .onDevice else {
            return "Select On-device to measure"
        }

        return switch viewModel.state {
        case .idle:
            "Not checked"
        case .checkingAvailability:
            "Checking"
        case .unavailable(.deviceNotSupported):
            "Device not eligible"
        case .unavailable(.intelligenceDisabled):
            "Apple Intelligence disabled"
        case .unavailable(.modelNotReady):
            "Model not ready"
        case .unavailable(.languageOrRegionUnsupported):
            "Locale or region unsupported"
        case .unavailable(.other):
            "Unavailable for an unrecognized reason"
        case .ready, .generating, .content, .rejected, .failed, .cancelled:
            "Foundation Models available"
        }
    }

    private var isBusy: Bool {
        switch viewModel.state {
        case .checkingAvailability, .generating:
            true
        default:
            false
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

    private func replaceViewModel(
        for provider: StructuredGenerationProvider
    ) {
        viewModel.cancel()
        viewModel = Self.makeViewModel(
            for: provider,
            request: selectedRequest
        )
        refreshDeviceSnapshot()
        viewModel.checkAvailability()
    }

    private func refreshDeviceSnapshot() {
        deviceSnapshot = StructuredGenerationDeviceSnapshot.capture()
    }

    private func moveBenchmarkSelection(by offset: Int) {
        let proposedID = benchmarkEntryID + offset
        guard (0...30).contains(proposedID) else {
            return
        }
        benchmarkEntryID = proposedID
    }

    private func measurementRow(
        _ label: String,
        value: String
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                Spacer(minLength: 12)
                Text(value)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                Text(value)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private static func makeViewModel(
        for provider: StructuredGenerationProvider,
        request: StructuredGenerationRequest
    ) -> StructuredGenerationViewModel {
        let client: any StructuredGenerationClient
        switch provider {
        case .fixture:
            client = StructuredGenerationFixtures.validClient(for: request)
        case .invalidFixture:
            client = StructuredGenerationFixtures.invalidClient
        case .onDevice:
            client = FoundationModelGenerationClient()
        }

        return StructuredGenerationViewModel(
            request: request,
            client: client
        )
    }
}

private enum StructuredGenerationProvider: String, CaseIterable, Identifiable {
    case fixture
    case invalidFixture
    case onDevice

    var id: Self { self }

    var title: String {
        switch self {
        case .fixture:
            "Deterministic fixture"
        case .invalidFixture:
            "Invalid gate fixture"
        case .onDevice:
            "On-device"
        }
    }
}

#Preview {
    StructuredGenerationView()
}
#endif
