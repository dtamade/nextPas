# Usability Research: nextpas.core.http cycle-8 Wave C

**Scope**: GetJson ensure+decode + Retry-After / 429
**Out of scope**: CONNECT / full PSL / Response metadata / Op-everywhere / H3

---

## C1 — ensure+decode JSON

| Dimension | Conclusion |
|-----------|------------|
| Root cause | ensure helpers stop at string/bytes; apps re-call `JsonParse` |
| Assets | `JsonParse` / `TryJsonParse`; `HttpEnsureSuccess`; `HttpGetString` pattern; request-side `HttpReadRequestBodyJson` uses `hekParse` |
| Go/Rust | reqwest `.json()`; common Go `json.NewDecoder` after status check |
| Fix | `HttpReadResponseJson` + `HttpGetJson` (+ `IHttpClient.GetJson`); invalid JSON → `EHttpError.CreateOp(hekProtocol, 'json', …)` (response path Op for metrics); non-2xx keeps ensure `hekStatus` |
| Non-break | `HttpPostJson` remains ensure→string; raw `PostJson` still no ensure |

## C2 — Retry-After + 429

| Dimension | Conclusion |
|-----------|------------|
| Root cause | `TRetryClient` only 5xx + exponential 100ms..5s; ignores headers; 429 is 4xx exit |
| Assets | `WithRetry` decorator; `HttpIsRetrySafeRequest`; `platform_thread_sleep_ns`; cancel check before sleep |
| Go/Rust | Default Go client no auto-retry; cloud SDKs honor Retry-After on 429/503 |
| Fix | Retriable status = **429 or 5xx**; prefer delta-seconds `Retry-After` when parseable; else exponential; **cap 60s**; HTTP-date not required this slice (honest docs) |
| Opt-in | Only `WithRetry(n>0)`; no change for default clients |
| Test | Mock transport with `Retry-After: 0` for zero-wait retries |

## Peer gap matrix (Wave C)

| Area | nextpas pre | after Wave C | Peer bar |
|------|-------------|--------------|----------|
| GET ensure+JSON doc | missing | `HttpGetJson` / `GetJson` | reqwest `.json()` |
| Retry-After | no | delta-seconds + cap | middleware / SDK |
| 429 retry | no | yes with WithRetry | common SDK |
| CONNECT HTTPS proxy | no | still Deferred | common |

---

## Recommendation

Single Wave C commit: C1 + C2 + docs, then path-limited land.
Do **not** open CONNECT/PSL in this wave.
