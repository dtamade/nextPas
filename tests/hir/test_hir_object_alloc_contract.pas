program test_hir_object_alloc_contract;

{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.compiler.sema.semantic_model, nextpas.compiler.ir.hir.types, nextpas.compiler.ir.hir.model,
  nextpas.compiler.ir.hir.builder, nextpas.compiler.ir.hir.llvm_emitter, nextpas.compiler.ir.hir.verifier, nextpas.compiler.ir.system_contracts;

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-object-alloc-contract-failure=', AMessage);
  Halt(1);
end;

function CountTypedObjectAlloc(AModule: THIRModule;
  out AAllocCount: LongInt): Boolean;
var
  Func: THIRFunction;
  Instr: THIRInstr;
  ContractDefinition: TSystemContractDefinition;
  OperandType: THIRTypeRec;
  FuncIndex, BlockIndex, InstrIndex: LongInt;
begin
  AAllocCount := 0;
  Result := True;
  for FuncIndex := 0 to AModule.FunctionCount - 1 do
  begin
    Func := AModule.FunctionAt(FuncIndex);
    for BlockIndex := 0 to LongInt(Func.Blocks.Count) - 1 do
      if Func.Blocks[SizeUInt(BlockIndex)].Instrs <> nil then
        for InstrIndex := 0 to LongInt(Func.Blocks[SizeUInt(BlockIndex)].Instrs.Count) - 1 do
        begin
          Instr := Func.Blocks[SizeUInt(BlockIndex)].Instrs[SizeUInt(InstrIndex)];
          if (Instr.Kind = hikIntrinsic) and
            IsSystemContract(Instr, sckObjectAlloc) then
          begin
            Inc(AAllocCount);
            ContractDefinition := SystemContractAt(sckObjectAlloc);
            if Instr.IntrinsicName <> ContractDefinition.SemanticName then
            begin
              WriteLn('hir-object-alloc-contract-failure=name-mismatch:',
                Instr.IntrinsicName);
              Exit(False);
            end;
            if Length(Instr.Operands) <> 1 then
            begin
              WriteLn('hir-object-alloc-contract-failure=operand-count:',
                IntToStr(Length(Instr.Operands)));
              Exit(False);
            end;
            OperandType := AModule.Types.GetType(Instr.Operands[0].TypeId);
            if OperandType.Kind <> htkInt then
            begin
              WriteLn('hir-object-alloc-contract-failure=operand-not-int');
              Exit(False);
            end;
          end;
          if (Instr.Kind = hikIntrinsic) and
            SameText(Instr.IntrinsicName, 'class_alloc') then
          begin
            WriteLn('hir-object-alloc-contract-failure=legacy-bare-class-alloc');
            Exit(False);
          end;
        end;
  end;
end;

var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  Verifier: THIRVerifier;
  LlvmText: string;
  AllocCount: LongInt;
begin
  SemaModel := TSemanticModel.Create;
  Builder := nil;
  Emitter := nil;
  Verifier := nil;
  try
    SemaModel.AddTypedHirNode(
      'class-new-runtime',
      '32',
      0,
      0,
      'Worker' + #9 + 'TWorker.Create'
    );

    Builder := THIRBuilder.Create(SemaModel);
    Builder.Build;

    Verifier := THIRVerifier.Create(Builder.Module);
    if not Verifier.Verify then
      Fail('hir-verifier-error-count:' + IntToStr(Verifier.ErrorCount));

    if not CountTypedObjectAlloc(Builder.Module, AllocCount) then
      Halt(1);
    if AllocCount <> 1 then
      Fail('object-alloc-count:' + IntToStr(AllocCount));
    WriteLn('hir-object-alloc-contract-count=', AllocCount);

    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;

    if Pos(' = call ptr @np_object_alloc(i64 ', LlvmText) = 0 then
      Fail('missing-llvm-object-alloc-call');
    if Pos('declare ptr @np_object_alloc(i64 %size)', LlvmText) = 0 then
      Fail('missing-llvm-object-alloc-decl');
    if Pos(' = call ptr @np_alloc(i64 %v', LlvmText) <> 0 then
      Fail('direct-base-alloc-call-from-class-new');
    if Pos('class_alloc', LlvmText) <> 0 then
      Fail('legacy-class-alloc-name-leaked-to-llvm');

    WriteLn('hir-object-alloc-contract-llvm-helpers=found');
    WriteLn('hir-object-alloc-contract=pass');
  finally
    Verifier.Free;
    Emitter.Free;
    Builder.Free;
    SemaModel.Free;
  end;
end.