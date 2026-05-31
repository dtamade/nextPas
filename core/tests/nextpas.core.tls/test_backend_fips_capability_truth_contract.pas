program test_backend_fips_capability_truth_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib
  {$IFDEF UNIX}
  , nextpas.core.tls.openssl.backed
  , nextpas.core.tls.mbedtls.lib
  , nextpas.core.tls.wolfssl.lib
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

  LActual := LLib.GetCapabilities.SupportsFIPSMode;
  Require(LActual = AExpected,
    Format('%s SupportsFIPSMode mismatch: expected=%s actual=%s',
      [SSL_LIBRARY_NAMES[ABackend], BoolToStr(AExpected, True), BoolToStr(LActual, True)]));

  WriteLn('[PASS] ', SSL_LIBRARY_NAMES[ABackend], ' SupportsFIPSMode = ',
    BoolToStr(LActual, True));
end;

begin
  WriteLn('Testing backend FIPS capability truth contract');
  WriteLn('==============================================');

  CheckBackendCapability(sslFreePascal, False);
  CheckBackendCapability(sslOpenSSL, False);
  CheckBackendCapability(sslWinSSL, False);
  CheckBackendCapability(sslMbedTLS, False);
  CheckBackendCapability(sslWolfSSL, False);

  WriteLn('==============================================');
  WriteLn('✅ backend FIPS capability truth contract verified');
end.
