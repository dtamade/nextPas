function EncodeRuntimeBoolExprFold(const Ctx: TSemaHirLoweringContext;
  const ANode: TGreenNode; out ABlob: string;
  const AAllowOwnedStringCompare: Boolean): Boolean;
var
  LeftBlob, RightBlob, Op, Pred: string;
begin
  ABlob := '';
  if ANode = nil then
    Exit(False);
  if (ANode.NodeKind = gnkUnaryExpression) and
    SameText(ANode.Text, 'not') and (ANode.ChildCount >= 1) then
  begin
    if not EncodeRuntimeBoolExprFold(Ctx, ANode.ChildAt(0), LeftBlob,
      AAllowOwnedStringCompare) then
      Exit(False);
    ABlob := 'int 1' + #10 + LeftBlob + 'zext' + #10 + 'sub' + #10 +
      'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and Ctx.RuntimeVars.IsRuntimeVar(ANode.Text) then
  begin
    ABlob := 'var ' + ANode.Text + #10 + 'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'True') then
  begin
    ABlob := 'int 1' + #10 + 'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'False') then
  begin
    ABlob := 'int 0' + #10 + 'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) or
    ((ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2)) then
  begin
    if Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ANode, LeftBlob) then
    begin
      ABlob := LeftBlob + 'int 0' + #10 + 'cmp ne' + #10;
      Exit(True);
    end;
  end;
  if ANode.NodeKind <> gnkBinaryExpression then
    Exit(False);
  if ANode.ChildCount < 2 then
    Exit(False);
  Op := ANode.Text;
  if Op = '=' then Pred := 'eq'
  else if Op = '<>' then Pred := 'ne'
  else if Op = '<' then Pred := 'slt'
  else if Op = '<=' then Pred := 'sle'
  else if Op = '>' then Pred := 'sgt'
  else if Op = '>=' then Pred := 'sge'
  else if SameText(Op, 'and') then
  begin
    if not EncodeRuntimeBoolExprFold(Ctx, ANode.ChildAt(0), LeftBlob,
      AAllowOwnedStringCompare) then
      Exit(False);
    if not EncodeRuntimeBoolExprFold(Ctx, ANode.ChildAt(1), RightBlob,
      AAllowOwnedStringCompare) then
      Exit(False);
    ABlob := LeftBlob + 'zext' + #10 + RightBlob + 'zext' + #10 +
      'mul' + #10 + 'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end
  else if SameText(Op, 'or') then
  begin
    if not EncodeRuntimeBoolExprFold(Ctx, ANode.ChildAt(0), LeftBlob,
      AAllowOwnedStringCompare) then
      Exit(False);
    if not EncodeRuntimeBoolExprFold(Ctx, ANode.ChildAt(1), RightBlob,
      AAllowOwnedStringCompare) then
      Exit(False);
    ABlob := LeftBlob + 'zext' + #10 + RightBlob + 'zext' + #10 +
      'add' + #10 + 'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end
  else if SameText(Op, 'is') then
  begin
    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
      (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
    begin
      if np_sema_type_check.TypeMetaIsInterface(Ctx.Model, ANode.ChildAt(1).Text) then
      begin
        if (Ctx.RuntimeVars.LookupClassVar(ANode.ChildAt(0).Text) <> '') and
          (Pos(ANode.ChildAt(1).Text,
            np_sema_type_check.TypeMetaInterfaces(Ctx.Model,
              Ctx.RuntimeVars.LookupClassVar(ANode.ChildAt(0).Text))) > 0) then
          ABlob := 'int 1' + #10 + 'int 0' + #10 + 'cmp ne' + #10
        else
          ABlob := 'int 0' + #10 + 'int 0' + #10 + 'cmp ne' + #10;
        Exit(True);
      end;
      ABlob := 'var ' + ANode.ChildAt(0).Text + #10 +
        'is ' + ANode.ChildAt(1).Text + #10 +
        'int 0' + #10 + 'cmp ne' + #10;
      Exit(True);
    end;
    Exit(False);
  end
  else if SameText(Op, 'as') then
  begin
    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
      (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
      (np_sema_type_check.TypeMetaIsInterface(Ctx.Model, ANode.ChildAt(1).Text)) then
    begin
      ABlob := 'var ' + ANode.ChildAt(0).Text + #10;
      Exit(True);
    end;
    Exit(False);
  end
  else
    Exit(False);
  if (Op = '=') or (Op = '<>') then
  begin
    if Ctx.CanEmitStrCompareOperand(Ctx.CallbackCtx, ANode.ChildAt(0),
      AAllowOwnedStringCompare) and
      Ctx.CanEmitStrCompareOperand(Ctx.CallbackCtx, ANode.ChildAt(1),
      AAllowOwnedStringCompare) then
    begin
      if Ctx.EmitStrCompareOperand(Ctx.CallbackCtx, ANode.ChildAt(0),
        AAllowOwnedStringCompare, LeftBlob) and
        Ctx.EmitStrCompareOperand(Ctx.CallbackCtx, ANode.ChildAt(1),
        AAllowOwnedStringCompare, RightBlob) then
      begin
        ABlob := LeftBlob + RightBlob + 'strcmp ' + Pred + #10 +
          'int 0' + #10 + 'cmp ne' + #10;
        Exit(True);
      end;
    end;
  end;
  if not Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ANode.ChildAt(0), LeftBlob) then
    Exit(False);
  if not Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ANode.ChildAt(1), RightBlob) then
    Exit(False);
  ABlob := LeftBlob + RightBlob + 'cmp ' + Pred + #10;
  Result := True;
end;

