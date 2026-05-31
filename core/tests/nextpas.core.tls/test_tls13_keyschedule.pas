program test_tls13_keyschedule;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.keyschedule;

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

function StringToBytes(const AValue: AnsiString): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
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

procedure TestDeterministicVectorSHA256;
var
  LSharedSecret: TBytes;
  LTranscriptData: TBytes;
  LSecrets: TTLS13HandshakeSecrets;
  LError: string;
begin
  LSharedSecret := HexToBytes('4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742');
  LTranscriptData := StringToBytes('ClientHelloHandshakeBytes||ServerHelloHandshakeBytes');

  AssertTrue(
    TryDeriveTLS13HandshakeSecrets(
      TLS13_CIPHER_AES_128_GCM_SHA256,
      LSharedSecret,
      LTranscriptData,
      LSecrets,
      LError
    ),
    'SHA256 key schedule should succeed: ' + LError
  );

  AssertTrue(LSecrets.Valid, 'Secrets should be marked valid');
  AssertTrue(LSecrets.HashSize = 32, 'Hash size should be 32');
  AssertTrue(LSecrets.KeyLength = 16, 'AES-128 key length should be 16');
  AssertTrue(LSecrets.IVLength = 12, 'IV length should be 12');

  AssertBytesEqual(HexToBytes('fc4394acdb9d481a21b9614b831016b5b5e656e5e237bc8ed8eb0eb540c2c8aa'),
    LSecrets.TranscriptHash, 'Transcript hash mismatch');

  AssertBytesEqual(HexToBytes('33ad0a1c607ec03b09e6cd9893680ce210adf300aa1f2660e1b22e10f170f92a'),
    LSecrets.EarlySecret, 'Early secret mismatch');
  AssertBytesEqual(HexToBytes('6f2615a108c702c5678f54fc9dbab69716c076189c48250cebeac3576c3611ba'),
    LSecrets.DerivedSecret, 'Derived secret mismatch');
  AssertBytesEqual(HexToBytes('e4e520f8ca639e6562121a8d006bbce3e012f049744806f283e99c54cab713f3'),
    LSecrets.HandshakeSecret, 'Handshake secret mismatch');

  AssertBytesEqual(HexToBytes('1109d494613725a7432a6b6a831c54071f4c0b4f741d5c7305dac39eb49f514b'),
    LSecrets.ClientHandshakeTrafficSecret, 'Client HS traffic secret mismatch');
  AssertBytesEqual(HexToBytes('7adbfeda325088ba2201c0175d8ea186e4d5408e3b6bd2dcb3d61f471cbf3b61'),
    LSecrets.ServerHandshakeTrafficSecret, 'Server HS traffic secret mismatch');

  AssertBytesEqual(HexToBytes('a3a662876dcbac9554bbc99658dd66d7'),
    LSecrets.ClientHandshakeKey, 'Client HS key mismatch');
  AssertBytesEqual(HexToBytes('0282134be4f52f9264da1fab8a81b937'),
    LSecrets.ServerHandshakeKey, 'Server HS key mismatch');

  AssertBytesEqual(HexToBytes('a273928e850d5f659463e664'),
    LSecrets.ClientHandshakeIV, 'Client HS IV mismatch');
  AssertBytesEqual(HexToBytes('3e17de206ce69aa9c35dc8ff'),
    LSecrets.ServerHandshakeIV, 'Server HS IV mismatch');
end;

procedure TestChachaKeyLength;
var
  LSharedSecret: TBytes;
  LTranscriptData: TBytes;
  LSecrets: TTLS13HandshakeSecrets;
  LError: string;
begin
  LSharedSecret := HexToBytes('4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742');
  LTranscriptData := StringToBytes('ClientHelloHandshakeBytes||ServerHelloHandshakeBytes');

  AssertTrue(
    TryDeriveTLS13HandshakeSecrets(
      TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
      LSharedSecret,
      LTranscriptData,
      LSecrets,
      LError
    ),
    'CHACHA key schedule should succeed: ' + LError
  );

  AssertTrue(LSecrets.KeyLength = 32, 'CHACHA key length should be 32');
  AssertTrue(Length(LSecrets.ClientHandshakeKey) = 32, 'Client key bytes should be 32');
  AssertTrue(Length(LSecrets.ServerHandshakeKey) = 32, 'Server key bytes should be 32');
  AssertTrue(Length(LSecrets.ClientHandshakeIV) = 12, 'Client IV bytes should be 12');
  AssertTrue(Length(LSecrets.ServerHandshakeIV) = 12, 'Server IV bytes should be 12');
end;

procedure TestDeriveSHA384CipherPath;
var
  LSharedSecret: TBytes;
  LTranscriptData: TBytes;
  LSecrets, LSecrets2: TTLS13HandshakeSecrets;
  LError: string;
begin
  LSharedSecret := HexToBytes('4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742');
  LTranscriptData := StringToBytes('ClientHelloHandshakeBytes||ServerHelloHandshakeBytes');

  AssertTrue(
    TryDeriveTLS13HandshakeSecrets(
      TLS13_CIPHER_AES_256_GCM_SHA384,
      LSharedSecret,
      LTranscriptData,
      LSecrets,
      LError
    ),
    'SHA384 cipher path should derive successfully: ' + LError
  );

  AssertTrue(LSecrets.Valid, 'SHA384 secrets should be valid');
  AssertTrue(LSecrets.HashSize = 48, 'SHA384 hash size should be 48');
  AssertTrue(LSecrets.KeyLength = 32, 'AES-256 key length should be 32');
  AssertTrue(LSecrets.IVLength = 12, 'SHA384 IV length should be 12');

  AssertTrue(Length(LSecrets.TranscriptHash) = 48, 'SHA384 transcript hash length should be 48');
  AssertTrue(Length(LSecrets.EarlySecret) = 48, 'SHA384 early secret length should be 48');
  AssertTrue(Length(LSecrets.DerivedSecret) = 48, 'SHA384 derived secret length should be 48');
  AssertTrue(Length(LSecrets.HandshakeSecret) = 48, 'SHA384 handshake secret length should be 48');
  AssertTrue(Length(LSecrets.ClientHandshakeTrafficSecret) = 48, 'SHA384 client traffic secret length should be 48');
  AssertTrue(Length(LSecrets.ServerHandshakeTrafficSecret) = 48, 'SHA384 server traffic secret length should be 48');
  AssertTrue(Length(LSecrets.ClientHandshakeKey) = 32, 'SHA384 client handshake key length should be 32');
  AssertTrue(Length(LSecrets.ServerHandshakeKey) = 32, 'SHA384 server handshake key length should be 32');
  AssertTrue(Length(LSecrets.ClientHandshakeIV) = 12, 'SHA384 client handshake iv length should be 12');
  AssertTrue(Length(LSecrets.ServerHandshakeIV) = 12, 'SHA384 server handshake iv length should be 12');

  AssertTrue(
    not BytesEqual(LSecrets.ClientHandshakeTrafficSecret, LSecrets.ServerHandshakeTrafficSecret),
    'Client/server handshake traffic secrets should differ for SHA384 suite'
  );

  AssertTrue(
    TryDeriveTLS13HandshakeSecrets(
      TLS13_CIPHER_AES_256_GCM_SHA384,
      LSharedSecret,
      LTranscriptData,
      LSecrets2,
      LError
    ),
    'SHA384 re-derivation should succeed: ' + LError
  );

  AssertBytesEqual(LSecrets.TranscriptHash, LSecrets2.TranscriptHash,
    'SHA384 transcript hash should be deterministic');
  AssertBytesEqual(LSecrets.HandshakeSecret, LSecrets2.HandshakeSecret,
    'SHA384 handshake secret should be deterministic');
  AssertBytesEqual(LSecrets.ClientHandshakeKey, LSecrets2.ClientHandshakeKey,
    'SHA384 client key should be deterministic');
  AssertBytesEqual(LSecrets.ServerHandshakeKey, LSecrets2.ServerHandshakeKey,
    'SHA384 server key should be deterministic');
  AssertBytesEqual(LSecrets.ClientHandshakeIV, LSecrets2.ClientHandshakeIV,
    'SHA384 client iv should be deterministic');
  AssertBytesEqual(LSecrets.ServerHandshakeIV, LSecrets2.ServerHandshakeIV,
    'SHA384 server iv should be deterministic');
end;

procedure TestDeriveClientEarlyDataSecrets;
var
  LPsk: TBytes;
  LClientHello: TBytes;
  LSecrets, LSecrets2: TTLS13EarlyDataSecrets;
  LError: string;
begin
  LPsk := HexToBytes('00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff');
  LClientHello := StringToBytes('ClientHelloWithPSKAndEarlyData');

  AssertTrue(
    TryDeriveTLS13ClientEarlyDataSecrets(
      TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
      LPsk,
      LClientHello,
      LSecrets,
      LError
    ),
    'Client early-data secret derivation should succeed for CHACHA suite: ' + LError
  );

  AssertTrue(LSecrets.Valid, 'Early-data secrets should be marked valid');
  AssertTrue(LSecrets.HashSize = 32, 'Early-data hash size should follow suite hash');
  AssertTrue(LSecrets.KeyLength = 32, 'CHACHA early-data key length should be 32');
  AssertTrue(LSecrets.IVLength = 12, 'Early-data IV length should be 12');
  AssertTrue(Length(LSecrets.TranscriptHash) = 32, 'Early-data transcript hash length should be 32');
  AssertTrue(Length(LSecrets.EarlySecret) = 32, 'Early secret length should be 32');
  AssertTrue(Length(LSecrets.ClientEarlyTrafficSecret) = 32,
    'Client early traffic secret length should be 32');
  AssertTrue(Length(LSecrets.ClientEarlyKey) = 32, 'Client early-data key length should be 32');
  AssertTrue(Length(LSecrets.ClientEarlyIV) = 12, 'Client early-data IV length should be 12');

  AssertTrue(
    TryDeriveTLS13ClientEarlyDataSecrets(
      TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
      LPsk,
      LClientHello,
      LSecrets2,
      LError
    ),
    'Client early-data secret re-derivation should stay deterministic: ' + LError
  );

  AssertBytesEqual(LSecrets.EarlySecret, LSecrets2.EarlySecret,
    'Early secret should be deterministic');
  AssertBytesEqual(LSecrets.ClientEarlyTrafficSecret, LSecrets2.ClientEarlyTrafficSecret,
    'Client early traffic secret should be deterministic');
  AssertBytesEqual(LSecrets.ClientEarlyKey, LSecrets2.ClientEarlyKey,
    'Client early-data key should be deterministic');
  AssertBytesEqual(LSecrets.ClientEarlyIV, LSecrets2.ClientEarlyIV,
    'Client early-data iv should be deterministic');
end;

procedure TestRejectInvalidPSKLengthForEarlyData;
var
  LBadPSK: TBytes;
  LClientHello: TBytes;
  LSecrets: TTLS13EarlyDataSecrets;
  LError: string;
begin
  LBadPSK := HexToBytes('00112233445566778899aabbccddeeff');
  LClientHello := StringToBytes('ClientHelloWithPSKAndEarlyData');

  AssertTrue(
    not TryDeriveTLS13ClientEarlyDataSecrets(
      TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
      LBadPSK,
      LClientHello,
      LSecrets,
      LError
    ),
    'Client early-data derivation should fail closed for invalid PSK length'
  );
  AssertTrue(Pos('PSK', UpperCase(LError)) > 0,
    'Invalid early-data PSK length should surface PSK-specific error text');
end;

begin
  WriteLn('Testing TLS 1.3 key schedule...');

  TestDeterministicVectorSHA256;
  TestChachaKeyLength;
  TestDeriveSHA384CipherPath;
  TestDeriveClientEarlyDataSecrets;
  TestRejectInvalidPSKLengthForEarlyData;

  WriteLn('✅ TLS 1.3 key schedule checks passed');
end.
