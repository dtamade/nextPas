# nextpas.core.http Goal Tree

> Last updated: 2026-07-17 (multi-era ROADMAP + Goal Loop)
> Goal: make `nextpas.core.http` one of the best Free Pascal HTTP frameworks, with public API quality, correctness, lifecycle clarity, maintainability, and performance evidence that stand up against Go `net/http` and high-quality Rust HTTP stacks.
>
> **Forward execution (only)**: [`ROADMAP.md`](ROADMAP.md) — ordered Eras/Waves, Goal Loop, Inbox. This file is north star + stage truth, **not** a day-to-day backlog.

## North Star And Scope

`nextpas.core.http` should become a framework-quality HTTP module, not just a working H1 server/client:

- Public API first: handlers, router, client, headers, messages, static, and WebSocket surfaces must be coherent, testable, and stable before they are called complete.
- Correctness before ranking: malformed framing, redirect semantics, lifecycle, ownership, and timeout behavior must be proven before broad benchmark claims matter.
- HTTP should stay framework-shaped: synchronous public contracts, small interfaces, explicit ownership, and transport seams that do not leak runtime internals into consumers.
- Higher-level truth should improve lower layers: if HTTP reveals a bad contract in `net`, `async`, `platform`, `mem`, or `base`, the right fix is usually to improve the lower-layer contract, not to hide it behind an HTTP workaround.
- Evidence over slogans: public surface claims need focused tests; performance claims need isolated benchmarks or controlled comparators; cross-language claims need honest caveats.

This goal tree covers `core/src/nextpas.core.http*`, HTTP tests/examples/benchmarks, and HTTP module docs. It does not treat H2/H3 placeholders, static serving helpers, or WebSocket helpers as “done” simply because H1 is already strong.

## Current Position

| 项 | 状态 |
|----|------|
| G0–G5 骨架 | 完成 |
| non-H3 stage-complete | 完成（H3 诚实 blocked on QUIC） |
| Usability A–I | 完成 landed（含 Cookie site、FinalUrl/Version、proxy Basic-only） |
| 主 Makefile gate | ~35 focused suites |
| **NEXT** | **仅 [`ROADMAP.md`](ROADMAP.md)**（满自治 Goal Loop；本文件不写具体 Wave 名） |

四支柱、推荐路径、Done when、Gates、Inbox 均只在 ROADMAP 维护。

### Stage completion definition (non-H3)

HTTP can be called stage-complete only when all of these hold:

1. Public contracts and docs match source (`CONTRACT.md` / `ARCHITECTURE.md` / this tree).
2. Main Makefile gate is green with heaptrc-sensitive suites at `0 unfreed` where claimed.
3. H1 malformed/lifecycle/ownership open decisions are closed — keep-alive request-tail is **INV-12 final** (`CONTRACT.md` §3.1).
4. H2 is reachable from facade options with live proof; design exclusions remain explicit.
5. Runtime truth (threaded baseline + epoll poll path) is documented and not contradicted by gates.
6. Performance claims stay scoped; no fake H3 surface.

### Recent history

Long wave-by-wave fix notes and cycle assessments were moved to
[`archive/`](archive/README.md). Do not treat that directory as a backlog.

## Map

```text
nextpas.core.http
├── G0: Module control, docs, and verification discipline         [baseline]
├── G1: Stable public H1 surface                                 [landed]
├── G2: Correctness, safety, lifecycle, and ownership proof      [INV-12 final]
├── G3: API ergonomics and performance isolation                 [stage-closed]
├── G4: Protocol evolution seams (H2/H3 codec + registry + transport) [H2 facade-proven; H3 blocked]
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
- response charset auto-detection (`HttpReadResponseBodyStringAuto` — UTF-8, Latin-1, fallback)
- explicit response body release helper
- tighter redirect method/body/header ownership semantics
- `PostForm` convenience for `application/x-www-form-urlencoded`
- form encoding (`EncodeUrlEncodedForm`, `EncodeMultipartFormData`)
- `PostJson`/`PutJson`/`PatchJson` convenience for `application/json`
- `Delete` body overloads (IReader, string, TBytes) — parity with Post/Put/Patch
- `DeleteJson` convenience for `application/json` DELETE requests
- `WithBasicAuth`/`WithBearerAuth` auth decorator (returns new `IHttpClient` with automatic `authorization` header)
- `WithHeader` generic header injection decorator (chains with auth: `WithBearerAuth(token).WithHeader('Accept', 'application/json')`)
- `WithTimeout`/`WithMaxRedirects`/`WithFollowRedirects` per-request options decorator (overrides client defaults for a single request)
- `IHttpRequestWithOptions` interface + `THttpRequestOptions` record for per-request option overrides
- `THttpRequestBuilder` fluent request builder (Header, BasicAuth, BearerAuth, ContentType, Body, QueryParam, Timeout, MaxRedirects, FollowRedirects, Build)
- Builder / `SendStreaming` streaming body ownership API (non-buffered IReader, explicit close-on-send contract, redirect replayability caveat); `NewStreamingRequest` removed
- per-request timeout override at transport level (H1 transport checks `IHttpRequestWithOptions` to override `FOptions.Timeout`)
- `HttpEnsureSuccess` response status guard (raises EHttpError on non-2xx, returns response for chaining)

Still intentionally not claimed:

- (none currently)

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

P4 residual cost isolation is closed: ladder + benches restored. Further
performance work should profile specific L1/L2 hotspots with scoped caveats,
not collect more ranking tables.

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
- Test coverage vs h2-test-coverage-plan.md targets: client 55/55 (✅ closed), frame 37/35 (✅ closed), hpack 30/30 (✅ closed); session gap closed
- Real TLS runtime proof: ✅ `test_http_tls_real` (5 tests, self-signed cert + handshake + stream wrapper + H2 transport creation); 9 unfreed blocks are in openssl backend layer, not HTTP
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

**Not a live backlog.** Ordered work + Goal Loop: [`ROADMAP.md`](ROADMAP.md).

Closed eras (detail only in ROADMAP / archive): stage P1–P5, usability A–I, and any wave already marked landed on ROADMAP.

**Live ordered path and current NEXT**: only [`ROADMAP.md`](ROADMAP.md). If archive notes disagree, **ROADMAP wins**.

## Immediate Do-Not-Drift Rules

- Do not widen public API just to match a checklist from another ecosystem.
- Do not treat benchmark rows as durable performance truth without scoped caveats.
- Do not hide lower-layer design problems behind HTTP-only workarounds.
- Do not call exposed APIs complete without focused unit coverage and leak proof.
- Do not confuse “many tests” with “the right tests.”
