# nextPas FPC 源码映射规范

用这份规范把 nextPas 的现代化设计和真实 FPC 源码建立明确映射。它回答的不是
“nextPas 要不要照抄 FPC”，而是“FPC 的真实 compiler/rtl 里哪些职责现在耦合在一起，
这些耦合点暴露了什么能力需求，nextPas 应该保留哪些能力、拆开什么边界、避免哪些历史结构”。

这份文档的目的，是挡住两种同样糟糕的做法：

- 只凭抽象架构术语空谈 modern compiler
- 看到 FPC 现有结构后直接逐文件复制

## 先把当前使用的本地 FPC 源树写清

当前 nextPas 文档明确使用这份真实源码树作为 FPC 兼容性基线与架构取证来源：

| 路径                         | 当前角色                                            |
| ---------------------------- | --------------------------------------------------- |
| `/home/dtamade/projects/fpc` | phase1 兼容性基线，同时也是当前架构取证与设计参考树 |

这条基线的意义很直接：

- 架构规范引用的 FPC 事实必须能回到这份真实源码树
- 后续 compiler、toolchain、package、IDE 设计不能脱离这份源码观察来空想
- ADR、架构规范和实施文档对 FPC 参考树的口径应保持一致

## 先看 FPC 真源码暴露了哪些高耦合热点

下面这些文件不是“顺手看一眼”，而是 nextPas 设计必须正面回应的真实耦合点：

| FPC 源文件                                    | 当前真实职责                                                           | 对 nextPas 的设计含义                                                                  |
| --------------------------------------------- | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `compiler/compiler.pas`                       | 编译器入口、`InitSystems`、全局初始化、驱动总控                        | nextPas 需要显式 `CompilationSession` 和可组合 driver，而不是全局初始化拼装            |
| `compiler/systems.pas`                        | 目标 OS/系统信息事实中心                                               | nextPas 的 target facts 外置方向是对的，但必须保留单点事实源                           |
| `compiler/fmodule.pas`                        | `tmodule` 同时承载 unit 状态、依赖、symtable、link 资产、SCC           | nextPas 必须把 module ownership 拆成 unit resolver、semantic state、link metadata 三层 |
| `compiler/fppu.pas`                           | `tppumodule` 同时负责 search/load/reload/PPU 持久化/deref              | nextPas 必须把 unit resolution 和 compiled artifact persistence 分开                   |
| `compiler/pmodules.pas`                       | `registerunit -> adddependency -> loadppu -> push symtable` 串在一起   | nextPas 必须把 parse/load/use graph 拆成显式 pipeline，而不是副作用串接                |
| `compiler/symtable.pas`                       | symbol table 同时处理 duplicate、PPU IO、deref、`needs_init_final`     | nextPas 不能让 symbol graph 继续背负 persistence 和 runtime-init 判定杂务              |
| `compiler/symdef.pas` + `compiler/symsym.pas` | type/symbol 定义与 PPU、target、RTTI、generic 细节深度纠缠             | nextPas 需要 canonical type graph + symbol graph，而不是历史类层次复制                 |
| `compiler/htypechk.pas`                       | overload resolution、operator acceptance、candidate ranking 的核心引擎 | nextPas 必须把 overload resolution 视为一等 subsystem，而不是若干 if/else              |
| `compiler/constexp.pas`                       | 用 `Tconstexprint` 处理常量整数求值边界                                | nextPas 需要正式 constant representation，而不是把常量求值塞给 backend                 |

## 这些真实源码说明 nextPas 应该保留什么

虽然 nextPas 不应该复制 FPC 文件结构，但这些能力不能丢：

- 有正式的 unit 依赖模型，而不是只有文件查找习惯
- 有正式的 symbol / type 体系，而不是只靠 AST 注解
- 有单独的 overload resolution 机制，而不是调用点零散打分
- 有单独的 constant evaluation 表示，而不是把常量求值混进 codegen
- 有单点 target facts，而不是每个阶段自推导平台规则
- 有 init/final 与 runtime helper 的显式前提，而不是让 runtime 猜

换句话说，nextPas 不应该保留 FPC 的历史组织方式，但必须保留它已经证明必要的 compiler capabilities。

## nextPas 应该拆开的边界，不再沿用 FPC 的历史揉合法

根据上面的真实源码观察，nextPas 至少要把这些职责分开：

- `UnitResolver`
  - 负责 `UnitId`、search path、`UnitGraph`、cycle diagnostics、installed unit roots
- `SemanticModel`
  - 负责 symbol graph、type graph、constant evaluation、overload resolution、`Typed HIR`
- `RuntimeBootstrapPlan`
  - 负责从语义层导出 init/fini、halt、runtime helper 需求
- `ArtifactPersistence`
  - 负责未来 compiled unit metadata 或 cache artifact，不反向污染 semantic model
- `TargetFacts`
  - 负责 `linux-x86_64` 的单点平台事实

这几层在 FPC 源码里今天并没有被完全拆开，这正是 nextPas 需要现代化重构的空间。

## 新编译器推荐骨架要直接回应这些源码事实

基于 FPC 真实源码，nextPas 推荐的更现代骨架不是凭空命名，而是有针对性的拆耦：

```text
Source database
  -> UnitResolver
  -> Green CST / AST facade
  -> SemanticModel
  -> Typed HIR
  -> RuntimeBootstrapPlan
  -> MIR
  -> Codegen adapter
  -> Target-aware output path
```

其中：

- `UnitResolver` 对应 FPC 里今天分散在 `fmodule.pas`、`fppu.pas`、`pmodules.pas` 的解析与依赖职责
- `SemanticModel` 对应 FPC 里今天分散在 `symtable.pas`、`symdef.pas`、`symsym.pas`、`htypechk.pas`、
  `constexp.pas` 的语义职责
- `RuntimeBootstrapPlan` 对应 FPC 里今天散落在 `pmodules.pas`、`symtable.pas` 和 runtime side 的
  init/final 相关前提

## 这份映射真正约束什么

- 后续 nextPas 设计文档必须能说明：它解决的是 FPC 真源码里的哪类耦合，而不是只给出空洞口号。
- 如果某份新文档引入了一个全新层次或对象，必须能说明它替代了 FPC 里的哪类混杂职责。
- 如果某个 nextPas 设计选择无法在 FPC 真源码中找到它要解决的问题来源，就要怀疑这是不是在发明无用复杂度。

## 第一阶段非目标

- 不把 `/home/dtamade/projects/fpc` 当前 checkout 自动宣告为新的兼容性基线。
- 不把 FPC 每个 Pascal 单元都逐个翻译成 nextPas 的同名模块。
- 不因为 FPC 里存在历史耦合，就把 nextPas 也设计成同样的耦合。
- 不把“参考真源码”误解成“放弃现代化重构”。

第一阶段真正要交付的是：一套既尊重 FPC 真源码现实，又敢于把历史耦合拆成现代边界的编译器设计。
