program test_parser_dotted_uses_clause;

{$mode objfpc}{$H+}

uses
  np_ast_facade,
  np_diagnostics_sink,
  np_green_tree,
  np_lexer;

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
      'uses nextpas.core.time.base, nextpas.core.time.stopwatch;'#10 +
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
    if Ast.InterfaceUseCount <> 2 then
      Halt(4);
    if Ast.InterfaceUseAt(0) <> 'nextpas.core.time.base' then
      Halt(5);
    if Ast.InterfaceUseAt(1) <> 'nextpas.core.time.stopwatch' then
      Halt(6);
  finally
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end.
