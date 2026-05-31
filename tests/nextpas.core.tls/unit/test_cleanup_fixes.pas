program test_cleanup_fixes;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.secure,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.rand;

procedure TestSecureRandom;
var
  Bytes1, Bytes2: TBytes;
  I: Integer;
  AllZero, AllSame: Boolean;
begin
  WriteLn('Testing TSecureRandom...');
  
  // Check if RAND_bytes is available
  WriteLn('RAND_bytes assigned: ', Assigned(RAND_bytes));
  
  // Test 1: Generate random bytes
  Bytes1 := TSecureRandom.Generate(32);
  if Length(Bytes1) <> 32 then
  begin
    WriteLn('FAIL: Expected 32 bytes, got ', Length(Bytes1));
    Exit;
  end;
  
  WriteLn('First bytes: ', Bytes1[0], ', ', Bytes1[1], ', ', Bytes1[2]);
    
  // Test 2: Check for non-zero (it's statistically impossible to be all zero)
  AllZero := True;
  for I := 0 to High(Bytes1) do
    if Bytes1[I] <> 0 then
    begin
      AllZero := False;
      Break;
    end;
    
  if AllZero then
  begin
    WriteLn('FAIL: Random bytes are all zero (highly unlikely)');
    Exit;
  end;
    
  // Test 3: Generate another set and check if different
  Bytes2 := TSecureRandom.Generate(32);
  WriteLn('Second bytes: ', Bytes2[0], ', ', Bytes2[1], ', ', Bytes2[2]);
  
  AllSame := True;
  for I := 0 to High(Bytes1) do
    if Bytes1[I] <> Bytes2[I] then
    begin
      AllSame := False;
      Break;
    end;
  
  if AllSame then
  begin
    WriteLn('FAIL: Two random sequences are identical');
    WriteLn('This could mean RAND_bytes is not being used correctly');
    Exit;
  end;
    
  WriteLn('PASS: TSecureRandom works correctly');
end;

begin
  try
    // Try to load OpenSSL for better random
    try
      LoadOpenSSLCore;
      WriteLn('OpenSSL loaded: ', GetOpenSSLVersionString);
      LoadOpenSSLRAND;
      WriteLn('RAND module loaded: ', TOpenSSLLoader.IsModuleLoaded(osmRAND));
    except
      on E: Exception do
        WriteLn('OpenSSL/RAND load error: ', E.Message);
    end;
    
    TestSecureRandom;
    
    WriteLn('All tests completed.');
  except
    on E: Exception do
      WriteLn('Error: ' + E.Message);
  end;
end.
