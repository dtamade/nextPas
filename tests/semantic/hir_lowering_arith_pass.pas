{ objfpc}{+}
program hir_lowering_arith_pass;
var A,B,R: Integer;
begin
  A:=10; B:=3;
  R:=A+B; if R<>13 then Halt(1);
  R:=A-B; if R<>7 then Halt(2);
  R:=A*B; if R<>30 then Halt(3);
  R:=A div B; if R<>3 then Halt(4);
  R:=A mod B; if R<>1 then Halt(5);
end.
