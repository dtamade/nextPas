program qualified_type_name_pass;

{$mode objfpc}{$H+}

uses
  nextpas.core.fs.base;

{ Test: fully-qualified type names in parameter/return types }
function MapKind(AK: nextpas.core.fs.base.TFileType): LongInt;
begin
  Result := Ord(AK);
end;

var
  R: LongInt;
begin
  R := MapKind(nextpas.core.fs.base.ftRegular);
  if R <> Ord(nextpas.core.fs.base.ftRegular) then
    Halt(1);
end.
