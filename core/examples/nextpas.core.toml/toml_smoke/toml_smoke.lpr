program toml_smoke;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.toml;

var
  LDoc: ITomlDocument;
  LRoot: TTomlValue;

begin
  WriteLn('toml-smoke=ready');

  LDoc := TomlParse(
    '[server]' + #10 +
    'host = "localhost"' + #10 +
    'port = 8080' + #10);
  if LDoc.HasError then
  begin
    WriteLn('toml-smoke-status=fail');
    WriteLn('error=', LDoc.Error.Message.ToString);
    Halt(1);
  end;

  LRoot := LDoc.Root;
  WriteLn('host=', LRoot.Get('server').Get('host').AsStr.ToString);
  WriteLn('port=', LRoot.Get('server').Get('port').AsInt);
  WriteLn('compact=', LDoc.Stringify);
  WriteLn('toml-smoke-status=pass');
end.
