import Foundation
import Testing
@testable import DailySwift

struct SourceRetrievalTests {
    @Test("Query validation happens before private source access")
    func validationPrecedesSourceAccess() async throws {
        let service = InMemorySourceLibraryService(
            restoreOutcomes: [.failure(.readFailed)]
        )
        let retriever = DirectScanSourceRetriever(
            sourceLibrary: service
        )

        await #expect(throws: SourceRetrievalFailure.emptyQuery) {
            try await retriever.search(
                SourceRetrievalRequest(query: " \n ")
            )
        }
        await #expect(throws: SourceRetrievalFailure.queryTooLong) {
            try await retriever.search(
                SourceRetrievalRequest(
                    query: String(
                        repeating: "a",
                        count: SourceRetrievalRequest
                            .maximumQueryCharacterCount + 1
                    )
                )
            )
        }
        await #expect(
            throws: SourceRetrievalFailure.invalidResultLimit
        ) {
            try await retriever.search(
                SourceRetrievalRequest(
                    query: "actor",
                    resultLimit: 0
                )
            )
        }
    }

    @Test("Query tokenization is deterministic and inflection aware")
    func tokenization() {
        #expect(
            SourceRetrievalTokenizer.tokens(
                in: "Protocols, dependencies, VALUES, boxes, and classes"
            ) == [
                "protocol", "dependency", "value", "box", "class",
            ]
        )
        #expect(
            SourceRetrievalTokenizer.tokens(
                in: "values values VALUES"
            ) == ["value"]
        )
        #expect(
            SourceRetrievalTokenizer.tokens(
                in: "values values VALUES",
                keepingDuplicates: true
            ) == ["value", "value", "value"]
        )
    }

    @Test("Direct scan ranks concepts and preserves exact citations")
    func directScanRankingAndCitations() async throws {
        let fixture = RetrievalBenchmarkFixture()
        let retriever = DirectScanSourceRetriever(
            sourceLibrary: fixture.service
        )

        for judgment in fixture.judgments {
            let results = try await retriever.search(
                judgment.request
            )
            let repeatedResults = try await retriever.search(
                judgment.request
            )
            #expect(results == repeatedResults)
            #expect(
                results.first?.document.id
                    == judgment.relevantSourceIDs.first
            )
            for result in results {
                let resolved = try await fixture.service.resolve(
                    result.citation
                )
                #expect(resolved.excerpt == result.excerpt)
                #expect(
                    resolved.citation.contentHash
                        == result.citation.contentHash
                )
            }
        }

        let noResults = try await retriever.search(
            SourceRetrievalRequest(query: "metal rendering pipeline")
        )
        #expect(noResults.isEmpty)
    }

    @Test("Direct scan applies source filters and deletion")
    func sourceFilterAndDeletion() async throws {
        let fixture = RetrievalBenchmarkFixture()
        let retriever = DirectScanSourceRetriever(
            sourceLibrary: fixture.service
        )
        let sourceID = fixture.sourceIDs.stateOwnership
        let request = SourceRetrievalRequest(
            query: "state",
            sourceIDs: [sourceID],
            resultLimit: 8
        )

        let filtered = try await retriever.search(request)
        #expect(!filtered.isEmpty)
        #expect(filtered.allSatisfy { $0.document.id == sourceID })

        try await fixture.service.delete(sourceID: sourceID)
        #expect(try await retriever.search(request).isEmpty)
    }

    @Test("SQLite FTS5 compares against the direct-scan oracle")
    func ftsComparison() async throws {
        let fixture = RetrievalBenchmarkFixture()
        let corpus = try await SourceRetrievalCorpusLoader(
            sourceLibrary: fixture.service
        )
        .load()
        let temporaryRoot = try makeTemporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        let index = SQLiteFTS5SourceRetrievalIndex(
            databaseURL: temporaryRoot
                .appendingPathComponent("retrieval.sqlite")
        )
        try await index.rebuild(from: corpus)

        var initialResults: [[SourceRetrievalMatch]] = []
        for judgment in fixture.judgments {
            let results = try await index.search(
                judgment.request,
                in: corpus
            )
            let repeatedResults = try await index.search(
                judgment.request,
                in: corpus
            )
            initialResults.append(results)
            #expect(results == repeatedResults)
            #expect(
                results.first?.document.id
                    == judgment.relevantSourceIDs.first
            )
            #expect(
                RetrievalBenchmarkMetrics(
                    results: results,
                    relevantSourceIDs: judgment.relevantSourceIDs
                )
                .reciprocalRank == 1
            )
            for result in results {
                #expect(
                    try await fixture.service.resolve(
                        result.citation
                    )
                    .excerpt == result.excerpt
                )
            }
        }

        try await index.rebuild(from: corpus)
        for (offset, judgment) in fixture.judgments.enumerated() {
            #expect(
                try await index.search(
                    judgment.request,
                    in: corpus
                ) == initialResults[offset]
            )
        }

        let filtered = try await index.search(
            SourceRetrievalRequest(
                query: "state",
                sourceIDs: [fixture.sourceIDs.stateOwnership],
                resultLimit: 8
            ),
            in: corpus
        )
        #expect(
            filtered.allSatisfy {
                $0.document.id == fixture.sourceIDs.stateOwnership
            }
        )
        #expect(
            try await index.search(
                SourceRetrievalRequest(
                    query: "metal rendering pipeline"
                ),
                in: corpus
            )
            .isEmpty
        )
    }

    @Test("SQLite FTS5 rebuild removes deleted source entries")
    func ftsRebuildAfterDeletion() async throws {
        let fixture = RetrievalBenchmarkFixture()
        let loader = SourceRetrievalCorpusLoader(
            sourceLibrary: fixture.service
        )
        let temporaryRoot = try makeTemporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        let index = SQLiteFTS5SourceRetrievalIndex(
            databaseURL: temporaryRoot
                .appendingPathComponent("retrieval.sqlite")
        )
        let request = SourceRetrievalRequest(
            query: "cooperative cancellation",
            resultLimit: 8
        )

        var corpus = try await loader.load()
        try await index.rebuild(from: corpus)
        #expect(
            try await index.search(request, in: corpus)
                .contains {
                    $0.document.id
                        == fixture.sourceIDs.cooperativeCancellation
                }
        )

        try await fixture.service.delete(
            sourceID: fixture.sourceIDs.cooperativeCancellation
        )
        corpus = try await loader.load()
        try await index.rebuild(from: corpus)
        #expect(
            try await index.search(request, in: corpus)
                .allSatisfy {
                    $0.document.id
                        != fixture.sourceIDs.cooperativeCancellation
                }
        )
    }

    @Test("Hosted retrieval benchmark records bounded evidence")
    func hostedBenchmark() async throws {
        let fixture = RetrievalBenchmarkFixture()
        let corpus = try await SourceRetrievalCorpusLoader(
            sourceLibrary: fixture.service
        )
        .load()
        let temporaryRoot = try makeTemporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        let databaseURL = temporaryRoot
            .appendingPathComponent("retrieval.sqlite")
        let index = SQLiteFTS5SourceRetrievalIndex(
            databaseURL: databaseURL
        )

        var directMetrics: [RetrievalBenchmarkMetrics] = []
        for judgment in fixture.judgments {
            directMetrics.append(
                RetrievalBenchmarkMetrics(
                    results: DirectScanSourceRetriever.rank(
                        corpus,
                        for: try judgment.request.validated()
                    ),
                    relevantSourceIDs: judgment.relevantSourceIDs
                )
            )
        }

        let buildStart = ContinuousClock.now
        try await index.rebuild(from: corpus)
        let buildDuration = buildStart.duration(to: .now)

        var ftsMetrics: [RetrievalBenchmarkMetrics] = []
        for judgment in fixture.judgments {
            ftsMetrics.append(
                RetrievalBenchmarkMetrics(
                    results: try await index.search(
                        judgment.request,
                        in: corpus
                    ),
                    relevantSourceIDs: judgment.relevantSourceIDs
                )
            )
        }
        let timingIterationCount = 20
        let directStart = ContinuousClock.now
        for _ in 0..<timingIterationCount {
            for judgment in fixture.judgments {
                _ = DirectScanSourceRetriever.rank(
                    corpus,
                    for: try judgment.request.validated()
                )
            }
        }
        let directDuration = directStart.duration(to: .now)
        let ftsStart = ContinuousClock.now
        for _ in 0..<timingIterationCount {
            for judgment in fixture.judgments {
                _ = try await index.search(
                    judgment.request,
                    in: corpus
                )
            }
        }
        let ftsDuration = ftsStart.duration(to: .now)
        let byteCount = try databaseURL.resourceValues(
            forKeys: [.fileSizeKey]
        )
        .fileSize ?? 0
        let evidence = RetrievalBenchmarkEvidence(
            queryCount: fixture.judgments.count,
            corpusCount: corpus.count,
            timingIterationCount: timingIterationCount,
            corpusUTF8Bytes: corpus.reduce(0) {
                $0 + Data(
                    $1.resolvedCitation.excerpt.utf8
                )
                .count
            },
            direct: .aggregate(directMetrics),
            fts: .aggregate(ftsMetrics),
            directSeconds: seconds(directDuration),
            ftsBuildSeconds: seconds(buildDuration),
            ftsQuerySeconds: seconds(ftsDuration),
            ftsStorageBytes: byteCount
        )
        let report = evidence.report

        #expect(evidence.direct.precisionAt1 == 1)
        #expect(evidence.direct.reciprocalRank == 1)
        #expect(evidence.fts.precisionAt1 == 1)
        #expect(evidence.fts.reciprocalRank == 1)
        print(report)
        Attachment.record(
            report,
            named: "retrieval-benchmark.txt"
        )
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "DailySwiftRetrievalTests-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        return root
    }

    private func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

}

private struct RetrievalBenchmarkFixture {
    struct SourceIDs {
        let valueSemantics = UUID(
            uuidString: "61000000-0000-0000-0000-000000000001"
        )!
        let protocolBoundaries = UUID(
            uuidString: "61000000-0000-0000-0000-000000000002"
        )!
        let stateOwnership = UUID(
            uuidString: "61000000-0000-0000-0000-000000000003"
        )!
        let cooperativeCancellation = UUID(
            uuidString: "61000000-0000-0000-0000-000000000004"
        )!
        let storageDistractor = UUID(
            uuidString: "61000000-0000-0000-0000-000000000005"
        )!
    }

    let sourceIDs = SourceIDs()
    let service: InMemorySourceLibraryService
    let judgments: [RetrievalBenchmarkJudgment]

    init() {
        var fixtures: [(UUID, String, String)] = [
            (
                sourceIDs.valueSemantics,
                "Swift value semantics",
                """
                # Value semantics
                A Swift struct copy owns independent stored values. Mutating \
                the copy does not alter the original value.
                """
            ),
            (
                sourceIDs.protocolBoundaries,
                "Protocol dependency boundaries",
                """
                # Protocol dependency boundaries
                A protocol abstracts article loading so dependencies are \
                injected at the composition root.
                """
            ),
            (
                sourceIDs.stateOwnership,
                "SwiftUI state ownership",
                """
                # SwiftUI state ownership
                A view owns local state data when that data belongs to its \
                stable identity and lifecycle.
                """
            ),
            (
                sourceIDs.cooperativeCancellation,
                "Cooperative cancellation",
                """
                # Cooperative cancellation
                Structured concurrency tasks check cancellation and stop \
                obsolete async work before publishing stale state.
                """
            ),
            (
                sourceIDs.storageDistractor,
                "Application storage",
                """
                # Application storage
                Persisted state records article data. Storage migration keeps \
                saved records compatible across schema versions.
                """
            ),
        ]
        let distractorBodies = [
            "Swift state storage records data for offline reading.",
            "A protocol describes one service boundary.",
            "A copied value appears in an unrelated storage example.",
            "A cooperative task performs unrelated scheduled work.",
            "Cancellation appears in a networking status message.",
        ]
        for index in 0..<100 {
            let suffix = String(format: "%012d", index + 1)
            fixtures.append(
                (
                    UUID(
                        uuidString:
                            "62000000-0000-0000-0000-\(suffix)"
                    )!,
                    "Synthetic distractor \(index + 1)",
                    """
                    # Reference section \(index + 1)
                    \(distractorBodies[index % distractorBodies.count])
                    """
                )
            )
        }
        var documents: [SourceDocument] = []
        var chunks: [SourceChunk] = []
        var normalizedTextBySourceID: [UUID: String] = [:]

        for (index, fixture) in fixtures.enumerated() {
            let text = SourceTextProcessor.normalize(fixture.2)
            let contentHash = SourceTextProcessor.contentHash(for: text)
            documents.append(
                SourceDocument(
                    id: fixture.0,
                    title: fixture.1,
                    author: "Project Fixture",
                    publisher: nil,
                    originFileName: "fixture-\(index).md",
                    rightsStatus: .openLicensed,
                    contentHash: contentHash,
                    importedAt: Date(
                        timeIntervalSince1970: 1_785_200_000
                            + Double(index)
                    ),
                    format: .markdown,
                    byteCount: Data(text.utf8).count
                )
            )
            chunks.append(
                contentsOf: SourceTextProcessor.chunks(
                    sourceID: fixture.0,
                    sourceContentHash: contentHash,
                    normalizedText: text,
                    format: .markdown
                )
            )
            normalizedTextBySourceID[fixture.0] = text
        }

        service = InMemorySourceLibraryService(
            snapshot: SourceLibrarySnapshot(
                documents: documents,
                chunks: chunks
            ),
            normalizedTextBySourceID: normalizedTextBySourceID
        )
        judgments = [
            RetrievalBenchmarkJudgment(
                request: SourceRetrievalRequest(
                    query: "value semantics"
                ),
                relevantSourceIDs: [sourceIDs.valueSemantics]
            ),
            RetrievalBenchmarkJudgment(
                request: SourceRetrievalRequest(
                    query: "protocol dependencies"
                ),
                relevantSourceIDs: [sourceIDs.protocolBoundaries]
            ),
            RetrievalBenchmarkJudgment(
                request: SourceRetrievalRequest(
                    query: "state ownership"
                ),
                relevantSourceIDs: [sourceIDs.stateOwnership]
            ),
            RetrievalBenchmarkJudgment(
                request: SourceRetrievalRequest(
                    query: "cooperative cancellation"
                ),
                relevantSourceIDs: [
                    sourceIDs.cooperativeCancellation,
                ]
            ),
            RetrievalBenchmarkJudgment(
                request: SourceRetrievalRequest(
                    query: "state data",
                    resultLimit: 3
                ),
                relevantSourceIDs: [
                    sourceIDs.stateOwnership,
                    sourceIDs.storageDistractor,
                ]
            ),
        ]
    }
}

private struct RetrievalBenchmarkJudgment {
    let request: SourceRetrievalRequest
    let relevantSourceIDs: [UUID]
}

private struct RetrievalBenchmarkMetrics {
    let precisionAt1: Double
    let precisionAt3: Double
    let reciprocalRank: Double

    init(
        results: [SourceRetrievalMatch],
        relevantSourceIDs: [UUID]
    ) {
        let relevant = Set(relevantSourceIDs)
        precisionAt1 = results.first.map {
            relevant.contains($0.document.id) ? 1 : 0
        } ?? 0
        precisionAt3 = Double(
            results.prefix(3).filter {
                relevant.contains($0.document.id)
            }
            .count
        ) / 3
        if let rank = results.firstIndex(where: {
            relevant.contains($0.document.id)
        }) {
            reciprocalRank = 1 / Double(rank + 1)
        } else {
            reciprocalRank = 0
        }
    }

    static func aggregate(
        _ metrics: [RetrievalBenchmarkMetrics]
    ) -> RetrievalBenchmarkMetrics {
        guard !metrics.isEmpty else {
            return RetrievalBenchmarkMetrics(
                precisionAt1: 0,
                precisionAt3: 0,
                reciprocalRank: 0
            )
        }
        let count = Double(metrics.count)
        return RetrievalBenchmarkMetrics(
            precisionAt1: metrics.reduce(0) {
                $0 + $1.precisionAt1
            } / count,
            precisionAt3: metrics.reduce(0) {
                $0 + $1.precisionAt3
            } / count,
            reciprocalRank: metrics.reduce(0) {
                $0 + $1.reciprocalRank
            } / count
        )
    }

    private init(
        precisionAt1: Double,
        precisionAt3: Double,
        reciprocalRank: Double
    ) {
        self.precisionAt1 = precisionAt1
        self.precisionAt3 = precisionAt3
        self.reciprocalRank = reciprocalRank
    }
}

private struct RetrievalBenchmarkEvidence {
    let queryCount: Int
    let corpusCount: Int
    let timingIterationCount: Int
    let corpusUTF8Bytes: Int
    let direct: RetrievalBenchmarkMetrics
    let fts: RetrievalBenchmarkMetrics
    let directSeconds: Double
    let ftsBuildSeconds: Double
    let ftsQuerySeconds: Double
    let ftsStorageBytes: Int

    var report: String {
        [
            "retrieval_benchmark_version=1",
            "query_count=\(queryCount)",
            "corpus_count=\(corpusCount)",
            "timing_iteration_count=\(timingIterationCount)",
            "corpus_utf8_bytes=\(corpusUTF8Bytes)",
            "direct_precision_at_1=\(direct.precisionAt1)",
            "direct_precision_at_3=\(direct.precisionAt3)",
            "direct_reciprocal_rank=\(direct.reciprocalRank)",
            "fts_precision_at_1=\(fts.precisionAt1)",
            "fts_precision_at_3=\(fts.precisionAt3)",
            "fts_reciprocal_rank=\(fts.reciprocalRank)",
            "direct_query_seconds=\(directSeconds)",
            "fts_build_seconds=\(ftsBuildSeconds)",
            "fts_query_seconds=\(ftsQuerySeconds)",
            "fts_storage_bytes=\(ftsStorageBytes)",
        ]
        .joined(separator: "\n")
    }
}
