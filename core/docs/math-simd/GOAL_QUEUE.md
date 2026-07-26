# math-simd Goal Queue

> Last updated: 2026-07-26
> Lane: `math-simd` worktree (`codex/math-simd`)
> Purpose: **single CURRENT pointer** so agents run end-to-end cards without human “继续”.
> Maintenance posture: [`MAINTENANCE.md`](MAINTENANCE.md) (debt inventory + re-verify baseline).

## How to execute (agent contract)

1. Work is planned in **BATCH**es; `CURRENT` is always **one Card** inside an active Batch.
2. Read **only** the active Batch + `CURRENT` card (+ linked roadmap sections).
3. Implement within **IN_SCOPE_PATHS**; anything outside → **STOP** (Blocked).
4. **UNIT_TESTS required**: new behavior = RED unit tests first; bugfix = regression test; leaf = parity + source-contract + runtime slot assert.
5. Run **GATES** exactly; on failure fix or Blocked (**never skip / never lower strict**).
6. Fill **EVIDENCE** (commands + exit codes + pass counts + named tests). No evidence → not done.
7. One logical **commit** per Card (message = card intent); advance `CURRENT` to **NEXT**.
8. When all cards in a Batch are done: run **BATCH_GATES**, fill batch EVIDENCE, mark Batch closed.
9. Do not auto-start Wave 4 walls. Do not wait for chat「继续」inside an approved Batch.

### Card template (copy for new goals)

```text
GOAL_ID:
STATUS: pending | in_progress | done | blocked
NEXT:
WHY:
IN_SCOPE_PATHS:
OUT_OF_SCOPE:
UNIT_TESTS:
DELIVERABLES:
GATES:
DoD:
EVIDENCE:
STOP:
BLOCKED_UNTIL: (optional)
```

---

## CURRENT

```text
CURRENT=M3.4  # M3.2 done 2026-07-26;M3.3 保持 optional。用户 2026-07-26 指令:不再调用 Codex,Claude 全权推进 math/simd
```

---

## BATCH M3 — post-audit polish wave 【active · Codex-approved 2026-07-26】

> Mode A 内打磨:修债/拆文件/补证据。Codex 审核结论:有条件批准。
> **OUT_OF_SCOPE(写死)**: F-006 L0/L3 拆分;生产门面拆分;simdgen 强制迁移;Tan 新 API
> (caller scratch 等);默认 focused 全量 `-gh`;Wave 4 walls;新 ISA;新公共 API。

### M3.1 — F-003 根治:Tan scratch 栈上分块  【done 2026-07-26】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | M3.2 |
| **WHY** | F-003 现修复为每调用全量 GetMem×2(2×4N 字节堆峰值);根治为固定栈分块,消除 Tan 热路径堆分配 |
| **IN_SCOPE_PATHS** | `core/src/nextpas.core.simd.avx2.batch.inc`;`core/src/nextpas.core.simd.sse2.batch.inc`;`core/tests/nextpas.core.simd/nextpas.core.simd.dispatchapi.testcase.pas`;findings/MAINTENANCE 状态行 |
| **OUT_OF_SCOPE** | ArraySinCos;threadvar 复活;caller-provided scratch API;F64 Tan(无堆);微基准 |
| **DELIVERABLES** | `CTanScratchElems = 512` 局部常量;`LSin/LCos: array[0..511] of Single` 栈数组;外层 while chunk 循环复用现有 Sin/Cos 叶 + 现有 div asm 尾路径;去 try/finally/GetMem/FreeMem |
| **UNIT_TESTS** | `Test_BatchF32_ArrayTan_ChunkBoundary_NearParity`:counts 0/1/7/8/511/512/513/1027 逐元素 vs `ScalarArrayTanF32`;能 force 则 force SSE2+AVX2 各跑;count=0 不动 dst;source contract:`AVX2ArrayTanF32`/`SSE2ArrayTanF32` 体内无 `GetMem/FreeMem` |
| **GATES** | `make focused FOCUS=core/tests/nextpas.core.simd`(允许 +N 新测试);hygiene;`git diff --check` |
| **DoD** | 门禁绿;Tan 体内零堆分配有契约锁定;findings F-003 标 residual hardening closed;一 commit |
| **EVIDENCE** | 2026-07-26: focused **1764**/0(1762+2 新测试);hygiene pass;math clean test exit 0 + heaptrc 0 unfreed;diff-check clean;`Test_BatchF32_ArrayTan_ChunkBoundary_NearParity`(SSE2+AVX2 force,counts 0/1/7/8/511/512/513/1027)+ `Test_ArrayTanF32_NoHeapScratch_SourceAudit`(GetMem/FreeMem 禁 + CTanScratchElems 必现) |

### M3.2 — F-007 收尾:dispatchapi 巨测拆分(方案 A′)  【done 2026-07-26】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | M3.3 |
| **WHY** | dispatchapi.testcase.pas 23879 行 / 单类 251 Test_ 方法;review/bisect/并行编译差 |
| **IN_SCOPE_PATHS** | `core/tests/nextpas.core.simd/nextpas.core.simd.dispatchapi*.pas`(新增拆分单元);`nextpas.core.simd.test.lpr`;size-report/MAINTENANCE |
| **OUT_OF_SCOPE** | 改断言/阈值/容差;重命名 Test_ 方法;合并重复测试;改 hook 语义;生产代码 |
| **DELIVERABLES** | 方案 A:按主题缝拆成 5–7 个 `TTestCase_*` 新类/新单元 + `dispatchapi.support.pas`(TSourceLines/hook/globals/基类);文件头 NEON/RISCVV 条件编译镜像块逐单元复制;lpr 注册全量 |
| **UNIT_TESTS** | 拆前/拆后 `published procedure Test_` 计数对账(拆前实测值);focused 总数与 M3.1 后基线一致 |
| **GATES** | focused 总数不漂;hygiene;`git diff --check` |
| **DoD** | 每单元 <5k 行;逻辑 diff≈0;old→new suite 名对照记录;一 commit |
| **步骤纪律** | 先 support 提取可编译 → 再按主题搬类 → 最后删空壳;禁止同 commit 改断言 |
| **EVIDENCE** | 2026-07-26: 原单元 24012→**7159** 行(保留 71 个脚本耦合方法 + wiring helper 同文件);新增 6 单元:support **353**(13 共享 helper + TSourceLines + hook 全局)、controlplane **3995**(59+2 方法)、parity **3084**(29 方法 + 36 Synthetic private)、batchparity **1819**(23)、capabilities **2336**(37+3)、nonx86 **5742**(29)。质量守恒:interface 声明 71+61+29+23+40+29=**253** = implementation body 253。focused **1764**/0(与 M3.1 基线一致,零漂移),Suites 61→**65**(+4 新注册);hygiene pass;math clean test exit 0 + heaptrc 0 unfreed;`git diff --check` clean。脚本改动仅 `check_nonx86_helper_semantics.py` DISPATCHAPI_FILE 重定向 → nonx86 单元;用脚本自身 extract/require 函数隔离对照:HEAD 原文件 vs 新单元提取行为**逐字节等价**(相同 5/6/16 缺失 fragment 集,清单漂移系历史遗留,见 M3.4)。wiring_sync/key_slot_audit 与 main 输出一致(均为 pre-existing 失败,见 M3.4)。**DoD 偏差记录**:①「每单元 <5k」两处例外:原单元 7159(脚本耦合方法不可移)、nonx86 5742(单类内聚不拆),已记入 MAINTENANCE size report;②「audit green」不可达成——audit 门在 main 上已系统性死亡(fail-fast 掩盖 13/21 步失败),M3.2 以「audit 零新增失败(main 逐字节对照)」替代,恢复立卡 M3.4 |

### M3.3 — F-009 切片:concurrent-heaptrc opt-in  【pending · optional】

| Field | Content |
|-------|---------|
| **STATUS** | pending (optional) |
| **NEXT** | IDLE |
| **WHY** | 并发 suite 默认无 heaptrc;防其他并发泄漏回流(Tan 主路径 M3.1 后已无堆) |
| **IN_SCOPE_PATHS** | `core/tests/nextpas.core.simd/Makefile`;MAINTENANCE debt 表 |
| **OUT_OF_SCOPE** | 默认 `test`/`focused` 挂 heaptrc |
| **DELIVERABLES** | `concurrent-heaptrc` 目标(-gh,解析 0 unfreed,同 cpuinfo-heaptrc 模式) |
| **GATES** | 新目标本地跑通;hygiene |
| **EVIDENCE** | (待填) |

### M3.4 — audit 门系统性恢复  【active 2026-07-26】

| Field | Content |
|-------|---------|
| **STATUS** | active |
| **NEXT** | M3.3 (optional) → IDLE |
| **WHY** | `make audit` 第一步 simdgen --verify 失败即停,掩盖了后续 13/21 步失败;main 逐字节同红(M3.2 期间发现)。整个 simd 契约门形同虚设:文档重组(9ab2e83fc)与 inc 重命名(e42ac7416)后脚本从未同步 |
| **失败分类(2026-07-26 实测)** | ① 路径遗孤:contract_roadmap(缺 docs/simd/GOAL_TREE.md)、wiring_sync(checklist.md)、riscvv_native_evidence / linux_evidence / windows_freeze / cpuinfo_runner(closeout.md / cpuinfo.md 等)、helper_semantics(neon.shared_wide_memory_asm.inc)、shell_runner(intrinsics.experimental Makefile 契约);② 契约基线漂移:dispatch_contract_signature(TSimdDispatchTable sha,分组重构未更新基线)、avx512_alignment(base.pas 缺 64B 否认 token)、sse2_structure(failure_count=8,缺 truth 行 + migration-map 文档)、intrinsics_coverage_layout / intrinsics_experimental_status、helper_semantics fragment 清单(5/6/16 缺失);③ 缺失载体:publicabi_smoke.h/.ps1、BuildOrTest.bat、intrinsics.x86.sse2.pas;④ simdgen DRIFT×4:baseline 分组前缀(生成器无 group 模型,1398 diff 行)+ AVX2 Add/Mul 小数组快速路径(401540bad)+ Clamp NaN-safe(6835a2aec);⑤ 跨模块 token:cpuinfo_boundary 对 hash.sha256 / tls.chacha20poly1305 期望失配;⑥ key_slot_audit:NEON issues=58 / RISCVV issues=38(与 main 一致) |
| **IN_SCOPE_PATHS** | `core/tests/nextpas.core.simd/check_*.py`;`core/tools/simdgen/**`;`core/src/nextpas.core.simd.base.pas`(仅契约注释 token);simd 文档 truth 源;`core/tests/nextpas.core.simd/Makefile` |
| **OUT_OF_SCOPE** | 改测试断言/阈值;hash/tls 生产源码(跨 lane,只能改 checker 期望或报 Needs Review);删除仍有价值的检查逻辑(先修后删,删除需逐条论证) |
| **分波(每波一 commit)** | **W1** 路径遗孤:逐脚本判定「重定向到现存 truth 源 / 检查逻辑降级为现存文件 / 死检查删除并论证」;**W2** 契约基线有意更新:dispatch sha、avx512 token、sse2 structure、intrinsics 状态、helper_semantics fragment 对齐现代码;**W3** simdgen 同步:baseline 分组前缀建模(从 base.pas 解析 TSimdDispatchTable 派生 slot→group,避免手维护映射)+ Add/Mul 快速路径 + Clamp NaN-safe 入模板(先例 033d75664 FMA sync);**W4** key_slot 真值对账 + cpuinfo_boundary 跨模块期望(hash/tls 若需源码改动则 Needs Review);**W5** Makefile audit 改为逐步全跑不 fail-fast(收集全部失败再退出),防再次掩盖 |
| **GATES** | 每波后:`make -C core/tests/nextpas.core.simd audit` 失败步数单调下降;focused 1764/0 不漂;hygiene;终态 audit **全绿** |
| **DoD** | audit 21/21 步绿;focused/math 门不漂;每个被删检查有书面论证;EVIDENCE 记录每波前后失败步数 |
| **EVIDENCE** | (待填) |

### Audit remediation package  【done 2026-07-26】

P1 F-001…F-005/F-020 closed with source-contracts + rtl --fail-tests.
See root `findings.md` remediation table and commits on this branch.

### M0 — maintenance re-verify  【done 2026-07-26 · docs only】

| Field | Content |
|-------|---------|
| **STATUS** | done (no code change) |
| **NEXT** | IDLE |
| **WHY** | Mode A: green gates + doc truth + debt inventory after FF to main |
| **EVIDENCE** | HEAD `e9d92ab5b` (= main); hygiene pass; math clean test exit 0 + API surface **71/0** + Pascal **313**/0 + heaptrc 0; simd focused **1762**/0; inventory in `MAINTENANCE.md` |
| **OUT_OF_SCOPE** | Feature work; Wave 4 walls; neon-optin re-run (x86 host) |

### M1 — D-RTL-2/3 residual cut  【done 2026-07-26】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | IDLE |
| **WHY** | Close in-lane test RTL residuals that do not need thread owner |
| **IN_SCOPE_PATHS** | `core/tests/nextpas.core.simd/nextpas.core.simd.dispatchapi.testcase.pas`; `transcendental_f32.pas`; math-simd / math CONTRACT + MAINTENANCE docs |
| **OUT_OF_SCOPE** | D-RTL-1 `TThread` four files; production API; Wave 4 |
| **DELIVERABLES** | Local `TSourceLines` (fs ReadFile*); drop `Classes`/`TStringList` from dispatchapi; math `Power`; TextFormat-compatible `%f` |
| **GATES** | simd focused **1762**/0; transcendental_f32 standalone PASS; hygiene |
| **EVIDENCE** | 2026-07-26: focused **1762**/0; `transcendental_f32` **1050** checks / 0 failures |

### M2 — D-RTL-1 TThread residual cut  【done 2026-07-26】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | IDLE |
| **WHY** | Clear last math-simd test `Classes`/`TThread` residual; fix TWorkerThread FPC lifecycle root cause |
| **IN_SCOPE_PATHS** | `core/src/nextpas.core.thread.base.pas` (cross-module, required); simd concurrent/direct/cpuinfo.lazy tests; MAINTENANCE/CONTRACT |
| **OUT_OF_SCOPE** | thread pool redesign; non-simd TThread consumers in other modules |
| **DELIVERABLES** | `TWorkerThread` → BeginThread/WaitForThreadTerminate + Destroy join; migrate 4 simd test files off Classes.TThread |
| **GATES** | simd focused **1762**/0; concurrent standalone PASS; cpuinfo-focused green; `core/tests/nextpas.core.thread/test_thread` **19**/0; hygiene |
| **EVIDENCE** | 2026-07-26: all gates green; root cause = platform_thread_create skipped FPC TLS/heap init (same note as test.runner) |
| **CROSS-MODULE** | `nextpas.core.thread.base` lifecycle fix — required for correct worker threads under FPC host |

### Usability P0/P1 package  【done 2026-07-20】

Strict batch equal-length (default); `BatchLog*` alias; `TryBatchLn*`; docs CONTRACT 1.5 / API app-vs-kernel / numeric contract pointer.

### Usability Wave-2  【done 2026-07-21】

- P0-1: `vec.batch` / `vec.batch.simd` strict equal-length (same policy as scalar Batch)
- P0-2: simd README app-entry warning + math-first quickstart
- P0-3: RTL residual **6→4**（`fs.ReadDir` + dispatchapi `TSourceLines`）；`TThread` 四文件
  待 thread owner 加固 `TWorkerThread` 后再清零


---

## Wave C — post-representative expansion 【active】

> 代表集 23 叶 **不撤销**。Wave C 为显式扩展波；每批仍 UNIT_TESTS + evidence。
> 默认顺序：C0 → C1 → C2 → C3 → C4a → C4b → …；C5/C6 需点名。

### C0–C3  【done 2026-07-20】

### C4a — NEON BatchF64 core 8 leaves  【done 2026-07-20 · Sprint】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | C4b |
| **WHY** | F32/F64 symmetry for math F64 batch consumers |
| **LEAVES** | Add/Sub/Mul/Div/Min/Max/Abs/Neg F64 |
| **UNIT_TESTS** | FacadeFastSlots F64 core; Platform F64 remainder still scalar; `Test_BatchF64_ArrayCore8_Parity` |
| **EVIDENCE** | focused **1754**/0; neon **1754**/0; math exit 0; API 71/0 |

### C4b — NEON BatchF64 Sqrt / broadcast / Reduce  【done 2026-07-20 · Sprint】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | C4c |
| **WHY** | math F64 hot path (stats/scale/sqrt) after C4a core 8 |
| **LEAVES** | Sqrt, MulScalar, AddScalar, ReduceSum/Dot/Min/Max F64 |
| **UNIT_TESTS** | FacadeFastSlots C4b; Platform Exp/Linear/Clamp still scalar; `Test_BatchF64_SqrtBroadcastReduce_Parity` |
| **EVIDENCE** | focused **1755**/0; neon-optin **1755**/0; math exit 0; API 71/0 |

### C4c — NEON BatchF64 Linear / Clamp / Lerp / Fma / Axpy  【done 2026-07-20 · Sprint】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | C4d |
| **WHY** | F32 B3+B4+C1 mix symmetry for math F64 normalize/lerp/fma |
| **LEAVES** | Linear, Clamp, Lerp, Fma, Axpy F64 |
| **UNIT_TESTS** | FacadeFastSlots C4c; Exp/Rcp/Ceil/ReLU still scalar; `Test_BatchF64_LinearClampLerpFmaAxpy_Parity` |
| **EVIDENCE** | focused **1756**/0; neon-optin **1756**/0; math exit 0; API 71/0 |

### C4d — NEON BatchF64 Ceil/Floor/Trunc + ReLU/AbsDiff  【done 2026-07-20 · Sprint】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | C4e |
| **WHY** | F32 Wave C2+C3 rounding/utility symmetry on F64 |
| **LEAVES** | Ceil, Floor, Trunc, ReLU, AbsDiff F64 |
| **UNIT_TESTS** | FacadeFastSlots C4d; Exp/Rcp/Round still scalar; `Test_BatchF64_CeilFloorTruncReLUAbsDiff_Parity` |
| **EVIDENCE** | focused **1757**/0; neon-optin **1757**/0; math exit 0; API 71/0 |

### C4e — NEON BatchF64 Rcp / Rsqrt / Refine  【done 2026-07-20 · Sprint】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | IDLE |
| **WHY** | F32 B7–B9 reciprocal family symmetry; close F64 NEON representative path |
| **LEAVES** | Rcp, Rsqrt, RcpRefine, RsqrtRefine F64 (exact fdiv / fsqrt+fdiv) |
| **UNIT_TESTS** | FacadeFastSlots C4e; Exp/Round/Sin still scalar; `Test_BatchF64_RcpRsqrtRefine_Parity` |
| **EVIDENCE** | focused **1758**/0; neon-optin **1758**/0; math exit 0; API 71/0 |

### C5 — transcendental sample  【done 2026-07-20 · design + sample】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | C5b |
| **WHY** | ARM math BatchSin/Exp still scalar; prove NEON transcendental path |
| **DESIGN** | `core/docs/simd/design-c5-transcendentals.md` (D1–D5) |
| **LEAVES** | `ArraySinF32`, `ArrayExpF32` (Cody-Waite poly; near-parity) |
| **UNIT_TESTS** | FacadeFastSlots; Cos/Log/F64 Sin still scalar; `Test_BatchF32_ArraySinExp_NearParity` |
| **EVIDENCE** | focused **1759**/0; neon-optin **1759**/0; math exit 0 |

### C5b — Cos / SinCos  【done 2026-07-20 · Sprint】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | C5c |
| **LEAVES** | `ArrayCosF32`, `ArraySinCosF32` |
| **UNIT_TESTS** | FacadeFastSlots; Log/Tan/F64 Sin still scalar; `Test_BatchF32_ArrayCosSinCos_NearParity` |
| **EVIDENCE** | focused **1760**/0; neon-optin **1760**/0; math exit 0 |

### C5c — Log / Log2 / Log10  【done 2026-07-20 · Sprint】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | C5d |
| **LEAVES** | `ArrayLogF32`, `ArrayLog2F32`, `ArrayLog10F32` |
| **UNIT_TESTS** | FacadeFastSlots; Tan/F64 Log still scalar; `Test_BatchF32_ArrayLogFamily_NearParity` |
| **EVIDENCE** | focused **1761**/0; neon-optin **1761**/0; math exit 0 |

### C5d — F64 Sin / Exp  【done 2026-07-20 · Sprint】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | C5e |
| **LEAVES** | `ArraySinF64`, `ArrayExpF64` |
| **UNIT_TESTS** | FacadeFastSlots; F64 Cos/Log still scalar; `Test_BatchF64_ArraySinExp_NearParity` |
| **EVIDENCE** | focused **1762**/0; neon-optin **1762**/0; math exit 0 |

### C5e — F32 Sin/Exp true 4-wide NEON asm  【done 2026-07-20 · Sprint】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | C5e-ext |
| **LEAVES** | `NEONArraySinF32`, `NEONArrayExpF32` rewritten as `assembler; nostackframe` 4×f32 |
| **UNIT_TESTS** | FacadeFastSlots assembler contracts; existing Sin/Exp near-parity still green |
| **EVIDENCE** | focused **1762**/0; neon-optin **1762**/0; math exit 0 |

### C5e-ext — Cos/Log F32 + Sin/Exp F64 vector asm  【done 2026-07-20 · Sprint】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | IDLE |
| **LEAVES** | CosF32 4-wide; LogF32 4-wide; SinF64/ExpF64 2-wide; Log2/10 scale on Log |
| **UNIT_TESTS** | assembler contracts; Cos/Log/F64 near-parity suites still green |
| **EVIDENCE** | focused **1762**/0; neon-optin **1762**/0; math exit 0 |
| **FOLLOW-ON** | C6 landing |

### C6 — landing prep  【planned, controller】

---

## NEON BatchF32 代表集 【closed 2026-07-20】

**STATUS:** closed — do **not** auto-expand transcendental / full table without a new explicit Batch.

### Owned (23 leaves, ASM opt-in register)

| Group | Slots |
|-------|--------|
| Arith/cmp/unary | Add, Sub, Mul, Div, Min, Max, Abs, Neg |
| Scalar broadcast | MulScalar, AddScalar |
| Mix | Clamp, Lerp, Fma, Axpy |
| Root/recip | Sqrt, Rcp, Rsqrt, RcpRefine, RsqrtRefine |
| Reduce | ReduceSum, ReduceDot, ReduceMin, ReduceMax |

### Intentionally scalar (boundary)

- Transcendentals: Sin/Cos/Exp/Log/Pow/Tan/…
- Rounding: Ceil/Floor/Round/Trunc/Fract
- Utility: Mod/Sign/Step/Smoothstep/ReLU/…
- All **BatchF64** / **BatchInteger**

### Verification (B9 closeout)

- focused **1750**/0；neon-optin **1750**/0；math exit 0；API surface 71/0

---

## BATCH B9 — NEON ArrayRsqrtRefine + 代表集收口  【closed 2026-07-20】

| Field | Content |
|-------|---------|
| **STATUS** | closed |
| **WHY** | Finish reciprocal family; close NEON BatchF32 representative set (23 leaves) |
| **CARDS** | B9.1–B9.3 (same session) |
| **OUT_OF_SCOPE** | Transcendentals; BatchF64; Wave 4 |
| **EVIDENCE** | 2026-07-20: focused **1750**/0; neon-optin **1750**/0; math exit 0; 代表集 docs + Exp/Ceil still-scalar contracts |

### B9.1 contracts + Test_BatchF32_ArrayRsqrtRefine_Parity 【done】
### B9.2 NEONArrayRsqrtRefineF32 【done】
### B9.3 math + docs + 代表集 closed → IDLE 【done】

---

## BATCH B8 — NEON BatchF32 ArrayRsqrt / ArrayRcpRefine  【closed 2026-07-20】

| Field | Content |
|-------|---------|
| **STATUS** | closed |
| **WHY** | Exact rsqrt + refine rcp companions |
| **CARDS** | B8.1–B8.3 (same session) |
| **OUT_OF_SCOPE** | RsqrtRefine; F64; Wave 4 |
| **EVIDENCE** | 2026-07-20: focused **1749**/0; neon-optin **1749**/0; math exit 0 + API surface 71/0 |

### B8.1 contracts + Test_BatchF32_ArrayRsqrtRcpRefine_Parity 【done】
### B8.2 NEONArrayRsqrtF32 / NEONArrayRcpRefineF32 【done】 (no frsqrte approx)
### B8.3 math + docs → IDLE 【done】

---

## BATCH B7 — NEON BatchF32 ArrayRcp / ReduceDot  【closed 2026-07-20】

| Field | Content |
|-------|---------|
| **STATUS** | closed |
| **WHY** | User-selected next leaves: exact Rcp + ReduceDot |
| **CARDS** | B7.1–B7.3 (same session) |
| **OUT_OF_SCOPE** | Rsqrt/Refine; F64; Wave 4 |
| **EVIDENCE** | 2026-07-20: focused **1748**/0; neon-optin **1748**/0; math exit 0 + API surface 71/0 |

### B7.1 contracts + Test_BatchF32_ArrayRcpReduceDot_Parity 【done】
### B7.2 NEONArrayRcpF32 / NEONReduceDotF32 【done】 (Rcp=fdiv 1/x; Dot near-parity)
### B7.3 math + docs → IDLE 【done】

---

## BATCH B6 — NEON BatchF32 ReduceMin / ReduceMax  【closed 2026-07-19】

| Field | Content |
|-------|---------|
| **STATUS** | closed |
| **WHY** | Complete reduce trio after ReduceSum; high-frequency extrema |
| **CARDS** | B6.1–B6.3 (same session) |
| **OUT_OF_SCOPE** | ReduceDot; Rcp; F64; Wave 4 |
| **EVIDENCE** | 2026-07-19: focused **1747**/0; neon-optin **1747**/0; math exit 0 + API surface 71/0 |

### B6.1 contracts + Test_BatchF32_ReduceMinMax_Parity 【done】
### B6.2 NEONReduceMinF32 / NEONReduceMaxF32 【done】
### B6.3 math + docs → IDLE 【done】

---

## BATCH B5 — NEON BatchF32 ArraySqrt / ReduceSum  【closed 2026-07-19】

| Field | Content |
|-------|---------|
| **STATUS** | closed |
| **WHY** | Next high-frequency leaves after B4 fused ops |
| **CARDS** | B5.1 → B5.2 → B5.3 (same session) |
| **OUT_OF_SCOPE** | ReduceDot/Min/Max; Rcp; F64; Wave 4 |
| **EVIDENCE** | 2026-07-19: focused **1746**/0; neon-optin **1746**/0; math exit 0 + API surface 71/0 |

### B5.1 — contracts + `Test_BatchF32_ArraySqrtReduceSum_Parity` 【done】
### B5.2 — Implement NEONArraySqrtF32 / NEONReduceSumF32 【done】 (ReduceSum near-parity for assoc)
### B5.3 — math + docs → IDLE 【done】

---

## BATCH B4 — NEON BatchF32 ArrayFma / ArrayAxpy  【closed 2026-07-19】

| Field | Content |
|-------|---------|
| **STATUS** | closed |
| **WHY** | S23c-style fused leaves; high-frequency Fma/Axpy |
| **CARDS** | B4.1 → B4.2 → B4.3 (same session) |
| **OUT_OF_SCOPE** | Reduce/Sqrt; F64; Wave 4 |
| **EVIDENCE** | 2026-07-19: focused **1745**/0; neon-optin **1745**/0; math exit 0 + API surface 71/0 |

### B4.1 — contracts + `Test_BatchF32_ArrayFmaAxpy_Parity` 【done】
### B4.2 — Implement NEONArrayFmaF32 / NEONArrayAxpyF32 【done】 (mul+add, not hardware fmla)
### B4.3 — math smoke + docs → IDLE 【done】

---

## BATCH B3 — NEON BatchF32 ArrayLerp / ArrayClamp  【closed 2026-07-19】

| Field | Content |
|-------|---------|
| **STATUS** | closed |
| **WHY** | math public `BatchLerpF32` / `BatchClampF32` hot paths |
| **CARDS** | B3.1 → B3.2 → B3.3 (same session) |
| **OUT_OF_SCOPE** | Fma/Axpy; F64; Wave 4 |
| **BATCH_GATES** | focused; neon-optin; math clean test; hygiene |
| **EVIDENCE** | 2026-07-19: focused **1744**/0; neon-optin **1744**/0; math exit 0 + API surface 71/0 |

### B3.1 — contracts + `Test_BatchF32_ArrayLerpClamp_Parity`

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | B3.2 |
| **UNIT_TESTS** | FacadeFastSlots Lerp/Clamp; PlatformFacadeSlots honesty; `Test_BatchF32_ArrayLerpClamp_Parity` |
| **EVIDENCE** | length matrix + t=0/1/0.5 + count=0 |

### B3.2 — Implement NEONArrayLerpF32 / NEONArrayClampF32

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | B3.3 |
| **EVIDENCE** | asm fmin/fmax clamp; lerp = start+t*(end-start); ASM-only register |

### B3.3 — math smoke + docs

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | IDLE |
| **EVIDENCE** | math clean test exit 0; docs BatchF32 NEON 12 leaves |

---

## BATCH B2 — NEON BatchF32 AddScalar / MulScalar  【closed 2026-07-19】

| Field | Content |
|-------|---------|
| **STATUS** | closed |
| **WHY** | Power math `BatchScaleOffset*` and scalar-broadcast hot paths; next high-frequency band after Div |
| **CARDS** | B2.1 → B2.2 → B2.3 (same session) |
| **OUT_OF_SCOPE** | Lerp/Clamp (later batch); Fma/Axpy; F64/Integer; Wave 4 |
| **BATCH_GATES** | focused; neon-optin-focused; math clean test; hygiene; diff-check |
| **BATCH_DoD** | Both leaves owned under ASM; unit tests green; docs 8→10 leaves |
| **EVIDENCE** | 2026-07-19: focused **1743**/0; neon-optin **1743**/0; math exit 0 + API surface 71/0; hygiene pass |

### B2.1 — RED contracts + Mul/AddScalar parity unit tests

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | B2.2 |
| **UNIT_TESTS** | FacadeFastSlots MulScalar/AddScalar asm+scalar+register+runtime; PlatformFacadeSlots honesty (Lerp/Clamp still scalar); `Test_BatchF32_ArrayMulAddScalar_Parity` |
| **EVIDENCE** | Unit test + contracts land with impl; parity counts 0/1/4/7/16/65 + NaN + count=0 |

### B2.2 — Implement NEONArrayMulScalarF32 / NEONArrayAddScalarF32

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | B2.3 |
| **IN_SCOPE_PATHS** | neon.pas; neon.facade.asm/scalar.inc; neon.register.inc |
| **EVIDENCE** | asm fmul/fadd + scalar broadcast; register under ASM only |

### B2.3 — math smoke + docs closeout

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | IDLE |
| **EVIDENCE** | math clean test exit 0; docs BatchF32 NEON 10 leaves |

---

## BATCH B1 — NEON BatchF32 ArrayDiv  【closed 2026-07-19】

| Field | Content |
|-------|---------|
| **STATUS** | closed |
| **WHY** | S23b deferred Div; division semantics need strict unit tests before leaf ownership |
| **CARDS** | B1.1 → B1.2 → B1.3 (same session: tests+impl+smoke) |
| **OUT_OF_SCOPE** | BatchF64/Integer; Fma/Axpy; full BatchF32 table; math public ABI renames; Wave 4 |
| **BATCH_GATES** | `make focused FOCUS=core/tests/nextpas.core.simd`; `make -C core/tests/nextpas.core.simd neon-optin-focused`; `make -C core/tests/nextpas.core.math clean test`; `make hygiene`; `git diff --check` |
| **BATCH_DoD** | All three cards done with EVIDENCE; Div in NEON BatchF32 ownership set (ASM opt-in); docs honest |
| **EVIDENCE** | 2026-07-19: focused **1742**/0 (+1 special Div unit test); neon-optin **1742**/0; math clean test exit 0 + API surface 71/0; hygiene pass |

### B1.1 — RED unit tests + contracts for NEON ArrayDivF32

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | B1.2 |
| **UNIT_TESTS** | `Test_NEON_FacadeFastSlots_*` (Div asm/scalar/register/runtime); PlatformFacadeSlots no longer forbids Div; `Test_BatchF32_ArrayDiv_SpecialParity_Matches_Scalar`; `TestArrayDivF32_SpecialParity` in array_f32_correctness |
| **EVIDENCE** | Intermediate RED: focused failed with missing `NEONArrayDivF32` contract snippets before B1.2; special test first failed `EInvalidOp` then fixed with FPU mask |

### B1.2 — Implement NEONArrayDivF32 leaf

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | B1.3 |
| **DELIVERABLES** | `NEONArrayDivF32` in `neon.facade.asm.inc` (fdiv) + scalar companion + register under ASM |
| **EVIDENCE** | focused **1742** passed after impl; neon-optin green |

### B1.3 — math consumer smoke + docs closeout

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | IDLE |
| **EVIDENCE** | `make -C core/tests/nextpas.core.math clean test` exit 0; `MATH_API_SURFACE OK: scanned=71 findings=0`; docs leaf count → 8 (incl Div) |

---

## math↔simd linkage (Q2)

Authoritative **edit-where** map for this shared lane. Prevents wrong-module goals.

### Ownership

| Concern | Owner | Touch paths | Do not |
|---------|-------|-------------|--------|
| Scalar types, value-type methods, constants | **math** | `core/src/nextpas.core.math.{base,scalar,trig,vec,mat,quat,transform,easing,random}*` | Put public math types in simd |
| Public batch API (F32/F64 open-array + vec.batch) | **math** | `math.batch*`, `math.vec.batch*`, facade re-export, `docs/math/API.md` | Expose `Array*` names as math public API |
| Internal single-value SIMD helpers | **math** (private) | `math.impl.simd` only | Public facade; value-type default path without profile |
| Array* F32/F64 batch + transcendentals | **simd** | `nextpas.core.simd` public + `BatchF32`/`BatchF64` dispatch leaves | Reimplement Array* inside math |
| VecF32x* / CoreVectors / Memory / Mask | **simd** | simd public facade + backends | math imports private backend/dispatch units |
| NEON / RVV / x86 asm leaves & honesty | **simd** | simd backends, contracts, roadmap | math-side ISA `#ifdef` or dead wrappers |

### Allowed dependency edges

```text
consumer ──uses──► nextpas.core.math          (public math)
consumer ──uses──► nextpas.core.simd          (public simd; optional)

math.batch ────────► math.batch.simd ──uses──► nextpas.core.simd   (Array*F32/F64)
math.vec.batch ────► math.vec.batch.simd ─uses─► nextpas.core.simd (VecF32x*)
math.impl.simd ────uses──► nextpas.core.simd   (VecF32x*; not public)

simd ──//──► math   (FORBIDDEN: no reverse dependency)
math ──//──► nextpas.core.simd.{dispatch,backend*,cpuinfo,dataplane,*}  (FORBIDDEN: public facade only)
```

### Public surface mapping (math → simd)

| Math public | Math impl unit | simd symbol family | Notes |
|-------------|----------------|--------------------|-------|
| `Batch*F32` / `Batch*F64` (sin/cos/exp/…/lerp/clamp/scale-offset) | `math.batch` → `math.batch.simd` | `Array*F32` / `Array*F64` | Thin open-array facade; counts/bounds owned by math |
| `BatchDot/Normalize/Transform/Lerp/Clamp` (F32 + Double minimal) | `math.vec.batch` → `math.vec.batch.simd` | `VecF32x*` (F32 path); Double primarily scalar/math loops | Double set is M-V1 minimal parity, not full Array*F64 |
| Value-type `TVec*` / `TMat*` methods | `math.vec` / `math.mat` / … | **none by default** | Stay scalar; SIMD only via batch or `impl.simd` under design review |

### Edit decision (future goals)

| You want to… | Edit module | Typical gate |
|--------------|-------------|--------------|
| New/change public math batch signature or docs | **math** | `core-math-api-surface-smoke`, math focused |
| Faster ArraySin/Add/… leaf or NEON Batch slot | **simd** | simd focused / neon-optin / contracts |
| After simd Batch leaf change that math calls | **math smoke only** | M-C1 style: `make -C core/tests/nextpas.core.math clean test` |
| Wire value-type method → SIMD | **STOP** | Needs profile + design review (lane non-goal) |
| Import simd private unit from math | **STOP** | Source-contract / non-goal violation |

### Cross-README pointers

- math: [`../math/README.md`](../math/README.md) Layer And Ownership
- simd: [`../simd/README.md`](../simd/README.md) math consumer note

---

## Wave 0 — Goal OS

### G0 — Queue + pointers  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (this file + plan/GOAL_TREE/roadmap pointers) |
| **NEXT** | S23a |
| **WHY** | Explicit queue so execution does not depend on chat “继续” |
| **DELIVERABLES** | `GOAL_QUEUE.md`; `core/docs/simd/plan.md` points here; `core/docs/math/GOAL_TREE.md` residual + pointer; roadmap “默认下一刀” → CURRENT |
| **GATES** | `git diff --check`; docs-only hygiene if needed |
| **DoD** | CURRENT points at first code card; agent contract above is present |

---

## Wave 1 — simd kernel (main)

### S23a — NEON BatchF32 ArrayAdd/Sub/Mul  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | S23b |
| **WHY** | Close the largest NEON “all Batch inherits scalar” gap with high-ROI leaves |
| **IN_SCOPE_PATHS** | `core/src/nextpas.core.simd.neon.pas`; `core/src/nextpas.core.simd.neon.register.inc`; `core/src/nextpas.core.simd.neon.facade.asm.inc` and/or new `neon.batch*.inc`; `core/src/nextpas.core.simd.neon.facade.scalar.inc` / scalar batch fallback include; `core/tests/nextpas.core.simd/nextpas.core.simd.dispatchapi.testcase.pas`; `core/docs/simd/{roadmap,plan,README}.md`; this file |
| **OUT_OF_SCOPE** | BatchF64 / BatchInteger leaves; full BatchF32 table; RVV; math production code; public ABI renames; raw-merge main; dead `NEONX := ScalarX` registered wrappers |
| **DELIVERABLES** | Symbols `NEONArrayAddF32` / `NEONArraySubF32` / `NEONArrayMulF32`: AArch64 asm (`assembler; nostackframe`, ICE-safe loads) under `NEXTPAS_SIMD_NEON_ASM_ENABLED`; scalar fallbacks when asm off; register bind **only** under ASM_ENABLED; contracts: PlatformFacadeSlots no longer forbids all BatchF32 overrides—assert remaining Batch* still scalar; FacadeFastSlots (or equivalent) requires asm/register/runtime expectations for the three; docs: BatchF32 ownership progress |
| **GATES** | `make focused FOCUS=core/tests/nextpas.core.simd`; `make -C core/tests/nextpas.core.simd neon-optin-focused`; `make hygiene`; `git diff --check` |
| **DoD** | Gates green; three slots source+runtime contract; CURRENT→S23b; one feat commit |
| **STOP** | Need public ABI break; want whole Batch table; must touch math; ICE/compiler blocks asm and no safe fallback path |

**Symbol list (fixed):**

1. `NEONArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt)`
2. `NEONArraySubF32(...)`
3. `NEONArrayMulF32(...)`

**Pattern:** same ownership as Phase 22 Memory — real asm leaf + non-asm scalar symbol + register only when ASM enabled. Names match `static.inc` (`NEONArray*F32`).

### S23b — NEON BatchF32 Min/Max/Abs/Neg (+ optional Div)  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (Min/Max/Abs/Neg; Div deferred) |
| **NEXT** | M-C1 |
| **WHY** | Second high-frequency BatchF32 band without filling F64/Integer |
| **IN_SCOPE_PATHS** | Same neon/batch/test/docs set as S23a |
| **OUT_OF_SCOPE** | BatchF64/Integer full tables; transcendence ArraySin/Exp; math API |
| **DELIVERABLES** | At least `NEONArrayMinF32` / `Max` / `Abs` / `Neg`; optional `Div`; register+contracts+docs |
| **GATES** | Same as S23a |
| **DoD** | Gates green; CURRENT→M-C1; commit |
| **STOP** | Scope creep into full table |

### S23c — Optional BatchF32 Fma/Axpy or reduce sample  【optional】

| Field | Content |
|-------|---------|
| **STATUS** | pending (skip if S23b already enough for lane goals) |
| **NEXT** | M-C1 (if not done) or S24a |
| **WHY** | Only if profile/consumer pressure; not required for “lane complete” |
| **OUT_OF_SCOPE** | Whole table |
| **DELIVERABLES** | 1–3 extra leaves max |
| **GATES** | Same focused set |
| **DoD** | Or mark skipped in CURRENT notes |

### S24a — RVV Memory/Batch honesty  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (2026-07-17) |
| **NEXT** | S25a |
| **WHY** | No silent “native” claims without leaves |
| **IN_SCOPE_PATHS** | RVV register/docs/tests source-contracts; roadmap |
| **OUT_OF_SCOPE** | Fake RVV wrappers; claiming Phase-3 hardware without evidence |
| **DELIVERABLES** | Document+contract: Memory/Batch intentionally scalar unless real leaf |
| **GATES** | focused (or RVV opt-in smoke if exists); hygiene; diff-check |
| **DoD** | Honesty matrix green; CURRENT advanced |
| **BLOCKED_UNTIL** | — (software-only) |
| **EVIDENCE** | `Test_RISCVV_MemoryBatch_Intentionally_Scalar_Until_RealLeaf` locks no `table.Memory.` / `table.Batch*` register overrides, no `Mem*_RISCVV` / `RISCVVArray*` dead wrappers, runtime Memory 15 + Batch representative slots == scalar; register.inc honesty comment; roadmap matrix updated |

### S24b — RVV real leaves  【blocked】

| Field | Content |
|-------|---------|
| **STATUS** | blocked |
| **BLOCKED_UNTIL** | RISC-V hardware or approved QEMU evidence path |
| **NEXT** | S25a |
| **WHY** | Optional 1–N Memory/Batch leaves with real evidence |

### S25a — Benchmark methodology + remeasure hotspots  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (2026-07-17) |
| **NEXT** | S25b |
| **WHY** | High-performance requires reproducible SIMD vs true-scalar |
| **IN_SCOPE_PATHS** | `core/benchmarks/nextpas.core.simd/**`; simd docs § performance; related test benches |
| **OUT_OF_SCOPE** | Changing public API to chase scores |
| **DELIVERABLES** | Method note (anti FPC auto-vectorization); remeasure ArrayMulF32 etc.; record host/flags |
| **GATES** | Documented command runs; hygiene |
| **DoD** | Numbers in roadmap/README with method; CURRENT→S25b |
| **EVIDENCE** | `bench_hotspots` + `performance-methodology.md`; vsTrue AddF32 4.51x / AddF64 6.36x / MulF32 4.12x / MemEqual 43.98x @ AVX2 Xeon E5-2696 v4 |

### S25b — Optimize or revise targets  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (2026-07-17) — **re-baseline**, no leaf opt |
| **NEXT** | M-V1 |
| **WHY** | Close or honestly re-baseline underperforming targets under **vsTrue** primary metric |
| **IN_SCOPE_PATHS** | Hot leaf impls + docs；可引用 `performance-methodology.md` |
| **OUT_OF_SCOPE** | Silent target deletion without reason；把 vsLib 当主指标 |
| **DELIVERABLES** | Revised vsTrue SLA + rationale（Mul 4x 达标保留；AddF32 正式 4x+ / stretch 6x+） |
| **GATES** | focused + hygiene（无叶改动 → 不强制 bench_hotspots 重跑） |
| **DoD** | CURRENT→M-V1 |
| **EVIDENCE** | roadmap §5 SLA 表；performance-methodology §6；四热点 vsTrue 相对正式 SLA 全绿 |

---

## Wave 2 — math residual (secondary)

### M-C1 — math consumer smoke after NEON Batch  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (2026-07-17) |
| **NEXT** | S24a |
| **WHY** | math must keep working when simd Batch leaves appear (public-only) |
| **IN_SCOPE_PATHS** | `core/tests/nextpas.core.math/**` (run); math docs only if needed |
| **OUT_OF_SCOPE** | math production rewrites; private simd imports |
| **DELIVERABLES** | `make -C core/tests/nextpas.core.math clean test` green evidence; note in GOAL_TREE |
| **GATES** | math clean test; hygiene if any file touch |
| **DoD** | Evidence recorded; CURRENT advanced |
| **STOP** | Failures requiring private simd coupling |
| **EVIDENCE** | `make -C core/tests/nextpas.core.math clean test` → exit 0; `MATH_API_SURFACE OK: scanned=70 findings=0`; 16 Pascal suites / 305 tests, 0 failed; heaptrc 0 unfreed on all suites |

### M-V1 — vec.batch Double minimal parity  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (2026-07-17) |
| **NEXT** | M-V2 |
| **WHY** | Complete advanced public batch symmetry (F32-first gap) |
| **IN_SCOPE_PATHS** | `core/src/nextpas.core.math.vec.batch*`; root facade; tests `test_vec_batch*`; `core/docs/math/API.md` |
| **OUT_OF_SCOPE** | Value-type SIMD methods; M9; private simd |
| **DELIVERABLES** | Minimal Double set mirroring F32 vec.batch core ops |
| **GATES** | `make -C core/tests/nextpas.core.math clean test`; api-surface if API grows; hygiene |
| **DoD** | Tests+API.md; CURRENT→M-V2 |
| **EVIDENCE** | Double overloads: BatchDot(2d/3d/4d), Normalize(2d/3d/4d + 3d src-dst), Transform(Mat3d×2d, Mat4d×3d MultPoint), Lerp/Clamp TVec3d; value-type loops; facade re-export; test_vec_batch +6 Double cases |

### M-V2 — math residual docs + lane mode  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (2026-07-17) |
| **NEXT** | Q1 |
| **WHY** | Clean backlog: in-lane vs deferred vs out-of-lane |
| **IN_SCOPE_PATHS** | `core/docs/math/**` (+ pointer docs as needed) |
| **OUT_OF_SCOPE** | Code changes unless docs demand |
| **DELIVERABLES** | GOAL_TREE residual sections; macOS/M9 blocked; lane complete checklist |
| **GATES** | diff-check |
| **DoD** | CURRENT→Q1 |
| **EVIDENCE** | GOAL_TREE: residual closed; backlog classified; math lane-complete checklist; macOS/M9 blocked table |

### M9 — fafafa.game cutover  【blocked】

| Field | Content |
|-------|---------|
| **STATUS** | blocked |
| **BLOCKED_UNTIL** | Product authorization + cross-lane plan |
| **OUT_OF_SCOPE** | Entire math-simd default queue |

### macOS trig host proof  【blocked】

| Field | Content |
|-------|---------|
| **STATUS** | blocked |
| **BLOCKED_UNTIL** | macOS runner / CI host |

---

## Wave 3 — quality / elegance

### Q1 — Pointer freshness  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (2026-07-17) |
| **NEXT** | Q2 |
| **WHY** | CURRENT, README, roadmap §1 must not drift |
| **IN_SCOPE_PATHS** | simd/math docs |
| **DELIVERABLES** | Align phase headers, verification counts, CURRENT |
| **GATES** | diff-check |
| **DoD** | CURRENT→Q2 or IDLE |
| **EVIDENCE** | README/roadmap 验证 **1741**；math Remaining Gaps 去掉已完成 Double 伪缺口；指针统一 CURRENT=Q2 |

### Q2 — math↔simd linkage table  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (2026-07-17) |
| **NEXT** | IDLE |
| **WHY** | Prevent wrong-module edits in future goals |
| **DELIVERABLES** | Short table in this file or both READMEs |
| **GATES** | diff-check; hygiene |
| **DoD** | CURRENT→IDLE; table live above |
| **EVIDENCE** | §「math↔simd linkage (Q2)」in this file; short pointers in math/simd README |

### IDLE  【CURRENT】

When CURRENT=`IDLE`: lane has no in-lane code goal. Agent only re-verifies gates or stops.
Wave 4 walls (S26/S27/S24b/M9) stay blocked — never auto-start.
Debt inventory and latest baseline: [`MAINTENANCE.md`](MAINTENANCE.md).

**V0 re-verify (2026-07-19, ownership takeover):**

- `make -C core/tests/nextpas.core.math clean test` → exit 0；`MATH_API_SURFACE OK: scanned=71 findings=0`；Pascal heaptrc 0 unfreed
- `make focused FOCUS=core/tests/nextpas.core.simd` → **1741** passed / 0 failed
- `make hygiene` → pass；`git diff --check` clean on tracked tree

**M0 re-verify (2026-07-26, maintenance mode A):**

- FF to main `e9d92ab5b`；hygiene pass
- math clean test exit 0；API surface **71/0**；Pascal suites **313**/0；heaptrc 0 unfreed
- simd focused **1762**/0
- debt inventory written to `MAINTENANCE.md`

---

## Wave 4 — external walls (never auto-start)

| ID | Item | BLOCKED_UNTIL |
|----|------|----------------|
| S26 | Compiler built-in SIMD | compiler lane |
| S27 | LASX/WASM/VSX/MSA | FPC/toolchain + validation |
| S24b | RVV hardware leaves | hardware/QEMU policy |
| M9 | fafafa.game | product auth |

---

## Lane-complete definition (this worktree)

### simd lane-complete

- [x] Nested dispatch + honest ownership discipline
- [x] NEON Memory 15/15 + SharedMask
- [x] NEON BatchF32 high-frequency representative set (S23a/S23b; Div deferred)
- [x] RVV honesty (S24a)
- [x] Perf method + hotspot remeasure (S25a)
- [x] Hotspot close-or-revise (S25b re-baseline)
- [x] Docs CURRENT coherent (Q1)
- [x] math↔simd linkage table (Q2)

### math lane-complete

- [x] M0–M8 available-host gates
- [x] Public batch F32/F64 via public simd
- [x] vec.batch Double minimal parity (M-V1)
- [x] Residual backlog clean (M-V2)
- [x] Consumer smoke after Batch leaves (M-C1)
- [x] M9/macOS explicitly blocked (not silent)
- [x] math↔simd linkage table (Q2)

### Non-goals (always)

- Dead scalar wrappers registered as “native”
- math importing private simd backend units
- Value-type methods → SIMD without profile + design review
- raw-merge long-lived lane to main
- Claiming blocked hardware/compiler work done

---

## Default order (happy path)

```text
G0 ✅ → S23a ✅ → S23b ✅ → M-C1 ✅ → S24a ✅ → S25a ✅ → S25b ✅ → M-V1 ✅ → M-V2 ✅ → Q1 ✅ → Q2 ✅ → IDLE
         (S23c optional)                       (S24b only if hardware)
```

## Agent session prompt (paste)

```text
You are the math-simd lane executor on branch math-simd.
1. Open core/docs/math-simd/GOAL_QUEUE.md and execute only CURRENT.
2. Follow that card’s paths, gates, DoD, STOP.
3. Commit when DoD is met; advance CURRENT to NEXT.
4. Do not ask for 继续. One card per session unless CURRENT was G0 docs-only chaining into the same session by human request.
5. On STOP/BLOCKED: report Blocked with evidence and exit.
```
