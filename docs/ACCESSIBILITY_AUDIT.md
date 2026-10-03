# Accessibility regression audit and local approval gate

Candidate date: 2026-10-03. Branch: `fix/accessibility-focus-regression`.
The initial installed candidate was **1.4.0 (7)**. Publication was withheld pending user approval; the release follow-up below records the subsequent authorization.

## Findings and history

The investigation inspected AppKit windows, SwiftUI controls, native editor bridges, pointer routing, state-machine timers, auxiliary panels, synchronization, canonical documentation, and history before changing behavior. These are independently evidenced implementation defects; they do not prove that every reported visual or VoiceOver symptom has the same cause.

| Finding | Evidence / recent change | Fix |
| --- | --- | --- |
| Return can leave saved Quick Note text in the composer | `8ae50ea` changed capture updates to reject replacement while first responder, including the explicit empty state after successful submission. Earlier capture updated its string after submission. | A successful submission's focus revision permits the explicit empty reset. Ordinary active-editor updates and marked IME text remain protected. |
| Keyboard cannot reach hover-only details and drag-only operations | Main Task title and Quick Notes context were pointer surfaces; reorder and note attachment required drag. This was an existing gap exposed by the broader focus regression. | Native open buttons, task/note/Step menus, move actions, note attachment menu, and Back to Main. Reopening the installed app also opens capture. |
| Multiline text consumes Tab rather than leaving the editor | Native editor work in `f33d146` replaced persisted SwiftUI TextEditor/FocusState with custom NSTextView bridges; no explicit key-loop traversal existed in the shared editor. | Tab/Shift-Tab invoke AppKit next/previous key-view traversal; selection, native text accessibility, Return, and formatting remain native. |
| Pointer timers and hover can dismiss or replace content during keyboard use | State machine only tracked pointer engagement/auxiliary presentation; it had no keyboard ownership boundary. | Keyboard/explicit-open sessions cancel dismissal and suspend hover replacement. Deliberate workspace clicks restore pointer mode; deactivation and Space changes end keyboard ownership. |
| Closing panels retain responders during retreat; focus transfer can target hidden surfaces | Order-out paths did not explicitly retire responders/AX content; deferred capture requests did not verify panel presentation. Auxiliary closing unconditionally called makeKey. | Explicit retirement before animation, current-Space focus policy, guarded deferred capture, sensible Secondary-to-Main transfer, and guarded auxiliary return after close completes. |
| Space reconciliation reorders windows without updating accessibility lifecycle | `a94344c` added logical reordering across Spaces. `e1af251` correctly invalidated old application restoration but did not update panel AX exposure/key loops. | Retire inactive/hidden content, recalculate native loops, post layout changes for current visible panels, preserve native selection where valid, and never activate merely on a Space notification. |
| Auxiliary Escape/Command-W monitor can handle another window's events | `f33d146` auxiliary monitor checked visibility without key-window ownership. | Scope the local monitor to its key auxiliary window. |
| Symbol actions have ambiguous names/states | Completion circles, add-Step, note trash, generic Step actions, generic minute +/- controls, and duplicate image names. | Contextual names, Step completion value, named effort choices/states, distinct frequency/pause values and actions, numbered image labels, hidden decorative content. |
| Banner activation focuses Main rather than task content; stale banner animation can retire newer content | `8ae50ea` introduced banner opening through the state machine without Secondary focus; retirement had no generation check or explicit AX hide. | Keep banner non-key/non-main; name task/window, hide subtree on retirement, guard animation generation, validate task existence, then intentionally key Secondary on activation. |

History checks found the same `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`, `.ignoresCycle`, `.nonactivatingPanel`, `canBecomeKey = true`, and `canBecomeMain = false` configuration before `a94344c`. Those flags were not newly introduced in that change and have not been blamed or blindly reverted. Shared corner masking performs layer clipping and does not create accessibility elements; it remains intact. Live fullscreen/VoiceOver validation is required to determine whether any further window configuration change is necessary.

Previous-app restoration retains the valid `e1af251` cross-Space safeguard and now also requires EasyFlow still to own activation, so dismissal cannot override a newer application choice.

The user supplied a crop showing the native menu chevron overlapping the circular Main Task action icon. Main Task, note, and Step circular action menus now use `.menuIndicator(.hidden)` to retain only their circular symbol, without changing native menu actions or accessibility names. This visual correction also requires confirmation on the installed candidate.

## Surface audit

| Surface | Implemented / inspected behavior | Remaining live verification |
| --- | --- | --- |
| Main and Secondary | Distinct window titles, native key capability, automatic key-loop recalculation, exposure/retirement, explicit open/back/dismiss paths, keyboard ownership | Actual Tab/Shift-Tab order, VoiceOver window traversal, key focus and Escape/Command-W |
| Quick Notes and note bodies | Native capture text role/value/selection, submission reset, contextual body names, browser open, note action/reorder/attachment menus, native title field | Capture with IME, focus-loss commit, multiple notes, keyboard attachment and rich body editing |
| Main Tasks and Recently Completed | Named completion/open/action controls, native effort menus, keyboard reordering, missing task context cleared; completed tasks remain read-only native labels | Focus after completion/deletion/reordering, announcement of completion/history |
| Steps | Named completion with state, contextual title/notes/action names, native menu reorder/delete, add-Step name | Actual completion announcement, menu access, editor traversal, focus after row removal |
| Settings | Native labeled toggles/pickers; conditional removal of disabled sections; contextual minute values/actions and pause names/states; focus returns to a surviving control when pause/status controls disappear or reminders are disabled; same hosting view retained on resize | VO focus during collapse, pause/resume and resizing, picker announcements and +/- bounds |
| Reminder banner | Remains nonactivating, non-key, non-main; task/window names; immediate AX retirement and stale-generation guard; validated activation to exact task/Secondary | No spontaneous VoiceOver focus, announcement when navigated, expired banner removal and activation |
| Images / preview | Distinct numbered thumbnail names; existing native image preview label, native auxiliary close paths, originating current-Space focus guard | Open/remove image using keyboard, image preview close and return |
| Activation edge / decorations | Invisible edge and pointer view excluded from AX; decorative mark, reorder handles with menu equivalents, insertion bars and drag-only attachment icon excluded | No phantom elements or duplicate decorative nodes in VoiceOver |
| Context menus / auxiliary panels | Editing remains AppKit responder-owned; native menus supplement pointer-only actions; auxiliary monitor only handles its key window | Native keyboard menu operation, Settings/preview coexistence and return |

Rich-text sidecars, custom highlight glyph drawing, undo, paste/images, formatting shortcuts and persistence remain intact. The layout manager only draws glyph decorations; it introduces no accessibility views. Editor updates refresh labels, preserve current editing/selection, and avoid replacing marked text. Native role/value/selected-text tests pass. No privileged AX client APIs, event tap, or Accessibility permission requests exist in production code.

## Automated validation

- `swift build`: passed.
- Full `swift test`: **152 tests in 25 suites passed**, with all 137 prior tests retained.
- Added 14 tests in `AccessibilityRegressionTests` and one activation-ownership test in `FocusRestorationTests`. Coverage includes current-Space focus eligibility, native responder/subtree retirement, passive windows, Tab traversal, editor update/IME policy, native text role/value/selection, close routing, keyboard/pointer/deactivation/Space transitions, Secondary return, banner content lifecycle, and contextual names.
- Existing suites cover panel timers/transitions, window configuration, collapsed Settings height, five-minute bounds, rich-text formatting/selection, capture races, attachments, migrations, persistence, ordering, deletion, and fake Reminders reconciliation.
- `git diff --check`: passed.
- Release-mode app build and non-publishing packaging: passed using `EASYFLOW_DIST_DIR` under `.build/accessibility-package`.
- Bundle verification: metadata, executable, icon, ad-hoc signature, and absence of private state all passed for the built and installed bundles.
- The experimental direct SwiftUI accessibility-tree test could not materialize nodes without a live accessibility client. It was replaced with native AppKit banner lifecycle assertions; no existing tests were removed or disabled. Actual SwiftUI names/roles/order remain a VoiceOver manual gate.

AppKit key-loop behavior follows [Apple's native window/key-view-loop contract](https://developer.apple.com/documentation/appkit/nswindow/recalculatekeyviewloop%28%29).

## Local installation and data verification

The existing application was gracefully terminated through `NSRunningApplication.terminate()` and allowed to flush saves. The final validated release-mode candidate was installed at `/Applications/EasyFlow.app`, launched, and reopened through the native app reopen path. It remains version **1.4.0**, build **7**, with bundle identifier unchanged.

Read-only SQLite checks before/after installation returned `integrity_check = ok` and no foreign-key violations. Against the immediate pre-install baseline, content-free fingerprints confirm unchanged Main Task, Step, note, image metadata, migration records, attachment bytes and preferences: **58 Main Tasks, 30 Steps, 11 notes, 3 attachments/files, and 5 migration records**. The four settings rows remain present; only `reminders.listIdentifier` differed after automatic startup reconciliation. Existing synchronization always upserts that mapping and its timestamp; the original baseline hashes do not distinguish a timestamp refresh from a mapping refresh. The earlier baseline also detected one note row soft-deleted during the interactive session (the row remained retained), so the final replacement was checked against a fresh baseline after graceful quit to preserve the latest saved state. That final installation did not change any workspace row, preferences, or attachment bytes. The application-support location and schema are unchanged.

Runtime checks confirmed one installed EasyFlow process, finished launch, native reopen/activation, two visible workspace panels plus the 3-point activation edge, and no duplicate workspace windows. This confirms startup and native presentation over the retained database; rendered contents and input behavior still require visual/manual confirmation. VoiceOver was not running. No desktop interaction tool was available; no system-wide Accessibility permission was enabled or requested to simulate keyboard/VoiceOver/Space use.

## Manual verification procedure

These are the interactive checks originally supplied with the installed candidate. The subsequent publication authorization is recorded below; checks not performed by the agent are not represented as passed. Reopen via Spotlight/Finder if hidden. On macOS, use normal system keyboard-navigation settings to include buttons in Tab traversal.

1. **Keyboard:** Open EasyFlow, type and submit two Quick Notes, verify composer clears, Tab/Shift-Tab through Main, open a task, navigate Secondary and Back to Main, edit Description, Step title and notes, use Space/Return and arrow keys in native controls/menus, open Step/task/note actions, reorder without drag, attach a note without drag, create/delete/complete task/Step and confirm usable focus. Verify native word/line/selection navigation and formatting shortcuts; test an IME composition if used.
2. **Settings:** Open Settings, traverse controls, disable/re-enable banners, select Custom frequency and adjust bounds, expand/collapse Custom pause, pause and Resume. Verify values/labels, no disappearing-control focus trap, stable resizing, Escape/Command-W, and return to Main. Open/close image preview and verify return.
3. **Pointer/new features:** Confirm immediate accidental dismissal, edge dwell, task hover, panel traversal, drag reorder and note attachment remain reliable. After keyboard editing, deliberately click the workspace and confirm pointer mode resumes. Switch applications and confirm EasyFlow does not reclaim focus.
4. **Spaces:** On A open Main/Secondary; switch to B, interact, close, verify no jump to A, reopen on B and confirm focus. Repeat at least three times. Repeat normal↔fullscreen Spaces, while editing, with Settings open, and during animations. Check both panel sides and multiple displays if available.
5. **VoiceOver:** Enable VoiceOver manually; traverse Main and Secondary; verify useful names, native roles, states/values, text selection and editing, order, no hidden/duplicate/phantom elements. Verify task/Step/note menus, Recently Completed, Settings collapse/expand and pause controls, and image preview.
6. **Banner:** Let a reminder appear while another app is focused. Confirm keyboard and VoiceOver focus do not move; navigate to the banner and check the task name. Activate it and verify exact task/Secondary focus. Let it expire and verify no stale element. Repeat after a Space transition.

Local runtime launch/reopen/data/bundle checks and in-process native accessibility tests were performed. The human keyboard-only sequence, real Space/fullscreen transitions, spoken VoiceOver behavior, pointer/animation smoke sequence and real timed-banner interaction have **not** been manually verified here. These remain documented manual verification limitations.

## Changed files

- Product contract: `PRODUCT_SPEC.md`.
- App: `AppShellCoordinator.swift`, `ApplicationMenu.swift`, `EasyFlowMain.swift`.
- State: `Edge/PanelStateMachine.swift`.
- Settings: `Settings/SettingsView.swift`.
- Views: `AccessibilityNames.swift`, `AdaptiveTextEditor.swift`, `AppShellViewModel.swift`, `DirectReorderViews.swift`, `EasyFlowPanelSurface.swift`, `MainPanelView.swift`, `NoteAttachmentsView.swift`, `NoteImageTextView.swift`, `PersistedEditors.swift`, `QuickNoteCaptureEditor.swift`, `SecondaryPanelView.swift`.
- Windows: `ActivationEdgePanel.swift`, `AuxiliaryWindowLayout.swift`, `OverlayPanel.swift`, `PanelPresentationCoordinator.swift`, `PointerTrackingViews.swift`, `ReminderBannerPanel.swift`.
- Tests: `AccessibilityRegressionTests.swift`, `FocusRestorationTests.swift`.
- Canonical documentation: `docs/ARCHITECTURE.md`, `docs/UX_BEHAVIOR.md`, this audit.

In the initial accessibility-fix commit, `Support/Info.plist`, persistence/schema, packaging scripts and release metadata were not changed. No release/tag/push/publication was performed at that stage.


## Release follow-up — 2026-10-03

After receiving the installed-candidate report and its manual verification limitations, the user explicitly instructed: “ok continua il lavoro di prima e infine pubblica la patch”. This authorizes the version update and publication of **1.4.1 (8)**. It does not constitute an agent claim that the human VoiceOver/Spaces procedure was executed.

The final review additionally found that changing Panel Side rebuilt the state machine without keyboard ownership. Reconfiguration now stabilizes presentation while preserving keyboard ownership; a regression test verifies that closing Settings afterward does not trigger pointer dismissal. The circular action icons retain their hidden native menu indicators.

Patch validation uses `swift build`, the full 153-test suite, release-mode build, local ZIP/checksum packaging, bundle verification, documentation targets, and `git diff --check`. The versioned bundle was gracefully installed at `/Applications/EasyFlow.app`. Before/after read-only checks returned SQLite integrity `ok`, no foreign-key violations, and identical workspace rows, setting values, migrations, attachment bytes, and preferences; setting timestamps were excluded from this semantic value comparison because startup reconciliation refreshes them. The release notes are in [releases/v1.4.1.md](releases/v1.4.1.md). Live interactive VoiceOver/Spaces testing remains outside the available automation and is not claimed as complete.
