{$mode objfpc}{$H+}
program test_strings_pass;
uses SysUtils;

var
  S1, S2, S3: string;
  I: LongInt;
begin
  { basic string ops }
  S1 := 'Hello';
  S2 := 'World';
  S3 := S1 + ' World';
  if S3 <> 'Hello World' then Halt(1);

  { string length }
  if Length(S3) <> 11 then Halt(2);

  { string comparison }
  if S1 = S2 then Halt(3);
  if S1 <> 'Hello' then Halt(4);

  { Copy/Pos }
  if Copy(S3, 1, 5) <> 'Hello' then Halt(5);
  if Pos('World', S3) <> 7 then Halt(6);

  { IntToStr }
  I := 42;
  S1 := IntToStr(I);
  if S1 <> '42' then Halt(7);

  { UpperCase/LowerCase }
  S1 := 'Hello';
  S2 := UpperCase(S1);
  if S2 <> 'HELLO' then Halt(8);
  S2 := LowerCase(S1);
  if S2 <> 'hello' then Halt(9);

  WriteLn('strings OK');
end.
