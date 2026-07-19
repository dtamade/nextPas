# nextpas.core.async

Single-threaded async event loop for FreePascal with cross-platform backend support.

## Truth Matrix

### linux runtime truth
- io_uring is the linux completion backend (Linux 5.1+) via `TIoReactor` — `pbmCompletionQueue`
- `pbepoll` is a readiness-backed fallback (Linux 2.6+) via `TEpollReactor` — not a completion-equivalent replacement for file I/O
- Runtime auto-detection: `TryIoUringProbe` reports usable only when `io_uring_setup` returns a real fd (`LFd >= 0`); any setup failure falls back to epoll
- If the real io_uring queue creation fails after probing, `TPoller.Create` switches backend truth to epoll (or `pbUnsupported` if epoll create also fails)
- 18 timeout tests in `test_async_timeout` verify the race mechanism, `TTimeoutCtx` lifecycle, and heaptrc enforcement

### windows wine-runtime truth
- `TPoller` defines `pbIocp` and wires `TIocpReactor` (`nextpas.core.io.reactor.iocp`) — full completion implementation (not a stub): `CreateIoCompletionPort`, overlapped `ReadFile`/`WriteFile`, `WSASend`/`WSARecv`, `AcceptEx`/`ConnectEx`, `GetQueuedCompletionStatus`, `CancelIoEx`
- Backend model: `pbIocp` is `pbmCompletionQueue` (completion-based; positioned file I/O supported)
- Timeout cancel: `TryCancelByContext` → `CancelIoEx` on matching pending ops; completion packet still arrives (often `-ERROR_OPERATION_ABORTED`) and is discarded by Timeout CAS when the timer already won
- **truth=wine-runtime-smoke**: `test_reactor_iocp_wine` (socket + cancel) and `test_poller_windows_runtime_smoke` (overlapped file via poller) run under Wine on this worktree
- **source-contract + forced compile** gates remain (`test_async_windows_compile_gate`, `test_poller_windows_compile_gate`)
- **not windows runtime ready** as **native Windows host** evidence — no real Windows runner has proven the same suite on bare metal; Wine is not a host claim
- **platform wake is not the iocp owner** — Windows platform wake (or its future replacement) is owned by the platform poller seam, not by the IOCP completion port; IOCP and platform wake are separate plumbing paths

### macOS/FreeBSD truth
- Poller backend enum includes `pbKqueue` — readiness backend via `TKqueueReactor` (`nextpas.core.io.reactor.kqueue`)
- `TPoller` wires kqueue on `NEXTPAS_MACOS` / `NEXTPAS_FREEBSD` (`PollerDetectBackend` → `pbKqueue`)
- Backend model: `pbKqueue` is `pbmReadiness` (aligned with epoll; not completion-queue file I/O)
- Timeout cancel: best-effort like epoll (`TryCancelByContext` drops pending op + internal `-ECANCELED`)
- **source-contract + forced compile only** on Linux hosts: `test_async_kqueue_compile_gate` uses `-dNEXTPAS_FORCE_HOST_DARWIN` to prove the kqueue path compiles (FreeBSD FORCE_HOST currently blocked by unrelated `platform.thread` typing)
- **CI host hooks (Q9)**: `core/scripts/async-host-matrix.sh` runs dial/resolve + kqueue compile gate; Linux job strict; macOS job **best-effort** (`continue-on-error`) — still not a claim of full macOS async runtime parity unless that job is green without best-effort
- **not macOS/FreeBSD host-runtime proven** as a blanket claim in this worktree without green strict host jobs
- Pure idle loops without a valid backend wait on platform wake without I/O polling; with kqueue, I/O polling is available once Create succeeds

### DNS / Happy Eyeballs truth (Q6–Q9)
- `AsyncResolve`: single-worker AF_UNSPEC multi-A
- `AsyncResolveEx`: parallel A + AAAA + Resolution Delay (default 50ms), single merged callback
- `AsyncResolveStream`: incremental per-family callbacks for DNS-race-while-dialing
- `AsyncTcpDial`: concurrent staggered HE; host path races dial with late DNS family arrival
- Evidence: `test_net_async_resolve` / `test_net_async_dial` 0 leak on Linux; host matrix script above

### Backend Model Classification
- `pbiouring` and `pbiocp` are `pbmCompletionQueue` — these backends signal completion when an operation finishes, not readiness
- `pbepoll` is `pbmReadiness` — epoll signals when a fd is ready to read/write, not when an operation completes
- `pbkqueue` is `pbmReadiness` — kqueue EVFILT_READ/WRITE oneshot, same readiness class as epoll
- Positioned file I/O is only a completion-backend capability (`pbIoUring` / `pbIocp`); epoll/kqueue remain readiness-only and are not completion-equivalent replacements for file I/O
- `pbUnsupported` documents the absence of a usable backend
- Application semantics are not identical across backends; readiness fallbacks cannot stand in for completion-queue file I/O

## Features

- io_uring backend (Linux 5.1+) with epoll fallback (Linux 2.6+)
- kqueue readiness backend (macOS/FreeBSD) via `TKqueueReactor` / `pbKqueue`
- IOCP completion backend (Windows) via `TIocpReactor` / `pbIocp` (wine-runtime-smoke)
- Runtime backend detection (automatic best selection)
- Timer heap (min-heap, O(log n) schedule/cancel)
- I/O with deadline (timeout race mechanism with atomic CAS)
- Cross-thread wake (platform poller wake + Post via T1 MPSC, H3-1)
- Task state machine (idle/pending/completed/failed/timedout/cancelled)
- Zero memory leaks (`test_async_timeout` enforces heaptrc on the timeout race mechanism)

- Structured concurrency (TaskGroup with cancel/drain/wait semantics)
- Graceful shutdown management (phased shutdown with timeout)
- Generic timeout wrapper (IAsyncTimeout with cancel/timeout tracking)
- WhenAll/WhenAny combinators (parallel execution with completion notification)
- Async retry with exponential backoff (RetryWithBackoff/RetryWithFixedDelay)
- Async sync primitives (Mutex, Semaphore, Channel, CondVar)
  - Channel: `Send`/`TrySend` try-fail when full; `SendAsync` queues until space (or Close)
- Vectored I/O (AsyncReadv/AsyncWritev for scatter/gather operations)
- Async signal handling (IAsyncSignalHandler with signalfd integration)
- Buffer pool (IAsyncBufferPool for efficient buffer allocation/reuse)
- CancellationToken tree with parent/child propagation
- PostRef/PostMethod/ScheduleRef three-form callbacks (PostRef heap-wrapped for MPSC unmanaged constraint)
- PostEx/ScheduleEx with OnDiscard: Close frees heap-wrapped contexts without invoking callbacks
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
| `Close` | Release all resources (poller, wake poller, T1 MPSC pending queue) — discards unfired Post items; aborts pending I/O with -ECANCELED |
| `IsValid` | Returns True if poller, wake poller, and pending MPSC (`FPendingReady`) are all ready |
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
If the timer fires first, the callback receives `AResult = -110` (ETIMEDOUT) and the
loop best-effort cancels the pending poller op (`TryCancelByContext`).
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
- **Platform wake**: Cross-thread wake via the platform poller wake seam. `Post` enqueues onto a T1 MPSC queue (`TMpscQueueImpl<TAsyncPendingItem>`, H3-1) and wakes the loop. The loop thread is the single consumer (`DrainPending`).

## Backend Selection

At `TPoller.Create` time, the runtime probes for io_uring support:

1. Call `syscall(SYS_io_uring_setup, 1, @params)` with minimal params
2. Probe truth is usable only when the setup call returns a non-negative fd; the probe closes that fd immediately
3. Any setup failure (including ENOSYS and other errno values) leaves the backend on epoll
4. If the real io_uring queue creation fails after probing, create switches to epoll and re-validates the fallback

This means:
- Linux 5.1+ with io_uring: uses `TIoReactor` (io_uring) — `pbmCompletionQueue`
- Linux 2.6+ without io_uring, or after create-time io_uring failure: uses `TEpollReactor` (epoll) — `pbmReadiness`
- macOS/FreeBSD: uses `TKqueueReactor` (kqueue) — `pbmReadiness` (compile-gate proven; host runtime not claimed here)
- Windows: `TIocpReactor` / `pbIocp` — `pbmCompletionQueue` (**truth=wine-runtime-smoke**; not windows runtime ready on native host)

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
| `ScheduleEx` | Schedule with OnDiscard for abandoned timer context free |
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

### Resource lifecycle (Close / Free convention)

- `TAsyncLoop` is a **class** (heap-owned). Call `Free` (or `Close` then `Free`); `Destroy` calls `Close` and does not re-raise.
- `TAsyncLoop.Close` — idempotent: releases poller, wake poller, MPSC pending queue (discard unfired Posts); aborts pending I/O. May re-raise if an abort callback fails.
- Dependents (`IAsyncMutex`, `IAsyncShutdown`, …) store a non-owning `TAsyncLoop` reference — free dependents before the loop.
- `TPoller.Close` — releases backend reactor
- `TTimerHeap.Close` — nils callback references, frees heap storage

### Deadline exception semantics

- Deadline/timeout exceeded → `ETimeoutError` (callers can distinguish timeout from network failure)
- Actual network errors (connection reset, etc.) → `ENetworkError`
- Linux `SO_RCVTIMEO` returns `EAGAIN` on timeout — the implementation detects this when a
  deadline is set and re-raises as `ETimeoutError`

- **Timeout cancel (best-effort by backend)**: when the deadline timer wins the CAS race, the loop calls `TPoller.TryCancelByContext` on the `TimeoutCtx`:
  - **io_uring**: submits `IORING_OP_ASYNC_CANCEL` for the pending entry; the original CQE still arrives (often `-ECANCELED`) and is discarded by CAS
  - **epoll / kqueue**: removes the pending op from the reactor table and delivers an internal `-ECANCELED` completion so `TimeoutCtx` refcount is released (not a kernel read/write cancel)
  - **IOCP**: `CancelIoEx` by context; OVERLAPPED stays until GQCS delivers aborted completion (discarded by CAS if timer already won)
  - User API is unchanged: still exactly one user completion (`-110` or I/O result)
- **CancellationToken (Q1/Q5)**: optional `Token` on combinators / TaskGroup / `Async*TimeoutEx` (Read/Write/Recv/Send) — token cancel yields one completion (`-ECANCELED` on timeout-io); not a full Go `context` surface
- **IOCP wine-runtime-smoke**: reactor socket + cancel and poller overlapped file smoke under Wine; still **not windows runtime ready** on a native Windows host
- **WhenAll/WhenAny exist** in `async.combinators` (plus Ref variants).
- **No file descriptor lifecycle management**: the caller is responsible for opening/closing fds.


## OnDiscard ownership

- Heap-wrapped Post contexts must use `PostEx(..., OnDiscard)` when Close may discard before invoke.
- Timer contexts that need Close cleanup use `ScheduleEx(..., OnDiscard)`.
- `CancelTimer` does **not** run OnDiscard; the cancelling owner still cleans up.
- Close/Recycle runs OnDiscard for abandoned timer entries.
