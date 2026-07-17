# Usability Research: nextpas.core.http cycle-9 Wave D

**Kind**: research (root cause + peer strategies)
**Baseline**: assessment cycle-9; main `5120626f0`; http lane after Wave C absorb
**Scope**: HTTPS CONNECT via plain HTTP proxy (no proxy auth)

---

## Root cause

| Fact | Location |
|------|----------|
| H1 `ValidatePlainHttpClientUrlScheme` only allows `http` | `impl.h1.pas` |
| Proxy path always absolute-form; dials proxy host | `TH1ClientTransport.RoundTrip` |
| No CONNECT request; no TLS wrap after proxy | same |
| H2 has direct TLS (`NewTlsClientTcpStream`) | `impl.h2.client.pas` |
| TLS stream helper already exists | `impl.tls.stream.pas` |
| Client options already carry `TLSContext` | `THttpClientOptions` |
| Registry did not pass `TLSContext` into H1 options | `impl.registry.pas` |

**Symptom**: `WithProxyUrl('http://proxy:8080').Get('https://origin/...')` fails as
unsupported scheme (or would absolute-form https URL to a proxy that expects CONNECT).

**Peer strategy**:
- Go `net/http`: CONNECT for https; absolute-form for http; optional Proxy-Authorization.
- curl: CONNECT then TLS ClientHello on the tunnel; origin-form request-target.

---

## Design

```
https target + ProxyUrl(http):
  dial proxy
  CONNECT host:port HTTP/1.1 + Host
  require 2xx (skip body; leftover → prepend)
  NewTlsClientTcpStream(raw, TLSContext|SecureClient, SNI=host, ALPN=http/1.1)
  WriteRequest origin-form
  pool key: connect|proxy|host:port  (stores TLS-wrapped stream)

http target + ProxyUrl(http):
  (unchanged) absolute-form

https target + no proxy:
  still reject on H1 (Wave D non-goal: direct H1 https)
```

### Non-goals

- Proxy authentication (`Proxy-Authorization` on CONNECT)
- SOCKS proxies
- H1 direct https without proxy
- HTTP-date Retry-After (already deferred Wave C)
- H3 / full PSL / Response metadata expansion

### Risks

| Risk | Mitigation |
|------|------------|
| Pool mixes tunnel vs absolute proxy sockets | Distinct pool key prefix `connect|` |
| CONNECT response body consumes ClientHello | ReadResponse with skip-body (hmHead) + prepend FPending |
| TLS handshake I/O unbounded | Apply ConnectTimeout/Timeout deadline before TLS wrap |
| Self-signed test needs verify-none context | Test sets `TLSContext` with `WithVerifyNone` |

---

## Test plan

1. Mock CONNECT proxy: 200 + TLS server + HTTP origin reply
2. Assert CONNECT request-line `CONNECT example.test:443`
3. Assert tunneled request origin-form `GET /path`
4. Denied CONNECT (403) → `hekConnect`
5. Existing absolute-form http proxy tests stay green
