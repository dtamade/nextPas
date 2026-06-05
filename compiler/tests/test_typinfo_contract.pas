program test_typinfo_contract;

{$mode objfpc}{$H+}

uses
  TypInfo;

var
  TypeInfoPtr: PTypeInfo;
  SourceValues: array[0..1] of AnsiString;
  DestValues: array[0..1] of AnsiString;
begin
  TypeInfoPtr := Pointer(TypeInfo(AnsiString));
  if TypeInfoPtr = nil then
    Halt(1);
  if TypeInfoPtr^.Kind <> tkAString then
    Halt(2);

  InitializeArray(@SourceValues[0], TypeInfoPtr, Length(SourceValues));
  InitializeArray(@DestValues[0], TypeInfoPtr, Length(DestValues));
  try
    SourceValues[0] := 'left';
    SourceValues[1] := 'right';
    CopyArray(@DestValues[0], @SourceValues[0], TypeInfoPtr, Length(SourceValues));
    if DestValues[0] <> 'left' then
      Halt(3);
    if DestValues[1] <> 'right' then
      Halt(4);
  finally
    FinalizeArray(@SourceValues[0], TypeInfoPtr, Length(SourceValues));
    FinalizeArray(@DestValues[0], TypeInfoPtr, Length(DestValues));
  end;
end.
