procedure THIRBuilder.ProcessRetRuntime(const ANode: TTypedHirNode);
var
  V, ObjPtr: THIRValueId;
  Term: THIRTerminator;
  Func: THIRFunction;
  Instr: THIRInstr;
  I: LongInt;
  SourceType, RetType: THIRTypeId;
  Normalized: THIRValueId;
begin
  if FIntfVarNames.Count > 0 then
    for I := 0 to LongInt(FIntfVarNames.Count) - 1 do
    begin
      ObjPtr := FindAlloca(FIntfVarNames[I] + '$obj');
      if ObjPtr <> 0 then
      begin
        ObjPtr := EmitLoad(GetPtrType, ObjPtr);
        { Typed interface_release at return: SystemContractKind authority. }
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        Instr.Kind := hikIntrinsic;
        Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
        AssignSystemContract(Instr, sckInterfaceRelease);
        Instr.CallTarget := SystemContractAt(sckInterfaceRelease).RuntimeMapping;
        SetLength(Instr.Operands, 1);
        Instr.Operands[0] := MakeTypedOperand(ObjPtr, GetPtrType);
        EmitInstr(Instr);
      end;
    end;
  Func := FModule.FunctionAt(FModule.FunctionCount - 1);
  if (FCurrentFuncId <> 0) then
    for I := 0 to FModule.FunctionCount - 1 do
      if FModule.FunctionAt(I).Id = FCurrentFuncId then
      begin
        Func := FModule.FunctionAt(I);
        Break;
      end;
  if (Func.Params <> nil) and (Func.Params.Count > 0) and
    (Func.Params[0].Name = 'sret_ptr') then
  begin
    FlushPendingCleanupNodes;
    FillChar(Term, SizeOf(Term), 0);
    Term.Kind := htkReturn;
    Term.ReturnValue := 0;
    if (FCurrentFuncId <> 0) and (FCurrentBlockId <> 0) then
    begin
      FModule.SetTerminator(FCurrentFuncId, FCurrentBlockId, Term);
      FBlockTerminated := True;
    end;
  end
  else
  begin
    { unit-init seeds ret-runtime with "int 0" (narrowest const width i8);
      function-body-begin defaults ReturnTypeId to i64. Cast so ret matches. }
    SourceType := 0;
    V := LowerNodeExprOrBlobTyped(ANode, ANode.Operand, SourceType);
    RetType := Func.ReturnTypeId;
    if (V <> 0) and (RetType <> 0) then
    begin
      if SourceType = 0 then
        SourceType := RetType;
      if SourceType <> RetType then
      begin
        Normalized := NormalizeScalarValueToType(V, SourceType, RetType);
        if Normalized <> 0 then
          V := Normalized;
      end;
    end;
    FlushPendingCleanupNodes;
    FillChar(Term, SizeOf(Term), 0);
    Term.Kind := htkReturn;
    Term.ReturnValue := V;
    if (FCurrentFuncId <> 0) and (FCurrentBlockId <> 0) then
    begin
      FModule.SetTerminator(FCurrentFuncId, FCurrentBlockId, Term);
      FBlockTerminated := True;
    end;
  end;
end;

procedure THIRBuilder.ProcessCallRuntime(const ANode: TTypedHirNode);
var
  Instr: THIRInstr;
  TabPos: LongInt;
  FuncName, Rest, ArgBlob, StrVarName: string;
  FirstArgBlob, FirstArgName: string;
  ArgValue, PtrVal, LenVal, ObjectFreeReceiverValue: THIRValueId;
  ArgOps: array of THIROperand;
  ArgCount: LongInt;
  OwnsObjectFreeDestroy, OwnsObjectFreeHeapRelease: Boolean;
  ObjectFreeCleanupClass: string;
  ExprResult: THIRExprResult;
  SemaTypeId: LongInt;
  Fact: TSemanticScalarTypeFact;
  TargetHirType, SourceHirType: THIRTypeId;
begin
  TabPos := Pos(#9, ANode.Operand);
  if TabPos > 0 then
  begin
    FuncName := Copy(ANode.Operand, 1, TabPos - 1);
    Rest := Copy(ANode.Operand, TabPos + 1, Length(ANode.Operand));
  end
  else
  begin
    FuncName := ANode.Operand;
    Rest := '';
  end;

  FirstArgBlob := '';
  if Rest <> '' then
  begin
    TabPos := Pos(#9, Rest);
    if TabPos > 0 then
      FirstArgBlob := Copy(Rest, 1, TabPos - 1)
    else
      FirstArgBlob := Rest;
  end;
  FirstArgName := ExtractVarOperandName(FirstArgBlob);
  OwnsObjectFreeDestroy := (FPendingObjectFreeDestroyName <> '') and
    (FPendingObjectFreeReceiverValue <> 0) and
    SameText(FuncName, FPendingObjectFreeDestroyName) and
    SameText(FirstArgName, FPendingObjectFreeReceiverName);
  ObjectFreeReceiverValue := FPendingObjectFreeReceiverValue;
  ObjectFreeCleanupClass := FPendingObjectFreeCleanupClass;
  OwnsObjectFreeHeapRelease := OwnsObjectFreeDestroy and
    FPendingObjectFreeHeapRelease;
  if FPendingObjectFreeDestroyName <> '' then
  begin
    FPendingObjectFreeDestroyName := '';
    FPendingObjectFreeReceiverName := '';
    FPendingObjectFreeReceiverValue := 0;
    FPendingObjectFreeCleanupClass := '';
    FPendingObjectFreeHeapRelease := False;
  end;

  if (ANode.ExprId > 0) and (not OwnsObjectFreeDestroy) and
    LowerExprValue(ANode.ExprId, ExprResult) then
    Exit;

  { Type-name call-runtime: TypeName(Arg) is a cast, never call @TypeName. }
  if (not OwnsObjectFreeDestroy) and (FuncName <> '') and (FSemaModel <> nil) then
  begin
    SemaTypeId := FSemaModel.FindTypeByName(FuncName);
    if (SemaTypeId > 0) and FSemaModel.GetTypeScalarFact(SemaTypeId, Fact) and
      (Fact.Kind in [sskBool, sskInt, sskFloat, sskPointer]) then
    begin
      TargetHirType := SemanticTypeIdToHirTypeId(SemaTypeId);
      if TargetHirType = 0 then
        TargetHirType := GetIntType;
      { Single residual arg blob after FuncName tab. }
      if FirstArgBlob <> '' then
      begin
        ArgValue := ParseIntExprArg(FirstArgBlob);
        if ArgValue <> 0 then
        begin
          SourceHirType := GetIntType;
          if (Length(FirstArgBlob) > 4) and (Copy(FirstArgBlob, 1, 4) = 'var ') then
          begin
            FirstArgName := ExtractVarOperandName(FirstArgBlob);
            if FindAllocaType(FirstArgName) = GetPtrType then
              SourceHirType := GetPtrType;
          end;
          ArgValue := NormalizeScalarValueToType(ArgValue, SourceHirType,
            TargetHirType);
          if ArgValue = 0 then
            Exit;
          { Value left on stack via side-effect? call-runtime discards result
            when used as statement; when used as expr, ProcessCall is via
            ParseIntExprArg 'call' token — handled in EmitExprCall. }
          Exit;
        end;
      end;
    end;
  end;

  ArgCount := 0;
  SetLength(ArgOps, 0);
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
    if OwnsObjectFreeDestroy and (ArgCount = 0) then
    begin
      SetLength(ArgOps, ArgCount + 1);
      ArgOps[ArgCount] := MakeTypedOperand(ObjectFreeReceiverValue, GetPtrType);
      Inc(ArgCount);
    end
    else if (Length(ArgBlob) > 7) and (Copy(ArgBlob, 1, 7) = 'strvar ') then
    begin
      StrVarName := Copy(ArgBlob, 8, Length(ArgBlob));
      if (Length(StrVarName) > 0) and (StrVarName[Length(StrVarName)] = #10) then
        StrVarName := Copy(StrVarName, 1, Length(StrVarName) - 1);
      PtrVal := FindAlloca(StrVarName + '$ts');
      if PtrVal <> 0 then
      begin
        PtrVal := EmitTStringData(PtrVal);
        LenVal := EmitTStringLen(FindAlloca(StrVarName + '$ts'));
        if (PtrVal <> 0) and (LenVal <> 0) then
        begin
          SetLength(ArgOps, ArgCount + 2);
          ArgOps[ArgCount] := MakeTypedOperand(PtrVal, GetPtrType);
          ArgOps[ArgCount + 1] := MakeTypedOperand(LenVal, GetIntTypeByWidth(32, True));
          Inc(ArgCount, 2);
        end;
      end;
    end
    else if (Length(ArgBlob) > 7) and (Copy(ArgBlob, 1, 7) = 'arrvar ') then
    begin
      { open-array formal → (ptr, i32 len); ParseIntExprArg only pops one value }
      StrVarName := Copy(ArgBlob, 8, Length(ArgBlob));
      if (Length(StrVarName) > 0) and (StrVarName[Length(StrVarName)] = #10) then
        StrVarName := Copy(StrVarName, 1, Length(StrVarName) - 1);
      PtrVal := FindAlloca(StrVarName + '$ptr');
      LenVal := FindAlloca(StrVarName + '$len');
      if (PtrVal <> 0) and (LenVal <> 0) then
      begin
        PtrVal := EmitLoad(GetPtrType, PtrVal);
        LenVal := EmitLoad(GetIntTypeByWidth(32, True), LenVal);
        SetLength(ArgOps, ArgCount + 2);
        ArgOps[ArgCount] := MakeTypedOperand(PtrVal, GetPtrType);
        ArgOps[ArgCount + 1] := MakeTypedOperand(LenVal, GetIntTypeByWidth(32, True));
        Inc(ArgCount, 2);
      end;
    end
    else if (Length(ArgBlob) > 7) and (Copy(ArgBlob, 1, 7) = 'strlit ') then
    begin
      StrVarName := Copy(ArgBlob, 8, Length(ArgBlob));
      if (Length(StrVarName) > 0) and (StrVarName[Length(StrVarName)] = #10) then
        StrVarName := Copy(StrVarName, 1, Length(StrVarName) - 1);
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikIntrinsic;
      Instr.TypeId := GetPtrType;
      Instr.IntrinsicName := 'str_const';
      Instr.CallTarget := StrVarName;
      EmitInstr(Instr);
      PtrVal := Instr.ResultId;
      FillChar(Instr, SizeOf(Instr), 0);
      Instr.ResultId := FModule.NewValue;
      Instr.Kind := hikLoad;
      Instr.TypeId := GetIntTypeByWidth(32, True);
      Instr.IntrinsicName := 'const:' + IntToStr(Length(StrVarName) - 2);
      EmitInstr(Instr);
      LenVal := Instr.ResultId;
      SetLength(ArgOps, ArgCount + 2);
      ArgOps[ArgCount] := MakeTypedOperand(PtrVal, GetPtrType);
      ArgOps[ArgCount + 1] := MakeTypedOperand(LenVal, GetIntTypeByWidth(32, True));
      Inc(ArgCount, 2);
    end
    else
    begin
      ArgValue := ParseIntExprArg(ArgBlob);
      if ArgValue <> 0 then
      begin
        SetLength(ArgOps, ArgCount + 1);
        if (Length(ArgBlob) > 4) and (Copy(ArgBlob, 1, 4) = 'var ') then
        begin
          StrVarName := Copy(ArgBlob, 5, Length(ArgBlob));
          if (Length(StrVarName) > 0) and (StrVarName[Length(StrVarName)] = #10) then
            StrVarName := Copy(StrVarName, 1, Length(StrVarName) - 1);
          if (not IsVarParamAlloca(StrVarName)) and
            (FindAllocaType(StrVarName) = GetPtrType) then
            ArgOps[ArgCount] := MakeTypedOperand(ArgValue, GetPtrType)
          else
            ArgOps[ArgCount] := MakeOperand(ArgValue);
        end
        else if (Pos(' p' + #10, ArgBlob) > 0) or
          (Copy(ArgBlob, 1, 4) = 'null') or
          (Copy(ArgBlob, 1, 7) = 'recvar ') or
          (Copy(ArgBlob, 1, 7) = 'varref ') then
          ArgOps[ArgCount] := MakeTypedOperand(ArgValue, GetPtrType)
        else
          ArgOps[ArgCount] := MakeOperand(ArgValue);
        Inc(ArgCount);
      end;
    end;
  end;

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  if OwnsObjectFreeDestroy then
  begin
    Instr.Kind := hikIntrinsic;
    AssignSystemContract(Instr, sckObjectFreeDestroy);
  end
  else
    Instr.Kind := hikCall;
  Instr.TypeId := GetIntType;
  Instr.CallTarget := FuncName;
  Instr.Operands := ArgOps;
  EmitInstr(Instr);

  if OwnsObjectFreeHeapRelease then
  begin
    if ObjectFreeCleanupClass <> '' then
      EmitObjectStringCleanupCall(
        ObjectFreeCleanupClass, ObjectFreeReceiverValue);
    if ObjectFreeCleanupClass <> '' then
      EmitObjectDynArrayCleanupCall(
        ObjectFreeCleanupClass, ObjectFreeReceiverValue);
    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
    AssignSystemContract(Instr, sckObjectFreeRelease);
    SetLength(Instr.Operands, 1);
    Instr.Operands[0] := MakeTypedOperand(ObjectFreeReceiverValue, GetPtrType);
    EmitInstr(Instr);
  end;
end;

procedure THIRBuilder.ProcessObjectFreeRuntime(const ANode: TTypedHirNode);
var
  CleanupClassName, DestroyName, Line, Rest, ReceiverName: string;
  Instr: THIRInstr;
  LineEnd: LongInt;
  ReceiverPtr, ReceiverSlot: THIRValueId;
  HeapRelease: Boolean;
begin
  DestroyName := '';
  CleanupClassName := '';
  ReceiverName := '';
  HeapRelease := False;
  FPendingObjectFreeDestroyName := '';
  FPendingObjectFreeReceiverName := '';
  FPendingObjectFreeReceiverValue := 0;
  FPendingObjectFreeCleanupClass := '';
  FPendingObjectFreeHeapRelease := False;
  Rest := ANode.Operand;
  while Rest <> '' do
  begin
    LineEnd := Pos(#10, Rest);
    if LineEnd > 0 then
    begin
      Line := Copy(Rest, 1, LineEnd - 1);
      Rest := Copy(Rest, LineEnd + 1, Length(Rest));
    end
    else
    begin
      Line := Rest;
      Rest := '';
    end;
    Line := Trim(Line);
    if (Length(Line) > 4) and SameText(Copy(Line, 1, 4), 'var ') then
      ReceiverName := Trim(Copy(Line, 5, Length(Line)))
    else if (Length(Line) > 8) and SameText(Copy(Line, 1, 8), 'destroy ') then
      DestroyName := Trim(Copy(Line, 9, Length(Line)))
    else if (Length(Line) > 14) and
      SameText(Copy(Line, 1, 14), 'cleanup-class ') then
      CleanupClassName := Trim(Copy(Line, 15, Length(Line)))
    else if SameText(Line, 'heap-release true') then
      HeapRelease := True;
  end;

  if ReceiverName = '' then
    Exit;
  ReceiverSlot := FindAlloca(ReceiverName);
  if ReceiverSlot = 0 then
  begin
    EnsureAlloca(ReceiverName, GetPtrType);
    ReceiverSlot := FindAlloca(ReceiverName);
  end;
  if ReceiverSlot = 0 then
    Exit;

  if IsVarParamAlloca(ReceiverName) then
    ReceiverPtr := EmitLoad(GetPtrType, EmitLoad(GetPtrType, ReceiverSlot))
  else
    ReceiverPtr := EmitLoad(GetPtrType, ReceiverSlot);

  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  AssignSystemContract(Instr, sckObjectFree);
  Instr.CallTarget := DestroyName;
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(ReceiverPtr, GetPtrType);
  EmitInstr(Instr);

  if DestroyName <> '' then
  begin
    FPendingObjectFreeDestroyName := DestroyName;
    FPendingObjectFreeReceiverName := ReceiverName;
    FPendingObjectFreeReceiverValue := ReceiverPtr;
    FPendingObjectFreeCleanupClass := CleanupClassName;
    FPendingObjectFreeHeapRelease := HeapRelease;
  end;
end;

procedure THIRBuilder.ProcessFillCharRuntime(const ANode: TTypedHirNode);
var
  TabPos1, TabPos2: LongInt;
  VarName, CountStr, ValueStr, Rest: string;
  DestAlloca, CountV, ValueV: THIRValueId;
  Instr: THIRInstr;
begin
  Rest := ANode.Operand;
  TabPos1 := Pos(#9, Rest);
  if TabPos1 = 0 then Exit;
  VarName := Trim(Copy(Rest, 1, TabPos1 - 1));
  Rest := Copy(Rest, TabPos1 + 1, Length(Rest));
  TabPos2 := Pos(#9, Rest);
  if TabPos2 = 0 then Exit;
  CountStr := Trim(Copy(Rest, 1, TabPos2 - 1));
  ValueStr := Trim(Copy(Rest, TabPos2 + 1, Length(Rest)));
  DestAlloca := FindAlloca(VarName);
  if DestAlloca = 0 then Exit;
  CountV := ParseIntExprArg(CountStr);
  if CountV = 0 then Exit;
  ValueV := ParseIntExprArg(ValueStr);
  if ValueV = 0 then Exit;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'fillchar';
  SetLength(Instr.Operands, 3);
  Instr.Operands[0] := MakeTypedOperand(DestAlloca, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(CountV, GetIntType);
  Instr.Operands[2] := MakeTypedOperand(ValueV, GetIntType);
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessMoveRuntime(const ANode: TTypedHirNode);
var
  TabPos1, TabPos2: LongInt;
  SrcVar, DstVar, CountStr, Rest: string;
  SrcAlloca, DstAlloca, CountV: THIRValueId;
  Instr: THIRInstr;
begin
  Rest := ANode.Operand;
  TabPos1 := Pos(#9, Rest);
  if TabPos1 = 0 then Exit;
  SrcVar := Trim(Copy(Rest, 1, TabPos1 - 1));
  Rest := Copy(Rest, TabPos1 + 1, Length(Rest));
  TabPos2 := Pos(#9, Rest);
  if TabPos2 = 0 then Exit;
  DstVar := Trim(Copy(Rest, 1, TabPos2 - 1));
  CountStr := Trim(Copy(Rest, TabPos2 + 1, Length(Rest)));
  SrcAlloca := FindAlloca(SrcVar);
  if SrcAlloca = 0 then Exit;
  DstAlloca := FindAlloca(DstVar);
  if DstAlloca = 0 then Exit;
  CountV := ParseIntExprArg(CountStr);
  if CountV = 0 then Exit;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  Instr.IntrinsicName := 'move';
  SetLength(Instr.Operands, 3);
  Instr.Operands[0] := MakeTypedOperand(SrcAlloca, GetPtrType);
  Instr.Operands[1] := MakeTypedOperand(DstAlloca, GetPtrType);
  Instr.Operands[2] := MakeTypedOperand(CountV, GetIntType);
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessGetMemRuntime(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  VarName, SizeStr, Rest: string;
  SizeV: THIRValueId;
  Instr: THIRInstr;
begin
  Rest := ANode.Operand;
  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  VarName := Trim(Copy(Rest, 1, TabPos - 1));
  SizeStr := Trim(Copy(Rest, TabPos + 1, Length(Rest)));
  SizeV := ParseIntExprArg(SizeStr);
  if SizeV = 0 then Exit;
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := GetPtrType;
  AssignSystemContract(Instr, sckHeapAlloc);
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(SizeV, GetIntType);
  EmitInstr(Instr);
  EmitStore(GetPtrType, Instr.ResultId, FindAlloca(VarName));
end;

procedure THIRBuilder.ProcessFreeMemRuntime(const ANode: TTypedHirNode);
var
  VarName: string;
  PtrAlloca, PtrVal: THIRValueId;
  Instr: THIRInstr;
begin
  VarName := Trim(ANode.Operand);
  if VarName = '' then Exit;
  PtrAlloca := FindAlloca(VarName);
  if PtrAlloca = 0 then Exit;
  PtrVal := EmitLoad(GetPtrType, PtrAlloca);
  FillChar(Instr, SizeOf(Instr), 0);
  Instr.ResultId := FModule.NewValue;
  Instr.Kind := hikIntrinsic;
  Instr.TypeId := FModule.Types.AddType(htkVoid, 'void');
  AssignSystemContract(Instr, sckHeapFree);
  SetLength(Instr.Operands, 1);
  Instr.Operands[0] := MakeTypedOperand(PtrVal, GetPtrType);
  EmitInstr(Instr);
end;

procedure THIRBuilder.ProcessAssignedRuntime(const ANode: TTypedHirNode);
var
  VarName: string;
  PtrAlloca, PtrVal: THIRValueId;
begin
  VarName := Trim(ANode.Operand);
  if VarName = '' then Exit;
  PtrAlloca := FindAlloca(VarName);
  if PtrAlloca = 0 then Exit;
  PtrVal := EmitLoad(GetPtrType, PtrAlloca);
  EmitCmpOp(hikCmpNe, GetBoolType,
    PtrVal, EmitNullPtrValue, GetPtrType, GetPtrType);
end;

procedure THIRBuilder.ProcessInterlockedOp(const ANode: TTypedHirNode);
var
  TabPos: LongInt;
  TargetName, ArgBlob, NewValBlob, CmpValBlob, Rest: string;
  TargetAlloca, TargetPtr, NewVal, CmpVal, Addend, FetchAddResult, OneVal: THIRValueId;
  Instr: THIRInstr;
  IntrinsicOpName: string;
  IsCas: Boolean;
  SourceType: THIRTypeId;

  { atomicrmw/cmpxchg operate on i64; pointer-swap call sites (e.g.
    InterlockedExchange on a head pointer) hand us ptr values — ptrtoint them. }
  function ToIntOperand(const AValueId: THIRValueId;
    const ASourceTypeId: THIRTypeId): THIRValueId;
  begin
    Result := AValueId;
    if (AValueId = 0) or (ASourceTypeId = 0) or
      (ASourceTypeId = GetIntType) then
      Exit;
    Result := NormalizeScalarValueToType(AValueId, ASourceTypeId, GetIntType);
    if Result = 0 then
      Result := AValueId;
  end;

begin
  Rest := ANode.Operand;
  TabPos := Pos(#9, Rest);
  if TabPos = 0 then Exit;
  TargetName := Trim(Copy(Rest, 1, TabPos - 1));
  Rest := Copy(Rest, TabPos + 1, Length(Rest));

  TargetAlloca := FindAlloca(TargetName);
  if TargetAlloca = 0 then Exit;
  TargetPtr := EmitLoad(GetPtrType, TargetAlloca);
  if TargetPtr = 0 then Exit;

  IsCas := (ANode.NodeKind = hnkInterlockedCasRuntime) or
           (ANode.NodeKind = hnkInterlockedCas64Runtime);

  if IsCas then
  begin
    { CAS: Target #9 NewValue #9 CompareValue }
    TabPos := Pos(#9, Rest);
    if TabPos = 0 then Exit;
    NewValBlob := Trim(Copy(Rest, 1, TabPos - 1));
    CmpValBlob := Trim(Copy(Rest, TabPos + 1, Length(Rest)));

    SourceType := 0;
    NewVal := LowerNodeExprOrBlobTyped(ANode, NewValBlob, SourceType);
    NewVal := ToIntOperand(NewVal, SourceType);
    SourceType := 0;
    CmpVal := LowerNodeExprOrBlobTyped(ANode, CmpValBlob, SourceType);
    CmpVal := ToIntOperand(CmpVal, SourceType);
    if (NewVal = 0) or (CmpVal = 0) then Exit;

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetIntType;
    if ANode.NodeKind = hnkInterlockedCas64Runtime then
      Instr.IntrinsicName := 'interlocked-cas64'
    else
      Instr.IntrinsicName := 'interlocked-cas';
    SetLength(Instr.Operands, 3);
    Instr.Operands[0] := MakeTypedOperand(TargetPtr, GetPtrType);
    Instr.Operands[1] := MakeTypedOperand(NewVal, GetIntType);
    Instr.Operands[2] := MakeTypedOperand(CmpVal, GetIntType);
    EmitInstr(Instr);
  end
  else
  begin
    { Exchange / FetchAdd: Target #9 Value }
    ArgBlob := Trim(Rest);
    SourceType := 0;
    Addend := LowerNodeExprOrBlobTyped(ANode, ArgBlob, SourceType);
    Addend := ToIntOperand(Addend, SourceType);
    if Addend = 0 then Exit;

    if ANode.NodeKind = hnkInterlockedXchgRuntime then
      IntrinsicOpName := 'interlocked-xchg'
    else if ANode.NodeKind = hnkInterlockedFetchAdd64Runtime then
      IntrinsicOpName := 'interlocked-fetch-add64'
    else
      IntrinsicOpName := 'interlocked-fetch-add';

    FillChar(Instr, SizeOf(Instr), 0);
    Instr.ResultId := FModule.NewValue;
    Instr.Kind := hikIntrinsic;
    Instr.TypeId := GetIntType;
    Instr.IntrinsicName := IntrinsicOpName;
    SetLength(Instr.Operands, 2);
    Instr.Operands[0] := MakeTypedOperand(TargetPtr, GetPtrType);
    Instr.Operands[1] := MakeTypedOperand(Addend, GetIntType);
    EmitInstr(Instr);
    FetchAddResult := Instr.ResultId;

    { InterlockedIncrement/Decrement return new value (old+1 / old-1), not old value }
    if (ANode.NodeKind = hnkInterlockedFetchAddRuntime) then
    begin
      { The blob for Increment is 'int 1' + #10, for Decrement is 'int -1' + #10
        For ExchangeAdd, the blob is a runtime expression. Only adjust for constants +/-1 }
      if (Length(ArgBlob) >= 7) and
         ((Copy(ArgBlob, 1, 7) = 'int 1' + #10) or
          (Copy(ArgBlob, 1, 8) = 'int -1' + #10)) then
      begin
        { This is Increment or Decrement: adjust result }
        FillChar(Instr, SizeOf(Instr), 0);
        Instr.ResultId := FModule.NewValue;
        if Copy(ArgBlob, 1, 6) = 'int -1' then
          Instr.Kind := hikSub
        else
          Instr.Kind := hikAdd;
        Instr.TypeId := GetIntType;
        SetLength(Instr.Operands, 2);
        Instr.Operands[0] := MakeTypedOperand(FetchAddResult, GetIntType);
        OneVal := EmitConstIntSmart(1);
        Instr.Operands[1] := MakeTypedOperand(OneVal, GetIntType);
        EmitInstr(Instr);
      end;
    end;
  end;
end;
