import Foundation

enum SourceDocumentFormat: String, Codable, CaseIterable, Hashable, Sendable {
    case plainText
    case markdown

    var label: String {
        switch self {
        case .plainText:
            "Plain text"
        case .markdown:
            "Markdown"
        }
    }

    var storageExtension: String {
        switch self {
        case .plainText:
            "txt"
        case .markdown:
            "md"
        }
    }

    static func detect(from url: URL) throws(SourceLibraryFailure)
        -> SourceDocumentFormat {
        switch url.pathExtension.lowercased() {
        case "txt":
            .plainText
        case "md", "markdown":
            .markdown
        default:
            throw .unsupportedFileType
        }
    }
}

enum SourceRightsStatus: String, Codable, CaseIterable, Hashable, Identifiable,
    Sendable {
    case lawfullyPossessedPrivateCopy
    case openLicensed
    case publicDomain
    case permissionGranted

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .lawfullyPossessedPrivateCopy:
            "Lawfully possessed private copy"
        case .openLicensed:
            "Openly licensed"
        case .publicDomain:
            "Public domain"
        case .permissionGranted:
            "Permission granted"
        }
    }

    var detail: String {
        switch self {
        case .lawfullyPossessedPrivateCopy:
            "A private copy you have the right to use."
        case .openLicensed:
            "Material distributed under a license that permits this use."
        case .publicDomain:
            "Material whose copyright restrictions do not apply."
        case .permissionGranted:
            "Material the rights holder has permitted you to use."
        }
    }
}

struct SourceImportMetadata: Equatable, Sendable {
    var title: String
    var author: String?
    var publisher: String?
    var rightsStatus: SourceRightsStatus

    func validated() throws(SourceLibraryFailure) -> SourceImportMetadata {
        let cleanTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !cleanTitle.isEmpty else {
            throw .missingTitle
        }

        return SourceImportMetadata(
            title: cleanTitle,
            author: Self.cleaned(author),
            publisher: Self.cleaned(publisher),
            rightsStatus: rightsStatus
        )
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let cleanValue = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return cleanValue.isEmpty ? nil : cleanValue
    }
}

struct SourceImportRequest: Sendable {
    let fileURL: URL
    let metadata: SourceImportMetadata
}

struct SourceLocation: Codable, Equatable, Hashable, Sendable {
    let startLine: Int
    let endLine: Int
    let startCharacter: Int
    let endCharacter: Int

    var lineLabel: String {
        startLine == endLine
            ? "Line \(startLine)"
            : "Lines \(startLine)–\(endLine)"
    }

    var characterLabel: String {
        let inclusiveEnd = max(startCharacter, endCharacter - 1)
        return startCharacter == inclusiveEnd
            ? "Character \(startCharacter)"
            : "Characters \(startCharacter)–\(inclusiveEnd)"
    }
}

struct SourceDocument: Codable, Equatable, Hashable, Identifiable, Sendable {
    static let currentSchemaVersion = 1
    static let currentNormalizationVersion = 1

    let id: UUID
    let schemaVersion: Int
    let normalizationVersion: Int
    let title: String
    let author: String?
    let publisher: String?
    let originFileName: String
    let rightsStatus: SourceRightsStatus
    let localOnly: Bool
    let contentHash: String
    let importedAt: Date
    let format: SourceDocumentFormat
    let byteCount: Int

    init(
        id: UUID,
        schemaVersion: Int = Self.currentSchemaVersion,
        normalizationVersion: Int = Self.currentNormalizationVersion,
        title: String,
        author: String?,
        publisher: String?,
        originFileName: String,
        rightsStatus: SourceRightsStatus,
        localOnly: Bool = true,
        contentHash: String,
        importedAt: Date,
        format: SourceDocumentFormat,
        byteCount: Int
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.normalizationVersion = normalizationVersion
        self.title = title
        self.author = author
        self.publisher = publisher
        self.originFileName = originFileName
        self.rightsStatus = rightsStatus
        self.localOnly = localOnly
        self.contentHash = contentHash
        self.importedAt = importedAt
        self.format = format
        self.byteCount = byteCount
    }
}

struct SourceChunk: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let sourceID: UUID
    let ordinal: Int
    let headingPath: [String]
    let location: SourceLocation
    let contentHash: String
    let preview: String

    var citation: SourceCitation {
        SourceCitation(
            sourceID: sourceID,
            chunkID: id,
            headingPath: headingPath,
            location: location,
            contentHash: contentHash
        )
    }
}

struct SourceCitation: Codable, Equatable, Hashable, Sendable {
    let sourceID: UUID
    let chunkID: String
    let headingPath: [String]
    let location: SourceLocation
    let contentHash: String

    var headingLabel: String? {
        guard !headingPath.isEmpty else {
            return nil
        }
        return headingPath.joined(separator: " › ")
    }
}

struct ResolvedSourceCitation: Equatable, Sendable {
    let document: SourceDocument
    let citation: SourceCitation
    let excerpt: String
}

struct SourceLibrarySnapshot: Equatable, Sendable {
    static let empty = SourceLibrarySnapshot(
        documents: [],
        chunks: []
    )

    var documents: [SourceDocument]
    var chunks: [SourceChunk]

    func document(id: UUID) -> SourceDocument? {
        documents.first { $0.id == id }
    }

    func chunks(for sourceID: UUID) -> [SourceChunk] {
        chunks
            .filter { $0.sourceID == sourceID }
            .sorted { $0.ordinal < $1.ordinal }
    }
}

enum SourceLibraryFailure: Error, Equatable, Sendable {
    case missingTitle
    case unsupportedFileType
    case fileTooLarge
    case emptyDocument
    case invalidEncoding
    case unreadableFile
    case duplicate(existingSourceID: UUID)
    case initializationFailed
    case readFailed
    case writeFailed
    case citationMissing
    case citationInvalid
    case deleteFailed

    var title: String {
        switch self {
        case .missingTitle:
            "Title required"
        case .unsupportedFileType:
            "Unsupported source"
        case .fileTooLarge:
            "Source is too large"
        case .emptyDocument:
            "Source has no readable text"
        case .invalidEncoding:
            "Text encoding is unsupported"
        case .unreadableFile:
            "Source could not be read"
        case .duplicate:
            "Source already imported"
        case .initializationFailed:
            "Source library unavailable"
        case .readFailed:
            "Source library could not load"
        case .writeFailed:
            "Source could not be stored"
        case .citationMissing:
            "Citation is unavailable"
        case .citationInvalid:
            "Citation could not be verified"
        case .deleteFailed:
            "Source could not be deleted"
        }
    }

    var message: String {
        switch self {
        case .missingTitle:
            "Add a title before importing this source."
        case .unsupportedFileType:
            "Choose a TXT, MD, or Markdown file."
        case .fileTooLarge:
            "This first source importer accepts files up to 5 MiB."
        case .emptyDocument:
            "The selected file does not contain importable text."
        case .invalidEncoding:
            "Save the source as UTF-8 text and try again."
        case .unreadableFile:
            "Daily Swift could not access the selected file. Choose it again."
        case .duplicate:
            "An existing source has the same normalized content."
        case .initializationFailed:
            "Imported sources are temporarily unavailable. Seed articles still work offline."
        case .readFailed:
            "Daily Swift could not restore imported source metadata."
        case .writeFailed:
            "Nothing was added. Check available storage and try again."
        case .citationMissing:
            "The source or passage has been removed."
        case .citationInvalid:
            "The stored passage no longer matches its exact citation."
        case .deleteFailed:
            "Deletion could not finish. Try again to remove all remaining local data."
        }
    }
}
