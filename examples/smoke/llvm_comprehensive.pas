program Llvm_comprehensive;
type
  TResult = record
    Value: Integer;
    IsValid: Integer;
  end;

function Abs(X: Integer): Integer;
begin
  if X < 0 then
    Abs := 0 - X
  else
    Abs := X;
end;

function Clamp(X, Lo, Hi: Integer): Integer;
begin
  if X < Lo then
    Clamp := Lo
  else if X > Hi then
    Clamp := Hi
  else
    Clamp := X;
end;

function SumRange(A, B: Integer): Integer;
var
  I: Integer;
begin
  SumRange := 0;
  for I := A to B do
    SumRange := SumRange + I;
end;

var
  R: TResult;
  X: Integer;
begin
  R.Value := SumRange(1, 10);
  R.IsValid := 1;
  X := Clamp(R.Value, 0, 100);
  X := Abs(X - 97);
  Halt(X);
end.
