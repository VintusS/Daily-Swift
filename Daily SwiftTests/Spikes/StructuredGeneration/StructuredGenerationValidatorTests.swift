#if DEBUG
import Testing
@testable import DailySwift

struct StructuredGenerationValidatorTests {
    private let validator = StructuredGenerationValidator()

    @Test("The bounded cited fixture passes deterministic validation")
    func validFixturePasses() throws {
        let artifact = try validator.validate(
            StructuredGenerationFixtures.validArtifact,
            for: StructuredGenerationFixtures.request
        )

        #expect(artifact == StructuredGenerationFixtures.validArtifact)
        #expect(
            StructuredGenerationFixtures.request.sourceCards.count
                == StructuredGenerationValidationLimits.maximumSourceCards
        )
    }

    @Test("Uncited and ambiguous output reports typed failures")
    func invalidFixtureIsRejected() {
        let failures = validator.failures(
            in: StructuredGenerationFixtures.invalidArtifact,
            for: StructuredGenerationFixtures.request
        )

        #expect(failures.contains(.missingCitations(.lesson)))
        #expect(failures.contains(.missingCitations(.exercise)))
        #expect(failures.contains(.duplicateChoiceText("The same answer")))
        #expect(failures.contains(.correctChoiceNotFound("missing")))
    }

    @Test("Only source cards actually used need a resolvable citation")
    func unusedSourceCardsDoNotForceCitations() {
        let fixture = StructuredGenerationFixtures.validArtifact
        let focusedLesson = StructuredLessonArtifact(
            title: fixture.lesson.title,
            learningObjective: fixture.lesson.learningObjective,
            explanation: fixture.lesson.explanation,
            exampleCode: fixture.lesson.exampleCode,
            citationIDs: ["main-actor-state"]
        )
        let focusedExercise = StructuredMultipleChoiceExercise(
            prompt: fixture.exercise.prompt,
            choices: fixture.exercise.choices,
            correctChoiceID: fixture.exercise.correctChoiceID,
            explanation: fixture.exercise.explanation,
            citationIDs: ["deterministic-validation"]
        )
        let artifact = StructuredGenerationArtifact(
            schemaVersion: fixture.schemaVersion,
            promptVersion: fixture.promptVersion,
            modelVersion: fixture.modelVersion,
            swiftVersion: fixture.swiftVersion,
            minimumIOSVersion: fixture.minimumIOSVersion,
            lesson: focusedLesson,
            exercise: focusedExercise
        )

        let failures = validator.failures(
            in: artifact,
            for: StructuredGenerationFixtures.request
        )

        #expect(failures.isEmpty)
    }

    @Test("Diagnostic categories never expose rejected values")
    func diagnosticCategoriesArePrivacySafe() {
        let privateCardID = "private-card-identity"
        let privateChoiceText = "private generated answer"
        let failures: [StructuredGenerationValidationFailure] = [
            .unknownCitation(scope: .lesson, cardID: privateCardID),
            .duplicateChoiceText(privateChoiceText),
        ]
        let diagnostics = failures.map {
            "\($0.category.rawValue) \($0.category.title)"
        }
        .joined(separator: " ")

        #expect(!diagnostics.contains(privateCardID))
        #expect(!diagnostics.contains(privateChoiceText))
        #expect(failures[0].category == .citationUnknown)
        #expect(failures[1].category == .choiceTextDuplicated)
    }

    @Test("Source-card count and content hash are bounded inputs")
    func sourceCardBoundsAreValidated() {
        let fixture = StructuredGenerationFixtures.sourceCards[0]
        let cardWithoutHash = StructuredGenerationSourceCard(
            id: "missing-hash",
            title: fixture.title,
            location: fixture.location,
            rights: fixture.rights,
            contentHash: " ",
            text: fixture.text
        )
        let extraCard = StructuredGenerationSourceCard(
            id: "extra-card",
            title: fixture.title,
            location: fixture.location,
            rights: fixture.rights,
            contentHash: fixture.contentHash,
            text: fixture.text
        )
        let request = StructuredGenerationRequest(
            conceptID: StructuredGenerationFixtures.request.conceptID,
            difficulty: StructuredGenerationFixtures.request.difficulty,
            swiftVersion: StructuredGenerationFixtures.request.swiftVersion,
            minimumIOSVersion: StructuredGenerationFixtures.request.minimumIOSVersion,
            promptVersion: StructuredGenerationFixtures.request.promptVersion,
            schemaVersion: StructuredGenerationFixtures.request.schemaVersion,
            sourceCards: StructuredGenerationFixtures.sourceCards
                + [cardWithoutHash, extraCard]
        )

        let failures = validator.failures(
            in: StructuredGenerationFixtures.validArtifact,
            for: request
        )

        #expect(
            failures.contains(
                .tooManySourceCards(
                    actual: 6,
                    maximum: StructuredGenerationValidationLimits.maximumSourceCards
                )
            )
        )
        #expect(
            failures.contains(
                .emptyRequiredField(
                    .sourceCardContentHash(cardID: "missing-hash")
                )
            )
        )
    }

    @Test("Every fixture content hash matches its source text")
    func fixtureContentHashesMatch() {
        let failures = validator.failures(
            in: StructuredGenerationFixtures.validArtifact,
            for: StructuredGenerationFixtures.request
        )

        #expect(
            !failures.contains {
                if case .sourceCardContentHashMismatch = $0 {
                    return true
                }
                return false
            }
        )
    }

    @Test("A well-formed but stale content hash is rejected")
    func staleContentHashIsRejected() {
        let fixture = StructuredGenerationFixtures.sourceCards[0]
        let tamperedCard = StructuredGenerationSourceCard(
            id: fixture.id,
            title: fixture.title,
            location: fixture.location,
            rights: fixture.rights,
            contentHash: String(repeating: "0", count: 64),
            text: fixture.text
        )
        let requestFixture = StructuredGenerationFixtures.request
        let request = StructuredGenerationRequest(
            conceptID: requestFixture.conceptID,
            difficulty: requestFixture.difficulty,
            swiftVersion: requestFixture.swiftVersion,
            minimumIOSVersion: requestFixture.minimumIOSVersion,
            promptVersion: requestFixture.promptVersion,
            schemaVersion: requestFixture.schemaVersion,
            sourceCards: [tamperedCard]
        )

        #expect(throws: StructuredGenerationValidationError.self) {
            try validator.validate(request)
        }
        #expect(
            validator.failures(
                in: StructuredGenerationFixtures.validArtifact,
                for: request
            )
            .contains(.sourceCardContentHashMismatch(cardID: fixture.id))
        )
    }

    @Test("Generated platform version tags must match the request")
    func platformVersionTagsAreValidated() {
        let fixture = StructuredGenerationFixtures.validArtifact
        let artifact = StructuredGenerationArtifact(
            schemaVersion: fixture.schemaVersion,
            promptVersion: fixture.promptVersion,
            modelVersion: fixture.modelVersion,
            swiftVersion: "5.10",
            minimumIOSVersion: "25.0",
            lesson: fixture.lesson,
            exercise: fixture.exercise
        )

        let failures = validator.failures(
            in: artifact,
            for: StructuredGenerationFixtures.request
        )

        #expect(
            failures.contains(
                .swiftVersionMismatch(expected: "6", actual: "5.10")
            )
        )
        #expect(
            failures.contains(
                .minimumIOSVersionMismatch(
                    expected: "26.0",
                    actual: "25.0"
                )
            )
        )
    }

    @Test("Resolvable source locations and choice identities are required")
    func provenanceAndChoiceIdentityAreValidated() {
        let sourceFixture = StructuredGenerationFixtures.sourceCards[0]
        let sourceWithoutLocation = StructuredGenerationSourceCard(
            id: sourceFixture.id,
            title: sourceFixture.title,
            location: StructuredGenerationSourceLocation(
                documentTitle: " ",
                section: ""
            ),
            rights: sourceFixture.rights,
            contentHash: "not-a-sha-256-digest",
            text: sourceFixture.text
        )
        let fixture = StructuredGenerationFixtures.validArtifact
        let exercise = StructuredMultipleChoiceExercise(
            prompt: fixture.exercise.prompt,
            choices: [
                StructuredGenerationChoice(id: "", text: "First"),
                StructuredGenerationChoice(id: "second", text: "Second"),
            ],
            correctChoiceID: "",
            explanation: fixture.exercise.explanation,
            citationIDs: fixture.exercise.citationIDs
        )
        let request = StructuredGenerationRequest(
            conceptID: StructuredGenerationFixtures.request.conceptID,
            difficulty: StructuredGenerationFixtures.request.difficulty,
            swiftVersion: StructuredGenerationFixtures.request.swiftVersion,
            minimumIOSVersion: StructuredGenerationFixtures.request.minimumIOSVersion,
            promptVersion: StructuredGenerationFixtures.request.promptVersion,
            schemaVersion: StructuredGenerationFixtures.request.schemaVersion,
            sourceCards: [sourceWithoutLocation]
        )
        let artifact = StructuredGenerationArtifact(
            schemaVersion: fixture.schemaVersion,
            promptVersion: fixture.promptVersion,
            modelVersion: fixture.modelVersion,
            swiftVersion: fixture.swiftVersion,
            minimumIOSVersion: fixture.minimumIOSVersion,
            lesson: fixture.lesson,
            exercise: exercise
        )

        let failures = validator.failures(in: artifact, for: request)

        #expect(
            failures.contains(
                .emptyRequiredField(
                    .sourceDocumentTitle(cardID: sourceFixture.id)
                )
            )
        )
        #expect(
            failures.contains(
                .emptyRequiredField(.sourceSection(cardID: sourceFixture.id))
            )
        )
        #expect(
            failures.contains(
                .invalidSourceCardContentHash(cardID: sourceFixture.id)
            )
        )
        #expect(
            failures.contains(.emptyRequiredField(.choiceID(index: 0)))
        )
        #expect(
            failures.contains(.emptyRequiredField(.correctChoiceID))
        )
    }
}
#endif
