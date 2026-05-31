program test_wolfssl_connection_session_reused_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes, ctypes,
  nextpas.core.tls.base,
  nextpas.core.tls.wolfssl.base,
  nextpas.core.tls.wolfssl.api,
  nextpas.core.tls.wolfssl.lib,
  nextpas.core.tls.wolfssl.session,
  nextpas.core.tls.wolfssl.connection;

const
  STUB_WOLFSSL_NATIVE_SESSION_ID: array[0..3] of Byte = ($89, $AB, $CD, $EF);
  STUB_WOLFSSL_NATIVE_SESSION_TIMEOUT = 4321;
  STUB_WOLFSSL_CIPHER_TLS13: AnsiString = 'TLS_AES_128_GCM_SHA256';

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GSetSessionCalls: Integer = 0;
  GLastConfiguredSession: PWOLFSSL_SESSION = nil;
  GObservedSessionReused: Integer = 0;

procedure AssertTrue(const AName: string; ACondition: Boolean;
  const ADetail: string = '');
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

function StubWolfSSLD2ISessionOk(session: PPWOLFSSL_SESSION; const pp: PPByte;
  length: Integer): PWOLFSSL_SESSION; cdecl;
begin
  if (pp = nil) or (length <= 0) then
    Exit(nil);
  GetMem(Result, 1);
  PByte(Result)^ := $A5;
end;

procedure StubWolfSSLSessionFree(session: PWOLFSSL_SESSION); cdecl;
begin
  if session <> nil then
    FreeMem(session);
end;

function StubWolfSSLSessionGetID(const sess: PWOLFSSL_SESSION;
  idLen: PCardinal): PByte; cdecl;
begin
  if Assigned(idLen) then
    idLen^ := Length(STUB_WOLFSSL_NATIVE_SESSION_ID);
  Result := @STUB_WOLFSSL_NATIVE_SESSION_ID[0];
end;

function StubWolfSSLSessionGetTime(const session: PWOLFSSL_SESSION): clong; cdecl;
begin
  Result := 1700000000;
end;

function StubWolfSSLSessionGetTimeout(const session: PWOLFSSL_SESSION): clong; cdecl;
begin
  Result := STUB_WOLFSSL_NATIVE_SESSION_TIMEOUT;
end;

function StubWolfSSLSessionCipherGetNameTLS13(
  const session: PWOLFSSL_SESSION): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(STUB_WOLFSSL_CIPHER_TLS13);
end;

function FakeWolfSSLSetSession(ssl: PWOLFSSL;
  session: PWOLFSSL_SESSION): Integer; cdecl;
begin
  Inc(GSetSessionCalls);
  GLastConfiguredSession := session;
  if (ssl = nil) or (session = nil) then
    Exit(WOLFSSL_FAILURE);
  Result := WOLFSSL_SUCCESS;
end;

function FakeWolfSSLSessionReused(ssl: PWOLFSSL): Integer; cdecl;
begin
  if ssl = nil then
    Exit(0);
  Result := GObservedSessionReused;
end;

procedure TestDeserializedSessionOwnerPathKeepsConfiguredVsObservedTruth;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LResumption: ISSLSessionResumption;
  LConnInfo: ISSLConnectionInfo;
  LSession: ISSLSession;
  LNativeAccess: ISSLNativeHandleAccess;
  LNativeHandle: Pointer;
  LInfo: TSSLConnectionInfo;
  LStream: TMemoryStream;
  LOriginalD2I: TwolfSSL_d2i_SSL_SESSION;
  LOriginalSessionFree: TwolfSSL_SESSION_free;
  LOriginalSessionGetId: TwolfSSL_SESSION_get_id;
  LOriginalSessionGetTime: TwolfSSL_SESSION_get_time;
  LOriginalSessionGetTimeout: TwolfSSL_SESSION_get_timeout;
  LOriginalSessionCipherGetName: TwolfSSL_SESSION_CIPHER_get_name;
  LOriginalSetSession: TwolfSSL_set_session;
  LOriginalSessionReused: TwolfSSL_session_reused;
begin
  WriteLn;
  WriteLn('=== WolfSSL deserialized session reuse owner truth ===');

  LLib := CreateWolfSSLLibrary;
  if (LLib = nil) or (not LLib.Initialize) then
  begin
    MarkSkip('wolfssl deserialized session reuse owner truth',
      'backend failed to initialize');
    Exit;
  end;

  LCtx := LLib.CreateContext(sslCtxClient);
  if LCtx = nil then
  begin
    MarkSkip('wolfssl deserialized session reuse owner truth',
      'failed to create WolfSSL client context');
    Exit;
  end;

  LStream := TMemoryStream.Create;
  LConn := nil;
  LResumption := nil;
  LConnInfo := nil;
  LSession := nil;

  LOriginalD2I := wolfSSL_d2i_SSL_SESSION;
  LOriginalSessionFree := wolfSSL_SESSION_free;
  LOriginalSessionGetId := wolfSSL_SESSION_get_id;
  LOriginalSessionGetTime := wolfSSL_SESSION_get_time;
  LOriginalSessionGetTimeout := wolfSSL_SESSION_get_timeout;
  LOriginalSessionCipherGetName := wolfSSL_SESSION_CIPHER_get_name;
  LOriginalSetSession := wolfSSL_set_session;
  LOriginalSessionReused := wolfSSL_session_reused;
  try
    LConn := TWolfSSLConnection.Create(LCtx, LStream);
    AssertTrue('WolfSSL connection exposes ISSLSessionResumption owner path',
      Supports(LConn, ISSLSessionResumption, LResumption));
    AssertTrue('WolfSSL connection exposes ISSLConnectionInfo owner path',
      Supports(LConn, ISSLConnectionInfo, LConnInfo));

    wolfSSL_d2i_SSL_SESSION := @StubWolfSSLD2ISessionOk;
    wolfSSL_SESSION_free := @StubWolfSSLSessionFree;
    wolfSSL_SESSION_get_id := @StubWolfSSLSessionGetID;
    wolfSSL_SESSION_get_time := @StubWolfSSLSessionGetTime;
    wolfSSL_SESSION_get_timeout := @StubWolfSSLSessionGetTimeout;
    wolfSSL_SESSION_CIPHER_get_name := @StubWolfSSLSessionCipherGetNameTLS13;
    wolfSSL_set_session := @FakeWolfSSLSetSession;
    wolfSSL_session_reused := @FakeWolfSSLSessionReused;

    LSession := TWolfSSLSession.Create;
    AssertTrue('real WolfSSL session deserialize succeeds before owner-path injection proof',
      LSession.Deserialize(TBytes.Create(8, 7, 6, 5)));
    AssertTrue('deserialized WolfSSL session preserves native session id truth',
      LSession.GetID = '89ABCDEF');
    AssertTrue('deserialized WolfSSL session preserves native timeout truth',
      LSession.GetTimeout = STUB_WOLFSSL_NATIVE_SESSION_TIMEOUT);
    AssertTrue('deserialized WolfSSL session preserves native cipher truth',
      LSession.GetCipherName = string(STUB_WOLFSSL_CIPHER_TLS13));
    AssertTrue('deserialized WolfSSL session keeps a native handle',
      Supports(LSession, ISSLNativeHandleAccess, LNativeAccess) and
      (LNativeAccess.GetNativeHandle <> nil),
      'expected TWolfSSLSession.Deserialize to materialize a native session handle');

    LNativeHandle := nil;
    if Supports(LSession, ISSLNativeHandleAccess, LNativeAccess) then
      LNativeHandle := LNativeAccess.GetNativeHandle;

    GSetSessionCalls := 0;
    GLastConfiguredSession := nil;
    GObservedSessionReused := 0;

    LResumption.SetSession(LSession);

    AssertTrue('owner SetSession injects the deserialized WolfSSL native session handle',
      (GSetSessionCalls = 1) and (Pointer(GLastConfiguredSession) = LNativeHandle),
      Format('calls=%d configured=%p expected=%p',
        [GSetSessionCalls, Pointer(GLastConfiguredSession), LNativeHandle]));
    AssertTrue('configured deserialized session is not immediately reported as observed reuse',
      not LResumption.IsSessionReused);

    LInfo := LConnInfo.GetConnectionInfo;
    AssertTrue('connection info keeps IsResumed=False before observed native reuse',
      not LInfo.IsResumed);

    GObservedSessionReused := 1;

    AssertTrue('owner IsSessionReused reads native wolfSSL_session_reused truth',
      LResumption.IsSessionReused);

    LInfo := LConnInfo.GetConnectionInfo;
    AssertTrue('connection info IsResumed mirrors owner reuse truth after native hit',
      LInfo.IsResumed);
  finally
    LConnInfo := nil;
    LResumption := nil;
    LConn := nil;
    LSession := nil;
    LCtx := nil;
    wolfSSL_d2i_SSL_SESSION := LOriginalD2I;
    wolfSSL_SESSION_free := LOriginalSessionFree;
    wolfSSL_SESSION_get_id := LOriginalSessionGetId;
    wolfSSL_SESSION_get_time := LOriginalSessionGetTime;
    wolfSSL_SESSION_get_timeout := LOriginalSessionGetTimeout;
    wolfSSL_SESSION_CIPHER_get_name := LOriginalSessionCipherGetName;
    wolfSSL_set_session := LOriginalSetSession;
    wolfSSL_session_reused := LOriginalSessionReused;

    if LLib <> nil then
      LLib.Finalize;
    LStream.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('WolfSSL Connection Session Reused Contract Test');
  WriteLn('========================================');

  try
    TestDeserializedSessionOwnerPathKeepsConfiguredVsObservedTruth;

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
