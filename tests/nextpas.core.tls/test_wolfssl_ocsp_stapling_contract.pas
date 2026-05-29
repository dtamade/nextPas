program test_wolfssl_ocsp_stapling_contract;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  fafafa.ssl,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.wolfssl.lib;

// INTENTIONAL_OCSP_CORE_SURFACE: this WolfSSL-specific runtime/contract
// file intentionally keeps direct core OCSP compatibility-surface coverage
// as backend proof for the public stapling surface defaults. Ordinary
// ISSLOCSPStapling owner-path guidance is frozen elsewhere.

const
  OCSP_FIXTURE_FILE = 'tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der';
  CERT_FILE = 'tests/certificate/test_certs/signer_cert.pem';
  KEY_FILE = 'tests/certificate/test_certs/signer_key.pem';

var
  GTotal: Integer = 0;
  GPassed: Integer = 0;
  GFailed: Integer = 0;
  GSkipped: Integer = 0;

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

function NewWolfSSLServerContextFromBuilder(
  const AStapledResponseFile: string = ''): ISSLContext;
var
  LBuilder: ISSLContextBuilder;
begin
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslWolfSSL)
    .WithTLS13
    .WithSessionCache(False)
    .WithCertificate(CERT_FILE)
    .WithPrivateKey(KEY_FILE)
    .WithOCSPStapling(True);

  if AStapledResponseFile <> '' then
    LBuilder := LBuilder.WithServerOCSPStapledResponseFile(AStapledResponseFile);

  Result := LBuilder.BuildServer;
end;

procedure TestWolfSSLOCSPContract;
var
  LLib: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
  LServerCtx: ISSLContext;
  LClientCtx: ISSLContext;
  LStaplingCtx: ISSLServerOCSPStaplingContext;
  LConn: ISSLConnection;
  LFixture: TBytes;
  LLoaded: TBytes;
begin
  WriteLn('=== WolfSSL OCSP stapling contract ===');

  if not TSSLFactory.IsLibraryAvailable(sslWolfSSL) then
  begin
    Skip('WolfSSL contract', 'backend not available on this platform');
    Exit;
  end;

  LLib := TSSLFactory.GetLibraryInstance(sslWolfSSL);
  if (LLib = nil) or (not LLib.Initialize) then
  begin
    Skip('WolfSSL contract', 'backend failed to initialize');
    Exit;
  end;

  LCaps := LLib.GetCapabilities;
  CheckTrue('WolfSSL capability exposes OCSP stapling surface',
    LCaps.SupportsOCSPStapling,
    'SupportsOCSPStapling should be True once runtime stapling APIs are wired');
  CheckTrue('WolfSSL capability marks OCSP stapling experimental',
    LCaps.OCSPStaplingSupport = sslSupportExperimental,
    Format('expected=%d actual=%d', [Ord(sslSupportExperimental), Ord(LCaps.OCSPStaplingSupport)]));

  LServerCtx := LLib.CreateContext(sslCtxServer);
  CheckTrue('WolfSSL server context exposes ISSLServerOCSPStaplingContext',
    Supports(LServerCtx, ISSLServerOCSPStaplingContext, LStaplingCtx),
    'server context should expose public server stapling interface');
  if not Supports(LServerCtx, ISSLServerOCSPStaplingContext, LStaplingCtx) then
    Exit;

  LFixture := ReadFileBytes(OCSP_FIXTURE_FILE);
  CheckTrue('WolfSSL OCSP fixture is present', Length(LFixture) > 0,
    'fixture should not be empty');

  LStaplingCtx.SetServerStapledOCSPResponse(LFixture);
  CheckTrue('WolfSSL context reports stapled response after SetServerStapledOCSPResponse',
    LStaplingCtx.HasServerStapledOCSPResponse,
    'HasServerStapledOCSPResponse should be True after setting bytes');
  CheckTrue('WolfSSL context returns same stapled response bytes',
    BytesEqual(LFixture, LStaplingCtx.GetServerStapledOCSPResponse),
    'GetServerStapledOCSPResponse should round-trip the configured DER bytes');

  LStaplingCtx.ClearServerStapledOCSPResponse;
  CheckTrue('WolfSSL context clears stapled response bytes',
    not LStaplingCtx.HasServerStapledOCSPResponse,
    'ClearServerStapledOCSPResponse should remove configured DER bytes');

  LServerCtx := NewWolfSSLServerContextFromBuilder(OCSP_FIXTURE_FILE);
  CheckTrue('WolfSSL BuildServer exposes ISSLServerOCSPStaplingContext',
    Supports(LServerCtx, ISSLServerOCSPStaplingContext, LStaplingCtx),
    'BuildServer should expose public server stapling interface');
  if Supports(LServerCtx, ISSLServerOCSPStaplingContext, LStaplingCtx) then
  begin
    LLoaded := LStaplingCtx.GetServerStapledOCSPResponse;
    CheckTrue('WolfSSL BuildServer loads configured stapled response file',
      LStaplingCtx.HasServerStapledOCSPResponse and BytesEqual(LFixture, LLoaded),
      'BuildServer should load configured stapled OCSP response bytes into the context');
  end;

  LClientCtx := LLib.CreateContext(sslCtxClient);
  LConn := LClientCtx.CreateConnection(THandle(0));
  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  CheckTrue('WolfSSL connection OCSP stapling enabled defaults false without stapled response',
    not LConn.GetOCSPStaplingEnabled,
    'GetOCSPStaplingEnabled should reflect an actual stapled response, not just symbol presence');
  {$POP}
end;

begin
  try
    TestWolfSSLOCSPContract;

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
