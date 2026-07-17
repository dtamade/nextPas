# nextpas.core.platform — Forward Execution Roadmap

**Authority**: sole forward-execution plan for the platform module.
**Evidence / phase log**: [goal-tree.md](goal-tree.md)
**Stable contracts**: [master-spec.md](master-spec.md), [CONTRACT.md](CONTRACT.md), [ERROR-HANDLING.md](ERROR-HANDLING.md), [RETURN-SEMANTICS.md](RETURN-SEMANTICS.md)
**Host evidence labels only**: [runtime-truth-matrix.md](runtime-truth-matrix.md)
**Closed residual program (LT0–LT3 done)**: [residual-roadmap.md](residual-roadmap.md)

**Usability**: maintenance baseline **8.21/10** — no open-ended rescoring waves.
**Last inventory**: 2026-07-17
**Status**: draft for owner confirmation → then execute autonomously by phase order

---

## 0. How to use this document

| Rule | Meaning |
|------|---------|
| One forward map | Execute only phases listed here (and their ordered slices) |
| Evidence before claim | Never promote truth tiers without host logs matching the tier name |
| Path-limited land | Platform lane lands via allowed-path cherry-pick / landing-check |
| FPC RTL | Only `nextpas.core.system` may `uses` FPC RTL in production design |
| Discuss on major change | Scope change, truth promotion criteria change, or new host owner → revise this file first |
| Autonomous otherwise | After confirmation, proceed slice-by-slice without waiting for re-prompt |

**Non-authority (do not drive work from these):**

- [ROADMAP-v2.md](ROADMAP-v2.md) — 2026-07-06 planning snapshot (stale scores / completed items)
- [USABILITY-ASSESSMENT.md](USABILITY-ASSESSMENT.md) — body historical; banner score only
- Daily reports, coverage audits, old completion plans under `core/docs/plans/*platform*`

---

## 1. North star

`nextpas.core.platform` is nextPas **L0 OS foundation**: host-owned raw FFI + portable feature facades.

1. Correct, leak-safe contracts on Linux (already strong) stay green.
2. Windows becomes **durable real-host CI** (`ci-matrix`), not Wine-as-proxy.
3. macOS gains honest **focused-runtime** on real runners before any broader claim.
4. Other hosts (FreeBSD / Android / secondary Linux arches) stay evidence-honest; promote only when owners + gates exist.
5. Residual usability / dual-IO / error authority stay in **maintenance** mode.

Truth tiers (from master-spec):
`source-contract` → `forced-compile` → `focused-runtime` → `ci-matrix`
Wine is forever **`wine-runtime-smoke`**, never a substitute for real Windows `ci-matrix`.

---

## 2. Current inventory (2026-07-17)

### 2.1 What is solid

| Area | State |
|------|--------|
| Module shape | 60+ units: feature facades + linux/windows/posix/unix/darwin/freebsd/android base/ffi |
| Linux x86_64 | `focused-runtime` across facade modules; maintenance gates green |
| Error / return | `PLATFORM_ERR_*` authority in ERROR-HANDLING; three-tier return model frozen |
| Usability waves 1–4 | **Closed** at 8.21 maintenance |
| LT0–LT3 residual | **Done** (docs freeze, live-name gates, dual-IO owner-only, raw OS side-channel) |
| Wine matrix (14) | **pass=14 / fail=0 / skip=0** via `platform-wine-ci-matrix.sh` (secondary; never substitutes for real Windows) |
| Real Windows GHA | **D1.d done**: documented 17-gate set is `truth=ci-matrix` (pass=17 on `windows-latest`; wine still green) |
| Tier-2 Linux arches | aarch64 / arm32 / riscv64 forced-compile (13 modules) |
| Readiness vs completion | Split held: `platform_poller_*` readiness; IOCP in `io.reactor.iocp` |

### 2.2 What is incomplete or dishonest-risk

| Gap | Severity | Notes |
|-----|----------|--------|
| Windows beyond documented 17-gate set | **P1** | signal / secure-zero native / full AcceptEx-ConnectEx suite not in matrix |
| macOS beyond documented 8-gate set | **P1** | D2.c done for listed modules only; full-host parity not claimed |
| `platform.signal` Win64 wine path | **P1** | Missing error/FFI uses; not in 14-module matrix |
| Windows secure-zero native path | **P1** | Documented deferred; still fallback |
| dual-IO symbols on `platform.process` | **P2** | Owner-only; long-term deprecation not scheduled |
| Deferred F7/F9/F10/F14 | **P3** | Mapping symmetry, ALen rename, diagnostics, freetype move-out |
| Doc authority sprawl | **P0 docs** | Multiple “roadmaps”; fixed by this file becoming sole forward map |
| Stale claims in older docs | **P1 docs** | e.g. master-spec “no real Windows CI runner”; truth-matrix poller row |

### 2.3 Host truth (honest)

| Host | Current tier | Next honest claim |
|------|--------------|-------------------|
| Linux x86_64 | focused-runtime | keep green |
| Windows x86_64 | **`ci-matrix` for documented 17-gate set** + wine-runtime-smoke secondary | expand matrix modules; keep wine green |
| macOS | **`focused-runtime` for documented 8-gate set** (D2.c); inventory via best-effort | keep matrix green; no full-host parity |
| FreeBSD | source-contract / best-effort | forced-compile or runtime when CI stable |
| Android | forced-compile fragments | device/runtime only with NDK owner |
| Linux aarch64/arm32/riscv64 | forced-compile | runtime only with hardware/CI |

---

## 3. Phase plan (executable)

Priority order: **D0 → D1 → D2 → D3 → D4 → D5**.
Do not start a later phase’s promotion claims until earlier phase exit criteria pass (maintenance work may interleave).

### D0 — Documentation authority freeze

| Field | Content |
|-------|---------|
| **Goal** | One forward map; historical docs demoted; inventory frozen |
| **Deliverables** | This `ROADMAP.md`; README authority table; residual-roadmap closed pointer; goal-tree pointer; stale claim fixes in master-spec / runtime-truth-matrix |
| **Depends on** | None |
| **Priority** | **P0 — do first** |
| **Exit / acceptance** | README lists this file as sole forward-execution authority; residual-roadmap keeps LT0–LT3 + dual-IO tokens for contracts; `test_platform_return_semantics_contract` + `test_platform_goal_tree_contract` + docs live-patterns + hygiene green |
| **Status** | **Done** (owner confirmed; sole forward authority) |

### D1 — Windows evidence ladder (ex-LT4 Windows half)

| Field | Content |
|-------|---------|
| **Goal** | Real Windows runtime proof durable in CI; wine remains secondary regression |
| **Depends on** | D0 |
| **Priority** | **P0** |

| Slice | Deliverable | Acceptance |
|-------|-------------|------------|
| **D1.a** | Keep wine matrix 14/14 green; optional expand (signal/console) without claiming ci-matrix | `platform-wine-ci-matrix.sh` pass=14+; honest SKIP/FAIL classification |
| **D1.b** | Expand GHA `test-windows-runtime` via `scripts/platform-windows-ci-matrix.ps1` (14 wine-suite dirs natively + 3 dedicated real gates) | Each gate is native Windows `make clean test` (not Wine); job fails closed |
| **D1.c** | Fix remaining Win64 compile/runtime blockers found by D1.a/b | focused host tests still green on Linux; wine/GHA evidence attached in goal-tree |
| **D1.d** | Promote Windows to **`ci-matrix`** only when criteria below all true | Update runtime-truth-matrix + goal-tree + master-spec in same land |

**Windows `ci-matrix` promotion criteria (all required):**

1. GHA `windows-latest` runs a **documented module set ≥ wine matrix core 14** (or explicit superseding list in this ROADMAP).
2. Each gate is real Windows runtime (not wine, not compile-only).
3. heaptrc / suite pass recorded; no “best-effort continue on fail”.
4. Wine matrix still green as non-promotional regression.
5. Explicit log line language: `truth=ci-matrix` only after 1–4.

**D1.d status (2026-07-17): Done** for the documented 17-gate set only.

| Check | Evidence |
|-------|----------|
| 1 module set ≥ 14 | `platform-windows-ci-matrix.sh` lists 17 gates (14 wine-suite dirs + poller/io/socket real) |
| 2 real Windows | GHA `test-windows-runtime` on `windows-latest` via native `make clean test` |
| 3 fail-closed | matrix exits 1 on any gate fail; pass=17 fail=0 (run 29569033144 and later green windows jobs) |
| 4 wine green | local `platform-wine-ci-matrix.sh` pass=14 fail=0 skip=0 |
| 5 log language | scripts print `truth=ci-matrix; … scope=documented-17-gate-set` |

**Documented superseding gate list (ci-matrix scope):**
`platform.{time,memory,sync,thread,io,process,files,fs,path,env,mmap,random,socket}`,
`io.reactor.iocp`, `poller.windows_runtime_smoke`, `platform.io.windows_real`,
`platform.socket.windows_real`.

**Not claimed by D1.d:** full-host Windows parity; modules outside the list (e.g. signal, console, secure-zero native); AcceptEx/ConnectEx beyond existing smoke gaps.

**Non-goals for D1:** macOS promotion; dual-IO removal; F7 mapping rewrite.

### D2 — macOS focused-runtime (ex-LT4 macOS half)

| Field | Content |
|-------|---------|
| **Goal** | Named macOS module gates at `focused-runtime` (not best-effort whole suite) |
| **Depends on** | D0; preferably D1.b pattern for CI structure |
| **Priority** | **P0 after D1.b pattern stable** |

| Slice | Deliverable | Acceptance |
|-------|-------------|------------|
| **D2.a** | Inventory which modules already compile/run on `macos-14` | readiness script or job matrix list |
| **D2.b** | Add focused gates: at least time, sync, thread, files, path, env, error, socket (kqueue path) | real macOS runner; fail closed for listed gates |
| **D2.c** | Promote listed modules to `focused-runtime` in goal-tree + truth-matrix | no claim of full-host parity |

**D2.a inventory (2026-07-17, from GHA `macos-14` best-effort):**

| Observation | Evidence |
|-------------|----------|
| Best-effort whole suite | ~5 pass / ~807 skip (failures reported as SKIP); not promotional |
| Root toolchain footgun | trunk `ppca64` could not find `System` unless `fpc.cfg` is copied next to compiler + explicit `-Fu…/units/aarch64-darwin/rtl` |
| Platform runtime under best-effort | essentially not green (almost all platform gates skipped as compile/run fails) |
| Intended focused set | D2.b documented 8-gate list below |

**D2.b status:** matrix script `core/scripts/platform-macos-ci-matrix.sh` + GHA fail-closed step; FPC verify fails closed. Best-effort remains non-promotional inventory only.

**Documented macOS focused gate list (8):**
`platform.{time,sync,thread,files,path,env,error,socket}` via primary host suites
(`test_platform_time_helpers`, `test_platform_sync`, `test_platform_thread`,
`test_platform_files`, `test_platform_path`, `test_platform_env`,
`test_platform_error`, `test_platform_socket`).

**macOS promotion criteria (D2.c):** durable Actions green on the 8-gate matrix + truth-matrix/goal-tree rows updated. Not full-host parity.

**D2.c status (2026-07-17): Done** for the documented 8-gate set only.

| Check | Evidence |
|-------|----------|
| 1 real macOS | GHA `test-macos` on `macos-14` aarch64 via native `make clean test` |
| 2 documented 8-gate set | `platform-macos-ci-matrix.sh` lists time/sync/thread/files/path/env/error/socket |
| 3 fail-closed matrix green | step `Run platform macOS focused matrix (fail-closed)` success on run 29578542275 (~2 min wall; no gate timeout) after Darwin varargs/detach/errno fixes (25c843edb) |
| 4 docs | runtime-truth-matrix + goal-tree + master-spec + this ROADMAP updated in D2.c land |
| 5 scope honesty | not full-host macOS parity; best-effort inventory still non-evidence |

**Not claimed by D2.c:** full-host macOS parity; modules outside the 8-gate list; FreeBSD promotion.

### D3 — Contract & debt cleanup (maintenance)

| Field | Content |
|-------|---------|
| **Goal** | Shrink transitional surface without usability rescoring |
| **Depends on** | D0; preferably after D1 not blocked |
| **Priority** | **P1–P2** |

| Slice | Item | Acceptance |
|-------|------|------------|
| **D3.a** | `platform.signal` Win64 compile + wine or real-Windows smoke | wine-build green or real gate; no silent stubs |
| **D3.b** | Windows secure-zero native path or explicit permanent unsupported | truth-matrix honest either way |
| **D3.c** | dual-IO deprecation schedule (keep symbols, document sunset or permanent owner-only) | residual/CONTRACT/ROADMAP agree |
| **D3.d** | F14 freetype boundary decision (keep under platform vs move) | ADR or CONTRACT note + owner |
| **D3.e** | Deferred F7/F9/F10 only if consumer pain forces | otherwise stay Won't |

### D4 — Secondary hosts (honest, low urgency)

| Field | Content |
|-------|---------|
| **Goal** | FreeBSD / Android / secondary arch evidence only with owners |
| **Depends on** | D1–D2 not required, but do not steal P0 capacity |
| **Priority** | **P3** |

| Host | Next step | Promote when |
|------|-----------|--------------|
| FreeBSD | stabilize cross-platform-actions compile + smoke | named runtime gates exist |
| Android | NDK compile matrix expand; no fake device claims | device/emulator owner |
| Linux arm/riscv | optional runtime CI if hardware available | real run logs |

### D5 — Performance & consumer feedback (post-stability)

| Field | Content |
|-------|---------|
| **Goal** | Benchmarks and consumer-driven facade fixes after truth ladder stable |
| **Depends on** | D1 exit preferred; never before contract freezes |
| **Priority** | **P3** |
| **Acceptance** | Bench reports under docs; no truth-tier language change from benches alone |

---

## 4. Standing maintenance (always green)

Run before any Ready land that touches platform:

```bash
make focused FOCUS=core/tests/nextpas.core.platform/test_platform_return_semantics_contract
make focused FOCUS=core/tests/nextpas.core.platform/test_platform_docs_live_patterns
make focused FOCUS=core/tests/nextpas.core.platform.error/test_platform_error
make focused FOCUS=core/tests/nextpas.core.platform/test_platform_goal_tree_contract
make -C core/tests/architecture/source_contracts host-raw-ffi-audit
make hygiene
./core/scripts/platform-wine-ci-matrix.sh   # when Win64/wine path touched
```

Optional readiness inventory (not a promotion):

```bash
./scripts/platform-lt4-readiness.sh
```

---

## 5. Default execution queue (after confirmation)

1. **D0** done.
2. **D1.a–D1.d** done for documented 17-gate Windows `ci-matrix` set; keep wine + GHA green.
3. **D2.a–D2.c** done for documented 8-gate macOS `focused-runtime` set; keep GHA matrix green.
4. **D3** debt in severity order.
5. **D4/D5** opportunistic / owner-gated.

---

## 6. Decision log (append only)

| Date | Decision |
|------|----------|
| 2026-07-17 | Usability freeze 8.21; residual LT0–LT3 done; LT4 split into D1/D2 |
| 2026-07-17 | Wine matrix 14/14 green; real-Windows GHA has 3 gates; not ci-matrix |
| 2026-07-17 | Owner accepted recommended plan: D0 land → expand real-Windows GHA → keep wine secondary |
| 2026-07-17 | Repo public; GHA can run. D1.b uses `platform-windows-ci-matrix.sh` under MSYS2 x86_64 FPC (not Chocolatey i386) |
| 2026-07-17 | First Windows matrix CI failed on `ppc386` + `reference to`; toolchain switched to MSYS2 MINGW64 FPC |
| 2026-07-17 | MSYS2 has no `mingw-w64-x86_64-fpc` package; Windows CI installs official FPC 3.3.1 x86_64-win64 trunk snapshot + MSYS2 make/bash |
| 2026-07-17 | Windows CI toolchain reaches real compile; enable `-Sg`/`{$GOTO ON}` project-wide so mem/http/json ports build without host fpc.cfg |
| 2026-07-17 | First full matrix: pass=13 fail=4 (sync trylock, random zeros flaky, io create-server/wake, socket CompareMem). D1.c fixes: SRW TryAcquire returns Win32 BOOLEAN not BOOL; FIONBIO=$8004667E; CreateServerSocket loopback/host-order; random any-nonzero; socket uses system.CompareMem |
| 2026-07-17 | D1.c closed: real-Windows matrix **pass=17 fail=0** (run 29569033144). Mapped PLATFORM_ERR_AGAIN treated as Winsock would-block in wake drain + socket classifiers. D1.d promotion still pending criteria checklist |
| 2026-07-17 | **D1.d done**: promote documented 17-gate set to `truth=ci-matrix` after criteria 1–4 met (GHA 17/17 durable; wine 14/14; fail-closed). Not full-host Windows parity. Next: D2 macOS. |
| 2026-07-17 | **D2.a**: macOS best-effort is non-evidence (~5/812); FPC trunk missing System unit without compiler-local fpc.cfg. **D2.b**: add fail-closed 8-gate `platform-macos-ci-matrix.sh` + FPC verify; best-effort demoted to inventory-only. |
| 2026-07-17 | Darwin residual: aarch64 varargs `open`/`fcntl`, thread detach RefCount (trampoline UAF), host `ESysE*` error tests; land 25c843edb |
| 2026-07-17 | **D2.c done**: promote documented 8-gate set to `focused-runtime` after GHA matrix fail-closed success (run 29578542275 step 8). Not full-host macOS parity. Next: D3 debt. |

---

## 7. Owner confirmation (accepted)

- [x] D0 doc authority model accepted
- [x] D1 Windows ladder order (wine keep → GHA expand → promote) accepted
- [x] Windows `ci-matrix` criteria (section D1) accepted as written
- [x] D2 macOS after D1.b pattern accepted
- [x] D3 dual-IO stays owner-only unless we schedule deprecation (default: no removal this program)
- [x] D4/D5 remain low priority unless hosts/owners appear

Autonomous execution follows §5; only major criteria changes revise this file.
