function TSemanticAnalyzer.NewBlockLabel(const APrefix: string): string;
begin
  Inc(FBlockLabelCounter);
  Result := APrefix + IntToStr(FBlockLabelCounter);
end;

procedure TSemanticAnalyzer.RegisterRuntimeVar(const AName: string);
begin
  FRuntimeVars.RegisterRuntimeVar(AName);
end;

function TSemanticAnalyzer.IsRuntimeVar(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsRuntimeVar(AName);
end;

procedure TSemanticAnalyzer.RegisterRuntimeStrVar(const AName: string);
begin
  FRuntimeVars.RegisterRuntimeStrVar(AName);
end;

procedure TSemanticAnalyzer.RegisterOwnedRuntimeStrVar(const AName: string);
begin
  FRuntimeVars.RegisterOwnedRuntimeStrVar(AName);
end;

procedure TSemanticAnalyzer.RegisterBorrowedRuntimeStrVar(const AName: string);
begin
  FRuntimeVars.RegisterBorrowedRuntimeStrVar(AName);
end;

procedure TSemanticAnalyzer.RegisterOwnedStringReturnFunc(const AName: string);
begin
  FRuntimeVars.RegisterOwnedStringReturnFunc(AName);
end;

function TSemanticAnalyzer.IsRuntimeStrVar(const AName: string): Boolean;
var
  SymId: LongInt;
  TypeId: LongInt;
  TypeName: string;
begin
  { Check registered runtime string vars via FRuntimeVars }
  if FRuntimeVars.IsRuntimeStrVar(AName) then
    Exit(True);
  { Also accept any string-typed variable — they hold safe string values }
  SymId := FModel.FindSymbolByName(AName);
  if SymId > 0 then
  begin
    TypeId := FModel.SymbolAt(SymId - 1).TypeId;
    if TypeId > 0 then
    begin
      TypeName := FModel.TypeAt(TypeId - 1).Name;
      if SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString') then
        Exit(True);
    end;
  end;
  Result := False;
end;

function TSemanticAnalyzer.IsOwnedRuntimeStrVar(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsOwnedRuntimeStrVar(AName);
end;

function TSemanticAnalyzer.IsBorrowedRuntimeStrVar(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsBorrowedRuntimeStrVar(AName);
end;

function TSemanticAnalyzer.IsOwnedStringReturnFunc(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsOwnedStringReturnFunc(AName);
end;

procedure TSemanticAnalyzer.ClearPendingStringTempReleases;
begin
  FRuntimeVars.ClearPendingStringTempReleases;
end;

procedure TSemanticAnalyzer.QueuePendingStringTempRelease(
  const ATempName, ASourceName: string);
begin
  FRuntimeVars.QueuePendingStringTempRelease(ATempName, ASourceName);
end;

procedure TSemanticAnalyzer.EmitPendingStringTempReleases;
var
  I: LongInt;
  TempNames: TStringArray;
  TempSources: TStringArray;
begin
  TempNames := FRuntimeVars.GetPendingStringTempNames;
  TempSources := FRuntimeVars.GetPendingStringTempSources;
  for I := High(TempNames) downto 0 do
    FModel.AddTypedHirNode('string-temp-release-runtime',
      TempSources[I], 0, 0, TempNames[I]);
  FRuntimeVars.ClearPendingStringTempReleases;
end;

procedure TSemanticAnalyzer.RegisterConcatOwnedStringReturnConsumers(
  const AConcatNode: TGreenNode; var AChanged: Boolean);
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  nextpas.compiler.sema.string_ownership.RegisterConcatOwnedStringReturnConsumers(Ctx, AConcatNode, AChanged);
end;


function TSemanticAnalyzer.IsRootOwnedStringReturnCandidate(
  const AEntry: TProcedureBodyEntry; const AIsStrReturn: Boolean): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.IsRootOwnedStringReturnCandidate(Ctx, AEntry, AIsStrReturn);
end;


function TSemanticAnalyzer.DeclReturnsString(const ADecl: TGreenNode): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.DeclReturnsString(ADecl);
end;

function TSemanticAnalyzer.DeclaresStringLocal(const ADecl: TGreenNode;
  const AName: string): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.DeclaresStringLocal(ADecl, AName);
end;

function TSemanticAnalyzer.StringReturnFunctionNameFromNode(
  const ANode: TGreenNode; out AName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.StringReturnFunctionNameFromNode(
    Ctx, ANode, AName);
end;

function TSemanticAnalyzer.FunctionCallReturnsString(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.FunctionCallReturnsString(Ctx, ANode);
end;

function TSemanticAnalyzer.MemberCallReturnsString(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.MemberCallReturnsString(Ctx, ANode);
end;

function TSemanticAnalyzer.TypeIdIsManagedString(
  const ATypeId: LongInt): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.TypeIdIsManagedString(Ctx, ATypeId);
end;

function TSemanticAnalyzer.IsSupportedOwnedStringReturnIdentifierTarget(
  const ATargetNode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.IsSupportedOwnedStringReturnIdentifierTarget(Ctx, ATargetNode);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnStoreTarget(
  const ATargetNode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.IsSupportedOwnedStringReturnStoreTarget(Ctx, ATargetNode);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnConsumerTarget(
  const ATargetNode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.IsSupportedOwnedStringReturnConsumerTarget(Ctx, ATargetNode);
end;


function TSemanticAnalyzer.AssignmentOwnsStringReturn(const ANode: TGreenNode;
  const AEntry: TProcedureBodyEntry): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.AssignmentOwnsStringReturn(Ctx, ANode, AEntry);
end;


function TSemanticAnalyzer.AssignmentOwnsTopLevelStringReturn(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.AssignmentOwnsTopLevelStringReturn(Ctx, ANode);
end;


function TSemanticAnalyzer.CallArgumentOwnsStringReturn(
  const ACallNode, AArgNode: TGreenNode; AArgPosition: LongInt;
  out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.CallArgumentOwnsStringReturn(Ctx, ACallNode, AArgNode, AArgPosition, AFuncName);
end;


function TSemanticAnalyzer.DirectOwnedStringReturnAssignmentNode(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.DirectOwnedStringReturnAssignmentNode(Ctx, ANode);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnArgument(
  const ACallNode, AArgNode: TGreenNode; AArgPosition: LongInt): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.IsSupportedOwnedStringReturnArgument(Ctx, ACallNode, AArgNode, AArgPosition);
end;


function TSemanticAnalyzer.LengthArgumentOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.LengthArgumentOwnsStringReturn(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnLengthArgument(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.IsSupportedOwnedStringReturnLengthArgument(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.EmitOwnedStringLengthTemp(const ANode: TGreenNode;
  out ABlob: string): Boolean;
var
  SourceName, TempName, Operand: string;
  CallNode: TGreenNode;
begin
  { Encode nested call formals (recvar / str / ints). The free ownership
    helper only emitted a no-arg sret call (ptr len owner alloc_size stub),
    which broke Length(GetS(R)) — missing const record formal. }
  ABlob := '';
  Result := False;
  if not IsSupportedOwnedStringReturnLengthArgument(ANode, SourceName) then
    Exit;
  if (ANode.ChildCount < 2) or (ANode.ChildAt(1) = nil) then
    Exit;
  CallNode := ANode.ChildAt(1);
  Inc(FBlockLabelCounter);
  TempName := '$str_len_tmp_' + IntToStr(FBlockLabelCounter);
  RegisterRuntimeVar(TempName);
  RegisterRuntimeStrVar(TempName);
  Operand := EncodeStrCallArgs(CallNode, TempName);
  FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0, TempName);
  FModel.AddTypedHirNode('string-temp-owned-runtime', SourceName, 0, 0,
    TempName + #9 + 'callee ' + EffectiveRuntimeCalleeName(SourceName, nil) + #9 + Operand);
  FModel.AddTypedHirNode('string-temp-length-runtime', SourceName, 0, 0,
    'strvar ' + TempName + #10);
  FModel.AddTypedHirNode('string-temp-release-runtime', SourceName, 0, 0,
    TempName);
  ABlob := 'var ' + TempName + '$len' + #10;
  Result := True;
end;


function TSemanticAnalyzer.EmitOwnedStringConcatLengthTemp(
  const ANode: TGreenNode; out ABlob: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.EmitOwnedStringConcatLengthTemp(Ctx, ANode, ABlob);
end;


function TSemanticAnalyzer.CopyArgumentOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.CopyArgumentOwnsStringReturn(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnCopyArgument(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.IsSupportedOwnedStringReturnCopyArgument(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.EmitOwnedStringCopyTemp(const ACopyNode: TGreenNode;
  const ADestName: string; out ATempName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.EmitOwnedStringCopyTemp(Ctx, ACopyNode, ADestName, ATempName);
end;


function TSemanticAnalyzer.WriteArgumentOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.WriteArgumentOwnsStringReturn(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnWriteArgument(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.IsSupportedOwnedStringReturnWriteArgument(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.EmitOwnedStringWriteTemp(
  const ANode: TGreenNode; out ATempName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.EmitOwnedStringWriteTemp(Ctx, ANode, ATempName);
end;


function TSemanticAnalyzer.EmitOwnedStringConcatWriteTemp(
  const ANode: TGreenNode; out ATempName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.EmitOwnedStringConcatWriteTemp(Ctx, ANode, ATempName);
end;


function TSemanticAnalyzer.ConcatOperandOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.ConcatOperandOwnsStringReturn(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnConcatOperand(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.IsSupportedOwnedStringReturnConcatOperand(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.ConcatExpressionConsumesOwnedStringReturnDeferred(
  const ANode: TGreenNode; const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.ConcatExpressionConsumesOwnedStringReturnDeferred(Ctx, ANode, AInsideDirectOwnedAssignmentRhs);
end;


function TSemanticAnalyzer.CompareOperandOwnsStringReturn(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.CompareOperandOwnsStringReturn(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.IsSupportedOwnedStringReturnCompareOperand(
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.IsSupportedOwnedStringReturnCompareOperand(Ctx, ANode, AFuncName);
end;


function TSemanticAnalyzer.BoolConditionHasSupportedOwnedStringCompare(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.BoolConditionHasSupportedOwnedStringCompare(Ctx, ANode);
end;


function TSemanticAnalyzer.CompareExpressionConsumesOwnedStringReturnDeferred(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.CompareExpressionConsumesOwnedStringReturnDeferred(Ctx, ANode);
end;


function TSemanticAnalyzer.NodeConsumesOwnedStringReturnDeferred(
  const ANode: TGreenNode;
  const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.NodeConsumesOwnedStringReturnDeferred(Ctx, ANode, AInsideDirectOwnedAssignmentRhs);
end;


procedure TSemanticAnalyzer.ScanOwnedStringReturnConsumers(
  const ANode: TGreenNode; const AEntry: TProcedureBodyEntry;
  var AChanged: Boolean);
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  nextpas.compiler.sema.string_ownership.ScanOwnedStringReturnConsumers(Ctx, ANode, AEntry, AChanged);
end;


procedure TSemanticAnalyzer.ScanTopLevelOwnedStringReturnConsumers(
  const ANode: TGreenNode; var AChanged: Boolean);
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  nextpas.compiler.sema.string_ownership.ScanTopLevelOwnedStringReturnConsumers(Ctx, ANode, AChanged);
end;


procedure TSemanticAnalyzer.CheckDeferredOwnedStringReturnConsumers(
  const ANode: TGreenNode);
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  nextpas.compiler.sema.string_ownership.CheckDeferredOwnedStringReturnConsumers(Ctx, ANode);
end;


procedure TSemanticAnalyzer.PreRegisterOwnedStringReturnConsumers;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  nextpas.compiler.sema.string_ownership.PreRegisterOwnedStringReturnConsumers(Ctx);
end;


procedure TSemanticAnalyzer.RegisterRuntimeArrVar(const AName: string);
begin
  FRuntimeVars.RegisterRuntimeArrVar(AName);
end;

procedure TSemanticAnalyzer.RegisterBorrowedRuntimeArrVar(const AName: string);
begin
  FRuntimeVars.RegisterBorrowedRuntimeArrVar(AName);
end;

function TSemanticAnalyzer.IsRuntimeArrVar(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsRuntimeArrVar(AName);
end;

function TSemanticAnalyzer.IsBorrowedRuntimeArrVar(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsBorrowedRuntimeArrVar(AName);
end;

function TSemanticAnalyzer.IsStaticRuntimeArrVar(const AName: string): Boolean;
var
  Value: Int64;
begin
  Result := FModel.LookupConstValue(AName + '$arr_static', Value) and
    (Value <> 0);
end;

function TSemanticAnalyzer.DynArrayElemSizeOfVar(const AName: string): Int64;
begin
  Result := 8;
  if not FModel.LookupConstValue(AName + '$arr_elem_size', Result) then
    Result := 8;
end;

procedure TSemanticAnalyzer.EmitOwnedStringCleanupNodes(const AExceptName: string);
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  nextpas.compiler.sema.string_ownership.EmitOwnedStringCleanupNodes(Ctx, AExceptName);
end;


procedure TSemanticAnalyzer.EmitOwnedDynArrayCleanupNodes;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  nextpas.compiler.sema.string_ownership.EmitOwnedDynArrayCleanupNodes(Ctx);
end;


function TSemanticAnalyzer.IsManagedRecord(const ATypeName: string): Boolean;
var
  Meta: TTypeMetadata;
  I: LongInt;
begin
  Result := False;
  if not FModel.GetTypeMetaByName(ATypeName, Meta) then
    Exit;
  if not Meta.IsRecord then
    Exit;
  if Meta.Fields = nil then
    Exit(False);
  for I := 0 to LongInt(Meta.Fields.Count) - 1 do
  begin
    if Meta.Fields[SizeUInt(I)].IsString or Meta.Fields[SizeUInt(I)].IsDynArray then
      Exit(True);
    { 递归检查嵌套 record }
    if Meta.Fields[SizeUInt(I)].IsRecord then
    begin
      if (Meta.Fields[SizeUInt(I)].TypeId > 0) and
        (Meta.Fields[SizeUInt(I)].TypeId <= FModel.TypeCount) and
        IsManagedRecord(FModel.TypeAt(Meta.Fields[SizeUInt(I)].TypeId - 1).Name) then
        Exit(True);
    end;
  end;
end;

procedure TSemanticAnalyzer.EmitOwnedManagedRecordCleanupNodes;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  nextpas.compiler.sema.string_ownership.EmitOwnedManagedRecordCleanupNodes(Ctx);
end;

procedure TSemanticAnalyzer.EmitClassVarFreeCleanupNodes;
var
  I, Value: LongInt;
  VarName, ClsName, DestroyFuncName, FuncName: string;
  ClassNames, ClassTypes: TStringArray;
begin
  ClassNames := FRuntimeVars.GetClassVarNames;
  ClassTypes := FRuntimeVars.GetClassVarTypes;
  for I := 0 to Length(ClassNames) - 1 do
  begin
    VarName := ClassNames[I];
    ClsName := ClassTypes[I];
    if (VarName = '') or (ClsName = '') then
      Continue;
    { 8-bit char/byte/bool params register as pseudo class vars to get the
      pointer-slot ABI; Pointer covers P^ deref lookups. Neither is an object
      — emitting an object-free guard on them yields a dead null-check
      template (IsSep/StrLen residuals). }
    if SameText(ClsName, 'Pointer') then
      Continue;
    if TypeMetaSize(ClsName) = 1 then
      Continue;
    DestroyFuncName := ClsName + '.Destroy';
    Value := TypeMetaVmtSlot(ClsName, 'Destroy');
    if (Value >= 0) and FModel.LookupStringConstValue(
      ClsName + '$vmt_func_' + IntToStr(Value), FuncName
    ) then
      DestroyFuncName := FuncName;
    FModel.AddTypedHirNode(
      'object-free-runtime',
      NPSYSTEM_OBJECT_FREE,
      0, 0,
      'var ' + VarName + #10 +
      'destroy ' + DestroyFuncName + #10 +
      'cleanup-class ' + ClsName + #10 +
      'nil-guard true' + #10 +
      'heap-release true' + #10
    );
  end;
end;


procedure TSemanticAnalyzer.RegisterClassVar(const AName, AClassName: string);
var
  V: Int64;
begin
  if FModel.LookupConstValue(FRuntimeVars.LookupClassVar(AName) + '$vmt_count', V) and
    TypeMetaIsInterface(FRuntimeVars.LookupClassVar(AName)) then
    Exit;
  FRuntimeVars.RegisterClassVar(AName, AClassName);
end;

function TSemanticAnalyzer.LookupClassVar(const AName: string): string;
begin
  Result := FRuntimeVars.LookupClassVar(AName);
end;

procedure TSemanticAnalyzer.RegisterRecordVar(const AName, ATypeName: string);
begin
  FRuntimeVars.RegisterRecordVar(AName, ATypeName);
end;

procedure TSemanticAnalyzer.RegisterPointerVar(const AName,
  APointeeTypeName: string);
begin
  FRuntimeVars.RegisterPointerVar(AName, APointeeTypeName);
end;

function TSemanticAnalyzer.IsRecordVar(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsRecordVar(AName);
end;

procedure TSemanticAnalyzer.RegisterVarParam(const AName: string);
begin
  FRuntimeVars.RegisterVarParam(AName);
end;

function TSemanticAnalyzer.IsVarParam(const AName: string): Boolean;
begin
  Result := FRuntimeVars.IsVarParam(AName);
end;

function TSemanticAnalyzer.IsVarParamAtPosition(
  const ADecl: TGreenNode; APosition: LongInt): Boolean;
var
  J, K, ParamIdx: LongInt;
  Child, ParamChild: TGreenNode;
begin
  Result := False;
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      ParamIdx := 0;
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild = nil) or (ParamChild.NodeKind <> gnkParameterDecl) then
          Continue;
        if ParamIdx = APosition then
        begin
          Result := ParamNameIsByRef(ParamChild.Text);
          Exit;
        end;
        Inc(ParamIdx);
      end;
      Exit;
    end;
  end;
end;

function TSemanticAnalyzer.LookupRecordVar(const AName: string): string;
begin
  Result := FRuntimeVars.LookupRecordVar(AName);
end;

function TSemanticAnalyzer.LookupPointerVar(const AName: string): string;
begin
  Result := FRuntimeVars.LookupPointerVar(AName);
end;

procedure TSemanticAnalyzer.RegisterPtrReturnFunc(const AName, AClassName: string);
begin
  FRuntimeVars.RegisterPtrReturnFunc(AName, AClassName);
end;

procedure TSemanticAnalyzer.RegisterImportedUnitTree(const ATree: TGreenTree;
  const AOwnerUnitId: string);
begin
  if ATree = nil then
    Exit;
  FImportedUnitTrees.Push(ATree);
  FImportedUnitOwners.Push(AOwnerUnitId);
end;

function TSemanticAnalyzer.LookupPtrReturnFunc(const AName: string): string;
begin
  Result := FRuntimeVars.LookupPtrReturnFunc(AName);
end;

function TSemanticAnalyzer.EmitStrConcatOperand(const ANode: TGreenNode;
  const ADestVar: string): string;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.EmitStrConcatOperand(Ctx, ANode, ADestVar);
end;


function TSemanticAnalyzer.ConcatTreeHasSupportedOwnedStringReturn(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.ConcatTreeHasSupportedOwnedStringReturn(Ctx, ANode);
end;


function TSemanticAnalyzer.CanEmitStrConcatOperand(
  const ANode: TGreenNode): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.CanEmitStrConcatOperand(Ctx, ANode);
end;


function TSemanticAnalyzer.CanEmitStrCompareOperand(const ANode: TGreenNode;
  const AAllowOwnedStringReturn: Boolean): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.CanEmitStrCompareOperand(Ctx, ANode, AAllowOwnedStringReturn);
end;


function TSemanticAnalyzer.EmitStrCompareOperand(const ANode: TGreenNode;
  const AAllowOwnedStringReturn: Boolean; out ABlob: string): Boolean;
var
  Ctx: TSemaOwnershipContext;
begin
  FillOwnershipContext(Ctx);
  Result := nextpas.compiler.sema.string_ownership.EmitStrCompareOperand(Ctx, ANode, AAllowOwnedStringReturn, ABlob);
end;


function TSemanticAnalyzer.EncodeStrCallArgs(const ACallNode: TGreenNode;
  const ADestVar: string): string;
var
  ArgIndex: LongInt;
  ArgNode: TGreenNode;
  Blob, LitValue, SourceName, TempName: string;
begin
  Result := '';
  ArgIndex := 0;
  if ACallNode.NodeKind = gnkFunctionCall then
    ArgIndex := 1;
  ClearPendingStringTempReleases;
  while ArgIndex < ACallNode.ChildCount do
  begin
    ArgNode := ACallNode.ChildAt(ArgIndex);
    if ArgNode = nil then
    begin
      Inc(ArgIndex);
      Continue;
    end;
    if (ArgNode.NodeKind = gnkIdentifier) and IsRuntimeStrVar(ArgNode.Text) then
      Blob := 'strvar ' + ArgNode.Text + #10
    else if (ArgNode.NodeKind = gnkIdentifier) and IsRuntimeArrVar(ArgNode.Text) then
      { open-array / array of const formal → (ptr,len) like strvar }
      Blob := 'arrvar ' + ArgNode.Text + #10
    else if (ArgNode.NodeKind = gnkIdentifier) and IsRecordVar(ArgNode.Text) then
      { const/var record formal (Batch 25 Length(GetS(R))). }
      Blob := 'recvar ' + ArgNode.Text + #10
    else if IsSupportedOwnedStringReturnArgument(ACallNode, ArgNode,
      ArgIndex - 1) and StringReturnFunctionNameFromNode(ArgNode, SourceName) then
    begin
      Inc(FBlockLabelCounter);
      TempName := '$str_arg_tmp_' + IntToStr(FBlockLabelCounter);
      RegisterRuntimeVar(TempName);
      RegisterRuntimeStrVar(TempName);
      FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName,
        0, 0, TempName);
      FModel.AddTypedHirNode('string-temp-owned-runtime', SourceName,
        0, 0, TempName + #9 + 'callee ' + EffectiveRuntimeCalleeName(SourceName, nil) + #9 +
        'ptr len owner alloc_size');
      FModel.AddTypedHirNode('string-temp-borrow-arg-runtime',
        ACallNode.Text, 0, 0, 'strvar ' + TempName + #10);
      QueuePendingStringTempRelease(TempName, SourceName);
      Blob := 'strvar ' + TempName + #10;
    end
    else if (ArgNode.NodeKind = gnkIdentifier) and
      EvaluateStringConstant(ArgNode, LitValue) then
    begin
      { String const identifier formal (PATH_ENV_PREFIX='PATH='): materialize
        as literal temp, not residual call @CONST() (M2 const-upper). }
      Blob := EmitStrConcatOperand(ArgNode, ADestVar);
      if Blob <> '' then
        Blob := 'strvar ' + Blob + #10
      else
        Blob := '';
    end
    else if ArgNode.NodeKind = gnkStringLiteral then
    begin
      LitValue := DecodePascalStringLiteral(ArgNode.Text);
      Blob := EmitStrConcatOperand(ArgNode, ADestVar);
      if Blob <> '' then
        Blob := 'strvar ' + Blob + #10
      else
        Blob := '';
    end
    else if EncodeRuntimeIntExprFold(ArgNode, Blob) then
      { Blob already set }
    else
      Blob := '';
    if Blob <> '' then
    begin
      if Result <> '' then
        Result := Result + #9 + Blob
      else
        Result := Blob;
    end;
    Inc(ArgIndex);
  end;
end;

function TSemanticAnalyzer.IsExceptionHandlerVar(const AName: string): Boolean;
var
  I: SizeUInt;
begin
  Result := False;
  if (FExceptionHandlerVars = nil) or (FExceptionHandlerVars.Count = 0) then
    Exit;
  for I := 0 to FExceptionHandlerVars.Count - 1 do
    if SameText(FExceptionHandlerVars[I], AName) then
      Exit(True);
end;

function TSemanticAnalyzer.EncodeExceptionMemberStrTemp(const ABaseName,
  AMemberName: string; out ATempName: string): Boolean;
var
  ClsName, FieldName: string;
  FieldIdx: Int64;

  function ResolveFieldIdx(const AType, AMember: string; out AFieldName: string): Int64;
  begin
    { 属性 read 目标优先，其次裸字段名，最后 Pascal 惯例 F 前缀字段 }
    if FModel.LookupStringConstValue(AType + '.' + AMember + '$read', AFieldName) and
      (TypeMetaFieldIndex(AType, AFieldName) >= 0) then
      Exit(TypeMetaFieldIndex(AType, AFieldName));
    AFieldName := AMember;
    Result := TypeMetaFieldIndex(AType, AMember);
    if Result < 0 then
    begin
      AFieldName := 'F' + AMember;
      Result := TypeMetaFieldIndex(AType, AFieldName);
    end;
  end;

begin
  ATempName := '';
  ClsName := LookupClassVar(ABaseName);
  if ClsName = '' then
    Exit(False);
  FieldIdx := ResolveFieldIdx(ClsName, AMemberName, FieldName);
  if (FieldIdx < 0) or (not TypeMetaFieldIsStr(ClsName, FieldName)) then
  begin
    { 空子类可能未重注册继承字段——异常对象前缀布局对所有子类一致，
      直接按基类 Exception 解析槽位 }
    ClsName := 'Exception';
    FieldIdx := ResolveFieldIdx(ClsName, AMemberName, FieldName);
    if (FieldIdx < 0) or (not TypeMetaFieldIsStr(ClsName, FieldName)) then
      Exit(False);
  end;
  Inc(FBlockLabelCounter);
  ATempName := '$str_arg_tmp_' + IntToStr(FBlockLabelCounter);
  RegisterRuntimeVar(ATempName);
  RegisterRuntimeStrVar(ATempName);
  FModel.AddTypedHirNode('var-decl-tstring-runtime', ATempName, 0, 0, ATempName);
  FModel.AddTypedHirNode('assign-tstring-field-load-runtime', ATempName, 0, 0,
    ABaseName + #9 + IntToStr(FieldIdx));
  FLastCallArgsUsedExcMember := True;
  Result := True;
end;

function TSemanticAnalyzer.EncodeCallStatementArgs(
  const ACallName: string; const ACallNode, ADeclNode: TGreenNode): string;
var
  ArgIndex, ParamIndex: LongInt;
  ArgNode: TGreenNode;
  Decoded, SourceName, TempName: string;
begin
  Result := ACallName;
  FLastCallArgsUsedExcMember := False;
  ClearPendingStringTempReleases;
  if ACallNode = nil then
    Exit;
  if ACallNode.NodeKind = gnkFunctionCall then
    ArgIndex := 1
  else
    ArgIndex := 0;
  ParamIndex := 0;
  while ArgIndex < ACallNode.ChildCount do
  begin
    ArgNode := ACallNode.ChildAt(ArgIndex);
    if (ArgNode <> nil) and (ArgNode.NodeKind = gnkIdentifier) and
      IsVarParamAtPosition(ADeclNode, ParamIndex) and
      IsRuntimeVar(ArgNode.Text) then
      Result := Result + #9 + 'varref ' + ArgNode.Text + #10
    else if (ArgNode <> nil) and (ArgNode.NodeKind = gnkIdentifier) and
      IsRuntimeStrVar(ArgNode.Text) then
      Result := Result + #9 + 'strvar ' + ArgNode.Text + #10
    else if (ArgNode <> nil) and (ArgNode.NodeKind = gnkIdentifier) and
      IsRuntimeArrVar(ArgNode.Text) then
      Result := Result + #9 + 'arrvar ' + ArgNode.Text + #10
    else if (ArgNode <> nil) and IsSupportedOwnedStringReturnArgument(
      ACallNode, ArgNode, ParamIndex) and
      StringReturnFunctionNameFromNode(ArgNode, SourceName) then
    begin
      Inc(FBlockLabelCounter);
      TempName := '$str_arg_tmp_' + IntToStr(FBlockLabelCounter);
      RegisterRuntimeVar(TempName);
      RegisterRuntimeStrVar(TempName);
      FModel.AddTypedHirNode('var-decl-tstring-runtime', TempName,
        0, 0, TempName);
      FModel.AddTypedHirNode('string-temp-owned-runtime', SourceName,
        0, 0, TempName + #9 + 'callee ' + EffectiveRuntimeCalleeName(SourceName, nil) + #9 +
        'ptr len owner alloc_size');
      FModel.AddTypedHirNode('string-temp-borrow-arg-runtime',
        ACallName, 0, 0, 'strvar ' + TempName + #10);
      QueuePendingStringTempRelease(TempName, SourceName);
      Result := Result + #9 + 'strvar ' + TempName + #10;
    end
    else if (ArgNode <> nil) and (ArgNode.NodeKind = gnkIdentifier) and
      EvaluateStringConstant(ArgNode, Decoded) then
      { String const identifier formal: fold to strlit, not residual
        call @CONST() (M2 const-upper). }
      Result := Result + #9 + 'strlit ' +
        EncodePascalStringLiteral(Decoded) + #10
    else if (ArgNode <> nil) and (ArgNode.NodeKind = gnkStringLiteral) then
      Result := Result + #9 + 'strlit ' + ArgNode.Text + #10
    else if (ArgNode <> nil) and (ArgNode.NodeKind = gnkDotAccess) and
      (ArgNode.ChildCount >= 2) and
      (ArgNode.ChildAt(0).NodeKind = gnkIdentifier) and
      (ArgNode.ChildAt(1).NodeKind = gnkIdentifier) and
      IsExceptionHandlerVar(ArgNode.ChildAt(0).Text) and
      EncodeExceptionMemberStrTemp(
        ArgNode.ChildAt(0).Text, ArgNode.ChildAt(1).Text, TempName) then
      Result := Result + #9 + 'strvar ' + TempName + #10
    else if (ArgNode <> nil) and EncodeRuntimeIntExprFold(ArgNode, Decoded) then
      Result := Result + #9 + Decoded;
    Inc(ArgIndex);
    Inc(ParamIndex);
  end;
end;

procedure TSemanticAnalyzer.EmitBlockLabel(const ALabel: string);
var Ctx: TSemaHirLoweringContext;
begin
  Ctx.Model := FModel;
  Ctx.CurrentBlockTerminated := FCurrentBlockTerminated;
  nextpas.compiler.ir.hir.lowering.EmitBlockLabel(Ctx, ALabel);
  FCurrentBlockTerminated := Ctx.CurrentBlockTerminated;
end;

procedure TSemanticAnalyzer.EmitGotoLabel(const ALabel: string);
var Ctx: TSemaHirLoweringContext;
begin
  Ctx.Model := FModel;
  Ctx.CurrentBlockTerminated := FCurrentBlockTerminated;
  nextpas.compiler.ir.hir.lowering.EmitGotoLabel(Ctx, ALabel);
  FCurrentBlockTerminated := Ctx.CurrentBlockTerminated;
end;
destructor TSemanticAnalyzer.Destroy;
var
  Index: LongInt;
  Pending: PPendingSignatureEntry;
begin
  if FImportedUnitTrees <> nil then
    for Index := 0 to LongInt(FImportedUnitTrees.Count) - 1 do
      FImportedUnitTrees[Index].Free;
  FImportedUnitTrees.Free;
  FImportedUnitOwners.Free;
  FBreakLabels.Free;
  FContinueLabels.Free;
  { FVarParamNames now managed by FRuntimeVars }
  FInliningStack.Free;
  FExceptionHandlerVars.Free;
  FGenericCache.Free;
  FCompilerProcNames.Free;
  FGenericWorkQueue.Free;
  FGenericRetrySpecs.Free;
  if FPendingSignatures <> nil then
  begin
    for Index := 0 to LongInt(FPendingSignatures.Count) - 1 do
    begin
      Pending := FPendingSignatures.GetPtr(SizeUInt(Index));
      Pending^.ParamNames.Free;
      Pending^.ParamNames := nil;
      Pending^.ArgTypes.Free;
      Pending^.ArgTypes := nil;
    end;
  end;
  FPendingSignatures.Free;
  FProcedureBodies.Free;
  FProcedureBodyNameNext.Free;
  FProcedureBodyNameNext := nil;
  FProcedureBodyNameFirst.Free;
  FProcedureBodyNameFirst := nil;
  FBuiltinRegistry.Free;
  FRuntimeVars.Free;
  FModel.Free;
  inherited Destroy;
end;
