import Foundation

enum LearningProgressProjector {
    static func evidence(
        catalog: LearningCatalog,
        snapshot: LearningProgressSnapshot
    ) -> LearningEvidenceSummary {
        let completedChallengeIDs = Set(
            snapshot.attempts.lazy.filter(\.isCorrect).map(\.challengeID)
        )
        let readArticleIDs = Set(
            snapshot.articleActivities.lazy.compactMap { activity in
                activity.completedAt == nil ? nil : activity.articleID
            }
        )
        let validChallengeIDs = Set(catalog.challenges.map(\.id))
        let validArticleIDs = Set(catalog.articles.map(\.id))
        let relevantAttempts = snapshot.attempts.filter {
            validChallengeIDs.contains($0.challengeID)
        }

        let completedDailyStepIDs = Set(
            catalog.dailyPlan.steps.compactMap { step in
                switch step.content {
                case let .article(identifier):
                    readArticleIDs.contains(identifier) ? step.id : nil
                case let .challenge(identifier):
                    completedChallengeIDs.contains(identifier) ? step.id : nil
                }
            }
        )

        let domains = LearningDomain.allCases.map { domain in
            let domainChallenges = catalog.challenges.filter {
                $0.domain == domain
            }
            let domainArticles = catalog.articles.filter {
                $0.domain == domain
            }
            let domainChallengeIDs = Set(domainChallenges.map(\.id))
            let domainAttempts = relevantAttempts.filter {
                domainChallengeIDs.contains($0.challengeID)
            }

            return DomainEvidenceSummary(
                domain: domain,
                completedChallenges: domainChallenges.filter {
                    completedChallengeIDs.contains($0.id)
                }.count,
                totalChallenges: domainChallenges.count,
                readArticles: domainArticles.filter {
                    readArticleIDs.contains($0.id)
                }.count,
                totalArticles: domainArticles.count,
                correctAttempts: domainAttempts.filter(\.isCorrect).count,
                totalAttempts: domainAttempts.count
            )
        }

        return LearningEvidenceSummary(
            completedChallengeIDs: completedChallengeIDs.intersection(
                validChallengeIDs
            ),
            readArticleIDs: readArticleIDs.intersection(validArticleIDs),
            totalAttempts: relevantAttempts.count,
            correctAttempts: relevantAttempts.filter(\.isCorrect).count,
            completedDailyStepIDs: completedDailyStepIDs,
            domains: domains
        )
    }
}
