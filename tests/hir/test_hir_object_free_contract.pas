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
  FoundContract: Boolean;
  FoundOwnedDestroy: Boolean;
  FoundHeapRelease: Boolean;
  FuncIndex, BlockIndex, InstrIndex: LongInt;
  NullCheckPos, BranchPos, DestroyLabelPos, DestroyCallPos, ReleaseCallPos,
  EndLabelPos: LongInt;

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
