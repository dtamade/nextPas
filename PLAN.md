# nextPas 项目总控计划

> 最后更新：2026-07-26
> 当前可证明成熟度：AL1 骨架期；历史 AL2 声明正在按 production gate 复核
> 当前编译器执行计划：`docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md`
> 成熟度定义：`docs/architecture/architecture-maturity-levels.md`
> 目标树：`docs/plans/goal-tree.md`

## 北极星

打造 FreePascal 领域最优秀的编译器与标准库生态：内部严谨性对齐 Rust，构建反馈、
所有权和操作复杂度对齐 Go，同时保留 Pascal 的 unit、`System`、托管类型、ABI 和对象
模型语义。

## 当前事实

以下状态是 2026-07-13 可引用的起点，不得用更早的完成标记覆盖：

- `compiler-pass` fresh command invocation 53/53，紧接的 immediate repeat 53/53；
  `compiler-fail` 16/16。harness 仍复用 workspace `.nextpas` artifact roots，因此这两次运行
  不能写成受控 cold/warm 证明。
- canonical `make rebuild-compiler` 已返回 `rebuild-compiler=pass`。
- C0-C7 和 22/22 stage2 记录证明 module/source-level probe，不证明可执行 B/C 两代编译器。
- NPC V2 framing 与 path-safe entry identity 已落地；framing 14/14 和五阶段 fail-closed
  incremental gate fresh 通过。root 调用仍传入空依赖，compiler test/build cache-root owner
  也未冻结，因此不能宣称 production incremental compilation。
- query database、parallel scheduler 和 MIR 均已有骨架，但尚未成为 typed、deterministic、
  verified 的默认生产路径。
- System TypeId、type-parent graph、canonical source-backed cache 和 projection 已进入当前 main
  基线。`TSystemContractKind` 控制 HIR validation 与 LLVM dispatch 的 production families
  已有：object-free、process init/fini、string ownership triad、dynarray set_length/fini、
  interface addref/release、halt；M1 其余 residual families 仍未迁移。
- M2 两跳自举已开跑：M2-0 harness + LLVM smoke、M2-1 ladder L0–L2 均绿；
  M2-2（L3 = full stage0 driver A→B link）卡在 `opt` residual undefined symbols
  （2026-07-26 实测 80 unique / 251 total；执行入口：`docs/plans/m2/ROADMAP.md`）。
  生产 codegen 路径 = Typed HIR → LLVM；
  MIR 冻结为 experimental，不作为 gen-B 正确性证据。

因此当前等级保持 AL1。任何 AL2、self-host、incremental、parallel、MIR 或性能晋级都必须
由 active roadmap 中的 fresh promotion gate 证明。

## 当前执行顺序

| Milestone | 目标 | 晋级结果 |
| --- | --- | --- |
| M0 | 恢复 compiler/System gate、NPC cache、rebuild 和基准真相 | 建立可信开发基线 |
| M1 | 冻结 compiler 与 L0 System 四层 bootstrap contract | 消除语义漂移 |
| M2 | 证明真实 A→B→C 两跳可执行性；FPC 只构建 A | 大迁移前的自举可行性 |
| M3 | 冻结 session/workspace owner、typed IDs 和 immutable snapshots | 建立 compiler kernel |
| M4 | 建立 typed query、依赖图和正确增量失效 | 查询化生产晋级 |
| M5 | 建立 dependency-ready、deterministic parallel build | AL2 重新判定 |
| M6 | 收敛为单一 verified MIR/codegen path | 自有 codegen 晋级 |
| M7 | 建立可复现、可发布、可回退的 production self-host | AL3 self-host gate |
| M8 | 建立 shared language service、formatter core 和 `nextpas test` truth | AL3 internal tooling core |
| M9 | 在正确性不回退前提下实现编译吞吐领先 | AL5 leadership gate |

公开 LSP server、`fmt` 产品 workflow 和 IDE protocol adapter 属于 AL4。它们必须复用 M8
内部 truth，不能创建第二套 parser、resolver、semantic model 或 workspace graph。

## 当前执行窗口

1. [x] 落地 System identity、parent graph、source-backed cache 和 canonical projection 修复。
2. [x] 版本化 NPC cache framing，补 round-trip、corruption 和 mandatory incremental gate。
3. [ ] 建立显式 compiler test/build cache-root owner/override，再跑受控 cold/warm full suite。
4. [x] 恢复 compiler correctness baseline：compiler-pass 53/53 两次 invocation、
   compiler-fail 16/16。
5. [x] 恢复 canonical `make rebuild-compiler`。
6. [ ] 建立 fail-closed B0 benchmark 和完整进程树 RSS。
7. [ ] 继续 System typed contract migration；object-free、process init/fini、string triad、
   dynarray、interface、halt families 已落地，其余 residual 待迁移，M1 未完成。
8. [~] M2 A→B→C 证明已开跑（与 M1 residual 迁移并行）：M2-0 harness + M2-1 ladder
   L0–L2 ✅；当前主战场是 M2-2（L3 A→B link）residual undefined symbols 清理，
   唯一执行入口 `docs/plans/m2/ROADMAP.md`（咬合队列 B0–B8，探针
   `scripts/m2-l3-residual.sh`）。M3+ 大迁移仍以 M2 闭合为前置。

## 权威文档

| 文档 | 权威范围 |
| --- | --- |
| `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md` | 当前 compiler correctness、self-host、query、MIR、tooling 与性能执行顺序 |
| `docs/architecture/architecture-maturity-levels.md` | AL0-AL5 晋级边界 |
| `docs/plans/goal-tree.md` | 项目阶段与完成证据索引 |
| `docs/architecture/compiler-pipeline-specification.md` | 稳定 compiler pipeline 与 owner boundary |
| `docs/architecture/runtime-bootstrap-specification.md` | compiler、System、RTL/CRT bootstrap 边界 |
| `docs/plans/compiler-audit.md` | 历史量化审计输入，不单独构成当前完成证明 |
| `docs/plans/compiler-architecture-plan.md` | v2.2 历史规划和测量快照 |
| `docs/plans/debt-roadmap.md` | 2026-07-06 债务历史快照 |
| `docs/plans/selfhost-roadmap.md` | v3.0 自举顺序历史快照 |

稳定事实以 `docs/architecture/` 和 `docs/adr/` 为准。active roadmap 只决定当前执行顺序和
promotion evidence，不得改写已接受的 owner boundary。

## Landing 纪律

- 普通开发只在 `.worktrees/compiler-system` / `codex/compiler-system` lane 进行。
- 长期 lane 不 raw merge 到 `main`；每个可审查 slice 都在 latest-main candidate 上做
  path-limited replay。
- landing 前必须证明 candidate 相对 `main` behind 0、路径范围正确、focused gate、
  `git diff --check` 和 `make hygiene` 全部通过。
- `task_plan.md`、`findings.md`、`progress.md` 和构建产物不得进入主线。
