import Foundation
import Testing
@testable import DailySwift

struct LearningSourceDeletionCoordinatorTests {
    @Test("Generated derivatives are removed before their source")
    func generatedLearningIsDeletedFirst() async throws {
        let recorder = SourceDeletionRecorder()
        let generatedLearning = RecordingGeneratedLearningGenerator(
            recorder: recorder
        )
        let sourceLibrary = RecordingSourceLibraryService(
            recorder: recorder
        )
        let coordinator = CascadingLearningSourceDeleter(
            sourceLibrary: sourceLibrary,
            generatedLearning: generatedLearning
        )

        try await coordinator.deleteSource(id: sourceID)

        #expect(
            await recorder.events()
                == ["generated-learning", "source"]
        )
    }

    @Test("A generated cleanup failure retains the source")
    func generatedCleanupFailureStopsSourceDeletion() async {
        let recorder = SourceDeletionRecorder()
        let generatedLearning = RecordingGeneratedLearningGenerator(
            recorder: recorder,
            deletionFailure: .storageUnavailable
        )
        let sourceLibrary = RecordingSourceLibraryService(
            recorder: recorder
        )
        let coordinator = CascadingLearningSourceDeleter(
            sourceLibrary: sourceLibrary,
            generatedLearning: generatedLearning
        )

        await #expect(throws: SourceLibraryFailure.deleteFailed) {
            try await coordinator.deleteSource(id: sourceID)
        }
        #expect(await recorder.events() == ["generated-learning"])
    }

    @Test("A source deletion failure reports a safe partial result")
    func sourceDeletionFailureFollowsGeneratedCleanup() async {
        let recorder = SourceDeletionRecorder()
        let generatedLearning = RecordingGeneratedLearningGenerator(
            recorder: recorder
        )
        let sourceLibrary = RecordingSourceLibraryService(
            recorder: recorder,
            deletionFailure: .deleteFailed
        )
        let coordinator = CascadingLearningSourceDeleter(
            sourceLibrary: sourceLibrary,
            generatedLearning: generatedLearning
        )

        await #expect(throws: SourceLibraryFailure.deleteFailed) {
            try await coordinator.deleteSource(id: sourceID)
        }
        #expect(
            await recorder.events()
                == [
                    "generated-learning",
                    "source",
                    "source-deletion-abort",
                ]
        )
    }

    @Test("Generated cleanup failure re-enables the retained source")
    func generatedCleanupFailureReenablesSource() async throws {
        let sourceLibrary = SourceLibraryFixtures.service()
        let store = InMemoryGeneratedLearningStore(
            deleteOutcomes: [.failure(.deleteFailed)]
        )
        let generator = GeneratedLearningGenerator(
            retriever: DirectScanSourceRetriever(
                sourceLibrary: sourceLibrary
            ),
            sourceLibrary: sourceLibrary,
            provider: DeterministicLanguageModelProvider(),
            store: store
        )
        let coordinator = CascadingLearningSourceDeleter(
            sourceLibrary: sourceLibrary,
            generatedLearning: generator
        )

        await #expect(throws: SourceLibraryFailure.deleteFailed) {
            try await coordinator.deleteSource(
                id: SourceLibraryFixtures.sourceID
            )
        }

        let artifact = try await generator.generate(
            topic: "actor isolation",
            sourceIDs: [SourceLibraryFixtures.sourceID]
        )
        #expect(artifact.references(sourceID: SourceLibraryFixtures.sourceID))
    }

    @Test("Source cleanup failure aborts invalidation for the retained source")
    func sourceCleanupFailureReenablesSource() async throws {
        let baseSourceLibrary = SourceLibraryFixtures.service()
        let sourceLibrary = DeleteFailingSourceLibrary(
            base: baseSourceLibrary
        )
        let generator = GeneratedLearningGenerator(
            retriever: DirectScanSourceRetriever(
                sourceLibrary: sourceLibrary
            ),
            sourceLibrary: sourceLibrary,
            provider: DeterministicLanguageModelProvider(),
            store: InMemoryGeneratedLearningStore()
        )
        let coordinator = CascadingLearningSourceDeleter(
            sourceLibrary: sourceLibrary,
            generatedLearning: generator
        )

        await #expect(throws: SourceLibraryFailure.deleteFailed) {
            try await coordinator.deleteSource(
                id: SourceLibraryFixtures.sourceID
            )
        }

        let artifact = try await generator.generate(
            topic: "actor isolation",
            sourceIDs: [SourceLibraryFixtures.sourceID]
        )
        #expect(artifact.references(sourceID: SourceLibraryFixtures.sourceID))
    }

    private var sourceID: UUID {
        UUID(uuidString: "76000000-0000-0000-0000-000000000001")!
    }
}

private actor SourceDeletionRecorder {
    private var recordedEvents: [String] = []

    func record(_ event: String) {
        recordedEvents.append(event)
    }

    func events() -> [String] {
        recordedEvents
    }
}

private actor RecordingGeneratedLearningGenerator:
    GeneratedLearningGenerating {
    private let recorder: SourceDeletionRecorder
    private let deletionFailure: GeneratedLearningFailure?

    init(
        recorder: SourceDeletionRecorder,
        deletionFailure: GeneratedLearningFailure? = nil
    ) {
        self.recorder = recorder
        self.deletionFailure = deletionFailure
    }

    func availability() async -> LanguageModelAvailability {
        .available
    }

    func restore() async throws -> [GeneratedLearningArtifact] {
        []
    }

    func generate(
        topic: String,
        sourceIDs: Set<UUID>
    ) async throws -> GeneratedLearningArtifact {
        throw GeneratedLearningFailure.generationFailed
    }

    func deleteArtifacts(referencing sourceID: UUID) async throws {
        await recorder.record("generated-learning")
        if let deletionFailure {
            throw deletionFailure
        }
    }

    func abortSourceDeletion(id sourceID: UUID) async {
        await recorder.record("source-deletion-abort")
    }
}

private actor DeleteFailingSourceLibrary: SourceLibraryServing {
    private let base: InMemorySourceLibraryService

    init(base: InMemorySourceLibraryService) {
        self.base = base
    }

    func restore() async throws -> SourceLibrarySnapshot {
        try await base.restore()
    }

    func importSource(
        _ request: SourceImportRequest
    ) async throws -> SourceDocument {
        try await base.importSource(request)
    }

    func resolve(
        _ citation: SourceCitation
    ) async throws -> ResolvedSourceCitation {
        try await base.resolve(citation)
    }

    func delete(sourceID: UUID) async throws {
        throw SourceLibraryFailure.deleteFailed
    }
}

private actor RecordingSourceLibraryService: SourceLibraryServing {
    private let recorder: SourceDeletionRecorder
    private let deletionFailure: SourceLibraryFailure?

    init(
        recorder: SourceDeletionRecorder,
        deletionFailure: SourceLibraryFailure? = nil
    ) {
        self.recorder = recorder
        self.deletionFailure = deletionFailure
    }

    func restore() async throws -> SourceLibrarySnapshot {
        .empty
    }

    func importSource(
        _ request: SourceImportRequest
    ) async throws -> SourceDocument {
        throw SourceLibraryFailure.unreadableFile
    }

    func resolve(
        _ citation: SourceCitation
    ) async throws -> ResolvedSourceCitation {
        throw SourceLibraryFailure.citationMissing
    }

    func delete(sourceID: UUID) async throws {
        await recorder.record("source")
        if let deletionFailure {
            throw deletionFailure
        }
    }
}
