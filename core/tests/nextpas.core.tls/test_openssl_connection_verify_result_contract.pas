program test_openssl_connection_verify_result_contract;

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

// INTENTIONAL_VERIFY_RESULT_CORE_SURFACE: this root-test backend contract
// file intentionally keeps direct core GetVerifyResult/GetVerifyResultString
// coverage as backend proof. Generic ISSLCertificateVerification owner-path
// guidance is frozen elsewhere.
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

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

procedure TestFreshConnectionShouldNotReportVerifySuccessBeforeHandshake;
var
  LContext: ISSLContext;
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
begin
  WriteLn;
  WriteLn('=== OpenSSL pre-handshake verify status ===');

  if (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_bio)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) then
  begin
    MarkSkip('openssl pre-handshake verify status contract',
      'required baseline OpenSSL SSL/BIO helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupStreamConnectionConstructor(LContext);

  LStream := TMemoryStream.Create;
  LConn := nil;
  try
    LConn := TOpenSSLConnection.Create(LContext, LStream);
    AssertTrue('Fresh OpenSSL connection should not report verify success before handshake',
      LConn.GetVerifyResult = -1,
      'expected fresh connection verify result to stay unavailable before handshake');
    AssertTrue('Fresh OpenSSL connection should surface not-verified diagnostic before handshake',
      SameText(LConn.GetVerifyResultString, 'Not verified'),
      'expected pre-handshake verify string to stay Not verified');
  finally
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
  end;
end;

procedure TestGetVerifyResultShouldDegradeSafelyWhenHelperIsUnavailable;
var
  LContext: ISSLContext;
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
  LOriginalSSLGetVerifyResult: TSSL_get_verify_result;
  LRaised: Boolean;
  LResult: Integer;
  LDetail: string;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection verify result guard ===');

  if (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_bio)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) then
  begin
    MarkSkip('openssl connection verify result contract',
      'required baseline OpenSSL SSL/BIO helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupStreamConnectionConstructor(LContext);

  LStream := TMemoryStream.Create;
  LConn := nil;
  LOriginalSSLGetVerifyResult := SSL_get_verify_result;
  try
    LConn := TOpenSSLConnection.Create(LContext, LStream);

    LRaised := False;
    LResult := 0;
    LDetail := '';

    SSL_get_verify_result := nil;
    try
      try
        LResult := LConn.GetVerifyResult;
      except
        on E: Exception do
        begin
          LRaised := True;
          LDetail := E.ClassName + ': ' + E.Message;
        end;
      end;
    finally
      SSL_get_verify_result := LOriginalSSLGetVerifyResult;
    end;

    AssertTrue('GetVerifyResult when SSL_get_verify_result is unavailable should not raise',
      not LRaised, LDetail);
    AssertTrue('GetVerifyResult when SSL_get_verify_result is unavailable should return -1',
      LResult = -1,
      'expected GetVerifyResult to preserve its -1 contract');
  finally
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Verify Result Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection verify result contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      if not LoadOpenSSLSSL then
        raise Exception.Create('failed to load SSL support');
    end;

    if SkippedTests = 0 then
      TestFreshConnectionShouldNotReportVerifySuccessBeforeHandshake;

    if SkippedTests = 0 then
      TestGetVerifyResultShouldDegradeSafelyWhenHelperIsUnavailable;

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
