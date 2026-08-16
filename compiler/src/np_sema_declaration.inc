procedure TSemanticAnalyzer.ProcessVarSection(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I, J: LongInt;
  Child, TypeChild: TGreenNode;
  SymbolId: LongInt;
  TypeId: LongInt;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkVarDecl) then
      Continue;
    TypeId := 0;
    for J := 0 to Child.ChildCount - 1 do
    begin
      TypeChild := Child.ChildAt(J);
      if (TypeChild <> nil) and (TypeChild.NodeKind = gnkIdentifier) then
      begin
        TypeId := ResolveTypeIdForOwner(TypeChild.Text, AOwnerUnitId);
        if (TypeId = 0) and (Pos('<', TypeChild.Text) > 0) then
          TypeId := ResolveOrInstantiateInlineGeneric(TypeChild.Text, AOwnerUnitId);
        Break;
      end;
    end;
    SymbolId := FModel.AddSymbol(Child.Text, 'variable', AOwnerUnitId, TypeId,
      Child.ByteOffset);
    if FCurrentScopeId > 0 then
      FModel.SetSymbolScope(SymbolId, FCurrentScopeId);
  end;
end;

procedure TSemanticAnalyzer.ProcessConstSection(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I, J: LongInt;
  Child, ValueChild: TGreenNode;
  Value: Int64;
  FloatValue: Double;
  StringValue: string;
  ArrOperand: string;
  SeededValue: Boolean;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkConstDecl) then
      Continue;
    FModel.AddSymbol(Child.Text, 'constant', AOwnerUnitId, 0,
      Child.ByteOffset);
    SeededValue := False;
    { Typed const array `Name: array[L..H] of T = (...)`:
      parser keeps type child, drops paren initializer. Still register
      arr metadata so High/SizeOf/open-array args use arrvar not @Name(). }
    for J := 0 to Child.ChildCount - 1 do
    begin
      ValueChild := Child.ChildAt(J);
      if (ValueChild <> nil) and (ValueChild.NodeKind = gnkArrayType) then
      begin
        RegisterArrayVarMetadata(Child.Text, ValueChild, ArrOperand);
        SeededValue := True;
        Break;
      end;
    end;
    if SeededValue then
      Continue;
    for J := 0 to Child.ChildCount - 1 do
    begin
      ValueChild := Child.ChildAt(J);
      if EvaluateIntegerConstant(ValueChild, Value) then
      begin
        FModel.AddConstValue(Child.Text, Value);
        Break;
      end;
      if EvaluateFloatConstant(ValueChild, FloatValue) then
      begin
        FModel.AddFloatConstValue(Child.Text, FloatValue);
        Break;
      end;
      if EvaluateStringConstant(ValueChild, StringValue) then
      begin
        FModel.AddStringConstValue(Child.Text, StringValue);
        Break;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.FinalizeConstSections;
  procedure FixSection(const ANode: TGreenNode);
  var
    J, K: LongInt;
    Child, ValueChild: TGreenNode;
    Value: Int64;
    FloatValue: Double;
    StringValue: string;
  begin
    if ANode = nil then
      Exit;
    for J := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(J);
      if (Child = nil) or (Child.NodeKind <> gnkConstDecl) then
        Continue;
      { 值已登记(任意类型)则 skip; 只补登首次 Evaluate 失败的常量。 }
      if FModel.LookupConstValue(Child.Text, Value) or
        FModel.LookupFloatConstValue(Child.Text, FloatValue) or
        FModel.LookupStringConstValue(Child.Text, StringValue) then
        Continue;
      for K := 0 to Child.ChildCount - 1 do
      begin
        ValueChild := Child.ChildAt(K);
        if EvaluateIntegerConstant(ValueChild, Value) then
        begin
          FModel.AddConstValue(Child.Text, Value);
          Break;
        end;
        if EvaluateFloatConstant(ValueChild, FloatValue) then
        begin
          FModel.AddFloatConstValue(Child.Text, FloatValue);
          Break;
        end;
        if EvaluateStringConstant(ValueChild, StringValue) then
        begin
          FModel.AddStringConstValue(Child.Text, StringValue);
          Break;
        end;
      end;
    end;
  end;
  procedure ScanNode(const ANode: TGreenNode);
  var
    I: LongInt;
    Child: TGreenNode;
  begin
    if ANode = nil then
      Exit;
    if ANode.NodeKind = gnkConstSection then
      FixSection(ANode);
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child <> nil then
        ScanNode(Child);
    end;
  end;
var
  I: LongInt;
begin
  for I := 0 to FImportedUnitTrees.Count - 1 do
    ScanNode(FImportedUnitTrees[I].RootNode);
  if (FRootAst <> nil) and (FRootAst.RootNode <> nil) then
    ScanNode(FRootAst.RootNode);
end;

procedure TSemanticAnalyzer.ProcessProcedureDecl(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  SymbolId: LongInt;
  Index, J: LongInt;
  Child, ParamChild: TGreenNode;
  CallableScopeId, SavedScopeId: LongInt;
  ParamTypeId: LongInt;
  ParamCount: LongInt;
  SymCountBefore: LongInt;
begin
  if ANode = nil then
    Exit;
  SymbolId := FModel.AddSymbol(ANode.Text, 'procedure', AOwnerUnitId, 0,
    ANode.ByteOffset);
  FModel.AddTypedHirNode('procedure-decl', ANode.Text, SymbolId, 0, '');

  CallableScopeId := FModel.AddScope(skCallable, ANode.Text, FCurrentScopeId);
  SavedScopeId := FCurrentScopeId;
  FCurrentScopeId := CallableScopeId;
  ParamCount := 0;

  for Index := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(Index);
    if Child = nil then
      Continue;
    if Child.NodeKind = gnkParameterList then
    begin
      for J := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(J);
        if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
        begin
          ParamTypeId := ParamDeclTypeId(ParamChild, AOwnerUnitId);
          SymbolId := FModel.AddSymbol(
            StripParamModifier(ParamChild.Text),
            'parameter',
            AOwnerUnitId,
            ParamTypeId,
            ParamChild.ByteOffset);
          FModel.SetSymbolScope(SymbolId, CallableScopeId);
          Inc(ParamCount);
        end;
      end;
    end
    else if Child.NodeKind = gnkVarSection then
    begin
      SymCountBefore := FModel.SymbolCount;
      ProcessVarSection(Child, AOwnerUnitId);
      for ParamTypeId := SymCountBefore + 1 to FModel.SymbolCount do
        FModel.SetSymbolScope(ParamTypeId, CallableScopeId);
    end
    else if Child.NodeKind = gnkProcedureDecl then
      ProcessProcedureDecl(Child, AOwnerUnitId)
    else if Child.NodeKind = gnkFunctionDecl then
      ProcessFunctionDecl(Child, AOwnerUnitId)
    else if Child.NodeKind = gnkBeginBlock then
    begin
      RegisterProcedureBody(ANode.Text, Child, ANode, AOwnerUnitId);
      Break;
    end
    else if Child.NodeKind = gnkAsmBlock then
    begin
      RegisterProcedureBody(ANode.Text, Child, ANode, AOwnerUnitId);
      Break;
    end;
  end;

  FModel.SetSymbolParamCount(SymbolId, ParamCount);
  FModel.SetSymbolMinParamCount(SymbolId, CountRequiredDeclParams(ANode));
  FModel.SetSymbolParamSignature(SymbolId, GetParamSignature(ANode));
  FCurrentScopeId := SavedScopeId;
end;

procedure TSemanticAnalyzer.ProcessFunctionDecl(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  SymbolId: LongInt;
  TypeId: LongInt;
  J: LongInt;
  Child, ParamChild: TGreenNode;
  CallableScopeId, SavedScopeId: LongInt;
  ParamTypeId: LongInt;
  ParamCount: LongInt;
  SymCountBefore: LongInt;
begin
  if ANode = nil then
    Exit;
  TypeId := 0;
  for J := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkIdentifier) then
    begin
      TypeId := ResolveTypeIdForOwner(Child.Text, AOwnerUnitId);
      Break;
    end;
  end;
  SymbolId := FModel.AddSymbol(ANode.Text, 'function', AOwnerUnitId, TypeId,
    ANode.ByteOffset);
  FModel.AddTypedHirNode('function-decl', ANode.Text, SymbolId, TypeId, '');

  CallableScopeId := FModel.AddScope(skCallable, ANode.Text, FCurrentScopeId);
  SavedScopeId := FCurrentScopeId;
  FCurrentScopeId := CallableScopeId;
  ParamCount := 0;

  for J := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(J);
    if Child = nil then
      Continue;
    if Child.NodeKind = gnkParameterList then
    begin
      for TypeId := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(TypeId);
        if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
        begin
          ParamTypeId := ParamDeclTypeId(ParamChild, AOwnerUnitId);
          SymbolId := FModel.AddSymbol(
            StripParamModifier(ParamChild.Text),
            'parameter',
            AOwnerUnitId,
            ParamTypeId,
            ParamChild.ByteOffset);
          FModel.SetSymbolScope(SymbolId, CallableScopeId);
          Inc(ParamCount);
        end;
      end;
    end
    else if Child.NodeKind = gnkVarSection then
    begin
      SymCountBefore := FModel.SymbolCount;
      ProcessVarSection(Child, AOwnerUnitId);
      for ParamTypeId := SymCountBefore + 1 to FModel.SymbolCount do
        FModel.SetSymbolScope(ParamTypeId, CallableScopeId);
    end
    else if Child.NodeKind = gnkProcedureDecl then
      ProcessProcedureDecl(Child, AOwnerUnitId)
    else if Child.NodeKind = gnkFunctionDecl then
      ProcessFunctionDecl(Child, AOwnerUnitId)
    else if Child.NodeKind = gnkBeginBlock then
    begin
      RegisterProcedureBody(ANode.Text, Child, ANode, AOwnerUnitId);
      Break;
    end
    else if Child.NodeKind = gnkAsmBlock then
    begin
      RegisterProcedureBody(ANode.Text, Child, ANode, AOwnerUnitId);
      Break;
    end;
  end;

  FModel.SetSymbolParamCount(SymbolId, ParamCount);
  FModel.SetSymbolMinParamCount(SymbolId, CountRequiredDeclParams(ANode));
  FModel.SetSymbolParamSignature(SymbolId, GetParamSignature(ANode));
  FCurrentScopeId := SavedScopeId;
end;

procedure TSemanticAnalyzer.ProcessEnumType(const ANode: TGreenNode;
  const AOwnerUnitId: string; const ATypeId: LongInt);
var
  I: LongInt;
  Child: TGreenNode;
  Ordinal: Int64;
begin
  if ANode = nil then
    Exit;
  Ordinal := 0;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkIdentifier) then
    begin
      FModel.AddSymbol(Child.Text, 'enum-value', AOwnerUnitId, ATypeId,
        Child.ByteOffset);
      FModel.AddConstValue(Child.Text, Ordinal);
      Inc(Ordinal);
    end;
  end;
end;

procedure TSemanticAnalyzer.ProcessRecordFields(const ANode: TGreenNode;
  const AOwnerUnitId: string; const ATypeId: LongInt);
var
  I: LongInt;
  Child: TGreenNode;
  RecordScopeId: LongInt;
  FieldTypeId: LongInt;
  TypeChild: TGreenNode;
  J: LongInt;
  FieldIndex: LongInt;
  NameNode: TGreenNode;
  SymbolId: LongInt;
  RecName: string;
  Meta: TTypeMetadata;
  FieldMeta: TTypeMetadata;
  Field: TFieldMeta;
begin
  if ANode = nil then
    Exit;
  FillChar(Meta, SizeOf(Meta), 0);
  RecName := FModel.TypeAt(ATypeId - 1).Name;
  RecordScopeId := FModel.AddScope(skRecord, '', FCurrentScopeId);
  FieldIndex := 0;
  Meta.TypeId := ATypeId;
  Meta.IsRecord := True;
  Meta.VmtCount := 0;
  Meta.ParentClassId := 0;
  Meta.ParentClassName := '';
  Meta.Interfaces := '';
  Meta.ArrElemSize := 0;
  Meta.ArrElemType := '';
  Meta.ArrLowBound := 0;
  Meta.ArrHighBound := -1;
  Meta.ArrLength := 0;
  Meta.IsStaticArray := False;
  Meta.Fields := nil;
  Meta.VmtSlots := nil;
  Meta.RetPtrMethods := nil;
  Meta.Properties := nil;
  Meta.InterfaceSlots := nil;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if Child.NodeKind = gnkClassMethod then
    begin
      if Child.ChildCount > 0 then
      begin
        NameNode := Child.ChildAt(0);
        if (NameNode <> nil) and (NameNode.NodeKind = gnkIdentifier) then
        begin
          SymbolId := FModel.AddSymbol(
            RecName + '.' + NameNode.Text,
            'method', AOwnerUnitId, ATypeId, Child.ByteOffset);
          FModel.SetSymbolParamCount(SymbolId, CountDeclParams(Child));
          FModel.SetSymbolMinParamCount(SymbolId, CountRequiredDeclParams(Child));
          FModel.SetSymbolParamSignature(SymbolId, GetParamSignature(Child));
          FModel.SetSymbolReturnTypeId(SymbolId,
            DeclReturnTypeId(Child, AOwnerUnitId));
          FModel.SetSymbolScope(SymbolId, RecordScopeId);
        end;
      end;
      Continue;
    end;
    if Child.NodeKind = gnkClassProperty then
    begin
      { Record properties: register declared read/write targets plus the
        string-property marker so `S := Rec.Prop` resolves to the real getter
        instead of residual-calling @Type.Prop (M2 B3b: TGreenNode.Text). }
      for J := 0 to Child.ChildCount - 1 do
      begin
        NameNode := Child.ChildAt(J);
        if (NameNode <> nil) and (NameNode.NodeKind = gnkIdentifier) then
        begin
          if Pos('read:', NameNode.Text) = 1 then
            FModel.AddStringConstValue(
              RecName + '.' + Child.Text + '$read',
              Copy(NameNode.Text, 6, Length(NameNode.Text)))
          else if Pos('write:', NameNode.Text) = 1 then
            FModel.AddStringConstValue(
              RecName + '.' + Child.Text + '$write',
              Copy(NameNode.Text, 7, Length(NameNode.Text)))
          else if SameText(NameNode.Text, 'String') or
            SameText(NameNode.Text, 'AnsiString') then
            FModel.AddConstValue(RecName + '$ret_str_' + Child.Text, 1);
        end;
      end;
      Continue;
    end;
    if Child.NodeKind <> gnkVarDecl then
      Continue;
    FieldTypeId := 0;
    TypeChild := nil;
    for J := 0 to Child.ChildCount - 1 do
    begin
      TypeChild := Child.ChildAt(J);
      if (TypeChild <> nil) and (TypeChild.NodeKind = gnkIdentifier) then
      begin
        FieldTypeId := ResolveTypeIdForOwner(TypeChild.Text, AOwnerUnitId);
        Break;
      end;
    end;
    FModel.AddSymbol(Child.Text, 'field', AOwnerUnitId, FieldTypeId,
      Child.ByteOffset);
    FModel.SetSymbolScope(FModel.SymbolCount, RecordScopeId);
    FModel.AddConstValue(RecName + '.' + Child.Text + '$idx', FieldIndex);
    Field := Default(TFieldMeta);
    Field.Name := Child.Text;
    Field.Index := FieldIndex;
    { 检测字段类型 — 与 class 字段路径一致 }
    Field.IsString :=
      (TypeChild <> nil) and (TypeChild.NodeKind = gnkIdentifier) and
      (SameText(TypeChild.Text, 'String') or
       SameText(TypeChild.Text, 'AnsiString'));
    Field.IsPointer := False;
    Field.IsDynArray :=
      (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
      (Child.ChildAt(0).NodeKind = gnkArrayType);
    Field.IsRecord :=
      (FieldTypeId > 0) and FModel.GetTypeMeta(FieldTypeId, FieldMeta) and
      FieldMeta.IsRecord;
    Field.TypeId := FieldTypeId;
    if Meta.Fields = nil then
      Meta.Fields := TSemanticFieldMetaVec.Create;
    Meta.Fields.Push(Field);
    if Field.IsString then
      Inc(FieldIndex, 3)
    else if Field.IsDynArray then
      Inc(FieldIndex, 2)
    else if Field.IsRecord then
    begin
      if (FieldTypeId > 0) and FModel.GetTypeMeta(FieldTypeId, FieldMeta) then
        Inc(FieldIndex, FieldMeta.Size div 8)
      else
        Inc(FieldIndex, 1);
    end
    else
      Inc(FieldIndex, 1);
  end;
  FModel.AddConstValue(RecName + '$size', FieldIndex * 8);
  FModel.AddConstValue(RecName + '$record', 1);
  Meta.Size := FieldIndex * 8;
  FModel.SetTypeMeta(ATypeId, Meta);
end;

procedure TSemanticAnalyzer.AppendWhereConstraint(const ATypeId: LongInt;
  const AWhereSpec: string);
var
  ColonPos: LongInt;
  ParamName, Constraint: string;
begin
  ColonPos := Pos(':', AWhereSpec);
  if ColonPos <= 0 then
    Exit;
  ParamName := Copy(AWhereSpec, 1, ColonPos - 1);
  Constraint := Copy(AWhereSpec, ColonPos + 1, MaxInt);
  FModel.AppendTypeConstraint(ATypeId, ParamName, Constraint);
end;

procedure TSemanticAnalyzer.ProcessInterfaceMethods(const ANode: TGreenNode;
  const AOwnerUnitId: string; const ATypeId: LongInt);
var
  I, J: LongInt;
  Child, NameNode: TGreenNode;
  IntfName, ParentIntfName, ParentResolveName, MethShort: string;
  SymbolId: LongInt;
  Meta, ParentMeta: TTypeMetadata;
  Slot: TVmtSlot;
  ParentIntfTypeId, ParentResolveTypeId: LongInt;
  Symbol: TSemanticSymbol;
  HasParentMeta: Boolean;
  SlotVal: Int64;

  function SymbolNameHasPrefix(const AFull, APrefix: string): Boolean;
  begin
    { Case-insensitive "Prefix." head match — Pos() is case-sensitive. }
    Result := (APrefix <> '') and (Length(AFull) > Length(APrefix) + 1) and
      SameText(Copy(AFull, 1, Length(APrefix) + 1), APrefix + '.');
  end;

begin
  if ANode = nil then
    Exit;
  FillChar(Meta, SizeOf(Meta), 0);
  IntfName := FModel.TypeAt(ATypeId - 1).Name;
  ParentIntfName := '';
  ParentResolveName := '';
  ParentIntfTypeId := 0;
  ParentResolveTypeId := 0;
  HasParentMeta := False;
  if (ANode.ChildCount > 0) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) then
  begin
    ParentIntfName := ANode.ChildAt(0).Text;
    { Prefer name-index (last-wins re-export), then follow AliasTarget to the
      real interface that owns method symbols / VmtSlots.
      First-match TypeAt scan can pin a forward shell; TypeId-only parent
      method copy then misses IWriter.Write → bare @IHasher.Write. }
    ParentIntfTypeId := FModel.FindTypeByName(ParentIntfName);
    if ParentIntfTypeId <= 0 then
      for I := 0 to FModel.TypeCount - 1 do
        if SameText(FModel.TypeAt(I).Name, ParentIntfName) then
        begin
          ParentIntfTypeId := FModel.TypeAt(I).TypeId;
          Break;
        end;
    ParentResolveTypeId := ParentIntfTypeId;
    ParentResolveName := ParentIntfName;
    if (ParentResolveTypeId > 0) and
      FModel.GetTypeMeta(ParentResolveTypeId, ParentMeta) and
      (ParentMeta.AliasTargetTypeId > 0) and
      (ParentMeta.AliasTargetTypeId <= FModel.TypeCount) then
    begin
      ParentResolveTypeId := ParentMeta.AliasTargetTypeId;
      if FModel.TypeAt(ParentResolveTypeId - 1).Name <> '' then
        ParentResolveName := FModel.TypeAt(ParentResolveTypeId - 1).Name;
    end;
    if ParentIntfTypeId > 0 then
    begin
      FModel.SetTypeParent(ATypeId, ParentResolveTypeId);
      for I := 0 to FModel.SymbolCount - 1 do
      begin
        Symbol := FModel.SymbolAt(I);
        if not SameText(Symbol.Kind, 'method') then
          Continue;
        { Match by resolved parent TypeId OR by either parent name prefix.
          Re-export IWriter last-wins TypeId may not own original methods. }
        if not (
          ((ParentResolveTypeId > 0) and (Symbol.TypeId = ParentResolveTypeId)) or
          ((ParentIntfTypeId > 0) and (Symbol.TypeId = ParentIntfTypeId)) or
          SymbolNameHasPrefix(Symbol.Name, ParentResolveName) or
          SymbolNameHasPrefix(Symbol.Name, ParentIntfName)
        ) then
          Continue;
        if SymbolNameHasPrefix(Symbol.Name, ParentResolveName) then
          MethShort := Copy(Symbol.Name, Length(ParentResolveName) + 2, MaxInt)
        else if SymbolNameHasPrefix(Symbol.Name, ParentIntfName) then
          MethShort := Copy(Symbol.Name, Length(ParentIntfName) + 2, MaxInt)
        else
        begin
          J := Pos('.', Symbol.Name);
          if J <= 0 then
            Continue;
          MethShort := Copy(Symbol.Name, J + 1, MaxInt);
        end;
        if (MethShort = '') or (Pos('.', MethShort) > 0) then
          Continue;
        if FModel.FindSymbolByName(IntfName + '.' + MethShort) <> 0 then
          Continue;
        SymbolId := FModel.AddSymbol(IntfName + '.' + MethShort,
          'method', AOwnerUnitId, ATypeId, Symbol.ByteOffset);
        FModel.SetSymbolParamCount(SymbolId, Symbol.ParamCount);
        FModel.SetSymbolMinParamCount(SymbolId, Symbol.MinParamCount);
        FModel.SetSymbolParamSignature(SymbolId, Symbol.ParamSignature);
        if TypeMetaRetStr(ParentResolveName, MethShort) or
          TypeMetaRetStr(ParentIntfName, MethShort) then
          FModel.AddConstValue(IntfName + '$ret_str_' + MethShort, 1);
        if TypeMetaRetPtr(ParentResolveName, MethShort) or
          TypeMetaRetPtr(ParentIntfName, MethShort) then
          FModel.AddConstValue(IntfName + '$ret_ptr_' + MethShort, 1);
      end;
      HasParentMeta := FModel.GetTypeMeta(ParentResolveTypeId, ParentMeta);
      if not HasParentMeta then
        HasParentMeta := FModel.GetTypeMetaByName(ParentIntfName, ParentMeta);
      if not HasParentMeta then
        HasParentMeta := FModel.GetTypeMetaByName(ParentResolveName, ParentMeta);
    end;
  end;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkClassMethod) then
      Continue;
    if Child.ChildCount > 0 then
    begin
      NameNode := Child.ChildAt(0);
      if (NameNode <> nil) and (NameNode.NodeKind = gnkIdentifier) then
      begin
        SymbolId := FModel.AddSymbol(
          IntfName + '.' + NameNode.Text,
          'method', AOwnerUnitId, ATypeId, Child.ByteOffset);
        FModel.SetSymbolParamCount(SymbolId, CountDeclParams(Child));
        FModel.SetSymbolMinParamCount(SymbolId, CountRequiredDeclParams(Child));
        FModel.SetSymbolParamSignature(SymbolId, GetParamSignature(Child));
        FModel.SetSymbolReturnTypeId(SymbolId,
          DeclReturnTypeId(Child, AOwnerUnitId));
        if DeclReturnsString(Child) then
          FModel.AddConstValue(IntfName + '$ret_str_' + NameNode.Text, 1);
        { Interface methods returning class/interface/object → ivcall ret ptr.
          Without $ret_ptr_, EmitExprIvcall defaults to i64 → store ptr mismatch
          (Guard: Result := ALock.Lock). }
        if (Child.ChildCount > 1) and (Child.ChildAt(1) <> nil) and
          (Child.ChildAt(1).NodeKind = gnkIdentifier) and
          ((TypeMetaSize(Child.ChildAt(1).Text) > 0) or
           TypeMetaIsInterface(Child.ChildAt(1).Text) or
           SameText(Child.ChildAt(1).Text, IntfName) or
           SameText(Child.ChildAt(1).Text, 'Pointer') or
           SameText(Child.ChildAt(1).Text, 'PChar') or
           SameText(Child.ChildAt(1).Text, 'IInterface')) then
          FModel.AddConstValue(IntfName + '$ret_ptr_' + NameNode.Text, 1);
      end;
    end;
  end;
  { Explicit Meta fields — avoid `with` (stage0 bare-id under with → residual call). }
  Meta.TypeId := ATypeId;
  Meta.Size := 8;
  Meta.IsRecord := False;
  Meta.VmtCount := 0;
  if ParentResolveTypeId > 0 then
    Meta.ParentClassId := ParentResolveTypeId
  else
    Meta.ParentClassId := 0;
  if ParentResolveName <> '' then
    Meta.ParentClassName := ParentResolveName
  else
    Meta.ParentClassName := ParentIntfName;
  Meta.Interfaces := '';
  Meta.ArrElemSize := 0;
  Meta.ArrElemType := '';
  Meta.ArrLowBound := 0;
  Meta.ArrHighBound := -1;
  Meta.ArrLength := 0;
  Meta.IsStaticArray := False;
  Meta.Fields := nil;
  Meta.VmtSlots := nil;
  Meta.RetPtrMethods := nil;
  Meta.Properties := nil;
  Meta.InterfaceSlots := nil;
  { Inherit parent IMT first so IHasher.Write keeps IWriter slot index. }
  if HasParentMeta and (ParentMeta.VmtSlots <> nil) then
  begin
    for J := 0 to LongInt(ParentMeta.VmtSlots.Count) - 1 do
    begin
      Slot := ParentMeta.VmtSlots[SizeUInt(J)];
      { Child IMT names use child interface prefix for FuncQualName. }
      Slot.FuncQualName := IntfName + '.' + Slot.MethodName;
      Slot.SlotIndex := Meta.VmtCount;
      if Meta.VmtSlots = nil then
        Meta.VmtSlots := TSemanticVmtSlotVec.Create;
      Meta.VmtSlots.Push(Slot);
      FModel.AddConstValue(IntfName + '$vmt_slot_' + Slot.MethodName, Meta.VmtCount);
      Inc(Meta.VmtCount);
    end;
  end
  else if ParentResolveName <> '' then
  begin
    { Parent meta missing VmtSlots (re-export shell): rebuild IMT prefix from
      parent method symbols / $vmt_slot_ consts so Write stays slot 0. }
    for I := 0 to FModel.SymbolCount - 1 do
    begin
      Symbol := FModel.SymbolAt(I);
      if not SameText(Symbol.Kind, 'method') then
        Continue;
      if not (SymbolNameHasPrefix(Symbol.Name, ParentResolveName) or
        SymbolNameHasPrefix(Symbol.Name, ParentIntfName)) then
        Continue;
      if SymbolNameHasPrefix(Symbol.Name, ParentResolveName) then
        MethShort := Copy(Symbol.Name, Length(ParentResolveName) + 2, MaxInt)
      else
        MethShort := Copy(Symbol.Name, Length(ParentIntfName) + 2, MaxInt);
      if (MethShort = '') or (Pos('.', MethShort) > 0) then
        Continue;
      if FModel.LookupConstValue(IntfName + '$vmt_slot_' + MethShort, SlotVal) then
        Continue;
      Slot := Default(TVmtSlot);
      Slot.MethodName := MethShort;
      Slot.SlotIndex := Meta.VmtCount;
      Slot.FuncQualName := IntfName + '.' + MethShort;
      if Meta.VmtSlots = nil then
        Meta.VmtSlots := TSemanticVmtSlotVec.Create;
      Meta.VmtSlots.Push(Slot);
      FModel.AddConstValue(IntfName + '$vmt_slot_' + MethShort, Meta.VmtCount);
      Inc(Meta.VmtCount);
    end;
  end;
  for I := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(I);
    if SameText(Symbol.Kind, 'method') and
      SymbolNameHasPrefix(Symbol.Name, IntfName) then
    begin
      MethShort := Copy(Symbol.Name, Length(IntfName) + 2, MaxInt);
      if (MethShort = '') or (Pos('.', MethShort) > 0) then
        Continue;
      { Skip methods already inherited from parent IMT. }
      if FModel.LookupConstValue(IntfName + '$vmt_slot_' + MethShort, SlotVal) then
        Continue;
      Slot := Default(TVmtSlot);
      Slot.MethodName := MethShort;
      Slot.SlotIndex := Meta.VmtCount;
      Slot.FuncQualName := IntfName + '.' + MethShort;
      if Meta.VmtSlots = nil then
        Meta.VmtSlots := TSemanticVmtSlotVec.Create;
      Meta.VmtSlots.Push(Slot);
      { Name-keyed slot consts survive same-name unit re-exports that replace
        type-meta name index without copying VmtSlots (IChild = unit.IChild). }
      FModel.AddConstValue(IntfName + '$vmt_slot_' + MethShort, Meta.VmtCount);
      Inc(Meta.VmtCount);
    end;
  end;
  if Meta.ParentClassName <> '' then
    FModel.AddStringConstValue(IntfName + '$parent_class', Meta.ParentClassName);
  FModel.AddConstValue(IntfName + '$vmt_count', Meta.VmtCount);
  FModel.AddConstValue(IntfName + '$interface', 1);
  FModel.SetTypeKind(ATypeId, 'interface');
  FModel.SetTypeMeta(ATypeId, Meta);
end;

{ seed 倒序(consumer 先于 provider)令子接口先于父接口处理,父接口类型未注册
  时 ProcessInterfaceMethods 的父 IMT 继承分支被跳过(IHasher 缺
  IWriter.Write 即此症状)。ivcall 编码前补齐缺失的父 slots:父 slots 在前
  (沿用父 SlotIndex)、自身 slots 后移,consts/方法 symbol/ret 标记同步覆盖,
  布局与完整处理的 ProcessInterfaceMethods 一致,避免 ivcall slot 与 IMT
  表错位。父接口 meta 尚未建立时无能为力,保持原状。 }
procedure TSemanticAnalyzer.FixupInterfaceParentImt;
var
  I, J, K: LongInt;
  IntfTypeId: LongInt;
  Meta, ParentMeta: TTypeMetadata;
  IntfName, ParentName, MethShort: string;
  Slot: TVmtSlot;
  SlotVal: Int64;
  Missing, AlreadyIn, HasPrefix: Boolean;
  MethodId, SymbolId: LongInt;
  Symbol: TSemanticSymbol;
  Built: TSemanticVmtSlotVec;
begin
  for I := 0 to FModel.TypeCount - 1 do
  begin
    if not SameText(FModel.TypeAt(I).Kind, 'interface') then
      Continue;
    IntfTypeId := FModel.TypeAt(I).TypeId;
    IntfName := FModel.TypeAt(I).Name;
    if not FModel.GetTypeMeta(IntfTypeId, Meta) then
      Continue;
    ParentName := Meta.ParentClassName;
    if ParentName = '' then
      Continue;
    if not FModel.GetTypeMetaByName(ParentName, ParentMeta) or
      (ParentMeta.VmtSlots = nil) then
      Continue;
    Missing := False;
    for J := 0 to LongInt(ParentMeta.VmtSlots.Count) - 1 do
      if not FModel.LookupConstValue(IntfName + '$vmt_slot_' +
        ParentMeta.VmtSlots[SizeUInt(J)].MethodName, SlotVal) then
      begin
        Missing := True;
        Break;
      end;
    if not Missing then
      Continue; { 父 slots 已继承,无需重建 }
    Built := TSemanticVmtSlotVec.Create;
    for J := 0 to LongInt(ParentMeta.VmtSlots.Count) - 1 do
    begin
      Slot := ParentMeta.VmtSlots[SizeUInt(J)];
      Slot.FuncQualName := IntfName + '.' + Slot.MethodName;
      Built.Push(Slot);
    end;
    for J := 0 to FModel.SymbolCount - 1 do
    begin
      Symbol := FModel.SymbolAt(J);
      if not SameText(Symbol.Kind, 'method') then
        Continue;
      HasPrefix := (Length(Symbol.Name) > Length(IntfName) + 1) and
        SameText(Copy(Symbol.Name, 1, Length(IntfName) + 1), IntfName + '.');
      if not HasPrefix then
        Continue;
      MethShort := Copy(Symbol.Name, Length(IntfName) + 2, MaxInt);
      if (MethShort = '') or (Pos('.', MethShort) > 0) then
        Continue;
      AlreadyIn := False;
      for K := 0 to LongInt(Built.Count) - 1 do
        if SameText(Built[SizeUInt(K)].MethodName, MethShort) then
        begin
          AlreadyIn := True;
          Break;
        end;
      if AlreadyIn then
        Continue;
      Slot := Default(TVmtSlot);
      Slot.MethodName := MethShort;
      Slot.SlotIndex := LongInt(Built.Count);
      Slot.FuncQualName := IntfName + '.' + MethShort;
      Built.Push(Slot);
    end;
    Meta.VmtSlots := Built;
    Meta.VmtCount := LongInt(Built.Count);
    for J := 0 to LongInt(Built.Count) - 1 do
      FModel.AddConstValue(IntfName + '$vmt_slot_' +
        Built[SizeUInt(J)].MethodName, Built[SizeUInt(J)].SlotIndex);
    FModel.AddConstValue(IntfName + '$vmt_count', Meta.VmtCount);
    for J := 0 to LongInt(ParentMeta.VmtSlots.Count) - 1 do
    begin
      MethShort := ParentMeta.VmtSlots[SizeUInt(J)].MethodName;
      if FModel.FindSymbolByName(IntfName + '.' + MethShort) = 0 then
      begin
        MethodId := FModel.FindSymbolByName(ParentName + '.' + MethShort);
        if MethodId > 0 then
        begin
          Symbol := FModel.SymbolAt(MethodId);
          SymbolId := FModel.AddSymbol(IntfName + '.' + MethShort, 'method',
            Symbol.OwnerUnitId, IntfTypeId, Symbol.ByteOffset);
          FModel.SetSymbolParamCount(SymbolId, Symbol.ParamCount);
          FModel.SetSymbolMinParamCount(SymbolId, Symbol.MinParamCount);
          FModel.SetSymbolParamSignature(SymbolId, Symbol.ParamSignature);
          FModel.SetSymbolReturnTypeId(SymbolId, Symbol.ReturnTypeId);
        end;
      end;
      if TypeMetaRetStr(ParentName, MethShort) then
        FModel.AddConstValue(IntfName + '$ret_str_' + MethShort, 1);
      if TypeMetaRetPtr(ParentName, MethShort) then
        FModel.AddConstValue(IntfName + '$ret_ptr_' + MethShort, 1);
    end;
    FModel.SetTypeMeta(IntfTypeId, Meta);
  end;
end;

procedure TSemanticAnalyzer.VerifyInterfaceImplementation(
  const AClassTypeId: LongInt; const AInterfaceList: string;
  const AOwnerUnitId: string);
var
  I, J, K: LongInt;
  IntfName, ClsN, MethN, CheckName: string;
  IntfTypeId: LongInt;
  Symbol: TSemanticSymbol;
  QualIntfMethod: string;
  Found: Boolean;
  CurrentCheckTypeId: LongInt;
begin
  I := 1;
  while I <= Length(AInterfaceList) do
  begin
    J := I;
    while (J <= Length(AInterfaceList)) and (AInterfaceList[J] <> ',') do
      Inc(J);
    IntfName := Trim(Copy(AInterfaceList, I, J - I));
    I := J + 1;
    if IntfName = '' then
      Continue;
    IntfTypeId := 0;
    for K := 0 to FModel.TypeCount - 1 do
      if SameText(FModel.TypeAt(K).Name, IntfName) then
      begin
        IntfTypeId := FModel.TypeAt(K).TypeId;
        Break;
      end;
    if IntfTypeId <= 0 then
      Continue;
    for K := 0 to FModel.SymbolCount - 1 do
    begin
      Symbol := FModel.SymbolAt(K);
      if (Symbol.TypeId = IntfTypeId) and SameText(Symbol.Kind, 'method') then
      begin
        QualIntfMethod := IntfName + '.';
        if Pos(QualIntfMethod, Symbol.Name) = 1 then
        begin
          MethN := Copy(Symbol.Name, Length(QualIntfMethod) + 1, MaxInt);
          Found := False;
          CurrentCheckTypeId := AClassTypeId;
          while (CurrentCheckTypeId > 0) and (not Found) and
                (CurrentCheckTypeId <> FModel.TypeAt(CurrentCheckTypeId - 1).ParentTypeId) do
          begin
            ClsN := FModel.TypeAt(CurrentCheckTypeId - 1).Name;
            for J := 0 to FModel.SymbolCount - 1 do
              if SameText(FModel.SymbolAt(J).Name, ClsN + '.' + MethN) and
                (SameText(FModel.SymbolAt(J).Kind, 'method') or
                 SameText(FModel.SymbolAt(J).Kind, 'constructor')) then
              begin
                Found := True;
                Break;
              end;
            if not Found then
              CurrentCheckTypeId := FModel.TypeAt(CurrentCheckTypeId - 1).ParentTypeId;
          end;
          if not Found then
            FDiagnostics.EmitError('sema.missing-interface-method', 'sema',
              FRootFileId, 0,
              FModel.TypeAt(AClassTypeId - 1).Name +
              ' does not implement ' + IntfName + '.' + MethN);
        end;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.RegisterInterfaceSlots(const AClassTypeId: LongInt;
  const AInterfaceList: string);
var
  I, J, SlotOffset: LongInt;
  IntfName, ClsName: string;
  Meta: TTypeMetadata;
  Slot: TInterfaceSlotMeta;
  IntfNames: array of string;
  IntfCount: LongInt;
begin
  if not FModel.GetTypeMeta(AClassTypeId, Meta) then
    Exit;
  ClsName := FModel.TypeAt(AClassTypeId - 1).Name;
  IntfCount := 0;
  I := 1;
  while I <= Length(AInterfaceList) do
  begin
    J := I;
    while (J <= Length(AInterfaceList)) and (AInterfaceList[J] <> ',') do
      Inc(J);
    IntfName := Trim(Copy(AInterfaceList, I, J - I));
    I := J + 1;
    if SameText(IntfName, 'TObject') or SameText(IntfName, 'TInterfacedObject') then
      Continue;
    Inc(IntfCount);
    SetLength(IntfNames, IntfCount);
    IntfNames[IntfCount - 1] := IntfName;
  end;
  if IntfCount = 0 then
    Exit;
  SlotOffset := LongInt(Meta.Size div 8);
  if SlotOffset <= 0 then
    if Meta.Fields = nil then
      SlotOffset := 1
    else
      SlotOffset := LongInt(Meta.Fields.Count) + 1;
  { Build a fresh entry-owned vec; SetTypeMeta frees any previous table-owned
    InterfaceSlots pointer from GetTypeMeta without touching it here. }
  Meta.InterfaceSlots := TSemanticInterfaceSlotMetaVec.Create(SizeUInt(IntfCount));
  for I := 0 to IntfCount - 1 do
  begin
    Slot := Default(TInterfaceSlotMeta);
    Slot.InterfaceName := IntfNames[I];
    Slot.SlotOffset := SlotOffset + I;
    Meta.InterfaceSlots.Push(Slot);
    FModel.AddConstValue(ClsName + '$intf_offset_' + IntfNames[I],
      (SlotOffset + I) * 8);
  end;
  Meta.Size := (SlotOffset + IntfCount) * 8;
  FModel.AddConstValue(ClsName + '$size', Meta.Size);
  FModel.SetTypeMeta(AClassTypeId, Meta);
end;

function TSemanticAnalyzer.CheckSingleConstraint(const AArgType: string;
  const AConstraint: string): Boolean;
var
  IntfList: string;
  SubConstraints: TStringVec;
  I, J: LongInt;
  SC: string;
begin
  Result := True;
  SubConstraints := TStringVec.Create;
  try
    I := 1;
    while I <= Length(AConstraint) do
    begin
      J := I;
      while (J <= Length(AConstraint)) and (AConstraint[J] <> '|') do
        Inc(J);
      SubConstraints.Push(Trim(Copy(AConstraint, I, J - I)));
      I := J + 1;
    end;
    for I := 0 to SubConstraints.Count - 1 do
    begin
      SC := SubConstraints[I];
      if SC = '' then
        Continue;
      if SameText(SC, 'class') then
      begin
        if not TypeMetaIsClass(AArgType) then
        begin
          FDiagnostics.EmitError('sema.constraint-violation', 'sema',
            FRootFileId, 0,
            'type ' + AArgType + ' does not satisfy constraint "class"');
          Result := False;
          Exit;
        end;
      end
      else if SameText(SC, 'record') then
      begin
        if not TypeMetaIsRecord(AArgType) then
        begin
          FDiagnostics.EmitError('sema.constraint-violation', 'sema',
            FRootFileId, 0,
            'type ' + AArgType + ' does not satisfy constraint "record"');
          Result := False;
          Exit;
        end;
      end
      else
      begin
        if not TypeMetaIsClass(AArgType) then
        begin
          FDiagnostics.EmitError('sema.constraint-violation', 'sema',
            FRootFileId, 0,
            'type ' + AArgType + ' does not satisfy interface constraint "' +
            SC + '" (must be a class type)');
          Result := False;
          Exit;
        end;
        IntfList := TypeMetaInterfaces(AArgType);
        if (IntfList = '') or (Pos(',' + SC + ',', ',' + IntfList + ',') = 0) then
        begin
          FDiagnostics.EmitError('sema.constraint-violation', 'sema',
            FRootFileId, 0,
            'type ' + AArgType + ' does not implement interface "' + SC + '"');
          Result := False;
          Exit;
        end;
      end;
    end;
  finally
    SubConstraints.Free;
  end;
end;

procedure TSemanticAnalyzer.RegisterStructuredGenericParent(
  const ATypeId: LongInt; const AParentSpec: string;
  const AOwnerUnitId: string);
var
  LtPos, GtPos, I, J: LongInt;
  ParentName, ArgStr: string;
  ParentTypeId: LongInt;
  OwnerParams: string;
  ArgNames: TStringVec;
  ArgIndices: array of LongInt;
begin
  LtPos := Pos('<', AParentSpec);
  if LtPos <= 0 then
    Exit;
  ParentName := Copy(AParentSpec, 1, LtPos - 1);
  GtPos := 0;
  J := 1;
  for I := LtPos + 1 to Length(AParentSpec) do
  begin
    if AParentSpec[I] = '<' then Inc(J)
    else if AParentSpec[I] = '>' then
    begin
      Dec(J);
      if J = 0 then begin GtPos := I; Break; end;
    end;
  end;
  if GtPos <= LtPos then
    GtPos := Length(AParentSpec) + 1;
  ArgStr := Copy(AParentSpec, LtPos + 1, GtPos - LtPos - 1);

  ParentTypeId := 0;
  for I := 0 to FModel.TypeCount - 1 do
    if SameText(FModel.TypeAt(I).Name, ParentName) and
      (FModel.TypeAt(I).TypeParams <> '') and
      SameText(FModel.TypeAt(I).OwnerUnitId, AOwnerUnitId) then
    begin
      ParentTypeId := FModel.TypeAt(I).TypeId;
      Break;
    end;
  if ParentTypeId <= 0 then
    for I := 0 to FModel.TypeCount - 1 do
      if SameText(FModel.TypeAt(I).Name, ParentName) and
        (FModel.TypeAt(I).TypeParams <> '') then
      begin
        ParentTypeId := FModel.TypeAt(I).TypeId;
        Break;
      end;
  if ParentTypeId <= 0 then
    Exit;

  OwnerParams := FModel.TypeAt(ATypeId - 1).TypeParams;

  ArgNames := TStringVec.Create;
  I := 1;
  while I <= Length(ArgStr) do
  begin
    J := I;
    GtPos := 0;
    while J <= Length(ArgStr) do
    begin
      if ArgStr[J] = '<' then Inc(GtPos)
      else if ArgStr[J] = '>' then Dec(GtPos)
      else if (ArgStr[J] = ',') and (GtPos = 0) then Break;
      Inc(J);
    end;
    ArgNames.Push(Trim(Copy(ArgStr, I, J - I)));
    I := J + 1;
  end;

  SetLength(ArgIndices, ArgNames.Count);
  for I := 0 to ArgNames.Count - 1 do
  begin
    ArgIndices[I] := -1;
    J := 1;
    GtPos := 0;
    while J <= Length(OwnerParams) do
    begin
      if SameText(Copy(OwnerParams, J, Length(ArgNames[I])), ArgNames[I]) and
        ((J + Length(ArgNames[I]) - 1 = Length(OwnerParams)) or
         (OwnerParams[J + Length(ArgNames[I])] = ',')) then
      begin
        ArgIndices[I] := GtPos;
        Break;
      end;
      while (J <= Length(OwnerParams)) and (OwnerParams[J] <> ',') do Inc(J);
      Inc(J);
      Inc(GtPos);
    end;
  end;

  ArgNames.Free;
  FModel.SetTypeGenericParent(ATypeId, ParentTypeId, ArgIndices);
end;

procedure FreePendingSignatureNested(var AEntry: TPendingSignatureEntry);
begin
  AEntry.ParamNames.Free;
  AEntry.ParamNames := nil;
  AEntry.ArgTypes.Free;
  AEntry.ArgTypes := nil;
end;

function ClonePendingStringVec(
  const ASrc: TStringVec;
  AAllocator: IAllocator
): TStringVec;
var
  I: SizeInt;
begin
  if ASrc = nil then
    Exit(nil);
  if AAllocator <> nil then
    Result := TStringVec.Create(ASrc.Count, AAllocator)
  else
    Result := TStringVec.Create(ASrc.Count);
  for I := 0 to SizeInt(ASrc.Count) - 1 do
    Result.Push(ASrc[SizeUInt(I)]);
end;

procedure TSemanticAnalyzer.CompletePendingSignatures;
var
  I, BodyIdx: LongInt;
  Decl: TGreenNode;
  SubstSig: string;
  QualName: string;
  Entry: PPendingSignatureEntry;
begin
  if FPendingSignatures = nil then
    Exit;
  for I := 0 to LongInt(FPendingSignatures.Count) - 1 do
  begin
    Entry := FPendingSignatures.GetPtr(SizeUInt(I));
    QualName := Entry^.GenericName + '.' + Entry^.MethodShortName;
    Decl := nil;
    for BodyIdx := 0 to LongInt(FProcedureBodies.Count) - 1 do
    begin
      if SameText(FProcedureBodies[BodyIdx].Name, QualName) and
        SameText(FProcedureBodies[BodyIdx].OwnerUnitId, Entry^.OwnerUnitId) then
      begin
        Decl := FProcedureBodies[BodyIdx].Decl;
        Break;
      end;
    end;
    if Decl = nil then
      for BodyIdx := 0 to LongInt(FProcedureBodies.Count) - 1 do
        if SameText(FProcedureBodies[BodyIdx].Name, QualName) then
        begin
          Decl := FProcedureBodies[BodyIdx].Decl;
          Break;
        end;
    if (Decl <> nil) and (Entry^.ParamNames <> nil) and
      (Entry^.ArgTypes <> nil) then
    begin
      SubstSig := GetSubstitutedParamSignature(Decl,
        Entry^.ParamNames.ToArray, Entry^.ArgTypes.ToArray);
      FModel.SetSymbolParamSignature(Entry^.SymbolId, SubstSig);
    end;
    FreePendingSignatureNested(Entry^);
  end;
  FPendingSignatures.Clear;
end;

procedure TSemanticAnalyzer.ProcessClassFields(const ANode: TGreenNode;
  const AOwnerUnitId: string; const ATypeId: LongInt);
var
  I, J, K: LongInt;
  Child, NameNode: TGreenNode;
  TypeChild: TGreenNode;
  FieldTypeId: LongInt;
  ClassTypeName, SpecText: string;
  NewTypeId: LongInt;
  FieldIndex: LongInt;
  ClassScopeId: LongInt;
  ClsName, ParentName, ConstName, FieldName, ParentStringVal, InhParentName: string;
  CurrentVisibility: string;
  ParentFieldVal: Int64;
  DotPos, IdxPos: LongInt;
  ParentTypeId: LongInt;
  PointerTypeId: LongInt;
  SymbolId: LongInt;
  Meta, ParentMeta: TTypeMetadata;
  Field: TFieldMeta;
  Slot: TVmtSlot;
  VmtCount: LongInt;
  HasParentMeta: Boolean;
  IsArrayField, IsDynArrayField: Boolean;
  LowBound, HighBound, ArrayLength: Int64;
begin
  if ANode = nil then
    Exit;
  FillChar(Meta, SizeOf(Meta), 0);
  ClassScopeId := FModel.AddScope(skRecord, '', FCurrentScopeId);
  ClsName := FModel.TypeAt(ATypeId - 1).Name;
  FieldIndex := 1;
  ParentName := '';
  if (ANode.ChildCount > 0) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) then
    ParentName := ANode.ChildAt(0).Text
  else if (ATypeId > 0) and (ATypeId <= FModel.TypeCount) then
  begin
    ParentTypeId := FModel.TypeAt(ATypeId - 1).ParentTypeId;
    if (ParentTypeId > 0) and (ParentTypeId <= FModel.TypeCount) then
      ParentName := FModel.TypeAt(ParentTypeId - 1).Name;
  end;
  if (ParentName = '') and (not SameText(ClsName, 'TObject')) then
    ParentName := 'TObject';
  VmtCount := 0;
  Meta.Fields := nil;
  Meta.VmtSlots := nil;
  Meta.RetPtrMethods := nil;
  Meta.Properties := nil;
  Meta.InterfaceSlots := nil;
  HasParentMeta := (ParentName <> '') and FModel.GetTypeMetaByName(ParentName, ParentMeta);
  if ParentName <> '' then
  begin
    ParentFieldVal := TypeMetaSize(ParentName);
    if ParentFieldVal > 0 then
    begin
      FieldIndex := LongInt(ParentFieldVal) div 8;
      if HasParentMeta then
      begin
        if ParentMeta.Fields <> nil then
          for J := 0 to LongInt(ParentMeta.Fields.Count) - 1 do
          begin
            FModel.AddConstValue(ClsName + '.' + ParentMeta.Fields[SizeUInt(J)].Name + '$idx',
              ParentMeta.Fields[SizeUInt(J)].Index);
            if ParentMeta.Fields[SizeUInt(J)].IsString then
              FModel.AddConstValue(ClsName + '.' + ParentMeta.Fields[SizeUInt(J)].Name + '$str', 1);
            if ParentMeta.Fields[SizeUInt(J)].IsPointer then
              FModel.AddConstValue(ClsName + '.' + ParentMeta.Fields[SizeUInt(J)].Name + '$ptr', 1);
            if ParentMeta.Fields[SizeUInt(J)].IsDynArray then
              FModel.AddConstValue(ClsName + '.' + ParentMeta.Fields[SizeUInt(J)].Name + '$arr', 1);
            if FModel.LookupStringConstValue(
              ParentName + '.' + ParentMeta.Fields[SizeUInt(J)].Name + '$arr_elem_type',
              ParentStringVal) then
              FModel.AddStringConstValue(
                ClsName + '.' + ParentMeta.Fields[SizeUInt(J)].Name + '$arr_elem_type',
                ParentStringVal);
            if FModel.LookupConstValue(
              ParentName + '.' + ParentMeta.Fields[SizeUInt(J)].Name + '$arr_elem_size',
              ParentFieldVal) then
              FModel.AddConstValue(
                ClsName + '.' + ParentMeta.Fields[SizeUInt(J)].Name + '$arr_elem_size',
                ParentFieldVal);
            if Meta.Fields = nil then
              Meta.Fields := TSemanticFieldMetaVec.Create;
            Meta.Fields.Push(ParentMeta.Fields[SizeUInt(J)]);
          end;
      end
      else
      begin
        for J := 0 to FModel.ConstValueCount - 1 do
        begin
          ConstName := FModel.ConstValueNameAt(J);
          if (Pos(ParentName + '.', ConstName) = 1) and
            (Pos('$idx', ConstName) > 0) then
          begin
            DotPos := Pos('.', ConstName);
            IdxPos := Pos('$idx', ConstName);
            FieldName := Copy(ConstName, DotPos + 1, IdxPos - DotPos - 1);
            FModel.AddConstValue(ClsName + '.' + FieldName + '$idx',
              FModel.ConstValueAt(J));
          end
          else if (Pos(ParentName + '.', ConstName) = 1) and
            (Pos('$str', ConstName) > 0) then
          begin
            DotPos := Pos('.', ConstName);
            IdxPos := Pos('$str', ConstName);
            FieldName := Copy(ConstName, DotPos + 1, IdxPos - DotPos - 1);
            FModel.AddConstValue(ClsName + '.' + FieldName + '$str',
              FModel.ConstValueAt(J));
          end
          else if (Pos(ParentName + '.', ConstName) = 1) and
            (Pos('$ptr', ConstName) > 0) then
          begin
            DotPos := Pos('.', ConstName);
            IdxPos := Pos('$ptr', ConstName);
            FieldName := Copy(ConstName, DotPos + 1, IdxPos - DotPos - 1);
            FModel.AddConstValue(ClsName + '.' + FieldName + '$ptr',
              FModel.ConstValueAt(J));
          end
          else if (Pos(ParentName + '.', ConstName) = 1) and
            (Pos('$arr', ConstName) = Length(ConstName) - 3) then
          begin
            DotPos := Pos('.', ConstName);
            IdxPos := Pos('$arr', ConstName);
            FieldName := Copy(ConstName, DotPos + 1, IdxPos - DotPos - 1);
            FModel.AddConstValue(ClsName + '.' + FieldName + '$arr',
              FModel.ConstValueAt(J));
          end;
        end;
      end;
    end;
    if HasParentMeta then
    begin
      VmtCount := ParentMeta.VmtCount;
      FModel.AddConstValue(ClsName + '$vmt_count', VmtCount);
      if ParentMeta.VmtSlots <> nil then
        for J := 0 to LongInt(ParentMeta.VmtSlots.Count) - 1 do
        begin
          FModel.AddConstValue(ClsName + '$vmt_slot_' +
            ParentMeta.VmtSlots[SizeUInt(J)].MethodName,
            ParentMeta.VmtSlots[SizeUInt(J)].SlotIndex);
          FModel.AddStringConstValue(ClsName + '$vmt_func_' +
            IntToStr(ParentMeta.VmtSlots[SizeUInt(J)].SlotIndex),
            ParentMeta.VmtSlots[SizeUInt(J)].FuncQualName);
          if Meta.VmtSlots = nil then
            Meta.VmtSlots := TSemanticVmtSlotVec.Create;
          Meta.VmtSlots.Push(ParentMeta.VmtSlots[SizeUInt(J)]);
        end;
    end
    else
    begin
      ParentFieldVal := TypeMetaVmtCount(ParentName);
      if ParentFieldVal >= 0 then
      begin
        VmtCount := LongInt(ParentFieldVal);
        FModel.AddConstValue(ClsName + '$vmt_count', VmtCount);
        for J := 0 to FModel.ConstValueCount - 1 do
        begin
          ConstName := FModel.ConstValueNameAt(J);
          if (Pos(ParentName + '$vmt_slot_', ConstName) = 1) then
          begin
            FieldName := Copy(ConstName,
              Length(ParentName + '$vmt_slot_') + 1, Length(ConstName));
            FModel.AddConstValue(ClsName + '$vmt_slot_' + FieldName,
              FModel.ConstValueAt(J));
          end;
        end;
        for J := 0 to VmtCount - 1 do
        begin
          ConstName := ParentName + '$vmt_func_' + IntToStr(J);
          if FModel.LookupStringConstValue(ConstName, FieldName) then
            FModel.AddStringConstValue(
              ClsName + '$vmt_func_' + IntToStr(J), FieldName);
        end;
      end;
    end;
    FModel.AddStringConstValue(ClsName + '$parent_class', ParentName);
  end;
  CurrentVisibility := 'public';
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if (Child.NodeKind = gnkIdentifier) and (Pos('where:', Child.Text) = 1) then
    begin
      AppendWhereConstraint(ATypeId, Copy(Child.Text, 7, MaxInt));
      Continue;
    end;
    if Child.NodeKind = gnkVisibilityLabel then
    begin
      CurrentVisibility := LowerCase(Child.Text);
      Continue;
    end;
    if Child.NodeKind = gnkClassField then
    begin
      FieldTypeId := 0;
      IsArrayField := (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        (Child.ChildAt(0).NodeKind = gnkArrayType);
      IsDynArrayField := IsArrayField and
        (not TryGetArrayTypeBounds(
          Child.ChildAt(0), LowBound, HighBound, ArrayLength));
      if Child.ChildCount > 0 then
      begin
        NameNode := Child.ChildAt(0);
        if (NameNode <> nil) and (NameNode.NodeKind = gnkIdentifier) then
          FieldTypeId := ResolveTypeIdForOwner(NameNode.Text, AOwnerUnitId);
        if (NameNode <> nil) and (NameNode.NodeKind = gnkArrayType) then
        begin
          PointerTypeId := FModel.FindTypeByName('Pointer');
          if PointerTypeId > 0 then
            FieldTypeId := PointerTypeId;
        end;
      end;
      FModel.AddSymbol(Child.Text, 'field', AOwnerUnitId, FieldTypeId,
        Child.ByteOffset);
      FModel.SetSymbolScope(FModel.SymbolCount, ClassScopeId);
      FModel.SetSymbolVisibility(FModel.SymbolCount, CurrentVisibility);
      FModel.AddConstValue(
        ClsName + '.' + Child.Text + '$idx',
        FieldIndex);
      if IsArrayField then
      begin
        if IsDynArrayField then
          FModel.AddConstValue(ClsName + '.' + Child.Text + '$arr', 1);
        NameNode := ArrayElementTypeNode(Child.ChildAt(0));
        if NameNode <> nil then
        begin
          FModel.AddStringConstValue(
            ClsName + '.' + Child.Text + '$arr_elem_type',
            NameNode.Text);
          if TypeMetaIsRecord(NameNode.Text) then
            FModel.AddConstValue(
              ClsName + '.' + Child.Text + '$arr_elem_size',
              TypeMetaSize(NameNode.Text))
          else
            FModel.AddConstValue(
              ClsName + '.' + Child.Text + '$arr_elem_size',
              8);
        end;
      end;
      if (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        ((TypeMetaSize(Child.ChildAt(0).Text) > 0) or
         SameText(Child.ChildAt(0).Text, ClsName)) then
        FModel.AddConstValue(
          ClsName + '.' + Child.Text + '$ptr', 1);
      if (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        (SameText(Child.ChildAt(0).Text, 'String') or
         SameText(Child.ChildAt(0).Text, 'AnsiString')) then
      begin
        FModel.AddConstValue(ClsName + '.' + Child.Text + '$str', 1);
        Inc(FieldIndex, 4);
      end
      else if IsDynArrayField then
        Inc(FieldIndex, 2)
      else if (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        TypeMetaIsRecord(Child.ChildAt(0).Text) and
        (TypeMetaSize(Child.ChildAt(0).Text) > 0) then
      begin
        ParentFieldVal := TypeMetaSize(Child.ChildAt(0).Text);
        for J := 0 to FModel.ConstValueCount - 1 do
        begin
          ConstName := FModel.ConstValueNameAt(J);
          if (Pos(Child.ChildAt(0).Text + '.', ConstName) = 1) and
            (Pos('$idx', ConstName) > 0) then
          begin
            DotPos := Pos('.', ConstName);
            IdxPos := Pos('$idx', ConstName);
            FieldName := Copy(ConstName, DotPos + 1, IdxPos - DotPos - 1);
            FModel.AddConstValue(
              ClsName + '.' + Child.Text + '.' + FieldName + '$idx',
              FieldIndex + FModel.ConstValueAt(J));
          end;
        end;
        Inc(FieldIndex, ParentFieldVal div 8);
      end
      else
        Inc(FieldIndex);
      Field := Default(TFieldMeta);
      Field.Name := Child.Text;
      Field.Index := TypeMetaFieldIndex(ClsName, Child.Text);
      Field.IsString :=
        (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        (SameText(Child.ChildAt(0).Text, 'String') or
         SameText(Child.ChildAt(0).Text, 'AnsiString'));
      Field.IsPointer :=
        (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        ((TypeMetaSize(Child.ChildAt(0).Text) > 0) or
         SameText(Child.ChildAt(0).Text, ClsName));
      Field.IsDynArray := IsDynArrayField;
      Field.TypeId := FieldTypeId;
      if Meta.Fields = nil then
        Meta.Fields := TSemanticFieldMetaVec.Create;
      Meta.Fields.Push(Field);
    end
    else if Child.NodeKind = gnkTypeSection then
    begin
      { Class-local type section (TVecBuf = specialize TArray<T>). Register
        each alias so call sites inside cloned bodies can resolve the
        receiver; generic args (T) stay unbound until instantiation. }
      for J := 0 to Child.ChildCount - 1 do
      begin
        NameNode := Child.ChildAt(J);
        if (NameNode = nil) or (NameNode.NodeKind <> gnkTypeDecl) then
          Continue;
        ClassTypeName := NameNode.Text;
        if ClassTypeName = '' then
          Continue;
        TypeChild := nil;
        for K := 0 to NameNode.ChildCount - 1 do
          if NameNode.ChildAt(K) <> nil then
          begin
            TypeChild := NameNode.ChildAt(K);
            Break;
          end;
        if (TypeChild = nil) or (TypeChild.NodeKind <> gnkIdentifier) then
          Continue;
        SpecText := TypeChild.Text;
        NewTypeId := FModel.AddType(ClassTypeName, 'declared');
        FModel.SetTypeParent(NewTypeId, 0);
        { Register as a unit-scoped type symbol too: field receivers
          (FBuf: TVecBuf) resolve via ResolveTypeIdForOwner, which scans
          symbols, not the bare type table — without this the field
          TypeId was 0 and method receivers fell back to PAnsiChar. }
        FModel.AddSymbol(ClassTypeName, 'type', AOwnerUnitId, NewTypeId, 0);
        if Pos('<', SpecText) > 0 then
        begin
          { Generic-parameterized alias: keep the spec text and the owning
            class so instantiation can expand it (T -> concrete arg). }
          FModel.AddStringConstValue(ClassTypeName + '$class_spec', SpecText);
          FModel.AddStringConstValue(ClassTypeName + '$class_owner',
            ClsName);
          FModel.AddStringConstValue(ClassTypeName + '$class_owner_unit',
            AOwnerUnitId);
          FModel.AddConstValue(ClassTypeName + '$size', 8);
          FModel.SetTypeKind(NewTypeId, 'alias');
          { Seed a metadata entry so GetTypeMeta can find the alias;
            FindTypeByName alone does not create one. }
          FModel.SetTypeAliasTarget(NewTypeId, 0);
        end
        else
        begin
          { Concrete class-local alias: forward to the resolved target when
            it is already registered, mirroring ProcessTypeSection. }
          FieldTypeId := ResolveTypeIdForOwner(SpecText, AOwnerUnitId);
          if FieldTypeId > 0 then
          begin
            if FModel.GetTypeMeta(FieldTypeId, Meta) and (Meta.Size > 0) then
            begin
              FModel.AddConstValue(ClassTypeName + '$size', Meta.Size);
              FModel.SetTypeParent(NewTypeId, FieldTypeId);
            end;
            FModel.SetTypeKind(NewTypeId, 'alias');
            FModel.SetTypeAliasTarget(NewTypeId, FieldTypeId);
          end
          else
          begin
            FModel.AddConstValue(ClassTypeName + '$size', 8);
            FModel.SetTypeKind(NewTypeId, 'alias');
            FModel.SetTypeAliasTarget(NewTypeId, 0);
          end;
        end;
      end;
    end
    else if Child.NodeKind = gnkClassMethod then
    begin
      if Child.ChildCount > 0 then
      begin
        NameNode := Child.ChildAt(0);
        if (NameNode <> nil) and (NameNode.NodeKind = gnkIdentifier) then
        begin
          SymbolId := FModel.AddSymbol(
            ClsName + '.' + NameNode.Text,
            'method', AOwnerUnitId, ATypeId, Child.ByteOffset);
          FModel.SetSymbolParamCount(SymbolId, CountDeclParams(Child));
          FModel.SetSymbolMinParamCount(SymbolId, CountRequiredDeclParams(Child));
          FModel.SetSymbolParamSignature(SymbolId, GetParamSignature(Child));
          FModel.SetSymbolReturnTypeId(SymbolId,
            DeclReturnTypeId(Child, AOwnerUnitId));
          FModel.SetSymbolVisibility(SymbolId, CurrentVisibility);
          FModel.SetSymbolScope(SymbolId, ClassScopeId);
          if Pos(';virtual', Child.Text) > 0 then
          begin
            FModel.AddConstValue(
              ClsName + '$vmt_slot_' + NameNode.Text, VmtCount);
            FModel.AddStringConstValue(
              ClsName + '$vmt_func_' + IntToStr(VmtCount),
              ClsName + '.' + NameNode.Text);
            Slot := Default(TVmtSlot);
            Slot.MethodName := NameNode.Text;
            Slot.SlotIndex := VmtCount;
            Slot.FuncQualName := ClsName + '.' + NameNode.Text;
            if Meta.VmtSlots = nil then
              Meta.VmtSlots := TSemanticVmtSlotVec.Create;
            Meta.VmtSlots.Push(Slot);
            Inc(VmtCount);
            FModel.AddConstValue(ClsName + '$vmt_count', VmtCount);
            if Pos(';abstract', Child.Text) > 0 then
              FModel.AddStringConstValue(
                ClsName + '$abstract_' + NameNode.Text, 'true');
          end
          else if Pos(';override', Child.Text) > 0 then
          begin
            ParentFieldVal := TypeMetaVmtSlot(ParentName, NameNode.Text);
            if ParentFieldVal >= 0 then
            begin
              FModel.AddConstValue(
                ClsName + '$vmt_slot_' + NameNode.Text, ParentFieldVal);
              FModel.AddStringConstValue(
                ClsName + '$vmt_func_' + IntToStr(ParentFieldVal),
                ClsName + '.' + NameNode.Text);
              if Meta.VmtSlots <> nil then
                for J := 0 to LongInt(Meta.VmtSlots.Count) - 1 do
                  if Meta.VmtSlots.GetPtr(SizeUInt(J))^.SlotIndex = ParentFieldVal then
                  begin
                    Meta.VmtSlots.GetPtr(SizeUInt(J))^.FuncQualName :=
                      ClsName + '.' + NameNode.Text;
                    Break;
                  end;
            end;
          end;
          if (Child.ChildCount > 1) and (Child.ChildAt(1) <> nil) and
            (Child.ChildAt(1).NodeKind = gnkIdentifier) and
            ((TypeMetaSize(Child.ChildAt(1).Text) > 0) or
             SameText(Child.ChildAt(1).Text, ClsName)) then
            FModel.AddConstValue(
              ClsName + '$ret_ptr_' + NameNode.Text, 1);
          if (Child.ChildCount > 1) and (Child.ChildAt(1) <> nil) and
            (Child.ChildAt(1).NodeKind = gnkIdentifier) and
            (SameText(Child.ChildAt(1).Text, 'String') or
             SameText(Child.ChildAt(1).Text, 'AnsiString')) then
            FModel.AddConstValue(
              ClsName + '$ret_str_' + NameNode.Text, 1);
        end;
      end;
    end
    else if Child.NodeKind = gnkClassProperty then
    begin
      for J := 0 to Child.ChildCount - 1 do
      begin
        NameNode := Child.ChildAt(J);
        if (NameNode <> nil) and (NameNode.NodeKind = gnkIdentifier) then
        begin
          if Pos('read:', NameNode.Text) = 1 then
            FModel.AddStringConstValue(
              ClsName + '.' + Child.Text + '$read',
              Copy(NameNode.Text, 6, Length(NameNode.Text)))
          else if Pos('write:', NameNode.Text) = 1 then
            FModel.AddStringConstValue(
              ClsName + '.' + Child.Text + '$write',
              Copy(NameNode.Text, 7, Length(NameNode.Text)));
        end;
      end;
    end;
  end;
  FModel.AddConstValue(
    ClsName + '$size',
    FieldIndex * 8);
  if VmtCount = 0 then
    FModel.AddConstValue(ClsName + '$vmt_count', 0);
  Meta.TypeId := ATypeId;
  Meta.Size := FieldIndex * 8;
  Meta.IsRecord := False;
  Meta.VmtCount := VmtCount;
  Meta.ParentClassId := FModel.TypeAt(ATypeId - 1).ParentTypeId;
  Meta.ParentClassName := ParentName;
  Meta.Interfaces := '';
  Meta.ArrElemSize := 0;
  Meta.ArrElemType := '';
  Meta.ArrLowBound := 0;
  Meta.ArrHighBound := -1;
  Meta.ArrLength := 0;
  Meta.IsStaticArray := False;
  FModel.SetTypeMeta(ATypeId, Meta);
  { Empty / partial subclass: map undeclared Create/CreateFmt/Destroy to the
    nearest non-TObject ancestor that declares them. Encode-time body index is
    unreliable across import order; declaration-time symbols are stable. }
  if ParentName <> '' then
  begin
    for J := 0 to 2 do
    begin
      case J of
        0: FieldName := 'Create';
        1: FieldName := 'CreateFmt';
      else
        FieldName := 'Destroy';
      end;
      if FModel.FindSymbolByName(ClsName + '.' + FieldName) <> 0 then
        Continue;
      InhParentName := ParentName;
      while InhParentName <> '' do
      begin
        if (not SameText(InhParentName, 'TObject')) and
          (FModel.FindSymbolByName(InhParentName + '.' + FieldName) <> 0) then
        begin
          FModel.AddStringConstValue(ClsName + '.$resolve_' + FieldName,
            InhParentName + '.' + FieldName);
          Break;
        end;
        if FModel.LookupStringConstValue(
          InhParentName + '.$resolve_' + FieldName, ParentStringVal) then
        begin
          FModel.AddStringConstValue(ClsName + '.$resolve_' + FieldName,
            ParentStringVal);
          Break;
        end;
        InhParentName := NextClassAncestorName(InhParentName);
      end;
      { CreateFmt often lives only on Exception; fall back to Create. }
      if SameText(FieldName, 'CreateFmt') and
        (not FModel.LookupStringConstValue(ClsName + '.$resolve_CreateFmt',
          ParentStringVal)) then
      begin
        if FModel.LookupStringConstValue(ClsName + '.$resolve_Create',
          ParentStringVal) then
          FModel.AddStringConstValue(ClsName + '.$resolve_CreateFmt',
            ParentStringVal)
        else
        begin
          InhParentName := ParentName;
          while InhParentName <> '' do
          begin
            if (not SameText(InhParentName, 'TObject')) and
              (FModel.FindSymbolByName(InhParentName + '.Create') <> 0) then
            begin
              FModel.AddStringConstValue(ClsName + '.$resolve_CreateFmt',
                InhParentName + '.Create');
              Break;
            end;
            if FModel.LookupStringConstValue(InhParentName + '.$resolve_Create',
              ParentStringVal) then
            begin
              FModel.AddStringConstValue(ClsName + '.$resolve_CreateFmt',
                ParentStringVal);
              Break;
            end;
            InhParentName := NextClassAncestorName(InhParentName);
          end;
        end;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.ProcessTypeSection(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I, J, K: LongInt;
  Child, TypeChild, NameNode: TGreenNode;
  SymbolId: LongInt;
  TypeId: LongInt;
  ParentTypeId: LongInt;
  InterfaceList: string;
  SizeVal: Int64;
  LowBound, HighBound, ArrayLength: Int64;
  AliasTargetId: LongInt;
  AliasTargetMeta: TTypeMetadata;
  AliasHasTargetMeta: Boolean;
  AliasLocalMeta: TTypeMetadata;
  Fact: TSemanticScalarTypeFact;
  TypeName: string;
  TypeKind: string;
  AliasResolveTarget, CtorName, ResolvedCallee: string;
  ReusedSystemIntrinsic: Boolean;
  function IsSystemIntrinsicSelfAlias(const ADeclaration: TGreenNode;
    const AName: string): Boolean;
  var
    TypeNode: TGreenNode;
  begin
    Result := False;
    if not SameText(AOwnerUnitId, 'system') then
      Exit;
    if ADeclaration.ChildCount <> 1 then
      Exit;

    TypeNode := ADeclaration.ChildAt(0);
    if (TypeNode = nil) or (TypeNode.NodeKind <> gnkIdentifier) or
      not SameText(TypeNode.Text, AName) then
      Exit;
    Result := True;
  end;
  function ReusableSystemIntrinsicTypeId(const ADeclaration: TGreenNode;
    const AName: string): LongInt;
  var
    ExistingType: TSemanticType;
  begin
    Result := 0;
    if not IsSystemIntrinsicSelfAlias(ADeclaration, AName) then
      Exit;

    Result := FModel.FindTypeByName(AName);
    if (Result <= 0) or (Result > FModel.TypeCount) then
    begin
      Result := 0;
      Exit;
    end;

    ExistingType := FModel.TypeAt(Result - 1);
    if not (SameText(ExistingType.Kind, 'builtin') or
      SameText(ExistingType.Kind, 'alias')) then
    begin
      Result := 0;
      Exit;
    end;
  end;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkTypeDecl) then
      Continue;
    if Child.Text = '' then
      Continue;
    { Handle {$compiler_root} and {$compiler_type_kind} directives }
    TypeName := Child.Text;
    TypeKind := 'declared';
    if Copy(TypeName, 1, 14) = 'compiler_root:' then
    begin
      TypeName := Copy(TypeName, 15, Length(TypeName));
      TypeKind := 'class';
    end
    else if Copy(TypeName, 1, 18) = 'compiler_type_kind:' then
    begin
      TypeName := Copy(TypeName, 19, Length(TypeName));
      TypeKind := 'enum';
    end;
    TypeId := ReusableSystemIntrinsicTypeId(Child, TypeName);
    ReusedSystemIntrinsic := TypeId > 0;
    if not ReusedSystemIntrinsic then
      TypeId := FModel.AddType(TypeName, TypeKind);
    FModel.SetTypeOwner(TypeId, AOwnerUnitId);
    SymbolId := FModel.AddSymbol(TypeName, 'type', AOwnerUnitId, TypeId,
      Child.ByteOffset);
    if FCurrentScopeId > 0 then
      FModel.SetSymbolScope(SymbolId, FCurrentScopeId);
    if ReusedSystemIntrinsic then
      Continue;
    for J := 0 to Child.ChildCount - 1 do
    begin
      TypeChild := Child.ChildAt(J);
      if (TypeChild <> nil) and (TypeChild.NodeKind = gnkTypeParamList) then
      begin
        FModel.SetTypeParams(TypeId, TypeChild);
        Break;
      end;
    end;
    for J := 0 to Child.ChildCount - 1 do
    begin
      TypeChild := Child.ChildAt(J);
      if TypeChild = nil then
        Continue;
      if TypeChild.NodeKind = gnkEnumType then
        ProcessEnumType(TypeChild, AOwnerUnitId, TypeId)
      else if TypeChild.NodeKind = gnkRecordType then
        ProcessRecordFields(TypeChild, AOwnerUnitId, TypeId)
      else if TypeChild.NodeKind = gnkClassType then
      begin
        { Detect "class of TRef". Parser sets Text='of'. Do NOT use bare
          ChildCount=1 — that also matches empty `T = class(Parent);`. }
        if SameText(TypeChild.Text, 'of') and
          (TypeChild.ChildCount = 1) and
          (TypeChild.ChildAt(0) <> nil) and
          (TypeChild.ChildAt(0).NodeKind = gnkIdentifier) then
        begin
          AliasTargetId := ResolveTypeIdForOwner(
            TypeChild.ChildAt(0).Text, AOwnerUnitId);
          if AliasTargetId > 0 then
          begin
            AliasHasTargetMeta := FModel.GetTypeMeta(
              AliasTargetId, AliasTargetMeta);
            if not FModel.GetTypeMeta(TypeId, AliasLocalMeta) then
              FillChar(AliasLocalMeta, SizeOf(AliasLocalMeta), 0);
            AliasLocalMeta.TypeId := TypeId;
            AliasLocalMeta.AliasTargetTypeId := AliasTargetId;
            if AliasHasTargetMeta and (AliasTargetMeta.Size > 0) then
            begin
              AliasLocalMeta.Size := AliasTargetMeta.Size;
              AliasLocalMeta.VmtCount := AliasTargetMeta.VmtCount;
              AliasLocalMeta.ParentClassId := AliasTargetId;
              if FModel.TypeAt(AliasTargetId - 1).Name <> '' then
                AliasLocalMeta.ParentClassName :=
                  FModel.TypeAt(AliasTargetId - 1).Name;
            end;
            FModel.SetTypeMeta(TypeId, AliasLocalMeta);
            FModel.SetTypeParent(TypeId, AliasTargetId);
            FModel.SetTypeKind(TypeId, 'class');
            if TypeMetaSize(Child.Text) <= 0 then
              FModel.AddConstValue(Child.Text + '$size', 8);
          end;
          { Skip normal class processing — this is a class reference type }
        end
        else
        begin
        ParentTypeId := 0;
        if not SameText(TypeChild.Text, 'interface') then
          ParentTypeId := ImplicitSystemObjectParentTypeId(Child.Text);
        if TypeChild.ChildCount > 0 then
        begin
          if TypeChild.ChildAt(0).NodeKind = gnkIdentifier then
          begin
            ParentTypeId := ResolveTypeIdForOwner(
              TypeChild.ChildAt(0).Text,
              AOwnerUnitId
            );
            if (ParentTypeId > 0) and
              (not SameText(FModel.TypeAt(ParentTypeId - 1).Kind, 'class')) and
              (not SameText(FModel.TypeAt(ParentTypeId - 1).Kind, 'interface')) and
              (not SameText(FModel.TypeAt(ParentTypeId - 1).Kind, 'declared')) and
              (not FModel.LookupConstValue(TypeChild.ChildAt(0).Text + '$size', SizeVal)) and
              (TypeMetaSize(TypeChild.ChildAt(0).Text) <= 0) then
              ParentTypeId := 0;
            if (ParentTypeId = 0) and (Pos('<', TypeChild.ChildAt(0).Text) > 0) then
            begin
              FModel.AddStringConstValue(
                AOwnerUnitId + '.' + Child.Text + '$generic_parent',
                TypeChild.ChildAt(0).Text);
              RegisterStructuredGenericParent(TypeId, TypeChild.ChildAt(0).Text,
                AOwnerUnitId);
            end;
          end;
        end
        else if not SameText(TypeChild.Text, 'interface') then
          ParentTypeId := ImplicitSystemObjectParentTypeId(Child.Text);
        if ParentTypeId > 0 then
          FModel.SetTypeParent(TypeId, ParentTypeId);
        if (not SameText(TypeChild.Text, 'interface')) and
          (TypeMetaSize(Child.Text) <= 0) then
          FModel.AddConstValue(Child.Text + '$size', 8);
        InterfaceList := '';
        for K := 0 to TypeChild.ChildCount - 1 do
        begin
          if (TypeChild.ChildAt(K) <> nil) and
            (TypeChild.ChildAt(K).NodeKind = gnkIdentifier) and
            (Pos('where:', TypeChild.ChildAt(K).Text) = 0) then
          begin
            if (K = 0) and (ParentTypeId > 0) then
              Continue;
            if InterfaceList <> '' then
              InterfaceList := InterfaceList + ',';
            InterfaceList := InterfaceList + TypeChild.ChildAt(K).Text;
          end;
        end;
        if InterfaceList <> '' then
          FModel.AddStringConstValue(Child.Text + '$interfaces', InterfaceList);
        if not SameText(TypeChild.Text, 'interface') then
        begin
          ProcessClassFields(TypeChild, AOwnerUnitId, TypeId);
          if InterfaceList <> '' then
          begin
            VerifyInterfaceImplementation(TypeId, InterfaceList, AOwnerUnitId);
            RegisterInterfaceSlots(TypeId, InterfaceList);
          end;
        end
        else
          ProcessInterfaceMethods(TypeChild, AOwnerUnitId, TypeId);
        end; { else: normal class (not class-of) }
      end
      else if (TypeChild.NodeKind = gnkIdentifier) and
        (Pos('<', TypeChild.Text) > 0) then
        InstantiateGenericType(TypeId, TypeChild.Text, AOwnerUnitId)
      else if TypeChild.NodeKind = gnkArrayType then
      begin
        { TBytes = array of Byte / TBuf = array[0..N] of Char — type-level
          array facts so SizeOf/Length/High and local seeding see dyn/static. }
        if not FModel.GetTypeMeta(TypeId, AliasLocalMeta) then
          FillChar(AliasLocalMeta, SizeOf(AliasLocalMeta), 0);
        AliasLocalMeta.TypeId := TypeId;
        AliasLocalMeta.IsRecord := False;
        AliasLocalMeta.VmtCount := 0;
        AliasLocalMeta.ParentClassId := 0;
        AliasLocalMeta.ParentClassName := '';
        AliasLocalMeta.AliasTargetTypeId := 0;
        NameNode := ArrayElementTypeNode(TypeChild);
        if NameNode <> nil then
          AliasLocalMeta.ArrElemType := NameNode.Text
        else
          AliasLocalMeta.ArrElemType := '';
        AliasLocalMeta.ArrElemSize := 0;
        if NameNode <> nil then
        begin
          if SameText(NameNode.Text, 'Char') or
            SameText(NameNode.Text, 'AnsiChar') or
            SameText(NameNode.Text, 'Byte') or
            SameText(NameNode.Text, 'Boolean') or
            SameText(NameNode.Text, 'ShortInt') then
            AliasLocalMeta.ArrElemSize := 1
          else if SameText(NameNode.Text, 'WideChar') or
            SameText(NameNode.Text, 'Word') or
            SameText(NameNode.Text, 'SmallInt') then
            AliasLocalMeta.ArrElemSize := 2
          else if SameText(NameNode.Text, 'Integer') or
            SameText(NameNode.Text, 'LongInt') or
            SameText(NameNode.Text, 'Cardinal') or
            SameText(NameNode.Text, 'LongWord') or
            SameText(NameNode.Text, 'DWord') then
            AliasLocalMeta.ArrElemSize := 4
          else if TypeMetaSize(NameNode.Text) > 0 then
            AliasLocalMeta.ArrElemSize := TypeMetaSize(NameNode.Text)
          else
            AliasLocalMeta.ArrElemSize := 8;
          FModel.AddStringConstValue(TypeName + '$arr_elem_type', NameNode.Text);
          FModel.AddConstValue(TypeName + '$arr_elem_size',
            AliasLocalMeta.ArrElemSize);
        end;
        if TryGetArrayTypeBounds(TypeChild, LowBound, HighBound, ArrayLength) then
        begin
          AliasLocalMeta.IsStaticArray := True;
          AliasLocalMeta.ArrLowBound := LowBound;
          AliasLocalMeta.ArrHighBound := HighBound;
          AliasLocalMeta.ArrLength := ArrayLength;
          if AliasLocalMeta.ArrElemSize <= 0 then
            AliasLocalMeta.ArrElemSize := 1;
          AliasLocalMeta.Size := ArrayLength * AliasLocalMeta.ArrElemSize;
          FModel.AddConstValue(TypeName + '$arr_static', 1);
          FModel.AddConstValue(TypeName + '$arr_low', LowBound);
          FModel.AddConstValue(TypeName + '$arr_high', HighBound);
          FModel.AddConstValue(TypeName + '$arr_len', ArrayLength);
          FModel.AddConstValue(TypeName + '$size', AliasLocalMeta.Size);
        end
        else
        begin
          { Dynarray descriptor is a managed pointer — SizeOf(TBytes)=8. }
          AliasLocalMeta.IsStaticArray := False;
          AliasLocalMeta.ArrLowBound := 0;
          AliasLocalMeta.ArrHighBound := -1;
          AliasLocalMeta.ArrLength := 0;
          AliasLocalMeta.Size := 8;
          FModel.AddConstValue(TypeName + '$arr', 1);
          FModel.AddConstValue(TypeName + '$size', 8);
        end;
        FModel.SetTypeMeta(TypeId, AliasLocalMeta);
        FModel.SetTypeKind(TypeId, 'array');
      end
      else if (TypeChild.NodeKind = gnkIdentifier) and
        (Length(TypeChild.Text) > 1) and (TypeChild.Text[1] = '^') then
      begin
        { PFoo = ^TFoo: pointer alias, never inherit TFoo record layout. }
        AliasTargetId := ResolveTypeIdForOwner(
          Copy(TypeChild.Text, 2, Length(TypeChild.Text)), AOwnerUnitId);
        if not FModel.GetTypeMeta(TypeId, AliasLocalMeta) then
          FillChar(AliasLocalMeta, SizeOf(AliasLocalMeta), 0);
        AliasLocalMeta.TypeId := TypeId;
        AliasLocalMeta.Size := 8;
        AliasLocalMeta.IsRecord := False;
        AliasLocalMeta.VmtCount := 0;
        AliasLocalMeta.ParentClassId := 0;
        AliasLocalMeta.ParentClassName := '';
        if AliasTargetId > 0 then
          AliasLocalMeta.AliasTargetTypeId := AliasTargetId
        else
          AliasLocalMeta.AliasTargetTypeId := 0;
        FModel.SetTypeMeta(TypeId, AliasLocalMeta);
        FModel.SetTypeKind(TypeId, 'alias');
        FModel.SetTypeScalarFact(TypeId, sskPointer, 64, False);
        FModel.AddConstValue(TypeName + '$size', 8);
        AliasTargetId := FModel.FindTypeByName('Pointer');
        if AliasTargetId > 0 then
          FModel.SetTypeParent(TypeId, AliasTargetId);
      end
      else if TypeChild.NodeKind = gnkIdentifier then
      begin
        AliasTargetId := ResolveTypeIdForOwner(
          TypeChild.Text, AOwnerUnitId);
        if (AliasTargetId > 0) and
          ((AliasTargetId <> TypeId) or
           not IsSystemIntrinsicSelfAlias(Child, TypeName)) then
        begin
          AliasHasTargetMeta := FModel.GetTypeMeta(
            AliasTargetId, AliasTargetMeta);
          if not FModel.GetTypeMeta(TypeId, AliasLocalMeta) then
            FillChar(AliasLocalMeta, SizeOf(AliasLocalMeta), 0);
          AliasLocalMeta.TypeId := TypeId;
          AliasLocalMeta.AliasTargetTypeId := AliasTargetId;
          if AliasHasTargetMeta and (AliasTargetMeta.Size > 0) then
          begin
            AliasLocalMeta.Size := AliasTargetMeta.Size;
            AliasLocalMeta.IsRecord := AliasTargetMeta.IsRecord;
            AliasLocalMeta.VmtCount := AliasTargetMeta.VmtCount;
            AliasLocalMeta.ParentClassId := AliasTargetId;
            if FModel.TypeAt(AliasTargetId - 1).Name <> '' then
              AliasLocalMeta.ParentClassName := FModel.TypeAt(AliasTargetId - 1).Name;
            { Interface/class re-export must keep VmtSlots — name-index last-wins
              would otherwise drop slots and residual-call bare @IChild.Method. }
            if AliasTargetMeta.VmtSlots <> nil then
              AliasLocalMeta.VmtSlots := AliasTargetMeta.VmtSlots;
            { Record re-export must keep Fields — last-wins would otherwise drop
              them and string field loads residual-call @Type.Field (M2:
              TInterfaceSlotMeta re-exported by nextpas.compiler.sema.semantic_model). SetTypeMeta
              clones shared field vecs, so aliasing is ownership-safe. }
            if AliasTargetMeta.Fields <> nil then
              AliasLocalMeta.Fields := AliasTargetMeta.Fields;
          end;
          FModel.SetTypeMeta(TypeId, AliasLocalMeta);
          FModel.SetTypeParent(TypeId, AliasTargetId);
          if TypeMetaIsInterface(TypeChild.Text) or
            SameText(FModel.TypeAt(AliasTargetId - 1).Kind, 'interface') then
          begin
            FModel.SetTypeKind(TypeId, 'interface');
            FModel.AddConstValue(TypeName + '$interface', 1);
            if AliasHasTargetMeta and (AliasTargetMeta.VmtCount > 0) then
              FModel.AddConstValue(TypeName + '$vmt_count', AliasTargetMeta.VmtCount);
            if AliasHasTargetMeta and (AliasTargetMeta.VmtSlots <> nil) then
              for K := 0 to LongInt(AliasTargetMeta.VmtSlots.Count) - 1 do
              begin
                FModel.AddConstValue(TypeName + '$vmt_slot_' +
                  AliasTargetMeta.VmtSlots[SizeUInt(K)].MethodName,
                  AliasTargetMeta.VmtSlots[SizeUInt(K)].SlotIndex);
                { Keep ret-ptr/ret-str flags on the re-export name so
                  TypeMetaRetPtr(IChild, WaitWithOutput) still hits after
                  last-wins name index. }
                if TypeMetaRetPtr(
                  FModel.TypeAt(AliasTargetId - 1).Name,
                  AliasTargetMeta.VmtSlots[SizeUInt(K)].MethodName) or
                  TypeMetaRetPtr(TypeChild.Text,
                  AliasTargetMeta.VmtSlots[SizeUInt(K)].MethodName) then
                  FModel.AddConstValue(TypeName + '$ret_ptr_' +
                    AliasTargetMeta.VmtSlots[SizeUInt(K)].MethodName, 1);
                if TypeMetaRetStr(
                  FModel.TypeAt(AliasTargetId - 1).Name,
                  AliasTargetMeta.VmtSlots[SizeUInt(K)].MethodName) or
                  TypeMetaRetStr(TypeChild.Text,
                  AliasTargetMeta.VmtSlots[SizeUInt(K)].MethodName) then
                  FModel.AddConstValue(TypeName + '$ret_str_' +
                    AliasTargetMeta.VmtSlots[SizeUInt(K)].MethodName, 1);
              end;
          end;
          { Copy scalar / dynarray facts so High(SizeUInt)/Length(TBytesAlias)
            still fold after unit-local aliases. }
          if FModel.GetTypeScalarFact(AliasTargetId, Fact) then
            FModel.SetTypeScalarFact(TypeId, Fact.Kind, Fact.BitWidth,
              Fact.Signed);
          if FModel.LookupConstValue(TypeChild.Text + '$arr', SizeVal) then
          begin
            FModel.AddConstValue(TypeName + '$arr', 1);
            if FModel.LookupConstValue(TypeChild.Text + '$arr_elem_size',
              SizeVal) then
              FModel.AddConstValue(TypeName + '$arr_elem_size', SizeVal);
            if FModel.LookupStringConstValue(
              TypeChild.Text + '$arr_elem_type', InterfaceList) then
              FModel.AddStringConstValue(TypeName + '$arr_elem_type',
                InterfaceList);
            if TypeMetaSize(TypeName) <= 0 then
              FModel.AddConstValue(TypeName + '$size', 8);
          end
          else if (not FModel.GetTypeScalarFact(TypeId, Fact)) and
            (TypeMetaSize(TypeChild.Text) > 0) then
            FModel.AddConstValue(TypeName + '$size',
              TypeMetaSize(TypeChild.Text));
          { Class/exception re-exports (EDoubleFree = unit.path.EDoubleFree):
            seed $resolve_Create so raise Alias.Create marks real body. }
          if AliasHasTargetMeta and (not AliasTargetMeta.IsRecord) and
            ((AliasTargetMeta.VmtCount > 0) or
              (AliasTargetMeta.ParentClassName <> '') or
              (AliasLocalMeta.ParentClassName <> '') or
              SameText(FModel.TypeAt(AliasTargetId - 1).Kind, 'class')) then
          begin
            AliasResolveTarget := FModel.TypeAt(AliasTargetId - 1).Name;
            if AliasResolveTarget = '' then
              AliasResolveTarget := TypeChild.Text;
            for K := 0 to 2 do
            begin
              case K of
                0: CtorName := 'Create';
                1: CtorName := 'CreateFmt';
              else
                CtorName := 'Destroy';
              end;
              if FModel.FindSymbolByName(TypeName + '.' + CtorName) <> 0 then
                Continue;
              if FModel.LookupStringConstValue(
                AliasResolveTarget + '.$resolve_' + CtorName,
                ResolvedCallee) then
                FModel.AddStringConstValue(TypeName + '.$resolve_' + CtorName,
                  ResolvedCallee)
              else if FModel.FindSymbolByName(
                AliasResolveTarget + '.' + CtorName) <> 0 then
                FModel.AddStringConstValue(TypeName + '.$resolve_' + CtorName,
                  AliasResolveTarget + '.' + CtorName)
              else if SameText(CtorName, 'CreateFmt') then
              begin
                if FModel.LookupStringConstValue(
                  AliasResolveTarget + '.$resolve_Create', ResolvedCallee) or
                  FModel.LookupStringConstValue(
                    TypeName + '.$resolve_Create', ResolvedCallee) then
                  FModel.AddStringConstValue(TypeName + '.$resolve_CreateFmt',
                    ResolvedCallee)
                else if FModel.FindSymbolByName(
                  AliasResolveTarget + '.Create') <> 0 then
                  FModel.AddStringConstValue(TypeName + '.$resolve_CreateFmt',
                    AliasResolveTarget + '.Create');
              end;
            end;
          end;
        end;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.InstantiateGenericType(
  const AInstanceTypeId: LongInt;
  const ASpecText: string;
  const AOwnerUnitId: string);
var
  GenericName: string;
  LtPos, GtPos: LongInt;
  GenericTypeId: LongInt;
  GenericType: TSemanticType;
  InstanceName: string;
  I, J, K, BodyIdx: LongInt;
  SizeVal: Int64;
  Symbol: TSemanticSymbol;
  NewSymbolId: LongInt;
  QualPrefix: string;
  ArgStr, ParamStr, ConstraintStr: string;
  ArgTypes: TStringVec;
  ParamNames: TStringVec;
  Constraints: TStringVec;
  MethodShortName: string;
  SubstSig: string;
  Decl: TGreenNode;
  GenericMeta: TTypeMetadata;
  HasGenericMeta: Boolean;
  ParentTypeId: LongInt;
  ParentName: string;
  ParentSym: TSemanticSymbol;
  AlreadyExists: Boolean;
  InstCtorName, ParCtorName: string;
  ParCandIds: array of LongInt;
  SymId, Mid, ParCount: LongInt;
  CandOffset, CandParamCount, CandMinParamCount: LongInt;
  CandSig: string;
  P, Q: PSemanticSymbol;
  Entry: TPendingSignatureEntry;
  InstBodyName: string;
  BodyEntry: TProcedureBodyEntry;
  IsVecInstance, IsArrayTemplate, IsGenericCollectionInstance,
  IsElementManagerInstance, IsHashMapInstance: Boolean;
begin
  LtPos := Pos('<', ASpecText);
  if LtPos <= 0 then
    Exit;
  GenericName := Copy(ASpecText, 1, LtPos - 1);
  GtPos := 0;
  J := 1;
  for I := LtPos + 1 to Length(ASpecText) do
  begin
    if ASpecText[I] = '<' then
      Inc(J)
    else if ASpecText[I] = '>' then
    begin
      Dec(J);
      if J = 0 then
      begin
        GtPos := I;
        Break;
      end;
    end;
  end;
  if GtPos <= LtPos then
    GtPos := Length(ASpecText) + 1;
  ArgStr := Copy(ASpecText, LtPos + 1, GtPos - LtPos - 1);

  GenericTypeId := 0;
  for I := 0 to FModel.TypeCount - 1 do
  begin
    GenericType := FModel.TypeAt(I);
    if SameText(GenericType.Name, GenericName) and
      (GenericType.TypeParams <> '') and
      SameText(GenericType.OwnerUnitId, AOwnerUnitId) then
    begin
      GenericTypeId := GenericType.TypeId;
      Break;
    end;
  end;
  if GenericTypeId <= 0 then
  begin
    for I := 0 to FModel.TypeCount - 1 do
    begin
      GenericType := FModel.TypeAt(I);
      if SameText(GenericType.Name, GenericName) and
        (GenericType.TypeParams <> '') then
      begin
        GenericTypeId := GenericType.TypeId;
        Break;
      end;
    end;
  end;
  if GenericTypeId <= 0 then
  begin
    { Unit-graph order is discovery order, not topo: template units (e.g.
      core.collections.vec) can register after earlier units instantiate
      them, leaving TStringVec & co as empty shells. Defer the call;
      SeedImportedUnitBodies replays deferred specs once all types are in. }
    FGenericRetrySpecs.Push(ASpecText + #9 + AOwnerUnitId + #9 +
      IntToStr(AInstanceTypeId));
    Exit;
  end;
  GenericType := FModel.TypeAt(GenericTypeId - 1);
  ParamStr := GenericType.TypeParams;
  ConstraintStr := GenericType.TypeConstraints;
  if AInstanceTypeId <= 0 then
    Exit;
  FModel.SetTypeInstantiatedFrom(AInstanceTypeId, GenericTypeId);

  ArgTypes := TStringVec.Create;
  I := 1;
  while I <= Length(ArgStr) do
  begin
    J := I;
    GtPos := 0;
    while J <= Length(ArgStr) do
    begin
      if ArgStr[J] = '<' then
        Inc(GtPos)
      else if ArgStr[J] = '>' then
        Dec(GtPos)
      else if (ArgStr[J] = ',') and (GtPos = 0) then
        Break;
      Inc(J);
    end;
    ArgTypes.Push(Trim(Copy(ArgStr, I, J - I)));
    I := J + 1;
  end;

  ParamNames := TStringVec.Create;
  I := 1;
  while I <= Length(ParamStr) do
  begin
    J := I;
    while (J <= Length(ParamStr)) and (ParamStr[J] <> ',') do
      Inc(J);
    ParamNames.Push(Trim(Copy(ParamStr, I, J - I)));
    I := J + 1;
  end;

  for I := 0 to ArgTypes.Count - 1 do
  begin
    if Pos('<', ArgTypes[I]) > 0 then
      ResolveOrInstantiateInlineGeneric(ArgTypes[I], AOwnerUnitId);
  end;

  Constraints := TStringVec.Create;
  I := 1;
  while I <= Length(ConstraintStr) do
  begin
    J := I;
    while (J <= Length(ConstraintStr)) and (ConstraintStr[J] <> ',') do
      Inc(J);
    Constraints.Push(Trim(Copy(ConstraintStr, I, J - I)));
    I := J + 1;
  end;

  if (ParamNames.Count > 0) and (ArgTypes.Count <> ParamNames.Count) then
  begin
    FDiagnostics.EmitError('sema.generic-arity-mismatch', 'sema',
      FRootFileId, 0,
      'generic type ' + GenericName + ' expects ' + IntToStr(ParamNames.Count) +
      ' type argument(s), but ' + IntToStr(ArgTypes.Count) + ' provided');
    Exit;
  end;

  for I := 0 to Constraints.Count - 1 do
  begin
    if (Constraints[I] = '') or (I >= ArgTypes.Count) then
      Continue;
    if not CheckSingleConstraint(ArgTypes[I], Constraints[I]) then
      Exit;
  end;

  InstanceName := FModel.TypeAt(AInstanceTypeId - 1).Name;
  { B4b 缺口乙: persist T→实参 mapping so TypeMetaSize can resolve template
    type params while encoding cloned instance bodies (Create/Push chains
    reference T through TVecBuf/TArray field types). }
  FModel.AddStringConstValue(InstanceName + '.$generic_inst', GenericName);
  for I := 0 to ParamNames.Count - 1 do
    if I < ArgTypes.Count then
      FModel.AddStringConstValue(
        InstanceName + '.$generic_arg_' + ParamNames[I], ArgTypes[I]);
  QualPrefix := GenericName + '.';
  for I := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(I);
    if (Pos(QualPrefix, Symbol.Name) = 1) and
      (SameText(Symbol.Kind, 'method') or
       SameText(Symbol.Kind, 'constructor') or
       SameText(Symbol.Kind, 'destructor')) then
    begin
      MethodShortName := Copy(Symbol.Name, Length(QualPrefix) + 1, MaxInt);
      NewSymbolId := FModel.AddSymbol(
        InstanceName + '.' + MethodShortName,
        Symbol.Kind, AOwnerUnitId, AInstanceTypeId, Symbol.ByteOffset);
      FModel.SetSymbolParamCount(NewSymbolId, Symbol.ParamCount);
      FModel.SetSymbolMinParamCount(NewSymbolId, Symbol.MinParamCount);

      SubstSig := '';
      if (ParamNames.Count > 0) and (ArgTypes.Count >= ParamNames.Count) then
      begin
        { Same-name chain lookup (index built at registration; first entry =
          lowest index, matching the former linear scan). }
        Decl := nil;
        BodyIdx := FirstBodyIndexForNameLocal(GenericName + '.' + MethodShortName);
        if BodyIdx >= 0 then
          Decl := FProcedureBodies.GetPtrUnchecked(BodyIdx)^.Decl;
        if Decl <> nil then
          SubstSig := GetSubstitutedParamSignature(Decl, ParamNames.ToArray, ArgTypes.ToArray)
        else
        begin
          Entry := Default(TPendingSignatureEntry);
          Entry.SymbolId := NewSymbolId;
          Entry.GenericName := GenericName;
          Entry.MethodShortName := MethodShortName;
          Entry.OwnerUnitId := AOwnerUnitId;
          Entry.ParamNames := ClonePendingStringVec(ParamNames, FAllocator);
          Entry.ArgTypes := ClonePendingStringVec(ArgTypes, FAllocator);
          FPendingSignatures.Push(Entry);
        end;
      end;
      FModel.SetSymbolParamSignature(NewSymbolId, SubstSig);
    end;
  end;
  { L5: Propagate constructors from parent types.
    When a generic class inherits from a base class, the base class constructors
    must be accessible through the specialized type. Walk the parent chain and
    copy constructor symbols to the instance type.
    Candidates come from the same-name chain (membership = SameText match,
    ASCII identifiers); reversed collection restores ascending-index order so
    overload tie-breaks see candidates exactly like the former full scans. }
  InstCtorName := InstanceName + '.Create';
  ParentTypeId := FModel.TypeAt(GenericTypeId - 1).ParentTypeId;
  while (ParentTypeId > 0) and (ParentTypeId <= FModel.TypeCount) do
  begin
    ParCtorName := FModel.TypeAt(ParentTypeId - 1).Name + '.Create';
    ParCount := 0;
    SymId := FModel.FirstSymbolIdByName(ParCtorName);
    while SymId > 0 do
    begin
      Inc(ParCount);
      SymId := FModel.NextSymbolIdSameName(SymId);
    end;
    SetLength(ParCandIds, ParCount);
    SymId := FModel.FirstSymbolIdByName(ParCtorName);
    for K := ParCount - 1 downto 0 do
    begin
      ParCandIds[K] := SymId;
      SymId := FModel.NextSymbolIdSameName(SymId);
    end;
    for K := 0 to ParCount - 1 do
    begin
      P := FModel.SymbolPtr(ParCandIds[K] - 1);
      if (P = nil) or not SameText(P^.Kind, 'constructor') then
        Continue;
      { Check if instance already has this constructor }
      AlreadyExists := False;
      Mid := FModel.FirstSymbolIdByName(InstCtorName);
      while Mid > 0 do
      begin
        Q := FModel.SymbolPtr(Mid - 1);
        if Q = nil then
          Break;
        if SameText(Q^.Kind, 'constructor') then
        begin
          AlreadyExists := True;
          Break;
        end;
        Mid := FModel.NextSymbolIdSameName(Mid);
      end;
      if not AlreadyExists then
      begin
        { Snapshot before AddSymbol: Push may realloc symbol storage. }
        CandOffset := P^.ByteOffset;
        CandParamCount := P^.ParamCount;
        CandMinParamCount := P^.MinParamCount;
        CandSig := P^.ParamSignature;
        NewSymbolId := FModel.AddSymbol(
          InstCtorName,
          'constructor', AOwnerUnitId, AInstanceTypeId, CandOffset);
        FModel.SetSymbolParamCount(NewSymbolId, CandParamCount);
        FModel.SetSymbolMinParamCount(NewSymbolId, CandMinParamCount);
        FModel.SetSymbolParamSignature(NewSymbolId, CandSig);
      end;
    end;
    ParentTypeId := FModel.TypeAt(ParentTypeId - 1).ParentTypeId;
  end;
  for I := 0 to FModel.SymbolCount - 1 do
  begin
    P := FModel.SymbolPtr(I);
    if (P = nil) or (Pos(QualPrefix, P^.Name) <> 1) or
      not SameText(P^.Kind, 'field') then
      Continue;
    MethodShortName := Copy(P^.Name, Length(QualPrefix) + 1, MaxInt);
    CandOffset := P^.ByteOffset;
    FModel.AddSymbol(InstanceName + '.' + MethodShortName,
      'field', AOwnerUnitId, AInstanceTypeId, CandOffset);
    SizeVal := TypeMetaFieldIndex(GenericName, MethodShortName);
    if SizeVal >= 0 then
      FModel.AddConstValue(InstanceName + '.' + MethodShortName + '$idx', SizeVal);
    if TypeMetaFieldIsStr(GenericName, MethodShortName) then
      FModel.AddConstValue(InstanceName + '.' + MethodShortName + '$str', 1);
    if TypeMetaFieldIsPtr(GenericName, MethodShortName) then
      FModel.AddConstValue(InstanceName + '.' + MethodShortName + '$ptr', 1);
  end;
  { Copy TypeMetadata (Fields array) from generic type to instance type.
    Field symbols use unqualified names (e.g. 'FHashFunc'), so the loop above
    never matches them against QualPrefix. Without this copy, GetFieldMetaByName
    fails for the instance type and the $idx fallback also fails because the
    const values were never copied. }
  HasGenericMeta := FModel.GetTypeMetaByName(GenericName, GenericMeta);
  if HasGenericMeta then
  begin
    GenericMeta.TypeId := AInstanceTypeId;
    FModel.SetTypeMeta(AInstanceTypeId, GenericMeta);
  end;
  FModel.SetTypeParent(AInstanceTypeId,
    FModel.TypeAt(GenericTypeId - 1).ParentTypeId);
  if GenericType.GenericParent.TemplateTypeId > 0 then
  begin
    GtPos := 0;
    for I := 0 to High(GenericType.GenericParent.ArgIndices) do
      if GenericType.GenericParent.ArgIndices[I] < 0 then
      begin
        GtPos := -1;
        Break;
      end;
    if GtPos = 0 then
    begin
      SubstSig := FModel.TypeAt(GenericType.GenericParent.TemplateTypeId - 1).Name + '<';
      for I := 0 to High(GenericType.GenericParent.ArgIndices) do
      begin
        if I > 0 then
          SubstSig := SubstSig + ',';
        J := GenericType.GenericParent.ArgIndices[I];
        if (J >= 0) and (J < ArgTypes.Count) then
          SubstSig := SubstSig + ArgTypes[J]
        else
          SubstSig := SubstSig + '?';
      end;
      SubstSig := SubstSig + '>';
      GtPos := ResolveOrInstantiateInlineGeneric(SubstSig, AOwnerUnitId);
      if GtPos > 0 then
        FModel.SetTypeParent(AInstanceTypeId, GtPos);
    end;
  end;
  if (GenericType.GenericParent.TemplateTypeId <= 0) or (GtPos < 0) then
  if FModel.LookupStringConstValue(GenericType.OwnerUnitId + '.' + GenericName + '$generic_parent', SubstSig) then
  begin
    for I := 0 to ParamNames.Count - 1 do
    begin
      J := 1;
      while J <= Length(SubstSig) - Length(ParamNames[I]) + 1 do
      begin
        if SameText(Copy(SubstSig, J, Length(ParamNames[I])), ParamNames[I]) and
          ((J = 1) or not (SubstSig[J-1] in ['A'..'Z','a'..'z','0'..'9','_'])) and
          ((J + Length(ParamNames[I]) - 1 = Length(SubstSig)) or
           not (SubstSig[J + Length(ParamNames[I])] in ['A'..'Z','a'..'z','0'..'9','_'])) then
        begin
          SubstSig := Copy(SubstSig, 1, J - 1) + ArgTypes[I] +
            Copy(SubstSig, J + Length(ParamNames[I]), MaxInt);
          J := J + Length(ArgTypes[I]);
        end
        else
          Inc(J);
      end;
    end;
    GtPos := ResolveOrInstantiateInlineGeneric(SubstSig, AOwnerUnitId);
    if GtPos > 0 then
      FModel.SetTypeParent(AInstanceTypeId, GtPos);
  end;
  SizeVal := TypeMetaSize(GenericName);
  if SizeVal > 0 then
    FModel.AddConstValue(InstanceName + '$size', SizeVal)
  else
    FModel.AddConstValue(InstanceName + '$size', 8);
  SizeVal := TypeMetaVmtCount(GenericName);
  HasGenericMeta := FModel.GetTypeMetaByName(GenericName, GenericMeta);
  if (SizeVal >= 0) and HasGenericMeta then
  begin
    FModel.AddConstValue(InstanceName + '$vmt_count', SizeVal);
    if GenericMeta.VmtSlots <> nil then
      for I := 0 to LongInt(GenericMeta.VmtSlots.Count) - 1 do
      begin
        SubstSig := GenericMeta.VmtSlots[SizeUInt(I)].FuncQualName;
        if Pos(GenericName + '.', SubstSig) = 1 then
          SubstSig := InstanceName + Copy(SubstSig, Length(GenericName) + 1, MaxInt);
        FModel.AddStringConstValue(InstanceName + '$vmt_func_' +
          IntToStr(GenericMeta.VmtSlots[SizeUInt(I)].SlotIndex), SubstSig);
        FModel.AddConstValue(InstanceName + '$vmt_slot_' +
          GenericMeta.VmtSlots[SizeUInt(I)].MethodName,
          GenericMeta.VmtSlots[SizeUInt(I)].SlotIndex);
      end;
  end
  else if SizeVal >= 0 then
  begin
    FModel.AddConstValue(InstanceName + '$vmt_count', SizeVal);
    for I := 0 to SizeVal - 1 do
    begin
      if FModel.LookupStringConstValue(GenericName + '$vmt_func_' + IntToStr(I), SubstSig) then
      begin
        if Pos(GenericName + '.', SubstSig) = 1 then
          SubstSig := InstanceName + Copy(SubstSig, Length(GenericName) + 1, MaxInt);
        FModel.AddStringConstValue(InstanceName + '$vmt_func_' + IntToStr(I), SubstSig);
      end;
    end;
  end
  else if TypeMetaVmtCount(InstanceName) < 0 then
    FModel.AddConstValue(InstanceName + '$vmt_count', 0);
  { B4b 分期Ⅱ(白名单): clone template method bodies onto the instance
    name. ResolveClassMethodCalleeName lands on instance symbols
    (TToolStatusEventVec.Count) after instantiation, but without cloned
    bodies the seed queue can never mark/encode them → undefined. Full
    template cloning (2026-08-18) exposed nested families
    (TSpan/TGenericCollection/FInternal*); grow the whitelist per closure,
    one slice per probe. TVec bodies are field/global self-contained
    except Create: its `inherited Create` pulls in the generic base
    instance TGenericCollection<T>.Create, whose body references
    @DoCompare*/@DoEquals* and builds TElementManager<T> — hence the
    TGenericCollection/TElementManager closures below (ROADMAP 注²²). }
  IsVecInstance := SameText(GenericName, 'TVec');
  IsArrayTemplate := SameText(GenericName, 'TArray');
  IsGenericCollectionInstance := SameText(GenericName, 'TGenericCollection');
  IsElementManagerInstance := SameText(GenericName, 'TElementManager');
  IsHashMapInstance := SameText(GenericName, 'THashMap');
  for BodyIdx := 0 to LongInt(FProcedureBodies.Count) - 1 do
  begin
    if Pos(GenericName + '.', FProcedureBodies[BodyIdx].Name) <> 1 then
      Continue;
    MethodShortName := Copy(FProcedureBodies[BodyIdx].Name,
      Length(GenericName) + 2, MaxInt);
    if (MethodShortName = '') or (MethodShortName[1] = '<') then
      Continue; { Fn<T> generic function, not a collection method }
    if not ((SameText(MethodShortName, 'Count')) or
            (SameText(MethodShortName, 'GetDefaultGrowStrategyI')) or
            (IsArrayTemplate and (
               SameText(MethodShortName, 'GetPtrUnchecked') or
               SameText(MethodShortName, 'GetMemory') or
               SameText(MethodShortName, 'GetCount'))) or
            (IsVecInstance and (
               SameText(MethodShortName, 'Create') or
               SameText(MethodShortName, 'Push') or
               SameText(MethodShortName, 'GetPtrUnchecked') or
               SameText(MethodShortName, 'SyncDataPtr') or
               SameText(MethodShortName, 'GetItem') or
               SameText(MethodShortName, 'GetUnchecked') or
               SameText(MethodShortName, 'EnsureCapacity') or
               SameText(MethodShortName, 'GetPtr') or
               SameText(MethodShortName, 'GetCapacity') or
               SameText(MethodShortName, 'Clear') or
               SameText(MethodShortName, 'PushUnchecked') or
               SameText(MethodShortName, 'Zero') or
               SameText(MethodShortName, 'Resize') or
               SameText(MethodShortName, 'ToArray'))) or
            { Generic base chain: TVec.Create clones call
              TGenericCollection<T>.Create (inherited), which assigns
              comparer/equals method pointers (@DoCompare*/@DoEquals*) and
              builds TElementManager<T> (interface impl methods land in
              the vmt table even when called via interface). DefaultProxy
              methods call FInternalComparer/FInternalEquals fields, which
              the runtime encoder cannot lower yet — excluded here; the
              Create body never references them. }
            (IsGenericCollectionInstance and (
               SameText(MethodShortName, 'Create') or
               SameText(MethodShortName, 'GetElementTypeInfo') or
               ((Pos('DoCompare', MethodShortName) = 1) and
                (not SameText(MethodShortName, 'DoCompareDefaultProxy'))) or
               ((Pos('DoEquals', MethodShortName) = 1) and
                (not SameText(MethodShortName, 'DoEqualsDefaultProxy'))))) or
            (IsElementManagerInstance and (
               SameText(MethodShortName, 'Create') or
               SameText(MethodShortName, 'GeTAllocator') or
               SameText(MethodShortName, 'GetElementSize') or
               SameText(MethodShortName, 'GetIsManagedType') or
               SameText(MethodShortName, 'GetElementTypeInfo'))) or
            { THashMap<K,V>: instance methods referenced from the Create
              closure (TProcedureBodyNameFirstMap.Create backlog). Create
              calls InitCapacity (inherited base Create is covered by the
              TGenericCollection slice); InitCapacity calls NextPow2 and
              RecalcMaxLoad. Keep the slice to the closure, one probe per
              slice (ROADMAP 注²²). }
            (IsHashMapInstance and (
               SameText(MethodShortName, 'Create') or
               SameText(MethodShortName, 'InitCapacity') or
               SameText(MethodShortName, 'NextPow2') or
               SameText(MethodShortName, 'RecalcMaxLoad')))) then
      Continue;
    InstBodyName := InstanceName + '.' + MethodShortName;
    { Skip only when this exact template entry was already cloned; overloads
      sharing a name (TVec.Create ×2) each clone onto the instance. }
    K := FirstBodyIndexForNameLocal(InstBodyName);
    while K >= 0 do
    begin
      if FProcedureBodies[K].Body = FProcedureBodies[BodyIdx].Body then
        Break;
      K := FProcedureBodyNameNext[K];
    end;
    if K >= 0 then
      Continue;
    BodyEntry.Name := InstBodyName;
    BodyEntry.Body := FProcedureBodies[BodyIdx].Body;
    BodyEntry.Decl := FProcedureBodies[BodyIdx].Decl;
    BodyEntry.OwnerUnitId := FProcedureBodies[BodyIdx].OwnerUnitId;
    BodyEntry.ScopeId := FProcedureBodies[BodyIdx].ScopeId;
    BodyEntry.Needed := True;
    BodyEntry.Encoded := False;
    BodyEntry.Queued := False;
    FProcedureBodies.Push(BodyEntry);
    IndexProcedureBodyName(InstBodyName, LongInt(FProcedureBodies.Count) - 1);
    FGenericWorkQueue.Push(LongInt(FProcedureBodies.Count) - 1);
  end;
  SubstSig := TypeMetaParentClass(GenericName);
  if SubstSig <> '' then
  begin
    if Pos('<', SubstSig) > 0 then
    begin
      for I := 0 to ParamNames.Count - 1 do
      begin
        J := 1;
        while J <= Length(SubstSig) - Length(ParamNames[I]) + 1 do
        begin
          if SameText(Copy(SubstSig, J, Length(ParamNames[I])), ParamNames[I]) and
            ((J = 1) or not (SubstSig[J-1] in ['A'..'Z','a'..'z','0'..'9','_'])) and
            ((J + Length(ParamNames[I]) - 1 = Length(SubstSig)) or
             not (SubstSig[J + Length(ParamNames[I])] in ['A'..'Z','a'..'z','0'..'9','_'])) then
          begin
            SubstSig := Copy(SubstSig, 1, J - 1) + ArgTypes[I] +
              Copy(SubstSig, J + Length(ParamNames[I]), MaxInt);
            J := J + Length(ArgTypes[I]);
          end
          else
            Inc(J);
        end;
      end;
    end;
    FModel.AddStringConstValue(InstanceName + '$parent_class', SubstSig);
  end
  else
    FModel.AddStringConstValue(InstanceName + '$parent_class',
      FModel.TypeAt(GenericTypeId - 1).Name);
  ArgTypes.Free;
  ParamNames.Free;
  Constraints.Free;
end;

function TSemanticAnalyzer.ResolveOrInstantiateInlineGeneric(
  const ASpecText: string; const AOwnerUnitId: string): LongInt;
var
  GenericName: string;
  LtPos: LongInt;
  I: LongInt;
  GenericType: TSemanticType;
  GenericTypeId: LongInt;
  NewTypeId: LongInt;
  CacheKey: string;
  CacheEntry: TGenericCacheEntry;
begin
  Result := 0;
  LtPos := Pos('<', ASpecText);
  if LtPos <= 0 then
    Exit;

  CacheKey := LowerCase(AOwnerUnitId + '#' + ASpecText);
  for I := 0 to FGenericCache.Count - 1 do
    if FGenericCache[I].Key = CacheKey then
    begin
      Result := FGenericCache[I].TypeId;
      Exit;
    end;
  CacheKey := LowerCase(ASpecText);
  for I := 0 to FGenericCache.Count - 1 do
    if (Length(FGenericCache[I].Key) > Length(CacheKey)) and
      (FGenericCache[I].Key[Length(FGenericCache[I].Key) - Length(CacheKey)] = '#') and
      (Copy(FGenericCache[I].Key, Length(FGenericCache[I].Key) - Length(CacheKey) + 1, MaxInt) = CacheKey) then
    begin
      Result := FGenericCache[I].TypeId;
      FModel.AddSymbol(ASpecText, 'type', AOwnerUnitId, Result, 0);
      CacheEntry.Key := LowerCase(AOwnerUnitId + '#' + ASpecText);
      CacheEntry.TypeId := Result;
      FGenericCache.Push(CacheEntry);
      Exit;
    end;

  GenericName := Copy(ASpecText, 1, LtPos - 1);
  GenericTypeId := 0;
  for I := 0 to FModel.TypeCount - 1 do
  begin
    GenericType := FModel.TypeAt(I);
    if SameText(GenericType.Name, GenericName) and
      (GenericType.TypeParams <> '') then
    begin
      GenericTypeId := GenericType.TypeId;
      Break;
    end;
  end;
  if GenericTypeId <= 0 then
    Exit;
  NewTypeId := FModel.AddType(ASpecText, 'declared');
  FModel.SetTypeOwner(NewTypeId, AOwnerUnitId);
  FModel.AddSymbol(ASpecText, 'type', AOwnerUnitId, NewTypeId, 0);

  CacheEntry.Key := CacheKey;
  CacheEntry.TypeId := NewTypeId;
  FGenericCache.Push(CacheEntry);

  InstantiateGenericType(NewTypeId, ASpecText, AOwnerUnitId);
  Result := NewTypeId;
end;

procedure TSemanticAnalyzer.WalkDeclarations(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I: LongInt;
  Child: TGreenNode;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    case Child.NodeKind of
      gnkVarSection, gnkThreadVarSection:
        ProcessVarSection(Child, AOwnerUnitId);
      gnkConstSection:
        ProcessConstSection(Child, AOwnerUnitId);
      gnkTypeSection:
        ProcessTypeSection(Child, AOwnerUnitId);
      gnkProcedureDecl:
        ProcessProcedureDecl(Child, AOwnerUnitId);
      gnkFunctionDecl:
        ProcessFunctionDecl(Child, AOwnerUnitId);
      gnkInterfaceSection, gnkImplementationSection:
        WalkDeclarations(Child, AOwnerUnitId);
    end;
  end;
end;
