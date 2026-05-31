program test_streaming_operations;

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

function BytesEqual(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(A) <> Length(B) then Exit;

  for I := 0 to High(A) do
    if A[I] <> B[I] then Exit;

  Result := True;
end;

procedure TestStreamingHasher_SHA256_Basic;
var
  LHasher: TStreamingHasher;
  LData1, LData2, LHash: TBytes;
  LExpectedHash: TBytes;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== TStreamingHasher SHA256 Basic Tests ===');

  // Test 1: Create and basic hashing
  LHasher := TStreamingHasher.Create(HASH_SHA256);
  try
    Assert(not LHasher.IsFinalized, 'Should not be finalized initially');

    // Prepare test data
    SetLength(LData1, 100);
    for I := 0 to 99 do
      LData1[I] := Byte(I);

    LHasher.Update(LData1);
    LHash := LHasher.Finalize;

    Assert(Length(LHash) = 32, 'SHA256 hash should be 32 bytes');
    Assert(LHasher.IsFinalized, 'Should be finalized after Finalize call');
  finally
    LHasher.Free;
  end;

  // Test 2: Multiple updates should equal single update
  SetLength(LData1, 50);
  SetLength(LData2, 50);
  for I := 0 to 49 do
  begin
    LData1[I] := Byte(I);
    LData2[I] := Byte(I + 50);
  end;

  // Single update reference
  SetLength(LExpectedHash, 100);
  for I := 0 to 99 do
    LExpectedHash[I] := Byte(I);
  LExpectedHash := TCryptoUtils.SHA256(LExpectedHash);

  // Multiple updates
  LHasher := TStreamingHasher.Create(HASH_SHA256);
  try
    LHasher.Update(LData1);
    LHasher.Update(LData2);
    LHash := LHasher.Finalize;

    Assert(BytesEqual(LHash, LExpectedHash), 'Multiple updates should equal single update');
  finally
    LHasher.Free;
  end;

  // Test 3: Reset and reuse
  LHasher := TStreamingHasher.Create(HASH_SHA256);
  try
    SetLength(LData1, 10);
    for I := 0 to 9 do
      LData1[I] := Byte(I);

    LHasher.Update(LData1);
    LHash := LHasher.Finalize;

    Assert(LHasher.IsFinalized, 'Should be finalized');

    // Reset
    LHasher.Reset;

    Assert(not LHasher.IsFinalized, 'Should not be finalized after Reset');

    // Reuse
    LHasher.Update(LData1);
    LHash := LHasher.Finalize;

    Assert(Length(LHash) = 32, 'Hash after reset should still be 32 bytes');
  finally
    LHasher.Free;
  end;
end;

procedure TestStreamingHasher_SHA512_Basic;
var
  LHasher: TStreamingHasher;
  LData, LHash: TBytes;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== TStreamingHasher SHA512 Basic Tests ===');

  LHasher := TStreamingHasher.Create(HASH_SHA512);
  try
    SetLength(LData, 100);
    for I := 0 to 99 do
      LData[I] := Byte(I);

    LHasher.Update(LData);
    LHash := LHasher.Finalize;

    Assert(Length(LHash) = 64, 'SHA512 hash should be 64 bytes');
    Assert(LHasher.IsFinalized, 'Should be finalized');
  finally
    LHasher.Free;
  end;
end;

procedure TestStreamingHasher_View;
var
  LHasher: TStreamingHasher;
  LData, LHash, LExpectedHash: TBytes;
  LView: TBytesView;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== TStreamingHasher with TBytesView (Zero-Copy) ===');

  SetLength(LData, 100);
  for I := 0 to 99 do
    LData[I] := Byte(I);

  // Expected result using normal method
  LExpectedHash := TCryptoUtils.SHA256(LData);

  // Test with View (zero-copy)
  LHasher := TStreamingHasher.Create(HASH_SHA256);
  try
    LView := TBytesView.FromBytes(LData);
    LHasher.UpdateView(LView);
    LHash := LHasher.Finalize;

    Assert(BytesEqual(LHash, LExpectedHash), 'View update should match normal update');
  finally
    LHasher.Free;
  end;
end;

procedure TestStreamingHasher_ErrorHandling;
var
  LHasher: TStreamingHasher;
  LData: TBytes;
  LHash: TBytes;
  LErrorRaised: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== TStreamingHasher Error Handling ===');

  SetLength(LData, 10);
  for I := 0 to 9 do
    LData[I] := Byte(I);

  // Test: Update after finalize should raise error
  LHasher := TStreamingHasher.Create(HASH_SHA256);
  try
    LHasher.Update(LData);
    LHash := LHasher.Finalize;

    LErrorRaised := False;
    try
      LHasher.Update(LData); // Should raise error
    except
      on E: Exception do
        LErrorRaised := True;
    end;

    Assert(LErrorRaised, 'Update after Finalize should raise error');
  finally
    LHasher.Free;
  end;
end;

procedure TestStreamingCipher_AES_GCM_Encrypt;
var
  LCipher: TStreamingCipher;
  LKey, LIV: TBytes;
  LData1, LData2: TBytes;
  LOut1, LOut2, LFinal, LTag: TBytes;
  LSuccess: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== TStreamingCipher AES-GCM Encryption ===');

  // Setup
  SetLength(LKey, 32);
  SetLength(LIV, 12);
  for I := 0 to 31 do
    LKey[I] := Byte(I);
  for I := 0 to 11 do
    LIV[I] := Byte(I);

  SetLength(LData1, 50);
  SetLength(LData2, 50);
  for I := 0 to 49 do
  begin
    LData1[I] := Byte(I);
    LData2[I] := Byte(I + 50);
  end;

  // Test: Streaming encryption
  LCipher := TStreamingCipher.CreateEncrypt(ENCRYPT_AES_256_GCM, LKey, LIV);
  try
    Assert(LCipher.IsEncrypt, 'Should be in encrypt mode');
    Assert(not LCipher.IsFinalized, 'Should not be finalized initially');

    LSuccess := LCipher.Update(LData1, LOut1);
    Assert(LSuccess, 'First Update should succeed');
    Assert(Length(LOut1) > 0, 'First output should not be empty');

    LSuccess := LCipher.Update(LData2, LOut2);
    Assert(LSuccess, 'Second Update should succeed');

    LSuccess := LCipher.Finalize(LFinal, LTag);
    Assert(LSuccess, 'Finalize should succeed');
    Assert(Length(LTag) = 16, 'GCM tag should be 16 bytes');
    Assert(LCipher.IsFinalized, 'Should be finalized');
  finally
    LCipher.Free;
  end;
end;

procedure TestStreamingCipher_AES_GCM_RoundTrip;
var
  LEncCipher, LDecCipher: TStreamingCipher;
  LKey, LIV: TBytes;
  LOriginalData, LData1, LData2: TBytes;
  LEncOut1, LEncOut2, LEncFinal, LTag: TBytes;
  LDecOut1, LDecOut2, LDecFinal: TBytes;
  LDecrypted: TBytes;
  LSuccess: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== TStreamingCipher AES-GCM Round-Trip ===');

  // Setup
  SetLength(LKey, 32);
  SetLength(LIV, 12);
  for I := 0 to 31 do
    LKey[I] := Byte(I);
  for I := 0 to 11 do
    LIV[I] := Byte(I);

  SetLength(LData1, 50);
  SetLength(LData2, 50);
  for I := 0 to 49 do
  begin
    LData1[I] := Byte(I);
    LData2[I] := Byte(I + 50);
  end;

  // Save original
  SetLength(LOriginalData, 100);
  for I := 0 to 99 do
    LOriginalData[I] := Byte(I);

  // Encrypt
  LEncCipher := TStreamingCipher.CreateEncrypt(ENCRYPT_AES_256_GCM, LKey, LIV);
  try
    LSuccess := LEncCipher.Update(LData1, LEncOut1);
    Assert(LSuccess, 'Encrypt: First Update should succeed');

    LSuccess := LEncCipher.Update(LData2, LEncOut2);
    Assert(LSuccess, 'Encrypt: Second Update should succeed');

    LSuccess := LEncCipher.Finalize(LEncFinal, LTag);
    Assert(LSuccess, 'Encrypt: Finalize should succeed');
  finally
    LEncCipher.Free;
  end;

  // Decrypt
  LDecCipher := TStreamingCipher.CreateDecrypt(ENCRYPT_AES_256_GCM, LKey, LIV);
  try
    Assert(not LDecCipher.IsEncrypt, 'Should be in decrypt mode');

    LSuccess := LDecCipher.Update(LEncOut1, LDecOut1);
    Assert(LSuccess, 'Decrypt: First Update should succeed');

    LSuccess := LDecCipher.Update(LEncOut2, LDecOut2);
    Assert(LSuccess, 'Decrypt: Second Update should succeed');

    LSuccess := LDecCipher.Finalize(LDecFinal, LTag);
    Assert(LSuccess, 'Decrypt: Finalize should succeed');
  finally
    LDecCipher.Free;
  end;

  // Reconstruct decrypted data
  SetLength(LDecrypted, Length(LDecOut1) + Length(LDecOut2) + Length(LDecFinal));
  if Length(LDecOut1) > 0 then
    Move(LDecOut1[0], LDecrypted[0], Length(LDecOut1));
  if Length(LDecOut2) > 0 then
    Move(LDecOut2[0], LDecrypted[Length(LDecOut1)], Length(LDecOut2));
  if Length(LDecFinal) > 0 then
    Move(LDecFinal[0], LDecrypted[Length(LDecOut1) + Length(LDecOut2)], Length(LDecFinal));

  Assert(BytesEqual(LDecrypted, LOriginalData), 'Decrypted data should match original');
end;

procedure TestStreamingCipher_View;
var
  LCipher: TStreamingCipher;
  LKey, LIV: TBytes;
  LData, LOut, LFinal, LTag: TBytes;
  LView: TBytesView;
  LSuccess: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== TStreamingCipher with TBytesView (Zero-Copy) ===');

  SetLength(LKey, 32);
  SetLength(LIV, 12);
  for I := 0 to 31 do
    LKey[I] := Byte(I);
  for I := 0 to 11 do
    LIV[I] := Byte(I);

  SetLength(LData, 100);
  for I := 0 to 99 do
    LData[I] := Byte(I);

  LCipher := TStreamingCipher.CreateEncrypt(ENCRYPT_AES_256_GCM, LKey, LIV);
  try
    LView := TBytesView.FromBytes(LData);
    LSuccess := LCipher.UpdateView(LView, LOut);

    Assert(LSuccess, 'UpdateView should succeed');
    Assert(Length(LOut) > 0, 'Output should not be empty');

    LSuccess := LCipher.Finalize(LFinal, LTag);
    Assert(LSuccess, 'Finalize after UpdateView should succeed');
  finally
    LCipher.Free;
  end;
end;

procedure TestStreamingCipher_WrongTag;
var
  LEncCipher, LDecCipher: TStreamingCipher;
  LKey, LIV: TBytes;
  LData, LEncOut, LEncFinal, LTag: TBytes;
  LDecOut, LDecFinal: TBytes;
  LSuccess: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== TStreamingCipher Wrong Tag Test ===');

  SetLength(LKey, 32);
  SetLength(LIV, 12);
  for I := 0 to 31 do
    LKey[I] := Byte(I);
  for I := 0 to 11 do
    LIV[I] := Byte(I);

  SetLength(LData, 50);
  for I := 0 to 49 do
    LData[I] := Byte(I);

  // Encrypt
  LEncCipher := TStreamingCipher.CreateEncrypt(ENCRYPT_AES_256_GCM, LKey, LIV);
  try
    LEncCipher.Update(LData, LEncOut);
    LEncCipher.Finalize(LEncFinal, LTag);
  finally
    LEncCipher.Free;
  end;

  // Corrupt tag
  LTag[0] := LTag[0] xor $FF;

  // Try to decrypt with wrong tag
  LDecCipher := TStreamingCipher.CreateDecrypt(ENCRYPT_AES_256_GCM, LKey, LIV);
  try
    LDecCipher.Update(LEncOut, LDecOut);
    LSuccess := LDecCipher.Finalize(LDecFinal, LTag);

    Assert(not LSuccess, 'Decrypt with wrong tag should fail');
  finally
    LDecCipher.Free;
  end;
end;

procedure PrintSummary;
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  Phase 2.3.4 Streaming Operations Test Suite');
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
    WriteLn('  Phase 2.3.4: Streaming Operations Tests');
    WriteLn('═══════════════════════════════════════════════════════════');

    TestStreamingHasher_SHA256_Basic;
    TestStreamingHasher_SHA512_Basic;
    TestStreamingHasher_View;
    TestStreamingHasher_ErrorHandling;

    TestStreamingCipher_AES_GCM_Encrypt;
    TestStreamingCipher_AES_GCM_RoundTrip;
    TestStreamingCipher_View;
    TestStreamingCipher_WrongTag;

    PrintSummary;

    WriteLn('✓ Phase 2.3.4 Streaming operations implementation complete!');
    WriteLn('✓ All streaming hash and cipher operations working correctly!');
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
