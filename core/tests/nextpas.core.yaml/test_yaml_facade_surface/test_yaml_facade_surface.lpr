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

begin
  T := TTestSuite.Create('nextpas.core.yaml (facade surface)');
  T.Test('facade exposes core surface', @TestFacadeExposesCoreSurface);
  T.Test('facade edge depth and large value',
    @TestFacadeEdgeDepthAndLargeValue);
  T.Test('facade exposes reader parse', @TestFacadeExposesReaderParse);
  if not T.Run then Halt(1);
end.
