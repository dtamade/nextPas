program test_crypto_utils_ex;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.crypto.utils;

var
  Key, IV, Data, AAD: TBytes;
  EncResult, DecResult: TEncryptionResult;
  
procedure Fail(const Msg: string);
begin
  WriteLn('FAIL: ', Msg);
  Halt(1);
end;

procedure Pass(const Msg: string);
begin
  WriteLn('PASS: ', Msg);
end;

begin
  WriteLn('Testing TCryptoUtils Ex methods...');
  
  // Initialize data
  Key := TCryptoUtils.GenerateKey(256);
  IV := TCryptoUtils.GenerateIV(12);
  Data := TEncoding.UTF8.GetBytes('Hello, World!');
  AAD := TEncoding.UTF8.GetBytes('header');
  
  // Test EncryptEx
  EncResult := TCryptoUtils.AES_GCM_EncryptEx(Data, Key, IV, AAD);
  if not EncResult.Success then
    Fail('EncryptEx failed: ' + EncResult.ErrorMessage);
    
  if Length(EncResult.Data) = 0 then
    Fail('EncryptEx returned empty data');
    
  Pass('AES_GCM_EncryptEx success');
  
  // Test DecryptEx
  DecResult := TCryptoUtils.AES_GCM_DecryptEx(EncResult.Data, Key, IV, AAD);
  if not DecResult.Success then
    Fail('DecryptEx failed: ' + DecResult.ErrorMessage);
    
  if not TCryptoUtils.SecureCompare(Data, DecResult.Data) then
    Fail('Decrypted data does not match original');
    
  Pass('AES_GCM_DecryptEx success');
  
  // Test Failure Case (Wrong Key)
  Key[0] := Key[0] xor $FF; // Corrupt key
  DecResult := TCryptoUtils.AES_GCM_DecryptEx(EncResult.Data, Key, IV, AAD);
  if DecResult.Success then
    Fail('DecryptEx should have failed with wrong key');
    
  if DecResult.ErrorMessage = '' then
    Fail('DecryptEx should have returned error message');
    
  Pass('AES_GCM_DecryptEx failure handling success');
  
  WriteLn('All tests passed!');
end.
