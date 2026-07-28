//
//  ContentView.swift
//  Daily Swift
//
//  Created by Dragomir Mindrescu on 27.07.2026.
//

import SwiftUI

@MainActor
struct ContentView: View {
    private let rootViewModel: AppRootViewModel
    private let learningStudioViewModel: LearningStudioViewModel
    private let launchConfiguration: AppLaunchConfiguration

    init(environment: AppEnvironment = .live()) {
        self.init(
            rootViewModel: environment.makeRootViewModel(),
            learningStudioViewModel:
                environment.makeLearningStudioViewModel(),
            launchConfiguration: environment.launchConfiguration
        )
    }

    init(
        rootViewModel: AppRootViewModel,
        learningStudioViewModel: LearningStudioViewModel,
        launchConfiguration: AppLaunchConfiguration
    ) {
        self.rootViewModel = rootViewModel
        self.learningStudioViewModel = learningStudioViewModel
        self.launchConfiguration = launchConfiguration
    }

    var body: some View {
#if DEBUG
        if launchConfiguration.isStructuredGenerationSpikeEnabled {
            StructuredGenerationView()
        } else {
            AppRootView(
                viewModel: rootViewModel,
                learningStudioViewModel: learningStudioViewModel
            )
        }
#else
        AppRootView(
            viewModel: rootViewModel,
            learningStudioViewModel: learningStudioViewModel
        )
#endif
    }
}

#Preview {
    ContentView(
        environment: AppEnvironment(
            bootstrapService: InMemoryAppBootstrapService()
        )
    )
}
