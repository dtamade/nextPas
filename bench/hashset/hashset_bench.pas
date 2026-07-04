{$mode objfpc}{$H+}
program hashset_bench;

uses
  nextpas.core.base,
  nextpas.core.time.base, nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.collections.hashmap.swiss.i32i32;

const
  N100 = 100;
  N1K = 1000;
  N10K = 10000;
  N100K = 100000;

var
  GKeys: array[0..N100K - 1] of Int32;
  GMiss: array[0..N100K - 1] of Int32;

  GMap100: TSwissTableI32I32;
  GMap1K: TSwissTableI32I32;
  GMap10K: TSwissTableI32I32;
  GMap100K: TSwissTableI32I32;

procedure GenData;
var
  I: Integer;
begin
  for I := 0 to N100K - 1 do
  begin
    GKeys[I] := Int32(I * 2 + 1);
    GMiss[I] := Int32(I * 2);
  end;
end;

procedure BuildMaps;
var
  I: Integer;
begin
  GMap100 := TSwissTableI32I32.Create(N100);
  for I := 0 to N100 - 1 do GMap100.Put(GKeys[I], 0);

  GMap1K := TSwissTableI32I32.Create(N1K);
  for I := 0 to N1K - 1 do GMap1K.Put(GKeys[I], 0);

  GMap10K := TSwissTableI32I32.Create(N10K);
  for I := 0 to N10K - 1 do GMap10K.Put(GKeys[I], 0);

  GMap100K := TSwissTableI32I32.Create(N100K);
  for I := 0 to N100K - 1 do GMap100K.Put(GKeys[I], 0);
end;

{ --- Build (create + insert all) --- }

procedure SwissBuild_100(const ACtx: IBenchContext);
var
  LMap: TSwissTableI32I32;
  I: Integer;
begin
  LMap := TSwissTableI32I32.Create(N100);
  try
    for I := 0 to N100 - 1 do
      LMap.Put(GKeys[I], 0);
  finally
    LMap.Free;
  end;
end;

procedure SwissBuild_1K(const ACtx: IBenchContext);
var
  LMap: TSwissTableI32I32;
  I: Integer;
begin
  LMap := TSwissTableI32I32.Create(N1K);
  try
    for I := 0 to N1K - 1 do
      LMap.Put(GKeys[I], 0);
  finally
    LMap.Free;
  end;
end;

procedure SwissBuild_10K(const ACtx: IBenchContext);
var
  LMap: TSwissTableI32I32;
  I: Integer;
begin
  LMap := TSwissTableI32I32.Create(N10K);
  try
    for I := 0 to N10K - 1 do
      LMap.Put(GKeys[I], 0);
  finally
    LMap.Free;
  end;
end;

procedure SwissBuild_100K(const ACtx: IBenchContext);
var
  LMap: TSwissTableI32I32;
  I: Integer;
begin
  LMap := TSwissTableI32I32.Create(N100K);
  try
    for I := 0 to N100K - 1 do
      LMap.Put(GKeys[I], 0);
  finally
    LMap.Free;
  end;
end;

{ --- Lookup Hit (pre-built map) --- }

procedure SwissLookupHit_100(const ACtx: IBenchContext);
var
  I, LV: Integer;
  Sum: Int32;
begin
  Sum := 0;
  for I := 0 to N100 - 1 do
    if GMap100.TryGetValue(GKeys[I], LV) then
      Inc(Sum);
end;

procedure SwissLookupHit_1K(const ACtx: IBenchContext);
var
  I, LV: Integer;
  Sum: Int32;
begin
  Sum := 0;
  for I := 0 to N1K - 1 do
    if GMap1K.TryGetValue(GKeys[I], LV) then
      Inc(Sum);
end;

procedure SwissLookupHit_10K(const ACtx: IBenchContext);
var
  I, LV: Integer;
  Sum: Int32;
begin
  Sum := 0;
  for I := 0 to N10K - 1 do
    if GMap10K.TryGetValue(GKeys[I], LV) then
      Inc(Sum);
end;

procedure SwissLookupHit_100K(const ACtx: IBenchContext);
var
  I, LV: Integer;
  Sum: Int32;
begin
  Sum := 0;
  for I := 0 to N100K - 1 do
    if GMap100K.TryGetValue(GKeys[I], LV) then
      Inc(Sum);
end;

{ --- Lookup Miss (pre-built map) --- }

procedure SwissLookupMiss_1K(const ACtx: IBenchContext);
var
  I, LV: Integer;
  Sum: Int32;
begin
  Sum := 0;
  for I := 0 to N1K - 1 do
    if GMap1K.TryGetValue(GMiss[I], LV) then
      Inc(Sum);
end;

procedure SwissLookupMiss_10K(const ACtx: IBenchContext);
var
  I, LV: Integer;
  Sum: Int32;
begin
  Sum := 0;
  for I := 0 to N10K - 1 do
    if GMap10K.TryGetValue(GMiss[I], LV) then
      Inc(Sum);
end;

procedure SwissLookupMiss_100K(const ACtx: IBenchContext);
var
  I, LV: Integer;
  Sum: Int32;
begin
  Sum := 0;
  for I := 0 to N100K - 1 do
    if GMap100K.TryGetValue(GMiss[I], LV) then
      Inc(Sum);
end;

{ --- Main --- }

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  GenData;
  BuildMaps;

  WriteLn('=== nextPas hashset_bench (', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%}, ') ===');
  WriteLn;

  { Suite 1: Build }
  LSuite := TBenchSuite.Create('hashset/build');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(10000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('100', @SwissBuild_100);
  LSuite.Add('1K', @SwissBuild_1K);
  LSuite.Add('10K', @SwissBuild_10K);
  LSuite.Add('100K', @SwissBuild_100K);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
  WriteLn;

  { Suite 2: Lookup Hit (pre-built) }
  LSuite := TBenchSuite.Create('hashset/lookup-hit');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(50000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('Hit/100', @SwissLookupHit_100);
  LSuite.Add('Hit/1K', @SwissLookupHit_1K);
  LSuite.Add('Hit/10K', @SwissLookupHit_10K);
  LSuite.Add('Hit/100K', @SwissLookupHit_100K);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
  WriteLn;

  { Suite 3: Lookup Miss (pre-built) }
  LSuite := TBenchSuite.Create('hashset/lookup-miss');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(50000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('Miss/1K', @SwissLookupMiss_1K);
  LSuite.Add('Miss/10K', @SwissLookupMiss_10K);
  LSuite.Add('Miss/100K', @SwissLookupMiss_100K);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
  WriteLn;

  GMap100.Free;
  GMap1K.Free;
  GMap10K.Free;
  GMap100K.Free;
end.
