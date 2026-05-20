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

  // function Double(x): Integer; begin Double := x * 2; end;
  SemaModel.AddTypedHirNode('function-body-begin', 'Double', 0, 0,
    'Double' + #9 + 'i' + #9 + '1' + #9 + 'x');
  SemaModel.AddTypedHirNode('var-decl-runtime', 'x', 0, 0, 'x');
  SemaModel.AddTypedHirNode('ret-runtime', 'Result', 0, 0,
    'var x' + #10 + 'int 2' + #10 + 'mul' + #10);
  SemaModel.AddTypedHirNode('function-body-end', 'Double', 0, 0, '');

  // function Inc3(x): Integer; begin Inc3 := x + 3; end;
  SemaModel.AddTypedHirNode('function-body-begin', 'Inc3', 0, 0,
    'Inc3' + #9 + 'i' + #9 + '1' + #9 + 'x');
  SemaModel.AddTypedHirNode('var-decl-runtime', 'x', 0, 0, 'x');
  SemaModel.AddTypedHirNode('ret-runtime', 'Result', 0, 0,
    'var x' + #10 + 'int 3' + #10 + 'add' + #10);
  SemaModel.AddTypedHirNode('function-body-end', 'Inc3', 0, 0, '');

  // begin Halt(Double(Inc3(2))); end.  => (2+3)*2 = 10
  SemaModel.AddTypedHirNode('halt-call-runtime', 'Halt', 0, 0,
    'int 2' + #10 + 'call Inc3 1' + #10 + 'call Double 1' + #10);

  Builder := THIRBuilder.Create(SemaModel);
  Builder.Build;

  Emitter := THIRLlvmEmitter.Create(Builder.Module);
  Emitter.EmitModule;
  Emitter.SaveToFile('/tmp/hir_e2e_compose.ll');

  Emitter.Free;
  Builder.Free;
  SemaModel.Free;
end.
