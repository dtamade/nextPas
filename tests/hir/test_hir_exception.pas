program test_hir_exception;

{$mode objfpc}{$H+}

uses
  SysUtils, np_semantic_model, np_hir_types, np_hir_model,
  np_hir_builder, np_hir_printer, np_hir_llvm_emitter;

procedure Fail(const AMsg: string);
begin
  WriteLn(StdErr, 'hir-exception-failure=', AMsg);
  Halt(1);
end;

procedure TestTryFinally;
var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  LlvmText: string;
begin
  SemaModel := TSemanticModel.Create;

  { Simulate what sema produces for:
      try
        WriteLn('try');
      finally
        WriteLn('finally');
      end;
      WriteLn('done');
  }

  // try-begin: kind=finally, operand=finally label
  SemaModel.AddTypedHirNode('try-begin-runtime', 'finally', 0, 0,
    'finally1' + #10);
  // try body: WriteLn('try')
  SemaModel.AddTypedHirNode('write-string-runtime', 'Write', 0, 0, 'try');
  SemaModel.AddTypedHirNode('write-string-runtime', 'Write', 0, 0, #10);
  // try-end
  SemaModel.AddTypedHirNode('try-end-runtime', 'finally', 0, 0, '');
  // br to finally label
  SemaModel.AddTypedHirNode('br-runtime', 'finally1', 0, 0, 'finally1');
  // finally block label
  SemaModel.AddTypedHirNode('block-label-runtime', 'finally1', 0, 0, 'finally1');
  // finally-begin
  SemaModel.AddTypedHirNode('finally-begin-runtime', '', 0, 0, '');
  // finally body: WriteLn('finally')
  SemaModel.AddTypedHirNode('write-string-runtime', 'Write', 0, 0, 'finally');
  SemaModel.AddTypedHirNode('write-string-runtime', 'Write', 0, 0, #10);
  // finally-end
  SemaModel.AddTypedHirNode('finally-end-runtime', '', 0, 0, '');
  // br to endtry
  SemaModel.AddTypedHirNode('br-runtime', 'endtry1', 0, 0, 'endtry1');
  // endtry block label
  SemaModel.AddTypedHirNode('block-label-runtime', 'endtry1', 0, 0, 'endtry1');
  // after try: WriteLn('done')
  SemaModel.AddTypedHirNode('write-string-runtime', 'Write', 0, 0, 'done');
  SemaModel.AddTypedHirNode('write-string-runtime', 'Write', 0, 0, #10);
  // halt
  SemaModel.AddTypedHirNode('halt-call-runtime', 'Halt', 0, 0, 'int 0' + #10);

  Builder := THIRBuilder.Create(SemaModel);
  Builder.Build;

  Emitter := THIRLlvmEmitter.Create(Builder.Module);
  Emitter.EmitModule;
  LlvmText := Emitter.AsText;

  if Pos('np_try_push', LlvmText) = 0 then
    Fail('missing-np_try_push-in-llvm-output');
  if Pos('np_finally_end', LlvmText) = 0 then
    Fail('missing-np_finally_end-in-llvm-output');
  if Pos('setjmp', LlvmText) = 0 then
    Fail('missing-setjmp-in-llvm-output');
  if Pos('np_try_pop', LlvmText) = 0 then
    Fail('missing-np_try_pop-in-llvm-output');

  Emitter.SaveToFile('/tmp/hir_exception_finally.ll');

  Emitter.Free;
  Builder.Free;
  SemaModel.Free;
end;

procedure TestTryExcept;
var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  LlvmText: string;
begin
  SemaModel := TSemanticModel.Create;

  { Simulate what sema produces for:
      try
        WriteLn('try');
      except
        WriteLn('caught');
      end;
      WriteLn('done');
  }

  // try-begin: kind=except, operand=except label
  SemaModel.AddTypedHirNode('try-begin-runtime', 'except', 0, 0,
    'except1' + #10);
  // try body: WriteLn('try')
  SemaModel.AddTypedHirNode('write-string-runtime', 'Write', 0, 0, 'try');
  SemaModel.AddTypedHirNode('write-string-runtime', 'Write', 0, 0, #10);
  // try-end
  SemaModel.AddTypedHirNode('try-end-runtime', 'except', 0, 0, '');
  // br to endtry
  SemaModel.AddTypedHirNode('br-runtime', 'endtry1', 0, 0, 'endtry1');
  // except block label
  SemaModel.AddTypedHirNode('block-label-runtime', 'except1', 0, 0, 'except1');
  // except-begin
  SemaModel.AddTypedHirNode('except-begin-runtime', '', 0, 0, '');
  // except body: WriteLn('caught')
  SemaModel.AddTypedHirNode('write-string-runtime', 'Write', 0, 0, 'caught');
  SemaModel.AddTypedHirNode('write-string-runtime', 'Write', 0, 0, #10);
  // except-end
  SemaModel.AddTypedHirNode('except-end-runtime', '', 0, 0, '');
  // br to endtry
  SemaModel.AddTypedHirNode('br-runtime', 'endtry1', 0, 0, 'endtry1');
  // endtry block label
  SemaModel.AddTypedHirNode('block-label-runtime', 'endtry1', 0, 0, 'endtry1');
  // after try: WriteLn('done')
  SemaModel.AddTypedHirNode('write-string-runtime', 'Write', 0, 0, 'done');
  SemaModel.AddTypedHirNode('write-string-runtime', 'Write', 0, 0, #10);
  // halt
  SemaModel.AddTypedHirNode('halt-call-runtime', 'Halt', 0, 0, 'int 0' + #10);

  Builder := THIRBuilder.Create(SemaModel);
  Builder.Build;

  Emitter := THIRLlvmEmitter.Create(Builder.Module);
  Emitter.EmitModule;
  LlvmText := Emitter.AsText;

  if Pos('np_try_push', LlvmText) = 0 then
    Fail('except-missing-np_try_push');
  if Pos('np_except_end', LlvmText) = 0 then
    Fail('except-missing-np_except_end');
  if Pos('setjmp', LlvmText) = 0 then
    Fail('except-missing-setjmp');

  Emitter.SaveToFile('/tmp/hir_exception_except.ll');

  Emitter.Free;
  Builder.Free;
  SemaModel.Free;
end;

begin
  TestTryFinally;
  TestTryExcept;
  WriteLn('hir-exception-status=pass');
end.
