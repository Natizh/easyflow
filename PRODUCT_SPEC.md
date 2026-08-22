# EasyFlow Product Specification

## Product identity and purpose

EasyFlow is the product name, not a temporary codename. Product UI, code identifiers, settings labels, and project documentation are written in English by default. The dedicated Apple Reminders list is named `EasyFlow`.

EasyFlow is a lightweight macOS edge workspace that keeps the user's current working set continuously available while using the computer. It addresses near-term focus—what is being worked on now, what comes next, what remains unfinished, what thought should not be lost, and what smaller steps belong to the current task—rather than general life or project management.

Product principle:

> A lightweight macOS edge workspace that keeps the user's current working set always one movement away.

## Durable principles

### Always one movement away

EasyFlow is normally invisible. The user intentionally reaches the activation edge and the workspace appears without opening a normal window, using the Dock, clicking a menu-bar item, switching applications, or navigating project hierarchies.

### Extremely low friction

Capturing a thought, seeing the next task, creating a task, or checking a Step requires very little interaction.

### Local-first, with a narrow sync boundary

Everything specific to the EasyFlow workspace remains local unless synchronization is explicitly required. V1 has no EasyFlow server, account, backend, webhook listener, or always-on secondary device. Apple Reminders/iCloud is the only external integration and supplies cross-device availability for Main Tasks.

### Position is priority; effort is separate

The vertical order of Main Tasks and Steps is their priority. Neither type has an independent numeric priority. Only Main Tasks have effort, expressed as `1`, `2`, `3`, or `4`, representing work required rather than importance.

### Native and lightweight

EasyFlow runs throughout a Mac session, so the invisible state must use very little CPU and memory. It should look and behave like a native macOS utility, with no Electron, Chromium, unnecessary web runtime, telemetry, analytics, or needless network activity.

## Visibility, activation, and displays

- Normal use has no persistent primary window, no menu-bar icon, and ultimately no Dock icon.
- A development-only Dock presence may be used for debugging if documented; it must not redefine production behavior.
- EasyFlow starts automatically when the user logs in and Settings opens from the Main Panel.
- The preferred activation surface is the far-right outer edge of the rightmost display in the current arrangement, determined using the desktop coordinate system (for example, the `NSScreen` with the greatest `frame.maxX`).
- Only if implementation proves that model technically infeasible may EasyFlow fall back to the right edge of the display containing the cursor; the limitation and fallback require documentation and user visibility.
- The activation hot zone is intentionally narrow. Its exact width is a tuning parameter.
- Intentional activation requires approximately 300 ms in the hot zone. Minor empirical tuning is allowed, but the interaction must remain immediate and must not become arbitrarily slower.
- An accidental activation closes immediately or effectively immediately when the cursor leaves.

EasyFlow overlays ordinary, maximized, fullscreen, and Space-hosted applications without resizing or shifting them. Its desired availability is analogous to an always-present system utility, but it uses the right edge rather than the display notch.

## Panel model

EasyFlow has a Main Panel at the right edge and one contextual Secondary Panel immediately to its left.

The Main Panel conceptually occupies about 20% of the current display width, with sensible minimum and maximum constraints. The Secondary Panel uses roughly another fifth with similar constraints. Exact values are unresolved under [OQ-008](docs/OPEN_QUESTIONS.md#oq-008-panel-width-constraints).

The Main Panel contains, in order:

1. Quick Notes capture area;
2. `Main Tasks` heading;
3. a small `+ New Task` control;
4. active Main Tasks in local priority order;
5. `Recently Completed`;
6. a Settings gear in the lower-right region.

The visual hierarchy is calm, productive, and native. `+ New Task` is not a giant call to action.

The Secondary Panel is reused for the Quick Notes browser or the currently hovered Main Task. It updates context in place; EasyFlow does not create a separate third notes/details window.

## Quick Notes

Quick Notes form a low-friction capture inbox for temporary ideas, technical thoughts, fragments, scratch information, or context that may later belong to a Main Task. They are not the primary task-management system and should be easy to organize rather than becoming permanent clutter.

After intentional activation, the user can type into Quick Note capture without another click. The capture field behaves as a native multiline note editor: `Return` inserts a newline, `Command+Return` explicitly commits the note and clears the composer, and a non-empty draft is preserved automatically and committed when capture ends. See [OQ-001](docs/OPEN_QUESTIONS.md#oq-001-quick-note-keyboard-semantics) and `docs/UX_BEHAVIOR.md` for the settled data-safety semantics.

Each Quick Note contains an app-owned ID, optional explicit title, body, creation and update timestamps, local order, and optional deletion metadata. When no explicit title exists, the UI derives a label from the first meaningful words without modifying or truncating the stored body. Browsing shows the explicit/generated title, creation time/date, and enough preview text for recognition.

When Quick Notes is active, the Secondary Panel supports opening, reading, editing, deleting, reordering, and dragging notes to Main Tasks.

Dragging a Quick Note onto a Main Task is a move:

- the note leaves the inbox after a successful drop;
- its body and sensible timestamp/history are preserved;
- it becomes a distinct Attached Note owned by the target Main Task;
- it is not duplicated or concatenated into the task Description.

A Main Task may own multiple Attached Notes.

## Main Tasks

Main Tasks are high-level tasks and the only EasyFlow objects synchronized through Apple Reminders. Each has a short title, effort `1...4`, local sort position, optional text style, local Description, local Steps, local Attached Notes, and lifecycle metadata.

V1 does not add categories, tags, due dates, or a separate priority field.

### Creation and effort

The small `+ New Task` control enters a low-friction inline creation flow. Creation eventually persists the EasyFlow representation, creates an Apple Reminder in the dedicated list, and stores the external association. The exact effort-selection interaction remains unresolved under [OQ-002](docs/OPEN_QUESTIONS.md#oq-002-effort-during-main-task-creation); do not replace it with a complex modal.

Effort is editable and may eventually use dots, a segmented indicator, a subtle bar, or another compact native representation. The visual is intentionally not frozen.

### Ordering and appearance

Main Task order is authoritative only inside EasyFlow and persists locally after restart. Drag-and-drop pickup should be immediate or near-immediate, fluid, low-latency, and show a clear destination. Prefer a direct custom gesture if standard system drag feels clumsy.

Right-click/contextual actions may set text color, highlight, and underline. These styles are cosmetic only and do not affect priority, effort, synchronization, or completion. Do not add an elaborate styling inspector.

### Details

Hovering a Main Task displays its detail context in the Secondary Panel. The content order is:

1. Main Task title/context;
2. editable Description;
3. Steps;
4. Attached Notes.

Description is one lightweight free-text field for task meaning, intended execution, context, and reminders to self. It remains local and is not a Step collection.

## Steps

A Main Task can contain any number of one-level Steps. Nested Steps are not supported in v1. A Step has an app-owned ID, parent Main Task ID, title, local order, completion state, optional style and notes, timestamps, and optional deletion metadata.

Step position is priority. Steps support high-quality local drag reordering. Completing a Step checks it and dims it, but it remains visible and stays in position until its parent Main Task is completed, archived, or deleted. Step notes remain local.

Text color, highlight, and underline are available through the same lightweight contextual model as Main Tasks.

## Attached Notes

Attached Notes are Quick Notes organized into a Main Task. They remain distinct note objects, appear below Steps, and preserve their content and history where sensible. Multiple Attached Notes can belong to one Main Task.

## Completion, deletion, and history

Completing a Main Task:

1. marks its corresponding Apple Reminder completed;
2. removes it from active Main Tasks;
3. places it in `Recently Completed`.

The visible Recently Completed area may contain a small, bounded, rotating history, but it must not expose an arbitrary label such as `Last 5` and must not destroy older local history merely because it is no longer visible. The exact visible count is a UI tuning parameter. Restore/uncomplete behavior remains unresolved under [OQ-003](docs/OPEN_QUESTIONS.md#oq-003-restore-from-recently-completed).

Deleting a Main Task deletes its external Apple Reminder and soft-deletes its local record. Local Description, Steps, Attached Notes, styles, and metadata remain temporarily recoverable. The retention period is unresolved under [OQ-007](docs/OPEN_QUESTIONS.md#oq-007-deleted-item-retention).

Quick Notes are easy to delete without needless accidental data loss. A consistent soft-delete design is preferred when natural, but ordinary use must not feel burdened by trash management.

## Apple Reminders boundary

EasyFlow works with a dedicated Apple Reminders list named `EasyFlow`; it does not depend on Reminders folders/groups. The user may place that list in any folder manually.

The synchronized Main Task core is:

- title;
- completion state;
- existence/deletion.

EasyFlow creates, renames, completes, and deletes corresponding reminders. It also reconciles external renames, completions, deletions, and new reminders created directly in the dedicated list.

Local-only data includes EasyFlow order/priority, effort, styles, Description, Steps and their state/notes, Attached Notes, Quick Notes, trash metadata, and panel/UI state. Apple Reminders ordering does not need to match EasyFlow ordering.

## Settings, permissions, and appearance

The Main Panel gear opens Settings. Potential categories are appearance, launch at login, activation behavior, panel sizing, and UX timings; only settings backed by real features belong in v1.

EasyFlow starts automatically at login through a native mechanism such as `SMAppService`. First run handles Reminders authorization, finding or creating the EasyFlow list, and launch-at-login configuration. Authorization states include not determined, authorized, denied/restricted, and unavailable/error. Permission is not repeatedly requested once decided, and a graceful local experience remains available where technically reasonable.

The baseline design uses system typography, SF Symbols, macOS materials, adaptive light/dark mode, native spacing, restrained translucency/shadows, continuous corners, subtle animation, and appropriate context menus. Avoid a web-dashboard look, Electron chrome, giant controls, gratuitous gradients, and excessive animation.

Standard appearance must work on the minimum deployment target, macOS 14. macOS 26 is the primary development and experience target. Frosted appearance may be offered where appropriate. Liquid Glass is optional only where supported and never gates core functionality. See [OQ-004](docs/OPEN_QUESTIONS.md#oq-004-minimum-macos-deployment-target) and ADR-006.

## Performance, privacy, and reliability

- Hidden-state activity is minimal: no needless timers, high-frequency polling, repeated database work, cloud loop, hidden WebView, or unnecessary rendering on every mouse event.
- Use event-driven mouse and change observation where feasible.
- Local data survives app close, relaunch, restart, login/logout, and application migrations.
- Database work does not block the UI, and migrations are versioned and tested rather than wiping production data.
- No telemetry or analytics is collected, and task/note bodies are not sent to external services or logged in production.
- EventKit access requests only what EasyFlow requires.

## Explicit v1 exclusions

V1 excludes Notion sync, custom backend/server/webhooks, accounts, collaboration, iPhone/iPad apps, tags, categories, project hierarchies, complex grouping, due dates, calendar integration, recurring tasks, dependencies, nested Steps, percentage completion, EasyFlow notifications, global shortcuts, embedded AI, telemetry, analytics, advertising, social features, reporting, Kanban, and team features. See `docs/BACKLOG.md` for deferred ideas.

## Definition of Done

EasyFlow v1 is done when the user can:

1. have EasyFlow start at macOS login with no persistent normal-use UI;
2. intentionally reveal it at the right edge with a narrow hot zone and approximately 300 ms dwell while accidental activation dismisses immediately;
3. type, browse, edit, reorder, and delete Quick Notes without an extra capture click;
4. create, view, style, reorder, complete, and delete Main Tasks with effort `1...4`;
5. synchronize Main Task title, creation, completion, and deletion with the dedicated Apple Reminders list and reconcile external changes;
6. retain EasyFlow ordering and enriched workspace data locally;
7. hover tasks and switch Secondary Panel context immediately without reopening the whole surface;
8. edit Description, create/reorder/complete/style one-level Steps, and add Step notes;
9. move Quick Notes into Attached Notes below Steps;
10. see completed Main Tasks in Recently Completed and retain soft-deleted local context temporarily;
11. use the overlay over fullscreen applications and across Spaces without shifting the underlying app;
12. restart the app or Mac without losing local metadata;
13. open Settings from the Main Panel and use a native baseline appearance, with optional newer effects where supported;
14. leave EasyFlow running without noticeable system slowdown.

Features outside this definition require explicit approval for a later release.
