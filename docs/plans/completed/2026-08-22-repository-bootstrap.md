# Repository Bootstrap Plan

Status: Completed by the initial repository bootstrap commit.

## Objective

Transform the original EasyFlow master bootstrap source into an empty-repository foundation that preserves product intent without implementing the application or silently resolving open choices.

## Deliverables

- Git repository on `main` with Swift/macOS ignore rules.
- Canonical product, UX, architecture, data, Reminders, backlog, development, and open-question documentation.
- Accepted ADRs for the native stack, GRDB, Reminders boundary, edge activation, and repository memory.
- AGENTS.md operational contract.
- Reference-project and licensing boundaries.
- Documented SwiftPM layout and CI/publication direction, gated by unresolved prerequisites.

## Traceability matrix

| Bootstrap source | Canonical destination |
| --- | --- |
| 0, 69–82 | README, AGENTS, development plan, this completed plan |
| 1–5, 9–35, 40–46, 67–68, 78 | PRODUCT_SPEC and backlog |
| 6–8, 23, 38–39, 55–57, 75 | UX behavior and open questions |
| 37, 43–51, 76–77 | Architecture and ADRs |
| 12, 16, 27, 31, 34–35, 47–49 | Data model |
| 17–19, 33–37, 44 | Reminders sync |
| 52–53 | Reference projects and open license question |
| 59–66, 69–74 | AGENTS, development plan, README |
| 54–58, 79 | Open questions and cross-links in domain docs |

## Required invariants audited

- Position remains priority; effort remains a separate `1...4` estimate.
- Quick Note assignment is a move preserving identity/content, not a copy.
- Completed Steps remain visible and ordered; completed Main Tasks enter Recently Completed.
- EasyFlow deletion removes the Reminder and soft-deletes local context.
- Only Main Task title, completion, and existence synchronize.
- The preferred trigger is the outer right edge of the rightmost display.
- Approximately 300 ms applies to edge activation, not task hover.
- Main and one contextual Secondary Panel form the complete overlay surface.
- SQLite/GRDB is selected; SwiftData is not the v1 persistence architecture.
- Liquid Glass is optional, and the baseline remains available on the approved minimum OS.
- V1 has no custom server, account, telemetry, analytics, or extra integration.

## Deliberate gates

- `Package.swift` and source scaffold wait for the minimum macOS target.
- GitHub publication waits for valid authentication, owner, and visibility.
- CI waits for a locally buildable Swift package and a compatible runner choice.
- `LICENSE` waits for an explicit license decision.

The source master file is not copied wholesale into the repository; these canonical documents replace it as durable project truth.
