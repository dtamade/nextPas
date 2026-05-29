program test_openssl_connection_stream_handshake_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.consts,
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

function StubSSLDoHandshakeWantRead(ssl: PSSL): Integer; cdecl;
begin
  Result := -1;
end;

function StubSSLGetErrorWantRead(const ssl: PSSL; ret: Integer): Integer; cdecl;
begin
  Result := SSL_ERROR_WANT_READ;
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

procedure AssertStreamConnectSafeDegrade(const AName: string; AContext: ISSLContext);
var
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
  LRaised: Boolean;
  LDetail: string;
  LResult: Boolean;
begin
  LStream := TMemoryStream.Create;
  LConn := nil;
  try
    LConn := TOpenSSLConnection.Create(AContext, LStream);

    LRaised := False;
    LDetail := '';
    LResult := True;
    try
      LResult := LConn.Connect;
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
    AssertTrue(AName + ' should return False', not LResult,
      'expected Connect to return False');
  finally
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
  end;
end;

procedure TestStreamConnectShouldFailGracefullyWhenHandshakeHelpersAreUnavailable;
var
  LContext: ISSLContext;
  LOriginalSSLDoHandshake: TSSL_do_handshake;
  LOriginalSSLGetError: TSSL_get_error;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection stream handshake guard ===');

  if (not Assigned(SSL_do_handshake)) or
     (not Assigned(SSL_get_error)) then
  begin
    MarkSkip('openssl connection stream handshake contract',
      'required baseline OpenSSL handshake helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupStreamConnectionConstructor(LContext);

  LOriginalSSLDoHandshake := SSL_do_handshake;
  LOriginalSSLGetError := SSL_get_error;

  try
    SSL_do_handshake := @StubSSLDoHandshakeWantRead;
    SSL_get_error := @StubSSLGetErrorWantRead;
    AssertStreamConnectSafeDegrade(
      'Connect baseline when handshake reports WANT_READ on empty stream',
      LContext
    );

    SSL_do_handshake := nil;
    SSL_get_error := LOriginalSSLGetError;
    AssertStreamConnectSafeDegrade(
      'Connect when SSL_do_handshake is unavailable',
      LContext
    );

    SSL_do_handshake := @StubSSLDoHandshakeWantRead;
    SSL_get_error := nil;
    AssertStreamConnectSafeDegrade(
      'Connect when SSL_get_error is unavailable',
      LContext
    );
  finally
    SSL_do_handshake := LOriginalSSLDoHandshake;
    SSL_get_error := LOriginalSSLGetError;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Stream Handshake Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection stream handshake contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      if not LoadOpenSSLSSL then
        raise Exception.Create('failed to load SSL support');
    end;

    if SkippedTests = 0 then
      TestStreamConnectShouldFailGracefullyWhenHandshakeHelpersAreUnavailable;

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
