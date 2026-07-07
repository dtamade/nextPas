unit nextpas.core.mem.pool.memory_pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.pool.base,
  nextpas.core.mem.allocator.base;

type

  // IMemoryPool — 通用内存池接口
  //
  // 继承自 IPool，同时暴露固定大小 API (Acquire/Release) 和可变大小 API (GetMem/FreeMem)。
  //
  // 语义约定：
  // - GetMem/FreeMem: 可变大小分配，支持任意大小（池内部可能走 size class 或 fallback）
  // - Acquire/Release: 固定大小分配，分配该池的”最小分配粒度”
  // - 实际使用：可变大小分配优先使用 GetMem/AllocMem/ReallocMem/FreeMem
  // - Acquire 系列仅用于兼容层/极简场景（如只需要固定大小块的场景）
  //
  // 与 IAllocator 的关系：
  // - IMemoryPool 同时实现 IAllocator（通过 GetMem/FreeMem/AllocMem/ReallocMem/Traits）
  // - 调用方可以将 IMemoryPool 当作 IAllocator 使用
  //
  // ⚠️ 同一对象两种分配语义 (以 TSlabPool 为例):
  //   - 通过 IPool 引用调用 Acquire → 分配最小 slab 单元 (通常 8B)
  //   - 通过 IAllocator 引用调用 GetMem(64) → 走 size-class 路由
  //   两者返回的指针可以互相 FreeMem/Release，但分配粒度不同。
  //   新代码应统一使用 IAllocator.GetMem/FreeMem，Acquire 仅保留向后兼容。
  //
  // 实现者：TSlabPool, TFixedSlabPool, TSlabPoolConcurrent 等
  IMemoryPool = interface(IPool)
    ['{6F6B4299-3B29-4C6F-917D-8D6B4B5E0E99}']
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(APtr: Pointer);
  end;

implementation

end.
