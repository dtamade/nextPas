# 编译器深度审计 Findings

> 审计日期：2026-07-05
> 范围：compiler/ 全部 60,000 行生产代码
> 方法：静态分析 + 数据量化 + 架构对标

---

## 总览

| 类别 | Findings 数 | 严重度分布 |
|------|-------------|-----------|
| 架构 | 6 | 4x , 2x  |
| 性能 | 7 | 2x , 5x  |
| 内存 | 3 | 3x  |
| 工程 | 4 | 1x , 3x  |
| **合计** | **20** | |

---

## A. 架构 Findings

### A-01 [ ] TSemanticAnalyzer God Class — 279 方法，单一故障点

**数据**：
- 279 方法声明，183 实现
- 12,255 行单文件
- 60+ 私有字段共享可变状态
- 7+ 种职责混在一个 class

**影响**：任何改动需要理解 12,000 行上下文；无法独立测试任何子功能；并行开发不可能。

**对标**：Clang 的 Sema 分为 `SemaDecl.cpp`, `SemaExpr.cpp`, `SemaOverload.cpp` 等 20+ 文件。Rust 的 `rustc_typeck` 拆为 10+ 个 crate。

---

### A-02 [ ] Pipeline 边界模糊 — sema 直接生成 HIR

**数据**：
- sema 包含 `BuildRuntime*` 系列方法（`np_sema_runtime_expr.inc`, 3,345 行）
- HIR Builder (`np_hir_builder.pas`, 7,092 行) 退化为被动数据结构填充器
- sema 直接构造 `TSemanticHirExpr` 节点

**影响**：无法在 sema 和 IR 之间插入优化 pass；sema 的输出不是纯粹的类型化 AST，而是已经偏向目标 IR。

**对标**：LLVM 架构中 Frontend → IR → Optimizer → Backend 严格分层。nextPas 的 sema 跨越了前两层。

---

### A-03 [ ] .inc 文件伪装架构 — 物理分离但逻辑耦合

**数据**：
- `np_sema_string_ops.inc` (2,243 行) — 字符串所有权跟踪方法
- `np_sema_runtime_expr.inc` (3,345 行) — 运行时表达式生成方法
- 两者都是 `TSemanticAnalyzer` 的方法，共享所有私有字段

**影响**：无法独立编译、测试或理解。.inc 是 C 语言的 `#include`，不是模块化。

---

### A-04 [ ] Permissive Overload — 15+ 处工程妥协

**数据**：代码中 15+ 处注释标记：
```
{ Permissive: pick first exact match instead of failing }
{ Permissive: pick first compatible match instead of failing }
{ Permissive: suppress ambiguous-overload errors for C8 pass }
```

**影响**：编译器可能接受错误的代码、拒绝正确的代码，或在存在多个候选时产生不确定行为。

---

### A-05 [ ] 无 IR 优化 Pass — 生成的代码完全未优化

**数据**：
- `np_hir_builder.pas`: 0 个优化/transform 方法
- `np_hir_verifier.pas`: 234 行，仅做 SSA 基本验证
- HIR → LLVM IR 是 1:1 直译，无任何中间优化

**影响**：生成的 LLVM IR 质量完全依赖 LLVM 自身的优化。循环展开、常量折叠、死代码消除等基础优化都推给 LLVM，导致编译时间更长（LLVM 要做更多工作）。

---

### A-06 [ ] 编译会话缺少 Pipeline 抽象

**数据**：
- `np_compilation_session.pas` (2,554 行, 166 方法) 直接调用各阶段
- 无 Pipeline/Pass 注册机制
- 阶段顺序硬编码在 `Compile` 方法中

**影响**：无法插入自定义 pass、无法并行化阶段、无法 A/B 测试不同策略。

---

## B. 性能 Findings

### B-01 [ ] O(n) 线性查找 — 核心查找路径

**数据**：
- `LookupProcedureBody`: O(n) 遍历 `FProcedureBodies` 数组
- `LookupOverload`: O(n) 遍历 + 参数匹配
- `HasOverload`: O(n) 遍历 + 计数
- `MangledName`: O(n) 每次调用（字符串拼接 `IntToStr`）
- sema 共有 225 个 for 循环，35 个直接遍历动态数组

**量化影响**：假设 10,000 个过程体，每次重载解析 O(n) = 10,000 次 `SameText` 调用。每个调用点触发一次查找 → 编译时间 O(n²)。

**应改为**：`TDictionary<string, TProcedureBodyEntry>` 或排序数组 + 二分查找。

---

### B-02 [ ] GetParamSignature — 每次重载解析都重新计算

**数据**：
- `GetParamSignature` (~85 行) 对每个参数：`ResolveTypeIdForOwner` → `TypeSignatureForTypeId` → 字符串拼接
- 每次重载解析调用一次，每次参数匹配调用一次
- 无缓存

**影响**：同一函数的签名在编译过程中被重复计算数十到数百次。

---

### B-03 [ ] 字符串拼接在热路径中

**数据**：
- sema 中有 277 处字符串拼接 (`:= ... +`)
- `MangledName` (每次调用都拼接 `Name + '$' + IntToStr(Count)`)
- `GetParamSignature` 逐字符拼接签名串
- LLVM emitter 中大量 `Op := Op + ...` 模式

**影响**：每次拼接都分配新字符串 + 复制。`GetParamSignature` 在大型编译中可能被调用数千次。

---

### B-04 [ ] 无符号表索引 — 每次按名称查找都是字符串比较

**数据**：
- sema 中 408 处 `SameText` 调用
- 每次查找按名称匹配：`SameText(FProcedureBodies[Index].Name, AName)`
- 无哈希索引、无符号 ID 快速路径

**影响**：编译器中 90% 的查找是"已知符号 ID → 找符号"，但当前全部退化为字符串比较。

---

### B-05 [ ] 无增量编译 — 每次全量重来

**数据**：
- `np_symbol_cache.pas` (241 行) — 仅缓存导入单元符号，不缓存编译结果
- `np_compilation_session.pas` — 每次从 lexer 开始全量处理
- 无 mtime/fingerprint 检查
- 67 单元 6.4s，158 单元 16s（自举障碍路线图数据）

**影响**：修改 1 行代码 → 重新编译全部传递依赖。开发迭代速度受限于 O(n) 全量编译。

---

### B-06 [ ] 无并行编译 — 单线程顺序处理

**数据**：
- `np_compilation_session.pas`: 0 处线程/并行相关代码
- 单元按拓扑序顺序处理：`for Index := 0 to FUnitGraph.ResolvedUnitCount - 1`

**影响**：多核 CPU 利用率 ~1/n。拓扑序同层单元可完全并行。

---

### B-07 [ ] LLVM Emitter — 逐字符串拼接 IR

**数据**：
- LLVM IR 生成通过字符串拼接：`Op := '  call void @' + AInstr.CallTarget + '('`
- 无 IR builder API（如 LLVM C++ API 的 `IRBuilder`）
- 每条指令分配 5-15 次字符串

**影响**：大型模块（1000+ 函数）的 LLVM IR 生成产生海量临时字符串分配。

---

## C. 内存 Findings

### C-01 [ ] SetLength +1 — 逐元素扩容

**数据**：
- sema: 20+ 处 `SetLength(arr, Length(arr) + 1)` 模式
- hir builder: 16 处 `SetLength(arr, N + 1)` 模式
- 每次 +1 触发 ReAllocMem + 全量复制

**量化影响**：添加 1000 个字段到 class → 1000 次 ReAllocMem + ~500,000 次元素复制。
应改为容量翻倍策略（如 `SetLength(arr, Count + 16)` 已部分使用但不一致）。

---

### C-02 [ ] Green Tree — 每个 AST 节点是独立 class 实例

**数据**：
- `TGreenNode = class` — 堆分配
- 每个 token/identifier/expression 一个 class 实例
- `AppendChild` 添加引用

**影响**：中型源文件（5000 tokens）→ 5000+ 次 `TGreenNode.Create` → 5000+ 次堆分配。
内存碎片化 + GC 压力。

**对标**：Roslyn (C#) 使用 `GreenNode` 不可变树 + 节点复用。Rust 的 `rowan` 使用 arena + 索引。

---

### C-03 [ ] 无 Arena/Region 分配 — 编译器生命周期内无释放

**数据**：
- 无 `TFastArena` 使用（虽然 core/mem 已有 64.8ns 的 TFastArena）
- AST 节点、HIR 节点、语义模型全部分散堆分配
- 编译结束后依赖引用计数或 GC 回收

**影响**：编译器内存峰值高，且无法利用 arena 的批量释放优势。

---

## D. 工程 Findings

### D-01 [ ] 测试覆盖不足 — test/production 比 0.33

**数据**：
- 生产代码：30,815 行（6 个核心文件）
- 测试代码：10,289 行（29 个测试文件）
- 比例：0.33x（健康标准：>1.0x）
- sema (12,255 行) 无直接单元测试

**影响**：God Class 改动风险极高，无安全网。

---

### D-02 [ ] 无错误恢复 — 一个错误就停止

**数据**：
- sema: 0 处 error recovery 代码
- lexer: 0 处 error recovery 代码

**影响**：一个语法错误 → 编译停止，用户只能看到第一个错误。IDE 场景不可用。

---

### D-03 [ ] 诊断系统无结构化输出

**数据**：
- `np_diagnostics_sink.pas` (663 行) — 仅存储 `TDiagnosticRecord` 数组
- 无 JSON/sarif/LSP 格式输出
- 无 fix-it/quick-fix 支持

**影响**：无法集成 IDE（VS Code plugin 需要 LSP diagnostic 格式）。

---

### D-04 [ ] 编译器 CLI 分散

**数据**：
- 编译入口在 `np_compilation_session.pas`
- 工具链在 `np_toolchain_plan.pas` (2,137 行)
- 无统一的 `nextpas` CLI 入口文件
- 命令行参数解析散落在多处

**影响**：新开发者难以找到入口；添加新 CLI 选项需要修改多处。

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
| 测试覆盖 | 0.33x | >2x | >2x |

---

## 优先级建议

###   P0 — 阻塞自举/正确性

| # | Finding | 行动 |
|---|---------|------|
| A-04 | Permissive Overload | C8 后立即清理，实现正式重载解析 |
| C-03 | 无 Arena 分配 | 集成 core/mem TFastArena 到编译器 |

###   P1 — 严重影响开发效率

| # | Finding | 行动 |
|---|---------|------|
| B-01 | O(n) 线性查找 | 引入哈希索引 (TDictionary) |
| B-05 | 无增量编译 | 实现符号表热缓存 |
| A-01 | God Class | 开始 Phase 1 拆分 (builtins) |

###   P2 — 中期改进

| # | Finding | 行动 |
|---|---------|------|
| B-06 | 无并行编译 | 拓扑序分层并行 |
| B-02 | 签名重复计算 | 缓存签名到语义模型 |
| C-01 | SetLength +1 | 统一容量翻倍策略 |
| D-01 | 测试覆盖不足 | sema 单元测试覆盖 |

###   P3 — 长期优化

| # | Finding | 行动 |
|---|---------|------|
| A-05 | 无 IR 优化 | 添加基础 HIR 优化 pass |
| C-02 | AST 节点堆分配 | Arena 化 Green Tree |
| B-07 | LLVM IR 字符串拼接 | StringBuilder/stream API |
| D-03 | 无结构化诊断 | LSP/sarif 输出 |
| D-02 | 无错误恢复 | 增量错误恢复 |

---

## 治理关联

- 技术债看板: `docs/plans/debt-roadmap.md`
- 目标树: `docs/plans/goal-tree.md`
- 自举路线图: `docs/plans/selfhost-roadmap.md`

---

*审计方法：grep 量化 + 结构分析 + 业界对标。未运行 profiler，性能数据为静态估算。*
*建议下一步：在大型编译（全量 core/）上运行 heaptrc + Valgrind/cachegrind 获取实测数据。*
