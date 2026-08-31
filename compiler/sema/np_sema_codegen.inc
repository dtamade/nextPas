{$I np_sema_encode_runtime_expr.inc}
function TSemanticAnalyzer.EncodeRuntimeIntExprFold(
  const ANode: TGreenNode; out ABlob: string): Boolean;
var
  LExprId: LongInt;
begin
  Result := EncodeRuntimeIntExprFoldCore(ANode, ABlob, LExprId);
end;

function TSemanticAnalyzer.EncodeRuntimeIntExprFold(
  const ANode: TGreenNode; out ABlob: string; out AExprId: LongInt): Boolean;
begin
  Result := EncodeRuntimeIntExprFoldCore(ANode, ABlob, AExprId);
end;

function TSemanticAnalyzer.BuildRuntimeArrayElementAddressHirExpr(
  const ANode: TGreenNode; out AExprId: LongInt): Boolean;
var
  ArrayName: string;
  Children: array of LongInt;
  Fact: TSemanticScalarTypeFact;
  IndexExpr, Expr: TSemanticHirExpr;
  CandidateTypeId, ElementTypeId, IndexExprId, IndexTypeId, SymbolId: LongInt;
  ElementTypeName: string;
begin
  AExprId := 0;
  if (ANode = nil) or (ANode.NodeKind <> gnkArrayAccess) or
    (ANode.ChildCount < 2) then
    Exit(False);
  if (ANode.ChildAt(0) = nil) or
    (ANode.ChildAt(0).NodeKind <> gnkIdentifier) then
    Exit(False);

  ArrayName := ANode.ChildAt(0).Text;
  if (ArrayName = '') or (not IsRuntimeArrVar(ArrayName)) then
    Exit(False);
  SymbolId := FModel.FindSymbolByName(ArrayName);
  if SymbolId <= 0 then
    Exit(False);
  if not BuildRuntimeScalarHirExpr(ANode.ChildAt(1), IndexExprId) then
    Exit(False);
  if (IndexExprId <= 0) or (IndexExprId > FModel.HirExprCount) then
    Exit(False);

  IndexExpr := FModel.HirExprAt(IndexExprId - 1);
  IndexTypeId := IndexExpr.TypeId;
  if (IndexTypeId <= 0) or
    (not FModel.GetTypeScalarFact(IndexTypeId, Fact)) or
    (Fact.Kind <> sskInt) then
    Exit(False);

  ElementTypeId := FModel.FindTypeByName('Integer');
  if FModel.LookupStringConstValue(ArrayName + '$arr_elem_type',
    ElementTypeName) and (ElementTypeName <> '') then
  begin
    CandidateTypeId := FModel.FindTypeByName(ElementTypeName);
    if CandidateTypeId > 0 then
      ElementTypeId := CandidateTypeId;
  end;
  if ElementTypeId <= 0 then
    Exit(False);

  SetLength(Children, 1);
  Children[0] := IndexExprId;
  AExprId := FModel.AddHirExpr(
    shekArrayElem, ElementTypeId, SymbolId, Children,
    0, 0.0, '', '', 0, shvcAddress
  );
  if AExprId <= 0 then
    Exit(False);
  Expr := FModel.HirExprAt(AExprId - 1);
  Result := (Expr.Kind = shekArrayElem) and (Expr.ValueClass = shvcAddress);
end;

function TSemanticAnalyzer.FindSymbolByNameAndType(const AName: string;
  const ATypeId: LongInt): LongInt;
var
  I: LongInt;
  Symbol: TSemanticSymbol;
begin
  for I := FModel.SymbolCount - 1 downto 0 do
  begin
    Symbol := FModel.SymbolAt(I);
    if SameText(Symbol.Name, AName) and
      ((ATypeId <= 0) or (Symbol.TypeId = ATypeId)) then
      Exit(Symbol.SymbolId);
  end;
  Result := 0;
end;

function TSemanticAnalyzer.EnsureSelfSymbolId(out ASelfTypeId: LongInt): LongInt;
begin
  ASelfTypeId := 0;
  if FCurrentMethodClass = '' then
    Exit(0);
  ASelfTypeId := FModel.FindTypeByName(FCurrentMethodClass);
  if ASelfTypeId <= 0 then
    Exit(0);
  Result := FindSymbolByNameAndType('self', ASelfTypeId);
  if Result = 0 then
    Result := FModel.AddSymbol('self', 'parameter', '', ASelfTypeId, 0);
end;

function TSemanticAnalyzer.LookupFieldMetaByTypeName(const ATypeName,
  AFieldName: string; out AOwnerTypeId: LongInt;
  out AFieldMeta: TFieldMeta): Boolean;
begin
  AOwnerTypeId := FModel.FindTypeByName(ATypeName);
  if AOwnerTypeId <= 0 then
    Exit(False);
  Result := FModel.GetFieldMetaByName(AOwnerTypeId, AFieldName, AFieldMeta);
end;

function TSemanticAnalyzer.BuildRecordBaseAddressExpr(const ARecordName,
  ARecordTypeName: string; out AExprId: LongInt): Boolean;
var
  Children: array of LongInt;
  RecordTypeId, RecordSymbolId: LongInt;
begin
  AExprId := 0;
  if (ARecordName = '') or (ARecordTypeName = '') then
    Exit(False);

  RecordTypeId := FModel.FindTypeByName(ARecordTypeName);
  if RecordTypeId <= 0 then
    Exit(False);

  RecordSymbolId := FindSymbolByNameAndType(ARecordName, RecordTypeId);
  if RecordSymbolId = 0 then
    RecordSymbolId := FModel.FindSymbolByName(ARecordName);
  if RecordSymbolId <= 0 then
    Exit(False);

  SetLength(Children, 0);
  AExprId := FModel.AddHirExpr(
    shekSymbolAddress, RecordTypeId, RecordSymbolId, Children,
    0,
    0.0, '', '', 0, shvcAddress
  );
  Result := AExprId > 0;
end;

function TSemanticAnalyzer.BuildClassBaseAddressExpr(const ABaseName,
  AClassName: string; out AExprId: LongInt): Boolean;
var
  Children: array of LongInt;
  BaseTypeId, PointerTypeId, BaseSymbolId, PointerExprId: LongInt;
  SelfTypeId: LongInt;
begin
  AExprId := 0;
  PointerTypeId := FModel.FindTypeByName('Pointer');
  if PointerTypeId <= 0 then
    Exit(False);
  BaseTypeId := FModel.FindTypeByName(AClassName);
  if BaseTypeId <= 0 then
    Exit(False);

  if SameText(ABaseName, 'self') then
  begin
    BaseSymbolId := EnsureSelfSymbolId(SelfTypeId);
    if (BaseSymbolId <= 0) or (SelfTypeId <> BaseTypeId) then
      Exit(False);
  end
  else
  begin
    BaseSymbolId := FindSymbolByNameAndType(ABaseName, BaseTypeId);
    if BaseSymbolId = 0 then
      BaseSymbolId := FModel.FindSymbolByName(ABaseName);
    if BaseSymbolId <= 0 then
      Exit(False);
  end;

  SetLength(Children, 0);
  PointerExprId := FModel.AddHirExpr(
    shekSymbolValue, PointerTypeId, BaseSymbolId, Children,
    0,
    0.0, '', '', 0, shvcScalar
  );
  SetLength(Children, 1);
  Children[0] := PointerExprId;
  AExprId := FModel.AddHirExpr(
    shekDeref, BaseTypeId, 0,
    Children, 0, 0.0, '', '', 0, shvcAddress
  );
  Result := AExprId > 0;
end;

function TSemanticAnalyzer.BuildClassFieldTargetExpr(const ABaseName,
  AClassName, AFieldName: string; out AExprId: LongInt): Boolean;
var
  Children: array of LongInt;
  BaseTypeId, BaseExprId: LongInt;
  FieldMeta: TFieldMeta;
begin
  AExprId := 0;
  if not LookupFieldMetaByTypeName(AClassName, AFieldName, BaseTypeId,
    FieldMeta) then
    Exit(False);
  if not BuildClassBaseAddressExpr(ABaseName, AClassName, BaseExprId) then
    Exit(False);

  SetLength(Children, 1);
  Children[0] := BaseExprId;
  AExprId := FModel.AddHirExpr(
    shekField, FieldMeta.TypeId, 0,
    Children, FieldMeta.Index, 0.0, FieldMeta.Name, '', 0, shvcAddress
  );
  Result := AExprId > 0;
end;

function TSemanticAnalyzer.TryCurrentClassFieldArrayAccess(
  const AArrayAccessNode: TGreenNode; out AFieldName: string): Boolean;
var
  BaseName, OwnerClassName: string;
begin
  Result := TryClassFieldArrayAccess(AArrayAccessNode, BaseName, OwnerClassName,
    AFieldName) and SameText(BaseName, 'self') and
    SameText(OwnerClassName, FCurrentMethodClass);
end;

function TSemanticAnalyzer.TryClassFieldArrayAccess(
  const AArrayAccessNode: TGreenNode; out ABaseName, AClassName,
  AFieldName: string): Boolean;
var
  BaseNode, FieldNode, ReceiverNode: TGreenNode;
begin
  ABaseName := '';
  AClassName := '';
  AFieldName := '';
  if (AArrayAccessNode = nil) or
    (AArrayAccessNode.NodeKind <> gnkArrayAccess) or
    (AArrayAccessNode.ChildCount < 2) or
    (AArrayAccessNode.ChildAt(0) = nil) then
    Exit(False);

  BaseNode := AArrayAccessNode.ChildAt(0);
  if (BaseNode.NodeKind = gnkIdentifier) and (FCurrentMethodClass <> '') then
  begin
    AFieldName := BaseNode.Text;
    if (AFieldName <> '') and
      (not IsRuntimeArrVar(AFieldName)) and
      (not IsRuntimeStrVar(AFieldName)) and
      (TypeMetaFieldIndex(FCurrentMethodClass, AFieldName) >= 0) then
    begin
      ABaseName := 'self';
      AClassName := FCurrentMethodClass;
    end
    else
      AFieldName := '';
  end
  else if (BaseNode.NodeKind = gnkDotAccess) and
    (BaseNode.ChildCount >= 2) and
    (BaseNode.ChildAt(0) <> nil) and
    (BaseNode.ChildAt(1) <> nil) and
    (BaseNode.ChildAt(0).NodeKind = gnkIdentifier) and
    (BaseNode.ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    ReceiverNode := BaseNode.ChildAt(0);
    FieldNode := BaseNode.ChildAt(1);
    AFieldName := FieldNode.Text;
    if SameText(ReceiverNode.Text, 'Self') and (FCurrentMethodClass <> '') and
      (TypeMetaFieldIndex(FCurrentMethodClass, AFieldName) >= 0) then
    begin
      ABaseName := 'self';
      AClassName := FCurrentMethodClass;
    end
    else
    begin
      AClassName := LookupClassVar(ReceiverNode.Text);
      if (AClassName <> '') and
        (TypeMetaFieldIndex(AClassName, AFieldName) >= 0) then
        ABaseName := ReceiverNode.Text
      else
      begin
        AClassName := '';
        AFieldName := '';
      end;
    end;
  end;

  Result := (ABaseName <> '') and (AClassName <> '') and
    (AFieldName <> '');
end;

function TSemanticAnalyzer.BuildClassFieldArrayElementTargetExpr(
  const AArrayAccessNode: TGreenNode; out AExprId: LongInt): Boolean;
var
  Children: array of LongInt;
  ArrayExpr, FieldExpr, IndexExpr: TSemanticHirExpr;
  ElementTypeId, FieldExprId, IndexExprId, IndexTypeId: LongInt;
  BaseName, OwnerClassName, ElementTypeName, FieldName: string;
  Fact: TSemanticScalarTypeFact;
begin
  AExprId := 0;
  if not TryClassFieldArrayAccess(AArrayAccessNode, BaseName,
    OwnerClassName,
    FieldName) then
    Exit(False);

  if not FModel.LookupStringConstValue(
    OwnerClassName + '.' + FieldName + '$arr_elem_type',
    ElementTypeName) then
    Exit(False);
  ElementTypeId := FModel.FindTypeByName(ElementTypeName);
  if ElementTypeId <= 0 then
    Exit(False);

  if not BuildClassFieldTargetExpr(BaseName, OwnerClassName, FieldName,
    FieldExprId) then
    Exit(False);
  if (FieldExprId <= 0) or (FieldExprId > FModel.HirExprCount) then
    Exit(False);
  FieldExpr := FModel.HirExprAt(FieldExprId - 1);
  if (FieldExpr.Kind <> shekField) or
    (FieldExpr.ValueClass <> shvcAddress) then
    Exit(False);

  if not BuildRuntimeScalarHirExpr(AArrayAccessNode.ChildAt(1), IndexExprId) then
    Exit(False);
  if (IndexExprId <= 0) or (IndexExprId > FModel.HirExprCount) then
    Exit(False);
  IndexExpr := FModel.HirExprAt(IndexExprId - 1);
  IndexTypeId := IndexExpr.TypeId;
  if (IndexTypeId <= 0) or
    (not FModel.GetTypeScalarFact(IndexTypeId, Fact)) or
    (Fact.Kind <> sskInt) then
    Exit(False);

  SetLength(Children, 2);
  Children[0] := FieldExprId;
  Children[1] := IndexExprId;
  AExprId := FModel.AddHirExpr(
    shekArrayElem, ElementTypeId, 0,
    Children, 0, 0.0,
    '', '', 0, shvcAddress
  );
  if (AExprId <= 0) or (AExprId > FModel.HirExprCount) then
    Exit(False);
  ArrayExpr := FModel.HirExprAt(AExprId - 1);
  Result := (ArrayExpr.Kind = shekArrayElem) and
    (ArrayExpr.ValueClass = shvcAddress);
end;

function TSemanticAnalyzer.ResolveArrayAccessElementTypeId(
  const AArrayAccessNode: TGreenNode; out AElementTypeId: LongInt): Boolean;
var
  ArrayName, BaseName, OwnerClassName, ElementTypeName, FieldName: string;
begin
  AElementTypeId := 0;
  if (AArrayAccessNode = nil) or
    (AArrayAccessNode.NodeKind <> gnkArrayAccess) or
    (AArrayAccessNode.ChildCount < 2) then
    Exit(False);

  if (AArrayAccessNode.ChildAt(0) <> nil) and
    (AArrayAccessNode.ChildAt(0).NodeKind = gnkIdentifier) then
  begin
    ArrayName := AArrayAccessNode.ChildAt(0).Text;
    if (ArrayName <> '') and IsRuntimeArrVar(ArrayName) and
      FModel.LookupStringConstValue(ArrayName + '$arr_elem_type',
        ElementTypeName) then
    begin
      AElementTypeId := FModel.FindTypeByName(ElementTypeName);
      Exit(AElementTypeId > 0);
    end;
  end;

  if TryClassFieldArrayAccess(AArrayAccessNode, BaseName, OwnerClassName,
    FieldName) and
    FModel.LookupStringConstValue(
      OwnerClassName + '.' + FieldName + '$arr_elem_type',
      ElementTypeName) then
  begin
    AElementTypeId := FModel.FindTypeByName(ElementTypeName);
    Exit(AElementTypeId > 0);
  end;

  Result := False;
end;

function TSemanticAnalyzer.TryBuildLegacyParamKindsFromSignature(
  const AArgSignature: string; const AParamCount: LongInt;
  out AParamKinds: string): Boolean;
var
  I: LongInt;
begin
  AParamKinds := '';
  if Length(AArgSignature) < AParamCount then
    Exit(False);
  for I := 1 to AParamCount do
    case AArgSignature[I] of
      'b', 'i':
        AParamKinds := AParamKinds + 'i';
      'p':
        AParamKinds := AParamKinds + 'p';
    else
      Exit(False);
    end;
  Result := True;
end;

function TSemanticAnalyzer.TryBuildLegacyParamKindsForDecl(
  const ADeclNode: TGreenNode; const AParamCount: LongInt;
  out AParamKinds: string): Boolean;
var
  Child, ParamNode, TypeNode: TGreenNode;
  I, J, ParamIndex: LongInt;
  TypeName: string;
  IsVarByRef: Boolean;
begin
  AParamKinds := '';
  ParamIndex := 0;
  if ADeclNode = nil then
    Exit(False);

  for I := 0 to ADeclNode.ChildCount - 1 do
  begin
    Child := ADeclNode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkParameterList) then
      Continue;
    for J := 0 to Child.ChildCount - 1 do
    begin
      ParamNode := Child.ChildAt(J);
      if (ParamNode = nil) or (ParamNode.NodeKind <> gnkParameterDecl) then
        Continue;
      Inc(ParamIndex);
      IsVarByRef := ParamNameIsByRef(ParamNode.Text);
      if ParamNode.ChildCount <= 0 then
      begin
        if IsVarByRef then
          Exit(False);
        AParamKinds := AParamKinds + 'i';
        Continue;
      end;
      TypeNode := ParamNode.ChildAt(0);
      if TypeNode = nil then
      begin
        if IsVarByRef then
          Exit(False);
        AParamKinds := AParamKinds + 'i';
        Continue;
      end;
      TypeName := TypeNode.Text;
      if SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString') then
        Exit(False);
      if TypeNode.NodeKind = gnkArrayType then
        Exit(False);
      if IsVarByRef then
      begin
        if (Length(TypeName) > 1) and (TypeName[1] = '^') then
          AParamKinds := AParamKinds + 'r'
        else if TypeMetaSize(TypeName) > 0 then
        begin
          if TypeMetaIsRecord(TypeName) then
            Exit(False);
          AParamKinds := AParamKinds + 'r';
        end
        else
          AParamKinds := AParamKinds + 'r';
      end
      else if (Length(TypeName) > 1) and (TypeName[1] = '^') then
        AParamKinds := AParamKinds + 'p'
      else if TypeMetaSize(TypeName) > 0 then
      begin
        if TypeMetaIsRecord(TypeName) then
          Exit(False);
        AParamKinds := AParamKinds + 'p';
      end
      else
        AParamKinds := AParamKinds + 'i';
    end;
    Break;
  end;

  Result := ParamIndex = AParamCount;
end;

function TSemanticAnalyzer.FindTypeDeclNodeInRoot(const ARootNode: TGreenNode;
  const ATypeName: string; out ATypeDeclNode,
  ATypeBodyNode: TGreenNode): Boolean;
var
  I, J, K: LongInt;
  SectionNode, TypeDeclNode, TypeBodyNode: TGreenNode;
  DeclName: string;
begin
  ATypeDeclNode := nil;
  ATypeBodyNode := nil;
  if (ARootNode = nil) or (ATypeName = '') then
    Exit(False);

  for I := 0 to ARootNode.ChildCount - 1 do
  begin
    SectionNode := ARootNode.ChildAt(I);
    if (SectionNode = nil) or (SectionNode.NodeKind <> gnkTypeSection) then
      Continue;
    for J := 0 to SectionNode.ChildCount - 1 do
    begin
      TypeDeclNode := SectionNode.ChildAt(J);
      if (TypeDeclNode = nil) or (TypeDeclNode.NodeKind <> gnkTypeDecl) then
        Continue;
      { Extract actual type name from directive-prefixed text }
      DeclName := TypeDeclNode.Text;
      if Copy(DeclName, 1, 14) = 'compiler_root:' then
        DeclName := Copy(DeclName, 15, Length(DeclName))
      else if Copy(DeclName, 1, 18) = 'compiler_type_kind:' then
        DeclName := Copy(DeclName, 19, Length(DeclName));
      if not SameText(DeclName, ATypeName) then
        Continue;
      ATypeDeclNode := TypeDeclNode;
      for K := 0 to TypeDeclNode.ChildCount - 1 do
      begin
        TypeBodyNode := TypeDeclNode.ChildAt(K);
        if (TypeBodyNode <> nil) and (TypeBodyNode.NodeKind = gnkClassType) then
        begin
          ATypeBodyNode := TypeBodyNode;
          Exit(True);
        end;
      end;
      Exit(False);
    end;
  end;
  Result := False;
end;

function TSemanticAnalyzer.FindTypeDeclNode(const ATypeName,
  AOwnerUnitId: string; out ATypeDeclNode, ATypeBodyNode: TGreenNode): Boolean;
var
  Index: LongInt;
  RootOwnerUnitId: string;
begin
  ATypeDeclNode := nil;
  ATypeBodyNode := nil;
  RootOwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);

  if (FRootAst <> nil) and
    ((AOwnerUnitId = '') or SameText(AOwnerUnitId, RootOwnerUnitId)) and
    FindTypeDeclNodeInRoot(FRootAst.RootNode, ATypeName, ATypeDeclNode,
      ATypeBodyNode) then
    Exit(True);

  for Index := 0 to LongInt(FImportedUnitTrees.Count) - 1 do
  begin
    if (AOwnerUnitId <> '') and
      (not SameText(FImportedUnitOwners[Index], AOwnerUnitId)) then
      Continue;
    if FindTypeDeclNodeInRoot(FImportedUnitTrees[Index].RootNode, ATypeName,
      ATypeDeclNode, ATypeBodyNode) then
      Exit(True);
  end;

  if AOwnerUnitId <> '' then
    for Index := 0 to LongInt(FImportedUnitTrees.Count) - 1 do
      if FindTypeDeclNodeInRoot(FImportedUnitTrees[Index].RootNode, ATypeName,
        ATypeDeclNode, ATypeBodyNode) then
        Exit(True);
  Result := False;
end;

function TSemanticAnalyzer.FindTypeMethodDecl(const ATypeName, AOwnerUnitId,
  AMethodName: string; const AArgCount: LongInt; const AArgSignature: string;
  const AHasArgSignature: Boolean; out ADeclNode: TGreenNode): Boolean;
var
  CandidateNode, ChildNode, NameNode, SignatureNode, TypeBodyNode,
    TypeDeclNode: TGreenNode;
  CurrentTypeId, Depth, I, MatchCount, SignatureMatchCount: LongInt;
  TypeSymbol: TSemanticSymbol;
begin
  ADeclNode := nil;
  CurrentTypeId := ResolveTypeIdForOwner(ATypeName, AOwnerUnitId);
  Depth := 0;
  while (CurrentTypeId > 0) and (Depth < 32) do
  begin
    if not TypeSymbolForTypeId(CurrentTypeId, TypeSymbol) then
      Exit(False);
    if FindTypeDeclNode(TypeSymbol.Name, TypeSymbol.OwnerUnitId, TypeDeclNode,
      TypeBodyNode) then
    begin
      CandidateNode := nil;
      SignatureNode := nil;
      MatchCount := 0;
      SignatureMatchCount := 0;
      for I := 0 to TypeBodyNode.ChildCount - 1 do
      begin
        ChildNode := TypeBodyNode.ChildAt(I);
        if (ChildNode = nil) or (ChildNode.NodeKind <> gnkClassMethod) or
          (ChildNode.ChildCount = 0) then
          Continue;
        NameNode := ChildNode.ChildAt(0);
        if (NameNode = nil) or (NameNode.NodeKind <> gnkIdentifier) or
          (not SameText(NameNode.Text, AMethodName)) or
          (not DeclAcceptsArgCount(ChildNode, AArgCount)) then
          Continue;
        Inc(MatchCount);
        CandidateNode := ChildNode;
        if (not AHasArgSignature) or
          DeclParamSignatureMatchesArgs(ChildNode, AArgSignature, AArgCount) then
        begin
          Inc(SignatureMatchCount);
          SignatureNode := ChildNode;
        end;
      end;
      if SignatureMatchCount = 1 then
      begin
        ADeclNode := SignatureNode;
        Exit(True);
      end;
      if (SignatureMatchCount = 0) and (MatchCount = 1) then
      begin
        ADeclNode := CandidateNode;
        Exit(True);
      end;
    end;
    if (CurrentTypeId <= 0) or (CurrentTypeId > FModel.TypeCount) then
      Break;
    CurrentTypeId := FModel.TypeAt(CurrentTypeId - 1).ParentTypeId;
    Inc(Depth);
  end;
  Result := False;
end;

function TSemanticAnalyzer.TryGetDispatchedMemberCallContract(
  const ACallNode: TGreenNode; out AExprKind: TSemanticHirExprKind;
  out AReceiverVarName, ACalleeName, AParamKinds: string;
  out ASlotIndex, AReturnTypeId: LongInt): Boolean;
var
  ArgTypeIds: TTypeIdArray;
  Candidates: TOverloadCandidateArray;
  DeclNode, MemberNode, ReceiverNode: TGreenNode;
  HasArgSignature, HasTypeMismatchEvidence: Boolean;
  MemberName, ReceiverName, ResolutionFailureKind, ArgSignature,
    ReceiverTypeName, DeclaringTypeName: string;
  ArgCount, DotPos, MemberOffset, ReceiverTypeId, TargetSymbolId: LongInt;
  TargetSymbol: TSemanticSymbol;
begin
  AExprKind := shekInvalid;
  AReceiverVarName := '';
  ACalleeName := '';
  AParamKinds := '';
  ASlotIndex := -1;
  AReturnTypeId := 0;
  ReceiverName := '';
  MemberName := '';
  MemberOffset := 0;
  ArgCount := 0;

  if ExtractDirectMemberCall(ACallNode, ReceiverName, MemberName,
    MemberOffset, ArgCount) then
  begin
    if SameText(ReceiverName, 'Self') then
      AReceiverVarName := 'self'
    else
      AReceiverVarName := ReceiverName;
    ReceiverTypeId := TypeIdForMemberReceiver(ReceiverName, FCurrentMethodClass,
      NormalizeUnitIdentity(FUnitGraph.RootName));
  end
  else if (ACallNode <> nil) and (ACallNode.NodeKind = gnkDotAccess) and
    (ACallNode.ChildCount >= 2) then
  begin
    ReceiverNode := ACallNode.ChildAt(0);
    MemberNode := ACallNode.ChildAt(1);
    if (ReceiverNode = nil) or (MemberNode = nil) or
      (ReceiverNode.NodeKind <> gnkIdentifier) or
      (MemberNode.NodeKind <> gnkIdentifier) then
      Exit(False);
    ReceiverName := ReceiverNode.Text;
    MemberName := MemberNode.Text;
    MemberOffset := MemberNode.ByteOffset;
    if SameText(ReceiverName, 'Self') then
      AReceiverVarName := 'self'
    else
      AReceiverVarName := ReceiverName;
    ReceiverTypeId := TypeIdForMemberReceiver(ReceiverName, FCurrentMethodClass,
      NormalizeUnitIdentity(FUnitGraph.RootName));
  end
  else if (FCurrentMethodClass <> '') and
    IsImplicitSelfCallNode(ACallNode) and
    (not IsQualifiedCallNode(ACallNode)) then
  begin
    MemberName := BareCallCalleeName(ACallNode);
    if MemberName = '' then
      Exit(False);
    AReceiverVarName := 'self';
    ReceiverTypeId := TypeIdForMemberReceiver('Self', FCurrentMethodClass,
      NormalizeUnitIdentity(FUnitGraph.RootName));
    ArgCount := CallArgumentCount(ACallNode);
  end
  else
    Exit(False);

  if (AReceiverVarName = '') or (ReceiverTypeId <= 0) or
    (ReceiverTypeId > FModel.TypeCount) or (not IsRuntimeVar(AReceiverVarName)) then
    Exit(False);

  HasArgSignature := (ACallNode <> nil) and
    (ACallNode.NodeKind in [gnkFunctionCall, gnkProcedureCallStatement, gnkDotAccess]) and
    CallArgumentSignature(ACallNode, ArgSignature);
  if not CallArgumentTypeIds(ACallNode, ArgTypeIds) then
    SetLength(ArgTypeIds, 0);
  HasTypeMismatchEvidence := HasArgSignature and
    CallArgumentSignatureIsStable(ACallNode,
      NormalizeUnitIdentity(FUnitGraph.RootName));
  ResolutionFailureKind := '';
  SetLength(Candidates, 0);
  TargetSymbolId := MethodSymbolIdForClassTypeMember(
    ReceiverTypeId,
    MemberName,
    ArgCount,
    ArgTypeIds,
    ArgSignature,
    HasArgSignature,
    HasTypeMismatchEvidence,
    ResolutionFailureKind,
    Candidates
  );
  if TargetSymbolId <= 0 then
    Exit(False);

  ReceiverTypeName := FModel.TypeAt(ReceiverTypeId - 1).Name;
  if ReceiverTypeName = '' then
    Exit(False);
  ASlotIndex := TypeMetaVmtSlot(ReceiverTypeName, MemberName);
  if ASlotIndex < 0 then
    Exit(False);
  if TypeMetaIsInterface(ReceiverTypeName) then
    AExprKind := shekInterfaceCall
  else
    AExprKind := shekVirtualCall;

  TargetSymbol := FModel.SymbolAt(TargetSymbolId - 1);
  ACalleeName := TargetSymbol.Name;
  if ACalleeName = '' then
    Exit(False);

  DotPos := Pos('.', ACalleeName);
  if DotPos > 0 then
    DeclaringTypeName := Copy(ACalleeName, 1, DotPos - 1)
  else
    DeclaringTypeName := ReceiverTypeName;
  DeclNode := nil;
  FindTypeMethodDecl(
    DeclaringTypeName,
    TargetSymbol.OwnerUnitId,
    MemberName,
    ArgCount,
    ArgSignature,
    HasArgSignature,
    DeclNode
  );

  if ((DeclNode = nil) or
    (not TryBuildLegacyParamKindsForDecl(DeclNode, ArgCount, AParamKinds))) and
    (not TryBuildLegacyParamKindsFromSignature(ArgSignature, ArgCount,
      AParamKinds)) then
    Exit(False);
  AParamKinds := 'p' + AParamKinds;

  if DeclNode <> nil then
    AReturnTypeId := DeclReturnTypeId(DeclNode, TargetSymbol.OwnerUnitId);
  if AReturnTypeId <= 0 then
    AReturnTypeId := InferExpressionType(ACallNode);
  if AReturnTypeId <= 0 then
    AReturnTypeId := FModel.FindTypeByName('Integer');
  if AReturnTypeId <= 0 then
    Exit(False);
  if TypeMetaIsClass(FModel.TypeAt(AReturnTypeId - 1).Name) then
    AReturnTypeId := FModel.FindTypeByName('Pointer');

  Result := AReturnTypeId > 0;
end;

function TSemanticAnalyzer.TryGetDirectCallContract(
  const ACallNode: TGreenNode; out ACalleeName, AParamKinds: string;
  out AReturnTypeId: LongInt): Boolean;
var
  BodyNode, DeclNode, EffectiveCallNode: TGreenNode;
  ParamCount: LongInt;
begin
  ACalleeName := '';
  AParamKinds := '';
  AReturnTypeId := 0;
  if ACallNode = nil then
    Exit(False);

  EffectiveCallNode := ACallNode;
  if (ACallNode.NodeKind = gnkProcedureCallStatement) and
    (ACallNode.ChildCount >= 1) and (ACallNode.ChildAt(0) <> nil) and
    (ACallNode.ChildAt(0).NodeKind = gnkFunctionCall) then
    EffectiveCallNode := ACallNode.ChildAt(0);

  if (EffectiveCallNode = nil) or
    (EffectiveCallNode.NodeKind <> gnkFunctionCall) or
    (EffectiveCallNode.ChildCount < 1) or (EffectiveCallNode.ChildAt(0) = nil) or
    (EffectiveCallNode.ChildAt(0).NodeKind <> gnkIdentifier) then
    Exit(False);

  ACalleeName := EffectiveCallNode.ChildAt(0).Text;
  if (ACalleeName = '') or HasOverload(ACalleeName) or
    (Pos('specialize ', ACalleeName) = 1) or
    (Pos('.', ACalleeName) <> 0) or IsBuiltinProcedure(ACalleeName) or
    (not LookupProcedureBody(ACalleeName, BodyNode, DeclNode)) or
    (DeclNode = nil) then
    Exit(False);

  ParamCount := EffectiveCallNode.ChildCount - 1;
  if not TryBuildLegacyParamKindsForDecl(DeclNode, ParamCount, AParamKinds) then
    Exit(False);

  AReturnTypeId := InferExpressionType(EffectiveCallNode);
  if AReturnTypeId <= 0 then
    AReturnTypeId := FModel.FindTypeByName('Integer');
  if AReturnTypeId <= 0 then
    Exit(False);
  if TypeMetaIsClass(FModel.TypeAt(AReturnTypeId - 1).Name) then
    AReturnTypeId := FModel.FindTypeByName('Pointer');

  Result := AReturnTypeId > 0;
end;

function TSemanticAnalyzer.TryGetOrdinaryMemberCallContract(
  const ACallNode: TGreenNode; out AReceiverVarName, ACalleeName,
  AParamKinds: string; out AReturnTypeId: LongInt): Boolean;
var
  ArgTypeIds: TTypeIdArray;
  BodyNode, DeclNode: TGreenNode;
  Candidates: TOverloadCandidateArray;
  MemberNode, ReceiverNode: TGreenNode;
  HasArgSignature, HasTypeMismatchEvidence: Boolean;
  MemberName, ReceiverName, ResolutionFailureKind, ArgSignature, OwnerUnitId: string;
  ArgCount, MemberOffset, ReceiverTypeId, TargetSymbolId: LongInt;
  ReceiverTypeName: string;
begin
  AReceiverVarName := '';
  ACalleeName := '';
  AParamKinds := '';
  AReturnTypeId := 0;
  ReceiverName := '';
  MemberName := '';
  MemberOffset := 0;
  ArgCount := 0;

  if ExtractDirectMemberCall(ACallNode, ReceiverName, MemberName,
    MemberOffset, ArgCount) then
  begin
    if SameText(ReceiverName, 'Self') then
      AReceiverVarName := 'self'
    else
      AReceiverVarName := ReceiverName;
    ReceiverTypeId := TypeIdForMemberReceiver(ReceiverName, FCurrentMethodClass,
      NormalizeUnitIdentity(FUnitGraph.RootName));
  end
  else if (ACallNode <> nil) and (ACallNode.NodeKind = gnkDotAccess) and
    (ACallNode.ChildCount >= 2) then
  begin
    ReceiverNode := ACallNode.ChildAt(0);
    MemberNode := ACallNode.ChildAt(1);
    if (ReceiverNode = nil) or (MemberNode = nil) or
      (ReceiverNode.NodeKind <> gnkIdentifier) or
      (MemberNode.NodeKind <> gnkIdentifier) then
      Exit(False);
    ReceiverName := ReceiverNode.Text;
    MemberName := MemberNode.Text;
    MemberOffset := MemberNode.ByteOffset;
    ArgCount := 0;
    if SameText(ReceiverName, 'Self') then
      AReceiverVarName := 'self'
    else
      AReceiverVarName := ReceiverName;
    ReceiverTypeId := TypeIdForMemberReceiver(ReceiverName, FCurrentMethodClass,
      NormalizeUnitIdentity(FUnitGraph.RootName));
  end
  else if (FCurrentMethodClass <> '') and
    IsImplicitSelfCallNode(ACallNode) and
    (not IsQualifiedCallNode(ACallNode)) then
  begin
    MemberName := BareCallCalleeName(ACallNode);
    if MemberName = '' then
      Exit(False);
    AReceiverVarName := 'self';
    ReceiverTypeId := TypeIdForMemberReceiver('Self', FCurrentMethodClass,
      NormalizeUnitIdentity(FUnitGraph.RootName));
    ArgCount := CallArgumentCount(ACallNode);
  end
  else
    Exit(False);

  if (AReceiverVarName = '') or (ReceiverTypeId <= 0) or
    (ReceiverTypeId > FModel.TypeCount) or (not IsRuntimeVar(AReceiverVarName)) then
    Exit(False);

  HasArgSignature := (ACallNode <> nil) and
    (ACallNode.NodeKind in [gnkFunctionCall, gnkProcedureCallStatement]) and
    CallArgumentSignature(ACallNode, ArgSignature);
  if not CallArgumentTypeIds(ACallNode, ArgTypeIds) then
    SetLength(ArgTypeIds, 0);
  HasTypeMismatchEvidence := HasArgSignature and
    CallArgumentSignatureIsStable(ACallNode,
      NormalizeUnitIdentity(FUnitGraph.RootName));
  ResolutionFailureKind := '';
  SetLength(Candidates, 0);
  TargetSymbolId := MethodSymbolIdForClassTypeMember(
    ReceiverTypeId,
    MemberName,
    ArgCount,
    ArgTypeIds,
    ArgSignature,
    HasArgSignature,
    HasTypeMismatchEvidence,
    ResolutionFailureKind,
    Candidates
  );
  if TargetSymbolId <= 0 then
    Exit(False);

  ReceiverTypeName := FModel.TypeAt(ReceiverTypeId - 1).Name;
  if (ReceiverTypeName = '') or TypeMetaIsInterface(ReceiverTypeName) or
    (TypeMetaVmtSlot(ReceiverTypeName, MemberName) >= 0) then
    Exit(False);

  ACalleeName := FModel.SymbolAt(TargetSymbolId - 1).Name;
  if (ACalleeName = '') or
    not LookupCallBindingDeclaration(
      ACalleeName,
      ArgCount,
      ArgTypeIds,
      ArgSignature,
      HasArgSignature,
      HasTypeMismatchEvidence,
      ResolutionFailureKind,
      BodyNode,
      DeclNode,
      OwnerUnitId
    ) or (DeclNode = nil) then
    Exit(False);

  if not TryBuildLegacyParamKindsForDecl(DeclNode, ArgCount, AParamKinds) then
    Exit(False);
  AParamKinds := 'p' + AParamKinds;

  AReturnTypeId := DeclReturnTypeId(DeclNode, OwnerUnitId);
  if AReturnTypeId <= 0 then
    AReturnTypeId := InferExpressionType(ACallNode);
  if AReturnTypeId <= 0 then
    AReturnTypeId := FModel.FindTypeByName('Integer');
  if AReturnTypeId <= 0 then
    Exit(False);
  if TypeMetaIsClass(FModel.TypeAt(AReturnTypeId - 1).Name) then
    AReturnTypeId := FModel.FindTypeByName('Pointer');

  Result := AReturnTypeId > 0;
end;

function TSemanticAnalyzer.BuildTargetAddressExpr(const ATargetNode: TGreenNode;
  out AExprId: LongInt): Boolean;
var
  Children: array of LongInt;
  BaseName, ClassTypeName, FieldName, RecordTypeName: string;
  BaseExprId, BaseTypeId, ElementTypeId, ScalarSymbolId, ScalarTypeId: LongInt;
  Fact: TSemanticScalarTypeFact;
  FieldMeta: TFieldMeta;
begin
  AExprId := 0;
  if ATargetNode = nil then
    Exit(False);

  case ATargetNode.NodeKind of
    gnkIdentifier:
      begin
        BaseName := ATargetNode.Text;
        if BaseName = '' then
          Exit(False);
        if SameText(BaseName, 'Self') and (FCurrentMethodClass <> '') then
          Exit(BuildClassBaseAddressExpr('self', FCurrentMethodClass, AExprId));
        if (FCurrentMethodClass <> '') and
          (TypeMetaFieldIndex(FCurrentMethodClass, BaseName) >= 0) then
          Exit(BuildClassFieldTargetExpr('self', FCurrentMethodClass,
            BaseName, AExprId));
        if SameText(BaseName, 'Result') and (FCurrentRetVarName <> '') then
        begin
          RecordTypeName := LookupRecordVar(FCurrentRetVarName);
          if RecordTypeName <> '' then
            Exit(BuildRecordBaseAddressExpr(FCurrentRetVarName,
              RecordTypeName, AExprId));
        end;
        RecordTypeName := LookupRecordVar(BaseName);
        if RecordTypeName <> '' then
          Exit(BuildRecordBaseAddressExpr(BaseName, RecordTypeName, AExprId));
        ClassTypeName := LookupClassVar(BaseName);
        if ClassTypeName <> '' then
          Exit(BuildClassBaseAddressExpr(BaseName, ClassTypeName, AExprId));
        if IsRuntimeVar(BaseName) and
          (not IsRuntimeStrVar(BaseName)) and
          (not IsRuntimeArrVar(BaseName)) then
        begin
          ScalarSymbolId := FModel.FindSymbolByName(BaseName);
          if ScalarSymbolId <= 0 then
            Exit(False);
          ScalarTypeId := FModel.SymbolTypeId(ScalarSymbolId);
          if (ScalarTypeId <= 0) or
            (not FModel.GetTypeScalarFact(ScalarTypeId, Fact)) or
            not (Fact.Kind in [sskBool, sskInt, sskPointer]) then
            Exit(False);
          SetLength(Children, 0);
          AExprId := FModel.AddHirExpr(
            shekSymbolAddress, ScalarTypeId, ScalarSymbolId, Children,
    0,
    0.0, '', '', 0, shvcAddress
          );
          Exit(AExprId > 0);
        end;
        Result := False;
      end;
    gnkArrayAccess:
      Result := BuildRuntimeArrayElementAddressHirExpr(ATargetNode, AExprId) or
        BuildClassFieldArrayElementTargetExpr(ATargetNode, AExprId);
    gnkDotAccess:
      begin
        if (ATargetNode.ChildCount < 2) or (ATargetNode.ChildAt(0) = nil) or
          (ATargetNode.ChildAt(1) = nil) or
          (ATargetNode.ChildAt(1).NodeKind <> gnkIdentifier) then
          Exit(False);

        FieldName := ATargetNode.ChildAt(1).Text;
        if not BuildTargetAddressExpr(ATargetNode.ChildAt(0), BaseExprId) then
          Exit(False);
        if (BaseExprId <= 0) or (BaseExprId > FModel.HirExprCount) then
          Exit(False);

        BaseTypeId := FModel.HirExprAt(BaseExprId - 1).TypeId;
        if (BaseTypeId <= 0) and
          (ATargetNode.ChildAt(0).NodeKind = gnkArrayAccess) then
        begin
          if not ResolveArrayAccessElementTypeId(ATargetNode.ChildAt(0),
            ElementTypeId) then
            Exit(False);
          BaseTypeId := ElementTypeId;
        end;
        if BaseTypeId <= 0 then
          Exit(False);
        if not FModel.GetFieldMetaByName(BaseTypeId, FieldName, FieldMeta) then
          Exit(False);

        SetLength(Children, 1);
        Children[0] := BaseExprId;
        AExprId := FModel.AddHirExpr(
          shekField, FieldMeta.TypeId, 0,
    Children, FieldMeta.Index, 0.0,
          FieldMeta.Name, '', 0, shvcAddress
        );
        Result := AExprId > 0;
      end;
  else
    Result := False;
  end;
end;

function TSemanticAnalyzer.BuildByRefArgumentAddressExpr(
  const ATargetNode: TGreenNode; out AExprId: LongInt): Boolean;
var
  Children: array of LongInt;
  BaseName: string;
  SelfTypeId, SymbolId, TypeId: LongInt;
begin
  AExprId := 0;
  if ATargetNode = nil then
    Exit(False);

  if ATargetNode.NodeKind = gnkIdentifier then
  begin
    BaseName := ATargetNode.Text;
    if SameText(BaseName, 'Result') and (FCurrentRetVarName <> '') then
      BaseName := FCurrentRetVarName;

    if SameText(BaseName, 'Self') then
    begin
      SymbolId := EnsureSelfSymbolId(SelfTypeId);
      TypeId := SelfTypeId;
    end
    else if (BaseName <> '') and IsRuntimeVar(BaseName) and
      (not IsRuntimeStrVar(BaseName)) and (not IsRuntimeArrVar(BaseName)) then
    begin
      SymbolId := FModel.FindSymbolByName(BaseName);
      TypeId := FModel.SymbolTypeId(SymbolId);
    end
    else
    begin
      SymbolId := 0;
      TypeId := 0;
    end;

    if (SymbolId > 0) and (TypeId > 0) then
    begin
      SetLength(Children, 0);
      AExprId := FModel.AddHirExpr(
        shekSymbolAddress, TypeId, SymbolId, Children,
    0,
    0.0, '', '', 0, shvcAddress
      );
      Exit(AExprId > 0);
    end;
  end;

  Result := BuildTargetAddressExpr(ATargetNode, AExprId);
end;

procedure TSemanticAnalyzer.AttachStatementCallExpr(const AHirNodeId: LongInt;
  const ACallNode: TGreenNode);
var
  ExprId: LongInt;
begin
  if (AHirNodeId <= 0) or (ACallNode = nil) then
    Exit;
  if BuildRuntimeScalarHirExpr(ACallNode, ExprId) then
    FModel.SetTypedHirNodeExprId(AHirNodeId, ExprId);
end;


{ === SemaBridge functions — adapt TSemanticAnalyzer methods to callback pointers === }

function SemaBridge_BuildTargetAddressExpr(const Ctx: Pointer; const ATargetNode: TGreenNode;
  out AExprId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).BuildTargetAddressExpr(ATargetNode, AExprId);
end;

function SemaBridge_BuildClassBaseAddressExpr(const Ctx: Pointer; const ABaseName,
  AClassName: string; out AExprId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).BuildClassBaseAddressExpr(ABaseName, AClassName, AExprId);
end;

function SemaBridge_BuildByRefArgumentAddressExpr(const Ctx: Pointer;
  const AArgNode: TGreenNode; out AExprId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).BuildByRefArgumentAddressExpr(AArgNode, AExprId);
end;

function SemaBridge_BuildRuntimeArrayElementAddressHirExpr(const Ctx: Pointer;
  const ANode: TGreenNode; out AExprId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).BuildRuntimeArrayElementAddressHirExpr(ANode, AExprId);
end;

function SemaBridge_EvaluateIntegerConstant(const Ctx: Pointer; const ANode: TGreenNode;
  out AValue: Int64): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).EvaluateIntegerConstant(ANode, AValue);
end;

function SemaBridge_InferExpressionType(const Ctx: Pointer;
  const ANode: TGreenNode): LongInt;
begin
  Result := TSemanticAnalyzer(Ctx).InferExpressionType(ANode);
end;

function SemaBridge_TypeIdForVariable(const Ctx: Pointer;
  const AName: string): LongInt;
begin
  Result := TSemanticAnalyzer(Ctx).TypeIdForVariable(AName);
end;

function SemaBridge_TryGetDirectCallContract(const Ctx: Pointer; const ACallNode: TGreenNode;
  out ACalleeName, AParamKinds: string; out AResultTypeId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).TryGetDirectCallContract(ACallNode, ACalleeName, AParamKinds, AResultTypeId);
end;

function SemaBridge_TryGetDispatchedMemberCallContract(const Ctx: Pointer;
  const ACallNode: TGreenNode; out AExprKind: TSemanticHirExprKind;
  out AReceiverVarName, ACalleeName, AParamKinds: string;
  out ASlotIndex, AReturnTypeId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).TryGetDispatchedMemberCallContract(
    ACallNode, AExprKind, AReceiverVarName, ACalleeName, AParamKinds, ASlotIndex, AReturnTypeId);
end;

function SemaBridge_TryGetOrdinaryMemberCallContract(const Ctx: Pointer;
  const ACallNode: TGreenNode; out AReceiverVarName, ACalleeName,
  AParamKinds: string; out AResultTypeId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).TryGetOrdinaryMemberCallContract(
    ACallNode, AReceiverVarName, ACalleeName, AParamKinds, AResultTypeId);
end;

function SemaBridge_TryGetTypeCastTargetTypeId(const Ctx: Pointer;
  const ACallNode: TGreenNode; out ATypeId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).TryGetTypeCastTargetTypeId(ACallNode, ATypeId);
end;

function SemaBridge_TryGetIntrinsicExprName(const Ctx: Pointer;
  const ACallNode: TGreenNode; out AIntrinsicName: string): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).TryGetIntrinsicExprName(ACallNode, AIntrinsicName);
end;

function SemaBridge_ResolveTypeIdForOwner(const Ctx: Pointer; const ATypeName,
  AOwnerUnitId: string): LongInt;
begin
  Result := TSemanticAnalyzer(Ctx).ResolveTypeIdForOwner(ATypeName, AOwnerUnitId);
end;

function SemaBridge_EncodeRuntimeIntExprFold(const Ctx: Pointer;
  const ANode: TGreenNode; out ABlob: string): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).EncodeRuntimeIntExprFold(ANode, ABlob);
end;

function SemaBridge_CanEmitStrCompareOperand(const Ctx: Pointer;
  const ANode: TGreenNode; AAllowOwned: Boolean): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).CanEmitStrCompareOperand(ANode, AAllowOwned);
end;

function SemaBridge_EmitStrCompareOperand(const Ctx: Pointer;
  const ANode: TGreenNode; AAllowOwned: Boolean;
  out ABlob: string): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).EmitStrCompareOperand(ANode, AAllowOwned, ABlob);
end;

function SemaBridge_TypeMetaIsInterface(const Ctx: Pointer;
  const ATypeName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaIsInterface(
    TSemanticAnalyzer(Ctx).FModel, ATypeName);
end;

function SemaBridge_TypeMetaInterfaces(const Ctx: Pointer;
  const ATypeName: string): string;
begin
  Result := np_sema_type_check.TypeMetaInterfaces(
    TSemanticAnalyzer(Ctx).FModel, ATypeName);
end;

function SemaBridge_TypeMetaFieldIndex(const Ctx: Pointer;
  const ATypeName, AFieldName: string): Int64;
begin
  Result := np_sema_type_check.TypeMetaFieldIndex(
    TSemanticAnalyzer(Ctx).FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.BuildRuntimeScalarHirExpr(const ANode: TGreenNode;
  out AExprId: LongInt): Boolean;
var
  Ctx: TSemaHirLoweringContext;
begin
  { Fill context }
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Ctx.Diagnostics := FDiagnostics;
  Ctx.RootFileId := FRootFileId;
  Ctx.BlockLabelCounter := FBlockLabelCounter;
  Ctx.CurrentMethodClass := FCurrentMethodClass;
  Ctx.CurrentRetVarName := FCurrentRetVarName;
  Ctx.RuntimeVars := FRuntimeVars;
  Ctx.CurrentBlockTerminated := FCurrentBlockTerminated;
  { Fill callbacks }
  Ctx.CallbackCtx := Pointer(Self);
  Ctx.BuildTargetAddressExpr := @SemaBridge_BuildTargetAddressExpr;
  Ctx.BuildClassBaseAddressExpr := @SemaBridge_BuildClassBaseAddressExpr;
  Ctx.BuildByRefArgumentAddressExpr := @SemaBridge_BuildByRefArgumentAddressExpr;
  Ctx.BuildRuntimeArrayElementAddressHirExpr := @SemaBridge_BuildRuntimeArrayElementAddressHirExpr;
  Ctx.EvaluateIntegerConstant := @SemaBridge_EvaluateIntegerConstant;
  Ctx.InferExpressionType := @SemaBridge_InferExpressionType;
  Ctx.TypeIdForVariable := @SemaBridge_TypeIdForVariable;
  Ctx.TryGetDirectCallContract := @SemaBridge_TryGetDirectCallContract;
  Ctx.TryGetDispatchedMemberCallContract := @SemaBridge_TryGetDispatchedMemberCallContract;
  Ctx.TryGetOrdinaryMemberCallContract := @SemaBridge_TryGetOrdinaryMemberCallContract;
  Ctx.TryGetTypeCastTargetTypeId := @SemaBridge_TryGetTypeCastTargetTypeId;
  Ctx.TryGetIntrinsicExprName := @SemaBridge_TryGetIntrinsicExprName;
  Ctx.ResolveTypeIdForOwner := @SemaBridge_ResolveTypeIdForOwner;
  Ctx.EncodeRuntimeIntExprFold := @SemaBridge_EncodeRuntimeIntExprFold;
  Ctx.CanEmitStrCompareOperand := @SemaBridge_CanEmitStrCompareOperand;
  Ctx.EmitStrCompareOperand := @SemaBridge_EmitStrCompareOperand;
  Ctx.TypeMetaIsInterface := @SemaBridge_TypeMetaIsInterface;
  Ctx.TypeMetaInterfaces := @SemaBridge_TypeMetaInterfaces;
  Ctx.TypeMetaFieldIndex := @SemaBridge_TypeMetaFieldIndex;
  { Delegate }
  Result := np_hir_lowering.BuildRuntimeScalarHirExpr(Ctx, ANode, AExprId);
  { Sync mutable state back }
  FCurrentBlockTerminated := Ctx.CurrentBlockTerminated;
  FBlockLabelCounter := Ctx.BlockLabelCounter;
end;

procedure TSemanticAnalyzer.AttachRuntimeReturnExpr(const AHirNodeId: LongInt;
  const AReturnVarName: string);
var Ctx: TSemaHirLoweringContext;
begin
  Ctx.Model := FModel;
  np_hir_lowering.AttachRuntimeReturnExpr(Ctx, AHirNodeId, AReturnVarName);
end;

procedure TSemanticAnalyzer.AttachRuntimeConditionExpr(const AHirNodeId: LongInt;
  const ACondNode: TGreenNode);

  function IsRuntimeBoolExprNode(const ANode: TGreenNode): Boolean;
  var
    Op: string;
  begin
    if ANode = nil then
      Exit(False);
    if (ANode.NodeKind = gnkUnaryExpression) and
      SameText(ANode.Text, 'not') and (ANode.ChildCount >= 1) then
      Exit(IsRuntimeBoolExprNode(ANode.ChildAt(0)));
    if (ANode.NodeKind <> gnkBinaryExpression) or (ANode.ChildCount < 2) then
      Exit(False);
    Op := ANode.Text;
    if (Op = '=') or (Op = '<>') or (Op = '<') or (Op = '<=') or
      (Op = '>') or (Op = '>=') then
      Exit(True);
    if SameText(Op, 'and') or SameText(Op, 'or') then
      Exit(IsRuntimeBoolExprNode(ANode.ChildAt(0)) and
        IsRuntimeBoolExprNode(ANode.ChildAt(1)));
    Result := False;
  end;

var
  ExprId: LongInt;
begin
  if AHirNodeId <= 0 then
    Exit;
  if not IsRuntimeBoolExprNode(ACondNode) then
    Exit;
  if not BuildRuntimeScalarHirExpr(ACondNode, ExprId) then
    Exit;
  FModel.SetTypedHirNodeExprId(AHirNodeId, ExprId);
end;

function TSemanticAnalyzer.EncodeRuntimeBoolExprFold(
  const ANode: TGreenNode; out ABlob: string;
  const AAllowOwnedStringCompare: Boolean): Boolean;
var
  Ctx: TSemaHirLoweringContext;
begin
  Ctx.Model := FModel;
  Ctx.RuntimeVars := FRuntimeVars;
  Ctx.CallbackCtx := Pointer(Self);
  Ctx.EncodeRuntimeIntExprFold := @SemaBridge_EncodeRuntimeIntExprFold;
  Ctx.CanEmitStrCompareOperand := @SemaBridge_CanEmitStrCompareOperand;
  Ctx.EmitStrCompareOperand := @SemaBridge_EmitStrCompareOperand;
  Ctx.TypeMetaIsInterface := @SemaBridge_TypeMetaIsInterface;
  Ctx.TypeMetaInterfaces := @SemaBridge_TypeMetaInterfaces;
  Ctx.TypeMetaFieldIndex := @SemaBridge_TypeMetaFieldIndex;
  Result := np_hir_lowering.EncodeRuntimeBoolExprFold(Ctx, ANode, ABlob,
    AAllowOwnedStringCompare);
end;

{$I np_sema_walk_halt_calls.inc}
procedure TSemanticAnalyzer.LowerRuntimeIfStatement(
  const AIfNode: TGreenNode; const ACondBlob: string);
var
  NodeId: LongInt;
  ThenLabel, ElseLabel, EndLabel: string;
  HasElse: Boolean;
begin
  HasElse := AIfNode.ChildCount >= 3;
  ThenLabel := NewBlockLabel('then');
  if HasElse then
    ElseLabel := NewBlockLabel('else')
  else
    ElseLabel := '';
  EndLabel := NewBlockLabel('endif');
  if not HasElse then
    ElseLabel := EndLabel;
  NodeId := FModel.AddTypedHirNode(
    'cond-br-runtime', 'if', 0, 0,
    ACondBlob + 'labels ' + ThenLabel + #9 + ElseLabel + #10
  );
  if AIfNode.ChildCount >= 1 then
    AttachRuntimeConditionExpr(NodeId, AIfNode.ChildAt(0));
  EmitPendingStringTempReleases;
  FCurrentBlockTerminated := True;
  EmitBlockLabel(ThenLabel);
  WalkHaltCalls(AIfNode.ChildAt(1));
  EmitGotoLabel(EndLabel);
  if HasElse then
  begin
    EmitBlockLabel(ElseLabel);
    WalkHaltCalls(AIfNode.ChildAt(2));
    EmitGotoLabel(EndLabel);
  end;
  EmitBlockLabel(EndLabel);
end;

procedure TSemanticAnalyzer.LowerRuntimeWhileStatement(const ANode: TGreenNode);
var
  NodeId: LongInt;
  CondNode, BodyNode: TGreenNode;
  CondBlob, CondLabel, BodyLabel, ExitLabel: string;
  UseOwnedCompareCondition: Boolean;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  CondNode := ANode.ChildAt(0);
  BodyNode := ANode.ChildAt(1);
  UseOwnedCompareCondition := BoolConditionHasSupportedOwnedStringCompare(
    CondNode);
  if (not UseOwnedCompareCondition) and
    (not EncodeRuntimeBoolExprFold(CondNode, CondBlob)) then
    Exit;
  CondLabel := NewBlockLabel('while-cond');
  BodyLabel := NewBlockLabel('while-body');
  ExitLabel := NewBlockLabel('while-end');
  FBreakLabels.Push(ExitLabel);
  FContinueLabels.Push(CondLabel);
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(CondLabel);
  if UseOwnedCompareCondition and
    (not EncodeRuntimeBoolExprFold(CondNode, CondBlob, True)) then
    Exit;
  NodeId := FModel.AddTypedHirNode(
    'cond-br-runtime', 'while', 0, 0,
    CondBlob + 'labels ' + BodyLabel + #9 + ExitLabel + #10
  );
  AttachRuntimeConditionExpr(NodeId, CondNode);
  EmitPendingStringTempReleases;
  FCurrentBlockTerminated := True;
  EmitBlockLabel(BodyLabel);
  WalkHaltCalls(BodyNode);
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(ExitLabel);
  FBreakLabels.Pop;
  FContinueLabels.Pop;
end;

procedure TSemanticAnalyzer.LowerRuntimeRepeatStatement(const ANode: TGreenNode);
var
  NodeId: LongInt;
  CondNode, BodyNode: TGreenNode;
  CondBlob, BodyLabel, CondLabel, ExitLabel: string;
  UseOwnedCompareCondition: Boolean;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  BodyNode := ANode.ChildAt(0);
  CondNode := ANode.ChildAt(1);
  UseOwnedCompareCondition := BoolConditionHasSupportedOwnedStringCompare(
    CondNode);
  if (not UseOwnedCompareCondition) and
    (not EncodeRuntimeBoolExprFold(CondNode, CondBlob)) then
    Exit;
  BodyLabel := NewBlockLabel('repeat-body');
  CondLabel := NewBlockLabel('repeat-cond');
  ExitLabel := NewBlockLabel('repeat-end');
  FBreakLabels.Push(ExitLabel);
  FContinueLabels.Push(CondLabel);
  EmitGotoLabel(BodyLabel);
  EmitBlockLabel(BodyLabel);
  WalkHaltCalls(BodyNode);
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(CondLabel);
  if UseOwnedCompareCondition and
    (not EncodeRuntimeBoolExprFold(CondNode, CondBlob, True)) then
    Exit;
  NodeId := FModel.AddTypedHirNode(
    'cond-br-runtime', 'until', 0, 0,
    CondBlob + 'labels ' + ExitLabel + #9 + BodyLabel + #10
  );
  AttachRuntimeConditionExpr(NodeId, CondNode);
  EmitPendingStringTempReleases;
  FCurrentBlockTerminated := True;
  EmitBlockLabel(ExitLabel);
  FBreakLabels.Pop;
  FContinueLabels.Pop;
end;

procedure TSemanticAnalyzer.LowerRuntimeCaseStatement(const ANode: TGreenNode);
var
  SelectorNode, SelectorChild, LabelNode, LabelExpr: TGreenNode;
  SelectorBlob, SwitchBlob, ExitLabel, BodyLabel, DefaultLabel: string;
  BodyLabels: array of string;
  I, J, K, CaseCount, SelectorCount: LongInt;
  Val, LoVal, HiVal: Int64;
  HasElse: Boolean;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  if not EncodeRuntimeIntExprFold(ANode.ChildAt(0), SelectorBlob) then
    Exit;

  SelectorCount := 0;
  HasElse := False;
  for I := 1 to ANode.ChildCount - 1 do
  begin
    SelectorChild := ANode.ChildAt(I);
    if (SelectorChild <> nil) and (SelectorChild.NodeKind = gnkCaseSelector) then
      Inc(SelectorCount)
    else
      HasElse := True;
  end;

  ExitLabel := NewBlockLabel('case-end');
  DefaultLabel := NewBlockLabel('case-default');
  SetLength(BodyLabels, SelectorCount);
  for I := 0 to SelectorCount - 1 do
    BodyLabels[I] := NewBlockLabel('case-body');

  CaseCount := 0;
  SwitchBlob := '';
  K := 0;
  for I := 1 to ANode.ChildCount - 1 do
  begin
    SelectorChild := ANode.ChildAt(I);
    if (SelectorChild = nil) or (SelectorChild.NodeKind <> gnkCaseSelector) then
      Continue;
    for J := 0 to SelectorChild.ChildCount - 1 do
    begin
      LabelNode := SelectorChild.ChildAt(J);
      if (LabelNode = nil) or (LabelNode.NodeKind <> gnkCaseLabel) then
        Continue;
      if LabelNode.ChildCount < 1 then
        Continue;
      LabelExpr := LabelNode.ChildAt(0);
      if (LabelExpr <> nil) and (LabelExpr.NodeKind = gnkRangeExpression) and
        (LabelExpr.ChildCount >= 2) then
      begin
        if EvaluateIntegerConstant(LabelExpr.ChildAt(0), LoVal) and
          EvaluateIntegerConstant(LabelExpr.ChildAt(1), HiVal) then
          for Val := LoVal to HiVal do
          begin
            SwitchBlob := SwitchBlob + IntToStr(Val) + #9 + BodyLabels[K] + #10;
            Inc(CaseCount);
          end;
      end
      else if EvaluateIntegerConstant(LabelExpr, Val) then
      begin
        SwitchBlob := SwitchBlob + IntToStr(Val) + #9 + BodyLabels[K] + #10;
        Inc(CaseCount);
      end;
    end;
    Inc(K);
  end;

  FModel.AddTypedHirNode(
    'switch-runtime', 'case', 0, 0,
    SelectorBlob + 'switch ' + IntToStr(CaseCount) + #10 +
    SwitchBlob + 'default' + #9 + DefaultLabel + #10
  );
  FCurrentBlockTerminated := True;

  K := 0;
  for I := 1 to ANode.ChildCount - 1 do
  begin
    SelectorChild := ANode.ChildAt(I);
    if (SelectorChild = nil) or (SelectorChild.NodeKind <> gnkCaseSelector) then
      Continue;
    EmitBlockLabel(BodyLabels[K]);
    for J := 0 to SelectorChild.ChildCount - 1 do
    begin
      LabelNode := SelectorChild.ChildAt(J);
      if (LabelNode <> nil) and (LabelNode.NodeKind <> gnkCaseLabel) then
        WalkHaltCalls(LabelNode);
    end;
    EmitGotoLabel(ExitLabel);
    Inc(K);
  end;

  EmitBlockLabel(DefaultLabel);
  if HasElse then
  begin
    for I := 1 to ANode.ChildCount - 1 do
    begin
      SelectorChild := ANode.ChildAt(I);
      if (SelectorChild <> nil) and (SelectorChild.NodeKind <> gnkCaseSelector) then
        WalkHaltCalls(SelectorChild);
    end;
  end;
  EmitGotoLabel(ExitLabel);
  EmitBlockLabel(ExitLabel);
end;

procedure TSemanticAnalyzer.LowerRuntimeForStatement(const ANode: TGreenNode);
var
  LoopVar, Direction: string;
  StartNode, EndNode, BodyNode: TGreenNode;
  StartBlob, EndBlob, CondBlob: string;
  CondLabel, BodyLabel, StepLabel, ExitLabel: string;
  Pred, Op: string;
begin
  if (ANode = nil) or (ANode.ChildCount < 4) then
    Exit;
  if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
    Exit;
  LoopVar := ANode.ChildAt(0).Text;
  RegisterRuntimeVar(LoopVar);
  StartNode := ANode.ChildAt(1);
  EndNode := ANode.ChildAt(2);
  BodyNode := ANode.ChildAt(3);
  Direction := ANode.Text;
  if not EncodeRuntimeIntExprFold(StartNode, StartBlob) then
    Exit;
  if not EncodeRuntimeIntExprFold(EndNode, EndBlob) then
    Exit;
  if SameText(Direction, 'to') then
  begin
    Pred := 'sle';
    Op := 'add';
  end
  else if SameText(Direction, 'downto') then
  begin
    Pred := 'sge';
    Op := 'sub';
  end
  else
    Exit;
  FModel.AddTypedHirNode(
    'assign-runtime', LoopVar, 0, 0,
    LoopVar + #9 + StartBlob
  );
  CondLabel := NewBlockLabel('for-cond');
  BodyLabel := NewBlockLabel('for-body');
  StepLabel := NewBlockLabel('for-step');
  ExitLabel := NewBlockLabel('for-end');
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(CondLabel);
  CondBlob := 'var ' + LoopVar + #10 + EndBlob + 'cmp ' + Pred + #10;
  FModel.AddTypedHirNode(
    'cond-br-runtime', 'for', 0, 0,
    CondBlob + 'labels ' + BodyLabel + #9 + ExitLabel + #10
  );
  FCurrentBlockTerminated := True;
  FBreakLabels.Push(ExitLabel);
  FContinueLabels.Push(StepLabel);
  EmitBlockLabel(BodyLabel);
  WalkHaltCalls(BodyNode);
  EmitGotoLabel(StepLabel);
  EmitBlockLabel(StepLabel);
  FModel.AddTypedHirNode(
    'assign-runtime', LoopVar, 0, 0,
    LoopVar + #9 + 'var ' + LoopVar + #10 + 'int 1' + #10 + Op + #10
  );
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(ExitLabel);
  FBreakLabels.Pop;
  FContinueLabels.Pop;
end;

procedure TSemanticAnalyzer.LowerRuntimeTryFinallyStatement(const ANode: TGreenNode);
var
  TryBody, FinallyBody: TGreenNode;
  FinallyLabel, EndLabel: string;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then Exit;
  TryBody := ANode.ChildAt(0);
  FinallyBody := ANode.ChildAt(1);
  FinallyLabel := NewBlockLabel('finally');
  EndLabel := NewBlockLabel('endtry');

  FModel.AddTypedHirNode('try-begin-runtime', 'finally', 0, 0,
    FinallyLabel + #10);
  WalkHaltCalls(TryBody);
  FModel.AddTypedHirNode('try-end-runtime', 'finally', 0, 0, '');
  EmitGotoLabel(FinallyLabel);

  EmitBlockLabel(FinallyLabel);
  FModel.AddTypedHirNode('finally-begin-runtime', '', 0, 0, '');
  WalkHaltCalls(FinallyBody);
  FModel.AddTypedHirNode('finally-end-runtime', '', 0, 0, '');
  EmitGotoLabel(EndLabel);

  EmitBlockLabel(EndLabel);
end;

procedure TSemanticAnalyzer.LowerRuntimeTryExceptStatement(const ANode: TGreenNode);
var
  TryBody, HandlerBody: TGreenNode;
  ExceptLabel, EndLabel: string;
  I: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then Exit;
  TryBody := ANode.ChildAt(0);
  ExceptLabel := NewBlockLabel('except');
  EndLabel := NewBlockLabel('endtry');

  FModel.AddTypedHirNode('try-begin-runtime', 'except', 0, 0,
    ExceptLabel + #10);
  WalkHaltCalls(TryBody);
  FModel.AddTypedHirNode('try-end-runtime', 'except', 0, 0, '');
  EmitGotoLabel(EndLabel);

  EmitBlockLabel(ExceptLabel);
  FModel.AddTypedHirNode('except-begin-runtime', '', 0, 0, '');
  for I := 1 to ANode.ChildCount - 1 do
  begin
    HandlerBody := ANode.ChildAt(I);
    if HandlerBody <> nil then
      WalkHaltCalls(HandlerBody);
  end;
  FModel.AddTypedHirNode('except-end-runtime', '', 0, 0, '');
  EmitGotoLabel(EndLabel);

  EmitBlockLabel(EndLabel);
end;

procedure TSemanticAnalyzer.UnrollHaltForLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  LoopVar: string;
  StartValue, EndValue, IterValue: Int64;
  Direction: string;
  BodyNode: TGreenNode;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 4) then
    Exit;
  if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
    Exit;
  LoopVar := ANode.ChildAt(0).Text;
  if not EvaluateIntegerConstant(ANode.ChildAt(1), StartValue) then
    Exit;
  if not EvaluateIntegerConstant(ANode.ChildAt(2), EndValue) then
    Exit;
  Direction := ANode.Text;
  BodyNode := ANode.ChildAt(3);
  IterCount := 0;
  IterValue := StartValue;
  if SameText(Direction, 'to') then
  begin
    while (IterValue <= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkHaltCalls(BodyNode);
      Inc(IterValue);
      Inc(IterCount);
    end;
  end
  else if SameText(Direction, 'downto') then
  begin
    while (IterValue >= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkHaltCalls(BodyNode);
      Dec(IterValue);
      Inc(IterCount);
    end;
  end;
end;

procedure TSemanticAnalyzer.UnrollHaltWhileLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  CondNode, BodyNode: TGreenNode;
  CondValue: Int64;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  CondNode := ANode.ChildAt(0);
  BodyNode := ANode.ChildAt(1);
  IterCount := 0;
  while IterCount < MaxIterations do
  begin
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue = 0 then
      Exit;
    WalkHaltCalls(BodyNode);
    Inc(IterCount);
  end;
end;

procedure TSemanticAnalyzer.UnrollHaltRepeatLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  BodyNode, CondNode: TGreenNode;
  CondValue: Int64;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  BodyNode := ANode.ChildAt(0);
  CondNode := ANode.ChildAt(1);
  IterCount := 0;
  while IterCount < MaxIterations do
  begin
    WalkHaltCalls(BodyNode);
    Inc(IterCount);
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue <> 0 then
      Exit;
  end;
end;

procedure TSemanticAnalyzer.WalkRuntimeVarDecls(const ANode: TGreenNode);
var
  I, J: LongInt;
  Child, Decl, TypeChild, ArrayTypeNode: TGreenNode;
  IsStr, IsThread: Boolean;
  ArrOperand, Operand: string;
  Folded, Value: Int64;
  LSymbolId, LTypeId, HirId: LongInt;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if (Child.NodeKind = gnkProcedureDecl) or
      (Child.NodeKind = gnkFunctionDecl) then
      Continue;
    { threadvar uses gnkThreadVarSection + gnkVarDecl children — same shape
      as var. Without this, bare GAVX2TanBufCapacity residual-calls @Name(). }
    IsThread := Child.NodeKind = gnkThreadVarSection;
    if (Child.NodeKind = gnkVarSection) or IsThread then
    begin
      for J := 0 to Child.ChildCount - 1 do
      begin
        Decl := Child.ChildAt(J);
        if (Decl = nil) or (Decl.NodeKind <> gnkVarDecl) or
          (Decl.Text = '') then
          Continue;
        IsStr := False;
        ArrayTypeNode := nil;
        if Decl.ChildCount > 0 then
        begin
          TypeChild := Decl.ChildAt(0);
          if (TypeChild <> nil) and
            (SameText(TypeChild.Text, 'String') or
             SameText(TypeChild.Text, 'AnsiString')) then
            IsStr := True;
        end;
        ArrayTypeNode := FindArrayTypeNodeForVarDecl(Child, J);
        RegisterRuntimeVar(Decl.Text);
        HirId := 0;
        if IsStr then
        begin
          RegisterRuntimeStrVar(Decl.Text);
          RegisterOwnedRuntimeStrVar(Decl.Text);
          HirId := FModel.AddTypedHirNode(
            'var-decl-tstring-runtime', Decl.Text, 0, 0, Decl.Text
          );
        end
        else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
          (SameText(Decl.ChildAt(0).Text, 'String') or
           SameText(Decl.ChildAt(0).Text, 'AnsiString')) then
        begin
          RegisterRuntimeStrVar(Decl.Text);
          RegisterOwnedRuntimeStrVar(Decl.Text);
          HirId := FModel.AddTypedHirNode(
            'var-decl-tstring-runtime', Decl.Text, 0, 0, Decl.Text
          );
        end
        else if ArrayTypeNode <> nil then
        begin
          RegisterArrayVarMetadata(Decl.Text, ArrayTypeNode, ArrOperand);
          HirId := FModel.AddTypedHirNode(
            'var-decl-arr-runtime', Decl.Text, 0, 0, ArrOperand
          );
        end
        else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
          TypeMetaIsDynArrayType(Decl.ChildAt(0).Text) then
        begin
          RegisterRuntimeArrVar(Decl.Text);
          if FModel.LookupConstValue(
            Decl.ChildAt(0).Text + '$arr_elem_size', Value) then
            FModel.AddConstValue(Decl.Text + '$arr_elem_size', Value);
          if FModel.LookupStringConstValue(
            Decl.ChildAt(0).Text + '$arr_elem_type', Operand) then
            FModel.AddStringConstValue(Decl.Text + '$arr_elem_type', Operand);
          HirId := FModel.AddTypedHirNode(
            'var-decl-arr-runtime', Decl.Text, 0, 0, Decl.Text
          );
        end
        else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
          (Length(Decl.ChildAt(0).Text) > 1) and (Decl.ChildAt(0).Text[1] = '^') then
        begin
          RegisterRuntimeVar(Decl.Text);
          RegisterPointerVar(Decl.Text, Copy(Decl.ChildAt(0).Text, 2,
            Length(Decl.ChildAt(0).Text)));
          HirId := FModel.AddTypedHirNode(
            'var-decl-ptr-runtime', Decl.Text, 0, 0, Decl.Text
          );
        end
        else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
          TypeMetaIsPointer(Decl.ChildAt(0).Text) then
        begin
          RegisterRuntimeVar(Decl.Text);
          RegisterPointerVar(Decl.Text, Decl.ChildAt(0).Text);
          HirId := FModel.AddTypedHirNode(
            'var-decl-ptr-runtime', Decl.Text, 0, 0, Decl.Text
          );
        end
        else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
          TypeMetaIsInterface(Decl.ChildAt(0).Text) then
        begin
          RegisterRuntimeVar(Decl.Text);
          RegisterClassVar(Decl.Text, Decl.ChildAt(0).Text);
          HirId := FModel.AddTypedHirNode(
            'var-decl-ptr-runtime', Decl.Text, 0, 0, Decl.Text
          );
        end
        else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
          (TypeMetaSize(Decl.ChildAt(0).Text) > 0) then
        begin
          if TypeMetaIsRecord(Decl.ChildAt(0).Text) then
          begin
            RegisterRecordVar(Decl.Text, Decl.ChildAt(0).Text);
            HirId := FModel.AddTypedHirNode(
              'var-decl-record-runtime', Decl.Text, 0, 0,
              Decl.Text + #9 + IntToStr(TypeMetaSize(Decl.ChildAt(0).Text) div 8)
            );
            if IsManagedRecord(Decl.ChildAt(0).Text) then
              FRuntimeVars.RegisterManagedRecordVar(Decl.Text, Decl.ChildAt(0).Text);
          end
          else if TypeMetaIsClass(Decl.ChildAt(0).Text) then
          begin
            RegisterClassVar(Decl.Text, Decl.ChildAt(0).Text);
            HirId := FModel.AddTypedHirNode(
              'var-decl-ptr-runtime', Decl.Text, 0, 0, Decl.Text
            );
          end
          else
          begin
            LSymbolId := FindSymbolByName(Decl.Text);
            if LSymbolId > 0 then
              LTypeId := FModel.SymbolTypeId(LSymbolId)
            else
              LTypeId := 0;
            HirId := FModel.AddTypedHirNode(
              'var-decl-runtime', Decl.Text, LSymbolId, LTypeId, Decl.Text
            );
          end;
        end
        else
        begin
          LSymbolId := FindSymbolByName(Decl.Text);
          if LSymbolId > 0 then
            LTypeId := FModel.SymbolTypeId(LSymbolId)
          else
            LTypeId := 0;
          HirId := FModel.AddTypedHirNode(
            'var-decl-runtime', Decl.Text, LSymbolId, LTypeId, Decl.Text
          );
        end;
        if IsThread and (HirId > 0) then
          FModel.SetTypedHirNodeIsThreadVar(HirId, True);
      end;
      Continue;
    end;
    { Typed const arrays need the same arr runtime decl as vars, else
      open-array uses residual-call @Name() and opt fails first on tables. }
    if Child.NodeKind = gnkConstSection then
    begin
      for J := 0 to Child.ChildCount - 1 do
      begin
        Decl := Child.ChildAt(J);
        if (Decl = nil) or (Decl.NodeKind <> gnkConstDecl) or
          (Decl.Text = '') then
          Continue;
        ArrayTypeNode := nil;
        if Decl.ChildCount > 0 then
        begin
          TypeChild := Decl.ChildAt(0);
          if (TypeChild <> nil) and (TypeChild.NodeKind = gnkArrayType) then
            ArrayTypeNode := TypeChild;
        end;
        if ArrayTypeNode = nil then
          Continue;
        RegisterRuntimeVar(Decl.Text);
        RegisterArrayVarMetadata(Decl.Text, ArrayTypeNode, ArrOperand);
        FModel.AddTypedHirNode(
          'var-decl-arr-runtime', Decl.Text, 0, 0, ArrOperand
        );
      end;
      Continue;
    end;
    WalkRuntimeVarDecls(Child);
  end;
end;
