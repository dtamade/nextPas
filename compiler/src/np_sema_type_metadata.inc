
function TSemanticAnalyzer.TypeMetaFieldIndex(
  const ATypeName, AFieldName: string): Int64;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaFieldIndex(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaFieldIsStr(
  const ATypeName, AFieldName: string): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaFieldIsStr(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaFieldIsPtr(
  const ATypeName, AFieldName: string): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaFieldIsPtr(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaFieldIsDynArray(
  const ATypeName, AFieldName: string): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaFieldIsDynArray(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaFieldDynArrayElemSize(
  const ATypeName, AFieldName: string): Int64;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaFieldDynArrayElemSize(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaVmtSlot(
  const ATypeName, AMethodName: string): Int64;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaVmtSlot(FModel, ATypeName, AMethodName);
end;

function TSemanticAnalyzer.TypeMetaRetPtr(
  const ATypeName, AMethodName: string): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaRetPtr(FModel, ATypeName, AMethodName);
end;

function TSemanticAnalyzer.TypeMetaRetStr(
  const ATypeName, AMethodName: string): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaRetStr(FModel, ATypeName, AMethodName);
end;

function TSemanticAnalyzer.TypeMetaParentClass(const ATypeName: string): string;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaParentClass(FModel, ATypeName);
end;

function TSemanticAnalyzer.NextClassAncestorName(const ATypeName: string): string;
begin
  Result := nextpas.compiler.sema.type_check.NextClassAncestorName(FModel, ATypeName);
end;

function TSemanticAnalyzer.ResolveClassMethodCalleeName(const AClassName,
  AMethodName: string): string;
var
  OwnerName, MemberName, Candidate, Resolved, ShortName: string;
  Guard, DotPos, CharIdx: LongInt;
  FoundNonTObject: string;
  FoundAny: string;
  function ClassHasMethod(const AOwner, AMethod: string): Boolean;
  begin
    { A direct call needs a real body; a bare symbol (abstract virtual,
      un-cloned generic method like TArray<Boolean>.Create without a
      whitelist body) would emit an undefined callee. }
    Result := FirstBodyIndexForNameLocal(AOwner + '.' + AMethod) >= 0;
  end;
  function PeelAliasClassName(const AName: string): string;
  var
    Cur: string;
    Tid, G, LocalDot, LocalIdx: LongInt;
    M: TTypeMetadata;
    SpecText, SpecOwner, GenericName, ArgsText, ArgName, Subst,
      ExpandedName: string;
    LtPos, GtPos, ArgI, ArgJ, Depth: LongInt;
  begin
    Result := AName;
    Cur := AName;
    G := 0;
    while (Cur <> '') and (G < 8) do
    begin
      Inc(G);
      Tid := FModel.FindTypeByName(Cur);
      if Tid <= 0 then
      begin
        LocalDot := 0;
        for LocalIdx := Length(Cur) downto 1 do
          if Cur[LocalIdx] = '.' then
          begin
            LocalDot := LocalIdx;
            Break;
          end;
        if LocalDot > 0 then
        begin
          ShortName := Copy(Cur, LocalDot + 1, MaxInt);
          Tid := FModel.FindTypeByName(ShortName);
          if Tid > 0 then
            Cur := ShortName
          else
            Break;
        end
        else
          Break;
      end;
      if not FModel.GetTypeMeta(Tid, M) then
        Break;
      if M.AliasTargetTypeId <= 0 then
      begin
        { Class-local generic alias (TVecBuf = specialize TArray<T>):
          T stays unbound until instantiation, so the alias target is 0.
          Expand through the active generic instance's $generic_arg_<T>
          consts and instantiate the concrete target on demand. }
        if (FCurrentGenericInstance <> '') and
          FModel.LookupStringConstValue(Cur + '$class_spec', SpecText) and
          (SpecText <> '') then
        begin
          LtPos := Pos('<', SpecText);
          if LtPos > 0 then
          begin
            Depth := 1;
            GtPos := LtPos + 1;
            while (GtPos <= Length(SpecText)) and (Depth > 0) do
            begin
              if SpecText[GtPos] = '<' then
                Inc(Depth)
              else if SpecText[GtPos] = '>' then
                Dec(Depth);
              Inc(GtPos);
            end;
            GenericName := Copy(SpecText, 1, LtPos - 1);
            ArgsText := Copy(SpecText, LtPos + 1, GtPos - LtPos - 2);
            ExpandedName := GenericName + '<';
            ArgI := 1;
            while ArgI <= Length(ArgsText) do
            begin
              while (ArgI <= Length(ArgsText)) and (ArgsText[ArgI] = ' ') do
                Inc(ArgI);
              ArgJ := ArgI;
              while (ArgJ <= Length(ArgsText)) and (ArgsText[ArgJ] <> ',') do
                Inc(ArgJ);
              ArgName := Copy(ArgsText, ArgI, ArgJ - ArgI);
              while (Length(ArgName) > 0) and
                (ArgName[Length(ArgName)] = ' ') do
                Delete(ArgName, Length(ArgName), 1);
              Subst := ArgName;
              if FModel.LookupStringConstValue(
                FCurrentGenericInstance + '.$generic_arg_' + ArgName,
                Subst) then
                { template param -> concrete generic arg }
              else
                Subst := ArgName;
              ExpandedName := ExpandedName + Subst;
              if (ArgJ <= Length(ArgsText)) and (ArgsText[ArgJ] = ',') then
                ExpandedName := ExpandedName + ',';
              ArgI := ArgJ + 1;
            end;
            ExpandedName := ExpandedName + '>';
            SpecOwner := '';
            FModel.LookupStringConstValue(Cur + '$class_owner_unit',
              SpecOwner);
            if FModel.FindTypeByName(ExpandedName) <= 0 then
              ResolveOrInstantiateInlineGeneric(ExpandedName, SpecOwner);
            if FModel.FindTypeByName(ExpandedName) > 0 then
            begin
              Result := ExpandedName;
              Break;
            end;
          end;
        end;
        Result := Cur;
        Break;
      end;
      if (M.AliasTargetTypeId > 0) and
        (M.AliasTargetTypeId <= FModel.TypeCount) then
      begin
        ShortName := FModel.TypeAt(M.AliasTargetTypeId - 1).Name;
        if (ShortName = '') or SameText(ShortName, Cur) then
        begin
          Result := Cur;
          Break;
        end;
        Cur := ShortName;
        Result := Cur;
      end
      else
        Break;
    end;
  end;
  function TryResolveTable(const AOwner, AMethod: string;
    out AResolved: string): Boolean;
  begin
    Result := FModel.LookupStringConstValue(
      AOwner + '.$resolve_' + AMethod, AResolved) and (AResolved <> '');
  end;
begin
  Result := '';
  if (AClassName = '') or (AMethodName = '') then
    Exit;
  OwnerName := PeelAliasClassName(AClassName);
  MemberName := AMethodName;
  if TryResolveTable(AClassName, MemberName, Resolved) or
    ((not SameText(OwnerName, AClassName)) and
      TryResolveTable(OwnerName, MemberName, Resolved)) then
    Exit(Resolved);

  FoundNonTObject := '';
  FoundAny := '';
  Candidate := OwnerName;
  Guard := 0;
  while (Candidate <> '') and (Guard < 16) do
  begin
    Inc(Guard);
    if ClassHasMethod(Candidate, MemberName) then
    begin
      if not SameText(Candidate, 'TObject') then
      begin
        FoundNonTObject := Candidate + '.' + MemberName;
        Break;
      end
      else if FoundAny = '' then
        FoundAny := Candidate + '.' + MemberName;
    end;
    Candidate := NextClassAncestorName(Candidate);
    if Candidate = '' then
      Break;
    { unit-qualified parent → short type name when full path is not registered. }
    if FModel.FindTypeByName(Candidate) <= 0 then
    begin
      DotPos := 0;
      for CharIdx := Length(Candidate) downto 1 do
        if Candidate[CharIdx] = '.' then
        begin
          DotPos := CharIdx;
          Break;
        end;
      if DotPos > 0 then
      begin
        ShortName := Copy(Candidate, DotPos + 1, MaxInt);
        if FModel.FindTypeByName(ShortName) > 0 then
          Candidate := ShortName;
      end;
    end;
  end;
  if FoundNonTObject <> '' then
    Exit(FoundNonTObject);
  if FoundAny <> '' then
    Exit(FoundAny);

  { CreateFmt rarely has a body on leaf exception classes; fall back to Create. }
  if SameText(MemberName, 'CreateFmt') then
  begin
    if TryResolveTable(AClassName, 'Create', Resolved) or
      TryResolveTable(OwnerName, 'Create', Resolved) then
      Exit(Resolved);
    Candidate := OwnerName;
    Guard := 0;
    while (Candidate <> '') and (Guard < 16) do
    begin
      Inc(Guard);
      if (not SameText(Candidate, 'TObject')) and
        ClassHasMethod(Candidate, 'Create') then
        Exit(Candidate + '.Create');
      Candidate := NextClassAncestorName(Candidate);
      if Candidate = '' then
        Break;
      if FModel.FindTypeByName(Candidate) <= 0 then
      begin
        DotPos := 0;
        for CharIdx := Length(Candidate) downto 1 do
          if Candidate[CharIdx] = '.' then
          begin
            DotPos := CharIdx;
            Break;
          end;
        if DotPos > 0 then
        begin
          ShortName := Copy(Candidate, DotPos + 1, MaxInt);
          if FModel.FindTypeByName(ShortName) > 0 then
            Candidate := ShortName;
        end;
      end;
    end;
  end;

  Result := OwnerName + '.' + MemberName;
end;

function TSemanticAnalyzer.TypeMetaVmtCount(const ATypeName: string): Int64;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaVmtCount(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaInterfaces(const ATypeName: string): string;
begin
  Result := nextpas.compiler.sema.type_check.TypeMetaInterfaces(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeSignatureForTypeId(const ATypeId: LongInt): string;
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
  Result := nextpas.compiler.sema.overload.TypeSignatureForTypeId(Ctx, ATypeId);
end;

function TSemanticAnalyzer.TypeIdHasStableScalarFact(
  const ATypeId: LongInt
): Boolean;
var
  TypeInfo: TSemanticType;
begin
  Result := False;
  if (ATypeId <= 0) or (ATypeId > FModel.TypeCount) then
    Exit;

  TypeInfo := FModel.TypeAt(ATypeId - 1);
  if FModel.TypeHasScalarFact(ATypeId) then
    Exit(True);

  if not SameText(TypeInfo.Kind, 'builtin') then
    Exit;

  Result :=
    SameText(TypeInfo.Name, 'AnsiString') or
    SameText(TypeInfo.Name, 'RawByteString') or
    SameText(TypeInfo.Name, 'ShortString') or
    SameText(TypeInfo.Name, 'WideString') or
    SameText(TypeInfo.Name, 'UnicodeString');
end;

function TSemanticAnalyzer.CallArgumentSignature(
  const ACallNode: TGreenNode;
  out ASignature: string
): Boolean;
var
  ArgNode: TGreenNode;
  ArgRoot: TGreenNode;
  ArgTypeId: LongInt;
  Index: LongInt;
  TypeSig: string;
begin
  ASignature := '';
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
  begin
    ArgNode := ArgRoot.ChildAt(Index);
    ArgTypeId := InferExpressionType(ArgNode);
    TypeSig := TypeSignatureForTypeId(ArgTypeId);
    if TypeSig = '' then
      Exit(False);
    ASignature := ASignature + TypeSig;
  end;
  Result := True;
end;

function TSemanticAnalyzer.CallArgumentTypeIds(
  const ACallNode: TGreenNode;
  out ATypeIds: TTypeIdArray
): Boolean;
