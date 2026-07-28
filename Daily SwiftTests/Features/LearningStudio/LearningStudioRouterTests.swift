import Testing
@testable import DailySwift

@MainActor
struct LearningStudioRouterTests {
    @Test("Each tab keeps an independent typed path")
    func independentPaths() {
        let router = LearningStudioRouter()

        router.openArticle("article.one")
        router.openChallenge("challenge.one")
        router.openPreferences()

        #expect(router.selectedTab == .progress)
        #expect(router.libraryPath == [.article("article.one")])
        #expect(
            router.challengesPath == [.challenge("challenge.one")]
        )
        #expect(router.progressPath == [.preferences])
        #expect(router.todayPath.isEmpty)
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
