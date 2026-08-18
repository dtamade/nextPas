{ P^.F classification via the pointer-var registry: pointee type + field
  index, or decline when the base is not a registered pointer var. }
function TSemanticAnalyzer.TryPointerFieldAccess(const ALocalNode: TGreenNode;
  out APointerName, APointeeTypeName, AFieldName: string;
  out AFieldIndex: Int64): Boolean;
var
  BaseNode, DerefNode, FieldNode: TGreenNode;
begin
  APointerName := '';
  APointeeTypeName := '';
  AFieldName := '';
  AFieldIndex := -1;
  if (ALocalNode = nil) or (ALocalNode.NodeKind <> gnkDotAccess) or
    (ALocalNode.ChildCount < 2) then
    Exit(False);
  DerefNode := ALocalNode.ChildAt(0);
  FieldNode := ALocalNode.ChildAt(1);
  if (DerefNode = nil) or (DerefNode.NodeKind <> gnkDereference) or
    (DerefNode.ChildCount < 1) or (FieldNode = nil) or
    (FieldNode.NodeKind <> gnkIdentifier) then
    Exit(False);
  BaseNode := DerefNode.ChildAt(0);
  if (BaseNode = nil) or (BaseNode.NodeKind <> gnkIdentifier) then
    Exit(False);
  APointerName := BaseNode.Text;
  APointeeTypeName := LookupPointerVar(APointerName);
  if APointeeTypeName = '' then
    Exit(False);
  AFieldName := FieldNode.Text;
  AFieldIndex := TypeMetaFieldIndex(APointeeTypeName, AFieldName);
  Result := AFieldIndex >= 0;
end;

{ Address blob for a by-ref formal receiving a field-access argument:
  P^.F via pointer-var registry, or B.F when B resolves as a pointer var,
  or B.F when B is a record-typed symbol ('varref' address channel).
  Emits base ptr + 'field_ref' (gep, no load) — the value paths append
  arr_load instead, which starves the callee's address expectation.
  Shared by the expression-position residual-call encoder and the
  statement-position EncodeCallStatementArgs (tree-exit139 family). }
function TSemanticAnalyzer.TryByRefFieldAddressBlob(
  const ALocalNode: TGreenNode; out ABlob: string): Boolean;
var
  BaseName, FieldName: string;
  TypeNameK: string;
  FieldIdx: Int64;
  SymbolIdTmp, TypeIdTmp: LongInt;
begin
  ABlob := '';
  if (ALocalNode = nil) or (ALocalNode.NodeKind <> gnkDotAccess) or
    (ALocalNode.ChildCount < 2) then
    Exit(False);
  if TryPointerFieldAccess(ALocalNode, BaseName, TypeNameK, FieldName,
    FieldIdx) then
  begin
    ABlob := 'var ' + BaseName + #10 + 'field_ref ' +
      IntToStr(FieldIdx) + #10;
    Exit(True);
  end;
  if (ALocalNode.ChildAt(0) <> nil) and
    (ALocalNode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ALocalNode.ChildAt(1) <> nil) and
    (ALocalNode.ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    BaseName := ALocalNode.ChildAt(0).Text;
    FieldName := ALocalNode.ChildAt(1).Text;
    { Result aliases the current sret retvar alloca (record-returning
      functions pass Result.X by address like any record base). }
    if SameText(BaseName, 'Result') and (FCurrentRetVarName <> '') then
      BaseName := FCurrentRetVarName;
    { Pointer-var base: slot holds the pointer, plain load yields it. }
    TypeNameK := LookupPointerVar(BaseName);
    if TypeNameK <> '' then
    begin
      FieldIdx := TypeMetaFieldIndex(TypeNameK, FieldName);
      if FieldIdx >= 0 then
      begin
        ABlob := 'var ' + BaseName + #10 + 'field_ref ' +
          IntToStr(FieldIdx) + #10;
        Exit(True);
      end;
    end;
    { Record-typed base (var-param/local/global record): address channel is
      'varref' — builder pushes the alloca, or single-derefs var-param
      allocas to the caller record pointer (never the double-deref value
      that 'var' would give). Symbol table supplies the declared type;
      seeded-body locals register via RegisterRecordVar only (no model
      symbol), so fall back to that registry before declining. }
    SymbolIdTmp := FModel.FindSymbolByName(BaseName);
    TypeIdTmp := 0;
    TypeNameK := '';
    FieldIdx := -1;
    if SymbolIdTmp > 0 then
      TypeIdTmp := FModel.SymbolTypeId(SymbolIdTmp);
    if TypeIdTmp > 0 then
      TypeNameK := FModel.TypeAt(TypeIdTmp - 1).Name;
    if (TypeNameK = '') or (not TypeMetaIsRecord(TypeNameK)) then
      TypeNameK := LookupRecordVar(BaseName);
    if (TypeNameK <> '') and TypeMetaIsRecord(TypeNameK) then
    begin
      FieldIdx := TypeMetaFieldIndex(TypeNameK, FieldName);
      if FieldIdx >= 0 then
      begin
        ABlob := 'varref ' + BaseName + #10 + 'field_ref ' +
          IntToStr(FieldIdx) + #10;
        Exit(True);
      end;
    end;
    if GetEnvDefault('NEXTPAS_DEBUG', '') = '1' then
      WriteLn(StdErr, '[byref-field] declined base=', BaseName,
        ' field=', FieldName, ' sym=', SymbolIdTmp,
        ' typeid=', TypeIdTmp, ' type="', TypeNameK,
        '" isrec=', TypeMetaIsRecord(TypeNameK), ' fieldidx=', FieldIdx);
  end;
  Result := False;
end;

function TSemanticAnalyzer.EncodeRuntimeIntExprFoldCore(
  const ANode: TGreenNode; out ABlob: string; out AExprId: LongInt): Boolean;

  function NeedsFoldFallback(const N: TGreenNode): Boolean;
  var
    I: LongInt;
    Child: TGreenNode;
  begin
    if N = nil then
      Exit(False);
    if (N.NodeKind = gnkIdentifier) and (N.Text <> '') and
      not IsRuntimeVar(N.Text) then
      Exit(True);
    if N.NodeKind = gnkFunctionCall then
      Exit(True);
    for I := 0 to N.ChildCount - 1 do
    begin
      Child := N.ChildAt(I);
      if (Child <> nil) and NeedsFoldFallback(Child) then
        Exit(True);
    end;
    Result := False;
  end;

  { Element byte size of a pointer pointee (PInt32 → alias target Int32 → 4).
    PChar/… stay 1; anything unresolved defaults to 1. }
  function PointeeElemSizeCode(const ATypeName: string): Int64;
  var
    TmpId, TmpTarget: LongInt;
    TmpMeta: TTypeMetadata;
  begin
    Result := 1;
    if ATypeName = '' then
      Exit;
    TmpId := FModel.FindTypeByName(ATypeName);
    if TmpId <= 0 then
      Exit;
    if FModel.GetTypeMeta(TmpId, TmpMeta) and (TmpMeta.Size > 1) and
      (TmpMeta.AliasTargetTypeId > 0) then
    begin
      TmpTarget := TmpMeta.AliasTargetTypeId;
      if FModel.GetTypeMeta(TmpTarget, TmpMeta) and (TmpMeta.Size > 1) then
        Result := TmpMeta.Size;
    end
    else if FModel.GetTypeMeta(TmpId, TmpMeta) and (TmpMeta.Size > 1) then
      Result := TmpMeta.Size;
  end;

  { Element byte size of a pointer pointee (PInt32 → alias target Int32 → 4).
    PChar/… stay 1; anything unresolved defaults to 1. }
  function PointeeElemSizeCode(const ATypeName: string): Int64;
  var
    TmpId, TmpTarget: LongInt;
    TmpMeta: TTypeMetadata;
  begin
    Result := 1;
    if ATypeName = '' then
      Exit;
    TmpId := FModel.FindTypeByName(ATypeName);
    if TmpId <= 0 then
      Exit;
    if FModel.GetTypeMeta(TmpId, TmpMeta) and (TmpMeta.Size > 1) and
      (TmpMeta.AliasTargetTypeId > 0) then
    begin
      TmpTarget := TmpMeta.AliasTargetTypeId;
      if FModel.GetTypeMeta(TmpTarget, TmpMeta) and (TmpMeta.Size > 1) then
        Result := TmpMeta.Size;
    end
    else if FModel.GetTypeMeta(TmpId, TmpMeta) and (TmpMeta.Size > 1) then
      Result := TmpMeta.Size;
  end;

  { P^.Field or P^.RecField.SubField value load.
    Nested form beats unit.path.FreeFunc heuristic when SubField collides
    with a free function name (e.g. LDispatch^.Memory.Utf8Validate). }
  function TryPointerFieldValueBlob(const ALocalNode: TGreenNode;
    out AValueBlob: string): Boolean;
  var
    PtrName, PointeeName, FieldName, NestedTypeName: string;
    FieldIdx, NestedIdx: Int64;
    MidNode, SubNode: TGreenNode;
    Meta: TTypeMetadata;
    I: LongInt;
    FieldTypeId: LongInt;
  begin
    AValueBlob := '';
    if TryPointerFieldAccess(ALocalNode, PtrName, PointeeName, FieldName,
      FieldIdx) then
    begin
      AValueBlob := 'var ' + PtrName + #10 + 'int ' + IntToStr(FieldIdx) + #10;
      if TypeMetaFieldIsPtr(PointeeName, FieldName) then
        AValueBlob := AValueBlob + 'arr_load_ptr' + #10
      else
        AValueBlob := AValueBlob + 'arr_load' + #10;
      Exit(True);
    end;
    if (ALocalNode = nil) or (ALocalNode.NodeKind <> gnkDotAccess) or
      (ALocalNode.ChildCount < 2) then
      Exit(False);
    MidNode := ALocalNode.ChildAt(0);
    SubNode := ALocalNode.ChildAt(1);
    if (SubNode = nil) or (SubNode.NodeKind <> gnkIdentifier) then
      Exit(False);
    if not TryPointerFieldAccess(MidNode, PtrName, PointeeName, FieldName,
      FieldIdx) then
      Exit(False);
    NestedTypeName := '';
    FieldTypeId := 0;
    if FModel.GetTypeMetaByName(PointeeName, Meta) and (Meta.Fields <> nil) then
      for I := 0 to LongInt(Meta.Fields.Count) - 1 do
        if SameText(Meta.Fields[SizeUInt(I)].Name, FieldName) then
        begin
          FieldTypeId := Meta.Fields[SizeUInt(I)].TypeId;
          Break;
        end;
    if (FieldTypeId > 0) and (FieldTypeId <= FModel.TypeCount) then
      NestedTypeName := FModel.TypeAt(FieldTypeId - 1).Name;
    if NestedTypeName = '' then
      Exit(False);
    NestedIdx := TypeMetaFieldIndex(NestedTypeName, SubNode.Text);
    if NestedIdx < 0 then
      Exit(False);
    { Word-slot layout: nested record starts at FieldIdx; subfield is relative. }
    AValueBlob := 'var ' + PtrName + #10 +
      'int ' + IntToStr(FieldIdx + NestedIdx) + #10;
    if TypeMetaFieldIsPtr(NestedTypeName, SubNode.Text) then
      AValueBlob := AValueBlob + 'arr_load_ptr' + #10
    else
      AValueBlob := AValueBlob + 'arr_load' + #10;
    Result := True;
  end;

  { property Text read GetText — record props are not in type meta yet, so
    DotAccess falls through to call Type.Text. Prefer an existing GetX body. }
  function ResolvePropertyReadCallee(const ATypeName, AMember: string): string;
  var
    Direct, Getter: string;
    BodyNode, DeclNode: TGreenNode;
  begin
    Direct := ATypeName + '.' + AMember;
    if (ATypeName = '') or (AMember = '') then
      Exit(Direct);
    if LookupProcedureBody(Direct, BodyNode, DeclNode) then
      Exit(Direct);
    Getter := ATypeName + '.Get' + AMember;
    if LookupProcedureBody(Getter, BodyNode, DeclNode) then
      Exit(Getter);
    Result := Direct;
  end;

  { 辅助：尝试创建结构化 int literal 表达式 }
  function TryEmitIntLiteral(Value: Int64): Boolean;
  var
    LId: LongInt;
  begin
    LId := FModel.AddHirExpr(
      shekIntLiteral, 0, 0, [], Value, 0.0, '', '', 0, shvcScalar);
    if LId > 0 then
    begin
      AExprId := LId;
      ABlob := 'expr ' + IntToStr(LId) + #10;
      Exit(True);
    end;
    Result := False;
  end;

  { 辅助：尝试创建结构化 string literal 表达式 }
  function TryEmitStringLiteral(const AText: string): Boolean;
  var
    LId: LongInt;
  begin
    LId := FModel.AddHirExpr(
      shekStringLiteral, 0, 0, [], 0, 0.0, AText, '', 0, shvcScalar);
    if LId > 0 then
    begin
      AExprId := LId;
      ABlob := 'expr ' + IntToStr(LId) + #10;
      Exit(True);
    end;
    Result := False;
  end;

  { 辅助：尝试创建结构化 nil literal 表达式 }
  function TryEmitNilLiteral: Boolean;
  var
    LId: LongInt;
  begin
    LId := FModel.AddHirExpr(
      shekNilLiteral, 0, 0, [], 0, 0.0, '', '', 0, shvcScalar);
    if LId > 0 then
    begin
      AExprId := LId;
      ABlob := 'expr ' + IntToStr(LId) + #10;
      Exit(True);
    end;
    Result := False;
  end;

  { 辅助：尝试创建结构化 exc_load intrinsic 表达式 }
  function TryEmitExcLoad: Boolean;
  var
    LId: LongInt;
  begin
    LId := FModel.AddHirExpr(
      shekIntrinsic, 0, 0, [], 0, 0.0, '', 'exc_load', 0, shvcScalar);
    if LId > 0 then
    begin
      AExprId := LId;
      ABlob := 'expr ' + IntToStr(LId) + #10;
      Exit(True);
    end;
    Result := False;
  end;

  { 辅助：尝试创建结构化 symbol value 表达式 }
  function TryEmitSymbolValue(const AName: string): Boolean;
  var
    LSymbolId, LTypeId, LId: LongInt;
  begin
    LSymbolId := FindSymbolByName(AName);
    if LSymbolId <= 0 then
      Exit(False);
    LTypeId := FModel.SymbolTypeId(LSymbolId);
    LId := FModel.AddHirExpr(
      shekSymbolValue, LTypeId, LSymbolId, [], 0, 0.0, '', '', 0, shvcScalar);
    if LId > 0 then
    begin
      AExprId := LId;
      ABlob := 'expr ' + IntToStr(LId) + #10;
      Exit(True);
    end;
    Result := False;
  end;

  { 辅助：尝试创建结构化 field self 表达式 }
  function TryEmitFieldSelf(AFieldIndex: Int64; AIsPtr: Boolean): Boolean;
  var
    LSelfId, LSelfTypeId, LFieldExprId, LId: LongInt;
    LPChildren: array of LongInt;
  begin
    LSelfId := FindSymbolByName('Self');
    if LSelfId <= 0 then
      Exit(False);
    LSelfTypeId := FModel.SymbolTypeId(LSelfId);
    LFieldExprId := FModel.AddHirExpr(
      shekSymbolValue, LSelfTypeId, LSelfId, [], 0, 0.0, '', '', 0, shvcAddress);
    if LFieldExprId <= 0 then
      Exit(False);
    SetLength(LPChildren, 1);
    LPChildren[0] := LFieldExprId;
    LId := FModel.AddHirExpr(
      shekField, 0, 0, LPChildren, AFieldIndex, 0.0, '', '', 0, shvcScalar);
    if LId > 0 then
    begin
      AExprId := LId;
      ABlob := 'expr ' + IntToStr(LId) + #10;
      Exit(True);
    end;
    Result := False;
  end;

  { Interlocked* in value position (old := InterlockedXxx(...)): plain 'call'
    encoding loads the by-ref target as a value and the address is gone by the
    time the builder sees it — encode the address ('varref'/'field_ref') plus a
    dedicated 'ilk <op>' token instead. Statement-position calls are handled in
    np_sema_walk_halt_calls.inc; non-identifier targets fall back to the plain
    call (residual, no worse than before). }
  function TryEncodeInterlockedValueCall(const ACallNode: TGreenNode;
    out AIlkBlob: string): Boolean;
  var
    LCallee, LOp, LArgBlob, LEncoded: string;
    LExpectedArgs, LArgIdx: LongInt;
    LFieldIdx: Int64;
    LTargetNode: TGreenNode;
  begin
    Result := False;
    AIlkBlob := '';
    LCallee := ACallNode.ChildAt(0).Text;
    if SameText(LCallee, 'InterlockedCompareExchange') then
    begin
      LOp := 'cas';
      LExpectedArgs := 3;
    end
    else if SameText(LCallee, 'InterlockedCompareExchange64') then
    begin
      LOp := 'cas64';
      LExpectedArgs := 3;
    end
    else if SameText(LCallee, 'InterlockedExchange') or
      SameText(LCallee, 'InterlockedExchange64') then
    begin
      LOp := 'xchg';
      LExpectedArgs := 2;
    end
    else if SameText(LCallee, 'InterlockedExchangeAdd') then
    begin
      LOp := 'add';
      LExpectedArgs := 2;
    end
    else if SameText(LCallee, 'InterlockedExchangeAdd64') then
    begin
      LOp := 'add64';
      LExpectedArgs := 2;
    end
    else
      Exit;
    if ACallNode.ChildCount <> LExpectedArgs + 1 then
      Exit;
    LTargetNode := ACallNode.ChildAt(1);
    if (LTargetNode = nil) or (LTargetNode.NodeKind <> gnkIdentifier) then
      Exit;
    LFieldIdx := -1;
    if FCurrentMethodClass <> '' then
      LFieldIdx := TypeMetaFieldIndex(FCurrentMethodClass, LTargetNode.Text);
    if LFieldIdx >= 0 then
      AIlkBlob := 'var self' + #10 + 'field_ref ' + IntToStr(LFieldIdx) + #10
    else
      AIlkBlob := 'varref ' + LTargetNode.Text + #10;
    for LArgIdx := 2 to ACallNode.ChildCount - 1 do
    begin
      if (ACallNode.ChildAt(LArgIdx) = nil) or
        not EncodeRuntimeIntExprFold(ACallNode.ChildAt(LArgIdx), LEncoded) then
        Exit;
      AIlkBlob := AIlkBlob + LEncoded;
    end;
    AIlkBlob := AIlkBlob + 'ilk ' + LOp + #10;
    Result := True;
  end;

var
  Folded: Int64;
  CharValue: LongInt;
  ExprId, StrExprId: LongInt;
  BaseName, OwnerClassName, FieldName, FuncName, ArgName, ReceiverVarName: string;
  StrCallIdx, StrCallArgCount, K, ArgIndex, DotPos: LongInt;
  TargetTypeId, SourceExprId, CastExprId: LongInt;
  CastChildren: array of LongInt;
  BranchNode, DeclNode, RhsNode, BaseNode: TGreenNode;
  ParamNode: TGreenNode;
  CallFormalByRef: array of Boolean;
  CallHasFormalMeta: Boolean;
  Operand, PropName, BaseNodeName: string;
  FldMeta: TFieldMeta;
begin
  ABlob := '';
  AExprId := 0;
  if ANode = nil then
    Exit(False);
  if EmitOwnedStringConcatLengthTemp(ANode, ABlob) then
    Exit(True);
  if EmitOwnedStringLengthTemp(ANode, ABlob) then
    Exit(True);
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'nil') then
  begin
    if TryEmitNilLiteral then
      Exit(True);
    ABlob := 'null' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'ExceptObject') then
  begin
    if TryEmitExcLoad then
      Exit(True);
    ABlob := 'exc_load' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and SameText(ANode.ChildAt(0).Text, 'ExceptObject') then
  begin
    if TryEmitExcLoad then
      Exit(True);
    ABlob := 'exc_load' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'True') then
  begin
    if TryEmitIntLiteral(1) then
      Exit(True);
    ABlob := 'int 1' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'False') then
  begin
    if TryEmitIntLiteral(0) then
      Exit(True);
    ABlob := 'int 0' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Assigned') and
    (ANode.ChildAt(1) <> nil) then
  begin
    { System.Assigned(X) → X <> nil. Never residual-call @Assigned.
      Simple locals keep dedicated `assigned name` token; complex args
      (P^.Rec.Field / procedural slots) encode then cmp-ne 0. }
    if (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
      (ANode.ChildAt(1).Text <> '') then
    begin
      ABlob := 'assigned ' + ANode.ChildAt(1).Text + #10;
      Exit(True);
    end;
    if EncodeRuntimeIntExprFold(ANode.ChildAt(1), ABlob) then
    begin
      ABlob := ABlob + 'int 0' + #10 + 'cmp ne' + #10;
      Exit(True);
    end;
    { Unencodable arg: still must not emit call @Assigned. }
    ABlob := 'int 0' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkStringLiteral) then
  begin
    { 迁移到结构化表达式: Length('string') }
    { 创建字符串 literal 表达式 }
    StrExprId := FModel.AddHirExpr(
      shekStringLiteral,
      0, { TypeId }
      0, { SymbolId }
      [], { Children }
      0, { LiteralInt }
      0.0, { LiteralFloat }
      ANode.ChildAt(1).Text, { LiteralStr }
      '', { Op }
      0, { SourceOffset }
      shvcScalar { ValueClass }
    );
    if StrExprId > 0 then
    begin
      { 创建 Length 调用表达式 }
      ExprId := FModel.AddHirExpr(
        shekIntrinsic,
        0, { TypeId }
        0, { SymbolId }
        [StrExprId], { Children }
        0, { LiteralInt }
        0.0, { LiteralFloat }
        '', { LiteralStr }
        'strlen', { Op }
        0, { SourceOffset }
        shvcScalar { ValueClass }
      );
      if ExprId > 0 then
      begin
        AExprId := ExprId;
        ABlob := 'expr ' + IntToStr(ExprId) + #10;
        Exit(True);
      end;
    end;
    { Fallback }
    ABlob := 'strlit ' + ANode.ChildAt(1).Text + #10 + 'strlen' + #10;
    Exit(True);
  end;
  { Length(FEvalExpr) in method before local-$len: bare field names are often
    also registered as runtime str vars, but have no Name$ts alloca. }
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    (FCurrentMethodClass <> '') then
  begin
    Folded := TypeMetaFieldIndex(FCurrentMethodClass, ANode.ChildAt(1).Text);
    if Folded >= 0 then
    begin
      if TypeMetaFieldIsStr(FCurrentMethodClass, ANode.ChildAt(1).Text) then
      begin
        ABlob := 'fieldstrlen self ' + IntToStr(Folded) + #10;
        Exit(True);
      end;
      if TypeMetaFieldIsDynArray(FCurrentMethodClass, ANode.ChildAt(1).Text) then
      begin
        if TryEmitFieldSelf(Folded + 1, False) then
          Exit(True);
        ABlob := 'field self ' + IntToStr(Folded + 1) + #10;
        Exit(True);
      end;
    end;
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    { Result aliases the retvar name (registered under the function name);
      without the remap Length(Result) folded empty and the loop bound
      alloca was never stored (stub SysUtils for-loops). }
    ReceiverVarName := ANode.ChildAt(1).Text;
    if SameText(ReceiverVarName, 'Result') and (FCurrentRetVarName <> '') then
      ReceiverVarName := FCurrentRetVarName;
    if IsRuntimeStrVar(ReceiverVarName) or
      IsRuntimeArrVar(ReceiverVarName) then
    begin
      { Variable read wins: the retvar registers under the function's own
        name, so LookupProcedureBody would find the enclosing function and
        Length(Result) materialized as a self-call (mini_up SIGSEGV). }
      if (FCurrentRetVarName = '') or
        (not SameText(ReceiverVarName, FCurrentRetVarName)) then
      begin
        if LookupProcedureBody(ReceiverVarName, BranchNode, DeclNode) then
        begin
          Inc(FBlockLabelCounter);
          Operand := '$len_tmp_' + IntToStr(FBlockLabelCounter);
          RegisterRuntimeVar(Operand);
          RegisterRuntimeStrVar(Operand);
          FModel.AddTypedHirNode('var-decl-tstring-runtime', Operand, 0, 0, Operand);
          FModel.AddTypedHirNode(
            'assign-tstring-call-runtime',
            EffectiveRuntimeCalleeName(ReceiverVarName, DeclNode), 0, 0, Operand
          );
          ABlob := 'var ' + Operand + '$len' + #10;
          Exit(True);
        end;
      end;
      ABlob := 'var ' + ReceiverVarName + '$len' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkDotAccess) and
    (ANode.ChildAt(1).ChildCount >= 2) and
    (ANode.ChildAt(1).ChildAt(0) <> nil) and
    (ANode.ChildAt(1).ChildAt(1) <> nil) and
    (ANode.ChildAt(1).ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1).ChildAt(1).NodeKind = gnkIdentifier) and
    SameText(ANode.ChildAt(1).ChildAt(0).Text, 'Self') and
    (FCurrentMethodClass <> '') and
    TypeMetaFieldIsDynArray(FCurrentMethodClass,
      ANode.ChildAt(1).ChildAt(1).Text) then
  begin
    Folded := TypeMetaFieldIndex(FCurrentMethodClass,
      ANode.ChildAt(1).ChildAt(1).Text);
    if TryEmitFieldSelf(Folded + 1, False) then
      Exit(True);
    ABlob := 'field self ' + IntToStr(Folded + 1) + #10;
    Exit(True);
  end;
  { Batch 25: Length(R.S) / Length(obj.Field) — GEP + tstring_len. }
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkDotAccess) and
    (ANode.ChildAt(1).ChildCount >= 2) and
    (ANode.ChildAt(1).ChildAt(0) <> nil) and
    (ANode.ChildAt(1).ChildAt(1) <> nil) and
    (ANode.ChildAt(1).ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1).ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    ReceiverVarName := ANode.ChildAt(1).ChildAt(0).Text;
    if SameText(ReceiverVarName, 'Self') and (FCurrentMethodClass <> '') then
    begin
      ReceiverVarName := 'self';
      FuncName := FCurrentMethodClass;
    end
    else
    begin
      FuncName := LookupClassVar(ReceiverVarName);
      if FuncName = '' then
        FuncName := LookupRecordVar(ReceiverVarName);
    end;
    if FuncName <> '' then
    begin
      ArgName := ANode.ChildAt(1).ChildAt(1).Text;
      if TypeMetaFieldIsStr(FuncName, ArgName) then
      begin
        Folded := TypeMetaFieldIndex(FuncName, ArgName);
        if Folded >= 0 then
        begin
          ABlob := 'fieldstrlen ' + ReceiverVarName + ' ' + IntToStr(Folded) + #10;
          Exit(True);
        end;
      end;
    end;
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 3) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    SameText(ANode.ChildAt(0).Text, 'SarLongint') then
  begin
    { FPC arithmetic-shift-right intrinsic → ashr chain (hikShr → moAShr).
      Missing encode used to leave call @SarLongint(i64, ptr) — the ptr being
      the scalar aShift param living in a ptr slot (B6.5-Sar). }
    if EncodeRuntimeIntExprFold(ANode.ChildAt(1), FuncName) and
      EncodeRuntimeIntExprFold(ANode.ChildAt(2), ArgName) then
    begin
      ABlob := FuncName + ArgName + 'sar' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 3) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    SameText(ANode.ChildAt(0).Text, 'Pos') then
  begin
    { Needle (ptr,len) then haystack (ptr,len) then strpos.
      Incomplete Pos (needle only) left ptr on stack → mul i64 %ptr. }
    ABlob := '';
    FuncName := '';
    if (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkStringLiteral) then
      ABlob := 'strlit ' + ANode.ChildAt(1).Text + #10
    else if (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
      IsRuntimeStrVar(ANode.ChildAt(1).Text) then
      ABlob := 'strvar ' + ANode.ChildAt(1).Text + #10
    else if (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
      FModel.LookupStringConstValue(ANode.ChildAt(1).Text, ArgName) and
      (Pos('''', ArgName) = 0) then
      { Const string identifier (DirectorySeparator etc.) — fold to literal.
        Values containing quotes fall through: strlit arg is quoted form. }
      ABlob := 'strlit ''' + ArgName + '''' + #10
    else if (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkFunctionCall) and
      (ANode.ChildAt(1).Text <> '') and
      LookupProcedureBody(ANode.ChildAt(1).Text, BranchNode, DeclNode) and
      (IsRuntimeStrVar(ANode.ChildAt(1).Text) or
       IsOwnedStringReturnFunc(ANode.ChildAt(1).Text)) then
    begin
      { String-returning call needle (LowerCase(AName)) — materialize into a
        $pos_ndl temp; the inline fallthrough mis-split (data,len) into a
        bogus sret target. }
      Inc(FBlockLabelCounter);
      ArgName := '$pos_ndl_' + IntToStr(FBlockLabelCounter);
      RegisterRuntimeVar(ArgName);
      RegisterRuntimeStrVar(ArgName);
      FModel.AddTypedHirNode('var-decl-tstring-runtime', ArgName, 0, 0,
        ArgName);
      FModel.AddTypedHirNode('assign-tstring-call-runtime', ArgName, 0, 0,
        ArgName + #9 + 'callee ' +
        EffectiveRuntimeCalleeName(ANode.ChildAt(1).Text, nil) + #9 +
        EncodeStrCallArgs(ANode.ChildAt(1), ArgName));
      ABlob := 'strvar ' + ArgName + #10;
    end;
    if (ANode.ChildAt(2) <> nil) and
      (ANode.ChildAt(2).NodeKind = gnkIdentifier) and
      IsRuntimeStrVar(ANode.ChildAt(2).Text) then
      FuncName := 'strvar ' + ANode.ChildAt(2).Text + #10
    else if (ANode.ChildAt(2) <> nil) and
      (ANode.ChildAt(2).NodeKind = gnkArrayAccess) and
      (ANode.ChildAt(2).ChildCount >= 2) and
      (ANode.ChildAt(2).ChildAt(0) <> nil) and
      (ANode.ChildAt(2).ChildAt(0).NodeKind = gnkIdentifier) and
      IsRuntimeArrVar(ANode.ChildAt(2).ChildAt(0).Text) and
      EncodeRuntimeIntExprFold(ANode.ChildAt(2).ChildAt(1), Operand) then
      { String-array element haystack (AItems[I]) — tsload reads (data,len)
        through the 24-byte TString stride instead of an int arr_load. }
      FuncName := Operand + 'tsload ' +
        ANode.ChildAt(2).ChildAt(0).Text + #10
    else if (ANode.ChildAt(2) <> nil) and
      (ANode.ChildAt(2).NodeKind = gnkArrayAccess) and
      (ANode.ChildAt(2).ChildCount >= 2) and
      TryClassFieldArrayAccess(ANode.ChildAt(2), BaseName, OwnerClassName,
        FieldName) and
      EncodeRuntimeIntExprFold(ANode.ChildAt(2).ChildAt(1), Operand) then
    begin
      Folded := TypeMetaFieldIndex(OwnerClassName, FieldName);
      if Folded >= 0 then
        FuncName := 'field ' + BaseName + ' ' + IntToStr(Folded) + ' p' +
          #10 + Operand + 'tsload' + #10;
    end
    else if (ANode.ChildAt(2) <> nil) and
      (ANode.ChildAt(2).NodeKind = gnkArrayAccess) and
      (ANode.ChildAt(2).ChildCount >= 2) and
      (ANode.ChildAt(2).ChildAt(0) <> nil) then
    begin
      { Class/record instance indexed property haystack — two shapes:
        - X[I]        default indexed property (TVec<string> Items)
        - X.Items[I]  explicit property access
        Materialize the string via the property getter call. Without this
        branch the strpos fast path falls through and the Pos call is
        emitted with garbage args (stray const plus the loop index). }
      BaseNode := ANode.ChildAt(2).ChildAt(0);
      Operand := '';
      PropName := '';
      BaseNodeName := '';
      if BaseNode.NodeKind = gnkIdentifier then
      begin
        BaseNodeName := BaseNode.Text;
        Operand := LookupClassVar(BaseNodeName);
        if Operand = '' then
          Operand := LookupRecordVar(BaseNodeName);
        { default indexed property getter heuristic (TVec.Items → GetItem) }
        PropName := 'Item';
      end
      else if (BaseNode.NodeKind = gnkDotAccess) and
        (BaseNode.ChildCount >= 2) and
        (BaseNode.ChildAt(0) <> nil) and
        (BaseNode.ChildAt(0).NodeKind = gnkIdentifier) and
        (BaseNode.ChildAt(1) <> nil) and
        (BaseNode.ChildAt(1).NodeKind = gnkIdentifier) then
      begin
        BaseNodeName := BaseNode.ChildAt(0).Text;
        Operand := LookupClassVar(BaseNodeName);
        if Operand = '' then
          Operand := LookupRecordVar(BaseNodeName);
        PropName := BaseNode.ChildAt(1).Text;
      end;
      if (Operand <> '') and (PropName <> '') and
        EncodeRuntimeIntExprFold(ANode.ChildAt(2).ChildAt(1), ArgName) then
      begin
        Inc(FBlockLabelCounter);
        ReceiverVarName := '$pos_hay_' + IntToStr(FBlockLabelCounter);
        RegisterRuntimeVar(ReceiverVarName);
        RegisterRuntimeStrVar(ReceiverVarName);
        FModel.AddTypedHirNode('var-decl-tstring-runtime', ReceiverVarName,
          0, 0, ReceiverVarName);
        FModel.AddTypedHirNode('assign-tstring-call-runtime',
          ResolvePropertyReadCallee(Operand, PropName), 0, 0,
          ReceiverVarName + #9 + 'callee ' +
          ResolvePropertyReadCallee(Operand, PropName) + #9 +
          'var ' + BaseNodeName + #9 + ArgName);
        FuncName := 'strvar ' + ReceiverVarName + #10;
      end;
    end
    else if (ANode.ChildAt(2) <> nil) and
      (ANode.ChildAt(2).NodeKind = gnkFunctionCall) and
      (ANode.ChildAt(2).Text <> '') and
      LookupProcedureBody(ANode.ChildAt(2).Text, BranchNode, DeclNode) and
      (IsRuntimeStrVar(ANode.ChildAt(2).Text) or
       IsOwnedStringReturnFunc(ANode.ChildAt(2).Text)) then
    begin
      { String-returning call haystack (LowerCase(AValue)) — same
        materialization as the needle side. }
      Inc(FBlockLabelCounter);
      ReceiverVarName := '$pos_hay_' + IntToStr(FBlockLabelCounter);
      RegisterRuntimeVar(ReceiverVarName);
      RegisterRuntimeStrVar(ReceiverVarName);
      FModel.AddTypedHirNode('var-decl-tstring-runtime', ReceiverVarName,
        0, 0, ReceiverVarName);
      FModel.AddTypedHirNode('assign-tstring-call-runtime',
        ReceiverVarName, 0, 0,
        ReceiverVarName + #9 + 'callee ' +
        EffectiveRuntimeCalleeName(ANode.ChildAt(2).Text, nil) + #9 +
        EncodeStrCallArgs(ANode.ChildAt(2), ReceiverVarName));
      FuncName := 'strvar ' + ReceiverVarName + #10;
    end
    else if (ANode.ChildAt(2) <> nil) and
      (ANode.ChildAt(2).NodeKind = gnkDotAccess) and
      (ANode.ChildAt(2).ChildCount >= 2) and
      (ANode.ChildAt(2).ChildAt(0) <> nil) and
      (ANode.ChildAt(2).ChildAt(1) <> nil) and
      (ANode.ChildAt(2).ChildAt(0).NodeKind = gnkIdentifier) and
      (ANode.ChildAt(2).ChildAt(1).NodeKind = gnkIdentifier) then
    begin
      ReceiverVarName := ANode.ChildAt(2).ChildAt(0).Text;
      ArgName := ANode.ChildAt(2).ChildAt(1).Text;
      Operand := LookupClassVar(ReceiverVarName);
      if Operand = '' then
        Operand := LookupRecordVar(ReceiverVarName);
      if Operand <> '' then
      begin
        Inc(FBlockLabelCounter);
        FuncName := '$pos_hay_' + IntToStr(FBlockLabelCounter);
        RegisterRuntimeVar(FuncName);
        RegisterRuntimeStrVar(FuncName);
        FModel.AddTypedHirNode('var-decl-tstring-runtime', FuncName, 0, 0,
          FuncName);
        if TypeMetaFieldIsStr(Operand, ArgName) then
        begin
          Folded := TypeMetaFieldIndex(Operand, ArgName);
          if Folded >= 0 then
            FModel.AddTypedHirNode(
              'assign-tstring-field-load-runtime', FuncName, 0, 0,
              ReceiverVarName + #9 + IntToStr(Folded))
          else
            FuncName := '';
        end
        else
          { Property/method string: TypeChild.Text → prefer GetText body. }
          FModel.AddTypedHirNode(
            'assign-tstring-call-runtime',
            ResolvePropertyReadCallee(Operand, ArgName), 0, 0,
            FuncName + #9 + 'var ' + ReceiverVarName);
        if FuncName <> '' then
          FuncName := 'strvar ' + FuncName + #10
        else
          FuncName := '';
      end;
    end;
    { Concat-tree operands (',' + SC + ',') and char-literal needles
      (#9/#10 blob scans) match none of the shapes above; left unfilled
      they fall through to generic int folding, which lowers the tree to
      ptrtoint/add garbage args on a bare @Pos call. Unsupported kinds
      yield '' here and degrade to the previous behavior unchanged. }
    if (ABlob = '') and (ANode.ChildAt(1) <> nil) then
    begin
      ArgName := EncodePosConcatOperand(ANode.ChildAt(1));
      if ArgName <> '' then
        ABlob := 'strvar ' + ArgName + #10;
    end;
    if (FuncName = '') and (ANode.ChildAt(2) <> nil) then
    begin
      ArgName := EncodePosConcatOperand(ANode.ChildAt(2));
      if ArgName <> '' then
        FuncName := 'strvar ' + ArgName + #10;
    end;
    if (ABlob <> '') and (FuncName <> '') then
    begin
      ABlob := ABlob + FuncName + 'strpos' + #10;
      Exit(True);
    end;
  end;
  { S[I] char read as a value: byte at tstring_data(S)[I-1] (str_chr token
    pops the folded index). Base may be 'Result' — alias the retvar name
    like assignments do, else the fold silently declines (stub SysUtils
    `Result[I] in [...]` bodies were dropped whole). }
  if (ANode.NodeKind = gnkArrayAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1) <> nil) then
  begin
    ReceiverVarName := ANode.ChildAt(0).Text;
    if SameText(ReceiverVarName, 'Result') and (FCurrentRetVarName <> '') then
      ReceiverVarName := FCurrentRetVarName;
    if IsRuntimeStrVar(ReceiverVarName) and
      EncodeRuntimeIntExprFold(ANode.ChildAt(1), ABlob) then
    begin
      ABlob := ABlob + 'str_chr ' + ReceiverVarName + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (SameText(ANode.ChildAt(0).Text, 'Ord') or
     SameText(ANode.ChildAt(0).Text, 'Chr') or
     SameText(ANode.ChildAt(0).Text, 'Abs') or
     SameText(ANode.ChildAt(0).Text, 'UpCase') or
     SameText(ANode.ChildAt(0).Text, 'Pred') or
     SameText(ANode.ChildAt(0).Text, 'Succ') or
     SameText(ANode.ChildAt(0).Text, 'BsfQWord') or
     SameText(ANode.ChildAt(0).Text, 'BsrQWord') or
     SameText(ANode.ChildAt(0).Text, 'BsfDWord') or
     SameText(ANode.ChildAt(0).Text, 'BsrDWord') or
     SameText(ANode.ChildAt(0).Text, 'BsfWord') or
     SameText(ANode.ChildAt(0).Text, 'BsrWord') or
     SameText(ANode.ChildAt(0).Text, 'BsfByte') or
     SameText(ANode.ChildAt(0).Text, 'BsrByte')) then
  begin
    { Abs/Sqr overloads (Abs$p / Abs$i) must residual-call the mangled body,
      not the integer `abs` intrinsic — float Abs is SingleAbsBits, not i64 abs. }
    if (SameText(ANode.ChildAt(0).Text, 'Abs') and HasOverload('Abs')) or
      (SameText(ANode.ChildAt(0).Text, 'UpCase') and HasOverload('UpCase')) then
    begin
      { Fall through to generic call + EffectiveRuntimeCalleeName. }
    end
    else if (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkStringLiteral) and
      (Length(ANode.ChildAt(1).Text) = 3) and
      (ANode.ChildAt(1).Text[1] = '''') then
    begin
      CharValue := Ord(ANode.ChildAt(1).Text[2]);
      if TryEmitIntLiteral(CharValue) then
      begin
        { Ord('A') is the bare value — no suffix. Plain 'int N', not the
          structured 'expr N': a folded char literal can sit in the middle
          of a binary blob (DigitDecode: Ord(C) - Ord('A')), where the
          structured line is dropped (ParseIntExprArgTyped does not push
          it) and the sub loses its right operand. }
        if SameText(ANode.ChildAt(0).Text, 'Ord') then
          ABlob := 'int ' + IntToStr(CharValue) + #10
        else if SameText(ANode.ChildAt(0).Text, 'Pred') then
          ABlob := ABlob + 'expr ' + IntToStr(AExprId) + #10 + 'int 1' + #10 + 'sub' + #10
        else if SameText(ANode.ChildAt(0).Text, 'Succ') then
          ABlob := ABlob + 'expr ' + IntToStr(AExprId) + #10 + 'int 1' + #10 + 'add' + #10
        else if SameText(ANode.ChildAt(0).Text, 'Abs') then
          ABlob := ABlob + 'abs' + #10
        else if SameText(ANode.ChildAt(0).Text, 'UpCase') then
          ABlob := ABlob + 'upcase' + #10;
        Exit(True);
      end;
      ABlob := 'int ' + IntToStr(CharValue) + #10;
      if SameText(ANode.ChildAt(0).Text, 'Pred') then
        ABlob := ABlob + 'int 1' + #10 + 'sub' + #10
      else if SameText(ANode.ChildAt(0).Text, 'Succ') then
        ABlob := ABlob + 'int 1' + #10 + 'add' + #10
      else if SameText(ANode.ChildAt(0).Text, 'Abs') then
        ABlob := ABlob + 'abs' + #10
      else if SameText(ANode.ChildAt(0).Text, 'UpCase') then
        ABlob := ABlob + 'upcase' + #10;
      Exit(True);
    end
    else if EncodeRuntimeIntExprFold(ANode.ChildAt(1), ABlob) then
    begin
      { Intrinsic consuming a Char value (Ord/UpCase/Pred/Succ on a Char
        param): the operand folds to the slot address; load the i8 first
        (Ord(C) in DigitDecode's case bodies otherwise sums the address). }
      if IsCharValueOperand(ANode.ChildAt(1)) then
        ABlob := ABlob + 'charval' + #10;
      if SameText(ANode.ChildAt(0).Text, 'Pred') then
        ABlob := ABlob + 'int 1' + #10 + 'sub' + #10
      else if SameText(ANode.ChildAt(0).Text, 'Succ') then
        ABlob := ABlob + 'int 1' + #10 + 'add' + #10
      else if SameText(ANode.ChildAt(0).Text, 'Abs') then
        ABlob := ABlob + 'abs' + #10
      else if SameText(ANode.ChildAt(0).Text, 'UpCase') then
        { System UpCase(char) — no RTL body; branchless select intrinsic. }
        ABlob := ABlob + 'upcase' + #10
      { System Bsf*/Bsr* — no RTL body; lower to llvm.cttz/ctlz (never bare @Bsf*). }
      else if (Length(ANode.ChildAt(0).Text) >= 3) and
        SameText(Copy(ANode.ChildAt(0).Text, 1, 3), 'Bsf') then
        ABlob := ABlob + 'bsf' + #10
      else if (Length(ANode.ChildAt(0).Text) >= 3) and
        SameText(Copy(ANode.ChildAt(0).Text, 1, 3), 'Bsr') then
        ABlob := ABlob + 'bsr' + #10;
      Exit(True);
    end
    else if SameText(ANode.ChildAt(0).Text, 'Ord') and
      EncodeRuntimeBoolExprFold(ANode.ChildAt(1), ABlob) then
    begin
      ABlob := ABlob + 'zext' + #10;
      Exit(True);
    end;
  end;
  { Default(T) — system zero-init intrinsic. No RTL body; never residual
    @Default / @TypeName from Default(Type). Scalar/handle store of 0 is enough
    for unit globals reduced to i64; record locals use fillchar-runtime walk. }
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    SameText(ANode.ChildAt(0).Text, 'Default') then
  begin
    if TryEmitIntLiteral(0) then
      Exit(True);
    ABlob := 'int 0' + #10;
    Exit(True);
  end;
  { EOF(F) — System text/file stub (core system.io: always True). No seeded
    body under bare @EOF; fold to 1 so while-not-EOF / conds never residual. }
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    SameText(ANode.ChildAt(0).Text, 'EOF') then
  begin
    if TryEmitIntLiteral(1) then
      Exit(True);
    ABlob := 'int 1' + #10;
    Exit(True);
  end;
  { FilePos(F) — System handle stub (core system.io: Result := 0). No seeded
    bare @FilePos body; fold so TFileStream.Seek never residuals. }
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    SameText(ANode.ChildAt(0).Text, 'FilePos') then
  begin
    if TryEmitIntLiteral(0) then
      Exit(True);
    ABlob := 'int 0' + #10;
    Exit(True);
  end;
  { FileSize — two overloads collide on bare name:
      1) System handle stub FileSize(var File): LongInt → Result := 0
      2) fs path FileSize(const string): Int64 → real @FileSize(ptr,i32)
    Only fold the handle form. Path form keeps one string-ish arg and must
    fall through to the seeded unit body (never residual, never zeroed). }
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    SameText(ANode.ChildAt(0).Text, 'FileSize') then
  begin
    RhsNode := nil;
    if ANode.ChildCount >= 2 then
      RhsNode := ANode.ChildAt(1);
    if (RhsNode <> nil) and
      ((RhsNode.NodeKind = gnkStringLiteral) or
       ((RhsNode.NodeKind = gnkIdentifier) and IsRuntimeStrVar(RhsNode.Text))) then
      { path FileSize(string) — do not fold }
    else
    begin
      if TryEmitIntLiteral(0) then
        Exit(True);
      ABlob := 'int 0' + #10;
      Exit(True);
    end;
  end;
  { SizeOf/High/Low must fold before generic call encoding — otherwise
    SizeOf(staticArray) becomes call @SizeOf with arrvar (ptr,len) args. }
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (SameText(ANode.ChildAt(0).Text, 'SizeOf') or
     SameText(ANode.ChildAt(0).Text, 'High') or
     SameText(ANode.ChildAt(0).Text, 'Low') or
     SameText(ANode.ChildAt(0).Text, 'Length')) then
  begin
    if EvaluateIntegerConstant(ANode, Folded) then
    begin
      if TryEmitIntLiteral(Folded) then
        Exit(True);
      ABlob := 'int ' + IntToStr(Folded) + #10;
      Exit(True);
    end;
    { Runtime lower — never residual-call @SizeOf/@High/@Low/@Length. }
    RhsNode := nil;
    if ANode.ChildCount >= 2 then
      RhsNode := ANode.ChildAt(1);
    if SameText(ANode.ChildAt(0).Text, 'SizeOf') and (RhsNode <> nil) then
    begin
      Folded := 0;
      if RhsNode.NodeKind = gnkIdentifier then
      begin
        if FModel.LookupConstValue(RhsNode.Text + '$arr_len', Folded) and
          (Folded > 0) then
        begin
          CharValue := LongInt(DynArrayElemSizeOfVar(RhsNode.Text));
          if CharValue <= 0 then
            CharValue := 1;
          Folded := Folded * CharValue;
        end
        else if TypeMetaIsDynArrayType(RhsNode.Text) or
          (IsRuntimeArrVar(RhsNode.Text) and
           (not IsStaticRuntimeArrVar(RhsNode.Text))) then
          Folded := 8
        else
        begin
          Operand := LookupRecordVar(RhsNode.Text);
          if Operand <> '' then
            Folded := TypeMetaSize(Operand);
          if Folded <= 0 then
            Folded := TypeMetaSize(RhsNode.Text);
          if Folded <= 0 then
          begin
            TargetTypeId := InferExpressionType(RhsNode);
            if TargetTypeId > 0 then
              TargetTypeId := CanonicalTypeId(TargetTypeId);
            if (TargetTypeId > 0) and (TargetTypeId <= FModel.TypeCount) then
              Folded := TypeMetaSize(FModel.TypeAt(TargetTypeId - 1).Name);
          end;
        end;
      end
      else
      begin
        TargetTypeId := InferExpressionType(RhsNode);
        if TargetTypeId > 0 then
          TargetTypeId := CanonicalTypeId(TargetTypeId);
        if (TargetTypeId > 0) and (TargetTypeId <= FModel.TypeCount) then
          Folded := TypeMetaSize(FModel.TypeAt(TargetTypeId - 1).Name);
      end;
      if Folded <= 0 then
      begin
        { Symbol type for locals/params (SizeOf(AMutex)/SizeOf(LBits)). }
        if RhsNode.NodeKind = gnkIdentifier then
        begin
          TargetTypeId := 0;
          for CharValue := 1 to FModel.SymbolCount do
            if SameText(FModel.SymbolAt(CharValue).Name, RhsNode.Text) and
              (FModel.SymbolAt(CharValue).TypeId > 0) then
            begin
              TargetTypeId := FModel.SymbolAt(CharValue).TypeId;
              Break;
            end;
          if TargetTypeId > 0 then
            TargetTypeId := CanonicalTypeId(TargetTypeId);
          if (TargetTypeId > 0) and (TargetTypeId <= FModel.TypeCount) then
            Folded := TypeMetaSize(FModel.TypeAt(TargetTypeId - 1).Name);
        end;
      end;
      if Folded <= 0 then
        Folded := 8; { pointer-width default — never residual @SizeOf }
      if Folded > 0 then
      begin
        if TryEmitIntLiteral(Folded) then
          Exit(True);
        ABlob := 'int ' + IntToStr(Folded) + #10;
        Exit(True);
      end;
    end
    else if (SameText(ANode.ChildAt(0).Text, 'High') or
      SameText(ANode.ChildAt(0).Text, 'Low') or
      SameText(ANode.ChildAt(0).Text, 'Length')) and (RhsNode <> nil) then
    begin
      { High/Low/Length of dynarray / open-array / string runtime vars. }
      if (RhsNode.NodeKind = gnkIdentifier) and
        (IsRuntimeArrVar(RhsNode.Text) or IsRuntimeStrVar(RhsNode.Text) or
         TypeMetaIsDynArrayType(RhsNode.Text) or
         FModel.LookupStringConstValue(RhsNode.Text + '$arr_elem_type', Operand)) then
      begin
        if not IsRuntimeArrVar(RhsNode.Text) and
          not IsRuntimeStrVar(RhsNode.Text) and
          (TypeMetaIsDynArrayType(RhsNode.Text) or
           FModel.LookupStringConstValue(RhsNode.Text + '$arr_elem_type', Operand)) then
        begin
          RegisterRuntimeArrVar(RhsNode.Text);
          if FModel.LookupConstValue(RhsNode.Text + '$arr_elem_size', Folded) then
            { already on type name — copy to var if needed later }
          else if FModel.LookupConstValue(
            LookupRecordVar(RhsNode.Text) + '$arr_elem_size', Folded) then
            ;
        end;
        if SameText(ANode.ChildAt(0).Text, 'Low') then
        begin
          if TryEmitIntLiteral(0) then
            Exit(True);
          ABlob := 'int 0' + #10;
          Exit(True);
        end;
        if SameText(ANode.ChildAt(0).Text, 'Length') then
        begin
          ABlob := 'var ' + RhsNode.Text + '$len' + #10;
          Exit(True);
        end;
        { High(arr) = Length(arr) - 1 }
        ABlob := 'var ' + RhsNode.Text + '$len' + #10 +
          'int 1' + #10 + 'sub' + #10;
        Exit(True);
      end;
      { High(R.Field) / Length(R.Field) for dynarray record/class fields. }
      if (RhsNode.NodeKind = gnkDotAccess) and (RhsNode.ChildCount >= 2) and
        (RhsNode.ChildAt(0) <> nil) and (RhsNode.ChildAt(1) <> nil) and
        (RhsNode.ChildAt(0).NodeKind = gnkIdentifier) and
        (RhsNode.ChildAt(1).NodeKind = gnkIdentifier) then
      begin
        ReceiverVarName := RhsNode.ChildAt(0).Text;
        ArgName := RhsNode.ChildAt(1).Text;
        if SameText(ReceiverVarName, 'Self') and (FCurrentMethodClass <> '') then
        begin
          ReceiverVarName := 'self';
          FuncName := FCurrentMethodClass;
        end
        else
        begin
          FuncName := LookupClassVar(ReceiverVarName);
          if FuncName = '' then
            FuncName := LookupRecordVar(ReceiverVarName);
        end;
        if (FuncName <> '') and TypeMetaFieldIsDynArray(FuncName, ArgName) then
        begin
          Folded := TypeMetaFieldIndex(FuncName, ArgName);
          if Folded >= 0 then
          begin
            if SameText(ANode.ChildAt(0).Text, 'Low') then
            begin
              if TryEmitIntLiteral(0) then
                Exit(True);
              ABlob := 'int 0' + #10;
              Exit(True);
            end;
            { dynarray field layout: ptr at idx, len at idx+1 }
            if SameText(ANode.ChildAt(0).Text, 'Length') then
            begin
              if TryEmitFieldSelf(Folded + 1, False) and
                SameText(ReceiverVarName, 'self') then
                Exit(True);
              ABlob := 'field ' + ReceiverVarName + ' ' +
                IntToStr(Folded + 1) + #10;
              Exit(True);
            end;
            { High }
            if SameText(ReceiverVarName, 'self') and
              TryEmitFieldSelf(Folded + 1, False) then
              ABlob := ABlob + 'int 1' + #10 + 'sub' + #10
            else
              ABlob := 'field ' + ReceiverVarName + ' ' +
                IntToStr(Folded + 1) + #10 + 'int 1' + #10 + 'sub' + #10;
            Exit(True);
          end;
        end;
      end;
      { Length/High/Low(ident) — last chance via type name or aggressive $len. }
      if (RhsNode.NodeKind = gnkIdentifier) then
      begin
        TargetTypeId := InferExpressionType(RhsNode);
        if TargetTypeId > 0 then
          TargetTypeId := CanonicalTypeId(TargetTypeId);
        if (TargetTypeId > 0) and (TargetTypeId <= FModel.TypeCount) then
          Operand := FModel.TypeAt(TargetTypeId - 1).Name
        else
          Operand := '';
        if SameText(ANode.ChildAt(0).Text, 'Low') then
        begin
          if TryEmitIntLiteral(0) then
            Exit(True);
          ABlob := 'int 0' + #10;
          Exit(True);
        end;
        if (Operand <> '') and
          (TypeMetaIsDynArrayType(Operand) or
           SameText(Operand, 'AnsiString') or
           SameText(Operand, 'String') or
           SameText(Operand, 'RawByteString') or
           SameText(Operand, 'UnicodeString') or
           SameText(Operand, 'WideString')) then
        begin
          if TypeMetaIsDynArrayType(Operand) then
            RegisterRuntimeArrVar(RhsNode.Text)
          else
            RegisterRuntimeStrVar(RhsNode.Text);
          if SameText(ANode.ChildAt(0).Text, 'Length') then
          begin
            ABlob := 'var ' + RhsNode.Text + '$len' + #10;
            Exit(True);
          end;
          { High }
          ABlob := 'var ' + RhsNode.Text + '$len' + #10 +
            'int 1' + #10 + 'sub' + #10;
          Exit(True);
        end;
        { Aggressive: non-type-name identifiers treated as runtime arr/str.
          High(Lines)/Length(Deps) often miss RegisterRuntimeArrVar. }
        if (FModel.FindTypeByName(RhsNode.Text) <= 0) or
          IsRuntimeArrVar(RhsNode.Text) or IsRuntimeStrVar(RhsNode.Text) then
        begin
          if not IsRuntimeStrVar(RhsNode.Text) then
            RegisterRuntimeArrVar(RhsNode.Text);
          if SameText(ANode.ChildAt(0).Text, 'Length') then
          begin
            ABlob := 'var ' + RhsNode.Text + '$len' + #10;
            Exit(True);
          end;
          ABlob := 'var ' + RhsNode.Text + '$len' + #10 +
            'int 1' + #10 + 'sub' + #10;
          Exit(True);
        end;
      end;
      { Length/High(R.Field) — also try string fields via fieldstrlen. }
      if (RhsNode.NodeKind = gnkDotAccess) and (RhsNode.ChildCount >= 2) and
        (RhsNode.ChildAt(0) <> nil) and (RhsNode.ChildAt(1) <> nil) and
        (RhsNode.ChildAt(0).NodeKind = gnkIdentifier) and
        (RhsNode.ChildAt(1).NodeKind = gnkIdentifier) then
      begin
        ReceiverVarName := RhsNode.ChildAt(0).Text;
        ArgName := RhsNode.ChildAt(1).Text;
        if SameText(ReceiverVarName, 'Self') and (FCurrentMethodClass <> '') then
        begin
          ReceiverVarName := 'self';
          FuncName := FCurrentMethodClass;
        end
        else if SameText(ReceiverVarName, 'Result') and
          (FCurrentRetVarName <> '') then
        begin
          FuncName := LookupRecordVar(FCurrentRetVarName);
          if FuncName = '' then
            FuncName := LookupRecordVar('Result');
          if FuncName = '' then
            FuncName := LookupClassVar(FCurrentRetVarName);
        end
        else
        begin
          FuncName := LookupClassVar(ReceiverVarName);
          if FuncName = '' then
            FuncName := LookupRecordVar(ReceiverVarName);
        end;
        if FuncName <> '' then
        begin
          if TypeMetaFieldIsStr(FuncName, ArgName) and
            SameText(ANode.ChildAt(0).Text, 'Length') then
          begin
            Folded := TypeMetaFieldIndex(FuncName, ArgName);
            if Folded >= 0 then
            begin
              if SameText(ReceiverVarName, 'self') then
                ABlob := 'fieldstrlen self ' + IntToStr(Folded) + #10
              else
                ABlob := 'fieldstrlen ' + ReceiverVarName + ' ' +
                  IntToStr(Folded) + #10;
              Exit(True);
            end;
          end;
          if TypeMetaFieldIsDynArray(FuncName, ArgName) then
          begin
            Folded := TypeMetaFieldIndex(FuncName, ArgName);
            if Folded >= 0 then
            begin
              if SameText(ANode.ChildAt(0).Text, 'Low') then
              begin
                if TryEmitIntLiteral(0) then
                  Exit(True);
                ABlob := 'int 0' + #10;
                Exit(True);
              end;
              if SameText(ANode.ChildAt(0).Text, 'Length') then
              begin
                ABlob := 'field ' + ReceiverVarName + ' ' +
                  IntToStr(Folded + 1) + #10;
                Exit(True);
              end;
              ABlob := 'field ' + ReceiverVarName + ' ' +
                IntToStr(Folded + 1) + #10 + 'int 1' + #10 + 'sub' + #10;
              Exit(True);
            end;
          end;
        end;
      end;
    end;
    { Hard stop — never residual-call @SizeOf/@High/@Low/@Length. }
    if SameText(ANode.ChildAt(0).Text, 'Low') then
    begin
      if TryEmitIntLiteral(0) then
        Exit(True);
      ABlob := 'int 0' + #10;
      Exit(True);
    end;
    if SameText(ANode.ChildAt(0).Text, 'SizeOf') then
    begin
      { Unknown layout: pointer-width default keeps Move/FillChar linked. }
      if TryEmitIntLiteral(8) then
        Exit(True);
      ABlob := 'int 8' + #10;
      Exit(True);
    end;
    if (RhsNode <> nil) and (RhsNode.NodeKind = gnkIdentifier) then
    begin
      RegisterRuntimeArrVar(RhsNode.Text);
      if SameText(ANode.ChildAt(0).Text, 'Length') then
      begin
        ABlob := 'var ' + RhsNode.Text + '$len' + #10;
        Exit(True);
      end;
      ABlob := 'var ' + RhsNode.Text + '$len' + #10 +
        'int 1' + #10 + 'sub' + #10;
      Exit(True);
    end;
    if TryEmitIntLiteral(0) then
      Exit(True);
    ABlob := 'int 0' + #10;
    Exit(True);
  end;
  { Type cast TypeName(Arg) — never residual-call @TypeName. Prefer shekCast. }
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount = 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    TryGetTypeCastTargetTypeId(ANode, TargetTypeId) then
  begin
    if not EncodeRuntimeIntExprFold(ANode.ChildAt(1), ABlob, SourceExprId) then
      Exit(False);
    if SourceExprId > 0 then
    begin
      SetLength(CastChildren, 1);
      CastChildren[0] := SourceExprId;
      CastExprId := FModel.AddHirExpr(
        shekCast, TargetTypeId, 0, CastChildren, 0, 0.0, '', '',
        ANode.ByteOffset, shvcScalar);
      if CastExprId > 0 then
      begin
        AExprId := CastExprId;
        ABlob := 'expr ' + IntToStr(CastExprId) + #10;
        Exit(True);
      end;
    end;
    { Residual: keep encoded arg value; cast is identity at i64/ptr handle. }
    Exit(True);
  end;
  { Zero-arg calls (ChildCount = 1: callee only) reach the implicit-self
    member chain below via the FCurrentMethodClass branch; without the >= 1
    guard, `LTypeInfo := GetElementTypeInfo()` fell through and was dropped
    (b4b-i7). }
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) then
  begin
    { Local type cast TypeName(expr): type declared inside the method body
      never enters the type table, so TryGetTypeCastTargetTypeId above missed
      it and the call fallback would residual-call @TypeName (M2:
      PSizeUIntArray / TPthreadKeyDtor, 2 uses). Single-arg identifier head
      with no procedure symbol/body → cast: fold the arg, no call. Inside a
      method, a bare callee may still be an implicit-self method call
      (TSemanticAnalyzer.NextBodyIndexForNameLocal), so only fold when the
      qualified Class.Method lookup also misses. }
    if (ANode.ChildCount = 2) and (ANode.ChildAt(1) <> nil) and
      (not LookupProcedureBody(ANode.ChildAt(0).Text, BranchNode, DeclNode)) and
      (FModel.FindSymbolByName(ANode.ChildAt(0).Text) = 0) and
      ((FCurrentMethodClass = '') or
       ((FModel.FindSymbolByName(FCurrentMethodClass + '.' + ANode.ChildAt(0).Text) = 0) and
        (not LookupProcedureBody(FCurrentMethodClass + '.' + ANode.ChildAt(0).Text,
          BranchNode, DeclNode)))) then
    begin
      ABlob := '';
      if EncodeRuntimeIntExprFold(ANode.ChildAt(1), ABlob) then
        Exit(True);
    end;
    if TryEncodeInterlockedValueCall(ANode, ABlob) then
      Exit(True);
    { Callee formal meta BEFORE arg encoding: by-ref formals need the variable
      ADDRESS ('varref'), not a value load — define-side ABI expects ptr for
      `var` params while residual 'var X' pushes the loaded value (v2.28). }
    CallHasFormalMeta := False;
    SetLength(CallFormalByRef, 0);
    if (ANode.ChildCount >= 1) and (ANode.ChildAt(0) <> nil) then
    begin
      BranchNode := nil;
      DeclNode := nil;
      if LookupProcedureBody(ANode.ChildAt(0).Text, BranchNode, DeclNode) and
        (DeclNode <> nil) then
      begin
        SetLength(CallFormalByRef, ANode.ChildCount - 1);
        for K := 0 to Length(CallFormalByRef) - 1 do
          CallFormalByRef[K] := False;
        ArgIndex := 0;
        for K := 0 to DeclNode.ChildCount - 1 do
        begin
          RhsNode := DeclNode.ChildAt(K);
          if (RhsNode = nil) or
            (RhsNode.NodeKind <> gnkParameterList) then
            Continue;
          for StrExprId := 0 to RhsNode.ChildCount - 1 do
          begin
            if ArgIndex >= Length(CallFormalByRef) then
              Break;
            ParamNode := RhsNode.ChildAt(StrExprId);
            if (ParamNode = nil) or
              (ParamNode.NodeKind <> gnkParameterDecl) then
              Continue;
            CallFormalByRef[ArgIndex] := ParamNameIsByRef(ParamNode.Text);
            Inc(ArgIndex);
          end;
        end;
        CallHasFormalMeta := True;
      end;
    end;
    ABlob := '';
    StrCallArgCount := 0;
    for StrCallIdx := 1 to ANode.ChildCount - 1 do
    begin
      if (ANode.ChildAt(StrCallIdx) <> nil) and
        (ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) and
        IsRuntimeStrVar(ANode.ChildAt(StrCallIdx).Text) then
      begin
        ABlob := ABlob + 'strvar ' + ANode.ChildAt(StrCallIdx).Text + #10;
        Inc(StrCallArgCount, 2);
      end
      else if (ANode.ChildAt(StrCallIdx) <> nil) and
        (ANode.ChildAt(StrCallIdx).NodeKind = gnkStringLiteral) then
      begin
        ABlob := ABlob + 'strlit ' + ANode.ChildAt(StrCallIdx).Text + #10;
        Inc(StrCallArgCount, 2);
      end
      else if (ANode.ChildAt(StrCallIdx) <> nil) and
        (ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) and
        EvaluateStringConstant(ANode.ChildAt(StrCallIdx), FuncName) then
      begin
        { String const identifier formal (PATH_ENV_PREFIX='PATH='): fold to
          strlit, not residual call @CONST() (M2 const-upper). }
        ABlob := ABlob + 'strlit ' +
          EncodePascalStringLiteral(FuncName) + #10;
        Inc(StrCallArgCount, 2);
      end
      else if (ANode.ChildAt(StrCallIdx) <> nil) and
        (ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) and
        IsRuntimeArrVar(ANode.ChildAt(StrCallIdx).Text) then
      begin
        ABlob := ABlob + 'arrvar ' + ANode.ChildAt(StrCallIdx).Text + #10;
        Inc(StrCallArgCount, 2);
      end
      else if CallHasFormalMeta and CallFormalByRef[StrCallIdx - 1] and
        (ANode.ChildAt(StrCallIdx) <> nil) and
        (ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) then
      begin
        { By-ref formal + identifier arg → address channel, never a value
          load. Implicit-self fields go via self+field_ref; every other name
          via varref (builder resolves alloca / var-param deref / global_ref
          — same shape as the interlocked encoder above). }
        if (FCurrentMethodClass <> '') and
          (TypeMetaFieldIndex(FCurrentMethodClass,
            ANode.ChildAt(StrCallIdx).Text) >= 0) then
          ABlob := ABlob + 'var self' + #10 + 'field_ref ' +
            IntToStr(TypeMetaFieldIndex(FCurrentMethodClass,
              ANode.ChildAt(StrCallIdx).Text)) + #10
        else
          ABlob := ABlob + 'varref ' +
            ANode.ChildAt(StrCallIdx).Text + #10;
        Inc(StrCallArgCount);
      end
      else if CallHasFormalMeta and CallFormalByRef[StrCallIdx - 1] and
        (ANode.ChildAt(StrCallIdx) <> nil) and
        TryByRefFieldAddressBlob(ANode.ChildAt(StrCallIdx), Operand) then
      begin
        { By-ref formal + field-access arg → field address (gep, no load). }
        ABlob := ABlob + Operand;
        Inc(StrCallArgCount);
      end
      else if (ANode.ChildAt(StrCallIdx) <> nil) and
        (ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) and
        FModel.LookupConstValue(ANode.ChildAt(StrCallIdx).Text, Folded) then
      begin
        { Enum/const identifiers fold here at the source: FoldCore's
          structured-expr fallback emits 'expr N' tokens that push nothing in
          cond-br blob consumption — the call then underflows its declared
          arity and opt sees zero-padded operands (v2.28 campaign). }
        ABlob := ABlob + 'int ' + IntToStr(Folded) + #10;
        Inc(StrCallArgCount);
      end
      else if EncodeRuntimeIntExprFold(ANode.ChildAt(StrCallIdx), FuncName) then
      begin
        ABlob := ABlob + FuncName;
        Inc(StrCallArgCount);
      end
      else
      begin
        Exit(False);
      end;
    end;
    if LookupProcedureBody(ANode.ChildAt(0).Text, BranchNode, DeclNode) and
      (DeclNode <> nil) then
    begin
      StrCallIdx := ANode.ChildCount - 1;
      for K := 0 to DeclNode.ChildCount - 1 do
      begin
        if (DeclNode.ChildAt(K) = nil) or
          (DeclNode.ChildAt(K).NodeKind <> gnkParameterList) then
          Continue;
        ArgIndex := 0;
        for DotPos := 0 to DeclNode.ChildAt(K).ChildCount - 1 do
        begin
          RhsNode := DeclNode.ChildAt(K).ChildAt(DotPos);
          if (RhsNode = nil) or (RhsNode.NodeKind <> gnkParameterDecl) then
            Continue;
          Inc(ArgIndex);
          if ArgIndex > StrCallIdx then
          begin
            if RhsNode.ChildCount > 1 then
            begin
              if EncodeRuntimeIntExprFold(
                RhsNode.ChildAt(RhsNode.ChildCount - 1), FuncName) then
              begin
                ABlob := ABlob + FuncName;
                Inc(StrCallArgCount);
              end;
            end;
          end;
        end;
        Break;
      end;
    end;
    if Pos('specialize ', ANode.ChildAt(0).Text) = 1 then
    begin
      ArgName := Copy(ANode.ChildAt(0).Text, 12, Length(ANode.ChildAt(0).Text) - 11);
      DotPos := Pos('<', ArgName);
      if DotPos > 0 then
      begin
        FuncName := Copy(ArgName, 1, DotPos - 1);
        Operand := Copy(ArgName, DotPos + 1, Pos('>', ArgName) - DotPos - 1);
        K := Pos('.', FuncName);
        if K > 0 then
        begin
          ArgName := LookupClassVar(Copy(FuncName, 1, K - 1));
          if ArgName <> '' then
            FuncName := ArgName + '.' + Copy(FuncName, K + 1, Length(FuncName) - K);
          ArgName := FuncName + '$' + StringReplace(StringReplace(Operand, ', ', '$', True), ',', '$', True);
          if not LookupProcedureBody(ArgName, BranchNode, DeclNode) then
          begin
            for K := 0 to LongInt(FProcedureBodies.Count) - 1 do
              if (Pos(FuncName + '<', FProcedureBodies[K].Name) = 1) then
              begin
                RegisterProcedureBody(ArgName,
                  FProcedureBodies[K].Body, FProcedureBodies[K].Decl,
                  FProcedureBodies[K].OwnerUnitId);
                FGenericWorkQueue.Push(LongInt(FProcedureBodies.Count) - 1);
                Break;
              end;
          end;
          Operand := Copy(Copy(ANode.ChildAt(0).Text, 12, Length(ANode.ChildAt(0).Text) - 11), 1, Pos('.', Copy(ANode.ChildAt(0).Text, 12, Length(ANode.ChildAt(0).Text) - 11)) - 1);
          ABlob := 'var ' + Operand + #10 + ABlob +
            'call ' + ArgName + ' ' + IntToStr(StrCallArgCount + 1) + #10;
        end
        else
        begin
          ArgName := FuncName + '$' + StringReplace(StringReplace(Operand, ', ', '$', True), ',', '$', True);
          if not LookupProcedureBody(ArgName, BranchNode, DeclNode) then
          begin
            for K := 0 to LongInt(FProcedureBodies.Count) - 1 do
              if (Pos(FuncName + '<', FProcedureBodies[K].Name) = 1) then
              begin
                RegisterProcedureBody(ArgName,
                  FProcedureBodies[K].Body, FProcedureBodies[K].Decl,
                  FProcedureBodies[K].OwnerUnitId);
                FGenericWorkQueue.Push(LongInt(FProcedureBodies.Count) - 1);
                Break;
              end;
          end;
          ABlob := ABlob + 'call ' + ArgName + ' ' +
            IntToStr(StrCallArgCount) + #10;
        end;
      end
      else
        ABlob := ABlob + 'call ' + ArgName + ' ' +
          IntToStr(StrCallArgCount) + #10;
    end
    else if (TypeMetaSize(ANode.ChildAt(0).Text) > 0) and
      (LookupClassVar(ANode.ChildAt(0).Text) = '') and
      (ANode.ChildCount = 2) then
    begin
      { Sized type cast residual (record/alias): keep arg blob, no call. }
      Exit(True);
    end
    else if (FCurrentMethodClass <> '') and
      (Pos('inherited ', ANode.ChildAt(0).Text) = 1) then
    begin
      { inherited Create → nearest ancestor with Create body/symbol; skip bare
        TObject when a non-TObject parent name is available (qualified parents
        may collapse ParentTypeId to TObject). }
      ArgName := Copy(ANode.ChildAt(0).Text, 12, Length(ANode.ChildAt(0).Text) - 11);
      FuncName := NextClassAncestorName(FCurrentMethodClass);
      BaseName := '';
      ReceiverVarName := '';
      while FuncName <> '' do
      begin
        if LookupProcedureBody(FuncName + '.' + ArgName, BranchNode, DeclNode) or
          (FModel.FindSymbolByName(FuncName + '.' + ArgName) <> 0) then
        begin
          if not SameText(FuncName, 'TObject') then
          begin
            BaseName := FuncName;
            Break;
          end
          else if BaseName = '' then
            BaseName := FuncName;
        end;
        if (ReceiverVarName = '') and (not SameText(FuncName, 'TObject')) then
          ReceiverVarName := FuncName;
        FuncName := NextClassAncestorName(FuncName);
      end;
      if (BaseName <> '') and (not SameText(BaseName, 'TObject')) then
      begin
        FuncName := BaseName;
        { The matched ancestor station may be an alias (ECore): canonicalize
          via $resolve table / alias peel so the callee names a real define.
          Receiver-fallback stations below stay raw by design. }
        Operand := ResolveClassMethodCalleeName(FuncName, ArgName);
        if Operand <> '' then
        begin
          ABlob := 'var self' + #10 + ABlob +
            'call ' + Operand + ' ' + IntToStr(StrCallArgCount + 1) + #10;
          Exit(True);
        end;
      end
      else if ReceiverVarName <> '' then
        FuncName := ReceiverVarName
      else
        FuncName := BaseName;
      if FuncName <> '' then
        ABlob := 'var self' + #10 + ABlob +
          'call ' + FuncName + '.' + ArgName +
          ' ' + IntToStr(StrCallArgCount + 1) + #10
      else
        ABlob := ABlob + 'call ' + ANode.ChildAt(0).Text + ' ' +
          IntToStr(StrCallArgCount) + #10;
    end
    else if (FCurrentMethodClass <> '') then
    begin
      { Prefer procedure-body index (Class.Method) over FindSymbol — method
        symbols may be absent while bodies are registered; nested locals of
        methods still set FCurrentMethodClass via outer-frame seed. }
      FuncName := FCurrentMethodClass;
      while FuncName <> '' do
      begin
        if LookupProcedureBody(FuncName + '.' + ANode.ChildAt(0).Text,
          BranchNode, DeclNode) or
          (FModel.FindSymbolByName(FuncName + '.' + ANode.ChildAt(0).Text) <> 0) then
          Break;
        FuncName := NextClassAncestorName(FuncName);
      end;
      if FuncName <> '' then
      begin
        Folded := TypeMetaVmtSlot(FCurrentMethodClass, ANode.ChildAt(0).Text);
        if Folded >= 0 then
          ABlob := 'var self' + #10 + ABlob +
            'vcall ' + IntToStr(Folded) + ' ' + IntToStr(StrCallArgCount) + #10
        else
          ABlob := 'var self' + #10 + ABlob +
            'call ' + FuncName + '.' + ANode.ChildAt(0).Text +
            ' ' + IntToStr(StrCallArgCount + 1) + #10;
      end
      else
        ABlob := ABlob + 'call ' +
          EffectiveRuntimeCalleeName(ANode.ChildAt(0).Text, DeclNode,
            ANode.ChildCount - 1) + ' ' +
          IntToStr(StrCallArgCount) + #10;
    end
    else
      { Always align with SeedFunctionBodies EffName (HasOverload → mangled);
        arity-aware so non-first overloads bind their own shape. }
      ABlob := ABlob + 'call ' +
        EffectiveRuntimeCalleeName(ANode.ChildAt(0).Text, DeclNode,
          ANode.ChildCount - 1) + ' ' +
        IntToStr(StrCallArgCount) + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkDotAccess) and
    (ANode.ChildAt(0).ChildCount >= 2) and
    (ANode.ChildAt(0).ChildAt(0) <> nil) and
    (ANode.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(0).ChildAt(1) <> nil) and
    (ANode.ChildAt(0).ChildAt(1).NodeKind = gnkIdentifier) and
    (TypeMetaSize(ANode.ChildAt(0).ChildAt(0).Text) > 0) and
    (LookupClassVar(ANode.ChildAt(0).ChildAt(0).Text) = '') then
  begin
    { ClassName.Create in expression position (raise E.Create(...), nested
      temps). Alloc/VMT keep source class; call the nearest ancestor that
      actually declares/defines the ctor (prefer body over bare symbol so
      empty subclasses resolve to parent Create, not residual Child.Create). }
    Inc(FBlockLabelCounter);
    OwnerClassName := ANode.ChildAt(0).ChildAt(0).Text;
    FieldName := ANode.ChildAt(0).ChildAt(1).Text;
    BaseName := ResolveClassMethodCalleeName(OwnerClassName, FieldName);
    if BaseName = '' then
      BaseName := OwnerClassName + '.' + FieldName;
    ArgName := '$new_tmp_' + IntToStr(FBlockLabelCounter);
    RegisterRuntimeVar(ArgName);
    RegisterClassVar(ArgName, OwnerClassName);
    Folded := TypeMetaSize(OwnerClassName);
    Operand := ArgName + #9 + BaseName;
    for StrCallIdx := 1 to ANode.ChildCount - 1 do
    begin
      RhsNode := ANode.ChildAt(StrCallIdx);
      if RhsNode = nil then
        Continue;
      if RhsNode.NodeKind = gnkStringLiteral then
      begin
        Inc(FBlockLabelCounter);
        BaseName := '$str_arg_' + IntToStr(FBlockLabelCounter);
        RegisterRuntimeVar(BaseName);
        RegisterRuntimeStrVar(BaseName);
        FModel.AddTypedHirNode('var-decl-tstring-runtime', BaseName, 0, 0, BaseName);
        FModel.AddTypedHirNode('assign-tstring-literal-runtime',
          BaseName, 0, 0, DecodePascalStringLiteral(RhsNode.Text));
        Operand := Operand + #9 + 'strvar ' + BaseName + #10;
      end
      else if (RhsNode.NodeKind = gnkIdentifier) and
        IsRuntimeStrVar(RhsNode.Text) then
        Operand := Operand + #9 + 'strvar ' + RhsNode.Text + #10
      else if EncodeRuntimeIntExprFold(RhsNode, BaseName) then
        Operand := Operand + #9 + BaseName;
    end;
    FModel.AddTypedHirNode(
      'class-new-runtime', IntToStr(Folded), 0, 0, Operand);
    if (TypeMetaVmtCount(OwnerClassName) > 0) or
      (TypeMetaInterfaces(OwnerClassName) <> '') then
      FModel.AddTypedHirNode('vmt-store-runtime',
        OwnerClassName, 0, 0, ArgName + #9 + OwnerClassName);
    ABlob := 'var ' + ArgName + #10;
    Exit(True);
  end;
  { DotAccess method reference `R.Method` used as a value (F := R.M): no
    parens, so gnkFunctionCall never wraps it — encode as a zero-arg member
    call with receiver. Method-only: unresolved members fall through to the
    field-access branches below (b4b-i7). Property reads (R.Data, $read
    const present) are NOT method refs — they fall through to the property
    branch, otherwise @Type.Data residual-calls the property name (b4b-i8). }
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount = 2) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    ReceiverVarName := ANode.ChildAt(0).Text;
    if SameText(ReceiverVarName, 'Self') and (FCurrentMethodClass <> '') then
    begin
      ReceiverVarName := 'self';
      FuncName := FCurrentMethodClass;
    end
    else
      FuncName := LookupClassVar(ReceiverVarName);
    if (FuncName <> '') and
      (not FModel.LookupStringConstValue(
        FuncName + '.' + ANode.ChildAt(1).Text + '$read', ArgName)) then
    begin
      ArgName := ResolveClassMethodCalleeName(FuncName,
        ANode.ChildAt(1).Text);
      if (ArgName <> '') or
        (TypeMetaVmtSlot(FuncName, ANode.ChildAt(1).Text) >= 0) then
      begin
        if ArgName = '' then
          ArgName := FuncName + '.' + ANode.ChildAt(1).Text;
        { Receiver may be a current-class field — load from self+idx; a bare
          'var FField' has no alloca and degrades to call @FField. }
        if (ReceiverVarName <> 'self') and
          (TypeMetaFieldIndex(FCurrentMethodClass, ReceiverVarName) >= 0) then
        begin
          BaseName := 'field self ' +
            IntToStr(TypeMetaFieldIndex(FCurrentMethodClass, ReceiverVarName));
          if TypeMetaFieldIsPtr(FCurrentMethodClass, ReceiverVarName) then
            BaseName := BaseName + ' p' + #10
          else
            BaseName := BaseName + #10;
        end
        else
          BaseName := 'var ' + ReceiverVarName + #10;
        { Virtual/abstract members (TCollection.GetCount virtual abstract) have
          no body — dispatch through the vmt instead of call @Class.Member,
          which stays undefined (b4b-i8). }
        Folded := TypeMetaVmtSlot(FuncName, ANode.ChildAt(1).Text);
        if Folded >= 0 then
        begin
          ABlob := BaseName + 'vcall ' + IntToStr(Folded) + ' 0';
          if TypeMetaRetPtr(FuncName, ANode.ChildAt(1).Text) then
            ABlob := ABlob + ' p' + #10
          else
            ABlob := ABlob + #10;
        end
        else
          ABlob := BaseName + 'call ' + ArgName + ' 1' + #10;
        Exit(True);
      end;
    end;
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    (TypeMetaSize(ANode.ChildAt(0).Text) > 0) and
    (LookupClassVar(ANode.ChildAt(0).Text) = '') and
    (TypeMetaIsClass(ANode.ChildAt(0).Text) or
     SameText(ANode.ChildAt(1).Text, 'Create')) then
  begin
    { Bare Type.Create (no parens) — same class-new as FunctionCall form. }
    Inc(FBlockLabelCounter);
    OwnerClassName := ANode.ChildAt(0).Text;
    FieldName := ANode.ChildAt(1).Text;
    BaseName := ResolveClassMethodCalleeName(OwnerClassName, FieldName);
    if BaseName = '' then
      BaseName := OwnerClassName + '.' + FieldName;
    ArgName := '$new_tmp_' + IntToStr(FBlockLabelCounter);
    RegisterRuntimeVar(ArgName);
    RegisterClassVar(ArgName, OwnerClassName);
    Folded := TypeMetaSize(OwnerClassName);
    Operand := ArgName + #9 + BaseName;
    FModel.AddTypedHirNode(
      'class-new-runtime', IntToStr(Folded), 0, 0, Operand);
    if (TypeMetaVmtCount(OwnerClassName) > 0) or
      (TypeMetaInterfaces(OwnerClassName) <> '') then
      FModel.AddTypedHirNode('vmt-store-runtime',
        OwnerClassName, 0, 0, ArgName + #9 + OwnerClassName);
    ABlob := 'var ' + ArgName + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkDotAccess) and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    { P^.Rec.Field value before unit.path.FreeFunc bare-name steal. }
    if TryPointerFieldValueBlob(ANode, ABlob) then
      Exit(True);
    { unit.path.FreeFunc bare call — rightmost name. }
    ArgName := ANode.ChildAt(1).Text;
    if LookupProcedureBody(ArgName, BranchNode, DeclNode) or
      (LookupPtrReturnFunc(ArgName) <> '') then
    begin
      ABlob := 'call ' + EffectiveRuntimeCalleeName(ArgName, DeclNode) + ' 0' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkDotAccess) and
    (ANode.ChildAt(0).ChildCount >= 2) and
    (ANode.ChildAt(0).ChildAt(1) <> nil) and
    (ANode.ChildAt(0).ChildAt(1).NodeKind = gnkIdentifier) and
    ((ANode.ChildAt(0).ChildAt(0) = nil) or
     (ANode.ChildAt(0).ChildAt(0).NodeKind = gnkDotAccess) or
     (TypeMetaSize(ANode.ChildAt(0).ChildAt(0).Text) <= 0)) then
  begin
    { P^.Rec.ProcField(args) — load code pointer then indirect call.
      Must win over unit.path.FreeFunc() when the leaf name is also a free fn. }
    if TryPointerFieldValueBlob(ANode.ChildAt(0), FuncName) then
    begin
      StrCallArgCount := 0;
      ABlob := '';
      for StrCallIdx := 1 to ANode.ChildCount - 1 do
        if (ANode.ChildAt(StrCallIdx) <> nil) and
          EncodeRuntimeIntExprFold(ANode.ChildAt(StrCallIdx), BaseName) then
        begin
          ABlob := ABlob + BaseName;
          Inc(StrCallArgCount);
        end;
      ABlob := ABlob + FuncName + 'icall ' + IntToStr(StrCallArgCount) + #10;
      Exit(True);
    end;
    { unit.path.FreeFunc() — not Class.Method. }
    ArgName := ANode.ChildAt(0).ChildAt(1).Text;
    if LookupProcedureBody(ArgName, BranchNode, DeclNode) or
      (LookupPtrReturnFunc(ArgName) <> '') then
    begin
      StrCallArgCount := 0;
      ABlob := '';
      for StrCallIdx := 1 to ANode.ChildCount - 1 do
        if (ANode.ChildAt(StrCallIdx) <> nil) and
          EncodeRuntimeIntExprFold(ANode.ChildAt(StrCallIdx), BaseName) then
        begin
          ABlob := ABlob + BaseName;
          Inc(StrCallArgCount);
        end;
      ABlob := ABlob + 'call ' + EffectiveRuntimeCalleeName(ArgName, DeclNode) +
        ' ' + IntToStr(StrCallArgCount) + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkDotAccess) and
    (ANode.ChildAt(0).ChildCount >= 2) and
    (ANode.ChildAt(0).ChildAt(0) <> nil) and
    (ANode.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(0).ChildAt(1) <> nil) and
    (ANode.ChildAt(0).ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    ReceiverVarName := ANode.ChildAt(0).ChildAt(0).Text;
    if SameText(ReceiverVarName, 'Self') and (FCurrentMethodClass <> '') then
    begin
      ReceiverVarName := 'self';
      FuncName := FCurrentMethodClass;
    end
    else
      FuncName := LookupClassVar(ReceiverVarName);
    if FuncName <> '' then
    begin
      { The receiver may be a current-class field (class-var registered by
        the walk); its value must load from self+idx — a bare 'var FField'
        has no alloca and degrades to call @FField (b4b-i7). }
      if (ReceiverVarName <> 'self') and
        (TypeMetaFieldIndex(FCurrentMethodClass, ReceiverVarName) >= 0) then
      begin
        BaseName := 'field self ' +
          IntToStr(TypeMetaFieldIndex(FCurrentMethodClass, ReceiverVarName));
        if TypeMetaFieldIsPtr(FCurrentMethodClass, ReceiverVarName) then
          BaseName := BaseName + ' p' + #10
        else
          BaseName := BaseName + #10;
      end
      else
        BaseName := 'var ' + ReceiverVarName + #10;
      ABlob := '';
      StrCallArgCount := 0;
      for StrCallIdx := 1 to ANode.ChildCount - 1 do
      begin
        if ANode.ChildAt(StrCallIdx) = nil then
          Continue;
        if (ANode.ChildAt(StrCallIdx).NodeKind = gnkStringLiteral) then
        begin
          Inc(FBlockLabelCounter);
          ArgName := '$str_arg_' + IntToStr(FBlockLabelCounter);
          RegisterRuntimeVar(ArgName);
          RegisterRuntimeStrVar(ArgName);
          FModel.AddTypedHirNode('var-decl-tstring-runtime', ArgName, 0, 0, ArgName);
          FModel.AddTypedHirNode('assign-tstring-literal-runtime',
            ArgName, 0, 0,
            DecodePascalStringLiteral(ANode.ChildAt(StrCallIdx).Text));
          ABlob := ABlob + 'strvar ' + ArgName + #10;
          Inc(StrCallArgCount, 2);
        end
        else if (ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) and
          IsRuntimeStrVar(ANode.ChildAt(StrCallIdx).Text) then
        begin
          ABlob := ABlob + 'strvar ' + ANode.ChildAt(StrCallIdx).Text + #10;
          Inc(StrCallArgCount, 2);
        end
        else if (ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) and
          SameText(ANode.ChildAt(StrCallIdx).Text, 'Result') and
          (FCurrentRetVarName <> '') then
        begin
          { out/array Result → address for interface/class method formals. }
          ABlob := ABlob + 'varref ' + FCurrentRetVarName + #10;
          Inc(StrCallArgCount);
        end
        else if (ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) and
          IsRuntimeArrVar(ANode.ChildAt(StrCallIdx).Text) then
        begin
          ABlob := ABlob + 'var ' + ANode.ChildAt(StrCallIdx).Text + '$ptr' + #10;
          Inc(StrCallArgCount);
        end
        else if EvaluateIntegerConstant(ANode.ChildAt(StrCallIdx), Folded) then
        begin
          ABlob := ABlob + 'int ' + IntToStr(Folded) + #10;
          Inc(StrCallArgCount);
        end
        else if EncodeRuntimeIntExprFold(ANode.ChildAt(StrCallIdx), ArgName) then
        begin
          ABlob := ABlob + ArgName;
          Inc(StrCallArgCount);
        end;
      end;
      Folded := TypeMetaVmtSlot(FuncName, ANode.ChildAt(0).ChildAt(1).Text);
      if (Folded >= 0) and (not TypeMetaIsInterface(FuncName)) then
      begin
        ABlob := BaseName +
          ABlob + 'vcall ' + IntToStr(Folded) + ' ' +
          IntToStr(StrCallArgCount);
        if TypeMetaRetPtr(FuncName, ANode.ChildAt(0).ChildAt(1).Text) then
          ABlob := ABlob + ' p' + #10
        else
          ABlob := ABlob + #10;
      end
      else if (Folded >= 0) and TypeMetaIsInterface(FuncName) then
      begin
        { Multi-arg interface: ExtraArgCount = StrCallArgCount (args already
          pushed). Zero-arg keeps ExtraArgCount 0. Avoid bare @IHasher.Method. }
        ABlob := BaseName +
          ABlob + 'ivcall ' + IntToStr(Folded) + ' ' +
          IntToStr(StrCallArgCount);
        if TypeMetaRetPtr(FuncName, ANode.ChildAt(0).ChildAt(1).Text) then
          ABlob := ABlob + ' p' + #10
        else
          ABlob := ABlob + #10;
      end
      else
      begin
        ArgName := FuncName;
        while (ArgName <> '') and
          (FModel.FindSymbolByName(ArgName + '.' +
            ANode.ChildAt(0).ChildAt(1).Text) = 0) do
          ArgName := NextClassAncestorName(ArgName);
        if ArgName = '' then ArgName := FuncName;
        ABlob := BaseName +
          ABlob + 'call ' + ArgName + '.' +
          ANode.ChildAt(0).ChildAt(1).Text + ' ' +
          IntToStr(StrCallArgCount + 1) + #10;
      end;
      Exit(True);
    end;
  end;
  { Single-char literal 'x' / #num folds to its ordinal in value context
    (IsSep body: Result := C = '/'). Without this the RHS of comparisons
    stays un-encodable and the whole assignment is silently dropped. }
  if ((ANode.NodeKind = gnkStringLiteral) and (Length(ANode.Text) = 3) and
    (ANode.Text[1] = '''') and (ANode.Text[3] = '''')) then
  begin
    Folded := Ord(ANode.Text[2]);
    { Plain 'int N', not structured 'expr': a char literal can sit in the
      middle of a comparison blob (IsSep: C = '/'), where a structured
      expr line is dropped (ParseIntExprArgTyped does not push it) and
      the compare loses its left operand. }
    ABlob := 'int ' + IntToStr(Folded) + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkCharLiteral) and (Length(ANode.Text) >= 2) then
  begin
    if ANode.Text[1] = '''' then
      Folded := Ord(ANode.Text[2])
    else if ANode.Text[1] = '#' then
    begin
      { #num / #$hex char-code literal: fold to the code, not the '#'
        ordinal. Multi-segment strings (#13#10) are not scalar chars —
        leave them to the string paths (returns False). }
      if Pos('#', Copy(ANode.Text, 2, Length(ANode.Text))) > 0 then
        Exit(False);
      Folded := 0;
      if (Length(ANode.Text) >= 3) and (ANode.Text[2] = '$') then
      begin
        for K := 3 to Length(ANode.Text) do
        begin
          Folded := Folded * 16;
          if (ANode.Text[K] >= '0') and (ANode.Text[K] <= '9') then
            Folded := Folded + Ord(ANode.Text[K]) - Ord('0')
          else if (ANode.Text[K] >= 'a') and (ANode.Text[K] <= 'f') then
            Folded := Folded + Ord(ANode.Text[K]) - Ord('a') + 10
          else if (ANode.Text[K] >= 'A') and (ANode.Text[K] <= 'F') then
            Folded := Folded + Ord(ANode.Text[K]) - Ord('A') + 10
          else
            Exit(False);
        end;
      end
      else
      begin
        for K := 2 to Length(ANode.Text) do
          if (ANode.Text[K] >= '0') and (ANode.Text[K] <= '9') then
            Folded := Folded * 10 + Ord(ANode.Text[K]) - Ord('0')
          else
            Exit(False);
      end;
    end
    else
      Exit(False);
    ABlob := 'int ' + IntToStr(Folded) + #10;
    Exit(True);
  end;
  if NeedsFoldFallback(ANode) then
  begin
    { Under NoFold still fold pure intrinsics (SizeOf/Ord/...) — otherwise
      SizeOf(staticArray) becomes a bogus call @SizeOf and fails llvm-as. }
    if (not FNoFold) or
      ((ANode.NodeKind = gnkIdentifier) and
       FModel.LookupConstValue(ANode.Text, Folded)) or
      ((ANode.NodeKind = gnkDotAccess) and
       EvaluateIntegerConstant(ANode, Folded)) or
      ((ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
       (ANode.ChildAt(0) <> nil) and
       (SameText(ANode.ChildAt(0).Text, 'SizeOf') or
        SameText(ANode.ChildAt(0).Text, 'Ord') or
        SameText(ANode.ChildAt(0).Text, 'High') or
        SameText(ANode.ChildAt(0).Text, 'Low') or
        SameText(ANode.ChildAt(0).Text, 'Pred') or
        SameText(ANode.ChildAt(0).Text, 'Succ'))) then
      if EvaluateIntegerConstant(ANode, Folded) then
      begin
        if TryEmitIntLiteral(Folded) then
          Exit(True);
        ABlob := 'int ' + IntToStr(Folded) + #10;
        Exit(True);
      end;
  end;
  if (FCurrentMethodClass <> '') and (ANode.NodeKind = gnkIdentifier) and
    (ANode.Text <> '') and
    (TypeMetaFieldIndex(FCurrentMethodClass, ANode.Text) >= 0) then
  begin
    Folded := TypeMetaFieldIndex(FCurrentMethodClass, ANode.Text);
    if TryEmitFieldSelf(Folded, TypeMetaFieldIsPtr(FCurrentMethodClass, ANode.Text)) then
      Exit(True);
    ABlob := 'field self ' + IntToStr(Folded);
    if TypeMetaFieldIsPtr(FCurrentMethodClass, ANode.Text) then
      ABlob := ABlob + ' p' + #10
    else
      ABlob := ABlob + #10;
    Exit(True);
  end;
  if (FCurrentMethodClass <> '') and (ANode.NodeKind = gnkDotAccess) and
    (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    TypeMetaFieldIsPtr(FCurrentMethodClass, ANode.ChildAt(0).Text) and
    (TypeMetaFieldIndex(FCurrentMethodClass, ANode.ChildAt(0).Text) >= 0) then
  begin
    Folded := TypeMetaFieldIndex(FCurrentMethodClass, ANode.ChildAt(0).Text);
    FuncName := '';
    for StrCallIdx := 1 to FModel.SymbolCount do
      if SameText(FModel.SymbolAt(StrCallIdx).Name, ANode.ChildAt(0).Text) and
        SameText(FModel.SymbolAt(StrCallIdx).Kind, 'field') then
      begin
        if FModel.SymbolAt(StrCallIdx).TypeId > 0 then
          FuncName := FModel.TypeAt(
            FModel.SymbolAt(StrCallIdx).TypeId - 1).Name;
        Break;
      end;
    if (FuncName <> '') and
      (TypeMetaFieldIndex(FuncName, ANode.ChildAt(1).Text) >= 0) then
    begin
      StrCallIdx := LongInt(TypeMetaFieldIndex(FuncName, ANode.ChildAt(1).Text));
      if TypeMetaFieldIsPtr(FuncName, ANode.ChildAt(1).Text) then
        ABlob := 'field self ' + IntToStr(Folded) + ' p' + #10 +
          'int ' + IntToStr(StrCallIdx) + #10 + 'arr_load_ptr' + #10
      else
        ABlob := 'field self ' + IntToStr(Folded) + ' p' + #10 +
          'int ' + IntToStr(StrCallIdx) + #10 + 'arr_load' + #10;
      Exit(True);
    end;
  end;
  if (FCurrentMethodClass <> '') and (ANode.NodeKind = gnkDotAccess) and
    (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    (TypeMetaFieldIndex(FCurrentMethodClass + '.' + ANode.ChildAt(0).Text,
      ANode.ChildAt(1).Text) >= 0) then
  begin
    Folded := TypeMetaFieldIndex(FCurrentMethodClass + '.' + ANode.ChildAt(0).Text,
      ANode.ChildAt(1).Text);
    if TryEmitFieldSelf(Folded, False) then
      Exit(True);
    ABlob := 'field self ' + IntToStr(Folded) + #10;
    Exit(True);
  end;
  if (FCurrentMethodClass <> '') and (ANode.NodeKind = gnkIdentifier) and
    (Pos('inherited ', ANode.Text) = 1) then
  begin
    ArgName := Copy(ANode.Text, 11, Length(ANode.Text));
    FuncName := NextClassAncestorName(FCurrentMethodClass);
    BaseName := '';
    ReceiverVarName := '';
    while FuncName <> '' do
    begin
      if LookupProcedureBody(FuncName + '.' + ArgName, BranchNode, DeclNode) or
        (FModel.FindSymbolByName(FuncName + '.' + ArgName) <> 0) then
      begin
        if not SameText(FuncName, 'TObject') then
        begin
          BaseName := FuncName;
          Break;
        end
        else if BaseName = '' then
          BaseName := FuncName;
      end;
      if (ReceiverVarName = '') and (not SameText(FuncName, 'TObject')) then
        ReceiverVarName := FuncName;
      FuncName := NextClassAncestorName(FuncName);
    end;
    if (BaseName <> '') and (not SameText(BaseName, 'TObject')) then
      FuncName := BaseName
    else if ReceiverVarName <> '' then
      FuncName := ReceiverVarName
    else
      FuncName := BaseName;
    if FuncName <> '' then
    begin
      ABlob := 'var self' + #10 +
        'call ' + FuncName + '.' + ArgName + ' 1' + #10;
      Exit(True);
    end;
  end;
  { Bare method/property-getter id (GetNodeKind, no parens): same resolve as
    gnkFunctionCall — LookupProcedureBody first. Record types currently skip
    method children in ParseTypeReference, so FindSymbolByName(Class.Method)
    is often 0 while FProcedureBodies still has TGreenNode.GetNodeKind; symbol-
    only walk residual-calls bare @GetNodeKind(). Skip locals (IsRuntimeVar). }
  if (FCurrentMethodClass <> '') and (ANode.NodeKind = gnkIdentifier) and
    (ANode.Text <> '') and (not IsRuntimeVar(ANode.Text)) then
  begin
    FuncName := FCurrentMethodClass;
    while FuncName <> '' do
    begin
      if LookupProcedureBody(FuncName + '.' + ANode.Text, BranchNode, DeclNode) or
        (FModel.FindSymbolByName(FuncName + '.' + ANode.Text) <> 0) then
        Break;
      FuncName := NextClassAncestorName(FuncName);
    end;
    if FuncName <> '' then
    begin
      Folded := TypeMetaVmtSlot(FCurrentMethodClass, ANode.Text);
      if Folded >= 0 then
      begin
        ABlob := 'var self' + #10 + 'vcall ' + IntToStr(Folded) + ' 0';
        if TypeMetaRetPtr(FCurrentMethodClass, ANode.Text) then
          ABlob := ABlob + ' p' + #10
        else
          ABlob := ABlob + #10;
      end
      else
        ABlob := 'var self' + #10 +
          'call ' + FuncName + '.' + ANode.Text + ' 1' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkDotAccess) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    EncodeRuntimeIntExprFold(ANode.ChildAt(0), FuncName) then
  begin
    if Pos(' p' + #10, FuncName) > 0 then
    begin
      ArgName := '';
      for StrCallIdx := 1 to FModel.SymbolCount do
        if SameText(FModel.SymbolAt(StrCallIdx).Name,
          ANode.ChildAt(0).ChildAt(1).Text) and
          SameText(FModel.SymbolAt(StrCallIdx).Kind, 'field') then
        begin
          if FModel.SymbolAt(StrCallIdx).TypeId > 0 then
            ArgName := FModel.TypeAt(
              FModel.SymbolAt(StrCallIdx).TypeId - 1).Name;
          Break;
        end;
      if ArgName <> '' then
      begin
        Folded := TypeMetaVmtSlot(ArgName, ANode.ChildAt(1).Text);
        if Folded >= 0 then
        begin
          ABlob := FuncName + 'vcall ' + IntToStr(Folded) + ' 0';
          if TypeMetaRetPtr(ArgName, ANode.ChildAt(1).Text) then
            ABlob := ABlob + ' p' + #10
          else
            ABlob := ABlob + #10;
          Exit(True);
        end;
        Folded := TypeMetaFieldIndex(ArgName, ANode.ChildAt(1).Text);
        if Folded >= 0 then
        begin
          ABlob := FuncName + 'int ' + IntToStr(Folded) + #10;
          if TypeMetaFieldIsPtr(ArgName, ANode.ChildAt(1).Text) then
            ABlob := ABlob + 'arr_load_ptr' + #10
          else
            ABlob := ABlob + 'arr_load' + #10;
          Exit(True);
        end;
      end;
    end;
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkArrayAccess) and
    (ANode.ChildAt(0).ChildCount >= 2) and
    (ANode.ChildAt(0).ChildAt(0) <> nil) and
    (ANode.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    IsRuntimeArrVar(ANode.ChildAt(0).ChildAt(0).Text) then
  begin
    FuncName := '';
    if FModel.LookupStringConstValue(
      ANode.ChildAt(0).ChildAt(0).Text + '$arr_elem_type', FuncName) then
    begin end;
    if (FuncName = '') and
      (TypeMetaSize(ANode.ChildAt(0).ChildAt(0).Text) > 0) then
      FuncName := ANode.ChildAt(0).ChildAt(0).Text;
    if FuncName <> '' then
    begin
      Folded := TypeMetaVmtSlot(FuncName, ANode.ChildAt(1).Text);
      if (Folded >= 0) and
        EncodeRuntimeIntExprFold(ANode.ChildAt(0).ChildAt(1), ArgName) then
      begin
        ABlob := ArgName + 'arrload ' + ANode.ChildAt(0).ChildAt(0).Text +
          ' p' + #10 + 'vcall ' + IntToStr(Folded) + ' 0';
        if TypeMetaRetPtr(FuncName, ANode.ChildAt(1).Text) then
          ABlob := ABlob + ' p' + #10
        else
          ABlob := ABlob + #10;
        Exit(True);
      end;
      Folded := TypeMetaFieldIndex(FuncName, ANode.ChildAt(1).Text);
      if (Folded >= 0) and
        EncodeRuntimeIntExprFold(ANode.ChildAt(0).ChildAt(1), ArgName) then
      begin
        ABlob := ArgName + 'arrload ' + ANode.ChildAt(0).ChildAt(0).Text +
          ' p' + #10 + 'int ' + IntToStr(Folded) + #10 + 'arr_load' + #10;
        Exit(True);
      end;
    end;
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkArrayAccess) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    TryClassFieldArrayAccess(ANode.ChildAt(0), BaseName, OwnerClassName,
      FieldName) and
    FModel.LookupStringConstValue(
      OwnerClassName + '.' + FieldName + '$arr_elem_type', ArgName) then
  begin
    Folded := TypeMetaFieldIndex(ArgName, ANode.ChildAt(1).Text);
    if (Folded >= 0) and
      EncodeRuntimeIntExprFold(ANode.ChildAt(0).ChildAt(1), Operand) then
    begin
      StrCallIdx := TypeMetaFieldIndex(OwnerClassName, FieldName);
      if StrCallIdx < 0 then
        Exit(False);
      ABlob := 'field ' + BaseName + ' ' + IntToStr(StrCallIdx) +
        ' p' + #10 + Operand;
      StrCallIdx := 1;
      if TypeMetaIsRecord(ArgName) then
      begin
        StrCallIdx := TypeMetaSize(ArgName) div 8;
        if StrCallIdx <= 0 then
          Exit(False);
      end;
      if StrCallIdx > 1 then
        ABlob := ABlob + 'int ' + IntToStr(StrCallIdx) + #10 + 'mul' + #10;
      ABlob := ABlob + 'int ' + IntToStr(Folded) + #10 + 'add' + #10;
      if TypeMetaFieldIsPtr(ArgName, ANode.ChildAt(1).Text) then
        ABlob := ABlob + 'arr_load_ptr' + #10
      else
        ABlob := ABlob + 'arr_load' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    ReceiverVarName := ANode.ChildAt(0).Text;
    if SameText(ReceiverVarName, 'Self') and (FCurrentMethodClass <> '') then
    begin
      ReceiverVarName := 'self';
      FuncName := FCurrentMethodClass;
    end
    else
      FuncName := LookupClassVar(ReceiverVarName);
    if (FuncName = '') and (FCurrentMethodClass <> '') and
      TypeMetaFieldIsPtr(FCurrentMethodClass, ANode.ChildAt(0).Text) and
      (TypeMetaFieldIndex(FCurrentMethodClass, ANode.ChildAt(0).Text) >= 0) then
    begin
      Folded := TypeMetaFieldIndex(FCurrentMethodClass, ANode.ChildAt(0).Text);
      ArgName := 'field self ' + IntToStr(Folded) + ' p' + #10;
      FuncName := '';
      { Field type comes from the current class's field meta, not the first
        symbol table hit: other classes (text.builder FBuf: PAnsiChar) share
        the field name and hijacked the receiver type. }
      if FModel.GetFieldMetaByName(FModel.FindTypeByName(FCurrentMethodClass),
        ANode.ChildAt(0).Text, FldMeta) and (FldMeta.TypeId > 0) then
        FuncName := FModel.TypeAt(FldMeta.TypeId - 1).Name;
      if FuncName <> '' then
      begin
        Folded := TypeMetaVmtSlot(FuncName, ANode.ChildAt(1).Text);
        if Folded >= 0 then
        begin
          ABlob := ArgName + 'vcall ' + IntToStr(Folded) + ' 0';
          if TypeMetaRetPtr(FuncName, ANode.ChildAt(1).Text) then
            ABlob := ABlob + ' p' + #10
          else
            ABlob := ABlob + #10;
        end
        else if FModel.LookupStringConstValue(
          FuncName + '.' + ANode.ChildAt(1).Text + '$read', Operand) and
          (TypeMetaFieldIndex(FuncName, Operand) >= 0) then
        begin
          { Field-backed property off a ptr field receiver: the receiver ptr is
            already on the stack, so index it instead of calling @Type.FField. }
          ABlob := ArgName +
            'int ' + IntToStr(TypeMetaFieldIndex(FuncName, Operand)) + #10;
          if TypeMetaFieldIsPtr(FuncName, Operand) then
            ABlob := ABlob + 'arr_load_ptr' + #10
          else
            ABlob := ABlob + 'arr_load' + #10;
        end
        else
        begin
          { Class-local alias receiver (TVecBuf = specialize TArray<T>):
            expand via the active generic instance so the callee names a
            real cloned body instead of the template alias. }
          Operand := ResolveClassMethodCalleeName(FuncName,
            ANode.ChildAt(1).Text);
          if Operand = '' then
            Operand := FuncName + '.' + ANode.ChildAt(1).Text;
          ABlob := ArgName +
            'call ' + Operand + ' 1' + #10;
        end;
        Exit(True);
      end;
      FuncName := '';
    end;
    if FuncName <> '' then
    begin
      if FModel.LookupStringConstValue(
        FuncName + '.' + ANode.ChildAt(1).Text + '$read', ArgName) then
      begin
        { A declared read target may be a backing FIELD (property RootNode
          read FRootNode), not a getter — call @Type.FField is undefined. }
        Folded := TypeMetaFieldIndex(FuncName, ArgName);
        if Folded >= 0 then
        begin
          ABlob := 'field ' + ReceiverVarName + ' ' + IntToStr(Folded);
          if TypeMetaFieldIsPtr(FuncName, ArgName) then
            ABlob := ABlob + ' p' + #10
          else
            ABlob := ABlob + #10;
        end
        else
        begin
          { Abstract/virtual getters (TCollection.GetCount virtual abstract)
            have no body — direct call @Type.GetCount is undefined; dispatch
            through the vmt like the no-read branch below (b4b-i8). }
          Folded := TypeMetaVmtSlot(FuncName, ArgName);
          if Folded >= 0 then
          begin
            ABlob := 'var ' + ReceiverVarName + #10 +
              'vcall ' + IntToStr(Folded) + ' 0';
            if TypeMetaRetPtr(FuncName, ArgName) then
              ABlob := ABlob + ' p' + #10
            else
              ABlob := ABlob + #10;
          end
          else
            ABlob := 'var ' + ReceiverVarName + #10 +
              'call ' + FuncName + '.' + ArgName + ' 1' + #10;
        end
      end
      else
      begin
        Folded := TypeMetaFieldIndex(FuncName, ANode.ChildAt(1).Text);
        if Folded >= 0 then
        begin
          ABlob := 'field ' + ReceiverVarName + ' ' + IntToStr(Folded);
          if TypeMetaFieldIsPtr(FuncName, ANode.ChildAt(1).Text) then
            ABlob := ABlob + ' p' + #10
          else
            ABlob := ABlob + #10;
        end
        else
        begin
          Folded := TypeMetaVmtSlot(FuncName, ANode.ChildAt(1).Text);
          if Folded >= 0 then
          begin
            if TypeMetaIsInterface(FuncName) then
              ABlob := 'var ' + ReceiverVarName + #10 +
                'ivcall ' + IntToStr(Folded) + ' 0'
            else
              ABlob := 'var ' + ReceiverVarName + #10 +
                'vcall ' + IntToStr(Folded) + ' 0';
            if TypeMetaRetPtr(FuncName, ANode.ChildAt(1).Text) then
              ABlob := ABlob + ' p' + #10
            else
              ABlob := ABlob + #10;
          end
          else
          begin
            ArgName := FuncName;
            while (ArgName <> '') and
              (FModel.FindSymbolByName(ArgName + '.' + ANode.ChildAt(1).Text) = 0) do
              ArgName := NextClassAncestorName(ArgName);
            if ArgName = '' then ArgName := FuncName;
            ABlob := 'var ' + ReceiverVarName + #10 +
              'call ' + ResolvePropertyReadCallee(ArgName, ANode.ChildAt(1).Text) +
              ' 1' + #10;
          end;
        end;
      end;
      Exit(True);
    end;
  end;
  if TryPointerFieldValueBlob(ANode, ABlob) then
    Exit(True);
  if TryPointerFieldAccess(ANode, FuncName, ArgName, Operand, Folded) then
  begin
    ABlob := 'var ' + FuncName + #10 + 'int ' + IntToStr(Folded) + #10;
    if TypeMetaFieldIsPtr(ArgName, Operand) then
      ABlob := ABlob + 'arr_load_ptr' + #10
    else
      ABlob := ABlob + 'arr_load' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and
    SameText(ANode.Text, 'as') and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(0), ABlob) then
      Exit(True);
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and
    (ANode.ChildCount >= 2) then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(0), FuncName) and
      EncodeRuntimeIntExprFold(ANode.ChildAt(1), ArgName) then
    begin
      { Comparison in value context (IsSep: Result := C = '/'). Char-like
        params/pointers registered as pseudo class vars hold the char slot
        address; load the i8 value before comparing. Char-pointer index
        access (StrLen: S[Result] <> #0) encodes the element address via
        arr_elem_ref (the Char-arg ABI needs the slot), so it needs the
        same value load here; only the three Char pointer kinds are
        affected — numeric pointees (pelem_load) already carry the value. }
      if ANode.ChildAt(0).NodeKind = gnkIdentifier then
      begin
        OwnerClassName := LookupClassVar(ANode.ChildAt(0).Text);
        if (OwnerClassName <> '') and (TypeMetaSize(OwnerClassName) = 1) then
          FuncName := FuncName + 'charval' + #10;
      end
      else if (ANode.ChildAt(0).NodeKind = gnkArrayAccess) and
        (ANode.ChildAt(0).ChildCount >= 2) and
        (ANode.ChildAt(0).ChildAt(0) <> nil) and
        (ANode.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
        ((LookupPointerVar(ANode.ChildAt(0).ChildAt(0).Text) = 'PChar') or
         (LookupPointerVar(ANode.ChildAt(0).ChildAt(0).Text) = 'PAnsiChar') or
         (LookupPointerVar(ANode.ChildAt(0).ChildAt(0).Text) = 'PUTF8Char')) then
        FuncName := FuncName + 'charval' + #10;
      if ANode.ChildAt(1).NodeKind = gnkIdentifier then
      begin
        OwnerClassName := LookupClassVar(ANode.ChildAt(1).Text);
        if (OwnerClassName <> '') and (TypeMetaSize(OwnerClassName) = 1) then
          ArgName := ArgName + 'charval' + #10;
      end
      else if (ANode.ChildAt(1).NodeKind = gnkArrayAccess) and
        (ANode.ChildAt(1).ChildCount >= 2) and
        (ANode.ChildAt(1).ChildAt(0) <> nil) and
        (ANode.ChildAt(1).ChildAt(0).NodeKind = gnkIdentifier) and
        ((LookupPointerVar(ANode.ChildAt(1).ChildAt(0).Text) = 'PChar') or
         (LookupPointerVar(ANode.ChildAt(1).ChildAt(0).Text) = 'PAnsiChar') or
         (LookupPointerVar(ANode.ChildAt(1).ChildAt(0).Text) = 'PUTF8Char')) then
        ArgName := ArgName + 'charval' + #10;
      if ANode.Text = '+' then
        ABlob := FuncName + ArgName + 'add' + #10
      else if ANode.Text = '-' then
        ABlob := FuncName + ArgName + 'sub' + #10
      else if ANode.Text = '*' then
        ABlob := FuncName + ArgName + 'mul' + #10
      else if SameText(ANode.Text, 'div') then
        ABlob := FuncName + ArgName + 'div' + #10
      else if SameText(ANode.Text, 'mod') then
        ABlob := FuncName + ArgName + 'mod' + #10
      else if ANode.Text = '=' then
        ABlob := FuncName + ArgName + 'cmp eq' + #10
      else if ANode.Text = '<>' then
        ABlob := FuncName + ArgName + 'cmp ne' + #10
      else if ANode.Text = '<' then
        ABlob := FuncName + ArgName + 'cmp slt' + #10
      else if ANode.Text = '<=' then
        ABlob := FuncName + ArgName + 'cmp sle' + #10
      else if ANode.Text = '>' then
        ABlob := FuncName + ArgName + 'cmp sgt' + #10
      else if ANode.Text = '>=' then
        ABlob := FuncName + ArgName + 'cmp sge' + #10
      else
      begin
        Result := EncodeRuntimeIntExpr(ANode, ABlob, FCurrentRetVarName);
        Exit;
      end;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkUnaryExpression) and
    (ANode.ChildCount >= 1) and (ANode.Text = '-') then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(0), FuncName) then
    begin
      ABlob := FuncName + 'neg' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkUnaryExpression) and
    (ANode.ChildCount >= 1) and (ANode.Text = '@') then
  begin
    if TryPointerFieldAccess(ANode.ChildAt(0), FuncName, ArgName, Operand,
      Folded) then
    begin
      ABlob := 'var ' + FuncName + #10 + 'field_ref ' +
        IntToStr(Folded) + #10;
      Exit(True);
    end;
    { @Result — ret slot is seeded as FCurrentRetVarName, not bare "Result".
      Without this, encode falls to funcref → residual global @Result. }
    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
      SameText(ANode.ChildAt(0).Text, 'Result') and
      (FCurrentRetVarName <> '') then
    begin
      ABlob := 'varref ' + FCurrentRetVarName + #10;
      Exit(True);
    end;
    { @StaticArray / open-array: storage lives at Name$ptr, not bare Name.
      varref Name misses FindAlloca → empty stack; funcref → residual @Name. }
    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
      (ANode.ChildAt(0).Text <> '') and
      IsRuntimeArrVar(ANode.ChildAt(0).Text) then
    begin
      ABlob := 'var ' + ANode.ChildAt(0).Text + '$ptr' + #10;
      Exit(True);
    end;
    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
      IsRuntimeVar(ANode.ChildAt(0).Text) then
    begin
      ABlob := 'varref ' + ANode.ChildAt(0).Text + #10;
      Exit(True);
    end;
    { @UnitGlobal / @threadvar — SeedFunctionBodies does FRuntimeVars.Reset per
      body, so unit-level IsRuntimeVar is gone. Symbols stay Kind=variable
      (ProcessVarSection). Prefer varref → EmitExprVarRef → @g_Name, else
      funcref residual bare @GThreadCache (opt first after threadvar emit). }
    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
      (ANode.ChildAt(0).Text <> '') then
    begin
      StrCallIdx := FindSymbolByName(ANode.ChildAt(0).Text);
      if (StrCallIdx > 0) and
        SameText(FModel.SymbolAt(StrCallIdx - 1).Kind, 'variable') then
      begin
        ABlob := 'varref ' + ANode.ChildAt(0).Text + #10;
        Exit(True);
      end;
    end;
    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkArrayAccess) and
      (ANode.ChildAt(0).ChildCount >= 2) and
      (ANode.ChildAt(0).ChildAt(0) <> nil) and
      (ANode.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
      IsRuntimeArrVar(ANode.ChildAt(0).ChildAt(0).Text) and
      EncodeRuntimeIntExprFold(ANode.ChildAt(0).ChildAt(1), FuncName) then
    begin
      ABlob := FuncName + 'arr_elem_ref ' +
        ANode.ChildAt(0).ChildAt(0).Text + #10;
      Exit(True);
    end;
    { @FGen / @Self.FGen — method field address is GEP(self, idx), not global
      @FGen (platform_wait/wake_address need the instance field slot). }
    if (FCurrentMethodClass <> '') and (ANode.ChildAt(0) <> nil) then
    begin
      if (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
        (TypeMetaFieldIndex(FCurrentMethodClass, ANode.ChildAt(0).Text) >= 0) then
      begin
        Folded := TypeMetaFieldIndex(FCurrentMethodClass, ANode.ChildAt(0).Text);
        ABlob := 'var self' + #10 + 'field_ref ' + IntToStr(Folded) + #10;
        Exit(True);
      end;
      if (ANode.ChildAt(0).NodeKind = gnkDotAccess) and
        (ANode.ChildAt(0).ChildCount >= 2) and
        (ANode.ChildAt(0).ChildAt(0) <> nil) and
        (ANode.ChildAt(0).ChildAt(1) <> nil) and
        (ANode.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
        (ANode.ChildAt(0).ChildAt(1).NodeKind = gnkIdentifier) and
        (SameText(ANode.ChildAt(0).ChildAt(0).Text, 'Self') or
          SameText(ANode.ChildAt(0).ChildAt(0).Text, 'self')) and
        (TypeMetaFieldIndex(FCurrentMethodClass,
          ANode.ChildAt(0).ChildAt(1).Text) >= 0) then
      begin
        Folded := TypeMetaFieldIndex(FCurrentMethodClass,
          ANode.ChildAt(0).ChildAt(1).Text);
        ABlob := 'var self' + #10 + 'field_ref ' + IntToStr(Folded) + #10;
        Exit(True);
      end;
    end;
    { @FreeFunction — procedural/function pointer value (not residual call). }
    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
      (ANode.ChildAt(0).Text <> '') and
      (not IsRuntimeVar(ANode.ChildAt(0).Text)) and
      (not IsRuntimeArrVar(ANode.ChildAt(0).Text)) then
    begin
      ABlob := 'funcref ' + ANode.ChildAt(0).Text + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkDereference) and (ANode.ChildCount >= 1) then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(0), FuncName) then
    begin
      ABlob := FuncName + 'deref' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkIdentifier) and (ANode.Text = 'Result') and
    (FCurrentRetVarName <> '') then
  begin
    ABlob := 'var ' + FCurrentRetVarName + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and (ANode.Text <> '') and
    IsRecordVar(ANode.Text) then
  begin
    ABlob := 'recvar ' + ANode.Text + #10;
    Exit(True);
  end;
  { Open-array / array-of-const formals live as Name$ptr + Name$len only.
    Bare `var Name` residual-calls @Name(); pass as arrvar (ptr,len) ABI. }
  if (ANode.NodeKind = gnkIdentifier) and (ANode.Text <> '') and
    IsRuntimeArrVar(ANode.Text) then
  begin
    ABlob := 'arrvar ' + ANode.Text + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkArrayAccess) and
    (ANode.ChildAt(0).ChildCount >= 2) and
    (ANode.ChildAt(0).ChildAt(0) <> nil) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    IsRuntimeArrVar(ANode.ChildAt(0).ChildAt(0).Text) and
    FModel.LookupStringConstValue(
      ANode.ChildAt(0).ChildAt(0).Text + '$arr_elem_type', FuncName) then
  begin
    Folded := TypeMetaFieldIndex(FuncName, ANode.ChildAt(1).Text);
    if Folded >= 0 then
    begin
      StrCallIdx := LongInt(Folded);
      if FModel.LookupConstValue(
        ANode.ChildAt(0).ChildAt(0).Text + '$arr_elem_size', Folded) and
        EncodeRuntimeIntExprFold(ANode.ChildAt(0).ChildAt(1), ArgName) then
      begin
        ABlob := 'var ' + ANode.ChildAt(0).ChildAt(0).Text + '$ptr' + #10 +
          ArgName + 'int ' + IntToStr(Folded div 8) + #10 + 'mul' + #10 +
          'int ' + IntToStr(StrCallIdx) + #10 + 'add' + #10 + 'arr_load' + #10;
        Exit(True);
      end;
    end;
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    IsRecordVar(ANode.ChildAt(0).Text) then
  begin
    FuncName := LookupRecordVar(ANode.ChildAt(0).Text);
    Folded := -1;
    if FuncName <> '' then
      Folded := TypeMetaFieldIndex(FuncName, ANode.ChildAt(1).Text);
    if Folded >= 0 then
    begin
      ABlob := 'rload ' + ANode.ChildAt(0).Text + ' ' +
        IntToStr(Folded) + #10;
      Exit(True);
    end;
    { Record properties are absent from type meta, so falling through here
      residual-calls @Type.Member. Field-backed props still resolve via the
      declared read target. }
    if (FuncName <> '') and FModel.LookupStringConstValue(
      FuncName + '.' + ANode.ChildAt(1).Text + '$read', ArgName) and
      (ArgName <> '') then
    begin
      Folded := TypeMetaFieldIndex(FuncName, ArgName);
      if Folded >= 0 then
      begin
        ABlob := 'rload ' + ANode.ChildAt(0).Text + ' ' +
          IntToStr(Folded) + #10;
        Exit(True);
      end;
    end;
  end;
  if (ANode.NodeKind = gnkArrayAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    ((LookupPointerVar(ANode.ChildAt(0).Text) = 'PChar') or
     (LookupPointerVar(ANode.ChildAt(0).Text) = 'PAnsiChar') or
     (LookupPointerVar(ANode.ChildAt(0).Text) = 'PUTF8Char')) then
  begin
    { Character pointer index: element address (Char formals are passed as
      ptr to the character slot — IsSep(APath[Result-1])). The generic
      arrload fallback needs Name$ptr, which pointer params lack, so it drops
      the base and the residual call gets only the index (M2: @Result 1 use).
      Restricted to char pointers: numeric pointees (PInt32 etc.) take the
      element as a value, not a Char-slot address. }
    if EncodeRuntimeIntExprFold(ANode.ChildAt(1), FuncName) then
    begin
      ABlob := FuncName + 'arr_elem_ref ' + ANode.ChildAt(0).Text + #10;
      Exit(True);
    end;
  end;
  { Numeric pointee index (aSrc[i] of PInt32): element VALUE via gep scaled
    by pointee size + load. Char pointers above stay address-only; the
    generic arrload fallback needs Name$ptr, which pointer params lack, so it
    used to drop the base and the residual call kept only the index (aSrc[i]
    of ScalarArrayShrI32 → SarLongint's first arg degraded to i). }
  if (ANode.NodeKind = gnkArrayAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (LookupPointerVar(ANode.ChildAt(0).Text) <> '') and
    (not ((LookupPointerVar(ANode.ChildAt(0).Text) = 'PChar') or
          (LookupPointerVar(ANode.ChildAt(0).Text) = 'PAnsiChar') or
          (LookupPointerVar(ANode.ChildAt(0).Text) = 'PUTF8Char'))) and
    EncodeRuntimeIntExprFold(ANode.ChildAt(1), FuncName) then
  begin
    Folded := PointeeElemSizeCode(LookupPointerVar(ANode.ChildAt(0).Text));
    if Folded > 1 then
    begin
      ABlob := FuncName + 'pelem_load ' + ANode.ChildAt(0).Text + ' ' +
        IntToStr(Folded) + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkArrayAccess) and (ANode.ChildCount >= 2) and
    TryClassFieldArrayAccess(ANode, BaseName, OwnerClassName, FieldName) then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(1), FuncName) then
    begin
      Folded := TypeMetaFieldIndex(OwnerClassName, FieldName);
      ABlob := 'field ' + BaseName + ' ' + IntToStr(Folded) + ' p' + #10 +
        FuncName + 'arr_load' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkArrayAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    IsRuntimeStrVar(ANode.ChildAt(0).Text) then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(1), FuncName) then
    begin
      ABlob := FuncName + 'strcharload ' + ANode.ChildAt(0).Text + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkArrayAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    IsRuntimeArrVar(ANode.ChildAt(0).Text) then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(1), FuncName) then
    begin
      ABlob := FuncName + 'arrload ' + ANode.ChildAt(0).Text + #10;
      Exit(True);
    end;
  end;
  { Interface type name as a value argument (Supports(Obj, IIntf, Out)):
    FPC materializes the interface GUID here; the bare-var residual would
    become an undefined `call @IIntfName()` in the emitter. Encode a stable
    interface id (type symbol index) instead — full TGuid materialization
    is deferred with TObject.GetInterface (M2 B5f). }
  if (ANode.NodeKind = gnkIdentifier) and (ANode.Text <> '') and
    (not IsRuntimeVar(ANode.Text)) and TypeMetaIsInterface(ANode.Text) then
  begin
    ABlob := 'int ' + IntToStr(FModel.FindTypeByName(ANode.Text)) + #10;
    Exit(True);
  end;
  Result := EncodeRuntimeIntExpr(ANode, ABlob, FCurrentRetVarName);
end;

