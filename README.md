# EasyFlow

EasyFlow is a lightweight macOS edge workspace that keeps the user's current working set one movement away. It is normally invisible, appears from the far-right edge of the rightmost display, and combines fast note capture with a locally enriched task view synchronized through a dedicated Apple Reminders list.

## Status

The repository is in the documentation bootstrap phase. Product behavior, architectural boundaries, development stages, and unresolved decisions are recorded, but the application has not been implemented.

The Swift package is intentionally absent until the minimum macOS deployment target is approved. CI will be added only after the initial Swift project builds locally. No GitHub remote or license is configured yet.

## Repository guide

- [`PRODUCT_SPEC.md`](PRODUCT_SPEC.md): canonical product scope and v1 requirements.
- [`docs/UX_BEHAVIOR.md`](docs/UX_BEHAVIOR.md): interaction states, focus, hover, panels, and drag behavior.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): intended native macOS architecture and dependency boundaries.
- [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md): local entities, ordering, lifecycle, and migrations.
- [`docs/REMINDERS_SYNC.md`](docs/REMINDERS_SYNC.md): EventKit boundary and reconciliation requirements.
- [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md): unresolved product and engineering decisions.
- [`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md): bounded implementation chunks and acceptance criteria.
- [`docs/BACKLOG.md`](docs/BACKLOG.md): deferred ideas and explicit v1 exclusions.
- [`docs/decisions/`](docs/decisions/): accepted architectural decision records.
- [`docs/references/REFERENCE_PROJECTS.md`](docs/references/REFERENCE_PROJECTS.md): external references and licensing boundaries.
- [`AGENTS.md`](AGENTS.md): operating rules for coding agents and contributors.

## Intended technology

EasyFlow is planned as a native macOS application using Swift, SwiftUI, AppKit, EventKit, ServiceManagement, SQLite, and GRDB. SwiftUI owns view composition; AppKit owns overlay-window, edge-monitoring, fullscreen/Spaces, and precision focus behavior.

The intended SwiftPM layout, once the deployment target is approved, is:

```text
Package.swift
Sources/EasyFlow/
  App/
  Windows/
  Edge/
  Models/
  Database/
  Reminders/
  Views/
  Settings/
  Utilities/
Tests/EasyFlowTests/
```

Empty placeholder directories are not tracked. The first implementation stage is the native macOS shell described in the development plan.

## Development workflow

`main` is the integration branch and should remain buildable once code exists. Substantial features use bounded branches; coherent work rounds are verified, documented, and committed using conventional-style messages. See `AGENTS.md` before changing the repository.

## Unresolved prerequisites

The minimum deployment target, GitHub visibility and owner, and project license remain undecided. These gates must be resolved before creating the Swift manifest, publishing the remote repository, or adding a license. All product-level unresolved decisions are retained in `docs/OPEN_QUESTIONS.md`.
