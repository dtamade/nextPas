program test_wolfssl_connection_peer_certificate_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.wolfssl.base,
  nextpas.core.tls.wolfssl.api,
  nextpas.core.tls.wolfssl.lib,
  nextpas.core.tls.wolfssl.connection,
  nextpas.core.tls.wolfssl.certificate,
  nextpas.core.tls.wolfssl.native_handle;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GStubPeerCertificateDER: TBytes;
  GSourcePeerCertificateHandle: PWOLFSSL_X509 = nil;
  GSourcePeerCertificateD2I: TwolfSSL_X509_d2i = nil;

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

function StubWolfSSLGetPeerCertificateFromDER(ssl: PWOLFSSL): PWOLFSSL_X509; cdecl;
begin
  GSourcePeerCertificateHandle := nil;
  Result := nil;
  if (ssl = nil) or (Length(GStubPeerCertificateDER) = 0) or
     (not Assigned(GSourcePeerCertificateD2I)) then
    Exit;

  Result := GSourcePeerCertificateD2I(nil, @GStubPeerCertificateDER[0],
    Length(GStubPeerCertificateDER));
  GSourcePeerCertificateHandle := Result;
end;

function CaptureCertHandle(const ACert: ISSLCertificate): Pointer;
var
  LNative: ISSLNativeHandleAccess;
begin
  Result := nil;
  if (ACert <> nil) and Supports(ACert, ISSLNativeHandleAccess, LNative) then
    Result := LNative.GetNativeHandle;
end;

procedure TestConnectionPeerCertificateMustMaterializeOwnedCopy;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LFixture: TWolfSSLCertificate;
  LStream: TMemoryStream;
  LConn: TWolfSSLConnection;
  LCert: ISSLCertificate;
  LExpectedFingerprint: string;
  LOriginalGetPeerCertificate: TwolfSSL_get_peer_certificate;
  LOriginalX509D2I: TwolfSSL_X509_d2i;
  LOriginalI2DX509: TwolfSSL_i2d_X509;
begin
  WriteLn;
  WriteLn('=== WolfSSL connection peer certificate materialization ===');

  LLib := CreateWolfSSLLibrary;
  if (not Assigned(LLib)) or (not LLib.Initialize) then
  begin
    MarkSkip('wolfssl connection peer certificate contract',
      'failed to initialize WolfSSL library');
    Exit;
  end;

  if (not Assigned(wolfSSL_X509_d2i)) or
     (not Assigned(wolfSSL_i2d_X509)) or
     (not Assigned(wolfSSL_new)) then
  begin
    LLib.Finalize;
    MarkSkip('wolfssl connection peer certificate contract',
      'required baseline WolfSSL X509 helpers are unavailable');
    Exit;
  end;

  LFixture := TWolfSSLCertificate.Create;
  if not LFixture.LoadFromFile('tests/certificate/test_certs/signer_cert.pem') then
  begin
    LFixture.Free;
    LLib.Finalize;
    MarkSkip('wolfssl connection peer certificate contract',
      'failed to load tests/certificate/test_certs/signer_cert.pem fixture');
    Exit;
  end;

  LExpectedFingerprint := LFixture.GetFingerprintSHA256;
  GStubPeerCertificateDER := LFixture.SaveToDER;

  LOriginalGetPeerCertificate := wolfSSL_get_peer_certificate;
  LOriginalX509D2I := wolfSSL_X509_d2i;
  LOriginalI2DX509 := wolfSSL_i2d_X509;
  GSourcePeerCertificateD2I := LOriginalX509D2I;

  LCtx := LLib.CreateContext(sslCtxClient);
  LStream := TMemoryStream.Create;
  LConn := nil;
  try
    LConn := TWolfSSLConnection.Create(LCtx, LStream);
    wolfSSL_get_peer_certificate := @StubWolfSSLGetPeerCertificateFromDER;

    LCert := LConn.GetPeerCertificate;
    AssertTrue('GetPeerCertificate should materialize a certificate',
      LCert <> nil);
    AssertTrue('GetPeerCertificate fingerprint should match the fixture',
      (LCert <> nil) and SameText(LCert.GetFingerprintSHA256, LExpectedFingerprint));
    AssertTrue('GetPeerCertificate must return an owned copy instead of the source native handle',
      (LCert <> nil) and (CaptureCertHandle(LCert) <> nil) and
      (CaptureCertHandle(LCert) <> Pointer(GSourcePeerCertificateHandle)));

    wolfSSL_i2d_X509 := nil;
    LCert := LConn.GetPeerCertificate;
    AssertTrue('GetPeerCertificate should fail closed when cert-copy helper is unavailable',
      LCert = nil);
  finally
    wolfSSL_get_peer_certificate := LOriginalGetPeerCertificate;
    wolfSSL_X509_d2i := LOriginalX509D2I;
    wolfSSL_i2d_X509 := LOriginalI2DX509;
    GSourcePeerCertificateD2I := nil;
    GSourcePeerCertificateHandle := nil;
    SetLength(GStubPeerCertificateDER, 0);
    if Assigned(LConn) then
      LConn.Free;
    LStream.Free;
    LFixture.Free;
    LLib.Finalize;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('WolfSSL Connection Peer Certificate Contract Test');
  WriteLn('========================================');

  try
    TestConnectionPeerCertificateMustMaterializeOwnedCopy;

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
