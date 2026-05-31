program test_openssl_ec;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DynLibs,
  nextpas.core.tls.openssl.api.types,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.ec;

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

function TestECLoadFunctions: Boolean;
var
  LLib: TLibHandle;
begin
  Result := False;
  
  try
    LoadOpenSSLCore;
  except
    on E: Exception do
    begin
      WriteLn('Failed to load OpenSSL Core: ', E.Message);
      PrintTestResult('EC - Load functions', False);
      Exit;
    end;
  end;
  
  LLib := GetCryptoLibHandle;
  if LLib = NilHandle then
  begin
    WriteLn('Failed to get crypto library handle');
    PrintTestResult('EC - Load functions', False);
    Exit;
  end;
  
  if not LoadECFunctions(LLib) then
  begin
    WriteLn('Failed to load EC functions');
    PrintTestResult('EC - Load functions', False);
    Exit;
  end;
  
  Result := True;
  PrintTestResult('EC - Load functions', Result);
end;

function TestECGroupCreation: Boolean;
var
  LGroup: PEC_GROUP;
begin
  Result := False;
  
  LGroup := EC_GROUP_new_by_curve_name(NID_X9_62_prime256v1);
  if not Assigned(LGroup) then Exit;
  
  EC_GROUP_free(LGroup);
  Result := True;
  PrintTestResult('EC - Group creation (secp256r1)', Result);
end;

function TestECKeyGeneration: Boolean;
var
  LKey: PEC_KEY;
  LGroup: PEC_GROUP;
begin
  Result := False;
  
  if not LoadOpenSSLBN then Exit;
  
  LKey := nil;
  LGroup := nil;
  
  try
    LGroup := EC_GROUP_new_by_curve_name(NID_X9_62_prime256v1);
    if not Assigned(LGroup) then Exit;
    
    LKey := EC_KEY_new();
    if not Assigned(LKey) then Exit;
    
    if EC_KEY_set_group(LKey, LGroup) <> 1 then Exit;
    if EC_KEY_generate_key(LKey) <> 1 then Exit;
    
    Result := True;
  finally
    if Assigned(LKey) then EC_KEY_free(LKey);
    if Assigned(LGroup) then EC_GROUP_free(LGroup);
  end;
  
  PrintTestResult('EC - Key generation', Result);
end;

function TestECPublicKeyRetrieval: Boolean;
var
  LKey: PEC_KEY;
  LGroup: PEC_GROUP;
  LPubKey: PEC_POINT;
begin
  Result := False;
  
  LKey := nil;
  LGroup := nil;
  
  try
    LGroup := EC_GROUP_new_by_curve_name(NID_X9_62_prime256v1);
    if not Assigned(LGroup) then Exit;
    
    LKey := EC_KEY_new();
    if not Assigned(LKey) then Exit;
    
    if EC_KEY_set_group(LKey, LGroup) <> 1 then Exit;
    if EC_KEY_generate_key(LKey) <> 1 then Exit;
    
    LPubKey := EC_KEY_get0_public_key(LKey);
    if not Assigned(LPubKey) then Exit;
    
    Result := True;
  finally
    if Assigned(LKey) then EC_KEY_free(LKey);
    if Assigned(LGroup) then EC_GROUP_free(LGroup);
  end;
  
  PrintTestResult('EC - Public key retrieval', Result);
end;

function TestECMultipleCurves: Boolean;
var
  LKey: PEC_KEY;
  LGroup: PEC_GROUP;
  LCurves: array[0..3] of Integer;
  i: Integer;
  LSuccess: Boolean;
begin
  Result := True;
  
  LCurves[0] := NID_X9_62_prime256v1;  // secp256r1 / P-256
  LCurves[1] := NID_secp384r1;          // secp384r1 / P-384
  LCurves[2] := NID_secp521r1;          // secp521r1 / P-521
  LCurves[3] := NID_secp256k1;          // secp256k1 (Bitcoin)
  
  for i := 0 to High(LCurves) do
  begin
    LKey := nil;
    LGroup := nil;
    LSuccess := False;
    
    try
      LGroup := EC_GROUP_new_by_curve_name(LCurves[i]);
      if not Assigned(LGroup) then Continue;
      
      LKey := EC_KEY_new();
      if not Assigned(LKey) then Continue;
      
      if EC_KEY_set_group(LKey, LGroup) <> 1 then Continue;
      if EC_KEY_generate_key(LKey) <> 1 then Continue;
      
      LSuccess := True;
    finally
      if Assigned(LKey) then EC_KEY_free(LKey);
      if Assigned(LGroup) then EC_GROUP_free(LGroup);
    end;
    
    if not LSuccess then
    begin
      Result := False;
      Break;
    end;
  end;
  
  PrintTestResult('EC - Multiple curves (P-256, P-384, P-521, secp256k1)', Result);
end;

function TestECKeyCheck: Boolean;
var
  LKey: PEC_KEY;
  LGroup: PEC_GROUP;
begin
  Result := False;
  
  LKey := nil;
  LGroup := nil;
  
  try
    LGroup := EC_GROUP_new_by_curve_name(NID_X9_62_prime256v1);
    if not Assigned(LGroup) then Exit;
    
    LKey := EC_KEY_new();
    if not Assigned(LKey) then Exit;
    
    if EC_KEY_set_group(LKey, LGroup) <> 1 then Exit;
    if EC_KEY_generate_key(LKey) <> 1 then Exit;
    
    // Check if the key is valid
    if Assigned(EC_KEY_check_key) then
    begin
      if EC_KEY_check_key(LKey) <> 1 then Exit;
    end;
    
    Result := True;
  finally
    if Assigned(LKey) then EC_KEY_free(LKey);
    if Assigned(LGroup) then EC_GROUP_free(LGroup);
  end;
  
  PrintTestResult('EC - Key validation', Result);
end;

function TestECPointOperations: Boolean;
var
  LGroup: PEC_GROUP;
  LPoint1, LPoint2: PEC_POINT;
  LCtx: PBN_CTX;
begin
  Result := False;
  
  if not LoadOpenSSLBN then Exit;
  
  LGroup := nil;
  LPoint1 := nil;
  LPoint2 := nil;
  LCtx := nil;
  
  try
    LGroup := EC_GROUP_new_by_curve_name(NID_X9_62_prime256v1);
    if not Assigned(LGroup) then Exit;
    
    LCtx := BN_CTX_new();
    if not Assigned(LCtx) then Exit;
    
    // Create points
    LPoint1 := EC_POINT_new(LGroup);
    if not Assigned(LPoint1) then Exit;
    
    LPoint2 := EC_POINT_new(LGroup);
    if not Assigned(LPoint2) then Exit;
    
    // Copy point
    if EC_POINT_copy(LPoint2, LPoint1) <> 1 then Exit;
    
    Result := True;
  finally
    if Assigned(LPoint1) then EC_POINT_free(LPoint1);
    if Assigned(LPoint2) then EC_POINT_free(LPoint2);
    if Assigned(LCtx) then BN_CTX_free(LCtx);
    if Assigned(LGroup) then EC_GROUP_free(LGroup);
  end;
  
  PrintTestResult('EC - Point operations', Result);
end;

function TestECInvalidInputs: Boolean;
var
  LKey: PEC_KEY;
begin
  Result := True;
  
  // Test with nil group (should fail gracefully)
  LKey := EC_KEY_new();
  if Assigned(LKey) then
  begin
    // Should fail but not crash
    if EC_KEY_generate_key(LKey) = 1 then
      Result := False;  // Should not succeed without a group
    EC_KEY_free(LKey);
  end;
  
  PrintTestResult('EC - Invalid inputs handling', Result);
end;

procedure RunAllTests;
begin
  TestECLoadFunctions;
  TestECGroupCreation;
  TestECKeyGeneration;
  TestECPublicKeyRetrieval;
  TestECMultipleCurves;
  TestECKeyCheck;
  TestECPointOperations;
  TestECInvalidInputs;
  
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
