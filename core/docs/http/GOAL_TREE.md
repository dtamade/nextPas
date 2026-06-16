# nextpas.core.http Goal Tree

> Last updated: 2026-06-16
> Goal: make `nextpas.core.http` one of the best Free Pascal HTTP frameworks, with public API quality, correctness, lifecycle clarity, maintainability, and performance evidence that stand up against Go `net/http` and high-quality Rust HTTP stacks.

## North Star And Scope

`nextpas.core.http` should become a framework-quality HTTP module, not just a working H1 server/client:

- Public API first: handlers, router, client, headers, messages, static, and WebSocket surfaces must be coherent, testable, and stable before they are called complete.
- Correctness before ranking: malformed framing, redirect semantics, lifecycle, ownership, and timeout behavior must be proven before broad benchmark claims matter.
- HTTP should stay framework-shaped: synchronous public contracts, small interfaces, explicit ownership, and transport seams that do not leak runtime internals into consumers.
- Higher-level truth should improve lower layers: if HTTP reveals a bad contract in `net`, `async`, `platform`, `mem`, or `base`, the right fix is usually to improve the lower-layer contract, not to hide it behind an HTTP workaround.
- Evidence over slogans: public surface claims need focused tests; performance claims need isolated benchmarks or controlled comparators; cross-language claims need honest caveats.

This goal tree covers `core/src/nextpas.core.http*`, HTTP tests/examples/benchmarks, and HTTP module docs. It does not treat H2/H3 placeholders, static serving helpers, or WebSocket helpers as “done” simply because H1 is already strong.

## Current Position

This lane is in **G2/G3/G4 active hardening**:

- G0 control and module discipline already exist in `AGENTS.md`, `core/AGENTS.md`, and `core/docs/design-conventions.md`.
- G1 stable H1 public surface is largely landed: server/client/router/headers/url/message/middleware/static/websocket all exist and already have substantial focused coverage.
- G2 correctness and lifecycle proof is well advanced: threaded and Linux `epoll` paths have broad raw-wire/server proof, client redirect/body ownership semantics are materially tighter, and examples have runnable smoke coverage.
- G3 API and performance isolation is still active: client ergonomics keeps closing real gaps, and H1 performance work is now splitting costs into parser, lazy header, writer, outbound, and full-chain layers.
- G4 H2 transport is now landed: server session + client transport + TLS ALPN + connection pool + RFC 9113 compliance are all implemented with 181 focused tests. H2 is production-transport-ready, not just a foundation slice. Remaining work is test coverage hardening (client -33, frame -17, hpack -15 tests vs plan) and documentation alignment. Session test hardening complete (55 tests, MaxConcurrentStreams check-order bug fixed).
- H3 remains blocked on the QUIC module (only QUIC crypto primitives exist).

## Map

```text
nextpas.core.http
├── G0: Module control, docs, and verification discipline         [active baseline]
├── G1: Stable public H1 surface                                 [mostly landed]
├── G2: Correctness, safety, lifecycle, and ownership proof      [advanced]
├── G3: API ergonomics and performance isolation                 [active]
├── G4: Protocol evolution seams (H2/H3 codec + registry + transport) [H2 transport landed, test hardening]
├── G5: Static/WebSocket graduation gates                        [helper-level stable]
└── G6: Cross-language benchmark truth and long-run positioning  [ongoing, not final]
```

## Stable Public Surface

These surfaces are already expected to behave like real framework APIs, not experimental helpers:

- `IHttpServer` / `THttpServer`
- `IHttpClient`
- `IHttpRouter`, `IHttpHandler`, `IHttpMiddleware`
- `IHttpHeaders`, `IHttpRequest`, `IHttpResponse`
- request/response helpers exposed through `nextpas.core.http`
- `ServeFile`, `ServeDir`
- `UpgradeWebSocket`, `IWebSocket`, `TWebSocketOptions`

Stability here means:

- public behavior is covered by focused tests
- nil/error/ownership edges are explicit
- transport/runtime details stay behind seams unless intentionally exposed
- helper additions should close real ergonomics gaps, not create a second overlapping API family

## Correctness And Safety Targets

HTTP is not done until these remain true:

- Every public API surface has direct focused coverage before it is called complete.
- Changed API behavior must have regression coverage and fresh heaptrc `0 unfreed memory blocks` evidence in the relevant focused gates.
- Request parsing, malformed framing, redirect semantics, timeout behavior, and response/body ownership must be explicitly defined and tested.
- Server runtime behavior must prefer precise wire-contract proof over synthetic “probably OK” reasoning.
- Error surfaces should fail fast at the API boundary when possible, instead of letting nil/access-violation behavior leak through transport internals.

Current strong areas:

- H1 parser and server malformed-input proof
- redirect semantics and response-body ownership
- server lifecycle shape
- runnable examples

Remaining pressure is mostly on keeping those guarantees coherent while the module evolves, not reopening broad undifferentiated correctness sweeps.

## Client Ergonomics Route

The client route should keep moving toward the best parts of Go/Rust ergonomics without copying names blindly.

Priority order:

1. request construction that makes method, URL, headers, body shape, and ownership obvious
2. response helpers that make read/release behavior obvious
3. redirect, timeout, and failure semantics that fail clearly at the public boundary
4. only then consider broader builder-style APIs

Already landed:

- URL string overloads for `NewRequest`
- string / bytes request body helpers
- string / bytes response body helpers
- explicit response body release helper
- tighter redirect method/body/header ownership semantics

Still intentionally not claimed:

- a full fluent request builder
- per-request redirect override
- per-request timeout override
- form/json helper families
- streaming/chunked request body ownership API
- response charset decoding or sniffing

Those can land later, but only after the contract shape is clear enough to stay stable.

## Server Runtime Route

The server route is not “make HTTP more async-looking.” The fixed direction is:

- keep the HTTP public surface synchronous and simple
- keep listener/runtime/backend ownership in `nextpas.core.net.server`
- keep H1/H2/H3 as protocol layers over common foundation seams
- let readiness-family and future completion-family runtimes share the same protocol-state ownership model

Current runtime truth:

- threaded is still the correctness baseline
- Linux `epoll` already has real poll-driven progress
- H1 successful response drain is reactor-owned on the poll path
- active + 1 queued response semantics already exist
- remaining runtime work is characterization and optimization, not a rewrite of the public model

High-risk runtime changes should stop for review if they broaden `net` / `async` / `platform` boundaries instead of clarifying them.

## Performance Evidence Route

Performance work should follow this order:

1. prove correctness and stable contracts first
2. isolate one cost center at a time
3. keep benchmark claims honest about what they do and do not prove
4. save broad ranking claims for later rounds

Current benchmark families already cover:

- server comparison runner
- Go `net/http` comparator
- Rust std-only comparator
- optional Hyper/Tokio comparator
- H1 parser microbenchmarks
- router dispatch
- header lookup
- H1 writer serialization
- H1 outbound drain
- full-chain keep-alive scenarios

Current isolation direction:

- parser adapter materialization
- lazy header access
- response writer serialization
- outbound drain
- writer plus outbound drain combination
- full-chain correlation with direct/router/middleware workload splits

What still matters most now is isolating remaining runtime/socket overhead and other non-parser/non-writer costs, not collecting more final benchmark tables too early.

## Protocol Evolution Gates

H2/H3 are important, but honesty matters more than placeholders.

Rules:

- No fake public API should imply that H3 already works.
- Future H3 work must preserve the same public HTTP contract unless there is a clear, documented reason to expand it.
- Rust or Go feature parity is not a reason to create empty abstractions.
- Current H2 transport policy is explicit: `http://` uses cleartext prior
  knowledge, `https://` requires negotiated ALPN `h2`, and HTTP/1.1
  `Upgrade: h2c` / `HTTP2-Settings` upgrade is not exposed.

H2 transport has landed as a complete implementation covering:

- **Frame codec** (RFC 9113): all 10 frame types, 13 error codes, frame validation, padded payload handling
- **HPACK** (RFC 7541): encoder/decoder, dynamic table with MRU cache, Huffman codec with 4-bit nibble decode, DecodeView zero-refcount path
- **Stream state machine**: 7-state machine, HEADERS/CONTINUATION assembly, trailer handling (pseudo-header/hop-by-hop forbidden), MaxHeaderListSize enforcement
- **Server session**: client preface validation, SETTINGS handshake, frame dispatch, per-stream request execution, MaxConcurrentStreams enforcement, GOAWAY with split last-stream tracking, poll-driven execution (ITcpServerPollDrivenSession)
- **Client transport**: synchronous RoundTrip, connection pool (MaxPoolSize-governed), stale pooled connection retry, server push rejection, PING/GOAWAY handling
- **TLS integration**: ALPN `h2` negotiation, SNI, session factory seam
- **RFC 9113 compliance**: HPACK table-size rules, MaxHeaderListSize (431/ENHANCE_YOUR_CALM), trailer section, GOAWAY last-stream tracking, MaxConcurrentStreams (REFUSED_STREAM)
- **Tests**: 181 focused tests across 7 suites + Go/Rust HPACK benchmark comparators

Design exclusions (by design, not gaps):
- h2c Upgrade path (cleartext H2 uses prior knowledge only)
- Server push (ENABLE_PUSH=0, PUSH_PROMISE → GOAWAY)
- CONNECT / WebSocket over H2 (future work)
- PRIORITY frame priority scheduling (parse, ignore — RFC permits)

Remaining H2 hardening:
- Test coverage vs h2-test-coverage-plan.md targets (client -33, frame -17, hpack -15); session gap closed
- Real TLS runtime proof (currently mock-based)
- Documentation alignment (this document and ARCHITECTURE.md)

H3 is blocked on the QUIC module. Only `nextpas.core.tls.quic.crypto.pas` (QUIC v1 crypto primitives) exists; no QPACK/HTTP3 frame/stream source code.

## Static And WebSocket Graduation Criteria

Static and WebSocket helpers are intentionally helper-level public surfaces today.

They should stay that way unless there is a clear graduation contract:

- static serving should not grow into a broader service family until range, streaming, cache, and binary-file semantics are defined tightly enough to stay stable
- WebSocket should not grow new option families or extension negotiation APIs without a clear ownership and behavior story
- more negative-case testing is not itself progress unless it closes a real behavior gap

Current rule of thumb:

- helper-level behavior can keep tightening
- helper-to-subsystem graduation needs an explicit design decision

## Verification And Done Criteria

A slice is only done when all of these are true for its scope:

- RED or source-contract was observed first
- minimal implementation passed the relevant focused gate
- changed public surface has direct focused tests
- heaptrc-sensitive focused tests report `0 unfreed memory blocks`
- `git diff --check` passes
- `make hygiene` passes
- the slice is committed as one clear rollback unit

The module is not “done” because one slice is green. The overall HTTP goal remains active until the controller explicitly stops it or a requirement-by-requirement audit proves the whole target is complete.

## Current Highest-Value Slices

As of 2026-06-07, the best next slices are:

1. **HTTP goal/control docs**
   - keep this goal tree and HTTP docs aligned with real status
   - separate stable architecture facts from active route decisions
2. **Runtime/socket cost isolation**
   - keep splitting non-parser/non-writer server cost with narrow benchmarks
   - avoid jumping straight to final benchmark rankings
3. **Client ergonomics, but only for real gaps**
   - prefer one stable helper over a sprawling builder surface
4. **Cross-language benchmark truth**
   - keep Rust std-only vs. Hyper/Tokio labeling honest
   - improve reproducibility and workload clarity before headline comparisons
5. **Protocol seam readiness**
   - continue H2 codec proof with broader HPACK integer/string/header-block coverage, frame-type-specific validation, and later QPACK/QUIC planning
   - improve H2/H3 seam quality only where it reduces future design risk without faking support

## Immediate Do-Not-Drift Rules

- Do not widen public API just to match a checklist from another ecosystem.
- Do not treat benchmark rows as durable performance truth without scoped caveats.
- Do not hide lower-layer design problems behind HTTP-only workarounds.
- Do not call exposed APIs complete without focused unit coverage and leak proof.
- Do not confuse “many tests” with “the right tests.”
