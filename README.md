# EasyFlow

EasyFlow is a native macOS edge workspace for the tasks and notes you need while working. Move the pointer to the far-right edge of the rightmost display and the workspace slides over the current app. Move away and it gets out of the way.

## What it does

- Captures multiline Quick Notes without an extra click.
- Keeps a locally ordered list of Main Tasks with effort, descriptions, Steps, styles, and Attached Notes.
- Moves Quick Notes into tasks without copying them.
- Synchronizes Main Task title, completion, creation, and deletion through a dedicated Apple Reminders list.
- Stores EasyFlow-specific data locally in SQLite. No account or EasyFlow server is required.
- Runs as an accessory app without a Dock or menu-bar workflow.

## Requirements

- macOS 14 or later
- Swift 6 / a compatible Xcode toolchain
- Reminders access for cross-device Main Task synchronization

macOS 26 adds the optional Liquid Glass appearance. Standard and Frosted modes work on the macOS 14 baseline.

## Build and run

Run the testable Swift package directly:

```sh
swift package resolve
swift build
swift test
swift run EasyFlow
```

Build the ad-hoc-signed development app used for Reminders permission and normal manual testing:

```sh
./scripts/build-dev-app.sh
open .build/dev/EasyFlow.app
```

Build an unsigned release configuration:

```sh
./scripts/build-release-app.sh
open .build/release-app/EasyFlow.app
```

The bundle identifier is `io.github.natizh.easyflow`. Distribution still requires a final icon export, Apple Developer signing, notarization, and any release-specific entitlements.

## Privacy and data

Quick Notes, effort, order, descriptions, Steps, styles, Attached Notes, settings, and trash metadata stay on the Mac. Apple Reminders receives only Main Task title, completion, and existence. EasyFlow has no telemetry, analytics, custom backend, or account system.

Local databases and Reminder contents are excluded from Git.

## Project documentation

- [`PRODUCT_SPEC.md`](PRODUCT_SPEC.md) defines product behavior and scope.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) covers the SwiftUI/AppKit, GRDB, and lifecycle boundaries.
- [`docs/UX_BEHAVIOR.md`](docs/UX_BEHAVIOR.md) records pointer, panel, focus, drag, and keyboard behavior.
- [`docs/REMINDERS_SYNC.md`](docs/REMINDERS_SYNC.md) defines EventKit reconciliation and failure handling.
- [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md) retains the few product decisions that remain open.
- [`AGENTS.md`](AGENTS.md) is the contributor and coding-agent contract.

## License

EasyFlow is available under the [MIT License](LICENSE).
