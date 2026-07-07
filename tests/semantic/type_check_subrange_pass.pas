{$mode objfpc}{$H+}
program type_check_subrange_pass;

{ 类型检查：子界类型 }

type
  TAge = 0..150;
  TLetter = 'A'..'Z';

var
  Age: TAge;
  Ch: TLetter;
begin
  Age := 25;
  if Age <> 25 then Halt(1);
  Age := 0;
  if Age <> 0 then Halt(2);
  Age := 150;
  if Age <> 150 then Halt(3);

  Ch := 'A';
  if Ch <> 'A' then Halt(4);
  Ch := 'Z';
  if Ch <> 'Z' then Halt(5);
end.
