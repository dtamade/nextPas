program test_openssl_connection_cipher_name_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.connection;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;

procedure AssertTrue(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  Inc(TotalTests);
  if ACondition then
  begin
    Inc(PassedTests);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
  end;
end;

procedure MarkSkip(const AName, AReason: string);
begin
  Inc(TotalTests);
  Inc(SkippedTests);
  WriteLn('[SKIP] [capability] ', AName, ' - ', AReason);
end;

function StubSSLGetCurrentCipherNonNil(const ssl: PSSL): PSSL_CIPHER; cdecl;
begin
  Result := PSSL_CIPHER(Pointer(PtrUInt(1)));
end;

procedure WarmupStreamConnectionConstructor(AContext: ISSLContext);
var
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
begin
  LStream := TMemoryStream.Create;
  LConn := nil;
  try
    LConn := TOpenSSLConnection.Create(AContext, LStream);
    if LConn = nil then
      raise Exception.Create('stream connection constructor warmup returned nil');
  finally
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
  end;
end;

procedure AssertCipherNameSafeDegrade(const AName: string; AContext: ISSLContext);
var
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
  LRaised: Boolean;
  LResult: string;
  LDetail: string;
begin
  LStream := TMemoryStream.Create;
  LConn := nil;
  try
    LConn := TOpenSSLConnection.Create(AContext, LStream);

    LRaised := False;
    LResult := 'unexpected';
    LDetail := '';
    try
      LResult := LConn.GetCipherName;
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
    AssertTrue(AName + ' should return empty string', LResult = '',
      'expected GetCipherName to preserve its empty-string contract');
  finally
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
  end;
end;

procedure TestGetCipherNameShouldDegradeSafelyWhenCipherHelpersAreUnavailable;
var
  LContext: ISSLContext;
  LOriginalSSLGetCurrentCipher: TSSL_get_current_cipher;
  LOriginalSSLCipherGetName: TSSL_CIPHER_get_name;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection cipher name guard ===');

  if (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_bio)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) then
  begin
    MarkSkip('openssl connection cipher name contract',
      'required baseline OpenSSL SSL/BIO helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupStreamConnectionConstructor(LContext);

  LOriginalSSLGetCurrentCipher := SSL_get_current_cipher;
  LOriginalSSLCipherGetName := SSL_CIPHER_get_name;
  try
    SSL_get_current_cipher := nil;
    SSL_CIPHER_get_name := LOriginalSSLCipherGetName;
    AssertCipherNameSafeDegrade(
      'GetCipherName when SSL_get_current_cipher is unavailable',
      LContext
    );

    SSL_get_current_cipher := @StubSSLGetCurrentCipherNonNil;
    SSL_CIPHER_get_name := nil;
    AssertCipherNameSafeDegrade(
      'GetCipherName when SSL_CIPHER_get_name is unavailable',
      LContext
    );
  finally
    SSL_get_current_cipher := LOriginalSSLGetCurrentCipher;
    SSL_CIPHER_get_name := LOriginalSSLCipherGetName;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Cipher Name Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection cipher name contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      if not LoadOpenSSLSSL then
        raise Exception.Create('failed to load SSL support');
    end;

    if SkippedTests = 0 then
      TestGetCipherNameShouldDegradeSafelyWhenCipherHelpersAreUnavailable;

    WriteLn;
    WriteLn('========================================');
    WriteLn('Summary');
    WriteLn('========================================');
    WriteLn('Total tests: ', TotalTests);
    WriteLn('Passed: ', PassedTests);
    WriteLn('Failed: ', FailedTests);
    WriteLn('Skipped: ', SkippedTests);

    if FailedTests > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
