program test_parser_program_directive_uses_clause;

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
      'program DirectiveUsesProbe;'#10 +
      '{$mode objfpc}{$H+}'#10 +
      'uses SysUtils;'#10 +
      'begin'#10 +
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
    if Ast.RootKindName <> 'program' then
      Halt(4);
    if Ast.DeclaredName <> 'DirectiveUsesProbe' then
      Halt(5);
    if Ast.InterfaceUseCount <> 1 then
      Halt(6);
    if Ast.InterfaceUseAt(0) <> 'SysUtils' then
      Halt(7);
  finally
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end.
