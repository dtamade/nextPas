program test_errors;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors;

procedure TestExceptionHierarchy;
var
  LErr: ENextPasError;
begin
  LErr := EArgumentError.Create('test argument error');
  Assert(LErr is ENextPasError, 'EArgumentError should inherit ENextPasError');
  Assert(LErr.Message = 'test argument error');
  LErr.Free;

  LErr := EIOError.Create('io failed');
  Assert(LErr is ENextPasError);
  LErr.Free;

  LErr := ETimeoutError.Create('timed out');
  Assert(LErr is ENextPasError);
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
  Assert(LCaught, 'Should catch EIndexOutOfRangeError as ENextPasError');
end;

procedure TestCategoryConstantsRemainPublic;
var
  LErr: ENextPasError;
begin
  LErr := ENextPasError.Create('network failed', ecNetwork);
  try
    Assert(LErr.Category = ecNetwork, 'ecNetwork should remain public through nextpas.core.errors');
  finally
    LErr.Free;
  end;
end;

begin
  WriteLn('=== nextpas.core.errors tests ===');
  TestExceptionHierarchy;
  TestExceptionRaise;
  TestCategoryConstantsRemainPublic;
  WriteLn('PASS: all errors tests passed');
end.
