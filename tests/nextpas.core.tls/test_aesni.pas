program test_aesni;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils, nextpas.core.tls.crypto.aesni;

function BytesToHex(const B: array of Byte; ALen: Integer): string;
var I: Integer;
begin
  Result := '';
  for I := 0 to ALen - 1 do
    Result := Result + LowerCase(IntToHex(B[I], 2));
end;

var
  LKey, LPlain, LCipher: TAESNIBlock;
  LExpKey: TAESNIExpandedKey128;
  LDecrypted: TAESNIBlock;
begin
  WriteLn('AES-NI available: ', IsAESNIAvailable);

  if not IsAESNIAvailable then
  begin
    WriteLn('AES-NI not supported on this CPU, skipping test');
    Halt(0);
  end;

  // NIST AES-128 test vector
  // Key: 2b7e151628aed2a6abf7158809cf4f3c
  // Plaintext: 6bc1bee22e409f96e93d7e117393172a
  // Ciphertext: 3ad77bb40d7a3660a89ecaf32466ef97
  LKey[0] := $2b; LKey[1] := $7e; LKey[2] := $15; LKey[3] := $16;
  LKey[4] := $28; LKey[5] := $ae; LKey[6] := $d2; LKey[7] := $a6;
  LKey[8] := $ab; LKey[9] := $f7; LKey[10] := $15; LKey[11] := $88;
  LKey[12] := $09; LKey[13] := $cf; LKey[14] := $4f; LKey[15] := $3c;

  LPlain[0] := $6b; LPlain[1] := $c1; LPlain[2] := $be; LPlain[3] := $e2;
  LPlain[4] := $2e; LPlain[5] := $40; LPlain[6] := $9f; LPlain[7] := $96;
  LPlain[8] := $e9; LPlain[9] := $3d; LPlain[10] := $7e; LPlain[11] := $11;
  LPlain[12] := $73; LPlain[13] := $93; LPlain[14] := $17; LPlain[15] := $2a;

  AESNIExpandKey128(LKey, LExpKey);
  AESNIEncryptBlock128(LPlain, LCipher, LExpKey);

  WriteLn('Plaintext:  ', BytesToHex(LPlain, 16));
  WriteLn('Ciphertext: ', BytesToHex(LCipher, 16));
  WriteLn('Expected:   3ad77bb40d7a3660a89ecaf32466ef97');
  WriteLn('Match: ', BytesToHex(LCipher, 16) = '3ad77bb40d7a3660a89ecaf32466ef97');

  // Test decrypt
  AESNIDecryptBlock128(LCipher, LDecrypted, LExpKey);
  WriteLn('Decrypted:  ', BytesToHex(LDecrypted, 16));
  WriteLn('Decrypt OK: ', BytesToHex(LDecrypted, 16) = BytesToHex(LPlain, 16));
end.
