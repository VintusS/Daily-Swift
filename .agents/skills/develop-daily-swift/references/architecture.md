# Architecture rules

## Dependency direction

Use this dependency flow:

```text
SwiftUI View
→ Feature ViewModel
→ Use Case or Domain Service
→ Repository or Platform Service
→ SwiftData, files, model provider, CloudKit, GameKit, or StoreKit
```

Keep domain behavior independent of SwiftUI and storage frameworks. Expose
platform behavior through narrow protocols and supply deterministic fakes.

## State and dependencies

- Keep feature view models isolated to the main actor.
- Use unidirectional state updates.
- Assemble live dependencies once in `AppEnvironment`.
- Pass dependencies through explicit initialization or a controlled environment
  value.
- Prefer value types for domain state and actors for shared mutable subsystems.
- Keep imported files and large derived data out of SwiftData.
- Treat indexes, embeddings, caches, and generated intermediates as rebuildable.

Use actors only around real shared mutable work, such as source import, indexing,
generation, progress mutation, workspace mutation, and sync coordination.

## Feature shape

Keep related feature files together until reuse and stability justify extraction.
Start with one app target plus unit and UI test targets. Extract pure logic into a
local Swift package only when a stable dependency boundary and measurable build
or reuse benefit exist.

## SwiftUI quality

- Keep view bodies declarative and free of business rules.
- Model loading, empty, content, error, and offline states explicitly.
- Avoid global singletons and hidden service locators.
- Add previews or fixtures for meaningful states when they remain deterministic.
- Treat accessibility behavior as part of the feature API.
- Keep navigation decisions in an explicit router or feature coordinator.

## Persistence and sync

- Use SwiftData for structured metadata, progress, relationships, and settings.
- Use Application Support for original imports, extracted text, generated
  long-form content, workspaces, models, embeddings, and indexes.
- Use Keychain only for secrets.
- Design CloudKit merging, offline queues, schema versioning, and deletion before
  enabling sync for a model.
- Prefer append-only attempt evidence and deterministic derived mastery where the
  accepted data decision supports it.

## Change discipline

Do not introduce giant view models, broad base classes, generic repository
abstractions without a use case, or one protocol per trivial value. Record
durable tradeoffs in `Docs/Architecture/`.
