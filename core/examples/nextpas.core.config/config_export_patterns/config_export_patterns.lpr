program config_export_patterns;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.config,
  nextpas.core.errors,
  nextpas.core.fs;

procedure Fail(const AMessage: string);
begin
  WriteLn('config-export-patterns-status=fail');
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

procedure CheckStringArray(const AValues: TStringArray; const ALabel: string);
begin
  if Length(AValues) <> 2 then
    Fail(ALabel + ' array length mismatch');
  CheckEqual('api', AValues[0], ALabel + ' item0');
  CheckEqual('prod', AValues[1], ALabel + ' item1');
end;

procedure VerifyReload(const APath: string; AFormat: TConfigFormat;
  const AMarker: string);
var
  LLoaded: IConfig;
begin
  LLoaded := ConfigLoad(APath, AFormat);
  CheckEqual('nextpas', LLoaded.GetStringRequired('app.name'),
    AMarker + ' app.name');
  CheckEqualInt(8080, LLoaded.GetIntRequired('app.port'),
    AMarker + ' app.port');
  CheckEqual('true', LLoaded.GetRawString('feature.enabled'),
    AMarker + ' feature.enabled');
  CheckEqual('http://${app.name}:${app.port}',
    LLoaded.GetRawString('service.url'),
    AMarker + ' raw url');
  CheckEqual('http://nextpas:8080', LLoaded.GetStringRequired('service.url'),
    AMarker + ' interpolated url');
  CheckStringArray(LLoaded.GetStringArray('tags'), AMarker + ' tags');
  WriteLn(AMarker, '=pass');
end;

var
  LMutable: TConfig;
  LSnapshot: IConfig;
  LReject: TConfig;
  LIniPath: string;
  LJsonPath: string;
  LYamlPath: string;
  LTomlPath: string;
  LRaised: Boolean;

begin
  WriteLn('config-export-patterns=ready');

  LIniPath := 'app.snapshot.ini';
  LJsonPath := 'app.snapshot.json';
  LYamlPath := 'app.snapshot.yaml';
  LTomlPath := 'app.snapshot.toml';
  Remove(LIniPath);
  Remove(LJsonPath);
  Remove(LYamlPath);
  Remove(LTomlPath);

  LMutable := TConfig.Create;
  try
    LMutable.SetString('app.name', 'nextpas');
    LMutable.SetInt('app.port', 8080);
    LMutable.SetBool('feature.enabled', True);
    LMutable.SetString('service.url', 'http://${app.name}:${app.port}');
    LMutable.SetStringArray('tags', ['api', 'prod']);

    LSnapshot := ConfigBuilder
      .AddDefault('app.name', 'nextpas')
      .AddDefault('app.port', '8080')
      .AddDefault('feature.enabled', 'true')
      .AddDefault('service.url', 'http://${app.name}:${app.port}')
      .AddDefault('tags.0', 'api')
      .AddDefault('tags.1', 'prod')
      .Build;
    if LSnapshot.ToIni = '' then
      Fail('snapshot ini export empty');
    WriteLn('snapshot-ini-export=pass');

    LMutable.SaveToIni(LIniPath);
    LMutable.SaveToJson(LJsonPath);
    LMutable.SaveToYaml(LYamlPath);
    LMutable.SaveToToml(LTomlPath);

    VerifyReload(LIniPath, cfIni, 'ini-save-reload');
    VerifyReload(LJsonPath, cfJson, 'json-save-reload');
    VerifyReload(LYamlPath, cfYaml, 'yaml-save-reload');
    VerifyReload(LTomlPath, cfToml, 'toml-save-reload');
  finally
    LMutable.Free;
  end;

  LReject := TConfig.Create;
  try
    LReject.SetString('special.leading', '  two spaces');
    LRaised := False;
    try
      LReject.ToIni;
    except
      on E: EConfigError do
        LRaised := Pos('special.leading', E.Message) > 0;
    end;
    if not LRaised then
      Fail('expected ini leading-space rejection');
    WriteLn('ini-leading-space-reject=pass');
  finally
    LReject.Free;
  end;

  Remove(LIniPath);
  Remove(LJsonPath);
  Remove(LYamlPath);
  Remove(LTomlPath);
  WriteLn('config-export-patterns-status=pass');
end.
