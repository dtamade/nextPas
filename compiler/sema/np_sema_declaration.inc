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
  SetLength(Meta.Fields, 0);
  SetLength(Meta.VmtSlots, 0);
  SetLength(Meta.RetPtrMethods, 0);
  SetLength(Meta.Properties, 0);
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
    SetLength(Meta.Fields, Length(Meta.Fields) + 1);
    Meta.Fields[High(Meta.Fields)].Name := Child.Text;
    Meta.Fields[High(Meta.Fields)].Index := FieldIndex;
    { 检测字段类型 — 与 class 字段路径一致 }
    Meta.Fields[High(Meta.Fields)].IsString :=
      (TypeChild <> nil) and (TypeChild.NodeKind = gnkIdentifier) and
      (SameText(TypeChild.Text, 'String') or
       SameText(TypeChild.Text, 'AnsiString'));
    Meta.Fields[High(Meta.Fields)].IsPointer := False;
    Meta.Fields[High(Meta.Fields)].IsDynArray :=
      (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
      (Child.ChildAt(0).NodeKind = gnkArrayType);
    Meta.Fields[High(Meta.Fields)].IsRecord :=
      (FieldTypeId > 0) and FModel.GetTypeMeta(FieldTypeId, FieldMeta) and
      FieldMeta.IsRecord;
    Meta.Fields[High(Meta.Fields)].TypeId := FieldTypeId;
    if Meta.Fields[High(Meta.Fields)].IsString then
      Inc(FieldIndex, 3)
    else if Meta.Fields[High(Meta.Fields)].IsDynArray then
      Inc(FieldIndex, 2)
    else if Meta.Fields[High(Meta.Fields)].IsRecord then
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
  IntfName, ParentIntfName, MethShort: string;
  SymbolId: LongInt;
  Meta: TTypeMetadata;
  ParentIntfTypeId: LongInt;
  Symbol: TSemanticSymbol;
begin
  if ANode = nil then
    Exit;
  FillChar(Meta, SizeOf(Meta), 0);
  IntfName := FModel.TypeAt(ATypeId - 1).Name;
  if (ANode.ChildCount > 0) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) then
  begin
    ParentIntfName := ANode.ChildAt(0).Text;
    ParentIntfTypeId := 0;
    for I := 0 to FModel.TypeCount - 1 do
      if SameText(FModel.TypeAt(I).Name, ParentIntfName) then
      begin
        ParentIntfTypeId := FModel.TypeAt(I).TypeId;
        Break;
      end;
    if ParentIntfTypeId > 0 then
    begin
      FModel.SetTypeParent(ATypeId, ParentIntfTypeId);
      for I := 0 to FModel.SymbolCount - 1 do
      begin
        Symbol := FModel.SymbolAt(I);
        if (Symbol.TypeId = ParentIntfTypeId) and
          SameText(Symbol.Kind, 'method') and
          (Pos(ParentIntfName + '.', Symbol.Name) = 1) then
        begin
          MethShort := Copy(Symbol.Name, Length(ParentIntfName) + 2, MaxInt);
          SymbolId := FModel.AddSymbol(IntfName + '.' + MethShort,
            'method', AOwnerUnitId, ATypeId, Symbol.ByteOffset);
          FModel.SetSymbolParamCount(SymbolId, Symbol.ParamCount);
          FModel.SetSymbolMinParamCount(SymbolId, Symbol.MinParamCount);
          FModel.SetSymbolParamSignature(SymbolId, Symbol.ParamSignature);
          if TypeMetaRetStr(ParentIntfName, MethShort) then
            FModel.AddConstValue(IntfName + '$ret_str_' + MethShort, 1);
        end;
      end;
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
      end;
    end;
  end;
  with Meta do
  begin
    TypeId := ATypeId;
    Size := 8;
    IsRecord := False;
    VmtCount := 0;
    ParentClassId := 0;
    ParentClassName := '';
    Interfaces := '';
    ArrElemSize := 0;
    ArrElemType := '';
    ArrLowBound := 0;
    ArrHighBound := -1;
    ArrLength := 0;
    IsStaticArray := False;
    SetLength(Fields, 0);
    SetLength(VmtSlots, 0);
    SetLength(RetPtrMethods, 0);
    SetLength(Properties, 0);
  end;
  for I := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(I);
    if SameText(Symbol.Kind, 'method') and
      (Pos(IntfName + '.', Symbol.Name) = 1) then
    begin
      MethShort := Copy(Symbol.Name, Length(IntfName) + 2, MaxInt);
      SetLength(Meta.VmtSlots, Meta.VmtCount + 1);
      Meta.VmtSlots[Meta.VmtCount].MethodName := MethShort;
      Meta.VmtSlots[Meta.VmtCount].SlotIndex := Meta.VmtCount;
      Meta.VmtSlots[Meta.VmtCount].FuncQualName := IntfName + '.' + MethShort;
      Inc(Meta.VmtCount);
    end;
  end;
  FModel.AddConstValue(IntfName + '$vmt_count', Meta.VmtCount);
  FModel.AddConstValue(IntfName + '$interface', 1);
  FModel.SetTypeMeta(ATypeId, Meta);
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
    SlotOffset := Length(Meta.Fields) + 1;
  SetLength(Meta.InterfaceSlots, IntfCount);
  for I := 0 to IntfCount - 1 do
  begin
    Meta.InterfaceSlots[I].InterfaceName := IntfNames[I];
    Meta.InterfaceSlots[I].SlotOffset := SlotOffset + I;
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

procedure TSemanticAnalyzer.CompletePendingSignatures;
var
  I, BodyIdx: LongInt;
  Decl: TGreenNode;
  SubstSig: string;
  QualName: string;
begin
  for I := 0 to Length(FPendingSignatures) - 1 do
  begin
    QualName := FPendingSignatures[I].GenericName + '.' +
      FPendingSignatures[I].MethodShortName;
    Decl := nil;
    for BodyIdx := 0 to Length(FProcedureBodies) - 1 do
    begin
      if SameText(FProcedureBodies[BodyIdx].Name, QualName) and
        SameText(FProcedureBodies[BodyIdx].OwnerUnitId,
          FPendingSignatures[I].OwnerUnitId) then
      begin
        Decl := FProcedureBodies[BodyIdx].Decl;
        Break;
      end;
    end;
    if Decl = nil then
      for BodyIdx := 0 to Length(FProcedureBodies) - 1 do
        if SameText(FProcedureBodies[BodyIdx].Name, QualName) then
        begin
          Decl := FProcedureBodies[BodyIdx].Decl;
          Break;
        end;
    if Decl <> nil then
    begin
      SubstSig := GetSubstitutedParamSignature(Decl,
        FPendingSignatures[I].ParamNames,
        FPendingSignatures[I].ArgTypes);
      FModel.SetSymbolParamSignature(FPendingSignatures[I].SymbolId, SubstSig);
    end;
  end;
  SetLength(FPendingSignatures, 0);
end;

procedure TSemanticAnalyzer.ProcessClassFields(const ANode: TGreenNode;
  const AOwnerUnitId: string; const ATypeId: LongInt);
var
  I, J: LongInt;
  Child, NameNode: TGreenNode;
  FieldTypeId: LongInt;
  FieldIndex: LongInt;
  ClassScopeId: LongInt;
  ClsName, ParentName, ConstName, FieldName, ParentStringVal: string;
  CurrentVisibility: string;
  ParentFieldVal: Int64;
  DotPos, IdxPos: LongInt;
  ParentTypeId: LongInt;
  PointerTypeId: LongInt;
  SymbolId: LongInt;
  Meta, ParentMeta: TTypeMetadata;
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
  SetLength(Meta.Fields, 0);
  SetLength(Meta.VmtSlots, 0);
  SetLength(Meta.RetPtrMethods, 0);
  SetLength(Meta.Properties, 0);
  HasParentMeta := (ParentName <> '') and FModel.GetTypeMetaByName(ParentName, ParentMeta);
  if ParentName <> '' then
  begin
    ParentFieldVal := TypeMetaSize(ParentName);
    if ParentFieldVal > 0 then
    begin
      FieldIndex := LongInt(ParentFieldVal) div 8;
      if HasParentMeta then
      begin
        for J := 0 to High(ParentMeta.Fields) do
        begin
          FModel.AddConstValue(ClsName + '.' + ParentMeta.Fields[J].Name + '$idx',
            ParentMeta.Fields[J].Index);
          if ParentMeta.Fields[J].IsString then
            FModel.AddConstValue(ClsName + '.' + ParentMeta.Fields[J].Name + '$str', 1);
          if ParentMeta.Fields[J].IsPointer then
            FModel.AddConstValue(ClsName + '.' + ParentMeta.Fields[J].Name + '$ptr', 1);
          if ParentMeta.Fields[J].IsDynArray then
            FModel.AddConstValue(ClsName + '.' + ParentMeta.Fields[J].Name + '$arr', 1);
          if FModel.LookupStringConstValue(
            ParentName + '.' + ParentMeta.Fields[J].Name + '$arr_elem_type',
            ParentStringVal) then
            FModel.AddStringConstValue(
              ClsName + '.' + ParentMeta.Fields[J].Name + '$arr_elem_type',
              ParentStringVal);
          if FModel.LookupConstValue(
            ParentName + '.' + ParentMeta.Fields[J].Name + '$arr_elem_size',
            ParentFieldVal) then
            FModel.AddConstValue(
              ClsName + '.' + ParentMeta.Fields[J].Name + '$arr_elem_size',
              ParentFieldVal);
          SetLength(Meta.Fields, Length(Meta.Fields) + 1);
          Meta.Fields[High(Meta.Fields)] := ParentMeta.Fields[J];
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
      for J := 0 to High(ParentMeta.VmtSlots) do
      begin
        FModel.AddConstValue(ClsName + '$vmt_slot_' +
          ParentMeta.VmtSlots[J].MethodName, ParentMeta.VmtSlots[J].SlotIndex);
        FModel.AddStringConstValue(ClsName + '$vmt_func_' +
          IntToStr(ParentMeta.VmtSlots[J].SlotIndex),
          ParentMeta.VmtSlots[J].FuncQualName);
        SetLength(Meta.VmtSlots, Length(Meta.VmtSlots) + 1);
        Meta.VmtSlots[High(Meta.VmtSlots)] := ParentMeta.VmtSlots[J];
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
      SetLength(Meta.Fields, Length(Meta.Fields) + 1);
      Meta.Fields[High(Meta.Fields)].Name := Child.Text;
      Meta.Fields[High(Meta.Fields)].Index :=
        TypeMetaFieldIndex(ClsName, Child.Text);
      Meta.Fields[High(Meta.Fields)].IsString :=
        (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        (SameText(Child.ChildAt(0).Text, 'String') or
         SameText(Child.ChildAt(0).Text, 'AnsiString'));
      Meta.Fields[High(Meta.Fields)].IsPointer :=
        (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        ((TypeMetaSize(Child.ChildAt(0).Text) > 0) or
         SameText(Child.ChildAt(0).Text, ClsName));
      Meta.Fields[High(Meta.Fields)].IsDynArray := IsDynArrayField;
      Meta.Fields[High(Meta.Fields)].TypeId := FieldTypeId;
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
            SetLength(Meta.VmtSlots, Length(Meta.VmtSlots) + 1);
            Meta.VmtSlots[High(Meta.VmtSlots)].MethodName := NameNode.Text;
            Meta.VmtSlots[High(Meta.VmtSlots)].SlotIndex := VmtCount;
            Meta.VmtSlots[High(Meta.VmtSlots)].FuncQualName :=
              ClsName + '.' + NameNode.Text;
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
              for J := 0 to High(Meta.VmtSlots) do
                if Meta.VmtSlots[J].SlotIndex = ParentFieldVal then
                begin
                  Meta.VmtSlots[J].FuncQualName := ClsName + '.' + NameNode.Text;
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
end;

procedure TSemanticAnalyzer.ProcessTypeSection(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I, J, K: LongInt;
  Child, TypeChild: TGreenNode;
  SymbolId: LongInt;
  TypeId: LongInt;
  ParentTypeId: LongInt;
  InterfaceList: string;
  SizeVal: Int64;
  AliasTargetId: LongInt;
  AliasTargetMeta: TTypeMetadata;
  AliasHasTargetMeta: Boolean;
  AliasLocalMeta: TTypeMetadata;
  TypeName: string;
  TypeKind: string;
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
        { Detect "class of TRef" — exactly one identifier child, no body }
        if (not SameText(TypeChild.Text, 'interface')) and
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
          end;
          FModel.SetTypeMeta(TypeId, AliasLocalMeta);
          FModel.SetTypeParent(TypeId, AliasTargetId);
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
  I, J, BodyIdx: LongInt;
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
    Exit;
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
        Decl := nil;
        for BodyIdx := 0 to Length(FProcedureBodies) - 1 do
        begin
          if SameText(FProcedureBodies[BodyIdx].Name, GenericName + '.' + MethodShortName) then
          begin
            Decl := FProcedureBodies[BodyIdx].Decl;
            Break;
          end;
        end;
        if Decl <> nil then
          SubstSig := GetSubstitutedParamSignature(Decl, ParamNames.ToArray, ArgTypes.ToArray)
        else
        begin
          BodyIdx := Length(FPendingSignatures);
          SetLength(FPendingSignatures, BodyIdx + 1);
          FPendingSignatures[BodyIdx].SymbolId := NewSymbolId;
          FPendingSignatures[BodyIdx].GenericName := GenericName;
          FPendingSignatures[BodyIdx].MethodShortName := MethodShortName;
          FPendingSignatures[BodyIdx].OwnerUnitId := AOwnerUnitId;
          SetLength(FPendingSignatures[BodyIdx].ParamNames, ParamNames.Count);
          for BodyIdx := 0 to ParamNames.Count - 1 do
            FPendingSignatures[High(FPendingSignatures)].ParamNames[BodyIdx] := ParamNames[BodyIdx];
          SetLength(FPendingSignatures[High(FPendingSignatures)].ArgTypes, ArgTypes.Count);
          for BodyIdx := 0 to ArgTypes.Count - 1 do
            FPendingSignatures[High(FPendingSignatures)].ArgTypes[BodyIdx] := ArgTypes[BodyIdx];
        end;
      end;
      FModel.SetSymbolParamSignature(NewSymbolId, SubstSig);
    end;
  end;
  { L5: Propagate constructors from parent types.
    When a generic class inherits from a base class, the base class constructors
    must be accessible through the specialized type. Walk the parent chain and
    copy constructor symbols to the instance type. }
  ParentTypeId := FModel.TypeAt(GenericTypeId - 1).ParentTypeId;
  while (ParentTypeId > 0) and (ParentTypeId <= FModel.TypeCount) do
  begin
    ParentName := FModel.TypeAt(ParentTypeId - 1).Name;
    for I := 0 to FModel.SymbolCount - 1 do
    begin
      ParentSym := FModel.SymbolAt(I);
      if SameText(ParentSym.Name, ParentName + '.Create') and
        SameText(ParentSym.Kind, 'constructor') then
      begin
        { Check if instance already has this constructor }
        AlreadyExists := False;
        for J := 0 to FModel.SymbolCount - 1 do
        begin
          if SameText(FModel.SymbolAt(J).Name, InstanceName + '.Create') and
            SameText(FModel.SymbolAt(J).Kind, 'constructor') then
          begin
            AlreadyExists := True;
            Break;
          end;
        end;
        if not AlreadyExists then
        begin
          NewSymbolId := FModel.AddSymbol(
            InstanceName + '.Create',
            'constructor', AOwnerUnitId, AInstanceTypeId, ParentSym.ByteOffset);
          FModel.SetSymbolParamCount(NewSymbolId, ParentSym.ParamCount);
          FModel.SetSymbolMinParamCount(NewSymbolId, ParentSym.MinParamCount);
          FModel.SetSymbolParamSignature(NewSymbolId, ParentSym.ParamSignature);
        end;
      end;
    end;
    ParentTypeId := FModel.TypeAt(ParentTypeId - 1).ParentTypeId;
  end;
  for I := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(I);
    if (Pos(QualPrefix, Symbol.Name) = 1) and
      SameText(Symbol.Kind, 'field') then
    begin
      MethodShortName := Copy(Symbol.Name, Length(QualPrefix) + 1, MaxInt);
      FModel.AddSymbol(InstanceName + '.' + MethodShortName,
        'field', AOwnerUnitId, AInstanceTypeId, Symbol.ByteOffset);
      SizeVal := TypeMetaFieldIndex(GenericName, MethodShortName);
      if SizeVal >= 0 then
        FModel.AddConstValue(InstanceName + '.' + MethodShortName + '$idx', SizeVal);
      if TypeMetaFieldIsStr(GenericName, MethodShortName) then
        FModel.AddConstValue(InstanceName + '.' + MethodShortName + '$str', 1);
      if TypeMetaFieldIsPtr(GenericName, MethodShortName) then
        FModel.AddConstValue(InstanceName + '.' + MethodShortName + '$ptr', 1);
    end;
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
    for I := 0 to High(GenericMeta.VmtSlots) do
    begin
      SubstSig := GenericMeta.VmtSlots[I].FuncQualName;
      if Pos(GenericName + '.', SubstSig) = 1 then
        SubstSig := InstanceName + Copy(SubstSig, Length(GenericName) + 1, MaxInt);
      FModel.AddStringConstValue(InstanceName + '$vmt_func_' +
        IntToStr(GenericMeta.VmtSlots[I].SlotIndex), SubstSig);
      FModel.AddConstValue(InstanceName + '$vmt_slot_' +
        GenericMeta.VmtSlots[I].MethodName, GenericMeta.VmtSlots[I].SlotIndex);
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
      gnkVarSection:
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
