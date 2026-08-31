function TSemanticAnalyzer.ArrayElementTypeNode(
  const AArrayTypeNode: TGreenNode): TGreenNode;
begin
  Result := nil;
  if (AArrayTypeNode = nil) or (AArrayTypeNode.NodeKind <> gnkArrayType) then
    Exit;
  if AArrayTypeNode.ChildCount < 1 then
    Exit;
  Result := AArrayTypeNode.ChildAt(0);
end;

function TSemanticAnalyzer.TryGetArrayTypeBounds(
  const AArrayTypeNode: TGreenNode; out ALow, AHigh, ALength: Int64): Boolean;
var
  RangeNode: TGreenNode;
begin
  ALow := 0;
  AHigh := -1;
  ALength := 0;
  if (AArrayTypeNode = nil) or (AArrayTypeNode.NodeKind <> gnkArrayType) or
    (AArrayTypeNode.ChildCount < 2) then
    Exit(False);
  RangeNode := AArrayTypeNode.ChildAt(1);
  if (RangeNode = nil) or (RangeNode.NodeKind <> gnkRangeExpression) or
    (RangeNode.ChildCount < 2) then
    Exit(False);
  if not EvaluateIntegerConstant(RangeNode.ChildAt(0), ALow) then
    Exit(False);
  if not EvaluateIntegerConstant(RangeNode.ChildAt(1), AHigh) then
    Exit(False);
  if AHigh < ALow then
    Exit(False);
  ALength := AHigh - ALow + 1;
  Result := ALength > 0;
end;

function TSemanticAnalyzer.FindArrayTypeNodeForVarDecl(
  const AVarSection: TGreenNode; const ADeclIndex: LongInt): TGreenNode;
var
  K: LongInt;
  Decl, TypeChild, NextSibling: TGreenNode;
begin
  Result := nil;
  if (AVarSection = nil) or (ADeclIndex < 0) or
    (ADeclIndex >= AVarSection.ChildCount) then
    Exit;
  Decl := AVarSection.ChildAt(ADeclIndex);
  if (Decl = nil) or (Decl.NodeKind <> gnkVarDecl) then
    Exit;
  if Decl.ChildCount > 0 then
  begin
    TypeChild := Decl.ChildAt(0);
    if (TypeChild <> nil) and (TypeChild.NodeKind = gnkArrayType) then
      Exit(TypeChild);
    if (TypeChild <> nil) and (TypeChild.Text = '') then
    begin
      for K := ADeclIndex + 1 to AVarSection.ChildCount - 1 do
      begin
        NextSibling := AVarSection.ChildAt(K);
        if (NextSibling <> nil) and (NextSibling.NodeKind <> gnkVarDecl) then
        begin
          if NextSibling.NodeKind = gnkArrayType then
            Exit(NextSibling);
          Break;
        end;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.RegisterArrayVarMetadata(const AVarName: string;
  const AArrayTypeNode: TGreenNode; out AOperand: string);
var
  ElementNode: TGreenNode;
  LowBound, HighBound, ArrLength: Int64;
begin
  AOperand := AVarName;
  RegisterRuntimeArrVar(AVarName);

  ElementNode := ArrayElementTypeNode(AArrayTypeNode);
  if ElementNode <> nil then
  begin
    FModel.AddStringConstValue(AVarName + '$arr_elem_type',
      ElementNode.Text);
    { Elem size in bytes for SizeOf / dynarray stride.
      Prefer known scalars first — TypeMetaSize may be bits/slots and must
      not override Char=1 etc. }
    if SameText(ElementNode.Text, 'Char') or
      SameText(ElementNode.Text, 'AnsiChar') or
      SameText(ElementNode.Text, 'Byte') or
      SameText(ElementNode.Text, 'Boolean') or
      SameText(ElementNode.Text, 'ShortInt') then
      FModel.AddConstValue(AVarName + '$arr_elem_size', 1)
    else if SameText(ElementNode.Text, 'WideChar') or
      SameText(ElementNode.Text, 'Word') or
      SameText(ElementNode.Text, 'SmallInt') then
      FModel.AddConstValue(AVarName + '$arr_elem_size', 2)
    else if SameText(ElementNode.Text, 'Integer') or
      SameText(ElementNode.Text, 'LongInt') or
      SameText(ElementNode.Text, 'Cardinal') or
      SameText(ElementNode.Text, 'LongWord') or
      SameText(ElementNode.Text, 'DWord') then
      FModel.AddConstValue(AVarName + '$arr_elem_size', 4)
    else if SameText(ElementNode.Text, 'Int64') or
      SameText(ElementNode.Text, 'QWord') or
      SameText(ElementNode.Text, 'NativeInt') or
      SameText(ElementNode.Text, 'NativeUInt') or
      SameText(ElementNode.Text, 'Pointer') or
      SameText(ElementNode.Text, 'PChar') or
      SameText(ElementNode.Text, 'PAnsiChar') then
      FModel.AddConstValue(AVarName + '$arr_elem_size', 8)
    else if TypeMetaSize(ElementNode.Text) > 0 then
      FModel.AddConstValue(AVarName + '$arr_elem_size',
        TypeMetaSize(ElementNode.Text))
    else if TypeMetaIsRecord(ElementNode.Text) then
      FModel.AddConstValue(AVarName + '$arr_elem_size',
        TypeMetaSize(ElementNode.Text));
  end;

  if TryGetArrayTypeBounds(AArrayTypeNode, LowBound, HighBound, ArrLength) then
  begin
    FModel.AddConstValue(AVarName + '$arr_static', 1);
    FModel.AddConstValue(AVarName + '$arr_low', LowBound);
    FModel.AddConstValue(AVarName + '$arr_high', HighBound);
    FModel.AddConstValue(AVarName + '$arr_len', ArrLength);
    AOperand := AVarName + #9 + 'static' + #9 + IntToStr(LowBound) +
      #9 + IntToStr(HighBound) + #9 + IntToStr(ArrLength);
  end;
end;
