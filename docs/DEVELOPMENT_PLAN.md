# Development Plan

EasyFlow's v1 implementation is present on `main`: the native edge shell, local GRDB workspace, complete local UI, Apple Reminders synchronization, Settings, appearance modes, launch-at-login integration, accessibility work, and repeatable app packaging.

## Working discipline

- Keep `main` buildable and use one bounded branch for each coherent change.
- Read the product, UX, architecture, data, sync, and relevant ADR documents before editing.
- Update documentation when behavior or architecture changes.
- Finish file-changing rounds with formatting, build, tests, manual instructions where needed, and clear commits.
- Do not rewrite useful history or overwrite unrelated work.

## Verification baseline

Automated checks cover:

- edge activation and panel state transitions;
- display and panel geometry;
- AppKit task/note/Step pointer routing and reorder cancellation;
- Quick Note draft/commit idempotency;
- migrations, reopen persistence, CRUD, ordering, completion, and soft deletion;
- EventKit authorization mapping, list selection, retries, external imports, and three-way reconciliation;
- appearance and platform-service state that can be separated from live macOS behavior.

Real-device checks remain necessary for physical pointer feel, focus restoration, fullscreen/Spaces, multi-display changes, live iCloud delay, launch at login, accessibility, materials, animation, and release-bundle behavior. The consolidated checklist is in `docs/testing/CHUNK_A_SMOKE_TEST.md`.

## Release work outside the repository

Before public distribution:

1. Supply the final two-panel EasyFlow icon exports under `Support/AppIcon.iconset`.
2. Build the release app with `scripts/build-release-app.sh`.
3. Sign with the intended Apple Developer identity and required entitlements.
4. Notarize and staple the distributed build.
5. Run the manual regression checklist on the macOS 14 baseline and macOS 26 primary target.

Developer ID credentials, notarization, and final artwork are not stored in this repository.

## Scope control

Do not add backlog features to v1 without an explicit product decision. In particular, restore/uncomplete from Recently Completed and permanent trash retention remain unresolved in `docs/OPEN_QUESTIONS.md`.
