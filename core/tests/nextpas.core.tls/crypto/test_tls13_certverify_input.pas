program test_tls13_certverify_input;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.tls13.servercertverify;

const
  SERVER_CONTEXT = 'TLS 1.3, server CertificateVerify';
  CLIENT_CONTEXT = 'TLS 1.3, client CertificateVerify';

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

procedure FillHash(var AHash: TBytes; ALength: Integer; AStart: Byte);
var
  I: Integer;
begin
  SetLength(AHash, ALength);
  for I := 0 to ALength - 1 do
    AHash[I] := Byte(AStart + I);
end;

procedure CheckCertVerifyInput(const AInput: TBytes; const AContext: string;
  const AHash: TBytes; const AMessage: string);
var
  I: Integer;
  LHashOffset: Integer;
begin
  Check(Length(AInput) = 64 + Length(AContext) + 1 + Length(AHash),
    AMessage + ' length should match context and transcript hash');

  for I := 0 to 63 do
    Check(AInput[I] = $20, AMessage + ' should start with 64 spaces');

  for I := 1 to Length(AContext) do
    Check(AInput[63 + I] = Byte(Ord(AContext[I])),
      AMessage + ' context bytes should be copied verbatim');

  Check(AInput[64 + Length(AContext)] = 0,
    AMessage + ' context separator should be NUL');

  LHashOffset := 64 + Length(AContext) + 1;
  for I := 0 to Length(AHash) - 1 do
    Check(AInput[LHashOffset + I] = AHash[I],
      AMessage + ' transcript hash bytes should be copied verbatim');
end;

procedure TestServerCertificateVerifyInputSHA256;
var
  LHash: TBytes;
  LInput: TBytes;
begin
  WriteLn('Test: TLS 1.3 server CertificateVerify input SHA-256');
  FillHash(LHash, 32, $10);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LHash);
  CheckCertVerifyInput(LInput, SERVER_CONTEXT, LHash, 'server SHA-256 input');
end;

procedure TestServerCertificateVerifyInputSHA384;
var
  LHash: TBytes;
  LInput: TBytes;
begin
  WriteLn('Test: TLS 1.3 server CertificateVerify input SHA-384');
  FillHash(LHash, 48, $40);
  LInput := BuildTLS13ServerCertificateVerifyInputSHA256(LHash);
  CheckCertVerifyInput(LInput, SERVER_CONTEXT, LHash, 'server SHA-384 input');
end;

procedure TestClientCertificateVerifyInputSHA256;
var
  LHash: TBytes;
  LInput: TBytes;
begin
  WriteLn('Test: TLS 1.3 client CertificateVerify input SHA-256');
  FillHash(LHash, 32, $70);
  LInput := BuildTLS13ClientCertificateVerifyInput(LHash);
  CheckCertVerifyInput(LInput, CLIENT_CONTEXT, LHash, 'client SHA-256 input');
end;

begin
  WriteLn('=== TLS 1.3 CertificateVerify Input Tests ===');
  WriteLn('');

  TestServerCertificateVerifyInputSHA256;
  TestServerCertificateVerifyInputSHA384;
  TestClientCertificateVerifyInputSHA256;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
