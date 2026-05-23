program test_hir_late_alloca_hoist;

{$mode objfpc}{$H+}

uses
  SysUtils, np_semantic_model, np_hir_types, np_hir_model,
  np_hir_builder, np_hir_llvm_emitter;

var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  OutputPath: string;
begin
  if ParamCount >= 1 then
    OutputPath := ParamStr(1)
  else
    OutputPath := '/tmp/hir_late_alloca_hoist.ll';

  SemaModel := TSemanticModel.Create;

  SemaModel.AddTypedHirNode('var-decl-runtime', 'i', 0, 0, 'i');
  SemaModel.AddTypedHirNode('assign-runtime', 'i := 3', 0, 0,
    'i' + #9 + 'int 3' + #10);
  SemaModel.AddTypedHirNode('block-label-runtime', 'cond', 0, 0, 'cond');
  SemaModel.AddTypedHirNode('cond-br-runtime', 'while', 0, 0,
    'var i' + #10 + 'int 0' + #10 + 'cmp sgt' + #10 +
    'labels body' + #9 + 'exit');
  SemaModel.AddTypedHirNode('block-label-runtime', 'body', 0, 0, 'body');
  SemaModel.AddTypedHirNode('assign-runtime', 'late.slot := 7', 0, 0,
    'late.slot' + #9 + 'int 7' + #10);
  SemaModel.AddTypedHirNode('assign-runtime', 'i := i - 1', 0, 0,
    'i' + #9 + 'var i' + #10 + 'int 1' + #10 + 'sub' + #10);
  SemaModel.AddTypedHirNode('br-runtime', 'cond', 0, 0, 'cond');
  SemaModel.AddTypedHirNode('block-label-runtime', 'exit', 0, 0, 'exit');
  SemaModel.AddTypedHirNode('halt-call-runtime', 'Halt(late.slot)', 0, 0,
    'var late.slot' + #10);

  Builder := THIRBuilder.Create(SemaModel);
  Builder.Build;

  Emitter := THIRLlvmEmitter.Create(Builder.Module);
  Emitter.EmitModule;
  Emitter.SaveToFile(OutputPath);

  Emitter.Free;
  Builder.Free;
  SemaModel.Free;
end.
