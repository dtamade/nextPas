# HTTP Phase 1 Completion — SIMD Fast Path + Polish + Optimization

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete HTTP Phase 1 with SIMD-accelerated parser fast path, facade updates, expanded test coverage, server optimizations, and prepare for production readiness.

**Architecture:** SIMD scan layer sits in front of llhttp strict parser. Facade re-exports server/client factories. Server gets object pooling to reduce per-request allocations. Client gets chunked response and streaming body support.

**Tech Stack:** Free Pascal, nextpas.core.simd (SSE2/SSSE3), nextpas.core.http.*, nextpas.core.bench.

---

## Task 1: SIMD H1 Scan Layer

**Files:**
- Create: `src/nextpas.core.http.impl.h1.scan.pas`
- Test: `tests/nextpas.core.http/test_http_h1scan/test_http_h1scan.lpr`
- Test: `tests/nextpas.core.http/test_http_h1scan/Makefile`

**Purpose:** Low-level SIMD scanning functions for HTTP/1.1 hot paths. No protocol semantics — just byte pattern finding.

**API:**
```pascal
function ScanFindCRLF(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeInt;
function ScanFindDoubleCRLF(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeInt;
function ScanFindColon(const ABuf: PAnsiChar; const ALen: SizeUInt): SizeInt;
function ScanValidateToken(const ABuf: PAnsiChar; const ALen: SizeUInt): Boolean;
```

**Implementation strategy:**
- Use `nextpas.core.simd.vec16` for 16-byte SIMD comparison
- `ScanFindCRLF`: CmpEq for `\r`, check next byte is `\n`
- `ScanFindDoubleCRLF`: find `\r\n\r\n` (header terminator)
- `ScanFindColon`: CmpEq for `:`
- `ScanValidateToken`: verify all bytes are valid HTTP token chars (no CTL, no separators)
- Scalar fallback for < 16 bytes or non-SSE2 platforms

**Tests (10+):**
- FindCRLF at various positions (start, middle, end, not found)
- FindDoubleCRLF (header block terminator)
- FindColon (header name:value separator)
- ValidateToken (valid, invalid with CTL, invalid with space)
- Empty input
- Input shorter than 16 bytes (scalar path)
- Input exactly 16 bytes (single SIMD pass)
- Large input (multiple SIMD passes)

---

## Task 2: HTTP Facade Update

**Files:**
- Modify: `src/nextpas.core.http.pas`

**Purpose:** Re-export server and client factories so consumers only need `uses nextpas.core.http`.

**Add to facade:**
```pascal
uses
  nextpas.core.http.server,
  nextpas.core.http.client;

type
  THttpServer = nextpas.core.http.server.THttpServer;
  THttpServerOptions = nextpas.core.http.server.THttpServerOptions;
  THttpClient = nextpas.core.http.client.THttpClient;
  THttpClientOptions = nextpas.core.http.client.THttpClientOptions;

function NewHttpServer(const AHandler: IHttpHandler): IHttpServer; overload; inline;
function NewHttpServer(const AHandler: IHttpHandler; const AOptions: THttpServerOptions): IHttpServer; overload; inline;
function NewHttpClient: IHttpClient; overload; inline;
function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient; overload; inline;
```

**Verify:** Compile facade, run existing tests.

---

## Task 3: Client Expanded Tests

**Files:**
- Modify: `tests/nextpas.core.http/test_http_client/test_http_client.lpr`

**Add tests:**
- Chunked transfer-encoding response
- Large body (64KB) streaming read
- Multiple sequential requests (connection not reused in v1)
- Request with custom method (PUT, DELETE)
- Response with no Content-Length and Connection:close (read until EOF)
- Empty body response (204)
- Client with 0 timeout (no timeout)

---

## Task 4: Server Object Pool Optimization

**Files:**
- Modify: `src/nextpas.core.http.server.pas`

**Purpose:** Reduce per-request heap allocations in the connection handler loop.

**Optimizations:**
1. Reuse parser across requests (already done via Reset)
2. Reuse buffered writer across requests (already done — single LBufWriter per connection)
3. Pre-allocate read buffer on stack (already done — LBuf array)
4. Avoid string allocations in hot path where possible

**Key change:** Move THttpRequest creation to use a pooled/reused headers object instead of creating new IHttpHeaders per request. Or: accept current allocation pattern and verify it's not the bottleneck via benchmark.

**Actually:** Run the server benchmark and profile. If 97K req/s is already good, document it and move on. The real optimization is SIMD fast path (Task 1).

**Verify:** Server benchmark still shows >= 90K req/s after any changes.

---

## Task 5: Integration Smoke Test — Full Stack

**Files:**
- Create: `tests/nextpas.core.http/test_http_smoke/test_http_smoke.lpr`
- Create: `tests/nextpas.core.http/test_http_smoke/Makefile`

**Purpose:** End-to-end smoke test using ONLY the facade (`uses nextpas.core.http`). Proves the facade is complete and usable.

**Tests:**
1. Start server with router + middleware, client makes GET → 200
2. Client POST with JSON body → server reads body, responds 201
3. Client follows redirect chain (server returns 301 → 200)
4. Server handles concurrent clients (2 threads × 10 requests each)
5. Client timeout triggers correctly
6. Router path params accessible in handler

This test uses ONLY `nextpas.core.http` + `nextpas.core.http.server` + `nextpas.core.http.client` — no internal modules.

---

## Execution Order

1. Task 2 (facade update) — quick, unblocks Task 5
2. Task 1 (SIMD scan) — independent, most complex
3. Task 3 (client tests) — expands coverage
4. Task 5 (smoke test) — validates everything works together
5. Task 4 (server optimization) — profile-driven, last

Each task: implement → test → verify 0 leaks → commit.

## Quality Gates

- All public APIs tested
- 0 memory leaks (heaptrc)
- 0 compiler warnings
- SIMD scan has scalar fallback
- Facade compiles and all existing tests pass
- Server benchmark >= 90K req/s maintained
