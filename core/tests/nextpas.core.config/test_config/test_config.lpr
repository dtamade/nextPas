program test_config;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.os.env,
  nextpas.core.config,
  nextpas.core.testing;

var
  T: TTestRunner;

{ === GetString Tests === }

procedure TestGetStringBasic;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[app]' + #10 + 'host=localhost' + #10 + 'port=8080' + #10);
    CheckEqual('localhost', LCfg.GetString('app.host'), 'host');
    CheckEqual('8080', LCfg.GetString('app.port'), 'port');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetStringDefault;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    CheckEqual('fallback', LCfg.GetString('missing', 'fallback'), 'default');
    CheckEqual('', LCfg.GetString('missing'), 'empty default');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetStringCaseInsensitive;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[DB]' + #10 + 'Host=myhost' + #10);
    CheckEqual('myhost', LCfg.GetString('db.host'), 'lower lookup');
    CheckEqual('myhost', LCfg.GetString('DB.HOST'), 'upper lookup');
  finally
    LCfg.Free;
  end;
end;

{ === GetInt Tests === }

procedure TestGetIntBasic;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[server]' + #10 + 'port=9090' + #10 + 'timeout=30' + #10);
    CheckEqual(Int64(9090), LCfg.GetInt('server.port'), 'port');
    CheckEqual(Int64(30), LCfg.GetInt('server.timeout'), 'timeout');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetIntDefault;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    CheckEqual(Int64(42), LCfg.GetInt('missing', 42), 'default');
    CheckEqual(Int64(0), LCfg.GetInt('missing'), 'zero default');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetIntInvalid;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[x]' + #10 + 'bad=abc' + #10 + 'float=3.14' + #10);
    CheckEqual(Int64(-1), LCfg.GetInt('x.bad', -1), 'non-numeric');
    CheckEqual(Int64(99), LCfg.GetInt('x.float', 99), 'float as int');
  finally
    LCfg.Free;
  end;
end;

{ === GetBool Tests === }

procedure TestGetBoolBasic;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[flags]' + #10 +
      'a=true' + #10 + 'b=false' + #10 +
      'c=1' + #10 + 'd=0' + #10 +
      'e=yes' + #10 + 'f=no' + #10 +
      'g=on' + #10 + 'h=off' + #10);
    CheckEqual(True, LCfg.GetBool('flags.a'), 'true');
    CheckEqual(False, LCfg.GetBool('flags.b'), 'false');
    CheckEqual(True, LCfg.GetBool('flags.c'), '1');
    CheckEqual(False, LCfg.GetBool('flags.d'), '0');
    CheckEqual(True, LCfg.GetBool('flags.e'), 'yes');
    CheckEqual(False, LCfg.GetBool('flags.f'), 'no');
    CheckEqual(True, LCfg.GetBool('flags.g'), 'on');
    CheckEqual(False, LCfg.GetBool('flags.h'), 'off');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetBoolDefault;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    CheckEqual(True, LCfg.GetBool('missing', True), 'default true');
    CheckEqual(False, LCfg.GetBool('missing', False), 'default false');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetBoolInvalid;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[x]' + #10 + 'bad=maybe' + #10);
    CheckEqual(True, LCfg.GetBool('x.bad', True), 'invalid returns default');
  finally
    LCfg.Free;
  end;
end;

{ === GetFloat Tests === }

procedure TestGetFloatBasic;
var
  LCfg: TConfig;
  LVal: Double;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[math]' + #10 + 'pi=3.14159' + #10 + 'neg=-2.5' + #10);
    LVal := LCfg.GetFloat('math.pi');
    Check((LVal > 3.14) and (LVal < 3.15), 'pi');
    LVal := LCfg.GetFloat('math.neg');
    Check((LVal > -2.6) and (LVal < -2.4), 'neg');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetFloatDefault;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    Check(LCfg.GetFloat('missing', 1.5) > 1.4, 'default');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetFloatInvalid;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[x]' + #10 + 'bad=hello' + #10);
    Check(LCfg.GetFloat('x.bad', 7.7) > 7.6, 'invalid returns default');
  finally
    LCfg.Free;
  end;
end;

{ === SetDefault Tests === }

procedure TestSetDefault;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetDefault('key1', 'default_val');
    CheckEqual('default_val', LCfg.GetString('key1'), 'set default');
    { LoadFromIni should override }
    LCfg.LoadFromIni('[section]' + #10 + 'key1=override' + #10);
    { SetDefault should NOT override existing }
    LCfg.SetDefault('section.key1', 'ignored');
    CheckEqual('override', LCfg.GetString('section.key1'), 'not overridden');
  finally
    LCfg.Free;
  end;
end;

{ === LoadFromIni Tests === }

procedure TestLoadFromIniSections;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni(
      '[database]' + #10 +
      'host=db.example.com' + #10 +
      'port=5432' + #10 +
      '[cache]' + #10 +
      'ttl=300' + #10);
    CheckEqual('db.example.com', LCfg.GetString('database.host'), 'db host');
    CheckEqual(Int64(5432), LCfg.GetInt('database.port'), 'db port');
    CheckEqual(Int64(300), LCfg.GetInt('cache.ttl'), 'cache ttl');
  finally
    LCfg.Free;
  end;
end;

procedure TestLoadFromIniGlobalKeys;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('name=myapp' + #10 + 'version=1.0' + #10);
    CheckEqual('myapp', LCfg.GetString('name'), 'global name');
    CheckEqual('1.0', LCfg.GetString('version'), 'global version');
  finally
    LCfg.Free;
  end;
end;

{ === LoadFromJson Tests === }

procedure TestLoadFromJsonBasic;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"host":"localhost","port":3000,"debug":true}');
    CheckEqual('localhost', LCfg.GetString('host'), 'json host');
    CheckEqual(Int64(3000), LCfg.GetInt('port'), 'json port');
    CheckEqual(True, LCfg.GetBool('debug'), 'json debug');
  finally
    LCfg.Free;
  end;
end;

procedure TestLoadFromJsonTypes;
var
  LCfg: TConfig;
  LVal: Double;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"str":"hello","num":42,"flt":2.718,"flag":false,"nil_val":null}');
    CheckEqual('hello', LCfg.GetString('str'), 'string');
    CheckEqual(Int64(42), LCfg.GetInt('num'), 'int');
    LVal := LCfg.GetFloat('flt');
    Check((LVal > 2.71) and (LVal < 2.72), 'float');
    CheckEqual(False, LCfg.GetBool('flag'), 'bool');
    CheckEqual('', LCfg.GetString('nil_val'), 'null');
  finally
    LCfg.Free;
  end;
end;

{ === LoadFromEnv Tests === }

procedure TestLoadFromEnvBasic;
var
  LCfg: TConfig;
begin
  SetEnv('TESTCFG_HOST', 'envhost');
  SetEnv('TESTCFG_PORT', '4000');
  try
    LCfg := TConfig.Create;
    try
      LCfg.LoadFromEnv('TESTCFG_');
      CheckEqual('envhost', LCfg.GetString('host'), 'env host');
      CheckEqual(Int64(4000), LCfg.GetInt('port'), 'env port');
    finally
      LCfg.Free;
    end;
  finally
    UnsetEnv('TESTCFG_HOST');
    UnsetEnv('TESTCFG_PORT');
  end;
end;

procedure TestLoadFromEnvOverride;
var
  LCfg: TConfig;
begin
  SetEnv('MYAPP_DB_HOST', 'envdb');
  try
    LCfg := TConfig.Create;
    try
      LCfg.LoadFromIni('[x]' + #10 + 'db_host=inidb' + #10);
      { Env loaded after INI overrides }
      LCfg.LoadFromEnv('MYAPP_');
      CheckEqual('envdb', LCfg.GetString('db_host'), 'env overrides ini');
    finally
      LCfg.Free;
    end;
  finally
    UnsetEnv('MYAPP_DB_HOST');
  end;
end;

{ === Has / GetKeys Tests === }

procedure TestHas;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromIni('[s]' + #10 + 'key=val' + #10);
    CheckEqual(True, LCfg.Has('s.key'), 'exists');
    CheckEqual(False, LCfg.Has('s.missing'), 'not exists');
  finally
    LCfg.Free;
  end;
end;

procedure TestGetKeys;
var
  LCfg: TConfig;
  LKeys: TStringArray;
begin
  LCfg := TConfig.Create;
  try
    LCfg.LoadFromJson('{"a":"1","b":"2","c":"3"}');
    LKeys := LCfg.GetKeys;
    CheckEqual(Int64(3), Int64(Length(LKeys)), 'key count');
  finally
    LCfg.Free;
  end;
end;

{ === Empty Config Tests === }

procedure TestEmptyConfig;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    CheckEqual(Int64(0), Int64(LCfg.Count), 'empty count');
    CheckEqual(False, LCfg.Has('anything'), 'empty has');
    CheckEqual('def', LCfg.GetString('x', 'def'), 'empty get');
  finally
    LCfg.Free;
  end;
end;

{ === Override Priority Tests === }

procedure TestOverridePriority;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    { SetDefault first }
    LCfg.SetDefault('server.host', 'default_host');
    { INI overrides default }
    LCfg.LoadFromIni('[server]' + #10 + 'host=ini_host' + #10);
    CheckEqual('ini_host', LCfg.GetString('server.host'), 'ini over default');
    { JSON overrides INI }
    LCfg.LoadFromJson('{"server.host":"json_host"}');
    CheckEqual('json_host', LCfg.GetString('server.host'), 'json over ini');
  finally
    LCfg.Free;
  end;
end;

procedure TestOverrideEnvHighest;
var
  LCfg: TConfig;
begin
  SetEnv('APP_NAME', 'env_app');
  try
    LCfg := TConfig.Create;
    try
      LCfg.SetDefault('name', 'default_app');
      LCfg.LoadFromIni('name=ini_app' + #10);
      LCfg.LoadFromJson('{"name":"json_app"}');
      LCfg.LoadFromEnv('APP_');
      CheckEqual('env_app', LCfg.GetString('name'), 'env highest priority');
    finally
      LCfg.Free;
    end;
  finally
    UnsetEnv('APP_NAME');
  end;
end;

{ === Count Tests === }

procedure TestCount;
var
  LCfg: TConfig;
begin
  LCfg := TConfig.Create;
  try
    CheckEqual(Int64(0), Int64(LCfg.Count), 'initial');
    LCfg.LoadFromJson('{"a":"1","b":"2"}');
    CheckEqual(Int64(2), Int64(LCfg.Count), 'after json');
    LCfg.LoadFromIni('[s]' + #10 + 'c=3' + #10);
    CheckEqual(Int64(3), Int64(LCfg.Count), 'after ini');
  finally
    LCfg.Free;
  end;
end;

{ === Main === }

begin
  T := TTestRunner.Create('nextpas.core.config');
  T.Run('GetString.Basic', @TestGetStringBasic);
  T.Run('GetString.Default', @TestGetStringDefault);
  T.Run('GetString.CaseInsensitive', @TestGetStringCaseInsensitive);
  T.Run('GetInt.Basic', @TestGetIntBasic);
  T.Run('GetInt.Default', @TestGetIntDefault);
  T.Run('GetInt.Invalid', @TestGetIntInvalid);
  T.Run('GetBool.Basic', @TestGetBoolBasic);
  T.Run('GetBool.Default', @TestGetBoolDefault);
  T.Run('GetBool.Invalid', @TestGetBoolInvalid);
  T.Run('GetFloat.Basic', @TestGetFloatBasic);
  T.Run('GetFloat.Default', @TestGetFloatDefault);
  T.Run('GetFloat.Invalid', @TestGetFloatInvalid);
  T.Run('SetDefault', @TestSetDefault);
  T.Run('LoadFromIni.Sections', @TestLoadFromIniSections);
  T.Run('LoadFromIni.GlobalKeys', @TestLoadFromIniGlobalKeys);
  T.Run('LoadFromJson.Basic', @TestLoadFromJsonBasic);
  T.Run('LoadFromJson.Types', @TestLoadFromJsonTypes);
  T.Run('LoadFromEnv.Basic', @TestLoadFromEnvBasic);
  T.Run('LoadFromEnv.Override', @TestLoadFromEnvOverride);
  T.Run('Has', @TestHas);
  T.Run('GetKeys', @TestGetKeys);
  T.Run('EmptyConfig', @TestEmptyConfig);
  T.Run('Override.Priority', @TestOverridePriority);
  T.Run('Override.EnvHighest', @TestOverrideEnvHighest);
  T.Run('Count', @TestCount);
  T.Summary;
end.
