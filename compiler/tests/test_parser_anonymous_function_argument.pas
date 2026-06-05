program test_parser_anonymous_function_argument;

{$mode objfpc}{$H+}

uses
  np_diagnostics_sink,
  np_green_tree,
  np_lexer;

function CountNodesByKind(const ANode: TGreenNode;
  const AKind: TGreenNodeKind): LongInt;
var
  ChildIndex: LongInt;
begin
  Result := 0;
  if ANode = nil then
    Exit;
  if ANode.NodeKind = AKind then
    Inc(Result);
  for ChildIndex := 0 to ANode.ChildCount - 1 do
    Inc(Result, CountNodesByKind(ANode.ChildAt(ChildIndex), AKind));
end;

function FindDeclByKindAndName(const ANode: TGreenNode;
  const AKind: TGreenNodeKind;
  const AExpectedName: string): TGreenNode;
var
  ChildIndex: LongInt;
begin
  Result := nil;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = AKind) and (ANode.Text = AExpectedName) then
    Exit(ANode);
  for ChildIndex := 0 to ANode.ChildCount - 1 do
  begin
    Result := FindDeclByKindAndName(ANode.ChildAt(ChildIndex), AKind,
      AExpectedName);
    if Result <> nil then
      Exit;
  end;
end;

function FindUnnamedDeclByKind(const ANode: TGreenNode;
  const AKind: TGreenNodeKind): TGreenNode;
var
  ChildIndex: LongInt;
begin
  Result := nil;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = AKind) and (ANode.Text = '') then
    Exit(ANode);
  for ChildIndex := 0 to ANode.ChildCount - 1 do
  begin
    Result := FindUnnamedDeclByKind(ANode.ChildAt(ChildIndex), AKind);
    if Result <> nil then
      Exit;
  end;
end;

function HasChildOfKind(const ANode: TGreenNode;
  const AKind: TGreenNodeKind): Boolean;
var
  ChildIndex: LongInt;
begin
  Result := False;
  if ANode = nil then
    Exit;
  for ChildIndex := 0 to ANode.ChildCount - 1 do
    if ANode.ChildAt(ChildIndex).NodeKind = AKind then
      Exit(True);
end;

var
  AnonymousFunctionNode: TGreenNode;
  Diagnostics: TDiagnosticsSink;
  ProcedureNode: TGreenNode;
  Lexer: TLexerResult;
  Tree: TGreenTree;
begin
  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := nil;
  Tree := nil;
  try
    Lexer := TLexerResult.Create(
      'unit AnonymousFunctionArgUnit;'#10 +
      'interface'#10 +
      'type'#10 +
      '  TRandomGeneratorRefFunc = reference to function(aRange: Int64): Int64;'#10 +
      '  TDemo = class'#10 +
      '  public'#10 +
      '    procedure Shuffle(aRandomGenerator: TRandomGeneratorRefFunc);'#10 +
      '    procedure Shuffle;'#10 +
      '  end;'#10 +
      'implementation'#10 +
      'procedure TDemo.Shuffle;'#10 +
      'begin'#10 +
      '  Shuffle('#10 +
      '    function(aRange: Int64): Int64'#10 +
      '    begin'#10 +
      '      Result := Random(aRange);'#10 +
      '    end'#10 +
      '  );'#10 +
      'end;'#10 +
      'end.'#10,
      Diagnostics,
      1
    );
    Tree := ParseGreenTree(Lexer, Diagnostics, 1);

    if Tree = nil then
      Halt(1);
    if Diagnostics.HasErrors then
      Halt(2);
    if not Tree.IsValid then
      Halt(3);
    ProcedureNode := FindDeclByKindAndName(Tree.RootNode, gnkProcedureDecl,
      'TDemo.Shuffle');
    if ProcedureNode = nil then
      Halt(4);
    if not HasChildOfKind(ProcedureNode, gnkBeginBlock) then
      Halt(5);
    AnonymousFunctionNode := FindUnnamedDeclByKind(Tree.RootNode,
      gnkFunctionDecl);
    if AnonymousFunctionNode = nil then
      Halt(6);
    if not HasChildOfKind(AnonymousFunctionNode, gnkBeginBlock) then
      Halt(7);
  finally
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end.
