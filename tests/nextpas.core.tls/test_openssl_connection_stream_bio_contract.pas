program test_openssl_connection_stream_bio_contract;

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
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.connection;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GOriginalBIONew: TBIO_new = nil;
  GBIONewCallCount: Integer = 0;

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

function StubBIONewFailSecond(const AMethod: PBIO_METHOD): PBIO; cdecl;
begin
  Inc(GBIONewCallCount);
  if GBIONewCallCount = 2 then
    Exit(nil);

  if Assigned(GOriginalBIONew) then
    Result := GOriginalBIONew(AMethod)
  else
    Result := nil;
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

procedure AssertStreamConstructorControlledFailure(const AName: string; AContext: ISSLContext);
var
  LStream: TMemoryStream;
  LConn: TOpenSSLConnection;
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
begin
  LStream := TMemoryStream.Create;
  LConn := nil;
  try
    LRaised := False;
    LControlled := False;
    LDetail := '';
    try
      LConn := TOpenSSLConnection.Create(AContext, LStream);
    except
      on E: Exception do
      begin
        LRaised := True;
        LControlled := E is ESSLOutOfMemoryException;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should raise', LRaised,
      'expected stream constructor to fail');
    AssertTrue(AName + ' should raise controlled ESSLOutOfMemoryException', LControlled, LDetail);
  finally
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
  end;
end;

procedure TestStreamConstructorShouldFailGracefullyWhenCleanupBIOHelperIsUnavailable;
var
  LContext: ISSLContext;
  LOriginalBIOFree: TBIO_free;
begin
  WriteLn;
  WriteLn('=== OpenSSL connection stream BIO cleanup guard ===');

  if (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(BIO_free)) or
     (not Assigned(SSL_new)) or
     (not Assigned(SSL_set_bio)) then
  begin
    MarkSkip('openssl connection stream bio contract',
      'required baseline OpenSSL SSL/BIO helpers are unavailable');
    Exit;
  end;

  LContext := GLib.CreateContext(sslCtxClient);
  if LContext = nil then
    raise Exception.Create('failed to create OpenSSL client context');

  WarmupStreamConnectionConstructor(LContext);

  GOriginalBIONew := BIO_new;
  LOriginalBIOFree := BIO_free;
  GBIONewCallCount := 0;

  BIO_new := @StubBIONewFailSecond;
  BIO_free := nil;
  try
    AssertStreamConstructorControlledFailure(
      'Create(AContext, AStream) when BIO_free is unavailable during partial cleanup',
      LContext
    );
  finally
    BIO_new := GOriginalBIONew;
    BIO_free := LOriginalBIOFree;
    GOriginalBIONew := nil;
    GBIONewCallCount := 0;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Connection Stream BIO Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl connection stream bio contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      if not LoadOpenSSLSSL then
        raise Exception.Create('failed to load SSL support');
    end;

    if SkippedTests = 0 then
      TestStreamConstructorShouldFailGracefullyWhenCleanupBIOHelperIsUnavailable;

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
