# ADR-002: GRDB Local Storage

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

EasyFlow owns relational local metadata for Main Tasks, Steps, Quick/Attached Notes, styles, ordering, completion, soft deletion, settings, and external Reminder mappings. Data must survive upgrades and remain easy to inspect and test.

## Decision

Use SQLite through GRDB for v1 persistence. Define an explicit versioned schema and migrations, use app-owned UUIDs, expose focused repositories/observations, and test migration and lifecycle behavior. Do not wipe production data on schema changes.

## Alternatives considered

- **SwiftData:** rejected for v1 because EasyFlow prioritizes explicit schemas, predictable migrations, inspection, and update semantics.
- **Core Data:** capable but adds a different abstraction model without a product-driven benefit over the chosen explicit GRDB approach.
- **Flat files/UserDefaults:** unsuitable for relational children, ordering, observation, soft deletion, and migrations.
- **Remote database:** rejected by local-first scope and the absence of a backend.

## Consequences

- The project adds GRDB after the deployment target/package scaffold is approved.
- Schema, indexes, queries, and transaction boundaries remain visible and testable.
- Migrations require ongoing versioned tests.
- The data layer should stay small and explicit rather than becoming an enterprise abstraction stack.
