{$I np_hir_builder_vcall.inc}

function THIRBuilder.ParseIntExprArg(const AExprArg: string): THIRValueId;
var
  TypeId: THIRTypeId;
begin
  Result := ParseIntExprArgTyped(AExprArg, TypeId);
end;

function THIRBuilder.ParseIntExprArgTyped(const AExprArg: string;
  out ATypeId: THIRTypeId): THIRValueId;
var
  S: TExprStack;
  Lines: array of string;
  LineCount, I, SpacePos: LongInt;
  Line, Token, Arg: string;
  V: THIRValueId;
  Instr: THIRInstr;
  ExprId: LongInt;
  ExprResult: THIRExprResult;
  OperandType: THIRTypeId;
begin
  Result := 0;
  ATypeId := 0;
  S.Init;

  SetLength(Lines, 0);
  LineCount := 0;
  Line := '';
  for I := 1 to Length(AExprArg) do
  begin
    if AExprArg[I] = #10 then
    begin
      if Line <> '' then
      begin
        if LineCount >= Length(Lines) then
          SetLength(Lines, LineCount + 16);
        Lines[LineCount] := Line;
        Inc(LineCount);
      end;
      Line := '';
    end
    else
      Line := Line + AExprArg[I];
  end;
  if Line <> '' then
  begin
    if LineCount >= Length(Lines) then
      SetLength(Lines, LineCount + 16);
    Lines[LineCount] := Line;
    Inc(LineCount);
  end;

  for I := 0 to LineCount - 1 do
  begin
    Line := Lines[I];
    
    { 检查是否是结构化表达式 }
    if Copy(Line, 1, 5) = 'expr ' then
    begin
      { 提取 ExprId }
      ExprId := StrToIntDef(Copy(Line, 6, Length(Line)), 0);
      if ExprId > 0 then
      begin
        { 调用 LowerExpr 处理结构化表达式 }
        if LowerExpr(ExprId, ExprResult) then
        begin
          Result := ExprResult.ValueId;
          ATypeId := ExprResult.TypeId;
          Exit;
        end;
      end;
      { 如果 LowerExpr 失败，继续处理下一行 }
      Continue;
    end;

    Line := Lines[I];
    SpacePos := Pos(' ', Line);
    if SpacePos > 0 then
    begin
      Token := Copy(Line, 1, SpacePos - 1);
      Arg := Copy(Line, SpacePos + 1, Length(Line));
    end
    else
    begin
      Token := Line;
      Arg := '';
    end;

    if Token = 'int' then EmitExprInt(S, Arg)
    else if Token = 'null' then EmitExprNull(S)
    else if Token = 'assigned' then
    begin
      V := FindAlloca(Arg);
      if V <> 0 then
      begin
        V := EmitLoad(GetPtrType, V);
        S.Push(EmitCmpOp(hikCmpNe, GetBoolType, V, EmitNullPtrValue,
          GetPtrType, GetPtrType));
      end
      else
        S.Push(EmitConstIntOfType(0, GetBoolType));
    end
    else if Token = 'exc_load' then
    begin
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'exc_load';
      EmitInstr(Instr);
      S.PushTyped(Instr.ResultId, GetPtrType);
    end
    else if Token = 'strvar' then EmitExprStrVar(S, Arg)
    else if Token = 'strlit' then EmitExprStrLit(S, Arg)
    else if Token = 'var' then EmitExprVar(S, Arg)
    else if Token = 'varref' then EmitExprVarRef(S, Arg)
    else if Token = 'deref' then
    begin
      V := S.PopTyped(OperandType);
      if OperandType <> 0 then
        S.PushTyped(EmitLoad(OperandType, V), OperandType)
      else
        S.Push(EmitLoad(GetIntType, V));
    end
    else if Token = 'recvar' then EmitExprRecVar(S, Arg)
    else if Token = 'is' then EmitExprIs(S, Arg)
    else if Token = 'arr_load' then EmitExprArrLoad(S)
    else if Token = 'arr_load_ptr' then EmitExprArrLoadPtr(S)
    else if Token = 'arr_elem_ref' then EmitExprArrElemRef(S, Arg)
    else if Token = 'field_ref' then EmitExprFieldRef(S, Arg)
    else if Token = 'rload' then EmitExprRLoad(S, Arg)
    else if Token = 'add' then EmitExprBinOp(S, hikAdd)
    else if Token = 'sub' then EmitExprBinOp(S, hikSub)
    else if Token = 'mul' then EmitExprBinOp(S, hikMul)
    else if Token = 'div' then EmitExprBinOp(S, hikDiv)
    else if Token = 'mod' then EmitExprBinOp(S, hikMod)
    else if Token = 'neg' then EmitExprUnaryOp(S, hikNeg, '')
    else if Token = 'abs' then EmitExprUnaryOp(S, hikIntrinsic, 'abs')
    else if Token = 'cmp' then EmitExprCmp(S, Arg)
    else if Token = 'strcmp' then EmitExprStrCmp(S, Arg)
    else if Token = 'zext' then EmitExprZext(S)
    else if Token = 'call' then EmitExprCall(S, Arg)
    else if Token = 'arrvar' then
    begin
      V := FindAlloca(Arg + '$ptr');
      if V <> 0 then
        S.PushTyped(EmitLoad(GetPtrType, V), GetPtrType)
      else
      begin
        EnsureAlloca(Arg + '$ptr', GetPtrType);
        V := FindAlloca(Arg + '$ptr');
        if V <> 0 then
          S.PushTyped(EmitLoad(GetPtrType, V), GetPtrType);
      end;
      V := FindAlloca(Arg + '$len');
      if V <> 0 then
        S.Push(EmitLoad(GetIntTypeByWidth(32, True), V))
      else
      begin
        EnsureAlloca(Arg + '$len', GetIntTypeByWidth(32, True));
        V := FindAlloca(Arg + '$len');
        if V <> 0 then
          S.Push(EmitLoad(GetIntTypeByWidth(32, True), V));
      end;
    end
    else if Token = 'arrload' then EmitExprArrLoadVar(S, Arg)
    else if Token = 'field' then EmitExprField(S, Arg)
    else if Token = 'vcall' then EmitExprVcall(S, Arg)
    else if Token = 'ivcall' then EmitExprIvcall(S, Arg);
  end;

  if S.Count > 0 then
    Result := S.PopTyped(ATypeId);
end;

procedure THIRBuilder.ProcessVarDecl(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  ParamIdx: LongInt;
  ParamValueId: THIRValueId;
  Arg: string;
  TabPos, Code: LongInt;
  DeclType: THIRTypeId;
  ArrName: string;
  IsStaticArray: Boolean;
  ArrLow, ArrHigh, ArrLength: Int64;
begin
  if ANode.NodeKind = hnkVarDeclRuntime then
  begin
    DeclType := SemanticTypeIdToHirTypeId(ANode.TypeId);
    if DeclType = 0 then
      DeclType := GetIntType;
    if FPendingParamCount > 0 then
    begin
      ParamIdx := FPendingParamLlvmIdx;
      ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].ValueId;

      if FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].TypeId = GetPtrType then
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikAlloca;
        Instr.TypeId := GetPtrType;
        EmitInstr(Instr);

        RegisterAllocaEntry(ANode.Operand, Instr.ResultId, GetPtrType, False);

        EmitStore(GetPtrType, ParamValueId, Instr.ResultId);
      end
      else
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikAlloca;
        Instr.TypeId := DeclType;
        EmitInstr(Instr);

        RegisterAllocaEntry(ANode.Operand, Instr.ResultId, DeclType, False);

        EmitStore(DeclType, ParamValueId, Instr.ResultId);
      end;
      Dec(FPendingParamCount);
      Inc(FPendingParamLlvmIdx);
    end
    else if FInStartFunc then
    begin
      if FGlobalCount >= Length(FGlobalNames) then
      begin
        SetLength(FGlobalNames, FGlobalCount + 32);
        SetLength(FGlobalTypes, FGlobalCount + 32);
      end;
      FGlobalNames[FGlobalCount] := ANode.Operand;
      FGlobalTypes[FGlobalCount] := DeclType;
      Inc(FGlobalCount);
      FModule.AddGlobal(ANode.Operand, DeclType, ANode.IsThreadVar);
    end
    else
      EnsureAlloca(ANode.Operand, DeclType);
  end
  else if (ANode.NodeKind = hnkVarDeclArrRuntime) or
    (ANode.NodeKind = hnkVarDeclArrBorrowedRuntime) then
  begin
    if not ParseArrayDeclOperand(ANode.Operand, ArrName, IsStaticArray,
      ArrLow, ArrHigh, ArrLength) then
      ArrName := ANode.Operand;
    if FInStartFunc then
    begin
      if FGlobalCount >= Length(FGlobalNames) then
      begin
        SetLength(FGlobalNames, FGlobalCount + 32);
        SetLength(FGlobalTypes, FGlobalCount + 32);
      end;
      FGlobalNames[FGlobalCount] := ArrName + '$ptr';
      FGlobalTypes[FGlobalCount] := GetPtrType;
      Inc(FGlobalCount);
      FModule.AddGlobal(ArrName + '$ptr', GetPtrType);
      if FGlobalCount >= Length(FGlobalNames) then
      begin
        SetLength(FGlobalNames, FGlobalCount + 32);
        SetLength(FGlobalTypes, FGlobalCount + 32);
      end;
      FGlobalNames[FGlobalCount] := ArrName + '$len';
      FGlobalTypes[FGlobalCount] := GetIntTypeByWidth(32, True);
      Inc(FGlobalCount);
      FModule.AddGlobal(ArrName + '$len', GetIntTypeByWidth(32, True));
      if IsStaticArray then
        EmitStaticArrayBacking(ArrName, ArrLength);
    end
    else
    begin
      if FPendingParamCount > 0 then
      begin
        ParamIdx := FPendingParamLlvmIdx;
        ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].ValueId;
        EnsureAlloca(ArrName + '$ptr', GetPtrType);
        EmitStore(GetPtrType, ParamValueId, FindAlloca(ArrName + '$ptr'));
        Inc(FPendingParamLlvmIdx);
        ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[FPendingParamLlvmIdx].ValueId;
        EnsureAlloca(ArrName + '$len', GetIntTypeByWidth(32, True));
        EmitStore(GetIntTypeByWidth(32, True), ParamValueId, FindAlloca(ArrName + '$len'));
        Dec(FPendingParamCount);
        Inc(FPendingParamLlvmIdx);
      end
      else
      begin
        EnsureAlloca(ArrName + '$ptr', GetPtrType);
        EnsureAlloca(ArrName + '$len', GetIntTypeByWidth(32, True));
        if IsStaticArray then
          EmitStaticArrayBacking(ArrName, ArrLength);
        if (ANode.NodeKind = hnkVarDeclArrRuntime) and (not IsStaticArray) then
          InitializeDynArraySlots(ArrName);
      end;
    end;
  end
  else if ANode.NodeKind = hnkVarDeclPtrRuntime then
  begin
    if FPendingParamCount > 0 then
    begin
      ParamIdx := FPendingParamLlvmIdx;
      ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].ValueId;

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikAlloca;
      Instr.TypeId := GetPtrType;
      EmitInstr(Instr);

      RegisterAllocaEntry(ANode.Operand, Instr.ResultId, GetPtrType, False);

      EmitStore(GetPtrType, ParamValueId, Instr.ResultId);
      Dec(FPendingParamCount);
      Inc(FPendingParamLlvmIdx);
    end
    else if FSretValueId <> 0 then
    begin
      RegisterAllocaEntry(ANode.Operand, FSretValueId, GetIntType, False);
      FSretValueId := 0;
    end
    else
      EnsureAlloca(ANode.Operand, GetPtrType);
  end
  else if ANode.NodeKind = hnkVarDeclVarrefRuntime then
  begin
    if FPendingParamCount > 0 then
    begin
      ParamIdx := FPendingParamLlvmIdx;
      ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[ParamIdx].ValueId;

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikAlloca;
      Instr.TypeId := GetPtrType;
      EmitInstr(Instr);

      RegisterAllocaEntry(ANode.Operand, Instr.ResultId, GetPtrType, True);

      EmitStore(GetPtrType, ParamValueId, Instr.ResultId);
      Dec(FPendingParamCount);
      Inc(FPendingParamLlvmIdx);
    end
    else
      EnsureAlloca(ANode.Operand, GetPtrType);
  end
  else if ANode.NodeKind = hnkVarDeclRecordRuntime then
  begin
    TabPos := Pos(#9, ANode.Operand);
    if TabPos > 0 then
    begin
      Arg := Copy(ANode.Operand, 1, TabPos - 1);
      Val(Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand)), ParamIdx, Code);
      if Code = 0 then
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikAlloca;
        Instr.TypeId := GetIntType;
        Instr.IntrinsicName := 'record:' + IntToStr(ParamIdx);
        EmitInstr(Instr);

        RegisterAllocaEntry(Arg, Instr.ResultId, GetIntType, False);
        FAllocas[FAllocaCount - 1].RecordSlots := ParamIdx;
      end;
    end;
  end;
end;

procedure THIRBuilder.ProcessAssign(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, Blob, RealName: string;
  V, Addr, PtrVal: THIRValueId;
  StoreType, ValueType: THIRTypeId;
  LSymId: LongInt;
  LTypeId: THIRTypeId;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Blob := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  V := LowerNodeExprOrBlobTyped(ANode, Blob, ValueType);

  if (Length(VarName) > 1) and (VarName[1] = '*') then
  begin
    RealName := Copy(VarName, 2, Length(VarName));
    Addr := FindAlloca(RealName);
    if (V <> 0) and (Addr <> 0) then
    begin
      PtrVal := EmitLoad(GetPtrType, Addr);
      if ValueType = 0 then
        ValueType := GetIntType;
      EmitStore(ValueType, V, PtrVal);
    end;
    Exit;
  end;

  Addr := FindAlloca(VarName);
  if Addr = 0 then
  begin
    { 尝试从语义模型获取变量类型 }
    LSymId := FSemaModel.FindSymbolByName(VarName);
    if LSymId > 0 then
    begin
      LTypeId := SemanticTypeIdToHirTypeId(FSemaModel.SymbolAt(LSymId - 1).TypeId);
      if LTypeId <> 0 then
        EnsureAlloca(VarName, LTypeId)
      else
        EnsureAlloca(VarName, GetIntType);
    end
    else
      EnsureAlloca(VarName, GetIntType);
    Addr := FindAlloca(VarName);
  end;
  if (V <> 0) and (Addr <> 0) then
  begin
    if IsVarParamAlloca(VarName) then
    begin
      Addr := EmitLoad(GetPtrType, Addr);
      if ValueType = 0 then
        ValueType := GetIntType;
      EmitStore(ValueType, V, Addr);
    end
    else
    begin
      StoreType := FindAllocaType(VarName);
      if StoreType = 0 then
        StoreType := GetIntType;
      if ValueType <> 0 then
      begin
        V := NormalizeScalarValueToType(V, ValueType, StoreType);
        if V = 0 then
          V := ParseIntExprArg(Blob);
      end;
      if V <> 0 then
        EmitStore(StoreType, V, Addr);
    end;
  end;
end;

{$I np_hir_builder_ctrlflow.inc}

{$I np_hir_builder_funclifecycle.inc}

{$I np_hir_builder_runtime.inc}

{$I np_hir_builder_write_string.inc}

{$I np_hir_builder_cleanup.inc}

{$I np_hir_builder_object.inc}

procedure THIRBuilder.ProcessNode(const ANode: TTypedHirNode);
begin
  if (FPendingObjectFreeDestroyName <> '') and
    (ANode.NodeKind <> hnkCallRuntime) and
    (ANode.NodeKind <> hnkObjectFreeRuntime) then
  begin
    FPendingObjectFreeDestroyName := '';
    FPendingObjectFreeReceiverName := '';
    FPendingObjectFreeReceiverValue := 0;
    FPendingObjectFreeCleanupClass := '';
    FPendingObjectFreeHeapRelease := False;
  end;

  if (FPendingCleanupCount > 0) and
    (ANode.NodeKind <> hnkDynArrayCleanupRuntime) and
    (ANode.NodeKind <> hnkTStringCleanupRuntime) and
    (ANode.NodeKind <> hnkHaltCallRuntime) and
    (ANode.NodeKind <> hnkHaltCall) and
    (ANode.NodeKind <> hnkRetRuntime) and
    (ANode.NodeKind <> hnkRetTStringRuntime) then
    FlushPendingCleanupNodes;

  { Set current source position from node's symbol for debug info }
  SetCurrentSourcePosFromSymbol(ANode.SymbolId);

  case ANode.NodeKind of
    hnkVarDeclRuntime, hnkVarDeclArrRuntime,
    hnkVarDeclArrBorrowedRuntime, hnkVarDeclPtrRuntime,
    hnkVarDeclVarrefRuntime, hnkVarDeclRecordRuntime:
      ProcessVarDecl(ANode);
    hnkVarDeclTStringRuntime:
      ProcessVarDeclTString(ANode);
    hnkAssignTStringLiteralRuntime:
      ProcessAssignTStringLiteral(ANode);
    hnkAssignTStringCopyRuntime:
      ProcessAssignTStringCopy(ANode);
    hnkAssignTStringCallRuntime:
      ProcessAssignTStringCall(ANode);
    hnkAssignTStringConcatRuntime:
      ProcessAssignTStringConcat(ANode);
    hnkAssignTStringFieldLoadRuntime:
      ProcessAssignTStringFieldLoad(ANode);
    hnkFieldStoreTStringRuntime:
      ProcessFieldStoreTString(ANode);
    hnkAssignRuntime:
      ProcessAssign(ANode);
    hnkHaltCallRuntime:
      ProcessHaltCall(ANode);
    hnkHaltCall:
      ProcessHaltCallConst(ANode);
    hnkCondBrRuntime:
      ProcessCondBr(ANode);
    hnkSwitchRuntime:
      ProcessSwitch(ANode);
    hnkBrRuntime:
      ProcessBr(ANode);
    hnkBlockLabelRuntime:
      ProcessBlockLabel(ANode);
    hnkFunctionBodyBegin:
      ProcessFunctionBegin(ANode);
    hnkFunctionBodyEnd:
      ProcessFunctionEnd(ANode);
    hnkProcedureDecl, hnkFunctionDecl:
      ProcessExternalDecl(ANode);
    hnkRetRuntime:
      ProcessRetRuntime(ANode);
    hnkRetTStringRuntime:
      ProcessRetTString(ANode);
    hnkCallRuntime:
      ProcessCallRuntime(ANode);
    hnkStringTempOwnedRuntime:
      ProcessStringTempOwnedRuntime(ANode);
    hnkStringTempBorrowArgRuntime:
      ProcessStringTempBorrowArgRuntime(ANode);
    hnkStringTempLengthRuntime:
      ProcessStringTempLengthRuntime(ANode);
    hnkStringTempReleaseRuntime:
      ProcessStringTempReleaseRuntime(ANode);
    hnkObjectFreeRuntime:
      ProcessObjectFreeRuntime(ANode);
    hnkTStringFromIntRuntime:
      ProcessIntToStr(ANode);
    hnkTStringCopyRuntime:
      ProcessCopyStr(ANode);
    hnkWriteIntRuntime:
      ProcessWriteInt(ANode);
    hnkWriteStringRuntime:
      ProcessWriteString(ANode);
    hnkWriteCall:
      ProcessWriteCall(ANode);
    hnkWriteStrVarRuntime:
      ProcessWriteStrVar(ANode);
    hnkSetLengthArrRuntime:
      ProcessSetLengthArr(ANode);
    hnkSetLengthFieldArrRuntime:
      ProcessSetLengthFieldArr(ANode);
    hnkDynArrayCleanupRuntime:
      QueueCleanupNode(ANode);
    hnkTStringCleanupRuntime:
      QueueCleanupNode(ANode);
    hnkManagedRecordCleanupRuntime:
      QueueCleanupNode(ANode);
    hnkAssignArrElemRuntime:
      ProcessAssignArrElem(ANode);
    hnkMethodBodyBegin:
      ProcessMethodBegin(ANode);
    hnkClassNewRuntime:
      ProcessClassNew(ANode);
    hnkFieldStoreRuntime:
      ProcessFieldStore(ANode);
    hnkRecordFieldStoreRuntime:
      ProcessRecordFieldStore(ANode);
    hnkRecordCopyRuntime:
      ProcessRecordCopy(ANode);
    hnkVmtStoreRuntime:
      ProcessVmtStore(ANode);
    hnkIntfAdjustRuntime:
      ProcessIntfAdjust(ANode);
    hnkIntfAddRefRuntime:
      ProcessIntfAddRef(ANode);
    hnkIntfReleaseRuntime:
      ProcessIntfRelease(ANode);
    hnkTryBeginRuntime, hnkTryEndRuntime,
    hnkFinallyBeginRuntime, hnkFinallyEndRuntime,
    hnkExceptBeginRuntime, hnkExceptEndRuntime,
    hnkRaiseRuntime:
      ProcessExceptionNode(ANode);
    hnkProcessInitRuntime:
      EmitProcessInit;
    hnkProcessFiniRuntime:
      EmitProcessFini;
    hnkUnitInitRuntime:
      ;  // handled by SeedUnitLifecycleBodies → function-body-begin
    hnkUnitFiniRuntime:
      ;  // handled by SeedUnitLifecycleBodies → function-body-begin
    hnkFillCharRuntime:
      ProcessFillCharRuntime(ANode);
    hnkMoveRuntime:
      ProcessMoveRuntime(ANode);
    hnkInterlockedCasRuntime, hnkInterlockedXchgRuntime,
    hnkInterlockedFetchAddRuntime, hnkInterlockedCas64Runtime,
    hnkInterlockedFetchAdd64Runtime:
      ProcessInterlockedOp(ANode);
    hnkGetMemRuntime:
      ProcessGetMemRuntime(ANode);
    hnkFreeMemRuntime:
      ProcessFreeMemRuntime(ANode);
    hnkAssignedRuntime:
      ProcessAssignedRuntime(ANode);
    hnkUnknown:
      ;
  end;
end;

procedure THIRBuilder.QueueCleanupNode(const ANode: TTypedHirNode);
begin
  if FPendingCleanupCount >= Length(FPendingCleanupNodes) then
    SetLength(FPendingCleanupNodes, FPendingCleanupCount + 8);
  FPendingCleanupNodes[FPendingCleanupCount] := ANode;
  Inc(FPendingCleanupCount);
end;

procedure THIRBuilder.FlushPendingCleanupNodes;
var
  I: LongInt;
  Node: TTypedHirNode;
begin
  for I := 0 to FPendingCleanupCount - 1 do
  begin
    Node := FPendingCleanupNodes[I];
    case Node.NodeKind of
      hnkDynArrayCleanupRuntime:
        ProcessDynArrayCleanup(Node);
      hnkTStringCleanupRuntime:
        EmitTStringFini(FindAlloca(Node.Operand + '$ts'));
      hnkManagedRecordCleanupRuntime:
        ProcessManagedRecordCleanup(Node);
    end;
  end;
  FPendingCleanupCount := 0;
end;

procedure THIRBuilder.EmitProcessInit;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikCall;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.CallTarget := 'np_process_init';
  EmitInstr(Instr);
end;

procedure THIRBuilder.EmitProcessFini;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikCall;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.CallTarget := 'np_process_fini';
  EmitInstr(Instr);
end;

procedure THIRBuilder.Build;
var
  I: LongInt;
  Node: TTypedHirNode;
  EntryBlock: THIRBlockId;
  Instr: THIRInstr;
  FwdName, FwdRest: string;
  FwdColon, FwdColon2: LongInt;
  LOrder: array of string;
begin
  FFwdFuncCount := 0;
  for I := 0 to FSemaModel.TypedHirNodeCount - 1 do
  begin
    Node := FSemaModel.TypedHirNodeAt(I);
    if (Node.Kind = 'function-body-begin') or
       (Node.Kind = 'method-body-begin') then
    begin
      FwdName := Node.DisplayName;
      FwdRest := '';
      FwdColon := Pos(':', Node.Operand);
      if FwdColon > 0 then
      begin
        FwdRest := Copy(Node.Operand, FwdColon + 1, Length(Node.Operand));
        FwdColon2 := Pos(':', FwdRest);
        if FwdColon2 > 0 then
          FwdRest := Copy(FwdRest, FwdColon2 + 1, Length(FwdRest))
        else
          FwdRest := '';
      end;
      if FFwdFuncCount >= Length(FFwdFuncNames) then
      begin
        SetLength(FFwdFuncNames, FFwdFuncCount + 32);
        SetLength(FFwdFuncRetTypes, FFwdFuncCount + 32);
      end;
      FFwdFuncNames[FFwdFuncCount] := FwdName;
      if FwdRest = 'p' then
        FFwdFuncRetTypes[FFwdFuncCount] := GetPtrType
      else if (FwdRest = 's') or (FwdRest = 'so') then
        FFwdFuncRetTypes[FFwdFuncCount] := GetStringType
      else
        FFwdFuncRetTypes[FFwdFuncCount] := GetIntType;
      Inc(FFwdFuncCount);
    end;
  end;

  FCurrentFuncId := FModule.AddFunction('_start', GetIntType);
  EntryBlock := FModule.AddBlock(FCurrentFuncId, 'entry');
  FModule.SetEntryBlock(FCurrentFuncId, EntryBlock);
  FCurrentBlockId := EntryBlock;
  FEntryBlockId := EntryBlock;
  FBlockTerminated := False;

  for I := 0 to FSemaModel.TypedHirNodeCount - 1 do
  begin
    Node := FSemaModel.TypedHirNodeAt(I);
    ProcessNode(Node);
  end;

  if not FBlockTerminated then
  begin
    FlushPendingCleanupNodes;
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.IntrinsicName := 'halt';
    Instr.CallTarget := '0';
    EmitInstr(Instr);
  end;

  // Transfer unit init order from semantic model to HIR module
  if FSemaModel.UnitInitOrderCount > 0 then
  begin
    SetLength(LOrder, FSemaModel.UnitInitOrderCount);
    for I := 0 to FSemaModel.UnitInitOrderCount - 1 do
      LOrder[I] := FSemaModel.UnitInitOrderAt(I);
    FModule.SetUnitInitOrder(LOrder);
  end;
end;

{ TString 24B runtime }

{$I np_hir_builder_tstring.inc}
