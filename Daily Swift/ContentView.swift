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
    private let generatedLearningViewModel: GeneratedLearningViewModel
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
            generatedLearningViewModel:
                environment.makeGeneratedLearningViewModel(),
            launchConfiguration: environment.launchConfiguration
        )
    }

    init(
        rootViewModel: AppRootViewModel,
        learningStudioViewModel: LearningStudioViewModel,
        sourceLibraryViewModel: SourceLibraryViewModel,
        sourceRetrievalViewModel: SourceRetrievalViewModel,
        generatedLearningViewModel: GeneratedLearningViewModel,
        launchConfiguration: AppLaunchConfiguration
    ) {
        self.rootViewModel = rootViewModel
        self.learningStudioViewModel = learningStudioViewModel
        self.sourceLibraryViewModel = sourceLibraryViewModel
        self.sourceRetrievalViewModel = sourceRetrievalViewModel
        self.generatedLearningViewModel = generatedLearningViewModel
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
                sourceRetrievalViewModel: sourceRetrievalViewModel,
                generatedLearningViewModel: generatedLearningViewModel
            )
        }
#else
        AppRootView(
            viewModel: rootViewModel,
            learningStudioViewModel: learningStudioViewModel,
            sourceLibraryViewModel: sourceLibraryViewModel,
            sourceRetrievalViewModel: sourceRetrievalViewModel,
            generatedLearningViewModel: generatedLearningViewModel
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
