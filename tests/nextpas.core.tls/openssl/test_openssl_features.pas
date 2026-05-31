program test_openssl_features;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DynLibs,
  nextpas.core.tls.factory,
  nextpas.core.tls.base,
  fafafa.ssl,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.ec,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.provider,
  nextpas.core.tls.openssl.api.store,
  nextpas.core.tls.openssl.api.engine,
  nextpas.core.tls.openssl.api.pkcs12,
  nextpas.core.tls.openssl.api.pkcs,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.pkcs11.backend;

procedure Require(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function StubSetMinProtoPolicy(ctx: PSSL_CTX; version: Integer): Integer; cdecl;
begin
  if (version = TLS1_VERSION) or (version = TLS1_1_VERSION) then
    Result := 0
  else
    Result := 1;
end;

function StubSetMaxProtoPolicy(ctx: PSSL_CTX; version: Integer): Integer; cdecl;
begin
  if (version = TLS1_VERSION) or (version = TLS1_1_VERSION) then
    Result := 0
  else
    Result := 1;
end;

function StubRejectTLS13SetMinProtoPolicy(ctx: PSSL_CTX; version: Integer): Integer; cdecl;
begin
  if version = TLS1_3_VERSION then
    Result := 0
  else
    Result := 1;
end;

function StubRejectTLS13SetMaxProtoPolicy(ctx: PSSL_CTX; version: Integer): Integer; cdecl;
begin
  if version = TLS1_3_VERSION then
    Result := 0
  else
    Result := 1;
end;

function StubRejectDTLSSetMinProtoPolicy(ctx: PSSL_CTX; version: Integer): Integer; cdecl;
begin
  if (version = DTLS1_VERSION) or (version = DTLS1_2_VERSION) then
    Result := 0
  else
    Result := 1;
end;

function StubRejectDTLSSetMaxProtoPolicy(ctx: PSSL_CTX; version: Integer): Integer; cdecl;
begin
  if (version = DTLS1_VERSION) or (version = DTLS1_2_VERSION) then
    Result := 0
  else
    Result := 1;
end;

function ExpectedOpenSSLPrivateKeyFileSurfaceReady: Boolean;
begin
  Result := Assigned(SSL_CTX_use_PrivateKey_file);
end;

function ExpectedOpenSSLPrivateKeyReadSurfaceReady: Boolean;
begin
  if (not Assigned(PEM_read_bio_PrivateKey)) and
     (not TOpenSSLLoader.IsModuleLoaded(osmPEM)) then
    LoadOpenSSLPEM(GetCryptoLibHandle);

  Result := Assigned(PEM_read_bio_PrivateKey) and
    Assigned(BIO_free) and
    (Assigned(BIO_new_file) or Assigned(BIO_new_mem_buf));
end;

function ExpectedOpenSSLPEMOrPKCS8Ready: Boolean;
begin
  Result := ExpectedOpenSSLPrivateKeyFileSurfaceReady or
    ExpectedOpenSSLPrivateKeyReadSurfaceReady;
end;

function RawOpenSSLFunctionExported(const AName: string): Boolean;
var
  LLibHandle: TLibHandle;
begin
  LLibHandle := GetCryptoLibHandle;
  Result := (LLibHandle <> NilHandle) and
    Assigned(GetProcedureAddress(LLibHandle, PChar(AName)));
end;

procedure PrepareOpenSSLDERPrivateKeyRuntimeSurfaces;
begin
  LoadOpenSSLPKCS(GetCryptoLibHandle);
  LoadPKCS12Module(GetCryptoLibHandle);
  LoadOpenSSLRSA;
  LoadECFunctions(GetCryptoLibHandle);
  if Assigned(PKCS8_decrypt) or Assigned(PKCS8_encrypt) then
    TOpenSSLLoader.SetModuleLoaded(osmPKCS12, True);
end;

function ExpectedOpenSSLDERPKCS8PrivateKeyReady: Boolean;
begin
  Result := Assigned(nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO) and
    Assigned(nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY);
end;

function ExpectedOpenSSLEncryptedDERPKCS8PrivateKeyReady: Boolean;
begin
  Result := Assigned(nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG) and
    Assigned(nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt) and
    Assigned(nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY);
end;

function ExpectedOpenSSLDERPKCS1PrivateKeyReady: Boolean;
begin
  Result := Assigned(d2i_RSAPrivateKey) and
    Assigned(EVP_PKEY_new) and
    Assigned(EVP_PKEY_set1_RSA);
end;

function ExpectedOpenSSLDERSEC1ECPrivateKeyReady: Boolean;
begin
  Result := Assigned(EC_KEY_free) and
    Assigned(EVP_PKEY_new) and
    RawOpenSSLFunctionExported('d2i_ECPrivateKey') and
    RawOpenSSLFunctionExported('EVP_PKEY_set1_EC_KEY');
end;

function ExpectedOpenSSLDERPrivateKeyReady: Boolean;
begin
  Result := ExpectedOpenSSLDERPKCS8PrivateKeyReady or
    ExpectedOpenSSLEncryptedDERPKCS8PrivateKeyReady or
    ExpectedOpenSSLDERPKCS1PrivateKeyReady or
    ExpectedOpenSSLDERSEC1ECPrivateKeyReady;
end;

function ExpectedOpenSSLPKCS8PrivateKeyReady: Boolean;
begin
  Result := ExpectedOpenSSLPEMOrPKCS8Ready or
    ExpectedOpenSSLDERPKCS8PrivateKeyReady or
    ExpectedOpenSSLEncryptedDERPKCS8PrivateKeyReady;
end;

function ExpectedOpenSSLPasswordProtectedKeyReady: Boolean;
begin
  Result := ExpectedOpenSSLPrivateKeyReadSurfaceReady or
    ExpectedOpenSSLEncryptedDERPKCS8PrivateKeyReady;
end;

procedure TestCertificateStore;
var
  SSLLib: ISSLLibrary;
  Store: ISSLCertificateStore;
  Count: Integer;
  LoadedSystem: Boolean;
begin
  WriteLn;
  WriteLn('Testing Certificate Store');
  WriteLn('==========================');

  SSLLib := TSSLFactory.GetLibrary(sslOpenSSL);
  Require(SSLLib <> nil, 'OpenSSL library instance is nil');

  if not SSLLib.Initialize then
  begin
    WriteLn('Failed to initialize OpenSSL');
    Exit;
  end;

  Store := SSLLib.CreateCertificateStore;
  Require(Store <> nil, 'CreateCertificateStore returned nil');
  WriteLn('Store created: TRUE');

  LoadedSystem := Store.LoadSystemStore;
  WriteLn('System store loaded: ', BoolToStr(LoadedSystem, True));

  Count := Store.GetCount;
  Require(Count >= 0, 'Certificate count must be >= 0');
  WriteLn('Certificate count: ', Count);

  Require(not Store.VerifyCertificate(nil),
    'VerifyCertificate(nil) should return False');
  WriteLn('VerifyCertificate(nil): FALSE (contract verified)');

  WriteLn('✅ Certificate Store test completed');
end;

procedure TestSession;
var
  SSLLib: ISSLLibrary;
  Ctx: ISSLContext;
begin
  WriteLn;
  WriteLn('Testing Session Serialization');
  WriteLn('==============================');

  SSLLib := TSSLFactory.GetLibrary(sslOpenSSL);
  Require(SSLLib <> nil, 'OpenSSL library instance is nil');

  if not SSLLib.Initialize then
  begin
    WriteLn('Failed to initialize OpenSSL');
    Exit;
  end;

  Ctx := SSLLib.CreateContext(sslCtxClient);
  Require(Ctx <> nil, 'CreateContext returned nil');
  WriteLn('Context created: TRUE');

  Ctx.SetSessionCacheMode(True);
  Require(Ctx.GetSessionCacheMode,
    'Session cache should be enabled after SetSessionCacheMode(True)');

  Ctx.SetSessionTimeout(1800);
  Require(Ctx.GetSessionTimeout = 1800,
    'Session timeout should persist after SetSessionTimeout');

  Ctx.SetSessionCacheSize(256);
  Require(Ctx.GetSessionCacheSize = 256,
    'Session cache size should persist after SetSessionCacheSize');

  WriteLn('[SKIP] Session object retrieval requires a completed TLS handshake');
  WriteLn('✅ Session test completed (context session contracts verified)');
end;

procedure TestCertificateVerify;
var
  SSLLib: ISSLLibrary;
  Store: ISSLCertificateStore;
  LoadedSystem: Boolean;
  Chain: TSSLCertificateArray;
begin
  WriteLn;
  WriteLn('Testing Certificate Verification');
  WriteLn('=================================');

  SSLLib := TSSLFactory.GetLibrary(sslOpenSSL);
  Require(SSLLib <> nil, 'OpenSSL library instance is nil');

  if not SSLLib.Initialize then
  begin
    WriteLn('Failed to initialize OpenSSL');
    Exit;
  end;

  Store := SSLLib.CreateCertificateStore;
  Require(Store <> nil, 'CreateCertificateStore returned nil');

  LoadedSystem := Store.LoadSystemStore;
  WriteLn('System store loaded for verification: ', BoolToStr(LoadedSystem, True));

  Require(Store.GetCount >= 0, 'Store.GetCount should be >= 0');

  Require(not Store.VerifyCertificate(nil),
    'VerifyCertificate(nil) should return False');

  Chain := Store.BuildCertificateChain(nil);
  Require(Length(Chain) = 0,
    'BuildCertificateChain(nil) should return empty chain');

  WriteLn('[SKIP] End-to-end certificate verification requires real certificate chain');
  WriteLn('✅ Verification test completed (store contracts verified)');
end;

procedure TestCipherSupportContract;
var
  SSLLib: ISSLLibrary;
  LKnownGood: Boolean;
  LKnownBad: Boolean;
begin
  WriteLn;
  WriteLn('Testing Cipher Support Contract');
  WriteLn('===============================');

  SSLLib := TSSLFactory.GetLibrary(sslOpenSSL);
  Require(SSLLib <> nil, 'OpenSSL library instance is nil');

  if not SSLLib.Initialize then
  begin
    WriteLn('Failed to initialize OpenSSL');
    Exit;
  end;

  LKnownGood := SSLLib.IsCipherSupported('TLS_AES_128_GCM_SHA256');
  Require(LKnownGood,
    'TLS_AES_128_GCM_SHA256 should be reported supported on initialized OpenSSL backend');

  LKnownBad := SSLLib.IsCipherSupported('TLS_FAKE_AES_128_GCM_SHA256');
  Require(not LKnownBad,
    'Unknown fake cipher must not be accepted only because name contains AES/GCM keywords');

  WriteLn('✅ Cipher support contract verified');
end;

procedure TestFeatureSupportRuntimeDriftContract;
var
  SSLLib: ISSLLibrary;
  LOrigSNI: TSSL_set_tlsext_host_name;
  LOrigALPN: TSSL_CTX_set_alpn_protos;
  LOrigReneg: TSSL_renegotiate;
begin
  WriteLn;
  WriteLn('Testing Feature Support Runtime Drift Contract');
  WriteLn('==============================================');

  SSLLib := TSSLFactory.GetLibrary(sslOpenSSL);
  Require(SSLLib <> nil, 'OpenSSL library instance is nil');

  if not SSLLib.Initialize then
  begin
    WriteLn('Failed to initialize OpenSSL');
    Exit;
  end;

  LOrigSNI := SSL_set_tlsext_host_name;
  if not Assigned(LOrigSNI) then
    WriteLn('[SKIP] SNI symbol unavailable in current build; skip pointer-drift check')
  else
  begin
    SSL_set_tlsext_host_name := nil;
    try
      Require(not SSLLib.IsFeatureSupported(sslFeatSNI),
        'SNI must be reported unsupported when SSL_set_tlsext_host_name is missing at runtime');
    finally
      SSL_set_tlsext_host_name := LOrigSNI;
    end;
  end;

  LOrigALPN := SSL_CTX_set_alpn_protos;
  if not Assigned(LOrigALPN) then
    WriteLn('[SKIP] ALPN symbol unavailable in current build; skip pointer-drift check')
  else
  begin
    SSL_CTX_set_alpn_protos := nil;
    try
      Require(not SSLLib.IsFeatureSupported(sslFeatALPN),
        'ALPN must be reported unsupported when SSL_CTX_set_alpn_protos is missing at runtime');
    finally
      SSL_CTX_set_alpn_protos := LOrigALPN;
    end;
  end;

  LOrigReneg := SSL_renegotiate;
  if not Assigned(LOrigReneg) then
    WriteLn('[SKIP] Renegotiation symbol unavailable in current build; skip pointer-drift check')
  else
  begin
    SSL_renegotiate := nil;
    try
      Require(not SSLLib.IsFeatureSupported(sslFeatRenegotiation),
        'Renegotiation must be reported unsupported when SSL_renegotiate is missing at runtime');
    finally
      SSL_renegotiate := LOrigReneg;
    end;
  end;

  WriteLn('✅ Feature runtime drift contract verified');
end;

procedure TestCapabilityMatrixRuntimeDriftContract;
var
  SSLLib: TOpenSSLLibrary;
  LHandle: TLibHandle;
  LOrigSetMaxEarly: TSSL_CTX_set_max_early_data;
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn;
  WriteLn('Testing Capability Matrix Runtime Drift Contract');
  WriteLn('================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
    if LHandle = NilHandle then
    begin
      WriteLn('[SKIP] libssl handle unavailable; skip capability-drift check');
      Exit;
    end;

    if not TOpenSSLLoader.IsFunctionAvailable(LHandle, 'SSL_CTX_set_max_early_data') then
    begin
      WriteLn('[SKIP] libssl does not export SSL_CTX_set_max_early_data; skip capability-drift check');
      Exit;
    end;

    LOrigSetMaxEarly := SSL_CTX_set_max_early_data;
    SSL_CTX_set_max_early_data := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(LCaps.ZeroRTTSupport <> sslSupportStable,
        '0-RTT support must stop claiming stable while SSL_CTX_set_max_early_data is not runtime-ready');
      Require(LCaps.EarlyDataSupport <> sslSupportStable,
        'Early-data support must stop claiming stable while SSL_CTX_set_max_early_data is not runtime-ready');
    finally
      SSL_CTX_set_max_early_data := LOrigSetMaxEarly;
    end;

    WriteLn('✅ Capability matrix runtime drift contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestSessionTicketCapabilityMatrixRuntimeDriftContract;
var
  SSLLib: TOpenSSLLibrary;
  LHandle: TLibHandle;
  LOrigSetTicketExtCb: TSSL_set_session_ticket_ext_cb;
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn;
  WriteLn('Testing Session Ticket Capability Matrix Runtime Drift Contract');
  WriteLn('==============================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
    if LHandle = NilHandle then
    begin
      WriteLn('[SKIP] libssl handle unavailable; skip session-ticket capability-drift check');
      Exit;
    end;

    if not TOpenSSLLoader.IsFunctionAvailable(LHandle, 'SSL_set_session_ticket_ext_cb') then
    begin
      WriteLn('[SKIP] libssl does not export SSL_set_session_ticket_ext_cb; skip session-ticket capability-drift check');
      Exit;
    end;

    LOrigSetTicketExtCb := SSL_set_session_ticket_ext_cb;
    SSL_set_session_ticket_ext_cb := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsSessionTickets,
        'Session-ticket support must stop claiming supported while SSL_set_session_ticket_ext_cb is not runtime-ready');
      Require(LCaps.SessionTicketsSupport <> sslSupportStable,
        'Session-ticket support level must stop claiming stable while SSL_set_session_ticket_ext_cb is not runtime-ready');
    finally
      SSL_set_session_ticket_ext_cb := LOrigSetTicketExtCb;
    end;

    WriteLn('✅ Session-ticket capability matrix runtime drift contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestPostHandshakeCapabilityMatrixRuntimeDriftContract;
var
  SSLLib: TOpenSSLLibrary;
  LHandle: TLibHandle;
  LOrigVerifyPostHandshake: TSSL_verify_client_post_handshake;
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn;
  WriteLn('Testing Post-Handshake Capability Matrix Runtime Drift Contract');
  WriteLn('================================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
    if LHandle = NilHandle then
    begin
      WriteLn('[SKIP] libssl handle unavailable; skip post-handshake capability-drift check');
      Exit;
    end;

    if not TOpenSSLLoader.IsFunctionAvailable(LHandle, 'SSL_verify_client_post_handshake') then
    begin
      WriteLn('[SKIP] libssl does not export SSL_verify_client_post_handshake; skip post-handshake capability-drift check');
      Exit;
    end;

    LOrigVerifyPostHandshake := SSL_verify_client_post_handshake;
    SSL_verify_client_post_handshake := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(LCaps.PostHandshakeAuthSupport <> sslSupportStable,
        'Post-handshake auth support must stop claiming stable while SSL_verify_client_post_handshake is not runtime-ready');
    finally
      SSL_verify_client_post_handshake := LOrigVerifyPostHandshake;
    end;

    WriteLn('✅ Post-handshake capability matrix runtime drift contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestSNICapabilityMatrixRuntimeDriftContract;
var
  SSLLib: TOpenSSLLibrary;
  LOrigSetHostName: TSSL_set_tlsext_host_name;
  LOrigServerNameCallback: TSSL_CTX_set_tlsext_servername_callback;
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn;
  WriteLn('Testing SNI Capability Matrix Runtime Drift Contract');
  WriteLn('====================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LOrigSetHostName := SSL_set_tlsext_host_name;
    LOrigServerNameCallback := SSL_CTX_set_tlsext_servername_callback;
    if (not Assigned(LOrigSetHostName)) and (not Assigned(LOrigServerNameCallback)) then
    begin
      WriteLn('[SKIP] SNI helper surface unavailable; skip capability-drift check');
      Exit;
    end;

    SSL_set_tlsext_host_name := nil;
    SSL_CTX_set_tlsext_servername_callback := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsSNI,
        'SNI capability must stop claiming supported when the SNI helper surface is not runtime-ready');
      Require(LCaps.SNISupport = sslSupportNone,
        'SNI support level must become none when the SNI helper surface is not runtime-ready');
    finally
      SSL_set_tlsext_host_name := LOrigSetHostName;
      SSL_CTX_set_tlsext_servername_callback := LOrigServerNameCallback;
    end;

    WriteLn('✅ SNI capability matrix runtime drift contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestALPNCapabilityMatrixRuntimeDriftContract;
var
  SSLLib: TOpenSSLLibrary;
  LOrigSetALPN: TSSL_CTX_set_alpn_protos;
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn;
  WriteLn('Testing ALPN Capability Matrix Runtime Drift Contract');
  WriteLn('=====================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LOrigSetALPN := SSL_CTX_set_alpn_protos;
    if not Assigned(LOrigSetALPN) then
    begin
      WriteLn('[SKIP] ALPN setter unavailable; skip capability-drift check');
      Exit;
    end;

    SSL_CTX_set_alpn_protos := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsALPN,
        'ALPN capability must stop claiming supported when SSL_CTX_set_alpn_protos is not runtime-ready');
      Require(LCaps.ALPNSupport = sslSupportNone,
        'ALPN support level must become none when SSL_CTX_set_alpn_protos is not runtime-ready');
    finally
      SSL_CTX_set_alpn_protos := LOrigSetALPN;
    end;

    WriteLn('✅ ALPN capability matrix runtime drift contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestOCSPStaplingCapabilityMatrixRuntimeDriftContract;
var
  SSLLib: TOpenSSLLibrary;
  LOrigStatusCallback: TSSL_CTX_set_tlsext_status_cb;
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn;
  WriteLn('Testing OCSP Stapling Capability Matrix Runtime Drift Contract');
  WriteLn('==============================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LOrigStatusCallback := SSL_CTX_set_tlsext_status_cb;
    if not Assigned(LOrigStatusCallback) then
    begin
      WriteLn('[SKIP] OCSP stapling callback unavailable; skip capability-drift check');
      Exit;
    end;

    SSL_CTX_set_tlsext_status_cb := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsOCSPStapling,
        'OCSP stapling capability must stop claiming supported when SSL_CTX_set_tlsext_status_cb is not runtime-ready');
      Require(LCaps.OCSPStaplingSupport = sslSupportNone,
        'OCSP stapling support level must become none when SSL_CTX_set_tlsext_status_cb is not runtime-ready');
    finally
      SSL_CTX_set_tlsext_status_cb := LOrigStatusCallback;
    end;

    WriteLn('✅ OCSP stapling capability matrix runtime drift contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestSessionCacheCapabilityMatrixRuntimeDriftContract;
var
  SSLLib: TOpenSSLLibrary;
  LOrigSetSessionCacheMode: TSSL_CTX_set_session_cache_mode;
  LOrigGetSessionCacheMode: TSSL_CTX_get_session_cache_mode;
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn;
  WriteLn('Testing Session Cache Capability Matrix Runtime Drift Contract');
  WriteLn('==============================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LOrigSetSessionCacheMode := SSL_CTX_set_session_cache_mode;
    LOrigGetSessionCacheMode := SSL_CTX_get_session_cache_mode;
    if (not Assigned(LOrigSetSessionCacheMode)) or
       (not Assigned(LOrigGetSessionCacheMode)) then
    begin
      LCaps := SSLLib.GetCapabilities;
      Require(LCaps.SessionCacheSupport = sslSupportNone,
        'Session-cache support level must be none when the session-cache helper surface is incomplete');
      WriteLn('✅ Session-cache capability matrix baseline contract verified');
      Exit;
    end;

    SSL_CTX_get_session_cache_mode := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(LCaps.SessionCacheSupport = sslSupportNone,
        'Session-cache support level must become none when SSL_CTX_get_session_cache_mode is not runtime-ready');
    finally
      SSL_CTX_get_session_cache_mode := LOrigGetSessionCacheMode;
    end;

    WriteLn('✅ Session-cache capability matrix runtime drift contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestRenegotiationCapabilityMatrixRuntimeDriftContract;
var
  SSLLib: TOpenSSLLibrary;
  LOrigRenegotiate: TSSL_renegotiate;
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn;
  WriteLn('Testing Renegotiation Capability Matrix Runtime Drift Contract');
  WriteLn('==============================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LOrigRenegotiate := SSL_renegotiate;
    if not Assigned(LOrigRenegotiate) then
    begin
      WriteLn('[SKIP] Renegotiation helper unavailable; skip capability-drift check');
      Exit;
    end;

    SSL_renegotiate := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(LCaps.RenegotiationSupport = sslSupportNone,
        'Renegotiation support level must become none when SSL_renegotiate is not runtime-ready');
    finally
      SSL_renegotiate := LOrigRenegotiate;
    end;

    WriteLn('✅ Renegotiation capability matrix runtime drift contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestCertificateTransparencyCapabilityMatrixRuntimeDriftContract;
var
  SSLLib: TOpenSSLLibrary;
  LOrigCTLoaded: Boolean;
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn;
  WriteLn('Testing Certificate Transparency Capability Matrix Runtime Drift Contract');
  WriteLn('==========================================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    if SSLLib.GetVersionNumber < $1010000F then
    begin
      WriteLn('[SKIP] OpenSSL version is below CT support floor; skip capability-drift check');
      Exit;
    end;

    LOrigCTLoaded := TOpenSSLLoader.IsModuleLoaded(osmCT);
    TOpenSSLLoader.SetModuleLoaded(osmCT, False);
    try
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsCertificateTransparency,
        'Certificate-transparency capability must stop claiming supported while osmCT is not runtime-ready');
      Require(LCaps.CertTransparencySupport = sslSupportNone,
        'Certificate-transparency support level must become none while osmCT is not runtime-ready');
    finally
      TOpenSSLLoader.SetModuleLoaded(osmCT, LOrigCTLoaded);
    end;

    WriteLn('✅ Certificate-transparency capability matrix runtime drift contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestCertificateTransparencyPublicSurfaceTruthContract;
var
  SSLLib: ISSLLibrary;
  LProbeLib: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LProbeStream: TMemoryStream;
  LCT: ISSLCertificateTransparency;
  LCTValidation: ISSLCertificateTransparencyValidation;
  LOrigCTLoaded: Boolean;
begin
  WriteLn;
  WriteLn('Testing Certificate Transparency Public Surface Truth Contract');
  WriteLn('==============================================================');

  LProbeLib := TOpenSSLLibrary.Create as ISSLLibrary;
  Require(LProbeLib <> nil, 'OpenSSL probe library instance is nil');
  if not LProbeLib.Initialize then
  begin
    WriteLn('Failed to initialize OpenSSL');
    Exit;
  end;

  LProbeStream := TMemoryStream.Create;
  try
    LCtx := LProbeLib.CreateContext(sslCtxClient);
    LConn := LCtx.CreateConnection(LProbeStream);

    Require(not Supports(LConn, ISSLCertificateTransparency, LCT),
      'OpenSSL connection must not expose ISSLCertificateTransparency by default');
    Require(not Supports(LConn, ISSLCertificateTransparencyValidation, LCTValidation),
      'OpenSSL connection must not expose ISSLCertificateTransparencyValidation by default');
  finally
    LProbeStream.Free;
  end;

  LConn := nil;
  LCtx := nil;
  LProbeLib := nil;

  SSLLib := TOpenSSLLibrary.Create as ISSLLibrary;
  Require(SSLLib <> nil, 'OpenSSL library instance is nil');
  LOrigCTLoaded := TOpenSSLLoader.IsModuleLoaded(osmCT);
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    TOpenSSLLoader.SetModuleLoaded(osmCT, True);
    LCaps := SSLLib.GetCapabilities;
    Require(not SSLLib.IsFeatureSupported(sslFeatCertificateTransparency),
      'OpenSSL must not publish CT feature support merely because low-level CT bindings are marked loaded');
    Require(not LCaps.SupportsCertificateTransparency,
      'OpenSSL capability must not claim CT support merely because low-level CT bindings are marked loaded');
    Require(LCaps.CertTransparencySupport = sslSupportNone,
      'OpenSSL CT support level must remain none until a real connection CT surface exists');
  finally
    TOpenSSLLoader.SetModuleLoaded(osmCT, LOrigCTLoaded);
  end;

  WriteLn('✅ Certificate-transparency public surface truth contract verified');
end;

procedure TestTPMPublicCapabilityTruthContract;
var
  SSLLib: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn;
  WriteLn('Testing TPM Public Capability Truth Contract');
  WriteLn('============================================');

  SSLLib := TOpenSSLLibrary.Create as ISSLLibrary;
  Require(SSLLib <> nil, 'OpenSSL library instance is nil');

  if not SSLLib.Initialize then
  begin
    WriteLn('Failed to initialize OpenSSL');
    Exit;
  end;

  LCaps := SSLLib.GetCapabilities;
  Require(not LCaps.SupportsTPM,
    'OpenSSL must not publish TPM capability without a shipped TPM public/runtime path');

  WriteLn('✅ TPM public capability truth contract verified');
end;

procedure TestPKCS11CapabilityMatrixRuntimeDriftContract;
var
  SSLLib: TOpenSSLLibrary;
  LOrigProviderLoad: TOSSL_PROVIDER_load;
  LOrigStoreOpen: TOSSL_STORE_open;
  LOrigStoreExpect: TOSSL_STORE_expect;
  LOrigEngineById: TENGINE_by_id;
  LOrigEngineInit: TENGINE_init;
  LOrigEngineLoadPrivateKey: TENGINE_load_private_key;
  LCaps: TSSLBackendCapabilities;
  LRuntimeReady: Boolean;
begin
  WriteLn;
  WriteLn('Testing PKCS#11 Capability Matrix Runtime Drift Contract');
  WriteLn('========================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LRuntimeReady := TPKCS11BackendFactory.IsBackendAvailable(btAuto);
    LCaps := SSLLib.GetCapabilities;
    Require(LCaps.SupportsPKCS11 = LRuntimeReady,
      'PKCS#11 capability must match PKCS#11 backend auto-detection readiness');
  finally
    SSLLib.Free;
  end;

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LOrigProviderLoad := OSSL_PROVIDER_load;
    LOrigStoreOpen := OSSL_STORE_open;
    LOrigStoreExpect := OSSL_STORE_expect;
    LOrigEngineById := ENGINE_by_id;
    LOrigEngineInit := ENGINE_init;
    LOrigEngineLoadPrivateKey := ENGINE_load_private_key;

    OSSL_PROVIDER_load := nil;
    OSSL_STORE_open := nil;
    OSSL_STORE_expect := nil;
    ENGINE_by_id := nil;
    ENGINE_init := nil;
    ENGINE_load_private_key := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsPKCS11,
        'PKCS#11 capability must stop claiming supported when neither Provider nor ENGINE backend is runtime-ready');
    finally
      OSSL_PROVIDER_load := LOrigProviderLoad;
      OSSL_STORE_open := LOrigStoreOpen;
      OSSL_STORE_expect := LOrigStoreExpect;
      ENGINE_by_id := LOrigEngineById;
      ENGINE_init := LOrigEngineInit;
      ENGINE_load_private_key := LOrigEngineLoadPrivateKey;
    end;

    WriteLn('✅ PKCS#11 capability matrix runtime drift contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestChaChaPolyCapabilityMatrixRuntimeDriftContract;
var
  SSLLib: TOpenSSLLibrary;
  LOrigSetCipherSuites: TSSL_CTX_set_ciphersuites;
  LCaps: TSSLBackendCapabilities;
  LRuntimeSupported: Boolean;
begin
  WriteLn;
  WriteLn('Testing ChaCha20-Poly1305 Capability Matrix Runtime Drift Contract');
  WriteLn('===================================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LRuntimeSupported := SSLLib.IsCipherSupported('TLS_CHACHA20_POLY1305_SHA256');
    LCaps := SSLLib.GetCapabilities;
    Require(LCaps.SupportsChaChaPoly = LRuntimeSupported,
      'ChaCha20-Poly1305 capability must match runtime cipher parser baseline');
  finally
    SSLLib.Free;
  end;

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LOrigSetCipherSuites := SSL_CTX_set_ciphersuites;
    if not Assigned(LOrigSetCipherSuites) then
    begin
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsChaChaPoly,
        'ChaCha20-Poly1305 capability must be false when SSL_CTX_set_ciphersuites is unavailable');
      WriteLn('✅ ChaCha20-Poly1305 capability matrix baseline contract verified');
      Exit;
    end;

    SSL_CTX_set_ciphersuites := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsChaChaPoly,
        'ChaCha20-Poly1305 capability must stop claiming supported when SSL_CTX_set_ciphersuites is not runtime-ready');
    finally
      SSL_CTX_set_ciphersuites := LOrigSetCipherSuites;
    end;

    WriteLn('✅ ChaCha20-Poly1305 capability matrix runtime drift contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestPKCS12CapabilityMatrixRuntimeDriftContract;
var
  SSLLib: TOpenSSLLibrary;
  LOrigPKCS12Parse: nextpas.core.tls.openssl.api.pkcs12.TPKCS12_parse;
  LCaps: TSSLBackendCapabilities;
  LSurfaceReady: Boolean;
begin
  WriteLn;
  WriteLn('Testing PKCS#12 Capability Matrix Runtime Drift Contract');
  WriteLn('========================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LSurfaceReady := Assigned(nextpas.core.tls.openssl.api.pkcs12.PKCS12_create) and
      Assigned(nextpas.core.tls.openssl.api.pkcs12.PKCS12_parse) and
      Assigned(nextpas.core.tls.openssl.api.pkcs12.d2i_PKCS12_bio) and
      Assigned(nextpas.core.tls.openssl.api.pkcs12.i2d_PKCS12_bio);
    LCaps := SSLLib.GetCapabilities;
    Require(LCaps.SupportsPKCS12 = LSurfaceReady,
      'PKCS#12 capability must match PKCS12 core API surface readiness');
  finally
    SSLLib.Free;
  end;

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LOrigPKCS12Parse := nextpas.core.tls.openssl.api.pkcs12.PKCS12_parse;
    if not Assigned(LOrigPKCS12Parse) then
    begin
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsPKCS12,
        'PKCS#12 capability must be false when PKCS12_parse is unavailable');
      WriteLn('✅ PKCS#12 capability matrix baseline contract verified');
      Exit;
    end;

    nextpas.core.tls.openssl.api.pkcs12.PKCS12_parse := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsPKCS12,
        'PKCS#12 capability must stop claiming supported when PKCS12_parse is not runtime-ready');
    finally
      nextpas.core.tls.openssl.api.pkcs12.PKCS12_parse := LOrigPKCS12Parse;
    end;

    WriteLn('✅ PKCS#12 capability matrix runtime drift contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestTLS13CapabilityMatrixPolicyAwareContract;
var
  SSLLib: TOpenSSLLibrary;
  LOrigSetMin: TSSL_CTX_set_min_proto_version;
  LOrigSetMax: TSSL_CTX_set_max_proto_version;
  LCaps: TSSLBackendCapabilities;
  LTLS13Runtime: Boolean;
begin
  WriteLn;
  WriteLn('Testing TLS 1.3 Capability Matrix Policy-Aware Contract');
  WriteLn('=======================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LTLS13Runtime := SSLLib.IsProtocolSupported(sslProtocolTLS13);
    LCaps := SSLLib.GetCapabilities;
    Require(LCaps.SupportsTLS13 = LTLS13Runtime,
      'TLS 1.3 capability must match runtime protocol probe baseline');
  finally
    SSLLib.Free;
  end;

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LOrigSetMin := SSL_CTX_set_min_proto_version;
    LOrigSetMax := SSL_CTX_set_max_proto_version;
    if (not Assigned(LOrigSetMin)) or (not Assigned(LOrigSetMax)) then
    begin
      WriteLn('[SKIP] Proto version setter symbols unavailable; skip TLS 1.3 capability policy-drift check');
      Exit;
    end;

    SSL_CTX_set_min_proto_version := @StubRejectTLS13SetMinProtoPolicy;
    SSL_CTX_set_max_proto_version := @StubRejectTLS13SetMaxProtoPolicy;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsTLS13,
        'TLS 1.3 capability must stop claiming supported when runtime policy rejects TLS 1.3');
      Require(LCaps.MaxTLSVersion = sslProtocolTLS12,
        'Max TLS version must fall back to TLS 1.2 when runtime policy rejects TLS 1.3');
      Require(LCaps.ZeroRTTSupport <> sslSupportStable,
        '0-RTT support must stop claiming stable when runtime policy rejects TLS 1.3');
      Require(LCaps.EarlyDataSupport <> sslSupportStable,
        'Early-data support must stop claiming stable when runtime policy rejects TLS 1.3');
      Require(LCaps.PostHandshakeAuthSupport <> sslSupportStable,
        'Post-handshake auth support must stop claiming stable when runtime policy rejects TLS 1.3');
    finally
      SSL_CTX_set_min_proto_version := LOrigSetMin;
      SSL_CTX_set_max_proto_version := LOrigSetMax;
    end;

    WriteLn('✅ TLS 1.3 capability matrix policy-aware contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestDTLSCapabilityMatrixPolicyAwareContract;
var
  SSLLib: TOpenSSLLibrary;
  LOrigSetMin: TSSL_CTX_set_min_proto_version;
  LOrigSetMax: TSSL_CTX_set_max_proto_version;
  LCaps: TSSLBackendCapabilities;
  LDTLSRuntime: Boolean;
begin
  WriteLn;
  WriteLn('Testing DTLS Capability Matrix Policy-Aware Contract');
  WriteLn('====================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LDTLSRuntime := SSLLib.IsProtocolSupported(sslProtocolDTLS10) or
      SSLLib.IsProtocolSupported(sslProtocolDTLS12);
    LCaps := SSLLib.GetCapabilities;
    Require(LCaps.SupportsDTLS = LDTLSRuntime,
      'DTLS capability must match runtime protocol probe baseline');
  finally
    SSLLib.Free;
  end;

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    LOrigSetMin := SSL_CTX_set_min_proto_version;
    LOrigSetMax := SSL_CTX_set_max_proto_version;
    if (not Assigned(LOrigSetMin)) or (not Assigned(LOrigSetMax)) then
    begin
      WriteLn('[SKIP] Proto version setter symbols unavailable; skip DTLS capability policy-drift check');
      Exit;
    end;

    SSL_CTX_set_min_proto_version := @StubRejectDTLSSetMinProtoPolicy;
    SSL_CTX_set_max_proto_version := @StubRejectDTLSSetMaxProtoPolicy;
    try
      Require(not SSLLib.IsProtocolSupported(sslProtocolDTLS10),
        'DTLS 1.0 runtime probe must respect DTLS policy setters');
      Require(not SSLLib.IsProtocolSupported(sslProtocolDTLS12),
        'DTLS 1.2 runtime probe must respect DTLS policy setters');
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsDTLS,
        'DTLS capability must stop claiming supported when runtime policy rejects DTLS protocol setters');
    finally
      SSL_CTX_set_min_proto_version := LOrigSetMin;
      SSL_CTX_set_max_proto_version := LOrigSetMax;
    end;

    WriteLn('✅ DTLS capability matrix policy-aware contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestKeyFormatCapabilityMatrixBaselineContract;
var
  SSLLib: TOpenSSLLibrary;
  LCaps: TSSLBackendCapabilities;
  LExpectedPEMPrivateKey: Boolean;
  LExpectedPKCS8PrivateKey: Boolean;
  LExpectedPasswordProtected: Boolean;
  LExpectedDERPrivateKey: Boolean;
begin
  WriteLn;
  WriteLn('Testing Key-Format Capability Matrix Baseline Contract');
  WriteLn('======================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    PrepareOpenSSLDERPrivateKeyRuntimeSurfaces;

    LExpectedPEMPrivateKey := ExpectedOpenSSLPEMOrPKCS8Ready;
    LExpectedPKCS8PrivateKey := ExpectedOpenSSLPKCS8PrivateKeyReady;
    LExpectedPasswordProtected := ExpectedOpenSSLPasswordProtectedKeyReady;
    LExpectedDERPrivateKey := ExpectedOpenSSLDERPrivateKeyReady;
    LCaps := SSLLib.GetCapabilities;

    Require(LCaps.SupportsPEMPrivateKey = LExpectedPEMPrivateKey,
      'PEM private-key capability must match the current OpenSSL private-key load surface');
    Require(LCaps.SupportsPKCS8PrivateKey = LExpectedPKCS8PrivateKey,
      'PKCS#8 private-key capability must match the current OpenSSL PEM/DER private-key load surface');
    Require(LCaps.SupportsPasswordProtectedKeys = LExpectedPasswordProtected,
      'Password-protected private-key capability must match the current OpenSSL PEM/encrypted-DER load surface');
    Require(LCaps.SupportsDERPrivateKey = LExpectedDERPrivateKey,
      'DER private-key capability must match the current OpenSSL DER private-key load surface');

    WriteLn('✅ Key-format capability matrix baseline contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestKeyFormatCapabilityMatrixDERPKCS8FallbackContract;
var
  SSLLib: TOpenSSLLibrary;
  LCaps: TSSLBackendCapabilities;
  LOrigPEMReadPrivateKey: TPEM_read_bio_PrivateKey;
  LOrigUsePrivateKeyFile: TSSL_CTX_use_PrivateKey_file;
  LOrigD2IX509Sig: nextpas.core.tls.openssl.api.pkcs.Td2i_X509_SIG;
  LOrigPKCS8Decrypt: nextpas.core.tls.openssl.api.pkcs12.TPKCS8_decrypt;
  LOrigD2IRSAPrivateKey: Td2i_RSAPrivateKey;
  LOrigEVPPKEYNew: TEVP_PKEY_new;
  LOrigEVPPKEYSet1RSA: TEVP_PKEY_set1_RSA;
begin
  WriteLn;
  WriteLn('Testing Key-Format Capability Matrix DER PKCS#8 Fallback Contract');
  WriteLn('=================================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    PrepareOpenSSLDERPrivateKeyRuntimeSurfaces;
    if not LoadOpenSSLPEM(GetCryptoLibHandle) then
    begin
      WriteLn('[SKIP] PEM module unavailable; skip DER PKCS#8 fallback check');
      Exit;
    end;

    if not ExpectedOpenSSLDERPKCS8PrivateKeyReady then
    begin
      WriteLn('[SKIP] DER PKCS#8 helpers unavailable; skip DER PKCS#8 fallback check');
      Exit;
    end;

    LOrigPEMReadPrivateKey := PEM_read_bio_PrivateKey;
    LOrigUsePrivateKeyFile := SSL_CTX_use_PrivateKey_file;
    LOrigD2IX509Sig := nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG;
    LOrigPKCS8Decrypt := nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt;
    LOrigD2IRSAPrivateKey := d2i_RSAPrivateKey;
    LOrigEVPPKEYNew := EVP_PKEY_new;
    LOrigEVPPKEYSet1RSA := EVP_PKEY_set1_RSA;

    PEM_read_bio_PrivateKey := nil;
    SSL_CTX_use_PrivateKey_file := nil;
    nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG := nil;
    nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt := nil;
    d2i_RSAPrivateKey := nil;
    EVP_PKEY_new := nil;
    EVP_PKEY_set1_RSA := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsPEMPrivateKey,
        'PEM private-key capability must be false when PEM read and PEM file surfaces are unavailable');
      Require(LCaps.SupportsPKCS8PrivateKey,
        'PKCS#8 private-key capability must stay true when DER PKCS#8 helpers remain runtime-ready');
      Require(LCaps.SupportsDERPrivateKey,
        'DER private-key capability must stay true when DER PKCS#8 helpers remain runtime-ready');
    finally
      PEM_read_bio_PrivateKey := LOrigPEMReadPrivateKey;
      SSL_CTX_use_PrivateKey_file := LOrigUsePrivateKeyFile;
      nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG := LOrigD2IX509Sig;
      nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt := LOrigPKCS8Decrypt;
      d2i_RSAPrivateKey := LOrigD2IRSAPrivateKey;
      EVP_PKEY_new := LOrigEVPPKEYNew;
      EVP_PKEY_set1_RSA := LOrigEVPPKEYSet1RSA;
    end;

    WriteLn('✅ Key-format capability matrix DER PKCS#8 fallback contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestKeyFormatCapabilityMatrixEncryptedDERPasswordContract;
var
  SSLLib: TOpenSSLLibrary;
  LCaps: TSSLBackendCapabilities;
  LOrigPEMReadPrivateKey: TPEM_read_bio_PrivateKey;
  LOrigUsePrivateKeyFile: TSSL_CTX_use_PrivateKey_file;
  LOrigD2IPKCS8PrivateKeyInfo: nextpas.core.tls.openssl.api.pkcs.Td2i_PKCS8_PRIV_KEY_INFO;
  LOrigD2IRSAPrivateKey: Td2i_RSAPrivateKey;
  LOrigEVPPKEYNew: TEVP_PKEY_new;
  LOrigEVPPKEYSet1RSA: TEVP_PKEY_set1_RSA;
begin
  WriteLn;
  WriteLn('Testing Key-Format Capability Matrix Encrypted DER Password Contract');
  WriteLn('===================================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    PrepareOpenSSLDERPrivateKeyRuntimeSurfaces;
    if not LoadOpenSSLPEM(GetCryptoLibHandle) then
    begin
      WriteLn('[SKIP] PEM module unavailable; skip encrypted DER password check');
      Exit;
    end;

    if not ExpectedOpenSSLEncryptedDERPKCS8PrivateKeyReady then
    begin
      WriteLn('[SKIP] Encrypted DER PKCS#8 helpers unavailable; skip encrypted DER password check');
      Exit;
    end;

    LOrigPEMReadPrivateKey := PEM_read_bio_PrivateKey;
    LOrigUsePrivateKeyFile := SSL_CTX_use_PrivateKey_file;
    LOrigD2IPKCS8PrivateKeyInfo := nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO;
    LOrigD2IRSAPrivateKey := d2i_RSAPrivateKey;
    LOrigEVPPKEYNew := EVP_PKEY_new;
    LOrigEVPPKEYSet1RSA := EVP_PKEY_set1_RSA;

    PEM_read_bio_PrivateKey := nil;
    SSL_CTX_use_PrivateKey_file := nil;
    nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO := nil;
    d2i_RSAPrivateKey := nil;
    EVP_PKEY_new := nil;
    EVP_PKEY_set1_RSA := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsPEMPrivateKey,
        'PEM private-key capability must be false when only encrypted DER helpers remain runtime-ready');
      Require(LCaps.SupportsPKCS8PrivateKey,
        'PKCS#8 private-key capability must stay true when only encrypted DER PKCS#8 helpers remain runtime-ready');
      Require(LCaps.SupportsPasswordProtectedKeys,
        'Password-protected private-key capability must stay true when only encrypted DER PKCS#8 helpers remain runtime-ready');
      Require(LCaps.SupportsDERPrivateKey,
        'DER private-key capability must stay true when only encrypted DER PKCS#8 helpers remain runtime-ready');
    finally
      PEM_read_bio_PrivateKey := LOrigPEMReadPrivateKey;
      SSL_CTX_use_PrivateKey_file := LOrigUsePrivateKeyFile;
      nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO := LOrigD2IPKCS8PrivateKeyInfo;
      d2i_RSAPrivateKey := LOrigD2IRSAPrivateKey;
      EVP_PKEY_new := LOrigEVPPKEYNew;
      EVP_PKEY_set1_RSA := LOrigEVPPKEYSet1RSA;
    end;

    WriteLn('✅ Key-format capability matrix encrypted DER password contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestKeyFormatCapabilityMatrixNoDERSurfaceRuntimeDriftContract;
var
  SSLLib: TOpenSSLLibrary;
  LCaps: TSSLBackendCapabilities;
  LOrigD2IPKCS8PrivateKeyInfo: nextpas.core.tls.openssl.api.pkcs.Td2i_PKCS8_PRIV_KEY_INFO;
  LOrigEVPPKCS82PKEY: nextpas.core.tls.openssl.api.pkcs.TEVP_PKCS82PKEY;
  LOrigD2IX509Sig: nextpas.core.tls.openssl.api.pkcs.Td2i_X509_SIG;
  LOrigPKCS8Decrypt: nextpas.core.tls.openssl.api.pkcs12.TPKCS8_decrypt;
  LOrigD2IRSAPrivateKey: Td2i_RSAPrivateKey;
  LOrigECKeyFree: TEC_KEY_free;
  LOrigEVPPKEYNew: TEVP_PKEY_new;
  LOrigEVPPKEYSet1RSA: TEVP_PKEY_set1_RSA;
begin
  WriteLn;
  WriteLn('Testing Key-Format Capability Matrix No-DER-Surface Runtime Drift Contract');
  WriteLn('=========================================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    PrepareOpenSSLDERPrivateKeyRuntimeSurfaces;

    LOrigD2IPKCS8PrivateKeyInfo := nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO;
    LOrigEVPPKCS82PKEY := nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY;
    LOrigD2IX509Sig := nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG;
    LOrigPKCS8Decrypt := nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt;
    LOrigD2IRSAPrivateKey := d2i_RSAPrivateKey;
    LOrigECKeyFree := EC_KEY_free;
    LOrigEVPPKEYNew := EVP_PKEY_new;
    LOrigEVPPKEYSet1RSA := EVP_PKEY_set1_RSA;

    nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO := nil;
    nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY := nil;
    nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG := nil;
    nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt := nil;
    d2i_RSAPrivateKey := nil;
    EC_KEY_free := nil;
    EVP_PKEY_new := nil;
    EVP_PKEY_set1_RSA := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsDERPrivateKey,
        'DER private-key capability must stop claiming support when all DER helper surfaces are unavailable');
    finally
      nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO := LOrigD2IPKCS8PrivateKeyInfo;
      nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY := LOrigEVPPKCS82PKEY;
      nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG := LOrigD2IX509Sig;
      nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt := LOrigPKCS8Decrypt;
      d2i_RSAPrivateKey := LOrigD2IRSAPrivateKey;
      EC_KEY_free := LOrigECKeyFree;
      EVP_PKEY_new := LOrigEVPPKEYNew;
      EVP_PKEY_set1_RSA := LOrigEVPPKEYSet1RSA;
    end;

    WriteLn('✅ Key-format capability matrix no-DER-surface runtime drift contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestKeyFormatCapabilityMatrixECSEC1FallbackContract;
var
  SSLLib: TOpenSSLLibrary;
  LCaps: TSSLBackendCapabilities;
  LOrigPEMReadPrivateKey: TPEM_read_bio_PrivateKey;
  LOrigUsePrivateKeyFile: TSSL_CTX_use_PrivateKey_file;
  LOrigD2IPKCS8PrivateKeyInfo: nextpas.core.tls.openssl.api.pkcs.Td2i_PKCS8_PRIV_KEY_INFO;
  LOrigEVPPKCS82PKEY: nextpas.core.tls.openssl.api.pkcs.TEVP_PKCS82PKEY;
  LOrigD2IX509Sig: nextpas.core.tls.openssl.api.pkcs.Td2i_X509_SIG;
  LOrigPKCS8Decrypt: nextpas.core.tls.openssl.api.pkcs12.TPKCS8_decrypt;
  LOrigD2IRSAPrivateKey: Td2i_RSAPrivateKey;
  LOrigEVPPKEYSet1RSA: TEVP_PKEY_set1_RSA;
begin
  WriteLn;
  WriteLn('Testing Key-Format Capability Matrix EC SEC1 Fallback Contract');
  WriteLn('==============================================================');

  SSLLib := TOpenSSLLibrary.Create;
  try
    if not SSLLib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    PrepareOpenSSLDERPrivateKeyRuntimeSurfaces;
    if not ExpectedOpenSSLDERSEC1ECPrivateKeyReady then
    begin
      WriteLn('[SKIP] EC SEC1 helpers unavailable; skip EC SEC1 fallback check');
      Exit;
    end;

    LOrigPEMReadPrivateKey := PEM_read_bio_PrivateKey;
    LOrigUsePrivateKeyFile := SSL_CTX_use_PrivateKey_file;
    LOrigD2IPKCS8PrivateKeyInfo := nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO;
    LOrigEVPPKCS82PKEY := nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY;
    LOrigD2IX509Sig := nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG;
    LOrigPKCS8Decrypt := nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt;
    LOrigD2IRSAPrivateKey := d2i_RSAPrivateKey;
    LOrigEVPPKEYSet1RSA := EVP_PKEY_set1_RSA;

    PEM_read_bio_PrivateKey := nil;
    SSL_CTX_use_PrivateKey_file := nil;
    nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO := nil;
    nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY := nil;
    nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG := nil;
    nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt := nil;
    d2i_RSAPrivateKey := nil;
    EVP_PKEY_set1_RSA := nil;
    try
      LCaps := SSLLib.GetCapabilities;
      Require(not LCaps.SupportsPEMPrivateKey,
        'PEM private-key capability must be false when only EC SEC1 DER surface remains runtime-ready');
      Require(not LCaps.SupportsPKCS8PrivateKey,
        'PKCS#8 private-key capability must be false when only EC SEC1 DER surface remains runtime-ready');
      Require(not LCaps.SupportsPasswordProtectedKeys,
        'Password-protected private-key capability must be false when only EC SEC1 DER surface remains runtime-ready');
      Require(LCaps.SupportsDERPrivateKey,
        'DER private-key capability must stay true when only EC SEC1 DER surface remains runtime-ready');
    finally
      PEM_read_bio_PrivateKey := LOrigPEMReadPrivateKey;
      SSL_CTX_use_PrivateKey_file := LOrigUsePrivateKeyFile;
      nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO := LOrigD2IPKCS8PrivateKeyInfo;
      nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY := LOrigEVPPKCS82PKEY;
      nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG := LOrigD2IX509Sig;
      nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt := LOrigPKCS8Decrypt;
      d2i_RSAPrivateKey := LOrigD2IRSAPrivateKey;
      EVP_PKEY_set1_RSA := LOrigEVPPKEYSet1RSA;
    end;

    WriteLn('✅ Key-format capability matrix EC SEC1 fallback contract verified');
  finally
    SSLLib.Free;
  end;
end;

procedure TestProtocolSupportPolicyAwareContract;
var
  SSLLib: ISSLLibrary;
  LOrigSetMin: TSSL_CTX_set_min_proto_version;
  LOrigSetMax: TSSL_CTX_set_max_proto_version;
begin
  WriteLn;
  WriteLn('Testing Protocol Support Policy-Aware Contract');
  WriteLn('==============================================');

  SSLLib := TSSLFactory.GetLibrary(sslOpenSSL);
  Require(SSLLib <> nil, 'OpenSSL library instance is nil');

  if not SSLLib.Initialize then
  begin
    WriteLn('Failed to initialize OpenSSL');
    Exit;
  end;

  LOrigSetMin := SSL_CTX_set_min_proto_version;
  LOrigSetMax := SSL_CTX_set_max_proto_version;

  if (not Assigned(LOrigSetMin)) or (not Assigned(LOrigSetMax)) then
  begin
    WriteLn('[SKIP] Proto version setter symbols unavailable; skip policy-aware probe check');
    Exit;
  end;

  SSL_CTX_set_min_proto_version := @StubSetMinProtoPolicy;
  SSL_CTX_set_max_proto_version := @StubSetMaxProtoPolicy;
  try
    Require(not SSLLib.IsProtocolSupported(sslProtocolTLS10),
      'TLS1.0 should be unsupported when runtime policy rejects TLS1.0 setters');
    Require(not SSLLib.IsProtocolSupported(sslProtocolTLS11),
      'TLS1.1 should be unsupported when runtime policy rejects TLS1.1 setters');
    Require(SSLLib.IsProtocolSupported(sslProtocolTLS12),
      'TLS1.2 should remain supported when runtime policy allows TLS1.2 setters');
  finally
    SSL_CTX_set_min_proto_version := LOrigSetMin;
    SSL_CTX_set_max_proto_version := LOrigSetMax;
  end;

  WriteLn('✅ Protocol policy-aware contract verified');
end;

begin
  WriteLn('Testing OpenSSL Advanced Features');
  WriteLn('==================================');
  WriteLn;

  try
    TestCertificateStore;
    TestSession;
    TestCertificateVerify;
    TestCipherSupportContract;
    TestFeatureSupportRuntimeDriftContract;
    TestCapabilityMatrixRuntimeDriftContract;
    TestSessionTicketCapabilityMatrixRuntimeDriftContract;
    TestPostHandshakeCapabilityMatrixRuntimeDriftContract;
    TestSNICapabilityMatrixRuntimeDriftContract;
    TestALPNCapabilityMatrixRuntimeDriftContract;
    TestOCSPStaplingCapabilityMatrixRuntimeDriftContract;
    TestSessionCacheCapabilityMatrixRuntimeDriftContract;
    TestRenegotiationCapabilityMatrixRuntimeDriftContract;
    TestCertificateTransparencyCapabilityMatrixRuntimeDriftContract;
    TestCertificateTransparencyPublicSurfaceTruthContract;
    TestTPMPublicCapabilityTruthContract;
    TestPKCS11CapabilityMatrixRuntimeDriftContract;
    TestChaChaPolyCapabilityMatrixRuntimeDriftContract;
    TestPKCS12CapabilityMatrixRuntimeDriftContract;
    TestTLS13CapabilityMatrixPolicyAwareContract;
    TestDTLSCapabilityMatrixPolicyAwareContract;
    TestKeyFormatCapabilityMatrixBaselineContract;
    TestKeyFormatCapabilityMatrixDERPKCS8FallbackContract;
    TestKeyFormatCapabilityMatrixEncryptedDERPasswordContract;
    TestKeyFormatCapabilityMatrixECSEC1FallbackContract;
    TestKeyFormatCapabilityMatrixNoDERSurfaceRuntimeDriftContract;
    TestProtocolSupportPolicyAwareContract;

    WriteLn;
    WriteLn('===================');
    WriteLn('✅ All tests passed');
    WriteLn('===================');
  except
    on E: Exception do
    begin
      WriteLn('❌ Test failed: ', E.Message);
      Halt(1);
    end;
  end;
end.
