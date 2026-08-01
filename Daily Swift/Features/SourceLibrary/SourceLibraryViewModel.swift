import Foundation
import Observation

enum SourceLibraryLoadState: Equatable, Sendable {
    case loading
    case ready
    case failed(SourceLibraryFailure)
}

enum SourceLibraryFeedback: Equatable, Sendable {
    case idle
    case cancelled
    case imported(sourceID: UUID)
    case duplicate(existingSourceID: UUID)
    case deleted
    case failed(SourceLibraryFailure)

    var announcement: String? {
        switch self {
        case .idle:
            nil
        case .cancelled:
            "Source import cancelled. Nothing changed."
        case .imported:
            "Source imported and available offline."
        case .duplicate:
            "This source is already in the library."
        case .deleted:
            "Source and derived passages deleted."
        case let .failed(failure):
            "\(failure.title). \(failure.message)"
        }
    }
}

struct PendingSourceImport: Identifiable, Equatable, Sendable {
    let id: UUID
    let fileURL: URL
    let suggestedTitle: String

    init(fileURL: URL) {
        id = UUID()
        self.fileURL = fileURL
        suggestedTitle = fileURL
            .deletingPathExtension()
            .lastPathComponent
    }
}

@MainActor
@Observable
final class SourceLibraryViewModel {
    private(set) var state: SourceLibraryLoadState = .loading
    private(set) var snapshot: SourceLibrarySnapshot = .empty
    private(set) var feedback: SourceLibraryFeedback = .idle
    private(set) var pendingImport: PendingSourceImport?
    private(set) var isImporting = false
    private(set) var deletingSourceID: UUID?

    @ObservationIgnored
    private let service: any SourceLibraryServing

    @ObservationIgnored
    private let sourceDeleter: any LearningSourceDeleting

    init(
        service: any SourceLibraryServing,
        sourceDeleter: (any LearningSourceDeleting)? = nil
    ) {
        self.service = service
        self.sourceDeleter = sourceDeleter
            ?? DirectLearningSourceDeleter(sourceLibrary: service)
    }

    var documents: [SourceDocument] {
        snapshot.documents
    }

    func document(id: UUID) -> SourceDocument? {
        snapshot.document(id: id)
    }

    func chunks(for sourceID: UUID) -> [SourceChunk] {
        snapshot.chunks(for: sourceID)
    }

    func loadIfNeeded() async {
        guard state == .loading else {
            return
        }
        await load()
    }

    func retryLoad() {
        state = .loading
        Task {
            await load()
        }
    }

    func receiveFileSelection(
        _ result: Result<[URL], any Error>
    ) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                feedback = .cancelled
                return
            }
            feedback = .idle
            pendingImport = PendingSourceImport(fileURL: url)

        case let .failure(error):
            let cocoaError = error as NSError
            if cocoaError.domain == NSCocoaErrorDomain,
               cocoaError.code == NSUserCancelledError {
                feedback = .cancelled
            } else {
                feedback = .failed(.unreadableFile)
            }
        }
    }

    func cancelPendingImport() {
        pendingImport = nil
        feedback = .cancelled
    }

    func recordPickerCancellation() {
        feedback = .cancelled
    }

    func importPending(
        metadata: SourceImportMetadata
    ) async {
        guard let pendingImport,
              !isImporting else {
            return
        }

        isImporting = true
        feedback = .idle
        defer {
            isImporting = false
            self.pendingImport = nil
        }

        do {
            let document = try await service.importSource(
                SourceImportRequest(
                    fileURL: pendingImport.fileURL,
                    metadata: metadata
                )
            )
            snapshot = try await service.restore()
            state = .ready
            feedback = .imported(sourceID: document.id)
        } catch let failure as SourceLibraryFailure {
            if failure == .importCancelled {
                feedback = .cancelled
            } else if case let .duplicate(existingSourceID) = failure {
                feedback = .duplicate(
                    existingSourceID: existingSourceID
                )
            } else {
                feedback = .failed(failure)
            }
        } catch {
            feedback = .failed(.writeFailed)
        }
    }

    func resolve(
        _ citation: SourceCitation
    ) async throws -> ResolvedSourceCitation {
        try await service.resolve(citation)
    }

    @discardableResult
    func delete(sourceID: UUID) async -> Bool {
        guard deletingSourceID == nil else {
            return false
        }
        deletingSourceID = sourceID
        feedback = .idle
        defer {
            deletingSourceID = nil
        }

        do {
            try await sourceDeleter.deleteSource(id: sourceID)
            snapshot = try await service.restore()
            state = .ready
            feedback = .deleted
            return true
        } catch let failure as SourceLibraryFailure {
            feedback = .failed(failure)
            return false
        } catch {
            feedback = .failed(.deleteFailed)
            return false
        }
    }

    func clearFeedback() {
        feedback = .idle
    }

    private func load() async {
        do {
            snapshot = try await service.restore()
            state = .ready
        } catch let failure as SourceLibraryFailure {
            state = .failed(failure)
        } catch {
            state = .failed(.readFailed)
        }
    }
}
