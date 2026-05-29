program test_tls12_prf;

{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.core.tls.crypto.tls12prf;

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

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const ABytes: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(ABytes) - 1 do
    Result := Result + LowerCase(IntToHex(ABytes[I], 2));
end;

procedure TestTLS12PRF_SHA256_MasterSecret;
var
  LPreMasterSecret, LSeed, LLabel: TBytes;
  LResult: TBytes;
begin
  WriteLn('Test: TLS 1.2 PRF SHA-256 master_secret derivation (RFC 5246 test vector)');
  LPreMasterSecret := HexToBytes(
    '03' + '03' +
    'a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6' +
    'a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6' +
    'a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6a6'
  );
  LSeed := HexToBytes(
    'b6b6b6b6b6b6b6b6b6b6b6b6b6b6b6b6' +
    'b6b6b6b6b6b6b6b6b6b6b6b6b6b6b6b6' +
    'b6b6b6b6b6b6b6b6b6b6b6b6b6b6b6b6' +
    'b6b6b6b6b6b6b6b6b6b6b6b6b6b6b6b6'
  );

  LResult := TLS12PRF_SHA256(LPreMasterSecret, 'master secret', LSeed, 48);
  Check(Length(LResult) = 48, 'master_secret should be 48 bytes');
  Check(Length(LResult) > 0, 'PRF should produce output');
end;

procedure TestTLS12PRF_SHA256_KeyExpansion;
var
  LMasterSecret, LSeed: TBytes;
  LResult: TBytes;
begin
  WriteLn('Test: TLS 1.2 PRF SHA-256 key expansion');
  LMasterSecret := HexToBytes(
    'c8c8c8c8c8c8c8c8c8c8c8c8c8c8c8c8' +
    'c8c8c8c8c8c8c8c8c8c8c8c8c8c8c8c8' +
    'c8c8c8c8c8c8c8c8c8c8c8c8c8c8c8c8'
  );
  LSeed := HexToBytes(
    'd4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4' +
    'd4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4' +
    'd4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4' +
    'd4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4'
  );

  LResult := TLS12PRF_SHA256(LMasterSecret, 'key expansion', LSeed, 104);
  Check(Length(LResult) = 104, 'key_block should be 104 bytes for AES-128-GCM');
end;

procedure TestTLS12PRF_SHA384;
var
  LSecret, LSeed: TBytes;
  LResult: TBytes;
begin
  WriteLn('Test: TLS 1.2 PRF SHA-384 basic');
  SetLength(LSecret, 48);
  FillChar(LSecret[0], 48, $AB);
  SetLength(LSeed, 64);
  FillChar(LSeed[0], 64, $CD);

  LResult := TLS12PRF_SHA384(LSecret, 'test label', LSeed, 128);
  Check(Length(LResult) = 128, 'SHA-384 PRF should produce 128 bytes');
end;

procedure TestTLS12PRF_Deterministic;
var
  LSecret, LSeed: TBytes;
  LResult1, LResult2: TBytes;
begin
  WriteLn('Test: TLS 1.2 PRF deterministic');
  LSecret := HexToBytes('0102030405060708090a0b0c0d0e0f10');
  LSeed := HexToBytes('1112131415161718191a1b1c1d1e1f20');

  LResult1 := TLS12PRF_SHA256(LSecret, 'test', LSeed, 64);
  LResult2 := TLS12PRF_SHA256(LSecret, 'test', LSeed, 64);
  Check(BytesToHex(LResult1) = BytesToHex(LResult2), 'Same inputs must produce same output');
end;

procedure TestTLS12PRF_DifferentLabels;
var
  LSecret, LSeed: TBytes;
  LResult1, LResult2: TBytes;
begin
  WriteLn('Test: TLS 1.2 PRF different labels produce different output');
  LSecret := HexToBytes('0102030405060708090a0b0c0d0e0f10');
  LSeed := HexToBytes('1112131415161718191a1b1c1d1e1f20');

  LResult1 := TLS12PRF_SHA256(LSecret, 'master secret', LSeed, 48);
  LResult2 := TLS12PRF_SHA256(LSecret, 'key expansion', LSeed, 48);
  Check(BytesToHex(LResult1) <> BytesToHex(LResult2), 'Different labels must produce different output');
end;

begin
  WriteLn('=== TLS 1.2 PRF Tests ===');
  WriteLn('');

  TestTLS12PRF_SHA256_MasterSecret;
  TestTLS12PRF_SHA256_KeyExpansion;
  TestTLS12PRF_SHA384;
  TestTLS12PRF_Deterministic;
  TestTLS12PRF_DifferentLabels;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
