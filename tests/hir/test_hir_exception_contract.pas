program test_hir_exception_contract;

{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.compiler.sema.semantic_model, np_hir_types, np_hir_model,
  np_hir_builder, np_hir_llvm_emitter, np_hir_verifier, np_system_contracts;

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-exception-contract-failure=', AMessage);
  Halt(1);
end;

type
  TExceptionCounts = record
    TryPush, TryPop, FinallyEnd, ExceptEnd, RaiseCount: LongInt;
  end;

function CountTypedException(AModule: THIRModule;
  out ACounts: TExceptionCounts): Boolean;
var
  Func: THIRFunction;
  Instr: THIRInstr;
  ContractDefinition: TSystemContractDefinition;
  FuncIndex, BlockIndex, InstrIndex: LongInt;
begin
  FillChar(ACounts, SizeOf(ACounts), 0);
  Result := True;
  for FuncIndex := 0 to AModule.FunctionCount - 1 do
  begin
    Func := AModule.FunctionAt(FuncIndex);
    for BlockIndex := 0 to LongInt(Func.Blocks.Count) - 1 do
      if Func.Blocks[SizeUInt(BlockIndex)].Instrs <> nil then
        for InstrIndex := 0 to LongInt(Func.Blocks[SizeUInt(BlockIndex)].Instrs.Count) - 1 do
        begin
          Instr := Func.Blocks[SizeUInt(BlockIndex)].Instrs[SizeUInt(InstrIndex)];
          if (Instr.Kind = hikIntrinsic) and Instr.HasSystemContract then
          begin
            if IsSystemContract(Instr, sckExceptionTryPush) then
            begin
                Inc(ACounts.TryPush);
                ContractDefinition := SystemContractAt(sckExceptionTryPush);
                if Instr.IntrinsicName <> ContractDefinition.SemanticName then
                begin
                  WriteLn('hir-exception-contract-failure=try-push-name-mismatch:',
                    Instr.IntrinsicName);
                  Exit(False);
                end;
                if Length(Instr.Operands) <> 0 then
                begin
                  WriteLn('hir-exception-contract-failure=try-push-operand-count');
                  Exit(False);
                end;
            end
            else if IsSystemContract(Instr, sckExceptionTryPop) then
            begin
                Inc(ACounts.TryPop);
                ContractDefinition := SystemContractAt(sckExceptionTryPop);
                if Instr.IntrinsicName <> ContractDefinition.SemanticName then
                begin
                  WriteLn('hir-exception-contract-failure=try-pop-name-mismatch:',
                    Instr.IntrinsicName);
                  Exit(False);
                end;
            end
            else if IsSystemContract(Instr, sckExceptionFinallyEnd) then
            begin
                Inc(ACounts.FinallyEnd);
                ContractDefinition := SystemContractAt(sckExceptionFinallyEnd);
                if Instr.IntrinsicName <> ContractDefinition.SemanticName then
                begin
                  WriteLn('hir-exception-contract-failure=finally-end-name-mismatch:',
                    Instr.IntrinsicName);
                  Exit(False);
                end;
            end
            else if IsSystemContract(Instr, sckExceptionExceptEnd) then
            begin
                Inc(ACounts.ExceptEnd);
                ContractDefinition := SystemContractAt(sckExceptionExceptEnd);
                if Instr.IntrinsicName <> ContractDefinition.SemanticName then
                begin
                  WriteLn('hir-exception-contract-failure=except-end-name-mismatch:',
                    Instr.IntrinsicName);
                  Exit(False);
                end;
            end
            else if IsSystemContract(Instr, sckExceptionRaise) then
            begin
                Inc(ACounts.RaiseCount);
                ContractDefinition := SystemContractAt(sckExceptionRaise);
                if Instr.IntrinsicName <> ContractDefinition.SemanticName then
                begin
                  WriteLn('hir-exception-contract-failure=raise-name-mismatch:',
                    Instr.IntrinsicName);
                  Exit(False);
                end;
            end;
          end;
          if (Instr.Kind = hikTryBegin) or (Instr.Kind = hikTryEnd) or
            (Instr.Kind = hikFinallyEnd) or (Instr.Kind = hikExceptEnd) or
            (Instr.Kind = hikRaise) then
          begin
            WriteLn('hir-exception-contract-failure=legacy-bare-exception-kind:',
              IntToStr(Ord(Instr.Kind)));
            Exit(False);
          end;
        end;
  end;
end;

procedure CheckTryFinally;
var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Verifier: THIRVerifier;
  Emitter: THIRLlvmEmitter;
  LlvmText: string;
  Counts: TExceptionCounts;
begin
  SemaModel := TSemanticModel.Create;
  Builder := nil;
  Verifier := nil;
  Emitter := nil;
  try
    SemaModel.AddTypedHirNode('try-begin-runtime', 'finally', 0, 0,
      'finally1' + #10);
    SemaModel.AddTypedHirNode('try-end-runtime', 'finally', 0, 0, '');
    SemaModel.AddTypedHirNode('br-runtime', 'finally1', 0, 0, 'finally1');
    SemaModel.AddTypedHirNode('block-label-runtime', 'finally1', 0, 0, 'finally1');
    SemaModel.AddTypedHirNode('finally-begin-runtime', '', 0, 0, '');
    SemaModel.AddTypedHirNode('finally-end-runtime', '', 0, 0, '');
    SemaModel.AddTypedHirNode('br-runtime', 'endtry1', 0, 0, 'endtry1');
    SemaModel.AddTypedHirNode('block-label-runtime', 'endtry1', 0, 0, 'endtry1');
    Builder := THIRBuilder.Create(SemaModel);
    Builder.Build;
    Verifier := THIRVerifier.Create(Builder.Module);
    if not Verifier.Verify then
      Fail('finally-hir-verifier-error-count:' + IntToStr(Verifier.ErrorCount));
    if not CountTypedException(Builder.Module, Counts) then
      Halt(1);
    WriteLn('hir-exception-contract-finally-try-push=', Counts.TryPush);
    WriteLn('hir-exception-contract-finally-try-pop=', Counts.TryPop);
    WriteLn('hir-exception-contract-finally-end=', Counts.FinallyEnd);
    if Counts.TryPush < 1 then
      Fail('finally-missing-typed-try-push');
    if Counts.TryPop < 1 then
      Fail('finally-missing-typed-try-pop');
    if Counts.FinallyEnd < 1 then
      Fail('finally-missing-typed-finally-end');
    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;
    if Pos('call void @np_try_push(ptr %jmpbuf.', LlvmText) = 0 then
      Fail('finally-missing-np-try-push-call');
    if Pos('call void @np_try_pop()', LlvmText) = 0 then
      Fail('finally-missing-np-try-pop-call');
    if Pos('call void @np_finally_end()', LlvmText) = 0 then
      Fail('finally-missing-np-finally-end-call');
    if Pos('setjmp', LlvmText) = 0 then
      Fail('finally-missing-setjmp');
  finally
    Emitter.Free;
    Verifier.Free;
    Builder.Free;
    SemaModel.Free;
  end;
end;

procedure CheckTryExcept;
var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Verifier: THIRVerifier;
  Emitter: THIRLlvmEmitter;
  LlvmText: string;
  Counts: TExceptionCounts;
begin
  SemaModel := TSemanticModel.Create;
  Builder := nil;
  Verifier := nil;
  Emitter := nil;
  try
    SemaModel.AddTypedHirNode('try-begin-runtime', 'except', 0, 0,
      'except1' + #10);
    SemaModel.AddTypedHirNode('try-end-runtime', 'except', 0, 0, '');
    SemaModel.AddTypedHirNode('br-runtime', 'endtry1', 0, 0, 'endtry1');
    SemaModel.AddTypedHirNode('block-label-runtime', 'except1', 0, 0, 'except1');
    SemaModel.AddTypedHirNode('except-begin-runtime', '', 0, 0, '');
    SemaModel.AddTypedHirNode('except-end-runtime', '', 0, 0, '');
    SemaModel.AddTypedHirNode('br-runtime', 'endtry1', 0, 0, 'endtry1');
    SemaModel.AddTypedHirNode('block-label-runtime', 'endtry1', 0, 0, 'endtry1');
    Builder := THIRBuilder.Create(SemaModel);
    Builder.Build;
    Verifier := THIRVerifier.Create(Builder.Module);
    if not Verifier.Verify then
      Fail('except-hir-verifier-error-count:' + IntToStr(Verifier.ErrorCount));
    if not CountTypedException(Builder.Module, Counts) then
      Halt(1);
    WriteLn('hir-exception-contract-except-try-push=', Counts.TryPush);
    WriteLn('hir-exception-contract-except-end=', Counts.ExceptEnd);
    if Counts.TryPush < 1 then
      Fail('except-missing-typed-try-push');
    if Counts.ExceptEnd < 1 then
      Fail('except-missing-typed-except-end');
    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;
    if Pos('call void @np_try_push(ptr %jmpbuf.', LlvmText) = 0 then
      Fail('except-missing-np-try-push-call');
    if Pos('call void @np_except_end()', LlvmText) = 0 then
      Fail('except-missing-np-except-end-call');
  finally
    Emitter.Free;
    Verifier.Free;
    Builder.Free;
    SemaModel.Free;
  end;
end;

procedure CheckRaise;
var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Verifier: THIRVerifier;
  Emitter: THIRLlvmEmitter;
  LlvmText: string;
  Counts: TExceptionCounts;
begin
  SemaModel := TSemanticModel.Create;
  Builder := nil;
  Verifier := nil;
  Emitter := nil;
  try
    SemaModel.AddTypedHirNode('raise-runtime', 'raise', 0, 0, '');
    Builder := THIRBuilder.Create(SemaModel);
    Builder.Build;
    Verifier := THIRVerifier.Create(Builder.Module);
    if not Verifier.Verify then
      Fail('raise-hir-verifier-error-count:' + IntToStr(Verifier.ErrorCount));
    if not CountTypedException(Builder.Module, Counts) then
      Halt(1);
    WriteLn('hir-exception-contract-raise-count=', Counts.RaiseCount);
    if Counts.RaiseCount < 1 then
      Fail('missing-typed-raise');
    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;
    if Pos('call void @np_raise()', LlvmText) = 0 then
      Fail('missing-np-raise-call');
    if Pos('unreachable', LlvmText) = 0 then
      Fail('missing-raise-unreachable');
  finally
    Emitter.Free;
    Verifier.Free;
    Builder.Free;
    SemaModel.Free;
  end;
end;

begin
  CheckTryFinally;
  CheckTryExcept;
  CheckRaise;
  WriteLn('hir-exception-contract-llvm-helpers=found');
  WriteLn('hir-exception-contract=pass');
end.