{ objfpc}{+}
program hir_lowering_mixed_arith_pass;
var I,J: Integer; R: Real;
begin
  I:=5; J:=2;
  R:=I/J; if Abs(R-2.5)>0.001 then Halt(1);
  R:=I+J*0.5; if Abs(R-6.0)>0.001 then Halt(2);
  R:=(I+J)/2.0; if Abs(R-3.5)>0.001 then Halt(3);
end.
