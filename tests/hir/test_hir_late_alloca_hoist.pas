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

  SemaModel.AddTypedHirNode('cond-br-runtime', 'if', 0, 0,
    'int 1' + #10 + 'int 1' + #10 + 'cmp eq' + #10 +
    'labels then' + #9 + 'exit');
  SemaModel.AddTypedHirNode('block-label-runtime', 'then', 0, 0, 'then');
  SemaModel.AddTypedHirNode('assign-runtime', 'late.slot := 7', 0, 0,
    'late.slot' + #9 + 'int 7' + #10);
  SemaModel.AddTypedHirNode('br-runtime', 'exit', 0, 0, 'exit');
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
