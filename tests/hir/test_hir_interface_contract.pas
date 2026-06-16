program test_hir_interface_contract;

{$mode objfpc}{$H+}

uses
  SysUtils, np_semantic_model, np_hir_types, np_hir_model,
  np_hir_builder, np_hir_llvm_emitter, np_hir_verifier;

var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Verifier: THIRVerifier;
  Emitter: THIRLlvmEmitter;
  LlvmText: string;
  Func: THIRFunction;
  Instr: THIRInstr;
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
    // Model interface variable lifecycle:
    // - var-decl-ptr-runtime: allocate interface variable slot
    // - intf-addref-runtime: addref when assigning new value
    // - intf-release-runtime: release when variable goes out of scope
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
      for BlockIndex := 0 to High(Func.Blocks) do
        for InstrIndex := 0 to High(Func.Blocks[BlockIndex].Instrs) do
        begin
          Instr := Func.Blocks[BlockIndex].Instrs[InstrIndex];
          if (Instr.Kind = hikIntrinsic) and SameText(Instr.IntrinsicName, 'intf_addref') then
            Inc(AddrefCount);
          if (Instr.Kind = hikIntrinsic) and SameText(Instr.IntrinsicName, 'intf_release') then
            Inc(ReleaseCount);
        end;
    end;

    WriteLn('hir-interface-contract-addref-count=', AddrefCount);
    WriteLn('hir-interface-contract-release-count=', ReleaseCount);

    if AddrefCount < 1 then
      Fail('missing-intf-addref-hir-intrinsic');
    if ReleaseCount < 1 then
      Fail('missing-intf-release-hir-intrinsic');

    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;

    AddrefHelperPos := Pos('call void @np_intf_addref', LlvmText);
    ReleaseHelperPos := Pos('call void @np_intf_release', LlvmText);

    if AddrefHelperPos = 0 then
      Fail('missing-intf-addref-llvm-helper');
    if ReleaseHelperPos = 0 then
      Fail('missing-intf-release-llvm-helper');

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
