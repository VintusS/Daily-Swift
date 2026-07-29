# Delivery workflow

## Task packet

Require every task to state:

- objective;
- allowed files or boundary;
- acceptance criteria;
- non-goals;
- test and build commands;
- accessibility and offline implications;
- privacy, provenance, and licensing implications;
- persistence and migration implications;
- performance constraints;
- rollback or fallback;
- architecture record impact.

If these are missing, infer only safe, reversible details. Record any decision
that changes product behavior or architecture.

## Branches and history

Use `<type>/<lowercase-kebab-summary>`.

Allowed types are `spike`, `feature`, `fix`, `refactor`, `test`, `docs`, `chore`,
and `release`. Do not include assistant, model, platform, or tool branding.

Use imperative commit subjects. Keep commits intentional and keep a pull request
to one vertical capability or one feasibility question. Prefer squash merge into
protected `main`, then delete the branch.

Form the reserved automation label by joining `co` and `dex`. It is prohibited in
branch names, path names, file content, source identifiers, attribution, commit
subjects, and pull-request text.

## Pull requests

Use `.github/pull_request_template.md`. Require:

- explicit outcome and linked work packet;
- acceptance evidence and exact commands;
- architecture/data/privacy notes;
- screenshots or recordings for UI;
- tests at the lowest useful boundary;
- accessibility verification;
- risk and rollback notes;
- successful `Project Hygiene`, `Build`, and `Tests` checks from `iOS CI`.

Recommended `main` ruleset:

- require a pull request;
- require one approval when collaborators are present;
- dismiss stale approvals;
- require conversation resolution;
- require the `Project Hygiene`, `Build`, and `Tests` checks to pass;
- require the branch to be current before merge;
- block force pushes and deletion;
- allow squash merge; disable direct pushes.

## Versioning

- Keep `main` releasable and tag public releases with semantic versions.
- Increment the Xcode build number for distributed builds.
- Version persisted schemas, competency content, prompts, generated schemas, and
  exports independently.
- Pair every data migration with forward tests and a documented recovery path.

## Verification

Always run the hygiene script and a signing-independent Xcode build. Do not run
automated test suites, UI tests, or benchmarks locally. Add and review the
required test coverage, then rely on the hosted `Tests` check for execution.
Run generated-content benchmarks through GitHub CI when a prompt, model, source
schema, or validation rule changes.

Before hosted results exist, report tests as not run locally and pending GitHub
CI. Do not report a build as tested when no hosted test target executed.
