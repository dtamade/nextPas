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

  // function Square(n: Integer): Integer; begin Square := n * n; end;
  SemaModel.AddTypedHirNode('function-body-begin', 'Square', 0, 0,
    'Square' + #9 + 'i' + #9 + '1' + #9 + 'n');
  SemaModel.AddTypedHirNode('var-decl-runtime', 'n', 0, 0, 'n');
  SemaModel.AddTypedHirNode('ret-runtime', 'Result', 0, 0,
    'var n' + #10 + 'var n' + #10 + 'mul' + #10);
  SemaModel.AddTypedHirNode('function-body-end', 'Square', 0, 0, '');

  // begin Halt(Square(7)); end.
  SemaModel.AddTypedHirNode('halt-call-runtime', 'Halt(Square(7))', 0, 0,
    'int 7' + #10 + 'call Square 1' + #10);

  Builder := THIRBuilder.Create(SemaModel);
  Builder.Build;

  Emitter := THIRLlvmEmitter.Create(Builder.Module);
  Emitter.EmitModule;
  Emitter.SaveToFile('/tmp/hir_e2e_fn.ll');

  WriteLn('Generated LLVM IR:');
  WriteLn(Emitter.AsText);

  Emitter.Free;
  Builder.Free;
  SemaModel.Free;
end.
