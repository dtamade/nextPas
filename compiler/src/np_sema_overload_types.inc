function GetParamSignature(const Ctx: TSemaOverloadContext; const ADecl: TGreenNode): string;
var
  J, K: LongInt;
  Child, ParamChild, TypeChild: TGreenNode;
  TypeId: LongInt;
  TypeName: string;
  Dummy: Int64;
  LTypeId: LongInt;
  TypeSig: string;
begin
  Result := '';
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild = nil) or (ParamChild.NodeKind <> gnkParameterDecl) then
          Continue;
        TypeName := '';
        TypeChild := nil;
        if ParamChild.ChildCount > 0 then
        begin
          TypeChild := ParamChild.ChildAt(0);
          if TypeChild <> nil then
            TypeName := LowerCase(TypeChild.Text);
        end;
        TypeId := 0;
        if TypeChild <> nil then
        begin
          TypeId := ResolveTypeIdForOwner(Ctx, 
            TypeChild.Text,
            NormalizeUnitIdentity(Ctx.CurrentProcessingUnitId)
          );
          if TypeId <= 0 then
            TypeId := ResolveTypeIdForOwner(Ctx, 
              TypeChild.Text,
              NormalizeUnitIdentity(Ctx.UnitGraph.RootName)
            );
          if TypeId <= 0 then
            TypeId := ResolveTypeId(Ctx, TypeChild.Text);
        end;
        TypeSig := TypeSignatureForTypeId(Ctx, TypeId);
        if TypeSig <> '' then
          Result := Result + TypeSig
        else if (TypeName = 'string') or (TypeName = 'ansistring') then
          Result := Result + 's'
        else if (TypeName = 'boolean') or (TypeName = 'bool') then
          Result := Result + 'b'
        else if (TypeChild <> nil) and TypeMetaIsRecord(Ctx.Model, TypeChild.Text) then
          Result := Result + 'r'
        else if (TypeChild <> nil) and TypeIsInterfaceByName(Ctx.Model, TypeChild.Text) then
          Result := Result + 'f'
        else if SameText(TypeName, 'integer') or SameText(TypeName, 'longint') or
          SameText(TypeName, 'longword') or SameText(TypeName, 'cardinal') or
          SameText(TypeName, 'dword') or SameText(TypeName, 'smallint') or
          SameText(TypeName, 'word') or SameText(TypeName, 'byte') or
          SameText(TypeName, 'shortint') or SameText(TypeName, 'int64') or
          SameText(TypeName, 'qword') or SameText(TypeName, 'uint64') or
          SameText(TypeName, 'sizeint') or SameText(TypeName, 'sizeuint') or
          SameText(TypeName, 'uint32') or SameText(TypeName, 'int32') or
          SameText(TypeName, 'uint16') or SameText(TypeName, 'uint8') or
          SameText(TypeName, 'int16') or SameText(TypeName, 'int8') or
          SameText(TypeName, 'ptruint') or SameText(TypeName, 'ptrint') or
          SameText(TypeName, 'nativeint') or SameText(TypeName, 'nativeuint') or
          SameText(TypeName, 'char') or SameText(TypeName, 'ansichar') or
          SameText(TypeName, 'widechar') then
          Result := Result + 'i'
        else if (TypeChild <> nil) then
        begin
          LTypeId := Ctx.Model.FindTypeByName(TypeChild.Text);
          if (LTypeId > 0) and
            SameText(Ctx.Model.TypeAt(LTypeId - 1).Kind, 'class') then
            Result := Result + 'c'
          else if TypeMetaIsClass(Ctx.Model, TypeChild.Text) then
            Result := Result + 'c'
          else if TypeMetaSize(Ctx.Model, TypeChild.Text) > 0 then
            Result := Result + 'p'
          else
            Result := Result + 'i';
        end
        else
          Result := Result + 'i';
      end;
      Exit;
    end;
  end;
end;


function DeclParamSignatureMatchesArgs(const Ctx: TSemaOverloadContext; 
  const ADecl: TGreenNode;
  const AArgSignature: string;
  const AArgCount: LongInt
): Boolean;
var
  I: LongInt;
  ParamSignature: string;
begin
  ParamSignature := GetParamSignature(Ctx, ADecl);
  if (AArgCount >= 0) and (Length(ParamSignature) >= AArgCount) and
    SameText(Copy(ParamSignature, 1, AArgCount), AArgSignature) then
    Exit(True);
  { Char → String promotion: 'i' arg matches 's' param }
  if (AArgCount > 0) and (Length(ParamSignature) >= AArgCount) then
  begin
    Result := True;
    for I := 1 to AArgCount do
    begin
      if (ParamSignature[I] = 's') and (I <= Length(AArgSignature)) and
        (AArgSignature[I] = 'i') then
        Continue;
      if (I <= Length(AArgSignature)) and
        SameText(ParamSignature[I], AArgSignature[I]) then
        Continue;
      Result := False;
      Break;
    end;
  end
  else
    Result := False;
end;


function DeclParamTypesExactMatch(const Ctx: TSemaOverloadContext; 
  const ADecl: TGreenNode;
  const AOwnerUnitId: string;
  const AArgTypeIds: TTypeIdArray;
  const AArgCount: LongInt
): Boolean;
var
  Child: TGreenNode;
  ChildIndex: LongInt;
  LeftFact: TSemanticScalarTypeFact;
  RightFact: TSemanticScalarTypeFact;
  ParamEntryIndex: LongInt;
  ParamDecl: TGreenNode;
  ParamIndex: LongInt;
  ParamTypeId: LongInt;
begin
  Result := False;
  if (ADecl = nil) or (AArgCount < 0) or
    (Length(AArgTypeIds) <> AArgCount) then
    Exit;

  for ChildIndex := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(ChildIndex);
    if (Child = nil) or (Child.NodeKind <> gnkParameterList) then
      Continue;

    ParamIndex := 0;
    for ParamEntryIndex := 0 to Child.ChildCount - 1 do
    begin
      ParamDecl := Child.ChildAt(ParamEntryIndex);
      if (ParamDecl = nil) or (ParamDecl.NodeKind <> gnkParameterDecl) then
        Continue;
      if ParamIndex >= AArgCount then
        Break;
      ParamTypeId := ParamDeclTypeId(Ctx, ParamDecl, AOwnerUnitId);
      if (ParamTypeId > 0) and (AArgTypeIds[ParamIndex] > 0) and
        (CanonicalTypeId(Ctx, ParamTypeId) <>
         CanonicalTypeId(Ctx, AArgTypeIds[ParamIndex])) then
      begin
        if not (
          Ctx.Model.GetTypeScalarFact(CanonicalTypeId(Ctx, ParamTypeId), LeftFact) and
          Ctx.Model.GetTypeScalarFact(CanonicalTypeId(Ctx, AArgTypeIds[ParamIndex]), RightFact) and
          (LeftFact.Kind in [sskBool, sskInt, sskFloat]) and
          (RightFact.Kind = LeftFact.Kind) and
          (RightFact.BitWidth = LeftFact.BitWidth) and
          (RightFact.Signed = LeftFact.Signed)
        ) then
          Exit(False);
      end;
      Inc(ParamIndex);
    end;
    Exit(ParamIndex = AArgCount);
  end;
  Result := AArgCount = 0;
end;


function DeclParamTypesCompatibleMatch(const Ctx: TSemaOverloadContext; 
  const ADecl: TGreenNode;
  const AOwnerUnitId: string;
  const AArgTypeIds: TTypeIdArray;
  const AArgCount: LongInt
): Boolean;
var
  Child: TGreenNode;
  ChildIndex: LongInt;
  ParamEntryIndex: LongInt;
  ParamDecl: TGreenNode;
  ParamIndex: LongInt;
  ParamTypeId: LongInt;
begin
  Result := False;
  if (ADecl = nil) or (AArgCount < 0) or
    (Length(AArgTypeIds) <> AArgCount) then
    Exit;

  for ChildIndex := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(ChildIndex);
    if (Child = nil) or (Child.NodeKind <> gnkParameterList) then
      Continue;

    ParamIndex := 0;
    for ParamEntryIndex := 0 to Child.ChildCount - 1 do
    begin
      ParamDecl := Child.ChildAt(ParamEntryIndex);
      if (ParamDecl = nil) or (ParamDecl.NodeKind <> gnkParameterDecl) then
        Continue;
      if ParamIndex >= AArgCount then
        Break;
      ParamTypeId := ParamDeclTypeId(Ctx, ParamDecl, AOwnerUnitId);
      if (ParamTypeId > 0) and (AArgTypeIds[ParamIndex] > 0) and
        not AreTypesCompatible(Ctx, ParamTypeId, AArgTypeIds[ParamIndex]) then
        Exit(False);
      Inc(ParamIndex);
    end;
    Exit(ParamIndex = AArgCount);
  end;
  Result := AArgCount = 0;
end;


function CanonicalTypeId(const Ctx: TSemaOverloadContext; const ATypeId: LongInt): LongInt;
var
  CurrentTypeId: LongInt;
  Depth: LongInt;
  Meta: TTypeMetadata;
begin
  CurrentTypeId := ATypeId;
  Depth := 0;
  while (CurrentTypeId > 0) and (CurrentTypeId <= Ctx.Model.TypeCount) and
    (Depth < 16) do
  begin
    if Ctx.Model.GetTypeMeta(CurrentTypeId, Meta) and
      (Meta.AliasTargetTypeId > 0) and
      (Meta.AliasTargetTypeId <> CurrentTypeId) then
      CurrentTypeId := Meta.AliasTargetTypeId
    else
      Break;
    Inc(Depth);
  end;
  Result := CurrentTypeId;
end;


function ParamDeclTypeId(const Ctx: TSemaOverloadContext; 
  const AParamDecl: TGreenNode;
  const AOwnerUnitId: string
): LongInt;
var
  TypeChild: TGreenNode;
begin
  Result := 0;
  if (AParamDecl = nil) or (AParamDecl.ChildCount <= 0) then
    Exit;
  TypeChild := AParamDecl.ChildAt(0);
  if (TypeChild = nil) or (TypeChild.NodeKind <> gnkIdentifier) then
    Exit;
  Result := ResolveTypeIdForOwner(Ctx, TypeChild.Text, AOwnerUnitId);
  if Result <= 0 then
    Result := ResolveTypeIdForOwner(Ctx, 
      TypeChild.Text,
      NormalizeUnitIdentity(Ctx.UnitGraph.RootName)
    );
  if Result <= 0 then
    Result := ResolveTypeId(Ctx, TypeChild.Text);
end;


function AreTypesCompatible(const Ctx: TSemaOverloadContext; 
  const ALhsTypeId, ARhsTypeId: LongInt): Boolean;
var
  IntIds: array[0..16] of LongInt;
  StrIds: array[0..4] of LongInt;
  I: LongInt;
  LhsIsInt, RhsIsInt, LhsIsStr, RhsIsStr: Boolean;
  CharTypeId, WideCharTypeId: LongInt;
  CanonicalLhsTypeId, CanonicalRhsTypeId: LongInt;
begin
  if ALhsTypeId = ARhsTypeId then
    Exit(True);
  if (ALhsTypeId = 0) or (ARhsTypeId = 0) then
    Exit(True);

  CanonicalLhsTypeId := CanonicalTypeId(Ctx, ALhsTypeId);
  CanonicalRhsTypeId := CanonicalTypeId(Ctx, ARhsTypeId);
  if CanonicalLhsTypeId = CanonicalRhsTypeId then
    Exit(True);
  if Ctx.Model.IsTypeDescendantOf(CanonicalRhsTypeId, CanonicalLhsTypeId) then
    Exit(True);
  if Ctx.Model.IsTypeDescendantOf(CanonicalLhsTypeId, CanonicalRhsTypeId) then
    Exit(True);
  if IsPointerTypeId(Ctx, CanonicalLhsTypeId) and IsPointerTypeId(Ctx, CanonicalRhsTypeId) then
    Exit(True);

  IntIds[0] := Ctx.Model.FindTypeByName('Byte');
  IntIds[1] := Ctx.Model.FindTypeByName('Word');
  IntIds[2] := Ctx.Model.FindTypeByName('LongInt');
  IntIds[3] := Ctx.Model.FindTypeByName('Integer');
  IntIds[4] := Ctx.Model.FindTypeByName('Int64');
  IntIds[5] := Ctx.Model.FindTypeByName('QWord');
  IntIds[6] := Ctx.Model.FindTypeByName('LongWord');
  IntIds[7] := Ctx.Model.FindTypeByName('ShortInt');
  IntIds[8] := Ctx.Model.FindTypeByName('SmallInt');
  IntIds[9] := Ctx.Model.FindTypeByName('Int32');
  IntIds[10] := Ctx.Model.FindTypeByName('UInt32');
  IntIds[11] := Ctx.Model.FindTypeByName('UInt64');
  IntIds[12] := Ctx.Model.FindTypeByName('WideChar');
  IntIds[13] := Ctx.Model.FindTypeByName('Single');
  IntIds[14] := Ctx.Model.FindTypeByName('Double');
  IntIds[15] := Ctx.Model.FindTypeByName('AnsiChar');
  IntIds[16] := Ctx.Model.FindTypeByName('Char');

  LhsIsInt := False;
  RhsIsInt := False;
  for I := 0 to High(IntIds) do
  begin
    if CanonicalLhsTypeId = IntIds[I] then LhsIsInt := True;
    if CanonicalRhsTypeId = IntIds[I] then RhsIsInt := True;
  end;
  if LhsIsInt and RhsIsInt then
    Exit(True);

  StrIds[0] := Ctx.Model.FindTypeByName('AnsiString');
  StrIds[1] := Ctx.Model.FindTypeByName('ShortString');
  StrIds[2] := Ctx.Model.FindTypeByName('WideString');
  StrIds[3] := Ctx.Model.FindTypeByName('UnicodeString');
  StrIds[4] := Ctx.Model.FindTypeByName('RawByteString');

  LhsIsStr := False;
  RhsIsStr := False;
  for I := 0 to High(StrIds) do
  begin
    if CanonicalLhsTypeId = StrIds[I] then LhsIsStr := True;
    if CanonicalRhsTypeId = StrIds[I] then RhsIsStr := True;
  end;
  if LhsIsStr and RhsIsStr then
    Exit(True);

  if CanonicalLhsTypeId = Ctx.Model.FindTypeByName('Boolean') then
    Exit(CanonicalRhsTypeId = Ctx.Model.FindTypeByName('Boolean'));

  CharTypeId := Ctx.Model.FindTypeByName('Char');
  WideCharTypeId := Ctx.Model.FindTypeByName('WideChar');
  if LhsIsStr and ((CanonicalRhsTypeId = CharTypeId) or
    (CanonicalRhsTypeId = WideCharTypeId)) then
    Exit(True);
  if ((CanonicalLhsTypeId = CharTypeId) or
    (CanonicalLhsTypeId = WideCharTypeId)) and RhsIsStr then
    Exit(True);
  if ((CanonicalLhsTypeId = CharTypeId) or
    (CanonicalLhsTypeId = WideCharTypeId)) and
    ((CanonicalRhsTypeId = CharTypeId) or
     (CanonicalRhsTypeId = WideCharTypeId)) then
    Exit(True);

  { String literal → PAnsiChar / PChar implicit conversion }
  if RhsIsStr and IsPointerTypeId(Ctx, CanonicalLhsTypeId) then
    Exit(True);

  { Single-char string literal → Char/AnsiChar/WideChar implicit conversion }
  if RhsIsStr and ((CanonicalLhsTypeId = CharTypeId) or
    (CanonicalLhsTypeId = WideCharTypeId) or
    (CanonicalLhsTypeId = Ctx.Model.FindTypeByName('AnsiChar'))) then
    Exit(True);

  Result := False;
end;


function IsPointerTypeId(const Ctx: TSemaOverloadContext; const ATypeId: LongInt): Boolean;
var
  CurrentTypeId: LongInt;
  Fact: TSemanticScalarTypeFact;
begin
  Result := False;
  CurrentTypeId := CanonicalTypeId(Ctx, ATypeId);
  while (CurrentTypeId > 0) and (CurrentTypeId <= Ctx.Model.TypeCount) do
  begin
    if Ctx.Model.GetTypeScalarFact(CurrentTypeId, Fact) and
      (Fact.Kind = sskPointer) then
      Exit(True);
    CurrentTypeId := Ctx.Model.TypeAt(CurrentTypeId - 1).ParentTypeId;
  end;
end;


function ResolveTypeId(const Ctx: TSemaOverloadContext; const ATypeName: string): LongInt;
begin
  Result := ResolveTypeIdForOwner(Ctx, ATypeName, '', True);
end;

function ResolveTypeIdForOwner(const Ctx: TSemaOverloadContext; 
  const ATypeName: string;
  const APreferredOwnerUnitId: string;
  const AAllowDirectImportSearch: Boolean
): LongInt;
var
  CandidateSeen: Boolean;
  DirectImportMatchCount: LongInt;
  DotPos: LongInt;
  I: LongInt;
  Index: LongInt;
  NormalizedOwnerUnitId: string;
  PreferredMatchCount: LongInt;
  QualifiedOwnerUnitId: string;
  ShortTypeName: string;
  Symbol: TSemanticSymbol;
  UniqueTypeId: LongInt;
begin
  if ATypeName = '' then
    Exit(0);
  if SameText(ATypeName, 'String') then
    Exit(Ctx.Model.FindTypeByName('AnsiString'));
  if SameText(ATypeName, 'Cardinal') then
    Exit(Ctx.Model.FindTypeByName('LongWord'));
  if SameText(ATypeName, 'Real') then
    Exit(Ctx.Model.FindTypeByName('Double'));
  if SameText(ATypeName, 'Extended') then
    Exit(Ctx.Model.FindTypeByName('Double'));

  DotPos := 0;
  for I := Length(ATypeName) downto 1 do
    if ATypeName[I] = '.' then
    begin
      DotPos := I;
      Break;
    end;
  if (DotPos > 1) and (DotPos < Length(ATypeName)) then
  begin
    QualifiedOwnerUnitId := NormalizeUnitIdentity(
      Copy(ATypeName, 1, DotPos - 1)
    );
    ShortTypeName := Copy(ATypeName, DotPos + 1, MaxInt);
    if (QualifiedOwnerUnitId <> '') and (ShortTypeName <> '') then
    begin
      PreferredMatchCount := 0;
      UniqueTypeId := 0;
      for Index := 0 to Ctx.Model.SymbolCount - 1 do
      begin
        Symbol := Ctx.Model.SymbolAt(Index);
        if SameText(Symbol.Kind, 'type') and
          SameText(Symbol.Name, ShortTypeName) and
          SameText(Symbol.OwnerUnitId, QualifiedOwnerUnitId) and
          (Symbol.TypeId > 0) and (Symbol.TypeId <= Ctx.Model.TypeCount) then
        begin
          Inc(PreferredMatchCount);
          if UniqueTypeId = 0 then
            UniqueTypeId := Symbol.TypeId
          else if UniqueTypeId <> Symbol.TypeId then
          begin
            if SameText(Ctx.Model.TypeAt(Symbol.TypeId - 1).Kind, 'class') or
              SameText(Ctx.Model.TypeAt(Symbol.TypeId - 1).Kind, 'interface') then
              UniqueTypeId := Symbol.TypeId
            else if not (SameText(Ctx.Model.TypeAt(UniqueTypeId - 1).Kind, 'class') or
              SameText(Ctx.Model.TypeAt(UniqueTypeId - 1).Kind, 'interface')) then
              Exit(0);
          end;
        end;
      end;
      if PreferredMatchCount >= 1 then
        Exit(UniqueTypeId);
    end;
  end;

  NormalizedOwnerUnitId := NormalizeUnitIdentity(APreferredOwnerUnitId);
  if NormalizedOwnerUnitId <> '' then
  begin
    PreferredMatchCount := 0;
    UniqueTypeId := 0;
    for Index := 0 to Ctx.Model.SymbolCount - 1 do
    begin
      Symbol := Ctx.Model.SymbolAt(Index);
      if SameText(Symbol.Kind, 'type') and
        SameText(Symbol.Name, ATypeName) and
        SameText(Symbol.OwnerUnitId, NormalizedOwnerUnitId) and
        (Symbol.TypeId > 0) and (Symbol.TypeId <= Ctx.Model.TypeCount) then
      begin
        Inc(PreferredMatchCount);
        if UniqueTypeId = 0 then
          UniqueTypeId := Symbol.TypeId
        else if UniqueTypeId <> Symbol.TypeId then
        begin
          if SameText(Ctx.Model.TypeAt(Symbol.TypeId - 1).Kind, 'class') or
            SameText(Ctx.Model.TypeAt(Symbol.TypeId - 1).Kind, 'interface') then
            UniqueTypeId := Symbol.TypeId
          else if SameText(Ctx.Model.TypeAt(UniqueTypeId - 1).Kind, 'class') or
            SameText(Ctx.Model.TypeAt(UniqueTypeId - 1).Kind, 'interface') then
            { Keep existing class/interface UniqueTypeId }
          else
            { Neither is class/interface yet — prefer later entry }
            UniqueTypeId := Symbol.TypeId;
        end;
      end;
    end;
    if PreferredMatchCount >= 1 then
      Exit(UniqueTypeId);

    if AAllowDirectImportSearch then
    begin
      DirectImportMatchCount := 0;
      UniqueTypeId := 0;
      for Index := 0 to Ctx.Model.SymbolCount - 1 do
      begin
        Symbol := Ctx.Model.SymbolAt(Index);
        if SameText(Symbol.Kind, 'type') and
          SameText(Symbol.Name, ATypeName) and
          UnitDirectlyImports(Ctx, NormalizedOwnerUnitId, Symbol.OwnerUnitId) and
          (Symbol.TypeId > 0) and (Symbol.TypeId <= Ctx.Model.TypeCount) then
        begin
          Inc(DirectImportMatchCount);
          { Prefer later entry (full definition over forward declaration) }
          UniqueTypeId := Symbol.TypeId;
        end;
      end;
      if DirectImportMatchCount >= 1 then
        Exit(UniqueTypeId);
    end;
  end;

  CandidateSeen := False;
  UniqueTypeId := 0;
  for Index := 0 to Ctx.Model.SymbolCount - 1 do
  begin
    Symbol := Ctx.Model.SymbolAt(Index);
    if SameText(Symbol.Kind, 'type') and SameText(Symbol.Name, ATypeName) and
      (Symbol.TypeId > 0) and (Symbol.TypeId <= Ctx.Model.TypeCount) then
    begin
      { Prefer later type entry (full definition over forward declaration) }
      UniqueTypeId := Symbol.TypeId;
      CandidateSeen := True;
    end;
  end;
  if CandidateSeen then
    Exit(UniqueTypeId);

  Result := Ctx.Model.FindTypeByName(ATypeName);
end;


function TypeSignatureForTypeId(const Ctx: TSemaOverloadContext; const ATypeId: LongInt): string;
var
  Fact: TSemanticScalarTypeFact;
  TypeName: string;
  TypeInfo: TSemanticType;
  Dummy: Int64;
  Meta: TTypeMetadata;
begin
  Result := '';
  if (ATypeId <= 0) or (ATypeId > Ctx.Model.TypeCount) then
    Exit;

  TypeInfo := Ctx.Model.TypeAt(ATypeId - 1);
  TypeName := TypeInfo.Name;
  if (TypeName = '') then
    Exit;
  if SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString') or
    SameText(TypeName, 'RawByteString') or
    SameText(TypeName, 'ShortString') or SameText(TypeName, 'WideString') or
    SameText(TypeName, 'UnicodeString') then
    Exit('s');
  if SameText(TypeName, 'Boolean') then
    Exit('b');
  if SameText(TypeName, 'Integer') or SameText(TypeName, 'LongInt') or
    SameText(TypeName, 'LongWord') or SameText(TypeName, 'Cardinal') or
    SameText(TypeName, 'DWord') or SameText(TypeName, 'SmallInt') or
    SameText(TypeName, 'Word') or SameText(TypeName, 'Byte') or
    SameText(TypeName, 'ShortInt') or SameText(TypeName, 'Int64') or
    SameText(TypeName, 'QWord') or SameText(TypeName, 'UInt64') or
    SameText(TypeName, 'SizeInt') or SameText(TypeName, 'SizeUInt') or
    SameText(TypeName, 'UInt32') or SameText(TypeName, 'Int32') or
    SameText(TypeName, 'UInt16') or SameText(TypeName, 'UInt8') or
    SameText(TypeName, 'Int16') or SameText(TypeName, 'Int8') or
    SameText(TypeName, 'PtrUInt') or SameText(TypeName, 'PtrInt') or
    SameText(TypeName, 'NativeInt') or SameText(TypeName, 'NativeUInt') or
    SameText(TypeName, 'Char') or SameText(TypeName, 'AnsiChar') or
    SameText(TypeName, 'WideChar') then
    Exit('i');
  if Ctx.Model.GetTypeScalarFact(ATypeId, Fact) and (Fact.Kind = sskPointer) then
    Exit('p');
  if Ctx.Model.GetTypeMeta(ATypeId, Meta) then
  begin
    if Meta.IsRecord then
      Exit('r');
    if TypeIsInterfaceByName(Ctx.Model, TypeName) then
      Exit('f');
    if SameText(TypeInfo.Kind, 'class') then
      Exit('c');
    Exit('p');
  end;
  if TypeMetaIsRecord(Ctx.Model, TypeName) then
    Exit('r');
  if TypeIsInterfaceByName(Ctx.Model, TypeName) then
    Exit('f');
  if TypeMetaIsClass(Ctx.Model, TypeName) then
    Exit('c');
  if TypeMetaSize(Ctx.Model, TypeName) > 0 then
    Exit('p');
  Result := 'i';
end;
