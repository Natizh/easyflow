# ADR-005: Repository as Project Memory

- **Status:** Accepted
- **Date:** 2026-08-22

## Context

EasyFlow will be implemented through multiple substantial AI-assisted work rounds. Conversation history is incomplete and cannot safely preserve long-lived product intent, tradeoffs, open questions, or licensing constraints.

## Decision

Treat repository documents, ADRs, completed/active plans, tests, and Git history as the durable source of truth. Separate product, UX, architecture, data, sync, backlog, reference, and agent guidance concerns. Update the relevant document when a durable decision changes, and record architectural rationale in an ADR. Keep open questions explicitly open until the user decides them.

## Alternatives considered

- **One permanent master prompt:** rejected because it becomes difficult to maintain, navigate, and reconcile with code.
- **Conversation memory only:** rejected because future agents may not have access to it.
- **Code and commit messages only:** rejected because product behavior and unresolved decisions are not recoverable reliably from implementation.

## Consequences

- Every work round begins by reading repository truth and inspecting Git status.
- Documentation changes accompany behavior or architectural changes.
- Coherent rounds end with verified, understandable commits.
- The repository must not contain private Reminder data, secrets, local databases, or copied incompatible source.
