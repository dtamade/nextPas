program test_backend_feature_capability_parity_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib
  {$IFDEF UNIX}
  , nextpas.core.tls.openssl.backed
  , nextpas.core.tls.openssl.base
  , nextpas.core.tls.mbedtls.lib
  , nextpas.core.tls.mbedtls.base
  , nextpas.core.tls.wolfssl.lib
  , nextpas.core.tls.wolfssl.base
  {$ENDIF}
  {$IFDEF WINDOWS}
  , nextpas.core.tls.openssl.backed
  , nextpas.core.tls.winssl.lib
  , nextpas.core.tls.mbedtls.lib
  , nextpas.core.tls.wolfssl.lib
  {$ENDIF}
  ;

procedure Require(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function FeatureLevelPresent(ALevel: TSSLFeatureSupportLevel): Boolean;
begin
  Result := ALevel <> sslSupportNone;
end;

function PublishedFeatureTruth(
  const ACaps: TSSLBackendCapabilities;
  AFeature: TSSLFeature
): Boolean;
begin
  Result := False;
  case AFeature of
    sslFeatSNI:
      Result := FeatureLevelPresent(ACaps.SNISupport);
    sslFeatALPN:
      Result := FeatureLevelPresent(ACaps.ALPNSupport);
    sslFeatSessionCache:
      Result := FeatureLevelPresent(ACaps.SessionCacheSupport);
    sslFeatSessionTickets:
      Result := FeatureLevelPresent(ACaps.SessionTicketsSupport);
    sslFeatRenegotiation:
      Result := FeatureLevelPresent(ACaps.RenegotiationSupport);
    sslFeatOCSPStapling:
      Result := FeatureLevelPresent(ACaps.OCSPStaplingSupport);
    sslFeatCertificateTransparency:
      Result := FeatureLevelPresent(ACaps.CertTransparencySupport);
  end;
end;

function FeatureName(AFeature: TSSLFeature): string;
begin
  Result := '';
  case AFeature of
    sslFeatSNI:
      Result := 'SNI';
    sslFeatALPN:
      Result := 'ALPN';
    sslFeatSessionCache:
      Result := 'SessionCache';
    sslFeatSessionTickets:
      Result := 'SessionTickets';
    sslFeatRenegotiation:
      Result := 'Renegotiation';
    sslFeatOCSPStapling:
      Result := 'OCSPStapling';
    sslFeatCertificateTransparency:
      Result := 'CertificateTransparency';
  end;
end;

procedure CheckBackendParity(ABackend: TSSLLibraryType);
var
  LLib: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
  LFeature: TSSLFeature;
  LRuntimeTruth: Boolean;
  LPublishedTruth: Boolean;
begin
  if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    WriteLn('[SKIP] ', SSL_LIBRARY_NAMES[ABackend], ' not available');
    Exit;
  end;

  LLib := TSSLFactory.GetLibrary(ABackend);
  Require(LLib <> nil, SSL_LIBRARY_NAMES[ABackend] + ' library must be creatable');

  LCaps := LLib.GetCapabilities;

  WriteLn('[CHECK] ', SSL_LIBRARY_NAMES[ABackend]);
  for LFeature := Low(TSSLFeature) to High(TSSLFeature) do
  begin
    LRuntimeTruth := LLib.IsFeatureSupported(LFeature);
    LPublishedTruth := PublishedFeatureTruth(LCaps, LFeature);

    Require(LRuntimeTruth = LPublishedTruth,
      Format('%s %s parity mismatch: runtime=%s published=%s',
        [
          SSL_LIBRARY_NAMES[ABackend],
          FeatureName(LFeature),
          BoolToStr(LRuntimeTruth, True),
          BoolToStr(LPublishedTruth, True)
        ]));

    WriteLn('  [PASS] ', FeatureName(LFeature), ' runtime/published parity = ',
      BoolToStr(LRuntimeTruth, True));
  end;
end;

var
  LBackend: TSSLLibraryType;
begin
  WriteLn('Testing backend feature capability parity contract');
  WriteLn('===============================================');

  for LBackend := Low(TSSLLibraryType) to High(TSSLLibraryType) do
  begin
    if LBackend = sslAutoDetect then
      Continue;
    CheckBackendParity(LBackend);
  end;

  WriteLn('✅ backend feature capability parity contract verified');
end.
