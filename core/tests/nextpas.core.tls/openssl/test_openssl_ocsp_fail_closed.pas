program test_openssl_ocsp_fail_closed;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.api.consts,
  fafafa.ssl;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('❌ FAIL: ', AMessage);
    Halt(1);
  end;
  WriteLn('✅ PASS: ', AMessage);
end;

procedure TestMissingAIA;
var
  LLib: ISSLLibrary;
  LCAOpts, LLeafOpts: TCertGenOptions;
  LCAPEM, LCAKeyPEM: string;
  LLeafPEM, LLeafKeyPEM: string;
  LCACert, LLeafCert: ISSLCertificate;
  LStore: ISSLCertificateStore;
  LRes: TSSLCertVerifyResult;
  LOk: Boolean;
begin
  WriteLn('--- Test: OCSP requested, missing AIA -> fail closed (OCSP_VERIFY_NEEDED) ---');

  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Check(LLib.Initialize, 'OpenSSL library initialized');

  LCAOpts := TCertificateUtils.DefaultGenOptions;
  LCAOpts.CommonName := 'Test Root CA';
  LCAOpts.Organization := 'Test Org';
  LCAOpts.ValidDays := 3650;
  LCAOpts.IsCA := True;

  Check(TCertificateUtils.GenerateSelfSigned(LCAOpts, LCAPEM, LCAKeyPEM), 'Generated CA certificate');

  LLeafOpts := TCertificateUtils.DefaultGenOptions;
  LLeafOpts.CommonName := 'leaf.test';
  LLeafOpts.ValidDays := 30;
  LLeafOpts.IsCA := False;
  LLeafOpts.OCSPResponderURL := ''; // No AIA

  Check(TCertificateUtils.GenerateSigned(LLeafOpts, LCAPEM, LCAKeyPEM, LLeafPEM, LLeafKeyPEM), 'Generated leaf certificate');

  LCACert := TSSLFactory.CreateCertificate(sslOpenSSL);
  Check(LCACert.LoadFromPEM(LCAPEM), 'Loaded CA PEM into ISSLCertificate');

  LLeafCert := TSSLFactory.CreateCertificate(sslOpenSSL);
  Check(LLeafCert.LoadFromPEM(LLeafPEM), 'Loaded leaf PEM into ISSLCertificate');

  LStore := TSSLFactory.CreateCertificateStore(sslOpenSSL);
  Check(LStore.AddCertificate(LCACert), 'Added CA to certificate store');

  LOk := LLeafCert.VerifyEx(LStore, [sslCertVerifyCheckOCSP], LRes);
  Check(not LOk, 'VerifyEx should fail');
  Check(LRes.ErrorCode = X509_V_ERR_OCSP_VERIFY_NEEDED, 'ErrorCode = X509_V_ERR_OCSP_VERIFY_NEEDED');
end;

procedure TestUnreachableResponder;
var
  LLib: ISSLLibrary;
  LCAOpts, LLeafOpts: TCertGenOptions;
  LCAPEM, LCAKeyPEM: string;
  LLeafPEM, LLeafKeyPEM: string;
  LCACert, LLeafCert: ISSLCertificate;
  LStore: ISSLCertificateStore;
  LRes: TSSLCertVerifyResult;
  LOk: Boolean;
begin
  WriteLn('--- Test: OCSP requested, unreachable responder -> fail closed (OCSP_VERIFY_FAILED) ---');

  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Check(LLib.Initialize, 'OpenSSL library initialized');

  LCAOpts := TCertificateUtils.DefaultGenOptions;
  LCAOpts.CommonName := 'Test Root CA';
  LCAOpts.Organization := 'Test Org';
  LCAOpts.ValidDays := 3650;
  LCAOpts.IsCA := True;

  Check(TCertificateUtils.GenerateSelfSigned(LCAOpts, LCAPEM, LCAKeyPEM), 'Generated CA certificate');

  LLeafOpts := TCertificateUtils.DefaultGenOptions;
  LLeafOpts.CommonName := 'leaf.test';
  LLeafOpts.ValidDays := 30;
  LLeafOpts.IsCA := False;
  // Point to a local, likely closed port (fast failure, no external network).
  LLeafOpts.OCSPResponderURL := 'http://127.0.0.1:1';

  Check(TCertificateUtils.GenerateSigned(LLeafOpts, LCAPEM, LCAKeyPEM, LLeafPEM, LLeafKeyPEM), 'Generated leaf certificate with AIA OCSP URL');

  LCACert := TSSLFactory.CreateCertificate(sslOpenSSL);
  Check(LCACert.LoadFromPEM(LCAPEM), 'Loaded CA PEM into ISSLCertificate');

  LLeafCert := TSSLFactory.CreateCertificate(sslOpenSSL);
  Check(LLeafCert.LoadFromPEM(LLeafPEM), 'Loaded leaf PEM into ISSLCertificate');

  LStore := TSSLFactory.CreateCertificateStore(sslOpenSSL);
  Check(LStore.AddCertificate(LCACert), 'Added CA to certificate store');

  LOk := LLeafCert.VerifyEx(LStore, [sslCertVerifyCheckOCSP], LRes);
  Check(not LOk, 'VerifyEx should fail');
  Check(
    LRes.ErrorCode = X509_V_ERR_OCSP_VERIFY_FAILED,
    Format('ErrorCode expected X509_V_ERR_OCSP_VERIFY_FAILED, got %d (%s)', [LRes.ErrorCode, LRes.ErrorMessage])
  );
end;

begin
  try
    TestMissingAIA;
    WriteLn;
    TestUnreachableResponder;
    WriteLn;
    WriteLn('All OCSP fail-closed tests passed.');
  except
    on E: Exception do
    begin
      WriteLn('❌ Unhandled exception: ', E.Message);
      Halt(1);
    end;
  end;
end.
