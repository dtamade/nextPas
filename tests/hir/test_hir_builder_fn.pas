program test_hir_builder_fn;

{$mode objfpc}{$H+}

uses
  SysUtils, np_semantic_model, np_hir_types, np_hir_model,
  np_hir_builder, np_hir_printer, np_hir_verifier;

var
  SemaModel: TSemanticModel;
  Builder: THIRBuilder;
  Printer: THIRPrinter;
  Verifier: THIRVerifier;
  I: LongInt;
begin
  SemaModel := TSemanticModel.Create;

  SemaModel.AddTypedHirNode('function-body-begin', 'Square', 0, 0,
    'Square' + #9 + 'i' + #9 + '1' + #9 + 'n');
  SemaModel.AddTypedHirNode('var-decl-runtime', 'n', 0, 0, 'n');
  SemaModel.AddTypedHirNode('ret-runtime', 'Result', 0, 0,
    'var n' + #10 + 'var n' + #10 + 'mul' + #10);
  SemaModel.AddTypedHirNode('function-body-end', 'Square', 0, 0, '');

  SemaModel.AddTypedHirNode('var-decl-runtime', 'x', 0, 0, 'x');
  SemaModel.AddTypedHirNode('assign-runtime', 'x := 5', 0, 0,
    'x' + #9 + 'int 5' + #10);
  SemaModel.AddTypedHirNode('halt-call-runtime', 'Halt(Square(x))', 0, 0,
    'var x' + #10 + 'call Square 1' + #10);

  WriteLn('=== Building HIR with function ===');
  Builder := THIRBuilder.Create(SemaModel);
  Builder.Build;

  WriteLn('');
  WriteLn('=== HIR Output ===');
  Printer := THIRPrinter.Create(Builder.Module);
  Printer.Print;
  WriteLn(Printer.AsText);
  Printer.Free;

  WriteLn('=== Verification ===');
  Verifier := THIRVerifier.Create(Builder.Module);
  if Verifier.Verify then
    WriteLn('PASS: No verification errors')
  else
  begin
    WriteLn('FAIL: ', Verifier.ErrorCount, ' error(s)');
    for I := 0 to Verifier.ErrorCount - 1 do
      WriteLn('  [', Verifier.ErrorAt(I).FuncName, ' bb',
        Verifier.ErrorAt(I).BlockId, '] ',
        Verifier.ErrorAt(I).Message);
  end;
  Verifier.Free;

  Builder.Free;
  SemaModel.Free;
end.
