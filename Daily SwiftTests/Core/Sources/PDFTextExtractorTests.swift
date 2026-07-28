import Foundation
import Darwin
import Testing
import UIKit
@testable import DailySwift

struct PDFTextExtractorTests {
    @Test("PDF normalization preserves page provenance")
    func normalizationPreservesPageProvenance() throws {
        let extraction = PDFTextExtraction(
            pages: [
                ExtractedPDFPage(
                    number: 1,
                    text: "Page one\r\nFirst fact.  "
                ),
                ExtractedPDFPage(number: 2, text: "  \n"),
                ExtractedPDFPage(
                    number: 3,
                    text: "Page three\nSecond fact."
                ),
            ]
        )

        let normalized = SourceTextProcessor.normalize(
            extraction: extraction
        )

        #expect(
            normalized.text
                == "Page one\nFirst fact.\n\nPage three\nSecond fact."
        )
        #expect(
            normalized.pageMap.pages
                == [
                    SourcePageSpan(
                        pageNumber: 1,
                        startCharacter: 0,
                        endCharacter: 20
                    ),
                    SourcePageSpan(
                        pageNumber: 3,
                        startCharacter: 22,
                        endCharacter: 45
                    ),
                ]
        )
        #expect(
            normalized.pageMap.isValid(
                characterCount: normalized.text.count
            )
        )

        let sourceID = UUID(
            uuidString: "99999999-9999-9999-9999-999999999999"
        )!
        let hash = SourceTextProcessor.contentHash(
            for: normalized.text
        )
        let chunks = SourceTextProcessor.addingPageLocations(
            to: SourceTextProcessor.chunks(
                sourceID: sourceID,
                sourceContentHash: hash,
                normalizedText: normalized.text,
                format: .pdf,
                targetCharacterCount: 24
            ),
            pageMap: normalized.pageMap
        )

        #expect(chunks.count == 2)
        #expect(chunks[0].location.pageLabel == "Page 1")
        #expect(chunks[1].location.pageLabel == "Page 3")
    }

    @Test("Selectable-text threshold distinguishes scanned documents")
    func selectableTextThreshold() {
        let enoughText = PDFTextExtraction(
            pages: [
                ExtractedPDFPage(number: 1, text: "Text"),
                ExtractedPDFPage(number: 2, text: ""),
                ExtractedPDFPage(number: 3, text: ""),
                ExtractedPDFPage(number: 4, text: ""),
                ExtractedPDFPage(number: 5, text: ""),
            ]
        )
        let tooLittleText = PDFTextExtraction(
            pages: enoughText.pages + [
                ExtractedPDFPage(number: 6, text: ""),
            ]
        )

        #expect(enoughText.hasEnoughSelectableText)
        #expect(!tooLittleText.hasEnoughSelectableText)
    }

    @Test("PDFKit extracts synthetic project-owned page text")
    func pdfKitExtraction() async throws {
        let root = try makeTemporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        let url = root.appendingPathComponent("synthetic.pdf")
        try makePDF(
            at: url,
            pageTexts: [
                "First synthetic page",
                "Second synthetic page",
            ]
        )

        let extraction = try await PDFKitTextExtractor().extract(
            from: url
        )

        #expect(extraction.pageCount == 2)
        #expect(extraction.pages[0].number == 1)
        #expect(
            extraction.pages[0].text.contains(
                "First synthetic page"
            )
        )
        #expect(extraction.pages[1].number == 2)
        #expect(
            extraction.pages[1].text.contains(
                "Second synthetic page"
            )
        )
    }

    @Test("PDFKit identifies a synthetic image-only PDF as requiring OCR")
    func imageOnlyPDFRequiresOCR() async throws {
        let root = try makeTemporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        let url = root.appendingPathComponent("image-only.pdf")
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 400, height: 600)
        )
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            UIColor.systemBlue.setFill()
            context.cgContext.fill(
                CGRect(x: 40, y: 40, width: 200, height: 200)
            )
        }

        await #expect(throws: SourceLibraryFailure.requiresOCR) {
            try await PDFKitTextExtractor().extract(from: url)
        }
    }

    @Test("PDFKit rejects a synthetic password-protected PDF")
    func encryptedPDFIsRejected() async throws {
        let root = try makeTemporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        let url = root.appendingPathComponent("locked.pdf")
        try makeEncryptedPDF(at: url)

        await #expect(throws: SourceLibraryFailure.encryptedDocument) {
            try await PDFKitTextExtractor().extract(from: url)
        }
    }

    @Test("PDFKit rejects malformed PDF data")
    func malformedPDFIsRejected() async throws {
        let root = try makeTemporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        let url = root.appendingPathComponent("malformed.pdf")
        try Data("not a PDF".utf8).write(to: url)

        await #expect(throws: SourceLibraryFailure.pdfExtractionFailed) {
            try await PDFKitTextExtractor().extract(from: url)
        }
    }

    @Test("PDFKit records bounded extraction measurements")
    func extractionMeasurements() async throws {
        let root = try makeTemporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
        }
        let fixtures = [
            (
                name: "small",
                pages: 2,
                targetBytes: 0
            ),
            (
                name: "medium",
                pages: 20,
                targetBytes: 1_024 * 1_024
            ),
            (
                name: "maximum",
                pages: 80,
                targetBytes:
                    SourceLibraryService.maximumFileByteCount - 1_024
            ),
        ]
        let extractor = PDFKitTextExtractor()
        var measurementLines: [String] = []

        for fixture in fixtures {
            let url = root.appendingPathComponent(
                "\(fixture.name).pdf"
            )
            try makePDF(
                at: url,
                pageTexts: (1...fixture.pages).map {
                    "Synthetic page \($0). Actor isolation keeps mutable state safe."
                }
            )
            try padPDF(
                at: url,
                targetByteCount: fixture.targetBytes
            )

            let bytes = try fileByteCount(at: url)
            let memoryBefore = residentMemoryBytes()
            let started = ContinuousClock.now
            let extraction = try await extractor.extract(from: url)
            let elapsed = started.duration(to: .now)
            let memoryAfter = residentMemoryBytes()
            let characters = extraction.pages.reduce(0) {
                $0 + $1.text.count
            }

            measurementLines.append(
                "fixture=\(fixture.name) bytes=\(bytes) pages=\(extraction.pageCount) characters=\(characters) seconds=\(seconds(elapsed)) resident_delta_bytes=\(signedDifference(memoryAfter, memoryBefore))"
            )
            #expect(bytes <= SourceLibraryService.maximumFileByteCount)
            #expect(extraction.pageCount == fixture.pages)
            #expect(extraction.textPageCount == fixture.pages)
        }

        Attachment.record(
            measurementLines.joined(separator: "\n"),
            named: "pdf-extraction-measurements.txt"
        )
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "DailySwiftPDFTests-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        return root
    }

    private func makePDF(
        at url: URL,
        pageTexts: [String]
    ) throws {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 400, height: 600)
        )
        try renderer.writePDF(to: url) { context in
            for text in pageTexts {
                context.beginPage()
                (text as NSString).draw(
                    in: CGRect(x: 40, y: 40, width: 320, height: 500),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 18),
                    ]
                )
            }
        }
    }

    private func padPDF(
        at url: URL,
        targetByteCount: Int
    ) throws {
        guard targetByteCount > 0 else {
            return
        }
        let size = try fileByteCount(at: url)
        guard size < targetByteCount else {
            return
        }
        let handle = try FileHandle(forWritingTo: url)
        defer {
            try? handle.close()
        }
        try handle.seekToEnd()
        try handle.write(
            contentsOf: Data(
                repeating: 0x20,
                count: targetByteCount - size
            )
        )
    }

    private func makeEncryptedPDF(
        at url: URL
    ) throws {
        let consumer = try #require(
            CGDataConsumer(url: url as CFURL)
        )
        var mediaBox = CGRect(
            x: 0,
            y: 0,
            width: 400,
            height: 600
        )
        let options: [CFString: Any] = [
            kCGPDFContextUserPassword: "daily-swift-fixture",
            kCGPDFContextOwnerPassword: "daily-swift-owner",
        ]
        let context = try #require(
            CGContext(
                consumer: consumer,
                mediaBox: &mediaBox,
                options as CFDictionary
            )
        )
        context.beginPDFPage(nil)
        context.setFillColor(UIColor.systemBlue.cgColor)
        context.fill(
            CGRect(x: 40, y: 40, width: 200, height: 200)
        )
        context.endPDFPage()
        context.closePDF()
    }

    private func residentMemoryBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size
                / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        return result == KERN_SUCCESS
            ? UInt64(info.resident_size)
            : 0
    }

    private func fileByteCount(
        at url: URL
    ) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(
            atPath: url.path
        )
        return try #require(attributes[.size] as? Int)
    }

    private func seconds(
        _ duration: ContinuousClock.Duration
    ) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    private func signedDifference(
        _ first: UInt64,
        _ second: UInt64
    ) -> Int64 {
        if first >= second {
            return Int64(min(first - second, UInt64(Int64.max)))
        }
        return -Int64(min(second - first, UInt64(Int64.max)))
    }
}
