import Testing
@testable import DailySwift

@MainActor
struct DailySwiftSmokeTests {
    @Test("The initial view can be constructed")
    func initialViewCanBeConstructed() {
        _ = ContentView()
    }
}
