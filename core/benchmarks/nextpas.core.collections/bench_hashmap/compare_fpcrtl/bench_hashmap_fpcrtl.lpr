program bench_hashmap_fpcrtl;

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
  HASH_SIZE = 131072;

type
  PEntry = ^TEntry;
  TEntry = record
    Key: Int32;
    Value: Int32;
    Next: PEntry;
  end;

  TSimpleHashMap = record
    Buckets: array of PEntry;
    Count: Integer;
  end;

var
  GSink: Int64;

function MonoNs: Int64;
var ts: TTimeSpec;
begin
  clock_gettime(CLOCK_MONOTONIC, @ts);
  Result := ts.tv_sec * 1000000000 + ts.tv_nsec;
end;

procedure InitMap(out M: TSimpleHashMap);
begin
  SetLength(M.Buckets, HASH_SIZE);
  FillChar(M.Buckets[0], HASH_SIZE * SizeOf(Pointer), 0);
  M.Count := 0;
end;

procedure FreeMap(var M: TSimpleHashMap);
var i: Integer; p, n: PEntry;
begin
  for i := 0 to High(M.Buckets) do
  begin
    p := M.Buckets[i];
    while p <> nil do begin n := p^.Next; Dispose(p); p := n; end;
  end;
  SetLength(M.Buckets, 0);
end;

function HashKey(k: Int32): UInt32; inline;
begin
  Result := UInt32(k) * 2654435761;
end;

procedure MapPut(var M: TSimpleHashMap; k, v: Int32);
var idx: UInt32; p: PEntry;
begin
  idx := HashKey(k) and (HASH_SIZE - 1);
  p := M.Buckets[idx];
  while p <> nil do
  begin
    if p^.Key = k then begin p^.Value := v; Exit; end;
    p := p^.Next;
  end;
  New(p);
  p^.Key := k;
  p^.Value := v;
  p^.Next := M.Buckets[idx];
  M.Buckets[idx] := p;
  Inc(M.Count);
end;

function MapGet(var M: TSimpleHashMap; k: Int32; out v: Int32): Boolean;
var idx: UInt32; p: PEntry;
begin
  idx := HashKey(k) and (HASH_SIZE - 1);
  p := M.Buckets[idx];
  while p <> nil do
  begin
    if p^.Key = k then begin v := p^.Value; Exit(True); end;
    p := p^.Next;
  end;
  Result := False;
end;

type TBenchProc = procedure;

procedure Bench(const aName: string; aProc: TBenchProc);
var
  LIters, it: Int64;
  LStart, LElapsed: Int64;
  LSamples: array[0..SAMPLES-1] of Int64;
  i, j: Integer;
  LTmp: Int64;
  LNsPerOp, LOpsPerSec: Double;
begin
  for i := 0 to 2 do aProc();
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

var GMap: TSimpleHashMap;
    i: Integer;

procedure BenchPut;
var M: TSimpleHashMap; i: Integer;
begin
  InitMap(M);
  for i := 0 to N - 1 do MapPut(M, i, i);
  GSink := GSink + M.Count;
  FreeMap(M);
end;

procedure BenchGetHit;
var i, v: Integer;
begin
  for i := 0 to N - 1 do
    if MapGet(GMap, i, v) then GSink := GSink + v;
end;

procedure BenchGetMiss;
var i, v: Integer;
begin
  for i := N to N + N - 1 do
    if MapGet(GMap, i, v) then GSink := GSink + v;
end;

begin
  InitMap(GMap);
  for i := 0 to N - 1 do MapPut(GMap, i, i);

  WriteLn('=== FPC chained hash table Benchmark (N=', N, ') ===');
  WriteLn;
  Bench('ChainedHash.Put/N=100000', @BenchPut);
  Bench('ChainedHash.Get(hit)/N=100000', @BenchGetHit);
  Bench('ChainedHash.Get(miss)/N=100000', @BenchGetMiss);
  FreeMap(GMap);
  if GSink = -1 then WriteLn(GSink);
end.
