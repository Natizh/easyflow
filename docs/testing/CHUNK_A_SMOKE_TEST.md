# Chunk A Manual Smoke Test

Use this checklist on a real macOS desktop after `swift build`, then launch with `swift run EasyFlow`. Automated test success does not prove window-server, focus, fullscreen, Spaces, or physical pointer behavior.

## Preconditions

- Confirm no other EasyFlow process is running.
- Record macOS version, display arrangement, and whether the run is a SwiftPM debug executable or packaged app.
- Keep a normal application with an editable text field active to test focus restoration.
- Do not grant Input Monitoring or Accessibility solely for EasyFlow edge activation; Chunk A uses a transparent 3-point tracking panel.

## Checklist

| Scenario | Procedure | Expected result |
| --- | --- | --- |
| Resident state | Launch EasyFlow and do not approach the edge | No Main/Secondary UI, Dock icon, or menu-bar item appears; process remains resident |
| Accidental crossing | Sweep through the far-right edge for less than 300 ms | No visible panel and no keyboard focus change |
| Intentional activation | Hold at the far-right edge for about 300 ms | Main appears over the current app without resizing it |
| Quick Note focus | Immediately type after intentional activation | Text appears in the Quick Note composer without a click |
| Immediate abandonment | Activate, then leave without moving into Main or typing | Main disappears effectively immediately and prior app focus returns |
| Engaged Main grace | Move inside Main, leave briefly, then re-enter within 180 ms | Pending dismissal cancels and Main remains usable |
| Secondary context | Hover the Quick Notes region | One Secondary panel appears directly left with Quick Notes placeholder content |
| Main ↔ Secondary traversal | Move repeatedly across both panels and their gap | Neither panel flickers or closes while traversing |
| Staged exit | Leave after Secondary interaction | Secondary closes after about 250 ms; Main follows about 180 ms later |
| Fullscreen | Repeat activation over a fullscreen app | Overlay appears above the fullscreen app without forcing a Space change |
| Spaces | Activate on at least two Spaces | Edge surface and overlays are available on each Space |
| Multiple displays | Arrange displays with clear left/right ordering and test every physical right edge | Only the far-right outer edge of the display with greatest `frame.maxX` activates |
| Display rearrangement | Change display arrangement while EasyFlow runs | Hot zone and panel geometry move to the new rightmost display |
| Focus restoration | Begin typing in another app, activate EasyFlow, then abandon | EasyFlow never steals focus before dwell; prior app can resume after dismissal |
| Closed-state resources | Observe CPU/wakeups for at least 30 seconds with panels closed | No sustained CPU use, polling loop, animation timer, or repeated database/network activity |

## Current implementation-run evidence (2026-08-22)

Environment: macOS 26 toolchain/host, one 1470×956-point display, SwiftPM debug executable.

- **Verified:** process remained resident as a LaunchServices `UIElement`, with no Dock-centric application type and no menu-bar UI implemented.
- **Verified:** only a transparent 3×956-point activation window was present while visible panels were closed, at corrected status-bar window layer 25.
- **Verified:** five one-second `top` samples while closed reported 0.0% CPU, about 15 MB resident memory, four threads, and unchanged accumulated CPU time.
- **User verified on the target Mac:** physical far-right edge activation works and the Main Panel visibly opens; the basic real-hardware activation path is functional.
- **Automated only:** rightmost-display selection, activation-zone geometry, 300 ms dwell/cancellation, responsive frames, immediate/staged dismissal, context replacement, and traversal cancellation.
- **Not manually verified:** immediate keyboard focus, accidental-dismiss focus restoration, Secondary traversal/rendering, fullscreen overlay, multiple Spaces, multiple displays, and display rearrangement. Synthetic pointer events did not constitute reliable hardware-pointer evidence and are not counted.

Append dated evidence for each environment used. Do not replace an unverified row with a claim based only on compilation or unit tests.

## Chunk B/C local workspace checklist

The following scenarios require real GUI validation after the local workspace implementation. Automated coverage is noted separately and is not a substitute.

| Scenario | Procedure | Expected result |
| --- | --- | --- |
| Quick Note multiline | Type text and press Return | A newline is inserted; no note is committed yet |
| Quick Note explicit commit | Press Command+Return with non-empty text | One inbox note appears and the composer clears |
| Focus-loss/panel-close commit | Type a note, then change focus or close EasyFlow | One note is committed without duplicates |
| Interrupted draft | Type, wait at least 400 ms, terminate/relaunch | The uncommitted draft is restored |
| Restart persistence | Create/edit local objects, quit, and relaunch | Tasks, notes, Steps, styles, ordering, completion, and descriptions survive |
| Main Task creation | Open `+ New Task`, enter title without effort, then choose effort | No hidden default; task finalizes only with valid title and explicit `1...4` effort |
| Main Task ordering | Drag task title/body and relaunch | A between-row insertion line appears, final dense order persists, and rows do not flicker |
| Task context | Move directly from Task A to Task B | Shared Secondary updates immediately without re-entering animation |
| Description | Edit Description and leave the editor | Text persists locally and remains independent from Steps |
| Steps | Add, edit, annotate, complete, reorder, and delete Steps | Completed Steps stay dimmed in place; order and notes persist |
| Note organization | Drag an inbox Quick Note onto a Main Task row | Target highlights; the same note leaves inbox and appears below Steps |
| Appearance | Right-click a task/Step and change color, highlight, underline | Restrained local style persists without changing priority or effort |
| Completion | Check a Main Task | It leaves active tasks and appears under `Recently Completed` without a restore control |
| Soft deletion | Delete a task/note and relaunch | It stays hidden from normal UI; no permanent purge runs |
| Settings | Click the gear | A minimal surface shows only implemented storage/activation/panel/appearance information |
| Panel motion | Open/close Main and Secondary, then switch contexts | Windows slide spatially; an open Secondary does not replay entrance for content changes |
| Closed resources | Observe the resident process with panels closed | No database polling or animation timer causes sustained CPU activity |

Current status: these Chunk B/C GUI scenarios are **not yet manually verified**. Persistence, migration, reorder, completion, style storage, idempotent draft commit, transactional note movement/rollback, observation-driven view-model updates, and prior panel-state regressions are automated.

Closed-state process evidence after Chunks B/C (2026-08-22): the production Application Support database opened successfully; five one-second samples reported 0.0% CPU, about 16 MB resident memory, four-to-six threads, and unchanged accumulated CPU time. No workspace database exists inside or is tracked by the repository.

## Real-device workspace findings (2026-08-23)

User-confirmed working before the fix round: physical far-right activation, visible Main Panel, Quick Note typing, Command+Return commit/clear, and opening Settings.

User-confirmed defects before the fix round: misaligned Quick Note caret, no visible saved-note rows in Main, copy-style internal reorder semantics, insufficient vertical margins, no obvious Settings dismissal, and no observed Secondary Panel.

The fixes are automated but require a new user pass: AppKit caret/text geometry, compact observed Main inbox, direct insertion-bar reorder, 8%-clamped vertical margins, Done/Escape/Command+W Settings dismissal, explicit contextual hover surfaces, Secondary z-order, and bridge traversal. Fullscreen, Spaces, multi-display, focus restoration, and the repaired user-visible flows remain unverified until manually exercised.

## Chunk D Reminders checklist

Build and launch the stable TCC identity with `./scripts/build-dev-app.sh` and `open .build/dev/EasyFlow.app`.

1. Grant the fresh full-access Reminders prompt.
2. Confirm the existing manually created writable `EasyFlow` list is selected and no duplicate appears.
3. Create, rename, complete, and delete a local Main Task; verify the corresponding Reminder lifecycle.
4. Create a Reminder manually in the list; verify import with `?` effort, assign `1...4` locally, and confirm no Reminder metadata changes.
5. Rename, complete, and delete externally; verify local title, Recently Completed, and retained soft-deleted metadata.
6. Relaunch and confirm list/task mappings persist without duplicate creation.
7. Revoke access; confirm the local workspace remains usable and Settings shows recovery. Restore permission and retry.
8. If available, repeat from another Apple device after iCloud propagation.
9. After sync settles, measure hidden CPU/memory and confirm there is no polling.

End-to-end user mutation scenarios and visual no-duplicate confirmation are not verified by the fake-adapter suite and remain manually incomplete.

Development-bundle evidence (2026-08-23): the ad-hoc-signed `io.github.natizh.easyflow` app launched under a stable TCC identity, obtained access, persisted one Reminders list identifier, and reached two mappings with no pending mutation. The exact-list no-create path is automated; the user still needs to visually confirm that no duplicate list appeared. After synchronization settled, five one-second samples reported 0.0% CPU, about 22 MB resident memory, three threads, and unchanged accumulated CPU time; a three-second stack sample showed the main/event threads blocked idle.

## Second real-device corrective round (2026-08-23)

Confirmed before this fix: Main opens, Quick Notes and synchronized Main Tasks are usable, Reminders sync operates, and external imports show `?` effort.

Confirmed defects before this fix: Secondary had never appeared; Main Task reorder required the tiny grip; imported effort assignment was unreachable because Task Detail was invisible. Chunk E later supersedes the temporary recent-three limit with newest five.

Required user revalidation:

1. Launch the stable development app and open Main.
2. Hover Quick Notes; confirm Secondary visibly appears left of Main.
3. Hover Task A, then Task B; confirm one Secondary swaps detail without replaying entrance.
4. Traverse Main↔Secondary repeatedly without closure.
5. Import a Reminder, confirm `?`, hover it, choose `Set effort` `1...4`, and confirm dots plus restart persistence without Reminder metadata changes.
6. Drag a Main Task from its title/body—not a grip—and confirm the insertion line and final order.
7. Confirm checkbox click, right-click menu, and Quick Note attachment remain functional.
8. Complete at least six tasks; confirm only the newest five display and the sixth remains stored.

These repaired user-visible behaviors require user revalidation and are not marked manually verified by automated tests.

## AppKit pointer-routing revalidation

The second SwiftUI-based attempt also failed on real hardware: Secondary remained invisible and title/body drag did not begin. The current build no longer depends on SwiftUI hover or vertical DragGesture for Main Tasks.

Revalidate with the stable development app:

1. Hover Quick Notes, then Task A and Task B; confirm Secondary appears left and swaps one window's content.
2. Traverse Main↔gap↔Secondary without dismissal.
3. Mouse down on a Main Task title/body, move more than 4 points, cross another rendered row midpoint, and release; confirm one insertion-bar reorder.
4. Repeat with movement below 4 points; confirm no reorder.
5. Confirm checkbox, effort, right-click menu, wheel/trackpad scrolling, and Quick Note attachment still work.
6. Press Escape during a genuine reorder; confirm no database order change.
7. With Secondary open on a task or Quick Notes, move onto clearly empty Main background/footer space; confirm Secondary retracts immediately while Main stays open.
8. Repeat Main→gap→Secondary traversal; confirm the bridge does not trigger the empty-Main collapse.

If input still fails, launch from Terminal with structural diagnostics:

```sh
EASYFLOW_INPUT_DEBUG=1 .build/dev/EasyFlow.app/Contents/MacOS/EasyFlow
```

Diagnostics contain pointer coordinates, hit region/task UUID, insertion boundary, panel frame/alpha/level/window number, and structural state only. They never contain task, note, Description, Step, or Reminder text. This validation remains user-required; automated AppKit-router tests are not WindowServer proof.
