import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    private(set) var path: [AppRoute]

    init(path: [AppRoute] = []) {
        self.path = path
    }

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func replacePath(with routes: [AppRoute]) {
        path = routes
    }

    func goBack() {
        guard !path.isEmpty else {
            return
        }

        path.removeLast()
    }

    func reset() {
        path.removeAll()
    }
}
