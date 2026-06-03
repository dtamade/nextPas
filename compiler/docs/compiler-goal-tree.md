# nextPas 编译器目标树（compiler goal tree）

> 编译器域（`compiler/`）的总控地图。与 `core/docs/platform-goal-tree.md`（RTL 域）并列。
> 每轮工作前对照本树确认当前节点；每轮结束同步状态。

---

## 北极星

让 nextPas 成为 FreePascal 领域顶级编译器框架。关键里程碑：**自举**——用 nextPas
编译器编译它自己的 RTL（`core/` ~37 万行），最终自举编译编译器自身。

管线：lexer → green tree (CST) → sema → typed HIR nodes → HIR builder (SSA) → LLVM IR。

---

## 战略定位（超越 FPC 的维度）

不正面硬刚 FPC 30 年的功能完整度，在 FPC 架构不允许的维度建立优势：

1. **LLVM 优化** —— 向量化、内联、LTO
2. **编译速度** —— 内容哈希增量编译 + 并行
3. **错误体验** —— Rust 级诊断（source span + "Did you mean?"）
4. **现代扩展** —— 类型推断、泛型推断、null safety

---

## 四个架构债务（2026-06-01 与 Codex 深度研究，已验证到代码行）

| # | 债务 | 根因（代码坐标） | 严重度 |
|---|------|------------------|--------|
| 1 | sema→HIR 字符串 blob 传表达式，类型信息被压扁 | `np_semantic_analyzer.pas:6033 EncodeRuntimeIntExprFold` / `np_hir_builder.pas:1310 ParseIntBlob` / `TTypedHirNode.Operand:string` | 最高 |
| 2 | 类型宽度只有 i64 | `np_hir_builder.pas:315 GetIntType` 写死 `AddIntType(64,True)` 全局单例；emitter `TypeToLlvm` else→i64 | 高 |
| 3 | 单后端单目标硬编码 | `np_hir_llvm_emitter.pas:822-823` triple/datalayout 硬编码；`np_backend_plan.pas:607` 构造 emitter 未传已持有的 `FTargetFacts` | 中（第一步极低成本） |
| 4 | 零优化 pass + bump allocator 无 free | `np_hir_llvm_emitter.pas:1052 np_alloc` brk bump；`np_toolchain_plan.pas:1335` opt 未传 -O 级别 | 中（可延后） |

**因果链**：债务1（结构化带类型表达式契约）→ 债务2（宽度传播）→ 债务4 allocator。
债务3 第一步独立且零风险，应最早做以防继续把 x86_64/Linux 假设写进新结构。

---

## 目标树节点

| 节点 | 内容 | 依赖 | 状态 |
|------|------|------|------|
| **C0** | 137 smoke 基线冻结 + 本目标树固化 | — | ✅ 2026-06-01 |
| **C1** | 债务3 第一刀：target facts 接入 emitter，去硬编码 triple/datalayout | C0 | ✅ 2026-06-01 |
| **C2** | 债务1 骨架：结构化表达式表 `TSemanticHirExpr` + `TTypedHirNode.ExprId` + builder `LowerExpr` 双轨入口（blob fallback） | C1 | ✅ 2026-06-01 |
| **C3** | 债务1 第一批迁移：常量/变量/算术/比较/not-and-or/cond-br/ret/halt/write-int | C2 | ✅ 2026-06-02 |
| **C4** | 债务2 核心：真实 scalar 宽度（i8/16/32/64/u*/f32/f64/i1）+ cast 指令 + signedness（sdiv/udiv/icmp s*u*）；提升/截断规则放 sema | C3 | ✅ 2026-06-02 |
| **C5** | 债务1 第二批：lvalue/address 模型（EmitAddress vs EmitValue）→ 修 `P^.Field`、`@Arr[i]`、array/record/class field | C4 | 🚧 2026-06-03 C5-M |
| **C6** | 债务4 allocator：freestanding malloc/free（mmap + free list + coalesce），object/string/dynarray 真实释放 | C5 | ⬜ |
| **C7** | 债务3 深化（target runtime profile/callconv/layout、多目标 IR smoke）+ 债务4 优化（LLVM O2/LTO 可配置） | C5,C6 | ⬜ |
| **C8** | 自举探针：用 nextPas 编译 `core/` 一个真实中等模块，产出"自举差距清单" | C5,C6 | 🏁 里程碑 |

**关键路径** = C2 + C3 + C4 + C5 + C6（allocator）。优化与多目标可延后。

---

## 已达成能力（C0 基线，137 smoke 全绿）

完整 OOP（继承/虚方法/abstract/interface + 引用计数/is/as）、泛型方法（FPC+Delphi 双语法/
嵌套 specialize）、异常（try/except/finally/raise/ExceptObject）、指针（`@X`/`P^`/`P^:=`/
`^Type` 参数）、record 参数/返回、数组参数、unit 编译链接、字符串 concat。

---

## 工作纪律

- 每轮前对照本树确认节点；每轮后同步状态 + 详细报告 + 下一步规划
- 完整重编译验证（`scripts/rebuild-compiler.sh`，确认 40000+ lines；绝不信任 stale PPU）
- 测试 100% 通过 + exit code 验证 + 无内存泄漏
- 复杂取舍与 /codex 深入讨论
- 每轮结束复盘 + git 提交（只 stage compiler/ 相关，绝不碰 core/ 未提交修改）
- 多人协作：编译器域当前无并行 worktree，但仍守最小修改原则

---

## 变更记录

- 2026-06-01 C0：固化本目标树。4 债务路线图与 Codex 研究确认。
- 2026-06-01 C1：target facts 接入 emitter（双构造器 overload，去硬编码 triple/datalayout，
  用上 toml 完整 datalayout）。修复 merge `5de44530` 对 sema 的 156 行回归。137/137 全绿。
  **Codex 建议（C4 采纳）**：债务2 起把 emitter 的裸字符串参数升级为结构化 `TCodegenTargetInfo`
  （由 TTargetFactsView 派生），承载宽度/指针宽度/ABI 对齐/调用约定；默认回退只留 legacy 无参构造器。
- 2026-06-01 C2：引入结构化表达式表 `TSemanticHirExpr`、`TTypedHirNode.ExprId` 与
  builder `LowerExpr` / blob fallback 双轨入口。本轮不迁移 producer，`ExprId=0` 继续走旧 blob；
  focused tests + 完整重编译 + 137/137 LLVM smoke 全绿。
- 2026-06-01 C3-A：builder-only 结构化 scalar lowering：`LowerExpr` 支持 int literal、
  symbol value、unary、binary arithmetic、compare、not/and/or，并在 lowering 前用
  `CanLowerExpr` 预检整棵表达式，保证不支持节点完整回落 blob、不留下半截 HIR。
  本轮仍不迁移 sema producer；focused tests + 完整重编译 + 137/137 LLVM smoke 全绿。
- 2026-06-01 C3-B1：sema producer 第一刀，仅迁移 `Halt(expr)` runtime 参数：
  对简单 scalar 表达式生成 `TSemanticHirExpr` 并设置 `halt-call-runtime.ExprId`，
  同时保留旧 `Operand` blob。runtime var 保持为 `shekSymbolValue`，不因 var-init
  被折成 literal。focused tests + 完整重编译 + 137/137 LLVM smoke 全绿。
- 2026-06-01 C3-B2：sema producer 第二刀，仅迁移 `Write/WriteLn` 的
  `write-int-runtime` 参数：三条 `write-int-runtime` 创建路径统一保留旧 `Operand`
  blob，并在 `BuildRuntimeScalarHirExpr` 支持时设置 `ExprId`。本轮不迁移
  assignment/return/cond-br producer。TDD RED=`test_semantic_hir_expr_producer`
  退出 13；GREEN 后 focused tests + 完整重编译（43668 lines compiled）+
  137/137 LLVM smoke 全绿。
- 2026-06-01 C3-B3：sema producer 第三刀，仅迁移 `ret-runtime` 返回值读取：
  在 `Exit;` 与函数隐式收尾生成的 `ret-runtime` 节点上，保留旧
  `var <retvar>` blob，同时附加指向当前返回变量的 `shekSymbolValue ExprId`。
  本轮不回溯 `Result := ...` 的原始表达式树，只先把 return 消费面切到结构化
  路径。TDD RED=`test_semantic_hir_expr_producer` 退出 23；GREEN 后 focused
  tests + 完整重编译（43694 lines compiled）+ 137/137 LLVM smoke 全绿。
- 2026-06-02 C3-B4：sema producer 第四刀，迁移 `if/while/repeat` 的
  `cond-br-runtime` 条件表达式：仅当结构化表达式可证明产出 bool/i1
  （compare、not(compare)、and/or 组合）时设置 `ExprId`，保留旧 condition blob。
  `for` 的手工拼接循环条件暂不迁移。TDD RED=`test_semantic_hir_expr_producer`
  退出 33；GREEN 后 focused tests + 完整重编译（43739 lines compiled）+
  137/137 LLVM smoke 全绿。
- 2026-06-02 C3-B5：sema producer 第五刀，仅迁移普通标量变量赋值
  `assign-runtime`：例如 `x := x + 4` 会保留旧 `Operand` blob，同时在目标不是
  dotted/string/array/record/class 变量时附加结构化 scalar `ExprId`。指针解引用、
  field/array store、字符串/record/class 赋值、`Inc/Dec` 合成 blob 与 `for`
  初始化/步进仍走旧路径。TDD RED=`test_semantic_hir_expr_producer` 退出 43；
  GREEN 后 focused tests + 完整重编译（43753 lines compiled）+
  137/137 LLVM smoke 全绿。
- 2026-06-02 C3-B6：sema producer 第六刀，迁移普通标量变量的 `Inc/Dec`
  合成 `assign-runtime`：保留旧 `var x` + delta + `add/sub` blob，同时附加结构化
  `shekBinaryOp`（`+`/`-`）表达式。field `Inc/Dec`、`for` 初始化/步进、
  `call-runtime` 参数 blob、指针/lvalue 与 string/array/record/class ownership
  场景继续留给后续节点。TDD RED=`test_semantic_hir_expr_producer` 退出 53；
  GREEN 后 focused tests + 完整重编译（43803 lines compiled）+
  137/137 LLVM smoke 全绿。C3 的安全单表达式 producer 面已足够，下一步进入 C4。
- 2026-06-02 C4-A：真实标量宽度根基第一刀：`TSemanticModel` 增加
  `TSemanticScalarTypeFact`，sema 种下 Boolean/i1、Byte/u8、Word/u16、
  Integer/LongInt/i32、LongWord/Cardinal/u32、Int64/i64、QWord/u64、
  Single/f32、Double/f64、Pointer/ptr facts；HIR builder 增加 TypeId→HIR type
  映射，typed structured lowering 在 fact 完整且操作数同型时产出真实宽度，
  fact 缺失则回落旧 blob；LLVM emitter 的 `icmp`/`zext` 改用 typed operand/result。
  C4 仍未完成：cast/extend/trunc、promotion 与 unsigned `div/mod/icmp` 留给后续。
- 2026-06-02 C4-B：结构化 cast 第一刀：`TSemanticHirExprKind` 新增 `shekCast`，
  HIR builder 增加显式 cast lowering，按源/目标 typed HIR 标量类型产出
  `zext` / `sext` / `trunc`；LLVM emitter 补齐 `trunc` 与 `sext`。本轮仍不迁移
  sema producer，也不处理 `int -> bool`、pointer/float cast、`sdiv/udiv`、
  `srem/urem`、signed/unsigned `icmp`。focused tests + 完整重编译（44265 lines compiled）+
  137/137 LLVM smoke 全绿；下一步进入 C4-C signedness 与 promotion 规则。
- 2026-06-02 C4-C：typed signedness 第一刀：保持 HIR model 与 producer 不变，
  只在 LLVM emitter 依据 typed HIR operand type 选择具体 opcode：
  unsigned `div/mod` 发 `udiv/urem`，unsigned ordered compare 发
  `ult/ule/ugt/uge`，signed int 路径保持 `sdiv/srem/slt/sle/sgt/sge`。
  本轮仍未把 mixed-width promotion 决策放回 sema，也未扩到 pointer/float cast。
  focused tests + 完整重编译（44352 lines compiled）+ 137/137 LLVM smoke 全绿；
  C4 剩余主任务是 sema-side promotion 与显式 `shekCast` 物化。
- 2026-06-02 C4-D：sema-side integer promotion 第一刀：`BuildRuntimeScalarHirExpr`
  开始为已迁移 runtime scalar producer 写入具体 `TypeId`，对 mixed-width integer
  binary/compare 表达式在 sema 选择 common type，并用显式 `shekCast` 物化
  `zext` / `sext` / `trunc`。本轮保持 `var-decl-runtime` alloca 不切真实宽度，
  旧 blob 仍可回退；同时在 builder 侧把 typed `Halt` 与 `Write/WriteLn` integer
  runtime 参数归一到 legacy i64 helper ABI，修复 i32 值直传 i64 asm/helper 的 LLVM
  verifier 回归。TDD RED=`test_semantic_hir_expr_producer` 退出 75/122/132；
  GREEN 后 focused tests + 完整重编译（44536 lines compiled）+
  137/137 LLVM smoke 全绿。C4 下一步建议先做剩余 legacy i64 ABI/alloca 审计，
  再进入 C5 lvalue/address 模型。
- 2026-06-02 C4-E：legacy alloca store normalization：审计 C4-D 后的 typed value
  与旧 i64 存储边界，确认普通 `assign-runtime` 仍可能把 typed i32 直接
  `store i32` 到 legacy i64 alloca。HIR builder 新增通用 scalar target-type
  normalization helper，并让普通 alloca assignment 以现有槽类型为 store type，
  必要时插入 `sext` / `zext` / `trunc`。本轮不切 `var-decl-runtime` 真实宽度，
  不扩大到 varparam、间接 `*name` assignment、return/function-call ABI 或 C5
  lvalue/address 模型。TDD RED=`test_semantic_hir_expr_producer` 退出 142；
  GREEN 后 focused tests + 完整重编译（44547 lines compiled）+
  137/137 LLVM smoke 全绿。C4 现在可以进入 C5。
- 2026-06-02 C5-A：address/value builder skeleton：不迁移 sema producer，先在
  HIR builder 让结构化 `shekSymbolAddress`、`shekAddressOf`、`shekDeref`
  区分 lvalue address 与 scalar value。`LowerExprValue` 现在会在遇到
  `shvcAddress` 时显式 load；`LowerExprAddress` 只接受真正的 address 结果。
  TDD RED=`test_hir_builder_structured_address` 退出 2；GREEN 后 focused
  tests + 完整重编译（44709 lines compiled）+ 137/137 LLVM smoke 全绿。
  C5 下一步迁移 `@x` / `P^` 这类最小 sema producer 切片。
- 2026-06-02 C5-B：address/deref sema producer 第一刀：普通 runtime scalar
  assignment 中的 `@identifier` 现在保留旧 `varref` blob，同时附加
  `shekSymbolAddress -> shekAddressOf` 结构化表达式；`p^` 保留旧 `deref`
  blob，同时附加 `shekDeref`，其 child 明确为 builtin `Pointer` scalar。
  本轮不引入精确 pointee metadata，不迁移 field/array/class/record address
  chain。TDD RED=`test_semantic_hir_expr_producer` 退出 153；GREEN 后 focused
  tests + 完整重编译（44805 lines compiled）+ 137/137 LLVM smoke 全绿。
  C5 下一步进入 `@Arr[i]` / `P^.Field` 的 lvalue chain 结构化建模。
- 2026-06-02 C5-C：array element address 第一刀：builder 支持
  `shekArrayElem` 作为 `shvcAddress`，通过现有 `arr$ptr` + `gep_i64`
  生成动态 `array of Integer` 元素地址；sema producer 支持 `@arr[i]`
  生成 `shekArrayElem -> shekAddressOf`。旧 blob fallback 新增临时
  `arr_elem_ref` token，只用于结构化 lowering 失败时保底。本轮不迁移
  static array、array store、record/class field 或 `P^.Field`。TDD RED=
  `test_hir_builder_structured_address` 退出 2 /
  `test_semantic_hir_expr_producer` 退出 182；GREEN 后 focused tests +
  完整重编译（44967 lines compiled）+ 137/137 LLVM smoke 全绿。C5
  下一步建议转向 `P^.Field` 的结构化 field offset 链。
- 2026-06-02 C5-D：pointer field address 第一刀：builder 支持
  `shekField` 作为 `shvcAddress`，通过 base address + field index 生成
  `gep_i64` 字段地址；`shekDeref` 现在允许 non-scalar aggregate TypeId
  作为 address base，字段值由 `LowerExprValue` 显式 load。sema producer
  为 `^Type` runtime 变量登记 pointee metadata，并支持 `@p^.Field`
  生成 `shekAddressOf -> shekField -> shekDeref -> shekSymbolValue`。
  旧 blob fallback 新增临时 `field_ref` token。本轮不迁移 field store、
  普通 `record.field`、`class.field`、嵌套 field chain 或 static array。
  TDD RED=`test_hir_builder_structured_address` 退出 2 /
  `test_semantic_hir_expr_producer` 退出 192；GREEN 后 focused tests +
  完整重编译（45252 lines compiled）+ 137/137 LLVM smoke 全绿。C5
  下一步建议进入 field store / record-class field 剩余 address chain。
- 2026-06-03 C5-E：field store RHS 第一刀：builder 让
  `field-store-runtime` / `record-field-store-runtime` 先消费 RHS
  `ExprId`，失败时继续回落旧 blob；sema producer 为普通 class/self
  field store 与 record field store 的 scalar RHS 附加结构化表达式。
  本轮刻意不把 `TTypedHirNode.ExprId` 复用成 LHS target/address 通道，
  LHS 仍由既有 node kind + operand 描述；typed RHS store 继续在 builder
  归一到 legacy i64/ptr field-slot ABI。TDD RED=
  `test_hir_builder_structured_address` 退出 2 /
  `test_semantic_hir_expr_producer` 退出 203、213；GREEN 后 focused tests +
  完整重编译（45316 lines compiled）+ 137/137 LLVM smoke 全绿。C5
  下一步应进入真正的 LHS target/address 结构：普通 `record.field` /
  `class.field` address、嵌套 field chain、array store 与 static array。
- 2026-06-03 C5-F：field store target/address 第一刀：`TTypedHirNode`
  新增独立 `TargetExprId`，保持 `ExprId` 只表示 RHS；builder 让
  `field-store-runtime` / `record-field-store-runtime` 优先通过
  `LowerExprAddress(TargetExprId)` 得到 LHS 地址，失败时仍回落旧 operand
  target 解析。sema producer 为普通 `record.field := rhs`、方法内
  `self.field := rhs` 和 `obj.field := rhs` 生成结构化 target：
  record 走 `shekField -> shekSymbolAddress`，class/self 走
  `shekField -> shekDeref -> shekSymbolValue`。本轮不迁移 array store、
  static array 或嵌套 field chain。TDD RED=缺少 `TargetExprId` API 时
  `test_semantic_hir_expr` / `test_hir_builder_structured_address` /
  `test_semantic_hir_expr_producer` 编译失败；GREEN 后 focused tests +
  完整重编译（45545 lines compiled）+ 137/137 LLVM smoke 全绿。C5
  下一步进入 `array[i] := rhs`、static array address 与 nested field chain。
- 2026-06-03 C5-G：array store target/address 第一刀：普通动态数组
  `arr[i] := rhs` 的 `assign-arr-elem-runtime` 现在可通过独立
  `TargetExprId` 表达 LHS 元素地址，builder 优先 `LowerExprAddress(TargetExprId)`，
  成功时不再解析 legacy index，失败时仍完整回落旧 operand/blob 路径。sema
  producer 为普通 runtime `array of Integer` store 生成
  `shekArrayElem(ValueClass=shvcAddress)` target；static array、字段数组、
  array-of-record-field、嵌套 lvalue chain 与 class/object RHS 特殊分支继续留给
  后续 C5 切片。TDD RED=`test_hir_builder_structured_address` 退出 6 /
  `test_semantic_hir_expr_producer` 退出 233；GREEN 后 focused tests +
  完整重编译（45618 lines compiled）+ 137/137 LLVM smoke 全绿。C5
  下一步建议处理 static array target 与 nested lvalue chain 的统一表达。
- 2026-06-03 C5-H0：static array foundation：先修静态数组基础语义，再进入
  static array target/address。parser 现在保留 `array[lo..hi] of T` bounds，
  sema 为直接 static array 变量记录 `arr$arr_static`、`arr$arr_low`、
  `arr$arr_high`、`arr$arr_len` 与元素类型 metadata，并继续通过
  `var-decl-arr-runtime` / `arr$ptr` / `arr$len` 兼容旧路径；builder 为 static
  array 创建真实 backing storage，初始化既有 `arr$ptr` / `arr$len` 通道，并在
  `LowerArrayElemExpr`、`arr_elem_ref`、`arrload var` 与 array-store fallback
  路径按 lower bound 做 `index - low` 归一化。static array 的结构化
  `TargetExprId` producer、字段数组、array-of-record-field 与嵌套 lvalue chain
  仍留给后续 C5-H/C5-I。TDD RED=`test_hir_builder_structured_address` 退出 6 /
  `test_semantic_hir_expr_producer` 退出 241；GREEN 后 focused tests +
  完整重编译（45932 lines compiled）+ 静态数组 global/local runtime 探针 exit=42 +
  137/137 LLVM smoke 全绿。C5 下一步进入 static array target/address producer。
- 2026-06-03 C5-H：static array target/address：direct static array
  `arr[i] := rhs` 与 `@arr[i]` 现在明确走结构化 producer。`shekArrayElem`
  继续作为 dynamic/static 共享的 element-address kind，static vs dynamic 由
  C5-H0 metadata 和 builder lower-bound normalization 决定；`assign-arr-elem-runtime`
  在保留旧 operand/blob 的同时，为 direct array element store 附加 RHS `ExprId`
  与 LHS `TargetExprId`。本轮不迁移字段数组、array-of-record-field、class/object
  RHS 特殊分支或 nested lvalue chain。TDD RED=`test_semantic_hir_expr_producer`
  退出 246；GREEN 后 focused tests + 完整重编译（45934 lines compiled）+
  137/137 LLVM smoke 全绿。C5 下一步进入 C5-I：field arrays 与 nested lvalue chain。
- 2026-06-03 C5-I：array-of-record-field target 第一刀：`arr[i].Field := rhs`
  现在生成结构化 nested target `shekField -> shekArrayElem -> index`，并同时保留
  旧 offset blob fallback。`shekArrayElem` 开始携带语义元素类型；builder 允许
  aggregate array element 作为 address base，即没有 concrete scalar HIR type 时仍可
  参与 `LowerExprAddress`，但作为 value load 仍要求 concrete scalar HIR type。TDD
  RED=`test_semantic_hir_expr_producer` 退出 173；GREEN 后 focused tests +
  完整重编译（46013 lines compiled）+ 137/137 LLVM smoke 全绿。C5 下一步建议在
  `self.Items[i]` 字段数组和 `arr[i].A.B` 更深 field chain 中择一继续拆小切片。
- 2026-06-03 C5-J：field-array target 第一刀：`self.FItems[i] := rhs` 现在可生成
  结构化 target `shekArrayElem(SymbolId=0) -> shekField(self.FItems) -> index`。
  `shekArrayElem` 保持旧 symbol-backed direct array 形态，同时新增 base-address child
  形态，用于从字段 slot load array buffer 后做元素 GEP；legacy `__field_arr__`
  operand/blob fallback 原样保留。parser 现在保留 class field 的完整 type node，
  包括逗号字段列表；sema 为 class array field 记录 element metadata，并覆盖隐式
  `FItems[i]`、显式 `Self.FItems[i]` 和继承 field-array metadata。RHS 继续走
  `ExprId`，LHS 走 `TargetExprId`。TDD RED=`test_hir_builder_structured_address`
  退出 6 / `test_semantic_hir_expr_producer` 退出 148；review RED 退出 62；
  GREEN 后 focused tests + 完整重编译（46248 lines compiled）+ 137/137 LLVM smoke
  全绿。C5 下一步建议进入 `arr[i].A.B` 更深 field chain 或收口 field-array value load。
- 2026-06-03 C5-K0：constructor arg classification 红点修复：`test_obj_compose`
  中 `TRect.Create(P.GetX, P.GetY)` 曾把 `TPoint.GetX/GetY` 的 i64 结果按 ptr
  参数传给 `(ptr, i64, i64)` constructor。根因是 builder 的 `ProcessClassNew`
  用参数 blob 的 receiver/内部行推断 pointer，`var P` 污染了 nested method-call
  最终结果。修复后新增 `ParseIntBlobTyped`，让 `ProcessClassNew` 直接消费 blob
  lowering 的最终 `TypeId`：integer nested method-call 归为 `i64`，pointer-return
  ordinary member call 继续归为 `ptr`。TDD RED=`test_semantic_hir_expr_producer`
  退出 148；GREEN 后 focused tests + 完整重编译（46258 lines compiled）+
  `test_obj_compose` / `test_nested_method` 对照通过 + 137/137 LLVM smoke 全绿。
  C5 下一步仍建议进入 `arr[i].A.B` 更深 field chain 或 field-array value load。
- 2026-06-03 C5-K：nested array-backed field chain 第一刀：`arr[i].A.B := rhs`
  与 `Self.FItems[i].A.B := rhs` 现在都能生成递归 `TargetExprId`，形态为
  `shekField -> shekField -> shekArrayElem`。sema 新增共享 `BuildTargetAddressExpr`
  递归拼装 address tree，并把 array-backed field store producer 收口为统一分流：
  direct array 与 field-array 都保留旧 blob fallback，但 fallback 的 index 会展平成
  `index * elem_slots + field_offset`，因此旧路径仍有意义。builder 让 `shekField`
  接受 aggregate intermediate address（有 semantic `TypeId`、无 scalar HIR type），
  只在 address context 放行，value load 仍要求 concrete scalar type。TDD RED=
  `test_hir_builder_structured_address` 退出 6 /
  `test_semantic_hir_expr_producer` 退出 222；GREEN 后 changed tests +
  9 focused compiler tests + 完整重编译（46508 lines compiled）+
  137/137 LLVM smoke 全绿。C5 下一步建议进入 array/field-array value load
  与剩余 class/object RHS 收口。
- 2026-06-03 C5-L：array/field-array value load：`x := arr[i]`、
  `x := arr[i].A.B`、`y := FItems[i]`、`y := Self.FItems[i].A.B`
  现在都能重新发出 value-side `assign-runtime`，并挂上结构化 `ExprId`。根因不是
  builder，而是 producer 的旧 blob gate：`WalkHaltCalls` 只有在
  `EncodeRuntimeIntExprFold` 成功时才会发 assign node，而 current-class field-array
  value load 没有 legacy blob。修复后在不改 builder 的前提下，补齐了
  `Self/FItems[i]` 与 `Self/FItems[i].Field` 的旧 blob 编码路径，保持 structured expr 与
  legacy fallback 双轨一致。TDD RED=`test_semantic_hir_expr_producer` shell exit 255
  （实为 `Halt(261)`）；GREEN 后 changed tests + 完整重编译（44115 lines compiled）+
  137/137 LLVM smoke 全绿。C5 下一步建议进入剩余 class/object RHS 与 value-side 对称收口。
- 2026-06-03 C5-M：object-backed field-array value load：`y := Other.FItems[i]`、
  `Result := Other.FItems[i]`、`y := Other.FItems[i].A.B`、
  `Result := Other.FItems[i].A.B` 现在与 self/current-class 路径对齐：
  sema 新增共享 `TryClassFieldArrayAccess`，统一识别 implicit self / explicit self /
  object variable receiver，并让 `BuildClassFieldArrayElementTargetExpr`、
  `ResolveArrayAccessElementTypeId`、`EncodeRuntimeIntExprFold` 复用同一份
  receiver/class/field 事实。builder 本轮不变；legacy `arr_load` fallback 继续保留。
  TDD RED=`test_semantic_hir_expr_producer` 退出 83；GREEN 后 changed tests +
  完整重编译（44145 lines compiled）+ 137/137 LLVM smoke 全绿。C5 下一步继续
  `WalkHaltCalls` 剩余 class/object RHS 特殊分支（constructor-like、raw object-dot、
  pointer-return helper）。
