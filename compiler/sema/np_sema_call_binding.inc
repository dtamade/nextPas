  QualifiedName := TypeSymbol.Name + '.' + AMemberName;
  HasArgTypeIds := (Length(AArgTypeIds) = AArgCount) and
    TypeIdArrayHasKnownTypes(AArgTypeIds);
  SymbolId := 0;
  SignatureSymbolId := 0;
  SymbolMatchCount := 0;
  SignatureMatchCount := 0;
  SetLength(ACandidates, 0);
  BodyCandidateCount := 0;
  BodyCompatibleMatchCount := 0;
  BodyCompatibleMatchIndex := -1;
  BodyExactMatchCount := 0;
  BodyExactMatchIndex := -1;
  BodyMatchCount := 0;

  { Body name-index first (O(overloads)). L3 SeedCallBindings hits this path
    for every member call; scanning all ~19k symbols first was the hang. }
  Index := FirstBodyIndexForNameLocal(QualifiedName);
  while Index >= 0 do
  begin
    if SameText(FProcedureBodies[Index].OwnerUnitId, TypeSymbol.OwnerUnitId) then
    begin
      AMethodNameFound := True;
      Inc(BodyCandidateCount);
      if DeclAcceptsArgCount(FProcedureBodies[Index].Decl, AArgCount) then
      begin
        if HasArgTypeIds and DeclParamTypesExactMatch(
          FProcedureBodies[Index].Decl,
          TypeSymbol.OwnerUnitId,
          AArgTypeIds,
          AArgCount
        ) then
        begin
          BodyExactMatchIndex := Index;
          Inc(BodyExactMatchCount);
        end
        else if HasArgTypeIds and DeclParamTypesCompatibleMatch(
          FProcedureBodies[Index].Decl,
          TypeSymbol.OwnerUnitId,
          AArgTypeIds,
          AArgCount
        ) then
        begin
          BodyCompatibleMatchIndex := Index;
          Inc(BodyCompatibleMatchCount);
        end;
        if (not AHasArgSignature) or
          SameText(GetParamSignature(FProcedureBodies[Index].Decl), AArgSignature) then
          Inc(BodyMatchCount);
      end;
    end;
    Index := NextBodyIndexForNameLocal(Index);
  end;
  { Prefer the class-declaration symbol (method/constructor/destructor) over
    the routine-body stub when both exist for QualifiedName: call bindings
    must target the declaration carrying TypeId/param metadata; the body
    symbol is an implementation stub (TypeId=0, ParamCount=-1). Signature-
    matched against AArgSignature so same-arity overloads stay disambiguated;
    ambiguous (>1) or signature-less cases keep the body-path result.
    Name-index walk only (O(overloads)) — never the full symbol table. }
  if (BodyExactMatchCount > 0) or (BodyCompatibleMatchCount > 0) then
  begin
    DeclSymbolId := FModel.FirstSymbolIdByName(QualifiedName);
    while DeclSymbolId > 0 do
    begin
      Symbol := FModel.SymbolAt(DeclSymbolId - 1);
      if SameText(Symbol.Kind, 'method') or
        SameText(Symbol.Kind, 'constructor') or
        SameText(Symbol.Kind, 'destructor') then
      begin
        AMethodNameFound := True;
        if ((AArgCount >= Symbol.MinParamCount) and
            (AArgCount <= Symbol.ParamCount)) and
           ((not AHasArgSignature) or
            ((Symbol.ParamSignature <> '') and
             SameText(Symbol.ParamSignature, AArgSignature))) then
        begin
          Inc(DeclCandidateCount);
          DeclCandidateId := DeclSymbolId;
        end;
      end;
      DeclSymbolId := FModel.NextSymbolIdSameName(DeclSymbolId);
    end;
    if DeclCandidateCount = 1 then
      Exit(DeclCandidateId);
    DeclCandidateCount := 0;
    DeclCandidateId := 0;
  end;
  if HasArgTypeIds and
    ((BodyExactMatchCount > 0) or (BodyCompatibleMatchCount > 0)) then
  begin
    { C8/M2 permissive: identical multi-body exact/compatible → last index. }
    if BodyExactMatchCount >= 1 then
      Exit(CallableSymbolIdForDeclaration(
        FProcedureBodies[BodyExactMatchIndex].Decl,
        TypeSymbol.OwnerUnitId
      ));
    if BodyCompatibleMatchCount >= 1 then
      Exit(CallableSymbolIdForDeclaration(
        FProcedureBodies[BodyCompatibleMatchIndex].Decl,
        TypeSymbol.OwnerUnitId
      ));
  end;
  { Arg types unknown: still bind unique body by arity (common in SeedCallBindings). }
  if BodyMatchCount = 1 then
  begin
    Index := FirstBodyIndexForNameLocal(QualifiedName);
    while Index >= 0 do
    begin
      if SameText(FProcedureBodies[Index].OwnerUnitId, TypeSymbol.OwnerUnitId) and
        DeclAcceptsArgCount(FProcedureBodies[Index].Decl, AArgCount) and
        ((not AHasArgSignature) or
          SameText(GetParamSignature(FProcedureBodies[Index].Decl), AArgSignature)) then
        Exit(CallableSymbolIdForDeclaration(
          FProcedureBodies[Index].Decl, TypeSymbol.OwnerUnitId));
      Index := NextBodyIndexForNameLocal(Index);
    end;
  end;

  { Create/Destroy-style members: body miss → O(1) name index, not full table. }
  if SameText(AMemberName, 'Create') or SameText(AMemberName, 'Destroy') or
    SameText(AMemberName, 'CreateFmt') or SameText(AMemberName, 'CreateRes') or
    SameText(AMemberName, 'Equal') then
  begin
    if BodyMatchCount = 1 then
    begin
      { Single argcount-accepting body already found above. }
      Index := FirstBodyIndexForNameLocal(QualifiedName);
      while Index >= 0 do
      begin
        if SameText(FProcedureBodies[Index].OwnerUnitId, TypeSymbol.OwnerUnitId) and
          DeclAcceptsArgCount(FProcedureBodies[Index].Decl, AArgCount) then
          Exit(CallableSymbolIdForDeclaration(
            FProcedureBodies[Index].Decl, TypeSymbol.OwnerUnitId));
        Index := NextBodyIndexForNameLocal(Index);
      end;
    end;
    SymbolId := FModel.FindSymbolByName(QualifiedName);
    if SymbolId > 0 then
    begin
      Symbol := FModel.SymbolAt(SymbolId - 1);
      if SameText(Symbol.Kind, 'constructor') or
        SameText(Symbol.Kind, 'destructor') or
        SameText(Symbol.Kind, 'method') then
      begin
        AMethodNameFound := True;
        if (AArgCount >= Symbol.MinParamCount) and
          (AArgCount <= Symbol.ParamCount) then
          Exit(SymbolId);
      end;
    end;
    Exit;
  end;

  { Symbol table only when body path did not uniquely resolve.
    Walk name-chain O(overloads), not O(all ~19k symbols). }
  SymbolId := 0;
  SignatureSymbolId := 0;
  SymbolMatchCount := 0;
  SignatureMatchCount := 0;
  Index := FModel.FirstSymbolIdByName(QualifiedName);
  while Index > 0 do
  begin
    Symbol := FModel.SymbolAt(Index - 1);
    if SameText(Symbol.Name, QualifiedName) and
      (SameText(Symbol.Kind, 'method') or
       SameText(Symbol.Kind, 'constructor') or
       SameText(Symbol.Kind, 'destructor')) then
    begin
      AMethodNameFound := True;
      SetLength(ACandidates, Length(ACandidates) + 1);
      ACandidates[High(ACandidates)].Name := Symbol.Name;
      ACandidates[High(ACandidates)].ParamCount := Symbol.ParamCount;
      ACandidates[High(ACandidates)].ParamSignature := Symbol.ParamSignature;
      ACandidates[High(ACandidates)].DeclByteOffset := Symbol.ByteOffset;
      if (AArgCount < Symbol.MinParamCount) or (AArgCount > Symbol.ParamCount) then
        ACandidates[High(ACandidates)].MismatchReason := 'param-count'
      else if AHasArgSignature and
        (not SameText(Copy(Symbol.ParamSignature, 1, Length(AArgSignature)), AArgSignature)) then
        ACandidates[High(ACandidates)].MismatchReason := 'type-mismatch'
      else
        ACandidates[High(ACandidates)].MismatchReason := '';
      if (AArgCount >= Symbol.MinParamCount) and (AArgCount <= Symbol.ParamCount) then
      begin
        Inc(SymbolMatchCount);
        SymbolId := Symbol.SymbolId;
        if (Symbol.ParamSignature = '') or
          (AHasArgSignature and
           SameText(Copy(Symbol.ParamSignature, 1, Length(AArgSignature)), AArgSignature)) then
        begin
          Inc(SignatureMatchCount);
          SignatureSymbolId := Symbol.SymbolId;
        end;
      end;
    end;
    Index := FModel.NextSymbolIdSameName(Index);
  end;
  if SymbolMatchCount = 0 then
  begin
    if AMethodNameFound and (
      SameText(
        TypeSymbol.OwnerUnitId,
        NormalizeUnitIdentity(FUnitGraph.RootName)
      ) or OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)
    ) then
      AResolutionFailureKind := 'wrong-argument-count';
    Exit;
  end;
  if AHasTypeMismatchEvidence and
    (SymbolMatchCount = 1) and AHasArgSignature and
    (SignatureMatchCount = 0) then
  begin
    if SameText(
      TypeSymbol.OwnerUnitId,
      NormalizeUnitIdentity(FUnitGraph.RootName)
    ) or OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId) then
    begin
      AResolutionFailureKind := 'type-mismatch';
      Exit;
    end;
  end;
  if SymbolMatchCount > 1 then
  begin
    if AHasArgSignature and (SignatureMatchCount = 1) then
      SymbolId := SignatureSymbolId
    else if AHasArgSignature and (SignatureMatchCount > 1) then
    begin
      // Multiple symbols with matching signature — prefer the one from
      // the same owner unit as the receiver type. If exactly one matches
      // the owner unit, use it (local definition wins over imported
      // duplicate). If more than one matches the same owner unit, it is
      // a genuine ambiguous overload within the same unit.
      SameOwnerCount := 0;
      SameOwnerSymbolId := 0;
      Index := FModel.FirstSymbolIdByName(QualifiedName);
      while Index > 0 do
      begin
        Symbol := FModel.SymbolAt(Index - 1);
        if SameText(Symbol.Name, QualifiedName) and
          (SameText(Symbol.Kind, 'method') or
           SameText(Symbol.Kind, 'constructor') or
           SameText(Symbol.Kind, 'destructor')) and
          (AArgCount >= Symbol.MinParamCount) and
          (AArgCount <= Symbol.ParamCount) and
          AHasArgSignature and
          SameText(Copy(Symbol.ParamSignature, 1, Length(AArgSignature)), AArgSignature) and
          SameText(Symbol.OwnerUnitId, TypeSymbol.OwnerUnitId) then
        begin
          Inc(SameOwnerCount);
          if SameOwnerSymbolId = 0 then
            SameOwnerSymbolId := Symbol.SymbolId;
        end;
        Index := FModel.NextSymbolIdSameName(Index);
      end;
      if SameOwnerCount = 1 then
        SymbolId := SameOwnerSymbolId
      else
      begin
        AResolutionFailureKind := 'ambiguous-overload';
        SymbolId := 0;
      end;
    end
    else if not AHasArgSignature then
    begin
        BestDist := MaxInt;
        BestSymbolId := 0;
        Index := FModel.FirstSymbolIdByName(QualifiedName);
        while Index > 0 do
        begin
          Symbol := FModel.SymbolAt(Index - 1);
          if SameText(Symbol.Name, QualifiedName) and
            (SameText(Symbol.Kind, 'method') or
             SameText(Symbol.Kind, 'constructor') or
             SameText(Symbol.Kind, 'destructor')) and
            (AArgCount >= Symbol.MinParamCount) and
            (AArgCount <= Symbol.ParamCount) then
          begin
            Dist := Symbol.ParamCount - AArgCount;
            if Dist < 0 then Dist := -Dist;
            if (Dist < BestDist) or
              ((Dist = BestDist) and (BestSymbolId = 0)) then
            begin
              BestDist := Dist;
              BestSymbolId := Symbol.SymbolId;
            end;
          end;
          Index := FModel.NextSymbolIdSameName(Index);
        end;
        if BestSymbolId > 0 then
        begin
          SymbolId := BestSymbolId;
          // Continue to body check below
        end
        else
        begin
          if SameText(
            TypeSymbol.OwnerUnitId,
            NormalizeUnitIdentity(FUnitGraph.RootName)
          ) or OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId) then
            AResolutionFailureKind := 'ambiguous-overload';
          Exit;
        end;
      end
    else if SignatureMatchCount = 0 then
    begin
      if AAllowNoMatchingOverloadDiagnostic and AHasTypeMismatchEvidence and
        (
          SameText(TypeSymbol.OwnerUnitId, NormalizeUnitIdentity(FUnitGraph.RootName)) or
          OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)
        ) then
        AResolutionFailureKind := 'no-matching-overload';
      Exit;
    end
    else
    begin
      if BestSymbolId > 0 then
      begin
        AResolutionFailureKind := 'ambiguous-overload';
        SymbolId := 0;
      end;
      Exit;
    end;
  end;
  if SymbolId <= 0 then
    Exit;

  if BodyCandidateCount = 0 then
    Exit(SymbolId);
  if BodyMatchCount > 1 then
  begin
    AResolutionFailureKind := 'ambiguous-overload';
    Exit;
  end;
  if BodyMatchCount = 0 then
    Exit;

  Result := SymbolId;
end;

function TSemanticAnalyzer.MethodSymbolIdForClassTypeMember(
  const AClassTypeId: LongInt;
  const AMemberName: string;
  const AArgCount: LongInt;
  const AArgTypeIds: TTypeIdArray;
  const AArgSignature: string;
  const AHasArgSignature: Boolean;
  const AHasTypeMismatchEvidence: Boolean;
  out AResolutionFailureKind: string;
  out ACandidates: TOverloadCandidateArray
): LongInt;
var
  CurrentTypeId: LongInt;
  Depth: LongInt;
  MethodNameFound: Boolean;
  TypeSymbol: TSemanticSymbol;
  AliasMeta: TTypeMetadata;
  PrevTypeId: LongInt;
begin
  Result := 0;
  AResolutionFailureKind := '';
  CurrentTypeId := AClassTypeId;
  Depth := 0;
  if not TypeIdHasKnownClassLayout(CurrentTypeId) then
  begin
    if FModel.GetTypeMeta(CurrentTypeId, AliasMeta) and
      (AliasMeta.AliasTargetTypeId > 0) then
      CurrentTypeId := AliasMeta.AliasTargetTypeId;
    if not TypeIdHasKnownClassLayout(CurrentTypeId) then
      Exit;
  end;
  while (CurrentTypeId > 0) and (Depth < 32) do
  begin
    if ClassTypeHasKnownNonMethodMember(CurrentTypeId, AMemberName) then
    begin
      if TypeSymbolForTypeId(CurrentTypeId, TypeSymbol) and
        (
          SameText(
            TypeSymbol.OwnerUnitId,
            NormalizeUnitIdentity(FUnitGraph.RootName)
          ) or
          OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)
        ) then
        AResolutionFailureKind := 'invalid-call-shape';
      Exit;
    end;

    Result := MethodSymbolIdForExactClassTypeMember(
      CurrentTypeId,
      AMemberName,
      AArgCount,
      AArgTypeIds,
      AArgSignature,
      AHasArgSignature,
      AHasTypeMismatchEvidence,
      (Depth = 0) or (
        TypeSymbolForTypeId(CurrentTypeId, TypeSymbol) and
        (
          SameText(
            TypeSymbol.OwnerUnitId,
            NormalizeUnitIdentity(FUnitGraph.RootName)
          ) or
          OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)
        )
      ),
      MethodNameFound,
      AResolutionFailureKind,
      ACandidates
    );
    if Result > 0 then
      Exit;
    if AResolutionFailureKind <> '' then
      Exit;
    if MethodNameFound then
      Exit;
    if (CurrentTypeId <= 0) or (CurrentTypeId > FModel.TypeCount) then
      Exit;
    PrevTypeId := CurrentTypeId;
    CurrentTypeId := FModel.TypeAt(PrevTypeId - 1).ParentTypeId;
    if (CurrentTypeId = 0) and FModel.GetTypeMeta(PrevTypeId, AliasMeta) and
      (AliasMeta.AliasTargetTypeId > 0) then
      CurrentTypeId := AliasMeta.AliasTargetTypeId;
    Inc(Depth);
  end;
  if IsDeferredSystemObjectMember(AMemberName) then
    Exit;
  if TypeSymbolForTypeId(AClassTypeId, TypeSymbol) and
    (not SameText(
      TypeSymbol.OwnerUnitId,
      NormalizeUnitIdentity(FUnitGraph.RootName)
    )) and
    (not OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)) then
    Exit;
  AResolutionFailureKind := 'unknown-member';
end;

function TSemanticAnalyzer.TryRegisterMemberCallBinding(
  const ACallNode: TGreenNode;
  const ACurrentMethodClass: string;
  const ACurrentOwnerUnitId: string;
  out AResolutionFailureKind: string;
  out AFailureName: string;
  out AFailureOffset: LongInt;
  out AActualArgCount: LongInt;
  out ACandidates: TOverloadCandidateArray
): Boolean;
var
  ArgCount: LongInt;
  ArgTypeIds: TTypeIdArray;
  ArgSignature: string;
  Candidates: TOverloadCandidateArray;
  HasArgSignature: Boolean;
  HasTypeMismatchEvidence: Boolean;
  MemberName: string;
  MemberOffset: LongInt;
  ReceiverName: string;
  ReceiverTypeId: LongInt;
  TargetSymbolId: LongInt;
begin
  Result := False;
  AResolutionFailureKind := '';
  AFailureName := '';
  AFailureOffset := 0;
  AActualArgCount := 0;
  TargetSymbolId := 0;
  SetLength(ACandidates, 0);
  if not ExtractDirectMemberCall(
    ACallNode,
    ReceiverName,
    MemberName,
    MemberOffset,
    ArgCount
  ) then
    Exit;
  AActualArgCount := ArgCount;
  AFailureName := MemberName;
  AFailureOffset := MemberOffset;
  if not CallArgumentTypeIds(ACallNode, ArgTypeIds) then
    SetLength(ArgTypeIds, 0);
  HasArgSignature := CallArgumentSignature(ACallNode, ArgSignature);
  HasTypeMismatchEvidence := HasArgSignature and
    CallArgumentSignatureIsStable(ACallNode, ACurrentOwnerUnitId);
  ReceiverTypeId := TypeIdForMemberReceiver(
    ReceiverName,
    ACurrentMethodClass,
    ACurrentOwnerUnitId
  );
  if ReceiverTypeId <= 0 then
  begin
    if not TryResolveTypeNameMemberCallTarget(
      ReceiverName,
      MemberName,
      ArgCount,
      ArgTypeIds,
      ArgSignature,
      HasArgSignature,
      HasTypeMismatchEvidence,
      ReceiverTypeId,
      TargetSymbolId
    ) then
      Exit;
  end;

  if TargetSymbolId <= 0 then
  begin
    TargetSymbolId := MethodSymbolIdForClassTypeMember(
      ReceiverTypeId,
      MemberName,
      ArgCount,
      ArgTypeIds,
      ArgSignature,
      HasArgSignature,
      HasTypeMismatchEvidence,
      AResolutionFailureKind,
      Candidates
    );
    ACandidates := Candidates;
  end;
  if TargetSymbolId <= 0 then
    Exit;

  if (ACurrentMethodClass = '') or
    (not SameText(ACurrentMethodClass,
      FModel.TypeAt(ReceiverTypeId - 1).Name)) then
  begin
    if SameText(FModel.SymbolAt(TargetSymbolId - 1).Visibility, 'private') and
      (not SameText(FModel.SymbolAt(TargetSymbolId - 1).OwnerUnitId,
        ACurrentOwnerUnitId)) then
    begin
      AResolutionFailureKind := 'inaccessible-member';
      Exit;
    end;
    if SameText(FModel.SymbolAt(TargetSymbolId - 1).Visibility, 'protected') and
      (not SameText(FModel.SymbolAt(TargetSymbolId - 1).OwnerUnitId,
        ACurrentOwnerUnitId)) then
    begin
      AResolutionFailureKind := 'inaccessible-member';
      Exit;
    end;
  end;

  FModel.AddBinding(
    'member-call',
    MemberName,
    ACurrentOwnerUnitId,
    MemberOffset,
    TargetSymbolId
  );
  Result := True;
end;

function TSemanticAnalyzer.TryRegisterImplicitSelfBareMethodCallBinding(
  const ACallNode: TGreenNode;
  const ACurrentMethodClass: string;
  const ACurrentOwnerUnitId: string;
  out AResolutionFailureKind: string;
  out AFailureName: string;
  out AFailureOffset: LongInt
): Boolean;
var
  ArgCount: LongInt;
  ArgTypeIds: TTypeIdArray;
  ArgSignature: string;
  CallName: string;
  HasArgSignature: Boolean;
  HasTypeMismatchEvidence: Boolean;
  ImplicitCandidates: TOverloadCandidateArray;
  ReceiverTypeId: LongInt;
  TargetSymbolId: LongInt;
begin
  Result := False;
  AResolutionFailureKind := '';
  AFailureName := '';
  AFailureOffset := 0;
  if (ACurrentMethodClass = '') or (ACallNode = nil) or
    not (ACallNode.NodeKind in [gnkProcedureCallStatement, gnkFunctionCall]) then
    Exit;

  CallName := BareCallCalleeName(ACallNode);
  if CallName = '' then
    Exit;
  AFailureName := CallName;
  AFailureOffset := ACallNode.ByteOffset;

  ReceiverTypeId := TypeIdForMemberReceiver(
    'Self',
    ACurrentMethodClass,
    ACurrentOwnerUnitId
  );
  if ReceiverTypeId <= 0 then
    Exit;

  ArgCount := CallArgumentCount(ACallNode);
  if not CallArgumentTypeIds(ACallNode, ArgTypeIds) then
    SetLength(ArgTypeIds, 0);
  HasArgSignature := CallArgumentSignature(ACallNode, ArgSignature);
  HasTypeMismatchEvidence := HasArgSignature and
    CallArgumentSignatureIsStable(ACallNode, ACurrentOwnerUnitId);
  TargetSymbolId := MethodSymbolIdForClassTypeMember(
    ReceiverTypeId,
    CallName,
    ArgCount,
    ArgTypeIds,
    ArgSignature,
    HasArgSignature,
    HasTypeMismatchEvidence,
    AResolutionFailureKind,
    ImplicitCandidates
  );
  if TargetSymbolId <= 0 then
    Exit;

  FModel.AddBinding(
    'member-call',
    CallName,
    ACurrentOwnerUnitId,
    ACallNode.ByteOffset,
    TargetSymbolId
  );
  Result := True;
end;

function TSemanticAnalyzer.BindCallArgs(const ADecl: TGreenNode;
  const ACallNode: TGreenNode;
  const ANameSkip: LongInt): TParamSnapshots;
var
  ParamList: TGreenNode;
  ParamDecl, ArgNode: TGreenNode;
  Index, ParamIndex, ArgIndex: LongInt;
  Value, Prior: Int64;
  Snap: TParamSnapshot;
begin
  Result := nil;
  if (ADecl = nil) or (ACallNode = nil) then
    Exit;
  ParamList := nil;
  for Index := 0 to ADecl.ChildCount - 1 do
    if (ADecl.ChildAt(Index) <> nil) and
      (ADecl.ChildAt(Index).NodeKind = gnkParameterList) then
    begin
      ParamList := ADecl.ChildAt(Index);
      Break;
    end;
  if ParamList = nil then
    Exit;
  ParamIndex := 0;
  for Index := 0 to ParamList.ChildCount - 1 do
  begin
    ParamDecl := ParamList.ChildAt(Index);
    if (ParamDecl = nil) or (ParamDecl.NodeKind <> gnkParameterDecl) then
      Continue;
    ArgIndex := ANameSkip + ParamIndex;
    if ArgIndex >= ACallNode.ChildCount then
      Break;
    ArgNode := ACallNode.ChildAt(ArgIndex);
    if (ArgNode <> nil) and EvaluateIntegerConstant(ArgNode, Value) then
    begin
      Snap.Name := ParamDecl.Text;
      Snap.HadValue := FModel.LookupVarInitValue(ParamDecl.Text, Prior);
      Snap.PriorValue := Prior;
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Snap;
      FModel.AddVarInitValue(ParamDecl.Text, Value);
    end;
    Inc(ParamIndex);
  end;
end;

procedure TSemanticAnalyzer.RestoreCallArgs(const ASnapshots: TParamSnapshots);
var
  Index: LongInt;
begin
  for Index := High(ASnapshots) downto 0 do
  begin
    if ASnapshots[Index].HadValue then
      FModel.AddVarInitValue(ASnapshots[Index].Name,
        ASnapshots[Index].PriorValue)
    else
      FModel.RemoveVarInitValue(ASnapshots[Index].Name);
  end;
end;

function TSemanticAnalyzer.EnsureUnitScope(
  const AOwnerUnitId: string
): LongInt;
var
  Index: LongInt;
  Scope: TSemanticScope;
begin
  Result := 0;
  if Trim(AOwnerUnitId) = '' then
    Exit;

  for Index := 0 to FModel.ScopeCount - 1 do
  begin
    Scope := FModel.ScopeAt(Index);
    if (Scope.Kind = skUnit) and
      SameText(NormalizeUnitIdentity(Scope.Name), AOwnerUnitId) then
      Exit(Scope.ScopeId);
  end;

  Result := FModel.AddScope(skUnit, AOwnerUnitId, 1);
end;

function TSemanticAnalyzer.CallableSymbolIdForDeclaration(
  const ADecl: TGreenNode;
  const AOwnerUnitId: string
): LongInt;
var
  Child: TGreenNode;
  ExpectedKind: string;
  Index: LongInt;
  ParamCount: LongInt;
  ParamSignature: string;
  Symbol: TSemanticSymbol;
  SymbolId: LongInt;
  TypeId: LongInt;
begin
  Result := 0;
  if ADecl = nil then
    Exit;

  if ADecl.NodeKind = gnkFunctionDecl then
    ExpectedKind := 'function'
  else if ADecl.NodeKind = gnkProcedureDecl then
    ExpectedKind := 'procedure'
  else
    ExpectedKind := '';
  ParamCount := CountDeclParams(ADecl);
  ParamSignature := GetParamSignature(ADecl);

  { Name-chain scan O(overloads), not O(all symbols). }
  SymbolId := FModel.FirstSymbolIdByName(ADecl.Text);
  while SymbolId > 0 do
  begin
    Symbol := FModel.SymbolAt(SymbolId - 1);
    if (Symbol.ByteOffset = ADecl.ByteOffset) and
      SameText(Symbol.Name, ADecl.Text) and
      ((AOwnerUnitId = '') or SameText(Symbol.OwnerUnitId, AOwnerUnitId)) and
      (SameText(Symbol.Kind, 'procedure') or
       SameText(Symbol.Kind, 'function') or
       SameText(Symbol.Kind, 'method') or
       SameText(Symbol.Kind, 'constructor') or
       SameText(Symbol.Kind, 'destructor')) then
      Exit(Symbol.SymbolId);
    SymbolId := FModel.NextSymbolIdSameName(SymbolId);
  end;

  SymbolId := FModel.FirstSymbolIdByName(ADecl.Text);
  while SymbolId > 0 do
  begin
    Symbol := FModel.SymbolAt(SymbolId - 1);
    if SameText(Symbol.Name, ADecl.Text) and
      ((AOwnerUnitId = '') or SameText(Symbol.OwnerUnitId, AOwnerUnitId)) and
      ((ExpectedKind = '') or SameText(Symbol.Kind, ExpectedKind) or
        SameText(Symbol.Kind, 'method') or
        SameText(Symbol.Kind, 'constructor') or
        SameText(Symbol.Kind, 'destructor')) and
      (Symbol.ParamCount = ParamCount) and
      SameText(Symbol.ParamSignature, ParamSignature) then
      Exit(Symbol.SymbolId);
    SymbolId := FModel.NextSymbolIdSameName(SymbolId);
  end;

  if (ExpectedKind = '') or (AOwnerUnitId = '') then
    Exit;

  { Qualified method decls (TFoo.Bar) still need a symbol id for bindings. }
  if Pos('.', ADecl.Text) > 0 then
  begin
    SymbolId := FModel.FirstSymbolIdByName(ADecl.Text);
    while SymbolId > 0 do
    begin
      Symbol := FModel.SymbolAt(SymbolId - 1);
      if SameText(Symbol.Name, ADecl.Text) and
        ((AOwnerUnitId = '') or SameText(Symbol.OwnerUnitId, AOwnerUnitId)) and
        (SameText(Symbol.Kind, 'method') or
         SameText(Symbol.Kind, 'constructor') or
         SameText(Symbol.Kind, 'destructor') or
         SameText(Symbol.Kind, 'function') or
         SameText(Symbol.Kind, 'procedure')) and
        ((Symbol.ParamCount < 0) or (Symbol.ParamCount = ParamCount)) then
        Exit(Symbol.SymbolId);
      SymbolId := FModel.NextSymbolIdSameName(SymbolId);
    end;
    Exit(0);
  end;

  TypeId := 0;
  if ADecl.NodeKind = gnkFunctionDecl then
    for Index := 0 to ADecl.ChildCount - 1 do
    begin
      Child := ADecl.ChildAt(Index);
      if (Child <> nil) and (Child.NodeKind = gnkIdentifier) then
      begin
        TypeId := ResolveTypeIdForOwner(Child.Text, AOwnerUnitId);
        Break;
      end;
    end;

  Result := FModel.AddSymbol(
    ADecl.Text,
    ExpectedKind,
    AOwnerUnitId,
    TypeId,
    ADecl.ByteOffset
  );
  FModel.SetSymbolParamCount(Result, ParamCount);
  FModel.SetSymbolMinParamCount(Result, CountRequiredDeclParams(ADecl));
  FModel.SetSymbolParamSignature(Result, ParamSignature);
  FModel.SetSymbolScope(Result, EnsureUnitScope(AOwnerUnitId));
end;

procedure TSemanticAnalyzer.RegisterCallBinding(
  const ACallNode: TGreenNode;
  const ADecl: TGreenNode;
  const AOwnerUnitId: string
);
var
  SymbolId: LongInt;
begin
  if (ACallNode = nil) or (ADecl = nil) then
    Exit;

  SymbolId := CallableSymbolIdForDeclaration(ADecl, AOwnerUnitId);
  if SymbolId <= 0 then
    Exit;

  FModel.AddBinding(
    'call',
    ACallNode.Text,
    NormalizeUnitIdentity(FUnitGraph.RootName),
    ACallNode.ByteOffset,
    SymbolId
  );
end;

