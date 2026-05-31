program test_zerocopy_view;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.crypto.utils,
  nextpas.core.tls.encoding;

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

procedure TestTBytesViewBasics;
var
  LData: TBytes;
  LView: TBytesView;
  LResult: TBytes;
  LSlice: TBytesView;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== TBytesView Basic Tests ===');

  // Test 1: FromBytes
  SetLength(LData, 10);
  for I := 0 to 9 do
    LData[I] := Byte(I);

  LView := TBytesView.FromBytes(LData);
  Assert(LView.Length = 10, 'FromBytes: Length should be 10');
  Assert(LView.Data <> nil, 'FromBytes: Data pointer should not be nil');
  Assert(LView.IsValid, 'FromBytes: View should be valid');
  Assert(not LView.IsEmpty, 'FromBytes: View should not be empty');

  // Test 2: GetByte
  Assert(LView.GetByte(0) = 0, 'GetByte(0) should return 0');
  Assert(LView.GetByte(5) = 5, 'GetByte(5) should return 5');
  Assert(LView.GetByte(9) = 9, 'GetByte(9) should return 9');

  // Test 3: AsBytes (conversion)
  LResult := LView.AsBytes;
  Assert(Length(LResult) = 10, 'AsBytes: Result length should be 10');
  Assert(LResult[0] = 0, 'AsBytes: First byte should be 0');
  Assert(LResult[9] = 9, 'AsBytes: Last byte should be 9');

  // Test 4: Empty view
  LView := TBytesView.Empty;
  Assert(LView.Length = 0, 'Empty: Length should be 0');
  Assert(LView.Data = nil, 'Empty: Data should be nil');
  Assert(LView.IsEmpty, 'Empty: Should be empty');
  Assert(not LView.IsValid, 'Empty: Should not be valid');

  // Test 5: FromPtr
  SetLength(LData, 5);
  for I := 0 to 4 do
    LData[I] := Byte(100 + I);

  LView := TBytesView.FromPtr(@LData[0], 5);
  Assert(LView.Length = 5, 'FromPtr: Length should be 5');
  Assert(LView.Data <> nil, 'FromPtr: Data should not be nil');
  Assert(LView.GetByte(0) = 100, 'FromPtr: First byte should be 100');
  Assert(LView.GetByte(4) = 104, 'FromPtr: Last byte should be 104');

  // Test 6: Slice
  SetLength(LData, 20);
  for I := 0 to 19 do
    LData[I] := Byte(I);

  LView := TBytesView.FromBytes(LData);

  // Slice middle
  LSlice := LView.Slice(5, 10);
  Assert(LSlice.Length = 10, 'Slice: Length should be 10');
  Assert(LSlice.GetByte(0) = 5, 'Slice: First byte should be 5');
  Assert(LSlice.GetByte(9) = 14, 'Slice: Last byte should be 14');

  // Slice to end
  LSlice := LView.Slice(15, 100);
  Assert(LSlice.Length = 5, 'Slice to end: Length should be 5 (auto-adjusted)');
  Assert(LSlice.GetByte(0) = 15, 'Slice to end: First byte should be 15');

  // Slice out of bounds
  LSlice := LView.Slice(100, 10);
  Assert(LSlice.IsEmpty, 'Slice out of bounds: Should be empty');
end;

procedure TestSHA256View;
var
  LData: TBytes;
  LView: TBytesView;
  LHashView, LHashNormal: TBytes;
  LMatch: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== SHA256View Tests ===');

  // Test 1: Small data
  SetLength(LData, 64);
  for I := 0 to 63 do
    LData[I] := Byte(I);

  LView := TBytesView.FromBytes(LData);
  LHashView := TCryptoUtils.SHA256View(LView);
  LHashNormal := TCryptoUtils.SHA256(LData);

  Assert(Length(LHashView) = 32, 'SHA256View: Hash length should be 32');

  LMatch := True;
  for I := 0 to 31 do
    if LHashView[I] <> LHashNormal[I] then
      LMatch := False;

  Assert(LMatch, 'SHA256View: Should produce same result as SHA256');

  // Test 2: Medium data
  SetLength(LData, 1024);
  for I := 0 to 1023 do
    LData[I] := Byte(I mod 256);

  LView := TBytesView.FromBytes(LData);
  LHashView := TCryptoUtils.SHA256View(LView);
  LHashNormal := TCryptoUtils.SHA256(LData);

  LMatch := True;
  for I := 0 to 31 do
    if LHashView[I] <> LHashNormal[I] then
      LMatch := False;

  Assert(LMatch, 'SHA256View (1KB): Should produce same result as SHA256');

  // Test 3: Empty data handling
  SetLength(LData, 0);
  LView := TBytesView.FromBytes(LData);

  try
    LHashView := TCryptoUtils.SHA256View(LView);
    Assert(False, 'SHA256View: Should raise exception for invalid view');
  except
    on E: Exception do
      Assert(True, 'SHA256View: Should raise exception for empty data');
  end;
end;

procedure TestSHA512View;
var
  LData: TBytes;
  LView: TBytesView;
  LHashView, LHashNormal: TBytes;
  LMatch: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== SHA512View Tests ===');

  SetLength(LData, 128);
  for I := 0 to 127 do
    LData[I] := Byte(I);

  LView := TBytesView.FromBytes(LData);
  LHashView := TCryptoUtils.SHA512View(LView);
  LHashNormal := TCryptoUtils.SHA512(LData);

  Assert(Length(LHashView) = 64, 'SHA512View: Hash length should be 64');

  LMatch := True;
  for I := 0 to 63 do
    if LHashView[I] <> LHashNormal[I] then
      LMatch := False;

  Assert(LMatch, 'SHA512View: Should produce same result as SHA512');
end;

procedure TestAES_GCM_EncryptView;
var
  LData, LKey, LIV: TBytes;
  LDataView, LKeyView, LIVView: TBytesView;
  LResult, LTag: TBytes;
  LSuccess: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== AES_GCM_EncryptView Tests ===');

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

  LDataView := TBytesView.FromBytes(LData);
  LKeyView := TBytesView.FromBytes(LKey);
  LIVView := TBytesView.FromBytes(LIV);

  LSuccess := TCryptoUtils.AES_GCM_EncryptView(LDataView, LKeyView, LIVView, LResult, LTag);

  Assert(LSuccess, 'AES_GCM_EncryptView: Encryption should succeed');
  Assert(Length(LResult) > 0, 'AES_GCM_EncryptView: Result should not be empty');
  Assert(Length(LTag) = 16, 'AES_GCM_EncryptView: Tag should be 16 bytes');

  // Test 2: Invalid key size
  SetLength(LKey, 16);  // Wrong size
  LKeyView := TBytesView.FromBytes(LKey);

  LSuccess := TCryptoUtils.AES_GCM_EncryptView(LDataView, LKeyView, LIVView, LResult, LTag);
  Assert(not LSuccess, 'AES_GCM_EncryptView: Should fail with wrong key size');

  // Test 3: Invalid IV size
  SetLength(LKey, 32);
  SetLength(LIV, 16);  // Wrong size
  LKeyView := TBytesView.FromBytes(LKey);
  LIVView := TBytesView.FromBytes(LIV);

  LSuccess := TCryptoUtils.AES_GCM_EncryptView(LDataView, LKeyView, LIVView, LResult, LTag);
  Assert(not LSuccess, 'AES_GCM_EncryptView: Should fail with wrong IV size');
end;

procedure TestAES_GCM_DecryptView;
var
  LData, LKey, LIV: TBytes;
  LDataView, LKeyView, LIVView: TBytesView;
  LCiphertext, LTag, LDecrypted: TBytes;
  LCiphertextView, LTagView: TBytesView;
  LSuccess: Boolean;
  LMatch: Boolean;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== AES_GCM_DecryptView Tests ===');

  // Encrypt first
  SetLength(LData, 64);
  SetLength(LKey, 32);
  SetLength(LIV, 12);

  for I := 0 to 63 do
    LData[I] := Byte(I);
  for I := 0 to 31 do
    LKey[I] := Byte(I);
  for I := 0 to 11 do
    LIV[I] := Byte(I);

  LDataView := TBytesView.FromBytes(LData);
  LKeyView := TBytesView.FromBytes(LKey);
  LIVView := TBytesView.FromBytes(LIV);

  LSuccess := TCryptoUtils.AES_GCM_EncryptView(LDataView, LKeyView, LIVView, LCiphertext, LTag);
  Assert(LSuccess, 'Encrypt for decrypt test: Should succeed');

  // Test 1: Valid decryption
  LCiphertextView := TBytesView.FromBytes(LCiphertext);
  LTagView := TBytesView.FromBytes(LTag);

  LSuccess := TCryptoUtils.AES_GCM_DecryptView(LCiphertextView, LKeyView, LIVView, LTagView, LDecrypted);

  Assert(LSuccess, 'AES_GCM_DecryptView: Decryption should succeed');
  Assert(Length(LDecrypted) = Length(LData), 'AES_GCM_DecryptView: Decrypted length should match original');

  LMatch := True;
  for I := 0 to High(LData) do
    if LDecrypted[I] <> LData[I] then
      LMatch := False;

  Assert(LMatch, 'AES_GCM_DecryptView: Decrypted data should match original');

  // Test 2: Wrong tag (authentication failure)
  SetLength(LTag, 16);
  for I := 0 to 15 do
    LTag[I] := Byte(I);  // Wrong tag

  LTagView := TBytesView.FromBytes(LTag);
  LSuccess := TCryptoUtils.AES_GCM_DecryptView(LCiphertextView, LKeyView, LIVView, LTagView, LDecrypted);

  Assert(not LSuccess, 'AES_GCM_DecryptView: Should fail with wrong tag');
end;

procedure TestBase64EncodeView;
var
  LData: TBytes;
  LView: TBytesView;
  LEncodedNormal: string;
  LEncodedView: string;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== Base64Encode Tests ===');

  // Test 1: Basic encoding parity (TBytes vs TBytesView)
  WriteLn('  Creating test data...');
  SetLength(LData, 64);
  for I := 0 to 63 do
    LData[I] := Byte(I);

  WriteLn('  Creating view from data...');
  LView := TBytesView.FromBytes(LData);

  WriteLn('  Encoding with normal method...');
  LEncodedNormal := TEncodingUtils.Base64Encode(LData);

  WriteLn('  Encoding with view method...');
  LEncodedView := TEncodingUtils.Base64EncodeView(LView);

  Assert(LEncodedNormal <> '', 'Base64Encode: Result should not be empty');
  Assert(Length(LEncodedNormal) > 0, 'Base64Encode: Should produce non-empty result');
  Assert(LEncodedView = LEncodedNormal, 'Base64EncodeView: Should match Base64Encode output');

  // Test 2: Empty data
  SetLength(LData, 0);
  LView := TBytesView.FromBytes(LData);
  LEncodedNormal := TEncodingUtils.Base64Encode(LData);
  LEncodedView := TEncodingUtils.Base64EncodeView(LView);
  Assert(LEncodedNormal = '', 'Base64Encode: Empty data should produce empty string');
  Assert(LEncodedView = '', 'Base64EncodeView: Empty data should produce empty string');
end;

procedure TestZeroCopySemantics;
var
  LData: TBytes;
  LView: TBytesView;
  LOriginalPtr: PByte;
begin
  WriteLn;
  WriteLn('=== Zero-Copy Semantics Tests ===');

  SetLength(LData, 100);
  LOriginalPtr := @LData[0];

  LView := TBytesView.FromBytes(LData);

  Assert(LView.Data = LOriginalPtr, 'Zero-copy: View should point to original data');

  // Modify through view (simulated)
  LData[0] := 99;
  Assert(LView.GetByte(0) = 99, 'Zero-copy: View should reflect changes to original data');
end;

procedure TestSliceOperations;
var
  LData: TBytes;
  LView, LSlice1, LSlice2, LNestedSlice: TBytesView;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== Slice Operations Tests ===');

  SetLength(LData, 100);
  for I := 0 to 99 do
    LData[I] := Byte(I);

  LView := TBytesView.FromBytes(LData);

  // Test 1: Multiple slices from same view
  LSlice1 := LView.Slice(0, 50);
  LSlice2 := LView.Slice(50, 50);

  Assert(LSlice1.Length = 50, 'Slice1: Length should be 50');
  Assert(LSlice2.Length = 50, 'Slice2: Length should be 50');
  Assert(LSlice1.GetByte(0) = 0, 'Slice1: First byte should be 0');
  Assert(LSlice2.GetByte(0) = 50, 'Slice2: First byte should be 50');

  // Test 2: Nested slices
  LNestedSlice := LSlice1.Slice(10, 20);
  Assert(LNestedSlice.Length = 20, 'Nested slice: Length should be 20');
  Assert(LNestedSlice.GetByte(0) = 10, 'Nested slice: First byte should be 10');
end;

procedure PrintSummary;
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  Phase 2.3.2 Zero-Copy TBytesView Test Suite');
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
    WriteLn('  Phase 2.3.2: TBytesView Zero-Copy Implementation Tests');
    WriteLn('═══════════════════════════════════════════════════════════');

    TestTBytesViewBasics;
    TestSHA256View;
    TestSHA512View;
    TestAES_GCM_EncryptView;
    TestAES_GCM_DecryptView;
    TestBase64EncodeView;
    TestZeroCopySemantics;
    TestSliceOperations;

    PrintSummary;

    WriteLn('✓ Phase 2.3.2 TBytesView implementation complete!');
    WriteLn('✓ All zero-copy methods working correctly!');
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
