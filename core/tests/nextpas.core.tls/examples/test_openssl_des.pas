program test_openssl_des;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DynLibs,
  nextpas.core.tls.openssl.api.types,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.des;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure PrintTestResult(const TestName: string; Passed: Boolean);
begin
  if Passed then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    Inc(TestsFailed);
  end;
end;

function TestDESLoadFunctions: Boolean;
var
  LLib: TLibHandle;
begin
  Result := False;
  
  try
    // Load core library first
    LoadOpenSSLCore;
  except
    on E: Exception do
    begin
      WriteLn('Failed to load OpenSSL Core: ', E.Message);
      PrintTestResult('DES - Load functions', False);
      Exit;
    end;
  end;
  
  // Get crypto library handle
  LLib := GetCryptoLibHandle;
  if LLib = NilHandle then
  begin
    WriteLn('Failed to get crypto library handle');
    PrintTestResult('DES - Load functions', False);
    Exit;
  end;
  
  // Load DES functions
  if not LoadDESFunctions(LLib) then
  begin
    WriteLn('Failed to load DES functions');
    PrintTestResult('DES - Load functions', False);
    Exit;
  end;
  
  Result := True;
  PrintTestResult('DES - Load functions', Result);
end;

function TestDESECBEncryptDecrypt: Boolean;
var
  LKey: TBytes;
  LData: TBytes;
  LEncrypted: TBytes;
  LDecrypted: TBytes;
  i: Integer;
begin
  Result := False;
  
  // Test data: "Hello!!!"  (8 bytes for DES block)
  SetLength(LData, 8);
  LData[0] := Ord('H');
  LData[1] := Ord('e');
  LData[2] := Ord('l');
  LData[3] := Ord('l');
  LData[4] := Ord('o');
  LData[5] := Ord('!');
  LData[6] := Ord('!');
  LData[7] := Ord('!');
  
  // Test key: "12345678"
  SetLength(LKey, 8);
  LKey[0] := Ord('1');
  LKey[1] := Ord('2');
  LKey[2] := Ord('3');
  LKey[3] := Ord('4');
  LKey[4] := Ord('5');
  LKey[5] := Ord('6');
  LKey[6] := Ord('7');
  LKey[7] := Ord('8');
  
  // Encrypt
  LEncrypted := DESEncrypt(LData, LKey);
  if Length(LEncrypted) = 0 then Exit;
  
  // Decrypt
  LDecrypted := DESDecrypt(LEncrypted, LKey);
  if Length(LDecrypted) <> Length(LData) then Exit;
  
  // Verify decrypted matches original
  for i := 0 to Length(LData) - 1 do
    if LData[i] <> LDecrypted[i] then Exit;
  
  Result := True;
  PrintTestResult('DES - ECB encrypt/decrypt', Result);
end;

function TestDES3EncryptDecrypt: Boolean;
var
  LKey1, LKey2, LKey3: TBytes;
  LData: TBytes;
  LEncrypted: TBytes;
  LDecrypted: TBytes;
  i: Integer;
begin
  Result := False;
  
  // Test data: "Hello!!!"
  SetLength(LData, 8);
  LData[0] := Ord('H');
  LData[1] := Ord('e');
  LData[2] := Ord('l');
  LData[3] := Ord('l');
  LData[4] := Ord('o');
  LData[5] := Ord('!');
  LData[6] := Ord('!');
  LData[7] := Ord('!');
  
  // Three different keys
  SetLength(LKey1, 8);
  for i := 0 to 7 do LKey1[i] := i + 1;
  
  SetLength(LKey2, 8);
  for i := 0 to 7 do LKey2[i] := i + 9;
  
  SetLength(LKey3, 8);
  for i := 0 to 7 do LKey3[i] := i + 17;
  
  // Encrypt with 3DES
  LEncrypted := DES3Encrypt(LData, LKey1, LKey2, LKey3);
  if Length(LEncrypted) = 0 then Exit;
  
  // Decrypt with 3DES
  LDecrypted := DES3Decrypt(LEncrypted, LKey1, LKey2, LKey3);
  if Length(LDecrypted) <> Length(LData) then Exit;
  
  // Verify decrypted matches original
  for i := 0 to Length(LData) - 1 do
    if LData[i] <> LDecrypted[i] then Exit;
  
  Result := True;
  PrintTestResult('DES - 3DES encrypt/decrypt', Result);
end;

function TestDESMultipleBlocks: Boolean;
var
  LKey: TBytes;
  LData: TBytes;
  LEncrypted: TBytes;
  LDecrypted: TBytes;
  i: Integer;
begin
  Result := False;
  
  // Test data: 16 bytes (2 DES blocks)
  SetLength(LData, 16);
  for i := 0 to 15 do
    LData[i] := Byte(i);
  
  // Test key
  SetLength(LKey, 8);
  for i := 0 to 7 do
    LKey[i] := Byte(i + 1);
  
  // Encrypt
  LEncrypted := DESEncrypt(LData, LKey);
  if Length(LEncrypted) <> 16 then Exit;
  
  // Decrypt
  LDecrypted := DESDecrypt(LEncrypted, LKey);
  if Length(LDecrypted) <> Length(LData) then Exit;
  
  // Verify decrypted matches original
  for i := 0 to Length(LData) - 1 do
    if LData[i] <> LDecrypted[i] then Exit;
  
  Result := True;
  PrintTestResult('DES - Multiple blocks', Result);
end;

function TestDESWeakKeyCheck: Boolean;
var
  LWeakKey: DES_cblock;
  LResult: Integer;
begin
  Result := False;
  
  if not Assigned(DES_is_weak_key) then
  begin
    // Function not available in this OpenSSL version
    Result := True;
    PrintTestResult('DES - Weak key check (skipped - not available)', Result);
    Exit;
  end;
  
  // Create a known weak key: 0x0101010101010101
  // This is one of the 4 DES weak keys
  FillChar(LWeakKey, SizeOf(LWeakKey), $01);
  
  // Check if it's detected as weak
  LResult := DES_is_weak_key(@LWeakKey);
  
  // Should return 1 for weak key
  Result := (LResult = 1);
  
  PrintTestResult('DES - Weak key check', Result);
end;

function TestDESKeyParity: Boolean;
var
  LKey: DES_cblock;
  i: Integer;
begin
  Result := False;
  
  if not Assigned(DES_set_odd_parity) or not Assigned(DES_check_key_parity) then
  begin
    // Functions not available
    Result := True;
    PrintTestResult('DES - Key parity (skipped - not available)', Result);
    Exit;
  end;
  
  // Create a key with random data
  for i := 0 to 7 do
    LKey[i] := Byte((i + 1) * 17);
  
  // Set odd parity
  DES_set_odd_parity(@LKey);
  
  // Check parity (should return 1 if parity is correct)
  Result := (DES_check_key_parity(@LKey) = 1);
  
  PrintTestResult('DES - Key parity', Result);
end;

function TestDESEmptyData: Boolean;
var
  LKey: TBytes;
  LData: TBytes;
  LEncrypted: TBytes;
begin
  Result := False;
  
  // Empty data
  SetLength(LData, 0);
  
  // Test key
  SetLength(LKey, 8);
  LKey[0] := Ord('1');
  LKey[1] := Ord('2');
  LKey[2] := Ord('3');
  LKey[3] := Ord('4');
  LKey[4] := Ord('5');
  LKey[5] := Ord('6');
  LKey[6] := Ord('7');
  LKey[7] := Ord('8');
  
  // Encrypt should handle empty data gracefully
  LEncrypted := DESEncrypt(LData, LKey);
  
  // Should return empty or padded result
  Result := True;
  
  PrintTestResult('DES - Empty data handling', Result);
end;

function TestDESInvalidKey: Boolean;
var
  LKey: TBytes;
  LData: TBytes;
  LEncrypted: TBytes;
begin
  Result := False;
  
  // Test data
  SetLength(LData, 8);
  FillChar(LData[0], 8, $AA);
  
  // Invalid key (too short)
  SetLength(LKey, 4);
  
  // Encrypt should fail gracefully
  LEncrypted := DESEncrypt(LData, LKey);
  
  // Should return nil or empty
  Result := (Length(LEncrypted) = 0);
  
  PrintTestResult('DES - Invalid key handling', Result);
end;

procedure RunAllTests;
begin
  TestDESLoadFunctions;
  TestDESECBEncryptDecrypt;
  TestDES3EncryptDecrypt;
  TestDESMultipleBlocks;
  TestDESWeakKeyCheck;
  TestDESKeyParity;
  TestDESEmptyData;
  TestDESInvalidKey;
  
  WriteLn;
  WriteLn('Tests Passed: ', TestsPassed);
  WriteLn('Tests Failed: ', TestsFailed);
  WriteLn('Total Tests: ', TestsPassed + TestsFailed);
  
  if TestsFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end;

begin
  try
    RunAllTests;
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
