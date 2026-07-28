import XCTest

final class DailySwiftUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDeterministicGenerationFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--open-structured-generation-spike",
        ]

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

    @MainActor
    func testFirstRunCompletesAndOpensPrivacy() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=first-run",
        ]

        app.launch()

        XCTAssertTrue(
            app.staticTexts["app-shell.first-run"]
                .waitForExistence(timeout: 5),
            "The first-run experience should be visible."
        )

        app.buttons["app-shell.continue"].tap()

        XCTAssertTrue(
            app.staticTexts["app-shell.ready"]
                .waitForExistence(timeout: 5),
            "Completing first run should reveal the ready studio."
        )

        app.buttons["app-shell.privacy"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["privacy-and-data.screen"]
                .waitForExistence(timeout: 5),
            "Privacy & Data should be reachable from the ready studio."
        )
    }

    @MainActor
    func testRestoredNavigationReturnsToPrivacy() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=restored-privacy",
        ]

        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["privacy-and-data.screen"]
                .waitForExistence(timeout: 5),
            "A valid restored route should return to Privacy & Data."
        )
    }

    @MainActor
    func testSavedRouteRestoresAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--reset-ui-testing-app-shell",
        ]

        app.launch()

        XCTAssertTrue(
            app.staticTexts["app-shell.first-run"]
                .waitForExistence(timeout: 5),
            "An isolated persistent store should begin at first run."
        )

        app.buttons["app-shell.continue"].tap()

        XCTAssertTrue(
            app.staticTexts["app-shell.ready"]
                .waitForExistence(timeout: 5),
            "First-run completion should be saved before ready appears."
        )

        app.buttons["app-shell.privacy"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["privacy-and-data.screen"]
                .waitForExistence(timeout: 5),
            "The production route should open before relaunch."
        )

        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["privacy-and-data.screen"]
                .waitForExistence(timeout: 5),
            "The live test store should restore the last production route."
        )
    }

    @MainActor
    func testRouteSaveFailurePresentsRecoveryAboveDestination() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready-save-failed",
        ]

        app.launch()

        XCTAssertTrue(
            app.staticTexts["app-shell.ready"]
                .waitForExistence(timeout: 5),
            "The seeded persistent shell should be ready."
        )

        app.buttons["app-shell.privacy"].tap()

        XCTAssertTrue(
            app.staticTexts["app-shell.failure"]
                .waitForExistence(timeout: 5),
            "A route save failure should cover the active destination."
        )

        app.buttons["app-shell.continue-temporarily"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["privacy-and-data.screen"]
                .waitForExistence(timeout: 5),
            "Temporary recovery should preserve the selected route."
        )
    }

    @MainActor
    func testRecoverableFailureCanRetry() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=store-unavailable",
        ]

        app.launch()

        XCTAssertTrue(
            app.staticTexts["app-shell.failure"]
                .waitForExistence(timeout: 5),
            "A storage failure should present recovery actions."
        )

        app.buttons["app-shell.retry"].tap()

        XCTAssertTrue(
            app.staticTexts["app-shell.first-run"]
                .waitForExistence(timeout: 5),
            "Retry should recover when storage becomes available."
        )
    }
}
