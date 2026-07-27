# ADR-005: Foundation Models provider abstraction

**Status:** Proposed
**Date:** 2026-07-27
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
have not been run. This record therefore proposes a boundary but does not yet
accept Foundation Models as the default provider.

## Proposed decision

Use `StructuredGenerationClient` as the isolated Packet 000-A spike boundary.
It owns the Foundation Models availability check, combined typed generation
request, and cancellation needed to measure the feasibility question. Its
generated response contains both a lesson and a multiple-choice exercise. It is
not the proposed production protocol and must not spread into feature views.

If the device gate is go or constrained go, place accepted model behavior behind
a narrow production `LanguageModelProvider` boundary owned by the Knowledge
Engine. Reserve that name for the production boundary. It exposes:

- an explicit availability result;
- a typed generation request whose artifact contract is chosen by the
  orchestrating use case;
- cancellation with a terminal state;
- stable failure categories suitable for recovery and private metrics.

The spike client, and a future Apple adapter if accepted, perform platform
availability checks and typed generation. They do not decide whether content is
valid or learner-ready. Schema, citation, source identity, API/version, answer
determinism, and duplicate validation stay in provider-independent services.
Only candidates whose nested artifacts pass every applicable validator may
cross the presentation gate.

The current spike implements only the structural subset: source identity and
content hashes, citation resolution and coverage, exact requested version tags,
unique choice identifiers and normalized text, and one referenced correct
choice. It does not verify semantic API correctness, compilation, or
semantically equivalent distractors. Those candidates remain experimental; a
later generated-content trust record must define the additional deterministic
evidence required for production presentation.

### Availability mapping

The locally inspected SDK states map as follows:

| Framework or adapter result | Application value | Behavior |
|---|---|---|
| `available` | `.available` | Allow an explicit generation request. |
| `unavailable(deviceNotEligible)` | `.unavailable(.deviceNotSupported)` | Explain the limitation and use deterministic content. |
| `unavailable(appleIntelligenceNotEnabled)` | `.unavailable(.intelligenceDisabled)` | Explain the dependency and use deterministic content. |
| `unavailable(modelNotReady)` | `.unavailable(.modelNotReady)` | Preserve work, allow retry later, and use deterministic content now. |
| Separately detected locale or region restriction | `.unavailable(.languageOrRegionUnsupported)` | Explain the restriction and use deterministic content. |
| Unmapped future or unexpected availability result | `.unavailable(.other)` | Fail closed, retain a private diagnostic category, and use deterministic content. |

Unexpected generation errors map to a recoverable failure state. Cancellation
must discard partial presentation state, return the interface to a stable state,
and allow a subsequent request.

### Deterministic fallback

A deterministic provider supplies reviewed seed lessons and exercises through
the same consumer-facing artifact contract. It is not an error screen or a
temporary test double. It is the required offline product path whenever the
system model is unavailable, not ready, cancelled, rejected by validators, or
limited by performance or thermal policy.

### State ownership

Feature state changes are unidirectional. A main-actor view model owns visible
idle, checking, ready, generating, content, unavailable, cancelled, and failure
states. Provider work does not mutate SwiftUI views or persistence directly.
Cancellation and stale responses are resolved before a candidate can be
presented.

### Privacy and provenance

- Requests remain on device.
- Source cards are bounded, explicitly delimited untrusted data.
- Citation identities are assigned by the application.
- Logs may contain stable categories, counts, timing, memory, and thermal
  observations, but never source text, prompt bodies, generated artifact bodies,
  or learner data.
- Private diagnostic artifacts are not synced.

### Accessibility

Availability, progress, cancellation, rejection, and fallback have semantic
text, ordered focus, and concise VoiceOver announcements. State does not rely on
color or motion. Status and recovery actions support accessibility text sizes
and Reduce Motion. Long generation cannot block deterministic learning.

## Decision gate

The final decision remains unselected until the physical-iPhone evidence record
is complete.

- **Go:** at least 90% first-pass validator acceptance across 30 generated
  artifacts; 100% of invalid or uncited results blocked; warm p95 latency at or
  below 20 seconds; at least 4 bounded source cards; cancellation returns to
  stable UI within 1 second and a subsequent request succeeds; no memory
  termination or critical thermal state.
- **Constrained go:** 70–89% first-pass acceptance, warm p95 at or below 45
  seconds, only 1–2 practical source cards, or serious thermal pressure.
  Generation is limited or scheduled opportunistically, and deterministic
  lessons remain the default fallback.
- **No-go:** below 70% first-pass acceptance; any invalid artifact reaches
  presentation; target-device unavailability; state corruption after
  cancellation or repetition; repeated critical thermal state; or memory
  termination.

Until this record is Accepted, production feature work must not depend on the
Apple adapter. A no-go outcome retains deterministic content and removes or
isolates experimental model code.

## Alternatives considered

### Call Foundation Models directly from feature views

This reduces initial indirection but couples UI state to a changing platform
API, weakens deterministic tests, and makes fallback and stale-response handling
inconsistent. It is not proposed.

### Treat generated content as ready when typed decoding succeeds

Typed output narrows shape errors but does not prove citation validity, factual
support, API availability, or answer uniqueness. Provider-independent
validation and a presentation gate remain required.

### Require the model for the learning loop

This conflicts with the local-first product promise and excludes unsupported,
disabled, or not-ready states. Reviewed deterministic lessons remain a
first-class path.

### Use a cloud provider for the first implementation

This adds network, consent, credential, cost, and private-source transfer
concerns before the local path is measured. Cloud generation remains a later,
explicit opt-in decision.

### Ship deterministic content only

This is the retained fallback and becomes the selected production approach if
Packet 000-A is no-go. The spike is required before deciding whether to stop
there.

## Consequences

### Positive

- Spike behavior is testable through a deterministic
  `StructuredGenerationClient`, and accepted production behavior can remain
  testable through providers and explicit availability states.
- Validation, provenance, and presentation safety do not depend on one model.
- The daily learning loop remains useful without generation.
- Platform changes remain contained behind one Knowledge Engine boundary.

### Negative

- Typed artifacts and failures require explicit cross-boundary mappings.
- Provider-independent validators add work before generated content is shown.
- Model and prompt updates require the benchmark and decision evidence to be
  revisited.
- The abstraction must remain narrow to avoid speculative adapters.

## Verification

Before changing this record to Accepted:

1. Complete the simulator/host deterministic tests described in the evidence
   record.
2. Complete all physical-iPhone environment fields and the 30-artifact run
   table.
3. Record validator acceptance, blocked invalid results, p95 warm latency,
   source-card capacity, cancellation recovery, memory, and thermal results.
4. Run project hygiene, the signing-independent Debug build, and the focused
   tests from the active work packet.
5. Select go, constrained go, or no-go without weakening thresholds after seeing
   results.

Device-dependent verification is currently **not run**.

The deterministic spike implementation, Debug and Release simulator builds, and
the 20-test iPhone 17 / iOS 26.5 simulator suite pass. This evidence validates
the proposed seam and presentation gate only; it does not accept the provider.

## Residual risks

- OS and system-model updates can change behavior without a prompt change.
- A single target device and locale do not prove the same result everywhere.
- Validator coverage may miss teaching-quality or factual defects.
- Short feasibility runs may understate sustained battery, memory, or thermal
  cost.
- Context limits may vary by artifact schema and source-card composition.

## Supersession

None.
