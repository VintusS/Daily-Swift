#if DEBUG
import Darwin
import Foundation
import UIKit

struct StructuredGenerationBenchmarkEntry: Identifiable, Equatable, Sendable {
    let id: Int
    let sourceCardAliases: [String]

    var title: String {
        id == 0 ? "Unscored warm-up" : "Measured run \(id) of 30"
    }

    var sourceCardSummary: String {
        sourceCardAliases.joined(separator: " + ")
    }
}

enum StructuredGenerationBenchmarkPlan {
    static let warmUp = StructuredGenerationBenchmarkEntry(
        id: 0,
        sourceCardAliases: ["A", "B", "C", "D"]
    )

    static let measuredRuns = [
        entry(1, ["A", "B", "C", "D"]),
        entry(2, ["A"]),
        entry(3, ["A", "B", "C", "D"]),
        entry(4, ["A", "B"]),
        entry(5, ["A", "B", "C", "D"]),
        entry(6, ["A", "B", "C"]),
        entry(7, ["A", "B", "C", "D"]),
        entry(8, ["B"]),
        entry(9, ["A", "B", "C", "D"]),
        entry(10, ["A", "C"]),
        entry(11, ["A", "B", "C", "D"]),
        entry(12, ["A", "B", "D"]),
        entry(13, ["A", "B", "C", "D"]),
        entry(14, ["C"]),
        entry(15, ["A", "B", "C", "D"]),
        entry(16, ["A", "D"]),
        entry(17, ["A", "B", "C", "D"]),
        entry(18, ["A", "C", "D"]),
        entry(19, ["A", "B", "C", "D"]),
        entry(20, ["D"]),
        entry(21, ["A", "B", "C", "D"]),
        entry(22, ["B", "C"]),
        entry(23, ["A", "B", "C", "D"]),
        entry(24, ["B", "C", "D"]),
        entry(25, ["A", "B", "C", "D"]),
        entry(26, ["B", "D"]),
        entry(27, ["A", "B", "C", "D"]),
        entry(28, ["C", "D"]),
        entry(29, ["A", "B", "C", "D"]),
        entry(30, ["A", "B", "C", "D"]),
    ]

    static let entries = [warmUp] + measuredRuns

    static func request(
        for entry: StructuredGenerationBenchmarkEntry
    ) -> StructuredGenerationRequest {
        let cards = entry.sourceCardAliases.map(sourceCard(for:))
        return StructuredGenerationFixtures.request(sourceCards: cards)
    }

    private static func entry(
        _ id: Int,
        _ aliases: [String]
    ) -> StructuredGenerationBenchmarkEntry {
        StructuredGenerationBenchmarkEntry(
            id: id,
            sourceCardAliases: aliases
        )
    }

    private static func sourceCard(
        for alias: String
    ) -> StructuredGenerationSourceCard {
        guard let index = ["A", "B", "C", "D"].firstIndex(of: alias) else {
            preconditionFailure("Unknown frozen source-card alias")
        }
        return StructuredGenerationFixtures.sourceCards[index]
    }
}

struct StructuredGenerationDeviceSnapshot: Equatable, Sendable {
    let hardwareIdentifier: String
    let operatingSystem: String
    let localeIdentifier: String
    let regionIdentifier: String
    let powerState: String
    let batteryLevel: String
    let thermalState: String

    @MainActor
    static func capture() -> StructuredGenerationDeviceSnapshot {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true

        return StructuredGenerationDeviceSnapshot(
            hardwareIdentifier: currentHardwareIdentifier(),
            operatingSystem: ProcessInfo.processInfo
                .operatingSystemVersionString,
            localeIdentifier: Locale.current.identifier,
            regionIdentifier: Locale.current.region?.identifier ?? "Unknown",
            powerState: powerStateLabel(device.batteryState),
            batteryLevel: batteryLevelLabel(device.batteryLevel),
            thermalState: thermalStateLabel(
                ProcessInfo.processInfo.thermalState
            )
        )
    }

    private static func currentHardwareIdentifier() -> String {
        var byteCount = 0
        guard sysctlbyname("hw.machine", nil, &byteCount, nil, 0) == 0 else {
            return "Unknown"
        }

        var bytes = [CChar](repeating: 0, count: byteCount)
        guard sysctlbyname("hw.machine", &bytes, &byteCount, nil, 0) == 0 else {
            return "Unknown"
        }
        if bytes.last == 0 {
            bytes.removeLast()
        }
        return String(decoding: bytes.map(UInt8.init), as: UTF8.self)
    }

    private static func powerStateLabel(
        _ state: UIDevice.BatteryState
    ) -> String {
        switch state {
        case .unknown:
            "Unknown"
        case .unplugged:
            "Battery"
        case .charging:
            "Charging"
        case .full:
            "External power, full"
        @unknown default:
            "Unknown"
        }
    }

    private static func batteryLevelLabel(_ level: Float) -> String {
        guard level >= 0 else {
            return "Unknown"
        }
        return "\(Int((level * 100).rounded()))%"
    }

    private static func thermalStateLabel(
        _ state: ProcessInfo.ThermalState
    ) -> String {
        switch state {
        case .nominal:
            "Nominal"
        case .fair:
            "Fair"
        case .serious:
            "Serious"
        case .critical:
            "Critical"
        @unknown default:
            "Unknown"
        }
    }
}

enum StructuredGenerationEvidenceReporter {
    static let launchArgument =
        "--report-structured-generation-environment"

    @MainActor
    static func reportIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else {
            return
        }

        let snapshot = StructuredGenerationDeviceSnapshot.capture()
        let availability = await FoundationModelGenerationClient()
            .availability()
        let fields = [
            "hardware=\(snapshot.hardwareIdentifier)",
            "os=\(snapshot.operatingSystem)",
            "locale=\(snapshot.localeIdentifier)",
            "region=\(snapshot.regionIdentifier)",
            "modelAvailability=\(label(for: availability))",
            "power=\(snapshot.powerState)",
            "battery=\(snapshot.batteryLevel)",
            "thermal=\(snapshot.thermalState)",
        ]
        print("Packet 000-A environment | \(fields.joined(separator: " | "))")
    }

    static func label(
        for availability: StructuredGenerationAvailability
    ) -> String {
        switch availability {
        case .available:
            "available"
        case .unavailable(.deviceNotSupported):
            "device-not-supported"
        case .unavailable(.intelligenceDisabled):
            "apple-intelligence-disabled"
        case .unavailable(.modelNotReady):
            "model-not-ready"
        case .unavailable(.languageOrRegionUnsupported):
            "locale-or-region-unsupported"
        case .unavailable(.other):
            "other-unavailable"
        }
    }
}
#endif
