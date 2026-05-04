# nextPas C 互操作与链接规范

用这份规范定义 nextPas 第一阶段之后要逐步收紧的 C interop 边界。它回答的不是
“能不能先随便 `external` 一下”，而是“calling convention、symbol naming、external import、
C library binding、sysroot library resolution 和 backend emission 应该如何被表达，
才能让 nextPas 的 C 接口既现代、优雅，又不靠历史隐式规则拼出来”。

这份文档和 `semantic-model-specification.md`、`backend-specification.md`、
`cross-compilation-specification.md` 一起工作。前者冻结语言语义，这里冻结 foreign ABI /
symbol / library contract。如果你要看 LLVM backend 怎样消费这些 contract，继续读
`llvm-backend-specification.md`。

## 先看 FPC 真源码如何把 C 接口分散在多层里

这份规范直接回应这些 FPC 真实源码事实：

- `compiler/globtype.pas`
  - `tproccalloption` 里直接有 `pocall_cdecl`、`pocall_cppdecl`、
    `pocall_sysv_abi_cdecl`、`pocall_ms_abi_cdecl`
  - `cstylearrayofconst` 说明 C-style calling convention 会影响参数模型
- `compiler/paramgr.pas`
  - `push_high_param` 明确对 `cdecl_pocalls` 走不同参数规则
- `compiler/pdecsub.pas`
  - `proc_get_importname` / `proc_set_mangledname` 根据 call option、`target_info.Cprefix`、
    `import_dll`、`import_name` 与 C++ mangling 决定外部符号名
- `compiler/pdecvar.pas`
  - `cvar`、`external`、`weakexternal`、DLL 名、`name`、`Cprefix`、
    `AddExternalImport` 共同决定 external variable 行为
- `compiler/link.pas`
  - `AddStaticCLibrary` / `AddSharedCLibrary` 单独处理 C library
- `compiler/systems/t_linux.pas`
  - `ModulesLinkToLibc` 会同时考虑 `external 'c' name 'foo'` 和 `$linklib c`
  - library search 与 sysroot/cross-link 行为是正式逻辑，不是临时 shell 参数

这些事实说明：C interop 不只是 parser directive，而是横跨 sema、ABI、linking 和 target facts
的一条正式边界。

## C interop 只冻结三条主轴

为了避免名词膨胀，nextPas 先只冻结三条主轴：

- calling convention
- symbol binding
- library binding

这三条分别回答：

- 调用时参数和返回值怎么过边界
- 最终导入/导出的外部名字是什么
- 这个外部符号应当从哪个库或哪类链接输入中解析

任何一个维度没有显式写清，C interop 都会重新退化成平台习惯。

## 当前 stage0 已经冻结的最小 C interop contract

当前仓库已经把第一条最小 foreign binding contract 真正接进 compiler spine，而不是只停在规范里：

- syntax / green tree / AST facade 已能识别最小 declaration shape：
  `procedure <id>; cdecl; external 'c' name '<symbol>';`
- sema 会把这条 declaration 收成 typed `foreign-procedure-binding`，并产出
  `logical library request = { logicalId: "c", linkageKind: "shared", strength: "strong" }`
- `stage0 build examples/smoke/external_cdecl_smoke.pas` 现在会把这条 contract 继续投影到
  `logical-link-request.libraryRequests[]`
- 如果 declaration 省略显式 `name '<symbol>'`，当前最小 baseline 会直接给出
  `sema.missing-external-symbol-name`

这条基线还没有进入完整 foreign call lowering、varargs、Cprefix 默认命名或 sysroot library
resolution；它只先冻结“显式 cdecl external declaration 必须在语义层变成正式 foreign binding /
logical library request”这条事实链。

## calling convention 必须在语义层就成为正式事实

nextPas 至少要能表达这些调用约定：

- `cdecl`
- `cppdecl`
- `sysv_abi_cdecl`
- `ms_abi_cdecl`

并且明确：

- 调用约定是 `Typed HIR` 事实，不是 backend 临时猜测
- 参数传递、结果传递、varargs 行为和 hidden parameter 规则都受 calling convention 影响
- backend 只消费 calling convention，不重新发明 calling convention
- 不同 target 对某些 calling convention 的支持面不同，这应由 `TargetFacts` 明确约束

这直接回应了 FPC `globtype.pas` 与 `paramgr.pas` 里今天真实存在的调用约定差异。

## `external name`、默认导出名与 `Cprefix` 必须分开

FPC `pdecsub.pas` 与 `pdecvar.pas` 已经说明，默认名字、显式 `name`、DLL/import 名、
`Cprefix` 和 C++ mangling 是不同层次的东西。

nextPas 第一阶段要求：

- Pascal declaration name 不等于最终 foreign symbol name
- 显式 `external name` 优先于默认生成规则
- 默认 symbol naming 由 calling convention + target facts 决定
- `Cprefix` 属于 `TargetFacts`，不属于 parser 细节
- C++ mangling 是独立策略，不能和 plain `cdecl` 混为一谈

这条规则挡住的就是“在某个 backend 里顺手给名字加个前缀”的历史写法。

## external procedure 与 external variable 必须复用同一套 binding 逻辑

nextPas 不允许 procedure 和 variable 各自维护一套完全不同的 foreign binding 语义。

至少要统一这些点：

- foreign symbol name
- optional import library
- weak / strong import
- visibility / export intent
- target-specific prefix/suffix normalization

这直接回应 FPC 里 procedure 侧的 `proc_get_importname` 与 variable 侧的 `AddExternalImport`
目前分散实现的现状。

## library binding 必须区分逻辑库名与物理文件名

FPC `t_linux.pas` 已经暴露出一个关键事实：

- `external 'c' name 'foo'` 带来的是带前后缀的 import library 语义
- `$linklib c` 带来的是逻辑库名
- linker 最终还要做 prefix/extension stripping 与 search path 解析

因此 nextPas 要求：

- library binding 先记录 logical library id
- physical soname / archive filename 是 target facts + sysroot resolution 的结果
- raw filename import 只能作为显式特例，不能替代 logical library binding
- shared/static/object/framework 等 input kind 必须显式区分

这让 `libc.so`、`c`、`libpango-1.0.so.0` 这类不同层次的名字不再互相污染。

## C interop 只能产出逻辑 link request，不能直接产出 raw linker args

FPC 的 `proc_get_importname`、`AddExternalImport`、`AddStaticCLibrary`、`AddSharedCLibrary`
已经说明，foreign declaration 最终确实会影响 linking；但影响方式不是“解析器顺手拼一段 linker
命令”。

因此 nextPas 继续冻结：

- `external name`、optional import library、`$linklib` 与 weak import 只产出 interop contract
  里的 symbol / library request
- C interop 可以表达 logical library id、shared/static/import intent、weak/strong import intent，
  但不直接表达 host tool executable、search path flag 或 raw argv fragment
- `-lfoo`、full soname、import library filename、framework-style input、ordered symbol sidecar
  这些 linker-facing serialization 继续属于 `ToolchainBinding + LinkerProfile + Sysroot`
- backend 只消费已经冻结的 interop contract；toolchain 再把这些 contract 和 target/runtime/link
  环境一起收敛成真正 invocation

这样 `cdecl`、`external`、`cvar`、`$linklib` 与 cross-link/sysroot 之间的关系才是可组合的，
而不是谁先拿到字符串谁就先决定链接行为。

当前仓库里的最小 execution-side reality 也已经开始对齐这条边界：

- `procedure <id>; cdecl; external 'c' name '<symbol>';` 现在仍只会先产出
  `logical-link-request.libraryRequests[]`
- 但对 nextPas 自己直接拥有 linker argv 的两条 plan family
  `native-assemble-link` 与 `llvm-ir-opt-llc-link`，toolchain planner 现在会把
  `{logicalId:"c", linkageKind:"shared", strength:"strong"}` 解析成 repo-local
  `distribution-runtime-root`
  `lib/nextpas/runtime/<runtime-sdk>/libc.so`
- 解析成功后，真正进入 linker argv 的仍然是 toolchain side 的 `-L<runtime-root>` 与 `-lc`
  serialization，而不是 semantic/backend 直接写 raw args
- 解析失败时会在 planning 阶段直接产出 `toolchain.c-library-not-found`

这条最小 contract 仍然故意没有接管默认 `bootstrap-native-assemble-link` 里宿主 FPC 生成的
`*_link.res`；那条默认路径里的 host-owned `SEARCH_DIR(...)` / `GROUP(-lc)` 继续留在下一批
单独收口。

## sysroot library resolution 必须服从 target，而不是服从 host

只要涉及 C library，cross compilation 就不能回避。

nextPas 第一阶段明确：

- library search 先走 `Sysroot`
- library prefix / suffix 规则来自 `TargetFacts`
- host 默认 `/usr/lib` 之类路径不能隐式覆盖 target sysroot
- `external 'c'`、`$linklib c`、runtime-required libc 都必须走同一套 target-aware resolution

这条规则直接回应 FPC `t_linux.pas` 里 `sysrootpath` 和 `ModulesLinkToLibc` 的真实逻辑。

## C varargs 不是语法糖，而是 ABI contract

既然 FPC 已经用 `cstylearrayofconst` 和 `cdecl_pocalls` 把这件事写成正式逻辑，
nextPas 也必须把 varargs 当成 ABI 主题。

第一阶段要求：

- varargs 只能出现在明确允许的 calling convention 上
- `array of const` 风格桥接是 ABI 相关行为，不属于 parser 小功能
- backend 不能在不知道 calling convention 的情况下尝试生成 varargs call
- 如果某个 target/backend 不支持该 varargs 模式，必须给出结构化 diagnostics

## backend 与 LLVM backend 只能消费同一套 C interop contract

无论最终走 native backend 还是 LLVM backend，nextPas 都要求：

- calling convention 来自 `Typed HIR`
- symbol binding 来自 interop contract
- library binding 来自 target-aware link model
- backend 只把这些 contract 映射到各自的 emission 形式

这保证 C interop 不是某个 backend 的私货能力。

## diagnostics 必须覆盖 ABI、symbol 与 library 三类失败

至少要稳定这些失败类别：

- `sema.unsupported-calling-convention-for-target`
- `sema.invalid-varargs-usage`
- `sema.missing-external-symbol-name`
- `backend.external-symbol-emission-failed`
- `toolchain.c-library-not-found`
- `toolchain.import-library-resolution-failed`
- `toolchain.weak-external-not-supported`

每条这类诊断至少要保留：

- relevant declaration
- requested calling convention
- target id
- logical library id or explicit library name
- resolved or unresolved external symbol

## `stage0`、`stage1` 与 `stage2` 如何接这条边界

- `stage0`
  - 先冻结 calling convention、symbol binding 和 library binding 的文档边界
  - 允许真实实现仍主要依赖宿主工具链
- `stage1`
  - nextPas 开始接管更正式的 foreign ABI lowering、C library resolution diagnostics
  - LLVM backend 与 native backend 共用同一套 interop contract
- `stage2`
  - 只有当 cross compilation、backend contract 和 runtime contract 都稳定后，
    才值得继续扩大 C interop 支持面

## 第一阶段非目标

- 不做自动 C header importer 或 bindgen 系统
- 不承诺完整 C++ ABI 兼容矩阵
- 不把 ABI compatibility 写成当前硬承诺
- 不让不同 backend 各自偷偷维护一套 external/import/link 规则
- 不把 sysroot / target-aware link search 退化成 host 上“能找到库就算成功”

第一阶段真正要交付的是：一套把 calling convention、symbol naming、library binding 与
target-aware linking 正式写成编译器事实的 C interop 规范。
