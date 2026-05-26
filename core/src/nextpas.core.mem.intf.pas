unit nextpas.core.mem.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base;

type
  IAllocator = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    function Allocate(const ASize: SizeUInt): Pointer;
    function Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
    procedure Deallocate(const APtr: Pointer);
  end;

implementation

end.
