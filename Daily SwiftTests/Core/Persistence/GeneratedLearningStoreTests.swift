import Foundation
import Testing
@testable import DailySwift

@MainActor
struct GeneratedLearningStoreTests {
    @Test("File store round trips one JSON file per artifact")
    func perArtifactRoundTrip() async throws {
        let rootURL = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }
        let older = GeneratedLearningStoreFixtures.artifact(
            id: GeneratedLearningStoreFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningStoreFixtures.firstSourceID],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let newer = GeneratedLearningStoreFixtures.artifact(
            id: GeneratedLearningStoreFixtures.secondArtifactID,
            sourceIDs: [GeneratedLearningStoreFixtures.secondSourceID],
            createdAt: Date(timeIntervalSince1970: 1_800_000_100)
        )
        let store = FileGeneratedLearningStore(rootURL: rootURL)

        try await store.save(older)
        try await store.save(newer)

        #expect(try await store.restore() == [newer, older])
        let jsonFileNames = try FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension.lowercased() == "json" }
        .map(\.lastPathComponent)
        #expect(
            Set(jsonFileNames)
                == Set([
                    "\(older.id.uuidString.lowercased()).json",
                    "\(newer.id.uuidString.lowercased()).json",
                ])
        )
    }

    @Test("Saving the same artifact identity atomically replaces its file")
    func saveReplacesArtifact() async throws {
        let rootURL = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }
        let original = GeneratedLearningStoreFixtures.artifact(
            id: GeneratedLearningStoreFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningStoreFixtures.firstSourceID],
            topic: "Original topic"
        )
        let replacement = GeneratedLearningStoreFixtures.artifact(
            id: original.id,
            sourceIDs: [GeneratedLearningStoreFixtures.firstSourceID],
            topic: "Replacement topic"
        )
        let store = FileGeneratedLearningStore(rootURL: rootURL)

        try await store.save(original)
        try await store.save(replacement)

        #expect(try await store.restore() == [replacement])
    }

    @Test("Cancelling a new save removes the committed artifact file")
    func cancelledNewSaveRollsBack() async throws {
        let rootURL = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }
        let artifact = GeneratedLearningStoreFixtures.artifact(
            id: GeneratedLearningStoreFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningStoreFixtures.firstSourceID]
        )
        let checkpoint = GeneratedLearningStoreSaveCheckpoint()
        let store = FileGeneratedLearningStore(
            rootURL: rootURL,
            postWriteCheckpoint: {
                await checkpoint.pauseAfterWrite()
            }
        )
        let save = Task {
            try await store.save(artifact)
        }

        await checkpoint.waitUntilPaused()
        save.cancel()
        await checkpoint.resume()

        do {
            try await save.value
            Issue.record("Expected the committed save to be cancelled")
        } catch is CancellationError {
            // Expected cancellation after the atomic write checkpoint.
        } catch {
            Issue.record("Expected CancellationError after save rollback")
        }
        #expect(
            !FileManager.default.fileExists(
                atPath: artifactURL(artifact.id, under: rootURL).path
            )
        )
        #expect(try await store.restore().isEmpty)
    }

    @Test("Cancelling an atomic replacement restores the previous artifact")
    func cancelledReplacementRestoresPreviousArtifact() async throws {
        let rootURL = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }
        let original = GeneratedLearningStoreFixtures.artifact(
            id: GeneratedLearningStoreFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningStoreFixtures.firstSourceID],
            topic: "Original topic"
        )
        let replacement = GeneratedLearningStoreFixtures.artifact(
            id: original.id,
            sourceIDs: [GeneratedLearningStoreFixtures.firstSourceID],
            topic: "Cancelled replacement"
        )
        let initialStore = FileGeneratedLearningStore(rootURL: rootURL)
        try await initialStore.save(original)

        let checkpoint = GeneratedLearningStoreSaveCheckpoint()
        let replacementStore = FileGeneratedLearningStore(
            rootURL: rootURL,
            postWriteCheckpoint: {
                await checkpoint.pauseAfterWrite()
            }
        )
        let save = Task {
            try await replacementStore.save(replacement)
        }

        await checkpoint.waitUntilPaused()
        save.cancel()
        await checkpoint.resume()

        do {
            try await save.value
            Issue.record("Expected the replacement save to be cancelled")
        } catch is CancellationError {
            // Expected cancellation after the replacement checkpoint.
        } catch {
            Issue.record("Expected CancellationError after replacement rollback")
        }
        #expect(try await initialStore.restore() == [original])
    }

    @Test("Corrupt artifact data is quarantined without blocking restore")
    func corruptArtifact() async throws {
        let rootURL = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        let corruptURL = rootURL.appendingPathComponent("corrupt.json")
        try Data("not-json".utf8).write(
            to: corruptURL,
            options: .atomic
        )
        let store = FileGeneratedLearningStore(rootURL: rootURL)

        #expect(try await store.restore().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: corruptURL.path))
        let quarantined = try quarantinedURLs(under: rootURL)
        #expect(quarantined.count == 1)
        #expect(
            try Data(contentsOf: quarantined[0])
                == Data("not-json".utf8)
        )
    }

    @Test("Unsupported schema is rejected on save and quarantined on restore")
    func unsupportedSchema() async throws {
        let saveRootURL = temporaryRoot()
        let restoreRootURL = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: saveRootURL)
            try? FileManager.default.removeItem(at: restoreRootURL)
        }
        let unsupported = GeneratedLearningStoreFixtures.artifact(
            id: GeneratedLearningStoreFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningStoreFixtures.firstSourceID],
            schemaVersion: GeneratedLearningArtifact.currentSchemaVersion + 1
        )
        let saveStore = FileGeneratedLearningStore(rootURL: saveRootURL)

        await #expect(
            throws: GeneratedLearningStoreFailure.unsupportedSchema
        ) {
            try await saveStore.save(unsupported)
        }

        try FileManager.default.createDirectory(
            at: restoreRootURL,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let unsupportedURL = restoreRootURL.appendingPathComponent(
            "unsupported.json"
        )
        try encoder.encode(unsupported).write(
            to: unsupportedURL,
            options: .atomic
        )
        let restoreStore = FileGeneratedLearningStore(rootURL: restoreRootURL)

        #expect(try await restoreStore.restore().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: unsupportedURL.path))
        #expect(try quarantinedURLs(under: restoreRootURL).count == 1)
    }

    @Test("Valid artifacts restore while corrupt JSON siblings are quarantined")
    func mixedValidAndCorruptArtifacts() async throws {
        let rootURL = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }
        let valid = GeneratedLearningStoreFixtures.artifact(
            id: GeneratedLearningStoreFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningStoreFixtures.firstSourceID]
        )
        let store = FileGeneratedLearningStore(rootURL: rootURL)
        try await store.save(valid)

        let corruptURL = rootURL.appendingPathComponent("corrupt.json")
        try Data("not-json".utf8).write(to: corruptURL, options: .atomic)

        #expect(try await store.restore() == [valid])
        #expect(!FileManager.default.fileExists(atPath: corruptURL.path))
        #expect(try quarantinedURLs(under: rootURL).count == 1)
    }

    @Test("Unreadable artifact data is preserved and reports read failure")
    func unreadableArtifactIsPreserved() async throws {
        let rootURL = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        let unreadableURL = rootURL.appendingPathComponent(
            "unreadable.json",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: unreadableURL,
            withIntermediateDirectories: false
        )
        let store = FileGeneratedLearningStore(rootURL: rootURL)

        await #expect(throws: GeneratedLearningStoreFailure.readFailed) {
            _ = try await store.restore()
        }
        #expect(FileManager.default.fileExists(atPath: unreadableURL.path))
        #expect(
            !FileManager.default.fileExists(
                atPath: quarantineURL(under: rootURL).path
            )
        )
    }

    @Test("Single-artifact deletion leaves unrelated history intact")
    func singleArtifactDeletion() async throws {
        let rootURL = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }
        let first = GeneratedLearningStoreFixtures.artifact(
            id: GeneratedLearningStoreFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningStoreFixtures.firstSourceID]
        )
        let second = GeneratedLearningStoreFixtures.artifact(
            id: GeneratedLearningStoreFixtures.secondArtifactID,
            sourceIDs: [GeneratedLearningStoreFixtures.secondSourceID]
        )
        let store = FileGeneratedLearningStore(rootURL: rootURL)
        try await store.save(first)
        try await store.save(second)

        try await store.deleteArtifact(id: first.id)
        try await store.deleteArtifact(id: first.id)

        #expect(try await store.restore() == [second])
    }

    @Test("Source deletion removes every referencing artifact file")
    func sourceReferenceDeletion() async throws {
        let rootURL = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }
        let firstSourceID = GeneratedLearningStoreFixtures.firstSourceID
        let secondSourceID = GeneratedLearningStoreFixtures.secondSourceID
        let firstOnly = GeneratedLearningStoreFixtures.artifact(
            id: GeneratedLearningStoreFixtures.firstArtifactID,
            sourceIDs: [firstSourceID]
        )
        let secondOnly = GeneratedLearningStoreFixtures.artifact(
            id: GeneratedLearningStoreFixtures.secondArtifactID,
            sourceIDs: [secondSourceID]
        )
        let shared = GeneratedLearningStoreFixtures.artifact(
            id: GeneratedLearningStoreFixtures.sharedArtifactID,
            sourceIDs: [firstSourceID, secondSourceID]
        )
        let store = FileGeneratedLearningStore(rootURL: rootURL)
        try await store.save(firstOnly)
        try await store.save(secondOnly)
        try await store.save(shared)
        let corruptURL = rootURL.appendingPathComponent("corrupt.json")
        try Data("not-json".utf8).write(to: corruptURL, options: .atomic)
        let unreadableURL = rootURL.appendingPathComponent(
            "unreadable.json",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: unreadableURL,
            withIntermediateDirectories: false
        )

        try await store.deleteArtifacts(referencing: firstSourceID)

        #expect(try await store.restore() == [secondOnly])
        #expect(
            !FileManager.default.fileExists(
                atPath: artifactURL(firstOnly.id, under: rootURL).path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: artifactURL(secondOnly.id, under: rootURL).path
            )
        )
        #expect(
            !FileManager.default.fileExists(
                atPath: artifactURL(shared.id, under: rootURL).path
            )
        )
        #expect(!FileManager.default.fileExists(atPath: corruptURL.path))
        #expect(!FileManager.default.fileExists(atPath: unreadableURL.path))
        #expect(
            !FileManager.default.fileExists(
                atPath: quarantineURL(under: rootURL).path
            )
        )
    }

    @Test("A non-directory root reports initialization failure")
    func initializationFailure() async throws {
        let containerURL = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: containerURL)
        }
        try FileManager.default.createDirectory(
            at: containerURL,
            withIntermediateDirectories: true
        )
        let blockedRootURL = containerURL.appendingPathComponent(
            "generated-learning"
        )
        try Data("occupied".utf8).write(to: blockedRootURL)
        let artifact = GeneratedLearningStoreFixtures.artifact(
            id: GeneratedLearningStoreFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningStoreFixtures.firstSourceID]
        )
        let store = FileGeneratedLearningStore(rootURL: blockedRootURL)

        await #expect(
            throws: GeneratedLearningStoreFailure.initializationFailed
        ) {
            _ = try await store.restore()
        }
        await #expect(
            throws: GeneratedLearningStoreFailure.initializationFailed
        ) {
            try await store.save(artifact)
        }
    }

    @Test("In-memory store exposes deterministic storage failures")
    func inMemoryFailureInjection() async {
        let artifact = GeneratedLearningStoreFixtures.artifact(
            id: GeneratedLearningStoreFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningStoreFixtures.firstSourceID]
        )
        let store = InMemoryGeneratedLearningStore(
            restoreOutcomes: [.failure(.readFailed)],
            writeOutcomes: [.failure(.writeFailed)],
            deleteOutcomes: [.failure(.deleteFailed)]
        )

        await #expect(throws: GeneratedLearningStoreFailure.readFailed) {
            _ = try await store.restore()
        }
        await #expect(throws: GeneratedLearningStoreFailure.writeFailed) {
            try await store.save(artifact)
        }
        await #expect(throws: GeneratedLearningStoreFailure.deleteFailed) {
            try await store.deleteArtifacts(
                referencing: GeneratedLearningStoreFixtures.firstSourceID
            )
        }
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "DailySwiftGeneratedLearningStoreTests-\(UUID().uuidString)",
            isDirectory: true
        )
    }

    private func artifactURL(_ id: UUID, under rootURL: URL) -> URL {
        rootURL.appendingPathComponent(
            "\(id.uuidString.lowercased()).json",
            isDirectory: false
        )
    }

    private func quarantineURL(under rootURL: URL) -> URL {
        rootURL.appendingPathComponent(
            ".quarantine",
            isDirectory: true
        )
    }

    private func quarantinedURLs(under rootURL: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: quarantineURL(under: rootURL),
            includingPropertiesForKeys: nil
        )
    }
}

private actor GeneratedLearningStoreSaveCheckpoint {
    private var didPause = false
    private var pauseWaiters: [CheckedContinuation<Void, Never>] = []
    private var resumeContinuation: CheckedContinuation<Void, Never>?

    func pauseAfterWrite() async {
        didPause = true
        let waiters = pauseWaiters
        pauseWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            resumeContinuation = continuation
        }
    }

    func waitUntilPaused() async {
        guard !didPause else {
            return
        }
        await withCheckedContinuation { continuation in
            pauseWaiters.append(continuation)
        }
    }

    func resume() {
        resumeContinuation?.resume()
        resumeContinuation = nil
    }
}

private enum GeneratedLearningStoreFixtures {
    static let firstSourceID = UUID(
        uuidString: "33333333-3333-3333-3333-333333333333"
    )!
    static let secondSourceID = UUID(
        uuidString: "44444444-4444-4444-4444-444444444444"
    )!
    static let firstArtifactID = UUID(
        uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc"
    )!
    static let secondArtifactID = UUID(
        uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd"
    )!
    static let sharedArtifactID = UUID(
        uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"
    )!

    static func artifact(
        id: UUID,
        sourceIDs: [UUID],
        topic: String = "Value semantics",
        schemaVersion: Int = GeneratedLearningArtifact.currentSchemaVersion,
        createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000)
    ) -> GeneratedLearningArtifact {
        let references = sourceIDs.enumerated().map { index, sourceID in
            GeneratedLearningSourceReference(
                id: "source-card-\(index + 1)",
                documentTitle: "Private source \(index + 1)",
                rightsStatus: .lawfullyPossessedPrivateCopy,
                citation: SourceCitation(
                    sourceID: sourceID,
                    chunkID: "chunk-\(index + 1)",
                    headingPath: ["Swift", "Value semantics"],
                    location: SourceLocation(
                        startLine: index + 1,
                        endLine: index + 2,
                        startCharacter: index * 50,
                        endCharacter: (index + 1) * 50
                    ),
                    contentHash: String(repeating: "c", count: 64)
                )
            )
        }
        let citationIDs = references.first.map { [$0.id] } ?? []
        return GeneratedLearningArtifact(
            id: id,
            schemaVersion: schemaVersion,
            topic: topic,
            promptVersion: GeneratedLearningGenerator.promptVersion,
            candidateSchemaVersion:
                GeneratedLearningGenerator.candidateSchemaVersion,
            providerRuntimeLabel: "deterministic-provider-v1",
            sourceSetHash: String(repeating: "d", count: 64),
            createdAt: createdAt,
            trust: .experimentalUserMaterial,
            sourceReferences: references,
            article: GeneratedLearningArticle(
                title: "Understanding value semantics",
                learningObjective: "Explain independent logical values.",
                explanation: "A copied value preserves independent state.",
                exampleCode: "struct Progress { var count = 0 }",
                citationReferenceIDs: citationIDs
            ),
            quiz: GeneratedLearningQuiz(
                prompt: "What does copying a value preserve?",
                choices: [
                    GeneratedLearningQuizChoice(
                        id: "choice-1",
                        text: "Independent logical state"
                    ),
                    GeneratedLearningQuizChoice(
                        id: "choice-2",
                        text: "Shared mutable identity"
                    ),
                    GeneratedLearningQuizChoice(
                        id: "choice-3",
                        text: "A global dependency"
                    ),
                ],
                answerKeyChoiceID: "choice-1",
                explanation: "Value semantics preserve independent behavior.",
                citationReferenceIDs: citationIDs
            )
        )
    }
}
