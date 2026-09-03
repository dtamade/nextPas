# nextpas.core

[![Version](https://img.shields.io/badge/version-1.0.0-blue)](VERSION) [![FPC](https://img.shields.io/badge/FPC-3.3.1-orange)](https://www.freepascal.org/) [![License](https://img.shields.io/badge/license-MIT-green)](LICENSE) [![Core](https://img.shields.io/badge/core-L0--L3%20%E4%B8%A5%E6%A0%BC%E5%88%86%E5%B1%82-lightgrey)](docs/design-conventions.md) [![Tests](https://img.shields.io/badge/tests-focused%20gate-brightgreen)](tests/) [![Docs](https://img.shields.io/badge/docs-100%2B%20modules-blueviolet)](docs/)

nextPas 的基座框架。这里承载 `nextpas.core.*` 源码、测试、示例、benchmark 和模块文档。

> **定位**：单一命名空间 `nextpas.core.*`，100+ 单元，L0–L3 严格分层，仅向下依赖，无同层循环；`nextpas.core` 是编译器与运行时唯一实现层（拥有 `IStream`/`text.conv` 等自有类型体系，不包装 FPC `TStream`/`SysUtils` 遗留）。

这份 README 只做 core 子项目导航；设计规范以 `docs/design-conventions.md` 为准。

## 概览 · L0 口径与特性矩阵

**分层口径**：

```
L0 基座  base · exception · errors · mem · platform · log.intf · atomic    ← 仅 FPC RTL
L1 能力  bytes · text · encoding · collections · hash · sync · async        ← 仅依赖 L0
L2 能力  fs · path · net · tls · crypto · compress · tar · zip · json · time      ← 仅依赖 L0–L1
L3 运行时 http · websocket · tui · config · bench · agent                    ← 仅依赖 L0–L2
```

| 维度 | 代表模块 | 亮点（轻量高级感，克制陈述） |
|------|----------|------------------------------|
| 类型与内存 | `base` · `mem` · `bytes` | `TBytes`/`TByteSpan`/`SizeInt` 原生类型，`IAllocator` 注入，`TResult`/`TOption` 值语义，heaptrc 0 泄漏门禁 |
| 集合 | `collections` | `Vec`/`HashMap`（Swiss Table 默认）/`TreeMap`/`BTree`/`ConcurrentHashMap` 等 25+ 容器，`MakeXxx` 工厂，`TMemAllocator` 统一 |
| 文本与编码 | `text` · `encoding` · `hash` | `text.conv` 拥有 `Format`/`SameText`，纯函数无状态，`Base64`/`Hex`/`Varint`/`Url` 4 编码 |
| 网络与安全 | `net` · `tls` · `http` | H1/H2 双栈，HPACK/GOAWAY/流控，`IHttpClient`/`IHttpServer` 单一异常 `EHttpError(hek*)` 12 类正序 |
| 工具与可观测 | `bench` · `test` · `log` · `config` | 微基准统计诚实、property 测试、结构化日志、类型安全配置 |

> 设计以“最小可测试门面 + 显式所有权 + source-contract 隔离 FPC RTL”为约束；`core/src` 平铺 `.pas`，`core/tests` 按模块 `focused gate`，产物隔离 `build/`，协作见 `AGENTS.md`。

## 先从这里读

1. `AGENTS.md`
2. `docs/design-conventions.md`
3. 仓库根目录 `../AGENTS.md`
4. 仓库根目录 `../docs/worktrees.md`
5. 当前模块的 `docs/<module>/` 或相关 `docs/plans/*`

如果你直接在 `core/` 目录启动 Codex/Claude，先读 `AGENTS.md`。如果你在仓库根目录启动，
也要在改 core 代码前回到这里读 core 专属入口。

## 构建

core 有自己的聚合 `Makefile`。它适合做收口验证，不是每个小任务的默认第一选择：

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
make -C tests/nextpas.core.math clean test
make -C tests/nextpas.core.simd cpuinfo-focused
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

## 最小示例

```bash
# 聚合验证
make -C core build
make -C core/tests/nextpas.core.collections/quickstart clean test
```

```pascal
program quickstart;
{$mode objfpc}{$H+}
uses nextpas.core.collections, nextpas.core.collections.vec.intf;
var V: specialize IVec<Integer>;
begin
  V := specialize MakeVec<Integer>;
  V.Push(42);
  WriteLn(V.Pop);
end.
```

> 版本以 `VERSION` 为准（当前 `1.0.0`），完整示例见 `examples/`。

## 设计规范

`docs/design-conventions.md` 是 nextpas.core 的设计规范和项目规范权威入口。它覆盖：

- 命名、文件组织和模块四件套范式
- L0-L3 分层和 owner boundary
- 接口、错误处理、FFI、内存所有权、线程安全
- 测试、benchmark、example 和文档布局
- 构建产物隔离和多人 / 多 AI 协作纪律

core 下的任何生产代码、测试、示例或 benchmark 改动，都必须遵守该文件。

## 文档分工

- `AGENTS.md`：core 目录下的 AI 开工入口。
- `README.md`：core 子项目导航。
- `docs/design-conventions.md`：稳定设计规范和项目规范。
- `docs/plans/`：阶段性计划、审计和迁移记录。
- `docs/<module>/`：模块专题设计和维护文档；旧式 `docs/nextpas.core.<module>*.md` 平铺文档已废弃。

## 许可证

MIT
