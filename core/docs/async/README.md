# nextpas.core.async

Single-threaded async event loop for FreePascal with cross-platform backend support.

## Truth Matrix

### linux runtime truth
- io_uring backend (Linux 5.1+) via `TIoReactor`
- epoll fallback (Linux 2.6+) via `TEpollReactor`
- Runtime auto-detection: probes io_uring at `TPoller.Create` time; falls back to epoll on ENOSYS
- 18 timeout tests in `test_async_timeout` verify the race mechanism, `TTimeoutCtx` lifecycle, and heaptrc enforcement

### windows compile truth
- `TPoller` defines `pbIocp` in the backend enum on Windows, but `TIocpReactor` is currently a stub that raises `ENetworkError`
- `nextpas.core.io.reactor.iocp.pas` contains the IOCP function declarations (`CreateIoCompletionPort`, `GetQueuedCompletionStatus`, `PostQueuedCompletionStatus`, `CancelIoEx`) with `external 'kernel32.dll'`
- Backend model: `pbIocp` is classified as `pbmCompletionQueue` (completion-based, not readiness-based)
- **source-contract + forced compile only**: tests exist (`test_async_windows_compile_gate`, `test_poller_windows_compile_gate`) that verify the Windows source compiles, but there are no runtime tests
- **not windows runtime ready** — no Windows runner has proven runtime correctness on an actual Windows host
- **platform wake is not the iocp owner** — Windows platform wake (or its future replacement) is owned by the platform poller seam, not by the IOCP completion port; IOCP and platform wake are separate plumbing paths

### macOS/FreeBSD truth
- Poller backend enum does **not** have a `pbKqueue` entry — no `pbkqueue` backend
- `nextpas.core.platform.io.base.pas` defines a `TKqueueReactor` but the poller does not wire it in
- macOS/FreeBSD currently gets `pbUnsupported` when the poller fails to detect io_uring
- `pbUnsupported` documents the `pbunsupported` fallback for any host that is not Linux with io_uring or epoll
- Pure idle loops on unsupported backends will simply wait on platform wake without I/O polling

### Backend Model Classification
- `pbiouring` and `pbiocp` are `pbmCompletionQueue` — these backends signal completion when an operation finishes, not readiness
- `pbepoll` is `pbmReadiness` — epoll signals when a fd is ready to read/write, not when an operation completes
- `pbUnsupported` documents the absence of a usable backend

## Features

- io_uring backend (Linux 5.1+) with epoll fallback (Linux 2.6+)
- Runtime backend detection (automatic best selection)
- Timer heap (min-heap, O(log n) schedule/cancel)
- I/O with deadline (timeout race mechanism with atomic CAS)
- Cross-thread wake (platform poller wake + Post queue)
- Task state machine (idle/pending/completed/failed/timedout/cancelled)
- Zero memory leaks (`test_async_timeout` enforces heaptrc on the timeout race mechanism)

## Quick Start

```pascal
uses
  nextpas.core.async, nextpas.core.time.base, nextpas.core.time.deadline;

procedure OnTimer(AContext: Pointer);
begin
  WriteLn('Timer fired!');
  TAsyncLoop(AContext^).Stop;
end;

var
  Loop: TAsyncLoop;
begin
  Loop := TAsyncLoop.Create;

  // Schedule a timer to fire after 100ms
  Loop.Schedule(TDuration.FromMilliseconds(100), @OnTimer, @Loop);

  // Run the event loop (blocks until Stop is called)
  Loop.Run;
  Loop.Close;
end.
```

## API Reference

### TAsyncLoop

| Method | Description |
|--------|-------------|
| `Create(AQueueDepth)` | Create loop with I/O queue depth (default 64) |
| `Close` | Release all resources (poller, wake poller, mutex) — aborts pending I/O with -ECANCELED |
| `IsValid` | Returns True if all three owned resources are initialized: poller, wake poller, and pending queue mutex |
| `Run` | Run loop until `Stop` is called |
| `RunOnce` | Process one batch of events then return |
| `Poll` | Non-blocking: fire timers + poll I/O + drain pending |
| `Stop` | Signal the loop to exit `Run` |

### Timer Scheduling

| Method | Description |
|--------|-------------|
| `Schedule(ADelay, ACallback, AContext)` | Fire callback after duration |
| `ScheduleAt(ADeadline, ACallback, AContext)` | Fire callback at deadline |
| `CancelTimer(AHandle)` | Cancel a pending timer (returns True if cancelled) |
| `AsyncSleep(ADelay, ACallback, AContext)` | Alias for Schedule (semantic clarity) |

### Async I/O

| Method | Description |
|--------|-------------|
| `AsyncRead(AFd, ABuf, ALen, AOffset, ACallback, AContext)` | Async file/pipe read |
| `AsyncWrite(AFd, ABuf, ALen, AOffset, ACallback, AContext)` | Async file/pipe write |
| `AsyncAccept(AFd, AAddr, AAddrLen, AFlags, ACallback, AContext)` | Async socket accept |
| `AsyncRecv(AFd, ABuf, ALen, AFlags, ACallback, AContext)` | Async socket recv |
| `AsyncSend(AFd, ABuf, ALen, AFlags, ACallback, AContext)` | Async socket send |

### I/O with Timeout

| Method | Description |
|--------|-------------|
| `AsyncReadTimeout(AFd, ABuf, ALen, AOffset, ADeadline, ACallback, AContext)` | Read with deadline |
| `AsyncWriteTimeout(AFd, ABuf, ALen, AOffset, ADeadline, ACallback, AContext)` | Write with deadline |
| `AsyncRecvTimeout(AFd, ABuf, ALen, AFlags, ADeadline, ACallback, AContext)` | Recv with deadline |
| `AsyncSendTimeout(AFd, ABuf, ALen, AFlags, ADeadline, ACallback, AContext)` | Send with deadline |

Timeout methods use a race mechanism: a timer and the I/O operation run concurrently.
If the timer fires first, the callback receives `AResult = -110` (ETIMEDOUT).
If I/O completes first, the timer is cancelled automatically.
The mechanism uses atomically-reference-counted `TTimeoutCtx` to ensure exactly one callback fires.

### Cross-Thread Communication

| Method | Description |
|--------|-------------|
| `Post(ACallback, AContext)` | Enqueue callback from any thread (thread-safe) |
| `Wake` | Wake the loop from sleep through the platform poller wake seam (thread-safe) |

### TTimerHeap (low-level)

| Method | Description |
|--------|-------------|
| `Create` | Initialize an empty timer heap |
| `Close` | Release all heap storage and nil callback references (prevents leaks) |
| `Schedule(ADeadline, ACallback, AContext)` | Schedule at absolute deadline |
| `ScheduleAfter(ADelay, ACallback, AContext)` | Schedule after relative delay |
| `Cancel(AHandle)` | Tombstone-cancel a timer |
| `NextDeadline` | Peek the earliest non-cancelled deadline |
| `FireExpired` | Fire all expired timers, return count |
| `Count` | Number of entries in the heap |

### TAsyncTask (state machine)

| Method | Description |
|--------|-------------|
| `Create` | Initialize in Idle state |
| `Complete(AResult)` | Transition to Completed |
| `Fail(AResult)` | Transition to Failed |
| `Timeout` | Transition to TimedOut (result = -110) |
| `Cancel` | Transition to Cancelled |
| `OnComplete(ACallback, AContext)` | Register completion callback |
| `Status` / `IsCompleted` / `IsDone` | Query state |

### Callback Signatures

```pascal
type
  TAsyncCallback = procedure(AContext: Pointer);
  TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);
```

## Architecture

```
+------------------+
|   TAsyncLoop     |  (integrates all components)
+--------+---------+
         |
    +----+----+----------+
    |         |          |
+---v---+ +---v----+ +---v------+
| TPoller| |TTimerHeap| | platform |
| (I/O)  | | (timers) | | wake    |
+---------+ +----------+ +----------+
    |
    +--- io_uring (TIoReactor) — pbmCompletionQueue
    |
    +--- epoll (TEpollReactor) — pbmReadiness
```

- **TPoller**: Unified I/O backend that dispatches to io_uring or epoll based on runtime detection.
- **TTimerHeap**: Min-heap with tombstone cancellation. Entries are recycled via a free-list.
- **Platform wake**: Cross-thread wake via the platform poller wake seam. `Post` appends to a mutex-protected queue and wakes the loop. The loop drains the queue on each iteration.

## Backend Selection

At `TPoller.Create` time, the runtime probes for io_uring support:

1. Call `syscall(SYS_io_uring_setup, 1, @params)` with minimal params
2. If the syscall returns a valid fd (or any error other than ENOSYS), io_uring is available
3. Otherwise, fall back to epoll

This means:
- Linux 5.1+ with io_uring: uses `TIoReactor` (io_uring) — `pbmCompletionQueue`
- Linux 2.6+ without io_uring: uses `TEpollReactor` (epoll) — `pbmReadiness`
- macOS/FreeBSD: returns `pbUnsupported` — no functional I/O backend
- Windows: compile-only `pbIocp` stub — `pbmCompletionQueue`

Check the active backend at runtime:
```pascal
if Loop.FPoller.Backend = pbIoUring then
  WriteLn('Using io_uring')
else
  WriteLn('Using epoll');
```

## Thread Safety

- **TAsyncLoop is single-threaded**: all callbacks execute on the loop thread.
- **Post/Wake are thread-safe**: can be called from any thread to enqueue work.
- **Do NOT** call `Schedule`, `AsyncRead`, `Run`, or other methods from non-loop threads.

Pattern for cross-thread communication:
```pascal
// From worker thread:
Loop.Post(@HandleResult, MyDataPtr);

// HandleResult runs on the loop thread:
procedure HandleResult(AContext: Pointer);
begin
  // Safe to call Loop.Schedule, AsyncRead, etc. here
end;
```

## Event Loop Execution Model

`Run` implements a busy-poll-then-sleep loop:

1. Drain pending callbacks from cross-thread queue
2. Fire expired timers
3. Flush + poll I/O (non-blocking)
4. If any work was done, loop immediately (step 1)
5. If idle, sleep on platform poller wake until either a wake signal arrives or a timer expires

The wake timeout:
- With no pending I/O (pure idle): may sleep indefinitely on platform wake — `pure idle waits may block indefinitely`
- With pending I/O: the wait is capped so the loop can service I/O completion callbacks — `pending i/o caps wake-only waits`

## Design Decisions

### Schedule naming convention

`TAsyncLoop.Schedule` and `TTimerHeap.Schedule` use **different semantics**:

| Layer | `Schedule` takes | `ScheduleAt`/`ScheduleAfter` takes |
|-------|------------------|-----------------------------------|
| `TAsyncLoop` | `TDuration` (relative delay) | `ScheduleAt(TDeadline)` (absolute time) |
| `TTimerHeap` | `TDeadline` (absolute deadline) | `ScheduleAfter(TDuration)` (relative delay) |

This is intentional: `TAsyncLoop` is the user-facing API where relative delay is the common case,
so `Schedule` is the convenient shortcut. `TTimerHeap` is the internal engine where absolute
deadlines are the native representation.

### Two callback signatures

The framework uses two callback types for different purposes:

```pascal
TAsyncCallback = procedure(AContext: Pointer);
  // Used by: Schedule, Post, AsyncSleep (no result to report)

TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);
  // Used by: AsyncRead/Write/Accept/Recv/Send (carries operation result)
```

This split avoids forcing a result parameter into timer/post callbacks where it would always be ignored.
`TAsyncTask.OnComplete` uses `TAsyncCallback` — the result is fetched separately via `GetResult`.

### Resource lifecycle (Close convention)

All heap-owning record types use `Close` for teardown:
- `TAsyncLoop.Close` — releases poller, wake poller, mutex; aborts pending I/O
- `TPoller.Close` — releases backend reactor
- `TTimerHeap.Close` — nils callback references, frees heap storage

### Deadline exception semantics

- Deadline/timeout exceeded → `ETimeoutError` (callers can distinguish timeout from network failure)
- Actual network errors (connection reset, etc.) → `ENetworkError`
- Linux `SO_RCVTIMEO` returns `EAGAIN` on timeout — the implementation detects this when a
  deadline is set and re-raises as `ETimeoutError`

- **Timeout is notify-only**: the timer fires the callback with ETIMEDOUT but does not cancel the kernel I/O operation. The I/O will still complete eventually (and be discarded).
- **No kqueue backend**: the poller backend enum and platform io base define no kqueue variant for the async module's use. no `pbkqueue` backend.
- **IOCP is compile-only**: `pbIocp` exists in the backend enum and the reactor stub compiles, but no runtime verification has been done on Windows.
- **No WhenAll/WhenAny combinators**: tasks must be composed manually via callbacks.
- **No file descriptor lifecycle management**: the caller is responsible for opening/closing fds.
