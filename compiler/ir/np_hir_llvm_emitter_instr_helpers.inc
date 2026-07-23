
uses
  SysUtils, nextpas.core.text.conv, np_system_contracts;

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

function THIRLlvmEmitter.EmitCastValueToLlvmType(AValueId: THIRValueId;
  const AWantedTy, ATag: string): string;
var
  HaveTy: string;
  CastName: string;
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
  HaveTy := ValueLlvmType(AValueId, AWantedTy);
  if (HaveTy = '') or (HaveTy = AWantedTy) then
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
  LlvmType, Op, SretRef, FirstTy, ArgTy: string;
  IsTStringSret: Boolean;
  NeedSretInject: Boolean;
begin
  LlvmType := TypeToLlvm(AInstr.TypeId);
  if (LlvmType = '') or (LlvmType = 'void') then
    if AInstr.ResultId <> 0 then
      LlvmType := 'i64';
  IsTStringSret := IsTStringSretFunction(AInstr.CallTarget);
  SretRef := '';
  NeedSretInject := False;
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
    Op := '  call void @' + AInstr.CallTarget + '(ptr sret(%TString) ' + SretRef;
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
      Op := Op + ArgTy + ' ' + ValueRef(AInstr.Operands[I].ValueId);
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
  if IsSretFunction(AInstr.CallTarget) then
    Op := '  call void @' + AInstr.CallTarget + '('
  else if LlvmType = 'void' then
    Op := '  call void @' + AInstr.CallTarget + '('
  else
    Op := '  ' + ValueRef(AInstr.ResultId) + ' = call ' + LlvmType +
      ' @' + AInstr.CallTarget + '(';
  for I := 0 to High(AInstr.Operands) do
  begin
    if I > 0 then Op := Op + ', ';
    if AInstr.Operands[I].TypeId <> 0 then
      Op := Op + TypeToLlvm(AInstr.Operands[I].TypeId) + ' '
    else
      Op := Op + 'i64 ';
    Op := Op + ValueRef(AInstr.Operands[I].ValueId);
  end;
  Op := Op + ')';
  Emit(Op);
  if (AInstr.ResultId <> 0) and (not IsSretFunction(AInstr.CallTarget)) and
    (LlvmType <> 'void') then
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
        Emit('  call void @' + AInstr.CallTarget + '()')
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
          Emit('  call void @' + AInstr.CallTarget + '()')
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
          Emit('  call void @' + AInstr.CallTarget + '(ptr ' +
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
          Emit('  call void @' + AInstr.CallTarget + '(ptr ' +
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
          Emit('  call void @' + AInstr.CallTarget + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ')')
        else
          Emit('  call void @' +
            SystemContractAt(sckStringAssign).RuntimeMapping + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ')');
      end;
    end;
    sckObjectFree:
      EmitObjectFreeGuardStart(AInstr);
    sckObjectFreeDestroy:
      EmitObjectFreeOwnedDestroy(AInstr);
    sckObjectFreeCleanup:
      Emit('  call void @' + AInstr.CallTarget + '(ptr ' +
        ValueRef(AInstr.Operands[0].ValueId) + ')');
    sckObjectFreeRelease:
      EmitObjectFreeRelease(AInstr);
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
