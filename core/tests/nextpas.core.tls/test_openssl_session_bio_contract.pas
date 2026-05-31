program test_openssl_session_bio_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.session;

var
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

function CreateTestSession: TOpenSSLSession;
var
  LSession: PSSL_SESSION;
begin
  if not Assigned(SSL_SESSION_new) then
    raise Exception.Create('SSL_SESSION_new is unavailable');

  LSession := SSL_SESSION_new();
  if LSession = nil then
    raise Exception.Create('failed to allocate SSL session');

  Result := TOpenSSLSession.Create(LSession, Assigned(SSL_SESSION_free));
end;

procedure AssertSerializeSafeDegrade(const AName: string);
var
  LSession: TOpenSSLSession;
  LRaised: Boolean;
  LDetail: string;
  LData: TBytes;
begin
  LSession := CreateTestSession;
  try
    LRaised := False;
    LDetail := '';
    SetLength(LData, 1);
    LData[0] := 42;

    try
      LData := LSession.Serialize();
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
    AssertTrue(AName + ' should return empty bytes', Length(LData) = 0,
      'expected Serialize to return empty bytes');
  finally
    LSession.Free;
  end;
end;

procedure AssertDeserializeSafeDegrade(const AName: string);
var
  LSession: TOpenSSLSession;
  LRaised: Boolean;
  LDetail: string;
  LResult: Boolean;
begin
  LSession := CreateTestSession;
  try
    LRaised := False;
    LDetail := '';
    LResult := True;

    try
      LResult := LSession.Deserialize(TBytes.Create(1, 2, 3, 4));
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
    AssertTrue(AName + ' should return False', not LResult,
      'expected Deserialize to return False');
  finally
    LSession.Free;
  end;
end;

procedure TestSessionHelpersShouldFailGracefullyWhenSessionOrBIOHelpersAreUnavailable;
var
  LOriginalSessionSerialize: Ti2d_SSL_SESSION_bio;
  LOriginalSessionDeserialize: Td2i_SSL_SESSION_bio;
  LOriginalBIONew: TBIO_new;
  LOriginalBIOSMem: TBIO_s_mem;
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalBIOFree: TBIO_free;
begin
  WriteLn;
  WriteLn('=== OpenSSL session BIO guard ===');

  LOriginalSessionSerialize := i2d_SSL_SESSION_bio;
  LOriginalSessionDeserialize := d2i_SSL_SESSION_bio;
  LOriginalBIONew := BIO_new;
  LOriginalBIOSMem := BIO_s_mem;
  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  LOriginalBIOFree := BIO_free;

  i2d_SSL_SESSION_bio := nil;
  try
    AssertSerializeSafeDegrade('Serialize when i2d_SSL_SESSION_bio is unavailable');
  finally
    i2d_SSL_SESSION_bio := LOriginalSessionSerialize;
  end;

  BIO_new := nil;
  try
    AssertSerializeSafeDegrade('Serialize when BIO_new is unavailable');
  finally
    BIO_new := LOriginalBIONew;
  end;

  BIO_s_mem := nil;
  try
    AssertSerializeSafeDegrade('Serialize when BIO_s_mem is unavailable');
  finally
    BIO_s_mem := LOriginalBIOSMem;
  end;

  BIO_free := nil;
  try
    AssertSerializeSafeDegrade('Serialize when BIO_free is unavailable');
  finally
    BIO_free := LOriginalBIOFree;
  end;

  d2i_SSL_SESSION_bio := nil;
  try
    AssertDeserializeSafeDegrade('Deserialize when d2i_SSL_SESSION_bio is unavailable');
  finally
    d2i_SSL_SESSION_bio := LOriginalSessionDeserialize;
  end;

  BIO_new_mem_buf := nil;
  try
    AssertDeserializeSafeDegrade('Deserialize when BIO_new_mem_buf is unavailable');
  finally
    BIO_new_mem_buf := LOriginalBIONewMemBuf;
  end;

  BIO_free := nil;
  try
    AssertDeserializeSafeDegrade('Deserialize when BIO_free is unavailable');
  finally
    BIO_free := LOriginalBIOFree;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Session BIO Contract Test');
  WriteLn('========================================');

  try
    try
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
    except
      on E: Exception do
      begin
        MarkSkip('openssl session bio contract',
          'failed to load OpenSSL core/BIO support: ' + E.Message);
      end;
    end;

    if (SkippedTests = 0) and
       (not Assigned(SSL_SESSION_new)) then
      MarkSkip('openssl session bio contract',
        'SSL_SESSION_new is unavailable on this runtime');

    if SkippedTests = 0 then
      TestSessionHelpersShouldFailGracefullyWhenSessionOrBIOHelpersAreUnavailable;

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
