# Phase 9: 最终分配器套件

## 目标
4 个分配器，补齐 mem 模块分配器谱系。

## P9-1: TBumpAllocator — 线性分配器 ✅
- 最快可能的分配：仅递增指针
- 无 free、无 header、无碎片
- Reset 一次性回收
- 适合：解析器临时 AST、编译期临时数据
- 定位：比 Arena2 更简单（无页管理），比 Stack 更快
- 测试：7 个

## P9-2: TPool2Allocator — 对齐池分配器 ✅
- Pool 的增强版：支持自定义对齐
- 块头部存储完整元数据（magic + size class + sequence）
- 碎片检测：sequence number 检测 double-free
- 适合：SIMD 数据、DMA 缓冲区、需要对齐的场景
- 测试：7 个

## P9-3: TSizeClassAllocator — 通用尺寸类分配器 ✅
- 16 个尺寸类（8B–64KB），每类独立 freelist
- 小对象走 freelist，大对象走 inner allocator
- 碎片统计：每类的利用率
- 适合：通用场景的 drop-in 替代
- 测试：7 个

## P9-4: TBitmapAllocator — 位图分配器 ✅
- 用位图跟踪固定大小槽位的分配状态
- O(n) 扫描找空闲位，但内存开销极小（1 bit per slot）
- 适合：嵌入式场景、内存受限环境、固定槽位管理
- 测试：7 个

## 结果
- 新增源文件：4 个
- 新增测试：28 个
- Phase 9 完成后：37 allocator 文件 / ~877 测试
