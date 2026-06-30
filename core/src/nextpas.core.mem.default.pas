unit nextpas.core.mem.default;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.allocator.base;

function DefaultAllocator: TAllocator;

implementation

uses
  nextpas.core.mem.allocator.foundation;

function DefaultAllocator: TAllocator;
begin
  Result := nextpas.core.mem.allocator.foundation.GetRtlAllocator;
end;

end.
