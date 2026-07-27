//
//  ContentView.swift
//  Daily Swift
//
//  Created by Dragomir Mindrescu on 27.07.2026.
//

import SwiftUI

@MainActor
struct ContentView: View {
    var body: some View {
#if DEBUG
        StructuredGenerationView()
#else
        VStack {
            Image(systemName: "swift")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Daily Swift")
                .accessibilityIdentifier("initial.greeting")
        }
        .padding()
#endif
    }
}

#Preview {
    ContentView()
}
