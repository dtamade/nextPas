# Usability Assessment: nextpas.core.http (cycle-10)

**Kind**: product slice inventory (Wave E)
**Module**: `nextpas.core.http` (L3)
**Baseline**:
- **http worktree HEAD**: post Wave D absorb (`20b920815` / main `61ee03f93`)
- **main HEAD** (at plan): `61ee03f93` (Wave D CONNECT landed + pushed)
**Comparator**: Go `net/http` ProxyURL Userinfo Basic; curl `--proxy-user` / direct HTTPS
**Constraint**: dual-compiler isolation — only `nextpas.core.system` may `uses` FPC RTL

---

## Summary

| Metric | Value |
|--------|-------|
| **Pre-Wave-E score** | **~98.5 / 100** (post Wave D) |
| **Target post-Wave-E** | **~99 / 100** |
| **Overall risk** | **Medium** (direct TLS pool keying + proxy auth header) |
| **This wave** | **E1 H1 direct HTTPS** · **E2 Proxy Basic auth** · **E3 tests/docs** |
| **Still Deferred** | full PSL · Response metadata · Op-everywhere · H3 · Digest/SOCKS · HTTP-date Retry-After |
| **Residual-honest** | cancel ~50 ms slices; OpenSSL factory residual when backend unit linked |
| **Keep** | CONNECT tunnel; absolute-form http proxy; JSON dual raw/ensure |

**One-line judgment**: Wave E closes the two highest-ROI residual client gaps after
CONNECT: **direct `https://` on H1** and **proxy Basic auth from `ProxyUrl` UserInfo**.

### Dimension focus

| Dimension | Pre | Wave E effect |
|-----------|----:|---------------|
| API usability | 97 | `Get('https://…')` works without proxy; `http://user:pass@proxy` works |
| Call consistency | 97 | Direct TLS + CONNECT TLS share `NewTlsClientTcpStream` path |
| Error message quality | 93 | CONNECT still `hekConnect` on non-2xx; scheme rejects only non-http(s) |
| Boundary conditions | 95 | UserInfo Basic only; no Digest/SOCKS; no overwrite if header set |

---

## Findings (Wave E scope)

| ID | Item | Disposition |
|----|------|-------------|
| **E1** | H1 direct `https://` (TLS wrap, pool key) | **Implement** |
| **E2** | Proxy Basic from `ProxyUrl` UserInfo (CONNECT + absolute-form) | **Implement** |
| **E3** | e2e + inventory/CONTRACT truth | **Tests/docs** after code |
| F1 | full PSL / metadata / Op-all / H3 | **Deferred** |
| F2 | Digest / NTLM / SOCKS | **Deferred** |

---

## Priority

| ID | Pri | Action |
|----|-----|--------|
| E1 direct HTTPS | P2 product | Implement |
| E2 Proxy Basic | P2 product | Implement |
| E3 focused e2e + docs | P2 | Tests/docs |
| PSL / H3 / Digest / SOCKS | P2–P3 | Stay Deferred |

---

## Next Steps

1. Research + fix-plan (this cycle).
2. Implement E1 → E2 → E3.
3. Focused gates + path-limited land.
