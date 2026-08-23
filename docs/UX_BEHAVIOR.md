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

## Quick Note keyboard and data-safety semantics

[OQ-001](OPEN_QUESTIONS.md#oq-001-quick-note-keyboard-semantics) is resolved as follows:

- Intentional activation places keyboard focus in the Quick Note composer without a click.
- `Return` inserts a newline, matching a native multiline notes editor.
- `Command+Return` explicitly commits the non-empty note to the inbox and resets the composer for another capture.
- While typing, the non-empty composer is persisted as one debounced draft rather than creating duplicate inbox notes.
- When EasyFlow closes or the composer loses focus, a non-whitespace draft is committed automatically; an empty/whitespace-only draft is discarded.
- Relaunch restores an interrupted persisted draft until it has been committed.

The persistence mechanics arrive with the local workspace chunk. Chunk A establishes intentional focus and semantic submit/focus-loss hooks without pretending notes are already stored. This design keeps ordinary `Return` behavior native, gives power users an explicit fast commit, and protects capture from accidental dismissal, focus changes, or process interruption.

## Main and Secondary Panels

- Main opens first from the right edge.
- Secondary opens immediately to Main's left when Quick Notes or a Main Task becomes contextual.
- Only one Secondary Panel exists. Its content changes in place rather than closing and reopening or spawning overlapping windows.
- Main and Secondary overlay the current application and never resize or shift it.
- The panels must remain available over maximized/fullscreen applications and across Spaces.
- Each panel uses 20% of display width clamped to 360–520 points, with an 8-point outer margin/gap. These width constants remain subject only to evidence-based prototype tuning under [OQ-008](OPEN_QUESTIONS.md#oq-008-panel-width-constraints).
- Real-device feedback replaces the original 12-point vertical inset with 8% of display height clamped to 64–96 points. Main and Secondary share identical vertical alignment and height, leaving a clearly visible band above and below.
- Main visually slides from and back into the right edge. Secondary slides left from Main and retracts toward it. Context replacement within a visible Secondary updates in place without replaying the entrance transition. Current development motion may remain restrained; final spring, duration, opacity/material interpolation, and reduced-motion tuning belong to Production Polish.

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

Quick Notes and every visible Main Task row are full contextual hover surfaces. The AppKit capture editor emits native hover entry. Secondary opens above Main at a nonzero visible start alpha, settles entirely inside the selected display directly left of Main, and content replacement never replays entrance.

Task hover uses no debounce (`0 ms`) and replaces Secondary content immediately. [OQ-010](OPEN_QUESTIONS.md#oq-010-main-task-hover-debounce) is resolved unless measured flicker later justifies a documented change.

## Closing behavior

An immediately abandoned activation closes Main immediately or effectively immediately; do not impose a one-second dismissal delay.

After meaningful Secondary interaction, Secondary receives 250 ms of re-entry grace and closes first; Main closes 180 ms later. An engaged Main without Secondary uses 180 ms. These values resolve [OQ-009](OPEN_QUESTIONS.md#oq-009-closing-grace-interval) for Chunk A. Pointer re-entry cancels pending close tasks. The 8-point panel gap belongs to the combined interaction bridge so the user does not fight dismissal while traversing.

## Quick Notes interaction

- Intentional activation routes typing to the capture field.
- Capture uses an AppKit-backed `NSTextView`/`NSScrollView` with system body typography, a 10×9-point text-container inset, zero line-fragment padding, native selection/IME behavior, and no independent fake caret geometry.
- Committed notes appear immediately below the composer in a bounded compact inbox and remain available in the Secondary browser.
- The browser shows generated/explicit title, creation date/time, and identifying preview.
- Opening supports reading and editing without changing the underlying body merely to generate a label.
- Notes can be deleted and reordered locally.
- A drag from the inbox to a Main Task moves the existing note into Attached Notes only after a successful drop.
- A failed or cancelled drop leaves the note unchanged in the inbox.
- A successful drop preserves stable identity, body, timestamps/history where sensible, and assigns ownership to the target task.

## Main Task creation and editing

- `+ New Task` starts a compact inline title flow.
- Do not introduce a modal creation form.
- The inline composer requires a non-empty title plus an explicit compact `1...4` effort choice. There is no hidden default; this resolves [OQ-002](OPEN_QUESTIONS.md#oq-002-effort-during-main-task-creation).
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

Internal reorder uses direct local gestures and a thin insertion bar at an exact collection boundary. It never highlights a row as a container or uses copy-style `NSItemProvider` semantics. Only Quick Note attachment uses a cross-window payload and target-row highlight.

For Main Tasks, the title/body region—not a tiny grip—is the direct reorder surface. A 4-point movement threshold separates click from drag. Checkbox and effort controls remain outside that gesture; right-click context menus, hover, scrolling, and note attachment remain available.

## Settings dismissal

Settings provides a visible `Done` control, Escape dismissal, and Command+W dismissal. While presented, Settings holds the EasyFlow interaction open; closing returns to Main and re-evaluates the pointer state rather than trapping or orphaning focus.

## Completion and deletion interaction

- Completing a Step checks and dims it without moving or hiding it.
- Completing a Main Task removes it from active tasks and adds it to Recently Completed while synchronizing completion.
- Recently Completed presents a small bounded view without destroying older local history. Restore behavior is unresolved under [OQ-003](OPEN_QUESTIONS.md#oq-003-restore-from-recently-completed).
- Deleting a Main Task must make the external deletion consequence clear enough to avoid surprise, then delete the Reminder and soft-delete local context.
- Quick Note deletion should protect against accidental loss without turning trash into a heavy workflow.

## Reminders exceptional state

Normal synchronization is quiet. Settings shows only Connected, Needs Access, Synchronizing, Access Denied, ambiguity, or error/retry state. Tasks imported from Reminders show a compact `?` with “Effort not set”; Task Detail offers `1...4`, and assignment remains local.

For unrated imports, Task Detail displays `Set effort` and four immediate buttons. Assignment updates Main presentation and persistence only; it never marks synchronized title/completion pending.

`Recently Completed` renders at most three tasks, ordered by completion time descending with stable UUID tie ordering. This presentation limit does not purge history and does not resolve restore behavior.

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
