unit nextpas.compiler.ir.hir.llvm_emitter;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.compiler.ir.hir.types, nextpas.compiler.ir.hir.model,
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
      last-wins dropped real class-new bodies when a later empty facade won.
      LLVM identifiers are case-sensitive: @GetCwd (Pascal) and @getcwd
      (libc external) are distinct symbols, so compare exactly — SameText here
      wrongly let the Pascal define swallow the external declare. }
    LAlreadyEmitted := False;
    for J := 0 to FModule.FunctionCount - 1 do
    begin
      if J = I then
        Continue;
      if FModule.FunctionAt(J).Name <> LFunc.Name then
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

  { Emit debug info metadata section at the end of the module }
  if FDebugInfoEnabled then
    EmitDebugMetadataSection;

  { Shared by all define bodies (#0). Keep freestanding stack 16-byte aligned. }
  Emit('');
  Emit('attributes #0 = { alignstack=16 nounwind }');
end;

{$I np_hir_llvm_emitter_helpers.inc}

end.
