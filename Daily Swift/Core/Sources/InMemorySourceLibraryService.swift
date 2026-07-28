import Foundation
import PDFKit
import UIKit

actor InMemorySourceLibraryService: SourceLibraryServing {
    private var snapshot: SourceLibrarySnapshot
    private var normalizedTextBySourceID: [UUID: String]
    private var originalFileURLBySourceID: [UUID: URL]
    private var restoreOutcomes: [Result<Void, SourceLibraryFailure>]
    private let now: @Sendable () -> Date
    private let makeSourceID: @Sendable () -> UUID
    private let pdfTextExtractor: any PDFTextExtracting

    init(
        snapshot: SourceLibrarySnapshot = .empty,
        normalizedTextBySourceID: [UUID: String] = [:],
        originalFileURLBySourceID: [UUID: URL] = [:],
        restoreOutcomes: [Result<Void, SourceLibraryFailure>] = [],
        now: @escaping @Sendable () -> Date = { .now },
        makeSourceID: @escaping @Sendable () -> UUID = UUID.init,
        pdfTextExtractor: any PDFTextExtracting = PDFKitTextExtractor()
    ) {
        self.snapshot = snapshot
        self.normalizedTextBySourceID = normalizedTextBySourceID
        self.originalFileURLBySourceID = originalFileURLBySourceID
        self.restoreOutcomes = restoreOutcomes
        self.now = now
        self.makeSourceID = makeSourceID
        self.pdfTextExtractor = pdfTextExtractor
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
        let normalizedText: String
        let pageMap: SourcePageMap?
        switch format {
        case .plainText, .markdown:
            guard let decoded = String(
                data: data,
                encoding: .utf8
            ) else {
                throw SourceLibraryFailure.invalidEncoding
            }
            normalizedText = SourceTextProcessor.normalize(decoded)
            pageMap = nil
        case .pdf:
            let normalized = SourceTextProcessor.normalize(
                extraction: try await pdfTextExtractor.extract(
                    from: request.fileURL
                )
            )
            normalizedText = normalized.text
            pageMap = normalized.pageMap
        }
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
        var chunks = SourceTextProcessor.chunks(
            sourceID: sourceID,
            sourceContentHash: contentHash,
            normalizedText: normalizedText,
            format: format
        )
        if let pageMap {
            chunks = SourceTextProcessor.addingPageLocations(
                to: chunks,
                pageMap: pageMap
            )
        }
        snapshot.documents.insert(document, at: 0)
        snapshot.chunks.append(contentsOf: chunks)
        normalizedTextBySourceID[sourceID] = normalizedText
        originalFileURLBySourceID[sourceID] =
            format == .pdf ? request.fileURL : nil
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
            excerpt: excerpt,
            originalFileURL: originalFileURLBySourceID[
                citation.sourceID
            ]
        )
    }

    func delete(sourceID: UUID) async throws {
        snapshot.documents.removeAll { $0.id == sourceID }
        snapshot.chunks.removeAll { $0.sourceID == sourceID }
        normalizedTextBySourceID[sourceID] = nil
        originalFileURLBySourceID[sourceID] = nil
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

    static let pdfSourceID = UUID(
        uuidString: "45454545-4545-4545-4545-454545454545"
    )!

    static let pdfNormalizedText = """
    Synthetic PDF page provenance
    This project-owned fixture verifies an exact offline PDF citation.
    """

    static let pdfContentHash = SourceTextProcessor.contentHash(
        for: pdfNormalizedText
    )

    static let pdfDocument = SourceDocument(
        id: pdfSourceID,
        title: "Synthetic PDF evidence",
        author: "Daily Swift Fixtures",
        publisher: nil,
        originFileName: "synthetic-pdf-evidence.pdf",
        rightsStatus: .openLicensed,
        contentHash: pdfContentHash,
        importedAt: Date(timeIntervalSince1970: 1_785_200_000),
        format: .pdf,
        byteCount: Data(pdfNormalizedText.utf8).count
    )

    static let pdfChunks = SourceTextProcessor.addingPageLocations(
        to: SourceTextProcessor.chunks(
            sourceID: pdfSourceID,
            sourceContentHash: pdfContentHash,
            normalizedText: pdfNormalizedText,
            format: .pdf
        ),
        pageMap: SourcePageMap(
            pages: [
                SourcePageSpan(
                    pageNumber: 1,
                    startCharacter: 0,
                    endCharacter: pdfNormalizedText.count
                ),
            ]
        )
    )

    static func pdfService() -> InMemorySourceLibraryService {
        let url = makeSyntheticPDF()
        return InMemorySourceLibraryService(
            snapshot: SourceLibrarySnapshot(
                documents: [pdfDocument],
                chunks: pdfChunks
            ),
            normalizedTextBySourceID: [
                pdfSourceID: pdfNormalizedText,
            ],
            originalFileURLBySourceID: [
                pdfSourceID: url,
            ]
        )
    }

    private static func makeSyntheticPDF() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "daily-swift-synthetic-source.pdf"
            )
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: 800, height: 1_100)
        )
        let image = renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(
                CGRect(x: 0, y: 0, width: 800, height: 1_100)
            )
            (
                """
                Synthetic PDF page provenance

                This project-owned fixture verifies an exact offline PDF citation.
                """ as NSString
            )
            .draw(
                in: CGRect(x: 72, y: 96, width: 656, height: 500),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 30),
                    .foregroundColor: UIColor.label,
                ]
            )
        }
        let pdf = PDFDocument()
        if let page = PDFPage(image: image) {
            pdf.insert(page, at: 0)
            _ = pdf.write(to: url)
        }
        return url
    }
}
