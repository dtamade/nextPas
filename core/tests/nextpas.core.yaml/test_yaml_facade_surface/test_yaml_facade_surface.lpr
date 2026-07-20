program test_yaml_facade_surface;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.yaml,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestFacadeExposesCoreSurface;
var
  LDoc: IYamlDocument;
  LValue: TYamlValue;
  LKind: TYamlNodeKind;
  LError: TYamlError;
  LBuilder: TYamlBuilder;
begin
  LDoc := YamlParse('name: Alice' + #10 + 'count: 2');
  Check(not LDoc.HasError, 'parse via facade succeeds');

  LValue := LDoc.Root;
  Check(LValue.IsMap, 'root is map');
  CheckEqual('Alice', LValue.MapGet('name').AsStr.ToString, 'name');
  CheckEqual(Int64(2), LValue.MapGet('count').AsInt, 'count');
  CheckEqual('Alice', LValue.Get('name').AsStr.ToString, 'Get aliases MapGet');
  CheckEqual(Int64(2), LValue.Get('count').AsInt, 'Get aliases MapGet for int');

  LKind := LValue.Kind;
  Check(Ord(LKind) >= 0, 'node kind visible through facade');

  LError := YamlParse('{a: 1, b}').Error;
  Check(LError.Line > 0, 'error type visible through facade');

  LBuilder.Init;
  try
    LBuilder.BeginMap;
    LBuilder.PutKey('name');
    LBuilder.PutStr('demo');
    LBuilder.EndMap;
    CheckEqual('{name: demo}', LBuilder.Stringify,
      'builder visible through facade');
  finally
    LBuilder.Done;
  end;
end;

procedure TestFacadeEdgeDepthAndLargeValue;
var
  LXml: string;
  LDoc: IYamlDocument;
  LValue: TYamlValue;
  LI: Integer;
  LBig: string;
  LError: TYamlError;
begin
  LXml := '';
  for LI := 1 to 40 do
    LXml := LXml + 'l' + IntToStr(LI) + ':' + #10 + '  ';
  LXml := LXml + 'v: 42' + #10;
  LDoc := YamlParse(LXml);
  Check(not LDoc.HasError, 'deep nested map parses');
  LValue := LDoc.Root;
  for LI := 1 to 40 do
    LValue := LValue.MapGet('l' + IntToStr(LI));
  CheckEqual(Int64(42), LValue.MapGet('v').AsInt, 'deep value');

  SetLength(LBig, 4096);
  for LI := 1 to 4096 do
    LBig[LI] := Chr(Ord('a') + (LI mod 26));
  LDoc := YamlParse('blob: "' + LBig + '"' + #10);
  Check(not LDoc.HasError, 'large string value parses');
  CheckEqual(Int64(4096), Int64(Length(LDoc.Root.MapGet('blob').AsStr.ToString)),
    'large string length');

  LDoc := YamlParse('a: 1' + #10 + '---' + #10 + 'b: 2' + #10);
  Check(LDoc.HasError, 'second document marker rejected');
  LError := LDoc.Error;
  Check(LError.Line > 0, 'multi-doc error has line');
end;

function YamlBytesFromString(const AText: string): TBytes;
var
  LI: Integer;
begin
  SetLength(Result, Length(AText));
  for LI := 1 to Length(AText) do
    Result[LI - 1] := Byte(AText[LI]);
end;

procedure TestFacadeExposesReaderParse;
var
  LStream: IStream;
  LDoc: IYamlDocument;
  LRaised: Boolean;
begin
  LStream := CreateBytesStreamFrom(YamlBytesFromString('name: bob' + #10));
  LDoc := YamlParse(LStream as IReader);
  Check(not LDoc.HasError, 'IReader yaml parse');
  CheckEqual('bob', LDoc.Root.MapGet('name').AsStr.ToString, 'IReader value');
  LRaised := False;
  try
    YamlParse(IReader(nil));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'nil IReader raises');
end;

procedure TestFacadeFeatureMatrix;
var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;
  LText: string;
  LMsg: string;
begin
  LDoc := YamlParse('n: null' + #10 + 'b: true' + #10 + 'i: 42' + #10 +
    'f: 1.5' + #10 + 's: hello' + #10 + 'arr:' + #10 + '  - 1' + #10 +
    '  - 2' + #10 + 'obj:' + #10 + '  k: v' + #10);
  Check(not LDoc.HasError, 'matrix parse');
  LRoot := LDoc.Root;
  Check(LRoot.MapGet('n').IsNull or LRoot.MapGet('n').IsStr,
    'null-ish node');
  CheckEqual(True, LRoot.MapGet('b').AsBool, 'bool');
  CheckEqual(Int64(42), LRoot.MapGet('i').AsInt, 'int');
  Check(Abs(LRoot.MapGet('f').AsFloat - 1.5) < 1e-9, 'float');
  CheckEqual('hello', LRoot.MapGet('s').AsStr.ToString, 'str');
  Check(LRoot.MapGet('arr').IsSeq, 'seq');
  CheckEqual(Int64(2), Int64(LRoot.MapGet('arr').SeqLen), 'seq len');
  CheckEqual('v', LRoot.MapGet('obj').MapGet('k').AsStr.ToString, 'nested map');

  LDoc := YamlParse('a: 1' + #10 + '---' + #10 + 'b: 2' + #10);
  Check(LDoc.HasError, 'multi-doc rejected');
  LMsg := LDoc.Error.Message.ToString;
  Check((Pos('multiple', LMsg) > 0) or (Pos('document', LMsg) > 0) or
    (LDoc.Error.Line > 0), 'multi-doc diagnostic');

  LDoc := YamlParse('a: 1' + #10 + '<<: *anchor' + #10);
  Check(LDoc.HasError, 'merge-key rejected or anchor error');

  LDoc := YamlParse('name: round' + #10 + 'n: 3' + #10);
  Check(not LDoc.HasError, 'roundtrip source');
  LText := LDoc.Stringify;
  LDoc := YamlParse(LText);
  Check(not LDoc.HasError, 'stringify reparse');
  CheckEqual('round', LDoc.Root.MapGet('name').AsStr.ToString, 'roundtrip name');
  CheckEqual(Int64(3), LDoc.Root.MapGet('n').AsInt, 'roundtrip n');
end;

begin
  T := TTestSuite.Create('nextpas.core.yaml (facade surface)');
  T.Test('facade exposes core surface', @TestFacadeExposesCoreSurface);
  T.Test('facade edge depth and large value',
    @TestFacadeEdgeDepthAndLargeValue);
  T.Test('facade exposes reader parse', @TestFacadeExposesReaderParse);
  T.Test('facade feature matrix', @TestFacadeFeatureMatrix);
  if not T.Run then Halt(1);
end.
