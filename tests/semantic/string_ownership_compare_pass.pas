{$mode objfpc}{$H+}
program string_ownership_compare_pass;

{ 字符串所有权：比较操作 }

var
  S1, S2: string;
  B: Boolean;
begin
  S1 := 'abc';
  S2 := 'abc';
  B := S1 = S2;
  if not B then Halt(1);

  S2 := 'def';
  B := S1 <> S2;
  if not B then Halt(2);

  S1 := 'aaa';
  S2 := 'bbb';
  B := S1 < S2;
  if not B then Halt(3);

  S1 := 'zzz';
  S2 := 'aaa';
  B := S1 > S2;
  if not B then Halt(4);
end.
