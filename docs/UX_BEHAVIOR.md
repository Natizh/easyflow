# UX Behavior

This document defines interaction behavior and state transitions. Product scope belongs in `PRODUCT_SPEC.md`; platform structure belongs in `docs/ARCHITECTURE.md`.

## Interaction regions

- **Activation hot zone:** a deliberately narrow strip at the outer right edge of the rightmost display.
- **Main Panel region:** the primary EasyFlow surface at the screen edge.
- **Secondary Panel region:** a contextual surface directly left of Main.
- **Grace region:** the combined traversal area and short-lived state used to prevent dismissal while the pointer legitimately moves between panels.

The preferred rightmost display is the screen with the greatest desktop-coordinate `frame.maxX`. A per-current-display edge is only an explicitly documented fallback after the preferred behavior is attempted and found technically infeasible.

## Activation state machine

| State | Entry | Behavior | Exit |
| --- | --- | --- | --- |
| Hidden | App resident; no visible UI | Minimal idle activity; observe edge entry without a high-frequency render loop | Pointer enters hot zone → `PotentialActivation` |
| PotentialActivation | Pointer enters narrow hot zone | Start approximately 300 ms dwell; do not expose UI or take focus on a mere crossing | Dwell completes → `MainVisible`; pointer exits → `Hidden` |
| MainVisible | Intentional dwell completed | Reveal Main Panel and prepare Quick Note input | Pointer immediately abandons → `Hidden`; context hover → `SecondaryVisible`; editing/drag/settings → `Interacting` |
| SecondaryVisible | Quick Notes or Main Task context active | Keep Main open; show one contextual Secondary Panel | Context changes → update in place; return to empty Main area → collapse Secondary; leave all regions after grace → staged closing |
| Interacting | Keyboard, click, edit, drag, or Settings interaction begins | Do not dismiss while the user is interacting; cancel stale hover/close timers | Interaction ends → appropriate visible state; explicit/qualified exit → staged closing |
| StagedClosing | Pointer leaves after genuine Secondary interaction | Close Secondary first, then Main after a short grace interval under one second | Re-entry → cancel closing; timers complete → `Hidden` |

The 300 ms value is an edge-activation protection only. It is not a task-hover delay.

## Intentional focus and restoration

After intentional activation, keyboard input goes directly to the Quick Note capture field without an extra click. Focus must not move during `PotentialActivation`; a transient pointer crossing must never steal keystrokes from Safari, Xcode, Terminal, or another application.

The window coordinator records the previously active application/window before activation. If EasyFlow takes focus and the interaction is immediately abandoned, it restores the prior context where macOS permits this without disruptive hacks. A real EasyFlow interaction may follow normal activation behavior. Exact AppKit calls and failure handling must be documented during Chunk A and covered by repeatable manual tests.

Quick Note commit and multiline behavior is unresolved in [OQ-001](OPEN_QUESTIONS.md#oq-001-quick-note-keyboard-semantics).

## Main and Secondary Panels

- Main opens first from the right edge.
- Secondary opens immediately to Main's left when Quick Notes or a Main Task becomes contextual.
- Only one Secondary Panel exists. Its content changes in place rather than closing and reopening or spawning overlapping windows.
- Main and Secondary overlay the current application and never resize or shift it.
- The panels must remain available over maximized/fullscreen applications and across Spaces.
- Panel targets are roughly one fifth of the display each; exact responsive bounds remain open in [OQ-008](OPEN_QUESTIONS.md#oq-008-panel-width-constraints).

## Context switching

| Pointer transition | Required result |
| --- | --- |
| Hidden → edge dwell | Reveal Main after intentional dwell |
| Quick Notes area → Secondary | Show Quick Notes browser |
| Main Task A → Secondary | Show Task A details |
| Task A → Task B | Keep both panels open and replace A with B immediately |
| Quick Notes → Task | Reuse Secondary and replace browser with task details |
| Task → Quick Notes | Reuse Secondary and replace details with browser |
| Secondary → another Main Task | Keep Main open and switch context |
| Secondary → empty/non-contextual Main area | Collapse Secondary; keep Main open |
| Main ↔ Secondary traversal | Do not dismiss during legitimate traversal |

Task hover should feel immediate. A tiny evidence-based anti-flicker debounce is allowed but unresolved under [OQ-010](OPEN_QUESTIONS.md#oq-010-main-task-hover-debounce).

## Closing behavior

An immediately abandoned activation closes Main immediately or effectively immediately; do not impose a one-second dismissal delay.

After meaningful Secondary interaction, the intended staged close is Secondary first and Main shortly afterward. The grace interval is below one second and remains unresolved under [OQ-009](OPEN_QUESTIONS.md#oq-009-closing-grace-interval). Pointer re-entry cancels pending close timers. Hit regions and grace behavior must avoid gaps that force the user to fight the panels.

## Quick Notes interaction

- Intentional activation routes typing to the capture field.
- The browser shows generated/explicit title, creation date/time, and identifying preview.
- Opening supports reading and editing without changing the underlying body merely to generate a label.
- Notes can be deleted and reordered locally.
- A drag from the inbox to a Main Task moves the existing note into Attached Notes only after a successful drop.
- A failed or cancelled drop leaves the note unchanged in the inbox.
- A successful drop preserves stable identity, body, timestamps/history where sensible, and assigns ownership to the target task.

## Main Task creation and editing

- `+ New Task` starts a compact inline title flow.
- Do not introduce a modal creation form.
- Effort is mandatory conceptually, but when and how it is selected remains unresolved under [OQ-002](OPEN_QUESTIONS.md#oq-002-effort-during-main-task-creation).
- Hover reveals Description, Steps, then Attached Notes in Secondary.
- Title, Description, effort, style, Step content, and Attached Notes remain editable through low-friction native controls.

## Reordering quality bar

Main Tasks, Steps, and retained Quick Note ordering use stable row identity and local sort order. Dragging must provide:

- immediate or near-immediate pickup;
- a clear destination indicator;
- smooth movement without accidental text selection;
- no janky full-list rerendering;
- a single persistence commit on release where practical;
- cancellation that leaves the original order intact.

Use a direct drag gesture when it materially improves responsiveness over macOS system drag behavior.

## Completion and deletion interaction

- Completing a Step checks and dims it without moving or hiding it.
- Completing a Main Task removes it from active tasks and adds it to Recently Completed while synchronizing completion.
- Recently Completed presents a small bounded view without destroying older local history. Restore behavior is unresolved under [OQ-003](OPEN_QUESTIONS.md#oq-003-restore-from-recently-completed).
- Deleting a Main Task must make the external deletion consequence clear enough to avoid surprise, then delete the Reminder and soft-delete local context.
- Quick Note deletion should protect against accidental loss without turning trash into a heavy workflow.

## Appearance and accessibility

Use native typography, SF Symbols, adaptive contrast, macOS materials, restrained animation, context menus, continuous corners, and light/dark mode. Standard appearance is the baseline; newer Liquid Glass behavior is optional when available. Controls, focus indicators, VoiceOver labels, keyboard navigation where appropriate, reduced motion, and sufficient contrast are part of production polish.

## Manual smoke scenarios

Chunk A and later GUI work must document repeatable tests for:

1. edge crossing shorter than the dwell does nothing and does not steal focus;
2. an intentional dwell reveals Main and accepts typing;
3. immediate abandonment restores the previous context and closes promptly;
4. Task A → Task B and Quick Notes ↔ Task switches Secondary in place;
5. traversal between panels never crosses an unintended dismissal gap;
6. overlays work over normal, maximized, fullscreen, and multiple Spaces;
7. the correct rightmost display is selected for varied display arrangements;
8. drag pickup, cancellation, drop indicators, and persistence remain fluid;
9. light/dark mode, reduced motion, and accessibility behavior remain usable.
