# EasyFlow

EasyFlow is a lightweight macOS edge workspace that keeps the user's current working set one movement away. It is normally invisible, appears from the far-right edge of the rightmost display, and combines fast note capture with a locally enriched task view synchronized through a dedicated Apple Reminders list.

## Status

The repository bootstrap and Chunks A–C are implemented. The minimum deployment target is macOS 14, with macOS 26 as the primary development and experience target.

EasyFlow is MIT-licensed. The SwiftPM project and deterministic CI are configured. The app now provides the resident edge shell plus a restart-safe local GRDB workspace: Quick Notes, explicitly estimated Main Tasks, task details, Description, Steps and notes, Attached Notes, ordering, completion, Recently Completed, soft deletion, styling, drag/drop, and minimal Settings. Full Apple Reminders synchronization deliberately remains Chunk D.

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
- [`docs/testing/CHUNK_A_SMOKE_TEST.md`](docs/testing/CHUNK_A_SMOKE_TEST.md): repeatable real-device app-shell verification and current evidence.
- [`AGENTS.md`](AGENTS.md): operating rules for coding agents and contributors.

## Technology and project structure

EasyFlow is a native macOS application using Swift, SwiftUI, AppKit, EventKit, ServiceManagement, SQLite, and GRDB. SwiftUI owns view composition; AppKit owns overlay-window, edge-monitoring, fullscreen/Spaces, and precision focus behavior.

The SwiftPM layout grows by implemented responsibility:

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

Empty placeholder directories are not tracked. EventKit authorization and ServiceManagement launch-at-login boundaries are compiled but are not yet connected to full product flows. Reminders synchronization remains Chunk D; local persistence remains Chunk B.

## Build and test

Requirements: macOS 14 or later and a Swift 6 toolchain/Xcode capable of building the package.

```sh
swift package resolve
swift build
swift test
swift run EasyFlow
```

`swift run EasyFlow` launches the resident accessory process and usable local-only workspace. Release packaging, signing, launch-at-login activation, and live Reminders flows are later work.

GitHub Actions runs deterministic build and test checks on pushes to `main` and pull requests.

The automated Chunk A suite covers state transitions, timing commands, display selection, responsive geometry, traversal, AppKit window configuration, and prepared EventKit/ServiceManagement boundaries. Physical pointer activation, focus restoration, fullscreen, Spaces, and multi-display behavior require the manual checklist; compilation is not treated as proof of those behaviors.

## Development workflow

`main` is the integration branch and should remain buildable once code exists. Substantial features use bounded branches; coherent work rounds are verified, documented, and committed using conventional-style messages. See `AGENTS.md` before changing the repository.

## Current decisions and open work

The canonical GitHub repository is the private [`Natizh/easyflow`](https://github.com/Natizh/easyflow) remote. `main` is the integration/default branch and GitHub Actions verifies build and tests after pushes and pull requests. Remaining product-level decisions are retained in `docs/OPEN_QUESTIONS.md`; implementation must not silently resolve questions outside the active chunk.
