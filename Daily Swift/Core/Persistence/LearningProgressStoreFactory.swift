import SwiftData

enum LearningProgressStoreFactory {
    static func live() -> any LearningProgressStoring {
        do {
            return SwiftDataLearningProgressStore(
                modelContainer: try makeLiveContainer()
            )
        } catch {
            return UnavailableLearningProgressStore(
                failure: .initializationFailed
            )
        }
    }

    static func inMemory() -> any LearningProgressStoring {
        do {
            return SwiftDataLearningProgressStore(
                modelContainer: try makeInMemoryContainer()
            )
        } catch {
            return UnavailableLearningProgressStore(
                failure: .initializationFailed
            )
        }
    }

    static func makeLiveContainer()
        throws(LearningProgressStoreFailure) -> ModelContainer {
        try makeContainer(isStoredInMemoryOnly: false)
    }

    static func makeInMemoryContainer()
        throws(LearningProgressStoreFailure) -> ModelContainer {
        try makeContainer(isStoredInMemoryOnly: true)
    }

    private static func makeContainer(
        isStoredInMemoryOnly: Bool
    ) throws(LearningProgressStoreFailure) -> ModelContainer {
        do {
            let schema = Schema(
                versionedSchema: LearningProgressSchemaV1.self
            )
            let configuration = ModelConfiguration(
                "DailySwiftLearningProgress",
                schema: schema,
                isStoredInMemoryOnly: isStoredInMemoryOnly,
                allowsSave: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )

            return try ModelContainer(
                for: schema,
                configurations: configuration
            )
        } catch {
            throw .initializationFailed
        }
    }
}
