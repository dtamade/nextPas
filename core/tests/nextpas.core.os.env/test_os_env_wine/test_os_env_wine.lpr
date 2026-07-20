program test_os_env_wine;

{ L2 os.env Windows evidence under Wine.
  truth=wine-runtime-smoke — NOT real Windows host runtime. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.os.env
  ;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

procedure TestGetEnvPathOrSystemRoot;
var
  L: string;
begin
  L := GetEnv('SystemRoot');
  if L = '' then
    L := GetEnv('PATH');
  Check(L <> '', 'SystemRoot or PATH non-empty');
end;


procedure TestExpandBrace;
begin
  SetEnv('NEXTPAS_WINE_BR', 'brace');
  try
    CheckEqual('x-brace-y', ExpandEnv('x-${NEXTPAS_WINE_BR}-y'), 'brace expand');
  finally
    UnsetEnv('NEXTPAS_WINE_BR');
  end;
end;

procedure TestSetUnsetExpand;
var
  LName: string;
begin
  LName := 'NEXTPAS_WINE_EV';
  SetEnv(LName, 'wine_ok');
  try
    CheckEqual('wine_ok', GetEnv(LName), 'GetEnv after Set');
    CheckEqual('pre-wine_ok', ExpandEnv('pre-%' + LName + '%'), 'Expand %VAR%');
  finally
    UnsetEnv(LName);
  end;
  Check(not HasEnv(LName), 'HasEnv false after Unset');
end;

{$ELSE}

procedure TestSkipHost;
begin
  Check(True, 'host is not Windows; wine suite is cross-target only');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('os.env L2 wine-runtime-smoke');
{$IFDEF NEXTPAS_WINDOWS}
  T.Test('getenv path/systemroot', @TestGetEnvPathOrSystemRoot);
  T.Test('set unset expand', @TestSetUnsetExpand);
  T.Test('expand brace', @TestExpandBrace);
{$ELSE}
  T.Test('skip non-windows host', @TestSkipHost);
{$ENDIF}
  if not T.Run then
    Halt(1);
end.
