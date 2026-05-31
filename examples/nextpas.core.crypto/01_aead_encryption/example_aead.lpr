program example_aead;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.crypto.aesgcm;

var
  LKey, LNonce, LPlaintext, LAAD: TBytes;
  LCiphertext, LTag, LDecrypted: TBytes;
  I: Integer;
begin
  WriteLn('=== AES-256-GCM Authenticated Encryption ===');
  WriteLn;

  // Generate a 256-bit key (in production, use a KDF or secure random)
  SetLength(LKey, 32);
  for I := 0 to 31 do LKey[I] := Byte(I);

  // 96-bit nonce (must be unique per encryption with same key)
  SetLength(LNonce, 12);
  for I := 0 to 11 do LNonce[I] := Byte(I + $A0);

  // Message to encrypt
  LPlaintext := TEncoding.UTF8.GetBytes(UnicodeString('Hello, nextPas crypto!'));

  // Additional authenticated data (not encrypted, but integrity-protected)
  LAAD := TEncoding.UTF8.GetBytes(UnicodeString('metadata'));

  // Encrypt
  if PurePascalAESGCMEncrypt(LKey, LNonce, LPlaintext, LAAD, LCiphertext, LTag) then
    WriteLn('Encrypted: ', Length(LCiphertext), ' bytes + 16-byte tag')
  else
  begin
    WriteLn('ERROR: encryption failed');
    Halt(1);
  end;

  // Decrypt
  if PurePascalAESGCMDecrypt(LKey, LNonce, LCiphertext, LTag, LAAD, LDecrypted) then
    WriteLn('Decrypted: ', TEncoding.UTF8.GetString(LDecrypted))
  else
  begin
    WriteLn('ERROR: decryption failed (tampered?)');
    Halt(1);
  end;

  // Tamper detection: modify ciphertext
  LCiphertext[0] := LCiphertext[0] xor $FF;
  if not PurePascalAESGCMDecrypt(LKey, LNonce, LCiphertext, LTag, LAAD, LDecrypted) then
    WriteLn('Tamper detected (expected)')
  else
    WriteLn('ERROR: tamper not detected!');

  WriteLn;
  WriteLn('nextpas.core.crypto.aesgcm=ready');
end.
