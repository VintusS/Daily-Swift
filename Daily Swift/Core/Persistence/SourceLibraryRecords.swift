import Foundation
import SwiftData

enum SourceLibrarySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SourceDocumentRecord.self,
            SourceChunkRecord.self,
        ]
    }
}

@Model
final class SourceDocumentRecord {
    @Attribute(.unique) var sourceID: UUID
    @Attribute(.unique) var contentHash: String
    var schemaVersion: Int
    var normalizationVersion: Int
    var title: String
    var author: String?
    var publisher: String?
    var originFileName: String
    var rightsStatusIdentifier: String
    var localOnly: Bool
    var importedAt: Date
    var formatIdentifier: String
    var byteCount: Int

    init(document: SourceDocument) {
        sourceID = document.id
        contentHash = document.contentHash
        schemaVersion = document.schemaVersion
        normalizationVersion = document.normalizationVersion
        title = document.title
        author = document.author
        publisher = document.publisher
        originFileName = document.originFileName
        rightsStatusIdentifier = document.rightsStatus.rawValue
        localOnly = document.localOnly
        importedAt = document.importedAt
        formatIdentifier = document.format.rawValue
        byteCount = document.byteCount
    }

    func domainModel() throws -> SourceDocument {
        guard let rightsStatus = SourceRightsStatus(
            rawValue: rightsStatusIdentifier
        ),
        let format = SourceDocumentFormat(
            rawValue: formatIdentifier
        ) else {
            throw SourceLibraryFailure.readFailed
        }

        return SourceDocument(
            id: sourceID,
            schemaVersion: schemaVersion,
            normalizationVersion: normalizationVersion,
            title: title,
            author: author,
            publisher: publisher,
            originFileName: originFileName,
            rightsStatus: rightsStatus,
            localOnly: localOnly,
            contentHash: contentHash,
            importedAt: importedAt,
            format: format,
            byteCount: byteCount
        )
    }
}

@Model
final class SourceChunkRecord {
    @Attribute(.unique) var chunkID: String
    var sourceID: UUID
    var ordinal: Int
    var headingPathData: Data
    var startLine: Int
    var endLine: Int
    var startCharacter: Int
    var endCharacter: Int
    var contentHash: String
    var preview: String

    init(chunk: SourceChunk) {
        chunkID = chunk.id
        sourceID = chunk.sourceID
        ordinal = chunk.ordinal
        headingPathData = (
            try? JSONEncoder().encode(chunk.headingPath)
        ) ?? Data("[]".utf8)
        startLine = chunk.location.startLine
        endLine = chunk.location.endLine
        startCharacter = chunk.location.startCharacter
        endCharacter = chunk.location.endCharacter
        contentHash = chunk.contentHash
        preview = chunk.preview
    }

    func domainModel() throws -> SourceChunk {
        let headingPath = try JSONDecoder().decode(
            [String].self,
            from: headingPathData
        )
        return SourceChunk(
            id: chunkID,
            sourceID: sourceID,
            ordinal: ordinal,
            headingPath: headingPath,
            location: SourceLocation(
                startLine: startLine,
                endLine: endLine,
                startCharacter: startCharacter,
                endCharacter: endCharacter
            ),
            contentHash: contentHash,
            preview: preview
        )
    }
}
