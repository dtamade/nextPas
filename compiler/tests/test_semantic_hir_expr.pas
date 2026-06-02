program test_semantic_hir_expr;

{$mode objfpc}{$H+}

uses
  np_semantic_model, np_hir_types;

var
  Model: TSemanticModel;
  ExprId: LongInt;
  Expr: TSemanticHirExpr;
  NodeId: LongInt;
  Node: TTypedHirNode;
  Children: array of LongInt;
begin
  Model := TSemanticModel.Create;
  SetLength(Children, 0);

  ExprId := Model.AddHirExpr(
    shekIntLiteral,
    7,
    0,
    Children,
    42,
    '',
    'add',
    128,
    shvcScalar
  );

  if ExprId <> 1 then
    Halt(1);

  if Model.HirExprCount <> 1 then
    Halt(2);

  Expr := Model.HirExprAt(0);
  if Expr.ExprId <> 1 then
    Halt(3);
  if Expr.Kind <> shekIntLiteral then
    Halt(4);
  if Expr.TypeId <> 7 then
    Halt(5);
  if Expr.SymbolId <> 0 then
    Halt(6);
  if Expr.LiteralInt <> 42 then
    Halt(7);
  if Expr.LiteralStr <> '' then
    Halt(8);
  if Expr.Op <> 'add' then
    Halt(9);
  if Expr.SourceOffset <> 128 then
    Halt(10);
  if Expr.ValueClass <> shvcScalar then
    Halt(11);

  NodeId := Model.AddTypedHirNode('assign-runtime', 'x := 1', 0, 0, 'x'#9'int 1'#10);
  if NodeId <> 1 then
    Halt(12);

  Model.SetTypedHirNodeExprId(NodeId, ExprId);
  Model.SetTypedHirNodeTargetExprId(NodeId, ExprId);

  Node := Model.TypedHirNodeAt(0);
  if Node.ExprId <> ExprId then
    Halt(13);
  if Node.TargetExprId <> ExprId then
    Halt(14);

  Model.Free;
end.
