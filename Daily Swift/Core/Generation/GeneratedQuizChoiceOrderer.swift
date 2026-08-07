import Foundation

enum GeneratedQuizChoiceOrderer {
    static func orderedChoices(
        _ choices: [GeneratedLearningQuizChoice],
        artifactID: UUID
    ) -> [GeneratedLearningQuizChoice] {
        var orderedChoices = choices
        var generator = GeneratedQuizSeededRandomNumberGenerator(
            seed: seed(for: artifactID)
        )
        orderedChoices.shuffle(using: &generator)
        return orderedChoices
    }

    private static func seed(for artifactID: UUID) -> UInt64 {
        var value: UInt64 = 14_695_981_039_346_656_037
        for byte in artifactID.uuidString.utf8 {
            value ^= UInt64(byte)
            value &*= 1_099_511_628_211
        }
        return value
    }
}

private struct GeneratedQuizSeededRandomNumberGenerator:
    RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
