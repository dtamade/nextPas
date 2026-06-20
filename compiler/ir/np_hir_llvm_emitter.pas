unit np_hir_llvm_emitter;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  np_hir_types, np_hir_model;

const
  { 默认目标元数据 —— 仅当 emitter 未被注入 target facts 时回退使用，
    保持旧调用方（无参构造）行为等价于历史硬编码值。 }
  DEFAULT_LLVM_TRIPLE = 'x86_64-unknown-linux-gnu';
  DEFAULT_LLVM_DATALAYOUT =
    'e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64';

type
  THIRLlvmEmitter = class
  private
    FModule: THIRModule;
    FLlvmTriple: string;
    FLlvmDataLayout: string;
    FLines: array of string;
    FLineCount: LongInt;
    FGlobalRefNames: array of string;
    FGlobalRefIds: array of THIRValueId;
    FGlobalRefCount: LongInt;
    FNeedsWriteInt: Boolean;
    FNeedsAlloc: Boolean;
    FNeedsFree: Boolean;
    FNeedsMemcpy: Boolean;
    FNeedsMemset: Boolean;
    FNeedsMemmove: Boolean;
    FNeedsStrConcat: Boolean;
    FNeedsStringOwnership: Boolean;
    FNeedsTStringRuntime: Boolean;
    FNeedsStrCmp: Boolean;
    FNeedsIntToStr: Boolean;
    FNeedsObjectAlloc: Boolean;
    FNeedsObjectFreeRelease: Boolean;
    FNeedsDynArrayHelpers: Boolean;
    FStrConstants: array of string;
    FStrConstCount: LongInt;
    FCurrentReturnTypeId: THIRTypeId;
    FIsCheckCounter: LongInt;
    FObjectFreeCounter: LongInt;
    FPendingObjectFreeActive: Boolean;
    FPendingObjectFreeEndLabel: string;
    FNeedsExceptionRuntime: Boolean;
    FNeedsProcessLifecycle: Boolean;
    FProcessFiniEmitted: Boolean;
    FUnitInitCallsEmitted: Boolean;
    FUnitFiniCallsEmitted: Boolean;
    FTryCounter: LongInt;
    procedure Emit(const S: string);
    function ValueRef(AValueId: THIRValueId): string;
    function TypeToLlvm(ATypeId: THIRTypeId): string;
    function BlockEndsWithIntrinsicReturn(const ABlock: THIRBlock): Boolean;
    function OperandTypeToLlvm(const AOperand: THIROperand;
      const AFallback: string): string;
    function IsUnsignedIntegerType(const ATypeId: THIRTypeId): Boolean;
    function IsUnsignedOrderedCompareType(const ATypeId: THIRTypeId): Boolean;
    function DivOpcodeToLlvm(const AInstr: THIRInstr): string;
    function ModOpcodeToLlvm(const AInstr: THIRInstr): string;
    function CompareOpcodeToLlvm(const AInstr: THIRInstr): string;
    function AddStrConstant(const AValue: string): LongInt;
    function EscapeLlvmStr(const AValue: string): string;
    function IsSretFunction(const AName: string): Boolean;
    procedure EmitFunction(const AFunc: THIRFunction);
    procedure EmitCallInstr(const AInstr: THIRInstr);
    procedure ClosePendingObjectFreeGuard;
    procedure EmitObjectFreeGuardStart(const AInstr: THIRInstr);
    procedure EmitObjectFreeOwnedDestroy(const AInstr: THIRInstr);
    procedure EmitObjectFreeRelease(const AInstr: THIRInstr);
    procedure EmitInstr(const AInstr: THIRInstr);
    procedure EmitTerminator(const ATerm: THIRTerminator);
    procedure EmitWriteIntHelper;
    procedure EmitStrConstants;
    procedure EmitAllocHelper;
    procedure EmitMemcpyHelper;
    procedure EmitMemzeroHelper;
    procedure EmitStrConcatHelper;
    procedure EmitStringOwnershipHelpers;
    procedure EmitTStringHelpers;
    procedure EmitDynArrayHelpers;
    procedure EmitObjectAllocHelper;
    procedure EmitObjectFreeReleaseHelper;
    procedure EmitIntfRefCountHelpers;
    procedure EmitObjectReleaseValidHelper;
    procedure EmitFreeHelper;
    procedure EmitObjectReleaseInvalidHelper;
    procedure EmitAllocatorFaultHelper;
    procedure EmitExceptionRuntimeHelpers;
    procedure EmitVmtGlobals;
    procedure EmitImtGlobals;
    procedure EmitUnitInitCalls;
    procedure EmitUnitFiniCalls;
  public
    constructor Create(AModule: THIRModule); overload;
    constructor Create(AModule: THIRModule;
      const ALlvmTriple, ALlvmDataLayout: string); overload;
    procedure EmitModule;
    function AsText: string;
    procedure SaveToFile(const APath: string);
  end;

implementation

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
  Create(AModule, DEFAULT_LLVM_TRIPLE, DEFAULT_LLVM_DATALAYOUT);
end;

constructor THIRLlvmEmitter.Create(AModule: THIRModule;
  const ALlvmTriple, ALlvmDataLayout: string);
begin
  inherited Create;
  FModule := AModule;
  if ALlvmTriple <> '' then
    FLlvmTriple := ALlvmTriple
  else
    FLlvmTriple := DEFAULT_LLVM_TRIPLE;
  if ALlvmDataLayout <> '' then
    FLlvmDataLayout := ALlvmDataLayout
  else
    FLlvmDataLayout := DEFAULT_LLVM_DATALAYOUT;
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
  SetLength(FLines, 0);
end;

procedure THIRLlvmEmitter.Emit(const S: string);
begin
  if FLineCount >= Length(FLines) then
    SetLength(FLines, FLineCount + 128);
  FLines[FLineCount] := S;
  Inc(FLineCount);
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
    htkInt: Result := 'i' + IntToStr(T.BitWidth);
    htkFloat:
      case T.FloatWidth of
        fwF32: Result := 'float';
        fwF64: Result := 'double';
        fwF80: Result := 'x86_fp80';
      end;
    htkPointer, htkUntypedPtr: Result := 'ptr';
    htkString: Result := 'ptr';
  else
    Result := 'i64';
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
begin
  LlvmType := TypeToLlvm(AInstr.TypeId);
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
      Op := Op + TypeToLlvm(AInstr.Operands[I].TypeId) + ' ' +
        ValueRef(AInstr.Operands[I].ValueId)
    else
      Op := Op + 'i64 ' + ValueRef(AInstr.Operands[I].ValueId);
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

procedure THIRLlvmEmitter.EmitInstr(const AInstr: THIRInstr);
var
  LlvmType, Op: string;
  I: LongInt;
begin
  if FPendingObjectFreeActive and not ((AInstr.Kind = hikIntrinsic) and
    (SameText(AInstr.IntrinsicName, NPSYSTEM_OBJECT_FREE_DESTROY) or
    SameText(AInstr.IntrinsicName, NPSYSTEM_OBJECT_FREE_CLEANUP) or
    SameText(AInstr.IntrinsicName, NPSYSTEM_OBJECT_FREE_RELEASE))) then
    ClosePendingObjectFreeGuard;

  LlvmType := TypeToLlvm(AInstr.TypeId);

  case AInstr.Kind of
    hikAlloca:
    begin
      if (AInstr.IntrinsicName <> '') and
        (Copy(AInstr.IntrinsicName, 1, 7) = 'record:') then
      begin
        Op := '  ' + ValueRef(AInstr.ResultId) + ' = alloca [' +
          Copy(AInstr.IntrinsicName, 8, Length(AInstr.IntrinsicName)) +
          ' x i64]';
        if AInstr.CallTarget <> '' then
          Op := Op + ' ; ' + AInstr.CallTarget;
        Emit(Op);
      end
      else if AInstr.IntrinsicName = 'tstring' then
      begin
        FNeedsTStringRuntime := True;
        Op := '  ' + ValueRef(AInstr.ResultId) + ' = alloca [24 x i8], align 8';
        if AInstr.CallTarget <> '' then
          Op := Op + ' ; ' + AInstr.CallTarget;
        Emit(Op);
      end
      else
      begin
        Op := '  ' + ValueRef(AInstr.ResultId) + ' = alloca ' + LlvmType;
        if AInstr.CallTarget <> '' then
          Op := Op + ' ; ' + AInstr.CallTarget;
        Emit(Op);
      end;
    end;
    hikLoad:
    begin
      if AInstr.IntrinsicName <> '' then
      begin
        if Copy(AInstr.IntrinsicName, 1, 6) = 'const:' then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = add ' + LlvmType +
            ' ' + Copy(AInstr.IntrinsicName, 7, Length(AInstr.IntrinsicName)) + ', 0')
        else if AInstr.IntrinsicName = 'null' then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = inttoptr i64 0 to ptr')
        else if Length(AInstr.Operands) > 0 then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = load ' + LlvmType +
            ', ptr ' + ValueRef(AInstr.Operands[0].ValueId))
        else
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = load ' + LlvmType + ', ptr null');
      end
      else if Length(AInstr.Operands) > 0 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = load ' + LlvmType +
          ', ptr ' + ValueRef(AInstr.Operands[0].ValueId))
      else
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = load ' + LlvmType + ', ptr null');
    end;
    hikStore:
      if Length(AInstr.Operands) >= 2 then
        Emit('  store ' + LlvmType + ' ' + ValueRef(AInstr.Operands[0].ValueId) +
          ', ptr ' + ValueRef(AInstr.Operands[1].ValueId));
    hikAdd:
      if Length(AInstr.Operands) >= 2 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = add ' + LlvmType +
          ' ' + ValueRef(AInstr.Operands[0].ValueId) +
          ', ' + ValueRef(AInstr.Operands[1].ValueId));
    hikSub:
      if Length(AInstr.Operands) >= 2 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = sub ' + LlvmType +
          ' ' + ValueRef(AInstr.Operands[0].ValueId) +
          ', ' + ValueRef(AInstr.Operands[1].ValueId));
    hikMul:
      if Length(AInstr.Operands) >= 2 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = mul ' + LlvmType +
          ' ' + ValueRef(AInstr.Operands[0].ValueId) +
          ', ' + ValueRef(AInstr.Operands[1].ValueId));
    hikDiv:
      if Length(AInstr.Operands) >= 2 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = ' +
          DivOpcodeToLlvm(AInstr) + ' ' + LlvmType +
          ' ' + ValueRef(AInstr.Operands[0].ValueId) +
          ', ' + ValueRef(AInstr.Operands[1].ValueId));
    hikMod:
      if Length(AInstr.Operands) >= 2 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = ' +
          ModOpcodeToLlvm(AInstr) + ' ' + LlvmType +
          ' ' + ValueRef(AInstr.Operands[0].ValueId) +
          ', ' + ValueRef(AInstr.Operands[1].ValueId));
    hikNeg:
      if Length(AInstr.Operands) >= 1 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = sub ' + LlvmType +
          ' 0, ' + ValueRef(AInstr.Operands[0].ValueId));
    hikCmpEq, hikCmpNe, hikCmpLt, hikCmpLe, hikCmpGt, hikCmpGe:
    begin
      Op := CompareOpcodeToLlvm(AInstr);
      if Length(AInstr.Operands) >= 2 then
      begin
        LlvmType := OperandTypeToLlvm(AInstr.Operands[0], 'i64');
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = icmp ' + Op + ' ' +
          LlvmType + ' ' + ValueRef(AInstr.Operands[0].ValueId) +
          ', ' + ValueRef(AInstr.Operands[1].ValueId));
      end;
    end;
    hikTrunc:
      if Length(AInstr.Operands) >= 1 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = trunc ' +
          OperandTypeToLlvm(AInstr.Operands[0], 'i64') + ' ' +
          ValueRef(AInstr.Operands[0].ValueId) + ' to ' +
          TypeToLlvm(AInstr.TypeId));
    hikZext:
      if Length(AInstr.Operands) >= 1 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = zext ' +
          OperandTypeToLlvm(AInstr.Operands[0], 'i1') + ' ' +
          ValueRef(AInstr.Operands[0].ValueId) + ' to ' +
          TypeToLlvm(AInstr.TypeId));
    hikSext:
      if Length(AInstr.Operands) >= 1 then
        Emit('  ' + ValueRef(AInstr.ResultId) + ' = sext ' +
          OperandTypeToLlvm(AInstr.Operands[0], 'i64') + ' ' +
          ValueRef(AInstr.Operands[0].ValueId) + ' to ' +
          TypeToLlvm(AInstr.TypeId));
    hikCall:
    begin
      if AInstr.CallTarget = 'np_process_init' then
      begin
        FNeedsProcessLifecycle := True;
        EmitCallInstr(AInstr);
        // After process_init, emit unit init calls in topological order
        if not FUnitInitCallsEmitted then
        begin
          EmitUnitInitCalls;
          FUnitInitCallsEmitted := True;
        end;
      end
      else if AInstr.CallTarget = 'np_process_fini' then
      begin
        FNeedsProcessLifecycle := True;
        if FProcessFiniEmitted then
          Exit; // already emitted before halt syscall
        // Before process_fini, emit unit fini calls in reverse order
        if not FUnitFiniCallsEmitted then
        begin
          EmitUnitFiniCalls;
          FUnitFiniCallsEmitted := True;
        end;
        EmitCallInstr(AInstr);
      end
      else
        EmitCallInstr(AInstr);
    end;
    hikIntrinsic:
    begin
      if AInstr.IntrinsicName = 'halt' then
      begin
        if FNeedsProcessLifecycle and not FProcessFiniEmitted then
        begin
          // Emit unit fini calls in reverse order before process_fini
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
            ' "{rdi},~{rax},~{rcx},~{r11}"(i64 ' + ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if SameText(AInstr.IntrinsicName, NPSYSTEM_OBJECT_FREE) then
        EmitObjectFreeGuardStart(AInstr)
      else if SameText(AInstr.IntrinsicName, NPSYSTEM_OBJECT_FREE_DESTROY) then
        EmitObjectFreeOwnedDestroy(AInstr)
      else if SameText(AInstr.IntrinsicName, NPSYSTEM_OBJECT_FREE_CLEANUP) then
      begin
        if Length(AInstr.Operands) >= 1 then
          Emit('  call void @' + AInstr.CallTarget + '(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if SameText(AInstr.IntrinsicName, NPSYSTEM_OBJECT_FREE_RELEASE) then
        EmitObjectFreeRelease(AInstr)
      else if AInstr.IntrinsicName = 'write_int' then
      begin
        FNeedsWriteInt := True;
        if Length(AInstr.Operands) >= 1 then
          Emit('  call void @write_i64_decimal(i64 ' + ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'write_str' then
      begin
        I := AddStrConstant(AInstr.CallTarget);
        Emit('  call void asm sideeffect "movq $$1, %rax; syscall",' +
          ' "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr @.str.' +
          IntToStr(I) + ', i64 ' + IntToStr(Length(AInstr.CallTarget)) + ')');
      end
      else if AInstr.IntrinsicName = 'write_str_var' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Emit('  call void asm sideeffect "movq $$1, %rax; syscall",' +
            ' "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ')');
        end;
      end
      else if AInstr.IntrinsicName = 'store_str_lit' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          I := AddStrConstant(AInstr.CallTarget);
          Emit('  store ptr @.str.' + IntToStr(I) + ', ptr ' + ValueRef(AInstr.Operands[0].ValueId));
          Emit('  store i64 ' + IntToStr(Length(AInstr.CallTarget)) +
            ', ptr ' + ValueRef(AInstr.Operands[1].ValueId));
        end;
      end
      else if AInstr.IntrinsicName = 'call_str_func' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Op := '  %callstr.' + IntToStr(AInstr.ResultId) +
            ' = call {ptr, i64} @' + AInstr.CallTarget + '(';
          for I := 2 to High(AInstr.Operands) do
          begin
            if I > 2 then Op := Op + ', ';
            if AInstr.Operands[I].TypeId <> 0 then
              Op := Op + TypeToLlvm(AInstr.Operands[I].TypeId) + ' ' + ValueRef(AInstr.Operands[I].ValueId)
            else
              Op := Op + 'i64 ' + ValueRef(AInstr.Operands[I].ValueId);
          end;
          Op := Op + ')';
          Emit(Op);
          Emit('  %callstr.' + IntToStr(AInstr.ResultId) +
            '.p = extractvalue {ptr, i64} %callstr.' +
            IntToStr(AInstr.ResultId) + ', 0');
          Emit('  %callstr.' + IntToStr(AInstr.ResultId) +
            '.l = extractvalue {ptr, i64} %callstr.' +
            IntToStr(AInstr.ResultId) + ', 1');
          Emit('  store ptr %callstr.' + IntToStr(AInstr.ResultId) +
            '.p, ptr ' + ValueRef(AInstr.Operands[0].ValueId));
          Emit('  store i64 %callstr.' + IntToStr(AInstr.ResultId) +
            '.l, ptr ' + ValueRef(AInstr.Operands[1].ValueId));
        end;
      end
      else if AInstr.IntrinsicName = 'call_str_owned_func' then
      begin
        Op := '  ' + ValueRef(AInstr.ResultId) +
          ' = call {ptr, i64, ptr, i64} @' + AInstr.CallTarget + '(';
        for I := 0 to High(AInstr.Operands) do
        begin
          if I > 0 then Op := Op + ', ';
          if AInstr.Operands[I].TypeId <> 0 then
            Op := Op + TypeToLlvm(AInstr.Operands[I].TypeId) + ' ' +
              ValueRef(AInstr.Operands[I].ValueId)
          else
            Op := Op + 'i64 ' + ValueRef(AInstr.Operands[I].ValueId);
        end;
        Op := Op + ')';
        Emit(Op);
      end
      else if AInstr.IntrinsicName = 'str_concat' then
      begin
        FNeedsAlloc := True;
        FNeedsMemcpy := True;
        FNeedsStrConcat := True;
        if Length(AInstr.Operands) >= 6 then
        begin
          Emit('  %concat.' + IntToStr(AInstr.ResultId) +
            ' = call {ptr, i64} @np_str_concat(ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ', ptr ' + ValueRef(AInstr.Operands[2].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[3].ValueId) + ')');
          Emit('  %concat.' + IntToStr(AInstr.ResultId) +
            '.p = extractvalue {ptr, i64} %concat.' +
            IntToStr(AInstr.ResultId) + ', 0');
          Emit('  %concat.' + IntToStr(AInstr.ResultId) +
            '.l = extractvalue {ptr, i64} %concat.' +
            IntToStr(AInstr.ResultId) + ', 1');
          Emit('  store ptr %concat.' + IntToStr(AInstr.ResultId) +
            '.p, ptr ' + ValueRef(AInstr.Operands[4].ValueId));
          Emit('  store i64 %concat.' + IntToStr(AInstr.ResultId) +
            '.l, ptr ' + ValueRef(AInstr.Operands[5].ValueId));
        end;
      end
      else if AInstr.IntrinsicName = 'str_concat_owned' then
      begin
        FNeedsAlloc := True;
        FNeedsFree := True;
        FNeedsMemcpy := True;
        FNeedsStringOwnership := True;
        if Length(AInstr.Operands) >= 4 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call {ptr, i64, ptr, i64} @np_str_concat_owned(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[1].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[2].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[3].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'str_copy_owned' then
      begin
        FNeedsAlloc := True;
        FNeedsFree := True;
        FNeedsMemcpy := True;
        FNeedsStringOwnership := True;
        if Length(AInstr.Operands) >= 4 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call {ptr, i64, ptr, i64} @np_str_copy_owned(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[1].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[2].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[3].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'string_owned_extract_ptr' then
      begin
        if Length(AInstr.Operands) >= 1 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = extractvalue {ptr, i64, ptr, i64} ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', 0');
      end
      else if AInstr.IntrinsicName = 'string_owned_extract_len' then
      begin
        if Length(AInstr.Operands) >= 1 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = extractvalue {ptr, i64, ptr, i64} ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', 1');
      end
      else if AInstr.IntrinsicName = 'string_owned_extract_owner' then
      begin
        if Length(AInstr.Operands) >= 1 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = extractvalue {ptr, i64, ptr, i64} ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', 2');
      end
      else if AInstr.IntrinsicName = 'string_owned_extract_alloc_size' then
      begin
        if Length(AInstr.Operands) >= 1 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = extractvalue {ptr, i64, ptr, i64} ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', 3');
      end
      else if AInstr.IntrinsicName = 'string_release' then
      begin
        FNeedsAlloc := True;
        FNeedsFree := True;
        FNeedsStringOwnership := True;
        if Length(AInstr.Operands) >= 2 then
          Emit('  call void @np_string_release(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[1].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'string_owner_clear' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Emit('  store ptr null, ptr ' +
            ValueRef(AInstr.Operands[0].ValueId));
          Emit('  store i64 0, ptr ' +
            ValueRef(AInstr.Operands[1].ValueId));
        end;
      end
      else if AInstr.IntrinsicName = 'ret_str' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Emit('  %retstr.' + IntToStr(AInstr.ResultId) +
            '.1 = insertvalue {ptr, i64} undef, ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', 0');
          Emit('  %retstr.' + IntToStr(AInstr.ResultId) +
            '.2 = insertvalue {ptr, i64} %retstr.' +
            IntToStr(AInstr.ResultId) + '.1, i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ', 1');
          Emit('  ret {ptr, i64} %retstr.' + IntToStr(AInstr.ResultId) + '.2');
        end;
      end
      else if AInstr.IntrinsicName = 'ret_str_owned' then
      begin
        if Length(AInstr.Operands) >= 4 then
        begin
          Emit('  %retstrowned.' + IntToStr(AInstr.ResultId) +
            '.1 = insertvalue {ptr, i64, ptr, i64} undef, ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', 0');
          Emit('  %retstrowned.' + IntToStr(AInstr.ResultId) +
            '.2 = insertvalue {ptr, i64, ptr, i64} %retstrowned.' +
            IntToStr(AInstr.ResultId) + '.1, i64 ' +
            ValueRef(AInstr.Operands[1].ValueId) + ', 1');
          Emit('  %retstrowned.' + IntToStr(AInstr.ResultId) +
            '.3 = insertvalue {ptr, i64, ptr, i64} %retstrowned.' +
            IntToStr(AInstr.ResultId) + '.2, ptr ' +
            ValueRef(AInstr.Operands[2].ValueId) + ', 2');
          Emit('  %retstrowned.' + IntToStr(AInstr.ResultId) +
            '.4 = insertvalue {ptr, i64, ptr, i64} %retstrowned.' +
            IntToStr(AInstr.ResultId) + '.3, i64 ' +
            ValueRef(AInstr.Operands[3].ValueId) + ', 3');
          Emit('  ret {ptr, i64, ptr, i64} %retstrowned.' +
            IntToStr(AInstr.ResultId) + '.4');
        end;
      end
      else if AInstr.IntrinsicName = 'global_ref' then
      begin
        if FGlobalRefCount >= Length(FGlobalRefNames) then
        begin
          SetLength(FGlobalRefNames, FGlobalRefCount + 16);
          SetLength(FGlobalRefIds, FGlobalRefCount + 16);
        end;
        FGlobalRefNames[FGlobalRefCount] := AInstr.CallTarget;
        FGlobalRefIds[FGlobalRefCount] := AInstr.ResultId;
        Inc(FGlobalRefCount);
      end
      else if AInstr.IntrinsicName = 'gep_i64' then
      begin
        if Length(AInstr.Operands) >= 2 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = getelementptr i64, ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId));
      end
      else if AInstr.IntrinsicName = 'gep_i8' then
      begin
        if Length(AInstr.Operands) >= 2 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = getelementptr i8, ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId));
      end
      else if AInstr.IntrinsicName = 'load_zext_i8' then
      begin
        if Length(AInstr.Operands) >= 1 then
        begin
          Emit('  %zext.' + IntToStr(AInstr.ResultId) +
            ' = load i8, ptr ' + ValueRef(AInstr.Operands[0].ValueId));
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = zext i8 %zext.' + IntToStr(AInstr.ResultId) + ' to i64');
        end;
      end
      else if AInstr.IntrinsicName = 'abs' then
      begin
        if Length(AInstr.Operands) >= 1 then
        begin
          Emit('  %abs.neg.' + IntToStr(AInstr.ResultId) +
            ' = sub i64 0, ' + ValueRef(AInstr.Operands[0].ValueId));
          Emit('  %abs.cmp.' + IntToStr(AInstr.ResultId) +
            ' = icmp sge i64 ' + ValueRef(AInstr.Operands[0].ValueId) + ', 0');
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = select i1 %abs.cmp.' + IntToStr(AInstr.ResultId) +
            ', i64 ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', i64 %abs.neg.' + IntToStr(AInstr.ResultId));
        end;
      end
      else if AInstr.IntrinsicName = 'str_const' then
      begin
        Op := Copy(AInstr.CallTarget, 2, Length(AInstr.CallTarget) - 2);
        Emit('  ' + ValueRef(AInstr.ResultId) +
          ' = getelementptr i8, ptr @.str.' + IntToStr(
            AddStrConstant(Op)) + ', i64 0');
      end
      else if AInstr.IntrinsicName = 'int_to_str' then
      begin
        if Length(AInstr.Operands) >= 3 then
        begin
          FNeedsAlloc := True;
          Emit('  %its.' + IntToStr(AInstr.ResultId) +
            ' = call {ptr, i64} @np_int_to_str(i64 ' + ValueRef(AInstr.Operands[0].ValueId) + ')');
          Emit('  %its.' + IntToStr(AInstr.ResultId) +
            '.p = extractvalue {ptr, i64} %its.' +
            IntToStr(AInstr.ResultId) + ', 0');
          Emit('  %its.' + IntToStr(AInstr.ResultId) +
            '.l = extractvalue {ptr, i64} %its.' +
            IntToStr(AInstr.ResultId) + ', 1');
          Emit('  store ptr %its.' + IntToStr(AInstr.ResultId) +
            '.p, ptr ' + ValueRef(AInstr.Operands[1].ValueId));
          Emit('  store i64 %its.' + IntToStr(AInstr.ResultId) +
            '.l, ptr ' + ValueRef(AInstr.Operands[2].ValueId));
          FNeedsIntToStr := True;
        end;
      end
      else if AInstr.IntrinsicName = 'int_to_str_owned' then
      begin
        if Length(AInstr.Operands) >= 1 then
        begin
          FNeedsAlloc := True;
          FNeedsFree := True;
          FNeedsStringOwnership := True;
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call {ptr, i64, ptr, i64} @np_int_to_str_owned(i64 ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
        end;
      end
      else if AInstr.IntrinsicName = 'str_cmp' then
      begin
        if Length(AInstr.Operands) >= 4 then
        begin
          if AInstr.CallTarget = 'ne' then
          begin
            Emit('  %strcmp.' + IntToStr(AInstr.ResultId) +
              ' = call i64 @np_str_cmp(ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ', ptr ' + ValueRef(AInstr.Operands[2].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[3].ValueId) + ')');
            Emit('  ' + ValueRef(AInstr.ResultId) +
              ' = xor i64 %strcmp.' + IntToStr(AInstr.ResultId) + ', 1');
          end
          else
            Emit('  ' + ValueRef(AInstr.ResultId) +
              ' = call i64 @np_str_cmp(ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ', ptr ' + ValueRef(AInstr.Operands[2].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[3].ValueId) + ')');
          FNeedsStrCmp := True;
        end;
      end
      else if AInstr.IntrinsicName = 'str_pos' then
      begin
        if Length(AInstr.Operands) >= 4 then
        begin
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call i64 @np_str_pos(ptr ' + ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ', ptr ' + ValueRef(AInstr.Operands[2].ValueId) + ', i64 ' + ValueRef(AInstr.Operands[3].ValueId) + ')');
          FNeedsStrCmp := True;  // 复用标志：str_cmp/str_pos 一起声明（linker 忽略未引用的 declare）
        end;
      end
      else if AInstr.IntrinsicName = 'arr_alloc' then
      begin
        FNeedsAlloc := True;
        if Length(AInstr.Operands) >= 1 then
        begin
          Emit('  %arralloc.' + IntToStr(AInstr.ResultId) +
            '.sz = mul i64 ' + ValueRef(AInstr.Operands[0].ValueId) + ', 8');
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call ptr @np_alloc(i64 %arralloc.' +
            IntToStr(AInstr.ResultId) + '.sz)');
        end;
      end
      else if AInstr.IntrinsicName = 'arr_alloc_sized' then
      begin
        FNeedsAlloc := True;
        if Length(AInstr.Operands) >= 2 then
        begin
          Emit('  %arralloc.' + IntToStr(AInstr.ResultId) +
            '.sz = mul i64 ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', ' + ValueRef(AInstr.Operands[1].ValueId));
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call ptr @np_alloc(i64 %arralloc.' +
            IntToStr(AInstr.ResultId) + '.sz)');
        end;
      end
      else if AInstr.IntrinsicName = 'dynarray_resize' then
      begin
        FNeedsAlloc := True;
        FNeedsFree := True;
        FNeedsMemcpy := True;
        FNeedsDynArrayHelpers := True;
        if Length(AInstr.Operands) >= 4 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call ptr @np_dynarray_resize(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[1].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[2].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[3].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'dynarray_release' then
      begin
        FNeedsAlloc := True;
        FNeedsFree := True;
        FNeedsDynArrayHelpers := True;
        if Length(AInstr.Operands) >= 3 then
          Emit('  call void @np_dynarray_release(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[1].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[2].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'class_alloc' then
      begin
        FNeedsAlloc := True;
        FNeedsObjectAlloc := True;
        if Length(AInstr.Operands) >= 1 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call ptr @np_object_alloc(i64 ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'vmt_store' then
      begin
        if (Length(AInstr.Operands) >= 1) and (AInstr.CallTarget <> '') then
          Emit('  store ptr @' + AInstr.CallTarget + '.vmt, ptr ' + ValueRef(AInstr.Operands[0].ValueId));
      end
      else if AInstr.IntrinsicName = 'imt_store' then
      begin
        if (Length(AInstr.Operands) >= 1) and (AInstr.CallTarget <> '') then
          Emit('  store ptr @' + AInstr.CallTarget + ', ptr ' + ValueRef(AInstr.Operands[0].ValueId));
      end
      else if AInstr.IntrinsicName = 'intf_addref' then
      begin
        if Length(AInstr.Operands) >= 1 then
          Emit('  call void @np_intf_addref(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'intf_release' then
      begin
        if Length(AInstr.Operands) >= 1 then
          Emit('  call void @np_intf_release(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'exc_store' then
      begin
        if Length(AInstr.Operands) >= 1 then
          Emit('  store ptr ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', ptr @__np_exc_object');
      end
      else if AInstr.IntrinsicName = 'exc_load' then
      begin
        Emit('  ' + ValueRef(AInstr.ResultId) +
          ' = load ptr, ptr @__np_exc_object');
      end
      else if AInstr.IntrinsicName = 'vcall' then
      begin
        if Length(AInstr.Operands) >= 2 then
        begin
          Op := '  ' + ValueRef(AInstr.ResultId) +
            ' = call ' + TypeToLlvm(AInstr.TypeId) + ' ' + ValueRef(AInstr.Operands[0].ValueId) +
            '(ptr ' + ValueRef(AInstr.Operands[1].ValueId);
          for I := 2 to High(AInstr.Operands) do
          begin
            if AInstr.Operands[I].TypeId <> 0 then
              Op := Op + ', ' + TypeToLlvm(AInstr.Operands[I].TypeId) +
                ' ' + ValueRef(AInstr.Operands[I].ValueId)
            else
              Op := Op + ', i64 ' + ValueRef(AInstr.Operands[I].ValueId);
          end;
          Op := Op + ')';
          Emit(Op);
        end;
      end
      else if AInstr.IntrinsicName = 'vcall_str' then
      begin
        if Length(AInstr.Operands) >= 4 then
        begin
          Emit('  %vcallstr.' + IntToStr(AInstr.ResultId) +
            ' = call {ptr, i64} ' + ValueRef(AInstr.Operands[0].ValueId) +
            '(ptr ' + ValueRef(AInstr.Operands[1].ValueId) + ')');
          Emit('  %vcallstr.' + IntToStr(AInstr.ResultId) +
            '.p = extractvalue {ptr, i64} %vcallstr.' +
            IntToStr(AInstr.ResultId) + ', 0');
          Emit('  %vcallstr.' + IntToStr(AInstr.ResultId) +
            '.l = extractvalue {ptr, i64} %vcallstr.' +
            IntToStr(AInstr.ResultId) + ', 1');
          Emit('  store ptr %vcallstr.' + IntToStr(AInstr.ResultId) +
            '.p, ptr ' + ValueRef(AInstr.Operands[2].ValueId));
          Emit('  store i64 %vcallstr.' + IntToStr(AInstr.ResultId) +
            '.l, ptr ' + ValueRef(AInstr.Operands[3].ValueId));
        end;
      end
      else if AInstr.IntrinsicName = 'is_instance' then
      begin
        if (Length(AInstr.Operands) >= 1) and (AInstr.CallTarget <> '') then
        begin
          Inc(FIsCheckCounter);
          Emit('  br label %is.pre.' + IntToStr(FIsCheckCounter));
          Emit('is.pre.' + IntToStr(FIsCheckCounter) + ':');
          Emit('  br label %is.loop.' + IntToStr(FIsCheckCounter));
          Emit('is.loop.' + IntToStr(FIsCheckCounter) + ':');
          Emit('  %is.cur.' + IntToStr(FIsCheckCounter) +
            ' = phi ptr [ ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', %is.pre.' + IntToStr(FIsCheckCounter) +
            ' ], [ %is.parent.' + IntToStr(FIsCheckCounter) +
            ', %is.next.' + IntToStr(FIsCheckCounter) + ' ]');
          Emit('  %is.eq.' + IntToStr(FIsCheckCounter) +
            ' = icmp eq ptr %is.cur.' + IntToStr(FIsCheckCounter) +
            ', @' + AInstr.CallTarget + '.vmt');
          Emit('  br i1 %is.eq.' + IntToStr(FIsCheckCounter) +
            ', label %is.true.' + IntToStr(FIsCheckCounter) +
            ', label %is.next.' + IntToStr(FIsCheckCounter));
          Emit('is.next.' + IntToStr(FIsCheckCounter) + ':');
          Emit('  %is.parent.' + IntToStr(FIsCheckCounter) +
            ' = load ptr, ptr %is.cur.' + IntToStr(FIsCheckCounter));
          Emit('  %is.done.' + IntToStr(FIsCheckCounter) +
            ' = icmp eq ptr %is.parent.' + IntToStr(FIsCheckCounter) +
            ', null');
          Emit('  br i1 %is.done.' + IntToStr(FIsCheckCounter) +
            ', label %is.false.' + IntToStr(FIsCheckCounter) +
            ', label %is.loop.' + IntToStr(FIsCheckCounter));
          Emit('is.true.' + IntToStr(FIsCheckCounter) + ':');
          Emit('  br label %is.end.' + IntToStr(FIsCheckCounter));
          Emit('is.false.' + IntToStr(FIsCheckCounter) + ':');
          Emit('  br label %is.end.' + IntToStr(FIsCheckCounter));
          Emit('is.end.' + IntToStr(FIsCheckCounter) + ':');
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = phi i64 [ 1, %is.true.' + IntToStr(FIsCheckCounter) +
            ' ], [ 0, %is.false.' + IntToStr(FIsCheckCounter) + ' ]');
        end;
      end
      else if AInstr.IntrinsicName = 'fillchar' then
      begin
        if Length(AInstr.Operands) >= 3 then
        begin
          Emit('  call void @np_memset(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i8 ' +
            ValueRef(AInstr.Operands[2].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[1].ValueId) + ')');
          FNeedsMemset := True;
        end;
      end
      else if AInstr.IntrinsicName = 'move' then
      begin
        if Length(AInstr.Operands) >= 3 then
        begin
          Emit('  call void @np_memmove(ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[2].ValueId) + ')');
          FNeedsMemmove := True;
        end;
      end
      else if AInstr.IntrinsicName = 'getmem' then
      begin
        if Length(AInstr.Operands) >= 1 then
        begin
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = call ptr @np_alloc(i64 ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
          FNeedsAlloc := True;
        end;
      end
      else if AInstr.IntrinsicName = 'freemem' then
      begin
        if Length(AInstr.Operands) >= 1 then
        begin
          Emit('  call void @np_free(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 0)');
          FNeedsFree := True;
        end;
      end
      else if AInstr.IntrinsicName = 'tstring_init' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 1 then
          Emit('  call void @np_tstring_init(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_fini' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 1 then
          Emit('  call void @np_tstring_fini(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_assign' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 2 then
          Emit('  call void @np_tstring_assign(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_ret_move' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 2 then
          Emit('  call void @np_tstring_ret_move(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_ret_copy' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 2 then
          Emit('  call void @np_tstring_ret_copy(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_from_literal' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 3 then
          Emit('  call void @np_tstring_from_literal(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[2].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_copy' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 4 then
          Emit('  call void @np_tstring_copy(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[2].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[3].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_concat' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 3 then
          Emit('  call void @np_tstring_concat(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[2].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_field_assign' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 2 then
          Emit('  call void @np_tstring_field_assign(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
            ValueRef(AInstr.Operands[1].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_field_fini' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 1 then
          Emit('  call void @np_tstring_field_fini(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_len' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 1 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call i64 @np_tstring_len(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_from_int' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 2 then
          Emit('  call void @np_tstring_from_int(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', i64 ' +
            ValueRef(AInstr.Operands[1].ValueId) + ')');
      end
      else if AInstr.IntrinsicName = 'tstring_data' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 1 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = call ptr @np_tstring_data(ptr ' +
            ValueRef(AInstr.Operands[0].ValueId) + ')');
      end
    end;
    hikTryBegin:
    begin
      FNeedsExceptionRuntime := True;
      Inc(FTryCounter);
      Emit('  ; --- try begin ---');
      Emit('  %jmpbuf.' + IntToStr(FTryCounter) + ' = alloca [9 x ptr]');
      Emit('  call void @np_try_push(ptr %jmpbuf.' + IntToStr(FTryCounter) + ')');
      Emit('  %setjmp.' + IntToStr(FTryCounter) + ' = call i32 @setjmp(ptr %jmpbuf.' + IntToStr(FTryCounter) + ')');
      Emit('  %is_exc.' + IntToStr(FTryCounter) + ' = icmp ne i32 %setjmp.' + IntToStr(FTryCounter) + ', 0');
      if AInstr.IntrinsicName <> '' then
        Emit('  br i1 %is_exc.' + IntToStr(FTryCounter) + ', label %' +
          Trim(AInstr.IntrinsicName) + ', label %try.body.' + IntToStr(FTryCounter))
      else
        Emit('  br i1 %is_exc.' + IntToStr(FTryCounter) + ', label %try.exc.' +
          IntToStr(FTryCounter) + ', label %try.body.' + IntToStr(FTryCounter));
      Emit('try.body.' + IntToStr(FTryCounter) + ':');
    end;
    hikTryEnd:
    begin
      Emit('  ; --- try end ---');
      Emit('  call void @np_try_pop()');
    end;
    hikFinallyBegin:
    begin
      Emit('  ; --- finally begin ---');
    end;
    hikFinallyEnd:
    begin
      Emit('  ; --- finally end ---');
      Emit('  call void @np_finally_end()');
    end;
    hikExceptBegin:
    begin
      Emit('  ; --- except begin ---');
    end;
    hikExceptEnd:
    begin
      Emit('  ; --- except end ---');
      Emit('  call void @np_except_end()');
    end;
    hikRaise:
    begin
      FNeedsExceptionRuntime := True;
      Emit('  call void @np_raise()');
      Emit('  unreachable');
    end;
  end;
end;

procedure THIRLlvmEmitter.EmitTerminator(const ATerm: THIRTerminator);
var
  I: LongInt;
  RetTy: string;
  T: THIRTypeRec;
begin
  ClosePendingObjectFreeGuard;
  case ATerm.Kind of
    htkReturn:
      if ATerm.ReturnValue = 0 then
        Emit('  ret void')
      else begin
        T := FModule.Types.GetType(FCurrentReturnTypeId);
        if T.Kind = htkString then
          RetTy := '{ptr, i64}'
        else
          RetTy := TypeToLlvm(FCurrentReturnTypeId);
        Emit('  ret ' + RetTy + ' ' + ValueRef(ATerm.ReturnValue));
      end;
    htkBranch:
      Emit('  br label %bb' + IntToStr(ATerm.TargetBlock));
    htkCondBranch:
      Emit('  br i1 ' + ValueRef(ATerm.Condition) +
        ', label %bb' + IntToStr(ATerm.TrueBlock) +
        ', label %bb' + IntToStr(ATerm.FalseBlock));
    htkSwitch:
    begin
      Emit('  switch i64 ' + ValueRef(ATerm.Condition) +
        ', label %bb' + IntToStr(ATerm.DefaultBlock) + ' [');
      for I := 0 to High(ATerm.SwitchCases) do
        Emit('    i64 ' + IntToStr(ATerm.SwitchCases[I].Value) +
          ', label %bb' + IntToStr(ATerm.SwitchCases[I].TargetBlock));
      Emit('  ]');
    end;
    htkUnreachable:
      Emit('  unreachable');
  end;
end;

function THIRLlvmEmitter.IsSretFunction(const AName: string): Boolean;
var
  I: LongInt;
  F: THIRFunction;
begin
  for I := 0 to FModule.FunctionCount - 1 do
  begin
    F := FModule.FunctionAt(I);
    if SameText(F.Name, AName) and (Length(F.Params) > 0) and
      (F.Params[0].Name = 'sret_ptr') then
      Exit(True);
  end;
  Result := False;
end;

procedure THIRLlvmEmitter.EmitFunction(const AFunc: THIRFunction);
var
  I, J: LongInt;
  ParamStr, RetStr: string;
  T: THIRTypeRec;
begin
  if AFunc.IsExternal then Exit;
  FGlobalRefCount := 0;

  ParamStr := '';
  for I := 0 to High(AFunc.Params) do
  begin
    if I > 0 then ParamStr := ParamStr + ', ';
    ParamStr := ParamStr + TypeToLlvm(AFunc.Params[I].TypeId) +
      ' ' + ValueRef(AFunc.Params[I].ValueId);
  end;

  T := FModule.Types.GetType(AFunc.ReturnTypeId);
  if AFunc.IsTStringReturnAbi then
  begin
    FNeedsTStringRuntime := True;
    RetStr := 'void';
    if ParamStr <> '' then
      ParamStr := 'ptr sret(%TString) %agg.result, ' + ParamStr
    else
      ParamStr := 'ptr sret(%TString) %agg.result';
  end
  else if (Length(AFunc.Params) > 0) and (AFunc.Params[0].Name = 'sret_ptr') then
    RetStr := 'void'
  else if AFunc.UsesOwnedStringReturnAbi then
    RetStr := '{ptr, i64, ptr, i64}'
  else if T.Kind = htkString then
    RetStr := '{ptr, i64}'
  else
    RetStr := TypeToLlvm(AFunc.ReturnTypeId);

  FCurrentReturnTypeId := AFunc.ReturnTypeId;

  Emit('');
  if (Pos('np_object_dynarray_cleanup_', AFunc.Name) = 1) or
    (Pos('np_object_string_cleanup_', AFunc.Name) = 1) then
    Emit('define internal ' + RetStr + ' @' + AFunc.Name +
      '(' + ParamStr + ') {')
  else
    Emit('define ' + RetStr + ' @' + AFunc.Name +
      '(' + ParamStr + ') {');

  for I := 0 to High(AFunc.Blocks) do
  begin
    Emit('bb' + IntToStr(AFunc.Blocks[I].Id) + ':');
    for J := 0 to High(AFunc.Blocks[I].Instrs) do
      EmitInstr(AFunc.Blocks[I].Instrs[J]);
    if not BlockEndsWithIntrinsicReturn(AFunc.Blocks[I]) then
      EmitTerminator(AFunc.Blocks[I].Terminator);
  end;

  Emit('}');
end;

procedure THIRLlvmEmitter.EmitUnitInitCalls;
var
  I: LongInt;
  LName: string;
  LNormalizedUnitName: string;
begin
  for I := 0 to FModule.UnitInitOrderCount - 1 do
  begin
    LName := FModule.UnitInitOrderAt(I);
    LNormalizedUnitName := StringReplace(LName, '.', '_', True);
    Emit('  call void @np_unit_init_' + LNormalizedUnitName + '()');
  end;
end;

procedure THIRLlvmEmitter.EmitUnitFiniCalls;
var
  I: LongInt;
  LName: string;
  LNormalizedUnitName: string;
begin
  // Fini in reverse order of init
  for I := FModule.UnitInitOrderCount - 1 downto 0 do
  begin
    LName := FModule.UnitInitOrderAt(I);
    LNormalizedUnitName := StringReplace(LName, '.', '_', True);
    Emit('  call void @np_unit_fini_' + LNormalizedUnitName + '()');
  end;
end;

procedure THIRLlvmEmitter.EmitModule;
var
  I: LongInt;
  G: THIRGlobal;
  LFunc: THIRFunction;
begin
  FLineCount := 0;
  FStrConstCount := 0;
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
  FNeedsExceptionRuntime := False;
  FNeedsProcessLifecycle := False;
  FProcessFiniEmitted := False;
  FUnitInitCallsEmitted := False;
  FUnitFiniCallsEmitted := False;
  FTryCounter := 0;
  FObjectFreeCounter := 0;
  FPendingObjectFreeActive := False;
  FPendingObjectFreeEndLabel := '';
  Emit('; ModuleID = ''' + FModule.ModuleName + '''');
  Emit('target triple = "' + FLlvmTriple + '"');
  Emit('target datalayout = "' + FLlvmDataLayout + '"');

  for I := 0 to FModule.GlobalCount - 1 do
  begin
    G := FModule.GlobalAt(I);
    Emit('');
    if FModule.Types.GetType(G.TypeId).Kind = htkPointer then
      Emit('@g_' + G.Name + ' = internal global ptr null')
    else
      Emit('@g_' + G.Name + ' = internal global i64 0');
  end;

  for I := 0 to FModule.FunctionCount - 1 do
  begin
    LFunc := FModule.FunctionAt(I);
    EmitFunction(LFunc);
  end;

  if FNeedsProcessLifecycle then
  begin
    Emit('');
    Emit('declare void @np_process_init()');
    Emit('declare void @np_process_fini()');
  end;

  if FStrConstCount > 0 then
  begin
    Emit('');
    EmitStrConstants;
  end;

  EmitVmtGlobals;
  EmitImtGlobals;

  if FNeedsWriteInt then
    EmitWriteIntHelper;

  if FNeedsAlloc then
    EmitAllocHelper;

  if FNeedsMemcpy or FNeedsMemset or FNeedsMemmove or FNeedsStringOwnership then
    EmitMemcpyHelper;

  if FNeedsObjectAlloc then
    EmitMemzeroHelper;

  if FNeedsStrConcat then
    EmitStrConcatHelper;

  if FNeedsStringOwnership then
    EmitStringOwnershipHelpers;

  if FNeedsTStringRuntime then
    EmitTStringHelpers;

  if FNeedsDynArrayHelpers then
    EmitDynArrayHelpers;

  if FNeedsObjectAlloc then
    EmitObjectAllocHelper;

  if FNeedsObjectFreeRelease then
  begin
    EmitObjectFreeReleaseHelper;
    EmitObjectReleaseValidHelper;
  end;

  if FNeedsFree then
    EmitFreeHelper;

  if FNeedsObjectFreeRelease then
    EmitObjectReleaseInvalidHelper;

  if FNeedsAlloc then
    EmitAllocatorFaultHelper;

  if FNeedsObjectAlloc then
    EmitIntfRefCountHelpers;

  if FNeedsExceptionRuntime then
    EmitExceptionRuntimeHelpers;

  if FNeedsStrCmp then
  begin
    // Phase 4: np_str_cmp/np_str_pos 已移至 nextpas.runtime.strings.ll
    Emit('');
    Emit('declare i64 @np_str_cmp(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len)');
    Emit('declare i64 @np_str_pos(ptr %sub_ptr, i64 %sub_len, ptr %s_ptr, i64 %s_len)');
  end;

  if FNeedsIntToStr then
  begin
    // Phase 4: np_int_to_str 声明已在 EmitStringOwnershipHelpers 中 emit
  end;
end;

procedure THIRLlvmEmitter.EmitWriteIntHelper;
begin
  // Phase 4: write_i64_decimal 已移至 nextpas.runtime.strings.ll
  Emit('');
  Emit('declare void @write_i64_decimal(i64 %v)');
end;

function THIRLlvmEmitter.AddStrConstant(const AValue: string): LongInt;
begin
  Result := FStrConstCount;
  if FStrConstCount >= Length(FStrConstants) then
    SetLength(FStrConstants, FStrConstCount + 16);
  FStrConstants[FStrConstCount] := AValue;
  Inc(FStrConstCount);
end;

function THIRLlvmEmitter.EscapeLlvmStr(const AValue: string): string;
var
  I: LongInt;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(AValue) do
  begin
    C := AValue[I];
    if (Ord(C) < 32) or (Ord(C) > 126) or (C = '"') or (C = '\') then
      Result := Result + '\' + LowerCase(IntToHex(Ord(C), 2))
    else
      Result := Result + C;
  end;
end;

procedure THIRLlvmEmitter.EmitStrConstants;
var
  I, Len: LongInt;
begin
  for I := 0 to FStrConstCount - 1 do
  begin
    Len := Length(FStrConstants[I]);
    Emit('@.str.' + IntToStr(I) + ' = private constant [' + IntToStr(Len) +
      ' x i8] c"' + EscapeLlvmStr(FStrConstants[I]) + '"');
  end;
end;

// ---------------------------------------------------------------------------
// BOOTSTRAP-TEMPORARY: Inline runtime helpers
//
// The following procedures emit inline LLVM IR for allocator, memory, and
// object lifecycle operations.  This is a BOOTSTRAP TEMPORARY — every
// compiled binary carries its own copy of these ~300 lines of IR.
//
// Gate 4 roadmap (docs/plans/2026-06-18-debt-roadmap.md):
//   Phase 1 (done): mark as bootstrap-temporary
//   Phase 2 (pending): create runtime.allocator Pascal module with C ABI
//   Phase 3 (pending): replace `define internal` with `declare external`
//
// Once Phase 3 is complete, these emit helpers become no-ops and the runtime
// module provides the single canonical implementation.
// ---------------------------------------------------------------------------

procedure THIRLlvmEmitter.EmitAllocHelper;
begin
  // Phase 3: allocator 已移至 libnprt.a runtime 模块，只 emit 外部声明
  Emit('');
  Emit('declare ptr @np_alloc(i64 %size)');
  Emit('declare void @np_free(ptr %raw, i64 %size)');
  Emit('declare void @np_allocator_fault(i64 %code, i64 %arg0, i64 %arg1)');
end;

procedure THIRLlvmEmitter.EmitMemcpyHelper;
begin
  // Phase 3: memops 已移至 libnprt.a runtime 模块
  Emit('');
  Emit('declare void @np_memcpy(ptr %dst, ptr %src, i64 %n)');
  Emit('declare void @np_memmove(ptr %dst, ptr %src, i64 %n)');
  Emit('declare void @np_memset(ptr %dst, i8 %val, i64 %n)');
  Emit('declare void @np_memzero(ptr %dst, i64 %n)');
end;

procedure THIRLlvmEmitter.EmitMemzeroHelper;
begin
  // Phase 3: memzero 声明已在 EmitMemcpyHelper 中 emit
end;

procedure THIRLlvmEmitter.EmitStrConcatHelper;
begin
  // Phase 4: np_str_concat 已移至 nextpas.runtime.strings.ll
  Emit('');
  Emit('declare {ptr, i64} @np_str_concat(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len)');
end;

procedure THIRLlvmEmitter.EmitStringOwnershipHelpers;
begin
  // Phase 4: 字符串 helper 已移至 nextpas.runtime.strings.ll
  Emit('');
  Emit('declare void @np_string_fault(i64 %code, i64 %arg0, i64 %arg1)');
  Emit('declare void @np_string_release(ptr %owner, i64 %alloc_size)');
  Emit('declare {ptr, i64, ptr, i64} @np_str_concat_owned(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len)');
  Emit('declare {ptr, i64, ptr, i64} @np_str_copy_owned(ptr %src_ptr, i64 %src_len, i64 %start, i64 %count)');
  Emit('declare {ptr, i64} @np_int_to_str(i64 %val)');
  Emit('declare {ptr, i64, ptr, i64} @np_int_to_str_owned(i64 %val)');
end;

procedure THIRLlvmEmitter.EmitTStringHelpers;
begin
  { TString 24B runtime — all functions operate on ptr to 24-byte record }
  Emit('');
  Emit('%TString = type [24 x i8]');
  Emit('declare void @np_tstring_init(ptr %s)');
  Emit('declare void @np_tstring_fini(ptr %s)');
  Emit('declare void @np_tstring_assign(ptr %dst, ptr %src)');
  Emit('declare void @np_tstring_move(ptr %dst, ptr %src)');
  Emit('declare i64 @np_tstring_len(ptr %s)');
  Emit('declare ptr @np_tstring_data(ptr %s)');
  Emit('declare i8 @np_tstring_is_sso(ptr %s)');
  Emit('declare void @np_tstring_create(ptr %dst, ptr %data, i64 %len)');
  Emit('declare void @np_tstring_from_literal(ptr %dst, ptr %lit, i64 %len)');
  Emit('declare void @np_tstring_concat(ptr %dst, ptr %a, ptr %b)');
  Emit('declare void @np_tstring_copy(ptr %dst, ptr %src, i64 %start, i64 %count)');
  Emit('declare void @np_tstring_from_int(ptr %dst, i64 %val)');
  Emit('declare i64 @np_tstring_equal(ptr %a, ptr %b)');
  Emit('declare i64 @np_tstring_compare(ptr %a, ptr %b)');
  Emit('declare void @np_tstring_field_assign(ptr %dst, ptr %src)');
  Emit('declare void @np_tstring_field_fini(ptr %s)');
  Emit('declare void @np_tstring_ret_move(ptr %sret_dst, ptr %src)');
  Emit('declare void @np_tstring_ret_copy(ptr %sret_dst, ptr %src)');
end;

procedure THIRLlvmEmitter.EmitDynArrayHelpers;
begin
  // Phase 4: 动态数组 helper 已移至 nextpas.runtime.dynarray.ll
  Emit('');
  Emit('declare void @np_dynarray_fault(i64 %code, i64 %arg0, i64 %arg1)');
  Emit('declare void @np_dynarray_release(ptr %ptr, i64 %len, i64 %elem_size)');
  Emit('declare ptr @np_dynarray_resize(ptr %old_ptr, i64 %old_len, i64 %new_len, i64 %elem_size)');
end;

procedure THIRLlvmEmitter.EmitObjectAllocHelper;
begin
  // Phase 3: object alloc 已移至 libnprt.a runtime 模块
  Emit('');
  Emit('declare ptr @np_object_alloc(i64 %size)');
end;

procedure THIRLlvmEmitter.EmitObjectFreeReleaseHelper;
begin
  // Phase 3: object free 已移至 libnprt.a runtime 模块
  Emit('');
  Emit('declare void @np_object_free_release(ptr %obj)');
end;

procedure THIRLlvmEmitter.EmitObjectReleaseValidHelper;
begin
  // Phase 3: 已移至 libnprt.a runtime 模块（内部函数，不需要外部声明）
end;

procedure THIRLlvmEmitter.EmitFreeHelper;
begin
  // Phase 3: np_free 声明已在 EmitAllocHelper 中 emit
end;

procedure THIRLlvmEmitter.EmitObjectReleaseInvalidHelper;
begin
  // Phase 3: 已移至 libnprt.a runtime 模块（内部函数，不需要外部声明）
end;

procedure THIRLlvmEmitter.EmitAllocatorFaultHelper;
begin
  // Phase 3: allocator fault 已移至 libnprt.a runtime 模块
  // np_allocator_fault 声明已在 EmitAllocHelper 中 emit
  // llvm.trap 声明保留（其他 helpers 也需要）
  Emit('');
  Emit('declare void @llvm.trap()');
end;

procedure THIRLlvmEmitter.EmitIntfRefCountHelpers;
begin
  // Phase 3: intf refcount 已移至 libnprt.a runtime 模块
  Emit('');
  Emit('declare void @np_intf_addref(ptr %obj)');
  Emit('declare void @np_intf_release(ptr %obj)');
end;

procedure THIRLlvmEmitter.EmitExceptionRuntimeHelpers;
begin
  // Phase 4: 异常 runtime 已移至 nextpas.runtime.exceptions.ll
  // globals 和 helper 函数通过 libnprt.a 外部链接
  Emit('');
  Emit('; --- Exception runtime (external from libnprt.a) ---');
  Emit('@__np_exc_stack = external global ptr');
  Emit('@__np_exc_pending = external global i1');
  Emit('@__np_exc_object = external global ptr');
  Emit('');
  Emit('declare void @np_try_push(ptr %buf)');
  Emit('declare void @np_try_pop()');
  Emit('declare void @np_raise()');
  Emit('declare void @np_finally_end()');
  Emit('declare void @np_except_end()');
  Emit('');

  // setjmp/longjmp 实现必须内联在用户程序中（module-level asm）
  // runtime .ll 通过 declare @longjmp 引用，链接时解析
  Emit('; freestanding setjmp/longjmp via module-level asm');
  Emit('module asm ".globl setjmp"');
  Emit('module asm ".type setjmp, @function"');
  Emit('module asm "setjmp:"');
  Emit('module asm "  movq %rbx, (%rdi)"');
  Emit('module asm "  movq %rbp, 8(%rdi)"');
  Emit('module asm "  movq %r12, 16(%rdi)"');
  Emit('module asm "  movq %r13, 24(%rdi)"');
  Emit('module asm "  movq %r14, 32(%rdi)"');
  Emit('module asm "  movq %r15, 40(%rdi)"');
  Emit('module asm "  leaq 8(%rsp), %rax"');
  Emit('module asm "  movq %rax, 48(%rdi)"');
  Emit('module asm "  movq (%rsp), %rax"');
  Emit('module asm "  movq %rax, 56(%rdi)"');
  Emit('module asm "  xorl %eax, %eax"');
  Emit('module asm "  ret"');
  Emit('module asm ""');
  Emit('module asm ".globl longjmp"');
  Emit('module asm ".type longjmp, @function"');
  Emit('module asm "longjmp:"');
  Emit('module asm "  movq (%rdi), %rbx"');
  Emit('module asm "  movq 8(%rdi), %rbp"');
  Emit('module asm "  movq 16(%rdi), %r12"');
  Emit('module asm "  movq 24(%rdi), %r13"');
  Emit('module asm "  movq 32(%rdi), %r14"');
  Emit('module asm "  movq 40(%rdi), %r15"');
  Emit('module asm "  movq 48(%rdi), %rsp"');
  Emit('module asm "  movl %esi, %eax"');
  Emit('module asm "  testl %eax, %eax"');
  Emit('module asm "  jnz 1f"');
  Emit('module asm "  incl %eax"');
  Emit('module asm "  1: jmpq *56(%rdi)"');
  Emit('');
  Emit('declare i32 @setjmp(ptr) returns_twice nounwind');
  Emit('declare void @longjmp(ptr, i32) noreturn nounwind');
end;

procedure THIRLlvmEmitter.EmitVmtGlobals;
var
  I, J: LongInt;
  Vmt: THIRVmtGlobal;
  Line: string;
begin
  for I := 0 to FModule.VmtGlobalCount - 1 do
  begin
    Vmt := FModule.VmtGlobalAt(I);
    if Length(Vmt.Funcs) = 0 then Continue;
    Line := '@' + Vmt.ClassName + '.vmt = internal constant [' +
      IntToStr(Length(Vmt.Funcs)) + ' x ptr] [';
    for J := 0 to High(Vmt.Funcs) do
    begin
      if J > 0 then Line := Line + ', ';
      if Vmt.Funcs[J] = '' then
        Line := Line + 'ptr null'
      else
        Line := Line + 'ptr @' + Vmt.Funcs[J];
    end;
    Line := Line + ']';
    Emit('');
    Emit(Line);
  end;
end;

procedure THIRLlvmEmitter.EmitImtGlobals;
var
  I, J, K: LongInt;
  Imt: THIRImtGlobal;
  Line, RealFunc, ThunkName, ParamStr, CallArgs: string;
  OffsetBytes, ParamCount: LongInt;
  UnderscorePos: LongInt;
begin
  for I := 0 to FModule.ImtGlobalCount - 1 do
  begin
    Imt := FModule.ImtGlobalAt(I);
    if Length(Imt.ThunkNames) = 0 then Continue;

    Line := '@' + Imt.ClassName + '.imt.' + Imt.InterfaceName +
      ' = internal constant [' + IntToStr(Length(Imt.ThunkNames)) + ' x ptr] [';
    for J := 0 to High(Imt.ThunkNames) do
    begin
      if J > 0 then Line := Line + ', ';
      if Imt.ThunkNames[J] = '' then
        Line := Line + 'ptr null'
      else
        Line := Line + 'ptr @' + Imt.ThunkNames[J];
    end;
    Line := Line + ']';
    Emit('');
    Emit(Line);

    OffsetBytes := Imt.SlotOffset * 8;
    for J := 0 to High(Imt.ThunkNames) do
    begin
      ThunkName := Imt.ThunkNames[J];
      if ThunkName = '' then Continue;
      UnderscorePos := Pos('._intf_thunk_', ThunkName);
      if UnderscorePos > 0 then
        RealFunc := Copy(ThunkName, 1, UnderscorePos - 1) + '.' +
          Copy(ThunkName, Pos('_' + Imt.InterfaceName + '_', ThunkName) +
            Length(Imt.InterfaceName) + 2, MaxInt)
      else
        RealFunc := ThunkName;
      ParamCount := 0;
      if J < Length(Imt.ThunkParamCounts) then
        ParamCount := Imt.ThunkParamCounts[J];
      ParamStr := 'ptr %intf_self';
      CallArgs := 'ptr %obj';
      for K := 0 to ParamCount - 1 do
      begin
        ParamStr := ParamStr + ', i64 %a' + IntToStr(K);
        CallArgs := CallArgs + ', i64 %a' + IntToStr(K);
      end;
      Emit('');
      Emit('define internal i64 @' + ThunkName + '(' + ParamStr + ') {');
      Emit('entry:');
      Emit('  %obj = getelementptr i8, ptr %intf_self, i64 -' + IntToStr(OffsetBytes));
      Emit('  %r = tail call i64 @' + RealFunc + '(' + CallArgs + ')');
      Emit('  ret i64 %r');
      Emit('}');
    end;
  end;
end;

function THIRLlvmEmitter.AsText: string;
var
  I: LongInt;
begin
  Result := '';
  for I := 0 to FLineCount - 1 do
    Result := Result + FLines[I] + LineEnding;
end;

procedure THIRLlvmEmitter.SaveToFile(const APath: string);
var
  F: TextFile;
  I: LongInt;
begin
  AssignFile(F, APath);
  Rewrite(F);
  for I := 0 to FLineCount - 1 do
    WriteLn(F, FLines[I]);
  CloseFile(F);
end;

end.
