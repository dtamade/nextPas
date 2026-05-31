program test_openssl_connection_destroy_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
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

procedure ReleaseConnection(var AConn: TOpenSSLConnection);
var
  LConn: TOpenSSLConnection;
begin
  LConn := AConn;
  AConn := nil;
  if Assigned(LConn) then
    LConn.Free;
end;

procedure WarmupSocketConnectionConstructor(AContext: ISSLContext);
var
  LConn: TOpenSSLConnection;
begin
  LConn := nil;
  try
    LConn := TOpenSSLConnection.Create(AContext, THandle(0));
    if LConn = nil then
      raise Exception.Create('socket connection constructor warmup returned nil');
  finally
    if Assigned(LConn) then
      LConn.Free;
  end;
end;

procedure TestDestroyShouldRemainSafeWhenSSLFreeHelperIsUnavailable;
var
  LContext: ISSLContext;
  LConn: TOpenSSLConnection;
  LOriginalSSLFree: TSSL_free;
  LRaised: Boolean;
  LDetail: string;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection destroy guard ===');

  if (not Assigned(SSL_free)) or
     (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_fd)) then
  begin
    MarkSkip('openssl connection destroy contract',
      'required baseline OpenSSL SSL helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupSocketConnectionConstructor(LContext);

  LConn := TOpenSSLConnection.Create(LContext, THandle(0));
  LOriginalSSLFree := SSL_free;
  try
    LRaised := False;
    LDetail := '';

    SSL_free := nil;
    try
      try
        ReleaseConnection(LConn);
      except
        on E: Exception do
        begin
          LRaised := True;
          LDetail := E.ClassName + ': ' + E.Message;
        end;
      end;
    finally
      SSL_free := LOriginalSSLFree;
    end;

    AssertTrue('Destroy when SSL_free is unavailable should not raise',
      not LRaised, LDetail);
  finally
    if Assigned(LConn) then
      LConn.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Destroy Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection destroy contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      if not LoadOpenSSLSSL then
        raise Exception.Create('failed to load SSL support');
    end;

    if SkippedTests = 0 then
      TestDestroyShouldRemainSafeWhenSSLFreeHelperIsUnavailable;

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
