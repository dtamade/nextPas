# nextpas.core.mem 架构设计

## 设计哲学

### 核心原则
1. **性能优先**：所有热路径必须极致优化
2. **零虚分发**：record 类型优于 class 类型
3. **接口优雅**：遵循 Rust trait / Go interface 风格
4. **生产级质量**：完整的测试覆盖和基准对照

### 设计约束
- IAllocator 接口有 40 个模块 384 个引用，不能轻易改动
- TAllocator 基类提供 DoGetMem/DoFreeMem 虚方法
- 用户要求"质量标准与 Go/Rust 对齐"

## 架构分层

### L0: 基础类型
- `nextpas.core.mem.base` - AlignUp, IsPowerOfTwo, TArenaMarker
- `nextpas.core.mem.intf` - IAllocator 接口
- `nextpas.core.mem.arena.types` - IArena 接口

### L1: Arena 实现
- `nextpas.core.mem.arena` - TLocalArena (GetMem-backed, IArena)
- `nextpas.core.mem.arena.compiler` - TFastArena (mmap-backed, 零虚分发)
- `nextpas.core.mem.arena.growable` - TGrowableArena (段增长, IArena)

### L2: 分配器包装
- `nextpas.core.mem.allocator.arena` - TFastArenaAllocator (IAllocator 包装)
- `nextpas.core.mem.allocator.tracking` - TTrackingAllocator (泄漏检测)
- `nextpas.core.mem.allocator.leak_check` - RunTestWithLeakCheck (测试便利)

### L3: 门面
- `nextpas.core.mem.pas` - 门面，re-export 所有类型

## 核心设计

### IArena 接口
```pascal
IArena = interface
  function Alloc(aSize: SizeUInt): Pointer;
  function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
  function AllocZeroed(aSize: SizeUInt): Pointer;
  function SaveMark: TArenaMarker;
  procedure RestoreToMark(aMark: TArenaMarker);
  procedure Reset;
  function TotalSize: SizeUInt;
  function UsedSize: SizeUInt;
  function RemainingSize: SizeUInt;
end;
```

### TFastArena 设计
- **零虚分发**：record 类型，不是 class 类型
- **mmap 后备**：使用 platform_mmap_create_anonymous 直接映射
- **几何增长**：chunk 大小 2x 增长
- **大对象直接 mmap**：>=64KB 的对象直接映射
- **标记/恢复**：TArenaMark = record (ChunkIndex, Offset)

### TLocalArena 设计
- **GetMem 后备**：使用标准 GetMem 分配
- **固定容量**：分配只前进，Reset 一次性释放全部
- **IArena 接口**：实现 IArena 接口，支持引用计数

### TGrowableArena 设计
- **段增长**：按需添加新段（几何或线性增长）
- **灵活配置**：可配置增长策略、对齐方式、最大容量
- **IArena 接口**：实现 IArena 接口，支持引用计数

## 性能优化

### TFastArena 热路径
```pascal
function TArena.Alloc(aSize: SizeUInt): Pointer;
begin
  // 1. 对齐当前指针
  LAligned := AlignUp(FCurrentPtr, FAlignment);
  // 2. 边界检查
  if LAligned + aSize > FCurrentEnd then
    Exit(nil);
  // 3. 更新指针
  FCurrentPtr := LAligned + aSize;
  // 4. 返回结果
  Result := LAligned;
end;
```

### 性能对比
- TFastArena 256B: 64.8ns (比 System.GetMem 快 3.8x)
- TFastArena 64B: 47.0ns (比 System.GetMem 快 1.5x)
- TGrowableArena 批量: 151.6µs (比 TFastArena 快 3.7x)

## 内存管理

### 内存分配策略
- **小对象**：从 chunk 分配，chunk 大小 2x 增长
- **大对象**：直接 mmap，>=64KB 的对象
- **对齐分配**：支持任意 2 的幂对齐

### 内存释放策略
- **Arena 释放**：Reset 一次性释放所有内存
- **单个释放**：不支持，DoFreeMem 为 no-op
- **内存泄漏检测**：TTrackingAllocator 记录所有分配/释放

## 接口设计

### IAllocator 接口
```pascal
IAllocator = interface
  function GetMem(aSize: SizeUInt): Pointer;
  function AllocMem(aSize: SizeUInt): Pointer;
  function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
  procedure FreeMem(aDst: Pointer);
  function MemSize(aPtr: Pointer): SizeUInt;
  function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
  procedure FreeAligned(aPtr: Pointer);
  function Traits: TAllocatorTraits;
end;
```

### TAllocatorTraits
```pascal
TAllocatorTraits = record
  ZeroInitialized: Boolean;
  ThreadSafe: Boolean;
  HasMemSize: Boolean;
  SupportsAligned: Boolean;
end;
```

## 测试策略

### 单元测试
- 每个接口方法都有对应的测试
- 边界条件测试
- 并发测试（如果适用）

### 基准测试
- FPC RTL 对照
- Go 标准库对照
- Rust 标准库对照

### 内存泄漏检测
- 所有测试 0 leaks
- TTrackingAllocator 检测所有分配/释放

## 未来演进

### Phase 1: 编译器集成
- HIR builder Arena 迁移
- LLVM emitter buffer 集成

### Phase 2: 性能优化
- SIMD 优化
- 缓存友好优化

### Phase 3: 功能扩展
- 线程安全 Arena
- NUMA 感知分配
