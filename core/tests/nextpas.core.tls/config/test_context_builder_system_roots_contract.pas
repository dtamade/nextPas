program test_context_builder_system_roots_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.context.builder;

type
  IInspectableCertificateStore = interface
    ['{2E9A9A2F-D44C-4A85-B76C-0EE08FD7B171}']
    function GetBackendType: TSSLLibraryType;
    function GetLoadSystemStoreCount: Integer;
  end;

  IInspectableContext = interface
    ['{A90600F7-F954-43B4-A601-C8B2465E6A7A}']
    function GetSetCertificateStoreCount: Integer;
    function GetLastStoreBackendType: TSSLLibraryType;
    function GetLastStoreLoadSystemStoreCount: Integer;
  end;

  TMockCertificateStore = class(TInterfacedObject, ISSLCertificateStore, IInspectableCertificateStore)
  private
    FBackendType: TSSLLibraryType;
    FLoadSystemStoreCount: Integer;
  public
    constructor Create(ABackendType: TSSLLibraryType);

    function AddCertificate(ACert: ISSLCertificate): Boolean;
    function RemoveCertificate(ACert: ISSLCertificate): Boolean;
    function Contains(ACert: ISSLCertificate): Boolean;
    procedure Clear;
    function GetCount: Integer;
    function GetCertificate(AIndex: Integer): ISSLCertificate;
    function LoadFromFile(const AFileName: string): Boolean;
    function LoadFromPath(const APath: string): Boolean;
    function LoadSystemStore: Boolean;
    function FindBySubject(const ASubject: string): ISSLCertificate;
    function FindByIssuer(const AIssuer: string): ISSLCertificate;
    function FindBySerialNumber(const ASerialNumber: string): ISSLCertificate;
    function FindByFingerprint(const AFingerprint: string): ISSLCertificate;
    function VerifyCertificate(ACert: ISSLCertificate): Boolean;
    function BuildCertificateChain(ACert: ISSLCertificate): TSSLCertificateArray;

    function GetBackendType: TSSLLibraryType;
    function GetLoadSystemStoreCount: Integer;
  end;

  TMockContext = class(TInterfacedObject, ISSLContext, IInspectableContext)
  private
    FContextType: TSSLContextType;
    FSetCertificateStoreCount: Integer;
    FLastStoreBackendType: TSSLLibraryType;
    FLastStoreLoadSystemStoreCount: Integer;
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

    function GetSetCertificateStoreCount: Integer;
    function GetLastStoreBackendType: TSSLLibraryType;
    function GetLastStoreLoadSystemStoreCount: Integer;
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
    function CreateContext(aType: TSSLContextType): ISSLContext;
    function CreateCertificate: ISSLCertificate;
    function CreateCertificateStore: ISSLCertificateStore;
  end;

  TMockOpenSSLLibrary = class(TMockLibraryBase)
  public
    function GetLibraryType: TSSLLibraryType; override;
    function GetVersionString: string; override;
  end;

  TMockMbedTLSLibrary = class(TMockLibraryBase)
  public
    function GetLibraryType: TSSLLibraryType; override;
    function GetVersionString: string; override;
  end;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('[PASS] ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

procedure CheckEqualsInt(const AMessage: string; AExpected, AActual: Integer);
begin
  Check(AExpected = AActual,
    AMessage + ' (expected=' + IntToStr(AExpected) + ', actual=' + IntToStr(AActual) + ')');
end;

procedure CheckEqualsBackend(const AMessage: string; AExpected, AActual: TSSLLibraryType);
begin
  Check(AExpected = AActual,
    AMessage + ' (expected=' + SSL_LIBRARY_NAMES[AExpected] + ', actual=' + SSL_LIBRARY_NAMES[AActual] + ')');
end;

constructor TMockCertificateStore.Create(ABackendType: TSSLLibraryType);
begin
  inherited Create;
  FBackendType := ABackendType;
  FLoadSystemStoreCount := 0;
end;

function TMockCertificateStore.AddCertificate(ACert: ISSLCertificate): Boolean;
begin
  Result := True;
end;

function TMockCertificateStore.RemoveCertificate(ACert: ISSLCertificate): Boolean;
begin
  Result := True;
end;

function TMockCertificateStore.Contains(ACert: ISSLCertificate): Boolean;
begin
  Result := False;
end;

procedure TMockCertificateStore.Clear;
begin
end;

function TMockCertificateStore.GetCount: Integer;
begin
  Result := 0;
end;

function TMockCertificateStore.GetCertificate(AIndex: Integer): ISSLCertificate;
begin
  Result := nil;
end;

function TMockCertificateStore.LoadFromFile(const AFileName: string): Boolean;
begin
  Result := True;
end;

function TMockCertificateStore.LoadFromPath(const APath: string): Boolean;
begin
  Result := True;
end;

function TMockCertificateStore.LoadSystemStore: Boolean;
begin
  Inc(FLoadSystemStoreCount);
  Result := True;
end;

function TMockCertificateStore.FindBySubject(const ASubject: string): ISSLCertificate;
begin
  Result := nil;
end;

function TMockCertificateStore.FindByIssuer(const AIssuer: string): ISSLCertificate;
begin
  Result := nil;
end;

function TMockCertificateStore.FindBySerialNumber(const ASerialNumber: string): ISSLCertificate;
begin
  Result := nil;
end;

function TMockCertificateStore.FindByFingerprint(const AFingerprint: string): ISSLCertificate;
begin
  Result := nil;
end;

function TMockCertificateStore.VerifyCertificate(ACert: ISSLCertificate): Boolean;
begin
  Result := True;
end;

function TMockCertificateStore.BuildCertificateChain(ACert: ISSLCertificate): TSSLCertificateArray;
begin
  SetLength(Result, 0);
end;

function TMockCertificateStore.GetBackendType: TSSLLibraryType;
begin
  Result := FBackendType;
end;

function TMockCertificateStore.GetLoadSystemStoreCount: Integer;
begin
  Result := FLoadSystemStoreCount;
end;

constructor TMockContext.Create(AContextType: TSSLContextType);
begin
  inherited Create;
  FContextType := AContextType;
  FSetCertificateStoreCount := 0;
  FLastStoreBackendType := sslAutoDetect;
  FLastStoreLoadSystemStoreCount := 0;
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
  Result := [];
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
var
  LStore: IInspectableCertificateStore;
begin
  Inc(FSetCertificateStoreCount);
  if not Supports(AStore, IInspectableCertificateStore, LStore) then
    raise Exception.Create('Unexpected certificate store implementation in mock context');

  FLastStoreBackendType := LStore.GetBackendType;
  FLastStoreLoadSystemStoreCount := LStore.GetLoadSystemStoreCount;
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

function TMockContext.GetSetCertificateStoreCount: Integer;
begin
  Result := FSetCertificateStoreCount;
end;

function TMockContext.GetLastStoreBackendType: TSSLLibraryType;
begin
  Result := FLastStoreBackendType;
end;

function TMockContext.GetLastStoreLoadSystemStoreCount: Integer;
begin
  Result := FLastStoreLoadSystemStoreCount;
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
  Result := True;
end;

function TMockLibraryBase.IsCipherSupported(const aCipherName: string): Boolean;
begin
  Result := True;
end;

function TMockLibraryBase.IsFeatureSupported(aFeature: TSSLFeature): Boolean;
begin
  Result := True;
end;

function TMockLibraryBase.GetCapabilities: TSSLBackendCapabilities;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.BackendType := GetLibraryType;
  Result.MinTLSVersion := sslProtocolTLS12;
  Result.MaxTLSVersion := sslProtocolTLS13;
  Result.SupportsSystemCertStore := True;
end;

procedure TMockLibraryBase.SetDefaultConfig(const aConfig: TSSLConfig);
begin
end;

function TMockLibraryBase.GetDefaultConfig: TSSLConfig;
begin
  FillChar(Result, SizeOf(Result), 0);
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
  Result := TMockContext.Create(aType);
end;

function TMockLibraryBase.CreateCertificate: ISSLCertificate;
begin
  Result := nil;
end;

function TMockLibraryBase.CreateCertificateStore: ISSLCertificateStore;
begin
  Result := TMockCertificateStore.Create(GetLibraryType);
end;

function TMockOpenSSLLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslOpenSSL;
end;

function TMockOpenSSLLibrary.GetVersionString: string;
begin
  Result := 'MockOpenSSL';
end;

function TMockMbedTLSLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslMbedTLS;
end;

function TMockMbedTLSLibrary.GetVersionString: string;
begin
  Result := 'MockMbedTLS';
end;

procedure ConfigureMockBackends;
begin
  TSSLFactory.ReleaseLibrary(sslOpenSSL);
  TSSLFactory.ReleaseLibrary(sslMbedTLS);
  TSSLFactory.RegisterLibrary(sslOpenSSL, TMockOpenSSLLibrary, 'Mock OpenSSL', 100000);
  TSSLFactory.RegisterLibrary(sslMbedTLS, TMockMbedTLSLibrary, 'Mock MbedTLS', 90000);
  TSSLFactory.SetDefaultLibrary(sslAutoDetect);
end;

procedure Test_ClientExplicitBackendUsesMatchingSystemStore;
var
  LContext: ISSLContext;
  LInspectable: IInspectableContext;
begin
  WriteLn('=== Test 1: BuildClient uses system store from explicit backend ===');
  ConfigureMockBackends;

  LContext := TSSLContextBuilder.Create
    .WithBackend(sslMbedTLS)
    .WithVerifyPeer
    .WithSystemRoots
    .BuildClient;

  Check(Supports(LContext, IInspectableContext, LInspectable),
    'Client context supports inspection');
  if not Supports(LContext, IInspectableContext, LInspectable) then
    Exit;

  CheckEqualsInt('Client build injects one certificate store', 1,
    LInspectable.GetSetCertificateStoreCount);
  CheckEqualsInt('Client build loads system roots before injection', 1,
    LInspectable.GetLastStoreLoadSystemStoreCount);
  CheckEqualsBackend('Client build uses explicit backend store', sslMbedTLS,
    LInspectable.GetLastStoreBackendType);
end;

procedure Test_ServerWithSystemRootsLoadsStore;
var
  LContext: ISSLContext;
  LInspectable: IInspectableContext;
begin
  WriteLn('=== Test 2: BuildServer loads system roots when requested ===');
  ConfigureMockBackends;

  LContext := TSSLContextBuilder.Create
    .WithBackend(sslMbedTLS)
    .WithVerifyPeer
    .WithSystemRoots
    .WithCertificatePEM('mock-cert')
    .WithPrivateKeyPEM('mock-key')
    .BuildServer;

  Check(Supports(LContext, IInspectableContext, LInspectable),
    'Server context supports inspection');
  if not Supports(LContext, IInspectableContext, LInspectable) then
    Exit;

  CheckEqualsInt('Server build injects one certificate store', 1,
    LInspectable.GetSetCertificateStoreCount);
  CheckEqualsInt('Server build loads system roots before injection', 1,
    LInspectable.GetLastStoreLoadSystemStoreCount);
  CheckEqualsBackend('Server build uses explicit backend store', sslMbedTLS,
    LInspectable.GetLastStoreBackendType);
end;

begin
  Randomize;
  Test_ClientExplicitBackendUsesMatchingSystemStore;
  Test_ServerWithSystemRootsLoadsStore;

  WriteLn('---');
  WriteLn('Passed: ', GTestsPassed);
  WriteLn('Failed: ', GTestsFailed);

  if GTestsFailed > 0 then
    Halt(1);
end.
