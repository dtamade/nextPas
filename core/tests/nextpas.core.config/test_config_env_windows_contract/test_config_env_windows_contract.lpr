program test_config_env_windows_contract;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.config.env,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestTryConfigEnvNameToKeyMatchesPrefixCaseInsensitivelyOnWindows;
var
  LKey: string;
begin
  LKey := '';
  CheckEqual(True,
    TryConfigEnvNameToKey('app_HOST', 'APP_', LKey),
    'mixed-case env prefix matches on windows');
  CheckEqual('host', LKey, 'suffix lowercases after windows prefix match');
end;

procedure TestTryConfigEnvNameToKeyStillRejectsMissingSuffixOnWindows;
var
  LKey: string;
begin
  LKey := 'stale';
  CheckEqual(False,
    TryConfigEnvNameToKey('app_', 'APP_', LKey),
    'prefix-only env name still rejected on windows');
  CheckEqual('', LKey, 'missing suffix clears key');
end;

begin
  T := TTestSuite.Create('nextpas.core.config.env.windows_contract');
  T.Test('EnvNameToKey.MatchesPrefixCaseInsensitivelyOnWindows',
    @TestTryConfigEnvNameToKeyMatchesPrefixCaseInsensitivelyOnWindows);
  T.Test('EnvNameToKey.RejectsMissingSuffixOnWindows',
    @TestTryConfigEnvNameToKeyStillRejectsMissingSuffixOnWindows);
  if not T.Run then Halt(1);
end.
