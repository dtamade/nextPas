{$mode objfpc}{$H+}
program overload_method_pass;

{ 重载解析：方法重载 }

type
  TCalculator = class
    function Compute(A: Integer): Integer; overload;
    function Compute(A, B: Integer): Integer; overload;
    function Compute(const S: string): Integer; overload;
  end;

function TCalculator.Compute(A: Integer): Integer;
begin
  Compute := A * 2;
end;

function TCalculator.Compute(A, B: Integer): Integer;
begin
  Compute := A + B;
end;

function TCalculator.Compute(const S: string): Integer;
begin
  Compute := Length(S);
end;

var
  C: TCalculator;
  R: Integer;
begin
  C := TCalculator.Create;
  R := C.Compute(5);
  if R <> 10 then Halt(1);
  R := C.Compute(3, 4);
  if R <> 7 then Halt(2);
  R := C.Compute('hello');
  if R <> 5 then Halt(3);
end.
