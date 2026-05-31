program test_openssl_connection_socket_constructor_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ssl;

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

procedure WarmupSocketConnectionConstructor(AContext: ISSLContext);
var
  LConn: ISSLConnection;
begin
  LConn := AContext.CreateConnection(THandle(0));
  if LConn = nil then
    raise Exception.Create('socket CreateConnection warmup returned nil');
end;

procedure AssertSocketConstructorControlledFailure(
  const AName, AExpectedHelper: string;
  AContext: ISSLContext
);
var
  LConn: ISSLConnection;
  LRaised: Boolean;
  LControlled: Boolean;
  LWasAccessViolation: Boolean;
  LFunctionNotFound: Boolean;
  LMentionsExpectedHelper: Boolean;
  LMentionsAccessViolation: Boolean;
  LDetail: string;
begin
  LConn := nil;
  LRaised := False;
  LControlled := False;
  LWasAccessViolation := False;
  LFunctionNotFound := False;
  LMentionsExpectedHelper := False;
  LMentionsAccessViolation := False;
  LDetail := '';
  try
    LConn := AContext.CreateConnection(THandle(0));
  except
    on E: Exception do
    begin
      LRaised := True;
      LControlled := E is ESSLException;
      LWasAccessViolation := E is EAccessViolation;
      LDetail := E.ClassName + ': ' + E.Message;
      LMentionsExpectedHelper := Pos(AExpectedHelper, LDetail) > 0;
      LMentionsAccessViolation := Pos('Access violation', LDetail) > 0;
      if E is ESSLException then
        LFunctionNotFound := ESSLException(E).ErrorCode = sslErrFunctionNotFound;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised,
    'expected CreateConnection(THandle(0)) to fail');
  AssertTrue(AName + ' should raise controlled ESSLException', LControlled, LDetail);
  AssertTrue(AName + ' should not raise EAccessViolation', not LWasAccessViolation, LDetail);
  AssertTrue(AName + ' should report sslErrFunctionNotFound', LFunctionNotFound, LDetail);
  AssertTrue(AName + ' should mention the missing helper', LMentionsExpectedHelper, LDetail);
  AssertTrue(AName + ' should not surface raw access violation text',
    not LMentionsAccessViolation, LDetail);
end;

procedure TestSocketConstructorShouldRaiseControlledExceptionWhenHelpersAreUnavailable;
var
  LContext: ISSLContext;
  LOriginalSSLNew: TSSL_new;
  LOriginalSSLSetFD: TSSL_set_fd;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection socket constructor guard ===');

  if (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_fd)) then
  begin
    MarkSkip('openssl connection socket constructor contract',
      'required baseline OpenSSL constructor helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupSocketConnectionConstructor(LContext);

  LOriginalSSLNew := SSL_new;
  LOriginalSSLSetFD := SSL_set_fd;
  try
    SSL_new := nil;
    SSL_set_fd := LOriginalSSLSetFD;
    AssertSocketConstructorControlledFailure(
      'CreateConnection when SSL_new is unavailable',
      'SSL_new',
      LContext
    );

    SSL_new := LOriginalSSLNew;
    SSL_set_fd := nil;
    AssertSocketConstructorControlledFailure(
      'CreateConnection when SSL_set_fd is unavailable',
      'SSL_set_fd',
      LContext
    );
  finally
    SSL_new := LOriginalSSLNew;
    SSL_set_fd := LOriginalSSLSetFD;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Socket Constructor Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection socket constructor contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      if not LoadOpenSSLSSL then
        raise Exception.Create('failed to load SSL support');
    end;

    if SkippedTests = 0 then
      TestSocketConstructorShouldRaiseControlledExceptionWhenHelpersAreUnavailable;

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
