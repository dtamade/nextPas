program test_hir_class_alloc_contract;

{$mode objfpc}{$H+}

uses
  SysUtils, np_semantic_model, np_hir_types, np_hir_model,
  np_hir_builder, np_hir_llvm_emitter, np_hir_verifier,
  np_system_contracts;

var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  Verifier: THIRVerifier;
  Func: THIRFunction;
  Instr: THIRInstr;
  LlvmText: string;
  FoundClassAlloc: Boolean;
  FuncIndex, BlockIndex, InstrIndex: LongInt;

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-class-alloc-contract-failure=', AMessage);
  Halt(1);
end;

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

    FoundClassAlloc := False;
    for FuncIndex := 0 to Builder.Module.FunctionCount - 1 do
    begin
      Func := Builder.Module.FunctionAt(FuncIndex);
      for BlockIndex := 0 to LongInt(Func.Blocks.Count) - 1 do
        if Func.Blocks[SizeUInt(BlockIndex)].Instrs <> nil then
          for InstrIndex := 0 to LongInt(Func.Blocks[SizeUInt(BlockIndex)].Instrs.Count) - 1 do
        begin
          Instr := Func.Blocks[SizeUInt(BlockIndex)].Instrs[SizeUInt(InstrIndex)];
          { 生产约定为 typed sckObjectAlloc（语义名 np.system.object_alloc）；
            裸 'class_alloc' IntrinsicName 是 emitter 的 legacy 兼容路径 }
          if (Instr.Kind = hikIntrinsic) and
            IsSystemContract(Instr, sckObjectAlloc) then
          begin
            if FoundClassAlloc then
              Fail('duplicate-hir-class-alloc');
            FoundClassAlloc := True;
            if Length(Instr.Operands) <> 1 then
              Fail('hir-class-alloc-operand-count:' +
                IntToStr(Length(Instr.Operands)));
          end;
        end;
    end;
    if not FoundClassAlloc then
      Fail('missing-hir-class-alloc-intrinsic');

    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;

    if Pos(' = call ptr @np_object_alloc(i64 ', LlvmText) = 0 then
      Fail('missing-hir-class-alloc-object-helper-call');
    { Phase 3: np_object_alloc 已移至 libnprt.a runtime 模块，只 emit 声明 }
    if Pos('declare ptr @np_object_alloc(i64 %size)', LlvmText) = 0 then
      Fail('missing-hir-class-alloc-object-helper-decl');
    if Pos(' = call ptr @np_alloc(i64 %v', LlvmText) <> 0 then
      Fail('direct-hir-class-alloc-base-alloc-call');

    WriteLn('hir-class-alloc-contract-status=pass');
  finally
    Verifier.Free;
    Emitter.Free;
    Builder.Free;
    SemaModel.Free;
  end;
end.
