program test_marshal;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.reflect.base,
  nextpas.core.reflect,
  nextpas.core.reflect.marshal,
  nextpas.core.config,
  nextpas.core.testing;

type
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

var
  T: TTestRunner;

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
    ConfigUnmarshal(nil, LRegistry, LTypeID, @LServer);
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

begin
  T := TTestRunner.Create('nextpas.core.reflect.marshal');
  T.Run('unmarshal server config', @TestUnmarshalServerConfig);
  T.Run('missing fields keep existing values', @TestMissingFieldsKeepExistingValues);
  T.Run('empty config keeps zero values', @TestEmptyConfigKeepsZeroValues);
  T.Run('multiple record types', @TestMultipleRecordTypes);
  T.Run('invalid inputs do not crash', @TestInvalidInputsDoNotCrash);
  T.Summary;
end.
