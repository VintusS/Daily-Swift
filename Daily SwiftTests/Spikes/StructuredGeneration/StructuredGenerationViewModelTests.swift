#if DEBUG
import Testing
@testable import DailySwift

@MainActor
struct StructuredGenerationViewModelTests {
    @Test("Every unavailable reason maps to an explicit state")
    func unavailableStatesAreMapped() async {
        let reasons: [StructuredGenerationUnavailability] = [
            .deviceNotSupported,
            .intelligenceDisabled,
            .modelNotReady,
            .languageOrRegionUnsupported,
            .other,
        ]

        for reason in reasons {
            let client = DeterministicStructuredGenerationClient(
                availability: .unavailable(reason),
                outcome: .artifact(StructuredGenerationFixtures.validArtifact)
            )
            let viewModel = makeViewModel(client: client)

            viewModel.checkAvailability()
            await viewModel.waitForCurrentOperation()

            #expect(viewModel.state == .unavailable(reason))
        }
    }

    @Test("A valid candidate becomes visible content")
    func validArtifactBecomesContent() async {
        let viewModel = makeViewModel(
            client: StructuredGenerationFixtures.validClient
        )

        viewModel.generate()
        await viewModel.waitForCurrentOperation()

        #expect(
            viewModel.state
                == .content(StructuredGenerationFixtures.validArtifact)
        )
    }

    @Test("An invalid candidate is rejected before becoming content")
    func invalidArtifactIsRejected() async {
        let viewModel = makeViewModel(
            client: StructuredGenerationFixtures.invalidClient
        )

        viewModel.generate()
        await viewModel.waitForCurrentOperation()

        guard case let .rejected(error) = viewModel.state else {
            Issue.record("Expected a rejected state")
            return
        }
        #expect(error.failures.contains(.missingCitations(.lesson)))
        #expect(error.failures.contains(.correctChoiceNotFound("missing")))
    }

    @Test("An invalid request is rejected before provider generation")
    func invalidRequestIsRejected() async {
        let fixture = StructuredGenerationFixtures.sourceCards[0]
        let tamperedCard = StructuredGenerationSourceCard(
            id: fixture.id,
            title: fixture.title,
            location: fixture.location,
            rights: fixture.rights,
            contentHash: String(repeating: "0", count: 64),
            text: fixture.text
        )
        let requestFixture = StructuredGenerationFixtures.request
        let invalidRequest = StructuredGenerationRequest(
            conceptID: requestFixture.conceptID,
            difficulty: requestFixture.difficulty,
            swiftVersion: requestFixture.swiftVersion,
            minimumIOSVersion: requestFixture.minimumIOSVersion,
            promptVersion: requestFixture.promptVersion,
            schemaVersion: requestFixture.schemaVersion,
            sourceCards: [tamperedCard]
        )
        let viewModel = makeViewModel(
            request: invalidRequest,
            client: StructuredGenerationFixtures.validClient
        )

        viewModel.generate()
        await viewModel.waitForCurrentOperation()

        guard case let .rejected(error) = viewModel.state else {
            Issue.record("Expected the request to be rejected")
            return
        }
        #expect(
            error.failures.contains(
                .sourceCardContentHashMismatch(cardID: fixture.id)
            )
        )
    }

    @Test("Every typed client error maps to an explicit failure state")
    func clientErrorsAreMapped() async {
        let failures: [StructuredGenerationClientFailure] = [
            .contextWindowExceeded,
            .safetyGuardrail,
            .requestFailed,
            .invalidResponse,
            .unknown,
        ]

        for failure in failures {
            let client = DeterministicStructuredGenerationClient(
                outcome: .failure(failure)
            )
            let viewModel = makeViewModel(client: client)

            viewModel.generate()
            await viewModel.waitForCurrentOperation()

            #expect(viewModel.state == .failed(failure))
        }
    }

    @Test("Cancellation is stable and a subsequent request succeeds")
    func cancellationIsStableAndRetrySucceeds() async {
        let client = DeterministicStructuredGenerationClient(
            outcome: .artifact(StructuredGenerationFixtures.validArtifact),
            delay: .milliseconds(100)
        )
        let viewModel = makeViewModel(client: client)

        viewModel.generate()
        let didStart = await waitUntil {
            viewModel.state == .generating
        }
        #expect(didStart)

        let clock = ContinuousClock()
        let cancellationStarted = clock.now
        viewModel.cancel()
        await Task.yield()

        #expect(viewModel.state == .cancelled)
        #expect(cancellationStarted.duration(to: clock.now) < .seconds(1))

        viewModel.generate()
        await viewModel.waitForCurrentOperation()

        #expect(
            viewModel.state
                == .content(StructuredGenerationFixtures.validArtifact)
        )
    }

    @Test("A stale response cannot replace the newest response")
    func staleResponseIsIgnored() async {
        let client = ControllableStructuredGenerationClient()
        let viewModel = makeViewModel(client: client)
        let olderArtifact = artifact(modelVersion: "older-fixture")
        let newerArtifact = artifact(modelVersion: "newer-fixture")

        viewModel.generate()
        let firstRequestStarted = await waitForRequestCount(1, from: client)
        #expect(firstRequestStarted)
        guard firstRequestStarted else {
            viewModel.cancel()
            return
        }

        viewModel.generate()
        let secondRequestStarted = await waitForRequestCount(2, from: client)
        #expect(secondRequestStarted)
        guard secondRequestStarted else {
            viewModel.cancel()
            return
        }

        await client.resumeRequest(2, with: newerArtifact)
        await viewModel.waitForCurrentOperation()
        #expect(viewModel.state == .content(newerArtifact))

        await client.resumeRequest(1, with: olderArtifact)
        await Task.yield()
        #expect(viewModel.state == .content(newerArtifact))
    }

    private func makeViewModel(
        request: StructuredGenerationRequest = StructuredGenerationFixtures.request,
        client: any StructuredGenerationClient
    ) -> StructuredGenerationViewModel {
        StructuredGenerationViewModel(
            request: request,
            client: client
        )
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        for _ in 0..<1_000 {
            if condition() {
                return true
            }
            await Task.yield()
        }
        return false
    }

    private func waitForRequestCount(
        _ expectedCount: Int,
        from client: ControllableStructuredGenerationClient
    ) async -> Bool {
        for _ in 0..<1_000 {
            if await client.requestCount() >= expectedCount {
                return true
            }
            await Task.yield()
        }
        return false
    }

    private func artifact(
        modelVersion: String
    ) -> StructuredGenerationArtifact {
        let fixture = StructuredGenerationFixtures.validArtifact
        return StructuredGenerationArtifact(
            schemaVersion: fixture.schemaVersion,
            promptVersion: fixture.promptVersion,
            modelVersion: modelVersion,
            swiftVersion: fixture.swiftVersion,
            minimumIOSVersion: fixture.minimumIOSVersion,
            lesson: fixture.lesson,
            exercise: fixture.exercise
        )
    }
}

private actor ControllableStructuredGenerationClient:
    StructuredGenerationClient {
    private var nextRequestNumber = 0
    private var continuations: [
        Int: CheckedContinuation<StructuredGenerationArtifact, any Error>
    ] = [:]

    func availability() async -> StructuredGenerationAvailability {
        .available
    }

    func generate(
        _ request: StructuredGenerationRequest
    ) async throws -> StructuredGenerationArtifact {
        nextRequestNumber += 1
        let requestNumber = nextRequestNumber

        return try await withCheckedThrowingContinuation { continuation in
            continuations[requestNumber] = continuation
        }
    }

    func requestCount() -> Int {
        nextRequestNumber
    }

    func resumeRequest(
        _ requestNumber: Int,
        with artifact: StructuredGenerationArtifact
    ) {
        continuations.removeValue(forKey: requestNumber)?.resume(
            returning: artifact
        )
    }
}
#endif
