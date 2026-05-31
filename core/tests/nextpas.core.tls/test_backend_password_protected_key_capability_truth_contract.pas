program test_backend_password_protected_key_capability_truth_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.exceptions,
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

const
  ENCRYPTED_PRIVATE_KEY_SENTINEL =
    '-----BEGIN ENCRYPTED PRIVATE KEY-----' + #10 +
    'contract-sentinel' + #10 +
    '-----END ENCRYPTED PRIVATE KEY-----' + #10;
  TEST_PASSWORD = 'contract-password';

procedure Require(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function IsUnsupportedPasswordMessage(const AMessage: string): Boolean;
var
  LLower: string;
begin
  LLower := LowerCase(AMessage);
  Result := (Pos('unsupported', LLower) > 0) or
    (Pos('supportspasswordprotectedkeys', LLower) > 0) or
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

  LActual := LLib.GetCapabilities.SupportsPasswordProtectedKeys;
  Require(LActual = AExpected,
    Format('%s SupportsPasswordProtectedKeys mismatch: expected=%s actual=%s',
      [SSL_LIBRARY_NAMES[ABackend], BoolToStr(AExpected, True), BoolToStr(LActual, True)]));

  WriteLn('[PASS] ', SSL_LIBRARY_NAMES[ABackend], ' SupportsPasswordProtectedKeys = ',
    BoolToStr(LActual, True));
end;

procedure ExpectUnsupportedLoadPrivateKeyFile(ACtx: ISSLContext;
  ABackend: TSSLLibraryType; const AFileName: string);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ACtx.LoadPrivateKey(AFileName, TEST_PASSWORD);
  except
    on E: ESSLException do
    begin
      Require(IsUnsupportedPasswordMessage(E.Message),
        Format('%s LoadPrivateKey(file,password) rejection must report unsupported password semantics: %s',
          [SSL_LIBRARY_NAMES[ABackend], E.Message]));
      LRejected := True;
    end;
  end;

  Require(LRejected,
    Format('%s must reject non-empty password for LoadPrivateKey(file,password) when SupportsPasswordProtectedKeys=False',
      [SSL_LIBRARY_NAMES[ABackend]]));
end;

procedure ExpectUnsupportedLoadPrivateKeyStream(ACtx: ISSLContext;
  ABackend: TSSLLibraryType; AStream: TStream);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ACtx.LoadPrivateKey(AStream, TEST_PASSWORD);
  except
    on E: ESSLException do
    begin
      Require(IsUnsupportedPasswordMessage(E.Message),
        Format('%s LoadPrivateKey(stream,password) rejection must report unsupported password semantics: %s',
          [SSL_LIBRARY_NAMES[ABackend], E.Message]));
      LRejected := True;
    end;
  end;

  Require(LRejected,
    Format('%s must reject non-empty password for LoadPrivateKey(stream,password) when SupportsPasswordProtectedKeys=False',
      [SSL_LIBRARY_NAMES[ABackend]]));
end;

procedure ExpectUnsupportedLoadPrivateKeyPEM(ACtx: ISSLContext;
  ABackend: TSSLLibraryType);
var
  LRejected: Boolean;
begin
  LRejected := False;
  try
    ACtx.LoadPrivateKeyPEM(ENCRYPTED_PRIVATE_KEY_SENTINEL, TEST_PASSWORD);
  except
    on E: ESSLException do
    begin
      Require(IsUnsupportedPasswordMessage(E.Message),
        Format('%s LoadPrivateKeyPEM(password) rejection must report unsupported password semantics: %s',
          [SSL_LIBRARY_NAMES[ABackend], E.Message]));
      LRejected := True;
    end;
  end;

  Require(LRejected,
    Format('%s must reject non-empty password for LoadPrivateKeyPEM(password) when SupportsPasswordProtectedKeys=False',
      [SSL_LIBRARY_NAMES[ABackend]]));
end;

procedure CheckRejectsNonEmptyPassword(ABackend: TSSLLibraryType);
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LTempDir: string;
  LTempFile: string;
  LStream: TStringStream;
begin
  if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    WriteLn('[SKIP] ', SSL_LIBRARY_NAMES[ABackend], ' backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibrary(ABackend);
  Require(LLib <> nil, SSL_LIBRARY_NAMES[ABackend] + ' library should be creatable when available');
  Require(not LLib.GetCapabilities.SupportsPasswordProtectedKeys,
    SSL_LIBRARY_NAMES[ABackend] + ' must publish SupportsPasswordProtectedKeys=False for this contract');

  LCtx := LLib.CreateContext(sslCtxClient);
  Require(LCtx <> nil, SSL_LIBRARY_NAMES[ABackend] + ' context should be creatable');

  LTempDir := IncludeTrailingPathDelimiter('tmp') +
    'test_backend_password_protected_key_capability_truth';
  ForceDirectories(LTempDir);
  LTempFile := IncludeTrailingPathDelimiter(LTempDir) +
    LowerCase(SSL_LIBRARY_NAMES[ABackend]) + '_encrypted_private_key.pem';
  LStream := TStringStream.Create(ENCRYPTED_PRIVATE_KEY_SENTINEL);
  try
    with TStringList.Create do
    try
      Text := ENCRYPTED_PRIVATE_KEY_SENTINEL;
      SaveToFile(LTempFile);
    finally
      Free;
    end;

    ExpectUnsupportedLoadPrivateKeyFile(LCtx, ABackend, LTempFile);

    LStream.Position := 0;
    ExpectUnsupportedLoadPrivateKeyStream(LCtx, ABackend, LStream);

    ExpectUnsupportedLoadPrivateKeyPEM(LCtx, ABackend);
  finally
    LStream.Free;
    if FileExists(LTempFile) then
      DeleteFile(LTempFile);
  end;

  WriteLn('[PASS] ', SSL_LIBRARY_NAMES[ABackend],
    ' rejects non-empty password on unpublished password-protected key surfaces');
end;

begin
  WriteLn('Testing password-protected key capability truth contract');
  WriteLn('=======================================================');

  CheckBackendCapability(sslFreePascal, False);
  CheckBackendCapability(sslWolfSSL, False);
  CheckBackendCapability(sslMbedTLS, True);
  CheckBackendCapability(sslWinSSL, True);

  CheckRejectsNonEmptyPassword(sslFreePascal);
  CheckRejectsNonEmptyPassword(sslWolfSSL);

  WriteLn('=======================================================');
  WriteLn('✅ password-protected key capability truth contract verified');
end.
