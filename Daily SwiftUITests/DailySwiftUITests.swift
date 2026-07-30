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

    @MainActor
    func testNativeTabsSupportChallengeArticleAndProgressFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=empty",
        ]

        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(
            tabBar.waitForExistence(timeout: 5),
            "The functional studio should use a native tab bar."
        )
        XCTAssertTrue(tabBar.buttons["Today"].exists)
        XCTAssertTrue(tabBar.buttons["Challenges"].exists)
        XCTAssertTrue(tabBar.buttons["Library"].exists)
        XCTAssertTrue(tabBar.buttons["Progress"].exists)

        tabBar.buttons["Challenges"].tap()
        XCTAssertTrue(
            app.navigationBars["Challenges"].waitForExistence(timeout: 5)
        )

        app.buttons["challenges.open.swift.value-copy-output"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["challenge.player"]
                .waitForExistence(timeout: 5)
        )
        app.buttons["challenge.choice.zero-one"].tap()
        app.buttons["challenge.submit"].tap()
        assertAttemptSaved(
            app.descendants(matching: .any)[
                "challenge.feedback.correct"
            ]
        )

        tabBar.buttons["Library"].tap()
        XCTAssertTrue(
            app.navigationBars["Library"].waitForExistence(timeout: 5)
        )
        app.buttons["library.open.swift.value-semantics"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["article.reader"]
                .waitForExistence(timeout: 5)
        )
        app.buttons["article.bookmark"].tap()
        let markReadButton = app.buttons["article.mark-read"]
        XCTAssertTrue(markReadButton.waitForExistence(timeout: 5))
        expectation(
            for: NSPredicate(format: "isEnabled == true"),
            evaluatedWith: markReadButton
        )
        waitForExpectations(timeout: 5)
        markReadButton.tap()
        expectation(
            for: NSPredicate(format: "label == 'Article read'"),
            evaluatedWith: markReadButton
        )
        waitForExpectations(timeout: 5)

        tabBar.buttons["Progress"].tap()
        XCTAssertTrue(
            app.navigationBars["Progress"].waitForExistence(timeout: 5)
        )
        let correctAnswers = app.descendants(matching: .any)[
            "progress.correct-answers"
        ]
        let articlesRead = app.descendants(matching: .any)[
            "progress.articles-read"
        ]
        XCTAssertTrue(correctAnswers.waitForExistence(timeout: 5))
        XCTAssertTrue(articlesRead.waitForExistence(timeout: 5))
        XCTAssertEqual(correctAnswers.value as? String, "1")
        XCTAssertEqual(articlesRead.value as? String, "1")
    }

    @MainActor
    func testLearningEvidenceAndSelectedTabRestoreAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=live",
            "--reset-ui-testing-learning-progress",
        ]

        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Challenges"].tap()
        app.buttons["challenges.open.swift.value-copy-output"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["challenge.player"]
                .waitForExistence(timeout: 5)
        )
        app.buttons["challenge.choice.zero-one"].tap()
        app.buttons["challenge.submit"].tap()
        assertAttemptSaved(
            app.descendants(matching: .any)[
                "challenge.feedback.correct"
            ]
        )

        app.terminate()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=live",
        ]
        app.launch()

        XCTAssertTrue(
            app.navigationBars["Challenges"].waitForExistence(timeout: 5),
            "The selected native tab should restore without restoring a stale detail path."
        )
        app.tabBars.buttons["Progress"].tap()

        let correctAnswers = app.descendants(matching: .any)[
            "progress.correct-answers"
        ]
        XCTAssertTrue(correctAnswers.waitForExistence(timeout: 5))
        XCTAssertEqual(
            correctAnswers.value as? String,
            "1",
            "Saved challenge evidence should survive termination."
        )
    }

    @MainActor
    func testLearningStoreRestoreFailureCanRetry() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=restore-retry",
        ]

        app.launch()

        XCTAssertTrue(
            app.staticTexts["learning-studio.failure"]
                .waitForExistence(timeout: 5)
        )
        app.buttons["learning-studio.retry"].tap()

        XCTAssertTrue(
            app.navigationBars["Today"].waitForExistence(timeout: 5),
            "A deterministic retry should restore the functional studio."
        )
    }

    @MainActor
    func testChallengeSaveFailureCanRetryWithoutLosingFeedback() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=write-retry",
        ]

        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        tabBar.buttons["Challenges"].tap()
        app.buttons["challenges.open.swift.value-copy-output"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["challenge.player"]
                .waitForExistence(timeout: 5)
        )
        app.buttons["challenge.choice.zero-one"].tap()
        app.buttons["challenge.submit"].tap()

        XCTAssertTrue(
            app.buttons["challenge.retry-save"]
                .waitForExistence(timeout: 5),
            "Correctness should remain visible when saving fails."
        )
        app.buttons["challenge.retry-save"].tap()

        assertAttemptSaved(
            app.descendants(matching: .any)[
                "challenge.feedback.correct"
            ]
        )
        XCTAssertFalse(
            app.buttons["challenge.retry-save"].exists,
            "A successful idempotent retry should clear the unsaved state."
        )
    }

    @MainActor
    func testLearningStoreFailureCanContinueTemporarily() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=restore-retry",
        ]

        app.launch()

        XCTAssertTrue(
            app.staticTexts["learning-studio.failure"]
                .waitForExistence(timeout: 5)
        )
        app.buttons["learning-studio.continue-temporarily"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[
                "learning-studio.temporary"
            ]
            .waitForExistence(timeout: 5),
            "Temporary mode must be explicit before the learner continues."
        )
        XCTAssertTrue(app.tabBars.firstMatch.exists)

        app.tabBars.buttons["Challenges"].tap()
        app.buttons["challenges.open.swift.value-copy-output"].tap()
        app.buttons["challenge.choice.zero-one"].tap()
        app.buttons["challenge.submit"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "challenge.feedback.temporary-storage"
            ]
            .waitForExistence(timeout: 5)
        )

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(
            app.staticTexts["TEMPORARY SESSION EVIDENCE"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(
            app.staticTexts["SAVED LEARNING EVIDENCE"].exists
        )

        app.buttons["progress.preferences"].tap()
        XCTAssertTrue(
            app.buttons["Clear temporary session"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.buttons["Reset learning progress"].exists)
    }

    @MainActor
    func testLibrarySearchAndBookmarksEmptyStates() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=empty",
        ]

        app.launch()
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(
            app.navigationBars["Library"].waitForExistence(timeout: 5)
        )

        let bookmarkFilter = app.buttons["library.bookmarks-filter"]
        XCTAssertTrue(bookmarkFilter.waitForExistence(timeout: 5))
        bookmarkFilter.tap()
        XCTAssertTrue(
            app.staticTexts["No bookmarked articles"]
                .waitForExistence(timeout: 5)
        )

        bookmarkFilter.tap()
        let searchField = app.searchFields[
            "Search articles and passages"
        ]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("topic-that-does-not-exist")

        XCTAssertTrue(
            app.staticTexts["No matching articles"]
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testImportedPassageSearchOpensExactCitation() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=empty",
            "--source-library-scenario=seeded",
        ]

        app.launch()
        app.tabBars.buttons["Library"].tap()

        let searchField = app.searchFields[
            "Search articles and passages"
        ]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("actor isolation")

        let keyboardSearch = app.keyboards.buttons["Search"]
        XCTAssertTrue(keyboardSearch.waitForExistence(timeout: 5))
        keyboardSearch.tap()

        let result = app.buttons["source-retrieval.result.0"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "source-retrieval.offline"
            ]
            .exists
        )
        result.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["citation.reader"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.staticTexts["Exact stored passage"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Verified offline"].exists)
    }

    @MainActor
    func testImportedPDFPassageSearchOpensExactPageCitation() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=empty",
            "--source-library-scenario=seeded-pdf",
        ]

        app.launch()
        app.tabBars.buttons["Library"].tap()

        let searchField = app.searchFields[
            "Search articles and passages"
        ]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("page provenance")

        let keyboardSearch = app.keyboards.buttons["Search"]
        XCTAssertTrue(keyboardSearch.waitForExistence(timeout: 5))
        keyboardSearch.tap()

        let result = app.buttons["source-retrieval.result.0"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["citation.reader"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.staticTexts["Page 1"].waitForExistence(timeout: 5)
        )

        let openPageButton = app.buttons["citation.open-pdf-page"]
        XCTAssertTrue(openPageButton.waitForExistence(timeout: 5))
        openPageButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["citation.pdf-page"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.navigationBars["Original PDF · Page 1"]
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testImportedSourceOpensExactCitationAndDeletes() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=empty",
            "--source-library-scenario=seeded",
        ]

        app.launch()
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(
            app.navigationBars["Library"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.buttons["source-library.import"]
                .waitForExistence(timeout: 5),
            "The native source-import action should be available."
        )

        let sourceRow = app.buttons[
            "source.open.44444444-4444-4444-4444-444444444444"
        ]
        XCTAssertTrue(sourceRow.waitForExistence(timeout: 5))
        sourceRow.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["source.detail"]
                .waitForExistence(timeout: 5)
        )
        let detailScreenshot = XCTAttachment(
            screenshot: app.screenshot()
        )
        detailScreenshot.name = "Imported source detail"
        detailScreenshot.lifetime = .keepAlways
        add(detailScreenshot)
        app.buttons["source.open-citation.0"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["citation.reader"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.staticTexts["Exact stored passage"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Verified offline"].exists)
        let citationScreenshot = XCTAttachment(
            screenshot: app.screenshot()
        )
        citationScreenshot.name = "Exact offline citation"
        citationScreenshot.lifetime = .keepAlways
        add(citationScreenshot)

        app.navigationBars.buttons["Source"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["source.detail"]
                .waitForExistence(timeout: 5)
        )
        let deleteButton = app.buttons["source.delete"]
        for _ in 0..<3 where !deleteButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(deleteButton.isHittable)
        deleteButton.tap()
        app.buttons["source.confirm-delete"].firstMatch.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["source-library.empty"]
                .waitForExistence(timeout: 5),
            "Cascading deletion should return to the empty imported-source library."
        )
    }

    @MainActor
    func testImportedPDFOpensExactPageOffline() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=empty",
            "--source-library-scenario=seeded-pdf",
        ]

        app.launch()
        app.tabBars.buttons["Library"].tap()

        let sourceRow = app.buttons[
            "source.open.45454545-4545-4545-4545-454545454545"
        ]
        XCTAssertTrue(sourceRow.waitForExistence(timeout: 5))
        sourceRow.tap()

        let citationButton = app.buttons["source.open-citation.0"]
        XCTAssertTrue(citationButton.waitForExistence(timeout: 5))
        citationButton.tap()

        XCTAssertTrue(
            app.staticTexts["Page 1"].waitForExistence(timeout: 5)
        )
        let openPageButton = app.buttons["citation.open-pdf-page"]
        XCTAssertTrue(openPageButton.waitForExistence(timeout: 5))

        let citationScreenshot = XCTAttachment(
            screenshot: app.screenshot()
        )
        citationScreenshot.name = "Exact PDF citation with page provenance"
        citationScreenshot.lifetime = .keepAlways
        add(citationScreenshot)

        openPageButton.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["citation.pdf-page"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.navigationBars["Original PDF · Page 1"]
                .waitForExistence(timeout: 5)
        )

        let pageScreenshot = XCTAttachment(
            screenshot: app.screenshot()
        )
        pageScreenshot.name = "Locally stored original PDF page"
        pageScreenshot.lifetime = .keepAlways
        add(pageScreenshot)
    }

    @MainActor
    func testImportedPDFReflowsInDarkAccessibilityText() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=empty",
            "--source-library-scenario=seeded-pdf",
            "-AppleInterfaceStyle",
            "Dark",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
            "-UIAccessibilityDarkerSystemColorsEnabled",
            "YES",
            "-UIAccessibilityReduceMotionEnabled",
            "YES",
        ]

        app.launch()
        app.tabBars.buttons["Library"].tap()
        let sourceRow = app.buttons[
            "source.open.45454545-4545-4545-4545-454545454545"
        ]
        for _ in 0..<6 where !sourceRow.exists {
            app.swipeUp()
        }
        XCTAssertTrue(sourceRow.waitForExistence(timeout: 5))
        sourceRow.tap()

        let citationButton = app.buttons["source.open-citation.0"]
        for _ in 0..<4 where !citationButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(citationButton.waitForExistence(timeout: 5))
        citationButton.tap()

        XCTAssertTrue(
            app.staticTexts["Page 1"].waitForExistence(timeout: 5)
        )
        let openPageButton = app.buttons["citation.open-pdf-page"]
        for _ in 0..<4 where !openPageButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(openPageButton.isHittable)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name =
            "PDF citation dark increased contrast accessibility XXXL"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testSourceLibraryRestoreFailureCanRetry() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=empty",
            "--source-library-scenario=restore-retry",
        ]

        app.launch()
        app.tabBars.buttons["Library"].tap()

        let retry = app.buttons["source-library.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        retry.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["source-library.empty"]
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testSourceImporterCanBeCancelledWithoutChangingLibrary() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=empty",
            "--source-library-scenario=empty",
        ]

        app.launch()
        app.tabBars.buttons["Library"].tap()
        let importButton = app.buttons["source-library.import"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
        importButton.tap()

        let cancelButton = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(
            cancelButton.waitForExistence(timeout: 5),
            "The native document picker should present a cancellation action."
        )
        cancelButton.tap()

        XCTAssertTrue(
            app.staticTexts["Import cancelled"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["source-library.empty"]
                .exists
        )
    }

    @MainActor
    func testImportedSourceReflowsInDarkAccessibilityText() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=empty",
            "--source-library-scenario=seeded",
            "-AppleInterfaceStyle",
            "Dark",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]

        app.launch()
        app.tabBars.buttons["Library"].tap()
        let sourceRow = app.buttons[
            "source.open.44444444-4444-4444-4444-444444444444"
        ]
        for _ in 0..<6 where !sourceRow.exists {
            app.swipeUp()
        }
        XCTAssertTrue(sourceRow.waitForExistence(timeout: 5))
        sourceRow.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["source.detail"]
                .waitForExistence(timeout: 5)
        )
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Imported source dark accessibility XXXL"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let citationButton = app.buttons["source.open-citation.0"]
        for _ in 0..<4 where !citationButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(citationButton.waitForExistence(timeout: 5))
    }

    @MainActor
    func testArticleStateRestoresAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=live",
            "--reset-ui-testing-learning-progress",
        ]

        app.launch()
        app.tabBars.buttons["Library"].tap()
        app.buttons["library.open.swift.value-semantics"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["article.reader"]
                .waitForExistence(timeout: 5)
        )

        app.buttons["article.bookmark"].tap()
        let markReadButton = app.buttons["article.mark-read"]
        expectation(
            for: NSPredicate(format: "isEnabled == true"),
            evaluatedWith: markReadButton
        )
        waitForExpectations(timeout: 5)
        markReadButton.tap()
        expectation(
            for: NSPredicate(format: "label == 'Article read'"),
            evaluatedWith: markReadButton
        )
        waitForExpectations(timeout: 5)

        app.terminate()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=live",
        ]
        app.launch()

        XCTAssertTrue(
            app.navigationBars["Library"].waitForExistence(timeout: 5)
        )
        let row = app.buttons["library.open.swift.value-semantics"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let value = row.value as? String
        XCTAssertTrue(value?.contains("read") == true)
        XCTAssertFalse(value?.contains("not read") == true)
        XCTAssertTrue(value?.contains("bookmarked") == true)
    }

    @MainActor
    func testIncorrectChallengeCanBeRemediatedAndRetried() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=empty",
        ]

        app.launch()
        app.tabBars.buttons["Challenges"].tap()
        app.buttons["challenges.open.swift.value-copy-output"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["challenge.player"]
                .waitForExistence(timeout: 5)
        )

        app.buttons["challenge.choice.one-one"].tap()
        app.buttons["challenge.submit"].tap()
        let incorrectFeedback = app.descendants(matching: .any)[
            "challenge.feedback.incorrect"
        ]
        assertAttemptSaved(incorrectFeedback)
        XCTAssertTrue(
            app.buttons["challenge.try-again"]
                .waitForExistence(timeout: 5)
        )
        app.buttons["challenge.try-again"].tap()
        app.buttons["challenge.choice.zero-one"].tap()
        app.buttons["challenge.submit"].tap()
        assertAttemptSaved(
            app.descendants(matching: .any)[
                "challenge.feedback.correct"
            ]
        )

        app.tabBars.buttons["Progress"].tap()
        let attempts = app.descendants(matching: .any)[
            "progress.attempts"
        ]
        let correct = app.descendants(matching: .any)[
            "progress.correct-answers"
        ]
        XCTAssertTrue(attempts.waitForExistence(timeout: 5))
        XCTAssertEqual(attempts.value as? String, "2")
        XCTAssertEqual(correct.value as? String, "1")
    }

    @MainActor
    private func assertAttemptSaved(_ feedback: XCUIElement) {
        XCTAssertTrue(
            feedback.waitForExistence(timeout: 5),
            "Deterministic feedback should be visible."
        )
        let saved = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "value CONTAINS %@",
                "Attempt saved."
            ),
            object: feedback
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [saved], timeout: 5),
            .completed,
            "The UI must not continue before the attempt is durable."
        )
    }
}
