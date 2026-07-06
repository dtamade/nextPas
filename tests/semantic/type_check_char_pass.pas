{ objfpc}{+}
program type_check_char_pass;
var C: Char; I: Integer;
begin
  C := 'A'; if C <> 'A' then Halt(1);
  I := Ord(C); if I <> 65 then Halt(2);
  C := Chr(66); if C <> 'B' then Halt(3);
end.
