program test_hir_e2e_chain;

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

  // halt-call-runtime: Halt(Tripled())
  SemaModel.AddTypedHirNode('halt-call-runtime', 'Halt', 0, 0,
    'call Tripled 0' + #10);

  // function Base: Integer; begin Base := 5; end;
  SemaModel.AddTypedHirNode('function-body-begin', 'Base', 0, 0, '0:');
  SemaModel.AddTypedHirNode('var-decl-runtime', 'Base', 0, 0, 'Base');
  SemaModel.AddTypedHirNode('assign-runtime', 'Base', 0, 0,
    'Base' + #9 + 'int 5' + #10);
  SemaModel.AddTypedHirNode('ret-runtime', 'Base', 0, 0,
    'var Base' + #10);
  SemaModel.AddTypedHirNode('function-body-end', 'Base', 0, 0, '');

  // function Doubled: Integer; begin Doubled := Base() * 2; end;
  SemaModel.AddTypedHirNode('function-body-begin', 'Doubled', 0, 0, '0:');
  SemaModel.AddTypedHirNode('var-decl-runtime', 'Doubled', 0, 0, 'Doubled');
  SemaModel.AddTypedHirNode('assign-runtime', 'Doubled', 0, 0,
    'Doubled' + #9 + 'call Base 0' + #10 + 'int 2' + #10 + 'mul' + #10);
  SemaModel.AddTypedHirNode('ret-runtime', 'Doubled', 0, 0,
    'var Doubled' + #10);
  SemaModel.AddTypedHirNode('function-body-end', 'Doubled', 0, 0, '');

  // function Tripled: Integer; begin Tripled := Doubled() + Base(); end;
  SemaModel.AddTypedHirNode('function-body-begin', 'Tripled', 0, 0, '0:');
  SemaModel.AddTypedHirNode('var-decl-runtime', 'Tripled', 0, 0, 'Tripled');
  SemaModel.AddTypedHirNode('assign-runtime', 'Tripled', 0, 0,
    'Tripled' + #9 + 'call Doubled 0' + #10 + 'call Base 0' + #10 + 'add' + #10);
  SemaModel.AddTypedHirNode('ret-runtime', 'Tripled', 0, 0,
    'var Tripled' + #10);
  SemaModel.AddTypedHirNode('function-body-end', 'Tripled', 0, 0, '');

  Builder := THIRBuilder.Create(SemaModel);
  Builder.Build;

  Emitter := THIRLlvmEmitter.Create(Builder.Module);
  Emitter.EmitModule;
  Emitter.SaveToFile('/tmp/hir_e2e_chain.ll');

  WriteLn('HIR e2e chain test: LLVM IR saved to /tmp/hir_e2e_chain.ll');

  Emitter.Free;
  Builder.Free;
  SemaModel.Free;
end.
