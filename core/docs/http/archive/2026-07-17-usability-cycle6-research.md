# Research: nextpas.core.http usability cycle-6 findings

**Kind**: root-cause + peer comparison (read-only)
**Baseline**: committed `fb0bbeae0` + **uncommitted cycle-5** worktree
**Inputs**: cycle-6 assessment; CONTRACT / API_COVERAGE; client / h1 / h2 / websocket;
  Go `net/http`, gorilla/websocket; Rust `reqwest`, `tokio-tungstenite`
**Output**: disposition freeze for fix plan (no implementation in this doc)

---

## 1. Problem inventory (classified)

| Class | IDs | Summary |
|-------|-----|---------|
| **Process / land** | I1 | cycle-5 fixes implemented but uncommitted / not on main |
| **Docs archive truth** | I2 | cycle-5 assessment body still describes pre-fix WS/e2e gaps in dimension table |
| **WS session cancel** | I3 | Dial budget landed; no CancelToken mid-frame after upgrade |
| **Verification depth** | I4 | H2 dial/cancel proven by unit/source; no live hang e2e |
| **Error structure** | I5 | CreateOp improved on redirect/WS; still sparse module-wide |
| **Residual honest** | I6 | ~50 ms cancel slice |
| **Keep / Deferred** | D1–D6 | Server Default RW=0; CONNECT; PSL; Retry-After; Response metadata; GetJson decode |
| **Non-goal** | N1 | H3/QUIC |
| **Closed (effective tree)** | C1–C7 | H1/H2 dial+cancel; WithConnectTimeout; TLS re-arm; WS dial; live H1/WS e2e; CONTRACT §2.1; isolation |

---

## 2. Root-cause analysis

### I1 — cycle-5 uncommitted

**Symptom**: `git status` shows modified production/tests/docs + untracked cycle-5 assessment docs;
HEAD still cycle-4 commit.

**Root cause**: Implementation completed in session; commit/landing not requested or not finished.

**Impact**: Peer worktrees / main lack WS dial budgets and live e2e; risk of overwrite or lost work;
assessment score claims diverge from published history.

**Peer**: Go/Rust projects treat unmerged work as not shipped — same rule.

**Fix strategy**:
1. Single logical commit (or 2: code+tests, docs) on `http` lane.
2. Path-limited landing candidate → ff main when authorized.
3. Do not start large P2 feature work before land (reduces blast radius).

**Risk of fix**: Low (process). Conflict risk rises if delayed.

---

### I2 — cycle-5 assessment archive inconsistency

**Symptom**: Post-fix score banner says 96, but dimension Notes still say “WS dial no budget”
and “no live http dial-hang e2e”.

**Root cause**: Assessment file updated scores at end without rewriting dimension narrative.

**Impact**: Future agents re-open closed bugs from stale notes.

**Fix strategy**: Patch cycle-5 assessment dimension table + one-line judgment to post-fix truth;
or add explicit “Superseded by cycle-6 inventory” banner. Prefer **minimal truth fix**.

**Risk**: None (docs).

---

### I3 — WebSocket mid-session cancel missing

**Symptom**: `TWebSocketOptions` has ConnectTimeout/Timeout; no CancelToken; after 101 success
deadlines cleared to Infinite; `ReadFrame`/`ReadMessage` block without cancel slices.

**Root cause**:
1. cycle-5 scoped dial/handshake only (HTTP client parity for connect path).
2. Cancel adapter lives in H1/H2 client transport, not shared for WS streams.
3. Long-lived WS design intentionally clears handshake deadlines.

**Impact**: Apps that cancel WS on shutdown may hang until peer close or process kill —
weaker than HTTP RoundTrip cancel and weaker than Go context / Rust cancel.

**Peer**:
- Go: `Dialer` + connection with deadlines; app often sets read deadlines in loop.
- Rust: cancel tokens / drop futures abort reads.

**Fix strategy** (choose one in plan confirmation):
- **A (Implement P2)**: Add optional `IHttpCancelToken` to options; apply `SetCancelToken`
  adapter on active stream for session lifetime; clear on Close.
- **B (Honest-doc)**: Document that WS cancel is app-owned via external deadline (if exposed)
  or process kill; no false “cancel works” claim.

**Recommendation**: Prefer **A** if adapter reuse is low blast; else **B** for this cycle.

**Risk**: Medium for A (frame loop + pool N/A); Low for B.

---

### I4 — H2 live dial e2e thin

**Symptom**: H2 has fake dial budget + Set/Clear cancel tests; no backlog-full live hang through
`NewHttpClient.WithVersion(hvHttp2)`.

**Root cause**: cycle-5 M2 focused H1 live (primary) + WS; H2 cleartext facade e2e exists for
happy path but not dial hang.

**Impact**: H2 ConnectTimeout plumbing regression might only fail source-contract strings.

**Fix strategy**: Optional backlog-full test with H2 prior-knowledge client if stable; skip if
H2 handshake complicates non-accepting peer (may get connect timeout before preface —
still valuable).

**Risk**: Low–Medium flaky. Localhost only.

---

### I5 — CreateOp sparse

**Symptom**: ~318 Create vs ~19 CreateOp after cycle-5 redirect/WS adds.

**Root cause**: Kind taxonomy first; Op optional; only hot paths wired.

**Impact**: Structured logging incomplete; not user-facing correctness.

**Fix strategy**: Only client Send / ensure / download remaining Create sites if easy; **do not**
Op-everywhere parsers.

**Risk**: Low.

---

### I6 — Cancel slice residual

Net SO_RCVTIMEO ~50 ms design. Document; pair with Timeout. No fake OS interrupt.

---

## 3. Closed items (do not re-open)

| ID | Item | Evidence |
|----|------|----------|
| C1 | H1 OS dial + mid-read cancel | impl.h1 + live client tests |
| C2 | H2 ConnectTimeout + cancel + pool clear | h2.client + tests |
| C3 | WithConnectTimeout fluent | intf + client |
| C4 | TLS FInner deadline re-arm | tls.stream + h2 tests |
| C5 | WS timed dial Default 30s | websocket.pas (dirty) |
| C6 | Live H1 dial + mid-read cancel e2e | test_http_client (dirty) |
| C7 | CONTRACT §2.1 + JSON dual table | CONTRACT (dirty) |
| C8 | FPC RTL isolation http path | rg clean |

---

## 4. Deferred product (explicit non-cycle-6 feature expand)

| ID | Item | Why deferred |
|----|------|--------------|
| D1 | HTTPS CONNECT / proxy auth | TLS tunnel design |
| D2 | Retry-After aware retry | Policy product |
| D3 | Full PSL cookies | Data maintenance |
| D4 | `IHttpResponse` metadata | Surface freeze |
| D5 | ensure-2xx JSON decode | json ownership |
| D6 | Server Default RW change | High test blast; Go also unbounded by default |
| N1 | H3/QUIC | QUIC module |

---

## 5. Impact matrix

| ID | User-visible? | Correctness? | Blast | Effort | Priority |
|----|---------------|--------------|-------|--------|----------|
| I1 land | Indirect (ship) | Process | Low | S | **P0** |
| I2 docs archive | Agents/docs | Truth | Low | S | **P0** |
| I3 WS cancel | Yes (WS apps) | Timeout/cancel | Medium | M | **P2** |
| I4 H2 live e2e | Regression | Safety net | Low | M | **P2** |
| I5 CreateOp | Ops | No | Low | S | **P2** |
| I6 residual | Latency | No | — | — | Honest |

---

## 6. Peer comparison (summary)

| Concern | nextpas now | Go | Rust | Cycle-6 action |
|---------|-------------|----|------|----------------|
| HTTP connect/cancel | Landed | strong | strong | Maintain |
| WS connect timeout | Landed (dirty) | Dialer | timeouts | Land |
| WS cancel | Missing | context | cancel | P2 or doc |
| Dual-compiler isolation | Hard rule | N/A | N/A | Maintain |
| Land hygiene | Dirty tree | CI merge | CI merge | **P0 land** |

---

## 7. Fix strategy freeze

1. **M0**: Commit cycle-5 + path-limited land (when authorized) + archive truth fix.
2. **M1 (optional P2)**: WS CancelToken **or** honest non-support docs.
3. **M2 (optional P2)**: H2 live dial timeout e2e.
4. **M3 (optional P2)**: Bounded CreateOp polish.
5. **Out of scope**: Deferred product list; Default server RW change; OS interrupt cancel; H3.

---

## 8. Implementation risk

| Risk | Mitigation |
|------|------------|
| Land without re-running gates | Re-run focused gates on landing worktree |
| WS cancel breaks frame tests | Feature optional; Default nil token |
| Scope creep to CONNECT/GetJson | Checklist reject |

**Overall implementation risk**: **Low** if land-first; **Medium** if P2 WS cancel included.
