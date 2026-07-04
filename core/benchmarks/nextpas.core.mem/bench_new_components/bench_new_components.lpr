program bench_new_components;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.mem.base, nextpas.core.mem.intf, nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf, nextpas.core.mem.arena.local, nextpas.core.mem.arena.thread,
  nextpas.core.mem.pool.sizeclass, nextpas.core.mem.allocator.fallback, nextpas.core.mem.allocator;
const SMALL_SIZE = 64;
var GSink: Pointer;
procedure BenchLocalArenaAlloc64(const ACtx: IBenchContext);
var LA: TLocalArena; LP: Pointer;
begin LA := TLocalArena.Create(4 * 1024 * 1024); LP := LA.Alloc(SMALL_SIZE); PByte(LP)^ := 1; LA.Free; end;
procedure BenchThreadArenaAlloc64(const ACtx: IBenchContext);
var LP: Pointer;
begin LP := ThreadArena.Alloc(SMALL_SIZE); PByte(LP)^ := 1; ThreadArena.Reset; end;
procedure BenchSizeClassPoolAlloc64(const ACtx: IBenchContext);
var LP: Pointer;
begin LP := SizeClassPool.Alloc(SMALL_SIZE); PByte(LP)^ := 1; SizeClassPool.Free(LP); end;
procedure BenchDefaultAllocator64(const ACtx: IBenchContext);
var LA: IAllocator; LP: Pointer;
begin LA := DefaultAllocator; LP := LA.GetMem(SMALL_SIZE); LA.FreeMem(LP); end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('new-components');
  LSuite.Add('LocalArena/64B', @BenchLocalArenaAlloc64).Add('ThreadArena/64B', @BenchThreadArenaAlloc64)
    .Add('SizeClassPool/64B', @BenchSizeClassPoolAlloc64).Add('DefaultAllocator/64B', @BenchDefaultAllocator64);
  WriteLn(LSuite.Run.PrintToConsole);
end.
