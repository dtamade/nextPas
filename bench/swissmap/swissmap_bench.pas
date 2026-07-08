program swissmap_bench;

{$mode objfpc}{$H+}

uses nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.collections.hashmap.swiss.i32i32;

const
  N1K = 1000;
  N10K = 10000;
  N100K = 100000;

var
  GKeys1K, GKeys10K, GKeys100K: array of Int32;
  GShuffledKeys: array of Int32;
  GSink: Integer;

procedure InitData;
var
  I: Integer;
begin
  SetLength(GKeys100K, N100K);
  SetLength(GKeys10K, N10K);
  SetLength(GKeys1K, N1K);
  for I := 0 to N100K-1 do
  begin
    GKeys100K[I] := (I * 2654435761) and $7FFFFFFF;
    if I < N10K then GKeys10K[I] := GKeys100K[I];
    if I < N1K then GKeys1K[I] := GKeys100K[I];
  end;
  { Shuffled keys for lookup miss }
  SetLength(GShuffledKeys, N100K);
  for I := 0 to N100K-1 do
    GShuffledKeys[I] := ((I + N100K) * 2654435761) and $7FFFFFFF;
end;

{ --- SwissMap Put/1K --- }

procedure BenchSwiss_Put1K(const ACtx: IBenchContext);
var
  LMap: TSwissTableI32I32;
  I: Integer;
begin
  LMap := TSwissTableI32I32.Create(N1K);
  try
    for I := 0 to N1K-1 do
      LMap.Put(GKeys1K[I], I);
    GSink := LMap.Get(GKeys1K[0]);
  finally
    LMap.Free;
  end;
  ACtx.SetBytes(N1K * 8);
end;

{ --- SwissMap Put/10K --- }

procedure BenchSwiss_Put10K(const ACtx: IBenchContext);
var
  LMap: TSwissTableI32I32;
  I: Integer;
begin
  LMap := TSwissTableI32I32.Create(N10K);
  try
    for I := 0 to N10K-1 do
      LMap.Put(GKeys10K[I], I);
    GSink := LMap.Get(GKeys10K[0]);
  finally
    LMap.Free;
  end;
  ACtx.SetBytes(N10K * 8);
end;

{ --- SwissMap Put/100K --- }

procedure BenchSwiss_Put100K(const ACtx: IBenchContext);
var
  LMap: TSwissTableI32I32;
  I: Integer;
begin
  LMap := TSwissTableI32I32.Create(N100K);
  try
    for I := 0 to N100K-1 do
      LMap.Put(GKeys100K[I], I);
    GSink := LMap.Get(GKeys100K[0]);
  finally
    LMap.Free;
  end;
  ACtx.SetBytes(N100K * 8);
end;

{ --- SwissMap Lookup/1K --- }

procedure BenchSwiss_Lookup1K(const ACtx: IBenchContext);
var
  LMap: TSwissTableI32I32;
  I, LVal: Integer;
begin
  LMap := TSwissTableI32I32.Create(N1K);
  try
    for I := 0 to N1K-1 do
      LMap.Put(GKeys1K[I], I);
    for I := 0 to N1K-1 do
      LMap.TryGetValue(GKeys1K[I], LVal);
    GSink := LVal;
  finally
    LMap.Free;
  end;
  ACtx.SetBytes(N1K * 8);
end;

{ --- SwissMap Lookup/10K --- }

procedure BenchSwiss_Lookup10K(const ACtx: IBenchContext);
var
  LMap: TSwissTableI32I32;
  I, LVal: Integer;
begin
  LMap := TSwissTableI32I32.Create(N10K);
  try
    for I := 0 to N10K-1 do
      LMap.Put(GKeys10K[I], I);
    for I := 0 to N10K-1 do
      LMap.TryGetValue(GKeys10K[I], LVal);
    GSink := LVal;
  finally
    LMap.Free;
  end;
  ACtx.SetBytes(N10K * 8);
end;

{ --- SwissMap Lookup Miss/1K --- }

procedure BenchSwiss_Miss1K(const ACtx: IBenchContext);
var
  LMap: TSwissTableI32I32;
  I, LVal: Integer;
  LCount: Integer;
begin
  LMap := TSwissTableI32I32.Create(N1K);
  try
    for I := 0 to N1K-1 do
      LMap.Put(GKeys1K[I], I);
    LCount := 0;
    for I := 0 to N1K-1 do
      if LMap.TryGetValue(GShuffledKeys[I], LVal) then Inc(LCount);
    GSink := LCount;
  finally
    LMap.Free;
  end;
  ACtx.SetBytes(N1K * 8);
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  LSuite := TBenchSuite.Create('swissmap');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);

  LSuite.Add('Swiss/Put/1K', @BenchSwiss_Put1K);
  LSuite.Add('Swiss/Put/10K', @BenchSwiss_Put10K);
  LSuite.Add('Swiss/Put/100K', @BenchSwiss_Put100K);
  LSuite.Add('Swiss/Lookup/1K', @BenchSwiss_Lookup1K);
  LSuite.Add('Swiss/Lookup/10K', @BenchSwiss_Lookup10K);
  LSuite.Add('Swiss/Miss/1K', @BenchSwiss_Miss1K);

  LResults := LSuite.Run;
  LResults.ToBenchStat;
end.
