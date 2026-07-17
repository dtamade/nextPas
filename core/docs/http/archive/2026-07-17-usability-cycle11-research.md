# Usability Research: nextpas.core.http cycle-11 Wave F

**Kind**: research (root cause + peer strategies)
**Baseline**: assessment cycle-11; main `2820157d2`; http lane after Wave E absorb
**Scope**: HTTP-date Retry-After + WithTLSContext + JSON write ensure+decode

---

## Root cause

| Fact | Location |
|------|----------|
| `TryHttpParseRetryAfterMs` only `TryStrToInt64` | `client.pas` |
| Wave C docs: HTTP-date ignored | CONTRACT / intf comment |
| IMF-fix parsers exist in cookie/static | private; client must not use static |
| `TLSContext` field lacks fluent `With*` | `base.pas` / `IHttpClient` |
| `HttpPostJson` returns string only | `client.pas` |
| `HttpReadResponseJson` / `HttpGetJson` ready | reuse for write path |

---

## Design

### F1 Retry-After

```
TryHttpParseRetryAfterMs(headers, delayMs):
  raw = trim(Retry-After)
  if empty → false
  if delta-seconds parseable → clamp [0,60] * 1000 → true
  if IMF-fix parseable → max(0, unix - now) * 1000, cap 60s → true
  else → false  // exponential backoff
```

Past date → delay 0 (same as `Retry-After: 0`).

### F2 WithTLSContext

```
THttpClientOptions.WithTLSContext(ctx)
IHttpClient.WithTLSContext(ctx) → NewHttpClient(options.WithTLSContext)
Forwarder rebinds like WithProxyUrl / WithConnectTimeout
```

### F3 JSON document write

```
HttpPostJsonDocument(client, url, bodyDoc) →
  Post raw JSON → HttpReadResponseJson(resp, 'POST', url)
HttpPutJsonDocument / HttpPatchJsonDocument same pattern
// HttpPostJson string API unchanged
```

### Non-goals

full PSL, Response metadata, Op-everywhere, H3, Digest/SOCKS, OpenSSL residual zero.

---

## Test plan

1. WithRetry + past IMF-fix Retry-After → quick retry success
2. invalid Retry-After still backoff (existing)
3. Options.WithTLSContext + fluent client direct https e2e
4. HttpPostJsonDocument 200 object; 404 hekStatus; invalid body hekProtocol Op=json
5. base fluent chain includes TLSContext
