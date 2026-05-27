# nextPas 语义模型规范

用这份规范定义 nextPas 第一阶段之后要逐步收紧的语义模型边界。它回答的不是
“`sema/` 目录里以后会放哪些文件”，而是“符号、作用域、类型、常量求值、重载解析、
内建语义与 `Typed HIR` 应该以什么形式被表达，哪些事实必须在语义层冻结，哪些内容
不允许继续散落在 driver、backend 或 runtime glue code 里”。

这份文档承接 `compiler-specification.md` 对 `sema` 的职责定义，也细化
`compiler-pipeline-specification.md` 中对 `Typed HIR` 的要求。如果你要看运行时如何消费
这里产出的显式语义点，继续读 `runtime-bootstrap-specification.md`。如果你要看这些语义事实
依赖的 `UnitGraph`、unit identity 和 search path 从哪里来，继续读 `unit-resolution-specification.md`。
如果你要看语义失败如何进入稳定 diagnostics sink，继续读 `diagnostics-specification.md`。
如果你要看这些语义事实怎样进入 shared analysis、hover、rename、references 和 diagnostics
streaming，继续读 `language-service-specification.md`。
如果你要看 `Typed HIR` 之后哪些事实允许继续下沉到 `MIR` 与 backend，继续读
`backend-specification.md`。如果你要看这份设计具体在拆 FPC 哪些真实源码耦合，继续读
`fpc-source-grounding-specification.md`。

## 先用 FPC 真源码校准问题，而不是先发明答案

这份语义模型不是凭空命名出来的，它直接回应这些真实 FPC compiler 单元：

- `compiler/symtable.pas`：symbol table 今天同时承担 duplicate、deref、PPU IO 和
  `needs_init_final` 分析
- `compiler/symdef.pas`：definitions 体系同时依赖 `constexp`、`node`、target/platform 和
  PPU 细节
- `compiler/symsym.pas`：symbols 体系中 `tprocsym` 直接背负 overload declaration list
- `compiler/htypechk.pas`：`tcallcandidates` 是一整套真实的 overload resolution engine
- `compiler/constexp.pas`：FPC 专门用 `Tconstexprint` 处理常量整数求值边界

nextPas 的目标不是否认这些能力，而是把这些已经被证明必要的能力，从历史类层次和
持久化耦合里拆出来，收敛成独立、可缓存、可 lowering 的 semantic core。

## 把 `sema` 写成编译器核心，而不是后处理步骤

nextPas 的现代化、高性能、优雅，不会来自“先 parse，再在各处补一点语义判断”。
真正的收敛点必须是语义模型本身。

因此，第一阶段先冻结这些原则：

- `sema` 负责把语法世界变成可执行、可诊断、可 lowering 的语义世界。
- `sema` 不回写 AST，也不依赖 backend 重做类型或名字判断。
- `Typed HIR` 是语义层的主要产物，而不是临时过渡结构。
- runtime 只执行已经被语义层明确表达的语义点，不补做语言判断。
- diagnostics 必须直接由语义模型产出稳定分类，而不是把失败留给命令行字符串拼装。

## 把语义层的产物固定成三类数据

nextPas 推荐把语义分析结果收敛成三类核心产物：

| 产物         | 作用                                                             | 为什么必须独立存在                                                 |
| ------------ | ---------------------------------------------------------------- | ------------------------------------------------------------------ |
| symbol graph | 表达声明、定义、导出、引用和重载集合                             | 避免名字绑定继续依赖原始字符串查找                                 |
| type graph   | 表达 canonical type、alias、composite type 与 callable signature | 避免每个阶段各自复制一套类型判断                                   |
| binding table | 表达 source occurrence 到 semantic symbol 的绑定                 | 让 language service / query / IDE 不用重扫源码或自建名字解析        |
| `Typed HIR`  | 表达已经绑定且带类型的语义节点                                   | 让 lowering 和 runtime handshake 消费显式语义，而不是消费 AST 惯性 |

这三者可以共享 arena、interner 和会话缓存，但不应该重新退化成“有一棵 AST，剩下靠注释和 side table”。

## 当前 Batch 6 已经落下的最小真实骨架

第一阶段现在不是只在空谈 `Typed HIR`。当前仓库里，`Batch 6` 已经把最小 semantic spine
落成真实实体：

- `compiler/sema/np_semantic_model.pas`
  - 先固定 symbol/type/binding/typed-hir/runtime-contract count、root name 与 semantic status
- `compiler/sema/np_semantic_analyzer.pas`
  - 先固定 builtin canonical type、resolved unit symbol、call binding、runtime contract seed 与 duplicate import failure
- `compiler/frontend/np_compilation_session.pas`
  - 真实拥有 semantic model，并在 `ResolveUnits` 之后调用 `AnalyzeSemantics`
- `tools/stage0/nextpas.pas`
  - 把 `semantic-status`、`symbol-count`、`type-count`、`typed-hir-node-count`、
    `runtime-contract-count` 和 `typed-hir-root-name` 投影到 command envelope
  - `query symbols` 还会把同一份 binding table 投影成 `query-bindings` / `queryBindings`，
    并把 binding target metadata 投影成 `query-definitions` / `queryDefinitions`

这套最小骨架当前故意只承诺三件事：

- symbol graph 先表达 unit-level symbol identity 与最小 callable symbol identity
- binding table 先表达 root source 中 procedure/function call occurrence 到 callable `SymbolId` 的绑定；
  当前已覆盖 root callable、arg-count overload 消歧、最小 typed overload 消歧与唯一
  imported-unit callable target，并通过
  `query-bindings` / `queryBindings` 暴露给 CLI 与 future language-service adapter；同一份
  session-owned model 还会把 target symbol/unit metadata 投影成 `query-definitions` /
  `queryDefinitions`。bare procedure/function symbol 会记录 `ParamCount` 与 compact
  `ParamSignature`；name-only call binding 会把默认参数语法折算成
  `requiredParamCount..ParamCount` 的可接受 arity 区间，并只用当前已提供参数的 compact
  argument signature 前缀选择唯一 target；root-owned 单一 target 且当前参数签名来自 literal/纯表达式、
  已声明内建标量/字符串变量/参数，或 root-owned 零参内建标量/字符串 function result 等稳定事实并可证明不兼容时发
  `sema.type-mismatch`；root source 没有同名 callable、imported `project-source` 单一 target
  但调用 arity 不在 target 可接受区间内时发 `sema.wrong-argument-count`，arity 已匹配但稳定
  argument signature 明确不兼容时同样发 `sema.type-mismatch`；imported `installed-source`
  single-target arity miss 继续 deferred，不发 `sema.wrong-argument-count`；imported 同名同 arity 多候选、稳定
  argument signature 全不匹配时发 `sema.no-matching-overload`；root-owned exact class
  member-call 中同 owner / 同 qualified name / 同 arity 多候选且稳定 argument signature 全不匹配时，
  同样发 `sema.no-matching-overload`；imported `project-source` inherited member-call
  overload set 也接受 root-owned 零参内建标量/字符串 function result 作为稳定 no-match evidence。
  imported `installed-source` single-target
  type mismatch、single-target arity miss、bare callable ambiguity、bare callable no-match、
  class/record/alias 变量/参数、imported/带参/member function result 相关 no-match、
  无法推断或 signature 不唯一时仍保守不绑定。带 selector/member 的
  qualified callee（例如 `Holder.Help();`）不会再被
  name-only binding pass 误绑定到 imported bare callable；当前正向 selector/member
  contract 覆盖 root source 中直接变量 receiver 的 class method statement call（例如
  `Worker.Run;` / `Worker.Run();` / `Worker.SetValue(7);`）、表达式参数里的 direct
  member function call（例如 `Halt(Worker.Add(1, 2));`）、class method body 内的
  `Self.SetValue(9)` 与 bare implicit-self method call（例如 `Touch;` / `Touch(7);`，
  包括回绑到 parent class method 的 inherited case），以及已声明 class type-name receiver 的 constructor-like member call
  （例如 `TWorker.Create(42)`），以 `member-call` binding 指向已声明的 `TClass.Method`
  method symbol。root source 变量的 type id 也可以来自 imported project/source unit 中已 seed
  的 class type，因此 `uses Worker; var Worker: TWorker;` 后的 direct member call 可绑定到
  imported `TWorker.Add` method symbol；当 root 与 imported unit 同时声明同名 class 时，
  variable receiver 会使用变量 symbol 上的 `TypeId`，target lookup 再按该 type symbol 的
  owner unit 限定 `TClass.Method`，避免继续靠第一个同名 class/method 字符串匹配。若 receiver
  exact class type 未声明同名 method，member lookup 会沿 `ParentTypeId` 链查 parent class
  method，并继续使用 parent type symbol owner 限定 target；exact type 已声明同名 method 但
  没有任何同 arity target 时会发出 `sema.wrong-argument-count`，同一条 arity failure 也会从
  class method body 的 bare implicit-self fallback 透传出来，例如当前 class 的 `Pick;`
  调 `Pick(Value: Integer)` 或 inherited `Touch;` 调 `Touch(Value: Integer)`；body 不匹配或不唯一时仍会保守停止。
  class method declaration 的 parameter list 会进入
  green tree，`method` symbol 会记录 `ParamCount` 与 compact `ParamSignature`；带参数 method
  call 先使用 call argument count 选择同 owner、同 qualified name、同 `ParamCount` 的 target
  set；root-owned 单一 target 且当前参数签名来自 literal/纯表达式、已声明内建标量/字符串变量/参数、
  或 root-owned 零参内建标量/字符串 function result 等稳定事实并可证明不兼容时发
  `sema.type-mismatch`，同一条 failure kind 也会从 class method body 的 bare implicit-self
  fallback 透传出来，例如当前 class 的 `Pick(True);`、inherited `Touch(True);`，以及
  `Pick(Flag);` 中 `Flag` 是 root-owned 零参 Boolean function result 的当前 class method 场景；
  receiver exact type 或 class method body bare
  implicit-self fallback 中，root-owned 多候选同 arity 但稳定 argument signature 全不匹配时发
  `sema.no-matching-overload`，例如当前 class 的 `Pick(True);` 同时面对
  `Pick(Integer)` / `Pick(AnsiString)`，或 inherited `Touch(True);` 同时面对
  `Touch(Integer)` / `Touch(AnsiString)`；imported `project-source` inherited member-call
  overload set 同样可用 root-owned 零参内建标量/字符串 function result 作为 stable
  no-match evidence，例如 `Worker.Pick(Flag);` 中 parent chain 暴露
  `Pick(Integer)` / `Pick(AnsiString)` 而 `Flag` 返回 `Boolean`；若同 arity 有多个候选，则用当前可推断的
  argument signature 做唯一匹配；若 signature collision 仍无法唯一选择，则发
  `sema.ambiguous-overload`，同一 ambiguity 也会从 bare implicit-self fallback
  透传出来，例如当前 class 的 `Pick(1);` 同时面对 `Pick(Integer)` / `Pick(LongInt)`，
  或 inherited `Touch(1);` 同时面对 `Touch(Integer)` 与 `Touch(LongInt)`。随后再用同名
  `TClass.Method` body declaration 的 argument count / signature 做二次确认。完整 overload
  ranking、implicit conversion、default parameter lowering / ranking、member resolver、visibility checking、property
  accessor、record method、array/deref receiver、runtime constructor allocation/lowering 与
  virtual/override dispatch 仍未完成
- type graph 先只表达 builtin canonical types：`Boolean`、`Integer`、`AnsiString`
- `Typed HIR` 先只表达 compilation root、resolved unit refs 与 runtime contract refs

对 `program` / `library` / `package` root，当前 runtime contract seed 也已经先冻结成
`np.system.process_init` 与 `np.system.process_fini` 两个显式语义点，而不是继续把初始化 /
清理前提藏在 driver 或 backend 特判里。

## 只保留少量但硬的 identity

为了控制复杂度，也为了符合高性能目标，语义层先冻结少量稳定 identity：

- `SymbolId`
- `ScopeId`
- `TypeId`
- `UnitId`
- `HirNodeId`

这组 identity 的作用不是制造名词，而是把跨阶段共享事实从字符串和指针偶然性里剥离出来。

要求如下：

- 名字绑定结果优先落到 `SymbolId`，而不是保留原始名字等待后面再次查找。
- 类型判断结果优先落到 `TypeId`，而不是把类型信息散落成布尔标记或临时对象。
- `Typed HIR` 中可被后续阶段引用的节点优先使用 `HirNodeId` 或等价稳定标识。
- identity 本身必须 cheap to copy、cheap to compare，适合 batch diagnostics 和 arena-owned 数据流。

## 让 symbol model 承担所有“名字已经被理解”的事实

symbol model 必须显式表达这些事实：

- 一个声明引入了什么名字
- 这个名字属于哪个 scope
- 它对应什么 kind
- 它是否参与 overload set
- 其他节点如何引用它

第一阶段不需要先展开到完整历史 Pascal 角落，但至少要稳定承接这些 symbol kind：

- unit symbol
- type symbol
- const symbol
- variable symbol
- field symbol
- procedure/function symbol
- parameter symbol

这里真正要避免的是两种退化：

- 用字符串 map 临时查到就算绑定完成
- 把 overload、visibility、declaration ownership 塞进若干互相不知道来源的布尔标记

如果后续实现解释不清某个名字为什么可见、为什么命中某个声明，说明 symbol model 还不够完整。

## scope model 必须是显式层级，而不是递归搜索习惯

语义模型里的 scope 不应该等同于“需要时递归往上找”。

推荐固定这些 scope 层级：

- compilation scope
- unit scope
- interface scope / implementation scope
- callable-local scope
- record or aggregate member scope

这不要求第一阶段先覆盖所有 Pascal 特例，但要求：

- scope parent 关系显式存在，而不是隐藏在遍历顺序里。
- 可见性规则通过 scope relation 和 symbol attribute 共同决定。
- unit interface/export 边界是语义层事实，不是 runtime 或 backend 的猜测。
- diagnostics 可以说明“名字在哪个 scope 查找失败”，而不是只报一个模糊 not found。

## type model 必须 canonical，而不是每次现算

如果 nextPas 想要优雅且高性能，type model 就不能靠每次判断临时拼出来。

第一阶段先冻结以下规则：

- 语义层维护 canonical `TypeId` 视图。
- alias type 和 representation type 必须可区分，而不是被粗暴压平。
- callable signature 必须是 type model 的正式成员，而不是 procedure symbol 上的一串附注。
- composite type、pointer-like relation、array-like relation、ordinal relation 需要以结构化方式表达。
- implicit conversion 的合法性必须来自明确 type relation，而不是来自 scattered special case。

这份规范故意不提前承诺完整 ABI、layout 或 calling convention；这些仍然属于更下游边界。
但它要求“类型正确性”必须在这里就稳定下来。

## 把 overload resolution 当成一等语义流程

重载解析不能继续被写成“挑一个最像的”。

nextPas 推荐把 overload resolution 固定成受控流程：

```text
candidate collection
  -> visibility filtering
  -> arity / label / parameter-shape filtering
  -> type compatibility scoring
  -> tie-break validation
  -> selected callee or structured ambiguity diagnostic
```

这条流程至少要保证：

- candidate set 来自 symbol model，而不是 runtime helper 或 backend 名字表。
- ambiguity 是结构化语义失败，不是“随便选一个继续”。
- intrinsic 和普通 callable 共享调用语义框架，但保留不同的 lowering tag。
- 重载解析结果直接进入 `Typed HIR`，后续阶段不再重跑。

## constant evaluation 必须是语义层能力，不是 codegen 副产品

常量求值影响正确性，因此必须属于语义模型。

第一阶段要求：

- constant evaluation 在 `sema` 内完成，而不是留到 backend 或 runtime。
- 常量值使用结构化 constant representation，而不是只保留原始文本。
- constant folding 只作用于已经被语义层判定安全且确定的表达式。
- 求值失败应产生结构化语义 diagnostics，例如 kind mismatch、overflow-like failure、
  unsupported-constant-form。
- 求值结果进入 `Typed HIR`，让后续 lowering 可以直接消费。

这样做的目的，是让“常量是否成立”成为语义事实，而不是实现副作用。

## intrinsic 与 built-in 语义必须显式化

现代化设计不等于没有 intrinsic；现代化设计的关键，是 intrinsic 不再隐形。

这份规范先冻结：

- intrinsic 调用在 `Typed HIR` 中必须有明确 tag，而不是伪装成普通名字然后在后面偷偷识别。
- runtime-related intrinsic 必须与 `runtime-bootstrap-specification.md` 中的 contract naming 对齐。
- pure semantic intrinsic 和 runtime-assisted intrinsic 必须能被区分。
- intrinsic 的选择权属于语义层，不属于 backend 私有特判。

因此，后续实现应该能回答三个明确问题：

1. 这是普通 symbol 调用，还是 intrinsic 调用？
2. 它是否需要 runtime helper 参与？
3. 它在 `Typed HIR` 里对应哪个显式节点或 tag？

## `Typed HIR` 只表达语义结论，不回流语法偶然性

`Typed HIR` 必须是语义世界的正式入口，而不是“AST 再贴一层类型信息”。

推荐冻结这些规则：

- `Typed HIR` 节点引用 symbol 和 type identity，而不是继续保存待解析名字。
- `Typed HIR` 保留控制流和语义需要的节点，不保留仅供语法还原的 trivia 细节。
- statement / expression / declaration 三类节点保持显式区分。
- runtime-required semantics，例如 init/fini、halt-like behavior、runtime fault edge，必须以
  明确节点或明确 effect tag 表达。
- lowering 只消费 `Typed HIR` 已经存在的结论，不允许重新解释 Pascal 表层语法。

如果一个后续阶段需要回到 AST 才知道语义应该怎么走，说明 `Typed HIR` 还不够完整。

## 语义 diagnostics 必须从这层直接产出

语义模型是 diagnostics 的主产地之一，不能把错误留给别处拼出来。

第一阶段至少要能稳定表达这些语义失败类别：

- unresolved-name
- duplicate-declaration
- visibility-violation
- type-mismatch
- invalid-call-shape
- ambiguous-overload
- invalid-constant-evaluation
- intrinsic-misuse
- unit-cycle-related semantic failure

当前真实落地的 semantic failure baseline 包括：

- `sema.duplicate-declaration`
  - 先用于 duplicate unit import，证明 semantic failure 已进入 diagnostics sink 和 command result bridge
- `sema.wrong-argument-count`
  - 先用于 bare procedure/function call 中 callable name 已知、但没有任何同优先级 arity match 的场景
  - 也用于 bare procedure/function call 中 root source 没有同名 callable、但 imported
    `project-source` 单一 target 已知且调用 arity 不匹配的场景
  - 也用于 class method body 内 bare implicit-self method call 找到 current class root-owned
    method name，但没有任何 arity-compatible target 的场景
  - 也用于 class method body 内 bare implicit-self method call 沿 parent chain 找到 root-owned
    method name，但没有任何 arity-compatible target 的场景
- `sema.type-mismatch`
  - 先用于 bare procedure/function call 与 direct member-call 中，root-owned 单一 target 的 arity
    已匹配、当前 argument signature 来自稳定 literal/纯表达式、已声明内建标量/字符串变量/参数事实，
    或 root-owned 零参内建标量/字符串 function result 且与 target param signature 明确不兼容的场景
  - 也用于 bare procedure/function call、direct member-call 以及 inherited direct member-call 中 imported
    `project-source` 单一 target 的 arity 已匹配、当前 argument signature 来自稳定事实且与 target
    param signature 明确不兼容的场景；该 stable evidence 包含 root-owned 零参内建标量/字符串 function result
  - 同形状 imported `installed-source` single-target / inherited single-target mismatch 继续 deferred，
    即使 argument evidence 是 root-owned 零参内建标量/字符串 function result，也不提前投影为 ordinary
    `sema.type-mismatch`
  - 也用于 class method body 内 bare implicit-self method call 找到 root-owned 单一 target，
    但 stable argument signature 与 target param signature 明确不兼容的场景；该 stable evidence
    包含 builtin literal/纯表达式与 root-owned 零参内建标量/字符串 function result，并覆盖
    current class 与 inherited parent method target
- `sema.no-matching-overload`
  - 也用于 class method body 内 bare implicit-self method call 找到 current class root-owned
    同名同 arity多候选，但 stable argument signature 与全部 target param signature 都不兼容的场景
  - 也用于 class method body 内 bare implicit-self method call 沿 parent chain 找到 root-owned
    同名同 arity多候选，但 stable argument signature 与全部 target param signature 都不兼容的场景
- `sema.ambiguous-overload`
  - 先用于 bare procedure/function call binding 中同名同 arity imported callable 多候选且无法唯一选择的场景
  - 也用于 direct member-call binding 中 compact signature collision 后无法唯一选择 target method 的场景
  - 也用于 class method body 内 bare implicit-self method call 找到 current class root-owned
    同名同 arity多候选，但 compact signature collision 后无法唯一选择 target method 的场景
  - 也用于 class method body 内 bare implicit-self method call 沿 parent chain 找到 root-owned
    同名同 arity多候选，但 compact signature collision 后无法唯一选择 target method 的场景
- `sema.no-matching-overload`
  - 先用于 root-owned 或 imported bare procedure/function call binding 中，同名同 arity 多候选存在、
    argument signature 来自稳定 evidence、但没有任何同优先级 candidate signature 匹配的场景
  - 也用于 imported `project-source` inherited member-call overload set 中，root-owned 零参
    内建标量/字符串 function result 可作为稳定 evidence 且所有 target signature 都不匹配的场景
- `sema.unknown-callable`
  - 先用于 root source bare callable name miss，且不会把已知 symbol/type/builtin callable 误归类
  - 当当前 unit graph 含有 `installed-source` import 时，bare callable name miss 继续保守不绑定，
    避免把 incomplete helper/RTL callable truth 提前报成普通 unknown callable
- `sema.unknown-member`
  - 先用于 direct class member-call 中 receiver type 已知、class/parent chain 没有同名 method，且同名 field/property 不应被误报的场景
  - 也用于 class method body 内 bare implicit-self method call 中，当前 `Self` class/parent chain
    没有同名 method 的场景；例如 `procedure TWorker.Run; begin Missing; end;`
  - implicit runtime 已能读取 source-backed nextPas `System` / `TObject` truth；普通 `class`
    会隐式继承 `System.TObject`，`Obj.Free` 通过真实 `TObject.Free` method symbol 进入
    `member-call` binding；缺少 source-backed System truth 的路径仍保持 deferred，避免把 System
    基线缺口误报成普通 unknown member
  - no-fold typed HIR 现在会让隐式 `System.TObject` 父类的 VMT slot/function metadata 参与
    class layout，并把 `Obj.Free` lowering 到当前有效 `Destroy` runtime call；只继承
    `TObject.Destroy` 的普通 class 会落到 `TObject.Destroy`，而不是不存在的子类 destructor
  - `Obj.Free` 同时会生成 `object-free-runtime` typed HIR node，DisplayName 为
    `np.system.object_free`，Operand 记录 receiver、effective `Destroy`、nil guard 和 heap release
- `sema.invalid-call-shape`
  - 先用于 direct class member-call 中 receiver 类型已知、class layout truth 已知，且同名 field/property
    已知存在但不是 callable 的场景；例如 `Worker.Value(1)` 会失败为 `sema.invalid-call-shape`
  - 同一条边界同样适用于已知 class property 被当成 call 使用的场景；例如
    `Worker.Value(1)` 在 `Value` 是 property 时也会失败为 `sema.invalid-call-shape`
  - 当 member lookup 沿 `ParentTypeId` 命中 inherited field/property，且该 member 不是 callable 时，
    同样失败为 `sema.invalid-call-shape`
  - 上述 inherited non-callable 边界同样覆盖 inherited class property
  - specialized generic receiver、record/property/array/deref receiver 与更完整 member access 仍继续 deferred
    intent；`THIRBuilder` 会把它投影成 HIR `np.system.object_free` intrinsic marker，保留
    receiver pointer operand 与 effective `Destroy` target，并把紧随其后的匹配 `Destroy`
    lowering 标记成 `np.system.object_free.destroy` owned marker；`heap-release true` 会在
    matching owned destroy 后追加 `np.system.object_free.release` marker。LLVM HIR emitter 已能用
    receiver nil branch 包住 owned destroy call，并在非空分支内发出
    `@np_object_free_release` hook；class allocation lowering 也已先进入
    `@np_object_alloc(i64 size)` helper。该 helper 当前写入 16-byte header，记录 payload size
    与 magic，release helper 会从 payload pointer 回退读取 header、校验 magic，并把合法 header
    分到 `release:` 占位块、非法 header 分到 `invalid:` 并调用
    `@np_object_release_invalid(ptr %raw, i64 %size, i64 %magic)` 后汇合到 `done:`；invalid helper 当前会
    调用 `@llvm.trap()` 并发出 `unreachable`；`release:` 当前调用
    `@np_object_release_valid(ptr %raw, i64 %size)`，并在该 helper 内清零 header magic。当前 object
    alloc/release helpers 仍只是 ownership contract，还不声明真实 allocator free、结构化 diagnostics /
    Pascal exception path 或完整 dynamic dispatch runtime 已完成
  - 没有 class layout truth 的 alias / generic specialization / record-like receiver 继续 deferred，直到
    generic instantiation、record methods 和完整 member resolver 进入 semantic model

这里的重点不是今天就冻结完整 code 列表，而是先冻结“语义错误是结构化类别”的事实。

## 让性能约束直接塑造 semantic model

语义层很容易变成最慢的一层，所以性能策略必须前置。

nextPas 在 semantic model 上坚持这些规则：

- symbol、type 和 `Typed HIR` 节点优先使用 arena allocation。
- 常用标识符、qualified name 片段和 canonical type key 优先 interning。
- overload resolution 优先在 candidate set 上工作，不做大范围重复查找。
- unit 变更优先触发 unit-level invalidation，不默认整仓重做语义分析。
- diagnostics 优先 batch emission，不在分析热路径中频繁字符串格式化。

如果未来有人想为了“实现快一点”回到全局 map + heap object + repeated lookup 的写法，
必须给出明确收益证据。

## `stage0`、`stage1` 与 `stage2` 如何接这层语义模型

- `stage0`
  - 先把语义模型写成稳定方向
  - 允许真实编译工作仍主要由 FreePascal 托管
  - 但新的 nextPas 设计不得偏离这条收敛路径
- `stage1`
  - 优先接管 symbol binding、type checking、constant evaluation、overload resolution
  - 让 `Typed HIR` 成为真实 lowering 输入
- `stage2`
  - 在 semantic model、runtime handshake 和 `MIR` 都稳定后，再调查更深的 backend /
    self-hosting 接管

这意味着 semantic model spec 不是附属说明，而是 `stage1` 真正开始变成 nextPas compiler
的门槛之一。

## 第一阶段非目标

- 不把完整 Pascal 全量角落语义一次写死。
- 不提前冻结 ABI、layout 或 object format，`ABI compatibility is deferred`。
- 不把 unit resolution 的全部路径策略塞进这份文档；那更适合后续独立专题继续细化。
- 不把 diagnostics 的输出格式细节和快照策略全塞进这里；这里只冻结语义失败类别与产地。
- 不把 `Typed HIR` 退化成“加了类型注释的 AST”。

第一阶段真正要交付的是：一套能把 symbol、scope、type、constant evaluation、
overload resolution、intrinsic 与 `Typed HIR` 收拢成统一语义核心的设计。
