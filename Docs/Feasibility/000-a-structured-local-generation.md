# Packet 000-A evidence: Structured local generation

**Status:** In Progress
**Evidence record version:** 1
**Opened:** 2026-07-27
**Decision:** Pending physical-iPhone evidence
**Governing record:** [ADR-005](../Architecture/ADR-005-foundation-models-provider.md)

## Question

Can Foundation Models reliably create bounded, typed lesson and exercise
artifacts on the supported iPhone while preserving deterministic validation,
safe state transitions, local privacy, and a useful model-unavailable fallback?

This record declares the decision thresholds and collection method before
device measurement. Empty result fields mean **not measured**. Host or simulator
results must not be presented as physical-device evidence.

## Scope

- Map every Foundation Models availability result to an explicit application
  state.
- Generate combined candidates containing a typed lesson and typed
  multiple-choice exercise from bounded source cards.
- Validate schemas, citation identity and coverage, exact requested version
  tags, and structural answer uniqueness outside the model provider.
- Exercise cancellation, repetition, failure, and deterministic fallback paths.
- Measure first-pass acceptance, latency, practical context, memory, and thermal
  behavior on a supported iPhone.

## Explicit non-goals

- A final prompt library or production prompt tuning.
- All exercise types.
- A production lesson, settings, onboarding, or tutor interface.
- Retrieval, source importing, or citation-reader implementation.
- Cloud generation or a downloadable specialist model.
- A claim that generated content is correct merely because it is typed.
- Production caching, background scheduling, or model-download management.

## Predeclared decision thresholds

The benchmark contains 30 combined candidate generations. Each response contains
both a typed lesson and a typed multiple-choice exercise. A candidate passes
only when both nested artifacts pass every applicable validator. A scheduled
request that fails, times out, or returns either nested artifact invalid does not
pass first-pass validation and remains in the denominator. Repair and retry
results are recorded separately and cannot improve the first-pass rate.

| Signal | Go | Constrained go | No-go |
|---|---|---|---|
| First-pass validator acceptance | At least 90% across 30 generated artifacts | 70–89% across 30 generated artifacts | Below 70% across 30 generated artifacts |
| Presentation safety | 100% of invalid or uncited results are blocked | Same blocking requirement; deterministic lessons remain the default fallback | Any invalid artifact reaches presentation |
| Warm latency | p95 at or below 20 seconds | p95 above 20 seconds and at or below 45 seconds | A result above the constrained range cannot support acceptance without a new, documented threshold |
| Practical source-card context | At least 4 bounded source cards | Only 1–2 practical bounded source cards | Target workflow cannot produce a validated typed artifact from the minimum practical context |
| Cancellation and repetition | Cancellation returns the UI to a stable state within 1 second and a subsequent request succeeds | Generation is limited or deferred only if the same state-integrity requirement still passes | State corruption after cancellation or repeated requests |
| Availability | Available on the target device for the declared locale, region, and Apple Intelligence state | Availability limitations are surfaced and deterministic lessons remain usable | Model unavailable on the target device under the intended supported configuration |
| Memory and thermal behavior | No memory termination and no critical thermal state | Serious thermal pressure; limit generation, pre-generate opportunistically, and keep deterministic lessons as the default fallback | Memory termination or repeated critical thermal state |

Any no-go signal makes the result no-go. A go result requires every go condition.
A result that meets no no-go condition but meets a constrained condition is a
constrained go, with the limitation recorded in ADR-005. An unclassified gap,
such as exactly three practical source cards, cannot be called go; it requires a
documented review or a pre-measurement amendment to this record.

## Definitions

- **First-pass acceptance:** the first generated candidate passes every
  applicable deterministic validator before repair, regeneration, or manual
  editing.
- **Invalid for this feasibility rate:** a candidate fails its typed schema,
  source-card identity or hash, citation resolution or coverage, exact requested
  version tags, unique choice IDs/text, or single correct-choice reference.
- **Warm latency:** elapsed time from request submission to a typed result or
  terminal failure after one unscored warm-up request. The same clock boundary
  applies to every measured run.
- **Bounded source card:** a fixture with a stable identifier, source location,
  rights state, version tags, content hash, and a size recorded in the fixture
  manifest. The manifest and total request size are frozen before device runs.
- **Stable state:** no stale artifact is shown, progress is no longer announced,
  controls reflect the terminal state, and a new request can begin without
  relaunching the app.

## Current validation boundary

The spike gate proves structural integrity and provenance plumbing. It does not
prove that an API claim is factually correct, that example code compiles, or
that differently worded choices are semantically distinct. Those checks require
source-claim validation, deterministic exercise semantics, and compiler/static
evidence governed by later records.

The 30-run first-pass rate therefore measures typed-generation feasibility
against the structural gate only. It cannot assign a verified-generated trust
tier or authorize production presentation. Manual benchmark observations may
record unsupported claims or semantic ambiguity, but they cannot be counted as
an implemented deterministic validator.

## Runtime availability mapping

The locally inspected SDK exposes `available` and these unavailable reasons:
`deviceNotEligible`, `appleIntelligenceNotEnabled`, and `modelNotReady`.
The prototype must map them without relying on display text:

| Framework or adapter result | Application value | Required behavior |
|---|---|---|
| `available` | `.available` | Permit an explicit generation request. |
| `deviceNotEligible` | `.unavailable(.deviceNotSupported)` | Explain that local generation is unavailable and offer deterministic content. |
| `appleIntelligenceNotEnabled` | `.unavailable(.intelligenceDisabled)` | Explain the dependency without blocking deterministic learning. |
| `modelNotReady` | `.unavailable(.modelNotReady)` | Preserve work, allow a later retry, and offer deterministic content now. |
| A separately detected locale or region restriction | `.unavailable(.languageOrRegionUnsupported)` | Explain the restriction and offer deterministic content. |
| An unmapped future or unexpected availability result | `.unavailable(.other)` | Fail closed, retain a private diagnostic category, and offer deterministic content. |

Generation errors remain a separate failure state with a retry action and the
same fallback. Debug logging may include stable error categories and timing, but
must not include prompts, source-card text, generated lesson text, or learner
data.

## Evidence boundary

### Simulator or host evidence

Simulator and host runs may establish:

- typed schemas compile;
- validators accept and reject deterministic fixtures as expected;
- the pure SDK-to-application availability mapper covers every known reason and
  locale rejection;
- cancellation and repetition state transitions are deterministic;
- fallback artifacts preserve the same user-flow contract;
- accessibility identifiers, labels, and non-color state cues exist.

They cannot establish model availability, generation quality, practical context
capacity, latency, memory pressure, energy use, or thermal behavior on iPhone.

### Recorded simulator result

The 2026-07-27 iPhone 17 / iOS 26.5 simulator run established:

- both typed nested schemas and the Foundation Models adapter compile;
- four bounded project-authored source cards pass request validation;
- source-card SHA-256 digests are recomputed before provider generation;
- adversarial prompt delimiters are escaped and the complete rendered prompt
  has a hard character bound;
- unknown, duplicate, missing, and incomplete citations are blocked;
- aggregate citation coverage is required for every supplied source card;
- empty or duplicate choice identities, duplicate answer text, and a missing
  correct answer are blocked;
- Swift and minimum-iOS version tags must match the generation request;
- unavailable, rejected, failed, cancelled, and successful states are explicit;
- cancellation remains stable and a stale response cannot replace newer state;
- the deterministic fixture completes the same validated presentation flow;
- the debug and release signing-independent simulator builds pass;
- the complete suite passes 20 tests with 0 failures, including one XCUITest
  that presents both nested artifacts.

This evidence completes only the deterministic simulator portion of the packet.
It does not count toward the physical-device benchmark or select a decision.

### Physical-iPhone evidence

Only a supported physical iPhone may establish:

- runtime availability under the recorded device configuration;
- the 30-artifact first-pass rate and rejection/repair counts;
- warm p50 and p95 latency;
- practical bounded source-card count and total request size;
- cancellation responsiveness followed by a successful request;
- peak memory observations and absence of memory termination;
- starting, worst, and ending thermal states.

## Toolchain and environment

SDK facts below describe the local build environment, not a completed device
run.

| Field | Value |
|---|---|
| Xcode | 26.5 (build 17F42) |
| Swift | 6.3.2 |
| iPhoneOS SDK | 26.5 |
| FoundationModels module | 1.5.2 |
| Project deployment target | iOS 26.0 |
| Physical iPhone model | Not measured |
| Device OS version and build | Not measured |
| Locale and region | Not measured |
| Apple Intelligence state | Not measured |
| Power state | Not measured |
| Starting thermal state | Not measured |

## Measurement procedure

1. Freeze the public or synthetic fixture manifest, typed schemas, prompt
   version, validator version, and source-card size limits.
2. Run deterministic validator, availability, cancellation, repeated-request,
   and fallback tests on the simulator.
3. On the recorded physical iPhone, perform one unscored warm-up request.
4. Run the fixed 30-artifact benchmark without editing failed candidates.
5. Record every request, including terminal failures, in the run table below.
6. Run cancellation during active generation, confirm stable UI within one
   second, and immediately complete a subsequent request.
7. Run intentionally invalid and uncited fixtures through presentation gating
   and record whether every one is blocked.
8. Summarize latency, context, memory, and thermal evidence without including
   private source or generated content.
9. Select go, constrained go, or no-go only after the complete physical-device
   evidence is reviewed.

## Run table template

| Run | Source cards | Total request size | Lesson valid | Exercise valid | Combined first-pass accepted | Rejection category | Warm latency | Peak memory observation | Start/worst/end thermal state | Notes |
|---:|---:|---:|---|---|---|---|---:|---|---|---|
| — | — | — | Not measured | Not measured | Not measured | — | Not measured | Not measured | Not measured | Physical-device run pending |

Do not store prompt bodies, source-card contents, or generated artifact bodies
in this evidence table. Failed artifacts may be retained only in private local
diagnostics.

## Summary template

| Measurement | Result | Threshold interpretation |
|---|---|---|
| First-pass accepted / 30 | Not measured | Pending |
| Invalid or uncited artifacts blocked | Not measured | Pending |
| Warm p50 / p95 latency | Not measured | Pending |
| Practical bounded source cards | Not measured | Pending |
| Cancellation to stable state | Not measured | Pending |
| Subsequent request after cancellation | Not measured | Pending |
| Memory termination | Not measured | Pending |
| Worst thermal state | Not measured | Pending |
| Target-device availability | Not measured | Pending |
| Proposed outcome | Not selected | Physical-iPhone evidence required |

## Deterministic fallback

The fallback supplies reviewed seed lessons and exercises through the same
consumer-facing artifact contract. It performs no model call, requires no
network or iCloud account, and preserves the daily learning flow when the model
is unavailable, not ready, cancelled, rejected, or too expensive to run safely.
Fallback content must retain stable source and version metadata and must pass
the same applicable deterministic validators.

## Accessibility checks

- Availability, generating, cancelled, rejected, and fallback states have
  concise VoiceOver announcements.
- State is communicated with text and semantics, never color alone.
- Status and recovery actions remain usable at accessibility text sizes.
- Progress animation respects Reduce Motion and is not required to understand
  the state.
- Cancellation and deterministic fallback remain reachable without a timed
  interaction.
- A long generation request never traps focus or blocks unrelated deterministic
  learning.

## Privacy and provenance checks

- Use only public, licensed, or synthetic repository fixtures.
- Treat source-card text as untrusted data, separate from instructions.
- Assign citation identifiers in the prototype; never accept an invented source
  identity.
- Keep requests and generated artifacts on device.
- Log categories, counts, timing, memory, and thermal observations only.
- Do not sync raw artifacts or private diagnostics.

## Residual risks

- System-model behavior may change with an OS or model update even when the
  application code and prompt version are unchanged.
- One device, locale, and benchmark cannot represent every supported runtime
  configuration.
- Passing typed schemas does not prove factual correctness, teaching quality, or
  semantic answer uniqueness beyond the implemented structural validators.
- A short run may not reveal battery cost, sustained thermal pressure, or
  long-session memory growth.
- Context capacity may vary with schema complexity and source-card composition.
- Availability can change after setup, OS updates, or model asset changes, so
  the deterministic fallback remains mandatory after any go decision.

## Current conclusion

The isolated debug implementation and deterministic simulator verification are
complete. No product or architecture decision has been selected. The provider
proposal remains **Proposed**, this packet remains **In Progress**, and all
physical-iPhone measurements remain pending.
