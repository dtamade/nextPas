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
  {$ifdef unix}nextpas.core.thread.init,{$endif}
  nextpas.core.collections.hashmap,
  nextpas.core.text.builder,
  nextpas.core.json,
  nextpas.core.toml,
  nextpas.core.regex,
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
  TOML_N        = 500;
  REGEX_N       = 1000;

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
  赛道 5: TOML — parse
  ============================================================ }

var
  GTomlStr: AnsiString;

procedure InitTomlData;
var
  LBuilder: IStringBuilder;
  I: SizeInt;
begin
  LBuilder := MakeStringBuilder(TOML_N * 200);
  LBuilder.AppendStr('[server]' + LineEnding);
  LBuilder.AppendStr('host = "0.0.0.0"' + LineEnding);
  LBuilder.AppendStr('port = 8080' + LineEnding);
  LBuilder.AppendStr('workers = 16' + LineEnding);
  LBuilder.AppendStr('max_connections = 10000' + LineEnding);
  LBuilder.AppendStr(LineEnding);
  LBuilder.AppendStr('[database]' + LineEnding);
  LBuilder.AppendStr('driver = "postgresql"' + LineEnding);
  LBuilder.AppendStr('host = "db.example.com"' + LineEnding);
  LBuilder.AppendStr('port = 5432' + LineEnding);
  LBuilder.AppendStr('pool_size = 20' + LineEnding);
  LBuilder.AppendStr(LineEnding);

  for I := 0 to TOML_N - 1 do
  begin
    LBuilder.AppendStr('[[services]]' + LineEnding);
    LBuilder.AppendStr('name = "service_'); LBuilder.AppendInt(I);
    LBuilder.AppendStr('"' + LineEnding);
    LBuilder.AppendStr('enabled = ');
    if (I and 1) = 0 then LBuilder.AppendStr('true') else LBuilder.AppendStr('false');
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('weight = '); LBuilder.AppendInt(I mod 100);
    LBuilder.AppendStr(LineEnding);
    LBuilder.AppendStr('timeout = '); LBuilder.AppendInt(1000 + I * 10);
    LBuilder.AppendStr('.5' + LineEnding);
    LBuilder.AppendStr('endpoint = "https://api.example.com/v1/service_');
    LBuilder.AppendInt(I); LBuilder.AppendStr('"' + LineEnding);
    LBuilder.AppendStr('tags = ["production", "region_');
    LBuilder.AppendInt(I mod 5); LBuilder.AppendStr('", "tier_');
    LBuilder.AppendStr('backend'); LBuilder.AppendStr('"]' + LineEnding);
    LBuilder.AppendStr(LineEnding);
  end;

  GTomlStr := LBuilder.ToString;
end;

procedure BenchTOML_Parse(const ACtx: IBenchContext);
var
  LDoc: ITomlDocument;
begin
  LDoc := TomlParse(GTomlStr);
  ACtx.SetBytes(Length(GTomlStr));
end;

{ ============================================================
  赛道 6: Regex — match + findall
  ============================================================ }

var
  GRegexLogLines: array of AnsiString;
  GRegexPattern: AnsiString;
  GRegexSimplePattern: AnsiString;
  GRegexFindAllPattern: AnsiString;

procedure InitRegexData;
var
  I: SizeInt;
begin
  GRegexPattern := '(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}\.\d{3}) \[(\w+)\] (.+)';
  GRegexSimplePattern := '\d+';
  GRegexFindAllPattern := '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3} \[\w+\] .+';
  SetLength(GRegexLogLines, REGEX_N);
  for I := 0 to REGEX_N - 1 do
    GRegexLogLines[I] := '2026-06-29 14:3' + AnsiString(IntToStr(I mod 10)) +
      ':2' + AnsiString(IntToStr(I mod 6)) + '.' +
      AnsiString(IntToStr(100 + (I * 37) mod 900)) +
      ' [info] Request #' + IntToStr(I) + ' completed in ' +
      IntToStr(I mod 500) + 'ms';
end;

procedure BenchRegex_Match(const ACtx: IBenchContext);
var
  LRe: TRegex;
  I, LMatched: SizeInt;
begin
  LRe := TRegex.Compile(GRegexPattern);
  LMatched := 0;
  for I := 0 to REGEX_N - 1 do
    if LRe.IsMatch(GRegexLogLines[I]) then
      Inc(LMatched);
  ACtx.SetBytes(REGEX_N * 80);
end;

procedure BenchRegex_SimpleMatch(const ACtx: IBenchContext);
var
  LRe: TRegex;
  I, LMatched: SizeInt;
begin
  LRe := TRegex.Compile(GRegexSimplePattern);
  LMatched := 0;
  for I := 0 to REGEX_N - 1 do
    if LRe.IsMatch(GRegexLogLines[I]) then
      Inc(LMatched);
  ACtx.SetBytes(REGEX_N * 80);
end;

procedure BenchRegex_FindAll(const ACtx: IBenchContext);
var
  LRe: TRegex;
  I, LTotal: SizeInt;
  LMatches: TMatchArray;
begin
  LRe := TRegex.Compile(GRegexFindAllPattern);
  LTotal := 0;
  for I := 0 to REGEX_N - 1 do
  begin
    LMatches := LRe.FindAll(GRegexLogLines[I]);
    Inc(LTotal, Length(LMatches));
  end;
  ACtx.SetBytes(REGEX_N * 80);
end;

procedure BenchRegex_FindAllCapture(const ACtx: IBenchContext);
var
  LRe: TRegex;
  I, LTotal: SizeInt;
  LMatches: TMatchArray;
begin
  LRe := TRegex.Compile(GRegexPattern);
  LTotal := 0;
  for I := 0 to REGEX_N - 1 do
  begin
    LMatches := LRe.FindAll(GRegexLogLines[I]);
    Inc(LTotal, Length(LMatches));
  end;
  ACtx.SetBytes(REGEX_N * 80);
end;

{ ============================================================
  Main
  ============================================================ }
var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LI: SizeInt;
  LFilter: string;
begin
  WriteLn('=== nextPas Arena Benchmark v2 ===');
  WriteLn('FPC ', {$I %FPCVERSION%}, ' / ', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%});
  WriteLn;

  InitHashMapKeys;
  InitSortData;
  InitJsonData;
  InitTomlData;
  InitRegexData;

  { Pre-allocate and populate map for Lookup/Iterate benchmarks }
  GPreallocMap := TIntHashMap.Create(HASHMAP_N);
  for LI := 0 to HASHMAP_N - 1 do
    GPreallocMap.Put(GHashMapKeys[LI], LI);

  LSuite := TBenchSuite.Create('Arena')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  { Apply filter from command line }
  if ParamCount > 0 then
  begin
    LFilter := ParamStr(1);
    LSuite.SetFilter(LFilter);
  end;

  LSuite.Add('HashMap/Insert', @BenchHashMap_Insert);
  LSuite.Add('HashMap/Lookup', @BenchHashMap_Lookup);
  LSuite.Add('HashMap/Iterate', @BenchHashMap_Iterate);
  LSuite.Add('Sort/Int32', @BenchSort_Int32);
  LSuite.Add('String/Builder', @BenchString_Builder);
  LSuite.Add('String/Concat', @BenchString_Concat);
  LSuite.Add('JSON/Parse', @BenchJSON_Parse);
  LSuite.Add('TOML/Parse', @BenchTOML_Parse);
  LSuite.Add('Regex/Match', @BenchRegex_Match);
  LSuite.Add('Regex/SimpleMatch', @BenchRegex_SimpleMatch);
  LSuite.Add('Regex/FindAll', @BenchRegex_FindAll);
  LSuite.Add('Regex/FindAllCapture', @BenchRegex_FindAllCapture);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchstat);

  WriteLn;
  WriteLn('=== console report ===');
  WriteLn(LResults.PrintToConsole);

  GPreallocMap.Free;
end.
