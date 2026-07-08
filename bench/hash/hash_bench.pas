program hash_bench;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.text.conv,
  nextpas.core.collections.hashmap.swiss.str;

const
  N = 100000;

type
  TIntMap = specialize TSwissTableStr<Integer>;

var
  GKeys: array[0..N-1] of string;
  GMissKeys: array[0..N-1] of string;
  GLookupMap: TIntMap;
  I: Integer;

procedure InitData;
begin
  for I := 0 to N - 1 do
  begin
    GKeys[I] := 'key_' + IntToStr(I);
    GMissKeys[I] := 'miss_' + IntToStr(I);
  end;
  GLookupMap := TIntMap.Create(N);
  for I := 0 to N - 1 do
    GLookupMap.Put(GKeys[I], I);
end;

procedure BenchInsert(const ACtx: IBenchContext);
var
  Map: TIntMap;
  J: Integer;
begin
  Map := TIntMap.Create(N);
  for J := 0 to N - 1 do
    Map.Put(GKeys[J], J);
  ACtx.SetBytes(N * 16);
  Map.Free;
end;

procedure BenchLookup(const ACtx: IBenchContext);
var
  J: Integer;
  V: Integer;
  Found: Boolean;
begin
  for J := 0 to N - 1 do
    Found := GLookupMap.TryGetValue(GKeys[J], V);
  ACtx.SetBytes(N * 16);
  if not Found then WriteLn('');
end;

procedure BenchInsertLookup(const ACtx: IBenchContext);
var
  Map: TIntMap;
  J: Integer;
  V: Integer;
  Found: Boolean;
begin
  Map := TIntMap.Create(N);
  for J := 0 to N - 1 do
    Map.Put(GKeys[J], J);
  for J := 0 to N - 1 do
    Found := Map.TryGetValue(GKeys[J], V);
  ACtx.SetBytes(N * 32);
  if not Found then WriteLn('');
  Map.Free;
end;

procedure BenchLookupMiss(const ACtx: IBenchContext);
var
  J: Integer;
  V: Integer;
  Found: Boolean;
begin
  for J := 0 to N - 1 do
    Found := GLookupMap.TryGetValue(GMissKeys[J], V);
  ACtx.SetBytes(N * 16);
  if Found then WriteLn('');
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitData;

  WriteLn('=== nextPas HashMap Benchmark ===');
  WriteLn('N=', N, ' string keys');
  WriteLn;

  LSuite := TBenchSuite.Create('hash')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Insert/100k', @BenchInsert);
  LSuite.Add('Lookup/100k', @BenchLookup);
  LSuite.Add('InsertLookup/100k', @BenchInsertLookup);
  LSuite.Add('LookupMiss/100k', @BenchLookupMiss);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);

  GLookupMap.Free;
end.
