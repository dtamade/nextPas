program dynarray_bench;

{$mode objfpc}{$H+}

uses SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 100000;

var
  GSink: Integer;

procedure BenchBuildAppend(const ACtx: IBenchContext);
var
  I: Integer;
  LArr: array of Integer;
begin
  SetLength(LArr, 0);
  for I := 0 to N-1 do
  begin
    SetLength(LArr, Length(LArr) + 1);
    LArr[High(LArr)] := I;
  end;
  GSink := Length(LArr);
  ACtx.SetBytes(N * SizeOf(Integer));
end;

procedure BenchBuildPrealloc(const ACtx: IBenchContext);
var
  I: Integer;
  LArr: array of Integer;
begin
  SetLength(LArr, N);
  for I := 0 to N-1 do
    LArr[I] := I;
  GSink := Length(LArr);
  ACtx.SetBytes(N * SizeOf(Integer));
end;

procedure BenchBuildDoubling(const ACtx: IBenchContext);
var
  I, LLen, LCap: Integer;
  LArr: array of Integer;
begin
  LCap := 16;
  LLen := 0;
  SetLength(LArr, LCap);
  for I := 0 to N-1 do
  begin
    if LLen >= LCap then
    begin
      LCap := LCap * 2;
      SetLength(LArr, LCap);
    end;
    LArr[LLen] := I;
    Inc(LLen);
  end;
  SetLength(LArr, LLen);
  GSink := Length(LArr);
  ACtx.SetBytes(N * SizeOf(Integer));
end;

procedure BenchConcat(const ACtx: IBenchContext);
var
  I: Integer;
  LA, LB, LC: array of Integer;
begin
  SetLength(LA, N div 2);
  SetLength(LB, N div 2);
  for I := 0 to (N div 2) - 1 do
  begin
    LA[I] := I;
    LB[I] := I + N div 2;
  end;
  SetLength(LC, N);
  for I := 0 to (N div 2) - 1 do
    LC[I] := LA[I];
  for I := 0 to (N div 2) - 1 do
    LC[I + N div 2] := LB[I];
  GSink := Length(LC);
  ACtx.SetBytes(N * SizeOf(Integer));
end;

procedure BenchSliceCopy(const ACtx: IBenchContext);
var
  I, LStart, LEnd: Integer;
  LSrc, LDst: array of Integer;
begin
  SetLength(LSrc, N);
  for I := 0 to N-1 do
    LSrc[I] := I;
  SetLength(LDst, N);
  for I := 0 to 99 do
  begin
    LStart := I * 1000;
    LEnd := LStart + 500;
    Move(LSrc[LStart], LDst[0], (LEnd - LStart) * SizeOf(Integer));
  end;
  GSink := Length(LDst);
  ACtx.SetBytes(100 * 500 * SizeOf(Integer));
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  LSuite := TBenchSuite.Create('dynarray');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('BuildAppend/100K', @BenchBuildAppend);
  LSuite.Add('BuildPrealloc/100K', @BenchBuildPrealloc);
  LSuite.Add('BuildDoubling/100K', @BenchBuildDoubling);
  LSuite.Add('Concat/100K', @BenchConcat);
  LSuite.Add('SliceCopy/100K', @BenchSliceCopy);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
