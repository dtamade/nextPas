program test_openssl_connection_accept_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.consts,
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

function StubSSLAcceptFail(ssl: PSSL): Integer; cdecl;
begin
  Result := -1;
end;

function StubSSLGetErrorGenericFailure(const ssl: PSSL; ret: Integer): Integer; cdecl;
begin
  Result := SSL_ERROR_SSL;
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

procedure AssertSocketAcceptSafeDegrade(const AName: string; AContext: ISSLContext);
var
  LConn: TOpenSSLConnection;
  LRaised: Boolean;
  LResult: Boolean;
  LDetail: string;
begin
  LConn := nil;
  try
    LConn := TOpenSSLConnection.Create(AContext, THandle(0));

    LRaised := False;
    LResult := True;
    LDetail := '';
    try
      LResult := LConn.Accept;
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
    AssertTrue(AName + ' should return False', not LResult,
      'expected Accept to return False');
  finally
    if Assigned(LConn) then
      LConn.Free;
  end;
end;

procedure TestSocketAcceptShouldFailGracefullyWhenHelpersAreUnavailable;
var
  LContext: ISSLContext;
  LOriginalSSLAccept: TSSL_accept;
  LOriginalSSLGetError: TSSL_get_error;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection accept guard ===');

  if (not Assigned(SSL_accept)) or
     (not Assigned(SSL_get_error)) or
     (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_fd)) then
  begin
    MarkSkip('openssl connection accept contract',
      'required baseline OpenSSL SSL helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxServer);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL server context');

  WarmupSocketConnectionConstructor(LContext);

  LOriginalSSLAccept := SSL_accept;
  LOriginalSSLGetError := SSL_get_error;
  try
    SSL_accept := @StubSSLAcceptFail;
    SSL_get_error := @StubSSLGetErrorGenericFailure;
    AssertSocketAcceptSafeDegrade(
      'Accept baseline when SSL_accept fails',
      LContext
    );

    SSL_accept := nil;
    SSL_get_error := LOriginalSSLGetError;
    AssertSocketAcceptSafeDegrade(
      'Accept when SSL_accept is unavailable',
      LContext
    );

    SSL_accept := @StubSSLAcceptFail;
    SSL_get_error := nil;
    AssertSocketAcceptSafeDegrade(
      'Accept when SSL_get_error is unavailable on failure path',
      LContext
    );
  finally
    SSL_accept := LOriginalSSLAccept;
    SSL_get_error := LOriginalSSLGetError;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Accept Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection accept contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      if not LoadOpenSSLSSL then
        raise Exception.Create('failed to load SSL support');
    end;

    if SkippedTests = 0 then
      TestSocketAcceptShouldFailGracefullyWhenHelpersAreUnavailable;

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
