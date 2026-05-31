program test_cert_rotation_expiry_check;

{$mode ObjFPC}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  Math,
  DateUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.cert.rotation,
  nextpas.core.tls.factory;

procedure Fail(const AMessage: string);
begin
  WriteLn('❌ ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

procedure TestExpiryWithValidCertificate;
var
  LCtx: ISSLContext;
  LMgr: TCertificateRotationManager;
  LCfg: TRotationConfig;
  LDaysRemaining: Integer;
  LInfo: TSSLCertificateInfo;
  LExpectedDays: Integer;
  LActualValid: Boolean;
begin
  WriteLn('=== Test: expiry check with valid certificate ===');

  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslOpenSSL);
  AssertTrue(LCtx <> nil, 'Server context should be created');

  LMgr := TCertificateRotationManager.Create(LCtx);
  try
    FillChar(LCfg, SizeOf(LCfg), 0);
    LCfg.CertificatePath := 'tests/certificate/test_certs/signer_cert.pem';
    LCfg.PrivateKeyPath := 'tests/certificate/test_certs/signer_key.pem';
    LCfg.CheckIntervalSeconds := 1;
    LCfg.ExpiryWarningDays := 30;
    LCfg.AutoReloadOnChange := False;
    LCfg.AutoReloadOnExpiry := False;

    AssertTrue(LMgr.Start(LCfg), 'Rotation manager should start with valid certificate files');
    LMgr.Stop;

    LInfo := TSSLHelper.GetCertificateInfo(LCfg.CertificatePath);
    LExpectedDays := Floor(LInfo.NotAfter - Now);

    LActualValid := LMgr.CheckExpiry(LDaysRemaining);

    AssertTrue(LActualValid, 'Expected valid certificate to be reported as valid');
    AssertTrue(LDaysRemaining > 0,
      Format('Expected days remaining > 0, got %d', [LDaysRemaining]));
    AssertTrue(Abs(LDaysRemaining - LExpectedDays) <= 1,
      Format('DaysRemaining should track certificate NotAfter (expected around %d, got %d)',
        [LExpectedDays, LDaysRemaining]));
  finally
    LMgr.Free;
  end;
end;

procedure TestExpiryWithMissingCertificateFile;
var
  LCtx: ISSLContext;
  LMgr: TCertificateRotationManager;
  LCfg: TRotationConfig;
  LDaysRemaining: Integer;
  LActualValid: Boolean;
begin
  WriteLn('=== Test: expiry check with missing certificate file ===');

  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslOpenSSL);
  AssertTrue(LCtx <> nil, 'Server context should be created');

  LMgr := TCertificateRotationManager.Create(LCtx);
  try
    FillChar(LCfg, SizeOf(LCfg), 0);
    LCfg.CertificatePath := 'tests/certificate/test_certs/nonexistent_cert.pem';
    LCfg.PrivateKeyPath := 'tests/certificate/test_certs/signer_key.pem';
    LCfg.CheckIntervalSeconds := 1;
    LCfg.ExpiryWarningDays := 30;

    AssertTrue(not LMgr.Start(LCfg),
      'Rotation manager should reject missing certificate file');

    LActualValid := LMgr.CheckExpiry(LDaysRemaining);
    AssertTrue(not LActualValid,
      'CheckExpiry should return False when certificate path is invalid');
    AssertTrue(LDaysRemaining = 0,
      Format('Expected 0 days remaining for missing certificate, got %d', [LDaysRemaining]));
  finally
    LMgr.Free;
  end;
end;

begin
  WriteLn('fafafa.ssl certificate rotation expiry tests');
  WriteLn('==============================================');

  TestExpiryWithValidCertificate;
  TestExpiryWithMissingCertificateFile;

  WriteLn('==============================================');
  WriteLn('✅ certificate rotation expiry tests passed');
end.
