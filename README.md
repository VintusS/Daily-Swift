# Daily Swift

**An adaptive, local-first learning companion for becoming a stronger iOS developer.**

Daily Swift turns the intention to “get better at iOS” into a focused, rewarding daily practice. It brings together Swift, SwiftUI, and the wider iOS SDK in short learning sessions that can adapt to a learner’s goals, evidence, and source material.

The project is an iPhone-first SwiftUI app built with an unusually deliberate standard for learning quality: a model may help compose an explanation or practice exercise, but it does not get to invent the curriculum, claim that an answer is correct, or hide where an explanation came from.

> Open the app, complete a focused 20–30 minute session, and leave measurably better at the iOS-development skills that matter most to you.

## The idea

Learning iOS development is rarely one subject. It spans language fundamentals, SwiftUI state and layout, concurrency, persistence, networking, testing, accessibility, legacy APIs, and the practical decisions that turn code into a shippable app. Daily Swift is designed to make that landscape approachable without reducing it to a streak counter or an endless feed of generated text.

The intended experience combines a clear skill path with daily lessons, quizzes, coding challenges, review, and project work. Motivation systems—progression, achievements, and a friendly companion—are meant to support consistent practice, never to stand in for real mastery.

## What makes it different

### A curriculum comes first

A versioned competency graph is the long-term source of truth. AI is a constrained collaborator inside that structure: it can select, explain, combine, and generate learning material, but it does not decide what the learner should master or rewrite their progress based on confidence alone.

### Your sources stay yours

Learners can import material they lawfully possess, including text, Markdown, and text-based PDFs. The app keeps those sources on device, preserves rights metadata and exact citation locations, and treats every imported document as untrusted data. There is no web crawling, automatic acquisition, or silent cloud handoff.

### Generated learning is cited and bounded

The current experimental generation flow retrieves a small set of relevant local passages, creates a cited article and multiple-choice quiz, validates its structure and citations, and saves accepted artifacts locally. Each citation can lead back to the precise source location. Artifacts with missing, stale, malformed, or overly copied source content are rejected rather than presented.

### Honest feedback over theatrical certainty

Where an answer can be checked deterministically, it should be. Generated quiz answers are explicitly labeled as experimental answer-key matches and are kept separate from verified correctness, mastery, and prerequisite unlocking. The same principle applies to code execution: arbitrary Swift or SwiftUI compilation on iPhone is a feasibility question, not a promise the app makes today.

## Current foundations

- Native iPhone experience built with SwiftUI and modern Swift concurrency.
- A four-part learning studio for Today, Challenges, Library, and Progress.
- Typed navigation, recoverable launch/restoration states, and explicit dependency composition.
- Local learner evidence and preferences backed by SwiftData, with large private material stored separately in Application Support.
- Local source import, deterministic text processing and retrieval, and exact TXT, Markdown, and PDF citation navigation.
- An app-owned language-model provider boundary with an experimental Apple Foundation Models adapter and deterministic fakes for predictable development and testing.
- Local generated-learning history with versioned identities, atomic persistence, stable quiz order, cancellation handling, and fail-closed restoration.
- Accessibility and privacy designed into the flow: semantic state messages, scalable layouts, non-color status communication, and no private source text or prompts in diagnostics.

## Architecture at a glance

Daily Swift intentionally stays in one application target while its boundaries are still proving themselves. The architecture favors pragmatic MVVM, narrow protocols, explicit dependencies, and one-way state changes:

```text
SwiftUI view
    → main-actor view model
        → use case or focused service protocol
            → local or platform adapter
```

The application composition root assembles its environment at launch. Views render state and send user intent; they do not own persistence, routing, retrieval, model selection, or validation. This keeps the product usable with deterministic fakes and makes risky platform integrations easy to isolate.

## Product principles

| Principle | In practice |
| --- | --- |
| Local-first | Core learning, sources, progress, and accepted history remain useful without a network connection. |
| Provenance | Generated material keeps resolvable source identities, hashes, and exact citations. |
| Deterministic where possible | Rules, validators, answer keys, parsers, and tests take precedence over model self-assessment. |
| Privacy by design | Private learning material remains on device and never enters logs or diagnostics. |
| Modern-first, legacy-aware | The product teaches current iOS approaches while making migration and maintenance skills first-class. |
| Accessible by default | VoiceOver, Dynamic Type, Reduce Motion, contrast, and non-color state communication are acceptance criteria. |

## Technology

- Swift 6 with strict concurrency checking
- SwiftUI for the iPhone interface
- SwiftData for structured local learner data
- PDFKit for text-PDF handling and citation reading
- Foundation Models behind an app-owned provider abstraction
- Swift Testing and XCTest/XCUITest targets, executed in hosted CI

The product baseline is iOS 26.0 and iPhone only. It deliberately uses Apple-native runtime frameworks and avoids third-party runtime dependencies in the main app.

## Project status

Daily Swift is an active personal-product project, not a finished public learning platform. The current work focuses on experimental, source-grounded generated learning from private imports. The Apple Foundation Models integration remains unpromoted until device evidence establishes its quality, latency, cancellation, memory, thermal, energy, and accessibility behavior.

That distinction matters: the app preserves accepted generated history and local source reading when generation is unavailable; on a fresh install with neither, it shows an honest empty or unavailable state rather than pretending a new lesson was generated.

Planned next steps include adaptive diagnostics, a fuller competency graph and mastery model, spaced review, richer project-based learning, motivation systems, safe code-lab capabilities, sync, export, and public-product hardening. Each step is gated by explicit architecture, privacy, accessibility, and validation decisions.

## Repository guide

- [Product and Engineering Master Plan](Docs/Product/daily-swift-master-plan.md) — vision, scope, principles, and technical boundaries.
- [Build and Development Plan](plans/build-and-development-plan.md) — active delivery sequence and current work packet.
- [Architecture Decision Records](Docs/Architecture/README.md) — accepted technical and product-boundary decisions.
- [Contributing guide](CONTRIBUTING.md) — local setup and contribution expectations.

## Building and validation

Open `Daily Swift.xcodeproj` in Xcode, select the shared **Daily Swift** scheme, and build for an iPhone destination. The project uses signing-independent build configuration for automation.

Automated unit, UI, and performance tests are intentionally run in the hosted CI workflow rather than on local machines. Local work is checked with repository hygiene, static review, and build-only validation; the hosted `Project Hygiene`, `Build`, and `Tests` checks remain the source of truth for automated verification.

## License and content

The application engine and educational content/assets are intentionally treated as separate licensing decisions. Imported learner material remains private and local-only. Public distribution, sharing, bundled third-party educational material, and export of generated content each require explicit policy before they are introduced.
