import SwiftUI

struct InteractionPreferencesView: View {
    let preferences: LearningPreferences
    let isResetting: Bool
    let isTemporarySession: Bool
    let onSoundChanged: (Bool) -> Void
    let onHapticsChanged: (Bool) -> Void
    let onAnimationsChanged: (Bool) -> Void
    let onReset: () async -> Bool
    let onPrivacy: () -> Void

    @State private var draft: LearningPreferences
    @State private var showsResetConfirmation = false

    init(
        preferences: LearningPreferences,
        isResetting: Bool,
        isTemporarySession: Bool,
        onSoundChanged: @escaping (Bool) -> Void,
        onHapticsChanged: @escaping (Bool) -> Void,
        onAnimationsChanged: @escaping (Bool) -> Void,
        onReset: @escaping () async -> Bool,
        onPrivacy: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.isResetting = isResetting
        self.isTemporarySession = isTemporarySession
        self.onSoundChanged = onSoundChanged
        self.onHapticsChanged = onHapticsChanged
        self.onAnimationsChanged = onAnimationsChanged
        self.onReset = onReset
        self.onPrivacy = onPrivacy
        _draft = State(initialValue: preferences)
    }

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Sound",
                    systemImage: "speaker.wave.2",
                    isOn: preferenceBinding(
                        \.soundEnabled,
                        onChange: onSoundChanged
                    )
                )
                Toggle(
                    "Haptics",
                    systemImage: "iphone.radiowaves.left.and.right",
                    isOn: preferenceBinding(
                        \.hapticsEnabled,
                        onChange: onHapticsChanged
                    )
                )
                Toggle(
                    "App animations",
                    systemImage: "sparkles",
                    isOn: preferenceBinding(
                        \.animationsEnabled,
                        onChange: onAnimationsChanged
                    )
                )
            } header: {
                Text("Feedback")
            } footer: {
                Text(
                    "System Reduce Motion always takes priority. Sound, haptics, and animation never carry learning meaning alone."
                )
            }
            .disabled(isResetting)

            Section("Privacy") {
                Button(action: onPrivacy) {
                    Label("Privacy & Data", systemImage: "hand.raised")
                }
            }

            Section {
                Button(role: .destructive) {
                    showsResetConfirmation = true
                } label: {
                    Label(
                        isTemporarySession
                            ? "Clear temporary session"
                            : "Reset learning progress",
                        systemImage: "trash"
                    )
                }
                .disabled(isResetting)
                .accessibilityHint(
                    isTemporarySession
                        ? "Asks for confirmation before clearing only this temporary in-memory session."
                        : "Asks for confirmation before removing saved attempts, article activity, and interaction preferences."
                )
                .accessibilityIdentifier("preferences.reset")
            } footer: {
                Text(
                    isTemporarySession
                        ? "Clear removes only this temporary session. The unavailable persistent store is not changed."
                        : "Reset removes only this learning studio’s local records. It does not change the separate launch shell."
                )
            }
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            isTemporarySession
                ? "Clear this temporary session?"
                : "Reset all learning progress?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                isTemporarySession
                    ? "Clear temporary session"
                    : "Reset learning progress",
                role: .destructive
            ) {
                Task {
                    if await onReset() {
                        draft = .init()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                isTemporarySession
                    ? "Only this in-memory session will be cleared. Persistent learning data is not changed."
                    : "Saved challenge attempts, article activity, and interaction preferences will be removed from this device."
            )
        }
        .accessibilityIdentifier("preferences.screen")
    }

    private func preferenceBinding(
        _ keyPath: WritableKeyPath<LearningPreferences, Bool>,
        onChange: @escaping (Bool) -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { newValue in
                draft[keyPath: keyPath] = newValue
                onChange(newValue)
            }
        )
    }
}
