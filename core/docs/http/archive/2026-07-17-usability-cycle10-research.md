# Usability Research: nextpas.core.http cycle-10 Wave E

**Kind**: research (root cause + peer strategies)
**Baseline**: assessment cycle-10; main `61ee03f93`; http lane after Wave D absorb
**Scope**: H1 direct HTTPS + proxy Basic auth from ProxyUrl UserInfo

---

## Root cause

| Fact | Location |
|------|----------|
| H1 `ValidatePlainHttpClientUrlScheme` allows `https` only with proxy | `impl.h1.pas` |
| `PrepareFreshConnection` TLS-wraps only after CONNECT | same |
| Direct pool key is bare host (would mix plain/TLS if https opened) | `RoundTrip` PoolGet/Put |
| CONNECT request has no `Proxy-Authorization` | `EstablishHttpsConnectTunnel` |
| Absolute-form proxy write has no UserInfo → Basic injection | `WriteRequest` |
| `TUrl.Parse` already extracts raw `UserInfo` | `http.base.pas` |
| Request builder already has Basic via encoding | `http.message` `BasicAuth` |
| TLS stream helper + registry TLSContext already landed | Wave D |

**Symptom A**: `NewHttpClient.Get('https://origin/…')` → unsupported scheme.
**Symptom B**: `ProxyUrl='http://user:pass@proxy:8080'` never sends credentials to proxy.

**Peer strategy**:
- Go: `ProxyURL.User` → `Proxy-Authorization: Basic …` on CONNECT and absolute-form.
- curl: direct HTTPS is default; `--proxy-user` / URL userinfo → proxy Basic.
- Do not overwrite an explicit `Proxy-Authorization` request header.

---

## Design

```
https target + no proxy:
  dial origin:port
  NewTlsClientTcpStream(raw, TLSContext|SecureClient, SNI=host, ALPN=http/1.1)
  WriteRequest origin-form
  pool key: https|host  (port separate as today)

https target + ProxyUrl(http) [unchanged tunnel]:
  dial proxy → CONNECT → TLS → origin-form
  pool key: connect|proxy|host:port
  if ProxyUrl.UserInfo ≠ '': inject Proxy-Authorization: Basic base64(userinfo)
    on CONNECT request

http target + ProxyUrl(http) [absolute-form]:
  if ProxyUrl.UserInfo ≠ '' and request lacks proxy-authorization:
    inject Proxy-Authorization: Basic base64(raw UserInfo)
  (no percent-decode of UserInfo in this slice)

UserInfo encoding:
  Base64Encode(StringToUTF8Bytes(UserInfo))  // same as THttpRequestBuilder.BasicAuth
```

### Non-goals

- Digest / NTLM / Negotiate proxy auth
- SOCKS proxies
- Percent-decode of UserInfo (raw wire userinfo only)
- full PSL / Response metadata / Op-everywhere / H3
- server Default RW=0 change

### Risks

| Risk | Mitigation |
|------|------------|
| Pool mixes plain TCP with TLS-wrapped sockets | Distinct pool key prefix `https\|` for direct secure |
| Overwriting caller Proxy-Authorization | Absolute-form inject only if header absent |
| CONNECT auth missing vs absolute present | Same helper for both paths |
| Self-signed test needs verify-none | Test sets `TLSContext` with `WithVerifyNone` |

---

## Test plan

1. Direct HTTPS e2e: TLS server + HTTP 200; assert origin-form over TLS
2. Update scheme-reject test: `ftp` still rejected; `https` no longer rejected as scheme
3. CONNECT + `http://user:pass@proxy` → CONNECT has `Proxy-Authorization: Basic …`
4. Absolute-form + UserInfo → proxy request has Basic
5. Explicit `Proxy-Authorization` on request not overwritten (absolute-form)
6. Existing CONNECT / absolute-form without UserInfo stay green
