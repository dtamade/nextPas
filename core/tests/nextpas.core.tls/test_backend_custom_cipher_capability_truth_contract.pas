program test_backend_custom_cipher_capability_truth_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.freepascal.lib
  {$IFDEF UNIX}
  , nextpas.core.tls.openssl.backed
  , nextpas.core.tls.openssl.api.ssl
  , nextpas.core.tls.mbedtls.lib
  , nextpas.core.tls.wolfssl.lib
  {$ENDIF}
  {$IFDEF WINDOWS}
  , nextpas.core.tls.openssl.backed
  , nextpas.core.tls.openssl.api.ssl
  , nextpas.core.tls.winssl.lib
  , nextpas.core.tls.mbedtls.lib
  , nextpas.core.tls.wolfssl.lib
  {$ENDIF}
  ;

const
  CUSTOM_CIPHER_LIST = 'HIGH:!aNULL:!MD5';
  CUSTOM_CIPHER_SUITES = 'TLS_AES_128_GCM_SHA256';

procedure Require(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function IsUnsupportedCustomCipherMessage(const AMessage: string): Boolean;
var
  LLower: string;
begin
  LLower := LowerCase(AMessage);
  Result := (Pos('unsupported', LLower) > 0) or
    (Pos('supportscustomciphersuites', LLower) > 0) or
    (Pos('不支持', AMessage) > 0);
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

  LActual := LLib.GetCapabilities.SupportsCustomCipherSuites;
  Require(LActual = AExpected,
    Format('%s SupportsCustomCipherSuites mismatch: expected=%s actual=%s',
      [SSL_LIBRARY_NAMES[ABackend], BoolToStr(AExpected, True), BoolToStr(LActual, True)]));

  WriteLn('[PASS] ', SSL_LIBRARY_NAMES[ABackend], ' SupportsCustomCipherSuites = ',
    BoolToStr(LActual, True));
end;

procedure CheckOpenSSLBackendCapability;
var
  LLib: ISSLLibrary;
  LActual: Boolean;
  LExpected: Boolean;
begin
  if not TSSLFactory.IsLibraryAvailable(sslOpenSSL) then
  begin
    WriteLn('[SKIP] OpenSSL backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibrary(sslOpenSSL);
  Require(LLib <> nil, 'OpenSSL library should be creatable when available');

  LExpected := OpenSSLPublishedCustomCipherSurfaceReady;
  LActual := LLib.GetCapabilities.SupportsCustomCipherSuites;
  Require(LActual = LExpected,
    Format('OpenSSL SupportsCustomCipherSuites mismatch: expected=%s actual=%s',
      [BoolToStr(LExpected, True), BoolToStr(LActual, True)]));

  WriteLn('[PASS] OpenSSL SupportsCustomCipherSuites = ', BoolToStr(LActual, True));
end;

procedure ExpectUnsupportedSetCipherList(ACtx: ISSLContext;
  ABackend: TSSLLibraryType; const AValue, ALabel: string);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ACtx.SetCipherList(AValue);
  except
    on E: ESSLException do
    begin
      Require(IsUnsupportedCustomCipherMessage(E.Message),
        Format('%s %s rejection must report unsupported custom-cipher semantics: %s',
          [SSL_LIBRARY_NAMES[ABackend], ALabel, E.Message]));
      LRejected := True;
    end;
  end;

  Require(LRejected,
    Format('%s must reject %s while SupportsCustomCipherSuites=False',
      [SSL_LIBRARY_NAMES[ABackend], ALabel]));
end;

procedure ExpectUnsupportedSetCipherSuites(ACtx: ISSLContext;
  ABackend: TSSLLibraryType; const AValue, ALabel: string);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ACtx.SetCipherSuites(AValue);
  except
    on E: ESSLException do
    begin
      Require(IsUnsupportedCustomCipherMessage(E.Message),
        Format('%s %s rejection must report unsupported custom-cipher semantics: %s',
          [SSL_LIBRARY_NAMES[ABackend], ALabel, E.Message]));
      LRejected := True;
    end;
  end;

  Require(LRejected,
    Format('%s must reject %s while SupportsCustomCipherSuites=False',
      [SSL_LIBRARY_NAMES[ABackend], ALabel]));
end;

procedure CheckPublishedOpenSSLBackend;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
begin
  if not TSSLFactory.IsLibraryAvailable(sslOpenSSL) then
  begin
    WriteLn('[SKIP] OpenSSL backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibrary(sslOpenSSL);
  Require(LLib <> nil, 'OpenSSL library should be creatable when available');
  Require(LLib.GetCapabilities.SupportsCustomCipherSuites,
    'OpenSSL must publish SupportsCustomCipherSuites=True on the ready runtime path');

  LCtx := LLib.CreateContext(sslCtxClient);
  Require(LCtx <> nil, 'OpenSSL context should be creatable');

  LCtx.SetCipherList(CUSTOM_CIPHER_LIST);
  Require(LCtx.GetCipherList = CUSTOM_CIPHER_LIST,
    'OpenSSL published backend should accept custom cipher-list override');

  LCtx.SetCipherSuites(CUSTOM_CIPHER_SUITES);
  Require(LCtx.GetCipherSuites = CUSTOM_CIPHER_SUITES,
    'OpenSSL published backend should accept custom cipher-suites override');

  WriteLn('[PASS] OpenSSL published custom-cipher setters accept custom non-default overrides');
end;

procedure CheckUnpublishedBackend(ABackend: TSSLLibraryType);
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
begin
  if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    WriteLn('[SKIP] ', SSL_LIBRARY_NAMES[ABackend], ' backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibrary(ABackend);
  Require(LLib <> nil, SSL_LIBRARY_NAMES[ABackend] + ' library should be creatable when available');
  Require(not LLib.GetCapabilities.SupportsCustomCipherSuites,
    SSL_LIBRARY_NAMES[ABackend] + ' must publish SupportsCustomCipherSuites=False for this contract');

  LCtx := LLib.CreateContext(sslCtxClient);
  Require(LCtx <> nil, SSL_LIBRARY_NAMES[ABackend] + ' context should be creatable');

  LCtx.SetCipherList('');
  LCtx.SetCipherSuites('');
  LCtx.SetCipherList(SSL_DEFAULT_CIPHER_LIST);
  LCtx.SetCipherSuites(SSL_DEFAULT_TLS13_CIPHERSUITES);
  Require(LCtx.GetCipherList = SSL_DEFAULT_CIPHER_LIST,
    SSL_LIBRARY_NAMES[ABackend] + ' should keep shipped cipher-list baseline as compatibility/default-context path');
  Require(LCtx.GetCipherSuites = SSL_DEFAULT_TLS13_CIPHERSUITES,
    SSL_LIBRARY_NAMES[ABackend] + ' should keep shipped cipher-suites baseline as compatibility/default-context path');

  ExpectUnsupportedSetCipherList(LCtx, ABackend, CUSTOM_CIPHER_LIST,
    'custom cipher-list override');
  ExpectUnsupportedSetCipherSuites(LCtx, ABackend, CUSTOM_CIPHER_SUITES,
    'custom cipher-suites override');

  WriteLn('[PASS] ', SSL_LIBRARY_NAMES[ABackend],
    ' unpublished custom-cipher setters keep shipped baselines and reject custom non-default overrides');
end;

procedure CheckFactoryRejectsCustomCipherOverride(ABackend: TSSLLibraryType);
var
  LLib: ISSLLibrary;
  LConfig: TSSLConfig;
  LCtx: ISSLContext;
  LRejected: Boolean;
begin
  if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    WriteLn('[SKIP] ', SSL_LIBRARY_NAMES[ABackend], ' backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibrary(ABackend);
  Require(LLib <> nil, SSL_LIBRARY_NAMES[ABackend] + ' library should be creatable when available');
  LConfig := LLib.GetDefaultConfig;
  LConfig.LibraryType := ABackend;
  LConfig.ContextType := sslCtxClient;
  LConfig.CipherList := CUSTOM_CIPHER_LIST;

  LRejected := False;
  try
    LCtx := TSSLFactory.CreateContext(LConfig);
    LCtx := nil;
  except
    on E: ESSLException do
    begin
      Require(IsUnsupportedCustomCipherMessage(E.Message),
        Format('%s factory custom-cipher rejection must report unsupported semantics: %s',
          [SSL_LIBRARY_NAMES[ABackend], E.Message]));
      LRejected := True;
    end;
  end;

  Require(LRejected,
    SSL_LIBRARY_NAMES[ABackend] + ' factory CreateContext must reject custom non-default cipher config while SupportsCustomCipherSuites=False');

  WriteLn('[PASS] ', SSL_LIBRARY_NAMES[ABackend],
    ' factory CreateContext rejects custom non-default cipher config while capability is unpublished');
end;

procedure CheckDirectLibraryRejectsCustomDefaultConfig(ABackend: TSSLLibraryType);
var
  LLib: ISSLLibrary;
  LOriginalConfig: TSSLConfig;
  LConfig: TSSLConfig;
  LCtx: ISSLContext;
  LRejected: Boolean;
begin
  if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    WriteLn('[SKIP] ', SSL_LIBRARY_NAMES[ABackend], ' backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibrary(ABackend);
  Require(LLib <> nil, SSL_LIBRARY_NAMES[ABackend] + ' library should be creatable when available');
  LOriginalConfig := LLib.GetDefaultConfig;
  LConfig := LOriginalConfig;
  LConfig.CipherSuites := CUSTOM_CIPHER_SUITES;
  LLib.SetDefaultConfig(LConfig);
  try
    LRejected := False;
    try
      LCtx := LLib.CreateContext(sslCtxClient);
      LCtx := nil;
    except
      on E: ESSLException do
      begin
        Require(IsUnsupportedCustomCipherMessage(E.Message),
          Format('%s direct-library custom default-config rejection must report unsupported semantics: %s',
            [SSL_LIBRARY_NAMES[ABackend], E.Message]));
        LRejected := True;
      end;
    end;

    Require(LRejected,
      SSL_LIBRARY_NAMES[ABackend] + ' direct-library CreateContext must reject custom non-default default-config ciphers while capability is unpublished');
  finally
    LLib.SetDefaultConfig(LOriginalConfig);
  end;

  WriteLn('[PASS] ', SSL_LIBRARY_NAMES[ABackend],
    ' direct-library default-config path rejects custom non-default cipher overrides while capability is unpublished');
end;

procedure CheckOpenSSLIncompleteSurfaceFailsClosed;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LCaps: TSSLBackendCapabilities;
  LOrigSetCipherSuites: TSSL_CTX_set_ciphersuites;
begin
  if not TSSLFactory.IsLibraryAvailable(sslOpenSSL) then
  begin
    WriteLn('[SKIP] OpenSSL backend not available on this platform');
    Exit;
  end;

  LLib := TOpenSSLLibrary.Create as ISSLLibrary;
  Require(LLib.Initialize,
    'OpenSSL probe library should initialize for custom-cipher runtime gate contract');

  LOrigSetCipherSuites := SSL_CTX_set_ciphersuites;
  if not Assigned(LOrigSetCipherSuites) then
  begin
    WriteLn('[SKIP] OpenSSL build does not export SSL_CTX_set_ciphersuites');
    Exit;
  end;

  SSL_CTX_set_ciphersuites := nil;
  try
    LCaps := LLib.GetCapabilities;
    Require(not LCaps.SupportsCustomCipherSuites,
      'OpenSSL must stop publishing SupportsCustomCipherSuites when the TLS 1.3 cipher helper is missing');

    LCtx := LLib.CreateContext(sslCtxClient);
    Require(LCtx <> nil,
      'OpenSSL context should still be creatable on the incomplete helper path so default baseline compatibility remains intact');

    LCtx.SetCipherList(SSL_DEFAULT_CIPHER_LIST);
    LCtx.SetCipherSuites(SSL_DEFAULT_TLS13_CIPHERSUITES);

    ExpectUnsupportedSetCipherList(LCtx, sslOpenSSL, CUSTOM_CIPHER_LIST,
      'custom cipher-list override');
    ExpectUnsupportedSetCipherSuites(LCtx, sslOpenSSL, CUSTOM_CIPHER_SUITES,
      'custom cipher-suites override');
  finally
    SSL_CTX_set_ciphersuites := LOrigSetCipherSuites;
  end;

  WriteLn('[PASS] OpenSSL incomplete custom-cipher helper surface falls back to fail-closed capability truth');
end;

begin
  WriteLn('Testing custom cipher capability truth contract');
  WriteLn('=============================================');

  CheckOpenSSLBackendCapability;
  CheckBackendCapability(sslFreePascal, False);
  CheckBackendCapability(sslWinSSL, False);
  CheckBackendCapability(sslMbedTLS, False);
  CheckBackendCapability(sslWolfSSL, False);

  CheckPublishedOpenSSLBackend;
  CheckUnpublishedBackend(sslFreePascal);
  CheckUnpublishedBackend(sslWinSSL);
  CheckUnpublishedBackend(sslMbedTLS);
  CheckUnpublishedBackend(sslWolfSSL);

  CheckFactoryRejectsCustomCipherOverride(sslFreePascal);
  CheckFactoryRejectsCustomCipherOverride(sslWinSSL);
  CheckFactoryRejectsCustomCipherOverride(sslMbedTLS);
  CheckFactoryRejectsCustomCipherOverride(sslWolfSSL);

  CheckDirectLibraryRejectsCustomDefaultConfig(sslFreePascal);
  CheckDirectLibraryRejectsCustomDefaultConfig(sslWinSSL);
  CheckDirectLibraryRejectsCustomDefaultConfig(sslMbedTLS);
  CheckDirectLibraryRejectsCustomDefaultConfig(sslWolfSSL);

  CheckOpenSSLIncompleteSurfaceFailsClosed;

  WriteLn('=============================================');
  WriteLn('✅ custom cipher capability truth contract verified');
end.
