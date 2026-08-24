
uses
  SysUtils, nextpas.core.text.conv, nextpas.compiler.ir.system_contracts;

const
  NP_ALLOCATOR_PAGE_SIZE = 4096;
  NP_ALLOCATOR_PRELUDE_SIZE = 16;
  NP_ALLOCATOR_MIN_SMALL_BLOCK_SIZE = 24;
  NP_ALLOCATOR_LARGE_THRESHOLD = 65536;
  NP_ALLOCATOR_LARGE_MAGIC = '131388245100000016';

constructor THIRLlvmEmitter.Create(AModule: THIRModule);
begin
  Create(AModule, DEFAULT_LLVM_TRIPLE, DEFAULT_LLVM_DATALAYOUT, False, nil);
end;

constructor THIRLlvmEmitter.Create(AModule: THIRModule;
  const ALlvmTriple, ALlvmDataLayout: string; ADebugInfo: Boolean;
  AAllocator: IAllocator);
begin
  inherited Create;
  FModule := AModule;
  FAllocator := AAllocator;
  { 从参数读取，如果为空则使用 x86_64-linux 默认值 }
  if ALlvmTriple <> '' then
    FLlvmTriple := ALlvmTriple
  else
    FLlvmTriple := 'x86_64-unknown-linux-gnu';
  if ALlvmDataLayout <> '' then
    FLlvmDataLayout := ALlvmDataLayout
  else
    FLlvmDataLayout := 'e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64';
  if FAllocator <> nil then
  begin
    FLines := TLlvmLineVec.Create(0, FAllocator);
    FGlobalRefNames := TLlvmNameVec.Create(0, FAllocator);
    FGlobalRefIds := TLlvmValueIdVec.Create(0, FAllocator);
    FStrConstants := TLlvmNameVec.Create(0, FAllocator);
    FDebugMetadata := TLlvmNameVec.Create(0, FAllocator);
  end
  else
  begin
    FLines := TLlvmLineVec.Create;
    FGlobalRefNames := TLlvmNameVec.Create;
    FGlobalRefIds := TLlvmValueIdVec.Create;
    FStrConstants := TLlvmNameVec.Create;
    FDebugMetadata := TLlvmNameVec.Create;
  end;
  FNeedsWriteInt := False;
  FNeedsAlloc := False;
  FNeedsFree := False;
  FNeedsMemcpy := False;
  FNeedsMemset := False;
  FNeedsMemmove := False;
  FNeedsStrConcat := False;
  FNeedsStringOwnership := False;
  FNeedsTStringRuntime := False;
  FNeedsStrCmp := False;
  FNeedsIntToStr := False;
  FNeedsObjectAlloc := False;
  FNeedsObjectFreeRelease := False;
  FNeedsDynArrayHelpers := False;
  FNeedsIntfRefCountHelpers := False;
  FIsCheckCounter := 0;
  FObjectFreeCounter := 0;
  FPendingObjectFreeActive := False;
  FPendingObjectFreeReceiverValueId := 0;
  FPendingObjectFreeDestroyTarget := '';
  FPendingObjectFreeEndLabel := '';
  FNeedsExceptionRuntime := False;
  FNeedsProcessLifecycle := False;
  FProcessFiniEmitted := False;
  FTryCounter := 0;
  FDebugInfoEnabled := ADebugInfo;
  FCurrentDISubprogram := -1;
  FDIFileIndex := -1;
  FDICUIndex := -1;
end;

destructor THIRLlvmEmitter.Destroy;
begin
  FDebugMetadata.Free;
  FStrConstants.Free;
  FGlobalRefIds.Free;
  FGlobalRefNames.Free;
  FLines.Free;
  inherited Destroy;
end;

procedure THIRLlvmEmitter.ClearGlobalRefs;
begin
  FGlobalRefNames.Clear;
  FGlobalRefIds.Clear;
end;

procedure THIRLlvmEmitter.Emit(const S: string);
begin
  FLines.Push(S);
end;

function THIRLlvmEmitter.AddDebugMetadata(const AMetadata: string): LongInt;
begin
  Result := LongInt(FDebugMetadata.Count);
  FDebugMetadata.Push(AMetadata);
end;

function THIRLlvmEmitter.EmitDILocation(ALine, ACol: LongInt): LongInt;
begin
  if FCurrentDISubprogram < 0 then
    Exit(-1);
  Result := AddDebugMetadata(
    '!DILocation(line: ' + IntToStr(ALine) +
    ', column: ' + IntToStr(ACol) +
    ', scope: !' + IntToStr(FCurrentDISubprogram) + ')');
end;

procedure THIRLlvmEmitter.EmitDebugMetadataSection;
var
  I: SizeUInt;
begin
  if FDebugMetadata.Count = 0 then
    Exit;
  Emit('');
  for I := 0 to FDebugMetadata.Count - 1 do
    Emit('!' + IntToStr(I) + ' = ' + FDebugMetadata[I]);
end;

function THIRLlvmEmitter.ValueRef(AValueId: THIRValueId): string;
var
  I: SizeUInt;
begin
  if FGlobalRefIds.Count > 0 then
    for I := 0 to FGlobalRefIds.Count - 1 do
      if FGlobalRefIds[I] = AValueId then
        Exit('@g_' + FGlobalRefNames[I]);
  Result := '%v' + IntToStr(AValueId);
end;

function THIRLlvmEmitter.TypeToLlvm(ATypeId: THIRTypeId): string;
var
  T: THIRTypeRec;
begin
  if ATypeId = 0 then Exit('void');
  T := FModule.Types.GetType(ATypeId);
  case T.Kind of
    htkVoid: Result := 'void';
    htkBool: Result := 'i1';
    htkChar: Result := 'i8';
    htkInt: Result := 'i' + IntToStr(T.BitWidth);
    htkFloat:
      case T.FloatWidth of
        fwF32: Result := 'float';
        fwF64: Result := 'double';
        fwF80: Result := 'x86_fp80';
      end;
    htkPointer, htkUntypedPtr: Result := 'ptr';
    htkString: Result := 'ptr';
    { Composite types are always passed by reference in LLVM IR }
    htkArray, htkDynArray, htkSet,
    htkRecord, htkClass, htkInterface, htkClassRef,
    htkFunc: Result := 'ptr';
  else
    Result := 'ptr'; { defensive: unknown types default to ptr, not i64 }
  end;
end;

function THIRLlvmEmitter.BlockEndsWithIntrinsicReturn(
  const ABlock: THIRBlock): Boolean;
var
  LastInstr: THIRInstr;
begin
  Result := False;
  if (ABlock.Instrs = nil) or (ABlock.Instrs.Count = 0) then
    Exit;
  LastInstr := ABlock.Instrs[ABlock.Instrs.Count - 1];
  Result := (LastInstr.Kind = hikIntrinsic) and
    ((LastInstr.IntrinsicName = 'ret_str') or
     (LastInstr.IntrinsicName = 'ret_str_owned'));
end;

function THIRLlvmEmitter.OperandTypeToLlvm(const AOperand: THIROperand;
  const AFallback: string): string;
begin
  if AOperand.TypeId <> 0 then
    Result := TypeToLlvm(AOperand.TypeId)
  else
    Result := ValueLlvmType(AOperand.ValueId, AFallback);
end;

procedure THIRLlvmEmitter.NoteValueLlvmType(AValueId: THIRValueId;
  const ALlvmType: string);
begin
  if (AValueId = 0) or (ALlvmType = '') then
    Exit;
  if AValueId > Length(FValueLlvmTypes) then
    SetLength(FValueLlvmTypes, AValueId + 64);
  FValueLlvmTypes[AValueId - 1] := ALlvmType;
end;

function THIRLlvmEmitter.ValueLlvmType(AValueId: THIRValueId;
  const AFallback: string): string;
begin
  if (AValueId > 0) and (AValueId <= Length(FValueLlvmTypes)) and
    (FValueLlvmTypes[AValueId - 1] <> '') then
    Exit(FValueLlvmTypes[AValueId - 1]);
  Result := AFallback;
end;

function LlvmFpBitWidth(const ATy: string): LongInt;
begin
  if ATy = 'float' then
    Exit(32);
  if ATy = 'double' then
    Exit(64);
  if ATy = 'x86_fp80' then
    Exit(80);
  Result := 0;
end;

function IsLlvmFpType(const ATy: string): Boolean;
begin
  Result := (ATy = 'float') or (ATy = 'double') or (ATy = 'x86_fp80');
end;

function THIRLlvmEmitter.EmitCastValueToLlvmType(AValueId: THIRValueId;
  const AWantedTy, ATag: string;
  const AHaveTyHint: string): string;
var
  HaveTy: string;
  CastName, MidName, IntTy: string;
  WantW, HaveW: LongInt;
begin
  if AValueId = 0 then
  begin
    if (AWantedTy = 'ptr') or (AWantedTy = '') then
      Exit('null');
    if (AWantedTy = 'float') or (AWantedTy = 'double') or
      (AWantedTy = 'x86_fp80') then
      Exit('0.0');
    Exit('0');
  end;
  Result := ValueRef(AValueId);
  if AWantedTy = '' then
    Exit;
  { Prefer noted SSA type; optional hint (operand TypeId); never assume Wanted. }
  HaveTy := ValueLlvmType(AValueId, '');
  if HaveTy = '' then
    HaveTy := AHaveTyHint;
  if HaveTy = '' then
    Exit;
  if HaveTy = AWantedTy then
    Exit;
  CastName := '%cast.' + ATag + '.' + IntToStr(AValueId);
  if (HaveTy = 'ptr') and (Copy(AWantedTy, 1, 1) = 'i') then
  begin
    Emit('  ' + CastName + ' = ptrtoint ptr ' + Result + ' to ' + AWantedTy);
    Result := CastName;
  end
  else if (AWantedTy = 'ptr') and (Copy(HaveTy, 1, 1) = 'i') then
  begin
    Emit('  ' + CastName + ' = inttoptr ' + HaveTy + ' ' + Result + ' to ptr');
    Result := CastName;
  end
  else if (Copy(HaveTy, 1, 1) = 'i') and (Copy(AWantedTy, 1, 1) = 'i') then
  begin
    WantW := StrToIntDef(Copy(AWantedTy, 2, 8), 0);
    HaveW := StrToIntDef(Copy(HaveTy, 2, 8), 0);
    if WantW > HaveW then
    begin
      Emit('  ' + CastName + ' = sext ' + HaveTy + ' ' + Result +
        ' to ' + AWantedTy);
      Result := CastName;
    end
    else if WantW < HaveW then
    begin
      Emit('  ' + CastName + ' = trunc ' + HaveTy + ' ' + Result +
        ' to ' + AWantedTy);
      Result := CastName;
    end;
  end
  else if (HaveTy = 'i1') and (Copy(AWantedTy, 1, 1) = 'i') then
  begin
    Emit('  ' + CastName + ' = zext i1 ' + Result + ' to ' + AWantedTy);
    Result := CastName;
  end
  else if IsLlvmFpType(HaveTy) and IsLlvmFpType(AWantedTy) then
  begin
    { float ↔ double: value conversion, not bitcast. }
    HaveW := LlvmFpBitWidth(HaveTy);
    WantW := LlvmFpBitWidth(AWantedTy);
    if WantW > HaveW then
      Emit('  ' + CastName + ' = fpext ' + HaveTy + ' ' + Result +
        ' to ' + AWantedTy)
    else
      Emit('  ' + CastName + ' = fptrunc ' + HaveTy + ' ' + Result +
        ' to ' + AWantedTy);
    Result := CastName;
  end
  else if IsLlvmFpType(HaveTy) and (Copy(AWantedTy, 1, 1) = 'i') then
  begin
    { Residual Result/slot often i64 while SSA is float/double.
      Preserve bits: bitcast to same-width int, then zext/trunc. }
    HaveW := LlvmFpBitWidth(HaveTy);
    WantW := StrToIntDef(Copy(AWantedTy, 2, 8), 0);
    if (HaveW <= 0) or (WantW <= 0) then
      Exit;
    IntTy := 'i' + IntToStr(HaveW);
    if HaveW = WantW then
    begin
      Emit('  ' + CastName + ' = bitcast ' + HaveTy + ' ' + Result +
        ' to ' + AWantedTy);
      Result := CastName;
    end
    else
    begin
      MidName := '%cast.fp2i.' + ATag + '.' + IntToStr(AValueId);
      Emit('  ' + MidName + ' = bitcast ' + HaveTy + ' ' + Result +
        ' to ' + IntTy);
      if WantW > HaveW then
        Emit('  ' + CastName + ' = zext ' + IntTy + ' ' + MidName +
          ' to ' + AWantedTy)
      else
        Emit('  ' + CastName + ' = trunc ' + IntTy + ' ' + MidName +
          ' to ' + AWantedTy);
      Result := CastName;
    end;
  end
  else if (Copy(HaveTy, 1, 1) = 'i') and IsLlvmFpType(AWantedTy) then
  begin
    { Inverse residual path: iN slot → float/double use site. }
    HaveW := StrToIntDef(Copy(HaveTy, 2, 8), 0);
    WantW := LlvmFpBitWidth(AWantedTy);
    if (HaveW <= 0) or (WantW <= 0) then
      Exit;
    IntTy := 'i' + IntToStr(WantW);
    if HaveW = WantW then
    begin
      Emit('  ' + CastName + ' = bitcast ' + HaveTy + ' ' + Result +
        ' to ' + AWantedTy);
      Result := CastName;
    end
    else
    begin
      MidName := '%cast.i2fp.' + ATag + '.' + IntToStr(AValueId);
      if HaveW > WantW then
        Emit('  ' + MidName + ' = trunc ' + HaveTy + ' ' + Result +
          ' to ' + IntTy)
      else
        Emit('  ' + MidName + ' = zext ' + HaveTy + ' ' + Result +
          ' to ' + IntTy);
      Emit('  ' + CastName + ' = bitcast ' + IntTy + ' ' + MidName +
        ' to ' + AWantedTy);
      Result := CastName;
    end;
  end;
  { Other mismatched pairs left uncast — prefer crash at opt over wrong IR. }
end;

function THIRLlvmEmitter.IsUnsignedIntegerType(const ATypeId: THIRTypeId): Boolean;
var
  TypeRec: THIRTypeRec;
begin
  if ATypeId = 0 then
    Exit(False);
  TypeRec := FModule.Types.GetType(ATypeId);
  Result := (TypeRec.Kind = htkInt) and (not TypeRec.Signed);
end;

function THIRLlvmEmitter.IsUnsignedOrderedCompareType(
  const ATypeId: THIRTypeId
): Boolean;
var
  TypeRec: THIRTypeRec;
begin
  if ATypeId = 0 then
    Exit(False);
  TypeRec := FModule.Types.GetType(ATypeId);
  Result := ((TypeRec.Kind = htkInt) and (not TypeRec.Signed)) or
    (TypeRec.Kind = htkPointer) or (TypeRec.Kind = htkUntypedPtr);
end;

function THIRLlvmEmitter.DivOpcodeToLlvm(const AInstr: THIRInstr): string;
var
  OperandTypeId: THIRTypeId;
begin
  OperandTypeId := AInstr.TypeId;
  if Length(AInstr.Operands) >= 1 then
    OperandTypeId := AInstr.Operands[0].TypeId;
  if IsUnsignedIntegerType(OperandTypeId) then
    Result := 'udiv'
  else
    Result := 'sdiv';
end;

function THIRLlvmEmitter.ModOpcodeToLlvm(const AInstr: THIRInstr): string;
var
  OperandTypeId: THIRTypeId;
begin
  OperandTypeId := AInstr.TypeId;
  if Length(AInstr.Operands) >= 1 then
    OperandTypeId := AInstr.Operands[0].TypeId;
  if IsUnsignedIntegerType(OperandTypeId) then
    Result := 'urem'
  else
    Result := 'srem';
end;

function THIRLlvmEmitter.CompareOpcodeToLlvm(const AInstr: THIRInstr): string;
var
  OperandTypeId: THIRTypeId;
begin
  OperandTypeId := 0;
  if Length(AInstr.Operands) >= 1 then
    OperandTypeId := AInstr.Operands[0].TypeId;

  case AInstr.Kind of
    hikCmpEq:
      Result := 'eq';
    hikCmpNe:
      Result := 'ne';
    hikCmpLt:
      if IsUnsignedOrderedCompareType(OperandTypeId) then
        Result := 'ult'
      else
        Result := 'slt';
    hikCmpLe:
      if IsUnsignedOrderedCompareType(OperandTypeId) then
        Result := 'ule'
      else
        Result := 'sle';
    hikCmpGt:
      if IsUnsignedOrderedCompareType(OperandTypeId) then
        Result := 'ugt'
      else
        Result := 'sgt';
    hikCmpGe:
      if IsUnsignedOrderedCompareType(OperandTypeId) then
        Result := 'uge'
      else
        Result := 'sge';
  else
    Result := 'eq';
  end;
end;

procedure THIRLlvmEmitter.EmitCallInstr(const AInstr: THIRInstr);
var
  I: LongInt;
  LlvmType, Op, SretRef, FirstTy, ArgTy, FormalTy: string;
  IsTStringSret: Boolean;
  IsRecordSret: Boolean;
  NeedSretInject: Boolean;
  Callee: THIRFunction;
  HaveCallee: Boolean;
  CalleeParamIndex: LongInt;
  J: LongInt;
begin
  LlvmType := TypeToLlvm(AInstr.TypeId);
  if (LlvmType = '') or (LlvmType = 'void') then
    if AInstr.ResultId <> 0 then
      LlvmType := 'i64';
  IsTStringSret := IsTStringSretFunction(AInstr.CallTarget);
  IsRecordSret := (not IsTStringSret) and IsSretFunction(AInstr.CallTarget);
  SretRef := '';
  NeedSretInject := False;
  HaveCallee := False;
  FillChar(Callee, SizeOf(Callee), 0);
  for J := 0 to FModule.FunctionCount - 1 do
  begin
    Callee := FModule.FunctionAt(J);
    if SameText(Callee.Name, AInstr.CallTarget) then
    begin
      HaveCallee := True;
      Break;
    end;
  end;
  { Batch 25: TString-return ABI is void(ptr sret(%TString), formals...).
    Scalar-encoded call sites pass only formals and store ResultId; inject a
    temp slot and bind ResultId so Length(GetS(...)) / field consumers work. }
  if IsTStringSret then
  begin
    FNeedsTStringRuntime := True;
    if Length(AInstr.Operands) = 0 then
      NeedSretInject := True
    else
    begin
      if AInstr.Operands[0].TypeId <> 0 then
        FirstTy := TypeToLlvm(AInstr.Operands[0].TypeId)
      else
        FirstTy := 'i64';
      if (FirstTy <> 'ptr') and (Pos('ptr', FirstTy) <> 1) then
        NeedSretInject := True
      else
        SretRef := ValueRef(AInstr.Operands[0].ValueId);
    end;
    if NeedSretInject then
    begin
      SretRef := '%sret.tmp.' + IntToStr(AInstr.ResultId);
      Emit('  ' + SretRef + ' = alloca [24 x i8], align 8');
      Emit('  call void @np_tstring_init(ptr ' + SretRef + ')');
    end;
    Op := '  call void ' + LlvmGlobalRef(AInstr.CallTarget) + '(ptr sret(%TString) ' + SretRef;
    for I := 0 to High(AInstr.Operands) do
    begin
      if (not NeedSretInject) and (I = 0) then
        Continue;
      Op := Op + ', ';
      if AInstr.Operands[I].TypeId <> 0 then
        ArgTy := TypeToLlvm(AInstr.Operands[I].TypeId)
      else
        ArgTy := 'i64';
      if ArgTy = '' then
        ArgTy := 'i64';
      { Cast SSA value to the call-site type (small ints often land as i8/i32). }
      Op := Op + ArgTy + ' ' + EmitCastValueToLlvmType(
        AInstr.Operands[I].ValueId, ArgTy, 'callarg.' + IntToStr(AInstr.ResultId) +
        '.' + IntToStr(I));
    end;
    Op := Op + ')';
    Emit(Op);
    if AInstr.ResultId <> 0 then
    begin
      Emit('  ' + ValueRef(AInstr.ResultId) + ' = bitcast ptr ' +
        SretRef + ' to ptr');
      NoteValueLlvmType(AInstr.ResultId, 'ptr');
    end;
    Exit;
  end;
  { Record/aggregate sret: callee is void(sret_ptr, formals...).
    Residual encode for `Rec := F(...)` puts `recvar Rec` as first operand so F
    writes directly into Rec — use that ptr as sret (do NOT inject a second one).
    Expression-context calls have only the true formals → inject a temp buffer.
    Bind ResultId via ptrtoint so residual `store i64 %result` stays SSA-valid. }
  if IsRecordSret then
  begin
    SretRef := '';
    I := 0;
    CalleeParamIndex := 1; { skip sret_ptr in callee formals }
    if Length(AInstr.Operands) > 0 then
    begin
      FirstTy := '';
      if AInstr.Operands[0].TypeId <> 0 then
        FirstTy := TypeToLlvm(AInstr.Operands[0].TypeId);
      if FirstTy = '' then
        FirstTy := ValueLlvmType(AInstr.Operands[0].ValueId, '');
      { Dest present when first op is ptr and cannot be the first true formal:
        - formal after sret is non-ptr → first ptr must be recvar dest
        - or operand count = formals_after_sret + 1 (extra dest slot)
        Incomplete residual args still need dest detection via formal type. }
      if FirstTy = 'ptr' then
      begin
        NeedSretInject := False; { True below = treat first as dest }
        if HaveCallee and (Callee.Params <> nil) and
          (Callee.Params.Count > 1) then
        begin
          FormalTy := TypeToLlvm(Callee.Params[1].TypeId);
          J := LongInt(Callee.Params.Count) - 1; { formals after sret }
          if J < 0 then
            J := 0;
          if (FormalTy <> '') and (FormalTy <> 'ptr') then
            NeedSretInject := True
          else if Length(AInstr.Operands) = J + 1 then
            NeedSretInject := True;
        end
        else
          NeedSretInject := True; { no callee meta: recvar-first residual encode }
        if NeedSretInject then
        begin
          SretRef := EmitCastValueToLlvmType(
            AInstr.Operands[0].ValueId, 'ptr',
            'sret.dest.' + IntToStr(AInstr.ResultId), FirstTy);
          I := 1; { skip dest operand }
        end;
      end;
    end;
    if SretRef = '' then
    begin
      SretRef := '%sret.rec.' + IntToStr(AInstr.ResultId);
      { Conservative buffer: large config records GEPs past a few dozen slots. }
      Emit('  ' + SretRef + ' = alloca [512 x i64], align 8');
      Emit('  call void @np_memset(ptr ' + SretRef + ', i8 0, i64 4096)');
      FNeedsMemcpy := True;
      FNeedsMemset := True;
      I := 0;
    end;
    Op := '  call void ' + LlvmGlobalRef(AInstr.CallTarget) + '(ptr ' + SretRef;
    while I <= High(AInstr.Operands) do
    begin
      Op := Op + ', ';
      { String formal pair (pN_ptr, pN_len): either already expanded (ptr,int)
        or a single TString buffer that needs data/len unpack. }
      if HaveCallee and (Callee.Params <> nil) and
        (CalleeParamIndex + 1 < LongInt(Callee.Params.Count)) and
        (Pos('_ptr', Callee.Params[SizeUInt(CalleeParamIndex)].Name) > 0) and
        (Pos('_len', Callee.Params[SizeUInt(CalleeParamIndex + 1)].Name) > 0) then
      begin
        FirstTy := '';
        if AInstr.Operands[I].TypeId <> 0 then
          FirstTy := TypeToLlvm(AInstr.Operands[I].TypeId);
        if FirstTy = '' then
          FirstTy := ValueLlvmType(AInstr.Operands[I].ValueId, 'i64');
        if (I + 1 <= High(AInstr.Operands)) then
        begin
          ArgTy := '';
          if AInstr.Operands[I + 1].TypeId <> 0 then
            ArgTy := TypeToLlvm(AInstr.Operands[I + 1].TypeId);
          if ArgTy = '' then
            ArgTy := ValueLlvmType(AInstr.Operands[I + 1].ValueId, '');
        end
        else
          ArgTy := '';
        if (FirstTy = 'ptr') and (ArgTy <> '') and (Copy(ArgTy, 1, 1) = 'i') then
        begin
          { Already (data,len). }
          Op := Op + 'ptr ' + EmitCastValueToLlvmType(
            AInstr.Operands[I].ValueId, 'ptr',
            'callarg.' + IntToStr(AInstr.ResultId) + '.' + IntToStr(I));
          Op := Op + ', i32 ' + EmitCastValueToLlvmType(
            AInstr.Operands[I + 1].ValueId, 'i32',
            'callarg.' + IntToStr(AInstr.ResultId) + '.' + IntToStr(I + 1));
          Inc(I, 2);
          Inc(CalleeParamIndex, 2);
          Continue;
        end;
        if FirstTy = 'ptr' then
        begin
          { TString buffer → expand. }
          FNeedsTStringRuntime := True;
          Emit('  %ts.data.' + IntToStr(AInstr.ResultId) + '.' + IntToStr(I) +
            ' = call ptr @np_tstring_data(ptr ' +
            ValueRef(AInstr.Operands[I].ValueId) + ')');
          Emit('  %ts.len64.' + IntToStr(AInstr.ResultId) + '.' + IntToStr(I) +
            ' = call i64 @np_tstring_len(ptr ' +
            ValueRef(AInstr.Operands[I].ValueId) + ')');
          Emit('  %ts.len32.' + IntToStr(AInstr.ResultId) + '.' + IntToStr(I) +
            ' = trunc i64 %ts.len64.' + IntToStr(AInstr.ResultId) + '.' +
            IntToStr(I) + ' to i32');
          Op := Op + 'ptr %ts.data.' + IntToStr(AInstr.ResultId) + '.' +
            IntToStr(I) + ', i32 %ts.len32.' + IntToStr(AInstr.ResultId) +
            '.' + IntToStr(I);
          Inc(I);
          Inc(CalleeParamIndex, 2);
          Continue;
        end;
      end;
      ArgTy := '';
      if HaveCallee and (Callee.Params <> nil) and
        (CalleeParamIndex < LongInt(Callee.Params.Count)) then
        ArgTy := TypeToLlvm(Callee.Params[SizeUInt(CalleeParamIndex)].TypeId);
      if ArgTy = '' then
      begin
        if AInstr.Operands[I].TypeId <> 0 then
          ArgTy := TypeToLlvm(AInstr.Operands[I].TypeId)
        else
          ArgTy := ValueLlvmType(AInstr.Operands[I].ValueId, 'i64');
      end;
      if ArgTy = '' then
        ArgTy := 'i64';
      Op := Op + ArgTy + ' ' + EmitCastValueToLlvmType(
        AInstr.Operands[I].ValueId, ArgTy, 'callarg.' + IntToStr(AInstr.ResultId) +
        '.' + IntToStr(I), ValueLlvmType(AInstr.Operands[I].ValueId, ''));
      Inc(I);
      Inc(CalleeParamIndex);
    end;
    Op := Op + ')';
    Emit(Op);
    if AInstr.ResultId <> 0 then
    begin
      Emit('  ' + ValueRef(AInstr.ResultId) + ' = ptrtoint ptr ' +
        SretRef + ' to i64');
      NoteValueLlvmType(AInstr.ResultId, 'i64');
    end;
    Exit;
  end;
  { Ordinary calls: prefer noted SSA type for casts; ArgTy follows operand
    TypeId when set (residual i64 ABI), else noted type, else i64. }
  { Call-signature consistency meter (v2.27 defensive follow-up). Strict
    raise is env-gated (NEXTPAS_EMIT_STRICT_CALLS=1): the residual layer
    still carries ~148 shape-drifted bare-name calls per probe (~1893 in
    the L3 build, 0825 cache scan), so always-on would red every gate.
    This meter is the acceptance tool for that cleanup campaign. }
  if FStrictCalls and HaveCallee and (Callee.Params <> nil) and
    (Length(AInstr.Operands) <> LongInt(Callee.Params.Count)) then
    raise Exception.Create('call-signature-mismatch:' + AInstr.CallTarget +
      ' formals=' + IntToStr(LongInt(Callee.Params.Count)) +
      ' args=' + IntToStr(Length(AInstr.Operands)));
  if LlvmType = 'void' then
    Op := '  call void ' + LlvmGlobalRef(AInstr.CallTarget) + '('
  else
    Op := '  ' + ValueRef(AInstr.ResultId) + ' = call ' + LlvmType +
      ' ' + LlvmGlobalRef(AInstr.CallTarget) + '(';
  for I := 0 to High(AInstr.Operands) do
  begin
    if I > 0 then
      Op := Op + ', ';
    FirstTy := ValueLlvmType(AInstr.Operands[I].ValueId, '');
    ArgTy := '';
    if AInstr.Operands[I].TypeId <> 0 then
      ArgTy := TypeToLlvm(AInstr.Operands[I].TypeId);
    if ArgTy = '' then
      ArgTy := FirstTy;
    if ArgTy = '' then
      ArgTy := 'i64';
    { Integer width only: match formal iN when both sides are integers. }
    if HaveCallee and (Callee.Params <> nil) and
      (I < LongInt(Callee.Params.Count)) then
    begin
      FormalTy := TypeToLlvm(Callee.Params[SizeUInt(I)].TypeId);
      if (FormalTy <> '') and (Copy(FormalTy, 1, 1) = 'i') and
        (Copy(ArgTy, 1, 1) = 'i') then
        ArgTy := FormalTy;
    end;
    Op := Op + ArgTy + ' ' + EmitCastValueToLlvmType(
      AInstr.Operands[I].ValueId, ArgTy, 'callarg.' + IntToStr(AInstr.ResultId) +
      '.' + IntToStr(I), FirstTy);
  end;
  Op := Op + ')';
  Emit(Op);
  if (AInstr.ResultId <> 0) and (LlvmType <> 'void') then
    NoteValueLlvmType(AInstr.ResultId, LlvmType);
end;

procedure THIRLlvmEmitter.ClosePendingObjectFreeGuard;
begin
  if not FPendingObjectFreeActive then
    Exit;
  Emit('  br label %' + FPendingObjectFreeEndLabel);
  Emit(FPendingObjectFreeEndLabel + ':');
  FPendingObjectFreeActive := False;
  FPendingObjectFreeReceiverValueId := 0;
  FPendingObjectFreeDestroyTarget := '';
  FPendingObjectFreeEndLabel := '';
end;

function THIRLlvmEmitter.IsObjectFreeGuardContinuation(
  const AInstr: THIRInstr): Boolean;
begin
  if (not AInstr.HasSystemContract) or (AInstr.Kind <> hikIntrinsic) then
    Exit(False);
  case AInstr.SystemContractKind of
    sckObjectFreeDestroy,
    sckObjectFreeCleanup,
    sckObjectFreeRelease:
      Result := True;
  else
    Result := False;
  end;
end;

function THIRLlvmEmitter.EmitSystemContractInstr(
  const AInstr: THIRInstr): Boolean;
var
  ValidationError: string;
begin
  if not AInstr.HasSystemContract then
    Exit(False);
  if not ValidateSystemContractInstr(AInstr, FModule.Types,
    ValidationError) then
    raise Exception.Create(ValidationError);
  if FPendingObjectFreeActive and not IsObjectFreeGuardContinuation(AInstr) then
    ClosePendingObjectFreeGuard;
  case AInstr.SystemContractKind of
    sckObjectFreeDestroy,
    sckObjectFreeCleanup,
    sckObjectFreeRelease:
      if not FPendingObjectFreeActive then
        raise Exception.Create('system-contract-sequence-root-missing:' +
          IntToStr(Ord(AInstr.SystemContractKind)))
      else if not ValidateObjectFreeSequenceContinuation(
        FPendingObjectFreeReceiverValueId,
        AInstr.Operands[0].ValueId, FPendingObjectFreeDestroyTarget,
        AInstr.CallTarget, AInstr.SystemContractKind,
        ValidationError) then
        raise Exception.Create(ValidationError);
  else
    ;
  end;
  case AInstr.SystemContractKind of
    sckProcessInit:
    begin
      FNeedsProcessLifecycle := True;
      if AInstr.CallTarget <> '' then
        Emit('  call void ' + LlvmGlobalRef(AInstr.CallTarget) + '()')
      else
        Emit('  call void @' +
          SystemContractAt(sckProcessInit).RuntimeMapping + '()');
      if not FUnitInitCallsEmitted then
      begin
        EmitUnitInitCalls;
        FUnitInitCallsEmitted := True;
      end;
    end;
    sckProcessFini:
    begin
      FNeedsProcessLifecycle := True;
      if not FProcessFiniEmitted then
      begin
        if not FUnitFiniCallsEmitted then
        begin
          EmitUnitFiniCalls;
          FUnitFiniCallsEmitted := True;
        end;
        if AInstr.CallTarget <> '' then
          Emit('  call void ' + LlvmGlobalRef(AInstr.CallTarget) + '()')
        else
          Emit('  call void @' +
            SystemContractAt(sckProcessFini).RuntimeMapping + '()');
        FProcessFiniEmitted := True;
      end;
    end;
    sckStringInit:
    begin
      FNeedsTStringRuntime := True;
      if Length(AInstr.Operands) >= 1 then
      begin
        if AInstr.CallTarget <> '' then
          Emit('  call void ' + LlvmGlobalRef(AInstr.CallTarget) + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')')
        else
          Emit('  call void @' +
            SystemContractAt(sckStringInit).RuntimeMapping + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end;
    end;
    sckStringFini:
    begin
      FNeedsTStringRuntime := True;
      if Length(AInstr.Operands) >= 1 then
      begin
        if AInstr.CallTarget <> '' then
          Emit('  call void ' + LlvmGlobalRef(AInstr.CallTarget) + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')')
        else
          Emit('  call void @' +
            SystemContractAt(sckStringFini).RuntimeMapping + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end;
    end;
    sckStringAssign:
    begin
      FNeedsTStringRuntime := True;
      if Length(AInstr.Operands) >= 2 then
      begin
        if AInstr.CallTarget <> '' then
          Emit('  call void ' + LlvmGlobalRef(AInstr.CallTarget) + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ')')
        else
          Emit('  call void @' +
            SystemContractAt(sckStringAssign).RuntimeMapping + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ')');
      end;
    end;
    sckDynArraySetLength:
    begin
      { ABI: ptr, i64 old_len, i64 new_len, i64 elem_size.
        HIR often keeps len as i32 and elem_size as small int — cast at call. }
      FNeedsAlloc := True;
      FNeedsFree := True;
      FNeedsMemcpy := True;
      FNeedsDynArrayHelpers := True;
      if Length(AInstr.Operands) >= 4 then
      begin
        if AInstr.CallTarget <> '' then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call ptr ' + LlvmGlobalRef(AInstr.CallTarget) + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, 'i64',
              'dynset.old.' + IntToStr(AInstr.ResultId)) + ', i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[2].ValueId, 'i64',
              'dynset.new.' + IntToStr(AInstr.ResultId)) + ', i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[3].ValueId, 'i64',
              'dynset.esz.' + IntToStr(AInstr.ResultId)) + ')')
        else
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call ptr @' +
            SystemContractAt(sckDynArraySetLength).RuntimeMapping + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, 'i64',
              'dynset.old.' + IntToStr(AInstr.ResultId)) + ', i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[2].ValueId, 'i64',
              'dynset.new.' + IntToStr(AInstr.ResultId)) + ', i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[3].ValueId, 'i64',
              'dynset.esz.' + IntToStr(AInstr.ResultId)) + ')');
      end;
    end;
    sckDynArrayFini:
    begin
      { ABI: ptr, i64 len, i64 elem_size — widen small ints before call. }
      FNeedsAlloc := True;
      FNeedsFree := True;
      FNeedsDynArrayHelpers := True;
      if Length(AInstr.Operands) >= 3 then
      begin
        if AInstr.CallTarget <> '' then
          Emit('  call void ' + LlvmGlobalRef(AInstr.CallTarget) + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, 'i64',
              'dynfini.len.' + IntToStr(AInstr.Operands[0].ValueId)) + ', i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[2].ValueId, 'i64',
              'dynfini.esz.' + IntToStr(AInstr.Operands[0].ValueId)) + ')')
        else
          Emit('  call void @' +
            SystemContractAt(sckDynArrayFini).RuntimeMapping + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[1].ValueId, 'i64',
              'dynfini.len.' + IntToStr(AInstr.Operands[0].ValueId)) + ', i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[2].ValueId, 'i64',
              'dynfini.esz.' + IntToStr(AInstr.Operands[0].ValueId)) + ')');
      end;
    end;
    sckInterfaceAddRef:
    begin
      FNeedsIntfRefCountHelpers := True;
      if Length(AInstr.Operands) >= 1 then
      begin
        if AInstr.CallTarget <> '' then
          Emit('  call void ' + LlvmGlobalRef(AInstr.CallTarget) + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')')
        else
          Emit('  call void @' +
            SystemContractAt(sckInterfaceAddRef).RuntimeMapping + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end;
    end;
    sckInterfaceRelease:
    begin
      FNeedsIntfRefCountHelpers := True;
      if Length(AInstr.Operands) >= 1 then
      begin
        if AInstr.CallTarget <> '' then
          Emit('  call void ' + LlvmGlobalRef(AInstr.CallTarget) + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')')
        else
          Emit('  call void @' +
            SystemContractAt(sckInterfaceRelease).RuntimeMapping + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end;
    end;
    sckHalt:
    begin
      { Typed halt: inject process_fini once, then backend-private syscall. }
      if FNeedsProcessLifecycle and not FProcessFiniEmitted then
      begin
        if not FUnitFiniCallsEmitted then
        begin
          EmitUnitFiniCalls;
          FUnitFiniCallsEmitted := True;
        end;
        Emit('  call void @np_process_fini()');
        FProcessFiniEmitted := True;
      end;
      if AInstr.CallTarget <> '' then
        Emit('  call void asm sideeffect "movq $$60, %rax; syscall",' +
          ' "{rdi},~{rax},~{rcx},~{r11}"(i64 ' + AInstr.CallTarget + ')')
      else if Length(AInstr.Operands) >= 1 then
        Emit('  call void asm sideeffect "movq $$60, %rax; syscall",' +
          ' "{rdi},~{rax},~{rcx},~{r11}"(i64 ' +
          ValueRef(AInstr.Operands[0].ValueId) + ')');
    end;
    sckHeapAlloc:
    begin
      FNeedsAlloc := True;
      if Length(AInstr.Operands) >= 1 then
      begin
        if AInstr.CallTarget <> '' then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = call ptr ' +
            LlvmGlobalRef(AInstr.CallTarget) + '(i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, 'i64',
              'heapalloc.' + IntToStr(AInstr.ResultId)) + ')')
        else
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = call ptr ' +
            LlvmGlobalRef(SystemContractAt(sckHeapAlloc).RuntimeMapping) +
            '(i64 ' +
            EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, 'i64',
              'heapalloc.' + IntToStr(AInstr.ResultId)) + ')');
      end;
    end;
    sckObjectAlloc:
    begin
      { Typed class instance alloc: byte size → @np_object_alloc. }
      FNeedsAlloc := True;
      FNeedsObjectAlloc := True;
      if Length(AInstr.Operands) >= 1 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = call ptr ' +
          LlvmGlobalRef(SystemContractAt(sckObjectAlloc).RuntimeMapping) +
          '(i64 ' +
          EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, 'i64',
            'objalloc.' + IntToStr(AInstr.ResultId)) + ')');
    end;
    sckHeapFree:
    begin
      FNeedsFree := True;
      if Length(AInstr.Operands) >= 1 then
      begin
        if AInstr.CallTarget <> '' then
          Emit('  call void ' + LlvmGlobalRef(AInstr.CallTarget) + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 0)')
        else
          Emit('  call void @' +
            SystemContractAt(sckHeapFree).RuntimeMapping + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 0)');
      end;
    end;
    sckExceptionTryPush:
    begin
      { Typed try frame: alloca jmpbuf + push + setjmp branch.
        Handler label is CallTarget (bbN); empty → synthetic try.exc.N. }
      FNeedsExceptionRuntime := True;
      Inc(FTryCounter);
      Emit('  ; --- try begin ---');
      Emit('  %jmpbuf.' + IntToStr(FTryCounter) + ' = alloca [9 x ptr]');
      Emit('  call void @' +
        SystemContractAt(sckExceptionTryPush).RuntimeMapping +
        '(ptr %jmpbuf.' + IntToStr(FTryCounter) + ')');
      Emit('  %setjmp.' + IntToStr(FTryCounter) +
        ' = call i32 @setjmp(ptr %jmpbuf.' + IntToStr(FTryCounter) + ')');
      Emit('  %is_exc.' + IntToStr(FTryCounter) + ' = icmp ne i32 %setjmp.' +
        IntToStr(FTryCounter) + ', 0');
      if AInstr.CallTarget <> '' then
        Emit('  br i1 %is_exc.' + IntToStr(FTryCounter) + ', label %' +
          Trim(AInstr.CallTarget) + ', label %try.body.' +
          IntToStr(FTryCounter))
      else
        Emit('  br i1 %is_exc.' + IntToStr(FTryCounter) +
          ', label %try.exc.' + IntToStr(FTryCounter) +
          ', label %try.body.' + IntToStr(FTryCounter));
      Emit('try.body.' + IntToStr(FTryCounter) + ':');
    end;
    sckExceptionTryPop:
    begin
      Emit('  ; --- try end ---');
      Emit('  call void @' +
        SystemContractAt(sckExceptionTryPop).RuntimeMapping + '()');
    end;
    sckExceptionFinallyEnd:
    begin
      Emit('  ; --- finally end ---');
      Emit('  call void @' +
        SystemContractAt(sckExceptionFinallyEnd).RuntimeMapping + '()');
    end;
    sckExceptionExceptEnd:
    begin
      Emit('  ; --- except end ---');
      Emit('  call void @' +
        SystemContractAt(sckExceptionExceptEnd).RuntimeMapping + '()');
    end;
    sckExceptionRaise:
    begin
      FNeedsExceptionRuntime := True;
      Emit('  call void @' +
        SystemContractAt(sckExceptionRaise).RuntimeMapping + '()');
      Emit('  unreachable');
    end;
    sckObjectFree:
      EmitObjectFreeGuardStart(AInstr);
    sckObjectFreeDestroy:
      EmitObjectFreeOwnedDestroy(AInstr);
    sckObjectFreeCleanup:
      Emit('  call void ' + LlvmGlobalRef(AInstr.CallTarget) + '(ptr ' +
        ValueRef(AInstr.Operands[0].ValueId) + ')');
    sckObjectFreeRelease:
      EmitObjectFreeRelease(AInstr);
    sckManagedRecordFini:
      { Marker only: nested sckStringFini / sckDynArrayFini do the work. }
      Emit('  ; --- managed-record-fini (compiler-planned field cleanup) ---');
  else
    raise Exception.Create('Unsupported typed System contract kind: ' +
      IntToStr(Ord(AInstr.SystemContractKind)));
  end;
  Result := True;
end;

procedure THIRLlvmEmitter.EmitObjectFreeGuardStart(const AInstr: THIRInstr);
var
  CounterText: string;
  DestroyLabel: string;
begin
  Inc(FObjectFreeCounter);
  CounterText := IntToStr(FObjectFreeCounter);
  DestroyLabel := 'objectfree.destroy.' + CounterText;
  FPendingObjectFreeEndLabel := 'objectfree.end.' + CounterText;
  Emit('  %objectfree.isnull.' + CounterText + ' = icmp eq ptr ' +
    ValueRef(AInstr.Operands[0].ValueId) + ', null');
  Emit('  br i1 %objectfree.isnull.' + CounterText + ', label %' +
    FPendingObjectFreeEndLabel + ', label %' + DestroyLabel);
  Emit(DestroyLabel + ':');
  FPendingObjectFreeReceiverValueId := AInstr.Operands[0].ValueId;
  FPendingObjectFreeDestroyTarget := AInstr.CallTarget;
  FPendingObjectFreeActive := True;
end;

procedure THIRLlvmEmitter.EmitObjectFreeOwnedDestroy(const AInstr: THIRInstr);
begin
  EmitCallInstr(AInstr);
end;

procedure THIRLlvmEmitter.EmitObjectFreeRelease(const AInstr: THIRInstr);
begin
  FNeedsAlloc := True;
  FNeedsFree := True;
  FNeedsObjectFreeRelease := True;
  Emit('  call void @np_object_free_release(ptr ' +
    ValueRef(AInstr.Operands[0].ValueId) + ')');
  ClosePendingObjectFreeGuard;
end;

procedure THIRLlvmEmitter.EmitIndirectCallInstr(const AInstr: THIRInstr);
var
  I: LongInt;
  LlvmType, Op, ArgTy, CalleeRef, CalleeTy: string;
begin
  if Length(AInstr.Operands) < 1 then
    Exit;
  LlvmType := TypeToLlvm(AInstr.TypeId);
  if (LlvmType = '') or (LlvmType = 'void') then
    if AInstr.ResultId <> 0 then
      LlvmType := 'i64';
  CalleeTy := '';
  if AInstr.Operands[0].TypeId <> 0 then
    CalleeTy := TypeToLlvm(AInstr.Operands[0].TypeId);
  if CalleeTy = '' then
    CalleeTy := ValueLlvmType(AInstr.Operands[0].ValueId, 'i64');
  if CalleeTy = 'ptr' then
    CalleeRef := ValueRef(AInstr.Operands[0].ValueId)
  else
  begin
    { Function pointers may land as i64 formals; coerce to ptr before call. }
    CalleeRef := EmitCastValueToLlvmType(AInstr.Operands[0].ValueId, 'ptr',
      'indcall.fp.' + IntToStr(AInstr.ResultId));
  end;
  if AInstr.ResultId <> 0 then
    Op := '  ' + ValueRef(AInstr.ResultId) + ' = call ' + LlvmType + ' ' +
      CalleeRef + '('
  else
    Op := '  call void ' + CalleeRef + '(';
  for I := 1 to High(AInstr.Operands) do
  begin
    if I > 1 then
      Op := Op + ', ';
    if AInstr.Operands[I].TypeId <> 0 then
      ArgTy := TypeToLlvm(AInstr.Operands[I].TypeId)
    else
      ArgTy := ValueLlvmType(AInstr.Operands[I].ValueId, 'i64');
    if ArgTy = '' then
      ArgTy := 'i64';
    Op := Op + ArgTy + ' ' + EmitCastValueToLlvmType(
      AInstr.Operands[I].ValueId, ArgTy,
      'indcall.arg.' + IntToStr(AInstr.ResultId) + '.' + IntToStr(I));
  end;
  Op := Op + ')';
  if AInstr.CallTarget <> '' then
    Op := Op + ' ; indirect ' + AInstr.CallTarget;
  Emit(Op);
  if AInstr.ResultId <> 0 then
    NoteValueLlvmType(AInstr.ResultId, LlvmType);
end;
