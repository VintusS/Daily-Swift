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

    let catalog: LearningCatalog
    let evidence: LearningEvidenceSummary
    let snapshot: LearningProgressSnapshot
    let generatedArtifacts: [GeneratedLearningArtifact]
    let onOpenChallenge: (String) -> Void
    let onOpenGeneratedQuiz: (UUID) -> Void

    @State private var filter: Filter = .all
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var visibleChallenges: [LearningChallenge] {
        catalog.challenges.filter { challenge in
            switch filter {
            case .all:
                true
            case .incomplete:
                !evidence.completedChallengeIDs.contains(challenge.id)
            case .completed:
                evidence.completedChallengeIDs.contains(challenge.id)
            }
        }
    }

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

            Group {
                if visibleChallenges.isEmpty
                    && visibleGeneratedArtifacts.isEmpty {
                    ContentUnavailableView(
                        "No \(filter.title.lowercased()) challenges",
                        systemImage: "checkmark.seal",
                        description: Text(
                            filter == .completed
                                ? "Complete a challenge and its recorded evidence will appear here."
                                : "Choose another filter to keep practicing."
                        )
                    )
                } else {
                    List {
                        if !visibleGeneratedArtifacts.isEmpty {
                            Section {
                                ForEach(
                                    visibleGeneratedArtifacts
                                ) { artifact in
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
                                    Text(
                                        "\(visibleGeneratedArtifacts.count)"
                                    )
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Generated quizzes")
                                .accessibilityValue(
                                    "\(visibleGeneratedArtifacts.count)"
                                )
                                .accessibilityIdentifier(
                                    "generated-quizzes.count"
                                )
                            } footer: {
                                Text(
                                    "Answer-key matches are recorded as activity only. Generated quizzes are experimental and never update mastery."
                                )
                            }
                        }

                        if !visibleChallenges.isEmpty {
                            Section {
                                ForEach(visibleChallenges) { challenge in
                                    Button {
                                        onOpenChallenge(challenge.id)
                                    } label: {
                                        ChallengeCatalogRow(
                                            challenge: challenge,
                                            isComplete: evidence
                                                .completedChallengeIDs
                                                .contains(challenge.id)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier(
                                        "challenges.open.\(challenge.id)"
                                    )
                                }
                            } header: {
                                Text(
                                    "\(visibleChallenges.count) deterministic challenges"
                                )
                            } footer: {
                                Text(
                                    "Feedback is checked against bundled answer keys. No model or network is used."
                                )
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
        }
        .navigationTitle("Challenges")
        .accessibilityIdentifier("challenges.screen")
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
                Text("Challenge filter")
                    .font(StudioTokens.Typography.sectionHeading)

                Spacer()

                Picker("Challenge filter", selection: $filter) {
                    ForEach(Filter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }
        } else {
            Picker("Challenge filter", selection: $filter) {
                ForEach(Filter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct ChallengeCatalogRow: View {
    let challenge: LearningChallenge
    let isComplete: Bool

    var body: some View {
        HStack(
            alignment: .top,
            spacing: StudioTokens.Spacing.small
        ) {
            Image(systemName: challenge.kind.symbolName)
                .font(.title3)
                .foregroundStyle(StudioTokens.Color.action)
                .frame(minWidth: 30, minHeight: 30)
                .accessibilityHidden(true)

            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.xSmall
            ) {
                HStack(alignment: .firstTextBaseline) {
                    Text(challenge.title)
                        .font(StudioTokens.Typography.sectionHeading)
                        .foregroundStyle(StudioTokens.Color.primaryText)

                    Spacer()

                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(StudioTokens.Color.primaryText)
                            .accessibilityLabel("Completed")
                    }
                }

                Text(challenge.prompt)
                    .font(StudioTokens.Typography.supporting)
                    .foregroundStyle(StudioTokens.Color.secondaryText)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: StudioTokens.Spacing.xSmall) {
                        metadata
                    }

                    VStack(
                        alignment: .leading,
                        spacing: StudioTokens.Spacing.xxSmall
                    ) {
                        metadata
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StudioTokens.Color.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(.vertical, StudioTokens.Spacing.xxSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(challenge.title)
        .accessibilityValue(
            "\(challenge.prompt) \(challenge.domain.title), \(challenge.kind.label), \(challenge.difficulty.label), \(isComplete ? "completed" : "not completed")"
        )
        .accessibilityHint("Opens the challenge.")
    }

    @ViewBuilder
    private var metadata: some View {
        LearningBadge(
            challenge.domain.title,
            symbol: challenge.domain.symbolName
        )
        LearningBadge(
            challenge.difficulty.label,
            symbol: "dial.medium"
        )
    }
}
