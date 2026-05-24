# nextPas tools/

`tools/` 用于放置 nextPas 面向开发者的工具入口。nextPas 的长期目标是一整套开发环境，
所以这里最终不会只承载一个 compiler wrapper。第一阶段先从一个受约束的
FreePascal 托管 `stage0` 驱动开始，先公开 `build`、最小 `test`、`env status/use/sync/clean`、
最小 `doctor`、最小 `query symbols` 与只读 `pkg inspect`，而不是从大而全的工具集开始。

这里的结构原则明确参考 Rust / Go 一类现代工具链的长处：公开命令入口尽量薄，共享核心能力尽量
沉到稳定控制面里。换句话说，`tools/` 更像统一 developer command surface，而不是一堆各自为政的脚本。

如果你要看冻结后的公开行为，先读
`docs/architecture/stage0-driver-specification.md`。如果你要看 future workspace-aware tool
surface 应该建立在什么控制面上，继续读 `docs/architecture/workspace-specification.md`。
如果你要看 package manager、formatter、doc、richer doctor、richer query 这些 future tools 应该怎样共用
统一产品命令面，继续读 `docs/architecture/developer-tooling-specification.md`。
如果你要看 `pkg` family 自己的 workflow、manifest/lock truth 和 target-aware install
layout 怎样冻结，继续读 `docs/architecture/package-workflow-specification.md`。

## 第一阶段这里会承接什么

- `stage0/`：最小 `nextpas` 命令行控制面所在位置
- `../examples/smoke/hello.pas`：`stage0` 驱动入口的规范 smoke 输入
- 后续与架构文档明确对齐的开发者工具入口，例如 package manager、formatter、language service surface

第一阶段当前承诺的公开命令路径是：

```text
nextpas build <source> --target linux-x86_64
nextpas test --list-groups
nextpas test --filter <group>
nextpas env status --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]
nextpas env use --target linux-x86_64 --toolchain-binding <id> --workspace <root>
nextpas env sync --target linux-x86_64 [--toolchain-binding <id>] --workspace <root>
nextpas env clean --target linux-x86_64 --workspace <root>
nextpas doctor --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]
nextpas query symbols <source> --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]
nextpas pkg inspect --workspace <root> --target linux-x86_64 [--toolchain-binding <id>]
```

这组路径的意义，是让 FreePascal 继续充当 `stage0` 宿主时，nextPas 已经拥有最小但真实的
build/test/env/doctor/query/pkg 工具入口表面；其中 `env status` 投影已解析环境状态，
`env use` 只写 workspace-local selection sidecar，`env sync` 只刷新 workspace-local
resolution sidecar，不承担 `bootstrap`、下载、解包或 runtime SDK 安装动作，
`query symbols` 只复用 compilation session 的语义结果，不假装完整 language service 已经落地。

## 这里必须和谁对齐

- `build/targets/linux-x86_64.toml`：目标事实来源
- `tests/` 与 smoke 样例：命令路径的验证入口
- `examples/smoke/hello.pas`：当前标准 build 输入
- `build/`：本地验证与 CI 的复用控制面

## 这里现在不做什么

- 不在第一阶段就把 `tools/` 扩张成完整包管理器、格式化工具、IDE 或 LSP 集合。
- 不把平台事实硬编码在 CLI 目录里。
- 不让每个 future tool 都复制一份自己的 workspace / target / package / toolchain 逻辑。
- 不提前承诺 `env bootstrap`、下载、解包或 runtime SDK 安装这类更深 materialization verbs 已经落地。
