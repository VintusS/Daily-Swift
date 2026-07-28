import Foundation
import Testing
@testable import DailySwift

struct SourceTextProcessorTests {
    @Test("Normalization makes equivalent line endings and Unicode stable")
    func normalizationAndHashingAreStable() {
        let decomposed = "  \r\n# Cafe\u{301}  \r\nBody\t \r\n\r\n"
        let composed = "# Café\nBody"

        let first = SourceTextProcessor.normalize(decomposed)
        let second = SourceTextProcessor.normalize(composed)

        #expect(first == second)
        #expect(
            SourceTextProcessor.contentHash(for: first)
                == SourceTextProcessor.contentHash(for: second)
        )
        #expect(
            SourceTextProcessor.contentHash(for: first)
                == "65bcb203fa9cf1a782009f6c81cc8a4aa7c607684bcd76c327a17de300f7ce4d"
        )
    }

    @Test("Markdown chunks retain heading paths and exact locations")
    func markdownHeadingAndLocations() {
        let text = """
        # Values
        Struct copies keep independent values.

        ## Mutation
        Mutating one copy does not change the other.
        """
        let normalized = SourceTextProcessor.normalize(text)
        let sourceID = UUID(
            uuidString: "55555555-5555-5555-5555-555555555555"
        )!
        let sourceHash = SourceTextProcessor.contentHash(for: normalized)

        let chunks = SourceTextProcessor.chunks(
            sourceID: sourceID,
            sourceContentHash: sourceHash,
            normalizedText: normalized,
            format: .markdown,
            targetCharacterCount: 80
        )

        #expect(chunks.count == 2)
        #expect(chunks[0].headingPath == ["Values"])
        #expect(chunks[0].location.startLine == 1)
        #expect(chunks[0].location.endLine == 2)
        #expect(chunks[1].headingPath == ["Values", "Mutation"])
        #expect(chunks[1].location.startLine == 4)
        #expect(chunks[1].location.endLine == 5)

        for chunk in chunks {
            let excerpt = SourceTextProcessor.excerpt(
                from: normalized,
                location: chunk.location
            )
            #expect(excerpt != nil)
            #expect(
                excerpt.map {
                    SourceTextProcessor.contentHash(for: $0)
                }
                    == chunk.contentHash
            )
        }
    }

    @Test("Oversized lines split deterministically at Character boundaries")
    func oversizedLineSplitsAtCharacterBoundaries() {
        let normalized = "A😀B😀C😀D"
        let sourceID = UUID(
            uuidString: "66666666-6666-6666-6666-666666666666"
        )!
        let hash = SourceTextProcessor.contentHash(for: normalized)

        let chunks = SourceTextProcessor.chunks(
            sourceID: sourceID,
            sourceContentHash: hash,
            normalizedText: normalized,
            format: .plainText,
            targetCharacterCount: 3
        )

        #expect(chunks.map(\.location.startCharacter) == [0, 3, 6])
        #expect(chunks.map(\.location.endCharacter) == [3, 6, 7])
        #expect(
            chunks.compactMap {
                SourceTextProcessor.excerpt(
                    from: normalized,
                    location: $0.location
                )
            } == ["A😀B", "😀C😀", "D"]
        )
    }

    @Test("Source metadata requires a title and normalizes optional values")
    func metadataValidation() throws {
        #expect(throws: SourceLibraryFailure.missingTitle) {
            try SourceImportMetadata(
                title: "  ",
                author: nil,
                publisher: nil,
                rightsStatus: .publicDomain
            )
            .validated()
        }

        let metadata = try SourceImportMetadata(
            title: "  Swift Notes  ",
            author: "  Ada  ",
            publisher: " ",
            rightsStatus: .permissionGranted
        )
        .validated()

        #expect(metadata.title == "Swift Notes")
        #expect(metadata.author == "Ada")
        #expect(metadata.publisher == nil)
        #expect(metadata.rightsStatus == .permissionGranted)
    }
}
