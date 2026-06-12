program test_yaml_facade_surface;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.yaml,
  nextpas.core.testing;

var
  T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.yaml (facade surface)');
  T.Run('facade exposes core surface', @TestFacadeExposesCoreSurface);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
