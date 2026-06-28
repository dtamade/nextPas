{**
 * bench_arena2.pas — nextPas vs Go vs Rust 综合竞技场 v2
 *
 * 修正：HashMap 预分配容量（公平对比 Go make(map, N)）
 *}
program bench_arena2;
{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  {$ifdef unix}cthreads,{$endif}
  SysUtils, Classes,
  nextpas.core.collections.hashmap,
  nextpas.core.text.builder,
  nextpas.core.json,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  np_sort_utils;

const
  HASHMAP_N     = 100000;
  SORT_N        = 10000;
  STRING_N      = 10000;
  JSON_N        = 1000;

type
  TIntHashMap = specialize THashMap<SizeInt, SizeInt>;

{ ============================================================
  赛道 1: HashMap — 预分配 + 精确测量
  ============================================================ }

var
  GHashMapKeys: array[0..HASHMAP_N-1] of SizeInt;
  GPreallocMap: TIntHashMap;

procedure InitHashMapKeys;
var I: SizeInt;
begin
  for I := 0 to HASHMAP_N - 1 do
    GHashMapKeys[I] := (I * 2654435761) and $7FFFFFFF;
end;

procedure BenchHashMap_Insert(const ACtx: IBenchContext);
var
  LMap: TIntHashMap;
  I: SizeInt;
begin
  LMap := TIntHashMap.Create(HASHMAP_N);
  try
    for I := 0 to HASHMAP_N - 1 do
      LMap.Put(GHashMapKeys[I], I);
  finally
    LMap.Free;
  end;
  ACtx.SetBytes(HASHMAP_N * SizeOf(SizeInt) * 2);
end;

procedure BenchHashMap_Lookup(const ACtx: IBenchContext);
var
  I, LVal: SizeInt;
  LFound: SizeInt;
begin
  LFound := 0;
  for I := 0 to HASHMAP_N - 1 do
    if GPreallocMap.TryGetValue(GHashMapKeys[I], LVal) then
      Inc(LFound);
  ACtx.SetBytes(HASHMAP_N * SizeOf(SizeInt));
end;

procedure BenchHashMap_Iterate(const ACtx: IBenchContext);
var
  LEntry: TIntHashMap.TEntry;
  LCount: SizeInt;
begin
  LCount := 0;
  for LEntry in GPreallocMap do
    Inc(LCount);
  ACtx.SetBytes(HASHMAP_N * SizeOf(SizeInt) * 2);
end;

{ ============================================================
  赛道 2: Sort — IntroSort
  ============================================================ }

var
  GSortData: array[0..SORT_N-1] of Int32;

procedure InitSortData;
var I: SizeInt;
begin
  for I := 0 to SORT_N - 1 do
    GSortData[I] := (I * 48271) mod 1000000;
end;

procedure BenchSort_Int32(const ACtx: IBenchContext);
var
  LArr: array of Int32;
begin
  SetLength(LArr, SORT_N);
  Move(GSortData[0], LArr[0], SORT_N * SizeOf(Int32));
  IntroSortInt32(LArr);
  ACtx.SetBytes(SORT_N * SizeOf(Int32));
end;

{ ============================================================
  赛道 3: String — StringBuilder
  ============================================================ }
procedure BenchString_Builder(const ACtx: IBenchContext);
var
  LBuilder: IStringBuilder;
  I: SizeInt;
begin
  LBuilder := MakeStringBuilder(STRING_N * 16);
  for I := 0 to STRING_N - 1 do
  begin
    LBuilder.AppendStr('item_');
    LBuilder.AppendInt(I);
    LBuilder.AppendChar(',');
  end;
  LBuilder.ToString;
  ACtx.SetBytes(STRING_N * 16);
end;

procedure BenchString_Concat(const ACtx: IBenchContext);
var
  LResult: AnsiString;
  I: SizeInt;
begin
  LResult := '';
  for I := 0 to STRING_N - 1 do
    LResult := LResult + 'item_' + IntToStr(I) + ',';
  ACtx.SetBytes(STRING_N * 16);
end;

{ ============================================================
  赛道 4: JSON — parse
  ============================================================ }

var
  GJsonStr: AnsiString;

procedure InitJsonData;
var I: SizeInt;
begin
  GJsonStr := '{"users":[';
  for I := 0 to JSON_N - 1 do
  begin
    if I > 0 then GJsonStr := GJsonStr + ',';
    GJsonStr := GJsonStr +
      '{"id":' + IntToStr(I) +
      ',"name":"user_' + IntToStr(I) + '"' +
      ',"email":"user' + IntToStr(I) + '@example.com"' +
      ',"age":' + IntToStr(20 + (I mod 50)) + '}';
  end;
  GJsonStr := GJsonStr + ']}';
end;

procedure BenchJSON_Parse(const ACtx: IBenchContext);
var
  LDoc: IJsonDocument;
begin
  LDoc := JsonParse(GJsonStr);
  ACtx.SetBytes(Length(GJsonStr));
end;

{ ============================================================
  Main
  ============================================================ }
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LI: SizeInt;
begin
  WriteLn('=== nextPas Arena Benchmark v2 ===');
  WriteLn('FPC ', {$I %FPCVERSION%}, ' / ', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%});
  WriteLn;

  InitHashMapKeys;
  InitSortData;
  InitJsonData;

  { Pre-allocate and populate map for Lookup/Iterate benchmarks }
  GPreallocMap := TIntHashMap.Create(HASHMAP_N);
  for LI := 0 to HASHMAP_N - 1 do
    GPreallocMap.Put(GHashMapKeys[LI], LI);

  LSuite := TBenchSuite.Create('Arena')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('HashMap/Insert', @BenchHashMap_Insert);
  LSuite.Add('HashMap/Lookup', @BenchHashMap_Lookup);
  LSuite.Add('HashMap/Iterate', @BenchHashMap_Iterate);
  LSuite.Add('Sort/Int32', @BenchSort_Int32);
  LSuite.Add('String/Builder', @BenchString_Builder);
  LSuite.Add('String/Concat', @BenchString_Concat);
  LSuite.Add('JSON/Parse', @BenchJSON_Parse);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchstat);

  WriteLn;
  WriteLn('=== console report ===');
  WriteLn(LResults.PrintToConsole);

  GPreallocMap.Free;
end.
