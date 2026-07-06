# mem 模块 P-03/I-02/I-03 实施计划

**日期**: 2026-07-06
**状态**: 执行中

---

## 1. P-03: Bitmap span 多级管理

### 1.1 问题分析

当前 `TSpan` 使用单个 64-bit bitmap，最多支持 64 个 slots：
- 优势：BSF 单指令分配，O(1) 复杂度
- 限制：大规模分配场景 (1000+ 并发分配) 需要频繁扫描多个 span

### 1.2 优化方案

实现多级 span 管理：
- 一级 span: 64 slots (当前)
- 二级 span: 64 * 64 = 4096 slots
- 三级 span: 64 * 64 * 64 = 262144 slots

BSF 批量定位：
- 一次 BSF 找到非空 bitmap
- 二次 BSF 找到具体 slot
- 减少 cache miss

### 1.3 实施步骤

1. 设计多级 span 数据结构
2. 实现 BSF 批量定位算法
3. 添加性能测试
4. 对比 Go/mimalloc 性能

### 1.4 预期收益

- 大规模分配场景 (1000+ 并发分配) 性能提升 20-30%
- 减少 bitmap 扫描次数
- 提升多核扩展性

---

## 2. I-02: 统一入口

### 2.1 问题分析

当前 mem.pas 已经是一个门面单元，但用户需要通过 IAllocator 接口来调用 GetMem/AllocMem/ReallocMem/FreeMem 方法。

### 2.2 优化方案

添加全局函数：
```pascal
function GetMem(ASize: SizeUInt): Pointer;
function AllocMem(ASize: SizeUInt): Pointer;
function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
procedure FreeMem(ADst: Pointer);
```

这些函数直接调用 DefaultAllocator，简化用户使用。

### 2.3 实施步骤

1. 在 mem.pas 中添加全局函数
2. 添加测试验证
3. 更新文档

### 2.4 预期收益

- 简化用户使用
- 减少样板代码
- 提升开发体验

---

## 3. I-03: 对齐统一

### 3.1 问题分析

当前 AlignUp 有两个版本：
1. `mem.base.pas:78` - `AlignUp(const AValue, AAlignment: SizeUInt): SizeUInt` - 用于整数
2. `mem.utils.pas:1287` - `AlignUp(aPtr: Pointer; aAlignment: SizeUInt): Pointer` - 用于指针

AllocAligned 在 IArena 接口中，不在 IAllocator 接口中。

### 3.2 优化方案

1. 统一 AlignUp 函数：
   - 保留两个版本（整数和指针）
   - 确保实现一致性

2. 添加 IAllocator 的 AllocAligned 方法（可选）：
   - 当前 AllocAligned 在 IArena 接口中
   - 可以考虑添加到 IAllocator 接口

### 3.3 实施步骤

1. 审查 AlignUp 函数实现
2. 确保一致性
3. 添加测试验证
4. 更新文档

### 3.4 预期收益

- 统一对齐策略
- 减少用户困惑
- 提升代码可维护性

---

## 4. 里程碑

| 任务 | 预计时间 | 优先级 | 状态 |
|------|----------|--------|------|
| P-03 Bitmap span 多级管理 | 3-5 天 | 高 | 待执行 |
| I-02 统一入口 | 1 天 | 中 | ✅ 已完成 |
| I-03 对齐统一 | 1 天 | 中 | ✅ 已完成 |

---

## 5. 风险评估

| 任务 | 风险 | 缓解措施 |
|------|------|----------|
| P-03 | 高 | 需要仔细测试并发场景 |
| I-02 | 低 | 仅添加全局函数 |
| I-03 | 低 | 仅审查和文档更新 |
