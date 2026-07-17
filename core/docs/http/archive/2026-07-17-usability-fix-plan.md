# Implementation plan: HTTP usability findings fix (2026-07-17)

**Depends on**: `2026-07-17-usability-findings-research.md` (research first)
**Confirmation gate**: research + this plan = approval to implement in one continuous run.

---

## 1. Milestones (order)

| MS | Priority | Scope | Deliverable | Depends |
|----|----------|-------|-------------|---------|
| M0 | — | Research + this plan | Docs under `core/docs/http/` | — |
| M1 | **P0** | Doc honesty | CONTRACT/README/API_COVERAGE + option field comments | M0 |
| M2 | **P1** | hekArgument unify | message, form, headers, stream public preconditions | M0 |
| M3 | **P1** | Cookie SameSite | Parse/store/send policy + tests | M0 |
| M4 | **P1-net** | Dial/cancel | **Blocked** table only (no fake dial timeout) | M0, M1 |
| M5 | **P2** | GetString + default UA | IHttpClient methods; H1 default User-Agent | M0 |
| M6 | Verify | Gates | client + cookie + message + hygiene; scratch logs | M1–M5 |

---

## 2. Priority order and dependencies

```
M0 research/plan
  └─► M1 P0 docs ──────────────────────────┐
  └─► M2 hekArgument ──► message/form tests┤
  └─► M3 SameSite ─────► cookie/client tests┤──► M6 verify
  └─► M4 Blocked dial (docs only) ─────────┤
  └─► M5 GetString + UA ─► client tests ───┘
```

- **http-owned**: M1, M2, M3, M5
- **net-owned (Blocked)**: M4
- **Deferred**: CONNECT, Retry-After, PSL, H3

---

## 3. Milestone detail

### M1 — P0 docs
- CONTRACT § timeouts / cancel: ConnectTimeout = post-dial first-write only; OS dial Blocked.
- README Limits / cancel section aligned.
- API_COVERAGE: wave/current truth only; remove or archive contradictory multi-arg `NewRequest` “补齐” as history.
- `THttpClientOptions.ConnectTimeout` field comment in `base.pas`.

### M2 — hekArgument
Replace public precondition `EArgumentError` with `EHttpError.Create(hekArgument, ...)` in:
- `nextpas.core.http.message`
- `nextpas.core.http.form`
- `nextpas.core.http.headers`
- `nextpas.core.http.stream`
Update tests that catch `EArgumentError` on those paths.

### M3 — SameSite (policy from research §2.3)
- Store: parse SameSite; default Lax if absent; None requires Secure.
- Send: SiteKey approximation; cross-site only None.
- Tests: None without Secure dropped; cross-site suppresses Lax/Strict; same-site sends Lax.

### M4 — Net P1 honesty
- No `DialTimeout` fake field.
- CONTRACT Blocked table (mirror research §6).
- Comments: cancel + Timeout pairing.

### M5 — P2 kept
- `IHttpClient.GetString` / `GetBytes` (+ forwarder, facade if needed).
- Default `User-Agent: nextpas-http/1.0` when request has no User-Agent (H1 write path).

### M6 — Verification
```bash
make focused FOCUS=core/tests/nextpas.core.http/test_http_client
make -C core/tests/nextpas.core.http/test_http_cookie clean test
make -C core/tests/nextpas.core.http/test_http_message clean test
make hygiene
```
Logs → `{SCRATCH}/`.

---

## 4. Non-goals / deferred (rationale)

| Item | Why deferred |
|------|----------------|
| HTTPS CONNECT / proxy auth | Separate TLS tunnel design; not required for honesty score |
| Retry-After | Needs retry policy API design |
| Full PSL | Research chose SiteKey approx; PSL embed is large |
| OS dial timeout / mid-read cancel | Net/platform work; Blocked not half-fixed |
| H3 / async API | Product non-goals |

---

## 5. Risks during implementation

- Over-migrate internal impl exceptions → stick to M2 file list.
- SameSite default Lax changes store counts → tests use same-site hosts.
- UA injection surprises custom servers → only if header absent.

---

## 6. Done when

Acceptance criteria 1–5 of the goal plan file are met; verification plan observations hold; scratch evidence saved.
