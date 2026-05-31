program test_ocsp_connection_verification_regression;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Dynlibs, ctypes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.connection,
  nextpas.core.tls.openssl.native_handle,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.ocsp,
  nextpas.core.tls.openssl.api.crypto,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.base;

type
  TCRYPTO_malloc_fn = function(num: size_t; const fname: PAnsiChar; line: Integer): Pointer; cdecl;

  TOpenSSLConnectionAccess = class(TOpenSSLConnection)
  public
    function CheckRequiredOCSPStapling(AIsClient: Boolean): Boolean;
  end;

function TOpenSSLConnectionAccess.CheckRequiredOCSPStapling(AIsClient: Boolean): Boolean;
begin
  Result := ValidateRequiredOCSPStapling(AIsClient);
end;

// INTENTIONAL_OCSP_CORE_SURFACE: this OpenSSL-specific runtime/regression
// file intentionally keeps direct core OCSP compatibility-surface coverage
// as backend proof for stapled-response status/verification behavior.
// Ordinary ISSLOCSPStapling owner-path guidance is frozen elsewhere.

type
  TSkipCategory = (
    scDependency,
    scVersion,
    scEnvironment,
    scCapability,
    scOther
  );

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TestsSkipped: Integer = 0;
  SkipDependency: Integer = 0;
  SkipVersion: Integer = 0;
  SkipEnvironment: Integer = 0;
  SkipCapability: Integer = 0;
  SkipOther: Integer = 0;

function SkipCategoryLabel(ACategory: TSkipCategory): string;
begin
  case ACategory of
    scDependency: Result := 'dependency';
    scVersion: Result := 'version';
    scEnvironment: Result := 'environment';
    scCapability: Result := 'capability';
  else
    Result := 'other';
  end;
end;

procedure LogPass(const AMessage: string);
begin
  Inc(TestsPassed);
  WriteLn('[PASS] ', AMessage);
end;

procedure LogFail(const AMessage: string);
begin
  Inc(TestsFailed);
  WriteLn('[FAIL] ', AMessage);
end;

procedure LogSkip(const AMessage: string; ACategory: TSkipCategory = scOther);
begin
  Inc(TestsSkipped);

  case ACategory of
    scDependency: Inc(SkipDependency);
    scVersion: Inc(SkipVersion);
    scEnvironment: Inc(SkipEnvironment);
    scCapability: Inc(SkipCapability);
  else
    Inc(SkipOther);
  end;

  WriteLn('[SKIP] [', SkipCategoryLabel(ACategory), '] ', AMessage);
end;

procedure CleanupOpenSSLMemory(APtr: Pointer);
begin
  if APtr = nil then
    Exit;

  if Assigned(OPENSSL_free) then
    OPENSSL_free(APtr)
  else if Assigned(CRYPTO_free) then
    CRYPTO_free(APtr, nil, 0);
end;

function LoadSuccessfulBasicOCSPFixture(out ADer: TBytes): Boolean;
const
  FIXTURE_PATH = './tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der';
var
  LStream: TFileStream;
begin
  Result := False;
  SetLength(ADer, 0);

  if not FileExists(FIXTURE_PATH) then
    Exit;

  LStream := TFileStream.Create(FIXTURE_PATH, fmOpenRead or fmShareDenyNone);
  try
    SetLength(ADer, LStream.Size);
    if Length(ADer) > 0 then
      LStream.ReadBuffer(ADer[0], Length(ADer));
  finally
    LStream.Free;
  end;

  Result := Length(ADer) > 0;
end;

procedure TestOCSPLowercaseSymbolAliasLoading;
begin
  WriteLn;
  WriteLn('=== OCSP OpenSSL 3.x lowercase symbol alias loading ===');

  try
    LoadOpenSSLCore;

    if not LoadOpenSSLOCSP(GetCryptoLibHandle) then
    begin
      LogSkip('OCSP module not available', scCapability);
      Exit;
    end;

    if not Assigned(OCSP_RESPONSE_create) then
    begin
      LogFail('OCSP_RESPONSE_create unresolved (expected lowercase alias fallback)');
      Exit;
    end;

    if not Assigned(OCSP_RESPONSE_status) then
    begin
      LogFail('OCSP_RESPONSE_status unresolved (expected lowercase alias fallback)');
      Exit;
    end;

    if not Assigned(OCSP_RESPONSE_get1_basic) then
    begin
      LogFail('OCSP_RESPONSE_get1_basic unresolved (expected lowercase alias fallback)');
      Exit;
    end;

    LogPass('OCSP lowercase alias fallback is loaded');

  except
    on E: Exception do
      LogFail('Exception: ' + E.Message);
  end;
end;

procedure TestOCSPStatusRequestEnablementFromContextOption;
var
  LLibrary: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LNativeConn: ISSLNativeHandleAccess;
  LStream: TMemoryStream;
  LCtxHandle: PSSL_CTX;
  LSSL: PSSL;
  LOptions: TSSLOptions;
  LCtxType: clong;
  LBeforeType: clong;
  LAfterType: clong;
  LState: TSSLHandshakeState;
begin
  WriteLn;
  WriteLn('=== OCSP status_request enablement from context option ===');

  LLibrary := nil;
  LContext := nil;
  LConn := nil;
  LNativeConn := nil;
  LStream := nil;

  try
    LoadOpenSSLCore;
    LoadOpenSSLSSL;

    if not Assigned(SSL_CTX_get_tlsext_status_type) then
    begin
      if Assigned(SSL_CTX_ctrl) then
        LogFail('SSL_CTX_get_tlsext_status_type should be available via wrapper when SSL_CTX_ctrl exists')
      else
        LogSkip('SSL_CTX_get_tlsext_status_type unavailable', scCapability);
      Exit;
    end;

    if not Assigned(SSL_get_tlsext_status_type) then
    begin
      if Assigned(SSL_ctrl) then
        LogFail('SSL_get_tlsext_status_type should be available via wrapper when SSL_ctrl exists')
      else
        LogSkip('SSL_get_tlsext_status_type unavailable', scCapability);
      Exit;
    end;

    LLibrary := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if LLibrary = nil then
    begin
      LogSkip('OpenSSL library instance unavailable', scDependency);
      Exit;
    end;

    if not LLibrary.Initialize then
    begin
      LogSkip('OpenSSL library initialization failed', scDependency);
      Exit;
    end;

    LContext := LLibrary.CreateContext(sslContextClient);
    if LContext = nil then
    begin
      LogFail('CreateContext returned nil');
      Exit;
    end;

    LCtxHandle := PSSL_CTX(GetNativeHandleSafe(LContext, 'TestOCSPStatusRequestEnablementFromContextOption.Context'));
    LCtxType := SSL_CTX_get_tlsext_status_type(LCtxHandle);
    if LCtxType <> 0 then
    begin
      LogFail(Format('Expected initial context status_type = 0, got %d', [LCtxType]));
      Exit;
    end;

    LStream := TMemoryStream.Create;
    LConn := LContext.CreateConnection(LStream);
    if LConn = nil then
    begin
      LogFail('CreateConnection returned nil');
      Exit;
    end;

    if not Supports(LConn, ISSLNativeHandleAccess, LNativeConn) then
    begin
      LogFail('Connection does not support ISSLNativeHandleAccess');
      Exit;
    end;

    LSSL := PSSL(LNativeConn.GetNativeHandle);
    if LSSL = nil then
    begin
      LogFail('Native SSL handle is nil');
      Exit;
    end;

    LBeforeType := SSL_get_tlsext_status_type(LSSL);
    if LBeforeType <> 0 then
    begin
      LogFail(Format('Expected initial connection status_type = 0, got %d', [LBeforeType]));
      Exit;
    end;

    LOptions := LContext.GetOptions;
    Include(LOptions, ssoEnableOCSPStapling);
    LContext.SetOptions(LOptions);

    LCtxType := SSL_CTX_get_tlsext_status_type(LCtxHandle);
    if LCtxType <> TLSEXT_STATUSTYPE_ocsp then
    begin
      LogFail(Format('Expected context status_type = %d after enabling option, got %d',
        [TLSEXT_STATUSTYPE_ocsp, LCtxType]));
      Exit;
    end;

    // Existing SSL connection should adopt updated option before handshake attempt
    LState := LConn.DoHandshake;
    LAfterType := SSL_get_tlsext_status_type(LSSL);
    if LAfterType <> TLSEXT_STATUSTYPE_ocsp then
    begin
      LogFail(Format('Expected connection status_type = %d after handshake attempt, got %d (state=%d)',
        [TLSEXT_STATUSTYPE_ocsp, LAfterType, Ord(LState)]));
      Exit;
    end;

    LogPass('OCSP status_request is enabled on context and propagated to connection pre-handshake');

  except
    on E: Exception do
      LogFail('Exception: ' + E.Message);
  end;

  LConn := nil;
  if Assigned(LStream) then
    LStream.Free;

  if Assigned(LLibrary) then
    LLibrary.Finalize;
end;

procedure TestRequiredOCSPStaplingFailClosedPolicy;
var
  LLibrary: ISSLLibrary;
  LContext: ISSLContext;
  LOptions: TSSLOptions;
  LConnAccess: TOpenSSLConnectionAccess;
  LStream: TMemoryStream;
  LSSL: PSSL;
  LResponseDER: TBytes;
  LOpenSSLResp: Pointer;
  LSetResult: clong;
  LCryptoMalloc: TCRYPTO_malloc_fn;
  LVerifyRes: Integer;
begin
  WriteLn;
  WriteLn('=== Required OCSP stapling fail-closed policy ===');

  LLibrary := nil;
  LContext := nil;
  LConnAccess := nil;
  LStream := nil;
  LOpenSSLResp := nil;

  try
    LoadOpenSSLCore;
    LoadOpenSSLSSL;
    LoadOpenSSLCrypto;

    if not LoadOpenSSLOCSP(GetCryptoLibHandle) then
    begin
      LogSkip('OCSP module not available', scCapability);
      Exit;
    end;

    if not Assigned(SSL_set_tlsext_status_ocsp_resp) then
    begin
      if Assigned(SSL_ctrl) then
        LogFail('SSL_set_tlsext_status_ocsp_resp should be available via wrapper when SSL_ctrl exists')
      else
        LogSkip('SSL_set_tlsext_status_ocsp_resp unavailable', scCapability);
      Exit;
    end;

    LCryptoMalloc := TCRYPTO_malloc_fn(GetProcedureAddress(GetCryptoLibHandle, 'CRYPTO_malloc'));
    if not Assigned(LCryptoMalloc) then
    begin
      LogSkip('CRYPTO_malloc unavailable', scDependency);
      Exit;
    end;

    if not LoadSuccessfulBasicOCSPFixture(LResponseDER) then
    begin
      LogFail('Missing or empty OCSP fixture: tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der');
      Exit;
    end;

    LLibrary := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if LLibrary = nil then
    begin
      LogSkip('OpenSSL library instance unavailable', scDependency);
      Exit;
    end;

    if not LLibrary.Initialize then
    begin
      LogSkip('OpenSSL library initialization failed', scDependency);
      Exit;
    end;

    LContext := LLibrary.CreateContext(sslContextClient);
    if LContext = nil then
    begin
      LogFail('CreateContext returned nil');
      Exit;
    end;

    LOptions := LContext.GetOptions;
    Include(LOptions, ssoEnableOCSPStapling);
    Include(LOptions, ssoRequireOCSPStapling);
    LContext.SetOptions(LOptions);

    if not (ssoRequireOCSPStapling in LContext.GetOptions) then
    begin
      LogFail('ssoRequireOCSPStapling option is not persisted in context');
      Exit;
    end;

    LStream := TMemoryStream.Create;
    LConnAccess := TOpenSSLConnectionAccess.Create(LContext, LStream);

    LSSL := PSSL(LConnAccess.GetNativeHandle);
    if LSSL = nil then
    begin
      LogFail('Native SSL handle is nil');
      Exit;
    end;

    // Case 1: required + no stapled response -> fail with VERIFY_NEEDED
    if LConnAccess.CheckRequiredOCSPStapling(True) then
    begin
      LogFail('Expected fail-closed when required stapled response is missing');
      Exit;
    end;

    if Assigned(SSL_get_verify_result) then
    begin
      LVerifyRes := SSL_get_verify_result(LSSL);
      if LVerifyRes <> X509_V_ERR_OCSP_VERIFY_NEEDED then
      begin
        LogFail(Format('Expected verify_result = X509_V_ERR_OCSP_VERIFY_NEEDED (%d), got %d',
          [X509_V_ERR_OCSP_VERIFY_NEEDED, LVerifyRes]));
        Exit;
      end;
    end;

    // Case 2: required + stapled response present but unverifiable -> fail with VERIFY_FAILED
    LOpenSSLResp := LCryptoMalloc(Length(LResponseDER), 'test_ocsp_connection_verification_regression', 0);
    if LOpenSSLResp = nil then
    begin
      LogFail('CRYPTO_malloc failed for OCSP response payload');
      Exit;
    end;

    Move(LResponseDER[0], LOpenSSLResp^, Length(LResponseDER));
    LSetResult := SSL_set_tlsext_status_ocsp_resp(LSSL, PByte(LOpenSSLResp), Length(LResponseDER));
    if LSetResult <> 1 then
    begin
      CleanupOpenSSLMemory(LOpenSSLResp);
      LOpenSSLResp := nil;
      LogFail('SSL_set_tlsext_status_ocsp_resp failed for fixture payload');
      Exit;
    end;

    LOpenSSLResp := nil; // ownership transferred

    if LConnAccess.CheckRequiredOCSPStapling(True) then
    begin
      LogFail('Expected fail-closed when required stapled response is not verified');
      Exit;
    end;

    if Assigned(SSL_get_verify_result) then
    begin
      LVerifyRes := SSL_get_verify_result(LSSL);
      if LVerifyRes <> X509_V_ERR_OCSP_VERIFY_FAILED then
      begin
        LogFail(Format('Expected verify_result = X509_V_ERR_OCSP_VERIFY_FAILED (%d), got %d',
          [X509_V_ERR_OCSP_VERIFY_FAILED, LVerifyRes]));
        Exit;
      end;
    end;

    LogPass('Required OCSP stapling fail-closed policy is enforced (missing/unverified response)');

  except
    on E: Exception do
      LogFail('Exception: ' + E.Message);
  end;

  CleanupOpenSSLMemory(LOpenSSLResp);
  if Assigned(LConnAccess) then
    LConnAccess.Free;
  if Assigned(LStream) then
    LStream.Free;

  if Assigned(LLibrary) then
    LLibrary.Finalize;
end;

procedure TestSuccessfulStapledOCSPFixtureMustNotVerifyWithoutPeerContext;
var
  LLibrary: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LNative: ISSLNativeHandleAccess;
  LStream: TMemoryStream;
  LSSL: PSSL;
  LResponseDER: TBytes;
  LOpenSSLResp: Pointer;
  LSetResult: clong;
  LStatus: string;
  LCryptoMalloc: TCRYPTO_malloc_fn;
begin
  WriteLn;
  WriteLn('=== Regression: successful/basic stapled OCSP fixture must not verify without peer context ===');

  LOpenSSLResp := nil;
  LLibrary := nil;
  LContext := nil;
  LConn := nil;
  LNative := nil;
  LStream := nil;

  try
    LoadOpenSSLCore;
    LoadOpenSSLSSL;
    LoadOpenSSLCrypto;

    if not LoadOpenSSLOCSP(GetCryptoLibHandle) then
    begin
      LogSkip('OCSP module not available', scCapability);
      Exit;
    end;

    if not Assigned(SSL_get_tlsext_status_ocsp_resp) then
    begin
      if Assigned(SSL_ctrl) then
        LogFail('SSL_get_tlsext_status_ocsp_resp should be available via wrapper when SSL_ctrl exists')
      else
        LogSkip('SSL_get_tlsext_status_ocsp_resp unavailable', scCapability);
      Exit;
    end;

    if not Assigned(SSL_set_tlsext_status_ocsp_resp) then
    begin
      if Assigned(SSL_ctrl) then
        LogFail('SSL_set_tlsext_status_ocsp_resp should be available via wrapper when SSL_ctrl exists')
      else
        LogSkip('SSL_set_tlsext_status_ocsp_resp unavailable', scCapability);
      Exit;
    end;

    LCryptoMalloc := TCRYPTO_malloc_fn(GetProcedureAddress(GetCryptoLibHandle, 'CRYPTO_malloc'));
    if not Assigned(LCryptoMalloc) then
    begin
      LogSkip('CRYPTO_malloc unavailable', scDependency);
      Exit;
    end;

    if not LoadSuccessfulBasicOCSPFixture(LResponseDER) then
    begin
      LogFail('Missing or empty OCSP fixture: tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der');
      Exit;
    end;

    LLibrary := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if LLibrary = nil then
    begin
      LogSkip('OpenSSL library instance unavailable', scDependency);
      Exit;
    end;

    if not LLibrary.Initialize then
    begin
      LogSkip('OpenSSL library initialization failed', scDependency);
      Exit;
    end;

    LContext := LLibrary.CreateContext(sslContextClient);
    if LContext = nil then
    begin
      LogFail('CreateContext returned nil');
      Exit;
    end;

    LStream := TMemoryStream.Create;
    LConn := LContext.CreateConnection(LStream);
    if LConn = nil then
    begin
      LogFail('CreateConnection returned nil');
      Exit;
    end;

    if not Supports(LConn, ISSLNativeHandleAccess, LNative) then
    begin
      LogFail('Connection does not support ISSLNativeHandleAccess');
      Exit;
    end;

    LSSL := PSSL(LNative.GetNativeHandle);
    if LSSL = nil then
    begin
      LogFail('Native SSL handle is nil');
      Exit;
    end;

    LOpenSSLResp := LCryptoMalloc(Length(LResponseDER), 'test_ocsp_connection_verification_regression', 0);
    if LOpenSSLResp = nil then
    begin
      LogFail('CRYPTO_malloc failed for OCSP response payload');
      Exit;
    end;

    Move(LResponseDER[0], LOpenSSLResp^, Length(LResponseDER));
    LSetResult := SSL_set_tlsext_status_ocsp_resp(LSSL, PByte(LOpenSSLResp), Length(LResponseDER));
    if LSetResult <> 1 then
    begin
      CleanupOpenSSLMemory(LOpenSSLResp);
      LOpenSSLResp := nil;
      LogFail('SSL_set_tlsext_status_ocsp_resp failed for fixture payload');
      Exit;
    end;

    LOpenSSLResp := nil; // Ownership transferred to SSL instance

    {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
    LStatus := LConn.GetOCSPResponseStatus;
    {$POP}
    if LStatus <> 'Successful' then
    begin
      LogFail('Expected OCSP status = Successful, got: ' + LStatus);
      Exit;
    end;

    {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
    if LConn.IsOCSPResponseVerified then
      LogFail('Successful/basic stapled fixture must NOT be treated as verified without peer cert context')
    else
      LogPass('Successful/basic stapled fixture is correctly rejected without peer cert context');
    {$POP}

  except
    on E: Exception do
      LogFail('Exception: ' + E.Message);
  end;

  CleanupOpenSSLMemory(LOpenSSLResp);
  LConn := nil;
  if Assigned(LStream) then
    LStream.Free;

  if Assigned(LLibrary) then
    LLibrary.Finalize;
end;

begin
  WriteLn('OCSP Connection Verification Regression Test');
  WriteLn('============================================');

  TestOCSPLowercaseSymbolAliasLoading;
  TestOCSPStatusRequestEnablementFromContextOption;
  TestRequiredOCSPStaplingFailClosedPolicy;
  TestSuccessfulStapledOCSPFixtureMustNotVerifyWithoutPeerContext;

  WriteLn;
  WriteLn('============================================');
  WriteLn('Passed:  ', TestsPassed);
  WriteLn('Failed:  ', TestsFailed);
  WriteLn('Skipped: ', TestsSkipped);
  WriteLn(Format('Skip breakdown: dependency=%d, version=%d, environment=%d, capability=%d, other=%d',
    [SkipDependency, SkipVersion, SkipEnvironment, SkipCapability, SkipOther]));
  WriteLn('============================================');

  if TestsFailed = 0 then
    ExitCode := 0
  else
    ExitCode := 1;
end.
