program test_config_args;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.args,
  nextpas.core.config,
  nextpas.core.config.args,
  nextpas.core.errors,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestPresentArgsOverrideDefaults;
var
  LParser: TArgParser;
  LCfg: IConfig;
begin
  LParser := TArgParser.Create('test', '');
  try
    LParser.SetAutoHelp(False);
    LParser.AddString('host', #0, 'server host', 'default-cli');
    LParser.AddInt('port', #0, 'port', 1);
    LParser.AddFlag('debug', #0, 'debug flag');
    Check(LParser.TryParseFrom(['--host', 'cli-host', '--port', '9090', '--debug']),
      'parse ok');

    LCfg := ConfigBuilderAddPresentArgs(
      ConfigBuilder
        .AddDefault('server.host', 'file-host')
        .AddDefault('server.port', '80')
        .AddDefault('server.debug', 'false'),
      LParser,
      ['host', 'port', 'debug'],
      ['server.host', 'server.port', 'server.debug'],
      [cavString, cavInt, cavBool])
      .Build;

    CheckEqual('cli-host', LCfg.GetString('server.host'), 'host override');
    CheckEqual(Int64(9090), LCfg.GetInt('server.port'), 'port override');
    CheckEqual(True, LCfg.GetBool('server.debug'), 'debug override');
  finally
    LParser.Free;
  end;
end;

procedure TestAbsentArgsLeaveDefaults;
var
  LParser: TArgParser;
  LCfg: IConfig;
begin
  LParser := TArgParser.Create('test', '');
  try
    LParser.SetAutoHelp(False);
    LParser.AddString('host', #0, 'server host', 'unused');
    Check(LParser.TryParseFrom([]), 'parse empty');

    LCfg := ConfigBuilderAddPresentArgs(
      ConfigBuilder.AddDefault('server.host', 'kept'),
      LParser,
      ['host'],
      ['server.host'],
      [cavString])
      .Build;

    CheckEqual('kept', LCfg.GetString('server.host'), 'absent leaves default');
  finally
    LParser.Free;
  end;
end;

procedure TestLengthMismatchRaises;
var
  LParser: TArgParser;
  LRaised: Boolean;
  LKeys, LValues: TStringArray;
begin
  LParser := TArgParser.Create('test', '');
  try
    LParser.SetAutoHelp(False);
    LRaised := False;
    try
      ConfigCollectPresentArgs(LParser, ['a'], ['k1', 'k2'], [cavString],
        LKeys, LValues);
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'collect length mismatch raises');

    LRaised := False;
    try
      ConfigBuilderAddPresentArgs(ConfigBuilder, LParser,
        ['a'], ['k1', 'k2'], [cavString]);
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'builder length mismatch raises');
  finally
    LParser.Free;
  end;
end;

procedure TestBorrowSeesLiveMutations;
var
  LCfg: TConfig;
  LView: IConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('name', 'one');
    LView := ConfigBorrow(LCfg);
    CheckEqual('one', LView.GetString('name'), 'borrow initial');
    LCfg.SetString('name', 'two');
    CheckEqual('two', LView.GetString('name'), 'borrow sees mutation');
    LView := nil;
    CheckEqual('two', LCfg.GetString('name'), 'config survives borrow release');
  finally
    LCfg.Free;
  end;
end;

procedure TestInterpolationModes;
var
  LCfg: TConfig;
  LRaised: Boolean;
  LSnap: IConfig;
begin
  LCfg := TConfig.Create;
  try
    LCfg.SetString('url', 'http://${missing}');
    CheckEqual('http://${missing}', LCfg.GetString('url'),
      'default leaves unresolved');

    LCfg.SetInterpolationMode(cimDisabled);
    CheckEqual('http://${missing}', LCfg.GetString('url'),
      'disabled returns raw');

    LCfg.SetInterpolationMode(cimStrict);
    LRaised := False;
    try
      LCfg.GetString('url');
    except
      on E: EConfigError do
        LRaised := True;
    end;
    CheckEqual(True, LRaised, 'strict fails unresolved');
  finally
    LCfg.Free;
  end;

  LSnap := ConfigBuilder
    .AddDefault('url', 'http://${x}')
    .SetInterpolationMode(cimDisabled)
    .Build;
  CheckEqual('http://${x}', LSnap.GetString('url'), 'builder disabled mode');
  Check(LSnap.GetInterpolationMode = cimDisabled, 'mode visible on IConfig');
end;

begin
  T := TTestSuite.Create('nextpas.core.config.args');
  T.Test('present args override defaults', @TestPresentArgsOverrideDefaults);
  T.Test('absent args leave defaults', @TestAbsentArgsLeaveDefaults);
  T.Test('length mismatch raises', @TestLengthMismatchRaises);
  T.Test('borrow sees live mutations', @TestBorrowSeesLiveMutations);
  T.Test('interpolation modes', @TestInterpolationModes);
  if not T.Run then Halt(1);
end.
