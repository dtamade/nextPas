# nextPas 目标平台规范

用这份规范定义 nextPas 第一阶段目标平台规格的边界。它回答的不是“未来可能支持哪些
平台”，而是“在当前 `stage0` 基线上，什么信息必须从代码中外置出来，并且只能服务
于 Linux x86_64”。

如果你要看 host/target/toolchain/sysroot 如何在架构上正式分离，继续读
`cross-compilation-specification.md`。如果你要看 LLVM triple / data layout 为什么仍然属于
target facts，继续读 `llvm-backend-specification.md`。如果你要看 `Cprefix`、C library naming
和 target-aware C linking 怎样进入正式 contract，继续读 `c-interop-specification.md`。
如果你要看 assembler/linker/archiver/resource tool 怎样消费这些 target facts，继续读
`toolchain-specification.md`。

## 为什么目标规格必须外置

第一阶段的 `promotion gate` 已经要求目标平台规格不能深埋在 Pascal 代码里。
如果平台假设继续散落在命令行驱动、运行时目录或临时 shell 参数里，后续就无法判断
到底是命令入口错了、目标模型错了，还是发行布局错了。

因此，`build/targets/linux-x86_64.toml` 不是装饰性配置，而是 nextPas 第一阶段的
单一目标事实来源。

## 第一阶段只允许一个目标

第一阶段唯一合法目标是：

```text
linux-x86_64
```

这条约束同时作用于：

- `nextpas build <source> --target linux-x86_64`
- `units/<target>/` 的发行布局语义
- Linux CI 与 `build/verify_local.sh`
- `stage0` 下的 smoke 构建路径

任何其他目标，包括 `windows-x86_64`、`macos-x86_64` 或预留占位目标，都不应在
当前规格中被声明为受支持。

## 当前只启用一个 target，不等于 target model 只有一个字符串

nextPas 当前只启用一个 target，是阶段控制，不是 target model 的最终形状。

即使在当前基线下，target facts 也不能退化成只有 `linux-x86_64` 这一行字符串，因为
FPC 真源码已经证明一个 target profile 真实包含：

- ABI 与 alignment
- assembler / linker / archiver / resource flavor
- C symbol prefix 与 C library naming
- object / archive / shared library 格式
- optional LLVM data layout

这也是为什么下一步 cross compilation、LLVM backend 和 C interop 都必须继续复用同一份
`TargetFacts`，而不是各自再长一套 target truth。

当前仓库里的最小真实 target profile 也已经把这件事写回实体：

- `build/targets/linux-x86_64.toml`
  - 当前已显式写出 `object_format=elf`
  - 当前已显式写出 `assembler_flavor=gnu-as`
  - 当前已显式写出 `linker_flavor=gnu-ld`
  - 当前已显式写出 `runtime_layout_key=target-sdk-split`
  - 当前已显式写出 `c_symbol_prefix=""`
  - 当前已显式写出 `c_library_naming=lib-prefix-so-a`
  - 当前已显式写出 `llvm_triple=x86_64-unknown-linux-gnu`
  - 当前已显式写出 Linux x86_64 对应的 `llvm_data_layout`
  - 当前已显式写出 `toolchain_binding=build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml`
- `build/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml`
  - 当前已显式写出 `binding_id`
  - 当前已显式写出 host / target identity
  - 当前已显式写出 `backend_family=native`
  - 当前已显式写出 `host_compiler=fpc`
  - 当前已显式写出 `sysroot_mode=runtime-sdk`
  - 当前已显式写出 `runtime_sdk=linux-x86_64`
  - 当前已显式写出 `allow_host_fallback=false`

也就是说，nextPas 现在不只是“将来需要 target facts”，而是已经把最小 target/backend/toolchain
truth 放进正式配置文件里，并由 `tools/stage0/target_config.pas` 真实消费。

## `build/targets/linux-x86_64.toml` 需要承载什么

第一阶段的目标规格至少要把以下信息作为显式字段或显式注释写清：

| 信息类别           | 第一阶段要求                                                                                     |
| ------------------ | ------------------------------------------------------------------------------------------------ |
| 目标标识           | 明确写出 `linux-x86_64`，作为当前唯一受支持目标                                                  |
| ABI / symbol facts | 写清 ABI、calling convention family、`Cprefix` 与 C library naming 规则                          |
| backend profile    | 写清 assembler / linker / archiver / resource flavor、object format，以及是否存在 LLVM profile   |
| 宿主工具链假设     | 写清 FreePascal/FPC 作为 `stage0` 宿主时依赖的最小调用前提，以及 host-to-target binding identity |
| 输出布局假设       | 与 `bin/`、`lib/`、`units/<target>/`、`share/` 的设计语义保持一致                                |
| 当前启用限制       | 明确当前不支持其他平台、其他 ABI 或未文档化的目标变体                                            |

这份规格不需要在第一阶段变成一个庞大的配置系统，但必须足够明确，足以替代
“把平台规则写死在代码里”的做法。

## 命令行入口如何使用目标规格

`tools/stage0/nextpas.pas` 与 `tools/stage0/target_config.pas` 应把目标规格当成
控制面输入，而不是当成实现细节附注。

公开行为应满足：

- 当目标为 `linux-x86_64` 时，驱动入口能够走通受支持的构建路径。
- 当目标不是受支持集合成员时，命令以非零状态退出，并清晰报告 `unsupported target`。
- 目标判断逻辑以外置规格为准，而不是以分散在 Pascal 代码中的条件分支为准。
- `stage0 build` 成功路径能把 `target-object-format`、`target-assembler-flavor`、
  `target-linker-flavor`、`target-runtime-layout-key`、`target-c-library-naming`、
  `target-llvm-triple`、`sysroot-mode`、`toolchain-binding-id` 与 `backend-family`
  投影回统一 command result bridge。

这也是为什么 `target-platform-specification.md` 必须与 `stage0-driver-specification.md`
配套存在。

## 目标规格与发行布局的关系

目标规格不能只管编译选项，不管产物去向。它至少要与以下发行语义保持一致：

- 目标相关产物应能解释为 `units/<target>/` 下的安装结果。
- 目标无关或共享资产应继续归入 `lib/` 或 `share/` 的公开语义。
- 目标规格不应该绕开 `distribution-layout-specification.md` 另起一套私有目录规则。

这条边界保证“构建目标”与“产物落点”不会在后续实现中脱节。

## 第一阶段非目标

- 不引入多目标矩阵。
- 不加入 Windows/macOS 的预留空配置。
- 不把 ABI 稳定性写成当前承诺，`ABI compatibility is deferred`。
- 不把多目标 execution support 宣告为当前基线能力。
- 不允许代码和配置同时各自维护一套互相矛盾的平台事实。

第一阶段要得到的是“单一、显式、可拒绝非法输入的目标规格”，而不是一个看似前瞻、
实际无法验证的多平台草案。
