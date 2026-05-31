program test_auto_backend_os_native_preference_truth_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.backend.selector,
  nextpas.core.tls.context.builder;

const
  // Current selector formula:
  // platform score bonus = 30, balanced platform weight = 10,
  // so preferred score delta should be (30 * 10) div 100 = 3.
  OS_NATIVE_PREFERRED_SCORE_DELTA = 3;

type
  TMockContext = class(TInterfacedObject, ISSLContext, ISSLNativeHandleAccess)
  private
    FContextType: TSSLContextType;
    FBackendType: TSSLLibraryType;
  public
    constructor Create(AContextType: TSSLContextType; ABackendType: TSSLLibraryType);

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

    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;
  end;

  TMockLibraryBase = class(TInterfacedObject, ISSLLibrary)
  public
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

  TMockOpenSSLLibrary = class(TMockLibraryBase)
  public
    function GetLibraryType: TSSLLibraryType; override;
    function GetVersionString: string; override;
    function GetCapabilities: TSSLBackendCapabilities; override;
  end;

  TMockWinSSLLibrary = class(TMockLibraryBase)
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

function BuildMockCapabilities(
  ABackendType: TSSLLibraryType;
  AImplType: TSSLBackendImplType;
  ASecurityProfile: Integer
): TSSLBackendCapabilities;
begin
  Result := Default(TSSLBackendCapabilities);
  Result.BackendType := ABackendType;
  Result.BackendImplType := AImplType;
  Result.MinTLSVersion := sslProtocolTLS12;
  Result.MaxTLSVersion := sslProtocolTLS13;
  Result.SupportsTLS13 := True;
  Result.HasConstantTimeOperations := True;
  Result.HasSecureMemoryWipe := True;
  Result.CompatibilityLevel := 95;
  Result.SupportedCiphers := [sslCipherAES128GCM];

  if ASecurityProfile >= 2 then
    Include(Result.SupportedCiphers, sslCipherAES256GCM);
end;

function FindMatchByType(
  const AMatches: TSSLBackendMatchArray;
  ABackendType: TSSLLibraryType;
  out AMatch: TSSLBackendMatch
): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(AMatches) do
  begin
    if AMatches[I].BackendType <> ABackendType then
      Continue;

    AMatch := AMatches[I];
    Exit(True);
  end;
end;

procedure ResetRegisteredBackends;
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

procedure RegisterMockPreferenceBackends;
begin
  ResetRegisteredBackends;
  TSSLFactory.RegisterLibrary(sslOpenSSL, TMockOpenSSLLibrary, 'Mock OpenSSL', 100000);
  TSSLFactory.RegisterLibrary(sslWinSSL, TMockWinSSLLibrary, 'Mock WinSSL', 100000);
  TSSLFactory.SetDefaultLibrary(sslAutoDetect);
end;

procedure RequireScoreAndSelectionTruth(
  const ABaselineMatches: TSSLBackendMatchArray;
  const APreferredMatches: TSSLBackendMatchArray
);
var
  LBaseOpenSSL, LBaseWinSSL: TSSLBackendMatch;
  LPreferredOpenSSL, LPreferredWinSSL: TSSLBackendMatch;
begin
  Require(Length(ABaselineMatches) = 2,
    'Baseline selector must see exactly the two controlled mock backends');
  Require(Length(APreferredMatches) = 2,
    'Preferred selector must see exactly the two controlled mock backends');

  Require(FindMatchByType(ABaselineMatches, sslOpenSSL, LBaseOpenSSL),
    'Baseline results must include mock OpenSSL');
  Require(FindMatchByType(ABaselineMatches, sslWinSSL, LBaseWinSSL),
    'Baseline results must include mock WinSSL');
  Require(FindMatchByType(APreferredMatches, sslOpenSSL, LPreferredOpenSSL),
    'Preferred results must include mock OpenSSL');
  Require(FindMatchByType(APreferredMatches, sslWinSSL, LPreferredWinSSL),
    'Preferred results must include mock WinSSL');

  Require(LBaseOpenSSL.MatchScore > LBaseWinSSL.MatchScore,
    'Baseline must rank the non-OS-native backend first in the controlled mock scenario');
  Require(LPreferredWinSSL.MatchScore > LPreferredOpenSSL.MatchScore,
    'PreferOSNative must let the OS-native backend overtake in the controlled mock scenario');

  Require(LPreferredOpenSSL.MatchScore = LBaseOpenSSL.MatchScore,
    'PreferOSNative must not change the non-OS-native backend score');
  Require(LPreferredWinSSL.MatchScore = LBaseWinSSL.MatchScore + OS_NATIVE_PREFERRED_SCORE_DELTA,
    'PreferOSNative must add the expected fixed score bonus to the OS-native backend');
end;

constructor TMockContext.Create(AContextType: TSSLContextType; ABackendType: TSSLLibraryType);
begin
  inherited Create;
  FContextType := AContextType;
  FBackendType := ABackendType;
end;

function TMockContext.GetContextType: TSSLContextType;
begin
  Result := FContextType;
end;

procedure TMockContext.SetProtocolVersions(AVersions: TSSLProtocolVersions);
begin
end;

function TMockContext.GetProtocolVersions: TSSLProtocolVersions;
begin
  Result := [sslProtocolTLS12, sslProtocolTLS13];
end;

procedure TMockContext.SetPreferredVersion(AVersion: TSSLProtocolVersion);
begin
end;

function TMockContext.GetPreferredVersion: TSSLProtocolVersion;
begin
  Result := sslProtocolUnknown;
end;

procedure TMockContext.LoadCertificate(const AFileName: string);
begin
end;

procedure TMockContext.LoadCertificate(AStream: TStream);
begin
end;

procedure TMockContext.LoadCertificate(ACert: ISSLCertificate);
begin
end;

procedure TMockContext.LoadPrivateKey(const AFileName: string; const APassword: string);
begin
end;

procedure TMockContext.LoadPrivateKey(AStream: TStream; const APassword: string);
begin
end;

procedure TMockContext.LoadCertificatePEM(const APEM: string);
begin
end;

procedure TMockContext.LoadPrivateKeyPEM(const APEM: string; const APassword: string);
begin
end;

procedure TMockContext.LoadCAFile(const AFileName: string);
begin
end;

procedure TMockContext.LoadCAPath(const APath: string);
begin
end;

procedure TMockContext.SetCertificateStore(AStore: ISSLCertificateStore);
begin
  if Assigned(AStore) then;
end;

procedure TMockContext.SetVerifyMode(AMode: TSSLVerifyModes);
begin
end;

function TMockContext.GetVerifyMode: TSSLVerifyModes;
begin
  Result := [];
end;

procedure TMockContext.SetVerifyDepth(ADepth: Integer);
begin
end;

function TMockContext.GetVerifyDepth: Integer;
begin
  Result := 0;
end;

procedure TMockContext.SetVerifyCallback(ACallback: TSSLVerifyCallback);
begin
end;

procedure TMockContext.SetCipherList(const ACipherList: string);
begin
end;

function TMockContext.GetCipherList: string;
begin
  Result := '';
end;

procedure TMockContext.SetCipherSuites(const ACipherSuites: string);
begin
end;

function TMockContext.GetCipherSuites: string;
begin
  Result := '';
end;

procedure TMockContext.SetSessionCacheMode(AEnabled: Boolean);
begin
end;

function TMockContext.GetSessionCacheMode: Boolean;
begin
  Result := False;
end;

procedure TMockContext.SetSessionTimeout(ATimeout: Integer);
begin
end;

function TMockContext.GetSessionTimeout: Integer;
begin
  Result := 0;
end;

procedure TMockContext.SetSessionCacheSize(ASize: Integer);
begin
end;

function TMockContext.GetSessionCacheSize: Integer;
begin
  Result := 0;
end;

procedure TMockContext.SetOptions(const AOptions: TSSLOptions);
begin
end;

function TMockContext.GetOptions: TSSLOptions;
begin
  Result := [];
end;

procedure TMockContext.SetServerName(const AServerName: string);
begin
end;

function TMockContext.GetServerName: string;
begin
  Result := '';
end;

procedure TMockContext.SetALPNProtocols(const AProtocols: string);
begin
end;

function TMockContext.GetALPNProtocols: string;
begin
  Result := '';
end;

procedure TMockContext.SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
begin
end;

function TMockContext.GetCertVerifyFlags: TSSLCertVerifyFlags;
begin
  Result := [];
end;

procedure TMockContext.SetPasswordCallback(ACallback: TSSLPasswordCallback);
begin
end;

procedure TMockContext.SetInfoCallback(ACallback: TSSLInfoCallback);
begin
end;

procedure TMockContext.AddCertificatePin(const AHash: TBytes; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
begin
end;

procedure TMockContext.AddCertificatePinBase64(const ABase64Hash: string; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
begin
end;

procedure TMockContext.SetCertificatePinningEnabled(AEnabled: Boolean);
begin
end;

function TMockContext.GetCertificatePinningEnabled: Boolean;
begin
  Result := False;
end;

procedure TMockContext.ClearCertificatePins;
begin
end;

function TMockContext.CreateConnection(ASocket: THandle): ISSLConnection;
begin
  Result := nil;
end;

function TMockContext.CreateConnection(AStream: TStream): ISSLConnection;
begin
  Result := nil;
end;

function TMockContext.IsValid: Boolean;
begin
  Result := True;
end;

function TMockContext.GetNativeHandle: Pointer;
begin
  Result := Pointer(PtrUInt(Ord(FBackendType) + 1));
end;

function TMockContext.GetBackendType: TSSLLibraryType;
begin
  Result := FBackendType;
end;

function TMockContext.IsNativeHandleValid: Boolean;
begin
  Result := True;
end;

function TMockLibraryBase.Initialize: Boolean;
begin
  Result := True;
end;

procedure TMockLibraryBase.Finalize;
begin
end;

function TMockLibraryBase.IsInitialized: Boolean;
begin
  Result := True;
end;

function TMockLibraryBase.GetLibraryType: TSSLLibraryType;
begin
  Result := sslAutoDetect;
end;

function TMockLibraryBase.GetVersionString: string;
begin
  Result := 'MockLibrary';
end;

function TMockLibraryBase.GetVersionNumber: Cardinal;
begin
  Result := 0;
end;

function TMockLibraryBase.GetCompileFlags: string;
begin
  Result := '';
end;

function TMockLibraryBase.IsProtocolSupported(aProtocol: TSSLProtocolVersion): Boolean;
begin
  Result := aProtocol in [sslProtocolTLS12, sslProtocolTLS13];
end;

function TMockLibraryBase.IsCipherSupported(const aCipherName: string): Boolean;
begin
  Result := aCipherName <> '';
end;

function TMockLibraryBase.IsFeatureSupported(aFeature: TSSLFeature): Boolean;
begin
  Result := aFeature in [sslFeatSNI, sslFeatALPN];
end;

function TMockLibraryBase.GetCapabilities: TSSLBackendCapabilities;
begin
  Result := BuildMockCapabilities(GetLibraryType, sslImplNative, 1);
end;

procedure TMockLibraryBase.SetDefaultConfig(const aConfig: TSSLConfig);
begin
end;

function TMockLibraryBase.GetDefaultConfig: TSSLConfig;
begin
  Result := Default(TSSLConfig);
  Result.LibraryType := GetLibraryType;
  Result.ContextType := sslCtxClient;
end;

function TMockLibraryBase.GetLastError: Integer;
begin
  Result := 0;
end;

function TMockLibraryBase.GetLastErrorString: string;
begin
  Result := '';
end;

procedure TMockLibraryBase.ClearError;
begin
end;

function TMockLibraryBase.GetStatistics: TSSLStatistics;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

procedure TMockLibraryBase.ResetStatistics;
begin
end;

procedure TMockLibraryBase.SetLogCallback(aCallback: TSSLLogCallback);
begin
end;

procedure TMockLibraryBase.Log(aLevel: TSSLLogLevel; const aMessage: string);
begin
end;

function TMockLibraryBase.CreateContext(aType: TSSLContextType): ISSLContext;
begin
  Result := TMockContext.Create(aType, GetLibraryType);
end;

function TMockLibraryBase.CreateCertificate: ISSLCertificate;
begin
  Result := nil;
end;

function TMockLibraryBase.CreateCertificateStore: ISSLCertificateStore;
begin
  Result := nil;
end;

function TMockOpenSSLLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslOpenSSL;
end;

function TMockOpenSSLLibrary.GetVersionString: string;
begin
  Result := 'MockOpenSSL';
end;

function TMockOpenSSLLibrary.GetCapabilities: TSSLBackendCapabilities;
begin
  Result := BuildMockCapabilities(sslOpenSSL, sslImplCLibrary, 2);
end;

function TMockWinSSLLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslWinSSL;
end;

function TMockWinSSLLibrary.GetVersionString: string;
begin
  Result := 'MockWinSSL';
end;

function TMockWinSSLLibrary.GetCapabilities: TSSLBackendCapabilities;
begin
  Result := BuildMockCapabilities(sslWinSSL, sslImplOSNative, 1);
end;

var
  LBaseRequirements: TSSLRequirements;
  LPreferredRequirements: TSSLRequirements;
  LBaselineMatches: TSSLBackendMatchArray;
  LPreferredMatches: TSSLBackendMatchArray;
  LSelectedType: TSSLLibraryType;
  LSelectedScore: Integer;
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LNativeAccess: ISSLNativeHandleAccess;
begin
  WriteLn('Testing Auto-Backend OS-Native Preference Truth Contract');
  WriteLn('========================================================');

  RegisterMockPreferenceBackends;
  try
    LBaseRequirements := CreateDefaultRequirements(optBalanced);
    LBaseRequirements.MinSecurityScore := 0;
    LBaseRequirements.MinPerformanceScore := 0;
    LBaseRequirements.MinCompatibilityLevel := 0;

    LPreferredRequirements := LBaseRequirements;
    LPreferredRequirements.PlatformPreferences.PreferOSNative := True;

    LBaselineMatches := SelectBestBackends(LBaseRequirements, 0);
    LPreferredMatches := SelectBestBackends(LPreferredRequirements, 0);

    RequireScoreAndSelectionTruth(LBaselineMatches, LPreferredMatches);

    Require(SelectBestBackend(LPreferredRequirements, LSelectedType, LSelectedScore),
      'SelectBestBackend must succeed for OS-native preferred requirements');
    Require(LSelectedType = sslWinSSL,
      'PreferOSNative must select the OS-native mock backend in the controlled scenario');
    Require(LSelectedScore = LPreferredMatches[0].MatchScore,
      'SelectBestBackend score must match the top-ranked preferred candidate');

    LBuilder := TSSLContextBuilder.Create.WithAutoBackendSelection(LPreferredRequirements);
    LResult := LBuilder.TryBuildClient(LContext);

    Require(LResult.IsOk,
      'Auto-backend builder must succeed for OS-native preferred requirements');
    Require(LContext <> nil,
      'Context must be created for OS-native preferred requirements');
    Require(Supports(LContext, ISSLNativeHandleAccess, LNativeAccess),
      'Mock context must expose backend identity through ISSLNativeHandleAccess');
    if Supports(LContext, ISSLNativeHandleAccess, LNativeAccess) then
      Require(LNativeAccess.GetBackendType = sslWinSSL,
        'Builder context must use the OS-native backend selected by the selector');

    WriteLn('✅ Auto-backend OS-native preference truth contract verified');
  finally
    ResetRegisteredBackends;
  end;
end.
