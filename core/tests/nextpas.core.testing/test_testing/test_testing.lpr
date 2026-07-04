program test_testing;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestCheckPass;
begin
  Check(True);
  Check(1 = 1, 'one equals one');
end;

procedure TestCheckEqualStr;
begin
  CheckEqual('hello', 'hello');
  CheckEqual('', '');
end;

procedure TestCheckEqualInt;
begin
  CheckEqual(Int64(42), Int64(42));
  CheckEqual(Int64(0), Int64(0));
  CheckEqual(Int64(-1), Int64(-1));
end;

procedure TestCheckEqualBool;
begin
  CheckEqual(True, True);
  CheckEqual(False, False);
end;

procedure TestFailCaught;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    Check(False, 'deliberate failure');
  except
    on E: EAssertionFailed do
      LCaught := True;
  end;
  Check(LCaught, 'Should have caught EAssertionFailed');
end;

begin
  T := TTestSuite.Create('nextpas.core.test');
  T.Test('Check pass', @TestCheckPass);
  T.Test('CheckEqual string', @TestCheckEqualStr);
  T.Test('CheckEqual int', @TestCheckEqualInt);
  T.Test('CheckEqual bool', @TestCheckEqualBool);
  T.Test('Fail is caught', @TestFailCaught);
  if not T.Run then Halt(1);
end.
