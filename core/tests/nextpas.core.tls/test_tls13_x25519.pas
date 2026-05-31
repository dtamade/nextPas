program test_tls13_x25519;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.crypto.x25519;

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

function HexNibble(AChar: Char): Byte;
begin
  case AChar of
    '0'..'9': Result := Ord(AChar) - Ord('0');
    'a'..'f': Result := 10 + Ord(AChar) - Ord('a');
    'A'..'F': Result := 10 + Ord(AChar) - Ord('A');
  else
    Fail('Invalid hex character: ' + AChar);
    Result := 0;
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I, LLen: Integer;
begin
  Result := nil;
  LLen := Length(AHex);
  if (LLen = 0) or ((LLen and 1) <> 0) then
    Fail('Invalid hex length');

  SetLength(Result, LLen div 2);
  for I := 0 to High(Result) do
    Result[I] := (HexNibble(AHex[2 * I + 1]) shl 4) or HexNibble(AHex[2 * I + 2]);
end;

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);

  Result := True;
  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);
end;

procedure AssertBytesEqual(const AExpected, AActual: TBytes; const AMessage: string);
begin
  if not BytesEqual(AExpected, AActual) then
    Fail(AMessage);
end;

procedure TestRFCVectorOne;
var
  LScalar: TBytes;
  LU: TBytes;
  LExpected: TBytes;
  LActual: TBytes;
begin
  LScalar := HexToBytes('a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4');
  LU := HexToBytes('e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c');
  LExpected := HexToBytes('c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552');

  LActual := X25519ScalarMult(LScalar, LU);
  AssertBytesEqual(LExpected, LActual, 'RFC 7748 vector #1 failed');
end;

procedure TestRFCVectorTwo;
var
  LScalar: TBytes;
  LU: TBytes;
  LExpected: TBytes;
  LActual: TBytes;
begin
  LScalar := HexToBytes('4b66e9d4d1b4673c5ad22691957d6af5c11b6421e0ea01d42ca4169e7918ba0d');
  LU := HexToBytes('e5210f12786811d3f4b7959d0538ae2c31dbe7106fc03c3efc4cd549c715a493');
  LExpected := HexToBytes('95cbde9476e8907d7aade45cb4b873f88b595a68799fa152e6f8f7647aac7957');

  LActual := X25519ScalarMult(LScalar, LU);
  AssertBytesEqual(LExpected, LActual, 'RFC 7748 vector #2 failed');
end;

procedure TestRFCKeyAgreement;
var
  LAlicePriv, LAlicePub: TBytes;
  LBobPriv, LBobPub: TBytes;
  LExpectedShared: TBytes;
  LAliceShared, LBobShared: TBytes;
begin
  LAlicePriv := HexToBytes('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a');
  LAlicePub := HexToBytes('8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a');
  LBobPriv := HexToBytes('5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb');
  LBobPub := HexToBytes('de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f');
  LExpectedShared := HexToBytes('4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742');

  AssertBytesEqual(LAlicePub, X25519PublicKeyFromPrivate(LAlicePriv), 'Alice public key mismatch');
  AssertBytesEqual(LBobPub, X25519PublicKeyFromPrivate(LBobPriv), 'Bob public key mismatch');

  LAliceShared := X25519ComputeSharedSecret(LAlicePriv, LBobPub);
  LBobShared := X25519ComputeSharedSecret(LBobPriv, LAlicePub);

  AssertBytesEqual(LExpectedShared, LAliceShared, 'Alice shared secret mismatch');
  AssertBytesEqual(LExpectedShared, LBobShared, 'Bob shared secret mismatch');
end;

procedure TestRandomSymmetry;
var
  LAlicePriv, LAlicePub: TBytes;
  LBobPriv, LBobPub: TBytes;
  LAliceShared, LBobShared: TBytes;
begin
  GenerateX25519KeyPair(LAlicePriv, LAlicePub);
  GenerateX25519KeyPair(LBobPriv, LBobPub);

  LAliceShared := X25519ComputeSharedSecret(LAlicePriv, LBobPub);
  LBobShared := X25519ComputeSharedSecret(LBobPriv, LAlicePub);

  AssertTrue(Length(LAliceShared) = 32, 'Shared secret length should be 32');
  AssertBytesEqual(LAliceShared, LBobShared, 'Random key agreement symmetry failed');
end;

begin
  WriteLn('Testing TLS 1.3 X25519 implementation...');

  TestRFCVectorOne;
  TestRFCVectorTwo;
  TestRFCKeyAgreement;
  TestRandomSymmetry;

  WriteLn('✅ TLS 1.3 X25519 checks passed');
end.
