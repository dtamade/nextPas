
uses
  nextpas.core.text.conv, nextpas.core.system.contracts;

const
  NP_ALLOCATOR_PAGE_SIZE = 4096;
  NP_ALLOCATOR_PRELUDE_SIZE = 16;
  NP_ALLOCATOR_MIN_SMALL_BLOCK_SIZE = 24;
  NP_ALLOCATOR_LARGE_THRESHOLD = 65536;
  NP_ALLOCATOR_LARGE_MAGIC = '131388245100000016';

constructor THIRLlvmEmitter.Create(AModule: THIRModule);
begin
  Create(AModule, DEFAULT_LLVM_TRIPLE, DEFAULT_LLVM_DATALAYOUT, False);
end;

constructor THIRLlvmEmitter.Create(AModule: THIRModule;
  const ALlvmTriple, ALlvmDataLayout: string; ADebugInfo: Boolean);
begin
  inherited Create;
  FModule := AModule;
  { 从参数读取，如果为空则使用 x86_64-linux 默认值 }
  if ALlvmTriple <> '' then
    FLlvmTriple := ALlvmTriple
  else
    FLlvmTriple := 'x86_64-unknown-linux-gnu';
  if ALlvmDataLayout <> '' then
    FLlvmDataLayout := ALlvmDataLayout
  else
    FLlvmDataLayout := 'e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64';
  FLineCount := 0;
  FGlobalRefCount := 0;
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
  FPendingObjectFreeEndLabel := '';
  FNeedsExceptionRuntime := False;
  FNeedsProcessLifecycle := False;
  FProcessFiniEmitted := False;
  FTryCounter := 0;
  FDebugInfoEnabled := ADebugInfo;
  FDebugMetadataCount := 0;
  FCurrentDISubprogram := -1;
  FDIFileIndex := -1;
  FDICUIndex := -1;
  SetLength(FLines, 0);
end;

procedure THIRLlvmEmitter.Emit(const S: string);
begin
  if FLineCount >= Length(FLines) then
    SetLength(FLines, FLineCount + 128);
  FLines[FLineCount] := S;
  Inc(FLineCount);
end;

function THIRLlvmEmitter.AddDebugMetadata(const AMetadata: string): LongInt;
begin
  if FDebugMetadataCount >= Length(FDebugMetadata) then
    SetLength(FDebugMetadata, FDebugMetadataCount + 32);
  FDebugMetadata[FDebugMetadataCount] := AMetadata;
  Result := FDebugMetadataCount;
  Inc(FDebugMetadataCount);
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
  I: LongInt;
begin
  if FDebugMetadataCount = 0 then
    Exit;
  Emit('');
  for I := 0 to FDebugMetadataCount - 1 do
    Emit('!' + IntToStr(I) + ' = ' + FDebugMetadata[I]);
end;

function THIRLlvmEmitter.ValueRef(AValueId: THIRValueId): string;
var
  I: LongInt;
begin
  for I := 0 to FGlobalRefCount - 1 do
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
  if Length(ABlock.Instrs) = 0 then
    Exit;
  LastInstr := ABlock.Instrs[High(ABlock.Instrs)];
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
    Result := AFallback;
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
  LlvmType, Op: string;
  IsTStringSret: Boolean;
begin
  LlvmType := TypeToLlvm(AInstr.TypeId);
  IsTStringSret := IsTStringSretFunction(AInstr.CallTarget);
  if IsSretFunction(AInstr.CallTarget) or IsTStringSret then
    Op := '  call void @' + AInstr.CallTarget + '('
  else if LlvmType = 'void' then
    Op := '  call void @' + AInstr.CallTarget + '('
  else
    Op := '  ' + ValueRef(AInstr.ResultId) + ' = call ' + LlvmType +
      ' @' + AInstr.CallTarget + '(';
  for I := 0 to High(AInstr.Operands) do
  begin
    if I > 0 then Op := Op + ', ';
    { First operand of TString sret call gets sret(%TString) annotation }
    if IsTStringSret and (I = 0) then
      Op := Op + 'ptr sret(%TString) '
    else if AInstr.Operands[I].TypeId <> 0 then
      Op := Op + TypeToLlvm(AInstr.Operands[I].TypeId) + ' '
    else
      Op := Op + 'i64 ';
    Op := Op + ValueRef(AInstr.Operands[I].ValueId);
  end;
  Op := Op + ')';
  Emit(Op);
end;

procedure THIRLlvmEmitter.ClosePendingObjectFreeGuard;
begin
  if not FPendingObjectFreeActive then
    Exit;
  Emit('  br label %' + FPendingObjectFreeEndLabel);
  Emit(FPendingObjectFreeEndLabel + ':');
  FPendingObjectFreeActive := False;
  FPendingObjectFreeEndLabel := '';
end;

procedure THIRLlvmEmitter.EmitObjectFreeGuardStart(const AInstr: THIRInstr);
var
  CounterText: string;
  DestroyLabel: string;
begin
  if Length(AInstr.Operands) < 1 then
    Exit;

  Inc(FObjectFreeCounter);
  CounterText := IntToStr(FObjectFreeCounter);
  DestroyLabel := 'objectfree.destroy.' + CounterText;
  FPendingObjectFreeEndLabel := 'objectfree.end.' + CounterText;
  Emit('  %objectfree.isnull.' + CounterText + ' = icmp eq ptr ' +
    ValueRef(AInstr.Operands[0].ValueId) + ', null');
  Emit('  br i1 %objectfree.isnull.' + CounterText + ', label %' +
    FPendingObjectFreeEndLabel + ', label %' + DestroyLabel);
  Emit(DestroyLabel + ':');
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
  if Length(AInstr.Operands) >= 1 then
    Emit('  call void @np_object_free_release(ptr ' +
      ValueRef(AInstr.Operands[0].ValueId) + ')');
  ClosePendingObjectFreeGuard;
end;

