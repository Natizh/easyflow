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

Implemented selection order is: resolved persisted writable identifier; otherwise exactly one writable exact-name `EasyFlow` list; otherwise create only when none exists; otherwise stop with ambiguity. The user's manually created single list is reused when discovered and is never duplicated by that path.

## Initial import and reconciliation

Initial reconciliation fetches reminders from the dedicated list and compares them with local Main Task mappings:

- mapped local/external pairs are reconciled for title, completion, and existence;
- an unmapped Reminder in the list becomes a local Main Task with a new EasyFlow UUID and unrated effort until the user assigns `1...4` locally;
- a local Main Task without a valid mapping is not automatically deleted; classify it for repair, recreation, or external-disappearance handling;
- local `sortIndex` is retained, and imported tasks receive deterministic local positions without mirroring Reminders order;
- enriched local metadata is never overwritten by external data that does not own it.

Three-way reconciliation compares local synchronized core, the last successful baseline, and the current external snapshot per field. One-sided changes propagate; equal concurrent changes advance the baseline; different concurrent changes use sync-specific local-core time and EventKit modification time only when reliable. Missing evidence becomes a retained conflict/error rather than silent overwrite.

External imports append deterministically with `effort = NULL` and origin `reminders`. Equal titles never imply identity. Existing local active and completed tasks without mappings create distinct reminders.

## EasyFlow-originated mutations

### Create

Persist an EasyFlow Main Task and create the corresponding Reminder in the dedicated list, then store the returned mapping. If external creation fails, retain local work with an explicit pending/error state and a retry path; do not silently discard the task.

### Rename

Update local presentation promptly, save the Reminder title asynchronously, and reconcile the result. Preserve the local task and report/retry on failure.

### Complete

Mark the Reminder complete and move the local task from active tasks to Recently Completed. Coordinate the operation so partial failure is visible and recoverable.

### Completion is final

V1 has no restore or uncomplete operation. A completed Main Task and its Reminder remain completed.

### Delete

Mark external deletion pending and soft-delete the local record. Keep full enriched context only while the task is among the five newest deleted Main Tasks. When retention purges an older task, preserve a minimal deletion tombstone if EventKit still needs a retry. A transport, permission, or identifier failure does not erase one of the five retained task records.

## External changes

EasyFlow observes EventKit store changes and schedules a coalesced reconciliation rather than high-frequency polling. It handles:

- external rename → update the local title cache while preserving local metadata;
- external completion → move the local task to Recently Completed;
- external uncompletion of a completed task → keep the local task completed and mark the Reminder completed again;
- external deletion → require two confirmed disappearances, then soft-delete locally under the five-item retention policy;
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
- EventKit change notifications are coalesced for 500 ms and trigger one full-list reconciliation; there is no polling.
- A first full-list disappearance records a recoverable missing state; a second confirmed disappearance soft-deletes locally while preserving enriched metadata.
- Pending create/update/delete and retry count persist across relaunch.
- Full deleted-task records are limited to the newest five. A pending external delete for purged data retains only task UUID, Reminder identifier, deletion time, retry count, and a non-content error code until the Reminder is absent.

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
