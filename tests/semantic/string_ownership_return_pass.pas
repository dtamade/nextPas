{$mode objfpc}{$H+}
program string_ownership_return_pass;

{ 字符串所有权：函数返回字符串 }

function MakeGreeting(const Name: string): string;
begin
  MakeGreeting := 'Hello, ' + Name + '!';
end;

function Concat3(const A, B, C: string): string;
begin
  Concat3 := A + B + C;
end;

var
  S: string;
begin
  S := MakeGreeting('World');
  if S <> 'Hello, World!' then Halt(1);

  S := Concat3('a', 'b', 'c');
  if S <> 'abc' then Halt(2);

  S := MakeGreeting(Concat3('X', 'Y', 'Z'));
  if S <> 'Hello, XYZ!' then Halt(3);
end.
