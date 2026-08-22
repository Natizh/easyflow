# Open Questions

These questions are intentionally unresolved. A proposal is not a decision. When one becomes blocking, present the choices and engineering consequences to the user, record the answer here, update the relevant domain document, and add or supersede an ADR if the decision is architectural.

## OQ-001: Quick Note keyboard semantics

**Domain:** UX<br>
**Blocks:** final Quick Note capture interaction

The user must be able to type immediately after intentional edge activation, capture quickly, and avoid an unnecessary click. The exact commit gesture is not approved.

Proposal under consideration:

```text
Return       = save Quick Note
Shift+Return = newline
```

Do not implement this proposal as final behavior without confirmation. See `docs/UX_BEHAVIOR.md`.

## OQ-002: Effort during Main Task creation

**Domain:** UX/Product<br>
**Blocks:** final Main Task creation flow

Every Main Task needs effort `1...4`, but it is unresolved whether effort is required immediately after the title, receives a default, or uses an inline compact selector during creation. Do not introduce a modal form.

## OQ-003: Restore from Recently Completed

**Domain:** UX/Reminders sync<br>
**Blocks:** restore/uncomplete control

It is unresolved whether Recently Completed permits a Main Task to be restored/uncompleted. If approved, the operation must also uncomplete the corresponding Apple Reminder.

## OQ-004: Minimum macOS deployment target

**Domain:** Architecture/Build<br>
**Blocks:** `Package.swift`, compileable Swift scaffold, CI runner selection

macOS 26 is the primary development target but is not the approved minimum. A compatibility recommendation must consider AppKit overlay behavior, EventKit, `SMAppService`, Swift/GRDB support, native materials, optional Liquid Glass, and maintenance cost. macOS 14 or 15 may be candidates, but neither is product truth.

## OQ-005: GitHub repository visibility

**Domain:** Publication<br>
**Blocks:** remote repository creation

The `easyflow` repository may be public or private. Neither is the default. The repository owner/account must also be confirmed; the local GitHub CLI currently names `Natizh`, but its credential was invalid at bootstrap time and ownership must not be inferred from that configuration.

## OQ-006: EasyFlow license

**Domain:** Legal/Publication<br>
**Blocks:** `LICENSE` file and any source reuse that depends on EasyFlow licensing

No EasyFlow license has been selected. Do not add MIT, GPL, Apache, or another license by inference from reference projects.

## OQ-007: Deleted-item retention

**Domain:** Product/Data<br>
**Blocks:** permanent purge policy

Deleted Main Tasks enter a local trash-like soft-deleted state. The permanent-deletion age is not selected; do not invent a seven-day, thirty-day, or other retention interval.

## OQ-008: Panel width constraints

**Domain:** UX<br>
**Blocks:** final responsive panel constants

The Main Panel target is approximately 20% of the current display width, with the Secondary Panel conceptually using another fifth. Exact minimum and maximum widths require prototype tuning so small screens remain usable and large displays do not create absurdly wide panels.

## OQ-009: Closing grace interval

**Domain:** UX<br>
**Blocks:** final panel state-machine timing

After real Secondary Panel interaction, it should close first and the Main Panel shortly afterward using a grace interval under one second. Exact timing requires tuning. This does not change the requirement that an immediately abandoned accidental activation closes immediately.

## OQ-010: Main Task hover debounce

**Domain:** UX<br>
**Blocks:** final hover tuning

Main Task context switching must feel immediate, and no visible hover dwell has been approved. A tiny debounce may be used only if testing demonstrates it is necessary to prevent flicker; record the chosen implementation constant rather than treating the edge-activation dwell as precedent.

## Decision discipline

Until resolved:

- leave the Swift manifest and CI absent for OQ-004;
- leave the GitHub remote absent for OQ-005 and unresolved ownership;
- leave `LICENSE` absent for OQ-006;
- keep UX-dependent behavior modeled behind explicit state/actions rather than hiding defaults;
- retain every question here and in its relevant domain document.
