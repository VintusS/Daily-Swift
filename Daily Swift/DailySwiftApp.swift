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
    private let learningStudioViewModel: LearningStudioViewModel
    private let sourceLibraryViewModel: SourceLibraryViewModel
    private let sourceRetrievalViewModel: SourceRetrievalViewModel

    init() {
        let environment = AppEnvironment.live()
        self.environment = environment
        rootViewModel = environment.makeRootViewModel()
        learningStudioViewModel =
            environment.makeLearningStudioViewModel()
        sourceLibraryViewModel =
            environment.makeSourceLibraryViewModel()
        sourceRetrievalViewModel =
            environment.makeSourceRetrievalViewModel()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                rootViewModel: rootViewModel,
                learningStudioViewModel: learningStudioViewModel,
                sourceLibraryViewModel: sourceLibraryViewModel,
                sourceRetrievalViewModel: sourceRetrievalViewModel,
                launchConfiguration: environment.launchConfiguration
            )
        }
    }
}
