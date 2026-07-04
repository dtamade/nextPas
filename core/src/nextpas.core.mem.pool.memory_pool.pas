unit nextpas.core.mem.pool.memory_pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.pool.base,
  nextpas.core.mem.allocator.base;

type
  {** IMemoryPool - 可变大小内存池接口
   *
   *  接口选择指南：
   *  - IAllocator：通用分配器契约（5 方法），推荐大多数场景
   *  - IPool：固定大小池（Acquire/Release），用于块池/对象池
   *  - IMemoryPool：继承 IPool + 可变大小，仅用于需要同时暴露两种 API 的池
   *
   *  历史原因：IMemoryPool 继承自 IPool，会暴露 Acquire/Release 等”单位”API。
   *  语义约定：对可变大小的池（如 slab），Acquire 分配最小分配粒度。
   *  实际使用：可变大小分配优先使用 GetMem/AllocMem/ReallocMem/FreeMem。
   *}
  IMemoryPool = interface(IPool)
    ['{6F6B4299-3B29-4C6F-917D-8D6B4B5E0E99}']
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(ADst: Pointer);
  end;

implementation

end.
