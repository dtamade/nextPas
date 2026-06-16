program test_toml_facade_surface;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.toml,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestFacadeExposesCoreSurface;
var
  LDoc: ITomlDocument;
  LValue: TTomlValue;
  LError: TTomlError;
  LBuilder: ITomlBuilder;
begin
  LDoc := TomlParse('title = "TOML"' + #10 + 'count = 2');
  Check(not LDoc.HasError, 'parse via facade succeeds');

  LValue := LDoc.Root;
  Check(LValue.IsTable, 'root is table');
  CheckEqual('TOML', LValue.Get('title').AsStr.ToString, 'title');
  CheckEqual(Int64(2), LValue.Get('count').AsInt, 'count');

  LError := TomlParse('= invalid').Error;
  Check(LError.Line > 0, 'error type visible through facade');

  LBuilder := TomlBuilder;
  LBuilder.Key('when');
  LBuilder.DateTime(TomlDateTimeWithOffset(2024, 1, 15, 10, 30, 0, 0, 0));
  Check(Pos('when = ', LBuilder.ToString) = 1,
    'builder and datetime helpers available through facade');
end;

begin
  T := TTestRunner.Create('nextpas.core.toml (facade surface)');
  T.Run('facade exposes core surface', @TestFacadeExposesCoreSurface);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
