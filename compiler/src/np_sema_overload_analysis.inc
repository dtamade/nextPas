function TSemanticAnalyzer.MangledName(const AName: string;
  AParamCount: LongInt): string;
begin
  Result := nextpas.compiler.sema.overload.MangledName(AName, AParamCount);
end;

function TSemanticAnalyzer.MangledNameSig(const AName: string;
  const ASig: string): string;
begin
  Result := nextpas.compiler.sema.overload.MangledNameSig(AName, ASig);
end;

function TSemanticAnalyzer.EffectiveRuntimeCalleeName(const AName: string;
  const ADecl: TGreenNode; const AArgCount: LongInt): string;
var
  BodyNode, DeclNode: TGreenNode;
  Sig, DeclBare: string;
  I, BodyIndex: LongInt;
  Binding: TSemanticForeignProcedureBinding;

begin
  Result := AName;
  if AName = '' then
    Exit;
  { libc/Win32 externals must stay bare (declare @getenv), never getenv$s. }
  for I := 0 to FModel.ForeignProcedureBindingCount - 1 do
  begin
    Binding := FModel.ForeignProcedureBindingAt(I);
    if SameText(Binding.PascalName, AName) then
    begin
      if Binding.ExternalSymbolName <> '' then
        Exit(Binding.ExternalSymbolName);
      Exit(AName);
    end;
  end;
  { Arity-aware overload pick: SeedFunctionBodies mangles each overload by
    its own signature, so a call site passing N raw operands must target the
    overload whose decl accepts N. First-body pick emitted mismatched-shape
    calls (atomic_compare_exchange_strong_64 5-arg sites hit the $iii
    3-param define; opt -O2 turned them into noreturn cascades — v2.27/D25).
    No arity match → legacy path below (emitter signature check catches it). }
  if (AArgCount >= 0) and HasOverload(AName) then
  begin
    BodyIndex := FirstBodyIndexForName(FProcedureBodies, AName);
    while BodyIndex >= 0 do
    begin
      if (FProcedureBodies[BodyIndex].Decl <> nil) and
        DeclAcceptsArgCount(FProcedureBodies[BodyIndex].Decl, AArgCount) then
      begin
        Sig := GetParamSignature(FProcedureBodies[BodyIndex].Decl);
        Exit(MangledNameSig(AName, Sig));
      end;
      BodyIndex := NextBodyIndexForName(FProcedureBodies, AName, BodyIndex);
    end;
  end;
  DeclNode := ADecl;
  { Stale Decl from a prior Lookup in the same encode walk must not mangle a
    different callee (classic getenv → getenv$s via leftover string-param decl). }
  if DeclNode <> nil then
  begin
    DeclBare := DeclNode.Text;
    if Pos(';', DeclBare) > 0 then
      DeclBare := Copy(DeclBare, 1, Pos(';', DeclBare) - 1);
    if (DeclBare <> '') and (not SameText(DeclBare, AName)) and
      (Pos('.', AName) = 0) then
      DeclNode := nil;
  end;
  if DeclNode = nil then
  begin
    if not LookupProcedureBody(AName, BodyNode, DeclNode) then
      Exit;
  end;
  if not HasOverload(AName) then
    Exit;
  if DeclNode = nil then
    Exit;
  Sig := GetParamSignature(DeclNode);
  if Sig = '' then
    Exit;
  Result := MangledNameSig(AName, Sig);
end;

function TSemanticAnalyzer.TryRegisterForeignProcedureBinding(
  const AText: string; const ASymbolId: LongInt): Boolean;
var
  CleanName, ExtRest, ExtLib, ExtSym: string;
  ExtPos, ColonPos, I: LongInt;
  Binding: TSemanticForeignProcedureBinding;
begin
  Result := False;
  ExtPos := Pos(';external:', AText);
  if ExtPos <= 0 then
    Exit;
  CleanName := AText;
  if Pos(';', CleanName) > 0 then
    CleanName := Copy(CleanName, 1, Pos(';', CleanName) - 1);
  ExtRest := Copy(AText, ExtPos + Length(';external:'), MaxInt);
  if Pos(';', ExtRest) > 0 then
    ExtRest := Copy(ExtRest, 1, Pos(';', ExtRest) - 1);
  ColonPos := Pos(':', ExtRest);
  if ColonPos > 0 then
  begin
    ExtLib := Copy(ExtRest, 1, ColonPos - 1);
    ExtSym := Copy(ExtRest, ColonPos + 1, MaxInt);
  end
  else
  begin
    ExtLib := ExtRest;
    ExtSym := CleanName;
  end;
  if ExtSym = '' then
    ExtSym := CleanName;
  for I := 0 to FModel.ForeignProcedureBindingCount - 1 do
  begin
    Binding := FModel.ForeignProcedureBindingAt(I);
    if SameText(Binding.PascalName, CleanName) then
      Exit(False);
  end;
  FModel.AddForeignProcedureBinding(
    CleanName, 'cdecl', ExtLib, ExtSym, ASymbolId);
  FModel.AddTypedHirNode(
    'foreign-procedure-binding', CleanName, ASymbolId, 0, ExtSym);
  if ExtLib <> '' then
    FModel.AddLibraryRequest(ExtLib, 'shared', 'strong');
  Result := True;
end;

procedure TSemanticAnalyzer.RegisterProcedureBody(const AName: string;
  const ABody: TGreenNode; const ADecl: TGreenNode;
  const AOwnerUnitId: string);
var
  Index: LongInt;
  Sig, ExistingSig, CleanName, ExtRest, ExtLib, ExtSym: string;
  Entry: TProcedureBodyEntry;
  ExtPos, ColonPos, SymbolId: LongInt;
begin
  CleanName := AName;
  if Pos(';', AName) > 0 then
  begin
    CleanName := Copy(AName, 1, Pos(';', AName) - 1);
    if Pos(';compilerproc', AName) > 0 then
      FCompilerProcNames.Push(CleanName);
    { function getenv(...); cdecl; external 'c' name 'getenv'
      → Text "getenv;…;external:c:getenv". Bare name + foreign binding. }
    ExtPos := Pos(';external:', AName);
    if ExtPos > 0 then
    begin
      ExtRest := Copy(AName, ExtPos + Length(';external:'), MaxInt);
      if Pos(';', ExtRest) > 0 then
        ExtRest := Copy(ExtRest, 1, Pos(';', ExtRest) - 1);
      ColonPos := Pos(':', ExtRest);
      if ColonPos > 0 then
      begin
        ExtLib := Copy(ExtRest, 1, ColonPos - 1);
        ExtSym := Copy(ExtRest, ColonPos + 1, MaxInt);
      end
      else
      begin
        ExtLib := ExtRest;
        ExtSym := CleanName;
      end;
      if ExtSym = '' then
        ExtSym := CleanName;
      SymbolId := FModel.FindSymbolByName(CleanName);
      FModel.AddForeignProcedureBinding(
        CleanName, 'cdecl', ExtLib, ExtSym, SymbolId);
      FModel.AddTypedHirNode(
        'foreign-procedure-binding', CleanName, SymbolId, 0, ExtSym);
      if ExtLib <> '' then
        FModel.AddLibraryRequest(ExtLib, 'shared', 'strong');
    end;
  end;
  Sig := GetParamIdentitySignature(ADecl);
  Index := FirstBodyIndexForNameLocal(CleanName);
  while Index >= 0 do
  begin
    if SameText(FProcedureBodies[Index].OwnerUnitId, AOwnerUnitId) then
    begin
      ExistingSig := GetParamIdentitySignature(FProcedureBodies[Index].Decl);
      if ExistingSig = Sig then
      begin
        Entry := FProcedureBodies[Index];
        Entry.Body := ABody;
        Entry.Decl := ADecl;
        Entry.OwnerUnitId := AOwnerUnitId;
        Entry.ScopeId := FCurrentScopeId;
        { Mid-seed body update: re-encode only if already reachable. }
        if (ABody <> nil) and Entry.Needed then
        begin
          Entry.Encoded := False;
          Entry.Queued := False;
        end;
        FProcedureBodies[Index] := Entry;
        Exit;
      end;
    end;
    Index := NextBodyIndexForNameLocal(Index);
  end;
  Entry.Name := CleanName;
  Entry.Body := ABody;
  Entry.Decl := ADecl;
  Entry.OwnerUnitId := AOwnerUnitId;
  Entry.ScopeId := FCurrentScopeId;
  { Reachability seed: default not Needed; Collect/Mark pull reachable set. }
  Entry.Needed := False;
  Entry.Encoded := False;
  Entry.Queued := False;
  FProcedureBodies.Push(Entry);
  IndexProcedureBodyName(CleanName, LongInt(FProcedureBodies.Count) - 1);
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
  if DeclName <> '' then
  begin
    { Prefer name-index + pointer match (O(overloads)), not O(all bodies). }
    Index := FirstBodyIndexForNameLocal(DeclName);
    while Index >= 0 do
    begin
      if FProcedureBodies[Index].Decl = ADecl then
        Exit(FProcedureBodies[Index].ScopeId);
      Index := NextBodyIndexForNameLocal(Index);
    end;
    { Fallback: unique name when pointer identity failed (shared body entries). }
    NameMatchCount := 0;
    NameMatchScopeId := 0;
    Index := FirstBodyIndexForNameLocal(DeclName);
    while Index >= 0 do
    begin
      Inc(NameMatchCount);
      NameMatchScopeId := FProcedureBodies[Index].ScopeId;
      Index := NextBodyIndexForNameLocal(Index);
    end;
    if NameMatchCount = 1 then
      Result := NameMatchScopeId;
    Exit;
  end;
  for Index := 0 to LongInt(FProcedureBodies.Count) - 1 do
    if FProcedureBodies[Index].Decl = ADecl then
      Exit(FProcedureBodies[Index].ScopeId);
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
  Result := nextpas.compiler.sema.overload.ParamDeclTypeId(Ctx, AParamDecl, AOwnerUnitId);
end;

function TSemanticAnalyzer.LookupProcedureBody(const AName: string;
  out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
var
  Index, DotPos, J: LongInt;
  OwnerName, MemberName, Resolved: string;
begin
  ABody := nil;
  ADecl := nil;
  Index := FirstBodyIndexForNameLocal(AName);
  if Index < 0 then
  begin
    { Empty subclass / alias: Class.Create → $resolve_Create body. }
    DotPos := 0;
    for J := Length(AName) downto 1 do
      if AName[J] = '.' then
      begin
        DotPos := J;
        Break;
      end;
    if DotPos > 1 then
    begin
      OwnerName := Copy(AName, 1, DotPos - 1);
      MemberName := Copy(AName, DotPos + 1, MaxInt);
      if FModel.LookupStringConstValue(OwnerName + '.$resolve_' + MemberName,
        Resolved) and (Resolved <> '') and (not SameText(Resolved, AName)) then
        Index := FirstBodyIndexForNameLocal(Resolved);
      if (Index < 0) and SameText(MemberName, 'CreateFmt') then
      begin
        if FModel.LookupStringConstValue(OwnerName + '.$resolve_Create',
          Resolved) and (Resolved <> '') then
          Index := FirstBodyIndexForNameLocal(Resolved);
      end;
    end;
  end;
  if Index >= 0 then
  begin
    ABody := FProcedureBodies[Index].Body;
    ADecl := FProcedureBodies[Index].Decl;
    Exit(True);
  end;
  Result := False;
end;

procedure TSemanticAnalyzer.FoldBodyNameIntoScratch(const AName: string);
begin
  FoldAsciiInto(FBodyLookupScratch, AName);
end;

function TSemanticAnalyzer.FirstBodyIndexForNameLocal(const AName: string): LongInt;
begin
  Result := -1;
  if (AName = '') or (FProcedureBodyNameFirst = nil) then
    Exit;
  FoldBodyNameIntoScratch(AName);
  if not FProcedureBodyNameFirst.TryGetValue(FBodyLookupScratch, Result) then
    Result := -1;
end;

function TSemanticAnalyzer.NextBodyIndexForNameLocal(const APrevIndex: LongInt): LongInt;
begin
  Result := -1;
  if (APrevIndex < 0) or (FProcedureBodyNameNext = nil) then
    Exit;
  if APrevIndex >= LongInt(FProcedureBodyNameNext.Count) then
    Exit;
  Result := FProcedureBodyNameNext[APrevIndex];
end;

procedure TSemanticAnalyzer.IndexProcedureBodyName(const AName: string;
  const AIndex: LongInt);
var
  Key: string;
  Head, Prev: LongInt;
begin
  if (AName = '') or (AIndex < 0) or (FProcedureBodyNameFirst = nil) or
    (FProcedureBodyNameNext = nil) then
    Exit;
  while LongInt(FProcedureBodyNameNext.Count) <= AIndex do
    FProcedureBodyNameNext.Push(-1);
  FProcedureBodyNameNext[AIndex] := -1;
  Key := LowerCase(AName);
  if FProcedureBodyNameFirst.TryGetValue(Key, Head) then
  begin
    { Append to preserve registration order (first overload wins lookup). }
    Prev := Head;
    while (Prev >= 0) and (Prev < LongInt(FProcedureBodyNameNext.Count)) and
      (FProcedureBodyNameNext[Prev] >= 0) do
      Prev := FProcedureBodyNameNext[Prev];
    if (Prev >= 0) and (Prev < LongInt(FProcedureBodyNameNext.Count)) then
      FProcedureBodyNameNext[Prev] := AIndex;
  end
  else
    FProcedureBodyNameFirst.Put(Key, AIndex);
end;

function TSemanticAnalyzer.HasOverload(const AName: string): Boolean;
var
  Index, Count: LongInt;
begin
  Count := 0;
  Index := FirstBodyIndexForNameLocal(AName);
  while Index >= 0 do
  begin
    Inc(Count);
    if Count > 1 then
      Exit(True);
    Index := NextBodyIndexForNameLocal(Index);
  end;
  Result := False;
end;

function TSemanticAnalyzer.LookupOverload(const AName: string;
  AArgCount: LongInt; out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
var
  Index: LongInt;
begin
  ABody := nil;
  ADecl := nil;
  Index := FirstBodyIndexForNameLocal(AName);
  while Index >= 0 do
  begin
    if DeclAcceptsArgCount(FProcedureBodies[Index].Decl, AArgCount) then
    begin
      ABody := FProcedureBodies[Index].Body;
      ADecl := FProcedureBodies[Index].Decl;
      Exit(True);
    end;
    Index := NextBodyIndexForNameLocal(Index);
  end;
  Result := False;
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
  Ctx.BodyNameFirst := FProcedureBodyNameFirst;
  Ctx.BodyNameNext := FProcedureBodyNameNext;
  Ctx.BodyLookupScratch := @FBodyLookupScratch;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := nextpas.compiler.sema.overload.LookupCallBindingDeclaration(
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
  Result := nextpas.compiler.sema.overload.OwnerUnitAllowsProjectSourceDiagnostic(Ctx, AOwnerUnitId);
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
  Result := nextpas.compiler.sema.overload.UnitDirectlyImports(Ctx, AOwnerUnitId, AImportedUnitId);
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
  Result := nextpas.compiler.sema.type_check.CallArgumentCount(ACallNode);
end;

function TSemanticAnalyzer.BareCallCalleeName(
  const ACallNode: TGreenNode
): string;
begin
  Result := nextpas.compiler.sema.type_check.BareCallCalleeName(ACallNode);
end;

function TSemanticAnalyzer.IsIntrinsicExprName(const AName: string): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.IsIntrinsicExprName(AName);
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

{ b4b-i7: resolve `specialize X<T>.M` — generic class method call at a
  runtime call site. Template params resolve through the current generic
  instance map ($generic_arg_<name>); the instance type is materialized on
  demand so its whitelist clones enter the seed queue, then the callee name
  lands on X<args>.M. Nested generic args (TArray<T> as an arg) keep their
  template tokens — only a direct template-param arg is substituted here.
  The walk's older specialize branch only handled the compile-time
  free-function form `specialize X<T>` and dropped the method part, leaving
  cloned Create bodies truncated at `FElementManager := specialize
  TElementManager<T>.Create(...)` (b4b-i7). }
function TSemanticAnalyzer.ResolveSpecializedClassMethodCall(
  const ACallee: string): string;
var
  LtPos, GtPos, I, J, K, GenericTypeId: LongInt;
  GenericName, MethodPart, ArgsText, ArgName, Subst, InstanceName: string;
begin
  Result := '';
  LtPos := Pos('<', ACallee);
  if LtPos <= 0 then
    Exit;
  GtPos := Length(ACallee);
  while (GtPos > LtPos) and (ACallee[GtPos] <> '>') do
    Dec(GtPos);
  if (GtPos <= LtPos) or (GtPos + 2 > Length(ACallee)) or
    (ACallee[GtPos + 1] <> '.') then
    Exit; { free-function form, handled by the walk's older branch }
  GenericName := Copy(ACallee, 1, LtPos - 1);
  ArgsText := Copy(ACallee, LtPos + 1, GtPos - LtPos - 1);
  MethodPart := Copy(ACallee, GtPos + 2, MaxInt);
  InstanceName := GenericName + '<';
  I := 1;
  while I <= Length(ArgsText) do
  begin
    while (I <= Length(ArgsText)) and (ArgsText[I] = ' ') do
      Inc(I);
    J := I;
    while (J <= Length(ArgsText)) and (ArgsText[J] <> ',') do
      Inc(J);
    ArgName := Copy(ArgsText, I, J - I);
    while (Length(ArgName) > 0) and (ArgName[Length(ArgName)] = ' ') do
      Delete(ArgName, Length(ArgName), 1);
    Subst := ArgName;
    if (FCurrentGenericInstance <> '') and
      FModel.LookupStringConstValue(
        FCurrentGenericInstance + '.$generic_arg_' + ArgName, Subst) then
      { template param -> concrete generic arg }
    else
      Subst := ArgName;
    InstanceName := InstanceName + Subst;
    if (J <= Length(ArgsText)) and (ArgsText[J] = ',') then
      InstanceName := InstanceName + ',';
    I := J + 1;
  end;
  InstanceName := InstanceName + '>';
  if FModel.FindTypeByName(InstanceName) <= 0 then
  begin
    GenericTypeId := 0;
    for K := 0 to FModel.TypeCount - 1 do
      if SameText(FModel.TypeAt(K).Name, GenericName) then
      begin
        GenericTypeId := FModel.TypeAt(K).TypeId;
        Break;
      end;
    if GenericTypeId > 0 then
      ResolveOrInstantiateInlineGeneric(InstanceName,
        FModel.TypeAt(GenericTypeId - 1).OwnerUnitId)
    else
      ResolveOrInstantiateInlineGeneric(InstanceName, '');
    if FModel.FindTypeByName(InstanceName) <= 0 then
      Exit;
  end;
  Result := ResolveClassMethodCalleeName(InstanceName, MethodPart);
  if Result = '' then
    Result := InstanceName + '.' + MethodPart;
end;

function TSemanticAnalyzer.IsWrappedCallChild(
  const AParent: TGreenNode;
  const AChild: TGreenNode
): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.IsWrappedCallChild(AParent, AChild);
end;

function TSemanticAnalyzer.IsImplicitSelfCallNode(
  const ACallNode: TGreenNode
): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.IsImplicitSelfCallNode(ACallNode);
end;

function TSemanticAnalyzer.IsQualifiedCallNode(
  const ACallNode: TGreenNode
): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.IsQualifiedCallNode(ACallNode);
end;

function TSemanticAnalyzer.ExtractDirectMemberCall(
  const ACallNode: TGreenNode;
  out AReceiverName: string;
  out AMemberName: string;
  out AMemberOffset: LongInt;
  out AArgCount: LongInt
): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.ExtractDirectMemberCall(ACallNode, AReceiverName, AMemberName, AMemberOffset, AArgCount);
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

  { Name-chain O(overloads), not O(all symbols). }
  Index := FModel.FirstSymbolIdByName(AName);
  while Index > 0 do
  begin
    Symbol := FModel.SymbolAt(Index - 1);
    if SameText(Symbol.Name, AName) and
      (SameText(Symbol.Kind, 'variable') or
       SameText(Symbol.Kind, 'parameter')) and
      (Symbol.TypeId > 0) and (Symbol.TypeId <= FModel.TypeCount) then
      Exit(Symbol.TypeId);
    Index := FModel.NextSymbolIdSameName(Index);
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
  { Name-chain of type symbols for AReceiverName, not full symbol table. }
  Index := FModel.FirstSymbolIdByName(AReceiverName);
  while Index > 0 do
  begin
    Symbol := FModel.SymbolAt(Index - 1);
    if not SameText(Symbol.Kind, 'type') or
      not SameText(Symbol.Name, AReceiverName) or
      (Symbol.TypeId <= 0) or (Symbol.TypeId > FModel.TypeCount) then
    begin
      Index := FModel.NextSymbolIdSameName(Index);
      Continue;
    end;

    CandidateTypeId := Symbol.TypeId;
    TypeAlreadySeen := False;
    for SeenIndex := 0 to SeenTypeIds.Count - 1 do
      if SeenTypeIds[SeenIndex] = CandidateTypeId then
      begin
        TypeAlreadySeen := True;
        Break;
      end;
    if TypeAlreadySeen then
    begin
      Index := FModel.NextSymbolIdSameName(Index);
      Continue;
    end;

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
    begin
      Index := FModel.NextSymbolIdSameName(Index);
      Continue;
    end;

    Inc(MatchCount);
    if MatchCount > 1 then
    begin
      SeenTypeIds.Free;
      Exit(False);
    end;

    AReceiverTypeId := CandidateTypeId;
    ATargetSymbolId := CandidateTargetSymbolId;
    Index := FModel.NextSymbolIdSameName(Index);
  end;

  SeenTypeIds.Free;
  Result := MatchCount = 1;
end;

function TSemanticAnalyzer.TypeSymbolForTypeId(
  const ATypeId: LongInt;
  out ASymbol: TSemanticSymbol
): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.TypeSymbolForTypeId(FModel, ATypeId, ASymbol);
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
  Result := nextpas.compiler.sema.type_check.TypeIdHasKnownClassLayout(FModel, ATypeId);
end;

function TSemanticAnalyzer.IsDeferredSystemObjectMember(
  const AMemberName: string
): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.IsDeferredSystemObjectMember(AMemberName);
end;

function TSemanticAnalyzer.TypeMetaSize(const ATypeName: string): Int64;
var
  ArgName: string;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaSize(FModel, ATypeName);
  { B4b 缺口乙: cloned generic instance bodies reference template type
    params (T) in field/pointer types. Resolve through the instance's
    T→实参 mapping stored by InstantiateGenericType, only when the raw
    lookup misses (a template param name, not a concrete type). }
  if (Result <= 0) and (FCurrentGenericInstance <> '') and
    FModel.LookupStringConstValue(
      FCurrentGenericInstance + '.$generic_arg_' + ATypeName, ArgName) then
    Result := TypeMetaSize(ArgName);
end;

function TSemanticAnalyzer.TypeMetaIsDynArrayType(const ATypeName: string): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaIsDynArrayType(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaIsRecord(const ATypeName: string): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaIsRecord(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaIsPointer(const ATypeName: string): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaIsPointer(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaIsClass(const ATypeName: string): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaIsClass(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaIsInterface(const ATypeName: string): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaIsInterface(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeIsInterfaceByName(const ATypeName: string): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.TypeIsInterfaceByName(FModel, ATypeName);
end;
