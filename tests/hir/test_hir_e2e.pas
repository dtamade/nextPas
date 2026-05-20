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

  // i := 3; while i > 0 do begin WriteLn(i); i := i - 1; end; Halt(0);
  SemaModel.AddTypedHirNode('var-decl-runtime', 'i', 0, 0, 'i');
  SemaModel.AddTypedHirNode('assign-runtime', 'i := 3', 0, 0,
    'i' + #9 + 'int 3' + #10);

  SemaModel.AddTypedHirNode('block-label-runtime', 'wc', 0, 0, 'wc');
  SemaModel.AddTypedHirNode('cond-br-runtime', 'while i > 0', 0, 0,
    'var i' + #10 + 'int 0' + #10 + 'cmp sgt' + #10 +
    'labels wb' + #9 + 'we' + #10);

  SemaModel.AddTypedHirNode('block-label-runtime', 'wb', 0, 0, 'wb');
  SemaModel.AddTypedHirNode('write-int-runtime', 'WriteLn(i)', 0, 0,
    'var i' + #10);
  SemaModel.AddTypedHirNode('assign-runtime', 'i := i - 1', 0, 0,
    'i' + #9 + 'var i' + #10 + 'int 1' + #10 + 'sub' + #10);
  SemaModel.AddTypedHirNode('br-runtime', 'goto wc', 0, 0, 'wc');

  SemaModel.AddTypedHirNode('block-label-runtime', 'we', 0, 0, 'we');
  SemaModel.AddTypedHirNode('halt-call-runtime', 'Halt(0)', 0, 0,
    'int 0' + #10);

  Builder := THIRBuilder.Create(SemaModel);
  Builder.Build;

  Emitter := THIRLlvmEmitter.Create(Builder.Module);
  Emitter.EmitModule;
  Emitter.SaveToFile('/tmp/hir_e2e_writeln.ll');

  Emitter.Free;
  Builder.Free;
  SemaModel.Free;
end.
