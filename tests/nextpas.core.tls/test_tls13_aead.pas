program test_tls13_aead;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.aead;

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

procedure TestChaChaSuiteRoundtrip;
var
  LKey, LNonce, LAAD, LPlain: TBytes;
  LEncrypted: TBytes;
  LRecovered: TBytes;
  LError: string;
begin
  LKey := HexToBytes('1c9240a5eb55d38af333888604f6b5f0473917c1402b80099dca5cbc207075c0');
  LNonce := HexToBytes('000000000102030405060708');
  LAAD := HexToBytes('f33388860000000000004e91');
  LPlain := HexToBytes('000102030405060708090a0b0c0d0e0f10111213');

  AssertTrue(
    TryTLS13AEADEncrypt(
      TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
      LKey,
      LNonce,
      LAAD,
      LPlain,
      LEncrypted,
      LError
    ),
    'TLS13 AEAD encrypt should succeed for CHACHA suite: ' + LError
  );

  AssertTrue(
    TryTLS13AEADDecrypt(
      TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
      LKey,
      LNonce,
      LAAD,
      LEncrypted,
      LRecovered,
      LError
    ),
    'TLS13 AEAD decrypt should succeed for CHACHA suite: ' + LError
  );

  AssertBytesEqual(LPlain, LRecovered, 'Recovered CHACHA plaintext mismatch');
end;

procedure TestAES128SuiteRoundtrip;
var
  LKey, LNonce, LAAD, LPlain: TBytes;
  LEncrypted, LRecovered: TBytes;
  LError: string;
begin
  AssertTrue(TLS13AEADIsSupported(TLS13_CIPHER_AES_128_GCM_SHA256),
    'AES-128-GCM suite should be supported');

  LKey := HexToBytes('000102030405060708090a0b0c0d0e0f');
  LNonce := HexToBytes('f0f1f2f3f4f5f6f7f8f9fafb');
  LAAD := HexToBytes('feedfacedeadbeeffeedfacedeadbeefabaddad2');
  LPlain := HexToBytes('d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a72');

  AssertTrue(
    TryTLS13AEADEncrypt(
      TLS13_CIPHER_AES_128_GCM_SHA256,
      LKey,
      LNonce,
      LAAD,
      LPlain,
      LEncrypted,
      LError
    ),
    'TLS13 AEAD encrypt should succeed for AES-128-GCM suite: ' + LError
  );

  AssertTrue(Length(LEncrypted) = Length(LPlain) + 16,
    'AES-128 encrypted payload should include 16-byte auth tag');

  AssertTrue(
    TryTLS13AEADDecrypt(
      TLS13_CIPHER_AES_128_GCM_SHA256,
      LKey,
      LNonce,
      LAAD,
      LEncrypted,
      LRecovered,
      LError
    ),
    'TLS13 AEAD decrypt should succeed for AES-128-GCM suite: ' + LError
  );

  AssertBytesEqual(LPlain, LRecovered, 'Recovered AES-128 plaintext mismatch');
end;

procedure TestAES256SuiteRoundtrip;
var
  LKey, LNonce, LAAD, LPlain: TBytes;
  LEncrypted, LRecovered: TBytes;
  LError: string;
begin
  AssertTrue(TLS13AEADIsSupported(TLS13_CIPHER_AES_256_GCM_SHA384),
    'AES-256-GCM suite should be supported');

  LKey := HexToBytes('603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4');
  LNonce := HexToBytes('cafebabefacedbaddecaf888');
  LAAD := HexToBytes('feedfacedeadbeeffeedfacedeadbeefabaddad2');
  LPlain := HexToBytes('6bc1bee22e409f96e93d7e117393172a');

  AssertTrue(
    TryTLS13AEADEncrypt(
      TLS13_CIPHER_AES_256_GCM_SHA384,
      LKey,
      LNonce,
      LAAD,
      LPlain,
      LEncrypted,
      LError
    ),
    'TLS13 AEAD encrypt should succeed for AES-256-GCM suite: ' + LError
  );

  AssertTrue(
    TryTLS13AEADDecrypt(
      TLS13_CIPHER_AES_256_GCM_SHA384,
      LKey,
      LNonce,
      LAAD,
      LEncrypted,
      LRecovered,
      LError
    ),
    'TLS13 AEAD decrypt should succeed for AES-256-GCM suite: ' + LError
  );

  AssertBytesEqual(LPlain, LRecovered, 'Recovered AES-256 plaintext mismatch');
end;

procedure TestAESAuthenticationFailure;
var
  LKey, LNonce, LAAD, LPlain: TBytes;
  LEncrypted, LRecovered: TBytes;
  LError: string;
begin
  LKey := HexToBytes('000102030405060708090a0b0c0d0e0f');
  LNonce := HexToBytes('f0f1f2f3f4f5f6f7f8f9fafb');
  LAAD := HexToBytes('feedfacedeadbeeffeedfacedeadbeefabaddad2');
  LPlain := HexToBytes('00112233445566778899aabbccddeeff');

  AssertTrue(
    TryTLS13AEADEncrypt(
      TLS13_CIPHER_AES_128_GCM_SHA256,
      LKey,
      LNonce,
      LAAD,
      LPlain,
      LEncrypted,
      LError
    ),
    'AES-128 setup encrypt should succeed: ' + LError
  );

  AssertTrue(Length(LEncrypted) > 0, 'Encrypted payload should not be empty');
  LEncrypted[High(LEncrypted)] := LEncrypted[High(LEncrypted)] xor $01;

  AssertTrue(
    not TryTLS13AEADDecrypt(
      TLS13_CIPHER_AES_128_GCM_SHA256,
      LKey,
      LNonce,
      LAAD,
      LEncrypted,
      LRecovered,
      LError
    ),
    'AES-128 decrypt should fail when auth tag is tampered'
  );
end;

begin
  WriteLn('Testing TLS 1.3 AEAD dispatch...');

  TestChaChaSuiteRoundtrip;
  TestAES128SuiteRoundtrip;
  TestAES256SuiteRoundtrip;
  TestAESAuthenticationFailure;

  WriteLn('✅ TLS 1.3 AEAD dispatch checks passed');
end.
