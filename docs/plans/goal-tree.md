<!-- 项目总控地图 -->
<!-- 版本: v2.5 | 日期: 2026-07-13 -->
<!-- 每轮工作前查阅，结束后同步状态 -->
<!-- 编译器执行计划: docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md -->

# nextPas 目标树 v2.5

打造 FreePascal 领域最优秀的编译器+标准库生态系统。

**架构成熟度**: 当前可证明 [AL1 骨架期]；AL2 历史声明正在复核 → 目标 [AL3 成熟期]
**编译器执行计划**: `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md`（M0-M9）
**等级定义**: `docs/architecture/architecture-maturity-levels.md`

下方 2026-07-06 以前的勾选保留历史进度，不单独构成 production promotion evidence。
当前状态以 fresh gate 和编译器执行计划中的 promotion dashboard 为准。

---

## 阶段 0: AL0 混沌期 — 历史能力里程碑（live gate 复核中）

**目标**: 用 nextPas 编译器编译自身 + 全部 core/ 模块

| 节点 | 内容 | 状态 | 日期 |
|------|------|------|------|
| C0-C4 | 编译器基础架构 | ✅ | 2026-06-02 |
| C5 | 预处理器 `{$IFDEF}` 支持 | ✅ | 2026-07-03 |
| C6 | owned string return 改进 | ✅ | 2026-07-03 |
| C7 | compiler module/source probe | ✅ | 2026-07-03 |
| C8 | Sema 深化 (S1-S9) | ✅ | 2026-06-30 |
| C9 | HIR→MIR 降低优化 | ✅ | 2026-07-03 |
| L1-L5 | 语义/平台债务 | ✅ | 2026-07-06 |

**关键指标**:

| 指标 | 值 |
|------|-----|
| compiler-pass | 53/53 fresh invocation + 53/53 immediate repeat；cold/warm 全量门仍待显式 cache-root 隔离 |
| self-compile | 19/19 ✅ |
| core/ 覆盖率 | 963/972 (99.1%) |
| FPC RTL 清零 | 0 直接依赖 ✅ |

---

## 阶段 1: AL1→AL2 骨架期→收敛期 — 自举冲刺 + 架构升级 🏗️ 当前阶段

**目标**: 完成自举证据闭环 + 打造先进编译器架构
**执行计划**: `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md`
**退出条件**: M0-M5 promotion gates 全部通过并重新判定 AL2

### 当前编译器路径 (M0-M5)

| Milestone | 内容 | 状态 |
|-----------|------|------|
| M0 | compiler/System gate、rebuild 与状态真相恢复 | 🏗️ |
| M1 | compiler/System bootstrap contract 收敛 | 🏗️ |
| M2 | 最小可执行 A→B→C 两跳自举证明 | 🏗️ |
| M3 | session owner、stable IDs、immutable snapshots | 🔲 |
| M4 | typed query + dependency-aware incremental | 🔲 |
| M5 | deterministic parallel + data-oriented performance | 🔲 |

**当前证据** (2026-07-13):
- L6-A (Class helper) 不是自举阻塞点。
- Resolver 只把真实依赖加入 `UnitGraph`；旧 252-unit 全索引编译结论已废止。
- System identity、parent graph、source-backed cache 与 canonical projection 已进入当前 main 基线；
  System intrinsics、source contract 和 typed ledger focused gates fresh 通过。
- compiler-pass fresh command invocation 53/53，紧接的 immediate repeat 53/53；compiler-fail 16/16，
  `make rebuild-compiler` 返回 `rebuild-compiler=pass`。
- NPC V2 framing 与 path-safe entry identity 已落地；framing 14/14 和五阶段 fail-closed
  incremental gate 通过。compiler-pass harness 尚未隔离或清空 workspace `.nextpas` artifact
  roots，因此两次 53/53 都不能写成 cold/warm-cache 证明。
- M1 production typed families 已落地：object-free（root/destroy/cleanup/release）、
  process_init/fini、string ownership triad（init/fini/assign）、dynarray
  set_length/fini（`sckDynArray*`）、interface addref/release（`sckInterface*`）、
  halt（`sckHalt`）；均由 `TSystemContractKind` 控制 HIR validation 与 LLVM dispatch。
  `dynarray_init` 仍 vocabulary。下一 family 与其余 residual 仍待迁移。
- 尚无可执行 B/C 两代编译器证据，不能把 module probe 写成两跳自举完成。

**关键决策点**:
1. compiler 与 L0 System 作为同一 bootstrap spine 管理，但保持四层 owner 边界。
2. 先完成 M2 两跳可执行性，再推进 query/parallel/MIR 大迁移。
3. M2 的“能自举”和 M7 的“可复现生产自举”是两个独立 promotion gate。
4. 增量、并行和 MIR 只按 production integration、correctness、determinism、performance 证据晋级。
5. Public LSP/formatter adapter 后置，先建立 M8 shared language-service/formatter core。

**M0-M5 全部通过后，才重新判定 AL1→AL2 晋级。**

---

## 阶段 2: AL2 收敛期 — 标准库 + 编译器成熟

**目标**: 查询化编译稳定，增量+并行成熟，诊断达业界水平
**前置条件**: AL1 退出条件全部完成

下表只记录标准库合同覆盖历史，不代表 compiler AL2 promotion gate 已通过。

| 节点 | 内容 | 状态 | 备注 |
|------|------|------|------|
| L0 | 内核稳定 | ✅ | 11/11 模块契约完成 |
| L1 | 基础设施完善 | ✅ | 12/12 模块契约完成 |
| L2 | 系统能力扩展 | ✅ | 4/4 模块契约完成 |
| L3 | 框架层建设 | ✅ | 3/3 模块契约完成 |

**契约体系**: 57 模块全覆盖 ✅

---

## 阶段 3: AL3 成熟期 — 自举完成 + 生产可用

**目标**: stage2 自举完成 + 生产可用 5 门全通过
**前置条件**: AL2 退出条件全部完成
**生产可用定义**:
`docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md` M7 production self-host、
M8 internal tooling core 和本节生产可用 5 门；M9 leadership 属于 AL5

| 节点 | 内容 | 状态 | 备注 |
|------|------|------|------|
| S1 | production self-host（M7） | 🔲 | M2 两跳基础上完成可复现、等价报告与发行产物 |
| S2 | 标准库完整（975 模块 nextPas 编译） | 🔲 | 0 处 FPC 依赖 |
| S3 | 性能 ≥ FPC -O2 | 🔲 | 编译速度 + 生成代码 |
| S4 | 多目标后端（LLVM + 1 额外） | 🔲 | Cranelift 或 GCC |
| S5 | `nextpas test` 生产契约收敛 | 🏗️ | 从现有 thin wrapper 晋级到 workspace/package discovery、确定 list/filter 和 target evidence |
| S6 | shared language service 内部边界 | 🔲 | session/revision/overlay/invalidation/query；不承诺公开 LSP server |
| S7 | formatter core contract | 🔲 | source/trivia truth、edit result、确定性、幂等、语义保持和失败路径 |

### 生产可用 5 门

| 门 | 定义 | 状态 |
|----|------|------|
| Correctness | helper/overload/type-check/imported callable 等语义面收口 |   待评估 |
| Determinism | 全量/增量/重复构建产物一致性 |   待评估 |
| Tooling | 诊断、query、test、doctor、env、pkg 与 compiler truth 一致 |   待评估 |
| Performance | 冷编译/热编译基线稳定 |   待评估 |
| Operability | 调试信息、崩溃归因、最小发布与回退路径 |   待评估 |

---

## 阶段 4: AL4 生态期 — 现代开发者工具链 + IDE 生态

**目标**: 统一的 CLI、LSP、格式化、测试、包管理和 IDE 开发体验
**前置条件**: AL3 退出条件全部完成

| 节点 | 内容 | 状态 | 备注 |
|------|------|------|------|
| E1 | 公开 LSP server / protocol adapter | 🔲 | diagnostics/跳转/引用/补全/rename；只投影 shared language service truth |
| E2 | `fmt` 产品 workflow | 🔲 | `--check` + 原子 write mode；复用 AL3 formatter core contract |
| E3 | Package Manager | 🔲 | registry + 依赖解析 + lockfile |
| E4 | GUI Framework | 🔲 | 窗口/布局/控件/渲染 |
| E5 | IDE 可用 | 🔲 | 自有 IDE 或 LSP 客户端复用 language service、test harness 与 tooling truth |
| E6 | 文档完整 | 🔲 | API + 教程 + 语言参考 + tooling workflow |

Owner 和 promotion gate 以 `docs/architecture/master-roadmap.md` 第 6 段、
`docs/architecture/language-service-specification.md`、
`docs/architecture/developer-tooling-specification.md` 与
`docs/architecture/test-harness-specification.md` 为准；本目标树只追踪阶段和完成证据。

---

## 阶段 5: AL5 领先期 — 全面超越

**目标**: 性能领先，形式化验证，生态成熟
**前置条件**: AL4 退出条件全部完成

| 节点 | 内容 | 状态 | 备注 |
|------|------|------|------|
| X1 | 性能 > 2x FPC 编译速度 | 🔲 | 按 compiler excellence plan Leadership envelope 取证 |
| X2 | 多目标完整（Linux/Win/macOS/WASM, x86_64/ARM64/RISC-V） | 🔲 | |
| X3 | 形式化验证关键路径 | 🔲 | |
| X4 | 社区 1000+ 第三方包 | 🔲 | |

---

## 当前执行窗口 (2026-07-13)

1. [x] 通过 latest-main candidate 落地 System identity/parent/cache 三个已审查提交。
2. [x] 修复并版本化 NPC cache framing，建立 fail-closed incremental gate。
3. [ ] 给 compiler test/build 建立显式 cache-root owner/override，再跑真正隔离的 cold/warm
   full compiler-pass；当前证据只算 fresh invocation + immediate repeat。
4. [x] 恢复 compiler correctness baseline：compiler-pass 53/53 两次 invocation、compiler-fail 16/16。
5. [x] 恢复 canonical `make rebuild-compiler`。
6. [ ] 建立 fail-closed B0 benchmark 与 process-tree resource evidence。
7. [x] M1 typed production families closed（2026-07-23）。
   - [x] object-free production family（root/destroy/cleanup/release）
   - [x] process_init/fini typed HIR family（`SystemContractKind` 权威；ledger 仍 scelHir）
   - [x] string ownership triad typed HIR（init/fini/assign → `np_tstring_*`；ledger scelHir）
   - [x] dynarray set_length/fini typed HIR（→ `np_dynarray_*`；init 仍 vocabulary；ledger scelExecutable）
   - [x] interface addref/release typed HIR（→ `np_intf_*`；ledger scelHir call-shape）
   - [x] halt typed HIR（`sckHalt` → backend syscall lowering；ledger scelHir）
   - [x] heap_alloc/free typed HIR（GetMem/FreeMem + field arr byte-size → `sckHeapAlloc`/`sckHeapFree` → `@np_alloc`/`@np_free`；ledger scelHir）
   - [x] exception boundary typed HIR（try_push/pop/raise/finally_end/except_end → `@np_try_*` 等；ledger scelHir；begin markers 仍 bare）
   - [x] object_alloc typed HIR（class-new → `sckObjectAlloc` → `@np_object_alloc`；ledger scelHir；arr_alloc 归并进 heap_alloc）
   - [x] managed_record_fini typed HIR（cleanup → `sckManagedRecordFini` 权威 marker + 嵌套 string/dynarray；init 仍 vocabulary；ledger scelHir）
   - Residual **non-blocking / intentionally deferred**（不挡 M1 关账）：
     `dynarray_init` / `managed_record_init` = vocabulary；
     `unit_init` / `unit_fini` = semantic；
     `object_free` root/release + `runtime_fault` = backend evidence boundary；
     runtime-closure / 全表 `scelExecutable` = M1 之后。
8. [ ] M2 A→B→C 两跳证明（进行中）
   - [x] M2-0 harness：`docs/plans/m2/*` + `scripts/m2-two-hop.sh` + `make m2-two-hop`（a-ready + LLVM hello 基线；禁 host FPC 伪装）
   - [ ] M2-1 LLVM 闭包阶梯 L1→L2
   - [ ] M2-2 A→B 可执行（ladder L3 / source-manifest entry）
   - [ ] M2-3 B→C + acceptance 子集 + 等价报告

---

## 进度追踪

| 日期 | 事件 | 备注 |
|------|------|------|
| 2026-07-03 | C7 compiler module/source probe | self-compile 19/19, core/ 99.1% |
| 2026-07-04 | 契约体系全部完成 | 57 模块全覆盖 |
| 2026-07-05 | 架构诊断 | TSemanticAnalyzer God Class (279方法/1class) |
| 2026-07-05 | 编译器审计 v1 | compiler-audit.md 合并 findings + critique，36 条量化发现 |
| 2026-07-05 | 架构计划 v2.2 | compiler-architecture-plan.md，15 周 5 阶段 + 规范对齐 + 风险矩阵 + 源码对标 |
| 2026-07-05 | 架构成熟度等级 | architecture-maturity-levels.md AL0-AL5 定义完成 |
| 2026-07-05 | 目标树 v2.1 | 5 阶段 + AL 等级标注 + AL3-AL5 长期目标 |
| 2026-07-11 | 目标树 v2.3 | 增加 LSP server、formatter 与 test 的分阶段里程碑和 promotion mapping |
| 2026-07-12 | Compiler excellence roadmap | 采用 Rust 式内部严谨性 + Go 式构建反馈，重新按 production evidence 计分 |
| 2026-07-13 | M0 truth revalidation | NPC gates、53/53 immediate repeat、16/16 fail、rebuild 与 tooling fresh 通过；cache-root isolation 保持 open |
| 2026-07-13 | M1 typed contract slice | object-free root/destroy/cleanup/release 成为首个 typed HIR-to-LLVM production family |
| 2026-07-23 | M1 process + string families | process_init/fini 与 string init/fini/assign 进入 typed HIR（scelHir call-shape） |
| 2026-07-23 | M1 dynarray + interface families | dynarray set_length/fini（scelExecutable）与 interface addref/release（scelHir）进入 typed HIR |
| 2026-07-23 | M1 halt + heap families | halt（scelHir syscall）与 GetMem/FreeMem heap_alloc/free（scelHir → np_alloc/np_free）进入 typed HIR |
| 2026-07-23 | M1 exception boundary family | try_push/pop/raise/finally_end/except_end 进入 typed HIR（scelHir；setjmp call-shape） |
| 2026-07-23 | M1 object_alloc + arr 归并 | class-new → sckObjectAlloc→np_object_alloc；field arr_alloc → sckHeapAlloc（scelHir） |
| 2026-07-23 | M1 managed_record_fini | cleanup → sckManagedRecordFini marker + nested string/dynarray（scelHir） |
| 2026-07-23 | M1 typed production families closed | vocabulary/semantic/backend residual 标 non-blocking；下一主线 M2 |
| 2026-07-23 | M2-0 harness | source-manifest + ladder + `m2-two-hop.sh` + `make m2-two-hop`；A→B 未关闭 |

---

## 治理文档索引

| 文档 | 用途 |
|------|------|
| `docs/plans/goal-tree.md` (本文件) | 项目总控地图 |
| `docs/architecture/architecture-maturity-levels.md` | 架构成熟度等级 AL0-AL5 |
| `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md` | 当前 compiler correctness、self-host、query、MIR 与性能主路线 |
| `docs/plans/compiler-architecture-plan.md` | v2.2 历史规划与测量快照 |
| `docs/plans/compiler-audit.md` | 编译器 36 条量化审计发现 |
| `docs/plans/debt-roadmap.md` | 2026-07-06 编译器债务历史快照 |
| `docs/plans/selfhost-roadmap.md` | v3.0 自举执行顺序历史快照 |
| `PLAN.md` | 根总控计划 |

*最后更新: 2026-07-13 | 版本: v2.5*
