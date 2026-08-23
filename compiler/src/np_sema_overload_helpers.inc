function CountDeclParams(const ADecl: TGreenNode): LongInt;
var
  J, K: LongInt;
  Child, ParamChild: TGreenNode;
begin
  Result := 0;
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
          Inc(Result);
      end;
      Exit;
    end;
  end;
end;

function CountRequiredDeclParams(const ADecl: TGreenNode): LongInt;
var
  J, K: LongInt;
  Child, ParamChild: TGreenNode;
begin
  Result := 0;
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) and
          (ParamChild.ChildCount <= 1) then
          Inc(Result);
      end;
      Exit;
    end;
  end;
end;

function DeclAcceptsArgCount(const ADecl: TGreenNode; const AArgCount: LongInt): Boolean;
var
  MaxParamCount: LongInt;
  MinParamCount: LongInt;
begin
  MaxParamCount := CountDeclParams(ADecl);
  MinParamCount := CountRequiredDeclParams(ADecl);
  Result := (AArgCount >= MinParamCount) and (AArgCount <= MaxParamCount);
end;

function MangledName(const AName: string; AParamCount: LongInt): string;
begin
  if AParamCount = 0 then
    Result := AName
  else
    Result := AName + '$' + IntToStr(AParamCount);
end;

function MangledNameSig(const AName, ASig: string): string;
begin
  if ASig = '' then
    Result := AName
  else
    Result := AName + '$' + ASig;
end;

function HasOverload(const AName: string;
  const AProcedureBodies: TProcedureBodyVec): Boolean;
var
  Index, Count: LongInt;
begin
  Count := 0;
  for Index := 0 to LongInt(AProcedureBodies.Count) - 1 do
    if SameText(AProcedureBodies[Index].Name, AName) then
      Inc(Count);
  Result := Count > 1;
end;

function FirstBodyIndexForName(const ABodies: TProcedureBodyVec;
  const AName: string): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to LongInt(ABodies.Count) - 1 do
    if SameText(ABodies[Index].Name, AName) then
      Exit(Index);
  Result := -1;
end;

function NextBodyIndexForName(const ABodies: TProcedureBodyVec;
  const AName: string; const APrevIndex: LongInt): LongInt;
var
  Index: LongInt;
begin
  if APrevIndex < 0 then
    Exit(-1);
  for Index := APrevIndex + 1 to LongInt(ABodies.Count) - 1 do
    if SameText(ABodies[Index].Name, AName) then
      Exit(Index);
  Result := -1;
end;

function CtxFirstBodyIndexForName(const Ctx: TSemaOverloadContext;
  const AName: string): LongInt;
begin
  Result := -1;
  if AName = '' then
    Exit;
  if (Ctx.BodyNameFirst <> nil) and
    Ctx.BodyNameFirst.TryGetValue(LowerCase(AName), Result) then
    Exit;
  if Ctx.BodyNameFirst <> nil then
    Exit(-1);
  Result := FirstBodyIndexForName(Ctx.ProcedureBodies, AName);
end;

function CtxNextBodyIndexForName(const Ctx: TSemaOverloadContext;
  const APrevIndex: LongInt): LongInt;
begin
  Result := -1;
  if APrevIndex < 0 then
    Exit;
  if Ctx.BodyNameNext <> nil then
  begin
    if APrevIndex >= LongInt(Ctx.BodyNameNext.Count) then
      Exit;
    Exit(Ctx.BodyNameNext[APrevIndex]);
  end;
  { Linear fallback needs the name — callers that use Next without First on
    unindexed context must use NextBodyIndexForName(ABodies, AName, Prev). }
end;

function LookupOverload(const AName: string; AArgCount: LongInt;
  const AProcedureBodies: TProcedureBodyVec;
  out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
var
  Index: LongInt;
begin
  ABody := nil;
  ADecl := nil;
  for Index := 0 to LongInt(AProcedureBodies.Count) - 1 do
    if SameText(AProcedureBodies[Index].Name, AName) and
      DeclAcceptsArgCount(AProcedureBodies[Index].Decl, AArgCount) then
    begin
      ABody := AProcedureBodies[Index].Body;
      ADecl := AProcedureBodies[Index].Decl;
      Exit(True);
    end;
  Result := False;
end;

function TypeIdArrayHasKnownTypes(const ATypeIds: TTypeIdArray): Boolean;
var
  Index: LongInt;
begin
  Result := Length(ATypeIds) = 0;
  if Result then
    Exit;
  for Index := 0 to Length(ATypeIds) - 1 do
    if ATypeIds[Index] > 0 then
      Exit(True);
  Result := False;
end;

function GetParamIdentitySignature(const ADecl: TGreenNode): string;
var
  Child: TGreenNode;
  Index: LongInt;
  ParamChild: TGreenNode;
  ParamIndex: LongInt;
  TypeChild: TGreenNode;
  TypeName: string;
begin
  Result := '';
  if ADecl = nil then
    Exit;
  for Index := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(Index);
    if (Child = nil) or (Child.NodeKind <> gnkParameterList) then
      Continue;
    ParamIndex := 0;
    while ParamIndex < Child.ChildCount do
    begin
      ParamChild := Child.ChildAt(ParamIndex);
      if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
      begin
        TypeName := '';
        if ParamChild.ChildCount > 0 then
        begin
          TypeChild := ParamChild.ChildAt(0);
          if TypeChild <> nil then
            TypeName := LowerCase(TypeChild.Text);
        end;
        { Open-array params (const aSrc: array of T) parse to an empty
          gnkArrayType text; without a placeholder the identity signature
          collapses across overloads (TCollection.Create(aAllocator,aData)
          vs (aSrc: array of T; aAllocator; aData)) and
          RegisterProcedureBody overwrites the full main-overload body
          with the delegating overload (b4b-i6). '?' keeps them apart. }
        if TypeName = '' then
          TypeName := '?';
        if Result <> '' then
          Result := Result + '|';
        Result := Result + TypeName;
      end;
      Inc(ParamIndex);
    end;
    Exit;
  end;
end;

function OwnerUnitAllowsProjectSourceDiagnostic(
  const Ctx: TSemaImportContext; const AOwnerUnitId: string): Boolean;
var
  ResolvedUnit: TResolvedUnit;
begin
  Result := False;
  if Trim(AOwnerUnitId) = '' then
    Exit;
  if not Ctx.UnitGraph.FindUnit(AOwnerUnitId, ResolvedUnit) then
    Exit;
  Result := SameText(ResolvedUnit.OriginClass, 'project-source');
end;

function UnitDirectlyImports(
  const Ctx: TSemaImportContext;
  const AOwnerUnitId, AImportedUnitId: string): Boolean;
var
  ImportId: string;
  Index: LongInt;
  OwnerUnitId: string;
  UnitTree: TGreenTree;
  UseIndex: LongInt;
begin
  Result := False;
  if (Trim(AOwnerUnitId) = '') or (Trim(AImportedUnitId) = '') then
    Exit;

  OwnerUnitId := NormalizeUnitIdentity(AOwnerUnitId);
  ImportId := NormalizeUnitIdentity(AImportedUnitId);
  if (OwnerUnitId = '') or (ImportId = '') then
    Exit;

  if SameText(OwnerUnitId, NormalizeUnitIdentity(Ctx.UnitGraph.RootName)) then
  begin
    for UseIndex := 0 to Ctx.RootAst.InterfaceUseCount - 1 do
      if SameText(NormalizeUnitIdentity(Ctx.RootAst.InterfaceUseAt(UseIndex)),
        ImportId) then
        Exit(True);
    for UseIndex := 0 to Ctx.RootAst.ImplementationUseCount - 1 do
      if SameText(NormalizeUnitIdentity(Ctx.RootAst.ImplementationUseAt(UseIndex)),
        ImportId) then
        Exit(True);
    Exit(False);
  end;

  if Ctx.ImportedUnitTrees = nil then
    Exit(False);
  for Index := 0 to LongInt(Ctx.ImportedUnitTrees.Count) - 1 do
  begin
    if not SameText(Ctx.ImportedUnitOwners[Index], OwnerUnitId) then
      Continue;
    UnitTree := Ctx.ImportedUnitTrees[Index];
    if UnitTree = nil then
      Exit(False);
    for UseIndex := 0 to UnitTree.InterfaceUseCount - 1 do
      if SameText(NormalizeUnitIdentity(UnitTree.InterfaceUseAt(UseIndex)),
        ImportId) then
        Exit(True);
    for UseIndex := 0 to UnitTree.ImplementationUseCount - 1 do
      if SameText(NormalizeUnitIdentity(
        UnitTree.ImplementationUseAt(UseIndex)), ImportId) then
        Exit(True);
    Exit(False);
  end;
end;
