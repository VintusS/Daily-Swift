import Foundation

protocol SourceLibraryServing: Sendable {
    func restore() async throws -> SourceLibrarySnapshot
    func importSource(_ request: SourceImportRequest) async throws
        -> SourceDocument
    func resolve(_ citation: SourceCitation) async throws
        -> ResolvedSourceCitation
    func delete(sourceID: UUID) async throws
}

actor SourceLibraryService: SourceLibraryServing {
    static let maximumFileByteCount = 5 * 1_024 * 1_024

    private let metadataStore: any SourceLibraryMetadataStoring
    private let rootURL: URL
    private let now: @Sendable () -> Date
    private let makeSourceID: @Sendable () -> UUID
    private let fileManager = FileManager.default

    init(
        metadataStore: any SourceLibraryMetadataStoring,
        rootURL: URL,
        now: @escaping @Sendable () -> Date = { .now },
        makeSourceID: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.metadataStore = metadataStore
        self.rootURL = rootURL
        self.now = now
        self.makeSourceID = makeSourceID
    }

    func restore() async throws -> SourceLibrarySnapshot {
        try cleanInterruptedFileOperations()
        return try await metadataStore.restore()
    }

    func importSource(
        _ request: SourceImportRequest
    ) async throws -> SourceDocument {
        let metadata = try request.metadata.validated()
        let format = try SourceDocumentFormat.detect(
            from: request.fileURL
        )
        let didStartSecurityScope = request.fileURL
            .startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScope {
                request.fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let values: URLResourceValues
        do {
            values = try request.fileURL.resourceValues(
                forKeys: [.fileSizeKey, .isRegularFileKey]
            )
        } catch {
            throw SourceLibraryFailure.unreadableFile
        }
        guard values.isRegularFile == true else {
            throw SourceLibraryFailure.unreadableFile
        }
        if let fileSize = values.fileSize,
           fileSize > Self.maximumFileByteCount {
            throw SourceLibraryFailure.fileTooLarge
        }

        let data: Data
        do {
            data = try Data(
                contentsOf: request.fileURL,
                options: .mappedIfSafe
            )
        } catch {
            throw SourceLibraryFailure.unreadableFile
        }
        guard data.count <= Self.maximumFileByteCount else {
            throw SourceLibraryFailure.fileTooLarge
        }
        guard let decoded = String(data: data, encoding: .utf8) else {
            throw SourceLibraryFailure.invalidEncoding
        }

        let normalizedText = SourceTextProcessor.normalize(decoded)
        guard !normalizedText.isEmpty else {
            throw SourceLibraryFailure.emptyDocument
        }
        let sourceHash = SourceTextProcessor.contentHash(
            for: normalizedText
        )
        if let existing = try await metadataStore.document(
            contentHash: sourceHash
        ) {
            throw SourceLibraryFailure.duplicate(
                existingSourceID: existing.id
            )
        }

        let sourceID = makeSourceID()
        let chunks = SourceTextProcessor.chunks(
            sourceID: sourceID,
            sourceContentHash: sourceHash,
            normalizedText: normalizedText,
            format: format
        )
        guard !chunks.isEmpty else {
            throw SourceLibraryFailure.emptyDocument
        }

        let document = SourceDocument(
            id: sourceID,
            title: metadata.title,
            author: metadata.author,
            publisher: metadata.publisher,
            originFileName: request.fileURL.lastPathComponent,
            rightsStatus: metadata.rightsStatus,
            contentHash: sourceHash,
            importedAt: now(),
            format: format,
            byteCount: data.count
        )

        try storeFiles(
            sourceURL: request.fileURL,
            normalizedText: normalizedText,
            document: document
        )
        do {
            try await metadataStore.insert(
                document: document,
                chunks: chunks
            )
        } catch {
            try? fileManager.removeItem(
                at: directoryURL(for: sourceID)
            )
            if let failure = error as? SourceLibraryFailure {
                throw failure
            }
            throw SourceLibraryFailure.writeFailed
        }

        return document
    }

    func resolve(
        _ citation: SourceCitation
    ) async throws -> ResolvedSourceCitation {
        guard let document = try await metadataStore.document(
            id: citation.sourceID
        ),
        let chunk = try await metadataStore.chunk(
            sourceID: citation.sourceID,
            chunkID: citation.chunkID
        ) else {
            throw SourceLibraryFailure.citationMissing
        }
        guard chunk.citation == citation else {
            throw SourceLibraryFailure.citationInvalid
        }

        let normalizedText: String
        do {
            normalizedText = try String(
                contentsOf: normalizedURL(for: document.id),
                encoding: .utf8
            )
        } catch {
            throw SourceLibraryFailure.citationMissing
        }
        guard let excerpt = SourceTextProcessor.excerpt(
            from: normalizedText,
            location: citation.location
        ),
        SourceTextProcessor.contentHash(for: excerpt)
            == citation.contentHash else {
            throw SourceLibraryFailure.citationInvalid
        }

        return ResolvedSourceCitation(
            document: document,
            citation: citation,
            excerpt: excerpt
        )
    }

    func delete(sourceID: UUID) async throws {
        let liveDirectory = directoryURL(for: sourceID)
        let stagedDirectory = rootURL.appendingPathComponent(
            ".deleting-\(sourceID.uuidString.lowercased())",
            isDirectory: true
        )
        let directoryExists = fileManager.fileExists(
            atPath: liveDirectory.path
        )
        var didDeleteMetadata = false

        do {
            if fileManager.fileExists(atPath: stagedDirectory.path) {
                try fileManager.removeItem(at: stagedDirectory)
            }
            if directoryExists {
                try fileManager.moveItem(
                    at: liveDirectory,
                    to: stagedDirectory
                )
            }
            try await metadataStore.delete(sourceID: sourceID)
            didDeleteMetadata = true
            if directoryExists {
                try fileManager.removeItem(at: stagedDirectory)
            }
        } catch {
            if !didDeleteMetadata,
               directoryExists,
               fileManager.fileExists(atPath: stagedDirectory.path),
               !fileManager.fileExists(atPath: liveDirectory.path) {
                try? fileManager.moveItem(
                    at: stagedDirectory,
                    to: liveDirectory
                )
            }
            throw SourceLibraryFailure.deleteFailed
        }
    }

    private func cleanInterruptedFileOperations()
        throws(SourceLibraryFailure) {
        guard fileManager.fileExists(atPath: rootURL.path) else {
            return
        }

        do {
            let entries = try fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: nil
            )
            for entry in entries {
                let name = entry.lastPathComponent
                if name.hasPrefix(".importing-")
                    || name.hasPrefix(".deleting-") {
                    try fileManager.removeItem(at: entry)
                }
            }
        } catch {
            throw .readFailed
        }
    }

    private func storeFiles(
        sourceURL: URL,
        normalizedText: String,
        document: SourceDocument
    ) throws(SourceLibraryFailure) {
        let destinationDirectory = directoryURL(for: document.id)
        let stagingDirectory = rootURL.appendingPathComponent(
            ".importing-\(document.id.uuidString.lowercased())",
            isDirectory: true
        )

        do {
            try fileManager.createDirectory(
                at: rootURL,
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: stagingDirectory.path) {
                try fileManager.removeItem(at: stagingDirectory)
            }
            try fileManager.createDirectory(
                at: stagingDirectory,
                withIntermediateDirectories: false
            )
            let originalURL = stagingDirectory.appendingPathComponent(
                "original.\(document.format.storageExtension)"
            )
            try fileManager.copyItem(
                at: sourceURL,
                to: originalURL
            )
            try Data(normalizedText.utf8).write(
                to: stagingDirectory.appendingPathComponent(
                    "normalized.txt"
                ),
                options: .atomic
            )
            try fileManager.moveItem(
                at: stagingDirectory,
                to: destinationDirectory
            )
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            throw .writeFailed
        }
    }

    private func directoryURL(for sourceID: UUID) -> URL {
        rootURL.appendingPathComponent(
            sourceID.uuidString.lowercased(),
            isDirectory: true
        )
    }

    private func normalizedURL(for sourceID: UUID) -> URL {
        directoryURL(for: sourceID)
            .appendingPathComponent("normalized.txt")
    }
}

actor UnavailableSourceLibraryService: SourceLibraryServing {
    func restore() async throws -> SourceLibrarySnapshot {
        throw SourceLibraryFailure.initializationFailed
    }

    func importSource(
        _ request: SourceImportRequest
    ) async throws -> SourceDocument {
        throw SourceLibraryFailure.initializationFailed
    }

    func resolve(
        _ citation: SourceCitation
    ) async throws -> ResolvedSourceCitation {
        throw SourceLibraryFailure.initializationFailed
    }

    func delete(sourceID: UUID) async throws {
        throw SourceLibraryFailure.initializationFailed
    }
}
