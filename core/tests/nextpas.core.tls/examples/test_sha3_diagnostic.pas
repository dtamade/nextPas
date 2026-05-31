program test_sha3_diagnostic;

{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.core.tls.openssl.api.core, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.api.sha3;

procedure PrintBytes(const Title: string; const Data: array of Byte);
var
  i: Integer;
begin
  Write(Title, ': ');
  for i := 0 to High(Data) do
    Write(Format('%.2x', [Data[i]]));
  WriteLn;
end;

function DirectHash_InitUpdateFinal: Boolean;
var
  Ctx: SHA3_CTX;
  Data: AnsiString;
  Hash: array[0..31] of Byte;
begin
  Result := False;
  WriteLn('=== Direct Init/Update/Final Test ===');
  
  try
    Data := 'abc';
    FillChar(Hash, SizeOf(Hash), 0);
    FillChar(Ctx, SizeOf(Ctx), 0);
    
    WriteLn('Calling SHA3_256_Init...');
    if SHA3_256_Init(@Ctx) <> 1 then
    begin
      WriteLn('ERROR: SHA3_256_Init failed');
      Exit;
    end;
    WriteLn('SHA3_256_Init: SUCCESS');
    
    WriteLn('Calling SHA3_256_Update with data: "', Data, '"');
    if SHA3_256_Update(@Ctx, @Data[1], Length(Data)) <> 1 then
    begin
      WriteLn('ERROR: SHA3_256_Update failed');
      Exit;
    end;
    WriteLn('SHA3_256_Update: SUCCESS');
    
    WriteLn('Calling SHA3_256_Final...');
    if SHA3_256_Final(@Hash[0], @Ctx) <> 1 then
    begin
      WriteLn('ERROR: SHA3_256_Final failed');
      Exit;
    end;
    WriteLn('SHA3_256_Final: SUCCESS');
    
    PrintBytes('Result', Hash);
    WriteLn('Expected: 3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532');
    
    Result := True;
    
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
      Exit;
    end;
  end;
end;

function DirectSHA3Test: Boolean;
var
  Data: AnsiString;
  Hash: array[0..31] of Byte;
  HashPtr: PByte;
begin
  Result := False;
  WriteLn;
  WriteLn('=== Direct SHA3 Function Test ===');
  
  try
    Data := 'abc';
    FillChar(Hash, SizeOf(Hash), 0);
    
    WriteLn('Calling SHA3_256 directly...');
    WriteLn('Data: "', Data, '"');
    WriteLn('Data length: ', Length(Data));
    WriteLn('Hash buffer address: ', IntToHex(PtrUInt(@Hash[0]), 16));
    
    HashPtr := SHA3_256(@Data[1], Length(Data), @Hash[0]);
    WriteLn('SHA3_256 returned: ', IntToHex(PtrUInt(HashPtr), 16));
    
    if HashPtr = nil then
    begin
      WriteLn('ERROR: SHA3_256 returned nil');
      Exit;
    end;
    
    PrintBytes('Result', Hash);
    WriteLn('Expected: 3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532');
    
    Result := True;
    
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
      Exit;
    end;
  end;
end;

function CheckFunctionPointers: Boolean;
begin
  Result := False;
  WriteLn;
  WriteLn('=== Function Pointer Check ===');
  
  WriteLn('SHA3_224_Init = ', IntToHex(PtrUInt(@SHA3_224_Init), 16), ' -> ', IntToHex(PtrUInt(SHA3_224_Init), 16));
  WriteLn('SHA3_256_Init = ', IntToHex(PtrUInt(@SHA3_256_Init), 16), ' -> ', IntToHex(PtrUInt(SHA3_256_Init), 16));
  WriteLn('SHA3_384_Init = ', IntToHex(PtrUInt(@SHA3_384_Init), 16), ' -> ', IntToHex(PtrUInt(SHA3_384_Init), 16));
  WriteLn('SHA3_512_Init = ', IntToHex(PtrUInt(@SHA3_512_Init), 16), ' -> ', IntToHex(PtrUInt(SHA3_512_Init), 16));
  WriteLn('SHA3_224 = ', IntToHex(PtrUInt(@SHA3_224), 16), ' -> ', IntToHex(PtrUInt(SHA3_224), 16));
  WriteLn('SHA3_256 = ', IntToHex(PtrUInt(@SHA3_256), 16), ' -> ', IntToHex(PtrUInt(SHA3_256), 16));
  WriteLn('SHA3_384 = ', IntToHex(PtrUInt(@SHA3_384), 16), ' -> ', IntToHex(PtrUInt(SHA3_384), 16));
  WriteLn('SHA3_512 = ', IntToHex(PtrUInt(@SHA3_512), 16), ' -> ', IntToHex(PtrUInt(SHA3_512), 16));
  
  Result := True;
end;

function TestOpenSSLVersion: Boolean;
var
  VersionNum: Cardinal;
  VersionStr: PAnsiChar;
begin
  Result := False;
  WriteLn;
  WriteLn('=== OpenSSL Version Info ===');
  
  try
    VersionNum := OpenSSL_version_num();
    WriteLn('OpenSSL_version_num: ', IntToHex(VersionNum, 8));
    WriteLn('  Major: ', (VersionNum shr 28) and $F);
    WriteLn('  Minor: ', (VersionNum shr 20) and $FF);
    WriteLn('  Patch: ', (VersionNum shr 4) and $FFFF);
    
    VersionStr := OpenSSL_version(0); // OPENSSL_VERSION
    if VersionStr <> nil then
      WriteLn('OpenSSL_version: ', VersionStr)
    else
      WriteLn('OpenSSL_version: (null)');
    
    Result := True;
    
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ', E.ClassName, ': ', E.Message);
      Exit;
    end;
  end;
end;

var
  TestCount, PassCount: Integer;
begin
  TestCount := 0;
  PassCount := 0;
  
  WriteLn('SHA3 Diagnostic Tool');
  WriteLn('====================');
  WriteLn;
  
  try
    // 加载OpenSSL
    if not LoadOpenSSLCore then
    begin
      WriteLn('FATAL: Failed to load OpenSSL core');
      Halt(1);
    end;
    WriteLn('OpenSSL core loaded successfully');
    
    if not LoadSHA3Functions(GetCryptoLibHandle) then
    begin
      WriteLn('FATAL: Failed to load SHA3 functions');
      Halt(1);
    end;
    WriteLn('SHA3 functions loaded successfully');
    WriteLn;
    
    // 测试1: 检查OpenSSL版本
    Inc(TestCount);
    if TestOpenSSLVersion then
      Inc(PassCount);
    
    // 测试2: 检查函数指针
    Inc(TestCount);
    if CheckFunctionPointers then
      Inc(PassCount);
    
    // 测试3: Init/Update/Final测试
    Inc(TestCount);
    if DirectHash_InitUpdateFinal then
      Inc(PassCount);
    
    // 测试4: 直接SHA3函数测试
    Inc(TestCount);
    if DirectSHA3Test then
      Inc(PassCount);
    
    WriteLn;
    WriteLn('=== Summary ===');
    WriteLn('Tests run: ', TestCount);
    WriteLn('Tests passed: ', PassCount);
    WriteLn('Tests failed: ', TestCount - PassCount);
    
    if PassCount = TestCount then
    begin
      WriteLn('Result: ALL TESTS PASSED');
      Halt(0);
    end
    else
    begin
      WriteLn('Result: SOME TESTS FAILED');
      Halt(1);
    end;
    
  except
    on E: Exception do
    begin
      WriteLn('FATAL EXCEPTION: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
