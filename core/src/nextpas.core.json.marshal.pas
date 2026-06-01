unit nextpas.core.json.marshal;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view,
  nextpas.core.reflect.base,
  nextpas.core.reflect.intf,
  nextpas.core.json.types,
  nextpas.core.json.value,
  nextpas.core.json.parser;

function JsonMarshal(ARegistry: ITypeRegistry; ATypeDef: PTypeDef; AData: Pointer): string;
function JsonUnmarshal(ARegistry: ITypeRegistry; ATypeDef: PTypeDef;
  const AValue: TJsonValue; AData: Pointer): Boolean;
function JsonUnmarshalStr(ARegistry: ITypeRegistry; ATypeDef: PTypeDef;
  const AJson: string; AData: Pointer): Boolean;

implementation

uses
  nextpas.core.text.builder,
  nextpas.core.json.writer,
  nextpas.core.mem.default,
  nextpas.core.reflect,
  nextpas.core.reflect.dynarray;

type
  TJsonMarshalVisitor = class(TBaseTypeVisitor)
  private
    FWriter: ^TJsonWriter;
    FRegistry: ITypeRegistry;
    procedure WriteValue(AKind: TFieldKind; APtr: Pointer; ASubType: PTypeDef);
  public
    function ShouldVisit(const AField: TFieldDef): Boolean; override;
    procedure BeginType(ATypeDef: PTypeDef; AData: Pointer); override;
    procedure EndType(ATypeDef: PTypeDef; AData: Pointer); override;
    procedure VisitBool(const AField: TFieldDef; APtr: PBoolean); override;
    procedure VisitInt32(const AField: TFieldDef; APtr: PInt32); override;
    procedure VisitInt64(const AField: TFieldDef; APtr: PInt64); override;
    procedure VisitUInt32(const AField: TFieldDef; APtr: PDWord); override;
    procedure VisitFloat32(const AField: TFieldDef; APtr: PSingle); override;
    procedure VisitFloat64(const AField: TFieldDef; APtr: PDouble); override;
    procedure VisitString(const AField: TFieldDef; APtr: PString); override;
    procedure VisitRecord(const AField: TFieldDef; APtr: Pointer; ASubType: PTypeDef); override;
    procedure VisitDynArray(const AField: TFieldDef; AArrayPtr: PPointer;
      AElementType: PTypeDef); override;
  end;

  TJsonUnmarshalVisitor = class(TBaseTypeVisitor)
  private
    FValue: TJsonValue;
    FRegistry: ITypeRegistry;
    FSuccess: Boolean;
    function ReadValue(const AValue: TJsonValue; AKind: TFieldKind;
      APtr: Pointer; ASubType: PTypeDef): Boolean;
  public
    function ShouldVisit(const AField: TFieldDef): Boolean; override;
    procedure BeginType(ATypeDef: PTypeDef; AData: Pointer); override;
    procedure VisitBool(const AField: TFieldDef; APtr: PBoolean); override;
    procedure VisitInt32(const AField: TFieldDef; APtr: PInt32); override;
    procedure VisitInt64(const AField: TFieldDef; APtr: PInt64); override;
    procedure VisitUInt32(const AField: TFieldDef; APtr: PDWord); override;
    procedure VisitFloat32(const AField: TFieldDef; APtr: PSingle); override;
    procedure VisitFloat64(const AField: TFieldDef; APtr: PDouble); override;
    procedure VisitString(const AField: TFieldDef; APtr: PString); override;
    procedure VisitRecord(const AField: TFieldDef; APtr: Pointer; ASubType: PTypeDef); override;
    procedure VisitDynArray(const AField: TFieldDef; AArrayPtr: PPointer;
      AElementType: PTypeDef); override;
  end;

{ TJsonMarshalVisitor }

function TJsonMarshalVisitor.ShouldVisit(const AField: TFieldDef): Boolean;
begin
  Result := not (ffTransient in AField.Flags);
end;

procedure TJsonMarshalVisitor.BeginType(ATypeDef: PTypeDef; AData: Pointer);
begin
  FWriter^.BeginObject;
end;

procedure TJsonMarshalVisitor.EndType(ATypeDef: PTypeDef; AData: Pointer);
begin
  FWriter^.EndObject;
end;

procedure TJsonMarshalVisitor.WriteValue(AKind: TFieldKind; APtr: Pointer;
  ASubType: PTypeDef);
begin
  case AKind of
    fkBool:
      FWriter^.Bool(PBoolean(APtr)^);
    fkInt8:
      FWriter^.Int(PInt8(APtr)^);
    fkInt16:
      FWriter^.Int(PInt16(APtr)^);
    fkInt32:
      FWriter^.Int(PInt32(APtr)^);
    fkInt64:
      FWriter^.Int(PInt64(APtr)^);
    fkUInt8:
      FWriter^.Int(PByte(APtr)^);
    fkUInt16:
      FWriter^.Int(PWord(APtr)^);
    fkUInt32:
      FWriter^.Int(Int64(PDWord(APtr)^));
    fkUInt64:
      FWriter^.UInt(PUInt64(APtr)^);
    fkFloat32:
      FWriter^.Float(PSingle(APtr)^);
    fkFloat64:
      FWriter^.Float(PDouble(APtr)^);
    fkString:
      FWriter^.Str(PString(APtr)^);
    fkRecord:
      begin
        if ASubType <> nil then
          FRegistry.Visit(ASubType, APtr, Self as ITypeVisitor)
        else
          FWriter^.Null;
      end;
  else
    FWriter^.Null;
  end;
end;

procedure TJsonMarshalVisitor.VisitBool(const AField: TFieldDef; APtr: PBoolean);
begin
  FWriter^.Key(AField.Name);
  WriteValue(AField.Kind, APtr, nil);
end;

procedure TJsonMarshalVisitor.VisitInt32(const AField: TFieldDef; APtr: PInt32);
begin
  FWriter^.Key(AField.Name);
  WriteValue(AField.Kind, APtr, nil);
end;

procedure TJsonMarshalVisitor.VisitInt64(const AField: TFieldDef; APtr: PInt64);
begin
  FWriter^.Key(AField.Name);
  WriteValue(AField.Kind, APtr, nil);
end;

procedure TJsonMarshalVisitor.VisitUInt32(const AField: TFieldDef; APtr: PDWord);
begin
  FWriter^.Key(AField.Name);
  WriteValue(AField.Kind, APtr, nil);
end;

procedure TJsonMarshalVisitor.VisitFloat32(const AField: TFieldDef; APtr: PSingle);
begin
  FWriter^.Key(AField.Name);
  WriteValue(AField.Kind, APtr, nil);
end;

procedure TJsonMarshalVisitor.VisitFloat64(const AField: TFieldDef; APtr: PDouble);
begin
  FWriter^.Key(AField.Name);
  WriteValue(AField.Kind, APtr, nil);
end;

procedure TJsonMarshalVisitor.VisitString(const AField: TFieldDef; APtr: PString);
begin
  FWriter^.Key(AField.Name);
  WriteValue(AField.Kind, APtr, nil);
end;

procedure TJsonMarshalVisitor.VisitRecord(const AField: TFieldDef; APtr: Pointer; ASubType: PTypeDef);
begin
  FWriter^.Key(AField.Name);
  WriteValue(AField.Kind, APtr, ASubType);
end;

procedure TJsonMarshalVisitor.VisitDynArray(const AField: TFieldDef;
  AArrayPtr: PPointer; AElementType: PTypeDef);
var
  LArray: Pointer;
  LLen: SizeInt;
  LIdx: SizeInt;
  LElemPtr: Pointer;
begin
  FWriter^.Key(AField.Name);
  if (AArrayPtr = nil) or (AField.ElementSize = 0) then
  begin
    FWriter^.Null;
    Exit;
  end;

  LArray := AArrayPtr^;
  LLen := DynArrayGetLength(LArray);
  FWriter^.BeginArray;
  for LIdx := 0 to LLen - 1 do
  begin
    LElemPtr := DynArrayElementPtr(LArray, LIdx, AField.ElementSize);
    if LElemPtr <> nil then
      WriteValue(AField.ElementKind, LElemPtr, AElementType)
    else
      FWriter^.Null;
  end;
  FWriter^.EndArray;
end;

{ TJsonUnmarshalVisitor }

function TJsonUnmarshalVisitor.ShouldVisit(const AField: TFieldDef): Boolean;
begin
  Result := FSuccess and not (ffTransient in AField.Flags);
end;

procedure TJsonUnmarshalVisitor.BeginType(ATypeDef: PTypeDef; AData: Pointer);
begin
  if not FValue.IsObject then
    FSuccess := False;
end;

function TJsonUnmarshalVisitor.ReadValue(const AValue: TJsonValue;
  AKind: TFieldKind; APtr: Pointer; ASubType: PTypeDef): Boolean;
var
  LVal: Int64;
  LSaved: TJsonValue;
  LSavedSuccess: Boolean;
begin
  Result := False;
  if APtr = nil then
    Exit;

  case AKind of
    fkBool:
      begin
        if not AValue.IsBool then Exit;
        PBoolean(APtr)^ := AValue.AsBool;
      end;
    fkInt8:
      begin
        if not (AValue.IsInt or AValue.IsReal) then Exit;
        PInt8(APtr)^ := Int8(AValue.AsInt);
      end;
    fkInt16:
      begin
        if not (AValue.IsInt or AValue.IsReal) then Exit;
        PInt16(APtr)^ := Int16(AValue.AsInt);
      end;
    fkInt32:
      begin
        if not (AValue.IsInt or AValue.IsReal) then Exit;
        PInt32(APtr)^ := Int32(AValue.AsInt);
      end;
    fkInt64:
      begin
        if not (AValue.IsInt or AValue.IsReal) then Exit;
        PInt64(APtr)^ := AValue.AsInt;
      end;
    fkUInt8:
      begin
        if not (AValue.IsInt or AValue.IsReal) then Exit;
        LVal := AValue.AsInt;
        PByte(APtr)^ := Byte(LVal);
      end;
    fkUInt16:
      begin
        if not (AValue.IsInt or AValue.IsReal) then Exit;
        LVal := AValue.AsInt;
        PWord(APtr)^ := Word(LVal);
      end;
    fkUInt32:
      begin
        if not (AValue.IsInt or AValue.IsReal) then Exit;
        LVal := AValue.AsInt;
        PDWord(APtr)^ := DWord(LVal);
      end;
    fkUInt64:
      begin
        if not (AValue.IsInt or AValue.IsReal) then Exit;
        PUInt64(APtr)^ := UInt64(AValue.AsInt);
      end;
    fkFloat32:
      begin
        if not (AValue.IsReal or AValue.IsInt) then Exit;
        PSingle(APtr)^ := Single(AValue.AsFloat);
      end;
    fkFloat64:
      begin
        if not (AValue.IsReal or AValue.IsInt) then Exit;
        PDouble(APtr)^ := AValue.AsFloat;
      end;
    fkString:
      begin
        if not AValue.IsStr then Exit;
        PString(APtr)^ := AValue.AsStr.ToString;
      end;
    fkRecord:
      begin
        if (ASubType = nil) or (not AValue.IsObject) then Exit;
        LSaved := FValue;
        LSavedSuccess := FSuccess;
        FValue := AValue;
        FSuccess := True;
        FRegistry.Visit(ASubType, APtr, Self as ITypeVisitor);
        Result := FSuccess;
        FValue := LSaved;
        FSuccess := LSavedSuccess;
        Exit;
      end;
  else
    Exit;
  end;
  Result := True;
end;

procedure TJsonUnmarshalVisitor.VisitBool(const AField: TFieldDef; APtr: PBoolean);
var V: TJsonValue;
begin
  V := FValue.ObjectGet(AField.Name);
  if V.IsValid then
    ReadValue(V, AField.Kind, APtr, nil);
end;

procedure TJsonUnmarshalVisitor.VisitInt32(const AField: TFieldDef; APtr: PInt32);
var V: TJsonValue;
begin
  V := FValue.ObjectGet(AField.Name);
  if V.IsValid then
    ReadValue(V, AField.Kind, APtr, nil);
end;

procedure TJsonUnmarshalVisitor.VisitInt64(const AField: TFieldDef; APtr: PInt64);
var V: TJsonValue;
begin
  V := FValue.ObjectGet(AField.Name);
  if V.IsValid then
    ReadValue(V, AField.Kind, APtr, nil);
end;

procedure TJsonUnmarshalVisitor.VisitUInt32(const AField: TFieldDef; APtr: PDWord);
var V: TJsonValue;
begin
  V := FValue.ObjectGet(AField.Name);
  if V.IsValid then
    ReadValue(V, AField.Kind, APtr, nil);
end;

procedure TJsonUnmarshalVisitor.VisitFloat32(const AField: TFieldDef; APtr: PSingle);
var V: TJsonValue;
begin
  V := FValue.ObjectGet(AField.Name);
  if V.IsValid then
    ReadValue(V, AField.Kind, APtr, nil);
end;

procedure TJsonUnmarshalVisitor.VisitFloat64(const AField: TFieldDef; APtr: PDouble);
var V: TJsonValue;
begin
  V := FValue.ObjectGet(AField.Name);
  if V.IsValid then
    ReadValue(V, AField.Kind, APtr, nil);
end;

procedure TJsonUnmarshalVisitor.VisitString(const AField: TFieldDef; APtr: PString);
var V: TJsonValue;
begin
  V := FValue.ObjectGet(AField.Name);
  if V.IsValid then
    ReadValue(V, AField.Kind, APtr, nil);
end;

procedure TJsonUnmarshalVisitor.VisitRecord(const AField: TFieldDef; APtr: Pointer; ASubType: PTypeDef);
var V: TJsonValue; LSaved: TJsonValue;
begin
  if ASubType = nil then Exit;
  V := FValue.ObjectGet(AField.Name);
  if not V.IsObject then Exit;
  LSaved := FValue;
  FValue := V;
  FRegistry.Visit(ASubType, APtr, Self as ITypeVisitor);
  FValue := LSaved;
end;

procedure TJsonUnmarshalVisitor.VisitDynArray(const AField: TFieldDef;
  AArrayPtr: PPointer; AElementType: PTypeDef);
var
  V: TJsonValue;
  LTemp: Pointer;
  LLen: SizeInt;
  LIdx: SizeInt;
  LElemPtr: Pointer;
begin
  if (AArrayPtr = nil) or (AField.DynArrayTypeInfo = nil) or
     (AField.ElementSize = 0) then
  begin
    FSuccess := False;
    Exit;
  end;

  V := FValue.ObjectGet(AField.Name);
  if not V.IsValid then
    Exit;
  if V.IsNull then
  begin
    DynArrayFree(AArrayPtr^, AField.DynArrayTypeInfo);
    AArrayPtr^ := nil;
    Exit;
  end;
  if not V.IsArray then
    Exit;

  LTemp := nil;
  try
    LLen := SizeInt(V.ArrayLen);
    DynArrayResize(LTemp, AField.DynArrayTypeInfo, LLen);
    if (LLen > 0) and (LTemp = nil) then
    begin
      FSuccess := False;
      Exit;
    end;

    for LIdx := 0 to LLen - 1 do
    begin
      LElemPtr := DynArrayElementPtr(LTemp, LIdx, AField.ElementSize);
      if (LElemPtr = nil) or
         (not ReadValue(V.ArrayGet(UInt32(LIdx)), AField.ElementKind,
           LElemPtr, AElementType)) then
      begin
        FSuccess := False;
        Exit;
      end;
    end;

    DynArrayFree(AArrayPtr^, AField.DynArrayTypeInfo);
    AArrayPtr^ := LTemp;
    LTemp := nil;
  finally
    if LTemp <> nil then
      DynArrayFree(LTemp, AField.DynArrayTypeInfo);
  end;
end;

{ Public API }

function JsonMarshal(ARegistry: ITypeRegistry; ATypeDef: PTypeDef; AData: Pointer): string;
var
  LVisitor: TJsonMarshalVisitor;
  LIntf: ITypeVisitor;
  LBuilder: TStringBuilder;
  LWriter: TJsonWriter;
begin
  if (ATypeDef = nil) or (AData = nil) then Exit('');
  LBuilder.Init(256);
  try
    LWriter.Init(LBuilder);
    LVisitor := TJsonMarshalVisitor.Create;
    LVisitor.FWriter := @LWriter;
    LVisitor.FRegistry := ARegistry;
    LIntf := LVisitor as ITypeVisitor;
    ARegistry.Visit(ATypeDef, AData, LIntf);
    LIntf := nil;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function JsonUnmarshal(ARegistry: ITypeRegistry; ATypeDef: PTypeDef;
  const AValue: TJsonValue; AData: Pointer): Boolean;
var
  LVisitor: TJsonUnmarshalVisitor;
  LIntf: ITypeVisitor;
begin
  if (ATypeDef = nil) or (AData = nil) or (not AValue.IsValid) then Exit(False);
  LVisitor := TJsonUnmarshalVisitor.Create;
  LVisitor.FValue := AValue;
  LVisitor.FRegistry := ARegistry;
  LVisitor.FSuccess := True;
  LIntf := LVisitor as ITypeVisitor;
  ARegistry.Visit(ATypeDef, AData, LIntf);
  Result := LVisitor.FSuccess;
  LIntf := nil;
end;

function JsonUnmarshalStr(ARegistry: ITypeRegistry; ATypeDef: PTypeDef;
  const AJson: string; AData: Pointer): Boolean;
var
  LDoc: TJsonDocument;
  LValue: TJsonValue;
begin
  if (ATypeDef = nil) or (AData = nil) or (AJson = '') then Exit(False);
  LDoc.Init(DefaultAllocator);
  try
    if not LDoc.Parse(TStringView.FromStr(AJson)) then Exit(False);
    LValue := TJsonValue.Create(LDoc, LDoc.Root);
    Result := JsonUnmarshal(ARegistry, ATypeDef, LValue, AData);
  finally
    LDoc.Done;
  end;
end;

end.
