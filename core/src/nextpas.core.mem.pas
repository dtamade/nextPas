unit nextpas.core.mem;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.arena,
  nextpas.core.mem.pool;

type
  TAllocatorKind = nextpas.core.mem.base.TAllocatorKind;
  TArenaMarker = nextpas.core.mem.base.TArenaMarker;
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TArena = nextpas.core.mem.arena.TArena;
  TPool = nextpas.core.mem.pool.TPool;

function DefaultAllocator: IAllocator; inline;

function AllocZeroed(const AAllocator: IAllocator; const ASize: SizeUInt): Pointer; inline;
function AllocArray(const AAllocator: IAllocator; const ACount, AElemSize: SizeUInt): Pointer; inline;

implementation

function DefaultAllocator: IAllocator;
begin
  Result := nextpas.core.mem.default.DefaultAllocator;
end;

function AllocZeroed(const AAllocator: IAllocator; const ASize: SizeUInt): Pointer;
begin
  Result := AAllocator.Allocate(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function AllocArray(const AAllocator: IAllocator; const ACount, AElemSize: SizeUInt): Pointer;
var
  LTotal: SizeUInt;
begin
  LTotal := ACount * AElemSize;
  Result := AAllocator.Allocate(LTotal);
  if Result <> nil then
    FillChar(Result^, LTotal, 0);
end;

end.
