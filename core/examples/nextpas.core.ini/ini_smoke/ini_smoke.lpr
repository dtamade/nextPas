program ini_smoke;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.ini;

var
  LIni: TIniFile;

begin
  WriteLn('ini-smoke=ready');

  LIni := IniParse(
    '[server]' + #10 +
    'host=localhost' + #10 +
    'port=8080' + #10);
  try
    WriteLn('host=', LIni.ReadString('server', 'host', ''));
    WriteLn('port=', LIni.ReadInteger('server', 'port', 0));
    WriteLn('roundtrip-has-section=', Pos('[server]', LIni.ToString) > 0);
    WriteLn('ini-smoke-status=pass');
  finally
    LIni.Free;
  end;
end.
