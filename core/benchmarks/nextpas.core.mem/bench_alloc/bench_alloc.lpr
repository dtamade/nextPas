program bench_alloc;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.fs,
  nextpas.core.mem,
  nextpas.core.platform.time;

var
  GSink: Pointer;
  LResults: IBenchResults;

procedure BenchAllocatorGetMem64(const ACtx: IBenchContext);
var LA: IAllocator; LP: Pointer;
begin LA := DefaultAllocator; LP := LA.GetMem(64); LA.FreeMem(LP); end;
procedure BenchAllocatorGetMem1K(const ACtx: IBenchContext);
var LA: IAllocator; LP: Pointer;
begin LA := DefaultAllocator; LP := LA.GetMem(1024); LA.FreeMem(LP); end;
procedure BenchAllocatorGetMem16K(const ACtx: IBenchContext);
var LA: IAllocator; LP: Pointer;
begin LA := DefaultAllocator; LP := LA.GetMem(16384); LA.FreeMem(LP); end;
procedure BenchRawGetMem64(const ACtx: IBenchContext);
var LP: Pointer;
begin LP := GetMem(64); FreeMem(LP); end;
procedure BenchRawGetMem1K(const ACtx: IBenchContext);
var LP: Pointer;
begin LP := GetMem(1024); FreeMem(LP); end;
procedure BenchRawGetMem16K(const ACtx: IBenchContext);
var LP: Pointer;
begin LP := GetMem(16384); FreeMem(LP); end;

begin
  LResults := TBenchSuite.Create('alloc')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('IAllocator/64B', @BenchAllocatorGetMem64)
    .Add('IAllocator/1KB', @BenchAllocatorGetMem1K)
    .Add('IAllocator/16KB', @BenchAllocatorGetMem16K)
    .Add('Raw/64B', @BenchRawGetMem64)
    .Add('Raw/1KB', @BenchRawGetMem1K)
    .Add('Raw/16KB', @BenchRawGetMem16K)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-alloc.json');
end.
