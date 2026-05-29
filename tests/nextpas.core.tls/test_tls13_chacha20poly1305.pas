program test_tls13_chacha20poly1305;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.tls13.chacha20poly1305;

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

procedure TestRFC8439AEADVector;
var
  LKey: TBytes;
  LNonce: TBytes;
  LAAD: TBytes;
  LPlain: TBytes;
  LCipher: TBytes;
  LTag: TBytes;
  LExpectedCipher: TBytes;
  LExpectedTag: TBytes;
begin
  // RFC 8439, Section 2.8.2
  LKey := HexToBytes('1c9240a5eb55d38af333888604f6b5f0473917c1402b80099dca5cbc207075c0');
  LNonce := HexToBytes('000000000102030405060708');
  LAAD := HexToBytes('f33388860000000000004e91');

  LExpectedCipher := HexToBytes(
    '64a0861575861af460f062c79be643bd5e805cfd345cf389f108670ac76c8cb2' +
    '4c6cfc18755d43eea09ee94e382d26b0bdb7b73c321b0100d4f03b7f355894cf' +
    '332f830e710b97ce98c8a84abd0b948114ad176e008d33bd60f982b1ff37c855' +
    '9797a06ef4f0ef61c186324e2b3506383606907b6a7c02b0f9f6157b53c867e4' +
    'b9166c767b804d46a59b5216cde7a4e99040c5a40433225ee282a1b0a06c523e' +
    'af4534d7f83fa1155b0047718cbc546a0d072b04b3564eea1b422273f548271a' +
    '0bb2316053fa76991955ebd63159434ecebb4e466dae5a1073a6727627097a10' +
    '49e617d91d361094fa68f0ff77987130305beaba2eda04df997b714d6c6f2c29' +
    'a6ad5cb4022b02709b'
  );
  LExpectedTag := HexToBytes('eead9d67890cbb22392336fea1851f38');

  AssertTrue(
    TryChaCha20Poly1305Decrypt(LKey, LNonce, LAAD, LExpectedCipher, LExpectedTag, LPlain),
    'RFC vector decrypt should succeed'
  );

  AssertTrue(
    TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag),
    'Encryption should succeed'
  );

  AssertBytesEqual(LExpectedCipher, LCipher, 'Ciphertext mismatch (RFC 8439 vector)');
  AssertBytesEqual(LExpectedTag, LTag, 'Tag mismatch (RFC 8439 vector)');

  LTag[0] := LTag[0] xor $01;
  AssertTrue(
    not TryChaCha20Poly1305Decrypt(LKey, LNonce, LAAD, LCipher, LTag, LPlain),
    'Decryption should fail with modified tag'
  );
end;

begin
  WriteLn('Testing TLS 1.3 ChaCha20-Poly1305 primitives...');

  TestRFC8439AEADVector;

  WriteLn('✅ TLS 1.3 ChaCha20-Poly1305 checks passed');
end.
