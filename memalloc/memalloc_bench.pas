{$mode ObjFPC}{$H+}
program memalloc_bench;
uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N100K = 100000;

var
  GResult: Pointer;

procedure GetFree64_100K(const ACtx: IBenchContext);
var I: Integer; P: Pointer;
begin
  for I := 1 to N100K do begin
    GetMem(P, 64);
    PByte(P)[0] := 1;
    FreeMem(P);
  end;
  GResult := P;
end;

procedure GetFree1K_100K(const ACtx: IBenchContext);
var I: Integer; P: Pointer;
begin
  for I := 1 to N100K do begin
    GetMem(P, 1024);
    PByte(P)[0] := 1;
    FreeMem(P);
  end;
  GResult := P;
end;

procedure GetFree4K_100K(const ACtx: IBenchContext);
var I: Integer; P: Pointer;
begin
  for I := 1 to N100K do begin
    GetMem(P, 4096);
    PByte(P)[0] := 1;
    FreeMem(P);
  end;
  GResult := P;
end;

procedure NewDispose_100K(const ACtx: IBenchContext);
type PRec = ^TRec; TRec = record A, B, C, D: Int64; end;
var I: Integer; P: PRec;
begin
  for I := 1 to N100K do begin
    New(P);
    P^.A := 1;
    Dispose(P);
  end;
end;

var LSuite: IBenchSuite;
    LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('MemAlloc');
  LSuite
    .SetMinDuration(TDuration.FromMilliseconds(200))
    .SetMaxIterations(1000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('GetFree64/100K', @GetFree64_100K);
  LSuite.Add('GetFree1K/100K', @GetFree1K_100K);
  LSuite.Add('GetFree4K/100K', @GetFree4K_100K);
  LSuite.Add('NewDispose/100K', @NewDispose_100K);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
