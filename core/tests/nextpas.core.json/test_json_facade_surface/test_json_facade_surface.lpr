program test_json_facade_surface;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.json,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestFacadeExposesCoreSurface;
var
  LDoc: IJsonDocument;
  LValue: TJsonValue;
  LError: TJsonError;
begin
  LDoc := JsonParse('{"name":"Alice","age":30}');
  Check(not LDoc.HasError, 'parse via facade succeeds');

  LValue := LDoc.Root;
  Check(LValue.IsObject, 'root is object');
  CheckEqual('Alice', LValue.ObjectGet('name').AsStr.ToString, 'name');
  CheckEqual(Int64(30), LValue.ObjectGet('age').AsInt, 'age');

  LError := JsonParse('{bad}').Error;
  Check(LError.Line > 0, 'error type visible through facade');

  CheckEqual('42', JsonStringify(JsonParse('42').Root),
    'JsonStringify available through facade');
end;

begin
  T := TTestRunner.Create('nextpas.core.json (facade surface)');
  T.Run('facade exposes core surface', @TestFacadeExposesCoreSurface);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
