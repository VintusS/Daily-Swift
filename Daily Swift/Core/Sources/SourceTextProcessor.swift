import CryptoKit
import Foundation

enum SourceTextProcessor {
    static let targetChunkCharacterCount = 1_200

    static func normalize(_ source: String) -> String {
        let lineNormalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .precomposedStringWithCanonicalMapping
        var lines = lineNormalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { trimTrailingHorizontalWhitespace(String($0)) }

        while lines.first?.isEmpty == true {
            lines.removeFirst()
        }
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }

        return lines.joined(separator: "\n")
    }

    static func contentHash(for text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func chunks(
        sourceID: UUID,
        sourceContentHash: String,
        normalizedText: String,
        format: SourceDocumentFormat,
        targetCharacterCount: Int = targetChunkCharacterCount
    ) -> [SourceChunk] {
        guard targetCharacterCount > 0,
              !normalizedText.isEmpty else {
            return []
        }

        let characters = Array(normalizedText)
        let lines = makeLines(from: characters)
        var headingLevels: [Int: String] = [:]
        var currentHeadingPath: [String] = []
        var chunks: [SourceChunk] = []
        var pending: PendingChunk?

        func appendChunk(
            start: Int,
            end: Int,
            startLine: Int,
            endLine: Int,
            headingPath: [String]
        ) {
            guard start < end else {
                return
            }
            let excerpt = String(characters[start..<end])
            let ordinal = chunks.count
            let chunkHash = contentHash(for: excerpt)
            chunks.append(
                SourceChunk(
                    id: "\(sourceContentHash)-\(start)-\(end)",
                    sourceID: sourceID,
                    ordinal: ordinal,
                    headingPath: headingPath,
                    location: SourceLocation(
                        startLine: startLine,
                        endLine: endLine,
                        startCharacter: start,
                        endCharacter: end
                    ),
                    contentHash: chunkHash,
                    preview: preview(for: excerpt)
                )
            )
        }

        func flushPending() {
            guard let pending else {
                return
            }
            appendChunk(
                start: pending.start,
                end: pending.end,
                startLine: pending.startLine,
                endLine: pending.endLine,
                headingPath: pending.headingPath
            )
        }

        for line in lines {
            let heading = format == .markdown
                ? markdownHeading(in: line.text)
                : nil

            if let heading {
                flushPending()
                pending = nil
                headingLevels = headingLevels.filter {
                    $0.key < heading.level
                }
                headingLevels[heading.level] = heading.title
                currentHeadingPath = headingLevels
                    .keys
                    .sorted()
                    .compactMap { headingLevels[$0] }
            }

            guard !line.text.isEmpty else {
                continue
            }

            if line.end - line.start > targetCharacterCount {
                flushPending()
                pending = nil
                var segmentStart = line.start
                while segmentStart < line.end {
                    let segmentEnd = min(
                        segmentStart + targetCharacterCount,
                        line.end
                    )
                    appendChunk(
                        start: segmentStart,
                        end: segmentEnd,
                        startLine: line.number,
                        endLine: line.number,
                        headingPath: currentHeadingPath
                    )
                    segmentStart = segmentEnd
                }
                continue
            }

            if let current = pending {
                let changesHeading = current.headingPath
                    != currentHeadingPath
                let candidateCount = line.end - current.start
                if changesHeading
                    || candidateCount > targetCharacterCount {
                    flushPending()
                    pending = PendingChunk(
                        start: line.start,
                        end: line.end,
                        startLine: line.number,
                        endLine: line.number,
                        headingPath: currentHeadingPath
                    )
                } else {
                    pending = PendingChunk(
                        start: current.start,
                        end: line.end,
                        startLine: current.startLine,
                        endLine: line.number,
                        headingPath: current.headingPath
                    )
                }
            } else {
                pending = PendingChunk(
                    start: line.start,
                    end: line.end,
                    startLine: line.number,
                    endLine: line.number,
                    headingPath: currentHeadingPath
                )
            }
        }

        flushPending()
        return chunks
    }

    static func excerpt(
        from normalizedText: String,
        location: SourceLocation
    ) -> String? {
        let characters = Array(normalizedText)
        guard location.startCharacter >= 0,
              location.endCharacter <= characters.count,
              location.startCharacter < location.endCharacter else {
            return nil
        }
        return String(
            characters[
                location.startCharacter..<location.endCharacter
            ]
        )
    }

    private static func trimTrailingHorizontalWhitespace(
        _ line: String
    ) -> String {
        var result = line
        while result.last == " " || result.last == "\t" {
            result.removeLast()
        }
        return result
    }

    private static func makeLines(
        from characters: [Character]
    ) -> [SourceLine] {
        var lines: [SourceLine] = []
        var start = 0
        var lineNumber = 1

        for (offset, character) in characters.enumerated()
            where character == "\n" {
            lines.append(
                SourceLine(
                    number: lineNumber,
                    start: start,
                    end: offset,
                    text: String(characters[start..<offset])
                )
            )
            start = offset + 1
            lineNumber += 1
        }

        lines.append(
            SourceLine(
                number: lineNumber,
                start: start,
                end: characters.count,
                text: String(characters[start..<characters.count])
            )
        )
        return lines
    }

    private static func markdownHeading(
        in line: String
    ) -> (level: Int, title: String)? {
        let characters = Array(line)
        var level = 0
        while level < characters.count,
              level < 6,
              characters[level] == "#" {
            level += 1
        }

        guard level > 0,
              level < characters.count,
              characters[level] == " " else {
            return nil
        }

        let title = String(characters[(level + 1)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return nil
        }
        return (level, title)
    }

    private static func preview(for excerpt: String) -> String {
        let compact = excerpt
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard compact.count > 180 else {
            return compact
        }
        return String(compact.prefix(177)) + "…"
    }
}

private struct SourceLine {
    let number: Int
    let start: Int
    let end: Int
    let text: String
}

private struct PendingChunk {
    let start: Int
    let end: Int
    let startLine: Int
    let endLine: Int
    let headingPath: [String]
}
