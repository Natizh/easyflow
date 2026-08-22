# ADR-006: macOS Support Policy

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

EasyFlow is primarily developed and experienced on current macOS 26 hardware, but its native baseline should not exclude older capable Macs solely for new appearance effects. The build target must support AppKit overlays, EventKit, ServiceManagement, SwiftUI, and GRDB while keeping maintenance bounded.

## Decision

Set the minimum deployment target to macOS 14. Treat macOS 26 as the primary development and experience target. Keep the complete Standard appearance and core behavior functional on macOS 14; use availability checks for newer APIs and optional Liquid Glass effects.

## Alternatives considered

- **Minimum macOS 26:** rejected because it would tie core functionality to the newest operating system without a product need.
- **Minimum macOS 15:** viable but rejected in favor of the explicitly selected wider macOS 14 baseline.
- **An older baseline:** not selected because additional compatibility burden has not been justified against the required framework set.

## Consequences

- `Package.swift`, build configuration, and CI target macOS 14 or later.
- Code must not reference macOS 15/26-only APIs without availability gates.
- Manual release checks eventually include both the macOS 14 baseline and macOS 26 primary experience where environments are available.
- Optional newer visual effects cannot become architectural dependencies.
