program test_cmac_evp;

{$mode Delphi}{$H+}

uses
  SysUtils, Dynlibs,
  nextpas.core.tls.openssl.api.cmac.evp;

function BytesToHex(const Bytes: TBytes): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(Bytes) do
    Result := Result + LowerCase(IntToHex(Bytes[i], 2));
end;

function HexToBytes(const Hex: string): TBytes;
var
  i, len: Integer;
begin
  len := Length(Hex) div 2;
  SetLength(Result, len);
  for i := 0 to len - 1 do
    Result[i] := StrToInt('$' + Copy(Hex, i * 2 + 1, 2));
end;

procedure TestCMAC_AES128;
var
  key, data, mac: TBytes;
  expected: string;
begin
  WriteLn('=== Testing CMAC-AES128 with EVP API ===');
  
  // NIST test vector
  key := HexToBytes('2b7e151628aed2a6abf7158809cf4f3c');
  data := HexToBytes('6bc1bee22e409f96e93d7e117393172a');
  expected := '070a16b46b4d4144f79bdd9dd04a287c';
  
  mac := CMAC_AES128_EVP(key, data);
  
  WriteLn('Key:      2b7e151628aed2a6abf7158809cf4f3c');
  WriteLn('Data:     6bc1bee22e409f96e93d7e117393172a');
  WriteLn('Expected: ', expected);
  WriteLn('Got:      ', BytesToHex(mac));
  
  if BytesToHex(mac) = expected then
    WriteLn('PASS: CMAC-AES128 test PASSED')
  else
    WriteLn('FAIL: CMAC-AES128 test FAILED');
  
  WriteLn;
end;

procedure TestCMAC_AES256;
var
  key, data, mac: TBytes;
  expected: string;
begin
  WriteLn('=== Testing CMAC-AES256 with EVP API ===');
  
  // NIST test vector
  key := HexToBytes('603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4');
  data := HexToBytes('6bc1bee22e409f96e93d7e117393172a');
  expected := '28a7023f452e8f82bd4bf28d8c37c35c';
  
  mac := CMAC_AES256_EVP(key, data);
  
  WriteLn('Key:      603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4');
  WriteLn('Data:     6bc1bee22e409f96e93d7e117393172a');
  WriteLn('Expected: ', expected);
  WriteLn('Got:      ', BytesToHex(mac));
  
  if BytesToHex(mac) = expected then
    WriteLn('PASS: CMAC-AES256 test PASSED')
  else
    WriteLn('FAIL: CMAC-AES256 test FAILED');
  
  WriteLn;
end;

procedure TestCMAC_Empty;
var
  key, data, mac: TBytes;
  expected: string;
begin
  WriteLn('=== Testing CMAC-AES128 with empty data ===');
  
  // NIST test vector for empty data
  key := HexToBytes('2b7e151628aed2a6abf7158809cf4f3c');
  SetLength(data, 0);
  expected := 'bb1d6929e95937287fa37d129b756746';
  
  mac := CMAC_AES128_EVP(key, data);
  
  WriteLn('Key:      2b7e151628aed2a6abf7158809cf4f3c');
  WriteLn('Data:     (empty)');
  WriteLn('Expected: ', expected);
  WriteLn('Got:      ', BytesToHex(mac));
  
  if BytesToHex(mac) = expected then
    WriteLn('PASS: Empty data test PASSED')
  else
    WriteLn('FAIL: Empty data test FAILED');
  
  WriteLn;
end;

procedure TestCMAC_Incremental;
var
  ctx: TCMACEVPContext;
  key, data1, data2, mac: TBytes;
  maclen: NativeUInt;
  expected: string;
begin
  WriteLn('=== Testing CMAC incremental update ===');
  
  key := HexToBytes('2b7e151628aed2a6abf7158809cf4f3c');
  data1 := HexToBytes('6bc1bee22e409f96');
  data2 := HexToBytes('e93d7e117393172a');
  expected := '070a16b46b4d4144f79bdd9dd04a287c';
  
  ctx := TCMACEVPContext.Create('AES-128-CBC');
  try
    if not ctx.Init(key) then
    begin
      WriteLn('FAIL: Failed to initialize context');
      Exit;
    end;
    
    if not ctx.Update(data1) then
    begin
      WriteLn('FAIL: First update failed');
      Exit;
    end;
    
    if not ctx.Update(data2) then
    begin
      WriteLn('FAIL: Second update failed');
      Exit;
    end;
    
    SetLength(mac, 16);
    maclen := 16;
    if not ctx.Final(@mac[0], maclen) then
    begin
      WriteLn('FAIL: Final failed');
      Exit;
    end;
    SetLength(mac, maclen);
    
    WriteLn('Key:      2b7e151628aed2a6abf7158809cf4f3c');
    WriteLn('Data:     6bc1bee22e409f96 + e93d7e117393172a');
    WriteLn('Expected: ', expected);
    WriteLn('Got:      ', BytesToHex(mac));
    
    if BytesToHex(mac) = expected then
      WriteLn('PASS: Incremental update test PASSED')
    else
      WriteLn('FAIL: Incremental update test FAILED');
  finally
    ctx.Free;
  end;
  
  WriteLn;
end;

begin
  WriteLn('CMAC EVP API Test Suite');
  WriteLn('=======================');
  WriteLn;
  
  // Check if CMAC is available
  if not IsEVPCMACAvailable then
  begin
    WriteLn('ERROR: CMAC is not available via EVP API');
    WriteLn('This may indicate an OpenSSL version issue or missing CMAC support.');
    Halt(1);
  end;
  
  WriteLn('PASS: CMAC is available via EVP API');
  WriteLn;
  
  // Run tests
  TestCMAC_AES128;
  TestCMAC_AES256;
  TestCMAC_Empty;
  TestCMAC_Incremental;
  
  WriteLn('=== Test Summary ===');
  WriteLn('All tests completed. Check results above.');
  WriteLn;
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
