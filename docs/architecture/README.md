# 架构文档目录

`docs/architecture/` 用于存放 nextPas 第一阶段稳定、可引用、可被后续实现直接依赖的架构文档。

如果你要判断文档分层、裁决顺序和阅读入口，先读
`documentation-baseline-specification.md`。本 README 只负责架构目录本身的导航。

## 命名规则

本目录采用“标准文件类型 + 正式中文标题”的命名方式：

- `overview.md`：用于总览性文档，正文正式名称写作“架构总览”
- `compatibility-matrix.md`：用于兼容范围矩阵，正文正式名称写作“兼容性矩阵”
- `master-roadmap.md`：用于全局主路线图，正文正式名称写作“主路线图”
- `compiler-roadmap.md`：用于编译器主线文档，正文正式名称写作“编译器路线图”
- `bootstrap-roadmap.md`：用于阶段推进文档，正文正式名称写作“自举路线图”
- `*-specification.md`：用于规范类文档，表示该文档定义边界、职责、约束和非目标

这套规则的目标不是把文件名写得越长越好，而是在保持路径稳定和可扫描性的同时，
让正文标题承担正式中文命名的职责。

因此，本目录不再使用 `blueprint`、`contract` 一类容易歧义的旧命名。

## 当前文档

- `documentation-baseline-specification.md`：nextPas 文档基线规范
- `overview.md`：nextPas 架构总览与 Mermaid 总图
- `compatibility-matrix.md`：nextPas 兼容性矩阵
- `master-roadmap.md`：nextPas 主路线图
- `compiler-roadmap.md`：nextPas 编译器路线图
- `bootstrap-roadmap.md`：nextPas 自举路线图
- `fpc-source-grounding-specification.md`：nextPas FPC 源码映射规范
- `packages-specification.md`：nextPas packages 规范
- `compiler-specification.md`：nextPas 编译器规范
- `compiler-pipeline-specification.md`：nextPas 编译器流水线规范
- `lexer-specification.md`：nextPas Lexer 规范
- `semantic-model-specification.md`：nextPas 语义模型规范
- `diagnostics-specification.md`：nextPas 诊断规范
- `unit-resolution-specification.md`：nextPas unit 解析规范
- `language-service-specification.md`：nextPas language service 规范
- `runtime-bootstrap-specification.md`：nextPas 运行时自举规范
- `cross-compilation-specification.md`：nextPas 交叉编译规范
- `toolchain-specification.md`：nextPas 工具链规范
- `workspace-specification.md`：nextPas workspace 规范
- `workspace-file-format-specification.md`：nextPas workspace 文件格式规范
- `developer-tooling-specification.md`：nextPas 开发者工具链表面规范
- `package-workflow-specification.md`：nextPas package workflow 规范
- `gui-framework-specification.md`：nextPas GUI 框架规范
- `platform-shell-specification.md`：nextPas PlatformShell 规范
- `ui-runtime-specification.md`：nextPas UI runtime 规范
- `ui-interaction-specification.md`：nextPas UI interaction 规范
- `ui-layout-specification.md`：nextPas UI layout 规范
- `ui-style-theme-specification.md`：nextPas UI style/theme 规范
- `ui-motion-specification.md`：nextPas UI motion 规范
- `ui-text-layout-specification.md`：nextPas UI text layout 规范
- `ui-accessibility-specification.md`：nextPas UI accessibility 规范
- `ui-rendering-specification.md`：nextPas UI rendering 规范
- `render-asset-pipeline-specification.md`：nextPas render asset pipeline 规范
- `ide-specification.md`：nextPas IDE 规范
- `backend-specification.md`：nextPas 后端规范
- `llvm-backend-specification.md`：nextPas LLVM 后端规范
- `c-interop-specification.md`：nextPas C 互操作与链接规范
- `directory-structure-specification.md`：nextPas 目录结构规范
- `rtl-specification.md`：nextPas RTL 规范
- `crt-specification.md`：nextPas CRT 规范
- `distribution-layout-specification.md`：nextPas 发行布局规范
- `test-harness-specification.md`：nextPas 测试 `harness` 规范
- `stage0-driver-specification.md`：nextPas `stage0` 驱动规范
- `target-platform-specification.md`：nextPas 目标平台规范

## 三层路线图

- 产品路线图：`master-roadmap.md`
- 编译器路线图：`compiler-roadmap.md`
- 自举路线图：`bootstrap-roadmap.md`

这三份文档同时存在，但不回答同一个问题：

- `master-roadmap.md` 负责 nextPas 作为整套开发环境先长什么骨架
- `compiler-roadmap.md` 负责 compiler 主线应该按什么顺序接管
- `bootstrap-roadmap.md` 负责 `stage0`、`stage1`、`stage2` 的所有权晋级

## 阅读顺序

- 先读 `documentation-baseline-specification.md`，确认文档分层和裁决顺序
- 再读 `overview.md`，了解第一阶段的顶层边界
- 然后读 `compatibility-matrix.md`，确认兼容范围和硬护栏
- 再读 `master-roadmap.md`，确认 nextPas 作为整套开发环境的全局推进顺序
- 再读 `compiler-roadmap.md`，确认 compiler execution spine、边界冻结和 promotion gate
- 再读 `bootstrap-roadmap.md`，确认 `stage0`、`stage1`、`stage2` 的自举所有权路径
- 再读 `fpc-source-grounding-specification.md`，确认现代化设计到底在回应 FPC 真源码里的哪些耦合
- 接着读 `packages-specification.md`，确认 `packages/` 的分层边界与第一阶段承诺
- 再读 `compiler-specification.md`，确认编译器内部边界与阶段关系
- 然后读 `compiler-pipeline-specification.md`，确认内部数据流、所有权和性能约束
- 再读 `semantic-model-specification.md`，确认 `sema`、`Typed HIR` 和语义核心对象如何冻结
- 再读 `diagnostics-specification.md`，确认结构化诊断、快照稳定性和 toolchain failure 如何冻结
- 再读 `unit-resolution-specification.md`，确认 `UnitGraph`、search path 和 unit identity 如何冻结
- 再读 `runtime-bootstrap-specification.md`，确认 compiler 与 `rtl/core/system/` 的启动握手边界
- 再读 `target-platform-specification.md`，确认当前启用 target facts 的外置边界
- 再读 `cross-compilation-specification.md`，确认 host/target/toolchain/sysroot 如何正式分离
- 再读 `toolchain-specification.md`，确认 compiler kernel、build tools 和 developer-facing tools 如何共用同一套 toolchain control plane
- 再读 `workspace-specification.md`，确认 project roots、package refs、target selection 和 artifact roots 如何冻结成 shared workspace truth
- 再读 `workspace-file-format-specification.md`，确认 workspace descriptor、package manifest、lockfile 和 root discovery 怎样把 shared truth 稳定落盘
- 再读 `developer-tooling-specification.md`，确认 build/test/pkg/fmt/doc/env/doctor/query 这类工具怎样收敛到统一 command surface
- 再读 `package-workflow-specification.md`，确认 manifest、lock、install root、registry/source/mirror 和 `pkg` workflow 怎样建立在 shared core 之上
- 再读 `language-service-specification.md`，确认 shared analysis、open file overlays、semantic queries 和 diagnostics streaming 如何冻结
- 再读 `gui-framework-specification.md`，确认全新硬件加速 Pascal UI stack 应该怎样接到 runtime、packages、toolchain 和发行布局上
- 再读 `platform-shell-specification.md`，确认 window、screen/monitor、clipboard/DnD、cursor 和 native surface integration 如何冻结成统一宿主边界
- 再读 `ui-runtime-specification.md`，确认 frame pump、dispatch cycle、invalidation merge 和 async-to-UI handoff 如何冻结成统一 runtime control plane
- 再读 `ui-interaction-specification.md`，确认 input event、focus path、command intent 和 interaction router 怎样冻结成统一交互控制面
- 再读 `ui-layout-specification.md`，确认 layout node、constraint、snapshot 和 invalidation 怎样冻结成统一几何控制面
- 再读 `ui-style-theme-specification.md`，确认 semantic token、style resolver、theme snapshot 和 theme asset set 怎样冻结成统一 visual control plane
- 再读 `ui-motion-specification.md`，确认 motion clock、transition、motion snapshot 和 scheduler 怎样冻结成统一 temporal control plane
- 再读 `ui-text-layout-specification.md`，确认 text/layout、glyph run、caret/selection 与 IME/input session 怎样冻结成统一 text truth
- 再读 `ui-accessibility-specification.md`，确认 accessibility node、snapshot、action 和 platform bridge 怎样冻结成统一辅助技术控制面
- 再读 `ui-rendering-specification.md`，确认 `DrawPlan`、`RenderGraph`、`SurfaceFrame` 和 render-side contract 怎样把 GUI 的硬件加速主路径冻结下来
- 再读 `render-asset-pipeline-specification.md`，确认 shader、atlas、font metadata、theme/image preprocessing 和 `RenderAssetBundle` 怎样收敛到统一资产流水线
- 再读 `ide-specification.md`，确认自有 IDE 应该怎样建立在 compiler、GUI framework、workspace truth 和 test/toolchain 控制面之上
- 再读 `backend-specification.md`，确认 `MIR`、codegen adapter、assembler/linker 与产物路径如何冻结
- 再读 `llvm-backend-specification.md`，确认 LLVM backend 为什么只是 backend contract 的一个实现
- 再读 `c-interop-specification.md`，确认 C ABI、external symbol 与 target-aware linking 如何冻结
- 最后按需进入其余各份 `*-specification.md`，查看运行时、测试、目标与发行约束
