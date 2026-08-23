function EmitOwnedStringConcatLengthTemp(var Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out ABlob: string): Boolean;
var
  ConcatNode: TGreenNode;
  LeftName, RightName, TempName: string;
begin
  ABlob := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount < 2) or (ANode.ChildAt(0) = nil) or
    (not SameText(ANode.ChildAt(0).Text, 'Length')) then
    Exit;
  ConcatNode := ANode.ChildAt(1);
  if (ConcatNode = nil) or (ConcatNode.NodeKind <> gnkBinaryExpression) or
    (ConcatNode.Text <> '+') or (ConcatNode.ChildCount < 2) or
    (not ConcatTreeHasSupportedOwnedStringReturn(Ctx, ConcatNode)) or
    (not CanEmitStrConcatOperand(Ctx, ConcatNode)) then
    Exit;
  LeftName := EmitStrConcatOperand(Ctx, ConcatNode.ChildAt(0), '');
  RightName := EmitStrConcatOperand(Ctx, ConcatNode.ChildAt(1), '');
  if (LeftName = '') or (RightName = '') then
    Exit;
  Inc(Ctx.BlockLabelCounter);
  TempName := '$str_len_cat_tmp_' + IntToStr(Ctx.BlockLabelCounter);
  Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
  Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
  Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
    TempName);
  Ctx.Model.AddTypedHirNode('assign-tstring-concat-runtime', TempName, 0, 0,
    LeftName + #9 + RightName);
  Ctx.Model.AddTypedHirNode('string-temp-length-runtime', TempName, 0, 0,
    'strvar ' + TempName + #10);
  Ctx.RuntimeVars.QueuePendingStringTempRelease(TempName, TempName);
  Ctx.RuntimeVars.ClearPendingStringTempReleases;
  ABlob := 'var ' + TempName + '$len' + #10;
  Result := True;
end;

function EmitOwnedStringConcatWriteTemp(var Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out ATempName: string): Boolean;
var
  LeftName, RightName: string;
begin
  ATempName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkBinaryExpression) or
    (ANode.Text <> '+') or (ANode.ChildCount < 2) or
    (not ConcatTreeHasSupportedOwnedStringReturn(Ctx, ANode)) or
    (not CanEmitStrConcatOperand(Ctx, ANode)) then
    Exit;
  LeftName := EmitStrConcatOperand(Ctx, ANode.ChildAt(0), '');
  RightName := EmitStrConcatOperand(Ctx, ANode.ChildAt(1), '');
  if (LeftName = '') or (RightName = '') then
    Exit;
  Inc(Ctx.BlockLabelCounter);
  ATempName := '$str_wrt_cat_tmp_' + IntToStr(Ctx.BlockLabelCounter);
  Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, ATempName);
  Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, ATempName);
  Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', ATempName, 0, 0,
    ATempName);
  Ctx.Model.AddTypedHirNode('assign-tstring-concat-runtime', ATempName, 0, 0,
    LeftName + #9 + RightName);
  Ctx.RuntimeVars.QueuePendingStringTempRelease(ATempName, ATempName);
  Result := True;
end;

function ConcatExpressionConsumesOwnedStringReturnDeferred(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
var
  I: LongInt;
  Child: TGreenNode;
  SourceName: string;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if IsSupportedOwnedStringReturnConcatOperand(Ctx, ANode, SourceName) then
    Exit(False);
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') then
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if ConcatExpressionConsumesOwnedStringReturnDeferred(Ctx, Child,
        AInsideDirectOwnedAssignmentRhs) then
        Exit(True);
    end;
    Exit(False);
  end;
  Result := NodeConsumesOwnedStringReturnDeferred(Ctx, ANode,
    AInsideDirectOwnedAssignmentRhs);
end;

function BoolConditionHasSupportedOwnedStringCompare(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
var
  Dummy: string;

  function CanEmitOwnedCompareOperand(const ALocalNode: TGreenNode): Boolean;
  begin
    Result := False;
    if ALocalNode = nil then
      Exit;
    if (ALocalNode.NodeKind = gnkIdentifier) and
      Ctx.IsRuntimeStrVar(Ctx.CallbackCtx, ALocalNode.Text) then
      Exit(True);
    if ALocalNode.NodeKind = gnkStringLiteral then
      Exit(True);
    if IsSupportedOwnedStringReturnCompareOperand(Ctx, ALocalNode, Dummy) then
      Exit(True);
    if (ALocalNode.NodeKind = gnkBinaryExpression) and
      (ALocalNode.Text = '+') and (ALocalNode.ChildCount >= 2) then
      Exit(
        ConcatTreeHasSupportedOwnedStringReturn(Ctx, ALocalNode) and
        CanEmitOwnedCompareOperand(ALocalNode.ChildAt(0)) and
        CanEmitOwnedCompareOperand(ALocalNode.ChildAt(1)));
  end;

  function IsSupportedCompareNode(const ALocalNode: TGreenNode): Boolean;
  begin
    Result := False;
    if (ALocalNode = nil) or (ALocalNode.NodeKind <> gnkBinaryExpression) or
      ((ALocalNode.Text <> '=') and (ALocalNode.Text <> '<>')) or
      (ALocalNode.ChildCount < 2) then
      Exit;
    if not (CanEmitOwnedCompareOperand(ALocalNode.ChildAt(0)) and
      CanEmitOwnedCompareOperand(ALocalNode.ChildAt(1))) then
      Exit;
    Result :=
      IsSupportedOwnedStringReturnCompareOperand(Ctx, ALocalNode.ChildAt(0),
        Dummy) or
      IsSupportedOwnedStringReturnCompareOperand(Ctx, ALocalNode.ChildAt(1),
        Dummy) or
      ConcatTreeHasSupportedOwnedStringReturn(Ctx, ALocalNode.ChildAt(0)) or
      ConcatTreeHasSupportedOwnedStringReturn(Ctx, ALocalNode.ChildAt(1));
  end;

  function HasSupportedOwnedCompare(const ALocalNode: TGreenNode): Boolean;
  begin
    Result := False;
    if ALocalNode = nil then
      Exit;
    if (ALocalNode.NodeKind = gnkUnaryExpression) and
      SameText(ALocalNode.Text, 'not') and (ALocalNode.ChildCount >= 1) then
      Exit(HasSupportedOwnedCompare(ALocalNode.ChildAt(0)));
    if (ALocalNode.NodeKind = gnkBinaryExpression) and
      (SameText(ALocalNode.Text, 'and') or SameText(ALocalNode.Text, 'or')) and
      (ALocalNode.ChildCount >= 2) then
      Exit(HasSupportedOwnedCompare(ALocalNode.ChildAt(0)) or
        HasSupportedOwnedCompare(ALocalNode.ChildAt(1)));
    Result := IsSupportedCompareNode(ALocalNode);
  end;

  function CanEmitOwnedBoolCondition(const ALocalNode: TGreenNode): Boolean;
  begin
    Result := False;
    if ALocalNode = nil then
      Exit;
    if (ALocalNode.NodeKind = gnkUnaryExpression) and
      SameText(ALocalNode.Text, 'not') and (ALocalNode.ChildCount >= 1) then
      Exit(CanEmitOwnedBoolCondition(ALocalNode.ChildAt(0)));
    if (ALocalNode.NodeKind = gnkIdentifier) and
      (Ctx.IsRuntimeVar(Ctx.CallbackCtx, ALocalNode.Text) or SameText(ALocalNode.Text, 'True') or
       SameText(ALocalNode.Text, 'False')) then
      Exit(True);
    if (ALocalNode.NodeKind = gnkBinaryExpression) and
      (SameText(ALocalNode.Text, 'and') or SameText(ALocalNode.Text, 'or')) and
      (ALocalNode.ChildCount >= 2) then
      Exit(CanEmitOwnedBoolCondition(ALocalNode.ChildAt(0)) and
        CanEmitOwnedBoolCondition(ALocalNode.ChildAt(1)));
    Result :=
      (ALocalNode.NodeKind = gnkBinaryExpression) and
      ((ALocalNode.Text = '=') or (ALocalNode.Text = '<>')) and
      (ALocalNode.ChildCount >= 2) and
      CanEmitOwnedCompareOperand(ALocalNode.ChildAt(0)) and
      CanEmitOwnedCompareOperand(ALocalNode.ChildAt(1));
  end;
begin
  Result := CanEmitOwnedBoolCondition(ANode) and
    HasSupportedOwnedCompare(ANode);
end;

function CompareExpressionConsumesOwnedStringReturnDeferred(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
var
  I: LongInt;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkUnaryExpression) and SameText(ANode.Text, 'not') and
    (ANode.ChildCount >= 1) then
    Exit(CompareExpressionConsumesOwnedStringReturnDeferred(Ctx, ANode.ChildAt(0)));
  if (ANode.NodeKind = gnkBinaryExpression) and
    (SameText(ANode.Text, 'and') or SameText(ANode.Text, 'or')) and
    (ANode.ChildCount >= 2) then
    Exit(CompareExpressionConsumesOwnedStringReturnDeferred(Ctx, ANode.ChildAt(0)) or
      CompareExpressionConsumesOwnedStringReturnDeferred(Ctx, ANode.ChildAt(1)));
  if (ANode.NodeKind <> gnkBinaryExpression) or
    ((ANode.Text <> '=') and (ANode.Text <> '<>')) or
    (ANode.ChildCount < 2) then
  begin
    { In compare expressions (if/while conditions), all sub-expressions are
      consumed immediately. Temporaries from owned string returns are safe. }
    for I := 0 to ANode.ChildCount - 1 do
      if NodeConsumesOwnedStringReturnDeferred(Ctx, ANode.ChildAt(I), True) then
        Exit(True);
    Exit(False);
  end;
  if CanEmitStrCompareOperand(Ctx, ANode.ChildAt(0), True) and
    CanEmitStrCompareOperand(Ctx, ANode.ChildAt(1), True) then
    Exit(False);
  Result := NodeConsumesOwnedStringReturnDeferred(Ctx, ANode, False);
end;

function NodeConsumesOwnedStringReturnDeferred(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode;
  const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
var
  I: LongInt;
  BodyNode, Child, DeclNode, DestNode, SourceNode: TGreenNode;
  SourceName: string;
begin
  Result := False;
  if ANode = nil then
    Exit;

  if (ANode.NodeKind = gnkProcedureDecl) or
    (ANode.NodeKind = gnkFunctionDecl) then
    Exit;

  { Concatenation (+) is a safe context: temporaries live for the entire
    expression evaluation. This handles patterns like FormatFloat(...) + 'x'
    or 'a' + F() + 'b' where the owned string return is used in a concatenation. }
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') then
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then Continue;
      if NodeConsumesOwnedStringReturnDeferred(Ctx, Child, True) then
        Exit(True);
    end;
    Exit(False);
  end;

  { Set constructors [...] are safe contexts: temporaries live for the entire
    constructor evaluation. This handles patterns like TextFormat('...', [FormatFloat(...)])
    where the owned string return is used inside a set constructor. }
  if ANode.NodeKind = gnkSetConstructor then
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then Continue;
      if NodeConsumesOwnedStringReturnDeferred(Ctx, Child, True) then
        Exit(True);
    end;
    Exit(False);
  end;

  if (ANode.NodeKind = gnkIfStatement) and (ANode.ChildCount >= 1) then
  begin
    if CompareExpressionConsumesOwnedStringReturnDeferred(Ctx, ANode.ChildAt(0)) then
      Exit(True);
    for I := 1 to ANode.ChildCount - 1 do
      if NodeConsumesOwnedStringReturnDeferred(Ctx, 
        ANode.ChildAt(I), AInsideDirectOwnedAssignmentRhs) then
        Exit(True);
    Exit(False);
  end;

  if ((ANode.NodeKind = gnkWhileStatement) or
    (ANode.NodeKind = gnkRepeatStatement)) and (ANode.ChildCount >= 2) then
  begin
    if ANode.NodeKind = gnkWhileStatement then
    begin
      Child := ANode.ChildAt(0);
      BodyNode := ANode.ChildAt(1);
    end
    else
    begin
      BodyNode := ANode.ChildAt(0);
      Child := ANode.ChildAt(1);
    end;
    if CompareExpressionConsumesOwnedStringReturnDeferred(Ctx, Child) then
      Exit(True);
    if BoolConditionHasSupportedOwnedStringCompare(Ctx, Child) then
      Exit(NodeConsumesOwnedStringReturnDeferred(Ctx, 
        BodyNode, AInsideDirectOwnedAssignmentRhs));
  end;

  if DirectOwnedStringReturnAssignmentNode(Ctx, ANode) then
  begin
    if ANode.ChildCount >= 2 then
    begin
      for I := 0 to ANode.ChildAt(1).ChildCount - 1 do
      begin
        if (ANode.ChildAt(1).NodeKind = gnkFunctionCall) and (I = 0) then
          Continue;
        if (ANode.ChildAt(1).NodeKind = gnkFunctionCall) and
          IsSupportedOwnedStringReturnArgument(Ctx, ANode.ChildAt(1),
            ANode.ChildAt(1).ChildAt(I), I - 1) then
          Continue;
        if NodeConsumesOwnedStringReturnDeferred(Ctx, 
          ANode.ChildAt(1).ChildAt(I), False) then
          Exit(True);
      end;
    end;
    Exit(False);
  end;

  if ANode.NodeKind = gnkAssignmentStatement then
  begin
    if ANode.ChildCount >= 2 then
    begin
      DestNode := ANode.ChildAt(0);
      SourceNode := ANode.ChildAt(1);
      if (IsSupportedOwnedStringReturnStoreTarget(Ctx, DestNode) or
        IsSupportedOwnedStringReturnIdentifierTarget(Ctx, DestNode)) and
        StringReturnFunctionNameFromNode(Ctx, SourceNode, SourceName) and
        Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, SourceName) then
        Exit(False);
      if (DestNode <> nil) and (DestNode.NodeKind = gnkIdentifier) and
        Ctx.IsRuntimeStrVar(Ctx.CallbackCtx, DestNode.Text) and
        (SourceNode <> nil) and (SourceNode.NodeKind = gnkBinaryExpression) and
        (SourceNode.Text = '+') then
        Exit(ConcatExpressionConsumesOwnedStringReturnDeferred(Ctx, SourceNode,
          True));
      Exit(NodeConsumesOwnedStringReturnDeferred(Ctx, 
        SourceNode, {AInsideDirectOwnedAssignmentRhs=}True));
    end;
    Exit(False);
  end;

  if (ANode.NodeKind = gnkFunctionCall) and
    ((SameText(ANode.Text, 'WriteLn')) or (SameText(ANode.Text, 'Write'))) then
  begin
    for I := 1 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then
        Continue;
      if IsSupportedOwnedStringReturnWriteArgument(Ctx, Child, SourceName) then
        Continue;
      if (Child.NodeKind = gnkBinaryExpression) and (Child.Text = '+') and
        ConcatTreeHasSupportedOwnedStringReturn(Ctx, Child) and
        CanEmitStrConcatOperand(Ctx, Child) then
        Continue;
      { WriteLn/Write arguments are safe contexts: temporaries live for
        the entire call duration. }
      if NodeConsumesOwnedStringReturnDeferred(Ctx, Child, True) then
        Exit(True);
    end;
    Exit(False);
  end;

  if (ANode.NodeKind = gnkFunctionCall) and
    Ctx.LookupProcedureBody(Ctx.CallbackCtx, ANode.Text, BodyNode, DeclNode) and
    (not FunctionCallReturnsString(Ctx, ANode)) then
  begin
    for I := 1 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then
        Continue;
      if IsSupportedOwnedStringReturnArgument(Ctx, ANode, Child, I - 1) then
        Continue;
      if NodeConsumesOwnedStringReturnDeferred(Ctx, 
        Child, AInsideDirectOwnedAssignmentRhs) then
        Exit(True);
    end;
    Exit(False);
  end;

  if IsSupportedOwnedStringReturnLengthArgument(Ctx, ANode, SourceName) then
    Exit(False);
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkBinaryExpression) and
    (ANode.ChildAt(1).Text = '+') and
    ConcatTreeHasSupportedOwnedStringReturn(Ctx, ANode.ChildAt(1)) and
    CanEmitStrConcatOperand(Ctx, ANode.ChildAt(1)) then
    Exit(False);
  if IsSupportedOwnedStringReturnCopyArgument(Ctx, ANode, SourceName) then
    Exit(False);

  if StringReturnFunctionNameFromNode(Ctx, ANode, SourceName) and
    Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, SourceName) and
    (not AInsideDirectOwnedAssignmentRhs) then
    Exit(True);
  if MemberCallReturnsString(Ctx, ANode) and
    (not AInsideDirectOwnedAssignmentRhs) then
    Exit(True);
  { Note: FunctionCallReturnsString catch-all intentionally removed.
    It was too broad — flagging ALL string-returning functions, not just
    registered owned string return functions. The StringReturnFunctionNameFromNode
    + IsOwnedStringReturnFunc check above correctly limits to registered
    functions. }
  if DirectOwnedStringReturnAssignmentNode(Ctx, ANode) and
    StringReturnFunctionNameFromNode(Ctx, ANode.ChildAt(1), SourceName) and
    Ctx.HasOverload(Ctx.CallbackCtx, SourceName) then
    Exit(True);

  { Exit(Expr) is equivalent to Result := Expr — the temporary lives for
    the entire function scope. Treat as safe context.
    Without this guard, Exit(F()) patterns where F is an imported function
    (like ExpandFileName from nextpas.core.fs) would fall through to the
    for-loop below, where the F() child would be flagged as a deferred
    owned-string return. }
  if ANode.NodeKind = gnkExitStatement then
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then Continue;
      { The owned string temporary from F() in Exit(F()) lives for the
        entire duration of Exit — treat as safe context. }
      if NodeConsumesOwnedStringReturnDeferred(Ctx, Child, True) then
        Exit(True);
    end;
    Exit(False);
  end;

  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    { Owned string temporaries passed as arguments to a function call are
      safe: the temporary lives for the entire enclosing call's duration.
      This handles patterns like SameText(LowerCase(S), 'value') where the
      outer call has overloads (preventing IsSupportedOwnedStringReturnArgument
      from applying). Mark argument positions (I >= 1) as safe contexts. }
    if (ANode.NodeKind = gnkFunctionCall) and (I >= 1) then
    begin
      if NodeConsumesOwnedStringReturnDeferred(Ctx, Child, True) then
        Exit(True);
    end
    { Concatenation operands are safe: temporaries live for the entire
      expression evaluation. }
    else if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') then
    begin
      if NodeConsumesOwnedStringReturnDeferred(Ctx, Child, True) then
        Exit(True);
    end
    else if NodeConsumesOwnedStringReturnDeferred(Ctx, 
      Child, AInsideDirectOwnedAssignmentRhs) then
      Exit(True);
  end;
end;
