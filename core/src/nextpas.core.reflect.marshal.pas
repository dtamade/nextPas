unit nextpas.core.reflect.marshal;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.reflect.base,
  nextpas.core.reflect.intf,
  nextpas.core.config;

{** 从 Config 填充 flat record。缺失字段保持目标内存原值。 *}
procedure ConfigUnmarshal(AConfig: TConfig; ARegistry: ITypeRegistry;
  ATypeID: TTypeID; ATarget: Pointer);

implementation

uses
  nextpas.core.reflect;

type
  TConfigUnmarshalVisitor = class(TBaseTypeVisitor)
  private
    FConfig: TConfig;
  public
    constructor Create(AConfig: TConfig);
    function ShouldVisit(const AField: TFieldDef): Boolean; override;
    procedure VisitBool(const AField: TFieldDef; APtr: PBoolean); override;
    procedure VisitInt32(const AField: TFieldDef; APtr: PInt32); override;
    procedure VisitInt64(const AField: TFieldDef; APtr: PInt64); override;
    procedure VisitFloat64(const AField: TFieldDef; APtr: PDouble); override;
    procedure VisitString(const AField: TFieldDef; APtr: PString); override;
    procedure VisitDynArray(const AField: TFieldDef; AArrayPtr: PPointer;
      AElementType: PTypeDef); override;
  end;

constructor TConfigUnmarshalVisitor.Create(AConfig: TConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

function TConfigUnmarshalVisitor.ShouldVisit(const AField: TFieldDef): Boolean;
begin
  Result := FConfig.Has(AField.Name);
end;

procedure TConfigUnmarshalVisitor.VisitBool(const AField: TFieldDef;
  APtr: PBoolean);
begin
  APtr^ := FConfig.GetBool(AField.Name);
end;

procedure TConfigUnmarshalVisitor.VisitInt32(const AField: TFieldDef;
  APtr: PInt32);
begin
  case AField.Kind of
    fkInt8: PInt8(APtr)^ := Int8(FConfig.GetInt(AField.Name));
    fkInt16: PInt16(APtr)^ := Int16(FConfig.GetInt(AField.Name));
  else
    APtr^ := Int32(FConfig.GetInt(AField.Name));
  end;
end;

procedure TConfigUnmarshalVisitor.VisitInt64(const AField: TFieldDef;
  APtr: PInt64);
begin
  APtr^ := FConfig.GetInt(AField.Name);
end;

procedure TConfigUnmarshalVisitor.VisitFloat64(const AField: TFieldDef;
  APtr: PDouble);
begin
  APtr^ := FConfig.GetFloat(AField.Name);
end;

procedure TConfigUnmarshalVisitor.VisitString(const AField: TFieldDef;
  APtr: PString);
begin
  APtr^ := FConfig.GetString(AField.Name);
end;

procedure TConfigUnmarshalVisitor.VisitDynArray(const AField: TFieldDef;
  AArrayPtr: PPointer; AElementType: PTypeDef);
begin
end;

procedure ConfigUnmarshal(AConfig: TConfig; ARegistry: ITypeRegistry;
  ATypeID: TTypeID; ATarget: Pointer);
var
  LTypeDef: PTypeDef;
  LVisitor: TConfigUnmarshalVisitor;
  LIntf: ITypeVisitor;
begin
  if (AConfig = nil) or (ARegistry = nil) or (ATarget = nil) then
    Exit;

  LTypeDef := ARegistry.FindTypeByID(ATypeID);
  if LTypeDef = nil then
    Exit;

  LVisitor := TConfigUnmarshalVisitor.Create(AConfig);
  LIntf := LVisitor as ITypeVisitor;
  ARegistry.Visit(LTypeDef, ATarget, LIntf);
  LIntf := nil;
end;

end.
