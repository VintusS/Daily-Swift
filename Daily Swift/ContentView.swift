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
    private let launchConfiguration: AppLaunchConfiguration

    init(environment: AppEnvironment = .live()) {
        self.init(
            rootViewModel: environment.makeRootViewModel(),
            launchConfiguration: environment.launchConfiguration
        )
    }

    init(
        rootViewModel: AppRootViewModel,
        launchConfiguration: AppLaunchConfiguration
    ) {
        self.rootViewModel = rootViewModel
        self.launchConfiguration = launchConfiguration
    }

    var body: some View {
#if DEBUG
        if launchConfiguration.isStructuredGenerationSpikeEnabled {
            StructuredGenerationView()
        } else {
            AppRootView(viewModel: rootViewModel)
        }
#else
        AppRootView(viewModel: rootViewModel)
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
