unit nextpas.core.mem.default;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

function DefaultAllocator: TMemAllocator;

implementation

uses
  nextpas.core.mem.allocator.foundation;

function DefaultAllocator: TMemAllocator;
begin
  Result := nextpas.core.mem.allocator.foundation.GetRtlAllocator;
end;

end.
