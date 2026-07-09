{$mode objfpc}{$H+}
program test_raii_class_auto_free_pass;

{ Tests that class local variables get automatic Free at scope exit.
  The compiler should generate object-free-runtime HIR nodes for
  class variables at procedure/function exit points. }

type
  TMyObj = class
    Value: Integer;
    constructor Create(AValue: Integer);
  end;

constructor TMyObj.Create(AValue: Integer);
begin
  Value := AValue;
end;

function TestSimple: Integer;
var
  Obj: TMyObj;
begin
  Obj := TMyObj.Create(42);
  Result := Obj.Value;
  { Obj should be freed automatically at scope exit }
end;

function TestMultiple: Integer;
var
  A, B: TMyObj;
begin
  A := TMyObj.Create(10);
  B := TMyObj.Create(20);
  Result := A.Value + B.Value;
  { Both A and B should be freed at scope exit }
end;

var
  TestResult: Integer;
begin
  TestResult := TestSimple;
  if TestResult <> 42 then Halt(1);

  TestResult := TestMultiple;
  if TestResult <> 30 then Halt(2);

  WriteLn('raii_class_auto_free OK');
end.
