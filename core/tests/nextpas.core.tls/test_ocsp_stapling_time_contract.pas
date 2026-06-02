program test_ocsp_stapling_time_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.time,
  nextpas.core.tls.ocsp,
  nextpas.core.tls.ocsp.cache,
  nextpas.core.tls.ocsp.stapling,
  nextpas.core.tls.x509;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    Inc(GPassCount)
  else
  begin
    Inc(GFailCount);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

procedure TestStaplingResultTimeSemantics;
var
  LResult: TOCSPStaplingResult;
begin
  WriteLn('Test: OCSP stapling result time semantics');

  FillChar(LResult, SizeOf(LResult), 0);
  Check(not LResult.NeedsRefresh,
    'Missing nextUpdate should not require refresh');

  LResult.Status := ossVerified;
  LResult.CertStatus := ocspGood;
  Check(LResult.IsValid, 'Verified good response should be valid');

  LResult.NextUpdate := DateTimeAddSeconds(DateTimeNow, 1800);
  Check(LResult.NeedsRefresh,
    'Response expiring within one hour should require refresh');

  LResult.NextUpdate := DateTimeAddSeconds(DateTimeNow, -7200);
  Check(LResult.NeedsRefresh,
    'Long-expired response should still require refresh');

  LResult.NextUpdate := DateTimeAddSeconds(DateTimeNow, 7200);
  Check(not LResult.NeedsRefresh,
    'Response outside refresh window should remain fresh');
end;

procedure TestStaplingClientEmptyResponseContract;
var
  LConfig: TOCSPStaplingConfig;
  LCache: TOCSPResponseCache;
  LClient: TOCSPStaplingClient;
  LCert: TX509Certificate;
  LIssuerCert: TX509Certificate;
  LResponse: TBytes;
  LResult: TOCSPStaplingResult;
begin
  WriteLn('Test: OCSP stapling client empty response contract');

  LConfig := TOCSPStaplingConfig.Default;
  LCache := TOCSPResponseCache.Create;
  LClient := TOCSPStaplingClient.Create(LConfig, LCache);
  LCert := TX509Certificate.Create;
  LIssuerCert := TX509Certificate.Create;
  try
    SetLength(LResponse, 0);
    LResult := LClient.ProcessStapledResponse(LResponse, LCert, LIssuerCert);
    Check(LResult.Status = ossNotProvided,
      'Empty response should map to ossNotProvided');
    Check(LClient.ShouldRequestStapling,
      'Default client config should request stapling');
  finally
    LIssuerCert.Free;
    LCert.Free;
    LClient.Free;
    LCache.Free;
  end;
end;

begin
  WriteLn('=== OCSP Stapling Time Contract Tests ===');
  WriteLn('');

  TestStaplingResultTimeSemantics;
  TestStaplingClientEmptyResponseContract;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
