program bench_json;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.text.view,
  nextpas.core.text.conv,
  nextpas.core.json, nextpas.core.json.value,
  nextpas.core.fs;
const
  SMALL_JSON = '{"name":"test","value":42,"items":[1,2,3,4,5]}';
var
  GLargeJson: string;
  GSmallDoc: IJsonDocument;
  GLargeDoc: IJsonDocument;
  GCounter: UInt64;
function BuildLargeJson: string;
var
  LBuf: string;
  LI, LCap, LLen: Integer;
  LPiece: string;
begin
  LCap := 0;
  LLen := 0;
  LBuf := '';
  for LI := 1 to 1000 do
  begin
    LPiece := '{"key":"item' + IntToStr(LI) + '","val":' + IntToStr(LI) + '},';
    if LLen + Length(LPiece) > LCap then
    begin
      if LCap = 0 then
        LCap := 8192
      else
        LCap := LCap * 2;
      while LCap < LLen + Length(LPiece) do
        LCap := LCap * 2;
      SetLength(LBuf, LCap);
    end;
    Move(LPiece[1], LBuf[LLen + 1], Length(LPiece));
    Inc(LLen, Length(LPiece));
  end;
  SetLength(LBuf, LLen);
  { drop trailing comma if present }
  if (LLen > 0) and (LBuf[LLen] = ',') then
    SetLength(LBuf, LLen - 1);
  Result := '{"items":[' + LBuf + ']}';
end;
procedure BenchParseSmall(const ACtx: IBenchContext);
var
  LDoc: IJsonDocument;
  LName: TStringView;
begin
  LDoc := JsonParse(SMALL_JSON);
  LName := LDoc.Root.ObjectGet('name').AsStr;
  GCounter := GCounter xor UInt64(LName.Len);
end;
procedure BenchParseLarge(const ACtx: IBenchContext);
var
  LDoc: IJsonDocument;
begin
  LDoc := JsonParse(GLargeJson);
  GCounter := GCounter xor UInt64(LDoc.Root.ObjectGet('items').ArrayLen);
end;
procedure BenchStringifySmall(const ACtx: IBenchContext);
var
  LStr: string;
begin
  LStr := GSmallDoc.Stringify;
  GCounter := GCounter xor UInt64(Length(LStr));
end;
procedure BenchStringifyLarge(const ACtx: IBenchContext);
var
  LStr: string;
begin
  LStr := GLargeDoc.Stringify;
  GCounter := GCounter xor UInt64(Length(LStr));
end;
procedure BenchAccessSmall(const ACtx: IBenchContext);
var
  LVal: Int64;
  LLen: UInt32;
begin
  LVal := GSmallDoc.Root.ObjectGet('value').AsInt;
  LLen := GSmallDoc.Root.ObjectGet('items').ArrayLen;
  GCounter := GCounter xor UInt64(LVal) xor UInt64(LLen);
end;
procedure BenchAccessLarge(const ACtx: IBenchContext);
var
  LItems: TJsonValue;
  LCount, LI: UInt32;
  LVal: Int64;
begin
  LItems := GLargeDoc.Root.ObjectGet('items');
  LCount := LItems.ArrayLen;
  for LI := 0 to LCount - 1 do
  begin
    LVal := LItems.ArrayGet(LI).ObjectGet('val').AsInt;
    GCounter := GCounter xor UInt64(LVal);
  end;
end;
var
  LResults: IBenchResults;
begin
  GLargeJson := BuildLargeJson;
  GSmallDoc := JsonParse(SMALL_JSON);
  GLargeDoc := JsonParse(GLargeJson);
  GCounter := 0;
  LResults := TBenchSuite.Create('json')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('Parse/small', @BenchParseSmall).Add('Parse/large', @BenchParseLarge)
    .Add('Stringify/small', @BenchStringifySmall).Add('Stringify/large', @BenchStringifyLarge)
    .Add('Access/small', @BenchAccessSmall).Add('Access/large', @BenchAccessLarge)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-json.json');
end.
