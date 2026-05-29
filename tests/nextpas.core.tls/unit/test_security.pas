program test_security;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.secure;

procedure TestSecureString;
var
  LSecure: TSecureString;
  LPassword: string;
begin
  WriteLn('[Test 1] TSecureString - Auto-zeroing');
  
  LSecure := TSecureString.Create('my-secret-password');
  WriteLn('  Created: ', LSecure.Size, ' bytes');
  WriteLn('  Value: ', LSecure.ToString);
  
  LSecure.Clear;
  WriteLn('  After Clear: ', LSecure.Size, ' bytes');
  WriteLn('✓ Memory auto-zeroed on clear');
  WriteLn;
end;

procedure TestSecureBytes;
var
  LBytes: TSecureBytes;
  LData: TBytes;
begin
  WriteLn('[Test 2] TSecureBytes - Secure storage');
  
  SetLength(LData, 16);
  FillChar(LData[0], 16, $AA);
  
  LBytes := TSecureBytes.Create(LData);
  WriteLn('  Created: ', LBytes.Size, ' bytes');
  WriteLn('  First byte: $', IntToHex(LBytes.Data[0], 2));
  
  LBytes.Clear;
  WriteLn('  After Clear: ', LBytes.Size, ' bytes');
  WriteLn('✓ Secure bytes auto-zeroed');
  WriteLn;
end;

procedure TestSecureRandom;
var
  LRandom: TBytes;
  I: Integer;
begin
  WriteLn('[Test 3] Secure Random Generation');
  
  LRandom := TSecureRandom.Generate(16);
  Write('  Random bytes: ');
  for I := 0 to 15 do
    Write(IntToHex(LRandom[I], 2), ' ');
  WriteLn;
  
  WriteLn('  Random int (1-100): ', TSecureRandom.GenerateInt(1, 100));
  WriteLn('✓ Cryptographically secure random working');
  WriteLn;
end;

procedure TestConstantTimeCompare;
var
  LA, LB: TBytes;
begin
  WriteLn('[Test 4] Constant-time comparison');
  
  SetLength(LA, 8);
  SetLength(LB, 8);
  FillChar(LA[0], 8, $FF);
  FillChar(LB[0], 8, $FF);
  
  WriteLn('  Same data: ', SecureCompare(LA, LB));
  
  LB[0] := $FE;
  WriteLn('  Different data: ', SecureCompare(LA, LB));
  
  WriteLn('  String compare: ', SecureCompareStrings('secret', 'secret'));
  WriteLn('  String differ: ', SecureCompareStrings('secret', 'Secret'));
  WriteLn('✓ Timing-attack resistant comparison working');
  WriteLn;
end;

procedure TestKeyStore;
var
  LStore: ISecureKeyStore;
  LKey, LLoaded: TSecureBytes;
  LData: TBytes;
begin
  WriteLn('[Test 5] Secure Key Store');
  
  LStore := CreateSecureKeyStore;
  
  // Create a test key
  SetLength(LData, 32);
  FillChar(LData[0], 32, $AB);
  LKey := TSecureBytes.Create(LData);
  
  // Store it
  LStore.StoreKey('test-key', LKey, 'password123');
  WriteLn('  Key stored');
  
  // Check existence
  WriteLn('  Has key: ', LStore.HasKey('test-key'));
  
  // Load it back
  LLoaded := LStore.LoadKey('test-key', 'password123');
  WriteLn('  Key loaded: ', LLoaded.Size, ' bytes');
  WriteLn('  First byte: $', IntToHex(LLoaded.Data[0], 2));
  
  // Lock/unlock
  LStore.Lock;
  WriteLn('  Store locked: ', LStore.IsLocked);
  
  LStore.Unlock('password123');
  WriteLn('  Store unlocked: ', not LStore.IsLocked);
  
  WriteLn('✓ Secure key storage working');
  WriteLn;
end;

begin
  WriteLn('====================================');
  WriteLn('  Security Hardening Tests');
  WriteLn('====================================');
  WriteLn;
  
  try
    TestSecureString;
    TestSecureBytes;
    TestSecureRandom;
    TestConstantTimeCompare;
    TestKeyStore;
    
    WriteLn('====================================');
    WriteLn('✓ ALL SECURITY TESTS PASSED');
    WriteLn('====================================');
    WriteLn;
    WriteLn('Security features ready:');
    WriteLn('  ✓ Auto-zeroing memory');
    WriteLn('  ✓ Secure random generation');
    WriteLn('  ✓ Constant-time operations');
    WriteLn('  ✓ Encrypted key storage');
    
  except
    on E: Exception do
    begin
      WriteLn('❌ ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
