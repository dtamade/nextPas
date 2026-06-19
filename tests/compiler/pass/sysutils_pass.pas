{$mode objfpc}{$H+}
program test_sysutils_pass;

uses
  SysUtils, Classes;

var
  SL: TStringList;
  R: Boolean;
  N: Integer;
  S: string;
begin
  { Test string functions }
  R := SameText('hello', 'HELLO');
  if not R then Halt(1);
  S := Trim('  test  ');
  if S <> 'test' then Halt(2);
  S := LowerCase('ABC');
  if S <> 'abc' then Halt(3);
  S := UpperCase('abc');
  if S <> 'ABC' then Halt(4);

  { Test path functions }
  S := ExtractFileName('/a/b/c.txt');
  if S <> 'c.txt' then Halt(5);
  S := ExtractFileDir('/a/b/c.txt');
  if S <> '/a/b' then Halt(6);
  S := ExtractFileExt('/a/b/c.txt');
  if S <> '.txt' then Halt(7);

  { Test type conversions }
  S := IntToStr(42);
  if S <> '42' then Halt(8);
  N := StrToInt('123');
  if N <> 123 then Halt(9);
  N := StrToIntDef('abc', 99);
  if N <> 99 then Halt(10);
  N := StrToInt64Def('456', 0);
  if N <> 456 then Halt(11);

  { Test StringReplace }
  S := StringReplace('hello world', 'world', 'pascal', []);
  if S <> 'hello pascal' then Halt(12);

  { Test TStringList }
  SL := TStringList.Create;
  try
    SL.Add('line1');
    SL.Add('line2');
    SL.Add('line3');
    if SL.Count <> 3 then Halt(13);
    if SL[0] <> 'line1' then Halt(14);
    if SL.IndexOf('line2') <> 1 then Halt(15);
    SL.Insert(1, 'inserted');
    if SL[1] <> 'inserted' then Halt(16);
    if SL.Count <> 4 then Halt(17);
    SL.Delete(1);
    if SL.Count <> 3 then Halt(18);
    if SL[1] <> 'line2' then Halt(19);
  finally
    SL.Free;
  end;

  WriteLn('OK');
end.
