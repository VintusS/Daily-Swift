import Foundation

struct SeedCurriculumProvider: Sendable {
    static let catalog = LearningCatalog(
        articles: SeedArticles.all,
        challenges: SeedChallenges.all,
        dailyPlan: SeedDailyPlan.plan
    )

    func loadCatalog() throws -> LearningCatalog {
        try Self.catalog.validated()
    }
}

private enum SeedArticles {
    static let all: [LearningArticle] = [
        valueSemantics,
        protocolBoundaries,
        swiftUIStateOwnership,
        stableViewIdentity,
        cooperativeCancellation,
        compositionRoot
    ]

    static let valueSemantics = LearningArticle(
        id: "swift.value-semantics",
        domain: .swiftLanguage,
        title: "Use Value Semantics for Predictable State",
        summary: """
        Learn how independent values, explicit mutation, and carefully chosen \
        reference boundaries make Swift state easier to reason about.
        """,
        estimatedMinutes: 5,
        sections: [
            LearningArticleSection(
                id: "swift.value-semantics.local-reasoning",
                heading: "Copies support local reasoning",
                body: """
                A Swift value describes its own logical state. Assigning a \
                structure to another variable produces an independent value \
                from the programmer's point of view. Swift may share storage \
                internally as an optimization, but changing one value must \
                still behave as though it does not mutate the other. This \
                makes value types a natural fit for snapshots, commands, and \
                evidence passed between layers: a consumer can inspect what it \
                received without wondering who else may change it later.
                """,
                code: """
                struct StudyProgress {
                    var completedStepIDs: Set<String> = []
                }

                var saved = StudyProgress()
                var draft = saved
                draft.completedStepIDs.insert("warm-up")

                print(saved.completedStepIDs.isEmpty)
                """
            ),
            LearningArticleSection(
                id: "swift.value-semantics.explicit-mutation",
                heading: "Make mutation visible",
                body: """
                A value stored with let cannot be mutated, while a value stored \
                with var can change through an explicit operation. A mutating \
                method keeps an invariant close to the data instead of asking \
                every caller to update several fields in the correct order. \
                The goal is not to make every type immutable. The goal is to \
                make the owner and timing of each mutation obvious enough that \
                tests can describe the transition from the old value to the \
                new one.
                """,
                code: """
                struct ReadingState {
                    private(set) var completedArticleIDs: Set<String> = []

                    mutating func complete(articleID: String) {
                        completedArticleIDs.insert(articleID)
                    }
                }
                """
            ),
            LearningArticleSection(
                id: "swift.value-semantics.boundaries",
                heading: "Choose identity only when it is useful",
                body: """
                Reference identity is valuable when multiple consumers must \
                coordinate through one shared lifetime, such as an actor that \
                serializes progress writes. It is less useful for a result that \
                merely reports what happened. Prefer a value for the report and \
                keep the shared service behind a narrow boundary. This split \
                lets concurrent work share the service intentionally while \
                keeping the data crossing that boundary stable, comparable, \
                and straightforward to test.
                """
            )
        ],
        takeaways: [
            "Value assignment preserves independent logical state.",
            "Explicit mutation makes ownership and transitions testable.",
            "Use shared identity for coordination, not for every data model."
        ],
        trust: .projectSeed
    )

    static let protocolBoundaries = LearningArticle(
        id: "swift.protocol-boundaries",
        domain: .swiftLanguage,
        title: "Design Protocols from the Consumer's Need",
        summary: """
        Shape small Swift protocols around real operations so production \
        adapters and deterministic fakes can satisfy the same contract.
        """,
        estimatedMinutes: 5,
        sections: [
            LearningArticleSection(
                id: "swift.protocol-boundaries.consumer",
                heading: "Start at the call site",
                body: """
                A useful protocol states what a consumer needs without exposing \
                how a particular adapter performs the work. A lesson screen may \
                need to load one article; it does not need the file layout, \
                database context, or cache policy of the live implementation. \
                Defining the requirement at that boundary keeps the interface \
                small and gives the caller fewer accidental dependencies. It \
                also avoids creating a protocol for a value that has no \
                alternate behavior or testing seam.
                """,
                code: """
                protocol ArticleLoading: Sendable {
                    func article(id: String) async throws -> LearningArticle
                }
                """
            ),
            LearningArticleSection(
                id: "swift.protocol-boundaries.injection",
                heading: "Inject the capability explicitly",
                body: """
                Initializer injection makes a dependency visible at the point \
                where the feature is assembled. The consumer stores the \
                protocol it needs and has no knowledge of a global registry. \
                Production can provide a bundled-content adapter, while a test \
                provides a fixed result or a deliberate failure. The same \
                feature behavior is exercised in both cases because the \
                substitution happens outside the feature rather than through \
                branches hidden inside it.
                """,
                code: """
                struct OpenArticle {
                    let loader: any ArticleLoading

                    func callAsFunction(id: String) async throws -> LearningArticle {
                        try await loader.article(id: id)
                    }
                }
                """
            ),
            LearningArticleSection(
                id: "swift.protocol-boundaries.failures",
                heading: "Keep failure meaning stable",
                body: """
                Platform errors often contain details that a feature should not \
                display or depend on. An adapter can translate those errors \
                into a small set of domain failures such as unavailable, \
                unreadable, or unsupported. Tests can then cover every recovery \
                path without reproducing a database or file-system failure. \
                Stable failure categories also protect privacy because raw \
                paths, stored values, and implementation messages never need \
                to cross into learner-visible state.
                """
            )
        ],
        takeaways: [
            "Define a protocol around the consumer's operation.",
            "Inject dependencies where the feature is assembled.",
            "Map platform failures to stable, privacy-safe domain failures."
        ],
        trust: .projectSeed
    )

    static let swiftUIStateOwnership = LearningArticle(
        id: "swiftui.state-ownership",
        domain: .swiftUI,
        title: "Give Every SwiftUI State One Clear Owner",
        summary: """
        Select state tools by ownership, send user intents in one direction, \
        and derive presentation instead of storing duplicate truth.
        """,
        estimatedMinutes: 5,
        sections: [
            LearningArticleSection(
                id: "swiftui.state-ownership.choose-owner",
                heading: "Choose the source of truth first",
                body: """
                Before choosing a property wrapper, decide who owns the value. \
                A view can use State for small transient values that belong to \
                that view, such as whether a local disclosure is expanded. A \
                child uses Binding when it may edit state owned by its parent. \
                Feature behavior that coordinates loading, saving, and recovery \
                belongs in an observable main-actor model. The wrapper follows \
                the ownership decision; it does not replace that decision.
                """,
                code: """
                struct CounterView: View {
                    @State private var count = 0

                    var body: some View {
                        Button("Count: \\(count)") {
                            count += 1
                        }
                    }
                }
                """
            ),
            LearningArticleSection(
                id: "swiftui.state-ownership.intents",
                heading: "Send intents, then render the result",
                body: """
                A predictable feature moves in one direction: the view renders \
                state, the learner performs an action, and the view forwards \
                that intent to the state owner. The owner validates the action, \
                calls its dependency, and publishes a new value. This approach \
                prevents a view from deciding correctness or persistence rules \
                while it is laying out controls. It also gives tests a simple \
                vocabulary: start from a state, send an intent, and assert the \
                next state.
                """,
                code: """
                @MainActor
                @Observable
                final class PracticeViewModel {
                    private(set) var submittedAnswerID: String?

                    func selectAnswer(id: String) {
                        submittedAnswerID = id
                    }
                }
                """
            ),
            LearningArticleSection(
                id: "swiftui.state-ownership.derive",
                heading: "Derive presentation when possible",
                body: """
                Storing both source data and every presentation consequence can \
                let those values disagree. If a button is enabled whenever a \
                selection exists, derive isSubmitEnabled from the selection \
                rather than mutating two properties. Persist durable evidence, \
                then derive progress from that evidence for the same reason. \
                Derived state narrows the number of transitions that can be \
                wrong and makes restoration produce the same result as the \
                original session.
                """
            )
        ],
        takeaways: [
            "Pick State, Binding, or an observable model from ownership.",
            "Views render state and forward user intents.",
            "Derive presentation from authoritative values when possible."
        ],
        trust: .projectSeed
    )

    static let stableViewIdentity = LearningArticle(
        id: "swiftui.stable-identity",
        domain: .swiftUI,
        title: "Keep SwiftUI Identity Stable",
        summary: """
        Use durable identifiers so lists, navigation, focus, and local row \
        state continue to represent the same conceptual item.
        """,
        estimatedMinutes: 4,
        sections: [
            LearningArticleSection(
                id: "swiftui.stable-identity.meaning",
                heading: "Identity answers what stayed the same",
                body: """
                SwiftUI compares successive view descriptions to update the \
                rendered interface. Stable identity tells that comparison which \
                element still represents the same article or challenge after \
                sorting, filtering, or inserting another item. When identity \
                changes unnecessarily, row state, focus, and animations may \
                attach to a different element or restart. A durable domain \
                identifier gives the framework the same answer the product \
                would use when saving progress.
                """,
                code: """
                struct ArticleSummary: Identifiable {
                    let id: String
                    let title: String
                }

                ForEach(articles) { article in
                    Text(article.title)
                }
                """
            ),
            LearningArticleSection(
                id: "swiftui.stable-identity.indices",
                heading: "An array position is not an item identity",
                body: """
                An offset describes where an element is currently stored, not \
                which element it is. If a new row is inserted at the beginning, \
                every later offset changes even though the underlying items do \
                not. Using offsets as identity can therefore make an edit or \
                navigation destination appear to move. Index-based iteration is \
                still useful when position itself is the data, but content \
                records should normally carry stable identifiers of their own.
                """
            ),
            LearningArticleSection(
                id: "swiftui.stable-identity.persistence",
                heading: "Share stable IDs across boundaries",
                body: """
                A bundled challenge, a saved attempt, and a navigation route can \
                refer to the same stable challenge identifier without sharing \
                their implementation types. That identifier becomes a small \
                contract between immutable content and mutable evidence. Once \
                released, changing it should be treated as a migration because \
                old progress still refers to the earlier value. Randomly \
                creating a new identifier each time content loads breaks that \
                contract even if the visible title is unchanged.
                """
            )
        ],
        takeaways: [
            "Stable identity preserves the meaning of a rendered item.",
            "Use domain identifiers instead of changing array offsets.",
            "Treat released content identifiers as migration boundaries."
        ],
        trust: .projectSeed
    )

    static let cooperativeCancellation = LearningArticle(
        id: "concurrency.cooperative-cancellation",
        domain: .concurrency,
        title: "Treat Cancellation as Part of the Contract",
        summary: """
        Make asynchronous work cancellation-aware, preserve cancellation \
        through error handling, and prevent stale results from replacing state.
        """,
        estimatedMinutes: 5,
        sections: [
            LearningArticleSection(
                id: "concurrency.cooperative-cancellation.check",
                heading: "Cancellation is cooperative",
                body: """
                Cancelling a task records a request; the task must reach a \
                cancellation-aware suspension point or check explicitly before \
                it stops. Many throwing asynchronous APIs surface cancellation \
                as an error. CPU-bound loops and work between suspension points \
                should call Task.checkCancellation at useful boundaries. The \
                check is not decoration: it defines when the operation promises \
                to stop doing unnecessary work and return control to its owner.
                """,
                code: """
                func refresh() async throws -> Payload {
                    try Task.checkCancellation()
                    let payload = try await service.load()
                    try Task.checkCancellation()
                    return payload
                }
                """
            ),
            LearningArticleSection(
                id: "concurrency.cooperative-cancellation.propagate",
                heading: "Do not turn cancellation into success",
                body: """
                A broad catch that returns fallback data for every error also \
                catches cancellation from a throwing child operation. The \
                caller then sees a successful result and may publish it even \
                though the work was deliberately cancelled. Handle cancellation \
                separately or rethrow it before mapping operational failures to \
                fallback behavior. A deterministic fallback can remain useful \
                without erasing the task lifecycle signal.
                """,
                code: """
                do {
                    return try await repository.load()
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    return cachedValue
                }
                """
            ),
            LearningArticleSection(
                id: "concurrency.cooperative-cancellation.stale",
                heading: "Guard against stale completion",
                body: """
                Cancellation and stale-result protection solve related but \
                different problems. An operation may finish just before the \
                cancellation request is observed, or an adapter may not suspend \
                at a cancellation-aware point. Give each request an identity \
                and compare it with the active identity before publishing. The \
                state owner can then ignore an older result after a retry starts \
                without asking a SwiftUI view to reason about task races.
                """,
                code: """
                let operationID = UUID()
                activeOperationID = operationID
                let value = try await service.load()

                guard activeOperationID == operationID else {
                    return
                }
                state = .content(value)
                """
            )
        ],
        takeaways: [
            "Cancellation requires a suspension point or explicit check.",
            "Preserve cancellation when mapping other failures.",
            "Use request identity to prevent stale state publication."
        ],
        trust: .projectSeed
    )

    static let compositionRoot = LearningArticle(
        id: "architecture.composition-root",
        domain: .appArchitecture,
        title: "Assemble Dependencies at One Composition Root",
        summary: """
        Construct live adapters once, inject narrow capabilities, and keep \
        domain behavior independent of SwiftUI and persistence frameworks.
        """,
        estimatedMinutes: 5,
        sections: [
            LearningArticleSection(
                id: "architecture.composition-root.assemble",
                heading: "Assembly is an application decision",
                body: """
                A composition root is the place where the application chooses \
                concrete adapters and connects them to features. Centralizing \
                that choice makes the runtime configuration visible without \
                turning the environment into a lookup registry. A feature still \
                receives only the capabilities it uses. Tests can construct the \
                same feature with deterministic in-memory collaborators and do \
                not need to start the production database or other unrelated \
                subsystems.
                """,
                code: """
                struct AppEnvironment {
                    let catalogProvider: SeedCurriculumProvider
                    let progressStore: any LearningProgressStoring
                }
                """
            ),
            LearningArticleSection(
                id: "architecture.composition-root.direction",
                heading: "Keep dependency direction explicit",
                body: """
                In a pragmatic MVVM feature, a SwiftUI view renders state and \
                forwards an intent to a main-actor view model. The view model \
                applies feature rules and calls a narrow service or repository. \
                A platform adapter implements that boundary with SwiftData, a \
                file, or another framework. Dependencies point toward the \
                domain contract, so replacing the adapter does not move storage \
                rules into the view or force domain values to become platform \
                model objects.
                """
            ),
            LearningArticleSection(
                id: "architecture.composition-root.failures",
                heading: "Recovery belongs at the boundary",
                body: """
                The adapter knows why a platform operation failed, but the \
                feature owns what the learner can do next. Translate the raw \
                error into a stable category, retain any safe in-memory state, \
                and let the view model expose retry or temporary operation. \
                This separation keeps recovery testable and prevents private \
                stored values or file paths from becoming UI copy. It also \
                avoids silently reporting an interaction as saved when only the \
                on-screen state changed.
                """
            )
        ],
        takeaways: [
            "Choose concrete adapters at the application composition root.",
            "Inject only the capabilities each feature consumes.",
            "Translate platform failures before they reach presentation."
        ],
        trust: .projectSeed
    )
}

private enum SeedChallenges {
    static let all: [LearningChallenge] = [
        valueCopyOutput,
        protocolDependency,
        swiftUIStateOwner,
        swiftUIIdentity,
        cancellationPropagation,
        asyncLetOutput,
        compositionRoot,
        viewWritesStorage
    ]

    static let valueCopyOutput = LearningChallenge(
        id: "swift.value-copy-output",
        domain: .swiftLanguage,
        title: "Trace an independent value copy",
        kind: .predictOutput,
        difficulty: .foundation,
        prompt: "What does this program print?",
        code: """
        struct Counter {
            var value = 0
        }

        var first = Counter()
        var second = first
        second.value += 1

        print(first.value, second.value)
        """,
        choices: [
            ChallengeChoice(id: "zero-one", text: "0 1"),
            ChallengeChoice(id: "one-one", text: "1 1"),
            ChallengeChoice(id: "zero-zero", text: "0 0"),
            ChallengeChoice(id: "one-zero", text: "1 0")
        ],
        correctChoiceID: "zero-one",
        explanation: """
        Counter is a structure. Assigning first to second creates an \
        independent value, so mutating second leaves first.value at zero.
        """,
        estimatedMinutes: 3,
        relatedArticleID: "swift.value-semantics",
        validationCapability: .deterministic
    )

    static let protocolDependency = LearningChallenge(
        id: "swift.protocol-dependency",
        domain: .swiftLanguage,
        title: "Choose the narrow dependency boundary",
        kind: .multipleChoice,
        difficulty: .applied,
        prompt: """
        A view model needs to load one article and tests need deterministic \
        success and failure. Which design best fits that requirement?
        """,
        code: nil,
        choices: [
            ChallengeChoice(
                id: "inject-protocol",
                text: """
                Inject a protocol with the one load operation and provide live \
                and in-memory implementations.
                """
            ),
            ChallengeChoice(
                id: "global-database",
                text: "Read a global database singleton directly in the view model."
            ),
            ChallengeChoice(
                id: "view-storage",
                text: "Let the SwiftUI view query the platform store itself."
            ),
            ChallengeChoice(
                id: "generic-registry",
                text: "Resolve every dependency by string from a global registry."
            )
        ],
        correctChoiceID: "inject-protocol",
        explanation: """
        A consumer-shaped protocol makes the required capability explicit and \
        lets tests substitute deterministic behavior without exposing storage.
        """,
        estimatedMinutes: 3,
        relatedArticleID: "swift.protocol-boundaries",
        validationCapability: .deterministic
    )

    static let swiftUIStateOwner = LearningChallenge(
        id: "swiftui.state-owner",
        domain: .swiftUI,
        title: "Find the missing state owner",
        kind: .spotTheIssue,
        difficulty: .foundation,
        prompt: "Why can this button not update the displayed count?",
        code: """
        struct CounterView: View {
            let count = 0

            var body: some View {
                Button("Count: \\(count)") {
                    count += 1
                }
            }
        }
        """,
        choices: [
            ChallengeChoice(
                id: "immutable-count",
                text: """
                count is an immutable stored value; view-owned transient state \
                should have an explicit mutable owner such as private State.
                """
            ),
            ChallengeChoice(
                id: "button-label",
                text: "A Button label cannot interpolate a number."
            ),
            ChallengeChoice(
                id: "body-mutating",
                text: "The body property must be declared mutating."
            ),
            ChallengeChoice(
                id: "integer-binding",
                text: "Every integer displayed by SwiftUI must be a Binding."
            )
        ],
        correctChoiceID: "immutable-count",
        explanation: """
        let makes count immutable. For state that this view owns, private State \
        supplies a mutable source of truth and asks SwiftUI to update the body.
        """,
        estimatedMinutes: 4,
        relatedArticleID: "swiftui.state-ownership",
        validationCapability: .deterministic
    )

    static let swiftUIIdentity = LearningChallenge(
        id: "swiftui.stable-row-identity",
        domain: .swiftUI,
        title: "Preserve row identity",
        kind: .multipleChoice,
        difficulty: .applied,
        prompt: """
        Articles can be reordered and inserted. Which identifier should a \
        ForEach use to preserve each article's identity?
        """,
        code: nil,
        choices: [
            ChallengeChoice(
                id: "stable-article-id",
                text: "The article's stable domain identifier."
            ),
            ChallengeChoice(
                id: "array-offset",
                text: "Its current array offset."
            ),
            ChallengeChoice(
                id: "new-uuid",
                text: "A new UUID created whenever the view body runs."
            ),
            ChallengeChoice(
                id: "visible-title",
                text: "Its visible title, even if titles may be edited."
            )
        ],
        correctChoiceID: "stable-article-id",
        explanation: """
        A stable domain identifier continues to name the same article after \
        ordering changes and can also connect navigation with saved activity.
        """,
        estimatedMinutes: 3,
        relatedArticleID: "swiftui.stable-identity",
        validationCapability: .deterministic
    )

    static let cancellationPropagation = LearningChallenge(
        id: "concurrency.cancellation-propagation",
        domain: .concurrency,
        title: "Keep cancellation distinct from failure",
        kind: .spotTheIssue,
        difficulty: .applied,
        prompt: "What lifecycle problem is hidden by this implementation?",
        code: """
        func loadOrFallback() async -> [Lesson] {
            do {
                return try await repository.load()
            } catch {
                return []
            }
        }
        """,
        choices: [
            ChallengeChoice(
                id: "swallows-cancellation",
                text: """
                A cancellation error can become an apparently successful empty \
                result instead of remaining cancelled.
                """
            ),
            ChallengeChoice(
                id: "requires-detached",
                text: "Every repository call must run in a detached task."
            ),
            ChallengeChoice(
                id: "arrays-not-sendable",
                text: "An array can never be returned from an async function."
            ),
            ChallengeChoice(
                id: "do-catch-main-actor",
                text: "do-catch is unavailable outside the main actor."
            )
        ],
        correctChoiceID: "swallows-cancellation",
        explanation: """
        Throwing async operations can surface cancellation as an error. A broad \
        catch maps it to success, so cancellation should be preserved before \
        other failures are converted to fallback data.
        """,
        estimatedMinutes: 4,
        relatedArticleID: "concurrency.cooperative-cancellation",
        validationCapability: .deterministic
    )

    static let asyncLetOutput = LearningChallenge(
        id: "concurrency.async-let-output",
        domain: .concurrency,
        title: "Combine two child-task results",
        kind: .predictOutput,
        difficulty: .foundation,
        prompt: "What number is printed after both async-let values finish?",
        code: """
        func doubled(_ value: Int) async -> Int {
            value * 2
        }

        async let first = doubled(2)
        async let second = doubled(3)
        let pair = await (first, second)

        print(pair.0 + pair.1)
        """,
        choices: [
            ChallengeChoice(id: "ten", text: "10"),
            ChallengeChoice(id: "five", text: "5"),
            ChallengeChoice(id: "six", text: "6"),
            ChallengeChoice(
                id: "order-dependent",
                text: "The result depends on which child finishes first."
            )
        ],
        correctChoiceID: "ten",
        explanation: """
        The two results are four and six. Awaiting the tuple waits for both, and \
        addition produces ten regardless of child completion order.
        """,
        estimatedMinutes: 3,
        relatedArticleID: "concurrency.cooperative-cancellation",
        validationCapability: .deterministic
    )

    static let compositionRoot = LearningChallenge(
        id: "architecture.composition-root",
        domain: .appArchitecture,
        title: "Place live dependency assembly",
        kind: .multipleChoice,
        difficulty: .applied,
        prompt: """
        Where should the application normally choose the live catalog and \
        progress-store adapters?
        """,
        code: nil,
        choices: [
            ChallengeChoice(
                id: "composition-root",
                text: "At the application composition root, before feature injection."
            ),
            ChallengeChoice(
                id: "article-row",
                text: "Inside every article row as it appears."
            ),
            ChallengeChoice(
                id: "domain-model",
                text: "Inside the domain value that represents an article."
            ),
            ChallengeChoice(
                id: "string-registry",
                text: "In a global string-keyed service registry."
            )
        ],
        correctChoiceID: "composition-root",
        explanation: """
        The composition root owns concrete runtime choices. Features receive \
        only their explicit capabilities and tests can provide substitutes.
        """,
        estimatedMinutes: 3,
        relatedArticleID: "architecture.composition-root",
        validationCapability: .deterministic
    )

    static let viewWritesStorage = LearningChallenge(
        id: "architecture.view-writes-storage",
        domain: .appArchitecture,
        title: "Keep persistence out of the view",
        kind: .spotTheIssue,
        difficulty: .stretch,
        prompt: "What is the main boundary problem in this project code?",
        code: """
        Button("Complete") {
            Task {
                try? await progressStore.appendAttempt(attempt)
            }
        }
        """,
        choices: [
            ChallengeChoice(
                id: "view-owns-write",
                text: """
                The view performs and suppresses a persistence operation instead \
                of sending an intent to a state owner with recovery behavior.
                """
            ),
            ChallengeChoice(
                id: "button-no-task",
                text: "A Button action can never begin asynchronous work."
            ),
            ChallengeChoice(
                id: "protocol-in-view",
                text: "A SwiftUI view cannot store a value typed as a protocol."
            ),
            ChallengeChoice(
                id: "append-not-async",
                text: "Append operations are required to be synchronous."
            )
        ],
        correctChoiceID: "view-owns-write",
        explanation: """
        The view should send a Complete intent to a main-actor state owner. That \
        owner can persist through the protocol, expose saving and failure state, \
        and avoid reporting unsaved evidence as durable.
        """,
        estimatedMinutes: 4,
        relatedArticleID: "architecture.composition-root",
        validationCapability: .deterministic
    )
}

private enum SeedDailyPlan {
    static let plan = DailyLearningPlan(
        id: "daily.predictable-state",
        title: "Make State Predictable",
        focus: "Swift values, SwiftUI ownership, and cooperative cancellation",
        summary: """
        Follow one thread from independent values through visible UI ownership \
        to asynchronous work that stops and resumes honestly.
        """,
        steps: [
            DailyLearningStep(
                id: "daily.predictable-state.read-values",
                title: "Read: Predictable value state",
                detail: "Build a clear model for copies and explicit mutation.",
                estimatedMinutes: 5,
                content: .article("swift.value-semantics")
            ),
            DailyLearningStep(
                id: "daily.predictable-state.trace-copy",
                title: "Challenge: Trace a value copy",
                detail: "Predict the result of mutating an independent value.",
                estimatedMinutes: 3,
                content: .challenge("swift.value-copy-output")
            ),
            DailyLearningStep(
                id: "daily.predictable-state.read-ui-owner",
                title: "Read: Own SwiftUI state",
                detail: "Choose one source of truth and send intents toward it.",
                estimatedMinutes: 5,
                content: .article("swiftui.state-ownership")
            ),
            DailyLearningStep(
                id: "daily.predictable-state.find-ui-owner",
                title: "Challenge: Find the state owner",
                detail: "Diagnose a view with no mutable source of truth.",
                estimatedMinutes: 4,
                content: .challenge("swiftui.state-owner")
            ),
            DailyLearningStep(
                id: "daily.predictable-state.read-cancellation",
                title: "Read: Preserve cancellation",
                detail: "Keep cancelled work from publishing a fallback result.",
                estimatedMinutes: 5,
                content: .article("concurrency.cooperative-cancellation")
            ),
            DailyLearningStep(
                id: "daily.predictable-state.find-cancellation",
                title: "Challenge: Spot swallowed cancellation",
                detail: "Separate task cancellation from recoverable failure.",
                estimatedMinutes: 4,
                content: .challenge("concurrency.cancellation-propagation")
            )
        ]
    )
}
