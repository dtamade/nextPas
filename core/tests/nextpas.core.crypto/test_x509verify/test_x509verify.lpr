program test_x509verify;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils, Classes, Process,
  nextpas.core.tls.x509,
  nextpas.core.time,
  nextpas.core.tls.cert.utils,
  nextpas.core.crypto.x509verify;

var
  GPass, GFail: Integer;
  GCertPath, GKeyPath, GPemPath: string;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then begin WriteLn('  [PASS] ', AName); Inc(GPass); end
  else begin WriteLn('  [FAIL] ', AName); Inc(GFail); end;
end;

function LoadCertFromFile(const APath: string): TX509Certificate;
var
  LStream: TFileStream;
  LData: TBytes;
begin
  Result := TX509Certificate.Create;
  LStream := TFileStream.Create(APath, fmOpenRead);
  try
    SetLength(LData, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(LData[0], LStream.Size);
    Result.LoadFromDER(LData);
  finally
    LStream.Free;
  end;
end;

function TempFilePath(const ASuffix: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas_x509verify_' + IntToStr(GetProcessID) + ASuffix;
end;

function EnsureTestCert: string;
var
  LRet: Integer;
begin
  GCertPath := TempFilePath('.der');
  GKeyPath := TempFilePath('.key.pem');
  GPemPath := TempFilePath('.cert.pem');
  DeleteFile(GCertPath);
  DeleteFile(GKeyPath);
  DeleteFile(GPemPath);

  LRet := ExecuteProcess('/usr/bin/openssl',
    'req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 ' +
    '-keyout ' + GKeyPath + ' -out ' + GPemPath + ' -days 1 -nodes ' +
    '-subj "/CN=test.example.com" -addext "subjectAltName=DNS:test.example.com,DNS:*.example.com"');
  if LRet <> 0 then
  begin
    WriteLn('SKIP: openssl not available');
    Halt(0);
  end;

  LRet := ExecuteProcess('/usr/bin/openssl',
    'x509 -in ' + GPemPath + ' -outform DER -out ' + GCertPath);
  if LRet <> 0 then
  begin
    WriteLn('SKIP: openssl DER conversion failed');
    Halt(0);
  end;

  Result := GCertPath;
end;

function BuildCurrentValidCertPEM(out ACertPEM: string): Boolean;
var
  LOptions: TCertGenOptions;
  LKeyPEM: string;
begin
  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.CommonName := 'x509verify-utc-contract.local';
  LOptions.Organization := 'nextpas core';
  LOptions.ValidDays := 1;
  LOptions.NotBefore := Now - (1.0 / 24.0);
  LOptions.NotAfter := Now + (1.0 / 24.0);
  Result := TCertificateUtils.GenerateSelfSigned(LOptions, ACertPEM, LKeyPEM);
end;

procedure TestMatchHostname;
var
  LCert: TX509Certificate;
begin
  LCert := LoadCertFromFile(GCertPath);
  try
    Check('match exact hostname', MatchHostname('test.example.com', LCert));
    Check('match wildcard single label', MatchHostname('sub.example.com', LCert));
    Check('reject multi-level subdomain (RFC 6125)',
      not MatchHostname('a.b.example.com', LCert));
    Check('reject bare domain for wildcard',
      not MatchHostname('example.com', LCert));
    Check('no match different domain', not MatchHostname('other.org', LCert));
    Check('empty hostname no match', not MatchHostname('', LCert));
  finally
    LCert.Free;
  end;
end;

procedure TestTrustStore;
var
  LStore: TX509TrustStore;
  LCert: TX509Certificate;
begin
  LStore := TX509TrustStore.Create;
  LCert := LoadCertFromFile(GCertPath);
  try
    LStore.AddTrustedCertificate(LCert);
    Check('loaded cert is valid now', LCert.IsValidNow);
    Check('trust store: added cert is trusted', LStore.IsTrusted(LCert));
    Check('trust store: find issuer (self-signed)', LStore.FindIssuer(LCert) <> nil);
  finally
    LStore.Free;
    LCert.Free;
  end;
end;

procedure TestVerifyChain_SelfSigned;
var
  LCert: TX509Certificate;
  LStore: TX509TrustStore;
  LChain: array of TX509Certificate;
  LResult: TX509VerifyResult;
begin
  LCert := LoadCertFromFile(GCertPath);
  LStore := TX509TrustStore.Create;
  try
    LStore.AddTrustedCertificate(LCert);
    SetLength(LChain, 1);
    LChain[0] := LCert;

    LResult := VerifyX509Chain(LChain, LStore, 'test.example.com');
    Check('self-signed chain valid', LResult.IsValid);
    Check('chain depth = 1', LResult.ChainDepth = 1);
  finally
    LStore.Free;
    LCert.Free;
  end;
end;

procedure TestVerifyChain_WrongHostname;
var
  LCert: TX509Certificate;
  LStore: TX509TrustStore;
  LChain: array of TX509Certificate;
  LResult: TX509VerifyResult;
begin
  LCert := LoadCertFromFile(GCertPath);
  LStore := TX509TrustStore.Create;
  try
    LStore.AddTrustedCertificate(LCert);
    SetLength(LChain, 1);
    LChain[0] := LCert;

    LResult := VerifyX509Chain(LChain, LStore, 'wrong.hostname.org');
    Check('wrong hostname rejected', not LResult.IsValid);
  finally
    LStore.Free;
    LCert.Free;
  end;
end;

procedure TestVerifyChain_UsesUtcValidityTime;
var
  LCert: TX509Certificate;
  LCertPEM: string;
  LStore: TX509TrustStore;
  LChain: array of TX509Certificate;
  LResult: TX509VerifyResult;
begin
  Check('build UTC contract cert', BuildCurrentValidCertPEM(LCertPEM));
  if LCertPEM = '' then
    Exit;

  LCert := TX509Certificate.Create;
  LStore := TX509TrustStore.Create;
  try
    LCert.LoadFromPEM(LCertPEM);
    Check('UTC contract cert notBefore before current UTC',
      LCert.Validity.NotBefore < DateTimeUtcNow);
    Check('UTC contract cert notAfter after current UTC',
      LCert.Validity.NotAfter > DateTimeUtcNow);

    LStore.AddTrustedCertificate(LCert);
    SetLength(LChain, 1);
    LChain[0] := LCert;

    LResult := VerifyX509Chain(LChain, LStore, 'x509verify-utc-contract.local');
    Check('verify chain uses UTC validity time', LResult.IsValid);
  finally
    LStore.Free;
    LCert.Free;
  end;
end;

begin
  GPass := 0;
  GFail := 0;
  try
    EnsureTestCert;
    WriteLn('=== X509 Verify Tests ===');
    WriteLn;

    TestMatchHostname;
    TestTrustStore;
    TestVerifyChain_SelfSigned;
    TestVerifyChain_WrongHostname;
    TestVerifyChain_UsesUtcValidityTime;

    WriteLn;
    WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  finally
    if GCertPath <> '' then DeleteFile(GCertPath);
    if GKeyPath <> '' then DeleteFile(GKeyPath);
    if GPemPath <> '' then DeleteFile(GPemPath);
  end;

  if GFail > 0 then Halt(1);
end.
