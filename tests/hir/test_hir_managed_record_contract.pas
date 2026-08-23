program test_hir_managed_record_contract;

{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.compiler.sema.semantic_model, np_hir_types, np_hir_model,
  np_hir_builder, np_hir_llvm_emitter, np_hir_verifier, np_system_contracts;

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-managed-record-contract-failure=', AMessage);
  Halt(1);
end;

function CountTypedManagedRecordFini(AModule: THIRModule;
  out AFiniCount: LongInt): Boolean;
var
  Func: THIRFunction;
  Instr: THIRInstr;
  ContractDefinition: TSystemContractDefinition;
  OperandType: THIRTypeRec;
  FuncIndex, BlockIndex, InstrIndex: LongInt;
begin
  AFiniCount := 0;
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
            IsSystemContract(Instr, sckManagedRecordFini) then
          begin
            Inc(AFiniCount);
            ContractDefinition := SystemContractAt(sckManagedRecordFini);
            if Instr.IntrinsicName <> ContractDefinition.SemanticName then
            begin
              WriteLn('hir-managed-record-contract-failure=name-mismatch:',
                Instr.IntrinsicName);
              Exit(False);
            end;
            if Length(Instr.Operands) <> 1 then
            begin
              WriteLn('hir-managed-record-contract-failure=operand-count:',
                IntToStr(Length(Instr.Operands)));
              Exit(False);
            end;
            OperandType := AModule.Types.GetType(Instr.Operands[0].TypeId);
            if OperandType.Kind <> htkPointer then
            begin
              WriteLn('hir-managed-record-contract-failure=operand-not-pointer');
              Exit(False);
            end;
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
  FiniCount: LongInt;
begin
  SemaModel := TSemanticModel.Create;
  Builder := nil;
  Emitter := nil;
  Verifier := nil;
  try
    SemaModel.AddConstValue('TRec.Name$idx', 0);
    SemaModel.SetTypeMeta(SemaModel.AddType('TRec', 'declared'),
      Default(TTypeMetadata));
    SemaModel.AddTypedHirNode('var-decl-record-runtime',
      'R', 0, 0, 'R'#9'3');
    SemaModel.AddTypedHirNode('managed-record-cleanup-runtime',
      'Cleanup', 0, 0, 'R'#9'TRec'#9'Name:s');

    Builder := THIRBuilder.Create(SemaModel);
    Builder.Build;

    Verifier := THIRVerifier.Create(Builder.Module);
    if not Verifier.Verify then
      Fail('hir-verifier-error-count:' + IntToStr(Verifier.ErrorCount));

    if not CountTypedManagedRecordFini(Builder.Module, FiniCount) then
      Halt(1);
    if FiniCount <> 1 then
      Fail('managed-record-fini-count:' + IntToStr(FiniCount));
    WriteLn('hir-managed-record-contract-count=', FiniCount);

    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;

    if Pos('managed-record-fini (compiler-planned field cleanup)', LlvmText) = 0 then
      Fail('missing-llvm-managed-record-fini-marker');
    if Pos('call void @np_tstring_fini(', LlvmText) = 0 then
      Fail('missing-nested-tstring-fini');

    WriteLn('hir-managed-record-contract-llvm-helpers=found');
    WriteLn('hir-managed-record-contract=pass');
  finally
    Verifier.Free;
    Emitter.Free;
    Builder.Free;
    SemaModel.Free;
  end;
end.