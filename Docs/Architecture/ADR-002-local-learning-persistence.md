# ADR-002: Local learning persistence

**Status:** Accepted
**Date:** 2026-07-28
**Owners:** Project maintainers

## Context

The first functional learning studio needs to preserve challenge evidence,
article activity, interaction preferences, and the selected top-level tab.
ADR-001 intentionally limits the app-shell `UserDefaults` snapshot to launch
and bounded production routing; it cannot become a general learner-data store.

The product master plan selects SwiftData for structured learner progress and
settings, Application Support for large documents and generated material, and
Keychain for secrets. CloudKit behavior and conflict resolution remain a
separate, unproven decision governed by ADR-003.

Phase 0 is still open. The owner has explicitly authorized a deterministic,
local-only learning slice so the application can be exercised now. This record
therefore accepts only the local structured-data boundary and does not accept a
sync design.

## Decision

### Storage split

- Use SwiftData for small structured learner evidence, article activity, and
  interaction preferences.
- Keep reviewed seed curriculum immutable in the application bundle/source.
- Reserve Application Support for future original imports, extracted text,
  long-form generated content, indexes, and workspaces.
- Reserve Keychain for future secrets.
- Do not configure CloudKit in this record.

### Persistence boundary

Production features depend on `LearningProgressStoring`, not `ModelContext` or
SwiftData model types. The protocol restores a domain snapshot and records
typed mutations. `SwiftDataLearningProgressStore` is the live adapter and an
in-memory implementation supplies deterministic tests and previews.

SwiftUI views do not fetch or mutate persistence models directly. A main-actor
feature view model loads domain values, derives presentation state through pure
domain functions, and sends mutations to the repository.

Durable mutations drain through one FIFO coordinator. A newer user action does
not cancel an in-flight write, failed queue heads retain their stable mutation
identity for retry, and reset is an ordered barrier that rejects later
mutations until it resolves. Pending projection state may inform later queued
values, but learner-visible saved evidence is updated only after the
corresponding mutation succeeds.

Compound mutations that must agree after relaunch are repository operations,
not multiple view-model calls. In particular, opening an article records its
activity and the selected Library tab in one SwiftData save.

### Evidence model

Challenge attempts are append-only records containing:

- stable attempt identifier;
- stable challenge identifier;
- selected answer identifier;
- deterministic correctness result;
- attempt date;
- schema version.

Article activity is one mutable record per stable article identifier containing
bookmark, last-opened, and completion state. Interaction preferences and the
selected tab are one bounded settings record.

Progress is derived from these records. It is not stored or presented as
mastery, XP, streak, or model confidence. The future mastery decision may
consume attempt evidence without rewriting its historical truth.

Correct and incorrect feedback can appear immediately, but its save status is
bound to the exact attempt UUID. Failed writes cannot increase completed
challenge, Today, or Progress evidence until an idempotent retry commits.

### Schema and migration

The learning schema begins at version 1. Stable curriculum identifiers are the
join boundary between bundled content and learner data. Missing content
identifiers are ignored in projections while the original evidence remains
available for future migration or export.

Future schema changes require:

- an explicit versioned schema;
- a migration plan or documented reset decision;
- forward and rollback fixtures;
- preservation of append-only attempt evidence where possible.

The store may offer deletion only through an explicit user-confirmed reset. A
feature reset removes learning-studio records and does not clear the separate
app-shell snapshot, imports, Keychain values, or future synced data.

### Failure behavior

Failure categories exposed outside the adapter are stable and privacy-safe:
initialization, read, write, and reset failure. Raw database paths, values, or
underlying errors never enter learner-visible copy or logs.

The product offers retry and an explicitly temporary in-memory session when the
local store is unavailable. Temporary progress is clearly labeled and is not
silently represented as saved.

## Alternatives considered

### Expand the app-shell UserDefaults snapshot

This would violate ADR-001, mix navigation recovery with learner data, and make
append-only evidence and future migrations brittle.

### Persist one opaque Codable blob

A single blob is simple but weakens append-only evidence, partial recovery,
querying, and migration. Separate SwiftData records keep the first schema small
without hiding the domain history.

### Enable CloudKit now

Sync conflict rules, account-unavailable behavior, deletion, and production
schema operations are not proven. Enabling CloudKit would turn an offline slice
into an unmeasured synchronization decision.

### Keep progress only in memory

That would make the app appear interactive but fail the owner's requirement for
meaningful repeated testing and restoration.

## Consequences

### Positive

- The first product experience survives termination without expanding the
  app-shell snapshot.
- Challenge evidence remains explainable and reusable by a later mastery model.
- Views and domain tests remain independent of SwiftData.
- The application stays useful without network, account, model, or iCloud.
- CloudKit can be designed later without being implied by local persistence.

### Negative

- The application owns a schema and migration responsibility earlier than the
  original phase sequence.
- Cross-device progress is unavailable.
- Seed-content identifier stability becomes a release requirement.
- A temporary in-memory fallback cannot persist progress.

## Verification

- Unit-test deterministic progress projections and missing content identifiers.
- Integration-test an in-memory SwiftData container for round trips, append-only
  attempts, article upserts, settings, and reset.
- Test initialization, read, write, and reset failures through deterministic
  fakes.
- UI-test a save, termination, relaunch, and restoration flow.
- Run signing-independent Debug and Release builds plus project hygiene.

## Supersession

None.
