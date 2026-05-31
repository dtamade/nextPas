program test_x509_chain_ecdsa;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.crypto.x509verify, nextpas.core.tls.x509;

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

procedure TestEmptyChain;
var
  LStore: TX509TrustStore;
  LResult: TX509VerifyResult;
  LEmpty: array of TX509Certificate;
begin
  WriteLn('TestEmptyChain');
  SetLength(LEmpty, 0);
  LStore := TX509TrustStore.Create;
  try
    LResult := VerifyX509Chain(LEmpty, LStore, '');
    Check(not LResult.IsValid, 'Empty chain rejected');
    Check(Pos('Empty', LResult.ErrorMessage) > 0, 'Error mentions empty');
  finally
    LStore.Free;
  end;
end;

procedure TestMatchHostnameEmpty;
var
  LCert: TX509Certificate;
begin
  WriteLn('TestMatchHostnameEmpty');
  LCert := TX509Certificate.Create;
  try
    Check(MatchHostname('', LCert), 'Empty hostname always matches');
  finally
    LCert.Free;
  end;
end;

procedure TestTrustStoreCreateDestroy;
var
  LStore: TX509TrustStore;
begin
  WriteLn('TestTrustStoreCreateDestroy');
  LStore := TX509TrustStore.Create;
  try
    Check(True, 'TrustStore created without crash');
  finally
    LStore.Free;
  end;
end;

procedure TestUntrustedSingleCert;
var
  LStore: TX509TrustStore;
  LCert: TX509Certificate;
  LChain: array[0..0] of TX509Certificate;
  LResult: TX509VerifyResult;
begin
  WriteLn('TestUntrustedSingleCert');
  LStore := TX509TrustStore.Create;
  LCert := TX509Certificate.Create;
  try
    LChain[0] := LCert;
    LResult := VerifyX509Chain(LChain, LStore, '');
    Check(not LResult.IsValid, 'Untrusted cert rejected');
  finally
    LCert.Free;
    LStore.Free;
  end;
end;

procedure TestP384ECDSASHA384Chain;
const
  CA_PEM =
    '-----BEGIN CERTIFICATE-----' + LineEnding +
    'MIIB2TCCAV+gAwIBAgIUNc3zmQpWp7qV6AgSzE5YWsIvl7gwCgYIKoZIzj0EAwMw' + LineEnding +
    'GTEXMBUGA1UEAwwOZmFmYWZhLXAzODQtY2EwIBcNMjYwNTI3MTY1NjUyWhgPMjA1' + LineEnding +
    'MzEwMTIxNjU2NTJaMBkxFzAVBgNVBAMMDmZhZmFmYS1wMzg0LWNhMHYwEAYHKoZI' + LineEnding +
    'zj0CAQYFK4EEACIDYgAEY7E9jRCYepZTj0kWEXfXwnhudBCmD13qCJ+nxJwFvddX' + LineEnding +
    '92sUEnhftlEXT/K5Q2tto4WgLYL6TW1r1y8MJ7+jPuRqhZ70+VtcYB7xcLKtJM6V' + LineEnding +
    'HM+ZdC+IWcUrsR6lDPFTo2YwZDASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB' + LineEnding +
    '/wQEAwIBBjAdBgNVHQ4EFgQU1BraDXCXh2/xLS+ogjdzVP/37+kwHwYDVR0jBBgw' + LineEnding +
    'FoAU1BraDXCXh2/xLS+ogjdzVP/37+kwCgYIKoZIzj0EAwMDaAAwZQIwTVYJF/us' + LineEnding +
    'P+KsxPiY3Le9sfIycZePfdkWqXPjgGyKy1wcssfBEdKNKN70t+5KqOknAjEA5lvx' + LineEnding +
    'U6wsuTJsaQsz+HkPWqR4tnRZRWv/QtQ5+7yyXkMgdaqfho++66E0koPKrwHg' + LineEnding +
    '-----END CERTIFICATE-----' + LineEnding;
  LEAF_PEM =
    '-----BEGIN CERTIFICATE-----' + LineEnding +
    'MIIB/zCCAYSgAwIBAgIUeYUlAkPmMEzIAJs/wgbwS60sZdgwCgYIKoZIzj0EAwMw' + LineEnding +
    'GTEXMBUGA1UEAwwOZmFmYWZhLXAzODQtY2EwIBcNMjYwNTI3MTY1NjUyWhgPMjA1' + LineEnding +
    'MzEwMTIxNjU2NTJaMCAxHjAcBgNVBAMMFWZhZmFmYS1wMzg0LWxlYWYudGVzdDB2' + LineEnding +
    'MBAGByqGSM49AgEGBSuBBAAiA2IABMkM/H6RCeeyakTT841LS+J2UctqWo6/SAaB' + LineEnding +
    '6fLUSYpTIKOd/QIx8iGinDauVZyXuH7ZCR3I7d0VnMVAjxNty6Bf7M/zACgKoEYd' + LineEnding +
    'kuxiFps2no3X/bOUrP0NhYICDPuJF6OBgzCBgDAMBgNVHRMBAf8EAjAAMA4GA1Ud' + LineEnding +
    'DwEB/wQEAwIHgDAgBgNVHREEGTAXghVmYWZhZmEtcDM4NC1sZWFmLnRlc3QwHQYD' + LineEnding +
    'VR0OBBYEFFAqvnlr7yWL8bdN2GpqGWTQ8vHiMB8GA1UdIwQYMBaAFNQa2g1wl4dv' + LineEnding +
    '8S0vqII3c1T/9+/pMAoGCCqGSM49BAMDA2kAMGYCMQDBGnIvnQAKNblnDgTQf6b6' + LineEnding +
    'jt9G3GjR4tN9OLdSkPnM1PSmM9hLGsGdQBTn0XIYIQMCMQDtYaH7U08fwfVMie50' + LineEnding +
    'TyHDDP7KdM2VIvhLrDlhIoHTGRS38cWnPJgm7oVgbarxwIQ=' + LineEnding +
    '-----END CERTIFICATE-----' + LineEnding;
var
  LStore: TX509TrustStore;
  LCA, LLeaf: TX509Certificate;
  LChain: array[0..0] of TX509Certificate;
  LResult: TX509VerifyResult;
begin
  WriteLn('TestP384ECDSASHA384Chain');
  LStore := TX509TrustStore.Create;
  LCA := TX509Certificate.Create;
  LLeaf := TX509Certificate.Create;
  try
    LCA.LoadFromPEM(CA_PEM);
    LLeaf.LoadFromPEM(LEAF_PEM);
    LStore.AddTrustedCertificate(LCA);
    LChain[0] := LLeaf;

    Check(LLeaf.SignatureAlgorithm.OID = '1.2.840.10045.4.3.3',
      'Leaf uses ecdsa-with-SHA384');
    Check(SameText(LCA.PublicKeyInfo.ECCurve, 'secp384r1'), 'Issuer curve is secp384r1');
    Check(Length(LCA.PublicKeyInfo.ECPoint) = 97, 'Issuer P-384 public key is 97-byte uncompressed point');

    LResult := VerifyX509Chain(LChain, LStore, 'fafafa-p384-leaf.test');
    Check(LResult.IsValid, 'P-384 ECDSA-SHA384 certificate chain verifies: ' + LResult.ErrorMessage);
  finally
    LLeaf.Free;
    LCA.Free;
    LStore.Free;
  end;
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestEmptyChain;
  TestMatchHostnameEmpty;
  TestTrustStoreCreateDestroy;
  TestUntrustedSingleCert;
  TestP384ECDSASHA384Chain;

  WriteLn;
  WriteLn('X509 Chain tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
