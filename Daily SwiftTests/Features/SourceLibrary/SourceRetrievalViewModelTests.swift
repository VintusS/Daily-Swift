import Foundation
import Testing
@testable import DailySwift

@MainActor
struct SourceRetrievalViewModelTests {
    @Test("Search publishes progress and exact results")
    func results() async throws {
        let match = try await fixtureMatch(query: "actor isolation")
        let retriever = InMemorySourceRetriever(
            outcomes: [.success([match])]
        )
        let viewModel = SourceRetrievalViewModel(
            retriever: retriever
        )

        viewModel.search(query: "actor isolation")
        #expect(viewModel.state == .searching)
        await waitUntil { viewModel.resultCount == 1 }

        #expect(viewModel.state == .results([match]))
        #expect(viewModel.state.announcement
            == "Search complete. 1 exact passage available.")
    }

    @Test("Invalid and empty-result searches are explicit")
    func invalidAndNoResults() async {
        let retriever = InMemorySourceRetriever(
            outcomes: [.success([])]
        )
        let viewModel = SourceRetrievalViewModel(
            retriever: retriever
        )

        viewModel.search(query: "the and of")
        #expect(viewModel.state == .failed(.invalidQuery))

        viewModel.search(query: "unmatched concept")
        await waitUntil { viewModel.state == .noResults }
        #expect(viewModel.state == .noResults)
    }

    @Test("Selected filters are sent and removed with deleted sources")
    func filtersAndDeletionReconciliation() async throws {
        let match = try await fixtureMatch(query: "actor isolation")
        let retriever = RecordingSourceRetriever(results: [match])
        let viewModel = SourceRetrievalViewModel(
            retriever: retriever
        )

        viewModel.toggleSourceFilter(match.document.id)
        viewModel.search(query: "actor isolation")
        await waitUntil { viewModel.resultCount == 1 }

        let requests = await retriever.recordedRequests()
        #expect(requests.count == 1)
        #expect(
            requests[0].sourceIDs == [match.document.id]
        )

        viewModel.reconcileAvailableSources([])
        #expect(viewModel.selectedSourceIDs.isEmpty)
        #expect(viewModel.state == .noResults)
    }

    @Test("Failure is retryable without exposing private values")
    func errorAndRetry() async throws {
        let match = try await fixtureMatch(query: "actor isolation")
        let retriever = InMemorySourceRetriever(
            outcomes: [
                .failure(.sourceUnavailable),
                .success([match]),
            ]
        )
        let viewModel = SourceRetrievalViewModel(
            retriever: retriever
        )

        viewModel.search(query: "actor isolation")
        await waitUntil {
            viewModel.state == .failed(.unavailable)
        }
        #expect(viewModel.state == .failed(.unavailable))

        viewModel.retry()
        await waitUntil { viewModel.resultCount == 1 }
        #expect(viewModel.state == .results([match]))
    }

    @Test("Cancellation is visible and does not publish results")
    func cancellation() async {
        let retriever = ViewModelCancellableRetriever()
        let viewModel = SourceRetrievalViewModel(
            retriever: retriever
        )

        viewModel.search(query: "actor isolation")
        #expect(viewModel.state == .searching)
        await Task.yield()
        viewModel.cancel()
        for _ in 0..<100 {
            if await retriever.observedCancellation() {
                break
            }
            await Task.yield()
        }

        #expect(viewModel.state == .cancelled)
        #expect(await retriever.observedCancellation())
    }

    @Test("An obsolete completion cannot replace a newer result")
    func staleCompletionIsIgnored() async throws {
        let oldMatch = try await fixtureMatch(
            query: "actor isolation"
        )
        let newMatch = try await fixtureMatch(
            query: "exact citations"
        )
        let retriever = ReorderingSourceRetriever(
            oldMatch: oldMatch,
            newMatch: newMatch
        )
        let viewModel = SourceRetrievalViewModel(
            retriever: retriever
        )

        viewModel.search(query: "first concept")
        await Task.yield()
        viewModel.search(query: "second concept")
        await waitUntil {
            viewModel.state == .results([newMatch])
        }
        await retriever.releaseFirstSearch()
        for _ in 0..<10 {
            await Task.yield()
        }

        #expect(viewModel.state == .results([newMatch]))
    }

    private func fixtureMatch(
        query: String
    ) async throws -> SourceRetrievalMatch {
        let service = SourceLibraryFixtures.service()
        let results = try await DirectScanSourceRetriever(
            sourceLibrary: service
        )
        .search(
            SourceRetrievalRequest(
                query: query,
                resultLimit: 1
            )
        )
        return try #require(results.first)
    }

    private func waitUntil(
        _ predicate: @MainActor () -> Bool
    ) async {
        for _ in 0..<100 where !predicate() {
            await Task.yield()
        }
    }
}

private actor RecordingSourceRetriever: SourceRetrieving {
    private let results: [SourceRetrievalMatch]
    private var requests: [SourceRetrievalRequest] = []

    init(results: [SourceRetrievalMatch]) {
        self.results = results
    }

    func search(
        _ request: SourceRetrievalRequest
    ) async throws(SourceRetrievalFailure) -> [SourceRetrievalMatch] {
        _ = try request.validated()
        requests.append(request)
        return results
    }

    func recordedRequests() -> [SourceRetrievalRequest] {
        requests
    }
}

private actor ViewModelCancellableRetriever: SourceRetrieving {
    private var didObserveCancellation = false

    func search(
        _ request: SourceRetrievalRequest
    ) async throws(SourceRetrievalFailure) -> [SourceRetrievalMatch] {
        _ = try request.validated()
        while !Task.isCancelled {
            await Task.yield()
        }
        didObserveCancellation = true
        throw .cancelled
    }

    func observedCancellation() -> Bool {
        didObserveCancellation
    }
}

private actor ReorderingSourceRetriever: SourceRetrieving {
    private let oldMatch: SourceRetrievalMatch
    private let newMatch: SourceRetrievalMatch
    private var canFinishFirstSearch = false

    init(
        oldMatch: SourceRetrievalMatch,
        newMatch: SourceRetrievalMatch
    ) {
        self.oldMatch = oldMatch
        self.newMatch = newMatch
    }

    func search(
        _ request: SourceRetrievalRequest
    ) async throws(SourceRetrievalFailure) -> [SourceRetrievalMatch] {
        let request = try request.validated()
        if request.query == "first concept" {
            while !canFinishFirstSearch {
                await Task.yield()
            }
            return [oldMatch]
        }
        return [newMatch]
    }

    func releaseFirstSearch() {
        canFinishFirstSearch = true
    }
}
