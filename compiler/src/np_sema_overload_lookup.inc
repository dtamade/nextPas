function LookupCallBindingDeclaration(const Ctx: TSemaOverloadContext; 
  const AName: string;
  const AArgCount: LongInt;
  const AArgTypeIds: TTypeIdArray;
  const AArgSignature: string;
  const AHasArgSignature: Boolean;
  const AHasTypeMismatchEvidence: Boolean;
  out AResolutionFailureKind: string;
  out ABody: TGreenNode;
  out ADecl: TGreenNode;
  out AOwnerUnitId: string
): Boolean;
var
  DirectImportCompatibleMatchCount: LongInt;
  DirectImportCompatibleMatchIndex: LongInt;
  DirectImportExactMatchCount: LongInt;
  DirectImportExactMatchIndex: LongInt;
  HasArgTypeIds: Boolean;
  Index: LongInt;
  ImportedDiagnosticMatchCount: LongInt;
  ImportedMatchCount: LongInt;
  ImportedMatchIndex: LongInt;
  ImportedDiagnosticNameCount: LongInt;
  ImportedNameCount: LongInt;
  ImportedCompatibleMatchCount: LongInt;
  ImportedCompatibleMatchIndex: LongInt;
  ImportedDiagnosticSignatureMatchCount: LongInt;
  ImportedExactMatchCount: LongInt;
  ImportedExactMatchIndex: LongInt;
  ImportedSignatureMatchCount: LongInt;
  ImportedSignatureMatchIndex: LongInt;
  DirectImportMatchCount: LongInt;
  DirectImportMatchIndex: LongInt;
  KnownSymbolId: LongInt;
  RootMatchCount: LongInt;
  RootMatchIndex: LongInt;
  RootNameCount: LongInt;
  RootOwnerUnitId: string;
  RootCompatibleMatchCount: LongInt;
  RootCompatibleMatchIndex: LongInt;
  RootExactMatchCount: LongInt;
  RootExactMatchIndex: LongInt;
  RootSignatureMatchCount: LongInt;
  RootSignatureMatchIndex: LongInt;
begin
  ABody := nil;
  ADecl := nil;
  AOwnerUnitId := '';
  AResolutionFailureKind := '';
  { 内建过程 (Write/WriteLn/Read/ReadLn 等) 可变参数，跳过重载解析 }
  if Ctx.BuiltinRegistry.IsBuiltinProcedure(AName) then
    Exit(False);
  ImportedDiagnosticMatchCount := 0;
  ImportedMatchCount := 0;
  ImportedMatchIndex := -1;
  ImportedDiagnosticNameCount := 0;
  ImportedDiagnosticSignatureMatchCount := 0;
  ImportedNameCount := 0;
  ImportedCompatibleMatchCount := 0;
  ImportedCompatibleMatchIndex := -1;
  ImportedExactMatchCount := 0;
  ImportedExactMatchIndex := -1;
  ImportedSignatureMatchCount := 0;
  ImportedSignatureMatchIndex := -1;
  DirectImportCompatibleMatchCount := 0;
  DirectImportCompatibleMatchIndex := -1;
  DirectImportExactMatchCount := 0;
  DirectImportExactMatchIndex := -1;
  DirectImportMatchCount := 0;
  DirectImportMatchIndex := -1;
  RootMatchCount := 0;
  RootMatchIndex := -1;
  RootNameCount := 0;
  RootCompatibleMatchCount := 0;
  RootCompatibleMatchIndex := -1;
  RootExactMatchCount := 0;
  RootExactMatchIndex := -1;
  RootSignatureMatchCount := 0;
  RootSignatureMatchIndex := -1;
  RootOwnerUnitId := NormalizeUnitIdentity(Ctx.UnitGraph.RootName);
  HasArgTypeIds := (Length(AArgTypeIds) = AArgCount) and
    TypeIdArrayHasKnownTypes(AArgTypeIds);

  { Name→index chain: O(overloads of AName), not O(all registered bodies).
    L3 nextpas registers ~12k bodies; full linear scan per call hangs. }
  Index := CtxFirstBodyIndexForName(Ctx, AName);
  while Index >= 0 do
  begin
    if SameText(Ctx.ProcedureBodies[Index].OwnerUnitId, RootOwnerUnitId) or
      SameText(Ctx.ProcedureBodies[Index].OwnerUnitId,
        Ctx.CurrentProcessingUnitId) then
    begin
      Inc(RootNameCount);
      if DeclAcceptsArgCount(Ctx.ProcedureBodies[Index].Decl, AArgCount) then
      begin
        RootMatchIndex := Index;
        Inc(RootMatchCount);
        if HasArgTypeIds and DeclParamTypesExactMatch(Ctx,
          Ctx.ProcedureBodies[Index].Decl,
          Ctx.ProcedureBodies[Index].OwnerUnitId,
          AArgTypeIds,
          AArgCount
        ) then
        begin
          RootExactMatchIndex := Index;
          Inc(RootExactMatchCount);
        end
        else if HasArgTypeIds and DeclParamTypesCompatibleMatch(Ctx,
          Ctx.ProcedureBodies[Index].Decl,
          Ctx.ProcedureBodies[Index].OwnerUnitId,
          AArgTypeIds,
          AArgCount
        ) then
        begin
          RootCompatibleMatchIndex := Index;
          Inc(RootCompatibleMatchCount);
        end;
        if AHasArgSignature and
          DeclParamSignatureMatchesArgs(Ctx,
            Ctx.ProcedureBodies[Index].Decl,
            AArgSignature,
            AArgCount
          ) then
        begin
          RootSignatureMatchIndex := Index;
          Inc(RootSignatureMatchCount);
        end;
      end;
    end
    else
    begin
      Inc(ImportedNameCount);
      if OwnerUnitAllowsProjectSourceDiagnostic(Ctx,
        Ctx.ProcedureBodies[Index].OwnerUnitId
      ) then
        Inc(ImportedDiagnosticNameCount);
      if DeclAcceptsArgCount(Ctx.ProcedureBodies[Index].Decl, AArgCount) then
      begin
        ImportedMatchIndex := Index;
        Inc(ImportedMatchCount);
        if HasArgTypeIds and DeclParamTypesExactMatch(Ctx,
          Ctx.ProcedureBodies[Index].Decl,
          Ctx.ProcedureBodies[Index].OwnerUnitId,
          AArgTypeIds,
          AArgCount
        ) then
        begin
          ImportedExactMatchIndex := Index;
          Inc(ImportedExactMatchCount);
        end
        else if HasArgTypeIds and DeclParamTypesCompatibleMatch(Ctx,
          Ctx.ProcedureBodies[Index].Decl,
          Ctx.ProcedureBodies[Index].OwnerUnitId,
          AArgTypeIds,
          AArgCount
        ) then
        begin
          ImportedCompatibleMatchIndex := Index;
          Inc(ImportedCompatibleMatchCount);
        end;
        if UnitDirectlyImports(Ctx, RootOwnerUnitId,
          Ctx.ProcedureBodies[Index].OwnerUnitId) then
        begin
          DirectImportMatchIndex := Index;
          Inc(DirectImportMatchCount);
          if HasArgTypeIds and DeclParamTypesExactMatch(Ctx,
            Ctx.ProcedureBodies[Index].Decl,
            Ctx.ProcedureBodies[Index].OwnerUnitId,
            AArgTypeIds,
            AArgCount
          ) then
          begin
            DirectImportExactMatchIndex := Index;
            Inc(DirectImportExactMatchCount);
          end
          else if HasArgTypeIds and DeclParamTypesCompatibleMatch(Ctx,
            Ctx.ProcedureBodies[Index].Decl,
            Ctx.ProcedureBodies[Index].OwnerUnitId,
            AArgTypeIds,
            AArgCount
          ) then
          begin
            DirectImportCompatibleMatchIndex := Index;
            Inc(DirectImportCompatibleMatchCount);
          end;
        end;
        if OwnerUnitAllowsProjectSourceDiagnostic(Ctx,
          Ctx.ProcedureBodies[Index].OwnerUnitId
        ) then
          Inc(ImportedDiagnosticMatchCount);
        if AHasArgSignature and
          DeclParamSignatureMatchesArgs(Ctx,
            Ctx.ProcedureBodies[Index].Decl,
            AArgSignature,
            AArgCount
          ) then
        begin
          ImportedSignatureMatchIndex := Index;
          Inc(ImportedSignatureMatchCount);
          if OwnerUnitAllowsProjectSourceDiagnostic(Ctx,
            Ctx.ProcedureBodies[Index].OwnerUnitId
          ) then
            Inc(ImportedDiagnosticSignatureMatchCount);
        end;
      end;
    end;
    Index := CtxNextBodyIndexForName(Ctx, Index);
  end;

  if RootMatchCount > 0 then
  begin
    if HasArgTypeIds and
      ((RootExactMatchCount > 0) or (RootCompatibleMatchCount > 0)) then
    begin
      { C8/M2 permissive: multi-unit same-signature (e.g. ParamStr) → last index. }
      if RootExactMatchCount >= 1 then
        RootSignatureMatchIndex := RootExactMatchIndex
      else if RootCompatibleMatchCount >= 1 then
        RootSignatureMatchIndex := RootCompatibleMatchIndex
      else
      begin
        if AHasTypeMismatchEvidence then
          AResolutionFailureKind := 'no-matching-overload';
        Exit(False);
      end;
    end
    else if RootMatchCount = 1 then
    begin
      if AHasArgSignature and
        (not DeclParamSignatureMatchesArgs(Ctx, 
          Ctx.ProcedureBodies[RootMatchIndex].Decl,
          AArgSignature,
          AArgCount
        )) then
      begin
        if AHasTypeMismatchEvidence then
        begin
          AResolutionFailureKind := 'type-mismatch';
        end;
        Exit(False);
      end;
      RootSignatureMatchIndex := RootMatchIndex
    end
    else if (not AHasArgSignature) or (RootSignatureMatchCount > 1) then
    begin
      { Permissive: any arity-accepting root body when signatures tie/missing. }
      if RootSignatureMatchCount >= 1 then
        RootSignatureMatchIndex := RootSignatureMatchIndex
      else
        RootSignatureMatchIndex := RootMatchIndex;
    end
    else if RootSignatureMatchCount = 0 then
    begin
      if AHasTypeMismatchEvidence then
        AResolutionFailureKind := 'no-matching-overload';
      Exit(False);
    end;

    ABody := Ctx.ProcedureBodies[RootSignatureMatchIndex].Body;
    ADecl := Ctx.ProcedureBodies[RootSignatureMatchIndex].Decl;
    AOwnerUnitId := Ctx.ProcedureBodies[RootSignatureMatchIndex].OwnerUnitId;
    Exit(True);
  end;

  if RootNameCount > 0 then
  begin
    AResolutionFailureKind := 'wrong-argument-count';
    Exit(False);
  end;

  if (RootNameCount = 0) and (ImportedNameCount = 0) then
  begin
    KnownSymbolId := Ctx.Model.LookupSymbolWithImports(AName, Ctx.CurrentScopeId);
    if IsSimpleIdentifierName(AName) and (KnownSymbolId = 0) and
      (Ctx.Model.FindTypeByName(AName) = 0) and
      (not Ctx.BuiltinRegistry.IsBuiltinProcedure(AName)) and
      (not HasInstalledSourceImports(Ctx)) then
      AResolutionFailureKind := 'unknown-callable';
    Exit(False);
  end;

  if ImportedMatchCount = 0 then
  begin
    if ImportedDiagnosticNameCount > 0 then
      AResolutionFailureKind := 'wrong-argument-count';
    Exit(False);
  end;

  { Prefer direct imports over transitive imports (FPC-compatible).
    C8/M2 permissive: multi-unit same-signature (ParamStr/SysUtils vs core)
    takes the last recorded direct-import exact/compatible match. }
  if HasArgTypeIds and (DirectImportExactMatchCount >= 1) then
  begin
    ABody := Ctx.ProcedureBodies[DirectImportExactMatchIndex].Body;
    ADecl := Ctx.ProcedureBodies[DirectImportExactMatchIndex].Decl;
    AOwnerUnitId := Ctx.ProcedureBodies[DirectImportExactMatchIndex].OwnerUnitId;
    Exit(True);
  end;

  if HasArgTypeIds and (DirectImportCompatibleMatchCount >= 1) and
    (DirectImportExactMatchCount = 0) then
  begin
    ABody := Ctx.ProcedureBodies[DirectImportCompatibleMatchIndex].Body;
    ADecl := Ctx.ProcedureBodies[DirectImportCompatibleMatchIndex].Decl;
    AOwnerUnitId := Ctx.ProcedureBodies[DirectImportCompatibleMatchIndex].OwnerUnitId;
    Exit(True);
  end;

  if (ImportedMatchCount > 1) and (DirectImportMatchCount = 1) then
  begin
    if HasArgTypeIds and (DirectImportExactMatchCount = 1) then
      DirectImportMatchIndex := DirectImportExactMatchIndex
    else if HasArgTypeIds and (DirectImportCompatibleMatchCount = 1) then
      DirectImportMatchIndex := DirectImportCompatibleMatchIndex
    else if HasArgTypeIds then
    begin
      if AHasTypeMismatchEvidence and
        OwnerUnitAllowsProjectSourceDiagnostic(Ctx, 
          Ctx.ProcedureBodies[DirectImportMatchIndex].OwnerUnitId
        ) then
        AResolutionFailureKind := 'type-mismatch';
      Exit(False);
    end
    else if AHasArgSignature and
      (not DeclParamSignatureMatchesArgs(Ctx, 
        Ctx.ProcedureBodies[DirectImportMatchIndex].Decl,
        AArgSignature,
        AArgCount
      )) then
    begin
      if AHasTypeMismatchEvidence and
        OwnerUnitAllowsProjectSourceDiagnostic(Ctx, 
          Ctx.ProcedureBodies[DirectImportMatchIndex].OwnerUnitId
        ) then
        AResolutionFailureKind := 'type-mismatch';
      Exit(False);
    end;
    ABody := Ctx.ProcedureBodies[DirectImportMatchIndex].Body;
    ADecl := Ctx.ProcedureBodies[DirectImportMatchIndex].Decl;
    AOwnerUnitId := Ctx.ProcedureBodies[DirectImportMatchIndex].OwnerUnitId;
    Exit(True);
  end;

  if ImportedMatchCount = 1 then
  begin
    if HasArgTypeIds and DeclParamTypesExactMatch(Ctx, 
      Ctx.ProcedureBodies[ImportedMatchIndex].Decl,
      Ctx.ProcedureBodies[ImportedMatchIndex].OwnerUnitId,
      AArgTypeIds,
      AArgCount
    ) then
      ImportedSignatureMatchIndex := ImportedMatchIndex
    else if HasArgTypeIds and DeclParamTypesCompatibleMatch(Ctx, 
      Ctx.ProcedureBodies[ImportedMatchIndex].Decl,
      Ctx.ProcedureBodies[ImportedMatchIndex].OwnerUnitId,
      AArgTypeIds,
      AArgCount
    ) then
      ImportedSignatureMatchIndex := ImportedMatchIndex
    else if HasArgTypeIds then
    begin
      if AHasTypeMismatchEvidence and
        OwnerUnitAllowsProjectSourceDiagnostic(Ctx, 
          Ctx.ProcedureBodies[ImportedMatchIndex].OwnerUnitId
        ) then
        AResolutionFailureKind := 'type-mismatch';
      Exit(False);
    end
    else if AHasArgSignature and
      (not DeclParamSignatureMatchesArgs(Ctx, 
        Ctx.ProcedureBodies[ImportedMatchIndex].Decl,
        AArgSignature,
        AArgCount
      )) then
    begin
      if AHasTypeMismatchEvidence and
        OwnerUnitAllowsProjectSourceDiagnostic(Ctx, 
          Ctx.ProcedureBodies[ImportedMatchIndex].OwnerUnitId
        ) then
        AResolutionFailureKind := 'type-mismatch';
      Exit(False);
    end
    else
      ImportedSignatureMatchIndex := ImportedMatchIndex
  end
  else if HasArgTypeIds and
    ((ImportedExactMatchCount > 0) or (ImportedCompatibleMatchCount > 0)) then
  begin
    { Permissive multi-unit exact/compatible (e.g. ParamStr×3). }
    if ImportedExactMatchCount >= 1 then
      ImportedSignatureMatchIndex := ImportedExactMatchIndex
    else if ImportedCompatibleMatchCount >= 1 then
      ImportedSignatureMatchIndex := ImportedCompatibleMatchIndex
    else
    begin
      if AHasTypeMismatchEvidence and
        (ImportedDiagnosticMatchCount = ImportedMatchCount) then
        AResolutionFailureKind := 'no-matching-overload';
      Exit(False);
    end;
  end
  else if (not AHasArgSignature) or (ImportedSignatureMatchCount > 1) then
  begin
    if ImportedSignatureMatchCount >= 1 then
    begin
      { Fall through — keep ImportedSignatureMatchIndex (last signature hit). }
    end
    else if ImportedMatchCount >= 1 then
      ImportedSignatureMatchIndex := ImportedMatchIndex
    else
    begin
      if AHasTypeMismatchEvidence and
        (ImportedDiagnosticMatchCount = ImportedMatchCount) then
        AResolutionFailureKind := 'no-matching-overload';
      Exit(False);
    end;
  end
  else if ImportedSignatureMatchCount = 0 then
  begin
    if AHasTypeMismatchEvidence and
      (ImportedDiagnosticMatchCount = ImportedMatchCount) then
      AResolutionFailureKind := 'no-matching-overload';
    Exit(False);
  end;

  ABody := Ctx.ProcedureBodies[ImportedSignatureMatchIndex].Body;
  ADecl := Ctx.ProcedureBodies[ImportedSignatureMatchIndex].Decl;
  AOwnerUnitId := Ctx.ProcedureBodies[ImportedSignatureMatchIndex].OwnerUnitId;
  Result := True;
end;

function HasInstalledSourceImports(const Ctx: TSemaOverloadContext): Boolean;
var
  Index: LongInt;
  ResolvedUnit: TResolvedUnit;
begin
  Result := False;
  for Index := 0 to Ctx.UnitGraph.ResolvedUnitCount - 1 do
  begin
    ResolvedUnit := Ctx.UnitGraph.ResolvedUnitAt(Index);
    if SameText(ResolvedUnit.OriginClass, 'installed-source') then
      Exit(True);
  end;
end;

function OwnerUnitAllowsProjectSourceDiagnostic(
  const Ctx: TSemaOverloadContext; const AOwnerUnitId: string): Boolean;
var ImportCtx: TSemaImportContext;
begin
  ImportCtx.UnitGraph := Ctx.UnitGraph;
  ImportCtx.RootAst := Ctx.RootAst;
  ImportCtx.ImportedUnitOwners := Ctx.ImportedUnitOwners;
  ImportCtx.ImportedUnitTrees := Ctx.ImportedUnitTrees;
  Result := OwnerUnitAllowsProjectSourceDiagnostic(ImportCtx, AOwnerUnitId);
end;

function UnitDirectlyImports(
  const Ctx: TSemaOverloadContext;
  const AOwnerUnitId, AImportedUnitId: string): Boolean;
var ImportCtx: TSemaImportContext;
begin
  ImportCtx.UnitGraph := Ctx.UnitGraph;
  ImportCtx.RootAst := Ctx.RootAst;
  ImportCtx.ImportedUnitOwners := Ctx.ImportedUnitOwners;
  ImportCtx.ImportedUnitTrees := Ctx.ImportedUnitTrees;
  Result := UnitDirectlyImports(ImportCtx, AOwnerUnitId, AImportedUnitId);
end;


