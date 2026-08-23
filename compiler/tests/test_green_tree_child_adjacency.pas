program test_green_tree_child_adjacency;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.compiler.diagnostics.sink,
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.syntax.lexer;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'green-tree-child-adjacency-failure=', AMessage);
  Halt(1);
end;

function FindTypeSection(const ANode: TGreenNode): TGreenNode;
var
  Child: TGreenNode;
  Index: LongInt;
begin
  if ANode = nil then
    Exit(nil);
  if ANode.NodeKind = gnkTypeSection then
    Exit(ANode);
  for Index := 0 to ANode.ChildCount - 1 do
  begin
    Child := FindTypeSection(ANode.ChildAt(Index));
    if Child <> nil then
      Exit(Child);
  end;
  Result := nil;
end;

procedure CheckTypeChild(const ASection: TGreenNode; const AIndex: LongInt;
  const AExpectedName: string);
var
  Child: TGreenNode;
begin
  Child := ASection.ChildAt(AIndex);
  if Child = nil then
    Fail('missing-type-child index=' + IntToStr(AIndex));
  if Child.NodeKind <> gnkTypeDecl then
    Fail('wrong-type-child-kind index=' + IntToStr(AIndex) +
      ' actual=' + Child.NodeKindName);
  if not SameText(Child.Text, AExpectedName) then
    Fail('wrong-type-child-name index=' + IntToStr(AIndex) +
      ' expected=' + AExpectedName + ' actual=' + Child.Text);
end;

var
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Tree: TGreenTree;
  TypeSection: TGreenNode;
begin
  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := TLexerResult.Create(
    'unit GreenTreeChildAdjacency;' + LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TFirst = Integer;' + LineEnding +
    '  TSecond = Integer;' + LineEnding +
    '  TThird = Integer;' + LineEnding +
    'implementation' + LineEnding +
    'end.' + LineEnding,
    Diagnostics,
    1
  );
  Tree := nil;
  try
    Tree := ParseGreenTree(Lexer, Diagnostics, 1);
    if Diagnostics.HasErrors then
      Fail('unexpected-syntax-diagnostic:' + Diagnostics.LastDiagnosticCode);
    TypeSection := FindTypeSection(Tree.RootNode);
    if TypeSection = nil then
      Fail('missing-type-section');
    if TypeSection.ChildCount <> 3 then
      Fail('wrong-type-child-count actual=' + IntToStr(TypeSection.ChildCount));
    CheckTypeChild(TypeSection, 0, 'TFirst');
    CheckTypeChild(TypeSection, 1, 'TSecond');
    CheckTypeChild(TypeSection, 2, 'TThird');
  finally
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;

  WriteLn('green-tree-child-adjacency=pass');
end.
