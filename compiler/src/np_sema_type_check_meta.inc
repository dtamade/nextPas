
uses
  SysUtils;

{ === 基本类型元数据 === }

function TypeMetaSize(const AModel: TSemanticModel; const ATypeName: string): Int64;
var
  Meta: TTypeMetadata;
  V: Int64;
  TypeId: LongInt;
  function KnownBuiltinSize(const AName: string): Int64;
  begin
    if SameText(AName, 'Boolean') or SameText(AName, 'ByteBool') or
      SameText(AName, 'Byte') or SameText(AName, 'ShortInt') or
      SameText(AName, 'AnsiChar') or SameText(AName, 'Char') or
      SameText(AName, 'Int8') or SameText(AName, 'UInt8') then
      Exit(1);
    if SameText(AName, 'Word') or SameText(AName, 'SmallInt') or
      SameText(AName, 'WideChar') or SameText(AName, 'Int16') or
      SameText(AName, 'UInt16') then
      Exit(2);
    if SameText(AName, 'Integer') or SameText(AName, 'LongInt') or
      SameText(AName, 'LongWord') or SameText(AName, 'Cardinal') or
      SameText(AName, 'DWord') or SameText(AName, 'Int32') or
      SameText(AName, 'UInt32') or SameText(AName, 'Single') then
      Exit(4);
    if SameText(AName, 'Int64') or SameText(AName, 'QWord') or
      SameText(AName, 'UInt64') or SameText(AName, 'Double') or
      SameText(AName, 'Pointer') or SameText(AName, 'PtrUInt') or
      SameText(AName, 'PtrInt') or SameText(AName, 'SizeUInt') or
      SameText(AName, 'SizeInt') or SameText(AName, 'NativeUInt') or
      SameText(AName, 'NativeInt') or SameText(AName, 'CodePointer') or
      SameText(AName, 'PChar') or SameText(AName, 'PAnsiChar') or
      SameText(AName, 'PByte') or SameText(AName, 'PPointer') then
      Exit(8);
    Result := -1;
  end;
  function ScalarSizeOfTypeId(const AId: LongInt): Int64;
  var
    Cur: LongInt;
    D: LongInt;
    F: TSemanticScalarTypeFact;
    M: TTypeMetadata;
  begin
    Result := -1;
    Cur := AId;
    D := 0;
    while (Cur > 0) and (Cur <= AModel.TypeCount) and (D < 16) do
    begin
      if AModel.GetTypeScalarFact(Cur, F) and (F.BitWidth > 0) and
        (F.Kind in [sskBool, sskInt, sskFloat, sskPointer]) then
        Exit(F.BitWidth div 8);
      if AModel.GetTypeMeta(Cur, M) then
      begin
        if M.Size > 0 then
          Exit(M.Size);
        if (M.AliasTargetTypeId > 0) and (M.AliasTargetTypeId <> Cur) then
        begin
          Cur := M.AliasTargetTypeId;
          Inc(D);
          Continue;
        end;
      end;
      if (Cur > 0) and (Cur <= AModel.TypeCount) and
        (AModel.TypeAt(Cur - 1).ParentTypeId > 0) and
        (AModel.TypeAt(Cur - 1).ParentTypeId <> Cur) then
      begin
        Cur := AModel.TypeAt(Cur - 1).ParentTypeId;
        Inc(D);
        Continue;
      end;
      Break;
    end;
  end;
begin
  { Prefer positive layout size; Size=0 meta must not hide scalar/const facts. }
  if AModel.GetTypeMetaByName(ATypeName, Meta) and (Meta.Size > 0) then
    Exit(Meta.Size);
  if AModel.LookupConstValue(ATypeName + '$size', V) and (V > 0) then
    Exit(V);
  TypeId := AModel.FindTypeByName(ATypeName);
  if TypeId > 0 then
  begin
    V := ScalarSizeOfTypeId(TypeId);
    if V > 0 then
      Exit(V);
  end;
  if AModel.GetTypeMetaByName(ATypeName, Meta) and
    (Meta.AliasTargetTypeId > 0) then
  begin
    V := ScalarSizeOfTypeId(Meta.AliasTargetTypeId);
    if V > 0 then
      Exit(V);
  end;
  V := KnownBuiltinSize(ATypeName);
  if V > 0 then
    Exit(V);
  if AModel.GetTypeMetaByName(ATypeName, Meta) then
    Exit(Meta.Size);
  Result := -1;
end;

function TypeMetaIsDynArrayType(const AModel: TSemanticModel;
  const ATypeName: string): Boolean;
var
  Meta: TTypeMetadata;
  V: Int64;
begin
  if ATypeName = '' then
    Exit(False);
  if AModel.LookupConstValue(ATypeName + '$arr', V) then
    Exit(True);
  if AModel.GetTypeMetaByName(ATypeName, Meta) and (not Meta.IsRecord) and
    (not Meta.IsStaticArray) and (Meta.ArrElemType <> '') then
    Exit(True);
  Result := False;
end;

function TypeMetaIsRecord(const AModel: TSemanticModel; const ATypeName: string): Boolean;
var Meta: TTypeMetadata; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) then Exit(Meta.IsRecord);
  Result := AModel.LookupConstValue(ATypeName + '$record', V);
end;

function TypeMetaIsPointer(const AModel: TSemanticModel; const ATypeName: string): Boolean;
var
  TypeId: LongInt;
  Fact: TSemanticScalarTypeFact;
  Meta: TTypeMetadata;
begin
  Result := False;
  if (Length(ATypeName) > 1) and (ATypeName[1] = '^') then
    Exit(True);
  TypeId := AModel.FindTypeByName(ATypeName);
  if (TypeId > 0) and AModel.GetTypeScalarFact(TypeId, Fact) and
    (Fact.Kind = sskPointer) then
    Exit(True);
  { Pointer aliases: size=8, not record, parent Pointer. }
  if AModel.GetTypeMetaByName(ATypeName, Meta) and (not Meta.IsRecord) and
    (Meta.Size = 8) then
  begin
    TypeId := AModel.FindTypeByName(ATypeName);
    if (TypeId > 0) and (TypeId <= AModel.TypeCount) then
    begin
      TypeId := AModel.TypeAt(TypeId - 1).ParentTypeId;
      if (TypeId > 0) and (TypeId <= AModel.TypeCount) and
        SameText(AModel.TypeAt(TypeId - 1).Name, 'Pointer') then
        Exit(True);
    end;
  end;
end;

function TypeMetaIsInterface(const AModel: TSemanticModel; const ATypeName: string): Boolean;
var
  V: Int64;
  TypeId: LongInt;
  Meta: TTypeMetadata;
  Depth: LongInt;
begin
  if ATypeName = '' then
    Exit(False);
  if AModel.LookupConstValue(ATypeName + '$interface', V) then
    Exit(True);
  TypeId := AModel.FindTypeByName(ATypeName);
  if (TypeId > 0) and (TypeId <= AModel.TypeCount) and
    SameText(AModel.TypeAt(TypeId - 1).Kind, 'interface') then
    Exit(True);
  { Alias / re-export: name index may point at meta without $interface const. }
  Depth := 0;
  while (TypeId > 0) and (TypeId <= AModel.TypeCount) and (Depth < 8) do
  begin
    if not AModel.GetTypeMeta(TypeId, Meta) then
      Break;
    if (Meta.VmtSlots <> nil) and (Meta.Size = 8) and (not Meta.IsRecord) and
      (Meta.ParentClassId = 0) and (Meta.ParentClassName = '') and
      (Meta.Fields = nil) then
      Exit(True);
    if (Meta.AliasTargetTypeId > 0) and (Meta.AliasTargetTypeId <> TypeId) then
    begin
      TypeId := Meta.AliasTargetTypeId;
      Inc(Depth);
      if AModel.LookupConstValue(AModel.TypeAt(TypeId - 1).Name + '$interface', V) then
        Exit(True);
      if SameText(AModel.TypeAt(TypeId - 1).Kind, 'interface') then
        Exit(True);
      Continue;
    end;
    Break;
  end;
  Result := False;
end;

function TypeIsInterfaceByName(const AModel: TSemanticModel; const ATypeName: string): Boolean;
var TypeId: LongInt;
begin
  if TypeMetaIsInterface(AModel, ATypeName) then
    Exit(True);
  TypeId := AModel.FindTypeByName(ATypeName);
  Result := (TypeId > 0) and
    SameText(AModel.TypeAt(TypeId - 1).Kind, 'interface');
end;

function TypeMetaIsClass(const AModel: TSemanticModel; const ATypeName: string): Boolean;
var
  Meta: TTypeMetadata;
  V: Int64;
  TypeId: LongInt;
begin
  Result := False;
  if ATypeName = '' then
    Exit;
  if TypeMetaIsPointer(AModel, ATypeName) then
    Exit(False);
  { Dynarray descriptor is SizeOf=8 managed pointer — not a class. }
  if TypeMetaIsDynArrayType(AModel, ATypeName) then
    Exit(False);
  if TypeMetaIsRecord(AModel, ATypeName) then
    Exit(False);
  { Interfaces also carry $vmt_count / VmtSlots (IMT). Must not look like class
    or LH: IHasher seeds as class and ivcall/vcall paths diverge. }
  if TypeMetaIsInterface(AModel, ATypeName) then
    Exit(False);
  TypeId := AModel.FindTypeByName(ATypeName);
  if (TypeId > 0) and (TypeId <= AModel.TypeCount) then
  begin
    if SameText(AModel.TypeAt(TypeId - 1).Kind, 'interface') then
      Exit(False);
    if SameText(AModel.TypeAt(TypeId - 1).Kind, 'class') then
      Exit(True);
  end;
  { Real classes carry VMT / parent — Size>0 alone matches Integer/LongInt. }
  if AModel.GetTypeMetaByName(ATypeName, Meta) then
  begin
    if (Meta.VmtCount > 0) or (Meta.ParentClassId > 0) or
      (Meta.ParentClassName <> '') then
      Exit(True);
  end;
  if AModel.LookupConstValue(ATypeName + '$vmt_count', V) then
    Exit(True);
end;

{ === 字段元数据 === }

function TypeMetaFieldIndex(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Int64;
var Meta: TTypeMetadata; I: LongInt; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) and (Meta.Fields <> nil) then
    for I := 0 to LongInt(Meta.Fields.Count) - 1 do
      if SameText(Meta.Fields[SizeUInt(I)].Name, AFieldName) then
        Exit(Meta.Fields[SizeUInt(I)].Index);
  if AModel.LookupConstValue(ATypeName + '.' + AFieldName + '$idx', V) then
    Exit(V);
  Result := -1;
end;

function TypeMetaFieldIsStr(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Boolean;
var Meta: TTypeMetadata; I: LongInt; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) and (Meta.Fields <> nil) then
    for I := 0 to LongInt(Meta.Fields.Count) - 1 do
      if SameText(Meta.Fields[SizeUInt(I)].Name, AFieldName) then
        Exit(Meta.Fields[SizeUInt(I)].IsString);
  Result := AModel.LookupConstValue(ATypeName + '.' + AFieldName + '$str', V);
end;

function TypeMetaFieldIsPtr(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Boolean;
var Meta: TTypeMetadata; I: LongInt; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) and (Meta.Fields <> nil) then
    for I := 0 to LongInt(Meta.Fields.Count) - 1 do
      if SameText(Meta.Fields[SizeUInt(I)].Name, AFieldName) then
        Exit(Meta.Fields[SizeUInt(I)].IsPointer);
  Result := AModel.LookupConstValue(ATypeName + '.' + AFieldName + '$ptr', V);
end;

function TypeMetaFieldIsDynArray(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Boolean;
var Meta: TTypeMetadata; I: LongInt; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) and (Meta.Fields <> nil) then
    for I := 0 to LongInt(Meta.Fields.Count) - 1 do
      if SameText(Meta.Fields[SizeUInt(I)].Name, AFieldName) then
        Exit(Meta.Fields[SizeUInt(I)].IsDynArray);
  Result := AModel.LookupConstValue(ATypeName + '.' + AFieldName + '$arr', V);
end;

function TypeMetaFieldDynArrayElemSize(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Int64;
begin
  if not AModel.LookupConstValue(
    ATypeName + '.' + AFieldName + '$arr_elem_size', Result) then
    Result := 8;
end;

{ === VMT 元数据 === }

function TypeMetaVmtSlot(const AModel: TSemanticModel;
  const ATypeName, AMethodName: string): Int64;
var
  Meta, TargetMeta: TTypeMetadata;
  I, Depth: LongInt;
  V: Int64;
  TargetName, CurName, ParentName: string;
  TypeId: LongInt;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) and (Meta.VmtSlots <> nil) then
    for I := 0 to LongInt(Meta.VmtSlots.Count) - 1 do
      if SameText(Meta.VmtSlots[SizeUInt(I)].MethodName, AMethodName) then
        Exit(Meta.VmtSlots[SizeUInt(I)].SlotIndex);
  if AModel.LookupConstValue(ATypeName + '$vmt_slot_' + AMethodName, V) then
    Exit(V);
  { Same-name re-export (IChild = unit.path.IChild) last-wins the name index to
    an alias meta that often drops VmtSlots; follow AliasTargetTypeId. }
  if AModel.GetTypeMetaByName(ATypeName, Meta) and
    (Meta.AliasTargetTypeId > 0) and
    (Meta.AliasTargetTypeId <= AModel.TypeCount) and
    AModel.GetTypeMeta(Meta.AliasTargetTypeId, TargetMeta) then
  begin
    if TargetMeta.VmtSlots <> nil then
      for I := 0 to LongInt(TargetMeta.VmtSlots.Count) - 1 do
        if SameText(TargetMeta.VmtSlots[SizeUInt(I)].MethodName, AMethodName) then
          Exit(TargetMeta.VmtSlots[SizeUInt(I)].SlotIndex);
    TargetName := AModel.TypeAt(Meta.AliasTargetTypeId - 1).Name;
    if (TargetName <> '') and (not SameText(TargetName, ATypeName)) and
      AModel.LookupConstValue(TargetName + '$vmt_slot_' + AMethodName, V) then
      Exit(V);
  end;
  { Interface inheritance: IHasher.Write lives on parent IWriter IMT prefix.
    Prefer child $vmt_slot_ (above); if missing, walk parent chain. Child IMT
    must still inherit parent slots at ProcessInterfaceMethods for layout. }
  CurName := ATypeName;
  Depth := 0;
  while (CurName <> '') and (Depth < 8) do
  begin
    ParentName := '';
    if AModel.GetTypeMetaByName(CurName, Meta) then
    begin
      if Meta.ParentClassName <> '' then
        ParentName := Meta.ParentClassName
      else if (Meta.ParentClassId > 0) and (Meta.ParentClassId <= AModel.TypeCount) then
        ParentName := AModel.TypeAt(Meta.ParentClassId - 1).Name;
      if (ParentName = '') and (Meta.AliasTargetTypeId > 0) and
        (Meta.AliasTargetTypeId <= AModel.TypeCount) then
        ParentName := AModel.TypeAt(Meta.AliasTargetTypeId - 1).Name;
    end;
    if ParentName = '' then
      if not AModel.LookupStringConstValue(CurName + '$parent_class', ParentName) then
        ParentName := '';
    if ParentName = '' then
    begin
      TypeId := AModel.FindTypeByName(CurName);
      if (TypeId > 0) and (AModel.TypeAt(TypeId - 1).ParentTypeId > 0) and
        (AModel.TypeAt(TypeId - 1).ParentTypeId <= AModel.TypeCount) then
        ParentName := AModel.TypeAt(AModel.TypeAt(TypeId - 1).ParentTypeId - 1).Name;
    end;
    if (ParentName = '') or SameText(ParentName, CurName) then
      Break;
    if AModel.LookupConstValue(ParentName + '$vmt_slot_' + AMethodName, V) then
      Exit(V);
    if AModel.GetTypeMetaByName(ParentName, TargetMeta) and
      (TargetMeta.VmtSlots <> nil) then
      for I := 0 to LongInt(TargetMeta.VmtSlots.Count) - 1 do
        if SameText(TargetMeta.VmtSlots[SizeUInt(I)].MethodName, AMethodName) then
          Exit(TargetMeta.VmtSlots[SizeUInt(I)].SlotIndex);
    CurName := ParentName;
    Inc(Depth);
  end;
  Result := -1;
end;

function TypeMetaRetPtr(const AModel: TSemanticModel;
  const ATypeName, AMethodName: string): Boolean;
var
  V: Int64;
  Meta: TTypeMetadata;
  TargetName, QualName: string;
  SymId, RetTypeId, Depth: LongInt;
  RetMeta: TTypeMetadata;
begin
  if AModel.LookupConstValue(ATypeName + '$ret_ptr_' + AMethodName, V) then
    Exit(True);
  { Re-export IChild = unit.IChild: name index last-wins; follow target. }
  if AModel.GetTypeMetaByName(ATypeName, Meta) and
    (Meta.AliasTargetTypeId > 0) and
    (Meta.AliasTargetTypeId <= AModel.TypeCount) then
  begin
    TargetName := AModel.TypeAt(Meta.AliasTargetTypeId - 1).Name;
    if (TargetName <> '') and (not SameText(TargetName, ATypeName)) and
      AModel.LookupConstValue(TargetName + '$ret_ptr_' + AMethodName, V) then
      Exit(True);
  end;
  { Fallback: method symbol ReturnTypeId is class/interface/record/object-sized.
    Covers interface methods whose $ret_ptr_ was missed at ProcessInterfaceMethods
    (TProcessOutput record → WaitWithOutput store-ptr vs call-i64). }
  QualName := ATypeName + '.' + AMethodName;
  SymId := AModel.FindSymbolByName(QualName);
  if SymId <= 0 then
  begin
    if AModel.GetTypeMetaByName(ATypeName, Meta) and
      (Meta.AliasTargetTypeId > 0) and
      (Meta.AliasTargetTypeId <= AModel.TypeCount) then
    begin
      TargetName := AModel.TypeAt(Meta.AliasTargetTypeId - 1).Name;
      if TargetName <> '' then
        SymId := AModel.FindSymbolByName(TargetName + '.' + AMethodName);
    end;
  end;
  if SymId > 0 then
  begin
    RetTypeId := AModel.SymbolAt(SymId - 1).ReturnTypeId;
    Depth := 0;
    while (RetTypeId > 0) and (RetTypeId <= AModel.TypeCount) and (Depth < 6) do
    begin
      TargetName := AModel.TypeAt(RetTypeId - 1).Name;
      if SameText(AModel.TypeAt(RetTypeId - 1).Kind, 'interface') or
        SameText(AModel.TypeAt(RetTypeId - 1).Kind, 'class') or
        SameText(TargetName, 'Pointer') or
        SameText(TargetName, 'PChar') or
        SameText(TargetName, 'IInterface') then
        Exit(True);
      if AModel.GetTypeMeta(RetTypeId, RetMeta) then
      begin
        { Records / multi-word values / interface-shaped meta → ptr in this ABI.
          Do NOT treat small scalar Size (1/2/4/8 bare) as ret-ptr. }
        if RetMeta.IsRecord then
          Exit(True);
        if (RetMeta.VmtSlots <> nil) and (not RetMeta.IsRecord) and
          (RetMeta.Size = 8) then
          Exit(True);
        if (RetMeta.Size > 8) and (not RetMeta.IsRecord) then
          Exit(True); { class instance layout returned as ptr }
        if (RetMeta.AliasTargetTypeId > 0) and
          (RetMeta.AliasTargetTypeId <> RetTypeId) then
        begin
          RetTypeId := RetMeta.AliasTargetTypeId;
          Inc(Depth);
          Continue;
        end;
      end;
      Break;
    end;
  end;
  Result := False;
end;

function TypeMetaRetStr(const AModel: TSemanticModel;
  const ATypeName, AMethodName: string): Boolean;
var
  V: Int64;
  Meta: TTypeMetadata;
  TargetName: string;
begin
  if AModel.LookupConstValue(ATypeName + '$ret_str_' + AMethodName, V) then
    Exit(True);
  if AModel.GetTypeMetaByName(ATypeName, Meta) and
    (Meta.AliasTargetTypeId > 0) and
    (Meta.AliasTargetTypeId <= AModel.TypeCount) then
  begin
    TargetName := AModel.TypeAt(Meta.AliasTargetTypeId - 1).Name;
    if (TargetName <> '') and (not SameText(TargetName, ATypeName)) and
      AModel.LookupConstValue(TargetName + '$ret_str_' + AMethodName, V) then
      Exit(True);
  end;
  Result := False;
end;

function TypeMetaVmtCount(const AModel: TSemanticModel; const ATypeName: string): Int64;
var Meta: TTypeMetadata; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) then Exit(Meta.VmtCount);
  if AModel.LookupConstValue(ATypeName + '$vmt_count', V) then Exit(V);
  Result := -1;
end;

{ === 类型层级 === }

function TypeMetaParentClass(const AModel: TSemanticModel; const ATypeName: string): string;
var Meta: TTypeMetadata;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) and (Meta.ParentClassName <> '') then
    Exit(Meta.ParentClassName);
  if not AModel.LookupStringConstValue(ATypeName + '$parent_class', Result) then
    Result := '';
end;

function NextClassAncestorName(const AModel: TSemanticModel; const ATypeName: string): string;
var
  TypeId: LongInt;
begin
  Result := '';
  if ATypeName = '' then
    Exit;

  TypeId := AModel.FindTypeByName(ATypeName);
  if (TypeId > 0) and (AModel.TypeAt(TypeId - 1).ParentTypeId > 0) then
    Result := AModel.TypeAt(
      AModel.TypeAt(TypeId - 1).ParentTypeId - 1).Name;
  if Result = '' then
    Result := TypeMetaParentClass(AModel, ATypeName);
  if SameText(Result, ATypeName) then
    Result := '';
end;

{ === 接口 === }

function TypeMetaInterfaces(const AModel: TSemanticModel; const ATypeName: string): string;
var Meta: TTypeMetadata;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) and (Meta.Interfaces <> '') then
    Exit(Meta.Interfaces);
  if not AModel.LookupStringConstValue(ATypeName + '$interfaces', Result) then
    Result := '';
end;

function IsIntrinsicExprName(const AName: string): Boolean;
begin
  Result := SameText(AName, 'SizeOf') or SameText(AName, 'High') or
    SameText(AName, 'Low') or SameText(AName, 'Length') or
    SameText(AName, 'Ord') or SameText(AName, 'Pred') or
    SameText(AName, 'Succ') or SameText(AName, 'Chr') or
    SameText(AName, 'Assigned') or SameText(AName, 'Abs') or
    SameText(AName, 'Sqr') or SameText(AName, 'Sqrt') or
    SameText(AName, 'Round') or SameText(AName, 'Trunc') or
    SameText(AName, 'Default') or SameText(AName, 'EOF') or
    SameText(AName, 'FilePos') or SameText(AName, 'FileSize') or
    SameText(AName, 'Min') or SameText(AName, 'Max') or
    SameText(AName, 'Floor') or SameText(AName, 'Ceil') or
    SameText(AName, 'Supports') or SameText(AName, 'IsFinite');
end;

