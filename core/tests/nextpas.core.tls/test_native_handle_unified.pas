{
  测试统一原生句柄辅助单元

  验证 nextpas.core.tls.native_handle 的所有功能
}

program test_native_handle_unified;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.native_handle,
  nextpas.core.tls.exceptions;

type
  PSSL_CTX = Pointer;  // OpenSSL 类型（简化）
  PSSL = Pointer;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;
  GSkipCount: Integer = 0;

procedure Test(const AName: string; AResult: Boolean);
begin
  if AResult then
  begin
    Inc(GPassCount);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('[FAIL] ', AName);
  end;
end;

procedure Fail(const AName: string; const AMessage: string = '');
begin
  Inc(GFailCount);
  if AMessage <> '' then
    WriteLn('[FAIL] ', AName, ': ', AMessage)
  else
    WriteLn('[FAIL] ', AName);
end;

procedure Skip(const AReason: string);
begin
  Inc(GSkipCount);
  WriteLn('[SKIP] ', AReason);
end;

procedure TestBasicFunctions;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Handle: Pointer;
  BackendType: TSSLLibraryType;
begin
  WriteLn('=== 测试基础函数 ===');

  // 创建 OpenSSL 上下文
  try
    Lib := TSSLFactory.GetLibrary(sslOpenSSL);
  except
    Skip('Factory not available');
    Exit;
  end;
  if not Lib.Initialize then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  Ctx := Lib.CreateContext(sslCtxClient);

  // 测试 IsNativeHandleAvailable
  Test('IsNativeHandleAvailable', IsNativeHandleAvailable(Ctx));

  // 测试 GetBackendType
  BackendType := GetBackendType(Ctx);
  Test('GetBackendType returns sslOpenSSL',
       BackendType = sslOpenSSL);

  // 测试 GetNativeHandle
  try
    Handle := GetNativeHandle(Ctx);
    Test('GetNativeHandle returns non-nil', Handle <> nil);
  except
    on E: Exception do
      Fail('GetNativeHandle exception', E.Message);
  end;

  // 测试 TryGetNativeHandle
  if TryGetNativeHandle(Ctx, Handle) then
    Test('TryGetNativeHandle success', Handle <> nil)
  else
    Fail('TryGetNativeHandle failed');

  // 测试 IsNativeHandleValid
  Test('IsNativeHandleValid', IsNativeHandleValid(Ctx));

  WriteLn;
end;

procedure TestSafeFunction;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Handle: Pointer;
begin
  WriteLn('=== 测试安全函数 ===');

  Lib := TSSLFactory.GetLibrary(sslOpenSSL);
  if not Lib.Initialize then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  Ctx := Lib.CreateContext(sslCtxClient);

  // 测试 GetNativeHandleSafe 带上下文
  try
    Handle := GetNativeHandleSafe(Ctx, 'TestSafeFunction');
    Test('GetNativeHandleSafe with context', Handle <> nil);
  except
    on E: Exception do
      Fail('GetNativeHandleSafe exception', E.Message);
  end;

  // 测试 GetNativeHandleSafe 无上下文
  try
    Handle := GetNativeHandleSafe(Ctx);
    Test('GetNativeHandleSafe without context', Handle <> nil);
  except
    on E: Exception do
      Fail('GetNativeHandleSafe exception', E.Message);
  end;

  WriteLn;
end;

procedure TestGenericFunctions;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  SSL_CTX: PSSL_CTX;
begin
  WriteLn('=== 测试泛型函数 ===');

  Lib := TSSLFactory.GetLibrary(sslOpenSSL);
  if not Lib.Initialize then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  Ctx := Lib.CreateContext(sslCtxClient);

  // 测试 GetNativeHandleAs
  try
    SSL_CTX := specialize GetNativeHandleAs<PSSL_CTX>(Ctx);
    Test('GetNativeHandleAs<PSSL_CTX>', SSL_CTX <> nil);
  except
    on E: Exception do
      Fail('GetNativeHandleAs exception', E.Message);
  end;

  // 测试 GetNativeHandleAsSafe
  try
    SSL_CTX := specialize GetNativeHandleAsSafe<PSSL_CTX>(Ctx, 'TestGenericFunctions');
    Test('GetNativeHandleAsSafe<PSSL_CTX>', SSL_CTX <> nil);
  except
    on E: Exception do
      Fail('GetNativeHandleAsSafe exception', E.Message);
  end;

  // 测试 TryGetNativeHandleAs
  if specialize TryGetNativeHandleAs<PSSL_CTX>(Ctx, SSL_CTX) then
    Test('TryGetNativeHandleAs<PSSL_CTX>', SSL_CTX <> nil)
  else
    Fail('TryGetNativeHandleAs failed');

  WriteLn;
end;

procedure TestErrorMessages;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  DummyIntf: IInterface;
  Handle: Pointer;
begin
  WriteLn('=== 测试错误消息 ===');

  // 创建一个不支持 ISSLNativeHandleAccess 的对象
  // （这里使用一个简单的接口作为示例）
  DummyIntf := nil;  // nil 接口

  // 测试错误消息 - GetNativeHandle
  try
    Handle := GetNativeHandle(DummyIntf);
    Fail('Should throw exception for nil interface');
  except
    on E: ESSLException do
    begin
      Test('GetNativeHandle throws exception for unsupported object', True);
      WriteLn('  Error message preview: ',
              Copy(E.Message, 1, 50), '...');
    end;
    on E: Exception do
      Fail('Unexpected exception', E.ClassName);
  end;

  // 测试错误消息 - GetNativeHandleSafe 带上下文
  try
    Handle := GetNativeHandleSafe(DummyIntf, 'TestErrorMessages.Line123');
    Fail('Should throw exception');
  except
    on E: ESSLException do
    begin
      Test('GetNativeHandleSafe throws exception with context', True);
      Test('Error message contains context',
           Pos('TestErrorMessages.Line123', E.Message) > 0);
      WriteLn('  Full error message:');
      WriteLn('  ', E.Message);
    end;
  end;

  WriteLn;
end;


procedure TestPureBackendLibraryContract;
var
  PureLib: ISSLLibrary;
  Handle: Pointer;
begin
  WriteLn('=== 测试 Pure Backend 合同 ===');

  PureLib := TSSLFactory.GetLibrary(sslFreePascal);
  if PureLib = nil then
  begin
    Skip('FreePascal backend library not available');
    WriteLn;
    Exit;
  end;

  Test('GetBackendType returns sslFreePascal for pure backend library',
       GetBackendType(PureLib) = sslFreePascal);
  Test('IsNativeHandleAvailable is false for pure backend library',
       not IsNativeHandleAvailable(PureLib));

  if TryGetNativeHandle(PureLib, Handle) then
    Fail('TryGetNativeHandle should fail for pure backend library')
  else
    Test('TryGetNativeHandle fails for pure backend library', Handle = nil);

  try
    Handle := GetNativeHandleSafe(PureLib, 'TestPureBackendLibraryContract');
    Fail('GetNativeHandleSafe should throw for pure backend library', 'got unexpected handle');
  except
    on E: ESSLException do
    begin
      Test('GetNativeHandleSafe throws for pure backend library', True);
      Test('Error message mentions pure FreePascal backend',
           Pos('pure freepascal backend', LowerCase(E.Message)) > 0);
    end;
    on E: Exception do
      Fail('Unexpected exception in pure backend contract', E.ClassName + ': ' + E.Message);
  end;

  WriteLn;
end;

procedure TestUsageExample;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  SSL_CTX: PSSL_CTX;
begin
  WriteLn('=== 使用示例 ===');

  Lib := TSSLFactory.GetLibrary(sslOpenSSL);
  if not Lib.Initialize then
  begin
    Skip('OpenSSL not available');
    Exit;
  end;

  Ctx := Lib.CreateContext(sslCtxClient);

  // 示例1: 简洁方式
  SSL_CTX := PSSL_CTX(GetNativeHandle(Ctx));
  WriteLn('[示例1] 简洁方式: Handle = ', PtrUInt(SSL_CTX));

  // 示例2: 类型安全方式
  SSL_CTX := specialize GetNativeHandleAs<PSSL_CTX>(Ctx);
  WriteLn('[示例2] 类型安全方式: Handle = ', PtrUInt(SSL_CTX));

  // 示例3: 最安全方式
  SSL_CTX := specialize GetNativeHandleAsSafe<PSSL_CTX>(Ctx, 'TestUsageExample');
  WriteLn('[示例3] 最安全方式: Handle = ', PtrUInt(SSL_CTX));

  // 示例4: 检查可用性
  if IsNativeHandleAvailable(Ctx) then
  begin
    WriteLn('[示例4] Native handle is available');
    WriteLn('  Backend type: ', GetBackendType(Ctx));
  end;

  WriteLn;
end;

begin
  WriteLn('fafafa.ssl - 统一原生句柄辅助单元测试');
  WriteLn('==========================================');
  WriteLn;

  try
    TestBasicFunctions;
    TestSafeFunction;
    TestGenericFunctions;
    TestErrorMessages;
    TestPureBackendLibraryContract;
    TestUsageExample;

    WriteLn('==========================================');
    WriteLn('汇总:');
    WriteLn('  Passed: ', GPassCount);
    WriteLn('  Failed: ', GFailCount);
    WriteLn('  Skipped: ', GSkipCount);

    if GFailCount > 0 then
      ExitCode := 1
    else
      ExitCode := 0;

    WriteLn('测试完成！');
  except
    on E: Exception do
    begin
      WriteLn('测试失败: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
