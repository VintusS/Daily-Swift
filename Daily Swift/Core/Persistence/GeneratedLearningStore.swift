import Foundation

protocol GeneratedLearningStoring: Sendable {
    func restore() async throws -> [GeneratedLearningArtifact]
    func save(_ artifact: GeneratedLearningArtifact) async throws
    func deleteArtifact(id: UUID) async throws
    func deleteArtifacts(referencing sourceID: UUID) async throws
}

actor FileGeneratedLearningStore: GeneratedLearningStoring {
    private enum UnreadableArtifactPolicy {
        case preserveAndFail
        case deleteForSourcePrivacy
    }

    private let rootURL: URL
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let postWriteCheckpoint: @Sendable () async -> Void

    init(
        rootURL: URL,
        postWriteCheckpoint: @escaping @Sendable () async -> Void = {}
    ) {
        self.rootURL = rootURL
        self.postWriteCheckpoint = postWriteCheckpoint
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func restore() async throws -> [GeneratedLearningArtifact] {
        try ensureRootExists()
        return try restoreArtifacts(
            unreadablePolicy: .preserveAndFail
        )
    }

    private func restoreArtifacts(
        unreadablePolicy: UnreadableArtifactPolicy
    ) throws -> [GeneratedLearningArtifact] {
        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw GeneratedLearningStoreFailure.readFailed
        }

        var artifacts: [GeneratedLearningArtifact] = []
        for url in urls
            .filter({ $0.pathExtension.lowercased() == "json" })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let artifact = try restoreArtifact(
                at: url,
                unreadablePolicy: unreadablePolicy
            ) else {
                continue
            }
            artifacts.append(artifact)
        }

        return artifacts.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func save(_ artifact: GeneratedLearningArtifact) async throws {
        try Task.checkCancellation()
        guard artifact.schemaVersion
            == GeneratedLearningArtifact.currentSchemaVersion else {
            throw GeneratedLearningStoreFailure.unsupportedSchema
        }
        try ensureRootExists()
        let data: Data
        do {
            data = try encoder.encode(artifact)
        } catch {
            throw GeneratedLearningStoreFailure.writeFailed
        }

        try Task.checkCancellation()
        let url = artifactURL(id: artifact.id)
        let previousData: Data?
        if fileManager.fileExists(atPath: url.path) {
            do {
                previousData = try Data(
                    contentsOf: url,
                    options: .mappedIfSafe
                )
            } catch {
                throw GeneratedLearningStoreFailure.writeFailed
            }
        } else {
            previousData = nil
        }

        do {
            try data.write(
                to: url,
                options: [.atomic]
            )
            await postWriteCheckpoint()
            try Task.checkCancellation()
        } catch is CancellationError {
            try rollbackSave(at: url, previousData: previousData)
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                try rollbackSave(at: url, previousData: previousData)
                throw CancellationError()
            }
            throw GeneratedLearningStoreFailure.writeFailed
        }
    }

    func deleteArtifact(id: UUID) async throws {
        try ensureRootExists()
        try removeArtifactFile(at: artifactURL(id: id))
    }

    func deleteArtifacts(referencing sourceID: UUID) async throws {
        try ensureRootExists()
        let artifacts = try restoreArtifacts(
            unreadablePolicy: .deleteForSourcePrivacy
        )
        let targets = artifacts.filter { $0.references(sourceID: sourceID) }
        for artifact in targets {
            try removeArtifactFile(at: artifactURL(id: artifact.id))
        }

        // Quarantined or unreadable bytes cannot prove that they do not cite
        // the source being deleted, so explicit source deletion removes them.
        try removeQuarantinedArtifacts()
    }

    private func restoreArtifact(
        at url: URL,
        unreadablePolicy: UnreadableArtifactPolicy
    ) throws -> GeneratedLearningArtifact? {
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            switch unreadablePolicy {
            case .preserveAndFail:
                throw GeneratedLearningStoreFailure.readFailed
            case .deleteForSourcePrivacy:
                try removeArtifactFile(at: url)
                return nil
            }
        }

        let artifact: GeneratedLearningArtifact
        do {
            artifact = try decoder.decode(
                GeneratedLearningArtifact.self,
                from: data
            )
        } catch {
            try quarantineArtifactFile(at: url)
            return nil
        }

        guard artifact.schemaVersion
            == GeneratedLearningArtifact.currentSchemaVersion else {
            try quarantineArtifactFile(at: url)
            return nil
        }
        return artifact
    }

    private func quarantineArtifactFile(at url: URL) throws {
        let directoryURL = quarantineURL
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            var destinationURL = directoryURL.appendingPathComponent(
                url.lastPathComponent,
                isDirectory: false
            )
            if fileManager.fileExists(atPath: destinationURL.path) {
                let quarantineName = [
                    UUID().uuidString.lowercased(),
                    url.lastPathComponent,
                ].joined(separator: "-")
                destinationURL = directoryURL.appendingPathComponent(
                    quarantineName,
                    isDirectory: false
                )
            }
            try fileManager.moveItem(at: url, to: destinationURL)
        } catch {
            throw GeneratedLearningStoreFailure.deleteFailed
        }
    }

    private func removeQuarantinedArtifacts() throws {
        do {
            if fileManager.fileExists(atPath: quarantineURL.path) {
                try fileManager.removeItem(at: quarantineURL)
            }
        } catch {
            throw GeneratedLearningStoreFailure.deleteFailed
        }
    }

    private func removeArtifactFile(at url: URL) throws {
        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        } catch {
            throw GeneratedLearningStoreFailure.deleteFailed
        }
    }

    private func rollbackSave(
        at url: URL,
        previousData: Data?
    ) throws {
        if let previousData {
            do {
                try previousData.write(to: url, options: [.atomic])
            } catch {
                throw GeneratedLearningStoreFailure.writeFailed
            }
        } else {
            try removeArtifactFile(at: url)
        }
    }

    private func ensureRootExists() throws {
        do {
            try fileManager.createDirectory(
                at: rootURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw GeneratedLearningStoreFailure.initializationFailed
        }
    }

    private func artifactURL(id: UUID) -> URL {
        rootURL.appendingPathComponent(
            "\(id.uuidString.lowercased()).json",
            isDirectory: false
        )
    }

    private var quarantineURL: URL {
        rootURL.appendingPathComponent(
            ".quarantine",
            isDirectory: true
        )
    }
}

actor InMemoryGeneratedLearningStore: GeneratedLearningStoring {
    private var artifacts: [GeneratedLearningArtifact]
    private var restoreOutcomes: [
        Result<Void, GeneratedLearningStoreFailure>
    ]
    private var writeOutcomes: [
        Result<Void, GeneratedLearningStoreFailure>
    ]
    private var deleteOutcomes: [
        Result<Void, GeneratedLearningStoreFailure>
    ]

    init(
        artifacts: [GeneratedLearningArtifact] = [],
        restoreOutcomes: [
            Result<Void, GeneratedLearningStoreFailure>
        ] = [],
        writeOutcomes: [
            Result<Void, GeneratedLearningStoreFailure>
        ] = [],
        deleteOutcomes: [
            Result<Void, GeneratedLearningStoreFailure>
        ] = []
    ) {
        self.artifacts = artifacts
        self.restoreOutcomes = restoreOutcomes
        self.writeOutcomes = writeOutcomes
        self.deleteOutcomes = deleteOutcomes
    }

    func restore() async throws -> [GeneratedLearningArtifact] {
        try consume(&restoreOutcomes)
        return artifacts.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func save(_ artifact: GeneratedLearningArtifact) async throws {
        try Task.checkCancellation()
        try consume(&writeOutcomes)
        try Task.checkCancellation()
        artifacts.removeAll { $0.id == artifact.id }
        artifacts.append(artifact)
    }

    func deleteArtifact(id: UUID) async throws {
        try consume(&deleteOutcomes)
        artifacts.removeAll { $0.id == id }
    }

    func deleteArtifacts(referencing sourceID: UUID) async throws {
        try consume(&deleteOutcomes)
        artifacts.removeAll { $0.references(sourceID: sourceID) }
    }

    private func consume(
        _ outcomes: inout [Result<Void, GeneratedLearningStoreFailure>]
    ) throws {
        guard !outcomes.isEmpty else {
            return
        }
        try outcomes.removeFirst().get()
    }
}

#if DEBUG
actor DelayedSaveGeneratedLearningStore: GeneratedLearningStoring {
    private let base: any GeneratedLearningStoring
    private let delay: Duration

    init(
        base: any GeneratedLearningStoring,
        delay: Duration
    ) {
        self.base = base
        self.delay = delay
    }

    func restore() async throws -> [GeneratedLearningArtifact] {
        try await base.restore()
    }

    func save(_ artifact: GeneratedLearningArtifact) async throws {
        let delayTask = Task.detached { [delay] in
            try? await Task.sleep(for: delay)
        }
        await delayTask.value
        try await base.save(artifact)
    }

    func deleteArtifact(id: UUID) async throws {
        try await base.deleteArtifact(id: id)
    }

    func deleteArtifacts(referencing sourceID: UUID) async throws {
        try await base.deleteArtifacts(referencing: sourceID)
    }
}
#endif

actor UnavailableGeneratedLearningStore: GeneratedLearningStoring {
    private let failure: GeneratedLearningStoreFailure

    init(failure: GeneratedLearningStoreFailure) {
        self.failure = failure
    }

    func restore() async throws -> [GeneratedLearningArtifact] {
        throw failure
    }

    func save(_ artifact: GeneratedLearningArtifact) async throws {
        throw failure
    }

    func deleteArtifact(id: UUID) async throws {
        throw failure
    }

    func deleteArtifacts(referencing sourceID: UUID) async throws {
        throw failure
    }
}
