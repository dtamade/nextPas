unit nextpas.core.reflect;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.reflect.base,
  nextpas.core.reflect.intf;

type
  TTypeID = nextpas.core.reflect.base.TTypeID;
  TFieldKind = nextpas.core.reflect.base.TFieldKind;
  TFieldFlag = nextpas.core.reflect.base.TFieldFlag;
  TFieldFlags = nextpas.core.reflect.base.TFieldFlags;
  TFieldDef = nextpas.core.reflect.base.TFieldDef;
  PFieldDef = nextpas.core.reflect.base.PFieldDef;
  TTypeDef = nextpas.core.reflect.base.TTypeDef;
  PTypeDef = nextpas.core.reflect.base.PTypeDef;
  ITypeVisitor = nextpas.core.reflect.intf.ITypeVisitor;
  ITypeRegistry = nextpas.core.reflect.intf.ITypeRegistry;

{** 创建类型注册表实例 *}
function CreateTypeRegistry: ITypeRegistry;

{** 默认 visitor 基类（所有方法空实现，子类按需覆盖） *}
type
  TBaseTypeVisitor = class(TInterfacedObject, ITypeVisitor)
  public
    procedure BeginType({%H-}ATypeDef: PTypeDef; {%H-}AData: Pointer); virtual;
    procedure EndType({%H-}ATypeDef: PTypeDef; {%H-}AData: Pointer); virtual;
    function ShouldVisit(const {%H-}AField: TFieldDef): Boolean; virtual;
    procedure VisitBool(const {%H-}AField: TFieldDef; {%H-}APtr: PBoolean); virtual;
    procedure VisitInt32(const {%H-}AField: TFieldDef; {%H-}APtr: PInt32); virtual;
    procedure VisitInt64(const {%H-}AField: TFieldDef; {%H-}APtr: PInt64); virtual;
    procedure VisitUInt32(const {%H-}AField: TFieldDef; {%H-}APtr: PDWord); virtual;
    procedure VisitFloat32(const {%H-}AField: TFieldDef; {%H-}APtr: PSingle); virtual;
    procedure VisitFloat64(const {%H-}AField: TFieldDef; {%H-}APtr: PDouble); virtual;
    procedure VisitString(const {%H-}AField: TFieldDef; {%H-}APtr: PString); virtual;
    procedure VisitRecord(const {%H-}AField: TFieldDef; {%H-}APtr: Pointer; {%H-}ASubType: PTypeDef); virtual;
    procedure VisitPointer(const {%H-}AField: TFieldDef; {%H-}APtr: PPointer); virtual;
  end;

implementation

uses
  nextpas.core.errors;

type
  TTypeRegistry = class(TInterfacedObject, ITypeRegistry)
  private
    FTypes: array[0..REFLECT_MAX_TYPES - 1] of TTypeDef;
    FTypeCount: Integer;
    FNextID: TTypeID;
    function FindIdx(const AName: string): Integer;
  public
    constructor Create;
    function RegisterType(const AName: string; ASize: Integer): TTypeID;
    function AddField(ATypeID: TTypeID; const AName: string;
      AOffset: PtrUInt; AKind: TFieldKind; ASize: Integer = 0;
      AFlags: TFieldFlags = []): Boolean;
    function FindType(const AName: string): PTypeDef;
    function FindTypeByID(AID: TTypeID): PTypeDef;
    function GetTypeID(const AName: string): TTypeID;
    function HasType(const AName: string): Boolean;
    function GetFieldDef(const ATypeName, AFieldName: string): PFieldDef;
    function GetFieldPtr(const ATypeName, AFieldName: string; AData: Pointer): Pointer;
    procedure Visit(ATypeDef: PTypeDef; AData: Pointer; AVisitor: ITypeVisitor);
    function GetTypeCount: Integer;
  end;

{ TTypeRegistry }

constructor TTypeRegistry.Create;
var
  LIdx: Integer;
begin
  inherited Create;
  FTypeCount := 0;
  FNextID := 1;
  for LIdx := 0 to REFLECT_MAX_TYPES - 1 do
    FTypes[LIdx].Active := False;
end;

function TTypeRegistry.FindIdx(const AName: string): Integer;
var
  LIdx: Integer;
begin
  for LIdx := 0 to FTypeCount - 1 do
    if FTypes[LIdx].Active and (FTypes[LIdx].Name = AName) then
      Exit(LIdx);
  Result := -1;
end;

function TTypeRegistry.RegisterType(const AName: string; ASize: Integer): TTypeID;
var
  LIdx: Integer;
begin
  LIdx := FindIdx(AName);
  if LIdx >= 0 then
    Exit(FTypes[LIdx].ID);
  if FTypeCount >= REFLECT_MAX_TYPES then
    raise Exception.Create('TypeRegistry: max types reached');
  LIdx := FTypeCount;
  FTypes[LIdx].Name := AName;
  FTypes[LIdx].ID := FNextID;
  FTypes[LIdx].Size := ASize;
  FTypes[LIdx].FieldCount := 0;
  FTypes[LIdx].Active := True;
  Inc(FTypeCount);
  Result := FNextID;
  Inc(FNextID);
end;

function TTypeRegistry.AddField(ATypeID: TTypeID; const AName: string;
  AOffset: PtrUInt; AKind: TFieldKind; ASize: Integer;
  AFlags: TFieldFlags): Boolean;
var
  LIdx, LFieldIdx: Integer;
begin
  Result := False;
  for LIdx := 0 to FTypeCount - 1 do
    if FTypes[LIdx].Active and (FTypes[LIdx].ID = ATypeID) then
    begin
      LFieldIdx := FTypes[LIdx].FieldCount;
      if LFieldIdx >= REFLECT_MAX_FIELDS then Exit;
      FTypes[LIdx].Fields[LFieldIdx].Name := AName;
      FTypes[LIdx].Fields[LFieldIdx].Offset := AOffset;
      FTypes[LIdx].Fields[LFieldIdx].Kind := AKind;
      FTypes[LIdx].Fields[LFieldIdx].Flags := AFlags;
      FTypes[LIdx].Fields[LFieldIdx].SubTypeID := TYPE_ID_NONE;
      if ASize > 0 then
        FTypes[LIdx].Fields[LFieldIdx].Size := ASize
      else
        case AKind of
          fkBool: FTypes[LIdx].Fields[LFieldIdx].Size := 1;
          fkInt8, fkUInt8: FTypes[LIdx].Fields[LFieldIdx].Size := 1;
          fkInt16, fkUInt16: FTypes[LIdx].Fields[LFieldIdx].Size := 2;
          fkInt32, fkUInt32, fkFloat32: FTypes[LIdx].Fields[LFieldIdx].Size := 4;
          fkInt64, fkUInt64, fkFloat64: FTypes[LIdx].Fields[LFieldIdx].Size := 8;
          fkPointer: FTypes[LIdx].Fields[LFieldIdx].Size := SizeOf(Pointer);
        else
          FTypes[LIdx].Fields[LFieldIdx].Size := 0;
        end;
      Inc(FTypes[LIdx].FieldCount);
      Exit(True);
    end;
end;

function TTypeRegistry.FindType(const AName: string): PTypeDef;
var
  LIdx: Integer;
begin
  LIdx := FindIdx(AName);
  if LIdx >= 0 then
    Result := @FTypes[LIdx]
  else
    Result := nil;
end;

function TTypeRegistry.FindTypeByID(AID: TTypeID): PTypeDef;
var
  LIdx: Integer;
begin
  for LIdx := 0 to FTypeCount - 1 do
    if FTypes[LIdx].Active and (FTypes[LIdx].ID = AID) then
      Exit(@FTypes[LIdx]);
  Result := nil;
end;

function TTypeRegistry.GetTypeID(const AName: string): TTypeID;
var
  LIdx: Integer;
begin
  LIdx := FindIdx(AName);
  if LIdx >= 0 then
    Result := FTypes[LIdx].ID
  else
    Result := TYPE_ID_NONE;
end;

function TTypeRegistry.HasType(const AName: string): Boolean;
begin
  Result := FindIdx(AName) >= 0;
end;

function TTypeRegistry.GetFieldDef(const ATypeName, AFieldName: string): PFieldDef;
var
  LIdx, LFIdx: Integer;
begin
  LIdx := FindIdx(ATypeName);
  if LIdx < 0 then Exit(nil);
  for LFIdx := 0 to FTypes[LIdx].FieldCount - 1 do
    if FTypes[LIdx].Fields[LFIdx].Name = AFieldName then
      Exit(@FTypes[LIdx].Fields[LFIdx]);
  Result := nil;
end;

function TTypeRegistry.GetFieldPtr(const ATypeName, AFieldName: string;
  AData: Pointer): Pointer;
var
  LField: PFieldDef;
begin
  LField := GetFieldDef(ATypeName, AFieldName);
  if (LField = nil) or (AData = nil) then
    Exit(nil);
  Result := AData + LField^.Offset;
end;

procedure TTypeRegistry.Visit(ATypeDef: PTypeDef; AData: Pointer;
  AVisitor: ITypeVisitor);
var
  LIdx: Integer;
  LField: PFieldDef;
  LPtr: Pointer;
begin
  if (ATypeDef = nil) or (AData = nil) or (AVisitor = nil) then Exit;
  AVisitor.BeginType(ATypeDef, AData);
  for LIdx := 0 to ATypeDef^.FieldCount - 1 do
  begin
    LField := @ATypeDef^.Fields[LIdx];
    if not AVisitor.ShouldVisit(LField^) then Continue;
    LPtr := AData + LField^.Offset;
    case LField^.Kind of
      fkBool: AVisitor.VisitBool(LField^, PBoolean(LPtr));
      fkInt32: AVisitor.VisitInt32(LField^, PInt32(LPtr));
      fkInt64: AVisitor.VisitInt64(LField^, PInt64(LPtr));
      fkUInt32: AVisitor.VisitUInt32(LField^, PDWord(LPtr));
      fkFloat32: AVisitor.VisitFloat32(LField^, PSingle(LPtr));
      fkFloat64: AVisitor.VisitFloat64(LField^, PDouble(LPtr));
      fkString: AVisitor.VisitString(LField^, PString(LPtr));
      fkRecord: AVisitor.VisitRecord(LField^, LPtr, FindTypeByID(LField^.SubTypeID));
      fkPointer: AVisitor.VisitPointer(LField^, PPointer(LPtr));
    end;
  end;
  AVisitor.EndType(ATypeDef, AData);
end;

function TTypeRegistry.GetTypeCount: Integer;
begin
  Result := FTypeCount;
end;

{ TBaseTypeVisitor }

procedure TBaseTypeVisitor.BeginType(ATypeDef: PTypeDef; AData: Pointer); begin end;
procedure TBaseTypeVisitor.EndType(ATypeDef: PTypeDef; AData: Pointer); begin end;
function TBaseTypeVisitor.ShouldVisit(const AField: TFieldDef): Boolean; begin Result := True; end;
procedure TBaseTypeVisitor.VisitBool(const AField: TFieldDef; APtr: PBoolean); begin end;
procedure TBaseTypeVisitor.VisitInt32(const AField: TFieldDef; APtr: PInt32); begin end;
procedure TBaseTypeVisitor.VisitInt64(const AField: TFieldDef; APtr: PInt64); begin end;
procedure TBaseTypeVisitor.VisitUInt32(const AField: TFieldDef; APtr: PDWord); begin end;
procedure TBaseTypeVisitor.VisitFloat32(const AField: TFieldDef; APtr: PSingle); begin end;
procedure TBaseTypeVisitor.VisitFloat64(const AField: TFieldDef; APtr: PDouble); begin end;
procedure TBaseTypeVisitor.VisitString(const AField: TFieldDef; APtr: PString); begin end;
procedure TBaseTypeVisitor.VisitRecord(const AField: TFieldDef; APtr: Pointer; ASubType: PTypeDef); begin end;
procedure TBaseTypeVisitor.VisitPointer(const AField: TFieldDef; APtr: PPointer); begin end;

{ Factory }

function CreateTypeRegistry: ITypeRegistry;
begin
  Result := TTypeRegistry.Create;
end;

end.
