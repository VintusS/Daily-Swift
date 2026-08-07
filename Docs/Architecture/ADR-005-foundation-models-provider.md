# ADR-005: Foundation Models provider abstraction

**Status:** Accepted
**Date:** 2026-07-27
**Last amended:** 2026-08-01
**Owners:** Project maintainers

## Context

Daily Swift is local-first and must remain useful when on-device generation is
unavailable. The product master plan prefers Foundation Models as the initial
provider, but requires a Phase 0 spike before that preference becomes an
accepted production dependency.

Model output is not authoritative curriculum or proof of correctness. Generated
lesson and exercise candidates require deterministic validation, resolvable
provenance, and a safe presentation gate. Imported source material is private,
untrusted data. The provider must not leak those inputs through logs or make
availability, cancellation, and failure state implicit in SwiftUI views.

The physical-iPhone measurements declared in
[Packet 000-A evidence](../Feasibility/000-a-structured-local-generation.md)
have not been run. On 2026-08-01, the owner explicitly deferred that
measurement and authorized an experimental production slice. This is a
sequencing exception, not evidence that the original go or constrained-go
thresholds passed.

After reviewing the first production UI, the owner further directed that
learner-facing articles and quizzes be generated-only. This supersedes the
earlier seed-content presentation fallback but does not promote the Apple
adapter or turn missing physical-device evidence into an accepted result.

## Decision

Use `StructuredGenerationClient` as the isolated Packet 000-A spike boundary.
It owns the Foundation Models availability check, combined typed generation
request, and cancellation needed to measure the feasibility question. Its
generated response contains both a lesson and a multiple-choice exercise. It is
not the production protocol and must not spread into feature views.

Place model behavior behind a narrow production `LanguageModelProvider`
boundary owned by the Knowledge Engine. Reserve that name for the production
boundary. It exposes:

- an explicit availability result;
- a typed generation request whose artifact contract is chosen by the
  orchestrating use case;
- cancellation with a terminal state;
- stable failure categories suitable for recovery and private metrics.

The spike client and the experimental production Apple adapter perform platform
availability checks and schema-constrained generation mapped into typed domain
artifacts. Neither decides whether content is valid or learner-ready.
Schema, citation, source identity, API/version, answer determinism, and
duplicate validation stay in provider-independent services. Only candidates
whose nested artifacts pass every applicable validator may cross the
presentation gate.

The Packet 000-A spike implements only the structural subset: source identity and
content hashes, at least one resolvable citation per nested artifact, exact
requested version tags, unique choice identifiers and normalized text, and one
referenced correct choice. It does not require every supplied card to be cited:
an unused input is not missing provenance, and forcing a citation would
incentivize unsupported attribution. It does not verify semantic API
correctness, compilation, or semantically equivalent distractors. Those
candidates remain experimental. ADR-007 now defines the additional trust,
presentation, exact-citation, and mastery-exclusion gates for Packet 008; its
acceptance is not evidence that a particular implementation or hosted run has
passed those gates.

The Packet 000-A spike adapter treats version metadata and identities as
application-owned. It stamps requested platform versions, builds a runtime
schema whose citation range matches the actual source-card count, maps guided
citation numbers to exact source-card identities, and derives stable choice
identities from a guided answer index. Unknown citation numbers, missing
citations, duplicate citations, duplicate answer text, or an invalid answer
reference still fail closed before presentation.

Version ownership remains explicit and independent:

- domain artifact schema version 1 describes the post-mapping application
  contract;
- prompt version `structured-generation-v2` describes the instruction and
  source-card rendering contract;
- provider candidate schema version 2 describes the runtime
  `DynamicGenerationSchema` decoded before domain mapping.

Changing one version does not silently change either of the others.

Packet 008's production prompt, candidate-schema, artifact-schema, runtime, and
source-set identities are separately governed by ADR-011. They must not silently
reuse or be inferred from these Packet 000-A spike version tags.

The public framework does not expose an exact system-model build identifier.
The spike therefore records the default provider plus runtime OS version as a
surrogate label; it must not be presented as the model's exact version.

### Experimental adoption policy

The app-owned boundary and generated-only operational fallback are accepted.
The Apple Foundation Models adapter is accepted only as an **experimental,
unpromoted** provider while physical quality and performance evidence remains
unmeasured.

- Generation is foreground-only, explicitly initiated by the learner, serial,
  bounded to at most four source cards, and cancellable.
- No automatic, background, bulk, or thermal-sensitive generation is allowed.
- The interface must never promise device capacity, latency, reliability,
  energy, memory, or thermal behavior.
- Availability permits an attempt but does not imply suitability.
- Rejected, failed, cancelled, or unavailable generation preserves accepted
  generated history and imported-source reading. If neither exists, the app
  presents an explicit unavailable or empty state rather than authored content.
- Content generated from private imports is always labeled
  `Experimental/User Material` in the current slice and must pass ADR-007's
  stronger evidence gates before presentation.
- Model output cannot update mastery or become authoritative curriculum.

This policy permits the owner-directed generated-learning vertical slice while
preserving the original benchmark as the promotion gate for making the Apple
adapter a normal/default provider or enabling opportunistic batch generation.

### Availability mapping

The locally inspected SDK states map as follows:

| Framework or adapter result | Application value | Behavior |
|---|---|---|
| `available` | `.available` | Allow an explicit generation request. |
| `unavailable(deviceNotEligible)` | `.unavailable(.deviceNotSupported)` | Explain the limitation; keep saved generated history and source reading available. |
| `unavailable(appleIntelligenceNotEnabled)` | `.unavailable(.intelligenceDisabled)` | Explain the dependency; keep saved generated history and source reading available. |
| `unavailable(modelNotReady)` | `.unavailable(.modelNotReady)` | Preserve work, allow retry later, and do not substitute authored content. |
| Separately detected locale or region restriction | `.unavailable(.languageOrRegionUnsupported)` | Explain the restriction and do not substitute authored content. |
| Unmapped future or unexpected availability result | `.unavailable(.other)` | Fail closed, retain a private diagnostic category, and do not substitute authored content. |

Unexpected generation errors map to a recoverable failure state. Cancellation
must discard partial presentation state, return the interface to a stable state,
and allow a subsequent request.

### Generated-only operational fallback

Production does not substitute an authored article or quiz when generation is
unavailable. Deterministic providers and authored learning fixtures are limited
to tests, previews, explicitly gated Debug scenarios, and separately accepted
assessment anchors. The learner-facing fallback consists of previously
accepted generated history, imported-source reading and search, preservation of
learner data, an explicit availability explanation, and retry. A fresh
installation may therefore have no article or quiz until a grounded request
succeeds. This owner-accepted policy narrows the earlier offline-learning
promise without promoting the experimental Apple adapter.

### State ownership

Feature state changes are unidirectional. A main-actor view model owns visible
idle, empty, checking, ready, generating, history, content, unavailable,
cancelled, and failure states. Provider work does not mutate SwiftUI views or
persistence directly. Cancellation and stale responses are resolved before a
candidate can be presented.

### Privacy and provenance

- Requests remain on device.
- Source-card text, title, and location are bounded, JSON-encoded inside one
  explicitly delimited untrusted-data boundary, and decoded losslessly; only
  the application-assigned citation number remains outside that boundary.
- Citation identities are assigned by the application.
- Privacy-safe diagnostic categories may identify a failed validation rule, but
  never include source identities, source text, prompt bodies, or generated
  artifact text.
- Logs may contain stable categories, counts, timing, memory, and thermal
  observations, but never source text, prompt bodies, generated artifact bodies,
  or learner data.
- Private diagnostic artifacts are not synced.

### Quality-feedback and training boundary

`LanguageModelProvider` exposes generation, availability, and cancellation; it
does not expose rating, training, fine-tuning, or model-mutation operations. The
generated-only Packet 008 completion follow-up does not add a rating interface
or rating storage. Any future Good or Bad feedback requires a separate work
packet and accepted persistence/privacy decision; it must remain app-owned,
must not invoke the provider or alter trust or mastery, and must not be
described as retraining Apple Intelligence. A future trainable provider, rating
export, or dataset workflow requires a separate accepted architecture and
explicit privacy, consent, source-rights, retention, deletion, and
device-evidence policy.

### Accessibility

Availability, progress, cancellation, rejection, empty, and fallback states
must have semantic text, ordered focus, and concise VoiceOver announcements.
State must not rely on color or motion. Status and recovery actions must support
accessibility text sizes and Reduce Motion. Long generation must not block saved
generated history or imported-source reading. Code-level semantics exist;
manual assistive-technology verification remains pending in the evidence
record.

## Provider promotion gate

The benchmark outcome remains unselected because the physical-iPhone evidence
record is incomplete. The thresholds remain frozen for any future promotion:

- **Go:** at least 90% first-pass validator acceptance across 30 generated
  artifacts; 100% of invalid or uncited results blocked; warm p95 latency at or
  below 20 seconds; at least 4 bounded source cards; cancellation returns to
  stable UI within 1 second and a subsequent request succeeds; no memory
  termination and no serious or critical thermal state.
- **Constrained go:** 70–89% first-pass acceptance; warm p95 above 20 seconds
  and at or below 45 seconds; only 1–3 practical source cards; stable
  cancellation above 1 second and at or below 3 seconds followed by a
  successful request; or serious but not critical thermal pressure. Generation
  remains further limited; automatic or opportunistic scheduling still requires
  a separately accepted policy.
- **No-go:** below 70% first-pass acceptance; any invalid artifact reaches
  presentation; warm p95 above 45 seconds; no validated result from one bounded
  source card; target-device unavailability; cancellation above 3 seconds, a
  failed subsequent request, or state corruption after cancellation or
  repetition; any critical thermal state; or memory termination.

Until this promotion gate passes, the app may require the experimental Apple
adapter only for an explicit request for new generated learning. It must not
claim that the adapter is promoted, universally available, or sufficient for a
complete offline session. A future no-go outcome keeps saved generated history
and source reading available, removes or further isolates experimental model
code, and requires a new product decision for creating additional content.

## Alternatives considered

### Call Foundation Models directly from feature views

This reduces initial indirection but couples UI state to a changing platform
API, weakens deterministic tests, and makes fallback and stale-response handling
inconsistent. It is rejected.

### Treat generated content as ready when typed decoding succeeds

Typed output narrows shape errors but does not prove citation validity, factual
support, API availability, or answer uniqueness. Provider-independent
validation and a presentation gate remain required.

### Require the model for the learning loop

This conflicts with the local-first product promise and excludes unsupported,
disabled, or not-ready states. The owner-directed exception nevertheless allows
new articles and quizzes to require an available experimental provider, while
saved generated history and imported-source reading remain first-class paths.

### Use a cloud provider for the first implementation

This adds network, consent, credential, cost, and private-source transfer
concerns before the local path is measured. Cloud generation remains a later,
explicit opt-in decision.

### Ship deterministic content only

This was the original learner-facing fallback. The owner rejected it for
production articles and quizzes after reviewing the first generated-learning
UI. Deterministic providers and authored artifacts remain necessary for tests,
previews, Debug scenarios, and separately accepted assessment anchors. The
frozen spike remains the promotion evidence needed to decide whether the
experimental Apple adapter can advance or should be removed.

## Consequences

### Positive

- Spike behavior is testable through a deterministic
  `StructuredGenerationClient`, and accepted production behavior can remain
  testable through providers and explicit availability states.
- Validation, provenance, and presentation safety do not depend on one model.
- Saved generated learning and imported sources remain useful without a new
  generation request.
- Platform changes remain contained behind one Knowledge Engine boundary.

### Negative

- Typed artifacts and failures require explicit cross-boundary mappings.
- Provider-independent validators add work before generated content is shown.
- A fresh installation has no learner-facing article or quiz when the provider
  is unavailable or no grounded request has succeeded.
- Model, prompt, or provider-candidate-schema updates require the benchmark and
  decision evidence to be revisited.
- The abstraction must remain narrow to avoid speculative adapters.

## Verification

Before promoting the experimental Apple adapter to the normal/default provider:

1. Complete the deterministic automated coverage described in the evidence
   record through the hosted `Tests` check. Local validation remains build-only.
2. Complete all physical-iPhone environment fields and the 30-artifact run
   table.
3. Record validator acceptance, blocked invalid results, p95 warm latency,
   source-card capacity, cancellation recovery, memory, and thermal results.
4. Run project hygiene, diff/static review, signing-independent Debug and
   Release build-only validation, any needed `build-for-testing`, and the exact
   hosted Project Hygiene, Build, and Tests checks from the active packet.
5. Select go, constrained go, or no-go without weakening thresholds after seeing
   results.

Separately verify the generated-only completion follow-up with unavailable,
empty-history, restored-history, cancelled, rejected, and failed scenarios. No
scenario may inject a learner-facing seed article or quiz. The completion UI
must not claim that it collects feedback or trains a model.

Device-dependent generation verification is currently **not run**.

The deterministic spike implementation, Debug and Release simulator builds, and
the historical 28-test iPhone 17 / iOS 26.5 simulator suite passed. The suite
contained 27 unit tests and one UI smoke test. This evidence validates the
app-owned seam and deterministic presentation checks only; it does not promote
the provider. Current automated tests are executed only by GitHub CI.

On 2026-07-30, the Debug measurement harness was extended to represent the
predeclared warm-up and 30-run schedule, request-size components, privacy-safe
device environment, deterministic fallback, and intentionally invalid
presentation-gate fixture. Signing-independent Debug and Release builds and
Debug `build-for-testing` pass. A development-signed build installed on an
iPhone Air (`iPhone18,4`) running iOS 27.0 beta (`24A5390f`) and later launched
the Packet 000-A screen. The device environment records `en_US` with Moldova
region, 55% battery, and nominal thermal state before warm-up. The explicit
environment report maps the default system model and current locale to
`.available`. The measured generation benchmark remains pending. These are
readiness facts, not Foundation Models acceptance evidence.

On 2026-08-01, the owner deferred Packet 000-A without selecting go,
constrained go, or no-go. Acceptance of this record is limited to the app-owned
boundary, generated-only operational fallback, and experimental-adapter policy
above. It does not convert missing device measurements into acceptance
evidence.

## Residual risks

- OS and system-model updates can change behavior without a prompt change.
- A single target device and locale do not prove the same result everywhere.
- Validator coverage may miss teaching-quality or factual defects.
- Short feasibility runs may understate sustained battery, memory, or thermal
  cost.
- Context limits may vary by artifact schema and source-card composition.

## Supersession

None.
