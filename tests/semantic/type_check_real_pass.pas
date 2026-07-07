{ objfpc}{+}
program type_check_real_pass;
var R: Real;
begin
  R := 1.5 + 2.5; if Abs(R - 4.0) > 0.001 then Halt(1);
  R := 3.0 * 4.0; if Abs(R - 12.0) > 0.001 then Halt(2);
  R := 10.0 / 4.0; if Abs(R - 2.5) > 0.001 then Halt(3);
end.
