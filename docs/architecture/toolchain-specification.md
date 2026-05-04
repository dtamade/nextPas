# nextPas 工具链规范

用这份规范定义 nextPas 作为“下一代 Pascal 开发环境”时的工具链边界。它回答的不是
“linker 具体叫什么名字”，而是“compiler kernel、外部 build tools、sysroot / SDK 资产、
developer-facing tools 应该怎样分层，才能让 nextPas 不只是一个编译器目录，而是一套现代、
优雅、高性能的开发环境”。

这份文档和 `stage0-driver-specification.md`、`backend-specification.md`、
`cross-compilation-specification.md`、`distribution-layout-specification.md`、
`test-harness-specification.md` 一起工作。前者们分别冻结公开命令表面、编译器后端、
host/target 分离、发行布局和验证控制面；这里冻结“谁来发现工具、谁来调用工具、
谁来为调用结果负责”的正式控制层。如果你要看 future GUI stack 怎样把 shader / asset /
surface tooling 接进同一套控制面，继续读 `gui-framework-specification.md`。如果你要看
future IDE build / test / package workflow 怎样继续复用同一套控制面，继续读
`ide-specification.md`。如果你要看 future language service 怎样消费 target truth 但不接管
tool invocation，继续读 `language-service-specification.md`。如果你要看 project roots、
package refs、target selection 与 artifact roots 怎样先收敛成 workspace control plane，
继续读 `workspace-specification.md`。如果你要看 package manager、formatter、doc、env、doctor
和 semantic query 怎样收敛到统一产品命令面，继续读 `developer-tooling-specification.md`。
如果你要看 package manifest、lock、install root 和 `pkg` workflow 怎样继续消费
`ToolchainBinding`，继续读 `package-workflow-specification.md`。
如果你要看 GUI 的 shader / atlas / font / theme preprocessing 怎样收敛到 render asset pipeline，
继续读 `render-asset-pipeline-specification.md`。

## 先看 FPC 真源码已经把哪些工具链事实写成真实系统

这份规范直接回应这些 FPC 真实源码事实：

- `compiler/systems.pas`
  - `tasminfo`、`tarinfo`、`tresinfo` 已经分别把 assembler、archiver、resource compiler
    写成独立 profile
  - `tsysteminfo` 同时持有 `assem`、`assemextern`、`link`、`linkextern`、`ar`、`res`、
    `Cprefix` 和 `llvmdatalayout`
- `compiler/assemble.pas`
  - `FindAssembler`、`CallAssembler`、`DoAssemble` 说明 assembler orchestration 是正式层，
    不是 backend 顺手执行一条 shell
  - `af_llvm` 说明某些 assembler 实际属于 LLVM toolchain
- `compiler/link.pas`
  - `TLinker`、`RegisterLinker`、`InitLinker`、`AddStaticCLibrary`、
    `AddSharedCLibrary` 说明 linker / binder / archive orchestration 是独立层
  - linker 选择确实受 `target_info.link` / `target_info.linkextern` 控制
- `compiler/systems/i_linux.pas`
  - Linux target info 直接带 `assem`、`assemextern`、`linkextern`、`ar`、`res`、
    `Cprefix` 与 `llvmdatalayout`
  - x86_64 Linux 与 AArch64 Linux 明明同属 Linux，assembler/linker/toolchain facts 仍然不同
- `compiler/systems/t_linux.pas`
  - `SetupLibrarySearchPath` 明说要“take sysroots and cross-compiling into account”
  - dynamic linker fallback 明说“when cross compiling”
  - link script 和 shared/static C library 处理都会受 sysroot 与 cross-link 行为影响

这些事实说明：FPC 虽然耦合很重，但它已经证明 toolchain 绝不是“编译器最后执行几条命令”
这么简单。nextPas 真正该做的，是把这些能力写成现代、显式、可组合的控制面。

## nextPas 不只是 compiler，compiler 只是 kernel

nextPas 的长期目标不是“一个能吐出目标文件的 Pascal compiler”，而是一整套 Pascal
开发环境。只是第一阶段为了控制范围，先只实现最小公开表面。

因此，toolchain 在 nextPas 里至少有这几层：

```text
nextPas developer environment
├── command surface
│   ├── nextpas driver
│   ├── test harness
│   └── future pkg/env/fmt/doc/doctor/query/language service surfaces
├── toolchain control plane
│   └── HostFacts + TargetFacts + ToolchainBinding + Sysroot
├── build tools
│   ├── assembler
│   ├── linker
│   ├── archiver
│   ├── resource compiler
│   └── optional LLVM utilities
├── compiler kernel
│   └── frontend -> sema -> Typed HIR -> MIR -> Codegen adapter
└── runtime and SDK assets
    └── rtl / crt / units/<target> / lib / share
```

这张图刻意把 `compiler kernel` 放在中间，而不是放在最上层。原因很简单：

- compiler 是工具链的核心内核
- 但公开命令表面不应该直接暴露 compiler 内部结构
- build tools 不应该反向主导 compiler 的数据模型
- runtime / installed units / distribution assets 也属于开发环境的一部分

第一阶段只承诺 `nextpas build <source> --target linux-x86_64`，不等于 nextPas 的长期架构
只剩一个编译器可执行文件。

## developer-facing tools 必须走 thin entrypoint + shared core

如果 nextPas 的项目结构要参考 Rust、Go 这类先进工具链，最该学的不是目录名，而是命令表面和
共享核心的关系。

因此 nextPas 冻结：

- package manager、environment tooling、formatter、language service、test runner、doctor、future IDE helper 都属于 command surface
- 它们应尽量做成 thin entrypoint
- 它们共享 `ToolchainBinding`、`ToolInvocationPlan`、diagnostics contract、workspace truth 与 target facts
- 不允许每个工具单独重写 tool discovery、sysroot resolution、artifact placement 或 failure mapping

这条规则的意义是：

- 使用工具更方便，因为行为一致
- 设计新工具更方便，因为共享核心已经在仓库结构里有正式归属
- 架构更优雅，因为“工具多”不会自动等于“逻辑重复”

## `ToolchainBinding` 必须是整套开发环境的执行契约

`cross-compilation-specification.md` 已经把 `ToolchainBinding` 定义成 host-to-target pair 的主键。
这里进一步冻结：它不只是 backend 的附注，而是整套开发环境里“谁来生产目标产物”的正式契约。

一个合法 `ToolchainBinding` 至少要显式表达：

- `backend family`
- `AssemblerProfile`
- `LinkerProfile`
- `ArchiverProfile`
- `ResourceToolProfile`
- optional LLVM executable set
- sysroot policy
- response file / script generation policy
- tool discovery policy

这里最重要的边界是：

- `TargetFacts` 负责目标 ABI、object format、symbol 和 library naming 规则
- `ToolchainBinding` 负责用哪套工具去实现这些目标规则
- developer-facing tools 只能消费 binding，不能各自绕开 binding 私自找工具

也就是说，未来无论是 `nextpas build`、`nextpas check`、`harness`，还是更后面的
package/workspace surface，都不能再各自偷偷拼一套“本机上能跑”的工具调用逻辑。

## 先冻结一份最小 `build/toolchains/<host>-to-<target>.toml` skeleton

如果 `ToolchainBinding` 继续只停留在抽象名词，后面实现时还是很容易重新退回
`CROSSBINDIR -> LDPROG/ARPROG/RCPROG/NASMPROG` 那种分散推导路径。

FPC 的 `fpcmake.ini`、debugsvr makefiles 和 `link.pas` 已经把反例写出来了：

- `CROSSBINDIR` 会派生 `ASPROG`、`LDPROG`、`RCPROG`、`ARPROG`、`NASMPROG`
- `FPCDIR`、`UNITSDIR`、`INSTALL_*DIR` 又在另一层继续表达 runtime / install 事实
- 如果没有一份正式 binding spec，tool role、runtime SDK 和 install layout 很快就会再次缠住

因此 nextPas 先推荐一份最小、够用、但已经足够实现的 binding skeleton：

```toml
[binding]
id = "linux-x86_64-to-linux-x86_64-gnu"
host = "linux-x86_64"
target = "linux-x86_64"
backend_family = "native"

[profiles]
assembler = "gnu-as"
linker = "gnu-ld"
archiver = "gnu-ar"
resource = "none"

[llvm]
enabled = false

[sysroot]
mode = "runtime-sdk"
runtime_sdk = "linux-x86_64"
allow_host_fallback = false

[resolution]
tool_root_kind = "distribution-helper-root"
runtime_root_kind = "distribution-runtime-root"
response_files = "auto"
link_scripts = "when-required"
```

这份 skeleton 当前先冻结这些 ownership：

- `[binding]` 持有 host/target pair identity 和 backend family
- `[profiles]` 只引用正式 profile id，不复制一整份 target facts 或 raw command template
- `[llvm]` 只表达这条 binding 是否要求 LLVM executable set，以及在启用时引用哪条 logical set id，
  不重写 triple/data layout
- `[sysroot]` 只表达 sysroot policy 和 runtime SDK selector，不保存 machine-local absolute path
- `[resolution]` 只表达从 distribution metadata 解析 helper root / runtime root 的逻辑方式，
  不保存 activated dist root 或 user-local cache locator

同样重要的是，`build/toolchains/<host>-to-<target>.toml` 继续明确不负责这些内容：

- 不保存 resolved dist root、selected channel、archive cache path、workspace-local activation state
- 不保存 final raw linker argv、response file content 或 concrete sidecar filename
- 不复制 `TargetFacts`、package dependency graph、workspace membership 或 install truth
- 不把 bundled toolchain executable path 写成 author hand-edit 的 host-local absolute path

换句话说，binding spec 负责“这条 host-to-target 关系需要哪些正式 role 和 policy”；
真正的 helper root、runtime SDK root 和 activated tool path 继续由 distribution metadata 与 `env`
解析结果提供。

当前仓库里的最小真实落点已经开始对齐这份 skeleton，而不是只停在文档名词上：

- `tools/stage0/target_config.pas` 现在会真实读取 `[profiles]`、`[sysroot]` 与 `[resolution]`
- `compiler/targets/np_target_facts.pas` 会把
  `AssemblerProfileId / LinkerProfileId / ArchiverProfileId / ResourceToolProfileId`、
  `ToolRootKind / RuntimeRootKind / ResponseFilePolicy / LinkScriptPolicy` 收进 typed metadata
- `tools/stage0/nextpas.pas` 会把这些字段投影成
  `assembler-profile-id`、`linker-profile-id`、`archiver-profile-id`、
  `resource-tool-profile-id`、`tool-root-kind`、`runtime-root-kind`、
  `response-file-policy` 与 `link-script-policy`

也就是说，nextPas 当前已经不再把“将来要怎么找到 assembler/linker/runtime root”留给
driver 私有猜测；哪怕真实执行仍只有 host compiler 这一条 step，binding 级执行契约也已经先固定。

## assembler、linker、archiver、resource compiler 必须各自有正式 profile

FPC 今天已经用 `tasminfo`、`tarinfo`、`tresinfo` 证明这几类工具需要独立 profile。
nextPas 继续保留这个事实，但把边界写得更清楚。

| Profile               | 至少冻结哪些字段                                                                                                                      | 为什么必须单列                                                             |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `AssemblerProfile`    | tool flavor、candidate executable names、input kind、output kind、default arg template、response file capability                      | assembler 既可能是 GNU as，也可能是 LLVM toolchain 的一部分                |
| `LinkerProfile`       | tool flavor、candidate executable names、supported output kinds、dynamic linker policy、script strategy、C library group/order policy | linker 不只是“把 `.o` 拼起来”，它还决定 shared/static/runtime linking 语义 |
| `ArchiverProfile`     | tool flavor、create/update/finalize pattern、script mode、archive format assumptions                                                  | static library production 不是 linker 的附注                               |
| `ResourceToolProfile` | rc/res/obj pipeline、input suffixes、output suffixes、single-stage or two-stage behavior                                              | resource handling 在很多目标上都不是 assembler 或 linker 的子步骤          |

这四类 profile 的职责边界必须保持稳定：

- `AssemblerProfile` 不定义 target ABI
- `LinkerProfile` 不重新定义 symbol naming
- `ArchiverProfile` 不私自决定 installed layout
- `ResourceToolProfile` 不吞掉 diagnostics responsibility

它们都只是 `ToolchainBinding` 里的执行部件，不是第二套 target truth。

如果 profile 继续只停留在字段名称，后面实现时还是会重新退回把 `TLinkerInfo.ExeCmd`、
`TLinkerInfo.DllCmd`、`tarinfo.arcmd` 或 `tarinfo.arfinishcmd` 当成 opaque string 直接到处复制。
nextPas 要冻结的，不是某条 shell 模板，而是这些模板背后真正稳定的执行语义。

### `AssemblerProfile` 也需要一份最小 skeleton

FPC `systems.pas` 的 `tasminfo` 直接有 `asmbin`、`asmcmd` 和 `flags`，而 `assemble.pas` 的
`FindAssembler`、`CallAssembler`、`DoAssemble` 又说明 assembler invocation 真的会依赖
tool discovery、LLVM suffix、command template 和 rerun policy。

因此 nextPas 推荐先冻结一份最小 `AssemblerProfile` skeleton：

```toml
[assembler_profile]
id = "gnu-as"
tool_flavor = "gnu-as"
driver_candidates = ["as"]
input_kind = "assembly-text"
output_kind = "object-file"
command_template_kind = "gnu-as"
response_file_mode = "unsupported"
target_selector_mode = "none"
llvm_toolchain_member = false
smartlink_section_support = "native"
```

这份 skeleton 当前只回答这些稳定问题：

- `driver_candidates`、`command_template_kind` 对应 `asmbin/asmcmd` 背后的可序列化角色
- `input_kind`、`output_kind` 回答 assembler 消费和产出的 artifact category
- `response_file_mode` 回答是否允许把大参数集下沉成 `@file`
- `target_selector_mode` 回答 serializer 是否需要像 LLVM triplet 这类 target selector
- `llvm_toolchain_member` 对应 `af_llvm` 这类 capability bit，但不把 LLVM target semantics 带进来
- `smartlink_section_support` 回答 smartlink section 是 tool capability 还是上游必须规避的限制

它继续明确不回答这些内容：

- 不回答 `TargetFacts` 里的 ABI、object format 或 symbol naming
- 不回答 resolved executable path 或 host-local utility directory
- 不回答 assembler text 的 comment token、label prefix 或 dollar escaping 细节
- 不把某条 `asmcmd` 原样复制成 shared metadata contract

换句话说，`AssemblerProfile` 只定义 assembler invocation family；真正的 asm dialect 和 target
emission 事实，继续留在 backend emission contract 与 `TargetFacts`。

### `LinkerProfile` 需要一份最小 skeleton

FPC `link.pas` 的 `TLinkerInfo` 明确有 `ExeCmd`、`DllCmd`、`ScriptName`、`DynamicLinker` 和
`ExtraOptions`。这说明 linker profile 至少要回答三件事：生成哪类产物、是否依赖 sidecar script，
以及 dynamic linker / search flag 这类 invocation family 规则归谁所有。

因此 nextPas 推荐先冻结一份最小 `LinkerProfile` skeleton：

```toml
[linker_profile]
id = "gnu-ld"
tool_flavor = "gnu-ld"
driver_kind = "direct-linker"
driver_candidates = ["ld"]
executable_kinds = ["executable", "shared-library"]
command_template_kind = "elf-gnu"
response_file_mode = "auto"
script_asset_kind = "gnu-link-script"
dynamic_linker_policy = "target-default-with-override"
library_search_flag = "-L"
shared_flag = "-shared"
map_file_support = "flag"
ordered_symbols_support = "sidecar-file"
```

这份 skeleton 当前只回答这些稳定问题：

- `driver_kind` 回答这条 profile 是 direct linker、compiler driver 还是 platform wrapper
- `executable_kinds` 回答 profile 是否显式区分 executable/shared-library 等 invocation family
- `command_template_kind` 回答 serializer 该选哪一类模板，而不是直接保存 raw `ExeCmd`
- `response_file_mode`、`script_asset_kind` 回答 sidecar 资产是否为正式一等公民
- `dynamic_linker_policy`、`library_search_flag`、`shared_flag` 回答 invocation family 的稳定差异
- `map_file_support`、`ordered_symbols_support` 回答 map file 与 ordered symbol sidecar 是否有正式能力位

它继续明确不回答这些内容：

- 不回答 final raw linker argv
- 不回答 resolved dynamic linker path 或 sysroot-expanded search root
- 不回答具体应该链接哪些 C library、package install result 或 runtime object
- 不把 `TargetFacts` 里的 triple、ABI、symbol naming 复制进 profile

换句话说，`LinkerProfile` 只描述“这类 linker 能怎样被序列化”；真正一次 link 的具体参数，
仍然来自 `LinkerInputSet + TargetFacts + Sysroot + ToolchainBinding`。

### `ArchiverProfile` 也需要一份最小 skeleton

FPC `systems.pas` 的 `tarinfo` 直接有 `addfilecmd`、`arfirstcmd`、`arcmd`、`arfinishcmd`。
这说明 archiver 不是“一条 `ar rcs` 命令”就能抽象完的东西；不同工具会把 create、append、finish、
scripted batch 和 index write 分散成不同阶段。

因此 nextPas 推荐先冻结一份最小 `ArchiverProfile` skeleton：

```toml
[archiver_profile]
id = "gnu-ar"
tool_flavor = "gnu-ar"
driver_candidates = ["ar"]
add_file_mode = "batch-files"
create_mode = "implicit-on-add"
finish_mode = "separate-index-pass"
script_mode = "optional-mri-script"
archive_format = "gnu-ar"
index_policy = "write-symbol-index"
```

这份 skeleton 的重点是：

- `add_file_mode`、`create_mode`、`finish_mode` 把 `arfirstcmd/arcmd/arfinishcmd` 背后的阶段分开
- `script_mode` 承认 `ar -M < $SCRIPT` 这类 scripted archive flow 是正式能力，不是边角例外
- `archive_format` 回答产物格式假设，避免 static library layout 被 linker/private script 顺手定义
- `index_policy` 回答是否需要单独 symbol index pass，例如 `ar s $LIB`

它同样继续不回答这些内容：

- 不回答 archive 产物最终安装到哪里
- 不回答 package publish / install layout
- 不回答 machine-local executable path
- 不把某个 archiver 的整条命令行当成 shared metadata 真相源

### `ResourceToolProfile` 也需要一份最小 skeleton

FPC `tresinfo` 与 `comprsrc.pas` 已经把资源编译流程写得很明确：

- `rcbin/rccmd` 是 optional `.rc -> .res` stage
- `resbin/rescmd` 是 `.res -> .o` 或等价 object stage
- 某些目标会让 `rc` stage 缺席，直接复用 `res` stage
- resource output 最终是否进入 link input，还要看 object output 是否真的被产出

因此 nextPas 推荐先冻结一份最小 `ResourceToolProfile` skeleton：

```toml
[resource_tool_profile]
id = "windres+fpcres-coff"
pipeline_kind = "optional-rc-plus-res"
rc_driver_candidates = ["windres"]
res_driver_candidates = ["fpcres"]
rc_command_template_kind = "gnu-windres"
res_command_template_kind = "fpcres-coff"
input_suffixes = [".rc", ".res"]
output_suffixes = [".res", ".o"]
intermediate_asset_kind = "binary-resource"
single_stage_fallback = "reuse-res-driver"
arch_parameter_mode = "target-arch-token"
```

这份 skeleton 的重点是：

- `pipeline_kind` 承认 resource pipeline 本来就可能是单阶段或双阶段，不是假设永远只调用一个 bin
- `rc_driver_candidates`、`res_driver_candidates` 把 optional front-stage 与 object stage 分开
- `rc_command_template_kind`、`res_command_template_kind` 把 `rccmd/rescmd` 归入 serializer policy
- `intermediate_asset_kind` 让 `.res` 这类中间资产有正式类型，而不是临时文件碰巧存在
- `single_stage_fallback` 对应 FPC “如果没有独立 `rcbin`，就退回 `resbin/rescmd`” 这种真实行为
- `arch_parameter_mode` 承认 `$ARCH` 这类 target-aware token 是 invocation family 的一部分

它同样继续不回答这些内容：

- 不回答 include search roots、sysroot root 或 package asset root
- 不回答 resource object 最终以什么顺序进入 final link
- 不回答 machine-local resource compiler path
- 不把 `.rc`/`.res` 中间文件暴露成公开稳定 IR

这条边界很关键，因为 resource pipeline 很容易被误写成 linker 的附属脚本；实际上它应该是
`ToolchainBinding` 里的正式 profile。

## `ToolInvocationPlan` 必须是结构化对象，而不是临时命令行字符串

FPC 的 `assemble.pas` 和 `link.pas` 已经说明，真正复杂的部分不在“有没有调用外部进程”，
而在“调用前是否已经把输入、输出、参数、脚本和失败语义收紧”。

因此 nextPas 冻结一个正式的 `ToolInvocationPlan` 概念。它至少要承载：

- resolved tool identity
- resolved executable path
- argv vector
- environment delta
- working directory
- declared inputs / outputs
- target id / host id / sysroot context
- response file or script sidecar assets
- failure mapping policy

`ToolInvocationPlan` 的意义有三条：

- 高性能：避免每个阶段都重复扫描文件系统和重新拼命令
- 优雅：response file、link script、ordered symbol file 之类临时资产有正式归属
- 可留证：diagnostics、snapshot 和 future build replay 都能指向同一份结构化调用计划

backend 只负责产生产物意图与输入清单；toolchain control plane 才负责把这些信息下沉成
真正可执行的 plan。

这里还要再进一步冻结一个关键边界：`ToolInvocationPlan` 不是“单条 shell 命令的对象包装”，
而是“一份有序 step 列表”。

原因很直接，FPC 真源码已经把反例写出来了：

- resource compile 可能是 `.rc -> .res -> .o`
- archiver 可能要跑 add/create 与 finish/index 两个阶段
- linker 某些目标上还会伴随后处理或 sidecar script generation

如果 `ToolInvocationPlan` 仍然假设自己永远只包一条命令，后面实现时还是会重新退回
`pre step` / `post step` / `temp script` 四处逃逸。

因此 nextPas 推荐一个最小 typed skeleton：

```json
{
  "planKind": "tool-invocation",
  "toolRole": "resource-compiler",
  "bindingId": "linux-x86_64-to-linux-x86_64-gnu",
  "profileId": "windres+fpcres-coff",
  "hostId": "linux-x86_64",
  "targetId": "linux-x86_64",
  "sysrootRef": "runtime-sdk:linux-x86_64",
  "steps": [
    {
      "stepId": "rc-to-res",
      "logicalExecutable": "windres",
      "resolvedPath": "<resolved-by-binding>",
      "argv": ["--include", "<inc>", "-O", "res", "-o", "app.res", "app.rc"],
      "envDelta": [],
      "workingDirectory": "<workspace-or-artifact-root>",
      "inputs": [{ "kind": "resource-script", "path": "app.rc" }],
      "outputs": [{ "kind": "binary-resource", "path": "app.res" }],
      "sidecars": [],
      "failureMapping": "toolchain.resource-exec-failed"
    },
    {
      "stepId": "res-to-obj",
      "logicalExecutable": "fpcres",
      "resolvedPath": "<resolved-by-binding>",
      "argv": ["-o", "app.o", "-of", "coff", "app.res"],
      "envDelta": [],
      "workingDirectory": "<workspace-or-artifact-root>",
      "inputs": [{ "kind": "binary-resource", "path": "app.res" }],
      "outputs": [{ "kind": "resource-object", "path": "app.o" }],
      "sidecars": [],
      "failureMapping": "toolchain.resource-exec-failed"
    }
  ]
}
```

这份 typed skeleton 主要冻结这些 ownership：

- plan 顶层持有 `toolRole`、`bindingId`、`profileId`、host/target/sysroot context
- `steps` 是严格有序的执行单元，resource、archiver、linker 都可以合法拥有多个 step
- 每个 step 自己持有 `logicalExecutable`、`resolvedPath`、`argv`、`envDelta`、`workingDirectory`
- `inputs`、`outputs`、`sidecars` 都必须是 typed artifact，而不是 shell redirection 的副产物
- `failureMapping` 属于 step，保证 diagnostics 能精确落在真正失败的执行点

它继续明确不承诺这些内容：

- 不把整个 plan 退化成 shell string 或 script blob
- 不允许 response file、link script、resource list 靠 `argv` 里的裸重定向字符串偷偷存在
- 不回答 package graph、workspace truth、selected channel 或 IDE session state
- 不把 `resolvedPath` 升格成 shared metadata truth

换句话说，`ToolInvocationPlan` 是 toolchain control plane 的执行快照，不是新的配置文件格式，
也不是另一套环境注册表。

当前仓库中的最小真实落点已经不再只停在这份 JSON 草图上。`stage0 build` 现在会为当前唯一
真实的 `bootstrap-native-assemble-link` production path 生成并投影一条 session-scoped
`ToolInvocationPlan`：

- `planId=plan-<session-id>-primary-tool`
- `toolRole=host-compiler`
- `profileId=fpc-stage0-host`
- `planFamily=bootstrap-native-assemble-link`
- `steps[0].stepId=host-fpc-emit-asm`
- `steps[0].resolvedPath=<resolved-host-fpc-path>`
- `steps[0].argv=["-st","-Aas","-FE<backend-cache>","-FU<backend-cache>","-Fu<abs-units-dir>","<abs-source-path>"]`
- `steps[0].workingDirectory=<workspace-root>/.nextpas/cache/backend/linux-x86_64`
- `steps[0].inputs=[{"kind":"pascal-source","path":"examples/smoke/hello.pas"}]`
- `steps[0].outputs` 至少包含 `assembly-text` 与 `linker-script`
- `steps[1].stepId=native-assemble`，输出 backend-owned `object-file`
- `steps[2].stepId=native-link`，通过确定性的 `<program>_link.res` 产出最终 executable
- 如果 build path 里还存在 source-backed units，plan 还会继续插入
  `native-assemble-<unit>` steps

同一条 plan 当前还会和 richer binding metadata 并行出现：

- `assembler-profile-id=gnu-as`
- `linker-profile-id=gnu-ld`
- `archiver-profile-id=gnu-ar`
- `resource-tool-profile-id=none`
- `tool-root-kind=distribution-helper-root`
- `runtime-root-kind=distribution-runtime-root`
- `response-file-policy=auto`
- `link-script-policy=when-required`

这一步当前已经不再只是冻结“单 step host compile”的边界；它真实切进了
“host emit asm + native assemble + native link” 的 bootstrap-native production path。
以后即使把 LLVM、resource compiler、archiver、linker 或 C interop helper 接进来，
它们也必须继续长在同一份 typed plan 上，而不是重新退回 shell string。

当前仓库也已经补上了对应的 execution contract。`compiler/toolchain/np_toolchain_runner.pas`
现在可以真实执行 ready `TToolchainPlan`：它会顺序跑 `steps[]`、准备当前 step 的
working/output/sidecar 目录、物化 `response-file` / `resource-list-script` /
`archive-command-script`，并在成功后按 `delete-on-success` 清理 sidecar。
`tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
已用 fake `as` / `ld` 验证 `native-assemble-link` 两步 plan 的 object/output 产出、
response capture 与 cleanup lifecycle。
当前 `compiler/frontend/np_compilation_session.pas` 也已经把这套 runner 接回
当前 `bootstrap-native-assemble-link` production path：`ExecuteToolchain(...)` 现在直接复用
`ExecuteToolchainPlan(...)`，并把真实运行结果收成 `tool-run-status`、
`tool-run-step-count` 与 `primary-tool-run-status`，再由 `stage0` 同步投影到
line-based output 与 `command-envelope=<json>.result`。`command-envelope` 也开始
携带 camelCase 的 `toolRunStatus`、`toolRunStepCount` 与 `primaryToolRunStatus`，
`build/verify_local.sh` 的 success / semantic-smoke / toolchain-failure gate 也会确认
这些字段在成功、语义失败、宿主 compiler failure 等路径都被吐出来。

这里现在要守住的边界已经继续前进：production path 不仅已经切到 bootstrap-native
assemble/link，later-step failure attribution 也已经收口。当前
`compiler/backend/np_backend_plan.pas` 已经交付 `assembly-text`、`object-file` 与
`executable` 三类 artifact truth，并把 backend-owned `.o` 通过
`logicalLinkRequest.objectInputs` 交给 toolchain control plane；`PlanFromBackend`
也已经合法选择 `bootstrap-native-assemble-link`。当 failure 发生在
`native-assemble` 或 `native-link` 时，session-owned diagnostic / build trace / status
metadata 现在会跟着真实失败 step 走，而不再退回 `host-fpc-emit-asm`；
`build/verify_local.sh` 已用 fake `as` / `ld` 负路径冻结
`toolchain.assembler-exec-failed` 与 `toolchain.linker-exec-failed` 这两条 contract。
这条 limitation 现在也已经收口：success trace / status event 不再是
单步摘要，而是完整 multi-step transcript。现阶段要继续守住的是
`tool-status-event-count`、`tool-run-step-count` 与 `buildTrace.steps[*]` 都由真实 executed
steps 决定，额外 source-backed unit 会继续追加 step/event，而不是复用固定常量。

### `inputs` / `outputs` 的 artifact kind 不能退化成随手写的字符串

FPC 真源码已经说明，tool invocation 之间传递的东西不是“任意路径”这么简单：

- `assemble.pas` 关心的是 asm text 与 object file
- `comprsrc.pas` 关心的是 `.rc -> .res -> .o`
- `link.pas` 关心的是 object、static/shared library、最终 image

如果 `inputs` / `outputs` 的 `kind` 仍然允许到处发明字符串，后面实现时很快又会重新退回
“靠文件后缀猜语义”的旧路。

因此 nextPas 先推荐一组最小 artifact kinds：

- `assembly-text`
- `object-file`
- `static-library`
- `shared-library`
- `import-library`
- `resource-script`
- `binary-resource`
- `resource-object`
- `executable-image`
- `debug-symbol-bundle`

这组 kinds 当前只回答“步骤之间在传什么”，不回答这些内容：

- 不回答安装布局应该落到哪里
- 不回答 package ownership
- 不回答 target ABI 或 object format 细节
- 不把文件后缀本身升级成 canonical truth

也就是说，artifact kind 是 toolchain 内部 typed contract；路径和后缀只是它的物化形式。

### `sidecars` 也必须先冻结成有限 kind 集合

FPC 的 `link.pas` 和 `comprsrc.pas` 已经把 sidecar 的真实种类写得很清楚：

- `Info.ResName` 是 linker input list / response-style asset
- `Info.ScriptName` 是独立 link script asset
- `WriteSymbolOrderFile` 会单独生成 symbol order file
- `fScriptName` 会生成 resource list script，然后再以 `@file` 形式喂给资源编译器

这说明 sidecar 不是“某个临时文件”的泛称，而是一组有明确角色和生命周期的执行资产。

因此 nextPas 先推荐一组最小 sidecar kinds：

- `response-file`
- `linker-script`
- `symbol-order-file`
- `resource-list-script`
- `archive-command-script`
- `map-file`

每个 `sidecar` entry 至少要能表达：

- `kind`
- `path`
- `ownerStepId`
- `materializationTiming`
- `cleanupPolicy`

推荐的最小形状可以是：

```json
{
  "kind": "resource-list-script",
  "path": "app.reslst",
  "ownerStepId": "res-to-obj",
  "materializationTiming": "before-step-exec",
  "cleanupPolicy": "delete-on-success"
}
```

这条规则的意义很直接：

- 高性能，因为 sidecar 是否可复用、何时生成、何时清理可以被正式建模
- 优雅，因为 `response-file`、`linker-script`、`resource-list-script` 不再互相冒充
- 可留证，因为 diagnostics 和 replay 能指出失败的不是“某个临时文件”，而是某类正式 sidecar

同样重要的是，sidecar kinds 继续不属于 shared distribution metadata，也不属于 package truth。
它们是 execution-owned asset，不是公开发行协议。

## linker input set 必须在 toolchain 层分桶，而不是在 backend 里手拼

FPC `link.pas` 的 `TLinker` 不是只拿一串对象文件直接执行。它显式维护：

- `ObjectFiles`
- `SharedLibFiles`
- `StaticLibFiles`
- `FrameworkFiles`
- `OrderedSymbols`
- `AddImportSymbol` 这类 import-side request

这说明 final link 的复杂度来自输入分类和顺序控制，而不是来自某个 backend 恰好知道几条 flag。

因此 nextPas 继续冻结：

- linker-facing `ToolInvocationPlan` 至少要能分开 object input、shared library request、
  static library request、framework request、import symbol intent、ordered symbol intent
- C interop、runtime/bootstrap、package install result 与 backend emission 都可以贡献这类输入，
  但不能直接决定最终 argv 排列
- dynamic linker choice、library group/order policy、response file 与 link script strategy 继续由
  `LinkerProfile + Sysroot + TargetFacts` 共同决定
- 如果 future binding 走 `ld`、`gold`、`lld`、`clang` driver 或其他 tool flavor，这些差异也只在
  profile serialization 层出现，不反向污染上游 contract

这条边界直接决定 nextPas 后面能不能同时支撑 GNU-heavy、LLVM-heavy 和 cross-host toolchain，
而不把 link model 写成一堆 backend 私货。

## host 语义与 target 语义必须彻底分开

toolchain 设计最容易滑坡的地方，就是让“host 上怎么找到命令”污染“target 应该长成什么样”。

nextPas 明确要求：

- `HostFacts` 负责 executable discovery、path separator、process spawning、host path semantics
- `TargetFacts` 负责 ABI、object format、`Cprefix`、library naming、dynamic linker semantics
- `ToolchainBinding` 负责 host-to-target 的映射关系
- `ToolInvocationPlan` 负责一次具体执行

因此：

- 同一个 `TargetFacts` 可以被多个 host binding 复用
- 同一个 target 可以有 GNU toolchain binding，也可以有 LLVM-heavy binding
- developer-facing tools 不能用“当前机器 PATH 里有什么”反推 target semantics

这也是为什么 nextPas 当前虽然只支持 `linux-x86_64 -> linux-x86_64`，架构上仍然不能把
`host == target` 写死。

## sysroot-aware resolution 属于 toolchain control plane，不属于 linker 私货

`compiler/systems/t_linux.pas` 已经说明：library search、dynamic linker fallback、
cross-link script 乃至 `external 'c'` / `$linklib c` 的处理，都会受 sysroot 影响。

因此 nextPas 要求：

- `Sysroot` 是 toolchain 显式输入
- library search roots 先经过 sysroot，再进入 target-aware resolution
- dynamic linker selection 不能脱离 sysroot 单独猜测
- import library / shared library / runtime-required libc 都走同一条 resolution contract

这条边界的直接结果是：

- linker profile 只描述能力与参数模板
- 真正的 search root、dynamic linker path、runtime library path 由 binding + sysroot 解析得到
- toolchain diagnostics 必须能指出到底是 tool 缺失、sysroot 错误，还是 target/profile 不匹配

这样 cross compilation 与 local build 才是在一套统一控制面上工作，而不是两套偶然相似的脚本。

当前仓库里这条规则也已经开始进入 execution-side contract，而不再只停留在文档：

- 对 nextPas 自己直接拥有 linker argv 的 `native-assemble-link` 与
  `llvm-ir-opt-llc-link`，planner 现在会先把
  `logical-link-request.libraryRequests[]` 里的最小 `logicalId="c"` shared request
  解析到 `distribution-runtime-root`
  `lib/nextpas/runtime/<runtime-sdk>/libc.so`
- 解析成功后，真正进入 linker step 的是 typed step input
  `runtime-library-root` / `shared-library`，以及 argv 里的 `-L<runtime-root>` / `-lc`
- 解析失败时，plan 会在 runner 执行前直接以
  `toolchain.c-library-not-found` 失败，而不是把缺库问题拖到 later linker stderr
- 默认 `bootstrap-native-assemble-link` 当前仍然故意不接管宿主 FPC 生成的
  `*_link.res`，所以这份 direct-link contract 还不是“所有 production path 都已完全收口”

也就是说，nextPas 当前已经把 logical library request 真正接到了 direct-link execution 面，
但还没有假装所有 host-owned linking 细节都已经被统一 toolchain control plane 回收。

## response file、link script 和 sidecar assets 不是公开 IR

FPC `link.pas` 已经证明，复杂链接几乎一定会生成 link script、group statement、
ordered symbol file 或等价 sidecar 资产。nextPas 也必须承认这一点，但要把边界写清楚：

- response file、link script、resource temp file、ordered symbol file 都属于 toolchain sidecar asset
- 它们由 `ToolInvocationPlan` 派生，不由 backend 直接手写
- 它们用于执行和留证，不是公开稳定 IR
- 用户不应被迫维护这些临时文件来表达语言或 target 语义

这条规则非常重要。否则 toolchain 很快又会退化成“谁能先拼出一段 shell 或 linker script，
谁就暂时拥有架构主导权”。

## LLVM toolchain 只是 specialization，不是第二套真相源

FPC 的 `af_llvm`、`triplet_llvm`、`llvmdatalayout` 说明 LLVM 确实会进入 toolchain，
但 nextPas 仍然要求：

- LLVM triple / data layout 继续属于 `TargetFacts`
- LLVM executables 是否存在、从哪里发现、怎么调用，属于 `ToolchainBinding`
- LLVM backend 与 non-LLVM backend 都复用同一套 `ToolInvocationPlan`
- LLVM toolchain 失败继续进入同一套 diagnostics sink

因此，如果以后 binding 里出现 `opt`、`llc`、`lld`、`llvm-ar` 或 `clang` 这类工具，
它们也只是 tool profile 的 specialization，不会变成一套独立的 target registry 或
独立的 developer environment。

`link.pas` 里真的会 `FindUtil('clang'+llvmutilssuffix)`，而 `llvmdatalayout` 又继续留在
`TargetFacts` 一侧。这正说明 LLVM executable locator 和 LLVM target semantics 必须彻底分开。

因此 nextPas 也推荐一份最小 optional LLVM executable set skeleton：

```toml
[llvm_executable_set]
id = "llvm-stable"
tool_root_kind = "distribution-helper-root"
clang_driver = "clang"
llc = "llc"
opt = "opt"
lld = "ld.lld"
llvm_ar = "llvm-ar"
suffix_policy = "shared-llvmutilssuffix"
version_contract = "same-major-series"
```

这份 skeleton 当前只回答 role locator：

- `tool_root_kind` 回答这些工具是从 distribution helper root、host tool cache 或其他正式 root 解析
- `clang_driver`、`llc`、`opt`、`lld`、`llvm_ar` 回答每个 role 的逻辑 executable id
- `suffix_policy` 承认像 `llvmutilssuffix` 这样的 shared suffix 机制本来就是工具发现的一部分
- `version_contract` 回答这组 LLVM tools 必须保持怎样的一致版本关系

它继续明确不回答这些内容：

- 不回答 LLVM triple、data layout、relocation model 或 target CPU
- 不回答 sanitizer library search dir、sysroot path 或 runtime SDK root
- 不回答 final linker argv、`-target` 参数细节或 C library ordering
- 不把 LLVM executable set 变成第二套 target registry

## bundled toolchain payload 只能经由 `ToolchainBinding` 被发现

FPC 现有 build/install 结构已经说明两件事：

- `fpcmake.ini` 会从 `CROSSBINDIR` 推导 `RCPROG`、`ARPROG`、`NASMPROG` 这类 target-aware tools
- `FPCDIR`、`rtl`、installed units 与 library/layout 也是同一套环境事实的一部分

这说明 tool binary、SDK metadata、runtime support asset 本来就是环境控制面问题，不是 package
作者在 manifest 里顺手填几条路径就能替代的。

因此 nextPas 继续冻结：

- 如果发行物内含 bundled linker、archiver、resource helper、LLVM utility 或其他 toolchain-private
  executable，它们只能通过 `ToolchainBinding` 被解析
- package workflow、IDE、language service 与 automation 都只能消费 binding 的解析结果，
  不能各自绕开 binding 去猜某个私有 helper 的路径
- package publish/install 也不能把这些 toolchain executables 当成普通 package payload 直接改写
  到 target truth 里
- public command surface 与私有 toolchain payload 的落位继续由
  `distribution-layout-specification.md` 约束

换句话说，nextPas 可以分发完整的 LLVM-heavy 或 GNU-heavy toolchain bundle，但 bundle 进入系统后
仍然只是一组被 binding 组织起来的执行部件，不是第二套 package truth，也不是新的 public CLI。

## target runtime SDK 与 host toolchain bundle 不能互相冒充

FPC 现有结构其实已经把这两层拆出来了：

- `FPCDIR` / `rtl` / `units` 指向的是 target-facing runtime environment
- `CROSSBINDIR` / `RCPROG` / `ARPROG` / assembler discovery 指向的是 host-facing tool executables

nextPas 必须把这条边界继续写清：

- target runtime SDK 负责 units、runtime libraries、import libraries、target metadata 和等价
  runtime support asset
- host toolchain bundle 负责 assembler、linker、archiver、resource helper、LLVM utilities 和等价
  executable payload
- 同一个 target runtime SDK 可以在原则上被多个 host-specific `ToolchainBinding` 复用
- `ToolchainBinding + Sysroot` 负责把“这套 host tools”与“这套 target runtime assets”收敛成一次
  可执行 build environment
- package workflow 可以把 package install result 落进 SDK-facing layout，但不能把 runtime SDK
  或 toolchain bundle 退化成普通 package dependency

这条规则是 nextPas 想成为整套现代开发环境时非常关键的一步：

- compiler/kernel 不需要假装自己同时拥有 source package graph 和 host tool discovery
- package manager 不会反向吞掉 runtime/toolchain version management
- future IDE、`env` family 和 `doctor` 都能共享同一套 environment ownership

## environment materialization 也必须服从 `ToolchainBinding`

真实工具链最容易再次失控的地方，不在 backend，而在“环境准备”。

FPC 的 `fpcmkcfg/fppkg.cfg` 和 `fpcmake.ini` 已经说明：

- bootstrap/repository/install state 会长成一套独立 config truth
- `FPCDIR`、`CROSSBINDIR`、`INSTALL_*DIR`、`RCPROG`/`ARPROG`/`NASMPROG` 会继续在另一层被推导

如果 nextPas 不把这层设计写清，future 的 channel/bootstrap/tool install 很快又会长成另一套半隐式系统。

因此 nextPas 在 toolchain control plane 上继续冻结：

- `env` family 可以负责 channel selection、distribution metadata resolution、dist root materialization、
  runtime SDK sync 与 host toolchain bundle activation
- 但 `env` 不拥有 target facts，不重写 tool profile，也不绕开 `ToolchainBinding`
- `env` 的正式输出应是可被 command surface、IDE、CI 复用的 environment resolution result：
  例如 resolved `ToolchainBinding`、`Sysroot`、runtime SDK roots 与 distribution-local helper roots
- 一旦进入真正的 build/test/pkg/doc/query/doctor 执行，tool discovery、sysroot resolution、
  response-file policy 和 failure mapping 仍然只认 toolchain control plane

这条规则的目的，是把“环境被准备好”与“工具链如何执行”接成一条线，而不是两套世界观。

## diagnostics 和 status event 必须在这里分界

`diagnostics-specification.md` 已经把 `toolchain` 冻结成正式 `Phase`。这里进一步定义
toolchain 自己该产出什么，不该产出什么。

toolchain 正式负责的结果包括：

- tool discovery failure
- unsupported binding/profile failure
- assembler / linker / archiver / resource execution failure
- sysroot / library resolution failure
- distribution metadata resolution failure
- environment activation / materialization failure
- sidecar asset generation failure

toolchain 不应把以下内容伪装成 diagnostics：

- “正在使用哪个 assembler”
- “现在进入 linking”
- “正在写 response file”
- “当前 active channel 是什么”
- “当前 resolved binding / dist root / runtime SDK readiness 是什么”

这些属于 status event 或 build trace，不属于结构化错误。

toolchain diagnostics 至少要保留：

- tool/profile identity
- host id / target id
- resolved executable path if available
- relevant sysroot or search roots
- primary input or output artifact
- exit code and summarized stderr/stdout if available

这让 future test replay、CI 留证和 issue triage 都能看到真正失败在哪一层。

### status event 也需要一份最小 schema

FPC 的 `exec_i_assembling`、`exec_t_using_assembler`、`exec_i_linking`、
`exec_i_compilingresource`、`exec_i_closing_script` 已经说明：真实工具链一定会有进度事件。
nextPas 不否认这类需求，但要把它们从 diagnostics 里正式拆出去。

因此 nextPas 先推荐一份最小 `ToolchainStatusEvent` schema：

```json
{
  "eventKind": "toolchain.step-started",
  "sessionId": "build-20260323-001",
  "planId": "plan-7f3c",
  "bindingId": "linux-x86_64-to-linux-x86_64-gnu",
  "profileId": "gnu-ld",
  "stepId": "final-link",
  "toolRole": "linker",
  "logicalExecutable": "ld",
  "timestamp": "2026-03-23T12:34:56Z",
  "summary": "link step started"
}
```

第一阶段当前只推荐这几类 event kinds：

- `toolchain.binding-resolved`
- `toolchain.tool-selected`
- `toolchain.step-started`
- `toolchain.sidecar-materialized`
- `toolchain.step-finished`
- `toolchain.plan-finished`

当前仓库里的最小真实落点已经不再只是文档示意。`tools/stage0/nextpas.pas` 现在会把
完整 executed-step transcript 投影到：

- line-based `tool-status-events=<json>`
- `command-envelope=<json>` 顶层的 `toolStatusEvents`

对 `examples/smoke/hello.pas` 这条当前主三步 success path，真实 event 序列是：

- `toolchain.tool-selected` / `toolchain.step-started` / `toolchain.step-finished`
  for `host-fpc-emit-asm`
- `toolchain.tool-selected` / `toolchain.step-started` / `toolchain.step-finished`
  for `native-assemble`
- `toolchain.tool-selected` / `toolchain.step-started` / `toolchain.step-finished`
  for `native-link`
- `toolchain.plan-finished`

因此当前 `tool-status-event-count=10`。如果 execution plan 里还追加了
`native-assemble-<unit>`，每个额外 executed step 会继续多出 3 个 event，再进入
`plan-finished`。

当 execution failure 发生在 later step 时，这组 event 的 step metadata 也不会回退到
primary step：assembler/linker failure 会分别带上真实的 `native-assemble` /
`native-link`、对应的 `profileId` / `logicalExecutable`，同时继续引用同一条
plan-level `buildTraceRef=trace-<session-id>-toolchain-plan`。`build/verify_local.sh`
已用 fake `as` / `ld` 负路径冻结这条 contract。

也就是说，第一阶段最小可运行 baseline 现在已经不再只有 failure diagnostic，也开始拥有
可留证、可验证、可回放的完整 tool execution progress spine。

这类 status event 的边界必须很清楚：

- 它服务 CLI progress、IDE build panel、CI live log 和 automation monitor
- 它不携带 `Severity`
- 它不替代 `DiagnosticCode`
- 它不负责决定命令退出码
- 它不把 session 内偶然字符串输出升级成稳定协议

也就是说，status event 负责“现在发生了什么”，不是“这次失败该如何分类”。

### build trace 必须是留证对象，而不是滚动日志拼接

如果 status event 只是实时流，那么 replay、CI 留证和 harness 回放还需要一个更稳的执行记录面。
`ToolInvocationPlan` 已经是执行前的 plan；nextPas 还需要一份执行后的 trace。

因此 nextPas 先推荐一份最小 `ToolchainBuildTrace` skeleton：

```json
{
  "traceKind": "toolchain-build-trace",
  "sessionId": "build-20260323-001",
  "planId": "plan-7f3c",
  "bindingId": "linux-x86_64-to-linux-x86_64-gnu",
  "hostId": "linux-x86_64",
  "targetId": "linux-x86_64",
  "startedAt": "2026-03-23T12:34:56Z",
  "finishedAt": "2026-03-23T12:34:58Z",
  "result": "failed",
  "steps": [
    {
      "stepId": "final-link",
      "status": "failed",
      "logicalExecutable": "ld",
      "primaryOutputs": [{ "kind": "executable-image", "path": "hello" }],
      "sidecars": [{ "kind": "response-file", "path": "hello_link.res" }],
      "diagnosticRefs": ["diag-0042"]
    }
  ]
}
```

这份 trace 当前主要回答这些问题：

- 本次执行对应哪条 `ToolInvocationPlan`
- 每个 step 最终成功还是失败
- 哪些 artifact / sidecar 真正被物化
- 哪些 diagnostics 与该 step 相关
- harness、CI 和 issue replay 应该回放哪一组正式执行事实

当前仓库里的最小真实落点又进一步前进了一步：这份 trace 已经不只存在于 failure path，
而且 success/failure 都统一收敛到 plan-level locator。对当前 production path：

- success path 会产出
  `buildTraceRef=trace-<session-id>-toolchain-plan`
  与 `result=success`
- failure path 也会继续产出同一条 trace locator，但 `result=failed`，
  并只在真实失败 step 上通过 `diagnosticRefs=["diag-0001"]` 指回正式 diagnostic

这里的关键 contract 不是某个固定 trace 字面量，而是：

- 每次 build 都会生成新的 `sessionId`
- `planId` 与 `buildTraceRef` 由该 `sessionId` 派生
- 同一轮 output / envelope / trace / status event 之间必须保持 locator 一致

这条 baseline 现在已经覆盖 success/failure 两侧的完整 executed-step trace。也就是说，
`native-assemble` / `native-link` 一旦 failure，trace 会按真实失败 step 归位并让
`diagnosticRefs` 指回同一条正式 diagnostic；而 success path 也会把
`host-fpc-emit-asm -> native-assemble -> native-link` 全部写进 `buildTrace.steps[]`，
并继续在 `sidecars[*]` 上保留 `materialized` / `cleanupStatus` 这类执行 truth。

它继续明确不负责这些内容：

- 不替代 structured diagnostics sink
- 不替代 package lock、workspace truth 或 distribution metadata
- 不要求保存完整 stdout/stderr 原文作为主稳定表面
- 不把实时 status event 流直接原样当成 canonical replay object

换句话说，status event 是实时观察面，build trace 是执行留证面，diagnostic 则是失败分类面。
三者必须协作，但不能互相冒充。

## compiler kernel、tools、runtime 与 distribution 必须通过这层汇合

nextPas 既然是整套开发环境，就不能让各个顶层目录各说各话。

因此 toolchain control plane 必须成为这些目录的公共汇合点：

- `compiler/`
  - 产出 `MIR`、artifact intent 和 target-aware input set
- `tools/`
  - 暴露 developer-facing command surface，但不私自维护工具发现逻辑
- `tests/`
  - 通过 `harness` 重放同一套 build intent 和 diagnostics model
- `rtl/` / `packages/`
  - 作为 installed units、runtime libraries 或 package assets 进入 target-aware output layout
- `build/`
  - 承载 target specs、toolchain bindings、local verification 与 CI glue

这也是 nextPas 和“只有一个 compiler binary 的项目”最根本的区别：它要设计的是整套环境的
控制面，而不是只设计一段 codegen。

## `stage0`、`stage1` 与更高层环境如何接这份规范

- `stage0`
  - 先只承诺一个受控的 `nextpas build` 路径
  - 当前宿主由 FreePascal 托管
  - 但 `ToolchainBinding`、tool profiles、tool diagnostics 的对象边界必须先固定
- `stage1`
  - nextPas 逐步接管 compiler kernel 和更多 driver logic
  - `harness`、package/workspace 入口、更多 build verb 可以接到同一套 toolchain control plane
- `stage2`
  - 只有在 compiler、toolchain、runtime、distribution 与 diagnostics 都稳定后，
    才值得继续调查更完整的 formatter / language service / richer developer workflow

这条阶段关系的重点不是“以后也许会有很多工具”，而是“以后新增的工具都不能绕过同一套
target/toolchain/runtime truth”。

同理，future GUI asset pipeline、shader helpers 或 UI-sidecar tools 如果出现，也必须服从
这条规则，而不是变成架构例外。

## 第一阶段非目标

- 不把所有 future developer tools 现在就实现成一棵巨大 CLI
- 不把 package manager、formatter、LSP 的命令设计提前写成当前公开承诺
- 不让 backend、LLVM adapter、driver、harness 各自维护第二套工具发现逻辑
- 不把 response file 或 link script 暴露成公开稳定 IR
- 不把“当前机器能跑”误当成已经完成 toolchain architecture

第一阶段真正要交付的是：一套把 compiler kernel、assembler/linker/archiver/resource tool、
sysroot、distribution assets 和 developer-facing surfaces 串成同一控制面的现代工具链边界。
