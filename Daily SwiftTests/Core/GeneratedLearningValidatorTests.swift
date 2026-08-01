import Foundation
import Testing
@testable import DailySwift

struct GeneratedLearningValidatorTests {
    private let validator = GeneratedLearningValidator()

    @Test("A bounded artifact with exact known citations is accepted")
    func validBoundedCitedArtifact() throws {
        let request = GeneratedLearningTestFixtures.request()
        let candidate = GeneratedLearningTestFixtures.candidate(
            citationReferenceIDs: [request.sourceCards[0].id]
        )
        let artifact = GeneratedLearningTestFixtures.artifact(
            request: request,
            candidate: candidate
        )

        try validator.validate(request)
        try validator.validate(candidate, for: request)
        try validator.validate(artifact)

        #expect(
            request.sourceCards.count
                == GeneratedLearningValidationLimits.maximumSourceCards
        )
        #expect(artifact.sourceReferences.count == request.sourceCards.count)
        #expect(
            artifact.sourceSetHash
                == GeneratedLearningValidator.sourceSetHash(
                    for: request.sourceCards
                )
        )
    }

    @Test("Missing, duplicate, and unknown citations fail closed")
    func invalidCitationsAreRejected() {
        let request = GeneratedLearningTestFixtures.request()
        let knownReferenceID = request.sourceCards[0].id
        let candidate = GeneratedLearningTestFixtures.candidate(
            articleCitationReferenceIDs: [],
            quizCitationReferenceIDs: [
                knownReferenceID,
                knownReferenceID,
                "unknown-reference",
            ]
        )

        let categories = validationCategories {
            try validator.validate(candidate, for: request)
        }

        #expect(categories.contains(.citationsMissing))
        #expect(categories.contains(.citationDuplicated))
        #expect(categories.contains(.citationUnknown))
    }

    @Test("Duplicate quiz choices and an ambiguous answer key fail closed")
    func duplicateChoicesAndAnswerKeyAreRejected() {
        let request = GeneratedLearningTestFixtures.request()
        let duplicateChoices = [
            GeneratedLearningQuizChoice(
                id: "duplicate-choice",
                text: "Use one explicit owner"
            ),
            GeneratedLearningQuizChoice(
                id: "duplicate-choice",
                text: " use one explicit owner "
            ),
            GeneratedLearningQuizChoice(
                id: "choice-3",
                text: "Use global mutable state"
            ),
        ]
        let candidate = GeneratedLearningTestFixtures.candidate(
            citationReferenceIDs: [request.sourceCards[0].id],
            choices: duplicateChoices,
            answerKeyChoiceID: "duplicate-choice"
        )

        let categories = validationCategories {
            try validator.validate(candidate, for: request)
        }

        #expect(categories.contains(.choiceIdentityDuplicated))
        #expect(categories.contains(.choiceTextDuplicated))
        #expect(categories.contains(.answerKeyMissing))
    }

    @Test("Extended verbatim source overlap fails closed")
    func extendedSourceOverlapIsRejected() {
        let sourceText = "Actors protect mutable state by allowing one explicit owner to serialize every update before another task can observe the resulting value."
        let citation = SourceCitation(
            sourceID: UUID(
                uuidString: "71000000-0000-0000-0000-000000000001"
            )!,
            chunkID: "verbatim-overlap-source",
            headingPath: ["Actor isolation"],
            location: SourceLocation(
                startLine: 1,
                endLine: 1,
                startCharacter: 0,
                endCharacter: sourceText.count
            ),
            contentHash: SourceTextProcessor.contentHash(for: sourceText)
        )
        let card = GeneratedLearningTestFixtures.sourceCard(
            documentTitle: "Synthetic overlap source",
            rightsStatus: .openLicensed,
            text: sourceText,
            citation: citation
        )
        let request = GeneratedLearningTestFixtures.request(
            sourceCards: [card]
        )
        let candidate = GeneratedLearningTestFixtures.candidate(
            citationReferenceIDs: [card.id],
            articleExplanation: sourceText
        )

        let categories = validationCategories {
            try validator.validate(candidate, for: request)
        }

        #expect(categories.contains(.sourceOverlapExceeded))
    }

    @Test("The normalized overlap boundary accepts 15 words and rejects 16")
    func exactSourceOverlapBoundary() throws {
        let words = (1...20).map { "boundaryword\($0)" }
        let sourceText = words.joined(separator: " ")
        let citation = SourceCitation(
            sourceID: UUID(
                uuidString: "71100000-0000-0000-0000-000000000001"
            )!,
            chunkID: "overlap-boundary-source",
            headingPath: ["Overlap boundary"],
            location: SourceLocation(
                startLine: 1,
                endLine: 1,
                startCharacter: 0,
                endCharacter: sourceText.count
            ),
            contentHash: SourceTextProcessor.contentHash(for: sourceText)
        )
        let card = GeneratedLearningTestFixtures.sourceCard(
            documentTitle: "Synthetic overlap boundary",
            rightsStatus: .openLicensed,
            text: sourceText,
            citation: citation
        )
        let request = GeneratedLearningTestFixtures.request(
            sourceCards: [card]
        )
        let fifteenWords = words.prefix(15)
            .map { $0.uppercased() + "," }
            .joined(separator: " ")
        try validator.validate(
            GeneratedLearningTestFixtures.candidate(
                citationReferenceIDs: [card.id],
                articleExplanation: fifteenWords
            ),
            for: request
        )

        let sixteenWords = words.prefix(16)
            .map { $0.uppercased() + "." }
            .joined(separator: " ")
        let categories = validationCategories {
            try validator.validate(
                GeneratedLearningTestFixtures.candidate(
                    citationReferenceIDs: [card.id],
                    articleExplanation: sixteenWords
                ),
                for: request
            )
        }
        #expect(categories.contains(.sourceOverlapExceeded))
    }

    @Test("The deterministic matrix exercises every rejection category")
    func everyValidationCategoryIsCovered() {
        let baseRequest = GeneratedLearningTestFixtures.request()
        var observed: Set<GeneratedLearningValidationCategory> = []

        observed.formUnion(validationCategories {
            try validator.validate(
                GeneratedLearningTestFixtures.request(
                    topic: " ",
                    swiftVersion: String(repeating: "6", count: 41),
                    promptVersion: "retired-prompt",
                    candidateSchemaVersion:
                        GeneratedLearningVersion.candidateSchema + 1,
                    artifactSchemaVersion:
                        GeneratedLearningArtifact.currentSchemaVersion + 1,
                    sourceCards: []
                )
            )
        })

        let duplicateCard = baseRequest.sourceCards[0]
        let oversizedCards = baseRequest.sourceCards + [
            GeneratedLearningTestFixtures.sourceCard(
                id: "source-card-5",
                documentTitle: duplicateCard.documentTitle,
                rightsStatus: duplicateCard.rightsStatus,
                text: duplicateCard.text,
                citation: duplicateCard.citation
            ),
        ]
        observed.formUnion(validationCategories {
            try validator.validate(
                GeneratedLearningTestFixtures.request(
                    sourceCards: oversizedCards
                )
            )
        })
        observed.formUnion(validationCategories {
            try validator.validate(
                GeneratedLearningTestFixtures.request(
                    sourceCards: [duplicateCard, duplicateCard]
                )
            )
        })

        let changedTextCard = LanguageModelSourceCard(
            id: duplicateCard.id,
            documentTitle: duplicateCard.documentTitle,
            locationLabel: duplicateCard.locationLabel,
            rightsStatus: duplicateCard.rightsStatus,
            contentHash: duplicateCard.contentHash,
            text: duplicateCard.text + " changed",
            citation: duplicateCard.citation
        )
        observed.formUnion(validationCategories {
            try validator.validate(
                GeneratedLearningTestFixtures.request(
                    sourceCards: [changedTextCard]
                )
            )
        })

        let invalidChoices = [
            GeneratedLearningQuizChoice(
                id: "choice-1",
                text: " "
            ),
            GeneratedLearningQuizChoice(
                id: "choice-2",
                text: "A distinct answer"
            ),
        ]
        observed.formUnion(validationCategories {
            try validator.validate(
                GeneratedLearningTestFixtures.candidate(
                    citationReferenceIDs: [
                        baseRequest.sourceCards[0].id,
                    ],
                    choices: invalidChoices,
                    answerKeyChoiceID: "missing-choice"
                ),
                for: baseRequest
            )
        })

        let duplicateChoiceCandidate =
            GeneratedLearningTestFixtures.candidate(
                citationReferenceIDs: [
                    baseRequest.sourceCards[0].id,
                ],
                choices: [
                    GeneratedLearningQuizChoice(
                        id: "duplicate",
                        text: "Repeated"
                    ),
                    GeneratedLearningQuizChoice(
                        id: "duplicate",
                        text: " repeated "
                    ),
                    GeneratedLearningQuizChoice(
                        id: "choice-3",
                        text: "Distinct"
                    ),
                ],
                answerKeyChoiceID: "duplicate"
            )
        observed.formUnion(validationCategories {
            try validator.validate(
                duplicateChoiceCandidate,
                for: baseRequest
            )
        })

        let validCandidate = GeneratedLearningTestFixtures.candidate(
            citationReferenceIDs: [baseRequest.sourceCards[0].id]
        )
        let mismatchedArtifact = GeneratedLearningTestFixtures.artifact(
            request: baseRequest,
            candidate: validCandidate,
            sourceSetHash: "not-the-current-source-set"
        )
        observed.formUnion(validationCategories {
            try validator.validate(mismatchedArtifact)
        })

        let citationCandidate = GeneratedLearningTestFixtures.candidate(
            articleCitationReferenceIDs: [],
            quizCitationReferenceIDs: [
                baseRequest.sourceCards[0].id,
                baseRequest.sourceCards[0].id,
                "unknown-reference",
            ]
        )
        observed.formUnion(validationCategories {
            try validator.validate(citationCandidate, for: baseRequest)
        })

        let overlapText = (1...20)
            .map { "verbatimword\($0)" }
            .joined(separator: " ")
        let overlapCitation = SourceCitation(
            sourceID: UUID(
                uuidString: "71000000-0000-0000-0000-000000000001"
            )!,
            chunkID: "validation-overlap",
            headingPath: ["Overlap"],
            location: SourceLocation(
                startLine: 1,
                endLine: 1,
                startCharacter: 0,
                endCharacter: overlapText.count
            ),
            contentHash: SourceTextProcessor.contentHash(for: overlapText)
        )
        let overlapCard = GeneratedLearningTestFixtures.sourceCard(
            documentTitle: "Overlap source",
            rightsStatus: .openLicensed,
            text: overlapText,
            citation: overlapCitation
        )
        let overlapRequest = GeneratedLearningTestFixtures.request(
            sourceCards: [overlapCard]
        )
        observed.formUnion(validationCategories {
            try validator.validate(
                GeneratedLearningTestFixtures.candidate(
                    citationReferenceIDs: [overlapCard.id],
                    articleExplanation: overlapText
                ),
                for: overlapRequest
            )
        })

        #expect(
            observed
                == Set(GeneratedLearningValidationCategory.allCases)
        )
    }

    private func validationCategories(
        _ operation: () throws -> Void
    ) -> [GeneratedLearningValidationCategory] {
        do {
            try operation()
            Issue.record("Expected generated learning validation to fail")
            return []
        } catch let failure as GeneratedLearningValidationError {
            return failure.categories
        } catch {
            Issue.record("Expected GeneratedLearningValidationError")
            return []
        }
    }
}

enum GeneratedLearningTestFixtures {
    private static let sourceIDs = [
        UUID(uuidString: "71000000-0000-0000-0000-000000000001")!,
        UUID(uuidString: "71000000-0000-0000-0000-000000000002")!,
        UUID(uuidString: "71000000-0000-0000-0000-000000000003")!,
        UUID(uuidString: "71000000-0000-0000-0000-000000000004")!,
    ]

    static func request(
        topic: String = "Actor isolation",
        swiftVersion: String = "6",
        minimumIOSVersion: String = "26.0",
        promptVersion: String = GeneratedLearningGenerator.promptVersion,
        candidateSchemaVersion: Int =
            GeneratedLearningGenerator.candidateSchemaVersion,
        artifactSchemaVersion: Int =
            GeneratedLearningArtifact.currentSchemaVersion,
        sourceCards: [LanguageModelSourceCard]? = nil
    ) -> LanguageModelGenerationRequest {
        LanguageModelGenerationRequest(
            topic: topic,
            swiftVersion: swiftVersion,
            minimumIOSVersion: minimumIOSVersion,
            promptVersion: promptVersion,
            candidateSchemaVersion: candidateSchemaVersion,
            artifactSchemaVersion: artifactSchemaVersion,
            sourceCards: sourceCards ?? (1...4).map { sourceCard($0) }
        )
    }

    static func sourceCard(_ index: Int) -> LanguageModelSourceCard {
        let text = "Source passage \(index) explains actor isolation and explicit state ownership."
        let contentHash = SourceTextProcessor.contentHash(for: text)
        let citation = SourceCitation(
            sourceID: sourceIDs[index - 1],
            chunkID: "generated-learning-chunk-\(index)",
            headingPath: ["Actor isolation", "Passage \(index)"],
            location: SourceLocation(
                startLine: index,
                endLine: index,
                startCharacter: 0,
                endCharacter: text.count
            ),
            contentHash: contentHash
        )
        return sourceCard(
            id: "source-card-\(index)",
            documentTitle: "Synthetic source \(index)",
            rightsStatus: .openLicensed,
            text: text,
            citation: citation
        )
    }

    static func sourceCard(
        id: String = "source-card-1",
        documentTitle: String,
        rightsStatus: SourceRightsStatus,
        text: String,
        citation: SourceCitation
    ) -> LanguageModelSourceCard {
        LanguageModelSourceCard(
            id: id,
            documentTitle: documentTitle,
            locationLabel: [
                citation.headingLabel,
                citation.location.pageLabel,
                citation.location.lineLabel,
            ]
            .compactMap(\.self)
            .joined(separator: " · "),
            rightsStatus: rightsStatus,
            contentHash: citation.contentHash,
            text: text,
            citation: citation
        )
    }

    static func candidate(
        citationReferenceIDs: [String]? = nil,
        articleCitationReferenceIDs: [String]? = nil,
        quizCitationReferenceIDs: [String]? = nil,
        choices: [GeneratedLearningQuizChoice]? = nil,
        answerKeyChoiceID: String? = nil,
        articleExplanation: String = "Actors isolate mutable state. Open the exact source citation to verify the generated explanation."
    ) -> LanguageModelGeneratedCandidate {
        let choices = choices ?? validChoices
        let sharedCitationIDs = citationReferenceIDs ?? ["source-card-1"]
        return LanguageModelGeneratedCandidate(
            providerRuntimeLabel: "deterministic-provider-v1",
            article: LanguageModelArticleCandidate(
                title: "Actor isolation in practice",
                learningObjective: "Explain how one owner protects mutable state.",
                explanation: articleExplanation,
                exampleCode: "actor Counter { var value = 0 }",
                citationReferenceIDs:
                    articleCitationReferenceIDs ?? sharedCitationIDs
            ),
            quiz: LanguageModelQuizCandidate(
                prompt: "Which choice matches the cited explanation?",
                choices: choices,
                answerKeyChoiceID:
                    answerKeyChoiceID ?? choices[0].id,
                explanation: "The saved answer key selects one explicit owner.",
                citationReferenceIDs:
                    quizCitationReferenceIDs ?? sharedCitationIDs
            )
        )
    }

    static func artifact(
        id: UUID = UUID(
            uuidString: "72000000-0000-0000-0000-000000000001"
        )!,
        request: LanguageModelGenerationRequest,
        candidate: LanguageModelGeneratedCandidate,
        documentTitleOverrides: [String: String] = [:],
        sourceSetHash: String? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 1_785_200_000)
    ) -> GeneratedLearningArtifact {
        GeneratedLearningArtifact(
            id: id,
            schemaVersion: request.artifactSchemaVersion,
            topic: request.topic,
            promptVersion: request.promptVersion,
            candidateSchemaVersion: request.candidateSchemaVersion,
            providerRuntimeLabel: candidate.providerRuntimeLabel,
            sourceSetHash: sourceSetHash
                ?? GeneratedLearningValidator.sourceSetHash(
                    for: request.sourceCards
                ),
            createdAt: createdAt,
            trust: .experimentalUserMaterial,
            sourceReferences: request.sourceCards.map { card in
                GeneratedLearningSourceReference(
                    id: card.id,
                    documentTitle:
                        documentTitleOverrides[card.id]
                            ?? card.documentTitle,
                    rightsStatus: card.rightsStatus,
                    citation: card.citation
                )
            },
            article: GeneratedLearningArticle(
                title: candidate.article.title,
                learningObjective: candidate.article.learningObjective,
                explanation: candidate.article.explanation,
                exampleCode: candidate.article.exampleCode,
                citationReferenceIDs:
                    candidate.article.citationReferenceIDs
            ),
            quiz: GeneratedLearningQuiz(
                prompt: candidate.quiz.prompt,
                choices: candidate.quiz.choices,
                answerKeyChoiceID: candidate.quiz.answerKeyChoiceID,
                explanation: candidate.quiz.explanation,
                citationReferenceIDs:
                    candidate.quiz.citationReferenceIDs
            )
        )
    }

    static func artifact(
        id: UUID,
        document: SourceDocument,
        citation: SourceCitation,
        excerpt: String,
        documentTitle: String? = nil,
        createdAt: Date
    ) -> GeneratedLearningArtifact {
        let card = sourceCard(
            documentTitle: document.title,
            rightsStatus: document.rightsStatus,
            text: excerpt,
            citation: citation
        )
        let request = request(sourceCards: [card])
        return artifact(
            id: id,
            request: request,
            candidate: candidate(
                citationReferenceIDs: [card.id]
            ),
            documentTitleOverrides: documentTitle.map {
                [card.id: $0]
            } ?? [:],
            createdAt: createdAt
        )
    }

    private static let validChoices = [
        GeneratedLearningQuizChoice(
            id: "choice-1",
            text: "Give mutable state one explicit owner"
        ),
        GeneratedLearningQuizChoice(
            id: "choice-2",
            text: "Duplicate state in every view"
        ),
        GeneratedLearningQuizChoice(
            id: "choice-3",
            text: "Use global state for every feature"
        ),
    ]
}
