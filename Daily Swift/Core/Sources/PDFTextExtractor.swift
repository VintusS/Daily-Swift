import Foundation
import PDFKit

struct ExtractedPDFPage: Codable, Equatable, Sendable {
    let number: Int
    let text: String
}

struct PDFTextExtraction: Codable, Equatable, Sendable {
    static let minimumTextPageRatio = 0.2

    let pages: [ExtractedPDFPage]

    var pageCount: Int {
        pages.count
    }

    var textPageCount: Int {
        pages.count {
            !$0.text.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        }
    }

    var hasEnoughSelectableText: Bool {
        guard pageCount > 0,
              textPageCount > 0 else {
            return false
        }
        return Double(textPageCount) / Double(pageCount)
            >= Self.minimumTextPageRatio
    }
}

protocol PDFTextExtracting: Sendable {
    func extract(from url: URL) async throws(SourceLibraryFailure)
        -> PDFTextExtraction
}

struct PDFKitTextExtractor: PDFTextExtracting {
    func extract(
        from url: URL
    ) async throws(SourceLibraryFailure) -> PDFTextExtraction {
        guard !Task.isCancelled else {
            throw .importCancelled
        }
        guard let document = PDFDocument(url: url) else {
            throw .pdfExtractionFailed
        }
        guard !document.isLocked else {
            throw .encryptedDocument
        }
        guard document.pageCount > 0 else {
            throw .pdfExtractionFailed
        }

        var pages: [ExtractedPDFPage] = []
        pages.reserveCapacity(document.pageCount)
        for pageIndex in 0..<document.pageCount {
            guard !Task.isCancelled else {
                throw .importCancelled
            }
            guard let page = document.page(at: pageIndex) else {
                throw .pdfExtractionFailed
            }
            pages.append(
                ExtractedPDFPage(
                    number: pageIndex + 1,
                    text: page.string ?? ""
                )
            )
        }

        let extraction = PDFTextExtraction(pages: pages)
        guard extraction.hasEnoughSelectableText else {
            throw .requiresOCR
        }
        return extraction
    }
}

struct SourcePageSpan: Codable, Equatable, Sendable {
    let pageNumber: Int
    let startCharacter: Int
    let endCharacter: Int
}

struct SourcePageMap: Codable, Equatable, Sendable {
    let extractionVersion: Int
    let pages: [SourcePageSpan]
    let integrityHash: String

    init(
        extractionVersion: Int = 1,
        pages: [SourcePageSpan]
    ) {
        self.extractionVersion = extractionVersion
        self.pages = pages
        integrityHash = Self.integrityHash(
            extractionVersion: extractionVersion,
            pages: pages
        )
    }

    func pageRange(
        for location: SourceLocation
    ) -> ClosedRange<Int>? {
        let intersectingPages = pages.filter { page in
            location.startCharacter < page.endCharacter
                && location.endCharacter > page.startCharacter
        }
        guard let first = intersectingPages.first,
              let last = intersectingPages.last else {
            return nil
        }
        return first.pageNumber...last.pageNumber
    }

    func isValid(characterCount: Int) -> Bool {
        guard extractionVersion == 1,
              !pages.isEmpty,
              integrityHash == Self.integrityHash(
                  extractionVersion: extractionVersion,
                  pages: pages
              ) else {
            return false
        }

        var previousPageNumber = 0
        var previousEndCharacter = 0
        for page in pages {
            guard page.pageNumber > previousPageNumber,
                  page.startCharacter >= previousEndCharacter,
                  page.startCharacter >= 0,
                  page.startCharacter < page.endCharacter,
                  page.endCharacter <= characterCount else {
                return false
            }
            previousPageNumber = page.pageNumber
            previousEndCharacter = page.endCharacter
        }
        return true
    }

    private static func integrityHash(
        extractionVersion: Int,
        pages: [SourcePageSpan]
    ) -> String {
        let identity = (
            ["v\(extractionVersion)"]
                + pages.map {
                    "\($0.pageNumber):\($0.startCharacter):\($0.endCharacter)"
                }
        )
        .joined(separator: "|")
        return SourceTextProcessor.contentHash(for: identity)
    }
}

struct NormalizedPDFText: Equatable, Sendable {
    let text: String
    let pageMap: SourcePageMap
}

extension SourceTextProcessor {
    static func normalize(
        extraction: PDFTextExtraction
    ) -> NormalizedPDFText {
        var normalizedPages: [(number: Int, text: String)] = []
        normalizedPages.reserveCapacity(extraction.pages.count)
        for page in extraction.pages {
            normalizedPages.append(
                (
                    number: page.number,
                    text: normalize(page.text)
                )
            )
        }

        var text = ""
        var pageSpans: [SourcePageSpan] = []
        for page in normalizedPages where !page.text.isEmpty {
            if !text.isEmpty {
                text.append("\n\n")
            }
            let start = text.count
            text.append(page.text)
            pageSpans.append(
                SourcePageSpan(
                    pageNumber: page.number,
                    startCharacter: start,
                    endCharacter: text.count
                )
            )
        }

        return NormalizedPDFText(
            text: text,
            pageMap: SourcePageMap(pages: pageSpans)
        )
    }

    static func addingPageLocations(
        to chunks: [SourceChunk],
        pageMap: SourcePageMap
    ) -> [SourceChunk] {
        chunks.map { chunk in
            guard let pageRange = pageMap.pageRange(
                for: chunk.location
            ) else {
                return chunk
            }
            return SourceChunk(
                id: chunk.id,
                sourceID: chunk.sourceID,
                ordinal: chunk.ordinal,
                headingPath: chunk.headingPath,
                location: SourceLocation(
                    startLine: chunk.location.startLine,
                    endLine: chunk.location.endLine,
                    startCharacter: chunk.location.startCharacter,
                    endCharacter: chunk.location.endCharacter,
                    startPage: pageRange.lowerBound,
                    endPage: pageRange.upperBound
                ),
                contentHash: chunk.contentHash,
                preview: chunk.preview
            )
        }
    }
}
