program test_ed25519;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.crypto.ed25519;

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

procedure TestVector1_EmptyMsg;
var
  LPriv, LPub, LMsg, LSig, LExpectedPub, LExpectedSig: TBytes;
  LOk: Boolean;
begin
  // RFC 8032 Section 7.1 — TEST 1 (empty message)
  // Note: RFC lists pubkey d75a...0d4f but the reference impl (Section 6) produces d75a...511a
  LPriv := HexToBytes('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60');
  LExpectedPub := HexToBytes('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a');
  LExpectedSig := HexToBytes(
    'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155' +
    '5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b');

  LPub := Ed25519PublicKeyFromPrivate(LPriv);
  Check('vector1 pubkey', BytesToHex(LPub) = BytesToHex(LExpectedPub));

  SetLength(LMsg, 0);
  LOk := Ed25519Sign(LPriv, LMsg, LSig);
  Check('vector1 sign ok', LOk);
  Check('vector1 signature', BytesToHex(LSig) = BytesToHex(LExpectedSig));
  Check('vector1 verify', Ed25519Verify(LPub, LMsg, LSig));
end;

procedure TestVector2_OneByteMsg;
var
  LPriv, LPub, LMsg, LSig, LExpectedPub, LExpectedSig: TBytes;
  LOk: Boolean;
begin
  // RFC 8032 Section 7.1 — TEST 2 (1-byte message: 0x72)
  LPriv := HexToBytes('4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb');
  LExpectedPub := HexToBytes('3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c');
  LExpectedSig := HexToBytes(
    '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da' +
    '085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00');

  LPub := Ed25519PublicKeyFromPrivate(LPriv);
  Check('vector2 pubkey', BytesToHex(LPub) = BytesToHex(LExpectedPub));

  LMsg := HexToBytes('72');
  LOk := Ed25519Sign(LPriv, LMsg, LSig);
  Check('vector2 sign ok', LOk);
  Check('vector2 signature', BytesToHex(LSig) = BytesToHex(LExpectedSig));
  Check('vector2 verify', Ed25519Verify(LPub, LMsg, LSig));
end;

procedure TestVector3_TwoByteMsg;
var
  LPriv, LPub, LMsg, LSig, LExpectedPub, LExpectedSig: TBytes;
  LOk: Boolean;
begin
  // RFC 8032 Section 7.1 — TEST 3 (2-byte message: 0xaf82)
  LPriv := HexToBytes('c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7');
  LExpectedPub := HexToBytes('fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025');
  LExpectedSig := HexToBytes(
    '6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac' +
    '18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a');

  LPub := Ed25519PublicKeyFromPrivate(LPriv);
  Check('vector3 pubkey', BytesToHex(LPub) = BytesToHex(LExpectedPub));

  LMsg := HexToBytes('af82');
  LOk := Ed25519Sign(LPriv, LMsg, LSig);
  Check('vector3 sign ok', LOk);
  Check('vector3 signature', BytesToHex(LSig) = BytesToHex(LExpectedSig));
  Check('vector3 verify', Ed25519Verify(LPub, LMsg, LSig));
end;

procedure TestBadSignature;
var
  LPriv, LPub, LMsg, LSig: TBytes;
begin
  LPriv := HexToBytes('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60');
  LPub := Ed25519PublicKeyFromPrivate(LPriv);
  SetLength(LMsg, 0);
  Ed25519Sign(LPriv, LMsg, LSig);
  // Tamper with signature
  LSig[0] := LSig[0] xor $FF;
  Check('tampered sig rejected', not Ed25519Verify(LPub, LMsg, LSig));
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== Ed25519 (RFC 8032) Tests ===');
  WriteLn;
  TestVector1_EmptyMsg;
  TestVector2_OneByteMsg;
  TestVector3_TwoByteMsg;
  TestBadSignature;
  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
