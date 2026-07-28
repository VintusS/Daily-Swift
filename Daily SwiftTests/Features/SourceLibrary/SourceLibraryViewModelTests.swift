import Foundation
import Testing
@testable import DailySwift

@MainActor
struct SourceLibraryViewModelTests {
    @Test("Load failure is explicit and retryable")
    func loadRetry() async {
        let service = InMemorySourceLibraryService(
            restoreOutcomes: [
                .failure(.readFailed),
                .success(()),
            ]
        )
        let viewModel = SourceLibraryViewModel(service: service)

        await viewModel.loadIfNeeded()
        #expect(viewModel.state == .failed(.readFailed))

        viewModel.retryLoad()
        for _ in 0..<20 {
            guard viewModel.state == .loading else {
                break
            }
            await Task.yield()
        }

        #expect(viewModel.state == .ready)
        #expect(viewModel.snapshot == .empty)
    }

    @Test("Selection, cancellation, import, duplicate, and deletion update state")
    func importLifecycle() async throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "DailySwiftSourceViewModelTests-\(UUID().uuidString)",
                isDirectory: true
            )
        defer {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: true
        )
        let sourceURL = temporaryRoot.appendingPathComponent("notes.md")
        try Data("# Notes\nExact text.".utf8).write(to: sourceURL)
        let sourceID = UUID(
            uuidString: "88888888-8888-8888-8888-888888888888"
        )!
        let service = InMemorySourceLibraryService(
            makeSourceID: { sourceID }
        )
        let viewModel = SourceLibraryViewModel(service: service)
        await viewModel.loadIfNeeded()

        viewModel.receiveFileSelection(.success([sourceURL]))
        #expect(viewModel.pendingImport?.suggestedTitle == "notes")
        viewModel.cancelPendingImport()
        #expect(viewModel.feedback == .cancelled)

        viewModel.receiveFileSelection(.success([sourceURL]))
        await viewModel.importPending(
            metadata: SourceImportMetadata(
                title: "Notes",
                author: nil,
                publisher: nil,
                rightsStatus: .publicDomain
            )
        )
        #expect(viewModel.feedback == .imported(sourceID: sourceID))
        #expect(viewModel.documents.count == 1)
        #expect(viewModel.chunks(for: sourceID).count == 1)

        viewModel.receiveFileSelection(.success([sourceURL]))
        await viewModel.importPending(
            metadata: SourceImportMetadata(
                title: "Duplicate",
                author: nil,
                publisher: nil,
                rightsStatus: .publicDomain
            )
        )
        #expect(
            viewModel.feedback
                == .duplicate(existingSourceID: sourceID)
        )
        #expect(viewModel.documents.count == 1)

        #expect(await viewModel.delete(sourceID: sourceID))
        #expect(viewModel.feedback == .deleted)
        #expect(viewModel.snapshot == .empty)
    }
}
