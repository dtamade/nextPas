program test_hir_builder_expr_fallback;

{$mode objfpc}{$H+}

uses
  SysUtils, np_semantic_model, np_hir_builder;

var
  Model: TSemanticModel;
  Builder: THIRBuilder;
  ExprResult: THIRExprResult;
  ExprId: LongInt;
  Children: array of LongInt;
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
end.
