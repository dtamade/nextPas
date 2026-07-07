unit nextpas.core.mem.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base;

type
  {**
   * @desc Allocator capability description used by strategy code.
   *
   * @note ZeroInitialized 仅对 AllocMem 有效 — AllocMem 保证返回全零内存。
   *       GetMem 不保证零填充，即使 ZeroInitialized=True。
   *}
  TAllocatorTraits = record
    ZeroInitialized: Boolean;  { AllocMem 返回全零内存 }
    ThreadSafe: Boolean;       { 所有方法线程安全 }
    SupportsRealloc: Boolean;  { ReallocMem 可用；False 时 ReallocMem 会抛 aeReallocNotSupported }
  end;

  {**
   * @desc Canonical nextpas.core allocator contract.
   *
   *  核心 5 方法：GetMem/AllocMem/ReallocMem/FreeMem + Traits。
   *  MemSize 和 AllocAligned/FreeAligned 已移至更专门的接口
   *  （IMemoryPool.MemSizeOf 和 IArena.AllocAligned）。
   *}
  IAllocator = interface
    ['{1CEB691D-D538-48D2-A5C4-A4F0A1B98928}']
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(APtr: Pointer);
    function Traits: TAllocatorTraits;
  end;

  {**
   * @desc Batch allocation interface.
   *
   *  批量分配/释放接口，摊销 TLS/cache 开销。
   *  实现者可覆盖以提供 O(1) 批量操作（而非 N 次单体操作）。
   *
   *  @note 默认实现回退到循环调用 IAllocator.GetMem/FreeMem。
   *}
  IBatchAllocator = interface
    ['{A7F3D2E1-5B8C-4D6E-9F0A-1C2D3E4F5A6B}']
    {** 批量分配 ACount 块，每块 ASize 字节。
        结果写入 ABlocks[0..ACount-1]。
        返回实际分配数量（OOM 时可能 < ACount）。 }
    function BatchGetMem(ASize: SizeUInt; ACount: Word;
      ABlocks: PPointer): Word;
    {** 批量释放 ACount 块，每块 ASize 字节。 }
    procedure BatchFreeMem(ASize: SizeUInt; ACount: Word;
      ABlocks: PPointer);
  end;

implementation

end.
