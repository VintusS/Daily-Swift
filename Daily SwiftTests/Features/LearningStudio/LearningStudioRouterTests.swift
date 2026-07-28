import Testing
@testable import DailySwift

@MainActor
struct LearningStudioRouterTests {
    @Test("Each tab keeps an independent typed path")
    func independentPaths() {
        let router = LearningStudioRouter()

        router.openArticle("article.one")
        router.openSource(SourceLibraryFixtures.sourceID)
        router.openCitation(SourceLibraryFixtures.chunks[0].citation)
        router.openChallenge("challenge.one")
        router.openPreferences()

        #expect(router.selectedTab == .progress)
        #expect(
            router.libraryPath == [
                .article("article.one"),
                .sourceDocument(SourceLibraryFixtures.sourceID),
                .sourceCitation(
                    SourceLibraryFixtures.chunks[0].citation
                ),
            ]
        )
        #expect(
            router.challengesPath == [.challenge("challenge.one")]
        )
        #expect(router.progressPath == [.preferences])
        #expect(router.todayPath.isEmpty)
    }

    @Test("Returning after source deletion clears only the Library path")
    func sourceDeletionReturnsToLibraryRoot() {
        let router = LearningStudioRouter(
            selectedTab: .progress,
            challengesPath: [.challenge("challenge.one")],
            libraryPath: [
                .sourceDocument(SourceLibraryFixtures.sourceID),
                .sourceCitation(
                    SourceLibraryFixtures.chunks[0].citation
                ),
            ],
            progressPath: [.preferences]
        )

        router.returnToLibraryRoot()

        #expect(router.selectedTab == .library)
        #expect(router.libraryPath.isEmpty)
        #expect(
            router.challengesPath == [.challenge("challenge.one")]
        )
        #expect(router.progressPath == [.preferences])
    }

    @Test("Replacing one tab path leaves the others unchanged")
    func replaceOnePath() {
        let router = LearningStudioRouter(
            libraryPath: [.article("article.one")],
            progressPath: [.preferences]
        )

        router.replacePath(
            [.challenge("challenge.two")],
            for: .challenges
        )

        #expect(
            router.challengesPath == [.challenge("challenge.two")]
        )
        #expect(router.libraryPath == [.article("article.one")])
        #expect(router.progressPath == [.preferences])
    }

    @Test("Opening the visible destination does not duplicate its path")
    func duplicateDestinationIsIgnored() {
        let router = LearningStudioRouter()

        router.openArticle("article.one")
        router.openArticle("article.one")
        router.openChallenge("challenge.one")
        router.openChallenge("challenge.one")
        router.openPreferences()
        router.openPreferences()

        #expect(router.libraryPath == [.article("article.one")])
        #expect(
            router.challengesPath == [.challenge("challenge.one")]
        )
        #expect(router.progressPath == [.preferences])
    }

    @Test("Reset clears paths without changing the selected tab")
    func resetPaths() {
        let router = LearningStudioRouter(
            selectedTab: .library,
            todayPath: [.article("article.today")],
            challengesPath: [.challenge("challenge.one")],
            libraryPath: [.article("article.one")],
            progressPath: [.preferences]
        )

        router.resetPaths()

        #expect(router.selectedTab == .library)
        #expect(router.todayPath.isEmpty)
        #expect(router.challengesPath.isEmpty)
        #expect(router.libraryPath.isEmpty)
        #expect(router.progressPath.isEmpty)
    }
}
