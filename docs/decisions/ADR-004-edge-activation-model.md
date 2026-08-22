# ADR-004: Edge Activation Model

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

EasyFlow should be normally invisible yet one movement away, without frequently appearing or stealing focus during ordinary cursor use. It must behave coherently with multiple displays, fullscreen apps, and Spaces.

## Decision

Use a deliberately narrow activation zone on the far-right outer edge of the rightmost display, selected by the largest desktop-coordinate `frame.maxX`. Require approximately 300 ms of continuous presence before intentional activation. A mere edge crossing does not show UI or take focus. If the just-opened panel is immediately abandoned, dismiss it immediately or effectively immediately.

Use Main and one contextual Secondary overlay panel. The 300 ms edge dwell does not apply to Main Task hover. Only after attempting and documenting a technical limitation may the product consider the fallback of activating on the current display's right edge.

## Alternatives considered

- **Dock or menu-bar activation:** rejected because it is not one physical movement away and creates conventional app-management burden.
- **Immediate zero-dwell activation:** rejected because accidental reveals and focus theft would be intrusive.
- **Activation on every display:** deferred, not part of v1.
- **Current-display edge as the primary model:** retained only as a documented technical fallback.

## Consequences

- Chunk A requires a testable activation/panel state machine and real multi-display/fullscreen/focus testing.
- Event observation must be efficient in the hidden state.
- Focus is acquired only after intentional activation and must be restored sensibly after immediate abandonment.
- Hot-zone width, panel bounds, closing grace, and any tiny task-hover debounce remain tuning/open decisions rather than architectural changes.
