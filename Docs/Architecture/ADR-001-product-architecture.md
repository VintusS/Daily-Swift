# ADR-001: Product architecture and MVVM boundaries

**Status:** Accepted
**Date:** 2026-07-28
**Owners:** Project maintainers

## Context

The product master plan fixes SwiftUI, pragmatic MVVM, explicit service
protocols, unidirectional state changes, and an application environment
assembled at launch. The repository baseline also keeps one application target
until a stable boundary demonstrates a concrete reason to extract a local
package.

The first production vertical is a narrow launch and restoration shell. It must
replace the debug spike as the normal app root without pulling unresolved Phase
0 decisions into production architecture. In particular, Foundation Models,
SwiftData and CloudKit, synchronization, and code execution remain governed by
separate pending feasibility work and architecture records.

The existing structured-generation screen remains useful for Packet 000-A
measurement. It is debug-only experimental code and must not become a
production route, a source of production dependencies, or the design baseline
for the shell.

## Decision

### Target and feature boundaries

- Keep one application target plus the existing unit-test and UI-test targets.
- Organize the application by app-composition and feature folders inside that
  target.
- Keep domain behavior independent of SwiftUI and platform storage.
- Extract a local package only after a stable boundary has a measured reuse or
  build-time benefit.

### Composition root and dependency flow

`DailySwiftApp` is the composition root. It constructs one explicit
`AppEnvironment` and the root application state, then passes dependencies
through initializers.

`AppEnvironment` is a typed collection of dependencies required by the
currently implemented production capabilities. It is not a registry: it has no
string lookup, generic resolver, mutable global instance, or shared singleton.
A feature receives only the dependency values or protocols it uses rather than
the entire environment by default.

The dependency direction is:

```text
SwiftUI view
→ @MainActor feature or root view model
→ use case or narrow service protocol
→ local or platform adapter
```

Views render state and send user intents. They do not own launch, restoration,
navigation, persistence, provider-selection, validation, or other business
rules.

### Typed production routing

Use an `@MainActor`, observable `AppRouter` with a typed production-destination
model. The router owns navigation mutations and exposes unidirectional
operations such as opening, replacing, and returning from destinations.

Only production routes may enter its path or a persisted shell snapshot.
Routes do not contain service instances, generated content, imported material,
or platform-provider values. New destinations are added only when they lead to
a complete, useful surface; the initial shell does not create empty tabs.

Debug and experimental destinations are deliberately excluded from
`AppRouter`. This keeps the route and restoration contract identical in Debug
and Release builds.

### Root state ownership

Use a dedicated `@MainActor`, observable root view model with an explicit state
machine:

- `launching`;
- `restoring`;
- `firstRun`;
- `ready`;
- `recoverableFailure`.

The recoverable-failure value carries a stable, privacy-safe category and
available recovery actions, never underlying private data. The view model owns
startup, snapshot loading, retry, continue-without-restoration, and stale-task
handling. The root SwiftUI view maps those states to accessible presentation
and forwards intents to the view model.

### Shell snapshot boundary

Use `AppBootstrapServing` as the narrow shell-snapshot protocol. It restores,
saves, and resets a bounded, versioned `AppShellSnapshot`. Production routing
and root state depend on this protocol rather than calling storage APIs.

The snapshot contains only:

- its schema version;
- the first-run completion marker;
- restorable production route identifiers and their minimal non-private
  parameters.

It does not contain learner progress, settings, source content, generated
content, provider state, sync state, or execution workspaces.
`InMemoryAppBootstrapService` supplies success, missing-snapshot,
corrupt-snapshot, and failure behavior for tests and previews.
`UserDefaultsAppBootstrapService` is the local live adapter for this one small
encoded value. It must not become a general settings store or repository and
does not pre-empt ADR-002 or ADR-003.

An absent snapshot enters the first-run state. An unsupported or unreadable
snapshot enters a recoverable failure with retry and continue-without-
restoration actions. Future schema changes require migration fixtures before
shipping.

### Isolation from unresolved capabilities

The first shell environment does not expose or instantiate:

- a language-model provider or the Packet 000-A spike client;
- SwiftData models or a CloudKit container;
- a synchronization coordinator;
- an execution or compiler service.

No placeholder service locator or speculative protocol is added for those
capabilities. A later accepted packet extends `AppEnvironment` through explicit
initializer parameters only when its dependency is implemented.

### Debug spike launch

The structured-generation spike remains entirely under `#if DEBUG`. The
composition root may select it only when the process receives the explicit
`--open-structured-generation-spike` launch argument.

That launch path bypasses the production root and router, is never written to a
shell snapshot, and is not represented by a production route. Release code,
`AppEnvironment`, and the shell do not import Foundation Models or reference
spike types. The flag exists for developer measurement and the focused UI test;
it is not a user-facing product capability.

## Alternatives considered

### Put the spike in the production router

This would make route restoration differ by build configuration and could leave
a debug-only destination in persisted state. It would also invite the proposed
provider boundary into production navigation. An explicit non-restored debug
launch path preserves the measurement surface without those dependencies.

### Use a global environment or service locator

Global lookup reduces initializer wiring but hides dependencies, weakens
deterministic tests, and allows unresolved services to spread through features.
Explicit composition and initializer injection are selected.

### Let the root view perform restoration

Loading snapshots and deciding recovery inside SwiftUI view bodies would mix
business rules with presentation and make cancellation and failure behavior
harder to test. A root state machine and view model are selected.

### Introduce SwiftData, CloudKit, or a general repository now

Those choices belong to open Phase 0 work and later ADRs. The shell needs only a
small local restoration boundary, so adopting broader persistence or sync
infrastructure now would exceed the authorized vertical.

### Extract app architecture into a local package

The current repository has one consumer and no demonstrated package boundary.
Keeping the code in the app target avoids premature modularity.

## Consequences

### Positive

- Debug and Release share the same production shell and route contract.
- Launch, restoration, and recovery are deterministic and testable without
  platform providers.
- Dependencies remain visible at construction sites and narrow at feature
  boundaries.
- Pending provider, persistence, sync, and execution decisions cannot silently
  become production requirements.
- The Packet 000-A measurement screen remains available without entering
  restorable product navigation.

### Negative

- Explicit initializer wiring adds some composition code.
- The shell snapshot is intentionally too narrow for settings, progress, or
  feature persistence.
- Every new route and dependency requires an intentional environment and test
  update.
- The debug spike requires a launch argument rather than normal product
  navigation.

## Verification

- Unit-test all root-state transitions, including missing, corrupt,
  unsupported-version, failed, retried, and stale snapshot loads.
- Unit-test typed router mutations and snapshot restoration using production
  routes only.
- Test the live shell-snapshot adapter with a round trip and deterministic
  recovery from invalid data.
- Run UI smoke tests for cold launch, first run, restored ready state, and
  recoverable failure.
- Run the existing deterministic spike UI flow with
  `--open-structured-generation-spike`.
- Run signing-independent Debug and Release builds. The Release build must
  compile without any spike type or Foundation Models dependency from the
  shell.
- Run the repository hygiene validator before handoff.

## Supersession

None.
