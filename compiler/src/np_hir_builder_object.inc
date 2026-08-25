procedure THIRBuilder.ProcessAssignArrElem(const ANode: TTypedHirNode);
var
  TabPos, TabPos2, TabPos3: LongInt;
  ArrName, Rest, IdxBlob, ValBlob, FieldIdxStr, PlainVarName: string;
  IdxVal, ValVal, BasePtr, ElemPtr, ObjPtr, FieldIdx, SizeVal: THIRValueId;
  StoreType, ValueType: THIRTypeId;
  TargetResult: THIRExprResult;
  Token: string;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  ArrName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  if ArrName = 'self' then
  begin
    TabPos2 := Pos(#9, Rest);
    if TabPos2 = 0 then Exit;
    FieldIdxStr := Copy(Rest, 1, TabPos2 - 1);
    Rest := Copy(Rest, TabPos2 + 1, Length(Rest));

    if ANode.DisplayName <> '__field_setlength__' then
    begin
      TabPos3 := Pos(#9, Rest);
      if TabPos3 = 0 then Exit;
      IdxBlob := Copy(Rest, 1, TabPos3 - 1);
      ValBlob := Copy(Rest, TabPos3 + 1, Length(Rest));

      if LowerNodeTargetExprAddress(ANode, TargetResult) then
      begin
        ElemPtr := TargetResult.AddressValueId;
        if ElemPtr = 0 then
          Exit;

        ValVal := LowerNodeExprOrBlobTyped(ANode, ValBlob, ValueType);
        if ValVal = 0 then
          Exit;

        if ValueType <> 0 then
        begin
          { 元素宽度优先于 RHS 宽度:标量参数槽改造后 RHS 可能是 i64
            (SarLongint),元素若是 i32,按 RHS store 会写溢出。 }
          if (TargetResult.TypeId <> 0) and
            (FModule.Types.GetType(TargetResult.TypeId).Kind in [htkInt, htkPointer]) then
            StoreType := TargetResult.TypeId
          else if FModule.Types.GetType(ValueType).Kind = htkPointer then
            StoreType := GetPtrType
          else
            StoreType := GetIntType;
          if StoreType <> ValueType then
          begin
            ValVal := NormalizeScalarValueToType(ValVal, ValueType, StoreType);
            if ValVal = 0 then
              ValVal := ParseIntExprArg(ValBlob);
          end;
          if ValVal <> 0 then
            EmitStore(StoreType, ValVal, ElemPtr);
        end
        else
        begin
          Token := ExtractVarOperandName(ValBlob);
          if (Pos(' p' + #10, ValBlob) > 0) or
            ((Token <> '') and (FindAllocaType(Token) = GetPtrType)) then
            EmitStore(GetPtrType, ValVal, ElemPtr)
          else
            EmitStore(GetIntType, ValVal, ElemPtr);
        end;
        Exit;
      end;
    end;

    ObjPtr := FindAlloca('self');
    if ObjPtr = 0 then Exit;
    ObjPtr := EmitLoad(GetPtrType, ObjPtr);

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + FieldIdxStr;
    EmitInstr(Instr);
    FieldIdx := Instr.ResultId;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeOperand(ObjPtr);
    Instr.Operands[1] := MakeOperand(FieldIdx);
    EmitInstr(Instr);
    ElemPtr := Instr.ResultId;

    if ANode.DisplayName = '__field_setlength__' then
    begin
      { Element count → byte size (×8) then typed sckHeapAlloc → @np_alloc. }
      IdxVal := ParseIntExprArg(Rest);
      if IdxVal = 0 then Exit;
      SizeVal := EmitBinOp(hikMul, GetIntTypeByWidth(64, True),
        IdxVal, EmitConstIntOfType(8, GetIntTypeByWidth(64, True)));
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      AssignSystemContract(Instr, sckHeapAlloc);
      SetLength(Instr.Operands, 1);
      Instr.Operands[0] := MakeTypedOperand(SizeVal, GetIntTypeByWidth(64, True));
      EmitInstr(Instr);
      EmitStore(GetPtrType, Instr.ResultId, ElemPtr);
    end
    else
    begin
      IdxVal := ParseIntExprArg(IdxBlob);
      ValVal := ParseIntExprArg(ValBlob);
      if (IdxVal = 0) or (ValVal = 0) then Exit;

      BasePtr := EmitLoad(GetPtrType, ElemPtr);

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'gep_i64';
      SetLength(Instr.Operands, 2);
      Instr.Operands[0] := MakeOperand(BasePtr);
      Instr.Operands[1] := MakeOperand(IdxVal);
      EmitInstr(Instr);
      ElemPtr := Instr.ResultId;

      EmitStore(GetIntType, ValVal, ElemPtr);
    end;
    Exit;
  end;

  TabPos2 := Pos(#9, Rest);
  if TabPos2 = 0 then Exit;
  IdxBlob := Copy(Rest, 1, TabPos2 - 1);
  ValBlob := Copy(Rest, TabPos2 + 1, Length(Rest));

  if LowerNodeTargetExprAddress(ANode, TargetResult) then
  begin
    ElemPtr := TargetResult.AddressValueId;
    if ElemPtr = 0 then
      Exit;

    ValVal := LowerNodeExprOrBlobTyped(ANode, ValBlob, ValueType);
    if ValVal = 0 then
      Exit;

    if ValueType <> 0 then
    begin
      { 元素宽度优先于 RHS 宽度:标量参数槽改造后 RHS 可能是 i64
        (SarLongint),元素若是 i32,按 RHS store 会写溢出。 }
      if (TargetResult.TypeId <> 0) and
        (FModule.Types.GetType(TargetResult.TypeId).Kind in [htkInt, htkPointer]) then
        StoreType := TargetResult.TypeId
      else if FModule.Types.GetType(ValueType).Kind = htkPointer then
        StoreType := GetPtrType
      else
        StoreType := GetIntType;
      if StoreType <> ValueType then
      begin
        ValVal := NormalizeScalarValueToType(ValVal, ValueType, StoreType);
        if ValVal = 0 then
          ValVal := ParseIntExprArg(ValBlob);
      end;
      if ValVal <> 0 then
        EmitStore(StoreType, ValVal, ElemPtr);
    end
    else
    begin
      Token := ExtractVarOperandName(ValBlob);
      if (Pos(' p' + #10, ValBlob) > 0) or
        ((Token <> '') and (FindAllocaType(Token) = GetPtrType)) then
        EmitStore(GetPtrType, ValVal, ElemPtr)
      else
        EmitStore(GetIntType, ValVal, ElemPtr);
    end;
    Exit;
  end;

  IdxVal := ParseIntExprArg(IdxBlob);
  ValVal := ParseIntExprArg(ValBlob);
  if (IdxVal = 0) or (ValVal = 0) then Exit;
  IdxVal := NormalizeArrayIndexValue(ArrName, IdxVal);
  if IdxVal = 0 then Exit;

  BasePtr := EmitLoad(GetPtrType, FindAlloca(ArrName + '$ptr'));

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(BasePtr);
  Instr.Operands[1] := MakeOperand(IdxVal);
  EmitInstr(Instr);
  ElemPtr := Instr.ResultId;

  PlainVarName := ExtractPlainVarOperandName(ValBlob);
  if (Pos(' p' + #10, ValBlob) > 0) or
    ((PlainVarName <> '') and (FindAllocaType(PlainVarName) = GetPtrType)) then
    EmitStore(GetPtrType, ValVal, ElemPtr)
  else
    EmitStore(GetIntType, ValVal, ElemPtr);
end;

procedure THIRBuilder.ProcessMethodBegin(const ANode: TTypedHirNode);
var
  I, ColonPos, ParamCount, Pos2: LongInt;
  FuncName, Rest, ParamTypes, RetSuffix: string;
  EntryBlock: THIRBlockId;
  ParamValueId: THIRValueId;
  Instr: THIRInstr;
  RetType: THIRTypeId;
begin
  FSavedFuncId := FCurrentFuncId;
  FSavedBlockId := FCurrentBlockId;
  FSavedEntryBlockId := FEntryBlockId;
  FInStartFunc := False;
  SnapshotWorkTables(FSavedAllocas, FSavedBlockNames, FSavedBlockIds);

  FuncName := ANode.DisplayName;
  Rest := ANode.Operand;
  ColonPos := Pos(':', Rest);
  ParamCount := 0;
  ParamTypes := '';
  RetSuffix := '';
  if ColonPos > 0 then
  begin
    ParamCount := StrToIntDef(Copy(Rest, 1, ColonPos - 1), 0);
    ParamTypes := Copy(Rest, ColonPos + 1, Length(Rest));
    Pos2 := Pos(':', ParamTypes);
    if Pos2 > 0 then
    begin
      RetSuffix := Copy(ParamTypes, Pos2 + 1, Length(ParamTypes));
      ParamTypes := Copy(ParamTypes, 1, Pos2 - 1);
    end;
  end;

  if RetSuffix = 's' then
  begin
    RetType := GetStringType;
  end
  else if RetSuffix = 'p' then
    RetType := GetPtrType
  else
    RetType := GetIntType;

  FCurrentFuncId := FModule.AddFunction(FuncName, RetType);
  if RetSuffix = 's' then
  begin
    FModule.SetFunctionTStringReturnAbi(FCurrentFuncId, True);
    FModule.AddFunctionParam(FCurrentFuncId, 'sret_ptr', GetPtrType, False, False);
  end
  else if (Length(RetSuffix) > 1) and (RetSuffix[1] = 'r') then
    { Record-returning method: same ABI as free functions with :r<N> —
      void(sret_ptr, self, formals...). FSretValueId lets the retvar bind
      to the buffer instead of an uninitialized alloca ptr. }
    FModule.AddFunctionParam(FCurrentFuncId, 'sret_ptr', GetPtrType, False, False);
  FModule.AddFunctionParam(FCurrentFuncId, 'self', GetPtrType, False, False);
  for I := 1 to ParamCount - 1 do
  begin
    if (I < Length(ParamTypes)) and (ParamTypes[I + 1] = 's') then
    begin
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1) + '_ptr', GetPtrType, False, False);
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1) + '_len', GetIntTypeByWidth(32, True), False, False);
    end
    else if (I < Length(ParamTypes)) and (ParamTypes[I + 1] = 'a') then
    begin
      { open/static array formal → (ptr, i32 len) ABI, same as free functions }
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1) + '_ptr', GetPtrType, False, False);
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1) + '_len', GetIntTypeByWidth(32, True), False, False);
    end
    else if (I < Length(ParamTypes)) and (ParamTypes[I + 1] = 'v') then
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1), GetPtrType, True, False)
    else if (I < Length(ParamTypes)) and
      ((ParamTypes[I + 1] = 'p') or (ParamTypes[I + 1] = 'r')) then
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1), GetPtrType, False, False)
    else
      FModule.AddFunctionParam(FCurrentFuncId, 'p' + IntToStr(I - 1), GetIntType, False, False);
  end;

  EntryBlock := FModule.AddBlock(FCurrentFuncId, 'entry');
  FModule.SetEntryBlock(FCurrentFuncId, EntryBlock);
  FCurrentBlockId := EntryBlock;
  FEntryBlockId := EntryBlock;
  FBlockTerminated := False;
  ClearWorkAllocas;
  ClearGlobalRefs;
  ClearWorkBlocks;

  if (RetSuffix = 's') or
    ((Length(RetSuffix) > 1) and (RetSuffix[1] = 'r')) then
  begin
    FSretValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[0].ValueId;
    ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[1].ValueId;
  end
  else
  begin
    FSretValueId := 0;
    ParamValueId := FModule.FunctionAt(FModule.FunctionCount - 1).Params[0].ValueId;
  end;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikAlloca;
  Instr.TypeId := GetPtrType;
  EmitInstr(Instr);
  RegisterAllocaEntry('self', Instr.ResultId, GetPtrType, False);
  EmitStore(GetPtrType, ParamValueId, Instr.ResultId);

  FPendingParamCount := ParamCount - 1;
  if (RetSuffix = 's') or
    ((Length(RetSuffix) > 1) and (RetSuffix[1] = 'r')) then
    FPendingParamLlvmIdx := 2
  else
    FPendingParamLlvmIdx := 1;
end;

procedure THIRBuilder.ProcessClassNew(const ANode: TTypedHirNode);
var
  I, TabPos: LongInt;
  VarName, Rest, CtorName, ArgBlob: string;
  SizeVal, PtrVal, ArgValue, V, LenVal: THIRValueId;
  ArgType: THIRTypeId;
  Instr: THIRInstr;
  ArgOps: array of THIROperand;
  ArgCount: LongInt;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Rest);
  if TabPos > 0 then
  begin
    CtorName := Copy(Rest, 1, TabPos - 1);
    Rest := Copy(Rest, TabPos + 1, Length(Rest));
  end
  else
  begin
    CtorName := Rest;
    Rest := '';
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntTypeByWidth(64, True);
  Instr.IntrinsicName := 'const:' + ANode.DisplayName;
  EmitInstr(Instr);
  SizeVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  AssignSystemContract(Instr, sckObjectAlloc);
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(SizeVal, GetIntTypeByWidth(64, True));
  EmitInstr(Instr);
  PtrVal := Instr.ResultId;

  { Always keep the entry-block slot from EnsureAlloca. Re-alloca in the
    current block breaks dominance for finally FreeAndNil (load of a body
    alloca from an earlier finally block → opt "undefined value"). }
  V := FindAlloca(VarName);
  if V = 0 then
    EnsureAlloca(VarName, GetPtrType);
  V := FindAlloca(VarName);
  if IsVarParamAlloca(VarName) then
    EmitStore(GetPtrType, PtrVal, EmitLoad(GetPtrType, V))
  else
    EmitStore(GetPtrType, PtrVal, V);

  ArgCount := 1;
  SetLength(ArgOps, 1);
  ArgOps[0] := MakeTypedOperand(PtrVal, GetPtrType);
  while Rest <> '' do
  begin
    TabPos := Pos(#9, Rest);
    if TabPos > 0 then
    begin
      ArgBlob := Copy(Rest, 1, TabPos - 1);
      Rest := Copy(Rest, TabPos + 1, Length(Rest));
    end
    else
    begin
      ArgBlob := Rest;
      Rest := '';
    end;
    if (Length(ArgBlob) > 7) and (Copy(ArgBlob, 1, 7) = 'strvar ') then
    begin
      VarName := Copy(ArgBlob, 8, Length(ArgBlob));
      if (Length(VarName) > 0) and (VarName[Length(VarName)] = #10) then
        VarName := Copy(VarName, 1, Length(VarName) - 1);
      ArgValue := FindAlloca(VarName + '$ts');
      if ArgValue <> 0 then
      begin
        PtrVal := EmitTStringData(ArgValue);
        LenVal := EmitTStringLen(ArgValue);
        if (PtrVal <> 0) and (LenVal <> 0) then
        begin
          SetLength(ArgOps, ArgCount + 2);
          ArgOps[ArgCount] := MakeTypedOperand(PtrVal, GetPtrType);
          ArgOps[ArgCount + 1] := MakeTypedOperand(LenVal, GetIntTypeByWidth(32, True));
          Inc(ArgCount, 2);
        end;
      end;
    end
    else
    begin
      ArgValue := ParseIntExprArgTyped(ArgBlob, ArgType);
      if ArgValue <> 0 then
      begin
        SetLength(ArgOps, ArgCount + 1);
        if ArgType <> 0 then
          ArgOps[ArgCount] := MakeTypedOperand(ArgValue, ArgType)
        else
          ArgOps[ArgCount] := MakeOperand(ArgValue);
        Inc(ArgCount);
      end;
    end;
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikCall;
  Instr.TypeId := GetIntType;
  Instr.CallTarget := CtorName;
  Instr.Operands := ArgOps;
  EmitInstr(Instr);
end;

procedure THIRBuilder.EnsureVmtForClass(const AClassName: string);
var
  VmtCount: Int64;
  I, J: LongInt;
  Funcs: array of string;
  FuncName, ParentClass: string;
  Meta: TTypeMetadata;
begin
  for J := 0 to FModule.VmtGlobalCount - 1 do
    if FModule.VmtGlobalAt(J).ClassName = AClassName then
      Exit;
  if FSemaModel.GetTypeMetaByName(AClassName, Meta) then
  begin
    VmtCount := Meta.VmtCount;
    ParentClass := Meta.ParentClassName;
  end
  else
  begin
    if not FSemaModel.LookupConstValue(AClassName + '$vmt_count', VmtCount) then
      VmtCount := 0;
    if not FSemaModel.LookupStringConstValue(AClassName + '$parent_class', ParentClass) then
      ParentClass := '';
  end;
  SetLength(Funcs, VmtCount + 1);
  if ParentClass <> '' then
  begin
    Funcs[0] := ParentClass + '.vmt';
    EnsureVmtForClass(ParentClass);
  end
  else
    Funcs[0] := '';
  for I := 0 to VmtCount - 1 do
  begin
    { Instance $vmt_func_ consts carry the instance name for generic
      specializations (TVec.Create → TToolStatusEventVec.Create); the shared
      template VmtSlots still hold the bare template name. Prefer consts,
      fall back to VmtSlots. }
    FuncName := '';
    if not FSemaModel.LookupStringConstValue(
      AClassName + '$vmt_func_' + IntToStr(I), FuncName) then
      FuncName := '';
    if (FuncName = '') and FSemaModel.GetTypeMetaByName(AClassName, Meta) and
      (Meta.VmtSlots <> nil) and (I < LongInt(Meta.VmtSlots.Count)) then
      FuncName := Meta.VmtSlots[SizeUInt(I)].FuncQualName;
    Funcs[I + 1] := FuncName;
  end;
  FModule.AddVmtGlobal(AClassName, Funcs);
end;

procedure THIRBuilder.ProcessVmtStore(const ANode: TTypedHirNode);
var
  ClsName, FuncName, VarName, ParentClass, AbstractCheck: string;
  VmtCount: Int64;
  I, TabPos: LongInt;
  Funcs: array of string;
  ObjPtr, ZeroVal, SlotPtr: THIRValueId;
  Instr: THIRInstr;
  Meta: TTypeMetadata;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos > 0 then
  begin
    VarName := Copy(ANode.Operand, 1, TabPos - 1);
    ClsName := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  end
  else
  begin
    VarName := 'self';
    ClsName := ANode.Operand;
  end;

  if FSemaModel.GetTypeMetaByName(ClsName, Meta) then
  begin
    VmtCount := Meta.VmtCount;
    ParentClass := Meta.ParentClassName;
  end
  else
  begin
    if not FSemaModel.LookupConstValue(ClsName + '$vmt_count', VmtCount) then
      VmtCount := 0;
    if not FSemaModel.LookupStringConstValue(ClsName + '$parent_class', ParentClass) then
      ParentClass := '';
  end;

  SetLength(Funcs, VmtCount + 1);
  if ParentClass <> '' then
    Funcs[0] := ParentClass + '.vmt'
  else
    Funcs[0] := '';
  for I := 0 to VmtCount - 1 do
  begin
    { Instance $vmt_func_ consts carry the instance name for generic
      specializations (TVec.Create → TToolStatusEventVec.Create); the shared
      template VmtSlots still hold the bare template name. Prefer consts,
      fall back to VmtSlots. }
    FuncName := '';
    if not FSemaModel.LookupStringConstValue(
      ClsName + '$vmt_func_' + IntToStr(I), FuncName) then
      FuncName := '';
    if (FuncName = '') and FSemaModel.GetTypeMetaByName(ClsName, Meta) and
      (Meta.VmtSlots <> nil) and (I < LongInt(Meta.VmtSlots.Count)) then
      FuncName := Meta.VmtSlots[SizeUInt(I)].FuncQualName;
    if (FuncName <> '') and
      FSemaModel.LookupStringConstValue(
        Copy(FuncName, 1, Pos('.', FuncName) - 1) + '$abstract_' +
        Copy(FuncName, Pos('.', FuncName) + 1, Length(FuncName)), AbstractCheck) then
      FuncName := '';
    Funcs[I + 1] := FuncName;
  end;
  FModule.AddVmtGlobal(ClsName, Funcs);

  while ParentClass <> '' do
  begin
    if FSemaModel.GetTypeMetaByName(ParentClass, Meta) then
    begin
      VmtCount := Meta.VmtCount;
      SetLength(Funcs, VmtCount + 1);
      if Meta.ParentClassName <> '' then
        Funcs[0] := Meta.ParentClassName + '.vmt'
      else
        Funcs[0] := '';
      for I := 0 to VmtCount - 1 do
      begin
        if (Meta.VmtSlots <> nil) and (I < LongInt(Meta.VmtSlots.Count)) then
          FuncName := Meta.VmtSlots[SizeUInt(I)].FuncQualName
        else
          FuncName := '';
        if (FuncName <> '') and (Pos('.', FuncName) > 0) and
          FSemaModel.LookupStringConstValue(
            Copy(FuncName, 1, Pos('.', FuncName) - 1) + '$abstract_' +
            Copy(FuncName, Pos('.', FuncName) + 1, Length(FuncName)), AbstractCheck) then
          FuncName := '';
        Funcs[I + 1] := FuncName;
      end;
      FModule.AddVmtGlobal(ParentClass, Funcs);
      ParentClass := Meta.ParentClassName;
    end
    else if FSemaModel.LookupConstValue(ParentClass + '$vmt_count', VmtCount) then
    begin
      SetLength(Funcs, VmtCount + 1);
      if FSemaModel.LookupStringConstValue(ParentClass + '$parent_class', FuncName) and
        (FuncName <> '') then
        Funcs[0] := FuncName + '.vmt'
      else
        Funcs[0] := '';
      for I := 0 to VmtCount - 1 do
      begin
        if not FSemaModel.LookupStringConstValue(
          ParentClass + '$vmt_func_' + IntToStr(I), FuncName) then
          FuncName := '';
        if (FuncName <> '') and (Pos('.', FuncName) > 0) and
          FSemaModel.LookupStringConstValue(
            Copy(FuncName, 1, Pos('.', FuncName) - 1) + '$abstract_' +
            Copy(FuncName, Pos('.', FuncName) + 1, Length(FuncName)), AbstractCheck) then
          FuncName := '';
        Funcs[I + 1] := FuncName;
      end;
      FModule.AddVmtGlobal(ParentClass, Funcs);
      if not FSemaModel.LookupStringConstValue(ParentClass + '$parent_class', ParentClass) then
        ParentClass := '';
    end
    else
    begin
      SetLength(Funcs, 1);
      Funcs[0] := '';
      FModule.AddVmtGlobal(ParentClass, Funcs);
      ParentClass := '';
    end;
  end;

  ObjPtr := FindAlloca(VarName);
  if ObjPtr = 0 then Exit;
  ObjPtr := EmitLoad(GetPtrType, ObjPtr);
  if IsVarParamAlloca(VarName) then
    ObjPtr := EmitLoad(GetPtrType, ObjPtr);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:0';
  EmitInstr(Instr);
  ZeroVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(ObjPtr);
  Instr.Operands[1] := MakeOperand(ZeroVal);
  EmitInstr(Instr);
  SlotPtr := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'vmt_store';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(SlotPtr, GetPtrType);
  Instr.CallTarget := ClsName;
  EmitInstr(Instr);

  if FSemaModel.GetTypeMetaByName(ClsName, Meta) and
    (Meta.InterfaceSlots <> nil) and (Meta.InterfaceSlots.Count > 0) then
  begin
    for I := 0 to LongInt(Meta.InterfaceSlots.Count) - 1 do
    begin
      EmitInterfaceSlotStore(ObjPtr, ClsName, Meta.InterfaceSlots[SizeUInt(I)]);
    end;
  end;
end;

procedure THIRBuilder.EmitInterfaceSlotStore(AObjPtr: THIRValueId;
  const AClassName: string; const ASlot: TInterfaceSlotMeta);
var
  Instr: THIRInstr;
  OffsetVal, SlotPtr: THIRValueId;
  IntfMeta: TTypeMetadata;
  ThunkNames: array of string;
  ParamCounts: array of LongInt;
  I: LongInt;
  SymId: LongInt;
  IntfName: string;
begin
  IntfName := ASlot.InterfaceName;
  { Cross-unit parent classes leak into InterfaceSlots as pseudo-interfaces
    (EXxx = class(ENextPasError) → slot 'ENextPasError'); class-kind slots
    must not emit imt_store. Same for 0-thunk interfaces: EmitImtGlobals
    skips their global, so the store reference would dangle (M2 B5e). }
  SymId := FSemaModel.FindTypeByName(IntfName);
  if (SymId > 0) and
    SameText(FSemaModel.TypeAt(SymId - 1).Kind, 'class') then
    Exit;
  if not FSemaModel.GetTypeMetaByName(IntfName, IntfMeta) then
    Exit;
  if IntfMeta.VmtCount <= 0 then
    Exit;
  SetLength(ThunkNames, IntfMeta.VmtCount);
  SetLength(ParamCounts, IntfMeta.VmtCount);
  for I := 0 to IntfMeta.VmtCount - 1 do
  begin
    if (IntfMeta.VmtSlots <> nil) and (I < LongInt(IntfMeta.VmtSlots.Count)) then
    begin
      ThunkNames[I] := AClassName + '._intf_thunk_' + IntfName + '_' +
        IntfMeta.VmtSlots[SizeUInt(I)].MethodName;
      SymId := FSemaModel.FindSymbolByName(
        IntfName + '.' + IntfMeta.VmtSlots[SizeUInt(I)].MethodName);
      if SymId > 0 then
        ParamCounts[I] := FSemaModel.SymbolAt(SymId - 1).ParamCount
      else
        ParamCounts[I] := 0;
    end
    else
    begin
      ThunkNames[I] := '';
      ParamCounts[I] := 0;
    end;
  end;
  FModule.AddImtGlobal(AClassName, IntfName, ThunkNames, ParamCounts, ASlot.SlotOffset);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntType;
  Instr.IntrinsicName := 'const:' + IntToStr(ASlot.SlotOffset);
  EmitInstr(Instr);
  OffsetVal := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'gep_i64';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0] := MakeOperand(AObjPtr);
  Instr.Operands[1] := MakeOperand(OffsetVal);
  EmitInstr(Instr);
  SlotPtr := Instr.ResultId;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'imt_store';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(SlotPtr, GetPtrType);
  Instr.CallTarget := AClassName + '.imt.' + IntfName;
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessExceptionNode(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  LabelName: string;
  BlockId: THIRBlockId;
  VoidType: THIRTypeId;
begin
  VoidType := FModule.Types.AddType(htkVoid, 'void');
  case ANode.NodeKind of
    hnkTryBeginRuntime:
    begin
      { Typed try_push: handler label in CallTarget (was bare hikTryBegin). }
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := VoidType;
      AssignSystemContract(Instr, sckExceptionTryPush);
      if ANode.Operand <> '' then
      begin
        LabelName := ANode.Operand;
        if (Length(LabelName) > 0) and (LabelName[Length(LabelName)] = #10) then
          LabelName := Copy(LabelName, 1, Length(LabelName) - 1);
        BlockId := EnsureBlock(LabelName);
        Instr.CallTarget := 'bb' + IntToStr(BlockId);
      end;
      EmitInstr(Instr);
    end;
    hnkTryEndRuntime:
    begin
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := VoidType;
      AssignSystemContract(Instr, sckExceptionTryPop);
      EmitInstr(Instr);
    end;
    hnkFinallyBeginRuntime:
    begin
      { Marker only — no system contract kind. }
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikFinallyBegin;
      Instr.TypeId := VoidType;
      EmitInstr(Instr);
    end;
    hnkFinallyEndRuntime:
    begin
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := VoidType;
      AssignSystemContract(Instr, sckExceptionFinallyEnd);
      EmitInstr(Instr);
    end;
    hnkExceptBeginRuntime:
    begin
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikExceptBegin;
      Instr.TypeId := VoidType;
      EmitInstr(Instr);
    end;
    hnkExceptEndRuntime:
    begin
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := VoidType;
      AssignSystemContract(Instr, sckExceptionExceptEnd);
      EmitInstr(Instr);
    end;
    hnkRaiseRuntime:
    begin
      if ANode.Operand <> '' then
      begin
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikIntrinsic;
        Instr.TypeId := 0;
        Instr.IntrinsicName := 'exc_store';
        SetLength(Instr.Operands, 1);
        Instr.Operands[0] := MakeTypedOperand(ParseIntExprArg(ANode.Operand), GetPtrType);
        EmitInstr(Instr);
      end;
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := VoidType;
      AssignSystemContract(Instr, sckExceptionRaise);
      EmitInstr(Instr);
    end;
  else
    ;
  end;
end;

procedure THIRBuilder.ProcessFieldStore(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, Rest, IdxStr, ValBlob, Token: string;
  ObjPtr, IdxVal, ValVal, FieldPtr: THIRValueId;
  StoreType, ValueType: THIRTypeId;
  TargetResult: THIRExprResult;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  IdxStr := Copy(Rest, 1, TabPos - 1);
  ValBlob := Copy(Rest, TabPos + 1, Length(Rest));

  if LowerNodeTargetExprAddress(ANode, TargetResult) then
    FieldPtr := TargetResult.AddressValueId
  else
  begin
    ObjPtr := FindAlloca(VarName);
    if ObjPtr = 0 then Exit;
    ObjPtr := EmitLoad(GetPtrType, ObjPtr);

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + IdxStr;
    EmitInstr(Instr);
    IdxVal := Instr.ResultId;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeOperand(ObjPtr);
    Instr.Operands[1] := MakeOperand(IdxVal);
    EmitInstr(Instr);
    FieldPtr := Instr.ResultId;
  end;
  if FieldPtr = 0 then Exit;

  ValVal := LowerNodeExprOrBlobTyped(ANode, ValBlob, ValueType);
  if ValVal <> 0 then
  begin
    if ValueType <> 0 then
    begin
      if FModule.Types.GetType(ValueType).Kind = htkPointer then
        StoreType := GetPtrType
      else
        StoreType := GetIntType;
      if StoreType <> ValueType then
      begin
        ValVal := NormalizeScalarValueToType(ValVal, ValueType, StoreType);
        if ValVal = 0 then
          ValVal := ParseIntExprArg(ValBlob);
      end;
      if ValVal <> 0 then
        EmitStore(StoreType, ValVal, FieldPtr);
    end
    else if (Length(ValBlob) > 4) and (Copy(ValBlob, 1, 4) = 'var ') then
    begin
      Token := Copy(ValBlob, 5, Length(ValBlob));
      if (Length(Token) > 0) and (Token[Length(Token)] = #10) then
        Token := Copy(Token, 1, Length(Token) - 1);
      if FindAllocaType(Token) = GetPtrType then
        EmitStore(GetPtrType, ValVal, FieldPtr)
      else
        EmitStore(GetIntType, ValVal, FieldPtr);
    end
    else if (Pos(' p' + #10, ValBlob) > 0) or
      (Copy(ValBlob, 1, 4) = 'null') then
      EmitStore(GetPtrType, ValVal, FieldPtr)
    else
      EmitStore(GetIntType, ValVal, FieldPtr);
  end;
end;

procedure THIRBuilder.ProcessRecordFieldStore(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, Rest, IdxStr, ValBlob: string;
  RecPtr, IdxVal, ValVal, FieldPtr: THIRValueId;
  ValueType: THIRTypeId;
  TargetResult: THIRExprResult;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  IdxStr := Copy(Rest, 1, TabPos - 1);
  ValBlob := Copy(Rest, TabPos + 1, Length(Rest));

  if LowerNodeTargetExprAddress(ANode, TargetResult) then
    FieldPtr := TargetResult.AddressValueId
  else
  begin
    RecPtr := FindAlloca(VarName);
    if RecPtr = 0 then Exit;

    if FindAllocaType(VarName) = GetPtrType then
      RecPtr := EmitLoad(GetPtrType, RecPtr);

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + IdxStr;
    EmitInstr(Instr);
    IdxVal := Instr.ResultId;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeOperand(RecPtr);
    Instr.Operands[1] := MakeOperand(IdxVal);
    EmitInstr(Instr);
    FieldPtr := Instr.ResultId;
  end;
  if FieldPtr = 0 then Exit;

  ValVal := LowerNodeExprOrBlobTyped(ANode, ValBlob, ValueType);
  if ValVal <> 0 then
  begin
    if ValueType <> 0 then
    begin
      ValVal := NormalizeScalarValueToType(ValVal, ValueType, GetIntType);
      if ValVal = 0 then
        ValVal := ParseIntExprArg(ValBlob);
    end;
    if ValVal <> 0 then
      EmitStore(GetIntType, ValVal, FieldPtr);
  end;
end;

procedure THIRBuilder.ProcessRecordCopy(const ANode: TTypedHirNode);
var
  TabPos, I, FieldCount, Code: LongInt;
  DstName, Rest, SrcName, CountStr: string;
  DstPtr, SrcPtr, IdxVal, SrcField, DstField, LoadedVal: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  DstName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));

  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  SrcName := Copy(Rest, 1, TabPos - 1);
  CountStr := Copy(Rest, TabPos + 1, Length(Rest));
  Val(CountStr, FieldCount, Code);
  if Code <> 0 then Exit;

  DstPtr := FindAlloca(DstName);
  SrcPtr := FindAlloca(SrcName);
  if (DstPtr = 0) or (SrcPtr = 0) then Exit;

  for I := 0 to FieldCount - 1 do
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + IntToStr(I);
    EmitInstr(Instr);
    IdxVal := Instr.ResultId;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeOperand(SrcPtr);
    Instr.Operands[1] := MakeOperand(IdxVal);
    EmitInstr(Instr);
    SrcField := Instr.ResultId;

    LoadedVal := EmitLoad(GetIntType, SrcField);

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'const:' + IntToStr(I);
    EmitInstr(Instr);
    IdxVal := Instr.ResultId;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeOperand(DstPtr);
    Instr.Operands[1] := MakeOperand(IdxVal);
    EmitInstr(Instr);
    DstField := Instr.ResultId;

    EmitStore(GetIntType, LoadedVal, DstField);
  end;
end;
