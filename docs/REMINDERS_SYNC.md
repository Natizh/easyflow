# Apple Reminders Synchronization

## Boundary

Apple Reminders/iCloud is EasyFlow's only cross-device synchronization infrastructure in v1. EasyFlow uses one dedicated Reminders list named `EasyFlow`. EventKit list/calendar APIs are the integration boundary; Reminders folders/groups are irrelevant, although the user may place the list in a folder manually.

EasyFlow has no custom server, webhook receiver, account, or background cloud service.

## Data ownership

| Data | Authority / location |
| --- | --- |
| Main Task title | Synchronized between EasyFlow and the dedicated Reminder |
| Main Task completion | Synchronized |
| Main Task existence/deletion | Synchronized |
| EasyFlow Main Task order | Local only; EasyFlow authoritative |
| Effort and style | Local only |
| Description | Local only |
| Steps, completion, notes, and style | Local only |
| Quick Notes and Attached Notes | Local only |
| Trash and UI state | Local only |

Do not encode local metadata into Reminder notes, priority, ordering, or other fields merely because storage is available. The deliberate boundary is title, completion, and existence.

## Identity

Every Main Task has an EasyFlow UUID. An EventKit calendar-item identifier is an external, nullable mapping and must not be treated as an eternal globally stable primary key. The mapping layer may retain reconciliation metadata as needed, but loss of one identifier never causes immediate destruction of local task context.

## Authorization and first run

Handle these states explicitly:

- `notDetermined`: explain the need and request Reminders access once;
- `authorized`/full access: discover or create the dedicated list and reconcile;
- `denied` or `restricted`: keep a graceful local workspace where technically reasonable and provide a clear recovery path to System Settings;
- unavailable/error: preserve local changes and surface a non-destructive retryable state.

First-run direction:

```text
launch
→ request required Reminders authorization
→ discover or create the EasyFlow list
→ configure/offer native launch at login
→ reconcile and enter normal operation
```

Do not repeatedly prompt after authorization has been decided.

## List discovery and creation

1. Fetch available Reminder calendars/lists after authorization.
2. Prefer a previously stored list identifier when it still resolves and represents the expected list.
3. Otherwise locate the dedicated list by the approved name `EasyFlow` using a documented deterministic rule when multiple matches exist.
4. If no suitable list exists, create it in an available writable Reminders source and persist its identifier.
5. If the source/list is unavailable or duplicated ambiguously, stop destructive reconciliation and present a recoverable state rather than guessing.

The exact duplicate-list choice should be documented during EventKit implementation based on API behavior; it must prioritize preservation over destructive convenience.

## Initial import and reconciliation

Initial reconciliation fetches reminders from the dedicated list and compares them with local Main Task mappings:

- mapped local/external pairs are reconciled for title, completion, and existence;
- an unmapped Reminder in the list becomes a local Main Task with a new EasyFlow UUID and local default metadata pending any unresolved effort UX policy;
- a local Main Task without a valid mapping is not automatically deleted; classify it for repair, recreation, or external-disappearance handling;
- local `sortIndex` is retained, and imported tasks receive deterministic local positions without mirroring Reminders order;
- enriched local metadata is never overwritten by external data that does not own it.

Conflict precedence for simultaneous title/completion changes must be documented against available EventKit timestamps and behavior during Chunk D. Until then, reconciliation must be conservative, idempotent, and non-destructive rather than inventing a hidden last-writer policy.

## EasyFlow-originated mutations

### Create

Persist an EasyFlow Main Task and create the corresponding Reminder in the dedicated list, then store the returned mapping. If external creation fails, retain local work with an explicit pending/error state and a retry path; do not silently discard the task.

### Rename

Update local presentation promptly, save the Reminder title asynchronously, and reconcile the result. Preserve the local task and report/retry on failure.

### Complete

Mark the Reminder complete and move the local task from active tasks to Recently Completed. Coordinate the operation so partial failure is visible and recoverable.

### Restore

No restore behavior exists until [OQ-003](OPEN_QUESTIONS.md#oq-003-restore-from-recently-completed) is resolved. If enabled, restoration must also uncomplete the Reminder.

### Delete

Delete the external Reminder and soft-delete the local record with all enriched context retained. A transport/permission/identifier failure must not be interpreted as permission to physically erase local context.

## External changes

EasyFlow observes EventKit store changes and schedules a coalesced reconciliation rather than high-frequency polling. It must eventually handle:

- external rename → update the local title cache while preserving local metadata;
- external completion → move the local task to Recently Completed;
- external deletion → record deliberate disappearance and retain local metadata according to reconciliation/soft-delete policy;
- a new Reminder in the EasyFlow list → import as a Main Task with a new UUID and deterministic local order.

Framework notifications indicate that data changed, not necessarily the exact semantic delta. Re-fetch and compare through the adapter; make repeated reconciliation safe.

## Failure and safety rules

- Authorization loss pauses external writes and never wipes local data.
- Missing or changed EventKit identifiers trigger reconciliation, not catastrophic deletion.
- A missing/renamed list triggers rediscovery and an explicit ambiguous/error state where necessary.
- All external operations are retryable or reach a clearly represented terminal user-action state.
- Never log Reminder titles or task/note bodies in production diagnostics.
- Never synchronize local-only fields by accident.
- Reconciliation runs are serialized and idempotent.

## Adapter and test seams

Wrap EventKit behind an interface supporting authorization status/request, list discovery/creation, reminder fetch, save, completion, deletion, and change observation. Convert EventKit objects into application-owned snapshots before reconciliation so most sync tests use fakes rather than live user data.

Automated tests cover:

- list found, missing, duplicated, and unavailable;
- initial import and deterministic local positioning;
- create/rename/complete/delete success and partial failure;
- external rename/completion/deletion/new item;
- identifier loss/change without local data destruction;
- repeated idempotent reconciliation;
- denied/restricted/revoked permission;
- preservation of every local-only field;
- retry and stale-result behavior.

Manual tests cover real permission dialogs, list creation, changes from another Apple device, iCloud delay, revoked access, external list deletion, and app relaunch during pending work. Use test Reminders content only; never place live private data in fixtures, logs, screenshots, or Git.
