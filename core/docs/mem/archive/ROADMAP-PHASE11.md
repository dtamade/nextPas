# Phase 11: 高级分配器策略

## 目标
4 个分配器，聚焦高级策略和实际工程场景。

## P11-1: TCascadeAllocator — 级联分配器 ✅
- 依次尝试多个 inner allocator
- 第一个成功则返回
- 适合：主分配器 + fallback 场景
- 测试：7 个

## P11-2: TBoundedAllocator — 有界分配器 ✅
- 包装 inner allocator，限制最大内存使用
- 超限时返回 nil（不抛异常）
- 支持动态调整上限
- 适合：内存预算控制、嵌入式场景
- 测试：7 个

## P11-3: TAlignedAllocator — 对齐分配器 ✅
- 保证所有分配满足指定对齐要求
- 支持任意对齐值（2 的幂）
- 适合：SIMD、DMA、硬件对齐要求
- 测试：7 个

## P11-4: TStatsAllocator — 统计包装器 ✅
- 包装 inner allocator，收集性能统计
- 跟踪：alloc/free 次数、字节数、峰值、平均大小
- 零分配开销（仅计数器递增）
- 适合：性能分析、容量规划
- 测试：7 个

## 结果
- 新增源文件：4 个
- 新增测试：28 个
- Phase 11 完成后：45 allocator 文件 / ~933 测试
