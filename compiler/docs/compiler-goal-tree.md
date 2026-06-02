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
| **C4** | 债务2 核心：真实 scalar 宽度（i8/16/32/64/u*/f32/f64/i1）+ cast 指令 + signedness（sdiv/udiv/icmp s*u*）；提升/截断规则放 sema | C3 | 🚧 2026-06-02 |
| **C5** | 债务1 第二批：lvalue/address 模型（EmitAddress vs EmitValue）→ 修 `P^.Field`、`@Arr[i]`、array/record/class field | C4 | ⬜ |
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
