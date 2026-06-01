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

procedure WriteFieldFromConfig(AConfig: TConfig; const AField: TFieldDef;
  AFieldPtr: Pointer);
begin
  case AField.Kind of
    fkString:
      PString(AFieldPtr)^ := AConfig.GetString(AField.Name);
    fkInt32:
      PInt32(AFieldPtr)^ := Int32(AConfig.GetInt(AField.Name));
    fkInt64:
      PInt64(AFieldPtr)^ := AConfig.GetInt(AField.Name);
    fkBool:
      PBoolean(AFieldPtr)^ := AConfig.GetBool(AField.Name);
    fkFloat64:
      PDouble(AFieldPtr)^ := AConfig.GetFloat(AField.Name);
  else
    ;
  end;
end;

procedure ConfigUnmarshal(AConfig: TConfig; ARegistry: ITypeRegistry;
  ATypeID: TTypeID; ATarget: Pointer);
var
  LTypeDef: PTypeDef;
  LIndex: Integer;
  LField: PFieldDef;
begin
  if (AConfig = nil) or (ARegistry = nil) or (ATarget = nil) then
    Exit;

  LTypeDef := ARegistry.FindTypeByID(ATypeID);
  if LTypeDef = nil then
    Exit;

  for LIndex := 0 to LTypeDef^.FieldCount - 1 do
  begin
    LField := @LTypeDef^.Fields[LIndex];
    if AConfig.Has(LField^.Name) then
      WriteFieldFromConfig(AConfig, LField^, PByte(ATarget) + LField^.Offset);
  end;
end;

end.
