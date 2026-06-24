program test_tstring_llvm;

{$mode objfpc}{$H+}

uses
  np_semantic_model, np_hir_builder, np_hir_model, np_hir_types,
  np_hir_llvm_emitter;

var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  LlvmIr: string;
  TestCount: LongInt;

function CountSubstring(const AText, ASubstring: string): LongInt;
var
  Offset, MatchPos: SizeInt;
begin
  Result := 0;
  if (AText = '') or (ASubstring = '') then
    Exit;
  Offset := 1;
  repeat
    MatchPos := Pos(ASubstring, Copy(AText, Offset, MaxInt));
    if MatchPos = 0 then
      Break;
    Inc(Result);
    Inc(Offset, MatchPos + Length(ASubstring) - 1);
  until False;
end;

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

  { === Test 8: assign-tstring-call-runtime (call string-returning func) === }
  Model := TSemanticModel.Create;
  try
    { Declare callee with string return }
    Model.AddTypedHirNode('func-runtime', 'GetStr:s', 0, 0, '');
    { Caller function }
    Model.AddTypedHirNode('start-func-runtime', 'TestCall', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'R', 0, 0, 'R');
    Model.AddTypedHirNode('assign-tstring-call-runtime',
      'GetStr', 0, 0, 'R');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('call void @GetStr(ptr', LlvmIr) > 0,
          'call emits void @GetStr with sret ptr', 17);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 9: tstring_field_assign declared via any tstring intrinsic === }
  { Field store test deferred: requires full object alloca setup.
    Instead verify emitter declares tstring_field_assign when any
    tstring intrinsic is used (from_literal triggers the declarations). }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S', 0, 0, 'S');
    Model.AddTypedHirNode('assign-tstring-literal-runtime',
      'S', 0, 0, 'Check');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        { All tstring runtime functions are declared when any tstring intrinsic is used }
        Check(Pos('declare void @np_tstring_field_assign(', LlvmIr) > 0,
          'tstring_field_assign declared', 18);
        Check(Pos('declare void @np_tstring_ret_move(', LlvmIr) > 0,
          'tstring_ret_move declared', 19);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 10: tstring-from-int-runtime emits np_tstring_from_int === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S', 0, 0, 'S');
    Model.AddTypedHirNode('tstring-from-int-runtime',
      'S', 0, 0, 'S'#9'int 42'#10);
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('call void @np_tstring_from_int(', LlvmIr) > 0,
          'tstring-from-int emits tstring_from_int', 20);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 11: tstring-copy-runtime emits np_tstring_copy === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'Src', 0, 0, 'Src');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'Dst', 0, 0, 'Dst');
    Model.AddTypedHirNode('tstring-copy-runtime',
      'Dst', 0, 0, 'Dst'#9'Src'#9'int 2'#10#9'int 3'#10);
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('call void @np_tstring_copy(', LlvmIr) > 0,
          'tstring-copy emits tstring_copy', 21);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 12: write-str-var-runtime emits write_str_var from tstring data/len === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S', 0, 0, 'S');
    Model.AddTypedHirNode('write-str-var-runtime',
      'Write', 0, 0, 'S');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('call ptr @np_tstring_data(', LlvmIr) > 0,
          'write-str-var loads tstring data', 22);
        Check(Pos('call i64 @np_tstring_len(', LlvmIr) > 0,
          'write-str-var loads tstring len', 23);
        Check(Pos('syscall", "{rdi},{rsi},{rdx}', LlvmIr) > 0,
          'write-str-var lowers to write syscall', 24);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 13: call-runtime strvar arg uses ptr+len ABI === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('function-body-begin',
      'Consume', 0, 0, '1:p:s');
    Model.AddTypedHirNode('function-body-end',
      'Consume', 0, 0, '');
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S', 0, 0, 'S');
    Model.AddTypedHirNode('call-runtime',
      'Consume', 0, 0, 'Consume'#9'strvar S');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('call ptr @np_tstring_data(', LlvmIr) > 0,
          'call-runtime strvar extracts data', 25);
        Check(Pos('call i64 @np_tstring_len(', LlvmIr) > 0,
          'call-runtime strvar extracts len', 26);
        Check(Pos('@Consume(ptr ', LlvmIr) > 0,
          'call-runtime emits ptr arg for string data', 27);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 14: class-new-runtime strvar arg uses ptr+len ABI === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('start-func-runtime', 'CtorTest', 0, 0, '');
    Model.AddTypedHirNode('var-decl-ptr-runtime', 'Obj', 0, 0, 'Obj');
    Model.AddTypedHirNode('var-decl-tstring-runtime', 'S', 0, 0, 'S');
    Model.AddTypedHirNode('class-new-runtime',
      '16', 0, 0, 'Obj'#9'MyClass.Create'#9'strvar S');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('call ptr @np_tstring_data(', LlvmIr) > 0,
          'class-new strvar extracts data', 28);
        Check(Pos('call i64 @np_tstring_len(', LlvmIr) > 0,
          'class-new strvar extracts len', 29);
        Check(Pos('@MyClass.Create(ptr ', LlvmIr) > 0,
          'class-new emits constructor call', 30);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 15: assign-tstring-call-runtime strvar arg uses ptr+len ABI === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('start-func-runtime', 'AssignCallTest', 0, 0, '');
    Model.AddTypedHirNode('function-body-begin', 'Echo', 0, 0, '1:s:s');
    Model.AddTypedHirNode('function-body-end', 'Echo', 0, 0, '');
    Model.AddTypedHirNode('function-body-begin', 'AssignCallTest', 0, 0, '0::');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'ArgS', 0, 0, 'ArgS');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'ResS', 0, 0, 'ResS');
    Model.AddTypedHirNode('assign-tstring-call-runtime',
      'ResS', 0, 0, 'ResS'#9'callee Echo'#9'strvar ArgS');
    Model.AddTypedHirNode('function-body-end', 'AssignCallTest', 0, 0, '');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('call ptr @np_tstring_data(', LlvmIr) > 0,
          'assign-tstring-call strvar extracts data', 31);
        Check(Pos('call i64 @np_tstring_len(', LlvmIr) > 0,
          'assign-tstring-call strvar extracts len', 32);
        Check(Pos('call void @Echo(ptr ', LlvmIr) > 0,
          'assign-tstring-call emits sret call', 33);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 16: method string return uses TString sret ABI === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('method-body-begin',
      'TMyClass.GetName', 0, 0, '1::s');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'Result', 0, 0, 'Result');
    Model.AddTypedHirNode('ret-tstring-runtime',
      'Result', 0, 0, 'Result');
    Model.AddTypedHirNode('function-body-end',
      'TMyClass.GetName', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('define void @TMyClass.GetName(ptr sret(%TString) %agg.result', LlvmIr) > 0,
          'method string return uses sret ABI', 34);
        Check(Pos('call void @np_tstring_ret_move(ptr %v1, ptr ', LlvmIr) > 0,
          'method string return moves into sret slot', 35);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 17: write-int-runtime emits write_i64_decimal === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('write-int-runtime',
      'Write', 0, 0, 'int 123'#10);
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('call void @write_i64_decimal(i64 ', LlvmIr) > 0,
          'write-int emits write_i64_decimal', 36);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 18: write-string-runtime emits literal write syscall === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('write-string-runtime',
      'Write', 0, 0, 'Hello');
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('syscall", "{rdi},{rsi},{rdx}', LlvmIr) > 0,
          'write-string emits write syscall', 37);
        Check(Pos('i64 5)', LlvmIr) > 0,
          'write-string uses literal length', 38);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 19: write-call emits folded literal write syscall === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('write-call',
      'WriteLn', 0, 0, 'Hi'#10);
    Model.AddTypedHirNode('process-fini-runtime',
      'np.system.process_fini', 0, 0, '');

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        LlvmIr := Emitter.AsText;

        Check(Pos('syscall", "{rdi},{rsi},{rdx}', LlvmIr) > 0,
          'write-call emits write syscall', 39);
        Check(Pos('i64 3)', LlvmIr) > 0,
          'write-call preserves newline length', 40);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 13: string-temp-length-runtime stores result in $len alloca === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S', 0, 0, 'S');
    Model.AddTypedHirNode('string-temp-length-runtime',
      'S', 0, 0, 'strvar S');
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
          'string-temp-length emits tstring_len', 41);
        Check(Pos('store i64', LlvmIr) > 0,
          'string-temp-length stores result in $len', 42);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 14: BlobVar $len path computes tstring_len for TString vars === }
  Model := TSemanticModel.Create;
  try
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-tstring-runtime',
      'S', 0, 0, 'S');
    Model.AddTypedHirNode('var-decl-runtime',
      'Len', 0, 0, 'Len');
    Model.AddTypedHirNode('assign-runtime',
      'Len', 0, 0, 'Len'#9'var S$len');
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
          'BlobVar $len computes tstring_len', 43);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 15: managed-record-cleanup emits tstring_fini for string field === }
  Model := TSemanticModel.Create;
  try
    Model.AddConstValue('TRec.Name$idx', 0);
    Model.SetTypeMeta(Model.AddType('TRec', 'declared'), Default(TTypeMetadata));
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-record-runtime',
      'R', 0, 0, 'R'#9'3');
    Model.AddTypedHirNode('managed-record-cleanup-runtime',
      'Cleanup', 0, 0, 'R'#9'TRec'#9'Name:s');
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
          'managed record cleanup emits tstring_fini', 44);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  { === Test 16: managed-record-cleanup only cleans string field once === }
  Model := TSemanticModel.Create;
  try
    Model.AddConstValue('TRec.Name$idx', 0);
    Model.SetTypeMeta(Model.AddType('TRec', 'declared'), Default(TTypeMetadata));
    Model.AddTypedHirNode('process-init-runtime',
      'np.system.process_init', 0, 0, '');
    Model.AddTypedHirNode('var-decl-record-runtime',
      'R', 0, 0, 'R'#9'4');
    Model.AddTypedHirNode('managed-record-cleanup-runtime',
      'Cleanup', 0, 0, 'R'#9'TRec'#9'Name:s');
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
          'mixed record cleanup still emits tstring_fini', 45);
        Check(CountSubstring(LlvmIr, 'call void @np_tstring_fini(') = 1,
          'mixed record cleanup emits one tstring_fini call', 46);
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
