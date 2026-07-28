import Foundation

@MainActor
protocol AppBootstrapServing: AnyObject {
    func restore() async throws -> AppShellSnapshot?
    func save(_ snapshot: AppShellSnapshot) async throws
    func reset() async throws
}

@MainActor
final class UserDefaultsAppBootstrapService: AppBootstrapServing {
    static let defaultSnapshotKey = "app-shell.snapshot"

    private let defaults: UserDefaults
    private let snapshotKey: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        defaults: UserDefaults = .standard,
        snapshotKey: String = defaultSnapshotKey
    ) {
        self.defaults = defaults
        self.snapshotKey = snapshotKey
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func restore() async throws -> AppShellSnapshot? {
        guard let storedValue = defaults.object(forKey: snapshotKey) else {
            return nil
        }
        guard let data = storedValue as? Data else {
            throw AppShellFailure.restorationCorrupt
        }

        let version: SnapshotVersionEnvelope
        do {
            version = try decoder.decode(
                SnapshotVersionEnvelope.self,
                from: data
            )
        } catch {
            throw AppShellFailure.restorationCorrupt
        }

        guard version.schemaVersion == AppShellSnapshot.currentSchemaVersion else {
            throw AppShellFailure.unsupportedSnapshotVersion
        }

        do {
            return try decoder.decode(AppShellSnapshot.self, from: data)
        } catch {
            throw AppShellFailure.restorationCorrupt
        }
    }

    func save(_ snapshot: AppShellSnapshot) async throws {
        guard snapshot.schemaVersion == AppShellSnapshot.currentSchemaVersion else {
            throw AppShellFailure.unsupportedSnapshotVersion
        }

        let data: Data
        do {
            data = try encoder.encode(snapshot)
        } catch {
            throw AppShellFailure.saveFailed
        }

        defaults.set(data, forKey: snapshotKey)
        guard defaults.data(forKey: snapshotKey) == data else {
            throw AppShellFailure.saveFailed
        }
    }

    func reset() async throws {
        defaults.removeObject(forKey: snapshotKey)
        guard defaults.object(forKey: snapshotKey) == nil else {
            throw AppShellFailure.storeUnavailable
        }
    }
}

private struct SnapshotVersionEnvelope: Decodable {
    let schemaVersion: Int
}

enum InMemoryAppBootstrapRestoreOutcome: Equatable, Sendable {
    case success(AppShellSnapshot?)
    case failure(AppShellFailure)
}

enum InMemoryAppBootstrapMutationOutcome: Equatable, Sendable {
    case success
    case failure(AppShellFailure)
}

@MainActor
final class InMemoryAppBootstrapService: AppBootstrapServing {
    private(set) var storedSnapshot: AppShellSnapshot?
    private(set) var restoreCallCount = 0
    private(set) var saveRequests: [AppShellSnapshot] = []
    private(set) var savedSnapshots: [AppShellSnapshot] = []
    private(set) var resetCallCount = 0

    private var restoreOutcomes: [InMemoryAppBootstrapRestoreOutcome]
    private var saveOutcomes: [InMemoryAppBootstrapMutationOutcome]
    private var resetOutcomes: [InMemoryAppBootstrapMutationOutcome]

    init(
        snapshot: AppShellSnapshot? = nil,
        restoreOutcomes: [InMemoryAppBootstrapRestoreOutcome] = [],
        saveOutcomes: [InMemoryAppBootstrapMutationOutcome] = [],
        resetOutcomes: [InMemoryAppBootstrapMutationOutcome] = []
    ) {
        storedSnapshot = snapshot
        self.restoreOutcomes = restoreOutcomes
        self.saveOutcomes = saveOutcomes
        self.resetOutcomes = resetOutcomes
    }

    func restore() async throws -> AppShellSnapshot? {
        restoreCallCount += 1

        guard !restoreOutcomes.isEmpty else {
            return storedSnapshot
        }

        switch restoreOutcomes.removeFirst() {
        case let .success(snapshot):
            return snapshot
        case let .failure(failure):
            throw failure
        }
    }

    func save(_ snapshot: AppShellSnapshot) async throws {
        saveRequests.append(snapshot)

        if !saveOutcomes.isEmpty {
            switch saveOutcomes.removeFirst() {
            case .success:
                break
            case let .failure(failure):
                throw failure
            }
        }

        storedSnapshot = snapshot
        savedSnapshots.append(snapshot)
    }

    func reset() async throws {
        resetCallCount += 1

        if !resetOutcomes.isEmpty {
            switch resetOutcomes.removeFirst() {
            case .success:
                break
            case let .failure(failure):
                throw failure
            }
        }

        storedSnapshot = nil
    }
}
