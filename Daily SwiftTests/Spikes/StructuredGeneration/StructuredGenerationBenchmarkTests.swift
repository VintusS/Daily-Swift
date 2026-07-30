#if DEBUG
import Testing
@testable import DailySwift

struct StructuredGenerationBenchmarkTests {
    @Test("The source-card manifest is frozen")
    func sourceCardManifestIsFrozen() {
        #expect(
            StructuredGenerationFixtures.sourceCards.map(\.id) == [
                "main-actor-state",
                "stale-result-protection",
                "deterministic-validation",
                "cooperative-cancellation",
            ]
        )
        #expect(
            StructuredGenerationFixtures.sourceCards.map {
                $0.text.utf8.count
            } == [189, 201, 180, 175]
        )
        #expect(
            StructuredGenerationFixtures.sourceCards.map(\.contentHash) == [
                "535e5d50fc1c363111a2c2035e9c7c1e754319fe014b4db0b8922d146147db82",
                "68d1b609465457ca7473961e781e111348c6ceebeeee6fd5b9c1a4eb5d3c0927",
                "40e6f797aa9f8a9ed05697c6e8a1e022d53cb32c511917451205b5b13f6f23bd",
                "35a76a76025907dccdf1cfb9974bf4e91f93292b39263e21194dbe7508c9b95a",
            ]
        )
    }

    @Test("The physical-device benchmark schedule is frozen")
    func benchmarkScheduleIsFrozen() {
        let expectedAliases = [
            ["A", "B", "C", "D"],
            ["A"],
            ["A", "B", "C", "D"],
            ["A", "B"],
            ["A", "B", "C", "D"],
            ["A", "B", "C"],
            ["A", "B", "C", "D"],
            ["B"],
            ["A", "B", "C", "D"],
            ["A", "C"],
            ["A", "B", "C", "D"],
            ["A", "B", "D"],
            ["A", "B", "C", "D"],
            ["C"],
            ["A", "B", "C", "D"],
            ["A", "D"],
            ["A", "B", "C", "D"],
            ["A", "C", "D"],
            ["A", "B", "C", "D"],
            ["D"],
            ["A", "B", "C", "D"],
            ["B", "C"],
            ["A", "B", "C", "D"],
            ["B", "C", "D"],
            ["A", "B", "C", "D"],
            ["B", "D"],
            ["A", "B", "C", "D"],
            ["C", "D"],
            ["A", "B", "C", "D"],
            ["A", "B", "C", "D"],
        ]

        #expect(StructuredGenerationBenchmarkPlan.measuredRuns.count == 30)
        #expect(
            StructuredGenerationBenchmarkPlan.measuredRuns.map(\.id)
                == Array(1...30)
        )
        #expect(
            StructuredGenerationBenchmarkPlan.measuredRuns
                .map(\.sourceCardAliases) == expectedAliases
        )
    }

    @Test("Every scheduled request preserves alias order and cardinality")
    func scheduledRequestsPreserveSourceCards() {
        for entry in StructuredGenerationBenchmarkPlan.entries {
            let request = StructuredGenerationBenchmarkPlan.request(for: entry)
            let expectedIDs = entry.sourceCardAliases.compactMap { alias in
                let index = ["A", "B", "C", "D"].firstIndex(of: alias)
                return index.map {
                    StructuredGenerationFixtures.sourceCards[$0].id
                }
            }

            #expect(request.sourceCards.map(\.id) == expectedIDs)
            #expect((1...4).contains(request.sourceCards.count))
        }
    }

    @Test("Request size records every predeclared component")
    func requestSizeRecordsEveryComponent() throws {
        for entry in StructuredGenerationBenchmarkPlan.entries {
            let request = StructuredGenerationBenchmarkPlan.request(for: entry)
            let size = try FoundationModelGenerationClient.requestSize(
                for: request
            )

            #expect(size.instructionsUTF8Bytes > 0)
            #expect(size.promptUTF8Bytes > 0)
            #expect(size.schemaJSONBytes > 0)
            #expect(
                size.totalUTF8Bytes
                    == size.instructionsUTF8Bytes
                        + size.promptUTF8Bytes
                        + size.schemaJSONBytes
            )
        }
    }

    @Test("The deterministic fallback validates for every scheduled subset")
    @MainActor
    func deterministicFallbackSupportsSchedule() async {
        for entry in StructuredGenerationBenchmarkPlan.entries {
            let request = StructuredGenerationBenchmarkPlan.request(for: entry)
            let client = StructuredGenerationFixtures.validClient(for: request)
            let viewModel = StructuredGenerationViewModel(
                request: request,
                client: client
            )

            viewModel.generate()
            await viewModel.waitForCurrentOperation()

            guard case .content = viewModel.state else {
                Issue.record(
                    "Expected content for benchmark entry \(entry.id)"
                )
                continue
            }
        }
    }
}
#endif
