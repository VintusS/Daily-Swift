import SwiftUI

struct TodayView: View {
    let catalog: LearningCatalog
    let evidence: LearningEvidenceSummary
    let onContinue: () -> Void
    let onOpenStep: (DailyLearningStep) -> Void
    let onPrivacy: () -> Void

    private var nextStep: DailyLearningStep? {
        catalog.dailyPlan.steps.first {
            !evidence.completedDailyStepIDs.contains($0.id)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.large
            ) {
                focusHeader

                dailyPlanCard

                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.small
                ) {
                    Text("Session steps")
                        .font(StudioTokens.Typography.title)
                        .foregroundStyle(StudioTokens.Color.primaryText)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(catalog.dailyPlan.steps) { step in
                        TodayStepRow(
                            step: step,
                            isComplete: evidence.completedDailyStepIDs
                                .contains(step.id),
                            onOpen: { onOpenStep(step) }
                        )
                    }
                }

                LearningCard {
                    VStack(
                        alignment: .leading,
                        spacing: StudioTokens.Spacing.small
                    ) {
                        Label(
                            "Ready without a connection",
                            systemImage: "wifi.slash"
                        )
                        .font(StudioTokens.Typography.sectionHeading)

                        Text(
                            "This starter session, every answer check, and your recorded evidence work entirely on device."
                        )
                        .font(StudioTokens.Typography.supporting)
                        .foregroundStyle(StudioTokens.Color.secondaryText)
                    }
                }
            }
            .frame(maxWidth: 720)
            .padding(StudioTokens.Spacing.medium)
            .padding(.bottom, StudioTokens.Spacing.large)
            .frame(maxWidth: .infinity)
        }
        .background(StudioTokens.Color.groupedCanvas)
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onPrivacy) {
                    Label("Privacy & Data", systemImage: "hand.raised")
                }
                .accessibilityIdentifier("app-shell.privacy")
            }
        }
    }

    private var focusHeader: some View {
        VStack(alignment: .leading, spacing: StudioTokens.Spacing.xSmall) {
            Text("TODAY’S FOCUS")
                .font(StudioTokens.Typography.codeCaption.weight(.bold))
                .foregroundStyle(StudioTokens.Color.primaryText)

            Text(catalog.dailyPlan.focus)
                .font(StudioTokens.Typography.display)
                .foregroundStyle(StudioTokens.Color.primaryText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("app-shell.ready")

            Text(catalog.dailyPlan.summary)
                .font(StudioTokens.Typography.body)
                .foregroundStyle(StudioTokens.Color.secondaryText)
        }
    }

    private var dailyPlanCard: some View {
        LearningCard {
            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.medium
            ) {
                HStack(alignment: .top) {
                    VStack(
                        alignment: .leading,
                        spacing: StudioTokens.Spacing.xxSmall
                    ) {
                        Text(catalog.dailyPlan.title)
                            .font(StudioTokens.Typography.title)

                        Label(
                            "\(catalog.dailyPlan.estimatedMinutes) minutes",
                            systemImage: "clock"
                        )
                        .font(StudioTokens.Typography.supporting)
                        .foregroundStyle(StudioTokens.Color.secondaryText)
                    }

                    Spacer()

                    LearningBadge(
                        nextStep == nil ? "Complete" : "Offline",
                        symbol: nextStep == nil
                            ? "checkmark.circle.fill"
                            : "arrow.down.circle",
                        role: nextStep == nil ? .success : .information
                    )
                }

                EvidenceProgressView(
                    title: "Session progress",
                    completed: evidence.completedDailyStepCount,
                    total: catalog.dailyPlan.steps.count,
                    supportingText: nextStep == nil
                        ? "Every recorded step in this starter session is complete."
                        : "Your next step is \(nextStep?.title ?? "ready")."
                )

                Button(action: onContinue) {
                    Label(
                        nextStep == nil
                            ? "Review the session"
                            : evidence.completedDailyStepCount == 0
                                ? "Start today’s session"
                                : "Continue today’s session",
                        systemImage: nextStep == nil
                            ? "arrow.counterclockwise"
                            : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudioPrimaryButtonStyle())
                .accessibilityHint(
                    nextStep == nil
                        ? "Opens the first learning step again."
                        : "Opens the next unfinished learning step."
                )
                .accessibilityIdentifier("today.continue")
            }
        }
    }
}

private struct TodayStepRow: View {
    let step: DailyLearningStep
    let isComplete: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(
                alignment: .top,
                spacing: StudioTokens.Spacing.small
            ) {
                Image(
                    systemName: isComplete
                        ? "checkmark.circle.fill"
                        : symbolName
                )
                .font(.title3)
                .foregroundStyle(StudioTokens.Color.primaryText)
                .frame(minWidth: 28, minHeight: 28)
                .accessibilityHidden(true)

                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.xxSmall
                ) {
                    Text(step.title)
                        .font(StudioTokens.Typography.sectionHeading)
                        .foregroundStyle(StudioTokens.Color.primaryText)

                    Text(step.detail)
                        .font(StudioTokens.Typography.supporting)
                        .foregroundStyle(StudioTokens.Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(
                        "\(isComplete ? "Completed" : "Not completed") · \(step.estimatedMinutes) min"
                    )
                    .font(StudioTokens.Typography.codeCaption)
                    .foregroundStyle(StudioTokens.Color.secondaryText)
                }

                Spacer(minLength: StudioTokens.Spacing.xSmall)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(StudioTokens.Color.secondaryText)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(StudioTokens.Spacing.medium)
            .background(
                StudioTokens.Color.surface,
                in: RoundedRectangle(
                    cornerRadius: StudioTokens.Radius.card,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(step.title)
        .accessibilityValue(
            "\(isComplete ? "Completed" : "Not completed"), \(step.estimatedMinutes) minutes"
        )
        .accessibilityHint("Opens this learning step.")
        .accessibilityIdentifier("today.step.\(step.id)")
    }

    private var symbolName: String {
        switch step.content {
        case .article:
            "book.pages"
        case .challenge:
            "checkmark.seal"
        }
    }
}
