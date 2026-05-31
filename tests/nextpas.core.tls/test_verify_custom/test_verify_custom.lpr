program test_verify_custom;
{$mode ObjFPC}{$H+}
uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.verify.custom,
  nextpas.core.crypto.hash;

var GPass: Integer = 0; GFail: Integer = 0;

procedure Check(C: Boolean; const N: string);
begin if C then begin WriteLn('  [PASS] ', N); Inc(GPass); end else begin WriteLn('  [FAIL] ', N); Inc(GFail); end; end;

var
  LVerifier: TSSLPinningVerifier;
  LAllowAll: TSSLAllowAllVerifier;
  LReq: TSSLServerCertificateVerifyRequest;
  LResult: TSSLOperationResult;
  LCertDER, LHash: TBytes;
begin
  WriteLn('=== Custom Certificate Verifier Tests ===');
  WriteLn;

  // Create a fake cert DER
  LCertDER := TBytes.Create(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16);
  LHash := SHA256(LCertDER);

  LReq.ServerName := 'example.com';
  LReq.LeafCertificateDER := LCertDER;
  LReq.DefaultErrorCode := 0;
  LReq.DefaultErrorMessage := '';

  WriteLn('--- Pinning verifier ---');
  LVerifier := TSSLPinningVerifier.Create;
  try
    LVerifier.AddPin(LHash);

    LResult := LVerifier.VerifyServerCertificate(LReq);
    Check(LResult.IsOk, 'matching pin accepted');

    // Wrong cert
    LReq.LeafCertificateDER := TBytes.Create(99,99,99,99);
    LResult := LVerifier.VerifyServerCertificate(LReq);
    Check(LResult.IsErr, 'non-matching pin rejected');

    // Empty cert
    SetLength(LReq.LeafCertificateDER, 0);
    LResult := LVerifier.VerifyServerCertificate(LReq);
    Check(LResult.IsErr, 'empty cert rejected');
  finally
    LVerifier.Free;
  end;

  WriteLn('--- No pins configured ---');
  LVerifier := TSSLPinningVerifier.Create;
  try
    LReq.LeafCertificateDER := LCertDER;
    LResult := LVerifier.VerifyServerCertificate(LReq);
    Check(LResult.IsErr, 'no pins = reject by default');

    LVerifier.AllowIfNoPins := True;
    LResult := LVerifier.VerifyServerCertificate(LReq);
    Check(LResult.IsOk, 'AllowIfNoPins = accept');
  finally
    LVerifier.Free;
  end;

  WriteLn('--- AllowAll verifier ---');
  LAllowAll := TSSLAllowAllVerifier.Create;
  try
    LResult := LAllowAll.VerifyServerCertificate(LReq);
    Check(LResult.IsOk, 'AllowAll always accepts');
  finally
    LAllowAll.Free;
  end;

  WriteLn;
  WriteLn('Results: ', GPass, ' passed, ', GFail, ' failed');
  if GFail > 0 then Halt(1);
end.
