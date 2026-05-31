program test_phase2_simple;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.aead;

var
  TotalTests, PassedTests: Integer;

type
  TTestFunction = function: Boolean;

procedure TestAEADMode(const ModeName: string; TestProc: TTestFunction);
begin
  Write('Testing ', ModeName, '... ');
  Inc(TotalTests);
  try
    if TestProc() then
    begin
      WriteLn('[PASS]');
      Inc(PassedTests);
    end
    else
      WriteLn('[FAIL]');
  except
    on E: Exception do
      WriteLn('[FAIL] ', E.Message);
  end;
end;

function TestGCM: Boolean;
var
  Key, IV, PlainText, AAD: TBytes;
  EncResult: TAEADEncryptResult;
  DecResult: TAEADDecryptResult;
  i: Integer;
begin
  Result := False;
  
  // Setup test data
  SetLength(Key, 32);
  SetLength(IV, 12);
  SetLength(PlainText, 64);
  SetLength(AAD, 16);
  
  for i := 0 to 31 do Key[i] := Byte(i);
  for i := 0 to 11 do IV[i] := Byte(i);
  for i := 0 to 63 do PlainText[i] := Byte($41 + (i mod 26));
  for i := 0 to 15 do AAD[i] := Byte($30 + (i mod 10));
  
  // Encrypt
  EncResult := AES_GCM_Encrypt(Key, IV, PlainText, AAD);
  if not EncResult.Success then
  begin
    WriteLn('  Encrypt failed: ', EncResult.ErrorMessage);
    Exit;
  end;
  
  // Decrypt
  DecResult := AES_GCM_Decrypt(Key, IV, EncResult.CipherText, EncResult.Tag, AAD);
  if not DecResult.Success then
  begin
    WriteLn('  Decrypt failed: ', DecResult.ErrorMessage);
    Exit;
  end;
  
  // Verify
  if Length(DecResult.PlainText) <> Length(PlainText) then
  begin
    WriteLn('  Length mismatch');
    Exit;
  end;
  
  for i := 0 to High(PlainText) do
    if DecResult.PlainText[i] <> PlainText[i] then
    begin
      WriteLn('  Data mismatch at position ', i);
      Exit;
    end;
  
  Result := True;
end;

function TestChaCha20Poly1305: Boolean;
var
  Key, Nonce, PlainText, AAD: TBytes;
  EncResult: TAEADEncryptResult;
  DecResult: TAEADDecryptResult;
  i: Integer;
begin
  Result := False;
  
  // Setup test data
  SetLength(Key, 32);
  SetLength(Nonce, 12);
  SetLength(PlainText, 64);
  SetLength(AAD, 16);
  
  for i := 0 to 31 do Key[i] := Byte(i);
  for i := 0 to 11 do Nonce[i] := Byte(i);
  for i := 0 to 63 do PlainText[i] := Byte($41 + (i mod 26));
  for i := 0 to 15 do AAD[i] := Byte($30 + (i mod 10));
  
  // Encrypt
  EncResult := ChaCha20_Poly1305_Encrypt(Key, Nonce, PlainText, AAD);
  if not EncResult.Success then
  begin
    WriteLn('  Encrypt failed: ', EncResult.ErrorMessage);
    Exit;
  end;
  
  // Decrypt
  DecResult := ChaCha20_Poly1305_Decrypt(Key, Nonce, EncResult.CipherText, EncResult.Tag, AAD);
  if not DecResult.Success then
  begin
    WriteLn('  Decrypt failed: ', DecResult.ErrorMessage);
    Exit;
  end;
  
  // Verify
  if Length(DecResult.PlainText) <> Length(PlainText) then
  begin
    WriteLn('  Length mismatch');
    Exit;
  end;
  
  for i := 0 to High(PlainText) do
    if DecResult.PlainText[i] <> PlainText[i] then
    begin
      WriteLn('  Data mismatch at position ', i);
      Exit;
    end;
  
  Result := True;
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  
  WriteLn;
  WriteLn('========================================');
  WriteLn('  PHASE 2: AEAD VERIFICATION (SIMPLE)');
  WriteLn('========================================');
  WriteLn;
  
  try
    // Load OpenSSL
    if not LoadOpenSSLLibrary then
    begin
      WriteLn('ERROR: Failed to load OpenSSL library');
      ExitCode := 1;
      Exit;
    end;
    
    // Load EVP functions
    if not LoadEVP(GetCryptoLibHandle) then
    begin
      WriteLn('ERROR: Failed to load EVP functions');
      ExitCode := 1;
      Exit;
    end;
    
    WriteLn('OpenSSL loaded successfully');
    WriteLn;
    
    // Test AEAD modes
    TestAEADMode('AES-256-GCM', TTestFunction(@TestGCM));
    TestAEADMode('ChaCha20-Poly1305', TTestFunction(@TestChaCha20Poly1305));
    
    WriteLn;
    WriteLn('========================================');
    WriteLn(Format('Results: %d/%d tests passed (%.1f%%)', 
      [PassedTests, TotalTests, (PassedTests / TotalTests) * 100]));
    WriteLn('========================================');
    WriteLn;
    
    if PassedTests = TotalTests then
    begin
      WriteLn('✅ ALL TESTS PASSED');
      WriteLn;
      WriteLn('Phase 2 Complete: AEAD modes (GCM, ChaCha20-Poly1305)');
      WriteLn('are working correctly with OpenSSL 3.x!');
      ExitCode := 0;
    end
    else
    begin
      WriteLn('⚠️  SOME TESTS FAILED');
      ExitCode := 1;
    end;
    
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.Message);
      ExitCode := 2;
    end;
  end;
  
  WriteLn;
end.
