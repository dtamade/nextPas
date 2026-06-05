# nextpas.core

nextPas 的基座框架。这里承载 `nextpas.core.*` 源码、测试、示例、benchmark 和模块文档。

这份 README 只做 core 子项目导航；设计规范以 `docs/design-conventions.md` 为准。

## 先从这里读

1. `AGENTS.md`
2. `docs/design-conventions.md`
3. 仓库根目录 `../AGENTS.md`
4. 仓库根目录 `../docs/worktrees.md`
5. 当前模块的 `docs/<module>/`、`docs/nextpas.core.<module>*.md` 或 `docs/plans/*`

如果你直接在 `core/` 目录启动 Codex/Claude，先读 `AGENTS.md`。如果你在仓库根目录启动，
也要在改 core 代码前回到这里读 core 专属入口。

## 构建

core 有自己的聚合 `Makefile`：

```bash
make build       # 编译框架
make test        # 编译并运行所有测试
make examples    # 编译所有示例
make benchmarks  # 编译并运行所有基准
make clean       # 清理构建产物
```

每个 `tests/`、`benchmarks/`、`examples/` 下的独立项目都应提供自己的
`Makefile`，可以进入项目目录单独构建或运行。顶层 Makefile 只做聚合，
不要把大型框架的失败边界藏在一个总脚本里。

普通模块开发优先跑 focused gate，例如：

```bash
make -C tests/nextpas.core.http/test_http_client clean test
```

提交前还要从仓库根目录运行：

```bash
make -C "$(git rev-parse --show-toplevel)" hygiene
git diff --check
```

## 要求

- FPC 3.3.1 (trunk) 或 nextPas 编译器

## 目录结构

```
src/        源码（.pas + .inc 平铺）
tests/      测试项目（按模块分子目录）
benchmarks/ 基准项目（按模块分子目录）
examples/   示例项目（按模块分子目录）
vendors/    第三方 C 库源码
docs/       设计文档
scripts/    构建脚本
build/      构建产物（git ignored）
```

## 设计规范

`docs/design-conventions.md` 是 nextpas.core 的设计规范和项目规范权威入口。它覆盖：

- 命名、文件组织和模块四件套范式
- L0-L3 分层和 owner boundary
- 接口、错误处理、FFI、内存所有权、线程安全
- 测试、benchmark、example 和文档布局
- 构建产物隔离和多人 / 多 AI 协作纪律

core 下的任何生产代码、测试、示例或 benchmark 改动，都必须遵守该文件。

## 许可证

MIT
