program test_wolfssl_client_peer_certificate_surface;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.utils,
  nextpas.core.tls.wolfssl.base,
  nextpas.core.tls.wolfssl.api,
  nextpas.core.tls.wolfssl.lib,
  nextpas.core.tls.wolfssl.connection;

var
  GLeafDER: TBytes;
  GIssuerDER: TBytes;
  GOriginalGetPeerCertificate: TwolfSSL_get_peer_certificate = nil;
  GOriginalGetPeerChain: TwolfSSL_get_peer_chain = nil;
  GOriginalGetChainCount: TwolfSSL_get_chain_count = nil;
  GOriginalGetChainLength: TwolfSSL_get_chain_length = nil;
  GOriginalGetChainCert: TwolfSSL_get_chain_cert = nil;

// INTENTIONAL_CORE_SURFACE: this backend proof file intentionally keeps direct
// core GetPeerCertificateChain coverage as runtime proof. Generic
// ISSLCertificateVerification owner-path guidance is frozen elsewhere.
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

procedure Skip(const AMessage: string);
begin
  WriteLn('[SKIP] ', AMessage);
  Halt(0);
end;

procedure Fail(const AMessage: string);
begin
  WriteLn('FAIL: ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

procedure AssertEqualsInt(AExpected, AActual: Int64; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

function ReadTextFile(const AFileName: string): string;
var
  LStream: TFileStream;
  LBytes: TBytes;
begin
  Result := '';
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(LBytes, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(LBytes[0], LStream.Size);
  finally
    LStream.Free;
  end;

  if Length(LBytes) > 0 then
    SetString(Result, PAnsiChar(@LBytes[0]), Length(LBytes));
end;

procedure LoadFixtureDER;
begin
  GLeafDER := TSSLUtils.PEMToDER(
    ReadTextFile('tests/certificate/test_certs/signer_cert.pem'));
  GIssuerDER := TSSLUtils.PEMToDER(
    ReadTextFile('tests/certificate/test_certs/ca_cert.pem'));

  AssertTrue(Length(GLeafDER) > 0, 'Leaf fixture DER should not be empty');
  AssertTrue(Length(GIssuerDER) > 0, 'Issuer fixture DER should not be empty');
end;

function StubWolfSSLGetPeerCertificateFromDER(ssl: PWOLFSSL): PWOLFSSL_X509; cdecl;
begin
  Result := nil;
  if (ssl = nil) or (Length(GLeafDER) = 0) or
     (not Assigned(wolfSSL_X509_d2i)) then
    Exit;

  Result := wolfSSL_X509_d2i(nil, @GLeafDER[0], Length(GLeafDER));
end;

function StubWolfSSLGetPeerChain(ssl: PWOLFSSL): PWOLFSSL_X509_CHAIN; cdecl;
begin
  if ssl = nil then
    Exit(nil);
  Result := PWOLFSSL_X509_CHAIN(Pointer(PtrUInt(1)));
end;

function StubWolfSSLGetChainCount(chain: PWOLFSSL_X509_CHAIN): Integer; cdecl;
begin
  if chain = nil then
    Exit(0);
  Result := 2;
end;

function StubWolfSSLGetChainLength(chain: PWOLFSSL_X509_CHAIN;
  idx: Integer): Integer; cdecl;
begin
  if chain = nil then
    Exit(0);

  case idx of
    0: Result := Length(GLeafDER);
    1: Result := Length(GIssuerDER);
  else
    Result := 0;
  end;
end;

function StubWolfSSLGetChainCert(chain: PWOLFSSL_X509_CHAIN;
  idx: Integer): PByte; cdecl;
begin
  if chain = nil then
    Exit(nil);

  case idx of
    0:
      if Length(GLeafDER) > 0 then
        Result := @GLeafDER[0]
      else
        Result := nil;
    1:
      if Length(GIssuerDER) > 0 then
        Result := @GIssuerDER[0]
      else
        Result := nil;
  else
    Result := nil;
  end;
end;

procedure RestoreChainAPIs;
begin
  wolfSSL_get_peer_certificate := GOriginalGetPeerCertificate;
  wolfSSL_get_peer_chain := GOriginalGetPeerChain;
  wolfSSL_get_chain_count := GOriginalGetChainCount;
  wolfSSL_get_chain_length := GOriginalGetChainLength;
  wolfSSL_get_chain_cert := GOriginalGetChainCert;
end;

procedure OverrideChainAPIs;
begin
  GOriginalGetPeerCertificate := wolfSSL_get_peer_certificate;
  GOriginalGetPeerChain := wolfSSL_get_peer_chain;
  GOriginalGetChainCount := wolfSSL_get_chain_count;
  GOriginalGetChainLength := wolfSSL_get_chain_length;
  GOriginalGetChainCert := wolfSSL_get_chain_cert;

  wolfSSL_get_peer_certificate := @StubWolfSSLGetPeerCertificateFromDER;
  wolfSSL_get_peer_chain := @StubWolfSSLGetPeerChain;
  wolfSSL_get_chain_count := @StubWolfSSLGetChainCount;
  wolfSSL_get_chain_length := @StubWolfSSLGetChainLength;
  wolfSSL_get_chain_cert := @StubWolfSSLGetChainCert;
end;

procedure TestPeerChainMaterialization;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LStream: TMemoryStream;
  LConn: TWolfSSLConnection;
  LPeerCert: ISSLCertificate;
  LIssuerFromPeerCert: ISSLCertificate;
  LChain: TSSLCertificateArray;
  LExpectedLeaf: ISSLCertificate;
  LExpectedIssuer: ISSLCertificate;
  LDERLeaf: ISSLCertificate;
begin
  if not TSSLFactory.IsLibraryAvailable(sslWolfSSL) then
    Skip('WolfSSL backend not available on this platform');

  LLib := TSSLFactory.GetLibraryInstance(sslWolfSSL);
  if (LLib = nil) or (not LLib.Initialize) then
    Skip('WolfSSL runtime unavailable; peer certificate surface test skipped');

  LoadFixtureDER;

  LExpectedLeaf := TSSLFactory.CreateCertificate(sslWolfSSL);
  AssertTrue(LExpectedLeaf <> nil, 'Expected leaf certificate should be created');
  AssertTrue(
    LExpectedLeaf.LoadFromFile('tests/certificate/test_certs/signer_cert.pem'),
    'Expected leaf certificate should load');

  LExpectedIssuer := TSSLFactory.CreateCertificate(sslWolfSSL);
  AssertTrue(LExpectedIssuer <> nil, 'Expected issuer certificate should be created');
  AssertTrue(
    LExpectedIssuer.LoadFromFile('tests/certificate/test_certs/ca_cert.pem'),
    'Expected issuer certificate should load');

  LDERLeaf := TSSLFactory.CreateCertificate(sslWolfSSL);
  AssertTrue(LDERLeaf <> nil, 'DER leaf certificate should be created');
  AssertTrue(LDERLeaf.LoadFromDER(GLeafDER),
    'WolfSSL certificate should load leaf DER fixture directly');

  LCtx := LLib.CreateContext(sslCtxClient);
  AssertTrue(LCtx <> nil, 'WolfSSL client context should be created');

  LStream := TMemoryStream.Create;
  LConn := nil;
  OverrideChainAPIs;
  try
    LConn := TWolfSSLConnection.Create(LCtx, LStream);

    LPeerCert := LConn.GetPeerCertificate;
    AssertTrue(LPeerCert <> nil,
      'WolfSSL peer leaf certificate should be exposed when peer certificate exists');
    AssertTrue(
      SameText(LPeerCert.GetFingerprintSHA256, LExpectedLeaf.GetFingerprintSHA256),
      'WolfSSL peer leaf certificate should match the scripted leaf fixture');

    LIssuerFromPeerCert := LPeerCert.GetIssuerCertificate;
    AssertTrue(LIssuerFromPeerCert <> nil,
      'WolfSSL peer leaf certificate should preserve issuer link');
    AssertTrue(
      (LIssuerFromPeerCert <> nil) and
      SameText(LIssuerFromPeerCert.GetFingerprintSHA256, LExpectedIssuer.GetFingerprintSHA256),
      'WolfSSL peer leaf issuer link should match the scripted issuer fixture');

    LChain := LConn.GetPeerCertificateChain;

    AssertEqualsInt(2, Length(LChain),
      'WolfSSL peer chain surface should materialize every native chain entry');
    AssertTrue(LChain[0] <> nil, 'WolfSSL peer chain leaf entry should not be nil');
    AssertTrue(LChain[1] <> nil, 'WolfSSL peer chain issuer entry should not be nil');
    AssertTrue(
      SameText(LChain[0].GetFingerprintSHA256, LExpectedLeaf.GetFingerprintSHA256),
      'WolfSSL peer chain leaf entry should match the scripted leaf fixture');
    AssertTrue(
      SameText(LChain[1].GetFingerprintSHA256, LExpectedIssuer.GetFingerprintSHA256),
      'WolfSSL peer chain issuer entry should match the scripted issuer fixture');
    AssertTrue(LChain[0].GetIssuerCertificate <> nil,
      'WolfSSL peer chain leaf entry should preserve issuer link');
    AssertTrue(
      (LChain[0].GetIssuerCertificate <> nil) and
      SameText(LChain[0].GetIssuerCertificate.GetFingerprintSHA256, LExpectedIssuer.GetFingerprintSHA256),
      'WolfSSL peer chain leaf issuer link should match the scripted issuer fixture');
    AssertTrue(LChain[1].GetIssuerCertificate = nil,
      'WolfSSL peer chain issuer entry should not invent a higher issuer link');

    wolfSSL_get_chain_cert := nil;
    LChain := LConn.GetPeerCertificateChain;
    AssertEqualsInt(0, Length(LChain),
      'WolfSSL peer chain surface should safe-degrade when chain helpers are unavailable');
  finally
    RestoreChainAPIs;
    if LConn <> nil then
      LConn.Free;
    LStream.Free;
    LLib.Finalize;
  end;
end;

begin
  WriteLn('Testing WolfSSL client peer certificate surface...');
  TestPeerChainMaterialization;
  WriteLn('PASS: WolfSSL client peer certificate chain surface contract passed');
end.
