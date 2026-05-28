program bench_sort_fpcrtl;

{$mode objfpc}{$H+}

uses
  SysUtils;

type
  TTimeSpec = record
    tv_sec: Int64;
    tv_nsec: Int64;
  end;
  PIntArray = ^TIntArray;
  TIntArray = array[0..0] of Integer;

function clock_gettime(clk_id: Int32; tp: Pointer): Int32; cdecl; external 'c' name 'clock_gettime';

const
  CLOCK_MONOTONIC = 1;
  N = 10000;
  TARGET_NS: Int64 = 100000000;
  SAMPLES = 5;
  MAX_ITERS = 100000;

var
  GRandomData: array[0..N-1] of Integer;
  GSortedData: array[0..N-1] of Integer;
  GReversedData: array[0..N-1] of Integer;
  GAllSameData: array[0..N-1] of Integer;
  GWorkBuf: array[0..N-1] of Integer;

function MonoNs: Int64;
var
  ts: TTimeSpec;
begin
  clock_gettime(CLOCK_MONOTONIC, @ts);
  Result := ts.tv_sec * 1000000000 + ts.tv_nsec;
end;

procedure InitData;
var
  i: Integer;
begin
  RandSeed := 42;
  for i := 0 to N - 1 do
  begin
    GRandomData[i] := Random(1000000);
    GSortedData[i] := i;
    GReversedData[i] := N - 1 - i;
    GAllSameData[i] := 7;
  end;
end;

procedure QSortInts(P: PInteger; L, R: Integer);
var
  i, j, pivot, tmp: Integer;
begin
  while L < R do
  begin
    if R - L < 16 then
    begin
      for i := L + 1 to R do
      begin
        tmp := P[i];
        j := i;
        while (j > L) and (P[j-1] > tmp) do
        begin
          P[j] := P[j-1];
          Dec(j);
        end;
        P[j] := tmp;
      end;
      Exit;
    end;
    i := L;
    j := R;
    pivot := P[(L + R) div 2];
    repeat
      while P[i] < pivot do Inc(i);
      while P[j] > pivot do Dec(j);
      if i <= j then
      begin
        tmp := P[i]; P[i] := P[j]; P[j] := tmp;
        Inc(i); Dec(j);
      end;
    until i > j;
    if (j - L) < (R - i) then
    begin
      QSortInts(P, L, j);
      L := i;
    end
    else
    begin
      QSortInts(P, i, R);
      R := j;
    end;
  end;
end;

procedure BenchSort(const aName: string; aData: PInteger);
var
  LIters, it: Int64;
  LStart, LElapsed: Int64;
  LSamples: array[0..SAMPLES-1] of Int64;
  i, j: Integer;
  LTmp: Int64;
  LNsPerOp, LOpsPerSec: Double;
begin
  for i := 0 to 9 do
  begin
    Move(aData^, GWorkBuf[0], N * SizeOf(Integer));
    QSortInts(@GWorkBuf[0], 0, N - 1);
  end;

  LIters := 100;
  while True do
  begin
    LStart := MonoNs;
    for it := 1 to LIters do
    begin
      Move(aData^, GWorkBuf[0], N * SizeOf(Integer));
      QSortInts(@GWorkBuf[0], 0, N - 1);
    end;
    LElapsed := MonoNs - LStart;
    if LElapsed >= TARGET_NS then Break;
    if LElapsed < 1000000 then
      LIters := LIters * 10
    else
      LIters := Int64(Double(LIters) * Double(TARGET_NS) / Double(LElapsed));
    if LIters < 100 then LIters := 100;
    if LIters > MAX_ITERS then begin LIters := MAX_ITERS; Break; end;
  end;

  for i := 0 to SAMPLES - 1 do
  begin
    LStart := MonoNs;
    for it := 1 to LIters do
    begin
      Move(aData^, GWorkBuf[0], N * SizeOf(Integer));
      QSortInts(@GWorkBuf[0], 0, N - 1);
    end;
    LSamples[i] := MonoNs - LStart;
  end;

  for i := 0 to SAMPLES - 2 do
    for j := i + 1 to SAMPLES - 1 do
      if LSamples[j] < LSamples[i] then
      begin
        LTmp := LSamples[i];
        LSamples[i] := LSamples[j];
        LSamples[j] := LTmp;
      end;

  LNsPerOp := Double(LSamples[SAMPLES div 2]) / Double(LIters);
  if LNsPerOp > 0 then
    LOpsPerSec := 1000000000.0 / LNsPerOp
  else
    LOpsPerSec := 0;

  WriteLn('  ', aName:40, LIters:12, ' iters', LNsPerOp:10:1, ' ns/op', LOpsPerSec:14:0, ' ops/s');
end;

begin
  InitData;
  WriteLn('=== FPC Baseline QuickSort (Hoare, no introsort) (N=', N, ') ===');
  WriteLn;
  BenchSort('QuickSort/random', @GRandomData[0]);
end.
