# Open Questions

This ledger preserves both open questions and resolved decisions under stable IDs. A proposal is not a decision. When an open item becomes blocking, present the choices and engineering consequences to the user, record the answer here, update the relevant domain document, and add or supersede an ADR if the decision is architectural.

## OQ-001: Quick Note keyboard semantics

**Domain:** UX<br>
**Status:** Resolved

The user must be able to type immediately after intentional edge activation, capture quickly, and avoid an unnecessary click.

Settled behavior:

```text
Return         = newline
Command+Return = commit to inbox and clear composer
focus loss or panel close = commit non-empty draft
```

Typing maintains one debounced persisted draft so interruption does not lose data or create duplicates. Whitespace-only drafts are discarded. See `docs/UX_BEHAVIOR.md` for rationale and lifecycle detail.

## OQ-002: Effort during Main Task creation

**Domain:** UX/Product<br>
**Status:** Resolved

Main Task creation uses an inline title field and compact `1...4` effort buttons. Effort has no hidden default; `Add` and keyboard submission finalize only when title and effort are both valid. No modal is used.

## OQ-003: Restore from Recently Completed

**Domain:** UX/Reminders sync<br>
**Blocks:** restore/uncomplete control

It is unresolved whether Recently Completed permits a Main Task to be restored/uncompleted. If approved, the operation must also uncomplete the corresponding Apple Reminder.

## OQ-004: Minimum macOS deployment target

**Domain:** Architecture/Build<br>
**Status:** Resolved

The minimum deployment target is macOS 14. macOS 26 is the primary development and experience target. Newer appearance APIs such as Liquid Glass remain optional and availability-gated. See ADR-006.

## OQ-005: GitHub repository visibility

**Domain:** Publication<br>
**Status:** Resolved

The canonical repository is private at `https://github.com/Natizh/easyflow`. `Natizh` was the sole authenticated user with no organization ownership candidates returned during publication. The default/integration branch is `main`.

## OQ-006: EasyFlow license

**Domain:** Legal/Publication<br>
**Status:** Resolved

EasyFlow uses the MIT License. This does not permit copying GPL-3.0 Atoll source into EasyFlow; continue to honor every reference project's license and attribution requirements.

## OQ-007: Deleted-item retention

**Domain:** Product/Data<br>
**Blocks:** permanent purge policy

Deleted Main Tasks enter a local trash-like soft-deleted state. The permanent-deletion age is not selected; do not invent a seven-day, thirty-day, or other retention interval.

## OQ-008: Panel width constraints

**Domain:** UX<br>
**Status:** Resolved for Chunk A; retain as a prototype-tuning decision if real-device evidence requires adjustment

Main and Secondary each use 20% of the selected display width, clamped independently to 360–520 points. Panels use an 8-point outer margin and gap plus a 12-point vertical inset. These constants preserve the one-fifth target on ordinary/wide displays while keeping small displays usable. Change them only with recorded prototype evidence.

## OQ-009: Closing grace interval

**Domain:** UX<br>
**Status:** Resolved for Chunk A; retain as a measured tuning decision

After real Secondary interaction and complete pointer exit, Secondary receives 250 ms of re-entry grace, then closes; Main closes 180 ms later. An engaged Main without Secondary receives 180 ms of re-entry grace. A newly opened, unengaged Main still closes immediately when abandoned. Central state-machine timers own these values.

## OQ-010: Main Task hover debounce

**Domain:** UX<br>
**Status:** Resolved for the local workspace; revisit only with measured flicker evidence

Main Task context switching has no debounce (`0 ms`). Hover requests replace the shared Secondary context immediately without closing or replaying window entrance. A future debounce requires measured flicker evidence and remains unrelated to the 300 ms edge dwell.

## Decision discipline

For the questions that remain open:

- keep UX-dependent behavior modeled behind explicit state/actions rather than hiding defaults;
- retain every question here and in its relevant domain document.
