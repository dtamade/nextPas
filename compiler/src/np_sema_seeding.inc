procedure TSemanticAnalyzer.SeedBuiltinTypes;
begin
  nextpas.compiler.sema.builtins.SeedBuiltinTypes(FModel);
end;

procedure TSemanticAnalyzer.SeedCachedTypeGaps;
var
  HasClassLikeMembers: Boolean;
  I, J: LongInt;
  ExistingTypeId: LongInt;
  MemberSym, TypeSym: TSemanticSymbol;
  ParentTypeId: LongInt;
  Meta: TTypeMetadata;
  OwnerUnitId: string;
begin
  { Cached units only register symbols, not types. Seed type entries for
    type symbols from cached units that are missing from the model. }
  for I := 0 to FModel.SymbolCount - 1 do
  begin
    TypeSym := FModel.SymbolAt(I);
    if not SameText(TypeSym.Kind, 'type') then
      Continue;
    OwnerUnitId := NormalizeUnitIdentity(TypeSym.OwnerUnitId);
    if OwnerUnitId = '' then
      Continue;

    ExistingTypeId := 0;
    if (TypeSym.TypeId > 0) and (TypeSym.TypeId <= FModel.TypeCount) then
      ExistingTypeId := TypeSym.TypeId
    else
      ExistingTypeId := ResolveTypeIdForOwner(TypeSym.Name, OwnerUnitId, False);
    if ExistingTypeId <= 0 then
      ExistingTypeId := FModel.FindTypeByName(TypeSym.Name);

    if ExistingTypeId <= 0 then
    begin
      ExistingTypeId := FModel.AddType(TypeSym.Name, 'declared');
      FModel.SetTypeOwner(ExistingTypeId, OwnerUnitId);
    end;
    FModel.SetSymbolTypeId(TypeSym.SymbolId, ExistingTypeId);

    HasClassLikeMembers := False;
    for J := 0 to FModel.SymbolCount - 1 do
    begin
      MemberSym := FModel.SymbolAt(J);
      if SameText(MemberSym.OwnerUnitId, OwnerUnitId) and
        SameText(MemberSym.Kind, 'method') and
        (Pos(LowerCase(FModel.TypeAt(ExistingTypeId - 1).Name) + '.',
          LowerCase(MemberSym.Name)) = 1) then
      begin
        HasClassLikeMembers := True;
        Break;
      end;
    end;

    if HasClassLikeMembers or SameText(TypeSym.Name, 'Exception') or
      SameText(TypeSym.Name, 'ExceptClass') or
      (SameText(Copy(TypeSym.Name, 1, 1), 'E') and
       (Length(TypeSym.Name) > 1) and
       (TypeSym.Name[2] in ['A'..'Z'])) then
    begin
      { 接口的 method symbol 前缀(IHasher.Sum)会误判 HasClassLikeMembers,
        空 Meta 覆盖会清掉 seed 期已建的 VmtSlots 与 $vmt_slot_* consts
        (IHasher.Write 因此长期 undefined)。已有明细的类型跳过覆盖——
        Fields 也是明细:无 virtual 方法的类(TElementManager 等)VmtCount=0
        但字段布局已注册,seed 空壳会清掉 Fields(b4b-i8 @FAllocator 根因)。 }
      if FModel.GetTypeMeta(ExistingTypeId, Meta) and
        ((Meta.VmtSlots <> nil) or (Meta.VmtCount > 0) or
         (Meta.Fields <> nil)) then
        Continue;
      ParentTypeId := 0;
      if not SameText(TypeSym.Name, 'TObject') then
        ParentTypeId := FModel.FindTypeByName('TObject');
      if ParentTypeId > 0 then
        FModel.SetTypeParent(ExistingTypeId, ParentTypeId);
      FillChar(Meta, SizeOf(Meta), 0);
      Meta.TypeId := ExistingTypeId;
      Meta.Size := 8;
      Meta.VmtCount := 0;
      Meta.ParentClassId := ParentTypeId;
      if ParentTypeId > 0 then
        Meta.ParentClassName := 'TObject';
      FModel.SetTypeMeta(ExistingTypeId, Meta);
      FModel.AddConstValue(TypeSym.Name + '$size', 8);
      FModel.AddConstValue(TypeSym.Name + '$vmt_count', 0);
      if ParentTypeId > 0 then
        FModel.AddStringConstValue(TypeSym.Name + '$parent_class', 'TObject');
    end;
  end;
end;

procedure TSemanticAnalyzer.AssignScopesToSymbols;
var
  I: LongInt;
  Sym: TSemanticSymbol;
begin
  for I := 0 to FModel.SymbolCount - 1 do
  begin
    Sym := FModel.SymbolAt(I);
    if Sym.ScopeId = 0 then
      FModel.SetSymbolScope(Sym.SymbolId, FCurrentScopeId);
  end;
end;

{ === Validation methods (extracted to np_sema_validation.inc) === }
{$I np_sema_validation.inc}

procedure TSemanticAnalyzer.SeedUnitSymbolsAndHir;
var
  Index: LongInt;
  ResolvedUnit: TResolvedUnit;
  SymbolId: LongInt;
begin
  FModel.SetRootName(FUnitGraph.RootName);
  FModel.AddTypedHirNode('compilation-root', FUnitGraph.RootName, 0, 0, '');

  for Index := 0 to FUnitGraph.ResolvedUnitCount - 1 do
  begin
    ResolvedUnit := FUnitGraph.ResolvedUnitAt(Index);
    SymbolId := FModel.AddSymbol(
      ResolvedUnit.CanonicalName,
      'unit',
      ResolvedUnit.UnitId,
      0,
      0
    );
    FModel.AddTypedHirNode(
      'resolved-unit',
      ResolvedUnit.CanonicalName,
      SymbolId,
      0,
      ''
    );
  end;
end;

procedure TSemanticAnalyzer.SeedRuntimeContracts;
  procedure AddRuntimeContract(const AContractName, AKind: string);
  begin
    FModel.AddRuntimeContract(AContractName);
    FModel.AddTypedHirNode(AKind, AContractName, 0, 0, '');
  end;

  procedure SeedUnitLifecycle;
  var
    RootNode, Child, ImplChild: TGreenNode;
    I, J: LongInt;
    HirId: LongInt;
    UnitName: string;
  begin
    if FRootAst = nil then
      Exit;
    RootNode := FRootAst.RootNode;
    if RootNode = nil then
      Exit;
    UnitName := FUnitGraph.RootName;
    for I := 0 to RootNode.ChildCount - 1 do
    begin
      Child := RootNode.ChildAt(I);
      if Child.NodeKind = gnkImplementationSection then
      begin
        for J := 0 to Child.ChildCount - 1 do
        begin
          ImplChild := Child.ChildAt(J);
          if ImplChild.NodeKind = gnkInitializationSection then
          begin
            FModel.AddRuntimeContract(NPSYSTEM_UNIT_INIT);
            HirId := FModel.AddTypedHirNode('unit-init-runtime', UnitName, 0, 0, UnitName);
            FModel.SetTypedHirNodeGreenRef(HirId, ImplChild);
          end
          else if ImplChild.NodeKind = gnkFinalizationSection then
          begin
            FModel.AddRuntimeContract(NPSYSTEM_UNIT_FINI);
            HirId := FModel.AddTypedHirNode('unit-fini-runtime', UnitName, 0, 0, UnitName);
            FModel.SetTypedHirNodeGreenRef(HirId, ImplChild);
          end;
        end;
        Break;
      end;
    end;
  end;

begin
  if (FRootAst.RootKindName = 'program') or
    (FRootAst.RootKindName = 'library') or
    (FRootAst.RootKindName = 'package') then
  begin
    AddRuntimeContract(NPSYSTEM_PROCESS_INIT, 'process-init-runtime');
    { process_fini 不在此处 seed，而是在 Analyze 末尾 SeedHaltCalls 之后，
      确保 HIR 顺序为: process_init → 用户代码 → process_fini }
  end
  else if FRootAst.RootKindName = 'unit' then
    SeedUnitLifecycle;
end;

{$I np_sema_seed_foreign_procedures.inc}
{$I np_sema_declaration.inc}
procedure TSemanticAnalyzer.SeedDeclarations;
var
  OwnerUnitId: string;
  RootNode: TGreenNode;
begin
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  OwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkDeclarations(RootNode, OwnerUnitId);
end;

{$I np_sema_assignment_handling.inc}
{$I np_sema_array_metadata.inc}

function TSemanticAnalyzer.EvaluateFloatConstant(const ANode: TGreenNode;
  out AValue: Double): Boolean;
var
  Parsed: Double;
  ParseCode: Word;
  IntVal: Int64;
  TypeId: LongInt;
  ArgNode: TGreenNode;
  Left, Right: Double;
begin
  AValue := 0.0;
  if ANode = nil then
    Exit(False);
  case ANode.NodeKind of
    gnkRealLiteral:
      begin
        Val(ANode.Text, Parsed, ParseCode);
        if ParseCode <> 0 then
          Exit(False);
        AValue := Parsed;
        Exit(True);
      end;
    gnkIntegerLiteral:
      begin
        { Integer formals of float const: Double(1) / bare 0 in float context. }
        Val(ANode.Text, IntVal, ParseCode);
        if ParseCode <> 0 then
          Exit(False);
        AValue := IntVal;
        Exit(True);
      end;
    gnkIdentifier:
      begin
        { ProcessConstSection / reexport: prefer model table over hardcodes. }
        if FModel.LookupFloatConstValue(ANode.Text, Parsed) then
        begin
          AValue := Parsed;
          Exit(True);
        end;
        if SameText(ANode.Text, 'DEG_TO_RAD') then
        begin
          AValue := 0.01745329251994329577;
          Exit(True);
        end;
        if SameText(ANode.Text, 'RAD_TO_DEG') then
        begin
          AValue := 57.2957795130823208768;
          Exit(True);
        end;
        if SameText(ANode.Text, 'PI') or SameText(ANode.Text, 'PI_VALUE') then
        begin
          AValue := 3.14159265358979323846;
          Exit(True);
        end;
        if SameText(ANode.Text, 'HALF_PI') then
        begin
          AValue := 1.57079632679489661923;
          Exit(True);
        end;
        if SameText(ANode.Text, 'TWO_PI') then
        begin
          AValue := 6.28318530717958647692;
          Exit(True);
        end;
        if SameText(ANode.Text, 'QUARTER_PI') then
        begin
          AValue := 0.78539816339744830962;
          Exit(True);
        end;
        Exit(False);
      end;
    gnkDotAccess:
      begin
        { unit reexport: nextpas.core.math.base.HALF_PI → bare HALF_PI table. }
        ArgNode := ANode;
        while (ArgNode <> nil) and (ArgNode.NodeKind = gnkDotAccess) and
          (ArgNode.ChildCount >= 2) do
          ArgNode := ArgNode.ChildAt(1);
        if (ArgNode <> nil) and (ArgNode.NodeKind = gnkIdentifier) and
          EvaluateFloatConstant(ArgNode, Parsed) then
        begin
          AValue := Parsed;
          Exit(True);
        end;
        Exit(False);
      end;
    gnkUnaryExpression:
      begin
        if (ANode.ChildCount >= 1) and (ANode.Text = '-') and
          EvaluateFloatConstant(ANode.ChildAt(0), Left) then
        begin
          AValue := -Left;
          Exit(True);
        end;
        if (ANode.ChildCount >= 1) and (ANode.Text = '+') and
          EvaluateFloatConstant(ANode.ChildAt(0), Left) then
        begin
          AValue := Left;
          Exit(True);
        end;
        Exit(False);
      end;
    gnkBinaryExpression:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if not EvaluateFloatConstant(ANode.ChildAt(0), Left) then
          Exit(False);
        if not EvaluateFloatConstant(ANode.ChildAt(1), Right) then
          Exit(False);
        if ANode.Text = '+' then
          AValue := Left + Right
        else if ANode.Text = '-' then
          AValue := Left - Right
        else if ANode.Text = '*' then
          AValue := Left * Right
        else if (ANode.Text = '/') and (Right <> 0.0) then
          AValue := Left / Right
        else
          Exit(False);
        Exit(True);
      end;
    gnkFunctionCall:
      begin
        { HALF_PI = Double(1.5707…) — cast form seeds via ProcessConstSection.
          Without this, bare HALF_PI residual-calls @HALF_PI() (Tan$p first). }
        if (ANode.ChildCount = 2) and
          TryGetTypeCastTargetTypeId(ANode, TypeId) and
          EvaluateFloatConstant(ANode.ChildAt(1), Parsed) then
        begin
          AValue := Parsed;
          Exit(True);
        end;
        Exit(False);
      end;
  else
    Exit(False);
  end;
end;

function TSemanticAnalyzer.EvaluateStringConstant(const ANode: TGreenNode;
  out AValue: string): Boolean;
var
  Op, Left, Right: string;
begin
  AValue := '';
  if ANode = nil then
    Exit(False);
  case ANode.NodeKind of
    gnkStringLiteral:
      begin
        AValue := DecodePascalStringLiteral(ANode.Text);
        Exit(True);
      end;
    gnkIdentifier:
      begin
        if FModel.LookupStringConstValue(ANode.Text, Left) then
        begin
          AValue := Left;
          Exit(True);
        end;
        Exit(False);
      end;
    gnkBinaryExpression:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        Op := ANode.Text;
        if Op <> '+' then
          Exit(False);
        if not EvaluateStringConstant(ANode.ChildAt(0), Left) then
          Exit(False);
        if not EvaluateStringConstant(ANode.ChildAt(1), Right) then
          Exit(False);
        AValue := Left + Right;
        Exit(True);
      end;
  end;
  Result := False;
end;

function DecodePascalStringLiteral(const AText: string): string;
var
  Raw: string;
  Index: SizeInt;
begin
  Result := '';
  if Length(AText) < 2 then
    Exit;
  if (AText[1] <> '''') or (AText[Length(AText)] <> '''') then
    Exit;
  Raw := Copy(AText, 2, Length(AText) - 2);
  Index := 1;
  while Index <= Length(Raw) do
  begin
    if (Raw[Index] = '''') and (Index < Length(Raw)) and (Raw[Index + 1] = '''') then
    begin
      Result := Result + '''';
      Inc(Index, 2);
    end
    else
    begin
      Result := Result + Raw[Index];
      Inc(Index);
    end;
  end;
end;

function EncodePascalStringLiteral(const AValue: string): string;
var
  Q: LongInt;
begin
  Result := '''';
  for Q := 1 to Length(AValue) do
  begin
    if AValue[Q] = '''' then
      Result := Result + ''''''''
    else
      Result := Result + AValue[Q];
  end;
  Result := Result + '''';
end;

{ === Codegen methods (extracted to np_sema_codegen.inc) === }
{$I np_sema_codegen.inc}

procedure TSemanticAnalyzer.SeedRuntimeVarDecls;
var
  RootNode: TGreenNode;
  I: LongInt;
  Tree: TGreenTree;
  OwnerId: string;
begin
  if not FNoFold then
    Exit;
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  if (FRootAst.RootKindName <> 'program') and
    (FRootAst.RootKindName <> 'library') and
    (FRootAst.RootKindName <> 'package') then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkRuntimeVarDecls(RootNode);
  { Multi-unit host-free: unit-level vars (GMuAcc, ...) live in imported unit
    ASTs registered by SeedImportedUnitBodies. Skip System to avoid flooding
    IR with full kernel globals. }
  if (FImportedUnitTrees <> nil) and (FImportedUnitOwners <> nil) then
    for I := 0 to LongInt(FImportedUnitTrees.Count) - 1 do
    begin
      Tree := FImportedUnitTrees[I];
      if (Tree = nil) or (Tree.RootNode = nil) then
        Continue;
      if I < LongInt(FImportedUnitOwners.Count) then
        OwnerId := FImportedUnitOwners[I]
      else
        OwnerId := '';
      if SameText(NormalizeUnitIdentity(OwnerId), 'system') then
        Continue;
      WalkRuntimeVarDecls(Tree.RootNode);
    end;
end;

procedure TSemanticAnalyzer.SeedHaltCalls;
var
  RootNode: TGreenNode;
begin
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  if (FRootAst.RootKindName <> 'program') and
    (FRootAst.RootKindName <> 'library') and
    (FRootAst.RootKindName <> 'package') then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkHaltCalls(RootNode);
  if FNoFold and not FCurrentBlockTerminated then
  begin
    EmitOwnedManagedRecordCleanupNodes;
    EmitOwnedDynArrayCleanupNodes;
    EmitOwnedStringCleanupNodes;
    FModel.AddTypedHirNode('halt-call-runtime', 'Halt', 0, 0, 'int 0' + #10);
    FCurrentBlockTerminated := True;
  end;
end;

procedure TSemanticAnalyzer.PreRegisterFunctionReturnTypes;
var
  I, J: LongInt;
  Entry: TProcedureBodyEntry;
  Child: TGreenNode;
  Folded: Int64;
begin
  for I := 0 to LongInt(FProcedureBodies.Count) - 1 do
  begin
    Entry := FProcedureBodies[I];
    if (Entry.Decl = nil) or (Entry.Body = nil) then
      Continue;
    if Pos('<', Entry.Name) > 0 then
      Continue;
    for J := 0 to Entry.Decl.ChildCount - 1 do
    begin
      Child := Entry.Decl.ChildAt(J);
      if Child = nil then
        Continue;
      if (Child.NodeKind = gnkIdentifier) and
        (SameText(Child.Text, 'String') or
         SameText(Child.Text, 'AnsiString')) then
      begin
        RegisterRuntimeVar(Entry.Name);
        RegisterRuntimeStrVar(Entry.Name);
        Break;
      end;
      if (Child.NodeKind = gnkIdentifier) and
        (Child.NodeKind <> gnkBeginBlock) and
        (TypeMetaSize(Child.Text) > 0) and
        (Pos('.', Entry.Name) = 0) then
      begin
        if not TypeMetaIsRecord(Child.Text) then
          RegisterPtrReturnFunc(Entry.Name, Child.Text);
        Break;
      end;
    end;
  end;
end;

{$I np_sema_seed_function_bodies.inc}
procedure TSemanticAnalyzer.SeedUnitLifecycleBodies;
var
  I: LongInt;
  Node: TTypedHirNode;
  SavedRetVarName: string;
  SavedOwnedReturn: Boolean;
  SavedBlockTerminated: Boolean;
  SavedMethodClass: string;
  LNormalizedUnitName: string;
  LFuncName: string;
begin
  for I := 0 to FModel.TypedHirNodeCount - 1 do
  begin
    Node := FModel.TypedHirNodeAt(I);
    if (Node.NodeKind <> hnkUnitInitRuntime) and
       (Node.NodeKind <> hnkUnitFiniRuntime) then
      Continue;
    if GreenNodeIsNil(Node.GreenNodeRef) then
      Continue;

    // Save current state
    SavedRetVarName := FCurrentRetVarName;
    SavedOwnedReturn := FCurrentOwnedStringReturn;
    SavedBlockTerminated := FCurrentBlockTerminated;
    SavedMethodClass := FCurrentMethodClass;

    // Reset for void function with no params — 全部 13 个 tracker 清零
    FRuntimeVars.Reset;
    FCurrentRetVarName := '';
    FCurrentOwnedStringReturn := False;
    FCurrentBlockTerminated := False;
    FCurrentMethodClass := '';

    { UnitId identity is lowercase (NormalizeUnitIdentity). TopologicalInitOrder
      may carry CanonicalName case — without LowerCase, define/call symbols diverge
      (e.g. @np_unit_init_MuInitLeaf vs @np_unit_init_muinitleaf). }
    LNormalizedUnitName := LowerCase(StringReplace(Node.Operand, '.', '_', True));

    if Node.NodeKind = hnkUnitInitRuntime then
    begin
      LFuncName := 'np_unit_init_' + LNormalizedUnitName;
      FModel.AddTypedHirNode('function-body-begin',
        LFuncName, 0, 0, '0:');
      WalkHaltCalls(Node.GreenNodeRef);
      if not FCurrentBlockTerminated then
      begin
        EmitOwnedManagedRecordCleanupNodes;
        EmitOwnedDynArrayCleanupNodes;
        EmitOwnedStringCleanupNodes('');
        FModel.AddTypedHirNode('ret-runtime', '0', 0, 0, 'int 0' + #10);
      end;
      FModel.AddTypedHirNode('function-body-end',
        LFuncName, 0, 0, '');
    end
    else
    begin
      LFuncName := 'np_unit_fini_' + LNormalizedUnitName;
      FModel.AddTypedHirNode('function-body-begin',
        LFuncName, 0, 0, '0:');
      WalkHaltCalls(Node.GreenNodeRef);
      if not FCurrentBlockTerminated then
      begin
        EmitOwnedManagedRecordCleanupNodes;
        EmitOwnedDynArrayCleanupNodes;
        EmitOwnedStringCleanupNodes('');
        FModel.AddTypedHirNode('ret-runtime', '0', 0, 0, 'int 0' + #10);
      end;
      FModel.AddTypedHirNode('function-body-end',
        LFuncName, 0, 0, '');
    end;

    // Restore state
    FCurrentRetVarName := SavedRetVarName;
    FCurrentOwnedStringReturn := SavedOwnedReturn;
    FCurrentBlockTerminated := SavedBlockTerminated;
    FCurrentMethodClass := SavedMethodClass;
  end;
end;

