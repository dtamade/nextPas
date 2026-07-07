{$mode objfpc}{$H+}
program type_check_const_pass;

{ 类型检查：常量 }

const
  MAX = 100;
  PI = 3.14159;
  GREETING = 'Hello';

var
  I: Integer;
  R: Real;
  S: string;
begin
  I := MAX;
  if I <> 100 then Halt(1);
  R := PI;
  if Abs(R - 3.14159) > 0.0001 then Halt(2);
  S := GREETING;
  if S <> 'Hello' then Halt(3);
end.
