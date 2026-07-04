# nextPas 编译器架构批判

> 日期：2026-07-05
> 范围：compiler/ 全部 49,667 行生产代码 (31 文件)
> 方法：架构哲学审视 + 业界对标 + 量化分析

---

## 一句话总结

**编译器没有把自己当成 nextPas 标准库的客户。**

标准库有 `THashMap`（O(1)），编译器用 `array of T` + `SameText`（O(n)）。
标准库有 `TVec<T>`（容量翻倍），编译器用 `SetLength(arr, Length(arr)+1)`（逐元素扩容）。
标准库有 `TFastArena`（64.8ns/alloc），编译器用 `TGreenNode = class`（堆分配）。

607,017 行标准库，编译器只用了 5 个模块。49,667 行编译器，全部数据结构自己重新实现。

**编译器在标准库旁边自己造轮子。**

---

## 数据基础

### 编译器全貌

| 指标 | 数值 |
|------|------|
| 生产文件 | 31 |
| 生产代码行数 | 49,667 |
| 测试文件 | 29 |
| 测试代码行数 | 10,289 |
| test/production 比 | **0.21x** |

### 文件集中度

| 文件 | 行数 | 占比 |
|------|------|------|
| np_semantic_analyzer.pas | 12,255 | 24.7% |
| np_hir_builder.pas | 7,092 | 14.3% |
| np_green_tree.pas | 5,379 | 10.8% |
| np_sema_runtime_expr.inc | 3,345 | 6.7% |
| np_compilation_session.pas | 2,554 | 5.1% |
| **5 文件合计** | **30,625** | **61.6%** |

### 全编译器反模式计数

| 反模式 | 数量 |
|--------|------|
| `SameText` 调用 | **647** |
| `for` 循环遍历动态数组 | **404** |
| `SetLength +1` 逐元素扩容 | **145** |
| 字符串拼接 | **1,125** |

### 标准库使用情况

编译器引用的标准库模块：

```
nextpas.core.text
nextpas.core.text.conv
nextpas.core.path
nextpas.core.os.env
nextpas.core.time
nextpas.core.base.utils
```

**5 个模块，占标准库 975 模块的 0.5%。**

编译器**没有使用**的标准库模块（但自己重新实现了等价功能）：

| 编译器自己实现的 | 标准库已有的 | 标准库优势 |
|-----------------|-------------|-----------|
| `array of TProcedureBodyEntry` + `SameText` 线性查找 | `THashMap<K,V>` | O(1) vs O(n) |
| `array of string` + `SetLength(arr, Length(arr)+1)` | `TVec<T>` | 容量翻倍 vs 逐元素扩容 |
| `TGreenNode = class` 堆分配 | `TFastArena` | 64.8ns + 批量释放 |
| `TDefineTable.IndexOf` O(n) | `THashSet<T>` | O(1) |
| `SameText` 字符串比较 | `TStringView` | 零拷贝 |

---

## 六个架构问题

### 问题一：TSemanticAnalyzer God Class — 279 方法，单一故障点

**数据**：
- 279 方法声明，183 方法实现
- 12,255 行单文件
- 60+ 私有字段共享可变状态
- 7+ 种职责混在一个 class：类型检查、重载解析、HIR 生成、字符串所有权、内置函数注册、运行时变量种子化、条件编译

**对标**：
- Clang Sema：`SemaDecl.cpp`, `SemaExpr.cpp`, `SemaOverload.cpp` 等 20+ 文件
- Rust typeck：10+ crate
- **nextPas**：1 个文件，1 个 class

**影响**：任何改动需要理解 12,000 行上下文。无法独立测试任何子功能。并行开发不可能。

---

### 问题二：全部查找都是 O(n) 线性扫描

**数据**：

```
FindTypeByName      → for I := 0 to Length(FTypes)-1      do SameText(...)
FindSymbolByName    → for I := 0 to Length(FSymbols)-1    do SameText(...)
LookupConstValue    → for I := 0 to Length(FConstValues)-1 do SameText(...)
GetTypeMetaByName   → for I := 0 to Length(FTypeMeta)-1   do SameText(...)
GetFieldMetaByName  → for I ... for J ...                  do SameText(...)  ← O(n×m)
GetVmtSlotByName    → for I ... for J ...                  do SameText(...)  ← O(n×m)
LookupProcedureBody → for I := 0 to Length(FProcBodies)-1 do SameText(...)
LookupOverload      → for I := 0 to Length(FProcBodies)-1 do SameText(...)
HasOverload         → for I := 0 to Length(FProcBodies)-1 do SameText(...)
TDefineTable.IndexOf → for I := 0 to FCount-1             do ...
```

**全编译器 647 处 `SameText`，404 处数组遍历。没有一处使用哈希表。**

**量化**：编译 1000 单元 × 200 符号/单元，每次 O(n) 遍历 → 40,000,000 次 `SameText`。每次 ~100ns → 纯字符串比较 4 秒。

---

### 问题三：SetLength+1 逐元素扩容 — 145 处

**数据**：

```pascal
SetLength(SeenTypeIds, Length(SeenTypeIds) + 1);    // sema
SetLength(ACandidates, Length(ACandidates) + 1);     // sema
SetLength(Result, Length(Result) + 1);               // sema
SetLength(Meta.Fields, Length(Meta.Fields) + 1);     // sema
SetLength(Meta.VmtSlots, Meta.VmtCount + 1);         // sema
SetLength(SubConstraints, Length(SubConstraints)+1); // sema
SetLength(ArgNames, Length(ArgNames) + 1);           // sema
// ... 145 处全编译器
```

每次 `SetLength +1` 触发 `ReAllocMem` + 全量元素复制。添加 1000 个字段 → 1000 次重分配 + ~500,000 次元素复制。

标准库 `TVec<T>` 用容量翻倍策略，摊销 O(1)。编译器不用。

---

### 问题四：Pipeline 边界模糊 — sema 直接生成 HIR

**数据**：
- sema 包含 `BuildRuntime*` 系列方法（`np_sema_runtime_expr.inc`, 3,345 行）
- HIR Builder (`np_hir_builder.pas`, 7,092 行) 退化为被动数据结构填充器
- sema 直接构造 `TSemanticHirExpr` 节点

**LLVM 标准架构**：Frontend → IR → Optimizer → Backend，严格分层。
**nextPas**：sema 跨越 Frontend + IR 两层。无法在 sema 和 IR 之间插入优化 pass。

---

### 问题五：.inc 文件伪装模块化

**数据**：
- `np_sema_string_ops.inc` (2,243 行) — 是 `TSemanticAnalyzer` 的方法
- `np_sema_runtime_expr.inc` (3,345 行) — 是 `TSemanticAnalyzer` 的方法
- 两者共享 `TSemanticAnalyzer` 的 60+ 私有字段

`.inc` 是 Pascal 的 `#include`。物理上分开了，逻辑上仍然是同一个 God Class。无法独立编译、测试或理解。

---

### 问题六：Permissive Overload — 15+ 处工程妥协

```pascal
{ Permissive: pick first exact match instead of failing }
{ Permissive: pick first compatible match instead of failing }
{ Permissive: suppress ambiguous-overload errors for C8 pass }
```

C8 冲刺的临时方案，现在埋在 12,000 行文件中。编译器可能接受错误代码、拒绝正确代码、或在多候选时产生不确定行为。

---

## 根因分析

**这些问题有一个共同的根因：编译器在 C0-C7 冲刺中快速堆砌功能，没有把标准库当作自己的基础设施。**

```
C0-C7 冲刺的隐含假设：    实际应该：
"先把功能做出来"          "用标准库做功能"
"array of T 够用了"       "TVec<T> 已经写好了"
"SameText 遍历就行"       "THashMap 是 O(1)"
"class 分配简单"          "TFastArena 64.8ns"
```

结果：编译器 49,667 行代码中，数据结构、内存管理、查找算法全部自己实现。标准库 607,017 行代码在旁边闲置。

---

## 对标

| 维度 | nextPas 编译器 | Clang/LLVM | Rust/rustc |
|------|---------------|------------|------------|
| Sema 结构 | 1 class, 279 方法 | 20+ 文件 | 10+ crate |
| 符号查找 | O(n) SameText | 哈希表 | 哈希表 |
| IR 优化 | 0 pass | 70+ pass | 30+ pass |
| 增量编译 | 无 | 有 (modules) | 有 (incremental) |
| AST 内存 | class 堆分配 | Arena + BumpPtr | Arena + index |
| 错误恢复 | 无 | 有 | 有 |
| 测试覆盖 | 0.21x | >2x | >2x |
| 用自己标准库 | 否 (0.5%) | 是 (LLVM 用 ADT) | 是 (rustc 用 std) |

---

## 修复路线

###   P0 — 立即可做（本月，不改架构）

| 行动 | 效果 |
|------|------|
| 编译器接入 `THashMap` 替换 O(n) 查找 | 编译速度立即提升 |
| 编译器接入 `TVec<T>` 替换 SetLength+1 | 消除 145 处逐元素扩容 |
| 编译器接入 `TFastArena` 管理 AST 节点 | 减少 80% 堆分配 |

###   P1 — 架构偿还（1-2 月）

| 行动 | 效果 |
|------|------|
| sema God Class 拆分 (builtins → string_ownership → overload → hir_lowering) | 降低改动风险 |
| .inc → 独立 unit | 消除伪模块化 |
| permissive overload → 正式重载解析 | 正确性 |

###   P2 — 能力补全（2-4 月）

| 行动 | 效果 |
|------|------|
| 增量编译（符号表热缓存） | 开发迭代 <1s |
| 基础 HIR 优化 pass | 生成代码质量 |
| sema 单元测试覆盖 | 重构安全网 |

---

## 治理关联

- 编译器 findings: `docs/plans/compiler-findings.md`
- 技术债看板: `docs/plans/debt-roadmap.md`
- 目标树: `docs/plans/goal-tree.md`

---

*这份 critique 只针对编译器。标准库（nextpas.core）有自己的考量，不在本文件范围。*
