import Foundation
import SwiftData

@ModelActor
actor SwiftDataLearningProgressStore: LearningProgressStoring {
    private static let preferencesRecordID = "learning-preferences"

    func restore() async throws -> LearningProgressSnapshot {
        do {
            let attempts = try modelContext.fetch(
                FetchDescriptor<LearningChallengeAttemptRecord>()
            )
            .map(\.domainModel)
            .sorted(by: Self.attemptsAreOrdered)

            let articleActivities = try modelContext.fetch(
                FetchDescriptor<LearningArticleActivityRecord>()
            )
            .map(\.domainModel)
            .sorted { $0.articleID < $1.articleID }

            var preferencesDescriptor =
                FetchDescriptor<LearningPreferencesRecord>(
                    predicate: #Predicate { record in
                        record.recordID == "learning-preferences"
                    }
                )
            preferencesDescriptor.fetchLimit = 1
            let preferences = try modelContext.fetch(
                preferencesDescriptor
            )
            .first?
            .domainModel ?? LearningPreferences()

            return LearningProgressSnapshot(
                attempts: attempts,
                articleActivities: articleActivities,
                preferences: preferences
            )
        } catch {
            throw LearningProgressStoreFailure.readFailed
        }
    }

    func appendAttempt(_ attempt: ChallengeAttempt) async throws {
        do {
            let attemptID = attempt.id
            var descriptor =
                FetchDescriptor<LearningChallengeAttemptRecord>(
                    predicate: #Predicate { record in
                        record.attemptID == attemptID
                    }
                )
            descriptor.fetchLimit = 1

            guard try modelContext.fetch(descriptor).isEmpty else {
                return
            }

            modelContext.insert(
                LearningChallengeAttemptRecord(attempt: attempt)
            )
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw LearningProgressStoreFailure.writeFailed
        }
    }

    func updateArticleActivity(
        _ activity: ArticleActivity
    ) async throws {
        do {
            let articleID = activity.articleID
            var descriptor =
                FetchDescriptor<LearningArticleActivityRecord>(
                    predicate: #Predicate { record in
                        record.articleID == articleID
                    }
                )
            descriptor.fetchLimit = 1

            if let record = try modelContext.fetch(descriptor).first {
                record.update(with: activity)
            } else {
                modelContext.insert(
                    LearningArticleActivityRecord(activity: activity)
                )
            }

            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw LearningProgressStoreFailure.writeFailed
        }
    }

    func recordArticleOpen(
        _ activity: ArticleActivity,
        preferences: LearningPreferences
    ) async throws {
        do {
            let articleID = activity.articleID
            var activityDescriptor =
                FetchDescriptor<LearningArticleActivityRecord>(
                    predicate: #Predicate { record in
                        record.articleID == articleID
                    }
                )
            activityDescriptor.fetchLimit = 1

            if let record = try modelContext.fetch(
                activityDescriptor
            ).first {
                record.update(with: activity)
            } else {
                modelContext.insert(
                    LearningArticleActivityRecord(activity: activity)
                )
            }

            var preferencesDescriptor =
                FetchDescriptor<LearningPreferencesRecord>(
                    predicate: #Predicate { record in
                        record.recordID == "learning-preferences"
                    }
                )
            preferencesDescriptor.fetchLimit = 1

            if let record = try modelContext.fetch(
                preferencesDescriptor
            ).first {
                record.update(with: preferences)
            } else {
                modelContext.insert(
                    LearningPreferencesRecord(
                        recordID: Self.preferencesRecordID,
                        preferences: preferences
                    )
                )
            }

            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw LearningProgressStoreFailure.writeFailed
        }
    }

    func updatePreferences(
        _ preferences: LearningPreferences
    ) async throws {
        do {
            var descriptor =
                FetchDescriptor<LearningPreferencesRecord>(
                    predicate: #Predicate { record in
                        record.recordID == "learning-preferences"
                    }
                )
            descriptor.fetchLimit = 1

            if let record = try modelContext.fetch(descriptor).first {
                record.update(with: preferences)
            } else {
                modelContext.insert(
                    LearningPreferencesRecord(
                        recordID: Self.preferencesRecordID,
                        preferences: preferences
                    )
                )
            }

            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw LearningProgressStoreFailure.writeFailed
        }
    }

    func reset() async throws {
        do {
            let attempts = try modelContext.fetch(
                FetchDescriptor<LearningChallengeAttemptRecord>()
            )
            let articleActivities = try modelContext.fetch(
                FetchDescriptor<LearningArticleActivityRecord>()
            )
            let preferences = try modelContext.fetch(
                FetchDescriptor<LearningPreferencesRecord>()
            )

            attempts.forEach(modelContext.delete)
            articleActivities.forEach(modelContext.delete)
            preferences.forEach(modelContext.delete)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw LearningProgressStoreFailure.resetFailed
        }
    }

    private static func attemptsAreOrdered(
        _ first: ChallengeAttempt,
        _ second: ChallengeAttempt
    ) -> Bool {
        if first.attemptedAt == second.attemptedAt {
            return first.id.uuidString < second.id.uuidString
        }
        return first.attemptedAt < second.attemptedAt
    }
}
