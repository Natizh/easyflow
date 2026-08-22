# Data Model

## Principles

- SQLite with GRDB is the selected local store.
- Every Main Task and local child object has an application-owned stable UUID.
- EventKit identifiers are external mappings, not primary identity.
- Position is represented by local order and is the authoritative priority in EasyFlow.
- Deletion is soft where local context must remain temporarily recoverable.
- Migrations are versioned, tested, and non-destructive to production data.
- Database work must not block UI interaction.

The physical schema may be refined during Chunk B, but it must preserve the product concepts below. Any meaningful normalization change should update this document before or with implementation.

## Conceptual relationships

```text
MainTask
  ├─ 0...n Steps
  └─ 0...n Notes in attached state

Note
  ├─ inbox
  ├─ attached to one MainTask
  └─ soft-deleted

AppSetting
  └─ local application preferences/state
```

Task and Step style metadata may be embedded in their records or normalized if implementation evidence favors it. Product semantics remain text color, highlight, and underline only.

## Main Task

Required concepts:

| Field | Meaning |
| --- | --- |
| `id` | App-owned UUID and stable local identity |
| `reminderIdentifier` | Optional current EventKit mapping; never sole identity |
| `titleCache` | Local title used for responsive/offline presentation and reconciliation |
| `effort` | Integer constrained to `1...4` |
| `sortIndex` | Local authoritative priority/order among active tasks |
| `textColor` / style | Optional cosmetic metadata |
| `highlight` | Optional cosmetic metadata |
| `isUnderlined` | Optional cosmetic metadata |
| `description` | Local lightweight free text |
| `createdAt`, `updatedAt` | Lifecycle timestamps |
| `completedAt` | Optional completion timestamp |
| `deletedAt` | Optional soft-deletion timestamp |

The schema may keep external mapping fields in a dedicated table if reconciliation history requires it. The exact physical representation belongs to Chunk B/D design, but identifiers must be nullable and recoverable rather than assumed eternal.

## Step

| Field | Meaning |
| --- | --- |
| `id` | App-owned UUID |
| `mainTaskID` | Required parent; Steps cannot exist outside one Main Task |
| `title` | Short Step text |
| `sortIndex` | Local priority/order within the parent |
| `isCompleted` | Completion flag; completion does not reorder or hide the Step |
| style fields | Optional text color, highlight, and underline |
| `notes` | Local short execution notes |
| `createdAt`, `updatedAt` | Lifecycle timestamps |
| `deletedAt` | Optional soft-deletion timestamp |

Steps are exactly one level deep. The model has no parent-Step relationship and no numeric priority independent of `sortIndex`.

## Notes

A unified note record is the preferred initial physical direction because a Quick Note becomes an Attached Note by moving ownership rather than duplicating content. The schema must express these equivalent states:

```text
inbox
attached(mainTaskID)
deleted
```

Required concepts:

| Field | Meaning |
| --- | --- |
| `id` | App-owned UUID preserved across a move |
| `title` | Optional explicit title |
| `body` | Full note content, never destructively truncated for display |
| `mainTaskID` | Null for inbox; target task for attached state |
| `sortIndex` | Order within the current inbox/task collection |
| `createdAt`, `updatedAt` | Preserved history timestamps |
| `deletedAt` | Optional soft-deletion timestamp |

An explicit location/state column may be added if it makes invariants clearer. If `mainTaskID` plus `deletedAt` fully and safely represents the states, avoid redundant data. This is an engineering schema refinement, not permission to change move semantics.

The generated display title is derived at presentation/domain level from the first meaningful words when `title` is absent. It is not stored by overwriting `body`.

## Settings

`AppSetting` stores only preferences that exist in the product, potentially including appearance, launch-at-login preference/status, activation tuning, and panel sizing. Do not prepopulate speculative settings. Panel/UI state remains local and does not synchronize through Reminders.

## Ordering

`sortIndex` defines position among non-deleted peers:

- Main Tasks: active EasyFlow priority;
- Steps: priority inside their Main Task;
- Quick Notes: inbox order;
- Attached Notes: local display order under the owning task if ordering is exposed.

Reorder operations update affected rows in one transaction and preserve stable identities. The implementation may choose dense integers, gapped values, or another well-tested strategy; it must support deterministic order, bounded write amplification, persistence after restart, and normalization when required. Apple Reminders order never overwrites Main Task `sortIndex`.

## Lifecycle operations

### Quick Note to Attached Note

One transaction changes the existing note from inbox ownership to the target Main Task and assigns a target-local order. It preserves ID, body, explicit title, creation time, and sensible update/history information. A failed transaction leaves the inbox note unchanged.

### Step completion

Set `isCompleted` and `updatedAt`. Do not change `sortIndex`, delete, or hide the Step.

### Main Task completion

Set `completedAt` and preserve all Description, Steps, Attached Notes, style, order/history, and external mapping. Active queries exclude completed tasks; Recently Completed queries a bounded view ordered by recent completion without deleting older records.

Restore/uncomplete behavior is unresolved in [OQ-003](OPEN_QUESTIONS.md#oq-003-restore-from-recently-completed).

### Main Task deletion

After coordinating the external Reminder deletion, set `deletedAt` locally and retain the task, Description, Steps, notes, and styles. Queries exclude soft-deleted rows unless explicitly operating on trash/reconciliation. The purge age remains unresolved in [OQ-007](OPEN_QUESTIONS.md#oq-007-deleted-item-retention).

External disappearance must never translate directly into destruction of local metadata merely because an identifier lookup failed.

### Quick Note deletion

Prefer the same soft-delete approach when consistent with implementation. The user-facing operation stays lightweight and protects against accidental loss without exposing a complex trash system.

## Relationships and deletion rules

- A Step belongs to exactly one Main Task.
- An attached Note belongs to exactly one Main Task; an inbox Note belongs to none.
- Soft-deleting a Main Task makes its children unavailable to active UI but does not immediately cascade physical deletion.
- Permanent purge, once approved, operates transactionally and accounts for associated records.
- Foreign keys and indexes should enforce valid parent relationships and support active ordered queries.

Expected indexes include active Main Task order, Steps by parent/order, inbox Notes by order, attached Notes by parent/order, completion recency, soft deletion, and current external identifiers. Final names and SQL are implementation details.

## Migrations and storage guarantees

- Create an explicit numbered migrator from the first schema.
- Test a fresh database and every supported upgrade path.
- Apply migrations transactionally and fail safely with actionable diagnostics.
- Never wipe a production database for a schema change.
- Development-only destructive reset, if ever introduced, must be clearly gated and documented.
- Store the database in the appropriate application-support location, never in the repository.
- Data must survive app close/relaunch, Mac restart, login/logout, and application updates.

## Test requirements

- effort constraint and stable UUID creation;
- deterministic task/Step/note ordering and reorder normalization;
- completed Steps retaining order and visibility eligibility;
- transactional Quick Note move with rollback behavior;
- Main Task completion and Recently Completed queries;
- soft deletion retaining related context;
- migration from every schema version;
- persistence across database reopen;
- active-query exclusion of deleted/completed records as appropriate;
- identifier mapping loss without destructive metadata deletion.
