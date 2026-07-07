{ objfpc}{+}
program type_check_typealias_pass;
type TAge=Integer; TName=string;
var A: TAge; N: TName;
begin
  A:=25; if A<>25 then Halt(1);
  N:='John'; if N<>'John' then Halt(2);
  A:=Integer(30); if A<>30 then Halt(3);
end.
