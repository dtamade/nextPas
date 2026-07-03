{$mode objfpc}{$H+}
program binsearch_bench;

uses
  SysUtils, Classes, nextpas.core.base,
  nextpas.core.time.base, nextpas.core.bench, nextpas.core.bench.intf;

const
  N = 100000;

var
  GArr: array[0..N - 1] of Int32;
  GQueries: array[0..N - 1] of Int32;
  GMissQ: array[0..N - 1] of Int32;

procedure GenData;
var
  I: Integer;
begin
  for I := 0 to N - 1 do
    GArr[I] := Int32(I * 2 + 1);  { sorted odd numbers }
  for I := 0 to N - 1 do
    GQueries[I] := GArr[I];       { all hits }
  for I := 0 to N - 1 do
    GMissQ[I] := Int32(I * 2);    { even = all misses }
end;

{ --- Standard binary search (branching) --- }
function BinSearchStd(APtr: PInt32; ACount: Integer; AVal: Int32): Boolean;
var
  L, R, M: Integer;
  V: Int32;
begin
  L := 0;
  R := ACount - 1;
  while L <= R do
  begin
    M := L + (R - L) shr 1;
    V := APtr[M];
    if V = AVal then
      Exit(True)
    else if V < AVal then
      L := M + 1
    else
      R := M - 1;
  end;
  Result := False;
end;

{ --- Branchless-like binary search: only narrow range, check at end --- }
function BinSearchBranchless(APtr: PInt32; ACount: Integer; AVal: Int32): Boolean;
var
  L, R, M: Integer;
  V: Int32;
begin
  L := 0;
  R := ACount;
  while L < R do
  begin
    M := L + (R - L) shr 1;
    V := APtr[M];
    if V < AVal then
      L := M + 1
    else
      R := M;
  end;
  Result := (L < ACount) and (APtr[L] = AVal);
end;

{ --- Eytzinger layout binary search --- }
{ Build eytzinger array from sorted input }
var
  GEytz: array[0..N - 1] of Int32;

procedure BuildEytzinger(ASrc: PInt32; ASrcN: Integer);
var
  Idx: Integer;

  procedure Visit(K, I: Integer);
  begin
    if K <= ASrcN then
    begin
      Visit(2 * K, I);
      if Idx < ASrcN then
      begin
        GEytz[K - 1] := ASrc[Idx];
        Inc(Idx);
      end;
      Visit(2 * K + 1, Idx);
    end;
  end;

begin
  Idx := 0;
  Visit(1, 0);
end;

{ Eytzinger search: only follow one branch (cache-friendly) }
function BinSearchEytz(APtr: PInt32; AN: Integer; AVal: Int32): Boolean;
var
  K: Integer;
begin
  K := 1;
  while K <= AN do
  begin
    if APtr[K - 1] < AVal then
      K := 2 * K + 1
    else if APtr[K - 1] = AVal then
      Exit(True)
    else
      K := 2 * K;
  end;
  Result := False;
end;

{ --- Benchmarks --- }

procedure StdSearch_Hit(const ACtx: IBenchContext);
var
  I, Sum: Integer;
begin
  Sum := 0;
  for I := 0 to N - 1 do
    if BinSearchStd(@GArr[0], N, GQueries[I]) then
      Inc(Sum);
end;

procedure BranchlessSearch_Hit(const ACtx: IBenchContext);
var
  I, Sum: Integer;
begin
  Sum := 0;
  for I := 0 to N - 1 do
    if BinSearchBranchless(@GArr[0], N, GQueries[I]) then
      Inc(Sum);
end;

procedure EytzingerSearch_Hit(const ACtx: IBenchContext);
var
  I, Sum: Integer;
begin
  Sum := 0;
  for I := 0 to N - 1 do
    if BinSearchEytz(@GEytz[0], N, GQueries[I]) then
      Inc(Sum);
end;

procedure StdSearch_Miss(const ACtx: IBenchContext);
var
  I, Sum: Integer;
begin
  Sum := 0;
  for I := 0 to N - 1 do
    if BinSearchStd(@GArr[0], N, GMissQ[I]) then
      Inc(Sum);
end;

procedure BranchlessSearch_Miss(const ACtx: IBenchContext);
var
  I, Sum: Integer;
begin
  Sum := 0;
  for I := 0 to N - 1 do
    if BinSearchBranchless(@GArr[0], N, GMissQ[I]) then
      Inc(Sum);
end;

procedure EytzingerSearch_Miss(const ACtx: IBenchContext);
var
  I, Sum: Integer;
begin
  Sum := 0;
  for I := 0 to N - 1 do
    if BinSearchEytz(@GEytz[0], N, GMissQ[I]) then
      Inc(Sum);
end;

var
  LSuite: TBenchSuite;
  LResults: IBenchResults;
begin
  GenData;
  BuildEytzinger(@GArr[0], N);

  WriteLn('=== nextPas binsearch_bench (', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%}, ') ===');
  WriteLn;

  LSuite := TBenchSuite.Create('BinSearchHit');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(1000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('Standard', @StdSearch_Hit);
  LSuite.Add('Branchless', @BranchlessSearch_Hit);
  LSuite.Add('Eytzinger', @EytzingerSearch_Hit);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
  WriteLn;

  LSuite := TBenchSuite.Create('BinSearchMiss');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(1000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('Standard', @StdSearch_Miss);
  LSuite.Add('Branchless', @BranchlessSearch_Miss);
  LSuite.Add('Eytzinger', @EytzingerSearch_Miss);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
  WriteLn;
end.
