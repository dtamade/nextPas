{$mode objfpc}{$H+}
program test_record_methods_pass;

{ Tests for record type features: field access, nested records. }

uses
  SysUtils;

type
  TPoint = record
    X, Y: LongInt;
  end;

  TRect = record
    Origin: TPoint;
    Width, Height: LongInt;
  end;

var
  P: TPoint;
  R: TRect;

begin
  { Record field access }
  P.X := 3;
  P.Y := 4;
  if P.X <> 3 then Halt(1);
  if P.Y <> 4 then Halt(2);

  { Nested record }
  R.Origin.X := 10;
  R.Origin.Y := 20;
  R.Width := 5;
  R.Height := 3;
  if R.Origin.X <> 10 then Halt(3);
  if R.Origin.Y <> 20 then Halt(4);
  if R.Width <> 5 then Halt(5);
  if R.Height <> 3 then Halt(6);

  { Record assignment }
  P.X := 100;
  P.Y := 200;
  if P.X <> 100 then Halt(7);

  WriteLn('record_methods OK');
end.
