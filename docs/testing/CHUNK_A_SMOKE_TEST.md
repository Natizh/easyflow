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
- **Automated only:** rightmost-display selection, activation-zone geometry, 300 ms dwell/cancellation, responsive frames, immediate/staged dismissal, context replacement, and traversal cancellation.
- **Not manually verified in this environment:** physical edge activation, immediate keyboard focus, accidental-dismiss focus restoration, visible Main/Secondary rendering, fullscreen overlay, multiple Spaces, and multiple displays. Synthetic pointer events did not constitute reliable hardware-pointer evidence and are not counted.

Append dated evidence for each environment used. Do not replace an unverified row with a claim based only on compilation or unit tests.
