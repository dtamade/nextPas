# Windows `platform.watch` design — ReadDirectoryChangesW

**Status:** S1–S3 landed (create/add/close + RDCW poll + overflow AGAIN).
**Owner:** platform lane. **Public API:** do not change without a new batch.

**S1 decisions locked:** single-directory v1; recursive out of scope;
`Fd` unused on Windows (`DirHandle` is validity).
**S2:** OVERLAPPED + auto-reset event; poll returns **1** (event) / **0**
(timeout) matching Linux test convention; residual multi-record drain.
**S3:** rename Action mapping (old=Deleted, new=Created); overflow →
`PLATFORM_ERR_AGAIN` + re-arm (`ERROR_NOTIFY_ENUM_DIR`).
**Batch-22:** smoke hard-asserts create+delete on real Windows; Wine soft OK
(GHA 29752923987).
**Batch-23:** multi-dir slots (`PLATFORM_WATCH_WIN_MAX=8`); `add` returns
positive wd; `remove(wd)` closes slot; poll via WaitForMultipleObjects.
**RDCW arm:** if ReadDirectoryChangesW returns success with 0 bytes, keep
`Pending` so poll does not busy re-arm with empty wait set.

Stable portable API lives in `nextpas.core.platform.watch`. Linux (inotify)
and Darwin/FreeBSD (kqueue EVFILT_VNODE) already provide focused-runtime.
Windows is currently a permanent-looking stub:

```pascal
// {$IFDEF NEXTPAS_WINDOWS} after Batch-15 S2
platform_watch_create → 0 (DirHandle invalid until add)
platform_watch_add    → CreateFileW dir + OVERLAPPED + arm RDCW
platform_watch_poll   → 1 event / 0 timeout (RDCW + WaitForSingleObject)
platform_watch_close  → CancelIoEx + CloseHandle; idempotent 0
```

Wine smoke covers S1 + poll timeout + create-file event (wine residual OK).

---

## 1. Goals

1. Keep **`platform_watch_{create,add,poll,close}`** and **`TPlatformWatchEvent`**
   stable for consumers (fs.watch, tests).
2. Map a **minimal useful** Windows directory-watch path to those semantics.
3. Align **timeout** and **error** vocabulary with existing
   `PLATFORM_ERR_*` / Linux behaviour where practical.
4. Ship in **small slices** with focused tests; no “big bang” IOCP port.

## 2. Non-goals (v1)

- IOCP completion-port driven watch (belongs with io.reactor later if needed).
- Full FSEvents / kqueue feature parity (xattrs, rename chains, coalescing).
- Network share / SMB edge cases as promotion criteria.
- Recursive-by-default tree watches without an explicit flag (TBD in S3+).
- Changing the portable event record layout (256-byte name cap stays).

## 3. Proposed Windows model

### 3.1 Handle ownership

| Concept | Linux | Windows v1 |
| --- | --- | --- |
| Watcher validity | `Fd >= 0` (inotify fd) | Directory handle owned by watcher |
| Path registration | `inotify_add_watch` | One directory per watcher in v1 (see limits) |
| Event wait | `poll`/`read` on inotify | `ReadDirectoryChangesW` (+ WaitForSingleObject on event or overlapped) |

**Record shape:** today `TPlatformWatcher` is `Fd: Int32` plus BSD-only arrays.
Windows needs either:

- **A (preferred for v1):** `{$IFDEF NEXTPAS_WINDOWS}` fields:
  `DirHandle: HANDLE; NotifyEvent: HANDLE; Buffer: array[…] of Byte; Pending: Boolean`
  and keep `Fd` as a non-negative sentinel only when valid (`PtrInt` cast of handle is
  unsafe on 64-bit — **do not** store HANDLE in Int32). Better: `Fd` unused on Win;
  `IsValid` checks `DirHandle <> 0 and <> INVALID_HANDLE_VALUE`.
- **B:** opaque pointer to heap-allocated Win state (more indirection, cleaner ABI).

Recommendation: **A** with explicit Windows fields; document that `Fd` is
POSIX-oriented and invalid on Windows.

### 3.2 Create / Add / Close

1. **`platform_watch_create`**
   - Zero record; no OS resource yet **or** allocate notify event only.
   - Return 0.

2. **`platform_watch_add(path)`** (v1: **first path only**; second path →
   `PLATFORM_ERR_NOSPC` or `PLATFORM_ERR_UNSUPPORTED` until multi-dir)
   - UTF-8 path → UTF-16 via existing `platform.windows.utf16`.
   - `CreateFileW(path, FILE_LIST_DIRECTORY,
     FILE_SHARE_READ|WRITE|DELETE, nil, OPEN_EXISTING,
     FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED, nil)`.
   - Store handle; arm first `ReadDirectoryChangesW` (see poll).
   - Nil path → `PLATFORM_ERR_INVALID`.
   - Non-directory / not found → map via `platform_get_last_error`.

3. **`platform_watch_close`**
   - Cancel Io / close handle / close event; zero record.
   - Idempotent close returns 0.

### 3.3 Poll and `ReadDirectoryChangesW`

**Filter (v1):**
`FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_DIR_NAME |
 FILE_NOTIFY_CHANGE_ATTRIBUTES | FILE_NOTIFY_CHANGE_SIZE |
 FILE_NOTIFY_CHANGE_LAST_WRITE`

**Buffer:** fixed e.g. 16–64 KiB on the watcher record or heap once at add.

**Map `FILE_NOTIFY_INFORMATION.Action` → `TPlatformWatchEvent`:**

| Action | Created | Deleted | Modified | Notes |
| --- | --- | --- | --- | --- |
| FILE_ACTION_ADDED | true | | | |
| FILE_ACTION_REMOVED | | true | | |
| FILE_ACTION_MODIFIED | | | true | |
| FILE_ACTION_RENAMED_OLD_NAME | | true | | treat as delete of old |
| FILE_ACTION_RENAMED_NEW_NAME | true | | | treat as create of new |

- `Name` / `NameLen`: convert WCHAR name to UTF-8 into 256-byte cap (truncate safely).
- `IsDir`: best-effort (optional `GetFileAttributes` on full path; may race — document).

**Timeout semantics (`ATimeoutMs`):**

| Value | Behaviour |
| --- | --- |
| `-1` | Wait indefinitely for next notification batch |
| `0` | Non-blocking: if no completed read, return `PLATFORM_ERR_TIMEDOUT` |
| `>0` | Wait up to N ms; else `PLATFORM_ERR_TIMEDOUT` |

Implementation sketch: OVERLAPPED + auto-reset event; `GetOverlappedResult` /
`WaitForSingleObject` with timeout; on success walk notify records and return
**one** coalesced event per `poll` call (v1), re-arm RDCW after drain.

**Overflow (S3 locked):** `ERROR_NOTIFY_ENUM_DIR` → **`PLATFORM_ERR_AGAIN`**
and re-arm RDCW (no synthetic Modified).

## 4. Error mapping

| Condition | Code |
| --- | --- |
| Nil path / invalid watcher | `PLATFORM_ERR_INVALID` |
| Not a directory / not found | `platform_get_last_error` fold |
| Timeout | `PLATFORM_ERR_TIMEDOUT` |
| Too many watches (v1 multi-dir later) | `PLATFORM_ERR_NOSPC` |
| Unimplemented recursive flag | `PLATFORM_ERR_UNSUPPORTED` |

## 5. Wine and truth tiers

| Host | v1 claim |
| --- | --- |
| Linux / Darwin | unchanged focused-runtime |
| Real Windows GHA/VM | focused-runtime after implement + gate |
| Wine | may stay partial; keep separate wine-runtime-smoke; do not claim ci-matrix from Wine alone |

After implementation, update `test_platform_watch_wine` from pure UNSUPPORTED
assertions only if Wine reliably delivers RDCW (often flaky) — otherwise keep
honest residual.

## 6. Test plan

| Slice | Gate |
| --- | --- |
| S0 | Source-contract: Windows branch no longer only UNSUPPORTED (or staged IFDEF) |
| S1 | create / add valid dir / close; invalid path |
| S2 | poll: create file in watched dir → Created/Modified within timeout |
| S3 | delete; multi-event drain; timeout path |
| S4 | Linux regression `test_platform_watch` 17/0 |
| S5 | Optional Windows real gate in matrix **after** durable GHA green |

## 7. Implementation slices (suggested)

| Slice | Deliverable |
| --- | --- |
| **S0** | This design; watcher Windows field design locked |
| **S1** | create/add/close + FFI bindings if missing in `windows.ffi` |
| **S2** | poll one-shot + unit tests on real Windows |
| **S3** | rename/delete mapping + overflow policy |
| **S4** | Docs promote + optional matrix candidate |

Do **not** start S1 until S0 review accepts field layout and timeout rules.

## 8. FFI checklist (likely gaps)

Confirm / add in `nextpas.core.platform.windows.ffi` (or base):

- `ReadDirectoryChangesW`
- `FILE_NOTIFY_INFORMATION` layout
- `FILE_LIST_DIRECTORY`, notify filter constants
- `CancelIoEx` / `CancelIo` if needed for close

Reuse existing: `CreateFileW`, `CloseHandle`, `GetLastError` mapping,
UTF-16 helpers.

## 9. Open decisions (need owner sign-off before S1)

1. Single-directory v1 vs multi-path array like BSD `WatchFds`?
2. Recursive watch: out of scope vs `bWatchSubtree` flag on add?
3. Overflow: error vs synthetic event?
4. `IsDir` best-effort required for v1 tests or optional?

## 10. References in-tree

- `core/src/nextpas.core.platform.watch.pas` — portable API + stubs
- `core/tests/nextpas.core.platform.watch/test_platform_watch/` — Linux behaviour
- `core/tests/nextpas.core.platform.watch/test_platform_watch_wine/` — Win UNSUPPORTED smoke
- Higher layer: `nextpas.core.fs.watch` (if present) should keep consuming portable API only

---

*Batch-15a design landed as documentation only. Implementation is a later batch.*
