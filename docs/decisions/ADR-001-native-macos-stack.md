# ADR-001: Native macOS Stack

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

EasyFlow is a continuously resident, normally invisible macOS utility that must provide precise overlay, display-edge, fullscreen/Spaces, focus, and launch-at-login behavior while consuming very few resources. Its content UI still benefits from declarative composition.

## Decision

Use Swift as the implementation language. Use SwiftUI for panel content, task/note/Settings views, appearance, and accessibility. Use AppKit for overlay windows, window levels, collection behavior, display geometry, edge interaction, focus, and lower-level drag behavior when SwiftUI is insufficient. Use EventKit for Reminders, ServiceManagement for native launch at login, and SQLite/GRDB for local storage.

The baseline UI uses native macOS materials and conventions. Liquid Glass may be an optional availability-gated appearance but never a functional dependency.

## Alternatives considered

- **Pure SwiftUI:** insufficient control and confidence for the required system-style window/focus behavior.
- **Pure AppKit:** possible but would make content composition and state-driven UI unnecessarily costly.
- **Electron or another web shell:** rejected for resident footprint, native integration, and product-quality reasons.
- **Custom backend/web UI:** rejected by local-first scope.

## Consequences

- The project maintains an explicit SwiftUI/AppKit boundary and tests pure state outside window plumbing.
- Some overlay and focus behavior requires manual validation on real macOS configurations.
- Platform APIs are implemented against the macOS 14 baseline, with macOS 26 as the primary development/experience target and newer APIs availability-gated.
- Engineers must prevent platform framework types from leaking through every domain layer.
