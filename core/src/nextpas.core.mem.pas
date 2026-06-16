unit nextpas.core.mem;
{**
 * @desc 内存管理门面：IAllocator 抽象、默认分配器、工具函数。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.error,
  nextpas.core.mem.default,
  nextpas.core.mem.arena,
  nextpas.core.mem.pool;

type
  TAllocatorKind = nextpas.core.mem.base.TAllocatorKind;
  TArenaMarker = nextpas.core.mem.base.TArenaMarker;
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TLocalArena = nextpas.core.mem.arena.TLocalArena;
  TArena = nextpas.core.mem.arena.TArena;
  TLocalBlockPool = nextpas.core.mem.pool.TLocalBlockPool;
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
  Result := AAllocator.GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function AllocArray(const AAllocator: IAllocator; const ACount, AElemSize: SizeUInt): Pointer;
var
  LTotal: SizeUInt;
begin
  if (ACount = 0) or (AElemSize = 0) then Exit(nil);
  LTotal := ACount * AElemSize;
  if (LTotal div AElemSize) <> ACount then
    raise EOutOfMemory.Create(aeOutOfMemory, 'AllocArray: size overflow');
  Result := AAllocator.GetMem(LTotal);
  if Result <> nil then
    FillChar(Result^, LTotal, 0);
end;

end.
