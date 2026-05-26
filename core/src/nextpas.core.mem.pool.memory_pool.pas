unit nextpas.core.mem.pool.memory_pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.pool.base;

type

  // 与 IAllocator 对齐的通用内存池接口（作为“友好接口”层）
  //
  // 说明：
  // - 历史原因：IMemoryPool 继承自 IPool，因此会暴露 Acquire/TryAcquire/AcquireN/Release 等“单位”API。
  // - 语义约定：对可变大小的池（如 slab），Acquire 系列应当分配该池的“最小分配粒度”（而不是 SizeOf(Pointer) 这种无意义的尺寸）。
  // - 实际使用：可变大小分配请优先使用 GetMem/AllocMem/ReallocMem/FreeMem；Acquire 系列仅用于兼容层/极简场景。
  IMemoryPool = interface(IPool)
    ['{6F6B4299-3B29-4C6F-917D-8D6B4B5E0E99}']
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
  end;

implementation

end.
