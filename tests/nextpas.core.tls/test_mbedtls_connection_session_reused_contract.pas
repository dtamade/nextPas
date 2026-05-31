program test_mbedtls_connection_session_reused_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.base,
  nextpas.core.tls.mbedtls.api,
  nextpas.core.tls.mbedtls.session,
  nextpas.core.tls.mbedtls.connection;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  GSetSessionCalls: Integer = 0;

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

function FakeMbedTLSSSLSetSession(ssl: Pmbedtls_ssl_context;
  session: Pmbedtls_ssl_session): Integer; cdecl;
begin
  Inc(GSetSessionCalls);
  if (ssl = nil) or (session = nil) then
    Exit(-1);
  Result := 0;
end;

function FakeMbedTLSSessionLoadOk(session: Pmbedtls_ssl_session;
  const buf: PByte; len: NativeUInt): Integer; cdecl;
begin
  if (session = nil) or (buf = nil) or (len = 0) then
    Exit(-1);
  Result := 0;
end;

procedure TestSetSessionMustNotPreclaimResumedHandshake;
var
  LConn: ISSLConnection;
  LResumption: ISSLSessionResumption;
  LStream: TMemoryStream;
  LSession: ISSLSession;
  LNativeAccess: ISSLNativeHandleAccess;
  LOriginalSSLInit: Tmbedtls_ssl_init;
  LOriginalSSLFree: Tmbedtls_ssl_free;
  LOriginalSSLSetup: Tmbedtls_ssl_setup;
  LOriginalSSLSetBio: Tmbedtls_ssl_set_bio;
  LOriginalSSLSetSession: Tmbedtls_ssl_set_session;
  LOriginalSessionLoad: Tmbedtls_ssl_session_load;
  LOriginalSessionFree: Tmbedtls_ssl_session_free;
begin
  WriteLn;
  WriteLn('=== MbedTLS session reused semantic truth ===');

  LOriginalSSLInit := mbedtls_ssl_init;
  LOriginalSSLFree := mbedtls_ssl_free;
  LOriginalSSLSetup := mbedtls_ssl_setup;
  LOriginalSSLSetBio := mbedtls_ssl_set_bio;
  LOriginalSSLSetSession := mbedtls_ssl_set_session;
  LOriginalSessionLoad := mbedtls_ssl_session_load;
  LOriginalSessionFree := mbedtls_ssl_session_free;

  mbedtls_ssl_init := nil;
  mbedtls_ssl_free := nil;
  mbedtls_ssl_setup := nil;
  mbedtls_ssl_set_bio := nil;
  mbedtls_ssl_set_session := @FakeMbedTLSSSLSetSession;
  mbedtls_ssl_session_load := @FakeMbedTLSSessionLoadOk;
  mbedtls_ssl_session_free := nil;
  GSetSessionCalls := 0;

  LStream := TMemoryStream.Create;
  try
    LConn := TMbedTLSConnection.Create(nil, nil, LStream) as ISSLConnection;
    LSession := TMbedTLSSession.Create;
    AssertTrue('connection exposes ISSLSessionResumption owner path',
      Supports(LConn, ISSLSessionResumption, LResumption));
    AssertTrue('deserialized real MbedTLS session is available for injection proof',
      LSession.Deserialize(TBytes.Create(1, 2, 3, 4)));
    AssertTrue('deserialized real MbedTLS session keeps a native handle',
      Supports(LSession, ISSLNativeHandleAccess, LNativeAccess) and
      (LNativeAccess.GetNativeHandle <> nil),
      'expected the deserialized TMbedTLSSession to retain a native session handle');

    AssertTrue('fresh connection starts with IsSessionReused=False',
      not LResumption.IsSessionReused);

    LResumption.SetSession(LSession);

    AssertTrue('SetSession still attempts native mbedtls_ssl_set_session when helper exists',
      GSetSessionCalls = 1,
      'expected fake mbedtls_ssl_set_session to be called exactly once');
    AssertTrue('SetSession must not claim a resumed handshake before Connect/DoHandshake',
      not LResumption.IsSessionReused,
      'configured session should not be reported as an actually reused handshake');
  finally
    LResumption := nil;
    LConn := nil;
    LStream.Free;
    mbedtls_ssl_init := LOriginalSSLInit;
    mbedtls_ssl_free := LOriginalSSLFree;
    mbedtls_ssl_setup := LOriginalSSLSetup;
    mbedtls_ssl_set_bio := LOriginalSSLSetBio;
    mbedtls_ssl_set_session := LOriginalSSLSetSession;
    mbedtls_ssl_session_load := LOriginalSessionLoad;
    mbedtls_ssl_session_free := LOriginalSessionFree;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('MbedTLS Connection Session Reused Contract Test');
  WriteLn('========================================');

  try
    TestSetSessionMustNotPreclaimResumedHandshake;

    WriteLn;
    WriteLn('========================================');
    WriteLn('Summary');
    WriteLn('========================================');
    WriteLn('Total tests: ', TotalTests);
    WriteLn('Passed: ', PassedTests);
    WriteLn('Failed: ', FailedTests);

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
