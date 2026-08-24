# Architecture

## Goals and constraints

EasyFlow is a continuously resident native macOS utility with a very low-cost hidden state. It combines precise system-style overlay behavior, SwiftUI content, local SQLite persistence, and a narrow EventKit integration. There is no custom server, account, browser runtime, telemetry, or analytics.

The minimum deployment target is macOS 14. Newer appearance APIs remain availability-gated so the macOS 14 baseline remains functional.

## Stack

- **Swift and Swift Concurrency:** implementation language and structured asynchronous work.
- **SwiftUI:** Main Panel and Secondary Panel content, rows, editors, Settings, appearance, and accessibility.
- **AppKit:** `NSPanel` or equivalent overlay windows, window levels, collection behaviors, fullscreen/Spaces support, display geometry, event monitoring, focus, and lower-level drag handling when needed.
- **EventKit:** permission-gated Apple Reminders access and change observation.
- **SQLite with GRDB:** explicit local schema, migrations, observations, and testable persistence.
- **ServiceManagement:** native launch-at-login configuration through `SMAppService`.

## Source layout

```text
Sources/EasyFlow/
  App/         App entry, lifecycle composition, dependency container
  Windows/     panels, coordinators, geometry, focus restoration
  Edge/        display selection, edge monitoring, activation state machine
  Models/      domain values and pure rules
  Database/    GRDB records, migrations, repositories, observations
  Reminders/   EventKit adapter, mapping, reconciliation
  Views/       SwiftUI Main/Secondary content and reusable views
  Settings/    settings model, UI, launch-at-login integration
  Utilities/   small cross-cutting helpers only
Tests/EasyFlowTests/
```

## Runtime composition

```text
EasyFlow application lifecycle
  ├─ Dependency container
  │   ├─ Database writer and repositories
  │   ├─ Reminder store adapter and reconciliation service
  │   ├─ Settings store / launch-at-login service
  │   └─ Clock/scheduler abstractions for testable timing
  ├─ Edge activation coordinator
  │   ├─ display topology provider
  │   ├─ pointer/event monitor
  │   └─ pure activation/panel state machine
  └─ Panel coordinator
      ├─ Main NSPanel hosting SwiftUI
      └─ Secondary NSPanel hosting contextual SwiftUI
```

The dependency container composes concrete platform services at launch. Domain and state-machine logic depend on protocols/value types rather than AppKit or EventKit globals, allowing deterministic unit tests.

## App lifecycle

The app launches as a resident utility, initializes the local database and settings, installs edge observation, and normally exposes no UI. First-run permission and list setup are coordinated without making local operation wholly dependent on EventKit availability. Launch-at-login setup uses native APIs and remains configurable through Settings.

Appearance preference is stored in UserDefaults and drives both hosted panel surfaces. Standard and Frosted are macOS 14-safe; Liquid Glass is compiled behind a macOS 26 availability check. SMAppService reports and changes main-app login registration from Settings. Reduce Motion bypasses AppKit frame animation, while Reduce Transparency and increased contrast alter panel surfaces without changing layout.

EasyFlow runs with the accessory activation policy and has no Dock icon or menu-bar item.

## Window and panel architecture

The panel coordinator owns both overlay windows as one coordinated interaction surface:

- Main is anchored to the right edge of the selected display.
- Secondary is immediately left of Main and changes content between Quick Notes and task details.
- Panels use window levels and collection behavior suitable for fullscreen applications and Spaces without changing the underlying app layout.
- The coordinator owns show/hide ordering, geometry, transition cancellation, previous-app focus context, and reconfiguration after display changes.
- Presentation exposes centralized frame/opacity animation hooks: Main's hidden frame is beyond the right edge, while Secondary's hidden frame retracts toward Main. Context replacement never recreates the Secondary window.
- SwiftUI renders content and emits semantic actions; it does not directly orchestrate global windows.
- Secondary is ordered in front after Main during its entrance, and AppKit capture/saved-note hover surfaces emit explicit context requests. Main↔Secondary gap geometry remains one bridge region.

Main Task pointer ownership is AppKit-backed. SwiftUI publishes actual visible row/title rectangles through one preference bridge; the flipped Main `NSHostingView` owns `mouseMoved`, left-button hit testing, thresholded `mouseDragged`, `mouseUp`, and Escape cancellation. This avoids SwiftUI hover/vertical-drag arbitration inside the task `ScrollView` while leaving rendering, wheel scrolling, checkbox, effort, context menus, and note-drop composition in SwiftUI.

Main and Secondary are borderless `NSPanel` instances that become key for controls, editing, and SwiftUI presentation but never become main windows. They join all Spaces, remain available beside fullscreen apps, ignore window cycling, and use status-bar window level. EasyFlow activates its accessory app explicitly while showing Main, keeping the AppKit click sequence and SwiftUI presentation lifecycle reliable. The app records the previously active application and restores it after an immediately abandoned activation where macOS permits.

## Edge activation

The display topology provider selects the screen with maximum `frame.maxX`. A transparent, non-key 3-point AppKit panel occupies only the far-right outer edge of that display. AppKit tracking areas on the activation surface, Main, and Secondary emit pointer-region changes into the state machine. This is event-driven, needs no continuous poll, and avoids adding Input Monitoring or Accessibility permission merely to observe the pointer.

The pure state machine separates pointer crossing, 300 ms potential activation, intentional activation, active interaction, immediate accidental exit, panel traversal, and staged closing. Its commands are the only source of dwell/close tasks. An 8-point gap is classified as a traversal bridge while the related panels are visible.

The activation panel and visible overlays use `.canJoinAllSpaces` and `.fullScreenAuxiliary` at status-bar window level. EasyFlow does not install activation edges on other displays.

## State management and data flow

`AppShellViewModel` consumes the repository's GRDB observation stream and exposes explicit user intents for both panels. Data flow is unidirectional at the feature boundary:

```text
AppKit/EventKit/SwiftUI event
  → semantic action
  → state machine or application service
  → local transaction / external mutation
  → repository observation
  → rendered state
```

Local UI and persistence should update responsively. External Reminder work is asynchronous and represented with explicit pending/error/reconciliation states rather than blocking the main thread.

Window motion uses centralized AppKit frame/opacity hooks: Main opens in 0.22 seconds from beyond the right edge; Secondary opens leftward in 0.28 seconds and retracts in 0.35 seconds; Main closing remains 0.18 seconds. Context replacement changes only the SwiftUI model. Reduce Motion bypasses animation.

## Persistence boundary

`AppDatabase` owns the production Application Support location and versioned migrator. The actor-isolated `WorkspaceRepository` owns CRUD, transactions, dense ordering, draft idempotency, soft deletion, five-item deleted-task retention, and a GRDB `ValueObservation` exposed as an async snapshot stream. Records, repository operations, and SQL remain explicit and inspectable.

Database observations notify only the affected feature state. Writes occur off the UI-critical path with clear transaction boundaries. Production databases are never wiped to resolve migration errors.

See `docs/DATA_MODEL.md`.

## Reminders boundary

An EventKit adapter contains framework types and authorization/list operations. Reconciliation logic operates on application-owned representations so it can be tested with fakes. A Main Task's UUID is its stable EasyFlow identity; EventKit identifiers are mappings that may become unavailable or change.

Only title, completion, and existence cross the boundary. Enriched EasyFlow metadata never leaks into Reminder fields. A purged deleted task may leave a minimal tombstone containing its UUID, Reminder identifier, deletion time, retry count, and non-content error code until external deletion succeeds. See `docs/REMINDERS_SYNC.md`.

`RemindersSyncCoordinator` serializes runs on the main actor, consumes adapter snapshots, coalesces store notifications, and persists baselines/pending mutations through `WorkspaceRepository`. The stable ad-hoc development bundle `io.github.natizh.easyflow` supplies `NSRemindersFullAccessUsageDescription`; raw SwiftPM build/test remains permission-independent.

## Concurrency

- UI and AppKit window mutations run on the main actor.
- Database work uses GRDB's queues/writers and transactional guarantees rather than ad hoc shared mutable state.
- EventKit operations are wrapped in async application services; framework callbacks are normalized before entering domain logic.
- Reconciliation is serialized per logical sync run to avoid competing destructive interpretations.
- Cancellation and stale-result checks prevent an old hover, timer, database observation, or external fetch from replacing newer state.
- Clocks/schedulers are injected into activation and grace-period logic for deterministic tests.

Exact actor annotations belong with implementation, but main-thread safety and isolation must remain explicit.

## Performance and privacy

- Hidden state has no animation timers, hidden WebView, constant cloud loop, or high-frequency database reads.
- Prefer event/change notification paths over polling.
- Avoid expensive work on each mouse event and full-list rendering during drag.
- Profile CPU, wakeups, memory, and database activity if idle cost is non-trivial.
- Do not log Reminder/task/note bodies in production.
- No task data leaves the Mac except the explicitly synchronized Main Task core through Apple Reminders/iCloud.

## Testing boundaries

Automate pure logic for activation timers, panel transitions, sorting, reorder, Step completion, note moves, soft deletion, migrations, persistence, and reconciliation. Use protocol-backed EventKit fakes and temporary databases. Manually test window levels, fullscreen/Spaces, multiple-display geometry, pointer traversal, focus restoration, real permission dialogs, live iCloud propagation, animation, and launch-at-login.

## CI

GitHub Actions runs `swift package resolve`, `swift build`, and `swift test` on `macos-15` for pushes to `main` and pull requests. Signing, packaging, and live EventKit tests remain local release checks.

## Packaging

`scripts/build-dev-app.sh` and `scripts/build-release-app.sh` create ad-hoc-signed app bundles for local use. Both use `io.github.natizh.easyflow`, the Reminders usage description, and UIElement lifecycle. The scripts generate `EasyFlow.icns` when a complete PNG iconset is present. Public distribution still requires Developer ID signing and notarization.
