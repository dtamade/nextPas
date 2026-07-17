function TSemanticAnalyzer.MangledName(const AName: string;
  AParamCount: LongInt): string;
begin
  Result := np_sema_overload.MangledName(AName, AParamCount);
end;

function TSemanticAnalyzer.MangledNameSig(const AName: string;
  const ASig: string): string;
begin
  Result := np_sema_overload.MangledNameSig(AName, ASig);
end;

procedure TSemanticAnalyzer.RegisterProcedureBody(const AName: string;
  const ABody: TGreenNode; const ADecl: TGreenNode;
  const AOwnerUnitId: string);
var
  Index: LongInt;
  Sig, ExistingSig, CleanName: string;
  Entry: TProcedureBodyEntry;
begin
  if Pos(';compilerproc', AName) > 0 then
  begin
    CleanName := Copy(AName, 1, Pos(';', AName) - 1);
    FCompilerProcNames.Push(CleanName);
  end
  else
    CleanName := AName;
  Sig := GetParamIdentitySignature(ADecl);
  for Index := 0 to LongInt(FProcedureBodies.Count) - 1 do
    if SameText(FProcedureBodies[Index].Name, CleanName) and
      SameText(FProcedureBodies[Index].OwnerUnitId, AOwnerUnitId) then
    begin
      ExistingSig := GetParamIdentitySignature(FProcedureBodies[Index].Decl);
      if ExistingSig = Sig then
      begin
        Entry := FProcedureBodies[Index];
        Entry.Body := ABody;
        Entry.Decl := ADecl;
        Entry.OwnerUnitId := AOwnerUnitId;
        Entry.ScopeId := FCurrentScopeId;
        FProcedureBodies[Index] := Entry;
        Exit;
      end;
    end;
  Entry.Name := CleanName;
  Entry.Body := ABody;
  Entry.Decl := ADecl;
  Entry.OwnerUnitId := AOwnerUnitId;
  Entry.ScopeId := FCurrentScopeId;
  FProcedureBodies.Push(Entry);
end;

function TSemanticAnalyzer.ProcedureBodyScopeIdForDecl(
  const ADecl: TGreenNode
): LongInt;
var
  Index, NameMatchCount, NameMatchScopeId: LongInt;
  DeclName: string;
begin
  Result := 0;
  if ADecl = nil then
    Exit;
  DeclName := ADecl.Text;
  { Try exact pointer match first }
  for Index := 0 to LongInt(FProcedureBodies.Count) - 1 do
    if FProcedureBodies[Index].Decl = ADecl then
      Exit(FProcedureBodies[Index].ScopeId);
  { Fallback: name match for overloaded declarations sharing same body entry.
    Only when exactly one entry has this name (no ambiguity). }
  if DeclName <> '' then
  begin
    NameMatchCount := 0;
    NameMatchScopeId := 0;
    for Index := 0 to LongInt(FProcedureBodies.Count) - 1 do
      if SameText(FProcedureBodies[Index].Name, DeclName) then
      begin
        Inc(NameMatchCount);
        NameMatchScopeId := FProcedureBodies[Index].ScopeId;
      end;
    if NameMatchCount = 1 then
      Result := NameMatchScopeId;
  end;
end;

function TSemanticAnalyzer.ParamDeclTypeId(
  const AParamDecl: TGreenNode; const AOwnerUnitId: string): LongInt;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.ParamDeclTypeId(Ctx, AParamDecl, AOwnerUnitId);
end;

function TSemanticAnalyzer.LookupProcedureBody(const AName: string;
  out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
var
  Index: LongInt;
begin
  ABody := nil;
  ADecl := nil;
  for Index := 0 to LongInt(FProcedureBodies.Count) - 1 do
    if SameText(FProcedureBodies[Index].Name, AName) then
    begin
      ABody := FProcedureBodies[Index].Body;
      ADecl := FProcedureBodies[Index].Decl;
      Exit(True);
    end;
  Result := False;
end;

function TSemanticAnalyzer.HasOverload(const AName: string): Boolean;
begin
  Result := np_sema_overload.HasOverload(AName, FProcedureBodies);
end;

function TSemanticAnalyzer.LookupOverload(const AName: string;
  AArgCount: LongInt; out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
begin
  Result := np_sema_overload.LookupOverload(AName, AArgCount, FProcedureBodies, ABody, ADecl);
end;

function TSemanticAnalyzer.LookupCallBindingDeclaration(
  const AName: string; const AArgCount: LongInt;
  const AArgTypeIds: TTypeIdArray; const AArgSignature: string;
  const AHasArgSignature: Boolean; const AHasTypeMismatchEvidence: Boolean;
  out AResolutionFailureKind: string;
  out ABody: TGreenNode; out ADecl: TGreenNode; out AOwnerUnitId: string): Boolean;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.LookupCallBindingDeclaration(
    Ctx, AName, AArgCount, AArgTypeIds, AArgSignature,
    AHasArgSignature, AHasTypeMismatchEvidence,
    AResolutionFailureKind, ABody, ADecl, AOwnerUnitId);
end;

function TSemanticAnalyzer.OwnerUnitAllowsProjectSourceDiagnostic(
  const AOwnerUnitId: string
): Boolean;
var
  Ctx: TSemaImportContext;
begin
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Result := np_sema_overload.OwnerUnitAllowsProjectSourceDiagnostic(Ctx, AOwnerUnitId);
end;

function TSemanticAnalyzer.HasInstalledSourceImports: Boolean;
var
  Index: LongInt;
  ResolvedUnit: TResolvedUnit;
begin
  Result := False;
  for Index := 0 to FUnitGraph.ResolvedUnitCount - 1 do
  begin
    ResolvedUnit := FUnitGraph.ResolvedUnitAt(Index);
    if SameText(ResolvedUnit.OriginClass, 'installed-source') then
      Exit(True);
  end;
end;

function TSemanticAnalyzer.UnitDirectlyImports(
  const AOwnerUnitId: string;
  const AImportedUnitId: string
): Boolean;
var
  Ctx: TSemaImportContext;
begin
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Result := np_sema_overload.UnitDirectlyImports(Ctx, AOwnerUnitId, AImportedUnitId);
end;

function TSemanticAnalyzer.ExpressionTypeFactIsStable(
  const ANode: TGreenNode;
  const ACurrentOwnerUnitId: string
): Boolean;
var
  CallName: string;
  CurrentOwnerUnitId: string;
  Index: LongInt;
  RootOwnerUnitId: string;
  Sym: TSemanticSymbol;
  SymId: LongInt;
  TargetTypeId: LongInt;
begin
  Result := False;
  if ANode = nil then
    Exit;

  CurrentOwnerUnitId := NormalizeUnitIdentity(ACurrentOwnerUnitId);
  RootOwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);

  case ANode.NodeKind of
    gnkIntegerLiteral, gnkRealLiteral, gnkStringLiteral, gnkCharLiteral:
      Exit(True);
    gnkIdentifier:
      begin
        if SameText(ANode.Text, 'True') or SameText(ANode.Text, 'False') then
          Exit(True);
        SymId := FModel.LookupSymbol(ANode.Text, FCurrentScopeId);
        if SymId <= 0 then
          Exit(False);
        Sym := FModel.SymbolAt(SymId - 1);
        if SameText(Sym.Kind, 'function') then
        begin
          Exit((Sym.ParamCount = 0) and
            (
              SameText(Sym.OwnerUnitId, RootOwnerUnitId) or
              (
                (CurrentOwnerUnitId <> '') and
                SameText(Sym.OwnerUnitId, CurrentOwnerUnitId) and
                OwnerUnitAllowsProjectSourceDiagnostic(Sym.OwnerUnitId)
              )
            ) and
            TypeIdHasStableScalarFact(Sym.TypeId));
        end
        else if (not SameText(Sym.Kind, 'variable')) and
          (not SameText(Sym.Kind, 'parameter')) and
          (not SameText(Sym.Kind, 'field')) then
          Exit(False);
        if TypeIdHasStableScalarFact(Sym.TypeId) then
          Exit(True);
        if (Sym.TypeId > 0) and (Sym.TypeId <= FModel.TypeCount) then
        begin
          if SameText(FModel.TypeAt(Sym.TypeId - 1).Kind, 'interface') then
            Exit(True);
          if SameText(FModel.TypeAt(Sym.TypeId - 1).Kind, 'class') then
            Exit(True);
        end;
        Exit(False);
      end;
    gnkFunctionCall:
      begin
        SymId := FModel.LookupSymbol(ANode.Text, FCurrentScopeId);
        if SymId > 0 then
        begin
          Sym := FModel.SymbolAt(SymId - 1);
          Exit(SameText(Sym.Kind, 'function') and (Sym.ParamCount = 0) and
            (
              SameText(Sym.OwnerUnitId, RootOwnerUnitId) or
              (
                (CurrentOwnerUnitId <> '') and
                SameText(Sym.OwnerUnitId, CurrentOwnerUnitId) and
                OwnerUnitAllowsProjectSourceDiagnostic(Sym.OwnerUnitId)
              )
            ) and
            (ANode.ChildCount <= 1) and TypeIdHasStableScalarFact(Sym.TypeId));
        end;
        if (ANode.ChildCount > 0) and (ANode.ChildAt(0) <> nil) and
          (ANode.ChildAt(0).NodeKind = gnkDotAccess) then
          Exit(ExpressionTypeFactIsStable(ANode.ChildAt(0), CurrentOwnerUnitId));
        Exit(False);
      end;
    gnkBinaryExpression, gnkUnaryExpression:
      begin
        for Index := 0 to ANode.ChildCount - 1 do
          if not ExpressionTypeFactIsStable(
            ANode.ChildAt(Index),
            CurrentOwnerUnitId
          ) then
            Exit(False);
        Exit(True);
      end;
    gnkDotAccess:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if (ANode.ChildAt(0) = nil) or (ANode.ChildAt(1) = nil) then
          Exit(False);
        if ANode.ChildAt(0).NodeKind = gnkIdentifier then
        begin
          SymId := FModel.LookupSymbol(ANode.ChildAt(0).Text, FCurrentScopeId);
          if SymId <= 0 then
          begin
            if SameText(ANode.ChildAt(0).Text, 'Self') and
              (FCurrentMethodClass <> '') then
              Exit(True);
            Exit(False);
          end;
          Sym := FModel.SymbolAt(SymId - 1);
          if Sym.TypeId <= 0 then
            Exit(False);
          if TypeIdHasStableScalarFact(Sym.TypeId) then
            Exit(True);
          if SameText(FModel.TypeAt(Sym.TypeId - 1).Kind, 'interface') then
            Exit(True);
          if SameText(FModel.TypeAt(Sym.TypeId - 1).Kind, 'class') then
            Exit(True);
          Exit(False);
        end;
        Exit(ExpressionTypeFactIsStable(ANode.ChildAt(0), CurrentOwnerUnitId));
      end;
  end;
end;

function TSemanticAnalyzer.CallArgumentSignatureIsStable(
  const ACallNode: TGreenNode;
  const ACurrentOwnerUnitId: string
): Boolean;
var
  ArgRoot: TGreenNode;
  Index: LongInt;
begin
  Result := False;
  if ACallNode = nil then
    Exit;

  ArgRoot := ACallNode;
  if (ACallNode.NodeKind = gnkProcedureCallStatement) and
    (ACallNode.ChildCount > 0) and
    (ACallNode.ChildAt(0) <> nil) and
    (ACallNode.ChildAt(0).NodeKind = gnkFunctionCall) then
    ArgRoot := ACallNode.ChildAt(0);

  if ArgRoot.NodeKind <> gnkFunctionCall then
    Exit(True);

  for Index := 1 to ArgRoot.ChildCount - 1 do
    if not ExpressionTypeFactIsStable(
      ArgRoot.ChildAt(Index),
      ACurrentOwnerUnitId
    ) then
      Exit(False);
  Result := True;
end;

function TSemanticAnalyzer.CallArgumentCount(const ACallNode: TGreenNode): LongInt;
begin
  Result := np_sema_type_check.CallArgumentCount(ACallNode);
end;

function TSemanticAnalyzer.BareCallCalleeName(
  const ACallNode: TGreenNode
): string;
begin
  Result := np_sema_type_check.BareCallCalleeName(ACallNode);
end;

function TSemanticAnalyzer.IsIntrinsicExprName(const AName: string): Boolean;
begin
  Result := np_sema_type_check.IsIntrinsicExprName(AName);
end;

function TSemanticAnalyzer.TryGetTypeCastTargetTypeId(
  const ACallNode: TGreenNode;
  out ATargetTypeId: LongInt
): Boolean;
var
  CalleeNode: TGreenNode;
begin
  ATargetTypeId := 0;
  if (ACallNode = nil) or (ACallNode.NodeKind <> gnkFunctionCall) or
    (ACallNode.ChildCount <> 2) then
    Exit(False);

  CalleeNode := ACallNode.ChildAt(0);
  if (CalleeNode = nil) or (CalleeNode.NodeKind <> gnkIdentifier) or
    (Trim(CalleeNode.Text) = '') then
    Exit(False);

  ATargetTypeId := ResolveTypeIdForOwner(
    CalleeNode.Text,
    NormalizeUnitIdentity(FCurrentProcessingUnitId)
  );
  if ATargetTypeId <= 0 then
    ATargetTypeId := ResolveTypeIdForOwner(
      CalleeNode.Text,
      NormalizeUnitIdentity(FUnitGraph.RootName)
    );
  if ATargetTypeId <= 0 then
    ATargetTypeId := ResolveTypeId(CalleeNode.Text);
  Result := ATargetTypeId > 0;
end;

function TSemanticAnalyzer.TryGetIntrinsicExprName(
  const ACallNode: TGreenNode;
  out AName: string
): Boolean;
var
  CalleeNode: TGreenNode;
  DummyTypeId: LongInt;
begin
  AName := '';
  if (ACallNode = nil) or (ACallNode.NodeKind <> gnkFunctionCall) or
    (ACallNode.ChildCount < 1) then
    Exit(False);

  if TryGetTypeCastTargetTypeId(ACallNode, DummyTypeId) then
    Exit(False);

  CalleeNode := ACallNode.ChildAt(0);
  if (CalleeNode = nil) or (CalleeNode.NodeKind <> gnkIdentifier) then
    Exit(False);

  AName := CalleeNode.Text;
  Result := IsIntrinsicExprName(AName);
  if not Result then
    AName := '';
end;

function TSemanticAnalyzer.IsWrappedCallChild(
  const AParent: TGreenNode;
  const AChild: TGreenNode
): Boolean;
begin
  Result := np_sema_type_check.IsWrappedCallChild(AParent, AChild);
end;

function TSemanticAnalyzer.IsImplicitSelfCallNode(
  const ACallNode: TGreenNode
): Boolean;
begin
  Result := np_sema_type_check.IsImplicitSelfCallNode(ACallNode);
end;

function TSemanticAnalyzer.IsQualifiedCallNode(
  const ACallNode: TGreenNode
): Boolean;
begin
  Result := np_sema_type_check.IsQualifiedCallNode(ACallNode);
end;

function TSemanticAnalyzer.ExtractDirectMemberCall(
  const ACallNode: TGreenNode;
  out AReceiverName: string;
  out AMemberName: string;
  out AMemberOffset: LongInt;
  out AArgCount: LongInt
): Boolean;
begin
  Result := np_sema_type_check.ExtractDirectMemberCall(ACallNode, AReceiverName, AMemberName, AMemberOffset, AArgCount);
end;

function TSemanticAnalyzer.TypeIdForVariable(const AName: string): LongInt;
var
  Index: LongInt;
  Symbol: TSemanticSymbol;
begin
  Result := 0;
  if AName = '' then
    Exit;

  if FCurrentScopeId > 0 then
  begin
    Index := FModel.LookupSymbol(AName, FCurrentScopeId);
    if Index > 0 then
    begin
      Symbol := FModel.SymbolAt(Index - 1);
      if (SameText(Symbol.Kind, 'variable') or
        SameText(Symbol.Kind, 'parameter')) and
        (Symbol.TypeId > 0) and (Symbol.TypeId <= FModel.TypeCount) then
        Exit(Symbol.TypeId);
    end;
  end;

  for Index := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(Index);
    if SameText(Symbol.Name, AName) and
      (SameText(Symbol.Kind, 'variable') or
       SameText(Symbol.Kind, 'parameter')) and
      (Symbol.TypeId > 0) and (Symbol.TypeId <= FModel.TypeCount) then
      Exit(Symbol.TypeId);
  end;
end;

function TSemanticAnalyzer.TypeIdForMemberReceiver(
  const AName: string;
  const ACurrentMethodClass: string;
  const ACurrentOwnerUnitId: string
): LongInt;
begin
  Result := 0;
  if SameText(AName, 'Self') and (ACurrentMethodClass <> '') then
    Exit(ResolveTypeIdForOwner(
      ACurrentMethodClass,
      ACurrentOwnerUnitId
    ));

  Result := TypeIdForVariable(AName);
  if Result > 0 then
    Exit;
  if AName = '' then
    Exit;

  Result := ResolveTypeIdForOwner(
    AName,
    NormalizeUnitIdentity(FUnitGraph.RootName),
    False
  );
end;

function TSemanticAnalyzer.TryResolveTypeNameMemberCallTarget(
      const AReceiverName: string;
      const AMemberName: string;
      const AArgCount: LongInt;
      const AArgTypeIds: TTypeIdArray;
      const AArgSignature: string;
      const AHasArgSignature: Boolean;
      const AHasTypeMismatchEvidence: Boolean;
      out AReceiverTypeId: LongInt;
  out ATargetSymbolId: LongInt
): Boolean;
var
  CandidateResolutionFailure: string;
  CandidateTargetSymbolId: LongInt;
  CandidateTypeId: LongInt;
  Candidates: TOverloadCandidateArray;
  Index: LongInt;
  MatchCount: LongInt;
  SeenIndex: LongInt;
  SeenTypeIds: specialize TVec<LongInt>;
  Symbol: TSemanticSymbol;
  TypeAlreadySeen: Boolean;
begin
  Result := False;
  AReceiverTypeId := 0;
  ATargetSymbolId := 0;
  if (AReceiverName = '') or (AMemberName = '') then
    Exit;

  MatchCount := 0;
  SeenTypeIds := specialize TVec<LongInt>.Create;
  for Index := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(Index);
    if not SameText(Symbol.Kind, 'type') or
      not SameText(Symbol.Name, AReceiverName) or
      (Symbol.TypeId <= 0) or (Symbol.TypeId > FModel.TypeCount) then
      Continue;

    CandidateTypeId := Symbol.TypeId;
    TypeAlreadySeen := False;
    for SeenIndex := 0 to SeenTypeIds.Count - 1 do
      if SeenTypeIds[SeenIndex] = CandidateTypeId then
      begin
        TypeAlreadySeen := True;
        Break;
      end;
    if TypeAlreadySeen then
      Continue;

    SeenTypeIds.Push(CandidateTypeId);

    CandidateResolutionFailure := '';
    SetLength(Candidates, 0);
    CandidateTargetSymbolId := MethodSymbolIdForClassTypeMember(
      CandidateTypeId,
      AMemberName,
      AArgCount,
      AArgTypeIds,
      AArgSignature,
      AHasArgSignature,
      AHasTypeMismatchEvidence,
      CandidateResolutionFailure,
      Candidates
    );
    if CandidateTargetSymbolId <= 0 then
      Continue;

    Inc(MatchCount);
    if MatchCount > 1 then
      Exit(False);

    AReceiverTypeId := CandidateTypeId;
    ATargetSymbolId := CandidateTargetSymbolId;
  end;

  SeenTypeIds.Free;
  Result := MatchCount = 1;
end;

function TSemanticAnalyzer.TypeSymbolForTypeId(
  const ATypeId: LongInt;
  out ASymbol: TSemanticSymbol
): Boolean;
begin
  Result := np_sema_type_check.TypeSymbolForTypeId(FModel, ATypeId, ASymbol);
end;

function TSemanticAnalyzer.ClassTypeHasKnownNonMethodMember(
  const AClassTypeId: LongInt;
  const AMemberName: string
): Boolean;
var
  ConstValue: Int64;
  MemberPrefix: string;
  StringValue: string;
  TypeSymbol: TSemanticSymbol;
  FieldMeta: TFieldMeta;
begin
  Result := False;
  if (AClassTypeId <= 0) or (AMemberName = '') then
    Exit;
  if FModel.GetFieldMetaByName(AClassTypeId, AMemberName, FieldMeta) then
    Exit(True);
  if not TypeSymbolForTypeId(AClassTypeId, TypeSymbol) then
    Exit;
  MemberPrefix := TypeSymbol.Name + '.' + AMemberName;
  Result :=
    FModel.LookupConstValue(MemberPrefix + '$idx', ConstValue) or
    FModel.LookupStringConstValue(MemberPrefix + '$read', StringValue) or
    FModel.LookupStringConstValue(MemberPrefix + '$write', StringValue);
end;

function TSemanticAnalyzer.TypeIdHasKnownClassLayout(
  const ATypeId: LongInt
): Boolean;
begin
  Result := np_sema_type_check.TypeIdHasKnownClassLayout(FModel, ATypeId);
end;

function TSemanticAnalyzer.IsDeferredSystemObjectMember(
  const AMemberName: string
): Boolean;
begin
  Result := np_sema_type_check.IsDeferredSystemObjectMember(AMemberName);
end;

function TSemanticAnalyzer.TypeMetaSize(const ATypeName: string): Int64;
begin
  Result := np_sema_type_check.TypeMetaSize(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaIsRecord(const ATypeName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaIsRecord(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaIsClass(const ATypeName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaIsClass(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaIsInterface(const ATypeName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaIsInterface(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeIsInterfaceByName(const ATypeName: string): Boolean;
begin
  Result := np_sema_type_check.TypeIsInterfaceByName(FModel, ATypeName);
end;
