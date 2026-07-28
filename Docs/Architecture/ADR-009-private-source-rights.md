# ADR-009: Lawful private-source import and rights metadata

**Status:** Accepted
**Date:** 2026-07-28
**Owners:** Project maintainers

## Context

Daily Swift may help a learner use material they lawfully possess, but online
availability, file possession, or technical readability is not permission to
redistribute or send that material elsewhere. Imported content is also private,
untrusted input that must not alter application behavior or enter diagnostics.

The first source slice needs a durable policy before it stores user-selected
text. It does not introduce web scraping, sharing, synchronization, cloud AI, or
bundled third-party educational content.

## Decision

Every imported source requires:

- a user-visible title;
- the original local filename as origin;
- author and publisher when known;
- one explicit rights status: lawfully possessed private copy, open licensed,
  public domain, or permission granted;
- import date and normalized-content hash;
- `localOnly` set to true.

An unknown or unconfirmed rights state cannot cross the import boundary. The
interface explains that the learner is responsible for selecting material they
may use.

Source content remains on device. The app does not log original or normalized
text, full file-provider URLs, source excerpts, prompts containing private
material, or generated private artifacts. Learner-visible failures use stable
categories without underlying paths or contents.

Imported text is always untrusted data. Future generation must delimit it from
instructions, assign citation identities in the application, expose no
mutation/network/execution tool through source text, validate every citation,
and abstain when evidence is insufficient.

Deletion removes the private source and its derived local data. Future export,
sync, sharing, and cloud processing require separate, explicit decisions and
user consent.

## Alternatives considered

### Import with an implicit private-use assumption

This shortens the form but hides a licensing decision and produces incomplete
provenance. An explicit rights choice is required.

### Accept an unknown rights state

Unknown is useful for catalogs that contain only metadata and links, but it is
not sufficient for ingesting a private full-text source into this pipeline.

### Copy author or publisher guesses from file metadata

Local files often lack trustworthy metadata. Daily Swift captures known values
without inventing them.

## Consequences

### Positive

- Rights and provenance survive every later chunk and citation.
- Private material has no implicit network or sync path.
- The policy supports lawful personal use without representing it as a public
  content license.

### Negative

- Import requires one additional learner decision.
- The application cannot verify the learner's legal rights automatically.
- Sharing and cloud features need later consent and data-boundary work.

## Verification

- Reject an import request without a permitted rights status.
- Persist and restore title, origin, author, publisher, rights, hash, date, and
  local-only state.
- Inspect logs, UI fixtures, tests, and screenshots for private source text or
  paths.
- Verify deletion removes the original, normalized text, chunks, and metadata.

## Supersession

None.
