unit np_hir_llvm_emitter;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  np_hir_types, np_hir_model,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

const
  { 默认目标元数据 —— 仅当 emitter 未被注入 target facts 时回退使用，
    保持旧调用方（无参构造）行为等价于历史硬编码值。 }
  DEFAULT_LLVM_TRIPLE = 'x86_64-unknown-linux-gnu';
  DEFAULT_LLVM_DATALAYOUT =
    'e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64';

type
  TLlvmLineVec = specialize TVec<string>;
  TLlvmNameVec = specialize TVec<string>;
  TLlvmValueIdVec = specialize TVec<THIRValueId>;

  THIRLlvmEmitter = class
  private
    FModule: THIRModule;
    FLlvmTriple: string;
    FLlvmDataLayout: string;
    { Optional phase scratch for emit working TVecs. }
    FAllocator: IAllocator;
    FLines: TLlvmLineVec;
    FGlobalRefNames: TLlvmNameVec;
    FGlobalRefIds: TLlvmValueIdVec;
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
    FNeedsIntfRefCountHelpers: Boolean;
    FStrConstants: TLlvmNameVec;
    FCurrentReturnTypeId: THIRTypeId;
    FCurrentFuncIsTStringSret: Boolean;
    FIsCheckCounter: LongInt;
    FObjectFreeCounter: LongInt;
    FPendingObjectFreeActive: Boolean;
    FPendingObjectFreeReceiverValueId: THIRValueId;
    FPendingObjectFreeDestroyTarget: string;
    FPendingObjectFreeEndLabel: string;
    FNeedsExceptionRuntime: Boolean;
    FNeedsProcessLifecycle: Boolean;
    FProcessFiniEmitted: Boolean;
    FUnitInitCallsEmitted: Boolean;
    FUnitFiniCallsEmitted: Boolean;
    FTryCounter: LongInt;
    { ResultId -> actual LLVM type for the current function (1-based ValueId).
      Load/call/const may disagree with HIR TypeId (e.g. Integer i32 vs call i64). }
    FValueLlvmTypes: array of string;
    { Debug info metadata }
    FDebugInfoEnabled: Boolean;
    FDebugMetadata: TLlvmNameVec;
    FCurrentDISubprogram: LongInt;  { metadata index of current function's DISubprogram }
    FDIFileIndex: LongInt;          { metadata index of the DIFile }
    FDICUIndex: LongInt;            { metadata index of the DICompileUnit }
    procedure ClearGlobalRefs;
    function AddDebugMetadata(const AMetadata: string): LongInt;
    function EmitDILocation(ALine, ACol: LongInt): LongInt;
    procedure EmitDebugMetadataSection;
    procedure Emit(const S: string);
  public
    constructor Create(AModule: THIRModule); overload;
    constructor Create(AModule: THIRModule;
      const ALlvmTriple, ALlvmDataLayout: string;
      ADebugInfo: Boolean = False;
      AAllocator: IAllocator = nil); overload;
    destructor Destroy; override;
    function ValueRef(AValueId: THIRValueId): string;
    function TypeToLlvm(ATypeId: THIRTypeId): string;
    function BlockEndsWithIntrinsicReturn(const ABlock: THIRBlock): Boolean;
    function OperandTypeToLlvm(const AOperand: THIROperand;
      const AFallback: string): string;
    function ValueLlvmType(AValueId: THIRValueId;
      const AFallback: string): string;
    procedure NoteValueLlvmType(AValueId: THIRValueId; const ALlvmType: string);
    { Cast SSA value to AWantedTy when noted/hinted type differs; returns ref. }
    function EmitCastValueToLlvmType(AValueId: THIRValueId;
      const AWantedTy, ATag: string;
      const AHaveTyHint: string = ''): string;
    function IsUnsignedIntegerType(const ATypeId: THIRTypeId): Boolean;
    function IsUnsignedOrderedCompareType(const ATypeId: THIRTypeId): Boolean;
    function DivOpcodeToLlvm(const AInstr: THIRInstr): string;
    function ModOpcodeToLlvm(const AInstr: THIRInstr): string;
    function CompareOpcodeToLlvm(const AInstr: THIRInstr): string;
    function AddStrConstant(const AValue: string): LongInt;
    function EscapeLlvmStr(const AValue: string): string;
    { Bare LLVM global id, or "quoted" when name has operator chars (:=, <>, …). }
    function LlvmGlobalName(const AName: string): string;
    function LlvmGlobalRef(const AName: string): string;
    function IsSretFunction(const AName: string): Boolean;
    function IsTStringSretFunction(const AName: string): Boolean;
    procedure EmitFunction(const AFunc: THIRFunction);
    procedure EmitCallInstr(const AInstr: THIRInstr);
    procedure EmitIndirectCallInstr(const AInstr: THIRInstr);
    procedure ClosePendingObjectFreeGuard;
    function IsObjectFreeGuardContinuation(const AInstr: THIRInstr): Boolean;
    function EmitSystemContractInstr(const AInstr: THIRInstr): Boolean;
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
    function HasEmittedFunction(const AName: string): Boolean;
    function NormalizeUnitLifecycleName(const AUnitName: string): string;
    procedure EmitUnitDeclares;
    procedure EmitUnitInitCalls;
    procedure EmitUnitFiniCalls;
    procedure EmitModule;
    function AsText: string;
    procedure SaveToFile(const APath: string);
  end;

implementation
{$I np_hir_llvm_emitter_instr_helpers.inc}
{$I np_hir_llvm_emitter_instr.inc}

{$I np_hir_llvm_emitter_emit.inc}
procedure THIRLlvmEmitter.EmitModule;
var
  I: LongInt;
  G: THIRGlobal;
  GType: THIRTypeRec;
  LFunc: THIRFunction;
  LAlreadyEmitted: Boolean;
  J: LongInt;
  function HirFunctionInstrCount(const AFunc: THIRFunction): LongInt;
  var
    BI: LongInt;
  begin
    Result := 0;
    if AFunc.Blocks = nil then
      Exit;
    for BI := 0 to LongInt(AFunc.Blocks.Count) - 1 do
      if AFunc.Blocks[SizeUInt(BI)].Instrs <> nil then
        Inc(Result, LongInt(AFunc.Blocks[SizeUInt(BI)].Instrs.Count));
  end;
begin
  FLines.Clear;
  FStrConstants.Clear;
  FDebugMetadata.Clear;
  ClearGlobalRefs;
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
  FNeedsExceptionRuntime := False;
  FNeedsProcessLifecycle := False;
  FProcessFiniEmitted := False;
  FUnitInitCallsEmitted := False;
  FUnitFiniCallsEmitted := False;
  FTryCounter := 0;
  FObjectFreeCounter := 0;
  FPendingObjectFreeActive := False;
  FPendingObjectFreeReceiverValueId := 0;
  FPendingObjectFreeDestroyTarget := '';
  FPendingObjectFreeEndLabel := '';
  Emit('; ModuleID = ''' + FModule.ModuleName + '''');
  Emit('target triple = "' + FLlvmTriple + '"');
  Emit('target datalayout = "' + FLlvmDataLayout + '"');
  Emit('');

  { Initialize debug info metadata if enabled }
  if FDebugInfoEnabled then
  begin
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
      if GType.Fields <> nil then
        for J := 0 to LongInt(GType.Fields.Count) - 1 do
        begin
          if J > 0 then Emit(', ');
          Emit(TypeToLlvm(GType.Fields[SizeUInt(J)].TypeId));
        end;
      Emit('}');
    end;
  end;
  Emit('');

  for I := 0 to FModule.GlobalCount - 1 do
  begin
    G := FModule.GlobalAt(I);
    Emit('');
    GType := FModule.Types.GetType(G.TypeId);
    if G.IsThreadVar then
    begin
      if GType.Kind = htkPointer then
        Emit('@g_' + G.Name + ' = internal thread_local global ptr null')
      else
      begin
        { Match RegisterGlobal DeclType (e.g. Integer → i32). }
        if (G.TypeId = 0) or (TypeToLlvm(G.TypeId) = 'void') then
          Emit('@g_' + G.Name + ' = internal thread_local global i64 0')
        else if (GType.Kind = htkFloat) or
          SameText(TypeToLlvm(G.TypeId), 'float') or
          SameText(TypeToLlvm(G.TypeId), 'double') then
          Emit('@g_' + G.Name + ' = internal thread_local global ' +
            TypeToLlvm(G.TypeId) + ' 0.0')
        else if (GType.Kind = htkRecord) or (GType.Kind = htkArray) or
          (GType.Kind = htkDynArray) or
          (Copy(TypeToLlvm(G.TypeId), 1, 1) = '{') or
          (Copy(TypeToLlvm(G.TypeId), 1, 1) = '[') then
          Emit('@g_' + G.Name + ' = internal thread_local global ' +
            TypeToLlvm(G.TypeId) + ' zeroinitializer')
        else
          Emit('@g_' + G.Name + ' = internal thread_local global ' +
            TypeToLlvm(G.TypeId) + ' 0');
      end;
    end
    else
    begin
      if GType.Kind = htkPointer then
        Emit('@g_' + G.Name + ' = internal global ptr null')
      else
      begin
        { Match RegisterGlobal DeclType (e.g. Integer → i32). Hardcoding i64
          made load/store of unit vars like GMuAcc type-inconsistent. }
        if (G.TypeId = 0) or (TypeToLlvm(G.TypeId) = 'void') then
          Emit('@g_' + G.Name + ' = internal global i64 0')
        else if (GType.Kind = htkFloat) or
          SameText(TypeToLlvm(G.TypeId), 'float') or
          SameText(TypeToLlvm(G.TypeId), 'double') then
          Emit('@g_' + G.Name + ' = internal global ' +
            TypeToLlvm(G.TypeId) + ' 0.0')
        else if (GType.Kind = htkRecord) or (GType.Kind = htkArray) or
          (GType.Kind = htkDynArray) or
          (Copy(TypeToLlvm(G.TypeId), 1, 1) = '{') or
          (Copy(TypeToLlvm(G.TypeId), 1, 1) = '[') then
          Emit('@g_' + G.Name + ' = internal global ' +
            TypeToLlvm(G.TypeId) + ' zeroinitializer')
        else
          Emit('@g_' + G.Name + ' = internal global ' +
            TypeToLlvm(G.TypeId) + ' 0');
      end;
    end;
  end;

  for I := 0 to FModule.FunctionCount - 1 do
  begin
    LFunc := FModule.FunctionAt(I);
    { Same short/mangled name can appear twice (unit facade NewSHA256 vs real
      impl, TextFormat re-export, …). Prefer the *denser* body by instr count —
      last-wins dropped real class-new bodies when a later empty facade won. }
    LAlreadyEmitted := False;
    for J := 0 to FModule.FunctionCount - 1 do
    begin
      if J = I then
        Continue;
      if not SameText(FModule.FunctionAt(J).Name, LFunc.Name) then
        Continue;
      if HirFunctionInstrCount(FModule.FunctionAt(J)) >
        HirFunctionInstrCount(LFunc) then
      begin
        LAlreadyEmitted := True;
        Break;
      end;
      if (HirFunctionInstrCount(FModule.FunctionAt(J)) =
        HirFunctionInstrCount(LFunc)) and (J < I) then
      begin
        { Tie: keep first occurrence only. }
        LAlreadyEmitted := True;
        Break;
      end;
    end;
    if LAlreadyEmitted then
      Continue;
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

  if FStrConstants.Count > 0 then
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

  if FNeedsObjectAlloc or FNeedsIntfRefCountHelpers then
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

  { M2 residual fallback: declare remaining undefined for opt (wholesale per buckets) }
  Emit('');
  if not HasEmittedFunction('GetCurrentThreadId') then Emit('declare i64 @GetCurrentThreadId(...)');
  if not HasEmittedFunction('getcwd') then Emit('declare void @getcwd(ptr, i64, ptr)');
  if not HasEmittedFunction('a') then Emit('declare i64 @a(...)');
  if not HasEmittedFunction('aDst') then Emit('declare i64 @aDst(...)');
  if not HasEmittedFunction('aElementCount') then Emit('declare i64 @aElementCount(...)');
  if not HasEmittedFunction('b') then Emit('declare i64 @b(...)');
  if not HasEmittedFunction('IFile.Close') then Emit('declare i64 @IFile.Close(...)');
  if not HasEmittedFunction('IHasher.Write') then Emit('declare i64 @IHasher.Write(...)');
  if not HasEmittedFunction('Int') then Emit('declare i64 @Int(...)');
  if not HasEmittedFunction('MEM_ARENA_STRICT_ENV') then Emit('declare i64 @MEM_ARENA_STRICT_ENV(...)');
  if not HasEmittedFunction('MEM_DEBUG_ENV') then Emit('declare i64 @MEM_DEBUG_ENV(...)');
  if not HasEmittedFunction('MEM_HEAP_SAFETY_ENV') then Emit('declare i64 @MEM_HEAP_SAFETY_ENV(...)');
  if not HasEmittedFunction('np_open') then Emit('declare i64 @np_open(...)');
  if not HasEmittedFunction('np_opendir') then Emit('declare i64 @np_opendir(...)');
  if not HasEmittedFunction('np_read') then Emit('declare i64 @np_read(...)');
  if not HasEmittedFunction('np_readdir') then Emit('declare i64 @np_readdir(...)');
  if not HasEmittedFunction('np_realpath') then Emit('declare i64 @np_realpath(...)');
  if not HasEmittedFunction('np_stat') then Emit('declare i64 @np_stat(...)');
  if not HasEmittedFunction('NPSYSTEM_UNIT_FINI') then Emit('declare i64 @NPSYSTEM_UNIT_FINI(...)');
  if not HasEmittedFunction('NPSYSTEM_UNIT_INIT') then Emit('declare i64 @NPSYSTEM_UNIT_INIT(...)');
  if not HasEmittedFunction('PATH_ENV_PREFIX') then Emit('declare i64 @PATH_ENV_PREFIX(...)');
  if not HasEmittedFunction('PathSeparator') then Emit('declare i64 @PathSeparator(...)');
  if not HasEmittedFunction('PLATFORM_FS_SHORT_READ_ERROR') then Emit('declare i64 @PLATFORM_FS_SHORT_READ_ERROR(...)');
  if not HasEmittedFunction('platform_virtual_commit') then Emit('declare i64 @platform_virtual_commit(...)');
  if not HasEmittedFunction('platform_virtual_release') then Emit('declare i64 @platform_virtual_release(...)');
  if not HasEmittedFunction('platform_virtual_reserve') then Emit('declare i64 @platform_virtual_reserve(...)');
  if not HasEmittedFunction('Pointer.GetTypeMeta') then Emit('declare i64 @Pointer.GetTypeMeta(...)');
  if not HasEmittedFunction('Pointer.TokenCount') then Emit('declare i64 @Pointer.TokenCount(...)');
  if not HasEmittedFunction('Pointer.TypeCount') then Emit('declare i64 @Pointer.TypeCount(...)');
  if not HasEmittedFunction('Pos') then Emit('declare i64 @Pos(...)');
  if not HasEmittedFunction('PSizeUIntArray') then Emit('declare i64 @PSizeUIntArray(...)');
  if not HasEmittedFunction('Result') then Emit('declare i64 @Result(...)');
  if not HasEmittedFunction('SarLongint') then Emit('declare i64 @SarLongint(...)');
  if not HasEmittedFunction('system') then Emit('declare i64 @system(...)');
  if not HasEmittedFunction('TAstFacade.Destroy') then Emit('declare i64 @TAstFacade.Destroy(...)');
  if not HasEmittedFunction('TFileStream.ReadBuffer') then Emit('declare i64 @TFileStream.ReadBuffer(...)');
  if not HasEmittedFunction('TInterfaceSlotMeta.InterfaceName') then Emit('declare i64 @TInterfaceSlotMeta.InterfaceName(...)');
  if not HasEmittedFunction('TProcess.FCurrentDirectory') then Emit('declare i64 @TProcess.FCurrentDirectory(...)');
  if not HasEmittedFunction('TPthreadKeyDtor') then Emit('declare i64 @TPthreadKeyDtor(...)');
  if not HasEmittedFunction('TStringBuilder.ToString') then Emit('declare i64 @TStringBuilder.ToString(...)');
  if not HasEmittedFunction('TToolStatusEventVec.Count') then Emit('declare i64 @TToolStatusEventVec.Count(...)');
  if not HasEmittedFunction('TToolStatusEventVec.Create') then Emit('declare i64 @TToolStatusEventVec.Create(...)');
  if not HasEmittedFunction('TToolStatusEventVec.Push') then Emit('declare i64 @TToolStatusEventVec.Push(...)');

  { Emit debug info metadata section at the end of the module }
  if FDebugInfoEnabled then
    EmitDebugMetadataSection;

  { Shared by all define bodies (#0). Keep freestanding stack 16-byte aligned. }
  Emit('');
  Emit('attributes #0 = { alignstack=16 nounwind }');
end;

{$I np_hir_llvm_emitter_helpers.inc}

end.
