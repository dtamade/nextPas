program test_result_types;

{$mode objfpc}{$H+}

{**
 * Result 类型单元测试
 *
 * 测试所有 Result 类型的方法和边界情况
 *}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

type
  { 测试助手类 - 提供回调方法 }
  TTestHelper = class
  public
    Inspected: Boolean;
    InspectedValue: string;

    function IsNonEmptyBytes(const AData: TBytes): Boolean;
    function IsLongEnoughBytes(const AData: TBytes): Boolean;
    procedure MarkInspected(const AData: TBytes);

    function IsNonEmptyString(const AValue: string): Boolean;
    function IsLongEnoughString(const AValue: string): Boolean;
    procedure CaptureValue(const AValue: string);
  end;

function TTestHelper.IsNonEmptyBytes(const AData: TBytes): Boolean;
begin
  Result := Length(AData) > 0;
end;

function TTestHelper.IsLongEnoughBytes(const AData: TBytes): Boolean;
begin
  Result := Length(AData) >= 5;
end;

procedure TTestHelper.MarkInspected(const AData: TBytes);
begin
  Inspected := True;
end;

function TTestHelper.IsNonEmptyString(const AValue: string): Boolean;
begin
  Result := Length(AValue) > 0;
end;

function TTestHelper.IsLongEnoughString(const AValue: string): Boolean;
begin
  Result := Length(AValue) >= 10;
end;

procedure TTestHelper.CaptureValue(const AValue: string);
begin
  InspectedValue := AValue;
end;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    Write('  ✓ ');
  end
  else
  begin
    Inc(GTestsFailed);
    Write('  ✗ ');
  end;
  WriteLn(AMessage);
end;

procedure AssertEquals(AExpected, AActual: Integer; const AMessage: string);
begin
  Assert(AExpected = AActual, AMessage + Format(' (Expected: %d, Got: %d)', [AExpected, AActual]));
end;

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  Assert(AExpected = AActual, AMessage + Format(' (Expected: "%s", Got: "%s")', [AExpected, AActual]));
end;

procedure TestSSLOperationResult;
var
  LResult: TSSLOperationResult;
begin
  WriteLn('=== TSSLOperationResult Tests ===');

  // Test Ok
  LResult := TSSLOperationResult.Ok;
  Assert(LResult.Success, 'Ok should set Success to True');
  Assert(LResult.IsOk, 'IsOk should return True for Ok result');
  Assert(not LResult.IsErr, 'IsErr should return False for Ok result');
  AssertEquals(Ord(sslErrNone), Ord(LResult.ErrorCode), 'Ok should have sslErrNone');

  // Test Err
  LResult := TSSLOperationResult.Err(sslErrTimeout, 'Timeout occurred');
  Assert(not LResult.Success, 'Err should set Success to False');
  Assert(LResult.IsErr, 'IsErr should return True for Err result');
  Assert(not LResult.IsOk, 'IsOk should return False for Err result');
  AssertEquals(Ord(sslErrTimeout), Ord(LResult.ErrorCode), 'Err should preserve error code');
  AssertEquals('Timeout occurred', LResult.ErrorMessage, 'Err should preserve error message');

  // Test Expect (success)
  LResult := TSSLOperationResult.Ok;
  try
    LResult.Expect('Should not throw');
    Assert(True, 'Expect should not throw on Ok');
  except
    Assert(False, 'Expect should not throw on Ok');
  end;

  // Test Expect (failure)
  LResult := TSSLOperationResult.Err(sslErrGeneral, 'Error');
  WriteLn('    DEBUG: About to test Expect with Err...');
  try
    WriteLn('    DEBUG: Calling Expect...');
    LResult.Expect('Custom message');
    WriteLn('    DEBUG: After Expect (should not reach here)');
    Assert(False, 'Expect should throw on Err');
  except
    on E: ESSLException do
    begin
      WriteLn('    DEBUG: Caught ESSLException: ', E.Message);
      Assert(True, 'Expect correctly threw ESSLException');
    end;
    on E: Exception do
    begin
      WriteLn('    DEBUG: Caught other exception: ', E.ClassName, ': ', E.Message);
      Assert(False, 'Wrong exception type');
    end;
  end;
  WriteLn('    DEBUG: After exception handling');

  // Test UnwrapErr
  LResult := TSSLOperationResult.Err(sslErrMemory, 'Memory error');
  AssertEquals(Ord(sslErrMemory), Ord(LResult.UnwrapErr), 'UnwrapErr should return error code');

  WriteLn;
end;

procedure TestSSLDataResult;
var
  LResult: TSSLDataResult;
  LData, LDefault: TBytes;
  LGotException: Boolean;
begin
  WriteLn('=== TSSLDataResult Tests ===');

  // Test Ok
  SetLength(LData, 3);
  LData[0] := 1; LData[1] := 2; LData[2] := 3;
  LResult := TSSLDataResult.Ok(LData);
  Assert(LResult.Success, 'Ok should set Success to True');
  Assert(LResult.IsOk, 'IsOk should return True');
  AssertEquals(3, Length(LResult.Data), 'Ok should preserve data');
  AssertEquals(1, LResult.Data[0], 'Ok should preserve data values');

  // Test Err
  LResult := TSSLDataResult.Err(sslErrInvalidParam, 'Invalid');
  Assert(LResult.IsErr, 'IsErr should return True for Err');
  AssertEquals(0, Length(LResult.Data), 'Err should have empty data');

  // Test Unwrap (success)
  SetLength(LData, 2);
  LData[0] := 42; LData[1] := 99;
  LResult := TSSLDataResult.Ok(LData);
  LData := LResult.Unwrap;
  AssertEquals(2, Length(LData), 'Unwrap should return data');
  AssertEquals(42, LData[0], 'Unwrap should return correct data');

  // Test Unwrap (failure)
  LResult := TSSLDataResult.Err(sslErrGeneral, 'Error');
  LGotException := False;
  try
    LData := LResult.Unwrap;
    Assert(False, 'Unwrap should throw on Err');
  except
    on E: Exception do
      LGotException := True;
  end;
  Assert(LGotException, 'Unwrap should throw on Err');

  // Test UnwrapOr (success)
  SetLength(LData, 1);
  LData[0] := 123;
  LResult := TSSLDataResult.Ok(LData);
  SetLength(LDefault, 1);
  LDefault[0] := 250;  // Use value that fits in Byte (0-255)
  LData := LResult.UnwrapOr(LDefault);
  AssertEquals(123, LData[0], 'UnwrapOr should return data on Ok');

  // Test UnwrapOr (failure)
  LData := nil;        // Clear any reference
  LDefault := nil;     // Clear any reference
  SetLength(LDefault, 1);
  LDefault[0] := 250;  // Use value that fits in Byte (0-255)
  LResult := TSSLDataResult.Err(sslErrGeneral, 'Error');
  LData := LResult.UnwrapOr(LDefault);
  AssertEquals(250, LData[0], 'UnwrapOr should return default on Err');

  // Test Expect (success)
  SetLength(LData, 1);
  LData[0] := 55;
  LResult := TSSLDataResult.Ok(LData);
  LData := LResult.Expect('Should succeed');
  AssertEquals(55, LData[0], 'Expect should return data on Ok');

  // Test Expect (failure)
  LResult := TSSLDataResult.Err(sslErrGeneral, 'Error');
  LGotException := False;
  try
    LData := LResult.Expect('Custom error');
    Assert(False, 'Expect should throw on Err');
  except
    on E: Exception do
      LGotException := True;
  end;
  Assert(LGotException, 'Expect should throw on Err');

  // Test UnwrapErr
  LResult := TSSLDataResult.Err(sslErrCertificate, 'Cert error');
  AssertEquals(Ord(sslErrCertificate), Ord(LResult.UnwrapErr), 'UnwrapErr should return error code');

  WriteLn;
end;

procedure TestSSLDataResult_IsOkAnd;
var
  LResult: TSSLDataResult;
  LData: TBytes;
  LHelper: TTestHelper;
begin
  WriteLn('=== TSSLDataResult.IsOkAnd Tests ===');

  LHelper := TTestHelper.Create;
  try
    // Test IsOkAnd with Ok and True predicate
    SetLength(LData, 10);
    LResult := TSSLDataResult.Ok(LData);
    Assert(LResult.IsOkAnd(@LHelper.IsNonEmptyBytes), 'IsOkAnd should return True when Ok and predicate True');

    // Test IsOkAnd with Ok and False predicate
    SetLength(LData, 2);
    LResult := TSSLDataResult.Ok(LData);
    Assert(not LResult.IsOkAnd(@LHelper.IsLongEnoughBytes), 'IsOkAnd should return False when Ok and predicate False');

    // Test IsOkAnd with Err
    LResult := TSSLDataResult.Err(sslErrGeneral, 'Error');
    Assert(not LResult.IsOkAnd(@LHelper.IsNonEmptyBytes), 'IsOkAnd should return False when Err');
  finally
    LHelper.Free;
  end;

  WriteLn;
end;

procedure TestSSLDataResult_Inspect;
var
  LResult: TSSLDataResult;
  LData: TBytes;
  LHelper: TTestHelper;
begin
  WriteLn('=== TSSLDataResult.Inspect Tests ===');

  LHelper := TTestHelper.Create;
  try
    // Test Inspect with Ok
    SetLength(LData, 5);
    LResult := TSSLDataResult.Ok(LData);
    LHelper.Inspected := False;
    LResult := LResult.Inspect(@LHelper.MarkInspected);
    Assert(LHelper.Inspected, 'Inspect should call callback on Ok');
    Assert(LResult.IsOk, 'Inspect should not consume result');
    AssertEquals(5, Length(LResult.Data), 'Inspect should preserve data');

    // Test Inspect with Err
    LResult := TSSLDataResult.Err(sslErrGeneral, 'Error');
    LHelper.Inspected := False;
    LResult := LResult.Inspect(@LHelper.MarkInspected);
    Assert(not LHelper.Inspected, 'Inspect should not call callback on Err');
    Assert(LResult.IsErr, 'Inspect should preserve Err state');
  finally
    LHelper.Free;
  end;

  WriteLn;
end;

procedure TestSSLStringResult;
var
  LResult: TSSLStringResult;
  LValue: string;
  LGotException: Boolean;
begin
  WriteLn('=== TSSLStringResult Tests ===');

  // Test Ok
  LResult := TSSLStringResult.Ok('Hello');
  Assert(LResult.IsOk, 'Ok should set IsOk to True');
  AssertEquals('Hello', LResult.Value, 'Ok should preserve value');

  // Test Err
  LResult := TSSLStringResult.Err(sslErrGeneral, 'Error message');
  Assert(LResult.IsErr, 'Err should set IsErr to True');
  AssertEquals('', LResult.Value, 'Err should have empty value');
  AssertEquals('Error message', LResult.ErrorMessage, 'Err should preserve error message');

  // Test Unwrap (success)
  LResult := TSSLStringResult.Ok('Test Value');
  LValue := LResult.Unwrap;
  AssertEquals('Test Value', LValue, 'Unwrap should return value on Ok');

  // Test Unwrap (failure)
  LResult := TSSLStringResult.Err(sslErrGeneral, 'Error');
  LGotException := False;
  try
    LValue := LResult.Unwrap;
    Assert(False, 'Unwrap should throw on Err');
  except
    on E: Exception do
      LGotException := True;
  end;
  Assert(LGotException, 'Unwrap should throw on Err');

  // Test UnwrapOr
  LResult := TSSLStringResult.Ok('Actual');
  LValue := LResult.UnwrapOr('Default');
  AssertEquals('Actual', LValue, 'UnwrapOr should return value on Ok');

  LResult := TSSLStringResult.Err(sslErrGeneral, 'Error');
  LValue := LResult.UnwrapOr('Default');
  AssertEquals('Default', LValue, 'UnwrapOr should return default on Err');

  // Test Expect
  LResult := TSSLStringResult.Ok('Success');
  LValue := LResult.Expect('Should work');
  AssertEquals('Success', LValue, 'Expect should return value on Ok');

  LResult := TSSLStringResult.Err(sslErrGeneral, 'Error');
  LGotException := False;
  try
    LValue := LResult.Expect('Custom message');
    Assert(False, 'Expect should throw on Err');
  except
    on E: Exception do
      LGotException := True;
  end;
  Assert(LGotException, 'Expect should throw on Err');

  WriteLn;
end;

procedure TestSSLStringResult_IsOkAnd;
var
  LResult: TSSLStringResult;
  LHelper: TTestHelper;
begin
  WriteLn('=== TSSLStringResult.IsOkAnd Tests ===');

  LHelper := TTestHelper.Create;
  try
    // Test with Ok and True predicate
    LResult := TSSLStringResult.Ok('Hello World!');
    Assert(LResult.IsOkAnd(@LHelper.IsNonEmptyString), 'IsOkAnd should return True when Ok and predicate True');
    Assert(LResult.IsOkAnd(@LHelper.IsLongEnoughString), 'IsOkAnd should handle different predicates');

    // Test with Ok and False predicate
    LResult := TSSLStringResult.Ok('Short');
    Assert(not LResult.IsOkAnd(@LHelper.IsLongEnoughString), 'IsOkAnd should return False when predicate False');

    // Test with Err
    LResult := TSSLStringResult.Err(sslErrGeneral, 'Error');
    Assert(not LResult.IsOkAnd(@LHelper.IsNonEmptyString), 'IsOkAnd should return False when Err');
  finally
    LHelper.Free;
  end;

  WriteLn;
end;

procedure TestSSLStringResult_Inspect;
var
  LResult: TSSLStringResult;
  LHelper: TTestHelper;
begin
  WriteLn('=== TSSLStringResult.Inspect Tests ===');

  LHelper := TTestHelper.Create;
  try
    // Test Inspect with Ok
    LResult := TSSLStringResult.Ok('Inspected');
    LHelper.InspectedValue := '';
    LResult := LResult.Inspect(@LHelper.CaptureValue);
    AssertEquals('Inspected', LHelper.InspectedValue, 'Inspect should call callback with value');
    Assert(LResult.IsOk, 'Inspect should not consume result');
    AssertEquals('Inspected', LResult.Value, 'Inspect should preserve value');

    // Test Inspect with Err
    LResult := TSSLStringResult.Err(sslErrGeneral, 'Error');
    LHelper.InspectedValue := 'unchanged';
    LResult := LResult.Inspect(@LHelper.CaptureValue);
    AssertEquals('unchanged', LHelper.InspectedValue, 'Inspect should not call callback on Err');
    Assert(LResult.IsErr, 'Inspect should preserve Err state');
  finally
    LHelper.Free;
  end;

  WriteLn;
end;

begin
  WriteLn('╔════════════════════════════════════════════════════════════╗');
  WriteLn('║   Result Types Unit Tests                                  ║');
  WriteLn('╚════════════════════════════════════════════════════════════╝');
  WriteLn;

  try
    TestSSLOperationResult;
    TestSSLDataResult;
    TestSSLDataResult_IsOkAnd;
    TestSSLDataResult_Inspect;
    TestSSLStringResult;
    TestSSLStringResult_IsOkAnd;
    TestSSLStringResult_Inspect;

    WriteLn('╔════════════════════════════════════════════════════════════╗');
    WriteLn(Format('║   Tests Passed: %-3d  Failed: %-3d                         ║', [GTestsPassed, GTestsFailed]));
    WriteLn('╚════════════════════════════════════════════════════════════╝');

    if GTestsFailed > 0 then
      ExitCode := 1;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('FATAL ERROR: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
