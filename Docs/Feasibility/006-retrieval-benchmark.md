# Packet 006 evidence: Retrieval benchmark and decision

**Status:** Completed
**Evidence record version:** 1
**Opened:** 2026-07-29
**Closed:** 2026-07-30
**Decision:** Direct scan
**Governing record:** [ADR-006](../Architecture/ADR-006-source-ingestion-and-retrieval.md)

## Question

For bounded local source retrieval, does SQLite FTS5 materially improve repeated
query performance over a deterministic direct scan without reducing relevance,
exact-citation integrity, rebuild determinism, privacy, or offline behavior?

## Frozen fixture

The project-owned synthetic corpus contains:

- one Swift value-semantics source;
- one protocol dependency-boundary source;
- one SwiftUI state-ownership source;
- one structured-concurrency cancellation source;
- one application-storage distractor;
- 100 additional distractor chunks that share one common query term without
  containing the complete target concept.

Five ranked judgments cover:

- an exact multi-term concept;
- plural and inflected terms;
- heading and body evidence;
- shared vocabulary;
- bounded result counts and source filters.

A separate no-result query verifies abstention. The benchmark records only
aggregate counts, metrics, durations, and derived storage bytes. It does not
record queries, source identities, titles, excerpts, paths, or private content.

## Correctness oracle

The direct-scan implementation is the correctness oracle. It:

1. validates and bounds the query before source restoration;
2. resolves every candidate through the exact-citation boundary;
3. normalizes query, heading, and body terms deterministically;
4. ranks coverage, exact sequence, headings, and bounded frequency;
5. breaks ties with stable source and chunk identities.

Both candidates must achieve:

- precision at 1: 1.0;
- mean reciprocal rank: 1.0;
- identical repeated results;
- no missing, stale, or invalid citation in returned results;
- no deleted or filtered source in returned results.

Timed comparisons reuse the same already resolved in-memory corpus so the
measurement isolates ranking and lookup work. Separate integration checks cover
source restoration, exact-citation resolution, filtering, and deletion.

## Selection rule

Select SQLite FTS5 for Packet 007 only when it satisfies every correctness gate,
reduces aggregate repeated-query time by at least 50 percent, and uses no more
than twice the normalized fixture byte count for its derived index.

Otherwise select direct scan. A timing result too small or noisy to establish
the threshold selects direct scan because it has no index lifecycle.

## Hosted result

| Signal | Direct scan | SQLite FTS5 |
|---|---:|---:|
| Precision at 1 | 1.0 | 1.0 |
| Precision at 3 | Not durably captured | Not durably captured |
| Mean reciprocal rank | 1.0 | 1.0 |
| Repeated query time | Not durably captured | Not durably captured |
| Index build time | Not applicable | Not durably captured |
| Derived storage | None | Not durably captured |
| Deterministic repeat/rebuild | Passed | Passed |
| Exact citations resolve | Passed | Passed |

Environment:

| Field | Value |
|---|---|
| Workflow | `iOS CI`, pull-request run `30519289416` |
| Runner | `macos-26-arm64`, image `20260720.0258.1` |
| Xcode | 26.5 |
| Simulator | iPhone 17 |
| OS | iOS 26.5; runner macOS 26.4 |
| Corpus entries | 105 |
| Judgments | 5 |
| Timing repetitions | 20 |

## Decision

Select the deterministic direct scan for Packet 007.

The hosted `Project Hygiene`, `Build`, and `Tests` jobs passed. The focused
retrieval tests confirmed both candidates' precision-at-1 and reciprocal-rank
gates, deterministic results, FTS5 deletion/rebuild behavior, filtering, query
validation before source access, and exact citation resolution. The hosted run
uploaded no workflow artifacts, and the exact `retrieval-benchmark.txt`
attachment was not present in its job log. Precision at 3, repeated-query
durations, FTS5 build duration, and derived storage bytes therefore cannot be
recorded or estimated.

ADR-006 requires FTS5 to establish every correctness, performance, and storage
gate before promotion. It also selects direct scan when hosted timing is
inconclusive. Because the durable evidence does not establish the 50 percent
timing improvement or the two-times storage ceiling, FTS5 remains experimental
and Packet 007 uses direct scan without an index lifecycle.

## Residual risks

- GitHub runner timing does not establish physical-device latency, memory,
  energy, or thermal behavior.
- The synthetic English fixture does not select tokenization for every
  programming symbol, language, or future curriculum domain.
- Keyword retrieval cannot resolve semantic synonyms absent shared terms.
- Larger books may justify indexing even when this bounded corpus selects
  direct scan; any later threshold change requires a new frozen benchmark.
