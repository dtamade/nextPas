# 编译器深度审计 Findings

> 审计日期：2026-07-05
> 范围：compiler/ 全部 49,667 行生产代码 (31 文件)
> 方法：静态分析 + 数据量化 + 架构对标
> 轮次：2 轮深度扫描

---

## 总览

| 类别 | 数量 | 严重度分布 |
|------|------|-----------|
| 架构 | 6 | 4x 🔴, 2x 🟠 |
| 性能 | 7 | 2x 🔴, 5x 🟠 |
| 内存 | 3 | 3x 🟠 |
| 工程 | 6 | 1x 🔴, 5x 🟡 |
| 第二轮扫描 | 14 | 2x 🔴, 7x 🟠, 5x 🟡 |
| **合计** | **36** | |

### 全局指标

| 指标 | 数值 |
|------|------|
| 生产文件 | 31 |
| 生产代码行数 | 49,667 |
| 测试文件 | 29 |
| 测试代码行数 | 10,289 |
| test/production 比 | **0.21x** |
| SameText 调用 (全编译器) | **647** |
| for 循环遍历数组 (全编译器) | **404** |
| SetLength +1 扩容 (全编译器) | **145** |
| 字符串拼接 (全编译器) | **1,125** |

### 文件集中度

| 文件 | 行数 | 占比 |
|------|------|------|
| np_semantic_analyzer.pas | 12,255 | 24.7% |
| np_hir_builder.pas | 7,092 | 14.3% |
| np_green_tree.pas | 5,379 | 10.8% |
| np_sema_runtime_expr.inc | 3,345 | 6.7% |
| np_compilation_session.pas | 2,554 | 5.1% |
| **5 文件合计** | **30,625** | **61.6%** |

---

## A. 架构 Findings (6)

### A-01 [🔴] TSemanticAnalyzer God Class — 279 方法，单一故障点

**数据**：
- 279 方法声明，183 实现
- 12,255 行单文件
- 60+ 私有字段共享可变状态
- 7+ 种职责混在一个 class

**影响**：任何改动需要理解 12,000 行上下文；无法独立测试任何子功能；并行开发不可能。

**对标**：Clang 的 Sema 分为 `SemaDecl.cpp`, `SemaExpr.cpp`, `SemaOverload.cpp` 等 20+ 文件。Rust 的 `rustc_typeck` 拆为 10+ 个 crate。

---

### A-02 [🔴] Pipeline 边界模糊 — sema 直接生成 HIR

**数据**：
- sema 包含 `BuildRuntime*` 系列方法（`np_sema_runtime_expr.inc`, 3,345 行）
- HIR Builder (`np_hir_builder.pas`, 7,092 行) 退化为被动数据结构填充器
- sema 直接构造 `TSemanticHirExpr` 节点

**影响**：无法在 sema 和 IR 之间插入优化 pass；sema 的输出不是纯粹的类型化 AST，而是已经偏向目标 IR。

**对标**：LLVM 架构中 Frontend → IR → Optimizer → Backend 严格分层。nextPas 的 sema 跨越了前两层。

---

### A-03 [🔴] .inc 文件伪装架构 — 物理分离但逻辑耦合

**数据**：
- `np_sema_string_ops.inc` (2,243 行) — 字符串所有权跟踪方法
- `np_sema_runtime_expr.inc` (3,345 行) — 运行时表达式生成方法
- 两者都是 `TSemanticAnalyzer` 的方法，共享所有私有字段

**影响**：无法独立编译、测试或理解。.inc 是 C 语言的 `#include`，不是模块化。

---

### A-04 [🔴] Permissive Overload — 15+ 处工程妥协

**数据**：代码中 15+ 处注释标记：
```
{ Permissive: pick first exact match instead of failing }
{ Permissive: pick first compatible match instead of failing }
{ Permissive: suppress ambiguous-overload errors for C8 pass }
```

**影响**：编译器可能接受错误的代码、拒绝正确的代码，或在存在多个候选时产生不确定行为。

---

### A-05 [🟠] 无 IR 优化 Pass — 生成的代码完全未优化

**数据**：
- `np_hir_builder.pas`: 0 个优化/transform 方法
- `np_hir_verifier.pas`: 234 行，仅做 SSA 基本验证
- HIR → LLVM IR 是 1:1 直译，无任何中间优化

**影响**：生成的 LLVM IR 质量完全依赖 LLVM 自身的优化。循环展开、常量折叠、死代码消除等基础优化都推给 LLVM，导致编译时间更长。

---

### A-06 [🟠] 编译会话缺少 Pipeline 抽象

**数据**：
- `np_compilation_session.pas` (2,554 行, 166 方法) 直接调用各阶段
- 无 Pipeline/Pass 注册机制
- 阶段顺序硬编码在方法调用中

**影响**：无法插入自定义 pass、无法并行化阶段、无法 A/B 测试不同策略。

---

## B. 性能 Findings (7)

### B-01 [🔴] O(n) 线性查找 — 核心查找路径

**数据**：
- `LookupProcedureBody`: O(n) 遍历 `FProcedureBodies` 数组
- `LookupOverload`: O(n) 遍历 + 参数匹配
- `HasOverload`: O(n) 遍历 + 计数
- `MangledName`: O(n) 每次调用（字符串拼接 `IntToStr`）
- sema 共有 225 个 for 循环，35 个直接遍历动态数组
- **全编译器**: 647 处 `SameText` 调用，404 处数组遍历

**量化影响**：假设编译 1000 单元 × 200 符号/单元，每次查找 O(n) 遍历 200 符号。总操作 = 40,000,000 次 `SameText`。每次 ~100ns → 纯字符串比较 4 秒。

**应改为**：`TDictionary<string, TProcedureBodyEntry>` 或排序数组 + 二分查找。

---

### B-02 [🟠] GetParamSignature — 每次重载解析都重新计算

**数据**：
- `GetParamSignature` (~85 行) 对每个参数：`ResolveTypeIdForOwner` → `TypeSignatureForTypeId` → 字符串拼接
- 每次重载解析调用一次，每次参数匹配调用一次
- 无缓存

**影响**：同一函数的签名在编译过程中被重复计算数十到数百次。

---

### B-03 [🟠] 字符串拼接在热路径中

**数据**：
- sema 中有 277 处字符串拼接
- `MangledName` (每次调用都拼接 `Name + '$' + IntToStr(Count)`)
- `GetParamSignature` 逐字符拼接签名串
- LLVM emitter 中大量 `Op := Op + ...` 模式
- **全编译器**: 1,125 处字符串拼接

**影响**：每次拼接都分配新字符串 + 复制。

---

### B-04 [🟠] 无符号表索引 — 每次按名称查找都是字符串比较

**数据**：
- sema 中 408 处 `SameText` 调用
- 每次查找按名称匹配：`SameText(FProcedureBodies[Index].Name, AName)`
- 无哈希索引、无符号 ID 快速路径

**影响**：编译器中 90% 的查找是"已知符号 ID → 找符号"，但当前全部退化为字符串比较。

---

### B-05 [🔴] 无增量编译 — 每次全量重来

**数据**：
- `np_symbol_cache.pas` (241 行) — 仅缓存导入单元符号，不缓存编译结果
- `np_compilation_session.pas` — 每次从 lexer 开始全量处理
- 无 mtime/fingerprint 检查
- 67 单元 6.4s，158 单元 16s（实测数据）

**影响**：修改 1 行代码 → 重新编译全部传递依赖。开发迭代速度受限于 O(n) 全量编译。

---

### B-06 [🟠] 无并行编译 — 单线程顺序处理

**数据**：
- `np_compilation_session.pas`: 0 处线程/并行相关代码
- 单元按拓扑序顺序处理：`for Index := 0 to FUnitGraph.ResolvedUnitCount - 1`

**影响**：多核 CPU 利用率 ~1/n。拓扑序同层单元可完全并行。

---

### B-07 [🟠] LLVM Emitter — 逐字符串拼接 IR

**数据**：
- LLVM IR 生成通过字符串拼接：`Op := '  call void @' + AInstr.CallTarget + '('`
- 无 IR builder API（如 LLVM C++ API 的 `IRBuilder`）
- 每条指令分配 5-15 次字符串

**影响**：大型模块（1000+ 函数）的 LLVM IR 生成产生海量临时字符串分配。

---

## C. 内存 Findings (3)

### C-01 [🟠] SetLength +1 — 逐元素扩容

**数据**：
- sema: 20+ 处 `SetLength(arr, Length(arr) + 1)` 模式
- hir builder: 16 处 `SetLength(arr, N + 1)` 模式
- **全编译器**: 145 处 `SetLength +1` 模式
- 每次 +1 触发 ReAllocMem + 全量复制

**量化影响**：添加 1000 个字段到 class → 1000 次 ReAllocMem + ~500,000 次元素复制。
应改为容量翻倍策略（如 `SetLength(arr, Count + 16)` 已部分使用但不一致）。

---

### C-02 [🟠] Green Tree — 每个 AST 节点是独立 class 实例

**数据**：
- `TGreenNode = class` — 堆分配
- 每个 token/identifier/expression 一个 class 实例
- `AppendChild` 添加引用

**影响**：中型源文件（5000 tokens）→ 5000+ 次 `TGreenNode.Create` → 5000+ 次堆分配。
内存碎片化 + GC 压力。

**对标**：Roslyn (C#) 使用 `GreenNode` 不可变树 + 节点复用。Rust 的 `rowan` 使用 arena + 索引。

---

### C-03 [🟠] 无 Arena/Region 分配 — 编译器生命周期内无释放

**数据**：
- 无 `TFastArena` 使用（虽然 core/mem 已有 64.8ns 的 TFastArena）
- AST 节点、HIR 节点、语义模型全部分散堆分配
- 编译结束后依赖引用计数或 GC 回收

**影响**：编译器内存峰值高，且无法利用 arena 的批量释放优势。

---

## D. 工程 Findings (6)

### D-01 [🔴] 测试覆盖严重不足 — test/production 比 0.21x

**数据**：
- 生产代码：49,667 行（31 文件）
- 测试代码：10,289 行（29 文件）
- 比例：0.21x（健康标准：>1.0x）
- sema (12,255 行) **0 个直接单元测试**

**影响**：God Class 改动风险极高，无安全网。

---

### D-02 [🟡] 无错误恢复 — 一个错误就停止

**数据**：
- sema: 0 处 error recovery 代码
- lexer: 0 处 error recovery 代码

**影响**：一个语法错误 → 编译停止，用户只能看到第一个错误。IDE 场景不可用。

---

### D-03 [🟡] 诊断系统无结构化输出

**数据**：
- `np_diagnostics_sink.pas` (663 行) — 仅存储 `TDiagnosticRecord` 数组
- 无 JSON/sarif/LSP 格式输出
- 无 fix-it/quick-fix 支持

**影响**：无法集成 IDE（VS Code plugin 需要 LSP diagnostic 格式）。

---

### D-04 [🟡] 编译器 CLI 分散

**数据**：
- 编译入口在 `np_compilation_session.pas`
- 工具链在 `np_toolchain_plan.pas` (2,137 行)
- 无统一的 `nextpas` CLI 入口文件
- 命令行参数解析散落在多处

**影响**：新开发者难以找到入口；添加新 CLI 选项需要修改多处。

---

### D-05 [🟡] LowerToMir — HIR 构建仅在调试模式执行

**数据**：
```pascal
if GetEnvironmentVariable('NEXTPAS_HIR_DUMP') = '1' then
  HirBuilder.Build;
```

**影响**：正常编译路径中 `LowerToMir` 是空操作（仅设置 `FMirStatus := 'ready'`）。HIR Builder 从未在正常路径被调用。实际代码生成路径不明。

---

### D-06 [🟡] Pipeline 阶段间字符串状态传递

**数据**：
- 阶段间通过 `Status = 'ready'` / `'failure'` / `'deferred'` 字符串传递状态
- 无类型化接口（如枚举或 discriminated union）
- `FSemanticModel`, `FBackendPlan` 等通过字段隐式传递

**影响**：隐式耦合，无法静态检查数据流正确性。无法独立测试单个阶段。

---

## E. 第二轮深度扫描 (14)

### E-01 [🔴] SemanticModel — 全部查找 O(n) 线性扫描

**数据**：
- `FindTypeByName`: O(n) 遍历 `FTypes`
- `FindSymbolByName`: O(n) 遍历 `FSymbols`
- `LookupConstValue`: O(n) 遍历 `FConstValues`
- `GetTypeMetaByName`: O(n) 遍历 `FTypeMetadataEntries` + 额外 `SameText(FTypes[...].Name)`
- `GetFieldMetaByName`: O(n×m) 双重循环
- `GetVmtSlotByName`: O(n×m) 双重循环

**影响**：SemanticModel 是编译器中最频繁查询的数据结构。每次查询都是 O(n)。无哈希索引、无排序+二分。

---

### E-02 [🟠] TypeMeta 重复查询 — 无缓存

**数据**：
- 15+ 个 `TypeMeta*` 方法（`TypeMetaSize`, `TypeMetaIsRecord`, `TypeMetaIsClass`, `TypeMetaFieldIndex` 等）
- 每个方法独立调用 `FModel.GetTypeMetaByName` → O(n) 遍历
- `GetParamSignature` 中每个参数调用 3 个 TypeMeta 方法
- 同一类型被重复查询数十次

**应改为**：缓存 TypeMeta 索引或使用哈希表。

---

### E-03 [🟡] TDefineTable — 预处理器 define 查找 O(n)

**数据**：
- `TDefineTable.IndexOf`: O(n) 遍历 + 每次 `UpperCase`
- 每次 `{$IFDEF}` 评估 → `IsDefined` → `IndexOf` → O(n)
- 典型文件有 10-50 个 `{$IFDEF}` 检查

**影响**：虽然 define 表通常较小（~50 条目），但在 1000 文件编译中仍累积显著开销。

---

### E-04 [🟠] Green Tree — FText 可变，破坏不可变性

**数据**：
- 20+ 处直接修改 `FText`：`NameNode.FText := NameNode.FText + SpecArgs`
- 模式：字符串拼接在节点构造后
- 宣称不可变但实际可变

**影响**：不可变树的核心优势（节点复用、并发安全）被破坏。每次拼接产生新字符串分配。

---

### E-05 [🟡] Lexer — 全量 Token 数组，无流式处理

**数据**：
- `TLexerResult.FTokens: array of TToken` 存储全部 token
- 每个 token 含 `LeadingTrivia` + `TrailingTrivia` 子数组
- 容量策略：初始估算 → 不足时 `×2` 扩容

**影响**：大文件（100,000+ tokens）内存占用高。Parser 无法流式消费 token。

---

### E-06 [🟠] Backend Plan — 纯元数据，无代码生成逻辑

**数据**：
- `np_backend_plan.pas` (636 行) — 管理 artifact 路径、library requests
- `TBackendPlanner.Plan` 不调用 LLVM emitter
- 无 IR→目标代码生成逻辑

**影响**：后端计划是元数据管理器，不是编译器后端。实际代码生成路径不明。

---

### E-07 [🔴] sema 零直接单元测试 — 最高风险模块无安全网

**数据**：
- `np_semantic_analyzer.pas`: 12,255 行，**0 个直接单元测试文件**
- 现有测试通过 34 个 compiler-pass 集成测试间接覆盖
- `test_semantic_hir_expr_producer.pas` (3,693 行) 测试 HIR 生成，非 sema 逻辑

**影响**：改动 sema 的任何方法 → 只能通过 34 个 compiler-pass 集成测试验证。无孤立测试 → 调试周期长。

---

### E-08 [🟡] 无 Profiler 数据 — 优化方向依赖猜测

**数据**：
- 无 heaptrc 报告
- 无 Valgrind/cachegrind 数据
- 无编译时间分解（lex% vs parse% vs sema% vs codegen%）

**影响**：优化方向依赖猜测而非数据。可能优化了占编译时间 1% 的代码。

---

### E-09 [🟡] Blob* 方法 — 284 处疑似遗留代码

**数据**：
- HIR Builder 中 284 处 `Blob*` 方法调用
- `BlobBinOp`, `BlobCmp`, `BlobZext`, `BlobUnaryOp` 等
- 命名暗示是"旧的 blob 代码生成"路径

**影响**：不清楚 Blob* 是活跃代码还是遗留。如果是遗留，占 HIR Builder 的很大比例。

---

### E-10 [🟠] TypeMetaFieldIndex — 双重循环 O(n×m)

**数据**：
```pascal
function TSemanticAnalyzer.TypeMetaFieldIndex(...)
  for I := 0 to Length(FTypeMetadataEntries) - 1 do
    if SameText(FTypes[...].Name, ATypeName) then
      for J := 0 to Length(Fields) - 1 do
        if SameText(Fields[J].Name, AFieldName) then
```

**影响**：每次字段访问触发 O(n×m) 查找。class 有 50 字段 × 100 类型 → 5000 次 `SameText`。

---

### E-11 [🟡] 字符串状态传递 — 脆弱接口

**数据**：
- 阶段间状态：`'ready'`, `'failure'`, `'deferred'` (字符串)
- 根类型名：`'unit'`, `'program'`, `'library'`, `'package'` (字符串)
- 无枚举类型、无 discriminated union

**影响**：拼写错误不会被编译器捕获。添加新状态需要 grep 全量代码。

---

### E-12 [🟡] HIR Types — htk 前缀重载

**数据**：
- `THIRTypeKind` 用 `htk` 前缀（htkVoid, htkInt...）
- `THIRInstrKind` 用 `hik` 前缀（hikAdd, hikCall...）
- `THIRTermKind` 也用 `htk` 前缀（htkReturn, htkBranch...）

**影响**：`htk` 同时表示类型和终止符，容易混淆。命名空间不够清晰。

---

### E-13 [🟠] ResolveTypeIdForOwner — 三次 fallback 查找

**数据**：
```pascal
TypeId := ResolveTypeIdForOwner(Name, OwnerUnitId);  // 尝试 1
if TypeId <= 0 then
  TypeId := ResolveTypeIdForOwner(Name, RootUnitId);  // 尝试 2
if TypeId <= 0 then
  TypeId := ResolveTypeId(Name);                       // 尝试 3
```

**影响**：每次类型解析最多 3 次 O(n) 查找。在 `GetParamSignature` 中每个参数触发此模式。

---

### E-14 [🟡] Green Tree node kind 枚举 — 53 个变体，无层次

**数据**：
- `TGreenNodeKind` 枚举 53 个变体，全部平铺
- 无分类（Expression/Statement/Declaration/Type）
- 匹配代码通过 case/if 链区分

**影响**：添加新节点类型需要修改所有 match 点。无 exhaustiveness 检查。

---

## 对标总结

| 维度 | nextPas 当前 | Clang/LLVM | Rust/rustc |
|------|-------------|------------|------------|
| Sema 结构 | 1 class, 279 方法 | 20+ 文件, 按主题拆分 | 10+ crate |
| IR 优化 | 0 pass | 70+ pass | 30+ pass |
| 增量编译 | 无 | 有 (modules) | 有 (incremental) |
| 并行编译 | 无 | 有 (-j) | 有 (codegen units) |
| AST 内存 | 独立堆分配 | Arena + BumpPtr | Arena + index |
| 错误恢复 | 无 | 有 | 有 |
| 测试覆盖 | 0.21x | >2x | >2x |
| 符号查找 | O(n) 线性 | 哈希表 | 哈希表 |

---

## 优先级建议

### 🔴 P0 — 阻塞自举/正确性

| # | Finding | 行动 |
|---|---------|------|
| A-04 | Permissive Overload | C8 后立即清理，实现正式重载解析 |
| C-03 | 无 Arena 分配 | 集成 core/mem TFastArena 到编译器 |

### 🟠 P1 — 严重影响开发效率

| # | Finding | 行动 |
|---|---------|------|
| B-01/E-01 | O(n) 线性查找 (647 SameText) | 引入哈希索引 (TDictionary) |
| B-05 | 无增量编译 | 实现符号表热缓存 |
| A-01 | God Class | 开始 Phase 1 拆分 (builtins) |
| D-01/E-07 | sema 零测试 | 建立 sema 单元测试框架 |

### 🟡 P2 — 中期改进

| # | Finding | 行动 |
|---|---------|------|
| B-06 | 无并行编译 | 拓扑序分层并行 |
| B-02/E-02 | 签名/TypeMeta 重复计算 | 缓存到语义模型 |
| C-01 | SetLength +1 (145 处) | 统一容量翻倍策略 |
| D-05 | LowerToMir 空操作 | 理清实际代码生成路径 |
| E-04 | FText 可变 | 修复 Green Tree 不可变性 |

### 🔵 P3 — 长期优化

| # | Finding | 行动 |
|---|---------|------|
| A-05 | 无 IR 优化 | 添加基础 HIR 优化 pass |
| C-02 | AST 节点堆分配 | Arena 化 Green Tree |
| B-07 | LLVM IR 字符串拼接 | StringBuilder/stream API |
| D-03 | 无结构化诊断 | LSP/sarif 输出 |
| D-02 | 无错误恢复 | 增量错误恢复 |
| E-09 | Blob* 遗留代码 | 审计并清理 |
| E-12 | htk 前缀重载 | 重命名消除歧义 |

---

## 治理关联

- 技术债看板: `docs/plans/debt-roadmap.md`
- 目标树: `docs/plans/goal-tree.md`
- 自举路线图: `docs/plans/selfhost-roadmap.md`

---

*审计方法：grep 量化 + 结构分析 + 业界对标。未运行 profiler，性能数据为静态估算。*
*建议下一步：在大型编译（全量 core/）上运行 heaptrc + Valgrind/cachegrind 获取实测数据。*

