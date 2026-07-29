---
name: develop-daily-swift
description: Build, plan, review, test, or deliver work in the Daily Swift iOS repository while enforcing its product phases, architecture, Apple-native dependency boundary, privacy, accessibility, testing, Git, and project-hygiene rules. Use for any Daily Swift code, plan, ADR, build packet, CI workflow, pull request, bug fix, refactor, or project review.
---

# Develop Daily Swift

Keep work aligned with the product promise while reducing each change to one
measurable decision or vertical capability.

## Establish context

1. Read the root `AGENTS.md`.
2. Read `Docs/Product/daily-swift-master-plan.md`.
3. Read `references/product-boundaries.md` and `references/delivery.md`.
4. If `plans/` exists, read `plans/build-and-development-plan.md` and the active
   work packet. Treat those files as local execution guidance, not a replacement
   for the master plan.
5. Read accepted records under `Docs/Architecture/` for the boundary being
   changed.

Do not invent a phase, feature, or architecture decision when the sources leave
it unresolved. Make the decision explicit in a work packet or architecture
record.

## Route the task

- For Swift or SwiftUI structure, persistence, services, navigation, or state,
  read `references/architecture.md`.
- For source import, retrieval, curriculum, model generation, prompts, citations,
  or generated exercises, read `references/ai-content-safety.md`.
- For Code Lab, static validation, a runner, compiler research, or export, read
  `references/execution-capabilities.md`.
- For Git, CI, branch, commit, pull-request, versioning, or release work, follow
  `references/delivery.md`.

Load only the references needed for the task after the two required references.

## Select the smallest valid outcome

Classify the work before editing:

1. **Repository baseline**: enable reliable development without deciding product
   behavior.
2. **Feasibility spike**: answer one high-risk question with measured evidence,
   a fallback, and a decision record.
3. **Foundation**: establish a reusable boundary required by an approved slice.
4. **Vertical capability**: deliver domain behavior through service, state, UI,
   persistence, and tests where those layers are relevant.
5. **Defect or maintenance**: restore or preserve defined behavior without
   expanding scope.

Do not implement broad production feature UI before the Phase 0 gates are
resolved. Prefer a deterministic offline learning loop as the first product
slice after the spikes.

## Implement in dependency order

For a feature, use this order where applicable:

1. domain model and invariants;
2. use case or service protocol;
3. deterministic fake;
4. platform or persistence adapter;
5. main-actor view model;
6. SwiftUI view;
7. integration and UI verification;
8. accessibility, offline, logging, migration, and documentation updates.

Keep platform APIs behind narrow boundaries. Assemble dependencies in the app
environment. Do not place business rules in views or bind the whole UI directly
to persistence models.

## Apply fixed guardrails

- Use SwiftUI and Apple-native runtime frameworks in the main app.
- Keep local and deterministic fallbacks for unavailable models and networks.
- Preserve source rights metadata and exact provenance.
- Treat imported material as private, untrusted input.
- Never use model self-confidence as product truth.
- Label evaluation honestly: compiled, deterministically validated, statically
  checked, rubric evaluated, or experimental.
- Include tests and explicit exit criteria in every phase deliverable.
- Include VoiceOver, Dynamic Type, Reduce Motion, contrast, and non-color state
  behavior in changed UI.
- Avoid premature local packages and generic layers without a concrete boundary.

## Enforce project hygiene

Form the reserved automation label by joining `co` and `dex`. Do not use that
label in project-facing names, text, branches, commits, pull requests, source
headers, or attribution. Do not add any automated creator line. Use the branch
and delivery rules in `references/delivery.md`.

Before handoff, run:

```sh
.agents/skills/develop-daily-swift/scripts/validate-project-hygiene.sh
```

Then run the most specific available build-only command. Apply the
`github-only-tests` skill: add and inspect tests locally, but leave all automated
test execution to GitHub CI. Report the exact local checks, hosted results when
available, remaining risks, and any unverified device-only behavior.
