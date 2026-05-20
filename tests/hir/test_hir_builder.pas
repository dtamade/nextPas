program test_hir_builder;

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

  SemaModel.AddTypedHirNode('var-decl-runtime', 'x', 0, 0, 'x');
  SemaModel.AddTypedHirNode('var-decl-runtime', 'y', 0, 0, 'y');
  SemaModel.AddTypedHirNode('var-decl-runtime', 'result', 0, 0, 'result');

  SemaModel.AddTypedHirNode('assign-runtime', 'x := 10', 0, 0,
    'x' + #9 + 'int 10' + #10);
  SemaModel.AddTypedHirNode('assign-runtime', 'y := 3', 0, 0,
    'y' + #9 + 'int 3' + #10);
  SemaModel.AddTypedHirNode('assign-runtime', 'result := x + y * 2', 0, 0,
    'result' + #9 + 'var x' + #10 + 'var y' + #10 + 'int 2' + #10 + 'mul' + #10 + 'add' + #10);

  SemaModel.AddTypedHirNode('halt-call-runtime', 'Halt(result)', 0, 0,
    'var result' + #10);

  WriteLn('=== Building HIR from TypedHirNode sequence ===');
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
