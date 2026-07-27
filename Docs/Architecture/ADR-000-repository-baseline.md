# ADR-000: Repository baseline

**Status:** Accepted
**Date:** 2026-07-27
**Owners:** Project maintainers

## Context

The initial repository was an Xcode SwiftUI template with one application target,
an iOS 26.5 deployment target, iPhone and iPad support, Swift 5 language mode,
personal signing settings, user-specific Xcode state, and no test targets. The
product master plan establishes an iPhone-first iOS 26 application, modern Swift
concurrency, reproducible CI, and explicit tests before feasibility work.

The baseline must remain easy to clone and build without deciding product
features or prematurely adding package boundaries.

## Decision

### Platform

- Set the minimum deployment target to iOS 26.0.
- Support iPhone only during the personal product phases.
- Build against iPhone device and simulator SDKs.
- Disable Mac Catalyst and designed-for-iPad compatibility destinations.

### Swift

- Use Swift 6 language mode.
- Use complete strict-concurrency checking.
- Use explicit actor isolation rather than module-wide implicit isolation.
- Keep the application, views, and feature view models main-actor isolated
  where appropriate.

### Naming

- Keep the project, target, product, and display name as `Daily Swift`.
- Use `DailySwift` as the Swift module name.
- Use `DailySwiftApp` and `DailySwiftApp.swift` for the application entry point.
- Keep the existing bundle identifier until public-branding and entitlement
  decisions are made.

### Signing

- Do not commit a personal development-team identifier.
- Keep automatic signing for local device development.
- Build and test simulators in local automation and CI with signing disabled.
- Each developer selects their own team locally when a physical-device build is
  required.

### Tests

- Use Swift Testing for unit and integration tests.
- Use XCTest/XCUITest for a small set of critical user-flow smoke tests.
- Keep `Daily SwiftTests` and `Daily SwiftUITests` in the shared application
  scheme.
- Require the signing-independent build and both test targets in CI.

### Repository structure

- Keep the application as one target until stable domain boundaries justify
  local packages.
- Keep plans, automation, project guidance, and architecture records visible in
  Xcode but outside the application target.
- Ignore user-specific Xcode state and remove it from version control.

## Alternatives considered

### Keep iOS 26.5 and Swift 5

This would preserve the generated template but narrow device compatibility and
leave the concurrency model ambiguous. It was rejected because no current
product requirement depends on iOS 26.5.

### Support iPad from the start

This would increase layout, navigation, testing, and accessibility scope before
the iPhone learning loop is proven. It remains deferred.

### Commit the owner's development team

This makes one machine convenient but creates noisy changes and contributor
friction. Local signing selection is preferred.

## Consequences

### Positive

- Clean clones share one toolchain and scheme.
- Concurrency errors surface early.
- Simulator builds and tests do not depend on signing credentials.
- Product naming is consistent in Swift source and test imports.
- Future files in synchronized groups appear in Xcode automatically.

### Negative

- Physical-device development requires one local signing selection.
- Swift 6 can expose concurrency errors sooner than the generated Swift 5 setup.
- iPad support will require an explicit later decision and dedicated testing.

## Verification

Run:

```sh
.agents/skills/develop-daily-swift/scripts/validate-project-hygiene.sh
```

```sh
xcodebuild \
  -project "Daily Swift.xcodeproj" \
  -scheme "Daily Swift" \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath /tmp/daily-swift-build \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  clean build
```

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

## Supersession

None.
