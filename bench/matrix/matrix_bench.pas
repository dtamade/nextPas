{$mode objfpc}{$H+}
program matrix_bench;

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N128 = 128;
  N256 = 256;
  N512 = 512;

type
  TMat128 = array[0..N128-1, 0..N128-1] of Int64;
  TMat256 = array[0..N256-1, 0..N256-1] of Int64;
  TMat512 = array[0..N512-1, 0..N512-1] of Int64;

var
  GA128, GB128, GC128: TMat128;
  GA256, GB256, GC256: TMat256;
  GA512, GB512, GC512: TMat512;

procedure InitData;
var
  I, J: Integer;
begin
  for I := 0 to N128 - 1 do
    for J := 0 to N128 - 1 do
    begin
      GA128[I, J] := I * N128 + J + 1;
      GB128[I, J] := (I + 1) * (J + 1);
    end;
  for I := 0 to N256 - 1 do
    for J := 0 to N256 - 1 do
    begin
      GA256[I, J] := I * N256 + J + 1;
      GB256[I, J] := (I + 1) * (J + 1);
    end;
  for I := 0 to N512 - 1 do
    for J := 0 to N512 - 1 do
    begin
      GA512[I, J] := I * N512 + J + 1;
      GB512[I, J] := (I + 1) * (J + 1);
    end;
end;

{ --- MatMul 128x128: compute-bound --- }
procedure BenchMatMul128(const ACtx: IBenchContext);
var
  I, J, K: Integer;
  LSum: Int64;
begin
  for I := 0 to N128 - 1 do
    for J := 0 to N128 - 1 do
    begin
      LSum := 0;
      for K := 0 to N128 - 1 do
        LSum += GA128[I, K] * GB128[K, J];
      GC128[I, J] := LSum;
    end;
  ACtx.SetBytes(Int64(N128) * N128 * N128 * 2 * SizeOf(Int64));
end;

{ --- MatAdd 512x512: memory-bound --- }
procedure BenchMatAdd512(const ACtx: IBenchContext);
var
  I, J: Integer;
begin
  for I := 0 to N512 - 1 do
    for J := 0 to N512 - 1 do
      GC512[I, J] := GA512[I, J] + GB512[I, J];
  ACtx.SetBytes(Int64(N512) * N512 * 3 * SizeOf(Int64));
end;

{ --- Transpose 512x512: cache miss pattern --- }
procedure BenchTranspose512(const ACtx: IBenchContext);
var
  I, J: Integer;
  LTmp: Int64;
begin
  GC512 := GA512;
  for I := 0 to N512 - 1 do
    for J := I + 1 to N512 - 1 do
    begin
      LTmp := GC512[I, J];
      GC512[I, J] := GC512[J, I];
      GC512[J, I] := LTmp;
    end;
  ACtx.SetBytes(Int64(N512) * N512 * 2 * SizeOf(Int64));
end;

{ --- MatMul 256x256: larger compute-bound --- }
procedure BenchMatMul256(const ACtx: IBenchContext);
var
  I, J, K: Integer;
  LSum: Int64;
begin
  for I := 0 to N256 - 1 do
    for J := 0 to N256 - 1 do
    begin
      LSum := 0;
      for K := 0 to N256 - 1 do
        LSum += GA256[I, K] * GB256[K, J];
      GC256[I, J] := LSum;
    end;
  ACtx.SetBytes(Int64(N256) * N256 * N256 * 2 * SizeOf(Int64));
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  LSuite := TBenchSuite.Create('Matrix');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(100);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('MatMul/128', @BenchMatMul128);
  LSuite.Add('MatAdd/512', @BenchMatAdd512);
  LSuite.Add('Transpose/512', @BenchTranspose512);
  LSuite.Add('MatMul/256', @BenchMatMul256);

  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
end.
