# HTTP Phase 1 Implementation Plan — Base + Intf + Headers + URL + Router

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the shared application layer of nextpas.core.http (types, interfaces, headers, URL parsing, radix-tree router) — everything that's protocol-version-independent and doesn't need llhttp.

**Architecture:** Bottom-up: base types → interfaces → headers collection → URL parser → router. Each unit is independently testable. Router uses radix tree for O(path_length) lookup with path parameters (`:id`) and wildcards (`*`).

**Tech Stack:** Free Pascal (objfpc), nextpas.core.text, nextpas.core.collections, nextpas.core.errors, nextpas.core.io.intf, nextpas.core.testing.

**Reference:** `docs/http/ARCHITECTURE.md`, `docs/design-conventions.md`

---

## Task 1: http.base — Public Types

**Files:**
- Create: `src/nextpas.core.http.base.pas`
- Test: `tests/nextpas.core.http/test_http_base/test_http_base.lpr`
- Test: `tests/nextpas.core.http/test_http_base/Makefile`

**Types to define:**

```pascal
THttpVersion = (hvHttp10, hvHttp11, hvHttp2, hvHttp3);
THttpMethod = (hmGet, hmHead, hmPost, hmPut, hmDelete, hmPatch, hmOptions, hmConnect, hmTrace);

THttpStatus = UInt16;

TUrl = record
  Scheme: string;
  UserInfo: string;
  Host: string;
  Port: UInt16;
  Path: string;
  RawQuery: string;
  Fragment: string;
  class function Parse(const ARaw: string): TUrl; static;
  function ToString: string;
  function HostPort: string;
end;
```

**Constants:**
```pascal
HTTP_STATUS_OK = 200;
HTTP_STATUS_CREATED = 201;
HTTP_STATUS_NO_CONTENT = 204;
HTTP_STATUS_MOVED_PERMANENTLY = 301;
HTTP_STATUS_FOUND = 302;
HTTP_STATUS_NOT_MODIFIED = 304;
HTTP_STATUS_BAD_REQUEST = 400;
HTTP_STATUS_UNAUTHORIZED = 401;
HTTP_STATUS_FORBIDDEN = 403;
HTTP_STATUS_NOT_FOUND = 404;
HTTP_STATUS_METHOD_NOT_ALLOWED = 405;
HTTP_STATUS_INTERNAL_SERVER_ERROR = 500;
HTTP_STATUS_BAD_GATEWAY = 502;
HTTP_STATUS_SERVICE_UNAVAILABLE = 503;

function HttpMethodToStr(const AMethod: THttpMethod): string;
function HttpStrToMethod(const AStr: string): THttpMethod;
function HttpStatusText(const ACode: THttpStatus): string;
```

**Tests:**
- TUrl.Parse: scheme, host, port, path, query, fragment, relative, edge cases
- HttpMethodToStr / HttpStrToMethod round-trip
- HttpStatusText for known codes
- TUrl.ToString reconstruction

---

## Task 2: http.intf — Interface Definitions

**Files:**
- Create: `src/nextpas.core.http.intf.pas`

**No tests for this unit** (pure interface declarations, tested through implementations).

**Interfaces:** IHttpHeaders, IHttpRequest, IHttpResponse, IHttpResponseWriter, IHttpHandler, IHttpMiddleware, IHttpRouter, IHttpServer, IHttpClient, IHttpTransport, IHttpServerTransport.

**Handler callback types (§8):**
```pascal
THttpHandlerFunc = reference to procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
THttpHandlerMethod = procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter) of object;
THttpHandlerProc = procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
```

---

## Task 3: http.headers — Header Collection

**Files:**
- Create: `src/nextpas.core.http.headers.pas`
- Test: `tests/nextpas.core.http/test_http_headers/test_http_headers.lpr`
- Test: `tests/nextpas.core.http/test_http_headers/Makefile`

**Implementation:** Case-insensitive header name lookup. Multiple values per key (e.g. Set-Cookie). Internal storage: dynamic array of name-value pairs (simple, cache-friendly for typical header counts < 30).

**Public API:**
```pascal
THttpHeaders = class(TInterfacedObject, IHttpHeaders)
  class function Create: IHttpHeaders; static;
  procedure Set_(const AName, AValue: string);
  procedure Add(const AName, AValue: string);
  function Get(const AName: string): string;
  function GetAll(const AName: string): TStringArray;
  function Has(const AName: string): Boolean;
  procedure Del(const AName: string);
  function Count: Int32;
  procedure ForEach(const ACallback: THeaderIterator);
  function Clone: IHttpHeaders;
end;
```

**Tests:**
- Set/Get basic
- Case-insensitive lookup
- Add multiple values (Set-Cookie)
- GetAll returns all values
- Del removes all values for key
- Has/Count
- ForEach iteration
- Clone independence
- Empty header name raises

---

## Task 4: http.url — URL Parser

**Files:**
- Create: `src/nextpas.core.http.url.pas`
- Test: `tests/nextpas.core.http/test_http_url/test_http_url.lpr`
- Test: `tests/nextpas.core.http/test_http_url/Makefile`

**Implementation:** RFC 3986 compliant URL parsing. Zero-copy where possible (string slicing).

**Tests (comprehensive):**
- `http://example.com` → scheme=http, host=example.com, port=0
- `https://user:pass@host:8080/path?q=1#frag` → all fields
- `/relative/path?key=val` → path-only (no scheme/host)
- `http://[::1]:8080/` → IPv6 host
- Empty string → raises
- Percent-encoded paths
- Query parameter parsing (bonus: `QueryParam(name)` helper)
- ToString round-trip for all cases

---

## Task 5: http.router — Radix Tree Router

**Files:**
- Create: `src/nextpas.core.http.router.pas`
- Test: `tests/nextpas.core.http/test_http_router/test_http_router.lpr`
- Test: `tests/nextpas.core.http/test_http_router/Makefile`

**Implementation:** Radix tree (compressed trie) with:
- Static segments: `/users/list`
- Path parameters: `/users/:id`
- Wildcard: `/static/*filepath`
- Method-based dispatch
- 404/405 handling

**Public API:**
```pascal
THttpRouter = class(TInterfacedObject, IHttpRouter, IHttpHandler)
  class function Create: IHttpRouter; static;
  procedure Handle(const AMethod: THttpMethod; const APattern: string; const AHandler: THttpHandlerFunc); overload;
  procedure Handle(const AMethod: THttpMethod; const APattern: string; const AHandler: THttpHandlerMethod); overload;
  procedure Handle(const AMethod: THttpMethod; const APattern: string; const AHandler: THttpHandlerProc); overload;
  procedure Get(const APattern: string; const AHandler: THttpHandlerFunc);
  procedure Post(const APattern: string; const AHandler: THttpHandlerFunc);
  procedure Put(const APattern: string; const AHandler: THttpHandlerFunc);
  procedure Delete(const APattern: string; const AHandler: THttpHandlerFunc);
  procedure Use(const AMiddleware: IHttpMiddleware);
  procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
end;
```

Path params accessible via `IHttpRequest`:
```pascal
function PathParam(const AName: string): string;
```

**Tests:**
- Static route match
- Path parameter extraction (`:id`)
- Wildcard match (`*filepath`)
- Method dispatch (GET vs POST same path)
- 404 for unmatched path
- 405 for wrong method
- Multiple params `/users/:uid/posts/:pid`
- Overlapping routes priority (static > param > wildcard)
- Trailing slash handling
- Empty pattern raises
- Duplicate route raises

---

## Execution Order

1. Task 1 (http.base) — foundation types, independently testable
2. Task 2 (http.intf) — interfaces, compile-only verification
3. Task 3 (http.headers) — first real implementation
4. Task 4 (http.url) — URL parsing
5. Task 5 (http.router) — radix tree, most complex piece

Each task: implement → test → verify 0 leaks → commit.

---

## Quality Gates

- All public APIs have test coverage
- 0 memory leaks (heaptrc)
- 0 compiler warnings
- Follows design-conventions.md (§2 module structure, §4 exceptions, §5 interface-first, §8 callbacks, §10 doc comments, §13 code style)
- No SysUtils dependency
