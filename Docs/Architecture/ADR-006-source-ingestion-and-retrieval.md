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

Packet 005 subsequently measured text-PDF extraction on iOS 26.5 and extends
this decision with a PDFKit adapter, page provenance, and explicit scanned-page
detection. It does not accept OCR or a retrieval implementation.

Packet 006 adds the fixed retrieval benchmark contract, a deterministic
direct-scan correctness oracle, and a Debug-only SQLite FTS5 candidate. The
production retrieval selection remains pending until the hosted benchmark
evidence is available.

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

The source importer accepts `.txt`, `.md`, `.markdown`, and text-based `.pdf`
files up to 50 MiB. Empty, unsupported, unreadable, invalid UTF-8, and larger
files fail with stable, privacy-safe categories. The limit is a binary input
cap, not a promise that arbitrary large documents will have low extraction,
normalization, or indexing cost. Streaming very-large-document ingestion
remains a later packet.

The 50 MiB boundary is checked from file metadata before extraction and checked
again from the readable byte count. A file exactly at the boundary is accepted;
a file one byte larger fails before visible metadata is created. The importer
continues to run outside the main actor, supports cancellation before metadata
commit, and stages local files before atomically publishing the source.

Simulator evidence recorded on 2026-07-29 with Xcode 26.5, an iPhone 17 arm64
simulator, and iOS 26.5:

| Fixture | Input bytes | Pages | Extracted characters | Extraction | Resident delta |
|---|---:|---:|---:|---:|---:|
| Small | 8,866 | 2 | 118 | 0.0054 s | +786,432 B |
| Medium | 1,048,576 | 20 | 1,191 | 0.0110 s | +81,920 B |
| Near 50 MiB limit | 52,427,776 | 80 | 4,791 | 0.4241 s | +393,216 B |

The focused source-service and PDF-extraction run passed 18 tests with no
failures or skips. It covered exact-boundary acceptance, one-byte-over rejection,
and extraction of the near-boundary synthetic PDF. Resident deltas are process
snapshots around extraction, not sampled peak memory, and do not establish
physical-device thermal behavior.

Chunk locations are rebuildable from the normalized file and normalization
version. Packet 006 keeps a deterministic direct-scan oracle and benchmarks it
against SQLite FTS5 before selecting a production keyword index. Semantic
reranking and `NLEmbedding` remain unselected until fixtures show material
benefit.

### Retrieval benchmark contract

Use application-owned `SourceRetrievalRequest`, `SourceRetrievalMatch`, and
`SourceRetrievalFailure` values. Validate an input before restoring or resolving
any private source:

- trim the query and reject empty or stop-word-only input;
- limit queries to 200 Swift `Character` values;
- limit results to at most eight;
- normalize case, width, diacritics, punctuation, common stop words, and a
  conservative set of English inflections deterministically;
- optionally constrain retrieval to an explicit set of source identifiers.

The direct-scan oracle resolves existing chunks through
`SourceLibraryServing`, so every candidate passes the established source,
chunk, location, content-hash, and page-provenance checks before ranking. Rank
term coverage first, then exact term sequence, heading evidence, and bounded
term frequency. Break ties by stable source and chunk identities. Returned
matches retain the resolved document, exact citation, excerpt, score, and
matched normalized terms.

Compare the oracle with a Debug-only SQLite FTS5 index using the same resolved
corpus and judgments. FTS rows contain a stable entry key, source identifier,
heading path, and body. Use the built-in Porter/Unicode tokenizer and weighted
BM25 ranking. Bind query terms and source filters as parameters; never compose
private text into SQL. The index is private derived data, versioned
independently, removable, and rebuildable from validated local chunks.

The frozen hosted fixture contains five relevant synthetic chunks and 100
synthetic distractors. Five judgments cover exact concepts, inflected terms,
multi-term concepts, shared vocabulary, and source filtering. Record precision
at 1, precision at 3, reciprocal rank, deterministic equality, repeated query
time, FTS build time, and derived storage bytes. Time both ranking candidates
against the same already resolved in-memory corpus; verify restoration,
citation resolution, filtering, and deletion separately.

Keep direct scan for production unless FTS5:

1. matches the oracle's perfect precision at 1 and reciprocal rank;
2. returns only exact resolvable citations;
3. produces identical results across rebuilds;
4. reduces repeated aggregate query time by at least 50 percent; and
5. uses no more than twice the normalized fixture byte count for derived
   storage.

If any gate fails or hosted timing is inconclusive, retain direct scan as the
Packet 007 implementation and keep FTS5 experimental. Semantic retrieval,
embeddings, query logging, and generation remain out of scope.

### Text PDF extraction and page provenance

Use `PDFKit` behind the app-owned `PDFTextExtracting` protocol. PDFKit types do
not enter domain models, feature view models, navigation state, or persistence
records.

For an accepted text PDF:

1. copy the original PDF while security-scoped access is active;
2. extract selectable text in one-based page order;
3. normalize each page with the accepted normalization version;
4. join non-empty pages with a deterministic two-line-feed separator;
5. record each non-empty page's half-open `Character` range in a versioned
   `page-map.json` sidecar;
6. attach the intersecting one-based page range to each domain chunk and
   citation;
7. validate source, chunk, normalized range, content hash, and page range before
   presenting the citation;
8. open the locally stored original PDF at the first cited page on request.

Page maps are private, derived data beside the stored original and normalized
text. The existing source metadata schema remains version 1 because no stored
model changes are required. Each sidecar includes a deterministic checksum of
its version and ordered page spans. Restore validates the checksum, increasing
page numbers, non-overlapping in-bounds ranges, and normalized-text bounds
before hydrating page locations. A missing, unreadable, or invalid sidecar is
rebuilt from the stored original only when the re-extracted normalized content
hash matches the document fingerprint; otherwise restoration fails closed.

Treat a PDF as requiring OCR when it has no selectable-text pages or when fewer
than 20 percent of its pages contain non-whitespace selectable text. Encrypted,
malformed, extraction-failed, oversized, and cancelled imports do not create
visible metadata. OCR remains a separate opt-in decision.

The normalized-content SHA-256 remains the duplicate identity across all source
formats. A PDF whose extracted normalized text matches an existing text,
Markdown, or PDF source resolves as a duplicate of that existing source rather
than creating a second document with different provenance.

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
- Invalid retrieval requests fail before private source text is read.
- Direct scan provides a deterministic, fail-closed relevance oracle.

### Negative

- The app owns a second SwiftData schema and Application Support lifecycle.
- The importer deliberately rejects non-UTF-8 text and files above 50 MiB.
- Text PDFs up to 50 MiB are accepted; scanned/image-dominant PDFs remain
  rejected until an OCR decision is made.
- The higher input cap increases temporary disk use and potential extraction,
  normalization, and chunking memory. Simulator measurements do not replace
  physical-device peak-memory and thermal validation.
- Character offsets refer to normalized text, not byte offsets in the original.
- PDF line and character offsets refer to normalized extracted text; one-based
  page ranges preserve navigation to the locally stored original.
- Keyword and semantic ranking remain later decisions.
- Direct scan resolves every candidate before ranking and therefore scales
  linearly with stored chunks; Packet 006 measures whether FTS5 justifies its
  derived storage and rebuild complexity.

## Verification

- Unit-test normalization, heading paths, chunk boundaries, Unicode character
  offsets, hashing, duplicate detection, and citation resolution.
- Integration-test import, Application Support copies, restore, exact citation,
  and cascading deletion with an in-memory SwiftData container and temporary
  directory.
- UI-test the source library and exact-citation reader with synthetic fixtures
  where system document-picker automation is not stable.
- Unit-test PDFKit extraction with synthetic project-owned text and image-only
  PDFs.
- Integration-test page-map persistence, rebuild, cancellation, exact-page
  citation resolution, and deletion without retaining the provider URL.
- UI-test opening a page-aware citation and its locally stored original PDF.
- Integration-test acceptance at exactly 50 MiB and rejection one byte above
  the limit without publishing metadata.
- Measure PDF extraction at the 50 MiB boundary and record that simulator
  resident-memory deltas are not physical-device peak-memory evidence.
- Run the frozen retrieval judgments against direct scan and SQLite FTS5 in
  hosted CI; record relevance, deterministic rebuild, timing, and storage
  evidence before selecting Packet 007 production retrieval.
- Run signing-independent Debug and Release builds plus project hygiene.

## Supersession

None.
