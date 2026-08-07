#if DEBUG
import Foundation

enum GeneratedLearningDebugFixtures {
    static let artifactID = UUID(
        uuidString: "77000000-0000-0000-0000-000000000001"
    )!

    static var artifact: GeneratedLearningArtifact {
        let sourceChunk = SourceLibraryFixtures.chunks[0]
        let citation = sourceChunk.citation
        let reference = GeneratedLearningSourceReference(
            id: "source-card-1",
            documentTitle: SourceLibraryFixtures.document.title,
            rightsStatus: SourceLibraryFixtures.document.rightsStatus,
            citation: citation
        )
        let sourceCard = LanguageModelSourceCard(
            id: reference.id,
            documentTitle: reference.documentTitle,
            locationLabel: [
                citation.headingLabel,
                citation.location.pageLabel,
                citation.location.lineLabel,
            ]
            .compactMap(\.self)
            .joined(separator: " · "),
            rightsStatus: reference.rightsStatus,
            contentHash: citation.contentHash,
            text: sourceChunk.preview,
            citation: citation
        )

        return GeneratedLearningArtifact(
            id: artifactID,
            schemaVersion: GeneratedLearningArtifact.currentSchemaVersion,
            topic: "actor isolation",
            promptVersion: GeneratedLearningVersion.prompt,
            candidateSchemaVersion:
                GeneratedLearningVersion.candidateSchema,
            providerRuntimeLabel: "debug-fixture-provider-v1",
            sourceSetHash: GeneratedLearningValidator.sourceSetHash(
                for: [sourceCard]
            ),
            createdAt: Date(timeIntervalSince1970: 1_785_200_000),
            trust: .experimentalUserMaterial,
            sourceReferences: [reference],
            article: GeneratedLearningArticle(
                title: "Actor isolation with one state owner",
                learningObjective:
                    "Explain how actor isolation protects mutable state.",
                explanation: """
                An actor gives mutable state an explicit isolation boundary. \
                Open the exact citation before relying on this generated \
                explanation.
                """,
                exampleCode: """
                actor Counter {
                    private(set) var value = 0
                }
                """,
                citationReferenceIDs: [reference.id]
            ),
            quiz: GeneratedLearningQuiz(
                prompt:
                    "Which declaration provides an isolation boundary?",
                choices: [
                    GeneratedLearningQuizChoice(
                        id: "choice-1",
                        text: "An actor"
                    ),
                    GeneratedLearningQuizChoice(
                        id: "choice-2",
                        text: "A global variable"
                    ),
                    GeneratedLearningQuizChoice(
                        id: "choice-3",
                        text: "An unchecked reference"
                    ),
                ],
                answerKeyChoiceID: "choice-1",
                explanation:
                    "The generated answer key selects the actor declaration.",
                citationReferenceIDs: [reference.id]
            )
        )
    }
}
#endif
