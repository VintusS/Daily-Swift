import Testing
@testable import DailySwift

@MainActor
struct DailySwiftSmokeTests {
    @Test("The initial view can be constructed")
    func initialViewCanBeConstructed() {
        let environment = AppEnvironment(
            bootstrapService: InMemoryAppBootstrapService()
        )

        _ = ContentView(environment: environment)
    }
}
