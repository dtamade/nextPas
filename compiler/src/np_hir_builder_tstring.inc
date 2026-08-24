{ Diagnostics for silently dropped typed nodes: gated behind NEXTPAS_DEBUG=1
  so default builds stay quiet. Surfaces shape bugs like concat operands
  without a tab (b4b-i16 family) as stderr warnings instead of silence. }
procedure DebugTStringDrop(const AWhere, ADetail: string);
begin
  if GetEnvDefault('NEXTPAS_DEBUG', '') = '1' then
    WriteLn(StdErr, '[hir-builder] ', AWhere, ': ', ADetail);
end;

procedure THIRBuilder.ProcessVarDeclTString(const ANode: TTypedHirNode);
var
  ParamIdx: LongInt;
  ParamValueId, LenValueId, TsSlot, LenI64: THIRValueId;
  Func: THIRFunction;
  Instr: THIRInstr;
begin
  if FPendingParamCount > 0 then
  begin
    { Const/open string params are ABI (ptr, i32 len). Materialize a real
      24B TString so write-str-var / strcmp / assign all see a TString slot.
      Historical bug: only stored the data ptr into $ts then called
      np_tstring_data/len on that ptr-slot → garbage human-summary. }
    Func := FModule.FunctionAt(FModule.FunctionCount - 1);
    ParamIdx := FPendingParamLlvmIdx;
    if (ParamIdx < 0) or (ParamIdx + 1 >= LongInt(Func.Params.Count)) then
      Exit;
    ParamValueId := Func.Params[ParamIdx].ValueId;
    LenValueId := Func.Params[ParamIdx + 1].ValueId;
    EmitTStringInit(ANode.Operand);
    TsSlot := FindAlloca(ANode.Operand + '$ts');
    if TsSlot = 0 then
      Exit;
    { np_tstring_from_literal expects i64 len; formal is i32. }
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikZext;
    Instr.TypeId := GetIntTypeByWidth(64, True);
    SetLength(Instr.Operands, 1);
    Instr.Operands[0] := MakeTypedOperand(LenValueId, GetIntTypeByWidth(32, True));
    EmitInstr(Instr);
    LenI64 := Instr.ResultId;
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.Kind := hikIntrinsic;
    Instr.IntrinsicName := 'tstring_from_literal';
    SetLength(Instr.Operands, 3);
    Instr.Operands[0] := MakeTypedOperand(TsSlot, GetPtrType);
    Instr.Operands[1] := MakeTypedOperand(ParamValueId, GetPtrType);
    Instr.Operands[2] := MakeTypedOperand(LenI64, GetIntTypeByWidth(64, True));
    EmitInstr(Instr);
    Dec(FPendingParamCount);
    Inc(FPendingParamLlvmIdx, 2);
  end
  else if FInStartFunc and (Length(ANode.Operand) > 0) and
    (ANode.Operand[1] <> '$') then
  begin
    { True program-level string global. Compiler temps ($str_len_tmp_*,
      $str_arg_*) must stay function-local 24B allocas so sret + Length work.
      Storage is inline 24B %TString: every tstring runtime call takes the
      global's address as an inline struct, so a ptr-sized slot overflowed
      16 bytes into adjacent globals (mc_e loop-var clobber family). }
    RegisterGlobal(ANode.Operand + '$ts', GetPtrType);
    FModule.AddGlobal(ANode.Operand + '$ts', GetPtrType, False, True);
  end
  else
  begin
    { Local / temp: single 24B alloca + tstring_init }
    EmitTStringInit(ANode.Operand);
  end;
end;

procedure THIRBuilder.EmitTStringInit(const AName: string);
var
  Instr: THIRInstr;
  ContractDefinition: TSystemContractDefinition;
  SlotId: THIRValueId;
begin
  if FindAlloca(AName + '$ts') <> 0 then Exit;
  { alloca [24 x i8] — uses tstring IntrinsicName for emitter dispatch }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikAlloca;
  Instr.TypeId := GetIntType; { placeholder — emitter overrides via IntrinsicName }
  Instr.IntrinsicName := 'tstring';
  Instr.CallTarget := AName;
  if (FCurrentFuncId <> 0) and (FEntryBlockId <> 0) then
    FModule.AddInstr(FCurrentFuncId, FEntryBlockId, Instr)
  else
    EmitInstr(Instr);
  RegisterAllocaEntry(AName + '$ts', Instr.ResultId, GetPtrType, False);
  { Typed string_init: SystemContractKind authority; CallTarget = runtime map. }
  SlotId := FindAlloca(AName + '$ts');
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := 0;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  AssignSystemContract(Instr, sckStringInit);
  ContractDefinition := SystemContractAt(sckStringInit);
  Instr.CallTarget := ContractDefinition.RuntimeMapping;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0].ValueId := SlotId;
  Instr.Operands[0].TypeId := GetPtrType;
  EmitInstr(Instr);
end;

procedure THIRBuilder.EmitTStringFini(AValue: THIRValueId);
var
  Instr: THIRInstr;
  ContractDefinition: TSystemContractDefinition;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  AssignSystemContract(Instr, sckStringFini);
  ContractDefinition := SystemContractAt(sckStringFini);
  Instr.CallTarget := ContractDefinition.RuntimeMapping;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0].ValueId := AValue;
  Instr.Operands[0].TypeId := GetPtrType;
  EmitInstr(Instr);
end;

procedure THIRBuilder.EmitTStringAssign(ADst, ASrc: THIRValueId);
var
  Instr: THIRInstr;
  ContractDefinition: TSystemContractDefinition;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := 0;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  AssignSystemContract(Instr, sckStringAssign);
  ContractDefinition := SystemContractAt(sckStringAssign);
  Instr.CallTarget := ContractDefinition.RuntimeMapping;
  SetLength(Instr.Operands, 2);
  Instr.Operands[0].ValueId := ADst;
  Instr.Operands[0].TypeId := GetPtrType;
  Instr.Operands[1].ValueId := ASrc;
  Instr.Operands[1].TypeId := GetPtrType;
  EmitInstr(Instr);
end;

function THIRBuilder.EmitTStringLen(AValue: THIRValueId): THIRValueId;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  { Runtime ABI: np_tstring_len returns i64 (SizeInt-compatible). }
  Instr.TypeId := GetIntTypeByWidth(64, True);
  Instr.IntrinsicName := 'tstring_len';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0].ValueId := AValue;
  Instr.Operands[0].TypeId := GetPtrType;
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

function THIRBuilder.EmitTStringData(AValue: THIRValueId): THIRValueId;
var
  Instr: THIRInstr;
begin
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'tstring_data';
  SetLength(Instr.Operands, 1);
  Instr.Operands[0].ValueId := AValue;
  Instr.Operands[0].TypeId := GetPtrType;
  EmitInstr(Instr);
  Result := Instr.ResultId;
end;

{ Phase 4b: TString assignment operations }

procedure THIRBuilder.ProcessAssignTStringLiteral(const ANode: TTypedHirNode);
var
  DstName, LitValue: string;
  DstPtr, LitPtr, LenConst: THIRValueId;
  Instr: THIRInstr;
begin
  DstName := ANode.DisplayName;
  LitValue := ANode.Operand;
  DstPtr := FindAlloca(DstName + '$ts');
  if DstPtr = 0 then Exit;
  { Step 1: get literal data pointer via str_const }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  Instr.IntrinsicName := 'str_const';
  Instr.CallTarget := LitValue;
  EmitInstr(Instr);
  LitPtr := Instr.ResultId;
  { Step 2: emit literal length as i64 constant (matches np_tstring_from_literal). }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikLoad;
  Instr.TypeId := GetIntTypeByWidth(64, True);
  Instr.IntrinsicName := 'const:' + IntToStr(Length(LitValue));
  EmitInstr(Instr);
  LenConst := Instr.ResultId;
  { Step 3: call tstring_from_literal(dst, lit, len) }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.Kind := hikIntrinsic;
  Instr.IntrinsicName := 'tstring_from_literal';
  SetLength(Instr.Operands, 3);
  Instr.Operands[0].ValueId := DstPtr;
  Instr.Operands[0].TypeId := GetPtrType;
  Instr.Operands[1].ValueId := LitPtr;
  Instr.Operands[1].TypeId := GetPtrType;
  Instr.Operands[2].ValueId := LenConst;
  Instr.Operands[2].TypeId := GetIntTypeByWidth(64, True);
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessAssignTStringCopy(const ANode: TTypedHirNode);
var
  SrcName, DstName: string;
  SrcPtr, DstPtr: THIRValueId;
begin
  SrcName := ANode.DisplayName;
  DstName := ANode.Operand;
  if SameText(SrcName, DstName) then Exit;
  SrcPtr := FindAlloca(SrcName + '$ts');
  DstPtr := FindAlloca(DstName + '$ts');
  if (SrcPtr = 0) or (DstPtr = 0) then
  begin
    DebugTStringDrop('assign-tstring-copy',
      'missing $ts alloca; src=' + SrcName + ' dst=' + DstName);
    Exit;
  end;
  EmitTStringAssign(DstPtr, SrcPtr);
end;

{ S[I] := <char> — runtime setchar (1-based idx, CoW ensure-unique inside
  np_tstring_setchar; never inlines a raw store because heap payloads are
  shared across TString copies). Operand = strvar #9 idxblob #9 valblob. }
procedure THIRBuilder.ProcessTStringSetChar(const ANode: TTypedHirNode);
var
  StrName, Rest, IdxBlob, ValBlob: string;
  TabPos: LongInt;
  Slot, IdxVal, ValVal: THIRValueId;
  VT: THIRTypeId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then
  begin
    DebugTStringDrop('tstring-setchar',
      'operand has no tab separator; operand=' + ANode.Operand);
    Exit;
  end;
  StrName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  TabPos := Pos(#9, Rest);
  if TabPos = 0 then
  begin
    DebugTStringDrop('tstring-setchar',
      'missing value tab; operand=' + ANode.Operand);
    Exit;
  end;
  IdxBlob := Copy(Rest, 1, TabPos - 1);
  ValBlob := Copy(Rest, TabPos + 1, Length(Rest));
  Slot := FindAlloca(StrName + '$ts');
  if Slot = 0 then
  begin
    DebugTStringDrop('tstring-setchar', 'missing $ts slot; str=' + StrName);
    Exit;
  end;
  IdxVal := LowerNodeExprOrBlobTyped(ANode, IdxBlob, VT);
  if IdxVal = 0 then
    IdxVal := ParseIntExprArg(IdxBlob);
  ValVal := LowerNodeExprOrBlobTyped(ANode, ValBlob, VT);
  if ValVal = 0 then
    ValVal := ParseIntExprArg(ValBlob);
  if (IdxVal = 0) or (ValVal = 0) then
  begin
    DebugTStringDrop('tstring-setchar',
      'unresolvable idx/val; str=' + StrName);
    Exit;
  end;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'tstring_setchar';
  SetLength(Instr.Operands, 3);
  Instr.Operands[0] := MakeTypedOperand(Slot, GetPtrType);
  { np_tstring_setchar ABI is (ptr, i64 idx, i64 ch). }
  Instr.Operands[1] := MakeTypedOperand(IdxVal, GetIntTypeByWidth(64, True));
  Instr.Operands[2] := MakeTypedOperand(ValVal, GetIntTypeByWidth(64, True));
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessAssignTStringConcat(const ANode: TTypedHirNode);
var
  DstName, LhsOp, RhsOp: string;
  DstPtr, LhsPtr, RhsPtr: THIRValueId;
  TabPos: LongInt;
  Instr: THIRInstr;
begin
  DstName := ANode.DisplayName;
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then
  begin
    DebugTStringDrop('assign-tstring-concat',
      'operand has no tab separator; dst=' + DstName +
      ' operand=' + ANode.Operand);
    Exit;
  end;
  LhsOp := Copy(ANode.Operand, 1, TabPos - 1);
  RhsOp := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  DstPtr := FindAlloca(DstName + '$ts');
  LhsPtr := FindAlloca(LhsOp + '$ts');
  RhsPtr := FindAlloca(RhsOp + '$ts');
  if (DstPtr = 0) or (LhsPtr = 0) or (RhsPtr = 0) then
  begin
    DebugTStringDrop('assign-tstring-concat',
      'missing $ts alloca; dst=' + DstName + ' lhs=' + LhsOp +
      ' rhs=' + RhsOp);
    Exit;
  end;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.Kind := hikIntrinsic;
  Instr.IntrinsicName := 'tstring_concat';
  SetLength(Instr.Operands, 3);
  Instr.Operands[0].ValueId := DstPtr;
  Instr.Operands[0].TypeId := GetPtrType;
  Instr.Operands[1].ValueId := LhsPtr;
  Instr.Operands[1].TypeId := GetPtrType;
  Instr.Operands[2].ValueId := RhsPtr;
  Instr.Operands[2].TypeId := GetPtrType;
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessAssignTStringCall(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  FuncName, ArgBlob, DstName, PartBlob, ObjName, SlotText: string;
  DstPtr, V, DataPtr, LenVal, ObjSlot, SelfPtr, TablePtr, FnPtr,
    SlotVal: THIRValueId;
  ArgTypeId: THIRTypeId;
  TabPos, I, ArgPartCount, ArgCount, SlotIdx: LongInt;
  ArgParts: array of string;
  ArgValues: array of THIRValueId;
  ArgTypes: array of THIRTypeId;
  IsDynamicDispatch, IsInterfaceDispatch: Boolean;
begin
  FuncName := ANode.DisplayName;
  ArgBlob := ANode.Operand;
  TabPos := Pos(#9, ArgBlob);
  if TabPos > 0 then
  begin
    DstName := Copy(ArgBlob, 1, TabPos - 1);
    ArgBlob := Copy(ArgBlob, TabPos + 1, Length(ArgBlob));
  end
  else
  begin
    DstName := ArgBlob;
    ArgBlob := '';
  end;

  DstPtr := FindAlloca(DstName + '$ts');
  if DstPtr = 0 then
  begin
    DebugTStringDrop('assign-tstring-call',
      'missing $ts alloca; dst=' + DstName + ' callee=' + FuncName);
    Exit;
  end;

  IsDynamicDispatch := False;
  IsInterfaceDispatch := False;
  ObjName := '';
  if Copy(ArgBlob, 1, 7) = 'callee ' then
  begin
    FuncName := Copy(ArgBlob, 8, Length(ArgBlob) - 7);
    TabPos := Pos(#9, FuncName);
    if TabPos > 0 then
    begin
      ArgBlob := Copy(FuncName, TabPos + 1, Length(FuncName));
      FuncName := Copy(FuncName, 1, TabPos - 1);
    end
    else
      ArgBlob := '';
  end
  else if ArgBlob <> '' then
  begin
    TabPos := Pos(#9, ArgBlob);
    if TabPos > 0 then
    begin
      ObjName := Copy(ArgBlob, 1, TabPos - 1);
      SlotText := Copy(ArgBlob, TabPos + 1, Length(ArgBlob));
      TabPos := Pos(#9, SlotText);
      if TabPos > 0 then
      begin
        ArgBlob := Copy(SlotText, TabPos + 1, Length(SlotText));
        SlotText := Copy(SlotText, 1, TabPos - 1);
      end
      else
        ArgBlob := '';
      SlotIdx := StrToIntDef(SlotText, -1);
      if (ObjName <> '') and (SlotIdx >= 0) then
      begin
        IsDynamicDispatch := True;
        IsInterfaceDispatch := FindAlloca(ObjName + '$obj') <> 0;
      end
      else
        ArgBlob := ANode.Operand;
    end;
  end;

  ArgCount := 0;
  SetLength(ArgValues, 0);
  SetLength(ArgTypes, 0);
  if ArgBlob <> '' then
  begin
    SetLength(ArgParts, 0);
    ArgPartCount := 0;
    PartBlob := '';
    for I := 1 to Length(ArgBlob) do
    begin
      if ArgBlob[I] = #9 then
      begin
        if PartBlob <> '' then
        begin
          if ArgPartCount >= Length(ArgParts) then
            SetLength(ArgParts, ArgPartCount + 8);
          ArgParts[ArgPartCount] := PartBlob;
          Inc(ArgPartCount);
          PartBlob := '';
        end;
      end
      else
        PartBlob := PartBlob + ArgBlob[I];
    end;
    if PartBlob <> '' then
    begin
      if ArgPartCount >= Length(ArgParts) then
        SetLength(ArgParts, ArgPartCount + 8);
      ArgParts[ArgPartCount] := PartBlob;
      Inc(ArgPartCount);
    end;

    for I := 0 to ArgPartCount - 1 do
    begin
      if Copy(ArgParts[I], 1, 7) = 'strvar ' then
      begin
        PartBlob := Copy(ArgParts[I], 8, Length(ArgParts[I]) - 7);
        if (Length(PartBlob) > 0) and
          (PartBlob[Length(PartBlob)] = #10) then
          PartBlob := Copy(PartBlob, 1, Length(PartBlob) - 1);
        V := FindAlloca(PartBlob + '$ts');
        if V <> 0 then
        begin
          DataPtr := EmitTStringData(V);
          LenVal := EmitTStringLen(V);
          if (DataPtr <> 0) and (LenVal <> 0) then
          begin
            if (ArgCount + 1) >= Length(ArgValues) then
            begin
              SetLength(ArgValues, ArgCount + 8);
              SetLength(ArgTypes, ArgCount + 8);
            end;
            ArgValues[ArgCount] := DataPtr;
            ArgTypes[ArgCount] := GetPtrType;
            Inc(ArgCount);
            ArgValues[ArgCount] := LenVal;
            ArgTypes[ArgCount] := GetIntType;
            Inc(ArgCount);
          end;
        end;
      end
      else if Copy(ArgParts[I], 1, 7) = 'arrvar ' then
      begin
        { open-array / array-of-const formal → (ptr, i32 len) ABI }
        PartBlob := Copy(ArgParts[I], 8, Length(ArgParts[I]) - 7);
        if (Length(PartBlob) > 0) and
          (PartBlob[Length(PartBlob)] = #10) then
          PartBlob := Copy(PartBlob, 1, Length(PartBlob) - 1);
        DataPtr := FindAlloca(PartBlob + '$ptr');
        LenVal := FindAlloca(PartBlob + '$len');
        if (DataPtr <> 0) and (LenVal <> 0) then
        begin
          DataPtr := EmitLoad(GetPtrType, DataPtr);
          LenVal := EmitLoad(GetIntTypeByWidth(32, True), LenVal);
          if (ArgCount + 1) >= Length(ArgValues) then
          begin
            SetLength(ArgValues, ArgCount + 8);
            SetLength(ArgTypes, ArgCount + 8);
          end;
          ArgValues[ArgCount] := DataPtr;
          ArgTypes[ArgCount] := GetPtrType;
          Inc(ArgCount);
          ArgValues[ArgCount] := LenVal;
          ArgTypes[ArgCount] := GetIntTypeByWidth(32, True);
          Inc(ArgCount);
        end;
      end
      else if Copy(ArgParts[I], 1, 7) = 'strlit ' then
      begin
        PartBlob := Copy(ArgParts[I], 8, Length(ArgParts[I]) - 7);
        if (Length(PartBlob) > 0) and
          (PartBlob[Length(PartBlob)] = #10) then
          PartBlob := Copy(PartBlob, 1, Length(PartBlob) - 1);
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikIntrinsic;
        Instr.TypeId := GetPtrType;
        Instr.IntrinsicName := 'str_const';
        Instr.CallTarget := PartBlob;
        EmitInstr(Instr);
        DataPtr := Instr.ResultId;
        { Open-ABI / runtime len is i64 (np_tstring_from_literal / create). }
        LenVal := EmitConstIntOfType(Length(PartBlob) - 2, GetIntTypeByWidth(64, True));
        if (DataPtr <> 0) and (LenVal <> 0) then
        begin
          if (ArgCount + 1) >= Length(ArgValues) then
          begin
            SetLength(ArgValues, ArgCount + 8);
            SetLength(ArgTypes, ArgCount + 8);
          end;
          ArgValues[ArgCount] := DataPtr;
          ArgTypes[ArgCount] := GetPtrType;
          Inc(ArgCount);
          ArgValues[ArgCount] := LenVal;
          ArgTypes[ArgCount] := GetIntTypeByWidth(64, True);
          Inc(ArgCount);
        end;
      end
      else
      begin
        V := ParseIntExprArgTyped(ArgParts[I], ArgTypeId);
        if V <> 0 then
        begin
          if ArgCount >= Length(ArgValues) then
          begin
            SetLength(ArgValues, ArgCount + 8);
            SetLength(ArgTypes, ArgCount + 8);
          end;
          ArgValues[ArgCount] := V;
          { recvar / varref / pointer formals must stay ptr — defaulting to
            GetIntType made constref record args into i64 and broke sret calls
            like GetS(R) / Length(GetS(R)). }
          if (Copy(ArgParts[I], 1, 7) = 'recvar ') or
            (Copy(ArgParts[I], 1, 7) = 'varref ') or
            (ArgTypeId = GetPtrType) then
            ArgTypes[ArgCount] := GetPtrType
          else if (ArgTypeId <> 0) and HirTypeIsInt(ArgTypeId) then
            ArgTypes[ArgCount] := GetIntType
          else if ArgTypeId <> 0 then
            ArgTypes[ArgCount] := ArgTypeId
          else
            ArgTypes[ArgCount] := GetIntType;
          Inc(ArgCount);
        end;
      end;
    end;
  end;

  if IsDynamicDispatch then
  begin
    ObjSlot := FindAlloca(ObjName);
    if ObjSlot = 0 then
      Exit;
    SelfPtr := EmitLoad(GetPtrType, ObjSlot);
    if SelfPtr = 0 then
      Exit;

    if IsInterfaceDispatch then
    begin
      TablePtr := EmitLoad(GetPtrType, SelfPtr);
      SlotVal := EmitConstIntOfType(SlotIdx, GetIntType);
    end
    else
    begin
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikLoad;
      Instr.TypeId := GetIntType;
      Instr.IntrinsicName := 'const:0';
      EmitInstr(Instr);

      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'gep_i64';
      SetLength(Instr.Operands, 2);
      Instr.Operands[0] := MakeTypedOperand(SelfPtr, GetPtrType);
      Instr.Operands[1] := MakeTypedOperand(Instr.ResultId - 1, GetIntType);
      EmitInstr(Instr);
      TablePtr := EmitLoad(GetPtrType, Instr.ResultId);
      SlotVal := EmitConstIntOfType(SlotIdx + 1, GetIntType);
    end;
    if (TablePtr = 0) or (SlotVal = 0) then
      Exit;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'gep_i64';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeTypedOperand(TablePtr, GetPtrType);
    Instr.Operands[1] := MakeTypedOperand(SlotVal, GetIntType);
    EmitInstr(Instr);
    FnPtr := EmitLoad(GetPtrType, Instr.ResultId);
    if FnPtr = 0 then
      Exit;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.IntrinsicName := 'vcall';
    SetLength(Instr.Operands, ArgCount + 3);
    Instr.Operands[0] := MakeTypedOperand(FnPtr, GetPtrType);
    Instr.Operands[1] := MakeTypedOperand(DstPtr, GetPtrType);
    Instr.Operands[2] := MakeTypedOperand(SelfPtr, GetPtrType);
    for I := 0 to ArgCount - 1 do
      Instr.Operands[I + 3] := MakeTypedOperand(ArgValues[I], ArgTypes[I]);
  end
  else
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikCall;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    Instr.CallTarget := FuncName;
    SetLength(Instr.Operands, ArgCount + 1);
    Instr.Operands[0] := MakeTypedOperand(DstPtr, GetPtrType);
    for I := 0 to ArgCount - 1 do
      Instr.Operands[I + 1] := MakeTypedOperand(ArgValues[I], ArgTypes[I]);
  end;
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessAssignTStringFieldLoad(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, IdxStr: string;
  ObjPtr, DstPtr, IdxVal, FieldPtr: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  IdxStr := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  DstPtr := FindAlloca(ANode.DisplayName + '$ts');
  if DstPtr = 0 then Exit;
  ObjPtr := FindAlloca(VarName);
  if ObjPtr = 0 then Exit;
  { Class / var-param record slots hold a pointer; local record allocas are
    the buffer itself. Only load when the slot is ptr-typed. }
  if FindAllocaType(VarName) = GetPtrType then
    ObjPtr := EmitLoad(GetPtrType, ObjPtr);
  { GEP to field offset }
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
  { tstring_field_assign(dst, field_ptr) }
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.Kind := hikIntrinsic;
  Instr.IntrinsicName := 'tstring_field_assign';
  SetLength(Instr.Operands, 2);
  Instr.Operands[0].ValueId := DstPtr;
  Instr.Operands[0].TypeId := GetPtrType;
  Instr.Operands[1].ValueId := FieldPtr;
  Instr.Operands[1].TypeId := GetPtrType;
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessFieldStoreTString(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, Rest, IdxStr, SrcSpec, SrcName: string;
  ObjPtr, IdxVal, FieldPtr, SrcPtr, TsTmp, LenConst: THIRValueId;
  Instr: THIRInstr;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos = 0 then Exit;
  VarName := Copy(ANode.Operand, 1, TabPos - 1);
  Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  IdxStr := Copy(Rest, 1, TabPos - 1);
  SrcSpec := Copy(Rest, TabPos + 1, Length(Rest));

  ObjPtr := FindAlloca(VarName);
  if ObjPtr = 0 then Exit;
  { Class / var-param record slots hold a pointer; local record allocas are
    the buffer itself (record:N). Only load when the slot is ptr-typed. }
  if FindAllocaType(VarName) = GetPtrType then
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

  { Resolve source: 'lit ...' → from_literal, 'var ...' → tstring_assign, raw name → tstring_assign.
    Use >= 4 so empty lit (SrcSpec = 'lit ') is accepted — SelectorName := '' was dropped. }
  if (Length(SrcSpec) >= 4) and (Copy(SrcSpec, 1, 4) = 'lit ') then
  begin
    { Literal source: tstring_from_literal(field_ptr, lit_data, lit_len) }
    SrcName := Copy(SrcSpec, 5, Length(SrcSpec));
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetPtrType;
    Instr.IntrinsicName := 'str_const';
    Instr.CallTarget := SrcName;
    EmitInstr(Instr);
    SrcPtr := Instr.ResultId;
    { Create TString from literal into a temp, then field_assign }
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikAlloca;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := 'tstring';
    EmitInstr(Instr);
    TsTmp := Instr.ResultId;
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := 0;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    AssignSystemContract(Instr, sckStringInit);
    Instr.CallTarget := SystemContractAt(sckStringInit).RuntimeMapping;
    SetLength(Instr.Operands, 1);
    Instr.Operands[0].ValueId := TsTmp;
    Instr.Operands[0].TypeId := GetPtrType;
    EmitInstr(Instr);
    { literal length constant — i64 to match np_tstring_from_literal ABI }
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikLoad;
    Instr.TypeId := GetIntTypeByWidth(64, True);
    Instr.IntrinsicName := 'const:' + IntToStr(Length(SrcName));
    EmitInstr(Instr);
    LenConst := Instr.ResultId;
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.Kind := hikIntrinsic;
    Instr.IntrinsicName := 'tstring_from_literal';
    SetLength(Instr.Operands, 3);
    Instr.Operands[0].ValueId := TsTmp;
    Instr.Operands[0].TypeId := GetPtrType;
    Instr.Operands[1].ValueId := SrcPtr;
    Instr.Operands[1].TypeId := GetPtrType;
    Instr.Operands[2].ValueId := LenConst;
    Instr.Operands[2].TypeId := GetIntTypeByWidth(64, True);
    EmitInstr(Instr);
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.Kind := hikIntrinsic;
    Instr.IntrinsicName := 'tstring_field_assign';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0].ValueId := FieldPtr;
    Instr.Operands[0].TypeId := GetPtrType;
    Instr.Operands[1].ValueId := TsTmp;
    Instr.Operands[1].TypeId := GetPtrType;
    EmitInstr(Instr);
  end
  else if (Length(SrcSpec) > 4) and (Copy(SrcSpec, 1, 4) = 'var ') then
  begin
    SrcName := Copy(SrcSpec, 5, Length(SrcSpec));
    SrcPtr := FindAlloca(SrcName + '$ts');
    if SrcPtr <> 0 then
    begin
      { tstring_field_assign(field_ptr, src_ts) }
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.Kind := hikIntrinsic;
      Instr.IntrinsicName := 'tstring_field_assign';
      SetLength(Instr.Operands, 2);
      Instr.Operands[0].ValueId := FieldPtr;
      Instr.Operands[0].TypeId := GetPtrType;
      Instr.Operands[1].ValueId := SrcPtr;
      Instr.Operands[1].TypeId := GetPtrType;
      EmitInstr(Instr);
    end;
  end
  else
  begin
    { Raw variable name }
    SrcPtr := FindAlloca(SrcSpec + '$ts');
    if SrcPtr <> 0 then
    begin
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.Kind := hikIntrinsic;
      Instr.IntrinsicName := 'tstring_field_assign';
      SetLength(Instr.Operands, 2);
      Instr.Operands[0].ValueId := FieldPtr;
      Instr.Operands[0].TypeId := GetPtrType;
      Instr.Operands[1].ValueId := SrcPtr;
      Instr.Operands[1].TypeId := GetPtrType;
      EmitInstr(Instr);
    end;
  end;
end;

procedure THIRBuilder.ProcessRetTString(const ANode: TTypedHirNode);
var
  SrcName: string;
  SrcPtr: THIRValueId;
  Instr: THIRInstr;
  Term: THIRTerminator;
begin
  { Flush cleanup before return }
  if FPendingCleanupNodes.Count > 0 then
    FlushPendingCleanupNodes;
  { Find source TString variable }
  SrcName := ANode.Operand;
  SrcPtr := FindAlloca(SrcName + '$ts');
  if SrcPtr = 0 then Exit;
  { tstring_ret_move(agg.result, src) }
  if FSretValueId <> 0 then
  begin
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.Kind := hikIntrinsic;
    Instr.IntrinsicName := 'tstring_ret_move';
    SetLength(Instr.Operands, 2);
    Instr.Operands[0].ValueId := FSretValueId;
    Instr.Operands[0].TypeId := GetPtrType;
    Instr.Operands[1].ValueId := SrcPtr;
    Instr.Operands[1].TypeId := GetPtrType;
    EmitInstr(Instr);
  end;
  { Emit return void (sret function) }
  FillChar(Term, SizeOf(Term), 0);
  Term.Kind := htkReturn;
  FModule.SetTerminator(FCurrentFuncId, FCurrentBlockId, Term);
  FBlockTerminated := True;
end;

end.
