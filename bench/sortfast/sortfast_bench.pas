program sortfast_bench;

{$mode objfpc}{$H+}

uses SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.collections.arr.sort;

const
  N1K = 1000;
  N10K = 10000;
  N100K = 100000;

var
  GData1K: array[0..N1K-1] of Int32;
  GData10K: array[0..N10K-1] of Int32;
  GData100K: array[0..N100K-1] of Int32;
  GWork: array of Int32;
  GSink: Integer;

procedure InitData;
var
  I: Integer;
begin
  for I := 0 to N100K-1 do
  begin
    GData100K[I] := (I * 2654435761) and $7FFFFFFF;
    if I < N10K then GData10K[I] := GData100K[I];
    if I < N1K then GData1K[I] := GData100K[I];
  end;
end;

{ --- nextpas.core sort (SortI32) --- }

procedure BenchFastSort_1K(const ACtx: IBenchContext);
begin
  SetLength(GWork, N1K);
  Move(GData1K[0], GWork[0], N1K * SizeOf(Int32));
  SortI32(@GWork[0], N1K);
  GSink := GWork[0];
  ACtx.SetBytes(N1K * SizeOf(Int32));
end;

procedure BenchFastSort_10K(const ACtx: IBenchContext);
begin
  SetLength(GWork, N10K);
  Move(GData10K[0], GWork[0], N10K * SizeOf(Int32));
  SortI32(@GWork[0], N10K);
  GSink := GWork[0];
  ACtx.SetBytes(N10K * SizeOf(Int32));
end;

procedure BenchFastSort_100K(const ACtx: IBenchContext);
begin
  SetLength(GWork, N100K);
  Move(GData100K[0], GWork[0], N100K * SizeOf(Int32));
  SortI32(@GWork[0], N100K);
  GSink := GWork[0];
  ACtx.SetBytes(N100K * SizeOf(Int32));
end;

{ --- FPC built-in sort: manual quicksort --- }

function CompareInt32(const A, B: Int32): Integer;
begin
  if A < B then Result := -1
  else if A > B then Result := 1
  else Result := 0;
end;

procedure QuickSortI32(var A: array of Int32; ALo, AHi: Integer);
var
  LPivot, LTmp: Int32;
  I, J: Integer;
begin
  if ALo >= AHi then Exit;
  LPivot := A[(ALo + AHi) shr 1];
  I := ALo;
  J := AHi;
  while I <= J do
  begin
    while A[I] < LPivot do Inc(I);
    while A[J] > LPivot do Dec(J);
    if I <= J then
    begin
      LTmp := A[I]; A[I] := A[J]; A[J] := LTmp;
      Inc(I); Dec(J);
    end;
  end;
  if ALo < J then QuickSortI32(A, ALo, J);
  if I < AHi then QuickSortI32(A, I, AHi);
end;

procedure BenchManualSort_1K(const ACtx: IBenchContext);
var
  LArr: array[0..N1K-1] of Int32;
begin
  Move(GData1K[0], LArr[0], N1K * SizeOf(Int32));
  QuickSortI32(LArr, 0, N1K-1);
  GSink := LArr[0];
  ACtx.SetBytes(N1K * SizeOf(Int32));
end;

procedure BenchManualSort_10K(const ACtx: IBenchContext);
var
  LArr: array[0..N10K-1] of Int32;
begin
  Move(GData10K[0], LArr[0], N10K * SizeOf(Int32));
  QuickSortI32(LArr, 0, N10K-1);
  GSink := LArr[0];
  ACtx.SetBytes(N10K * SizeOf(Int32));
end;

procedure BenchManualSort_100K(const ACtx: IBenchContext);
begin
  SetLength(GWork, N100K);
  Move(GData100K[0], GWork[0], N100K * SizeOf(Int32));
  QuickSortI32(GWork, 0, N100K-1);
  GSink := GWork[0];
  ACtx.SetBytes(N100K * SizeOf(Int32));
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  LSuite := TBenchSuite.Create('sortfast');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('FastSort/1K', @BenchFastSort_1K);
  LSuite.Add('FastSort/10K', @BenchFastSort_10K);
  LSuite.Add('FastSort/100K', @BenchFastSort_100K);
  LSuite.Add('ManualSort/1K', @BenchManualSort_1K);
  LSuite.Add('ManualSort/10K', @BenchManualSort_10K);
  LSuite.Add('ManualSort/100K', @BenchManualSort_100K);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
