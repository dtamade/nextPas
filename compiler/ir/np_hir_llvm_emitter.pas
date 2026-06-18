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
    FNeedsStrConcat: Boolean;
    FNeedsStringOwnership: Boolean;
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
  SysUtils, nextpas.core.system.contracts;

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
  FNeedsStrConcat := False;
  FNeedsStringOwnership := False;
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
      if (AInstr.CallTarget = 'np_process_init') or
        (AInstr.CallTarget = 'np_process_fini') then
        FNeedsProcessLifecycle := True;
      EmitCallInstr(AInstr);
    end;
    hikIntrinsic:
    begin
      if AInstr.IntrinsicName = 'halt' then
      begin
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
          FNeedsStrCmp := True;
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
      end;
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
  if (Length(AFunc.Params) > 0) and (AFunc.Params[0].Name = 'sret_ptr') then
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

procedure THIRLlvmEmitter.EmitModule;
var
  I: LongInt;
  G: THIRGlobal;
  LFunc: THIRFunction;
  LInitCount, LFiniCount: LongInt;
  LInitNames, LFiniNames: array of string;
  LEmitCtors: Boolean;
begin
  FLineCount := 0;
  FStrConstCount := 0;
  FNeedsWriteInt := False;
  FNeedsAlloc := False;
  FNeedsFree := False;
  FNeedsMemcpy := False;
  FNeedsStrConcat := False;
  FNeedsStringOwnership := False;
  FNeedsStrCmp := False;
  FNeedsIntToStr := False;
  FNeedsObjectAlloc := False;
  FNeedsObjectFreeRelease := False;
  FNeedsDynArrayHelpers := False;
  FNeedsExceptionRuntime := False;
  FNeedsProcessLifecycle := False;
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

  LInitCount := 0;
  LFiniCount := 0;
  SetLength(LInitNames, 16);
  SetLength(LFiniNames, 16);

  for I := 0 to FModule.FunctionCount - 1 do
  begin
    LFunc := FModule.FunctionAt(I);
    if Copy(LFunc.Name, 1, 14) = 'np_unit_init_' then
    begin
      if LInitCount >= Length(LInitNames) then
        SetLength(LInitNames, LInitCount + 16);
      LInitNames[LInitCount] := LFunc.Name;
      Inc(LInitCount);
    end
    else if Copy(LFunc.Name, 1, 14) = 'np_unit_fini_' then
    begin
      if LFiniCount >= Length(LFiniNames) then
        SetLength(LFiniNames, LFiniCount + 16);
      LFiniNames[LFiniCount] := LFunc.Name;
      Inc(LFiniCount);
    end;
    EmitFunction(LFunc);
  end;

  LEmitCtors := (LInitCount > 0) or (LFiniCount > 0);
  if LEmitCtors then
  begin
    if LInitCount > 0 then
    begin
      Emit('');
      Emit('@llvm.global_ctors = appending global [' + IntToStr(LInitCount) +
        ' x { i32, ptr, ptr }] [');
      for I := 0 to LInitCount - 1 do
      begin
        if I > 0 then Emit(',');
        Emit('  { i32 65535, ptr @' + LInitNames[I] + ', ptr null }');
      end;
      Emit(']');
    end;
    if LFiniCount > 0 then
    begin
      Emit('');
      Emit('@llvm.global_dtors = appending global [' + IntToStr(LFiniCount) +
        ' x { i32, ptr, ptr }] [');
      for I := 0 to LFiniCount - 1 do
      begin
        if I > 0 then Emit(',');
        Emit('  { i32 65535, ptr @' + LFiniNames[I] + ', ptr null }');
      end;
      Emit(']');
    end;
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

  if FNeedsMemcpy or FNeedsStringOwnership then
    EmitMemcpyHelper;

  if FNeedsObjectAlloc then
    EmitMemzeroHelper;

  if FNeedsStrConcat then
    EmitStrConcatHelper;

  if FNeedsStringOwnership then
    EmitStringOwnershipHelpers;

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
    Emit('');
    Emit('define internal i64 @np_str_cmp(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len) {');
    Emit('entry:');
    Emit('  %len_eq = icmp eq i64 %a_len, %b_len');
    Emit('  br i1 %len_eq, label %check_content, label %not_equal');
    Emit('check_content:');
    Emit('  %cmp0 = icmp eq i64 %a_len, 0');
    Emit('  br i1 %cmp0, label %equal, label %loop');
    Emit('loop:');
    Emit('  %i = phi i64 [ 0, %check_content ], [ %i_next, %loop_cont ]');
    Emit('  %ap = getelementptr i8, ptr %a_ptr, i64 %i');
    Emit('  %bp = getelementptr i8, ptr %b_ptr, i64 %i');
    Emit('  %ac = load i8, ptr %ap');
    Emit('  %bc = load i8, ptr %bp');
    Emit('  %eq = icmp eq i8 %ac, %bc');
    Emit('  br i1 %eq, label %loop_cont, label %not_equal');
    Emit('loop_cont:');
    Emit('  %i_next = add i64 %i, 1');
    Emit('  %done = icmp eq i64 %i_next, %a_len');
    Emit('  br i1 %done, label %equal, label %loop');
    Emit('equal:');
    Emit('  ret i64 1');
    Emit('not_equal:');
    Emit('  ret i64 0');
    Emit('}');
    Emit('');
    Emit('define internal i64 @np_str_pos(ptr %sub_ptr, i64 %sub_len, ptr %s_ptr, i64 %s_len) {');
    Emit('entry:');
    Emit('  %max = sub i64 %s_len, %sub_len');
    Emit('  %can = icmp sge i64 %max, 0');
    Emit('  br i1 %can, label %outer_loop, label %not_found');
    Emit('outer_loop:');
    Emit('  %oi = phi i64 [ 0, %entry ], [ %oi_next, %outer_cont ]');
    Emit('  br label %inner_loop');
    Emit('inner_loop:');
    Emit('  %ii = phi i64 [ 0, %outer_loop ], [ %ii_next, %inner_cont ]');
    Emit('  %sp = getelementptr i8, ptr %s_ptr, i64 %oi');
    Emit('  %spi = getelementptr i8, ptr %sp, i64 %ii');
    Emit('  %subp = getelementptr i8, ptr %sub_ptr, i64 %ii');
    Emit('  %sc = load i8, ptr %spi');
    Emit('  %subc = load i8, ptr %subp');
    Emit('  %match = icmp eq i8 %sc, %subc');
    Emit('  br i1 %match, label %inner_cont, label %outer_cont');
    Emit('inner_cont:');
    Emit('  %ii_next = add i64 %ii, 1');
    Emit('  %idone = icmp eq i64 %ii_next, %sub_len');
    Emit('  br i1 %idone, label %found, label %inner_loop');
    Emit('outer_cont:');
    Emit('  %oi_next = add i64 %oi, 1');
    Emit('  %odone = icmp sgt i64 %oi_next, %max');
    Emit('  br i1 %odone, label %not_found, label %outer_loop');
    Emit('found:');
    Emit('  %result = add i64 %oi, 1');
    Emit('  ret i64 %result');
    Emit('not_found:');
    Emit('  ret i64 0');
    Emit('}');
  end;

  if FNeedsIntToStr then
  begin
    Emit('');
    Emit('define internal {ptr, i64} @np_int_to_str(i64 %val) {');
    Emit('entry:');
    Emit('  %buf = call ptr @np_alloc(i64 21)');
    Emit('  %is_neg = icmp slt i64 %val, 0');
    Emit('  %abs_val = select i1 %is_neg, i64 0, i64 %val');
    Emit('  %neg_val = sub i64 0, %val');
    Emit('  %work = select i1 %is_neg, i64 %neg_val, i64 %val');
    Emit('  br label %digit_loop');
    Emit('digit_loop:');
    Emit('  %n = phi i64 [ %work, %entry ], [ %n_next, %digit_loop ]');
    Emit('  %pos = phi i64 [ 20, %entry ], [ %pos_next, %digit_loop ]');
    Emit('  %d = urem i64 %n, 10');
    Emit('  %c = add i64 %d, 48');
    Emit('  %ct = trunc i64 %c to i8');
    Emit('  %pos_next = sub i64 %pos, 1');
    Emit('  %dp = getelementptr i8, ptr %buf, i64 %pos_next');
    Emit('  store i8 %ct, ptr %dp');
    Emit('  %n_next = udiv i64 %n, 10');
    Emit('  %done = icmp eq i64 %n_next, 0');
    Emit('  br i1 %done, label %finish, label %digit_loop');
    Emit('finish:');
    Emit('  %start = select i1 %is_neg, i64 1, i64 0');
    Emit('  %final_pos = sub i64 %pos_next, %start');
    Emit('  br i1 %is_neg, label %add_sign, label %calc_result');
    Emit('add_sign:');
    Emit('  %sign_pos = sub i64 %pos_next, 1');
    Emit('  %sp = getelementptr i8, ptr %buf, i64 %sign_pos');
    Emit('  store i8 45, ptr %sp');
    Emit('  br label %calc_result');
    Emit('calc_result:');
    Emit('  %result_pos = phi i64 [ %pos_next, %finish ], [ %sign_pos, %add_sign ]');
    Emit('  %result_ptr = getelementptr i8, ptr %buf, i64 %result_pos');
    Emit('  %result_len = sub i64 20, %result_pos');
    Emit('  %r1 = insertvalue {ptr, i64} undef, ptr %result_ptr, 0');
    Emit('  %r2 = insertvalue {ptr, i64} %r1, i64 %result_len, 1');
    Emit('  ret {ptr, i64} %r2');
    Emit('}');
  end;
end;

procedure THIRLlvmEmitter.EmitWriteIntHelper;
begin
  Emit('');
  Emit('define internal void @write_i64_decimal(i64 %v) {');
  Emit('entry:');
  Emit('  %buf = alloca [24 x i8]');
  Emit('  %is_neg = icmp slt i64 %v, 0');
  Emit('  %neg_v = sub i64 0, %v');
  Emit('  %abs_v = select i1 %is_neg, i64 %neg_v, i64 %v');
  Emit('  %end_ptr = getelementptr [24 x i8], ptr %buf, i64 0, i64 24');
  Emit('  %first_ptr = getelementptr [24 x i8], ptr %buf, i64 0, i64 23');
  Emit('  br label %loop');
  Emit('loop:');
  Emit('  %cur = phi i64 [ %abs_v, %entry ], [ %nxt, %loop ]');
  Emit('  %ptr = phi ptr [ %first_ptr, %entry ], [ %ptr_prev, %loop ]');
  Emit('  %digit = urem i64 %cur, 10');
  Emit('  %digit_i8 = trunc i64 %digit to i8');
  Emit('  %digit_ascii = add i8 %digit_i8, 48');
  Emit('  store i8 %digit_ascii, ptr %ptr');
  Emit('  %nxt = udiv i64 %cur, 10');
  Emit('  %ptr_prev = getelementptr i8, ptr %ptr, i64 -1');
  Emit('  %done = icmp eq i64 %nxt, 0');
  Emit('  br i1 %done, label %neg_check, label %loop');
  Emit('neg_check:');
  Emit('  br i1 %is_neg, label %put_minus, label %finish');
  Emit('put_minus:');
  Emit('  store i8 45, ptr %ptr_prev');
  Emit('  %ptr_minus_prev = getelementptr i8, ptr %ptr_prev, i64 -1');
  Emit('  br label %finish');
  Emit('finish:');
  Emit('  %start_ptr = phi ptr [ %ptr_prev, %neg_check ], [ %ptr_minus_prev, %put_minus ]');
  Emit('  %start_next = getelementptr i8, ptr %start_ptr, i64 1');
  Emit('  %len = ptrtoint ptr %end_ptr to i64');
  Emit('  %start_int = ptrtoint ptr %start_next to i64');
  Emit('  %write_len = sub i64 %len, %start_int');
  Emit('  call void asm sideeffect "movq $$1, %rax; syscall",' +
    ' "{rdi},{rsi},{rdx},~{rax},~{rcx},~{r11},~{memory}"(i64 1, ptr %start_next, i64 %write_len)');
  Emit('  ret void');
  Emit('}');
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

procedure THIRLlvmEmitter.EmitAllocHelper;
begin
  Emit('');
  Emit('@__heap_cur = internal global ptr null');
  Emit('@__heap_free = internal global ptr null');
  Emit('');
  Emit('define internal ptr @np_alloc(i64 %size) {');
  Emit('entry:');
  Emit('  %alloc.is.large = icmp uge i64 %size, ' +
    IntToStr(NP_ALLOCATOR_LARGE_THRESHOLD));
  Emit('  br i1 %alloc.is.large, label %alloc.large, label %alloc.small.normalize');
  Emit('alloc.large:');
  Emit('  %alloc.large.rawlen = add i64 %size, ' +
    IntToStr(NP_ALLOCATOR_PRELUDE_SIZE));
  Emit('  %alloc.rawlen.overflow = icmp ult i64 %alloc.large.rawlen, %size');
  Emit('  br i1 %alloc.rawlen.overflow, label %alloc.fault.prelude, label %alloc.round');
  Emit('alloc.fault.prelude:');
  Emit('  call void @np_allocator_fault(i64 2, i64 %size, i64 ' +
    IntToStr(NP_ALLOCATOR_PRELUDE_SIZE) + ')');
  Emit('  unreachable');
  Emit('alloc.round:');
  Emit('  %alloc.large.plusmask = add i64 %alloc.large.rawlen, ' +
    IntToStr(NP_ALLOCATOR_PAGE_SIZE - 1));
  Emit('  %alloc.plusmask.overflow = icmp ult i64 %alloc.large.plusmask, %alloc.large.rawlen');
  Emit('  br i1 %alloc.plusmask.overflow, label %alloc.fault.round, label %alloc.mmap');
  Emit('alloc.fault.round:');
  Emit('  call void @np_allocator_fault(i64 3, i64 %alloc.large.rawlen, i64 ' +
    IntToStr(NP_ALLOCATOR_PAGE_SIZE) + ')');
  Emit('  unreachable');
  Emit('alloc.mmap:');
  Emit('  %alloc.mapped.len = and i64 %alloc.large.plusmask, -' +
    IntToStr(NP_ALLOCATOR_PAGE_SIZE));
  Emit('  %alloc.mmap.result = call i64 asm sideeffect "movq $$9, %rax\0Axorq %rdi, %rdi\0Amovq $$3, %rdx\0Amovq $$34, %r10\0Amovq $$-1, %r8\0Axorq %r9, %r9\0Asyscall", "={rax},{rsi},~{rcx},~{r11},~{rdi},~{rdx},~{r10},~{r8},~{r9},~{memory}"(i64 %alloc.mapped.len)');
  Emit('  %alloc.mmap.failed = icmp eq i64 %alloc.mmap.result, -1');
  Emit('  br i1 %alloc.mmap.failed, label %alloc.fault.mmap, label %alloc.write.prelude');
  Emit('alloc.fault.mmap:');
  Emit('  call void @np_allocator_fault(i64 4, i64 %size, i64 %alloc.mapped.len)');
  Emit('  unreachable');
  Emit('alloc.write.prelude:');
  Emit('  %alloc.large.base = inttoptr i64 %alloc.mmap.result to ptr');
  Emit('  store i64 ' + NP_ALLOCATOR_LARGE_MAGIC + ', ptr %alloc.large.base');
  Emit('  %alloc.large.lenp = getelementptr i8, ptr %alloc.large.base, i64 8');
  Emit('  store i64 %alloc.mapped.len, ptr %alloc.large.lenp');
  Emit('  %alloc.payload = getelementptr i8, ptr %alloc.large.base, i64 ' +
    IntToStr(NP_ALLOCATOR_PRELUDE_SIZE));
  Emit('  ret ptr %alloc.payload');
  Emit('');
  Emit('alloc.small.normalize:');
  Emit('  %alloc.too.small = icmp ult i64 %size, ' +
    IntToStr(NP_ALLOCATOR_MIN_SMALL_BLOCK_SIZE));
  Emit('  %alloc.size = select i1 %alloc.too.small, i64 ' +
    IntToStr(NP_ALLOCATOR_MIN_SMALL_BLOCK_SIZE) + ', i64 %size');
  Emit('  br label %free.scan');
  Emit('free.scan:');
  Emit('  %free.linkslot = phi ptr [ @__heap_free, %alloc.small.normalize ], [ %free.nextslot, %free.advance ]');
  Emit('  %free.head = load ptr, ptr %free.linkslot');
  Emit('  %free.has = icmp ne ptr %free.head, null');
  Emit('  br i1 %free.has, label %free.check, label %init');
  Emit('free.check:');
  Emit('  %free.size = load i64, ptr %free.head');
  Emit('  %free.fits = icmp uge i64 %free.size, %alloc.size');
  Emit('  br i1 %free.fits, label %reuse, label %free.advance');
  Emit('free.advance:');
  Emit('  %free.nextslot = getelementptr i8, ptr %free.head, i64 16');
  Emit('  br label %free.scan');
  Emit('reuse:');
  Emit('  %free.nextp = getelementptr i8, ptr %free.head, i64 16');
  Emit('  %free.next = load ptr, ptr %free.nextp');
  Emit('  store ptr %free.next, ptr %free.linkslot');
  Emit('  ret ptr %free.head');
  Emit('init:');
  Emit('  %cur = load ptr, ptr @__heap_cur');
  Emit('  %is_null = icmp eq ptr %cur, null');
  Emit('  br i1 %is_null, label %heap.init, label %alloc');
  Emit('heap.init:');
  Emit('  %brk0 = call i64 asm sideeffect "movq $$12, %rax\0Axorq %rdi, %rdi\0Asyscall", "={rax},~{rcx},~{r11},~{rdi}"()');
  Emit('  %brk0p = inttoptr i64 %brk0 to ptr');
  Emit('  store ptr %brk0p, ptr @__heap_cur');
  Emit('  br label %alloc');
  Emit('alloc:');
  Emit('  %base = load ptr, ptr @__heap_cur');
  Emit('  %next = getelementptr i8, ptr %base, i64 %alloc.size');
  Emit('  %nexti = ptrtoint ptr %next to i64');
  Emit('  call i64 asm sideeffect "movq $$12, %rax\0Asyscall", "={rax},{rdi},~{rcx},~{r11}"(i64 %nexti)');
  Emit('  store ptr %next, ptr @__heap_cur');
  Emit('  ret ptr %base');
  Emit('}');
end;

procedure THIRLlvmEmitter.EmitMemcpyHelper;
begin
  Emit('');
  Emit('define internal void @np_memcpy(ptr %dst, ptr %src, i64 %n) {');
  Emit('entry:');
  Emit('  %cmp0 = icmp eq i64 %n, 0');
  Emit('  br i1 %cmp0, label %done, label %loop');
  Emit('loop:');
  Emit('  %i = phi i64 [ 0, %entry ], [ %i_next, %loop ]');
  Emit('  %sp = getelementptr i8, ptr %src, i64 %i');
  Emit('  %b = load i8, ptr %sp');
  Emit('  %dp = getelementptr i8, ptr %dst, i64 %i');
  Emit('  store i8 %b, ptr %dp');
  Emit('  %i_next = add i64 %i, 1');
  Emit('  %cond = icmp eq i64 %i_next, %n');
  Emit('  br i1 %cond, label %done, label %loop');
  Emit('done:');
  Emit('  ret void');
  Emit('}');
end;

procedure THIRLlvmEmitter.EmitMemzeroHelper;
begin
  Emit('');
  Emit('define internal void @np_memzero(ptr %dst, i64 %n) {');
  Emit('entry:');
  Emit('  %cmp0 = icmp eq i64 %n, 0');
  Emit('  br i1 %cmp0, label %done, label %loop');
  Emit('loop:');
  Emit('  %i = phi i64 [ 0, %entry ], [ %i_next, %loop ]');
  Emit('  %dp = getelementptr i8, ptr %dst, i64 %i');
  Emit('  store i8 0, ptr %dp');
  Emit('  %i_next = add i64 %i, 1');
  Emit('  %cond = icmp eq i64 %i_next, %n');
  Emit('  br i1 %cond, label %done, label %loop');
  Emit('done:');
  Emit('  ret void');
  Emit('}');
end;

procedure THIRLlvmEmitter.EmitStrConcatHelper;
begin
  Emit('');
  Emit('define internal {ptr, i64} @np_str_concat(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len) {');
  Emit('entry:');
  Emit('  %total = add i64 %a_len, %b_len');
  Emit('  %buf = call ptr @np_alloc(i64 %total)');
  Emit('  call void @np_memcpy(ptr %buf, ptr %a_ptr, i64 %a_len)');
  Emit('  %dst2 = getelementptr i8, ptr %buf, i64 %a_len');
  Emit('  call void @np_memcpy(ptr %dst2, ptr %b_ptr, i64 %b_len)');
  Emit('  %r1 = insertvalue {ptr, i64} undef, ptr %buf, 0');
  Emit('  %r2 = insertvalue {ptr, i64} %r1, i64 %total, 1');
  Emit('  ret {ptr, i64} %r2');
  Emit('}');
end;

procedure THIRLlvmEmitter.EmitStringOwnershipHelpers;
begin
  Emit('');
  Emit('define internal void @np_string_fault(i64 %code, i64 %arg0, i64 %arg1) {');
  Emit('entry:');
  Emit('  call void @llvm.trap()');
  Emit('  unreachable');
  Emit('}');
  Emit('');
  Emit('define internal void @np_string_release(ptr %owner, i64 %alloc_size) {');
  Emit('entry:');
  Emit('  %isnull = icmp eq ptr %owner, null');
  Emit('  br i1 %isnull, label %done, label %size.check');
  Emit('size.check:');
  Emit('  %size.zero = icmp eq i64 %alloc_size, 0');
  Emit('  br i1 %size.zero, label %size.fault, label %release');
  Emit('size.fault:');
  Emit('  call void @np_string_fault(i64 1, i64 %alloc_size, i64 0)');
  Emit('  unreachable');
  Emit('release:');
  Emit('  call void @np_free(ptr %owner, i64 %alloc_size)');
  Emit('  br label %done');
  Emit('done:');
  Emit('  ret void');
  Emit('}');
  Emit('');
  Emit('define internal {ptr, i64, ptr, i64} @np_str_concat_owned(ptr %a_ptr, i64 %a_len, ptr %b_ptr, i64 %b_len) {');
  Emit('entry:');
  Emit('  %total = add i64 %a_len, %b_len');
  Emit('  %total.overflow = icmp ult i64 %total, %a_len');
  Emit('  br i1 %total.overflow, label %fault.total, label %zero.check');
  Emit('fault.total:');
  Emit('  call void @np_string_fault(i64 2, i64 %a_len, i64 %b_len)');
  Emit('  unreachable');
  Emit('zero.check:');
  Emit('  %is.zero = icmp eq i64 %total, 0');
  Emit('  br i1 %is.zero, label %zero, label %alloc');
  Emit('zero:');
  Emit('  %z1 = insertvalue {ptr, i64, ptr, i64} undef, ptr null, 0');
  Emit('  %z2 = insertvalue {ptr, i64, ptr, i64} %z1, i64 0, 1');
  Emit('  %z3 = insertvalue {ptr, i64, ptr, i64} %z2, ptr null, 2');
  Emit('  %z4 = insertvalue {ptr, i64, ptr, i64} %z3, i64 0, 3');
  Emit('  ret {ptr, i64, ptr, i64} %z4');
  Emit('alloc:');
  Emit('  %buf = call ptr @np_alloc(i64 %total)');
  Emit('  call void @np_memcpy(ptr %buf, ptr %a_ptr, i64 %a_len)');
  Emit('  %dst2 = getelementptr i8, ptr %buf, i64 %a_len');
  Emit('  call void @np_memcpy(ptr %dst2, ptr %b_ptr, i64 %b_len)');
  Emit('  %r1 = insertvalue {ptr, i64, ptr, i64} undef, ptr %buf, 0');
  Emit('  %r2 = insertvalue {ptr, i64, ptr, i64} %r1, i64 %total, 1');
  Emit('  %r3 = insertvalue {ptr, i64, ptr, i64} %r2, ptr %buf, 2');
  Emit('  %r4 = insertvalue {ptr, i64, ptr, i64} %r3, i64 %total, 3');
  Emit('  ret {ptr, i64, ptr, i64} %r4');
  Emit('}');
  Emit('');
  Emit('define internal {ptr, i64, ptr, i64} @np_str_copy_owned(ptr %src_ptr, i64 %src_len, i64 %start, i64 %count) {');
  Emit('entry:');
  Emit('  %start.invalid = icmp sle i64 %start, 0');
  Emit('  %count.invalid = icmp sle i64 %count, 0');
  Emit('  %start.after = icmp sgt i64 %start, %src_len');
  Emit('  %empty.a = or i1 %start.invalid, %count.invalid');
  Emit('  %empty = or i1 %empty.a, %start.after');
  Emit('  br i1 %empty, label %zero, label %bounds');
  Emit('bounds:');
  Emit('  %offset = sub i64 %start, 1');
  Emit('  %available = sub i64 %src_len, %offset');
  Emit('  %too.long = icmp sgt i64 %count, %available');
  Emit('  %copy.len = select i1 %too.long, i64 %available, i64 %count');
  Emit('  %copy.zero = icmp eq i64 %copy.len, 0');
  Emit('  br i1 %copy.zero, label %zero, label %alloc');
  Emit('alloc:');
  Emit('  %src.slice = getelementptr i8, ptr %src_ptr, i64 %offset');
  Emit('  %buf = call ptr @np_alloc(i64 %copy.len)');
  Emit('  call void @np_memcpy(ptr %buf, ptr %src.slice, i64 %copy.len)');
  Emit('  %r1 = insertvalue {ptr, i64, ptr, i64} undef, ptr %buf, 0');
  Emit('  %r2 = insertvalue {ptr, i64, ptr, i64} %r1, i64 %copy.len, 1');
  Emit('  %r3 = insertvalue {ptr, i64, ptr, i64} %r2, ptr %buf, 2');
  Emit('  %r4 = insertvalue {ptr, i64, ptr, i64} %r3, i64 %copy.len, 3');
  Emit('  ret {ptr, i64, ptr, i64} %r4');
  Emit('zero:');
  Emit('  %z1 = insertvalue {ptr, i64, ptr, i64} undef, ptr null, 0');
  Emit('  %z2 = insertvalue {ptr, i64, ptr, i64} %z1, i64 0, 1');
  Emit('  %z3 = insertvalue {ptr, i64, ptr, i64} %z2, ptr null, 2');
  Emit('  %z4 = insertvalue {ptr, i64, ptr, i64} %z3, i64 0, 3');
  Emit('  ret {ptr, i64, ptr, i64} %z4');
  Emit('}');
  Emit('');
  Emit('define internal {ptr, i64, ptr, i64} @np_int_to_str_owned(i64 %val) {');
  Emit('entry:');
  Emit('  %buf = call ptr @np_alloc(i64 21)');
  Emit('  %is_neg = icmp slt i64 %val, 0');
  Emit('  %neg_val = sub i64 0, %val');
  Emit('  %work = select i1 %is_neg, i64 %neg_val, i64 %val');
  Emit('  br label %digit_loop');
  Emit('digit_loop:');
  Emit('  %n = phi i64 [ %work, %entry ], [ %n_next, %digit_loop ]');
  Emit('  %pos = phi i64 [ 20, %entry ], [ %pos_next, %digit_loop ]');
  Emit('  %d = urem i64 %n, 10');
  Emit('  %c = add i64 %d, 48');
  Emit('  %ct = trunc i64 %c to i8');
  Emit('  %pos_next = sub i64 %pos, 1');
  Emit('  %dp = getelementptr i8, ptr %buf, i64 %pos_next');
  Emit('  store i8 %ct, ptr %dp');
  Emit('  %n_next = udiv i64 %n, 10');
  Emit('  %done = icmp eq i64 %n_next, 0');
  Emit('  br i1 %done, label %finish, label %digit_loop');
  Emit('finish:');
  Emit('  %final_pos = phi i64 [ %pos_next, %digit_loop ]');
  Emit('  br i1 %is_neg, label %write_neg, label %ret');
  Emit('write_neg:');
  Emit('  %neg_pos = sub i64 %final_pos, 1');
  Emit('  %negp = getelementptr i8, ptr %buf, i64 %neg_pos');
  Emit('  store i8 45, ptr %negp');
  Emit('  br label %ret');
  Emit('ret:');
  Emit('  %result_pos = phi i64 [ %final_pos, %finish ], [ %neg_pos, %write_neg ]');
  Emit('  %result_ptr = getelementptr i8, ptr %buf, i64 %result_pos');
  Emit('  %result_len = sub i64 20, %result_pos');
  Emit('  %r1 = insertvalue {ptr, i64, ptr, i64} undef, ptr %result_ptr, 0');
  Emit('  %r2 = insertvalue {ptr, i64, ptr, i64} %r1, i64 %result_len, 1');
  Emit('  %r3 = insertvalue {ptr, i64, ptr, i64} %r2, ptr %buf, 2');
  Emit('  %r4 = insertvalue {ptr, i64, ptr, i64} %r3, i64 21, 3');
  Emit('  ret {ptr, i64, ptr, i64} %r4');
  Emit('}');
end;

procedure THIRLlvmEmitter.EmitDynArrayHelpers;
begin
  Emit('');
  Emit('define internal void @np_dynarray_fault(i64 %code, i64 %arg0, i64 %arg1) {');
  Emit('entry:');
  Emit('  call void @llvm.trap()');
  Emit('  unreachable');
  Emit('}');
  Emit('');
  Emit('define internal void @np_dynarray_release(ptr %ptr, i64 %len, i64 %elem_size) {');
  Emit('entry:');
  Emit('  %release.isnull = icmp eq ptr %ptr, null');
  Emit('  br i1 %release.isnull, label %release.done, label %release.elem.check');
  Emit('release.elem.check:');
  Emit('  %release.elem.zero = icmp eq i64 %elem_size, 0');
  Emit('  br i1 %release.elem.zero, label %release.fault.elem, label %release.size');
  Emit('release.fault.elem:');
  Emit('  call void @np_dynarray_fault(i64 1, i64 %len, i64 %elem_size)');
  Emit('  unreachable');
  Emit('release.size:');
  Emit('  %release.size.bytes = mul i64 %len, %elem_size');
  Emit('  %release.size.div = udiv i64 %release.size.bytes, %elem_size');
  Emit('  %release.size.ok = icmp eq i64 %release.size.div, %len');
  Emit('  br i1 %release.size.ok, label %release.zero.check, label %release.fault.size');
  Emit('release.fault.size:');
  Emit('  call void @np_dynarray_fault(i64 2, i64 %len, i64 %elem_size)');
  Emit('  unreachable');
  Emit('release.zero.check:');
  Emit('  %release.size.zero = icmp eq i64 %release.size.bytes, 0');
  Emit('  br i1 %release.size.zero, label %release.done, label %release.call');
  Emit('release.call:');
  Emit('  call void @np_free(ptr %ptr, i64 %release.size.bytes)');
  Emit('  br label %release.done');
  Emit('release.done:');
  Emit('  ret void');
  Emit('}');
  Emit('');
  Emit('define internal ptr @np_dynarray_resize(ptr %old_ptr, i64 %old_len, i64 %new_len, i64 %elem_size) {');
  Emit('entry:');
  Emit('  %resize.new.zero = icmp eq i64 %new_len, 0');
  Emit('  br i1 %resize.new.zero, label %resize.release.zero, label %resize.same.check');
  Emit('resize.release.zero:');
  Emit('  call void @np_dynarray_release(ptr %old_ptr, i64 %old_len, i64 %elem_size)');
  Emit('  ret ptr null');
  Emit('resize.same.check:');
  Emit('  %resize.same.len = icmp eq i64 %old_len, %new_len');
  Emit('  br i1 %resize.same.len, label %resize.same, label %resize.elem.check');
  Emit('resize.same:');
  Emit('  ret ptr %old_ptr');
  Emit('resize.elem.check:');
  Emit('  %resize.elem.zero = icmp eq i64 %elem_size, 0');
  Emit('  br i1 %resize.elem.zero, label %resize.fault.elem, label %resize.alloc.size');
  Emit('resize.fault.elem:');
  Emit('  call void @np_dynarray_fault(i64 3, i64 %new_len, i64 %elem_size)');
  Emit('  unreachable');
  Emit('resize.alloc.size:');
  Emit('  %resize.alloc.bytes = mul i64 %new_len, %elem_size');
  Emit('  %resize.alloc.div = udiv i64 %resize.alloc.bytes, %elem_size');
  Emit('  %resize.alloc.ok = icmp eq i64 %resize.alloc.div, %new_len');
  Emit('  br i1 %resize.alloc.ok, label %resize.alloc, label %resize.fault.alloc');
  Emit('resize.fault.alloc:');
  Emit('  call void @np_dynarray_fault(i64 4, i64 %new_len, i64 %elem_size)');
  Emit('  unreachable');
  Emit('resize.alloc:');
  Emit('  %resize.new.ptr = call ptr @np_alloc(i64 %resize.alloc.bytes)');
  Emit('  %resize.old.isnull = icmp eq ptr %old_ptr, null');
  Emit('  br i1 %resize.old.isnull, label %resize.done, label %resize.old.size');
  Emit('resize.old.size:');
  Emit('  %resize.old.bytes = mul i64 %old_len, %elem_size');
  Emit('  %resize.old.div = udiv i64 %resize.old.bytes, %elem_size');
  Emit('  %resize.old.ok = icmp eq i64 %resize.old.div, %old_len');
  Emit('  br i1 %resize.old.ok, label %resize.copy.select, label %resize.fault.old');
  Emit('resize.fault.old:');
  Emit('  call void @np_dynarray_fault(i64 5, i64 %old_len, i64 %elem_size)');
  Emit('  unreachable');
  Emit('resize.copy.select:');
  Emit('  %resize.copy.use.old = icmp ule i64 %old_len, %new_len');
  Emit('  %resize.copy.len = select i1 %resize.copy.use.old, i64 %old_len, i64 %new_len');
  Emit('  %resize.copy.bytes = mul i64 %resize.copy.len, %elem_size');
  Emit('  %resize.copy.div = udiv i64 %resize.copy.bytes, %elem_size');
  Emit('  %resize.copy.ok = icmp eq i64 %resize.copy.div, %resize.copy.len');
  Emit('  br i1 %resize.copy.ok, label %resize.copy.check, label %resize.fault.copy');
  Emit('resize.fault.copy:');
  Emit('  call void @np_dynarray_fault(i64 6, i64 %resize.copy.len, i64 %elem_size)');
  Emit('  unreachable');
  Emit('resize.copy.check:');
  Emit('  %resize.copy.zero = icmp eq i64 %resize.copy.bytes, 0');
  Emit('  br i1 %resize.copy.zero, label %resize.release.old, label %resize.copy');
  Emit('resize.copy:');
  Emit('  call void @np_memcpy(ptr %resize.new.ptr, ptr %old_ptr, i64 %resize.copy.bytes)');
  Emit('  br label %resize.release.old');
  Emit('resize.release.old:');
  Emit('  call void @np_dynarray_release(ptr %old_ptr, i64 %old_len, i64 %elem_size)');
  Emit('  br label %resize.done');
  Emit('resize.done:');
  Emit('  ret ptr %resize.new.ptr');
  Emit('}');
end;

procedure THIRLlvmEmitter.EmitObjectAllocHelper;
begin
  Emit('');
  Emit('define internal ptr @np_object_alloc(i64 %size) {');
  Emit('entry:');
  Emit('  %total = add i64 %size, 24');
  Emit('  %total.overflow = icmp ult i64 %total, %size');
  Emit('  br i1 %total.overflow, label %object.alloc.fault.total, label %object.alloc.header');
  Emit('object.alloc.fault.total:');
  Emit('  call void @np_allocator_fault(i64 1, i64 %size, i64 24)');
  Emit('  unreachable');
  Emit('object.alloc.header:');
  Emit('  %raw = call ptr @np_alloc(i64 %total)');
  Emit('  store i64 %size, ptr %raw');
  Emit('  %magicp = getelementptr i8, ptr %raw, i64 8');
  Emit('  store i64 1313882451, ptr %magicp');
  Emit('  %rcp = getelementptr i8, ptr %raw, i64 16');
  Emit('  store i64 0, ptr %rcp');
  Emit('  %obj = getelementptr i8, ptr %raw, i64 24');
  Emit('  call void @np_memzero(ptr %obj, i64 %size)');
  Emit('  ret ptr %obj');
  Emit('}');
end;

procedure THIRLlvmEmitter.EmitObjectFreeReleaseHelper;
begin
  Emit('');
  Emit('define internal void @np_object_free_release(ptr %obj) {');
  Emit('entry:');
  Emit('  %isnull = icmp eq ptr %obj, null');
  Emit('  br i1 %isnull, label %done, label %header');
  Emit('header:');
  Emit('  %raw = getelementptr i8, ptr %obj, i64 -24');
  Emit('  %size = load i64, ptr %raw');
  Emit('  %magicp = getelementptr i8, ptr %raw, i64 8');
  Emit('  %magic = load i64, ptr %magicp');
  Emit('  %magic.ok = icmp eq i64 %magic, 1313882451');
  Emit('  br i1 %magic.ok, label %release, label %invalid');
  Emit('invalid:');
  Emit('  call void @np_object_release_invalid(ptr %raw, i64 %size, i64 %magic)');
  Emit('  br label %done');
  Emit('release:');
  Emit('  call void @np_object_release_valid(ptr %raw, i64 %size)');
  Emit('  br label %done');
  Emit('done:');
  Emit('  ret void');
  Emit('}');
end;

procedure THIRLlvmEmitter.EmitObjectReleaseValidHelper;
begin
  Emit('');
  Emit('define internal void @np_object_release_valid(ptr %raw, i64 %size) {');
  Emit('entry:');
  Emit('  %released.magicp = getelementptr i8, ptr %raw, i64 8');
  Emit('  store i64 0, ptr %released.magicp');
  Emit('  %alloc.size = add i64 %size, 24');
  Emit('  call void @np_free(ptr %raw, i64 %alloc.size)');
  Emit('  ret void');
  Emit('}');
end;

procedure THIRLlvmEmitter.EmitFreeHelper;
begin
  Emit('');
  Emit('define internal void @np_free(ptr %raw, i64 %size) {');
  Emit('entry:');
  Emit('  %free.is.large = icmp uge i64 %size, ' +
    IntToStr(NP_ALLOCATOR_LARGE_THRESHOLD));
  Emit('  br i1 %free.is.large, label %free.large, label %free.small');
  Emit('free.large:');
  Emit('  %free.large.base = getelementptr i8, ptr %raw, i64 -' +
    IntToStr(NP_ALLOCATOR_PRELUDE_SIZE));
  Emit('  %free.large.magic = load i64, ptr %free.large.base');
  Emit('  %free.large.magic.ok = icmp eq i64 %free.large.magic, ' +
    NP_ALLOCATOR_LARGE_MAGIC);
  Emit('  br i1 %free.large.magic.ok, label %free.large.len.check, label %free.large.magic.fault');
  Emit('free.large.magic.fault:');
  Emit('  call void @np_allocator_fault(i64 5, i64 %size, i64 %free.large.magic)');
  Emit('  unreachable');
  Emit('free.large.len.check:');
  Emit('  %free.large.lenp = getelementptr i8, ptr %free.large.base, i64 8');
  Emit('  %free.large.len = load i64, ptr %free.large.lenp');
  Emit('  %free.large.min = add i64 %size, ' +
    IntToStr(NP_ALLOCATOR_PRELUDE_SIZE));
  Emit('  %free.large.min.overflow = icmp ult i64 %free.large.min, %size');
  Emit('  br i1 %free.large.min.overflow, label %free.large.len.fault, label %free.large.len.validate');
  Emit('free.large.len.validate:');
  Emit('  %free.large.len.ok = icmp uge i64 %free.large.len, %free.large.min');
  Emit('  br i1 %free.large.len.ok, label %free.large.munmap, label %free.large.len.fault');
  Emit('free.large.len.fault:');
  Emit('  call void @np_allocator_fault(i64 6, i64 %size, i64 %free.large.len)');
  Emit('  unreachable');
  Emit('free.large.munmap:');
  Emit('  %free.large.base.i = ptrtoint ptr %free.large.base to i64');
  Emit('  %free.munmap.result = call i64 asm sideeffect "movq $$11, %rax\0Asyscall", "={rax},{rdi},{rsi},~{rcx},~{r11},~{memory}"(i64 %free.large.base.i, i64 %free.large.len)');
  Emit('  %free.munmap.ok = icmp eq i64 %free.munmap.result, 0');
  Emit('  br i1 %free.munmap.ok, label %free.done, label %free.munmap.fault');
  Emit('free.munmap.fault:');
  Emit('  call void @np_allocator_fault(i64 7, i64 %free.large.base.i, i64 %free.large.len)');
  Emit('  unreachable');
  Emit('free.small:');
  Emit('  %free.too.small = icmp ult i64 %size, ' +
    IntToStr(NP_ALLOCATOR_MIN_SMALL_BLOCK_SIZE));
  Emit('  %free.size.normalized = select i1 %free.too.small, i64 ' +
    IntToStr(NP_ALLOCATOR_MIN_SMALL_BLOCK_SIZE) + ', i64 %size');
  Emit('  %free.end = getelementptr i8, ptr %raw, i64 %free.size.normalized');
  Emit('  %free.cur = load ptr, ptr @__heap_cur');
  Emit('  %free.is.top = icmp eq ptr %free.cur, %free.end');
  Emit('  br i1 %free.is.top, label %free.reclaim, label %free.push');
  Emit('free.reclaim:');
  Emit('  %free.rawi = ptrtoint ptr %raw to i64');
  Emit('  call i64 asm sideeffect "movq $$12, %rax\0Asyscall", "={rax},{rdi},~{rcx},~{r11}"(i64 %free.rawi)');
  Emit('  store ptr %raw, ptr @__heap_cur');
  Emit('  ret void');
  Emit('free.push:');
  Emit('  br label %coalesce.scan');
  Emit('coalesce.scan:');
  Emit('  %coalesce.raw = phi ptr [ %raw, %free.push ], [ %coalesce.raw, %coalesce.advance ], [ %coalesce.raw, %coalesce.merge ], [ %coalesce.head, %coalesce.merge.prev ]');
  Emit('  %coalesce.total = phi i64 [ %free.size.normalized, %free.push ], [ %coalesce.total, %coalesce.advance ], [ %free.merged.total, %coalesce.merge ], [ %free.prev.merged.total, %coalesce.merge.prev ]');
  Emit('  %coalesce.linkslot = phi ptr [ @__heap_free, %free.push ], [ %coalesce.nextslot, %coalesce.advance ], [ @__heap_free, %coalesce.merge ], [ @__heap_free, %coalesce.merge.prev ]');
  Emit('  %coalesce.end = getelementptr i8, ptr %coalesce.raw, i64 %coalesce.total');
  Emit('  %coalesce.head = load ptr, ptr %coalesce.linkslot');
  Emit('  %coalesce.has = icmp ne ptr %coalesce.head, null');
  Emit('  br i1 %coalesce.has, label %coalesce.check, label %free.insert');
  Emit('coalesce.check:');
  Emit('  %coalesce.size = load i64, ptr %coalesce.head');
  Emit('  %coalesce.match = icmp eq ptr %coalesce.end, %coalesce.head');
  Emit('  br i1 %coalesce.match, label %coalesce.merge, label %coalesce.check.prev');
  Emit('coalesce.check.prev:');
  Emit('  %coalesce.prev.end = getelementptr i8, ptr %coalesce.head, i64 %coalesce.size');
  Emit('  %coalesce.prev.match = icmp eq ptr %coalesce.prev.end, %coalesce.raw');
  Emit('  br i1 %coalesce.prev.match, label %coalesce.merge.prev, label %coalesce.advance');
  Emit('coalesce.advance:');
  Emit('  %coalesce.nextslot = getelementptr i8, ptr %coalesce.head, i64 16');
  Emit('  br label %coalesce.scan');
  Emit('coalesce.merge:');
  Emit('  %free.merged.total = add i64 %coalesce.total, %coalesce.size');
  Emit('  %coalesce.nextp = getelementptr i8, ptr %coalesce.head, i64 16');
  Emit('  %coalesce.next = load ptr, ptr %coalesce.nextp');
  Emit('  store ptr %coalesce.next, ptr %coalesce.linkslot');
  Emit('  br label %coalesce.scan');
  Emit('coalesce.merge.prev:');
  Emit('  %free.prev.merged.total = add i64 %coalesce.size, %coalesce.total');
  Emit('  %coalesce.prev.nextp = getelementptr i8, ptr %coalesce.head, i64 16');
  Emit('  %coalesce.prev.next = load ptr, ptr %coalesce.prev.nextp');
  Emit('  store ptr %coalesce.prev.next, ptr %coalesce.linkslot');
  Emit('  br label %coalesce.scan');
  Emit('free.insert:');
  Emit('  store i64 %coalesce.total, ptr %coalesce.raw');
  Emit('  %free.nextp = getelementptr i8, ptr %coalesce.raw, i64 16');
  Emit('  %free.old = load ptr, ptr @__heap_free');
  Emit('  store ptr %free.old, ptr %free.nextp');
  Emit('  store ptr %coalesce.raw, ptr @__heap_free');
  Emit('  br label %free.done');
  Emit('free.done:');
  Emit('  ret void');
  Emit('}');
end;

procedure THIRLlvmEmitter.EmitObjectReleaseInvalidHelper;
begin
  Emit('');
  Emit('define internal void @np_object_release_invalid(ptr %raw, i64 %size, i64 %magic) {');
  Emit('entry:');
  Emit('  call void @llvm.trap()');
  Emit('  unreachable');
  Emit('}');
end;

procedure THIRLlvmEmitter.EmitAllocatorFaultHelper;
begin
  Emit('');
  Emit('declare void @llvm.trap()');
  Emit('');
  Emit('define internal void @np_allocator_fault(i64 %code, i64 %arg0, i64 %arg1) {');
  Emit('entry:');
  Emit('  call void @llvm.trap()');
  Emit('  unreachable');
  Emit('}');
end;

procedure THIRLlvmEmitter.EmitIntfRefCountHelpers;
begin
  Emit('');
  Emit('define internal void @np_intf_addref(ptr %obj) {');
  Emit('entry:');
  Emit('  %isnull = icmp eq ptr %obj, null');
  Emit('  br i1 %isnull, label %done, label %inc');
  Emit('inc:');
  Emit('  %rcp = getelementptr i8, ptr %obj, i64 -8');
  Emit('  %old = load i64, ptr %rcp');
  Emit('  %new = add i64 %old, 1');
  Emit('  store i64 %new, ptr %rcp');
  Emit('  br label %done');
  Emit('done:');
  Emit('  ret void');
  Emit('}');
  Emit('');
  Emit('define internal void @np_intf_release(ptr %obj) {');
  Emit('entry:');
  Emit('  %isnull = icmp eq ptr %obj, null');
  Emit('  br i1 %isnull, label %done, label %dec');
  Emit('dec:');
  Emit('  %rcp = getelementptr i8, ptr %obj, i64 -8');
  Emit('  %old = load i64, ptr %rcp');
  Emit('  %new = sub i64 %old, 1');
  Emit('  store i64 %new, ptr %rcp');
  Emit('  br label %done');
  Emit('done:');
  Emit('  ret void');
  Emit('}');
end;

procedure THIRLlvmEmitter.EmitExceptionRuntimeHelpers;
begin
  Emit('');
  Emit('; --- Exception runtime (freestanding setjmp/longjmp) ---');
  Emit('@__np_exc_stack = internal global ptr null');
  Emit('@__np_exc_pending = internal global i1 false');
  Emit('@__np_exc_object = internal global ptr null');
  Emit('');
  Emit('define internal void @np_try_push(ptr %buf) {');
  Emit('entry:');
  Emit('  %old = load ptr, ptr @__np_exc_stack');
  Emit('  %slot = getelementptr [9 x ptr], ptr %buf, i64 0, i64 8');
  Emit('  store ptr %old, ptr %slot');
  Emit('  store ptr %buf, ptr @__np_exc_stack');
  Emit('  ret void');
  Emit('}');
  Emit('');
  Emit('define internal void @np_try_pop() {');
  Emit('entry:');
  Emit('  %buf = load ptr, ptr @__np_exc_stack');
  Emit('  %slot = getelementptr [9 x ptr], ptr %buf, i64 0, i64 8');
  Emit('  %prev = load ptr, ptr %slot');
  Emit('  store ptr %prev, ptr @__np_exc_stack');
  Emit('  ret void');
  Emit('}');
  Emit('');
  Emit('');
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
  Emit('');
  Emit('define internal void @np_raise() {');
  Emit('entry:');
  Emit('  store i1 true, ptr @__np_exc_pending');
  Emit('  %buf = load ptr, ptr @__np_exc_stack');
  Emit('  %is_null = icmp eq ptr %buf, null');
  Emit('  br i1 %is_null, label %abort, label %do_longjmp');
  Emit('abort:');
  Emit('  call void asm sideeffect "movq $$60, %rax; movq $$217, %rdi; syscall", "~{rax},~{rdi},~{rcx},~{r11}"()');
  Emit('  unreachable');
  Emit('do_longjmp:');
  Emit('  call void @longjmp(ptr %buf, i32 1)');
  Emit('  unreachable');
  Emit('}');
  Emit('');
  Emit('define internal void @np_finally_end() {');
  Emit('entry:');
  Emit('  %pending = load i1, ptr @__np_exc_pending');
  Emit('  br i1 %pending, label %reraise, label %done');
  Emit('reraise:');
  Emit('  call void @np_try_pop()');
  Emit('  call void @np_raise()');
  Emit('  unreachable');
  Emit('done:');
  Emit('  ret void');
  Emit('}');
  Emit('');
  Emit('define internal void @np_except_end() {');
  Emit('entry:');
  Emit('  store i1 false, ptr @__np_exc_pending');
  Emit('  ret void');
  Emit('}');
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
