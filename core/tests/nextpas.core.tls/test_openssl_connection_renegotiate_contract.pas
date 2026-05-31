program test_openssl_connection_renegotiate_contract;

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

function StubSSLRenegotiateSuccess(ssl: PSSL): Integer; cdecl;
begin
  Result := 1;
end;

function StubSSLDoHandshakeSuccess(ssl: PSSL): Integer; cdecl;
begin
  Result := 1;
end;

procedure WarmupStreamConnectionConstructor(AContext: ISSLContext);
var
  LStream: TMemoryStream;
  LConn: TOpenSSLConnectionAccess;
begin
  LStream := TMemoryStream.Create;
  LConn := nil;
  try
    LConn := TOpenSSLConnectionAccess.Create(AContext, LStream);
    if LConn = nil then
      raise Exception.Create('stream connection constructor warmup returned nil');
  finally
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
  end;
end;

procedure AssertRenegotiateContract(const AName: string; AContext: ISSLContext;
  AExpectedResult: Boolean);
var
  LStream: TMemoryStream;
  LConn: TOpenSSLConnectionAccess;
  LRaised: Boolean;
  LResult: Boolean;
  LDetail: string;
begin
  LStream := TMemoryStream.Create;
  LConn := nil;
  try
    LConn := TOpenSSLConnectionAccess.Create(AContext, LStream);
    LConn.ForceConnectedState;

    LRaised := False;
    LResult := not AExpectedResult;
    LDetail := '';
    try
      LResult := LConn.Renegotiate;
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
    AssertTrue(AName + ' should return ' + BoolToStr(AExpectedResult, True),
      LResult = AExpectedResult,
      'expected Renegotiate to return ' + BoolToStr(AExpectedResult, True));
  finally
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
  end;
end;

procedure TestRenegotiateShouldFailGracefullyWhenHandshakeHelperIsUnavailable;
var
  LContext: ISSLContext;
  LOriginalSSLRenegotiate: TSSL_renegotiate;
  LOriginalSSLDoHandshake: TSSL_do_handshake;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection renegotiate handshake guard ===');

  if (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_bio)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) then
  begin
    MarkSkip('openssl connection renegotiate contract',
      'required baseline OpenSSL SSL/BIO helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupStreamConnectionConstructor(LContext);

  LOriginalSSLRenegotiate := SSL_renegotiate;
  LOriginalSSLDoHandshake := SSL_do_handshake;
  try
    SSL_renegotiate := @StubSSLRenegotiateSuccess;
    SSL_do_handshake := @StubSSLDoHandshakeSuccess;
    AssertRenegotiateContract(
      'Renegotiate baseline when renegotiate and handshake helpers succeed',
      LContext,
      True
    );

    SSL_renegotiate := @StubSSLRenegotiateSuccess;
    SSL_do_handshake := nil;
    AssertRenegotiateContract(
      'Renegotiate when SSL_do_handshake is unavailable after SSL_renegotiate succeeds',
      LContext,
      False
    );
  finally
    SSL_renegotiate := LOriginalSSLRenegotiate;
    SSL_do_handshake := LOriginalSSLDoHandshake;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Renegotiate Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection renegotiate contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      if not LoadOpenSSLSSL then
        raise Exception.Create('failed to load SSL support');
    end;

    if SkippedTests = 0 then
      TestRenegotiateShouldFailGracefullyWhenHandshakeHelperIsUnavailable;

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
