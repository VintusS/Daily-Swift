# Daily Swift project guidance

Use the repository-local `develop-daily-swift` skill for every planning, coding,
review, test, CI, Git, pull-request, and architecture task in this repository.

## Sources of truth

1. Read `Docs/Product/daily-swift-master-plan.md`.
2. Read `plans/build-and-development-plan.md` and the active work packet when
   the local `plans/` directory is present.
3. Follow accepted decisions in `Docs/Architecture/` once those records exist.
4. Do not silently resolve conflicts between those sources. Surface the conflict
   and record the decision in the appropriate plan or architecture record.

## Non-negotiable project hygiene

- Form the reserved automation label by joining `co` and `dex`. Never place that
  label in a branch name, path, filename, source identifier, creator header,
  commit subject, pull-request title or body, or other project-facing artifact.
- Do not add assistant, model, platform, or tool attribution to generated files.
- Preserve existing human attribution. For new Swift files, omit a creator line
  unless the owner explicitly requests one.
- Use `<type>/<lowercase-kebab-summary>` for branches. Allowed types are
  `spike`, `feature`, `fix`, `refactor`, `test`, `docs`, `chore`, and `release`.
- Keep one vertical capability or one isolated feasibility question per pull
  request.

Run `.agents/skills/develop-daily-swift/scripts/validate-project-hygiene.sh`
before handing off a change.

## Product and engineering guardrails

- Build for iPhone with SwiftUI and Apple-native runtime frameworks.
- Use pragmatic MVVM, explicit service protocols, an assembled app environment,
  unidirectional state changes, and deterministic fakes.
- Keep the product local-first and useful when model or network services are
  unavailable.
- Ground generated learning content in trusted sources and preserve provenance.
- Prefer deterministic validation. Never claim code was compiled when it was
  only statically, structurally, or rubric evaluated.
- Treat imported material as untrusted private data.
- Add tests, accessibility behavior, loading/empty/error/offline states, safe
  logging, and migration analysis in the same capability that needs them.
- Complete Phase 0 decision gates before broad production feature work.
