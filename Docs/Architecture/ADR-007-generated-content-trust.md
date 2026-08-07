# ADR-007: Generated-content trust and presentation safety

**Status:** Accepted
**Date:** 2026-08-01
**Last amended:** 2026-08-01 — generated-only learner presentation
**Owners:** Project maintainers

## Context

Daily Swift can retrieve exact passages from lawful private imports and can ask
an on-device model for a typed article and multiple-choice quiz. Typed decoding
does not prove factual correctness, semantic answer uniqueness, API
availability, compilation, or teaching quality. The first production slice
therefore needs an honest trust tier and a fail-closed boundary before any
generated candidate becomes learner-visible.

Prompt instructions to use original wording and avoid extended quotation do not
prove originality or a quotation limit by themselves. The private presentation
gate therefore also rejects any candidate field that repeats 16 or more
consecutive normalized words from a supplied source card.

The first Packet 008 implementation retained authored articles and challenges
beside generated history. The owner subsequently directed that learner-facing
articles and quizzes be generated-only. This changes presentation fallback, not
the evidence required for a generated artifact to cross the trust gate.

## Decision

Classify every artifact generated from private imported material as
`Experimental/User Material`. Structural validation and exact provenance do not
raise it to `Verified Generated`.

Before presentation, require all of the following:

- one to four application-assigned, size-bounded source cards;
- a current source, chunk, range, and content hash for every card;
- a non-empty bounded article and one bounded multiple-choice quiz;
- at least one unique, resolvable citation for the article and quiz explanation;
- exactly three non-empty, normalized-unique choices;
- exactly one application-owned answer-key identity that resolves to a choice;
- matching prompt, candidate-schema, artifact-schema, and source-set identities;
- no sequence of 16 or more normalized source-card words repeated verbatim in
  any generated article, code, quiz, choice, or explanation field;
- no stale result after cancellation, replacement, source deletion, or failure;
- privacy-safe rejection categories containing no source or generated text.

Reapply the source-overlap gate during restoration using the exact currently
resolved excerpts. Persisted bytes are not trusted merely because their schema,
citations, and hashes decode successfully.

Generation and persistence use two explicit phases. The cancellable provider
phase returns only an in-memory candidate. Once that result is accepted by the
main-actor operation identity, the UI enters a short non-cancellable
finalization phase that revalidates exact sources and persists atomically. A
late result from a cancelled provider therefore has no stored artifact to
delete or resurrect.

The generated answer key may be used for private practice feedback labeled
`Experimental`. A match is recorded as activity evidence but is excluded from
deterministic correctness, mastery, assessment, prerequisite unlocking, and
authoritative curriculum. The UI says “matches the generated answer key” rather
than claiming independently verified correctness.

Randomize a generated quiz's choice order once at the application boundary
before persistence, then revalidate that the stable answer-key identity resolves
to exactly one stored choice. Persist the accepted order and do not reshuffle it
when the artifact is opened or restored. Random placement is presentation
variation, not evidence of factual correctness or semantic novelty.

Each explicit Generate or New Variation action creates a fresh request and must
not silently reuse a prior presentation artifact. The current completion
follow-up does not add exact or semantic duplicate suppression, so a fresh
request can still produce similar or identical wording. The UI must not promise
that model output is inherently random or unique.

Good/Bad quality-feedback UI and storage are deferred to a separate work packet
and accepted persistence/privacy decision. If introduced later, a rating is
subjective learner feedback: it cannot change trust, citation validity,
answer-key status, correctness, mastery, or curriculum, cannot bypass this
presentation gate, and must never be described as model training.

Every article and quiz exposes exact citation actions. If a citation no longer
resolves, the artifact fails closed and is removed from learner-facing history.
Source deletion removes every stored generated artifact that references it.
Delete dependent generated artifacts before committing source deletion. If
derived cleanup cannot be confirmed, retain the source and present a retryable
failure; if the later source mutation fails, disclose that generated artifacts
may already have been removed.

Previously accepted generated history and imported-source reading remain
available when retrieval is insufficient or generation is unavailable,
cancelled, rejected, or failed. If neither exists, the app presents an explicit
empty or unavailable state rather than an authored article or quiz.

The current overlap gate and trust tier authorize private, local presentation
only. The gate is conservative protection, not proof of originality or broader
copyright compliance. Sharing, export, or redistribution requires a separate
rights decision and stronger accepted policy.

## Alternatives considered

### Treat typed output as verified

This confuses shape validation with factual and semantic proof. It is rejected.

### Hide citations behind a single source list

This weakens claim-level provenance and makes stale references harder to find.
Article and quiz scopes retain their own exact citations.

### Block all presentation until every semantic validator exists

This is safer but does not provide the owner-requested private experimental
learning loop. The explicit trust label, mastery exclusion, exact citations,
generated-history/source-reading fallback, and honest empty state bound the
initial risk.

## Consequences

### Positive

- Learners can inspect where experimental content came from.
- Invalid or stale artifacts do not enter the learning interface.
- Experimental answer matches cannot inflate mastery.
- Stronger validators can promote trust later without changing source identity.

### Negative

- Generated quiz feedback is useful practice, not proof of correctness.
- Some plausible candidates will be rejected.
- Citation resolution and source deletion must coordinate with artifact storage.
- Exact provenance does not by itself prove original phrasing or copyright
  compliance for exported or redistributed content.

## Verification

- Test every validation category with deterministic provider candidates.
- Test the 15-word accepted and 16-word rejected normalized source-overlap
  boundary for both fresh candidates and restored artifacts.
- Test exact TXT, Markdown, and PDF citation navigation.
- Test cancellation, stale-result suppression, unavailable and rejected states.
- Test that generated attempts are persisted but excluded from mastery.
- Test source-deletion cascade and corrupt-artifact fail-closed restoration.
- Test one-time choice randomization, stable restored order, and stable
  answer-key identity with an injected deterministic random source.
- Test fresh request identity and no silent artifact reuse while making no exact
  or semantic uniqueness claim.
- Test empty and unavailable states without learner-facing seed content while
  preserving saved generated history and imported-source reading.
- Verify VoiceOver order, accessibility text sizes, Reduce Motion, non-color
  state, and empty/fallback reachability.

## Supersession

None.
