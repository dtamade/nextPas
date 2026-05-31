program test_openssl_server_ocsp_stapling_callback_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes, ctypes,
  nextpas.core.tls.base,
  fafafa.ssl,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.consts;

const
  OCSP_FIXTURE_FILE = 'tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der';
  CERT_FILE = 'tests/certificate/test_certs/signer_cert.pem';
  KEY_FILE = 'tests/certificate/test_certs/signer_key.pem';

type
  TOpenSSLStatusCallback = function(ssl: PSSL; arg: Pointer): Integer; cdecl;

var
  GTotal: Integer = 0;
  GPassed: Integer = 0;
  GFailed: Integer = 0;
  GSkipped: Integer = 0;
  GRegisteredStatusCallback: Pointer = nil;
  GRegisteredStatusArg: Pointer = nil;
  GStatusCallbackRegistrations: Integer = 0;
  GStatusArgRegistrations: Integer = 0;
  GInjectedResponse: TBytes = nil;
  GInjectedResponseCalls: Integer = 0;

procedure Pass(const AName: string);
begin
  Inc(GTotal);
  Inc(GPassed);
  WriteLn('[PASS] ', AName);
end;

procedure Fail(const AName, ADetail: string);
begin
  Inc(GTotal);
  Inc(GFailed);
  WriteLn('[FAIL] ', AName);
  if ADetail <> '' then
    WriteLn('       ', ADetail);
end;

procedure Skip(const AName, AReason: string);
begin
  Inc(GTotal);
  Inc(GSkipped);
  WriteLn('[SKIP] ', AName, ' - ', AReason);
end;

procedure CheckTrue(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, ADetail);
end;

procedure ResetCaptures;
begin
  GRegisteredStatusCallback := nil;
  GRegisteredStatusArg := nil;
  GStatusCallbackRegistrations := 0;
  GStatusArgRegistrations := 0;
  GInjectedResponse := nil;
  GInjectedResponseCalls := 0;
end;

function ReadFileBytes(const AFileName: string): TBytes;
var
  LStream: TFileStream;
begin
  Result := nil;
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if LStream.Size > 0 then
    begin
      SetLength(Result, LStream.Size);
      LStream.ReadBuffer(Result[0], LStream.Size);
    end;
  finally
    LStream.Free;
  end;
end;

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);

  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);

  Result := True;
end;

function NewOpenSSLServerContextFromBuilder(
  const AStapledResponseFile: string = ''): ISSLContext;
var
  LBuilder: ISSLContextBuilder;
begin
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslOpenSSL)
    .WithTLS13
    .WithSessionCache(False)
    .WithCertificate(CERT_FILE)
    .WithPrivateKey(KEY_FILE)
    .WithOCSPStapling(True);

  if AStapledResponseFile <> '' then
    LBuilder := LBuilder.WithServerOCSPStapledResponseFile(AStapledResponseFile);

  Result := LBuilder.BuildServer;
end;

function StubSSLCTXSetStatusCB(ctx: PSSL_CTX; cb: Pointer): clong; cdecl;
begin
  Inc(GStatusCallbackRegistrations);
  GRegisteredStatusCallback := cb;
  Result := 1;
end;

function StubSSLCTXSetStatusArg(ctx: PSSL_CTX; arg: Pointer): clong; cdecl;
begin
  Inc(GStatusArgRegistrations);
  GRegisteredStatusArg := arg;
  Result := 1;
end;

function StubSSLSetStatusOCSPResp(ssl: PSSL; resp: PByte; len: clong): clong; cdecl;
begin
  Inc(GInjectedResponseCalls);
  SetLength(GInjectedResponse, 0);
  if (resp <> nil) and (len > 0) then
  begin
    SetLength(GInjectedResponse, len);
    Move(resp^, GInjectedResponse[0], len);
  end;
  Result := 1;
end;

procedure TestOpenSSLServerStaplingCallbackRegistration;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LStaplingCtx: ISSLServerOCSPStaplingContext;
  LFixture: TBytes;
  LCallback: TOpenSSLStatusCallback;
  LCallbackResult: Integer;
  LRegisteredArg: Pointer;
  LOrigStatusCB: TSSL_CTX_set_tlsext_status_cb;
  LOrigStatusArg: TSSL_CTX_set_tlsext_status_arg;
  LOrigSetResp: TSSL_set_tlsext_status_ocsp_resp;
begin
  WriteLn('=== OpenSSL server OCSP stapling callback contract ===');

  if not TSSLFactory.IsLibraryAvailable(sslOpenSSL) then
  begin
    Skip('OpenSSL server stapling callback contract', 'backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if (LLib = nil) or (not LLib.Initialize) then
  begin
    Skip('OpenSSL server stapling callback contract', 'backend failed to initialize');
    Exit;
  end;

  if (not Assigned(SSL_CTX_set_tlsext_status_cb)) or
     (not Assigned(SSL_CTX_set_tlsext_status_arg)) or
     (not Assigned(SSL_set_tlsext_status_ocsp_resp)) then
  begin
    Skip('OpenSSL server stapling callback contract',
      'required OCSP stapling callback APIs are unavailable');
    Exit;
  end;

  LOrigStatusCB := SSL_CTX_set_tlsext_status_cb;
  LOrigStatusArg := SSL_CTX_set_tlsext_status_arg;
  LOrigSetResp := SSL_set_tlsext_status_ocsp_resp;

  SSL_CTX_set_tlsext_status_cb := @StubSSLCTXSetStatusCB;
  SSL_CTX_set_tlsext_status_arg := @StubSSLCTXSetStatusArg;
  SSL_set_tlsext_status_ocsp_resp := @StubSSLSetStatusOCSPResp;
  try
    LFixture := ReadFileBytes(OCSP_FIXTURE_FILE);
    CheckTrue('OpenSSL OCSP fixture is present', Length(LFixture) > 0,
      'fixture should not be empty');

    ResetCaptures;
    LCtx := LLib.CreateContext(sslCtxServer);
    CheckTrue('OpenSSL server context exposes ISSLServerOCSPStaplingContext',
      Supports(LCtx, ISSLServerOCSPStaplingContext, LStaplingCtx),
      'server context should expose public server stapling interface');
    if not Supports(LCtx, ISSLServerOCSPStaplingContext, LStaplingCtx) then
      Exit;

    LStaplingCtx.SetServerStapledOCSPResponse(LFixture);
    CheckTrue('OpenSSL context registers status callback when stapled response is configured',
      GRegisteredStatusCallback <> nil,
      'SSL_CTX_set_tlsext_status_cb should receive a non-nil callback');
    CheckTrue('OpenSSL context registers callback arg when stapled response is configured',
      GRegisteredStatusArg <> nil,
      'SSL_CTX_set_tlsext_status_arg should receive the owning context pointer');
    if (GRegisteredStatusCallback = nil) or (GRegisteredStatusArg = nil) then
      Exit;

    LCallback := TOpenSSLStatusCallback(GRegisteredStatusCallback);
    LRegisteredArg := GRegisteredStatusArg;
    ResetCaptures;
    LCallbackResult := LCallback(PSSL(Pointer(PtrUInt($1234))), LRegisteredArg);
    CheckTrue('OpenSSL stapling callback returns SSL_TLSEXT_ERR_OK',
      LCallbackResult = SSL_TLSEXT_ERR_OK,
      Format('actual=%d', [LCallbackResult]));
    CheckTrue('OpenSSL stapling callback injects response into SSL handle',
      GInjectedResponseCalls = 1,
      Format('actual calls=%d', [GInjectedResponseCalls]));
    CheckTrue('OpenSSL stapling callback injects configured DER bytes',
      BytesEqual(LFixture, GInjectedResponse),
      'injected stapled response bytes should match configured DER payload');

    ResetCaptures;
    LStaplingCtx.ClearServerStapledOCSPResponse;
    CheckTrue('OpenSSL clear unregisters status callback',
      GRegisteredStatusCallback = nil,
      'SSL_CTX_set_tlsext_status_cb should receive nil after ClearServerStapledOCSPResponse');

    ResetCaptures;
    LCtx := NewOpenSSLServerContextFromBuilder(OCSP_FIXTURE_FILE);
    CheckTrue('OpenSSL BuildServer exposes ISSLServerOCSPStaplingContext',
      Supports(LCtx, ISSLServerOCSPStaplingContext, LStaplingCtx),
      'BuildServer should expose public server stapling interface');
    if Supports(LCtx, ISSLServerOCSPStaplingContext, LStaplingCtx) then
    begin
      CheckTrue('OpenSSL BuildServer loads configured stapled response bytes',
        BytesEqual(LFixture, LStaplingCtx.GetServerStapledOCSPResponse),
        'BuildServer should load configured stapled OCSP response bytes into the context');
      CheckTrue('OpenSSL BuildServer registers stapling callback',
        GRegisteredStatusCallback <> nil,
        'BuildServer should register the OpenSSL stapling callback when file material is configured');
    end;
  finally
    SSL_CTX_set_tlsext_status_cb := LOrigStatusCB;
    SSL_CTX_set_tlsext_status_arg := LOrigStatusArg;
    SSL_set_tlsext_status_ocsp_resp := LOrigSetResp;
  end;
end;

begin
  try
    TestOpenSSLServerStaplingCallbackRegistration;

    WriteLn;
    WriteLn('Summary');
    WriteLn('  Total:   ', GTotal);
    WriteLn('  Passed:  ', GPassed);
    WriteLn('  Failed:  ', GFailed);
    WriteLn('  Skipped: ', GSkipped);

    if GFailed > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
