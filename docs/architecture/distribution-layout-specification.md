# nextPas 发行布局规范

用这份文档定义 nextPas 第一阶段发行物的逻辑布局。它先把“公开交付给使用者的目录
应该长什么样”说清楚，再把这个布局与 `stage0`、本地验证和 Linux CI 绑定起来。

这是一份发行规范，不等于当前已经实现了完整安装器。第一阶段先冻结布局语义，
后续任务再把构建与打包路径接上。如果你要看 future package install workflow 怎样把
manifest、lock、cache root 和 install root 接到这份布局上，继续读
`package-workflow-specification.md`。
如果你要看 GUI render-side helpers、shader pack、font atlas 和 preview asset 应该怎样落位，
继续读 `render-asset-pipeline-specification.md`。

## 第一阶段只定义 Linux x86_64 的发行形状

和其余架构文档一样，这份发行布局只对 Linux x86_64 生效。第一阶段不引入
Windows/macOS 的并行目录分支，也不把多平台安装差异提前写成当前基线义务。

## 必须显式可见的四类路径

无论最终打包脚本如何组织版本号或暂存目录，nextPas 的公开发行物都必须显式暴露
以下四类路径：`bin/`、`lib/`、`units/<target>/` 和 `share/`。

| 路径              | 第一阶段职责                                                                        | 说明                                                  |
| ----------------- | ----------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `bin/`            | 放置公开命令行入口，如 `nextpas`                                                    | 命令表面必须一眼可见，不能把可执行入口藏进私有子目录  |
| `lib/`            | 放置目标无关的运行时支持资产、私有辅助库、bundled toolchain helpers 和版本化元数据  | 允许后续引入版本子目录，但公开语义必须继续保留 `lib/` |
| `units/<target>/` | 放置目标相关的已安装 units 与编译产物                                               | 第一阶段唯一合法目标是 `units/linux-x86_64/`          |
| `share/`          | 放置文档、样例、许可证、目标说明副本与 target/toolchain metadata 等非可执行共享资产 | 这类内容不能混入 `bin/` 或 `units/<target>/`          |

一个符合当前设计的发行根目录示意如下：

```text
<dist-root>/
├── bin/
│   └── nextpas
├── lib/
│   └── nextpas/
├── units/
│   └── linux-x86_64/
└── share/
    └── docs/
```

这里的示意强调“目录角色”，而不是抢先承诺最终版本号编码或安装器参数格式。

## bundled toolchain executables 不应挤进公开 `bin/`

如果 nextPas 未来打包自己的 linker wrapper、`lld`、`llvm-ar`、resource helper 或其他
backend-private executable，它们也不该和公开命令入口混在一起。

因此发行布局继续冻结：

- 顶层 `bin/` 只暴露稳定 user-facing command，例如 `nextpas`
- bundled toolchain executable、private wrapper、sidecar generator 或 target-private helper
  应进入 `lib/nextpas/toolchains/<binding>/bin/` 或等价私有 `lib/` 子树
- target specs、toolchain metadata、license notices、response-file template 或等价共享说明
  应进入 `share/nextpas/toolchains/`、`share/nextpas/targets/` 或等价共享 `share/` 子树
- `ToolchainBinding` 负责解析这些私有资产；CLI、IDE、package workflow 都不应直接假定某个
  helper 在用户 PATH 里可见

一个更完整但仍然保持四类公开路径的示意如下：

```text
<dist-root>/
├── bin/
│   └── nextpas
├── lib/
│   └── nextpas/
│       └── toolchains/
│           └── linux-x86_64-gnu/
│               ├── bin/
│               └── lib/
├── units/
│   └── linux-x86_64/
└── share/
    └── nextpas/
        ├── docs/
        ├── targets/
        └── toolchains/
```

这条规则直接回应 FPC 里 `CROSSBINDIR`、`RCPROG`、`ARPROG` 这类 target-specific tool discovery 事实，
但把它收进更清楚的现代分层：public command surface 和 private toolchain payload 必须是两层。

## target runtime SDK 也必须继续落回这四类公开路径

如果 nextPas 未来分发自己的 target runtime SDK，它也不能绕开已经冻结的公开布局。

FPC 的 `fpcmake.ini` 已经把这件事写得很具体：

- `INSTALL_UNITDIR` 负责已安装 units 与 `Package.fpc`
- `INSTALL_LIBDIR` 负责 shared library 或等价 runtime library
- `INSTALL_DATADIR`、`INSTALL_DOCDIR`、`INSTALL_EXAMPLEDIR` 负责 shared data、docs 和 examples
- `fpc_sourceinstall` / `fpc_zipsourceinstall` 又说明 source snapshot 是另一类分发物

因此 nextPas 继续冻结：

- target runtime SDK 的 public units 继续落在 `units/<target>/`
- target-private runtime libraries、import libraries、support archives 或等价 helper payload
  继续落在 `lib/nextpas/runtime/<target>/` 或等价私有 `lib/` 子树
- target-facing docs、examples、metadata、license notices 与 equivalent shared runtime assets
  继续落在 `share/nextpas/runtime/<target>/` 或等价共享 `share/` 子树
- source package release 不反向挤进 installed SDK layout；registry/publish truth 和 installed SDK
  truth 仍是两层
- runtime SDK 可以跟某个 compiler/toolchain 发行物一起打包，也可以独立分发，但公开路径语义不变

一个更贴近长期环境形状的示意如下：

```text
<dist-root>/
├── bin/
│   └── nextpas
├── lib/
│   └── nextpas/
│       ├── runtime/
│       │   └── linux-x86_64/
│       └── toolchains/
├── units/
│   └── linux-x86_64/
└── share/
    └── nextpas/
        ├── runtime/
        │   └── linux-x86_64/
        ├── targets/
        └── toolchains/
```

这条规则让 nextPas 后续即使长出自己的 runtime SDK、GUI runtime assets、LLVM-heavy toolchain bundle，
也仍然是在同一套公开布局里扩展，而不是重新发明另一棵发行树。

## channel / distribution metadata 必须是 shared metadata，不是隐式脚本状态

如果 `env bootstrap`、`env sync`、`env use` 以后真的要稳定工作，它们就必须有一份正式的
distribution metadata contract 可以消费。否则环境准备迟早又会退化成“脚本里顺手猜几个路径”。

FPC 的 `fppkg.cfg`、mirror list、repository selection、`fpcmake.ini` 里的 `FPCDIR` /
`CROSSBINDIR` / `INSTALL_*DIR` 推导已经说明：一旦环境 metadata 没有正式归属，路径、channel、
repository 和 install state 就会分散在不同地方。

因此 nextPas 在发行布局上继续冻结：

- channel identity、distribution release identity、host compatibility、available `ToolchainBinding` set、
  bundled runtime SDK target set、content digest 与等价 shared metadata 必须进入 `share/nextpas/`
  管理的共享 metadata 子树
- 这些 metadata 可以被 `env` family、IDE、CI 与 automation 共同读取，但不能混进顶层 `bin/`
  或私有 helper script 参数
- shared metadata 只回答“这份 distribution 里有什么、适用于谁、能解析出哪些 binding/runtime 组合”
- shared metadata 不回答 workspace membership、package dependency graph、user-local cache state、
  host-private override path 或 shell session 偶然状态

换句话说，distribution metadata 负责把发行物写清楚，不负责替 workspace、package workflow 或
用户 shell 保存第二份世界观。

## shared distribution metadata 也需要一份最小 skeleton

如果前面只说“metadata 很重要”，但不说明最小形状，后面实现时还是会重新退回脚本里散着几段
channel、binding、runtime SDK 路径猜测。

因此 nextPas 先推荐一份最小 shared metadata skeleton：

```toml
[distribution]
channel = "stable"
release = "0.1.0-dev.3"
host = "linux-x86_64"
layout_version = 1
digest = "sha256:3d4e..."

[[bindings]]
id = "linux-x86_64-to-linux-x86_64-gnu"
target = "linux-x86_64"
backend_family = "native"
binding_spec = "share/nextpas/toolchains/linux-x86_64-to-linux-x86_64-gnu.toml"
helper_bin_root = "lib/nextpas/toolchains/linux-x86_64-gnu/bin"
helper_lib_root = "lib/nextpas/toolchains/linux-x86_64-gnu/lib"
runtime_sdk = "linux-x86_64"

[[runtime_sdks]]
id = "linux-x86_64"
target = "linux-x86_64"
units_root = "units/linux-x86_64"
runtime_lib_root = "lib/nextpas/runtime/linux-x86_64"
runtime_share_root = "share/nextpas/runtime/linux-x86_64"
sysroot_mode = "bundled"
```

这份 skeleton 当前先回答这些问题：

- `[distribution]` 回答 channel、release、host compatibility、layout version 和整体 digest
- `[[bindings]]` 回答这份发行物提供哪些 `ToolchainBinding`、每条 binding 对应哪个 shared binding spec，
  以及 helper roots / runtime SDK selector 在发行树里的逻辑位置
- `[[runtime_sdks]]` 回答这份发行物提供哪些 target runtime SDK，以及它们映射到
  `units/<target>/`、`lib/nextpas/runtime/<target>/`、`share/nextpas/runtime/<target>/` 的方式

它同样继续明确不回答这些内容：

- 不回答 user-level active selection、workspace-local override、archive cache、activation scratch state
- 不回答 package dependency graph、manifest truth 或 lockfile snapshot
- 不把 `ld`、`lld`、`clang`、`llvm-ar` 的最终 resolved executable path 写成 machine-local absolute path
- 不替代 `build/toolchains/<host>-to-<target>.toml` 去定义 profile policy 本身

如果某条 `[[bindings]]` 依赖共享 LLVM helper set，它可以额外挂
`llvm_executable_set = "llvm-stable"`。这个字段继续只引用 shared metadata 中的逻辑 set id，
不能写 machine-local resolved path，也不复制 triple、data layout 或最终 linker argv。

也就是说，shared distribution metadata 负责回答“发行物里有哪些可解析对象和公开 locator”；
binding policy 继续留给 `build/toolchains/*.toml`，machine-local activation 则继续留给 `env`
sidecar。

## `env` 物化后的结果可以是本地状态，但 canonical truth 仍来自 shared metadata

现代环境管理当然会产生 machine-local activation state，但 nextPas 仍然要把 canonical truth 守住。

因此：

- active channel、selected distribution release、resolved dist root、activated binding 与 runtime SDK
  readiness 可以作为 machine-local environment state 存在
- 但这些状态必须是从 shared distribution metadata 解析出来的结果，而不是另一份独立 registry
- `env use` 改写的是本地选择结果，`env sync` 刷新的是本地 resolution / materialization 结果；二者都不改写发行物自带的 metadata truth
- 一旦发行物升级或 channel 切换，新的 canonical truth 仍由新 metadata 提供，再由 `env` 重新解析

这条边界能保证 nextPas 的环境控制面既现代、可更新，又不失去可解释性。

## 发行布局与仓库结构不是同一回事

目录结构规范定义的是源代码与验证资产怎么组织，发行布局定义的是构建完成后
要对外暴露什么。两者必须对应，但不能混为一谈。

- `tools/stage0/nextpas.pas` 属于仓库中的驱动入口来源；发行后它的公开命令表面
  归入 `bin/`。
- `build/targets/linux-x86_64.toml` 属于仓库中的目标平台规格；发行后相关目标约束
  可以复制或映射到 `share/` 或 `lib/` 管理的资产中。
- `build/toolchains/<host>-to-<target>.toml` 属于仓库中的 binding policy 规格；发行后相关 shared
  binding metadata 应复制或映射到 `share/nextpas/toolchains/` 管理的资产中。
- `rtl/` 与未来包兼容工作的安装结果，必须以 `units/<target>/` 的形式显式落地。
- package workflow 的 installed package result 也必须继续服从 `units/<target>`、`lib/`
  和 `share/` 的公开语义，而不是临时目录约定。
- future bundled LLVM/binutils/resource helpers 如果进入发行物，也只能作为私有 toolchain payload
  落在 `lib/` / `share/` 的公开语义之下，不能反客为主重新定义顶层目录。
- future GUI public units 也必须继续走 `units/<target>/`，而 GUI shared assets / docs /
  themes 与私有 runtime helpers 应分别落到 `share/` / `lib/` 的公开语义中。

如果某项资产既不能解释它属于仓库结构哪一层，也不能解释它为什么出现在发行树里，
说明边界还没有被设计清楚。

## 这份布局必须被本地验证和 CI 共同约束

`stage0` 的 `promotion gate` 不只检查能不能构建，也检查发行语义是否清楚。
因此后续的 `build/verify_local.sh` 与 Linux CI 必须共享同一套最小假设：

- 所有关键架构文档存在，并且没有互相矛盾。
- `stage0` 驱动入口可以在 Linux x86_64 上构建。
- smoke `harness` 路径可以跑通。
- 发行布局至少在逻辑上能映射到 `bin/`、`lib/`、`units/<target>/` 和 `share/`。

这条约束的意义，是避免出现“仓库能勉强构建，但没有公开发行形状”的半成品状态。

## 交叉编译不改变公开 layout key

即使未来引入 cross compilation，公开发行布局也必须继续以 target 为主键，而不是以 host 为主键。

因此：

- `units/<target>/` 继续表达目标安装结果
- host-specific toolchain 辅助物属于 build/control plane，不属于公开发行树
- 同一个 host 为多个 target 生产产物时，公开结果仍按 target 分区

更细的 host/target/toolchain/sysroot 规则由 `cross-compilation-specification.md` 定义。

## `stage0`、`stage1` 与 `stage2` 如何继承这份布局

- `stage0`：先冻结公开布局，让 FreePascal 托管的构建路径也遵守同一套发行语义。
- `stage1`：允许 nextPas 自己产出更多编译器与运行时资产，但不能突然改变顶层布局。
- `stage2`：即使进入可选的自托管调查，也必须保留可回退的公开发行形状。

阶段推进可以改变“谁来生产这些文件”，但不应该把已经公开的发行路径再次隐藏起来。

## 第一阶段非目标

这份发行布局刻意不承诺以下内容：

- 不在第一阶段同时发布多个目标平台目录。
- 不把安装器、包管理器或 IDE 集成写成发行布局的前提。
- 不让 `units/<target>/` 退回隐式的内部约定。
- 不把二进制稳定性说成既成事实，`ABI compatibility is deferred`。

第一阶段要得到的是“清楚、可验证、可回退的发行布局”，而不是一个尚未实现却
不断扩张的打包愿景。
