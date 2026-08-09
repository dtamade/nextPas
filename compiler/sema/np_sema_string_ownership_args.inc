function LengthArgumentOwnsStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  CalleeNode, ArgNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount < 2) then
    Exit;
  CalleeNode := ANode.ChildAt(0);
  ArgNode := ANode.ChildAt(1);
  if (CalleeNode = nil) or (ArgNode = nil) or
    (CalleeNode.NodeKind <> gnkIdentifier) or
    (not SameText(CalleeNode.Text, 'Length')) then
    Exit;
  if (ArgNode.NodeKind <> gnkFunctionCall) or
    (ArgNode.ChildCount < 1) or (ArgNode.ChildAt(0) = nil) or
    (ArgNode.ChildAt(0).NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(Ctx, ArgNode, AFuncName) then
    Exit;
  Result := not Ctx.HasOverload(Ctx.CallbackCtx, AFuncName);
end;

function IsSupportedOwnedStringReturnLengthArgument(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := LengthArgumentOwnsStringReturn(Ctx, ANode, AFuncName) and
    Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, AFuncName);
end;

function EmitOwnedStringLengthTemp(var Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  out ABlob: string): Boolean;
var
  SourceName, TempName: string;
begin
  ABlob := '';
  Result := False;
  if not IsSupportedOwnedStringReturnLengthArgument(Ctx, ANode, SourceName) then
    Exit;
  Inc(Ctx.BlockLabelCounter);
  TempName := '$str_len_tmp_' + IntToStr(Ctx.BlockLabelCounter);
  Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
  Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
  Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
    TempName);
  Ctx.Model.AddTypedHirNode('string-temp-owned-runtime', SourceName, 0, 0,
    TempName + #9 + 'callee ' + Ctx.EffectiveRuntimeCalleeName(Ctx.CallbackCtx, SourceName) + #9 +
    'ptr len owner alloc_size');
  Ctx.Model.AddTypedHirNode('string-temp-length-runtime', SourceName, 0, 0,
    'strvar ' + TempName + #10);
  Ctx.Model.AddTypedHirNode('string-temp-release-runtime', SourceName, 0, 0,
    TempName);
  ABlob := 'var ' + TempName + '$len' + #10;
  Result := True;
end;

function CopyArgumentOwnsStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  CalleeNode, ArgNode, FuncNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount < 4) then
    Exit;
  CalleeNode := ANode.ChildAt(0);
  ArgNode := ANode.ChildAt(1);
  if (CalleeNode = nil) or (ArgNode = nil) or
    (CalleeNode.NodeKind <> gnkIdentifier) or
    (not SameText(CalleeNode.Text, 'Copy')) then
    Exit;
  if (ArgNode.NodeKind <> gnkFunctionCall) or
    (ArgNode.ChildCount < 1) then
    Exit;
  FuncNode := ArgNode.ChildAt(0);
  if (FuncNode = nil) or (FuncNode.NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(Ctx, ArgNode, AFuncName) then
    Exit;
  Result := SameText(FuncNode.Text, AFuncName) and
    (not Ctx.HasOverload(Ctx.CallbackCtx, AFuncName));
end;

function IsSupportedOwnedStringReturnCopyArgument(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := CopyArgumentOwnsStringReturn(Ctx, ANode, AFuncName) and
    Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, AFuncName);
end;

function EmitOwnedStringCopyTemp(var Ctx: TSemaOwnershipContext; const ACopyNode: TGreenNode;
  const ADestName: string; out ATempName: string): Boolean;
var
  SourceName, StartBlob, LenBlob: string;
begin
  ATempName := '';
  Result := False;
  if (ADestName = '') or
    (not IsSupportedOwnedStringReturnCopyArgument(Ctx, ACopyNode, SourceName)) then
    Exit;
  if (not Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ACopyNode.ChildAt(2), StartBlob)) or
    (not Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ACopyNode.ChildAt(3), LenBlob)) then
    Exit;
  Inc(Ctx.BlockLabelCounter);
  ATempName := '$str_cpy_tmp_' + IntToStr(Ctx.BlockLabelCounter);
  Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, ATempName);
  Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, ATempName);
  Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', ATempName, 0, 0,
    ATempName);
  Ctx.Model.AddTypedHirNode('string-temp-owned-runtime', SourceName, 0, 0,
    ATempName + #9 + 'callee ' + Ctx.EffectiveRuntimeCalleeName(Ctx.CallbackCtx, SourceName) + #9 +
    'ptr len owner alloc_size');
  Ctx.Model.AddTypedHirNode('tstring-copy-runtime', ADestName, 0, 0,
    ADestName + #9 + ATempName + #9 + StartBlob + #9 + LenBlob);
  Ctx.Model.AddTypedHirNode('string-temp-release-runtime', SourceName, 0, 0,
    ATempName);
  Result := True;
end;

function WriteArgumentOwnsStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  CalleeNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount <> 1) then
    Exit;
  CalleeNode := ANode.ChildAt(0);
  if (CalleeNode = nil) or (CalleeNode.NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(Ctx, ANode, AFuncName) then
    Exit;
  Result := SameText(CalleeNode.Text, AFuncName) and
    (not Ctx.HasOverload(Ctx.CallbackCtx, AFuncName));
end;

function IsSupportedOwnedStringReturnWriteArgument(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := WriteArgumentOwnsStringReturn(Ctx, ANode, AFuncName) and
    Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, AFuncName);
end;

function EmitOwnedStringWriteTemp(var Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out ATempName: string): Boolean;
var
  SourceName: string;
begin
  ATempName := '';
  Result := False;
  if not IsSupportedOwnedStringReturnWriteArgument(Ctx, ANode, SourceName) then
    Exit;
  Inc(Ctx.BlockLabelCounter);
  ATempName := '$str_wrt_tmp_' + IntToStr(Ctx.BlockLabelCounter);
  Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, ATempName);
  Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, ATempName);
  Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', ATempName, 0, 0,
    ATempName);
  Ctx.Model.AddTypedHirNode('string-temp-owned-runtime', SourceName, 0, 0,
    ATempName + #9 + 'callee ' + Ctx.EffectiveRuntimeCalleeName(Ctx.CallbackCtx, SourceName) + #9 +
    'ptr len owner alloc_size');
  Ctx.RuntimeVars.QueuePendingStringTempRelease(ATempName, SourceName);
  Result := True;
end;

function ConcatOperandOwnsStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  FuncNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount <> 1) then
    Exit;
  FuncNode := ANode.ChildAt(0);
  if (FuncNode = nil) or (FuncNode.NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(Ctx, ANode, AFuncName) then
    Exit;
  Result := SameText(FuncNode.Text, AFuncName);
end;

function IsSupportedOwnedStringReturnConcatOperand(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := ConcatOperandOwnsStringReturn(Ctx, ANode, AFuncName) and
    Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, AFuncName);
end;

function CompareOperandOwnsStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  FuncNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount < 1) then
    Exit;
  FuncNode := ANode.ChildAt(0);
  if (FuncNode = nil) or (FuncNode.NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(Ctx, ANode, AFuncName) then
    Exit;
  Result := SameText(FuncNode.Text, AFuncName) and
    (not Ctx.HasOverload(Ctx.CallbackCtx, AFuncName));
end;

function IsSupportedOwnedStringReturnCompareOperand(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := CompareOperandOwnsStringReturn(Ctx, ANode, AFuncName) and
    Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, AFuncName);
end;


