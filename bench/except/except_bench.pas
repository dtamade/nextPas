program except_bench;
{$mode ObjFPC}{$H+}{$inline on}
uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

var
  GSink: Int64;

{ --- ExNoThrow: try/except with NO exception (FPC zero-cost) --- }
{ N=10000 × ITERS=1000 = 10M protected iterations, no throw }

procedure ExNoThrow(const ACtx: IBenchContext);
const
  N = 10000;
  ITERS = 1000;
var
  I, Iter: Integer;
  LSum: Int64;
begin
  LSum := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N-1 do begin
      try
        Inc(LSum, I);
      except
        LSum := -1;
      end;
    end;
  GSink := LSum;
  ACtx.SetBytes(ITERS * N * SizeOf(Integer));
end;

{ --- ExCatchRate: always-throw, always-catch (exceptional path) --- }
{ N=100 × ITERS=100 = 10K total throws }

procedure ExCatchRate(const ACtx: IBenchContext);
const
  N = 100;
  ITERS = 100;
var
  I, Iter: Integer;
  LCount: Int64;
begin
  LCount := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N-1 do begin
      try
        raise EAbort.Create('');
      except
        Inc(LCount);
      end;
    end;
  GSink := LCount;
  ACtx.SetBytes(N * ITERS);
end;

{ --- ExMixed: 1% throw rate (realistic scenario) --- }
{ N=10000 × ITERS=100 = 1M iterations, ~10K throws total }

procedure ExMixed(const ACtx: IBenchContext);
const
  N = 10000;
  ITERS = 100;
var
  I, Iter: Integer;
  LSum, LThrowCount: Int64;
begin
  LSum := 0;
  LThrowCount := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N-1 do begin
      try
        if I mod 100 = 0 then
          raise EAbort.Create('');
        Inc(LSum, I);
      except
        Inc(LThrowCount);
      end;
    end;
  GSink := LSum + LThrowCount;
  ACtx.SetBytes(ITERS * N * SizeOf(Integer));
end;

{ --- ExFinally: try/finally cleanup with no exception --- }
{ N=10000 × ITERS=1000 = 10M protected iterations }

procedure ExFinally(const ACtx: IBenchContext);
const
  N = 10000;
  ITERS = 1000;
var
  I, Iter: Integer;
  LSum: Int64;
  LCleanup: Integer;
begin
  LSum := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N-1 do begin
      LCleanup := 0;
      try
        Inc(LSum, I);
      finally
        Inc(LCleanup);
      end;
      Inc(LSum, LCleanup);
    end;
  GSink := LSum;
  ACtx.SetBytes(ITERS * N * SizeOf(Integer));
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('Except');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('ExNoThrow',  @ExNoThrow);
  LSuite.Add('ExCatchRate', @ExCatchRate);
  LSuite.Add('ExMixed',    @ExMixed);
  LSuite.Add('ExFinally',  @ExFinally);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
