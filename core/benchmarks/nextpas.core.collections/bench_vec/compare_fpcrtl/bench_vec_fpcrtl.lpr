program bench_vec_fpcrtl;

{$mode objfpc}{$H+}

uses
  SysUtils;

type
  TTimeSpec = record
    tv_sec: Int64;
    tv_nsec: Int64;
  end;

function clock_gettime(clk_id: Int32; tp: Pointer): Int32; cdecl; external 'c' name 'clock_gettime';

const
  CLOCK_MONOTONIC = 1;
  N = 100000;
  TARGET_NS: Int64 = 50000000;
  SAMPLES = 3;
  MAX_ITERS = 1000;

var
  GSink: Int64;

function MonoNs: Int64;
var
  ts: TTimeSpec;
begin
  clock_gettime(CLOCK_MONOTONIC, @ts);
  Result := ts.tv_sec * 1000000000 + ts.tv_nsec;
end;

type
  TBenchProc = procedure;

procedure Bench(const aName: string; aProc: TBenchProc);
var
  LIters, it: Int64;
  LStart, LElapsed: Int64;
  LSamples: array[0..SAMPLES-1] of Int64;
  i, j: Integer;
  LTmp: Int64;
  LNsPerOp, LOpsPerSec: Double;
begin
  for i := 0 to 4 do aProc();

  LIters := 10;
  while True do
  begin
    LStart := MonoNs;
    for it := 1 to LIters do aProc();
    LElapsed := MonoNs - LStart;
    if LElapsed >= TARGET_NS then Break;
    if LElapsed < 1000000 then LIters := LIters * 10
    else LIters := Int64(Double(LIters) * Double(TARGET_NS) / Double(LElapsed));
    if LIters < 10 then LIters := 10;
    if LIters > MAX_ITERS then begin LIters := MAX_ITERS; Break; end;
  end;

  for i := 0 to SAMPLES - 1 do
  begin
    LStart := MonoNs;
    for it := 1 to LIters do aProc();
    LSamples[i] := MonoNs - LStart;
  end;

  for i := 0 to SAMPLES - 2 do
    for j := i + 1 to SAMPLES - 1 do
      if LSamples[j] < LSamples[i] then
      begin LTmp := LSamples[i]; LSamples[i] := LSamples[j]; LSamples[j] := LTmp; end;

  LNsPerOp := Double(LSamples[SAMPLES div 2]) / Double(LIters);
  LOpsPerSec := 1e9 / LNsPerOp;
  WriteLn('  ', aName:40, LIters:8, ' iters', LNsPerOp:10:1, ' ns/op', LOpsPerSec:14:0, ' ops/s');
end;

var
  GData: array of Int32;

procedure BenchPush;
var
  A: array of Int32;
  i: Integer;
begin
  SetLength(A, 0);
  for i := 0 to N - 1 do
  begin
    SetLength(A, Length(A) + 1);
    A[High(A)] := i;
  end;
  GSink := GSink + Length(A);
end;

procedure BenchPushPrealloc;
var
  A: array of Int32;
  i: Integer;
begin
  SetLength(A, N);
  for i := 0 to N - 1 do
    A[i] := i;
  GSink := GSink + Length(A);
end;

procedure BenchPop;
var
  A: array of Int32;
  i: Integer;
begin
  SetLength(A, N);
  for i := N - 1 downto 0 do
    SetLength(A, i);
  GSink := GSink + Length(A);
end;

procedure BenchGet;
var
  i: Integer;
  LSum: Int64;
begin
  LSum := 0;
  for i := 0 to N - 1 do
    LSum := LSum + GData[i];
  GSink := GSink + LSum;
end;

procedure BenchIterate;
var
  i: Integer;
  LSum: Int64;
begin
  LSum := 0;
  for i := 0 to High(GData) do
    LSum := LSum + GData[i];
  GSink := GSink + LSum;
end;

procedure BenchInsertMid;
var
  A: array of Int32;
  i, mid, j: Integer;
begin
  SetLength(A, 0);
  for i := 0 to 999 do
  begin
    mid := Length(A) div 2;
    SetLength(A, Length(A) + 1);
    for j := High(A) downto mid + 1 do
      A[j] := A[j - 1];
    A[mid] := i;
  end;
  GSink := GSink + Length(A);
end;

procedure BenchDeleteMid;
var
  A: array of Int32;
  i, mid, j, LLen: Integer;
begin
  SetLength(A, 1000);
  for i := 0 to 999 do
  begin
    LLen := Length(A);
    if LLen = 0 then Break;
    mid := LLen div 2;
    for j := mid to LLen - 2 do
      A[j] := A[j + 1];
    SetLength(A, LLen - 1);
  end;
  GSink := GSink + Length(A);
end;

begin
  SetLength(GData, N);
  WriteLn('=== FPC RTL dynamic array Benchmark (N=', N, ') ===');
  WriteLn;
  Bench('dynarray SetLength+assign/N=100000', @BenchPush);
  Bench('dynarray prealloc assign/N=100000', @BenchPushPrealloc);
  Bench('dynarray SetLength pop/N=100000', @BenchPop);
  Bench('dynarray[i] get/N=100000', @BenchGet);
  Bench('dynarray iterate/N=100000', @BenchIterate);
  Bench('dynarray insert(mid)/N=1000', @BenchInsertMid);
  Bench('dynarray delete(mid)/N=1000', @BenchDeleteMid);
  if GSink = -999 then WriteLn(GSink);
end.
