unit nextpas.core.reflect.marshal;
{**
 * @desc Config → record typed bind via reflect visitor.
 *       Owner: reflect (uses config read surface; does not live in config unit).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.reflect.base,
  nextpas.core.reflect.intf,
  nextpas.core.config;

{** Fill a flat record from config. Missing keys keep target memory values. *}
procedure ConfigUnmarshal(AConfig: TConfig; ARegistry: ITypeRegistry;
  ATypeID: TTypeID; ATarget: Pointer); overload;
procedure ConfigUnmarshal(const AConfig: IConfig; ARegistry: ITypeRegistry;
  ATypeID: TTypeID; ATarget: Pointer); overload;

{** Same as above, but field Name maps to APrefix + '.' + Name (e.g. server.host).
    Empty prefix behaves like the non-prefix overloads. Trailing '.' on prefix is ok. *}
procedure ConfigUnmarshal(AConfig: TConfig; ARegistry: ITypeRegistry;
  ATypeID: TTypeID; ATarget: Pointer; const APrefix: string); overload;
procedure ConfigUnmarshal(const AConfig: IConfig; ARegistry: ITypeRegistry;
  ATypeID: TTypeID; ATarget: Pointer; const APrefix: string); overload;

implementation

uses
  nextpas.core.reflect,
  nextpas.core.reflect.dynarray;

type
  { Non-owning IConfig view over TConfig for ConfigUnmarshal(TConfig, ...). }
  TConfigAsIConfig = class(TInterfacedObject, IConfig)
  private
    FConfig: TConfig;
    function GetCount: Integer;
  public
    constructor Create(AConfig: TConfig);
    function GetString(const AKey: string; const ADefault: string = ''): string;
    function GetRawString(const AKey: string; const ADefault: string = ''): string;
    function GetStringArray(const AKey: string): TStringArray;
    function GetRawStringArray(const AKey: string): TStringArray;
    function GetInt(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetBool(const AKey: string; ADefault: Boolean = False): Boolean;
    function GetFloat(const AKey: string; ADefault: Double = 0.0): Double;
    function GetStringRequired(const AKey: string): string;
    function GetIntRequired(const AKey: string): Int64;
    function GetBoolRequired(const AKey: string): Boolean;
    function GetFloatRequired(const AKey: string): Double;
    procedure Require(const AKeys: array of string);
    function Has(const AKey: string): Boolean;
    function GetKeys: TStringArray;
    function GetSection(const APrefix: string): TStringArray;
    function GetInterpolationMode: TConfigInterpolationMode;
    function ToIni: string;
    function ToJson: string;
    function ToYaml: string;
    function ToToml: string;
    property Count: Integer read GetCount;
  end;

  TConfigUnmarshalVisitor = class(TBaseTypeVisitor)
  private
    FConfig: IConfig;
    FRegistry: ITypeRegistry;
    FPrefix: string;
    function FullKey(const AFieldName: string): string;
  public
    constructor Create(const AConfig: IConfig; ARegistry: ITypeRegistry;
      const APrefix: string);
    function ShouldVisit(const AField: TFieldDef): Boolean; override;
    procedure VisitBool(const AField: TFieldDef; APtr: PBoolean); override;
    procedure VisitInt32(const AField: TFieldDef; APtr: PInt32); override;
    procedure VisitInt64(const AField: TFieldDef; APtr: PInt64); override;
    procedure VisitUInt32(const AField: TFieldDef; APtr: PDWord); override;
    procedure VisitFloat32(const AField: TFieldDef; APtr: PSingle); override;
    procedure VisitFloat64(const AField: TFieldDef; APtr: PDouble); override;
    procedure VisitString(const AField: TFieldDef; APtr: PString); override;
    procedure VisitRecord(const AField: TFieldDef; APtr: Pointer;
      ASubType: PTypeDef); override;
    procedure VisitDynArray(const AField: TFieldDef; AArrayPtr: PPointer;
      AElementType: PTypeDef); override;
  end;

function NormalizeConfigPrefix(const APrefix: string): string;
var
  LLen: Integer;
begin
  Result := APrefix;
  LLen := Length(Result);
  while (LLen > 0) and (Result[LLen] = '.') do
  begin
    SetLength(Result, LLen - 1);
    LLen := Length(Result);
  end;
end;

function JoinConfigPrefix(const APrefix, AField: string): string;
begin
  if APrefix = '' then
    Exit(AField);
  Result := APrefix + '.' + AField;
end;

constructor TConfigAsIConfig.Create(AConfig: TConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

function TConfigAsIConfig.GetCount: Integer;
begin
  Result := FConfig.Count;
end;

function TConfigAsIConfig.GetString(const AKey: string; const ADefault: string): string;
begin
  Result := FConfig.GetString(AKey, ADefault);
end;

function TConfigAsIConfig.GetRawString(const AKey: string; const ADefault: string): string;
begin
  Result := FConfig.GetRawString(AKey, ADefault);
end;

function TConfigAsIConfig.GetStringArray(const AKey: string): TStringArray;
begin
  Result := FConfig.GetStringArray(AKey);
end;

function TConfigAsIConfig.GetRawStringArray(const AKey: string): TStringArray;
begin
  Result := FConfig.GetRawStringArray(AKey);
end;

function TConfigAsIConfig.GetInt(const AKey: string; ADefault: Int64): Int64;
begin
  Result := FConfig.GetInt(AKey, ADefault);
end;

function TConfigAsIConfig.GetBool(const AKey: string; ADefault: Boolean): Boolean;
begin
  Result := FConfig.GetBool(AKey, ADefault);
end;

function TConfigAsIConfig.GetFloat(const AKey: string; ADefault: Double): Double;
begin
  Result := FConfig.GetFloat(AKey, ADefault);
end;

function TConfigAsIConfig.GetStringRequired(const AKey: string): string;
begin
  Result := FConfig.GetStringRequired(AKey);
end;

function TConfigAsIConfig.GetIntRequired(const AKey: string): Int64;
begin
  Result := FConfig.GetIntRequired(AKey);
end;

function TConfigAsIConfig.GetBoolRequired(const AKey: string): Boolean;
begin
  Result := FConfig.GetBoolRequired(AKey);
end;

function TConfigAsIConfig.GetFloatRequired(const AKey: string): Double;
begin
  Result := FConfig.GetFloatRequired(AKey);
end;

procedure TConfigAsIConfig.Require(const AKeys: array of string);
begin
  FConfig.Require(AKeys);
end;

function TConfigAsIConfig.Has(const AKey: string): Boolean;
begin
  Result := FConfig.Has(AKey);
end;

function TConfigAsIConfig.GetKeys: TStringArray;
begin
  Result := FConfig.GetKeys;
end;

function TConfigAsIConfig.GetSection(const APrefix: string): TStringArray;
begin
  Result := FConfig.GetSection(APrefix);
end;

function TConfigAsIConfig.GetInterpolationMode: TConfigInterpolationMode;
begin
  Result := FConfig.GetInterpolationMode;
end;

function TConfigAsIConfig.ToIni: string;
begin
  Result := FConfig.ToIni;
end;

function TConfigAsIConfig.ToJson: string;
begin
  Result := FConfig.ToJson;
end;

function TConfigAsIConfig.ToYaml: string;
begin
  Result := FConfig.ToYaml;
end;

function TConfigAsIConfig.ToToml: string;
begin
  Result := FConfig.ToToml;
end;

constructor TConfigUnmarshalVisitor.Create(const AConfig: IConfig;
  ARegistry: ITypeRegistry; const APrefix: string);
begin
  inherited Create;
  FConfig := AConfig;
  FRegistry := ARegistry;
  FPrefix := NormalizeConfigPrefix(APrefix);
end;

function TConfigUnmarshalVisitor.FullKey(const AFieldName: string): string;
begin
  Result := JoinConfigPrefix(FPrefix, AFieldName);
end;

function TConfigUnmarshalVisitor.ShouldVisit(const AField: TFieldDef): Boolean;
var
  LKey: string;
begin
  { Nested records always descend; leaf ShouldVisit gates keep missing defaults. }
  if AField.Kind = fkRecord then
    Exit(True);

  LKey := FullKey(AField.Name);
  if AField.Kind = fkDynArray then
  begin
    { String arrays use GetStringArray(prefix) which needs prefix.0 present. }
    Result := FConfig.Has(LKey) or FConfig.Has(LKey + '.0');
    Exit;
  end;
  Result := FConfig.Has(LKey);
end;

procedure TConfigUnmarshalVisitor.VisitBool(const AField: TFieldDef;
  APtr: PBoolean);
begin
  APtr^ := FConfig.GetBool(FullKey(AField.Name));
end;

procedure TConfigUnmarshalVisitor.VisitInt32(const AField: TFieldDef;
  APtr: PInt32);
begin
  case AField.Kind of
    fkInt8: PInt8(APtr)^ := Int8(FConfig.GetInt(FullKey(AField.Name)));
    fkInt16: PInt16(APtr)^ := Int16(FConfig.GetInt(FullKey(AField.Name)));
  else
    APtr^ := Int32(FConfig.GetInt(FullKey(AField.Name)));
  end;
end;

procedure TConfigUnmarshalVisitor.VisitInt64(const AField: TFieldDef;
  APtr: PInt64);
begin
  APtr^ := FConfig.GetInt(FullKey(AField.Name));
end;

procedure TConfigUnmarshalVisitor.VisitUInt32(const AField: TFieldDef;
  APtr: PDWord);
var
  LVal: Int64;
begin
  LVal := FConfig.GetInt(FullKey(AField.Name));
  case AField.Kind of
    fkUInt8: PByte(APtr)^ := Byte(LVal);
    fkUInt16: PWord(APtr)^ := Word(LVal);
  else
    APtr^ := DWord(LVal);
  end;
end;

procedure TConfigUnmarshalVisitor.VisitFloat32(const AField: TFieldDef;
  APtr: PSingle);
begin
  APtr^ := Single(FConfig.GetFloat(FullKey(AField.Name)));
end;

procedure TConfigUnmarshalVisitor.VisitFloat64(const AField: TFieldDef;
  APtr: PDouble);
begin
  APtr^ := FConfig.GetFloat(FullKey(AField.Name));
end;

procedure TConfigUnmarshalVisitor.VisitString(const AField: TFieldDef;
  APtr: PString);
begin
  APtr^ := FConfig.GetString(FullKey(AField.Name));
end;

procedure TConfigUnmarshalVisitor.VisitRecord(const AField: TFieldDef;
  APtr: Pointer; ASubType: PTypeDef);
var
  LSaved: string;
  LSelf: ITypeVisitor;
begin
  if (ASubType = nil) or (APtr = nil) or (FRegistry = nil) then
    Exit;
  LSaved := FPrefix;
  FPrefix := FullKey(AField.Name);
  LSelf := Self as ITypeVisitor;
  FRegistry.Visit(ASubType, APtr, LSelf);
  FPrefix := LSaved;
end;

procedure TConfigUnmarshalVisitor.VisitDynArray(const AField: TFieldDef;
  AArrayPtr: PPointer; AElementType: PTypeDef);
var
  LKey: string;
  LItems: TStringArray;
  LI: Integer;
  LElem: Pointer;
begin
  if (AArrayPtr = nil) or (AField.ElementKind <> fkString) then
    Exit;
  if AField.DynArrayTypeInfo = nil then
    Exit;

  LKey := FullKey(AField.Name);
  LItems := FConfig.GetStringArray(LKey);
  DynArrayResize(AArrayPtr^, AField.DynArrayTypeInfo, Length(LItems));
  for LI := 0 to High(LItems) do
  begin
    LElem := DynArrayElementPtr(AArrayPtr^, LI, AField.ElementSize);
    if LElem <> nil then
      PString(LElem)^ := LItems[LI];
  end;
end;

procedure ConfigUnmarshalCore(const AConfig: IConfig; ARegistry: ITypeRegistry;
  ATypeID: TTypeID; ATarget: Pointer; const APrefix: string);
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

  LVisitor := TConfigUnmarshalVisitor.Create(AConfig, ARegistry, APrefix);
  LIntf := LVisitor as ITypeVisitor;
  ARegistry.Visit(LTypeDef, ATarget, LIntf);
  LIntf := nil;
end;

procedure ConfigUnmarshal(const AConfig: IConfig; ARegistry: ITypeRegistry;
  ATypeID: TTypeID; ATarget: Pointer);
begin
  ConfigUnmarshalCore(AConfig, ARegistry, ATypeID, ATarget, '');
end;

procedure ConfigUnmarshal(const AConfig: IConfig; ARegistry: ITypeRegistry;
  ATypeID: TTypeID; ATarget: Pointer; const APrefix: string);
begin
  ConfigUnmarshalCore(AConfig, ARegistry, ATypeID, ATarget, APrefix);
end;

procedure ConfigUnmarshal(AConfig: TConfig; ARegistry: ITypeRegistry;
  ATypeID: TTypeID; ATarget: Pointer);
var
  LView: IConfig;
begin
  if AConfig = nil then
    Exit;
  LView := TConfigAsIConfig.Create(AConfig);
  ConfigUnmarshalCore(LView, ARegistry, ATypeID, ATarget, '');
end;

procedure ConfigUnmarshal(AConfig: TConfig; ARegistry: ITypeRegistry;
  ATypeID: TTypeID; ATarget: Pointer; const APrefix: string);
var
  LView: IConfig;
begin
  if AConfig = nil then
    Exit;
  LView := TConfigAsIConfig.Create(AConfig);
  ConfigUnmarshalCore(LView, ARegistry, ATypeID, ATarget, APrefix);
end;

end.
