program test_process_lifecycle_llvm;

{$mode objfpc}{$H+}

uses
  np_semantic_model, np_hir_builder, np_hir_model, np_hir_types,
  np_hir_llvm_emitter;

var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  LlvmIr: string;
begin
  { Test: LLVM IR contains declare for np_process_init/fini and calls }
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
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        if Pos('declare void @np_process_init()', LlvmIr) = 0 then
        begin
          WriteLn('FAIL: missing declare void @np_process_init()');
          Halt(1);
        end;
        if Pos('declare void @np_process_fini()', LlvmIr) = 0 then
        begin
          WriteLn('FAIL: missing declare void @np_process_fini()');
          Halt(2);
        end;
        if Pos('call void @np_process_init()', LlvmIr) = 0 then
        begin
          WriteLn('FAIL: missing call void @np_process_init() in _start');
          Halt(3);
        end;
        if Pos('call void @np_process_fini()', LlvmIr) = 0 then
        begin
          WriteLn('FAIL: missing call void @np_process_fini() in _start');
          Halt(4);
        end;
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { Test: without lifecycle nodes, no declares emitted }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('var-decl-runtime', 'x', 0, 0, 'x');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        if Pos('np_process_init', LlvmIr) <> 0 then
        begin
          WriteLn('FAIL: unexpected np_process_init in IR without lifecycle');
          Halt(5);
        end;
        if Pos('np_process_fini', LlvmIr) <> 0 then
        begin
          WriteLn('FAIL: unexpected np_process_fini in IR without lifecycle');
          Halt(6);
        end;
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  WriteLn('process lifecycle LLVM IR tests passed');
end.
