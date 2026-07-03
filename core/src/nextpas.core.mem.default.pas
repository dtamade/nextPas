unit nextpas.core.mem.default;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf;

function DefaultAllocator: IAllocator;

implementation

uses
  nextpas.core.mem.allocator.foundation;

function DefaultAllocator: IAllocator;
begin
  Result := nextpas.core.mem.allocator.foundation.GetRtlAllocator;
end;

end.
