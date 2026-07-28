//
//  DailySwiftApp.swift
//  Daily Swift
//
//  Created by Dragomir Mindrescu on 27.07.2026.
//

import SwiftUI

@main
@MainActor
struct DailySwiftApp: App {
    private let environment: AppEnvironment
    private let rootViewModel: AppRootViewModel

    init() {
        let environment = AppEnvironment.live()
        self.environment = environment
        rootViewModel = environment.makeRootViewModel()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                rootViewModel: rootViewModel,
                launchConfiguration: environment.launchConfiguration
            )
        }
    }
}
