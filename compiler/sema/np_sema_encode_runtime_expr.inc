function TSemanticAnalyzer.EncodeRuntimeIntExprFoldCore(
  const ANode: TGreenNode; out ABlob: string; out AExprId: LongInt): Boolean;

  function NeedsFoldFallback(const N: TGreenNode): Boolean;
  var
    I: LongInt;
    Child: TGreenNode;
  begin
    if N = nil then
      Exit(False);
    if (N.NodeKind = gnkIdentifier) and (N.Text <> '') and
      not IsRuntimeVar(N.Text) then
      Exit(True);
    if N.NodeKind = gnkFunctionCall then
      Exit(True);
    for I := 0 to N.ChildCount - 1 do
    begin
      Child := N.ChildAt(I);
      if (Child <> nil) and NeedsFoldFallback(Child) then
        Exit(True);
    end;
    Result := False;
  end;

  function TryPointerFieldAccess(const ALocalNode: TGreenNode;
    out APointerName, APointeeTypeName, AFieldName: string;
    out AFieldIndex: Int64): Boolean;
  var
    BaseNode, DerefNode, FieldNode: TGreenNode;
  begin
    APointerName := '';
    APointeeTypeName := '';
    AFieldName := '';
    AFieldIndex := -1;
    if (ALocalNode = nil) or (ALocalNode.NodeKind <> gnkDotAccess) or
      (ALocalNode.ChildCount < 2) then
      Exit(False);
    DerefNode := ALocalNode.ChildAt(0);
    FieldNode := ALocalNode.ChildAt(1);
    if (DerefNode = nil) or (DerefNode.NodeKind <> gnkDereference) or
      (DerefNode.ChildCount < 1) or (FieldNode = nil) or
      (FieldNode.NodeKind <> gnkIdentifier) then
      Exit(False);
    BaseNode := DerefNode.ChildAt(0);
    if (BaseNode = nil) or (BaseNode.NodeKind <> gnkIdentifier) then
      Exit(False);
    APointerName := BaseNode.Text;
    APointeeTypeName := LookupPointerVar(APointerName);
    if APointeeTypeName = '' then
      Exit(False);
    AFieldName := FieldNode.Text;
    AFieldIndex := TypeMetaFieldIndex(APointeeTypeName, AFieldName);
    Result := AFieldIndex >= 0;
  end;

  { 辅助：尝试创建结构化 int literal 表达式 }
  function TryEmitIntLiteral(Value: Int64): Boolean;
  var
    LId: LongInt;
  begin
    LId := FModel.AddHirExpr(
      shekIntLiteral, 0, 0, [], Value, 0.0, '', '', 0, shvcScalar);
    if LId > 0 then
    begin
      AExprId := LId;
      ABlob := 'expr ' + IntToStr(LId) + #10;
      Exit(True);
    end;
    Result := False;
  end;

  { 辅助：尝试创建结构化 string literal 表达式 }
  function TryEmitStringLiteral(const AText: string): Boolean;
  var
    LId: LongInt;
  begin
    LId := FModel.AddHirExpr(
      shekStringLiteral, 0, 0, [], 0, 0.0, AText, '', 0, shvcScalar);
    if LId > 0 then
    begin
      AExprId := LId;
      ABlob := 'expr ' + IntToStr(LId) + #10;
      Exit(True);
    end;
    Result := False;
  end;

  { 辅助：尝试创建结构化 nil literal 表达式 }
  function TryEmitNilLiteral: Boolean;
  var
    LId: LongInt;
  begin
    LId := FModel.AddHirExpr(
      shekNilLiteral, 0, 0, [], 0, 0.0, '', '', 0, shvcScalar);
    if LId > 0 then
    begin
      AExprId := LId;
      ABlob := 'expr ' + IntToStr(LId) + #10;
      Exit(True);
    end;
    Result := False;
  end;

  { 辅助：尝试创建结构化 exc_load intrinsic 表达式 }
  function TryEmitExcLoad: Boolean;
  var
    LId: LongInt;
  begin
    LId := FModel.AddHirExpr(
      shekIntrinsic, 0, 0, [], 0, 0.0, '', 'exc_load', 0, shvcScalar);
    if LId > 0 then
    begin
      AExprId := LId;
      ABlob := 'expr ' + IntToStr(LId) + #10;
      Exit(True);
    end;
    Result := False;
  end;

  { 辅助：尝试创建结构化 symbol value 表达式 }
  function TryEmitSymbolValue(const AName: string): Boolean;
  var
    LSymbolId, LTypeId, LId: LongInt;
  begin
    LSymbolId := FindSymbolByName(AName);
    if LSymbolId <= 0 then
      Exit(False);
    LTypeId := FModel.SymbolTypeId(LSymbolId);
    LId := FModel.AddHirExpr(
      shekSymbolValue, LTypeId, LSymbolId, [], 0, 0.0, '', '', 0, shvcScalar);
    if LId > 0 then
    begin
      AExprId := LId;
      ABlob := 'expr ' + IntToStr(LId) + #10;
      Exit(True);
    end;
    Result := False;
  end;

  { 辅助：尝试创建结构化 field self 表达式 }
  function TryEmitFieldSelf(AFieldIndex: Int64; AIsPtr: Boolean): Boolean;
  var
    LSelfId, LSelfTypeId, LFieldExprId, LId: LongInt;
    LPChildren: array of LongInt;
  begin
    LSelfId := FindSymbolByName('Self');
    if LSelfId <= 0 then
      Exit(False);
    LSelfTypeId := FModel.SymbolTypeId(LSelfId);
    LFieldExprId := FModel.AddHirExpr(
      shekSymbolValue, LSelfTypeId, LSelfId, [], 0, 0.0, '', '', 0, shvcAddress);
    if LFieldExprId <= 0 then
      Exit(False);
    SetLength(LPChildren, 1);
    LPChildren[0] := LFieldExprId;
    LId := FModel.AddHirExpr(
      shekField, 0, 0, LPChildren, AFieldIndex, 0.0, '', '', 0, shvcScalar);
    if LId > 0 then
    begin
      AExprId := LId;
      ABlob := 'expr ' + IntToStr(LId) + #10;
      Exit(True);
    end;
    Result := False;
  end;

var
  Folded: Int64;
  CharValue: LongInt;
  ExprId, StrExprId: LongInt;
  BaseName, OwnerClassName, FieldName, FuncName, ArgName, ReceiverVarName: string;
  StrCallIdx, StrCallArgCount, K, ArgIndex, DotPos: LongInt;
  BranchNode, DeclNode, RhsNode: TGreenNode;
  Operand: string;
begin
  ABlob := '';
  AExprId := 0;
  if ANode = nil then
    Exit(False);
  if EmitOwnedStringConcatLengthTemp(ANode, ABlob) then
    Exit(True);
  if EmitOwnedStringLengthTemp(ANode, ABlob) then
    Exit(True);
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'nil') then
  begin
    if TryEmitNilLiteral then
      Exit(True);
    ABlob := 'null' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'ExceptObject') then
  begin
    if TryEmitExcLoad then
      Exit(True);
    ABlob := 'exc_load' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and SameText(ANode.ChildAt(0).Text, 'ExceptObject') then
  begin
    if TryEmitExcLoad then
      Exit(True);
    ABlob := 'exc_load' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'True') then
  begin
    if TryEmitIntLiteral(1) then
      Exit(True);
    ABlob := 'int 1' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'False') then
  begin
    if TryEmitIntLiteral(0) then
      Exit(True);
    ABlob := 'int 0' + #10;
    Exit(True);
  end;
  if FNoFold and (ANode.NodeKind = gnkFunctionCall) and
    (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Assigned') and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    ABlob := 'assigned ' + ANode.ChildAt(1).Text + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkStringLiteral) then
  begin
    { 迁移到结构化表达式: Length('string') }
    { 创建字符串 literal 表达式 }
    StrExprId := FModel.AddHirExpr(
      shekStringLiteral,
      0, { TypeId }
      0, { SymbolId }
      [], { Children }
      0, { LiteralInt }
      0.0, { LiteralFloat }
      ANode.ChildAt(1).Text, { LiteralStr }
      '', { Op }
      0, { SourceOffset }
      shvcScalar { ValueClass }
    );
    if StrExprId > 0 then
    begin
      { 创建 Length 调用表达式 }
      ExprId := FModel.AddHirExpr(
        shekIntrinsic,
        0, { TypeId }
        0, { SymbolId }
        [StrExprId], { Children }
        0, { LiteralInt }
        0.0, { LiteralFloat }
        '', { LiteralStr }
        'strlen', { Op }
        0, { SourceOffset }
        shvcScalar { ValueClass }
      );
      if ExprId > 0 then
      begin
        AExprId := ExprId;
        ABlob := 'expr ' + IntToStr(ExprId) + #10;
        Exit(True);
      end;
    end;
    { Fallback }
    ABlob := 'strlit ' + ANode.ChildAt(1).Text + #10 + 'strlen' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    (IsRuntimeStrVar(ANode.ChildAt(1).Text) or
     IsRuntimeArrVar(ANode.ChildAt(1).Text)) then
  begin
    if LookupProcedureBody(ANode.ChildAt(1).Text, BranchNode, DeclNode) then
    begin
      Inc(FBlockLabelCounter);
      Operand := '$len_tmp_' + IntToStr(FBlockLabelCounter);
      RegisterRuntimeVar(Operand);
      RegisterRuntimeStrVar(Operand);
      FModel.AddTypedHirNode('var-decl-tstring-runtime', Operand, 0, 0, Operand);
      FModel.AddTypedHirNode(
        'assign-tstring-call-runtime', ANode.ChildAt(1).Text, 0, 0, Operand
      );
      ABlob := 'var ' + Operand + '$len' + #10;
    end
    else
      ABlob := 'var ' + ANode.ChildAt(1).Text + '$len' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    (FCurrentMethodClass <> '') and
    TypeMetaFieldIsStr(FCurrentMethodClass, ANode.ChildAt(1).Text) then
  begin
    Folded := TypeMetaFieldIndex(FCurrentMethodClass, ANode.ChildAt(1).Text);
    if TryEmitFieldSelf(Folded + 1, False) then
      Exit(True);
    ABlob := 'field self ' + IntToStr(Folded + 1) + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    (FCurrentMethodClass <> '') and
    TypeMetaFieldIsDynArray(FCurrentMethodClass, ANode.ChildAt(1).Text) then
  begin
    Folded := TypeMetaFieldIndex(FCurrentMethodClass, ANode.ChildAt(1).Text);
    if TryEmitFieldSelf(Folded + 1, False) then
      Exit(True);
    ABlob := 'field self ' + IntToStr(Folded + 1) + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkDotAccess) and
    (ANode.ChildAt(1).ChildCount >= 2) and
    (ANode.ChildAt(1).ChildAt(0) <> nil) and
    (ANode.ChildAt(1).ChildAt(1) <> nil) and
    (ANode.ChildAt(1).ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1).ChildAt(1).NodeKind = gnkIdentifier) and
    SameText(ANode.ChildAt(1).ChildAt(0).Text, 'Self') and
    (FCurrentMethodClass <> '') and
    TypeMetaFieldIsDynArray(FCurrentMethodClass,
      ANode.ChildAt(1).ChildAt(1).Text) then
  begin
    Folded := TypeMetaFieldIndex(FCurrentMethodClass,
      ANode.ChildAt(1).ChildAt(1).Text);
    if TryEmitFieldSelf(Folded + 1, False) then
      Exit(True);
    ABlob := 'field self ' + IntToStr(Folded + 1) + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 3) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    SameText(ANode.ChildAt(0).Text, 'Pos') then
  begin
    ABlob := '';
    if (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkStringLiteral) then
      ABlob := ABlob + 'strlit ' + ANode.ChildAt(1).Text + #10
    else if (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
      IsRuntimeStrVar(ANode.ChildAt(1).Text) then
      ABlob := ABlob + 'strvar ' + ANode.ChildAt(1).Text + #10;
    if (ANode.ChildAt(2) <> nil) and
      (ANode.ChildAt(2).NodeKind = gnkIdentifier) and
      IsRuntimeStrVar(ANode.ChildAt(2).Text) then
      ABlob := ABlob + 'strvar ' + ANode.ChildAt(2).Text + #10;
    if ABlob <> '' then
    begin
      ABlob := ABlob + 'strpos' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (SameText(ANode.ChildAt(0).Text, 'Ord') or
     SameText(ANode.ChildAt(0).Text, 'Chr') or
     SameText(ANode.ChildAt(0).Text, 'Abs') or
     SameText(ANode.ChildAt(0).Text, 'Pred') or
     SameText(ANode.ChildAt(0).Text, 'Succ')) then
  begin
    if (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkStringLiteral) and
      (Length(ANode.ChildAt(1).Text) = 3) and
      (ANode.ChildAt(1).Text[1] = '''') then
    begin
      CharValue := Ord(ANode.ChildAt(1).Text[2]);
      if TryEmitIntLiteral(CharValue) then
      begin
        if SameText(ANode.ChildAt(0).Text, 'Pred') then
          ABlob := ABlob + 'expr ' + IntToStr(AExprId) + #10 + 'int 1' + #10 + 'sub' + #10
        else if SameText(ANode.ChildAt(0).Text, 'Succ') then
          ABlob := ABlob + 'expr ' + IntToStr(AExprId) + #10 + 'int 1' + #10 + 'add' + #10
        else if SameText(ANode.ChildAt(0).Text, 'Abs') then
          ABlob := ABlob + 'abs' + #10;
        Exit(True);
      end;
      ABlob := 'int ' + IntToStr(CharValue) + #10;
      if SameText(ANode.ChildAt(0).Text, 'Pred') then
        ABlob := ABlob + 'int 1' + #10 + 'sub' + #10
      else if SameText(ANode.ChildAt(0).Text, 'Succ') then
        ABlob := ABlob + 'int 1' + #10 + 'add' + #10
      else if SameText(ANode.ChildAt(0).Text, 'Abs') then
        ABlob := ABlob + 'abs' + #10;
      Exit(True);
    end;
    if EncodeRuntimeIntExprFold(ANode.ChildAt(1), ABlob) then
    begin
      if SameText(ANode.ChildAt(0).Text, 'Pred') then
        ABlob := ABlob + 'int 1' + #10 + 'sub' + #10
      else if SameText(ANode.ChildAt(0).Text, 'Succ') then
        ABlob := ABlob + 'int 1' + #10 + 'add' + #10
      else if SameText(ANode.ChildAt(0).Text, 'Abs') then
        ABlob := ABlob + 'abs' + #10;
      Exit(True);
    end;
    if SameText(ANode.ChildAt(0).Text, 'Ord') and
      EncodeRuntimeBoolExprFold(ANode.ChildAt(1), ABlob) then
    begin
      ABlob := ABlob + 'zext' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) then
  begin
    ABlob := '';
    StrCallArgCount := 0;
    for StrCallIdx := 1 to ANode.ChildCount - 1 do
    begin
      if (ANode.ChildAt(StrCallIdx) <> nil) and
        (ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) and
        IsRuntimeStrVar(ANode.ChildAt(StrCallIdx).Text) then
      begin
        ABlob := ABlob + 'strvar ' + ANode.ChildAt(StrCallIdx).Text + #10;
        Inc(StrCallArgCount, 2);
      end
      else if (ANode.ChildAt(StrCallIdx) <> nil) and
        (ANode.ChildAt(StrCallIdx).NodeKind = gnkStringLiteral) then
      begin
        ABlob := ABlob + 'strlit ' + ANode.ChildAt(StrCallIdx).Text + #10;
        Inc(StrCallArgCount, 2);
      end
      else if (ANode.ChildAt(StrCallIdx) <> nil) and
        (ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) and
        IsRuntimeArrVar(ANode.ChildAt(StrCallIdx).Text) then
      begin
        ABlob := ABlob + 'arrvar ' + ANode.ChildAt(StrCallIdx).Text + #10;
        Inc(StrCallArgCount, 2);
      end
      else if EncodeRuntimeIntExprFold(ANode.ChildAt(StrCallIdx), FuncName) then
      begin
        ABlob := ABlob + FuncName;
        Inc(StrCallArgCount);
      end
      else
        Exit(False);
    end;
    if LookupProcedureBody(ANode.ChildAt(0).Text, BranchNode, DeclNode) and
      (DeclNode <> nil) then
    begin
      StrCallIdx := ANode.ChildCount - 1;
      for K := 0 to DeclNode.ChildCount - 1 do
      begin
        if (DeclNode.ChildAt(K) = nil) or
          (DeclNode.ChildAt(K).NodeKind <> gnkParameterList) then
          Continue;
        ArgIndex := 0;
        for DotPos := 0 to DeclNode.ChildAt(K).ChildCount - 1 do
        begin
          RhsNode := DeclNode.ChildAt(K).ChildAt(DotPos);
          if (RhsNode = nil) or (RhsNode.NodeKind <> gnkParameterDecl) then
            Continue;
          Inc(ArgIndex);
          if ArgIndex > StrCallIdx then
          begin
            if RhsNode.ChildCount > 1 then
            begin
              if EncodeRuntimeIntExprFold(
                RhsNode.ChildAt(RhsNode.ChildCount - 1), FuncName) then
              begin
                ABlob := ABlob + FuncName;
                Inc(StrCallArgCount);
              end;
            end;
          end;
        end;
        Break;
      end;
    end;
    if Pos('specialize ', ANode.ChildAt(0).Text) = 1 then
    begin
      ArgName := Copy(ANode.ChildAt(0).Text, 12, Length(ANode.ChildAt(0).Text) - 11);
      DotPos := Pos('<', ArgName);
      if DotPos > 0 then
      begin
        FuncName := Copy(ArgName, 1, DotPos - 1);
        Operand := Copy(ArgName, DotPos + 1, Pos('>', ArgName) - DotPos - 1);
        K := Pos('.', FuncName);
        if K > 0 then
        begin
          ArgName := LookupClassVar(Copy(FuncName, 1, K - 1));
          if ArgName <> '' then
            FuncName := ArgName + '.' + Copy(FuncName, K + 1, Length(FuncName) - K);
          ArgName := FuncName + '$' + StringReplace(StringReplace(Operand, ', ', '$', True), ',', '$', True);
          if not LookupProcedureBody(ArgName, BranchNode, DeclNode) then
          begin
            for K := 0 to LongInt(FProcedureBodies.Count) - 1 do
              if (Pos(FuncName + '<', FProcedureBodies[K].Name) = 1) then
              begin
                RegisterProcedureBody(ArgName,
                  FProcedureBodies[K].Body, FProcedureBodies[K].Decl,
                  FProcedureBodies[K].OwnerUnitId);
                FGenericWorkQueue.Push(LongInt(FProcedureBodies.Count) - 1);
                Break;
              end;
          end;
          Operand := Copy(Copy(ANode.ChildAt(0).Text, 12, Length(ANode.ChildAt(0).Text) - 11), 1, Pos('.', Copy(ANode.ChildAt(0).Text, 12, Length(ANode.ChildAt(0).Text) - 11)) - 1);
          ABlob := 'var ' + Operand + #10 + ABlob +
            'call ' + ArgName + ' ' + IntToStr(StrCallArgCount + 1) + #10;
        end
        else
        begin
          ArgName := FuncName + '$' + StringReplace(StringReplace(Operand, ', ', '$', True), ',', '$', True);
          if not LookupProcedureBody(ArgName, BranchNode, DeclNode) then
          begin
            for K := 0 to LongInt(FProcedureBodies.Count) - 1 do
              if (Pos(FuncName + '<', FProcedureBodies[K].Name) = 1) then
              begin
                RegisterProcedureBody(ArgName,
                  FProcedureBodies[K].Body, FProcedureBodies[K].Decl,
                  FProcedureBodies[K].OwnerUnitId);
                FGenericWorkQueue.Push(LongInt(FProcedureBodies.Count) - 1);
                Break;
              end;
          end;
          ABlob := ABlob + 'call ' + ArgName + ' ' +
            IntToStr(StrCallArgCount) + #10;
        end;
      end
      else
        ABlob := ABlob + 'call ' + ArgName + ' ' +
          IntToStr(StrCallArgCount) + #10;
    end
    else if (TypeMetaSize(ANode.ChildAt(0).Text) > 0) and
      (LookupClassVar(ANode.ChildAt(0).Text) = '') and
      (ANode.ChildCount = 2) then
    begin
      ABlob := ABlob;
      Exit(True);
    end
    else if HasOverload(ANode.ChildAt(0).Text) then
    begin
      ArgName := '';
      for StrCallIdx := 1 to ANode.ChildCount - 1 do
      begin
        if (ANode.ChildAt(StrCallIdx) <> nil) and
          ((ANode.ChildAt(StrCallIdx).NodeKind = gnkStringLiteral) or
           ((ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) and
            IsRuntimeStrVar(ANode.ChildAt(StrCallIdx).Text))) then
          ArgName := ArgName + 's'
        else
          ArgName := ArgName + 'i';
      end;
      ABlob := ABlob + 'call ' + MangledNameSig(ANode.ChildAt(0).Text, ArgName) +
        ' ' + IntToStr(StrCallArgCount) + #10;
    end
    else if (FCurrentMethodClass <> '') and
      (Pos('inherited ', ANode.ChildAt(0).Text) = 1) then
    begin
      ArgName := Copy(ANode.ChildAt(0).Text, 12, Length(ANode.ChildAt(0).Text) - 11);
      FuncName := NextClassAncestorName(FCurrentMethodClass);
      if FuncName <> '' then
        ABlob := 'var self' + #10 + ABlob +
          'call ' + FuncName + '.' + ArgName +
          ' ' + IntToStr(StrCallArgCount + 1) + #10
      else
        ABlob := ABlob + 'call ' + ANode.ChildAt(0).Text + ' ' +
          IntToStr(StrCallArgCount) + #10;
    end
    else if (FCurrentMethodClass <> '') then
    begin
      FuncName := FCurrentMethodClass;
      while (FuncName <> '') and
        (FModel.FindSymbolByName(FuncName + '.' + ANode.ChildAt(0).Text) = 0) do
        FuncName := NextClassAncestorName(FuncName);
      if FuncName <> '' then
      begin
        Folded := TypeMetaVmtSlot(FCurrentMethodClass, ANode.ChildAt(0).Text);
        if Folded >= 0 then
          ABlob := 'var self' + #10 + ABlob +
            'vcall ' + IntToStr(Folded) + ' ' + IntToStr(StrCallArgCount) + #10
        else
          ABlob := 'var self' + #10 + ABlob +
            'call ' + FuncName + '.' + ANode.ChildAt(0).Text +
            ' ' + IntToStr(StrCallArgCount + 1) + #10;
      end
      else
        ABlob := ABlob + 'call ' + ANode.ChildAt(0).Text + ' ' +
          IntToStr(StrCallArgCount) + #10;
    end
    else
      ABlob := ABlob + 'call ' + ANode.ChildAt(0).Text + ' ' +
        IntToStr(StrCallArgCount) + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkDotAccess) and
    (ANode.ChildAt(0).ChildCount >= 2) and
    (ANode.ChildAt(0).ChildAt(0) <> nil) and
    (ANode.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(0).ChildAt(1) <> nil) and
    (ANode.ChildAt(0).ChildAt(1).NodeKind = gnkIdentifier) and
    (TypeMetaSize(ANode.ChildAt(0).ChildAt(0).Text) > 0) and
    (LookupClassVar(ANode.ChildAt(0).ChildAt(0).Text) = '') then
  begin
    Inc(FBlockLabelCounter);
    FuncName := '$new_tmp_' + IntToStr(FBlockLabelCounter);
    Folded := TypeMetaSize(ANode.ChildAt(0).ChildAt(0).Text);
    ArgName := FuncName + #9 +
      ANode.ChildAt(0).ChildAt(0).Text + '.' +
      ANode.ChildAt(0).ChildAt(1).Text;
    for StrCallIdx := 1 to ANode.ChildCount - 1 do
      if (ANode.ChildAt(StrCallIdx) <> nil) and
        EncodeRuntimeIntExprFold(ANode.ChildAt(StrCallIdx), Operand) then
        ArgName := ArgName + #9 + Operand;
    RegisterRuntimeVar(FuncName);
    RegisterClassVar(FuncName, ANode.ChildAt(0).ChildAt(0).Text);
    FModel.AddTypedHirNode(
      'class-new-runtime', IntToStr(Folded), 0, 0, ArgName);
    if (TypeMetaVmtCount(ANode.ChildAt(0).ChildAt(0).Text) > 0) or
      (TypeMetaInterfaces(ANode.ChildAt(0).ChildAt(0).Text) <> '') then
      FModel.AddTypedHirNode('vmt-store-runtime',
        ANode.ChildAt(0).ChildAt(0).Text, 0, 0,
        FuncName + #9 + ANode.ChildAt(0).ChildAt(0).Text);
    ABlob := 'var ' + FuncName + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkDotAccess) and
    (ANode.ChildAt(0).ChildCount >= 2) and
    (ANode.ChildAt(0).ChildAt(0) <> nil) and
    (ANode.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(0).ChildAt(1) <> nil) and
    (ANode.ChildAt(0).ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    ReceiverVarName := ANode.ChildAt(0).ChildAt(0).Text;
    if SameText(ReceiverVarName, 'Self') and (FCurrentMethodClass <> '') then
    begin
      ReceiverVarName := 'self';
      FuncName := FCurrentMethodClass;
    end
    else
      FuncName := LookupClassVar(ReceiverVarName);
    if FuncName <> '' then
    begin
      ABlob := '';
      StrCallArgCount := 0;
      for StrCallIdx := 1 to ANode.ChildCount - 1 do
      begin
        if ANode.ChildAt(StrCallIdx) = nil then
          Continue;
        if (ANode.ChildAt(StrCallIdx).NodeKind = gnkStringLiteral) then
        begin
          Inc(FBlockLabelCounter);
          ArgName := '$str_arg_' + IntToStr(FBlockLabelCounter);
          RegisterRuntimeVar(ArgName);
          RegisterRuntimeStrVar(ArgName);
          FModel.AddTypedHirNode('var-decl-tstring-runtime', ArgName, 0, 0, ArgName);
          FModel.AddTypedHirNode('assign-tstring-literal-runtime',
            ArgName, 0, 0,
            DecodePascalStringLiteral(ANode.ChildAt(StrCallIdx).Text));
          ABlob := ABlob + 'strvar ' + ArgName + #10;
          Inc(StrCallArgCount, 2);
        end
        else if (ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) and
          IsRuntimeStrVar(ANode.ChildAt(StrCallIdx).Text) then
        begin
          ABlob := ABlob + 'strvar ' + ANode.ChildAt(StrCallIdx).Text + #10;
          Inc(StrCallArgCount, 2);
        end
        else if EncodeRuntimeIntExprFold(ANode.ChildAt(StrCallIdx), ArgName) then
        begin
          ABlob := ABlob + ArgName;
          Inc(StrCallArgCount);
        end;
      end;
      Folded := TypeMetaVmtSlot(FuncName, ANode.ChildAt(0).ChildAt(1).Text);
      if Folded >= 0 then
      begin
        if TypeMetaIsInterface(FuncName) then
          ABlob := 'var ' + ReceiverVarName + #10 +
            ABlob + 'ivcall ' + IntToStr(Folded) + ' ' +
            IntToStr(StrCallArgCount)
        else
          ABlob := 'var ' + ReceiverVarName + #10 +
            ABlob + 'vcall ' + IntToStr(Folded) + ' ' +
            IntToStr(StrCallArgCount);
        if TypeMetaRetPtr(FuncName, ANode.ChildAt(0).ChildAt(1).Text) then
          ABlob := ABlob + ' p' + #10
        else
          ABlob := ABlob + #10;
      end
      else
      begin
        ArgName := FuncName;
        while (ArgName <> '') and
          (FModel.FindSymbolByName(ArgName + '.' +
            ANode.ChildAt(0).ChildAt(1).Text) = 0) do
          ArgName := NextClassAncestorName(ArgName);
        if ArgName = '' then ArgName := FuncName;
        ABlob := 'var ' + ReceiverVarName + #10 +
          ABlob + 'call ' + ArgName + '.' +
          ANode.ChildAt(0).ChildAt(1).Text + ' ' +
          IntToStr(StrCallArgCount + 1) + #10;
      end;
      Exit(True);
    end;
  end;
  if NeedsFoldFallback(ANode) then
  begin
    if (not FNoFold) or
      ((ANode.NodeKind = gnkIdentifier) and
       FModel.LookupConstValue(ANode.Text, Folded)) then
      if EvaluateIntegerConstant(ANode, Folded) then
      begin
        if TryEmitIntLiteral(Folded) then
          Exit(True);
        ABlob := 'int ' + IntToStr(Folded) + #10;
        Exit(True);
      end;
  end;
  if (FCurrentMethodClass <> '') and (ANode.NodeKind = gnkIdentifier) and
    (ANode.Text <> '') and
    (TypeMetaFieldIndex(FCurrentMethodClass, ANode.Text) >= 0) then
  begin
    Folded := TypeMetaFieldIndex(FCurrentMethodClass, ANode.Text);
    if TryEmitFieldSelf(Folded, TypeMetaFieldIsPtr(FCurrentMethodClass, ANode.Text)) then
      Exit(True);
    ABlob := 'field self ' + IntToStr(Folded);
    if TypeMetaFieldIsPtr(FCurrentMethodClass, ANode.Text) then
      ABlob := ABlob + ' p' + #10
    else
      ABlob := ABlob + #10;
    Exit(True);
  end;
  if (FCurrentMethodClass <> '') and (ANode.NodeKind = gnkDotAccess) and
    (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    TypeMetaFieldIsPtr(FCurrentMethodClass, ANode.ChildAt(0).Text) and
    (TypeMetaFieldIndex(FCurrentMethodClass, ANode.ChildAt(0).Text) >= 0) then
  begin
    Folded := TypeMetaFieldIndex(FCurrentMethodClass, ANode.ChildAt(0).Text);
    FuncName := '';
    for StrCallIdx := 1 to FModel.SymbolCount do
      if SameText(FModel.SymbolAt(StrCallIdx).Name, ANode.ChildAt(0).Text) and
        SameText(FModel.SymbolAt(StrCallIdx).Kind, 'field') then
      begin
        if FModel.SymbolAt(StrCallIdx).TypeId > 0 then
          FuncName := FModel.TypeAt(
            FModel.SymbolAt(StrCallIdx).TypeId - 1).Name;
        Break;
      end;
    if (FuncName <> '') and
      (TypeMetaFieldIndex(FuncName, ANode.ChildAt(1).Text) >= 0) then
    begin
      StrCallIdx := LongInt(TypeMetaFieldIndex(FuncName, ANode.ChildAt(1).Text));
      if TypeMetaFieldIsPtr(FuncName, ANode.ChildAt(1).Text) then
        ABlob := 'field self ' + IntToStr(Folded) + ' p' + #10 +
          'int ' + IntToStr(StrCallIdx) + #10 + 'arr_load_ptr' + #10
      else
        ABlob := 'field self ' + IntToStr(Folded) + ' p' + #10 +
          'int ' + IntToStr(StrCallIdx) + #10 + 'arr_load' + #10;
      Exit(True);
    end;
  end;
  if (FCurrentMethodClass <> '') and (ANode.NodeKind = gnkDotAccess) and
    (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    (TypeMetaFieldIndex(FCurrentMethodClass + '.' + ANode.ChildAt(0).Text,
      ANode.ChildAt(1).Text) >= 0) then
  begin
    Folded := TypeMetaFieldIndex(FCurrentMethodClass + '.' + ANode.ChildAt(0).Text,
      ANode.ChildAt(1).Text);
    if TryEmitFieldSelf(Folded, False) then
      Exit(True);
    ABlob := 'field self ' + IntToStr(Folded) + #10;
    Exit(True);
  end;
  if (FCurrentMethodClass <> '') and (ANode.NodeKind = gnkIdentifier) and
    (Pos('inherited ', ANode.Text) = 1) then
  begin
    ArgName := Copy(ANode.Text, 11, Length(ANode.Text));
    FuncName := NextClassAncestorName(FCurrentMethodClass);
    if FuncName <> '' then
    begin
      ABlob := 'var self' + #10 +
        'call ' + FuncName + '.' + ArgName + ' 1' + #10;
      Exit(True);
    end;
  end;
  if (FCurrentMethodClass <> '') and (ANode.NodeKind = gnkIdentifier) and
    (ANode.Text <> '') then
  begin
    FuncName := FCurrentMethodClass;
    while (FuncName <> '') and
      (FModel.FindSymbolByName(FuncName + '.' + ANode.Text) = 0) do
      FuncName := NextClassAncestorName(FuncName);
    if FuncName <> '' then
    begin
      Folded := TypeMetaVmtSlot(FCurrentMethodClass, ANode.Text);
      if Folded >= 0 then
      begin
        ABlob := 'var self' + #10 + 'vcall ' + IntToStr(Folded) + ' 0';
        if TypeMetaRetPtr(FCurrentMethodClass, ANode.Text) then
          ABlob := ABlob + ' p' + #10
        else
          ABlob := ABlob + #10;
      end
      else
        ABlob := 'var self' + #10 +
          'call ' + FuncName + '.' + ANode.Text + ' 1' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkDotAccess) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    EncodeRuntimeIntExprFold(ANode.ChildAt(0), FuncName) then
  begin
    if Pos(' p' + #10, FuncName) > 0 then
    begin
      ArgName := '';
      for StrCallIdx := 1 to FModel.SymbolCount do
        if SameText(FModel.SymbolAt(StrCallIdx).Name,
          ANode.ChildAt(0).ChildAt(1).Text) and
          SameText(FModel.SymbolAt(StrCallIdx).Kind, 'field') then
        begin
          if FModel.SymbolAt(StrCallIdx).TypeId > 0 then
            ArgName := FModel.TypeAt(
              FModel.SymbolAt(StrCallIdx).TypeId - 1).Name;
          Break;
        end;
      if ArgName <> '' then
      begin
        Folded := TypeMetaVmtSlot(ArgName, ANode.ChildAt(1).Text);
        if Folded >= 0 then
        begin
          ABlob := FuncName + 'vcall ' + IntToStr(Folded) + ' 0';
          if TypeMetaRetPtr(ArgName, ANode.ChildAt(1).Text) then
            ABlob := ABlob + ' p' + #10
          else
            ABlob := ABlob + #10;
          Exit(True);
        end;
        Folded := TypeMetaFieldIndex(ArgName, ANode.ChildAt(1).Text);
        if Folded >= 0 then
        begin
          ABlob := FuncName + 'int ' + IntToStr(Folded) + #10;
          if TypeMetaFieldIsPtr(ArgName, ANode.ChildAt(1).Text) then
            ABlob := ABlob + 'arr_load_ptr' + #10
          else
            ABlob := ABlob + 'arr_load' + #10;
          Exit(True);
        end;
      end;
    end;
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkArrayAccess) and
    (ANode.ChildAt(0).ChildCount >= 2) and
    (ANode.ChildAt(0).ChildAt(0) <> nil) and
    (ANode.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    IsRuntimeArrVar(ANode.ChildAt(0).ChildAt(0).Text) then
  begin
    FuncName := '';
    if FModel.LookupStringConstValue(
      ANode.ChildAt(0).ChildAt(0).Text + '$arr_elem_type', FuncName) then
    begin end;
    if (FuncName = '') and
      (TypeMetaSize(ANode.ChildAt(0).ChildAt(0).Text) > 0) then
      FuncName := ANode.ChildAt(0).ChildAt(0).Text;
    if FuncName <> '' then
    begin
      Folded := TypeMetaVmtSlot(FuncName, ANode.ChildAt(1).Text);
      if (Folded >= 0) and
        EncodeRuntimeIntExprFold(ANode.ChildAt(0).ChildAt(1), ArgName) then
      begin
        ABlob := ArgName + 'arrload ' + ANode.ChildAt(0).ChildAt(0).Text +
          ' p' + #10 + 'vcall ' + IntToStr(Folded) + ' 0';
        if TypeMetaRetPtr(FuncName, ANode.ChildAt(1).Text) then
          ABlob := ABlob + ' p' + #10
        else
          ABlob := ABlob + #10;
        Exit(True);
      end;
      Folded := TypeMetaFieldIndex(FuncName, ANode.ChildAt(1).Text);
      if (Folded >= 0) and
        EncodeRuntimeIntExprFold(ANode.ChildAt(0).ChildAt(1), ArgName) then
      begin
        ABlob := ArgName + 'arrload ' + ANode.ChildAt(0).ChildAt(0).Text +
          ' p' + #10 + 'int ' + IntToStr(Folded) + #10 + 'arr_load' + #10;
        Exit(True);
      end;
    end;
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkArrayAccess) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    TryClassFieldArrayAccess(ANode.ChildAt(0), BaseName, OwnerClassName,
      FieldName) and
    FModel.LookupStringConstValue(
      OwnerClassName + '.' + FieldName + '$arr_elem_type', ArgName) then
  begin
    Folded := TypeMetaFieldIndex(ArgName, ANode.ChildAt(1).Text);
    if (Folded >= 0) and
      EncodeRuntimeIntExprFold(ANode.ChildAt(0).ChildAt(1), Operand) then
    begin
      StrCallIdx := TypeMetaFieldIndex(OwnerClassName, FieldName);
      if StrCallIdx < 0 then
        Exit(False);
      ABlob := 'field ' + BaseName + ' ' + IntToStr(StrCallIdx) +
        ' p' + #10 + Operand;
      StrCallIdx := 1;
      if TypeMetaIsRecord(ArgName) then
      begin
        StrCallIdx := TypeMetaSize(ArgName) div 8;
        if StrCallIdx <= 0 then
          Exit(False);
      end;
      if StrCallIdx > 1 then
        ABlob := ABlob + 'int ' + IntToStr(StrCallIdx) + #10 + 'mul' + #10;
      ABlob := ABlob + 'int ' + IntToStr(Folded) + #10 + 'add' + #10;
      if TypeMetaFieldIsPtr(ArgName, ANode.ChildAt(1).Text) then
        ABlob := ABlob + 'arr_load_ptr' + #10
      else
        ABlob := ABlob + 'arr_load' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    ReceiverVarName := ANode.ChildAt(0).Text;
    if SameText(ReceiverVarName, 'Self') and (FCurrentMethodClass <> '') then
    begin
      ReceiverVarName := 'self';
      FuncName := FCurrentMethodClass;
    end
    else
      FuncName := LookupClassVar(ReceiverVarName);
    if (FuncName = '') and (FCurrentMethodClass <> '') and
      TypeMetaFieldIsPtr(FCurrentMethodClass, ANode.ChildAt(0).Text) and
      (TypeMetaFieldIndex(FCurrentMethodClass, ANode.ChildAt(0).Text) >= 0) then
    begin
      Folded := TypeMetaFieldIndex(FCurrentMethodClass, ANode.ChildAt(0).Text);
      ArgName := 'field self ' + IntToStr(Folded) + ' p' + #10;
      FuncName := '';
      for StrCallIdx := 1 to FModel.SymbolCount do
        if (FModel.SymbolAt(StrCallIdx).Name = ANode.ChildAt(0).Text) and
          (FModel.SymbolAt(StrCallIdx).Kind = 'field') then
        begin
          if FModel.SymbolAt(StrCallIdx).TypeId > 0 then
            FuncName := FModel.TypeAt(
              FModel.SymbolAt(StrCallIdx).TypeId - 1).Name;
          Break;
        end;
      if FuncName <> '' then
      begin
        Folded := TypeMetaVmtSlot(FuncName, ANode.ChildAt(1).Text);
        if Folded >= 0 then
        begin
          ABlob := ArgName + 'vcall ' + IntToStr(Folded) + ' 0';
          if TypeMetaRetPtr(FuncName, ANode.ChildAt(1).Text) then
            ABlob := ABlob + ' p' + #10
          else
            ABlob := ABlob + #10;
        end
        else
          ABlob := ArgName +
            'call ' + FuncName + '.' + ANode.ChildAt(1).Text + ' 1' + #10;
        Exit(True);
      end;
      FuncName := '';
    end;
    if FuncName <> '' then
    begin
      if FModel.LookupStringConstValue(
        FuncName + '.' + ANode.ChildAt(1).Text + '$read', ArgName) then
        ABlob := 'var ' + ReceiverVarName + #10 +
          'call ' + FuncName + '.' + ArgName + ' 1' + #10
      else
      begin
        Folded := TypeMetaFieldIndex(FuncName, ANode.ChildAt(1).Text);
        if Folded >= 0 then
        begin
          ABlob := 'field ' + ReceiverVarName + ' ' + IntToStr(Folded);
          if TypeMetaFieldIsPtr(FuncName, ANode.ChildAt(1).Text) then
            ABlob := ABlob + ' p' + #10
          else
            ABlob := ABlob + #10;
        end
        else
        begin
          Folded := TypeMetaVmtSlot(FuncName, ANode.ChildAt(1).Text);
          if Folded >= 0 then
          begin
            if TypeMetaIsInterface(FuncName) then
              ABlob := 'var ' + ReceiverVarName + #10 +
                'ivcall ' + IntToStr(Folded) + ' 0'
            else
              ABlob := 'var ' + ReceiverVarName + #10 +
                'vcall ' + IntToStr(Folded) + ' 0';
            if TypeMetaRetPtr(FuncName, ANode.ChildAt(1).Text) then
              ABlob := ABlob + ' p' + #10
            else
              ABlob := ABlob + #10;
          end
          else
          begin
            ArgName := FuncName;
            while (ArgName <> '') and
              (FModel.FindSymbolByName(ArgName + '.' + ANode.ChildAt(1).Text) = 0) do
              ArgName := NextClassAncestorName(ArgName);
            if ArgName = '' then ArgName := FuncName;
            ABlob := 'var ' + ReceiverVarName + #10 +
              'call ' + ArgName + '.' + ANode.ChildAt(1).Text + ' 1' + #10;
          end;
        end;
      end;
      Exit(True);
    end;
  end;
  if TryPointerFieldAccess(ANode, FuncName, ArgName, Operand, Folded) then
  begin
    ABlob := 'var ' + FuncName + #10 + 'int ' + IntToStr(Folded) + #10;
    if TypeMetaFieldIsPtr(ArgName, Operand) then
      ABlob := ABlob + 'arr_load_ptr' + #10
    else
      ABlob := ABlob + 'arr_load' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and
    SameText(ANode.Text, 'as') and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(0), ABlob) then
      Exit(True);
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and
    (ANode.ChildCount >= 2) then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(0), FuncName) and
      EncodeRuntimeIntExprFold(ANode.ChildAt(1), ArgName) then
    begin
      if ANode.Text = '+' then
        ABlob := FuncName + ArgName + 'add' + #10
      else if ANode.Text = '-' then
        ABlob := FuncName + ArgName + 'sub' + #10
      else if ANode.Text = '*' then
        ABlob := FuncName + ArgName + 'mul' + #10
      else if SameText(ANode.Text, 'div') then
        ABlob := FuncName + ArgName + 'div' + #10
      else if SameText(ANode.Text, 'mod') then
        ABlob := FuncName + ArgName + 'mod' + #10
      else
      begin
        Result := EncodeRuntimeIntExpr(ANode, ABlob);
        Exit;
      end;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkUnaryExpression) and
    (ANode.ChildCount >= 1) and (ANode.Text = '-') then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(0), FuncName) then
    begin
      ABlob := FuncName + 'neg' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkUnaryExpression) and
    (ANode.ChildCount >= 1) and (ANode.Text = '@') then
  begin
    if TryPointerFieldAccess(ANode.ChildAt(0), FuncName, ArgName, Operand,
      Folded) then
    begin
      ABlob := 'var ' + FuncName + #10 + 'field_ref ' +
        IntToStr(Folded) + #10;
      Exit(True);
    end;
    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
      IsRuntimeVar(ANode.ChildAt(0).Text) then
    begin
      ABlob := 'varref ' + ANode.ChildAt(0).Text + #10;
      Exit(True);
    end;
    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkArrayAccess) and
      (ANode.ChildAt(0).ChildCount >= 2) and
      (ANode.ChildAt(0).ChildAt(0) <> nil) and
      (ANode.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
      IsRuntimeArrVar(ANode.ChildAt(0).ChildAt(0).Text) and
      EncodeRuntimeIntExprFold(ANode.ChildAt(0).ChildAt(1), FuncName) then
    begin
      ABlob := FuncName + 'arr_elem_ref ' +
        ANode.ChildAt(0).ChildAt(0).Text + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkDereference) and (ANode.ChildCount >= 1) then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(0), FuncName) then
    begin
      ABlob := FuncName + 'deref' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkIdentifier) and (ANode.Text = 'Result') and
    (FCurrentRetVarName <> '') then
  begin
    ABlob := 'var ' + FCurrentRetVarName + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and (ANode.Text <> '') and
    IsRecordVar(ANode.Text) then
  begin
    ABlob := 'recvar ' + ANode.Text + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkArrayAccess) and
    (ANode.ChildAt(0).ChildCount >= 2) and
    (ANode.ChildAt(0).ChildAt(0) <> nil) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    IsRuntimeArrVar(ANode.ChildAt(0).ChildAt(0).Text) and
    FModel.LookupStringConstValue(
      ANode.ChildAt(0).ChildAt(0).Text + '$arr_elem_type', FuncName) then
  begin
    Folded := TypeMetaFieldIndex(FuncName, ANode.ChildAt(1).Text);
    if Folded >= 0 then
    begin
      StrCallIdx := LongInt(Folded);
      if FModel.LookupConstValue(
        ANode.ChildAt(0).ChildAt(0).Text + '$arr_elem_size', Folded) and
        EncodeRuntimeIntExprFold(ANode.ChildAt(0).ChildAt(1), ArgName) then
      begin
        ABlob := 'var ' + ANode.ChildAt(0).ChildAt(0).Text + '$ptr' + #10 +
          ArgName + 'int ' + IntToStr(Folded div 8) + #10 + 'mul' + #10 +
          'int ' + IntToStr(StrCallIdx) + #10 + 'add' + #10 + 'arr_load' + #10;
        Exit(True);
      end;
    end;
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    IsRecordVar(ANode.ChildAt(0).Text) then
  begin
    FuncName := LookupRecordVar(ANode.ChildAt(0).Text);
    Folded := -1;
    if FuncName <> '' then
      Folded := TypeMetaFieldIndex(FuncName, ANode.ChildAt(1).Text);
    if Folded >= 0 then
    begin
      ABlob := 'rload ' + ANode.ChildAt(0).Text + ' ' +
        IntToStr(Folded) + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkArrayAccess) and (ANode.ChildCount >= 2) and
    TryClassFieldArrayAccess(ANode, BaseName, OwnerClassName, FieldName) then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(1), FuncName) then
    begin
      Folded := TypeMetaFieldIndex(OwnerClassName, FieldName);
      ABlob := 'field ' + BaseName + ' ' + IntToStr(Folded) + ' p' + #10 +
        FuncName + 'arr_load' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkArrayAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    IsRuntimeStrVar(ANode.ChildAt(0).Text) then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(1), FuncName) then
    begin
      ABlob := FuncName + 'strcharload ' + ANode.ChildAt(0).Text + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkArrayAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    IsRuntimeArrVar(ANode.ChildAt(0).Text) then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(1), FuncName) then
    begin
      ABlob := FuncName + 'arrload ' + ANode.ChildAt(0).Text + #10;
      Exit(True);
    end;
  end;
  Result := EncodeRuntimeIntExpr(ANode, ABlob);
end;

