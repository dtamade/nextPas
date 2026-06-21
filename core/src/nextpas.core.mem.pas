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
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.arena.chunked,
  nextpas.core.mem.arena.virtual,
  nextpas.core.mem.allocator.arena,
  nextpas.core.mem.allocator.tracking,
  nextpas.core.mem.allocator.leak_check,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.pool;

type
  TAllocatorKind = nextpas.core.mem.base.TAllocatorKind;
  TArenaMarker = nextpas.core.mem.base.TArenaMarker;
  IAllocator = nextpas.core.mem.intf.IAllocator;
  IArena = nextpas.core.mem.arena.intf.IArena;
  TArenaMark = nextpas.core.mem.arena.base.TArenaMark;
  TArenaGrowthKind = nextpas.core.mem.arena.base.TArenaGrowthKind;
  TArenaStats = nextpas.core.mem.arena.base.TArenaStats;
  TArenaConfig = nextpas.core.mem.arena.base.TArenaConfig;
  TLocalArena = nextpas.core.mem.arena.local.TLocalArena;
  TChunkedArena = nextpas.core.mem.arena.chunked.TChunkedArena;
  TVirtualArena = nextpas.core.mem.arena.virtual.TVirtualArena;
  TArenaAllocator = nextpas.core.mem.allocator.arena.TFastArenaAllocator;
  TTrackingAllocator = nextpas.core.mem.allocator.tracking.TTrackingAllocator;
  TLeakCheckResult = nextpas.core.mem.allocator.leak_check.TLeakCheckResult;
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
