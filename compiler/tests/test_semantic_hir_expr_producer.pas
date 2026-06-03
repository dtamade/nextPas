program test_semantic_hir_expr_producer;

{$mode objfpc}{$H+}

uses
  SysUtils,
  np_ast_facade,
  np_diagnostics_sink,
  np_green_tree,
  np_hir_builder,
  np_hir_llvm_emitter,
  np_lexer,
  np_semantic_analyzer,
  np_semantic_model,
  np_unit_graph;

function BuildModel(const ASource: string): TSemanticModel;
var
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Tree: TGreenTree;
  Ast: TAstFacade;
  Graph: TUnitGraph;
  Analyzer: TSemanticAnalyzer;
begin
  Result := nil;
  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := nil;
  Tree := nil;
  Ast := nil;
  Graph := nil;
  Analyzer := nil;
  try
    Lexer := TLexerResult.Create(ASource, Diagnostics, 1);
    Tree := ParseGreenTree(Lexer, Diagnostics, 1);
    Ast := TAstFacade.Create(Tree);
    Graph := TUnitGraph.Create;
    Graph.SetRootName('test');
    Graph.MarkReady;
    Analyzer := TSemanticAnalyzer.Create(Ast, Graph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Result := Analyzer.DetachModel;
  finally
    Analyzer.Free;
    Graph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end;

function CountStaticArrayRangeNodes(const ANode: TGreenNode;
  const ALowText, AHighText, AElementText: string): LongInt;
var
  I: LongInt;
  RangeNode: TGreenNode;
begin
  Result := 0;
  if ANode = nil then
    Exit;

  if (ANode.NodeKind = gnkArrayType) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and SameText(ANode.ChildAt(0).Text, AElementText) then
  begin
    RangeNode := ANode.ChildAt(1);
    if (RangeNode <> nil) and (RangeNode.NodeKind = gnkRangeExpression) and
      (RangeNode.ChildCount >= 2) and (RangeNode.ChildAt(0) <> nil) and
      (RangeNode.ChildAt(1) <> nil) and
      (RangeNode.ChildAt(0).Text = ALowText) and
      (RangeNode.ChildAt(1).Text = AHighText) then
      Inc(Result);
  end;

  for I := 0 to ANode.ChildCount - 1 do
    Inc(Result, CountStaticArrayRangeNodes(ANode.ChildAt(I), ALowText,
      AHighText, AElementText));
end;

function FindFirstNodeByKind(const AModel: TSemanticModel;
  const AKind: string; out ANode: TTypedHirNode): Boolean;
var
  I: LongInt;
begin
  for I := 0 to AModel.TypedHirNodeCount - 1 do
  begin
    ANode := AModel.TypedHirNodeAt(I);
    if ANode.Kind = AKind then
      Exit(True);
  end;
  Result := False;
end;

function FindFirstNodeByKindAndOperandText(const AModel: TSemanticModel;
  const AKind, AText: string; out ANode: TTypedHirNode): Boolean;
var
  I: LongInt;
begin
  for I := 0 to AModel.TypedHirNodeCount - 1 do
  begin
    ANode := AModel.TypedHirNodeAt(I);
    if (ANode.Kind = AKind) and (Pos(AText, ANode.Operand) > 0) then
      Exit(True);
  end;
  Result := False;
end;

function CountSubstring(const AText, ASubstring: string): LongInt;
var
  SearchFrom: LongInt;
  FoundAt: LongInt;
begin
  Result := 0;
  if ASubstring = '' then
    Exit;

  SearchFrom := 1;
  while SearchFrom <= Length(AText) do
  begin
    FoundAt := Pos(ASubstring,
      Copy(AText, SearchFrom, Length(AText) - SearchFrom + 1));
    if FoundAt = 0 then
      Exit;
    Inc(Result);
    Inc(SearchFrom, FoundAt + Length(ASubstring) - 1);
  end;
end;

procedure AssertStaticArrayDeclMetadata(const AModel: TSemanticModel;
  const AName: string; const ALow, AHigh, ALen: Int64;
  const ABaseExitCode: LongInt);
var
  Node: TTypedHirNode;
  Value: Int64;
  ElementType: string;
begin
  if not FindFirstNodeByKindAndOperandText(AModel, 'var-decl-arr-runtime',
    AName, Node) then
    Halt(ABaseExitCode);
  if Pos(#9'static'#9 + IntToStr(ALow) + #9 + IntToStr(AHigh) + #9 +
    IntToStr(ALen), Node.Operand) = 0 then
    Halt(ABaseExitCode + 1);
  if (not AModel.LookupConstValue(AName + '$arr_static', Value)) or
    (Value <> 1) then
    Halt(ABaseExitCode + 2);
  if (not AModel.LookupConstValue(AName + '$arr_low', Value)) or
    (Value <> ALow) then
    Halt(ABaseExitCode + 3);
  if (not AModel.LookupConstValue(AName + '$arr_high', Value)) or
    (Value <> AHigh) then
    Halt(ABaseExitCode + 4);
  if (not AModel.LookupConstValue(AName + '$arr_len', Value)) or
    (Value <> ALen) then
    Halt(ABaseExitCode + 5);
  if (not AModel.LookupStringConstValue(AName + '$arr_elem_type',
    ElementType)) or (not SameText(ElementType, 'Integer')) then
    Halt(ABaseExitCode + 6);
end;

function FindAssignRuntimeNodeForDestAndOperandText(const AModel: TSemanticModel;
  const ADest, AText: string; out ANode: TTypedHirNode): Boolean;
var
  I: LongInt;
begin
  for I := 0 to AModel.TypedHirNodeCount - 1 do
  begin
    ANode := AModel.TypedHirNodeAt(I);
    if (ANode.Kind = 'assign-runtime') and (ANode.DisplayName = ADest) and
      (Pos(AText, ANode.Operand) > 0) then
      Exit(True);
  end;
  Result := False;
end;

procedure AssertRuntimeBinaryExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedOp: string;
  const ABaseExitCode: LongInt);
var
  Expr: TSemanticHirExpr;
begin
  if ANode.ExprId = 0 then
    Halt(ABaseExitCode);
  if ANode.Operand = '' then
    Halt(ABaseExitCode + 1);
  Expr := AModel.HirExprAt(ANode.ExprId - 1);
  if Expr.Kind <> shekBinaryOp then
    Halt(ABaseExitCode + 2);
  if Expr.Op <> AExpectedOp then
    Halt(ABaseExitCode + 3);
end;

procedure AssertRuntimeCompareExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedOp: string;
  const ABaseExitCode: LongInt);
var
  Expr: TSemanticHirExpr;
begin
  if ANode.ExprId = 0 then
    Halt(ABaseExitCode);
  if ANode.Operand = '' then
    Halt(ABaseExitCode + 1);
  Expr := AModel.HirExprAt(ANode.ExprId - 1);
  if Expr.Kind <> shekCompareOp then
    Halt(ABaseExitCode + 2);
  if Expr.Op <> AExpectedOp then
    Halt(ABaseExitCode + 3);
end;

function TypeNameOf(const AModel: TSemanticModel;
  const ATypeId: LongInt): string;
begin
  if (ATypeId <= 0) or (ATypeId > AModel.TypeCount) then
    Exit('');
  Result := AModel.TypeAt(ATypeId - 1).Name;
end;

procedure AssertExprTypeName(const AModel: TSemanticModel;
  const AExpr: TSemanticHirExpr; const AExpectedTypeName: string;
  const AExitCode: LongInt);
begin
  if not SameText(TypeNameOf(AModel, AExpr.TypeId), AExpectedTypeName) then
    Halt(AExitCode);
end;

procedure AssertClassReceiverAddressExpr(const AModel: TSemanticModel;
  const AExpr: TSemanticHirExpr; const ASymbolName: string;
  const ABaseExitCode: LongInt);
var
  BaseExpr: TSemanticHirExpr;
begin
  if AExpr.Kind <> shekDeref then
    Halt(ABaseExitCode);
  if AExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 1);
  if Length(AExpr.Children) <> 1 then
    Halt(ABaseExitCode + 2);
  BaseExpr := AModel.HirExprAt(AExpr.Children[0] - 1);
  if BaseExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 3);
  if AModel.SymbolAt(BaseExpr.SymbolId - 1).Name <> ASymbolName then
    Halt(ABaseExitCode + 4);
  AssertExprTypeName(AModel, BaseExpr, 'Pointer', ABaseExitCode + 5);
end;

procedure AssertCastChildType(const AModel: TSemanticModel;
  const AExprId: LongInt; const AExpectedTargetTypeName,
  AExpectedChildTypeName: string; const ABaseExitCode: LongInt);
var
  Expr, Child: TSemanticHirExpr;
begin
  if AExprId <= 0 then
    Halt(ABaseExitCode);
  Expr := AModel.HirExprAt(AExprId - 1);
  if Expr.Kind <> shekCast then
    Halt(ABaseExitCode + 1);
  AssertExprTypeName(AModel, Expr, AExpectedTargetTypeName, ABaseExitCode + 2);
  if Length(Expr.Children) < 1 then
    Halt(ABaseExitCode + 3);
  Child := AModel.HirExprAt(Expr.Children[0] - 1);
  AssertExprTypeName(AModel, Child, AExpectedChildTypeName, ABaseExitCode + 4);
end;

function FindCompareExprWithFirstCastChild(const AModel: TSemanticModel;
  const AChildTypeName: string; out AExpr: TSemanticHirExpr): Boolean;
var
  I: LongInt;
  Node: TTypedHirNode;
  FirstChild, CastChild: TSemanticHirExpr;
begin
  for I := 0 to AModel.TypedHirNodeCount - 1 do
  begin
    Node := AModel.TypedHirNodeAt(I);
    if Node.ExprId <= 0 then
      Continue;
    AExpr := AModel.HirExprAt(Node.ExprId - 1);
    if (AExpr.Kind <> shekCompareOp) or (Length(AExpr.Children) < 1) then
      Continue;
    FirstChild := AModel.HirExprAt(AExpr.Children[0] - 1);
    if (FirstChild.Kind <> shekCast) or (Length(FirstChild.Children) < 1) then
      Continue;
    CastChild := AModel.HirExprAt(FirstChild.Children[0] - 1);
    if SameText(TypeNameOf(AModel, CastChild.TypeId), AChildTypeName) then
      Exit(True);
  end;
  Result := False;
end;

procedure AssertRuntimeSymbolExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedName: string;
  const ABaseExitCode: LongInt);
var
  Expr: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.ExprId = 0 then
    Halt(ABaseExitCode);
  if ANode.Operand = '' then
    Halt(ABaseExitCode + 1);
  Expr := AModel.HirExprAt(ANode.ExprId - 1);
  if Expr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 2);
  if Expr.SymbolId = 0 then
    Halt(ABaseExitCode + 3);
  Symbol := AModel.SymbolAt(Expr.SymbolId - 1);
  if Symbol.Name <> AExpectedName then
    Halt(ABaseExitCode + 4);
end;

procedure AssertAddressOfRuntimeExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedSymbolName: string;
  const ABaseExitCode: LongInt);
var
  Expr, Child: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.ExprId = 0 then
    Halt(ABaseExitCode);
  if ANode.Operand = '' then
    Halt(ABaseExitCode + 1);
  Expr := AModel.HirExprAt(ANode.ExprId - 1);
  if Expr.Kind <> shekAddressOf then
    Halt(ABaseExitCode + 2);
  if Expr.ValueClass <> shvcScalar then
    Halt(ABaseExitCode + 3);
  AssertExprTypeName(AModel, Expr, 'Pointer', ABaseExitCode + 4);
  if Length(Expr.Children) < 1 then
    Halt(ABaseExitCode + 5);
  Child := AModel.HirExprAt(Expr.Children[0] - 1);
  if Child.Kind <> shekSymbolAddress then
    Halt(ABaseExitCode + 6);
  if Child.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 7);
  AssertExprTypeName(AModel, Child, 'Integer', ABaseExitCode + 8);
  if Child.SymbolId <= 0 then
    Halt(ABaseExitCode + 9);
  Symbol := AModel.SymbolAt(Child.SymbolId - 1);
  if Symbol.Name <> AExpectedSymbolName then
    Halt(ABaseExitCode + 10);
end;

procedure AssertDerefRuntimeExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedPointerName: string;
  const ABaseExitCode: LongInt);
var
  Expr, Child: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.ExprId = 0 then
    Halt(ABaseExitCode);
  if ANode.Operand = '' then
    Halt(ABaseExitCode + 1);
  Expr := AModel.HirExprAt(ANode.ExprId - 1);
  if Expr.Kind <> shekDeref then
    Halt(ABaseExitCode + 2);
  if Expr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 3);
  AssertExprTypeName(AModel, Expr, 'Integer', ABaseExitCode + 4);
  if Length(Expr.Children) < 1 then
    Halt(ABaseExitCode + 5);
  Child := AModel.HirExprAt(Expr.Children[0] - 1);
  if Child.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 6);
  if Child.ValueClass <> shvcScalar then
    Halt(ABaseExitCode + 7);
  AssertExprTypeName(AModel, Child, 'Pointer', ABaseExitCode + 8);
  if Child.SymbolId <= 0 then
    Halt(ABaseExitCode + 9);
  Symbol := AModel.SymbolAt(Child.SymbolId - 1);
  if Symbol.Name <> AExpectedPointerName then
    Halt(ABaseExitCode + 10);
end;

procedure AssertArrayElementAddressOfRuntimeExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedArrayName,
  AExpectedIndexName: string; const ABaseExitCode: LongInt);
var
  Expr, Child, IndexExpr: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.ExprId = 0 then
    Halt(ABaseExitCode);
  if ANode.Operand = '' then
    Halt(ABaseExitCode + 1);
  Expr := AModel.HirExprAt(ANode.ExprId - 1);
  if Expr.Kind <> shekAddressOf then
    Halt(ABaseExitCode + 2);
  if Expr.ValueClass <> shvcScalar then
    Halt(ABaseExitCode + 3);
  AssertExprTypeName(AModel, Expr, 'Pointer', ABaseExitCode + 4);
  if Length(Expr.Children) < 1 then
    Halt(ABaseExitCode + 5);

  Child := AModel.HirExprAt(Expr.Children[0] - 1);
  if Child.Kind <> shekArrayElem then
    Halt(ABaseExitCode + 6);
  if Child.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 7);
  AssertExprTypeName(AModel, Child, 'Integer', ABaseExitCode + 8);
  if Child.SymbolId <= 0 then
    Halt(ABaseExitCode + 9);
  Symbol := AModel.SymbolAt(Child.SymbolId - 1);
  if Symbol.Name <> AExpectedArrayName then
    Halt(ABaseExitCode + 10);
  if Length(Child.Children) < 1 then
    Halt(ABaseExitCode + 11);

  IndexExpr := AModel.HirExprAt(Child.Children[0] - 1);
  if IndexExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 12);
  AssertExprTypeName(AModel, IndexExpr, 'Integer', ABaseExitCode + 13);
  if IndexExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 14);
  Symbol := AModel.SymbolAt(IndexExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedIndexName then
    Halt(ABaseExitCode + 15);
end;

procedure AssertArrayElementStoreTargetExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedArrayName,
  AExpectedIndexName: string; const ABaseExitCode: LongInt);
var
  Expr, IndexExpr: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.TargetExprId = 0 then
    Halt(ABaseExitCode);

  Expr := AModel.HirExprAt(ANode.TargetExprId - 1);
  if Expr.Kind <> shekArrayElem then
    Halt(ABaseExitCode + 1);
  if Expr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 2);
  AssertExprTypeName(AModel, Expr, 'Integer', ABaseExitCode + 3);
  if Expr.SymbolId <= 0 then
    Halt(ABaseExitCode + 4);
  Symbol := AModel.SymbolAt(Expr.SymbolId - 1);
  if Symbol.Name <> AExpectedArrayName then
    Halt(ABaseExitCode + 5);
  if Length(Expr.Children) < 1 then
    Halt(ABaseExitCode + 6);

  IndexExpr := AModel.HirExprAt(Expr.Children[0] - 1);
  if IndexExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 7);
  AssertExprTypeName(AModel, IndexExpr, 'Integer', ABaseExitCode + 8);
  if IndexExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 9);
  Symbol := AModel.SymbolAt(IndexExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedIndexName then
    Halt(ABaseExitCode + 10);
end;

procedure AssertArrayElementValueExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedArrayName,
  AExpectedIndexName, AExpectedElementTypeName: string;
  const ABaseExitCode: LongInt);
var
  Expr, IndexExpr: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.ExprId = 0 then
    Halt(ABaseExitCode);

  Expr := AModel.HirExprAt(ANode.ExprId - 1);
  if Expr.Kind <> shekArrayElem then
    Halt(ABaseExitCode + 1);
  if Expr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 2);
  AssertExprTypeName(AModel, Expr, AExpectedElementTypeName,
    ABaseExitCode + 3);
  if Expr.SymbolId <= 0 then
    Halt(ABaseExitCode + 4);
  Symbol := AModel.SymbolAt(Expr.SymbolId - 1);
  if Symbol.Name <> AExpectedArrayName then
    Halt(ABaseExitCode + 5);
  if Length(Expr.Children) < 1 then
    Halt(ABaseExitCode + 6);

  IndexExpr := AModel.HirExprAt(Expr.Children[0] - 1);
  if IndexExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 7);
  AssertExprTypeName(AModel, IndexExpr, 'Integer', ABaseExitCode + 8);
  if IndexExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 9);
  Symbol := AModel.SymbolAt(IndexExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedIndexName then
    Halt(ABaseExitCode + 10);
end;

procedure AssertArrayRecordFieldStoreTargetExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedArrayName,
  AExpectedIndexName, AExpectedElementTypeName, AExpectedFieldTypeName,
  AExpectedFieldName: string; const AExpectedFieldIndex: Int64;
  const ABaseExitCode: LongInt);
var
  FieldExpr, ArrayExpr, IndexExpr: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.TargetExprId = 0 then
    Halt(ABaseExitCode);

  FieldExpr := AModel.HirExprAt(ANode.TargetExprId - 1);
  if FieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 1);
  if FieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 2);
  AssertExprTypeName(AModel, FieldExpr, AExpectedFieldTypeName,
    ABaseExitCode + 3);
  if FieldExpr.LiteralInt <> AExpectedFieldIndex then
    Halt(ABaseExitCode + 4);
  if FieldExpr.LiteralStr <> AExpectedFieldName then
    Halt(ABaseExitCode + 5);
  if Length(FieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 6);

  ArrayExpr := AModel.HirExprAt(FieldExpr.Children[0] - 1);
  if ArrayExpr.Kind <> shekArrayElem then
    Halt(ABaseExitCode + 7);
  if ArrayExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 8);
  AssertExprTypeName(AModel, ArrayExpr, AExpectedElementTypeName,
    ABaseExitCode + 9);
  if ArrayExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 10);
  Symbol := AModel.SymbolAt(ArrayExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedArrayName then
    Halt(ABaseExitCode + 11);
  if Length(ArrayExpr.Children) < 1 then
    Halt(ABaseExitCode + 12);

  IndexExpr := AModel.HirExprAt(ArrayExpr.Children[0] - 1);
  if IndexExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 13);
  AssertExprTypeName(AModel, IndexExpr, 'Integer', ABaseExitCode + 14);
  if IndexExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 15);
  Symbol := AModel.SymbolAt(IndexExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedIndexName then
    Halt(ABaseExitCode + 16);
end;

procedure AssertNestedArrayRecordFieldValueExpr(
  const AModel: TSemanticModel; const ANode: TTypedHirNode;
  const AExpectedArrayName, AExpectedIndexName, AExpectedElementTypeName,
  AExpectedOuterFieldTypeName, AExpectedLeafFieldTypeName,
  AExpectedOuterFieldName, AExpectedLeafFieldName: string;
  const AExpectedOuterFieldIndex, AExpectedLeafFieldIndex: Int64;
  const ABaseExitCode: LongInt);
var
  LeafFieldExpr, OuterFieldExpr, ArrayExpr, IndexExpr: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.ExprId = 0 then
    Halt(ABaseExitCode);

  LeafFieldExpr := AModel.HirExprAt(ANode.ExprId - 1);
  if LeafFieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 1);
  if LeafFieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 2);
  AssertExprTypeName(AModel, LeafFieldExpr, AExpectedLeafFieldTypeName,
    ABaseExitCode + 3);
  if LeafFieldExpr.LiteralInt <> AExpectedLeafFieldIndex then
    Halt(ABaseExitCode + 4);
  if LeafFieldExpr.LiteralStr <> AExpectedLeafFieldName then
    Halt(ABaseExitCode + 5);
  if Length(LeafFieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 6);

  OuterFieldExpr := AModel.HirExprAt(LeafFieldExpr.Children[0] - 1);
  if OuterFieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 7);
  if OuterFieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 8);
  AssertExprTypeName(AModel, OuterFieldExpr, AExpectedOuterFieldTypeName,
    ABaseExitCode + 9);
  if OuterFieldExpr.LiteralInt <> AExpectedOuterFieldIndex then
    Halt(ABaseExitCode + 10);
  if OuterFieldExpr.LiteralStr <> AExpectedOuterFieldName then
    Halt(ABaseExitCode + 11);
  if Length(OuterFieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 12);

  ArrayExpr := AModel.HirExprAt(OuterFieldExpr.Children[0] - 1);
  if ArrayExpr.Kind <> shekArrayElem then
    Halt(ABaseExitCode + 13);
  if ArrayExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 14);
  AssertExprTypeName(AModel, ArrayExpr, AExpectedElementTypeName,
    ABaseExitCode + 15);
  if ArrayExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 16);
  Symbol := AModel.SymbolAt(ArrayExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedArrayName then
    Halt(ABaseExitCode + 17);
  if Length(ArrayExpr.Children) < 1 then
    Halt(ABaseExitCode + 18);

  IndexExpr := AModel.HirExprAt(ArrayExpr.Children[0] - 1);
  if IndexExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 19);
  AssertExprTypeName(AModel, IndexExpr, 'Integer', ABaseExitCode + 20);
  if IndexExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 21);
  Symbol := AModel.SymbolAt(IndexExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedIndexName then
    Halt(ABaseExitCode + 22);
end;

procedure AssertNestedArrayRecordFieldStoreTargetExpr(
  const AModel: TSemanticModel; const ANode: TTypedHirNode;
  const AExpectedArrayName, AExpectedIndexName, AExpectedElementTypeName,
  AExpectedOuterFieldTypeName, AExpectedLeafFieldTypeName,
  AExpectedOuterFieldName, AExpectedLeafFieldName: string;
  const AExpectedOuterFieldIndex, AExpectedLeafFieldIndex: Int64;
  const ABaseExitCode: LongInt);
var
  LeafFieldExpr, OuterFieldExpr, ArrayExpr, IndexExpr: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.TargetExprId = 0 then
    Halt(ABaseExitCode);

  LeafFieldExpr := AModel.HirExprAt(ANode.TargetExprId - 1);
  if LeafFieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 1);
  if LeafFieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 2);
  AssertExprTypeName(AModel, LeafFieldExpr, AExpectedLeafFieldTypeName,
    ABaseExitCode + 3);
  if LeafFieldExpr.LiteralInt <> AExpectedLeafFieldIndex then
    Halt(ABaseExitCode + 4);
  if LeafFieldExpr.LiteralStr <> AExpectedLeafFieldName then
    Halt(ABaseExitCode + 5);
  if Length(LeafFieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 6);

  OuterFieldExpr := AModel.HirExprAt(LeafFieldExpr.Children[0] - 1);
  if OuterFieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 7);
  if OuterFieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 8);
  AssertExprTypeName(AModel, OuterFieldExpr, AExpectedOuterFieldTypeName,
    ABaseExitCode + 9);
  if OuterFieldExpr.LiteralInt <> AExpectedOuterFieldIndex then
    Halt(ABaseExitCode + 10);
  if OuterFieldExpr.LiteralStr <> AExpectedOuterFieldName then
    Halt(ABaseExitCode + 11);
  if Length(OuterFieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 12);

  ArrayExpr := AModel.HirExprAt(OuterFieldExpr.Children[0] - 1);
  if ArrayExpr.Kind <> shekArrayElem then
    Halt(ABaseExitCode + 13);
  if ArrayExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 14);
  AssertExprTypeName(AModel, ArrayExpr, AExpectedElementTypeName,
    ABaseExitCode + 15);
  if ArrayExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 16);
  Symbol := AModel.SymbolAt(ArrayExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedArrayName then
    Halt(ABaseExitCode + 17);
  if Length(ArrayExpr.Children) < 1 then
    Halt(ABaseExitCode + 18);

  IndexExpr := AModel.HirExprAt(ArrayExpr.Children[0] - 1);
  if IndexExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 19);
  AssertExprTypeName(AModel, IndexExpr, 'Integer', ABaseExitCode + 20);
  if IndexExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 21);
  Symbol := AModel.SymbolAt(IndexExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedIndexName then
    Halt(ABaseExitCode + 22);
end;

procedure AssertFieldArrayElementStoreTargetExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedFieldName,
  AExpectedIndexName, AExpectedElementTypeName: string;
  const AExpectedFieldIndex: Int64; const ABaseExitCode: LongInt);
var
  ArrayExpr, FieldExpr, DerefExpr, PointerExpr, IndexExpr: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.TargetExprId = 0 then
    Halt(ABaseExitCode);

  ArrayExpr := AModel.HirExprAt(ANode.TargetExprId - 1);
  if ArrayExpr.Kind <> shekArrayElem then
    Halt(ABaseExitCode + 1);
  if ArrayExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 2);
  AssertExprTypeName(AModel, ArrayExpr, AExpectedElementTypeName,
    ABaseExitCode + 3);
  if ArrayExpr.SymbolId <> 0 then
    Halt(ABaseExitCode + 4);
  if Length(ArrayExpr.Children) < 2 then
    Halt(ABaseExitCode + 5);

  FieldExpr := AModel.HirExprAt(ArrayExpr.Children[0] - 1);
  if FieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 6);
  if FieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 7);
  AssertExprTypeName(AModel, FieldExpr, 'Pointer', ABaseExitCode + 8);
  if FieldExpr.LiteralInt <> AExpectedFieldIndex then
    Halt(ABaseExitCode + 9);
  if FieldExpr.LiteralStr <> AExpectedFieldName then
    Halt(ABaseExitCode + 10);
  if Length(FieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 11);

  DerefExpr := AModel.HirExprAt(FieldExpr.Children[0] - 1);
  if DerefExpr.Kind <> shekDeref then
    Halt(ABaseExitCode + 12);
  if DerefExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 13);
  if Length(DerefExpr.Children) < 1 then
    Halt(ABaseExitCode + 14);

  PointerExpr := AModel.HirExprAt(DerefExpr.Children[0] - 1);
  if PointerExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 15);
  if PointerExpr.ValueClass <> shvcScalar then
    Halt(ABaseExitCode + 16);
  AssertExprTypeName(AModel, PointerExpr, 'Pointer', ABaseExitCode + 17);
  if PointerExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 18);
  Symbol := AModel.SymbolAt(PointerExpr.SymbolId - 1);
  if Symbol.Name <> 'self' then
    Halt(ABaseExitCode + 19);

  IndexExpr := AModel.HirExprAt(ArrayExpr.Children[1] - 1);
  if IndexExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 20);
  AssertExprTypeName(AModel, IndexExpr, 'Integer', ABaseExitCode + 21);
  if IndexExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 22);
  Symbol := AModel.SymbolAt(IndexExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedIndexName then
    Halt(ABaseExitCode + 23);
end;

procedure AssertFieldArrayElementValueExprWithBase(
  const AModel: TSemanticModel; const ANode: TTypedHirNode;
  const AExpectedBaseName, AExpectedFieldName, AExpectedIndexName,
  AExpectedElementTypeName: string; const AExpectedFieldIndex: Int64;
  const ABaseExitCode: LongInt);
var
  ArrayExpr, FieldExpr, DerefExpr, PointerExpr, IndexExpr: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.ExprId = 0 then
    Halt(ABaseExitCode);

  ArrayExpr := AModel.HirExprAt(ANode.ExprId - 1);
  if ArrayExpr.Kind <> shekArrayElem then
    Halt(ABaseExitCode + 1);
  if ArrayExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 2);
  AssertExprTypeName(AModel, ArrayExpr, AExpectedElementTypeName,
    ABaseExitCode + 3);
  if ArrayExpr.SymbolId <> 0 then
    Halt(ABaseExitCode + 4);
  if Length(ArrayExpr.Children) < 2 then
    Halt(ABaseExitCode + 5);

  FieldExpr := AModel.HirExprAt(ArrayExpr.Children[0] - 1);
  if FieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 6);
  if FieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 7);
  AssertExprTypeName(AModel, FieldExpr, 'Pointer', ABaseExitCode + 8);
  if FieldExpr.LiteralInt <> AExpectedFieldIndex then
    Halt(ABaseExitCode + 9);
  if FieldExpr.LiteralStr <> AExpectedFieldName then
    Halt(ABaseExitCode + 10);
  if Length(FieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 11);

  DerefExpr := AModel.HirExprAt(FieldExpr.Children[0] - 1);
  if DerefExpr.Kind <> shekDeref then
    Halt(ABaseExitCode + 12);
  if DerefExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 13);
  if Length(DerefExpr.Children) < 1 then
    Halt(ABaseExitCode + 14);

  PointerExpr := AModel.HirExprAt(DerefExpr.Children[0] - 1);
  if PointerExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 15);
  if PointerExpr.ValueClass <> shvcScalar then
    Halt(ABaseExitCode + 16);
  AssertExprTypeName(AModel, PointerExpr, 'Pointer', ABaseExitCode + 17);
  if PointerExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 18);
  Symbol := AModel.SymbolAt(PointerExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedBaseName then
    Halt(ABaseExitCode + 19);

  IndexExpr := AModel.HirExprAt(ArrayExpr.Children[1] - 1);
  if IndexExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 20);
  AssertExprTypeName(AModel, IndexExpr, 'Integer', ABaseExitCode + 21);
  if IndexExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 22);
  Symbol := AModel.SymbolAt(IndexExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedIndexName then
    Halt(ABaseExitCode + 23);
end;

procedure AssertFieldArrayElementValueExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedFieldName,
  AExpectedIndexName, AExpectedElementTypeName: string;
  const AExpectedFieldIndex: Int64; const ABaseExitCode: LongInt);
begin
  AssertFieldArrayElementValueExprWithBase(AModel, ANode, 'self',
    AExpectedFieldName, AExpectedIndexName, AExpectedElementTypeName,
    AExpectedFieldIndex, ABaseExitCode);
end;

procedure AssertObjectFieldArrayElementValueExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedBaseName, AExpectedFieldName,
  AExpectedIndexName, AExpectedElementTypeName: string;
  const AExpectedFieldIndex: Int64; const ABaseExitCode: LongInt);
begin
  AssertFieldArrayElementValueExprWithBase(AModel, ANode, AExpectedBaseName,
    AExpectedFieldName, AExpectedIndexName, AExpectedElementTypeName,
    AExpectedFieldIndex, ABaseExitCode);
end;

procedure AssertNestedFieldArrayStoreTargetExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedFieldName,
  AExpectedIndexName, AExpectedElementTypeName, AExpectedOuterFieldTypeName,
  AExpectedLeafFieldTypeName, AExpectedOuterFieldName,
  AExpectedLeafFieldName: string; const AExpectedArrayFieldIndex,
  AExpectedOuterFieldIndex, AExpectedLeafFieldIndex: Int64;
  const ABaseExitCode: LongInt);
var
  LeafFieldExpr, OuterFieldExpr, ArrayExpr, FieldExpr, DerefExpr,
    PointerExpr, IndexExpr: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.TargetExprId = 0 then
    Halt(ABaseExitCode);

  LeafFieldExpr := AModel.HirExprAt(ANode.TargetExprId - 1);
  if LeafFieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 1);
  if LeafFieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 2);
  AssertExprTypeName(AModel, LeafFieldExpr, AExpectedLeafFieldTypeName,
    ABaseExitCode + 3);
  if LeafFieldExpr.LiteralInt <> AExpectedLeafFieldIndex then
    Halt(ABaseExitCode + 4);
  if LeafFieldExpr.LiteralStr <> AExpectedLeafFieldName then
    Halt(ABaseExitCode + 5);
  if Length(LeafFieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 6);

  OuterFieldExpr := AModel.HirExprAt(LeafFieldExpr.Children[0] - 1);
  if OuterFieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 7);
  if OuterFieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 8);
  AssertExprTypeName(AModel, OuterFieldExpr, AExpectedOuterFieldTypeName,
    ABaseExitCode + 9);
  if OuterFieldExpr.LiteralInt <> AExpectedOuterFieldIndex then
    Halt(ABaseExitCode + 10);
  if OuterFieldExpr.LiteralStr <> AExpectedOuterFieldName then
    Halt(ABaseExitCode + 11);
  if Length(OuterFieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 12);

  ArrayExpr := AModel.HirExprAt(OuterFieldExpr.Children[0] - 1);
  if ArrayExpr.Kind <> shekArrayElem then
    Halt(ABaseExitCode + 13);
  if ArrayExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 14);
  AssertExprTypeName(AModel, ArrayExpr, AExpectedElementTypeName,
    ABaseExitCode + 15);
  if ArrayExpr.SymbolId <> 0 then
    Halt(ABaseExitCode + 16);
  if Length(ArrayExpr.Children) < 2 then
    Halt(ABaseExitCode + 17);

  FieldExpr := AModel.HirExprAt(ArrayExpr.Children[0] - 1);
  if FieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 18);
  if FieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 19);
  AssertExprTypeName(AModel, FieldExpr, 'Pointer', ABaseExitCode + 20);
  if FieldExpr.LiteralInt <> AExpectedArrayFieldIndex then
    Halt(ABaseExitCode + 21);
  if FieldExpr.LiteralStr <> AExpectedFieldName then
    Halt(ABaseExitCode + 22);
  if Length(FieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 23);

  DerefExpr := AModel.HirExprAt(FieldExpr.Children[0] - 1);
  if DerefExpr.Kind <> shekDeref then
    Halt(ABaseExitCode + 24);
  if DerefExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 25);
  if Length(DerefExpr.Children) < 1 then
    Halt(ABaseExitCode + 26);

  PointerExpr := AModel.HirExprAt(DerefExpr.Children[0] - 1);
  if PointerExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 27);
  if PointerExpr.ValueClass <> shvcScalar then
    Halt(ABaseExitCode + 28);
  AssertExprTypeName(AModel, PointerExpr, 'Pointer', ABaseExitCode + 29);
  if PointerExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 30);
  Symbol := AModel.SymbolAt(PointerExpr.SymbolId - 1);
  if Symbol.Name <> 'self' then
    Halt(ABaseExitCode + 31);

  IndexExpr := AModel.HirExprAt(ArrayExpr.Children[1] - 1);
  if IndexExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 32);
  AssertExprTypeName(AModel, IndexExpr, 'Integer', ABaseExitCode + 33);
  if IndexExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 34);
  Symbol := AModel.SymbolAt(IndexExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedIndexName then
    Halt(ABaseExitCode + 35);
end;

procedure AssertNestedFieldArrayValueExprWithBase(
  const AModel: TSemanticModel; const ANode: TTypedHirNode;
  const AExpectedBaseName, AExpectedFieldName, AExpectedIndexName,
  AExpectedElementTypeName, AExpectedOuterFieldTypeName,
  AExpectedLeafFieldTypeName, AExpectedOuterFieldName,
  AExpectedLeafFieldName: string; const AExpectedArrayFieldIndex,
  AExpectedOuterFieldIndex, AExpectedLeafFieldIndex: Int64;
  const ABaseExitCode: LongInt);
var
  LeafFieldExpr, OuterFieldExpr, ArrayExpr, FieldExpr, DerefExpr,
    PointerExpr, IndexExpr: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.ExprId = 0 then
    Halt(ABaseExitCode);

  LeafFieldExpr := AModel.HirExprAt(ANode.ExprId - 1);
  if LeafFieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 1);
  if LeafFieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 2);
  AssertExprTypeName(AModel, LeafFieldExpr, AExpectedLeafFieldTypeName,
    ABaseExitCode + 3);
  if LeafFieldExpr.LiteralInt <> AExpectedLeafFieldIndex then
    Halt(ABaseExitCode + 4);
  if LeafFieldExpr.LiteralStr <> AExpectedLeafFieldName then
    Halt(ABaseExitCode + 5);
  if Length(LeafFieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 6);

  OuterFieldExpr := AModel.HirExprAt(LeafFieldExpr.Children[0] - 1);
  if OuterFieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 7);
  if OuterFieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 8);
  AssertExprTypeName(AModel, OuterFieldExpr, AExpectedOuterFieldTypeName,
    ABaseExitCode + 9);
  if OuterFieldExpr.LiteralInt <> AExpectedOuterFieldIndex then
    Halt(ABaseExitCode + 10);
  if OuterFieldExpr.LiteralStr <> AExpectedOuterFieldName then
    Halt(ABaseExitCode + 11);
  if Length(OuterFieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 12);

  ArrayExpr := AModel.HirExprAt(OuterFieldExpr.Children[0] - 1);
  if ArrayExpr.Kind <> shekArrayElem then
    Halt(ABaseExitCode + 13);
  if ArrayExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 14);
  AssertExprTypeName(AModel, ArrayExpr, AExpectedElementTypeName,
    ABaseExitCode + 15);
  if ArrayExpr.SymbolId <> 0 then
    Halt(ABaseExitCode + 16);
  if Length(ArrayExpr.Children) < 2 then
    Halt(ABaseExitCode + 17);

  FieldExpr := AModel.HirExprAt(ArrayExpr.Children[0] - 1);
  if FieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 18);
  if FieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 19);
  AssertExprTypeName(AModel, FieldExpr, 'Pointer', ABaseExitCode + 20);
  if FieldExpr.LiteralInt <> AExpectedArrayFieldIndex then
    Halt(ABaseExitCode + 21);
  if FieldExpr.LiteralStr <> AExpectedFieldName then
    Halt(ABaseExitCode + 22);
  if Length(FieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 23);

  DerefExpr := AModel.HirExprAt(FieldExpr.Children[0] - 1);
  if DerefExpr.Kind <> shekDeref then
    Halt(ABaseExitCode + 24);
  if DerefExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 25);
  if Length(DerefExpr.Children) < 1 then
    Halt(ABaseExitCode + 26);

  PointerExpr := AModel.HirExprAt(DerefExpr.Children[0] - 1);
  if PointerExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 27);
  if PointerExpr.ValueClass <> shvcScalar then
    Halt(ABaseExitCode + 28);
  AssertExprTypeName(AModel, PointerExpr, 'Pointer', ABaseExitCode + 29);
  if PointerExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 30);
  Symbol := AModel.SymbolAt(PointerExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedBaseName then
    Halt(ABaseExitCode + 31);

  IndexExpr := AModel.HirExprAt(ArrayExpr.Children[1] - 1);
  if IndexExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 32);
  AssertExprTypeName(AModel, IndexExpr, 'Integer', ABaseExitCode + 33);
  if IndexExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 34);
  Symbol := AModel.SymbolAt(IndexExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedIndexName then
    Halt(ABaseExitCode + 35);
end;

procedure AssertNestedFieldArrayValueExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedFieldName,
  AExpectedIndexName, AExpectedElementTypeName, AExpectedOuterFieldTypeName,
  AExpectedLeafFieldTypeName, AExpectedOuterFieldName,
  AExpectedLeafFieldName: string; const AExpectedArrayFieldIndex,
  AExpectedOuterFieldIndex, AExpectedLeafFieldIndex: Int64;
  const ABaseExitCode: LongInt);
begin
  AssertNestedFieldArrayValueExprWithBase(AModel, ANode, 'self',
    AExpectedFieldName, AExpectedIndexName, AExpectedElementTypeName,
    AExpectedOuterFieldTypeName, AExpectedLeafFieldTypeName,
    AExpectedOuterFieldName, AExpectedLeafFieldName,
    AExpectedArrayFieldIndex, AExpectedOuterFieldIndex,
    AExpectedLeafFieldIndex, ABaseExitCode);
end;

procedure AssertNestedObjectFieldArrayValueExpr(
  const AModel: TSemanticModel; const ANode: TTypedHirNode;
  const AExpectedBaseName, AExpectedFieldName, AExpectedIndexName,
  AExpectedElementTypeName, AExpectedOuterFieldTypeName,
  AExpectedLeafFieldTypeName, AExpectedOuterFieldName,
  AExpectedLeafFieldName: string; const AExpectedArrayFieldIndex,
  AExpectedOuterFieldIndex, AExpectedLeafFieldIndex: Int64;
  const ABaseExitCode: LongInt);
begin
  AssertNestedFieldArrayValueExprWithBase(AModel, ANode, AExpectedBaseName,
    AExpectedFieldName, AExpectedIndexName, AExpectedElementTypeName,
    AExpectedOuterFieldTypeName, AExpectedLeafFieldTypeName,
    AExpectedOuterFieldName, AExpectedLeafFieldName,
    AExpectedArrayFieldIndex, AExpectedOuterFieldIndex,
    AExpectedLeafFieldIndex, ABaseExitCode);
end;

procedure AssertFieldAddressOfRuntimeExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedPointerName,
  AExpectedRecordTypeName, AExpectedFieldName: string;
  const AExpectedFieldIndex: Int64; const ABaseExitCode: LongInt);
var
  Expr, FieldExpr, DerefExpr, PointerExpr: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.ExprId = 0 then
    Halt(ABaseExitCode);
  if ANode.Operand = '' then
    Halt(ABaseExitCode + 1);

  Expr := AModel.HirExprAt(ANode.ExprId - 1);
  if Expr.Kind <> shekAddressOf then
    Halt(ABaseExitCode + 2);
  if Expr.ValueClass <> shvcScalar then
    Halt(ABaseExitCode + 3);
  AssertExprTypeName(AModel, Expr, 'Pointer', ABaseExitCode + 4);
  if Length(Expr.Children) < 1 then
    Halt(ABaseExitCode + 5);

  FieldExpr := AModel.HirExprAt(Expr.Children[0] - 1);
  if FieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 6);
  if FieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 7);
  AssertExprTypeName(AModel, FieldExpr, 'Integer', ABaseExitCode + 8);
  if FieldExpr.LiteralInt <> AExpectedFieldIndex then
    Halt(ABaseExitCode + 9);
  if FieldExpr.LiteralStr <> AExpectedFieldName then
    Halt(ABaseExitCode + 10);
  if Length(FieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 11);

  DerefExpr := AModel.HirExprAt(FieldExpr.Children[0] - 1);
  if DerefExpr.Kind <> shekDeref then
    Halt(ABaseExitCode + 12);
  if DerefExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 13);
  AssertExprTypeName(AModel, DerefExpr, AExpectedRecordTypeName,
    ABaseExitCode + 14);
  if Length(DerefExpr.Children) < 1 then
    Halt(ABaseExitCode + 15);

  PointerExpr := AModel.HirExprAt(DerefExpr.Children[0] - 1);
  if PointerExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 16);
  if PointerExpr.ValueClass <> shvcScalar then
    Halt(ABaseExitCode + 17);
  AssertExprTypeName(AModel, PointerExpr, 'Pointer', ABaseExitCode + 18);
  if PointerExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 19);
  Symbol := AModel.SymbolAt(PointerExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedPointerName then
    Halt(ABaseExitCode + 20);
end;

procedure AssertRecordFieldStoreTargetExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedRecordName,
  AExpectedRecordTypeName, AExpectedFieldTypeName, AExpectedFieldName: string;
  const AExpectedFieldIndex: Int64; const ABaseExitCode: LongInt);
var
  FieldExpr, BaseExpr: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.TargetExprId = 0 then
    Halt(ABaseExitCode);

  FieldExpr := AModel.HirExprAt(ANode.TargetExprId - 1);
  if FieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 1);
  if FieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 2);
  AssertExprTypeName(AModel, FieldExpr, AExpectedFieldTypeName,
    ABaseExitCode + 3);
  if FieldExpr.LiteralInt <> AExpectedFieldIndex then
    Halt(ABaseExitCode + 4);
  if FieldExpr.LiteralStr <> AExpectedFieldName then
    Halt(ABaseExitCode + 5);
  if Length(FieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 6);

  BaseExpr := AModel.HirExprAt(FieldExpr.Children[0] - 1);
  if BaseExpr.Kind <> shekSymbolAddress then
    Halt(ABaseExitCode + 7);
  if BaseExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 8);
  AssertExprTypeName(AModel, BaseExpr, AExpectedRecordTypeName,
    ABaseExitCode + 9);
  if BaseExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 10);
  Symbol := AModel.SymbolAt(BaseExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedRecordName then
    Halt(ABaseExitCode + 11);
end;

procedure AssertClassFieldStoreTargetExpr(const AModel: TSemanticModel;
  const ANode: TTypedHirNode; const AExpectedBaseName,
  AExpectedClassTypeName, AExpectedFieldTypeName, AExpectedFieldName: string;
  const AExpectedFieldIndex: Int64; const ABaseExitCode: LongInt);
var
  FieldExpr, DerefExpr, PointerExpr: TSemanticHirExpr;
  Symbol: TSemanticSymbol;
begin
  if ANode.TargetExprId = 0 then
    Halt(ABaseExitCode);

  FieldExpr := AModel.HirExprAt(ANode.TargetExprId - 1);
  if FieldExpr.Kind <> shekField then
    Halt(ABaseExitCode + 1);
  if FieldExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 2);
  AssertExprTypeName(AModel, FieldExpr, AExpectedFieldTypeName,
    ABaseExitCode + 3);
  if FieldExpr.LiteralInt <> AExpectedFieldIndex then
    Halt(ABaseExitCode + 4);
  if FieldExpr.LiteralStr <> AExpectedFieldName then
    Halt(ABaseExitCode + 5);
  if Length(FieldExpr.Children) < 1 then
    Halt(ABaseExitCode + 6);

  DerefExpr := AModel.HirExprAt(FieldExpr.Children[0] - 1);
  if DerefExpr.Kind <> shekDeref then
    Halt(ABaseExitCode + 7);
  if DerefExpr.ValueClass <> shvcAddress then
    Halt(ABaseExitCode + 8);
  AssertExprTypeName(AModel, DerefExpr, AExpectedClassTypeName,
    ABaseExitCode + 9);
  if Length(DerefExpr.Children) < 1 then
    Halt(ABaseExitCode + 10);

  PointerExpr := AModel.HirExprAt(DerefExpr.Children[0] - 1);
  if PointerExpr.Kind <> shekSymbolValue then
    Halt(ABaseExitCode + 11);
  if PointerExpr.ValueClass <> shvcScalar then
    Halt(ABaseExitCode + 12);
  AssertExprTypeName(AModel, PointerExpr, 'Pointer', ABaseExitCode + 13);
  if PointerExpr.SymbolId <= 0 then
    Halt(ABaseExitCode + 14);
  Symbol := AModel.SymbolAt(PointerExpr.SymbolId - 1);
  if Symbol.Name <> AExpectedBaseName then
    Halt(ABaseExitCode + 15);
end;

procedure TestHaltRuntimeExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var x: Integer;'#10 +
    'begin'#10 +
    '  x := 3;'#10 +
    '  Halt(x + 4);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(1);
    if Model.Status <> 'ready' then
      Halt(2);
    if not FindFirstNodeByKind(Model, 'halt-call-runtime', Node) then
      Halt(3);
    AssertRuntimeBinaryExpr(Model, Node, '+', 4);
  finally
    Model.Free;
  end;
end;

procedure TestWriteIntRuntimeExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var x: Integer;'#10 +
    'begin'#10 +
    '  x := 3;'#10 +
    '  WriteLn(x + 4);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(10);
    if Model.Status <> 'ready' then
      Halt(11);
    if not FindFirstNodeByKind(Model, 'write-int-runtime', Node) then
      Halt(12);
    AssertRuntimeBinaryExpr(Model, Node, '+', 13);
  finally
    Model.Free;
  end;
end;

procedure TestRetRuntimeExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'function AddOne(x: Integer): Integer;'#10 +
    'begin'#10 +
    '  Result := x + 4;'#10 +
    'end;'#10 +
    'begin'#10 +
    '  Halt(AddOne(3));'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(20);
    if Model.Status <> 'ready' then
      Halt(21);
    if not FindFirstNodeByKind(Model, 'ret-runtime', Node) then
      Halt(22);
    AssertRuntimeSymbolExpr(Model, Node, 'AddOne', 23);
  finally
    Model.Free;
  end;
end;

procedure TestCondBrRuntimeExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var x: Integer;'#10 +
    'begin'#10 +
    '  x := 3;'#10 +
    '  if x > 0 then'#10 +
    '    Halt(1)'#10 +
    '  else'#10 +
    '    Halt(2);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(30);
    if Model.Status <> 'ready' then
      Halt(31);
    if not FindFirstNodeByKind(Model, 'cond-br-runtime', Node) then
      Halt(32);
    AssertRuntimeCompareExpr(Model, Node, '>', 33);
  finally
    Model.Free;
  end;
end;

procedure TestAssignRuntimeExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var x: Integer;'#10 +
    'begin'#10 +
    '  x := 3;'#10 +
    '  x := x + 4;'#10 +
    '  Halt(x);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(40);
    if Model.Status <> 'ready' then
      Halt(41);
    if not FindFirstNodeByKindAndOperandText(Model, 'assign-runtime',
      'add', Node) then
      Halt(42);
    AssertRuntimeBinaryExpr(Model, Node, '+', 43);
  finally
    Model.Free;
  end;
end;

procedure TestIncRuntimeExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var x: Integer;'#10 +
    'begin'#10 +
    '  x := 3;'#10 +
    '  Inc(x, 4);'#10 +
    '  Halt(x);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(50);
    if Model.Status <> 'ready' then
      Halt(51);
    if not FindFirstNodeByKindAndOperandText(Model, 'assign-runtime',
      'add', Node) then
      Halt(52);
    AssertRuntimeBinaryExpr(Model, Node, '+', 53);
  finally
    Model.Free;
  end;
end;

procedure TestDecRuntimeExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var x: Integer;'#10 +
    'begin'#10 +
    '  x := 3;'#10 +
    '  Dec(x, 2);'#10 +
    '  Halt(x);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(60);
    if Model.Status <> 'ready' then
      Halt(61);
    if not FindFirstNodeByKindAndOperandText(Model, 'assign-runtime',
      'sub', Node) then
      Halt(62);
    AssertRuntimeBinaryExpr(Model, Node, '-', 63);
  finally
    Model.Free;
  end;
end;

procedure TestPointerAddressDerefRuntimeExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var x: Integer;'#10 +
    'var y: Integer;'#10 +
    'var p: ^Integer;'#10 +
    'begin'#10 +
    '  x := 5;'#10 +
    '  p := @x;'#10 +
    '  y := p^;'#10 +
    '  Halt(y);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(150);
    if Model.Status <> 'ready' then
      Halt(151);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'p',
      'varref x', Node) then
      Halt(152);
    AssertAddressOfRuntimeExpr(Model, Node, 'x', 153);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'y',
      'deref', Node) then
      Halt(164);
    AssertDerefRuntimeExpr(Model, Node, 'p', 165);
  finally
    Model.Free;
  end;
end;

procedure TestArrayElementAddressRuntimeExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var arr: array of Integer;'#10 +
    'var i: Integer;'#10 +
    'var y: Integer;'#10 +
    'var p: ^Integer;'#10 +
    'begin'#10 +
    '  SetLength(arr, 2);'#10 +
    '  i := 1;'#10 +
    '  arr[1] := 41;'#10 +
    '  p := @arr[i];'#10 +
    '  y := p^;'#10 +
    '  Halt(y);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(180);
    if Model.Status <> 'ready' then
      Halt(181);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'p',
      'arr_elem_ref arr', Node) then
      Halt(182);
    AssertArrayElementAddressOfRuntimeExpr(Model, Node, 'arr', 'i', 183);
  finally
    Model.Free;
  end;
end;

procedure TestStaticArrayElementAddressRuntimeExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var arr: array[1..3] of Integer;'#10 +
    'var i: Integer;'#10 +
    'var y: Integer;'#10 +
    'var p: ^Integer;'#10 +
    'begin'#10 +
    '  i := 1;'#10 +
    '  arr[1] := 41;'#10 +
    '  p := @arr[i];'#10 +
    '  y := p^;'#10 +
    '  Halt(y);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(218);
    if Model.Status <> 'ready' then
      Halt(219);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'p',
      'arr_elem_ref arr', Node) then
      Halt(220);
    AssertArrayElementAddressOfRuntimeExpr(Model, Node, 'arr', 'i', 221);
  finally
    Model.Free;
  end;
end;

procedure TestArrayElementStoreTargetExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var arr: array of Integer;'#10 +
    'var i: Integer;'#10 +
    'var y: Integer;'#10 +
    'begin'#10 +
    '  SetLength(arr, 2);'#10 +
    '  i := 1;'#10 +
    '  y := 41;'#10 +
    '  arr[i] := y + 1;'#10 +
    '  Halt(arr[i]);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(230);
    if Model.Status <> 'ready' then
      Halt(231);

    if not FindFirstNodeByKindAndOperandText(Model,
      'assign-arr-elem-runtime', 'add', Node) then
      Halt(232);
    AssertArrayElementStoreTargetExpr(Model, Node, 'arr', 'i', 233);
    AssertRuntimeBinaryExpr(Model, Node, '+', 236);
  finally
    Model.Free;
  end;
end;

procedure TestStaticArrayStoreTargetExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var arr: array[1..3] of Integer;'#10 +
    'var i: Integer;'#10 +
    'var y: Integer;'#10 +
    'begin'#10 +
    '  i := 1;'#10 +
    '  y := 41;'#10 +
    '  arr[i] := y + 1;'#10 +
    '  Halt(arr[i]);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(242);
    if Model.Status <> 'ready' then
      Halt(243);

    if not FindFirstNodeByKindAndOperandText(Model,
      'assign-arr-elem-runtime', 'add', Node) then
      Halt(244);
    AssertArrayElementStoreTargetExpr(Model, Node, 'arr', 'i', 245);
    AssertRuntimeBinaryExpr(Model, Node, '+', 246);
  finally
    Model.Free;
  end;
end;

procedure TestArrayElementValueExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var arr: array of Integer;'#10 +
    'var i: Integer;'#10 +
    'var x: Integer;'#10 +
    'begin'#10 +
    '  SetLength(arr, 2);'#10 +
    '  i := 1;'#10 +
    '  x := arr[i];'#10 +
    '  Halt(x);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(247);
    if Model.Status <> 'ready' then
      Halt(248);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'x',
      'arrload arr', Node) then
      Halt(249);
    AssertArrayElementValueExpr(Model, Node, 'arr', 'i', 'Integer', 250);
  finally
    Model.Free;
  end;
end;

procedure TestArrayRecordFieldStoreTargetExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TPair = record'#10 +
    '  X: Integer;'#10 +
    '  Y: Integer;'#10 +
    'end;'#10 +
    'var arr: array of TPair;'#10 +
    'var i: Integer;'#10 +
    'var y: Integer;'#10 +
    'begin'#10 +
    '  SetLength(arr, 2);'#10 +
    '  i := 1;'#10 +
    '  y := 41;'#10 +
    '  arr[i].Y := y + 1;'#10 +
    '  Halt(y);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(170);
    if Model.Status <> 'ready' then
      Halt(171);

    if not FindFirstNodeByKindAndOperandText(Model,
      'assign-arr-elem-runtime', 'add', Node) then
      Halt(172);
    AssertArrayRecordFieldStoreTargetExpr(Model, Node, 'arr', 'i', 'TPair',
      'Integer', 'Y', 1, 173);
    AssertRuntimeBinaryExpr(Model, Node, '+', 190);
  finally
    Model.Free;
  end;
end;

procedure TestNestedArrayRecordFieldValueExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TInner = record'#10 +
    '  B: Integer;'#10 +
    'end;'#10 +
    'type TOuter = record'#10 +
    '  A: TInner;'#10 +
    'end;'#10 +
    'var arr: array of TOuter;'#10 +
    'var i: Integer;'#10 +
    'var x: Integer;'#10 +
    'begin'#10 +
    '  SetLength(arr, 2);'#10 +
    '  i := 1;'#10 +
    '  x := arr[i].A.B;'#10 +
    '  Halt(x);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(251);
    if Model.Status <> 'ready' then
      Halt(252);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'x',
      'arr_load', Node) then
      Halt(253);
    AssertNestedArrayRecordFieldValueExpr(Model, Node, 'arr', 'i',
      'TOuter', 'TInner', 'Integer', 'A', 'B', 0, 0, 254);
  finally
    Model.Free;
  end;
end;

procedure TestNestedArrayRecordFieldStoreTargetExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TInner = record'#10 +
    '  B: Integer;'#10 +
    'end;'#10 +
    'type TOuter = record'#10 +
    '  A: TInner;'#10 +
    'end;'#10 +
    'var arr: array of TOuter;'#10 +
    'var i: Integer;'#10 +
    'var y: Integer;'#10 +
    'begin'#10 +
    '  SetLength(arr, 2);'#10 +
    '  i := 1;'#10 +
    '  y := 41;'#10 +
    '  arr[i].A.B := y + 1;'#10 +
    '  Halt(y);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(220);
    if Model.Status <> 'ready' then
      Halt(221);

    if not FindFirstNodeByKindAndOperandText(Model,
      'assign-arr-elem-runtime', 'add', Node) then
      Halt(222);
    AssertNestedArrayRecordFieldStoreTargetExpr(Model, Node, 'arr', 'i',
      'TOuter', 'TInner', 'Integer', 'A', 'B', 0, 0, 223);
    AssertRuntimeBinaryExpr(Model, Node, '+', 246);
  finally
    Model.Free;
  end;
end;

procedure TestFieldArrayValueExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TStack = class'#10 +
    '  FItems: array of Integer;'#10 +
    '  procedure Push(i: Integer; y: Integer);'#10 +
    'end;'#10 +
    'procedure TStack.Push(i: Integer; y: Integer);'#10 +
    'begin'#10 +
    '  y := FItems[i];'#10 +
    '  FItems[i] := y + 1;'#10 +
    '  Halt(y);'#10 +
    'end;'#10 +
    'begin'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(255);
    if Model.Status <> 'ready' then
      Halt(256);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'y',
      'arr_load', Node) then
      Halt(257);
    AssertFieldArrayElementValueExpr(Model, Node, 'FItems', 'i', 'Integer',
      1, 258);
  finally
    Model.Free;
  end;
end;

procedure TestObjectFieldArrayValueExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TStack = class'#10 +
    '  FItems: array of Integer;'#10 +
    '  function CopyItem(Other: TStack; i: Integer): Integer;'#10 +
    'end;'#10 +
    'function TStack.CopyItem(Other: TStack; i: Integer): Integer;'#10 +
    'var y: Integer;'#10 +
    'begin'#10 +
    '  y := Other.FItems[i];'#10 +
    '  Result := y;'#10 +
    'end;'#10 +
    'begin'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(71);
    if Model.Status <> 'ready' then
      Halt(72);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'y',
      'arr_load', Node) then
      Halt(73);
    AssertObjectFieldArrayElementValueExpr(Model, Node, 'Other', 'FItems', 'i',
      'Integer', 1, 74);
  finally
    Model.Free;
  end;
end;

procedure TestFieldArrayResultValueExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TStack = class'#10 +
    '  FItems: array of Integer;'#10 +
    '  function GetItem(i: Integer): Integer;'#10 +
    'end;'#10 +
    'function TStack.GetItem(i: Integer): Integer;'#10 +
    'begin'#10 +
    '  Result := FItems[i];'#10 +
    'end;'#10 +
    'begin'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(263);
    if Model.Status <> 'ready' then
      Halt(264);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'GetItem',
      'arr_load', Node) then
      Halt(265);
    AssertFieldArrayElementValueExpr(Model, Node, 'FItems', 'i', 'Integer',
      1, 266);
  finally
    Model.Free;
  end;
end;

procedure TestFieldArrayStoreTargetExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TStack = class'#10 +
    '  FItems: array of Integer;'#10 +
    '  procedure Push(i: Integer; y: Integer);'#10 +
    'end;'#10 +
    'procedure TStack.Push(i: Integer; y: Integer);'#10 +
    'begin'#10 +
    '  FItems[i] := y + 1;'#10 +
    '  Halt(y);'#10 +
    'end;'#10 +
    'begin'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(145);
    if Model.Status <> 'ready' then
      Halt(146);

    if not FindFirstNodeByKindAndOperandText(Model,
      'assign-arr-elem-runtime', 'add', Node) then
      Halt(147);
    AssertFieldArrayElementStoreTargetExpr(Model, Node, 'FItems', 'i',
      'Integer', 1, 148);
    AssertRuntimeBinaryExpr(Model, Node, '+', 172);
  finally
    Model.Free;
  end;
end;

procedure TestNestedFieldArrayValueExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TInner = record'#10 +
    '  B: Integer;'#10 +
    'end;'#10 +
    'type TOuter = record'#10 +
    '  A: TInner;'#10 +
    'end;'#10 +
    'type TStack = class'#10 +
    '  FItems: array of TOuter;'#10 +
    '  procedure Push(i: Integer; y: Integer);'#10 +
    'end;'#10 +
    'procedure TStack.Push(i: Integer; y: Integer);'#10 +
    'begin'#10 +
    '  y := Self.FItems[i].A.B;'#10 +
    '  Self.FItems[i].A.B := y + 1;'#10 +
    '  Halt(y);'#10 +
    'end;'#10 +
    'begin'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(259);
    if Model.Status <> 'ready' then
      Halt(260);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'y',
      'arr_load', Node) then
      Halt(261);
    AssertNestedFieldArrayValueExpr(Model, Node, 'FItems', 'i', 'TOuter',
      'TInner', 'Integer', 'A', 'B', 1, 0, 0, 262);
  finally
    Model.Free;
  end;
end;

procedure TestNestedFieldArrayResultValueExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TInner = record'#10 +
    '  B: Integer;'#10 +
    'end;'#10 +
    'type TOuter = record'#10 +
    '  A: TInner;'#10 +
    'end;'#10 +
    'type TStack = class'#10 +
    '  FItems: array of TOuter;'#10 +
    '  function GetLeaf(i: Integer): Integer;'#10 +
    'end;'#10 +
    'function TStack.GetLeaf(i: Integer): Integer;'#10 +
    'begin'#10 +
    '  Result := Self.FItems[i].A.B;'#10 +
    'end;'#10 +
    'begin'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(267);
    if Model.Status <> 'ready' then
      Halt(268);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'GetLeaf',
      'arr_load', Node) then
      Halt(269);
    AssertNestedFieldArrayValueExpr(Model, Node, 'FItems', 'i', 'TOuter',
      'TInner', 'Integer', 'A', 'B', 1, 0, 0, 270);
  finally
    Model.Free;
  end;
end;

procedure TestNestedObjectFieldArrayValueExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TInner = record'#10 +
    '  B: Integer;'#10 +
    'end;'#10 +
    'type TOuter = record'#10 +
    '  A: TInner;'#10 +
    'end;'#10 +
    'type TStack = class'#10 +
    '  FItems: array of TOuter;'#10 +
    '  function CopyLeaf(Other: TStack; i: Integer): Integer;'#10 +
    'end;'#10 +
    'function TStack.CopyLeaf(Other: TStack; i: Integer): Integer;'#10 +
    'var y: Integer;'#10 +
    'begin'#10 +
    '  y := Other.FItems[i].A.B;'#10 +
    '  Result := y;'#10 +
    'end;'#10 +
    'begin'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(75);
    if Model.Status <> 'ready' then
      Halt(76);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'y',
      'arr_load', Node) then
      Halt(77);
    AssertNestedObjectFieldArrayValueExpr(Model, Node, 'Other', 'FItems', 'i',
      'TOuter', 'TInner', 'Integer', 'A', 'B', 1, 0, 0, 78);
  finally
    Model.Free;
  end;
end;

procedure TestObjectFieldArrayResultValueExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TStack = class'#10 +
    '  FItems: array of Integer;'#10 +
    '  function CopyItem(Other: TStack; i: Integer): Integer;'#10 +
    'end;'#10 +
    'function TStack.CopyItem(Other: TStack; i: Integer): Integer;'#10 +
    'begin'#10 +
    '  Result := Other.FItems[i];'#10 +
    'end;'#10 +
    'begin'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(81);
    if Model.Status <> 'ready' then
      Halt(82);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'CopyItem',
      'arr_load', Node) then
      Halt(83);
    AssertObjectFieldArrayElementValueExpr(Model, Node, 'Other', 'FItems', 'i',
      'Integer', 1, 84);
  finally
    Model.Free;
  end;
end;

procedure TestNestedObjectFieldArrayResultValueExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TInner = record'#10 +
    '  B: Integer;'#10 +
    'end;'#10 +
    'type TOuter = record'#10 +
    '  A: TInner;'#10 +
    'end;'#10 +
    'type TStack = class'#10 +
    '  FItems: array of TOuter;'#10 +
    '  function CopyLeaf(Other: TStack; i: Integer): Integer;'#10 +
    'end;'#10 +
    'function TStack.CopyLeaf(Other: TStack; i: Integer): Integer;'#10 +
    'begin'#10 +
    '  Result := Other.FItems[i].A.B;'#10 +
    'end;'#10 +
    'begin'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(85);
    if Model.Status <> 'ready' then
      Halt(86);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'CopyLeaf',
      'arr_load', Node) then
      Halt(87);
    AssertNestedObjectFieldArrayValueExpr(Model, Node, 'Other', 'FItems', 'i',
      'TOuter', 'TInner', 'Integer', 'A', 'B', 1, 0, 0, 88);
  finally
    Model.Free;
  end;
end;

procedure TestNestedFieldArrayStoreTargetExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TInner = record'#10 +
    '  B: Integer;'#10 +
    'end;'#10 +
    'type TOuter = record'#10 +
    '  A: TInner;'#10 +
    'end;'#10 +
    'type TStack = class'#10 +
    '  FItems: array of TOuter;'#10 +
    '  procedure Push(i: Integer; y: Integer);'#10 +
    'end;'#10 +
    'procedure TStack.Push(i: Integer; y: Integer);'#10 +
    'begin'#10 +
    '  Self.FItems[i].A.B := y + 1;'#10 +
    '  Halt(y);'#10 +
    'end;'#10 +
    'begin'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(200);
    if Model.Status <> 'ready' then
      Halt(201);

    if not FindFirstNodeByKindAndOperandText(Model,
      'assign-arr-elem-runtime', 'add', Node) then
      Halt(202);
    AssertNestedFieldArrayStoreTargetExpr(Model, Node, 'FItems', 'i',
      'TOuter', 'TInner', 'Integer', 'A', 'B', 1, 0, 0, 203);
    AssertRuntimeBinaryExpr(Model, Node, '+', 239);
  finally
    Model.Free;
  end;
end;

procedure TestExplicitSelfFieldArrayStoreTargetExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TStack = class'#10 +
    '  FItems: array of Integer;'#10 +
    '  procedure Push(i: Integer; y: Integer);'#10 +
    'end;'#10 +
    'procedure TStack.Push(i: Integer; y: Integer);'#10 +
    'begin'#10 +
    '  Self.FItems[i] := y + 1;'#10 +
    '  Halt(y);'#10 +
    'end;'#10 +
    'begin'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(60);
    if Model.Status <> 'ready' then
      Halt(61);

    if not FindFirstNodeByKindAndOperandText(Model,
      'assign-arr-elem-runtime', 'add', Node) then
      Halt(62);
    AssertFieldArrayElementStoreTargetExpr(Model, Node, 'FItems', 'i',
      'Integer', 1, 63);
    AssertRuntimeBinaryExpr(Model, Node, '+', 87);
  finally
    Model.Free;
  end;
end;

procedure TestCommaFieldArrayStoreTargetExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TStack = class'#10 +
    '  FItems, FOther: array of Integer;'#10 +
    '  procedure Push(i: Integer; y: Integer);'#10 +
    'end;'#10 +
    'procedure TStack.Push(i: Integer; y: Integer);'#10 +
    'begin'#10 +
    '  FOther[i] := y + 1;'#10 +
    '  Halt(y);'#10 +
    'end;'#10 +
    'begin'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(90);
    if Model.Status <> 'ready' then
      Halt(91);

    if not FindFirstNodeByKindAndOperandText(Model,
      'assign-arr-elem-runtime', 'add', Node) then
      Halt(92);
    AssertFieldArrayElementStoreTargetExpr(Model, Node, 'FOther', 'i',
      'Integer', 2, 93);
    AssertRuntimeBinaryExpr(Model, Node, '+', 117);
  finally
    Model.Free;
  end;
end;

procedure TestInheritedFieldArrayStoreTargetExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TBase = class'#10 +
    '  FItems: array of Integer;'#10 +
    'end;'#10 +
    'type TChild = class(TBase)'#10 +
    '  procedure Push(i: Integer; y: Integer);'#10 +
    'end;'#10 +
    'procedure TChild.Push(i: Integer; y: Integer);'#10 +
    'begin'#10 +
    '  FItems[i] := y + 1;'#10 +
    '  Halt(y);'#10 +
    'end;'#10 +
    'begin'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(105);
    if Model.Status <> 'ready' then
      Halt(106);

    if not FindFirstNodeByKindAndOperandText(Model,
      'assign-arr-elem-runtime', 'add', Node) then
      Halt(107);
    AssertFieldArrayElementStoreTargetExpr(Model, Node, 'FItems', 'i',
      'Integer', 1, 108);
    AssertRuntimeBinaryExpr(Model, Node, '+', 132);
  finally
    Model.Free;
  end;
end;

procedure TestStaticArrayBoundsParser;
var
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Tree: TGreenTree;
  Count: LongInt;
begin
  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := nil;
  Tree := nil;
  try
    Lexer := TLexerResult.Create(
      'program test;'#10 +
      'type TArr = array[1..3] of Integer;'#10 +
      'var directArr: array[1..3] of Integer;'#10 +
      'begin'#10 +
      'end.'#10,
      Diagnostics, 1);
    Tree := ParseGreenTree(Lexer, Diagnostics, 1);
    if (Tree = nil) or (not Tree.IsValid) then
      Halt(240);
    Count := CountStaticArrayRangeNodes(Tree.RootNode, '1', '3', 'Integer');
    if Count < 2 then
      Halt(241);
  finally
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end;

procedure TestStaticArrayGlobalDeclMetadata;
var
  Model: TSemanticModel;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var globalArr: array[1..3] of Integer;'#10 +
    'begin'#10 +
    '  globalArr[1] := 40;'#10 +
    '  globalArr[2] := 2;'#10 +
    '  Halt(globalArr[1] + globalArr[2]);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(250);
    if Model.Status <> 'ready' then
      Halt(251);
    AssertStaticArrayDeclMetadata(Model, 'globalArr', 1, 3, 3, 252);
  finally
    Model.Free;
  end;
end;

procedure TestStaticArrayLocalDeclMetadata;
var
  Model: TSemanticModel;
begin
  Model := BuildModel(
    'program test;'#10 +
    'procedure Run;'#10 +
    'var localArr: array[1..3] of Integer;'#10 +
    'begin'#10 +
    '  localArr[1] := 42;'#10 +
    '  Halt(localArr[1]);'#10 +
    'end;'#10 +
    'begin'#10 +
    '  Run;'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(260);
    if Model.Status <> 'ready' then
      Halt(261);
    AssertStaticArrayDeclMetadata(Model, 'localArr', 1, 3, 3, 262);
  finally
    Model.Free;
  end;
end;

procedure TestPointerFieldAddressRuntimeExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TNode = record'#10 +
    '  Pad: Integer;'#10 +
    '  Value: Integer;'#10 +
    'end;'#10 +
    'var node: TNode;'#10 +
    'var p: ^TNode;'#10 +
    'var ip: ^Integer;'#10 +
    'begin'#10 +
    '  node.Pad := 0;'#10 +
    '  node.Value := 41;'#10 +
    '  p := @node;'#10 +
    '  ip := @p^.Value;'#10 +
    '  Halt(ip^);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(190);
    if Model.Status <> 'ready' then
      Halt(191);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'ip',
      'field_ref', Node) then
      Halt(192);
    AssertFieldAddressOfRuntimeExpr(Model, Node, 'p', 'TNode', 'Value', 1,
      193);
  finally
    Model.Free;
  end;
end;

procedure TestRecordFieldStoreRuntimeExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TPoint = record'#10 +
    '  X: Integer;'#10 +
    'end;'#10 +
    'var p: TPoint;'#10 +
    'var y: Integer;'#10 +
    'begin'#10 +
    '  y := 7;'#10 +
    '  p.X := y + 5;'#10 +
    '  Halt(p.X);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(200);
    if Model.Status <> 'ready' then
      Halt(201);

    if not FindFirstNodeByKindAndOperandText(Model,
      'record-field-store-runtime', 'add', Node) then
      Halt(202);
    AssertRuntimeBinaryExpr(Model, Node, '+', 203);
    AssertRecordFieldStoreTargetExpr(Model, Node, 'p', 'TPoint', 'Integer',
      'X', 0, 207);
  finally
    Model.Free;
  end;
end;

procedure TestClassFieldStoreRuntimeExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TCounter = class'#10 +
    '  FValue: Integer;'#10 +
    '  constructor Create(AInit: Integer);'#10 +
    'end;'#10 +
    'constructor TCounter.Create(AInit: Integer);'#10 +
    'begin'#10 +
    '  FValue := AInit + 1;'#10 +
    'end;'#10 +
    'var c: TCounter;'#10 +
    'begin'#10 +
    '  c := TCounter.Create(40);'#10 +
    '  Halt(c.FValue);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(210);
    if Model.Status <> 'ready' then
      Halt(211);

    if not FindFirstNodeByKindAndOperandText(Model, 'field-store-runtime',
      'add', Node) then
      Halt(212);
    AssertRuntimeBinaryExpr(Model, Node, '+', 213);
    AssertClassFieldStoreTargetExpr(Model, Node, 'self', 'TCounter',
      'Integer', 'FValue', 1, 217);
  finally
    Model.Free;
  end;
end;

procedure TestObjectFieldStoreRuntimeExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type TCounter = class'#10 +
    '  FValue: Integer;'#10 +
    '  procedure CopyTo(Other: TCounter; v: Integer);'#10 +
    'end;'#10 +
    'procedure TCounter.CopyTo(Other: TCounter; v: Integer);'#10 +
    'begin'#10 +
    '  Other.FValue := v + 1;'#10 +
    'end;'#10 +
    'begin'#10 +
    '  Halt(42);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(220);
    if Model.Status <> 'ready' then
      Halt(221);

    if not FindFirstNodeByKindAndOperandText(Model, 'field-store-runtime',
      'add', Node) then
      Halt(222);
    AssertRuntimeBinaryExpr(Model, Node, '+', 223);
    AssertClassFieldStoreTargetExpr(Model, Node, 'Other', 'TCounter',
      'Integer', 'FValue', 1, 227);
  finally
    Model.Free;
  end;
end;

procedure TestMixedWidthPromotionExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  Expr: TSemanticHirExpr;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  IR: string;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var b: Byte;'#10 +
    'var i: Integer;'#10 +
    'var lw: LongWord;'#10 +
    'begin'#10 +
    '  b := 7;'#10 +
    '  i := b + 4;'#10 +
    '  if b < i then Halt(1);'#10 +
    '  if lw < i then Halt(2);'#10 +
    '  Halt(i);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(70);
    if Model.Status <> 'ready' then
      Halt(71);

    if not FindFirstNodeByKindAndOperandText(Model, 'assign-runtime',
      'add', Node) then
      Halt(72);
    if Node.ExprId = 0 then
      Halt(73);
    Expr := Model.HirExprAt(Node.ExprId - 1);
    if Expr.Kind <> shekBinaryOp then
      Halt(74);
    AssertExprTypeName(Model, Expr, 'Integer', 75);
    if Length(Expr.Children) < 2 then
      Halt(76);
    AssertCastChildType(Model, Expr.Children[0], 'Integer', 'Byte', 77);
    AssertExprTypeName(Model, Model.HirExprAt(Expr.Children[1] - 1),
      'Integer', 82);

    if not FindCompareExprWithFirstCastChild(Model, 'Byte', Expr) then
      Halt(83);
    if Expr.Kind <> shekCompareOp then
      Halt(85);
    AssertExprTypeName(Model, Expr, 'Boolean', 86);
    if Length(Expr.Children) < 2 then
      Halt(87);
    AssertCastChildType(Model, Expr.Children[0], 'Integer', 'Byte', 88);
    AssertExprTypeName(Model, Model.HirExprAt(Expr.Children[1] - 1),
      'Integer', 93);

    if not FindCompareExprWithFirstCastChild(Model, 'LongWord', Expr) then
      Halt(94);
    if Expr.Kind <> shekCompareOp then
      Halt(96);
    AssertExprTypeName(Model, Expr, 'Boolean', 97);
    if Length(Expr.Children) < 2 then
      Halt(98);
    AssertCastChildType(Model, Expr.Children[0], 'Int64', 'LongWord', 99);
    AssertCastChildType(Model, Expr.Children[1], 'Int64', 'Integer', 104);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        IR := Emitter.AsText;
        if Pos('zext i8 ', IR) = 0 then
          Halt(109);
        if Pos(' to i32', IR) = 0 then
          Halt(110);
        if Pos('zext i32 ', IR) = 0 then
          Halt(111);
        if Pos('sext i32 ', IR) = 0 then
          Halt(112);
        if Pos(' to i64', IR) = 0 then
          Halt(113);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;
end;

procedure TestTypedHaltArgumentWidening;
var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  IR: string;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var i: Integer;'#10 +
    'begin'#10 +
    '  i := 7;'#10 +
    '  Halt(i);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(120);
    if Model.Status <> 'ready' then
      Halt(121);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        IR := Emitter.AsText;
        if Pos('sext i32 ', IR) = 0 then
          Halt(122);
        if Pos(' to i64', IR) = 0 then
          Halt(123);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;
end;

procedure TestTypedWriteIntArgumentWidening;
var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  IR: string;
begin
  Model := BuildModel(
    'program test;'#10 +
    'var i: Integer;'#10 +
    'begin'#10 +
    '  i := 7;'#10 +
    '  WriteLn(i);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(130);
    if Model.Status <> 'ready' then
      Halt(131);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        IR := Emitter.AsText;
        if Pos('sext i32 ', IR) = 0 then
          Halt(132);
        if Pos('call void @write_i64_decimal(i64 ', IR) = 0 then
          Halt(133);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;
end;

procedure TestTypedStoreIntoLegacyAllocaWidening;
var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  IR: string;
begin
  Model := BuildModel(
    'program test;'#10 +
    'function F: Integer;'#10 +
    'begin'#10 +
    '  F := 7;'#10 +
    'end;'#10 +
    'begin'#10 +
    '  Halt(F);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(140);
    if Model.Status <> 'ready' then
      Halt(141);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        IR := Emitter.AsText;
        if Pos('store i32 ', IR) > 0 then
          Halt(142);
        if Pos('sext i32 ', IR) = 0 then
          Halt(143);
        if Pos('store i64 ', IR) = 0 then
          Halt(144);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;
end;

procedure TestDirectCallExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  Expr, ArgExpr: TSemanticHirExpr;
begin
  Model := BuildModel(
    'program test;'#10 +
    'function AddOne(v: Integer): Integer;'#10 +
    'begin'#10 +
    '  AddOne := v + 1;'#10 +
    'end;'#10 +
    'var x: Integer;'#10 +
    'begin'#10 +
    '  x := AddOne(41);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(155);
    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'x',
      'call AddOne', Node) then
      Halt(156);
    if Node.ExprId = 0 then
      Halt(157);
    Expr := Model.HirExprAt(Node.ExprId - 1);
    if Expr.Kind <> shekCall then
      Halt(158);
    if (Expr.LiteralStr <> 'AddOne') or (Expr.Op <> 'i') then
      Halt(159);
    AssertExprTypeName(Model, Expr, 'Integer', 160);
    if Length(Expr.Children) <> 1 then
      Halt(161);
    ArgExpr := Model.HirExprAt(Expr.Children[0] - 1);
    if ArgExpr.Kind <> shekIntLiteral then
      Halt(162);
    if Expr.ValueClass <> shvcScalar then
      Halt(163);
  finally
    Model.Free;
  end;
end;

procedure TestDirectPointerCallExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  Expr: TSemanticHirExpr;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type'#10 +
    '  TNode = class'#10 +
    '  end;'#10 +
    'function MakeNode: TNode;'#10 +
    'begin'#10 +
    '  MakeNode := nil;'#10 +
    'end;'#10 +
    'var Chosen: TNode;'#10 +
    'begin'#10 +
    '  Chosen := MakeNode();'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(164);
    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'Chosen',
      'call MakeNode', Node) then
      Halt(165);
    if Node.ExprId = 0 then
      Halt(166);
    Expr := Model.HirExprAt(Node.ExprId - 1);
    if Expr.Kind <> shekCall then
      Halt(167);
    if Expr.LiteralStr <> 'MakeNode' then
      Halt(168);
    if Expr.Op <> '' then
      Halt(169);
    AssertExprTypeName(Model, Expr, 'Pointer', 170);
    if Length(Expr.Children) <> 0 then
      Halt(171);
    if Expr.ValueClass <> shvcScalar then
      Halt(172);
  finally
    Model.Free;
  end;
end;

procedure TestOrdinaryMemberCallExprProducer;
var
  Model: TSemanticModel;
  Node: TTypedHirNode;
  Expr, ReceiverExpr, ArgExpr, NestedExpr, NestedReceiverExpr: TSemanticHirExpr;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type'#10 +
    '  TCalc = class'#10 +
    '    FVal: Integer;'#10 +
    '    constructor Create(AVal: Integer);'#10 +
    '    function Get: Integer;'#10 +
    '    function AddTo(X: Integer): Integer;'#10 +
    '    function Next: TCalc;'#10 +
    '    function SumSelf: Integer;'#10 +
    '  end;'#10 +
    'constructor TCalc.Create(AVal: Integer);'#10 +
    'begin'#10 +
    '  FVal := AVal;'#10 +
    'end;'#10 +
    'function TCalc.Get: Integer;'#10 +
    'begin'#10 +
    '  Get := FVal;'#10 +
    'end;'#10 +
    'function TCalc.AddTo(X: Integer): Integer;'#10 +
    'begin'#10 +
    '  AddTo := FVal + X;'#10 +
    'end;'#10 +
    'function TCalc.Next: TCalc;'#10 +
    'begin'#10 +
    '  Next := Self;'#10 +
    'end;'#10 +
    'function TCalc.SumSelf: Integer;'#10 +
    'begin'#10 +
    '  SumSelf := Self.AddTo(Get);'#10 +
    'end;'#10 +
    'var A, B, C: TCalc; X: Integer;'#10 +
    'begin'#10 +
    '  A := TCalc.Create(10);'#10 +
    '  B := TCalc.Create(5);'#10 +
    '  X := A.AddTo(B.Get);'#10 +
    '  C := A.Next();'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(320);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'X',
      'call TCalc.AddTo', Node) then
      Halt(321);
    if Node.ExprId = 0 then
      Halt(322);
    Expr := Model.HirExprAt(Node.ExprId - 1);
    if Expr.Kind <> shekCall then
      Halt(323);
    if (Expr.LiteralStr <> 'TCalc.AddTo') or (Expr.Op <> 'pi') then
      Halt(324);
    AssertExprTypeName(Model, Expr, 'Integer', 325);
    if Length(Expr.Children) <> 2 then
      Halt(326);
    ReceiverExpr := Model.HirExprAt(Expr.Children[0] - 1);
    AssertClassReceiverAddressExpr(Model, ReceiverExpr, 'A', 327);
    ArgExpr := Model.HirExprAt(Expr.Children[1] - 1);
    if ArgExpr.Kind <> shekCall then
      Halt(333);
    if (ArgExpr.LiteralStr <> 'TCalc.Get') or (ArgExpr.Op <> 'p') then
      Halt(334);
    AssertExprTypeName(Model, ArgExpr, 'Integer', 335);
    if Length(ArgExpr.Children) <> 1 then
      Halt(336);
    NestedReceiverExpr := Model.HirExprAt(ArgExpr.Children[0] - 1);
    AssertClassReceiverAddressExpr(Model, NestedReceiverExpr, 'B', 337);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'SumSelf',
      'call TCalc.AddTo', Node) then
      Halt(343);
    if Node.ExprId = 0 then
      Halt(344);
    Expr := Model.HirExprAt(Node.ExprId - 1);
    if Expr.Kind <> shekCall then
      Halt(345);
    if (Expr.LiteralStr <> 'TCalc.AddTo') or (Expr.Op <> 'pi') then
      Halt(346);
    AssertExprTypeName(Model, Expr, 'Integer', 347);
    if Length(Expr.Children) <> 2 then
      Halt(348);
    ReceiverExpr := Model.HirExprAt(Expr.Children[0] - 1);
    AssertClassReceiverAddressExpr(Model, ReceiverExpr, 'self', 349);
    NestedExpr := Model.HirExprAt(Expr.Children[1] - 1);
    if NestedExpr.Kind <> shekCall then
      Halt(355);
    if (NestedExpr.LiteralStr <> 'TCalc.Get') or (NestedExpr.Op <> 'p') then
      Halt(356);
    AssertExprTypeName(Model, NestedExpr, 'Integer', 357);
    if Length(NestedExpr.Children) <> 1 then
      Halt(358);
    NestedReceiverExpr := Model.HirExprAt(NestedExpr.Children[0] - 1);
    AssertClassReceiverAddressExpr(Model, NestedReceiverExpr, 'self', 359);

    if not FindAssignRuntimeNodeForDestAndOperandText(Model, 'C',
      'call TCalc.Next', Node) then
      Halt(365);
    if Node.ExprId = 0 then
      Halt(366);
    Expr := Model.HirExprAt(Node.ExprId - 1);
    if Expr.Kind <> shekCall then
      Halt(367);
    if (Expr.LiteralStr <> 'TCalc.Next') or (Expr.Op <> 'p') then
      Halt(368);
    AssertExprTypeName(Model, Expr, 'Pointer', 369);
    if Length(Expr.Children) <> 1 then
      Halt(370);
    ReceiverExpr := Model.HirExprAt(Expr.Children[0] - 1);
    AssertClassReceiverAddressExpr(Model, ReceiverExpr, 'A', 371);
  finally
    Model.Free;
  end;
end;

procedure TestConstructorNestedMethodIntegerArgs;
var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  IR: string;
  CallPos: LongInt;
  LineEnd: LongInt;
  CallLine: string;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type'#10 +
    '  TPoint = class'#10 +
    '    FX, FY: Integer;'#10 +
    '    constructor Create(AX, AY: Integer);'#10 +
    '    function GetX: Integer;'#10 +
    '    function GetY: Integer;'#10 +
    '  end;'#10 +
    '  TRect = class'#10 +
    '    FWidth, FHeight: Integer;'#10 +
    '    constructor Create(AW, AH: Integer);'#10 +
    '    function Area: Integer;'#10 +
    '  end;'#10 +
    'constructor TPoint.Create(AX, AY: Integer);'#10 +
    'begin'#10 +
    '  FX := AX;'#10 +
    '  FY := AY;'#10 +
    'end;'#10 +
    'function TPoint.GetX: Integer;'#10 +
    'begin'#10 +
    '  GetX := FX;'#10 +
    'end;'#10 +
    'function TPoint.GetY: Integer;'#10 +
    'begin'#10 +
    '  GetY := FY;'#10 +
    'end;'#10 +
    'constructor TRect.Create(AW, AH: Integer);'#10 +
    'begin'#10 +
    '  FWidth := AW;'#10 +
    '  FHeight := AH;'#10 +
    'end;'#10 +
    'function TRect.Area: Integer;'#10 +
    'begin'#10 +
    '  Area := FWidth * FHeight;'#10 +
    'end;'#10 +
    'var P: TPoint; R: TRect;'#10 +
    'begin'#10 +
    '  P := TPoint.Create(3, 4);'#10 +
    '  R := TRect.Create(P.GetX, P.GetY);'#10 +
    '  Halt(R.Area);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(145);
    if Model.Status <> 'ready' then
      Halt(146);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        IR := Emitter.AsText;
        CallPos := Pos('call i64 @TRect.Create(', IR);
        if CallPos = 0 then
          Halt(147);
        LineEnd := Pos(#10, Copy(IR, CallPos, Length(IR)));
        if LineEnd > 0 then
          CallLine := Copy(IR, CallPos, LineEnd - 1)
        else
          CallLine := Copy(IR, CallPos, Length(IR));
        if CountSubstring(CallLine, ', ptr ') <> 0 then
          Halt(148);
        if CountSubstring(CallLine, ', i64 ') <> 2 then
          Halt(149);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;
end;

procedure TestConstructorNestedMethodPointerArgs;
var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  Emitter: THIRLlvmEmitter;
  IR: string;
  CallPos: LongInt;
  LineEnd: LongInt;
  CallLine: string;
begin
  Model := BuildModel(
    'program test;'#10 +
    'type'#10 +
    '  TNode = class'#10 +
    '    FNext: TNode;'#10 +
    '    constructor Create(ANext: TNode);'#10 +
    '    function NextNode: TNode;'#10 +
    '  end;'#10 +
    '  THolder = class'#10 +
    '    FNode: TNode;'#10 +
    '    constructor Create(ANode: TNode);'#10 +
    '  end;'#10 +
    'constructor TNode.Create(ANext: TNode);'#10 +
    'begin'#10 +
    '  FNext := ANext;'#10 +
    'end;'#10 +
    'function TNode.NextNode: TNode;'#10 +
    'begin'#10 +
    '  NextNode := FNext;'#10 +
    'end;'#10 +
    'constructor THolder.Create(ANode: TNode);'#10 +
    'begin'#10 +
    '  FNode := ANode;'#10 +
    'end;'#10 +
    'var First, Second: TNode; Holder: THolder;'#10 +
    'begin'#10 +
    '  First := TNode.Create(nil);'#10 +
    '  Second := TNode.Create(First);'#10 +
    '  Holder := THolder.Create(Second.NextNode);'#10 +
    '  if Holder = nil then Halt(1);'#10 +
    '  Halt(42);'#10 +
    'end.'#10
  );
  try
    if Model = nil then
      Halt(150);
    if Model.Status <> 'ready' then
      Halt(151);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      Emitter := THIRLlvmEmitter.Create(Builder.Module);
      try
        Emitter.EmitModule;
        IR := Emitter.AsText;
        CallPos := Pos('call i64 @THolder.Create(', IR);
        if CallPos = 0 then
          Halt(152);
        LineEnd := Pos(#10, Copy(IR, CallPos, Length(IR)));
        if LineEnd > 0 then
          CallLine := Copy(IR, CallPos, LineEnd - 1)
        else
          CallLine := Copy(IR, CallPos, Length(IR));
        if CountSubstring(CallLine, ', ptr ') <> 1 then
          Halt(153);
        if CountSubstring(CallLine, ', i64 ') <> 0 then
          Halt(154);
      finally
        Emitter.Free;
      end;
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;
end;

begin
  TestHaltRuntimeExprProducer;
  TestWriteIntRuntimeExprProducer;
  TestRetRuntimeExprProducer;
  TestCondBrRuntimeExprProducer;
  TestAssignRuntimeExprProducer;
  TestIncRuntimeExprProducer;
  TestDecRuntimeExprProducer;
  TestPointerAddressDerefRuntimeExprProducer;
  TestArrayElementAddressRuntimeExprProducer;
  TestStaticArrayElementAddressRuntimeExprProducer;
  TestArrayElementStoreTargetExprProducer;
  TestStaticArrayStoreTargetExprProducer;
  TestArrayElementValueExprProducer;
  TestArrayRecordFieldStoreTargetExprProducer;
  TestNestedArrayRecordFieldValueExprProducer;
  TestNestedArrayRecordFieldStoreTargetExprProducer;
  TestStaticArrayBoundsParser;
  TestStaticArrayGlobalDeclMetadata;
  TestStaticArrayLocalDeclMetadata;
  TestFieldArrayValueExprProducer;
  TestObjectFieldArrayValueExprProducer;
  TestFieldArrayResultValueExprProducer;
  TestFieldArrayStoreTargetExprProducer;
  TestNestedFieldArrayValueExprProducer;
  TestNestedObjectFieldArrayValueExprProducer;
  TestNestedFieldArrayResultValueExprProducer;
  TestObjectFieldArrayResultValueExprProducer;
  TestNestedObjectFieldArrayResultValueExprProducer;
  TestNestedFieldArrayStoreTargetExprProducer;
  TestExplicitSelfFieldArrayStoreTargetExprProducer;
  TestCommaFieldArrayStoreTargetExprProducer;
  TestInheritedFieldArrayStoreTargetExprProducer;
  TestPointerFieldAddressRuntimeExprProducer;
  TestClassFieldStoreRuntimeExprProducer;
  TestObjectFieldStoreRuntimeExprProducer;
  TestRecordFieldStoreRuntimeExprProducer;
  TestMixedWidthPromotionExprProducer;
  TestTypedHaltArgumentWidening;
  TestTypedWriteIntArgumentWidening;
  TestTypedStoreIntoLegacyAllocaWidening;
  TestDirectCallExprProducer;
  TestDirectPointerCallExprProducer;
  TestOrdinaryMemberCallExprProducer;
  TestConstructorNestedMethodIntegerArgs;
  TestConstructorNestedMethodPointerArgs;
end.
