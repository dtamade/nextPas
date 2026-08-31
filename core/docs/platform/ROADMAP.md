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
| Wine matrix (25) | **pass=25** modules via `platform-wine-ci-matrix.sh` (secondary; never substitutes for real Windows) |
| Real Windows GHA | **28 platform-gate `ci-matrix`** (+… +pty +watch +console; GHA 30168411064 pass=29 fail=0 with mem.host); wine **25** secondary |
| Tier-2 Linux arches | aarch64 / arm32 / riscv64 forced-compile (13 modules) |
| Readiness vs completion | Split held: `platform_poller_*` readiness; IOCP in `io.reactor.iocp` |

### 2.2 What is incomplete or dishonest-risk

| Gap | Severity | Notes |
|-----|----------|--------|
| Windows beyond documented 28 platform gates | **P1** | Full AcceptEx-ConnectEx depth / modules outside platform list not in matrix |
| `async-windows-native-smoke` job red | **P2 (not platform)** | Owner **net/async**; not a platform facade gate or promote blocker |
| macOS beyond documented 10 platform gates | **P1** | Layer A fail-closed only; whole job (async inventory) is not platform evidence |
| `platform.signal` Win64 runtime delivery | **P2** | D3.a: forced-compile + contract green; wine runtime not matrix (console Ctrl handler) |
| Windows secure-zero native export | **P2** | D3.b closed: permanent FillChar+barrier; no stable DLL export across Wine+real Windows |
| dual-IO symbols on `platform.process` | **P2** | D3.c: **permanent owner-only** (no sunset this program) |
| Deferred F7/F9/F10 | **P3** | Mapping symmetry, ALen rename, diagnostics — Won't unless consumer pain |
| F14 freetype | **P3** | D3.d: stays under platform as optional host binding |
| Doc authority sprawl | **P0 docs** | Multiple “roadmaps”; fixed by this file becoming sole forward map |
| Stale claims in older docs | **P2 docs** | Live inventory claims scrubbed 2026-07-21 (wine **24**, Windows **27**); historical decision-log rows keep period numbers |

### 2.3 Host truth (honest)

| Host | Current tier | Next honest claim |
|------|--------------|-------------------|
| Linux x86_64 | focused-runtime | keep green |
| Windows x86_64 | **`ci-matrix` for 28 platform gates** + wine **25** secondary | expand candidates one-at-a-time; keep wine + GHA green |
| macOS | **`focused-runtime` layer A** (10 platform gates incl. console; script total may be 11) | keep fail-closed green; do not treat whole job as platform evidence |
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
| **D1.a** | Keep wine matrix green (current **25** modules); optional expand without claiming ci-matrix | `platform-wine-ci-matrix.sh` pass=total; honest SKIP/FAIL classification |
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
| 4 wine green | local `platform-wine-ci-matrix.sh` pass=14 fail=0 skip=0 (**as of 2026-07-17**; current wine total=**24**) |
| 5 log language | scripts print `truth=ci-matrix; … scope=documented-17-gate-set` |

**Documented superseding gate list (ci-matrix scope, 18 after 2026-07-19 promote):**
`platform.{time,memory,sync,thread,io,process,files,fs,path,env,mmap,random,socket,error}`,
`io.reactor.iocp`, `poller.windows_runtime_smoke`, `platform.io.windows_real`,
`platform.socket.windows_real`.

**Not claimed:** full-host Windows parity; modules outside the list (e.g. signal, secure-zero native); AcceptEx/ConnectEx beyond existing smoke gaps; TUI true-console product path.

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

| Slice | Item | Acceptance | Status |
|-------|------|------------|--------|
| **D3.a** | `platform.signal` Win64 forced-compile + contract (no silent stubs) | `test_platform_windows_signal_compile_gate` with `NEXTPAS_FORCE_HOST_WINDOWS`; FFI owns `GenerateConsoleCtrlEvent`; uses `platform.error` | **Done** |
| **D3.b** | Windows secure-zero native path or explicit permanent unsupported | permanent FillChar+barrier (`pszbWindowsPermanentFallback`); truth-matrix honest | **Done** |
| **D3.c** | dual-IO deprecation schedule | permanent owner-only on `platform.process`; no sunset this program | **Done** |
| **D3.d** | F14 freetype boundary decision | stay under platform as optional host binding; move-out needs separate owner lane | **Done** |
| **D3.e** | Deferred F7/F9/F10 only if consumer pain forces | otherwise stay Won't | **Won't** (default) |

**D3.a notes:** Wine does not reliably deliver console control events; signal is intentionally **not** in the 14-module wine matrix. Evidence is forced-compile + source-contract on Linux host, plus existing real-Windows path when compiled under `NEXTPAS_WINDOWS`.

**D3.b notes:** Wine `ntdll` has no `RtlSecureZeroMemory` export; SDK `SecureZeroMemory` is FORCEINLINE. Promoting a raw external would break wine/link honesty. Permanent fallback is the closed decision until a dual-host export proof exists.

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

**D5 extensions (audit F-021 / F-025, not opened as waves):**

- Optional fuzz/soak for `files`/`path`/`socket`/`process` (no default harness this program).
- process/socket/sync **file split** only when a consumer pain + landing plan exists (F-004/F-005 deferred).
- Strategic Go/Rust gaps (typed errors, cancel tokens) stay L1+ / Won't at L0.

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
2. **D1.a–D1.d** done; Windows **`ci-matrix` expanded through 28 platform gates** (+watch Batch-21b; multi-dir Batch-23; **+console Batch-console-promote**); wine secondary **25**; keep wine + GHA green.
3. **D2.a–D2.c** done; **10-gate macOS `focused-runtime`** (+memory Batch-5B; +console 2026-07-26); keep GHA matrix green.
4. **D3.a–D3.d** done (signal compile, secure-zero permanent fallback, dual-IO owner-only, freetype stay); D3.e remains Won't.
5. **Windows watch expand series closed** (2026-07-21): S1–S3 + multi-dir + L2 multi-path/AddTree; **no `bWatchSubtree`**.
6. **D4/D5** opportunistic / owner-gated.
7. **Standing default:** §4 maintenance gates + keep Windows 28-gate / macOS 10-gate green. New platform work only with consumer pain or named owner (FreeBSD/Android/D5).

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
| 2026-07-17 | **D3.a done**: Windows signal forced-compile uses `platform.error` + `GenerateConsoleCtrlEvent` FFI; compile gate forces `NEXTPAS_FORCE_HOST_WINDOWS`. Not wine-matrix. |
| 2026-07-17 | **D3.b done**: Windows secure-zero closed as permanent FillChar+barrier (`pszbWindowsPermanentFallback`); no RtlSecureZeroMemory export on Wine. |
| 2026-07-17 | **D3.c done**: dual-IO permanent owner-only on `platform.process`; no sunset this program. |
| 2026-07-17 | **D3.d done**: freetype stays under platform as optional host binding; move-out requires separate owner lane. |
| 2026-07-17 | **D3.e**: F7/F9/F10 remain Won't unless consumer pain forces reopen. |
| 2026-07-19 | Expand matrix: add `platform.error` to wine matrix (14→15) and Windows scripts (17→18 candidate). Local wine single-gate + full matrix evidence required; do **not** promote 18-gate `ci-matrix` until GHA `test-windows-runtime` durable green. Fix goal-tree contract tokens + wine list honesty (dl/pipe/fmt/info/which suite-exists-not-gated). |
| 2026-07-19 | **fix(io)**: Windows-safe `TPoller.AsyncReadv`/`AsyncWritev` (empty-case after IFDEF strip). Unblocks GHA `poller.windows_runtime_smoke`. Landed `4b831227f`. |
| 2026-07-19 | **18-gate `ci-matrix` promoted**: GHA `test-windows-runtime` pass=18 fail=0 (run 29683362919 @ `4b831227f`); includes `platform.error`. Not full-host Windows parity. |
| 2026-07-19 | Expand matrix: add `platform.fmt` to wine (15→16) and Windows scripts (18→19 candidate). Local wine evidence required; promote 19 only after GHA green. |
| 2026-07-19 | **Batch-0**: fix `test.expect` Windows IUnknown calling convention (`stdcall`/`cdecl`); GHA Windows matrix pass=19 (run 29686191527 @ `e9f203e45`). |
| 2026-07-19 | **Batch-1**: promote documented 19-gate set to `ci-matrix` (includes error + fmt). Not full-host Windows parity. |
| 2026-07-19 | **Batch-2**: add `platform.info` to wine matrix (16→17). Windows scripts unchanged (no 20-gate candidate this batch). |
| 2026-07-19 | **Batch-3**: add `platform.which` to wine matrix (17→18). Windows scripts unchanged. |
| 2026-07-19 | **Batch-4**: add `platform.dl` to wine matrix (18→19) after Linux 19/0 + wine smoke 8/0. Windows scripts unchanged. |
| 2026-07-19 | **Batch-5A**: add `platform.memory` to macOS matrix script (8→9 candidate). Promote only after GHA `test-macos` pass=9. |
| 2026-07-19 | **Batch-5B-fix**: Darwin-safe `TThreadID` zero; Darwin `MAP_ANON`; POSIX virtual commit/decommit via `mprotect`; R20 `CreateFileW` hTemplateFile `nil`; re-apply ABI guards after test v8.9 regression + source-contract locks; Darwin memory GHA path (no-heaptrc Makefile, FillChar secure-zero, SysGetMem aligned_alloc, 16MiB align cap). |
| 2026-07-19 | **Batch-5B promote**: macOS **9-gate focused-runtime** (GHA run 29696318492 @ `d160cbc46`, fail-closed matrix step success). Not full-host macOS parity. |
| 2026-07-19 | **Batch-6**: add `platform.pipe` to wine matrix (19→20) after Linux 15/0 + wine smoke 8/0. Full wine matrix pass=20. Windows scripts unchanged. |
| 2026-07-20 | **Batch-7**: add `platform.args` to wine matrix (20→21) after Linux 9/0 + wine smoke 6/0. Windows scripts unchanged. |
| 2026-07-20 | **Batch-8**: fix Windows resource error uses + wine smoke; add `platform.resource` to wine matrix (21→22). Linux 19/0, wine smoke 12/0. |
| 2026-07-20 | **Batch-9 residual**: `platform.watch` wine smoke fails (watch_create → PLATFORM_ERR_UNSUPPORTED). Not matrix-gated. |
| 2026-07-20 | **Batch-10**: Windows scripts 19→20 candidate (+`platform.info`). |
| 2026-07-20 | **Batch-11**: promote Windows 20-gate `ci-matrix` after GHA pass=20 (run 29718874441 @ `534d5e7c4`). Fix Darwin watch `uses platform.error` (macOS matrix compile). |
| 2026-07-20 | **Batch-12**: fix pty wine smoke (`Rows`/`Cols`); honest watch wine UNSUPPORTED smoke; wine matrix 22→24. macOS platform matrix green pass=10 on run 29719632518 (job red only on non-platform async). |
| 2026-07-20 | **Batch-13**: docs — macOS layer A (fail-closed) vs layer B (whole job); Windows **20 platform gates** vs script total 21 (+mem.host). ABI recheck: wine contract 3/0 (stdcall + TThreadID still locked). |
| 2026-07-20 | **Batch-14**: Windows scripts candidate **+platform.which** (no promote until GHA green). Queue after: dl → args → pipe. |
| 2026-07-20 | **Batch-14b**: promote **21 platform-gate** set (+which) after GHA pass=22 (run 29721371136 @ `0cb2471bc`; which PASS; +mem.host in total). |
| 2026-07-20 | **Batch-16**: Windows scripts candidate **+platform.dl** (no promote until GHA). Queue after: args → pipe. |
| 2026-07-20 | **Batch-15a design**: Windows watch via ReadDirectoryChangesW — see [watch-windows-design.md](watch-windows-design.md) (docs only; no implement). |
| 2026-07-20 | **Batch-16b**: promote **22 platform-gate** set (+dl). GHA 29727006733 pass=23 fail=0 (dl + poller); fix `TPoller.AsyncSendTo/RecvFrom` empty case on Win64. Queue after: args → pipe. |
| 2026-07-20 | **Batch-17**: Windows scripts candidate **+platform.args** (no promote until GHA green). Queue after: pipe. |
| 2026-07-20 | **Batch-17b**: promote **23 platform-gate** set (+args) after GHA pass=24 (run 29728715160 @ `00e895e1a`; args PASS; +mem.host in total). Queue after: pipe. |
| 2026-07-20 | **Batch-18**: Windows scripts candidate **+platform.pipe** (no promote until GHA green). |
| 2026-07-20 | **Batch-18b**: promote **24 platform-gate** set (+pipe) after GHA pass=25 (run 29729281116 @ `c1a092433`; pipe PASS; +mem.host in total). |
| 2026-07-20 | **Batch-15 S1**: Windows `platform.watch` create/add/close via CreateFileW + DirHandle; poll still UNSUPPORTED. Wine smoke updated. Queue: S2 poll RDCW. |
| 2026-07-20 | **Batch-19**: Windows scripts candidate **+platform.resource** (no promote until GHA green). |
| 2026-07-20 | **Batch-19b**: promote **25 platform-gate** set (+resource) after GHA pass=26 (run 29730911054 @ `e0441ae62`; resource PASS; +mem.host in total). |
| 2026-07-20 | **Batch-15 S2**: Windows watch `ReadDirectoryChangesW` poll (one event + timeout); wine smoke create/timeout. Queue: S3 rename/delete. |
| 2026-07-20 | **Batch-20**: Windows scripts candidate **+platform.pty** (no promote until GHA green). |
| 2026-07-20 | **test**: Linux watch `detect delete` drain residuals before unlink (R30 multi-event shadow fix). |
| 2026-07-20 | **Batch-20b**: promote **26 platform-gate** set (+pty) after GHA matrix pass=27 (run 29734704405 @ `d2eb8f890`; pty PASS). Job may red on async-native-smoke (not platform evidence). |
| 2026-07-20 | **Batch-15 S3**: Windows watch overflow → `PLATFORM_ERR_AGAIN` + re-arm; wine smoke delete/multi soft. Queue: optional watch matrix candidate. |
| 2026-07-20 | **Batch-21**: Windows scripts candidate **+platform.watch** (S1–S3; no promote until GHA green). |
| 2026-07-20 | **Batch-21b**: promote **27 platform-gate** set (+watch) after GHA matrix pass=28 (run 29746628175 @ `2020db503`; watch PASS). Job may red on async-native-smoke (not platform evidence). |
| 2026-07-20 | **Batch-22**: watch smoke Wine vs real Windows detect; hard create/delete on real Windows after RDCW Pending fix. |
| 2026-07-20 | **Batch-23**: Windows multi-dir watch slots (8) for fs.watch multi-Add; add returns wd; remove(wd) works. |
| 2026-07-20 | **Owner note**: `async-windows-native-smoke` job step is **net/async** lane (`core/docs/net-async-io/WINDOWS-NATIVE-ASSESSMENT.md`); platform matrix green does not require that step. |
| 2026-07-20 | **fix(RDCW)**: arm with sync empty batch keeps `Pending=True` so poll waits on notify event (GHA 29752923987 create+delete hard PASS; matrix pass=28 fail=0). |
| 2026-07-20 | **test**: watch smoke two-dir multi-dir events + multi-event count loop; diagnostics pending_count. |
| 2026-07-20 | **test(fs)**: L2 `test_fs_watch_wine` hard create + two-dir multi-path on real Windows; Wine soft OK (consumes platform multi-dir). |
| 2026-07-21 | **chore**: platform watch smoke diag gated by `NEXTPAS_WATCH_DEBUG=1` (quiet default CI). |
| 2026-07-21 | **test(fs)**: L2 AddTree nested create via multi-dir walk (no bWatchSubtree); fits WIN_MAX=8. Landed `1790012ef`. |
| 2026-07-21 | **GHA AddTree evidence**: run [29759582229](https://github.com/dtamade/nextPas/actions/runs/29759582229) @ `1790012ef` — steps **`Run Windows runtime matrix` = success** and **`L2 process/fs/path/env Windows min-set` = success** (suite includes `l2.fs.watch` / AddTree). Local wine-runtime-smoke **6/0**. Async Windows native step hung on this SHA (pre-Q38; **net/async**, not platform evidence). |
| 2026-07-21 | **Decision (recursive)**: RDCW `bWatchSubtree=True` **out of scope** for v1 product path. Platform always arms with `bWatchSubtree=False`. Tree watch = L2 `AddTree` walk + multi-`Add` only (inotify-parity, WIN_MAX=8). Reopen only via explicit consumer batch + design revise. See [watch-windows-design.md](watch-windows-design.md). |
| 2026-07-21 | **Watch series closeout**: Batch-15 S1–S3 + Batch-22/23 multi-dir + L2 multi-path/AddTree **done**. **27 platform-gate** matrix + L2 `l2.fs.watch` host-windows green. **No further platform.watch expand batch** unless consumer pain. Next: standing maintenance (§4); D4/D5 opportunistic / owner-gated. |
| 2026-07-21 | **Docs hygiene (H3/H1)**: live inventory wine matrix count **14→24** (matches `platform-wine-ci-matrix.sh`); master-spec watch claim updated off UNSUPPORTED; residual snapshot marked historical; current counts point at this ROADMAP. |
| 2026-07-21 | **Batch-console-wine**: add `platform.console` to wine matrix (**24→25**) after Linux console 22/0 + raw 5/0 + wine-runtime-smoke 8/0 + full wine matrix pass=25 fail=0. TUI hangs Windows true-console on this ladder. Windows scripts **+console candidate** (no 28-gate ci-matrix promote until GHA green). Consumer-contract-audit refreshed (Windows readiness = ci-matrix for documented 27, not source/compile-only). |
| 2026-07-26 | **Batch-console-promote**: promote **28 platform-gate** set (+console) after GHA `test-windows-runtime` success run **30168411064** @ `5464b31c4` (PASS platform.console; matrix pass=29 fail=0 with mem.host). Facade smoke only — not TUI true-console product. Docs + matrix script scope strings updated 27→28. |
| 2026-07-26 | **Audit closeout F-001…F-025**: console read/write value/sentinel **failure=-1** (F-001); Darwin/FreeBSD termios console path (F-002); wine/host hard asserts (F-003); docs for dual-IO ban / no process-socket-sync split / freetype-x11 stay / host-capability-matrix (F-004…F-025). macOS matrix **+console candidate** only (no 10-gate promote without GHA). |
| 2026-07-26 | **hotfix(macOS matrix red)**: F-002 console path used Linux-only `pollfd` alias → all macOS focused gates exit 2 (Core CI run 30196911416). Fix: portable `TPollFd` (posix.base). Prevention: `console` added to simulated-host forced-compile matrix (darwin/android/freebsd/unix); matrix then exposed empty errno `case` in `platform.error` on Android/generic-unix → subset mapping added. Governance docs trimmed to limits (README 79/80, master-spec 119/120). Non-platform Core CI reds remain: math×2 text.conv, `format` registry, FreeBSD FPC 3.2.2 `reference to`. |
| 2026-07-26 | **Simulated-host matrix expanded to 11 facades** (+error/files/path/env/socket/memory). Exposed and fixed: `socket` impl-uses dangling comma on Android/generic-unix (never compiled there) + missing errno/`AF_UNSPEC`/`O_NONBLOCK` in android/unix base. `files` stays excluded from the generic-unix leg per wave10 contract (generic unix stat deferred — no invented stat record; first attempt to add one was correctly blocked by `test_platform_host_abi_wave10_posix_stat_hosts`). Evidence: matrix 4/4, wave10 7/7, wave5 5/5, socket_types 13/13, struct_sizes 12/12, return_semantics 25/25, Linux socket 12/12 0-leak, tier-2 aarch64/arm32/riscv64 compile exit 0. |
| 2026-07-26 | **macOS console promoted → 10-gate `focused-runtime`**: hotfix landed main@`20f9c6de6`; GHA Core CI **30198722396** layer A fail-closed matrix **pass=11 fail=0** (10 platform + mem.host), console 22/22 0-leak on macos-14 aarch64. Job-level red is non-platform `http.threaded_host` (`nextpas.core.log.pas` C-styled operators, log/http lane) — layer B, not platform evidence. Docs/script updated 9→10 (master-spec, goal-tree, residual, ROADMAP §2/§5, matrix script banner). |
| 2026-07-26 | **Simulated-host matrix batch-3 → 19 facades** (+args/dl/fmt/info/pipe/random/secure/which). Exposed and fixed: `random`/`dl`/`args` impl-uses parallel-IFDEF gaps on Android/generic-unix (ELSEIF+ELSE rewrite); android/unix base gained `ESysEACCES/ENOENT/ENOMEM`. `which` excluded from generic-unix leg (which→fs→files hits deferred stat, same wave10 rule as files). Evidence: matrix 4/4; Linux runtime args 9/9, dl 19/19, random 15/15, which 14/14; wave10 7/7; facade_surface 3/3; return_semantics 25/25. |
| 2026-07-26 | **Simulated-host matrix batch-4 → 24 facades tracked** (+mmap/process/pty/resource/signal; darwin/freebsd legs compile all 24, android 23, generic-unix 20). Exposed and fixed: `signal` fallback-stub block had no uses (PLATFORM_ERR_* unresolved) + FreeBSD block missing `posix.ffi` (kill/getpid); `process` inner parallel-IFDEF → ELSEIF+ELSE; android/unix base gained `ESysEPERM`; `PLATFORM_SC_OPEN_MAX` generic-unix `-1` sentinel (sysconf fails → caller fallback, same pattern as `_SC_PAGESIZE`). Deferred exclusions: `pty` off android+generic-unix (no verified termios/pty ABI), `mmap` off generic-unix (mmap→files hits deferred stat). Evidence: matrix 4/4; wave10 7/7; facade_surface 3/3; return_semantics 25/25; Linux runtime signal 5/5, resource 10/10, pty 9/9, socket 12/12, mmap 33/33, process 48/48 all 0-leak; tier-2 aarch64/arm32/riscv64 compile fail-lines=0. |
| 2026-07-26 | **Simulated-host matrix batch-5 → full coverage, 29 facades tracked** (+fs/io/watch/freetype/x11 — every `platform.*` facade now in the matrix). Exposed and fixed: `watch`/`io` fallback-stub blocks had no uses (PLATFORM_ERR_*, never compiled); `watch` fallback was missing 7 record-method impls (IsCreated/IsDeleted + all 5 TPlatformWatcher methods) — dead-incomplete code. Lesson: inserted fallback `uses` condition must be spelled `not (A or B…)`, not `not A and not B…` — io/watch source-contract tests locate the unsupported region by first occurrence of the literal marker. `fs` excluded from generic-unix leg (fs→files deferred stat). Evidence: matrix 4/4; io 23/23, watch 17/17 (incl. source contracts), fs 39+4+14, watch-suite 7/7; wave10 7/7; facade_surface 3/3; return_semantics 25/25. |
| 2026-07-26 | **D4 FreeBSD assessment (no work opened)**: `test-freebsd` perma-red root cause = `pkg install fpc` ships FPC 3.2.2, which lacks `functionreferences` modeswitch needed by `nextpas.core.base` (`reference to`) — every compile of core/src fails at the toolchain, not at platform code. Viable fix path identified: replicate the macOS job's "Build FPC trunk from source + actions/cache" pattern inside the cross-platform-actions VM (bootstrap 3.2.2 → gmake trunk → install under `$GITHUB_WORKSPACE` so host-side cache persists it; first run ~25 min, cached runs ~2 min). Aligned with D4 "stabilize cross-platform-actions compile + smoke". Not opened now: repo-level workflow change + multi-round CI debugging cost; queue behind the current test-linux green push. Honest-skip (`exit 0` on fpc<3.3) rejected — hides toolchain state without producing evidence. |
| 2026-07-26 | **Simulated-host matrix batch-6 → windows leg added (5 legs)**. Rationale: same structural gap as the F-002 macOS incident — Windows forced-compile coverage was scattered (utf16 gate 8 units, socket/poller gates) with no all-facade local gate; Windows compile breaks in untouched facades surfaced only in GHA. New leg is a **true cross target** (`-Twin64 -Px86_64 -Cn`, FPC built-in `WINDOWS` → settings.inc), unlike the `-dNEXTPAS_FORCE_HOST_*` unix legs — stronger evidence tier for the same cost. Leg compiles **all 29 facades** (resource/signal/watch fall to their UNSUPPORTED stubs; freetype/x11/fmt/info/secure are host-agnostic) + windows.base/ffi/utf16; asserts NEXTPAS_WINDOWS selected, no NEXTPAS_LINUX/NEXTPAS_UNIX residue. First run: **0 breaks** — batch-4/5 fallback-uses/record-method fixes had already paid the Windows-branch debt. CI feasibility pre-verified: existing `-Twin64` gates run unguarded in `make -C core test`, so test-linux runners have win64 cross units. Evidence: matrix 5/5; wave10 7/7; facade_surface 3/3; return_semantics_contract 25/25; goal_tree 7/7; cross_ci_matrix 3/3; wine_ci_matrix 3/3; hygiene pass; diff-check clean. |
| 2026-08-31 | **Darwin heaptrc gap closed (landing-perfection-20)**: `test_platform_memory` Makefile removed Darwin `FPC_FLAGS` override that disabled `-gh/heaptrc` (focused-runtime only). Root cause was posix_memalign/free + mmap/mprotect/munmap mix aborting at exit under heaptrc; fix retained SysGetMem fallback, mprotect-only commit/decommit, MAP_ANON ($1000) isolation, 16MiB cap, Darwin madvise skip. Heaptrc now congruent on Darwin and Linux via `common.mk` HEAPTRC env-channel (`haltonnotreleased,log=` + dump pins, 0 unfreed). `platform.memory` adds `TryBuildRawSize inline` + realloc shrink zero-copy + fail-closed grow stability. Evidence: `make -C core/tests/nextpas.core.platform.memory/test_platform_memory clean test` 0 unfreed on Linux; `bash scripts/build-hygiene-check.sh` pass. |

---

## 7. Owner confirmation (accepted)

- [x] D0 doc authority model accepted
- [x] D1 Windows ladder order (wine keep → GHA expand → promote) accepted
- [x] Windows `ci-matrix` criteria (section D1) accepted as written
- [x] D2 macOS after D1.b pattern accepted
- [x] D3 dual-IO stays owner-only unless we schedule deprecation (default: no removal this program)
- [x] D3.a–D3.d debt cleanup decisions accepted as documented above
- [x] D4/D5 remain low priority unless hosts/owners appear

Autonomous execution follows §5; only major criteria changes revise this file.
