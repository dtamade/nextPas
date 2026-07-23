# M2 two-hop harness inputs

Authority: `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md` §M2
(not bootstrap-spine “M2 typed contracts” — that was the M1 window).

| File | Role |
|------|------|
| `source-manifest.txt` | Target immutable entry for full A→B→C (stage0 driver) |
| `ladder.txt` | Progressive LLVM closure levels (L0→L3); only L3 closes A→B |
| `acceptance.txt` | B/C shared acceptance subset (used from M2-3) |

Runtime isolation roots (not versioned): `build/m2/gen-{a,b,c}/`, `build/m2/evidence/`.

Driver: `scripts/m2-two-hop.sh` / `make m2-two-hop`.