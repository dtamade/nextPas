program test_typinfo_contract;

{$mode objfpc}{$H+}

uses
  nextpas.core.system.typinfo;

type
  TStringSlots = array[0..1] of AnsiString;

var
  TypeInfoPtr: PTypeInfo;
  SourceValues: ^TStringSlots;
  DestValues: ^TStringSlots;
  SourceInitialized: Boolean;
  DestInitialized: Boolean;

begin
  TypeInfoPtr := Pointer(TypeInfo(AnsiString));
  if TypeInfoPtr = nil then
    Halt(1);
  if TypeInfoPtr^.Kind <> tkAString then
    Halt(2);

  GetMem(SourceValues, SizeOf(TStringSlots));
  GetMem(DestValues, SizeOf(TStringSlots));
  SourceInitialized := False;
  DestInitialized := False;
  try
    InitializeArray(SourceValues, TypeInfoPtr, Length(SourceValues^));
    SourceInitialized := True;
    InitializeArray(DestValues, TypeInfoPtr, Length(DestValues^));
    DestInitialized := True;

    SourceValues^[0] := 'left';
    SourceValues^[1] := 'right';
    CopyArray(DestValues, SourceValues, TypeInfoPtr, Length(SourceValues^));
    if DestValues^[0] <> 'left' then
      Halt(3);
    if DestValues^[1] <> 'right' then
      Halt(4);
  finally
    if DestInitialized then
      FinalizeArray(DestValues, TypeInfoPtr, Length(DestValues^));
    if SourceInitialized then
      FinalizeArray(SourceValues, TypeInfoPtr, Length(SourceValues^));
    FreeMem(DestValues);
    FreeMem(SourceValues);
  end;
end.
