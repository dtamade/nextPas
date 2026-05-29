program test_x25519;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.crypto.x25519;

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

procedure TestRFC7748Vector1;
var
  LScalar, LU, LExpected, LResult: TBytes;
begin
  // RFC 7748 Section 6.1 — Test Vector 1
  LScalar := HexToBytes('a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4');
  LU := HexToBytes('e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c');
  LExpected := HexToBytes('c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552');

  LResult := X25519ScalarMult(LScalar, LU);
  Check('RFC7748 vector 1', BytesToHex(LResult) = BytesToHex(LExpected));
end;

procedure TestRFC7748Vector2;
var
  LScalar, LU, LExpected, LResult: TBytes;
begin
  // RFC 7748 Section 6.1 — Test Vector 2
  LScalar := HexToBytes('4b66e9d4d1b4673c5ad22691957d6af5c11b6421e0ea01d42ca4169e7918ba0d');
  LU := HexToBytes('e5210f12786811d3f4b7959d0538ae2c31dbe7106fc03c3efc4cd549c715a493');
  LExpected := HexToBytes('95cbde9476e8907d7aade45cb4b873f88b595a68799fa152e6f8f7647aac7957');

  LResult := X25519ScalarMult(LScalar, LU);
  Check('RFC7748 vector 2', BytesToHex(LResult) = BytesToHex(LExpected));
end;

procedure TestBasePointMult;
var
  LPriv, LExpectedPub, LResult: TBytes;
begin
  // RFC 7748 Section 6.1 — Alice's public key
  // Alice's private key (after clamping) * basepoint = Alice's public key
  // Use the iterative test's first step: k=9, u=9 → result
  // Actually use a known pair: private=0x77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a
  // public=0x8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a
  LPriv := HexToBytes('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a');
  LExpectedPub := HexToBytes('8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a');

  LResult := X25519PublicKeyFromPrivate(LPriv);
  Check('RFC7748 Alice pubkey from private', BytesToHex(LResult) = BytesToHex(LExpectedPub));
end;

procedure TestKeyPairRoundtrip;
var
  LPrivA, LPubA, LPrivB, LPubB: TBytes;
  LSharedAB, LSharedBA: TBytes;
begin
  // Generate two key pairs, verify shared secrets match
  GenerateX25519KeyPair(LPrivA, LPubA);
  GenerateX25519KeyPair(LPrivB, LPubB);

  LSharedAB := X25519ComputeSharedSecret(LPrivA, LPubB);
  LSharedBA := X25519ComputeSharedSecret(LPrivB, LPubA);

  Check('ECDH roundtrip: shared secrets match', BytesToHex(LSharedAB) = BytesToHex(LSharedBA));
  Check('ECDH shared secret is 32 bytes', Length(LSharedAB) = 32);
end;

procedure TestIterative1000;
var
  LK, LU, LResult: TBytes;
  I: Integer;
begin
  // RFC 7748 Section 5.2 — iterative test (1000 iterations)
  // After 1000 iterations: k = 684cf59ba83309552800ef566f2f4d3c1c3887c49360e3875f2eb94d99532c51
  SetLength(LK, 32);
  SetLength(LU, 32);
  FillChar(LK[0], 32, 0);
  FillChar(LU[0], 32, 0);
  LK[0] := 9;
  LU[0] := 9;

  for I := 1 to 1000 do
  begin
    LResult := X25519ScalarMult(LK, LU);
    Move(LK[0], LU[0], 32);
    Move(LResult[0], LK[0], 32);
  end;

  Check('RFC7748 iterative 1000',
    BytesToHex(LK) = '684cf59ba83309552800ef566f2f4d3c1c3887c49360e3875f2eb94d99532c51');
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== X25519 (RFC 7748) Tests ===');
  WriteLn;

  TestRFC7748Vector1;
  TestRFC7748Vector2;
  TestBasePointMult;
  TestKeyPairRoundtrip;
  TestIterative1000;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
