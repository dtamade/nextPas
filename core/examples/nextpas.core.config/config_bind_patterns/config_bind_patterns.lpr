program config_bind_patterns;

{$I nextpas.core.settings.inc}

uses
  TypInfo,
  nextpas.core.reflect.base,
  nextpas.core.reflect,
  nextpas.core.reflect.marshal,
  nextpas.core.config;

type
  TStringDynArray = array of string;

  TServerConfig = record
    Host: string;
    Port: Int32;
  end;

  TAppConfig = record
    Name: string;
    Server: TServerConfig;
    Tags: TStringDynArray;
  end;

procedure Fail(const AMessage: string);
begin
  WriteLn('config-bind-patterns-status=fail');
  WriteLn('error=', AMessage);
  Halt(1);
end;

function OffsetOf(const ABase, AField: Pointer): PtrUInt;
begin
  Result := PtrUInt(AField) - PtrUInt(ABase);
end;

var
  LRegistry: ITypeRegistry;
  LServerID, LAppID: TTypeID;
  LCfg: IConfig;
  LApp: TAppConfig;
  LProbe: TAppConfig;

begin
  WriteLn('config-bind-patterns=ready');

  LRegistry := CreateTypeRegistry;
  LServerID := LRegistry.RegisterType('ServerConfig', SizeOf(TServerConfig));
  if not LRegistry.AddField(LServerID, 'Host',
    OffsetOf(@LProbe.Server, @LProbe.Server.Host), fkString) then
    Fail('register Host');
  if not LRegistry.AddField(LServerID, 'Port',
    OffsetOf(@LProbe.Server, @LProbe.Server.Port), fkInt32) then
    Fail('register Port');

  LAppID := LRegistry.RegisterType('AppConfig', SizeOf(TAppConfig));
  if not LRegistry.AddField(LAppID, 'Name',
    OffsetOf(@LProbe, @LProbe.Name), fkString) then
    Fail('register Name');
  if not LRegistry.AddRecordField(LAppID, 'Server',
    OffsetOf(@LProbe, @LProbe.Server), LServerID) then
    Fail('register Server');
  if not LRegistry.AddDynArrayField(LAppID, 'Tags',
    OffsetOf(@LProbe, @LProbe.Tags), fkString, SizeOf(string),
    TypeInfo(TStringDynArray)) then
    Fail('register Tags');

  LCfg := ConfigBuilder
    .AddJson('{"Name":"demo-app","server":{"Host":"127.0.0.1","Port":8080},' +
      '"Tags":["api","prod"]}')
    .Build;

  FillChar(LApp, SizeOf(LApp), 0);
  ConfigUnmarshal(LCfg, LRegistry, LAppID, @LApp);

  if LApp.Name <> 'demo-app' then
    Fail('Name mismatch');
  if LApp.Server.Host <> '127.0.0.1' then
    Fail('Server.Host mismatch');
  if LApp.Server.Port <> 8080 then
    Fail('Server.Port mismatch');
  if Length(LApp.Tags) <> 2 then
    Fail('Tags length mismatch');
  if LApp.Tags[0] <> 'api' then
    Fail('Tags[0] mismatch');

  WriteLn('app-name=', LApp.Name);
  WriteLn('server-host=', LApp.Server.Host);
  WriteLn('server-port=', LApp.Server.Port);
  WriteLn('tags-count=', Length(LApp.Tags));
  WriteLn('config-bind-patterns-status=pass');
end.
