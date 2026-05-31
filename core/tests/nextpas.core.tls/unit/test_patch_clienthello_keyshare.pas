program test_patch_clienthello_keyshare;
{$mode objfpc}{$H+}{$J-}
uses
  SysUtils,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.crypto.x25519;

var
  GTotal: Integer = 0;
  GPassed: Integer = 0;

procedure Check(const AName: string; ACondition: Boolean);
begin
  Inc(GTotal);
  if ACondition then Inc(GPassed)
  else begin WriteLn('  FAIL: ', AName); Halt(1); end;
  WriteLn('  PASS: ', AName);
end;

var
  LPriv, LX25519Pub, LP256Pub: TBytes;
  LOrigCH, LPatchedCH: TBytes;
  LOrigLen, LPatchedLen: Integer;
  I: Integer;
begin
  WriteLn('=== PatchClientHelloKeyShare Tests ===');

  LPriv := GenerateX25519PrivateKey;
  LX25519Pub := X25519PublicKeyFromPrivate(LPriv);

  LOrigCH := BuildTLS13ClientHelloHandshakeWithCiphers(
    'test.example.com', '', LX25519Pub, nil, False, False);

  // Create a fake P-256 public key (65 bytes, uncompressed)
  SetLength(LP256Pub, 65);
  LP256Pub[0] := $04;
  for I := 1 to 64 do LP256Pub[I] := Byte(I);

  LPatchedCH := PatchClientHelloKeyShare(LOrigCH, LP256Pub, TLS13_GROUP_SECP256R1);

  LOrigLen := Length(LOrigCH);
  LPatchedLen := Length(LPatchedCH);

  Check('Patched CH is longer (P-256 key is 65 vs X25519 32)',
    LPatchedLen > LOrigLen);
  Check('Size difference = 33 (65 - 32)',
    LPatchedLen - LOrigLen = 33);
  Check('Patched CH type = 1', LPatchedCH[0] = 1);
  Check('Patched CH version = 0x0303', (LPatchedCH[4] = 3) and (LPatchedCH[5] = 3));

  // Verify random is preserved
  Check('Random preserved', CompareMem(@LOrigCH[6], @LPatchedCH[6], 32));

  // Verify handshake length is updated
  LPatchedLen := (Integer(LPatchedCH[1]) shl 16) or (Integer(LPatchedCH[2]) shl 8) or Integer(LPatchedCH[3]);
  Check('Handshake length matches', LPatchedLen = Length(LPatchedCH) - 4);

  // Also test P-384 (97 bytes)
  SetLength(LP256Pub, 97);
  LP256Pub[0] := $04;
  for I := 1 to 96 do LP256Pub[I] := Byte(I + 100);

  LPatchedCH := PatchClientHelloKeyShare(LOrigCH, LP256Pub, TLS13_GROUP_SECP384R1);
  Check('P-384 patch size diff = 65 (97 - 32)',
    Length(LPatchedCH) - LOrigLen = 65);

  LPatchedLen := (Integer(LPatchedCH[1]) shl 16) or (Integer(LPatchedCH[2]) shl 8) or Integer(LPatchedCH[3]);
  Check('P-384 handshake length matches', LPatchedLen = Length(LPatchedCH) - 4);

  WriteLn;
  WriteLn('All passed: ', GPassed, '/', GTotal);
end.
