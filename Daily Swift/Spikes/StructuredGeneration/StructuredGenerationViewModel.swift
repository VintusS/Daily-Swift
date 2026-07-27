#if DEBUG
import Foundation
import Observation

enum StructuredGenerationViewState: Equatable, Sendable {
    case idle
    case checkingAvailability
    case ready
    case unavailable(StructuredGenerationUnavailability)
    case generating
    case content(StructuredGenerationArtifact)
    case rejected(StructuredGenerationValidationError)
    case failed(StructuredGenerationClientFailure)
    case cancelled
}

@MainActor
@Observable
final class StructuredGenerationViewModel {
    private(set) var state: StructuredGenerationViewState = .idle

    let request: StructuredGenerationRequest

    private let client: any StructuredGenerationClient
    private let validator: StructuredGenerationValidator

    @ObservationIgnored
    private var activeOperation: Task<Void, Never>?

    @ObservationIgnored
    private var activeOperationID: UUID?

    init(
        request: StructuredGenerationRequest,
        client: any StructuredGenerationClient,
        validator: StructuredGenerationValidator = StructuredGenerationValidator()
    ) {
        self.request = request
        self.client = client
        self.validator = validator
    }

    func checkAvailability() {
        replaceActiveOperation()

        let operationID = UUID()
        activeOperationID = operationID
        state = .checkingAvailability

        activeOperation = Task { [weak self] in
            guard let self else {
                return
            }

            let availability = await client.availability()
            guard !Task.isCancelled else {
                finishCancelledOperation(operationID)
                return
            }

            switch availability {
            case .available:
                finishOperation(operationID, with: .ready)
            case let .unavailable(reason):
                finishOperation(operationID, with: .unavailable(reason))
            }
        }
    }

    func generate() {
        replaceActiveOperation()

        let operationID = UUID()
        activeOperationID = operationID
        state = .checkingAvailability

        activeOperation = Task { [weak self] in
            guard let self else {
                return
            }

            let availability = await client.availability()
            guard !Task.isCancelled else {
                finishCancelledOperation(operationID)
                return
            }
            guard isActive(operationID) else {
                return
            }

            switch availability {
            case let .unavailable(reason):
                finishOperation(operationID, with: .unavailable(reason))
                return
            case .available:
                do {
                    try validator.validate(request)
                    state = .generating
                } catch let validationError as StructuredGenerationValidationError {
                    finishOperation(
                        operationID,
                        with: .rejected(validationError)
                    )
                    return
                } catch {
                    finishOperation(operationID, with: .failed(.unknown))
                    return
                }
            }

            do {
                let artifact = try await client.generate(request)
                try Task.checkCancellation()
                guard isActive(operationID) else {
                    return
                }

                do {
                    let validatedArtifact = try validator.validate(
                        artifact,
                        for: request
                    )
                    finishOperation(
                        operationID,
                        with: .content(validatedArtifact)
                    )
                } catch let validationError as StructuredGenerationValidationError {
                    finishOperation(
                        operationID,
                        with: .rejected(validationError)
                    )
                }
            } catch is CancellationError {
                finishCancelledOperation(operationID)
            } catch let failure as StructuredGenerationClientFailure {
                finishOperation(operationID, with: .failed(failure))
            } catch {
                finishOperation(operationID, with: .failed(.unknown))
            }
        }
    }

    func cancel() {
        guard let activeOperation else {
            return
        }

        activeOperationID = nil
        self.activeOperation = nil
        activeOperation.cancel()
        state = .cancelled
    }

    func waitForCurrentOperation() async {
        let operation = activeOperation
        await operation?.value
    }

    private func replaceActiveOperation() {
        activeOperation?.cancel()
        activeOperation = nil
        activeOperationID = nil
    }

    private func isActive(_ operationID: UUID) -> Bool {
        activeOperationID == operationID
    }

    private func finishCancelledOperation(_ operationID: UUID) {
        finishOperation(operationID, with: .cancelled)
    }

    private func finishOperation(
        _ operationID: UUID,
        with newState: StructuredGenerationViewState
    ) {
        guard isActive(operationID) else {
            return
        }

        state = newState
        activeOperationID = nil
        activeOperation = nil
    }
}
#endif
