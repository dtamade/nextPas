program test_hir_halt_contract;

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv, nextpas.compiler.sema.semantic_model, nextpas.compiler.ir.hir.types, nextpas.compiler.ir.hir.model,
  nextpas.compiler.ir.hir.builder, nextpas.compiler.ir.hir.llvm_emitter, nextpas.compiler.ir.hir.verifier, nextpas.compiler.ir.system_contracts;

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-halt-contract-failure=', AMessage);
  Halt(1);
end;

function CountTypedHalt(AModule: THIRModule; out AConstCount, AExprCount: LongInt): Boolean;
var
  Func: THIRFunction;
  Instr: THIRInstr;
  ContractDefinition: TSystemContractDefinition;
  OperandType: THIRTypeRec;
  FuncIndex, BlockIndex, InstrIndex: LongInt;
begin
  AConstCount := 0;
  AExprCount := 0;
  Result := True;
  for FuncIndex := 0 to AModule.FunctionCount - 1 do
  begin
    Func := AModule.FunctionAt(FuncIndex);
    for BlockIndex := 0 to LongInt(Func.Blocks.Count) - 1 do
      if Func.Blocks[SizeUInt(BlockIndex)].Instrs <> nil then
        for InstrIndex := 0 to LongInt(Func.Blocks[SizeUInt(BlockIndex)].Instrs.Count) - 1 do
        begin
          Instr := Func.Blocks[SizeUInt(BlockIndex)].Instrs[SizeUInt(InstrIndex)];
          if (Instr.Kind = hikIntrinsic) and IsSystemContract(Instr, sckHalt) then
          begin
            ContractDefinition := SystemContractAt(sckHalt);
            if Instr.IntrinsicName <> ContractDefinition.SemanticName then
            begin
              WriteLn('hir-halt-contract-failure=halt-name-mismatch:',
                Instr.IntrinsicName);
              Exit(False);
            end;
            if Length(Instr.Operands) = 0 then
            begin
              Inc(AConstCount);
              if Instr.CallTarget = '' then
              begin
                WriteLn('hir-halt-contract-failure=halt-const-target-missing');
                Exit(False);
              end;
            end
            else if Length(Instr.Operands) = 1 then
            begin
              Inc(AExprCount);
              OperandType := AModule.Types.GetType(Instr.Operands[0].TypeId);
              if OperandType.Kind <> htkInt then
              begin
                WriteLn('hir-halt-contract-failure=halt-expr-operand-not-int');
                Exit(False);
              end;
            end
            else
            begin
              WriteLn('hir-halt-contract-failure=halt-operand-count:',
                IntToStr(Length(Instr.Operands)));
              Exit(False);
            end;
          end;
          if (Instr.Kind = hikIntrinsic) and (not Instr.HasSystemContract) and
            (Instr.IntrinsicName = 'halt') then
          begin
            WriteLn('hir-halt-contract-failure=legacy-untyped-halt-intrinsic');
            Exit(False);
          end;
        end;
  end;
end;

procedure CheckConstHalt;
var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Verifier: THIRVerifier;
  Emitter: THIRLlvmEmitter;
  LlvmText: string;
  ConstCount, ExprCount: LongInt;
begin
  SemaModel := TSemanticModel.Create;
  Builder := nil;
  Verifier := nil;
  Emitter := nil;
  try
    SemaModel.AddTypedHirNode('halt-call', 'Halt', 0, 0, '42');
    Builder := THIRBuilder.Create(SemaModel);
    Builder.Build;
    Verifier := THIRVerifier.Create(Builder.Module);
    if not Verifier.Verify then
      Fail('const-hir-verifier-error-count:' + IntToStr(Verifier.ErrorCount));
    if not CountTypedHalt(Builder.Module, ConstCount, ExprCount) then
      Halt(1);
    WriteLn('hir-halt-contract-const-count=', ConstCount);
    if ConstCount < 1 then
      Fail('missing-typed-halt-const');
    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;
    if Pos('movq $$60, %rax; syscall', LlvmText) = 0 then
      Fail('const-missing-halt-syscall-lowering');
    if Pos('(i64 42)', LlvmText) = 0 then
      Fail('missing-halt-const-exit-code');
  finally
    Emitter.Free;
    Verifier.Free;
    Builder.Free;
    SemaModel.Free;
  end;
end;

procedure CheckExprHalt;
var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Verifier: THIRVerifier;
  Emitter: THIRLlvmEmitter;
  LlvmText: string;
  ConstCount, ExprCount: LongInt;
begin
  SemaModel := TSemanticModel.Create;
  Builder := nil;
  Verifier := nil;
  Emitter := nil;
  try
    SemaModel.AddTypedHirNode('var-decl-runtime', 'Code', 0, 0, 'Code');
    SemaModel.AddTypedHirNode('assign-runtime', 'Code := 7', 0, 0,
      'Code' + #9 + 'int 7' + #10);
    SemaModel.AddTypedHirNode('halt-call-runtime', 'Halt(Code)', 0, 0,
      'var Code' + #10);
    Builder := THIRBuilder.Create(SemaModel);
    Builder.Build;
    Verifier := THIRVerifier.Create(Builder.Module);
    if not Verifier.Verify then
      Fail('expr-hir-verifier-error-count:' + IntToStr(Verifier.ErrorCount));
    if not CountTypedHalt(Builder.Module, ConstCount, ExprCount) then
      Halt(1);
    WriteLn('hir-halt-contract-expr-count=', ExprCount);
    if ExprCount < 1 then
      Fail('missing-typed-halt-expr');
    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;
    if Pos('movq $$60, %rax; syscall', LlvmText) = 0 then
      Fail('expr-missing-halt-syscall-lowering');
  finally
    Emitter.Free;
    Verifier.Free;
    Builder.Free;
    SemaModel.Free;
  end;
end;

begin
  CheckConstHalt;
  CheckExprHalt;
  WriteLn('hir-halt-contract-llvm-syscall=found');
  WriteLn('hir-halt-contract=pass');
end.