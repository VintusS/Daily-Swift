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
    private let sourceLibraryViewModel: SourceLibraryViewModel
    private let sourceRetrievalViewModel: SourceRetrievalViewModel
    private let launchConfiguration: AppLaunchConfiguration

    init(environment: AppEnvironment = .live()) {
        self.init(
            rootViewModel: environment.makeRootViewModel(),
            learningStudioViewModel:
                environment.makeLearningStudioViewModel(),
            sourceLibraryViewModel:
                environment.makeSourceLibraryViewModel(),
            sourceRetrievalViewModel:
                environment.makeSourceRetrievalViewModel(),
            launchConfiguration: environment.launchConfiguration
        )
    }

    init(
        rootViewModel: AppRootViewModel,
        learningStudioViewModel: LearningStudioViewModel,
        sourceLibraryViewModel: SourceLibraryViewModel,
        sourceRetrievalViewModel: SourceRetrievalViewModel,
        launchConfiguration: AppLaunchConfiguration
    ) {
        self.rootViewModel = rootViewModel
        self.learningStudioViewModel = learningStudioViewModel
        self.sourceLibraryViewModel = sourceLibraryViewModel
        self.sourceRetrievalViewModel = sourceRetrievalViewModel
        self.launchConfiguration = launchConfiguration
    }

    var body: some View {
#if DEBUG
        if launchConfiguration.isStructuredGenerationSpikeEnabled {
            StructuredGenerationView()
        } else {
            AppRootView(
                viewModel: rootViewModel,
                learningStudioViewModel: learningStudioViewModel,
                sourceLibraryViewModel: sourceLibraryViewModel,
                sourceRetrievalViewModel: sourceRetrievalViewModel
            )
        }
#else
        AppRootView(
            viewModel: rootViewModel,
            learningStudioViewModel: learningStudioViewModel,
            sourceLibraryViewModel: sourceLibraryViewModel,
            sourceRetrievalViewModel: sourceRetrievalViewModel
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
