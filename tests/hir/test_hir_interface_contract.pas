program test_hir_interface_contract;

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv, nextpas.compiler.sema.semantic_model, nextpas.compiler.ir.hir.types, nextpas.compiler.ir.hir.model,
  nextpas.compiler.ir.hir.builder, nextpas.compiler.ir.hir.llvm_emitter, nextpas.compiler.ir.hir.verifier, nextpas.compiler.ir.system_contracts;

var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Verifier: THIRVerifier;
  Emitter: THIRLlvmEmitter;
  LlvmText: string;
  Func: THIRFunction;
  Instr: THIRInstr;
  ContractDefinition: TSystemContractDefinition;
  OperandType: THIRTypeRec;
  FuncIndex, BlockIndex, InstrIndex: LongInt;
  AddrefCount, ReleaseCount: LongInt;
  AddrefHelperPos, ReleaseHelperPos: LongInt;

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-interface-contract-failure=', AMessage);
  Halt(1);
end;

begin
  SemaModel := TSemanticModel.Create;
  Builder := nil;
  Verifier := nil;
  Emitter := nil;
  try
    { Model interface variable lifecycle:
      - var-decl-ptr-runtime: allocate interface variable slot
      - intf-addref-runtime: addref when assigning new value
      - intf-release-runtime: release when variable goes out of scope }
    SemaModel.AddTypedHirNode('var-decl-ptr-runtime', 'A', 0, 0, 'A');
    SemaModel.AddTypedHirNode('intf-addref-runtime', 'A' + #9 + '0', 0, 0, 'A');
    SemaModel.AddTypedHirNode('intf-release-runtime', 'A', 0, 0, 'A');

    Builder := THIRBuilder.Create(SemaModel);
    Builder.Build;

    Verifier := THIRVerifier.Create(Builder.Module);
    if not Verifier.Verify then
      Fail('hir-verifier-error-count:' + IntToStr(Verifier.ErrorCount));

    AddrefCount := 0;
    ReleaseCount := 0;
    for FuncIndex := 0 to Builder.Module.FunctionCount - 1 do
    begin
      Func := Builder.Module.FunctionAt(FuncIndex);
      for BlockIndex := 0 to LongInt(Func.Blocks.Count) - 1 do
        if Func.Blocks[SizeUInt(BlockIndex)].Instrs <> nil then
          for InstrIndex := 0 to LongInt(Func.Blocks[SizeUInt(BlockIndex)].Instrs.Count) - 1 do
          begin
            Instr := Func.Blocks[SizeUInt(BlockIndex)].Instrs[SizeUInt(InstrIndex)];
            if (Instr.Kind = hikIntrinsic) and
              IsSystemContract(Instr, sckInterfaceAddRef) then
            begin
              Inc(AddrefCount);
              ContractDefinition := SystemContractAt(sckInterfaceAddRef);
              if Instr.IntrinsicName <> ContractDefinition.SemanticName then
                Fail('addref-name-mismatch:' + Instr.IntrinsicName);
              if Instr.CallTarget <> ContractDefinition.RuntimeMapping then
                Fail('addref-runtime-mismatch:' + Instr.CallTarget);
              if Length(Instr.Operands) <> 1 then
                Fail('addref-operand-count:' + IntToStr(Length(Instr.Operands)));
              OperandType := Builder.Module.Types.GetType(Instr.Operands[0].TypeId);
              if OperandType.Kind <> htkPointer then
                Fail('addref-operand0-not-pointer');
            end;
            if (Instr.Kind = hikIntrinsic) and
              IsSystemContract(Instr, sckInterfaceRelease) then
            begin
              Inc(ReleaseCount);
              ContractDefinition := SystemContractAt(sckInterfaceRelease);
              if Instr.IntrinsicName <> ContractDefinition.SemanticName then
                Fail('release-name-mismatch:' + Instr.IntrinsicName);
              if Instr.CallTarget <> ContractDefinition.RuntimeMapping then
                Fail('release-runtime-mismatch:' + Instr.CallTarget);
              if Length(Instr.Operands) <> 1 then
                Fail('release-operand-count:' + IntToStr(Length(Instr.Operands)));
              OperandType := Builder.Module.Types.GetType(Instr.Operands[0].TypeId);
              if OperandType.Kind <> htkPointer then
                Fail('release-operand0-not-pointer');
            end;
            { Legacy bare names must not remain as untyped authority. }
            if (Instr.Kind = hikIntrinsic) and (not Instr.HasSystemContract) and
              ((Instr.IntrinsicName = 'intf_addref') or
              (Instr.IntrinsicName = 'intf_release')) then
              Fail('legacy-untyped-interface-intrinsic:' + Instr.IntrinsicName);
          end;
    end;

    WriteLn('hir-interface-contract-addref-count=', AddrefCount);
    WriteLn('hir-interface-contract-release-count=', ReleaseCount);

    if AddrefCount < 1 then
      Fail('missing-typed-intf-addref');
    if ReleaseCount < 1 then
      Fail('missing-typed-intf-release');

    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;

    AddrefHelperPos := Pos('call void @np_intf_addref', LlvmText);
    ReleaseHelperPos := Pos('call void @np_intf_release', LlvmText);

    if AddrefHelperPos = 0 then
      Fail('missing-intf-addref-llvm-helper');
    if ReleaseHelperPos = 0 then
      Fail('missing-intf-release-llvm-helper');
    if Pos('declare void @np_intf_addref', LlvmText) = 0 then
      Fail('missing-intf-addref-declare');
    if Pos('declare void @np_intf_release', LlvmText) = 0 then
      Fail('missing-intf-release-declare');

    WriteLn('hir-interface-contract-llvm-addref=found');
    WriteLn('hir-interface-contract-llvm-release=found');
    WriteLn('hir-interface-contract=pass');
  finally
    Emitter.Free;
    Verifier.Free;
    Builder.Free;
    SemaModel.Free;
  end;
end.