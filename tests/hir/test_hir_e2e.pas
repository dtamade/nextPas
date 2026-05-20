program test_hir_e2e;

{$mode objfpc}{$H+}

uses
  SysUtils, np_semantic_model, np_hir_types, np_hir_model,
  np_hir_builder, np_hir_printer, np_hir_llvm_emitter;

var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
begin
  SemaModel := TSemanticModel.Create;

  // i := 0; while i < 5 do i := i + 1; Halt(i);
  SemaModel.AddTypedHirNode('var-decl-runtime', 'i', 0, 0, 'i');
  SemaModel.AddTypedHirNode('assign-runtime', 'i := 0', 0, 0,
    'i' + #9 + 'int 0' + #10);

  // while condition check
  SemaModel.AddTypedHirNode('block-label-runtime', 'while_cond', 0, 0, 'while_cond');
  SemaModel.AddTypedHirNode('cond-br-runtime', 'while i < 5', 0, 0,
    'var i' + #10 + 'int 5' + #10 + 'cmp slt' + #10 +
    'labels while_body' + #9 + 'while_end' + #10);

  // while body
  SemaModel.AddTypedHirNode('block-label-runtime', 'while_body', 0, 0, 'while_body');
  SemaModel.AddTypedHirNode('assign-runtime', 'i := i + 1', 0, 0,
    'i' + #9 + 'var i' + #10 + 'int 1' + #10 + 'add' + #10);
  SemaModel.AddTypedHirNode('br-runtime', 'goto while_cond', 0, 0, 'while_cond');

  // after loop
  SemaModel.AddTypedHirNode('block-label-runtime', 'while_end', 0, 0, 'while_end');
  SemaModel.AddTypedHirNode('halt-call-runtime', 'Halt(i)', 0, 0,
    'var i' + #10);

  Builder := THIRBuilder.Create(SemaModel);
  Builder.Build;

  Emitter := THIRLlvmEmitter.Create(Builder.Module);
  Emitter.EmitModule;
  Emitter.SaveToFile('/tmp/hir_e2e_loop.ll');

  WriteLn(Emitter.AsText);

  Emitter.Free;
  Builder.Free;
  SemaModel.Free;
end.
