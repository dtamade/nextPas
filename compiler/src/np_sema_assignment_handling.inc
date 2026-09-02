procedure TSemanticAnalyzer.RebindExplicitClassParents;

  procedure RebindTypeSection(
    const ATypeSection: TGreenNode;
    const AOwnerUnitId: string
  );
  var
    Child: TGreenNode;
    Index: LongInt;
    Meta: TTypeMetadata;
    ParentNode: TGreenNode;
    ParentTypeId: LongInt;
    TypeChild: TGreenNode;
    TypeId: LongInt;
    TypeInfo: TSemanticType;
    TypeIndex: LongInt;
  begin
    if ATypeSection = nil then
      Exit;

    for Index := 0 to ATypeSection.ChildCount - 1 do
    begin
      Child := ATypeSection.ChildAt(Index);
      if (Child = nil) or (Child.NodeKind <> gnkTypeDecl) or
        (Child.Text = '') then
        Continue;

      TypeId := ResolveTypeIdForOwner(Child.Text, AOwnerUnitId);
      if (TypeId <= 0) or (TypeId > FModel.TypeCount) then
        Continue;

      TypeInfo := FModel.TypeAt(TypeId - 1);
      if TypeInfo.ParentTypeId > 0 then
        Continue;

      for TypeIndex := 0 to Child.ChildCount - 1 do
      begin
        TypeChild := Child.ChildAt(TypeIndex);
        if (TypeChild = nil) or (TypeChild.NodeKind <> gnkClassType) or
          SameText(TypeChild.Text, 'interface') or
          (TypeChild.ChildCount = 0) then
          Continue;

        ParentNode := TypeChild.ChildAt(0);
        if (ParentNode = nil) or (ParentNode.NodeKind <> gnkIdentifier) then
          Break;

        ParentTypeId := ResolveTypeIdForOwner(ParentNode.Text, AOwnerUnitId);
        if (ParentTypeId <= 0) or (ParentTypeId > FModel.TypeCount) then
          Break;
        if TypeMetaIsInterface(FModel.TypeAt(ParentTypeId - 1).Name) then
          Break;

        FModel.SetTypeParent(TypeId, ParentTypeId);
        if FModel.GetTypeMeta(TypeId, Meta) then
        begin
          Meta.ParentClassId := ParentTypeId;
          if Meta.ParentClassName = '' then
            Meta.ParentClassName := FModel.TypeAt(ParentTypeId - 1).Name;
          FModel.SetTypeMeta(TypeId, Meta);
        end;
        Break;
      end;
    end;
  end;

  procedure RebindInNode(
    const ANode: TGreenNode;
    const AOwnerUnitId: string
  );
  var
    Child: TGreenNode;
    Index: LongInt;
  begin
    if ANode = nil then
      Exit;

    for Index := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(Index);
      if Child = nil then
        Continue;
      case Child.NodeKind of
        gnkTypeSection:
          RebindTypeSection(Child, AOwnerUnitId);
        gnkInterfaceSection, gnkImplementationSection:
          RebindInNode(Child, AOwnerUnitId);
      end;
    end;
  end;

var
  Index: LongInt;
  RootNode: TGreenNode;
begin
  if (FRootAst <> nil) and FRootAst.IsValid then
  begin
    RootNode := FRootAst.RootNode;
    if RootNode <> nil then
      RebindInNode(RootNode, NormalizeUnitIdentity(FUnitGraph.RootName));
  end;

  for Index := 0 to LongInt(FImportedUnitTrees.Count) - 1 do
    RebindInNode(FImportedUnitTrees[Index].RootNode, FImportedUnitOwners[Index]);
end;

procedure TSemanticAnalyzer.WalkAssignmentStatements(const ANode: TGreenNode);
var
  I: LongInt;
  Child, RhsNode, BranchNode: TGreenNode;
  LhsSymbolId, RhsSymbolId: LongInt;
  LhsTypeId, RhsTypeId: LongInt;
  Value, CondValue: Int64;
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
    if Child.NodeKind = gnkIfStatement then
    begin
      if (Child.ChildCount >= 2) and
        EvaluateIntegerConstant(Child.ChildAt(0), CondValue) then
      begin
        if CondValue <> 0 then
          BranchNode := Child.ChildAt(1)
        else if Child.ChildCount >= 3 then
          BranchNode := Child.ChildAt(2)
        else
          BranchNode := nil;
        if BranchNode <> nil then
          WalkAssignmentStatements(BranchNode);
      end
      else
        WalkAssignmentStatements(Child);
      Continue;
    end;
    if Child.NodeKind = gnkForStatement then
    begin
      UnrollAssignmentForLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkWhileStatement then
    begin
      UnrollAssignmentWhileLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkRepeatStatement then
    begin
      UnrollAssignmentRepeatLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkAssignmentStatement then
    begin
      LhsSymbolId := FindSymbolByName(Child.Text);
      if LhsSymbolId = 0 then
        Continue;
      LhsTypeId := FModel.SymbolTypeId(LhsSymbolId);
      RhsNode := nil;
      if Child.ChildCount >= 2 then
        RhsNode := Child.ChildAt(1)
      else if (Child.ChildCount = 1) and
        (Child.ChildAt(0).NodeKind <> gnkIdentifier) and
        (Child.ChildAt(0).NodeKind <> gnkDotAccess) and
        (Child.ChildAt(0).NodeKind <> gnkArrayAccess) then
        RhsNode := Child.ChildAt(0);
      if RhsNode <> nil then
      begin
        if EvaluateIntegerConstant(RhsNode, Value) then
          FModel.AddVarInitValue(Child.Text, Value)
        else
          FModel.RemoveVarInitValue(Child.Text);
      end;
    end
    else
      WalkAssignmentStatements(Child);
  end;
end;

procedure TSemanticAnalyzer.UnrollAssignmentForLoop(const ANode: TGreenNode);
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
      WalkAssignmentStatements(BodyNode);
      Inc(IterValue);
      Inc(IterCount);
    end;
  end
  else if SameText(Direction, 'downto') then
  begin
    while (IterValue >= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkAssignmentStatements(BodyNode);
      Dec(IterValue);
      Inc(IterCount);
    end;
  end;
end;

procedure TSemanticAnalyzer.UnrollAssignmentWhileLoop(const ANode: TGreenNode);
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
    WalkAssignmentStatements(BodyNode);
    Inc(IterCount);
  end;
end;

procedure TSemanticAnalyzer.UnrollAssignmentRepeatLoop(const ANode: TGreenNode);
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
    WalkAssignmentStatements(BodyNode);
    Inc(IterCount);
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue <> 0 then
      Exit;
  end;
end;

procedure TSemanticAnalyzer.CheckAssignmentTypes;
var
  RootNode: TGreenNode;
begin
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkAssignmentStatements(RootNode);
end;

{$I np_sema_evaluate_integer_constant.inc}
