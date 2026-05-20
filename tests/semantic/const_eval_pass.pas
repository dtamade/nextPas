program Const_eval_pass;
const
  A = 10;
  B = 20;
  C = A + B;
  D = C * 2;
  E = D div 3;
  F = (A + B) * (C - D);
  MaxSize = 1024 * 1024;
  Greeting = 'Hello' + ' ' + 'World';
  IsLarge = MaxSize > 100000;
var
  X: Integer;
  S: string;
begin
  X := C;
  X := D;
  X := MaxSize;
  S := Greeting;
end.
