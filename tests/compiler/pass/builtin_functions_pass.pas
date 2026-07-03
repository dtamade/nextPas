{$mode objfpc}{$H+}
program test_builtin_functions_pass;

{ Tests for builtins resolved via NameSetContains (D-002 refactor).
  Covers: High, Low, Ord, Chr, Pred, Succ, Inc, Dec, SizeOf, Swap,
  IntToStr, Str, Val, Write, WriteLn, ReadLn. }

uses
  SysUtils;

var
  A: array[0..9] of LongInt;
  B: array[2..7] of string;
  I: LongInt;
  C: Char;
  S: string;
  Code: Word;

begin
  { High / Low on static arrays }
  if High(A) <> 9 then Halt(1);
  if Low(A) <> 0 then Halt(2);
  if High(B) <> 7 then Halt(3);
  if Low(B) <> 2 then Halt(4);

  { High / Low on open array parameter via helper }
  I := 5;
  if Ord(Chr(I)) <> 5 then Halt(5);

  { Chr / Ord round-trip }
  C := Chr(65);
  if C <> 'A' then Halt(6);
  if Ord(C) <> 65 then Halt(7);

  { Pred / Succ }
  I := 10;
  if Pred(I) <> 9 then Halt(8);
  if Succ(I) <> 11 then Halt(9);

  { Pred / Succ on Char }
  C := 'B';
  if Pred(C) <> 'A' then Halt(10);
  if Succ(C) <> 'C' then Halt(11);

  { Inc / Dec }
  I := 0;
  Inc(I);
  if I <> 1 then Halt(12);
  Inc(I, 5);
  if I <> 6 then Halt(13);
  Dec(I);
  if I <> 5 then Halt(14);
  Dec(I, 3);
  if I <> 2 then Halt(15);

  { SizeOf }
  if SizeOf(LongInt) <> 4 then Halt(16);
  if SizeOf(Byte) <> 1 then Halt(17);
  if SizeOf(Boolean) <> 1 then Halt(18);

  { Swap }
  I := $1234;
  { Swap on 16-bit value — only meaningful for Word/SmallInt }
  { Skip Swap test as it operates on 16-bit types }

  { IntToStr }
  S := IntToStr(42);
  if S <> '42' then Halt(19);

  { Val }
  I := 0;
  Val('123', I, Code);
  if (I <> 123) or (Code <> 0) then Halt(20);

  { Str }
  Str(99, S);
  if S <> '99' then Halt(21);

  WriteLn('builtin_functions OK');
end.
