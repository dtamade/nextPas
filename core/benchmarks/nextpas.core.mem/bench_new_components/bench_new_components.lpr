program bench_new_components;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.mem.base, nextpas.core.mem.intf, nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf, nextpas.core.mem.arena.local, nextpas.core.mem.arena.thread,
  nextpas.core.mem.pool.sizeclass, nextpas.core.mem.default;
const SMALL_SIZE = 64;
var
  GSink: Pointer;
  GThreadMgr: TThreadArenaManager;
  GSizeClassPool: TSizeClassPool;

procedure BenchLocalArenaAlloc64(const ACtx: IBenchContext);
var LA: TLocalArena; LP: Pointer;
begin
  LA := TLocalArena.Create(4 * 1024 * 1024);
  LP := LA.Alloc(SMALL_SIZE);
  PByte(LP)^ := 1;
  GSink := LP;
  LA.Free;
end;

procedure BenchThreadArenaAlloc64(const ACtx: IBenchContext);
var LA: TLocalArena; LP: Pointer;
begin
  LA := GThreadMgr.Get;
  LP := LA.Alloc(SMALL_SIZE);
  PByte(LP)^ := 1;
  GSink := LP;
  LA.Reset;
end;

procedure BenchSizeClassPoolAlloc64(const ACtx: IBenchContext);
var LP: Pointer;
begin
  LP := GSizeClassPool.Alloc(SMALL_SIZE);
  PByte(LP)^ := 1;
  GSink := LP;
  GSizeClassPool.Release(LP, SMALL_SIZE);
end;

procedure BenchDefaultAllocator64(const ACtx: IBenchContext);
var LA: IAllocator; LP: Pointer;
begin
  LA := DefaultAllocator;
  LP := LA.GetMem(SMALL_SIZE);
  if LP <> nil then
  begin
    PByte(LP)^ := 1;
    GSink := LP;
    LA.FreeMem(LP);
  end;
end;

var LSuite: IBenchSuite;
begin
  GThreadMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  GSizeClassPool := TSizeClassPool.Create;
  try
    LSuite := TBenchSuite.Create('new-components');
    LSuite.Add('LocalArena/64B', @BenchLocalArenaAlloc64)
      .Add('ThreadArena/64B', @BenchThreadArenaAlloc64)
      .Add('SizeClassPool/64B', @BenchSizeClassPoolAlloc64)
      .Add('DefaultAllocator/64B', @BenchDefaultAllocator64);
    WriteLn(LSuite.Run.PrintToConsole);
  finally
    GThreadMgr.DrainTLS;
    GThreadMgr.Free;
    GSizeClassPool.Free;
  end;
end.
