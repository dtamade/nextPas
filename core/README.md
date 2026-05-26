# nextpas.core

nextPas 的唯一基座框架。提供从基础类型到 HTTP 服务、终端 UI 的完整开发能力。

## 状态

初始阶段，L0 内核模块与第一批 L1 基础设施模块已开始落地：

- L0: `base`、`errors`、`platform`、`mem`、`log.intf`
- L1: `testing`、`bytes`、`time`、`sync`

顶层 `build/verify_local.sh` 已覆盖 `nextpas.core.time` 与
`nextpas.core.platform.sync` 的 focused 编译/运行检查。

## 构建

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

见 [docs/design-conventions.md](docs/design-conventions.md)

## 许可证

MIT
