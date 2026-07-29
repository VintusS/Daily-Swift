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
    static let maximumFileByteCount = 50 * 1_024 * 1_024

    private let metadataStore: any SourceLibraryMetadataStoring
    private let rootURL: URL
    private let now: @Sendable () -> Date
    private let makeSourceID: @Sendable () -> UUID
    private let pdfTextExtractor: any PDFTextExtracting
    private let fileManager = FileManager.default

    init(
        metadataStore: any SourceLibraryMetadataStoring,
        rootURL: URL,
        now: @escaping @Sendable () -> Date = { .now },
        makeSourceID: @escaping @Sendable () -> UUID = UUID.init,
        pdfTextExtractor: any PDFTextExtracting = PDFKitTextExtractor()
    ) {
        self.metadataStore = metadataStore
        self.rootURL = rootURL
        self.now = now
        self.makeSourceID = makeSourceID
        self.pdfTextExtractor = pdfTextExtractor
    }

    func restore() async throws -> SourceLibrarySnapshot {
        try cleanInterruptedFileOperations()
        let snapshot = try await metadataStore.restore()
        return try await hydratePageLocations(in: snapshot)
    }

    func importSource(
        _ request: SourceImportRequest
    ) async throws -> SourceDocument {
        let metadata = try request.metadata.validated()
        try ensureImportIsActive()
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

        let fileByteCount: Int
        if let fileSize = values.fileSize {
            fileByteCount = fileSize
        } else {
            do {
                fileByteCount = try Data(
                    contentsOf: request.fileURL,
                    options: .mappedIfSafe
                ).count
            } catch {
                throw SourceLibraryFailure.unreadableFile
            }
        }
        guard fileByteCount <= Self.maximumFileByteCount else {
            throw SourceLibraryFailure.fileTooLarge
        }

        let normalizedSource = try await normalizedSource(
            at: request.fileURL,
            format: format
        )
        try ensureImportIsActive()
        let normalizedText = normalizedSource.text
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
        var chunks = SourceTextProcessor.chunks(
            sourceID: sourceID,
            sourceContentHash: sourceHash,
            normalizedText: normalizedText,
            format: format
        )
        if let pageMap = normalizedSource.pageMap {
            chunks = SourceTextProcessor.addingPageLocations(
                to: chunks,
                pageMap: pageMap
            )
        }
        guard !chunks.isEmpty else {
            throw SourceLibraryFailure.emptyDocument
        }
        try ensureImportIsActive()

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
            byteCount: fileByteCount
        )

        try storeFiles(
            sourceURL: request.fileURL,
            normalizedText: normalizedText,
            document: document,
            pageMap: normalizedSource.pageMap
        )
        do {
            try ensureImportIsActive()
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
        let resolvedChunk = try await hydratedChunk(
            chunk,
            document: document
        )
        guard resolvedChunk.citation == citation else {
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

        let storedOriginalURL: URL?
        if document.format == .pdf {
            let url = originalURL(for: document)
            guard fileManager.fileExists(atPath: url.path) else {
                throw SourceLibraryFailure.citationMissing
            }
            storedOriginalURL = url
        } else {
            storedOriginalURL = nil
        }

        return ResolvedSourceCitation(
            document: document,
            citation: citation,
            excerpt: excerpt,
            originalFileURL: storedOriginalURL
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
        document: SourceDocument,
        pageMap: SourcePageMap?
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
            if let pageMap {
                try JSONEncoder().encode(pageMap).write(
                    to: stagingDirectory.appendingPathComponent(
                        "page-map.json"
                    ),
                    options: .atomic
                )
            }
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

    private func originalURL(for document: SourceDocument) -> URL {
        directoryURL(for: document.id)
            .appendingPathComponent(
                "original.\(document.format.storageExtension)"
            )
    }

    private func pageMapURL(for sourceID: UUID) -> URL {
        directoryURL(for: sourceID)
            .appendingPathComponent("page-map.json")
    }

    private func normalizedSource(
        at url: URL,
        format: SourceDocumentFormat
    ) async throws(SourceLibraryFailure) -> NormalizedSource {
        switch format {
        case .plainText, .markdown:
            let data: Data
            do {
                data = try Data(
                    contentsOf: url,
                    options: .mappedIfSafe
                )
            } catch {
                throw .unreadableFile
            }
            guard let decoded = String(
                data: data,
                encoding: .utf8
            ) else {
                throw .invalidEncoding
            }
            return NormalizedSource(
                text: SourceTextProcessor.normalize(decoded),
                pageMap: nil
            )

        case .pdf:
            let extraction = try await pdfTextExtractor.extract(
                from: url
            )
            let normalized = SourceTextProcessor.normalize(
                extraction: extraction
            )
            return NormalizedSource(
                text: normalized.text,
                pageMap: normalized.pageMap
            )
        }
    }

    private func hydratePageLocations(
        in snapshot: SourceLibrarySnapshot
    ) async throws(SourceLibraryFailure) -> SourceLibrarySnapshot {
        var hydratedChunks = snapshot.chunks
        for document in snapshot.documents where document.format == .pdf {
            let pageMap = try await loadPageMap(for: document)
            let sourceChunks = hydratedChunks.filter {
                $0.sourceID == document.id
            }
            let replacements = Dictionary(
                uniqueKeysWithValues: SourceTextProcessor
                    .addingPageLocations(
                        to: sourceChunks,
                        pageMap: pageMap
                    )
                    .map { ($0.id, $0) }
            )
            hydratedChunks = hydratedChunks.map {
                replacements[$0.id] ?? $0
            }
        }
        return SourceLibrarySnapshot(
            documents: snapshot.documents,
            chunks: hydratedChunks
        )
    }

    private func hydratedChunk(
        _ chunk: SourceChunk,
        document: SourceDocument
    ) async throws(SourceLibraryFailure) -> SourceChunk {
        guard document.format == .pdf else {
            return chunk
        }
        let pageMap = try await loadPageMap(for: document)
        guard let hydrated = SourceTextProcessor
            .addingPageLocations(
                to: [chunk],
                pageMap: pageMap
            )
            .first,
            hydrated.location.pageLabel != nil else {
            throw .citationInvalid
        }
        return hydrated
    }

    private func loadPageMap(
        for document: SourceDocument
    ) async throws(SourceLibraryFailure) -> SourcePageMap {
        do {
            let data = try Data(
                contentsOf: pageMapURL(for: document.id)
            )
            let pageMap = try JSONDecoder().decode(
                SourcePageMap.self,
                from: data
            )
            let normalizedText = try String(
                contentsOf: normalizedURL(for: document.id),
                encoding: .utf8
            )
            guard pageMap.isValid(
                characterCount: normalizedText.count
            ) else {
                throw SourceLibraryFailure.readFailed
            }
            return pageMap
        } catch {
            return try await rebuildPageMap(for: document)
        }
    }

    private func rebuildPageMap(
        for document: SourceDocument
    ) async throws(SourceLibraryFailure) -> SourcePageMap {
        guard document.format == .pdf else {
            throw .readFailed
        }
        let originalURL = originalURL(for: document)
        guard fileManager.fileExists(atPath: originalURL.path) else {
            throw .readFailed
        }
        let extraction = try await pdfTextExtractor.extract(
            from: originalURL
        )
        let normalized = SourceTextProcessor.normalize(
            extraction: extraction
        )
        guard SourceTextProcessor.contentHash(for: normalized.text)
            == document.contentHash else {
            throw .readFailed
        }

        do {
            try JSONEncoder().encode(normalized.pageMap).write(
                to: pageMapURL(for: document.id),
                options: .atomic
            )
            return normalized.pageMap
        } catch {
            throw .readFailed
        }
    }

    private func ensureImportIsActive()
        throws(SourceLibraryFailure) {
        guard !Task.isCancelled else {
            throw .importCancelled
        }
    }
}

private struct NormalizedSource {
    let text: String
    let pageMap: SourcePageMap?
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
