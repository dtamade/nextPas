program test_parser_external_class_operator_impl;

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
      'unit OperatorImplUnit;'#10 +
      'interface'#10 +
      'type'#10 +
      '  TNumber = record'#10 +
      '    Value: Integer;'#10 +
      '    class operator +(const A, B: TNumber): TNumber;'#10 +
      '  end;'#10 +
      'implementation'#10 +
      'class operator TNumber.+(const A, B: TNumber): TNumber;'#10 +
      'begin'#10 +
      '  Result.Value := A.Value + B.Value;'#10 +
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
    if CountNodesByKind(Tree.RootNode, gnkFunctionDecl) <> 1 then
      Halt(4);

    FunctionNode := FindFunctionDeclByName(Tree.RootNode, 'TNumber.+');
    if FunctionNode = nil then
      Halt(5);
    if not HasChildOfKind(FunctionNode, gnkBeginBlock) then
      Halt(6);
  finally
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end.
