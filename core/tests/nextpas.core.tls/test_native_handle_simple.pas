{
  简化测试 - 仅测试辅助函数本身
}

program test_native_handle_simple;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.native_handle,
  nextpas.core.tls.exceptions;

type
  {  Mock 对象 - 实现 ISSLNativeHandleAccess }
  TMockNativeHandleAccess = class(TInterfacedObject, ISSLNativeHandleAccess)
  private
    FHandle: Pointer;
  public
    constructor Create(AHandle: Pointer);
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;
  end;

constructor TMockNativeHandleAccess.Create(AHandle: Pointer);
begin
  inherited Create;
  FHandle := AHandle;
end;

function TMockNativeHandleAccess.GetNativeHandle: Pointer;
begin
  Result := FHandle;
end;

function TMockNativeHandleAccess.GetBackendType: TSSLLibraryType;
begin
  Result := sslOpenSSL;
end;

function TMockNativeHandleAccess.IsNativeHandleValid: Boolean;
begin
  Result := FHandle <> nil;
end;

procedure Test(const AName: string; AResult: Boolean);
begin
  if AResult then
    WriteLn('[PASS] ', AName)
  else
    WriteLn('[FAIL] ', AName);
end;

procedure TestWithMockObject;
var
  MockObj: IInterface;
  Handle: Pointer;
  TestPtr: Pointer;
begin
  WriteLn('=== 测试 Mock 对象 ===');

  // 创建 Mock 对象
  TestPtr := Pointer($12345678);
  MockObj := TMockNativeHandleAccess.Create(TestPtr);

  // 测试 IsNativeHandleAvailable
  Test('IsNativeHandleAvailable', IsNativeHandleAvailable(MockObj));

  // 测试 GetNativeHandle
  Handle := GetNativeHandle(MockObj);
  Test('GetNativeHandle returns correct pointer', Handle = TestPtr);

  // 测试 GetBackendType
  Test('GetBackendType returns sslOpenSSL',
       GetBackendType(MockObj) = sslOpenSSL);

  // 测试 TryGetNativeHandle
  if TryGetNativeHandle(MockObj, Handle) then
    Test('TryGetNativeHandle success', Handle = TestPtr)
  else
    WriteLn('[FAIL] TryGetNativeHandle failed');

  // 测试 IsNativeHandleValid
  Test('IsNativeHandleValid', IsNativeHandleValid(MockObj));

  WriteLn;
end;

procedure TestErrorCases;
var
  NilObj: IInterface;
  Handle: Pointer;
begin
  WriteLn('=== 测试错误情况 ===');

  NilObj := nil;

  // 测试 IsNativeHandleAvailable 返回 False
  Test('IsNativeHandleAvailable returns False for nil',
       not IsNativeHandleAvailable(NilObj));

  // 测试 GetNativeHandle 抛出异常
  try
    Handle := GetNativeHandle(NilObj);
    WriteLn('[FAIL] Should throw exception for nil');
  except
    on E: ESSLException do
    begin
      Test('GetNativeHandle throws exception', True);
      WriteLn('  Error message length: ', Length(E.Message), ' chars');
      Test('Error message contains "not available"',
           Pos('not available', E.Message) > 0);
    end;
  end;

  // 测试 GetNativeHandleSafe 带上下文
  try
    Handle := GetNativeHandleSafe(NilObj, 'TestContext');
    WriteLn('[FAIL] Should throw exception');
  except
    on E: ESSLException do
    begin
      Test('GetNativeHandleSafe throws exception', True);
      Test('Error message contains context',
           Pos('TestContext', E.Message) > 0);
    end;
  end;

  // 测试 TryGetNativeHandle 返回 False
  Test('TryGetNativeHandle returns False for nil',
       not TryGetNativeHandle(NilObj, Handle));

  WriteLn;
end;

procedure TestGenericFunctions;
var
  MockObj: IInterface;
  TestPtr: Pointer;
  Result: Pointer;
begin
  WriteLn('=== 测试泛型函数 ===');

  TestPtr := Pointer($ABCDEF00);
  MockObj := TMockNativeHandleAccess.Create(TestPtr);

  // 测试 GetNativeHandleAs
  Result := specialize GetNativeHandleAs<Pointer>(MockObj);
  Test('GetNativeHandleAs<Pointer>', Result = TestPtr);

  // 测试 GetNativeHandleAsSafe
  Result := specialize GetNativeHandleAsSafe<Pointer>(MockObj, 'TestGeneric');
  Test('GetNativeHandleAsSafe<Pointer>', Result = TestPtr);

  // 测试 TryGetNativeHandleAs
  if specialize TryGetNativeHandleAs<Pointer>(MockObj, Result) then
    Test('TryGetNativeHandleAs<Pointer>', Result = TestPtr)
  else
    WriteLn('[FAIL] TryGetNativeHandleAs failed');

  WriteLn;
end;

procedure TestNullHandle;
var
  MockObj: IInterface;
  Handle: Pointer;
begin
  WriteLn('=== 测试 Null 句柄 ===');

  // 创建返回 nil 的 Mock 对象
  MockObj := TMockNativeHandleAccess.Create(nil);

  // IsNativeHandleValid 应该返回 False
  Test('IsNativeHandleValid returns False for null handle',
       not IsNativeHandleValid(MockObj));

  // GetNativeHandleSafe 应该抛出异常
  try
    Handle := GetNativeHandleSafe(MockObj, 'TestNullHandle');
    WriteLn('[FAIL] Should throw exception for null handle');
  except
    on E: ESSLException do
    begin
      Test('GetNativeHandleSafe throws exception for null', True);
      Test('Error message contains "null"',
           Pos('null', LowerCase(E.Message)) > 0);
    end;
  end;

  WriteLn;
end;

begin
  WriteLn('fafafa.ssl - 统一原生句柄辅助单元简化测试');
  WriteLn('============================================');
  WriteLn;

  try
    TestWithMockObject;
    TestErrorCases;
    TestGenericFunctions;
    TestNullHandle;

    WriteLn('============================================');
    WriteLn('所有测试完成！');
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('测试失败: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
