program test_capability_matrix_v12;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory;

var
  GBackendsExecuted: Integer = 0;
  GBackendsSkipped: Integer = 0;
  GBackendsErrors: Integer = 0;
  GSkipBackendUnavailable: Integer = 0;
  GContractChecks: Integer = 0;
  GContractFailures: Integer = 0;

function FeatureLevelPresent(ALevel: TSSLFeatureSupportLevel): Boolean;
begin
  Result := ALevel <> sslSupportNone;
end;

function IsBackendUnavailableError(const AMessage: string): Boolean;
var
  LMsg: string;
begin
  LMsg := LowerCase(AMessage);
  Result := (Pos('not registered', LMsg) > 0) or
            (Pos('not enabled', LMsg) > 0) or
            (Pos('backend not available', LMsg) > 0) or
            (Pos('failed to load', LMsg) > 0);
end;

procedure RecordContract(const AName: string; ACondition: Boolean; const AFailureDetail: string = '');
begin
  Inc(GContractChecks);
  if ACondition then
    WriteLn('  [PASS] ', AName)
  else
  begin
    Inc(GContractFailures);
    if AFailureDetail <> '' then
      WriteLn('  [FAIL] ', AName, ' - ', AFailureDetail)
    else
      WriteLn('  [FAIL] ', AName);
  end;
end;

procedure RecordProjectionContracts(const ABackendName: string;
  const ACaps: TSSLBackendCapabilities; AExpectedBackend: TSSLLibraryType);
begin
  RecordContract(ABackendName + ' BackendType matches requested backend',
    ACaps.BackendType = AExpectedBackend,
    Format('Expected=%d Actual=%d',
      [Ord(AExpectedBackend), Ord(ACaps.BackendType)]));

  RecordContract(ABackendName + ' SupportsSNI matches SNISupport',
    ACaps.SupportsSNI = FeatureLevelPresent(ACaps.SNISupport),
    Format('SupportsSNI=%s SNISupport=%d',
      [BoolToStr(ACaps.SupportsSNI, True), Ord(ACaps.SNISupport)]));

  RecordContract(ABackendName + ' SupportsALPN matches ALPNSupport',
    ACaps.SupportsALPN = FeatureLevelPresent(ACaps.ALPNSupport),
    Format('SupportsALPN=%s ALPNSupport=%d',
      [BoolToStr(ACaps.SupportsALPN, True), Ord(ACaps.ALPNSupport)]));

  RecordContract(ABackendName + ' SupportsOCSPStapling matches OCSPStaplingSupport',
    ACaps.SupportsOCSPStapling = FeatureLevelPresent(ACaps.OCSPStaplingSupport),
    Format('SupportsOCSPStapling=%s OCSPStaplingSupport=%d',
      [BoolToStr(ACaps.SupportsOCSPStapling, True), Ord(ACaps.OCSPStaplingSupport)]));

  RecordContract(ABackendName + ' SupportsCertificateTransparency matches CertTransparencySupport',
    ACaps.SupportsCertificateTransparency = FeatureLevelPresent(ACaps.CertTransparencySupport),
    Format('SupportsCertificateTransparency=%s CertTransparencySupport=%d',
      [BoolToStr(ACaps.SupportsCertificateTransparency, True), Ord(ACaps.CertTransparencySupport)]));

  RecordContract(ABackendName + ' SupportsSessionTickets matches SessionTicketsSupport',
    ACaps.SupportsSessionTickets = FeatureLevelPresent(ACaps.SessionTicketsSupport),
    Format('SupportsSessionTickets=%s SessionTicketsSupport=%d',
      [BoolToStr(ACaps.SupportsSessionTickets, True), Ord(ACaps.SessionTicketsSupport)]));
end;

procedure RecordFeatureParityContracts(const ABackendName: string;
  ALib: ISSLLibrary; const ACaps: TSSLBackendCapabilities);
var
  LSessionCacheSupported: Boolean;
  LSessionTicketsSupported: Boolean;
begin
  LSessionCacheSupported := ALib.IsFeatureSupported(sslFeatSessionCache);
  RecordContract(ABackendName + ' session-cache feature matches SessionCacheSupport',
    LSessionCacheSupported = FeatureLevelPresent(ACaps.SessionCacheSupport),
    Format('IsFeatureSupported(SessionCache)=%s SessionCacheSupport=%d',
      [BoolToStr(LSessionCacheSupported, True), Ord(ACaps.SessionCacheSupport)]));

  LSessionTicketsSupported := ALib.IsFeatureSupported(sslFeatSessionTickets);
  RecordContract(ABackendName + ' session-tickets feature matches SessionTicketsSupport',
    LSessionTicketsSupported = FeatureLevelPresent(ACaps.SessionTicketsSupport),
    Format('IsFeatureSupported(SessionTickets)=%s SessionTicketsSupport=%d',
      [BoolToStr(LSessionTicketsSupported, True), Ord(ACaps.SessionTicketsSupport)]));
end;

procedure RecordBackendSpecificContracts(ABackend: TSSLLibraryType;
  const ACaps: TSSLBackendCapabilities);
begin
  case ABackend of
    sslOpenSSL:
      begin
        RecordContract('OpenSSL backend impl is C library',
          ACaps.BackendImplType = sslImplCLibrary,
          Format('BackendImplType=%d', [Ord(ACaps.BackendImplType)]));
        RecordContract('OpenSSL requires external library',
          ACaps.RequiresExternalLibrary,
          Format('RequiresExternalLibrary=%s',
            [BoolToStr(ACaps.RequiresExternalLibrary, True)]));
        RecordContract('OpenSSL publishes TLS 1.3',
          ACaps.SupportsTLS13,
          'SupportsTLS13=False');
        RecordContract('OpenSSL SNI support is stable',
          ACaps.SNISupport = sslSupportStable,
          Format('SNISupport=%d', [Ord(ACaps.SNISupport)]));
        RecordContract('OpenSSL ALPN support is stable',
          ACaps.ALPNSupport = sslSupportStable,
          Format('ALPNSupport=%d', [Ord(ACaps.ALPNSupport)]));
        RecordContract('OpenSSL OCSP stapling support is stable',
          ACaps.OCSPStaplingSupport = sslSupportStable,
          Format('OCSPStaplingSupport=%d', [Ord(ACaps.OCSPStaplingSupport)]));
        RecordContract('OpenSSL CT support is unpublished',
          ACaps.CertTransparencySupport = sslSupportNone,
          Format('CertTransparencySupport=%d',
            [Ord(ACaps.CertTransparencySupport)]));
        RecordContract('OpenSSL session tickets support is stable',
          ACaps.SessionTicketsSupport = sslSupportStable,
          Format('SessionTicketsSupport=%d',
            [Ord(ACaps.SessionTicketsSupport)]));
        RecordContract('OpenSSL PKCS12 support is published',
          ACaps.SupportsPKCS12,
          Format('SupportsPKCS12=%s', [BoolToStr(ACaps.SupportsPKCS12, True)]));
        RecordContract('OpenSSL custom cipher suites are published',
          ACaps.SupportsCustomCipherSuites,
          Format('SupportsCustomCipherSuites=%s',
            [BoolToStr(ACaps.SupportsCustomCipherSuites, True)]));
        RecordContract('OpenSSL callbacks are published',
          ACaps.SupportsCallbacks,
          Format('SupportsCallbacks=%s',
            [BoolToStr(ACaps.SupportsCallbacks, True)]));
      end;

    sslFreePascal:
      begin
        RecordContract('FreePascal backend impl is native',
          ACaps.BackendImplType = sslImplNative,
          Format('BackendImplType=%d', [Ord(ACaps.BackendImplType)]));
        RecordContract('FreePascal does not require external library',
          not ACaps.RequiresExternalLibrary,
          Format('RequiresExternalLibrary=%s',
            [BoolToStr(ACaps.RequiresExternalLibrary, True)]));
        RecordContract('FreePascal publishes TLS 1.3',
          ACaps.SupportsTLS13,
          'SupportsTLS13=False');
        RecordContract('FreePascal SNI support is experimental',
          ACaps.SNISupport = sslSupportExperimental,
          Format('SNISupport=%d', [Ord(ACaps.SNISupport)]));
        RecordContract('FreePascal ALPN support is experimental',
          ACaps.ALPNSupport = sslSupportExperimental,
          Format('ALPNSupport=%d', [Ord(ACaps.ALPNSupport)]));
        RecordContract('FreePascal OCSP stapling support is experimental',
          ACaps.OCSPStaplingSupport = sslSupportExperimental,
          Format('OCSPStaplingSupport=%d', [Ord(ACaps.OCSPStaplingSupport)]));
        RecordContract('FreePascal CT support is experimental',
          ACaps.CertTransparencySupport = sslSupportExperimental,
          Format('CertTransparencySupport=%d',
            [Ord(ACaps.CertTransparencySupport)]));
        RecordContract('FreePascal session tickets support is experimental',
          ACaps.SessionTicketsSupport = sslSupportExperimental,
          Format('SessionTicketsSupport=%d',
            [Ord(ACaps.SessionTicketsSupport)]));
        RecordContract('FreePascal session cache support is experimental',
          ACaps.SessionCacheSupport = sslSupportExperimental,
          Format('SessionCacheSupport=%d',
            [Ord(ACaps.SessionCacheSupport)]));
        RecordContract('FreePascal 0-RTT support is experimental',
          ACaps.ZeroRTTSupport = sslSupportExperimental,
          Format('ZeroRTTSupport=%d', [Ord(ACaps.ZeroRTTSupport)]));
        RecordContract('FreePascal early-data support is experimental',
          ACaps.EarlyDataSupport = sslSupportExperimental,
          Format('EarlyDataSupport=%d', [Ord(ACaps.EarlyDataSupport)]));
        RecordContract('FreePascal PKCS12 support is unpublished',
          not ACaps.SupportsPKCS12,
          Format('SupportsPKCS12=%s', [BoolToStr(ACaps.SupportsPKCS12, True)]));
        RecordContract('FreePascal password-protected keys are unpublished',
          not ACaps.SupportsPasswordProtectedKeys,
          Format('SupportsPasswordProtectedKeys=%s',
            [BoolToStr(ACaps.SupportsPasswordProtectedKeys, True)]));
        RecordContract('FreePascal custom cipher suites are published',
          ACaps.SupportsCustomCipherSuites,
          Format('SupportsCustomCipherSuites=%s',
            [BoolToStr(ACaps.SupportsCustomCipherSuites, True)]));
        RecordContract('FreePascal verify callback is published',
          ACaps.SupportsCallbacks,
          Format('SupportsCallbacks=%s',
            [BoolToStr(ACaps.SupportsCallbacks, True)]));
      end;
  else
    ;
  end;
end;

procedure TestBackendCapabilities(const ABackendName: string; AType: TSSLLibraryType);
var
  Lib: ISSLLibrary;
  Caps: TSSLBackendCapabilities;
  Desc: string;
  LKnownGood: Boolean;
  LKnownBad: Boolean;
  LEmptyName: Boolean;
begin
  WriteLn('========================================');
  WriteLn('Testing: ', ABackendName);
  WriteLn('========================================');

  try
    Lib := TSSLFactory.GetLibrary(AType);
    if not Assigned(Lib) then
    begin
      Inc(GBackendsSkipped);
      Inc(GSkipBackendUnavailable);
      WriteLn('  [SKIP] [backend-not-available] ', ABackendName, ' backend not available');
      WriteLn;
      Exit;
    end;

    if not Lib.Initialize then
    begin
      Inc(GBackendsSkipped);
      Inc(GSkipBackendUnavailable);
      WriteLn('  [SKIP] [backend-not-available] ', ABackendName,
        ' initialize failed: ', Lib.GetLastErrorString);
      WriteLn;
      Exit;
    end;

    Inc(GBackendsExecuted);

    Caps := Lib.GetCapabilities;

    WriteLn('[v1.1.0 Fields - Backward Compatibility]');
    WriteLn('  SupportsTLS13: ', Caps.SupportsTLS13);
    WriteLn('  SupportsALPN: ', Caps.SupportsALPN);
    WriteLn('  SupportsSNI: ', Caps.SupportsSNI);
    WriteLn('  SupportsOCSPStapling: ', Caps.SupportsOCSPStapling);
    WriteLn('  SupportsECDHE: ', Caps.SupportsECDHE);
    WriteLn('  MinTLSVersion: ', Ord(Caps.MinTLSVersion));
    WriteLn('  MaxTLSVersion: ', Ord(Caps.MaxTLSVersion));
    WriteLn;

    WriteLn('[v1.2.0 New Fields]');
    WriteLn('  BackendType: ', Ord(Caps.BackendType));
    WriteLn('  BackendImplType: ', Ord(Caps.BackendImplType));
    WriteLn('  BackendVersion: ', Caps.BackendVersion);
    WriteLn('  SupportsDTLS: ', Caps.SupportsDTLS);
    WriteLn;

    WriteLn('[Feature Support Levels]');
    WriteLn('  SNISupport: ', Ord(Caps.SNISupport));
    WriteLn('  ALPNSupport: ', Ord(Caps.ALPNSupport));
    WriteLn('  OCSPStaplingSupport: ', Ord(Caps.OCSPStaplingSupport));
    WriteLn('  CertTransparencySupport: ', Ord(Caps.CertTransparencySupport));
    WriteLn('  SessionTicketsSupport: ', Ord(Caps.SessionTicketsSupport));
    WriteLn('  SessionCacheSupport: ', Ord(Caps.SessionCacheSupport));
    WriteLn('  ZeroRTTSupport: ', Ord(Caps.ZeroRTTSupport));
    WriteLn('  EarlyDataSupport: ', Ord(Caps.EarlyDataSupport));
    WriteLn;

    WriteLn('[Capability Truth Contracts]');
    RecordProjectionContracts(ABackendName, Caps, AType);
    RecordFeatureParityContracts(ABackendName, Lib, Caps);
    RecordBackendSpecificContracts(AType, Caps);
    WriteLn;

    WriteLn('[Algorithm Support]');
    WriteLn('  Ciphers: ', IsCipherSupported(Caps, sslCipherAES256), ' (AES256), ',
            IsCipherSupported(Caps, sslCipherCHACHA20_POLY1305), ' (ChaCha20)');
    WriteLn('  Hashes: ', IsHashSupported(Caps, sslHashSHA256), ' (SHA256), ',
            IsHashSupported(Caps, sslHashSHA512), ' (SHA512)');
    WriteLn('  KeyExchange: ', IsKeyExchangeSupported(Caps, sslKexECDHE_RSA), ' (ECDHE-RSA)');
    WriteLn;

    WriteLn('[Cipher API Contract]');
    LKnownGood := Lib.IsCipherSupported('TLS_AES_128_GCM_SHA256');
    LKnownBad := Lib.IsCipherSupported('TLS_FAKE_AES_128_GCM_SHA256');
    LEmptyName := Lib.IsCipherSupported('');
    WriteLn('  KnownGood(TLS_AES_128_GCM_SHA256): ', LKnownGood);
    WriteLn('  FakeCipher(TLS_FAKE_AES_128_GCM_SHA256): ', LKnownBad);
    WriteLn('  EmptyName(""): ', LEmptyName);

    RecordContract(ABackendName + ' known-good cipher accepted', LKnownGood,
      'Known TLS1.3 cipher should be accepted');
    RecordContract(ABackendName + ' fake cipher rejected', not LKnownBad,
      'Unknown fake cipher should be rejected');
    RecordContract(ABackendName + ' empty name rejected', not LEmptyName,
      'Empty cipher name should be rejected');
    WriteLn;

    WriteLn('[Performance & Security Features]');
    WriteLn('  HasHardwareAcceleration: ', Caps.HasHardwareAcceleration);
    WriteLn('  HasSIMDOptimization: ', Caps.HasSIMDOptimization);
    WriteLn('  HasConstantTimeOperations: ', Caps.HasConstantTimeOperations);
    WriteLn('  SupportsFIPSMode: ', Caps.SupportsFIPSMode);
    WriteLn;

    WriteLn('[Platform Features]');
    WriteLn('  RequiresExternalLibrary: ', Caps.RequiresExternalLibrary);
    WriteLn('  SupportsSystemCertStore: ', Caps.SupportsSystemCertStore);
    WriteLn('  SupportsPKCS11: ', Caps.SupportsPKCS11);
    WriteLn('  SupportsTPM: ', Caps.SupportsTPM);
    WriteLn;

    WriteLn('[Helper Function Tests]');
    WriteLn('  IsNativeBackend: ', IsNativeBackend(Caps));
    WriteLn('  IsCLibraryBackend: ', IsCLibraryBackend(Caps));
    WriteLn('  RequiresExternalDependencies: ', RequiresExternalDependencies(Caps));
    WriteLn('  SecurityScore: ', GetSecurityScore(Caps), '/100');
    WriteLn('  PerformanceScore: ', GetPerformanceScore(Caps), '/100');
    WriteLn;

    WriteLn('[Capabilities Description]');
    Desc := GetCapabilitiesDescription(Caps);
    WriteLn(Desc);
    WriteLn;

    Lib.Finalize;
  except
    on E: Exception do
    begin
      if IsBackendUnavailableError(E.Message) then
      begin
        Inc(GBackendsSkipped);
        Inc(GSkipBackendUnavailable);
        WriteLn('  [SKIP] [backend-not-available] ', ABackendName, ' backend unavailable: ', E.Message);
      end
      else
      begin
        Inc(GBackendsErrors);
        WriteLn('  [ERROR] ', E.ClassName, ': ', E.Message);
      end;
      WriteLn;
    end;
  end;
end;

begin
  WriteLn('fafafa.ssl - Capability Matrix v1.2.0 Test');
  WriteLn('==========================================');
  WriteLn;

  TestBackendCapabilities('OpenSSL', sslOpenSSL);
  TestBackendCapabilities('FreePascal', sslFreePascal);
  TestBackendCapabilities('WolfSSL', sslWolfSSL);
  TestBackendCapabilities('MbedTLS', sslMbedTLS);
  TestBackendCapabilities('WinSSL', sslWinSSL);

  WriteLn('========================================');
  WriteLn('Backends executed: ', GBackendsExecuted);
  WriteLn('Backends skipped:  ', GBackendsSkipped,
    ' (backend-not-available=', GSkipBackendUnavailable, ')');
  WriteLn('Backends errors:   ', GBackendsErrors);
  WriteLn('Contract checks:   ', GContractChecks);
  WriteLn('Contract failures: ', GContractFailures);

  if (GBackendsErrors = 0) and (GContractFailures = 0) then
    WriteLn('✅ Capability matrix contract checks passed')
  else
    WriteLn('❌ Capability matrix contract checks failed');

  WriteLn('========================================');

  if (GBackendsErrors > 0) or (GContractFailures > 0) then
    Halt(1);
end.
