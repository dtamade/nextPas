{$mode objfpc}{$H+}
program test_implicit_system_imported_unit_pass;

uses
  implicit_system_imported_unit_support;

var
  Buffer: TImplicitSystemBuffer;
  Source: array[0..2] of Byte;
begin
  Source[0] := 10;
  Source[1] := 20;
  Source[2] := 30;

  Buffer := MakeBuffer(@Source[0], 3);
  if Buffer.Len <> 3 then
    Halt(1);
  if Buffer.Data = nil then
    Halt(2);
  if Buffer.Data^ <> 10 then
    Halt(3);

  WriteLn('implicit_system_imported_unit OK');
end.
