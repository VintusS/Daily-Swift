import Foundation

enum GeneratedLearningStoreFactory {
    static func live(
        fileManager: FileManager = .default
    ) -> any GeneratedLearningStoring {
        do {
            let rootURL = try rootURL(fileManager: fileManager)
            return FileGeneratedLearningStore(rootURL: rootURL)
        } catch {
            return UnavailableGeneratedLearningStore(
                failure: .initializationFailed
            )
        }
    }

#if DEBUG
    static func uiTesting(
        reset: Bool,
        fileManager: FileManager = .default
    ) -> any GeneratedLearningStoring {
        do {
            let rootURL = try rootURL(fileManager: fileManager)
            if reset, fileManager.fileExists(atPath: rootURL.path) {
                try fileManager.removeItem(at: rootURL)
            }
            return FileGeneratedLearningStore(rootURL: rootURL)
        } catch {
            return UnavailableGeneratedLearningStore(
                failure: .initializationFailed
            )
        }
    }
#endif

    private static func rootURL(
        fileManager: FileManager
    ) throws -> URL {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return applicationSupport
            .appendingPathComponent("Daily Swift", isDirectory: true)
            .appendingPathComponent(
                "GeneratedLearning",
                isDirectory: true
            )
            .appendingPathComponent("v1", isDirectory: true)
    }
}
