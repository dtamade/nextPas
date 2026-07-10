procedure EmitBlockLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);
begin
  Ctx.Model.AddTypedHirNode('block-label-runtime', ALabel, 0, 0, ALabel);
  Ctx.CurrentBlockTerminated := False;
end;

procedure EmitGotoLabel(var Ctx: TSemaHirLoweringContext; const ALabel: string);
begin
  if Ctx.CurrentBlockTerminated then
    Exit;
  Ctx.Model.AddTypedHirNode('br-runtime', ALabel, 0, 0, ALabel);
  Ctx.CurrentBlockTerminated := True;
end;

{ === 运行时表达式附着 === }

procedure AttachRuntimeReturnExpr(const Ctx: TSemaHirLoweringContext;
  const AHirNodeId: LongInt; const AReturnVarName: string);
var
  Children: array of LongInt;
  ExprId, SymbolId: LongInt;
begin
  if (AHirNodeId <= 0) or (AReturnVarName = '') then
    Exit;
  SymbolId := Ctx.Model.FindSymbolByName(AReturnVarName);
  if SymbolId <= 0 then
    Exit;
  SetLength(Children, 0);
  ExprId := Ctx.Model.AddHirExpr(
    shekSymbolValue, 0,
    SymbolId, Children, 0, 0.0, '', '', 0, shvcScalar
  );
  Ctx.Model.SetTypedHirNodeExprId(AHirNodeId, ExprId);
end;

{ === 诊断发射 === }

procedure EmitSemaError(const Ctx: TSemaHirLoweringContext;
  const ACode: string; const AMessage: string; const AByteOffset: LongInt);
var
  EmptyPayload: TDiagnosticPayload;
begin
  EmptyPayload.Kind := dpkNone;
  Ctx.Diagnostics.EmitErrorWithPayload(
    ACode, 'sema',
    BuildCoreSourceSpan(Ctx.RootFileId, AByteOffset, 0),
    AMessage, EmptyPayload);
end;

{ === 运行时变量查询 === }

function HirLowering_IsRuntimeStrVar(const Ctx: TSemaHirLoweringContext;
  const AName: string): Boolean;
var
  SymId: LongInt;
  TypeId: LongInt;
  TypeName: string;
begin
  if Ctx.RuntimeVars.IsRuntimeStrVar(AName) then
    Exit(True);
  SymId := Ctx.Model.FindSymbolByName(AName);
  if SymId > 0 then
  begin
    TypeId := Ctx.Model.SymbolAt(SymId - 1).TypeId;
    if TypeId > 0 then
    begin
      TypeName := Ctx.Model.TypeAt(TypeId - 1).Name;
      if SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString') then
        Exit(True);
    end;
  end;
  Result := False;
end;

{ === AST→HIR 表达式降级 (BuildRuntimeScalarHirExpr) === }
