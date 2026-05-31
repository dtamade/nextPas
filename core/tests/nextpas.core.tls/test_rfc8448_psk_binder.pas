program test_rfc8448_psk_binder;
{$mode objfpc}{$H+}{$J-}
{
  RFC 8448 Section 4 (Resumed 0-RTT Handshake) PSK Binder Verification

  Verifies our TLS 1.3 PSK binder computation against RFC 8448 test vectors.
  Tests each step of the key schedule independently:
    1. Early Secret = HKDF-Extract(salt=0, IKM=PSK)
    2. binder_key = Derive-Secret(Early Secret, "res binder", "")
    3. finished_key = HKDF-Expand-Label(binder_key, "finished", "", 32)
    4. binder = HMAC(finished_key, Hash(partial_ClientHello))

  Also verifies the combined TLS13ComputePSKBinderForCipherSuite function
  and the full ClientHello builder round-trip.
}
uses
  SysUtils,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.crypto.primitives,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.crypto.hash;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const B: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(B) do
    Result := Result + LowerCase(IntToHex(B[I], 2));
end;

procedure Check(const AName: string; const AActual: TBytes; const AExpectedHex: string);
var
  ActualHex: string;
begin
  ActualHex := BytesToHex(AActual);
  if ActualHex = LowerCase(AExpectedHex) then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPassCount);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    WriteLn('    actual:   ', ActualHex);
    WriteLn('    expected: ', LowerCase(AExpectedHex));
    Inc(GFailCount);
  end;
end;

procedure CheckLen(const AName: string; const AActual: TBytes; AExpectedLen: Integer);
begin
  if Length(AActual) = AExpectedLen then
  begin
    WriteLn('  [PASS] ', AName, ' (length=', Length(AActual), ')');
    Inc(GPassCount);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName, ' length=', Length(AActual), ' expected=', AExpectedLen);
    Inc(GFailCount);
  end;
end;

procedure CheckBool(const AName: string; AActual, AExpected: Boolean);
begin
  if AActual = AExpected then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPassCount);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName, ' actual=', AActual, ' expected=', AExpected);
    Inc(GFailCount);
  end;
end;

const
  CIPHER_SUITE = $1301; // TLS_AES_128_GCM_SHA256
  HASH_SIZE = 32;

  { RFC 8448 Section 4: PSK (from Section 3 resumption_master_secret) }
  PSK_HEX = '4ecd0eb6ec3b4d87f5d6028f922ca4c5851a277fd41311c9e62d2c9492e1c4f3';

  { RFC 8448 Section 4: Expected early_secret }
  EARLY_SECRET_HEX = '9b2188e9b2fc6d64d71dc329900e20bb41915000f678aa839cbb797cb7d8332c';

  { Computed binder_key = Derive-Secret(early_secret, "res binder", "") }
  BINDER_KEY_HEX = '69fe131a3bbad5d63c64eebcc30e395b9d8107726a13d074e389dbc8a4e47256';

  { Computed finished_key = HKDF-Expand-Label(binder_key, "finished", "", 32) }
  FINISHED_KEY_HEX = '5588673e72cb59c87d220caffe94f2dea9a3b1609f7d50e90a48227db9ed7eaa';

  { SHA-256 of empty input }
  EMPTY_HASH_HEX = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  { RFC 8448 Section 3: early_secret with zero PSK (cross-check) }
  ZERO_PSK_EARLY_SECRET_HEX = '33ad0a1c607ec03b09e6cd9893680ce210adf300aa1f2660e1b22e10f170f92a';

  { Synthetic partial ClientHello for end-to-end test }
  SYNTHETIC_PARTIAL_HEX = '0100000474657374';
  SYNTHETIC_BINDER_HEX = 'e4c99fb16dd1f516df0b35ab32b9893530bf95ce44e11229fba4053decd130ae';

var
  PSK: TBytes;
  ZeroSalt: TBytes;
  EarlySecret: TBytes;
  EmptyHash: TBytes;
  BinderKey: TBytes;
  FinishedKey: TBytes;
  PartialHash: TBytes;
  Binder: TBytes;
  SyntheticPartial: TBytes;
  ZeroPSK: TBytes;
  ComputedBinder: TBytes;
  // Round-trip test variables
  KeyShare: TBytes;
  Ticket: TBytes;
  FullCH: TBytes;
  PartialCH: TBytes;
  ExtractedBinder: TBytes;
  RecomputedBinder: TBytes;
  BinderOffset: Integer;
  BodyLen: Integer;
begin
  WriteLn('=== RFC 8448 PSK Binder Test Vector Verification ===');
  WriteLn;

  // =========================================================================
  // Test 1: SHA-256 of empty input
  // =========================================================================
  WriteLn('--- Test 1: SHA-256 empty hash ---');
  SetLength(ZeroSalt, 0);
  EmptyHash := SHA256(ZeroSalt);
  Check('SHA256("")', EmptyHash, EMPTY_HASH_HEX);
  WriteLn;

  // =========================================================================
  // Test 2: Early Secret with zero PSK (RFC 8448 Section 3 cross-check)
  // =========================================================================
  WriteLn('--- Test 2: Early Secret (zero PSK, RFC 8448 Section 3) ---');
  SetLength(ZeroPSK, HASH_SIZE);
  FillChar(ZeroPSK[0], HASH_SIZE, 0);
  SetLength(ZeroSalt, 0);
  EarlySecret := HKDF_Extract_SHA256(ZeroSalt, ZeroPSK);
  Check('HKDF-Extract(0, zero_PSK)', EarlySecret, ZERO_PSK_EARLY_SECRET_HEX);
  WriteLn;

  // =========================================================================
  // Test 3: Early Secret with RFC 8448 Section 4 PSK
  // =========================================================================
  WriteLn('--- Test 3: Early Secret (RFC 8448 Section 4 PSK) ---');
  PSK := HexToBytes(PSK_HEX);
  SetLength(ZeroSalt, 0);
  EarlySecret := HKDF_Extract_SHA256(ZeroSalt, PSK);
  Check('HKDF-Extract(0, PSK)', EarlySecret, EARLY_SECRET_HEX);
  WriteLn;

  // =========================================================================
  // Test 4: Binder Key derivation
  // =========================================================================
  WriteLn('--- Test 4: Binder Key (Derive-Secret) ---');
  EmptyHash := SHA256(ZeroSalt);
  BinderKey := TLS13_HKDF_Expand_Label_SHA256(EarlySecret, 'res binder', EmptyHash, HASH_SIZE);
  Check('Derive-Secret(ES, "res binder", "")', BinderKey, BINDER_KEY_HEX);
  WriteLn;

  // =========================================================================
  // Test 5: Finished Key derivation
  // =========================================================================
  WriteLn('--- Test 5: Finished Key ---');
  SetLength(ZeroSalt, 0);
  FinishedKey := TLS13_HKDF_Expand_Label_SHA256(BinderKey, 'finished', ZeroSalt, HASH_SIZE);
  Check('HKDF-Expand-Label(BK, "finished", "", 32)', FinishedKey, FINISHED_KEY_HEX);
  WriteLn;

  // =========================================================================
  // Test 6: Binder computation with synthetic partial ClientHello
  // =========================================================================
  WriteLn('--- Test 6: Binder (synthetic partial ClientHello) ---');
  SyntheticPartial := HexToBytes(SYNTHETIC_PARTIAL_HEX);
  PartialHash := SHA256(SyntheticPartial);
  Binder := HMAC_SHA256(FinishedKey, PartialHash);
  Check('HMAC(FK, Hash(partial_CH))', Binder, SYNTHETIC_BINDER_HEX);
  WriteLn;

  // =========================================================================
  // Test 7: Full chain via TLS13ComputePSKBinderForCipherSuite
  // =========================================================================
  WriteLn('--- Test 7: TLS13ComputePSKBinderForCipherSuite (end-to-end) ---');
  ComputedBinder := TLS13ComputePSKBinderForCipherSuite(CIPHER_SUITE, PSK, SyntheticPartial);
  CheckLen('Binder output length', ComputedBinder, HASH_SIZE);
  Check('TLS13ComputePSKBinderForCipherSuite', ComputedBinder, SYNTHETIC_BINDER_HEX);
  WriteLn;

  // =========================================================================
  // Test 8: Verify determinism
  // =========================================================================
  WriteLn('--- Test 8: Determinism ---');
  Binder := TLS13ComputePSKBinderForCipherSuite(CIPHER_SUITE, PSK, SyntheticPartial);
  Check('Second call same result', Binder, SYNTHETIC_BINDER_HEX);
  WriteLn;

  // =========================================================================
  // Test 9: Round-trip - Build ClientHello, extract partial, verify binder
  // This simulates what a server would do to verify the binder.
  // =========================================================================
  WriteLn('--- Test 9: ClientHello round-trip binder verification ---');

  // Build a real ClientHello with PSK
  SetLength(KeyShare, 32);
  FillChar(KeyShare[0], 32, $AB);  // dummy key share
  Ticket := HexToBytes('0102030405060708090a0b0c0d0e0f10');  // dummy ticket

  FullCH := BuildTLS13ClientHelloHandshakeWithComputedPSKBinder(
    'example.com', '',
    KeyShare,
    CIPHER_SUITE,
    Ticket,
    12345,  // obfuscated ticket age
    PSK,
    PartialCH,
    False, False, False
  );

  // FullCH should be non-empty
  CheckBool('FullCH non-empty', Length(FullCH) > 0, True);
  CheckBool('PartialCH non-empty', Length(PartialCH) > 0, True);

  // The binder is the last HASH_SIZE bytes of FullCH
  // (preceded by a 1-byte length field = 0x20)
  CheckBool('FullCH ends with binder', FullCH[Length(FullCH) - HASH_SIZE - 1] = HASH_SIZE, True);

  // Extract the binder from the full ClientHello
  SetLength(ExtractedBinder, HASH_SIZE);
  Move(FullCH[Length(FullCH) - HASH_SIZE], ExtractedBinder[0], HASH_SIZE);

  // The server would reconstruct the partial by taking the full CH
  // and truncating the binders (binders_length + binder_length + binder_value)
  // The handshake length field stays the same (it's the full body length)
  BinderOffset := Length(FullCH) - (2 + 1 + HASH_SIZE);
  SetLength(SyntheticPartial, BinderOffset);
  Move(FullCH[0], SyntheticPartial[0], BinderOffset);

  // Verify: server-side partial should equal our PartialCH
  // Wait - our PartialCH has the handshake length set to LPartialBody length
  // which equals the full body length. And the server's partial also has
  // the full body length in the header. So they should match.
  CheckBool('Server partial == our partial (length)', Length(SyntheticPartial) = Length(PartialCH), True);
  if Length(SyntheticPartial) = Length(PartialCH) then
    CheckBool('Server partial == our partial (content)', CompareMem(@SyntheticPartial[0], @PartialCH[0], Length(PartialCH)), True)
  else
  begin
    WriteLn('  [FAIL] Cannot compare - lengths differ: ', Length(SyntheticPartial), ' vs ', Length(PartialCH));
    Inc(GFailCount);
  end;

  // Recompute binder using the server-side partial
  RecomputedBinder := TLS13ComputePSKBinderForCipherSuite(CIPHER_SUITE, PSK, SyntheticPartial);
  Check('Recomputed binder matches extracted', RecomputedBinder, BytesToHex(ExtractedBinder));
  WriteLn;

  // =========================================================================
  // Test 10: Verify handshake length field consistency
  // The length field in the partial should equal the full body length
  // =========================================================================
  WriteLn('--- Test 10: Handshake length field consistency ---');
  // FullCH[0] = type (0x01), FullCH[1..3] = length (big-endian 24-bit)
  BodyLen := (Integer(FullCH[1]) shl 16) or (Integer(FullCH[2]) shl 8) or Integer(FullCH[3]);
  CheckBool('Header type = 0x01', FullCH[0] = 1, True);
  CheckBool('Body length = total - 4', BodyLen = Length(FullCH) - 4, True);
  // Partial should have the same length field
  CheckBool('Partial header length matches full',
    (PartialCH[1] = FullCH[1]) and (PartialCH[2] = FullCH[2]) and (PartialCH[3] = FullCH[3]),
    True);
  WriteLn;

  // =========================================================================
  // Summary
  // =========================================================================
  WriteLn('=== Results ===');
  WriteLn('  Passed: ', GPassCount);
  WriteLn('  Failed: ', GFailCount);
  WriteLn;

  if GFailCount = 0 then
    WriteLn('[ALL PASS] PSK binder crypto and ClientHello construction are correct.')
  else
    WriteLn('[FAILURES] See above for details.');

  if GFailCount > 0 then
    Halt(1);
end.
