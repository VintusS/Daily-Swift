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
    func testGeneratedLearningFromImportedPDFCanBeReadAndCompleted() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=empty",
            "--source-library-scenario=seeded-pdf",
        ]

        app.launch()
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(
            app.navigationBars["Library"].waitForExistence(timeout: 5)
        )

        let openComposer = app.buttons[
            "generated-learning.open-composer"
        ]
        XCTAssertTrue(openComposer.waitForExistence(timeout: 5))
        openComposer.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.composer"
            ]
            .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.staticTexts["Experimental / User Material"]
                .waitForExistence(timeout: 5)
        )

        let topic = app.descendants(matching: .any)[
            "generated-learning.topic"
        ]
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        topic.tap()
        topic.typeText("page provenance")

        let allSources = app.buttons["generated-learning.source.all"]
        XCTAssertTrue(scrollToHittable(allSources, in: app))
        XCTAssertEqual(allSources.value as? String, "Selected")
        allSources.tap()

        let generate = app.buttons["generated-learning.generate"]
        XCTAssertTrue(scrollToHittable(generate, in: app))
        generate.tap()

        let openArticle = app.buttons[
            "generated-learning.open-article"
        ]
        XCTAssertTrue(
            openArticle.waitForExistence(timeout: 5),
            "The deterministic UI-testing provider should save a cited article and quiz."
        )
        XCTAssertTrue(scrollToHittable(openArticle, in: app))
        openArticle.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-article.reader"
            ]
            .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-article.experimental-notice"
            ]
                .waitForExistence(timeout: 5)
        )

        let articleCitation = app.buttons[
            "generated-article.citation.source-card-1"
        ]
        XCTAssertTrue(scrollToHittable(articleCitation, in: app))
        articleCitation.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["citation.reader"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.staticTexts["Exact stored passage"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Page 1"].exists)

        let citationBack = app.navigationBars["Exact Citation"]
            .buttons.firstMatch
        XCTAssertTrue(citationBack.waitForExistence(timeout: 5))
        citationBack.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-article.reader"
            ]
            .waitForExistence(timeout: 5)
        )
        let markRead = app.buttons["generated-article.mark-read"]
        XCTAssertTrue(scrollToHittable(markRead, in: app))
        markRead.tap()

        let articleRead = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "label == %@",
                "Generated article read"
            ),
            object: markRead
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [articleRead], timeout: 5),
            .completed,
            "The generated article completion should be saved before continuing."
        )

        let openQuiz = app.buttons["generated-article.open-quiz"]
        XCTAssertTrue(scrollToHittable(openQuiz, in: app))
        openQuiz.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["generated-quiz.player"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.staticTexts["Experimental answer key"]
                .waitForExistence(timeout: 5)
        )

        let answer = app.buttons["generated-quiz.choice.choice-1"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        answer.tap()

        let submit = app.buttons["generated-quiz.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        submit.tap()

        let generatedFeedback = app.descendants(matching: .any)[
            "generated-quiz.feedback"
        ]
        XCTAssertTrue(generatedFeedback.waitForExistence(timeout: 5))
        XCTAssertEqual(
            generatedFeedback.label,
            "Matches the generated answer key"
        )
        let generatedAttemptSaved = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "value CONTAINS %@",
                "Attempt saved as activity evidence. It does not update mastery."
            ),
            object: generatedFeedback
        )
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [generatedAttemptSaved],
                timeout: 5
            ),
            .completed,
            "The generated attempt should be durable before continuing."
        )

        let quizCitation = app.buttons[
            "generated-quiz.citation.source-card-1"
        ]
        XCTAssertTrue(scrollToHittable(quizCitation, in: app))
        quizCitation.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["citation.reader"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Page 1"].exists)

        returnToNavigationRoot("Library", in: app)
        let generatedArticleRows = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "generated-article.open."
            )
        )
        XCTAssertTrue(
            scrollToExistence(generatedArticleRows.firstMatch, in: app)
        )

        app.tabBars.buttons["Challenges"].tap()
        returnToNavigationRoot("Challenges", in: app)
        let generatedQuizRows = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "generated-quiz.open."
            )
        )
        XCTAssertTrue(
            scrollToExistence(generatedQuizRows.firstMatch, in: app)
        )

        app.tabBars.buttons["Progress"].tap()
        let generatedAttempts = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "progress.attempt."
            )
        )
        XCTAssertTrue(
            scrollToExistence(generatedAttempts.firstMatch, in: app)
        )
    }

    @MainActor
    func testGeneratedLearningWithoutSourcesKeepsReviewedLearningAvailable()
        throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=empty",
            "--source-library-scenario=empty",
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
        XCTAssertTrue(
            app.navigationBars["Library"].waitForExistence(timeout: 5)
        )
        let openComposer = app.buttons[
            "generated-learning.open-composer"
        ]
        XCTAssertTrue(openComposer.waitForExistence(timeout: 5))
        openComposer.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.no-sources"
            ]
            .waitForExistence(timeout: 5)
        )
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name =
            "Generated learning no-source fallback accessibility XXXL"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let generate = app.buttons["generated-learning.generate"]
        XCTAssertTrue(scrollToExistence(generate, in: app))
        XCTAssertFalse(generate.isEnabled)

        let composerBack = app.navigationBars["Generate Learning"]
            .buttons.firstMatch
        XCTAssertTrue(composerBack.waitForExistence(timeout: 5))
        composerBack.tap()

        XCTAssertTrue(
            app.navigationBars["Library"].waitForExistence(timeout: 5)
        )
        let reviewedArticle = app.buttons[
            "library.open.swift.value-semantics"
        ]
        XCTAssertTrue(scrollToHittable(reviewedArticle, in: app))
    }

    @MainActor
    func testGeneratedLearningReadersSupportAccessibilityXXXL() throws {
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
        let generate = openGeneratedComposer(
            in: app,
            topic: "page provenance"
        )
        XCTAssertTrue(waitForEnabled(generate))
        generate.tap()

        let openArticle = app.buttons[
            "generated-learning.open-article"
        ]
        XCTAssertTrue(scrollToHittable(openArticle, in: app))
        openArticle.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-article.reader"
            ].waitForExistence(timeout: 5)
        )
        let articleScreenshot = XCTAttachment(
            screenshot: app.screenshot()
        )
        articleScreenshot.name =
            "Generated article dark accessibility XXXL"
        articleScreenshot.lifetime = .keepAlways
        add(articleScreenshot)

        let openQuiz = app.buttons["generated-article.open-quiz"]
        XCTAssertTrue(scrollToHittable(openQuiz, in: app))
        openQuiz.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["generated-quiz.player"]
                .waitForExistence(timeout: 5)
        )
        let quizScreenshot = XCTAttachment(screenshot: app.screenshot())
        quizScreenshot.name = "Generated quiz dark accessibility XXXL"
        quizScreenshot.lifetime = .keepAlways
        add(quizScreenshot)
    }

    @MainActor
    func testGeneratedLearningFromMarkdownRegeneratesAndOpensExactCitation()
        throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=empty",
            "--source-library-scenario=seeded",
        ]

        app.launch()
        let generate = openGeneratedComposer(
            in: app,
            topic: "actor isolation"
        )
        XCTAssertTrue(waitForEnabled(generate))
        generate.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.status.generated"
            ].waitForExistence(timeout: 5)
        )
        for _ in 0..<6 where !generate.isHittable {
            app.swipeDown()
        }
        XCTAssertTrue(generate.isHittable)
        XCTAssertTrue(waitForEnabled(generate))
        generate.tap()
        XCTAssertTrue(waitForEnabled(generate))
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.status.generated"
            ].waitForExistence(timeout: 5)
        )

        returnToNavigationRoot("Library", in: app)
        let generatedRows = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "generated-article.open."
            )
        )
        XCTAssertTrue(
            scrollToExistence(generatedRows.firstMatch, in: app)
        )
        XCTAssertEqual(generatedRows.count, 2)

        app.tabBars.buttons["Challenges"].tap()
        let quizRows = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "generated-quiz.open."
            )
        )
        XCTAssertTrue(scrollToHittable(quizRows.firstMatch, in: app))
        XCTAssertEqual(quizRows.count, 2)
        quizRows.firstMatch.tap()

        let citation = app.buttons[
            "generated-quiz.citation.source-card-1"
        ]
        XCTAssertTrue(scrollToHittable(citation, in: app))
        citation.tap()
        XCTAssertTrue(
            app.staticTexts["Exact stored passage"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.staticTexts["Actor isolation"]
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testGeneratedLearningHistoryRestoresAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=live",
            "--reset-ui-testing-learning-progress",
            "--source-library-scenario=seeded",
            "--generated-learning-scenario=persistent",
            "--reset-ui-testing-generated-learning",
        ]

        app.launch()
        let generate = openGeneratedComposer(
            in: app,
            topic: "actor isolation"
        )
        XCTAssertTrue(waitForEnabled(generate))
        generate.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.status.generated"
            ].waitForExistence(timeout: 5)
        )

        let openArticle = app.buttons[
            "generated-learning.open-article"
        ]
        XCTAssertTrue(scrollToHittable(openArticle, in: app))
        openArticle.tap()
        let markRead = app.buttons["generated-article.mark-read"]
        XCTAssertTrue(scrollToHittable(markRead, in: app))
        markRead.tap()
        let readSaved = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "label == %@",
                "Generated article read"
            ),
            object: markRead
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [readSaved], timeout: 5),
            .completed
        )

        let openQuiz = app.buttons["generated-article.open-quiz"]
        XCTAssertTrue(scrollToHittable(openQuiz, in: app))
        openQuiz.tap()
        let firstChoice = app.buttons[
            "generated-quiz.choice.choice-1"
        ]
        XCTAssertTrue(firstChoice.waitForExistence(timeout: 5))
        firstChoice.tap()
        app.buttons["generated-quiz.submit"].tap()
        let feedback = app.descendants(matching: .any)[
            "generated-quiz.feedback"
        ]
        XCTAssertTrue(feedback.waitForExistence(timeout: 5))
        let attemptSaved = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "value CONTAINS %@",
                "Attempt saved as activity evidence."
            ),
            object: feedback
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [attemptSaved], timeout: 5),
            .completed
        )

        app.terminate()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--learning-studio-scenario=live",
            "--source-library-scenario=seeded",
            "--generated-learning-scenario=persistent",
        ]
        app.launch()
        app.tabBars.buttons["Library"].tap()

        let restoredArticle = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "generated-article.open."
            )
        ).firstMatch
        XCTAssertTrue(scrollToHittable(restoredArticle, in: app))
        let articleReadRestored = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "value CONTAINS %@",
                "Read"
            ),
            object: restoredArticle
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [articleReadRestored], timeout: 5),
            .completed
        )

        app.tabBars.buttons["Challenges"].tap()
        let restoredQuiz = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "generated-quiz.open."
            )
        ).firstMatch
        XCTAssertTrue(scrollToHittable(restoredQuiz, in: app))
        let answerKeyMatchRestored = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "value CONTAINS %@",
                "Matched"
            ),
            object: restoredQuiz
        )
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [answerKeyMatchRestored],
                timeout: 5
            ),
            .completed
        )

        app.tabBars.buttons["Progress"].tap()
        let attempts = app.descendants(matching: .any)[
            "progress.attempts"
        ]
        let correctAnswers = app.descendants(matching: .any)[
            "progress.correct-answers"
        ]
        XCTAssertTrue(attempts.waitForExistence(timeout: 5))
        XCTAssertEqual(attempts.value as? String, "0")
        XCTAssertEqual(correctAnswers.value as? String, "0")
        let experimentalAttempt = app.descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@",
                    "progress.attempt."
                )
            )
            .firstMatch
        XCTAssertTrue(scrollToExistence(experimentalAttempt, in: app))
        let restoredExperimentalLabel = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "label CONTAINS %@",
                "Matches the generated answer key"
            ),
            object: experimentalAttempt
        )
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [restoredExperimentalLabel],
                timeout: 5
            ),
            .completed
        )
    }

    @MainActor
    func testGeneratedLearningUnavailableDisablesGeneration() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--source-library-scenario=seeded",
            "--generated-learning-scenario=unavailable",
        ]

        app.launch()
        let generate = openGeneratedComposer(
            in: app,
            topic: "actor isolation"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.status.unavailable"
            ].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(generate.isEnabled)
        let fallback = app.buttons["generated-learning.fallback"]
        XCTAssertTrue(scrollToHittable(fallback, in: app))
        fallback.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["library.screen"]
                .waitForExistence(timeout: 5)
        )
        let reviewedArticle = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "library.open."
            )
        ).firstMatch
        XCTAssertTrue(scrollToHittable(reviewedArticle, in: app))
    }

    @MainActor
    func testGeneratedLearningRejectsUncitedCandidate() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--source-library-scenario=seeded",
            "--generated-learning-scenario=rejected",
        ]

        app.launch()
        let generate = openGeneratedComposer(
            in: app,
            topic: "actor isolation"
        )
        XCTAssertTrue(waitForEnabled(generate))
        generate.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.status.rejected"
            ].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(
            app.buttons["generated-learning.open-article"].exists
        )
    }

    @MainActor
    func testGeneratedLearningCancellationDrainsBeforeRetry() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--source-library-scenario=seeded",
            "--generated-learning-scenario=delayed",
        ]

        app.launch()
        let generate = openGeneratedComposer(
            in: app,
            topic: "actor isolation"
        )
        XCTAssertTrue(waitForEnabled(generate))
        generate.tap()

        let cancel = app.buttons["generated-learning.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.cancelling"
            ].waitForExistence(timeout: 1)
        )
        XCTAssertFalse(
            app.buttons["generated-learning.generate"].exists,
            "A second request must remain unavailable while cancellation drains."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.status.cancelled"
            ].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(waitForEnabled(generate))
        XCTAssertFalse(
            app.buttons["generated-learning.open-article"].exists
        )

        generate.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.status.generated"
            ].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testGeneratedLearningFinalizationCannotBeCancelledOrReplaced()
        throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--source-library-scenario=seeded",
            "--generated-learning-scenario=finalizing",
        ]

        app.launch()
        let generate = openGeneratedComposer(
            in: app,
            topic: "actor isolation"
        )
        XCTAssertTrue(waitForEnabled(generate))
        generate.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.status.finalizing"
            ].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.buttons["generated-learning.cancel"].exists)
        XCTAssertFalse(app.buttons["generated-learning.generate"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.status.generated"
            ].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testGeneratedLearningStorageRetryRestoresReadyState() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--source-library-scenario=seeded",
            "--generated-learning-scenario=storage-retry",
        ]

        app.launch()
        _ = openGeneratedComposer(in: app, topic: "actor isolation")
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.status.storage-unavailable"
            ].waitForExistence(timeout: 5)
        )
        let retry = app.buttons["generated-learning.retry-storage"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        retry.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.status.ready"
            ].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testGeneratedLearningInsufficientEvidenceKeepsFallback() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--app-shell-scenario=ready",
            "--source-library-scenario=seeded",
        ]

        app.launch()
        let generate = openGeneratedComposer(
            in: app,
            topic: "nonexistentlexeme"
        )
        XCTAssertTrue(waitForEnabled(generate))
        generate.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.status.failed"
            ].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["generated-learning.fallback"].exists)
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

    @MainActor
    private func openGeneratedComposer(
        in app: XCUIApplication,
        topic: String
    ) -> XCUIElement {
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(
            app.navigationBars["Library"].waitForExistence(timeout: 5)
        )
        let openComposer = app.buttons[
            "generated-learning.open-composer"
        ]
        XCTAssertTrue(scrollToHittable(openComposer, in: app))
        openComposer.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "generated-learning.composer"
            ].waitForExistence(timeout: 5)
        )
        let topicField = app.descendants(matching: .any)[
            "generated-learning.topic"
        ]
        XCTAssertTrue(topicField.waitForExistence(timeout: 5))
        topicField.tap()
        topicField.typeText(topic)
        let generate = app.buttons["generated-learning.generate"]
        XCTAssertTrue(scrollToExistence(generate, in: app))
        return generate
    }

    @MainActor
    private func waitForEnabled(
        _ element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: element
        )
        return XCTWaiter.wait(
            for: [expectation],
            timeout: timeout
        ) == .completed
    }

    @MainActor
    private func returnToNavigationRoot(
        _ title: String,
        in app: XCUIApplication
    ) {
        if app.navigationBars[title].waitForExistence(timeout: 1) {
            return
        }
        for _ in 0..<6 {
            let backButton = app.navigationBars.buttons.firstMatch
            guard backButton.waitForExistence(timeout: 1) else {
                break
            }
            backButton.tap()
            if app.navigationBars[title].waitForExistence(timeout: 1) {
                return
            }
        }
        XCTAssertTrue(
            app.navigationBars[title].exists,
            "Expected to return to the \(title) root."
        )
    }

    @MainActor
    private func scrollToHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maximumSwipes: Int = 8
    ) -> Bool {
        if element.waitForExistence(timeout: 2), element.isHittable {
            return true
        }
        for _ in 0..<maximumSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 0.5), element.isHittable {
                return true
            }
        }
        return element.isHittable
    }

    @MainActor
    private func scrollToExistence(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maximumSwipes: Int = 8
    ) -> Bool {
        if element.waitForExistence(timeout: 2) {
            return true
        }
        for _ in 0..<maximumSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 0.5) {
                return true
            }
        }
        return element.exists
    }
}
