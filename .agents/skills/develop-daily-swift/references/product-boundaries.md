# Product boundaries

## Product promise

Daily Swift should turn a focused 20–30 minute session into measurable growth in
the learner's chosen iOS-development skills. Mastery evidence, not activity or
generated volume, is the core outcome.

## Capability boundaries

1. **Learning Engine**: competency graph, assessment, mastery, spaced repetition,
   daily learning choices, and projects.
2. **Knowledge Engine**: imports, retrieval, citations, local generation,
   validation, caching, and tutoring.
3. **Motivation Engine**: daily queue, map, XP, currency, hearts, streaks,
   achievements, pet, and later social progression.
4. **Code Lab**: editor, constrained validation, workspaces, and Xcode export.
   Compilation expands only after feasibility is proven.

Do not bypass these boundaries by placing knowledge-generation rules in views,
gamification values in mastery calculations, or execution claims in generic
lesson state.

## Fixed product decisions

- Primary platform: iPhone.
- Minimum product baseline: iOS 26; the exact minor target remains an explicit
  repository-baseline decision.
- UI: SwiftUI.
- Architecture: pragmatic MVVM with explicit protocols and an assembled app
  environment.
- Runtime dependencies: Apple-native in the main app. Any compiler/runtime
  experiment remains isolated.
- Operation: local-first, offline-capable, and useful when generation is
  unavailable.
- Content: a manually designed, versioned competency graph is authoritative.
- Evaluation: deterministic where possible.
- Provenance: every generated lesson retains resolvable source locations.
- Identity: Apple-native services; no custom password backend in early versions.
- Public licensing: source code and educational content/assets have separate,
  explicit licenses.

## Required sequence

1. Establish repository baseline and validation.
2. Complete the five Phase 0 feasibility prototypes.
3. Record go/no-go decisions and fallback paths.
4. Build the app foundation.
5. Deliver a deterministic offline learning loop.
6. Add source retrieval and cited local generation.
7. Add motivation systems after learning invariants are stable.
8. Expand Code Lab according to proven capability.
9. Harden sync, export, accessibility, privacy, and performance.
10. Add public-product and social concerns only after the personal product is
    dependable.

## Scope controls

- Do not treat the 22-item personal MVP list as one milestone.
- Do not make arbitrary Swift or SwiftUI compilation a prerequisite for learning.
- Do not bundle private or unlicensed learning material.
- Do not make XP, hearts, coins, or subscriptions stand in for mastery.
- Do not require iCloud for offline use; require it only for sync behavior.
- Do not promise Foundation Models suitability until the device spike passes.
