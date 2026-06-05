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
    function Allocate(const ASize: SizeUInt): Pointer;
    function Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
    procedure Deallocate(const APtr: Pointer);
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    function Traits: TAllocatorTraits;
  end;

implementation

end.
