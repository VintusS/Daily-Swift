import Foundation
import Testing
@testable import DailySwift

@MainActor
struct AppRootViewModelTests {
    @Test("A new install moves from launch to first run")
    func newInstallStartsFirstRun() async {
        let service = InMemoryAppBootstrapService()
        let viewModel = AppRootViewModel(bootstrapService: service)

        #expect(viewModel.state == .launching)

        viewModel.start()
        #expect(viewModel.state == .restoring)

        await viewModel.waitForCurrentOperation()
        #expect(viewModel.state == .firstRun(.idle))
        #expect(viewModel.router.path.isEmpty)
    }

    @Test("A completed snapshot restores the persistent session and route")
    func completedSnapshotRestores() async {
        let snapshot = AppShellSnapshot(
            hasCompletedFirstRun: true,
            routes: [.privacyAndData]
        )
        let service = InMemoryAppBootstrapService(snapshot: snapshot)
        let viewModel = AppRootViewModel(bootstrapService: service)

        viewModel.start()
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .ready(.persistent))
        #expect(viewModel.router.path == [.privacyAndData])
    }

    @Test("First run is not ready until its snapshot has been persisted")
    func persistencePrecedesReadyState() async {
        let service = GatedSaveAppBootstrapService()
        let viewModel = AppRootViewModel(bootstrapService: service)
        viewModel.start()
        await viewModel.waitForCurrentOperation()

        viewModel.completeFirstRun()
        #expect(viewModel.state == .firstRun(.saving))

        let saveStarted = await waitUntil {
            service.saveRequests.count == 1
        }
        #expect(saveStarted)
        #expect(viewModel.state == .firstRun(.saving))
        #expect(service.savedSnapshots.isEmpty)

        service.resumeSave()
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .ready(.persistent))
        #expect(service.savedSnapshots.count == 1)
        #expect(service.savedSnapshots.first?.hasCompletedFirstRun == true)
    }

    @Test("First run can open a real destination without persisting")
    func firstRunNavigationDoesNotPersist() async {
        let service = InMemoryAppBootstrapService()
        let viewModel = AppRootViewModel(bootstrapService: service)
        viewModel.start()
        await viewModel.waitForCurrentOperation()

        viewModel.navigate(to: .privacyAndData)
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .firstRun(.idle))
        #expect(viewModel.router.path == [.privacyAndData])
        #expect(service.saveRequests.isEmpty)
    }

    @Test("Every restoration failure has a recoverable root state")
    func restorationFailuresAreRecoverable() async {
        let failures: [AppShellFailure] = [
            .storeUnavailable,
            .restorationCorrupt,
            .unsupportedSnapshotVersion,
        ]

        for failure in failures {
            let service = InMemoryAppBootstrapService(
                restoreOutcomes: [.failure(failure)]
            )
            let viewModel = AppRootViewModel(
                bootstrapService: service
            )

            viewModel.start()
            await viewModel.waitForCurrentOperation()

            #expect(
                viewModel.state
                    == .recoverableStorageFailure(failure)
            )
        }
    }

    @Test("Retry repeats a failed restoration")
    func restorationRetrySucceeds() async {
        let snapshot = AppShellSnapshot(
            hasCompletedFirstRun: true,
            routes: [.privacyAndData]
        )
        let service = InMemoryAppBootstrapService(
            restoreOutcomes: [
                .failure(.storeUnavailable),
                .success(snapshot),
            ]
        )
        let viewModel = AppRootViewModel(bootstrapService: service)

        viewModel.start()
        await viewModel.waitForCurrentOperation()
        #expect(
            viewModel.state
                == .recoverableStorageFailure(.storeUnavailable)
        )

        viewModel.retry()
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .ready(.persistent))
        #expect(viewModel.router.path == [.privacyAndData])
        #expect(service.restoreCallCount == 2)
    }

    @Test("A failed first-run save can be retried")
    func firstRunSaveRetrySucceeds() async {
        let service = InMemoryAppBootstrapService(
            saveOutcomes: [
                .failure(.saveFailed),
                .success,
            ]
        )
        let viewModel = AppRootViewModel(bootstrapService: service)
        viewModel.start()
        await viewModel.waitForCurrentOperation()

        viewModel.completeFirstRun()
        await viewModel.waitForCurrentOperation()
        #expect(
            viewModel.state
                == .recoverableStorageFailure(.saveFailed)
        )

        viewModel.retry()
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .ready(.persistent))
        #expect(service.saveRequests.count == 2)
        #expect(service.savedSnapshots.count == 1)
    }

    @Test("Temporary mode remains usable without further persistence")
    func temporaryModeDoesNotPersist() async {
        let service = InMemoryAppBootstrapService(
            restoreOutcomes: [.failure(.storeUnavailable)]
        )
        let viewModel = AppRootViewModel(bootstrapService: service)
        viewModel.start()
        await viewModel.waitForCurrentOperation()

        viewModel.continueTemporarily()
        viewModel.navigate(to: .privacyAndData)
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .ready(.temporary))
        #expect(viewModel.router.path == [.privacyAndData])
        #expect(service.saveRequests.isEmpty)
    }

    @Test("Navigation is included in the persistent shell snapshot")
    func navigationPersists() async {
        let service = InMemoryAppBootstrapService(
            snapshot: AppShellSnapshot(
                hasCompletedFirstRun: true
            )
        )
        let viewModel = AppRootViewModel(bootstrapService: service)
        viewModel.start()
        await viewModel.waitForCurrentOperation()

        viewModel.navigate(to: .privacyAndData)
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.router.path == [.privacyAndData])
        #expect(
            service.savedSnapshots.last?.routes
                == [.privacyAndData]
        )
    }

    @Test("A failed route save keeps the route available for recovery")
    func failedNavigationSavePreservesRoute() async {
        let service = InMemoryAppBootstrapService(
            snapshot: AppShellSnapshot(
                hasCompletedFirstRun: true
            ),
            saveOutcomes: [.failure(.saveFailed)]
        )
        let viewModel = AppRootViewModel(bootstrapService: service)
        viewModel.start()
        await viewModel.waitForCurrentOperation()

        viewModel.navigate(to: .privacyAndData)
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.router.path == [.privacyAndData])
        #expect(
            viewModel.state
                == .recoverableStorageFailure(.saveFailed)
        )

        viewModel.continueTemporarily()

        #expect(viewModel.state == .ready(.temporary))
        #expect(viewModel.router.path == [.privacyAndData])
    }

    @Test("Reset clears durable state, navigation, and first-run progress")
    func resetClearsShellState() async {
        let service = InMemoryAppBootstrapService(
            snapshot: AppShellSnapshot(
                hasCompletedFirstRun: true,
                routes: [.privacyAndData]
            )
        )
        let viewModel = AppRootViewModel(bootstrapService: service)
        viewModel.start()
        await viewModel.waitForCurrentOperation()

        viewModel.reset()
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .firstRun(.idle))
        #expect(viewModel.router.path.isEmpty)
        #expect(service.storedSnapshot == nil)
        #expect(service.resetCallCount == 1)
    }

    @Test("An older start cannot replace a newer restored result")
    func staleStartIsIgnored() async {
        let service = ControllableRestoreAppBootstrapService()
        let viewModel = AppRootViewModel(bootstrapService: service)
        let newestSnapshot = AppShellSnapshot(
            hasCompletedFirstRun: true,
            routes: [.privacyAndData]
        )

        viewModel.start()
        let firstStarted = await waitUntil {
            service.restoreCallCount == 1
        }
        #expect(firstStarted)

        viewModel.start()
        let secondStarted = await waitUntil {
            service.restoreCallCount == 2
        }
        #expect(secondStarted)

        guard firstStarted, secondStarted else {
            service.resumeAll(with: nil)
            return
        }

        service.resumeRestore(2, with: newestSnapshot)
        await viewModel.waitForCurrentOperation()
        #expect(viewModel.state == .ready(.persistent))
        #expect(viewModel.router.path == [.privacyAndData])

        service.resumeRestore(1, with: nil)
        await Task.yield()

        #expect(viewModel.state == .ready(.persistent))
        #expect(viewModel.router.path == [.privacyAndData])
    }

    @Test("An unsupported fake snapshot is rejected defensively")
    func unsupportedFakeSnapshotIsRejected() async {
        let service = InMemoryAppBootstrapService(
            snapshot: AppShellSnapshot(
                schemaVersion:
                    AppShellSnapshot.currentSchemaVersion + 1,
                hasCompletedFirstRun: true
            )
        )
        let viewModel = AppRootViewModel(bootstrapService: service)

        viewModel.start()
        await viewModel.waitForCurrentOperation()

        #expect(
            viewModel.state
                == .recoverableStorageFailure(
                    .unsupportedSnapshotVersion
                )
        )
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        for _ in 0..<1_000 {
            if condition() {
                return true
            }
            await Task.yield()
        }
        return false
    }
}

@MainActor
private final class GatedSaveAppBootstrapService:
    AppBootstrapServing {
    private(set) var saveRequests: [AppShellSnapshot] = []
    private(set) var savedSnapshots: [AppShellSnapshot] = []

    private var saveContinuation:
        CheckedContinuation<Void, any Error>?

    func restore() async throws -> AppShellSnapshot? {
        nil
    }

    func save(_ snapshot: AppShellSnapshot) async throws {
        saveRequests.append(snapshot)

        try await withCheckedThrowingContinuation { continuation in
            saveContinuation = continuation
        }

        savedSnapshots.append(snapshot)
    }

    func reset() async throws {}

    func resumeSave() {
        saveContinuation?.resume()
        saveContinuation = nil
    }
}

@MainActor
private final class ControllableRestoreAppBootstrapService:
    AppBootstrapServing {
    private(set) var restoreCallCount = 0

    private var continuations: [
        Int: CheckedContinuation<AppShellSnapshot?, any Error>
    ] = [:]

    func restore() async throws -> AppShellSnapshot? {
        restoreCallCount += 1
        let requestNumber = restoreCallCount

        return try await withCheckedThrowingContinuation { continuation in
            continuations[requestNumber] = continuation
        }
    }

    func save(_ snapshot: AppShellSnapshot) async throws {}

    func reset() async throws {}

    func resumeRestore(
        _ requestNumber: Int,
        with snapshot: AppShellSnapshot?
    ) {
        continuations.removeValue(forKey: requestNumber)?.resume(
            returning: snapshot
        )
    }

    func resumeAll(with snapshot: AppShellSnapshot?) {
        let pendingContinuations = continuations.values
        continuations.removeAll()
        for continuation in pendingContinuations {
            continuation.resume(returning: snapshot)
        }
    }
}
