program test_hir_object_free_contract;

{$mode objfpc}{$H+}

uses
  SysUtils, np_semantic_model, np_hir_types, np_hir_model, np_system_contracts,
  np_hir_builder, np_hir_llvm_emitter, np_hir_verifier;

var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  Verifier: THIRVerifier;
  Func: THIRFunction;
  Instr: THIRInstr;
  OperandType: THIRTypeRec;
  WorkerMeta: TTypeMetadata;
  FieldMeta: TFieldMeta;
  LlvmText: string;
  FoundContract: Boolean;
  FoundOwnedDestroy: Boolean;
  FoundHeapRelease: Boolean;
  CleanupCount: LongInt;
  WorkerTypeId: LongInt;
  FuncIndex, BlockIndex, InstrIndex: LongInt;
  NullCheckPos, BranchPos, DestroyLabelPos, DestroyCallPos, ReleaseCallPos,
  StringCleanupCallPos, DynArrayCleanupCallPos, EndLabelPos: LongInt;

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

procedure AddContractInstr(AModule: THIRModule; AFuncId: THIRFuncId;
  ABlockId: THIRBlockId; AResultType: THIRTypeId;
  AContractKind: TSystemContractKind; AInstrKind: THIRInstrKind;
  AOperandType: THIRTypeId; AOperandCount: LongInt;
  const ACallTarget: string; ATamperName: Boolean;
  AReceiverValueId: THIRValueId = 0);
var
  ContractInstr: THIRInstr;
  OperandIndex: LongInt;
begin
  FillChar(ContractInstr, SizeOf(ContractInstr), 0);
  ContractInstr.ResultId := AModule.NewValue;
  ContractInstr.Kind := AInstrKind;
  ContractInstr.TypeId := AResultType;
  AssignSystemContract(ContractInstr, AContractKind);
  ContractInstr.CallTarget := ACallTarget;
  if ATamperName then
    ContractInstr.IntrinsicName := 'tampered-system-contract-name';
  SetLength(ContractInstr.Operands, AOperandCount);
  for OperandIndex := 0 to AOperandCount - 1 do
  begin
    if AReceiverValueId = 0 then
      AReceiverValueId := ContractInstr.ResultId;
    ContractInstr.Operands[OperandIndex] := MakeTypedOperand(
      AReceiverValueId, AOperandType);
  end;
  AModule.AddInstr(AFuncId, ABlockId, ContractInstr);
end;

function HasVerifierError(AVerifier: THIRVerifier;
  const AExpected: string): Boolean;
var
  ErrorIndex: LongInt;
begin
  for ErrorIndex := 0 to AVerifier.ErrorCount - 1 do
    if Pos(AExpected, AVerifier.ErrorAt(ErrorIndex).Message) > 0 then
      Exit(True);
  Result := False;
end;

procedure RecordMissingVerifierError(AVerifier: THIRVerifier;
  const AExpected: string; var AMissing: string);
begin
  if not HasVerifierError(AVerifier, AExpected) then
    AMissing := AMissing + AExpected + ';';
end;

procedure AssertMalformedSystemContractsRejected;
var
  ContractModule: THIRModule;
  ContractVerifier: THIRVerifier;
  ContractEmitter: THIRLlvmEmitter;
  StandaloneEmitter: THIRLlvmEmitter;
  FuncId: THIRFuncId;
  BlockId: THIRBlockId;
  VoidType, PointerType, IntType: THIRTypeId;
  Term: THIRTerminator;
  UnknownContractInstr: THIRInstr;
  UnknownContractOrdinal: LongInt;
  Missing: string;
  EmitterRejected, NonIntrinsicEmitterRejected,
  StandaloneEmitterRejected: Boolean;
begin
  ContractModule := THIRModule.Create('malformed-system-contracts');
  ContractVerifier := nil;
  ContractEmitter := nil;
  StandaloneEmitter := nil;
  try
    VoidType := ContractModule.Types.AddType(htkVoid, 'void');
    PointerType := ContractModule.Types.AddPointerType(VoidType);
    IntType := ContractModule.Types.AddIntType(64, True);
    FuncId := ContractModule.AddFunction('malformed_contracts', VoidType);
    BlockId := ContractModule.AddBlock(FuncId, 'entry');
    ContractModule.SetEntryBlock(FuncId, BlockId);

    AddContractInstr(ContractModule, FuncId, BlockId, VoidType,
      sckObjectFree, hikIntrinsic, PointerType, 0, 'TObject.Destroy', False);
    AddContractInstr(ContractModule, FuncId, BlockId, VoidType,
      sckObjectFree, hikIntrinsic, IntType, 1, 'TObject.Destroy', False);
    AddContractInstr(ContractModule, FuncId, BlockId, VoidType,
      sckObjectFree, hikIntrinsic, PointerType, 1, '', False);
    AddContractInstr(ContractModule, FuncId, BlockId, VoidType,
      sckProcessInit, hikIntrinsic, PointerType, 1, 'np_process_init', False);
    AddContractInstr(ContractModule, FuncId, BlockId, VoidType,
      sckObjectFree, hikCall, PointerType, 1, 'TObject.Destroy', False);
    AddContractInstr(ContractModule, FuncId, BlockId, VoidType,
      sckObjectFree, hikIntrinsic, PointerType, 1, 'TObject.Destroy', True);
    AddContractInstr(ContractModule, FuncId, BlockId, VoidType,
      sckObjectFreeDestroy, hikIntrinsic, PointerType, 1,
      'TObject.Destroy', False);

    { Unsupported contract kind must be rejected; AssignSystemContract raises
      on unknown kinds, so craft the instruction manually to reach the
      verifier's kind-unsupported path. }
    FillChar(UnknownContractInstr, SizeOf(UnknownContractInstr), 0);
    UnknownContractInstr.ResultId := ContractModule.NewValue;
    UnknownContractInstr.Kind := hikIntrinsic;
    UnknownContractInstr.TypeId := VoidType;
    UnknownContractInstr.HasSystemContract := True;
    UnknownContractOrdinal := 28; { one past the last declared kind }
    UnknownContractInstr.SystemContractKind :=
      TSystemContractKind(UnknownContractOrdinal);
    UnknownContractInstr.IntrinsicName := 'unknown-system-contract';
    SetLength(UnknownContractInstr.Operands, 1);
    UnknownContractInstr.Operands[0] := MakeTypedOperand(
      UnknownContractInstr.ResultId, PointerType);
    ContractModule.AddInstr(FuncId, BlockId, UnknownContractInstr);

    FillChar(Term, SizeOf(Term), 0);
    Term.Kind := htkReturn;
    ContractModule.SetTerminator(FuncId, BlockId, Term);

    ContractVerifier := THIRVerifier.Create(ContractModule);
    ContractVerifier.Verify;
    Missing := '';
    RecordMissingVerifierError(ContractVerifier,
      'system-contract-operand-count', Missing);
    RecordMissingVerifierError(ContractVerifier,
      'system-contract-operand-not-pointer', Missing);
    RecordMissingVerifierError(ContractVerifier,
      'system-contract-target-missing', Missing);
    RecordMissingVerifierError(ContractVerifier,
      'system-contract-kind-unsupported', Missing);
    RecordMissingVerifierError(ContractVerifier,
      'system-contract-kind-must-be-intrinsic', Missing);
    RecordMissingVerifierError(ContractVerifier,
      'system-contract-name-mismatch', Missing);
    RecordMissingVerifierError(ContractVerifier,
      'system-contract-sequence-root-missing', Missing);

    ContractEmitter := THIRLlvmEmitter.Create(ContractModule);
    EmitterRejected := False;
    try
      ContractEmitter.EmitInstr(
        ContractModule.FunctionAt(0).Blocks[SizeUInt(0)].Instrs[SizeUInt(0)]);
    except
      on E: Exception do
      begin
        EmitterRejected := Pos('system-contract-operand-count', E.Message) > 0;
        if not EmitterRejected then
          Missing := Missing + 'emitter-error:' + E.Message + ';';
      end;
    end;
    if not EmitterRejected then
      Missing := Missing + 'emitter-system-contract-operand-count;';
    NonIntrinsicEmitterRejected := False;
    try
      ContractEmitter.EmitInstr(
        ContractModule.FunctionAt(0).Blocks[SizeUInt(0)].Instrs[SizeUInt(4)]);
    except
      on E: Exception do
      begin
        NonIntrinsicEmitterRejected := Pos(
          'system-contract-kind-must-be-intrinsic', E.Message) > 0;
        if not NonIntrinsicEmitterRejected then
          Missing := Missing + 'non-intrinsic-emitter-error:' +
            E.Message + ';';
      end;
    end;
    if not NonIntrinsicEmitterRejected then
      Missing := Missing +
        'emitter-system-contract-kind-must-be-intrinsic;';
    StandaloneEmitter := THIRLlvmEmitter.Create(ContractModule);
    StandaloneEmitterRejected := False;
    try
      StandaloneEmitter.EmitInstr(
        ContractModule.FunctionAt(0).Blocks[SizeUInt(0)].Instrs[SizeUInt(6)]);
    except
      on E: Exception do
      begin
        StandaloneEmitterRejected := Pos(
          'system-contract-sequence-root-missing', E.Message) > 0;
        if not StandaloneEmitterRejected then
          Missing := Missing + 'standalone-emitter-error:' + E.Message + ';';
      end;
    end;
    if not StandaloneEmitterRejected then
      Missing := Missing + 'emitter-system-contract-sequence-root-missing;';
    if Missing <> '' then
      Fail('malformed-system-contract-validation-missing:' + Missing);
  finally
    StandaloneEmitter.Free;
    ContractEmitter.Free;
    ContractVerifier.Free;
    ContractModule.Free;
  end;
end;

procedure AssertObjectFreeSequenceOwnershipRejected;
var
  Missing: string;

  procedure CheckSequence(AContinuationKind: TSystemContractKind;
    AIncludeRoot, AUseRootReceiver: Boolean;
    const ARootTarget, AContinuationTarget, AExpectedError,
    ACaseName: string);
  var
    ContractModule: THIRModule;
    ContractVerifier: THIRVerifier;
    ContractEmitter: THIRLlvmEmitter;
    FuncId: THIRFuncId;
    BlockId: THIRBlockId;
    VoidType, PointerType: THIRTypeId;
    RootReceiver, ContinuationReceiver: THIRValueId;
    ContinuationIndex: LongInt;
    Term: THIRTerminator;
    Func: THIRFunction;
    EmitterRejected: Boolean;
  begin
    ContractModule := THIRModule.Create(ACaseName);
    ContractVerifier := nil;
    ContractEmitter := nil;
    try
      VoidType := ContractModule.Types.AddType(htkVoid, 'void');
      PointerType := ContractModule.Types.AddPointerType(VoidType);
      FuncId := ContractModule.AddFunction(ACaseName, VoidType);
      BlockId := ContractModule.AddBlock(FuncId, 'entry');
      ContractModule.SetEntryBlock(FuncId, BlockId);

      RootReceiver := 0;
      ContinuationIndex := 0;
      if AIncludeRoot then
      begin
        AddContractInstr(ContractModule, FuncId, BlockId, VoidType,
          sckObjectFree, hikIntrinsic, PointerType, 1, ARootTarget, False);
        Func := ContractModule.FunctionAt(0);
        RootReceiver := Func.Blocks[SizeUInt(0)].Instrs[SizeUInt(0)].ResultId;
        ContinuationIndex := 1;
      end;
      if AIncludeRoot and AUseRootReceiver then
        ContinuationReceiver := RootReceiver
      else
        ContinuationReceiver := 0;
      AddContractInstr(ContractModule, FuncId, BlockId, VoidType,
        AContinuationKind, hikIntrinsic, PointerType, 1,
        AContinuationTarget, False, ContinuationReceiver);

      FillChar(Term, SizeOf(Term), 0);
      Term.Kind := htkReturn;
      ContractModule.SetTerminator(FuncId, BlockId, Term);
      Func := ContractModule.FunctionAt(0);

      ContractVerifier := THIRVerifier.Create(ContractModule);
      ContractVerifier.Verify;
      if not HasVerifierError(ContractVerifier, AExpectedError) then
        Missing := Missing + ACaseName + '-verifier;';

      ContractEmitter := THIRLlvmEmitter.Create(ContractModule);
      EmitterRejected := False;
      try
        if AIncludeRoot then
          ContractEmitter.EmitInstr(Func.Blocks[SizeUInt(0)].Instrs[SizeUInt(0)]);
        ContractEmitter.EmitInstr(
          Func.Blocks[SizeUInt(0)].Instrs[SizeUInt(ContinuationIndex)]);
      except
        on E: Exception do
        begin
          EmitterRejected := Pos(AExpectedError, E.Message) > 0;
          if not EmitterRejected then
            Missing := Missing + ACaseName + '-emitter-error:' +
              E.Message + ';';
        end;
      end;
      if not EmitterRejected then
        Missing := Missing + ACaseName + '-emitter;';
    finally
      ContractEmitter.Free;
      ContractVerifier.Free;
      ContractModule.Free;
    end;
  end;

begin
  Missing := '';
  CheckSequence(sckObjectFreeDestroy, True, False, 'T', 'T',
    'system-contract-sequence-receiver-mismatch', 'receiver-destroy');
  CheckSequence(sckObjectFreeCleanup, True, False, 'T', 'cleanup_T',
    'system-contract-sequence-receiver-mismatch', 'receiver-cleanup');
  CheckSequence(sckObjectFreeRelease, True, False, 'T', '',
    'system-contract-sequence-receiver-mismatch', 'receiver-release');
  CheckSequence(sckObjectFreeDestroy, True, True, 'T', 'U',
    'system-contract-sequence-destroy-target-mismatch', 'destroy-target');
  CheckSequence(sckObjectFreeDestroy, False, False, '', 'T',
    'system-contract-sequence-root-missing', 'missing-root-destroy');
  CheckSequence(sckObjectFreeCleanup, False, False, '', 'cleanup_T',
    'system-contract-sequence-root-missing', 'missing-root-cleanup');
  CheckSequence(sckObjectFreeRelease, False, False, '', '',
    'system-contract-sequence-root-missing', 'missing-root-release');
  if Missing <> '' then
    Fail('object-free-sequence-validation-missing:' + Missing);
end;

begin
  AssertMalformedSystemContractsRejected;
  AssertObjectFreeSequenceOwnershipRejected;
  SemaModel := TSemanticModel.Create;
  Builder := nil;
  Emitter := nil;
  Verifier := nil;
  try
    WorkerTypeId := SemaModel.AddType('Worker', 'class');
    WorkerMeta := Default(TTypeMetadata);
    { Fields is a TVec class handle; SetTypeMeta adopts unowned vectors, so
      create it here and let the model own it from SetTypeMeta on. }
    WorkerMeta.Fields := TSemanticFieldMetaVec.Create;
    FieldMeta := Default(TFieldMeta);
    FieldMeta.Name := 'Name';
    FieldMeta.Index := 0;
    FieldMeta.IsString := True;
    WorkerMeta.Fields.Push(FieldMeta);
    FieldMeta := Default(TFieldMeta);
    FieldMeta.Name := 'Items';
    FieldMeta.Index := 4;
    FieldMeta.IsDynArray := True;
    WorkerMeta.Fields.Push(FieldMeta);
    SemaModel.SetTypeMeta(WorkerTypeId, WorkerMeta);
    SemaModel.AddConstValue('Worker.Items$arr_elem_size', 8);
    SemaModel.AddTypedHirNode('var-decl-ptr-runtime', 'Worker', 0, 0, 'Worker');
    SemaModel.AddTypedHirNode(
      'object-free-runtime',
      'untrusted-object-free-label',
      0,
      0,
      'var Worker' + #10 +
      'destroy TObject.Destroy' + #10 +
      'cleanup-class Worker' + #10 +
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
    CleanupCount := 0;
    for FuncIndex := 0 to Builder.Module.FunctionCount - 1 do
    begin
      Func := Builder.Module.FunctionAt(FuncIndex);
      for BlockIndex := 0 to LongInt(Func.Blocks.Count) - 1 do
        if Func.Blocks[SizeUInt(BlockIndex)].Instrs <> nil then
          for InstrIndex := 0 to LongInt(Func.Blocks[SizeUInt(BlockIndex)].Instrs.Count) - 1 do
        begin
          Instr := Func.Blocks[SizeUInt(BlockIndex)].Instrs[SizeUInt(InstrIndex)];
          if (Instr.Kind = hikIntrinsic) and
            IsSystemContract(Instr, sckObjectFree) then
          begin
            if FoundContract then
              Fail('duplicate-object-free-contract');
            FoundContract := True;
            if Instr.IntrinsicName <>
              SystemContractAt(sckObjectFree).SemanticName then
              Fail('object-free-intrinsic-name-mismatch:' +
                Instr.IntrinsicName);
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
            IsSystemContract(Instr, sckObjectFreeDestroy) then
          begin
            if FoundOwnedDestroy then
              Fail('duplicate-object-free-owned-destroy');
            FoundOwnedDestroy := True;
            if Instr.IntrinsicName <>
              SystemContractAt(sckObjectFreeDestroy).SemanticName then
              Fail('object-free-owned-destroy-intrinsic-name-mismatch:' +
                Instr.IntrinsicName);
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
            IsSystemContract(Instr, sckObjectFreeRelease) then
          begin
            if FoundHeapRelease then
              Fail('duplicate-object-free-release');
            FoundHeapRelease := True;
            if Instr.IntrinsicName <>
              SystemContractAt(sckObjectFreeRelease).SemanticName then
              Fail('object-free-release-intrinsic-name-mismatch:' +
                Instr.IntrinsicName);
            if Length(Instr.Operands) <> 1 then
              Fail('object-free-release-operand-count:' +
                IntToStr(Length(Instr.Operands)));
            if Instr.Operands[0].TypeId = 0 then
              Fail('object-free-release-receiver-type-missing');
            OperandType := Builder.Module.Types.GetType(Instr.Operands[0].TypeId);
            if OperandType.Kind <> htkPointer then
              Fail('object-free-release-receiver-not-pointer');
          end;
          if (Instr.Kind = hikIntrinsic) and
            IsSystemContract(Instr, sckObjectFreeCleanup) then
          begin
            Inc(CleanupCount);
            if Instr.IntrinsicName <>
              SystemContractAt(sckObjectFreeCleanup).SemanticName then
              Fail('object-free-cleanup-intrinsic-name-mismatch:' +
                Instr.IntrinsicName);
            if Instr.CallTarget = '' then
              Fail('object-free-cleanup-target-missing');
            if Length(Instr.Operands) <> 1 then
              Fail('object-free-cleanup-operand-count:' +
                IntToStr(Length(Instr.Operands)));
            OperandType := Builder.Module.Types.GetType(
              Instr.Operands[0].TypeId);
            if OperandType.Kind <> htkPointer then
              Fail('object-free-cleanup-receiver-not-pointer');
          end;
        end;
    end;

    if not FoundContract then
      Fail('missing-object-free-hir-intrinsic');
    if not FoundOwnedDestroy then
      Fail('missing-object-free-owned-destroy-intrinsic');
    if not FoundHeapRelease then
      Fail('missing-object-free-release-intrinsic');
    if CleanupCount <> 2 then
      Fail('object-free-cleanup-count:' + IntToStr(CleanupCount));

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
    StringCleanupCallPos := FindAfter(
      'call void @np_object_string_cleanup_Worker(ptr ', LlvmText,
      DestroyCallPos);
    if StringCleanupCallPos = 0 then
      Fail('missing-object-free-string-cleanup-after-destroy');
    DynArrayCleanupCallPos := FindAfter(
      'call void @np_object_dynarray_cleanup_Worker(ptr ', LlvmText,
      StringCleanupCallPos);
    if DynArrayCleanupCallPos = 0 then
      Fail('missing-object-free-dynarray-cleanup-after-string-cleanup');
    ReleaseCallPos := FindAfter('call void @np_object_free_release(ptr ',
      LlvmText, DynArrayCleanupCallPos);
    if ReleaseCallPos = 0 then
      Fail('missing-object-free-llvm-release-call-after-destroy');
    EndLabelPos := FindAfter(LineEnding + 'objectfree.end.', LlvmText,
      ReleaseCallPos);
    if EndLabelPos = 0 then
      Fail('missing-object-free-llvm-end-label-after-release');
    if not ((NullCheckPos < BranchPos) and (BranchPos < DestroyLabelPos) and
      (DestroyLabelPos < DestroyCallPos) and
      (DestroyCallPos < StringCleanupCallPos) and
      (StringCleanupCallPos < DynArrayCleanupCallPos) and
      (DynArrayCleanupCallPos < ReleaseCallPos) and
      (ReleaseCallPos < EndLabelPos)) then
      Fail('object-free-llvm-guard-order');
    { Phase 3: np_object_free_release 已移至 libnprt.a runtime 模块 }
    if Pos('declare void @np_object_free_release(ptr %obj)', LlvmText) = 0 then
      Fail('missing-object-free-release-helper-decl');
    if Pos('declare void @np_free(ptr %raw, i64 %size)', LlvmText) = 0 then
      Fail('missing-object-free-free-decl');
    if Pos('declare void @np_allocator_fault(i64 %code, i64 %arg0, i64 %arg1)', LlvmText) = 0 then
      Fail('missing-object-free-allocator-fault-decl');

    WriteLn('hir-object-free-contract-status=pass');
  finally
    Verifier.Free;
    Emitter.Free;
    Builder.Free;
    SemaModel.Free;
  end;
end.
