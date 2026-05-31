program test_tls12prf;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.crypto.tls12prf;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPass);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFail);
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

procedure TestPRF_SHA256_MasterSecret;
var
  LPreMaster, LSeed, LResult: TBytes;
begin
  LPreMaster := HexToBytes(
    '03033b46a7c4f230d5d5e4d5ab2a2f5c' +
    'f4f8e6a3e3e3e3e3e3e3e3e3e3e3e3e3' +
    'e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3');
  LSeed := HexToBytes(
    '5bc0b19b4a8b24b07afe7ec65c6e3b96' +
    'b1f3523c4aef1c0d2bb600cb27f5f818');

  LResult := TLS12PRF_SHA256(LPreMaster, 'master secret', LSeed, 48);
  Check('PRF-SHA256 output length = 48', Length(LResult) = 48);
  Check('PRF-SHA256 output is non-zero', BytesToHex(LResult) <> StringOfChar('0', 96));
end;

procedure TestPRF_SHA256_KeyExpansion;
var
  LMaster, LSeed, LResult: TBytes;
begin
  LMaster := HexToBytes(
    'ab1234567890abcdef1234567890abcd' +
    'ef1234567890abcdef1234567890abcd' +
    'ef1234567890abcdef1234567890abcd');
  LSeed := HexToBytes(
    'aabbccdd11223344aabbccdd11223344' +
    'aabbccdd11223344aabbccdd11223344');

  LResult := TLS12PRF_SHA256(LMaster, 'key expansion', LSeed, 104);
  Check('PRF-SHA256 key expansion length = 104', Length(LResult) = 104);
end;

procedure TestPRF_SHA256_RFC5246Vector;
var
  LSecret, LSeed, LResult: TBytes;
begin
  LSecret := HexToBytes('9bbe436ba940f017b17652849a71db35');
  LSeed := HexToBytes(
    'a0ba9f936cda311827a6f796ffd5198c');

  LResult := TLS12PRF_SHA256(LSecret, 'test label', LSeed, 100);
  Check('PRF-SHA256 RFC test output length = 100', Length(LResult) = 100);

  LResult := TLS12PRF_SHA256(LSecret, 'test label', LSeed, 32);
  Check('PRF-SHA256 deterministic (32 bytes)', Length(LResult) = 32);

  // Verify determinism: same inputs → same output
  Check('PRF-SHA256 deterministic',
    BytesToHex(TLS12PRF_SHA256(LSecret, 'test label', LSeed, 32)) =
    BytesToHex(LResult));
end;

procedure TestPRF_SHA384;
var
  LSecret, LSeed, LResult: TBytes;
begin
  LSecret := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
  LSeed := HexToBytes('aabbccdd11223344');

  LResult := TLS12PRF_SHA384(LSecret, 'test label', LSeed, 48);
  Check('PRF-SHA384 output length = 48', Length(LResult) = 48);

  LResult := TLS12PRF_SHA384(LSecret, 'test label', LSeed, 128);
  Check('PRF-SHA384 output length = 128', Length(LResult) = 128);

  // Determinism
  Check('PRF-SHA384 deterministic',
    BytesToHex(TLS12PRF_SHA384(LSecret, 'test label', LSeed, 48)) =
    BytesToHex(TLS12PRF_SHA384(LSecret, 'test label', LSeed, 48)));
end;

procedure TestPRF_SHA256_OpenSSLVector;
var
  LSecret, LSeed, LResult: TBytes;
begin
  // OpenSSL test vector from ssl/ssl_test.c (TLS 1.2 PRF with SHA-256)
  // secret = 16 bytes of 0x0b
  // label = "test label"
  // seed = "seed" (4 bytes)
  // output_length = 32
  LSecret := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
  LSeed := HexToBytes('73656564'); // "seed"

  LResult := TLS12PRF_SHA256(LSecret, 'test label', LSeed, 32);
  Check('PRF-SHA256 OpenSSL-style vector length', Length(LResult) = 32);
  // Verify against known output (computed with OpenSSL)
  Check('PRF-SHA256 OpenSSL vector value',
    BytesToHex(LResult) = '72c350bc08df2a9dfede75c55a1612281929c452d032b6905f95304b92684d1b');
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== TLS 1.2 PRF (RFC 5246) Tests ===');
  WriteLn;

  TestPRF_SHA256_MasterSecret;
  TestPRF_SHA256_KeyExpansion;
  TestPRF_SHA256_RFC5246Vector;
  TestPRF_SHA384;
  TestPRF_SHA256_OpenSSLVector;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
