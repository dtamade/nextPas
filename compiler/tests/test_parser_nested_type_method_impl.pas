program test_parser_nested_type_method_impl;

{$mode objfpc}{$H+}

uses
  np_diagnostics_sink,
  np_green_tree,
  np_lexer;

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
  Lexer: TLexerResult;
  MethodNode: TGreenNode;
  Tree: TGreenTree;
begin
  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := nil;
  Tree := nil;
  try
    Lexer := TLexerResult.Create(
      'unit NestedTypeMethodImplUnit;'#10 +
      'interface'#10 +
      'type'#10 +
      '  TOuter = class'#10 +
      '  public type'#10 +
      '    TNested = record'#10 +
      '      procedure Init;'#10 +
      '    end;'#10 +
      '  end;'#10 +
      'implementation'#10 +
      'procedure TOuter.TNested.Init;'#10 +
      'begin'#10 +
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

    MethodNode := FindDeclByKindAndName(Tree.RootNode, gnkProcedureDecl,
      'TOuter.TNested.Init');
    if MethodNode = nil then
      Halt(4);
    if not HasChildOfKind(MethodNode, gnkBeginBlock) then
      Halt(5);
  finally
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end.
