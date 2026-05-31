program test_security_first_fips_independence_contract;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.backend.selector,
  nextpas.core.tls.context.builder;

type
  ITestContextBackendInfo = interface
    ['{D95D84B8-D41F-4A93-BB41-4D2363A8B835}']
    function GetBackendType: TSSLLibraryType;
  end;

  TMockSecurityContext = class(TInterfacedObject, ISSLContext, ITestContextBackendInfo)
  private
    FBackendType: TSSLLibraryType;
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
  public
    constructor Create(ABackendType: TSSLLibraryType; AContextType: TSSLContextType);

    function GetBackendType: TSSLLibraryType;

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

  TMockSecurityLibraryBase = class(TInterfacedObject, ISSLLibrary)
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
    function GetCapabilities: TSSLBackendCapabilities; virtual;

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

  TMockNonFIPSSecurityLibrary = class(TMockSecurityLibraryBase)
  public
    function GetLibraryType: TSSLLibraryType; override;
    function GetVersionString: string; override;
    function GetCapabilities: TSSLBackendCapabilities; override;
  end;

  TMockFIPSSecurityLibrary = class(TMockSecurityLibraryBase)
  public
    function GetLibraryType: TSSLLibraryType; override;
    function GetVersionString: string; override;
    function GetCapabilities: TSSLBackendCapabilities; override;
  end;

procedure Require(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function CreateSecurityFirstCapBase(
  ABackendType: TSSLLibraryType;
  AImplType: TSSLBackendImplType
): TSSLBackendCapabilities;
begin
  Result := Default(TSSLBackendCapabilities);
  Result.BackendType := ABackendType;
  Result.BackendImplType := AImplType;
  Result.BackendVersion := 'mock-security-first';
  Result.MinTLSVersion := sslProtocolTLS12;
  Result.MaxTLSVersion := sslProtocolTLS13;
  Result.SupportsTLS13 := True;
  Result.SupportedCiphers := [
    sslCipherAES256GCM,
    sslCipherCHACHA20_POLY1305
  ];
  Result.SupportedHashes := [
    sslHashSHA256,
    sslHashSHA384,
    sslHashSHA512
  ];
  Result.SupportedKeyExchanges := [
    sslKexECDHE_RSA,
    sslKexECDHE_ECDSA
  ];
  Result.SNISupport := sslSupportStable;
  Result.ALPNSupport := sslSupportStable;
  Result.SessionCacheSupport := sslSupportStable;
  Result.SessionTicketsSupport := sslSupportStable;
  Result.RenegotiationSupport := sslSupportStable;
  Result.CompatibilityLevel := 90;
end;

procedure ClearSecurityFirstTestBackends;
var
  LType: TSSLLibraryType;
begin
  for LType := Low(TSSLLibraryType) to High(TSSLLibraryType) do
  begin
    if LType = sslAutoDetect then
      Continue;
    TSSLFactory.ReleaseLibrary(LType);
    TSSLFactory.UnregisterLibrary(LType);
  end;
end;

procedure ConfigureSecurityFirstTestBackends;
begin
  ClearSecurityFirstTestBackends;
  TSSLFactory.RegisterLibrary(sslOpenSSL, TMockNonFIPSSecurityLibrary,
    'Mock non-FIPS security-first backend', 100000);
  TSSLFactory.RegisterLibrary(sslWinSSL, TMockFIPSSecurityLibrary,
    'Mock FIPS-capable security-first backend', 90000);
  TSSLFactory.SetDefaultLibrary(sslAutoDetect);
end;

constructor TMockSecurityContext.Create(
  ABackendType: TSSLLibraryType;
  AContextType: TSSLContextType
);
begin
  inherited Create;
  FBackendType := ABackendType;
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
end;

function TMockSecurityContext.GetBackendType: TSSLLibraryType;
begin
  Result := FBackendType;
end;

function TMockSecurityContext.GetContextType: TSSLContextType;
begin
  Result := FContextType;
end;

procedure TMockSecurityContext.SetProtocolVersions(AVersions: TSSLProtocolVersions);
begin
  FProtocolVersions := AVersions;
end;

function TMockSecurityContext.GetProtocolVersions: TSSLProtocolVersions;
begin
  Result := FProtocolVersions;
end;

procedure TMockSecurityContext.SetPreferredVersion(AVersion: TSSLProtocolVersion);
begin
  FPreferredVersion := AVersion;
end;

function TMockSecurityContext.GetPreferredVersion: TSSLProtocolVersion;
begin
  Result := FPreferredVersion;
end;

procedure TMockSecurityContext.LoadCertificate(const AFileName: string);
begin
  if AFileName = '' then;
end;

procedure TMockSecurityContext.LoadCertificate(AStream: TStream);
begin
  if AStream <> nil then;
end;

procedure TMockSecurityContext.LoadCertificate(ACert: ISSLCertificate);
begin
  if ACert <> nil then;
end;

procedure TMockSecurityContext.LoadPrivateKey(const AFileName: string; const APassword: string);
begin
  if (AFileName = '') and (APassword = '') then;
end;

procedure TMockSecurityContext.LoadPrivateKey(AStream: TStream; const APassword: string);
begin
  if (AStream <> nil) and (APassword = '') then;
end;

procedure TMockSecurityContext.LoadCertificatePEM(const APEM: string);
begin
  if APEM = '' then;
end;

procedure TMockSecurityContext.LoadPrivateKeyPEM(const APEM: string; const APassword: string);
begin
  if (APEM = '') and (APassword = '') then;
end;

procedure TMockSecurityContext.LoadCAFile(const AFileName: string);
begin
  if AFileName = '' then;
end;

procedure TMockSecurityContext.LoadCAPath(const APath: string);
begin
  if APath = '' then;
end;

procedure TMockSecurityContext.SetCertificateStore(AStore: ISSLCertificateStore);
begin
  if AStore <> nil then;
end;

procedure TMockSecurityContext.SetVerifyMode(AMode: TSSLVerifyModes);
begin
  FVerifyMode := AMode;
end;

function TMockSecurityContext.GetVerifyMode: TSSLVerifyModes;
begin
  Result := FVerifyMode;
end;

procedure TMockSecurityContext.SetVerifyDepth(ADepth: Integer);
begin
  FVerifyDepth := ADepth;
end;

function TMockSecurityContext.GetVerifyDepth: Integer;
begin
  Result := FVerifyDepth;
end;

procedure TMockSecurityContext.SetVerifyCallback(ACallback: TSSLVerifyCallback);
begin
  if Assigned(ACallback) then;
end;

procedure TMockSecurityContext.SetCipherList(const ACipherList: string);
begin
  FCipherList := ACipherList;
end;

function TMockSecurityContext.GetCipherList: string;
begin
  Result := FCipherList;
end;

procedure TMockSecurityContext.SetCipherSuites(const ACipherSuites: string);
begin
  FCipherSuites := ACipherSuites;
end;

function TMockSecurityContext.GetCipherSuites: string;
begin
  Result := FCipherSuites;
end;

procedure TMockSecurityContext.SetSessionCacheMode(AEnabled: Boolean);
begin
  FSessionCacheMode := AEnabled;
end;

function TMockSecurityContext.GetSessionCacheMode: Boolean;
begin
  Result := FSessionCacheMode;
end;

procedure TMockSecurityContext.SetSessionTimeout(ATimeout: Integer);
begin
  FSessionTimeout := ATimeout;
end;

function TMockSecurityContext.GetSessionTimeout: Integer;
begin
  Result := FSessionTimeout;
end;

procedure TMockSecurityContext.SetSessionCacheSize(ASize: Integer);
begin
  FSessionCacheSize := ASize;
end;

function TMockSecurityContext.GetSessionCacheSize: Integer;
begin
  Result := FSessionCacheSize;
end;

procedure TMockSecurityContext.SetOptions(const AOptions: TSSLOptions);
begin
  FOptions := AOptions;
end;

function TMockSecurityContext.GetOptions: TSSLOptions;
begin
  Result := FOptions;
end;

procedure TMockSecurityContext.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
end;

function TMockSecurityContext.GetServerName: string;
begin
  Result := FServerName;
end;

procedure TMockSecurityContext.SetALPNProtocols(const AProtocols: string);
begin
  FALPNProtocols := AProtocols;
end;

function TMockSecurityContext.GetALPNProtocols: string;
begin
  Result := FALPNProtocols;
end;

procedure TMockSecurityContext.SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
begin
  FCertVerifyFlags := AFlags;
end;

function TMockSecurityContext.GetCertVerifyFlags: TSSLCertVerifyFlags;
begin
  Result := FCertVerifyFlags;
end;

procedure TMockSecurityContext.SetPasswordCallback(ACallback: TSSLPasswordCallback);
begin
  if Assigned(ACallback) then;
end;

procedure TMockSecurityContext.SetInfoCallback(ACallback: TSSLInfoCallback);
begin
  if Assigned(ACallback) then;
end;

procedure TMockSecurityContext.AddCertificatePin(const AHash: TBytes; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
begin
  if (Length(AHash) > 0) and (APinType >= 0) and (ADescription <> '') and AIsBackup then;
end;

procedure TMockSecurityContext.AddCertificatePinBase64(
  const ABase64Hash: string;
  APinType: Integer;
  const ADescription: string;
  AIsBackup: Boolean
);
begin
  if (ABase64Hash <> '') and (APinType >= 0) and (ADescription <> '') and AIsBackup then;
end;

procedure TMockSecurityContext.SetCertificatePinningEnabled(AEnabled: Boolean);
begin
  if AEnabled then;
end;

function TMockSecurityContext.GetCertificatePinningEnabled: Boolean;
begin
  Result := False;
end;

procedure TMockSecurityContext.ClearCertificatePins;
begin
end;

function TMockSecurityContext.CreateConnection(ASocket: THandle): ISSLConnection;
begin
  if ASocket <> 0 then;
  Result := nil;
end;

function TMockSecurityContext.CreateConnection(AStream: TStream): ISSLConnection;
begin
  if AStream <> nil then;
  Result := nil;
end;

function TMockSecurityContext.IsValid: Boolean;
begin
  Result := True;
end;

constructor TMockSecurityLibraryBase.Create;
begin
  inherited Create;
  FillChar(FDefaultConfig, SizeOf(FDefaultConfig), 0);
  FDefaultConfig.LibraryType := GetLibraryType;
  FDefaultConfig.ContextType := sslCtxClient;
end;

function TMockSecurityLibraryBase.Initialize: Boolean;
begin
  Result := True;
end;

procedure TMockSecurityLibraryBase.Finalize;
begin
end;

function TMockSecurityLibraryBase.IsInitialized: Boolean;
begin
  Result := True;
end;

function TMockSecurityLibraryBase.GetLibraryType: TSSLLibraryType;
begin
  Result := sslAutoDetect;
end;

function TMockSecurityLibraryBase.GetVersionString: string;
begin
  Result := 'MockSecurityLibrary';
end;

function TMockSecurityLibraryBase.GetVersionNumber: Cardinal;
begin
  Result := 1;
end;

function TMockSecurityLibraryBase.GetCompileFlags: string;
begin
  Result := '';
end;

function TMockSecurityLibraryBase.IsProtocolSupported(aProtocol: TSSLProtocolVersion): Boolean;
begin
  Result := aProtocol in [sslProtocolTLS12, sslProtocolTLS13];
end;

function TMockSecurityLibraryBase.IsCipherSupported(const aCipherName: string): Boolean;
begin
  Result := aCipherName <> '';
end;

function TMockSecurityLibraryBase.IsFeatureSupported(aFeature: TSSLFeature): Boolean;
begin
  Result := aFeature in [sslFeatSNI, sslFeatALPN, sslFeatSessionCache];
end;

function TMockSecurityLibraryBase.GetCapabilities: TSSLBackendCapabilities;
begin
  Result := CreateSecurityFirstCapBase(GetLibraryType, sslImplHybrid);
  NormalizeLegacyCapabilityBooleans(Result);
end;

procedure TMockSecurityLibraryBase.SetDefaultConfig(const aConfig: TSSLConfig);
begin
  FDefaultConfig := aConfig;
end;

function TMockSecurityLibraryBase.GetDefaultConfig: TSSLConfig;
begin
  Result := FDefaultConfig;
  Result.LibraryType := GetLibraryType;
end;

function TMockSecurityLibraryBase.GetLastError: Integer;
begin
  Result := 0;
end;

function TMockSecurityLibraryBase.GetLastErrorString: string;
begin
  Result := '';
end;

procedure TMockSecurityLibraryBase.ClearError;
begin
end;

function TMockSecurityLibraryBase.GetStatistics: TSSLStatistics;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

procedure TMockSecurityLibraryBase.ResetStatistics;
begin
end;

procedure TMockSecurityLibraryBase.SetLogCallback(aCallback: TSSLLogCallback);
begin
  if Assigned(aCallback) then;
end;

procedure TMockSecurityLibraryBase.Log(aLevel: TSSLLogLevel; const aMessage: string);
begin
  if (aLevel = sslLogNone) and (aMessage = '') then;
end;

function TMockSecurityLibraryBase.CreateContext(aType: TSSLContextType): ISSLContext;
begin
  Result := TMockSecurityContext.Create(GetLibraryType, aType);
end;

function TMockSecurityLibraryBase.CreateCertificate: ISSLCertificate;
begin
  Result := nil;
end;

function TMockSecurityLibraryBase.CreateCertificateStore: ISSLCertificateStore;
begin
  Result := nil;
end;

function TMockNonFIPSSecurityLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslOpenSSL;
end;

function TMockNonFIPSSecurityLibrary.GetVersionString: string;
begin
  Result := 'MockNonFIPSSecurityBackend';
end;

function TMockNonFIPSSecurityLibrary.GetCapabilities: TSSLBackendCapabilities;
begin
  Result := CreateSecurityFirstCapBase(GetLibraryType, sslImplCLibrary);
  Result.HasConstantTimeOperations := True;
  Result.HasSecureMemoryWipe := True;
  Result.SupportedCiphers := Result.SupportedCiphers + [sslCipherDES];
  Result.OCSPStaplingSupport := sslSupportStable;
  Result.CertTransparencySupport := sslSupportStable;
  NormalizeLegacyCapabilityBooleans(Result);
end;

function TMockFIPSSecurityLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslWinSSL;
end;

function TMockFIPSSecurityLibrary.GetVersionString: string;
begin
  Result := 'MockFIPSSecurityBackend';
end;

function TMockFIPSSecurityLibrary.GetCapabilities: TSSLBackendCapabilities;
begin
  Result := CreateSecurityFirstCapBase(GetLibraryType, sslImplOSNative);
  Result.HasConstantTimeOperations := True;
  Result.HasSecureMemoryWipe := True;
  Result.SupportsFIPSMode := True;
  Result.HasSIMDOptimization := True;
  NormalizeLegacyCapabilityBooleans(Result);
end;

procedure Test_DefaultSecurityFirstDoesNotPreferFIPS;
var
  LRequirements: TSSLRequirements;
  LSelectedType: TSSLLibraryType;
  LMatchScore: Integer;
begin
  WriteLn('=== Test 1: Default security-first requirements are not FIPS-biased ===');

  LRequirements := CreateSecurityFirstRequirements;

  Require(not LRequirements.PlatformPreferences.PreferFIPSCompliant,
    'Security-first requirements must not default to PreferFIPSCompliant=True');
  Require(sslProtocolTLS13 in LRequirements.RequiredProtocols,
    'Security-first requirements must still require TLS 1.3');
  Require(SelectBestBackend(LRequirements, LSelectedType, LMatchScore),
    'Security-first selector must find a backend in the controlled mock matrix');
  Require(LSelectedType = sslOpenSSL,
    'Default security-first selector must prefer the stronger non-FIPS backend when FIPS is only optional');

  WriteLn('  Selected backend: ', LibraryTypeToString(LSelectedType));
  WriteLn('  Match score: ', LMatchScore);
end;

procedure Test_ExplicitFIPSPreferenceChangesSelection;
var
  LRequirements: TSSLRequirements;
  LSelectedType: TSSLLibraryType;
  LMatchScore: Integer;
begin
  WriteLn('=== Test 2: Explicit FIPS preference is opt-in ===');

  LRequirements := CreateSecurityFirstRequirements;
  LRequirements.PlatformPreferences.PreferFIPSCompliant := True;

  Require(SelectBestBackend(LRequirements, LSelectedType, LMatchScore),
    'Selector must still find a backend when FIPS preference is explicitly enabled');
  Require(LSelectedType = sslWinSSL,
    'Explicit PreferFIPSCompliant=True must be the step that flips selection to the FIPS backend');

  WriteLn('  Selected backend with explicit FIPS preference: ',
    LibraryTypeToString(LSelectedType));
  WriteLn('  Match score: ', LMatchScore);
end;

procedure Test_WithSecurityFirstBuildsNonFIPSContext;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LInfo: ITestContextBackendInfo;
begin
  WriteLn('=== Test 3: WithSecurityFirst builder path stays non-FIPS by default ===');

  LBuilder := TSSLContextBuilder.Create.WithSecurityFirst;
  LResult := LBuilder.TryBuildClient(LContext);

  Require(LResult.IsOk,
    'WithSecurityFirst builder path must succeed without requiring a FIPS backend');
  Require(LContext <> nil,
    'WithSecurityFirst builder must return a context');
  Require(Supports(LContext, ITestContextBackendInfo, LInfo),
    'Mock security-first context must expose backend inspection info');
  Require(LInfo.GetBackendType = sslOpenSSL,
    'WithSecurityFirst builder must instantiate the selected non-FIPS backend by default');
end;

begin
  ConfigureSecurityFirstTestBackends;
  try
    Test_DefaultSecurityFirstDoesNotPreferFIPS;
    Test_ExplicitFIPSPreferenceChangesSelection;
    Test_WithSecurityFirstBuildsNonFIPSContext;
    WriteLn;
    WriteLn('✅ Security-first FIPS independence contract verified');
  finally
    ClearSecurityFirstTestBackends;
  end;
end.
