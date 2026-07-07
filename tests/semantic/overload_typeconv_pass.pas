{$mode objfpc}{$H+}
program overload_typeconv_pass;

{ 重载解析：类型转换重载 }

function ToStr(I: Integer): string;
begin
  Str(I, ToStr);
end;

function ToStr(R: Real): string;
begin
  Str(R:0:2, ToStr);
end;

var
  S: string;
begin
  S := ToStr(42);
  if S <> '42' then Halt(1);
  S := ToStr(3.14);
  { 只需要能编译运行即可 }
end.
