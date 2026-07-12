# nextPas 项目总控计划

> 最后更新：2026-07-12
> 当前可证明成熟度：AL1 骨架期；历史 AL2 声明正在按 production gate 复核
> 当前编译器执行计划：`docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md`
> 成熟度定义：`docs/architecture/architecture-maturity-levels.md`
> 目标树：`docs/plans/goal-tree.md`

## 北极星

打造 FreePascal 领域最优秀的编译器与标准库生态：内部严谨性对齐 Rust，构建反馈、
所有权和操作复杂度对齐 Go，同时保留 Pascal 的 unit、`System`、托管类型、ABI 和对象
模型语义。

## 当前事实

以下状态是 2026-07-12 可引用的起点，不得用更早的完成标记覆盖：

- `compiler-pass` 最近一次完整运行是 51/53；canonical System cache 修复后仍需 fresh
  cold/immediate-warm 复跑。
- `scripts/rebuild-compiler.sh` 没有有效 build body，当前不能作为 compiler rebuild 证据。
- C0-C7 和 22/22 stage2 记录证明 module/source-level probe，不证明可执行 B/C 两代编译器。
- nextPas compiler cache (NPC) 的 fingerprint framing 读写不一致，root 调用还传入空依赖；
  修复前不能宣称 production incremental compilation。
- query database、parallel scheduler 和 MIR 均已有骨架，但尚未成为 typed、deterministic、
  verified 的默认生产路径。
- System TypeId、type-parent graph 和 canonical source-backed cache 三个修复已在
  `codex/compiler-system` lane 提交，尚待 latest-main candidate 的 path-limited replay。

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

1. 通过 latest-main landing candidate 回放三个已审查的 System/compiler 修复。
2. 版本化 NPC cache framing，补 round-trip、wrong fingerprint、truncation、hostile count
   和 mandatory incremental gate。
3. 隔离 compiler test/build cache roots，复跑 cold/immediate-warm `compiler-pass`，修复
   `classes_pass` 和剩余 warm-only regression。
4. 恢复 canonical `make rebuild-compiler`，建立 fail-closed B0 benchmark 和完整进程树 RSS。
5. 完成 System 四层 contract ledger，再进入 FPC-only-A 的 M2 A→B→C 证明。

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
