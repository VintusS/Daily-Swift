# Contributing to Daily Swift

Daily Swift uses short-lived branches and pull requests into a protected `main`
branch. Keep changes small enough to review as one vertical capability or one
isolated technical experiment.

## Branches

Name branches as `<type>/<lowercase-kebab-summary>`.

Allowed types:

- `spike` for a measured feasibility experiment;
- `feature` for user-visible capability;
- `fix` for a defect;
- `refactor` for behavior-preserving structure changes;
- `test` for test-only work;
- `docs` for documentation and architecture records;
- `chore` for repository maintenance;
- `release` for release preparation.

Examples: `spike/foundation-model-availability`,
`feature/deterministic-daily-queue`, and `fix/citation-page-offset`.

Do not use assistant, model, platform, or tool names in branches or generated
artifacts. Do not add automated creator attribution to source headers.

## Pull requests

Open a pull request for every change to `main`. A pull request should:

- link its issue or work packet;
- state the objective, acceptance criteria, non-goals, and risks;
- identify architecture, privacy, accessibility, and migration impact;
- include tests appropriate to the changed boundary;
- pass the required `Project Hygiene`, `Build`, and `Tests` checks from `iOS CI`;
- update the applicable architecture record when a durable decision changes.

Use squash merge after approval and successful checks, then delete the source
branch. The squash subject should be an imperative summary suitable for history.

## Local validation

Run the hygiene check:

```sh
.agents/skills/develop-daily-swift/scripts/validate-project-hygiene.sh
```

Run the signing-independent build:

```sh
xcodebuild \
  -project "Daily Swift.xcodeproj" \
  -scheme "Daily Swift" \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath /tmp/daily-swift-derived-data \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  clean build
```

Run the unit and UI smoke tests:

```sh
xcodebuild \
  -project "Daily Swift.xcodeproj" \
  -scheme "Daily Swift" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5" \
  -derivedDataPath /tmp/daily-swift-tests \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  clean test
```

## Definition of done

A capability is complete only when behavior is verified and its loading, empty,
error, offline, accessibility, privacy, logging, persistence, and migration
effects are handled where relevant. Generated learning material must retain
source provenance and an honest validation label.
