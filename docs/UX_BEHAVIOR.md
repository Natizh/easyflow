# UX Behavior

This document defines interaction behavior and state transitions. Product scope belongs in `PRODUCT_SPEC.md`; platform structure belongs in `docs/ARCHITECTURE.md`.

## Interaction regions

- **Activation hot zone:** a deliberately narrow strip at the outer right edge of the rightmost display.
- **Main Panel region:** the primary EasyFlow surface at the screen edge.
- **Secondary Panel region:** a contextual surface directly left of Main.
- **Grace region:** the combined traversal area and short-lived state used to prevent dismissal while the pointer legitimately moves between panels.

The rightmost display is the screen with the greatest desktop-coordinate `frame.maxX`. EasyFlow does not install activation edges on other displays.

## Activation state machine

| State | Entry | Behavior | Exit |
| --- | --- | --- | --- |
| Hidden | App resident; no visible UI | Minimal idle activity; observe edge entry without a high-frequency render loop | Pointer enters hot zone → `PotentialActivation` |
| PotentialActivation | Pointer enters narrow hot zone | Start approximately 300 ms dwell; do not expose UI or take focus on a mere crossing | Dwell completes → `MainVisible`; pointer exits → `Hidden` |
| MainVisible | Intentional dwell completed | Reveal Main Panel and prepare Quick Note input | Pointer immediately abandons → `Hidden`; context hover → `SecondaryVisible`; editing/drag/settings → `Interacting` |
| SecondaryVisible | Quick Notes or Main Task context active | Keep Main open; show one contextual Secondary Panel | Context changes → update in place; explicit collapse strip above Recently Completed → collapse Secondary; leave all regions after grace → staged closing |
| Interacting | Keyboard, click, edit, drag, or Settings interaction begins | Do not dismiss while the user is interacting; cancel stale hover/close timers | Interaction ends → appropriate visible state; explicit/qualified exit → staged closing |
| StagedClosing | Pointer leaves after genuine Secondary interaction | Close Secondary first, then Main after a short grace interval under one second | Re-entry → cancel closing; timers complete → `Hidden` |

The 300 ms value is an edge-activation protection only. It is not a task-hover delay.

## Intentional focus and restoration

After intentional activation, keyboard input goes directly to the Quick Note capture field without an extra click. Focus must not move during `PotentialActivation`; a transient pointer crossing must never steal keystrokes from Safari, Xcode, Terminal, or another application.

The window coordinator records the previously active application before activation. If EasyFlow takes focus and the interaction is immediately abandoned, it restores the prior application where macOS permits. A real EasyFlow interaction follows normal activation behavior.

## Quick Note keyboard and data-safety semantics

- Intentional activation places keyboard focus in the Quick Note composer without a click.
- Post-v1 polish: `Return` explicitly commits the non-empty note to the inbox, resets the composer, and leaves it ready for another capture. `Command+Return` may remain an equivalent submit path.
- The Quick Note composer is quick-capture text, not paragraph composition; `Return` does not insert a newline into the saved note.
- While typing, the non-empty composer is persisted as one debounced draft rather than creating duplicate inbox notes.
- When EasyFlow closes or the composer loses focus, a non-whitespace draft is committed automatically; an empty/whitespace-only draft is discarded.
- Relaunch restores an interrupted persisted draft until it has been committed.

These semantics keep ordinary capture fast and protect typed drafts from accidental dismissal, focus changes, or process interruption.

## Main and Secondary Panels

- Main opens first from the right edge.
- Secondary opens immediately to Main's left when Quick Notes or a Main Task becomes contextual.
- Only one Secondary Panel exists. Its content changes in place rather than closing and reopening or spawning overlapping windows.
- Main and Secondary overlay the current application and never resize or shift it.
- The panels must remain available over maximized/fullscreen applications and across Spaces.
- Each panel uses 20% of display width clamped to 360–520 points, with an 8-point outer margin/gap.
- The vertical inset is 8% of display height clamped to 64–96 points. Main and Secondary share identical vertical alignment and height, leaving a clearly visible band above and below.
- Main visually slides from and back into the right edge. Secondary slides left from Main and retracts toward it with calmer independent timing: about 0.28 seconds to open and 0.35 seconds to close. Context replacement within a visible Secondary updates in place without replaying the entrance transition. Reduce Motion uses immediate frame changes.

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
| Secondary → empty/non-contextual Main area | Keep Secondary open |
| Secondary → invisible collapse strip above Recently Completed | Collapse Secondary; keep Main open |
| Main ↔ Secondary traversal | Do not dismiss during legitimate traversal |

The AppKit Main-context router owns this distinction. Quick Notes and task row rectangles are contextual. Empty background, section/footer space, gaps, and other non-owned areas do not clear Secondary. One invisible horizontal strip immediately above Recently Completed emits the central `clearSecondary` event; `clearSecondary` transitions to engaged Main and issues only `hideSecondary`. Narrow gaps between adjacent task rows and leftward movement through the Main edge toward Secondary are traversal regions, so they never collapse the panel mid-crossing.

Quick Notes and every visible Main Task row are full contextual hover surfaces. The AppKit capture editor emits native hover entry. Secondary opens above Main at a nonzero visible start alpha, settles entirely inside the selected display directly left of Main, and content replacement never replays entrance.

Main Task contextual hover is resolved from AppKit `mouseMoved` against the current rendered row frames; it does not depend on SwiftUI hover delivery. Repeated movement within one row is deduplicated, A→B emits one replacement, and leaving rows toward the bridge does not clear Secondary.

Task hover uses no debounce (`0 ms`) and replaces Secondary content immediately.

## Closing behavior

An immediately abandoned activation closes Main immediately or effectively immediately; do not impose a one-second dismissal delay.

After meaningful Secondary interaction, Secondary receives 250 ms of re-entry grace and closes first; Main closes 180 ms later. An engaged Main without Secondary uses 180 ms. Pointer re-entry cancels pending close tasks. The 8-point panel gap belongs to the combined interaction bridge so the user does not fight dismissal while traversing.

## Quick Notes interaction

- Intentional activation routes typing to the capture field.
- Capture uses an AppKit-backed `NSTextView`/`NSScrollView` with system body typography, a 10×9-point text-container inset, zero line-fragment padding, native selection/IME behavior, and no independent fake caret geometry.
- Committed notes appear immediately below the composer in a bounded compact inbox and remain available in the Secondary browser.
- The browser shows generated/explicit title, creation date/time, and identifying preview.
- Opening supports reading and editing without changing the underlying body merely to generate a label.
- Quick Note and Attached Note cards use one visible editable title. If no explicit title exists, that title is derived from the first three meaningful body words and updates as the body changes.
- Notes can be deleted and reordered locally.
- A drag from the inbox to a Main Task moves the existing note into Attached Notes only after a successful drop.
- A failed or cancelled drop leaves the note unchanged in the inbox.
- A successful drop preserves stable identity, body, timestamps/history where sensible, and assigns ownership to the target task.

## Main Task creation and editing

- `+ New Task` starts a compact inline title flow.
- Do not introduce a modal creation form.
- The inline composer requires a non-empty title plus an explicit compact `1...4` effort choice. There is no hidden default.
- Post-v1 polish: opening the New Task composer focuses the title field immediately. Pressing Return with a non-empty title moves keyboard focus to effort selection without creating the task. While that effort-selection state is active, number keys `1` through `4` select effort and create the task; other numbers are ignored and the shortcuts are not active in any other text input. The visual focus indication wraps only the four selectable effort choices, not the static `Effort` label or `Add` button.
- Hover reveals Description, Steps, then Attached Notes in Secondary.
- Title, Description, effort, style, Step content, and Attached Note title/body content remain editable through low-friction native controls.

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

Compact Quick Note rows have no grip or arrow-only target. AppKit captures the row drag: movement within the inbox resolves an insertion boundary, while movement over a Main Task switches to attachment targeting. Steps likewise remove the grip; AppKit captures row background outside the registered checkbox/title/notes editing rectangles.

For Main Tasks, the title/body region—not a tiny grip—is the direct reorder surface. A 4-point movement threshold separates click from drag. Checkbox and effort controls remain outside that gesture; right-click context menus, hover, scrolling, and note attachment remain available.

The Main `NSHostingView` captures the left-button sequence only when mouse-down hits the registered title/body rectangle. It suppresses ScrollView drag arbitration for that sequence, derives insertion from actual row midpoints, commits once on mouse-up, and cancels without writes on Escape. Normal wheel/trackpad scrolling remains SwiftUI-owned outside a reorder sequence.

## Settings dismissal

Settings provides a visible `Done` control, Escape dismissal, and Command+W dismissal. While presented, Settings holds the EasyFlow interaction open; closing returns to Main and re-evaluates the pointer state rather than trapping or orphaning focus.

Settings exposes the current SMAppService Launch at Login state, appearance selection, and Reminders recovery. Registration failures use user-facing copy and refresh from the system status rather than pretending the toggle succeeded.

Post-v1 polish adds a Compact/Comfortable Main Task row density setting. The setting affects Main Task row spacing and row thickness in the Main Panel only.

## Completion and deletion interaction

- Completing a Step checks and dims it without moving or hiding it.
- Completing a Main Task removes it from active tasks and adds it to Recently Completed while synchronizing completion.
- Recently Completed presents the five newest completed Main Tasks without destroying older local history. It has no restore or uncomplete action in v1.
- Deleting a Main Task must make the external deletion consequence clear enough to avoid surprise, then delete the Reminder and soft-delete local context.
- EasyFlow keeps the five newest deleted Main Tasks. A sixth deletion purges the oldest task and its owned local data without exposing a Trash UI.
- Quick Note deletion should protect against accidental loss without turning trash into a heavy workflow.

## Reminders exceptional state

Normal synchronization is quiet. Settings shows only Connected, Needs Access, Synchronizing, Access Denied, ambiguity, or error/retry state. Tasks imported from Reminders show a compact `?` with “Effort not set”; Task Detail offers `1...4`, and assignment remains local.

For unrated imports, Task Detail displays `Set effort` and four immediate buttons. Assignment updates Main presentation and persistence only; it never marks synchronized title/completion pending.

`Recently Completed` renders at most five tasks, ordered by completion time descending with stable UUID tie ordering. This presentation limit does not purge history.

Task Description uses a native measured text view: 42 points when empty/short, content-driven growth and shrinkage, and a 156-point cap with internal scrolling beyond it.

## Appearance and accessibility

Use native typography, SF Symbols, adaptive contrast, macOS materials, restrained animation, context menus, continuous corners, and light/dark mode. Standard and Frosted appearances support the macOS 14 baseline; Liquid Glass is optional on macOS 26+. Controls include VoiceOver labels, keyboard behavior where practical, reduced-motion handling, focus indicators, and increased-contrast borders.

## Manual smoke scenarios

Use these repeatable manual checks for window-server behavior:

1. edge crossing shorter than the dwell does nothing and does not steal focus;
2. an intentional dwell reveals Main and accepts typing;
3. immediate abandonment restores the previous context and closes promptly;
4. Task A → Task B and Quick Notes ↔ Task switches Secondary in place;
5. traversal between panels never crosses an unintended dismissal gap;
6. overlays work over normal, maximized, fullscreen, and multiple Spaces;
7. the correct rightmost display is selected for varied display arrangements;
8. drag pickup, cancellation, drop indicators, and persistence remain fluid;
9. light/dark mode, reduced motion, and accessibility behavior remain usable.
