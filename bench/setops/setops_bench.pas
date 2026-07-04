{$mode objfpc}{$H+}
program setops_bench;

uses
  SysUtils, Classes, nextpas.core.base,
  nextpas.core.time.base, nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.collections.arr.sort,
  nextpas.core.collections.hashmap.swiss.i32i32;

const
  N10K = 10000;
  N100K = 100000;

var
  GSorted10K: array[0..N10K - 1] of Int32;
  GSorted100K: array[0..N100K - 1] of Int32;
  GOut: array[0..N100K - 1] of Int32;

procedure GenData;
var
  I: Integer;
begin
  for I := 0 to N10K - 1 do
    GSorted10K[I] := Int32(I * 3 + 1);     { every 3rd }
  for I := 0 to N100K - 1 do
    GSorted100K[I] := Int32(I * 2 + 1);     { every 2nd (odd) }
end;

{ --- Sorted Intersection (merge-based) --- }
function SortedIntersect(ADst: PInt32; AA: PInt32; NA: Integer; AB: PInt32; NB: Integer): Integer;
var
  I, J, K: Integer;
  VA, VB: Int32;
begin
  I := 0; J := 0; K := 0;
  while (I < NA) and (J < NB) do
  begin
    VA := AA[I];
    VB := AB[J];
    if VA = VB then
    begin
      ADst[K] := VA;
      Inc(K); Inc(I); Inc(J);
    end
    else if VA < VB then
      Inc(I)
    else
      Inc(J);
  end;
  Result := K;
end;

procedure Intersect_10K(const ACtx: IBenchContext);
var C: Integer;
begin
  C := SortedIntersect(@GOut[0], @GSorted10K[0], N10K, @GSorted100K[0], N100K);
  if C < 0 then WriteLn(C);
end;

procedure Intersect_100K(const ACtx: IBenchContext);
var C: Integer;
begin
  C := SortedIntersect(@GOut[0], @GSorted100K[0], N100K, @GSorted100K[0], N100K);
  if C < 0 then WriteLn(C);
end;

{ --- Count-Only Intersection (no write) --- }
function SortedIntersectCount(AA: PInt32; NA: Integer; AB: PInt32; NB: Integer): Integer;
var
  I, J, K: Integer;
  VA, VB: Int32;
begin
  I := 0; J := 0; K := 0;
  while (I < NA) and (J < NB) do
  begin
    VA := AA[I];
    VB := AB[J];
    if VA = VB then
    begin
      Inc(K); Inc(I); Inc(J);
    end
    else if VA < VB then
      Inc(I)
    else
      Inc(J);
  end;
  Result := K;
end;

procedure CountIntersect_10K(const ACtx: IBenchContext);
var C: Integer;
begin
  C := SortedIntersectCount(@GSorted10K[0], N10K, @GSorted100K[0], N100K);
  if C < 0 then WriteLn(C);
end;

procedure CountIntersect_100K(const ACtx: IBenchContext);
var C: Integer;
begin
  C := SortedIntersectCount(@GSorted100K[0], N100K, @GSorted100K[0], N100K);
  if C < 0 then WriteLn(C);
end;

{ --- Sorted Union (merge-based) --- }
function SortedUnion(ADst: PInt32; AA: PInt32; NA: Integer; AB: PInt32; NB: Integer): Integer;
var
  I, J, K: Integer;
  VA, VB: Int32;
begin
  I := 0; J := 0; K := 0;
  while (I < NA) and (J < NB) do
  begin
    VA := AA[I]; VB := AB[J];
    if VA = VB then
    begin
      ADst[K] := VA; Inc(K); Inc(I); Inc(J);
    end
    else if VA < VB then
    begin
      ADst[K] := VA; Inc(K); Inc(I);
    end
    else
    begin
      ADst[K] := VB; Inc(K); Inc(J);
    end;
  end;
  while I < NA do begin ADst[K] := AA[I]; Inc(K); Inc(I); end;
  while J < NB do begin ADst[K] := AB[J]; Inc(K); Inc(J); end;
  Result := K;
end;

procedure Union_10K(const ACtx: IBenchContext);
var C: Integer;
begin
  C := SortedUnion(@GOut[0], @GSorted10K[0], N10K, @GSorted100K[0], N100K);
  if C < 0 then WriteLn(C);
end;

procedure Union_100K(const ACtx: IBenchContext);
var C: Integer;
begin
  C := SortedUnion(@GOut[0], @GSorted100K[0], N100K, @GSorted100K[0], N100K);
  if C < 0 then WriteLn(C);
end;

{ --- SwissTable-based Intersection --- }
procedure SwissIntersect_10K(const ACtx: IBenchContext);
var
  LMap: TSwissTableI32I32;
  I, LV, C: Integer;
begin
  LMap := TSwissTableI32I32.Create(N10K);
  try
    for I := 0 to N10K - 1 do
      LMap.Put(GSorted10K[I], 1);
    C := 0;
    for I := 0 to N100K - 1 do
      if LMap.TryGetValue(GSorted100K[I], LV) then
        Inc(C);
  finally
    LMap.Free;
  end;
end;

procedure SwissIntersect_100K(const ACtx: IBenchContext);
var
  LMap: TSwissTableI32I32;
  I, LV, C: Integer;
begin
  LMap := TSwissTableI32I32.Create(N100K);
  try
    for I := 0 to N100K - 1 do
      LMap.Put(GSorted100K[I], 1);
    C := 0;
    for I := 0 to N100K - 1 do
      if LMap.TryGetValue(GSorted100K[I], LV) then
        Inc(C);
  finally
    LMap.Free;
  end;
end;

var
  LSuite: TBenchSuite;
  LResults: IBenchResults;
begin
  GenData;

  WriteLn('=== nextPas setops_bench (', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%}, ') ===');
  WriteLn;

  LSuite := TBenchSuite.Create('Intersection');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(10000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('Merge/10Kx100K', @Intersect_10K);
  LSuite.Add('Merge/100Kx100K', @Intersect_100K);
  LSuite.Add('Count/10Kx100K', @CountIntersect_10K);
  LSuite.Add('Count/100Kx100K', @CountIntersect_100K);
  LSuite.Add('Swiss/10Kx100K', @SwissIntersect_10K);
  LSuite.Add('Swiss/100Kx100K', @SwissIntersect_100K);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
  WriteLn;

  LSuite := TBenchSuite.Create('Union');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(10000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('Merge/10Kx100K', @Union_10K);
  LSuite.Add('Merge/100Kx100K', @Union_100K);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
  WriteLn;
end.
