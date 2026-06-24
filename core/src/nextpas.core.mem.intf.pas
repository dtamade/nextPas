unit nextpas.core.mem.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base;

type
  {**
   * @desc Allocator capability description used by strategy code.
   *}
  TAllocatorTraits = record
    ZeroInitialized: Boolean;
    ThreadSafe: Boolean;
    HasMemSize: Boolean;
    SupportsAligned: Boolean;
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
