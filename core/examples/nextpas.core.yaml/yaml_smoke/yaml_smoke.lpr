program yaml_smoke;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.yaml;

var
  LDoc: IYamlDocument;
  LRoot: TYamlValue;

begin
  WriteLn('yaml-smoke=ready');

  LDoc := YamlParse(
    'server:' + #10 +
    '  host: localhost' + #10 +
    '  port: 8080' + #10);
  if LDoc.HasError then
  begin
    WriteLn('yaml-smoke-status=fail');
    WriteLn('error=', LDoc.Error.Message.ToString);
    Halt(1);
  end;

  LRoot := LDoc.Root;
  { Get is an alias for MapGet (TOML-style DX). }
  WriteLn('host=', LRoot.Get('server').Get('host').AsStr.ToString);
  WriteLn('port=', LRoot.Get('server').Get('port').AsInt);
  WriteLn('compact=', LDoc.Stringify);
  WriteLn('yaml-smoke-status=pass');
end.
