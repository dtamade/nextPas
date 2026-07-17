# Usability Research: nextpas.core.http cycle-7 Wave B

**Kind**: research (root cause + peer strategies; no production code in this file alone)
**Baseline**: assessment cycle-7 score **97/100**, Low risk; cycle-5 landed on main
**Scope**: P2-1 WS cancel · P2-2 H2 live dial e2e · P2-3 CreateOp hot-path · P2-4 docs truth
**Out of scope**: CONNECT / Retry-After / full PSL / Response metadata / GetJson / Op-everywhere / H3

---

## Problem classification

| ID | Class | Root cause | Impact | Strategy |
|----|-------|------------|--------|----------|
| P2-1 | Completeness | WS holds only IReader/IWriter; never SetCancelToken; options lack CancelToken | Long-lived WS cannot cooperative-cancel | Wire IHttpCancelToken → INetCancelToken on stream; keep after handshake |
| P2-2 | Evidence | H2 dial timeout proven by source + fake dial only | Live hang regression risk | backlog-full live e2e like H1/WS |
| P2-3 | Observability | Create 318 / CreateOp 19; redirect resolve still bare Create | Op metrics incomplete on client hot path | Bounded CreateOp in client.pas only |
| P2-4 | Docs honesty | API_COVERAGE still says cycle-5 uncommitted | Inventory lie after land | Point to cycle-7; mark Wave B |

---

## Peer comparison (fix strategies)

| Gap | Go | Rust | nextpas Wave B |
|-----|----|------|----------------|
| WS cancel | context on dial+Read | CancellationToken / abort | Options.WithCancelToken + net slices |
| H2 dial e2e | integration often | similar | backlog-full OS dial |
| Error ops | typed / wrapped | thiserror / anyhow | CreateOp on client redirect/status paths |
| Docs | release notes | CHANGELOG | API_COVERAGE inventory |

---

## Risk assessment

| Item | Risk if unfixed | Risk of fix | Blast radius |
|------|-----------------|-------------|--------------|
| P2-1 | Medium (chat apps) | Low–Med | websocket.pas + ws client tests |
| P2-2 | Low–Med | Low | h2_client test only |
| P2-3 | Low | Low | client.pas message Op field |
| P2-4 | Low | None | docs only |

**Overall fix wave risk**: **Low–Medium**.

---

## Recommended wave

**Single commit Wave B** implementing all four P2s, then path-limited land.
Do **not** open Deferred product in this wave.
