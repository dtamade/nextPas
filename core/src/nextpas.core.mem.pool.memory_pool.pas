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
  // 实现者：TSlabPool, TFixedSlabPool, TSlabPoolConcurrent 等
  IMemoryPool = interface(IPool)
    ['{6F6B4299-3B29-4C6F-917D-8D6B4B5E0E99}']
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(ADst: Pointer);
  end;

implementation

end.
