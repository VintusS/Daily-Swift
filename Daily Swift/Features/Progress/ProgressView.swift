import SwiftUI

struct LearningProgressView: View {
    let snapshot: LearningProgressSnapshot
    let generatedArtifacts: [GeneratedLearningArtifact]
    let isTemporarySession: Bool
    let onOpenPreferences: () -> Void
    let onPrivacy: () -> Void

    private var artifactsByQuizID: [String: GeneratedLearningArtifact] {
        Dictionary(
            uniqueKeysWithValues: generatedArtifacts.map {
                ($0.quizID, $0)
            }
        )
    }

    private var recentAttempts: [ChallengeAttempt] {
        Array(
            snapshot.attempts.filter {
                artifactsByQuizID[$0.challengeID] != nil
            }.sorted {
                $0.attemptedAt > $1.attemptedAt
            }.prefix(5)
        )
    }

    private var generatedAttemptCount: Int {
        snapshot.attempts.filter {
            artifactsByQuizID[$0.challengeID] != nil
        }.count
    }

    private var answerKeyMatchCount: Int {
        snapshot.attempts.filter { attempt in
            guard let artifact = artifactsByQuizID[attempt.challengeID] else {
                return false
            }
            return attempt.selectedChoiceID
                == artifact.quiz.answerKeyChoiceID
        }.count
    }

    private var generatedArticleReadCount: Int {
        generatedArtifacts.filter {
            snapshot.activity(for: $0.articleID).completedAt != nil
        }.count
    }

    private var generatedArticleActivityCount: Int {
        generatedArtifacts.filter { artifact in
            let activity = snapshot.activity(for: artifact.articleID)
            return activity.lastOpenedAt != nil
                || activity.completedAt != nil
                || activity.isBookmarked
        }.count
    }

    private var hasAnyRecordedActivity: Bool {
        !generatedArtifacts.isEmpty
            || generatedAttemptCount > 0
            || generatedArticleActivityCount > 0
    }

    var body: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.large
            ) {
                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.xSmall
                ) {
                    Text(
                        isTemporarySession
                            ? "TEMPORARY GENERATED ACTIVITY"
                            : "SAVED GENERATED ACTIVITY"
                    )
                    .font(
                        StudioTokens.Typography.codeCaption.weight(.bold)
                    )
                    .foregroundStyle(StudioTokens.Color.primaryText)

                    Text(progressHeading)
                        .font(StudioTokens.Typography.display)
                        .foregroundStyle(StudioTokens.Color.primaryText)
                        .accessibilityAddTraits(.isHeader)

                    Text(progressSummary)
                        .font(StudioTokens.Typography.body)
                        .foregroundStyle(StudioTokens.Color.secondaryText)
                }

                evidenceOverview

                recentEvidence

                LearningCard {
                    VStack(
                        alignment: .leading,
                        spacing: StudioTokens.Spacing.small
                    ) {
                        Text("Controls")
                            .font(StudioTokens.Typography.title)
                            .accessibilityAddTraits(.isHeader)

                        Button(action: onOpenPreferences) {
                            Label(
                                "Interaction preferences",
                                systemImage: "slider.horizontal.3"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudioSecondaryButtonStyle())
                        .accessibilityIdentifier(
                            "progress.preferences"
                        )

                        Button(action: onPrivacy) {
                            Label(
                                "Privacy & Data",
                                systemImage: "hand.raised"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudioSecondaryButtonStyle())
                        .accessibilityIdentifier("progress.privacy")
                    }
                }
            }
            .frame(maxWidth: 720)
            .padding(StudioTokens.Spacing.medium)
            .padding(.bottom, StudioTokens.Spacing.xLarge)
            .frame(maxWidth: .infinity)
        }
        .background(StudioTokens.Color.groupedCanvas)
        .navigationTitle("Progress")
        .accessibilityIdentifier("progress.screen")
    }

    private var progressHeading: String {
        if isTemporarySession {
            return !hasAnyRecordedActivity
                ? "This session’s activity starts here."
                : "This session’s work is adding up."
        }

        return !hasAnyRecordedActivity
            ? "Your generated activity starts here."
            : "Your generated learning is adding up."
    }

    private var progressSummary: String {
        guard hasAnyRecordedActivity else {
            return "Generate an article and quiz, then read or practice to create activity evidence. No mastery score is guessed."
        }

        let storageStatement = isTemporarySession
            ? "This temporary activity disappears when the app closes."
            : "This activity is stored on this iPhone."
        return "You have \(generatedArtifacts.count) generated pair\(generatedArtifacts.count == 1 ? "" : "s"), \(generatedArticleReadCount) article\(generatedArticleReadCount == 1 ? "" : "s") read, and \(generatedAttemptCount) quiz attempt\(generatedAttemptCount == 1 ? "" : "s"). \(storageStatement) Generated answer-key matches are not verified correctness or mastery."
    }

    private var evidenceOverview: some View {
        LearningCard {
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.medium
            ) {
                Text("Generated learning activity")
                    .font(StudioTokens.Typography.title)
                    .accessibilityAddTraits(.isHeader)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: StudioTokens.Spacing.large) {
                        summaryValues
                    }

                    VStack(
                        alignment: .leading,
                        spacing: StudioTokens.Spacing.small
                    ) {
                        summaryValues
                    }
                }

                Text(
                    "Retired authored lessons and quizzes are excluded from every value. Generated activity remains separate from curriculum mastery."
                )
                .font(StudioTokens.Typography.supporting)
                .foregroundStyle(StudioTokens.Color.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var summaryValues: some View {
        EvidenceValue(
            value: "\(generatedArtifacts.count)",
            label: "Generated pairs",
            symbol: "sparkles.rectangle.stack",
            accessibilityIdentifier: "progress.generated-pairs"
        )
        EvidenceValue(
            value: "\(generatedArticleReadCount)",
            label: "Articles read",
            symbol: "book.pages",
            accessibilityIdentifier: "progress.articles-read"
        )
        EvidenceValue(
            value: "\(generatedAttemptCount)",
            label: "Quiz attempts",
            symbol: "arrow.counterclockwise",
            accessibilityIdentifier: "progress.generated-attempts"
        )
        EvidenceValue(
            value: "\(answerKeyMatchCount)",
            label: "Answer-key matches",
            symbol: "checkmark.circle",
            accessibilityIdentifier: "progress.answer-key-matches"
        )
    }

    @ViewBuilder
    private var recentEvidence: some View {
        VStack(
            alignment: .leading,
            spacing: StudioTokens.Spacing.small
        ) {
            Text("Recent generated quiz attempts")
                .font(StudioTokens.Typography.title)
                .accessibilityAddTraits(.isHeader)

            if recentAttempts.isEmpty {
                LearningCard {
                    Label(
                        "No generated quiz attempts yet",
                        systemImage: "tray"
                    )
                    .font(StudioTokens.Typography.body)
                    .foregroundStyle(StudioTokens.Color.secondaryText)
                }
            } else {
                ForEach(recentAttempts) { attempt in
                    if let artifact = artifactsByQuizID[
                        attempt.challengeID
                    ] {
                        GeneratedAttemptEvidenceRow(
                            attempt: attempt,
                            artifact: artifact
                        )
                    }
                }
            }
        }
    }
}

private struct EvidenceValue: View {
    let value: String
    let label: String
    let symbol: String
    let accessibilityIdentifier: String

    var body: some View {
        HStack(spacing: StudioTokens.Spacing.xSmall) {
            Image(systemName: symbol)
                .foregroundStyle(StudioTokens.Color.action)
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(value)
                    .font(StudioTokens.Typography.title)
                    .foregroundStyle(StudioTokens.Color.primaryText)

                Text(label)
                    .font(StudioTokens.Typography.caption)
                    .foregroundStyle(StudioTokens.Color.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct GeneratedAttemptEvidenceRow: View {
    let attempt: ChallengeAttempt
    let artifact: GeneratedLearningArtifact

    private var matchesAnswerKey: Bool {
        attempt.selectedChoiceID == artifact.quiz.answerKeyChoiceID
    }

    var body: some View {
        LearningCard {
            HStack(alignment: .top, spacing: StudioTokens.Spacing.small) {
                Image(
                    systemName: matchesAnswerKey
                        ? "checkmark.circle.fill"
                        : "xmark.circle.fill"
                )
                .foregroundStyle(StudioTokens.Color.primaryText)
                .accessibilityHidden(true)

                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.xxSmall
                ) {
                    Text(artifact.article.title)
                        .font(StudioTokens.Typography.sectionHeading)
                        .foregroundStyle(StudioTokens.Color.primaryText)

                    Text(
                        matchesAnswerKey
                            ? "Matches the generated answer key"
                            : "Different from the generated answer key"
                    )
                    .font(StudioTokens.Typography.supporting)
                    .foregroundStyle(StudioTokens.Color.secondaryText)

                    LearningBadge(
                        "Experimental activity; not mastery",
                        symbol: "flask",
                        role: .warning
                    )

                    Text(
                        attempt.attemptedAt.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                    .font(StudioTokens.Typography.codeCaption)
                    .foregroundStyle(StudioTokens.Color.secondaryText)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(
                "progress.attempt.\(attempt.id.uuidString.lowercased())"
            )
        }
    }
}
