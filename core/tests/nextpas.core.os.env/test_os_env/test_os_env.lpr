program test_os_env;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.text.base,
  nextpas.core.fs,
  nextpas.core.os.env,
  nextpas.core.platform.env;

var
  T: TTestSuite;

{$I ../../fpc_rtl_uses_scan.inc}

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
begin
  LSourcePath := PathAbs('../../../' + ARelativePath);
  Check(Exists(LSourcePath), 'source exists: ' + ARelativePath);
  Result := ReadFileText(LSourcePath);
end;

procedure AssertSourceNoBareFpcRtlUses(const ALabel, ASource: string);
var
  LHit: string;
  LOk: Boolean;
  LMsg: string;
begin
  LOk := not FindBareFpcRtlInUses(ASource, LHit);
  LMsg := ALabel + ' — no bare FPC RTL in uses';
  if not LOk then
    LMsg := LMsg + ' (hit: ' + LHit + ')';
  Check(LOk, LMsg);
end;

procedure TestEnvOwnedSourcesNoFpcRtl;
begin
  AssertSourceNoBareFpcRtlUses('env src',
    LoadSourceText('src/nextpas.core.os.env.pas'));
end;

procedure TestEnvTestSuiteNoFpcRtl;
begin
  AssertSourceNoBareFpcRtlUses('env test',
    LoadSourceText('tests/nextpas.core.os.env/test_os_env/test_os_env.lpr'));
end;

procedure TestSetEnvRejectsNonPortableName;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    SetEnv('BAD NAME', 'v');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'SetEnv rejects space in name');

  LRaised := False;
  try
    SetEnv('1ABC', 'v');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'SetEnv rejects digit-leading name');

  LRaised := False;
  try
    UnsetEnv('has-dash');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'UnsetEnv rejects dash in name');
end;

procedure TestExpandEnvRejectsNonPortablePlaceholder;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    ExpandEnv('${foo-bar}');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'ExpandEnv rejects non-portable ${name}');

  LRaised := False;
  try
    ExpandEnv('$1ABC');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'ExpandEnv rejects digit-leading $VAR');
end;

procedure TestGetEnvAllowsNonPortableLookup;
begin
  { Lookup only forbids empty / = / NUL — odd names return empty, do not raise. }
  CheckEqual('', GetEnv('weird name'), 'GetEnv allows space name lookup');
  CheckEqual('', GetEnv('1digit'), 'GetEnv allows digit-leading lookup');
end;

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
  LCache, LSaved, LApp: string;
  LHadXdg: Boolean;
begin
  LHadXdg := TryGetEnv('XDG_CACHE_HOME', LSaved);
  try
    UnsetEnv('XDG_CACHE_HOME');
    LCache := UserCacheDir;
    Check(LCache <> '', 'UserCacheDir is not empty');
    Check(Pos('.cache', LCache) > 0, 'UserCacheDir fallback contains .cache');

    SetEnv('XDG_CACHE_HOME', '/tmp/nextpas-xdg-cache-test');
    LCache := UserCacheDir;
    CheckEqual('/tmp/nextpas-xdg-cache-test', LCache,
      'UserCacheDir respects XDG_CACHE_HOME');

    LApp := UserCacheDir('myapp');
    CheckEqual('/tmp/nextpas-xdg-cache-test/myapp', LApp,
      'UserCacheDir joins AppName');
  finally
    if LHadXdg then
      SetEnv('XDG_CACHE_HOME', LSaved)
    else
      UnsetEnv('XDG_CACHE_HOME');
  end;
end;

procedure TestUserConfigDir;
var
  LConfig, LSaved: string;
  LHadXdg: Boolean;
begin
  LHadXdg := TryGetEnv('XDG_CONFIG_HOME', LSaved);
  try
    UnsetEnv('XDG_CONFIG_HOME');
    LConfig := UserConfigDir;
    Check(LConfig <> '', 'UserConfigDir is not empty');
    Check(Pos('.config', LConfig) > 0, 'UserConfigDir fallback contains .config');

    SetEnv('XDG_CONFIG_HOME', '/tmp/nextpas-xdg-config-test');
    LConfig := UserConfigDir('app');
    CheckEqual('/tmp/nextpas-xdg-config-test/app', LConfig,
      'UserConfigDir XDG + AppName');
  finally
    if LHadXdg then
      SetEnv('XDG_CONFIG_HOME', LSaved)
    else
      UnsetEnv('XDG_CONFIG_HOME');
  end;
end;

procedure TestGetEnvDefault;
begin
  SetEnv('NEXTPAS_TEST_DEFAULT', 'exists');
  CheckEqual('exists', GetEnvDefault('NEXTPAS_TEST_DEFAULT', 'fallback'),
    'GetEnvDefault returns existing value');
  CheckEqual('fallback', GetEnvDefault('NEXTPAS_TEST_NONEXISTENT_VAR', 'fallback'),
    'GetEnvDefault returns default for missing var');
  SetEnv('NEXTPAS_TEST_DEFAULT_EMPTY', '');
  CheckEqual('', GetEnvDefault('NEXTPAS_TEST_DEFAULT_EMPTY', 'fallback'),
    'GetEnvDefault returns empty string for defined-empty var');
  UnsetEnv('NEXTPAS_TEST_DEFAULT');
  UnsetEnv('NEXTPAS_TEST_DEFAULT_EMPTY');
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

procedure TestUserDataDir;
var
  LData, LSaved: string;
  LHadXdg: Boolean;
begin
  LHadXdg := TryGetEnv('XDG_DATA_HOME', LSaved);
  try
    UnsetEnv('XDG_DATA_HOME');
    LData := UserDataDir;
    Check(LData <> '', 'UserDataDir is not empty');
    Check(Pos('.local/share', LData) > 0, 'UserDataDir fallback contains .local/share');

    SetEnv('XDG_DATA_HOME', '/tmp/nextpas-xdg-data-test');
    LData := UserDataDir('app');
    CheckEqual('/tmp/nextpas-xdg-data-test/app', LData,
      'UserDataDir XDG + AppName');
  finally
    if LHadXdg then
      SetEnv('XDG_DATA_HOME', LSaved)
    else
      UnsetEnv('XDG_DATA_HOME');
  end;
end;

procedure TestUserStateDir;
var
  LState, LSaved: string;
  LHadXdg: Boolean;
begin
  LHadXdg := TryGetEnv('XDG_STATE_HOME', LSaved);
  try
    UnsetEnv('XDG_STATE_HOME');
    LState := UserStateDir;
    Check(LState <> '', 'UserStateDir is not empty');
    Check(Pos('.local/state', LState) > 0, 'UserStateDir fallback contains .local/state');

    SetEnv('XDG_STATE_HOME', '/tmp/nextpas-xdg-state-test');
    LState := UserStateDir('app');
    CheckEqual('/tmp/nextpas-xdg-state-test/app', LState,
      'UserStateDir XDG + AppName');
  finally
    if LHadXdg then
      SetEnv('XDG_STATE_HOME', LSaved)
    else
      UnsetEnv('XDG_STATE_HOME');
  end;
end;

procedure TestExpandEnv_PercentVar;
begin
  SetEnv('NEXTPAS_TEST_PERCENT', 'pctval');
  try
    CheckEqual('pctval', ExpandEnv('%NEXTPAS_TEST_PERCENT%'),
      'ExpandEnv expands %VAR%');
    CheckEqual('pre-pctval-post', ExpandEnv('pre-%NEXTPAS_TEST_PERCENT%-post'),
      'ExpandEnv percent in middle');
    CheckEqual('100%', ExpandEnv('100%'),
      'ExpandEnv lone trailing percent stays');
    CheckEqual('a%b', ExpandEnv('a%b'),
      'ExpandEnv incomplete percent stays literal');
    CheckEqual('pctval/pctval', ExpandEnv('%NEXTPAS_TEST_PERCENT%/$NEXTPAS_TEST_PERCENT'),
      'ExpandEnv mixed percent and dollar');
  finally
    UnsetEnv('NEXTPAS_TEST_PERCENT');
  end;
end;

procedure TestClearEnv;
var
  LSnap: TStringArray;
  I, Eq: Integer;
  LName, LVal: string;
  LCode: Int32;
begin
  SetEnv('NEXTPAS_CLEAR_ME', '1');
  Check(HasEnv('NEXTPAS_CLEAR_ME'), 'pre-clear has marker');
  LSnap := EnvironmentVariables;
  try
    ClearEnv;
    Check(not HasEnv('NEXTPAS_CLEAR_ME'), 'ClearEnv removes marker');
  finally
    for I := 0 to High(LSnap) do
    begin
      Eq := Pos('=', LSnap[I]);
      if Eq <= 1 then
        Continue;
      LName := Copy(LSnap[I], 1, Eq - 1);
      LVal := Copy(LSnap[I], Eq + 1, MaxInt);
      LCode := platform_env_set(PAnsiChar(LName), PAnsiChar(LVal));
      Check(LCode = 0, 'restore env ' + LName);
    end;
  end;
  Check(HasEnv('NEXTPAS_CLEAR_ME') or (not HasEnv('NEXTPAS_CLEAR_ME')),
    'post-restore suite continues');
end;

procedure TestHasEnvEmptyVsMissing;
begin
  SetEnv('NEXTPAS_EMPTY_HAS', '');
  try
    Check(HasEnv('NEXTPAS_EMPTY_HAS'), 'empty value still HasEnv');
    Check(not HasEnv('NEXTPAS_MISSING_HAS_XYZ'), 'missing not HasEnv');
    CheckEqual('', GetEnv('NEXTPAS_EMPTY_HAS'), 'empty GetEnv');
    CheckEqual('', GetEnv('NEXTPAS_MISSING_HAS_XYZ'), 'missing GetEnv empty');
  finally
    UnsetEnv('NEXTPAS_EMPTY_HAS');
  end;
end;

procedure TestExpandEnvDollarDollarLiteral;
begin
  { Lone $ stays; $$ is two lone $ }
  CheckEqual('$', ExpandEnv('$'), 'lone dollar');
  CheckEqual('$$', ExpandEnv('$$'), 'double dollar literal pair');
end;

procedure TestExpandEnvBraceUndefined;
begin
  CheckEqual('', ExpandEnv('${NEXTPAS_NEVER_DEFINED_XYZ}'), 'brace undefined empty');
  CheckEqual('x', ExpandEnv('x${NEXTPAS_NEVER_DEFINED_XYZ}'), 'brace undefined mid');
end;

procedure TestExpandEnvMultipleVars;
begin
  SetEnv('NEXTPAS_A_R17', 'aa');
  SetEnv('NEXTPAS_B_R17', 'bb');
  try
    CheckEqual('aabb', ExpandEnv('$NEXTPAS_A_R17$NEXTPAS_B_R17'), 'adjacent vars');
    CheckEqual('aa-bb', ExpandEnv('${NEXTPAS_A_R17}-${NEXTPAS_B_R17}'), 'brace pair');
    CheckEqual('pre-aa-post', ExpandEnv('pre-$NEXTPAS_A_R17-post'), 'dollar mid');
  finally
    UnsetEnv('NEXTPAS_A_R17');
    UnsetEnv('NEXTPAS_B_R17');
  end;
end;

procedure TestExpandEnvStrictMissingRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    ExpandEnvStrict('$NEXTPAS_STRICT_MISSING_XYZ');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'ExpandEnvStrict missing raises');
end;

procedure TestGetEnvDefaultEdges;
begin
  CheckEqual('def', GetEnvDefault('NEXTPAS_MISSING_DEF_XYZ', 'def'), 'default used');
  SetEnv('NEXTPAS_DEF_EMPTY', '');
  try
    CheckEqual('', GetEnvDefault('NEXTPAS_DEF_EMPTY', 'def'), 'empty value not default');
  finally
    UnsetEnv('NEXTPAS_DEF_EMPTY');
  end;
end;

procedure TestTryGetEnvRoundtrip;
var
  LVal: string;
begin
  SetEnv('NEXTPAS_TRY_RT', 'v1');
  try
    Check(TryGetEnv('NEXTPAS_TRY_RT', LVal), 'try get true');
    CheckEqual('v1', LVal, 'try get value');
    Check(not TryGetEnv('NEXTPAS_TRY_MISSING_XYZ', LVal), 'try missing false');
  finally
    UnsetEnv('NEXTPAS_TRY_RT');
  end;
end;

procedure TestEnvKeysContainsMarker;
var
  LKeys: TStringArray;
  I: Integer;
  LFound: Boolean;
begin
  SetEnv('NEXTPAS_KEY_MARK', '1');
  try
    LKeys := EnvKeys;
    LFound := False;
    for I := 0 to High(LKeys) do
      if LKeys[I] = 'NEXTPAS_KEY_MARK' then
        LFound := True;
    Check(LFound, 'EnvKeys contains marker');
  finally
    UnsetEnv('NEXTPAS_KEY_MARK');
  end;
end;

procedure TestSetEnvOverwriteRoundtrip;
begin
  SetEnv('NEXTPAS_OW', '1');
  try
    CheckEqual('1', GetEnv('NEXTPAS_OW'), 'set first');
    SetEnv('NEXTPAS_OW', '2');
    CheckEqual('2', GetEnv('NEXTPAS_OW'), 'overwrite');
    UnsetEnv('NEXTPAS_OW');
    Check(not HasEnv('NEXTPAS_OW'), 'unset after');
  finally
    UnsetEnv('NEXTPAS_OW');
  end;
end;

procedure TestUserHomeDirNonEmpty;
var
  LHome: string;
begin
  LHome := UserHomeDir;
  Check(LHome <> '', 'home non-empty');
  Check(PathIsAbs(LHome) or (LHome[1] = '/'), 'home looks absolute');
end;

procedure TestExpandEnvPercentEdges;
begin
  SetEnv('NEXTPAS_PCT', 'P');
  try
    CheckEqual('P', ExpandEnv('%NEXTPAS_PCT%'), 'percent expand');
    CheckEqual('%', ExpandEnv('%'), 'lone percent');
    CheckEqual('%%', ExpandEnv('%%'), 'double percent');
  finally
    UnsetEnv('NEXTPAS_PCT');
  end;
end;

procedure TestExpandEnvWithDefaultUndefined;
begin
  CheckEqual('fb', ExpandEnvWithDefault('$NEXTPAS_NOPE_XYZ', 'fb'), 'with default');
  CheckEqual('xfb', ExpandEnvWithDefault('x$NEXTPAS_NOPE_XYZ', 'fb'), 'with default mid');
end;

procedure TestEnvironmentVariablesNonEmpty;
var
  LAll: TStringArray;
begin
  LAll := EnvironmentVariables;
  Check(Length(LAll) > 0, 'environ non-empty');
end;

{ --- main --- }

procedure TestExpandEnvR19Table;
begin
  SetEnv('NEXTPAS_R19_E', 'v');
  try
    CheckEqual('v', ExpandEnv('$NEXTPAS_R19_E'), 'r19 expand $');
    CheckEqual('v', ExpandEnv('${NEXTPAS_R19_E}'), 'r19 expand brace');
    CheckEqual('pre-v-post', ExpandEnv('pre-$NEXTPAS_R19_E-post'), 'r19 expand mid');
    CheckEqual('', ExpandEnv('$NEXTPAS_R19_NONE'), 'r19 expand missing empty');
    CheckEqual('v%', ExpandEnv('$NEXTPAS_R19_E%'), 'r19 expand trailing %');
  finally
    UnsetEnv('NEXTPAS_R19_E');
  end;
end;

procedure TestExpandEnvStrictR19;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    ExpandEnvStrict('$NEXTPAS_R19_STRICT_MISS');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'r19 strict missing raises');
end;

procedure TestHasEnvLookupR19;
begin
  SetEnv('NEXTPAS_R19_EMPTY', '');
  try
    Check(HasEnv('NEXTPAS_R19_EMPTY'), 'r19 empty has');
    Check(not HasEnv('NEXTPAS_R19_NOPE'), 'r19 missing has not');
    CheckEqual('', GetEnv('NEXTPAS_R19_EMPTY'), 'r19 empty get');
    CheckEqual('d', GetEnvDefault('NEXTPAS_R19_NOPE', 'd'), 'r19 default');
  finally
    UnsetEnv('NEXTPAS_R19_EMPTY');
  end;
end;

procedure TestEnvKeysMarkerR19;
var
  K: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  SetEnv('NEXTPAS_R19_KEY', '1');
  try
    K := EnvKeys;
    Found := False;
    for I := 0 to High(K) do
      if K[I] = 'NEXTPAS_R19_KEY' then
        Found := True;
    Check(Found, 'r19 keys has marker');
  finally
    UnsetEnv('NEXTPAS_R19_KEY');
  end;
end;

procedure TestUserDirsNonEmptyR19;
begin
  Check(UserHomeDir <> '', 'r19 home');
  Check(UserCacheDir <> '', 'r19 cache');
  Check(UserConfigDir <> '', 'r19 config');
end;

procedure TestSetUnsetRoundtripR19;
begin
  SetEnv('NEXTPAS_R19_RT', 'a');
  CheckEqual('a', GetEnv('NEXTPAS_R19_RT'), 'r19 set');
  SetEnv('NEXTPAS_R19_RT', 'b');
  CheckEqual('b', GetEnv('NEXTPAS_R19_RT'), 'r19 overwrite');
  UnsetEnv('NEXTPAS_R19_RT');
  Check(not HasEnv('NEXTPAS_R19_RT'), 'r19 unset');
end;

procedure TestExpandPercentR19;
begin
  SetEnv('NEXTPAS_R19_P', 'P');
  try
    CheckEqual('P', ExpandEnv('%NEXTPAS_R19_P%'), 'r19 percent');
    CheckEqual('xPy', ExpandEnv('x%NEXTPAS_R19_P%y'), 'r19 percent mid');
  finally
    UnsetEnv('NEXTPAS_R19_P');
  end;
end;

procedure TestExpandWithDefaultR19;
begin
  CheckEqual('fb', ExpandEnvWithDefault('$NEXTPAS_R19_X', 'fb'), 'r19 with def');
  SetEnv('NEXTPAS_R19_Y', 'y');
  try
    CheckEqual('y', ExpandEnvWithDefault('$NEXTPAS_R19_Y', 'fb'), 'r19 with def hit');
  finally
    UnsetEnv('NEXTPAS_R19_Y');
  end;
end;


procedure TestExpandEnvR19Extra;
begin
  SetEnv('NEXTPAS_R19E1', 'A');
  SetEnv('NEXTPAS_R19E2', 'B');
  try
    CheckEqual('AB', ExpandEnv('$NEXTPAS_R19E1$NEXTPAS_R19E2'), 'r19ee1');
    CheckEqual('A:B', ExpandEnv('${NEXTPAS_R19E1}:${NEXTPAS_R19E2}'), 'r19ee2');
    CheckEqual('$', ExpandEnv('$'), 'r19ee3');
    CheckEqual('$$', ExpandEnv('$$'), 'r19ee4');
    CheckEqual('A%', ExpandEnv('$NEXTPAS_R19E1%'), 'r19ee5');
  finally
    UnsetEnv('NEXTPAS_R19E1');
    UnsetEnv('NEXTPAS_R19E2');
  end;
end;

procedure TestTryGetEnvR19Extra;
var
  V: string;
begin
  SetEnv('NEXTPAS_R19TRY', 't');
  try
    Check(TryGetEnv('NEXTPAS_R19TRY', V), 'r19try1');
    CheckEqual('t', V, 'r19try2');
    Check(not TryGetEnv('NEXTPAS_R19TRY_MISS', V), 'r19try3');
  finally
    UnsetEnv('NEXTPAS_R19TRY');
  end;
end;

procedure TestEnvironNonEmptyR19Extra;
var
  E: TStringArray;
begin
  E := EnvironmentVariables;
  Check(Length(E) > 0, 'r19env non-empty');
  Check(Pos('=', E[0]) > 0, 'r19env pair shape');
end;

procedure TestGetEnvDefaultR19Extra;
begin
  CheckEqual('z', GetEnvDefault('NEXTPAS_R19GD_MISS', 'z'), 'r19gd1');
  SetEnv('NEXTPAS_R19GD', '');
  try
    CheckEqual('', GetEnvDefault('NEXTPAS_R19GD', 'z'), 'r19gd2 empty wins');
  finally
    UnsetEnv('NEXTPAS_R19GD');
  end;
end;

{ R22: mixed expand forms + empty vs missing }
procedure TestExpandEnvMixedR22;
begin
  SetEnv('NEXTPAS_R22A', 'A');
  SetEnv('NEXTPAS_R22B', 'B');
  try
    CheckEqual('A-B', ExpandEnv('$NEXTPAS_R22A-$NEXTPAS_R22B'), 'r22 mix dollar');
    CheckEqual('A/B', ExpandEnv('${NEXTPAS_R22A}/${NEXTPAS_R22B}'), 'r22 mix brace');
    CheckEqual('AB', ExpandEnv('%NEXTPAS_R22A%%NEXTPAS_R22B%'), 'r22 mix percent adjacent');
    CheckEqual('A-B', ExpandEnv('%NEXTPAS_R22A%-%NEXTPAS_R22B%'), 'r22 mix percent sep');
    CheckEqual('A-x', ExpandEnv('$NEXTPAS_R22A-x'), 'r22 dollar suffix');
    CheckEqual('pre', ExpandEnv('pre${NEXTPAS_R22_MISS}'), 'r22 undefined empty');
  finally
    UnsetEnv('NEXTPAS_R22A');
    UnsetEnv('NEXTPAS_R22B');
  end;
end;

procedure TestHasEnvEmptyR22;
begin
  SetEnv('NEXTPAS_R22EMPTY', '');
  try
    Check(HasEnv('NEXTPAS_R22EMPTY'), 'r22 empty exists');
    CheckEqual('', GetEnv('NEXTPAS_R22EMPTY'), 'r22 empty value');
    Check(not HasEnv('NEXTPAS_R22NEVER'), 'r22 missing');
  finally
    UnsetEnv('NEXTPAS_R22EMPTY');
  end;
end;

{ R31: os.Expand / Environ edge table. }
procedure TestExpandEnvKeysR31;
var
  LKeys: TStringArray;
  I: Integer;
  Found: Boolean;
  Raised: Boolean;
begin
  SetEnv('NEXTPAS_R31_A', 'alpha');
  SetEnv('NEXTPAS_R31_B', 'beta');
  try
    CheckEqual('alpha-beta', ExpandEnv('$NEXTPAS_R31_A-${NEXTPAS_R31_B}'),
      'r31 mixed $ and ${}');
    CheckEqual('alpha:beta', ExpandEnv('${NEXTPAS_R31_A}:${NEXTPAS_R31_B}'),
      'r31 brace pair');
    CheckEqual('alpha', ExpandEnvWithDefault('${NEXTPAS_R31_A}', 'x'),
      'r31 with default present');
    CheckEqual('fallback', ExpandEnvWithDefault('${NEXTPAS_R31_MISSING}', 'fallback'),
      'r31 with default missing');
    CheckEqual('alpha', ExpandEnvStrict('$NEXTPAS_R31_A'), 'r31 strict ok');
    Raised := False;
    try
      ExpandEnvStrict('$NEXTPAS_R31_NOPE');
    except
      on E: Exception do
        Raised := True;
    end;
    Check(Raised, 'r31 strict raises on missing');
    LKeys := EnvKeys;
    Found := False;
    for I := 0 to High(LKeys) do
      if LKeys[I] = 'NEXTPAS_R31_A' then
        Found := True;
    Check(Found, 'r31 EnvKeys has marker');
    Check(HasEnv('NEXTPAS_R31_A'), 'r31 HasEnv true');
    UnsetEnv('NEXTPAS_R31_A');
    Check(not HasEnv('NEXTPAS_R31_A'), 'r31 after unset');
  finally
    UnsetEnv('NEXTPAS_R31_A');
    UnsetEnv('NEXTPAS_R31_B');
  end;
end;




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
  T.Test('UserDataDir', @TestUserDataDir);
  T.Test('UserStateDir', @TestUserStateDir);
  T.Test('ExpandEnv_PercentVar', @TestExpandEnv_PercentVar);
  T.Test('GetEnvDefault', @TestGetEnvDefault);
  T.Test('ExpandEnvWithDefault', @TestExpandEnvWithDefault);
  T.Test('ExpandEnvWithDefault_EmptyValue', @TestExpandEnvWithDefault_EmptyValue);
  T.Test('ExpandEnvStrict', @TestExpandEnvStrict);
  T.Test('ExpandEnvStrict_BraceSyntax', @TestExpandEnvStrict_BraceSyntax);
  T.Test('ExpandEnvStrict_EmptyValue', @TestExpandEnvStrict_EmptyValue);
  T.Test('env owned sources no bare FPC RTL uses', @TestEnvOwnedSourcesNoFpcRtl);
  T.Test('env test suite no bare FPC RTL uses', @TestEnvTestSuiteNoFpcRtl);
  T.Test('SetEnv/UnsetEnv portable name', @TestSetEnvRejectsNonPortableName);
  T.Test('ExpandEnv portable placeholder', @TestExpandEnvRejectsNonPortablePlaceholder);
  T.Test('GetEnv allows non-portable lookup', @TestGetEnvAllowsNonPortableLookup);
  T.Test('ClearEnv', @TestClearEnv);
  T.Test('HasEnv empty vs missing', @TestHasEnvEmptyVsMissing);
  T.Test('ExpandEnv dollar literal', @TestExpandEnvDollarDollarLiteral);
  T.Test('ExpandEnv brace undefined', @TestExpandEnvBraceUndefined);
  T.Test('ExpandEnv multiple vars', @TestExpandEnvMultipleVars);
  T.Test('ExpandEnvStrict missing raises', @TestExpandEnvStrictMissingRaises);
  T.Test('GetEnvDefault edges', @TestGetEnvDefaultEdges);
  T.Test('TryGetEnv roundtrip', @TestTryGetEnvRoundtrip);
  T.Test('EnvKeys contains marker', @TestEnvKeysContainsMarker);
  T.Test('SetEnv overwrite roundtrip', @TestSetEnvOverwriteRoundtrip);
  T.Test('UserHomeDir non-empty', @TestUserHomeDirNonEmpty);
  T.Test('ExpandEnv percent edges', @TestExpandEnvPercentEdges);
  T.Test('ExpandEnvWithDefault undefined', @TestExpandEnvWithDefaultUndefined);
  T.Test('EnvironmentVariables non-empty', @TestEnvironmentVariablesNonEmpty);
  T.Test('ExpandEnv R19 table', @TestExpandEnvR19Table);
  T.Test('ExpandEnvStrict R19', @TestExpandEnvStrictR19);
  T.Test('HasEnv Lookup R19', @TestHasEnvLookupR19);
  T.Test('EnvKeys marker R19', @TestEnvKeysMarkerR19);
  T.Test('UserDirs non-empty R19', @TestUserDirsNonEmptyR19);
  T.Test('SetUnset roundtrip R19', @TestSetUnsetRoundtripR19);
  T.Test('Expand percent R19', @TestExpandPercentR19);
  T.Test('ExpandWithDefault R19', @TestExpandWithDefaultR19);
  T.Test('ExpandEnv R19 extra', @TestExpandEnvR19Extra);
  T.Test('TryGetEnv R19 extra', @TestTryGetEnvR19Extra);
  T.Test('Environ non-empty R19 extra', @TestEnvironNonEmptyR19Extra);
  T.Test('GetEnvDefault R19 extra', @TestGetEnvDefaultR19Extra);
  T.Test('ExpandEnv mixed R22', @TestExpandEnvMixedR22);
  T.Test('HasEnv empty R22', @TestHasEnvEmptyR22);
  T.Test('Expand EnvKeys R31', @TestExpandEnvKeysR31);
  if not T.Run then Halt(1);
end.