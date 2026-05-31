program test_capability_matrix_simple;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed;

procedure Require(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure TestCapabilityHelpers;
var
  Caps: TSSLBackendCapabilities;
begin
  WriteLn('========================================');
  WriteLn('Testing Capability Helper Functions');
  WriteLn('========================================');
  WriteLn;

  FillChar(Caps, SizeOf(Caps), 0);
  Caps.BackendType := sslOpenSSL;
  Caps.BackendImplType := sslImplCLibrary;
  Caps.BackendVersion := 'OpenSSL 3.0.0 (simulated)';

  Caps.SupportedCiphers := [sslCipherAES128, sslCipherAES256, sslCipherAES128GCM];
  Caps.SupportedHashes := [sslHashSHA256, sslHashSHA384, sslHashSHA512];
  Caps.SupportedKeyExchanges := [sslKexRSA, sslKexECDHE_RSA];

  Caps.HasHardwareAcceleration := True;
  Caps.HasSIMDOptimization := True;
  Caps.HasConstantTimeOperations := True;
  Caps.SupportsFIPSMode := False;
  Caps.RequiresExternalLibrary := True;
  Caps.SupportsSystemCertStore := False;

  WriteLn('[Algorithm Query Tests]');
  WriteLn('  IsCipherSupported(AES128): ', IsCipherSupported(Caps, sslCipherAES128));
  WriteLn('  IsCipherSupported(ChaCha20): ', IsCipherSupported(Caps, sslCipherCHACHA20_POLY1305));
  WriteLn('  IsHashSupported(SHA256): ', IsHashSupported(Caps, sslHashSHA256));
  WriteLn('  IsHashSupported(SHA1): ', IsHashSupported(Caps, sslHashSHA1));
  WriteLn('  IsKeyExchangeSupported(RSA): ', IsKeyExchangeSupported(Caps, sslKexRSA));
  WriteLn('  IsKeyExchangeSupported(ECDHE_ECDSA): ', IsKeyExchangeSupported(Caps, sslKexECDHE_ECDSA));

  Require(IsCipherSupported(Caps, sslCipherAES128), 'Simulated capability must contain AES128');
  Require(not IsCipherSupported(Caps, sslCipherCHACHA20_POLY1305),
    'Simulated capability must not contain ChaCha20');
  Require(IsHashSupported(Caps, sslHashSHA256), 'Simulated capability must contain SHA256');
  Require(not IsHashSupported(Caps, sslHashSHA1), 'Simulated capability must not contain SHA1');
  Require(IsKeyExchangeSupported(Caps, sslKexRSA), 'Simulated capability must contain RSA key exchange');
  Require(not IsKeyExchangeSupported(Caps, sslKexECDHE_ECDSA),
    'Simulated capability must not contain ECDHE_ECDSA');
  WriteLn;

  WriteLn('[Backend Type Tests]');
  WriteLn('  IsNativeBackend: ', IsNativeBackend(Caps));
  WriteLn('  IsCLibraryBackend: ', IsCLibraryBackend(Caps));
  WriteLn('  RequiresExternalDependencies: ', RequiresExternalDependencies(Caps));

  Require(not IsNativeBackend(Caps), 'Simulated OpenSSL backend is not native');
  Require(IsCLibraryBackend(Caps), 'Simulated OpenSSL backend should be C library backend');
  Require(RequiresExternalDependencies(Caps), 'Simulated OpenSSL backend should require external deps');
  WriteLn;

  WriteLn('[Feature Support Level Tests]');
  Caps.SNISupport := sslSupportStable;
  Caps.OCSPStaplingSupport := sslSupportExperimental;
  Caps.CertTransparencySupport := sslSupportDeprecated;
  WriteLn('  IsFeatureStable(SNI): ', IsFeatureStable(Caps.SNISupport));
  WriteLn('  IsFeatureStable(OCSPStapling): ', IsFeatureStable(Caps.OCSPStaplingSupport));
  WriteLn('  IsFeatureUsable(OCSPStapling): ', IsFeatureUsable(Caps.OCSPStaplingSupport));
  WriteLn('  IsFeatureDeprecated(CertTransparency): ', IsFeatureDeprecated(Caps.CertTransparencySupport));

  Require(IsFeatureStable(Caps.SNISupport), 'SNI support level should be stable');
  Require(not IsFeatureStable(Caps.OCSPStaplingSupport), 'OCSP support level should not be stable');
  Require(IsFeatureUsable(Caps.OCSPStaplingSupport), 'Experimental OCSP should be usable');
  Require(IsFeatureDeprecated(Caps.CertTransparencySupport), 'CT support level should be deprecated');
  WriteLn;

  WriteLn('[Scoring Tests]');
  WriteLn('  GetSecurityScore: ', GetSecurityScore(Caps), '/100');
  WriteLn('  GetPerformanceScore: ', GetPerformanceScore(Caps), '/100');
  Require(GetSecurityScore(Caps) > 0, 'Security score should be positive');
  Require(GetPerformanceScore(Caps) > 0, 'Performance score should be positive');
  WriteLn;

  WriteLn('[Description Test]');
  WriteLn(GetCapabilitiesDescription(Caps));
  WriteLn;
end;

procedure TestOpenSSLBackend;
var
  Lib: TOpenSSLLibrary;
  Caps: TSSLBackendCapabilities;
begin
  WriteLn('========================================');
  WriteLn('Testing OpenSSL Backend');
  WriteLn('========================================');
  WriteLn;

  Lib := TOpenSSLLibrary.Create;
  try
    if Lib.Initialize then
    begin
      WriteLn('[OpenSSL Backend Initialized]');
      WriteLn;

      Caps := Lib.GetCapabilities;

      WriteLn('[v1.1.0 Fields]');
      WriteLn('  SupportsTLS13: ', Caps.SupportsTLS13);
      WriteLn('  SupportsALPN: ', Caps.SupportsALPN);
      WriteLn('  SupportsSNI: ', Caps.SupportsSNI);
      WriteLn('  SupportsECDHE: ', Caps.SupportsECDHE);
      WriteLn;

      WriteLn('[v1.2.0 New Fields]');
      WriteLn('  BackendType: ', Ord(Caps.BackendType), ' (', SSL_LIBRARY_NAMES[Caps.BackendType], ')');
      WriteLn('  BackendImplType: ', Ord(Caps.BackendImplType));
      WriteLn('  BackendVersion: ', Caps.BackendVersion);
      WriteLn('  SupportsDTLS: ', Caps.SupportsDTLS);
      WriteLn;

      WriteLn('[Algorithm Support]');
      WriteLn('  AES128: ', IsCipherSupported(Caps, sslCipherAES128));
      WriteLn('  AES256GCM: ', IsCipherSupported(Caps, sslCipherAES256GCM));
      WriteLn('  ChaCha20: ', IsCipherSupported(Caps, sslCipherCHACHA20_POLY1305));
      WriteLn('  SHA256: ', IsHashSupported(Caps, sslHashSHA256));
      WriteLn('  ECDHE-RSA: ', IsKeyExchangeSupported(Caps, sslKexECDHE_RSA));

      Require(Lib.IsCipherSupported('TLS_AES_128_GCM_SHA256'),
        'OpenSSL should accept known TLS_AES_128_GCM_SHA256');
      Require(not Lib.IsCipherSupported('TLS_FAKE_AES_128_GCM_SHA256'),
        'OpenSSL should reject unknown fake cipher');
      Require(not Lib.IsCipherSupported(''),
        'OpenSSL should reject empty cipher name');
      WriteLn;

      WriteLn('[Security & Performance]');
      WriteLn('  SecurityScore: ', GetSecurityScore(Caps), '/100');
      WriteLn('  PerformanceScore: ', GetPerformanceScore(Caps), '/100');
      WriteLn('  HasHardwareAcceleration: ', Caps.HasHardwareAcceleration);
      WriteLn('  HasSIMDOptimization: ', Caps.HasSIMDOptimization);
      WriteLn('  HasConstantTimeOperations: ', Caps.HasConstantTimeOperations);
      WriteLn;

      WriteLn('[Platform Features]');
      WriteLn('  RequiresExternalLibrary: ', Caps.RequiresExternalLibrary);
      WriteLn('  SupportsSystemCertStore: ', Caps.SupportsSystemCertStore);
      WriteLn('  SupportsPKCS11: ', Caps.SupportsPKCS11);
      WriteLn;

      Lib.Finalize;
    end
    else
    begin
      WriteLn('[ERROR] Failed to initialize OpenSSL library');
      WriteLn('  This is expected if OpenSSL is not installed');
    end;
  finally
    Lib.Free;
  end;
end;

begin
  WriteLn('fafafa.ssl - Capability Matrix v1.2.0 Simple Test');
  WriteLn('==================================================');
  WriteLn;

  try
    TestCapabilityHelpers;
    WriteLn;
    TestOpenSSLBackend;

    WriteLn;
    WriteLn('========================================');
    WriteLn('All tests completed successfully!');
    WriteLn('========================================');
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('[FATAL ERROR] ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
