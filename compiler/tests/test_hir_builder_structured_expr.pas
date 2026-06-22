program test_hir_builder_structured_expr;

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv, np_semantic_model, np_hir_builder, np_hir_model;

var
  Model: TSemanticModel;
  IntegerTypeId, BooleanTypeId: LongInt;

procedure AssertTrue(const ACondition: Boolean; const ACode: LongInt);
begin
  if not ACondition then
    Halt(ACode);
end;

function AddIntLiteral(const AValue: Int64): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 0);
  Result := Model.AddHirExpr(
    shekIntLiteral, IntegerTypeId, 0, Children, AValue, '', '', 0, shvcScalar
  );
end;

function AddSymbolValue(const ASymbolId: LongInt): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 0);
  Result := Model.AddHirExpr(
    shekSymbolValue, IntegerTypeId, ASymbolId, Children, 0, '', '', 0,
    shvcScalar
  );
end;

function AddUnaryOp(const AOp: string; const AChild: LongInt): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 1);
  Children[0] := AChild;
  Result := Model.AddHirExpr(
    shekUnaryOp, BooleanTypeId, 0, Children, 0, '', AOp, 0, shvcScalar
  );
end;

function AddBinaryOp(const AOp: string; const ALeft, ARight: LongInt): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 2);
  Children[0] := ALeft;
  Children[1] := ARight;
  if SameText(AOp, 'and') or SameText(AOp, 'or') then
    Result := Model.AddHirExpr(
      shekBinaryOp, BooleanTypeId, 0, Children, 0, '', AOp, 0, shvcScalar
    )
  else
    Result := Model.AddHirExpr(
      shekBinaryOp, IntegerTypeId, 0, Children, 0, '', AOp, 0, shvcScalar
    );
end;

function AddCompareOp(const AOp: string; const ALeft, ARight: LongInt): LongInt;
var
  Children: array of LongInt;
begin
  SetLength(Children, 2);
  Children[0] := ALeft;
  Children[1] := ARight;
  Result := Model.AddHirExpr(
    shekCompareOp, BooleanTypeId, 0, Children, 0, '', AOp, 0, shvcScalar
  );
end;

function HasInstrKind(const AFunc: THIRFunction; const AKind: THIRInstrKind): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
      if AFunc.Blocks[BlockIndex].Instrs[InstrIndex].Kind = AKind then
        Exit(True);
  Result := False;
end;

function HasConstLoad(const AFunc: THIRFunction; const AName: string): Boolean;
var
  BlockIndex, InstrIndex: LongInt;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    for InstrIndex := 0 to High(AFunc.Blocks[BlockIndex].Instrs) do
      if (AFunc.Blocks[BlockIndex].Instrs[InstrIndex].Kind = hikLoad) and
        (AFunc.Blocks[BlockIndex].Instrs[InstrIndex].IntrinsicName = AName) then
        Exit(True);
  Result := False;
end;

function HasCondBranch(const AFunc: THIRFunction): Boolean;
var
  BlockIndex: LongInt;
begin
  for BlockIndex := 0 to High(AFunc.Blocks) do
    if (AFunc.Blocks[BlockIndex].Terminator.Kind = htkCondBranch) and
      (AFunc.Blocks[BlockIndex].Terminator.Condition <> 0) then
      Exit(True);
  Result := False;
end;

var
  Builder: THIRBuilder;
  Func: THIRFunction;
  SymY, SymX: LongInt;
  ExprInt5, ExprSymY, ExprSymX, ExprAdd, ExprCmpY, ExprCmpX: LongInt;
  ExprAnd, ExprOr, ExprNot: LongInt;
  NodeId: LongInt;
begin
  Model := TSemanticModel.Create;
  try
    IntegerTypeId := Model.AddType('Integer', 'builtin');
    Model.SetTypeScalarFact(IntegerTypeId, sskInt, 32, True);
    BooleanTypeId := Model.AddType('Boolean', 'builtin');
    Model.SetTypeScalarFact(BooleanTypeId, sskBool, 1, False);
    SymY := Model.AddSymbol('y', 'var', '', IntegerTypeId, 0);
    SymX := Model.AddSymbol('x', 'var', '', IntegerTypeId, 0);

    ExprInt5 := AddIntLiteral(5);
    ExprSymY := AddSymbolValue(SymY);
    ExprSymX := AddSymbolValue(SymX);
    ExprAdd := AddBinaryOp('+', ExprSymY, AddIntLiteral(4));
    ExprCmpY := AddCompareOp('=', ExprSymY, ExprInt5);
    ExprCmpX := AddCompareOp('>', ExprSymX, AddIntLiteral(8));
    ExprAnd := AddBinaryOp('and', ExprCmpY, ExprCmpX);
    ExprOr := AddBinaryOp('or', ExprAnd, ExprCmpY);
    ExprNot := AddUnaryOp('not', ExprOr);

    Model.AddTypedHirNode('var-decl-runtime', 'y', SymY, IntegerTypeId, 'y');
    NodeId := Model.AddTypedHirNode(
      'assign-runtime', 'y := structured literal', 0, 0, 'y'#9'int 0'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, ExprInt5);

    NodeId := Model.AddTypedHirNode(
      'assign-runtime', 'x := structured add', 0, 0, 'x'#9'int 0'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, ExprAdd);

    NodeId := Model.AddTypedHirNode(
      'cond-br-runtime', 'structured condition', 0, 0,
      'int 0'#10'labels then_block'#9'else_block'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, ExprNot);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      AssertTrue(Builder.Module.FunctionCount > 0, 1);
      Func := Builder.Module.FunctionAt(0);

      AssertTrue(HasConstLoad(Func, 'const:5'), 2);
      AssertTrue(HasConstLoad(Func, 'const:4'), 3);
      AssertTrue(HasConstLoad(Func, 'const:8'), 4);
      AssertTrue(HasInstrKind(Func, hikAdd), 5);
      AssertTrue(HasInstrKind(Func, hikCmpEq), 6);
      AssertTrue(HasInstrKind(Func, hikCmpGt), 7);
      AssertTrue(HasInstrKind(Func, hikMul), 8);
      AssertTrue(HasCondBranch(Func), 9);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;
end.
