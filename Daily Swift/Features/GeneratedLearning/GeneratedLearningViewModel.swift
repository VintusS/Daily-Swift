import Foundation
import Observation

enum GeneratedLearningPresentationFailure: Equatable, Sendable {
    case invalidTopic
    case insufficientEvidence
    case sourceUnavailable
    case contextTooLarge
    case safetyGuardrail
    case storageUnavailable
    case generationFailed

    var title: String {
        switch self {
        case .invalidTopic:
            "Choose a focused topic"
        case .insufficientEvidence:
            "Not enough matching evidence"
        case .sourceUnavailable:
            "Imported passages are unavailable"
        case .contextTooLarge:
            "This source request is too large"
        case .safetyGuardrail:
            "The model declined this request"
        case .storageUnavailable:
            "Generated history is unavailable"
        case .generationFailed:
            "The article and quiz were not generated"
        }
    }

    var message: String {
        switch self {
        case .invalidTopic:
            "Use a specific concept in 200 characters or fewer."
        case .insufficientEvidence:
            "Try terms that appear in your imported sources or choose different source filters."
        case .sourceUnavailable:
            "Daily Swift could not verify the current local passages. Your imports and saved generated history remain unchanged."
        case .contextTooLarge:
            "Use a narrower topic or fewer selected sources, then try again."
        case .safetyGuardrail:
            "No generated content was saved. Adjust the topic or return to your imported sources and generated history."
        case .storageUnavailable:
            "No unverified artifact was shown. Existing generated files were left unchanged, and imported sources remain available."
        case .generationFailed:
            "No generated content was saved. Check availability and try again, or return to your imported sources and generated history."
        }
    }
}

enum GeneratedLearningViewState: Equatable, Sendable {
    case loading
    case ready
    case generating
    case cancelling
    case finalizing
    case generated(UUID)
    case cancelled
    case unavailable(LanguageModelUnavailability)
    case rejected([GeneratedLearningValidationCategory])
    case failed(GeneratedLearningPresentationFailure)

    var announcement: String? {
        switch self {
        case .loading, .ready, .generating, .cancelling:
            nil
        case .finalizing:
            "Generation finished. Validating exact sources before saving."
        case .generated:
            "Generated article and quiz saved."
        case .cancelled:
            "Generation cancelled. No partial content was saved."
        case let .unavailable(reason):
            "On-device generation unavailable. \(reason.message)"
        case .rejected:
            "Generated content was rejected before presentation."
        case let .failed(failure):
            "\(failure.title). \(failure.message)"
        }
    }
}

extension LanguageModelUnavailability {
    var title: String {
        switch self {
        case .deviceNotSupported:
            "This iPhone does not support local generation"
        case .intelligenceDisabled:
            "Apple Intelligence is turned off"
        case .modelNotReady:
            "The on-device model is not ready"
        case .languageOrRegionUnsupported:
            "The current language or region is unsupported"
        case .other:
            "On-device generation is unavailable"
        }
    }

    var message: String {
        switch self {
        case .deviceNotSupported:
            "Imported sources and previously generated learning remain readable without the model."
        case .intelligenceDisabled:
            "Enable Apple Intelligence in Settings. Your imported sources and generated history remain available."
        case .modelNotReady:
            "Read your imported sources or saved generated learning, then try generation again later."
        case .languageOrRegionUnsupported:
            "Change to a supported configuration. Your imported sources and generated history remain available."
        case .other:
            "Imported sources and previously generated learning remain available."
        }
    }
}

@MainActor
@Observable
final class GeneratedLearningViewModel {
    var topic = ""
    private(set) var selectedSourceIDs: Set<UUID> = []
    private(set) var artifacts: [GeneratedLearningArtifact] = []
    private(set) var state: GeneratedLearningViewState = .loading

    @ObservationIgnored
    private let generator: any GeneratedLearningGenerating

    @ObservationIgnored
    private var activeOperation: Task<Void, Never>?

    @ObservationIgnored
    private var activeOperationID: UUID?

    @ObservationIgnored
    private var hasLoaded = false

    init(generator: any GeneratedLearningGenerating) {
        self.generator = generator
    }

    var isGenerating: Bool {
        state == .generating
    }

    var isBusy: Bool {
        return switch state {
        case .loading, .generating, .cancelling, .finalizing:
            true
        case .ready, .generated, .cancelled, .unavailable,
             .rejected, .failed:
            false
        }
    }

    var canRequestGeneration: Bool {
        guard activeOperation == nil else {
            return false
        }
        return switch state {
        case .ready, .generated, .cancelled, .rejected:
            true
        case let .failed(failure):
            failure != .storageUnavailable
        case .loading, .generating, .cancelling, .finalizing,
             .unavailable:
            false
        }
    }

    var latestArtifact: GeneratedLearningArtifact? {
        guard case let .generated(id) = state else {
            return nil
        }
        return artifact(id: id)
    }

    func artifact(id: UUID) -> GeneratedLearningArtifact? {
        artifacts.first { $0.id == id }
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }
        hasLoaded = true
        await load()
    }

    func reload() async {
        await cancelAndDrainActiveOperation()
        hasLoaded = true
        await load()
    }

    func toggleSource(_ sourceID: UUID) {
        guard !isBusy else {
            return
        }
        if selectedSourceIDs.contains(sourceID) {
            selectedSourceIDs.remove(sourceID)
        } else {
            selectedSourceIDs.insert(sourceID)
        }
    }

    func clearSourceSelection() {
        guard !isBusy else {
            return
        }
        selectedSourceIDs.removeAll()
    }

    func reconcileAvailableSources(_ availableSourceIDs: Set<UUID>) {
        selectedSourceIDs.formIntersection(availableSourceIDs)
    }

    func generate() {
        guard canRequestGeneration else {
            return
        }
        let operationID = UUID()
        activeOperationID = operationID
        state = .generating
        let generator = generator
        let topic = topic
        let sourceIDs = selectedSourceIDs

        let operation = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let artifact = try await generator.generate(
                    topic: topic,
                    sourceIDs: sourceIDs
                )
                guard isActive(operationID), !Task.isCancelled else {
                    if isActive(operationID) {
                        finish(operationID, state: .cancelled)
                    }
                    return
                }
                state = .finalizing
                try await generator.commitArtifact(artifact)
                guard isActive(operationID) else {
                    return
                }
                artifacts.removeAll { $0.id == artifact.id }
                artifacts.insert(artifact, at: 0)
                finish(operationID, state: .generated(artifact.id))
            } catch is CancellationError {
                guard isActive(operationID) else {
                    return
                }
                finish(operationID, state: .cancelled)
            } catch let failure as GeneratedLearningFailure {
                guard isActive(operationID) else {
                    return
                }
                finish(
                    operationID,
                    state: Self.state(for: failure)
                )
            } catch {
                guard isActive(operationID) else {
                    return
                }
                finish(
                    operationID,
                    state: .failed(.generationFailed)
                )
            }
        }
        activeOperation = operation
    }

    func cancel() {
        guard state == .generating,
              let activeOperation else {
            return
        }
        state = .cancelling
        activeOperation.cancel()
    }

    func checkAvailability() {
        guard activeOperation == nil,
              case .unavailable = state else {
            return
        }
        let operationID = UUID()
        activeOperationID = operationID
        state = .loading
        let generator = generator

        let operation = Task { [weak self] in
            guard let self else {
                return
            }
            let availability = await generator.availability()
            guard isActive(operationID), !Task.isCancelled else {
                return
            }
            switch availability {
            case .available:
                finish(operationID, state: .ready)
            case let .unavailable(reason):
                finish(operationID, state: .unavailable(reason))
            }
        }
        activeOperation = operation
    }

    func deleteArtifacts(referencing sourceID: UUID) async -> Bool {
        await cancelAndDrainActiveOperation()
        do {
            try await generator.deleteArtifacts(referencing: sourceID)
            artifacts.removeAll { $0.references(sourceID: sourceID) }
            switch await generator.availability() {
            case .available:
                state = .ready
            case let .unavailable(reason):
                state = .unavailable(reason)
            }
            return true
        } catch {
            state = .failed(.storageUnavailable)
            return false
        }
    }

    func waitForCurrentOperation() async {
        while let activeOperation {
            await activeOperation.value
        }
    }

    private func load() async {
        guard activeOperation == nil else {
            return
        }
        let operationID = UUID()
        activeOperationID = operationID
        state = .loading
        let generator = generator
        let operation = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let restoredArtifacts = try await generator.restore()
                try Task.checkCancellation()
                let availability = await generator.availability()
                try Task.checkCancellation()
                guard isActive(operationID) else {
                    return
                }
                artifacts = restoredArtifacts
                switch availability {
                case .available:
                    finish(operationID, state: .ready)
                case let .unavailable(reason):
                    finish(
                        operationID,
                        state: .unavailable(reason)
                    )
                }
            } catch is CancellationError {
                guard isActive(operationID) else {
                    return
                }
                finish(operationID, state: .cancelled)
            } catch {
                guard isActive(operationID) else {
                    return
                }
                artifacts = []
                finish(
                    operationID,
                    state: .failed(.storageUnavailable)
                )
            }
        }
        activeOperation = operation
        await operation.value
    }

    private func cancelAndDrainActiveOperation() async {
        guard let operation = activeOperation else {
            activeOperationID = nil
            return
        }
        if state == .finalizing {
            await operation.value
            return
        }
        activeOperationID = nil
        operation.cancel()
        await operation.value
        activeOperation = nil
    }

    private func isActive(_ operationID: UUID) -> Bool {
        activeOperationID == operationID
    }

    private func finish(
        _ operationID: UUID,
        state newState: GeneratedLearningViewState
    ) {
        guard isActive(operationID) else {
            return
        }
        state = newState
        activeOperationID = nil
        activeOperation = nil
    }

    private static func state(
        for failure: GeneratedLearningFailure
    ) -> GeneratedLearningViewState {
        switch failure {
        case .invalidTopic, .topicTooLong:
            .failed(.invalidTopic)
        case .insufficientEvidence:
            .failed(.insufficientEvidence)
        case let .unavailable(reason):
            .unavailable(reason)
        case .sourceUnavailable:
            .failed(.sourceUnavailable)
        case .contextTooLarge:
            .failed(.contextTooLarge)
        case .safetyGuardrail:
            .failed(.safetyGuardrail)
        case let .rejected(categories):
            .rejected(categories)
        case .storageUnavailable:
            .failed(.storageUnavailable)
        case .generationFailed:
            .failed(.generationFailed)
        }
    }
}
