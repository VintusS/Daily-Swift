import Foundation

enum GeneratedLearningVersion {
    static let prompt = "generated-learning-v1"
    static let candidateSchema = 1
}

enum GeneratedLearningTrust: String, Codable, Equatable, Sendable {
    case experimentalUserMaterial

    var label: String {
        "Experimental / User Material"
    }
}

struct GeneratedLearningSourceReference: Codable, Equatable, Hashable,
    Identifiable, Sendable {
    let id: String
    let documentTitle: String
    let rightsStatus: SourceRightsStatus
    let citation: SourceCitation
}

struct GeneratedLearningArticle: Codable, Equatable, Sendable {
    let title: String
    let learningObjective: String
    let explanation: String
    let exampleCode: String?
    let citationReferenceIDs: [String]
}

struct GeneratedLearningQuizChoice: Codable, Equatable, Identifiable,
    Sendable {
    let id: String
    let text: String
}

struct GeneratedLearningQuiz: Codable, Equatable, Sendable {
    let prompt: String
    let choices: [GeneratedLearningQuizChoice]
    let answerKeyChoiceID: String
    let explanation: String
    let citationReferenceIDs: [String]
}

struct GeneratedLearningArtifact: Codable, Equatable, Identifiable, Sendable {
    static let currentSchemaVersion = 1

    let id: UUID
    let schemaVersion: Int
    let topic: String
    let promptVersion: String
    let candidateSchemaVersion: Int
    let providerRuntimeLabel: String
    let sourceSetHash: String
    let createdAt: Date
    let trust: GeneratedLearningTrust
    let sourceReferences: [GeneratedLearningSourceReference]
    let article: GeneratedLearningArticle
    let quiz: GeneratedLearningQuiz

    var articleID: String {
        "generated.article.\(id.uuidString.lowercased())"
    }

    var quizID: String {
        "generated.quiz.\(id.uuidString.lowercased())"
    }

    func sourceReference(
        id referenceID: String
    ) -> GeneratedLearningSourceReference? {
        sourceReferences.first { $0.id == referenceID }
    }

    func references(sourceID: UUID) -> Bool {
        sourceReferences.contains {
            $0.citation.sourceID == sourceID
        }
    }
}

enum GeneratedLearningStoreFailure: Error, Equatable, Sendable {
    case initializationFailed
    case readFailed
    case writeFailed
    case deleteFailed
    case unsupportedSchema
    case corruptArtifact
}
