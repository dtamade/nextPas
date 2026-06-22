program test_process_lifecycle;

{$mode objfpc}{$H+}

uses
  nextpas.core.exception, np_semantic_model, np_hir_builder, np_hir_model,
  np_hir_types;

function HasCallTarget(const AFunc: THIRFunction;
  const ATarget: string): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
  Instr: THIRInstr;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
    begin
      Instr := AFunc.Blocks[BlockIndex].Instrs[InstrIndex];
      if (Instr.Kind = hikCall) and (Instr.CallTarget = ATarget) then
        Exit(True);
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
  { Test 1: process-init-runtime and process-fini-runtime generate calls }
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
      if not HasCallTarget(StartFunc, 'np_process_init') then
        Halt(2);
      if not HasCallTarget(StartFunc, 'np_process_fini') then
        Halt(3);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { Test 2: without process lifecycle nodes, no calls generated }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('var-decl-runtime', 'x', 0, 0, 'x');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      if Builder.Module.FunctionCount = 0 then
        Halt(4);
      StartFunc := GetStartFunc(Builder.Module);
      if HasCallTarget(StartFunc, 'np_process_init') then
        Halt(5);
      if HasCallTarget(StartFunc, 'np_process_fini') then
        Halt(6);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  WriteLn('process lifecycle tests passed');
end.
