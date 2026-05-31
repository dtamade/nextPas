program test_context_builder_try;

{$mode objfpc}{$H+}

{**
 * 测试 SSL Context Builder 的 Try* 方法
 * 验证 TryBuildClient 和 TryBuildServer 在成功和失败场景下的行为
 *}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.pkcs11.types,
  nextpas.core.tls.freepascal.context.material,
  nextpas.core.tls.freepascal.lib;

type
  IInspectableBuilderMaterialContext = interface
    ['{7B588BE0-06B4-4C75-91BB-9E3F3DCBA6F9}']
    function GetLoadedCertificateFile: string;
    function GetLoadedPrivateKeyFile: string;
    function GetLoadedPrivateKeyPassword: string;
    function GetLoadedCAFile: string;
    function GetLoadedCAPath: string;
  end;

  TMockBuilderContextBase = class(TInterfacedObject, ISSLContext)
  private
    FContextType: TSSLContextType;
    FProtocolVersions: TSSLProtocolVersions;
    FPreferredVersion: TSSLProtocolVersion;
    FVerifyMode: TSSLVerifyModes;
    FVerifyDepth: Integer;
    FCipherList: string;
    FCipherSuites: string;
    FSessionCacheMode: Boolean;
    FSessionTimeout: Integer;
    FSessionCacheSize: Integer;
    FOptions: TSSLOptions;
    FServerName: string;
    FALPNProtocols: string;
    FCertVerifyFlags: TSSLCertVerifyFlags;
    FLoadedCertificateFile: string;
    FLoadedPrivateKeyFile: string;
    FLoadedPrivateKeyPassword: string;
    FLoadedCAFile: string;
    FLoadedCAPath: string;
  public
    constructor Create(AContextType: TSSLContextType);

    function GetContextType: TSSLContextType;
    procedure SetProtocolVersions(AVersions: TSSLProtocolVersions);
    function GetProtocolVersions: TSSLProtocolVersions;
    procedure SetPreferredVersion(AVersion: TSSLProtocolVersion);
    function GetPreferredVersion: TSSLProtocolVersion;

    procedure LoadCertificate(const AFileName: string); overload;
    procedure LoadCertificate(AStream: TStream); overload;
    procedure LoadCertificate(ACert: ISSLCertificate); overload;

    procedure LoadPrivateKey(const AFileName: string; const APassword: string = ''); overload;
    procedure LoadPrivateKey(AStream: TStream; const APassword: string = ''); overload;

    procedure LoadCertificatePEM(const APEM: string);
    procedure LoadPrivateKeyPEM(const APEM: string; const APassword: string = '');

    procedure LoadCAFile(const AFileName: string);
    procedure LoadCAPath(const APath: string);

    procedure SetCertificateStore(AStore: ISSLCertificateStore);

    procedure SetVerifyMode(AMode: TSSLVerifyModes);
    function GetVerifyMode: TSSLVerifyModes;
    procedure SetVerifyDepth(ADepth: Integer);
    function GetVerifyDepth: Integer;
    procedure SetVerifyCallback(ACallback: TSSLVerifyCallback);

    procedure SetCipherList(const ACipherList: string);
    function GetCipherList: string;
    procedure SetCipherSuites(const ACipherSuites: string);
    function GetCipherSuites: string;

    procedure SetSessionCacheMode(AEnabled: Boolean);
    function GetSessionCacheMode: Boolean;
    procedure SetSessionTimeout(ATimeout: Integer);
    function GetSessionTimeout: Integer;
    procedure SetSessionCacheSize(ASize: Integer);
    function GetSessionCacheSize: Integer;

    procedure SetOptions(const AOptions: TSSLOptions);
    function GetOptions: TSSLOptions;

    procedure SetServerName(const AServerName: string);
    function GetServerName: string;

    procedure SetALPNProtocols(const AProtocols: string);
    function GetALPNProtocols: string;

    procedure SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
    function GetCertVerifyFlags: TSSLCertVerifyFlags;

    procedure SetPasswordCallback(ACallback: TSSLPasswordCallback);
    procedure SetInfoCallback(ACallback: TSSLInfoCallback);

    procedure AddCertificatePin(const AHash: TBytes; APinType: Integer;
      const ADescription: string; AIsBackup: Boolean = False);
    procedure AddCertificatePinBase64(const ABase64Hash: string; APinType: Integer;
      const ADescription: string; AIsBackup: Boolean = False);
    procedure SetCertificatePinningEnabled(AEnabled: Boolean);
    function GetCertificatePinningEnabled: Boolean;
    procedure ClearCertificatePins;

    function CreateConnection(ASocket: THandle): ISSLConnection; overload;
    function CreateConnection(AStream: TStream): ISSLConnection; overload;
    function IsValid: Boolean;
  end;

  TMockBuilderContextNoInstaller = class(TMockBuilderContextBase,
    IInspectableBuilderMaterialContext)
  public
    function GetLoadedCertificateFile: string;
    function GetLoadedPrivateKeyFile: string;
    function GetLoadedPrivateKeyPassword: string;
    function GetLoadedCAFile: string;
    function GetLoadedCAPath: string;
  end;

  TMockBuilderContextFailingInstaller = class(TMockBuilderContextBase,
    IFreePascalContextEarlyDataReplayInstaller,
    IFreePascalContextEarlyDataReplayDirectoryInstaller)
  public
    function InstallFileBackedReplayLedger(const AFileName: string): Boolean;
    function InstallDirectoryBackedReplayLedger(const ADirectoryName: string): Boolean;
  end;

  TMockBuilderLibraryBase = class(TInterfacedObject, ISSLLibrary)
  private
    FDefaultConfig: TSSLConfig;
  public
    constructor Create;

    function Initialize: Boolean; virtual;
    procedure Finalize;
    function IsInitialized: Boolean; virtual;

    function GetLibraryType: TSSLLibraryType; virtual;
    function GetVersionString: string; virtual;
    function GetVersionNumber: Cardinal;
    function GetCompileFlags: string;

    function IsProtocolSupported(aProtocol: TSSLProtocolVersion): Boolean;
    function IsCipherSupported(const aCipherName: string): Boolean;
    function IsFeatureSupported(aFeature: TSSLFeature): Boolean;
    function GetCapabilities: TSSLBackendCapabilities;

    procedure SetDefaultConfig(const aConfig: TSSLConfig);
    function GetDefaultConfig: TSSLConfig;

    function GetLastError: Integer;
    function GetLastErrorString: string;
    procedure ClearError;

    function GetStatistics: TSSLStatistics;
    procedure ResetStatistics;

    procedure SetLogCallback(aCallback: TSSLLogCallback);
    procedure Log(aLevel: TSSLLogLevel; const aMessage: string);

    function CreateContext(aType: TSSLContextType): ISSLContext; virtual;
    function CreateCertificate: ISSLCertificate;
    function CreateCertificateStore: ISSLCertificateStore;
  end;

  TMockBuilderLibraryNoInstaller = class(TMockBuilderLibraryBase)
  public
    function GetLibraryType: TSSLLibraryType; override;
    function GetVersionString: string; override;
    function CreateContext(aType: TSSLContextType): ISSLContext; override;
  end;

  TMockBuilderLibraryFailingInstaller = class(TMockBuilderLibraryBase)
  public
    function GetLibraryType: TSSLLibraryType; override;
    function GetVersionString: string; override;
    function CreateContext(aType: TSSLContextType): ISSLContext; override;
  end;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

function CreateRuntimeBuilder: ISSLContextBuilder;
begin
  Result := TSSLContextBuilder.Create.WithBackend(sslFreePascal);
end;

function CreateSafeRuntimeBuilder: ISSLContextBuilder;
begin
  Result := TSSLContextBuilder.CreateWithSafeDefaults.WithBackend(sslFreePascal);
end;

const
  SOFTHSM_MODULE_PATH = '/usr/lib/softhsm/libsofthsm2.so';

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ ', AMessage);
  end;
end;

constructor TMockBuilderContextBase.Create(AContextType: TSSLContextType);
begin
  inherited Create;
  FContextType := AContextType;
  FProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  FPreferredVersion := sslProtocolUnknown;
  FVerifyMode := [];
  FVerifyDepth := 0;
  FCipherList := '';
  FCipherSuites := '';
  FSessionCacheMode := False;
  FSessionTimeout := 0;
  FSessionCacheSize := 0;
  FOptions := [];
  FServerName := '';
  FALPNProtocols := '';
  FCertVerifyFlags := [];
  FLoadedCertificateFile := '';
  FLoadedPrivateKeyFile := '';
  FLoadedPrivateKeyPassword := '';
  FLoadedCAFile := '';
  FLoadedCAPath := '';
end;

function TMockBuilderContextBase.GetContextType: TSSLContextType;
begin
  Result := FContextType;
end;

procedure TMockBuilderContextBase.SetProtocolVersions(AVersions: TSSLProtocolVersions);
begin
  FProtocolVersions := AVersions;
end;

function TMockBuilderContextBase.GetProtocolVersions: TSSLProtocolVersions;
begin
  Result := FProtocolVersions;
end;

procedure TMockBuilderContextBase.SetPreferredVersion(AVersion: TSSLProtocolVersion);
begin
  FPreferredVersion := AVersion;
end;

function TMockBuilderContextBase.GetPreferredVersion: TSSLProtocolVersion;
begin
  Result := FPreferredVersion;
end;

procedure TMockBuilderContextBase.LoadCertificate(const AFileName: string);
begin
  if AFileName = 'missing-before-private-key-check.pem' then
    raise Exception.Create('certificate material should not load before server private-key validation');
  FLoadedCertificateFile := AFileName;
end;

procedure TMockBuilderContextBase.LoadCertificate(AStream: TStream);
begin
  if AStream <> nil then;
end;

procedure TMockBuilderContextBase.LoadCertificate(ACert: ISSLCertificate);
begin
  if ACert <> nil then;
end;

procedure TMockBuilderContextBase.LoadPrivateKey(const AFileName: string; const APassword: string);
begin
  FLoadedPrivateKeyFile := AFileName;
  FLoadedPrivateKeyPassword := APassword;
end;

procedure TMockBuilderContextBase.LoadPrivateKey(AStream: TStream; const APassword: string);
begin
  if (AStream <> nil) and (APassword = '') then;
end;

procedure TMockBuilderContextBase.LoadCertificatePEM(const APEM: string);
begin
  if APEM = '' then;
end;

procedure TMockBuilderContextBase.LoadPrivateKeyPEM(const APEM: string; const APassword: string);
begin
  if (APEM = '') and (APassword = '') then;
end;

procedure TMockBuilderContextBase.LoadCAFile(const AFileName: string);
begin
  FLoadedCAFile := AFileName;
end;

procedure TMockBuilderContextBase.LoadCAPath(const APath: string);
begin
  FLoadedCAPath := APath;
end;

procedure TMockBuilderContextBase.SetCertificateStore(AStore: ISSLCertificateStore);
begin
  if AStore <> nil then;
end;

function TMockBuilderContextNoInstaller.GetLoadedCertificateFile: string;
begin
  Result := FLoadedCertificateFile;
end;

function TMockBuilderContextNoInstaller.GetLoadedPrivateKeyFile: string;
begin
  Result := FLoadedPrivateKeyFile;
end;

function TMockBuilderContextNoInstaller.GetLoadedPrivateKeyPassword: string;
begin
  Result := FLoadedPrivateKeyPassword;
end;

function TMockBuilderContextNoInstaller.GetLoadedCAFile: string;
begin
  Result := FLoadedCAFile;
end;

function TMockBuilderContextNoInstaller.GetLoadedCAPath: string;
begin
  Result := FLoadedCAPath;
end;

procedure TMockBuilderContextBase.SetVerifyMode(AMode: TSSLVerifyModes);
begin
  FVerifyMode := AMode;
end;

function TMockBuilderContextBase.GetVerifyMode: TSSLVerifyModes;
begin
  Result := FVerifyMode;
end;

procedure TMockBuilderContextBase.SetVerifyDepth(ADepth: Integer);
begin
  FVerifyDepth := ADepth;
end;

function TMockBuilderContextBase.GetVerifyDepth: Integer;
begin
  Result := FVerifyDepth;
end;

procedure TMockBuilderContextBase.SetVerifyCallback(ACallback: TSSLVerifyCallback);
begin
  if Assigned(ACallback) then;
end;

procedure TMockBuilderContextBase.SetCipherList(const ACipherList: string);
begin
  FCipherList := ACipherList;
end;

function TMockBuilderContextBase.GetCipherList: string;
begin
  Result := FCipherList;
end;

procedure TMockBuilderContextBase.SetCipherSuites(const ACipherSuites: string);
begin
  FCipherSuites := ACipherSuites;
end;

function TMockBuilderContextBase.GetCipherSuites: string;
begin
  Result := FCipherSuites;
end;

procedure TMockBuilderContextBase.SetSessionCacheMode(AEnabled: Boolean);
begin
  FSessionCacheMode := AEnabled;
end;

function TMockBuilderContextBase.GetSessionCacheMode: Boolean;
begin
  Result := FSessionCacheMode;
end;

procedure TMockBuilderContextBase.SetSessionTimeout(ATimeout: Integer);
begin
  FSessionTimeout := ATimeout;
end;

function TMockBuilderContextBase.GetSessionTimeout: Integer;
begin
  Result := FSessionTimeout;
end;

procedure TMockBuilderContextBase.SetSessionCacheSize(ASize: Integer);
begin
  FSessionCacheSize := ASize;
end;

function TMockBuilderContextBase.GetSessionCacheSize: Integer;
begin
  Result := FSessionCacheSize;
end;

procedure TMockBuilderContextBase.SetOptions(const AOptions: TSSLOptions);
begin
  FOptions := AOptions;
end;

function TMockBuilderContextBase.GetOptions: TSSLOptions;
begin
  Result := FOptions;
end;

procedure TMockBuilderContextBase.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
end;

function TMockBuilderContextBase.GetServerName: string;
begin
  Result := FServerName;
end;

procedure TMockBuilderContextBase.SetALPNProtocols(const AProtocols: string);
begin
  FALPNProtocols := AProtocols;
end;

function TMockBuilderContextBase.GetALPNProtocols: string;
begin
  Result := FALPNProtocols;
end;

procedure TMockBuilderContextBase.SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
begin
  FCertVerifyFlags := AFlags;
end;

function TMockBuilderContextBase.GetCertVerifyFlags: TSSLCertVerifyFlags;
begin
  Result := FCertVerifyFlags;
end;

procedure TMockBuilderContextBase.SetPasswordCallback(ACallback: TSSLPasswordCallback);
begin
  if Assigned(ACallback) then;
end;

procedure TMockBuilderContextBase.SetInfoCallback(ACallback: TSSLInfoCallback);
begin
  if Assigned(ACallback) then;
end;

procedure TMockBuilderContextBase.AddCertificatePin(const AHash: TBytes; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
begin
  if (Length(AHash) > 0) and (APinType >= 0) and (ADescription <> '') and AIsBackup then;
end;

procedure TMockBuilderContextBase.AddCertificatePinBase64(const ABase64Hash: string;
  APinType: Integer; const ADescription: string; AIsBackup: Boolean);
begin
  if (ABase64Hash <> '') and (APinType >= 0) and (ADescription <> '') and AIsBackup then;
end;

procedure TMockBuilderContextBase.SetCertificatePinningEnabled(AEnabled: Boolean);
begin
  if AEnabled then;
end;

function TMockBuilderContextBase.GetCertificatePinningEnabled: Boolean;
begin
  Result := False;
end;

procedure TMockBuilderContextBase.ClearCertificatePins;
begin
end;

function TMockBuilderContextBase.CreateConnection(ASocket: THandle): ISSLConnection;
begin
  if ASocket <> 0 then;
  Result := nil;
end;

function TMockBuilderContextBase.CreateConnection(AStream: TStream): ISSLConnection;
begin
  if AStream <> nil then;
  Result := nil;
end;

function TMockBuilderContextBase.IsValid: Boolean;
begin
  Result := True;
end;

function TMockBuilderContextFailingInstaller.InstallFileBackedReplayLedger(
  const AFileName: string
): Boolean;
begin
  Result := False;
  if AFileName = '' then;
end;

function TMockBuilderContextFailingInstaller.InstallDirectoryBackedReplayLedger(
  const ADirectoryName: string
): Boolean;
begin
  Result := False;
  if ADirectoryName = '' then;
end;

constructor TMockBuilderLibraryBase.Create;
begin
  inherited Create;
  FillChar(FDefaultConfig, SizeOf(FDefaultConfig), 0);
  FDefaultConfig.LibraryType := GetLibraryType;
  FDefaultConfig.ContextType := sslCtxClient;
end;

function TMockBuilderLibraryBase.Initialize: Boolean;
begin
  Result := True;
end;

procedure TMockBuilderLibraryBase.Finalize;
begin
end;

function TMockBuilderLibraryBase.IsInitialized: Boolean;
begin
  Result := True;
end;

function TMockBuilderLibraryBase.GetLibraryType: TSSLLibraryType;
begin
  Result := sslAutoDetect;
end;

function TMockBuilderLibraryBase.GetVersionString: string;
begin
  Result := 'MockBuilderLibrary';
end;

function TMockBuilderLibraryBase.GetVersionNumber: Cardinal;
begin
  Result := 1;
end;

function TMockBuilderLibraryBase.GetCompileFlags: string;
begin
  Result := '';
end;

function TMockBuilderLibraryBase.IsProtocolSupported(aProtocol: TSSLProtocolVersion): Boolean;
begin
  Result := aProtocol in [sslProtocolTLS12, sslProtocolTLS13];
end;

function TMockBuilderLibraryBase.IsCipherSupported(const aCipherName: string): Boolean;
begin
  Result := aCipherName <> '';
end;

function TMockBuilderLibraryBase.IsFeatureSupported(aFeature: TSSLFeature): Boolean;
begin
  Result := aFeature in [sslFeatSNI, sslFeatALPN, sslFeatSessionCache];
end;

function TMockBuilderLibraryBase.GetCapabilities: TSSLBackendCapabilities;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.BackendType := GetLibraryType;
  Result.MinTLSVersion := sslProtocolTLS12;
  Result.MaxTLSVersion := sslProtocolTLS13;
end;

procedure TMockBuilderLibraryBase.SetDefaultConfig(const aConfig: TSSLConfig);
begin
  FDefaultConfig := aConfig;
end;

function TMockBuilderLibraryBase.GetDefaultConfig: TSSLConfig;
begin
  Result := FDefaultConfig;
  Result.LibraryType := GetLibraryType;
end;

function TMockBuilderLibraryBase.GetLastError: Integer;
begin
  Result := 0;
end;

function TMockBuilderLibraryBase.GetLastErrorString: string;
begin
  Result := '';
end;

procedure TMockBuilderLibraryBase.ClearError;
begin
end;

function TMockBuilderLibraryBase.GetStatistics: TSSLStatistics;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

procedure TMockBuilderLibraryBase.ResetStatistics;
begin
end;

procedure TMockBuilderLibraryBase.SetLogCallback(aCallback: TSSLLogCallback);
begin
  if Assigned(aCallback) then;
end;

procedure TMockBuilderLibraryBase.Log(aLevel: TSSLLogLevel; const aMessage: string);
begin
  if (aLevel = sslLogNone) and (aMessage = '') then;
end;

function TMockBuilderLibraryBase.CreateContext(aType: TSSLContextType): ISSLContext;
begin
  Result := TMockBuilderContextBase.Create(aType);
end;

function TMockBuilderLibraryBase.CreateCertificate: ISSLCertificate;
begin
  Result := nil;
end;

function TMockBuilderLibraryBase.CreateCertificateStore: ISSLCertificateStore;
begin
  Result := nil;
end;

function TMockBuilderLibraryNoInstaller.GetLibraryType: TSSLLibraryType;
begin
  Result := sslOpenSSL;
end;

function TMockBuilderLibraryNoInstaller.GetVersionString: string;
begin
  Result := 'MockBuilderNoInstaller';
end;

function TMockBuilderLibraryNoInstaller.CreateContext(aType: TSSLContextType): ISSLContext;
begin
  Result := TMockBuilderContextNoInstaller.Create(aType);
end;

function TMockBuilderLibraryFailingInstaller.GetLibraryType: TSSLLibraryType;
begin
  Result := sslMbedTLS;
end;

function TMockBuilderLibraryFailingInstaller.GetVersionString: string;
begin
  Result := 'MockBuilderFailingInstaller';
end;

function TMockBuilderLibraryFailingInstaller.CreateContext(aType: TSSLContextType): ISSLContext;
begin
  Result := TMockBuilderContextFailingInstaller.Create(aType);
end;

procedure RegisterReplayStoreMockLibraries;
begin
  TSSLFactory.ReleaseLibrary(sslOpenSSL);
  TSSLFactory.ReleaseLibrary(sslMbedTLS);
  TSSLFactory.RegisterLibrary(sslOpenSSL, TMockBuilderLibraryNoInstaller,
    'Mock builder backend without replay installer', 100000);
  TSSLFactory.RegisterLibrary(sslMbedTLS, TMockBuilderLibraryFailingInstaller,
    'Mock builder backend with failing replay installer', 100000);
end;

procedure UnregisterReplayStoreMockLibraries;
begin
  TSSLFactory.ReleaseLibrary(sslOpenSSL);
  TSSLFactory.ReleaseLibrary(sslMbedTLS);
  TSSLFactory.UnregisterLibrary(sslOpenSSL);
  TSSLFactory.UnregisterLibrary(sslMbedTLS);
end;

procedure TestTryBuildClient;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  WriteLn('=== TryBuildClient Tests ===');

  // 测试成功场景 - 基本配置
  LBuilder := CreateRuntimeBuilder;
  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Should create client context with defaults');
  Assert(LContext <> nil, 'Context should not be nil on success');
  LContext := nil;

  // 测试成功场景 - 带安全默认值
  LBuilder := CreateSafeRuntimeBuilder;
  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Should create client context with safe defaults');
  Assert(LContext <> nil, 'Context should not be nil with safe defaults');
  LContext := nil;

  // 测试配置链
  LBuilder := CreateRuntimeBuilder
    .WithTLS13
    .WithVerifyPeer
    .WithSystemRoots;
  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Should create client with chained configuration');
  Assert(LContext <> nil, 'Context should not be nil after chaining');
  LContext := nil;

  WriteLn;
end;

procedure TestTryBuildServer;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM, LKeyPEM: string;
  LMissingPINFile: string;
begin
  WriteLn('=== TryBuildServer Tests ===');

  // 测试失败场景 - 无证书
  LBuilder := CreateRuntimeBuilder;
  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsErr, 'Should fail without certificate');
  Assert(LContext = nil, 'Context should be nil on failure');
  Assert(LResult.ErrorMessage <> '', 'Should provide error message');
  WriteLn('    Error: ', LResult.ErrorMessage);

  LBuilder := CreateRuntimeBuilder
    .WithCertificate('missing-before-private-key-check.pem');
  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsErr, 'Should fail without private key before loading certificate file material');
  Assert(LContext = nil, 'Context should stay nil when private key is missing');
  Assert(Pos('requires a private key', LowerCase(LResult.ErrorMessage)) > 0,
    'Missing private key should keep the server validation error boundary');

  // 生成测试证书
  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'test.local',
    'Test Org',
    30,
    LCertPEM,
    LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  // 测试成功场景 - 带证书
  LBuilder := CreateRuntimeBuilder
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM);
  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsOk, 'Should create server context with certificate');
  Assert(LContext <> nil, 'Context should not be nil with certificate');
  LContext := nil;

  // 测试配置链 - 完整服务器配置
  LBuilder := CreateSafeRuntimeBuilder
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM)
    .WithTLS12And13
    .WithVerifyNone;
  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsOk, 'Should create server with full configuration');
  Assert(LContext <> nil, 'Context should not be nil with full config');
  LContext := nil;

  // Unsupported builder PKCS#11 PIN method should fail before runtime load
  LBuilder := CreateRuntimeBuilder
    .WithCertificatePEM(LCertPEM)
    .UsePKCS11('pkcs11:token=TestToken;object=ServerKey;type=private')
    .WithPKCS11PINMethod(pmCallback);
  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsErr, 'Should fail when builder PKCS#11 PIN method is unsupported');
  Assert(LContext = nil, 'Context should stay nil when unsupported PKCS#11 PIN method is rejected');
  Assert(Pos('pin-source', LResult.ErrorMessage) > 0,
    'Should explain URI pin-source or direct PIN alternatives for unsupported PKCS#11 PIN methods');

  // Supported env/file source methods should now fail on source resolution, not unsupported-method guard
  LBuilder := CreateRuntimeBuilder
    .WithCertificatePEM(LCertPEM)
    .UsePKCS11('pkcs11:token=TestToken;object=ServerKey;type=private?module-path=' + SOFTHSM_MODULE_PATH)
    .WithPKCS11PINMethod(pmEnvironment)
    .WithPKCS11PIN('PKCS11_BUILDER_MISSING_ENV_ORDERED');
  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsErr, 'Should fail when builder PKCS#11 env source is configured before pin value');
  Assert(Pos('environment variable', LowerCase(LResult.ErrorMessage)) > 0,
    'Builder PKCS#11 env source should stay observable when pin value is assigned afterwards');

  LBuilder := CreateRuntimeBuilder
    .WithCertificatePEM(LCertPEM)
    .UsePKCS11('pkcs11:token=TestToken;object=ServerKey;type=private?module-path=' + SOFTHSM_MODULE_PATH)
    .WithPKCS11PIN('PKCS11_BUILDER_MISSING_ENV')
    .WithPKCS11PINMethod(pmEnvironment);
  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsErr, 'Should fail when PKCS#11 environment PIN source is missing');
  Assert(Pos('environment variable', LowerCase(LResult.ErrorMessage)) > 0,
    'Missing PKCS#11 environment PIN source should report environment variable failure');

  LMissingPINFile := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'pkcs11_builder_missing_pin.txt';
  if FileExists(LMissingPINFile) then
    DeleteFile(LMissingPINFile);

  LBuilder := CreateRuntimeBuilder
    .WithCertificatePEM(LCertPEM)
    .UsePKCS11('pkcs11:token=TestToken;object=ServerKey;type=private?module-path=' + SOFTHSM_MODULE_PATH)
    .WithPKCS11PIN(LMissingPINFile)
    .WithPKCS11PINMethod(pmFile);
  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsErr, 'Should fail when PKCS#11 PIN file source is missing');
  Assert(Pos('pin file', LowerCase(LResult.ErrorMessage)) > 0,
    'Missing PKCS#11 PIN file source should report file lookup failure');

  LBuilder := CreateRuntimeBuilder
    .WithCertificatePEM(LCertPEM)
    .Override('pkcs11_uri', 'pkcs11:token=TestToken;object=ServerKey;type=private?module-path=' + SOFTHSM_MODULE_PATH)
    .Override('pkcs11_pin', 'PKCS11_BUILDER_MISSING_ENV_OVERRIDE')
    .Override('pkcs11_pin_method', 'pmEnvironment');
  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsErr, 'Should fail when Override configures a missing PKCS#11 environment PIN source');
  Assert(Pos('environment variable', LowerCase(LResult.ErrorMessage)) > 0,
    'Override-configured PKCS#11 PIN method should preserve environment source resolution semantics');

  WriteLn;
end;

procedure TestResultMethods;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  WriteLn('=== Result Methods Tests ===');

  // 测试 IsOk/IsErr
  LBuilder := CreateRuntimeBuilder;
  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Result should be Ok');
  Assert(not LResult.IsErr, 'Result should not be Err');

  // 测试失败的 IsErr
  LBuilder := CreateRuntimeBuilder;
  LResult := LBuilder.TryBuildServer(LContext);
  Assert(LResult.IsErr, 'Result should be Err without certificate');
  Assert(not LResult.IsOk, 'Result should not be Ok on failure');

  WriteLn;
end;

procedure TestCipherConfiguration;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  WriteLn('=== Cipher Configuration Tests ===');

  // 测试自定义密码套件
  LBuilder := CreateRuntimeBuilder
    .WithCipherList('HIGH:!aNULL:!MD5')
    .WithTLS13Ciphersuites('TLS_AES_256_GCM_SHA384');
  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsErr,
    'FreePascal builder path should reject backend-gated custom cipher lists');
  Assert(LContext = nil,
    'Context should stay nil when backend-gated custom cipher list is rejected');
  Assert(Pos('custom non-default cipher override', LowerCase(LResult.ErrorMessage)) > 0,
    'Custom cipher rejection should explain backend capability gating');
  LContext := nil;

  WriteLn;
end;

procedure TestProtocolVersions;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  WriteLn('=== Protocol Versions Tests ===');

  // TLS 1.2 only
  LBuilder := CreateRuntimeBuilder.WithTLS12;
  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Should create client with TLS 1.2');
  LContext := nil;

  // TLS 1.3 only
  LBuilder := CreateRuntimeBuilder.WithTLS13;
  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Should create client with TLS 1.3');
  LContext := nil;

  // Both TLS 1.2 and 1.3
  LBuilder := CreateRuntimeBuilder.WithTLS12And13;
  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Should create client with TLS 1.2 and 1.3');
  LContext := nil;

  WriteLn;
end;

procedure TestAutoBackendRequirements;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  WriteLn('=== Auto Backend Requirement Tests ===');

  LBuilder := TSSLContextBuilder.Create.RequirePKCS11Support;
  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsErr, 'Should fail when no available backend satisfies PKCS#11 requirement');
  Assert(LContext = nil, 'Context should be nil when auto-backend requirements are unmet');
  Assert(Pos('No suitable SSL backend found for requirements', LResult.ErrorMessage) > 0,
    'Should report that no suitable backend satisfies the requirements');

  LBuilder := TSSLContextBuilder.Create
    .RequirePKCS11Support
    .Override('explicit_backend', 'sslFreePascal');
  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Override(explicit_backend) should replace stale unmet auto-backend requirements');
  Assert(LContext <> nil, 'Context should be created when explicit backend override clears auto-selection');
  LContext := nil;

  WriteLn;
end;

procedure TestOCSPOverrideState;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  WriteLn('=== OCSP Override Tests ===');

  LBuilder := CreateRuntimeBuilder
    .Override('ocsp_stapling_required', 'true');
  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Override(ocsp_stapling_required) should still allow client context creation');
  Assert(LContext <> nil, 'Context should not be nil when OCSP required is configured via Override');
  if LContext <> nil then
  begin
    Assert(ssoRequireOCSPStapling in LContext.GetOptions,
      'Override-configured OCSP required state should persist to context options');
    Assert(ssoEnableOCSPStapling in LContext.GetOptions,
      'Override-configured OCSP required state should also enable stapling option');
  end;
  LContext := nil;

  WriteLn;
end;

procedure TestCTRequiredOverrideState;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  WriteLn('=== CT Required Override Tests ===');

  LBuilder := CreateRuntimeBuilder
    .Override('certificate_transparency_required', 'true');
  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Override(certificate_transparency_required) should still allow client context creation');
  Assert(LContext <> nil, 'Context should not be nil when CT required is configured via Override');
  if LContext <> nil then
  begin
    Assert(ssoRequireCertificateTransparency in LContext.GetOptions,
      'Override-configured CT required state should persist to context options');
  end;
  LContext := nil;

  WriteLn;
end;

procedure TestContextSafeConfigBuilderProjection;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LMaterial: IInspectableBuilderMaterialContext;
begin
  WriteLn('=== Context-Safe Config Builder Projection Tests ===');

  RegisterReplayStoreMockLibraries;
  try
    LBuilder := TSSLContextBuilder.Create
      .WithBackend(sslOpenSSL)
      .WithTLS13
      .WithVerifyNone
      .WithCertificate('builder-client-cert.pem')
      .WithPrivateKey('builder-client-key.pem', 'builder-secret')
      .WithCAFile('builder-ca.pem')
      .WithCAPath('builder-ca-dir')
      .WithSystemRoots
      .WithCipherList('HIGH:!aNULL')
      .WithTLS13Ciphersuites('TLS_AES_256_GCM_SHA384')
      .WithALPN('h2,http/1.1')
      .WithSessionCache(False)
      .WithSessionTimeout(123);

    LResult := LBuilder.TryBuildClient(LContext);
    Assert(LResult.IsOk, 'Builder should create client context through context-safe projection');
    Assert(LContext <> nil, 'Projected builder context should not be nil');

    if LContext <> nil then
    begin
      Assert(LContext.GetProtocolVersions = [sslProtocolTLS13],
        'Projected builder config should apply protocol versions');
      Assert(LContext.GetVerifyMode = [sslVerifyNone],
        'Projected builder config should apply verify mode');
      Assert(LContext.GetCipherList = 'HIGH:!aNULL',
        'Projected builder config should apply TLS 1.2 cipher list');
      Assert(LContext.GetCipherSuites = 'TLS_AES_256_GCM_SHA384',
        'Projected builder config should apply TLS 1.3 cipher suites');
      Assert(LContext.GetALPNProtocols = 'h2,http/1.1',
        'Projected builder config should apply ALPN defaults');
      Assert(LContext.GetSessionTimeout = 123,
        'Projected builder config should apply session timeout');
      Assert(not LContext.GetSessionCacheMode,
        'Projected builder config should preserve WithSessionCache(False)');
      Assert(not (ssoEnableSessionCache in LContext.GetOptions),
        'Projected builder options should preserve disabled session cache option');
      Assert(Supports(LContext, IInspectableBuilderMaterialContext, LMaterial),
        'Projected builder context should expose material probe');
      if LMaterial <> nil then
      begin
        Assert(LMaterial.GetLoadedCertificateFile = 'builder-client-cert.pem',
          'Projected builder config should apply certificate file material');
        Assert(LMaterial.GetLoadedPrivateKeyFile = 'builder-client-key.pem',
          'Projected builder config should apply private-key file material');
        Assert(LMaterial.GetLoadedPrivateKeyPassword = 'builder-secret',
          'Projected builder config should apply private-key password');
        Assert(LMaterial.GetLoadedCAFile = 'builder-ca.pem',
          'Projected builder config should apply CA file trust material');
        Assert(LMaterial.GetLoadedCAPath = 'builder-ca-dir',
          'Projected builder config should apply CA path trust material');
      end;
    end;
  finally
    UnregisterReplayStoreMockLibraries;
  end;

  WriteLn;
end;

procedure TestReplayStoreErrorContracts;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCertPEM: string;
  LKeyPEM: string;
begin
  WriteLn('=== Replay Store Error Contract Tests ===');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'builder-replay-errors.local',
    'fafafa.ssl',
    30,
    LCertPEM,
    LKeyPEM
  ) then
  begin
    Assert(False, 'Should generate certificate material for replay-store builder error tests');
    WriteLn;
    Exit;
  end;

  RegisterReplayStoreMockLibraries;
  try
    LBuilder := TSSLContextBuilder.Create
      .WithBackend(sslOpenSSL)
      .WithCertificatePEM(LCertPEM)
      .WithPrivateKeyPEM(LKeyPEM)
      .WithServerEarlyDataReplayStoreFile('tmp/mock-no-installer-replay-store.bin');
    LResult := LBuilder.TryBuildServer(LContext);
    Assert(LResult.IsErr,
      'Should fail when replay-store config targets a backend without installer seam');
    Assert(LContext = nil,
      'Context should stay nil when replay-store config requires a missing installer seam');
    Assert(Pos('server_early_data_replay_store_file', LResult.ErrorMessage) > 0,
      'Missing-installer replay-store error should name server_early_data_replay_store_file');
    Assert(Pos('requires a backend', LowerCase(LResult.ErrorMessage)) > 0,
      'Missing-installer replay-store error should explain the required backend seam');

    LBuilder := TSSLContextBuilder.Create
      .WithBackend(sslMbedTLS)
      .WithCertificatePEM(LCertPEM)
      .WithPrivateKeyPEM(LKeyPEM)
      .WithServerEarlyDataReplayStoreFile('tmp/mock-failing-installer-replay-store.bin');
    LResult := LBuilder.TryBuildServer(LContext);
    Assert(LResult.IsErr,
      'Should fail when replay-store installer returns False');
    Assert(LContext = nil,
      'Context should stay nil when replay-store installer reports failure');
    Assert(Pos('server_early_data_replay_store_file', LResult.ErrorMessage) > 0,
      'Installer-failure replay-store error should name server_early_data_replay_store_file');
    Assert(Pos('could not install', LowerCase(LResult.ErrorMessage)) > 0,
      'Installer-failure replay-store error should explain install failure');

    LBuilder := TSSLContextBuilder.Create
      .WithBackend(sslOpenSSL)
      .WithCertificatePEM(LCertPEM)
      .WithPrivateKeyPEM(LKeyPEM)
      .WithServerEarlyDataReplayStoreDirectory('tmp/mock-no-installer-replay-store-dir');
    LResult := LBuilder.TryBuildServer(LContext);
    Assert(LResult.IsErr,
      'Should fail when directory replay-store config targets a backend without installer seam');
    Assert(LContext = nil,
      'Context should stay nil when directory replay-store config requires a missing installer seam');
    Assert(Pos('server_early_data_replay_store_directory', LResult.ErrorMessage) > 0,
      'Missing-installer directory replay-store error should name server_early_data_replay_store_directory');
    Assert(Pos('requires a backend', LowerCase(LResult.ErrorMessage)) > 0,
      'Missing-installer directory replay-store error should explain the required backend seam');

    LBuilder := TSSLContextBuilder.Create
      .WithBackend(sslMbedTLS)
      .WithCertificatePEM(LCertPEM)
      .WithPrivateKeyPEM(LKeyPEM)
      .WithServerEarlyDataReplayStoreDirectory('tmp/mock-failing-installer-replay-store-dir');
    LResult := LBuilder.TryBuildServer(LContext);
    Assert(LResult.IsErr,
      'Should fail when directory replay-store installer returns False');
    Assert(LContext = nil,
      'Context should stay nil when directory replay-store installer reports failure');
    Assert(Pos('server_early_data_replay_store_directory', LResult.ErrorMessage) > 0,
      'Installer-failure directory replay-store error should name server_early_data_replay_store_directory');
    Assert(Pos('could not install', LowerCase(LResult.ErrorMessage)) > 0,
      'Installer-failure directory replay-store error should explain install failure');

    LBuilder := TSSLContextBuilder.Create
      .WithBackend(sslFreePascal)
      .WithCertificatePEM(LCertPEM)
      .WithPrivateKeyPEM(LKeyPEM)
      .WithServerEarlyDataReplayStoreFile('tmp/conflicting-replay-store.bin')
      .WithServerEarlyDataReplayStoreDirectory('tmp/conflicting-replay-store-dir');
    LResult := LBuilder.TryBuildServer(LContext);
    Assert(LResult.IsErr,
      'Should fail when both replay-store file and directory are configured');
    Assert(LContext = nil,
      'Context should stay nil when both replay-store file and directory are configured');
    Assert(Pos('server_early_data_replay_store_file', LResult.ErrorMessage) > 0,
      'Conflict replay-store error should name server_early_data_replay_store_file');
    Assert(Pos('server_early_data_replay_store_directory', LResult.ErrorMessage) > 0,
      'Conflict replay-store error should name server_early_data_replay_store_directory');
    Assert(Pos('not both', LowerCase(LResult.ErrorMessage)) > 0,
      'Conflict replay-store error should explain the mutual-exclusion contract');
  finally
    UnregisterReplayStoreMockLibraries;
  end;

  WriteLn;
end;

begin
  WriteLn('╔════════════════════════════════════════════════════════════╗');
  WriteLn('║   SSL Context Builder Try* Methods Tests                  ║');
  WriteLn('╚════════════════════════════════════════════════════════════╝');
  WriteLn;

  try
    TestTryBuildClient;
    TestTryBuildServer;
    TestResultMethods;
    TestCipherConfiguration;
    TestProtocolVersions;
    TestAutoBackendRequirements;
    TestOCSPOverrideState;
    TestCTRequiredOverrideState;
    TestContextSafeConfigBuilderProjection;
    TestReplayStoreErrorContracts;

    WriteLn('╔════════════════════════════════════════════════════════════╗');
    WriteLn(Format('║   Tests Passed: %-3d  Failed: %-3d                         ║', [GTestsPassed, GTestsFailed]));
    WriteLn('╚════════════════════════════════════════════════════════════╝');

    if GTestsFailed > 0 then
      ExitCode := 1;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('FATAL ERROR: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
