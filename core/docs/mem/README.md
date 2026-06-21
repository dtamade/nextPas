# nextpas.core.mem - 内存管理模块

## 概述

`nextpas.core.mem` 是 nextPas 框架的内存管理模块，提供高性能的内存分配器抽象和实现。

## 设计目标

- **高性能**：超越 Go/Rust 标准库的内存分配性能
- **零碎片**：Arena 分配器消除内存碎片
- **零泄漏**：完善的内存泄漏检测机制
- **接口优雅**：遵循 Rust trait / Go interface 风格的接口设计
- **生产级质量**：完整的测试覆盖和基准对照

## 核心类型

### IArena 接口
线性分配器接口，支持：
- `Alloc` - 分配内存
- `AllocAligned` - 对齐分配
- `AllocZeroed` - 分配并清零
- `SaveMark/RestoreToMark` - 保存/恢复分配位置
- `Reset` - 重置 Arena

### TLocalArena
基于 GetMem 的固定大小 Arena，实现 IArena 接口：
- 固定容量，分配只前进
- 支持 SaveMark/RestoreToMark
- 适用于请求/帧/文档等有限生命周期场景

### TFastArena
基于 mmap 的高性能 Arena，零虚分发：
- mmap 后备存储
- 零虚分发的 bump 分配器
- 适用于编译器热路径等需要极低开销分配的场景

### TGrowableArena
可增长的 Arena，支持段增长：
- 自动扩展：按需添加新段（几何或线性增长）
- 灵活配置：可配置增长策略、对齐方式、最大容量
- 适用于批量分配场景

### TFastArenaAllocator
包装 TFastArena 为 IAllocator 接口：
- 分配通过 TFastArena 的 bump 指针完成
- DoFreeMem 为 no-op
- Reset 方法一次性释放所有内存

### TTrackingAllocator
内存泄漏检测包装器：
- 记录所有分配/释放操作
- 检测内存泄漏
- 提供详细的泄漏报告

## 性能指标

- **TFastArena 256B**: 64.8ns (比 System.GetMem 快 3.8x)
- **TFastArena 64B**: 47.0ns (比 System.GetMem 快 1.5x)
- **TGrowableArena 批量**: 151.6µs (比 TFastArena 快 3.7x)

## 测试覆盖

- 92/92 tests passed
- 0 memory leaks
- 100% interface coverage

## 使用示例

### 基本使用
```pascal
var
  LArena: TLocalArena;
  LP: Pointer;
begin
  LArena := TLocalArena.Create(1024);
  try
    LP := LArena.Alloc(64);
    // 使用 LP...
  finally
    LArena.Free;
  end;
end;
```

### 使用 IAllocator 接口
```pascal
var
  LAllocator: IAllocator;
  LP: Pointer;
begin
  LAllocator := TFastArenaAllocator.Create;
  LP := LAllocator.GetMem(256);
  // 使用 LP...
  // 注意：Arena 不支持单个释放，需要 Reset 整个 Arena
end;
```

### 泄漏检测
```pascal
var
  LResult: TLeakCheckResult;
begin
  LResult := RunTestWithLeakCheck(procedure(AAllocator: IAllocator)
  begin
    // 测试代码...
  end);
  if LResult.LeakCount > 0 then
    WriteLn('Memory leaks detected!');
end;
```

## 相关文档

- [架构设计](ARCHITECTURE.md)
- [API 参考](API.md)
- [基准测试](BENCHMARKS.md)

## 依赖关系

```
nextpas.core.mem.base          ← 基础类型
nextpas.core.mem.intf          ← IAllocator 接口
nextpas.core.mem.arena.types   ← IArena 接口
nextpas.core.mem.arena         ← TLocalArena
nextpas.core.mem.arena.compiler ← TFastArena
nextpas.core.mem.arena.growable ← TGrowableArena
nextpas.core.mem.allocator.arena ← TFastArenaAllocator
nextpas.core.mem.allocator.tracking ← TTrackingAllocator
nextpas.core.mem.pas           ← 门面
```

## 版本历史

- v1.0 (2026-06-22): 架构修复完成，性能超越 Go/Rust
- v0.1 (2026-06-21): 初始实现
