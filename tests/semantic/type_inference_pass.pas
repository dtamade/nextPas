program Type_inference_pass;
type
  TColor = (clRed, clGreen, clBlue);
const
  Pi = 3;
  Greeting = 'hello';
function Square(X: Integer): Integer;
begin
  Square := X * X;
end;
function IsPositive(X: Integer): Boolean;
begin
  IsPositive := X > 0;
end;
var
  I: Integer;
  S: string;
  B: Boolean;
  C: TColor;
begin
  I := 42;
  I := Square(I);
  S := Greeting;
  B := IsPositive(I);
  B := I > 0;
  C := clRed;
  I := Pi;
end.
