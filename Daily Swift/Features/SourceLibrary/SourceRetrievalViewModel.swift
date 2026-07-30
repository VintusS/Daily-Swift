import Foundation
import Observation

enum SourceRetrievalPresentationFailure: Equatable, Sendable {
    case invalidQuery
    case queryTooLong
    case unavailable

    var title: String {
        switch self {
        case .invalidQuery:
            "Add a searchable concept"
        case .queryTooLong:
            "Search is too long"
        case .unavailable:
            "Imported passages are unavailable"
        }
    }

    var message: String {
        switch self {
        case .invalidQuery:
            "Use at least one specific term instead of only punctuation or common words."
        case .queryTooLong:
            "Keep the search to 200 characters or fewer."
        case .unavailable:
            "Daily Swift could not verify the current local passages. Imported sources and reviewed articles remain unchanged."
        }
    }
}

enum SourceRetrievalViewState: Equatable, Sendable {
    case idle
    case searching
    case results([SourceRetrievalMatch])
    case noResults
    case cancelled
    case failed(SourceRetrievalPresentationFailure)

    var announcement: String? {
        switch self {
        case .idle, .searching:
            nil
        case let .results(results):
            "Search complete. \(results.count) exact \(results.count == 1 ? "passage" : "passages") available."
        case .noResults:
            "Search complete. No exact passages found."
        case .cancelled:
            "Source search cancelled."
        case let .failed(failure):
            "\(failure.title). \(failure.message)"
        }
    }
}

@MainActor
@Observable
final class SourceRetrievalViewModel {
    private(set) var state: SourceRetrievalViewState = .idle
    private(set) var selectedSourceIDs: Set<UUID> = []

    @ObservationIgnored
    private let retriever: any SourceRetrieving

    @ObservationIgnored
    private var activeSearch: Task<Void, Never>?

    @ObservationIgnored
    private var activeSearchID: UUID?

    @ObservationIgnored
    private var lastSubmittedQuery: String?

    init(retriever: any SourceRetrieving) {
        self.retriever = retriever
    }

    var isSearching: Bool {
        state == .searching
    }

    var resultCount: Int {
        guard case let .results(results) = state else {
            return 0
        }
        return results.count
    }

    func search(query: String) {
        cancelActiveSearch(publishingCancellation: false)

        let request = SourceRetrievalRequest(
            query: query,
            sourceIDs: selectedSourceIDs,
            resultLimit: SourceRetrievalRequest.maximumResultCount
        )
        do {
            _ = try request.validated()
        } catch .emptyQuery {
            lastSubmittedQuery = nil
            state = .failed(.invalidQuery)
            return
        } catch .queryTooLong {
            lastSubmittedQuery = nil
            state = .failed(.queryTooLong)
            return
        } catch {
            lastSubmittedQuery = nil
            state = .failed(.invalidQuery)
            return
        }

        lastSubmittedQuery = query
        let searchID = UUID()
        activeSearchID = searchID
        state = .searching
        let retriever = retriever

        activeSearch = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let results = try await retriever.search(request)
                guard isActive(searchID), !Task.isCancelled else {
                    return
                }
                finish(
                    searchID,
                    state: results.isEmpty
                        ? .noResults
                        : .results(results)
                )
            } catch let failure as SourceRetrievalFailure {
                guard isActive(searchID) else {
                    return
                }
                switch failure {
                case .cancelled:
                    finish(searchID, state: .cancelled)
                case .emptyQuery, .invalidResultLimit:
                    finish(
                        searchID,
                        state: .failed(.invalidQuery)
                    )
                case .queryTooLong:
                    finish(
                        searchID,
                        state: .failed(.queryTooLong)
                    )
                case .sourceUnavailable, .indexUnavailable:
                    finish(
                        searchID,
                        state: .failed(.unavailable)
                    )
                }
            } catch {
                guard isActive(searchID) else {
                    return
                }
                finish(
                    searchID,
                    state: .failed(.unavailable)
                )
            }
        }
    }

    func retry() {
        guard let lastSubmittedQuery else {
            state = .idle
            return
        }
        search(query: lastSubmittedQuery)
    }

    func cancel() {
        cancelActiveSearch(publishingCancellation: true)
    }

    func queryChanged() {
        cancelActiveSearch(publishingCancellation: false)
        lastSubmittedQuery = nil
        state = .idle
    }

    func toggleSourceFilter(_ sourceID: UUID) {
        if selectedSourceIDs.contains(sourceID) {
            selectedSourceIDs.remove(sourceID)
        } else {
            selectedSourceIDs.insert(sourceID)
        }
    }

    func clearSourceFilters() {
        selectedSourceIDs.removeAll()
    }

    func reconcileAvailableSources(
        _ availableSourceIDs: Set<UUID>
    ) {
        selectedSourceIDs.formIntersection(availableSourceIDs)

        if activeSearchID != nil {
            cancelActiveSearch(publishingCancellation: false)
            state = .idle
            return
        }

        guard case let .results(results) = state else {
            return
        }
        let currentResults = results.filter {
            availableSourceIDs.contains($0.document.id)
        }
        guard currentResults != results else {
            return
        }
        state = currentResults.isEmpty
            ? .noResults
            : .results(currentResults)
    }

    private func cancelActiveSearch(
        publishingCancellation: Bool
    ) {
        let hadActiveSearch = activeSearchID != nil
        activeSearchID = nil
        let search = activeSearch
        activeSearch = nil
        search?.cancel()

        if publishingCancellation && hadActiveSearch {
            state = .cancelled
        }
    }

    private func isActive(_ searchID: UUID) -> Bool {
        activeSearchID == searchID
    }

    private func finish(
        _ searchID: UUID,
        state newState: SourceRetrievalViewState
    ) {
        guard isActive(searchID) else {
            return
        }
        state = newState
        activeSearchID = nil
        activeSearch = nil
    }
}
