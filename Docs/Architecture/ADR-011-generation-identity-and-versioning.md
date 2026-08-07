# ADR-011: Generation identity, versioning, and local storage

**Status:** Accepted
**Date:** 2026-08-01
**Last amended:** 2026-08-01 — generated-only learner presentation
**Owners:** Project maintainers

## Context

Generated learning must remain attributable after relaunch and must not be
reused across a changed prompt, schema, source passage, or runtime model label.
Private imported text and generated artifacts must remain local, and corrupted
or partially written artifacts must not enter learner-facing history.

The owner subsequently directed that production articles and quizzes be
generated-only and explicitly repeatable. This requires fresh artifact identity
for every accepted request, stable randomized quiz presentation, honest finite
storage behavior, and explicit deferral of duplicate suppression and quality
feedback rather than claiming unimplemented learning or model training.

## Decision

Own and version these identities independently:

- generated artifact schema version;
- provider candidate schema version;
- prompt version;
- provider/runtime label, using the OS version only as a surrogate where the
  framework exposes no exact model build;
- ordered source-card identities and content hashes;
- a deterministic source-set hash;
- application-assigned artifact, article, quiz, citation-card, and choice IDs;
- the accepted quiz-choice sequence after one-time application randomization.

Store accepted generated artifacts as individual, atomically written JSON files
under Application Support. Do not store prompt bodies or source-card text in the
artifact. Store only generated presentation content, exact citation values,
rights metadata needed for provenance, versions, timestamps, and hashes.

Randomize quiz choices once before the final accepted artifact is persisted,
using an injectable random source. The stored array order is authoritative after
that point and restoration must not reshuffle it. Stable choice and answer-key
identities survive the ordering step. Existing schema-version-1 artifacts
already persist array order and require no body-file migration for this rule.

Keep the generated candidate in memory during the cancellable provider phase.
Persist only after the owning UI operation accepts that result and enters
non-cancellable finalization. Finalization rechecks the exact sources before
and after the atomic write. This two-phase boundary prevents a cancelled late
result from becoming restorable even when deletion would be unavailable.

Restoration decodes and validates every file before presentation. Invalid,
unsupported, corrupt, stale, or source-unresolvable artifacts fail closed per
individual file. One invalid file must not make an unrelated valid artifact
visible without validation, hide all valid history, or prevent deletion of
other artifacts. Source deletion removes every artifact that references that
source even when another stored file is invalid.

Restoration resolves the exact current excerpts and reruns the private
source-overlap presentation gate. This prevents a structurally valid but
modified artifact file from bypassing the gate after relaunch.

The current completion follow-up does not add exact or semantic duplicate
suppression. A fresh request and artifact identity prove that prior history was
not silently reused; they do not prove that the model produced different
wording. Fingerprint ownership and duplicate policy require a separate accepted
work packet and ADR amendment before implementation.

Bytes that conclusively fail decoding or schema support move intact into a
hidden quarantine and are never presented. A transient read failure preserves
the original file and reports storage failure. Because unreadable and
quarantined bytes cannot prove that they do not cite a source, an explicit
source deletion removes all such bytes conservatively.

Learner quiz-attempt and article-activity evidence remains in the existing
append/update progress store even when its generated artifact is later removed.
It contains only app-owned content and selected-choice IDs plus activity
timestamps and bookmark/read flags, never source text, source titles,
citations, generated bodies, or prompts. Generated quiz attempts persist with
`isCorrect = false`; while the artifact remains, the UI may compare the selected
choice with its experimental answer key. After artifact deletion, the UI keeps
only an unlabeled experimental answer record and makes no match claim.
Unavailable generated IDs do not contribute to mastery or deterministic
correctness totals.

History is never silently reused to satisfy an explicit Generate or New
Variation action. Every accepted request receives a new application-owned
artifact identity. The product imposes no arbitrary artifact-count quota, but
this is not a promise of infinite storage, uninterrupted model capacity, or
successful persistence. Generation remains foreground-only and serial. A
storage failure preserves existing artifacts and exposes a recoverable error;
automatic eviction remains prohibited until a later storage-management policy
is accepted.

The current completion follow-up does not store Good/Bad feedback. Any future
rating schema, sidecar lifecycle, deletion cascade, UI behavior, export, or
aggregation requires a separate work packet, ADR amendment, and accepted
persistence/privacy decisions. A future rating must remain app-owned subjective
feedback; it must not invoke `LanguageModelProvider`, mutate a model, change
trust, update mastery, prove correctness, or be described as training Apple
Intelligence.

## Alternatives considered

### Store generated bodies in SwiftData

This expands the structured schema and future sync surface for private
long-form data. Application Support matches the accepted storage split.

### Persist rendered prompts and source excerpts

This increases private-data exposure and is unnecessary for provenance. Exact
citations and version/hash identities are sufficient for restoration checks.

### Keep generated artifacts only in memory

Completion evidence would outlive the content after relaunch and the requested
learning history would disappear. It is rejected.

## Consequences

### Positive

- Generated articles and quizzes survive relaunch locally.
- Identity changes cannot silently reuse incompatible artifacts.
- Private prompt/source material does not enter artifact files or logs.
- Deletion and corruption have explicit fail-closed behavior.
- Repeated learner requests remain distinct without an arbitrary product quota.
- Choice order survives relaunch without changing answer identity or generated
  trust.

### Negative

- The app owns another local file lifecycle.
- Repeated generation can consume finite device storage until explicit
  generated-history management is delivered.
- Model/runtime changes may leave older artifacts visible only under their
  recorded experimental identity until a later invalidation policy changes.
- Cache optimization and storage management remain incomplete.

## Verification

- Round-trip multiple artifacts and their exact identities.
- Reject unsupported schema versions and corrupt or partial files.
- Verify atomic replacement and deterministic restore ordering.
- Verify one-time randomized choice order, stable restoration, and unchanged
  answer-key identity with an injected deterministic random source.
- Verify fresh request identity, no silent cache reuse, honest absence of a
  uniqueness guarantee, and recoverable storage exhaustion without deleting
  valid history.
- Verify one invalid file fails closed without hiding unrelated valid history or
  blocking deletion.
- Verify source deletion cascades without deleting source-free learning activity
  and that retained generated IDs cannot affect mastery or correctness totals.
- Verify no stored or logged prompt body, source-card text, or file-provider
  path.

## Supersession

None.
