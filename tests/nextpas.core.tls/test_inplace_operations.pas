program test_inplace_operations;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.crypto.utils;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ FAILED: ', AMessage);
  end;
end;

procedure TestAES_GCM_EncryptInPlace_Basic;
var
  LData, LKey, LIV, LTag: TBytes;
  LOriginalData: TBytes;
  LSuccess: Boolean;
  LDataChanged: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== AES_GCM_EncryptInPlace Basic Tests ===');

  // Test 1: Valid encryption
  SetLength(LData, 64);
  SetLength(LKey, 32);
  SetLength(LIV, 12);

  for I := 0 to 63 do
    LData[I] := Byte(I);
  for I := 0 to 31 do
    LKey[I] := Byte(I);
  for I := 0 to 11 do
    LIV[I] := Byte(I);

  // Save original data for comparison
  SetLength(LOriginalData, Length(LData));
  Move(LData[0], LOriginalData[0], Length(LData));

  LSuccess := TCryptoUtils.AES_GCM_EncryptInPlace(LData, LKey, LIV, LTag);

  Assert(LSuccess, 'EncryptInPlace: Should succeed with valid inputs');
  Assert(Length(LTag) = 16, 'EncryptInPlace: Tag should be 16 bytes');
  Assert(Length(LData) >= 64, 'EncryptInPlace: Data length should be preserved');

  // Verify data was actually modified
  LDataChanged := False;
  for I := 0 to 63 do
  begin
    if LData[I] <> LOriginalData[I] then
    begin
      LDataChanged := True;
      Break;
    end;
  end;
  Assert(LDataChanged, 'EncryptInPlace: Data should be modified after encryption');

  // Test 2: Wrong key size
  SetLength(LData, 64);
  SetLength(LKey, 16);  // Wrong size
  SetLength(LIV, 12);

  for I := 0 to 63 do
    LData[I] := Byte(I);

  LSuccess := TCryptoUtils.AES_GCM_EncryptInPlace(LData, LKey, LIV, LTag);
  Assert(not LSuccess, 'EncryptInPlace: Should fail with wrong key size');

  // Test 3: Wrong IV size
  SetLength(LData, 64);
  SetLength(LKey, 32);
  SetLength(LIV, 16);  // Wrong size

  for I := 0 to 63 do
    LData[I] := Byte(I);

  LSuccess := TCryptoUtils.AES_GCM_EncryptInPlace(LData, LKey, LIV, LTag);
  Assert(not LSuccess, 'EncryptInPlace: Should fail with wrong IV size');

  // Test 4: Empty data
  SetLength(LData, 0);
  SetLength(LKey, 32);
  SetLength(LIV, 12);

  LSuccess := TCryptoUtils.AES_GCM_EncryptInPlace(LData, LKey, LIV, LTag);
  Assert(not LSuccess, 'EncryptInPlace: Should fail with empty data');
end;

procedure TestAES_GCM_DecryptInPlace_Basic;
var
  LData, LKey, LIV, LTag: TBytes;
  LOriginalData: TBytes;
  LSuccess: Boolean;
  LMatch: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== AES_GCM_DecryptInPlace Basic Tests ===');

  // Test 1: Encrypt then decrypt (round trip)
  SetLength(LData, 64);
  SetLength(LKey, 32);
  SetLength(LIV, 12);

  for I := 0 to 63 do
    LData[I] := Byte(I);
  for I := 0 to 31 do
    LKey[I] := Byte(I);
  for I := 0 to 11 do
    LIV[I] := Byte(I);

  // Save original plaintext
  SetLength(LOriginalData, Length(LData));
  Move(LData[0], LOriginalData[0], Length(LData));

  // Encrypt
  LSuccess := TCryptoUtils.AES_GCM_EncryptInPlace(LData, LKey, LIV, LTag);
  Assert(LSuccess, 'Setup: Encryption should succeed');

  // Decrypt
  LSuccess := TCryptoUtils.AES_GCM_DecryptInPlace(LData, LKey, LIV, LTag);
  Assert(LSuccess, 'DecryptInPlace: Should succeed with valid inputs');

  // Verify decrypted data matches original
  LMatch := True;
  for I := 0 to 63 do
  begin
    if LData[I] <> LOriginalData[I] then
    begin
      LMatch := False;
      Break;
    end;
  end;
  Assert(LMatch, 'DecryptInPlace: Decrypted data should match original plaintext');

  // Test 2: Wrong tag (authentication failure)
  SetLength(LData, 64);
  for I := 0 to 63 do
    LData[I] := Byte(I);

  // Encrypt first
  LSuccess := TCryptoUtils.AES_GCM_EncryptInPlace(LData, LKey, LIV, LTag);
  Assert(LSuccess, 'Setup: Encryption should succeed');

  // Modify tag
  LTag[0] := LTag[0] xor $FF;

  // Try to decrypt with wrong tag
  LSuccess := TCryptoUtils.AES_GCM_DecryptInPlace(LData, LKey, LIV, LTag);
  Assert(not LSuccess, 'DecryptInPlace: Should fail with wrong tag');

  // Test 3: Wrong key size
  SetLength(LData, 64);
  SetLength(LKey, 16);  // Wrong size
  SetLength(LIV, 12);
  SetLength(LTag, 16);

  LSuccess := TCryptoUtils.AES_GCM_DecryptInPlace(LData, LKey, LIV, LTag);
  Assert(not LSuccess, 'DecryptInPlace: Should fail with wrong key size');

  // Test 4: Wrong IV size
  SetLength(LData, 64);
  SetLength(LKey, 32);
  SetLength(LIV, 16);  // Wrong size
  SetLength(LTag, 16);

  LSuccess := TCryptoUtils.AES_GCM_DecryptInPlace(LData, LKey, LIV, LTag);
  Assert(not LSuccess, 'DecryptInPlace: Should fail with wrong IV size');

  // Test 5: Wrong tag size
  SetLength(LData, 64);
  SetLength(LKey, 32);
  SetLength(LIV, 12);
  SetLength(LTag, 8);  // Wrong size

  LSuccess := TCryptoUtils.AES_GCM_DecryptInPlace(LData, LKey, LIV, LTag);
  Assert(not LSuccess, 'DecryptInPlace: Should fail with wrong tag size');
end;

procedure TestInPlace_vs_Normal;
var
  LDataInPlace, LDataNormal, LKey, LIV, LTag, LTagNormal: TBytes;
  LSuccessInPlace: Boolean;
  LCiphertextNormal: TBytes;
  LCiphertextLen: Integer;
  LMatch: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== InPlace vs Normal Comparison Tests ===');

  // Test 1: InPlace encryption should produce same result as normal encryption
  SetLength(LDataInPlace, 64);
  SetLength(LDataNormal, 64);
  SetLength(LKey, 32);
  SetLength(LIV, 12);

  for I := 0 to 63 do
  begin
    LDataInPlace[I] := Byte(I);
    LDataNormal[I] := Byte(I);
  end;
  for I := 0 to 31 do
    LKey[I] := Byte(I);
  for I := 0 to 11 do
    LIV[I] := Byte(I);

  // Normal encryption
  LCiphertextNormal := TCryptoUtils.AES_GCM_Encrypt(LDataNormal, LKey, LIV);

  // InPlace encryption
  LSuccessInPlace := TCryptoUtils.AES_GCM_EncryptInPlace(LDataInPlace, LKey, LIV, LTag);
  Assert(LSuccessInPlace, 'Setup: InPlace encryption should succeed');

  // Extract tag from normal encryption (last 16 bytes)
  SetLength(LTagNormal, 16);
  Move(LCiphertextNormal[Length(LCiphertextNormal) - 16], LTagNormal[0], 16);

  // Compare ciphertexts (excluding tag from normal result)
  LCiphertextLen := Length(LCiphertextNormal) - 16;

  LMatch := (Length(LDataInPlace) = LCiphertextLen);
  if LMatch then
  begin
    for I := 0 to LCiphertextLen - 1 do
    begin
      if LDataInPlace[I] <> LCiphertextNormal[I] then
      begin
        LMatch := False;
        Break;
      end;
    end;
  end;
  Assert(LMatch, 'InPlace vs Normal: Ciphertext should match');

  // Compare tags
  LMatch := True;
  for I := 0 to 15 do
  begin
    if LTag[I] <> LTagNormal[I] then
    begin
      LMatch := False;
      Break;
    end;
  end;
  Assert(LMatch, 'InPlace vs Normal: Tags should match');
end;

procedure TestInPlace_LargeData;
var
  LData, LKey, LIV, LTag: TBytes;
  LOriginalData: TBytes;
  LSuccess: Boolean;
  LMatch: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== InPlace Large Data Tests ===');

  // Test with 1KB data
  SetLength(LData, 1024);
  SetLength(LKey, 32);
  SetLength(LIV, 12);

  for I := 0 to 1023 do
    LData[I] := Byte(I mod 256);
  for I := 0 to 31 do
    LKey[I] := Byte(I);
  for I := 0 to 11 do
    LIV[I] := Byte(I);

  // Save original
  SetLength(LOriginalData, Length(LData));
  Move(LData[0], LOriginalData[0], Length(LData));

  // Encrypt
  LSuccess := TCryptoUtils.AES_GCM_EncryptInPlace(LData, LKey, LIV, LTag);
  Assert(LSuccess, '1KB: Encryption should succeed');

  // Decrypt
  LSuccess := TCryptoUtils.AES_GCM_DecryptInPlace(LData, LKey, LIV, LTag);
  Assert(LSuccess, '1KB: Decryption should succeed');

  // Verify
  LMatch := True;
  for I := 0 to 1023 do
  begin
    if LData[I] <> LOriginalData[I] then
    begin
      LMatch := False;
      Break;
    end;
  end;
  Assert(LMatch, '1KB: Round trip should preserve data');

  // Test with 64KB data
  SetLength(LData, 65536);
  for I := 0 to 65535 do
    LData[I] := Byte(I mod 256);

  // Save original
  SetLength(LOriginalData, Length(LData));
  Move(LData[0], LOriginalData[0], Length(LData));

  // Encrypt
  LSuccess := TCryptoUtils.AES_GCM_EncryptInPlace(LData, LKey, LIV, LTag);
  Assert(LSuccess, '64KB: Encryption should succeed');

  // Decrypt
  LSuccess := TCryptoUtils.AES_GCM_DecryptInPlace(LData, LKey, LIV, LTag);
  Assert(LSuccess, '64KB: Decryption should succeed');

  // Verify
  LMatch := True;
  for I := 0 to 65535 do
  begin
    if LData[I] <> LOriginalData[I] then
    begin
      LMatch := False;
      Break;
    end;
  end;
  Assert(LMatch, '64KB: Round trip should preserve data');
end;

procedure TestInPlace_ZeroCopyBenefit;
var
  LData, LKey, LIV, LTag: TBytes;
  LOriginalPtr: PByte;
  LSuccess: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== InPlace Zero-Copy Benefit Tests ===');

  SetLength(LData, 64);
  SetLength(LKey, 32);
  SetLength(LIV, 12);

  for I := 0 to 63 do
    LData[I] := Byte(I);
  for I := 0 to 31 do
    LKey[I] := Byte(I);
  for I := 0 to 11 do
    LIV[I] := Byte(I);

  // Get pointer before encryption
  LOriginalPtr := @LData[0];

  // Encrypt in place
  LSuccess := TCryptoUtils.AES_GCM_EncryptInPlace(LData, LKey, LIV, LTag);
  Assert(LSuccess, 'Setup: Encryption should succeed');

  // Verify pointer is the same (no reallocation for same-size data)
  // Note: FreePascal may reallocate if length changes, but for GCM with same size it should be stable
  Assert(@LData[0] = LOriginalPtr, 'InPlace: Array pointer should remain the same');
end;

procedure PrintSummary;
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  Phase 2.3.3 In-Place Operations Test Suite');
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn;
  WriteLn('Test Summary:');
  WriteLn('  Tests Passed: ', GTestsPassed);
  WriteLn('  Tests Failed: ', GTestsFailed);
  WriteLn('  Total Tests:  ', GTestsPassed + GTestsFailed);
  WriteLn;

  if GTestsFailed = 0 then
  begin
    WriteLn('  ✓ ALL TESTS PASSED!');
    WriteLn;
  end
  else
  begin
    WriteLn('  ✗ SOME TESTS FAILED!');
    WriteLn;
    Halt(1);
  end;
end;

begin
  try
    WriteLn('═══════════════════════════════════════════════════════════');
    WriteLn('  Phase 2.3.3: In-Place Operations Tests');
    WriteLn('═══════════════════════════════════════════════════════════');

    TestAES_GCM_EncryptInPlace_Basic;
    TestAES_GCM_DecryptInPlace_Basic;
    TestInPlace_vs_Normal;
    TestInPlace_LargeData;
    TestInPlace_ZeroCopyBenefit;

    PrintSummary;

    WriteLn('✓ Phase 2.3.3 In-place operations implementation complete!');
    WriteLn('✓ All in-place encryption/decryption working correctly!');
    WriteLn;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('✗ Unexpected error: ', E.Message);
      Halt(1);
    end;
  end;
end.
