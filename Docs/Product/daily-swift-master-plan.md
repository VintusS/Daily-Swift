# Daily Swift — Product and Engineering Master Plan

**Status:** Product baseline for a personal iPhone app that can later become a public, open-source subscription product
**Primary platform:** iPhone
**Minimum OS:** iOS 26
**UI:** SwiftUI
**Architecture preference:** pragmatic MVVM, Apple-native frameworks, no third-party runtime dependencies in the main app
**Initial user:** the developer/owner, upper-intermediate Swift developer
**Working product name:** Daily Swift
**Last amended:** 2026-08-01 — generated-only learner presentation

---

## 1. Product vision

Daily Swift is an adaptive, gamified iOS-development teacher. It should identify a learner’s current ability, construct a personalized path through Swift, SwiftUI, and the wider iOS SDK, and turn trusted learning material into short interactive lessons, quizzes, coding challenges, reviews, and projects.

The app should preserve what made Unwrap engaging:

- short sessions;
- a visible level map;
- daily challenges;
- streaks;
- XP and progression;
- varied question formats;
- achievements;
- animations and sound;
- an approachable companion or pet;
- immediate feedback.

Daily Swift should exceed Unwrap by teaching the full iOS-development ecosystem, supporting modern and older APIs, importing private learning material, generating original personalized lessons, and adapting continuously to the learner’s mastery.

### Core promise

> Open the app, complete a focused 20–30 minute session, and leave measurably better at the iOS-development skills that matter most to you.

### Primary success journey

1. The learner selects a goal.
2. The app runs an adaptive diagnostic assessment.
3. The app produces a competency profile and personalized learning map.
4. The learner completes a daily queue of lessons and challenges.
5. The app detects weak skills, schedules reviews, and adjusts difficulty.
6. The learner finishes chapter projects and exports code for Xcode.
7. The app periodically reports measurable skill growth and recommends the next track.

---

## 2. Product principles

### 2.1 Learning quality before unlimited generation

The app must not ask an LLM to invent a full curriculum from nothing. A manually designed, versioned competency graph is the authoritative backbone. AI selects, explains, combines, and generates material inside that structure.

The learner may explicitly request new grounded variations repeatedly. This is
not a promise of infinite artifacts, device storage, model availability, or
semantic novelty; every request still passes the same source, provenance, and
presentation gates.

### 2.2 Deterministic evaluation where possible

The LLM may create candidate exercises, but correctness should be decided by deterministic validators, answer keys, rules, parsers, tests, or a compiler whenever possible. The model should not be the sole judge of whether code is correct.

### 2.3 Local-first and offline-capable

The default learning, retrieval, generation, progress tracking, and tutoring path should work on-device after required sources and model assets are available. Cloud AI is an optional later enhancement and must be explicitly enabled.

### 2.4 Provenance is part of the lesson

Every generated lesson must retain source provenance. The learner should be able to open the exact source document, article, page, section, or URL used to create an explanation.

### 2.5 Gamification supports learning

XP, streaks, lives, currency, achievements, and the pet should encourage practice. They must not distort mastery, hide core education behind artificial scarcity, or make mistakes feel like failure.

### 2.6 Modern-first, legacy-aware

Teach current APIs as the recommended path. Older APIs appear in migration lessons, maintenance tracks, and compatibility exercises, clearly labeled by OS and deprecation status.

### 2.7 Open-source code, separately licensed content

The application engine can be open source. Bundled educational content, source documents, models, mascots, sounds, and artwork require their own explicit licenses.

---

## 3. Confirmed scope

### Audience

- Multiple skill levels.
- Basic programming knowledge is assumed.
- Initial personal use, later public release.
- English interface and learning content initially.

### Learning goals

Users choose one or more goals:

- strengthen Swift fundamentals;
- master advanced Swift;
- learn SwiftUI;
- build complete iOS apps;
- learn specific iOS frameworks;
- understand architecture and testing;
- maintain older codebases;
- prepare for interviews;
- build a first production-ready app;
- close identified skill gaps.

### Curriculum scope

The long-term curriculum includes:

1. Swift language fundamentals.
2. Standard library and collections.
3. Protocols, generics, errors, value/reference semantics.
4. Modern concurrency.
5. SwiftUI fundamentals.
6. State, data flow, Observation, bindings, and environment.
7. Layout, drawing, animation, gestures, and accessibility.
8. Navigation, scenes, lifecycle, deep links, and app structure.
9. Networking, Codable, URLSession, caching, and offline behavior.
10. Persistence: files, UserDefaults, Keychain, Core Data, SwiftData, CloudKit.
11. Architecture: MVVM, dependency boundaries, modularity, and migrations.
12. Testing: Swift Testing, XCTest, UI testing, test doubles, and testability.
13. Debugging, Instruments, memory, performance, and energy use.
14. UIKit and SwiftUI interoperability.
15. Legacy APIs and migration paths.
16. App distribution, StoreKit, privacy, accessibility, and App Store concerns.
17. Interview preparation.
18. iOS frameworks and technologies, including framework-specific learning islands.

The app intentionally excludes teaching macOS, watchOS, tvOS, and visionOS as separate platforms. Cross-platform APIs may be mentioned only where needed to explain iOS behavior.

---

## 4. Technical feasibility decisions

## 4.1 On-device AI

The preferred on-device implementation uses Apple’s Foundation Models framework
through an app-owned provider abstraction. It remains experimental until the
provider-promotion evidence below is accepted.

### Provider design

```text
LanguageModelProvider
├── AppleFoundationModelProvider   // experimental; preferred future default
├── CoreMLModelProvider            // future downloadable specialist models
└── CloudModelProvider             // future, explicit opt-in
```

The app must check model availability at runtime and handle:

- Apple Intelligence disabled;
- unsupported device;
- model not downloaded or not ready;
- language or region restrictions;
- model-version changes after OS updates.

### Target MVP policy after provider promotion

The target policy below does not apply while the owner-directed experimental
exception remains active. Until promotion, that narrower exception and the
accepted architecture records control generation behavior.

- Apple’s system model is the only implemented model-backed provider.
- The architecture supports multiple providers without exposing unfinished choices.
- Generated lessons are cached per learner and prompt version.
- Generation may happen on demand or ahead of time.
- Larger batches should be scheduled opportunistically while charging and when thermal state is acceptable.

### Owner-directed experimental sequencing exception

On 2026-08-01, the owner deferred the Packet 000-A physical generation
benchmark and authorized a narrow production generated-learning slice. The
exception does not claim that any quality, latency, context, cancellation,
memory, energy, thermal, or accessibility threshold passed.

Until the benchmark is completed, Foundation Models remains an experimental,
unpromoted adapter behind the app-owned provider boundary. Generation is
foreground-only, learner-initiated, serial, cancellable, and limited to four
exactly cited source cards. The original experimental slice retained reviewed
deterministic content as its learner-facing fallback; the generated-only
completion follow-up below supersedes that presentation behavior. Generated
private-source quizzes are experimental activity and do not update mastery.
Automatic/background batches remain prohibited.

This exception permits production boundary, grounding, validation, local
history, and accessible generated-learning UI work. It does not authorize web
crawling, third-party content bundling, redistribution, or use of private source
text outside the accepted local-only rights boundary.

The experimental slice stores versioned history rather than performing cache
lookup or silent reuse. Cache deduplication, quotas, learner-facing storage
controls, and automatic eviction require a later accepted policy. Generated
answer-key matches remain experimental activity rather than verified
correctness. Deleting or rolling back generated presentation artifacts may
retain source-free activity identifiers, flags, and timestamps under ADR-011;
they never update mastery.

The model is instructed to use original wording and avoid extended quotation,
but that instruction is not proof of originality. The private presentation gate
also rejects 16 or more consecutive normalized words copied from any supplied
source card. That conservative limit is not proof of broader copyright
compliance. Experimental private artifacts are not authorized for sharing,
redistribution, or export; those capabilities require a separate rights
decision and stronger policy.

### Owner-directed generated-only presentation completion follow-up

On 2026-08-01, after the first generated-learning vertical was visible, the
owner directed that learner-facing articles and quizzes be generated-only. The
production Today, Library, and Challenges experiences must not display the
reviewed seed article or challenge bodies used by the deterministic learning
foundation. The manually designed competency graph remains authoritative, and
deterministic content may remain only as non-learner-facing assessment anchors,
test fixtures, previews, or explicitly gated Debug scenarios.

This decision supersedes learner-facing seed-fallback statements elsewhere in
this plan and in the earlier Packet 008 acceptance baseline. When a new request
cannot run or fails, the operational fallback is previously accepted generated
history, lawful imported-source reading and search, preservation of learner
data, an explicit unavailable or empty state, and retry. A fresh installation
may therefore have no article or quiz until a grounded request succeeds. The
app must not substitute a fixture or imply that new generation works without an
available provider.

Each learner-initiated Generate or New Variation action starts a fresh,
foreground, serial request and receives a new artifact identity after
acceptance. The product imposes no arbitrary count quota, but this is not an
infinite-storage or uninterrupted-capacity guarantee: source-evidence bounds,
model availability, validation, cancellation, finite device storage, and
recoverable persistence failures still apply. Background and bulk generation
remain prohibited while the provider is experimental.

Quality-feedback collection is not part of this completion follow-up. A future
Good or Bad rating must remain app-owned subjective feedback and must never be
described as training the Apple system model or changing model weights, content
trust, answer correctness, mastery, or curriculum. Rating storage, behavior,
export, or dataset use requires a separate work packet and accepted
architecture, privacy, consent, source-rights, retention, deletion, and
device-evidence decision.

### Context limitation

The model context is too small to ingest complete books directly in one prompt. Daily Swift must use retrieval and staged generation:

1. retrieve a few relevant source chunks;
2. build compact source cards;
3. generate one lesson or exercise set;
4. validate the output;
5. store the accepted result under the current identity policy; use it as a
   cache only after cache lookup and invalidation are separately accepted.

## 4.2 True Swift compilation on iPhone

This is the primary technical risk.

There is no normal public iOS framework that exposes Xcode’s Swift compiler. A third-party educational app cannot simply call `swiftc` as a process. SwiftUI code is even harder because dynamically compiled UI code cannot be freely loaded into the running signed app.

The following requirements cannot all be guaranteed simultaneously:

- actual arbitrary Swift compilation;
- actual arbitrary SwiftUI execution;
- iPhone-only;
- fully offline;
- Apple frameworks only;
- no embedded compiler/runtime;
- no backend;
- future App Store distribution.

### Required architecture decision

Treat code execution as an independent subsystem with capability levels.

#### Execution level A — deterministic exercises

Available in the first functional build:

- multiple choice;
- fill missing tokens;
- reorder lines;
- predict output using authored expected results;
- find the bug;
- repair a constrained snippet;
- explain code;
- flashcards;
- structured SwiftUI repair exercises;
- project instructions and rubrics.

These do not claim to compile arbitrary code.

#### Execution level B — constrained local runner

A later experimental runner can support a deliberately limited Swift subset or precompiled exercise templates. It may evaluate expressions and control flow, but must be clearly labeled as a subset rather than the complete Swift compiler.

#### Execution level C — full Swift compiler experiment

A blocking technical spike must investigate:

- embedding Swift compiler components in-process;
- compiling to WebAssembly;
- executing in a sandboxed WebAssembly runtime;
- binary size, memory, thermal impact, and startup cost;
- App Review implications;
- source visibility and editability requirements;
- supported Swift language and standard-library surface.

This path requires relaxing the “Apple frameworks only” rule for the execution subsystem by using open-source Swift compiler/runtime components.

#### Execution level D — external compiler

Public-product fallback options:

- optional sandboxed compiler service;
- local Mac companion on the same network;
- exported Swift package opened and compiled in Xcode.

### Recommendation

Do not block the learning product on arbitrary compilation. Build the learning, assessment, retrieval, generation, and gamification engines first. Run the compiler spike before promising full compilation as a public feature.

For SwiftUI exercises, the practical on-device solution is:

- use precompiled configurable views for live visual challenges;
- statically evaluate required constructs and modifiers;
- export complete source to Xcode for real compilation;
- add external compilation only after the execution spike succeeds.

## 4.3 iCloud and identity

Use Apple identity rather than a custom backend account in the personal and first public versions.

- iCloud/CloudKit stores synchronized progress and lightweight user data.
- Game Center provides social identity, leaderboards, friends, and achievements.
- StoreKit provides subscription entitlement.
- No custom password database is required.
- The app remains usable during temporary network loss with local data.

## 4.4 Native-only interpretation

“Native only” means:

- Swift and SwiftUI application code;
- Apple frameworks for UI, persistence, networking, AI, document handling, subscriptions, social features, logging, and testing;
- no third-party analytics, networking, database, UI, or dependency-injection frameworks;
- open-source compiler or parsing components are isolated behind the execution subsystem only if the full compiler experiment requires them.

---

## 5. Curriculum architecture

## 5.1 Competency graph

The curriculum is a directed graph rather than a flat course.

Each `Concept` contains:

- stable identifier;
- title and concise description;
- domain and subdomain;
- difficulty range;
- prerequisites;
- recommended successors;
- current API status;
- supported iOS/Swift versions;
- legacy and migration relationships;
- learning objectives;
- exercise capabilities;
- project associations;
- trusted source references.

### Node types

- concept lesson;
- guided practice;
- review;
- challenge;
- chapter boss test;
- mini-project;
- complete project;
- framework island;
- legacy migration lesson;
- interview drill;
- mastery checkpoint.

### Ordering rules

- Hard prerequisites remain ordered.
- Independent subjects are explorable.
- Users may skip ahead by passing mastery checks.
- The map highlights recommended, optional, locked, completed, and review-due nodes.

## 5.2 Curriculum tracks

### Track A — Swift Core

Syntax, types, optionals, collections, functions, closures, structs, classes, enums, protocols, generics, errors, memory, value semantics, and standard-library fluency.

### Track B — Advanced Swift

Protocol-oriented design, opaque/existential types, result builders, property wrappers, macros, advanced generics, ownership-related concepts, performance, and language evolution.

### Track C — Concurrency

Async/await, tasks, task groups, actors, isolation, Sendable, cancellation, structured concurrency, migration from callbacks and Combine, testing concurrent code, and common race conditions.

### Track D — SwiftUI

Views, modifiers, composition, state, bindings, Observation, environment, navigation, lists, forms, layout, drawing, animation, gestures, accessibility, app lifecycle, performance, and testing.

### Track E — App Foundations

Architecture, dependency boundaries, networking, persistence, authentication, app configuration, errors, logging, caching, security, localization, and accessibility.

### Track F — Framework Islands

Initial framework catalog:

- Foundation;
- Observation;
- Combine and migration away from unnecessary Combine usage;
- URLSession and Network;
- SwiftData and Core Data;
- CloudKit;
- StoreKit;
- AuthenticationServices;
- Security and Keychain;
- UserNotifications;
- BackgroundTasks;
- App Intents;
- WidgetKit and ActivityKit;
- MapKit and Core Location;
- Photos and PhotoKit;
- AVFoundation;
- Vision;
- Core ML;
- HealthKit;
- WebKit and SafariServices;
- Contacts and EventKit;
- Core Bluetooth;
- Core NFC;
- MultipeerConnectivity;
- ARKit where relevant to iPhone;
- Metal fundamentals where relevant to iOS.

### Track G — Testing, Debugging, and Performance

Swift Testing, XCTest, UI tests, Instruments, allocations, leaks, retain cycles, responsiveness, launch performance, rendering performance, networking diagnostics, energy, and production debugging.

### Track H — Legacy and Migration

UIKit patterns, delegates, completion handlers, Combine-heavy code, ObservableObject, older navigation APIs, Core Data stacks, deprecated SwiftUI modifiers, and modern migration plans.

Every legacy concept receives one of these labels:

- `legacy-relevant`;
- `deprecated-reference`;
- `migration-required`;
- `historical-only`.

### Track I — Interview Preparation

Language questions, output prediction, debugging, architecture discussion, concurrency reasoning, framework knowledge, take-home simulation, and code-review exercises.

---

## 6. Initial assessment and mastery

## 6.1 Diagnostic assessment

The initial assessment should be adaptive and goal-aware, not a fixed quiz.

### Recommended structure

1. Goal selection.
2. Self-reported experience and recent projects.
3. A short calibration set across core Swift, SwiftUI, and iOS concepts.
4. Adaptive follow-up questions near the estimated skill boundary.
5. Goal-specific probes.
6. One or more code-reading/debugging tasks.
7. A confidence review where the learner can flag unfamiliar but lucky answers.

### Question count

Use a target range rather than a fixed count:

- minimum useful diagnostic: about 25 items;
- normal diagnostic: 35–50 items;
- extended diagnostic: up to 60 items when uncertainty remains.

The assessment can be paused. Its progress should survive termination and device sync.

### Assessment output

- overall estimated level;
- per-domain mastery;
- confidence for each estimate;
- detected gaps;
- concepts eligible to skip;
- recommended starting node;
- first seven-day learning plan;
- suggested daily XP and time target.

## 6.2 Mastery model

Maintain mastery per concept rather than only XP.

Suggested fields:

- `masteryScore` from 0 to 1;
- `estimateConfidence`;
- `lastPracticedAt`;
- `nextReviewAt`;
- `attemptCount`;
- `correctStreak`;
- `hintDependence`;
- `averageResponseTime`;
- `difficultyCeiling`;
- `forgettingRate`;
- `evidenceByExerciseType`.

Correctness, difficulty, hints, response time, recency, and repeated evidence update mastery. XP never substitutes for mastery.

## 6.3 Spaced repetition

Spaced repetition is central. The daily queue combines:

- due reviews;
- current path lessons;
- weak-concept repair;
- one stretch challenge;
- optional exploration;
- a daily challenge.

A user who repeatedly misses a concept should receive a deeper explanation and prerequisite review, not only a repeated identical question.

---

## 7. Source library and ingestion

## 7.1 Source categories

### Bundled/default sources

Only include content that is official, open-licensed, public-domain, or separately licensed for redistribution.

Recommended default catalog:

- Apple Developer documentation;
- Apple tutorials and sample code;
- WWDC session metadata and transcripts where permitted;
- Swift.org language documentation;
- Swift Evolution proposals;
- selected openly licensed educational material;
- source manifests linking to reputable authors and publishers.

### Curated external sources

Maintain a catalog of high-quality sources such as Hacking with Swift, Swift by Sundell, SwiftLee, objc.io, Donny Wals, Point-Free, and other respected iOS educators. The public app should not bundle or republish their full copyrighted material without permission. It may retain links, metadata, user-created notes, and legally permitted excerpts.

### Private user imports

Users may import material they lawfully possess:

- PDF;
- plain text;
- Markdown;
- HTML or saved webpage;
- notes;
- later: EPUB;
- later: repositories or selected source files.

Private source contents remain on-device by default.

## 7.2 “Available online” is not a license

Do not automatically treat a downloadable PDF as distributable. The public product must never ship random books merely because copies exist online.

Use this policy:

- personal build: user may import a lawful private copy;
- public default pack: only licensed or freely distributable sources;
- source catalog: links and metadata are allowed subject to source terms;
- generated content: original phrasing and exercises, with citations and quote limits;
- copyrighted full text: never uploaded to cloud without explicit consent.

## 7.3 Import pipeline

```text
Import
→ identify format
→ extract text and structure
→ detect headings and code blocks
→ normalize whitespace and symbols
→ attach metadata and rights status
→ chunk semantically
→ generate fingerprints
→ index for retrieval
→ optionally produce a compact source summary
→ mark ready
```

### Native extraction

- PDFKit for text-based PDFs.
- Vision as an optional fallback for scanned pages, invoked only when required.
- URLSession and WebKit for permitted web content.
- XMLParser and Foundation utilities for structured formats.
- FileImporter and a Share Extension for user-driven imports.

### Chunk metadata

Every chunk stores:

- source document ID;
- heading path;
- page or section range;
- code-language marker;
- character/token count;
- content hash;
- author and publication metadata;
- source URL where relevant;
- rights status;
- framework and API tags;
- version tags;
- local-only flag.

## 7.4 Storage strategy

- SwiftData is the source of truth for metadata, relationships, progress, and generated-content records.
- Full imported files and large extracted text live in Application Support.
- A native SQLite FTS5 index may be used as a derived, rebuildable keyword index.
- Embeddings are stored as derived files or compact data blobs and are never the source of truth.
- Raw imported books and model files are excluded from routine CloudKit sync.
- iCloud sync stores source fingerprints, bookmarks, annotations, and generation manifests unless the user explicitly chooses document sync.

## 7.5 Retrieval strategy

Use hybrid retrieval:

1. filter by curriculum concept, framework, API version, and learner goal;
2. keyword retrieval;
3. semantic reranking;
4. source diversity selection;
5. recency/version preference;
6. final chunk budget construction.

The retrieval engine should prefer official documentation for factual API behavior and use teaching sources for explanations, analogies, and examples.

---

## 8. AI content-generation system

## 8.1 Main components

```text
AIContentOrchestrator
├── ModelAvailabilityService
├── RetrievalService
├── SourceCardBuilder
├── LessonPlanner
├── LessonGenerator
├── ExerciseGenerator
├── HintGenerator
├── TutorService
├── CitationResolver
├── ContentValidator
├── DifficultyCalibrator
├── DeduplicationService
└── GenerationCache
```

Each component is protocol-driven and testable with deterministic fakes.

## 8.2 Generated artifacts

The AI may generate:

- lesson explanations;
- examples;
- analogies;
- summaries;
- multiple-choice questions;
- fill-code questions;
- rearrangement questions;
- output-prediction questions;
- debugging exercises;
- SwiftUI repair challenges;
- hints;
- deeper remediation lessons;
- flashcards;
- interview prompts;
- project briefs;
- test cases and rubrics;
- personalized review sets;
- tutor replies;
- progress summaries.

## 8.3 Generation workflow

```text
Learner need
→ select concept and target difficulty
→ retrieve trusted chunks
→ build source cards
→ choose artifact schema
→ generate structured candidate
→ validate citations
→ validate API/version claims
→ validate answer determinism
→ validate code where supported
→ check duplicate risk
→ calibrate difficulty
→ assign trust tier
→ cache and present
```

Use structured generation types rather than asking for free-form JSON.

## 8.4 Content trust tiers

### Tier 1 — Reviewed Core

Manually authored or manually approved. Stable and suitable for assessment anchors.

### Tier 2 — Verified Generated

Generated content that passes all applicable validators and references trusted sources.

### Tier 3 — Generated Draft

Useful but missing a strong validator, compiler result, or sufficient source coverage. Clearly labeled.

### Tier 4 — Experimental/User Material

Generated primarily from user-provided or unverified sources.

## 8.5 Confidence indicator

Never display the model’s self-reported confidence as truth. Calculate confidence from evidence:

- source coverage;
- citation validity;
- source authority;
- API-version agreement;
- answer uniqueness;
- deterministic validation;
- compiler/test result;
- duplicate risk;
- prompt/model version stability.

## 8.6 Hallucination controls

- The model receives source text as untrusted reference data, not instructions.
- Source chunks are delimited and stripped of executable prompt directives.
- The model may not invent citations.
- Every citation must resolve to a stored source and location.
- Factual Apple API claims prefer Apple sources.
- Generated code must be version-tagged.
- Deprecated APIs require explicit labels.
- Incorrect or ambiguous questions are reportable and regenerable.
- The system keeps the failed artifact for diagnostics but removes it from the learner queue.

## 8.7 Generation policy

Generate per learner, but cache by:

- learner profile version;
- concept;
- difficulty;
- source-set hash;
- prompt version;
- model version;
- exercise schema version.

“Personalized” should not mean wastefully regenerating identical content every time a screen opens.

An explicit learner request for a new variation is different from reopening a
screen: it must not silently return the prior presentation artifact. Exact and
semantic duplicate suppression remain deferred validation work, so the product
must not claim that a fresh request is inherently random, unique, or guaranteed
to differ in wording.

---

## 9. Exercise engine

## 9.1 Exercise protocol

All exercises conform to one domain model with type-specific payloads.

Common fields:

- ID and schema version;
- concept IDs;
- difficulty;
- prompt;
- source citations;
- expected answer/rubric;
- hint sequence;
- time recommendation;
- XP reward;
- heart policy;
- validation capability;
- explanation and remediation links;
- generation and trust metadata.

## 9.2 Required activity types

1. Multiple choice.
2. Multiple select.
3. Fill missing code.
4. Tap tokens to construct code.
5. Reorder lines.
6. Predict output.
7. Spot the error.
8. Repair the code.
9. Write a snippet.
10. Explain code.
11. Flashcard recall.
12. Match concepts.
13. API availability question.
14. Legacy-to-modern migration.
15. SwiftUI modifier ordering.
16. Repair a SwiftUI view.
17. Visual result selection.
18. Test-writing exercise.
19. Code-review exercise.
20. Mini-project task.
21. Chapter project.
22. Interview simulation.

## 9.3 Feedback behavior

On a wrong answer:

1. show a concise explanation of the specific mistake;
2. reveal a guided hint or source excerpt;
3. offer a deeper lesson;
4. schedule a prerequisite review when evidence suggests a gap;
5. generate a new equivalent question rather than immediately repeating the same wording.

## 9.4 Hints and currency

Hints cost in-game currency in scored progression sessions. However:

- the first accessibility-related clarification is free;
- tutor questions are not blocked by currency;
- users may choose an accessibility setting that removes economic pressure from hints;
- using a hint reduces bonus XP but does not erase learning progress.

---

## 10. Code Lab

## 10.1 Editor design

Build an Xcode-inspired editor using SwiftUI with a UIKit/TextKit 2-backed text view where needed.

Features:

- monospaced editor;
- line numbers;
- syntax highlighting;
- automatic indentation;
- bracket pairing;
- configurable autocomplete;
- diagnostics gutter;
- inline hints;
- multiple files;
- exercise instructions panel;
- console/output panel;
- test-results panel;
- source references;
- light/dark themes;
- Dynamic Type and VoiceOver support.

Autocomplete is optional in Settings and may be disabled during assessments.

## 10.2 Workspace model

A project workspace contains:

- package manifest metadata;
- source files;
- resources;
- exercise tests or rubrics;
- target iOS/Swift version;
- dependencies restricted to allowed system frameworks;
- learner checkpoints;
- export history.

## 10.3 Export

The practical initial export is an Xcode-openable Swift package or project folder archive:

- source files;
- README with instructions;
- exercise requirements;
- tests where possible;
- source citations;
- learner notes.

Use ShareLink, Files, AirDrop, or iCloud Drive to move the package to a Mac.

## 10.4 Compilation capability labels

Every code exercise shows one of:

- `Compiled and tested`;
- `Deterministically validated`;
- `Statically checked`;
- `Rubric evaluated`;
- `Experimental`.

Never imply true compilation when only AI or static rules were used.

---

## 11. Gamification design

## 11.1 Core systems

The first complete product includes:

- XP;
- player levels;
- concept mastery levels;
- streaks;
- streak freezes and recovery;
- hearts/lives;
- achievements;
- daily quests;
- weekly goals;
- seasonal challenges later;
- unlockable map paths;
- in-game currency;
- chapter boss tests;
- pet progression;
- animations, sounds, haptics;
- social comparison and leaderboards later.

## 11.2 Economy

Use two values:

### XP

- cannot be spent;
- represents activity and consistency;
- drives player level and league score;
- does not represent mastery.

### Coins

Earned from:

- completing lessons;
- perfect challenges;
- streak milestones;
- chapter projects;
- reviewing weak concepts;
- achievements.

Spent on:

- hints;
- streak recovery;
- heart recovery;
- optional extra subjects in a chapter;
- challenge rerolls;
- pet cosmetics;
- map themes and celebrations.

Coins must not buy mastery or correct answers.

## 11.3 Hearts/lives

Hearts apply to scored map progression and daily challenges.

To prevent gamification from blocking education:

- practice mode remains open with zero hearts;
- source reading remains open;
- tutor access remains open;
- review exercises can restore hearts;
- an accessibility setting can soften or disable heart loss;
- subscription status must not grant fake mastery.

## 11.4 Streaks

A streak day is earned by meeting either the learner’s time goal or XP goal. The learner chooses the preferred metric and can enable both.

Support:

- streak freeze;
- limited streak recovery;
- travel/time-zone protection;
- honest local calendar handling;
- no manipulative countdowns.

## 11.5 Level map

The map is generated from the competency graph and learner state.

Visual node states:

- locked prerequisite;
- recommended next;
- available exploration;
- in progress;
- mastered;
- review due;
- boss challenge;
- project;
- framework island;
- legacy/migration node.

## 11.6 Pet companion

Working pet name: **Byte**.

Byte should:

- react to progress and streaks;
- celebrate mastery;
- provide short reminders;
- visually grow or unlock forms;
- wear earned cosmetics;
- appear in empty states and loading moments;
- never shame the learner.

All animations and sounds respect Reduce Motion, VoiceOver, and mute settings.

## 11.7 Social features

Use Game Center when the public product reaches social scope:

- friends;
- recurring XP leaderboards;
- challenge scores;
- achievements;
- optional shared challenges.

Do not create a custom social network in the MVP.

---

## 12. Daily learning experience

## 12.1 Home screen

The home screen should answer four questions immediately:

1. What should I do today?
2. How long will it take?
3. What skill am I improving?
4. What reward or progress will I earn?

Recommended sections:

- continue daily plan;
- streak and goal status;
- pet status;
- due reviews;
- recommended path node;
- daily challenge;
- current project;
- newly available framework island;
- progress insight.

## 12.2 Daily queue

A normal 20–30 minute queue:

1. two-minute recall warm-up;
2. one short lesson;
3. two to four varied exercises;
4. one weak-skill review;
5. one stretch challenge;
6. reward summary and next recommendation.

## 12.3 Session adaptation

The queue changes based on:

- time available;
- mastery uncertainty;
- recent mistakes;
- goal priority;
- due reviews;
- model availability;
- battery and thermal state;
- whether generated content is ready.

When AI generation is unavailable, previously accepted generated history and
lawful imported-source reading remain available offline. If neither exists, the
app presents an honest empty or unavailable state; it does not insert an
authored seed article or quiz into the learner-facing queue.

---

## 13. Data architecture

## 13.1 Core domain entities

- `UserProfile`
- `LearningGoal`
- `CompetencyDomain`
- `Concept`
- `PrerequisiteEdge`
- `CurriculumNode`
- `LearningPath`
- `AssessmentSession`
- `AssessmentItem`
- `MasteryState`
- `ReviewSchedule`
- `SourceDocument`
- `SourceChunk`
- `Citation`
- `LessonTemplate`
- `GeneratedLesson`
- `Exercise`
- `ExerciseAttempt`
- `ProjectWorkspace`
- `DailyPlan`
- `XPEvent`
- `CurrencyTransaction`
- `StreakState`
- `AchievementState`
- `PetState`
- `GenerationJob`
- `GenerationArtifact`
- `ContentValidationReport`
- `ModelConfiguration`
- `PromptVersion`
- `ContentReport`
- `SyncRecord`

## 13.2 Persistence split

### SwiftData

Use for:

- user profile;
- goals;
- mastery;
- progress;
- curriculum metadata;
- lesson and exercise metadata;
- attempts;
- gamification state;
- source metadata;
- generation metadata;
- syncable settings.

### File storage

Use for:

- original imports;
- extracted source text;
- generated long-form content;
- code workspaces;
- model assets;
- embeddings;
- derived indexes;
- export archives.

### Keychain

Use for:

- sensitive tokens if cloud AI is introduced;
- installation secrets;
- secure account-related state.

## 13.3 CloudKit sync

Sync lightweight personal data:

- goals;
- progress;
- mastery;
- streaks;
- achievements;
- generated-content manifests;
- notes;
- bookmarks;
- settings;
- project metadata.

Avoid syncing by default:

- downloaded models;
- large raw books;
- rebuildable embeddings;
- FTS indexes;
- temporary generation artifacts.

The sync design must include conflict resolution, schema migration tests, and an offline queue.

## 13.4 Export and deletion

The learner can export:

- progress as JSON;
- mastery report as JSON/Markdown;
- imported-source manifest;
- generated lessons;
- project workspaces;
- settings and gamification state.

The app must support complete local deletion and, for public release, deletion of synced user data.

---

## 14. Application architecture

## 14.1 Architectural style

Use pragmatic MVVM with explicit service protocols and unidirectional state updates.

Avoid:

- giant view models;
- service locators hidden throughout the app;
- business logic in SwiftUI views;
- SwiftData models directly controlling UI behavior everywhere;
- premature micro-packages;
- a generic “clean architecture” layer for every trivial action.

## 14.2 Dependency structure

```text
SwiftUI View
→ Feature ViewModel
→ Use Case / Domain Service
→ Repository or Platform Service
→ SwiftData / Files / Foundation Models / CloudKit / GameKit / StoreKit
```

Use an `AppEnvironment` assembled at launch and passed through explicit initializers or a controlled environment value.

## 14.3 Concurrency

Use Swift concurrency throughout.

Recommended actors:

- `SourceImportActor`;
- `IndexingActor`;
- `GenerationActor`;
- `ProgressActor`;
- `WorkspaceActor`;
- `SyncCoordinator` where actor isolation is beneficial.

UI view models remain main-actor isolated.

## 14.4 Suggested project structure

```text
DailySwift/
├── App/
│   ├── DailySwiftApp.swift
│   ├── AppEnvironment.swift
│   ├── AppRouter.swift
│   └── AppConfiguration.swift
├── Core/
│   ├── Domain/
│   ├── Persistence/
│   ├── Files/
│   ├── AI/
│   ├── Retrieval/
│   ├── Execution/
│   ├── Sync/
│   ├── Gamification/
│   ├── DesignSystem/
│   ├── Logging/
│   └── Utilities/
├── Features/
│   ├── Onboarding/
│   ├── Assessment/
│   ├── Home/
│   ├── LearningMap/
│   ├── LessonPlayer/
│   ├── ExercisePlayer/
│   ├── CodeLab/
│   ├── SourceLibrary/
│   ├── Tutor/
│   ├── Projects/
│   ├── Progress/
│   ├── Pet/
│   ├── Social/
│   ├── Store/
│   └── Settings/
├── Resources/
│   ├── Curriculum/
│   ├── SeedContent/
│   ├── Prompts/
│   └── Assets/
├── DailySwiftTests/
└── DailySwiftUITests/
```

Start with one app target plus test targets. Extract pure domain and generation logic into local Swift packages only when boundaries stabilize.

---

## 15. Navigation and main screens

### Onboarding

- product promise;
- Apple Intelligence availability;
- iCloud requirement and privacy;
- goal selection;
- daily goal selection;
- assessment introduction;
- assessment;
- results and generated map.

### Main tabs

Recommended first tab structure:

1. **Learn** — daily queue and map.
2. **Practice** — exercise catalog and reviews.
3. **Code** — workspaces and projects.
4. **Library** — sources and generated lessons.
5. **Profile** — mastery, streak, achievements, pet, settings.

### Key screens

- Home/Daily Plan;
- Skill Map;
- Lesson Player;
- Exercise Player;
- Challenge Results;
- Source Reader;
- AI Tutor;
- Code Lab;
- Project Workspace;
- Progress Report;
- Achievement Gallery;
- Pet Room;
- Source Import;
- Model and Offline Settings;
- Accessibility Settings.

---

## 16. Accessibility and interaction quality

Accessibility is required from the first functional version.

- Dynamic Type without clipped code controls.
- VoiceOver labels and ordered navigation.
- Accessible code-line announcements.
- Color is never the only state indicator.
- Reduced Motion alternatives.
- Separate sound, haptic, and animation controls.
- Sufficient contrast.
- Keyboard and external-keyboard support where available.
- Hints for cognitive accessibility.
- No time-based penalties in accessibility mode.
- Charts include textual summaries.
- Pet and reward animations never block task completion.

---

## 17. Privacy, security, and legal design

## 17.1 Privacy

Default behavior:

- source documents remain on-device;
- generated content remains on-device and in private iCloud sync where applicable;
- no analytics SDK;
- no ad SDK;
- no source content sent to cloud AI without explicit per-use consent;
- any future generated-content Good/Bad ratings require a separate accepted
  local-storage, consent, and privacy decision and must not be described as
  model training;
- clear storage and deletion controls.

## 17.2 Prompt-injection defense

Imported content is untrusted data.

- source chunks cannot alter system instructions;
- tools exposed to the model are narrow and read-only;
- imported text cannot trigger network calls or code execution;
- citation IDs are assigned by the app, not invented by the model;
- generated tool calls are validated before execution.

## 17.3 Copyright

- Do not redistribute Unwrap assets or lesson content.
- Do not bundle copyrighted books without permission.
- Store per-source rights metadata.
- Generate original wording and exercises.
- Minimize direct quotation.
- Provide source links and local locations.
- Keep private imports private.
- Separate open-source code from licensed content and assets.

## 17.4 Open-source structure

Recommended licensing approach:

- app source: MIT or Apache 2.0;
- curriculum graph: separate license selected deliberately;
- generated seed content: separate content license;
- mascot/artwork/sounds: explicit asset license;
- model weights: individual model licenses;
- user-imported material: excluded from repository.

The repository must contain a `CONTENT_LICENSES.md` and a machine-readable source manifest.

## 17.5 Product name

“Daily Swift” remains a working title until a trademark, App Store name, domain, and repository-name check is completed before public branding.

---

## 18. Monetization and public product

### Free plan

- core curriculum;
- local Apple model features;
- daily learning queue;
- core gamification;
- source import limits generous enough for real use;
- progress sync;
- core Code Lab and exports.

### Subscription plan later

Possible benefits:

- advanced curated paths;
- premium framework packs;
- larger cloud-generation allowance;
- heavier compiler service;
- advanced project reviews;
- creator-recommended paths;
- extended reports and history;
- additional pet cosmetics that do not affect learning.

Use StoreKit. The developer/test account receives a permanent internal entitlement during personal development.

Do not monetize hearts in a way that blocks education. Do not make local AI or the core learning path paid-only, matching the product decision.

---

## 19. Testing and quality strategy

## 19.1 Unit tests

Prioritize:

- mastery updates;
- adaptive assessment selection;
- spaced-repetition scheduling;
- prerequisite graph traversal;
- daily-plan construction;
- XP and currency invariants;
- streak rules and time-zone behavior;
- source chunking;
- citation resolution;
- generation-cache keys;
- content validation;
- migration rules;
- model availability fallbacks.

## 19.2 Integration tests

- PDF import to searchable chunks;
- source retrieval to generated lesson;
- generated exercise to validation report;
- attempt to mastery and review update;
- CloudKit conflict resolution;
- workspace export;
- StoreKit entitlement in test configuration;
- Game Center authentication later.

## 19.3 UI tests

- first launch;
- assessment resume;
- daily session completion;
- wrong answer and remediation;
- zero-heart practice access;
- source citation opening;
- model-unavailable fallback;
- import flow;
- project export;
- accessibility labels on critical screens.

## 19.4 Generated-content evaluation suite

Maintain a fixed benchmark set covering:

- Swift syntax;
- concurrency;
- SwiftUI state;
- API availability;
- legacy migration;
- networking;
- persistence;
- architecture;
- testing;
- common misconceptions.

Run prompts against benchmark fixtures whenever the OS model or prompt version changes.

## 19.5 CI

GitHub Actions should run:

- build;
- unit tests;
- UI smoke tests where practical;
- schema migration tests;
- seed-content validation;
- source-manifest license validation;
- prompt and generated-schema validation;
- export-format tests.

Use Xcode’s native tooling and avoid third-party CI dependencies unless a later requirement justifies one.

## 19.6 Performance

Use OSLog, signposts, MetricKit, and Instruments.

Track:

- launch time;
- SwiftData fetches;
- memory during PDF extraction;
- indexing throughput;
- generation latency;
- token usage;
- editor responsiveness;
- thermal state;
- battery impact;
- CloudKit sync failures;
- cache hit rate.

---

## 20. Build roadmap

No phase is considered complete without tests and an explicit exit criterion.

## Phase 0 — Feasibility and architecture spikes

### Goals

- prove Foundation Models structured generation;
- measure generation quality and context limits on the iPhone Air;
- prove PDF extraction and retrieval;
- decide the code-execution strategy;
- prove an Xcode-like editor prototype;
- prove SwiftData and CloudKit sync;
- establish project architecture and decision records.

### Deliverables

- model availability demo;
- structured lesson and quiz generation demo;
- local source import and retrieval demo;
- compiler feasibility report with a go/no-go decision;
- editor prototype;
- data-model prototype;
- architecture decision records.

### Exit criterion

Every high-risk assumption has a measured result. The product does not proceed while pretending arbitrary on-device SwiftUI compilation is solved.

## Phase 1 — App foundation

### Deliverables

- SwiftUI app shell;
- navigation;
- app environment;
- SwiftData stack;
- logging;
- settings;
- accessibility baseline;
- seed design system;
- CI and core tests.

### Exit criterion

The app launches reliably, persists settings, supports testable feature boundaries, and passes CI.

## Phase 2 — Curriculum and assessment

### Deliverables

- versioned competency graph;
- initial Swift/SwiftUI/iOS seed curriculum;
- adaptive diagnostic engine;
- mastery model;
- assessment results;
- generated learning map;
- skip-ahead mastery checks.

### Exit criterion

A fresh learner can complete an assessment and receive a stable, explainable starting path without AI generation.

## Phase 3 — Source library and retrieval

### Deliverables

- PDF/TXT/Markdown import;
- source reader;
- metadata and rights state;
- semantic chunking;
- keyword index;
- retrieval engine;
- citation navigation;
- private storage controls.

### Exit criterion

The app imports a lawful PDF, finds relevant passages, and opens the exact cited location offline.

## Phase 4 — Lesson and exercise engine

### Deliverables

- lesson player;
- common exercise protocol;
- all required renderer categories;
- deterministic seed exercises;
- attempts and feedback;
- remediation paths;
- chapter boss tests;
- mini-project definitions.

### Exit criterion

A learner can complete a full chapter using trusted static content, and mastery/review state updates correctly.

The deterministic studio that first satisfied this criterion is retained as
historical foundation evidence. Under the generated-only presentation
amendment, its authored article and challenge bodies are not part of the
production learner catalog; deterministic fixtures remain available to verify
domain and assessment behavior.

## Phase 5 — Local AI learning pipeline

### Deliverables

- Apple Foundation Models provider;
- retrieval-augmented generation;
- structured lesson/exercise schemas;
- validators;
- confidence tiers;
- prompt versioning;
- caching;
- tutor;
- content reporting and regeneration.

### Exit criterion

The app can generate a cited personalized lesson and varied exercise set from imported and trusted sources, validate it, and fall back safely when generation is unavailable.

## Phase 6 — Gamification and daily experience

### Deliverables

- XP;
- levels;
- coins;
- hearts;
- streaks and recovery;
- daily/weekly quests;
- achievements;
- animated map;
- sounds and haptics;
- Byte pet MVP;
- daily 20–30 minute queue;
- skill reports.

### Exit criterion

The app supports repeated daily use without sacrificing review quality or blocking learning when hearts reach zero.

## Phase 7 — Code Lab and projects

### Deliverables

- editor;
- syntax highlighting;
- optional autocomplete;
- multi-file workspaces;
- static/deterministic validation;
- live precompiled SwiftUI challenges;
- project templates;
- Xcode-compatible export;
- compiler capability labels;
- result of the full compiler experiment.

### Exit criterion

A learner can complete and export a meaningful project, with honest validation labels and no false promise of compilation.

## Phase 8 — Sync, backup, and personal-version hardening

### Deliverables

- CloudKit sync;
- conflict handling;
- data export;
- restore flow;
- model/source storage management;
- offline mode;
- performance profiling;
- complete accessibility pass;
- migration tests.

### Exit criterion

The personal app satisfies the MVP success criteria and is safe to use as the developer’s daily learning tool.

## Phase 9 — Public product foundation

### Deliverables

- StoreKit subscriptions;
- free/paid entitlements;
- privacy disclosures;
- account and deletion behavior;
- content licensing audit;
- public seed-source policy;
- moderation for shared paths;
- App Review preparation;
- TestFlight telemetry with user consent.

### Exit criterion

The app can be distributed without relying on private copyrighted content or unsupported execution claims.

## Phase 10 — Social and creator ecosystem

### Deliverables

- Game Center leaderboards and achievements;
- friends and challenges;
- trusted recommended paths;
- creator manifests;
- path signing/versioning;
- review and moderation tools;
- seasonal content.

### Exit criterion

Shared content is safe, licensed, versioned, and cannot corrupt the authoritative curriculum or learner progress.

---

## 21. Functional personal MVP

The personal MVP is complete when it can:

1. Detect whether the on-device model is available.
2. Let the user choose goals and daily targets.
3. Run an adaptive diagnostic assessment.
4. Produce a domain-level skill report.
5. Generate a personalized map from a designed competency graph.
6. Import at least PDF, text, and Markdown sources.
7. Retrieve and open exact source locations.
8. Generate original cited lessons locally.
9. Generate varied exercises and validate them.
10. Support every core exercise category, with honest capability labels.
11. Update mastery and spaced-repetition schedules.
12. Build a 20–30 minute daily queue.
13. Provide XP, coins, hearts, streaks, achievements, and map progression.
14. Provide Byte as a functional companion.
15. Offer a local tutor at the learner’s discretion.
16. Store content and progress offline.
17. Sync progress through iCloud.
18. Export all learner data.
19. Create multi-file project workspaces.
20. Export projects for Xcode on Mac.
21. Pass automated tests and accessibility checks.
22. Preserve saved generated learning and lawful source reading when AI
    generation is temporarily unavailable, and present an honest empty state
    when neither exists.

### Explicit MVP limitation

Arbitrary local Swift and SwiftUI compilation is not an assumed MVP capability. It is included only if Phase 0 proves a safe, maintainable implementation. The UI must state the actual validator used.

---

## 22. Deferred features

Keep these out of the initial personal build unless required by a spike:

- custom social network;
- public creator marketplace;
- public comments or messaging;
- seasonal live operations;
- cloud AI billing;
- server compiler;
- EPUB import;
- repository-wide code analysis;
- iPad and Mac native apps;
- non-English localization;
- complex mascot customization;
- user-generated public courses;
- automatic refreshing of every external source;
- macOS/watchOS/tvOS/visionOS curricula.

---

## 23. Product risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Generated lesson is wrong | High | Designed curriculum, official-source preference, validators, trust tiers, reporting |
| Generated question has ambiguous answer | High | Deterministic answer schemas, uniqueness checks, reject uncertain artifacts |
| Local model context is too small | High | Retrieval, source cards, multi-stage generation, one artifact at a time |
| Local model unavailable | High | Preserve accepted generated history and source reading; present an honest empty/unavailable state when neither exists |
| Arbitrary Swift compilation is infeasible | High | Capability levels, compiler spike, export to Xcode, optional future service |
| SwiftUI code cannot run dynamically | High | Precompiled visual sandboxes, static checks, Xcode export |
| Copyright violation | High | Rights metadata, private imports, licensed public packs only |
| Large books/models consume storage | Medium | Storage dashboard, per-source download controls, derived-data cleanup |
| CloudKit conflicts corrupt progress | High | append-only attempt events, deterministic merging, migration and sync tests |
| Gamification blocks learning | Medium | practice/tutor/library always available, accessibility override |
| Prompt changes after OS update | Medium | prompt versioning and benchmark suite |
| Solo development scope becomes unmanageable | High | strict phase exits, vertical slices, deferred-feature list |
| Open-source repo leaks private content | High | content outside repository, ignore rules, automated license checks |

---

## 24. Architecture decision records required before feature work

Create these ADRs in `/Docs/Architecture/`:

1. ADR-001: Product architecture and MVVM boundaries.
2. ADR-002: SwiftData and file-storage split.
3. ADR-003: CloudKit sync and conflict resolution.
4. ADR-004: Competency graph and mastery model.
5. ADR-005: Foundation Models provider abstraction.
6. ADR-006: Retrieval and indexing approach.
7. ADR-007: Generated-content trust and validation.
8. ADR-008: Code-execution capability levels.
9. ADR-009: Source licensing and private imports.
10. ADR-010: Gamification economy and anti-blocking rules.
11. ADR-011: Prompt versioning and model-update testing.
12. ADR-012: Open-source code versus content repositories.

---

## 25. Development task rules

When implementation begins, every implementation task should include:

- exact objective;
- allowed files;
- architectural boundary;
- acceptance criteria;
- test requirements;
- accessibility requirements;
- performance constraints;
- data-migration implications;
- non-goals;
- commands that must pass.

### Pull-request size

Prefer one vertical capability per pull request. Avoid “build the whole app” prompts.

### Required task sequence

1. Domain models and tests.
2. Service protocol and fake.
3. Persistence or platform adapter.
4. View model.
5. SwiftUI view.
6. Integration tests.
7. Accessibility verification.
8. Documentation/ADR update.

### Definition of done

A feature is not done when the UI appears. It is done when:

- behavior is tested;
- loading, empty, error, and offline states exist;
- accessibility labels exist;
- state restoration works where relevant;
- logging is added without leaking private data;
- generated content has provenance;
- migrations are considered;
- CI passes.

---

## 26. First implementation split after this plan

The next implementation document should be **Build Packet 0: Technical Feasibility Workspace**. It should contain five isolated prototypes:

1. Foundation Models structured lesson generator.
2. PDF import, chunking, retrieval, and citation opening.
3. Swift execution feasibility experiment and decision report.
4. TextKit-based Xcode-style editor prototype.
5. SwiftData plus CloudKit sync prototype.

No production feature UI should be built before these spikes answer the highest-risk questions.

---

## 27. Research basis and verified constraints

- Apple’s Foundation Models framework is available from iOS 26 and supports on-device generation, structured output, and tool-style workflows.
- The system model has a limited context window, requiring retrieval and staged generation rather than full-book prompts.
- The iPhone Air includes Apple Intelligence-capable hardware and is suitable for the system model, subject to runtime availability.
- Apple’s App Review rules contain a limited educational exception for executable code, but downloaded or executed code remains tightly constrained.
- Embedding the Swift compiler inside an iOS app is technically complex and is not provided as a normal public iOS framework.
- SwiftData can synchronize compatible data through CloudKit, but large imported documents and derived indexes should remain file-based and local by default.
- GameKit supplies native leaderboards, achievements, friends, and recurring competitions for the later social layer.
- PDFKit can load, search, and extract text from PDFs.
- Unwrap permits reuse of its `.swift` source under MIT, but its assets and educational content are not licensed for redistribution.

---

## 28. Final product decision

Daily Swift should be built as three cooperating engines:

1. **Learning Engine** — competency graph, assessment, mastery, spaced repetition, and projects.
2. **Knowledge Engine** — source imports, retrieval, citations, on-device AI generation, validation, and tutoring.
3. **Motivation Engine** — daily queue, map, XP, currency, hearts, streaks, achievements, pet, and social progression.

The Code Lab is a fourth capability boundary whose compilation features grow only as technical feasibility is proven.

This division lets the app become genuinely useful early, keeps AI grounded, preserves Unwrap-style motivation, and prevents the hardest compiler problem from consuming the entire product.
