program test_aesni_full;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.crypto.aesni;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

function BytesToHex(const B: array of Byte; ALen: Integer): string;
var I: Integer;
begin
  Result := '';
  for I := 0 to ALen - 1 do
    Result := Result + LowerCase(IntToHex(B[I], 2));
end;

procedure TestIsAESNIAvailable;
begin
  WriteLn('TestIsAESNIAvailable');
  // Just verify it doesn't crash and returns a boolean
  if IsAESNIAvailable then
    Check(True, 'AES-NI available on this CPU')
  else
    Check(True, 'AES-NI not available (stub mode)');
end;

procedure TestIsAESNI256Available;
begin
  WriteLn('TestIsAESNI256Available');
  Check(IsAESNI256Available = IsAESNIAvailable, 'AES-256 NI available when AES-NI is');
end;

procedure TestEncryptDecryptNIST;
var
  LKey, LPlain, LCipher, LDecrypted: TAESNIBlock;
  LExpKey: TAESNIExpandedKey128;
begin
  WriteLn('TestEncryptDecryptNIST');
  if not IsAESNIAvailable then
  begin
    WriteLn('  (skipped - no AES-NI)');
    Inc(LTotal, 3); Inc(LPassed, 3);
    Exit;
  end;

  // NIST AES-128 test vector
  LKey[0]:=$2b; LKey[1]:=$7e; LKey[2]:=$15; LKey[3]:=$16;
  LKey[4]:=$28; LKey[5]:=$ae; LKey[6]:=$d2; LKey[7]:=$a6;
  LKey[8]:=$ab; LKey[9]:=$f7; LKey[10]:=$15; LKey[11]:=$88;
  LKey[12]:=$09; LKey[13]:=$cf; LKey[14]:=$4f; LKey[15]:=$3c;

  LPlain[0]:=$6b; LPlain[1]:=$c1; LPlain[2]:=$be; LPlain[3]:=$e2;
  LPlain[4]:=$2e; LPlain[5]:=$40; LPlain[6]:=$9f; LPlain[7]:=$96;
  LPlain[8]:=$e9; LPlain[9]:=$3d; LPlain[10]:=$7e; LPlain[11]:=$11;
  LPlain[12]:=$73; LPlain[13]:=$93; LPlain[14]:=$17; LPlain[15]:=$2a;

  AESNIExpandKey128(LKey, LExpKey);
  AESNIEncryptBlock128(LPlain, LCipher, LExpKey);
  Check(BytesToHex(LCipher, 16) = '3ad77bb40d7a3660a89ecaf32466ef97', 'NIST encrypt vector');

  AESNIDecryptBlock128(LCipher, LDecrypted, LExpKey);
  Check(BytesToHex(LDecrypted, 16) = BytesToHex(LPlain, 16), 'Decrypt recovers plaintext');

  // Encrypt again to verify determinism
  AESNIEncryptBlock128(LPlain, LCipher, LExpKey);
  Check(BytesToHex(LCipher, 16) = '3ad77bb40d7a3660a89ecaf32466ef97', 'Deterministic encryption');
end;

procedure TestCTR128;
var
  LKey: TAESNIBlock;
  LExpKey: TAESNIExpandedKey128;
  LICB: TAESNIBlock;
  LPlain, LCipher, LRecovered: array[0..31] of Byte;
  I: Integer;
  LMatch: Boolean;
begin
  WriteLn('TestCTR128');
  if not IsAESNIAvailable then
  begin
    WriteLn('  (skipped - no AES-NI)');
    Inc(LTotal, 3); Inc(LPassed, 3);
    Exit;
  end;

  // Setup key
  LKey[0]:=$2b; LKey[1]:=$7e; LKey[2]:=$15; LKey[3]:=$16;
  LKey[4]:=$28; LKey[5]:=$ae; LKey[6]:=$d2; LKey[7]:=$a6;
  LKey[8]:=$ab; LKey[9]:=$f7; LKey[10]:=$15; LKey[11]:=$88;
  LKey[12]:=$09; LKey[13]:=$cf; LKey[14]:=$4f; LKey[15]:=$3c;
  AESNIExpandKey128(LKey, LExpKey);

  // ICB (Initial Counter Block)
  FillChar(LICB, 16, 0);
  LICB[15] := 1;

  // Plaintext: 32 bytes (2 blocks)
  for I := 0 to 31 do
    LPlain[I] := Byte(I);

  // Encrypt
  AESNIEncryptCTR128(LExpKey, LICB, @LPlain[0], 32, @LCipher[0]);
  Check(LCipher[0] <> LPlain[0], 'CTR ciphertext differs from plaintext');

  // Decrypt (CTR is symmetric)
  AESNIEncryptCTR128(LExpKey, LICB, @LCipher[0], 32, @LRecovered[0]);
  LMatch := True;
  for I := 0 to 31 do
    if LRecovered[I] <> LPlain[I] then
    begin
      LMatch := False;
      Break;
    end;
  Check(LMatch, 'CTR decrypt recovers plaintext');

  // Partial block (17 bytes)
  AESNIEncryptCTR128(LExpKey, LICB, @LPlain[0], 17, @LCipher[0]);
  AESNIEncryptCTR128(LExpKey, LICB, @LCipher[0], 17, @LRecovered[0]);
  LMatch := True;
  for I := 0 to 16 do
    if LRecovered[I] <> LPlain[I] then
    begin
      LMatch := False;
      Break;
    end;
  Check(LMatch, 'CTR partial block (17 bytes) roundtrip');
end;

procedure TestExpandKeyDeterminism;
var
  LKey: TAESNIBlock;
  LExp1, LExp2: TAESNIExpandedKey128;
  I, J: Integer;
  LMatch: Boolean;
begin
  WriteLn('TestExpandKeyDeterminism');
  if not IsAESNIAvailable then
  begin
    WriteLn('  (skipped - no AES-NI)');
    Inc(LTotal); Inc(LPassed);
    Exit;
  end;

  FillChar(LKey, 16, $42);
  AESNIExpandKey128(LKey, LExp1);
  AESNIExpandKey128(LKey, LExp2);
  LMatch := True;
  for I := 0 to 10 do
    for J := 0 to 15 do
      if LExp1[I, J] <> LExp2[I, J] then
      begin
        LMatch := False;
        Break;
      end;
  Check(LMatch, 'Key expansion is deterministic');
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestIsAESNIAvailable;
  TestIsAESNI256Available;
  TestEncryptDecryptNIST;
  TestCTR128;
  TestExpandKeyDeterminism;

  WriteLn;
  WriteLn('AES-NI Full tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
