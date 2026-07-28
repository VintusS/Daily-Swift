# ADR-006: Source ingestion, exact citations, and retrieval foundation

**Status:** Accepted
**Date:** 2026-07-28
**Owners:** Project maintainers

## Context

Daily Swift needs a private, offline evidence pipeline before generated learning
can consume imported material. The first production slice accepts lawful TXT
and Markdown files. It must preserve source identity and exact locations without
making an unmeasured indexing or model decision.

The existing learning-progress schema stores attempts, article activity, and
settings. Imported documents have a different lifecycle, storage footprint, and
deletion boundary. Adding source records to that schema would create an
unnecessary migration and couple learner evidence to rebuildable Knowledge
Engine data.

Packet 000-B has not measured PDF extraction, OCR, or retrieval ranking. ADR-005
also remains Proposed pending physical-iPhone evidence. The source foundation
must therefore be useful without either decision.

## Decision

### Domain and service boundary

Use application-owned `SourceDocument`, `SourceChunk`, `SourceCitation`,
`SourceLocation`, and rights/origin value types. Keep them independent of
SwiftUI, SwiftData, Uniform Type Identifiers, and model-provider frameworks.

Production source mutation runs in one actor behind a narrow
`SourceLibraryServing` protocol. Main-actor feature view models own visible
loading, empty, importing, cancelled, duplicate, malformed, failure, content,
and deletion states. Views render those states and send intents.

### Storage split

- Store source metadata and chunk-location records in a dedicated version-1
  SwiftData container.
- Store the approved original and normalized extracted text under Application
  Support in a directory owned by the stable source identifier.
- Keep absolute file-provider paths out of metadata.
- Do not add source models to the learning-progress container.
- Do not configure CloudKit or synchronization for source contents.

The importer copies the approved file while security-scoped access is active.
Later reading never depends on the original file-provider permission.

### Identity, normalization, and duplicates

Normalize TXT and Markdown deterministically before hashing or chunking:

1. decode supported text as UTF-8;
2. normalize line endings to line feed;
3. apply canonical Unicode composition;
4. remove trailing horizontal whitespace per line;
5. remove leading and trailing blank lines;
6. preserve internal blank lines and Markdown heading text.

Use SHA-256 of the normalized UTF-8 text as the stable content fingerprint.
Reject a second source with the same fingerprint and return the existing stable
source identifier. A source record keeps its UUID for its complete stored
lifetime.

### Chunks and citations

Chunk normalized text deterministically with a 1,200-character target. Prefer
Markdown heading boundaries and line boundaries; split an oversized line only
when required. Every chunk retains:

- stable source and chunk identifiers;
- ordered heading path;
- one-based inclusive line range;
- zero-based half-open Swift `Character` range in the normalized text;
- chunk content hash and bounded preview.

A citation is valid only when the stored source and chunk resolve, the character
range is in bounds, and the resolved excerpt still matches the chunk hash.
Citation navigation shows the exact stored excerpt and its heading, line, and
character location offline. It fails closed on missing or changed data.

### Import limits and derived data

Packet 004 accepts `.txt`, `.md`, and `.markdown` files up to 5 MiB. Empty,
unsupported, unreadable, invalid UTF-8, and larger files fail with stable,
privacy-safe categories. Streaming very-large-document ingestion is a later
packet.

Chunk locations are rebuildable from the normalized file and normalization
version. A later retrieval packet will keep a deterministic direct-scan oracle
and benchmark it against SQLite FTS5 before selecting a production keyword
index. Semantic reranking and `NLEmbedding` remain unselected until fixtures
show material benefit.

### Deletion

Deleting a source explicitly removes its document record, all chunk records,
the stored original, normalized text, and future derived indexes or generated
artifacts keyed to that source. Packet 004 implements the document/chunk/file
portion and exposes a confirmation before deletion.

## Alternatives considered

### Store original and normalized text in SwiftData

This simplifies one query path but makes large private text part of the
structured store and future sync/migration surface. Application Support is the
selected boundary for source bodies.

### Retain the picker URL or a security-scoped bookmark

This avoids a local copy but makes offline behavior depend on external provider
availability and permission lifetime. Daily Swift instead owns an approved
Application Support copy.

### Select SQLite FTS5 immediately

FTS5 is promising, but no repository fixture currently proves ranking,
tokenization, rebuild, or storage behavior. Exact chunks and a direct-scan
oracle are established first; the index choice remains a measured Packet 006
decision.

### Introduce a local package

The boundary has one application consumer and no measured build or reuse
benefit. Repository-native files remain in the app target.

## Consequences

### Positive

- Private sources remain available offline after import.
- Exact citations are resolvable without a model or index.
- Duplicate detection is deterministic across equivalent normalized files.
- Source persistence does not migrate or endanger learning evidence.
- Retrieval implementations can be benchmarked against stable chunks later.

### Negative

- The app owns a second SwiftData schema and Application Support lifecycle.
- Packet 004 deliberately rejects non-UTF-8 and files above 5 MiB.
- Character offsets refer to normalized text, not byte offsets in the original.
- Keyword and semantic ranking remain later decisions.

## Verification

- Unit-test normalization, heading paths, chunk boundaries, Unicode character
  offsets, hashing, duplicate detection, and citation resolution.
- Integration-test import, Application Support copies, restore, exact citation,
  and cascading deletion with an in-memory SwiftData container and temporary
  directory.
- UI-test the source library and exact-citation reader with synthetic fixtures
  where system document-picker automation is not stable.
- Run signing-independent Debug and Release builds plus project hygiene.

## Supersession

None.
