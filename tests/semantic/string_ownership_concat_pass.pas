{$mode objfpc}{$H+}
program string_ownership_concat_pass;

{ 字符串所有权：拼接操作 }

var
  S1, S2, S3: string;
begin
  S1 := 'Hello';
  S2 := 'World';
  S3 := S1 + ' ' + S2;
  if S3 <> 'Hello World' then Halt(1);

  S1 := S1 + '!';
  if S1 <> 'Hello!' then Halt(2);

  S3 := '';
  S3 := S3 + 'A';
  S3 := S3 + 'B';
  S3 := S3 + 'C';
  if S3 <> 'ABC' then Halt(3);
end.
