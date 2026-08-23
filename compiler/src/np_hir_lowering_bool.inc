{ Char-like operand in a compare: 8-bit scalar params are registered as
  pseudo class vars (the slot holds the char address, not the value) and
  char-pointer index access (StrLen: S[Result] <> #0) folds to the element
  address via arr_elem_ref. Both need the i8 loaded before comparing; flag
  them so the caller appends 'charval'. Numeric pointees (pelem_load) and
  string vars already carry values, and bare pointers (S <> nil) must stay
  address compares — only the three Char pointer kinds match here. }
function IsCharValueBlobOperand(const Ctx: TSemaHirLoweringContext;
  const ANode: TGreenNode): Boolean;
var
  VarTypeName: string;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if ANode.NodeKind = gnkIdentifier then
  begin
    VarTypeName := Ctx.RuntimeVars.LookupClassVar(ANode.Text);
    Result := (VarTypeName <> '') and
      (nextpas.compiler.sema.type_check.TypeMetaSize(Ctx.Model, VarTypeName) = 1);
  end
  else if (ANode.NodeKind = gnkArrayAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) then
  begin
    VarTypeName := Ctx.RuntimeVars.LookupPointerVar(ANode.ChildAt(0).Text);
    Result := SameText(VarTypeName, 'PChar') or
      SameText(VarTypeName, 'PAnsiChar') or SameText(VarTypeName, 'PUTF8Char');
  end;
end;

function EncodeRuntimeBoolExprFold(const Ctx: TSemaHirLoweringContext;
  const ANode: TGreenNode; out ABlob: string;
  const AAllowOwnedStringCompare: Boolean): Boolean;
var
  LeftBlob, RightBlob, Op, Pred, RecTypeName: string;
  RecNode: TGreenNode;
  LeftIsNil, RightIsNil: Boolean;
  FieldIdx: Int64;
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
      if nextpas.compiler.sema.type_check.TypeMetaIsInterface(Ctx.Model, ANode.ChildAt(1).Text) then
      begin
        if (Ctx.RuntimeVars.LookupClassVar(ANode.ChildAt(0).Text) <> '') and
          (Pos(ANode.ChildAt(1).Text,
            nextpas.compiler.sema.type_check.TypeMetaInterfaces(Ctx.Model,
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
      (nextpas.compiler.sema.type_check.TypeMetaIsInterface(Ctx.Model, ANode.ChildAt(1).Text)) then
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

    { TGreenNode (and similar facade records): class operator =/<> nil means
      FIndex < 0 / FIndex >= 0. Residual recvar+null+cmp compares the buffer
      address (always non-null) and also emits invalid icmp i64/ptr. }
    LeftIsNil := (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
      SameText(ANode.ChildAt(0).Text, 'nil');
    RightIsNil := (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
      SameText(ANode.ChildAt(1).Text, 'nil');
    RecNode := nil;
    if RightIsNil and (not LeftIsNil) then
      RecNode := ANode.ChildAt(0)
    else if LeftIsNil and (not RightIsNil) then
      RecNode := ANode.ChildAt(1);
    if (RecNode <> nil) and (RecNode.NodeKind = gnkIdentifier) and
      Ctx.RuntimeVars.IsRecordVar(RecNode.Text) then
    begin
      RecTypeName := Ctx.RuntimeVars.LookupRecordVar(RecNode.Text);
      FieldIdx := -1;
      if RecTypeName <> '' then
      begin
        FieldIdx := nextpas.compiler.sema.type_check.TypeMetaFieldIndex(Ctx.Model,
          RecTypeName, 'FIndex');
        if FieldIdx < 0 then
          FieldIdx := nextpas.compiler.sema.type_check.TypeMetaFieldIndex(Ctx.Model,
            RecTypeName, 'Index');
      end;
      { Layout fallback: TGreenNode = (FOwner:ptr, FIndex:LongInt) → slot 1. }
      if (FieldIdx < 0) and
        ((RecTypeName = '') or SameText(RecTypeName, 'TGreenNode')) then
        FieldIdx := 1;
      if FieldIdx >= 0 then
      begin
        { = nil → FIndex < 0; <> nil → FIndex >= 0 }
        if Op = '=' then
          Pred := 'slt'
        else
          Pred := 'sge';
        ABlob := 'rload ' + RecNode.Text + ' ' + IntToStr(FieldIdx) + #10 +
          'int 0' + #10 + 'cmp ' + Pred + #10;
        Exit(True);
      end;
    end;
  end;
  if not Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ANode.ChildAt(0), LeftBlob) then
    Exit(False);
  if not Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ANode.ChildAt(1), RightBlob) then
    Exit(False);
  if IsCharValueBlobOperand(Ctx, ANode.ChildAt(0)) then
    LeftBlob := LeftBlob + 'charval' + #10;
  if IsCharValueBlobOperand(Ctx, ANode.ChildAt(1)) then
    RightBlob := RightBlob + 'charval' + #10;
  ABlob := LeftBlob + RightBlob + 'cmp ' + Pred + #10;
  Result := True;
end;

