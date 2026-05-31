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
  nextpas.core.reflect;

type
  TJsonMarshalVisitor = class(TBaseTypeVisitor)
  private
    FWriter: ^TJsonWriter;
    FRegistry: ITypeRegistry;
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
  end;

  TJsonUnmarshalVisitor = class(TBaseTypeVisitor)
  private
    FValue: TJsonValue;
    FRegistry: ITypeRegistry;
    FSuccess: Boolean;
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

procedure TJsonMarshalVisitor.VisitBool(const AField: TFieldDef; APtr: PBoolean);
begin
  FWriter^.Key(AField.Name);
  FWriter^.Bool(APtr^);
end;

procedure TJsonMarshalVisitor.VisitInt32(const AField: TFieldDef; APtr: PInt32);
begin
  FWriter^.Key(AField.Name);
  case AField.Kind of
    fkInt8: FWriter^.Int(PInt8(APtr)^);
    fkInt16: FWriter^.Int(PInt16(APtr)^);
  else
    FWriter^.Int(APtr^);
  end;
end;

procedure TJsonMarshalVisitor.VisitInt64(const AField: TFieldDef; APtr: PInt64);
begin
  FWriter^.Key(AField.Name);
  if AField.Kind = fkUInt64 then
    FWriter^.UInt(PUInt64(APtr)^)
  else
    FWriter^.Int(APtr^);
end;

procedure TJsonMarshalVisitor.VisitUInt32(const AField: TFieldDef; APtr: PDWord);
begin
  FWriter^.Key(AField.Name);
  case AField.Kind of
    fkUInt8: FWriter^.Int(PByte(APtr)^);
    fkUInt16: FWriter^.Int(PWord(APtr)^);
  else
    FWriter^.Int(Int64(APtr^));
  end;
end;

procedure TJsonMarshalVisitor.VisitFloat32(const AField: TFieldDef; APtr: PSingle);
begin
  FWriter^.Key(AField.Name);
  FWriter^.Float(APtr^);
end;

procedure TJsonMarshalVisitor.VisitFloat64(const AField: TFieldDef; APtr: PDouble);
begin
  FWriter^.Key(AField.Name);
  FWriter^.Float(APtr^);
end;

procedure TJsonMarshalVisitor.VisitString(const AField: TFieldDef; APtr: PString);
begin
  FWriter^.Key(AField.Name);
  FWriter^.Str(APtr^);
end;

procedure TJsonMarshalVisitor.VisitRecord(const AField: TFieldDef; APtr: Pointer; ASubType: PTypeDef);
begin
  FWriter^.Key(AField.Name);
  if ASubType <> nil then
    FRegistry.Visit(ASubType, APtr, Self as ITypeVisitor)
  else
    FWriter^.Null;
end;

{ TJsonUnmarshalVisitor }

function TJsonUnmarshalVisitor.ShouldVisit(const AField: TFieldDef): Boolean;
begin
  Result := not (ffTransient in AField.Flags);
end;

procedure TJsonUnmarshalVisitor.BeginType(ATypeDef: PTypeDef; AData: Pointer);
begin
  if not FValue.IsObject then
    FSuccess := False;
end;

procedure TJsonUnmarshalVisitor.VisitBool(const AField: TFieldDef; APtr: PBoolean);
var V: TJsonValue;
begin
  V := FValue.ObjectGet(AField.Name);
  if V.IsBool then APtr^ := V.AsBool;
end;

procedure TJsonUnmarshalVisitor.VisitInt32(const AField: TFieldDef; APtr: PInt32);
var V: TJsonValue; LVal: Int64;
begin
  V := FValue.ObjectGet(AField.Name);
  if V.IsInt or V.IsReal then
  begin
    LVal := V.AsInt;
    case AField.Kind of
      fkInt8: PInt8(APtr)^ := Int8(LVal);
      fkInt16: PInt16(APtr)^ := Int16(LVal);
    else
      APtr^ := Int32(LVal);
    end;
  end;
end;

procedure TJsonUnmarshalVisitor.VisitInt64(const AField: TFieldDef; APtr: PInt64);
var V: TJsonValue;
begin
  V := FValue.ObjectGet(AField.Name);
  if V.IsInt or V.IsReal then
  begin
    if AField.Kind = fkUInt64 then
      PUInt64(APtr)^ := UInt64(V.AsInt)
    else
      APtr^ := V.AsInt;
  end;
end;

procedure TJsonUnmarshalVisitor.VisitUInt32(const AField: TFieldDef; APtr: PDWord);
var V: TJsonValue; LVal: Int64;
begin
  V := FValue.ObjectGet(AField.Name);
  if V.IsInt or V.IsReal then
  begin
    LVal := V.AsInt;
    case AField.Kind of
      fkUInt8: PByte(APtr)^ := Byte(LVal);
      fkUInt16: PWord(APtr)^ := Word(LVal);
    else
      APtr^ := DWord(LVal);
    end;
  end;
end;

procedure TJsonUnmarshalVisitor.VisitFloat32(const AField: TFieldDef; APtr: PSingle);
var V: TJsonValue;
begin
  V := FValue.ObjectGet(AField.Name);
  if V.IsReal or V.IsInt then APtr^ := Single(V.AsFloat);
end;

procedure TJsonUnmarshalVisitor.VisitFloat64(const AField: TFieldDef; APtr: PDouble);
var V: TJsonValue;
begin
  V := FValue.ObjectGet(AField.Name);
  if V.IsReal or V.IsInt then APtr^ := V.AsFloat;
end;

procedure TJsonUnmarshalVisitor.VisitString(const AField: TFieldDef; APtr: PString);
var V: TJsonValue;
begin
  V := FValue.ObjectGet(AField.Name);
  if V.IsStr then APtr^ := V.AsStr.ToString;
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
