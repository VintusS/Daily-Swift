import SwiftUI

struct ChallengesView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case incomplete
        case completed

        var id: String {
            rawValue
        }

        var title: String {
            rawValue.capitalized
        }
    }

    let snapshot: LearningProgressSnapshot
    let generatedArtifacts: [GeneratedLearningArtifact]
    let generatedLearningState: GeneratedLearningViewState
    let onGenerateLearning: () -> Void
    let onRetryGeneratedHistory: () -> Void
    let onOpenGeneratedQuiz: (UUID) -> Void

    @State private var filter: Filter = .all
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var visibleGeneratedArtifacts: [GeneratedLearningArtifact] {
        generatedArtifacts.filter { artifact in
            let isComplete = hasSavedAnswerKeyMatch(for: artifact)
            return switch filter {
            case .all:
                true
            case .incomplete:
                !isComplete
            case .completed:
                isComplete
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterControl
                .padding(.horizontal, StudioTokens.Spacing.medium)
                .padding(.vertical, StudioTokens.Spacing.xSmall)
                .background(.bar)
                .accessibilityIdentifier("challenges.filter")

            List {
                Section {
                    Button(action: onGenerateLearning) {
                        Label(
                            generatedArtifacts.isEmpty
                                ? "Generate a quiz from your sources"
                                : "Generate another article and quiz",
                            systemImage: "sparkles"
                        )
                    }
                    .accessibilityHint(
                        "Opens a new source-grounded generation request."
                    )
                    .accessibilityIdentifier(
                        "challenges.generate"
                    )
                } footer: {
                    Text(
                        "Every quiz here comes from a saved generated pair. Answer-key matches are activity evidence only and never update mastery."
                    )
                }

                if !visibleGeneratedArtifacts.isEmpty {
                    Section {
                        ForEach(visibleGeneratedArtifacts) { artifact in
                            Button {
                                onOpenGeneratedQuiz(artifact.id)
                            } label: {
                                GeneratedQuizHistoryRow(
                                    artifact: artifact,
                                    hasAnswerKeyMatch:
                                        hasSavedAnswerKeyMatch(
                                            for: artifact
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(
                                "generated-quiz.open.\(artifact.id.uuidString.lowercased())"
                            )
                        }
                    } header: {
                        HStack {
                            Text("Generated quizzes")
                            Spacer()
                            Text("\(visibleGeneratedArtifacts.count)")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Generated quizzes")
                        .accessibilityValue(
                            "\(visibleGeneratedArtifacts.count)"
                        )
                        .accessibilityIdentifier(
                            "generated-quizzes.count"
                        )
                    }
                } else {
                    Section {
                        generatedEmptyState
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Challenges")
        .accessibilityIdentifier("challenges.screen")
    }

    @ViewBuilder
    private var generatedEmptyState: some View {
        if generatedArtifacts.isEmpty {
            switch generatedLearningState {
            case .loading:
                HStack(spacing: StudioTokens.Spacing.small) {
                    ProgressView()
                    Text("Loading generated quizzes")
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("challenges.loading")

            case let .failed(failure) where failure == .storageUnavailable:
                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.small
                ) {
                    Label(
                        failure.title,
                        systemImage: "externaldrive.badge.exclamationmark"
                    )
                    .font(StudioTokens.Typography.sectionHeading)

                    Text(failure.message)
                        .font(StudioTokens.Typography.supporting)
                        .foregroundStyle(StudioTokens.Color.secondaryText)

                    Button(
                        "Retry loading generated history",
                        action: onRetryGeneratedHistory
                    )
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(
                        "challenges.retry-generated-history"
                    )
                }
                .accessibilityIdentifier("challenges.storage-unavailable")

            case let .unavailable(reason):
                ContentUnavailableView(
                    reason.title,
                    systemImage: "iphone.slash",
                    description: Text(reason.message)
                )
                .accessibilityIdentifier("challenges.unavailable")

            default:
                ContentUnavailableView(
                    "No generated quizzes yet",
                    systemImage: "sparkles.rectangle.stack",
                    description: Text(
                        "Import a source and request a topic to create your first article and quiz."
                    )
                )
                .accessibilityIdentifier("challenges.empty")
            }
        } else {
            ContentUnavailableView(
                filter == .completed
                    ? "No completed generated quizzes"
                    : "No incomplete generated quizzes",
                systemImage: filter == .completed
                    ? "checkmark.circle"
                    : "circle.dashed",
                description: Text(
                    "Choose another filter to see your generated quizzes."
                )
            )
            .accessibilityIdentifier("challenges.filtered-empty")
        }
    }

    private func hasSavedAnswerKeyMatch(
        for artifact: GeneratedLearningArtifact
    ) -> Bool {
        snapshot.attempts.contains {
            $0.challengeID == artifact.quizID
                && $0.selectedChoiceID
                    == artifact.quiz.answerKeyChoiceID
        }
    }

    @ViewBuilder
    private var filterControl: some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack {
                Text("Quiz filter")
                    .font(StudioTokens.Typography.sectionHeading)

                Spacer()

                Picker("Quiz filter", selection: $filter) {
                    ForEach(Filter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }
        } else {
            Picker("Quiz filter", selection: $filter) {
                ForEach(Filter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
