---
name: github-only-tests
description: Prevent local execution of Daily Swift automated tests and reserve test execution for GitHub CI. Use for every Daily Swift coding, review, validation, Git, pull-request, bug-fix, refactor, or delivery task that could otherwise run unit, integration, UI, performance, or simulator tests locally.
---

# GitHub-only test execution

Keep automated test execution in the repository's GitHub workflow.

## Local policy

- Do not run `xcodebuild test`, `test-without-building`, `swift test`, XCTest,
  Swift Testing, UI-test, benchmark, or performance-test commands locally.
- Do not boot or drive an iOS Simulator solely to execute or verify tests.
- Continue to add and update deterministic tests as part of the implementation.
- Permit read-only inspection, static review, project hygiene,
  `git diff --check`, and build-only commands that do not execute a test target.
- Do not weaken, skip, delete, or mark tests ignored to accommodate this policy.

## Delivery evidence

- Before a branch is pushed, report tests as **not run locally; pending GitHub
  CI**.
- Use the hosted `Project Hygiene`, `Build`, and `Tests` checks as acceptance
  evidence after the pull request is available.
- Never describe tests as passed until the hosted `Tests` check succeeds.
- If GitHub CI is unavailable or failing for infrastructure reasons, report the
  change as unverified and preserve the test coverage for a later hosted run.

Only run a local test when the repository owner explicitly overrides this
policy in the current request.
