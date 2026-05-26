unit nextpas.core.mem;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default;

type
  TAllocatorKind = nextpas.core.mem.base.TAllocatorKind;
  IAllocator = nextpas.core.mem.intf.IAllocator;

function DefaultAllocator: IAllocator; inline;

implementation

function DefaultAllocator: IAllocator;
begin
  Result := nextpas.core.mem.default.DefaultAllocator;
end;

end.
