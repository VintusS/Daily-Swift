import Foundation

struct AppShellSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let hasCompletedFirstRun: Bool
    let routes: [AppRoute]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        hasCompletedFirstRun: Bool,
        routes: [AppRoute] = []
    ) {
        self.schemaVersion = schemaVersion
        self.hasCompletedFirstRun = hasCompletedFirstRun
        self.routes = routes
    }
}
