program test_hash_utils;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.utils;

procedure TestSHA1;
var
  LData: TBytes;
  LHash: string;
begin
  WriteLn('Testing SHA1...');
  
  // Test with "Hello World"
  LData := TEncoding.UTF8.GetBytes('Hello World');
  LHash := TSSLUtils.CalculateSHA1(LData);
  
  WriteLn('  Input: Hello World');
  WriteLn('  SHA1: ', LHash);
  WriteLn('  Expected: 0A4D55A8D778E5022FAB701977C5D840BBC486D0');
  
  if UpperCase(LHash) = '0A4D55A8D778E5022FAB701977C5D840BBC486D0' then
    WriteLn('  ✓ PASS')
  else if Pos('ERROR', LHash) > 0 then
    WriteLn('  ✗ FAIL: ', LHash)
  else
    WriteLn('  ✗ FAIL: Hash mismatch');
    
  WriteLn;
end;

procedure TestSHA256;
var
  LData: TBytes;
  LHash: string;
begin
  WriteLn('Testing SHA256...');
  
  // Test with "Hello World"
  LData := TEncoding.UTF8.GetBytes('Hello World');
  LHash := TSSLUtils.CalculateSHA256(LData);
  
  WriteLn('  Input: Hello World');
  WriteLn('  SHA256: ', LHash);
  WriteLn('  Expected: A591A6D40BF420404A011733CFB7B190D62C65BF0BCDA32B57B277D9AD9F146E');
  
  if UpperCase(LHash) = 'A591A6D40BF420404A011733CFB7B190D62C65BF0BCDA32B57B277D9AD9F146E' then
    WriteLn('  ✓ PASS')
  else if Pos('ERROR', LHash) > 0 then
    WriteLn('  ✗ FAIL: ', LHash)
  else
    WriteLn('  ✗ FAIL: Hash mismatch');
    
  WriteLn;
end;

procedure TestMD5;
var
  LData: TBytes;
  LHash: string;
begin
  WriteLn('Testing MD5...');
  
  // Test with "Hello World"
  LData := TEncoding.UTF8.GetBytes('Hello World');
  LHash := TSSLUtils.CalculateMD5(LData);
  
  WriteLn('  Input: Hello World');
  WriteLn('  MD5: ', LHash);
  WriteLn('  Expected: B10A8DB164E0754105B7A99BE72E3FE5');
  
  if UpperCase(LHash) = 'B10A8DB164E0754105B7A99BE72E3FE5' then
    WriteLn('  ✓ PASS')
  else if Pos('ERROR', LHash) > 0 then
    WriteLn('  ✗ FAIL: ', LHash)
  else
    WriteLn('  ✗ FAIL: Hash mismatch');
    
  WriteLn;
end;

procedure TestEmptyInput;
var
  LData: TBytes;
  LHash: string;
begin
  WriteLn('Testing empty input...');
  
  SetLength(LData, 0);
  
  // SHA1 of empty string
  LHash := TSSLUtils.CalculateSHA1(LData);
  WriteLn('  SHA1(empty): ', LHash);
  WriteLn('  Expected: DA39A3EE5E6B4B0D3255BFEF95601890AFD80709');
  
  if UpperCase(LHash) = 'DA39A3EE5E6B4B0D3255BFEF95601890AFD80709' then
    WriteLn('  ✓ PASS')
  else
    WriteLn('  ✗ FAIL');
    
  WriteLn;
end;

begin
  WriteLn('==============================================');
  WriteLn('Hash Functions Test Suite');
  WriteLn('==============================================');
  WriteLn;
  
  // Load OpenSSL
  WriteLn('Loading OpenSSL...');
  LoadOpenSSLCore;
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
  begin
    WriteLn('ERROR: Failed to load OpenSSL library');
    WriteLn('Please ensure OpenSSL is installed on your system.');
    Halt(1);
  end;
  WriteLn('OpenSSL loaded: ', GetOpenSSLVersionString);
  
  // Load EVP functions
  WriteLn('Loading EVP functions...');
  if not LoadEVP(GetCryptoLibHandle) then
  begin
    WriteLn('ERROR: Failed to load EVP functions');
    Halt(1);
  end;
  WriteLn('EVP functions loaded');
  WriteLn;
  
  // Run tests
  TestSHA1;
  TestSHA256;
  TestMD5;
  TestEmptyInput;
  
  WriteLn('==============================================');
  WriteLn('Test suite completed');
  WriteLn('==============================================');
end.

