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
    HasMemSize: Boolean;       { MemSize 返回实际分配块大小 }
    SupportsAligned: Boolean;  { AllocAligned 可用 }
  end;

  {**
   * @desc Canonical nextpas.core allocator contract.
   *}
  IAllocator = interface
    ['{1CEB691D-D538-48D2-A5C4-A4F0A1B98928}']
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(ADst: Pointer);
    function MemSize(APtr: Pointer): SizeUInt;
    function AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
    procedure FreeAligned(APtr: Pointer);
    function Traits: TAllocatorTraits;
  end;

implementation

end.
