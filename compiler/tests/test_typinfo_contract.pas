program test_typinfo_contract;

{$mode objfpc}{$H+}

uses
  nextpas.core.system.typinfo;

type
  TStringSlots = array[0..1] of AnsiString;
  TInterfaceSlots = array[0..1] of IInterface;

  ISystemTypInfoContractProbe = interface
    ['{2067BC61-96D0-4DF4-B40E-D07AAB99E218}']
    function Value: Integer;
  end;

  TSystemTypInfoContractProbe = class(TInterfacedObject, ISystemTypInfoContractProbe)
  private
    FValue: Integer;
  public
    constructor Create(AValue: Integer);
    function Value: Integer;
  end;

constructor TSystemTypInfoContractProbe.Create(AValue: Integer);
begin
  inherited Create;
  FValue := AValue;
end;

function TSystemTypInfoContractProbe.Value: Integer;
begin
  Result := FValue;
end;

var
  TypeInfoPtr: PTypeInfo;
  SourceValues: ^TStringSlots;
  DestValues: ^TStringSlots;
  InterfaceSourceValues: ^TInterfaceSlots;
  InterfaceDestValues: ^TInterfaceSlots;
  SourceInitialized: Boolean;
  DestInitialized: Boolean;
  InterfaceSourceInitialized: Boolean;
  InterfaceDestInitialized: Boolean;
  FirstInterfaceValue: ISystemTypInfoContractProbe;
  SecondInterfaceValue: ISystemTypInfoContractProbe;
  ReadBackInterfaceValue: ISystemTypInfoContractProbe;

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
  InterfaceSourceValues := nil;
  InterfaceDestValues := nil;
  InterfaceSourceInitialized := False;
  InterfaceDestInitialized := False;
  FirstInterfaceValue := nil;
  SecondInterfaceValue := nil;
  ReadBackInterfaceValue := nil;
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

    { compiler TypInfo interface reference lifecycle contract }
    GetMem(InterfaceSourceValues, SizeOf(TInterfaceSlots));
    GetMem(InterfaceDestValues, SizeOf(TInterfaceSlots));
    InitializeArray(InterfaceSourceValues, TypeInfo(ISystemTypInfoContractProbe), Length(InterfaceSourceValues^));
    InterfaceSourceInitialized := True;
    InitializeArray(InterfaceDestValues, TypeInfo(ISystemTypInfoContractProbe), Length(InterfaceDestValues^));
    InterfaceDestInitialized := True;

    FirstInterfaceValue := TSystemTypInfoContractProbe.Create(11);
    SecondInterfaceValue := TSystemTypInfoContractProbe.Create(22);
    InterfaceSourceValues^[0] := FirstInterfaceValue;
    InterfaceSourceValues^[1] := SecondInterfaceValue;
    InterfaceDestValues^[0] := TSystemTypInfoContractProbe.Create(1);
    InterfaceDestValues^[1] := TSystemTypInfoContractProbe.Create(2);

    CopyArray(InterfaceDestValues, InterfaceSourceValues, TypeInfo(ISystemTypInfoContractProbe), Length(InterfaceSourceValues^));
    ReadBackInterfaceValue := InterfaceDestValues^[0] as ISystemTypInfoContractProbe;
    if ReadBackInterfaceValue.Value <> 11 then
      Halt(5);
    ReadBackInterfaceValue := InterfaceDestValues^[1] as ISystemTypInfoContractProbe;
    if ReadBackInterfaceValue.Value <> 22 then
      Halt(6);
    ReadBackInterfaceValue := nil;
  finally
    ReadBackInterfaceValue := nil;
    if InterfaceDestInitialized then
      FinalizeArray(InterfaceDestValues, TypeInfo(ISystemTypInfoContractProbe), Length(InterfaceDestValues^));
    if InterfaceSourceInitialized then
      FinalizeArray(InterfaceSourceValues, TypeInfo(ISystemTypInfoContractProbe), Length(InterfaceSourceValues^));
    if InterfaceDestValues <> nil then
      FreeMem(InterfaceDestValues);
    if InterfaceSourceValues <> nil then
      FreeMem(InterfaceSourceValues);
    SecondInterfaceValue := nil;
    FirstInterfaceValue := nil;
    if DestInitialized then
      FinalizeArray(DestValues, TypeInfoPtr, Length(DestValues^));
    if SourceInitialized then
      FinalizeArray(SourceValues, TypeInfoPtr, Length(SourceValues^));
    FreeMem(DestValues);
    FreeMem(SourceValues);
  end;
end.
