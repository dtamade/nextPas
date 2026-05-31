program test_openssl_connection_read_contract;

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

type
  TOpenSSLConnectionAccess = class(TOpenSSLConnection)
  public
    procedure ForceConnectedState;
  end;

procedure TOpenSSLConnectionAccess.ForceConnectedState;
begin
  FConnected := True;
  FHandshakeComplete := True;
end;

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

function StubSSLReadFail(ssl: PSSL; buf: Pointer; num: Integer): Integer; cdecl;
begin
  Result := -1;
end;

function StubSSLGetErrorGenericFailure(const ssl: PSSL; ret: Integer): Integer; cdecl;
begin
  Result := SSL_ERROR_SSL;
end;

procedure WarmupSocketConnectionConstructor(AContext: ISSLContext);
var
  LConn: TOpenSSLConnectionAccess;
begin
  LConn := nil;
  try
    LConn := TOpenSSLConnectionAccess.Create(AContext, THandle(0));
    if LConn = nil then
      raise Exception.Create('socket connection constructor warmup returned nil');
  finally
    if Assigned(LConn) then
      LConn.Free;
  end;
end;

procedure AssertSocketReadSafeDegrade(const AName: string; AContext: ISSLContext);
var
  LConn: TOpenSSLConnectionAccess;
  LBuffer: array[0..15] of Byte;
  LRaised: Boolean;
  LResult: Integer;
  LDetail: string;
begin
  LConn := nil;
  FillChar(LBuffer, SizeOf(LBuffer), 0);
  try
    LConn := TOpenSSLConnectionAccess.Create(AContext, THandle(0));
    LConn.ForceConnectedState;

    LRaised := False;
    LResult := 0;
    LDetail := '';
    try
      LResult := LConn.Read(LBuffer[0], SizeOf(LBuffer));
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
    AssertTrue(AName + ' should return -1', LResult = -1,
      'expected Read to return -1');
  finally
    if Assigned(LConn) then
      LConn.Free;
  end;
end;

procedure TestSocketReadShouldFailGracefullyWhenHelpersAreUnavailable;
var
  LContext: ISSLContext;
  LOriginalSSLRead: TSSL_read;
  LOriginalSSLGetError: TSSL_get_error;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection read guard ===');

  if (not Assigned(SSL_read)) or
     (not Assigned(SSL_get_error)) or
     (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_fd)) then
  begin
    MarkSkip('openssl connection read contract',
      'required baseline OpenSSL SSL helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupSocketConnectionConstructor(LContext);

  LOriginalSSLRead := SSL_read;
  LOriginalSSLGetError := SSL_get_error;
  try
    SSL_read := @StubSSLReadFail;
    SSL_get_error := @StubSSLGetErrorGenericFailure;
    AssertSocketReadSafeDegrade(
      'Read baseline when SSL_read fails',
      LContext
    );

    SSL_read := nil;
    SSL_get_error := LOriginalSSLGetError;
    AssertSocketReadSafeDegrade(
      'Read when SSL_read is unavailable',
      LContext
    );

    SSL_read := @StubSSLReadFail;
    SSL_get_error := nil;
    AssertSocketReadSafeDegrade(
      'Read when SSL_get_error is unavailable on failure path',
      LContext
    );
  finally
    SSL_read := LOriginalSSLRead;
    SSL_get_error := LOriginalSSLGetError;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Read Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection read contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      if not LoadOpenSSLSSL then
        raise Exception.Create('failed to load SSL support');
    end;

    if SkippedTests = 0 then
      TestSocketReadShouldFailGracefullyWhenHelpersAreUnavailable;

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
