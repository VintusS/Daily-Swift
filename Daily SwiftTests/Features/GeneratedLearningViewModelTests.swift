import Foundation
import Testing
@testable import DailySwift

@MainActor
struct GeneratedLearningViewModelTests {
    @Test("Restore publishes saved artifacts and available state once")
    func restoreAvailableArtifacts() async {
        let artifact = GeneratedLearningViewModelFixtures.artifact(
            id: GeneratedLearningViewModelFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningViewModelFixtures.firstSourceID]
        )
        let generator = ScriptedGeneratedLearningGenerator(
            restoredArtifacts: [artifact]
        )
        let viewModel = GeneratedLearningViewModel(generator: generator)

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()

        #expect(viewModel.state == .ready)
        #expect(viewModel.artifacts == [artifact])
        #expect(await generator.restoreCallCount() == 1)
    }

    @Test("Restore preserves history while publishing every unavailable state")
    func restoreUnavailableStates() async {
        let artifact = GeneratedLearningViewModelFixtures.artifact(
            id: GeneratedLearningViewModelFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningViewModelFixtures.firstSourceID]
        )
        let reasons: [LanguageModelUnavailability] = [
            .deviceNotSupported,
            .intelligenceDisabled,
            .modelNotReady,
            .languageOrRegionUnsupported,
            .other,
        ]

        for reason in reasons {
            let generator = ScriptedGeneratedLearningGenerator(
                availability: .unavailable(reason),
                restoredArtifacts: [artifact]
            )
            let viewModel = GeneratedLearningViewModel(generator: generator)

            await viewModel.loadIfNeeded()

            #expect(viewModel.state == .unavailable(reason))
            #expect(viewModel.artifacts == [artifact])
        }
    }

    @Test("Restore failure hides unverified history and reports storage failure")
    func restoreFailure() async {
        let generator = ScriptedGeneratedLearningGenerator(
            restoreFailure: .storageUnavailable
        )
        let viewModel = GeneratedLearningViewModel(generator: generator)

        await viewModel.loadIfNeeded()

        #expect(viewModel.artifacts.isEmpty)
        #expect(viewModel.state == .failed(.storageUnavailable))
        #expect(await generator.availabilityCallCount() == 0)
    }

    @Test("Storage recovery retries restoration before publishing ready")
    func storageRecoveryReloadsHistory() async {
        let artifact = GeneratedLearningViewModelFixtures.artifact(
            id: GeneratedLearningViewModelFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningViewModelFixtures.firstSourceID]
        )
        let generator = SequencedRestoreGeneratedLearningGenerator(
            restoreResults: [
                .failure(.storageUnavailable),
                .success([artifact]),
            ]
        )
        let viewModel = GeneratedLearningViewModel(generator: generator)

        await viewModel.loadIfNeeded()
        #expect(viewModel.state == .failed(.storageUnavailable))

        await viewModel.reload()

        #expect(viewModel.state == .ready)
        #expect(viewModel.artifacts == [artifact])
        #expect(await generator.restoreCallCount() == 2)
        #expect(await generator.availabilityCallCount() == 1)
    }

    @Test("Availability refresh replaces the visible availability state")
    func availabilityRefresh() async {
        let generator = SequencedAvailabilityGeneratedLearningGenerator(
            availabilityStates: [
                .unavailable(.modelNotReady),
                .available,
            ]
        )
        let viewModel = GeneratedLearningViewModel(generator: generator)

        await viewModel.loadIfNeeded()
        #expect(viewModel.state == .unavailable(.modelNotReady))

        viewModel.checkAvailability()
        await viewModel.waitForCurrentOperation()
        #expect(viewModel.state == .ready)
    }

    @Test("Generation publishes and records a cited article and quiz")
    func generationSuccess() async {
        let sourceID = GeneratedLearningViewModelFixtures.firstSourceID
        let artifact = GeneratedLearningViewModelFixtures.artifact(
            id: GeneratedLearningViewModelFixtures.firstArtifactID,
            sourceIDs: [sourceID]
        )
        let generator = ScriptedGeneratedLearningGenerator(
            generationResults: [.success(artifact)]
        )
        let viewModel = GeneratedLearningViewModel(generator: generator)
        await viewModel.loadIfNeeded()
        #expect(viewModel.state == .ready)
        viewModel.topic = "Actor isolation"
        viewModel.toggleSource(sourceID)

        viewModel.generate()
        #expect(viewModel.state == .generating)
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .generated(artifact.id))
        #expect(viewModel.latestArtifact == artifact)
        #expect(viewModel.artifacts == [artifact])
        #expect(await generator.committedArtifactIDs() == [artifact.id])
        let requests = await generator.recordedGenerationRequests()
        #expect(
            requests == [
                GeneratedLearningViewModelRequest(
                    topic: "Actor isolation",
                    sourceIDs: [sourceID]
                ),
            ]
        )
    }

    @Test("Generation storage failure leaves history unchanged")
    func generationStorageFailure() async {
        let existing = GeneratedLearningViewModelFixtures.artifact(
            id: GeneratedLearningViewModelFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningViewModelFixtures.firstSourceID]
        )
        let generator = ScriptedGeneratedLearningGenerator(
            restoredArtifacts: [existing],
            generationResults: [.success(existing)],
            commitFailure: .storageUnavailable
        )
        let viewModel = GeneratedLearningViewModel(generator: generator)
        await viewModel.loadIfNeeded()
        #expect(viewModel.state == .ready)
        viewModel.topic = "Actor isolation"

        viewModel.generate()
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .failed(.storageUnavailable))
        #expect(viewModel.artifacts == [existing])
    }

    @Test("Finalization cannot be cancelled or replaced")
    func finalizationIsNonCancellable() async {
        let artifact = GeneratedLearningViewModelFixtures.artifact(
            id: GeneratedLearningViewModelFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningViewModelFixtures.firstSourceID]
        )
        let generator = SuspendedCommitGeneratedLearningGenerator(
            artifact: artifact
        )
        let viewModel = GeneratedLearningViewModel(generator: generator)
        await viewModel.loadIfNeeded()
        viewModel.topic = "Actor isolation"

        viewModel.generate()
        await generator.waitUntilCommitStarts()
        #expect(viewModel.state == .finalizing)

        viewModel.cancel()
        viewModel.generate()
        #expect(viewModel.state == .finalizing)
        #expect(await generator.generationCallCount() == 1)

        await generator.releaseCommit()
        await viewModel.waitForCurrentOperation()
        #expect(viewModel.state == .generated(artifact.id))
        #expect(viewModel.artifacts == [artifact])
    }

    @Test("Cancellation blocks retry until the provider drains")
    func cancellationDrainBlocksRetry() async {
        let retryArtifact = GeneratedLearningViewModelFixtures.artifact(
            id: GeneratedLearningViewModelFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningViewModelFixtures.firstSourceID],
            topic: "Retry topic"
        )
        let generator = CancellableGeneratedLearningGenerator(
            retryArtifact: retryArtifact
        )
        let viewModel = GeneratedLearningViewModel(generator: generator)
        await viewModel.loadIfNeeded()
        #expect(viewModel.state == .ready)
        viewModel.topic = "Cooperative cancellation"

        viewModel.generate()
        await generator.waitUntilGenerationStarts()
        viewModel.cancel()
        #expect(viewModel.state == .cancelling)

        viewModel.topic = "Retry topic"
        viewModel.generate()
        #expect(viewModel.state == .cancelling)
        #expect(await generator.generationCallCount() == 1)

        await generator.waitUntilCancellationIsObserved()
        #expect(viewModel.state == .cancelling)
        #expect(await generator.generationCallCount() == 1)

        await generator.releaseCancellationDrain()
        await viewModel.waitForCurrentOperation()
        #expect(viewModel.state == .cancelled)
        #expect(viewModel.artifacts.isEmpty)

        viewModel.generate()
        #expect(viewModel.state == .generating)
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .generated(retryArtifact.id))
        #expect(viewModel.artifacts == [retryArtifact])
        #expect(await generator.generationCallCount() == 2)
    }

    @Test("A cancelled late return never reaches the commit boundary")
    func cancellationBeforeFinalizationDoesNotCommit() async {
        let artifact = GeneratedLearningViewModelFixtures.artifact(
            id: GeneratedLearningViewModelFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningViewModelFixtures.firstSourceID]
        )
        let generator = LateReturningGeneratedLearningGenerator(
            artifact: artifact
        )
        let viewModel = GeneratedLearningViewModel(generator: generator)
        await viewModel.loadIfNeeded()
        viewModel.topic = "Actor isolation"

        viewModel.generate()
        await generator.waitUntilGenerationStarts()
        viewModel.cancel()
        #expect(viewModel.state == .cancelling)

        await generator.returnCommittedArtifact()
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .cancelled)
        #expect(viewModel.artifacts.isEmpty)
        #expect(await generator.committedArtifactIDs().isEmpty)
    }

    @Test("Delayed restore finishes before generation can publish")
    func delayedRestoreSerializesGeneration() async {
        let restoredArtifact = GeneratedLearningViewModelFixtures.artifact(
            id: GeneratedLearningViewModelFixtures.firstArtifactID,
            sourceIDs: [GeneratedLearningViewModelFixtures.firstSourceID],
            topic: "Restored topic"
        )
        let generatedArtifact = GeneratedLearningViewModelFixtures.artifact(
            id: GeneratedLearningViewModelFixtures.secondArtifactID,
            sourceIDs: [GeneratedLearningViewModelFixtures.secondSourceID],
            topic: "Generated topic"
        )
        let generator = DelayedRestoreGeneratedLearningGenerator(
            restoredArtifact: restoredArtifact,
            generatedArtifact: generatedArtifact
        )
        let viewModel = GeneratedLearningViewModel(generator: generator)
        let loadTask = Task {
            await viewModel.loadIfNeeded()
        }

        await generator.waitUntilRestoreStarts()
        #expect(viewModel.state == .loading)

        viewModel.topic = "Generated topic"
        viewModel.generate()
        #expect(viewModel.state == .loading)
        #expect(await generator.generationCallCount() == 0)

        await generator.releaseRestore()
        await loadTask.value
        #expect(viewModel.state == .ready)
        #expect(viewModel.artifacts == [restoredArtifact])

        viewModel.generate()
        #expect(viewModel.state == .generating)
        await viewModel.waitForCurrentOperation()

        #expect(viewModel.state == .generated(generatedArtifact.id))
        #expect(viewModel.artifacts == [generatedArtifact, restoredArtifact])
        #expect(await generator.restoreCallCount() == 1)
        #expect(await generator.generationCallCount() == 1)
    }

    @Test("Source deletion removes every referencing artifact")
    func sourceDeletion() async {
        let firstSourceID = GeneratedLearningViewModelFixtures.firstSourceID
        let first = GeneratedLearningViewModelFixtures.artifact(
            id: GeneratedLearningViewModelFixtures.firstArtifactID,
            sourceIDs: [firstSourceID]
        )
        let second = GeneratedLearningViewModelFixtures.artifact(
            id: GeneratedLearningViewModelFixtures.secondArtifactID,
            sourceIDs: [GeneratedLearningViewModelFixtures.secondSourceID]
        )
        let generator = ScriptedGeneratedLearningGenerator(
            restoredArtifacts: [first, second]
        )
        let viewModel = GeneratedLearningViewModel(generator: generator)
        await viewModel.loadIfNeeded()

        let didDelete = await viewModel.deleteArtifacts(
            referencing: firstSourceID
        )

        #expect(didDelete)
        #expect(viewModel.state == .ready)
        #expect(viewModel.artifacts == [second])
        #expect(await generator.deletedSourceIDs() == [firstSourceID])
    }

    @Test("Source deletion failure retains history and reports storage")
    func sourceDeletionFailure() async {
        let sourceID = GeneratedLearningViewModelFixtures.firstSourceID
        let artifact = GeneratedLearningViewModelFixtures.artifact(
            id: GeneratedLearningViewModelFixtures.firstArtifactID,
            sourceIDs: [sourceID]
        )
        let generator = ScriptedGeneratedLearningGenerator(
            restoredArtifacts: [artifact],
            deletionFailure: .storageUnavailable
        )
        let viewModel = GeneratedLearningViewModel(generator: generator)
        await viewModel.loadIfNeeded()

        let didDelete = await viewModel.deleteArtifacts(
            referencing: sourceID
        )

        #expect(!didDelete)
        #expect(viewModel.artifacts == [artifact])
        #expect(viewModel.state == .failed(.storageUnavailable))
    }
}

private struct GeneratedLearningViewModelRequest: Equatable, Sendable {
    let topic: String
    let sourceIDs: Set<UUID>
}

private actor ScriptedGeneratedLearningGenerator:
    GeneratedLearningGenerating {
    private let availabilityState: LanguageModelAvailability
    private let restoredArtifacts: [GeneratedLearningArtifact]
    private let restoreFailure: GeneratedLearningFailure?
    private var generationResults: [
        Result<GeneratedLearningArtifact, GeneratedLearningFailure>
    ]
    private let deletionFailure: GeneratedLearningFailure?
    private let commitFailure: GeneratedLearningFailure?
    private var restoreCalls = 0
    private var availabilityCalls = 0
    private var generationRequests: [GeneratedLearningViewModelRequest] = []
    private var deletions: [UUID] = []
    private var committedIDs: [UUID] = []

    init(
        availability: LanguageModelAvailability = .available,
        restoredArtifacts: [GeneratedLearningArtifact] = [],
        restoreFailure: GeneratedLearningFailure? = nil,
        generationResults: [
            Result<GeneratedLearningArtifact, GeneratedLearningFailure>
        ] = [],
        deletionFailure: GeneratedLearningFailure? = nil,
        commitFailure: GeneratedLearningFailure? = nil
    ) {
        availabilityState = availability
        self.restoredArtifacts = restoredArtifacts
        self.restoreFailure = restoreFailure
        self.generationResults = generationResults
        self.deletionFailure = deletionFailure
        self.commitFailure = commitFailure
    }

    func availability() async -> LanguageModelAvailability {
        availabilityCalls += 1
        return availabilityState
    }

    func restore() async throws -> [GeneratedLearningArtifact] {
        restoreCalls += 1
        if let restoreFailure {
            throw restoreFailure
        }
        return restoredArtifacts
    }

    func generate(
        topic: String,
        sourceIDs: Set<UUID>
    ) async throws -> GeneratedLearningArtifact {
        generationRequests.append(
            GeneratedLearningViewModelRequest(
                topic: topic,
                sourceIDs: sourceIDs
            )
        )
        guard !generationResults.isEmpty else {
            throw GeneratedLearningFailure.generationFailed
        }
        return try generationResults.removeFirst().get()
    }

    func commitArtifact(
        _ artifact: GeneratedLearningArtifact
    ) async throws {
        committedIDs.append(artifact.id)
        if let commitFailure {
            throw commitFailure
        }
    }

    func deleteArtifacts(referencing sourceID: UUID) async throws {
        deletions.append(sourceID)
        if let deletionFailure {
            throw deletionFailure
        }
    }

    func restoreCallCount() -> Int {
        restoreCalls
    }

    func availabilityCallCount() -> Int {
        availabilityCalls
    }

    func recordedGenerationRequests() -> [GeneratedLearningViewModelRequest] {
        generationRequests
    }

    func deletedSourceIDs() -> [UUID] {
        deletions
    }

    func committedArtifactIDs() -> [UUID] {
        committedIDs
    }
}

private actor SequencedAvailabilityGeneratedLearningGenerator:
    GeneratedLearningGenerating {
    private var availabilityStates: [LanguageModelAvailability]

    init(availabilityStates: [LanguageModelAvailability]) {
        self.availabilityStates = availabilityStates
    }

    func availability() async -> LanguageModelAvailability {
        guard !availabilityStates.isEmpty else {
            return .unavailable(.other)
        }
        return availabilityStates.removeFirst()
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

    func deleteArtifacts(referencing sourceID: UUID) async throws {}
}

private actor SequencedRestoreGeneratedLearningGenerator:
    GeneratedLearningGenerating {
    private var restoreResults: [
        Result<
            [GeneratedLearningArtifact],
            GeneratedLearningFailure
        >
    ]
    private var restoreCalls = 0
    private var availabilityCalls = 0

    init(
        restoreResults: [
            Result<
                [GeneratedLearningArtifact],
                GeneratedLearningFailure
            >
        ]
    ) {
        self.restoreResults = restoreResults
    }

    func availability() async -> LanguageModelAvailability {
        availabilityCalls += 1
        return .available
    }

    func restore() async throws -> [GeneratedLearningArtifact] {
        restoreCalls += 1
        guard !restoreResults.isEmpty else {
            return []
        }
        return try restoreResults.removeFirst().get()
    }

    func generate(
        topic: String,
        sourceIDs: Set<UUID>
    ) async throws -> GeneratedLearningArtifact {
        throw GeneratedLearningFailure.generationFailed
    }

    func deleteArtifacts(referencing sourceID: UUID) async throws {}

    func restoreCallCount() -> Int {
        restoreCalls
    }

    func availabilityCallCount() -> Int {
        availabilityCalls
    }
}

private actor CancellableGeneratedLearningGenerator:
    GeneratedLearningGenerating {
    private let retryArtifact: GeneratedLearningArtifact
    private var didStartGeneration = false
    private var didObserveCancellation = false
    private var canDrainCancellation = false
    private var generationCalls = 0
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var cancellationWaiters: [
        CheckedContinuation<Void, Never>
    ] = []
    private var cancellationContinuation: CheckedContinuation<Void, Never>?
    private var drainContinuation: CheckedContinuation<Void, Never>?

    init(retryArtifact: GeneratedLearningArtifact) {
        self.retryArtifact = retryArtifact
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
        generationCalls += 1
        guard generationCalls == 1 else {
            return retryArtifact
        }

        didStartGeneration = true
        let pendingStartWaiters = startWaiters
        startWaiters.removeAll()
        pendingStartWaiters.forEach { $0.resume() }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                cancellationContinuation = continuation
            }
        } onCancel: {
            Task {
                await self.observeCancellation()
            }
        }
        await withCheckedContinuation { continuation in
            if canDrainCancellation {
                continuation.resume()
            } else {
                drainContinuation = continuation
            }
        }
        throw CancellationError()
    }

    func deleteArtifacts(referencing sourceID: UUID) async throws {}

    private func observeCancellation() {
        guard !didObserveCancellation else {
            return
        }
        didObserveCancellation = true
        cancellationContinuation?.resume()
        cancellationContinuation = nil
        let pendingCancellationWaiters = cancellationWaiters
        cancellationWaiters.removeAll()
        pendingCancellationWaiters.forEach { $0.resume() }
    }

    func waitUntilGenerationStarts() async {
        guard !didStartGeneration else {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func waitUntilCancellationIsObserved() async {
        guard !didObserveCancellation else {
            return
        }
        await withCheckedContinuation { continuation in
            cancellationWaiters.append(continuation)
        }
    }

    func releaseCancellationDrain() {
        canDrainCancellation = true
        drainContinuation?.resume()
        drainContinuation = nil
    }

    func generationCallCount() -> Int {
        generationCalls
    }
}

private actor DelayedRestoreGeneratedLearningGenerator:
    GeneratedLearningGenerating {
    private let restoredArtifact: GeneratedLearningArtifact
    private let generatedArtifact: GeneratedLearningArtifact
    private var didStartRestore = false
    private var canFinishRestore = false
    private var restoreCalls = 0
    private var generationCalls = 0
    private var restoreStartWaiters: [
        CheckedContinuation<Void, Never>
    ] = []
    private var restoreContinuation: CheckedContinuation<Void, Never>?

    init(
        restoredArtifact: GeneratedLearningArtifact,
        generatedArtifact: GeneratedLearningArtifact
    ) {
        self.restoredArtifact = restoredArtifact
        self.generatedArtifact = generatedArtifact
    }

    func availability() async -> LanguageModelAvailability {
        .available
    }

    func restore() async throws -> [GeneratedLearningArtifact] {
        restoreCalls += 1
        didStartRestore = true
        let pendingStartWaiters = restoreStartWaiters
        restoreStartWaiters.removeAll()
        pendingStartWaiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            if canFinishRestore {
                continuation.resume()
            } else {
                restoreContinuation = continuation
            }
        }
        return [restoredArtifact]
    }

    func generate(
        topic: String,
        sourceIDs: Set<UUID>
    ) async throws -> GeneratedLearningArtifact {
        generationCalls += 1
        return generatedArtifact
    }

    func deleteArtifacts(referencing sourceID: UUID) async throws {}

    func waitUntilRestoreStarts() async {
        guard !didStartRestore else {
            return
        }
        await withCheckedContinuation { continuation in
            restoreStartWaiters.append(continuation)
        }
    }

    func releaseRestore() {
        canFinishRestore = true
        restoreContinuation?.resume()
        restoreContinuation = nil
    }

    func restoreCallCount() -> Int {
        restoreCalls
    }

    func generationCallCount() -> Int {
        generationCalls
    }
}

private actor LateReturningGeneratedLearningGenerator:
    GeneratedLearningGenerating {
    private let artifact: GeneratedLearningArtifact
    private var didStart = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var returnContinuation: CheckedContinuation<Void, Never>?
    private var committedIDs: [UUID] = []

    init(artifact: GeneratedLearningArtifact) {
        self.artifact = artifact
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
        didStart = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            returnContinuation = continuation
        }
        // Intentionally ignore cancellation to simulate a provider/store
        // handoff that committed just before the UI cancellation arrived.
        return artifact
    }

    func commitArtifact(
        _ artifact: GeneratedLearningArtifact
    ) async throws {
        committedIDs.append(artifact.id)
    }

    func deleteArtifacts(referencing sourceID: UUID) async throws {}

    func waitUntilGenerationStarts() async {
        guard !didStart else {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func returnCommittedArtifact() {
        returnContinuation?.resume()
        returnContinuation = nil
    }

    func committedArtifactIDs() -> [UUID] {
        committedIDs
    }
}

private actor SuspendedCommitGeneratedLearningGenerator:
    GeneratedLearningGenerating {
    private let artifact: GeneratedLearningArtifact
    private var generationCalls = 0
    private var didStartCommit = false
    private var commitStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var commitContinuation: CheckedContinuation<Void, Never>?

    init(artifact: GeneratedLearningArtifact) {
        self.artifact = artifact
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
        generationCalls += 1
        return artifact
    }

    func commitArtifact(
        _ artifact: GeneratedLearningArtifact
    ) async throws {
        didStartCommit = true
        let waiters = commitStartWaiters
        commitStartWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            commitContinuation = continuation
        }
    }

    func deleteArtifacts(referencing sourceID: UUID) async throws {}

    func waitUntilCommitStarts() async {
        guard !didStartCommit else {
            return
        }
        await withCheckedContinuation { continuation in
            commitStartWaiters.append(continuation)
        }
    }

    func releaseCommit() {
        commitContinuation?.resume()
        commitContinuation = nil
    }

    func generationCallCount() -> Int {
        generationCalls
    }
}

private enum GeneratedLearningViewModelFixtures {
    static let firstSourceID = UUID(
        uuidString: "11111111-1111-1111-1111-111111111111"
    )!
    static let secondSourceID = UUID(
        uuidString: "22222222-2222-2222-2222-222222222222"
    )!
    static let firstArtifactID = UUID(
        uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    )!
    static let secondArtifactID = UUID(
        uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
    )!

    static func artifact(
        id: UUID,
        sourceIDs: [UUID],
        topic: String = "Actor isolation"
    ) -> GeneratedLearningArtifact {
        let references = sourceIDs.enumerated().map { index, sourceID in
            let referenceID = "source-card-\(index + 1)"
            return GeneratedLearningSourceReference(
                id: referenceID,
                documentTitle: "Source \(index + 1)",
                rightsStatus: .lawfullyPossessedPrivateCopy,
                citation: SourceCitation(
                    sourceID: sourceID,
                    chunkID: "chunk-\(index + 1)",
                    headingPath: ["Concurrency", "Actor isolation"],
                    location: SourceLocation(
                        startLine: 1,
                        endLine: 2,
                        startCharacter: 0,
                        endCharacter: 42
                    ),
                    contentHash: String(repeating: "a", count: 64)
                )
            )
        }
        let citationIDs = references.first.map { [$0.id] } ?? []
        return GeneratedLearningArtifact(
            id: id,
            schemaVersion: GeneratedLearningArtifact.currentSchemaVersion,
            topic: topic,
            promptVersion: GeneratedLearningGenerator.promptVersion,
            candidateSchemaVersion:
                GeneratedLearningGenerator.candidateSchemaVersion,
            providerRuntimeLabel: "deterministic-provider-v1",
            sourceSetHash: String(repeating: "b", count: 64),
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            trust: .experimentalUserMaterial,
            sourceReferences: references,
            article: GeneratedLearningArticle(
                title: "Understanding actor isolation",
                learningObjective: "Explain explicit state ownership.",
                explanation: "Actors isolate mutable state.",
                exampleCode: "actor Counter { var value = 0 }",
                citationReferenceIDs: citationIDs
            ),
            quiz: GeneratedLearningQuiz(
                prompt: "Which declaration isolates mutable state?",
                choices: [
                    GeneratedLearningQuizChoice(
                        id: "choice-1",
                        text: "An actor"
                    ),
                    GeneratedLearningQuizChoice(
                        id: "choice-2",
                        text: "A global variable"
                    ),
                    GeneratedLearningQuizChoice(
                        id: "choice-3",
                        text: "An unchecked reference"
                    ),
                ],
                answerKeyChoiceID: "choice-1",
                explanation: "An actor serializes access to its state.",
                citationReferenceIDs: citationIDs
            )
        )
    }
}
