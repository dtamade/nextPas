program test_tls12_clientauth;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.tls12.clientauth, nextpas.core.tls.x509;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

procedure TestBuildClientCertificateEmpty;
var
  LConfig: TTLS12ClientCertConfig;
  LResult: TBytes;
begin
  WriteLn('TestBuildClientCertificateEmpty');
  FillChar(LConfig, SizeOf(LConfig), 0);
  SetLength(LConfig.CertificateDER, 0);
  LConfig.Certificate := nil;
  LResult := TLS12BuildClientCertificate(LConfig);
  // Handshake type 11 (Certificate), length 6 (3+3+0)
  Check(Length(LResult) > 4, 'Non-empty result');
  Check(LResult[0] = 11, 'Handshake type = Certificate (11)');
end;

procedure TestBuildClientCertificateWithData;
var
  LConfig: TTLS12ClientCertConfig;
  LResult: TBytes;
  LCertLen: Integer;
begin
  WriteLn('TestBuildClientCertificateWithData');
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.CertificateDER := TBytes.Create($30, $82, $01, $00, $AA, $BB);
  LConfig.Certificate := nil;
  LResult := TLS12BuildClientCertificate(LConfig);

  LCertLen := 6;
  Check(LResult[0] = 11, 'Type = Certificate');
  // Total length = 3 (certs_len) + 3 (cert_len) + 6 (cert) = 12
  Check(LResult[3] = 12, 'Body length');
  // certificates_length = 3 + 6 = 9
  Check(LResult[6] = 9, 'Certificates list length');
  // single cert length = 6
  Check(LResult[9] = LCertLen, 'Single cert length');
  // cert data starts at offset 10
  Check(LResult[10] = $30, 'Cert data[0]');
  Check(LResult[15] = $BB, 'Cert data[5]');
end;

procedure TestBuildCertificateVerifyNoKey;
var
  LConfig: TTLS12ClientCertConfig;
  LHash: TBytes;
  LResult: TBytes;
  LError: string;
begin
  WriteLn('TestBuildCertificateVerifyNoKey');
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.Certificate := TX509Certificate.Create;
  try
    SetLength(LConfig.PrivateKeyDER, 0);
    SetLength(LHash, 32);
    FillChar(LHash[0], 32, $AA);
    LResult := TLS12BuildCertificateVerify(LConfig, LHash, False, LError);
    Check(Length(LResult) = 0, 'Empty result without valid key');
    Check(Length(LError) > 0, 'Error reported');
  finally
    LConfig.Certificate.Free;
  end;
end;

procedure TestConfigRecordFields;
var
  LConfig: TTLS12ClientCertConfig;
begin
  WriteLn('TestConfigRecordFields');
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.CertificateDER := TBytes.Create($01, $02);
  LConfig.PrivateKeyDER := TBytes.Create($03, $04);
  Check(Length(LConfig.CertificateDER) = 2, 'CertificateDER field');
  Check(Length(LConfig.PrivateKeyDER) = 2, 'PrivateKeyDER field');
  Check(LConfig.Certificate = nil, 'Certificate nil by default');
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestBuildClientCertificateEmpty;
  TestBuildClientCertificateWithData;
  TestBuildCertificateVerifyNoKey;
  TestConfigRecordFields;

  WriteLn;
  WriteLn('TLS12 ClientAuth tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
