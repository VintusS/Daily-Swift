import Foundation
import Testing
@testable import DailySwift

@MainActor
struct AppRouteAndSnapshotTests {
    @Test("Every app route survives a Codable round trip")
    func routeRoundTrip() throws {
        let route = AppRoute.privacyAndData

        let data = try JSONEncoder().encode(route)
        let decodedRoute = try JSONDecoder().decode(
            AppRoute.self,
            from: data
        )

        #expect(decodedRoute == route)
    }

    @Test("A shell snapshot survives a Codable round trip")
    func snapshotRoundTrip() throws {
        let snapshot = AppShellSnapshot(
            hasCompletedFirstRun: true,
            routes: [.privacyAndData]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decodedSnapshot = try JSONDecoder().decode(
            AppShellSnapshot.self,
            from: data
        )

        #expect(decodedSnapshot == snapshot)
        #expect(
            decodedSnapshot.schemaVersion
                == AppShellSnapshot.currentSchemaVersion
        )
    }

    @Test("The production store saves, restores, and resets shell state")
    func userDefaultsStoreLifecycle() async throws {
        let fixture = makeDefaultsFixture()
        defer {
            fixture.defaults.removePersistentDomain(
                forName: fixture.suiteName
            )
        }
        let service = UserDefaultsAppBootstrapService(
            defaults: fixture.defaults
        )
        let snapshot = AppShellSnapshot(
            hasCompletedFirstRun: true,
            routes: [.privacyAndData]
        )

        #expect(try await service.restore() == nil)

        try await service.save(snapshot)
        #expect(try await service.restore() == snapshot)

        try await service.reset()
        #expect(try await service.restore() == nil)
    }

    @Test("Malformed persisted state is reported as corrupt")
    func corruptSnapshotIsReported() async {
        let fixture = makeDefaultsFixture()
        defer {
            fixture.defaults.removePersistentDomain(
                forName: fixture.suiteName
            )
        }
        fixture.defaults.set(
            Data("not-json".utf8),
            forKey: UserDefaultsAppBootstrapService.defaultSnapshotKey
        )
        let service = UserDefaultsAppBootstrapService(
            defaults: fixture.defaults
        )

        await #expect(throws: AppShellFailure.restorationCorrupt) {
            try await service.restore()
        }
    }

    @Test("A newer persisted schema is not decoded as current state")
    func unsupportedSnapshotVersionIsReported() async throws {
        let fixture = makeDefaultsFixture()
        defer {
            fixture.defaults.removePersistentDomain(
                forName: fixture.suiteName
            )
        }
        let unsupportedSnapshot = AppShellSnapshot(
            schemaVersion: AppShellSnapshot.currentSchemaVersion + 1,
            hasCompletedFirstRun: true,
            routes: []
        )
        let data = try JSONEncoder().encode(unsupportedSnapshot)
        fixture.defaults.set(
            data,
            forKey: UserDefaultsAppBootstrapService.defaultSnapshotKey
        )
        let service = UserDefaultsAppBootstrapService(
            defaults: fixture.defaults
        )

        await #expect(
            throws: AppShellFailure.unsupportedSnapshotVersion
        ) {
            try await service.restore()
        }
    }

    @Test("Launch configuration parses UI and spike controls")
    func launchConfigurationParsing() {
        let configuration = AppLaunchConfiguration(
            arguments: [
                "DailySwift",
                "--ui-testing",
                "--reset-ui-testing-app-shell",
                "--reset-ui-testing-learning-progress",
                "--app-shell-scenario=restoration-corrupt",
                "--learning-studio-scenario=write-retry",
                "--open-structured-generation-spike",
            ]
        )

        #expect(configuration.isUITestingEnabled)
        #expect(configuration.isStructuredGenerationSpikeEnabled)
        #expect(configuration.shouldResetUITestingShell)
        #expect(configuration.shouldResetUITestingLearning)
        #expect(configuration.shellScenario == .restorationCorrupt)
        #expect(configuration.learningScenario == .writeRetry)
    }

    @Test("UI testing defaults to isolated in-memory learning progress")
    func uiTestingLearningDefault() {
        let configuration = AppLaunchConfiguration(
            arguments: ["DailySwift", "--ui-testing"]
        )

        #expect(configuration.learningScenario == .empty)
        #expect(!configuration.shouldResetUITestingLearning)
    }

    private func makeDefaultsFixture() -> (
        defaults: UserDefaults,
        suiteName: String
    ) {
        let suiteName = "DailySwiftTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
