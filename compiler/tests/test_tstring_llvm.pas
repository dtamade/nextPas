program test_tstring_llvm;

{$mode objfpc}{$H+}

uses
  SysUtils, np_semantic_model, np_hir_builder, np_hir_model, np_hir_types,
  np_hir_llvm_emitter;

var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  LlvmIr: string;
  TestCount: LongInt;

procedure Check(Condition: Boolean; const AName: string; ACode: LongInt);
begin
  if not Condition then
  begin
    WriteLn('FAIL [', TestCount, '] ', AName);
    Halt(ACode);
  end;
  Inc(TestCount);
end;

begin
  TestCount := 1;

  { === Test 1: global string variable uses ptr null (pointer to heap TString) === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S', 0, 0, 'S');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('@g_S$ts = internal global ptr null', LlvmIr) > 0,
          'global string var is ptr null', 1);
        { Global has $ts suffix — no old-style $ptr/$len/$owner/$alloc_size }
        Check(Pos('@g_S$ptr', LlvmIr) = 0,
          'no old-style $ptr global for S', 2);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 2: string literal assignment === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S', 0, 0, 'S');
    Model.AddTypedHirNode('assign-tstring-literal-runtime',
      'S', 0, 0, 'Hello');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('call void @np_tstring_from_literal(', LlvmIr) > 0,
          'literal assignment calls tstring_from_literal', 3);
        Check(Pos('declare void @np_tstring_from_literal(', LlvmIr) > 0,
          'tstring_from_literal declared', 4);
        Check(Pos('@.str.', LlvmIr) > 0,
          'string constant emitted', 5);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 3: string copy assignment === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S1', 0, 0, 'S1');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S2', 0, 0, 'S2');
    Model.AddTypedHirNode('assign-tstring-copy-runtime',
      'S2', 0, 0, 'S1');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('call void @np_tstring_assign(', LlvmIr) > 0,
          'copy assignment calls tstring_assign', 6);
        Check(Pos('declare void @np_tstring_assign(', LlvmIr) > 0,
          'tstring_assign declared', 7);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 4: string cleanup (fini) === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S', 0, 0, 'S');
    Model.AddTypedHirNode('tstring-cleanup-runtime',
      'S', 0, 0, '');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('call void @np_tstring_fini(', LlvmIr) > 0,
          'cleanup emits tstring_fini', 8);
        Check(Pos('declare void @np_tstring_fini(', LlvmIr) > 0,
          'tstring_fini declared', 9);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 5: tstring_len intrinsic === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S', 0, 0, 'S');
    Model.AddTypedHirNode('string-temp-length-runtime',
      'L', 0, 0, 'S');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('call i64 @np_tstring_len(', LlvmIr) > 0,
          'length calls tstring_len', 10);
        Check(Pos('declare i64 @np_tstring_len(', LlvmIr) > 0,
          'tstring_len declared', 11);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 6: NO old 4-slot fields in TString IR (checks 12-14) === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S', 0, 0, 'S');
    Model.AddTypedHirNode('assign-tstring-literal-runtime',
      'S', 0, 0, 'Hello World');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        { Verify: no old-style string header fields }
        Check(Pos('$owner', LlvmIr) = 0,
          'no old $owner suffix', 12);
        Check(Pos('$alloc_size', LlvmIr) = 0,
          'no old $alloc_size suffix', 13);
        { Verify: uses new tstring runtime, not old str runtime }
        Check(Pos('np_str_', LlvmIr) = 0,
          'no old np_str_ runtime calls', 14);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 8: tstring_concat intrinsic === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S1', 0, 0, 'S1');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S2', 0, 0, 'S2');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S3', 0, 0, 'S3');
    Model.AddTypedHirNode('assign-tstring-concat-runtime',
      'S3', 0, 0, 'S1'#9'S2');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('call void @np_tstring_concat(', LlvmIr) > 0,
          'concat calls tstring_concat', 15);
        Check(Pos('declare void @np_tstring_concat(', LlvmIr) > 0,
          'tstring_concat declared', 16);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  WriteLn('tstring LLVM IR tests passed (', TestCount - 1, ' checks)');
end.
