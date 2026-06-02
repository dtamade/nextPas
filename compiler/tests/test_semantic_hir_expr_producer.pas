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
  TestMixedWidthPromotionExprProducer;
  TestTypedHaltArgumentWidening;
  TestTypedWriteIntArgumentWidening;
  TestTypedStoreIntoLegacyAllocaWidening;
end.
