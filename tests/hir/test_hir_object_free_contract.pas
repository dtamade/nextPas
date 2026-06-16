program test_hir_object_free_contract;

{$mode objfpc}{$H+}

uses
  SysUtils, np_semantic_model, np_hir_types, np_hir_model,
  np_hir_builder, np_hir_llvm_emitter, np_hir_verifier;

var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  Verifier: THIRVerifier;
  Func: THIRFunction;
  Instr: THIRInstr;
  OperandType: THIRTypeRec;
  LlvmText: string;
  ReleaseHelperSlice: string;
  FoundContract: Boolean;
  FoundOwnedDestroy: Boolean;
  FoundHeapRelease: Boolean;
  FuncIndex, BlockIndex, InstrIndex: LongInt;
  NullCheckPos, BranchPos, DestroyLabelPos, DestroyCallPos, ReleaseCallPos,
  EndLabelPos, ReleaseHelperPos, MagicLoadPos, MagicCheckPos, MagicBranchPos,
  InvalidLabelPos, InvalidBoundaryCallPos, InvalidDoneBranchPos,
  ReleaseLabelPos, ReleaseBoundaryCallPos, ReleaseDoneBranchPos,
  ReleaseBoundaryHelperPos, ReleaseBoundaryMagicSlotPos,
  ReleaseBoundaryMagicStorePos, ReleaseBoundaryAllocSizePos,
  ReleaseBoundaryFreeCallPos,
  ReleaseBoundaryFreeHelperPos, InvalidBoundaryHelperPos, InvalidTrapCallPos,
  InvalidTrapUnreachablePos, InvalidTrapDeclarePos, FreeListGlobalPos,
  AllocLargeThresholdPos, AllocLargeBranchPos, AllocLargeRawLenPos,
  AllocLargePlusMaskPos, AllocMappedLenPos, AllocMmapCallPos,
  AllocPreludeMagicPos, AllocPreludeLenStorePos, AllocPayloadReturnPos,
  AllocFreeHeadLoadPos, AllocFreeSizeLoadPos, AllocFreeFitCheckPos,
  AllocFreeReuseBranchPos, AllocFreeNextSlotPos, AllocFreeNextLoadPos,
  AllocFreeAdvancePos, AllocFreeUnlinkSlotInitPos,
  AllocFreeUnlinkStorePos, AllocFreeReuseReturnPos, FreeTotalSizePos,
  FreeLargeThresholdPos, FreeLargeBranchPos, FreeLargeLabelPos,
  FreeLargeBasePos, FreeLargeMagicLoadPos, FreeLargeLenLoadPos,
  FreeLargeMinPos, FreeLargeLenCheckPos, FreeLargeMunmapCallPos,
  FreeSmallLabelPos, FreeEndPos, FreeCurLoadPos, FreeIsTopPos, FreeTopBranchPos,
  FreeReclaimLabelPos, FreeRawIntPos, FreeReclaimBrkPos,
  FreeHeapCurStorePos, FreeReclaimReturnPos, FreePushLabelPos,
  CoalesceRawPhiPos, CoalesceTotalPhiPos, CoalesceEndRuntimePos,
  CoalesceLinkSlotPos, CoalesceHeadLoadPos, CoalesceHasCheckPos,
  CoalesceHasBranchPos, CoalesceMatchPos, CoalesceBranchPos,
  CoalescePrevCheckLabelPos, CoalescePrevEndPos, CoalescePrevMatchPos,
  CoalescePrevBranchPos, CoalesceNextSlotPos, CoalesceAdvancePos,
  CoalesceSizeLoadPos, CoalesceMergedTotalPos, CoalesceNextLoadPos,
  CoalesceUnlinkStorePos, CoalesceMergePrevLabelPos,
  CoalescePrevMergedTotalPos, CoalescePrevNextLoadPos,
  CoalescePrevUnlinkStorePos, CoalesceMergeRestartPos,
  CoalescePrevMergeRestartPos, FreeInsertLabelPos, FreeInsertTotalStorePos,
  FreeNextSlotPos, FreeOldHeadLoadPos, FreeNextStorePos,
  FreeHeadPushPos, AllocatorFaultHelperPos, AllocatorFaultTrapPos: LongInt;

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-object-free-contract-failure=', AMessage);
  Halt(1);
end;

function FindAfter(const ANeedle, AText: string; AStart: LongInt): LongInt;
var
  Offset: LongInt;
begin
  if AStart < 1 then
    AStart := 1;
  Offset := Pos(ANeedle, Copy(AText, AStart, MaxInt));
  if Offset = 0 then
    Exit(0);
  Result := AStart + Offset - 1;
end;

function ExtractDefinitionSlice(const AText, AHeaderNeedle: string): string;
var
  StartPos, EndPos: LongInt;
begin
  Result := '';
  StartPos := Pos(AHeaderNeedle, AText);
  if StartPos = 0 then
    Exit;
  EndPos := FindAfter(LineEnding + '}', AText, StartPos);
  if EndPos = 0 then
    Exit;
  Result := Copy(AText, StartPos, EndPos - StartPos + Length(LineEnding + '}'));
end;

begin
  SemaModel := TSemanticModel.Create;
  Builder := nil;
  Emitter := nil;
  Verifier := nil;
  try
    SemaModel.AddTypedHirNode('var-decl-ptr-runtime', 'Worker', 0, 0, 'Worker');
    SemaModel.AddTypedHirNode(
      'object-free-runtime',
      'np.system.object_free',
      0,
      0,
      'var Worker' + #10 +
      'destroy TObject.Destroy' + #10 +
      'nil-guard true' + #10 +
      'heap-release true' + #10
    );
    SemaModel.AddTypedHirNode(
      'call-runtime',
      'TObject.Destroy',
      0,
      0,
      'TObject.Destroy' + #9 + 'var Worker' + #10
    );

    Builder := THIRBuilder.Create(SemaModel);
    Builder.Build;

    Verifier := THIRVerifier.Create(Builder.Module);
    if not Verifier.Verify then
      Fail('hir-verifier-error-count:' + IntToStr(Verifier.ErrorCount));

    FoundContract := False;
    FoundOwnedDestroy := False;
    FoundHeapRelease := False;
    for FuncIndex := 0 to Builder.Module.FunctionCount - 1 do
    begin
      Func := Builder.Module.FunctionAt(FuncIndex);
      for BlockIndex := 0 to High(Func.Blocks) do
        for InstrIndex := 0 to High(Func.Blocks[BlockIndex].Instrs) do
        begin
          Instr := Func.Blocks[BlockIndex].Instrs[InstrIndex];
          if (Instr.Kind = hikIntrinsic) and
            SameText(Instr.IntrinsicName, 'np.system.object_free') then
          begin
            if FoundContract then
              Fail('duplicate-object-free-contract');
            FoundContract := True;
            if not SameText(Instr.CallTarget, 'TObject.Destroy') then
              Fail('object-free-destroy-target-mismatch:' + Instr.CallTarget);
            if Length(Instr.Operands) <> 1 then
              Fail('object-free-receiver-operand-count:' +
                IntToStr(Length(Instr.Operands)));
            if Instr.Operands[0].TypeId = 0 then
              Fail('object-free-receiver-type-missing');
            OperandType := Builder.Module.Types.GetType(Instr.Operands[0].TypeId);
            if OperandType.Kind <> htkPointer then
              Fail('object-free-receiver-not-pointer');
          end;
          if (Instr.Kind = hikCall) and
            SameText(Instr.CallTarget, 'TObject.Destroy') then
            Fail('plain-object-free-destroy-call');
          if (Instr.Kind = hikIntrinsic) and
            SameText(Instr.IntrinsicName, 'np.system.object_free.destroy') then
          begin
            if FoundOwnedDestroy then
              Fail('duplicate-object-free-owned-destroy');
            FoundOwnedDestroy := True;
            if not SameText(Instr.CallTarget, 'TObject.Destroy') then
              Fail('object-free-owned-destroy-target-mismatch:' +
                Instr.CallTarget);
            if Length(Instr.Operands) <> 1 then
              Fail('object-free-owned-destroy-operand-count:' +
                IntToStr(Length(Instr.Operands)));
            if Instr.Operands[0].TypeId = 0 then
              Fail('object-free-owned-destroy-receiver-type-missing');
            OperandType := Builder.Module.Types.GetType(Instr.Operands[0].TypeId);
            if OperandType.Kind <> htkPointer then
              Fail('object-free-owned-destroy-receiver-not-pointer');
          end;
          if (Instr.Kind = hikIntrinsic) and
            SameText(Instr.IntrinsicName, 'np.system.object_free.release') then
          begin
            if FoundHeapRelease then
              Fail('duplicate-object-free-release');
            FoundHeapRelease := True;
            if Length(Instr.Operands) <> 1 then
              Fail('object-free-release-operand-count:' +
                IntToStr(Length(Instr.Operands)));
            if Instr.Operands[0].TypeId = 0 then
              Fail('object-free-release-receiver-type-missing');
            OperandType := Builder.Module.Types.GetType(Instr.Operands[0].TypeId);
            if OperandType.Kind <> htkPointer then
              Fail('object-free-release-receiver-not-pointer');
          end;
        end;
    end;

    if not FoundContract then
      Fail('missing-object-free-hir-intrinsic');
    if not FoundOwnedDestroy then
      Fail('missing-object-free-owned-destroy-intrinsic');
    if not FoundHeapRelease then
      Fail('missing-object-free-release-intrinsic');

    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;
    NullCheckPos := Pos('%objectfree.isnull.', LlvmText);
    if NullCheckPos = 0 then
      Fail('missing-object-free-llvm-null-check');
    if Pos(' = icmp eq ptr ', LlvmText) = 0 then
      Fail('missing-object-free-llvm-icmp-eq-ptr');
    BranchPos := FindAfter('br i1 %objectfree.isnull.', LlvmText, NullCheckPos);
    if BranchPos = 0 then
      Fail('missing-object-free-llvm-conditional-branch');
    DestroyLabelPos := FindAfter(LineEnding + 'objectfree.destroy.', LlvmText,
      BranchPos);
    if DestroyLabelPos = 0 then
      Fail('missing-object-free-llvm-destroy-label');
    DestroyCallPos := FindAfter('@TObject.Destroy', LlvmText, DestroyLabelPos);
    if DestroyCallPos = 0 then
      Fail('missing-object-free-llvm-destroy-call');
    ReleaseCallPos := FindAfter('call void @np_object_free_release(ptr ',
      LlvmText, DestroyCallPos);
    if ReleaseCallPos = 0 then
      Fail('missing-object-free-llvm-release-call-after-destroy');
    EndLabelPos := FindAfter(LineEnding + 'objectfree.end.', LlvmText,
      ReleaseCallPos);
    if EndLabelPos = 0 then
      Fail('missing-object-free-llvm-end-label-after-release');
    if not ((NullCheckPos < BranchPos) and (BranchPos < DestroyLabelPos) and
      (DestroyLabelPos < DestroyCallPos) and
      (DestroyCallPos < ReleaseCallPos) and (ReleaseCallPos < EndLabelPos)) then
      Fail('object-free-llvm-guard-order');
    ReleaseHelperPos := Pos('define internal void @np_object_free_release(ptr %obj)',
      LlvmText);
    if ReleaseHelperPos = 0 then
      Fail('missing-object-free-llvm-release-helper');
    ReleaseHelperSlice := ExtractDefinitionSlice(LlvmText,
      'define internal void @np_object_free_release(ptr %obj)');
    if ReleaseHelperSlice = '' then
      Fail('missing-object-free-release-helper-slice');
    if Pos('call void @np_dynarray_release(', ReleaseHelperSlice) <> 0 then
      Fail('object-free-release-helper-must-stay-field-agnostic');
    if Pos('@np_object_dynarray_cleanup_', ReleaseHelperSlice) <> 0 then
      Fail('object-free-release-helper-must-not-walk-fields');
    if FindAfter('%raw = getelementptr i8, ptr %obj, i64 -24', LlvmText,
      ReleaseHelperPos) = 0 then
      Fail('missing-object-free-release-header-base');
    if FindAfter('%size = load i64, ptr %raw', LlvmText, ReleaseHelperPos) = 0 then
      Fail('missing-object-free-release-header-size-load');
    if FindAfter('%magicp = getelementptr i8, ptr %raw, i64 8', LlvmText,
      ReleaseHelperPos) = 0 then
      Fail('missing-object-free-release-header-magic-slot');
    MagicLoadPos := FindAfter('%magic = load i64, ptr %magicp', LlvmText,
      ReleaseHelperPos);
    if MagicLoadPos = 0 then
      Fail('missing-object-free-release-header-magic-load');
    MagicCheckPos := FindAfter(
      '%magic.ok = icmp eq i64 %magic, 1313882451', LlvmText, MagicLoadPos);
    if MagicCheckPos = 0 then
      Fail('missing-object-free-release-header-magic-check');
    MagicBranchPos := FindAfter(
      'br i1 %magic.ok, label %release, label %invalid', LlvmText,
      MagicCheckPos);
    if MagicBranchPos = 0 then
      Fail('missing-object-free-release-header-magic-branch');
    InvalidLabelPos := FindAfter(LineEnding + 'invalid:', LlvmText,
      MagicBranchPos);
    if InvalidLabelPos = 0 then
      Fail('missing-object-free-release-invalid-label');
    InvalidBoundaryCallPos := FindAfter(
      'call void @np_object_release_invalid(ptr %raw, i64 %size, i64 %magic)',
      LlvmText, InvalidLabelPos);
    if InvalidBoundaryCallPos = 0 then
      Fail('missing-object-free-release-invalid-boundary-call');
    InvalidDoneBranchPos := FindAfter('br label %done', LlvmText,
      InvalidBoundaryCallPos);
    if InvalidDoneBranchPos = 0 then
      Fail('missing-object-free-release-invalid-joins-done');
    ReleaseLabelPos := FindAfter(LineEnding + 'release:', LlvmText,
      InvalidDoneBranchPos);
    if ReleaseLabelPos = 0 then
      Fail('missing-object-free-release-valid-label');
    ReleaseBoundaryCallPos := FindAfter(
      'call void @np_object_release_valid(ptr %raw, i64 %size)', LlvmText,
      ReleaseLabelPos);
    if ReleaseBoundaryCallPos = 0 then
      Fail('missing-object-free-release-valid-boundary-call');
    ReleaseDoneBranchPos := FindAfter('br label %done', LlvmText,
      ReleaseBoundaryCallPos);
    if ReleaseDoneBranchPos = 0 then
      Fail('missing-object-free-release-valid-joins-done');
    ReleaseBoundaryHelperPos := FindAfter(
      'define internal void @np_object_release_valid(ptr %raw, i64 %size)',
      LlvmText, ReleaseHelperPos);
    if ReleaseBoundaryHelperPos = 0 then
      Fail('missing-object-free-release-valid-helper');
    ReleaseBoundaryMagicSlotPos := FindAfter(
      '%released.magicp = getelementptr i8, ptr %raw, i64 8', LlvmText,
      ReleaseBoundaryHelperPos);
    if ReleaseBoundaryMagicSlotPos = 0 then
      Fail('missing-object-free-release-poison-magic-slot');
    ReleaseBoundaryMagicStorePos := FindAfter(
      'store i64 0, ptr %released.magicp', LlvmText,
      ReleaseBoundaryMagicSlotPos);
    if ReleaseBoundaryMagicStorePos = 0 then
      Fail('missing-object-free-release-poison-magic-store');
    ReleaseBoundaryAllocSizePos := FindAfter(
      '%alloc.size = add i64 %size, 24', LlvmText,
      ReleaseBoundaryMagicStorePos);
    if ReleaseBoundaryAllocSizePos = 0 then
      Fail('missing-object-free-release-valid-alloc-size');
    ReleaseBoundaryFreeCallPos := FindAfter(
      'call void @np_free(ptr %raw, i64 %alloc.size)', LlvmText,
      ReleaseBoundaryAllocSizePos);
    if ReleaseBoundaryFreeCallPos = 0 then
      Fail('missing-object-free-release-free-call');
    ReleaseBoundaryFreeHelperPos := FindAfter(
      'define internal void @np_free(ptr %raw, i64 %size)',
      LlvmText, ReleaseBoundaryHelperPos);
    if ReleaseBoundaryFreeHelperPos = 0 then
      Fail('missing-object-free-release-free-helper');
    FreeListGlobalPos := Pos('@__heap_free = internal global ptr null',
      LlvmText);
    if FreeListGlobalPos = 0 then
      Fail('missing-object-free-release-free-list-global');
    AllocLargeThresholdPos := FindAfter(
      '%alloc.is.large = icmp uge i64 %size, 65536', LlvmText,
      FreeListGlobalPos);
    if AllocLargeThresholdPos = 0 then
      Fail('missing-object-free-release-alloc-large-threshold');
    AllocLargeBranchPos := FindAfter(
      'br i1 %alloc.is.large, label %alloc.large, label %alloc.small.normalize',
      LlvmText, AllocLargeThresholdPos);
    if AllocLargeBranchPos = 0 then
      Fail('missing-object-free-release-alloc-large-branch');
    AllocLargeRawLenPos := FindAfter(
      '%alloc.large.rawlen = add i64 %size, 16', LlvmText,
      AllocLargeBranchPos);
    if AllocLargeRawLenPos = 0 then
      Fail('missing-object-free-release-alloc-large-rawlen');
    AllocLargePlusMaskPos := FindAfter(
      '%alloc.large.plusmask = add i64 %alloc.large.rawlen, 4095', LlvmText,
      AllocLargeRawLenPos);
    if AllocLargePlusMaskPos = 0 then
      Fail('missing-object-free-release-alloc-large-plusmask');
    AllocMappedLenPos := FindAfter(
      '%alloc.mapped.len = and i64 %alloc.large.plusmask, -4096', LlvmText,
      AllocLargePlusMaskPos);
    if AllocMappedLenPos = 0 then
      Fail('missing-object-free-release-alloc-mapped-len');
    AllocMmapCallPos := FindAfter('movq $$9, %rax', LlvmText,
      AllocMappedLenPos);
    if AllocMmapCallPos = 0 then
      Fail('missing-object-free-release-alloc-mmap-call');
    AllocPreludeMagicPos := FindAfter(
      'store i64 131388245100000016, ptr %alloc.large.base', LlvmText,
      AllocMmapCallPos);
    if AllocPreludeMagicPos = 0 then
      Fail('missing-object-free-release-alloc-prelude-magic-store');
    AllocPreludeLenStorePos := FindAfter(
      'store i64 %alloc.mapped.len, ptr %alloc.large.lenp', LlvmText,
      AllocPreludeMagicPos);
    if AllocPreludeLenStorePos = 0 then
      Fail('missing-object-free-release-alloc-prelude-len-store');
    AllocPayloadReturnPos := FindAfter('ret ptr %alloc.payload', LlvmText,
      AllocPreludeLenStorePos);
    if AllocPayloadReturnPos = 0 then
      Fail('missing-object-free-release-alloc-payload-return');
    if FindAfter(LineEnding + 'alloc.small.normalize:', LlvmText,
      AllocPayloadReturnPos) = 0 then
      Fail('missing-object-free-release-alloc-small-normalize-label');
    if FindAfter('%alloc.too.small = icmp ult i64 %size, 24', LlvmText,
      AllocPayloadReturnPos) = 0 then
      Fail('missing-object-free-release-alloc-small-min-check');
    if FindAfter(
      '%alloc.size = select i1 %alloc.too.small, i64 24, i64 %size',
      LlvmText, AllocPayloadReturnPos) = 0 then
      Fail('missing-object-free-release-alloc-size-normalized');
    AllocFreeHeadLoadPos := Pos(
      '%free.head = load ptr, ptr %free.linkslot', LlvmText);
    if AllocFreeHeadLoadPos = 0 then
      Fail('missing-object-free-release-alloc-free-head-load');
    AllocFreeSizeLoadPos := FindAfter(
      '%free.size = load i64, ptr %free.head', LlvmText,
      AllocFreeHeadLoadPos);
    if AllocFreeSizeLoadPos = 0 then
      Fail('missing-object-free-release-alloc-free-size-load');
    AllocFreeFitCheckPos := FindAfter(
      '%free.fits = icmp uge i64 %free.size, %alloc.size', LlvmText,
      AllocFreeSizeLoadPos);
    if AllocFreeFitCheckPos = 0 then
      Fail('missing-object-free-release-alloc-free-fit-check');
    AllocFreeReuseBranchPos := FindAfter(
      'br i1 %free.fits, label %reuse, label %free.advance', LlvmText,
      AllocFreeFitCheckPos);
    if AllocFreeReuseBranchPos = 0 then
      Fail('missing-object-free-release-alloc-free-reuse-branch');
    AllocFreeNextSlotPos := FindAfter(
      '%free.nextslot = getelementptr i8, ptr %free.head, i64 16', LlvmText,
      AllocFreeReuseBranchPos);
    if AllocFreeNextSlotPos = 0 then
      Fail('missing-object-free-release-alloc-free-next-slot');
    AllocFreeAdvancePos := FindAfter(
      'br label %free.scan', LlvmText, AllocFreeNextSlotPos);
    if AllocFreeAdvancePos = 0 then
      Fail('missing-object-free-release-alloc-free-advance');
    AllocFreeNextLoadPos := FindAfter(
      '%free.next = load ptr, ptr %free.nextp', LlvmText,
      AllocFreeAdvancePos);
    if AllocFreeNextLoadPos = 0 then
      Fail('missing-object-free-release-alloc-free-next-load');
    AllocFreeUnlinkSlotInitPos := FindAfter(
      '%free.linkslot = phi ptr [ @__heap_free, %alloc.small.normalize ], [ %free.nextslot, %free.advance ]',
      LlvmText, FreeListGlobalPos);
    if AllocFreeUnlinkSlotInitPos = 0 then
      Fail('missing-object-free-release-alloc-free-linkslot-phi');
    AllocFreeUnlinkStorePos := FindAfter(
      'store ptr %free.next, ptr %free.linkslot', LlvmText,
      AllocFreeNextLoadPos);
    if AllocFreeUnlinkStorePos = 0 then
      Fail('missing-object-free-release-alloc-free-unlink-store');
    AllocFreeReuseReturnPos := FindAfter('ret ptr %free.head', LlvmText,
      AllocFreeUnlinkStorePos);
    if AllocFreeReuseReturnPos = 0 then
      Fail('missing-object-free-release-alloc-free-reuse-return');
    FreeLargeThresholdPos := FindAfter(
      '%free.is.large = icmp uge i64 %size, 65536', LlvmText,
      ReleaseBoundaryFreeHelperPos);
    if FreeLargeThresholdPos = 0 then
      Fail('missing-object-free-release-free-large-threshold');
    FreeLargeBranchPos := FindAfter(
      'br i1 %free.is.large, label %free.large, label %free.small', LlvmText,
      FreeLargeThresholdPos);
    if FreeLargeBranchPos = 0 then
      Fail('missing-object-free-release-free-large-branch');
    FreeLargeLabelPos := FindAfter(LineEnding + 'free.large:', LlvmText,
      FreeLargeBranchPos);
    if FreeLargeLabelPos = 0 then
      Fail('missing-object-free-release-free-large-label');
    FreeLargeBasePos := FindAfter(
      '%free.large.base = getelementptr i8, ptr %raw, i64 -16', LlvmText,
      FreeLargeLabelPos);
    if FreeLargeBasePos = 0 then
      Fail('missing-object-free-release-free-large-base');
    FreeLargeMagicLoadPos := FindAfter(
      '%free.large.magic = load i64, ptr %free.large.base', LlvmText,
      FreeLargeBasePos);
    if FreeLargeMagicLoadPos = 0 then
      Fail('missing-object-free-release-free-large-magic-load');
    FreeLargeLenLoadPos := FindAfter(
      '%free.large.len = load i64, ptr %free.large.lenp', LlvmText,
      FreeLargeMagicLoadPos);
    if FreeLargeLenLoadPos = 0 then
      Fail('missing-object-free-release-free-large-len-load');
    FreeLargeMinPos := FindAfter(
      '%free.large.min = add i64 %size, 16', LlvmText,
      FreeLargeLenLoadPos);
    if FreeLargeMinPos = 0 then
      Fail('missing-object-free-release-free-large-min');
    FreeLargeLenCheckPos := FindAfter(
      '%free.large.len.ok = icmp uge i64 %free.large.len, %free.large.min',
      LlvmText, FreeLargeMinPos);
    if FreeLargeLenCheckPos = 0 then
      Fail('missing-object-free-release-free-large-len-check');
    FreeLargeMunmapCallPos := FindAfter('movq $$11, %rax', LlvmText,
      FreeLargeLenCheckPos);
    if FreeLargeMunmapCallPos = 0 then
      Fail('missing-object-free-release-free-large-munmap-call');
    FreeSmallLabelPos := FindAfter(LineEnding + 'free.small:', LlvmText,
      FreeLargeMunmapCallPos);
    if FreeSmallLabelPos = 0 then
      Fail('missing-object-free-release-free-small-label');
    if FindAfter('%free.too.small = icmp ult i64 %size, 24', LlvmText,
      FreeSmallLabelPos) = 0 then
      Fail('missing-object-free-release-free-small-min-check');
    if FindAfter(
      '%free.size.normalized = select i1 %free.too.small, i64 24, i64 %size',
      LlvmText, FreeSmallLabelPos) = 0 then
      Fail('missing-object-free-release-free-size-normalized');
    FreeEndPos := FindAfter(
      '%free.end = getelementptr i8, ptr %raw, i64 %free.size.normalized',
      LlvmText, FreeSmallLabelPos);
    if FreeEndPos = 0 then
      Fail('missing-object-free-release-free-end');
    FreeCurLoadPos := FindAfter('%free.cur = load ptr, ptr @__heap_cur',
      LlvmText, FreeEndPos);
    if FreeCurLoadPos = 0 then
      Fail('missing-object-free-release-free-cur-load');
    FreeIsTopPos := FindAfter(
      '%free.is.top = icmp eq ptr %free.cur, %free.end', LlvmText,
      FreeCurLoadPos);
    if FreeIsTopPos = 0 then
      Fail('missing-object-free-release-free-is-top');
    FreeTopBranchPos := FindAfter(
      'br i1 %free.is.top, label %free.reclaim, label %free.push',
      LlvmText, FreeIsTopPos);
    if FreeTopBranchPos = 0 then
      Fail('missing-object-free-release-free-top-branch');
    FreeReclaimLabelPos := FindAfter(LineEnding + 'free.reclaim:',
      LlvmText, FreeTopBranchPos);
    if FreeReclaimLabelPos = 0 then
      Fail('missing-object-free-release-free-reclaim-label');
    FreeRawIntPos := FindAfter('%free.rawi = ptrtoint ptr %raw to i64',
      LlvmText, FreeReclaimLabelPos);
    if FreeRawIntPos = 0 then
      Fail('missing-object-free-release-free-raw-int');
    FreeReclaimBrkPos := FindAfter(
      'call i64 asm sideeffect "movq $$12, %rax\0Asyscall", "={rax},{rdi},~{rcx},~{r11}"(i64 %free.rawi)',
      LlvmText, FreeRawIntPos);
    if FreeReclaimBrkPos = 0 then
      Fail('missing-object-free-release-free-reclaim-brk');
    FreeHeapCurStorePos := FindAfter('store ptr %raw, ptr @__heap_cur',
      LlvmText, FreeReclaimBrkPos);
    if FreeHeapCurStorePos = 0 then
      Fail('missing-object-free-release-free-heap-cur-store');
    FreeReclaimReturnPos := FindAfter('ret void', LlvmText,
      FreeHeapCurStorePos);
    if FreeReclaimReturnPos = 0 then
      Fail('missing-object-free-release-free-reclaim-return');
    FreePushLabelPos := FindAfter(LineEnding + 'free.push:', LlvmText,
      FreeReclaimReturnPos);
    if FreePushLabelPos = 0 then
      Fail('missing-object-free-release-free-push-label');
    CoalesceRawPhiPos := FindAfter(
      '%coalesce.raw = phi ptr [ %raw, %free.push ], [ %coalesce.raw, %coalesce.advance ], [ %coalesce.raw, %coalesce.merge ], [ %coalesce.head, %coalesce.merge.prev ]',
      LlvmText, FreePushLabelPos);
    if CoalesceRawPhiPos = 0 then
      Fail('missing-object-free-release-coalesce-raw-phi');
    CoalesceTotalPhiPos := FindAfter(
      '%coalesce.total = phi i64 [ %free.size.normalized, %free.push ], [ %coalesce.total, %coalesce.advance ], [ %free.merged.total, %coalesce.merge ], [ %free.prev.merged.total, %coalesce.merge.prev ]',
      LlvmText, CoalesceRawPhiPos);
    if CoalesceTotalPhiPos = 0 then
      Fail('missing-object-free-release-coalesce-total-phi');
    CoalesceLinkSlotPos := FindAfter(
      '%coalesce.linkslot = phi ptr [ @__heap_free, %free.push ], [ %coalesce.nextslot, %coalesce.advance ], [ @__heap_free, %coalesce.merge ], [ @__heap_free, %coalesce.merge.prev ]',
      LlvmText, CoalesceTotalPhiPos);
    if CoalesceLinkSlotPos = 0 then
      Fail('missing-object-free-release-coalesce-linkslot');
    CoalesceEndRuntimePos := FindAfter(
      '%coalesce.end = getelementptr i8, ptr %coalesce.raw, i64 %coalesce.total',
      LlvmText, CoalesceLinkSlotPos);
    if CoalesceEndRuntimePos = 0 then
      Fail('missing-object-free-release-coalesce-end');
    CoalesceHeadLoadPos := FindAfter(
      '%coalesce.head = load ptr, ptr %coalesce.linkslot', LlvmText,
      CoalesceLinkSlotPos);
    if CoalesceHeadLoadPos = 0 then
      Fail('missing-object-free-release-coalesce-head-load');
    CoalesceHasCheckPos := FindAfter(
      '%coalesce.has = icmp ne ptr %coalesce.head, null', LlvmText,
      CoalesceHeadLoadPos);
    if CoalesceHasCheckPos = 0 then
      Fail('missing-object-free-release-coalesce-has-check');
    CoalesceHasBranchPos := FindAfter(
      'br i1 %coalesce.has, label %coalesce.check, label %free.insert',
      LlvmText, CoalesceHasCheckPos);
    if CoalesceHasBranchPos = 0 then
      Fail('missing-object-free-release-coalesce-has-branch');
    CoalesceMatchPos := FindAfter(
      '%coalesce.match = icmp eq ptr %coalesce.end, %coalesce.head', LlvmText,
      CoalesceHasBranchPos);
    if CoalesceMatchPos = 0 then
      Fail('missing-object-free-release-coalesce-match');
    CoalesceBranchPos := FindAfter(
      'br i1 %coalesce.match, label %coalesce.merge, label %coalesce.check.prev',
      LlvmText, CoalesceMatchPos);
    if CoalesceBranchPos = 0 then
      Fail('missing-object-free-release-coalesce-prev-branch');
    CoalescePrevCheckLabelPos := FindAfter(LineEnding + 'coalesce.check.prev:',
      LlvmText, CoalesceBranchPos);
    if CoalescePrevCheckLabelPos = 0 then
      Fail('missing-object-free-release-coalesce-prev-check-label');
    CoalesceSizeLoadPos := FindAfter(
      '%coalesce.size = load i64, ptr %coalesce.head', LlvmText,
      CoalesceHasBranchPos);
    if CoalesceSizeLoadPos = 0 then
      Fail('missing-object-free-release-coalesce-size-load');
    CoalescePrevEndPos := FindAfter(
      '%coalesce.prev.end = getelementptr i8, ptr %coalesce.head, i64 %coalesce.size',
      LlvmText, CoalescePrevCheckLabelPos);
    if CoalescePrevEndPos = 0 then
      Fail('missing-object-free-release-coalesce-prev-end');
    CoalescePrevMatchPos := FindAfter(
      '%coalesce.prev.match = icmp eq ptr %coalesce.prev.end, %coalesce.raw',
      LlvmText, CoalescePrevEndPos);
    if CoalescePrevMatchPos = 0 then
      Fail('missing-object-free-release-coalesce-prev-match');
    CoalescePrevBranchPos := FindAfter(
      'br i1 %coalesce.prev.match, label %coalesce.merge.prev, label %coalesce.advance',
      LlvmText, CoalescePrevMatchPos);
    if CoalescePrevBranchPos = 0 then
      Fail('missing-object-free-release-coalesce-prev-match-branch');
    CoalesceNextSlotPos := FindAfter(
      '%coalesce.nextslot = getelementptr i8, ptr %coalesce.head, i64 16',
      LlvmText, CoalescePrevBranchPos);
    if CoalesceNextSlotPos = 0 then
      Fail('missing-object-free-release-coalesce-next-slot');
    CoalesceAdvancePos := FindAfter('br label %coalesce.scan', LlvmText,
      CoalesceNextSlotPos);
    if CoalesceAdvancePos = 0 then
      Fail('missing-object-free-release-coalesce-advance');
    CoalesceMergedTotalPos := FindAfter(
      '%free.merged.total = add i64 %coalesce.total, %coalesce.size',
      LlvmText, CoalesceSizeLoadPos);
    if CoalesceMergedTotalPos = 0 then
      Fail('missing-object-free-release-coalesce-merged-total');
    CoalesceNextLoadPos := FindAfter(
      '%coalesce.next = load ptr, ptr %coalesce.nextp', LlvmText,
      CoalesceMergedTotalPos);
    if CoalesceNextLoadPos = 0 then
      Fail('missing-object-free-release-coalesce-next-load');
    CoalesceUnlinkStorePos := FindAfter(
      'store ptr %coalesce.next, ptr %coalesce.linkslot', LlvmText,
      CoalesceNextLoadPos);
    if CoalesceUnlinkStorePos = 0 then
      Fail('missing-object-free-release-coalesce-unlink-store');
    CoalesceMergeRestartPos := FindAfter('br label %coalesce.scan', LlvmText,
      CoalesceUnlinkStorePos);
    if CoalesceMergeRestartPos = 0 then
      Fail('missing-object-free-release-coalesce-merge-restart');
    CoalesceMergePrevLabelPos := FindAfter(
      LineEnding + 'coalesce.merge.prev:', LlvmText, CoalesceMergeRestartPos);
    if CoalesceMergePrevLabelPos = 0 then
      Fail('missing-object-free-release-coalesce-merge-prev-label');
    CoalescePrevMergedTotalPos := FindAfter(
      '%free.prev.merged.total = add i64 %coalesce.size, %coalesce.total',
      LlvmText, CoalesceMergePrevLabelPos);
    if CoalescePrevMergedTotalPos = 0 then
      Fail('missing-object-free-release-coalesce-prev-merged-total');
    CoalescePrevNextLoadPos := FindAfter(
      '%coalesce.prev.next = load ptr, ptr %coalesce.prev.nextp',
      LlvmText, CoalescePrevMergedTotalPos);
    if CoalescePrevNextLoadPos = 0 then
      Fail('missing-object-free-release-coalesce-prev-next-load');
    CoalescePrevUnlinkStorePos := FindAfter(
      'store ptr %coalesce.prev.next, ptr %coalesce.linkslot',
      LlvmText, CoalescePrevNextLoadPos);
    if CoalescePrevUnlinkStorePos = 0 then
      Fail('missing-object-free-release-coalesce-prev-unlink-store');
    CoalescePrevMergeRestartPos := FindAfter('br label %coalesce.scan',
      LlvmText, CoalescePrevUnlinkStorePos);
    if CoalescePrevMergeRestartPos = 0 then
      Fail('missing-object-free-release-coalesce-prev-merge-restart');
    FreeInsertLabelPos := FindAfter(LineEnding + 'free.insert:', LlvmText,
      CoalescePrevMergeRestartPos);
    if FreeInsertLabelPos = 0 then
      Fail('missing-object-free-release-free-insert-label');
    FreeInsertTotalStorePos := FindAfter(
      'store i64 %coalesce.total, ptr %coalesce.raw', LlvmText,
      FreeInsertLabelPos);
    if FreeInsertTotalStorePos = 0 then
      Fail('missing-object-free-release-free-insert-total-store');
    FreeNextSlotPos := FindAfter(
      '%free.nextp = getelementptr i8, ptr %coalesce.raw, i64 16', LlvmText,
      FreeInsertTotalStorePos);
    if FreeNextSlotPos = 0 then
      Fail('missing-object-free-release-free-next-slot');
    FreeOldHeadLoadPos := FindAfter(
      '%free.old = load ptr, ptr @__heap_free', LlvmText, FreeNextSlotPos);
    if FreeOldHeadLoadPos = 0 then
      Fail('missing-object-free-release-free-old-head-load');
    FreeNextStorePos := FindAfter(
      'store ptr %free.old, ptr %free.nextp', LlvmText, FreeOldHeadLoadPos);
    if FreeNextStorePos = 0 then
      Fail('missing-object-free-release-free-next-store');
    FreeHeadPushPos := FindAfter('store ptr %coalesce.raw, ptr @__heap_free',
      LlvmText, FreeNextStorePos);
    if FreeHeadPushPos = 0 then
      Fail('missing-object-free-release-free-head-push');
    InvalidBoundaryHelperPos := FindAfter(
      'define internal void @np_object_release_invalid(ptr %raw, i64 %size, i64 %magic)',
      LlvmText, ReleaseBoundaryFreeHelperPos);
    if InvalidBoundaryHelperPos = 0 then
      Fail('missing-object-free-release-invalid-helper');
    InvalidTrapCallPos := FindAfter('call void @llvm.trap()', LlvmText,
      InvalidBoundaryHelperPos);
    if InvalidTrapCallPos = 0 then
      Fail('missing-object-free-release-invalid-trap-call');
    InvalidTrapUnreachablePos := FindAfter('  unreachable', LlvmText,
      InvalidTrapCallPos);
    if InvalidTrapUnreachablePos = 0 then
      Fail('missing-object-free-release-invalid-unreachable');
    InvalidTrapDeclarePos := FindAfter('declare void @llvm.trap()', LlvmText,
      InvalidTrapUnreachablePos);
    if InvalidTrapDeclarePos = 0 then
      Fail('missing-object-free-release-invalid-trap-declare');
    AllocatorFaultHelperPos := FindAfter(
      'define internal void @np_allocator_fault(i64 %code, i64 %arg0, i64 %arg1)',
      LlvmText, InvalidTrapDeclarePos);
    if AllocatorFaultHelperPos = 0 then
      Fail('missing-object-free-release-allocator-fault-helper');
    AllocatorFaultTrapPos := FindAfter('call void @llvm.trap()', LlvmText,
      AllocatorFaultHelperPos);
    if AllocatorFaultTrapPos = 0 then
      Fail('missing-object-free-release-allocator-fault-trap');

    WriteLn('hir-object-free-contract-status=pass');
  finally
    Verifier.Free;
    Emitter.Free;
    Builder.Free;
    SemaModel.Free;
  end;
end.
