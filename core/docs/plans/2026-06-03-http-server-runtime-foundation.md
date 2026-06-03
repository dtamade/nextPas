# HTTP Server Runtime Foundation Plan

Canonical source now lives at
[docs/net/ARCHITECTURE.md](/home/dtamade/projects/nextPas/core/docs/net/ARCHITECTURE.md:1).
This plan is kept as the original decision record; if wording diverges, the
formal architecture document wins.

## Goal

Freeze the runtime direction for `nextpas.core.http` before more protocol work lands.
The immediate objective is not to optimize the current thread-per-connection server in
place. The objective is to move server ownership to a reusable TCP server foundation
that can support threaded, evented, and Windows-native backends without breaking the
public HTTP contract.

## Decision

Use a mixed model:

- Public programming model: Go-like
- Internal runtime and protocol split: Tokio/Hyper-like
- Cross-platform I/O backend strategy: libuv-like
- Foundation ownership: `nextpas.core.net.server`

This means:

- Keep the public HTTP surface simple and synchronous.
- Move listener, runtime backend, connection ownership, shutdown, and worker handoff
  out of `nextpas.core.http.server`.
- Keep HTTP responsible for HTTP protocol state, not socket scheduling.
- Treat Windows IOCP as a first-class target, not an optional follow-up or a
  `WSAPoll` fallback end state.

## Why this plan

### Go gives the right public model, but not the right internal implementation

Go's `net/http` keeps handlers simple, and that is worth preserving.
But Go can do that because the runtime has goroutines and a mature scheduler.
`nextPas` does not currently have that equivalent, so copying Go's internal shape
would collapse into a traditional OS thread server.

### Tokio/Hyper gives the right internal ownership split

Tokio separates I/O driver, scheduler, and timer. Hyper treats one connection as a
protocol state object that is driven by an external runtime. That split maps well onto
the current `nextPas` codebase and avoids welding HTTP semantics to one runtime model.

### libuv gives the right backend discipline

libuv's backend strategy is the right cross-platform posture:

- Linux: `epoll`
- macOS / FreeBSD: `kqueue`
- Windows: `IOCP`

That is the standard we should follow. The public API should not look like libuv, but
the backend policy should.

## Current repo truth

This is no longer just a proposal. The foundation split has already landed:

- [src/nextpas.core.net.server.base.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.base.pas:1)
  exposes `threaded` / `epoll` / `kqueue` / `iocp` as backend intent.
- [src/nextpas.core.net.server.intf.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.intf.pas:1)
  exposes the real server seams: `ITcpServer`, `ITcpServerSession`,
  `ITcpServerSessionFactoryWithContext`, `ITcpServerWorkerHandoff`.
- [src/nextpas.core.net.server.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.pas:1)
  now also exposes the backend factory registry seam:
  `RegisterTcpServerFactory`, `TryGetTcpServerFactory`, `ResolveTcpServer`.
- [src/nextpas.core.net.server.threaded.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.threaded.pas:38)
  is the correctness baseline backend.
- [src/nextpas.core.net.server.epoll.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.server.epoll.pas:40)
  is already phase-1 evented: listener readiness and `TryAccept` are event-driven,
  while connection execution is still worker-driven.
- [src/nextpas.core.http.server.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.server.pas:127)
  no longer owns the runtime loop; it wires HTTP onto `NewTcpServer(...)`.
- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas:113)
  already has `TH1ServerConnectionState` as a protocol-owned session object.

What is still missing is narrower and clearer:

- no shared phase-2 per-connection evented driver yet
- no `kqueue` / `IOCP` concrete backend yet

## Architecture to freeze

### 1. Foundation layer: `nextpas.core.net.server`

This module owns reusable TCP server runtime behavior. It does not understand HTTP.

Its responsibilities:

- listen / accept
- runtime backend selection
- connection registration and shutdown
- timeout and close coordination
- worker handoff
- detach / hijack-friendly ownership
- native socket seam for advanced backends

This module should become the shared base for future TCP protocol servers, not only
HTTP.

### 2. Protocol layer: `nextpas.core.http`

HTTP owns protocol semantics only.

Its responsibilities:

- request parsing
- response serialization
- keep-alive semantics
- pipelining / request-tail isolation
- protocol-level ownership transfer, such as hijack
- per-connection HTTP state objects such as `TH1ServerConnectionState`

HTTP must not own thread creation, event loop policy, or Windows-specific I/O
semantics.

### 3. Public application layer

The public HTTP model stays synchronous and straightforward:

- `IHttpServer`
- `IHttpHandler`
- `IHttpRequest`
- `IHttpResponseWriter`

Handlers remain simple and synchronous for now. Evented backends must hand work off to
workers instead of running arbitrary handler code on the reactor thread.

## Module direction

The target shape is:

```text
nextpas.core.net.server.base
nextpas.core.net.server.intf
nextpas.core.net.server.threaded
nextpas.core.net.server.epoll
nextpas.core.net.server.kqueue
nextpas.core.net.server.iocp
```

HTTP then depends on the server foundation instead of owning its own runtime loop.

We should avoid a large inheritance-based `BaseServer` class. A reusable runtime module
and narrow interfaces are a better fit for `nextPas` than a deep class hierarchy.

If a convenience wrapper is ever added later, it must stay thin and must not become the
true runtime owner again.

## Why not start from a `BaseServer`

This decision is now fixed.

The reusable part across protocol servers is the runtime foundation:

- listen / accept
- backend selection
- connection ownership and shutdown
- worker handoff
- platform-specific I/O strategy

Those concerns belong in `nextpas.core.net.server`, not in an inheritance-heavy
protocol server base class.

A `BaseServer` approach would likely decay in three ways:

1. Protocol hooks would accumulate in the base class until runtime and protocol
   responsibilities were mixed together.
2. Evented backends and Windows `IOCP` would be forced into a shape designed around
   thread-oriented control flow.
3. Protocol-specific behavior such as hijack, pipelining, and half-close handling
   would leak into the base layer and become harder to reason about.

The selected model is therefore:

- shared runtime as a foundation module
- protocol behavior via composition
- one connection = one protocol state object
- backend-specific execution hidden behind narrow runtime contracts

## Runtime rules

These rules are fixed unless a later architecture review replaces them explicitly.

### Public model

- Keep a Go-like surface for server consumers.
- Do not expose callback-style event-loop APIs in the HTTP public facade.

### Internal model

- Treat one connection as one protocol state object.
- Let a runtime backend drive that state object.
- Do not let protocol code own thread creation or event-loop backend details.

### Worker model

- Threaded backend may execute the handler inline on its connection worker.
- Evented backends must not execute unbounded handler code on the reactor thread.
- Evented backends need an explicit worker handoff seam.

### Windows model

- Windows target is IOCP.
- `WSAPoll` is not an acceptable final architecture.

### Body model

- Keep the current public `IHttpRequest.Body: IReader` contract for now.
- Do not reopen body streaming design in the same batch as the runtime foundation move.
- True streaming / spill / spool work is phase-two performance work after the runtime
  base is stable.

## Alternatives rejected

### Keep runtime private to HTTP

Rejected because the same problem will reappear for every TCP protocol server.

### Build only a better thread-per-connection server

Rejected because it improves the current implementation but does not create a durable
cross-platform runtime foundation.

### Convert the public HTTP API to async first

Rejected because it would multiply surface breakage before the runtime boundaries are
correct.

### Standardize on readiness APIs everywhere, including Windows

Rejected because Windows should be built around IOCP/proactor semantics, not forced
through a second-rate compatibility path.

## Fixed execution plan

### Phase 0: Freeze the architecture

- Status: done

- Write this document
- Use it as the source of truth for the runtime direction

### Phase 1: Create `nextpas.core.net.server` skeleton

- Status: done

- Add foundation base and interface units
- Add the first ownership seams for listener, connection runtime, shutdown, and
  handoff
- No evented backend yet

### Phase 2: Implement the threaded backend first

- Status: done

- Recreate today's semantics through the new foundation
- Migrate HTTP to consume the foundation
- Keep behavior stable while ownership moves out of HTTP

### Phase 3: Finish the HTTP protocol split

- Status: mostly done for H1

- Continue reducing `http.server` into facade / composition code
- Keep moving protocol state into reusable connection-state objects

### Phase 4: Add Linux `epoll` backend

- Status: phase 1 done, phase 2 pending

- Drive the same HTTP connection-state objects through the new foundation
- Use worker handoff for handler execution
- Prove the backend without reopening public HTTP contracts

### Phase 5: Add `kqueue` backend

- Status: pending

- Match the contract already proven by the threaded and epoll backends

### Phase 6: Add Windows IOCP backend

- Status: pending

- Make Windows a first-class backend
- Do not route the long-term design through `WSAPoll`

### Phase 7: Performance phase

- request-body streaming seam
- spill / spool
- buffer pools
- write coalescing
- `io_uring` evaluation as an advanced Linux backend
- benchmark against Go, Rust, and FPC RTL baselines

## Current implementation truth

By the time this record is updated, the direction has already started landing:

- `nextpas.core.net.server.base` exposes backend selection, including `threaded`,
  `epoll`, `kqueue`, and `iocp`.
- `nextpas.core.net.server.intf` exposes the reusable runtime seam.
- `nextpas.core.net.server.threaded` provides the first concrete backend.
- `nextpas.core.http` has already begun moving runtime ownership out of
  `http.server`.

So the architecture is no longer tentative. Future work should treat this document and
`docs/net/ARCHITECTURE.md` as a frozen decision and focus on incremental delivery.

## Acceptance gates by phase

### Foundation phases

- No public HTTP contract regressions
- Focused tests for changed seams
- Heaptrc clean on changed-surface suites

### Backend phases

- Keep-alive
- pipelining
- malformed request rejection
- hijack ownership
- shutdown semantics

### Performance phase

- Benchmarks must compare against at least:
  - `nextPas` previous baseline
  - Go reference implementation
  - Rust reference implementation

## Immediate next batch

The next implementation batch should do only this:

1. keep threaded and `epoll` phase-1 contract parity stable
2. design and land the shared phase-2 per-connection evented driver seam
3. make that driver reusable for future `kqueue` / `IOCP`
4. keep public HTTP behavior unchanged and prove every changed seam with focused tests

That is the smallest move that advances the final architecture without reopening
unrelated protocol design questions.
