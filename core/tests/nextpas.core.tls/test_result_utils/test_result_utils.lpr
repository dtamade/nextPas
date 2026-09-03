program test_result_utils;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tls.base,
  nextpas.core.tls.result.utils,
  nextpas.core.test, nextpas.core.base, nextpas.core.text;

function AlwaysTrue: Boolean; begin Result := True; end;
function AlwaysFalse: Boolean; begin Result := False; end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('tls.result_utils');

  LSuite.Test('Ok/Err basics', procedure
  var LR: TSSLOperationResult;
  begin
    LR := Ok;
    CheckTrue(LR.IsOk); CheckTrue(not LR.IsErr);
    LR := Err(sslErrGeneral, 'Test error');
    CheckTrue(LR.IsErr); CheckTrue(not LR.IsOk);
    CheckTrue(LR.ErrorCode = sslErrGeneral);
    CheckEqual('Test error', LR.ErrorMessage);
  end);

  LSuite.Test('FromBool', procedure
  var LR: TSSLOperationResult;
  begin
    LR := TResultUtils.FromBool(True, 'TestOp');
    CheckTrue(LR.IsOk);
    LR := TResultUtils.FromBool(False, 'TestOp');
    CheckTrue(LR.IsErr);
    CheckTrue(Pos('TestOp', LR.ErrorMessage) > 0);
  end);

  LSuite.Test('ToResult', procedure
  var LR: TSSLOperationResult;
  begin
    LR := ToResult(True, 'InlineTest');
    CheckTrue(LR.IsOk);
    LR := ToResult(False, 'InlineTest');
    CheckTrue(LR.IsErr);
  end);

  LSuite.Test('TryOperation', procedure
  var LR: TSSLOperationResult;
  begin
    LR := TResultUtils.TryOperation(@AlwaysTrue, 'AlwaysTrue');
    CheckTrue(LR.IsOk);
    LR := TResultUtils.TryOperation(@AlwaysFalse, 'AlwaysFalse');
    CheckTrue(LR.IsErr);
  end);

  LSuite.Test('WithContext', procedure
  var LR: TSSLOperationResult;
  begin
    LR := Err(sslErrCertificate, 'cert error');
    LR := LR.WithContext('LoadCertificate');
    CheckTrue(Pos('LoadCertificate', LR.ErrorMessage) > 0);
  end);

  LSuite.Test('ToString', procedure
  var LR: TSSLOperationResult;
  begin
    LR := Ok;
    CheckEqual('Ok', LR.ToString);
    LR := Err(sslErrGeneral, 'test');
    CheckTrue(Pos('Err', LR.ToString) > 0);
  end);

  LSuite.Test('OrElse', procedure
  var LR: TSSLOperationResult;
  begin
    LR := Err(sslErrGeneral, 'first error');
    LR := LR.OrElse(Ok);
    CheckTrue(LR.IsOk);
    LR := Ok;
    LR := LR.OrElse(Err(sslErrGeneral, 'should not use'));
    CheckTrue(LR.IsOk);
  end);

  LSuite.Test('All combinator', procedure
  var LR: TSSLOperationResult;
  begin
    LR := TResultUtils.All([Ok, Ok, Ok]);
    CheckTrue(LR.IsOk);
    LR := TResultUtils.All([Ok, Err(sslErrGeneral, 'fail'), Ok]);
    CheckTrue(LR.IsErr);
  end);

  LSuite.Test('Any combinator', procedure
  var LR: TSSLOperationResult;
  begin
    LR := TResultUtils.Any([Err(sslErrGeneral, 'e1'), Ok, Err(sslErrGeneral, 'e2')]);
    CheckTrue(LR.IsOk);
    LR := TResultUtils.Any([Err(sslErrGeneral, 'e1'), Err(sslErrCertificate, 'e2')]);
    CheckTrue(LR.IsErr);
  end);

  LSuite.Test('TSSLDataResult', procedure
  var LR: TSSLDataResult;
  begin
    LR := OkData(TBytes.Create(1, 2, 3, 4));
    CheckTrue(LR.IsOk); CheckEqual(4, Length(LR.Data));
    LR := ErrData(sslErrInvalidData, 'bad data');
    CheckTrue(LR.IsErr); CheckTrue(Pos('Err', LR.ToString) > 0);
  end);

  LSuite.Test('TSSLStringResult', procedure
  var LR: TSSLStringResult;
  begin
    LR := OkString('hello');
    CheckTrue(LR.IsOk); CheckEqual('hello', LR.Value);
    LR := ErrString(sslErrParseFailed, 'parse error');
    CheckTrue(LR.IsErr); CheckTrue(Pos('Err', LR.ToString) > 0);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.tls.result_utils');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
