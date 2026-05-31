program test_tls12_fallback_clientrandom;
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
  LKeyShare, LClientHello, LClientRandom: TBytes;
  LPriv: TBytes;
  I: Integer;
begin
  WriteLn('=== TLS 1.2 Fallback ClientRandom Extraction ===');

  LPriv := GenerateX25519PrivateKey;
  LKeyShare := X25519PublicKeyFromPrivate(LPriv);

  LClientHello := BuildTLS13ClientHelloHandshakeWithCiphers(
    'test.example.com', '', LKeyShare, nil, False, False);

  Check('ClientHello length > 38', Length(LClientHello) > 38);
  Check('ClientHello type = 1', LClientHello[0] = 1);
  Check('ClientHello version = 0x0303', (LClientHello[4] = 3) and (LClientHello[5] = 3));

  // Extract ClientRandom (offset 6, 32 bytes)
  LClientRandom := Copy(LClientHello, 6, 32);
  Check('ClientRandom length = 32', Length(LClientRandom) = 32);

  // Verify it's not all zeros (random)
  I := 0;
  while (I < 32) and (LClientRandom[I] = 0) do Inc(I);
  Check('ClientRandom is not all zeros', I < 32);

  // Verify the random is at the correct offset by checking structure
  // After random (offset 38): session_id_length byte
  Check('Session ID length byte is valid', LClientHello[38] <= 32);

  WriteLn;
  WriteLn('All passed: ', GPassed, '/', GTotal);
end.
