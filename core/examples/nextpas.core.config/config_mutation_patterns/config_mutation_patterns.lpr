program config_mutation_patterns;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.config;

procedure Fail(const AMessage: string);
begin
  WriteLn('config-mutation-patterns-status=fail');
  WriteLn('error=', AMessage);
  Halt(1);
end;

procedure CheckEqual(const AExpected, AActual, ALabel: string);
begin
  if AExpected <> AActual then
    Fail(ALabel + ' expected="' + AExpected + '" actual="' + AActual + '"');
end;

procedure CheckEqualInt(AExpected, AActual: Int64; const ALabel: string);
begin
  if AExpected <> AActual then
    Fail(ALabel + ' expected/int mismatch');
end;

var
  LCfg: TConfig;
  LSource: TConfig;
  LTags: TStringArray;
  LRatio: Double;

begin
  WriteLn('config-mutation-patterns=ready');

  LCfg := TConfig.Create;
  try
    LCfg.SetString('server.host', '127.0.0.1');
    LCfg.SetInt('server.port', 8080);
    LCfg.SetBool('feature.enabled', True);
    LCfg.SetFloat('feature.ratio', 1.5);
    LCfg.SetString('service.url', 'http://${server.host}:${server.port}');
    LCfg.SetStringArray('tags', ['api', 'prod']);

    if not LCfg.GetBoolRequired('feature.enabled') then
      Fail('feature.enabled mismatch');
    LRatio := LCfg.GetFloatRequired('feature.ratio');
    if (LRatio < 1.4) or (LRatio > 1.6) then
      Fail('feature.ratio mismatch');

    CheckEqual('http://127.0.0.1:8080',
      LCfg.GetStringRequired('service.url'), 'service.url');
    CheckEqual('http://${server.host}:${server.port}',
      LCfg.GetRawString('service.url'), 'raw service.url');

    LTags := LCfg.GetStringArray('tags');
    CheckEqualInt(2, Length(LTags), 'tags count');
    CheckEqual('api', LTags[0], 'tags.0');
    CheckEqual('prod', LTags[1], 'tags.1');

    WriteLn('feature-enabled=pass');
    WriteLn('service-url=', LCfg.GetStringRequired('service.url'));
    WriteLn('raw-service-url=', LCfg.GetRawString('service.url'));
    WriteLn('tags-count=', Length(LTags));

    LCfg.SetString('server.temp', 'stale');
    LCfg.DeleteKey('server.temp');
    if LCfg.Has('server.temp') then
      Fail('DeleteKey did not remove server.temp');
    WriteLn('deletekey-removed=pass');

    LCfg.SetString('cache.host', 'redis.local');
    LCfg.SetInt('cache.port', 6379);
    LCfg.DeleteSection('cache');
    if LCfg.Has('cache.host') or LCfg.Has('cache.port') then
      Fail('DeleteSection did not remove cache section');
    WriteLn('deletesection-removed=pass');

    LSource := TConfig.Create;
    try
      LSource.SetString('server.host', 'worker.local');
      LSource.SetInt('server.port', 9090);
      LSource.SetString('service.url', 'http://${server.host}:${server.port}');
      LCfg.ReplaceFrom(LSource);
    finally
      LSource.Free;
    end;

    CheckEqual('worker.local', LCfg.GetStringRequired('server.host'),
      'replacefrom host');
    CheckEqualInt(9090, LCfg.GetIntRequired('server.port'),
      'replacefrom port');
    CheckEqual('http://worker.local:9090',
      LCfg.GetStringRequired('service.url'), 'replacefrom url');
    WriteLn('replacefrom-host=', LCfg.GetStringRequired('server.host'));

    LCfg.Clear;
    CheckEqualInt(0, LCfg.Count, 'clear count');
    if LCfg.Has('server.host') then
      Fail('Clear left server.host behind');
    WriteLn('clear-count=', LCfg.Count);
  finally
    LCfg.Free;
  end;

  WriteLn('config-mutation-patterns-status=pass');
end.
