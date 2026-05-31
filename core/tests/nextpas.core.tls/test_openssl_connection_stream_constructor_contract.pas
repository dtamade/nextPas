program test_openssl_connection_stream_constructor_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
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

procedure WarmupStreamConnectionConstructor(AContext: ISSLContext);
var
  LStream: TMemoryStream;
  LConn: ISSLConnection;
begin
  LStream := TMemoryStream.Create;
  try
    LConn := AContext.CreateConnection(LStream);
    if LConn = nil then
      raise Exception.Create('stream CreateConnection warmup returned nil');
  finally
    LStream.Free;
  end;
end;

procedure AssertStreamConstructorControlledFailure(const AName: string; AContext: ISSLContext);
var
  LStream: TMemoryStream;
  LConn: ISSLConnection;
  LRaised: Boolean;
  LControlled: Boolean;
  LWasAccessViolation: Boolean;
  LFunctionNotFound: Boolean;
  LMentionsHelper: Boolean;
  LMentionsAccessViolation: Boolean;
  LDetail: string;
begin
  LStream := TMemoryStream.Create;
  LConn := nil;
  LRaised := False;
  LControlled := False;
  LWasAccessViolation := False;
  LFunctionNotFound := False;
  LMentionsHelper := False;
  LMentionsAccessViolation := False;
  LDetail := '';
  try
    LConn := AContext.CreateConnection(LStream);
  except
    on E: Exception do
    begin
      LRaised := True;
      LControlled := E is ESSLException;
      LWasAccessViolation := E is EAccessViolation;
      LDetail := E.ClassName + ': ' + E.Message;
      LMentionsHelper := Pos('SSL_new', LDetail) > 0;
      LMentionsAccessViolation := Pos('Access violation', LDetail) > 0;
      if E is ESSLException then
        LFunctionNotFound := ESSLException(E).ErrorCode = sslErrFunctionNotFound;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised,
    'expected CreateConnection(TMemoryStream) to fail');
  AssertTrue(AName + ' should raise controlled ESSLException', LControlled, LDetail);
  AssertTrue(AName + ' should not raise EAccessViolation', not LWasAccessViolation, LDetail);
  AssertTrue(AName + ' should report sslErrFunctionNotFound', LFunctionNotFound, LDetail);
  AssertTrue(AName + ' should mention SSL_new', LMentionsHelper, LDetail);
  AssertTrue(AName + ' should not surface raw access violation text',
    not LMentionsAccessViolation, LDetail);

  LStream.Free;
end;

procedure TestStreamConstructorShouldRaiseControlledExceptionWhenSSLNewIsUnavailable;
var
  LContext: ISSLContext;
  LOriginalSSLNew: TSSL_new;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection stream constructor SSL_new guard ===');

  if (not Assigned(SSL_new)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(SSL_set_bio)) then
  begin
    MarkSkip('openssl connection stream constructor contract',
      'required baseline OpenSSL stream constructor helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupStreamConnectionConstructor(LContext);

  LOriginalSSLNew := SSL_new;
  try
    SSL_new := nil;
    AssertStreamConstructorControlledFailure(
      'CreateConnection(AStream) when SSL_new is unavailable',
      LContext
    );
  finally
    SSL_new := LOriginalSSLNew;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Stream Constructor Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection stream constructor contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      if not LoadOpenSSLSSL then
        raise Exception.Create('failed to load SSL support');
    end;

    if SkippedTests = 0 then
      TestStreamConstructorShouldRaiseControlledExceptionWhenSSLNewIsUnavailable;

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
