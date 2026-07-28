import Foundation

actor InMemorySourceLibraryService: SourceLibraryServing {
    private var snapshot: SourceLibrarySnapshot
    private var normalizedTextBySourceID: [UUID: String]
    private var restoreOutcomes: [Result<Void, SourceLibraryFailure>]
    private let now: @Sendable () -> Date
    private let makeSourceID: @Sendable () -> UUID

    init(
        snapshot: SourceLibrarySnapshot = .empty,
        normalizedTextBySourceID: [UUID: String] = [:],
        restoreOutcomes: [Result<Void, SourceLibraryFailure>] = [],
        now: @escaping @Sendable () -> Date = { .now },
        makeSourceID: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.snapshot = snapshot
        self.normalizedTextBySourceID = normalizedTextBySourceID
        self.restoreOutcomes = restoreOutcomes
        self.now = now
        self.makeSourceID = makeSourceID
    }

    func restore() async throws -> SourceLibrarySnapshot {
        if !restoreOutcomes.isEmpty {
            try restoreOutcomes.removeFirst().get()
        }
        return snapshot
    }

    func importSource(
        _ request: SourceImportRequest
    ) async throws -> SourceDocument {
        let metadata = try request.metadata.validated()
        let format = try SourceDocumentFormat.detect(
            from: request.fileURL
        )
        let data: Data
        do {
            data = try Data(contentsOf: request.fileURL)
        } catch {
            throw SourceLibraryFailure.unreadableFile
        }
        guard data.count <= SourceLibraryService.maximumFileByteCount else {
            throw SourceLibraryFailure.fileTooLarge
        }
        guard let decoded = String(data: data, encoding: .utf8) else {
            throw SourceLibraryFailure.invalidEncoding
        }
        let normalizedText = SourceTextProcessor.normalize(decoded)
        guard !normalizedText.isEmpty else {
            throw SourceLibraryFailure.emptyDocument
        }
        let contentHash = SourceTextProcessor.contentHash(
            for: normalizedText
        )
        if let existing = snapshot.documents.first(where: {
            $0.contentHash == contentHash
        }) {
            throw SourceLibraryFailure.duplicate(
                existingSourceID: existing.id
            )
        }

        let sourceID = makeSourceID()
        let document = SourceDocument(
            id: sourceID,
            title: metadata.title,
            author: metadata.author,
            publisher: metadata.publisher,
            originFileName: request.fileURL.lastPathComponent,
            rightsStatus: metadata.rightsStatus,
            contentHash: contentHash,
            importedAt: now(),
            format: format,
            byteCount: data.count
        )
        let chunks = SourceTextProcessor.chunks(
            sourceID: sourceID,
            sourceContentHash: contentHash,
            normalizedText: normalizedText,
            format: format
        )
        snapshot.documents.insert(document, at: 0)
        snapshot.chunks.append(contentsOf: chunks)
        normalizedTextBySourceID[sourceID] = normalizedText
        return document
    }

    func resolve(
        _ citation: SourceCitation
    ) async throws -> ResolvedSourceCitation {
        guard let document = snapshot.document(id: citation.sourceID),
              let chunk = snapshot.chunks.first(where: {
                  $0.sourceID == citation.sourceID
                      && $0.id == citation.chunkID
              }),
              chunk.citation == citation,
              let text = normalizedTextBySourceID[citation.sourceID] else {
            throw SourceLibraryFailure.citationMissing
        }
        guard let excerpt = SourceTextProcessor.excerpt(
            from: text,
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
        snapshot.documents.removeAll { $0.id == sourceID }
        snapshot.chunks.removeAll { $0.sourceID == sourceID }
        normalizedTextBySourceID[sourceID] = nil
    }
}

enum SourceLibraryFixtures {
    static let sourceID = UUID(
        uuidString: "44444444-4444-4444-4444-444444444444"
    )!

    static let normalizedText = """
    # Actor isolation
    Actors protect mutable state through isolation.

    ## Exact citations
    A citation should reopen the passage that supports a learning claim.
    """

    static let contentHash = SourceTextProcessor.contentHash(
        for: normalizedText
    )

    static let document = SourceDocument(
        id: sourceID,
        title: "Synthetic actor notes",
        author: "Daily Swift Fixtures",
        publisher: nil,
        originFileName: "synthetic-actor-notes.md",
        rightsStatus: .openLicensed,
        contentHash: contentHash,
        importedAt: Date(timeIntervalSince1970: 1_785_200_000),
        format: .markdown,
        byteCount: Data(normalizedText.utf8).count
    )

    static let chunks = SourceTextProcessor.chunks(
        sourceID: sourceID,
        sourceContentHash: contentHash,
        normalizedText: normalizedText,
        format: .markdown
    )

    static func service() -> InMemorySourceLibraryService {
        InMemorySourceLibraryService(
            snapshot: SourceLibrarySnapshot(
                documents: [document],
                chunks: chunks
            ),
            normalizedTextBySourceID: [
                sourceID: normalizedText,
            ]
        )
    }
}
