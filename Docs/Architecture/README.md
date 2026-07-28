# Architecture decision records

Architecture decision records capture durable choices that affect more than one
work packet. Accepted records take precedence over execution plans.

## Statuses

- **Proposed** — under review and not yet binding.
- **Accepted** — the active project decision.
- **Superseded** — replaced by a newer record.
- **Rejected** — considered and deliberately not selected.

## Records

| Record | Status | Decision |
|---|---|---|
| [ADR-000](ADR-000-repository-baseline.md) | Accepted | Repository baseline, platform, naming, signing, and test conventions |
| [ADR-001](ADR-001-product-architecture.md) | Accepted | Product architecture, explicit composition, typed production routing, and root-state boundaries |
| [ADR-002](ADR-002-local-learning-persistence.md) | Accepted | Local SwiftData learning evidence and file-storage split; CloudKit remains deferred |
| ADR-003 | Planned | CloudKit sync and conflict resolution |
| ADR-004 | Planned | Competency graph and mastery model |
| [ADR-005](ADR-005-foundation-models-provider.md) | Proposed | Foundation Models provider abstraction; Packet 000-A device decision pending |
| ADR-006 | Planned | Retrieval and indexing approach |
| ADR-007 | Planned | Generated-content trust and validation |
| ADR-008 | Planned | Code-execution capability levels |
| ADR-009 | Planned | Source licensing and private imports |
| ADR-010 | Planned | Gamification economy and anti-blocking rules |
| ADR-011 | Planned | Prompt versioning and model-update testing |
| ADR-012 | Planned | Open-source code versus content repositories |

Use [ADR-TEMPLATE.md](ADR-TEMPLATE.md) for new records.
