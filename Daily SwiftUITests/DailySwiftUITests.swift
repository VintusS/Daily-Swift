import XCTest

final class DailySwiftUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDeterministicGenerationFlow() throws {
        let app = XCUIApplication()

        app.launch()

        XCTAssertTrue(
            app.navigationBars["Generation spike"].waitForExistence(timeout: 5),
            "The debug generation spike should be visible after launch."
        )

        let generateButton = app.buttons["structured-generation.generate"]
        XCTAssertTrue(
            generateButton.waitForExistence(timeout: 5),
            "The deterministic fixture should become ready."
        )

        generateButton.tap()

        XCTAssertTrue(
            app.otherElements["structured-generation.lesson"].waitForExistence(timeout: 5),
            "A validated deterministic lesson should be presented."
        )
        XCTAssertTrue(
            app.otherElements["structured-generation.exercise"].waitForExistence(timeout: 5),
            "A validated deterministic exercise should be presented."
        )
    }
}
