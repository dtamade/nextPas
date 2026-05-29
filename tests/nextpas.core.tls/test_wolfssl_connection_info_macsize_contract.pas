program test_wolfssl_connection_info_macsize_contract;

{$mode ObjFPC}{$H+}
{$DEFINE ENABLE_WOLFSSL}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.wolfssl.base,
  nextpas.core.tls.wolfssl.api,
  nextpas.core.tls.wolfssl.lib,
  nextpas.core.tls.wolfssl.connection;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GLegacyCipherName: AnsiString = 'ECDHE-RSA-AES128-SHA256';
  GTLS13CipherName: AnsiString = 'TLS_AES_128_GCM_SHA256';
  GStubHmacSize: Integer = 32;

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

function StubWolfSSLGetCurrentCipherNonNil(ssl: PWOLFSSL): Pointer; cdecl;
begin
  Result := Pointer(PtrUInt(1));
end;

function StubWolfSSLCipherGetNameLegacyNonAead(cipher: Pointer): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(GLegacyCipherName);
end;

function StubWolfSSLCipherGetNameTLS13Aead(cipher: Pointer): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(GTLS13CipherName);
end;

function StubWolfSSLGetHmacSize(ssl: PWOLFSSL): Integer; cdecl;
begin
  Result := GStubHmacSize;
end;

procedure WarmupSocketConnectionConstructor(AContext: ISSLContext);
var
  LConn: TWolfSSLConnection;
begin
  LConn := nil;
  try
    LConn := TWolfSSLConnection.Create(AContext, THandle(-1));
    if LConn = nil then
      raise Exception.Create('socket connection constructor warmup returned nil');
  finally
    if Assigned(LConn) then
      LConn.Free;
  end;
end;

function CaptureFreshConnectionInfo(AContext: ISSLContext): TSSLConnectionInfo;
var
  LConn: TWolfSSLConnection;
  LConnInfoAccess: ISSLConnectionInfo;
  LManagedByInterface: Boolean;
begin
  LConn := nil;
  LConnInfoAccess := nil;
  LManagedByInterface := False;
  try
    LConn := TWolfSSLConnection.Create(AContext, THandle(-1));
    if not Supports(LConn, ISSLConnectionInfo, LConnInfoAccess) then
      raise Exception.Create('WolfSSL connection does not expose ISSLConnectionInfo');
    LManagedByInterface := True;
    Result := LConnInfoAccess.GetConnectionInfo;
  finally
    if LManagedByInterface then
      LConn := nil
    else if Assigned(LConn) then
      LConn.Free;
    LConnInfoAccess := nil;
  end;
end;

procedure AssertConnectionInfoMacSize(
  const AName: string;
  AContext: ISSLContext;
  AExpectedMacSize: Integer
);
var
  LInfo: TSSLConnectionInfo;
begin
  LInfo := CaptureFreshConnectionInfo(AContext);
  AssertTrue(AName,
    LInfo.MacSize = AExpectedMacSize,
    Format('expected MacSize=%d but got %d', [AExpectedMacSize, LInfo.MacSize]));
end;

procedure TestGetConnectionInfoMacSizeTruth;
var
  LContext: ISSLContext;
  LOriginalGetCurrentCipher: TwolfSSL_get_current_cipher;
  LOriginalCipherGetName: TwolfSSL_CIPHER_get_name;
  LOriginalGetHmacSize: TwolfSSL_GetHmacSize;
begin
  WriteLn;
  WriteLn('=== WolfSSL connection info mac-size truth ===');

  if (not Assigned(wolfSSL_new)) or
     (not Assigned(wolfSSL_free)) or
     (not Assigned(wolfSSL_set_fd)) then
  begin
    MarkSkip('wolfssl connection info mac-size contract',
      'required baseline WolfSSL connection helpers are unavailable');
    Exit;
  end;

  LContext := TSSLFactory.CreateContext(sslCtxClient, sslWolfSSL);
  if LContext = nil then
    raise Exception.Create('failed to create WolfSSL client context');

  WarmupSocketConnectionConstructor(LContext);

  LOriginalGetCurrentCipher := wolfSSL_get_current_cipher;
  LOriginalCipherGetName := wolfSSL_CIPHER_get_name;
  LOriginalGetHmacSize := wolfSSL_GetHmacSize;
  try
    wolfSSL_get_current_cipher := @StubWolfSSLGetCurrentCipherNonNil;

    wolfSSL_CIPHER_get_name := @StubWolfSSLCipherGetNameLegacyNonAead;
    wolfSSL_GetHmacSize := nil;
    AssertConnectionInfoMacSize(
      'GetConnectionInfo should degrade safely when WolfSSL legacy MacSize helper is unavailable',
      LContext,
      0
    );

    wolfSSL_CIPHER_get_name := @StubWolfSSLCipherGetNameLegacyNonAead;
    GStubHmacSize := 32;
    wolfSSL_GetHmacSize := @StubWolfSSLGetHmacSize;
    AssertConnectionInfoMacSize(
      'GetConnectionInfo should derive legacy non-AEAD MacSize from WolfSSL HMAC truth',
      LContext,
      32
    );

    wolfSSL_CIPHER_get_name := @StubWolfSSLCipherGetNameTLS13Aead;
    GStubHmacSize := 32;
    wolfSSL_GetHmacSize := @StubWolfSSLGetHmacSize;
    AssertConnectionInfoMacSize(
      'GetConnectionInfo should keep shared AEAD MacSize when WolfSSL HMAC truth differs',
      LContext,
      16
    );
  finally
    wolfSSL_get_current_cipher := LOriginalGetCurrentCipher;
    wolfSSL_CIPHER_get_name := LOriginalCipherGetName;
    wolfSSL_GetHmacSize := LOriginalGetHmacSize;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('WolfSSL Connection Info MacSize Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslWolfSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('wolfssl connection info mac-size contract',
        'failed to initialize WolfSSL library');

    if SkippedTests = 0 then
      TestGetConnectionInfoMacSizeTruth;

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
      WriteLn;
      WriteLn('[UNEXPECTED] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
