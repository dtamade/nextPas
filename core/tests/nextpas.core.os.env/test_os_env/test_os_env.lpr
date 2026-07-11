program test_os_env;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.text.base,
  nextpas.core.os.env;

var
  T: TTestSuite;

{ --- existing tests --- }

procedure Test_GetEnv_HOME;
var V: string;
begin
  V := GetEnv('HOME');
  Check(V <> '', 'HOME should not be empty');
  Check(V[1] = '/', 'HOME should start with /');
end;

procedure Test_GetEnv_Missing;
var V: string;
begin
  V := GetEnv('NEXTPAS_TEST_NONEXISTENT_VAR_XYZ');
  CheckEqual('', V, 'missing var returns empty string');
end;

procedure Test_GetEnvironmentVariable_Compat;
var V: string;
begin
  V := GetEnvironmentVariable('PATH');
  Check(V <> '', 'PATH should not be empty');
  Check(V[1] = '/', 'PATH should start with /');
end;

procedure Test_HasEnv_Exists;
begin
  Check(HasEnv('HOME'), 'HOME should exist');
  Check(HasEnv('PATH'), 'PATH should exist');
end;

procedure Test_HasEnv_Missing;
begin
  Check(not HasEnv('NEXTPAS_TEST_NONEXISTENT_VAR_XYZ'),
    'non-existent var should return false');
end;

procedure Test_SetEnv_And_Get;
begin
  SetEnv('NEXTPAS_TEST_SETENV', 'test_value');
  CheckEqual('test_value', GetEnv('NEXTPAS_TEST_SETENV'),
    'SetEnv stores and GetEnv retrieves');
  UnsetEnv('NEXTPAS_TEST_SETENV');
end;

procedure Test_SetEnv_Overwrite;
begin
  SetEnv('NEXTPAS_TEST_OVERWRITE', 'v1');
  CheckEqual('v1', GetEnv('NEXTPAS_TEST_OVERWRITE'));
  SetEnv('NEXTPAS_TEST_OVERWRITE', 'v2');
  CheckEqual('v2', GetEnv('NEXTPAS_TEST_OVERWRITE'));
  UnsetEnv('NEXTPAS_TEST_OVERWRITE');
end;

procedure Test_SetEnv_Empty_Value;
begin
  SetEnv('NEXTPAS_TEST_EMPTY', '');
  Check(HasEnv('NEXTPAS_TEST_EMPTY'), 'empty value var should exist');
  CheckEqual('', GetEnv('NEXTPAS_TEST_EMPTY'), 'empty value returns empty');
  UnsetEnv('NEXTPAS_TEST_EMPTY');
end;

procedure Test_UnsetEnv;
begin
  SetEnv('NEXTPAS_TEST_UNSET', 'to_remove');
  Check(HasEnv('NEXTPAS_TEST_UNSET'), 'var should exist before unset');
  UnsetEnv('NEXTPAS_TEST_UNSET');
  Check(not HasEnv('NEXTPAS_TEST_UNSET'), 'var should not exist after unset');
  CheckEqual('', GetEnv('NEXTPAS_TEST_UNSET'), 'unset var returns empty');
end;

procedure Test_UnsetEnv_NonExistent;
begin
  UnsetEnv('NEXTPAS_TEST_NEVER_SET_XYZ');
  Check(not HasEnv('NEXTPAS_TEST_NEVER_SET_XYZ'), 'unset nonexistent is safe');
end;

{ --- ExpandEnv tests --- }

procedure Test_ExpandEnv_Basic;
begin
  SetEnv('NEXTPAS_TEST_EXPAND', 'hello');
  CheckEqual('hello', ExpandEnv('${NEXTPAS_TEST_EXPAND}'),
    'ExpandEnv expands ${VAR}');
  UnsetEnv('NEXTPAS_TEST_EXPAND');
end;

procedure Test_ExpandEnv_NotFound;
begin
  { Unset the variable so it definitely does not exist }
  UnsetEnv('NEXTPAS_TEST_MISSING_XYZ');
  { Missing var expands to empty string: prefix + empty + suffix }
  CheckEqual('prefix::suffix', ExpandEnv('prefix:${NEXTPAS_TEST_MISSING_XYZ}:suffix'),
    'missing var becomes empty');
end;

procedure Test_ExpandEnv_Adjacent;
begin
  SetEnv('NEXTPAS_TEST_A', '1');
  SetEnv('NEXTPAS_TEST_B', '2');
  CheckEqual('1 and 2', ExpandEnv('${NEXTPAS_TEST_A} and ${NEXTPAS_TEST_B}'),
    'adjacent vars expand correctly');
  UnsetEnv('NEXTPAS_TEST_A');
  UnsetEnv('NEXTPAS_TEST_B');
end;

procedure Test_ExpandEnv_NoMarkers;
begin
  CheckEqual('plain text', ExpandEnv('plain text'),
    'no markers returns unchanged');
end;

procedure Test_ExpandEnv_Unterminated;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    ExpandEnv('bad ${NEXTPAS_TEST_EXPAND');
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'unterminated placeholder raises EArgumentError');
end;

procedure Test_ExpandEnv_InvalidName;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    ExpandEnv('${}');
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'empty var name raises EArgumentError');
end;

{ --- ExpandEnv $VAR tests --- }

procedure TestExpandEnv_DollarVar;
begin
  SetEnv('NEXTPAS_TEST_DOLLAR', 'hello');
  CheckEqual('hello', ExpandEnv('$NEXTPAS_TEST_DOLLAR'),
    'ExpandEnv expands $VAR');
  UnsetEnv('NEXTPAS_TEST_DOLLAR');
end;

procedure TestExpandEnv_DollarVarWithSuffix;
begin
  SetEnv('NEXTPAS_TEST_DOLLAR', 'hello');
  CheckEqual('hello.txt', ExpandEnv('$NEXTPAS_TEST_DOLLAR.txt'),
    'ExpandEnv $VAR with suffix');
  UnsetEnv('NEXTPAS_TEST_DOLLAR');
end;

procedure TestExpandEnv_DollarVarAtStart;
begin
  SetEnv('NEXTPAS_TEST_DOLLAR', 'hello');
  CheckEqual('hello world', ExpandEnv('$NEXTPAS_TEST_DOLLAR world'),
    'ExpandEnv $VAR at start');
  UnsetEnv('NEXTPAS_TEST_DOLLAR');
end;

procedure TestExpandEnv_DollarVarInMiddle;
begin
  SetEnv('NEXTPAS_TEST_DOLLAR', 'hello');
  CheckEqual('prefix hello suffix', ExpandEnv('prefix $NEXTPAS_TEST_DOLLAR suffix'),
    'ExpandEnv $VAR in middle');
  UnsetEnv('NEXTPAS_TEST_DOLLAR');
end;

procedure TestExpandEnv_DollarAlone;
begin
  CheckEqual('$', ExpandEnv('$'),
    'ExpandEnv lone dollar');
end;

procedure TestExpandEnv_DollarAtEnd;
begin
  CheckEqual('text$', ExpandEnv('text$'),
    'ExpandEnv dollar at end of string');
end;

procedure TestExpandEnv_MixedSyntax;
begin
  SetEnv('NEXTPAS_TEST_DOLLAR', 'dollar');
  SetEnv('NEXTPAS_TEST_BRACE', 'brace');
  CheckEqual('dollar brace', ExpandEnv('$NEXTPAS_TEST_DOLLAR ${NEXTPAS_TEST_BRACE}'),
    'ExpandEnv mixed $VAR and ${VAR}');
  UnsetEnv('NEXTPAS_TEST_DOLLAR');
  UnsetEnv('NEXTPAS_TEST_BRACE');
end;

procedure TestExpandEnv_DollarVarUndefined;
begin
  CheckEqual('', ExpandEnv('$NONEXISTENT_VAR_XYZ'),
    'ExpandEnv undefined $VAR returns empty');
end;

procedure TestEnvKeys;
var
  LKeys: TStringArray;
  I: Integer;
  LFoundHome: Boolean;
begin
  SetEnv('NEXTPAS_TEST_ENVKEYS', 'test123');
  LKeys := EnvKeys;
  Check(Length(LKeys) > 0, 'EnvKeys returns non-empty array');
  LFoundHome := False;
  for I := 0 to High(LKeys) do
  begin
    Check(Pos('=', LKeys[I]) = 0, 'EnvKeys entries have no = sign: ' + LKeys[I]);
    if LKeys[I] = 'NEXTPAS_TEST_ENVKEYS' then
      LFoundHome := True;
  end;
  Check(LFoundHome, 'EnvKeys contains NEXTPAS_TEST_ENVKEYS');
  UnsetEnv('NEXTPAS_TEST_ENVKEYS');
end;

procedure TestUserHomeDir;
var
  LHome: string;
begin
  LHome := UserHomeDir;
  Check(LHome <> '', 'UserHomeDir is not empty');
  Check(LHome[1] = '/', 'UserHomeDir starts with / (Unix)');
end;

procedure TestUserCacheDir;
var
  LCache: string;
begin
  LCache := UserCacheDir;
  Check(LCache <> '', 'UserCacheDir is not empty');
  Check(Pos('.cache', LCache) > 0, 'UserCacheDir contains .cache');
end;

procedure TestUserConfigDir;
var
  LConfig: string;
begin
  LConfig := UserConfigDir;
  Check(LConfig <> '', 'UserConfigDir is not empty');
  Check(Pos('.config', LConfig) > 0, 'UserConfigDir contains .config');
end;

procedure TestGetEnvDefault;
begin
  SetEnv('NEXTPAS_TEST_DEFAULT', 'exists');
  CheckEqual('exists', GetEnvDefault('NEXTPAS_TEST_DEFAULT', 'fallback'),
    'GetEnvDefault returns existing value');
  CheckEqual('fallback', GetEnvDefault('NEXTPAS_TEST_NONEXISTENT_VAR', 'fallback'),
    'GetEnvDefault returns default for missing var');
  UnsetEnv('NEXTPAS_TEST_DEFAULT');
end;

procedure TestExpandEnvWithDefault;
begin
  SetEnv('NEXTPAS_TEST_EXPDEF', 'hello');
  CheckEqual('hello world', ExpandEnvWithDefault('$NEXTPAS_TEST_EXPDEF world', 'NOPE'),
    'ExpandEnvWithDefault existing var');
  CheckEqual('NOPE world', ExpandEnvWithDefault('$NEXTPAS_TEST_MISSING_VAR world', 'NOPE'),
    'ExpandEnvWithDefault missing var uses default');
  CheckEqual('hello!=NOPE',
    ExpandEnvWithDefault('${NEXTPAS_TEST_EXPDEF}!=$NEXTPAS_TEST_UNDEF_XYZ', 'NOPE'),
    'ExpandEnvWithDefault mixed');
  UnsetEnv('NEXTPAS_TEST_EXPDEF');
end;

procedure TestExpandEnvWithDefault_EmptyValue;
begin
  SetEnv('NEXTPAS_TEST_EXPDEF_EMPTY', '');
  // Empty value is defined, should NOT use default
  CheckEqual('', ExpandEnvWithDefault('$NEXTPAS_TEST_EXPDEF_EMPTY', 'NOPE'),
    'ExpandEnvWithDefault empty value does not use default');
  UnsetEnv('NEXTPAS_TEST_EXPDEF_EMPTY');
end;

procedure TestExpandEnvStrict;
var
  LRaised: Boolean;
begin
  SetEnv('NEXTPAS_TEST_STRICT', 'value');
  { Existing var should work }
  CheckEqual('value', ExpandEnvStrict('$NEXTPAS_TEST_STRICT'),
    'ExpandEnvStrict existing var');
  { Undefined var should raise }
  LRaised := False;
  try
    ExpandEnvStrict('$NEXTPAS_TEST_UNDEF_STRICT_XYZ');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'ExpandEnvStrict raises on undefined var');
  UnsetEnv('NEXTPAS_TEST_STRICT');
end;

procedure TestExpandEnvStrict_BraceSyntax;
var
  LRaised: Boolean;
begin
  SetEnv('NEXTPAS_TEST_BRACE', 'hello');
  // ${VAR} syntax should work
  CheckEqual('hello', ExpandEnvStrict('${NEXTPAS_TEST_BRACE}'),
    'ExpandEnvStrict ${VAR} syntax');
  // ${UNDEF} should raise
  LRaised := False;
  try
    ExpandEnvStrict('${NEXTPAS_TEST_UNDEF_BRACE_XYZ}');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'ExpandEnvStrict raises on undefined ${VAR}');
  // Unterminated ${ should raise
  LRaised := False;
  try
    ExpandEnvStrict('${NEXTPAS_TEST_BRACE');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'ExpandEnvStrict raises on unterminated ${');
  UnsetEnv('NEXTPAS_TEST_BRACE');
end;

procedure TestExpandEnvStrict_EmptyValue;
begin
  SetEnv('NEXTPAS_TEST_EMPTY', '');
  { Empty value should NOT raise — var is defined, just empty }
  CheckEqual('', ExpandEnvStrict('$NEXTPAS_TEST_EMPTY'),
    'ExpandEnvStrict empty value does not raise');
  UnsetEnv('NEXTPAS_TEST_EMPTY');
end;

{ --- main --- }

begin
  T := TTestSuite.Create('nextpas.core.os.env');
  T.Test('GetEnv_HOME', @Test_GetEnv_HOME);
  T.Test('GetEnv_Missing', @Test_GetEnv_Missing);
  T.Test('GetEnvironmentVariable_Compat', @Test_GetEnvironmentVariable_Compat);
  T.Test('HasEnv_Exists', @Test_HasEnv_Exists);
  T.Test('HasEnv_Missing', @Test_HasEnv_Missing);
  T.Test('SetEnv_And_Get', @Test_SetEnv_And_Get);
  T.Test('SetEnv_Overwrite', @Test_SetEnv_Overwrite);
  T.Test('SetEnv_Empty_Value', @Test_SetEnv_Empty_Value);
  T.Test('UnsetEnv', @Test_UnsetEnv);
  T.Test('UnsetEnv_NonExistent', @Test_UnsetEnv_NonExistent);
  T.Test('ExpandEnv_Basic', @Test_ExpandEnv_Basic);
  T.Test('ExpandEnv_NotFound', @Test_ExpandEnv_NotFound);
  T.Test('ExpandEnv_Adjacent', @Test_ExpandEnv_Adjacent);
  T.Test('ExpandEnv_NoMarkers', @Test_ExpandEnv_NoMarkers);
  T.Test('ExpandEnv_Unterminated', @Test_ExpandEnv_Unterminated);
  T.Test('ExpandEnv_InvalidName', @Test_ExpandEnv_InvalidName);
  T.Test('ExpandEnv $VAR', @TestExpandEnv_DollarVar);
  T.Test('ExpandEnv $VAR.txt', @TestExpandEnv_DollarVarWithSuffix);
  T.Test('ExpandEnv $VAR world', @TestExpandEnv_DollarVarAtStart);
  T.Test('ExpandEnv prefix $VAR suffix', @TestExpandEnv_DollarVarInMiddle);
  T.Test('ExpandEnv lone $', @TestExpandEnv_DollarAlone);
  T.Test('ExpandEnv text$', @TestExpandEnv_DollarAtEnd);
  T.Test('ExpandEnv $VAR + ${VAR}', @TestExpandEnv_MixedSyntax);
  T.Test('ExpandEnv $UNDEFINED', @TestExpandEnv_DollarVarUndefined);
  T.Test('EnvKeys', @TestEnvKeys);
  T.Test('UserHomeDir', @TestUserHomeDir);
  T.Test('UserCacheDir', @TestUserCacheDir);
  T.Test('UserConfigDir', @TestUserConfigDir);
  T.Test('GetEnvDefault', @TestGetEnvDefault);
  T.Test('ExpandEnvWithDefault', @TestExpandEnvWithDefault);
  T.Test('ExpandEnvWithDefault_EmptyValue', @TestExpandEnvWithDefault_EmptyValue);
  T.Test('ExpandEnvStrict', @TestExpandEnvStrict);
  T.Test('ExpandEnvStrict_BraceSyntax', @TestExpandEnvStrict_BraceSyntax);
  T.Test('ExpandEnvStrict_EmptyValue', @TestExpandEnvStrict_EmptyValue);
  if not T.Run then Halt(1);
end.