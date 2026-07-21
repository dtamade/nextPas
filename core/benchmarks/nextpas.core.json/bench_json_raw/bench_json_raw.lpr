program bench_json_raw;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.platform.time, nextpas.core.text.view, nextpas.core.text.builder,
  nextpas.core.text.conv,
  nextpas.core.mem.intf, nextpas.core.mem.default,
  nextpas.core.json.types, nextpas.core.json.parser, nextpas.core.json.writer;
const
  SMALL_JSON = '{"name":"Alice","age":30,"active":true,"score":3.14}';
  MEDIUM_JSON = '{"users":[{"id":1,"name":"Alice","email":"alice@example.com","age":30},{"id":2,"name":"Bob","email":"bob@example.com","age":25},{"id":3,"name":"Charlie","email":"charlie@example.com","age":35}],"total":3,"page":1,"hasMore":false}';
var LARGE_JSON: string; GSink: UInt64;
procedure BuildLargeJson;
var B: TStringBuilder; W: TJsonWriter; I: Int32;
begin
  B.Init(8192); W.Init(B); W.BeginObject; W.Key('items'); W.BeginArray;
  for I := 0 to 99 do begin W.BeginObject; W.Key('id'); W.Int(I); W.Key('name'); W.Str('item_' + IntToStr(I)); W.Key('value'); W.Float(I * 1.5); W.Key('active'); W.Bool(I mod 2 = 0); W.EndObject; end;
  W.EndArray; W.Key('count'); W.Int(100); W.EndObject;
  LARGE_JSON := B.ToString; B.Done;
end;
procedure BenchParseSmall(const ACtx: IBenchContext);
var Doc: TJsonDocument; LView: TStringView;
begin
  LView := TStringView.FromStr(SMALL_JSON); Doc.Init(DefaultAllocator); Doc.Parse(LView); Doc.Done;
  GSink := GSink xor UInt64(Length(SMALL_JSON));
end;
procedure BenchParseMedium(const ACtx: IBenchContext);
var Doc: TJsonDocument; LView: TStringView;
begin
  LView := TStringView.FromStr(MEDIUM_JSON); Doc.Init(DefaultAllocator); Doc.Parse(LView); Doc.Done;
  GSink := GSink xor UInt64(Length(MEDIUM_JSON));
end;
procedure BenchParseLarge(const ACtx: IBenchContext);
var Doc: TJsonDocument; LView: TStringView;
begin
  LView := TStringView.FromStr(LARGE_JSON); Doc.Init(DefaultAllocator); Doc.Parse(LView); Doc.Done;
  GSink := GSink xor UInt64(Length(LARGE_JSON));
end;
var LSuite: IBenchSuite;
begin
  BuildLargeJson; GSink := 0;
  LSuite := TBenchSuite.Create('json-raw');
  LSuite.Add('Parse/small', @BenchParseSmall).Add('Parse/medium', @BenchParseMedium).Add('Parse/large', @BenchParseLarge);
  WriteLn(LSuite.Run.PrintToConsole);
end.
