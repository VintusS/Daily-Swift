import Foundation
import SwiftData

enum SourceLibraryStoreFactory {
    static func live() -> any SourceLibraryServing {
        do {
            let container = try makeLiveContainer()
            let metadataStore = SwiftDataSourceLibraryMetadataStore(
                modelContainer: container
            )
            return SourceLibraryService(
                metadataStore: metadataStore,
                rootURL: try makeLiveRootURL()
            )
        } catch {
            return UnavailableSourceLibraryService()
        }
    }

    static func makeLiveContainer()
        throws(SourceLibraryFailure) -> ModelContainer {
        try makeContainer(isStoredInMemoryOnly: false)
    }

    static func makeInMemoryContainer()
        throws(SourceLibraryFailure) -> ModelContainer {
        try makeContainer(isStoredInMemoryOnly: true)
    }

    static func makeLiveRootURL()
        throws(SourceLibraryFailure) -> URL {
        do {
            return try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent("DailySwift", isDirectory: true)
            .appendingPathComponent("Sources", isDirectory: true)
        } catch {
            throw .initializationFailed
        }
    }

    private static func makeContainer(
        isStoredInMemoryOnly: Bool
    ) throws(SourceLibraryFailure) -> ModelContainer {
        do {
            let schema = Schema(
                versionedSchema: SourceLibrarySchemaV1.self
            )
            let configuration = ModelConfiguration(
                "DailySwiftSourceLibrary",
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
