import Foundation
import Observation

enum LearningStudioTab: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case today
    case challenges
    case library
    case progress

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .today:
            "Today"
        case .challenges:
            "Challenges"
        case .library:
            "Library"
        case .progress:
            "Progress"
        }
    }

    var symbolName: String {
        switch self {
        case .today:
            "sun.max"
        case .challenges:
            "checkmark.seal"
        case .library:
            "books.vertical"
        case .progress:
            "chart.bar"
        }
    }
}

enum LearningStudioRoute: Hashable, Sendable {
    case article(String)
    case challenge(String)
    case preferences
}

@MainActor
@Observable
final class LearningStudioRouter {
    var selectedTab: LearningStudioTab
    private(set) var todayPath: [LearningStudioRoute]
    private(set) var challengesPath: [LearningStudioRoute]
    private(set) var libraryPath: [LearningStudioRoute]
    private(set) var progressPath: [LearningStudioRoute]

    init(
        selectedTab: LearningStudioTab = .today,
        todayPath: [LearningStudioRoute] = [],
        challengesPath: [LearningStudioRoute] = [],
        libraryPath: [LearningStudioRoute] = [],
        progressPath: [LearningStudioRoute] = []
    ) {
        self.selectedTab = selectedTab
        self.todayPath = todayPath
        self.challengesPath = challengesPath
        self.libraryPath = libraryPath
        self.progressPath = progressPath
    }

    func replacePath(
        _ path: [LearningStudioRoute],
        for tab: LearningStudioTab
    ) {
        switch tab {
        case .today:
            todayPath = path
        case .challenges:
            challengesPath = path
        case .library:
            libraryPath = path
        case .progress:
            progressPath = path
        }
    }

    func openArticle(_ articleID: String) {
        selectedTab = .library
        let route = LearningStudioRoute.article(articleID)
        if libraryPath.last != route {
            libraryPath.append(route)
        }
    }

    func openChallenge(_ challengeID: String) {
        selectedTab = .challenges
        let route = LearningStudioRoute.challenge(challengeID)
        if challengesPath.last != route {
            challengesPath.append(route)
        }
    }

    func openPreferences() {
        selectedTab = .progress
        if progressPath.last != .preferences {
            progressPath.append(.preferences)
        }
    }

    func resetPaths() {
        todayPath.removeAll()
        challengesPath.removeAll()
        libraryPath.removeAll()
        progressPath.removeAll()
    }
}
