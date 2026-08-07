#if DEBUG
import SwiftUI

private enum GeneratedLearningPreviewFixtures {
    static let artifactID = UUID(
        uuidString: "77000000-0000-0000-0000-000000000001"
    )!

    static var artifact: GeneratedLearningArtifact {
        let citation = SourceLibraryFixtures.chunks[0].citation
        let reference = GeneratedLearningSourceReference(
            id: "source-card-1",
            documentTitle: SourceLibraryFixtures.document.title,
            rightsStatus: SourceLibraryFixtures.document.rightsStatus,
            citation: citation
        )
        let card = LanguageModelSourceCard(
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
            text: SourceLibraryFixtures.chunks[0].preview,
            citation: citation
        )
        return GeneratedLearningArtifact(
            id: artifactID,
            schemaVersion: GeneratedLearningArtifact.currentSchemaVersion,
            topic: "actor isolation",
            promptVersion: GeneratedLearningVersion.prompt,
            candidateSchemaVersion:
                GeneratedLearningVersion.candidateSchema,
            providerRuntimeLabel: "preview-provider-v1",
            sourceSetHash: GeneratedLearningValidator.sourceSetHash(
                for: [card]
            ),
            createdAt: Date(timeIntervalSince1970: 1_785_200_000),
            trust: .experimentalUserMaterial,
            sourceReferences: [reference],
            article: GeneratedLearningArticle(
                title: "Actor isolation with one state owner",
                learningObjective: "Explain how actor isolation protects mutable state.",
                explanation: "An actor gives mutable state an explicit isolation boundary. Open the exact citation before relying on this generated explanation.",
                exampleCode: "actor Counter {\n    private(set) var value = 0\n}",
                citationReferenceIDs: [reference.id]
            ),
            quiz: GeneratedLearningQuiz(
                prompt: "Which declaration provides an isolation boundary?",
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
                explanation: "The generated answer key selects the actor declaration.",
                citationReferenceIDs: [reference.id]
            )
        )
    }

    static var failedFeedback: ChallengeFeedback {
        ChallengeFeedback(
            attemptID: UUID(
                uuidString: "77000000-0000-0000-0000-000000000002"
            )!,
            challengeID: artifact.quizID,
            selectedChoiceID: "choice-1",
            isCorrect: true,
            explanation: artifact.quiz.explanation,
            storage: .failed
        )
    }

    @MainActor
    static func viewModel(
        availability: LanguageModelAvailability = .available
    ) -> GeneratedLearningViewModel {
        let sourceLibrary = SourceLibraryFixtures.service()
        return GeneratedLearningViewModel(
            generator: GeneratedLearningGenerator(
                retriever: DirectScanSourceRetriever(
                    sourceLibrary: sourceLibrary
                ),
                sourceLibrary: sourceLibrary,
                provider: DeterministicLanguageModelProvider(
                    availability: availability
                ),
                store: InMemoryGeneratedLearningStore()
            )
        )
    }
}

#Preview("Generate Learning — Ready Dark") {
    NavigationStack {
        GeneratedLearningComposerView(
            viewModel: GeneratedLearningPreviewFixtures.viewModel(),
            documents: [SourceLibraryFixtures.document],
            onOpenArticle: { _ in },
            onOpenQuiz: { _ in },
            onReturnToLibrary: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Generate Learning — Unavailable Accessibility") {
    NavigationStack {
        GeneratedLearningComposerView(
            viewModel: GeneratedLearningPreviewFixtures.viewModel(
                availability: .unavailable(.modelNotReady)
            ),
            documents: [SourceLibraryFixtures.document],
            onOpenArticle: { _ in },
            onOpenQuiz: { _ in },
            onReturnToLibrary: {}
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Generated Article — Dark") {
    NavigationStack {
        GeneratedArticleReaderView(
            artifact: GeneratedLearningPreviewFixtures.artifact,
            activity: ArticleActivity(
                articleID:
                    GeneratedLearningPreviewFixtures.artifact.articleID,
                isBookmarked: true
            ),
            onToggleBookmark: {},
            onMarkRead: {},
            onOpenCitation: { _ in },
            onOpenQuiz: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Generated Article — Accessibility") {
    NavigationStack {
        GeneratedArticleReaderView(
            artifact: GeneratedLearningPreviewFixtures.artifact,
            activity: ArticleActivity(
                articleID:
                    GeneratedLearningPreviewFixtures.artifact.articleID,
                lastOpenedAt: Date(timeIntervalSince1970: 1_785_200_000),
                completedAt: Date(timeIntervalSince1970: 1_785_200_000)
            ),
            onToggleBookmark: {},
            onMarkRead: {},
            onOpenCitation: { _ in },
            onOpenQuiz: {}
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Generated Quiz — Accessibility") {
    NavigationStack {
        GeneratedQuizPlayerView(
            artifact: GeneratedLearningPreviewFixtures.artifact,
            hasSavedAnswerKeyMatch: false,
            currentFeedback: nil,
            onSubmit: { _ in nil },
            onRetrySave: { .saved },
            onOpenCitation: { _ in },
            onOpenArticle: {}
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Generated Quiz — Save Failure Dark") {
    NavigationStack {
        GeneratedQuizPlayerView(
            artifact: GeneratedLearningPreviewFixtures.artifact,
            hasSavedAnswerKeyMatch: false,
            currentFeedback:
                GeneratedLearningPreviewFixtures.failedFeedback,
            onSubmit: { _ in nil },
            onRetrySave: { .saved },
            onOpenCitation: { _ in },
            onOpenArticle: {}
        )
    }
    .preferredColorScheme(.dark)
}
#endif
