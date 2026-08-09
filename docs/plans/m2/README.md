# M2 two-hop harness inputs

Authority: `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md` §M2
(not bootstrap-spine “M2 typed contracts” — that was the M1 window).

| File | Role |
|------|------|
| `ROADMAP.md` | **Single execution entry**: bite queue B0-B8, session protocol, live numbers |
| `source-manifest.txt` | Target immutable entry for full A→B→C (stage0 driver) |
| `ladder.txt` | Progressive LLVM closure levels (L0→L3); only L3 closes A→B |
| `acceptance.txt` | B/C shared acceptance subset (used from M2-3) |
| `wave0-ledger.md` | Historical M2-2 ledger (nofold33-35 era; numbers superseded by `ROADMAP.md`) |
| `allowlist-baseline.sha256` | FPC RTL allowlist baseline hash (F-009: shrink-only from Wave3) |

Current status: M2-0 harness + LLVM smoke green; ladder L0–L2 green; L3 blocked on
residual undefined symbols at `opt` — live count and bite queue in `ROADMAP.md`.
Probe: `scripts/m2-l3-residual.sh`.

Runtime isolation roots (not versioned): `build/m2/gen-{a,b,c}/`, `build/m2/evidence/`.
The L3 probe binary `nextpas-m2-l3-probe` (repo root) is a runtime-local artifact —
do not commit it.

Driver: `scripts/m2-two-hop.sh` / `make m2-two-hop`.