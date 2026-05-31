# nextpas.core.async

Production-quality single-threaded async event loop for FreePascal.

## Features

- io_uring backend (Linux 5.1+) with epoll fallback (Linux 2.6+)
- Runtime backend detection (automatic best selection)
- Timer heap (min-heap, O(log n) schedule/cancel)
- I/O with deadline (timeout race mechanism)
- Cross-thread wake (eventfd + Post)
- Task state machine (idle/pending/completed/failed/timedout/cancelled)
- Zero memory leaks (31+ tests across 3 suites verify)

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
| `Close` | Release all resources (poller, eventfd, mutex) |
| `IsValid` | Returns True if poller and eventfd are initialized |
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

### Cross-Thread Communication

| Method | Description |
|--------|-------------|
| `Post(ACallback, AContext)` | Enqueue callback from any thread (thread-safe) |
| `Wake` | Wake the loop from sleep (thread-safe) |

### TTimerHeap (low-level)

| Method | Description |
|--------|-------------|
| `Create` | Initialize an empty timer heap |
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
| TPoller| |TTimerHeap| | eventfd  |
| (I/O)  | | (timers) | | (wake)   |
+---------+ +----------+ +----------+
    |
    +--- io_uring (TIoReactor)
    |
    +--- epoll (TEpollReactor)
```

- **TPoller**: Unified I/O backend that dispatches to io_uring or epoll based on runtime detection.
- **TTimerHeap**: Min-heap with tombstone cancellation. Entries are recycled via a free-list.
- **eventfd + PendingQueue**: Cross-thread wake mechanism. `Post` appends to a mutex-protected queue and writes to eventfd. The loop drains the queue on each iteration.

## Backend Selection

At `TPoller.Create` time, the runtime probes for io_uring support:

1. Call `syscall(SYS_io_uring_setup, 1, @params)` with minimal params
2. If the syscall returns a valid fd (or any error other than ENOSYS), io_uring is available
3. Otherwise, fall back to epoll

This means:
- Linux 5.1+ with io_uring: uses `TIoReactor` (io_uring)
- Linux 2.6+ without io_uring: uses `TEpollReactor` (epoll)
- The application code is identical regardless of backend

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

1. Drain eventfd + pending callbacks
2. Fire expired timers
3. Flush + poll I/O (non-blocking)
4. If any work was done, loop immediately (step 1)
5. If idle, sleep on eventfd via `poll()` with timeout capped at 10ms

This ensures low latency when busy and low CPU usage when idle.

## Known Limitations

- **Timeout is notify-only**: the timer fires the callback with ETIMEDOUT but does not cancel the kernel I/O operation. The I/O will still complete eventually (and be discarded).
- **kqueue/IOCP backends are stubs**: only Linux is fully implemented.
- **No WhenAll/WhenAny combinators**: tasks must be composed manually via callbacks.
- **No file descriptor lifecycle management**: the caller is responsible for opening/closing fds.
