program test_openssl_connection_protocol_version_contract;

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

procedure TestGetProtocolVersionShouldDegradeSafelyWhenSSLVersionHelperIsUnavailable;
var
  LContext: ISSLContext;
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
  LOriginalSSLVersion: TSSL_version;
  LRaised: Boolean;
  LResult: TSSLProtocolVersion;
  LDetail: string;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection protocol version guard ===');

  if (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_bio)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) then
  begin
    MarkSkip('openssl connection protocol version contract',
      'required baseline OpenSSL SSL/BIO helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupStreamConnectionConstructor(LContext);

  LStream := TMemoryStream.Create;
  LConn := nil;
  LOriginalSSLVersion := SSL_version;
  try
    LConn := TOpenSSLConnection.Create(LContext, LStream);

    LRaised := False;
    LResult := sslProtocolSSL2;
    LDetail := '';

    SSL_version := nil;
    try
      try
        LResult := LConn.GetProtocolVersion;
      except
        on E: Exception do
        begin
          LRaised := True;
          LDetail := E.ClassName + ': ' + E.Message;
        end;
      end;
    finally
      SSL_version := LOriginalSSLVersion;
    end;

    AssertTrue('GetProtocolVersion when SSL_version is unavailable should not raise',
      not LRaised, LDetail);
    AssertTrue('GetProtocolVersion when SSL_version is unavailable should return sslProtocolTLS12',
      LResult = sslProtocolTLS12,
      'expected GetProtocolVersion to preserve its default sslProtocolTLS12 contract');
  finally
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Protocol Version Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection protocol version contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      if not LoadOpenSSLSSL then
        raise Exception.Create('failed to load SSL support');
    end;

    if SkippedTests = 0 then
      TestGetProtocolVersionShouldDegradeSafelyWhenSSLVersionHelperIsUnavailable;

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
