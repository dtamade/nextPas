program test_x509verify;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils, Classes, Process,
  nextpas.core.tls.x509,
  nextpas.core.crypto.x509verify;

var
  GPass, GFail: Integer;

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

function EnsureTestCert: string;
var LRet: Integer;
begin
  Result := '/tmp/test_cert.der';
  if not FileExists(Result) then
  begin
    LRet := ExecuteProcess('/usr/bin/openssl',
      'req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 ' +
      '-keyout /tmp/test_key.pem -out /tmp/test_cert.pem -days 1 -nodes ' +
      '-subj "/CN=test.example.com" -addext "subjectAltName=DNS:test.example.com,DNS:*.example.com"');
    if LRet <> 0 then
    begin
      WriteLn('SKIP: openssl not available');
      Halt(0);
    end;
    ExecuteProcess('/usr/bin/openssl', 'x509 -in /tmp/test_cert.pem -outform DER -out ' + Result);
  end;
end;

procedure TestMatchHostname;
var
  LCert: TX509Certificate;
begin
  LCert := LoadCertFromFile('/tmp/test_cert.der');
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
  try
    LCert := LoadCertFromFile('/tmp/test_cert.der');
    LStore.AddTrustedCertificate(LCert);
    Check('trust store: added cert is trusted', LStore.IsTrusted(LCert));

    // A different cert should not be trusted
    // (We only have one cert, so just verify the store works)
    Check('trust store: find issuer (self-signed)', LStore.FindIssuer(LCert) <> nil);
  finally
    LStore.Free;
  end;
end;

procedure TestVerifyChain_SelfSigned;
var
  LCert: TX509Certificate;
  LStore: TX509TrustStore;
  LChain: array of TX509Certificate;
  LResult: TX509VerifyResult;
begin
  LCert := LoadCertFromFile('/tmp/test_cert.der');
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
  LCert := LoadCertFromFile('/tmp/test_cert.der');
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

begin
  GPass := 0;
  GFail := 0;
  EnsureTestCert;
  WriteLn('=== X509 Verify Tests ===');
  WriteLn;

  TestMatchHostname;
  TestTrustStore;
  TestVerifyChain_SelfSigned;
  TestVerifyChain_WrongHostname;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then Halt(1);
end.
