program bench_arena_go_rust;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.mem.base, nextpas.core.mem.arena.base, nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.local, nextpas.core.mem.arena.chunked, nextpas.core.mem.arena.virtual;
const SMALL_SIZE = 64;
var GSink: Pointer;
procedure BenchRTLAlloc64(const ACtx: IBenchContext);
var LP: Pointer;
begin GetMem(LP, SMALL_SIZE); FreeMem(LP); end;
procedure BenchLocalArenaAlloc64(const ACtx: IBenchContext);
var LA: TLocalArena; LP: Pointer;
begin LA := TLocalArena.Create(1024 * 1024); LP := LA.Alloc(SMALL_SIZE); PByte(LP)^ := 1; LA.Free; end;
procedure BenchChunkedArenaAlloc64(const ACtx: IBenchContext);
var LA: IChunkedArena; LP: Pointer;
begin LA := CreateChunkedArena(1024 * 1024); LP := LA.Alloc(SMALL_SIZE); PByte(LP)^ := 1; end;
procedure BenchVirtualArenaAlloc64(const ACtx: IBenchContext);
var LA: IVirtualArena; LP: Pointer;
begin LA := CreateVirtualArena(4 * 1024 * 1024); LP := LA.Alloc(SMALL_SIZE); PByte(LP)^ := 1; end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('arena');
  LSuite.Add('RTL/64B', @BenchRTLAlloc64).Add('LocalArena/64B', @BenchLocalArenaAlloc64)
    .Add('ChunkedArena/64B', @BenchChunkedArenaAlloc64).Add('VirtualArena/64B', @BenchVirtualArenaAlloc64);
  WriteLn(LSuite.Run.PrintToConsole);
end.
