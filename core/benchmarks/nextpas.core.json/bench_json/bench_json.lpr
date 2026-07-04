program bench_json;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.json, nextpas.core.json.parser, nextpas.core.json.serializer;
const
  SMALL_JSON = '{"name":"test","value":42,"items":[1,2,3,4,5]}';
var
  GLargeJson: string;
  GSmallDoc: IJsonDocument;
  GLargeDoc: IJsonDocument;
  GCounter: UInt64;
function BuildLargeJson: string;
var LBuf: string; LI, LCap, LLen: Integer;
begin
  LCap := 0; LLen := 0; LBuf := '';
  for LI := 1 to 1000 do begin
    if LLen + 60 > LCap then begin if LCap = 0 then LCap := 8192 else LCap := LCap * 2; SetLength(LBuf, LCap); end;
    LLen := LLen + FormatBuf(LBuf[LLen + 1], '{"key":"item' + IntToStr(LI) + '","val":' + IntToStr(LI) + '},', []);
  end;
  SetLength(LBuf, LLen);
  Result := '{"items":[' + LBuf + ']}';
end;
procedure BenchParseSmall(const ACtx: IBenchContext);
var LDoc: IJsonDocument; LName: string;
begin
  LDoc := TJsonParser.Parse(SMALL_JSON);
  LName := LDoc.Root.AsObject.GetString('name');
  GCounter := GCounter xor UInt64(Length(LName));
end;
procedure BenchParseLarge(const ACtx: IBenchContext);
var LDoc: IJsonDocument;
begin
  LDoc := TJsonParser.Parse(GLargeJson);
  GCounter := GCounter xor UInt64(LDoc.Root.AsObject.Count);
end;
procedure BenchStringifySmall(const ACtx: IBenchContext);
var LStr: string;
begin LStr := GSmallDoc.Stringify; GCounter := GCounter xor UInt64(Length(LStr)); end;
procedure BenchStringifyLarge(const ACtx: IBenchContext);
var LStr: string;
begin LStr := GLargeDoc.Stringify; GCounter := GCounter xor UInt64(Length(LStr)); end;
procedure BenchAccessSmall(const ACtx: IBenchContext);
var LVal: Integer; LLen: Integer;
begin
  LVal := GSmallDoc.Root.AsObject.GetInteger('value');
  LLen := Length(GSmallDoc.Root.AsObject.GetArray('items'));
  GCounter := GCounter xor UInt64(LVal) xor UInt64(LLen);
end;
procedure BenchAccessLarge(const ACtx: IBenchContext);
var LObj: IJsonObject; LCount, LI, LVal: Integer;
begin
  LObj := GLargeDoc.Root.AsObject; LCount := LObj.Count;
  for LI := 0 to LCount - 1 do begin
    LVal := LObj.GetPair(LI).Value.AsInteger;
    GCounter := GCounter xor UInt64(LVal);
  end;
end;
var LSuite: IBenchSuite;
begin
  GLargeJson := BuildLargeJson;
  GSmallDoc := TJsonParser.Parse(SMALL_JSON);
  GLargeDoc := TJsonParser.Parse(GLargeJson);
  GCounter := 0;
  LSuite := TBenchSuite.Create('json');
  LSuite.Add('Parse/small', @BenchParseSmall).Add('Parse/large', @BenchParseLarge)
    .Add('Stringify/small', @BenchStringifySmall).Add('Stringify/large', @BenchStringifyLarge)
    .Add('Access/small', @BenchAccessSmall).Add('Access/large', @BenchAccessLarge);
  WriteLn(LSuite.Run.PrintToConsole);
end.
