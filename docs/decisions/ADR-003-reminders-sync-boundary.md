# ADR-003: Apple Reminders Sync Boundary

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

The user wants Main Tasks available across Apple devices without operating an EasyFlow server. The richer EasyFlow workspace includes ordering, effort, styles, Description, Steps, Notes, and trash state that do not need cross-device representation.

## Decision

Use one dedicated Apple Reminders list named `EasyFlow`. Synchronize only Main Task title, completion, and existence/deletion. Keep ordering/priority, effort, style, Description, Steps, Attached Notes, Quick Notes, trash, and UI state local. Do not depend on Reminders folders/groups or attempt to mirror EasyFlow ordering.

Give every Main Task an app-owned UUID and treat EventKit identifiers as replaceable external mappings. Reconciliation must be conservative when identifiers or reminders disappear.

## Alternatives considered

- **Synchronize all EasyFlow fields through Reminder metadata:** rejected because it distorts the deliberate product boundary and couples local behavior to external fields.
- **Custom EasyFlow cloud/server:** rejected by v1 local-first scope and operational burden.
- **No cross-device synchronization:** rejected because Main Task availability across Apple devices is a core requirement.
- **Reminders folders/groups:** rejected because EventKit list/calendar concepts are the required boundary.

## Consequences

- Main Task mutations and external changes require an EventKit adapter and reconciliation layer.
- EasyFlow works locally when authorization is unavailable where technically reasonable, while clearly representing unsynchronized state.
- Loss of an EventKit identifier cannot trigger destructive local metadata deletion.
- Tests use adapter fakes; live iCloud behavior still requires manual coverage.
