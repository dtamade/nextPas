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
    FCurrentFuncIsTStringSret: Boolean;
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
    { Debug info metadata }
    FDebugInfoEnabled: Boolean;
    FDebugMetadata: array of string;
    FDebugMetadataCount: LongInt;
    FCurrentDISubprogram: LongInt;  { metadata index of current function's DISubprogram }
    FDIFileIndex: LongInt;          { metadata index of the DIFile }
    FDICUIndex: LongInt;            { metadata index of the DICompileUnit }
    function AddDebugMetadata(const AMetadata: string): LongInt;
    function EmitDILocation(ALine, ACol: LongInt): LongInt;
    procedure EmitDebugMetadataSection;
    procedure Emit(const S: string);
  public
    constructor Create(AModule: THIRModule); overload;
    constructor Create(AModule: THIRModule;
      const ALlvmTriple, ALlvmDataLayout: string;
      ADebugInfo: Boolean = False); overload;
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
    function IsTStringSretFunction(const AName: string): Boolean;
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
    procedure EmitUnitDeclares;
    procedure EmitUnitInitCalls;
    procedure EmitUnitFiniCalls;
    procedure EmitModule;
    function AsText: string;
    procedure SaveToFile(const APath: string);
  end;

implementation
{$I np_hir_llvm_emitter_instr_helpers.inc}
procedure THIRLlvmEmitter.EmitInstr(const AInstr: THIRInstr);
var
  LlvmType, Op, LTruncVal: string;
  I, LDbgIdx: LongInt;
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
          if TypeToLlvm(AInstr.TypeId) = 'void' then
            Op := '  call void '
          else
            Op := '  ' + ValueRef(AInstr.ResultId) + ' = call ' + TypeToLlvm(AInstr.TypeId) + ' ';
          Op := Op + ValueRef(AInstr.Operands[0].ValueId) +
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
          if AInstr.ResultId > 0 then
          begin
            Emit('  ' + ValueRef(AInstr.ResultId) + ' = trunc i64 ' +
              ValueRef(AInstr.Operands[2].ValueId) + ' to i8');
            Emit('  call void @np_memset(ptr ' +
              ValueRef(AInstr.Operands[0].ValueId) + ', i8 ' +
              ValueRef(AInstr.ResultId) + ', i64 ' +
              ValueRef(AInstr.Operands[1].ValueId) + ')');
          end
          else
          begin
            { No result ID - use inline trunc }
            Emit('  call void @np_memset(ptr ' +
              ValueRef(AInstr.Operands[0].ValueId) + ', i8 ' +
              'trunc (i64 ' + ValueRef(AInstr.Operands[2].ValueId) + ' to i8), i64 ' +
              ValueRef(AInstr.Operands[1].ValueId) + ')');
          end;
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
      else if AInstr.IntrinsicName = 'interlocked-cas' then
      begin
        if Length(AInstr.Operands) >= 3 then
        begin
          Emit('  %cas.pair.' + IntToStr(AInstr.ResultId) +
            ' = cmpxchg ptr ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', i64 ' + ValueRef(AInstr.Operands[2].ValueId) +
            ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) +
            ' seq_cst seq_cst');
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = extractvalue { i64, i1 } %cas.pair.' +
            IntToStr(AInstr.ResultId) + ', 0');
        end;
      end
      else if AInstr.IntrinsicName = 'interlocked-cas64' then
      begin
        if Length(AInstr.Operands) >= 3 then
        begin
          Emit('  %cas64.pair.' + IntToStr(AInstr.ResultId) +
            ' = cmpxchg ptr ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', i64 ' + ValueRef(AInstr.Operands[2].ValueId) +
            ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) +
            ' seq_cst seq_cst');
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = extractvalue { i64, i1 } %cas64.pair.' +
            IntToStr(AInstr.ResultId) + ', 0');
        end;
      end
      else if AInstr.IntrinsicName = 'interlocked-xchg' then
      begin
        if Length(AInstr.Operands) >= 2 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = atomicrmw xchg ptr ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ' seq_cst');
      end
      else if AInstr.IntrinsicName = 'interlocked-fetch-add' then
      begin
        if Length(AInstr.Operands) >= 2 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = atomicrmw add ptr ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ' seq_cst');
      end
      else if AInstr.IntrinsicName = 'interlocked-fetch-add64' then
      begin
        if Length(AInstr.Operands) >= 2 then
          Emit('  ' + ValueRef(AInstr.ResultId) +
            ' = atomicrmw add ptr ' + ValueRef(AInstr.Operands[0].ValueId) +
            ', i64 ' + ValueRef(AInstr.Operands[1].ValueId) + ' seq_cst');
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
        begin
          { Use %agg.result for TString sret functions (sret_ptr is skipped) }
          if FCurrentFuncIsTStringSret then
            Emit('  call void @np_tstring_ret_move(ptr %agg.result, ptr ' +
              ValueRef(AInstr.Operands[1].ValueId) + ')')
          else
            Emit('  call void @np_tstring_ret_move(ptr ' +
              ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
              ValueRef(AInstr.Operands[1].ValueId) + ')');
        end;
      end
      else if AInstr.IntrinsicName = 'tstring_ret_copy' then
      begin
        FNeedsTStringRuntime := True;
        if Length(AInstr.Operands) >= 2 then
        begin
          if FCurrentFuncIsTStringSret then
            Emit('  call void @np_tstring_ret_copy(ptr %agg.result, ptr ' +
              ValueRef(AInstr.Operands[1].ValueId) + ')')
          else
            Emit('  call void @np_tstring_ret_copy(ptr ' +
              ValueRef(AInstr.Operands[0].ValueId) + ', ptr ' +
              ValueRef(AInstr.Operands[1].ValueId) + ')');
        end;
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
    hikConstFloat:
    begin
      { Emit float constant as hex-encoded double for LLVM IR }
      Emit('  ' + ValueRef(AInstr.ResultId) + ' = fadd double 0.0, ' +
        FormatFloat('0.0################', AInstr.FloatValue));
    end;

    hikGetFieldPtr:
      if Length(AInstr.Operands) >= 1 then
      begin
        if AInstr.StructTypeName <> '' then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = getelementptr %' +
            AInstr.StructTypeName + ', %' + AInstr.StructTypeName + '* ' +
            ValueRef(AInstr.Operands[0].ValueId) +
            ', i32 0, i32 ' + IntToStr(AInstr.FieldIndex))
        else
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = getelementptr ' +
            LlvmType + ', ' + LlvmType + '* ' +
            ValueRef(AInstr.Operands[0].ValueId) +
            ', i32 0, i32 ' + IntToStr(AInstr.FieldIndex));
      end;

    hikExtractField:
      if Length(AInstr.Operands) >= 1 then
      begin
        if AInstr.StructTypeName <> '' then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = extractvalue %' +
            AInstr.StructTypeName + ' ' +
            ValueRef(AInstr.Operands[0].ValueId) +
            ', ' + IntToStr(AInstr.FieldIndex))
        else
          Emit('  ; hikExtractField: no struct type name');
      end;

    hikInsertField:
      if Length(AInstr.Operands) >= 2 then
      begin
        if AInstr.StructTypeName <> '' then
          Emit('  ' + ValueRef(AInstr.ResultId) + ' = insertvalue %' +
            AInstr.StructTypeName + ' ' +
            ValueRef(AInstr.Operands[0].ValueId) + ', ' +
            LlvmType + ' ' + ValueRef(AInstr.Operands[1].ValueId) +
            ', ' + IntToStr(AInstr.FieldIndex))
        else
          Emit('  ; hikInsertField: no struct type name');
      end;
  end;

  { Append debug location metadata if available }
  if FDebugInfoEnabled and (FCurrentDISubprogram >= 0) and
    (AInstr.SourceLine > 0) and (FLineCount > 0) then
  begin
    LDbgIdx := EmitDILocation(AInstr.SourceLine, AInstr.SourceCol);
    if LDbgIdx >= 0 then
      FLines[FLineCount - 1] := FLines[FLineCount - 1] +
        ', !dbg !' + IntToStr(LDbgIdx);
  end;
end;

{$I np_hir_llvm_emitter_emit.inc}
procedure THIRLlvmEmitter.EmitModule;
var
  I: LongInt;
  G: THIRGlobal;
  GType: THIRTypeRec;
  LFunc: THIRFunction;
  LAlreadyEmitted: Boolean;
  J: LongInt;
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
  Emit('');

  { Initialize debug info metadata if enabled }
  if FDebugInfoEnabled then
  begin
    FDebugMetadataCount := 0;
    { !0 = !DIFile }
    FDIFileIndex := AddDebugMetadata(
      '!DIFile(filename: "' + EscapeLlvmStr(FModule.ModuleName) +
      '.pas", directory: ".")');
    { !1 = !DICompileUnit }
    FDICUIndex := AddDebugMetadata(
      '!DICompileUnit(language: DW_LANG_Pascal, file: !' +
      IntToStr(FDIFileIndex) +
      ', producer: "nextPas", isOptimized: false, emissionKind: FullDebug)');
  end;

  Emit('%TString = type [24 x i8]');

  for I := 0 to FModule.Types.Count - 1 do
  begin
    GType := FModule.Types.GetType(I);
    if GType.Kind = htkRecord then
    begin
      Emit('');
      Emit('%' + GType.Name + ' = type {');
      for J := 0 to High(GType.Fields) do
      begin
        if J > 0 then Emit(', ');
        Emit(TypeToLlvm(GType.Fields[J].TypeId));
      end;
      Emit('}');
    end;
  end;
  Emit('');

  for I := 0 to FModule.GlobalCount - 1 do
  begin
    G := FModule.GlobalAt(I);
    Emit('');
    if G.IsThreadVar then
    begin
      if FModule.Types.GetType(G.TypeId).Kind = htkPointer then
        Emit('@g_' + G.Name + ' = internal thread_local global ptr null')
      else
        Emit('@g_' + G.Name + ' = internal thread_local global i64 0');
    end
    else
    begin
      if FModule.Types.GetType(G.TypeId).Kind = htkPointer then
        Emit('@g_' + G.Name + ' = internal global ptr null')
      else
        Emit('@g_' + G.Name + ' = internal global i64 0');
    end;
  end;

  for I := 0 to FModule.FunctionCount - 1 do
  begin
    LFunc := FModule.FunctionAt(I);
    { Skip duplicate function definitions }
    if I > 0 then
    begin
      LAlreadyEmitted := False;
      for J := 0 to I - 1 do
        if SameText(FModule.FunctionAt(J).Name, LFunc.Name) then
        begin
          LAlreadyEmitted := True;
          Break;
        end;
      if LAlreadyEmitted then
        Continue;
    end;
    EmitFunction(LFunc);
  end;

  if FNeedsProcessLifecycle then
  begin
    Emit('');
    Emit('declare void @np_process_init()');
    Emit('declare void @np_process_fini()');
  end;

  { Emit declare for unit init/fini symbols so LLVM opt does not reject them as undefined }
  if FModule.UnitInitOrderCount > 0 then
  begin
    Emit('');
    EmitUnitDeclares;
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

  { Emit debug info metadata section at the end of the module }
  if FDebugInfoEnabled then
    EmitDebugMetadataSection;
end;

{$I np_hir_llvm_emitter_helpers.inc}

end.
