{$mode objfpc}{$H+}
program test_builtins_pass;

var
  Buf: array[0..15] of Byte;
  Buf2: array[0..15] of Byte;
  P: Pointer;
  I: LongInt;

begin
  { Test FillChar }
  FillChar(Buf, SizeOf(Buf), 0);

  { Test Move }
  Buf[0] := 42;
  Move(Buf, Buf2, SizeOf(Buf));

  { Test GetMem/FreeMem }
  P := nil;
  GetMem(P, 256);
  if not Assigned(P) then
    Halt(1);
  FillChar(P^, 256, 0);
  FreeMem(P);

  { Test Assigned on nil }
  P := nil;
  if Assigned(P) then
    Halt(2);

  WriteLn('OK');
end.
