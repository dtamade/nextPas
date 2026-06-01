program test_hir_builder_expr_fallback;

{$mode objfpc}{$H+}

uses
  SysUtils, np_semantic_model, np_hir_builder, np_hir_model;

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

var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  ExprResult: THIRExprResult;
  ExprId, LiteralExprId, UnsupportedExprId, BadSymbolExprId, PartialExprId,
    NodeId: LongInt;
  Children: array of LongInt;
  Func: THIRFunction;
begin
  Model := TSemanticModel.Create;
  try
    SetLength(Children, 0);
    ExprId := Model.AddHirExpr(
      shekInvalid,
      0,
      0,
      Children,
      0,
      '',
      '',
      0,
      shvcNone
    );
    Builder := THIRBuilder.Create(Model);
    try
      if Builder.LowerExpr(ExprId, ExprResult) then
        Halt(1);
      if (ExprResult.ValueId <> 0) or (ExprResult.TypeId <> 0) or
        (ExprResult.AddressValueId <> 0) or (ExprResult.ValueClass <> shvcNone) then
        Halt(2);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;

  Model := TSemanticModel.Create;
  try
    SetLength(Children, 0);
    LiteralExprId := Model.AddHirExpr(
      shekIntLiteral,
      0,
      0,
      Children,
      99,
      '',
      '',
      0,
      shvcScalar
    );
    UnsupportedExprId := Model.AddHirExpr(
      shekCall,
      0,
      0,
      Children,
      0,
      '',
      '',
      0,
      shvcScalar
    );
    SetLength(Children, 2);
    Children[0] := LiteralExprId;
    Children[1] := UnsupportedExprId;
    PartialExprId := Model.AddHirExpr(
      shekBinaryOp,
      0,
      0,
      Children,
      0,
      '',
      '+',
      0,
      shvcScalar
    );
    Model.AddTypedHirNode('var-decl-runtime', 'x', 0, 0, 'x');
    NodeId := Model.AddTypedHirNode(
      'assign-runtime', 'x := fallback', 0, 0, 'x'#9'int 7'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, PartialExprId);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      if Builder.Module.FunctionCount = 0 then
        Halt(3);
      Func := Builder.Module.FunctionAt(0);
      if not HasConstLoad(Func, 'const:7') then
        Halt(4);
      if HasConstLoad(Func, 'const:99') then
        Halt(5);
    finally
      Builder.Free;
    end;

  finally
    Model.Free;
  end;

  Model := TSemanticModel.Create;
  try
    SetLength(Children, 0);
    LiteralExprId := Model.AddHirExpr(
      shekIntLiteral,
      0,
      0,
      Children,
      123,
      '',
      '',
      0,
      shvcScalar
    );
    BadSymbolExprId := Model.AddHirExpr(
      shekSymbolValue,
      0,
      999,
      Children,
      0,
      '',
      '',
      0,
      shvcScalar
    );
    SetLength(Children, 2);
    Children[0] := LiteralExprId;
    Children[1] := BadSymbolExprId;
    PartialExprId := Model.AddHirExpr(
      shekBinaryOp,
      0,
      0,
      Children,
      0,
      '',
      '+',
      0,
      shvcScalar
    );
    Model.AddTypedHirNode('var-decl-runtime', 'z', 0, 0, 'z');
    NodeId := Model.AddTypedHirNode(
      'assign-runtime', 'z := fallback', 0, 0, 'z'#9'int 11'#10
    );
    Model.SetTypedHirNodeExprId(NodeId, PartialExprId);

    Builder := THIRBuilder.Create(Model);
    try
      Builder.Build;
      if Builder.Module.FunctionCount = 0 then
        Halt(6);
      Func := Builder.Module.FunctionAt(0);
      if not HasConstLoad(Func, 'const:11') then
        Halt(7);
      if HasConstLoad(Func, 'const:123') then
        Halt(8);
    finally
      Builder.Free;
    end;
  finally
    Model.Free;
  end;
end.
