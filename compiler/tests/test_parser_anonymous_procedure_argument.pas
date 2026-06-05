program test_parser_anonymous_procedure_argument;

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

function FindFunctionDeclByName(const ANode: TGreenNode;
  const AExpectedName: string): TGreenNode;
var
  ChildIndex: LongInt;
begin
  Result := nil;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkFunctionDecl) and (ANode.Text = AExpectedName) then
    Exit(ANode);
  for ChildIndex := 0 to ANode.ChildCount - 1 do
  begin
    Result := FindFunctionDeclByName(ANode.ChildAt(ChildIndex), AExpectedName);
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
  AnonymousProcedureNode: TGreenNode;
  Diagnostics: TDiagnosticsSink;
  FunctionNode: TGreenNode;
  Lexer: TLexerResult;
  Tree: TGreenTree;
begin
  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := nil;
  Tree := nil;
  try
    Lexer := TLexerResult.Create(
      'unit AnonymousProcedureArgUnit;'#10 +
      'interface'#10 +
      'type'#10 +
      '  THandler = reference to procedure(const AValue: Int64);'#10 +
      '  TDemo = class'#10 +
      '  public'#10 +
      '    procedure Consume(AHandler: THandler);'#10 +
      '    function Wrap: Int64;'#10 +
      '  end;'#10 +
      'implementation'#10 +
      'function TDemo.Wrap: Int64;'#10 +
      'begin'#10 +
      '  Result := 0;'#10 +
      '  Consume('#10 +
      '    procedure(const AValue: Int64)'#10 +
      '    begin'#10 +
      '      Result := AValue;'#10 +
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
    FunctionNode := FindFunctionDeclByName(Tree.RootNode, 'TDemo.Wrap');
    if FunctionNode = nil then
      Halt(4);
    if not HasChildOfKind(FunctionNode, gnkBeginBlock) then
      Halt(5);
    AnonymousProcedureNode := FindUnnamedDeclByKind(Tree.RootNode,
      gnkProcedureDecl);
    if AnonymousProcedureNode = nil then
      Halt(6);
    if not HasChildOfKind(AnonymousProcedureNode, gnkBeginBlock) then
      Halt(7);
  finally
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end.
