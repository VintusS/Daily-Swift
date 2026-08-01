# ADR-011: Generation identity, versioning, and local storage

**Status:** Accepted
**Date:** 2026-08-01
**Owners:** Project maintainers

## Context

Generated learning must remain attributable after relaunch and must not be
reused across a changed prompt, schema, source passage, or runtime model label.
Private imported text and generated artifacts must remain local, and corrupted
or partially written artifacts must not enter learner-facing history.

## Decision

Own and version these identities independently:

- generated artifact schema version;
- provider candidate schema version;
- prompt version;
- provider/runtime label, using the OS version only as a surrogate where the
  framework exposes no exact model build;
- ordered source-card identities and content hashes;
- a deterministic source-set hash;
- application-assigned artifact, article, quiz, citation-card, and choice IDs.

Store accepted generated artifacts as individual, atomically written JSON files
under Application Support. Do not store prompt bodies or source-card text in the
artifact. Store only generated presentation content, exact citation values,
rights metadata needed for provenance, versions, timestamps, and hashes.

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

The first slice keeps history rather than silently reusing a previous artifact
as a generation cache. Cache lookup, deduplication policy, storage controls, and
automatic eviction remain follow-up work. Regeneration creates a new
application-owned artifact identity.

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

### Negative

- The app owns another local file lifecycle.
- Model/runtime changes may leave older artifacts visible only under their
  recorded experimental identity until a later invalidation policy changes.
- Cache optimization and storage management remain incomplete.

## Verification

- Round-trip multiple artifacts and their exact identities.
- Reject unsupported schema versions and corrupt or partial files.
- Verify atomic replacement and deterministic restore ordering.
- Verify one invalid file fails closed without hiding unrelated valid history or
  blocking deletion.
- Verify source deletion cascades without deleting source-free learning activity
  and that retained generated IDs cannot affect mastery or correctness totals.
- Verify no stored or logged prompt body, source-card text, or file-provider
  path.

## Supersession

None.
