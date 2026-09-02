
function TSemanticAnalyzer.DuplicateImportName: string;
var
  SeenImports: TStringArray;
  Index: LongInt;
  ImportName: string;
  ImportId: string;
begin
  { Only flag duplicates WITHIN the same section.
    FPC allows the same unit in both interface and implementation uses. }
  SeenImports := nil;
  for Index := 0 to FRootAst.InterfaceUseCount - 1 do
  begin
    ImportName := FRootAst.InterfaceUseAt(Index);
    ImportId := NormalizeUnitIdentity(ImportName);
    if ContainsString(SeenImports, ImportId) then
      Exit(ImportName);
    AppendString(SeenImports, ImportId);
  end;

  SeenImports := nil;
  for Index := 0 to FRootAst.ImplementationUseCount - 1 do
  begin
    ImportName := FRootAst.ImplementationUseAt(Index);
    ImportId := NormalizeUnitIdentity(ImportName);
    if ContainsString(SeenImports, ImportId) then
      Exit(ImportName);
    AppendString(SeenImports, ImportId);
  end;

  Result := '';
end;

function TSemanticAnalyzer.CountDeclParams(const ADecl: TGreenNode): LongInt;
begin
  Result := nextpas.compiler.sema.overload.CountDeclParams(ADecl);
end;

function TSemanticAnalyzer.CountRequiredDeclParams(
  const ADecl: TGreenNode): LongInt;
begin
  Result := nextpas.compiler.sema.overload.CountRequiredDeclParams(ADecl);
end;

function TSemanticAnalyzer.DeclReturnTypeId(const ADecl: TGreenNode;
  const AOwnerUnitId: string): LongInt;
var
  Child: TGreenNode;
  Index: LongInt;
begin
  Result := 0;
  if ADecl = nil then
    Exit;

  case ADecl.NodeKind of
    gnkFunctionDecl:
      Index := 0;
    gnkClassMethod:
      begin
        Index := 0;
        if (ADecl.ChildCount > 0) and (ADecl.ChildAt(0) <> nil) and
          (ADecl.ChildAt(0).NodeKind = gnkIdentifier) then
          Index := 1;
      end;
  else
    Exit;
  end;

  for Index := Index to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(Index);
    if (Child = nil) or (Child.NodeKind <> gnkIdentifier) then
      Continue;
    Result := ResolveTypeIdForOwner(Child.Text, AOwnerUnitId);
    if Result > 0 then
      Exit;
  end;
end;

function TSemanticAnalyzer.DeclAcceptsArgCount(const ADecl: TGreenNode;
  const AArgCount: LongInt): Boolean;
begin
  Result := nextpas.compiler.sema.overload.DeclAcceptsArgCount(ADecl, AArgCount);
end;

function TSemanticAnalyzer.DeclParamSignatureMatchesArgs(
  const ADecl: TGreenNode; const AArgSignature: string; const AArgCount: LongInt): Boolean;
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
  Result := nextpas.compiler.sema.overload.DeclParamSignatureMatchesArgs(Ctx, ADecl, AArgSignature, AArgCount);
end;

function TSemanticAnalyzer.GetParamSignature(const ADecl: TGreenNode): string;
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
  Result := nextpas.compiler.sema.overload.GetParamSignature(Ctx, ADecl);
end;

function TSemanticAnalyzer.GetParamIdentitySignature(
  const ADecl: TGreenNode
): string;
begin
  Result := nextpas.compiler.sema.overload.GetParamIdentitySignature(ADecl);
end;

function TSemanticAnalyzer.GetSubstitutedParamSignature(
  const ADecl: TGreenNode;
  const AParamNames, AArgTypes: array of string): string;
var
  J, K, P: LongInt;
  Child, ParamChild, TypeChild: TGreenNode;
  TypeId: LongInt;
  TypeName, SubstType: string;
  Dummy: Int64;
  Found: Boolean;
  TypeSig: string;
begin
  Result := '';
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild = nil) or (ParamChild.NodeKind <> gnkParameterDecl) then
          Continue;
        TypeName := '';
        TypeChild := nil;
        if ParamChild.ChildCount > 0 then
        begin
          TypeChild := ParamChild.ChildAt(0);
          if TypeChild <> nil then
            TypeName := TypeChild.Text;
        end;
        Found := False;
        for P := 0 to High(AParamNames) do
        begin
          if SameText(TypeName, AParamNames[P]) then
          begin
            SubstType := LowerCase(AArgTypes[P]);
            TypeId := ResolveTypeId(AArgTypes[P]);
            TypeSig := TypeSignatureForTypeId(TypeId);
            if TypeSig <> '' then
              Result := Result + TypeSig
            else if (SubstType = 'string') or (SubstType = 'ansistring') then
              Result := Result + 's'
            else if (SubstType = 'boolean') or (SubstType = 'bool') then
              Result := Result + 'b'
            else if TypeMetaIsRecord(AArgTypes[P]) then
              Result := Result + 'r'
            else if TypeMetaSize(AArgTypes[P]) > 0 then
              Result := Result + 'p'
            else
              Result := Result + 'i';
            Found := True;
            Break;
          end;
        end;
        if not Found then
        begin
          TypeName := LowerCase(TypeName);
          TypeId := 0;
          if TypeChild <> nil then
          begin
            TypeId := ResolveTypeIdForOwner(
              TypeChild.Text,
              NormalizeUnitIdentity(FCurrentProcessingUnitId)
            );
            if TypeId <= 0 then
              TypeId := ResolveTypeIdForOwner(
                TypeChild.Text,
                NormalizeUnitIdentity(FUnitGraph.RootName)
              );
            if TypeId <= 0 then
              TypeId := ResolveTypeId(TypeChild.Text);
          end;
          TypeSig := TypeSignatureForTypeId(TypeId);
          if TypeSig <> '' then
            Result := Result + TypeSig
          else if (TypeName = 'string') or (TypeName = 'ansistring') then
            Result := Result + 's'
          else if (TypeName = 'boolean') or (TypeName = 'bool') then
            Result := Result + 'b'
