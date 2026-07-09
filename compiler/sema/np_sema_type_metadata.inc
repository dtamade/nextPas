
function TSemanticAnalyzer.TypeMetaFieldIndex(
  const ATypeName, AFieldName: string): Int64;
begin
  Result := np_sema_type_check.TypeMetaFieldIndex(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaFieldIsStr(
  const ATypeName, AFieldName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaFieldIsStr(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaFieldIsPtr(
  const ATypeName, AFieldName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaFieldIsPtr(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaFieldIsDynArray(
  const ATypeName, AFieldName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaFieldIsDynArray(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaFieldDynArrayElemSize(
  const ATypeName, AFieldName: string): Int64;
begin
  Result := np_sema_type_check.TypeMetaFieldDynArrayElemSize(FModel, ATypeName, AFieldName);
end;

function TSemanticAnalyzer.TypeMetaVmtSlot(
  const ATypeName, AMethodName: string): Int64;
begin
  Result := np_sema_type_check.TypeMetaVmtSlot(FModel, ATypeName, AMethodName);
end;

function TSemanticAnalyzer.TypeMetaRetPtr(
  const ATypeName, AMethodName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaRetPtr(FModel, ATypeName, AMethodName);
end;

function TSemanticAnalyzer.TypeMetaRetStr(
  const ATypeName, AMethodName: string): Boolean;
begin
  Result := np_sema_type_check.TypeMetaRetStr(FModel, ATypeName, AMethodName);
end;

function TSemanticAnalyzer.TypeMetaParentClass(const ATypeName: string): string;
begin
  Result := np_sema_type_check.TypeMetaParentClass(FModel, ATypeName);
end;

function TSemanticAnalyzer.NextClassAncestorName(const ATypeName: string): string;
begin
  Result := np_sema_type_check.NextClassAncestorName(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaVmtCount(const ATypeName: string): Int64;
begin
  Result := np_sema_type_check.TypeMetaVmtCount(FModel, ATypeName);
end;

function TSemanticAnalyzer.TypeMetaInterfaces(const ATypeName: string): string;
begin
  Result := np_sema_type_check.TypeMetaInterfaces(FModel, ATypeName);
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
  Result := np_sema_overload.TypeSignatureForTypeId(Ctx, ATypeId);
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
