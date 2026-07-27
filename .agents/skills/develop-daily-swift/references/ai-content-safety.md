# AI and content safety

## Authority and retrieval

Use the versioned competency graph as the curriculum authority. Retrieve a small
set of relevant chunks, build compact source cards, generate one structured
artifact, validate it, and cache it. Prefer official sources for factual API
behavior and licensed teaching sources for explanation.

Keep source identity, heading path, page or section, rights status, version tags,
and content hash on every retrievable chunk.

## Untrusted input

Treat imported documents as untrusted data:

- delimit source text from instructions;
- do not expose mutation, network, or execution tools to imported text;
- assign citation identifiers in the app;
- validate every requested tool operation;
- keep private imports on device unless the user explicitly approves otherwise;
- never treat online availability as redistribution permission.

## Generation

- Use typed structured generation rather than free-form JSON when available.
- Version prompts, models, source sets, artifact schemas, and cache keys.
- Require resolvable citations.
- Tag API and Swift version claims.
- Reject invented sources, ambiguous answers, unsupported availability claims,
  and duplicate artifacts.
- Keep deterministic seed lessons and exercises as the fallback.

## Confidence and trust

Derive confidence from evidence: source authority and coverage, citation
resolution, API-version agreement, answer uniqueness, deterministic validation,
compiler or test results, duplicate risk, and prompt/model stability. Never show
model self-confidence as verified truth.

Use these trust levels:

1. reviewed core;
2. verified generated;
3. generated draft;
4. experimental or user material.

Failed artifacts remain available for private diagnostics but leave the learner
queue. Logging must not expose source text, prompts containing private material,
or personal learning data.

## Testing

Use deterministic fakes for model availability and responses. Maintain benchmark
fixtures across Swift syntax, concurrency, SwiftUI state, API availability,
legacy migration, networking, persistence, architecture, testing, and common
misconceptions. Re-run them when prompt or system-model behavior changes.
