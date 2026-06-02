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
  TestArrayElementStoreTargetExprProducer;
  TestPointerFieldAddressRuntimeExprProducer;
  TestClassFieldStoreRuntimeExprProducer;
  TestObjectFieldStoreRuntimeExprProducer;
  TestRecordFieldStoreRuntimeExprProducer;
  TestMixedWidthPromotionExprProducer;
  TestTypedHaltArgumentWidening;
  TestTypedWriteIntArgumentWidening;
  TestTypedStoreIntoLegacyAllocaWidening;
end.
