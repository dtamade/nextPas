# nextPas 编译器路线图修订（2026-06-25）

> 基于 C5-P 完成后的实际状态和最近 bug fix 暴露的问题，修订目标树 C5-C8 的优先级和拆分。

**当前状态：** ✅ C5 已完成（2026-06-27），C6 已推进到 H17（owned string return 的 class field store）。最近修了两个编译器 bug：sret codegen（字符串返回函数）和 class field string ops LLVM emission。

---

## 修订 1：C5 收口定义

### 问题

C5 完成了 A-P 共 16 个子节点，但目标树中状态仍为 `🚧 C5-O`，缺少明确的完成标准。

### 建议

C5 收口只需再完成 **两个子节点**：

| 节点 | 内容 | 预估 |
|------|------|------|
| **C5-Q** | `WalkHaltCalls` 剩余 special-case 清理：constructor-like / raw object-dot / pointer-return helper call | 1-2 轮 |
| **C5-R** | C5 exit criteria checklist：确认所有已迁移 producer 的 dual-track 覆盖率、补齐 C5-A 到 C5-P 遗漏的 focused tests | 1 轮 |

**C5 完成定义：**
- 137 LLVM smoke 全绿
- `test_semantic_hir_expr_producer` 全绿
- `test_hir_builder_structured_address` / `test_hir_builder_structured_expr` / `test_hir_builder_expr_fallback` 全绿
- `WalkHaltCalls` 不再有未分类的 special-case 分叉
- 旧 blob fallback 在所有已迁移路径上均可回退

**明确不在 C5 范围内（留给 C7/C8）：**
- property-like read/write
- record/string return 的 call ABI 升级
- overload resolution 结构化

---

## 修订 2：C6 拆分为 C6-A（allocator）和 C6-B（string ownership 收尾）

### 问题

当前 C6 混杂了两个不同性质的问题：
1. **allocator**：替换 bump allocator，实现真实 malloc/free（架构债务4）
2. **string ownership**：完善字符串所有权语义（C6-H7 到 H17 已在做）

Allocator 是自举的硬依赖（没有 free 就无法编译大型模块），string ownership 可以渐进完善。

### 建议

```
C6-A: allocator（真实 malloc/free + coalesce）
  - 依赖：C5 收口
  - 优先级：最高（自举 blocker）
  - 预估：2-3 轮

C6-B: string ownership 收尾
  - 依赖：C6-A（需要真实 free 来释放 string owner）
  - 优先级：高
  - 预估：2-3 轮
  - 包含：C6-H17 的 GREEN-2B/GREEN-3 收尾、record field string store、
    array element string store、string field cleanup on object free
```

**C6-A 的具体内容：**
- 用 mmap + free list + coalesce 替换 bump allocator
- 所有 `np_alloc` 调用改为可释放
- `np_free` 真正归还内存
- object/dynarray/string 释放路径接入 allocator
- 验证：分配/释放循环无泄漏、coalesce 正常工作

---

## 修订 3：C7-prep（opt level 可配置）提前

### 问题

C7（多目标/优化）被放在 C5,C6 之后，但其中的 LLVM O2/LTO 可配置化改动极小且独立。

### 建议

在 C5 收口后、C6-A 之前，插入一个微小节点：

| 节点 | 内容 | 预估 |
|------|------|------|
| **C7-prep** | LLVM opt level 从硬编码改为 toml/target-facts 驱动 | 0.5 轮 |

**理由：**
- 改动量极小（emitter 一处 + target toml 一个字段）
- 调试时可以在 O0/O2 之间切换，极大提升开发效率
- 不影响任何现有测试
- 避免以后"怎么又是硬编码"的返工

---

## 修订 4：C8 自举探针前移

### 问题

C8 被放在 C5,C6,C7 之后，但实际上自举探针（用 nextPas 编译 `core/` 一个真实模块）可以在 C6-A 完成后立即进行，不需要等 C6-B 和 C7 全部完成。

### 建议

C8 拆为两步：

| 节点 | 内容 | 预估 |
|------|------|------|
| **C8-prep** | C6-A 完成后，用 nextPas 编译 `core/` 一个中等模块，产出"自举差距清单" | 1 轮 |
| **C8** | 根据差距清单逐一修复，直到自举成功 | 多轮 |

---

## 修订后的路线图

```
                    ┌─────────────┐
                    │  C5 ✅ 完成  │  ← 2026-06-27
                    │  Q+R 已验证  │  
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ C7-prep  │ │ C6-A     │ │ 提交 C5  │
        │ opt可配置 │ │ allocator│ │ bug fix  │
        │  0.5轮   │ │  2-3轮   │ │ 到主线   │
        └──────────┘ └────┬─────┘ └──────────┘
                          │
                     ┌────┴────┐
                     ▼         ▼
               ┌──────────┐ ┌──────────┐
               │ C8-prep  │ │ C6-B     │
               │ 自举探针  │ │ string   │
               │  1轮     │ │ ownership│
               └────┬─────┘ │  2-3轮   │
                    │       └──────────┘
                    ▼
              ┌──────────┐
              │ C8       │
              │ 自举     │
              │ 多轮     │
              └──────────┘
```

**关键路径：C5 ✅ → C7-prep → C6-A → C8-prep → C8**
**并行路径：C7-prep（微小独立）、C6-B（可延后）**

---

## 与目标树的差异总结

| 原目标树 | 修订后 | 理由 |
|----------|--------|------|
| C5 状态 O | ✅ C5 完成 (2026-06-27) | test_semantic_hir_expr_producer exit=0 已解决 |
| C6 = allocator + optimization | C6-A = allocator, C6-B = string ownership | 拆分关注点 |
| C7 在 C5,C6 之后 | C7-prep 提前到 C5 后立即做 | 微小独立，提升效率 |
| C8 在 C5,C6,C7 之后 | C8-prep 在 C6-A 后立即做 | 尽早暴露自举差距 |
| 无最近 bug fix 记录 | 记录 sret + class field string fix | 路线图反映实际进展 |

---

## 最近修复的两个编译器 Bug

这些修复触及了 C6-B 域（字符串所有权），应在路线图中记录：

1. **sret codegen bug**（`52a51dbb3`）：TString-returning 函数没有 sret_ptr 参数，导致 LLVM emitter 签名与实际调用不匹配。修复了 builder 的 `ProcessFunctionBegin` 和 emitter 的 `IsTStringSretFunction`。

2. **class field string ops LLVM emission**（本次修改）：方法体内隐式 `Self` 的类字段字符串赋值（`Other := Text`）生成错误的 `assign-tstring-copy-runtime` 而非字段专用节点，导致 builder 静默失败。修复了 sema 的类字段目标识别和 HIR 节点生成。
