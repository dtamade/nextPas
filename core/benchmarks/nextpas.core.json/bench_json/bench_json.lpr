program bench_json;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  fpjson, jsonparser,
  nextpas.core.time.base,
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.json,
  nextpas.core.json.types,
  nextpas.core.json.parser,
  nextpas.core.json.value,
  nextpas.core.json.writer;

const
  SMALL_JSON = '{"name":"Alice","age":30,"active":true,"score":3.14}';
  MEDIUM_JSON = '{"users":[{"id":1,"name":"Alice","email":"alice@example.com","age":30},' +
    '{"id":2,"name":"Bob","email":"bob@example.com","age":25},' +
    '{"id":3,"name":"Charlie","email":"charlie@example.com","age":35}],' +
    '"total":3,"page":1,"hasMore":false}';

var
  LARGE_JSON: string;

procedure BuildLargeJson;
var
  B: TStringBuilder;
  W: TJsonWriter;
  I: Int32;
begin
  B.Init(8192);
  W.Init(B);
  W.BeginObject;
    W.Key('items'); W.BeginArray;
    for I := 0 to 99 do
    begin
      W.BeginObject;
        W.Key('id'); W.Int(I);
        W.Key('name'); W.Str('item_' + IntToStr(I));
        W.Key('value'); W.Float(I * 1.5);
        W.Key('active'); W.Bool(I mod 2 = 0);
      W.EndObject;
    end;
    W.EndArray;
    W.Key('count'); W.Int(100);
  W.EndObject;
  LARGE_JSON := B.ToString;
  B.Done;
end;

procedure BenchOp(const AName: string; const AOps: Int64; const AElapsed: TDuration);
var
  LNs: Int64;
  LNsPerOp: Double;
begin
  LNs := AElapsed.AsNanoseconds;
  if LNs > 0 then
    LNsPerOp := LNs / AOps
  else
    LNsPerOp := 0;
  WriteLn(Format('  %-45s %8.0f ns/op', [AName, LNsPerOp]));
end;

procedure BenchParseSmall;
const N = 50000;
var
  LStart: TInstant;
  I: Int32;
  Doc: IJsonDocument;
  FpcDoc: TJSONData;
begin
  LStart := TInstant.Now;
  for I := 1 to N do
    Doc := JsonParse(SMALL_JSON);
  BenchOp('nextpas JsonParse (small, 52B)', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
  begin
    FpcDoc := GetJSON(SMALL_JSON);
    FpcDoc.Free;
  end;
  BenchOp('FPC fpjson GetJSON (small, 52B)', N, LStart.Elapsed);
end;

procedure BenchParseMedium;
const N = 20000;
var
  LStart: TInstant;
  I: Int32;
  Doc: IJsonDocument;
  FpcDoc: TJSONData;
begin
  LStart := TInstant.Now;
  for I := 1 to N do
    Doc := JsonParse(MEDIUM_JSON);
  BenchOp('nextpas JsonParse (medium, 250B)', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
  begin
    FpcDoc := GetJSON(MEDIUM_JSON);
    FpcDoc.Free;
  end;
  BenchOp('FPC fpjson GetJSON (medium, 250B)', N, LStart.Elapsed);
end;

procedure BenchParseLarge;
const N = 5000;
var
  LStart: TInstant;
  I: Int32;
  Doc: IJsonDocument;
  FpcDoc: TJSONData;
begin
  LStart := TInstant.Now;
  for I := 1 to N do
    Doc := JsonParse(LARGE_JSON);
  BenchOp('nextpas JsonParse (large, ' + IntToStr(Length(LARGE_JSON)) + 'B)', N, LStart.Elapsed);

  LStart := TInstant.Now;
  for I := 1 to N do
  begin
    FpcDoc := GetJSON(LARGE_JSON);
    FpcDoc.Free;
  end;
  BenchOp('FPC fpjson GetJSON (large, ' + IntToStr(Length(LARGE_JSON)) + 'B)', N, LStart.Elapsed);
end;

procedure BenchStringify;
const N = 20000;
var
  LStart: TInstant;
  I: Int32;
  Doc: IJsonDocument;
  FpcDoc: TJSONData;
  S: string;
begin
  Doc := JsonParse(MEDIUM_JSON);
  LStart := TInstant.Now;
  for I := 1 to N do
    S := Doc.Stringify;
  BenchOp('nextpas Stringify (medium)', N, LStart.Elapsed);

  FpcDoc := GetJSON(MEDIUM_JSON);
  LStart := TInstant.Now;
  for I := 1 to N do
    S := FpcDoc.AsJSON;
  BenchOp('FPC fpjson AsJSON (medium)', N, LStart.Elapsed);
  FpcDoc.Free;
end;

procedure BenchAccess;
const N = 100000;
var
  LStart: TInstant;
  I: Int32;
  Doc: IJsonDocument;
  FpcDoc: TJSONData;
  LDummy: Int64;
begin
  Doc := JsonParse(MEDIUM_JSON);
  LStart := TInstant.Now;
  for I := 1 to N do
    LDummy := Doc.Root.ObjectGet('total').AsInt;
  BenchOp('nextpas ObjectGet+AsInt', N, LStart.Elapsed);

  FpcDoc := GetJSON(MEDIUM_JSON);
  LStart := TInstant.Now;
  for I := 1 to N do
    LDummy := (FpcDoc as TJSONObject).Get('total', Int64(0));
  BenchOp('FPC fpjson Get(key)', N, LStart.Elapsed);
  FpcDoc.Free;
end;

begin
  BuildLargeJson;

  WriteLn('=== nextpas.core.json benchmarks ===');
  WriteLn;

  WriteLn('--- Parse ---');
  BenchParseSmall;
  BenchParseMedium;
  BenchParseLarge;
  WriteLn;

  WriteLn('--- Stringify ---');
  BenchStringify;
  WriteLn;

  WriteLn('--- Access ---');
  BenchAccess;
  WriteLn;

  WriteLn('--- Reference (literature) ---');
  WriteLn('  yyjson parse (C):                    ~100-200 ns/KB');
  WriteLn('  Go encoding/json Unmarshal:          ~2000-5000 ns/KB');
  WriteLn('  simdjson (C++):                      ~50-100 ns/KB');
  WriteLn;

  WriteLn('Done.');
end.
