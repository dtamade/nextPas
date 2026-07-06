{$mode objfpc}{$H+}
program overload_default_param_pass;

{ 重载解析：默认参数 }

function Greet(const Name: string; const Greeting: string = 'Hello'): string;
begin
  Greet := Greeting + ' ' + Name;
end;

var
  S: string;
begin
  S := Greet('World');
  if S <> 'Hello World' then Halt(1);

  S := Greet('World', 'Hi');
  if S <> 'Hi World' then Halt(2);
end.
