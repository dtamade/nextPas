program test_parser_dotted_unit_root;

{$mode objfpc}{$H+}

uses
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.diagnostics.sink,
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.syntax.lexer;

var
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Tree: TGreenTree;
  Ast: TAstFacade;
begin
  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := nil;
  Tree := nil;
  Ast := nil;
  try
    Lexer := TLexerResult.Create(
      'unit nextpas.core.time;'#10 +
      'interface'#10 +
      'implementation'#10 +
      'end.'#10,
      Diagnostics,
      1
    );
    Tree := ParseGreenTree(Lexer, Diagnostics, 1);
    Ast := TAstFacade.Create(Tree);

    if Tree = nil then
      Halt(1);
    if Diagnostics.HasErrors then
      Halt(2);
    if not Ast.IsValid then
      Halt(3);
    if Ast.RootKindName <> 'unit' then
      Halt(4);
    if Ast.DeclaredName <> 'nextpas.core.time' then
      Halt(5);
  finally
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end.
