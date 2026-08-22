# EasyFlow

EasyFlow is a lightweight macOS edge workspace that keeps the user's current working set one movement away. It is normally invisible, appears from the far-right edge of the rightmost display, and combines fast note capture with a locally enriched task view synchronized through a dedicated Apple Reminders list.

## Status

The repository bootstrap is complete and native application implementation is underway. The minimum deployment target is macOS 14, with macOS 26 as the primary development and experience target.

EasyFlow is MIT-licensed. The Swift project, deterministic CI, private GitHub publication, and native app-shell vertical slice are the current implementation round.

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

## Current decisions and open work

The GitHub repository is private. Publication uses the single unambiguous authenticated GitHub owner once authentication is available. Remaining product-level decisions are retained in `docs/OPEN_QUESTIONS.md`; implementation must not silently resolve questions outside the active chunk.
