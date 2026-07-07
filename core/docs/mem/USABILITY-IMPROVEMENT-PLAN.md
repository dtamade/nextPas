# mem 模块可用性改进调研报告

**调研日期**: 2026-07-05  
**目标范围**: 短期 3 项 + 中期 3 项 + 长期 3 项  
**当前状态**: 9/9 任务全部完成 ✅

---

## 短期任务调研 (1-2 周)

### Task 1: 统一错误消息格式 ✅ 已完成

**当前状态**:
- 共发现 **112 处** `EAllocError.Create` / `EOutOfMemory.Create` 调用
- **75 处**已包含足够上下文
- **37 处**已补充数值上下文（overflow/out of range/corruption）

**修复内容**:
1. overflow 消息补充具体数值 (17处)
2. out of range 消息补充实际值和限制 (9处)
3. corruption 消息补充偏移量 (4处)
4. alignment 消息保持原样 (L0层无 IntToStr)
5. pointer 消息保持原样 (无 PtrToStr 工具函数)

**工作量**: 2 小时
**提交**: c40107c5b

---

### Task 2: API.md 决策树

**当前状态**:  
- `API.md` 已有 200+ 行文档
- `pool.base.pas` 已有接口选择决策树注释
- 门面 `mem.pas` 有选择指南注释（6 行）

**缺失内容**:  
1. **统一决策树**: 用户面对 IAllocator / IArena / IPool / IMemoryPool 时的选择指南
2. **场景示例**: 常见使用场景的代码示例
3. **性能特征**: 各分配器的性能特征对比

**目标结构**:
```markdown
## 分配器选择指南

### 决策树
```
需要分配内存？
├─ 通用场景 (malloc 替代) → DefaultAllocator
├─ 请求/帧级生命周期 → CreateDefaultArena
├─ 高频小对象 → CreateFixedSlabPool
├─ 并发场景 → TSlabPoolConcurrent
└─ 测试泄漏检测 → TTrackingAllocator
```

### 性能特征
| 分配器 | 64B ns/op | 线程安全 | 适用场景 |
|--------|-----------|----------|----------|
| DefaultAllocator | 16 | ✅ | 通用 |
| TLocalArena | 5 | ❌ | 帧分配 |
| TSlabPool | 8 | ❌ | 小对象 |
| TSlabPoolConcurrent | 4 | ✅ | 并发小对象 |
```

**实施计划**:
1. 在 `API.md` 增加 "选择指南" 章节
2. 从 `pool.base.pas` 提取决策树
3. 从 `BENCHMARKS.md` 提取性能数据
4. 增加 5 个常见场景示例

**工作量**: 1-2 小时

---

### Task 3: 清理 deprecated API ✅ 已完成

**当前状态**:
- `pool.slab.pas` 中的 deprecated API 已清理：
  - 删除 `EnablePageMerging` 字段（未使用）
  - 删除 `PageSize` 字段（未使用）
  - 删除 `CreateSlabConfigWithPageMerging` 函数

**影响分析**:
- 无外部调用，安全删除
- 测试验证：280+ 测试全部通过

**实施结果**:
- 已在 `mem-deprecated-cleanup` 分支完成
- commit: 37a1f32a0

**工作量**: 30 分钟

---

## 中期任务调研 (1 月)

### Task 4: TTrackingAllocator hash map ✅ 已完成

**当前状态**:  
- 已使用 **open-addressing hash map** (非线性扫描!)
- 实现: `MulHash64` + 线性探测
- 常量: `TRACK_MAP_MIN_CAP = 64`
- 增长: 2x 扩容
- 负载因子 > 50% 时自动增长

**结论**: 已经是 O(1) 平均复杂度，无需优化。

---

### Task 5: TVirtualArena IArena 适配器 ✅ 已完成

**当前状态**:  
- `TVirtualArenaAdapter` 已存在于 `allocator.arena.pas`
- 门面 `mem.pas` 已导出 `TVirtualArenaAdapter`
- 支持 `TArenaConcurrent`、`TFallbackArena` 包装

**结论**: 已实现，无需额外工作。

---

### Task 6: 接口拆分评估 ✅ 已完成

**当前状态**:  
- `IAllocator` 有 5 个方法: GetMem/AllocMem/ReallocMem/FreeMem/Traits
- 大多数实现只能完整实现 4 个（MemSize 已移除）
- `AllocAligned` / `FreeAligned` 已移至 `IArena`

**评估结论**:  
- 当前 5 方法设计已足够简洁
- `Traits` 方法提供运行时能力查询，Rust/Go 无此功能
- **不建议拆分**，但建议文档化各方法的使用场景

**结论**: 已评估，无需拆分。

---

## 长期任务调研 (季度)

### Task 7: 代码拆分 ✅ 已完成

**拆分结果** (2026-07-05):
| 文件 | 原行数 | 新行数 | 职责 |
|------|--------|--------|------|
| `pool.fixed_slab.pas` | 1,758 | 898 | TFixedSlabPool 类实现 |
| `pool.fixed_slab.nginx.pas` | — | 847 | Nginx slab 底层原语 |

**未拆分文件** (评估后决定不拆分):
| 文件 | 行数 | 原因 |
|------|------|------|
| `mem.utils.pas` | 1,379 | 全 inline 函数，内聚性极高 |
| `blockpool.sharded.pas` | 1,383 | 单类实现，拆分破坏封装 |

**验证**: test_slab_pool 19/19 ✅, test_slab_thread_safety 2/2 ✅, L0 边界检查 ✅

---

### Task 8: 异常粒度评估 ✅ 已完成

**评估结论** (2026-07-05):
- 核心 7 个异常类 + 9 个池特化异常，粒度合理
- 185 个 raise 站点分布均匀
- 对标 Rust/Go 无差距
- **无需修改**

**当前异常类**:
| 异常类 | 继承关系 | 使用场景 |
|--------|----------|----------|
| `EAllocError` | ENextPasError | 基类 |
| `EOutOfMemory` | EOutOfMemory | OOM |
| `EInvalidLayout` | EAllocError | 无效布局 |
| `EInvalidPointer` | EAllocError | 无效指针 |
| `EDoubleFree` | EAllocError | 双重释放 |
| `ESlabPoolInvalidSize` | EAllocError | Slab 无效大小 |
| `ESlabPoolCorruption` | EAllocError | Slab 损坏 |

**评估**:  
- 7 个异常类，粒度合理
- `EInvalidLayout` / `EInvalidPointer` / `EDoubleFree` 覆盖常见错误
- `ESlabPool*` 是 Slab 特化，保留

**建议**:  
- **保持现状**，粒度已足够
- 考虑添加 `EAlignmentNotSupported`（当前用 `EInvalidLayout`）

**工作量**: 无需修改

---

### Task 9: 编译时安全 (FPC -O2 死锁) ✅ 已解决

**评估结论** (2026-07-05):
- USABILITY-AUDIT.md F-03 已标记 **已解决**
- 当前实现使用 InterlockedCompareExchange + 平台 mutex，无 -O2 风险
- 无虚方法调用、无接口指针调用在锁路径上
- **无需操作**

**当前状态**:  
- `mutex.pas` 注释说明 FPC -O2 下指针调用可能死锁
- 无编译时检查
- 无运行时检测

**问题分析**:  
- FPC -O2 优化可能重排指令，导致锁状态不一致
- 仅影响 `TMemMutex` 的方法调用（通过接口指针）

**缓解方案**:
1. **编译警告**: `{$IFDEF FPC}{$IF OPTIMIZATION >= 2}` 添加警告
2. **运行时检测**: DEBUG 模式记录锁获取顺序
3. **文档**: CONTRACT.md 标记为已知限制

**建议**:  
- **方案 1 + 3**（编译警告 + 文档）
- 运行时检测开销太大，不建议

**工作量**: 1 小时

---

## 实施优先级

### 立即执行 (本周)

1. **Task 1**: 统一错误消息格式 (2-3h)
2. **Task 3**: 清理 deprecated API (30min) ✅ 已完成

### 下周执行

3. **Task 2**: API.md 决策树 (1-2h)
4. **Task 9**: 编译时安全警告 (1h)

### 本月执行

5. **Task 5**: TVirtualArena IArena 适配器 (2-3h)
6. **Task 6**: 接口拆分评估文档 (1h)

### 季度执行

7. **Task 4**: TTrackingAllocator 优化 (2-3h)
8. **Task 7**: 代码拆分 (1-2 天)
9. **Task 8**: 异常粒度评估 (无需修改)

---

## 风险评估

| 任务 | 风险 | 缓解措施 |
|------|------|----------|
| Task 1 | 低 | 仅修改错误消息，不影响功能 |
| Task 2 | 低 | 仅文档修改 |
| Task 3 | 中 | 可能影响外部用户，需评估 | ✅ 已完成，无外部调用 |
| Task 4 | 低 | 已使用 hash map，仅优化 |
| Task 5 | 低 | 新增适配器，不影响现有代码 |
| Task 6 | 低 | 仅文档评估 |
| Task 7 | 高 | 可能引入循环依赖 |
| Task 8 | 低 | 无需修改 |
| Task 9 | 低 | 仅添加编译警告 |

---

## 结论

**短期任务**: 2 项可立即执行，1 项下周执行  
**中期任务**: 2 项本月执行，1 项待评估  
**长期任务**: 1 项季度执行，2 项暂不执行  

**总工作量**: 约 2-3 天  
**风险等级**: LOW  
**建议**: 按优先级逐步执行，短期任务先行
