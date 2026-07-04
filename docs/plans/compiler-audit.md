<!-- 编译器完整审计报告 -->
<!-- 合并自 compiler-findings.md + compiler-architecture-critique.md -->
<!-- 版本: v1.0 | 日期: 2026-07-05 | 来源: 两轮深度扫描 + 架构哲学审视 -->

# nextPas 编译器完整审计

> **单一真相来源 (Single Source of Truth)**
> 本文件合并了 `compiler-findings.md`（36条量化发现）和 `compiler-architecture-critique.md`（架构哲学审视）。
> 两份旧文件已归档，请只维护这一份。
>
> 关联文档：
> - 行动计划: `compiler-architecture-plan.md`（15周 5阶段）
> - 技术债看板: `debt-roadmap.md`
> - 目标树: `goal-tree.md`

---

## 零、核心诊断：编译器不用标准库

**编译器没有把自己当成 nextPas 标准库的客户。**

| 编译器自己实现的 | 标准库已有的 | 标准库优势 |
|-----------------|-------------|-----------|
| `array of T` + `SameText` 线性查找 | `THashMap<K,V>` | O(1) vs O(n) |
| `SetLength(arr, Length(arr)+1)` | `TVec<T>` | 容量翻倍 vs 逐元素扩容 |
| `TGreenNode = class` 堆分配 | `TFastArena` | 64.8ns + 批量释放 |
| `TDefineTable.IndexOf` O(n) | `THashSet<T>` | O(1) |
| `SameText` 字符串比较 | `TStringView` | 零拷贝 |

**编译器引用标准库模块：5 个（占 975 模块的 0.5%）**
**编译器 49,667 行代码中，数据结构、内存管理、查找算法全部自己实现。**

```
C0-C7 冲刺的隐含假设：    实际应该：
"先把功能做出来"          "用标准库做功能"
"array of T 够用了"       "TVec<T> 已经写好了"
"SameText 遍历就行"       "THashMap 是 O(1)"
"class 分配简单"          "TFastArena 64.8ns"
```

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

## 一、架构 Findings (6)

### A-01 [🔴] TSemanticAnalyzer God Class — 279 方法，单一故障点

- 279 方法声明，183 实现，12,255 行单文件
- 60+ 私有字段共享可变状态
- 7+ 种职责混在一个 class：类型检查、重载解析、HIR 生成、字符串所有权、内置函数注册、运行时变量种子化、条件编译
- **对标**：Clang Sema 分 `SemaDecl.cpp`, `SemaExpr.cpp`, `SemaOverload.cpp` 等 20+ 文件。Rust typeck 拆为 10+ crate。
- **行动计划**：`compiler-architecture-plan.md` 阶段 1.2（5 阶段拆分）

### A-02 [🔴] Pipeline 边界模糊 — sema 直接生成 HIR

- sema 包含 `BuildRuntime*` 系列方法（`np_sema_runtime_expr.inc`, 3,345 行）
- HIR Builder 退化为被动数据结构填充器
- **对标**：LLVM 标准架构 Frontend → IR → Optimizer → Backend 严格分层
- **行动计划**：`compiler-architecture-plan.md` 阶段 1.3（引入 MIR 层）

### A-03 [🔴] .inc 文件伪装架构 — 物理分离但逻辑耦合

- `np_sema_string_ops.inc` (2,243 行) — 字符串所有权跟踪方法
- `np_sema_runtime_expr.inc` (3,345 行) — 运行时表达式生成方法
- 两者都是 `TSemanticAnalyzer` 的方法，共享所有私有字段
- **行动计划**：`compiler-architecture-plan.md` 阶段 1.2（改为独立 unit）

### A-04 [🔴] Permissive Overload — 15+ 处工程妥协

- 代码中 15+ 处 `{ Permissive: ... }` 注释标记
- 编译器可能接受错误代码、拒绝正确代码、产生不确定行为
- **行动计划**：`compiler-architecture-plan.md` 阶段 4.1

### A-05 [🟠] 无 IR 优化 Pass — 生成的代码完全未优化

- HIR → LLVM IR 是 1:1 直译，无任何中间优化
- **行动计划**：`compiler-architecture-plan.md` 阶段 3.1（6 个 MIR 优化 pass）

### A-06 [🟠] 编译会话缺少 Pipeline 抽象

- 阶段顺序硬编码在方法调用中，无 Pipeline/Pass 注册机制
- **行动计划**：`compiler-architecture-plan.md` 阶段 1.1（Pipeline 接口化）

---

## 二、性能 Findings (7)

### B-01 [🔴] O(n) 线性查找 — 核心查找路径

- `LookupProcedureBody`, `LookupOverload`, `HasOverload`, `MangledName` 全部 O(n)
- 全编译器: 647 处 `SameText`，404 处数组遍历
- **量化**：编译 1000 单元 × 200 符号/单元，每次 O(n) 遍历 → 40,000,000 次 `SameText`。每次 ~100ns → 纯字符串比较 4 秒
- **行动计划**：`compiler-architecture-plan.md` 阶段 0.1（THashMap 替换）

### B-02 [🟠] GetParamSignature — 每次重载解析都重新计算

- 无缓存，同一函数签名重复计算数十到数百次
- **行动计划**：缓存到语义模型（P1 优化）

### B-03 [🟠] 字符串拼接在热路径中 — 1,125 处

- `MangledName` 每次调用拼接 `Name + '$' + IntToStr(Count)`
- LLVM emitter 大量 `Op := Op + ...` 模式
- **行动计划**：阶段 0.2（TVec + StringBuilder）

### B-04 [🟠] 无符号表索引 — 每次按名称查找都是字符串比较

- sema 中 408 处 `SameText`，无哈希索引、无符号 ID 快速路径
- **行动计划**：阶段 0.1（THashMap）

### B-05 [🔴] 无增量编译 — 每次全量重来

- 67 单元 6.4s，158 单元 16s
- **行动计划**：`compiler-architecture-plan.md` 阶段 2.2

### B-06 [🟠] 无并行编译 — 单线程顺序处理

- 0 处线程/并行相关代码
- **行动计划**：`compiler-architecture-plan.md` 阶段 2.3

### B-07 [🟠] LLVM Emitter — 逐字符串拼接 IR

- 每条指令分配 5-15 次字符串
- **行动计划**：阶段 3（MIR 优化后自然解决）

---

## 三、内存 Findings (3)

### C-01 [🟠] SetLength +1 — 逐元素扩容（145 处）

- 每次 +1 触发 ReAllocMem + 全量复制
- 添加 1000 个字段 → 1000 次重分配 + ~500,000 次元素复制
- **行动计划**：阶段 0.2（TVec<T> 替换）

### C-02 [🟠] Green Tree — 每个 AST 节点是独立 class 实例

- 中型源文件（5000 tokens）→ 5000+ 次堆分配
- **对标**：Roslyn (C#) 用不可变树 + 节点复用。Rust rowan 用 arena + 索引
- **行动计划**：阶段 0.3（Arena 分配）

### C-03 [🟠] 无 Arena/Region 分配 — 编译器生命周期内无释放

- core/mem 已有 64.8ns 的 TFastArena，编译器不用
- **行动计划**：阶段 0.3

---

## 四、工程 Findings (6)

### D-01 [🔴] 测试覆盖严重不足 — test/production 比 0.21x

- 生产代码 49,667 行 vs 测试 10,289 行
- sema (12,255 行) **0 个直接单元测试**
- **行动计划**：阶段 4.3（sema 单元测试补全）

### D-02 [🟡] 无错误恢复 — 一个错误就停止

- sema 和 lexer 均 0 处 error recovery
- **行动计划**：阶段 3.2

### D-03 [🟡] 诊断系统无结构化输出

- 无 JSON/sarif/LSP 格式输出，无 fix-it/quick-fix
- **行动计划**：阶段 3.3

### D-04 [🟡] 编译器 CLI 分散

- 编译入口、工具链、命令行参数解析散落多处
- **行动计划**：阶段 1 统一

### D-05 [🟡] LowerToMir — HIR 构建仅在调试模式执行

- 正常编译路径 `LowerToMir` 是空操作，实际代码生成路径不明
- **行动计划**：阶段 1.3（MIR 层解决）

### D-06 [🟡] Pipeline 阶段间字符串状态传递

- 阶段间通过 `Status = 'ready'` / `'failure'` 字符串传递
- **行动计划**：阶段 1.1（枚举/接口替代）

---

## 五、第二轮深度扫描 (14)

### E-01 [🔴] SemanticModel — 全部查找 O(n) 线性扫描

- `FindTypeByName`, `FindSymbolByName`, `LookupConstValue`, `GetTypeMetaByName` 全部 O(n)
- `GetFieldMetaByName`, `GetVmtSlotByName` 为 O(n×m) 双重循环

### E-02 [🟠] TypeMeta 重复查询 — 无缓存

- 15+ 个 `TypeMeta*` 方法，每个独立调用 `GetTypeMetaByName` → O(n)
- 同一类型被重复查询数十次

### E-03 [🟡] TDefineTable — 预处理器 define 查找 O(n)

- `IndexOf`: O(n) 遍历 + 每次 `UpperCase`
- 每次 `{$IFDEF}` 评估触发

### E-04 [🟠] Green Tree — FText 可变，破坏不可变性

- 20+ 处直接修改 `FText`：`NameNode.FText := NameNode.FText + SpecArgs`
- 不可变树的核心优势（节点复用、并发安全）被破坏

### E-05 [🟡] Lexer — 全量 Token 数组，无流式处理

- `TLexerResult.FTokens` 存储全部 token，大文件内存占用高

### E-06 [🟠] Backend Plan — 纯元数据，无代码生成逻辑

- `TBackendPlanner.Plan` 不调用 LLVM emitter
- 后端计划是元数据管理器，不是编译器后端

### E-07 [🔴] sema 零直接单元测试 — 最高风险模块无安全网

- 12,255 行，0 个直接单元测试文件
- 现有测试通过 34 个 compiler-pass 集成测试间接覆盖

### E-08 [🟡] 无 Profiler 数据 — 优化方向依赖猜测

- 无 heaptrc 报告、无 Valgrind/cachegrind 数据、无编译时间分解

### E-09 [🟡] Blob* 方法 — 284 处疑似遗留代码

- HIR Builder 中 284 处 `Blob*` 方法调用
- 不清楚是活跃代码还是遗留

### E-10 [🟠] TypeMetaFieldIndex — 双重循环 O(n×m)

- class 有 50 字段 × 100 类型 → 5000 次 `SameText`

### E-11 [🟡] 字符串状态传递 — 脆弱接口

- 阶段间状态用字符串 `'ready'`, `'failure'`, `'deferred'`
- 拼写错误不会被编译器捕获

### E-12 [🟡] HIR Types — htk 前缀重载

- `THIRTypeKind` 用 `htk` 前缀，`THIRTermKind` 也用 `htk` 前缀
- 容易混淆

### E-13 [🟠] ResolveTypeIdForOwner — 三次 fallback 查找

- 每次类型解析最多 3 次 O(n) 查找

### E-14 [🟡] Green Tree node kind 枚举 — 53 个变体，无层次

- 无分类（Expression/Statement/Declaration/Type），匹配通过 case/if 链

---

## 六、对标总结

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
| 用自己标准库 | 否 (0.5%) | 是 (LLVM 用 ADT) | 是 (rustc 用 std) |

---

## 七、优先级建议

### 🔴 P0 — 阻塞自举/正确性

| # | Finding | 行动 | 计划阶段 |
|---|---------|------|---------|
| A-04 | Permissive Overload | 实现正式重载解析 | 4.1 |
| C-03 | 无 Arena 分配 | 集成 core/mem TFastArena | 0.3 |

### 🟠 P1 — 严重影响开发效率

| # | Finding | 行动 | 计划阶段 |
|---|---------|------|---------|
| B-01/E-01 | O(n) 线性查找 (647 SameText) | 引入 THashMap | 0.1 |
| B-05 | 无增量编译 | 实现符号表热缓存 | 2.2 |
| A-01 | God Class | 开始 Phase 1 拆分 (builtins) | 1.2 |
| D-01/E-07 | sema 零测试 | 建立 sema 单元测试框架 | 4.3 |

### 🟡 P2 — 中期改进

| # | Finding | 行动 | 计划阶段 |
|---|---------|------|---------|
| B-06 | 无并行编译 | 拓扑序分层并行 | 2.3 |
| B-02/E-02 | 签名/TypeMeta 重复计算 | 缓存到语义模型 | 1 |
| C-01 | SetLength +1 (145 处) | TVec<T> 替换 | 0.2 |
| D-05 | LowerToMir 空操作 | 理清实际代码生成路径 | 1.3 |
| E-04 | FText 可变 | 修复 Green Tree 不可变性 | 1 |

### 🔵 P3 — 长期优化

| # | Finding | 行动 | 计划阶段 |
|---|---------|------|---------|
| A-05 | 无 IR 优化 | 添加基础 MIR 优化 pass | 3.1 |
| C-02 | AST 节点堆分配 | Arena 化 Green Tree | 0.3 |
| B-07 | LLVM IR 字符串拼接 | MIR 后自然解决 | 3 |
| D-03 | 无结构化诊断 | LSP/sarif 输出 | 3.3 |
| D-02 | 无错误恢复 | 增量错误恢复 | 3.2 |
| E-09 | Blob* 遗留代码 | 审计并清理 | 4.2 |
| E-12 | htk 前缀重载 | 重命名消除歧义 | 4 |

---

## 八、治理关联

- **行动计划**: `docs/plans/compiler-architecture-plan.md`（15周 5阶段）
- **技术债看板**: `docs/plans/debt-roadmap.md`
- **目标树**: `docs/plans/goal-tree.md`
- **自举路线图**: `docs/plans/selfhost-roadmap.md`

---

*审计方法：grep 量化 + 结构分析 + 业界对标。未运行 profiler，性能数据为静态估算。*
*建议下一步：在大型编译（全量 core/）上运行 heaptrc + Valgrind/cachegrind 获取实测数据。*
*最后更新：2026-07-05*
