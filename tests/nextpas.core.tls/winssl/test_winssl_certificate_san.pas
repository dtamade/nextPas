program test_winssl_certificate_san;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

{
  WinSSL SAN Parsing Test

  Purpose:
    Validate that the WinSSL backend parses SubjectAltName (SAN) extensions
    consistently with the OpenSSL backend, including DNS and IP entries.

  Notes:
    - This test must be run on Windows (uses Schannel APIs).
    - It loads a DER-encoded test certificate generated from tests/certs/san-test.pem:
        tests/certs/winssl-san-test.cer
}

uses
  {$IFDEF WINDOWS}
  Windows,
  {$ELSE}
  {$ERROR 'This test requires Windows platform'}
  {$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.lib,
  nextpas.core.tls.winssl.certificate;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

function ResolveRepoFixturePath(const ARepoRelativePath: string): string;
const
  CandidatePrefixes: array[0..3] of string = (
    '',
    '../',
    '../../',
    '../../../'
  );
var
  I: Integer;
  LCandidate: string;
begin
  Result := '';
  for I := Low(CandidatePrefixes) to High(CandidatePrefixes) do
  begin
    LCandidate := ExpandFileName(CandidatePrefixes[I] + ARepoRelativePath);
    if FileExists(LCandidate) then
    begin
      Result := LCandidate;
      Exit;
    end;
  end;
end;

procedure AssertTrue(const TestName: string; Condition: Boolean);
begin
  Write('  [TEST] ', TestName, '... ');
  if Condition then
  begin
    WriteLn('PASS');
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('FAIL');
    Inc(TestsFailed);
  end;
end;

procedure AssertNotNil(const TestName: string; Ptr: Pointer);
begin
  AssertTrue(TestName, Ptr <> nil);
end;

procedure TestWinSSLSAN;
var
  Lib: ISSLLibrary;
  Cert: ISSLCertificate;
  SANs: TSSLStringArray;
  Info: TSSLCertificateInfo;
  HasSanTest, HasExample, HasIp: Boolean;
  I: Integer;
  InInfo: Boolean;
  CertPath: string;
begin
  WriteLn;
  WriteLn('=== WinSSL Certificate SAN Parsing Tests ===');

  Lib := CreateWinSSLLibrary;
  AssertNotNil('CreateWinSSLLibrary returns instance', Pointer(Lib));
  if (Lib = nil) or (not Lib.Initialize) then
  begin
    WriteLn('  Note: WinSSL library initialization failed, skipping SAN tests');
    AssertTrue('Initialize WinSSL library', False);
    Exit;
  end;

  Cert := Lib.CreateCertificate;
  if Cert = nil then
  begin
    WriteLn('  Note: CreateCertificate returned nil, skipping SAN tests');
    AssertTrue('CreateCertificate returns non-nil', False);
    Exit;
  end;

  CertPath := ResolveRepoFixturePath('tests/certs/winssl-san-test.cer');
  if CertPath = '' then
  begin
    WriteLn('  Note: SAN test certificate path could not be resolved');
    AssertTrue('SAN test certificate file exists', False);
    Exit;
  end;

  if not Cert.LoadFromFile(CertPath) then
  begin
    WriteLn('  Note: LoadFromFile failed for SAN test certificate');
    AssertTrue('LoadFromFile succeeds', False);
    Exit;
  end;

  SANs := Cert.GetSubjectAltNames;
  AssertTrue('GetSubjectAltNames returns non-empty array', Length(SANs) > 0);
  HasSanTest := False;
  HasExample := False;
  HasIp := False;
  for I := 0 to High(SANs) do
  begin
    if SANs[I] = 'san-test.local' then HasSanTest := True;
    if SANs[I] = 'example.test' then HasExample := True;
    if SANs[I] = '127.0.0.1' then HasIp := True;
  end;
  AssertTrue('SANs contain DNS:san-test.local', HasSanTest);
  AssertTrue('SANs contain DNS:example.test', HasExample);
  AssertTrue('SANs contain IP:127.0.0.1', HasIp);

  Info := Cert.GetInfo;
  InInfo := False;
  for I := 0 to High(Info.SubjectAltNames) do
  begin
    if Info.SubjectAltNames[I] = 'san-test.local' then
    begin
      InInfo := True;
      Break;
    end;
  end;
  AssertTrue('Info.SubjectAltNames contains DNS:san-test.local', InInfo);
  AssertTrue('VerifyHostname accepts DNS:san-test.local',
    Cert.VerifyHostname('san-test.local'));
  AssertTrue('VerifyHostname accepts DNS:example.test',
    Cert.VerifyHostname('example.test'));
  AssertTrue('VerifyHostname accepts IP:127.0.0.1',
    Cert.VerifyHostname('127.0.0.1'));
  AssertTrue('VerifyHostname rejects unrelated hostname',
    not Cert.VerifyHostname('wrong.test'));

  CertPath := ResolveRepoFixturePath('tests/certificate/test_certs/san_cn_conflict_cert.pem');
  if CertPath = '' then
  begin
    WriteLn('  Note: SAN-vs-CN conflict fixture path could not be resolved');
    AssertTrue('SAN-vs-CN conflict fixture file exists', False);
    Exit;
  end;
  if not Cert.LoadFromFile(CertPath) then
  begin
    WriteLn('  Note: LoadFromFile failed for SAN-vs-CN conflict fixture');
    AssertTrue('Load SAN-vs-CN conflict fixture succeeds', False);
    Exit;
  end;
  AssertTrue('VerifyHostname prioritizes SAN over CN when SAN exists',
    not Cert.VerifyHostname('cn-only.example.com'));
  AssertTrue('VerifyHostname still matches SAN DNS entry in SAN-vs-CN fixture',
    Cert.VerifyHostname('alt.example.com'));

  CertPath := ResolveRepoFixturePath('tests/certificate/test_certs/san_wildcard_cert.pem');
  if CertPath = '' then
  begin
    WriteLn('  Note: wildcard SAN fixture path could not be resolved');
    AssertTrue('Wildcard SAN fixture file exists', False);
    Exit;
  end;
  if not Cert.LoadFromFile(CertPath) then
  begin
    WriteLn('  Note: LoadFromFile failed for wildcard SAN fixture');
    AssertTrue('Load wildcard SAN fixture succeeds', False);
    Exit;
  end;
  AssertTrue('VerifyHostname matches single-label wildcard SAN',
    Cert.VerifyHostname('api.example.com'));
  AssertTrue('VerifyHostname rejects multi-label wildcard subdomain',
    not Cert.VerifyHostname('deep.api.example.com'));
end;

procedure PrintSummary;
var
  Total: Integer;
begin
  Total := TestsPassed + TestsFailed;
  WriteLn;
  WriteLn('========================================');
  WriteLn('WinSSL SAN Test Summary');
  WriteLn('========================================');
  WriteLn('Total tests: ', Total);
  WriteLn('Passed:      ', TestsPassed);
  WriteLn('Failed:      ', TestsFailed);
  if Total > 0 then
    WriteLn('Success rate: ', (TestsPassed * 100) div Total, '%');

  if TestsFailed = 0 then
  begin
    WriteLn('✅ ALL SAN TESTS PASSED');
    Halt(0);
  end
  else
  begin
    WriteLn('❌ SOME SAN TESTS FAILED');
    Halt(1);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('WinSSL SAN Parsing Test');
  WriteLn('========================================');

  try
    TestWinSSLSAN;
    PrintSummary;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('FATAL ERROR: ', E.Message);
      Halt(2);
    end;
  end;
end.
