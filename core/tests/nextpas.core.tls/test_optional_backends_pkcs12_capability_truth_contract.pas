program test_optional_backends_pkcs12_capability_truth_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.openssl.backed
  {$IFDEF UNIX}
  , nextpas.core.tls.mbedtls.lib
  , nextpas.core.tls.wolfssl.lib
  {$ENDIF}
  {$IFDEF WINDOWS}
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

procedure CheckBackendCapability(ABackend: TSSLLibraryType; AExpected: Boolean);
var
  LLib: ISSLLibrary;
  LActual: Boolean;
begin
  if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    WriteLn('[SKIP] ', SSL_LIBRARY_NAMES[ABackend], ' backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibrary(ABackend);
  Require(LLib <> nil, SSL_LIBRARY_NAMES[ABackend] + ' library should be creatable when available');

  LActual := LLib.GetCapabilities.SupportsPKCS12;
  Require(LActual = AExpected,
    Format('%s SupportsPKCS12 mismatch: expected=%s actual=%s',
      [SSL_LIBRARY_NAMES[ABackend], BoolToStr(AExpected, True), BoolToStr(LActual, True)]));

  WriteLn('[PASS] ', SSL_LIBRARY_NAMES[ABackend], ' SupportsPKCS12 = ',
    BoolToStr(LActual, True));
end;

begin
  WriteLn('Testing optional backends PKCS12 capability truth contract');
  WriteLn('==========================================================');

  CheckBackendCapability(sslFreePascal, False);
  CheckBackendCapability(sslOpenSSL, True);
  CheckBackendCapability(sslWinSSL, True);
  CheckBackendCapability(sslMbedTLS, False);
  CheckBackendCapability(sslWolfSSL, False);

  WriteLn('==========================================================');
  WriteLn('✅ optional backends PKCS12 capability truth contract verified');
end.
