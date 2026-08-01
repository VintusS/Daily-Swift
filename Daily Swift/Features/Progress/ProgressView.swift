import SwiftUI

struct LearningProgressView: View {
    let catalog: LearningCatalog
    let snapshot: LearningProgressSnapshot
    let evidence: LearningEvidenceSummary
    let generatedArtifacts: [GeneratedLearningArtifact]
    let isTemporarySession: Bool
    let onOpenPreferences: () -> Void
    let onPrivacy: () -> Void

    private var recentAttempts: [ChallengeAttempt] {
        Array(
            snapshot.attempts.sorted {
                $0.attemptedAt > $1.attemptedAt
            }.prefix(5)
        )
    }

    private var generatedAttemptCount: Int {
        snapshot.attempts.filter {
            $0.challengeID.hasPrefix("generated.quiz.")
        }.count
    }

    private var generatedArticleActivityCount: Int {
        snapshot.articleActivities.filter {
            $0.articleID.hasPrefix("generated.article.")
                && ($0.lastOpenedAt != nil
                    || $0.completedAt != nil
                    || $0.isBookmarked)
        }.count
    }

    private var hasAnyRecordedActivity: Bool {
        evidence.totalAttempts > 0
            || !evidence.readArticleIDs.isEmpty
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
                            ? "TEMPORARY SESSION EVIDENCE"
                            : "SAVED LEARNING EVIDENCE"
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

                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.small
                ) {
                    Text("By domain")
                        .font(StudioTokens.Typography.title)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(evidence.domains) { domain in
                        DomainEvidenceCard(summary: domain)
                    }
                }

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
                ? "This session’s evidence starts here."
                : "This session’s work is adding up."
        }

        return !hasAnyRecordedActivity
            ? "Your evidence starts here."
            : "Your work is adding up."
    }

    private var progressSummary: String {
        guard hasAnyRecordedActivity else {
            if isTemporarySession {
                return "Read an article or answer a challenge to create temporary session evidence. It will disappear when the app closes."
            }
            return "Read an article or answer a challenge to create your first saved evidence. No mastery score is guessed."
        }

        var parts: [String] = []
        if evidence.totalAttempts > 0 || !evidence.readArticleIDs.isEmpty {
            parts.append(
                "\(evidence.correctAttempts) correct answers across \(evidence.totalAttempts) deterministic attempts, plus \(evidence.readArticleIDs.count) reviewed articles read."
            )
        }
        if generatedAttemptCount > 0
            || generatedArticleActivityCount > 0 {
            parts.append(
                "\(generatedAttemptCount) experimental quiz attempts and \(generatedArticleActivityCount) generated article activities are recorded separately; they are not verified correctness or mastery."
            )
        }
        parts.append(
            isTemporarySession
                ? "This temporary activity disappears when the app closes and is not a mastery estimate."
                : "These are activity facts, not a mastery estimate."
        )
        return parts.joined(separator: " ")
    }

    private var evidenceOverview: some View {
        LearningCard {
            VStack(spacing: StudioTokens.Spacing.medium) {
                EvidenceProgressView(
                    title: "Starter session",
                    completed: evidence.completedDailyStepCount,
                    total: catalog.dailyPlan.steps.count,
                    supportingText: isTemporarySession
                        ? "Only evidence recorded in this temporary session completes a step until the app closes."
                        : "Only saved article and challenge evidence completes a step."
                )

                Divider()

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
            }
        }
    }

    @ViewBuilder
    private var summaryValues: some View {
        EvidenceValue(
            value: "\(evidence.correctAttempts)",
            label: "Correct answers",
            symbol: "checkmark.circle",
            accessibilityIdentifier: "progress.correct-answers"
        )
        EvidenceValue(
            value: "\(evidence.totalAttempts)",
            label: "Attempts",
            symbol: "arrow.counterclockwise",
            accessibilityIdentifier: "progress.attempts"
        )
        EvidenceValue(
            value: "\(evidence.readArticleIDs.count)",
            label: "Articles read",
            symbol: "book.pages",
            accessibilityIdentifier: "progress.articles-read"
        )
    }

    @ViewBuilder
    private var recentEvidence: some View {
        VStack(
            alignment: .leading,
            spacing: StudioTokens.Spacing.small
        ) {
            Text("Recent attempts")
                .font(StudioTokens.Typography.title)
                .accessibilityAddTraits(.isHeader)

            if recentAttempts.isEmpty {
                LearningCard {
                    Label(
                        "No challenge attempts yet",
                        systemImage: "tray"
                    )
                    .font(StudioTokens.Typography.body)
                    .foregroundStyle(StudioTokens.Color.secondaryText)
                }
            } else {
                ForEach(recentAttempts) { attempt in
                    AttemptEvidenceRow(
                        attempt: attempt,
                        challenge: catalog.challenge(
                            id: attempt.challengeID
                        ),
                        generatedArtifact: generatedArtifacts.first {
                            $0.quizID == attempt.challengeID
                        }
                    )
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

private struct DomainEvidenceCard: View {
    let summary: DomainEvidenceSummary

    var body: some View {
        LearningCard {
            HStack(
                alignment: .top,
                spacing: StudioTokens.Spacing.small
            ) {
                Image(systemName: summary.domain.symbolName)
                    .font(.title3)
                    .foregroundStyle(StudioTokens.Color.action)
                    .frame(minWidth: 30, minHeight: 30)
                    .accessibilityHidden(true)

                EvidenceProgressView(
                    title: summary.domain.title,
                    completed: summary.completedChallenges
                        + summary.readArticles,
                    total: summary.totalChallenges
                        + summary.totalArticles,
                    supportingText: "\(summary.correctAttempts) correct of \(summary.totalAttempts) attempts."
                )
            }
        }
    }
}

private struct AttemptEvidenceRow: View {
    let attempt: ChallengeAttempt
    let challenge: LearningChallenge?
    let generatedArtifact: GeneratedLearningArtifact?

    var body: some View {
        LearningCard {
            HStack(alignment: .top, spacing: StudioTokens.Spacing.small) {
                Image(
                    systemName: resultSymbolName
                )
                .foregroundStyle(StudioTokens.Color.primaryText)
                .accessibilityHidden(true)

                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.xxSmall
                ) {
                    Text(
                        challenge?.title
                            ?? generatedArtifact?.article.title
                            ?? (isGeneratedAttempt
                                ? "Unavailable generated quiz"
                                : "Retired challenge")
                    )
                        .font(StudioTokens.Typography.sectionHeading)
                        .foregroundStyle(StudioTokens.Color.primaryText)

                    Text(resultLabel)
                        .font(StudioTokens.Typography.supporting)
                        .foregroundStyle(StudioTokens.Color.secondaryText)

                    if isGeneratedAttempt {
                        LearningBadge(
                            "Experimental activity; not mastery",
                            symbol: "flask",
                            role: .warning
                        )
                    }

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

    private var resultLabel: String {
        if isGeneratedAttempt {
            guard let generatedAnswerKeyMatch else {
                return "Experimental generated answer recorded; its answer key is no longer available"
            }
            return generatedAnswerKeyMatch
                ? "Matches the generated answer key"
                : "Different from the generated answer key"
        }
        return attempt.isCorrect
            ? "Correct answer"
            : "Incorrect answer"
    }

    private var isGeneratedAttempt: Bool {
        generatedArtifact != nil
            || attempt.challengeID.hasPrefix("generated.quiz.")
    }

    private var generatedAnswerKeyMatch: Bool? {
        guard let generatedArtifact else {
            return nil
        }
        return attempt.selectedChoiceID
            == generatedArtifact.quiz.answerKeyChoiceID
    }

    private var resultSymbolName: String {
        if isGeneratedAttempt {
            guard let generatedAnswerKeyMatch else {
                return "questionmark.circle.fill"
            }
            return generatedAnswerKeyMatch
                ? "checkmark.circle.fill"
                : "xmark.circle.fill"
        }
        return attempt.isCorrect
            ? "checkmark.circle.fill"
            : "xmark.circle.fill"
    }
}
