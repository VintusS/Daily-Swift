import SwiftUI

struct LearningProgressView: View {
    let catalog: LearningCatalog
    let snapshot: LearningProgressSnapshot
    let evidence: LearningEvidenceSummary
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
            return evidence.totalAttempts == 0
                && evidence.readArticleIDs.isEmpty
                ? "This session’s evidence starts here."
                : "This session’s work is adding up."
        }

        return evidence.totalAttempts == 0
            && evidence.readArticleIDs.isEmpty
            ? "Your evidence starts here."
            : "Your work is adding up."
    }

    private var progressSummary: String {
        guard evidence.totalAttempts > 0 || !evidence.readArticleIDs.isEmpty
        else {
            if isTemporarySession {
                return "Read an article or answer a challenge to create temporary session evidence. It will disappear when the app closes."
            }
            return "Read an article or answer a challenge to create your first saved evidence. No mastery score is guessed."
        }

        if isTemporarySession {
            return "\(evidence.correctAttempts) correct answers across \(evidence.totalAttempts) attempts, plus \(evidence.readArticleIDs.count) read articles in this temporary session. These facts are not saved and are not a mastery estimate."
        }

        return "\(evidence.correctAttempts) correct answers across \(evidence.totalAttempts) attempts, plus \(evidence.readArticleIDs.count) read articles. These are activity facts, not a mastery estimate."
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
                        )
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

    var body: some View {
        LearningCard {
            HStack(alignment: .top, spacing: StudioTokens.Spacing.small) {
                Image(
                    systemName: attempt.isCorrect
                        ? "checkmark.circle.fill"
                        : "xmark.circle.fill"
                )
                .foregroundStyle(StudioTokens.Color.primaryText)
                .accessibilityHidden(true)

                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.xxSmall
                ) {
                    Text(challenge?.title ?? "Retired challenge")
                        .font(StudioTokens.Typography.sectionHeading)
                        .foregroundStyle(StudioTokens.Color.primaryText)

                    Text(attempt.isCorrect ? "Correct answer" : "Incorrect answer")
                        .font(StudioTokens.Typography.supporting)
                        .foregroundStyle(StudioTokens.Color.secondaryText)

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
        }
    }
}
