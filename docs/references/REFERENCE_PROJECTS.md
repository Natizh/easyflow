# Reference Projects

External projects provide behavioral or architectural study only. None is the EasyFlow specification. Before copying any source, inspect the current repository license and record the exact files, license obligations, and rationale. Prefer writing EasyFlow-specific code from learned patterns.

EasyFlow's own license remains unresolved in [OQ-006](../OPEN_QUESTIONS.md#oq-006-easyflow-license).

## Tic

Repository: <https://github.com/kasvith/tic>

Relevant study areas:

- native Swift/SwiftUI macOS task UI;
- SwiftUI hosted in AppKit panels;
- separation of window management and view logic;
- GRDB schema, migrations, observation, and persistence;
- task/subtask logic and direct drag gestures;
- launch-at-login architecture;
- architecture documentation and AI-agent guidance.

The bootstrap source records Tic as MIT-licensed based on a previous verification. Verify the current repository license again before source reuse. Learning patterns is preferred over wholesale copying.

## Atoll

Repository: <https://github.com/h4ckm1n-dev/atoll>

The user already uses Atoll. It is a behavioral/native reference for resident utility behavior, always-available notch overlays, SwiftUI/AppKit composition, fullscreen panels, settings/theming, repository organization, and AGENTS.md discipline.

The bootstrap source identifies Atoll as GPL-3.0. Do not copy its source into EasyFlow unless the user explicitly selects a compatible licensing strategy. Behavioral study and independent implementation are allowed.

## SideNotes

SideNotes is a proprietary product/UX reference for edge-accessible notes, instant capture, browsing, and low-friction visibility. It is not a code donor. EasyFlow borrows only broad interaction inspiration and retains its own product model.

## Unclutter

Unclutter is a proprietary product/UX reference for edge-triggered workspace behavior, light access, and overlay ideas. Do not copy proprietary source or assets.

## TodoPop

Repository: <https://github.com/shakee93/todopop>

Potential study areas include a lightweight native task utility, CRUD, reorder, persistence patterns, testable local logic, and documentation structure. Inspect and record its current license before any source reuse.

## tado / Liquid Todo references

These were previously considered for optional Liquid Glass and older-OS fallback patterns. Identify the exact repository and verify its license before relying on source. The purpose is to learn how newer appearance effects can degrade gracefully; EasyFlow does not copy the product or require Liquid Glass.

## Reuse ledger

No external source has been copied during bootstrap. If reuse is approved later, add an entry containing:

| Source repository/file | Version/commit | License | EasyFlow destination | Nature of reuse | Approval/obligations |
| --- | --- | --- | --- | --- | --- |

Behavioral observations that do not copy expression need not be itemized line by line, but must not turn a reference project's behavior into an undocumented EasyFlow requirement.
