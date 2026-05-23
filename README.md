# nextPas

nextPas 是一个与 FreePascal 兼容的现代化重构项目，长期目标是一整套下一代 Pascal
开发环境，而不只是一个 compiler binary。第一阶段先冻结文档、范围和验证基线，
再逐步把 compiler kernel、toolchain control plane、`stage0` 驱动入口与运行时边界接起来。

这份 README 只负责仓库级导航，不负责改写稳定架构边界或活动计划状态。如果出现口径冲突，
以 `docs/adr/`、`docs/architecture/` 和 `docs/plans/` 为准。

## 先从这里读

1. `docs/adr/0001-fpc-reference-baseline.md`
2. `docs/architecture/documentation-baseline-specification.md`
3. `docs/architecture/README.md`
4. `docs/plans/README.md`

如果你要恢复当前上下文，这四个入口已经足够把“基线决策、稳定规范、活动计划和历史记录”
分开看清。

## 当前主线状态

- 稳定架构专题已经补齐，覆盖总览、兼容矩阵、自举路线图、`compiler`、toolchain、
  workspace、workspace file format、package workflow、developer tooling、language service、
  架构原则与质量门槛、future GUI framework、PlatformShell、UI runtime、UI interaction、
  UI layout、UI style/theme、UI motion、UI text layout、UI accessibility、UI rendering、
  future IDE、`rtl`、`crt`、`packages`、`stage0`、目标平台、测试 `harness` 和发行布局。
- phase1 已完成；当前主线进入 post-phase1 的批次推进阶段。
- `docs/architecture/master-roadmap.md` 现已接管长期产品路线图入口。
- `docs/architecture/compiler-roadmap.md` 现已接管编译器执行主线入口。
- `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 现已接管当前活动主线入口。
- `packages` 已经有独立的专题规范、推进计划与调研记录，但它们不改写 phase1 主计划。

## 第一阶段硬护栏

- Platform: Linux x86_64 only
- Bootstrap: FreePascal is `stage0`
- Language scope: No new syntax
- Compatibility scope: `ABI compatibility is deferred`

这些护栏来自 ADR 和架构文档，不应该在 README 里被重新解释成另一套规则。

## 文档入口

- 基线决策：`docs/adr/0001-fpc-reference-baseline.md`
- 文档分层规则：`docs/architecture/documentation-baseline-specification.md`
- 架构目录：`docs/architecture/README.md`
- 架构总览与 Mermaid 总图：`docs/architecture/overview.md`
- 架构原则与质量门槛：`docs/architecture/architecture-principles-specification.md`
- 产品主路线图：`docs/architecture/master-roadmap.md`
- 编译器路线图：`docs/architecture/compiler-roadmap.md`
- 自举路线图：`docs/architecture/bootstrap-roadmap.md`
- PlatformShell 专题：`docs/architecture/platform-shell-specification.md`
- UI runtime 专题：`docs/architecture/ui-runtime-specification.md`
- Render asset pipeline 专题：`docs/architecture/render-asset-pipeline-specification.md`
- 活动计划目录：`docs/plans/README.md`
- 当前主计划：`docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`
- phase1 主计划：`docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`
- phase1 实施计划：`docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`
- 迭代推进模式：`docs/plans/2026-03-24-nextpas-iteration-mode-plan.md`
- packages 计划：`docs/plans/2026-03-21-nextpas-phase1-packages-plan.md`
- packages 调研：`docs/plans/support/2026-03-21-nextpas-phase1-packages-research.md`

## 仓库当前重点

第一阶段当前不是去发明新的 Pascal 方言，也不是马上承诺完整包生态、多平台首发、
ABI 对等，或一次性落完 package manager、formatter、IDE、LSP。当前重点是先把
nextPas 作为“开发环境”的仓库边界、toolchain 控制面、验证路径和 `stage0` 基线建立清楚，
之后再进入实现批次。
