import Foundation
import SwiftData
import Testing
@testable import DailySwift

@MainActor
struct SourceLibraryServiceTests {
    private let sourceID = UUID(
        uuidString: "77777777-7777-7777-7777-777777777777"
    )!
    private let importedAt = Date(timeIntervalSince1970: 1_785_200_000)

    @Test("Import persists metadata, files, chunks, and exact citations")
    func importRoundTripAndCitation() async throws {
        let fixture = try makeFixture()
        defer {
            try? FileManager.default.removeItem(at: fixture.temporaryRoot)
        }
        let sourceURL = fixture.temporaryRoot
            .appendingPathComponent("lesson.md")
        let sourceText = """
        # Value semantics
        A struct copy has independent stored values.

        ## Mutation
        Mutating one copy leaves the original unchanged.
        """
        try Data(sourceText.utf8).write(to: sourceURL)

        let imported = try await fixture.service.importSource(
            request(for: sourceURL)
        )
        let restored = try await fixture.service.restore()

        #expect(imported.id == sourceID)
        #expect(imported.title == "Private Swift Notes")
        #expect(imported.author == "A. Learner")
        #expect(imported.publisher == "Example Press")
        #expect(imported.originFileName == "lesson.md")
        #expect(
            imported.rightsStatus == .lawfullyPossessedPrivateCopy
        )
        #expect(imported.localOnly)
        #expect(imported.importedAt == importedAt)
        #expect(restored.documents == [imported])
        #expect(restored.chunks(for: sourceID).count == 2)

        let storedDirectory = fixture.sourceRoot
            .appendingPathComponent(
                sourceID.uuidString.lowercased(),
                isDirectory: true
            )
        #expect(
            FileManager.default.fileExists(
                atPath: storedDirectory
                    .appendingPathComponent("original.md")
                    .path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: storedDirectory
                    .appendingPathComponent("normalized.txt")
                    .path
            )
        )

        let citation = try #require(
            restored.chunks(for: sourceID).last?.citation
        )
        try FileManager.default.removeItem(at: sourceURL)
        let resolved = try await fixture.service.resolve(citation)

        #expect(resolved.document == imported)
        #expect(
            resolved.excerpt
                == "## Mutation\nMutating one copy leaves the original unchanged."
        )
        #expect(resolved.citation.location.startLine == 4)
        #expect(resolved.citation.location.endLine == 5)

        let reloaded = SourceLibraryService(
            metadataStore: SwiftDataSourceLibraryMetadataStore(
                modelContainer: fixture.container
            ),
            rootURL: fixture.sourceRoot
        )
        #expect(try await reloaded.restore() == restored)
        #expect(try await reloaded.resolve(citation) == resolved)
    }

    @Test("PDF import persists page provenance and the offline original")
    func pdfImportRoundTripAndCitation() async throws {
        let extractor = StubPDFTextExtractor(
            result: .success(
                PDFTextExtraction(
                    pages: [
                        ExtractedPDFPage(
                            number: 1,
                            text: "First page evidence."
                        ),
                        ExtractedPDFPage(
                            number: 2,
                            text: "Second page evidence."
                        ),
                    ]
                )
            )
        )
        let fixture = try makeFixture(pdfTextExtractor: extractor)
        defer {
            try? FileManager.default.removeItem(at: fixture.temporaryRoot)
        }
        let sourceURL = fixture.temporaryRoot
            .appendingPathComponent("lesson.pdf")
        try Data("%PDF synthetic fixture".utf8).write(to: sourceURL)

        let imported = try await fixture.service.importSource(
            request(for: sourceURL)
        )
        let restored = try await fixture.service.restore()
        let chunks = restored.chunks(for: imported.id)

        #expect(imported.format == .pdf)
        #expect(chunks.count == 1)
        #expect(chunks[0].location.pageLabel == "Pages 1–2")

        let storedDirectory = fixture.sourceRoot
            .appendingPathComponent(
                imported.id.uuidString.lowercased(),
                isDirectory: true
            )
        #expect(
            FileManager.default.fileExists(
                atPath: storedDirectory
                    .appendingPathComponent("original.pdf")
                    .path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: storedDirectory
                    .appendingPathComponent("page-map.json")
                    .path
            )
        )

        let citation = chunks[0].citation
        try FileManager.default.removeItem(at: sourceURL)
        let resolved = try await fixture.service.resolve(citation)

        #expect(resolved.document == imported)
        #expect(resolved.citation.location.startPage == 1)
        #expect(resolved.citation.location.endPage == 2)
        #expect(
            resolved.excerpt
                == "First page evidence.\n\nSecond page evidence."
        )
        #expect(
            resolved.originalFileURL
                == storedDirectory.appendingPathComponent("original.pdf")
        )
        let changedPageCitation = SourceCitation(
            sourceID: citation.sourceID,
            chunkID: citation.chunkID,
            headingPath: citation.headingPath,
            location: SourceLocation(
                startLine: citation.location.startLine,
                endLine: citation.location.endLine,
                startCharacter: citation.location.startCharacter,
                endCharacter: citation.location.endCharacter,
                startPage: 2,
                endPage: 2
            ),
            contentHash: citation.contentHash
        )
        await #expect(throws: SourceLibraryFailure.citationInvalid) {
            try await fixture.service.resolve(changedPageCitation)
        }

        let pageMapURL = storedDirectory.appendingPathComponent(
            "page-map.json"
        )
        let alteredPageMap = """
        {
          "extractionVersion": 1,
          "integrityHash": "invalid",
          "pages": [
            {
              "pageNumber": 9,
              "startCharacter": 0,
              "endCharacter": 20
            }
          ]
        }
        """
        try Data(alteredPageMap.utf8).write(
            to: pageMapURL,
            options: .atomic
        )
        let reloaded = SourceLibraryService(
            metadataStore: SwiftDataSourceLibraryMetadataStore(
                modelContainer: fixture.container
            ),
            rootURL: fixture.sourceRoot,
            pdfTextExtractor: extractor
        )
        #expect(try await reloaded.restore() == restored)
        #expect(
            FileManager.default.fileExists(
                atPath: storedDirectory
                    .appendingPathComponent("page-map.json")
                    .path
            )
        )
        #expect(try await reloaded.resolve(citation) == resolved)
    }

    @Test("Equivalent extracted text is a duplicate across source formats")
    func crossFormatDuplicateDetection() async throws {
        let extractor = StubPDFTextExtractor(
            result: .success(
                PDFTextExtraction(
                    pages: [
                        ExtractedPDFPage(
                            number: 1,
                            text: "Shared normalized evidence."
                        ),
                    ]
                )
            )
        )
        let fixture = try makeFixture(pdfTextExtractor: extractor)
        defer {
            try? FileManager.default.removeItem(at: fixture.temporaryRoot)
        }
        let textURL = fixture.temporaryRoot
            .appendingPathComponent("shared.txt")
        let pdfURL = fixture.temporaryRoot
            .appendingPathComponent("shared.pdf")
        try Data("Shared normalized evidence.".utf8).write(to: textURL)
        try Data("%PDF synthetic fixture".utf8).write(to: pdfURL)

        _ = try await fixture.service.importSource(
            request(for: textURL)
        )

        await #expect(
            throws: SourceLibraryFailure.duplicate(
                existingSourceID: sourceID
            )
        ) {
            try await fixture.service.importSource(
                request(for: pdfURL)
            )
        }
        #expect(
            try await fixture.service.restore().documents.count == 1
        )
    }

    @Test("Cancelling PDF extraction leaves no visible or staged source")
    func pdfExtractionCancellation() async throws {
        let fixture = try makeFixture(
            pdfTextExtractor: CancellablePDFTextExtractor()
        )
        defer {
            try? FileManager.default.removeItem(at: fixture.temporaryRoot)
        }
        let sourceURL = fixture.temporaryRoot
            .appendingPathComponent("cancel.pdf")
        try Data("%PDF synthetic fixture".utf8).write(to: sourceURL)

        let task = Task {
            try await fixture.service.importSource(
                request(for: sourceURL)
            )
        }
        await Task.yield()
        task.cancel()

        await #expect(throws: SourceLibraryFailure.importCancelled) {
            try await task.value
        }
        #expect(try await fixture.service.restore() == .empty)
        let stagedEntries = (
            try? FileManager.default.contentsOfDirectory(
                at: fixture.sourceRoot,
                includingPropertiesForKeys: nil
            )
        ) ?? []
        #expect(
            !stagedEntries.contains {
                $0.lastPathComponent.hasPrefix(".importing-")
            }
        )
    }

    @Test("PDF extraction failures leave the source library unchanged")
    func pdfExtractionFailuresAreAtomic() async throws {
        for failure in [
            SourceLibraryFailure.requiresOCR,
            .encryptedDocument,
            .pdfExtractionFailed,
        ] {
            let fixture = try makeFixture(
                pdfTextExtractor: StubPDFTextExtractor(
                    result: .failure(failure)
                )
            )
            defer {
                try? FileManager.default.removeItem(
                    at: fixture.temporaryRoot
                )
            }
            let sourceURL = fixture.temporaryRoot
                .appendingPathComponent("unavailable.pdf")
            try Data("%PDF synthetic fixture".utf8).write(to: sourceURL)

            await #expect(throws: failure) {
                try await fixture.service.importSource(
                    request(for: sourceURL)
                )
            }
            #expect(try await fixture.service.restore() == .empty)
        }
    }

    @Test("Restore removes interrupted import and deletion staging data")
    func interruptedFileOperationsAreCleaned() async throws {
        let fixture = try makeFixture()
        defer {
            try? FileManager.default.removeItem(at: fixture.temporaryRoot)
        }
        let importing = fixture.sourceRoot.appendingPathComponent(
            ".importing-orphan",
            isDirectory: true
        )
        let deleting = fixture.sourceRoot.appendingPathComponent(
            ".deleting-orphan",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: importing,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: deleting,
            withIntermediateDirectories: true
        )
        try Data("private".utf8).write(
            to: importing.appendingPathComponent("normalized.txt")
        )
        try Data("private".utf8).write(
            to: deleting.appendingPathComponent("normalized.txt")
        )

        #expect(try await fixture.service.restore() == .empty)
        #expect(
            !FileManager.default.fileExists(atPath: importing.path)
        )
        #expect(
            !FileManager.default.fileExists(atPath: deleting.path)
        )
    }

    @Test("Equivalent normalized content is rejected as a duplicate")
    func duplicateDetection() async throws {
        let fixture = try makeFixture()
        defer {
            try? FileManager.default.removeItem(at: fixture.temporaryRoot)
        }
        let firstURL = fixture.temporaryRoot
            .appendingPathComponent("first.txt")
        let secondURL = fixture.temporaryRoot
            .appendingPathComponent("second.txt")
        try Data("Café\r\nvalue   \r\n".utf8).write(to: firstURL)
        try Data("Cafe\u{301}\nvalue".utf8).write(to: secondURL)

        _ = try await fixture.service.importSource(
            request(for: firstURL)
        )

        await #expect(
            throws: SourceLibraryFailure.duplicate(
                existingSourceID: sourceID
            )
        ) {
            try await fixture.service.importSource(
                request(for: secondURL)
            )
        }
        #expect(
            try await fixture.service.restore().documents.count == 1
        )
    }

    @Test("Deletion removes source metadata, chunks, and stored files")
    func cascadingDeletion() async throws {
        let fixture = try makeFixture()
        defer {
            try? FileManager.default.removeItem(at: fixture.temporaryRoot)
        }
        let sourceURL = fixture.temporaryRoot
            .appendingPathComponent("delete-me.txt")
        try Data("One exact offline passage.".utf8).write(to: sourceURL)
        let imported = try await fixture.service.importSource(
            request(for: sourceURL)
        )
        let citation = try #require(
            try await fixture.service.restore().chunks.first?.citation
        )
        let storedDirectory = fixture.sourceRoot
            .appendingPathComponent(
                imported.id.uuidString.lowercased(),
                isDirectory: true
            )

        try await fixture.service.delete(sourceID: imported.id)

        #expect(try await fixture.service.restore() == .empty)
        #expect(
            !FileManager.default.fileExists(
                atPath: storedDirectory.path
            )
        )
        await #expect(throws: SourceLibraryFailure.citationMissing) {
            try await fixture.service.resolve(citation)
        }
    }

    @Test("Malformed, unsupported, and oversized files fail safely")
    func invalidFiles() async throws {
        let fixture = try makeFixture()
        defer {
            try? FileManager.default.removeItem(at: fixture.temporaryRoot)
        }
        let malformedURL = fixture.temporaryRoot
            .appendingPathComponent("malformed.txt")
        let unsupportedURL = fixture.temporaryRoot
            .appendingPathComponent("source.rtf")
        let oversizedURL = fixture.temporaryRoot
            .appendingPathComponent("large.txt")
        try Data([0xFF, 0xFE, 0xFF]).write(to: malformedURL)
        try Data("Text".utf8).write(to: unsupportedURL)
        try Data(
            repeating: 0x41,
            count: SourceLibraryService.maximumFileByteCount + 1
        )
        .write(to: oversizedURL)

        await #expect(throws: SourceLibraryFailure.invalidEncoding) {
            try await fixture.service.importSource(
                request(for: malformedURL)
            )
        }
        await #expect(throws: SourceLibraryFailure.unsupportedFileType) {
            try await fixture.service.importSource(
                request(for: unsupportedURL)
            )
        }
        await #expect(throws: SourceLibraryFailure.fileTooLarge) {
            try await fixture.service.importSource(
                request(for: oversizedURL)
            )
        }
        #expect(try await fixture.service.restore() == .empty)
    }

    @Test("Changed citation metadata and changed stored text fail closed")
    func invalidCitationFailsClosed() async throws {
        let fixture = try makeFixture()
        defer {
            try? FileManager.default.removeItem(at: fixture.temporaryRoot)
        }
        let sourceURL = fixture.temporaryRoot
            .appendingPathComponent("citation.txt")
        try Data("Stable passage.".utf8).write(to: sourceURL)
        let imported = try await fixture.service.importSource(
            request(for: sourceURL)
        )
        let citation = try #require(
            try await fixture.service.restore().chunks.first?.citation
        )
        let changedCitation = SourceCitation(
            sourceID: citation.sourceID,
            chunkID: citation.chunkID,
            headingPath: citation.headingPath,
            location: SourceLocation(
                startLine: 1,
                endLine: 1,
                startCharacter: 1,
                endCharacter: citation.location.endCharacter
            ),
            contentHash: citation.contentHash
        )

        await #expect(throws: SourceLibraryFailure.citationInvalid) {
            try await fixture.service.resolve(changedCitation)
        }

        let normalizedURL = fixture.sourceRoot
            .appendingPathComponent(
                imported.id.uuidString.lowercased()
            )
            .appendingPathComponent("normalized.txt")
        try Data("Changed passage".utf8).write(
            to: normalizedURL,
            options: .atomic
        )

        await #expect(throws: SourceLibraryFailure.citationInvalid) {
            try await fixture.service.resolve(citation)
        }
    }

    private func request(for url: URL) -> SourceImportRequest {
        SourceImportRequest(
            fileURL: url,
            metadata: SourceImportMetadata(
                title: "Private Swift Notes",
                author: "A. Learner",
                publisher: "Example Press",
                rightsStatus: .lawfullyPossessedPrivateCopy
            )
        )
    }

    private func makeFixture(
        pdfTextExtractor: any PDFTextExtracting = PDFKitTextExtractor()
    ) throws -> (
        service: SourceLibraryService,
        container: ModelContainer,
        temporaryRoot: URL,
        sourceRoot: URL
    ) {
        let container = try SourceLibraryStoreFactory
            .makeInMemoryContainer()
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "DailySwiftSourceTests-\(UUID().uuidString)",
                isDirectory: true
            )
        let sourceRoot = temporaryRoot.appendingPathComponent(
            "Sources",
            isDirectory: true
        )
        let fixedImportedAt = importedAt
        let fixedSourceID = sourceID
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: true
        )
        let service = SourceLibraryService(
            metadataStore: SwiftDataSourceLibraryMetadataStore(
                modelContainer: container
            ),
            rootURL: sourceRoot,
            now: { fixedImportedAt },
            makeSourceID: { fixedSourceID },
            pdfTextExtractor: pdfTextExtractor
        )
        return (service, container, temporaryRoot, sourceRoot)
    }
}

private struct StubPDFTextExtractor: PDFTextExtracting {
    let result: Result<PDFTextExtraction, SourceLibraryFailure>

    func extract(
        from url: URL
    ) async throws(SourceLibraryFailure) -> PDFTextExtraction {
        try result.get()
    }
}

private struct CancellablePDFTextExtractor: PDFTextExtracting {
    func extract(
        from url: URL
    ) async throws(SourceLibraryFailure) -> PDFTextExtraction {
        while !Task.isCancelled {
            await Task.yield()
        }
        throw .importCancelled
    }
}
