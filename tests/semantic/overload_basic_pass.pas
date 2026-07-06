program overload_basic_pass;

function Add(A, B: Integer): Integer;
begin
  Add := A + B;
end;

function Add(A, B: Double): Double;
begin
  Add := A + B;
end;

function Concat(A, B: string): string;
begin
  Concat := A + B;
end;

var
  I, J: Integer;
  D, E: Double;
  S1, S2: string;
  R: Integer;
  RD: Double;
  RS: string;
begin
  I := 10;
  J := 20;
  D := 1.5;
  E := 2.5;
  S1 := 'hello';
  S2 := ' world';
  R := Add(I, J);
  RD := Add(D, E);
  RS := Concat(S1, S2);
end.
