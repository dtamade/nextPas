program config_startup_patterns;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.config;

procedure Fail(const AMessage: string);
begin
  WriteLn('config-startup-patterns-status=fail');
  WriteLn('error=', AMessage);
  Halt(1);
end;

var
  LSnapshot: IConfig;
  LLoaded: IConfig;
  LTryConfig: IConfig;
  LMutable: TConfig;
  LDirect: TConfig;
  LError: string;

begin
  WriteLn('config-startup-patterns=ready');

  LSnapshot := ConfigBuilder
    .AddDefault('server.port', '8080')
    .AddFile('app.toml', cfToml)
    .RequireKeys(['server.host', 'server.port', 'service.url'])
    .Build;

  if LSnapshot.GetStringRequired('server.host') <> '127.0.0.1' then
    Fail('snapshot host mismatch');
  if LSnapshot.GetIntRequired('server.port') <> 8080 then
    Fail('snapshot default port mismatch');
  if LSnapshot.GetStringRequired('service.url') <> 'http://127.0.0.1:8080' then
    Fail('snapshot interpolated url mismatch');
  WriteLn('snapshot-host=', LSnapshot.GetStringRequired('server.host'));
  WriteLn('snapshot-port=', LSnapshot.GetIntRequired('server.port'));
  WriteLn('snapshot-url=', LSnapshot.GetStringRequired('service.url'));

  LLoaded := ConfigLoad('app.toml', cfToml);
  if LLoaded.GetStringRequired('server.host') <> '127.0.0.1' then
    Fail('ConfigLoad host mismatch');
  WriteLn('configload-host=', LLoaded.GetStringRequired('server.host'));

  LDirect := TConfig.Create;
  try
    LDirect.LoadFromFile('app.toml', cfToml);
    if LDirect.GetStringRequired('server.host') <> '127.0.0.1' then
      Fail('LoadFromFile host mismatch');
    WriteLn('loadfromfile-host=', LDirect.GetStringRequired('server.host'));
  finally
    LDirect.Free;
  end;

  LError := '';
  if not ConfigBuilder
    .AddDefault('server.port', '8080')
    .AddFile('app.toml', cfToml)
    .RequireKeys(['server.host', 'server.port'])
    .TryBuild(LTryConfig, LError) then
    Fail('TryBuild failed on valid config: ' + LError);
  if LTryConfig = nil then
    Fail('TryBuild returned nil config on success');
  WriteLn('trybuild-valid=pass');

  LTryConfig := nil;
  LError := '';
  if ConfigBuilder.AddFile('broken.toml', cfToml).TryBuild(LTryConfig, LError) then
    Fail('TryBuild unexpectedly succeeded on broken.toml');
  if LTryConfig <> nil then
    Fail('TryBuild returned config on broken.toml');
  if LError = '' then
    Fail('TryBuild returned empty error for broken.toml');
  if Pos('broken.toml', LError) = 0 then
    Fail('TryBuild error did not include broken.toml');
  WriteLn('trybuild-invalid=pass');

  LMutable := ConfigBuilder
    .AddDefault('server.port', '8080')
    .AddFile('app.toml', cfToml)
    .BuildConfig;
  try
    LMutable.LoadFromToml('[server]' + #10 + 'port = 9090' + #10);
    if LMutable.GetIntRequired('server.port') <> 9090 then
      Fail('mutable config did not update server.port');
    if LSnapshot.GetIntRequired('server.port') <> 8080 then
      Fail('snapshot changed after mutable update');
    WriteLn('mutable-port=', LMutable.GetIntRequired('server.port'));
    WriteLn('snapshot-still-port=', LSnapshot.GetIntRequired('server.port'));
  finally
    LMutable.Free;
  end;

  WriteLn('config-startup-patterns-status=pass');
end.
