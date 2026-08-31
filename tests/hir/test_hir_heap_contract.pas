program test_hir_heap_contract;

{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.compiler.sema.semantic_model, nextpas.compiler.ir.hir.types, nextpas.compiler.ir.hir.model,
  nextpas.compiler.ir.hir.builder, nextpas.compiler.ir.hir.llvm_emitter, nextpas.compiler.ir.hir.verifier, nextpas.compiler.ir.system_contracts;

procedure Fail(const AMessage: string);
begin
  WriteLn('hir-heap-contract-failure=', AMessage);
  Halt(1);
end;

function CountTypedHeap(AModule: THIRModule;
  out AAllocCount, AFreeCount: LongInt): Boolean;
var
  Func: THIRFunction;
  Instr: THIRInstr;
  ContractDefinition: TSystemContractDefinition;
  OperandType: THIRTypeRec;
  FuncIndex, BlockIndex, InstrIndex: LongInt;
begin
  AAllocCount := 0;
  AFreeCount := 0;
  Result := True;
  for FuncIndex := 0 to AModule.FunctionCount - 1 do
  begin
    Func := AModule.FunctionAt(FuncIndex);
    for BlockIndex := 0 to LongInt(Func.Blocks.Count) - 1 do
      if Func.Blocks[SizeUInt(BlockIndex)].Instrs <> nil then
        for InstrIndex := 0 to LongInt(Func.Blocks[SizeUInt(BlockIndex)].Instrs.Count) - 1 do
        begin
          Instr := Func.Blocks[SizeUInt(BlockIndex)].Instrs[SizeUInt(InstrIndex)];
          if (Instr.Kind = hikIntrinsic) and IsSystemContract(Instr, sckHeapAlloc) then
          begin
            Inc(AAllocCount);
            ContractDefinition := SystemContractAt(sckHeapAlloc);
            if Instr.IntrinsicName <> ContractDefinition.SemanticName then
            begin
              WriteLn('hir-heap-contract-failure=heap-alloc-name-mismatch:',
                Instr.IntrinsicName);
              Exit(False);
            end;
            if Length(Instr.Operands) <> 1 then
            begin
              WriteLn('hir-heap-contract-failure=heap-alloc-operand-count:',
                IntToStr(Length(Instr.Operands)));
              Exit(False);
            end;
            OperandType := AModule.Types.GetType(Instr.Operands[0].TypeId);
            if OperandType.Kind <> htkInt then
            begin
              WriteLn('hir-heap-contract-failure=heap-alloc-operand-not-int');
              Exit(False);
            end;
          end;
          if (Instr.Kind = hikIntrinsic) and IsSystemContract(Instr, sckHeapFree) then
          begin
            Inc(AFreeCount);
            ContractDefinition := SystemContractAt(sckHeapFree);
            if Instr.IntrinsicName <> ContractDefinition.SemanticName then
            begin
              WriteLn('hir-heap-contract-failure=heap-free-name-mismatch:',
                Instr.IntrinsicName);
              Exit(False);
            end;
            if Length(Instr.Operands) <> 1 then
            begin
              WriteLn('hir-heap-contract-failure=heap-free-operand-count:',
                IntToStr(Length(Instr.Operands)));
              Exit(False);
            end;
            OperandType := AModule.Types.GetType(Instr.Operands[0].TypeId);
            if OperandType.Kind <> htkPointer then
            begin
              WriteLn('hir-heap-contract-failure=heap-free-operand-not-pointer');
              Exit(False);
            end;
          end;
          if (Instr.Kind = hikIntrinsic) and (not Instr.HasSystemContract) and
            ((Instr.IntrinsicName = 'getmem') or
             (Instr.IntrinsicName = 'freemem')) then
          begin
            WriteLn('hir-heap-contract-failure=legacy-untyped-heap-intrinsic:',
              Instr.IntrinsicName);
            Exit(False);
          end;
        end;
  end;
end;

procedure CheckGetMemFreeMem;
var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Verifier: THIRVerifier;
  Emitter: THIRLlvmEmitter;
  LlvmText: string;
  AllocCount, FreeCount: LongInt;
begin
  SemaModel := TSemanticModel.Create;
  Builder := nil;
  Verifier := nil;
  Emitter := nil;
  try
    SemaModel.AddTypedHirNode('var-decl-runtime', 'P', 0, 0, 'P');
    SemaModel.AddTypedHirNode('getmem-runtime', 'GetMem(P, 64)', 0, 0,
      'P' + #9 + 'int 64' + #10);
    SemaModel.AddTypedHirNode('freemem-runtime', 'FreeMem(P)', 0, 0, 'P');
    Builder := THIRBuilder.Create(SemaModel);
    Builder.Build;
    Verifier := THIRVerifier.Create(Builder.Module);
    if not Verifier.Verify then
      Fail('hir-verifier-error-count:' + IntToStr(Verifier.ErrorCount));
    if not CountTypedHeap(Builder.Module, AllocCount, FreeCount) then
      Halt(1);
    WriteLn('hir-heap-contract-alloc-count=', AllocCount);
    WriteLn('hir-heap-contract-free-count=', FreeCount);
    if AllocCount < 1 then
      Fail('missing-typed-heap-alloc');
    if FreeCount < 1 then
      Fail('missing-typed-heap-free');
    Emitter := THIRLlvmEmitter.Create(Builder.Module);
    Emitter.EmitModule;
    LlvmText := Emitter.AsText;
    if Pos(' = call ptr @np_alloc(i64 ', LlvmText) = 0 then
      Fail('missing-heap-alloc-np-alloc-call');
    if Pos('call void @np_free(ptr ', LlvmText) = 0 then
      Fail('missing-heap-free-np-free-call');
    if Pos('declare ptr @np_alloc(i64 %size)', LlvmText) = 0 then
      Fail('missing-heap-alloc-declare');
    if Pos('declare void @np_free(ptr %raw, i64 %size)', LlvmText) = 0 then
      Fail('missing-heap-free-declare');
  finally
    Emitter.Free;
    Verifier.Free;
    Builder.Free;
    SemaModel.Free;
  end;
end;

begin
  CheckGetMemFreeMem;
  WriteLn('hir-heap-contract-llvm-helpers=found');
  WriteLn('hir-heap-contract=pass');
end.