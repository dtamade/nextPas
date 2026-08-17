program test_x509verify;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.system.sysutils, nextpas.core.system.classes,
  nextpas.core.process,   { ExecuteProcess:openssl 证书夹具生成 }
  nextpas.core.tls.x509,
  nextpas.core.time,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.x509verify,
  nextpas.core.test;

var
  GCertPath, GKeyPath, GPemPath: string;

function LoadCertFromFile(const APath: string): TX509Certificate;
var LStream: TFileStream; LData: TBytes;
begin
  Result := TX509Certificate.Create;
  LStream := TFileStream.Create(APath, fmOpenRead);
  try
    SetLength(LData, LStream.Size);
    if LStream.Size > 0 then LStream.ReadBuffer(LData[0], LStream.Size);
    Result.LoadFromDER(LData);
  finally LStream.Free; end;
end;

function TempFilePath(const ASuffix: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas_x509verify_' + IntToStr(GetProcessID) + ASuffix;
end;

function EnsureTestCert: Boolean;
var LRet: Integer;
begin
  Result := False;
  GCertPath := TempFilePath('.der');
  GKeyPath := TempFilePath('.key.pem');
  GPemPath := TempFilePath('.cert.pem');
  DeleteFile(GCertPath); DeleteFile(GKeyPath); DeleteFile(GPemPath);
  LRet := ExecuteProcess('/usr/bin/openssl',
    'req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 ' +
    '-keyout ' + GKeyPath + ' -out ' + GPemPath + ' -days 1 -nodes ' +
    '-subj "/CN=test.example.com" -addext "subjectAltName=DNS:test.example.com,DNS:*.example.com"');
  if LRet <> 0 then Exit;
  LRet := ExecuteProcess('/usr/bin/openssl',
    'x509 -in ' + GPemPath + ' -outform DER -out ' + GCertPath);
  if LRet <> 0 then Exit;
  Result := True;
end;

function BuildCurrentValidCertPEM(out ACertPEM: string): Boolean;
var LOptions: TCertGenOptions; LKeyPEM: string;
begin
  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.CommonName := 'x509verify-utc-contract.local';
  LOptions.Organization := 'nextpas core';
  LOptions.ValidDays := 1;
  LOptions.NotBefore := Now - (1.0 / 24.0);
  LOptions.NotAfter := Now + (1.0 / 24.0);
  Result := TCertificateUtils.GenerateSelfSigned(LOptions, ACertPEM, LKeyPEM);
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  if not EnsureTestCert then begin
    WriteLn('SKIP: openssl not available');
    Halt(0);
  end;

  LSuite := TTestSuite.Create('x509verify');

  LSuite.SetTeardown(procedure begin
    if GCertPath <> '' then DeleteFile(GCertPath);
    if GKeyPath <> '' then DeleteFile(GKeyPath);
    if GPemPath <> '' then DeleteFile(GPemPath);
  end);

  LSuite.Test('hostname matching', procedure
  var LCert: TX509Certificate;
  begin
    LCert := LoadCertFromFile(GCertPath);
    try
      CheckTrue(MatchHostname('test.example.com', LCert));
      CheckTrue(MatchHostname('sub.example.com', LCert));
      CheckTrue(not MatchHostname('a.b.example.com', LCert));
      CheckTrue(not MatchHostname('example.com', LCert));
      CheckTrue(not MatchHostname('other.org', LCert));
      CheckTrue(not MatchHostname('', LCert));
    finally LCert.Free; end;
  end);

  LSuite.Test('trust store', procedure
  var LStore: TX509TrustStore; LCert: TX509Certificate;
  begin
    LStore := TX509TrustStore.Create;
    LCert := LoadCertFromFile(GCertPath);
    try
      LStore.AddTrustedCertificate(LCert);
      CheckTrue(LCert.IsValidNow);
      CheckTrue(LStore.IsTrusted(LCert));
      CheckTrue(LStore.FindIssuer(LCert) <> nil);
    finally LStore.Free; LCert.Free; end;
  end);

  LSuite.Test('self-signed chain', procedure
  var LCert: TX509Certificate; LStore: TX509TrustStore;
    LChain: array of TX509Certificate; LResult: TX509VerifyResult;
  begin
    LCert := LoadCertFromFile(GCertPath);
    LStore := TX509TrustStore.Create;
    try
      LStore.AddTrustedCertificate(LCert);
      SetLength(LChain, 1); LChain[0] := LCert;
      LResult := VerifyX509Chain(LChain, LStore, 'test.example.com');
      CheckTrue(LResult.IsValid);
      CheckEqual(1, LResult.ChainDepth);
    finally LStore.Free; LCert.Free; end;
  end);

  LSuite.Test('wrong hostname rejected', procedure
  var LCert: TX509Certificate; LStore: TX509TrustStore;
    LChain: array of TX509Certificate; LResult: TX509VerifyResult;
  begin
    LCert := LoadCertFromFile(GCertPath);
    LStore := TX509TrustStore.Create;
    try
      LStore.AddTrustedCertificate(LCert);
      SetLength(LChain, 1); LChain[0] := LCert;
      LResult := VerifyX509Chain(LChain, LStore, 'wrong.hostname.org');
      CheckTrue(not LResult.IsValid);
    finally LStore.Free; LCert.Free; end;
  end);

  LSuite.Test('UTC validity time', procedure
  var LCert: TX509Certificate; LCertPEM: string;
    LStore: TX509TrustStore; LChain: array of TX509Certificate;
    LResult: TX509VerifyResult;
  begin
    CheckTrue(BuildCurrentValidCertPEM(LCertPEM));
    LCert := TX509Certificate.Create;
    LStore := TX509TrustStore.Create;
    try
      LCert.LoadFromPEM(LCertPEM);
      CheckTrue(LCert.Validity.NotBefore < DateTimeUtcNow);
      CheckTrue(LCert.Validity.NotAfter > DateTimeUtcNow);
      LStore.AddTrustedCertificate(LCert);
      SetLength(LChain, 1); LChain[0] := LCert;
      LResult := VerifyX509Chain(LChain, LStore, 'x509verify-utc-contract.local');
      CheckTrue(LResult.IsValid);
    finally LStore.Free; LCert.Free; end;
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.tls.x509verify');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
