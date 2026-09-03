program test_errors;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.test;

procedure TestExceptionHierarchy;
var
  LErr: ENextPasError;
begin
  LErr := EArgumentError.Create('test argument error');
  CheckTrue(LErr is ENextPasError, 'EArgumentError should inherit ENextPasError');
  CheckEqual('test argument error', LErr.Message);
  LErr.Free;

  LErr := EIOError.Create('io failed');
  CheckTrue(LErr is ENextPasError, 'EIOError should inherit ENextPasError');
  LErr.Free;

  LErr := ETimeoutError.Create('timed out');
  CheckTrue(LErr is ENextPasError, 'ETimeoutError should inherit ENextPasError');
  LErr.Free;
end;

procedure TestExceptionRaise;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    raise EIndexOutOfRangeError.Create('index 5 out of range [0..3]');
  except
    on E: ENextPasError do
      LCaught := True;
  end;
  CheckTrue(LCaught, 'Should catch EIndexOutOfRangeError as ENextPasError');
end;

procedure TestCategoryConstantsRemainPublic;
var
  LErr: ENextPasError;
begin
  LErr := ENextPasError.Create('network failed', ecNetwork);
  try
    CheckTrue(LErr.Category = ecNetwork, 'ecNetwork should remain public through nextpas.core.errors');
  finally
    LErr.Free;
  end;
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('errors');
  LSuite.Test('exception hierarchy', @TestExceptionHierarchy);
  LSuite.Test('exception raise', @TestExceptionRaise);
  LSuite.Test('category constants public', @TestCategoryConstantsRemainPublic);
  LRunner := TSuiteRunner.Create('nextpas.core.errors');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then
    Halt(1);
end.
