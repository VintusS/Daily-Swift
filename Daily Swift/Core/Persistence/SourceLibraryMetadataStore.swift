import Foundation
import SwiftData

protocol SourceLibraryMetadataStoring: Sendable {
    func restore() async throws -> SourceLibrarySnapshot
    func document(id: UUID) async throws -> SourceDocument?
    func document(contentHash: String) async throws -> SourceDocument?
    func chunk(
        sourceID: UUID,
        chunkID: String
    ) async throws -> SourceChunk?
    func insert(
        document: SourceDocument,
        chunks: [SourceChunk]
    ) async throws
    func delete(sourceID: UUID) async throws
}

@ModelActor
actor SwiftDataSourceLibraryMetadataStore:
    SourceLibraryMetadataStoring {
    func restore() async throws -> SourceLibrarySnapshot {
        do {
            let documents = try modelContext.fetch(
                FetchDescriptor<SourceDocumentRecord>()
            )
            .map { try $0.domainModel() }
            .sorted(by: Self.documentsAreOrdered)
            let chunks = try modelContext.fetch(
                FetchDescriptor<SourceChunkRecord>()
            )
            .map { try $0.domainModel() }
            .sorted(by: Self.chunksAreOrdered)
            return SourceLibrarySnapshot(
                documents: documents,
                chunks: chunks
            )
        } catch {
            throw SourceLibraryFailure.readFailed
        }
    }

    func document(id: UUID) async throws -> SourceDocument? {
        do {
            var descriptor = FetchDescriptor<SourceDocumentRecord>(
                predicate: #Predicate { record in
                    record.sourceID == id
                }
            )
            descriptor.fetchLimit = 1
            return try modelContext.fetch(descriptor)
                .first?
                .domainModel()
        } catch {
            throw SourceLibraryFailure.readFailed
        }
    }

    func document(
        contentHash: String
    ) async throws -> SourceDocument? {
        do {
            var descriptor = FetchDescriptor<SourceDocumentRecord>(
                predicate: #Predicate { record in
                    record.contentHash == contentHash
                }
            )
            descriptor.fetchLimit = 1
            return try modelContext.fetch(descriptor)
                .first?
                .domainModel()
        } catch {
            throw SourceLibraryFailure.readFailed
        }
    }

    func chunk(
        sourceID: UUID,
        chunkID: String
    ) async throws -> SourceChunk? {
        do {
            var descriptor = FetchDescriptor<SourceChunkRecord>(
                predicate: #Predicate { record in
                    record.sourceID == sourceID
                        && record.chunkID == chunkID
                }
            )
            descriptor.fetchLimit = 1
            return try modelContext.fetch(descriptor)
                .first?
                .domainModel()
        } catch {
            throw SourceLibraryFailure.readFailed
        }
    }

    func insert(
        document: SourceDocument,
        chunks: [SourceChunk]
    ) async throws {
        do {
            modelContext.insert(SourceDocumentRecord(document: document))
            for chunk in chunks {
                modelContext.insert(SourceChunkRecord(chunk: chunk))
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw SourceLibraryFailure.writeFailed
        }
    }

    func delete(sourceID: UUID) async throws {
        do {
            let documents = try modelContext.fetch(
                FetchDescriptor<SourceDocumentRecord>(
                    predicate: #Predicate { record in
                        record.sourceID == sourceID
                    }
                )
            )
            let chunks = try modelContext.fetch(
                FetchDescriptor<SourceChunkRecord>(
                    predicate: #Predicate { record in
                        record.sourceID == sourceID
                    }
                )
            )
            documents.forEach(modelContext.delete)
            chunks.forEach(modelContext.delete)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw SourceLibraryFailure.deleteFailed
        }
    }

    private static func documentsAreOrdered(
        _ first: SourceDocument,
        _ second: SourceDocument
    ) -> Bool {
        if first.importedAt == second.importedAt {
            return first.id.uuidString < second.id.uuidString
        }
        return first.importedAt > second.importedAt
    }

    private static func chunksAreOrdered(
        _ first: SourceChunk,
        _ second: SourceChunk
    ) -> Bool {
        if first.sourceID == second.sourceID {
            return first.ordinal < second.ordinal
        }
        return first.sourceID.uuidString < second.sourceID.uuidString
    }
}
