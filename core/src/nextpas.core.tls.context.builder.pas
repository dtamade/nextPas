{
  nextpas.core.tls.context.builder - Fluent SSL Context Builder

  Provides a modern, fluent API for SSL context configuration, inspired by
  Rust's rustls ConfigBuilder pattern.

  Features:
  - Method chaining for readable code
  - Type-safe configuration
  - Safe defaults built-in
  - Separate client/server building
}

unit nextpas.core.tls.context.builder;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  nextpas.core.base.utils,
  nextpas.core.exception, nextpas.core.text.conv, nextpas.core.tls.base,
  nextpas.core.tls.safety,
  nextpas.core.tls.pkcs11.types,
  nextpas.core.tls.pkcs11.pin,
  nextpas.core.tls.backend.selector;  // v1.3.0: 自动后端选择

type
  { Forward declarations }
  ISSLContextBuilder = interface;

  { Callback types for conditional configuration (Phase 2.2.1) }
  TBuilderConfigProc = procedure(ABuilder: ISSLContextBuilder);

  { Callback type for transformation (Phase 2.2.4) }
  TBuilderTransformFunc = function(ABuilder: ISSLContextBuilder): ISSLContextBuilder;

  {**
   * ISSLContextBuilder - Fluent API for SSL context configuration
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  ISSLContextBuilder = interface
    ['{F6A7B8C9-D0E1-4F23-4567-890ABCDEF012}']

    // Protocol version configuration
    function WithTLS12: ISSLContextBuilder;
    function WithTLS13: ISSLContextBuilder;
    function WithTLS12And13: ISSLContextBuilder;
    function WithProtocols(AVersions: TSSLProtocolVersions): ISSLContextBuilder;

    // Verification mode
    function WithVerifyPeer: ISSLContextBuilder;
    function WithVerifyNone: ISSLContextBuilder;  // Warning: Insecure!
    function WithVerifyDepth(ADepth: Integer): ISSLContextBuilder;

    // Certificate configuration
    function WithCertificate(const AFile: string): ISSLContextBuilder;
    function WithCertificatePEM(const APEM: string): ISSLContextBuilder;
    function WithPrivateKey(const AFile: string; const APassword: string = ''): ISSLContextBuilder;
    function WithPrivateKeyPEM(const APEM: string; const APassword: string = ''): ISSLContextBuilder;
    function WithCAFile(const AFile: string): ISSLContextBuilder;
    function WithCAPath(const APath: string): ISSLContextBuilder;
    function WithSystemRoots: ISSLContextBuilder;

    // Cipher configuration
    function WithCipherList(const ACiphers: string): ISSLContextBuilder;
    function WithTLS13Ciphersuites(const ACiphers: string): ISSLContextBuilder;
    function WithSafeDefaults: ISSLContextBuilder;  // Modern secure defaults

    // Advanced options
    { Compatibility-only context-level SNI.
      New client code should prefer per-connection hostname/SNI via
      TSSLConnectionBuilder.WithHostname(...) or
      ISSLClientConnection.SetServerName(...). }
    function WithSNI(const AServerName: string): ISSLContextBuilder;
      deprecated 'Use per-connection hostname via TSSLConnectionBuilder.WithHostname or ISSLClientConnection.SetServerName';
    function WithALPN(const AProtocols: string): ISSLContextBuilder;
    function WithSessionCache(AEnabled: Boolean): ISSLContextBuilder;
    function WithSessionTimeout(ASeconds: Integer): ISSLContextBuilder; overload;
    function WithSessionTimeout(const ATimeout: TTimeoutDuration): ISSLContextBuilder; overload;
    function WithClientEarlyData(AEnabled: Boolean = True): ISSLContextBuilder;
    function WithServerEarlyDataPolicy(APolicy: TSSLEarlyDataServerPolicy): ISSLContextBuilder;
    function WithServerMaxEarlyDataSize(ASize: Cardinal): ISSLContextBuilder;
    function WithServerEarlyDataReplayStoreFile(const AFile: string): ISSLContextBuilder;
    function WithServerEarlyDataReplayStoreDirectory(const ADirectory: string): ISSLContextBuilder;

    // HTTP transport hooks (fafafa.ssl does not implement networking)
    function WithHTTPHooks(AHTTPGet: TSSLHTTPGetCallback;
      AHTTPPost: TSSLHTTPPostCallback): ISSLContextBuilder;

    // PKCS#11 support
    function UsePKCS11(const AURI: string): ISSLContextBuilder;
    function WithPKCS11PIN(const APIN: string): ISSLContextBuilder;
    function WithPKCS11PINMethod(AMethod: TPKCS11PINMethod): ISSLContextBuilder;

    // OCSP Stapling support
    function WithOCSPStapling(AEnabled: Boolean = True): ISSLContextBuilder;
    function WithOCSPStaplingRequired(ARequired: Boolean = True): ISSLContextBuilder;
    function WithServerOCSPStapledResponseFile(const AFile: string): ISSLContextBuilder;
    function WithCertificateTransparencyRequired(ARequired: Boolean = True): ISSLContextBuilder;
    function WithCertVerifyCache(AEnabled: Boolean = True): ISSLContextBuilder;

    // v1.3.0: Automatic backend selection
    function WithAutoBackendSelection(const ARequirements: TSSLRequirements): ISSLContextBuilder;
    function WithSecurityFirst: ISSLContextBuilder;
    function WithPerformanceFirst: ISSLContextBuilder;
    function WithCompatibilityFirst: ISSLContextBuilder;
    function WithBackend(ABackendType: TSSLLibraryType): ISSLContextBuilder;
    function RequireTLS13: ISSLContextBuilder;
    function RequireCipher(ACipher: TSSLCipher): ISSLContextBuilder;
    function RequirePKCS11Support: ISSLContextBuilder;
    function PreferOSNative: ISSLContextBuilder;

    // Options
    function WithOption(AOption: TSSLOption): ISSLContextBuilder;
    function WithOptions(AOptions: TSSLOptions): ISSLContextBuilder;
    function WithoutOption(AOption: TSSLOption): ISSLContextBuilder;

    // Build methods
    function BuildClient: ISSLContext;
    function BuildServer: ISSLContext;

    // Try-pattern build methods (non-throwing)
    function TryBuildClient(out AContext: ISSLContext): TSSLOperationResult;
    function TryBuildServer(out AContext: ISSLContext): TSSLOperationResult;

    // Configuration validation (Phase 2.1.2)
    function Validate: TBuildValidationResult;
    function ValidateClient: TBuildValidationResult;
    function ValidateServer: TBuildValidationResult;
    function BuildClientWithValidation(out AValidation: TBuildValidationResult): ISSLContext;
    function BuildServerWithValidation(out AValidation: TBuildValidationResult): ISSLContext;

    // Configuration import/export (Phase 2.1.3)
    function ExportToJSON: string;
    function ImportFromJSON(const AJSON: string): ISSLContextBuilder;
    function ExportToINI: string;
    function ImportFromINI(const AINI: string): ISSLContextBuilder;

    // Configuration snapshot and clone (Phase 2.1.4)
    function Clone: ISSLContextBuilder;
    function Reset: ISSLContextBuilder;
    function ResetToDefaults: ISSLContextBuilder;  // Alias for Reset
    function Merge(ASource: ISSLContextBuilder): ISSLContextBuilder;

    // Conditional configuration (Phase 2.2.1)
    function When(ACondition: Boolean; AConfig: TBuilderConfigProc): ISSLContextBuilder;
    function Unless(ACondition: Boolean; AConfig: TBuilderConfigProc): ISSLContextBuilder;
    function WhenDevelopment(AConfig: TBuilderConfigProc): ISSLContextBuilder;
    function WhenProduction(AConfig: TBuilderConfigProc): ISSLContextBuilder;

    // Batch configuration (Phase 2.2.2)
    function Apply(AConfig: TBuilderConfigProc): ISSLContextBuilder;
    function ApplyPreset(APreset: ISSLContextBuilder): ISSLContextBuilder;
    function Pipe(ATransform: TBuilderConfigProc): ISSLContextBuilder;

    // Convenience methods (Phase 2.2.3)
    function WithCertificateChain(const ACerts: array of string): ISSLContextBuilder;
    function WithMutualTLS(const ACAFile: string; ARequired: Boolean = True): ISSLContextBuilder;
    function WithHTTP2: ISSLContextBuilder;
    function WithModernDefaults: ISSLContextBuilder;

    // Configuration transformation (Phase 2.2.4)
    function Transform(ATransform: TBuilderTransformFunc): ISSLContextBuilder;
    function Extend(const AOptions: array of TSSLOption): ISSLContextBuilder;
    function Override(const AField, AValue: string): ISSLContextBuilder;
  end;

  { Factory class for creating builders }
  TSSLContextBuilder = class
  public
    class function Create: ISSLContextBuilder; static;
    class function CreateWithSafeDefaults: ISSLContextBuilder; static;

    // Preset configurations (Phase 2.1.1)
    class function Development: ISSLContextBuilder; static;
    class function Production: ISSLContextBuilder; static;
    class function StrictSecurity: ISSLContextBuilder; static;
    class function LegacyCompatibility: ISSLContextBuilder; static;
  end;

implementation

uses
  nextpas.core.base,
  nextpas.core.text.strings,
  nextpas.core.tls.factory,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.freepascal.context.material,
  nextpas.core.tls.base64,
  nextpas.core.tls.logging,
  nextpas.core.json, nextpas.core.json.builder;

procedure LogBuilderContextLevelServerNameCompatibilityWarning(
  const ACallSite: string;
  AForServer: Boolean
);
begin
  if AForServer then
    TSecurityLog.Warning(
      'ContextBuilder',
      nextpas.core.text.conv.Format(
        '%s received WithSNI as deprecated context-level ServerName compatibility on a server context; ' +
        'BuildServer ignores it and server-side connections ignore it.',
        [ACallSite]
      )
    )
  else
    TSecurityLog.Warning(
      'ContextBuilder',
      nextpas.core.text.conv.Format(
        '%s received WithSNI as deprecated context-level SNI compatibility on a client context; ' +
        'BuildClient ignores it and new client connections start without inherited ServerName. ' +
        'Prefer per-connection hostname via TSSLConnectionBuilder.WithHostname, ' +
        'ISSLClientConnection.SetServerName, or TSSLConnector.Connect*(..., ServerName).',
        [ACallSite]
      )
    );
end;

function TimeoutDurationToSessionTimeoutSeconds(
  const ATimeout: TTimeoutDuration): Integer;
var
  LMilliseconds: Int64;
  LSeconds: Int64;
begin
  if ATimeout.IsInfinite then
    raise ESSLInvalidArgument.Create(
      'Infinite timeout is not valid for session lifetime',
      sslErrInvalidParam
    );

  LMilliseconds := ATimeout.ToMilliseconds;
  if (LMilliseconds mod 1000) <> 0 then
    raise ESSLInvalidArgument.Create(
      'Session timeout must be a whole number of seconds',
      sslErrInvalidParam
    );

  LSeconds := LMilliseconds div 1000;
  if (LSeconds < Low(Integer)) or (LSeconds > High(Integer)) then
    raise ESSLInvalidArgument.Create(
      'Session timeout exceeds Integer second range',
      sslErrInvalidParam
    );

  Result := Integer(LSeconds);
end;

type
  { Internal builder implementation }
  TSSLContextBuilderImpl = class(TInterfacedObject, ISSLContextBuilder)
  private
    FProtocolVersions: TSSLProtocolVersions;
    FVerifyMode: TSSLVerifyModes;
    FVerifyModeExplicit: Boolean;
    FDevelopmentPreset: Boolean;
    FVerifyDepth: Integer;
    FCertificateFile: string;
    FCertificatePEM: string;
    FPrivateKeyFile: string;
    FPrivateKeyPassword: string;
    FPrivateKeyPEM: string;
    FCAFile: string;
    FCAPath: string;
    FUseSystemRoots: Boolean;
    FCipherList: string;
    FTLS13Ciphersuites: string;
    FServerName: string;
    FALPNProtocols: string;
    FSessionCacheEnabled: Boolean;
    FSessionTimeout: Integer;
    FClientEarlyDataEnabled: Boolean;
    FServerEarlyDataPolicy: TSSLEarlyDataServerPolicy;
    FServerMaxEarlyDataSize: Cardinal;
    FServerEarlyDataReplayStoreFile: string;
    FServerEarlyDataReplayStoreDirectory: string;
    FOptions: TSSLOptions;

    // HTTP hooks (optional, only applied when backend supports ISSLHttpHooksAccess)
    FHTTPGetCallback: TSSLHTTPGetCallback;
    FHTTPPostCallback: TSSLHTTPPostCallback;

    // PKCS#11 fields
    FPKCS11URI: string;
    FPKCS11PIN: string;
    FPKCS11PINMethod: TPKCS11PINMethod;

    // OCSP Stapling fields
    FOCSPStaplingEnabled: Boolean;
    FOCSPStaplingRequired: Boolean;
    FServerOCSPStapledResponseFile: string;
    FCertificateTransparencyRequired: Boolean;

    // v1.3.0: Automatic backend selection fields
    FAutoSelectBackend: Boolean;
    FBackendRequirements: TSSLRequirements;
    FExplicitBackend: TSSLLibraryType;
    FExplicitBackendSet: Boolean;

    procedure SyncOCSPStaplingOptions;
    procedure SyncCertificateTransparencyOptions;
    function GetSupportedPKCS11PINValue: string;
    function BuildContextConfig(AContextType: TSSLContextType; ALibraryType: TSSLLibraryType): TSSLContextConfig;
  public
    constructor Create;

    // ISSLContextBuilder
    function WithTLS12: ISSLContextBuilder;
    function WithTLS13: ISSLContextBuilder;
    function WithTLS12And13: ISSLContextBuilder;
    function WithProtocols(AVersions: TSSLProtocolVersions): ISSLContextBuilder;

    function WithVerifyPeer: ISSLContextBuilder;
    function WithVerifyNone: ISSLContextBuilder;
    function WithVerifyDepth(ADepth: Integer): ISSLContextBuilder;

    function WithCertificate(const AFile: string): ISSLContextBuilder;
    function WithCertificatePEM(const APEM: string): ISSLContextBuilder;
    function WithPrivateKey(const AFile: string; const APassword: string = ''): ISSLContextBuilder;
    function WithPrivateKeyPEM(const APEM: string; const APassword: string = ''): ISSLContextBuilder;
    function WithCAFile(const AFile: string): ISSLContextBuilder;
    function WithCAPath(const APath: string): ISSLContextBuilder;
    function WithSystemRoots: ISSLContextBuilder;

    function WithCipherList(const ACiphers: string): ISSLContextBuilder;
    function WithTLS13Ciphersuites(const ACiphers: string): ISSLContextBuilder;
    function WithSafeDefaults: ISSLContextBuilder;

    function WithSNI(const AServerName: string): ISSLContextBuilder;
      deprecated 'Use per-connection hostname via TSSLConnectionBuilder.WithHostname or ISSLClientConnection.SetServerName';
    function WithALPN(const AProtocols: string): ISSLContextBuilder;
    function WithSessionCache(AEnabled: Boolean): ISSLContextBuilder;
    function WithSessionTimeout(ASeconds: Integer): ISSLContextBuilder; overload;
    function WithSessionTimeout(const ATimeout: TTimeoutDuration): ISSLContextBuilder; overload;
    function WithClientEarlyData(AEnabled: Boolean = True): ISSLContextBuilder;
    function WithServerEarlyDataPolicy(APolicy: TSSLEarlyDataServerPolicy): ISSLContextBuilder;
    function WithServerMaxEarlyDataSize(ASize: Cardinal): ISSLContextBuilder;
    function WithServerEarlyDataReplayStoreFile(const AFile: string): ISSLContextBuilder;
    function WithServerEarlyDataReplayStoreDirectory(const ADirectory: string): ISSLContextBuilder;
    function WithHTTPHooks(AHTTPGet: TSSLHTTPGetCallback;
      AHTTPPost: TSSLHTTPPostCallback): ISSLContextBuilder;

    function WithOption(AOption: TSSLOption): ISSLContextBuilder;
    function WithOptions(AOptions: TSSLOptions): ISSLContextBuilder;
    function WithoutOption(AOption: TSSLOption): ISSLContextBuilder;

    // PKCS#11 support
    function UsePKCS11(const AURI: string): ISSLContextBuilder;
    function WithPKCS11PIN(const APIN: string): ISSLContextBuilder;
    function WithPKCS11PINMethod(AMethod: TPKCS11PINMethod): ISSLContextBuilder;

    // OCSP Stapling support
    function WithOCSPStapling(AEnabled: Boolean = True): ISSLContextBuilder;
    function WithOCSPStaplingRequired(ARequired: Boolean = True): ISSLContextBuilder;
    function WithServerOCSPStapledResponseFile(const AFile: string): ISSLContextBuilder;
    function WithCertificateTransparencyRequired(ARequired: Boolean = True): ISSLContextBuilder;
    function WithCertVerifyCache(AEnabled: Boolean = True): ISSLContextBuilder;

    // v1.3.0: Automatic backend selection
    function WithAutoBackendSelection(const ARequirements: TSSLRequirements): ISSLContextBuilder;
    function WithSecurityFirst: ISSLContextBuilder;
    function WithPerformanceFirst: ISSLContextBuilder;
    function WithCompatibilityFirst: ISSLContextBuilder;
    function WithBackend(ABackendType: TSSLLibraryType): ISSLContextBuilder;
    function RequireTLS13: ISSLContextBuilder;
    function RequireCipher(ACipher: TSSLCipher): ISSLContextBuilder;
    function RequirePKCS11Support: ISSLContextBuilder;
    function PreferOSNative: ISSLContextBuilder;

    function BuildClient: ISSLContext;
    function BuildServer: ISSLContext;
    function TryBuildClient(out AContext: ISSLContext): TSSLOperationResult;
    function TryBuildServer(out AContext: ISSLContext): TSSLOperationResult;

    // Configuration validation (Phase 2.1.2)
    function Validate: TBuildValidationResult;
    function ValidateClient: TBuildValidationResult;
    function ValidateServer: TBuildValidationResult;
    function BuildClientWithValidation(out AValidation: TBuildValidationResult): ISSLContext;
    function BuildServerWithValidation(out AValidation: TBuildValidationResult): ISSLContext;

    // Configuration import/export (Phase 2.1.3)
    function ExportToJSON: string;
    function ImportFromJSON(const AJSON: string): ISSLContextBuilder;
    function ExportToINI: string;
    function ImportFromINI(const AINI: string): ISSLContextBuilder;

    // Configuration snapshot and clone (Phase 2.1.4)
    function Clone: ISSLContextBuilder;
    function Reset: ISSLContextBuilder;
    function ResetToDefaults: ISSLContextBuilder;
    function Merge(ASource: ISSLContextBuilder): ISSLContextBuilder;

    // Conditional configuration (Phase 2.2.1)
    function When(ACondition: Boolean; AConfig: TBuilderConfigProc): ISSLContextBuilder;
    function Unless(ACondition: Boolean; AConfig: TBuilderConfigProc): ISSLContextBuilder;
    function WhenDevelopment(AConfig: TBuilderConfigProc): ISSLContextBuilder;
    function WhenProduction(AConfig: TBuilderConfigProc): ISSLContextBuilder;

    // Batch configuration (Phase 2.2.2)
    function Apply(AConfig: TBuilderConfigProc): ISSLContextBuilder;
    function ApplyPreset(APreset: ISSLContextBuilder): ISSLContextBuilder;
    function Pipe(ATransform: TBuilderConfigProc): ISSLContextBuilder;

    // Convenience methods (Phase 2.2.3)
    function WithCertificateChain(const ACerts: array of string): ISSLContextBuilder;
    function WithMutualTLS(const ACAFile: string; ARequired: Boolean = True): ISSLContextBuilder;
    function WithHTTP2: ISSLContextBuilder;
    function WithModernDefaults: ISSLContextBuilder;

    // Configuration transformation (Phase 2.2.4)
    function Transform(ATransform: TBuilderTransformFunc): ISSLContextBuilder;
    function Extend(const AOptions: array of TSSLOption): ISSLContextBuilder;
    function Override(const AField, AValue: string): ISSLContextBuilder;
  end;

{ TSSLContextBuilder }

function ImportedVerifyModeIsExplicit(
  const AVerifyMode: TSSLVerifyModes;
  const ACAFile, ACAPath: string;
  AUseSystemRoots: Boolean
): Boolean;
begin
  if AVerifyMode <> [sslVerifyPeer] then
    Exit(True);

  Result := (nextpas.core.text.conv.Trim(ACAFile) <> '') or
            (nextpas.core.text.conv.Trim(ACAPath) <> '') or
            AUseSystemRoots;
end;

function EffectiveBuilderVerifyMode(
  const ABuilder: TSSLContextBuilderImpl;
  AForServer: Boolean
): TSSLVerifyModes;
begin
  if not ABuilder.FVerifyModeExplicit then
  begin
    if AForServer then
      Result := []
    else
      Result := [sslVerifyPeer];
    Exit;
  end;

  Result := ABuilder.FVerifyMode;
end;

class function TSSLContextBuilder.Create: ISSLContextBuilder;
begin
  Result := TSSLContextBuilderImpl.Create;
end;

class function TSSLContextBuilder.CreateWithSafeDefaults: ISSLContextBuilder;
begin
  Result := TSSLContextBuilderImpl.Create.WithSafeDefaults;
end;

{ Preset Configurations - Phase 2.1.1 }

class function TSSLContextBuilder.Development: ISSLContextBuilder;
var
  LBuilder: TSSLContextBuilderImpl;
begin
  LBuilder := TSSLContextBuilderImpl.Create;
  LBuilder.FDevelopmentPreset := True;
  Result := LBuilder
    .WithTLS12And13
    .WithVerifyNone
    .WithSessionCache(False)
    .WithOption(ssoEnableSessionTickets);
end;

class function TSSLContextBuilder.Production: ISSLContextBuilder;
begin
  {
    Production preset:
    - Strict security settings
    - Performance optimizations (session cache enabled)
    - TLS 1.2 and 1.3 only
    - Safe defaults for cipher suites
  }
  Result := TSSLContextBuilderImpl.Create
    .WithTLS12And13
    .WithVerifyPeer
    .WithSessionCache(True)  // Performance: enable session cache
    .WithSafeDefaults
    .WithOption(ssoEnableSessionTickets);
end;

class function TSSLContextBuilder.StrictSecurity: ISSLContextBuilder;
begin
  {
    StrictSecurity preset:
    - Maximum security level
    - TLS 1.3 only
    - Strict peer verification
    - Strong cipher suites only
    - All modern security features enabled
  }
  Result := TSSLContextBuilderImpl.Create
    .WithTLS13  // Only TLS 1.3 for maximum security
    .WithVerifyPeer
    .WithVerifyDepth(10)
    .WithSessionCache(True)
    .WithOptions([
      ssoEnableSNI,
      ssoDisableCompression,      // Prevent CRIME attack
      ssoDisableRenegotiation,    // Prevent renegotiation attacks
      ssoCipherServerPreference,  // Server chooses cipher
      ssoNoSSLv2,                 // Disable all insecure protocols
      ssoNoSSLv3,
      ssoNoTLSv1,
      ssoNoTLSv1_1,
      ssoNoTLSv1_2                // TLS 1.3 only
    ]);
end;

class function TSSLContextBuilder.LegacyCompatibility: ISSLContextBuilder;
begin
  {
    LegacyCompatibility preset:
    - Support for older protocols (TLS 1.0, 1.1, 1.2, 1.3)
    - Wider cipher suite support
    - More lenient verification
    - For interoperability with legacy systems
    WARNING: This preset is less secure, use only when necessary!
  }
  Result := TSSLContextBuilderImpl.Create
    .WithProtocols([sslProtocolTLS10, sslProtocolTLS11, sslProtocolTLS12, sslProtocolTLS13])
    .WithVerifyPeer  // Still verify, but allow older protocols
    .WithSessionCache(True)
    .WithOptions([
      ssoEnableSNI,
      ssoEnableSessionTickets
      // Note: We intentionally don't disable compression or renegotiation
      // for maximum compatibility with legacy systems
    ]);
end;

{ TSSLContextBuilderImpl }

constructor TSSLContextBuilderImpl.Create;
begin
  inherited Create;
  // Initialize with sensible defaults
  FProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  FVerifyMode := [sslVerifyPeer];
  FVerifyModeExplicit := False;
  FVerifyDepth := SSL_DEFAULT_VERIFY_DEPTH;
  FCertificateFile := '';
  FCertificatePEM := '';
  FPrivateKeyFile := '';
  FPrivateKeyPassword := '';
  FPrivateKeyPEM := '';
  FCAFile := '';
  FCAPath := '';
  FUseSystemRoots := False;
  FCipherList := '';
  FTLS13Ciphersuites := '';
  FServerName := '';
  FALPNProtocols := '';
  FSessionCacheEnabled := True;
  FSessionTimeout := SSL_DEFAULT_SESSION_TIMEOUT;
  FClientEarlyDataEnabled := False;
  FServerEarlyDataPolicy := sslEarlyDataServerReject;
  FServerMaxEarlyDataSize := 0;
  FServerEarlyDataReplayStoreFile := '';
  FServerEarlyDataReplayStoreDirectory := '';
  FOptions := [ssoEnableSNI, ssoDisableCompression, ssoDisableRenegotiation];

  FHTTPGetCallback := nil;
  FHTTPPostCallback := nil;

  // PKCS#11 defaults
  FPKCS11URI := '';
  FPKCS11PIN := '';
  FPKCS11PINMethod := pmNone;

  // OCSP Stapling defaults
  FOCSPStaplingEnabled := False;
  FOCSPStaplingRequired := False;
  FServerOCSPStapledResponseFile := '';
  FCertificateTransparencyRequired := False;

  // v1.3.0: Automatic backend selection defaults
  FAutoSelectBackend := False;
  FillChar(FBackendRequirements, SizeOf(FBackendRequirements), 0);
  FExplicitBackend := sslOpenSSL;  // 默认
  FExplicitBackendSet := False;
end;

procedure TSSLContextBuilderImpl.SyncOCSPStaplingOptions;
begin
  // Option-set can come from generic APIs/import; keep boolean flags and options aligned.
  if ssoRequireOCSPStapling in FOptions then
    FOCSPStaplingRequired := True;

  if FOCSPStaplingRequired then
    Include(FOptions, ssoRequireOCSPStapling)
  else
    Exclude(FOptions, ssoRequireOCSPStapling);

  if ssoEnableOCSPStapling in FOptions then
    FOCSPStaplingEnabled := True;

  if FOCSPStaplingRequired then
    FOCSPStaplingEnabled := True;

  if FOCSPStaplingEnabled then
    Include(FOptions, ssoEnableOCSPStapling)
  else
  begin
    Exclude(FOptions, ssoEnableOCSPStapling);
    Exclude(FOptions, ssoRequireOCSPStapling);
    FOCSPStaplingRequired := False;
  end;
end;

procedure TSSLContextBuilderImpl.SyncCertificateTransparencyOptions;
begin
  if ssoRequireCertificateTransparency in FOptions then
    FCertificateTransparencyRequired := True;

  if FCertificateTransparencyRequired then
    Include(FOptions, ssoRequireCertificateTransparency)
  else
    Exclude(FOptions, ssoRequireCertificateTransparency);
end;

{$WARN 6018 OFF}
function PKCS11PINMethodToString(AMethod: TPKCS11PINMethod): string;
begin
  case AMethod of
    pmNone:
      Result := 'pmNone';
    pmValue:
      Result := 'pmValue';
    pmEnvironment:
      Result := 'pmEnvironment';
    pmFile:
      Result := 'pmFile';
    pmCallback:
      Result := 'pmCallback';
    pmInteractive:
      Result := 'pmInteractive';
  else
    Result := 'unknown';
  end;
end;
{$WARN 6018 ON}

function UnsupportedBuilderPKCS11PINMethodMessage(AMethod: TPKCS11PINMethod): string;
begin
  Result := nextpas.core.text.conv.Format(
    'Context builder does not support PKCS#11 PIN method %s; use UsePKCS11(...) with URI pin-source or WithPKCS11PIN for direct PIN',
    [PKCS11PINMethodToString(AMethod)]
  );
end;

function MissingBuilderPKCS11PINSourceValueMessage(AMethod: TPKCS11PINMethod): string;
begin
  Result := nextpas.core.text.conv.Format(
    'Context builder PKCS#11 PIN method %s requires a non-empty source value',
    [PKCS11PINMethodToString(AMethod)]
  );
end;

function IsSerializablePKCS11PINSourceMethod(AMethod: TPKCS11PINMethod): Boolean;
begin
  Result := AMethod in [pmEnvironment, pmFile];
end;

function HasExplicitNonValuePKCS11PINMethod(AMethod: TPKCS11PINMethod): Boolean;
begin
  Result := AMethod in [pmEnvironment, pmFile, pmCallback, pmInteractive];
end;

function TryParseLibraryTypeValue(const AValue: string; out ALibraryType: TSSLLibraryType): Boolean;
var
  LOrdinal: Integer;
  LValueLower: string;
begin
  if TryStrToInt(nextpas.core.text.conv.Trim(AValue), LOrdinal) then
  begin
    Result := (LOrdinal >= Ord(Low(TSSLLibraryType))) and
              (LOrdinal <= Ord(High(TSSLLibraryType)));
    if Result then
      ALibraryType := TSSLLibraryType(LOrdinal)
    else
      ALibraryType := sslAutoDetect;
    Exit;
  end;

  LValueLower := LowerCase(nextpas.core.text.conv.Trim(AValue));

  if (LValueLower = 'sslautodetect') or (LValueLower = 'autodetect') or (LValueLower = 'auto') then
    ALibraryType := sslAutoDetect
  else if (LValueLower = 'sslopenssl') or (LValueLower = 'openssl') then
    ALibraryType := sslOpenSSL
  else if (LValueLower = 'sslmbedtls') or (LValueLower = 'mbedtls') then
    ALibraryType := sslMbedTLS
  else if (LValueLower = 'sslwolfssl') or (LValueLower = 'wolfssl') then
    ALibraryType := sslWolfSSL
  else if (LValueLower = 'sslwinssl') or (LValueLower = 'winssl') then
    ALibraryType := sslWinSSL
  else if (LValueLower = 'sslfreepascal') or (LValueLower = 'freepascal') or (LValueLower = 'fpc') then
    ALibraryType := sslFreePascal
  else
    Exit(False);

  Result := True;
end;

function TryParsePKCS11PINMethodOrdinal(AValue: Integer; out AMethod: TPKCS11PINMethod): Boolean;
begin
  Result := (AValue >= Ord(Low(TPKCS11PINMethod))) and
            (AValue <= Ord(High(TPKCS11PINMethod)));
  if Result then
    AMethod := TPKCS11PINMethod(AValue)
  else
    AMethod := pmNone;
end;

function IsValidProtocolVersionOrdinal(AValue: Integer): Boolean;
begin
  Result := (AValue >= Ord(Low(TSSLProtocolVersion))) and
            (AValue <= Ord(High(TSSLProtocolVersion)));
end;

function IsValidVerifyModeOrdinal(AValue: Integer): Boolean;
begin
  Result := (AValue >= Ord(Low(TSSLVerifyMode))) and
            (AValue <= Ord(High(TSSLVerifyMode)));
end;

function IsValidOptionOrdinal(AValue: Integer): Boolean;
begin
  Result := (AValue >= Ord(Low(TSSLOption))) and
            (AValue <= Ord(High(TSSLOption)));
end;

function IsValidEarlyDataPolicyOrdinal(AValue: Integer): Boolean;
begin
  Result := (AValue >= Ord(Low(TSSLEarlyDataServerPolicy))) and
            (AValue <= Ord(High(TSSLEarlyDataServerPolicy)));
end;

function IsValidLibraryTypeOrdinal(AValue: Integer): Boolean;
begin
  Result := (AValue >= Ord(Low(TSSLLibraryType))) and
            (AValue <= Ord(High(TSSLLibraryType)));
end;

function TryParsePKCS11PINMethodValue(const AValue: string; out AMethod: TPKCS11PINMethod): Boolean;
var
  LOrdinal: Integer;
  LValueLower: string;
begin
  if TryStrToInt(nextpas.core.text.conv.Trim(AValue), LOrdinal) then
    Exit(TryParsePKCS11PINMethodOrdinal(LOrdinal, AMethod));

  LValueLower := LowerCase(nextpas.core.text.conv.Trim(AValue));

  if (LValueLower = 'pmnone') or (LValueLower = 'none') then
  begin
    AMethod := pmNone;
    Result := True;
  end
  else if (LValueLower = 'pmvalue') or (LValueLower = 'value') then
  begin
    AMethod := pmValue;
    Result := True;
  end
  else if (LValueLower = 'pmenvironment') or (LValueLower = 'environment') then
  begin
    AMethod := pmEnvironment;
    Result := True;
  end
  else if (LValueLower = 'pmfile') or (LValueLower = 'file') then
  begin
    AMethod := pmFile;
    Result := True;
  end
  else if (LValueLower = 'pmcallback') or (LValueLower = 'callback') then
  begin
    AMethod := pmCallback;
    Result := True;
  end
  else if (LValueLower = 'pminteractive') or (LValueLower = 'interactive') then
  begin
    AMethod := pmInteractive;
    Result := True;
  end
  else
  begin
    AMethod := pmNone;
    Result := False;
  end;
end;

function BuilderClientReplayStoreScopeMessage(
  const AField, ACallSite: string): string;
begin
  Result := nextpas.core.text.conv.Format(
    '%s is server-scoped. Client context builders do not install replay stores; remove it from %s.',
    [AField, ACallSite]
  );
end;

procedure AddClientReplayStoreScopeValidationErrors(
  const ABuilder: TSSLContextBuilderImpl; var AValidation: TBuildValidationResult);
begin
  if nextpas.core.text.conv.Trim(ABuilder.FServerEarlyDataReplayStoreFile) <> '' then
    AValidation.AddError(
      BuilderClientReplayStoreScopeMessage(
        'server_early_data_replay_store_file',
        'ValidateClient'
      )
    );

  if nextpas.core.text.conv.Trim(ABuilder.FServerEarlyDataReplayStoreDirectory) <> '' then
    AValidation.AddError(
      BuilderClientReplayStoreScopeMessage(
        'server_early_data_replay_store_directory',
        'ValidateClient'
      )
    );
end;

procedure EnsureClientReplayStoreScope(
  const ABuilder: TSSLContextBuilderImpl; const ACallSite: string);
begin
  if nextpas.core.text.conv.Trim(ABuilder.FServerEarlyDataReplayStoreFile) <> '' then
    raise ESSLConfigurationException.Create(
      BuilderClientReplayStoreScopeMessage(
        'server_early_data_replay_store_file',
        ACallSite
      )
    );

  if nextpas.core.text.conv.Trim(ABuilder.FServerEarlyDataReplayStoreDirectory) <> '' then
    raise ESSLConfigurationException.Create(
      BuilderClientReplayStoreScopeMessage(
        'server_early_data_replay_store_directory',
        ACallSite
      )
    );
end;

function TSSLContextBuilderImpl.GetSupportedPKCS11PINValue: string;
begin
  case FPKCS11PINMethod of
    pmNone:
      Result := '';
    pmValue,
    pmEnvironment,
    pmFile:
      Result := TPKCS11PINManager.GetPIN(FPKCS11PINMethod, FPKCS11PIN, nil, '');
  else
    raise ESSLConfigurationException.Create(
      UnsupportedBuilderPKCS11PINMethodMessage(FPKCS11PINMethod)
    );
  end;
end;

function TSSLContextBuilderImpl.BuildContextConfig(
  AContextType: TSSLContextType;
  ALibraryType: TSSLLibraryType
): TSSLContextConfig;
begin
  SyncOCSPStaplingOptions;
  SyncCertificateTransparencyOptions;

  Result := CreateDefaultContextConfig(AContextType);
  Result.LibraryType := ALibraryType;
  Result.ProtocolVersions := FProtocolVersions;
  Result.VerifyMode := EffectiveBuilderVerifyMode(Self, AContextType = sslCtxServer);
  Result.VerifyDepth := FVerifyDepth;
  Result.CAFile := FCAFile;
  Result.CAPath := FCAPath;
  Result.UseSystemRoots := FUseSystemRoots;
  Result.Options := FOptions;
  if FSessionCacheEnabled then
    Include(Result.Options, ssoEnableSessionCache)
  else
    Exclude(Result.Options, ssoEnableSessionCache);
  Result.SessionTimeout := FSessionTimeout;
  Result.ALPNProtocols := FALPNProtocols;
  Result.ClientEarlyDataEnabled := FClientEarlyDataEnabled;
  Result.ServerEarlyDataPolicy := FServerEarlyDataPolicy;
  Result.ServerMaxEarlyDataSize := FServerMaxEarlyDataSize;
  if FCertificatePEM = '' then
    Result.CertificateFile := FCertificateFile;
  if (FPKCS11URI = '') and (FPrivateKeyPEM = '') then
  begin
    Result.PrivateKeyFile := FPrivateKeyFile;
    Result.PrivateKeyPassword := FPrivateKeyPassword;
  end;
end;

function TSSLContextBuilderImpl.WithTLS12: ISSLContextBuilder;
begin
  FProtocolVersions := [sslProtocolTLS12];
  Result := Self;
end;

function TSSLContextBuilderImpl.WithTLS13: ISSLContextBuilder;
begin
  FProtocolVersions := [sslProtocolTLS13];
  Result := Self;
end;

function TSSLContextBuilderImpl.WithTLS12And13: ISSLContextBuilder;
begin
  FProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  Result := Self;
end;

function TSSLContextBuilderImpl.WithProtocols(AVersions: TSSLProtocolVersions): ISSLContextBuilder;
begin
  FProtocolVersions := AVersions;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithVerifyPeer: ISSLContextBuilder;
begin
  FVerifyMode := [sslVerifyPeer];
  FVerifyModeExplicit := True;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithVerifyNone: ISSLContextBuilder;
begin
  FVerifyMode := [sslVerifyNone];
  FVerifyModeExplicit := True;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithVerifyDepth(ADepth: Integer): ISSLContextBuilder;
begin
  FVerifyDepth := ADepth;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithCertificate(const AFile: string): ISSLContextBuilder;
begin
  FCertificateFile := AFile;
  FCertificatePEM := '';
  Result := Self;
end;

function TSSLContextBuilderImpl.WithCertificatePEM(const APEM: string): ISSLContextBuilder;
begin
  FCertificatePEM := APEM;
  FCertificateFile := '';
  Result := Self;
end;

function TSSLContextBuilderImpl.WithPrivateKey(const AFile: string; const APassword: string): ISSLContextBuilder;
begin
  FPrivateKeyFile := AFile;
  FPrivateKeyPassword := APassword;
  FPrivateKeyPEM := '';
  Result := Self;
end;

function TSSLContextBuilderImpl.WithPrivateKeyPEM(const APEM: string; const APassword: string): ISSLContextBuilder;
begin
  FPrivateKeyPEM := APEM;
  FPrivateKeyPassword := APassword;
  FPrivateKeyFile := '';
  Result := Self;
end;

function TSSLContextBuilderImpl.WithCAFile(const AFile: string): ISSLContextBuilder;
begin
  FCAFile := AFile;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithCAPath(const APath: string): ISSLContextBuilder;
begin
  FCAPath := APath;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithSystemRoots: ISSLContextBuilder;
begin
  FUseSystemRoots := True;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithCipherList(const ACiphers: string): ISSLContextBuilder;
begin
  FCipherList := ACiphers;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithTLS13Ciphersuites(const ACiphers: string): ISSLContextBuilder;
begin
  FTLS13Ciphersuites := ACiphers;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithSafeDefaults: ISSLContextBuilder;
begin
  // Apply modern, secure defaults
  FProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  FVerifyDepth := SSL_DEFAULT_VERIFY_DEPTH;
  FCipherList := SSL_DEFAULT_CIPHER_LIST;
  FTLS13Ciphersuites := SSL_DEFAULT_TLS13_CIPHERSUITES;
  FOptions := [
    ssoEnableSNI,
    ssoDisableCompression,      // Prevent CRIME attack
    ssoDisableRenegotiation,    // Prevent renegotiation attacks
    ssoCipherServerPreference,  // Server chooses cipher
    ssoNoSSLv2,                 // Disable insecure protocols
    ssoNoSSLv3,
    ssoNoTLSv1,
    ssoNoTLSv1_1
  ];
  Result := Self;
end;

function TSSLContextBuilderImpl.WithSNI(const AServerName: string): ISSLContextBuilder;
begin
  FServerName := AServerName;
  Include(FOptions, ssoEnableSNI);
  Result := Self;
end;

function TSSLContextBuilderImpl.WithALPN(const AProtocols: string): ISSLContextBuilder;
begin
  FALPNProtocols := AProtocols;
  Include(FOptions, ssoEnableALPN);
  Result := Self;
end;

function TSSLContextBuilderImpl.WithSessionCache(AEnabled: Boolean): ISSLContextBuilder;
begin
  FSessionCacheEnabled := AEnabled;
  if AEnabled then
    Include(FOptions, ssoEnableSessionCache)
  else
    Exclude(FOptions, ssoEnableSessionCache);
  Result := Self;
end;

function TSSLContextBuilderImpl.WithSessionTimeout(ASeconds: Integer): ISSLContextBuilder;
begin
  FSessionTimeout := ASeconds;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithSessionTimeout(
  const ATimeout: TTimeoutDuration): ISSLContextBuilder;
begin
  Result := WithSessionTimeout(TimeoutDurationToSessionTimeoutSeconds(ATimeout));
end;

function TSSLContextBuilderImpl.WithClientEarlyData(AEnabled: Boolean): ISSLContextBuilder;
begin
  FClientEarlyDataEnabled := AEnabled;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithServerEarlyDataPolicy(
  APolicy: TSSLEarlyDataServerPolicy): ISSLContextBuilder;
begin
  FServerEarlyDataPolicy := APolicy;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithServerMaxEarlyDataSize(
  ASize: Cardinal): ISSLContextBuilder;
begin
  FServerMaxEarlyDataSize := ASize;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithServerEarlyDataReplayStoreFile(
  const AFile: string): ISSLContextBuilder;
begin
  FServerEarlyDataReplayStoreFile := AFile;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithServerEarlyDataReplayStoreDirectory(
  const ADirectory: string): ISSLContextBuilder;
begin
  FServerEarlyDataReplayStoreDirectory := ADirectory;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithHTTPHooks(AHTTPGet: TSSLHTTPGetCallback;
  AHTTPPost: TSSLHTTPPostCallback): ISSLContextBuilder;
begin
  FHTTPGetCallback := AHTTPGet;
  FHTTPPostCallback := AHTTPPost;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithOption(AOption: TSSLOption): ISSLContextBuilder;
begin
  Include(FOptions, AOption);

  case AOption of
    ssoEnableOCSPStapling:
      FOCSPStaplingEnabled := True;
    ssoRequireOCSPStapling:
      FOCSPStaplingRequired := True;
    ssoRequireCertificateTransparency:
      FCertificateTransparencyRequired := True;
  else
    ;
  end;

  SyncOCSPStaplingOptions;
  SyncCertificateTransparencyOptions;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithOptions(AOptions: TSSLOptions): ISSLContextBuilder;
begin
  FOptions := FOptions + AOptions;
  SyncOCSPStaplingOptions;
  SyncCertificateTransparencyOptions;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithoutOption(AOption: TSSLOption): ISSLContextBuilder;
begin
  Exclude(FOptions, AOption);

  case AOption of
    ssoEnableOCSPStapling:
      begin
        FOCSPStaplingEnabled := False;
        FOCSPStaplingRequired := False;
      end;
    ssoRequireOCSPStapling:
      FOCSPStaplingRequired := False;
    ssoRequireCertificateTransparency:
      FCertificateTransparencyRequired := False;
  else
    ;
  end;

  SyncOCSPStaplingOptions;
  SyncCertificateTransparencyOptions;
  Result := Self;
end;

{ PKCS#11 Support }

function TSSLContextBuilderImpl.UsePKCS11(const AURI: string): ISSLContextBuilder;
begin
  FPKCS11URI := AURI;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithPKCS11PIN(const APIN: string): ISSLContextBuilder;
begin
  FPKCS11PIN := APIN;
  if not HasExplicitNonValuePKCS11PINMethod(FPKCS11PINMethod) then
    FPKCS11PINMethod := pmValue;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithPKCS11PINMethod(AMethod: TPKCS11PINMethod): ISSLContextBuilder;
begin
  FPKCS11PINMethod := AMethod;
  Result := Self;
end;

{ OCSP Stapling Support }

function TSSLContextBuilderImpl.WithOCSPStapling(AEnabled: Boolean): ISSLContextBuilder;
begin
  FOCSPStaplingEnabled := AEnabled;
  if AEnabled then
    Include(FOptions, ssoEnableOCSPStapling)
  else
  begin
    Exclude(FOptions, ssoEnableOCSPStapling);
    Exclude(FOptions, ssoRequireOCSPStapling);
    FOCSPStaplingRequired := False;
  end;

  SyncOCSPStaplingOptions;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithOCSPStaplingRequired(ARequired: Boolean): ISSLContextBuilder;
begin
  FOCSPStaplingRequired := ARequired;

  if ARequired then
    Include(FOptions, ssoRequireOCSPStapling)
  else
    Exclude(FOptions, ssoRequireOCSPStapling);

  SyncOCSPStaplingOptions;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithServerOCSPStapledResponseFile(
  const AFile: string): ISSLContextBuilder;
begin
  FServerOCSPStapledResponseFile := AFile;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithCertificateTransparencyRequired(
  ARequired: Boolean): ISSLContextBuilder;
begin
  FCertificateTransparencyRequired := ARequired;

  if ARequired then
    Include(FOptions, ssoRequireCertificateTransparency)
  else
    Exclude(FOptions, ssoRequireCertificateTransparency);

  SyncCertificateTransparencyOptions;
  Result := Self;
end;

function TSSLContextBuilderImpl.WithCertVerifyCache(AEnabled: Boolean): ISSLContextBuilder;
begin
  if AEnabled then
    Include(FOptions, ssoEnableCertVerifyCache)
  else
    Exclude(FOptions, ssoEnableCertVerifyCache);
  Result := Self;
end;

function TSSLContextBuilderImpl.BuildClient: ISSLContext;
var
  LHttpHooks: ISSLHttpHooksAccess;
  ContextBackend: TSSLLibraryType;
  SelectedBackend: TSSLLibraryType;
  MatchScore: Integer;
  LConfig: TSSLContextConfig;
begin
  ContextBackend := sslAutoDetect;
  EnsureClientReplayStoreScope(Self, 'BuildClient');

  // v1.3.0: 自动后端选择
  if FAutoSelectBackend then
  begin
    if not SelectBestBackend(FBackendRequirements, SelectedBackend, MatchScore) then
      raise ESSLException.Create('No suitable SSL backend found for requirements');
    ContextBackend := SelectedBackend;
  end
  else if FExplicitBackendSet then
    ContextBackend := FExplicitBackend
  else
  begin
    ContextBackend := TSSLFactory.GetDefaultLibrary;
    if ContextBackend = sslAutoDetect then
      ContextBackend := TSSLFactory.DetectBestLibrary;
  end;

  LConfig := BuildContextConfig(sslCtxClient, ContextBackend);
  Result := TSSLFactory.CreateContext(LConfig);

  if Result = nil then
    raise ESSLException.Create('Failed to create SSL client context');

  Result.SetOptions(LConfig.Options);

  if Supports(Result, ISSLHttpHooksAccess, LHttpHooks) then
  begin
    LHttpHooks.SetHTTPGetCallback(FHTTPGetCallback);
    LHttpHooks.SetHTTPPostCallback(FHTTPPostCallback);
  end;

  // Imported dual-state configs are documented as PEM-first.
  if FCertificatePEM <> '' then
    Result.LoadCertificatePEM(FCertificatePEM);

  // Load private key (PKCS#11 or file)
  if FPKCS11URI <> '' then
  begin
    // PKCS#11 private key - Use LoadPrivateKey which supports PKCS#11 URIs
    // The underlying ISSLContext.LoadPrivateKey detects PKCS#11 URIs and
    // delegates to LoadPrivateKeyFromPKCS11 internally
    Result.LoadPrivateKey(FPKCS11URI, GetSupportedPKCS11PINValue);
  end
  else if FPrivateKeyPEM <> '' then
    Result.LoadPrivateKeyPEM(FPrivateKeyPEM, FPrivateKeyPassword);

  // Backend-gated custom cipher overrides stay on the original builder path.
  if FCipherList <> '' then
    Result.SetCipherList(FCipherList);

  if FTLS13Ciphersuites <> '' then
    Result.SetCipherSuites(FTLS13Ciphersuites);

  if FServerName <> '' then
    LogBuilderContextLevelServerNameCompatibilityWarning(
      'TSSLContextBuilderImpl.BuildClient',
      False
    );

  Result.SetSessionCacheMode(FSessionCacheEnabled);
end;

function TSSLContextBuilderImpl.BuildServer: ISSLContext;
var
  LHttpHooks: ISSLHttpHooksAccess;
  LEarlyDataReplayInstaller: IFreePascalContextEarlyDataReplayInstaller;
  LEarlyDataReplayDirectoryInstaller: IFreePascalContextEarlyDataReplayDirectoryInstaller;
  LServerOCSPStaplingContext: ISSLServerOCSPStaplingContext;
  ContextBackend: TSSLLibraryType;
  SelectedBackend: TSSLLibraryType;
  MatchScore: Integer;
  LConfig: TSSLContextConfig;
begin
  ContextBackend := sslAutoDetect;

  // v1.3.0: 自动后端选择
  if FAutoSelectBackend then
  begin
    if not SelectBestBackend(FBackendRequirements, SelectedBackend, MatchScore) then
      raise ESSLException.Create('No suitable SSL backend found for requirements');
    ContextBackend := SelectedBackend;
  end
  else if FExplicitBackendSet then
    ContextBackend := FExplicitBackend
  else
  begin
    ContextBackend := TSSLFactory.GetDefaultLibrary;
    if ContextBackend = sslAutoDetect then
      ContextBackend := TSSLFactory.DetectBestLibrary;
  end;

  // Validate required server material before the context-safe factory path can
  // load ordinary certificate/key files.
  if (FCertificateFile = '') and (FCertificatePEM = '') then
    raise ESSLException.Create('Server context requires a certificate');

  if (FPrivateKeyFile = '') and (FPrivateKeyPEM = '') and (FPKCS11URI = '') then
    raise ESSLException.Create('Server context requires a private key');

  LConfig := BuildContextConfig(sslCtxServer, ContextBackend);
  Result := TSSLFactory.CreateContext(LConfig);

  if Result = nil then
    raise ESSLException.Create('Failed to create SSL server context');

  Result.SetOptions(LConfig.Options);

  if Supports(Result, ISSLHttpHooksAccess, LHttpHooks) then
  begin
    LHttpHooks.SetHTTPGetCallback(FHTTPGetCallback);
    LHttpHooks.SetHTTPPostCallback(FHTTPPostCallback);
  end;

  if FCertificatePEM <> '' then
    Result.LoadCertificatePEM(FCertificatePEM);

  // Load private key (PKCS#11 or file)
  if FPKCS11URI <> '' then
  begin
    // PKCS#11 private key - Use LoadPrivateKey which supports PKCS#11 URIs
    // The underlying ISSLContext.LoadPrivateKey detects PKCS#11 URIs and
    // delegates to LoadPrivateKeyFromPKCS11 internally
    Result.LoadPrivateKey(FPKCS11URI, GetSupportedPKCS11PINValue);
  end
  else if FPrivateKeyPEM <> '' then
    Result.LoadPrivateKeyPEM(FPrivateKeyPEM, FPrivateKeyPassword);

  if FServerOCSPStapledResponseFile <> '' then
  begin
    if not Supports(Result, ISSLServerOCSPStaplingContext, LServerOCSPStaplingContext) then
      raise ESSLException.Create(
        'Configured server_ocsp_stapled_response_file requires a backend that implements ISSLServerOCSPStaplingContext'
      );
    LServerOCSPStaplingContext.LoadServerStapledOCSPResponseFile(FServerOCSPStapledResponseFile);
  end;

  if (nextpas.core.text.conv.Trim(FServerEarlyDataReplayStoreFile) <> '') and
    (nextpas.core.text.conv.Trim(FServerEarlyDataReplayStoreDirectory) <> '') then
    raise ESSLException.Create(
      'Configured server_early_data_replay_store_file and ' +
      'server_early_data_replay_store_directory are mutually exclusive; configure not both'
    );

  if FServerEarlyDataReplayStoreFile <> '' then
  begin
    if not Supports(Result, IFreePascalContextEarlyDataReplayInstaller, LEarlyDataReplayInstaller) then
      raise ESSLException.Create(
        'Configured server_early_data_replay_store_file requires a backend that implements IFreePascalContextEarlyDataReplayInstaller'
      );
    if not LEarlyDataReplayInstaller.InstallFileBackedReplayLedger(FServerEarlyDataReplayStoreFile) then
      raise ESSLException.Create(
        'Configured server_early_data_replay_store_file could not install the requested replay store'
      );
  end;

  if FServerEarlyDataReplayStoreDirectory <> '' then
  begin
    if not Supports(Result, IFreePascalContextEarlyDataReplayDirectoryInstaller,
      LEarlyDataReplayDirectoryInstaller) then
      raise ESSLException.Create(
        'Configured server_early_data_replay_store_directory requires a backend that implements IFreePascalContextEarlyDataReplayDirectoryInstaller'
      );
    if not LEarlyDataReplayDirectoryInstaller.InstallDirectoryBackedReplayLedger(
      FServerEarlyDataReplayStoreDirectory
    ) then
      raise ESSLException.Create(
        'Configured server_early_data_replay_store_directory could not install the requested replay store'
      );
  end;

  // Backend-gated custom cipher overrides stay on the original builder path.
  if FCipherList <> '' then
    Result.SetCipherList(FCipherList);

  if FTLS13Ciphersuites <> '' then
    Result.SetCipherSuites(FTLS13Ciphersuites);

  if FServerName <> '' then
    LogBuilderContextLevelServerNameCompatibilityWarning(
      'TSSLContextBuilderImpl.BuildServer',
      True
    );

  Result.SetSessionCacheMode(FSessionCacheEnabled);
end;

function TSSLContextBuilderImpl.TryBuildClient(out AContext: ISSLContext): TSSLOperationResult;
begin
  AContext := nil;

  try
    AContext := BuildClient;
    if AContext = nil then
    begin
      Result := TSSLOperationResult.Err(sslErrConfiguration, 'Failed to create SSL client context');
      Exit;
    end;

    Result := TSSLOperationResult.Ok;
  except
    on E: ESSLException do
    begin
      AContext := nil;
      Result := TSSLOperationResult.Err(sslErrConfiguration, 'SSL error: ' + E.Message);
    end;
    on E: Exception do
    begin
      AContext := nil;
      Result := TSSLOperationResult.Err(sslErrConfiguration, E.Message);
    end;
  end;
end;

function TSSLContextBuilderImpl.TryBuildServer(out AContext: ISSLContext): TSSLOperationResult;
begin
  AContext := nil;

  try
    AContext := BuildServer;
    if AContext = nil then
    begin
      Result := TSSLOperationResult.Err(sslErrConfiguration, 'Failed to create SSL server context');
      Exit;
    end;

    Result := TSSLOperationResult.Ok;
  except
    on E: ESSLException do
    begin
      AContext := nil;
      Result := TSSLOperationResult.Err(sslErrConfiguration, 'SSL error: ' + E.Message);
    end;
    on E: Exception do
    begin
      AContext := nil;
      Result := TSSLOperationResult.Err(sslErrConfiguration, E.Message);
    end;
  end;
end;

{ Configuration Validation - Phase 2.1.2 }

function ValidateCommonBuilderSettings(const ABuilder: TSSLContextBuilderImpl;
  AForServer: Boolean): TBuildValidationResult;
var
  LVerifyMode: TSSLVerifyModes;
begin
  Result := TBuildValidationResult.Ok;
  LVerifyMode := EffectiveBuilderVerifyMode(ABuilder, AForServer);

  // Check protocol versions
  if ABuilder.FProtocolVersions = [] then
    Result.AddWarning('No protocol versions specified, will use default');

  // Check for insecure protocols
  if sslProtocolSSL2 in ABuilder.FProtocolVersions then
    Result.AddError('SSL 2.0 is insecure and should not be used');
  if sslProtocolSSL3 in ABuilder.FProtocolVersions then
    Result.AddError('SSL 3.0 is insecure and should not be used');

  // Warn about old TLS versions
  if sslProtocolTLS10 in ABuilder.FProtocolVersions then
    Result.AddWarning('TLS 1.0 is deprecated and should be avoided');
  if sslProtocolTLS11 in ABuilder.FProtocolVersions then
    Result.AddWarning('TLS 1.1 is deprecated and should be avoided');

  // Check verification settings
  if (not AForServer) and (not (sslVerifyPeer in LVerifyMode)) then
    Result.AddWarning('Certificate verification is disabled - insecure for production');

  if ABuilder.FDevelopmentPreset then
    Result.AddWarning('Development preset active - not suitable for production deployment');

  // Check CA configuration when verification is enabled
  if (sslVerifyPeer in LVerifyMode) and
    (ABuilder.FCAFile = '') and (ABuilder.FCAPath = '') and (not ABuilder.FUseSystemRoots) then
  begin
    if AForServer then
      Result.AddWarning('Client verification enabled but no CA certificates configured')
    else
      Result.AddWarning('Peer verification enabled but no CA certificates configured');
  end;

  // Context-level SNI remains supported for backward compatibility,
  // but its meaning differs between client and server contexts.
  if ABuilder.FServerName <> '' then
  begin
    if AForServer then
      Result.AddWarning(
        'WithSNI is deprecated context-level ServerName compatibility on server contexts; BuildServer ignores it and server-side connections ignore it'
      )
    else
      Result.AddWarning(
        'WithSNI is deprecated context-level SNI compatibility on client contexts; BuildClient ignores it; prefer per-connection hostname via TSSLConnectionBuilder.WithHostname or ISSLClientConnection.SetServerName'
      );
  end;

  if not AForServer then
    AddClientReplayStoreScopeValidationErrors(ABuilder, Result);

  if ABuilder.FPKCS11URI <> '' then
  begin
    if (ABuilder.FPKCS11PINMethod in [pmValue, pmEnvironment, pmFile]) and
      (ABuilder.FPKCS11PIN = '') then
      Result.AddError(
        MissingBuilderPKCS11PINSourceValueMessage(ABuilder.FPKCS11PINMethod)
      )
    else if ABuilder.FPKCS11PINMethod in [pmCallback, pmInteractive] then
      Result.AddError(
        UnsupportedBuilderPKCS11PINMethodMessage(ABuilder.FPKCS11PINMethod)
      );
  end;

  // Check cipher configuration
  if (ABuilder.FCipherList <> '') and (Pos('NULL-', UpperCase(ABuilder.FCipherList)) > 0) then
    Result.AddError('NULL cipher detected in cipher list - provides no encryption');
  if (ABuilder.FCipherList <> '') and (Pos('EXPORT', UpperCase(ABuilder.FCipherList)) > 0) and
    (Pos('!EXPORT', UpperCase(ABuilder.FCipherList)) = 0) then
    Result.AddWarning('EXPORT cipher detected - uses weak encryption');
  if (ABuilder.FCipherList <> '') and (Pos('RC4', UpperCase(ABuilder.FCipherList)) > 0) and
    (Pos('!RC4', UpperCase(ABuilder.FCipherList)) = 0) then
    Result.AddWarning('RC4 cipher detected - considered insecure');

  // Check session configuration
  if ABuilder.FSessionTimeout < 0 then
    Result.AddError('Session timeout cannot be negative');
  if ABuilder.FSessionTimeout > 86400 then  // 24 hours
    Result.AddWarning('Session timeout is very long (> 24 hours)');
end;

function TSSLContextBuilderImpl.ValidateClient: TBuildValidationResult;
begin
  Result := ValidateCommonBuilderSettings(Self, False);
end;

function TSSLContextBuilderImpl.ValidateServer: TBuildValidationResult;
begin
  Result := ValidateCommonBuilderSettings(Self, True);

  // Server-specific validations

  // Check certificate configuration (REQUIRED for server)
  if (FCertificateFile = '') and (FCertificatePEM = '') then
    Result.AddError('Server context requires a certificate (use WithCertificate or WithCertificatePEM)');

  // Check private key configuration (REQUIRED for server)
  if (FPrivateKeyFile = '') and (FPrivateKeyPEM = '') and (FPKCS11URI = '') then
    Result.AddError('Server context requires a private key (use WithPrivateKey, WithPrivateKeyPEM, or UsePKCS11)');

  // Check if both file and PEM are set for certificate (potentially confusing)
  if (FCertificateFile <> '') and (FCertificatePEM <> '') then
    Result.AddWarning('Both certificate file and PEM are set - PEM will be used');

  // Check if both file and PEM are set for private key
  if (FPrivateKeyFile <> '') and (FPrivateKeyPEM <> '') then
    Result.AddWarning('Both private key file and PEM are set - PEM will be used');
end;

function TSSLContextBuilderImpl.Validate: TBuildValidationResult;
begin
  // Generic validation (works for both client and server)
  Result := ValidateClient;
end;

function TSSLContextBuilderImpl.BuildClientWithValidation(out AValidation: TBuildValidationResult): ISSLContext;
begin
  AValidation := ValidateClient;

  if not AValidation.IsValid then
    raise ESSLConfigurationException.Create(
      'Configuration validation failed: ' + AValidation.Errors[0]
    );

  Result := BuildClient;
end;

function TSSLContextBuilderImpl.BuildServerWithValidation(out AValidation: TBuildValidationResult): ISSLContext;
begin
  AValidation := ValidateServer;

  if not AValidation.IsValid then
    raise ESSLConfigurationException.Create(
      'Configuration validation failed: ' + AValidation.Errors[0]
    );

  Result := BuildServer;
end;

{ Configuration Import/Export - Phase 2.1.3 }

function ProtocolVersionsToJSONArray(const AProtocols: TSSLProtocolVersions): string;
var
  LBuilder: IJsonBuilder;
  LProtocol: TSSLProtocolVersion;
begin
  LBuilder := JsonBuilder;
  LBuilder.BeginArray;
  for LProtocol := Low(TSSLProtocolVersion) to High(TSSLProtocolVersion) do
    if LProtocol in AProtocols then
      LBuilder.Int(Ord(LProtocol));
  LBuilder.EndArray;
  Result := LBuilder.ToString;
end;

function CipherSupportToJSONArray(const ACiphers: TSSLCipherSupport): string;
var
  LBuilder: IJsonBuilder;
  LCipher: TSSLCipher;
begin
  LBuilder := JsonBuilder;
  LBuilder.BeginArray;
  for LCipher := Low(TSSLCipher) to High(TSSLCipher) do
    if LCipher in ACiphers then
      LBuilder.Int(Ord(LCipher));
  LBuilder.EndArray;
  Result := LBuilder.ToString;
end;

function HashSupportToJSONArray(const AHashes: TSSLHashSupport): string;
var
  LBuilder: IJsonBuilder;
  LHash: TSSLHash;
begin
  LBuilder := JsonBuilder;
  LBuilder.BeginArray;
  for LHash := Low(TSSLHash) to High(TSSLHash) do
    if LHash in AHashes then
      LBuilder.Int(Ord(LHash));
  LBuilder.EndArray;
  Result := LBuilder.ToString;
end;

function KeyExchangeSupportToJSONArray(
  const AKeyExchanges: TSSLKeyExchangeSupport): string;
var
  LBuilder: IJsonBuilder;
  LKeyExchange: TSSLKeyExchange;
begin
  LBuilder := JsonBuilder;
  LBuilder.BeginArray;
  for LKeyExchange := Low(TSSLKeyExchange) to High(TSSLKeyExchange) do
    if LKeyExchange in AKeyExchanges then
      LBuilder.Int(Ord(LKeyExchange));
  LBuilder.EndArray;
  Result := LBuilder.ToString;
end;

function FeaturesToJSONArray(const AFeatures: TSSLFeatures): string;
var
  LBuilder: IJsonBuilder;
  LFeature: TSSLFeature;
begin
  LBuilder := JsonBuilder;
  LBuilder.BeginArray;
  for LFeature := Low(TSSLFeature) to High(TSSLFeature) do
    if LFeature in AFeatures then
      LBuilder.Int(Ord(LFeature));
  LBuilder.EndArray;
  Result := LBuilder.ToString;
end;

const
  CONTEXT_SERVER_NAME_COMPAT_MODE = 'deprecated_context_sni';

procedure JSONArrayToProtocolVersions(const AArray: TJsonValue; out AProtocols: TSSLProtocolVersions);
var
  I: UInt32;
begin
  AProtocols := [];
  if not AArray.IsValid then
    Exit;

  for I := 0 to AArray.ArrayLen - 1 do
    Include(AProtocols, TSSLProtocolVersion(AArray.ArrayGet(I).AsInt));
end;

procedure JSONArrayToCipherSupport(const AArray: TJsonValue; out ACiphers: TSSLCipherSupport);
var
  I: UInt32;
begin
  ACiphers := [];
  if not AArray.IsValid then
    Exit;

  for I := 0 to AArray.ArrayLen - 1 do
    Include(ACiphers, TSSLCipher(AArray.ArrayGet(I).AsInt));
end;

procedure JSONArrayToHashSupport(const AArray: TJsonValue; out AHashes: TSSLHashSupport);
var
  I: UInt32;
begin
  AHashes := [];
  if not AArray.IsValid then
    Exit;

  for I := 0 to AArray.ArrayLen - 1 do
    Include(AHashes, TSSLHash(AArray.ArrayGet(I).AsInt));
end;

procedure JSONArrayToKeyExchangeSupport(
  const AArray: TJsonValue; out AKeyExchanges: TSSLKeyExchangeSupport);
var
  I: UInt32;
begin
  AKeyExchanges := [];
  if not AArray.IsValid then
    Exit;

  for I := 0 to AArray.ArrayLen - 1 do
    Include(AKeyExchanges, TSSLKeyExchange(AArray.ArrayGet(I).AsInt));
end;

procedure JSONArrayToFeatures(const AArray: TJsonValue; out AFeatures: TSSLFeatures);
var
  I: UInt32;
begin
  AFeatures := [];
  if not AArray.IsValid then
    Exit;

  for I := 0 to AArray.ArrayLen - 1 do
    Include(AFeatures, TSSLFeature(AArray.ArrayGet(I).AsInt));
end;

function RequirementsToJSON(const ARequirements: TSSLRequirements): string;
var
  LBuilder: IJsonBuilder;
begin
  LBuilder := JsonBuilder;
  LBuilder.BeginObject;
  LBuilder.Key('required_protocols');
  LBuilder.RawJson(ProtocolVersionsToJSONArray(ARequirements.RequiredProtocols));
  LBuilder.Key('required_ciphers');
  LBuilder.RawJson(CipherSupportToJSONArray(ARequirements.RequiredCiphers));
  LBuilder.Key('required_hashes');
  LBuilder.RawJson(HashSupportToJSONArray(ARequirements.RequiredHashes));
  LBuilder.Key('required_key_exchanges');
  LBuilder.RawJson(KeyExchangeSupportToJSONArray(ARequirements.RequiredKeyExchanges));
  LBuilder.Key('required_features');
  LBuilder.RawJson(FeaturesToJSONArray(ARequirements.RequiredFeatures));
  LBuilder.Key('preferred_ciphers');
  LBuilder.RawJson(CipherSupportToJSONArray(ARequirements.PreferredCiphers));
  LBuilder.Key('preferred_hashes');
  LBuilder.RawJson(HashSupportToJSONArray(ARequirements.PreferredHashes));
  LBuilder.Key('min_security_score');
  LBuilder.Int(ARequirements.MinSecurityScore);
  LBuilder.Key('min_performance_score');
  LBuilder.Int(ARequirements.MinPerformanceScore);
  LBuilder.Key('min_compatibility_level');
  LBuilder.Int(ARequirements.MinCompatibilityLevel);
  LBuilder.Key('prefer_os_native');
  LBuilder.Bool(ARequirements.PlatformPreferences.PreferOSNative);
  LBuilder.Key('prefer_hardware_accel');
  LBuilder.Bool(ARequirements.PlatformPreferences.PreferHardwareAccel);
  LBuilder.Key('prefer_fips_compliant');
  LBuilder.Bool(ARequirements.PlatformPreferences.PreferFIPSCompliant);
  LBuilder.Key('require_pkcs11');
  LBuilder.Bool(ARequirements.PlatformPreferences.RequirePKCS11);
  LBuilder.Key('require_tpm');
  LBuilder.Bool(ARequirements.PlatformPreferences.RequireTPM);
  LBuilder.Key('require_system_cert_store');
  LBuilder.Bool(ARequirements.PlatformPreferences.RequireSystemCertStore);
  LBuilder.Key('optimization_target');
  LBuilder.Int(Ord(ARequirements.OptimizationTarget));
  LBuilder.EndObject;
  Result := LBuilder.ToString;
end;

procedure JSONObjectToRequirements(const AObject: TJsonValue; out ARequirements: TSSLRequirements);
begin
  FillChar(ARequirements, SizeOf(ARequirements), 0);
  if not AObject.IsValid then
    Exit;

  if AObject.ObjectHas('required_protocols') then
    JSONArrayToProtocolVersions(AObject.ObjectGet('required_protocols'), ARequirements.RequiredProtocols);
  if AObject.ObjectHas('required_ciphers') then
    JSONArrayToCipherSupport(AObject.ObjectGet('required_ciphers'), ARequirements.RequiredCiphers);
  if AObject.ObjectHas('required_hashes') then
    JSONArrayToHashSupport(AObject.ObjectGet('required_hashes'), ARequirements.RequiredHashes);
  if AObject.ObjectHas('required_key_exchanges') then
    JSONArrayToKeyExchangeSupport(
      AObject.ObjectGet('required_key_exchanges'),
      ARequirements.RequiredKeyExchanges
    );
  if AObject.ObjectHas('required_features') then
    JSONArrayToFeatures(AObject.ObjectGet('required_features'), ARequirements.RequiredFeatures);
  if AObject.ObjectHas('preferred_ciphers') then
    JSONArrayToCipherSupport(AObject.ObjectGet('preferred_ciphers'), ARequirements.PreferredCiphers);
  if AObject.ObjectHas('preferred_hashes') then
    JSONArrayToHashSupport(AObject.ObjectGet('preferred_hashes'), ARequirements.PreferredHashes);
  if AObject.ObjectHas('min_security_score') then
    ARequirements.MinSecurityScore := AObject.ObjectGet('min_security_score').AsInt;
  if AObject.ObjectHas('min_performance_score') then
    ARequirements.MinPerformanceScore := AObject.ObjectGet('min_performance_score').AsInt;
  if AObject.ObjectHas('min_compatibility_level') then
    ARequirements.MinCompatibilityLevel := AObject.ObjectGet('min_compatibility_level').AsInt;
  if AObject.ObjectHas('prefer_os_native') then
    ARequirements.PlatformPreferences.PreferOSNative := AObject.ObjectGet('prefer_os_native').AsBool;
  if AObject.ObjectHas('prefer_hardware_accel') then
    ARequirements.PlatformPreferences.PreferHardwareAccel := AObject.ObjectGet('prefer_hardware_accel').AsBool;
  if AObject.ObjectHas('prefer_fips_compliant') then
    ARequirements.PlatformPreferences.PreferFIPSCompliant := AObject.ObjectGet('prefer_fips_compliant').AsBool;
  if AObject.ObjectHas('require_pkcs11') then
    ARequirements.PlatformPreferences.RequirePKCS11 := AObject.ObjectGet('require_pkcs11').AsBool;
  if AObject.ObjectHas('require_tpm') then
    ARequirements.PlatformPreferences.RequireTPM := AObject.ObjectGet('require_tpm').AsBool;
  if AObject.ObjectHas('require_system_cert_store') then
    ARequirements.PlatformPreferences.RequireSystemCertStore := AObject.ObjectGet('require_system_cert_store').AsBool;
  if AObject.ObjectHas('optimization_target') then
    ARequirements.OptimizationTarget := TSSLOptimizationTarget(AObject.ObjectGet('optimization_target').AsInt);
end;

function TSSLContextBuilderImpl.ExportToJSON: string;
var
  LBuilder: IJsonBuilder;
  LProto: TSSLProtocolVersion;
  LVerifyMode: TSSLVerifyMode;
  LOption: TSSLOption;
begin
  LBuilder := JsonBuilder;
  LBuilder.BeginObject;

  // Protocol versions
  LBuilder.Key('protocols');
  LBuilder.BeginArray;
  for LProto := Low(TSSLProtocolVersion) to High(TSSLProtocolVersion) do
    if LProto in FProtocolVersions then
      LBuilder.Int(Ord(LProto));
  LBuilder.EndArray;

  // Verification mode
  LBuilder.Key('verify_modes');
  LBuilder.BeginArray;
  for LVerifyMode := Low(TSSLVerifyMode) to High(TSSLVerifyMode) do
    if LVerifyMode in FVerifyMode then
      LBuilder.Int(Ord(LVerifyMode));
  LBuilder.EndArray;
  LBuilder.Key('verify_mode_explicit');
  LBuilder.Bool(FVerifyModeExplicit);
  LBuilder.Key('verify_depth');
  LBuilder.Int(FVerifyDepth);

  // Certificate configuration
  LBuilder.Key('certificate_file');
  LBuilder.Str(FCertificateFile);
  LBuilder.Key('certificate_pem');
  LBuilder.Str(FCertificatePEM);
  LBuilder.Key('private_key_file');
  LBuilder.Str(FPrivateKeyFile);
  LBuilder.Key('private_key_pem');
  LBuilder.Str(FPrivateKeyPEM);
  LBuilder.Key('pkcs11_uri');
  LBuilder.Str(FPKCS11URI);
  if IsSerializablePKCS11PINSourceMethod(FPKCS11PINMethod) then
  begin
    LBuilder.Key('pkcs11_pin_method');
    LBuilder.Int(Ord(FPKCS11PINMethod));
    LBuilder.Key('pkcs11_pin');
    LBuilder.Str(FPKCS11PIN);
  end;
  LBuilder.Key('ca_file');
  LBuilder.Str(FCAFile);
  LBuilder.Key('ca_path');
  LBuilder.Str(FCAPath);
  LBuilder.Key('use_system_roots');
  LBuilder.Bool(FUseSystemRoots);

  // Cipher configuration
  LBuilder.Key('cipher_list');
  LBuilder.Str(FCipherList);
  LBuilder.Key('tls13_ciphersuites');
  LBuilder.Str(FTLS13Ciphersuites);

  // Advanced options
  LBuilder.Key('server_name');
  LBuilder.Str(FServerName);
  if FServerName <> '' then
  begin
    LBuilder.Key('server_name_mode');
    LBuilder.Str(CONTEXT_SERVER_NAME_COMPAT_MODE);
  end;
  LBuilder.Key('alpn_protocols');
  LBuilder.Str(FALPNProtocols);
  LBuilder.Key('session_cache_enabled');
  LBuilder.Bool(FSessionCacheEnabled);
  LBuilder.Key('session_timeout');
  LBuilder.Int(FSessionTimeout);
  LBuilder.Key('client_early_data_enabled');
  LBuilder.Bool(FClientEarlyDataEnabled);
  LBuilder.Key('server_early_data_policy');
  LBuilder.Int(Ord(FServerEarlyDataPolicy));
  LBuilder.Key('server_max_early_data_size');
  LBuilder.Int(Int64(FServerMaxEarlyDataSize));
  LBuilder.Key('server_early_data_replay_store_file');
  LBuilder.Str(FServerEarlyDataReplayStoreFile);
  LBuilder.Key('server_early_data_replay_store_directory');
  LBuilder.Str(FServerEarlyDataReplayStoreDirectory);
  if FAutoSelectBackend then
  begin
    LBuilder.Key('auto_select_backend');
    LBuilder.Bool(True);
    LBuilder.Key('backend_requirements');
    LBuilder.RawJson(RequirementsToJSON(FBackendRequirements));
  end
  else if FExplicitBackendSet then
  begin
    LBuilder.Key('explicit_backend');
    LBuilder.Int(Ord(FExplicitBackend));
  end;

  // Options
  LBuilder.Key('options');
  LBuilder.BeginArray;
  for LOption := Low(TSSLOption) to High(TSSLOption) do
    if LOption in FOptions then
      LBuilder.Int(Ord(LOption));
  LBuilder.EndArray;

  // OCSP Stapling
  LBuilder.Key('ocsp_stapling_enabled');
  LBuilder.Bool(FOCSPStaplingEnabled);
  LBuilder.Key('ocsp_stapling_required');
  LBuilder.Bool(FOCSPStaplingRequired);
  LBuilder.Key('server_ocsp_stapled_response_file');
  LBuilder.Str(FServerOCSPStapledResponseFile);
  LBuilder.Key('certificate_transparency_required');
  LBuilder.Bool(FCertificateTransparencyRequired);

  LBuilder.EndObject;
  Result := LBuilder.ToString;
end;

function TSSLContextBuilderImpl.ImportFromJSON(const AJSON: string): ISSLContextBuilder;
var
  LDoc: IJsonDocument;
  LRoot, LBackendReq, LProtocolsArr, LVerifyArr, LOptionsArr, LPKCS11PINMethodVal: TJsonValue;
  LImportedRequirements: TSSLRequirements;
  LImportedExplicitBackend: TSSLLibraryType;
  LImportedPKCS11PINMethod: TPKCS11PINMethod;
  LImportedVerifyModeExplicit: Boolean;
  LHasImportedPKCS11PINMethod: Boolean;
  LHasImportedVerifyModeExplicit: Boolean;
  LHasExplicitBackend: Boolean;
  LHasAutoSelectBackend: Boolean;
  LAutoSelectBackend: Boolean;
  I: UInt32;
begin
  Result := Self;

  if AJSON = '' then
    Exit;

  FillChar(LImportedRequirements, SizeOf(LImportedRequirements), 0);
  LHasImportedPKCS11PINMethod := False;
  LHasImportedVerifyModeExplicit := False;
  LHasExplicitBackend := False;
  LHasAutoSelectBackend := False;
  LAutoSelectBackend := False;

  LDoc := JsonParse(AJSON);
  if LDoc.HasError then
    Exit;

  LRoot := LDoc.Root;
  if not LRoot.IsObject then
    Exit;

  // Protocol versions
  if LRoot.ObjectHas('protocols') then
  begin
    LProtocolsArr := LRoot.ObjectGet('protocols');
    FProtocolVersions := [];
    for I := 0 to LProtocolsArr.ArrayLen - 1 do
      if IsValidProtocolVersionOrdinal(LProtocolsArr.ArrayGet(I).AsInt) then
        Include(FProtocolVersions, TSSLProtocolVersion(LProtocolsArr.ArrayGet(I).AsInt));
  end;

  // Verification mode
  if LRoot.ObjectHas('verify_modes') then
  begin
    LVerifyArr := LRoot.ObjectGet('verify_modes');
    FVerifyMode := [];
    for I := 0 to LVerifyArr.ArrayLen - 1 do
      if IsValidVerifyModeOrdinal(LVerifyArr.ArrayGet(I).AsInt) then
        Include(FVerifyMode, TSSLVerifyMode(LVerifyArr.ArrayGet(I).AsInt));
  end;

  if LRoot.ObjectHas('verify_mode_explicit') then
  begin
    LImportedVerifyModeExplicit := LRoot.ObjectGet('verify_mode_explicit').AsBool;
    LHasImportedVerifyModeExplicit := True;
  end;

  if LRoot.ObjectHas('verify_depth') then
    FVerifyDepth := LRoot.ObjectGet('verify_depth').AsInt;

  // Certificate configuration
  if LRoot.ObjectHas('certificate_file') then
  begin
    FCertificateFile := LRoot.ObjectGet('certificate_file').AsStr.ToString;
    FCertificatePEM := '';
  end;
  if LRoot.ObjectHas('certificate_pem') then
  begin
    FCertificatePEM := LRoot.ObjectGet('certificate_pem').AsStr.ToString;
    FCertificateFile := '';
  end;
  if LRoot.ObjectHas('private_key_file') then
  begin
    FPrivateKeyFile := LRoot.ObjectGet('private_key_file').AsStr.ToString;
    FPrivateKeyPEM := '';
  end;
  if LRoot.ObjectHas('private_key_pem') then
  begin
    FPrivateKeyPEM := LRoot.ObjectGet('private_key_pem').AsStr.ToString;
    FPrivateKeyFile := '';
  end;
  if LRoot.ObjectHas('pkcs11_uri') then
    FPKCS11URI := LRoot.ObjectGet('pkcs11_uri').AsStr.ToString;
  LPKCS11PINMethodVal := LRoot.ObjectGet('pkcs11_pin_method');
  if LPKCS11PINMethodVal.IsValid then
  begin
    if LPKCS11PINMethodVal.IsInt and
      TryParsePKCS11PINMethodOrdinal(LPKCS11PINMethodVal.AsInt, LImportedPKCS11PINMethod) then
    begin
      FPKCS11PINMethod := LImportedPKCS11PINMethod;
      LHasImportedPKCS11PINMethod := True;
    end
    else if LPKCS11PINMethodVal.IsStr and
            TryParsePKCS11PINMethodValue(LPKCS11PINMethodVal.AsStr.ToString, LImportedPKCS11PINMethod) then
    begin
      FPKCS11PINMethod := LImportedPKCS11PINMethod;
      LHasImportedPKCS11PINMethod := True;
    end;
  end;
  if LRoot.ObjectHas('pkcs11_pin') then
  begin
    FPKCS11PIN := LRoot.ObjectGet('pkcs11_pin').AsStr.ToString;
    if not LHasImportedPKCS11PINMethod then
      FPKCS11PINMethod := pmValue;
  end;
  if LRoot.ObjectHas('ca_file') then
    FCAFile := LRoot.ObjectGet('ca_file').AsStr.ToString;
  if LRoot.ObjectHas('ca_path') then
    FCAPath := LRoot.ObjectGet('ca_path').AsStr.ToString;
  if LRoot.ObjectHas('use_system_roots') then
    FUseSystemRoots := LRoot.ObjectGet('use_system_roots').AsBool;

  // Cipher configuration
  if LRoot.ObjectHas('cipher_list') then
    FCipherList := LRoot.ObjectGet('cipher_list').AsStr.ToString;
  if LRoot.ObjectHas('tls13_ciphersuites') then
    FTLS13Ciphersuites := LRoot.ObjectGet('tls13_ciphersuites').AsStr.ToString;

  // Advanced options
  if LRoot.ObjectHas('server_name') then
    FServerName := LRoot.ObjectGet('server_name').AsStr.ToString;
  if LRoot.ObjectHas('server_name_mode') then
  begin
    // Compatibility metadata only; keep accepting it without changing runtime state.
  end;
  if LRoot.ObjectHas('alpn_protocols') then
    FALPNProtocols := LRoot.ObjectGet('alpn_protocols').AsStr.ToString;
  if LRoot.ObjectHas('session_cache_enabled') then
    FSessionCacheEnabled := LRoot.ObjectGet('session_cache_enabled').AsBool;
  if LRoot.ObjectHas('session_timeout') then
    FSessionTimeout := LRoot.ObjectGet('session_timeout').AsInt;
  if LRoot.ObjectHas('client_early_data_enabled') then
    FClientEarlyDataEnabled := LRoot.ObjectGet('client_early_data_enabled').AsBool;
  if LRoot.ObjectHas('server_early_data_policy') then
    if IsValidEarlyDataPolicyOrdinal(LRoot.ObjectGet('server_early_data_policy').AsInt) then
      FServerEarlyDataPolicy := TSSLEarlyDataServerPolicy(LRoot.ObjectGet('server_early_data_policy').AsInt);
  if LRoot.ObjectHas('server_max_early_data_size') then
    FServerMaxEarlyDataSize := Cardinal(LRoot.ObjectGet('server_max_early_data_size').AsInt);
  if LRoot.ObjectHas('server_early_data_replay_store_file') then
    FServerEarlyDataReplayStoreFile := LRoot.ObjectGet('server_early_data_replay_store_file').AsStr.ToString;
  if LRoot.ObjectHas('server_early_data_replay_store_directory') then
    FServerEarlyDataReplayStoreDirectory := LRoot.ObjectGet('server_early_data_replay_store_directory').AsStr.ToString;
  if LRoot.ObjectHas('explicit_backend') then
  begin
    if IsValidLibraryTypeOrdinal(LRoot.ObjectGet('explicit_backend').AsInt) then
    begin
      LImportedExplicitBackend := TSSLLibraryType(LRoot.ObjectGet('explicit_backend').AsInt);
      LHasExplicitBackend := True;
    end;
  end;
  if LRoot.ObjectHas('auto_select_backend') then
  begin
    LHasAutoSelectBackend := True;
    LAutoSelectBackend := LRoot.ObjectGet('auto_select_backend').AsBool;
    if LAutoSelectBackend then
    begin
      LBackendReq := LRoot.ObjectGet('backend_requirements');
      if LBackendReq.IsValid and LBackendReq.IsObject then
        JSONObjectToRequirements(LBackendReq, LImportedRequirements);
    end;
  end;

  // Options
  if LRoot.ObjectHas('options') then
  begin
    LOptionsArr := LRoot.ObjectGet('options');
    FOptions := [];
    for I := 0 to LOptionsArr.ArrayLen - 1 do
      if IsValidOptionOrdinal(LOptionsArr.ArrayGet(I).AsInt) then
        Include(FOptions, TSSLOption(LOptionsArr.ArrayGet(I).AsInt));
  end;

  // OCSP Stapling
  if LRoot.ObjectHas('ocsp_stapling_enabled') then
    FOCSPStaplingEnabled := LRoot.ObjectGet('ocsp_stapling_enabled').AsBool;
  if LRoot.ObjectHas('ocsp_stapling_required') then
    FOCSPStaplingRequired := LRoot.ObjectGet('ocsp_stapling_required').AsBool;
  if LRoot.ObjectHas('server_ocsp_stapled_response_file') then
    FServerOCSPStapledResponseFile := LRoot.ObjectGet('server_ocsp_stapled_response_file').AsStr.ToString;
  if LRoot.ObjectHas('certificate_transparency_required') then
    FCertificateTransparencyRequired := LRoot.ObjectGet('certificate_transparency_required').AsBool;

  if LHasAutoSelectBackend and LAutoSelectBackend then
  begin
    FAutoSelectBackend := True;
    FBackendRequirements := LImportedRequirements;
    FExplicitBackend := sslOpenSSL;
    FExplicitBackendSet := False;
  end
  else if LHasExplicitBackend then
  begin
    FExplicitBackend := LImportedExplicitBackend;
    FExplicitBackendSet := True;
    FAutoSelectBackend := False;
  end;

  SyncOCSPStaplingOptions;
  SyncCertificateTransparencyOptions;

  if LRoot.ObjectHas('verify_modes') then
  begin
    if LHasImportedVerifyModeExplicit then
      FVerifyModeExplicit := LImportedVerifyModeExplicit
    else
      FVerifyModeExplicit := ImportedVerifyModeIsExplicit(
        FVerifyMode,
        FCAFile,
        FCAPath,
        FUseSystemRoots
      );
  end;
end;

function TSSLContextBuilderImpl.ExportToINI: string;
var
  LLines: TStringArray;
  LBackendRequirementsStr: string;
  LProto: TSSLProtocolVersion;
  LVerifyMode: TSSLVerifyMode;
  LOption: TSSLOption;
  LProtocolStr, LVerifyStr, LOptionsStr: string;
  LDecodedBytes: TBytes;
begin
  try
    LLines.Add('[SSL Context Configuration]');
    LLines.Add('');

    // Protocol versions
    LProtocolStr := '';
    for LProto := Low(TSSLProtocolVersion) to High(TSSLProtocolVersion) do
      if LProto in FProtocolVersions then
      begin
        if LProtocolStr <> '' then
          LProtocolStr := LProtocolStr + ',';
        LProtocolStr := LProtocolStr + nextpas.core.text.conv.IntToStr(Ord(LProto));
      end;
    LLines.Add('protocols=' + LProtocolStr);

    // Verification
    LVerifyStr := '';
    for LVerifyMode := Low(TSSLVerifyMode) to High(TSSLVerifyMode) do
      if LVerifyMode in FVerifyMode then
      begin
        if LVerifyStr <> '' then
          LVerifyStr := LVerifyStr + ',';
        LVerifyStr := LVerifyStr + nextpas.core.text.conv.IntToStr(Ord(LVerifyMode));
      end;
    LLines.Add('verify_modes=' + LVerifyStr);
    if FVerifyModeExplicit then
      LLines.Add('verify_mode_explicit=true')
    else
      LLines.Add('verify_mode_explicit=false');
    LLines.Add('verify_depth=' + nextpas.core.text.conv.IntToStr(FVerifyDepth));
    LLines.Add('');

    // Certificate configuration
    LLines.Add('[Certificates]');
    LLines.Add('certificate_file=' + FCertificateFile);
    if FCertificatePEM <> '' then
    begin
      SetLength(LDecodedBytes, Length(FCertificatePEM));
      Move(FCertificatePEM[1], LDecodedBytes[0], Length(FCertificatePEM));
      LLines.Add('certificate_pem_b64=' + TBase64Utils.Encode(LDecodedBytes));
    end;
    LLines.Add('private_key_file=' + FPrivateKeyFile);
    if FPrivateKeyPEM <> '' then
    begin
      SetLength(LDecodedBytes, Length(FPrivateKeyPEM));
      Move(FPrivateKeyPEM[1], LDecodedBytes[0], Length(FPrivateKeyPEM));
      LLines.Add('private_key_pem_b64=' + TBase64Utils.Encode(LDecodedBytes));
    end;
    LLines.Add('pkcs11_uri=' + FPKCS11URI);
    if IsSerializablePKCS11PINSourceMethod(FPKCS11PINMethod) then
    begin
      LLines.Add('pkcs11_pin=' + FPKCS11PIN);
      LLines.Add('pkcs11_pin_method=' + nextpas.core.text.conv.IntToStr(Ord(FPKCS11PINMethod)));
    end;
    LLines.Add('ca_file=' + FCAFile);
    LLines.Add('ca_path=' + FCAPath);
    if FUseSystemRoots then
      LLines.Add('use_system_roots=true')
    else
      LLines.Add('use_system_roots=false');
    LLines.Add('');

    // Cipher configuration
    LLines.Add('[Ciphers]');
    LLines.Add('cipher_list=' + FCipherList);
    LLines.Add('tls13_ciphersuites=' + FTLS13Ciphersuites);
    LLines.Add('');

    // Advanced options
    LLines.Add('[Advanced]');
    LLines.Add('server_name=' + FServerName);
    if FServerName <> '' then
      LLines.Add('server_name_mode=' + CONTEXT_SERVER_NAME_COMPAT_MODE);
    LLines.Add('alpn_protocols=' + FALPNProtocols);
    if FSessionCacheEnabled then
      LLines.Add('session_cache_enabled=true')
    else
      LLines.Add('session_cache_enabled=false');
    LLines.Add('session_timeout=' + nextpas.core.text.conv.IntToStr(FSessionTimeout));
    if FClientEarlyDataEnabled then
      LLines.Add('client_early_data_enabled=true')
    else
      LLines.Add('client_early_data_enabled=false');
    LLines.Add('server_early_data_policy=' + nextpas.core.text.conv.IntToStr(Ord(FServerEarlyDataPolicy)));
    LLines.Add('server_max_early_data_size=' + nextpas.core.text.conv.IntToStr(FServerMaxEarlyDataSize));
    LLines.Add('server_early_data_replay_store_file=' + FServerEarlyDataReplayStoreFile);
    LLines.Add('server_early_data_replay_store_directory=' + FServerEarlyDataReplayStoreDirectory);
    if FExplicitBackendSet and (not FAutoSelectBackend) then
      LLines.Add('explicit_backend=' + nextpas.core.text.conv.IntToStr(Ord(FExplicitBackend)));
    LLines.Add('');

    if FAutoSelectBackend then
    begin
      LBackendRequirementsStr := RequirementsToJSON(FBackendRequirements);
      LLines.Add('[Backend Selection]');
      LLines.Add('auto_select_backend=true');
      LLines.Add('backend_requirements=' + LBackendRequirementsStr);
      LLines.Add('');
    end;

    // Options
    LOptionsStr := '';
    for LOption := Low(TSSLOption) to High(TSSLOption) do
      if LOption in FOptions then
      begin
        if LOptionsStr <> '' then
          LOptionsStr := LOptionsStr + ',';
        LOptionsStr := LOptionsStr + nextpas.core.text.conv.IntToStr(Ord(LOption));
      end;
    LLines.Add('[Options]');
    LLines.Add('options=' + LOptionsStr);
    LLines.Add('');

    // OCSP Stapling
    LLines.Add('[OCSP Stapling]');
    if FOCSPStaplingEnabled then
      LLines.Add('ocsp_stapling_enabled=true')
    else
      LLines.Add('ocsp_stapling_enabled=false');
    if FOCSPStaplingRequired then
      LLines.Add('ocsp_stapling_required=true')
    else
      LLines.Add('ocsp_stapling_required=false');
    LLines.Add('server_ocsp_stapled_response_file=' + FServerOCSPStapledResponseFile);
    LLines.Add('');

    // Certificate Transparency
    LLines.Add('[Certificate Transparency]');
    if FCertificateTransparencyRequired then
      LLines.Add('certificate_transparency_required=true')
    else
      LLines.Add('certificate_transparency_required=false');

    Result := LLines.Join(#10);
  finally
  end;
end;

function TSSLContextBuilderImpl.ImportFromINI(const AINI: string): ISSLContextBuilder;
var
  LLines: TStringArray;
  LBackendRequirementsDoc: IJsonDocument;
  I: Integer;
  LLine, LKey, LValue: string;
  LPos: Integer;
  LParts: TStringArray;
  LImportedRequirements: TSSLRequirements;
  LImportedExplicitBackend: TSSLLibraryType;
  LImportedPKCS11PINMethod: TPKCS11PINMethod;
  LImportedVerifyModeExplicit: Boolean;
  LHasImportedPKCS11PINMethod: Boolean;
  LHasImportedVerifyModeExplicit: Boolean;
  LHasExplicitBackend: Boolean;
  LHasAutoSelectBackend: Boolean;
  LHasVerifyModes: Boolean;
  LAutoSelectBackend: Boolean;
  LDecodedBytes: TBytes;
  J: Integer;
begin
  Result := Self;

  if AINI = '' then
    Exit;

  FillChar(LImportedRequirements, SizeOf(LImportedRequirements), 0);
  LHasImportedPKCS11PINMethod := False;
  LHasImportedVerifyModeExplicit := False;
  LHasExplicitBackend := False;
  LHasAutoSelectBackend := False;
  LHasVerifyModes := False;
  LAutoSelectBackend := False;
  try
    LLines := nextpas.core.text.strings.StringsParseLines(AINI);

    for I := 0 to Length(LLines) - 1 do
    begin
      LLine := nextpas.core.text.conv.Trim(LLines[I]);

      // Skip empty lines and section headers
      if (LLine = '') or (LLine[1] = '[') then
        Continue;

      // Parse key=value
      LPos := Pos('=', LLine);
      if LPos > 0 then
      begin
        LKey := nextpas.core.text.conv.Trim(Copy(LLine, 1, LPos - 1));
        LValue := nextpas.core.text.conv.Trim(Copy(LLine, LPos + 1, Length(LLine)));

        // Parse based on key
        if LKey = 'protocols' then
        begin
          LParts := nextpas.core.text.strings.StringsSplit(LValue, ',');
          FProtocolVersions := [];
          for J := 0 to Length(LParts) - 1 do
            if IsValidProtocolVersionOrdinal(StrToIntDef(LParts[J], -1)) then
              Include(FProtocolVersions, TSSLProtocolVersion(StrToIntDef(LParts[J], 0)));
        end
        else if LKey = 'verify_modes' then
        begin
          LParts := nextpas.core.text.strings.StringsSplit(LValue, ',');
          FVerifyMode := [];
          for J := 0 to Length(LParts) - 1 do
            if IsValidVerifyModeOrdinal(StrToIntDef(LParts[J], -1)) then
              Include(FVerifyMode, TSSLVerifyMode(StrToIntDef(LParts[J], 0)));
          LHasVerifyModes := True;
        end
        else if LKey = 'verify_mode_explicit' then
        begin
          LImportedVerifyModeExplicit := LowerCase(LValue) = 'true';
          LHasImportedVerifyModeExplicit := True;
        end
        else if LKey = 'verify_depth' then
          FVerifyDepth := StrToIntDef(LValue, SSL_DEFAULT_VERIFY_DEPTH)
        else if LKey = 'certificate_file' then
        begin
          FCertificateFile := LValue;
          FCertificatePEM := '';
        end
        else if LKey = 'certificate_pem_b64' then
        begin
          if TBase64Utils.TryDecode(LValue, LDecodedBytes) then
          begin
            SetLength(FCertificatePEM, Length(LDecodedBytes));
            if Length(LDecodedBytes) > 0 then
              Move(LDecodedBytes[0], FCertificatePEM[1], Length(LDecodedBytes));
            FCertificateFile := '';
          end;
        end
        else if LKey = 'private_key_file' then
        begin
          FPrivateKeyFile := LValue;
          FPrivateKeyPEM := '';
        end
        else if LKey = 'private_key_pem_b64' then
        begin
          if TBase64Utils.TryDecode(LValue, LDecodedBytes) then
          begin
            SetLength(FPrivateKeyPEM, Length(LDecodedBytes));
            if Length(LDecodedBytes) > 0 then
              Move(LDecodedBytes[0], FPrivateKeyPEM[1], Length(LDecodedBytes));
            FPrivateKeyFile := '';
          end;
        end
        else if LKey = 'pkcs11_uri' then
          FPKCS11URI := LValue
        else if LKey = 'pkcs11_pin' then
        begin
          FPKCS11PIN := LValue;
          if not LHasImportedPKCS11PINMethod then
            FPKCS11PINMethod := pmValue;
        end
        else if LKey = 'pkcs11_pin_method' then
        begin
          if TryParsePKCS11PINMethodValue(LValue, LImportedPKCS11PINMethod) then
          begin
            FPKCS11PINMethod := LImportedPKCS11PINMethod;
            LHasImportedPKCS11PINMethod := True;
          end;
        end
        else if LKey = 'ca_file' then
          FCAFile := LValue
        else if LKey = 'ca_path' then
          FCAPath := LValue
        else if LKey = 'use_system_roots' then
          FUseSystemRoots := (LowerCase(LValue) = 'true')
        else if LKey = 'cipher_list' then
          FCipherList := LValue
        else if LKey = 'tls13_ciphersuites' then
          FTLS13Ciphersuites := LValue
        else if LKey = 'server_name' then
          FServerName := LValue
        else if LKey = 'server_name_mode' then
        begin
          // Compatibility metadata only; keep accepting it without changing runtime state.
        end
        else if LKey = 'alpn_protocols' then
          FALPNProtocols := LValue
        else if LKey = 'session_cache_enabled' then
          FSessionCacheEnabled := (LowerCase(LValue) = 'true')
        else if LKey = 'session_timeout' then
          FSessionTimeout := StrToIntDef(LValue, SSL_DEFAULT_SESSION_TIMEOUT)
        else if LKey = 'client_early_data_enabled' then
          FClientEarlyDataEnabled := (LowerCase(LValue) = 'true')
        else if LKey = 'server_early_data_policy' then
        begin
          if IsValidEarlyDataPolicyOrdinal(StrToIntDef(LValue, -1)) then
            FServerEarlyDataPolicy := TSSLEarlyDataServerPolicy(StrToIntDef(LValue, Ord(sslEarlyDataServerReject)));
        end
        else if LKey = 'server_max_early_data_size' then
          FServerMaxEarlyDataSize := Cardinal(StrToIntDef(LValue, Integer(FServerMaxEarlyDataSize)))
        else if LKey = 'server_early_data_replay_store_file' then
          FServerEarlyDataReplayStoreFile := LValue
        else if LKey = 'server_early_data_replay_store_directory' then
          FServerEarlyDataReplayStoreDirectory := LValue
        else if LKey = 'explicit_backend' then
        begin
          if IsValidLibraryTypeOrdinal(StrToIntDef(LValue, -1)) then
          begin
            LImportedExplicitBackend := TSSLLibraryType(StrToIntDef(LValue, Ord(sslOpenSSL)));
            LHasExplicitBackend := True;
          end;
        end
        else if LKey = 'auto_select_backend' then
        begin
          LHasAutoSelectBackend := True;
          LAutoSelectBackend := (LowerCase(LValue) = 'true');
        end
        else if LKey = 'backend_requirements' then
        begin
          if LValue <> '' then
          begin
            try
              LBackendRequirementsDoc := JsonParse(LValue);
              if (not LBackendRequirementsDoc.HasError) and
                 LBackendRequirementsDoc.Root.IsObject then
                JSONObjectToRequirements(LBackendRequirementsDoc.Root, LImportedRequirements);
            except
              // Ignore malformed serialized requirement payloads.
            end;
          end;
        end
        else if LKey = 'options' then
        begin
          LParts := nextpas.core.text.strings.StringsSplit(LValue, ',');
          FOptions := [];
          for J := 0 to Length(LParts) - 1 do
            if IsValidOptionOrdinal(StrToIntDef(LParts[J], -1)) then
              Include(FOptions, TSSLOption(StrToIntDef(LParts[J], 0)));
        end
        else if LKey = 'ocsp_stapling_enabled' then
          FOCSPStaplingEnabled := (LowerCase(LValue) = 'true')
        else if LKey = 'ocsp_stapling_required' then
          FOCSPStaplingRequired := (LowerCase(LValue) = 'true')
        else if LKey = 'server_ocsp_stapled_response_file' then
          FServerOCSPStapledResponseFile := LValue
        else if LKey = 'certificate_transparency_required' then
          FCertificateTransparencyRequired := (LowerCase(LValue) = 'true');
      end;
    end;

    if LHasAutoSelectBackend and LAutoSelectBackend then
    begin
      FAutoSelectBackend := True;
      FBackendRequirements := LImportedRequirements;
      FExplicitBackend := sslOpenSSL;
      FExplicitBackendSet := False;
    end
    else if LHasExplicitBackend then
    begin
      FExplicitBackend := LImportedExplicitBackend;
      FExplicitBackendSet := True;
      FAutoSelectBackend := False;
    end;

    SyncOCSPStaplingOptions;
    SyncCertificateTransparencyOptions;

    if LHasVerifyModes then
    begin
      if LHasImportedVerifyModeExplicit then
        FVerifyModeExplicit := LImportedVerifyModeExplicit
      else
        FVerifyModeExplicit := ImportedVerifyModeIsExplicit(
          FVerifyMode,
          FCAFile,
          FCAPath,
          FUseSystemRoots
        );
    end;
  finally
  end;
end;

{ Configuration Snapshot and Clone - Phase 2.1.4 }

function TSSLContextBuilderImpl.Clone: ISSLContextBuilder;
var
  LClone: TSSLContextBuilderImpl;
begin
  // Create new instance and copy all fields
  LClone := TSSLContextBuilderImpl.Create;

  // Copy all configuration fields
  LClone.FProtocolVersions := FProtocolVersions;
  LClone.FVerifyMode := FVerifyMode;
  LClone.FVerifyModeExplicit := FVerifyModeExplicit;
  LClone.FVerifyDepth := FVerifyDepth;
  LClone.FCertificateFile := FCertificateFile;
  LClone.FCertificatePEM := FCertificatePEM;
  LClone.FPrivateKeyFile := FPrivateKeyFile;
  LClone.FPrivateKeyPassword := FPrivateKeyPassword;
  LClone.FPrivateKeyPEM := FPrivateKeyPEM;
  LClone.FCAFile := FCAFile;
  LClone.FCAPath := FCAPath;
  LClone.FUseSystemRoots := FUseSystemRoots;
  LClone.FCipherList := FCipherList;
  LClone.FTLS13Ciphersuites := FTLS13Ciphersuites;
  LClone.FServerName := FServerName;
  LClone.FALPNProtocols := FALPNProtocols;
  LClone.FSessionCacheEnabled := FSessionCacheEnabled;
  LClone.FSessionTimeout := FSessionTimeout;
  LClone.FClientEarlyDataEnabled := FClientEarlyDataEnabled;
  LClone.FServerEarlyDataPolicy := FServerEarlyDataPolicy;
  LClone.FServerMaxEarlyDataSize := FServerMaxEarlyDataSize;
  LClone.FServerEarlyDataReplayStoreFile := FServerEarlyDataReplayStoreFile;
  LClone.FServerEarlyDataReplayStoreDirectory := FServerEarlyDataReplayStoreDirectory;
  LClone.FOptions := FOptions;

  LClone.FHTTPGetCallback := FHTTPGetCallback;
  LClone.FHTTPPostCallback := FHTTPPostCallback;

  // Copy PKCS#11 fields
  LClone.FPKCS11URI := FPKCS11URI;
  LClone.FPKCS11PIN := FPKCS11PIN;
  LClone.FPKCS11PINMethod := FPKCS11PINMethod;

  // Copy OCSP Stapling fields
  LClone.FOCSPStaplingEnabled := FOCSPStaplingEnabled;
  LClone.FOCSPStaplingRequired := FOCSPStaplingRequired;
  LClone.FServerOCSPStapledResponseFile := FServerOCSPStapledResponseFile;
  LClone.FCertificateTransparencyRequired := FCertificateTransparencyRequired;
  LClone.SyncOCSPStaplingOptions;
  LClone.SyncCertificateTransparencyOptions;

  // Copy backend-selection state so cloned builders preserve runtime selection semantics.
  LClone.FAutoSelectBackend := FAutoSelectBackend;
  LClone.FBackendRequirements := FBackendRequirements;
  LClone.FExplicitBackend := FExplicitBackend;
  LClone.FExplicitBackendSet := FExplicitBackendSet;

  Result := LClone;
end;

function TSSLContextBuilderImpl.Reset: ISSLContextBuilder;
begin
  // Reset all fields to default values (same as constructor)
  FProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  FVerifyMode := [sslVerifyPeer];
  FVerifyModeExplicit := False;
  FVerifyDepth := SSL_DEFAULT_VERIFY_DEPTH;
  FCertificateFile := '';
  FCertificatePEM := '';
  FPrivateKeyFile := '';
  FPrivateKeyPassword := '';
  FPrivateKeyPEM := '';
  FCAFile := '';
  FCAPath := '';
  FUseSystemRoots := False;
  FCipherList := '';
  FTLS13Ciphersuites := '';
  FServerName := '';
  FALPNProtocols := '';
  FSessionCacheEnabled := True;
  FSessionTimeout := SSL_DEFAULT_SESSION_TIMEOUT;
  FClientEarlyDataEnabled := False;
  FServerEarlyDataPolicy := sslEarlyDataServerReject;
  FServerMaxEarlyDataSize := 0;
  FServerEarlyDataReplayStoreFile := '';
  FServerEarlyDataReplayStoreDirectory := '';
  FOptions := [ssoEnableSNI, ssoDisableCompression, ssoDisableRenegotiation];

  FHTTPGetCallback := nil;
  FHTTPPostCallback := nil;

  // Reset PKCS#11 fields
  FPKCS11URI := '';
  FPKCS11PIN := '';
  FPKCS11PINMethod := pmNone;

  // Reset OCSP Stapling fields
  FOCSPStaplingEnabled := False;
  FOCSPStaplingRequired := False;
  FServerOCSPStapledResponseFile := '';
  FCertificateTransparencyRequired := False;
  SyncOCSPStaplingOptions;
  SyncCertificateTransparencyOptions;

  // Reset backend-selection state to the same defaults as a fresh builder.
  FAutoSelectBackend := False;
  FillChar(FBackendRequirements, SizeOf(FBackendRequirements), 0);
  FExplicitBackend := sslOpenSSL;
  FExplicitBackendSet := False;

  Result := Self;
end;

function TSSLContextBuilderImpl.ResetToDefaults: ISSLContextBuilder;
begin
  // Alias for Reset
  Result := Reset;
end;

function TSSLContextBuilderImpl.Merge(ASource: ISSLContextBuilder): ISSLContextBuilder;
var
  LSourceJSON: string;
  LDoc: IJsonDocument;
  LObj, LBackendReq, LProtocolsArr, LVerifyArr, LOptionsArr: TJsonValue;
  LImportedRequirements: TSSLRequirements;
  LImportedExplicitBackend: TSSLLibraryType;
  LImportedPKCS11PINMethod: TPKCS11PINMethod;
  LImportedVerifyModeExplicit: Boolean;
  LHasImportedVerifyModeExplicit: Boolean;
  LHasExplicitBackend: Boolean;
  LHasAutoSelectBackend: Boolean;
  LHasVerifyModes: Boolean;
  LAutoSelectBackend: Boolean;
  I: UInt32;
  LStrValue: string;
begin
  Result := Self;

  if ASource = nil then
    Exit;

  // Export source to JSON and merge non-empty fields
  LSourceJSON := ASource.ExportToJSON;
  if LSourceJSON = '' then
    Exit;

  FillChar(LImportedRequirements, SizeOf(LImportedRequirements), 0);
  LHasImportedVerifyModeExplicit := False;
  LHasExplicitBackend := False;
  LHasAutoSelectBackend := False;
  LHasVerifyModes := False;
  LAutoSelectBackend := False;

  LDoc := JsonParse(LSourceJSON);
  if LDoc.HasError then
    Exit;

  LObj := LDoc.Root;
  if not LObj.IsObject then
    Exit;

  // Merge protocols if specified
  if LObj.ObjectHas('protocols') then
  begin
    LProtocolsArr := LObj.ObjectGet('protocols');
    if LProtocolsArr.ArrayLen > 0 then
    begin
      FProtocolVersions := [];
      for I := 0 to LProtocolsArr.ArrayLen - 1 do
        if IsValidProtocolVersionOrdinal(LProtocolsArr.ArrayGet(I).AsInt) then
          Include(FProtocolVersions, TSSLProtocolVersion(LProtocolsArr.ArrayGet(I).AsInt));
    end;
  end;

  // Merge verify modes if specified
  if LObj.ObjectHas('verify_modes') then
  begin
    LVerifyArr := LObj.ObjectGet('verify_modes');
    FVerifyMode := [];
    for I := 0 to LVerifyArr.ArrayLen - 1 do
      if IsValidVerifyModeOrdinal(LVerifyArr.ArrayGet(I).AsInt) then
        Include(FVerifyMode, TSSLVerifyMode(LVerifyArr.ArrayGet(I).AsInt));
    LHasVerifyModes := True;
  end;

  if LObj.ObjectHas('verify_mode_explicit') then
  begin
    LImportedVerifyModeExplicit := LObj.ObjectGet('verify_mode_explicit').AsBool;
    LHasImportedVerifyModeExplicit := True;
  end;

  // Merge other fields if non-empty
  if LObj.ObjectHas('verify_depth') then
    FVerifyDepth := LObj.ObjectGet('verify_depth').AsInt;

  if LObj.ObjectHas('certificate_file') then
  begin
    LStrValue := LObj.ObjectGet('certificate_file').AsStr.ToString;
    if LStrValue <> '' then
    begin
      FCertificateFile := LStrValue;
      FCertificatePEM := '';
    end;
  end;

  if LObj.ObjectHas('certificate_pem') then
  begin
    LStrValue := LObj.ObjectGet('certificate_pem').AsStr.ToString;
    if LStrValue <> '' then
    begin
      FCertificatePEM := LStrValue;
      FCertificateFile := '';
    end;
  end;

  if LObj.ObjectHas('private_key_file') then
  begin
    LStrValue := LObj.ObjectGet('private_key_file').AsStr.ToString;
    if LStrValue <> '' then
    begin
      FPrivateKeyFile := LStrValue;
      FPrivateKeyPEM := '';
    end;
  end;

  if LObj.ObjectHas('private_key_pem') then
  begin
    LStrValue := LObj.ObjectGet('private_key_pem').AsStr.ToString;
    if LStrValue <> '' then
    begin
      FPrivateKeyPEM := LStrValue;
      FPrivateKeyFile := '';
    end;
  end;

  if LObj.ObjectHas('pkcs11_uri') then
  begin
    LStrValue := LObj.ObjectGet('pkcs11_uri').AsStr.ToString;
    if LStrValue <> '' then
      FPKCS11URI := LStrValue;
  end;

  if LObj.ObjectHas('pkcs11_pin_method') then
  begin
    if TryParsePKCS11PINMethodOrdinal(LObj.ObjectGet('pkcs11_pin_method').AsInt, LImportedPKCS11PINMethod) then
      FPKCS11PINMethod := LImportedPKCS11PINMethod;
  end;

  if LObj.ObjectHas('pkcs11_pin') then
    FPKCS11PIN := LObj.ObjectGet('pkcs11_pin').AsStr.ToString;

  if LObj.ObjectHas('ca_file') then
  begin
    LStrValue := LObj.ObjectGet('ca_file').AsStr.ToString;
    if LStrValue <> '' then
      FCAFile := LStrValue;
  end;

  if LObj.ObjectHas('ca_path') then
  begin
    LStrValue := LObj.ObjectGet('ca_path').AsStr.ToString;
    if LStrValue <> '' then
      FCAPath := LStrValue;
  end;

  if LObj.ObjectHas('use_system_roots') then
    FUseSystemRoots := LObj.ObjectGet('use_system_roots').AsBool;

  if LObj.ObjectHas('cipher_list') then
  begin
    LStrValue := LObj.ObjectGet('cipher_list').AsStr.ToString;
    if LStrValue <> '' then
      FCipherList := LStrValue;
  end;

  if LObj.ObjectHas('tls13_ciphersuites') then
  begin
    LStrValue := LObj.ObjectGet('tls13_ciphersuites').AsStr.ToString;
    if LStrValue <> '' then
      FTLS13Ciphersuites := LStrValue;
  end;

  if LObj.ObjectHas('server_name') then
    FServerName := LObj.ObjectGet('server_name').AsStr.ToString;

  if LObj.ObjectHas('alpn_protocols') then
    FALPNProtocols := LObj.ObjectGet('alpn_protocols').AsStr.ToString;

  if LObj.ObjectHas('session_cache_enabled') then
    FSessionCacheEnabled := LObj.ObjectGet('session_cache_enabled').AsBool;

  if LObj.ObjectHas('session_timeout') then
    FSessionTimeout := LObj.ObjectGet('session_timeout').AsInt;

  if LObj.ObjectHas('client_early_data_enabled') then
    FClientEarlyDataEnabled := LObj.ObjectGet('client_early_data_enabled').AsBool;

  if LObj.ObjectHas('server_early_data_policy') then
    if IsValidEarlyDataPolicyOrdinal(LObj.ObjectGet('server_early_data_policy').AsInt) then
      FServerEarlyDataPolicy := TSSLEarlyDataServerPolicy(LObj.ObjectGet('server_early_data_policy').AsInt);

  if LObj.ObjectHas('server_max_early_data_size') then
    FServerMaxEarlyDataSize := Cardinal(LObj.ObjectGet('server_max_early_data_size').AsInt);

  if LObj.ObjectHas('server_early_data_replay_store_file') then
  begin
    LStrValue := LObj.ObjectGet('server_early_data_replay_store_file').AsStr.ToString;
    if LStrValue <> '' then
      FServerEarlyDataReplayStoreFile := LStrValue;
  end;

  if LObj.ObjectHas('server_early_data_replay_store_directory') then
  begin
    LStrValue := LObj.ObjectGet('server_early_data_replay_store_directory').AsStr.ToString;
    if LStrValue <> '' then
      FServerEarlyDataReplayStoreDirectory := LStrValue;
  end;

  if LObj.ObjectHas('ocsp_stapling_enabled') then
    FOCSPStaplingEnabled := LObj.ObjectGet('ocsp_stapling_enabled').AsBool;

  if LObj.ObjectHas('ocsp_stapling_required') then
    FOCSPStaplingRequired := LObj.ObjectGet('ocsp_stapling_required').AsBool;

  if LObj.ObjectHas('server_ocsp_stapled_response_file') then
  begin
    LStrValue := LObj.ObjectGet('server_ocsp_stapled_response_file').AsStr.ToString;
    if LStrValue <> '' then
      FServerOCSPStapledResponseFile := LStrValue;
  end;

  if LObj.ObjectHas('certificate_transparency_required') then
    FCertificateTransparencyRequired := LObj.ObjectGet('certificate_transparency_required').AsBool;

  if LObj.ObjectHas('explicit_backend') then
  begin
    if IsValidLibraryTypeOrdinal(LObj.ObjectGet('explicit_backend').AsInt) then
    begin
      LImportedExplicitBackend := TSSLLibraryType(LObj.ObjectGet('explicit_backend').AsInt);
      LHasExplicitBackend := True;
    end;
  end;

  if LObj.ObjectHas('auto_select_backend') then
  begin
    LHasAutoSelectBackend := True;
    LAutoSelectBackend := LObj.ObjectGet('auto_select_backend').AsBool;
    if LAutoSelectBackend then
    begin
      LBackendReq := LObj.ObjectGet('backend_requirements');
      if LBackendReq.IsValid and LBackendReq.IsObject then
        JSONObjectToRequirements(LBackendReq, LImportedRequirements);
    end;
  end;

  // Merge options
  if LObj.ObjectHas('options') then
  begin
    LOptionsArr := LObj.ObjectGet('options');
    FOptions := [];
    for I := 0 to LOptionsArr.ArrayLen - 1 do
      Include(FOptions, TSSLOption(LOptionsArr.ArrayGet(I).AsInt));
  end;

  if LHasAutoSelectBackend and LAutoSelectBackend then
  begin
    FAutoSelectBackend := True;
    FBackendRequirements := LImportedRequirements;
    FExplicitBackend := sslOpenSSL;
    FExplicitBackendSet := False;
  end
  else if LHasExplicitBackend then
  begin
    FExplicitBackend := LImportedExplicitBackend;
    FExplicitBackendSet := True;
    FAutoSelectBackend := False;
  end;

  SyncOCSPStaplingOptions;
  SyncCertificateTransparencyOptions;

  if LHasVerifyModes then
  begin
    if LHasImportedVerifyModeExplicit then
      FVerifyModeExplicit := LImportedVerifyModeExplicit
    else
      FVerifyModeExplicit := ImportedVerifyModeIsExplicit(
        FVerifyMode,
        FCAFile,
        FCAPath,
        FUseSystemRoots
      );
  end;
end;

{ Conditional Configuration - Phase 2.2.1 }

function TSSLContextBuilderImpl.When(ACondition: Boolean; AConfig: TBuilderConfigProc): ISSLContextBuilder;
begin
  Result := Self;

  if not ACondition then
    Exit;

  if Assigned(AConfig) then
    AConfig(Self);
end;

function TSSLContextBuilderImpl.Unless(ACondition: Boolean; AConfig: TBuilderConfigProc): ISSLContextBuilder;
begin
  Result := Self;

  if ACondition then
    Exit;

  if Assigned(AConfig) then
    AConfig(Self);
end;

function TSSLContextBuilderImpl.WhenDevelopment(AConfig: TBuilderConfigProc): ISSLContextBuilder;
begin
  {$IFDEF DEBUG}
  Result := When(True, AConfig);
  {$ELSE}
  Result := Self;
  {$ENDIF}
end;

function TSSLContextBuilderImpl.WhenProduction(AConfig: TBuilderConfigProc): ISSLContextBuilder;
begin
  {$IFNDEF DEBUG}
  Result := When(True, AConfig);
  {$ELSE}
  Result := Self;
  {$ENDIF}
end;

{ Batch Configuration - Phase 2.2.2 }

function TSSLContextBuilderImpl.Apply(AConfig: TBuilderConfigProc): ISSLContextBuilder;
begin
  Result := Self;

  if Assigned(AConfig) then
    AConfig(Self);
end;

function TSSLContextBuilderImpl.ApplyPreset(APreset: ISSLContextBuilder): ISSLContextBuilder;
begin
  Result := Self;

  if APreset = nil then
    Exit;

  // Merge the preset configuration into current builder
  Merge(APreset);
end;

function TSSLContextBuilderImpl.Pipe(ATransform: TBuilderConfigProc): ISSLContextBuilder;
begin
  // Pipe is an alias for Apply - functional programming style
  Result := Apply(ATransform);
end;

{ Convenience Methods - Phase 2.2.3 }

function TSSLContextBuilderImpl.WithCertificateChain(const ACerts: array of string): ISSLContextBuilder;
var
  I: Integer;
begin
  Result := Self;

  // Load all certificates in the chain
  // The first certificate is typically the end-entity certificate
  // Followed by intermediate certificates up to the root
  for I := Low(ACerts) to High(ACerts) do
  begin
    if I = Low(ACerts) then
      // First cert is the primary certificate
      FCertificatePEM := ACerts[I]
    else
      // Additional certs are part of the chain
      // Note: Current implementation only stores one cert
      // In a full implementation, we'd store the chain separately
      FCertificatePEM := FCertificatePEM + #10 + ACerts[I];
  end;
end;

function TSSLContextBuilderImpl.WithMutualTLS(const ACAFile: string; ARequired: Boolean): ISSLContextBuilder;
begin
  Result := Self;

  // Enable client certificate verification
  FVerifyMode := [sslVerifyPeer];
  FVerifyModeExplicit := True;

  if ARequired then
    // Fail if client doesn't provide certificate
    Include(FVerifyMode, sslVerifyFailIfNoPeerCert);

  // Set CA file for verifying client certificates
  FCAFile := ACAFile;
end;

function TSSLContextBuilderImpl.WithHTTP2: ISSLContextBuilder;
begin
  Result := Self;

  // Configure ALPN for HTTP/2
  // Include both h2 and http/1.1 for compatibility
  FALPNProtocols := 'h2,http/1.1';
  Include(FOptions, ssoEnableALPN);
end;

function TSSLContextBuilderImpl.WithModernDefaults: ISSLContextBuilder;
begin
  // Modern defaults focus on security and performance
  Result := Self;

  // Only modern TLS versions
  FProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];

  // Strong cipher suites
  FCipherList := 'ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM';
  FTLS13Ciphersuites := 'TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256';

  // Modern security options
  FOptions := [
    ssoEnableSNI,                // SNI support
    ssoDisableCompression,       // Prevent CRIME attack
    ssoDisableRenegotiation,     // Prevent renegotiation attacks
    ssoCipherServerPreference,   // Server chooses cipher
    ssoNoSSLv2,                  // Disable all old protocols
    ssoNoSSLv3,
    ssoNoTLSv1,
    ssoNoTLSv1_1,
    ssoEnableSessionTickets,     // Session resumption
    ssoEnableALPN                // ALPN support
  ];

  // Reasonable session settings
  FSessionCacheEnabled := True;
  FSessionTimeout := 7200;  // 2 hours

  // Strict verification by default
  FVerifyMode := [sslVerifyPeer];
  FVerifyModeExplicit := True;
  FVerifyDepth := 10;
end;

{ Configuration Transformation - Phase 2.2.4 }

function TSSLContextBuilderImpl.Transform(ATransform: TBuilderTransformFunc): ISSLContextBuilder;
begin
  Result := Self;

  if not Assigned(ATransform) then
    Exit;

  // Apply transformation and return the result
  Result := ATransform(Self);
end;

function TSSLContextBuilderImpl.Extend(const AOptions: array of TSSLOption): ISSLContextBuilder;
var
  I: Integer;
begin
  Result := Self;

  // Add all options to the current option set
  for I := Low(AOptions) to High(AOptions) do
    Include(FOptions, AOptions[I]);

  SyncOCSPStaplingOptions;
  SyncCertificateTransparencyOptions;
end;

function TSSLContextBuilderImpl.Override(const AField, AValue: string): ISSLContextBuilder;
var
  LFieldLower: string;
  LPKCS11PINMethod: TPKCS11PINMethod;
  LExplicitBackend: TSSLLibraryType;
begin
  Result := Self;

  LFieldLower := LowerCase(AField);

  // Override specific configuration fields based on field name
  if LFieldLower = 'cipher_list' then
    FCipherList := AValue
  else if LFieldLower = 'tls13_ciphersuites' then
    FTLS13Ciphersuites := AValue
  else if LFieldLower = 'server_name' then
    FServerName := AValue
  else if LFieldLower = 'alpn_protocols' then
    FALPNProtocols := AValue
  else if LFieldLower = 'client_early_data_enabled' then
    FClientEarlyDataEnabled := (LowerCase(AValue) = 'true')
  else if LFieldLower = 'server_early_data_policy' then
  begin
    if IsValidEarlyDataPolicyOrdinal(StrToIntDef(AValue, -1)) then
      FServerEarlyDataPolicy := TSSLEarlyDataServerPolicy(
        StrToIntDef(AValue, Ord(FServerEarlyDataPolicy))
      );
  end
  else if LFieldLower = 'server_max_early_data_size' then
    FServerMaxEarlyDataSize := Cardinal(StrToIntDef(AValue, Integer(FServerMaxEarlyDataSize)))
  else if LFieldLower = 'server_early_data_replay_store_file' then
    Result := WithServerEarlyDataReplayStoreFile(AValue)
  else if LFieldLower = 'server_early_data_replay_store_directory' then
    Result := WithServerEarlyDataReplayStoreDirectory(AValue)
  else if LFieldLower = 'ca_file' then
    FCAFile := AValue
  else if LFieldLower = 'ca_path' then
    FCAPath := AValue
  else if LFieldLower = 'use_system_roots' then
    FUseSystemRoots := (LowerCase(AValue) = 'true')
  else if LFieldLower = 'certificate_file' then
  begin
    FCertificateFile := AValue;
    FCertificatePEM := '';
  end
  else if LFieldLower = 'certificate_pem' then
  begin
    FCertificatePEM := AValue;
    FCertificateFile := '';
  end
  else if LFieldLower = 'private_key_file' then
  begin
    FPrivateKeyFile := AValue;
    FPrivateKeyPEM := '';
  end
  else if LFieldLower = 'private_key_pem' then
  begin
    FPrivateKeyPEM := AValue;
    FPrivateKeyFile := '';
  end
  else if LFieldLower = 'pkcs11_uri' then
    FPKCS11URI := AValue
  else if LFieldLower = 'pkcs11_pin' then
  begin
    FPKCS11PIN := AValue;
    if not HasExplicitNonValuePKCS11PINMethod(FPKCS11PINMethod) then
      FPKCS11PINMethod := pmValue;
  end
  else if LFieldLower = 'pkcs11_pin_method' then
  begin
    if TryParsePKCS11PINMethodValue(AValue, LPKCS11PINMethod) then
      FPKCS11PINMethod := LPKCS11PINMethod;
  end
  else if LFieldLower = 'explicit_backend' then
  begin
    if TryParseLibraryTypeValue(AValue, LExplicitBackend) then
    begin
      FExplicitBackend := LExplicitBackend;
      FExplicitBackendSet := True;
      FAutoSelectBackend := False;
    end;
  end
  else if LFieldLower = 'ocsp_stapling_enabled' then
    Result := WithOCSPStapling(LowerCase(AValue) = 'true')
  else if LFieldLower = 'ocsp_stapling_required' then
    Result := WithOCSPStaplingRequired(LowerCase(AValue) = 'true')
  else if LFieldLower = 'server_ocsp_stapled_response_file' then
    Result := WithServerOCSPStapledResponseFile(AValue)
  else if LFieldLower = 'certificate_transparency_required' then
    Result := WithCertificateTransparencyRequired(LowerCase(AValue) = 'true')
  else if LFieldLower = 'session_timeout' then
    FSessionTimeout := StrToIntDef(AValue, FSessionTimeout)
  else if LFieldLower = 'verify_depth' then
    FVerifyDepth := StrToIntDef(AValue, FVerifyDepth)
  else if LFieldLower = 'session_cache_enabled' then
    FSessionCacheEnabled := (LowerCase(AValue) = 'true')
  else
    raise ESSLConfigurationException.CreateFmt(
      'Unknown builder override field: "%s"', [AField]);
end;

{ v1.3.0: Automatic backend selection methods }

function TSSLContextBuilderImpl.WithAutoBackendSelection(
  const ARequirements: TSSLRequirements): ISSLContextBuilder;
begin
  Result := Self;
  FAutoSelectBackend := True;
  FBackendRequirements := ARequirements;
end;

function TSSLContextBuilderImpl.WithSecurityFirst: ISSLContextBuilder;
begin
  Result := WithAutoBackendSelection(CreateSecurityFirstRequirements);
end;

function TSSLContextBuilderImpl.WithPerformanceFirst: ISSLContextBuilder;
begin
  Result := WithAutoBackendSelection(CreatePerformanceFirstRequirements);
end;

function TSSLContextBuilderImpl.WithCompatibilityFirst: ISSLContextBuilder;
begin
  Result := WithAutoBackendSelection(CreateCompatibilityFirstRequirements);
end;

function TSSLContextBuilderImpl.WithBackend(ABackendType: TSSLLibraryType): ISSLContextBuilder;
begin
  Result := Self;
  FExplicitBackend := ABackendType;
  FExplicitBackendSet := True;
  FAutoSelectBackend := False;  // 显式指定后端时禁用自动选择
end;

function TSSLContextBuilderImpl.RequireTLS13: ISSLContextBuilder;
begin
  Result := Self;
  if not FAutoSelectBackend then
  begin
    // 如果还没有启用自动选择，则创建默认需求
    FBackendRequirements := CreateDefaultRequirements;
    FAutoSelectBackend := True;
  end;
  // 添加 TLS 1.3 要求
  FBackendRequirements.RequiredProtocols := [sslProtocolTLS13];
end;

function TSSLContextBuilderImpl.RequireCipher(ACipher: TSSLCipher): ISSLContextBuilder;
begin
  Result := Self;
  if not FAutoSelectBackend then
  begin
    FBackendRequirements := CreateDefaultRequirements;
    FAutoSelectBackend := True;
  end;
  // 添加密码算法要求
  Include(FBackendRequirements.RequiredCiphers, ACipher);
end;

function TSSLContextBuilderImpl.RequirePKCS11Support: ISSLContextBuilder;
begin
  Result := Self;
  if not FAutoSelectBackend then
  begin
    FBackendRequirements := CreateDefaultRequirements;
    FAutoSelectBackend := True;
  end;
  // 要求 PKCS#11 支持
  FBackendRequirements.PlatformPreferences.RequirePKCS11 := True;
end;

function TSSLContextBuilderImpl.PreferOSNative: ISSLContextBuilder;
begin
  Result := Self;
  if not FAutoSelectBackend then
  begin
    FBackendRequirements := CreateDefaultRequirements;
    FAutoSelectBackend := True;
  end;
  // 优先 OS 原生实现
  FBackendRequirements.PlatformPreferences.PreferOSNative := True;
end;

end.
