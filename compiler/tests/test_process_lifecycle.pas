program test_process_lifecycle;

{$mode objfpc}{$H+}

uses
  nextpas.core.exception, nextpas.compiler.sema.semantic_model, nextpas.compiler.ir.hir.builder, nextpas.compiler.ir.hir.model,
  nextpas.compiler.ir.hir.types, nextpas.compiler.ir.system_contracts;

function HasProcessContract(const AFunc: THIRFunction;
  AKind: TSystemContractKind): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
  Instr: THIRInstr;
  ContractDefinition: TSystemContractDefinition;
begin
  ContractDefinition := SystemContractAt(AKind);
  if AFunc.Blocks <> nil then
    for BlockIndex := 0 to LongInt(AFunc.Blocks.Count) - 1 do
      if AFunc.Blocks[SizeUInt(BlockIndex)].Instrs <> nil then
        for InstrIndex := 0 to
          LongInt(AFunc.Blocks[SizeUInt(BlockIndex)].Instrs.Count) - 1 do
        begin
          Instr := AFunc.Blocks[SizeUInt(BlockIndex)].Instrs[
            SizeUInt(InstrIndex)];
          if IsSystemContract(Instr, AKind) then
          begin
            if Instr.Kind <> hikIntrinsic then
              Exit(False);
            if Instr.IntrinsicName <> ContractDefinition.SemanticName then
              Exit(False);
            if Instr.CallTarget <> ContractDefinition.RuntimeMapping then
              Exit(False);
            if Length(Instr.Operands) <> 0 then
              Exit(False);
            Exit(True);
          end;
        end;
  Result := False;
end;

function GetStartFunc(const AModule: THIRModule): THIRFunction;
var
  I: LongInt;
begin
  for I := 0 to AModule.FunctionCount - 1 do
  begin
    Result := AModule.FunctionAt(I);
    if Result.Name = '_start' then
      Exit;
  end;
  raise Exception.Create('_start not found');
end;

var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  StartFunc: THIRFunction;
begin
  { Test 1: process lifecycle nodes → typed System contracts on _start }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-runtime', 'x', 0, 0, 'x');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      if Builder.Module.FunctionCount = 0 then
        Halt(1);
      StartFunc := GetStartFunc(Builder.Module);
      if not HasProcessContract(StartFunc, sckProcessInit) then
        Halt(2);
      if not HasProcessContract(StartFunc, sckProcessFini) then
        Halt(3);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { Test 2: without process lifecycle nodes, no typed process contracts }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('var-decl-runtime', 'x', 0, 0, 'x');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      if Builder.Module.FunctionCount = 0 then
        Halt(4);
      StartFunc := GetStartFunc(Builder.Module);
      if HasProcessContract(StartFunc, sckProcessInit) then
        Halt(5);
      if HasProcessContract(StartFunc, sckProcessFini) then
        Halt(6);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  WriteLn('process lifecycle tests passed');
end.