{
  test_new_api - 测试 fafafa.ssl v2.0 新增 API
  
  测试内容：
  1. Result 类型（TSSLDataResult, TSSLOperationResult）
  2. Try 方法（TrySHA256, TrySHA512, TrySecureRandom）
  3. Connection Builder 基本验证
}

program test_new_api;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.crypto.utils,
  nextpas.core.tls.factory,
  nextpas.core.tls.connection.builder,
  fafafa.ssl;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    WriteLn('✅ PASS: ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('❌ FAIL: ', TestName);
    Inc(TestsFailed);
  end;
end;

procedure TestResultTypes;
var
  DataResult: TSSLDataResult;
  OpResult: TSSLOperationResult;
  Data: TBytes;
begin
  WriteLn;
  WriteLn('=== Testing Result Types ===');
  
  // Test TSSLOperationResult.Ok
  OpResult := TSSLOperationResult.Ok;
  Check(OpResult.Success, 'TSSLOperationResult.Ok returns Success=True');
  
  // Test TSSLOperationResult.Err
  OpResult := TSSLOperationResult.Err(sslErrInvalidParam, 'Test error');
  Check(not OpResult.Success, 'TSSLOperationResult.Err returns Success=False');
  Check(OpResult.ErrorCode = sslErrInvalidParam, 'TSSLOperationResult.Err sets correct ErrorCode');
  Check(OpResult.ErrorMessage = 'Test error', 'TSSLOperationResult.Err sets correct ErrorMessage');
  
  // Test TSSLDataResult.Ok
  SetLength(Data, 10);
  FillChar(Data[0], 10, $AA);
  DataResult := TSSLDataResult.Ok(Data);
  Check(DataResult.IsOk, 'TSSLDataResult.Ok returns IsOk=True');
  Check(not DataResult.IsErr, 'TSSLDataResult.Ok returns IsErr=False');
  Check(Length(DataResult.Unwrap) = 10, 'TSSLDataResult.Ok stores correct data');
  
  // Test TSSLDataResult.Err
  DataResult := TSSLDataResult.Err(sslErrGeneral, 'Data error');
  Check(DataResult.IsErr, 'TSSLDataResult.Err returns IsErr=True');
  Check(not DataResult.IsOk, 'TSSLDataResult.Err returns IsOk=False');
  
  // Test UnwrapOr
  Data := DataResult.UnwrapOr(nil);
  Check(Data = nil, 'TSSLDataResult.UnwrapOr returns default on error');
end;

procedure TestTryMethods;
var
  Data, Hash, Random: TBytes;
  OK: Boolean;
begin
  WriteLn;
  WriteLn('=== Testing Try Methods ===');
  
  Data := TEncoding.UTF8.GetBytes('Test data');
  
  // Test TrySHA256 with TBytes
  OK := TCryptoUtils.TrySHA256(Data, Hash);
  Check(OK, 'TrySHA256(TBytes) returns True');
  Check(Length(Hash) = 32, 'TrySHA256 produces 32-byte hash');
  
  // Test TrySHA256 with string
  OK := TCryptoUtils.TrySHA256('Test string', Hash);
  Check(OK, 'TrySHA256(string) returns True');
  Check(Length(Hash) = 32, 'TrySHA256(string) produces 32-byte hash');
  
  // Test TrySHA512 with TBytes
  OK := TCryptoUtils.TrySHA512(Data, Hash);
  Check(OK, 'TrySHA512(TBytes) returns True');
  Check(Length(Hash) = 64, 'TrySHA512 produces 64-byte hash');
  
  // Test TrySHA512 with string
  OK := TCryptoUtils.TrySHA512('Test string', Hash);
  Check(OK, 'TrySHA512(string) returns True');
  Check(Length(Hash) = 64, 'TrySHA512(string) produces 64-byte hash');
  
  // Test TrySecureRandom
  OK := TCryptoUtils.TrySecureRandom(32, Random);
  Check(OK, 'TrySecureRandom returns True');
  Check(Length(Random) = 32, 'TrySecureRandom produces correct length');
  
  // Test TrySecureRandom with different sizes
  OK := TCryptoUtils.TrySecureRandom(16, Random);
  Check(Length(Random) = 16, 'TrySecureRandom(16) produces 16 bytes');
  
  OK := TCryptoUtils.TrySecureRandom(64, Random);
  Check(Length(Random) = 64, 'TrySecureRandom(64) produces 64 bytes');
end;

procedure TestHashConsistency;
var
  Data: TBytes;
  Hash1, Hash2: TBytes;
  HexHash: string;
begin
  WriteLn;
  WriteLn('=== Testing Hash Consistency ===');
  
  Data := TEncoding.UTF8.GetBytes('Hello World');
  
  // Test SHA256 produces consistent results
  TCryptoUtils.TrySHA256(Data, Hash1);
  TCryptoUtils.TrySHA256(Data, Hash2);
  Check(CompareMem(@Hash1[0], @Hash2[0], 32), 'SHA256 produces consistent results');
  
  // Test SHA256 matches expected value
  HexHash := TCryptoUtils.SHA256Hex('Hello World');
  Check(LowerCase(HexHash) = 'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e', 
        'SHA256 produces correct hash for "Hello World"');
  
  // Test SHA512 produces consistent results
  TCryptoUtils.TrySHA512(Data, Hash1);
  TCryptoUtils.TrySHA512(Data, Hash2);
  Check(CompareMem(@Hash1[0], @Hash2[0], 64), 'SHA512 produces consistent results');
end;

procedure TestSecureRandomUniqueness;
var
  R1, R2, R3: TBytes;
begin
  WriteLn;
  WriteLn('=== Testing Random Uniqueness ===');
  
  TCryptoUtils.TrySecureRandom(32, R1);
  TCryptoUtils.TrySecureRandom(32, R2);
  TCryptoUtils.TrySecureRandom(32, R3);
  
  Check(not CompareMem(@R1[0], @R2[0], 32), 'SecureRandom produces unique output (R1 != R2)');
  Check(not CompareMem(@R2[0], @R3[0], 32), 'SecureRandom produces unique output (R2 != R3)');
  Check(not CompareMem(@R1[0], @R3[0], 32), 'SecureRandom produces unique output (R1 != R3)');
end;

procedure TestConnectionBuilder;
var
  Builder: ISSLConnectionBuilder;
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  Res: TSSLOperationResult;
begin
  WriteLn;
  WriteLn('=== Testing Connection Builder ===');

  // 1. Create Context
  Ctx := TSSLFactory.CreateContext(sslCtxClient);
  Check(Ctx <> nil, 'TSSLFactory.CreateContext creates context');

  // 2. Test Validation: Missing Context
  Builder := TSSLConnectionBuilder.Create;
  Res := Builder
    .WithSocket(12345) // Fake socket
    .TryBuildClient(Conn);
  
  Check(not Res.Success, 'Builder fails without Context');
  Check(Res.ErrorCode = sslErrInvalidParam, 'Error code is sslErrInvalidParam (Missing Context)');

  // 3. Test Validation: Missing Socket/Stream
  Builder := TSSLConnectionBuilder.Create;
  Res := Builder
    .WithContext(Ctx)
    .TryBuildClient(Conn);
    
  Check(not Res.Success, 'Builder fails without Socket/Stream');
  Check(Res.ErrorCode = sslErrInvalidParam, 'Error code is sslErrInvalidParam (Missing Socket)');

  // 4. Test Configuration Chain & Attempt Connection
  // Note: This will fail at handshake because socket 12345 is invalid/not connected,
  // but it verifies the builder passes validation and attempts connection.
  Builder := TSSLConnectionBuilder.Create;
  Res := Builder
    .WithContext(Ctx)
    .WithSocket(12345)
    .WithTimeout(5000)
    .WithBlocking(True)
    .WithHostname('example.com')
    .TryBuildClient(Conn);

  // We expect failure, but NOT invalid param failure. 
  // Should be connection/handshake error.
  Check(not Res.Success, 'Builder execution attempts connection (and fails as expected)');
  Check(Res.ErrorCode <> sslErrInvalidParam, 'Error is NOT invalid param (Validation passed)');
  
  WriteLn('  (Expected failure reason: ', Res.ErrorMessage, ')');
end;

begin
  WriteLn('╔═══════════════════════════════════════════╗');
  WriteLn('║  fafafa.ssl v2.0 - New API Unit Tests     ║');
  WriteLn('╚═══════════════════════════════════════════╝');
  
  try
    TestResultTypes;
    TestTryMethods;
    TestHashConsistency;
    TestSecureRandomUniqueness;
    TestConnectionBuilder;
    
    WriteLn;
    WriteLn('══════════════════════════════════════════');
    WriteLn('Test Summary:');
    WriteLn('  Passed: ', TestsPassed);
    WriteLn('  Failed: ', TestsFailed);
    WriteLn('  Total:  ', TestsPassed + TestsFailed);
    WriteLn('══════════════════════════════════════════');
    
    if TestsFailed = 0 then
    begin
      WriteLn;
      WriteLn('✅ All tests passed!');
      Halt(0);
    end
    else
    begin
      WriteLn;
      WriteLn('❌ Some tests failed!');
      Halt(1);
    end;
  except
    on E: Exception do
    begin
      WriteLn('❌ Fatal error: ', E.Message);
      Halt(1);
    end;
  end;
end.
