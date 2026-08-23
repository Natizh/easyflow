# EasyFlow Agent Contract

This file is the operational contract for AI coding agents and contributors. Repository documents and Git history are EasyFlow's durable memory; conversation context is not a substitute.

## Before editing

1. Run `git status -sb` and preserve every unrelated or user-authored change.
2. Read `PRODUCT_SPEC.md` and the documents relevant to the requested subsystem.
3. Inspect the existing source, tests, and Git history before changing behavior.
4. Confirm the work belongs to the requested release. Do not expand scope without approval.

## Sources of truth

- Product behavior belongs in `PRODUCT_SPEC.md`.
- Exact interaction and state transitions belong in `docs/UX_BEHAVIOR.md`.
- Implementation boundaries belong in `docs/ARCHITECTURE.md`.
- Persistence and lifecycle rules belong in `docs/DATA_MODEL.md`.
- EventKit behavior belongs in `docs/REMINDERS_SYNC.md`.
These tracked canonical documents are authoritative. A local `.agent-context/` directory may contain historical plans, testing notes, decision records, or reference research. Nothing in `.agent-context/` overrides the tracked documentation, source, or tests, and a fresh clone must remain understandable without it.

When implementation reveals a real constraint, do not silently diverge. Update the relevant canonical document and preserve rationale in the commit history.

## Work rounds and branches

- Keep each round focused on one coherent product or engineering outcome. Large, bounded, end-to-end chunks are encouraged; unrelated changes are not.
- Keep `main` as the integration branch and buildable once code exists.
- Use a bounded branch for substantial work.
- Use worktrees only when independent work is genuinely running in parallel.
- Small documentation corrections do not require branch bureaucracy.
- End completed file-changing rounds with understandable, reversible conventional commits such as `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, or `chore:`.
- Do not rewrite published history, force-push, or run destructive reset/checkout operations without explicit user approval.

## Implementation boundaries

- Do not add a server, account system, web runtime, collaboration, analytics, telemetry, or any other out-of-scope feature.
- Preserve the native stack: SwiftUI for content and AppKit for platform-specific panels, edge activation, window levels, Spaces, fullscreen, and focus.
- Use SQLite with GRDB for EasyFlow-owned state. Do not replace it with SwiftData without an approved ADR.
- Treat Apple Reminders as the cross-device store only for Main Task title, completion, and existence. EasyFlow ordering and enriched workspace data stay local.
- Keep an app-owned UUID as local identity; an EventKit identifier is an external mapping, never the sole primary key.
- Prefer event-driven behavior and low idle resource use. Performance regressions in the hidden state are product bugs.
- Do not log user task/note bodies in production or commit local databases, Reminder data, secrets, or machine-specific paths.

## Quality requirements

Run the strongest relevant checks before finishing:

- `swift build` and `swift test` once the package exists;
- focused unit/integration tests for changed logic;
- migration tests for persistence changes;
- manual smoke procedures for overlay, fullscreen, Spaces, pointer, focus, animation, launch-at-login, and live EventKit behavior;
- `git diff --check` and documentation-link checks for documentation rounds.

Automated logic should cover sorting/reordering, completion, note movement, soft deletion, migrations, persistence, reminder reconciliation through fakes, and the panel/activation state machine. GUI behavior that cannot be reliable in unit tests must receive repeatable manual verification instructions.

## User experience invariants

- Position is priority for Main Tasks and Steps; there is no separate priority number.
- Effort is a Main Task work estimate from 1 through 4 and is unrelated to priority.
- A Quick Note dragged onto a Main Task moves into Attached Notes; it is not copied or concatenated into the Description.
- Completed Steps remain visible and in position. Completed Main Tasks leave the active list for Recently Completed.
- Edge activation targets the outer right edge of the rightmost display with an approximately 300 ms dwell. The dwell does not automatically apply to task hover.
- The Main Panel and one contextual Secondary Panel form a coordinated surface. Do not add unrelated windows for notes or details.
- Accidental opening dismisses immediately; legitimate movement between panels must not fight timers.

## References and licensing

External projects are references, not product specifications. Verify their current repository license before reusing source and record any reuse. Tic was previously identified as MIT, while Atoll is GPL-3.0 and must not donate source because EasyFlow's MIT license is not a compatible path for incorporating GPL source into this project. Proprietary products may provide behavioral inspiration only.
