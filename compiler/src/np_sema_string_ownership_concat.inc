function ConcatTreeHasSupportedOwnedStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
var
  Dummy: string;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if IsSupportedOwnedStringReturnConcatOperand(Ctx, ANode, Dummy) then
    Exit(True);
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') and
    (ANode.ChildCount >= 2) then
    Exit(ConcatTreeHasSupportedOwnedStringReturn(Ctx, ANode.ChildAt(0)) or
      ConcatTreeHasSupportedOwnedStringReturn(Ctx, ANode.ChildAt(1)));
end;

function CanEmitStrConcatOperand(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
var
  Dummy: string;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkIdentifier) and Ctx.IsRuntimeStrVar(Ctx.CallbackCtx, ANode.Text) then
    Exit(True);
  if (ANode.NodeKind = gnkIdentifier) and (Ctx.CurrentMethodClass <> '') and
    Ctx.TypeMetaFieldIsStr(Ctx.CallbackCtx, Ctx.CurrentMethodClass, ANode.Text) then
    Exit(True);
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') and
    (ANode.ChildCount >= 2) then
    Exit(CanEmitStrConcatOperand(Ctx, ANode.ChildAt(0)) and
      CanEmitStrConcatOperand(Ctx, ANode.ChildAt(1)));
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and SameText(ANode.ChildAt(0).Text,
    'IntToStr') and Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ANode.ChildAt(1), Dummy) then
    Exit(True);
  if IsSupportedOwnedStringReturnConcatOperand(Ctx, ANode, Dummy) then
    Exit(True);
  if ANode.NodeKind = gnkStringLiteral then
    Exit(True);
  Result := Ctx.EvaluateStringConstant(Ctx.CallbackCtx, ANode, Dummy);
end;

function EmitStrConcatOperand(var Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  const ADestVar: string): string;
var
  TempName, LitValue: string;
  FieldIdx: Int64;
begin
  Result := '';
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkIdentifier) and Ctx.IsRuntimeStrVar(Ctx.CallbackCtx, ANode.Text) then
    Exit(ANode.Text);
  if (ANode.NodeKind = gnkIdentifier) and (Ctx.CurrentMethodClass <> '') and
    Ctx.TypeMetaFieldIsStr(Ctx.CallbackCtx, Ctx.CurrentMethodClass, ANode.Text) then
  begin
    FieldIdx := Ctx.TypeMetaFieldIndex(Ctx.CallbackCtx, Ctx.CurrentMethodClass, ANode.Text);
    Inc(Ctx.BlockLabelCounter);
    TempName := '$str_tmp_' + IntToStr(Ctx.BlockLabelCounter);
    Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
    Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
    Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0, TempName);
    Ctx.Model.AddTypedHirNode(
      'assign-tstring-field-load-runtime', TempName, 0, 0,
      TempName + #9 + IntToStr(FieldIdx)
    );
    Exit(TempName);
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') and
    (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(1) <> nil) then
  begin
    LitValue := EmitStrConcatOperand(Ctx, ANode.ChildAt(0), ADestVar);
    if LitValue <> '' then
    begin
      TempName := EmitStrConcatOperand(Ctx, ANode.ChildAt(1), ADestVar);
      if TempName <> '' then
      begin
        Inc(Ctx.BlockLabelCounter);
        Result := '$str_tmp_' + IntToStr(Ctx.BlockLabelCounter);
        Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, Result);
        Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, Result);
        Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', Result, 0, 0, Result);
        { Builder contract: DisplayName=dst, Operand=left#9right. }
        Ctx.Model.AddTypedHirNode(
          'assign-tstring-concat-runtime',
          Result,
          0, 0,
          LitValue + #9 + TempName
        );
        Exit;
      end;
    end;
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'IntToStr') and
    Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ANode.ChildAt(1), LitValue) then
  begin
    Inc(Ctx.BlockLabelCounter);
    TempName := '$str_tmp_' + IntToStr(Ctx.BlockLabelCounter);
    Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
    Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
    Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0, TempName);
    Ctx.Model.AddTypedHirNode('tstring-from-int-runtime', TempName, 0, 0,
      TempName + #9 + LitValue);
    Exit(TempName);
  end;
  if IsSupportedOwnedStringReturnConcatOperand(Ctx, ANode, LitValue) then
  begin
    Inc(Ctx.BlockLabelCounter);
    TempName := '$str_cat_tmp_' + IntToStr(Ctx.BlockLabelCounter);
    Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
    Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
    Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
      TempName);
    Ctx.Model.AddTypedHirNode('string-temp-owned-runtime', LitValue, 0, 0,
      TempName + #9 + 'callee ' + Ctx.EffectiveRuntimeCalleeName(Ctx.CallbackCtx, LitValue) + #9 +
      'ptr len owner alloc_size');
    Ctx.RuntimeVars.QueuePendingStringTempRelease(TempName, LitValue);
    Exit(TempName);
  end;
  if ANode.NodeKind = gnkStringLiteral then
    LitValue := Ctx.DecodePascalStringLiteral(Ctx.CallbackCtx, ANode.Text)
  else if not Ctx.EvaluateStringConstant(Ctx.CallbackCtx, ANode, LitValue) then
    Exit;
  Inc(Ctx.BlockLabelCounter);
  TempName := '$str_tmp_' + IntToStr(Ctx.BlockLabelCounter);
  Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
  Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
  Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0, TempName);
  Ctx.Model.AddTypedHirNode('assign-tstring-literal-runtime', TempName, 0, 0, LitValue);
  Result := TempName;
end;

function CanEmitStrCompareOperand(const Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  const AAllowOwnedStringReturn: Boolean): Boolean;
var
  SourceName, TypeName: string;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkIdentifier) and Ctx.IsRuntimeStrVar(Ctx.CallbackCtx, ANode.Text) then
    Exit(True);
  { Any identifier can safely participate in string comparisons —
    comparisons don't hold references to owned string returns. }
  if (ANode.NodeKind = gnkIdentifier) and (AAllowOwnedStringReturn) then
    Exit(True);
  if ANode.NodeKind = gnkStringLiteral then
    Exit(True);
  { Batch 26: AState.SelectorName <> '' — record/class string field compare. }
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    TypeName := Ctx.LookupClassVar(Ctx.CallbackCtx, ANode.ChildAt(0).Text);
    if TypeName = '' then
      TypeName := Ctx.RuntimeVars.LookupRecordVar(ANode.ChildAt(0).Text);
    if (TypeName <> '') and
      Ctx.TypeMetaFieldIsStr(Ctx.CallbackCtx, TypeName, ANode.ChildAt(1).Text) then
      Exit(True);
  end;
  if AAllowOwnedStringReturn and (ANode.NodeKind = gnkBinaryExpression) and
    (ANode.Text = '+') and ConcatTreeHasSupportedOwnedStringReturn(Ctx, ANode) and
    CanEmitStrConcatOperand(Ctx, ANode) then
    Exit(True);
  if AAllowOwnedStringReturn and
    IsSupportedOwnedStringReturnCompareOperand(Ctx, ANode, SourceName) then
    Exit(True);
  { LowerCase/UpperCase are safe for comparisons even when overloaded }
  if AAllowOwnedStringReturn and (ANode.NodeKind = gnkFunctionCall) and
    (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (SameText(ANode.ChildAt(0).Text, 'LowerCase') or
     SameText(ANode.ChildAt(0).Text, 'UpperCase')) then
    Exit(True);
  { Any function call returning a string is safe as a compare operand —
    temporaries live for the entire comparison evaluation. This covers
    imported functions like Trim, Copy, etc. that are not registered as
    owned string return functions but still create safe temporaries. }
  if AAllowOwnedStringReturn and (ANode.NodeKind = gnkFunctionCall) and
    FunctionCallReturnsString(Ctx, ANode) then
    Exit(True);
end;

function EmitStrCompareOperand(var Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  const AAllowOwnedStringReturn: Boolean; out ABlob: string): Boolean;
var
  LeftName, RightName, SourceName, TempName, TypeName: string;
  FieldIdx: Int64;
begin
  ABlob := '';
  Result := False;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkIdentifier) and Ctx.IsRuntimeStrVar(Ctx.CallbackCtx, ANode.Text) then
  begin
    ABlob := 'strvar ' + ANode.Text + #10;
    Exit(True);
  end;
  if ANode.NodeKind = gnkStringLiteral then
  begin
    ABlob := 'strlit ' + ANode.Text + #10;
    Exit(True);
  end;
  { Batch 26: load record/class string field into a temp for strcmp. }
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    TypeName := Ctx.LookupClassVar(Ctx.CallbackCtx, ANode.ChildAt(0).Text);
    if TypeName = '' then
      TypeName := Ctx.RuntimeVars.LookupRecordVar(ANode.ChildAt(0).Text);
    if (TypeName <> '') and
      Ctx.TypeMetaFieldIsStr(Ctx.CallbackCtx, TypeName, ANode.ChildAt(1).Text) then
    begin
      FieldIdx := Ctx.TypeMetaFieldIndex(Ctx.CallbackCtx, TypeName,
        ANode.ChildAt(1).Text);
      if FieldIdx >= 0 then
      begin
        Inc(Ctx.BlockLabelCounter);
        TempName := '$str_cmp_fld_' + IntToStr(Ctx.BlockLabelCounter);
        Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
        Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
        Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
          TempName);
        Ctx.Model.AddTypedHirNode(
          'assign-tstring-field-load-runtime', TempName, 0, 0,
          ANode.ChildAt(0).Text + #9 + IntToStr(FieldIdx));
        ABlob := 'strvar ' + TempName + #10;
        Exit(True);
      end;
    end;
  end;
  if AAllowOwnedStringReturn and (ANode.NodeKind = gnkBinaryExpression) and
    (ANode.Text = '+') and (ANode.ChildCount >= 2) and
    ConcatTreeHasSupportedOwnedStringReturn(Ctx, ANode) and
    CanEmitStrConcatOperand(Ctx, ANode) then
  begin
    LeftName := EmitStrConcatOperand(Ctx, ANode.ChildAt(0), '');
    RightName := EmitStrConcatOperand(Ctx, ANode.ChildAt(1), '');
    if (LeftName = '') or (RightName = '') then
      Exit(False);
    Inc(Ctx.BlockLabelCounter);
    TempName := '$str_cmp_cat_tmp_' + IntToStr(Ctx.BlockLabelCounter);
    Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
    Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
    Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
      TempName);
    Ctx.Model.AddTypedHirNode('assign-tstring-concat-runtime', TempName, 0, 0,
      LeftName + #9 + RightName);
    Ctx.RuntimeVars.QueuePendingStringTempRelease(TempName, TempName);
    ABlob := 'strvar ' + TempName + #10;
    Exit(True);
  end;
  if AAllowOwnedStringReturn and
    IsSupportedOwnedStringReturnCompareOperand(Ctx, ANode, SourceName) then
  begin
    Inc(Ctx.BlockLabelCounter);
    TempName := '$str_cmp_tmp_' + IntToStr(Ctx.BlockLabelCounter);
    Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
    Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
    Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
      TempName);
    Ctx.Model.AddTypedHirNode('string-temp-owned-runtime', SourceName, 0, 0,
      TempName + #9 + 'callee ' + Ctx.EffectiveRuntimeCalleeName(Ctx.CallbackCtx, SourceName) + #9 +
      'ptr len owner alloc_size');
    Ctx.RuntimeVars.QueuePendingStringTempRelease(TempName, SourceName);
    ABlob := 'strvar ' + TempName + #10;
    Exit(True);
  end;
end;

procedure ScanTopLevelOwnedStringReturnConsumers(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; var AChanged: Boolean);
var
  I, J: LongInt;
  Child: TGreenNode;
  FuncName: string;
begin
  if ANode = nil then
    Exit;
  if AssignmentOwnsTopLevelStringReturn(Ctx, ANode) and
    StringReturnFunctionNameFromNode(Ctx, ANode.ChildAt(1), FuncName) and
    (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
  begin
    Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
    AChanged := True;
  end;
  if ANode.NodeKind = gnkFunctionCall then
  begin
    for J := 1 to ANode.ChildCount - 1 do
    begin
      if CallArgumentOwnsStringReturn(Ctx, 
        ANode, ANode.ChildAt(J), J - 1, FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
      if (SameText(ANode.Text, 'WriteLn') or SameText(ANode.Text, 'Write')) and
        WriteArgumentOwnsStringReturn(Ctx, ANode.ChildAt(J), FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
      if SameText(ANode.Text, 'WriteLn') or SameText(ANode.Text, 'Write') then
        RegisterConcatOwnedStringReturnConsumers(Ctx, ANode.ChildAt(J), AChanged);
    end;
    if LengthArgumentOwnsStringReturn(Ctx, ANode, FuncName) and
      (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
    begin
      Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
      AChanged := True;
    end;
    if (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
      SameText(ANode.ChildAt(0).Text, 'Length') then
      RegisterConcatOwnedStringReturnConsumers(Ctx, ANode.ChildAt(1), AChanged);
    if CopyArgumentOwnsStringReturn(Ctx, ANode, FuncName) and
      (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
    begin
      Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
      AChanged := True;
    end;
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') then
  begin
    for J := 0 to ANode.ChildCount - 1 do
    begin
      if ConcatOperandOwnsStringReturn(Ctx, ANode.ChildAt(J), FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
    end;
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and
    ((ANode.Text = '=') or (ANode.Text = '<>')) then
  begin
    for J := 0 to ANode.ChildCount - 1 do
    begin
      if CompareOperandOwnsStringReturn(Ctx, ANode.ChildAt(J), FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
    end;
  end;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child <> nil) and
      ((Child.NodeKind = gnkProcedureDecl) or
       (Child.NodeKind = gnkFunctionDecl)) then
      Continue;
    ScanTopLevelOwnedStringReturnConsumers(Ctx, Child, AChanged);
  end;
end;

procedure RegisterConcatOwnedStringReturnConsumers(const Ctx: TSemaOwnershipContext; 
  const AConcatNode: TGreenNode; var AChanged: Boolean);
var
  I: LongInt;
  FuncName: string;
begin
  if (AConcatNode = nil) or (AConcatNode.NodeKind <> gnkBinaryExpression) or
    (AConcatNode.Text <> '+') then
    Exit;
  for I := 0 to AConcatNode.ChildCount - 1 do
  begin
    if ConcatOperandOwnsStringReturn(Ctx, AConcatNode.ChildAt(I), FuncName) and
      (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
    begin
      Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
      AChanged := True;
    end;
    RegisterConcatOwnedStringReturnConsumers(Ctx, AConcatNode.ChildAt(I), AChanged);
  end;
end;

