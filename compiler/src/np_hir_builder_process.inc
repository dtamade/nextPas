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
  Lines: THirNameVec;
  I, SpacePos: LongInt;
  Line, Token, Arg: string;
  V: THIRValueId;
  Instr: THIRInstr;
  ExprId: LongInt;
  ExprResult: THIRExprResult;
  OperandType: THIRTypeId;
begin
  Result := 0;
  ATypeId := 0;
  S.Init(FAllocator);
  Lines := CreateNameVec;
  try
    Line := '';
    for I := 1 to Length(AExprArg) do
    begin
      if AExprArg[I] = #10 then
      begin
        if Line <> '' then
          Lines.Push(Line);
        Line := '';
      end
      else
        Line := Line + AExprArg[I];
    end;
    if Line <> '' then
      Lines.Push(Line);

    for I := 0 to LongInt(Lines.Count) - 1 do
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
      else if Token = 'tsdata' then EmitExprTsData(S, Arg)
      else if Token = 'strlit' then EmitExprStrLit(S, Arg)
      else if Token = 'var' then EmitExprVar(S, Arg)
      else if Token = 'varref' then EmitExprVarRef(S, Arg)
      else if Token = 'funcref' then
      begin
        { Unit/threadvar address mistook for free function → residual bare
          @GThreadCache. Prefer @g_* when name is a registered global. }
        V := 0;
        if FGlobalNames.Count > 0 then
          for ExprId := 0 to LongInt(FGlobalNames.Count) - 1 do
            if SameText(FGlobalNames[ExprId], Arg) then
            begin
              FillChar(Instr, SizeOf(Instr), 0);
              Instr.ResultId := FModule.NewValue;
              Instr.Kind := hikIntrinsic;
              Instr.TypeId := GetPtrType;
              Instr.IntrinsicName := 'global_ref';
              Instr.CallTarget := Arg;
              EmitInstr(Instr);
              V := Instr.ResultId;
              Break;
            end;
        if V <> 0 then
          S.PushTyped(V, GetPtrType)
        else
        begin
          { Address of free function/procedure as i64/ptr for procedural formals. }
          FillChar(Instr, SizeOf(Instr), 0);
          Instr.ResultId := FModule.NewValue;
          Instr.Kind := hikIntrinsic;
          Instr.TypeId := GetIntType;
          Instr.IntrinsicName := 'func_ref';
          Instr.CallTarget := Arg;
          EmitInstr(Instr);
          S.PushTyped(Instr.ResultId, GetIntType);
        end;
      end
      else if Token = 'deref' then
      begin
        V := S.PopTyped(OperandType);
        if OperandType <> 0 then
          S.PushTyped(EmitLoad(OperandType, V), OperandType)
        else
          S.Push(EmitLoad(GetIntType, V));
      end
      else if Token = 'charval' then
      begin
        { Char param value: the slot holds the char address, not the value
          (8-bit scalar ABI). Load i8 from the address before comparing. }
        V := S.PopTyped(OperandType);
        S.PushTyped(EmitLoad(GetIntTypeByWidth(8, False), V),
          GetIntTypeByWidth(8, False));
      end
      else if Token = 'recvar' then EmitExprRecVar(S, Arg)
      else if Token = 'is' then EmitExprIs(S, Arg)
      else if Token = 'arr_load' then EmitExprArrLoad(S)
      else if Token = 'arr_load_ptr' then EmitExprArrLoadPtr(S)
      else if Token = 'arr_elem_ref' then EmitExprArrElemRef(S, Arg)
      else if Token = 'pelem_load' then EmitExprPtrElemLoad(S, Arg)
      else if Token = 'field_ref' then EmitExprFieldRef(S, Arg)
      else if Token = 'rload' then EmitExprRLoad(S, Arg)
      else if Token = 'fieldstrlen' then EmitExprFieldStrLen(S, Arg)
      else if Token = 'add' then EmitExprBinOp(S, hikAdd)
      else if Token = 'sub' then EmitExprBinOp(S, hikSub)
      else if Token = 'mul' then EmitExprBinOp(S, hikMul)
      else if Token = 'div' then EmitExprBinOp(S, hikDiv)
      else if Token = 'mod' then EmitExprBinOp(S, hikMod)
      else if Token = 'sar' then EmitExprBinOp(S, hikShr)
      else if Token = 'neg' then EmitExprUnaryOp(S, hikNeg, '')
      else if Token = 'abs' then EmitExprUnaryOp(S, hikIntrinsic, 'abs')
      else if Token = 'upcase' then EmitExprUnaryOp(S, hikIntrinsic, 'upcase')
      else if Token = 'bsf' then EmitExprUnaryOp(S, hikIntrinsic, 'bsf')
      else if Token = 'bsr' then EmitExprUnaryOp(S, hikIntrinsic, 'bsr')
      else if Token = 'cmp' then EmitExprCmp(S, Arg)
      else if Token = 'strcmp' then EmitExprStrCmp(S, Arg)
      else if Token = 'strpos' then EmitExprStrPos(S)
      else if Token = 'zext' then EmitExprZext(S)
      else if Token = 'call' then EmitExprCall(S, Arg)
      else if Token = 'ilk' then EmitExprInterlocked(S, Arg)
      else if Token = 'icall' then EmitExprICall(S, Arg)
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
      else if Token = 'tsload' then EmitExprTsLoad(S, Arg)
      else if Token = 'field' then EmitExprField(S, Arg)
      else if Token = 'vcall' then EmitExprVcall(S, Arg)
      else if Token = 'ivcall' then EmitExprIvcall(S, Arg);
    end;

    if S.Count > 0 then
      Result := S.PopTyped(ATypeId);
  finally
    Lines.Free;
    S.Done;
  end;
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
  Func: THIRFunction;
begin
  if ANode.NodeKind = hnkVarDeclRuntime then
  begin
    DeclType := SemanticTypeIdToHirTypeId(ANode.TypeId);
    if DeclType = 0 then
      DeclType := GetIntType;
    if FPendingParamCount > 0 then
    begin
      ParamIdx := FPendingParamLlvmIdx;
      Func := FModule.FunctionAt(FModule.FunctionCount - 1);
      if (Func.Params = nil) or (ParamIdx < 0) or
        (ParamIdx >= LongInt(Func.Params.Count)) then
      begin
        EnsureAlloca(ANode.Operand, DeclType);
        Dec(FPendingParamCount);
      end
      else
      begin
        ParamValueId := Func.Params[ParamIdx].ValueId;

        if Func.Params[ParamIdx].TypeId = GetPtrType then
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
      end;
    end
    else if FInStartFunc then
    begin
      RegisterGlobal(ANode.Operand, DeclType);
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
      RegisterGlobal(ArrName + '$ptr', GetPtrType);
      FModule.AddGlobal(ArrName + '$ptr', GetPtrType);
      RegisterGlobal(ArrName + '$len', GetIntTypeByWidth(32, True));
      FModule.AddGlobal(ArrName + '$len', GetIntTypeByWidth(32, True));
      if IsStaticArray then
        EmitStaticArrayBacking(ArrName, ArrLength);
    end
    else
    begin
      if FPendingParamCount > 0 then
      begin
        ParamIdx := FPendingParamLlvmIdx;
        Func := FModule.FunctionAt(FModule.FunctionCount - 1);
        { open-array formal needs (ptr,len); skip if ABI slots missing }
        if (Func.Params = nil) or
          (ParamIdx < 0) or
          (ParamIdx + 1 >= LongInt(Func.Params.Count)) then
        begin
          EnsureAlloca(ArrName + '$ptr', GetPtrType);
          EnsureAlloca(ArrName + '$len', GetIntTypeByWidth(32, True));
          Dec(FPendingParamCount);
        end
        else
        begin
          ParamValueId := Func.Params[ParamIdx].ValueId;
          EnsureAlloca(ArrName + '$ptr', GetPtrType);
          EmitStore(GetPtrType, ParamValueId, FindAlloca(ArrName + '$ptr'));
          Inc(FPendingParamLlvmIdx);
          ParamValueId := Func.Params[FPendingParamLlvmIdx].ValueId;
          EnsureAlloca(ArrName + '$len', GetIntTypeByWidth(32, True));
          EmitStore(GetIntTypeByWidth(32, True), ParamValueId, FindAlloca(ArrName + '$len'));
          Dec(FPendingParamCount);
          Inc(FPendingParamLlvmIdx);
        end;
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
    else if (FSretValueId <> 0) and
      (not FModule.FunctionAt(FModule.FunctionCount - 1).IsTStringReturnAbi) then
    begin
      { Record/aggregate sret Result: sret_ptr is the result buffer address.
        TString sret keeps FSretValueId only for tstring_ret_move — local
        pointers (e.g. Event: ^T) must get real allocas, not steal sret. }
      RegisterAllocaEntry(ANode.Operand, FSretValueId, GetIntType, False);
      FSretValueId := 0;
    end
    else if FInStartFunc then
    begin
      { Unit-level class/object/pointer vars (ActiveExpressionTree, GRoot…).
        Must be @g_* — EnsureAlloca only creates a _start temporary that is
        wiped when function bodies start, leaving residual call @Name(). }
      RegisterGlobal(ANode.Operand, GetPtrType);
      FModule.AddGlobal(ANode.Operand, GetPtrType, ANode.IsThreadVar);
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
    else if FInStartFunc then
    begin
      RegisterGlobal(ANode.Operand, GetPtrType);
      FModule.AddGlobal(ANode.Operand, GetPtrType, ANode.IsThreadVar);
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
        if FInStartFunc then
        begin
          { Unit-level records: emit as i64-slot global (same width as local
            record alloca base). Multi-slot layout is still coarse. }
          RegisterGlobal(Arg, GetIntType);
          FModule.AddGlobal(Arg, GetIntType, ANode.IsThreadVar);
        end
        else
        begin
          FillChar(Instr, SizeOf(Instr), 0);
          Instr.ResultId := FModule.NewValue;
          Instr.Kind := hikAlloca;
          Instr.TypeId := GetIntType;
          Instr.IntrinsicName := 'record:' + IntToStr(ParamIdx);
          EmitInstr(Instr);

          RegisterAllocaEntry(Arg, Instr.ResultId, GetIntType, False);
          if FAllocas.Count > 0 then
            FAllocas.GetPtr(FAllocas.Count - 1)^.RecordSlots := ParamIdx;
        end;
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
  { Dynarr dual-slot: assignment targets Name$ptr, never invent bare Name. }
  if Addr = 0 then
  begin
    PtrVal := FindAlloca(VarName + '$ptr');
    if (PtrVal <> 0) and (V <> 0) then
    begin
      if (ValueType <> 0) and (ValueType <> GetPtrType) then
        V := NormalizeScalarValueToType(V, ValueType, GetPtrType);
      if V <> 0 then
        EmitStore(GetPtrType, V, PtrVal);
      { Keep $len as-is when RHS is bare ptr return; SetLength/arr copy update it. }
      Exit;
    end;
  end;
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
      { Untyped expr-stack (ivcall/vcall without ' p') is i64. Record Result is
        often var-decl-ptr (StoreType=ptr) — must inttoptr before store, else
        `store ptr %i64` fails opt (TCommand.Output := LChild.WaitWithOutput). }
      if ValueType = 0 then
        ValueType := GetIntType;
      if ValueType <> StoreType then
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

  if (FPendingCleanupNodes.Count > 0) and
    (ANode.NodeKind <> hnkDynArrayCleanupRuntime) and
    (ANode.NodeKind <> hnkTStringCleanupRuntime) and
    (ANode.NodeKind <> hnkHaltCallRuntime) and
    (ANode.NodeKind <> hnkHaltCall) and
    (ANode.NodeKind <> hnkRetRuntime) and
    (ANode.NodeKind <> hnkRetTStringRuntime) then
  begin
    FlushPendingCleanupNodes;
  end;

  { Set current source position from node's symbol for debug info }
  SetCurrentSourcePosFromSymbol(ANode.SymbolId);

  if ANode.NodeKind = hnkCondBrRuntime then
  begin
    WriteLn(StdErr, '[hir] case-cond-br name=', ANode.DisplayName,
      ' expr=', IntToStr(ANode.ExprId),
      ' opLen=', IntToStr(Length(ANode.Operand)));
    Flush(StdErr);
  end;

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
    hnkTStringSetCharRuntime:
      ProcessTStringSetChar(ANode);
    hnkFieldStoreTStringRuntime:
      ProcessFieldStoreTString(ANode);
    hnkAssignRuntime:
      ProcessAssign(ANode);
    hnkHaltCallRuntime:
      ProcessHaltCall(ANode);
    hnkHaltCall:
      ProcessHaltCallConst(ANode);
    hnkCondBrRuntime:
      begin
        WriteLn(StdErr, '[hir] dispatch ProcessCondBr');
        Flush(StdErr);
        ProcessCondBr(ANode);
      end;
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
  FPendingCleanupNodes.Push(ANode);
end;

procedure THIRBuilder.FlushPendingCleanupNodes;
var
  I: SizeUInt;
  Node: TTypedHirNode;
begin
  if FPendingCleanupNodes.Count > 0 then
    for I := 0 to FPendingCleanupNodes.Count - 1 do
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
  FPendingCleanupNodes.Clear;
end;

procedure THIRBuilder.EmitProcessInit;
var
  Instr: THIRInstr;
  ContractDefinition: TSystemContractDefinition;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  { Typed process family: SystemContractKind is authority; CallTarget holds
    runtime symbol for emitter. ResultId=0 keeps the call void-shaped. }
  Instr.ResultId := 0;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  AssignSystemContract(Instr, sckProcessInit);
  ContractDefinition := SystemContractAt(sckProcessInit);
  Instr.CallTarget := ContractDefinition.RuntimeMapping;
  EmitInstr(Instr);
end;

procedure THIRBuilder.EmitProcessFini;
var
  Instr: THIRInstr;
  ContractDefinition: TSystemContractDefinition;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := 0;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  AssignSystemContract(Instr, sckProcessFini);
  ContractDefinition := SystemContractAt(sckProcessFini);
  Instr.CallTarget := ContractDefinition.RuntimeMapping;
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
  FFwdFuncNames.Clear;
  FFwdFuncRetTypes.Clear;
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
      FFwdFuncNames.Push(FwdName);
      if FwdRest = 'p' then
        FFwdFuncRetTypes.Push(GetPtrType)
      else if (FwdRest = 's') or (FwdRest = 'so') then
        FFwdFuncRetTypes.Push(GetStringType)
      else
        FFwdFuncRetTypes.Push(GetIntType);
    end
    else if Node.Kind = 'foreign-procedure-binding' then
    begin
      { Ensure libc symbols are declare'd even when procedure/function-decl
        HIR nodes never appear for imported units. }
      ProcessExternalDecl(Node);
    end;
  end;

  FCurrentFuncId := FModule.AddFunction('_start', GetIntType);
  EntryBlock := FModule.AddBlock(FCurrentFuncId, 'entry');
  FModule.SetEntryBlock(FCurrentFuncId, EntryBlock);
  FCurrentBlockId := EntryBlock;
  FEntryBlockId := EntryBlock;
  FBlockTerminated := False;

  WriteLn(StdErr, '[hir] Build process nodes count=',
    IntToStr(FSemaModel.TypedHirNodeCount));
  Flush(StdErr);
  for I := 0 to FSemaModel.TypedHirNodeCount - 1 do
  begin
    Node := FSemaModel.TypedHirNodeAt(I);
    if ((I mod 1000) = 0) or
      (Node.Kind = 'function-body-begin') or
      (Node.Kind = 'method-body-begin') or
      (Node.Kind = 'function-body-end') then
    begin
      WriteLn(StdErr, '[hir] node=', IntToStr(I), '/',
        IntToStr(FSemaModel.TypedHirNodeCount),
        ' kind=', Node.Kind,
        ' name=', Node.DisplayName);
      Flush(StdErr);
    end;
    try
      ProcessNode(Node);
    except
      WriteLn(StdErr, '[hir] AV/exception at node=', IntToStr(I),
        ' kind=', Node.Kind,
        ' name=', Node.DisplayName,
        ' op=', Copy(Node.Operand, 1, 100));
      Flush(StdErr);
      raise;
    end;
  end;
  WriteLn(StdErr, '[hir] Build process nodes done');
  Flush(StdErr);

  if not FBlockTerminated then
  begin
    FlushPendingCleanupNodes;
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    AssignSystemContract(Instr, sckHalt);
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
