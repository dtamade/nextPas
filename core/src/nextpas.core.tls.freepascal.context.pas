{**
 * Unit: nextpas.core.tls.freepascal.context
 * Purpose: 纯 FreePascal 后端上下文骨架实现
 *}

unit nextpas.core.tls.freepascal.context;

{$mode ObjFPC}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  nextpas.core.base.utils,
  Base64, SysUtils, Classes,
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.io.intf,
  nextpas.core.io.stream_adapter,
  nextpas.core.io.util,
  nextpas.core.tls.base,
  nextpas.core.tls.errors,
  nextpas.core.tls.logging,
  nextpas.core.tls.freepascal.context.material,
  nextpas.core.tls.freepascal.earlydatareplay,
  nextpas.core.tls.freepascal.session,
  nextpas.core.tls.secure;

type
  TFreePascalPin = record
    Hash: TBytes;
    PinType: Integer;
    Description: string;
    IsBackup: Boolean;
  end;

  TFreePascalResumptionCacheEntry = record
    Key: string;
    Session: ISSLSession;
  end;

  TFreePascalContext = class(TInterfacedObject,
    ISSLContext,
    ISSLHttpHooksAccess,
    ISSLEarlyDataContext,
    ISSLServerOCSPStaplingContext,
    IFreePascalContextMaterial,
    IFreePascalContextTrustStore,
    IFreePascalContextVerifyCallback,
    IFreePascalContextCipherSuites,
    IFreePascalContextPinValidation,
    IFreePascalContextRevocationMaterial,
    IFreePascalContextServerStaplingMaterial,
    IFreePascalContextEarlyDataReplayProviderInstaller,
    IFreePascalContextEarlyDataReplayInstaller,
    IFreePascalContextEarlyDataReplayDirectoryInstaller,
    IFreePascalResumptionCache,
    IFreePascalEarlyDataReplayLedger,
    IFreePascalEarlyDataReplayLedgerAccess)
  private
    FLibrary: ISSLLibrary;
    FContextType: TSSLContextType;
    FProtocolVersions: TSSLProtocolVersions;
    FPreferredVersion: TSSLProtocolVersion;
    FVerifyMode: TSSLVerifyModes;
    FVerifyDepth: Integer;
    FCipherList: string;
    FCipherSuites: string;
    FConfiguredCipherSuites12: TFreePascalCipherSuiteList;
    FConfiguredCipherSuites13: TFreePascalCipherSuiteList;
    FSessionCacheEnabled: Boolean;
    FSessionTimeout: Integer;
    FSessionCacheSize: Integer;
    FOptions: TSSLOptions;
    FServerName: string;
    FALPNProtocols: string;
    FClientEarlyDataEnabled: Boolean;
    FServerEarlyDataPolicy: TSSLEarlyDataServerPolicy;
    FServerMaxEarlyDataSize: Cardinal;
    FCertVerifyFlags: TSSLCertVerifyFlags;
    FVerifyCallback: TSSLVerifyCallback;
    FPasswordCallback: TSSLPasswordCallback;
    FInfoCallback: TSSLInfoCallback;
    FHTTPGetCallback: TSSLHTTPGetCallback;
    FHTTPPostCallback: TSSLHTTPPostCallback;
    FCertificateStore: ISSLCertificateStore;
    FPinningEnabled: Boolean;
    FPins: array of TFreePascalPin;
    FResumptionCache: array of TFreePascalResumptionCacheEntry;
    FResumptionLock: TRTLCriticalSection;
    FDefaultEarlyDataReplayLedger: IFreePascalManagedEarlyDataReplayLedger;
    FActiveEarlyDataReplayLedger: IFreePascalEarlyDataReplayLedger;

    FCertificateFile: string;
    FCertificateData: TBytes;
    FPrivateKeyFile: string;
    FPrivateKeyData: TBytes;
    FCAFile: string;
    FCAPath: string;
    FCRLMaterial: TStringArray;
    FServerStapledOCSPResponse: TBytes;

    function ReadStreamToBytes(AStream: TStream): TBytes;
    function ReadIStreamToBytes(const AStream: IStream; AMaxSize: Int64;
      const AContext: string): TBytes;
    function TicketKey(const ATicket: TBytes): string;
    procedure RefreshConfiguredCipherSuites12;
    procedure RefreshConfiguredCipherSuites13;
    procedure PruneResumptionCache;
    procedure EnforceResumptionCacheLimit;
    procedure DecryptPrivateKeyData(const APassword, AMethodName: string);
    procedure RejectUnsupportedCallbackAssignment(
      const AFeature, AMethodName: string);
  public
    constructor Create(ALibrary: ISSLLibrary; AType: TSSLContextType);
    destructor Destroy; override;

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
    function LoadSystemCertificates: Boolean;
    procedure SetCertificateStore(AStore: ISSLCertificateStore);

    procedure SetVerifyMode(AMode: TSSLVerifyModes);
    function GetVerifyMode: TSSLVerifyModes;
    procedure SetVerifyDepth(ADepth: Integer);
    function GetVerifyDepth: Integer;
    procedure SetVerifyCallback(ACallback: TSSLVerifyCallback);
    function GetVerifyCallback: TSSLVerifyCallback;

    procedure SetCipherList(const ACipherList: string);
    function GetCipherList: string;
    procedure SetCipherSuites(const ACipherSuites: string);
    function GetCipherSuites: string;
    function GetConfiguredCipherSuites13: TFreePascalCipherSuiteList;
    function GetConfiguredCipherSuites12: TFreePascalCipherSuiteList;

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

    procedure SetClientEarlyDataEnabled(AEnabled: Boolean);
    function GetClientEarlyDataEnabled: Boolean;
    procedure SetServerEarlyDataPolicy(APolicy: TSSLEarlyDataServerPolicy);
    function GetServerEarlyDataPolicy: TSSLEarlyDataServerPolicy;
    procedure SetServerMaxEarlyDataSize(ASize: Cardinal);
    function GetServerMaxEarlyDataSize: Cardinal;

    procedure SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
    function GetCertVerifyFlags: TSSLCertVerifyFlags;

    procedure SetPasswordCallback(ACallback: TSSLPasswordCallback);
    procedure SetInfoCallback(ACallback: TSSLInfoCallback);
    procedure SetHTTPGetCallback(ACallback: TSSLHTTPGetCallback);
    function GetHTTPGetCallback: TSSLHTTPGetCallback;
    procedure SetHTTPPostCallback(ACallback: TSSLHTTPPostCallback);
    function GetHTTPPostCallback: TSSLHTTPPostCallback;

    procedure AddCertificatePin(const AHash: TBytes; APinType: Integer;
      const ADescription: string; AIsBackup: Boolean = False);
    procedure AddCertificatePinBase64(const ABase64Hash: string; APinType: Integer;
      const ADescription: string; AIsBackup: Boolean = False);
    procedure SetCertificatePinningEnabled(AEnabled: Boolean);
    function GetCertificatePinningEnabled: Boolean;
    procedure ClearCertificatePins;
    function ValidateCertificatePin(const ACertFingerprint: TBytes): Boolean;

    function CreateConnection(ASocket: THandle): ISSLConnection; overload;
    function CreateConnection(AStream: TStream): ISSLConnection; overload;

    function IsValid: Boolean;

    function HasCertificateMaterial: Boolean;
    function HasPrivateKeyMaterial: Boolean;
    function GetCertificateMaterial: TBytes;
    function GetPrivateKeyMaterial: TBytes;
    function BuildVerificationStore: ISSLCertificateStore;
    procedure ClearCRLMaterial;
    procedure AddCRLPEM(const APEM: string);
    procedure AddCRLFile(const AFileName: string);
    function BuildCRLStore: TStringArray;
    procedure ClearServerStapledOCSPResponse;
    procedure SetServerStapledOCSPResponse(const AResponseDER: TBytes);
    procedure LoadServerStapledOCSPResponseFile(const AFileName: string);
    function HasServerStapledOCSPResponse: Boolean;
    function GetServerStapledOCSPResponse: TBytes;

    function CanIssueSessionTickets: Boolean;
    function TryGetResumptionSession(const ATicket: TBytes; out ASession: ISSLSession): Boolean;
    procedure StoreResumptionSession(ASession: ISSLSession);
    function InstallReplayProviderBackedLedger(
      AProvider: IFreePascalEarlyDataReplayProvider
    ): Boolean;
    function InstallFileBackedReplayLedger(const AFileName: string): Boolean;
    function InstallDirectoryBackedReplayLedger(
      const ADirectoryName: string
    ): Boolean;
    function GetEarlyDataReplayLedger: IFreePascalEarlyDataReplayLedger;
    procedure SetEarlyDataReplayLedger(ALedger: IFreePascalEarlyDataReplayLedger);
    procedure ResetEarlyDataReplayLedger;
    function TryAcquireEarlyDataSession(ASession: ISSLSession): Boolean;
  end;

implementation

uses
  nextpas.core.text.strings,
  nextpas.core.tls.exceptions,
  nextpas.core.mem.secure,
  nextpas.core.tls.utils,
  nextpas.core.crypto.constant_time,
  nextpas.core.crypto.pkcs8,
  nextpas.core.tls.pem,
  nextpas.core.tls.freepascal.earlydatareplay.dirstore,
  nextpas.core.tls.freepascal.earlydatareplay.fileprovider,
  nextpas.core.tls.freepascal.connection,
  nextpas.core.tls.tls12.ciphersuite,
  nextpas.core.tls.tls12.wire,
  nextpas.core.tls.tls13.wire;

type
  TCipherSuiteTokenAppender = procedure(
    var ADest: TFreePascalCipherSuiteList;
    const AName: string
  );

constructor TFreePascalContext.Create(ALibrary: ISSLLibrary; AType: TSSLContextType);
begin
  inherited Create;
  FLibrary := ALibrary;
  FContextType := AType;
  FProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  FPreferredVersion := sslProtocolTLS13;
  FVerifyMode := [sslVerifyPeer];
  FVerifyDepth := SSL_DEFAULT_VERIFY_DEPTH;
  FCipherList := SSL_DEFAULT_CIPHER_LIST;
  FCipherSuites := SSL_DEFAULT_TLS13_CIPHERSUITES;
  SetLength(FConfiguredCipherSuites12, 0);
  SetLength(FConfiguredCipherSuites13, 0);
  FSessionCacheEnabled := True;
  FSessionTimeout := SSL_DEFAULT_SESSION_TIMEOUT;
  FSessionCacheSize := SSL_DEFAULT_SESSION_CACHE_SIZE;
  FOptions := [ssoEnableSessionCache, ssoEnableSessionTickets, ssoEnableSNI, ssoEnableALPN];
  FServerName := '';
  FALPNProtocols := '';
  FClientEarlyDataEnabled := False;
  FServerEarlyDataPolicy := sslEarlyDataServerReject;
  FServerMaxEarlyDataSize := 0;
  FCertVerifyFlags := [sslCertVerifyDefault];
  FVerifyCallback := nil;
  FPasswordCallback := nil;
  FInfoCallback := nil;
  FHTTPGetCallback := nil;
  FHTTPPostCallback := nil;
  FCertificateStore := nil;
  FPinningEnabled := False;
  SetLength(FPins, 0);
  SetLength(FResumptionCache, 0);
  InitCriticalSection(FResumptionLock);
  if AType in [sslCtxServer, sslCtxBoth] then
    FDefaultEarlyDataReplayLedger :=
      TFreePascalDefaultPersistentEarlyDataReplayLedger.Create(
        FSessionCacheEnabled,
        FSessionCacheSize
      )
  else
    FDefaultEarlyDataReplayLedger := TFreePascalInMemoryEarlyDataReplayLedger.Create(
      FSessionCacheEnabled,
      FSessionCacheSize
    );
  FActiveEarlyDataReplayLedger := FDefaultEarlyDataReplayLedger;
  SetLength(FCertificateData, 0);
  SetLength(FPrivateKeyData, 0);
  SetLength(FServerStapledOCSPResponse, 0);
end;

destructor TFreePascalContext.Destroy;
begin
  SecureZeroBytes(FPrivateKeyData);
  DoneCriticalSection(FResumptionLock);
  inherited Destroy;
end;

function TFreePascalContext.ReadStreamToBytes(AStream: TStream): TBytes;
begin
  if AStream = nil then
    RaiseInvalidParameter('AStream');
  Result := ReadIStreamToBytes(WrapTStream(AStream, False), High(Int64), 'AStream');
end;

function TFreePascalContext.ReadIStreamToBytes(const AStream: IStream;
  AMaxSize: Int64; const AContext: string): TBytes;
begin
  if AStream = nil then
    RaiseInvalidParameter(AContext);
  Result := IoReadAllLimited(AStream, AMaxSize);
end;

function TFreePascalContext.TicketKey(const ATicket: TBytes): string;
const
  HEX_DIGITS: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, Length(ATicket) * 2);
  for I := 0 to High(ATicket) do
  begin
    Result[I * 2 + 1] := HEX_DIGITS[(ATicket[I] shr 4) and $0F];
    Result[I * 2 + 2] := HEX_DIGITS[ATicket[I] and $0F];
  end;
end;

function CloneCipherSuiteList(const ASource: TFreePascalCipherSuiteList): TFreePascalCipherSuiteList;
begin
  Result := Copy(ASource, 0, Length(ASource));
end;

function NormalizeCipherSuiteName(const AName: string): string;
begin
  Result := UpperCase(Trim(AName));
  if Pos('TLS_', Result) = 1 then
    Delete(Result, 1, 4);
  Result := StringReplace(Result, '_', '-', [rfReplaceAll]);
  Result := StringReplace(Result, '-WITH-', '-', []);
  Result := StringReplace(Result, 'AES-128', 'AES128', []);
  Result := StringReplace(Result, 'AES-256', 'AES256', []);
end;

function TryAppendUniqueCipherSuite(
  var ADest: TFreePascalCipherSuiteList;
  AValue: Word
): Boolean;
var
  I: Integer;
begin
  Result := False;
  if AValue = 0 then
    Exit;

  for I := 0 to High(ADest) do
    if ADest[I] = AValue then
      Exit;

  SetLength(ADest, Length(ADest) + 1);
  ADest[High(ADest)] := AValue;
  Result := True;
end;

procedure AppendTLS12TokenSuites(
  var ADest: TFreePascalCipherSuiteList;
  const AName: string
);
var
  LName: string;
begin
  LName := NormalizeCipherSuiteName(AName);

  case LName of
    'ECDHE-RSA-AES128-GCM-SHA256':
      TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256);
    'ECDHE-RSA-AES256-GCM-SHA384':
      TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_GCM_SHA384);
    'ECDHE-ECDSA-AES128-GCM-SHA256':
      TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256);
    'ECDHE-ECDSA-AES256-GCM-SHA384':
      TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384);
    'ECDHE-RSA-AES128-CBC-SHA256':
      TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_CBC_SHA256);
    'ECDHE-RSA-AES256-CBC-SHA384':
      TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_CBC_SHA384);
    'ECDHE-RSA-CHACHA20-POLY1305-SHA256':
      TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256);
    'ECDHE-ECDSA-CHACHA20-POLY1305-SHA256':
      TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256);
    'ECDHE+AESGCM':
      begin
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256);
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_GCM_SHA384);
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256);
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384);
      end;
    'ECDHE+AES256':
      begin
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_GCM_SHA384);
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384);
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_CBC_SHA384);
      end;
    'ECDHE+CHACHA20':
      begin
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256);
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256);
      end;
    'ECDHE':
      begin
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256);
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256);
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256);
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_GCM_SHA384);
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256);
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384);
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_CBC_SHA256);
        TryAppendUniqueCipherSuite(ADest, TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_CBC_SHA384);
      end;
  else
    { Ignore OpenSSL-style deny-list and unsupported selector tokens. }
  end;
end;

procedure AppendTLS13TokenSuites(
  var ADest: TFreePascalCipherSuiteList;
  const AName: string
);
var
  LName: string;
begin
  LName := NormalizeCipherSuiteName(AName);

  case LName of
    'AES128-GCM-SHA256':
      TryAppendUniqueCipherSuite(ADest, TLS13_CIPHER_AES_128_GCM_SHA256);
    'AES256-GCM-SHA384':
      TryAppendUniqueCipherSuite(ADest, TLS13_CIPHER_AES_256_GCM_SHA384);
    'CHACHA20-POLY1305-SHA256':
      TryAppendUniqueCipherSuite(ADest, TLS13_CIPHER_CHACHA20_POLY1305_SHA256);
  else
    { Ignore unsupported selector tokens. }
  end;
end;

procedure ParseColonSeparatedCipherSuites(
  const ACipherString: string;
  AAppendToken: TCipherSuiteTokenAppender;
  var ADest: TFreePascalCipherSuiteList
);
var
  I: Integer;
  LStart: Integer;
  LStop: Integer;
  LValue: string;
begin
  SetLength(ADest, 0);
  LStart := 1;

  for I := 1 to Length(ACipherString) + 1 do
  begin
    if (I <= Length(ACipherString)) and (ACipherString[I] <> ':') then
      Continue;

    LStop := I - 1;
    while (LStart <= LStop) and (ACipherString[LStart] in [' ', #9, #10, #13]) do
      Inc(LStart);
    while (LStop >= LStart) and (ACipherString[LStop] in [' ', #9, #10, #13]) do
      Dec(LStop);

    if LStop >= LStart then
    begin
      LValue := Copy(ACipherString, LStart, LStop - LStart + 1);
      AAppendToken(ADest, LValue);
    end;

    LStart := I + 1;
  end;
end;

procedure TFreePascalContext.RefreshConfiguredCipherSuites12;
begin
  if (Trim(FCipherList) = '') or SameText(Trim(FCipherList), SSL_DEFAULT_CIPHER_LIST) then
  begin
    SetLength(FConfiguredCipherSuites12, 0);
    Exit;
  end;

  ParseColonSeparatedCipherSuites(
    FCipherList,
    @AppendTLS12TokenSuites,
    FConfiguredCipherSuites12
  );
end;

procedure TFreePascalContext.RefreshConfiguredCipherSuites13;
begin
  if (Trim(FCipherSuites) = '') or SameText(Trim(FCipherSuites), SSL_DEFAULT_TLS13_CIPHERSUITES) then
  begin
    SetLength(FConfiguredCipherSuites13, 0);
    Exit;
  end;

  ParseColonSeparatedCipherSuites(
    FCipherSuites,
    @AppendTLS13TokenSuites,
    FConfiguredCipherSuites13
  );
end;

procedure TFreePascalContext.PruneResumptionCache;
var
  I: Integer;
  LWriteIndex: Integer;
begin
  LWriteIndex := 0;
  for I := 0 to High(FResumptionCache) do
    if (FResumptionCache[I].Key <> '') and
      (FResumptionCache[I].Session <> nil) and
      FResumptionCache[I].Session.IsValid then
    begin
      if LWriteIndex <> I then
        FResumptionCache[LWriteIndex] := FResumptionCache[I];
      Inc(LWriteIndex);
    end;
  SetLength(FResumptionCache, LWriteIndex);
end;

procedure TFreePascalContext.EnforceResumptionCacheLimit;
var
  I: Integer;
  LOverflow: Integer;
begin
  if FSessionCacheSize <= 0 then
  begin
    SetLength(FResumptionCache, 0);
    Exit;
  end;

  if Length(FResumptionCache) <= FSessionCacheSize then
    Exit;

  LOverflow := Length(FResumptionCache) - FSessionCacheSize;
  for I := 0 to FSessionCacheSize - 1 do
    FResumptionCache[I] := FResumptionCache[I + LOverflow];
  SetLength(FResumptionCache, FSessionCacheSize);
end;

function TFreePascalContext.GetContextType: TSSLContextType;
begin
  Result := FContextType;
end;

procedure TFreePascalContext.SetProtocolVersions(AVersions: TSSLProtocolVersions);
begin
  FProtocolVersions := AVersions;

  if (FPreferredVersion <> sslProtocolUnknown) and
    not (FPreferredVersion in FProtocolVersions) then
    FPreferredVersion := sslProtocolUnknown;

  LogDeprecatedProtocolWarnings('FreePascal', AVersions);
end;

function TFreePascalContext.GetProtocolVersions: TSSLProtocolVersions;
begin
  Result := FProtocolVersions;
end;

procedure TFreePascalContext.SetPreferredVersion(AVersion: TSSLProtocolVersion);
begin
  if (AVersion <> sslProtocolUnknown) and
    not (AVersion in FProtocolVersions) then
    RaiseInvalidParameter('PreferredVersion');

  FPreferredVersion := AVersion;
end;

function TFreePascalContext.GetPreferredVersion: TSSLProtocolVersion;
begin
  Result := FPreferredVersion;
end;

procedure TFreePascalContext.LoadCertificate(const AFileName: string);
var
  LStream: TFileStream;
  LSize: Int64;
begin
  if AFileName = '' then
    RaiseInvalidParameter('AFileName');

  if not nextpas.core.fs.IsFile(AFileName) then
    raise ESSLFileNotFoundException.CreateWithContext(
      nextpas.core.text.conv.Format('Certificate file not found: %s', [AFileName]),
      sslErrLoadFailed,
      'TFreePascalContext.LoadCertificate',
      0,
      sslFreePascal
    );

  LSize := GetFileSizeByName(AFileName);
  if LSize > MAX_CERTIFICATE_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'Certificate file exceeds maximum allowed size (%d > %d bytes): %s',
      [LSize, MAX_CERTIFICATE_SIZE, AFileName]);

  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    FCertificateData := ReadStreamToBytes(LStream);
    FCertificateFile := AFileName;
  finally
  end;
end;

procedure TFreePascalContext.LoadCertificate(AStream: TStream);
var
  LTransport: IStream;
begin
  if AStream = nil then
    RaiseInvalidParameter('AStream');
  LTransport := WrapTStream(AStream, False);
  FCertificateData := ReadIStreamToBytes(LTransport, MAX_CERTIFICATE_SIZE, 'AStream');
end;

procedure TFreePascalContext.LoadCertificate(ACert: ISSLCertificate);
begin
  if ACert = nil then
    RaiseInvalidParameter('ACert');
  FCertificateData := ACert.SaveToDER;
end;

procedure TFreePascalContext.LoadPrivateKey(const AFileName: string; const APassword: string);
var
  LStream: TFileStream;
  LSize: Int64;
begin
  if AFileName = '' then
    RaiseInvalidParameter('AFileName');

  if not nextpas.core.fs.IsFile(AFileName) then
    raise ESSLFileNotFoundException.CreateWithContext(
      nextpas.core.text.conv.Format('Private key file not found: %s', [AFileName]),
      sslErrLoadFailed,
      'TFreePascalContext.LoadPrivateKey',
      0,
      sslFreePascal
    );

  LSize := GetFileSizeByName(AFileName);
  if LSize > MAX_PRIVATE_KEY_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'Private key file exceeds maximum allowed size (%d > %d bytes): %s',
      [LSize, MAX_PRIVATE_KEY_SIZE, AFileName]);

  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    FPrivateKeyData := ReadStreamToBytes(LStream);
    FPrivateKeyFile := AFileName;
  finally
    LStream.Free;
  end;

  if APassword <> '' then
    DecryptPrivateKeyData(APassword, 'TFreePascalContext.LoadPrivateKey');
end;

procedure TFreePascalContext.LoadPrivateKey(AStream: TStream; const APassword: string);
var
  LTransport: IStream;
begin
  if AStream = nil then
    RaiseInvalidParameter('AStream');
  LTransport := WrapTStream(AStream, False);
  FPrivateKeyData := ReadIStreamToBytes(LTransport, MAX_PRIVATE_KEY_SIZE, 'AStream');
  if APassword <> '' then
    DecryptPrivateKeyData(APassword, 'TFreePascalContext.LoadPrivateKey(AStream)');
end;

procedure TFreePascalContext.LoadCertificatePEM(const APEM: string);
var
  LAnsi: AnsiString;
begin
  if Length(APEM) = 0 then
    RaiseInvalidParameter('APEM');
  if Length(APEM) > MAX_CERTIFICATE_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'Certificate PEM exceeds maximum allowed size (%d > %d bytes)',
      [Length(APEM), MAX_CERTIFICATE_SIZE]);
  LAnsi := AnsiString(APEM);
  SetLength(FCertificateData, Length(LAnsi));
  if Length(LAnsi) > 0 then
    Move(LAnsi[1], FCertificateData[0], Length(LAnsi));
end;

procedure TFreePascalContext.LoadPrivateKeyPEM(const APEM: string; const APassword: string);
var
  LAnsi: AnsiString;
begin
  if Length(APEM) = 0 then
    RaiseInvalidParameter('APEM');
  if Length(APEM) > MAX_PRIVATE_KEY_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'Private key PEM exceeds maximum allowed size (%d > %d bytes)',
      [Length(APEM), MAX_PRIVATE_KEY_SIZE]);
  LAnsi := AnsiString(APEM);
  SetLength(FPrivateKeyData, Length(LAnsi));
  if Length(LAnsi) > 0 then
    Move(LAnsi[1], FPrivateKeyData[0], Length(LAnsi));

  if APassword <> '' then
    DecryptPrivateKeyData(APassword, 'TFreePascalContext.LoadPrivateKeyPEM');
end;

procedure TFreePascalContext.LoadCAFile(const AFileName: string);
var
  LSize: Int64;
begin
  if AFileName = '' then
    RaiseInvalidParameter('AFileName');

  if not nextpas.core.fs.IsFile(AFileName) then
    raise ESSLFileNotFoundException.CreateWithContext(
      nextpas.core.text.conv.Format('CA file not found: %s', [AFileName]),
      sslErrLoadFailed,
      'TFreePascalContext.LoadCAFile',
      0,
      sslFreePascal
    );

  LSize := GetFileSizeByName(AFileName);
  if LSize > MAX_CA_CHAIN_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'CA file exceeds maximum allowed size (%d > %d bytes): %s',
      [LSize, MAX_CA_CHAIN_SIZE, AFileName]);

  FCAFile := AFileName;
end;

procedure TFreePascalContext.LoadCAPath(const APath: string);
begin
  if not nextpas.core.fs.IsDir(APath) then
    raise ESSLFileNotFoundException.CreateWithContext(
      nextpas.core.text.conv.Format('CA path not found: %s', [APath]),
      sslErrLoadFailed,
      'TFreePascalContext.LoadCAPath',
      0,
      sslFreePascal
    );

  FCAPath := APath;
end;

function TFreePascalContext.LoadSystemCertificates: Boolean;
var
  LStore: ISSLCertificateStore;
begin
  Result := False;
  if FLibrary = nil then
    Exit;
  LStore := FLibrary.CreateCertificateStore;
  if LStore = nil then
    Exit;
  if not LStore.LoadSystemStore then
    Exit;
  FCertificateStore := LStore;
  Result := True;
end;

procedure TFreePascalContext.SetCertificateStore(AStore: ISSLCertificateStore);
begin
  FCertificateStore := AStore;
end;

procedure TFreePascalContext.SetVerifyMode(AMode: TSSLVerifyModes);
begin
  FVerifyMode := AMode;
end;

function TFreePascalContext.GetVerifyMode: TSSLVerifyModes;
begin
  Result := FVerifyMode;
end;

procedure TFreePascalContext.SetVerifyDepth(ADepth: Integer);
begin
  if ADepth < 0 then
    RaiseInvalidParameter('VerifyDepth');
  FVerifyDepth := ADepth;
end;

function TFreePascalContext.GetVerifyDepth: Integer;
begin
  Result := FVerifyDepth;
end;

procedure TFreePascalContext.DecryptPrivateKeyData(
  const APassword, AMethodName: string);
var
  LReader: TPEMReader;
  LBlock: TPEMBlock;
  LDecrypted: TBytes;
  LError: string;
  LDEKInfo, LAlgorithm, LIVHex: string;
  LCommaPos, I: Integer;
  LPEMText: string;
begin
  if Length(FPrivateKeyData) = 0 then
    Exit;

  LPEMText := nextpas.core.text.conv.UTF8BytesToString(FPrivateKeyData);
  LReader := TPEMReader.Create;
  try
    LReader.LoadFromString(LPEMText);
    if LReader.BlockCount = 0 then
      raise ESSLConfigurationException.CreateWithContext(
        'No PEM block found in private key data',
        sslErrLoadFailed, AMethodName, 0, sslFreePascal);

    LBlock := LReader.GetBlock(0);

    if LBlock.BlockType = pemEncryptedPrivateKey then
    begin
      if not TryDecryptPKCS8EncryptedPrivateKey(LBlock.Data, APassword, LDecrypted, LError) then
        raise ESSLConfigurationException.CreateWithContext(
          'Failed to decrypt PKCS#8 private key: ' + LError,
          sslErrLoadFailed, AMethodName, 0, sslFreePascal);
      FPrivateKeyData := LDecrypted;
    end
    else if LBlock.IsEncrypted and (LBlock.Headers <> nil) then
    begin
      LDEKInfo := '';
      for I := 0 to LBlock.Length(Headers) - 1 do
      begin
        if Pos('DEK-Info:', LBlock.Headers[I]) = 1 then
        begin
          LDEKInfo := Trim(Copy(LBlock.Headers[I], 10, Length(LBlock.Headers[I])));
          Break;
        end;
      end;

      if LDEKInfo = '' then
        raise ESSLConfigurationException.CreateWithContext(
          'Encrypted PEM missing DEK-Info header',
          sslErrLoadFailed, AMethodName, 0, sslFreePascal);

      LCommaPos := Pos(',', LDEKInfo);
      if LCommaPos = 0 then
        raise ESSLConfigurationException.CreateWithContext(
          'Invalid DEK-Info format',
          sslErrLoadFailed, AMethodName, 0, sslFreePascal);

      LAlgorithm := Copy(LDEKInfo, 1, LCommaPos - 1);
      LIVHex := Copy(LDEKInfo, LCommaPos + 1, Length(LDEKInfo));

      if not TryDecryptTraditionalPEMPrivateKey(
        LBlock.Data, LAlgorithm, LIVHex, APassword, LDecrypted, LError
      ) then
        raise ESSLConfigurationException.CreateWithContext(
          'Failed to decrypt traditional PEM private key: ' + LError,
          sslErrLoadFailed, AMethodName, 0, sslFreePascal);
      FPrivateKeyData := LDecrypted;
    end
    else
      raise ESSLConfigurationException.CreateWithContext(
        'Private key does not appear to be encrypted, but a password was provided',
        sslErrLoadFailed, AMethodName, 0, sslFreePascal);
  finally
  end;
end;

procedure TFreePascalContext.RejectUnsupportedCallbackAssignment(
  const AFeature, AMethodName: string);
begin
  raise ESSLConfigurationException.CreateWithContext(
    nextpas.core.text.conv.Format('%s is not published by the current FreePascal backend runtime. ' +
      'The FreePascal backend currently publishes verify callback wiring; password/info callback kinds remain unsupported.',
      [AFeature]),
    sslErrUnsupported,
    AMethodName,
    0,
    sslFreePascal
  );
end;

procedure TFreePascalContext.SetVerifyCallback(ACallback: TSSLVerifyCallback);
begin
  FVerifyCallback := ACallback;
end;

function TFreePascalContext.GetVerifyCallback: TSSLVerifyCallback;
begin
  Result := FVerifyCallback;
end;

procedure TFreePascalContext.SetCipherList(const ACipherList: string);
begin
  FCipherList := ACipherList;
  RefreshConfiguredCipherSuites12;
  if (Trim(ACipherList) <> '') and
    (not SameText(Trim(ACipherList), SSL_DEFAULT_CIPHER_LIST)) and
    (Length(FConfiguredCipherSuites12) = 0) then
    raise ESSLConfigurationException.CreateWithContext(
      'Cipher list does not contain any TLS 1.2 cipher suite supported by the FreePascal backend.',
      sslErrInvalidParam,
      'TFreePascalContext.SetCipherList',
      0,
      sslFreePascal
    );
end;

function TFreePascalContext.GetCipherList: string;
begin
  Result := FCipherList;
end;

procedure TFreePascalContext.SetCipherSuites(const ACipherSuites: string);
begin
  FCipherSuites := ACipherSuites;
  RefreshConfiguredCipherSuites13;
  if (Trim(ACipherSuites) <> '') and
    (not SameText(Trim(ACipherSuites), SSL_DEFAULT_TLS13_CIPHERSUITES)) and
    (Length(FConfiguredCipherSuites13) = 0) then
    raise ESSLConfigurationException.CreateWithContext(
      'Cipher suites string does not contain any TLS 1.3 cipher suite supported by the FreePascal backend.',
      sslErrInvalidParam,
      'TFreePascalContext.SetCipherSuites',
      0,
      sslFreePascal
    );
end;

function TFreePascalContext.GetCipherSuites: string;
begin
  Result := FCipherSuites;
end;

function TFreePascalContext.GetConfiguredCipherSuites13: TFreePascalCipherSuiteList;
begin
  Result := CloneCipherSuiteList(FConfiguredCipherSuites13);
end;

function TFreePascalContext.GetConfiguredCipherSuites12: TFreePascalCipherSuiteList;
begin
  Result := CloneCipherSuiteList(FConfiguredCipherSuites12);
end;

procedure TFreePascalContext.SetSessionCacheMode(AEnabled: Boolean);
var
  LManagedLedger: IFreePascalManagedEarlyDataReplayLedger;
begin
  FSessionCacheEnabled := AEnabled;
  if not AEnabled then
    SetLength(FResumptionCache, 0);

  if FDefaultEarlyDataReplayLedger <> nil then
    FDefaultEarlyDataReplayLedger.SetEnabled(AEnabled);

  if Supports(FActiveEarlyDataReplayLedger, IFreePascalManagedEarlyDataReplayLedger, LManagedLedger) then
    LManagedLedger.SetEnabled(AEnabled);
end;

function TFreePascalContext.GetSessionCacheMode: Boolean;
begin
  Result := FSessionCacheEnabled;
end;

procedure TFreePascalContext.SetSessionTimeout(ATimeout: Integer);
begin
  if ATimeout < 0 then
    RaiseInvalidParameter('SessionTimeout');
  FSessionTimeout := ATimeout;
end;

function TFreePascalContext.GetSessionTimeout: Integer;
begin
  Result := FSessionTimeout;
end;

procedure TFreePascalContext.SetSessionCacheSize(ASize: Integer);
var
  LManagedLedger: IFreePascalManagedEarlyDataReplayLedger;
begin
  if ASize < 0 then
    RaiseInvalidParameter('SessionCacheSize');
  FSessionCacheSize := ASize;
  EnforceResumptionCacheLimit;

  if FDefaultEarlyDataReplayLedger <> nil then
    FDefaultEarlyDataReplayLedger.SetCapacity(ASize);

  if Supports(FActiveEarlyDataReplayLedger, IFreePascalManagedEarlyDataReplayLedger, LManagedLedger) then
    LManagedLedger.SetCapacity(ASize);
end;

function TFreePascalContext.GetSessionCacheSize: Integer;
begin
  Result := FSessionCacheSize;
end;

procedure TFreePascalContext.SetOptions(const AOptions: TSSLOptions);
begin
  FOptions := AOptions;
end;

function TFreePascalContext.GetOptions: TSSLOptions;
begin
  Result := FOptions;
end;

procedure TFreePascalContext.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
end;

function TFreePascalContext.GetServerName: string;
begin
  Result := FServerName;
end;

procedure TFreePascalContext.SetALPNProtocols(const AProtocols: string);
begin
  FALPNProtocols := AProtocols;
end;

function TFreePascalContext.GetALPNProtocols: string;
begin
  Result := FALPNProtocols;
end;

procedure TFreePascalContext.SetClientEarlyDataEnabled(AEnabled: Boolean);
begin
  FClientEarlyDataEnabled := AEnabled;
end;

function TFreePascalContext.GetClientEarlyDataEnabled: Boolean;
begin
  Result := FClientEarlyDataEnabled;
end;

procedure TFreePascalContext.SetServerEarlyDataPolicy(APolicy: TSSLEarlyDataServerPolicy);
begin
  FServerEarlyDataPolicy := APolicy;
end;

function TFreePascalContext.GetServerEarlyDataPolicy: TSSLEarlyDataServerPolicy;
begin
  Result := FServerEarlyDataPolicy;
end;

procedure TFreePascalContext.SetServerMaxEarlyDataSize(ASize: Cardinal);
begin
  FServerMaxEarlyDataSize := ASize;
end;

function TFreePascalContext.GetServerMaxEarlyDataSize: Cardinal;
begin
  Result := FServerMaxEarlyDataSize;
end;

procedure TFreePascalContext.SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
begin
  FCertVerifyFlags := AFlags;
end;

function TFreePascalContext.GetCertVerifyFlags: TSSLCertVerifyFlags;
begin
  Result := FCertVerifyFlags;
end;

procedure TFreePascalContext.SetPasswordCallback(ACallback: TSSLPasswordCallback);
begin
  if Assigned(ACallback) then
    RejectUnsupportedCallbackAssignment('Password callback', 'TFreePascalContext.SetPasswordCallback');
  FPasswordCallback := nil;
end;

procedure TFreePascalContext.SetInfoCallback(ACallback: TSSLInfoCallback);
begin
  if Assigned(ACallback) then
    RejectUnsupportedCallbackAssignment('Info callback', 'TFreePascalContext.SetInfoCallback');
  FInfoCallback := nil;
end;

procedure TFreePascalContext.SetHTTPGetCallback(ACallback: TSSLHTTPGetCallback);
begin
  FHTTPGetCallback := ACallback;
end;

function TFreePascalContext.GetHTTPGetCallback: TSSLHTTPGetCallback;
begin
  Result := FHTTPGetCallback;
end;

procedure TFreePascalContext.SetHTTPPostCallback(ACallback: TSSLHTTPPostCallback);
begin
  FHTTPPostCallback := ACallback;
end;

function TFreePascalContext.GetHTTPPostCallback: TSSLHTTPPostCallback;
begin
  Result := FHTTPPostCallback;
end;

procedure TFreePascalContext.AddCertificatePin(const AHash: TBytes; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
var
  LIndex: Integer;
begin
  if Length(AHash) <> 32 then
    RaiseInvalidParameter('PinHash');

  LIndex := Length(FPins);
  SetLength(FPins, LIndex + 1);
  FPins[LIndex].Hash := Copy(AHash, 0, Length(AHash));
  FPins[LIndex].PinType := APinType;
  FPins[LIndex].Description := ADescription;
  FPins[LIndex].IsBackup := AIsBackup;
end;

procedure TFreePascalContext.AddCertificatePinBase64(const ABase64Hash: string; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
var
  LDecoded: string;
  LAnsi: AnsiString;
  LHash: TBytes;
begin
  LDecoded := DecodeStringBase64(ABase64Hash);
  LAnsi := AnsiString(LDecoded);
  SetLength(LHash, Length(LAnsi));
  if Length(LAnsi) > 0 then
    Move(LAnsi[1], LHash[0], Length(LAnsi));

  AddCertificatePin(LHash, APinType, ADescription, AIsBackup);
end;

procedure TFreePascalContext.SetCertificatePinningEnabled(AEnabled: Boolean);
begin
  FPinningEnabled := AEnabled;
end;

function TFreePascalContext.GetCertificatePinningEnabled: Boolean;
begin
  Result := FPinningEnabled;
end;

procedure TFreePascalContext.ClearCertificatePins;
begin
  SetLength(FPins, 0);
end;

function TFreePascalContext.ValidateCertificatePin(const ACertFingerprint: TBytes): Boolean;
var
  I: Integer;
  LPinHex, LCertHex: string;
  LPinBytes, LCertBytes: TBytes;
begin
  if (not FPinningEnabled) or (Length(FPins) = 0) then
  begin
    Result := True;
    Exit;
  end;
  LCertBytes := ACertFingerprint;
  for I := 0 to High(FPins) do
  begin
    LPinBytes := FPins[I].Hash;
    if TConstantTime.CompareBytes(LPinBytes, LCertBytes) = 1 then
    begin
      Result := True;
      Exit;
    end;
  end;
  Result := False;
end;

function TFreePascalContext.CreateConnection(ASocket: THandle): ISSLConnection;
begin
  Result := TFreePascalConnection.Create(Self as ISSLContext, ASocket);
end;

function TFreePascalContext.CreateConnection(AStream: TStream): ISSLConnection;
var
  LTransport: IStream;
begin
  LTransport := WrapTStream(AStream, False);
  Result := TFreePascalConnection.Create(Self as ISSLContext, LTransport);
end;

function TFreePascalContext.IsValid: Boolean;
begin
  Result := True;
end;

function TFreePascalContext.HasCertificateMaterial: Boolean;
begin
  Result := Length(FCertificateData) > 0;
end;

function TFreePascalContext.HasPrivateKeyMaterial: Boolean;
begin
  Result := Length(FPrivateKeyData) > 0;
end;

function TFreePascalContext.GetCertificateMaterial: TBytes;
var
  LPEM: string;
begin
  if (Length(FCertificateData) > 10) and
     (FCertificateData[0] = Ord('-')) and (FCertificateData[1] = Ord('-')) then
  begin
    SetString(LPEM, PAnsiChar(@FCertificateData[0]), Length(FCertificateData));
    Result := TSSLUtils.PEMToDER(LPEM);
  end
  else
    Result := Copy(FCertificateData, 0, Length(FCertificateData));
end;

function TFreePascalContext.GetPrivateKeyMaterial: TBytes;
var
  LPEM: string;
begin
  if (Length(FPrivateKeyData) > 10) and
     (FPrivateKeyData[0] = Ord('-')) and (FPrivateKeyData[1] = Ord('-')) then
  begin
    SetString(LPEM, PAnsiChar(@FPrivateKeyData[0]), Length(FPrivateKeyData));
    Result := TSSLUtils.PEMToDER(LPEM);
  end
  else
    Result := Copy(FPrivateKeyData, 0, Length(FPrivateKeyData));
end;

function TFreePascalContext.BuildVerificationStore: ISSLCertificateStore;
var
  I: Integer;
  LCertificate: ISSLCertificate;
  LClonedCertificate: ISSLCertificate;
begin
  Result := nil;

  if FLibrary = nil then
    Exit;

  try
    Result := FLibrary.CreateCertificateStore;
  except
    Exit(nil);
  end;

  if Result = nil then
    Exit;

  if FCertificateStore <> nil then
    for I := 0 to FCertificateStore.GetCount - 1 do
    begin
      LCertificate := FCertificateStore.GetCertificate(I);
      if LCertificate = nil then
        Continue;

      LClonedCertificate := LCertificate.Clone;
      if LClonedCertificate <> nil then
        Result.AddCertificate(LClonedCertificate);
    end;

  if FCAFile <> '' then
    Result.LoadFromFile(FCAFile);

  if FCAPath <> '' then
    Result.LoadFromPath(FCAPath);

  if Result.GetCount = 0 then
    Result := nil;
end;

procedure TFreePascalContext.ClearCRLMaterial;
begin
  FCRLMaterial.Clear;
end;

procedure TFreePascalContext.AddCRLPEM(const APEM: string);
begin
  if Trim(APEM) = '' then
    RaiseInvalidParameter('APEM');
  FCRLMaterial.Add(APEM);
end;

procedure TFreePascalContext.AddCRLFile(const AFileName: string);
var
  LCRLText: TStringArray;
begin
  if not nextpas.core.fs.IsFile(AFileName) then
    raise ESSLFileNotFoundException.CreateWithContext(
      nextpas.core.text.conv.Format('CRL file not found: %s', [AFileName]),
      sslErrLoadFailed,
      'TFreePascalContext.AddCRLFile',
      0,
      sslFreePascal
    );
  try
    LCRLText.LoadFromFile(AFileName);
    AddCRLPEM(LCRLText.Text);
  finally
  end;
end;

function TFreePascalContext.BuildCRLStore: TStringArray;
begin
  if (FCRLMaterial = nil) or (Length(FCRLMaterial) = 0) then
    Exit(nil);
  Result.Assign(FCRLMaterial);
end;

procedure TFreePascalContext.ClearServerStapledOCSPResponse;
begin
  SetLength(FServerStapledOCSPResponse, 0);
end;

procedure TFreePascalContext.SetServerStapledOCSPResponse(const AResponseDER: TBytes);
begin
  if Length(AResponseDER) = 0 then
  begin
    ClearServerStapledOCSPResponse;
    Exit;
  end;

  FServerStapledOCSPResponse := Copy(AResponseDER, 0, Length(AResponseDER));
end;

procedure TFreePascalContext.LoadServerStapledOCSPResponseFile(const AFileName: string);
var
  LStream: TFileStream;
  LSize: Int64;
begin
  if not nextpas.core.fs.IsFile(AFileName) then
    raise ESSLFileNotFoundException.CreateWithContext(
      nextpas.core.text.conv.Format('Server stapled OCSP response file not found: %s', [AFileName]),
      sslErrLoadFailed,
      'TFreePascalContext.LoadServerStapledOCSPResponseFile',
      0,
      sslFreePascal
    );

  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    LSize := LStream.Size;
    if LSize = 0 then
      raise ESSLInvalidArgument.Create(
        'OCSP response file is empty',
        sslErrInvalidParam
      );
    if LSize > MAX_OCSP_RESPONSE_SIZE then
      raise ESSLInvalidArgument.Create(
        nextpas.core.text.conv.Format('OCSP response file too large (%d bytes, max %d)',
          [LSize, MAX_OCSP_RESPONSE_SIZE]),
        sslErrInvalidParam
      );
    SetServerStapledOCSPResponse(ReadStreamToBytes(LStream));
  finally
  end;
end;

function TFreePascalContext.HasServerStapledOCSPResponse: Boolean;
begin
  Result := Length(FServerStapledOCSPResponse) > 0;
end;

function TFreePascalContext.GetServerStapledOCSPResponse: TBytes;
begin
  Result := Copy(FServerStapledOCSPResponse, 0, Length(FServerStapledOCSPResponse));
end;

function TFreePascalContext.CanIssueSessionTickets: Boolean;
begin
  Result :=
    (FContextType = sslCtxServer) and
    FSessionCacheEnabled and
    (FSessionCacheSize <> 0);
end;

function TFreePascalContext.TryGetResumptionSession(const ATicket: TBytes; out ASession: ISSLSession): Boolean;
var
  I: Integer;
  LKey: string;
begin
  ASession := nil;
  Result := False;

  if not CanIssueSessionTickets or (Length(ATicket) = 0) then
    Exit;

  EnterCriticalSection(FResumptionLock);
  try
    PruneResumptionCache;
    LKey := TicketKey(ATicket);
    for I := 0 to High(FResumptionCache) do
      if FResumptionCache[I].Key = LKey then
      begin
        if FResumptionCache[I].Session <> nil then
          ASession := FResumptionCache[I].Session.Clone;
        Exit(ASession <> nil);
      end;
  finally
    LeaveCriticalSection(FResumptionLock);
  end;
end;

procedure TFreePascalContext.StoreResumptionSession(ASession: ISSLSession);
var
  I: Integer;
  LEntryIndex: Integer;
  LKey: string;
  LStoredSession: ISSLSession;
  LResumptionSession: IFreePascalResumptionSession;
  LTLS12Session: IFreePascalTLS12ResumptionSession;
begin
  if not CanIssueSessionTickets then
    Exit;
  if (ASession = nil) or (not ASession.IsValid) or (not ASession.IsResumable) then
    Exit;

  LKey := '';
  if Supports(ASession, IFreePascalTLS12ResumptionSession, LTLS12Session) and
     (ASession.GetProtocolVersion = sslProtocolTLS12) then
    LKey := TicketKey(LTLS12Session.GetTLS12SessionID)
  else if Supports(ASession, IFreePascalResumptionSession, LResumptionSession) then
    LKey := TicketKey(LResumptionSession.GetTicket);

  if LKey = '' then
    Exit;

  LStoredSession := ASession.Clone;
  if LStoredSession = nil then
    Exit;
  LStoredSession.SetTimeout(FSessionTimeout);

  EnterCriticalSection(FResumptionLock);
  try
    PruneResumptionCache;
    LEntryIndex := -1;
    for I := 0 to High(FResumptionCache) do
      if FResumptionCache[I].Key = LKey then
      begin
        LEntryIndex := I;
        Break;
      end;

    if LEntryIndex >= 0 then
    begin
      FResumptionCache[LEntryIndex].Session := LStoredSession;
      Exit;
    end;

    LEntryIndex := Length(FResumptionCache);
    SetLength(FResumptionCache, LEntryIndex + 1);
    FResumptionCache[LEntryIndex].Key := LKey;
    FResumptionCache[LEntryIndex].Session := LStoredSession;
    EnforceResumptionCacheLimit;
  finally
    LeaveCriticalSection(FResumptionLock);
  end;
end;

function TFreePascalContext.InstallFileBackedReplayLedger(
  const AFileName: string
): Boolean;
var
  LProvider: IFreePascalEarlyDataReplayProvider;
begin
  Result := False;

  if Trim(AFileName) = '' then
    Exit;

  try
    LProvider := TFreePascalFileEarlyDataReplayProvider.Create(AFileName);
    Result := InstallReplayProviderBackedLedger(LProvider);
  except
    Result := False;
  end;
end;

function TFreePascalContext.InstallDirectoryBackedReplayLedger(
  const ADirectoryName: string
): Boolean;
var
  LStore: IFreePascalEarlyDataReplayStore;
begin
  Result := False;

  if Trim(ADirectoryName) = '' then
    Exit;

  try
    LStore := TFreePascalDirectoryEarlyDataReplayStore.Create(ADirectoryName);
    Result := InstallStoreBackedReplayLedger(Self, LStore);
  except
    Result := False;
  end;
end;

function TFreePascalContext.InstallReplayProviderBackedLedger(
  AProvider: IFreePascalEarlyDataReplayProvider
): Boolean;
var
  LLedger: IFreePascalManagedEarlyDataReplayLedger;
begin
  Result := False;

  if AProvider = nil then
    Exit;

  try
    LLedger := TFreePascalProviderBackedEarlyDataReplayLedger.Create(
      AProvider,
      FSessionCacheEnabled,
      FSessionCacheSize
    );
    SetEarlyDataReplayLedger(LLedger);
    Result := True;
  except
    Result := False;
  end;
end;

function TFreePascalContext.GetEarlyDataReplayLedger: IFreePascalEarlyDataReplayLedger;
begin
  Result := FActiveEarlyDataReplayLedger;
  if Result = nil then
    Result := FDefaultEarlyDataReplayLedger;
end;

procedure TFreePascalContext.SetEarlyDataReplayLedger(
  ALedger: IFreePascalEarlyDataReplayLedger
);
var
  LManagedLedger: IFreePascalManagedEarlyDataReplayLedger;
begin
  if ALedger = nil then
    FActiveEarlyDataReplayLedger := FDefaultEarlyDataReplayLedger
  else
    FActiveEarlyDataReplayLedger := ALedger;

  if Supports(FActiveEarlyDataReplayLedger, IFreePascalManagedEarlyDataReplayLedger, LManagedLedger) then
  begin
    LManagedLedger.SetEnabled(FSessionCacheEnabled);
    LManagedLedger.SetCapacity(FSessionCacheSize);
  end;
end;

procedure TFreePascalContext.ResetEarlyDataReplayLedger;
begin
  FActiveEarlyDataReplayLedger := FDefaultEarlyDataReplayLedger;
end;

function TFreePascalContext.TryAcquireEarlyDataSession(ASession: ISSLSession): Boolean;
var
  LLedger: IFreePascalEarlyDataReplayLedger;
begin
  Result := False;
  if (not FSessionCacheEnabled) or (FSessionCacheSize <= 0) then
    Exit;

  LLedger := GetEarlyDataReplayLedger;
  if LLedger = nil then
    Exit;

  Result := LLedger.TryAcquireEarlyDataSession(ASession);
end;

end.
