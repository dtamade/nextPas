program test_crypto_utils_hkdf_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.crypto.utils,
  nextpas.core.tls.encoding,
  nextpas.core.tls.exceptions;

procedure Fail(const AMessage: string);
begin
  WriteLn('❌ ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

procedure AssertEqualInt(AExpected, AActual: Int64; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

procedure AssertBytesEqual(const AExpected, AActual: TBytes; const AMessage: string);
var
  I: Integer;
begin
  AssertEqualInt(Length(AExpected), Length(AActual), AMessage + ' length mismatch');
  for I := 0 to Length(AExpected) - 1 do
    if AExpected[I] <> AActual[I] then
      Fail(Format('%s byte mismatch at %d (expected=%d actual=%d)',
        [AMessage, I, AExpected[I], AActual[I]]));
end;

procedure TestRFC5869Case1;
var
  LIKM, LSalt, LInfo, LExpected, LActual: TBytes;
  I: Integer;
begin
  WriteLn('--- Test: CryptoUtils HKDF RFC5869 Case 1');

  SetLength(LIKM, 22);
  for I := 0 to High(LIKM) do
    LIKM[I] := $0b;

  LSalt := TEncodingUtils.HexToBytes('000102030405060708090A0B0C');
  LInfo := TEncodingUtils.HexToBytes('F0F1F2F3F4F5F6F7F8F9');
  LExpected := TEncodingUtils.HexToBytes(
    '3CB25F25FAACD57A90434F64D0362F2A' +
    '2D2D0A90CF1A5A4C5DB02D56ECC4C5BF' +
    '34007208D5B887185865');

  LActual := TCryptoUtils.HKDF(LIKM, LSalt, LInfo, 42, HASH_SHA256);
  AssertBytesEqual(LExpected, LActual, 'HKDF RFC5869 case1 output should match');

  WriteLn('✅ HKDF RFC5869 Case 1 verified');
end;

procedure TestHKDFInvalidLengthContract;
var
  LIKM, LOut: TBytes;
  LRaised: Boolean;
begin
  WriteLn('--- Test: CryptoUtils HKDF invalid output length contract');

  LIKM := TEncodingUtils.HexToBytes('0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B');

  LRaised := False;
  try
    LOut := TCryptoUtils.HKDF(LIKM, nil, nil, 0, HASH_SHA256);
    Fail('HKDF output length=0 should raise ESSLInvalidArgument, got len=' + IntToStr(Length(LOut)));
  except
    on E: ESSLInvalidArgument do
      LRaised := True;
    on E: Exception do
      Fail('HKDF invalid length should raise ESSLInvalidArgument, got: ' + E.ClassName + ': ' + E.Message);
  end;

  AssertTrue(LRaised, 'HKDF invalid length must raise ESSLInvalidArgument');

  if TCryptoUtils.TryHKDF(LIKM, nil, nil, 0, LOut, HASH_SHA256) then
    Fail('TryHKDF should return False for invalid output length');

  AssertEqualInt(0, Length(LOut), 'TryHKDF invalid length should return empty output');

  WriteLn('✅ HKDF invalid length contract verified');
end;

begin
  WriteLn('CryptoUtils HKDF contract tests');
  WriteLn('==============================');

  TestRFC5869Case1;
  TestHKDFInvalidLengthContract;

  WriteLn('==============================');
  WriteLn('✅ All CryptoUtils HKDF contract tests passed');
end.
