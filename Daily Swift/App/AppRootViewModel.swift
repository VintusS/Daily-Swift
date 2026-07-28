import Foundation
import Observation

@MainActor
@Observable
final class AppRootViewModel {
    private(set) var state: AppRootState = .launching

    let router: AppRouter

    private let bootstrapService: any AppBootstrapServing

    @ObservationIgnored
    private var activeOperation: Task<Void, Never>?

    @ObservationIgnored
    private var activeOperationID: UUID?

    @ObservationIgnored
    private var recoveryAction: RecoveryAction = .start

    init(
        bootstrapService: any AppBootstrapServing,
        router: AppRouter = AppRouter()
    ) {
        self.bootstrapService = bootstrapService
        self.router = router
    }

    func start() {
        replaceActiveOperation()

        let operationID = UUID()
        activeOperationID = operationID
        state = .restoring

        activeOperation = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let snapshot = try await bootstrapService.restore()
                guard isActive(operationID) else {
                    return
                }

                restore(snapshot, operationID: operationID)
            } catch let failure as AppShellFailure {
                finishOperation(
                    operationID,
                    with: .recoverableStorageFailure(failure),
                    recoveryAction: .start
                )
            } catch {
                finishOperation(
                    operationID,
                    with: .recoverableStorageFailure(.storeUnavailable),
                    recoveryAction: .start
                )
            }
        }
    }

    func completeFirstRun() {
        guard state == .firstRun(.idle) else {
            return
        }

        replaceActiveOperation()

        let operationID = UUID()
        let snapshot = AppShellSnapshot(
            hasCompletedFirstRun: true,
            routes: router.path
        )
        activeOperationID = operationID
        state = .firstRun(.saving)

        activeOperation = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await bootstrapService.save(snapshot)
                finishOperation(
                    operationID,
                    with: .ready(.persistent),
                    recoveryAction: .start
                )
            } catch let failure as AppShellFailure {
                finishOperation(
                    operationID,
                    with: .recoverableStorageFailure(failure),
                    recoveryAction: .completeFirstRun
                )
            } catch {
                finishOperation(
                    operationID,
                    with: .recoverableStorageFailure(.saveFailed),
                    recoveryAction: .completeFirstRun
                )
            }
        }
    }

    func retry() {
        switch recoveryAction {
        case .start:
            start()
        case .completeFirstRun:
            state = .firstRun(.idle)
            completeFirstRun()
        case .persist:
            state = .ready(.persistent)
            persist()
        case .reset:
            reset()
        }
    }

    func continueTemporarily() {
        replaceActiveOperation()
        recoveryAction = .start
        state = .ready(.temporary)
    }

    func reset() {
        replaceActiveOperation()

        let operationID = UUID()
        activeOperationID = operationID
        state = .restoring

        activeOperation = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await bootstrapService.reset()
                guard isActive(operationID) else {
                    return
                }

                router.reset()
                finishOperation(
                    operationID,
                    with: .firstRun(.idle),
                    recoveryAction: .start
                )
            } catch let failure as AppShellFailure {
                finishOperation(
                    operationID,
                    with: .recoverableStorageFailure(failure),
                    recoveryAction: .reset
                )
            } catch {
                finishOperation(
                    operationID,
                    with: .recoverableStorageFailure(.storeUnavailable),
                    recoveryAction: .reset
                )
            }
        }
    }

    func navigate(to route: AppRoute) {
        switch state {
        case .firstRun:
            router.navigate(to: route)
        case .ready(.persistent):
            router.navigate(to: route)
            persist()
        case .ready(.temporary):
            router.navigate(to: route)
        case .launching, .restoring, .recoverableStorageFailure:
            return
        }
    }

    func replaceNavigationPath(with routes: [AppRoute]) {
        switch state {
        case .firstRun:
            router.replacePath(with: routes)
        case .ready(.persistent):
            router.replacePath(with: routes)
            persist()
        case .ready(.temporary):
            router.replacePath(with: routes)
        case .launching, .restoring, .recoverableStorageFailure:
            return
        }
    }

    func persist() {
        guard state == .ready(.persistent) else {
            return
        }

        replaceActiveOperation()

        let operationID = UUID()
        let snapshot = AppShellSnapshot(
            hasCompletedFirstRun: true,
            routes: router.path
        )
        activeOperationID = operationID

        activeOperation = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await bootstrapService.save(snapshot)
                finishOperation(
                    operationID,
                    with: .ready(.persistent),
                    recoveryAction: .start
                )
            } catch let failure as AppShellFailure {
                finishOperation(
                    operationID,
                    with: .recoverableStorageFailure(failure),
                    recoveryAction: .persist
                )
            } catch {
                finishOperation(
                    operationID,
                    with: .recoverableStorageFailure(.saveFailed),
                    recoveryAction: .persist
                )
            }
        }
    }

    func waitForCurrentOperation() async {
        let operation = activeOperation
        await operation?.value
    }

    private func restore(
        _ snapshot: AppShellSnapshot?,
        operationID: UUID
    ) {
        guard let snapshot else {
            router.reset()
            finishOperation(
                operationID,
                with: .firstRun(.idle),
                recoveryAction: .start
            )
            return
        }
        guard snapshot.schemaVersion == AppShellSnapshot.currentSchemaVersion else {
            finishOperation(
                operationID,
                with: .recoverableStorageFailure(
                    .unsupportedSnapshotVersion
                ),
                recoveryAction: .start
            )
            return
        }

        if snapshot.hasCompletedFirstRun {
            router.replacePath(with: snapshot.routes)
            finishOperation(
                operationID,
                with: .ready(.persistent),
                recoveryAction: .start
            )
        } else {
            router.reset()
            finishOperation(
                operationID,
                with: .firstRun(.idle),
                recoveryAction: .start
            )
        }
    }

    private func replaceActiveOperation() {
        activeOperationID = nil
        let operation = activeOperation
        activeOperation = nil
        operation?.cancel()
    }

    private func isActive(_ operationID: UUID) -> Bool {
        activeOperationID == operationID
    }

    private func finishOperation(
        _ operationID: UUID,
        with newState: AppRootState,
        recoveryAction: RecoveryAction
    ) {
        guard isActive(operationID) else {
            return
        }

        state = newState
        self.recoveryAction = recoveryAction
        activeOperationID = nil
        activeOperation = nil
    }
}

private enum RecoveryAction {
    case start
    case completeFirstRun
    case persist
    case reset
}
