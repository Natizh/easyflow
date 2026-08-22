# Development Plan

EasyFlow is implemented in large, bounded, end-to-end chunks. Each chunk defines scope, acceptance criteria, automated/manual verification, documentation updates, clear commits, and known gaps. `main` remains the integration branch and should remain buildable once code exists.

## Bootstrap: Repository truth

Status: complete when the initial documentation commit is created.

- Initialize Git and the canonical documentation hierarchy.
- Preserve all settled requirements and unresolved decisions.
- Add AGENTS.md, accepted ADRs, references/licensing notes, backlog, and ignore rules.
- Do not add product implementation, a license, a GitHub remote, `Package.swift`, or CI while their gates remain unresolved. Those initial gates were resolved after bootstrap: macOS 14 minimum, macOS 26 primary, private GitHub visibility, and MIT licensing.

Acceptance: a future agent can understand EasyFlow and begin Chunk A without the original bootstrap conversation or source file.

## Pre-Chunk-A gates

1. Use the settled macOS 14 minimum and macOS 26 primary target ([OQ-004](OPEN_QUESTIONS.md#oq-004-minimum-macos-deployment-target)).
2. Create a minimal SwiftPM executable target `EasyFlow` and `EasyFlowTests` with a real native app-shell boundary.
3. Run `swift package describe`, `swift build`, and `swift test`.
4. Commit as `chore: scaffold native macOS project`.
5. Add minimal GitHub Actions build/test CI only after local success and remote publication prerequisites are satisfied.

## Chunk A: Native macOS shell

Suggested branch: `feat/app-shell`

Status: implemented on the feature branch; automated checks complete and real-device GUI smoke evidence recorded separately before integration.

Implement:

- resident/invisible app lifecycle and AppKit/SwiftUI bridge;
- rightmost-display selection and far-right hot zone;
- event monitoring with approximately 300 ms intentional dwell;
- immediate accidental dismissal and focus-restoration foundation;
- coordinated Main and Secondary `NSPanel` infrastructure;
- responsive panel geometry without prematurely freezing OQ-008;
- overlay window level and fullscreen/Spaces behavior;
- pure activation/panel state machine with placeholder content;
- relevant state/timer tests and manual GUI smoke procedure.

Acceptance: EasyFlow launches, stays normally invisible, reveals Main through the preferred edge trigger, dismisses cleanly when abandoned, supports Secondary infrastructure, and remains available above fullscreen applications.

Do not add Reminders or the complete task UI merely to fill this chunk.

## Chunk B: Local workspace and persistence

Suggested branch: `feat/local-workspace`

Status: implemented and green on the feature branch; migration, reopen persistence, CRUD, ordering, completion, note movement/rollback, stable identity, relationships, and soft deletion are automated.

Implement:

- GRDB dependency, SQLite database, and versioned migrator;
- explicit repositories/services and observation;
- Main Task local metadata, effort, Description, lifecycle, and styles;
- one-level Steps with notes, completion, styles, and ordering;
- unified movable Notes model for inbox and attached ownership unless implementation evidence supports an equally safe documented schema;
- ordering/sort indexes, transactional reorder, soft deletion, and completion metadata;
- temporary database and pure domain tests.

Acceptance: EasyFlow-specific data can be created, updated, reordered, moved, completed, soft-deleted, and recovered after database restart without Apple Reminders.

## Chunk C: Complete local interaction UI

Continue on the bounded local-workspace branch or a dedicated child branch if review size requires it; do not create bureaucracy by default.

Implement:

- immediate Quick Note capture and contextual browser;
- generated display titles, editing, deletion, and local reorder;
- inline Main Task creation, effort display/edit, list, styles, and drag priority;
- task hover and immediate Task A → Task B context replacement;
- Description editor;
- Step CRUD, completion, reorder, notes, and styles;
- transactional Quick Note → Attached Note move and display below Steps;
- Recently Completed local UI;
- Settings gear and only the settings infrastructure backed by existing features;
- empty, loading, and local error states;
- UI/state tests and repeatable drag/focus/manual checks.

OQ-002, OQ-003, OQ-008, OQ-009, and OQ-010 must be resolved when they become blocking; no option is silently selected. OQ-001 is settled in `docs/UX_BEHAVIOR.md`.

Acceptance: EasyFlow is useful as a complete local current-work workspace before EventKit is enabled.

## Chunk D: Apple Reminders integration

Suggested branch: `feat/reminders-sync`

Implement:

- EventKit authorization states and first-run flow;
- discover/create the dedicated `EasyFlow` list;
- app-owned UUID ↔ external identifier mapping;
- initial import and conservative reconciliation;
- create, rename, complete, and delete mutations;
- external rename, completion, deletion, and new Reminder handling;
- coalesced EventKit change observation;
- disconnected, denied, ambiguous-list, identifier-loss, and error states;
- protocol-backed adapter, fakes, reconciliation tests, and a live manual plan.

Acceptance: Main Task title, completion, creation, and deletion stay coherent between EasyFlow and the dedicated list while every EasyFlow-specific field remains local.

## Chunk E: Production polish

Suggested branch: `feat/polish`

Implement/refine:

- minimal Settings and native launch at login;
- Standard appearance, Frosted where appropriate, and optional Liquid Glass only on supported versions;
- animation, focus, hover, pointer traversal, and panel sizing tuning;
- accessibility and reduced-motion behavior;
- onboarding, permission recovery, and error presentation;
- idle/resource profiling and performance fixes;
- application bundle, packaging, release build, and app lifecycle behavior;
- final regression suite, manual smoke checklist, and documentation refresh.

Acceptance: EasyFlow behaves like a polished native utility that can remain active through a Mac session without becoming intrusive or heavy.

## Test strategy across chunks

High-value automated coverage:

- task/Step/note order and drag-result logic;
- Step completion stability;
- Quick Note movement and rollback;
- soft deletion and retention-independent trash queries;
- all database migrations and reopen persistence;
- Reminder reconciliation through abstractions;
- activation and panel state machines using injected clocks;
- stale/cancelled async result handling.

Repeatable manual coverage:

- normal, maximized, fullscreen, and Spaces overlays;
- multiple-display geometry and arrangement changes;
- cursor traversal, animation, dismissal, and focus restoration;
- drag feel and visual indicators;
- real EventKit permission/list/iCloud behavior;
- launch at login and release-bundle behavior;
- CPU, wakeups, memory, and hidden-state activity.

Every completed chunk updates relevant canonical docs and ADRs, records known gaps, runs the strongest checks available, and ends in clear commits.

## GitHub and CI direction

The canonical GitHub repository is private at `https://github.com/Natizh/easyflow`, with `main` as the default/integration branch. Publication included tracked-file checks for secrets, private data, local databases, and machine paths before the initial push.

After the package builds, CI runs `swift build` and `swift test` on pull requests and pushes to `main` using a compatible GitHub-hosted macOS/Xcode environment. Lint, formatting, signing, packaging, and live EventKit tests are not bootstrap CI.
