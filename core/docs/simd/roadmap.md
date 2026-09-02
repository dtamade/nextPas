# nextpas.core.simd 开发路线图

> 最后更新: 2026-08-31
> 权威性: **本文件是 forward-looking 主线**。历史 Phase 1–19 / Wave B 的细节见下方「已完成归档」；活动设计见 `design/`；过期实施草稿见 `plans/` 与旧 plan 文件（仅存档）。
> 维护态债务与最新 re-verify：[`../math-simd/MAINTENANCE.md`](../math-simd/MAINTENANCE.md)。

## 0. 文档权威图

| 文档 | 角色 | 更新节奏 |
|------|------|----------|
| **[roadmap.md](roadmap.md)**（本文件） | 分阶段目标、优先级、验收、下一步主线 | 每 wave/phase 收口更新 |
| [README.md](README.md) | 模块入口、现状摘要、文档索引 | 与真相面同步 |
| [architecture.md](architecture.md) / [dispatch.md](dispatch.md) / [backends.md](backends.md) | 稳定架构事实 | 边界变化时更新 |
| [api.md](api.md) | 公开 API 参考 | 公共 API 变化时更新 |
| [design/](design/) | 活动/已完成设计说明 | 大设计收口时更新 |
| [plan.md](plan.md) | **当前活动阶段**任务清单（薄；细节指向本文件） | 开工/收口更新 |
| [methodology.md](methodology.md) | 协作与验证纪律 | 很少改 |
| `plans/`、`PHASE11_*`、`SIMD_*_PLAN.md`、`file-merge-plan.md` | **历史/专项存档**，不再当主线 | 不主动扩写 |

**纪律**：后续开发以本路线图主线推进；重大范围变更先修订本节「活动路线」再动刀。

---

## 1. 现状盘点 (2026-08-31 maintenance re-verify；Phase 20–25 + Wave C 已收口)

### 1.1 定位

`nextpas.core.simd` 是跨平台 SIMD 运行时：嵌套 dispatch 表 + backend register + 标量 baseline + 公共 facade。
**唯一实现层**在 `nextpas.core.*`；x86 最深，NEON/RVV 为覆盖扩展面。

### 1.2 架构真相（已稳定）

```
Facade (flat public API)
  → Dispatch (nested: CoreVectors / Batch* / Memory / Mask)
    → Backend register (SSE2…AVX512 / NEON / RVV / Scalar)
      → leaves (asm or Pascal)
```

- Phase 19：dispatch **路径级**模块化完成（嵌套组 + residual 契约）
- Wave B：NEON Mask → portable `SharedMask*` + `scMaskedOps`；Memory 缺口契约锁定
- Public ABI 字段名保持 **flat**（不随内部嵌套改名）

### 1.3 后端覆盖矩阵（槽所有权，非“能不能跑”）

| 后端 | CoreVectors | Memory | Mask | BatchF32/F64/Integer | 能力位要点 |
|------|-------------|--------|------|----------------------|------------|
| Scalar | 全 baseline | 全 | 全 | 全 | 参考实现 |
| SSE2/AVX2 链 | 深 | 深 | SharedMask + 本地 PopCount | 深 | MaskedOps 常开 |
| AVX512 | 宽向量深 | 部分/继承 | 部分 SharedMask | 宽批 | FMA/Shuffle 等按可用性 |
| **NEON** | 大量（~332 绑定；无 asm 时 scalar 继承） | **15/15**（22a+22b 全 Memory 真叶） | **20/20 SharedMask** | **BatchF32 代表集 23 + Wave C**（F64 代数 + 超越 sample/asm）；其余 Integer 等仍 scalar | `scMaskedOps` 常开；Integer/FMA/Shuffle 跟 vector-asm |
| **RVV** | 大量（~412） | **0/15 故意 scalar**（S24a） | **20/20 本地** | **0 故意 scalar**（S24a） | MaskedOps 跟 vector-asm；实验性；真叶等 S24b |
| LASX/WASM/VSX/MSA | — | — | — | — | 🔒 FPC/编译器阻塞 |

**NEON Memory**：Phase 22 已关闭全部 15 槽（asm 叶 + register，仅 `NEXTPAS_SIMD_NEON_ASM_ENABLED` 下接管；非 asm 编译保留 scalar fallback 符号）。

**NEON Batch 进度**：**代表集 closed（B1–B9，23 叶）** + **Wave C closed**（C1–C4e F64 代数；C5–C5e-ext F32/F64 超越 sample 与 4-wide/2-wide asm）。**故意 scalar 边界**：BatchInteger 全表、未选中的超越/舍入叶（契约锁定，非整表抄写）。

**RVV Memory/Batch 诚实矩阵（S24a）**：

| 组 | 槽所有权 | 证据 |
|----|----------|------|
| Memory（15） | 全继承 `FillBaseDispatchTable` scalar | register 无 `table.Memory.*`；无 `Mem*_RISCVV` 死包装；DispatchAPI 运行时指针 == scalar |
| BatchF32 / F64 / Integer | 全继承 scalar | register 无 `table.Batch*`；无 `RISCVVArray*` 死包装；代表槽运行时 == scalar |
| CoreVectors / Mask | 既有 RVV 绑定（asm 条件 / 本地 Mask） | 不在 S24a 范围内改动 |
| 真机 Phase 3 / S24b 真叶 | ⏸ blocked | 需 RISC-V 硬件或批准的 QEMU 证据路径 |

### 1.4 验证真相

| Gate | 状态 | 说明 |
|------|------|------|
| `make focused FOCUS=core/tests/nextpas.core.simd` | ✅ | **1762** passed（2026-08-31 M0 re-verify；C5e-ext 后基线） |
| `make -C core/tests/nextpas.core.simd neon-optin-focused` | ✅ | 历史 C5e-ext **1762**；本 maintenance 未在 x86 重跑 |
| `make -C core/tests/nextpas.core.math clean test` | ✅ | exit 0；API surface **71/0**；Pascal **313**/0 |
| `make hygiene` | ✅ | pass |
| `api-coverage-contract` | ✅ | missing=0 / thin=0（Phase 21 收口，strict-thin 未降） |
| RVV 真机 Phase 3 | ⏸ | 需 RISC-V 硬件证据 |
| 性能部分目标 | ✅ | S25b：vsTrue SLA 四热点全绿（AddF32 正式目标 4x+，stretch 6x+；见 §5） |

### 1.5 文档问题（Phase 20 已处理）

1. ~~路线图几乎全是已完成清单~~ → 已改为 Phase 20+ 可执行主线
2. ~~`plan.md` 与代码脱节~~ → 薄指针，仅跟踪当前阶段
3. ~~多份旧 plan 与主线重复~~ → 标注 archived
4. ~~README 验证数字过时~~ → 与本表同步
5. ~~methodology 引用 `progress.md`~~ → 已去掉

---

## 2. 战略目标（长期）

1. **正确性优先**：标量 baseline 语义为金标准；backend override 必须有 parity/source-contract
2. **所有权诚实**：无 dead wrapper、无假 NEON*/RVV* 绑定；缺口靠 baseline 继承并契约锁定
3. **x86 深、非 x86 可测**：NEON/RVV 在 opt-in 与契约层可回归；真机证据单独 wave
4. **质量门可红可修**：不靠文档撒谎；红点进入路线图并闭环
5. **不 raw-merge 长期 lane**：math-simd worktree 纪律不变

---

## 3. 活动路线（Phase 20+）

> 下列阶段是 **可执行主线**。重大范围变更先改本表再动刀。

### Phase 20 — 文档与真相面收口  【P0 · 已完成】

| 项 | 内容 |
|----|------|
| **目标** | 单一权威路线图；入口/计划/索引与代码一致；历史文档降级为存档 |
| **交付物** | 本文件结构；README 索引与验证数字；`plan.md` 改为「当前阶段指针」；methodology 去掉失效引用；旧 plan 文件标注 archived |
| **依赖** | 无代码依赖 |
| **验收** | 新人只读 README + roadmap 能回答：现状 / 下一步 / 跑什么 gate；无互相矛盾的「进行中」表 |
| **状态** | ✅ `b68facf33` 文档提交 |

### Phase 21 — 质量门修复（api-coverage）  【P0 · 已完成】

| 项 | 内容 |
|----|------|
| **目标** | `api-coverage-contract` 变绿（不降低 strict） |
| **交付物** | 补齐 27 个 missing 公共 API 测试引用；26 个 thin 符号达到 `min_refs=2` |
| **做法** | 扩展 `test_api_coverage_batch_math.pas`（F32 扩展 facade + F64/F32 第二样本）与 `test_api_coverage_wide_vectors.pas`（I16x32/I8x64/U8x64 CmpLe/Ge/Ne） |
| **依赖** | Phase 20 完成 |
| **验收** | `api-coverage-contract` → missing=0 thin=0；api-coverage 测试可运行全绿 |
| **非目标** | 不为刷绿删除公共 API；不降低 strict 标准 |
| **状态** | ✅ 源码 token 扫描 + 运行时断言双过 |

### Phase 22 — NEON Memory 真叶  【P1 · 已完成】

| 项 | 内容 |
|----|------|
| **目标** | 关闭 Memory 缺口中 **有真实 NEON 收益** 的槽；禁止标量 forwarder |
| **22a（✅）** | `Copy` / `Fill` / `DiffRange`：AArch64 asm + register（`NEXTPAS_SIMD_NEON_ASM_ENABLED`）+ scalar fallback 仅用于非 asm 编译单元；契约从 KeepBaseScalar 翻到 FacadeFastSlots |
| **22b（✅）** | `Reverse`（rev64+ext / rev）/ `BytesIndexOf`（首字节 NEON + 全匹配校验）/ `Utf8Validate`（ASCII NEON 快路径 + scalar-parity 多字节） |
| **依赖** | Phase 21 已完成；NEON asm 仍受 FPC trunk / AArch64 opt-in 约束 |
| **验收** | focused + neon-optin + hygiene 绿；Memory 15/15 源契约 asm/register；x86 runtime 仍 scalar（无 asm）；PlatformFacadeSlots 锁定 Batch* 继承 |
| **非目标** | 不为覆盖率写永久 `NEONMemX := ScalarMemX` 死包装注册 |

### Phase 23 — NEON Batch* 最小可用面  【P1 · 已完成（代表集）】

| 项 | 内容 |
|----|------|
| **目标** | 在 ARM 上提供与 x86 对齐的 **高频** Batch 路径（非整表抄写） |
| **23a（✅）** | `BatchF32` `ArrayAdd` / `ArraySub` / `ArrayMul`：AArch64 asm 叶 + register（仅 `NEXTPAS_SIMD_NEON_ASM_ENABLED`）+ 非 asm scalar companion；契约 FacadeFastSlots 运行时绑定期望 |
| **23b（✅）** | `Min` / `Max` / `Abs` / `Neg` |
| **B1 Div（✅）** | `ArrayDivF32`：asm + scalar companion + register（ASM opt-in）+ special parity unit test |
| **B2 Mul/AddScalar（✅）** | `ArrayMulScalarF32` / `ArrayAddScalarF32`：asm + companion + register + parity unit test |
| **B3 Clamp/Lerp（✅）** | `ArrayClampF32` / `ArrayLerpF32`：asm + companion + register + parity unit test |
| **B4 Fma/Axpy（✅）** | `ArrayFmaF32` / `ArrayAxpyF32`：mul+add（非硬件 FMA）+ companion + register + parity unit test |
| **B5 Sqrt/ReduceSum（✅）** | `ArraySqrtF32` / `ReduceSumF32`：fsqrt；Reduce 允许浮点结合差（near 测） |
| **B6 ReduceMin/Max（✅）** | `ReduceMinF32` / `ReduceMaxF32`：fmin/fmax 归约；count=0→0 |
| **B7 Rcp/ReduceDot（✅）** | `ArrayRcpF32`（exact fdiv 1/x）/ `ReduceDotF32`（near 容差） |
| **B8 Rsqrt/RcpRefine（✅）** | `ArrayRsqrtF32`（fsqrt+fdiv）/ `ArrayRcpRefineF32`（exact 1/x） |
| **B9 RsqrtRefine + 代表集收口（✅）** | `ArrayRsqrtRefineF32`；**23 叶代表集 closed**（超越/舍入/F64/Integer 故意 scalar） |
| **交付物** | `BatchF32` 代表 **23** 叶 + 边界表 + 契约锁定 Exp/Ceil 等仍 scalar |
| **依赖** | Phase 22 Memory 叶已稳定 |
| **验收** | neon-optin 契约 + 语义 smoke；代表集边界有 source-contract |
| **非目标** | 自动填满 transcendence/全表；Wave 4 |
| **状态** | ✅ **NEON BatchF32 代表集 closed**（GOAL_QUEUE） |

### Phase 24 — RVV 覆盖诚实化  【P2 · 24a 已完成】

| 项 | 内容 |
|----|------|
| **目标** | RVV Memory/Batch 要么真实现，要么文档+契约明确「故意 scalar」；Phase 3 真机证据单独 gate |
| **24a（✅）** | 诚实矩阵 + `Test_RISCVV_MemoryBatch_Intentionally_Scalar_Until_RealLeaf` 源/运行时契约；roadmap/README/register 注释对齐；**不**造假 RVV Memory/Batch 叶 |
| **24b** | （可选，blocked）1–N 个 Memory 或 Batch 真叶；需硬件/QEMU |
| **24c** | 真机证据包（硬件可用时） |
| **依赖** | 真机证据依赖硬件；软件契约不依赖 |
| **验收** | focused 绿；契约禁止 `table.Memory.` / `table.Batch*` 假绑定；文档不谎报 native |
| **非目标** | 无硬件时假装 G16 完成 |

### Phase 25 — 性能与分派开销  【P2 · ✅】

| 项 | 内容 |
|----|------|
| **目标** | 可复现的 SIMD vs 真标量基准；关闭明显未达标热点 |
| **25a（✅）** | 方法文档 + `bench_hotspots` 复测；主指标 **vsTrue**；主机/flags 入 [performance-methodology.md](performance-methodology.md) |
| **25b（✅）** | 诚实 re-baseline：SLA 全改 **vsTrue**；Mul/Mem/AddF64 保留目标并标注达标；AddF32 正式目标 **4x+**（stretch 6x+，不强制本卡微优化） |
| **交付物** | 基准方法说明；目标修订（理由入 §5 / performance-methodology）；G17 Phase 4 分派开销测量记录（可后置） |
| **依赖** | Phase 21 建议先完成（避免测到未覆盖 API） |
| **验收** | 文档中有可复现命令 + 主机/flags/数字；目标变更须写明原因 |

### Phase 26 — 编译器集成（长期）  【P3 · 阻塞】

| 项 | 内容 |
|----|------|
| **目标** | nextpas 编译器内建 SIMD 类型/运算符/自动向量化 |
| **交付物** | 跨 lane（compiler + simd）；不在本 worktree 单独闭环 |
| **依赖** | nextpas 编译器 SIMD 内建能力 |
| **验收** | 编译器侧测试 + 与 runtime facade 共存策略文档 |

### Phase 27+ — 新 ISA 后端  【🔒 阻塞】

LASX / WASM SIMD128 / VSX / MSA：保持 stub；启用条件 = nextpas/FPC 后端可用 + QEMU/真机验证流程。

---

## 4. 推荐执行顺序

```
P20 文档真相面 ──► P21 api-coverage 绿
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
   P22 NEON Memory 真叶    P25 性能/分派（可后置）
          │
          ▼
   P23 NEON Batch 最小面
          │
          ▼
   P24 RVV 诚实化 / 真机
          │
          ▼
   P26 编译器（阻塞） / P27 新 ISA（阻塞）
```

**默认下一刀 / Goal CURRENT**：见 [`../math-simd/GOAL_QUEUE.md`](../math-simd/GOAL_QUEUE.md)（现为 **IDLE** — 在途卡已空）。
不要用聊天「继续」驱动；`IDLE` 时仅 re-verify 或等新卡/Wave 4 解阻。
维护债务清单：[`../math-simd/MAINTENANCE.md`](../math-simd/MAINTENANCE.md)。

---

## 5. 性能参考线（S25a 测 / S25b SLA，2026-08-31）

**方法权威**：[performance-methodology.md](performance-methodology.md)
**复现**：`make -C core/benchmarks/nextpas.core.simd/bench_hotspots clean run`
**主机摘要**：Xeon E5-2696 v4 · FPC 3.3.1 · `-O3` · **AVX2** · VectorAsm=True
**主指标**：`vsTrue`（TrueScalar + volatile sink）。`vsLib` 仅历史对照。

### 5.1 正式 SLA（S25b 修订后）

| 操作 | 历史目标 | **正式 SLA (vsTrue)** | stretch（可选） | 测得 vsTrue | 测得 vsLib | SLA |
|------|----------|----------------------|-----------------|-------------|------------|-----|
| ArrayAddF32 @1024 | 6x+ | **4x+** | 6x+ | **4.51x** | 2.98x | **绿** |
| ArrayAddF64 @1024 | 6x+ | **6x+** | — | **6.36x** | 4.24x | **绿** |
| ArrayMulF32 @16KB | 4x+ | **4x+** | — | **4.12x** | 2.58x | **绿**（旧 ~2.5x=vsLib 污染） |
| MemEqual @4KB | 4x+ | **4x+** | — | **43.98x** | 4.33x | **绿** |
| 超越函数批处理 | 高倍率 | 保留 suite 回归 | — | 未在 hotspots 复测 | 多数超额 | 回归 |

### 5.2 AddF32 目标修订理由（非静默降标）

1. **方法纠偏在先**：S25a 证明历史 “未达标” 数字大量混用 vsLib；Mul 在 vsTrue 下已 ≥4x，无需为 chase 分数改叶。
2. **参考主机带宽现实**：E5-2696 v4 + AVX2 上 1024×f32 三流（2 读 1 写）实测 ~4.5x；把 **6x 定为硬 SLA** 会把平台/缓存噪声写成产品失败。
3. **6x 降为 stretch**：未来若做更大展开、多核/缓存友好布局或换更新主机，可冲击 6x；**不阻塞** Phase 25 收口，也不要求本卡微优化。
4. **AddF64 保持 6x+**：同主机已 6.36x，保留原硬目标。

规则：

- **主指标 = vsTrue**；禁止单独用 vsLib 写“SIMD 相对标量加速比”。
- FPC 3.3.1 无可靠 `NOVECTORIZE`；细节见 performance-methodology。
- 改 Batch/Memory 热叶后须重跑 `bench_hotspots` 并更新本表与 methodology。

---

## 6. 通用验收清单（每个 phase 收口）

1. worktree clean（仅任务文件）
2. `git diff --check` 通过
3. `make hygiene` 通过
4. 本模块 focused gate：`make focused FOCUS=core/tests/nextpas.core.simd`
5. 触及 NEON 契约时：`neon-optin-focused`
6. 触及公共 API 时：`api-coverage-contract`（Phase 21 后应为硬门）
7. 文档：roadmap 状态行 + README 数字 + 相关 design/契约同步
8. 提交：一个逻辑单元；message 说明「改了什么 / 为什么」
9. 汇报：Ready / Blocked / Needs Review（跨模块时）

---

## 7. 已完成归档（压缩；细节不重复展开）

### 目标类（G）

G1–G15、G18–G21 已完成或达标；G16 RVV 软件 Phase 1–2 完成、Phase 3 待硬件；G17 软件 Phase 1–3 完成、Phase 4 待测量。

### 阶段类（Phase）

| 范围 | 摘要 |
|------|------|
| Phase 1–6 | 静态路径、IEEE、文件合并、平台扩展、Highway、类型覆盖 |
| Phase 7–10 | 批量优化、基准框架、宽向量、内存工具 |
| Phase 11–12 | 矩阵分解/信号高级 + 性能与静态调度深化 |
| Phase 13–18 | F64 批量/超越函数与 SSE2/AVX2 SIMD 叶 |
| Phase 19 | Dispatch 嵌套模块化 P1–P6（路径对齐；槽差距刻意） |
| Wave B | SharedMask 可移植 + NEON Mask 绑定 + Memory 缺口契约 |

### 平台支持（摘要）

- **稳定**: x86 SSE2…AVX512、FMA3、AES/SHA/MMX；NEON（opt-in）
- **实验**: RVV；SVE/SVE2 intrinsics
- **阻塞**: LASX / WASM / VSX / MSA

---

## 8. 风险与决策点（需人确认时再改路线）

| 决策 | 选项 | 默认建议 |
|------|------|----------|
| api-coverage 红点 | 补测 vs 降 strict | **补测**（P21 ✅ 已采用） |
| NEON Memory 6 槽 | 全做 vs 先 3 高频 | **先 Copy/Fill/DiffRange**（P22a） |
| NEON Batch 范围 | 全表 vs 最小代表集 | **最小代表集**（P23） |
| RVV 无硬件 | 只契约 vs 停更 | **只契约诚实化**（P24a） |
| 性能未达标 | 优化 vs 改目标 | **S25b 已 re-baseline**：vsTrue SLA 四热点全绿；AddF32 正式 4x+ / stretch 6x+ |

---

## 9. 当前指针

- **Goal 队列**: [`../math-simd/GOAL_QUEUE.md`](../math-simd/GOAL_QUEUE.md)（**CURRENT=IDLE**）
- **活动阶段**: Goal CURRENT=IDLE（Q1/Q2 质量波已收；无在途代码目标）
- **已收口**: Phase 20–23b；Phase 25；G0；M-C1；S24a；S25a；S25b；M-V1；M-V2；Q1；Q2
- **math↔simd linkage**: GOAL_QUEUE §「math↔simd linkage (Q2)」
- **禁止带入 main 的噪音**: 临时 task_plan / findings / 本地 `.codegraph` 等

---

*修订记录*
- 2026-08-31: 重写为 forward-looking 主线；归档 Phase 1–19 / Wave B；建立 Phase 20–27。
- 2026-08-31: Phase 20 提交；Phase 21 补 facade 覆盖测试并变绿；指针切到 Phase 22。
- 2026-08-31: Phase 22a NEON MemCopy/MemSet/MemDiffRange asm 叶与契约翻转。
- 2026-08-31: Phase 22b Memory 15/15；G0 `GOAL_QUEUE.md`；默认下一刀 S23a。
- 2026-08-31: Phase 23a NEON BatchF32 ArrayAdd/Sub/Mul 真叶；CURRENT→S23b。
- 2026-08-31: Phase 23b NEON BatchF32 Min/Max/Abs/Neg 真叶（Div 推迟）；CURRENT→M-C1。
- 2026-08-31: M-C1 math consumer smoke 全绿（305 tests / API surface 70/0）；CURRENT→S24a。
- 2026-08-31: S24a RVV Memory/Batch 故意 scalar 诚实矩阵 + DispatchAPI 契约；CURRENT→S25a。
- 2026-08-31: S25a performance-methodology + bench_hotspots；vsTrue 数字入 §5；CURRENT→S25b。
- 2026-08-31: S25b 诚实 re-baseline（AddF32 SLA 4x+ / stretch 6x+；四热点 SLA 全绿）；CURRENT→M-V1。
- 2026-08-31: M-V1 vec.batch Double 最小对称（Dot/Normalize/Transform/Lerp/Clamp）；CURRENT→M-V2。
- 2026-08-31: M-V2 math residual docs + lane-complete 分类；CURRENT→Q1。
- 2026-08-31: Q1 指针新鲜度（验证数 1741、去掉假 Double 缺口）；CURRENT→Q2。
- 2026-08-31: Q2 math↔simd linkage 表；CURRENT→IDLE。
- 2026-08-31: V0/D0 接管复验（simd 1741 / math API surface 71/0）；Phase 23 标题改为已完成代表集。
- 2026-08-31: Batch B1 NEON `ArrayDivF32` 真叶 + special parity unit test；focused **1742**；CURRENT→IDLE。
- 2026-08-31: Batch B2 NEON `ArrayMulScalarF32`/`ArrayAddScalarF32`；focused **1743**；CURRENT→IDLE。
- 2026-08-31: Batch B3 NEON `ArrayClampF32`/`ArrayLerpF32`；focused **1744**；CURRENT→IDLE。
- 2026-08-31: Batch B4 NEON `ArrayFmaF32`/`ArrayAxpyF32`；focused **1745**；CURRENT→IDLE。
- 2026-08-31: Batch B5 NEON `ArraySqrtF32`/`ReduceSumF32`；focused **1746**；CURRENT→IDLE。
- 2026-08-31: Batch B6 NEON `ReduceMinF32`/`ReduceMaxF32`；focused **1747**；CURRENT→IDLE。
- 2026-08-31: Batch B7 NEON `ArrayRcpF32`/`ReduceDotF32`；focused **1748**；CURRENT→IDLE。
- 2026-08-31: Batch B8 NEON `ArrayRsqrtF32`/`ArrayRcpRefineF32`；focused **1749**；CURRENT→IDLE。
- 2026-08-31: Batch B9 `ArrayRsqrtRefineF32` + **NEON BatchF32 代表集 23 叶 closed**；focused **1750**；CURRENT→IDLE。
- 2026-08-31: Wave C0–C5e-ext（F64 代数 + 超越 sample/asm）；focused **1762**；CURRENT→IDLE。
- 2026-08-31: **M0 maintenance** — FF main + re-verify（simd **1762** / math API **71/0** / Pascal **313**/0）+ `MAINTENANCE.md` 债务清单；CURRENT 保持 IDLE。
