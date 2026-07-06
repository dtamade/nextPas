{ objfpc}{+}
program type_check_bool_pass;
var B: Boolean;
begin
  B := True; if not B then Halt(1);
  B := False; if B then Halt(2);
  B := not True; if B then Halt(3);
  B := True and True; if not B then Halt(4);
  B := False or True; if not B then Halt(5);
end.
