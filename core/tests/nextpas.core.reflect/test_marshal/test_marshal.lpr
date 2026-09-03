program test_marshal;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.reflect.base,
  nextpas.core.reflect,
  nextpas.core.reflect.marshal,
  nextpas.core.config,
  nextpas.core.test;

type
  TStringDynArray = array of string;

  TServerConfig = record
    Host: string;
    Port: Int32;
    Debug: Boolean;
    Timeout: Double;
  end;

  TDatabaseConfig = record
    Name: string;
    MaxConnections: Int64;
  end;

  TAppConfig = record
    Name: string;
    Server: TServerConfig;
  end;

  TServiceConfig = record
    Name: string;
    Tags: TStringDynArray;
  end;

var
  T: TTestSuite;

function OffsetOfServerHost: PtrUInt;
var
  LRecord: TServerConfig;
begin
  Result := PtrUInt(@LRecord.Host) - PtrUInt(@LRecord);
end;

function OffsetOfServerPort: PtrUInt;
var
  LRecord: TServerConfig;
begin
  Result := PtrUInt(@LRecord.Port) - PtrUInt(@LRecord);
end;

function OffsetOfServerDebug: PtrUInt;
var
  LRecord: TServerConfig;
begin
  Result := PtrUInt(@LRecord.Debug) - PtrUInt(@LRecord);
end;

function OffsetOfServerTimeout: PtrUInt;
var
  LRecord: TServerConfig;
begin
  Result := PtrUInt(@LRecord.Timeout) - PtrUInt(@LRecord);
end;

function OffsetOfDatabaseName: PtrUInt;
var
  LRecord: TDatabaseConfig;
begin
  Result := PtrUInt(@LRecord.Name) - PtrUInt(@LRecord);
end;

function OffsetOfDatabaseMaxConnections: PtrUInt;
var
  LRecord: TDatabaseConfig;
begin
  Result := PtrUInt(@LRecord.MaxConnections) - PtrUInt(@LRecord);
end;

function RegisterServerConfig(ARegistry: ITypeRegistry): TTypeID;
begin
  Result := ARegistry.RegisterType('ServerConfig', SizeOf(TServerConfig));
  Check(ARegistry.AddField(Result, 'Host', OffsetOfServerHost, fkString), 'add Host');
  Check(ARegistry.AddField(Result, 'Port', OffsetOfServerPort, fkInt32), 'add Port');
  Check(ARegistry.AddField(Result, 'Debug', OffsetOfServerDebug, fkBool), 'add Debug');
  Check(ARegistry.AddField(Result, 'Timeout', OffsetOfServerTimeout, fkFloat64), 'add Timeout');
end;

function RegisterDatabaseConfig(ARegistry: ITypeRegistry): TTypeID;
begin
  Result := ARegistry.RegisterType('DatabaseConfig', SizeOf(TDatabaseConfig));
  Check(ARegistry.AddField(Result, 'Name', OffsetOfDatabaseName, fkString), 'add Name');
  Check(ARegistry.AddField(Result, 'MaxConnections', OffsetOfDatabaseMaxConnections, fkInt64), 'add MaxConnections');
end;

function OffsetOfAppName: PtrUInt;
var
  LRecord: TAppConfig;
begin
  Result := PtrUInt(@LRecord.Name) - PtrUInt(@LRecord);
end;

function OffsetOfAppServer: PtrUInt;
var
  LRecord: TAppConfig;
begin
  Result := PtrUInt(@LRecord.Server) - PtrUInt(@LRecord);
end;

function OffsetOfServiceName: PtrUInt;
var
  LRecord: TServiceConfig;
begin
  Result := PtrUInt(@LRecord.Name) - PtrUInt(@LRecord);
end;

function OffsetOfServiceTags: PtrUInt;
var
  LRecord: TServiceConfig;
begin
  Result := PtrUInt(@LRecord.Tags) - PtrUInt(@LRecord);
end;

function RegisterAppConfig(ARegistry: ITypeRegistry): TTypeID;
var
  LServerID: TTypeID;
begin
  LServerID := RegisterServerConfig(ARegistry);
  Result := ARegistry.RegisterType('AppConfig', SizeOf(TAppConfig));
  Check(ARegistry.AddField(Result, 'Name', OffsetOfAppName, fkString), 'add App.Name');
  Check(ARegistry.AddRecordField(Result, 'Server', OffsetOfAppServer, LServerID),
    'add App.Server record');
end;

function RegisterServiceConfig(ARegistry: ITypeRegistry): TTypeID;
begin
  Result := ARegistry.RegisterType('ServiceConfig', SizeOf(TServiceConfig));
  Check(ARegistry.AddField(Result, 'Name', OffsetOfServiceName, fkString), 'add Service.Name');
  Check(ARegistry.AddDynArrayField(Result, 'Tags', OffsetOfServiceTags, fkString,
    SizeOf(string), TypeInfo(TStringDynArray)), 'add Service.Tags');
end;

procedure PutConfigValue(AConfig: TConfig; const AKey, AValue: string);
begin
  AConfig.SetDefault(AKey, AValue);
end;

procedure TestUnmarshalServerConfig;
var
  LRegistry: ITypeRegistry;
  LTypeID: TTypeID;
  LConfig: TConfig;
  LServer: TServerConfig;
begin
  LRegistry := CreateTypeRegistry;
  LTypeID := RegisterServerConfig(LRegistry);
  LServer.Host := '';
  LServer.Port := 0;
  LServer.Debug := False;
  LServer.Timeout := 0.0;
  LConfig := TConfig.Create;
  try
    PutConfigValue(LConfig, 'Host', 'localhost');
    PutConfigValue(LConfig, 'Port', '8080');
    PutConfigValue(LConfig, 'Debug', 'true');
    PutConfigValue(LConfig, 'Timeout', '12.5');

    ConfigUnmarshal(LConfig, LRegistry, LTypeID, @LServer);

    CheckEqual('localhost', LServer.Host, 'Host');
    CheckEqual(Int64(8080), Int64(LServer.Port), 'Port');
    CheckEqual(True, LServer.Debug, 'Debug');
    Check((LServer.Timeout > 12.49) and (LServer.Timeout < 12.51), 'Timeout');
  finally
    LConfig.Free;
  end;
end;

procedure TestMissingFieldsKeepExistingValues;
var
  LRegistry: ITypeRegistry;
  LTypeID: TTypeID;
  LConfig: TConfig;
  LServer: TServerConfig;
begin
  LRegistry := CreateTypeRegistry;
  LTypeID := RegisterServerConfig(LRegistry);
  LServer.Host := 'existing';
  LServer.Port := 3000;
  LServer.Debug := True;
  LServer.Timeout := 2.5;
  LConfig := TConfig.Create;
  try
    PutConfigValue(LConfig, 'Port', '9090');

    ConfigUnmarshal(LConfig, LRegistry, LTypeID, @LServer);

    CheckEqual('existing', LServer.Host, 'missing Host stays');
    CheckEqual(Int64(9090), Int64(LServer.Port), 'present Port updates');
    CheckEqual(True, LServer.Debug, 'missing Debug stays');
    Check((LServer.Timeout > 2.49) and (LServer.Timeout < 2.51), 'missing Timeout stays');
  finally
    LConfig.Free;
  end;
end;

procedure TestEmptyConfigKeepsZeroValues;
var
  LRegistry: ITypeRegistry;
  LTypeID: TTypeID;
  LConfig: TConfig;
  LServer: TServerConfig;
begin
  LRegistry := CreateTypeRegistry;
  LTypeID := RegisterServerConfig(LRegistry);
  LServer.Host := '';
  LServer.Port := 0;
  LServer.Debug := False;
  LServer.Timeout := 0.0;
  LConfig := TConfig.Create;
  try
    ConfigUnmarshal(LConfig, LRegistry, LTypeID, @LServer);

    CheckEqual('', LServer.Host, 'Host zero');
    CheckEqual(Int64(0), Int64(LServer.Port), 'Port zero');
    CheckEqual(False, LServer.Debug, 'Debug zero');
    Check((LServer.Timeout > -0.01) and (LServer.Timeout < 0.01), 'Timeout zero');
  finally
    LConfig.Free;
  end;
end;

procedure TestMultipleRecordTypes;
var
  LRegistry: ITypeRegistry;
  LServerTypeID, LDatabaseTypeID: TTypeID;
  LConfig: TConfig;
  LServer: TServerConfig;
  LDatabase: TDatabaseConfig;
begin
  LRegistry := CreateTypeRegistry;
  LServerTypeID := RegisterServerConfig(LRegistry);
  LDatabaseTypeID := RegisterDatabaseConfig(LRegistry);
  LServer.Host := '';
  LServer.Port := 0;
  LServer.Debug := False;
  LServer.Timeout := 0.0;
  LDatabase.Name := '';
  LDatabase.MaxConnections := 0;
  LConfig := TConfig.Create;
  try
    PutConfigValue(LConfig, 'Host', 'api.local');
    PutConfigValue(LConfig, 'Port', '7001');
    PutConfigValue(LConfig, 'Name', 'main');
    PutConfigValue(LConfig, 'MaxConnections', '1024');

    ConfigUnmarshal(LConfig, LRegistry, LServerTypeID, @LServer);
    ConfigUnmarshal(LConfig, LRegistry, LDatabaseTypeID, @LDatabase);

    CheckEqual('api.local', LServer.Host, 'server Host');
    CheckEqual(Int64(7001), Int64(LServer.Port), 'server Port');
    CheckEqual('main', LDatabase.Name, 'database Name');
    CheckEqual(Int64(1024), LDatabase.MaxConnections, 'database MaxConnections');
  finally
    LConfig.Free;
  end;
end;

procedure TestInvalidInputsDoNotCrash;
var
  LRegistry: ITypeRegistry;
  LTypeID: TTypeID;
  LConfig: TConfig;
  LServer: TServerConfig;
begin
  LRegistry := CreateTypeRegistry;
  LTypeID := RegisterServerConfig(LRegistry);
  LServer.Host := 'stable';
  LServer.Port := 42;
  LServer.Debug := True;
  LServer.Timeout := 1.25;
  LConfig := TConfig.Create;
  try
    ConfigUnmarshal(TConfig(nil), LRegistry, LTypeID, @LServer);
    ConfigUnmarshal(LConfig, nil, LTypeID, @LServer);
    ConfigUnmarshal(LConfig, LRegistry, 0, @LServer);
    ConfigUnmarshal(LConfig, LRegistry, LTypeID, nil);

    CheckEqual('stable', LServer.Host, 'Host unchanged');
    CheckEqual(Int64(42), Int64(LServer.Port), 'Port unchanged');
    CheckEqual(True, LServer.Debug, 'Debug unchanged');
    Check((LServer.Timeout > 1.24) and (LServer.Timeout < 1.26), 'Timeout unchanged');
  finally
    LConfig.Free;
  end;
end;

procedure TestUnmarshalFromIConfig;
var
  LRegistry: ITypeRegistry;
  LTypeID: TTypeID;
  LSnapshot: IConfig;
  LServer: TServerConfig;
begin
  LRegistry := CreateTypeRegistry;
  LTypeID := RegisterServerConfig(LRegistry);
  LServer.Host := '';
  LServer.Port := 0;
  LServer.Debug := False;
  LServer.Timeout := 0.0;

  LSnapshot := ConfigBuilder
    .AddJson('{"Host":"from-builder","Port":4242,"Debug":true,"Timeout":3.5}')
    .Build;

  ConfigUnmarshal(LSnapshot, LRegistry, LTypeID, @LServer);

  CheckEqual('from-builder', LServer.Host, 'IConfig Host');
  CheckEqual(Int64(4242), Int64(LServer.Port), 'IConfig Port');
  CheckEqual(True, LServer.Debug, 'IConfig Debug');
  Check((LServer.Timeout > 3.49) and (LServer.Timeout < 3.51), 'IConfig Timeout');
end;

procedure TestUnmarshalWithSectionPrefix;
var
  LRegistry: ITypeRegistry;
  LTypeID: TTypeID;
  LConfig: TConfig;
  LServer: TServerConfig;
begin
  LRegistry := CreateTypeRegistry;
  LTypeID := RegisterServerConfig(LRegistry);
  LServer.Host := '';
  LServer.Port := 0;
  LServer.Debug := False;
  LServer.Timeout := 0.0;
  LConfig := TConfig.Create;
  try
    LConfig.LoadFromJson(
      '{"server":{"Host":"prefixed","Port":9000,"Debug":false,"Timeout":1.0}}');
    { Flat keys after load: server.Host, server.Port, ... case-insensitive. }
    ConfigUnmarshal(LConfig, LRegistry, LTypeID, @LServer, 'server');

    CheckEqual('prefixed', LServer.Host, 'prefix Host');
    CheckEqual(Int64(9000), Int64(LServer.Port), 'prefix Port');
    CheckEqual(False, LServer.Debug, 'prefix Debug');
    Check((LServer.Timeout > 0.99) and (LServer.Timeout < 1.01), 'prefix Timeout');

    { Trailing dot on prefix is accepted. }
    LServer.Host := '';
    ConfigUnmarshal(LConfig, LRegistry, LTypeID, @LServer, 'server.');
    CheckEqual('prefixed', LServer.Host, 'prefix Host with trailing dot');
  finally
    LConfig.Free;
  end;
end;

procedure TestUnmarshalNestedRecord;
var
  LRegistry: ITypeRegistry;
  LTypeID: TTypeID;
  LSnapshot: IConfig;
  LApp: TAppConfig;
begin
  LRegistry := CreateTypeRegistry;
  LTypeID := RegisterAppConfig(LRegistry);
  LApp.Name := '';
  LApp.Server.Host := 'keep-me';
  LApp.Server.Port := 1;
  LApp.Server.Debug := True;
  LApp.Server.Timeout := 9.0;

  LSnapshot := ConfigBuilder
    .AddJson('{"Name":"my-app","server":{"Host":"nested-host","Port":7777}}')
    .Build;

  ConfigUnmarshal(LSnapshot, LRegistry, LTypeID, @LApp);

  CheckEqual('my-app', LApp.Name, 'nested app Name');
  CheckEqual('nested-host', LApp.Server.Host, 'nested Server.Host');
  CheckEqual(Int64(7777), Int64(LApp.Server.Port), 'nested Server.Port');
  { Missing nested leaves keep prior values. }
  CheckEqual(True, LApp.Server.Debug, 'nested Server.Debug kept');
  Check((LApp.Server.Timeout > 8.99) and (LApp.Server.Timeout < 9.01),
    'nested Server.Timeout kept');
end;

procedure TestUnmarshalStringArray;
var
  LRegistry: ITypeRegistry;
  LTypeID: TTypeID;
  LConfig: TConfig;
  LService: TServiceConfig;
begin
  LRegistry := CreateTypeRegistry;
  LTypeID := RegisterServiceConfig(LRegistry);
  LService.Name := '';
  LService.Tags := nil;
  LConfig := TConfig.Create;
  try
    LConfig.SetString('Name', 'svc');
    LConfig.SetStringArray('Tags', ['alpha', 'beta', 'gamma']);
    ConfigUnmarshal(LConfig, LRegistry, LTypeID, @LService);

    CheckEqual('svc', LService.Name, 'service Name');
    CheckEqual(Int64(3), Int64(Length(LService.Tags)), 'tags length');
    CheckEqual('alpha', LService.Tags[0], 'tags[0]');
    CheckEqual('beta', LService.Tags[1], 'tags[1]');
    CheckEqual('gamma', LService.Tags[2], 'tags[2]');
  finally
    LConfig.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.reflect.marshal');
  T.Test('unmarshal server config', @TestUnmarshalServerConfig);
  T.Test('missing fields keep existing values', @TestMissingFieldsKeepExistingValues);
  T.Test('empty config keeps zero values', @TestEmptyConfigKeepsZeroValues);
  T.Test('multiple record types', @TestMultipleRecordTypes);
  T.Test('invalid inputs do not crash', @TestInvalidInputsDoNotCrash);
  T.Test('unmarshal from IConfig snapshot', @TestUnmarshalFromIConfig);
  T.Test('unmarshal with section prefix', @TestUnmarshalWithSectionPrefix);
  T.Test('unmarshal nested record', @TestUnmarshalNestedRecord);
  T.Test('unmarshal string array', @TestUnmarshalStringArray);
  if not T.Run then Halt(1);
end.
