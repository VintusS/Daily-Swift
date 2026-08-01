import Foundation

protocol LearningSourceDeleting: Sendable {
    func deleteSource(id: UUID) async throws
}

actor CascadingLearningSourceDeleter: LearningSourceDeleting {
    private let sourceLibrary: any SourceLibraryServing
    private let generatedLearning: any GeneratedLearningGenerating

    init(
        sourceLibrary: any SourceLibraryServing,
        generatedLearning: any GeneratedLearningGenerating
    ) {
        self.sourceLibrary = sourceLibrary
        self.generatedLearning = generatedLearning
    }

    func deleteSource(id: UUID) async throws {
        do {
            try await generatedLearning.deleteArtifacts(referencing: id)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Keep the source when generated derivatives cannot be removed.
            throw SourceLibraryFailure.deleteFailed
        }

        do {
            // If this second step fails, generated derivatives may already
            // be gone while the original source remains. Reactivating the
            // source makes the disclosed retry path usable in this session.
            try await sourceLibrary.delete(sourceID: id)
        } catch {
            await generatedLearning.abortSourceDeletion(id: id)
            throw error
        }
    }
}

struct DirectLearningSourceDeleter: LearningSourceDeleting {
    let sourceLibrary: any SourceLibraryServing

    func deleteSource(id: UUID) async throws {
        try await sourceLibrary.delete(sourceID: id)
    }
}
