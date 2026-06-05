program test_result_utils;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.result.utils;

var
  LResult: TSSLOperationResult;
  LDataResult: TSSLDataResult;
  LStringResult: TSSLStringResult;
  LTestsPassed, LTestsFailed: Integer;

procedure Test(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', AName);
    Inc(LTestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', AName);
    Inc(LTestsFailed);
  end;
end;

function AlwaysTrue: Boolean;
begin
  Result := True;
end;

function AlwaysFalse: Boolean;
begin
  Result := False;
end;

begin
  LTestsPassed := 0;
  LTestsFailed := 0;

  WriteLn('=== nextpas.core.tls.result.utils Tests ===');
  WriteLn;

  // Test 1: Ok() convenience function
  WriteLn('--- TSSLOperationResult Tests ---');
  LResult := Ok;
  Test('Ok() creates success result', LResult.IsOk);
  Test('Ok() is not error', not LResult.IsErr);

  // Test 2: Err() convenience function
  LResult := Err(sslErrGeneral, 'Test error');
  Test('Err() creates error result', LResult.IsErr);
  Test('Err() is not ok', not LResult.IsOk);
  Test('Err() has correct error code', LResult.ErrorCode = sslErrGeneral);
  Test('Err() has correct message', LResult.ErrorMessage = 'Test error');

  // Test 3: FromBool conversion
  LResult := TResultUtils.FromBool(True, 'TestOp');
  Test('FromBool(True) is ok', LResult.IsOk);

  LResult := TResultUtils.FromBool(False, 'TestOp');
  Test('FromBool(False) is error', LResult.IsErr);
  Test('FromBool(False) has context in message', Pos('TestOp', LResult.ErrorMessage) > 0);

  // Test 4: ToResult inline function
  LResult := ToResult(True, 'InlineTest');
  Test('ToResult(True) is ok', LResult.IsOk);

  LResult := ToResult(False, 'InlineTest');
  Test('ToResult(False) is error', LResult.IsErr);

  // Test 5: TryOperation
  LResult := TResultUtils.TryOperation(@AlwaysTrue, 'AlwaysTrue');
  Test('TryOperation with true func is ok', LResult.IsOk);

  LResult := TResultUtils.TryOperation(@AlwaysFalse, 'AlwaysFalse');
  Test('TryOperation with false func is error', LResult.IsErr);

  // Test 6: WithContext helper
  LResult := Err(sslErrCertificate, 'cert error');
  LResult := LResult.WithContext('LoadCertificate');
  Test('WithContext adds prefix', Pos('LoadCertificate', LResult.ErrorMessage) > 0);

  // Test 7: ToString helper
  LResult := Ok;
  Test('Ok.ToString is "Ok"', LResult.ToString = 'Ok');

  LResult := Err(sslErrGeneral, 'test');
  Test('Err.ToString contains error info', Pos('Err', LResult.ToString) > 0);

  // Test 8: OrElse helper
  LResult := Err(sslErrGeneral, 'first error');
  LResult := LResult.OrElse(Ok);
  Test('OrElse returns default on error', LResult.IsOk);

  LResult := Ok;
  LResult := LResult.OrElse(Err(sslErrGeneral, 'should not use'));
  Test('OrElse keeps ok value', LResult.IsOk);

  // Test 9: All combinator
  LResult := TResultUtils.All([Ok, Ok, Ok]);
  Test('All([Ok, Ok, Ok]) is ok', LResult.IsOk);

  LResult := TResultUtils.All([Ok, Err(sslErrGeneral, 'fail'), Ok]);
  Test('All with one error is error', LResult.IsErr);

  // Test 10: Any combinator
  LResult := TResultUtils.Any([Err(sslErrGeneral, 'e1'), Ok, Err(sslErrGeneral, 'e2')]);
  Test('Any with one ok is ok', LResult.IsOk);

  LResult := TResultUtils.Any([Err(sslErrGeneral, 'e1'), Err(sslErrCertificate, 'e2')]);
  Test('Any with all errors is error', LResult.IsErr);

  // Test 11: TSSLDataResult
  WriteLn;
  WriteLn('--- TSSLDataResult Tests ---');
  LDataResult := OkData(TBytes.Create(1, 2, 3, 4));
  Test('OkData creates success', LDataResult.IsOk);
  Test('OkData has correct data length', Length(LDataResult.Data) = 4);

  LDataResult := ErrData(sslErrInvalidData, 'bad data');
  Test('ErrData creates error', LDataResult.IsErr);
  Test('ErrData.ToString contains Err', Pos('Err', LDataResult.ToString) > 0);

  // Test 12: TSSLStringResult
  WriteLn;
  WriteLn('--- TSSLStringResult Tests ---');
  LStringResult := OkString('hello');
  Test('OkString creates success', LStringResult.IsOk);
  Test('OkString has correct value', LStringResult.Value = 'hello');

  LStringResult := ErrString(sslErrParseFailed, 'parse error');
  Test('ErrString creates error', LStringResult.IsErr);
  Test('ErrString.ToString contains Err', Pos('Err', LStringResult.ToString) > 0);

  // Summary
  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', LTestsPassed);
  WriteLn('Failed: ', LTestsFailed);
  WriteLn;

  if LTestsFailed = 0 then
  begin
    WriteLn('All tests passed!');
    ExitCode := 0;
  end
  else
  begin
    WriteLn('Some tests failed!');
    ExitCode := 1;
  end;
end.
