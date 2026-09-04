{**
 * bench_arena.pas — nextPas vs Go vs Rust 综合竞技场
 *
 * 四个赛道：HashMap / Sort / String / JSON
 * 输出 benchstat 兼容格式
 *}
program bench_arena;
{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  {$ifdef unix}nextpas.core.thread.init,{$endif}
  nextpas.core.collections.hashmap,
  nextpas.core.text.builder,
  nextpas.core.json,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  np_sort_utils,
  nextpas.core.text.conv;


const
  HASHMAP_N     = 100000;
  SORT_N        = 10000;
  STRING_N      = 10000;
  JSON_N        = 1000;

type
  TIntHashMap = specialize THashMap<SizeInt, SizeInt>;

{ ============================================================
  赛道 1: HashMap — insert + lookup + iterate
  ============================================================ }
procedure BenchHashMap_Insert(const ACtx: IBenchContext);
var
  LMap: TIntHashMap;
  I: SizeInt;
begin
  LMap := TIntHashMap.Create;
  try
    for I := 0 to HASHMAP_N - 1 do
      LMap.Put((I * 2654435761) and $7FFFFFFF, I);
  finally
    LMap.Free;
  end;
  ACtx.SetBytes(HASHMAP_N * SizeOf(SizeInt) * 2);
end;

procedure BenchHashMap_Lookup(const ACtx: IBenchContext);
var
  LMap: TIntHashMap;
  I, LVal: SizeInt;
  LFound: SizeInt;
begin
  LMap := TIntHashMap.Create;
  try
    for I := 0 to HASHMAP_N - 1 do
      LMap.Put((I * 2654435761) and $7FFFFFFF, I);

    LFound := 0;
    for I := 0 to HASHMAP_N - 1 do
      if LMap.TryGetValue((I * 2654435761) and $7FFFFFFF, LVal) then
        Inc(LFound);
  finally
    LMap.Free;
  end;
  ACtx.SetBytes(HASHMAP_N * SizeOf(SizeInt));
end;

procedure BenchHashMap_Iterate(const ACtx: IBenchContext);
var
  LMap: TIntHashMap;
  I: SizeInt;
  LEntry: TIntHashMap.TEntry;
  LCount: SizeInt;
begin
  LMap := TIntHashMap.Create;
  try
    for I := 0 to HASHMAP_N - 1 do
      LMap.Put((I * 2654435761) and $7FFFFFFF, I);

    LCount := 0;
    for LEntry in LMap do
      Inc(LCount);
  finally
    LMap.Free;
  end;
  ACtx.SetBytes(HASHMAP_N * SizeOf(SizeInt) * 2);
end;

{ ============================================================
  赛道 2: Sort — Int32 排序
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
  LAll: TBenchResultArray;
  I: Integer;
begin
  WriteLn('=== nextPas Arena Benchmark ===');
  WriteLn('FPC ', {$I %FPCVERSION%}, ' / ', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%});
  WriteLn;

  InitSortData;
  InitJsonData;

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
end.
