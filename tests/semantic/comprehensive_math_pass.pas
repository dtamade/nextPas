{ objfpc}{+}
program comprehensive_math_pass;
var I,J: Integer; R: Real;
begin
  I:=Abs(-5); if I<>5 then Halt(1);
  I:=Sqr(6); if I<>36 then Halt(2);
  J:=10; I:=Pred(J); if I<>9 then Halt(3);
  I:=Succ(J); if I<>11 then Halt(4);
  I:=10; Dec(I); if I<>9 then Halt(5);
  Inc(I,5); if I<>14 then Halt(6);
end.
