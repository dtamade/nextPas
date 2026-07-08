{$mode objfpc}{$H+}
program test_exception_handling_pass;
uses SysUtils;

var
  TestNum: Integer;

procedure Check(Condition: Boolean; const Msg: string);
begin
  if not Condition then
  begin
    WriteLn('FAIL: ', Msg);
    Halt(1);
  end;
end;

{ Test 1: Basic try/except }
procedure TestBasicExcept;
var
  Caught: Boolean;
begin
  Caught := False;
  try
    raise Exception.Create('test error');
  except
    on E: Exception do
    begin
      Caught := True;
      Check(E.Message = 'test error', 'exception message');
    end;
  end;
  Check(Caught, 'exception caught');
end;

{ Test 2: try/finally ensures cleanup }
procedure TestFinally;
var
  Cleaned: Boolean;
begin
  Cleaned := False;
  try
    Cleaned := False;
  finally
    Cleaned := True;
  end;
  Check(Cleaned, 'finally executed');
end;

{ Test 3: try/finally with exception }
procedure TestFinallyWithExcept;
var
  Cleaned: Boolean;
  Caught: Boolean;
begin
  Cleaned := False;
  Caught := False;
  try
    try
      raise Exception.Create('inner error');
    finally
      Cleaned := True;
    end;
  except
    Caught := True;
  end;
  Check(Cleaned, 'finally executed before except');
  Check(Caught, 'exception propagated after finally');
end;

{ Test 4: Nested try/except }
procedure TestNestedTry;
var
  OuterCaught, InnerCaught: Boolean;
begin
  OuterCaught := False;
  InnerCaught := False;
  try
    try
      raise Exception.Create('inner');
    except
      InnerCaught := True;
      raise Exception.Create('outer');
    end;
  except
    OuterCaught := True;
  end;
  Check(InnerCaught, 'inner except');
  Check(OuterCaught, 'outer except');
end;

{ Test 5: Exception in function with result }
function SafeDiv(A, B: Integer): Integer;
begin
  try
    if B = 0 then
      raise EDivByZero.Create('division by zero');
    Result := A div B;
  except
    on E: EDivByZero do
      Result := -1;
  end;
end;

{ Test 6: Exception class hierarchy }
procedure TestExceptionHierarchy;
var
  Caught: Boolean;
begin
  Caught := False;
  try
    raise EIntOverflow.Create('overflow');
  except
    on E: Exception do
    begin
      Caught := True;
      Check(E is EIntOverflow, 'exception type check');
    end;
  end;
  Check(Caught, 'hierarchy exception caught');
end;

begin
  TestNum := 0;

  Inc(TestNum); WriteLn('Test ', TestNum, ': Basic except');
  TestBasicExcept;

  Inc(TestNum); WriteLn('Test ', TestNum, ': Finally');
  TestFinally;

  Inc(TestNum); WriteLn('Test ', TestNum, ': Finally with except');
  TestFinallyWithExcept;

  Inc(TestNum); WriteLn('Test ', TestNum, ': Nested try');
  TestNestedTry;

  Inc(TestNum); WriteLn('Test ', TestNum, ': Safe div');
  Check(SafeDiv(10, 2) = 5, '10 div 2');
  Check(SafeDiv(10, 0) = -1, '10 div 0');

  Inc(TestNum); WriteLn('Test ', TestNum, ': Exception hierarchy');
  TestExceptionHierarchy;

  WriteLn('All exception tests passed');
end.
