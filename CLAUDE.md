# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

nextPas 是一个 Free Pascal 兼容的现代 Pascal 编译器和运行时库项目。采用分阶段开发策略：
- **stage0**: 使用 FPC trunk 自举，编译器源码在 `tools/stage0/nextpas.pas`
- **core**: `nextpas.core` 运行时框架，包含 100+ 模块，采用分层架构 (L0-L3)
- **rtl**: 运行时库，包含核心 System/SysUtils/Classes 等
- **compiler**: 编译器前端、语义分析、IR、后端

## 常用命令

### 构建与验证
```bash
make rebuild-compiler          # 重建 stage0 编译器
make verify                    # 完整本地验证 (编译器 + 测试)
make hygiene                   # 检查源码树中是否有构建产物
make clean                     # 清理所有构建产物
```

### 测试运行
```bash
make test                      # 默认 smoke 测试
make test TEST_FILTER=         # 全量测试
make test TEST_FILTER=compiler-pass  # 特定组测试
tests/run_all_tests.sh --list-groups  # 列出所有测试组
make -C core test              # core 模块所有测试
make -C core/tests/nextpas.core.system clean test  # system 模块测试
```

### 单模块测试
```bash
make -C core/tests/<module>/<test_project> clean test
# 例如：
make -C core/tests/nextpas.core.text/test_text_width clean test
```

### Git Worktree 操作
```bash
scripts/worktree-add.sh <branch> [base]  # 创建新 worktree
scripts/worktree-audit.sh                 # 审计现有 worktrees
```

## 核心架构

### 分层架构 (L0-L3)

```
L0: base, errors, platform, mem, log.intf     ← 只依赖 FPC RTL
L1: bytes, text, collections, sync, async...  ← 只依赖 L0
L2: fs, net, tls, crypto, json, yaml...       ← 只依赖 L0-L1
L3: http, websocket, tui, config, app...      ← 只依赖 L0-L2
```

**依赖规则**: 只向下依赖，禁止同层循环依赖。

### 模块结构范式

每个模块遵循四件套模式（按需存在，不机械创建）：

```
nextpas.core.<module>.pas          ← 门面：纯 re-export
nextpas.core.<module>.base.pas     ← 基本类型（record, enum, const）
nextpas.core.<module>.intf.pas     ← 接口定义（interface 声明）
nextpas.core.<module>.ffi.pas      ← FFI/ABI 声明（foreign binding）
nextpas.core.<module>.<impl>.pas   ← 实现子模块
```

依赖方向：`base ← intf ← 实现 ← 门面`

### 双编译器架构（核心设计原则）

`nextpas.core.system` 是编译器内核和运行时的**唯一内核模块**。所有与编译器相关的定义和内核实现都在 `system` 下面，通过 `fpc`/`nextpas` 子域名区分两个编译器的实现：

```
nextpas.core.system.pas              ← 门面：纯委托，不含 {$IFDEF}
nextpas.core.system.fpc.pas          ← FPC 适配器（uses FPC 单元：SysUtils/Classes/System 等）
nextpas.core.system.nextpas.pas      ← nextPas 适配器（用 nextpas.core.* 内核实现）
nextpas.core.system.fpc.*.pas        ← FPC 子模块（按功能拆分）
nextpas.core.system.nextpas.*.pas    ← nextPas 子模块（按功能拆分）
```

- **FPC 编译时**：门面委托给 `system.fpc.*`，路由到 FPC 的实现
- **nextPas 编译时**：门面委托给 `system.nextpas.*`，使用内核实现

**路由通过分离的适配器单元完成**，不在模块内部用 `{$IFDEF}`，不在编译器 resolver 层。

**命名规则**：编译器内核相关定义统一在 `nextpas.core.system` 下，用 `fpc`/`nextpas` 子域名区分。不在其他模块（如 `nextpas.core.exception`）下分叉。

**这意味着**：
- `uses SysUtils` 等 FPC 单元名只出现在 `system.fpc.*` 中，是**设计如此**
- 门面层和 `system.nextpas.*` 不依赖任何 FPC 单元
- `units/<target>/` 中的 FPC 兼容文件是**临时映射层**，为尚不具备适配器的模块提供过渡
- 最终目标：所有内核定义都有完整的适配器对（`system.fpc.*` + `system.nextpas.*`），不再需要 shim
- 所有运行时能力必须在 `nextpas.core.system` 内实现，禁止外部独立兼容层

**禁止**：在 `nextpas.core.system` 之外创建编译器内核兼容层；在门面层使用 `{$IFDEF}`。

## nextpas.core.system 模块专项

### 模块定位

`nextpas.core.system` 是 nextPas RTL root 的设计前哨，承接 FPC `System` 的最低运行时契约。

**核心职责**:
- 拥有运行时契约的稳定词汇表 (`np.system.*` 名称)
- 为其他 core 模块提供最小兼容性门面
- 保持所有者边界：不直接实现，只委派给 owner 模块

### 所有者边界

| 功能域 | Owner | System stance |
|--------|-------|---------------|
| 基础类型 (`TBytes`, `SizeInt` 等) | `nextpas.core.base` | re-export 别名 |
| 异常分类 | `nextpas.core.exception` | re-export 别名 |
| 错误分类 | `nextpas.core.errors` | re-export 别名 |
| 内存工具 (`ZeroMem`, `FreeAndNil`) | `nextpas.core.base.utils` | inline forwarding |
| 文本转换 (`Format`, `IntToStr`) | `nextpas.core.text.conv` | sysutils facade forwarding |
| TypInfo | FPC `TypInfo` + `System` | typinfo facade bridge |
| 平台 API | `nextpas.core.platform` | **禁止直接使用** |
| OS 单元 (`Windows`, `BaseUnix`) | — | **禁止直接使用** |

### 禁止事项

- ❌ 不要复制 FPC `System`/`SysUtils`/`Classes` 杂货箱
- ❌ 不要绕过 owner 边界调用 `Windows`, `BaseUnix`, `Unix`
- ❌ 不要在 `core/src/` 创建裸露的 `System.pas`（与 FPC magic unit 冲突）
- ❌ 不要暴露未测试的兼容性 API
- ❌ 不要创建 `nextpas.core.system.classes` 单元（已推迟）

### 运行时契约名称

稳定常量定义在文档中，编译器使用这些名称而非魔术字符串：

| 契约 | 含义 | 状态 |
|------|------|------|
| `np.system.process_init` | 进程启动 | compiler semantic live |
| `np.system.process_fini` | 进程关闭 | compiler semantic live |
| `np.system.object_free` | 对象释放 | compiler/HIR live |
| `np.system.unit_init` | 单元初始化 | 未来 feature |
| `np.system.unit_fini` | 单元终结化 | 未来 feature |

### 当前阶段 (S4-S5)

- **已完成**: S0-S3 (文档/门面/契约)
- **已完成**: S4 TypInfo 最小门面、SysUtils 最小门面
- **进行中**: S5 编译器/运行时集成准备
- **已推迟**: Classes 门面、更广泛的 SysUtils 门面

### 源文件位置

```
core/src/nextpas.core.system.pas          ← 根门面
core/src/nextpas.core.system.typinfo.pas  ← TypInfo 最小门面
core/src/nextpas.core.system.sysutils.pas ← SysUtils 最小门面
rtl/core/system/System.pas                ← TObject.Free 真实来源
```

### 文档位置

```
core/docs/system/README.md                ← 模块入口文档（必读）
core/docs/system/goal-tree.md             ← 分阶段目标树
core/docs/system/rtl-mapping.md           ← FPC 到 nextPas 映射
core/docs/system/runtime-contracts.md     ← S2 运行时契约
core/docs/system/lifecycle-contracts.md   ← S3 生命周期契约
core/docs/system/compatibility-facades.md ← S4 兼容门面设计
```

### 测试入口

```bash
make -C core/tests/nextpas.core.system clean test
```

测试套件：
- `test_system_facade`: 根门面测试
- `test_system_source_contracts`: 源契约边界检查（大型 shell 脚本）
- `test_system_typinfo_minimal`: TypInfo 最小门面测试
- `test_system_sysutils_minimal`: SysUtils 最小门面测试

## 测试分组

仓库级测试组（`tests/run_all_tests.sh --filter <group>`）：

| 组 | 约定 | 机制 |
|----|------|------|
| `compiler-pass` | `tests/compiler/pass/*_pass.pas` | stage0 build 成功并运行 |
| `compiler-fail` | `tests/compiler/fail/*_fail.pas` | stage0 build 失败，对比 snapshot |
| `diagnostics` | `tests/diagnostics/**/*.pas` | host fpc 失败，对比 snapshot |
| `rtl` | `tests/rtl/*_smoke.pas` | host fpc 编译运行 |
| `toolchain` | `tests/toolchain/*_smoke.pas` | host fpc 编译运行 |

Snapshot golden 文件在 `tests/snapshots/*.stderr.txt`。

## Worktree 纪律

**核心规则**: 所有模块开发必须在 `.worktrees/<module>` 下的专属 worktree 进行。

- `main` 只用于总控 landing、仓库治理
- 一个 worktree 只负责一个模块或一条治理线
- 跨模块改动需说明原因、范围、风险、额外验证
- 合并前必须：worktree clean、focused verification 通过、`git diff --check` 通过、`make hygiene` 通过
- 不要 raw merge 长期模块 lane 到 `main`

详细规则见 `docs/worktrees.md`。

## AI 协作入口点

- `AGENTS.md`: 仓库级 AI 规则（必读）
- `core/AGENTS.md`: core 模块专属入口（做 core 工作必读）
- `docs/architecture/`: 稳定架构事实
- `docs/adr/`: 架构决策记录
- `docs/plans/`: 活动计划
- `core/docs/design-conventions.md`: nextpas.core 设计规范

## 报告状态

标准状态：
- `Ready`: 包含分支、worktree、HEAD、改动文件、验证证据、merge 建议
- `Blocked`: 说明阻塞条件、已尝试动作、需谁决策
- `Landed`: 说明进入 main 的提交、验证结果、worktree 清理
- `Needs Review`: 跨模块影响面大，需总控审查

不要把临时 `task_plan.md`、`findings.md`、`progress.md` 带入主线。

## 构建产物卫生

禁止产物散落到源码目录：
- `.o`, `.ppu`, `.a`, `.exe`, `.dll`, `.so`, `.dylib`
- `link*.res`, `*.test.res`, `ppas.sh`

临时产物应落在 `build/`、`.nextpas/` 等 ignored 目录。

`scripts/build-hygiene-check.sh` 会拦截违规产物。

## 编码风格

遵循 Pascal 通行风格：
- 单元名：`nextpas.core.<module>` (dotted namespace, 全小写)
- 类型前缀：`T` class/record, `I` interface, `E` exception
- 变量前缀：`L` local, `A` parameter, `F` field
- 2-space 缩进
- `{$mode ObjFPC}{$H+}` 编译模式

## 错误处理策略

- 默认用异常，调用方写直线代码
- 边界处统一捕获（HTTP handler、TUI 事件循环、main）
- TryXxx 仅在调用方需区分成功/失败分支时提供
- "无值"用 nil 表达，不引入 Result/Optional 类型