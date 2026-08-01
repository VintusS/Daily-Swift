# Packet 000-A evidence: Structured local generation

**Status:** In Progress
**Evidence record version:** 2
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

## Pre-measurement amendment

Version 2 was opened after manual, unscored use repeatedly reached the
validation gate, but before any run was entered in the fixed 30-artifact table.
The v1 candidate schema asked the model to reproduce application-owned version
strings, citation identities, choice identities, and a correct-choice identity.
Descriptions in a typed schema could not enforce the exact cross-field
relationships later required by the validator.

The v2 prompt and adapter make those relationships deterministic:

- requested Swift and minimum-iOS versions are stamped by the application;
- a runtime schema constrains guided citation numbers to the actual one-to-four
  card request, then maps them to exact source-card identities; missing,
  duplicate, or out-of-range citations are still rejected;
- exactly three generated choice strings receive application-owned stable
  identities, and a guided answer index maps to one of them;
- each nested artifact must cite at least one source card it actually uses, but
  unused input cards do not require citations;
- source text, title, and location are losslessly JSON-encoded inside one
  delimiter-safe untrusted-data boundary; only the application-assigned
  citation number remains outside;
- dynamic schema descriptions and the prompt tell the model not to repeat a
  citation number within either nested artifact;
- the debug harness displays stable validation categories without source
  identities, prompt text, source text, or generated artifact text;
- previously unclassified threshold gaps now resolve explicitly: one to three
  practical cards and stable cancellation above one second through three
  seconds are constrained go, while p95 above 45 seconds, cancellation above
  three seconds, or any critical thermal state are no-go.

Requiring every supplied card to appear in the output was removed because that
measures input utilization, not provenance, and can encourage unsupported
citations. Domain artifact schema version 1 remains the post-mapping application
contract. Prompt version `structured-generation-v2` and provider candidate
schema version 2 are versioned independently. No v1 result is scored, and the
complete 30-run denominator starts from zero with v2.

## Scope

- Map every Foundation Models availability result to an explicit application
  state.
- Generate combined candidates containing a typed lesson and typed
  multiple-choice exercise from bounded source cards.
- Validate schemas, citation presence and resolution, exact requested version
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
| Warm latency | p95 at or below 20 seconds | p95 above 20 seconds and at or below 45 seconds | p95 above 45 seconds |
| Practical source-card context | At least 4 bounded source cards | Only 1–3 practical bounded source cards | Target workflow cannot produce a validated typed artifact from one bounded source card |
| Cancellation and repetition | Cancellation returns the UI to a stable state within 1 second and a subsequent request succeeds | Stable cancellation takes more than 1 second and at most 3 seconds, and a subsequent request succeeds; limit or defer generation | Stable cancellation takes more than 3 seconds, a subsequent request fails, or state is corrupted after cancellation or repetition |
| Availability | Available on the target device for the declared locale, region, and Apple Intelligence state | Availability limitations are surfaced and deterministic lessons remain usable | Model unavailable on the target device under the intended supported configuration |
| Memory and thermal behavior | No memory termination and no serious or critical thermal state | Serious but not critical thermal pressure; limit generation, pre-generate opportunistically, and keep deterministic lessons as the default fallback | Memory termination or any critical thermal state |

Any no-go signal makes the result no-go. A go result requires every go condition.
A result that meets no no-go condition but meets a constrained condition is a
constrained go, with the limitation recorded in ADR-005.

## Definitions

- **First-pass acceptance:** the first generated candidate passes every
  applicable deterministic validator before repair, regeneration, or manual
  editing.
- **Invalid for this feasibility rate:** a candidate fails its typed schema,
  source-card identity or hash, per-artifact citation presence or resolution,
  exact requested version tags, unique choice IDs/text, or single
  correct-choice reference.
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

- the runtime schema builder compiles and accepts supported request
  cardinalities;
- generated structured content maps into typed domain drafts;
- validators accept and reject deterministic fixtures as expected;
- the pure SDK-to-application availability mapper covers every known reason and
  locale rejection;
- cancellation and repetition state transitions are deterministic;
- fallback artifacts preserve the same user-flow contract;
- accessibility identifiers, labels, and non-color state cues exist.

They cannot establish model availability, generation quality, practical context
capacity, latency, memory pressure, energy use, or thermal behavior on iPhone.

### Recorded simulator result

The 2026-07-27 and 2026-07-28 iPhone 17 / iOS 26.5 simulator runs established:

- the request-cardinality runtime schema, structured-content decoder, typed
  domain mapping, and Foundation Models adapter compile;
- four bounded project-authored source cards pass request validation;
- source-card SHA-256 digests are recomputed before provider generation;
- source text and metadata round-trip through delimiter-safe JSON encoding,
  adversarial delimiter text cannot close the untrusted-data boundary, and the
  complete rendered prompt has a hard character bound;
- unknown, duplicate, and missing citations are blocked;
- citation numbers are mapped to application-owned source identities, while
  unused source-card inputs do not require artificial citations;
- empty or duplicate choice identities, duplicate answer text, and a missing
  correct answer are blocked;
- Swift and minimum-iOS version tags must match the generation request;
- unavailable, rejected, failed, cancelled, and successful states are explicit;
- cancellation remains stable and a stale response cannot replace newer state;
- the deterministic fixture completes the same validated presentation flow;
- the debug and release signing-independent simulator builds pass;
- the complete suite passes 28 tests with 0 failures: 27 unit tests and one
  XCUITest that presents both nested artifacts;
- focused mapper tests prove that request metadata, citation identities, choice
  identities, and the correct answer reference are application-owned;
- invalid citation numbers and answer indices fail closed, and validation
  diagnostics contain categories rather than rejected values.

This evidence completes only the deterministic simulator portion of the packet.
It does not count toward the physical-device benchmark or select a decision.

### Physical-device harness readiness

The 2026-07-30 measurement preparation adds a Debug-only selector for the
unscored warm-up and every entry in the frozen 30-run schedule. For the selected
entry, it shows only source aliases and the predeclared UTF-8 request-size
components: session instructions, rendered prompt, sorted-key runtime-schema
JSON, and their total. It also shows the hardware identifier, operating-system
version, locale/region, Foundation Models availability category, power/battery,
and current thermal category.

The selector does not execute a run automatically, score a candidate, calculate
authoritative latency, or sample process memory. The operator must still use
60-fps screen-recording timecodes for latency and cancellation and Instruments
VM Tracker for memory. Selecting the invalid gate fixture routes its invalid and
uncited artifact through the same view model, deterministic validator, and
presentation gate; rejected values remain absent from diagnostics.

A development-signed Debug build compiled with Xcode 26.5, installed
successfully on the declared iPhone Air through CoreDevice, and launched the
Packet 000-A screen on 2026-07-30. A Debug-only explicit launch argument can
print the same approved environment fields plus the mapped Foundation Models
availability category to the attached development console. It never prints
prompts, sources, generated artifacts, or learner data.

LLDB inspection of the running app recorded the OS build, locale/region,
power/battery, and starting thermal category below. Xcode 26.5 could not import
the iOS 27 beta Foundation Models module in the debugger. The explicit
non-activating console report then mapped `SystemLanguageModel.default` and the
current locale to application value `.available`. Launch and availability
readiness do not prove generation quality, accessibility, latency, memory, or
sustained thermal behavior.

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
| Domain artifact schema | 1 |
| Provider candidate schema | 2 |
| Prompt version | `structured-generation-v2` |
| Physical iPhone model | iPhone Air (`iPhone18,4`), identified by CoreDevice; benchmark not run |
| Device OS version and build | iOS 27.0 beta (`24A5390f`); benchmark not run |
| Locale and region | `en_US@rg=mdzzzz`; region `MD` (Moldova) |
| Apple Intelligence state | Ready for the current configuration: `SystemLanguageModel.default` and locale map to `.available` |
| Power state | On battery, 55% |
| Starting thermal state | Nominal before warm-up |

## Measurement procedure

1. Freeze the public or synthetic fixture manifest, provider candidate schema
   version, typed domain contract version, prompt version, validator version,
   and source-card size limits.
2. Run deterministic validator, availability, cancellation, repeated-request,
   and fallback tests on the simulator.
3. On the recorded physical iPhone, perform one unscored four-card warm-up
   request.
4. Run the fixed 30-artifact schedule below without editing failed candidates
   or changing its order.
5. Record every request, including terminal failures, in the run table below.
   Request size is the sum of UTF-8 bytes for session instructions and the
   rendered prompt plus the sorted-key JSON byte count of the runtime
   `GenerationSchema`. Record the three components and the total; opaque
   framework overhead is excluded because the public API does not expose it.
   Measure warm latency from Generate activation to terminal status with the
   same 60-fps screen-recording timecodes used to align Instruments.
6. During a separate four-card request, activate Cancel, record the exact time
   to terminal stable UI, and immediately complete a subsequent request. Use
   60-fps screen-recording timecodes so the measured value can be classified as
   go, constrained go, or no-go without rounding to a threshold.
7. Run intentionally invalid and uncited fixtures through presentation gating
   and record whether every one is blocked.
8. Attach Instruments VM Tracker for the complete scheduled session. After a
   30-second post-warm-up idle baseline, sample at one-second intervals and
   record baseline, per-run peak physical footprint, session peak, and whether
   the process terminated. Synchronize run boundaries with screen-recording
   timecodes.
9. Record `ProcessInfo.processInfo.thermalState` before the warm-up, after each
   scheduled run, at the worst observed point, and after a five-minute idle
   recovery.
10. Summarize latency, context, memory, and thermal evidence without including
    private source or generated content.
11. Select go, constrained go, or no-go only after the complete physical-device
    evidence is reviewed.

### Fixed source-card schedule

The frozen four-card manifest uses these aliases only for the schedule:

| Alias | Source-card identity |
|---|---|
| A | `main-actor-state` |
| B | `stale-result-protection` |
| C | `deterministic-validation` |
| D | `cooperative-cancellation` |

The fixture manifest is frozen before device measurement:

| Alias | Source-card identity | Text UTF-8 bytes | SHA-256 |
|---|---|---:|---|
| A | `main-actor-state` | 189 | `535e5d50fc1c363111a2c2035e9c7c1e754319fe014b4db0b8922d146147db82` |
| B | `stale-result-protection` | 201 | `68d1b609465457ca7473961e781e111348c6ceebeeee6fd5b9c1a4eb5d3c0927` |
| C | `deterministic-validation` | 180 | `40e6f797aa9f8a9ed05697c6e8a1e022d53cb32c511917451205b5b13f6f23bd` |
| D | `cooperative-cancellation` | 175 | `35a76a76025907dccdf1cfb9974bf4e91f93292b39263e21194dbe7508c9b95a` |

| Runs | Frozen subset |
|---|---|
| 1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 30 | A + B + C + D |
| 2, 8, 14, 20 | A; B; C; D, respectively |
| 4, 10, 16, 22, 26, 28 | A+B; A+C; A+D; B+C; B+D; C+D, respectively |
| 6, 12, 18, 24 | A+B+C; A+B+D; A+C+D; B+C+D, respectively |

This yields 16 four-card runs and one pass over every one-, two-, and
three-card subset. Acceptance remains one combined 30-run rate; per-cardinality
counts are also reported so the practical-context decision is not selected
post hoc.

## Run table template

| Run | Source cards | Request size: instructions + prompt + schema = total | Lesson valid | Exercise valid | Combined first-pass accepted | Rejection category | Warm latency | Peak memory observation | Start/worst/end thermal state | Notes |
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
| Target-device availability | Available | Meets the availability go condition only |
| Proposed outcome | Not selected | Physical-iPhone evidence required |

## Deterministic fallback

The current spike fallback is a project-authored deterministic fixture that
uses the same artifact, validation, and presentation path without a model call,
network, or iCloud account. It proves fallback state continuity for this debug
harness; it is not reviewed production curriculum and does not prove a complete
daily learning loop.

The production fallback must supply reviewed seed lessons and exercises, retain
stable source and version metadata, pass the same applicable deterministic
validators, and preserve the daily learning flow whenever the model is
unavailable, not ready, cancelled, rejected, or too expensive to run safely.

## Accessibility requirements and evidence

Code inspection and the default-size UI smoke test establish semantic status
text, accessibility identifiers, non-color state symbols, cancellation, retry,
and deterministic-fixture controls. They do not establish manual VoiceOver,
accessibility text-size, Reduce Motion, focus, or long-running generation
behavior.

Before this packet closes, physical-device or simulator manual evidence must
confirm:

- concise VoiceOver announcements for availability, generating, cancelled,
  rejected, and fallback states;
- state and recovery actions remain understandable without color and usable at
  accessibility text sizes;
- progress respects Reduce Motion and is not required to understand state;
- cancellation and deterministic fallback remain reachable without a timed
  interaction;
- a long generation request does not trap focus or block the deterministic
  fixture path.

## Privacy and provenance checks

- Use only public, licensed, or synthetic repository fixtures.
- Treat source-card text, title, and location as untrusted data, losslessly
  JSON-encoded inside the same boundary and separate from instructions.
- Assign citation identifiers in the prototype; never accept an invented source
  identity.
- Show or record only stable rejection categories, never the rejected values.
- Keep requests and generated artifacts on device.
- Log categories, counts, timing, memory, and thermal observations only.
- Do not sync raw artifacts or private diagnostics.

## Residual risks

- System-model behavior may change with an OS or model update even when the
  application code and prompt version are unchanged.
- One device, locale, and benchmark cannot represent every supported runtime
  configuration.
- Passing schema-constrained decoding does not prove factual correctness,
  teaching quality, or semantic answer uniqueness beyond the implemented
  structural validators.
- A short run may not reveal battery cost, sustained thermal pressure, or
  long-session memory growth.
- Context capacity may vary with schema complexity and source-card composition.
- Availability can change after setup, OS updates, or model asset changes, so
  the deterministic fallback remains mandatory after any go decision.

## Current conclusion

The isolated debug implementation uses the v2 deterministic identity boundary,
and the measurement harness now represents the frozen schedule and request-size
method. The declared iPhone accepts and launches the development-signed app.
Hardware, OS, locale/region, power/battery, and starting thermal evidence is
recorded, and Foundation Models is available for that configuration. The
complete generation benchmark remains unmeasured. No product or architecture
decision has been selected. The provider proposal remains **Proposed**, this
packet remains **In Progress**, and the complete v2 physical-iPhone measurement
remains pending.
