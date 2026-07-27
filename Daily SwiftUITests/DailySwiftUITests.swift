import XCTest

final class DailySwiftUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesWithInitialContent() throws {
        let app = XCUIApplication()

        app.launch()

        XCTAssertTrue(
            app.staticTexts["initial.greeting"].waitForExistence(timeout: 5),
            "The initial greeting should be visible after launch."
        )
    }
}
