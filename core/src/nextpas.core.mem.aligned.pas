unit nextpas.core.mem.aligned;

{$I nextpas.core.settings.inc}

interface

function AllocAligned(ASize: SizeUInt; AAlignment: SizeUInt): Pointer;
  deprecated 'Use nextpas.core.mem.default.DefaultAllocator.AllocAligned instead';
procedure FreeAligned(APtr: Pointer);
  deprecated 'Use nextpas.core.mem.default.DefaultAllocator.FreeAligned instead';

{$WARNING 'nextpas.core.mem.aligned is deprecated: use nextpas.core.mem.default.DefaultAllocator.AllocAligned/FreeAligned'}

implementation

uses
  nextpas.core.mem.intf,
  nextpas.core.mem.default;

function AllocAligned(ASize: SizeUInt; AAlignment: SizeUInt): Pointer;
var
  LAllocator: nextpas.core.mem.intf.IAllocator;
begin
  LAllocator := nextpas.core.mem.default.DefaultAllocator;
  Result := LAllocator.AllocAligned(ASize, AAlignment);
end;

procedure FreeAligned(APtr: Pointer);
var
  LAllocator: nextpas.core.mem.intf.IAllocator;
begin
  LAllocator := nextpas.core.mem.default.DefaultAllocator;
  LAllocator.FreeAligned(APtr);
end;

end.
