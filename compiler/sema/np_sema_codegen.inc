function TSemanticAnalyzer.EncodeRuntimeIntExprFold(
  const ANode: TGreenNode; out ABlob: string): Boolean;

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
  if ANode = nil then
    Exit(False);
  if EmitOwnedStringConcatLengthTemp(ANode, ABlob) then
    Exit(True);
  if EmitOwnedStringLengthTemp(ANode, ABlob) then
    Exit(True);
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'nil') then
  begin
    { 迁移到结构化表达式: nil }
    ExprId := FModel.AddHirExpr(
      shekNilLiteral,
      0, { TypeId }
      0, { SymbolId }
      [], { Children }
      0, { LiteralInt }
      0.0, { LiteralFloat }
      '', { LiteralStr }
      '', { Op }
      0, { SourceOffset }
      shvcScalar { ValueClass }
    );
    if ExprId > 0 then
    begin
      ABlob := 'expr ' + IntToStr(ExprId) + #10;
      Exit(True);
    end;
    { Fallback }
    ABlob := 'null' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'ExceptObject') then
  begin
    ABlob := 'exc_load' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and SameText(ANode.ChildAt(0).Text, 'ExceptObject') then
  begin
    ABlob := 'exc_load' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'True') then
  begin
    { 迁移到结构化表达式: True -> int 1 }
    ExprId := FModel.AddHirExpr(
      shekIntLiteral,
      0, { TypeId }
      0, { SymbolId }
      [], { Children }
      1, { LiteralInt: True = 1 }
      0.0, { LiteralFloat }
      '', { LiteralStr }
      '', { Op }
      0, { SourceOffset }
      shvcScalar { ValueClass }
    );
    if ExprId > 0 then
    begin
      ABlob := 'expr ' + IntToStr(ExprId) + #10;
      Exit(True);
    end;
    { Fallback }
    ABlob := 'int 1' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'False') then
  begin
    { 迁移到结构化表达式: False -> int 0 }
    ExprId := FModel.AddHirExpr(
      shekIntLiteral,
      0, { TypeId }
      0, { SymbolId }
      [], { Children }
      0, { LiteralInt: False = 0 }
      0.0, { LiteralFloat }
      '', { LiteralStr }
      '', { Op }
      0, { SourceOffset }
      shvcScalar { ValueClass }
    );
    if ExprId > 0 then
    begin
      ABlob := 'expr ' + IntToStr(ExprId) + #10;
      Exit(True);
    end;
    { Fallback }
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
      { 迁移到结构化表达式: char literal }
      CharValue := Ord(ANode.ChildAt(1).Text[2]);
      ExprId := FModel.AddHirExpr(
        shekIntLiteral,
        0, { TypeId }
        0, { SymbolId }
        [], { Children }
        CharValue, { LiteralInt }
        0.0, { LiteralFloat }
        '', { LiteralStr }
        '', { Op }
        0, { SourceOffset }
        shvcScalar { ValueClass }
      );
      if ExprId > 0 then
      begin
        ABlob := 'expr ' + IntToStr(ExprId) + #10;
        if SameText(ANode.ChildAt(0).Text, 'Pred') then
          ABlob := ABlob + 'expr ' + IntToStr(ExprId) + #10 + 'int 1' + #10 + 'sub' + #10
        else if SameText(ANode.ChildAt(0).Text, 'Succ') then
          ABlob := ABlob + 'expr ' + IntToStr(ExprId) + #10 + 'int 1' + #10 + 'add' + #10
        else if SameText(ANode.ChildAt(0).Text, 'Abs') then
          ABlob := ABlob + 'abs' + #10;
        Exit(True);
      end;
      { Fallback }
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
            for K := 0 to Length(FProcedureBodies) - 1 do
              if (Pos(FuncName + '<', FProcedureBodies[K].Name) = 1) then
              begin
                RegisterProcedureBody(ArgName,
                  FProcedureBodies[K].Body, FProcedureBodies[K].Decl,
                  FProcedureBodies[K].OwnerUnitId);
                if FGenericWorkCount >= Length(FGenericWorkQueue) then
                  SetLength(FGenericWorkQueue, FGenericWorkCount + 64);
                FGenericWorkQueue[FGenericWorkCount] := Length(FProcedureBodies) - 1;
                Inc(FGenericWorkCount);
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
            for K := 0 to Length(FProcedureBodies) - 1 do
              if (Pos(FuncName + '<', FProcedureBodies[K].Name) = 1) then
              begin
                RegisterProcedureBody(ArgName,
                  FProcedureBodies[K].Body, FProcedureBodies[K].Decl,
                  FProcedureBodies[K].OwnerUnitId);
                if FGenericWorkCount >= Length(FGenericWorkQueue) then
                  SetLength(FGenericWorkQueue, FGenericWorkCount + 64);
                FGenericWorkQueue[FGenericWorkCount] := Length(FProcedureBodies) - 1;
                Inc(FGenericWorkCount);
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
        { 迁移到结构化表达式: 常量整数 }
        ExprId := FModel.AddHirExpr(
          shekIntLiteral,
          0, { TypeId }
          0, { SymbolId }
          [], { Children }
          Folded, { LiteralInt }
          0.0, { LiteralFloat }
          '', { LiteralStr }
          '', { Op }
          0, { SourceOffset }
          shvcScalar { ValueClass }
        );
        if ExprId > 0 then
        begin
          ABlob := 'expr ' + IntToStr(ExprId) + #10;
          Exit(True);
        end;
        { Fallback }
        ABlob := 'int ' + IntToStr(Folded) + #10;
        Exit(True);
      end;
  end;
  if (FCurrentMethodClass <> '') and (ANode.NodeKind = gnkIdentifier) and
    (ANode.Text <> '') and
    (TypeMetaFieldIndex(FCurrentMethodClass, ANode.Text) >= 0) then
  begin
    Folded := TypeMetaFieldIndex(FCurrentMethodClass, ANode.Text);
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

function TSemanticAnalyzer.EncodeRuntimeIntExprFold(
  const ANode: TGreenNode; out ABlob: string; out AExprId: LongInt): Boolean;
begin
  AExprId := 0;
  Result := EncodeRuntimeIntExprFold(ANode, ABlob);
  if Result and (Length(ABlob) > 5) and (Copy(ABlob, 1, 5) = 'expr ') then
    AExprId := StrToIntDef(Copy(ABlob, 6, Length(ABlob) - 5), 0);
end;

function TSemanticAnalyzer.BuildRuntimeArrayElementAddressHirExpr(
  const ANode: TGreenNode; out AExprId: LongInt): Boolean;
var
  ArrayName: string;
  Children: array of LongInt;
  Fact: TSemanticScalarTypeFact;
  IndexExpr, Expr: TSemanticHirExpr;
  CandidateTypeId, ElementTypeId, IndexExprId, IndexTypeId, SymbolId: LongInt;
  ElementTypeName: string;
begin
  AExprId := 0;
  if (ANode = nil) or (ANode.NodeKind <> gnkArrayAccess) or
    (ANode.ChildCount < 2) then
    Exit(False);
  if (ANode.ChildAt(0) = nil) or
    (ANode.ChildAt(0).NodeKind <> gnkIdentifier) then
    Exit(False);

  ArrayName := ANode.ChildAt(0).Text;
  if (ArrayName = '') or (not IsRuntimeArrVar(ArrayName)) then
    Exit(False);
  SymbolId := FModel.FindSymbolByName(ArrayName);
  if SymbolId <= 0 then
    Exit(False);
  if not BuildRuntimeScalarHirExpr(ANode.ChildAt(1), IndexExprId) then
    Exit(False);
  if (IndexExprId <= 0) or (IndexExprId > FModel.HirExprCount) then
    Exit(False);

  IndexExpr := FModel.HirExprAt(IndexExprId - 1);
  IndexTypeId := IndexExpr.TypeId;
  if (IndexTypeId <= 0) or
    (not FModel.GetTypeScalarFact(IndexTypeId, Fact)) or
    (Fact.Kind <> sskInt) then
    Exit(False);

  ElementTypeId := FModel.FindTypeByName('Integer');
  if FModel.LookupStringConstValue(ArrayName + '$arr_elem_type',
    ElementTypeName) and (ElementTypeName <> '') then
  begin
    CandidateTypeId := FModel.FindTypeByName(ElementTypeName);
    if CandidateTypeId > 0 then
      ElementTypeId := CandidateTypeId;
  end;
  if ElementTypeId <= 0 then
    Exit(False);

  SetLength(Children, 1);
  Children[0] := IndexExprId;
  AExprId := FModel.AddHirExpr(
    shekArrayElem, ElementTypeId, SymbolId, Children,
    0, 0.0, '', '', 0, shvcAddress
  );
  if AExprId <= 0 then
    Exit(False);
  Expr := FModel.HirExprAt(AExprId - 1);
  Result := (Expr.Kind = shekArrayElem) and (Expr.ValueClass = shvcAddress);
end;

function TSemanticAnalyzer.FindSymbolByNameAndType(const AName: string;
  const ATypeId: LongInt): LongInt;
var
  I: LongInt;
  Symbol: TSemanticSymbol;
begin
  for I := FModel.SymbolCount - 1 downto 0 do
  begin
    Symbol := FModel.SymbolAt(I);
    if SameText(Symbol.Name, AName) and
      ((ATypeId <= 0) or (Symbol.TypeId = ATypeId)) then
      Exit(Symbol.SymbolId);
  end;
  Result := 0;
end;

function TSemanticAnalyzer.EnsureSelfSymbolId(out ASelfTypeId: LongInt): LongInt;
begin
  ASelfTypeId := 0;
  if FCurrentMethodClass = '' then
    Exit(0);
  ASelfTypeId := FModel.FindTypeByName(FCurrentMethodClass);
  if ASelfTypeId <= 0 then
    Exit(0);
  Result := FindSymbolByNameAndType('self', ASelfTypeId);
  if Result = 0 then
    Result := FModel.AddSymbol('self', 'parameter', '', ASelfTypeId, 0);
end;

function TSemanticAnalyzer.LookupFieldMetaByTypeName(const ATypeName,
  AFieldName: string; out AOwnerTypeId: LongInt;
  out AFieldMeta: TFieldMeta): Boolean;
begin
  AOwnerTypeId := FModel.FindTypeByName(ATypeName);
  if AOwnerTypeId <= 0 then
    Exit(False);
  Result := FModel.GetFieldMetaByName(AOwnerTypeId, AFieldName, AFieldMeta);
end;

function TSemanticAnalyzer.BuildRecordBaseAddressExpr(const ARecordName,
  ARecordTypeName: string; out AExprId: LongInt): Boolean;
var
  Children: array of LongInt;
  RecordTypeId, RecordSymbolId: LongInt;
begin
  AExprId := 0;
  if (ARecordName = '') or (ARecordTypeName = '') then
    Exit(False);

  RecordTypeId := FModel.FindTypeByName(ARecordTypeName);
  if RecordTypeId <= 0 then
    Exit(False);

  RecordSymbolId := FindSymbolByNameAndType(ARecordName, RecordTypeId);
  if RecordSymbolId = 0 then
    RecordSymbolId := FModel.FindSymbolByName(ARecordName);
  if RecordSymbolId <= 0 then
    Exit(False);

  SetLength(Children, 0);
  AExprId := FModel.AddHirExpr(
    shekSymbolAddress, RecordTypeId, RecordSymbolId, Children,
    0,
    0.0, '', '', 0, shvcAddress
  );
  Result := AExprId > 0;
end;

function TSemanticAnalyzer.BuildClassBaseAddressExpr(const ABaseName,
  AClassName: string; out AExprId: LongInt): Boolean;
var
  Children: array of LongInt;
  BaseTypeId, PointerTypeId, BaseSymbolId, PointerExprId: LongInt;
  SelfTypeId: LongInt;
begin
  AExprId := 0;
  PointerTypeId := FModel.FindTypeByName('Pointer');
  if PointerTypeId <= 0 then
    Exit(False);
  BaseTypeId := FModel.FindTypeByName(AClassName);
  if BaseTypeId <= 0 then
    Exit(False);

  if SameText(ABaseName, 'self') then
  begin
    BaseSymbolId := EnsureSelfSymbolId(SelfTypeId);
    if (BaseSymbolId <= 0) or (SelfTypeId <> BaseTypeId) then
      Exit(False);
  end
  else
  begin
    BaseSymbolId := FindSymbolByNameAndType(ABaseName, BaseTypeId);
    if BaseSymbolId = 0 then
      BaseSymbolId := FModel.FindSymbolByName(ABaseName);
    if BaseSymbolId <= 0 then
      Exit(False);
  end;

  SetLength(Children, 0);
  PointerExprId := FModel.AddHirExpr(
    shekSymbolValue, PointerTypeId, BaseSymbolId, Children,
    0,
    0.0, '', '', 0, shvcScalar
  );
  SetLength(Children, 1);
  Children[0] := PointerExprId;
  AExprId := FModel.AddHirExpr(
    shekDeref, BaseTypeId, 0,
    Children, 0, 0.0, '', '', 0, shvcAddress
  );
  Result := AExprId > 0;
end;

function TSemanticAnalyzer.BuildClassFieldTargetExpr(const ABaseName,
  AClassName, AFieldName: string; out AExprId: LongInt): Boolean;
var
  Children: array of LongInt;
  BaseTypeId, BaseExprId: LongInt;
  FieldMeta: TFieldMeta;
begin
  AExprId := 0;
  if not LookupFieldMetaByTypeName(AClassName, AFieldName, BaseTypeId,
    FieldMeta) then
    Exit(False);
  if not BuildClassBaseAddressExpr(ABaseName, AClassName, BaseExprId) then
    Exit(False);

  SetLength(Children, 1);
  Children[0] := BaseExprId;
  AExprId := FModel.AddHirExpr(
    shekField, FieldMeta.TypeId, 0,
    Children, FieldMeta.Index, 0.0, FieldMeta.Name, '', 0, shvcAddress
  );
  Result := AExprId > 0;
end;

function TSemanticAnalyzer.TryCurrentClassFieldArrayAccess(
  const AArrayAccessNode: TGreenNode; out AFieldName: string): Boolean;
var
  BaseName, OwnerClassName: string;
begin
  Result := TryClassFieldArrayAccess(AArrayAccessNode, BaseName, OwnerClassName,
    AFieldName) and SameText(BaseName, 'self') and
    SameText(OwnerClassName, FCurrentMethodClass);
end;

function TSemanticAnalyzer.TryClassFieldArrayAccess(
  const AArrayAccessNode: TGreenNode; out ABaseName, AClassName,
  AFieldName: string): Boolean;
var
  BaseNode, FieldNode, ReceiverNode: TGreenNode;
begin
  ABaseName := '';
  AClassName := '';
  AFieldName := '';
  if (AArrayAccessNode = nil) or
    (AArrayAccessNode.NodeKind <> gnkArrayAccess) or
    (AArrayAccessNode.ChildCount < 2) or
    (AArrayAccessNode.ChildAt(0) = nil) then
    Exit(False);

  BaseNode := AArrayAccessNode.ChildAt(0);
  if (BaseNode.NodeKind = gnkIdentifier) and (FCurrentMethodClass <> '') then
  begin
    AFieldName := BaseNode.Text;
    if (AFieldName <> '') and
      (not IsRuntimeArrVar(AFieldName)) and
      (not IsRuntimeStrVar(AFieldName)) and
      (TypeMetaFieldIndex(FCurrentMethodClass, AFieldName) >= 0) then
    begin
      ABaseName := 'self';
      AClassName := FCurrentMethodClass;
    end
    else
      AFieldName := '';
  end
  else if (BaseNode.NodeKind = gnkDotAccess) and
    (BaseNode.ChildCount >= 2) and
    (BaseNode.ChildAt(0) <> nil) and
    (BaseNode.ChildAt(1) <> nil) and
    (BaseNode.ChildAt(0).NodeKind = gnkIdentifier) and
    (BaseNode.ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    ReceiverNode := BaseNode.ChildAt(0);
    FieldNode := BaseNode.ChildAt(1);
    AFieldName := FieldNode.Text;
    if SameText(ReceiverNode.Text, 'Self') and (FCurrentMethodClass <> '') and
      (TypeMetaFieldIndex(FCurrentMethodClass, AFieldName) >= 0) then
    begin
      ABaseName := 'self';
      AClassName := FCurrentMethodClass;
    end
    else
    begin
      AClassName := LookupClassVar(ReceiverNode.Text);
      if (AClassName <> '') and
        (TypeMetaFieldIndex(AClassName, AFieldName) >= 0) then
        ABaseName := ReceiverNode.Text
      else
      begin
        AClassName := '';
        AFieldName := '';
      end;
    end;
  end;

  Result := (ABaseName <> '') and (AClassName <> '') and
    (AFieldName <> '');
end;

function TSemanticAnalyzer.BuildClassFieldArrayElementTargetExpr(
  const AArrayAccessNode: TGreenNode; out AExprId: LongInt): Boolean;
var
  Children: array of LongInt;
  ArrayExpr, FieldExpr, IndexExpr: TSemanticHirExpr;
  ElementTypeId, FieldExprId, IndexExprId, IndexTypeId: LongInt;
  BaseName, OwnerClassName, ElementTypeName, FieldName: string;
  Fact: TSemanticScalarTypeFact;
begin
  AExprId := 0;
  if not TryClassFieldArrayAccess(AArrayAccessNode, BaseName,
    OwnerClassName,
    FieldName) then
    Exit(False);

  if not FModel.LookupStringConstValue(
    OwnerClassName + '.' + FieldName + '$arr_elem_type',
    ElementTypeName) then
    Exit(False);
  ElementTypeId := FModel.FindTypeByName(ElementTypeName);
  if ElementTypeId <= 0 then
    Exit(False);

  if not BuildClassFieldTargetExpr(BaseName, OwnerClassName, FieldName,
    FieldExprId) then
    Exit(False);
  if (FieldExprId <= 0) or (FieldExprId > FModel.HirExprCount) then
    Exit(False);
  FieldExpr := FModel.HirExprAt(FieldExprId - 1);
  if (FieldExpr.Kind <> shekField) or
    (FieldExpr.ValueClass <> shvcAddress) then
    Exit(False);

  if not BuildRuntimeScalarHirExpr(AArrayAccessNode.ChildAt(1), IndexExprId) then
    Exit(False);
  if (IndexExprId <= 0) or (IndexExprId > FModel.HirExprCount) then
    Exit(False);
  IndexExpr := FModel.HirExprAt(IndexExprId - 1);
  IndexTypeId := IndexExpr.TypeId;
  if (IndexTypeId <= 0) or
    (not FModel.GetTypeScalarFact(IndexTypeId, Fact)) or
    (Fact.Kind <> sskInt) then
    Exit(False);

  SetLength(Children, 2);
  Children[0] := FieldExprId;
  Children[1] := IndexExprId;
  AExprId := FModel.AddHirExpr(
    shekArrayElem, ElementTypeId, 0,
    Children, 0, 0.0,
    '', '', 0, shvcAddress
  );
  if (AExprId <= 0) or (AExprId > FModel.HirExprCount) then
    Exit(False);
  ArrayExpr := FModel.HirExprAt(AExprId - 1);
  Result := (ArrayExpr.Kind = shekArrayElem) and
    (ArrayExpr.ValueClass = shvcAddress);
end;

function TSemanticAnalyzer.ResolveArrayAccessElementTypeId(
  const AArrayAccessNode: TGreenNode; out AElementTypeId: LongInt): Boolean;
var
  ArrayName, BaseName, OwnerClassName, ElementTypeName, FieldName: string;
begin
  AElementTypeId := 0;
  if (AArrayAccessNode = nil) or
    (AArrayAccessNode.NodeKind <> gnkArrayAccess) or
    (AArrayAccessNode.ChildCount < 2) then
    Exit(False);

  if (AArrayAccessNode.ChildAt(0) <> nil) and
    (AArrayAccessNode.ChildAt(0).NodeKind = gnkIdentifier) then
  begin
    ArrayName := AArrayAccessNode.ChildAt(0).Text;
    if (ArrayName <> '') and IsRuntimeArrVar(ArrayName) and
      FModel.LookupStringConstValue(ArrayName + '$arr_elem_type',
        ElementTypeName) then
    begin
      AElementTypeId := FModel.FindTypeByName(ElementTypeName);
      Exit(AElementTypeId > 0);
    end;
  end;

  if TryClassFieldArrayAccess(AArrayAccessNode, BaseName, OwnerClassName,
    FieldName) and
    FModel.LookupStringConstValue(
      OwnerClassName + '.' + FieldName + '$arr_elem_type',
      ElementTypeName) then
  begin
    AElementTypeId := FModel.FindTypeByName(ElementTypeName);
    Exit(AElementTypeId > 0);
  end;

  Result := False;
end;

function TSemanticAnalyzer.TryBuildLegacyParamKindsFromSignature(
  const AArgSignature: string; const AParamCount: LongInt;
  out AParamKinds: string): Boolean;
var
  I: LongInt;
begin
  AParamKinds := '';
  if Length(AArgSignature) < AParamCount then
    Exit(False);
  for I := 1 to AParamCount do
    case AArgSignature[I] of
      'b', 'i':
        AParamKinds := AParamKinds + 'i';
      'p':
        AParamKinds := AParamKinds + 'p';
    else
      Exit(False);
    end;
  Result := True;
end;

function TSemanticAnalyzer.TryBuildLegacyParamKindsForDecl(
  const ADeclNode: TGreenNode; const AParamCount: LongInt;
  out AParamKinds: string): Boolean;
var
  Child, ParamNode, TypeNode: TGreenNode;
  I, J, ParamIndex: LongInt;
  TypeName: string;
  IsVarByRef: Boolean;
begin
  AParamKinds := '';
  ParamIndex := 0;
  if ADeclNode = nil then
    Exit(False);

  for I := 0 to ADeclNode.ChildCount - 1 do
  begin
    Child := ADeclNode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkParameterList) then
      Continue;
    for J := 0 to Child.ChildCount - 1 do
    begin
      ParamNode := Child.ChildAt(J);
      if (ParamNode = nil) or (ParamNode.NodeKind <> gnkParameterDecl) then
        Continue;
      Inc(ParamIndex);
      IsVarByRef := ParamNameIsByRef(ParamNode.Text);
      if ParamNode.ChildCount <= 0 then
      begin
        if IsVarByRef then
          Exit(False);
        AParamKinds := AParamKinds + 'i';
        Continue;
      end;
      TypeNode := ParamNode.ChildAt(0);
      if TypeNode = nil then
      begin
        if IsVarByRef then
          Exit(False);
        AParamKinds := AParamKinds + 'i';
        Continue;
      end;
      TypeName := TypeNode.Text;
      if SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString') then
        Exit(False);
      if TypeNode.NodeKind = gnkArrayType then
        Exit(False);
      if IsVarByRef then
      begin
        if (Length(TypeName) > 1) and (TypeName[1] = '^') then
          AParamKinds := AParamKinds + 'r'
        else if TypeMetaSize(TypeName) > 0 then
        begin
          if TypeMetaIsRecord(TypeName) then
            Exit(False);
          AParamKinds := AParamKinds + 'r';
        end
        else
          AParamKinds := AParamKinds + 'r';
      end
      else if (Length(TypeName) > 1) and (TypeName[1] = '^') then
        AParamKinds := AParamKinds + 'p'
      else if TypeMetaSize(TypeName) > 0 then
      begin
        if TypeMetaIsRecord(TypeName) then
          Exit(False);
        AParamKinds := AParamKinds + 'p';
      end
      else
        AParamKinds := AParamKinds + 'i';
    end;
    Break;
  end;

  Result := ParamIndex = AParamCount;
end;

function TSemanticAnalyzer.FindTypeDeclNodeInRoot(const ARootNode: TGreenNode;
  const ATypeName: string; out ATypeDeclNode,
  ATypeBodyNode: TGreenNode): Boolean;
var
  I, J, K: LongInt;
  SectionNode, TypeDeclNode, TypeBodyNode: TGreenNode;
  DeclName: string;
begin
  ATypeDeclNode := nil;
  ATypeBodyNode := nil;
  if (ARootNode = nil) or (ATypeName = '') then
    Exit(False);

  for I := 0 to ARootNode.ChildCount - 1 do
  begin
    SectionNode := ARootNode.ChildAt(I);
    if (SectionNode = nil) or (SectionNode.NodeKind <> gnkTypeSection) then
      Continue;
    for J := 0 to SectionNode.ChildCount - 1 do
    begin
      TypeDeclNode := SectionNode.ChildAt(J);
      if (TypeDeclNode = nil) or (TypeDeclNode.NodeKind <> gnkTypeDecl) then
        Continue;
      { Extract actual type name from directive-prefixed text }
      DeclName := TypeDeclNode.Text;
      if Copy(DeclName, 1, 14) = 'compiler_root:' then
        DeclName := Copy(DeclName, 15, Length(DeclName))
      else if Copy(DeclName, 1, 18) = 'compiler_type_kind:' then
        DeclName := Copy(DeclName, 19, Length(DeclName));
      if not SameText(DeclName, ATypeName) then
        Continue;
      ATypeDeclNode := TypeDeclNode;
      for K := 0 to TypeDeclNode.ChildCount - 1 do
      begin
        TypeBodyNode := TypeDeclNode.ChildAt(K);
        if (TypeBodyNode <> nil) and (TypeBodyNode.NodeKind = gnkClassType) then
        begin
          ATypeBodyNode := TypeBodyNode;
          Exit(True);
        end;
      end;
      Exit(False);
    end;
  end;
  Result := False;
end;

function TSemanticAnalyzer.FindTypeDeclNode(const ATypeName,
  AOwnerUnitId: string; out ATypeDeclNode, ATypeBodyNode: TGreenNode): Boolean;
var
  Index: LongInt;
  RootOwnerUnitId: string;
begin
  ATypeDeclNode := nil;
  ATypeBodyNode := nil;
  RootOwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);

  if (FRootAst <> nil) and
    ((AOwnerUnitId = '') or SameText(AOwnerUnitId, RootOwnerUnitId)) and
    FindTypeDeclNodeInRoot(FRootAst.RootNode, ATypeName, ATypeDeclNode,
      ATypeBodyNode) then
    Exit(True);

  for Index := 0 to Length(FImportedUnitTrees) - 1 do
  begin
    if (AOwnerUnitId <> '') and
      (not SameText(FImportedUnitOwners[Index], AOwnerUnitId)) then
      Continue;
    if FindTypeDeclNodeInRoot(FImportedUnitTrees[Index].RootNode, ATypeName,
      ATypeDeclNode, ATypeBodyNode) then
      Exit(True);
  end;

  if AOwnerUnitId <> '' then
    for Index := 0 to Length(FImportedUnitTrees) - 1 do
      if FindTypeDeclNodeInRoot(FImportedUnitTrees[Index].RootNode, ATypeName,
        ATypeDeclNode, ATypeBodyNode) then
        Exit(True);
  Result := False;
end;

function TSemanticAnalyzer.FindTypeMethodDecl(const ATypeName, AOwnerUnitId,
  AMethodName: string; const AArgCount: LongInt; const AArgSignature: string;
  const AHasArgSignature: Boolean; out ADeclNode: TGreenNode): Boolean;
var
  CandidateNode, ChildNode, NameNode, SignatureNode, TypeBodyNode,
    TypeDeclNode: TGreenNode;
  CurrentTypeId, Depth, I, MatchCount, SignatureMatchCount: LongInt;
  TypeSymbol: TSemanticSymbol;
begin
  ADeclNode := nil;
  CurrentTypeId := ResolveTypeIdForOwner(ATypeName, AOwnerUnitId);
  Depth := 0;
  while (CurrentTypeId > 0) and (Depth < 32) do
  begin
    if not TypeSymbolForTypeId(CurrentTypeId, TypeSymbol) then
      Exit(False);
    if FindTypeDeclNode(TypeSymbol.Name, TypeSymbol.OwnerUnitId, TypeDeclNode,
      TypeBodyNode) then
    begin
      CandidateNode := nil;
      SignatureNode := nil;
      MatchCount := 0;
      SignatureMatchCount := 0;
      for I := 0 to TypeBodyNode.ChildCount - 1 do
      begin
        ChildNode := TypeBodyNode.ChildAt(I);
        if (ChildNode = nil) or (ChildNode.NodeKind <> gnkClassMethod) or
          (ChildNode.ChildCount = 0) then
          Continue;
        NameNode := ChildNode.ChildAt(0);
        if (NameNode = nil) or (NameNode.NodeKind <> gnkIdentifier) or
          (not SameText(NameNode.Text, AMethodName)) or
          (not DeclAcceptsArgCount(ChildNode, AArgCount)) then
          Continue;
        Inc(MatchCount);
        CandidateNode := ChildNode;
        if (not AHasArgSignature) or
          DeclParamSignatureMatchesArgs(ChildNode, AArgSignature, AArgCount) then
        begin
          Inc(SignatureMatchCount);
          SignatureNode := ChildNode;
        end;
      end;
      if SignatureMatchCount = 1 then
      begin
        ADeclNode := SignatureNode;
        Exit(True);
      end;
      if (SignatureMatchCount = 0) and (MatchCount = 1) then
      begin
        ADeclNode := CandidateNode;
        Exit(True);
      end;
    end;
    if (CurrentTypeId <= 0) or (CurrentTypeId > FModel.TypeCount) then
      Break;
    CurrentTypeId := FModel.TypeAt(CurrentTypeId - 1).ParentTypeId;
    Inc(Depth);
  end;
  Result := False;
end;

function TSemanticAnalyzer.TryGetDispatchedMemberCallContract(
  const ACallNode: TGreenNode; out AExprKind: TSemanticHirExprKind;
  out AReceiverVarName, ACalleeName, AParamKinds: string;
  out ASlotIndex, AReturnTypeId: LongInt): Boolean;
var
  ArgTypeIds: TTypeIdArray;
  Candidates: TOverloadCandidateArray;
  DeclNode, MemberNode, ReceiverNode: TGreenNode;
  HasArgSignature, HasTypeMismatchEvidence: Boolean;
  MemberName, ReceiverName, ResolutionFailureKind, ArgSignature,
    ReceiverTypeName, DeclaringTypeName: string;
  ArgCount, DotPos, MemberOffset, ReceiverTypeId, TargetSymbolId: LongInt;
  TargetSymbol: TSemanticSymbol;
begin
  AExprKind := shekInvalid;
  AReceiverVarName := '';
  ACalleeName := '';
  AParamKinds := '';
  ASlotIndex := -1;
  AReturnTypeId := 0;
  ReceiverName := '';
  MemberName := '';
  MemberOffset := 0;
  ArgCount := 0;

  if ExtractDirectMemberCall(ACallNode, ReceiverName, MemberName,
    MemberOffset, ArgCount) then
  begin
    if SameText(ReceiverName, 'Self') then
      AReceiverVarName := 'self'
    else
      AReceiverVarName := ReceiverName;
    ReceiverTypeId := TypeIdForMemberReceiver(ReceiverName, FCurrentMethodClass,
      NormalizeUnitIdentity(FUnitGraph.RootName));
  end
  else if (ACallNode <> nil) and (ACallNode.NodeKind = gnkDotAccess) and
    (ACallNode.ChildCount >= 2) then
  begin
    ReceiverNode := ACallNode.ChildAt(0);
    MemberNode := ACallNode.ChildAt(1);
    if (ReceiverNode = nil) or (MemberNode = nil) or
      (ReceiverNode.NodeKind <> gnkIdentifier) or
      (MemberNode.NodeKind <> gnkIdentifier) then
      Exit(False);
    ReceiverName := ReceiverNode.Text;
    MemberName := MemberNode.Text;
    MemberOffset := MemberNode.ByteOffset;
    if SameText(ReceiverName, 'Self') then
      AReceiverVarName := 'self'
    else
      AReceiverVarName := ReceiverName;
    ReceiverTypeId := TypeIdForMemberReceiver(ReceiverName, FCurrentMethodClass,
      NormalizeUnitIdentity(FUnitGraph.RootName));
  end
  else if (FCurrentMethodClass <> '') and
    IsImplicitSelfCallNode(ACallNode) and
    (not IsQualifiedCallNode(ACallNode)) then
  begin
    MemberName := BareCallCalleeName(ACallNode);
    if MemberName = '' then
      Exit(False);
    AReceiverVarName := 'self';
    ReceiverTypeId := TypeIdForMemberReceiver('Self', FCurrentMethodClass,
      NormalizeUnitIdentity(FUnitGraph.RootName));
    ArgCount := CallArgumentCount(ACallNode);
  end
  else
    Exit(False);

  if (AReceiverVarName = '') or (ReceiverTypeId <= 0) or
    (ReceiverTypeId > FModel.TypeCount) or (not IsRuntimeVar(AReceiverVarName)) then
    Exit(False);

  HasArgSignature := (ACallNode <> nil) and
    (ACallNode.NodeKind in [gnkFunctionCall, gnkProcedureCallStatement, gnkDotAccess]) and
    CallArgumentSignature(ACallNode, ArgSignature);
  if not CallArgumentTypeIds(ACallNode, ArgTypeIds) then
    SetLength(ArgTypeIds, 0);
  HasTypeMismatchEvidence := HasArgSignature and
    CallArgumentSignatureIsStable(ACallNode,
      NormalizeUnitIdentity(FUnitGraph.RootName));
  ResolutionFailureKind := '';
  SetLength(Candidates, 0);
  TargetSymbolId := MethodSymbolIdForClassTypeMember(
    ReceiverTypeId,
    MemberName,
    ArgCount,
    ArgTypeIds,
    ArgSignature,
    HasArgSignature,
    HasTypeMismatchEvidence,
    ResolutionFailureKind,
    Candidates
  );
  if TargetSymbolId <= 0 then
    Exit(False);

  ReceiverTypeName := FModel.TypeAt(ReceiverTypeId - 1).Name;
  if ReceiverTypeName = '' then
    Exit(False);
  ASlotIndex := TypeMetaVmtSlot(ReceiverTypeName, MemberName);
  if ASlotIndex < 0 then
    Exit(False);
  if TypeMetaIsInterface(ReceiverTypeName) then
    AExprKind := shekInterfaceCall
  else
    AExprKind := shekVirtualCall;

  TargetSymbol := FModel.SymbolAt(TargetSymbolId - 1);
  ACalleeName := TargetSymbol.Name;
  if ACalleeName = '' then
    Exit(False);

  DotPos := Pos('.', ACalleeName);
  if DotPos > 0 then
    DeclaringTypeName := Copy(ACalleeName, 1, DotPos - 1)
  else
    DeclaringTypeName := ReceiverTypeName;
  DeclNode := nil;
  FindTypeMethodDecl(
    DeclaringTypeName,
    TargetSymbol.OwnerUnitId,
    MemberName,
    ArgCount,
    ArgSignature,
    HasArgSignature,
    DeclNode
  );

  if ((DeclNode = nil) or
    (not TryBuildLegacyParamKindsForDecl(DeclNode, ArgCount, AParamKinds))) and
    (not TryBuildLegacyParamKindsFromSignature(ArgSignature, ArgCount,
      AParamKinds)) then
    Exit(False);
  AParamKinds := 'p' + AParamKinds;

  if DeclNode <> nil then
    AReturnTypeId := DeclReturnTypeId(DeclNode, TargetSymbol.OwnerUnitId);
  if AReturnTypeId <= 0 then
    AReturnTypeId := InferExpressionType(ACallNode);
  if AReturnTypeId <= 0 then
    AReturnTypeId := FModel.FindTypeByName('Integer');
  if AReturnTypeId <= 0 then
    Exit(False);
  if TypeMetaIsClass(FModel.TypeAt(AReturnTypeId - 1).Name) then
    AReturnTypeId := FModel.FindTypeByName('Pointer');

  Result := AReturnTypeId > 0;
end;

function TSemanticAnalyzer.TryGetDirectCallContract(
  const ACallNode: TGreenNode; out ACalleeName, AParamKinds: string;
  out AReturnTypeId: LongInt): Boolean;
var
  BodyNode, DeclNode, EffectiveCallNode: TGreenNode;
  ParamCount: LongInt;
begin
  ACalleeName := '';
  AParamKinds := '';
  AReturnTypeId := 0;
  if ACallNode = nil then
    Exit(False);

  EffectiveCallNode := ACallNode;
  if (ACallNode.NodeKind = gnkProcedureCallStatement) and
    (ACallNode.ChildCount >= 1) and (ACallNode.ChildAt(0) <> nil) and
    (ACallNode.ChildAt(0).NodeKind = gnkFunctionCall) then
    EffectiveCallNode := ACallNode.ChildAt(0);

  if (EffectiveCallNode = nil) or
    (EffectiveCallNode.NodeKind <> gnkFunctionCall) or
    (EffectiveCallNode.ChildCount < 1) or (EffectiveCallNode.ChildAt(0) = nil) or
    (EffectiveCallNode.ChildAt(0).NodeKind <> gnkIdentifier) then
    Exit(False);

  ACalleeName := EffectiveCallNode.ChildAt(0).Text;
  if (ACalleeName = '') or HasOverload(ACalleeName) or
    (Pos('specialize ', ACalleeName) = 1) or
    (Pos('.', ACalleeName) <> 0) or IsBuiltinProcedure(ACalleeName) or
    (not LookupProcedureBody(ACalleeName, BodyNode, DeclNode)) or
    (DeclNode = nil) then
    Exit(False);

  ParamCount := EffectiveCallNode.ChildCount - 1;
  if not TryBuildLegacyParamKindsForDecl(DeclNode, ParamCount, AParamKinds) then
    Exit(False);

  AReturnTypeId := InferExpressionType(EffectiveCallNode);
  if AReturnTypeId <= 0 then
    AReturnTypeId := FModel.FindTypeByName('Integer');
  if AReturnTypeId <= 0 then
    Exit(False);
  if TypeMetaIsClass(FModel.TypeAt(AReturnTypeId - 1).Name) then
    AReturnTypeId := FModel.FindTypeByName('Pointer');

  Result := AReturnTypeId > 0;
end;

function TSemanticAnalyzer.TryGetOrdinaryMemberCallContract(
  const ACallNode: TGreenNode; out AReceiverVarName, ACalleeName,
  AParamKinds: string; out AReturnTypeId: LongInt): Boolean;
var
  ArgTypeIds: TTypeIdArray;
  BodyNode, DeclNode: TGreenNode;
  Candidates: TOverloadCandidateArray;
  MemberNode, ReceiverNode: TGreenNode;
  HasArgSignature, HasTypeMismatchEvidence: Boolean;
  MemberName, ReceiverName, ResolutionFailureKind, ArgSignature, OwnerUnitId: string;
  ArgCount, MemberOffset, ReceiverTypeId, TargetSymbolId: LongInt;
  ReceiverTypeName: string;
begin
  AReceiverVarName := '';
  ACalleeName := '';
  AParamKinds := '';
  AReturnTypeId := 0;
  ReceiverName := '';
  MemberName := '';
  MemberOffset := 0;
  ArgCount := 0;

  if ExtractDirectMemberCall(ACallNode, ReceiverName, MemberName,
    MemberOffset, ArgCount) then
  begin
    if SameText(ReceiverName, 'Self') then
      AReceiverVarName := 'self'
    else
      AReceiverVarName := ReceiverName;
    ReceiverTypeId := TypeIdForMemberReceiver(ReceiverName, FCurrentMethodClass,
      NormalizeUnitIdentity(FUnitGraph.RootName));
  end
  else if (ACallNode <> nil) and (ACallNode.NodeKind = gnkDotAccess) and
    (ACallNode.ChildCount >= 2) then
  begin
    ReceiverNode := ACallNode.ChildAt(0);
    MemberNode := ACallNode.ChildAt(1);
    if (ReceiverNode = nil) or (MemberNode = nil) or
      (ReceiverNode.NodeKind <> gnkIdentifier) or
      (MemberNode.NodeKind <> gnkIdentifier) then
      Exit(False);
    ReceiverName := ReceiverNode.Text;
    MemberName := MemberNode.Text;
    MemberOffset := MemberNode.ByteOffset;
    ArgCount := 0;
    if SameText(ReceiverName, 'Self') then
      AReceiverVarName := 'self'
    else
      AReceiverVarName := ReceiverName;
    ReceiverTypeId := TypeIdForMemberReceiver(ReceiverName, FCurrentMethodClass,
      NormalizeUnitIdentity(FUnitGraph.RootName));
  end
  else if (FCurrentMethodClass <> '') and
    IsImplicitSelfCallNode(ACallNode) and
    (not IsQualifiedCallNode(ACallNode)) then
  begin
    MemberName := BareCallCalleeName(ACallNode);
    if MemberName = '' then
      Exit(False);
    AReceiverVarName := 'self';
    ReceiverTypeId := TypeIdForMemberReceiver('Self', FCurrentMethodClass,
      NormalizeUnitIdentity(FUnitGraph.RootName));
    ArgCount := CallArgumentCount(ACallNode);
  end
  else
    Exit(False);

  if (AReceiverVarName = '') or (ReceiverTypeId <= 0) or
    (ReceiverTypeId > FModel.TypeCount) or (not IsRuntimeVar(AReceiverVarName)) then
    Exit(False);

  HasArgSignature := (ACallNode <> nil) and
    (ACallNode.NodeKind in [gnkFunctionCall, gnkProcedureCallStatement]) and
    CallArgumentSignature(ACallNode, ArgSignature);
  if not CallArgumentTypeIds(ACallNode, ArgTypeIds) then
    SetLength(ArgTypeIds, 0);
  HasTypeMismatchEvidence := HasArgSignature and
    CallArgumentSignatureIsStable(ACallNode,
      NormalizeUnitIdentity(FUnitGraph.RootName));
  ResolutionFailureKind := '';
  SetLength(Candidates, 0);
  TargetSymbolId := MethodSymbolIdForClassTypeMember(
    ReceiverTypeId,
    MemberName,
    ArgCount,
    ArgTypeIds,
    ArgSignature,
    HasArgSignature,
    HasTypeMismatchEvidence,
    ResolutionFailureKind,
    Candidates
  );
  if TargetSymbolId <= 0 then
    Exit(False);

  ReceiverTypeName := FModel.TypeAt(ReceiverTypeId - 1).Name;
  if (ReceiverTypeName = '') or TypeMetaIsInterface(ReceiverTypeName) or
    (TypeMetaVmtSlot(ReceiverTypeName, MemberName) >= 0) then
    Exit(False);

  ACalleeName := FModel.SymbolAt(TargetSymbolId - 1).Name;
  if (ACalleeName = '') or
    not LookupCallBindingDeclaration(
      ACalleeName,
      ArgCount,
      ArgTypeIds,
      ArgSignature,
      HasArgSignature,
      HasTypeMismatchEvidence,
      ResolutionFailureKind,
      BodyNode,
      DeclNode,
      OwnerUnitId
    ) or (DeclNode = nil) then
    Exit(False);

  if not TryBuildLegacyParamKindsForDecl(DeclNode, ArgCount, AParamKinds) then
    Exit(False);
  AParamKinds := 'p' + AParamKinds;

  AReturnTypeId := DeclReturnTypeId(DeclNode, OwnerUnitId);
  if AReturnTypeId <= 0 then
    AReturnTypeId := InferExpressionType(ACallNode);
  if AReturnTypeId <= 0 then
    AReturnTypeId := FModel.FindTypeByName('Integer');
  if AReturnTypeId <= 0 then
    Exit(False);
  if TypeMetaIsClass(FModel.TypeAt(AReturnTypeId - 1).Name) then
    AReturnTypeId := FModel.FindTypeByName('Pointer');

  Result := AReturnTypeId > 0;
end;

function TSemanticAnalyzer.BuildTargetAddressExpr(const ATargetNode: TGreenNode;
  out AExprId: LongInt): Boolean;
var
  Children: array of LongInt;
  BaseName, ClassTypeName, FieldName, RecordTypeName: string;
  BaseExprId, BaseTypeId, ElementTypeId, ScalarSymbolId, ScalarTypeId: LongInt;
  Fact: TSemanticScalarTypeFact;
  FieldMeta: TFieldMeta;
begin
  AExprId := 0;
  if ATargetNode = nil then
    Exit(False);

  case ATargetNode.NodeKind of
    gnkIdentifier:
      begin
        BaseName := ATargetNode.Text;
        if BaseName = '' then
          Exit(False);
        if SameText(BaseName, 'Self') and (FCurrentMethodClass <> '') then
          Exit(BuildClassBaseAddressExpr('self', FCurrentMethodClass, AExprId));
        if (FCurrentMethodClass <> '') and
          (TypeMetaFieldIndex(FCurrentMethodClass, BaseName) >= 0) then
          Exit(BuildClassFieldTargetExpr('self', FCurrentMethodClass,
            BaseName, AExprId));
        if SameText(BaseName, 'Result') and (FCurrentRetVarName <> '') then
        begin
          RecordTypeName := LookupRecordVar(FCurrentRetVarName);
          if RecordTypeName <> '' then
            Exit(BuildRecordBaseAddressExpr(FCurrentRetVarName,
              RecordTypeName, AExprId));
        end;
        RecordTypeName := LookupRecordVar(BaseName);
        if RecordTypeName <> '' then
          Exit(BuildRecordBaseAddressExpr(BaseName, RecordTypeName, AExprId));
        ClassTypeName := LookupClassVar(BaseName);
        if ClassTypeName <> '' then
          Exit(BuildClassBaseAddressExpr(BaseName, ClassTypeName, AExprId));
        if IsRuntimeVar(BaseName) and
          (not IsRuntimeStrVar(BaseName)) and
          (not IsRuntimeArrVar(BaseName)) then
        begin
          ScalarSymbolId := FModel.FindSymbolByName(BaseName);
          if ScalarSymbolId <= 0 then
            Exit(False);
          ScalarTypeId := FModel.SymbolTypeId(ScalarSymbolId);
          if (ScalarTypeId <= 0) or
            (not FModel.GetTypeScalarFact(ScalarTypeId, Fact)) or
            not (Fact.Kind in [sskBool, sskInt, sskPointer]) then
            Exit(False);
          SetLength(Children, 0);
          AExprId := FModel.AddHirExpr(
            shekSymbolAddress, ScalarTypeId, ScalarSymbolId, Children,
    0,
    0.0, '', '', 0, shvcAddress
          );
          Exit(AExprId > 0);
        end;
        Result := False;
      end;
    gnkArrayAccess:
      Result := BuildRuntimeArrayElementAddressHirExpr(ATargetNode, AExprId) or
        BuildClassFieldArrayElementTargetExpr(ATargetNode, AExprId);
    gnkDotAccess:
      begin
        if (ATargetNode.ChildCount < 2) or (ATargetNode.ChildAt(0) = nil) or
          (ATargetNode.ChildAt(1) = nil) or
          (ATargetNode.ChildAt(1).NodeKind <> gnkIdentifier) then
          Exit(False);

        FieldName := ATargetNode.ChildAt(1).Text;
        if not BuildTargetAddressExpr(ATargetNode.ChildAt(0), BaseExprId) then
          Exit(False);
        if (BaseExprId <= 0) or (BaseExprId > FModel.HirExprCount) then
          Exit(False);

        BaseTypeId := FModel.HirExprAt(BaseExprId - 1).TypeId;
        if (BaseTypeId <= 0) and
          (ATargetNode.ChildAt(0).NodeKind = gnkArrayAccess) then
        begin
          if not ResolveArrayAccessElementTypeId(ATargetNode.ChildAt(0),
            ElementTypeId) then
            Exit(False);
          BaseTypeId := ElementTypeId;
        end;
        if BaseTypeId <= 0 then
          Exit(False);
        if not FModel.GetFieldMetaByName(BaseTypeId, FieldName, FieldMeta) then
          Exit(False);

        SetLength(Children, 1);
        Children[0] := BaseExprId;
        AExprId := FModel.AddHirExpr(
          shekField, FieldMeta.TypeId, 0,
    Children, FieldMeta.Index, 0.0,
          FieldMeta.Name, '', 0, shvcAddress
        );
        Result := AExprId > 0;
      end;
  else
    Result := False;
  end;
end;

function TSemanticAnalyzer.BuildByRefArgumentAddressExpr(
  const ATargetNode: TGreenNode; out AExprId: LongInt): Boolean;
var
  Children: array of LongInt;
  BaseName: string;
  SelfTypeId, SymbolId, TypeId: LongInt;
begin
  AExprId := 0;
  if ATargetNode = nil then
    Exit(False);

  if ATargetNode.NodeKind = gnkIdentifier then
  begin
    BaseName := ATargetNode.Text;
    if SameText(BaseName, 'Result') and (FCurrentRetVarName <> '') then
      BaseName := FCurrentRetVarName;

    if SameText(BaseName, 'Self') then
    begin
      SymbolId := EnsureSelfSymbolId(SelfTypeId);
      TypeId := SelfTypeId;
    end
    else if (BaseName <> '') and IsRuntimeVar(BaseName) and
      (not IsRuntimeStrVar(BaseName)) and (not IsRuntimeArrVar(BaseName)) then
    begin
      SymbolId := FModel.FindSymbolByName(BaseName);
      TypeId := FModel.SymbolTypeId(SymbolId);
    end
    else
    begin
      SymbolId := 0;
      TypeId := 0;
    end;

    if (SymbolId > 0) and (TypeId > 0) then
    begin
      SetLength(Children, 0);
      AExprId := FModel.AddHirExpr(
        shekSymbolAddress, TypeId, SymbolId, Children,
    0,
    0.0, '', '', 0, shvcAddress
      );
      Exit(AExprId > 0);
    end;
  end;

  Result := BuildTargetAddressExpr(ATargetNode, AExprId);
end;

procedure TSemanticAnalyzer.AttachStatementCallExpr(const AHirNodeId: LongInt;
  const ACallNode: TGreenNode);
var
  ExprId: LongInt;
begin
  if (AHirNodeId <= 0) or (ACallNode = nil) then
    Exit;
  if BuildRuntimeScalarHirExpr(ACallNode, ExprId) then
    FModel.SetTypedHirNodeExprId(AHirNodeId, ExprId);
end;


{ === SemaBridge functions — adapt TSemanticAnalyzer methods to callback pointers === }

function SemaBridge_BuildTargetAddressExpr(const Ctx: Pointer; const ATargetNode: TGreenNode;
  out AExprId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).BuildTargetAddressExpr(ATargetNode, AExprId);
end;

function SemaBridge_BuildClassBaseAddressExpr(const Ctx: Pointer; const ABaseName,
  AClassName: string; out AExprId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).BuildClassBaseAddressExpr(ABaseName, AClassName, AExprId);
end;

function SemaBridge_BuildByRefArgumentAddressExpr(const Ctx: Pointer;
  const AArgNode: TGreenNode; out AExprId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).BuildByRefArgumentAddressExpr(AArgNode, AExprId);
end;

function SemaBridge_BuildRuntimeArrayElementAddressHirExpr(const Ctx: Pointer;
  const ANode: TGreenNode; out AExprId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).BuildRuntimeArrayElementAddressHirExpr(ANode, AExprId);
end;

function SemaBridge_EvaluateIntegerConstant(const Ctx: Pointer; const ANode: TGreenNode;
  out AValue: Int64): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).EvaluateIntegerConstant(ANode, AValue);
end;

function SemaBridge_InferExpressionType(const Ctx: Pointer;
  const ANode: TGreenNode): LongInt;
begin
  Result := TSemanticAnalyzer(Ctx).InferExpressionType(ANode);
end;

function SemaBridge_TypeIdForVariable(const Ctx: Pointer;
  const AName: string): LongInt;
begin
  Result := TSemanticAnalyzer(Ctx).TypeIdForVariable(AName);
end;

function SemaBridge_TryGetDirectCallContract(const Ctx: Pointer; const ACallNode: TGreenNode;
  out ACalleeName, AParamKinds: string; out AResultTypeId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).TryGetDirectCallContract(ACallNode, ACalleeName, AParamKinds, AResultTypeId);
end;

function SemaBridge_TryGetDispatchedMemberCallContract(const Ctx: Pointer;
  const ACallNode: TGreenNode; out AExprKind: TSemanticHirExprKind;
  out AReceiverVarName, ACalleeName, AParamKinds: string;
  out ASlotIndex, AReturnTypeId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).TryGetDispatchedMemberCallContract(
    ACallNode, AExprKind, AReceiverVarName, ACalleeName, AParamKinds, ASlotIndex, AReturnTypeId);
end;

function SemaBridge_TryGetOrdinaryMemberCallContract(const Ctx: Pointer;
  const ACallNode: TGreenNode; out AReceiverVarName, ACalleeName,
  AParamKinds: string; out AResultTypeId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).TryGetOrdinaryMemberCallContract(
    ACallNode, AReceiverVarName, ACalleeName, AParamKinds, AResultTypeId);
end;

function SemaBridge_TryGetTypeCastTargetTypeId(const Ctx: Pointer;
  const ACallNode: TGreenNode; out ATypeId: LongInt): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).TryGetTypeCastTargetTypeId(ACallNode, ATypeId);
end;

function SemaBridge_TryGetIntrinsicExprName(const Ctx: Pointer;
  const ACallNode: TGreenNode; out AIntrinsicName: string): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).TryGetIntrinsicExprName(ACallNode, AIntrinsicName);
end;

function SemaBridge_ResolveTypeIdForOwner(const Ctx: Pointer; const ATypeName,
  AOwnerUnitId: string): LongInt;
begin
  Result := TSemanticAnalyzer(Ctx).ResolveTypeIdForOwner(ATypeName, AOwnerUnitId);
end;

function SemaBridge_EncodeRuntimeIntExprFold(const Ctx: Pointer;
  const ANode: TGreenNode; out ABlob: string): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).EncodeRuntimeIntExprFold(ANode, ABlob);
end;

function SemaBridge_CanEmitStrCompareOperand(const Ctx: Pointer;
  const ANode: TGreenNode; AAllowOwned: Boolean): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).CanEmitStrCompareOperand(ANode, AAllowOwned);
end;

function SemaBridge_EmitStrCompareOperand(const Ctx: Pointer;
  const ANode: TGreenNode; AAllowOwned: Boolean;
  out ABlob: string): Boolean;
begin
  Result := TSemanticAnalyzer(Ctx).EmitStrCompareOperand(ANode, AAllowOwned, ABlob);
end;

function TSemanticAnalyzer.BuildRuntimeScalarHirExpr(const ANode: TGreenNode;
  out AExprId: LongInt): Boolean;
var
  Ctx: TSemaHirLoweringContext;
begin
  { Fill context }
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Ctx.Diagnostics := FDiagnostics;
  Ctx.RootFileId := FRootFileId;
  Ctx.BlockLabelCounter := FBlockLabelCounter;
  Ctx.CurrentMethodClass := FCurrentMethodClass;
  Ctx.CurrentRetVarName := FCurrentRetVarName;
  Ctx.RuntimeVars := FRuntimeVars;
  Ctx.CurrentBlockTerminated := FCurrentBlockTerminated;
  { Fill callbacks }
  Ctx.CallbackCtx := Pointer(Self);
  Ctx.BuildTargetAddressExpr := @SemaBridge_BuildTargetAddressExpr;
  Ctx.BuildClassBaseAddressExpr := @SemaBridge_BuildClassBaseAddressExpr;
  Ctx.BuildByRefArgumentAddressExpr := @SemaBridge_BuildByRefArgumentAddressExpr;
  Ctx.BuildRuntimeArrayElementAddressHirExpr := @SemaBridge_BuildRuntimeArrayElementAddressHirExpr;
  Ctx.EvaluateIntegerConstant := @SemaBridge_EvaluateIntegerConstant;
  Ctx.InferExpressionType := @SemaBridge_InferExpressionType;
  Ctx.TypeIdForVariable := @SemaBridge_TypeIdForVariable;
  Ctx.TryGetDirectCallContract := @SemaBridge_TryGetDirectCallContract;
  Ctx.TryGetDispatchedMemberCallContract := @SemaBridge_TryGetDispatchedMemberCallContract;
  Ctx.TryGetOrdinaryMemberCallContract := @SemaBridge_TryGetOrdinaryMemberCallContract;
  Ctx.TryGetTypeCastTargetTypeId := @SemaBridge_TryGetTypeCastTargetTypeId;
  Ctx.TryGetIntrinsicExprName := @SemaBridge_TryGetIntrinsicExprName;
  Ctx.ResolveTypeIdForOwner := @SemaBridge_ResolveTypeIdForOwner;
  Ctx.EncodeRuntimeIntExprFold := @SemaBridge_EncodeRuntimeIntExprFold;
  Ctx.CanEmitStrCompareOperand := @SemaBridge_CanEmitStrCompareOperand;
  Ctx.EmitStrCompareOperand := @SemaBridge_EmitStrCompareOperand;
  { Delegate }
  Result := np_sema_hir_lowering.BuildRuntimeScalarHirExpr(Ctx, ANode, AExprId);
  { Sync mutable state back }
  FCurrentBlockTerminated := Ctx.CurrentBlockTerminated;
  FBlockLabelCounter := Ctx.BlockLabelCounter;
end;

procedure TSemanticAnalyzer.AttachRuntimeReturnExpr(const AHirNodeId: LongInt;
  const AReturnVarName: string);
var Ctx: TSemaHirLoweringContext;
begin
  Ctx.Model := FModel;
  np_sema_hir_lowering.AttachRuntimeReturnExpr(Ctx, AHirNodeId, AReturnVarName);
end;

procedure TSemanticAnalyzer.AttachRuntimeConditionExpr(const AHirNodeId: LongInt;
  const ACondNode: TGreenNode);

  function IsRuntimeBoolExprNode(const ANode: TGreenNode): Boolean;
  var
    Op: string;
  begin
    if ANode = nil then
      Exit(False);
    if (ANode.NodeKind = gnkUnaryExpression) and
      SameText(ANode.Text, 'not') and (ANode.ChildCount >= 1) then
      Exit(IsRuntimeBoolExprNode(ANode.ChildAt(0)));
    if (ANode.NodeKind <> gnkBinaryExpression) or (ANode.ChildCount < 2) then
      Exit(False);
    Op := ANode.Text;
    if (Op = '=') or (Op = '<>') or (Op = '<') or (Op = '<=') or
      (Op = '>') or (Op = '>=') then
      Exit(True);
    if SameText(Op, 'and') or SameText(Op, 'or') then
      Exit(IsRuntimeBoolExprNode(ANode.ChildAt(0)) and
        IsRuntimeBoolExprNode(ANode.ChildAt(1)));
    Result := False;
  end;

var
  ExprId: LongInt;
begin
  if AHirNodeId <= 0 then
    Exit;
  if not IsRuntimeBoolExprNode(ACondNode) then
    Exit;
  if not BuildRuntimeScalarHirExpr(ACondNode, ExprId) then
    Exit;
  FModel.SetTypedHirNodeExprId(AHirNodeId, ExprId);
end;

function TSemanticAnalyzer.EncodeRuntimeBoolExprFold(
  const ANode: TGreenNode; out ABlob: string;
  const AAllowOwnedStringCompare: Boolean): Boolean;
var
  Ctx: TSemaHirLoweringContext;
begin
  Ctx.Model := FModel;
  Ctx.RuntimeVars := FRuntimeVars;
  Ctx.CallbackCtx := Pointer(Self);
  Ctx.EncodeRuntimeIntExprFold := @SemaBridge_EncodeRuntimeIntExprFold;
  Ctx.CanEmitStrCompareOperand := @SemaBridge_CanEmitStrCompareOperand;
  Ctx.EmitStrCompareOperand := @SemaBridge_EmitStrCompareOperand;
  Result := np_sema_hir_lowering.EncodeRuntimeBoolExprFold(Ctx, ANode, ABlob,
    AAllowOwnedStringCompare);
end;

procedure TSemanticAnalyzer.WalkHaltCalls(const ANode: TGreenNode);
var
  I, ArgIndex, ExprId, NodeId: LongInt;
  Child, Arg, RhsNode, BranchNode, DeclNode: TGreenNode;
  Operand: string;
  Value, CondValue: Int64;
  Decoded, StringValue, FuncName, ArgName, DestroyFuncName: string;
  OwnerClassName: string;
  ReceiverName: string;
  ParamSnaps: TParamSnapshots;
  InhTypeId, InhParentId: LongInt;
  InhMethodName, InhParentName: string;
  DotPos, K: LongInt;

  procedure AttachRuntimeScalarExpr(const AHirNodeId: LongInt;
    const AExprNode: TGreenNode);
  var
    LocalExprId: LongInt;
  begin
    if (AHirNodeId <= 0) or (AExprNode = nil) then
      Exit;
    if BuildRuntimeScalarHirExpr(AExprNode, LocalExprId) then
      FModel.SetTypedHirNodeExprId(AHirNodeId, LocalExprId);
  end;

  function BuildFieldStoreTargetExpr(const ATargetNode: TGreenNode;
    out AExprId: LongInt): Boolean;
  begin
    Result := BuildTargetAddressExpr(ATargetNode, AExprId);
  end;

  procedure AttachFieldStoreTargetExpr(const AHirNodeId: LongInt;
    const ATargetNode: TGreenNode);
  var
    LocalExprId: LongInt;
  begin
    if (AHirNodeId <= 0) or (ATargetNode = nil) then
      Exit;
    if BuildFieldStoreTargetExpr(ATargetNode, LocalExprId) then
      FModel.SetTypedHirNodeTargetExprId(AHirNodeId, LocalExprId);
  end;

  procedure AddFieldStoreRuntimeNode(const ADisplayName,
    AOperand: string; const ATargetNode, AExprNode: TGreenNode);
  var
    LocalNodeId: LongInt;
  begin
    LocalNodeId := FModel.AddTypedHirNode(
      'field-store-runtime', ADisplayName, 0, 0, AOperand
    );
    AttachRuntimeScalarExpr(LocalNodeId, AExprNode);
    AttachFieldStoreTargetExpr(LocalNodeId, ATargetNode);
  end;

  procedure AddFieldStoreStrOwnedRuntimeNode(const ADisplayName,
    AOperand: string; const ATargetNode: TGreenNode);
  var
    LocalNodeId: LongInt;
  begin
    LocalNodeId := FModel.AddTypedHirNode(
      'field-store-tstring-runtime', ADisplayName, 0, 0, AOperand
    );
    AttachFieldStoreTargetExpr(LocalNodeId, ATargetNode);
  end;

  function EmitStringFieldStoreRhsTemp(const AExprNode: TGreenNode;
    out ATempName: string): Boolean;
  var
    FieldIdx: Int64;
    LeftName, RightName: string;
  begin
    ATempName := '';
    if AExprNode = nil then
      Exit(False);
    if (AExprNode.NodeKind = gnkIdentifier) and
      (FCurrentMethodClass <> '') and
      TypeMetaFieldIsStr(FCurrentMethodClass, AExprNode.Text) then
    begin
      FieldIdx := TypeMetaFieldIndex(FCurrentMethodClass, AExprNode.Text);
      Inc(FBlockLabelCounter);
      ATempName := '$str_field_store_' + IntToStr(FBlockLabelCounter);
      RegisterRuntimeVar(ATempName);
      RegisterRuntimeStrVar(ATempName);
      FModel.AddTypedHirNode(
        'var-decl-tstring-runtime', ATempName, 0, 0, ATempName);
      FModel.AddTypedHirNode(
        'assign-tstring-field-load-runtime', ATempName, 0, 0,
        ATempName + #9 + IntToStr(FieldIdx));
      Exit(True);
    end;
    if (AExprNode.NodeKind = gnkBinaryExpression) and
      (AExprNode.Text = '+') and (AExprNode.ChildCount >= 2) and
      (AExprNode.ChildAt(0) <> nil) and
      (AExprNode.ChildAt(1) <> nil) then
    begin
      LeftName := EmitStrConcatOperand(AExprNode.ChildAt(0), '');
      RightName := EmitStrConcatOperand(AExprNode.ChildAt(1), '');
      if (LeftName = '') or (RightName = '') then
        Exit(False);
      Inc(FBlockLabelCounter);
      ATempName := '$str_field_store_' + IntToStr(FBlockLabelCounter);
      RegisterRuntimeVar(ATempName);
      RegisterRuntimeStrVar(ATempName);
      FModel.AddTypedHirNode(
        'var-decl-tstring-runtime', ATempName, 0, 0, ATempName);
      FModel.AddTypedHirNode(
        'assign-tstring-concat-runtime',
        LeftName + #9 + RightName, 0, 0, ATempName);
      Exit(True);
    end;
    Result := False;
  end;

  procedure AddRecordFieldStoreRuntimeNode(const ADisplayName,
    AOperand: string; const ATargetNode, AExprNode: TGreenNode);
  var
    LocalNodeId: LongInt;
  begin
    LocalNodeId := FModel.AddTypedHirNode(
      'record-field-store-runtime', ADisplayName, 0, 0, AOperand
    );
    AttachRuntimeScalarExpr(LocalNodeId, AExprNode);
    AttachFieldStoreTargetExpr(LocalNodeId, ATargetNode);
  end;

  procedure AttachArrayElementStoreTargetExpr(const AHirNodeId: LongInt;
    const ATargetNode: TGreenNode);
  var
    LocalExprId: LongInt;
  begin
    if (AHirNodeId <= 0) or (ATargetNode = nil) then
      Exit;
    if BuildTargetAddressExpr(ATargetNode, LocalExprId) then
      FModel.SetTypedHirNodeTargetExprId(AHirNodeId, LocalExprId);
  end;

  procedure AddArrayElementStoreRuntimeNode(const ADisplayName,
    AOperand: string; const ATargetNode, AExprNode: TGreenNode);
  var
    LocalNodeId: LongInt;
  begin
    LocalNodeId := FModel.AddTypedHirNode(
      'assign-arr-elem-runtime', ADisplayName, 0, 0, AOperand
    );
    AttachRuntimeScalarExpr(LocalNodeId, AExprNode);
    AttachArrayElementStoreTargetExpr(LocalNodeId, ATargetNode);
  end;

  procedure AddArrayRecordFieldStoreRuntimeNode(const ADisplayName,
    AOperand: string; const ATargetNode, AExprNode: TGreenNode);
  var
    LocalNodeId: LongInt;
  begin
    LocalNodeId := FModel.AddTypedHirNode(
      'assign-arr-elem-runtime', ADisplayName, 0, 0, AOperand
    );
    AttachRuntimeScalarExpr(LocalNodeId, AExprNode);
    AttachFieldStoreTargetExpr(LocalNodeId, ATargetNode);
  end;

  function ResolveArrayStoreRootInfo(const AArrayAccessNode: TGreenNode;
    out ADisplayName, AOperandPrefix: string; out AElementTypeId: LongInt;
    out AElementSlotCount: Int64): Boolean;
  var
    ArrayName, ElementTypeName, FieldName: string;
    FieldIndex: Int64;
  begin
    ADisplayName := '';
    AOperandPrefix := '';
    AElementTypeId := 0;
    AElementSlotCount := 1;
    if (AArrayAccessNode = nil) or
      (AArrayAccessNode.NodeKind <> gnkArrayAccess) or
      (AArrayAccessNode.ChildCount < 2) then
      Exit(False);

    if (AArrayAccessNode.ChildAt(0) <> nil) and
      (AArrayAccessNode.ChildAt(0).NodeKind = gnkIdentifier) then
    begin
      ArrayName := AArrayAccessNode.ChildAt(0).Text;
      if (ArrayName <> '') and IsRuntimeArrVar(ArrayName) and
        FModel.LookupStringConstValue(ArrayName + '$arr_elem_type',
          ElementTypeName) then
      begin
        ADisplayName := ArrayName;
        AOperandPrefix := ArrayName;
      end;
    end;

    if (ADisplayName = '') and (FCurrentMethodClass <> '') and
      TryCurrentClassFieldArrayAccess(AArrayAccessNode, FieldName) and
      FModel.LookupStringConstValue(
        FCurrentMethodClass + '.' + FieldName + '$arr_elem_type',
        ElementTypeName) then
    begin
      FieldIndex := TypeMetaFieldIndex(FCurrentMethodClass, FieldName);
      if FieldIndex < 0 then
        Exit(False);
      ADisplayName := '__field_arr__';
      AOperandPrefix := 'self' + #9 + IntToStr(FieldIndex);
    end;

    if (ADisplayName = '') or (ElementTypeName = '') then
      Exit(False);

    AElementTypeId := FModel.FindTypeByName(ElementTypeName);
    if AElementTypeId <= 0 then
      Exit(False);
    if TypeMetaIsRecord(ElementTypeName) then
    begin
      AElementSlotCount := TypeMetaSize(ElementTypeName) div 8;
      if AElementSlotCount <= 0 then
        Exit(False);
    end;
    Result := True;
  end;

  function ResolveArrayBackedFieldTarget(const ATargetNode: TGreenNode;
    out AArrayAccessNode: TGreenNode; out ALeafTypeId: LongInt;
    out AFieldOffset: Int64): Boolean;
  var
    DummyDisplayName, DummyOperandPrefix: string;
    BaseTypeId: LongInt;
    ElementSlotCount: Int64;
    FieldMeta: TFieldMeta;
  begin
    AArrayAccessNode := nil;
    ALeafTypeId := 0;
    AFieldOffset := 0;
    if (ATargetNode = nil) or (ATargetNode.NodeKind <> gnkDotAccess) or
      (ATargetNode.ChildCount < 2) or (ATargetNode.ChildAt(0) = nil) or
      (ATargetNode.ChildAt(1) = nil) or
      (ATargetNode.ChildAt(1).NodeKind <> gnkIdentifier) then
      Exit(False);

    if ATargetNode.ChildAt(0).NodeKind = gnkArrayAccess then
    begin
      AArrayAccessNode := ATargetNode.ChildAt(0);
      if not ResolveArrayStoreRootInfo(AArrayAccessNode, DummyDisplayName,
        DummyOperandPrefix, BaseTypeId, ElementSlotCount) then
        Exit(False);
      AFieldOffset := 0;
    end
    else
    begin
      if not ResolveArrayBackedFieldTarget(ATargetNode.ChildAt(0),
        AArrayAccessNode, BaseTypeId, AFieldOffset) then
        Exit(False);
    end;

    if not FModel.GetFieldMetaByName(BaseTypeId, ATargetNode.ChildAt(1).Text,
      FieldMeta) then
      Exit(False);
    Inc(AFieldOffset, FieldMeta.Index);
    ALeafTypeId := FieldMeta.TypeId;
    Result := ALeafTypeId > 0;
  end;

  function TryAddArrayBackedFieldStoreRuntimeNode(
    const ATargetNode, AExprNode: TGreenNode): Boolean;
  var
    ArrayAccessNode: TGreenNode;
    DisplayName, OperandPrefix, IndexBlob, ValueBlob: string;
    ElementTypeId, LeafTypeId: LongInt;
    ElementSlotCount, FieldOffset: Int64;
  begin
    Result := False;
    if not FNoFold or (ATargetNode = nil) or (AExprNode = nil) then
      Exit(False);
    if not ResolveArrayBackedFieldTarget(ATargetNode, ArrayAccessNode,
      LeafTypeId, FieldOffset) then
      Exit(False);
    if not ResolveArrayStoreRootInfo(ArrayAccessNode, DisplayName,
      OperandPrefix, ElementTypeId, ElementSlotCount) then
      Exit(False);
    if (ArrayAccessNode.ChildCount < 2) or
      (not EncodeRuntimeIntExprFold(ArrayAccessNode.ChildAt(1), IndexBlob)) or
      (not EncodeRuntimeIntExprFold(AExprNode, ValueBlob)) then
      Exit(False);

    if ElementSlotCount > 1 then
      IndexBlob := IndexBlob + 'int ' + IntToStr(ElementSlotCount) + #10 +
        'mul' + #10;
    if FieldOffset > 0 then
      IndexBlob := IndexBlob + 'int ' + IntToStr(FieldOffset) + #10 +
        'add' + #10;

    AddArrayElementStoreRuntimeNode(
      DisplayName,
      OperandPrefix + #9 + IndexBlob + #9 + ValueBlob,
      ATargetNode,
      AExprNode
    );
    Result := True;
  end;

  procedure AddWriteIntRuntimeNode(const AExprNode: TGreenNode;
    const AOperand: string);
  var
    LocalExprId, LocalNodeId: LongInt;
  begin
    LocalNodeId := FModel.AddTypedHirNode(
      'write-int-runtime', 'Write', 0, 0, AOperand
    );
    if BuildRuntimeScalarHirExpr(AExprNode, LocalExprId) then
      FModel.SetTypedHirNodeExprId(LocalNodeId, LocalExprId);
  end;

  procedure AddScalarAssignRuntimeNode(const ADestVar: string;
    const AExprNode: TGreenNode; const AOperand: string);
  var
    LocalExprId, LocalNodeId: LongInt;
  begin
    LocalNodeId := FModel.AddTypedHirNode(
      'assign-runtime', ADestVar, 0, 0, ADestVar + #9 + AOperand
    );
    if Pos('.', ADestVar) <> 0 then
      Exit;
    if IsRuntimeStrVar(ADestVar) or IsRuntimeArrVar(ADestVar) or
      IsRecordVar(ADestVar) then
      Exit;
    if BuildRuntimeScalarHirExpr(AExprNode, LocalExprId) then
      FModel.SetTypedHirNodeExprId(LocalNodeId, LocalExprId);
  end;

  procedure AddIncDecAssignRuntimeNode(const ADestVar, AOp: string;
    const ADeltaExprNode: TGreenNode; const AOperand: string);
  var
    Children: array of LongInt;
    DeltaExprId, LocalNodeId, ResultExprId, SymbolExprId, SymbolId: LongInt;
  begin
    LocalNodeId := FModel.AddTypedHirNode(
      'assign-runtime', ADestVar, 0, 0, ADestVar + #9 + AOperand
    );
    if Pos('.', ADestVar) <> 0 then
      Exit;
    if IsRuntimeStrVar(ADestVar) or IsRuntimeArrVar(ADestVar) or
      IsRecordVar(ADestVar) or (LookupClassVar(ADestVar) <> '') then
      Exit;
    SymbolId := FModel.FindSymbolByName(ADestVar);
    if SymbolId <= 0 then
      Exit;
    SetLength(Children, 0);
    SymbolExprId := FModel.AddHirExpr(
      shekSymbolValue, 0,
    SymbolId, Children, 0, 0.0, '', '', 0, shvcScalar
    );
    if ADeltaExprNode <> nil then
    begin
      if not BuildRuntimeScalarHirExpr(ADeltaExprNode, DeltaExprId) then
        Exit;
    end
    else
    begin
      SetLength(Children, 0);
      DeltaExprId := FModel.AddHirExpr(
        shekIntLiteral, 0, 0,
        Children, 1, 0.0, '', '', 0, shvcScalar
      );
    end;
    SetLength(Children, 2);
    Children[0] := SymbolExprId;
    Children[1] := DeltaExprId;
    ResultExprId := FModel.AddHirExpr(
      shekBinaryOp, 0, 0,
      Children, 0, 0.0, '', AOp, 0, shvcScalar
    );
    FModel.SetTypedHirNodeExprId(LocalNodeId, ResultExprId);
  end;

  function IncDecStructuredOp(const ABlobOp: string): string;
  begin
    if ABlobOp = 'add' then
      Result := '+'
    else
      Result := '-';
  end;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if (Child.NodeKind = gnkProcedureDecl) or
      (Child.NodeKind = gnkFunctionDecl) then
      Continue;
    if Child.NodeKind = gnkIfStatement then
    begin
      if (not FNoFold) and
        (Child.ChildCount >= 2) and
        EvaluateIntegerConstant(Child.ChildAt(0), CondValue) then
      begin
        if CondValue <> 0 then
          BranchNode := Child.ChildAt(1)
        else if Child.ChildCount >= 3 then
          BranchNode := Child.ChildAt(2)
        else
          BranchNode := nil;
        if BranchNode <> nil then
          WalkHaltCalls(BranchNode);
        Continue;
      end;
      if FNoFold and (Child.ChildCount >= 2) and
        EncodeRuntimeBoolExprFold(Child.ChildAt(0), Operand, True) then
      begin
        LowerRuntimeIfStatement(Child, Operand);
        Continue;
      end;
      WalkHaltCalls(Child);
      Continue;
    end;
    if Child.NodeKind = gnkForStatement then
    begin
      if FNoFold then
        LowerRuntimeForStatement(Child)
      else
        UnrollHaltForLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkWhileStatement then
    begin
      if FNoFold then
        LowerRuntimeWhileStatement(Child)
      else
        UnrollHaltWhileLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkRepeatStatement then
    begin
      if FNoFold then
        LowerRuntimeRepeatStatement(Child)
      else
        UnrollHaltRepeatLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkCaseStatement then
    begin
      if FNoFold then
        LowerRuntimeCaseStatement(Child)
      else
        WalkHaltCalls(Child);
      Continue;
    end;
    if (Child.NodeKind = gnkTryFinallyStatement) and FNoFold then
    begin
      LowerRuntimeTryFinallyStatement(Child);
      Continue;
    end;
    if (Child.NodeKind = gnkTryExceptStatement) and FNoFold then
    begin
      LowerRuntimeTryExceptStatement(Child);
      Continue;
    end;
    if (Child.NodeKind = gnkRaiseStatement) and FNoFold then
    begin
      if (Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) then
      begin
        if EncodeRuntimeIntExprFold(Child.ChildAt(0), Operand) then
          FModel.AddTypedHirNode('raise-runtime', 'raise', 0, 0, Operand)
        else
          FModel.AddTypedHirNode('raise-runtime', 'raise', 0, 0, '');
      end
      else
        FModel.AddTypedHirNode('raise-runtime', 'raise', 0, 0, '');
      FCurrentBlockTerminated := True;
      Continue;
    end;
    if (Child.NodeKind = gnkBreakStatement) and FNoFold then
    begin
      if FBreakLabels.Count > 0 then
        EmitGotoLabel(FBreakLabels.Last);
      FCurrentBlockTerminated := True;
      Continue;
    end;
    if (Child.NodeKind = gnkContinueStatement) and FNoFold then
    begin
      if FContinueLabels.Count > 0 then
        EmitGotoLabel(FContinueLabels.Last);
      FCurrentBlockTerminated := True;
      Continue;
    end;
    if (Child.NodeKind = gnkExitStatement) and FNoFold then
    begin
      EmitOwnedManagedRecordCleanupNodes;
      EmitOwnedDynArrayCleanupNodes;
      EmitOwnedStringCleanupNodes(FCurrentRetVarName);
      if (FCurrentRetVarName <> '') and IsRuntimeStrVar(FCurrentRetVarName) then
      begin
        if FCurrentOwnedStringReturn then
          FModel.AddTypedHirNode('ret-tstring-runtime', FCurrentRetVarName,
            0, 0, FCurrentRetVarName)
        else
          FModel.AddTypedHirNode('ret-tstring-runtime', FCurrentRetVarName, 0, 0,
            FCurrentRetVarName);
      end
      else if FCurrentRetVarName <> '' then
      begin
        NodeId := FModel.AddTypedHirNode('ret-runtime', FCurrentRetVarName, 0, 0,
          'var ' + FCurrentRetVarName + #10);
        AttachRuntimeReturnExpr(NodeId, FCurrentRetVarName);
      end
      else
        FModel.AddTypedHirNode('ret-runtime', '0', 0, 0, 'int 0' + #10);
      FCurrentBlockTerminated := True;
      Continue;
    end;
    if Child.NodeKind = gnkAssignmentStatement then
    begin
      Decoded := Child.Text;
      if (Decoded = 'Result') and (FCurrentRetVarName <> '') then
        Decoded := FCurrentRetVarName;
      Arg := nil;
      if Child.ChildCount >= 2 then
        Arg := Child.ChildAt(1);
      if FNoFold and (Arg <> nil) and
        (Arg.NodeKind = gnkFunctionCall) and
        TryGetIntrinsicExprName(Arg, FuncName) and
        SameText(FuncName, 'Default') and IsRecordVar(Decoded) then
      begin
        StringValue := LookupRecordVar(Decoded);
        Value := TypeMetaSize(StringValue);
        if (StringValue <> '') and (Value > 0) then
        begin
          FModel.AddTypedHirNode(
            'fillchar-runtime',
            Decoded,
            0,
            0,
            Decoded + #9 + 'int ' + IntToStr(Value div 8) + #10 +
            #9 + 'int 0' + #10
          );
          Continue;
        end;
      end;
      if FNoFold and (Child.ChildCount >= 2) and
        (Child.ChildAt(0) <> nil) and
        (Child.ChildAt(0).NodeKind = gnkDereference) and
        (Child.ChildAt(0).ChildCount >= 1) and
        (Child.ChildAt(0).ChildAt(0) <> nil) then
      begin
        Arg := Child.ChildAt(1);
        if (Arg <> nil) and EncodeRuntimeIntExprFold(Arg, Operand) then
        begin
          FModel.AddTypedHirNode(
            'assign-runtime', '*' + Child.ChildAt(0).ChildAt(0).Text, 0, 0,
            '*' + Child.ChildAt(0).ChildAt(0).Text + #9 + Operand
          );
        end;
        Continue;
      end
      else if (Child.ChildCount >= 1) and
        (Child.ChildAt(0).NodeKind = gnkDotAccess) and
        (Child.ChildAt(0).ChildCount >= 2) then
      begin
        Arg := nil;
        if Child.ChildCount >= 2 then
          Arg := Child.ChildAt(1);
        if TryAddArrayBackedFieldStoreRuntimeNode(Child.ChildAt(0), Arg) then
          Continue;

        Decoded := Child.ChildAt(0).ChildAt(0).Text + '.' +
          Child.ChildAt(0).ChildAt(1).Text;
        if FNoFold and (IsRecordVar(Child.ChildAt(0).ChildAt(0).Text) or
          (SameText(Child.ChildAt(0).ChildAt(0).Text, 'Result') and
           (FCurrentRetVarName <> '') and IsRecordVar(FCurrentRetVarName))) then
        begin
          if SameText(Child.ChildAt(0).ChildAt(0).Text, 'Result') and
            (FCurrentRetVarName <> '') then
            StringValue := LookupRecordVar(FCurrentRetVarName)
          else
            StringValue := LookupRecordVar(Child.ChildAt(0).ChildAt(0).Text);
          Value := -1;
          if StringValue <> '' then
            Value := TypeMetaFieldIndex(StringValue,
              Child.ChildAt(0).ChildAt(1).Text);
          if Value >= 0 then
          begin
            Arg := nil;
            if Child.ChildCount >= 2 then
              Arg := Child.ChildAt(1);
            if (Arg <> nil) and EncodeRuntimeIntExprFold(Arg, Operand) then
            begin
              if SameText(Child.ChildAt(0).ChildAt(0).Text, 'Result') and
                (FCurrentRetVarName <> '') then
                AddRecordFieldStoreRuntimeNode(
                  Decoded,
                  FCurrentRetVarName + #9 +
                  IntToStr(Value) + #9 + Operand,
                  Child.ChildAt(0),
                  Arg
                )
              else
                AddRecordFieldStoreRuntimeNode(
                  Decoded,
                  Child.ChildAt(0).ChildAt(0).Text + #9 +
                  IntToStr(Value) + #9 + Operand,
                  Child.ChildAt(0),
                  Arg
                );
            end;
            Continue;
          end;
        end;
        if FNoFold and
          (Child.ChildAt(0).ChildAt(0) <> nil) and
          (Child.ChildAt(0).ChildAt(0).NodeKind = gnkArrayAccess) and
          (Child.ChildAt(0).ChildAt(0).ChildCount >= 2) and
          (Child.ChildAt(0).ChildAt(0).ChildAt(0) <> nil) and
          IsRuntimeArrVar(Child.ChildAt(0).ChildAt(0).ChildAt(0).Text) then
        begin
          FuncName := Child.ChildAt(0).ChildAt(0).ChildAt(0).Text;
          if FModel.LookupStringConstValue(FuncName + '$arr_elem_type', StringValue) and
            (TypeMetaFieldIndex(StringValue, Child.ChildAt(0).ChildAt(1).Text) >= 0) and
            FModel.LookupConstValue(FuncName + '$arr_elem_size', CondValue) then
          begin
            Value := TypeMetaFieldIndex(StringValue,
              Child.ChildAt(0).ChildAt(1).Text);
            Arg := nil;
            if Child.ChildCount >= 2 then
              Arg := Child.ChildAt(1);
            if (Arg <> nil) and
              EncodeRuntimeIntExprFold(Child.ChildAt(0).ChildAt(0).ChildAt(1), Operand) and
              EncodeRuntimeIntExprFold(Arg, StringValue) then
              AddArrayRecordFieldStoreRuntimeNode(
                FuncName,
                FuncName + #9 + Operand + 'int ' + IntToStr(CondValue div 8) +
                #10 + 'mul' + #10 + 'int ' + IntToStr(Value) + #10 + 'add' + #10 +
                #9 + StringValue,
                Child.ChildAt(0),
                Arg
              );
            Continue;
          end;
        end;
        if FNoFold and
          (Child.ChildAt(0).ChildAt(0) <> nil) and
          (Child.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
          (Child.ChildAt(0).ChildAt(1) <> nil) and
          (Child.ChildAt(0).ChildAt(1).NodeKind = gnkIdentifier) and
          (((LookupClassVar(Child.ChildAt(0).ChildAt(0).Text) <> '') and
            TypeMetaFieldIsStr(
              LookupClassVar(Child.ChildAt(0).ChildAt(0).Text),
              Child.ChildAt(0).ChildAt(1).Text)) or
           (SameText(Child.ChildAt(0).ChildAt(0).Text, 'Self') and
            (FCurrentMethodClass <> '') and
            TypeMetaFieldIsStr(
              FCurrentMethodClass,
              Child.ChildAt(0).ChildAt(1).Text))) then
        begin
          if SameText(Child.ChildAt(0).ChildAt(0).Text, 'Self') then
          begin
            OwnerClassName := FCurrentMethodClass;
            ArgName := 'self';
          end
          else
          begin
            OwnerClassName := LookupClassVar(Child.ChildAt(0).ChildAt(0).Text);
            ArgName := Child.ChildAt(0).ChildAt(0).Text;
          end;
          Value := TypeMetaFieldIndex(
            OwnerClassName,
            Child.ChildAt(0).ChildAt(1).Text);
          Arg := nil;
          if Child.ChildCount >= 2 then
            Arg := Child.ChildAt(1);
          if Arg <> nil then
          begin
            if AssignmentOwnsTopLevelStringReturn(Child) and
              StringReturnFunctionNameFromNode(Arg, FuncName) and
              IsOwnedStringReturnFunc(FuncName) then
            begin
              Inc(FBlockLabelCounter);
              StringValue := '$str_field_owned_tmp_' + IntToStr(FBlockLabelCounter);
              RegisterRuntimeVar(StringValue);
              RegisterRuntimeStrVar(StringValue);
              RegisterOwnedRuntimeStrVar(StringValue);
              FModel.AddTypedHirNode(
                'var-decl-tstring-runtime', StringValue, 0, 0, StringValue);
              if Arg.NodeKind = gnkIdentifier then
                FModel.AddTypedHirNode(
                  'string-temp-owned-runtime', FuncName, 0, 0,
                  StringValue + #9 + 'callee ' + FuncName + #9 +
                  'ptr len owner alloc_size')
              else
              begin
                Operand := EncodeStrCallArgs(Arg, StringValue);
                if Operand <> '' then
                  Operand := #9 + Operand;
                FModel.AddTypedHirNode(
                  'assign-tstring-call-runtime', StringValue, 0, 0,
                  StringValue + #9 + 'callee ' + FuncName + Operand);
                EmitPendingStringTempReleases;
              end;
              AddFieldStoreStrOwnedRuntimeNode(
                Decoded,
                ArgName + #9 + IntToStr(Value) +
                #9 + StringValue,
                Child.ChildAt(0)
              );
              Continue;
            end;
            if Arg.NodeKind = gnkStringLiteral then
              FModel.AddTypedHirNode(
                'field-store-tstring-runtime', Decoded, 0, 0,
                ArgName + #9 +
                IntToStr(Value) + #9 + 'lit ' +
                DecodePascalStringLiteral(Arg.Text)
              )
            else if EvaluateStringConstant(Arg, StringValue) then
              FModel.AddTypedHirNode(
                'field-store-tstring-runtime', Decoded, 0, 0,
                ArgName + #9 +
                IntToStr(Value) + #9 + 'lit ' + StringValue
              )
            else if (Arg.NodeKind = gnkIdentifier) and
              IsRuntimeStrVar(Arg.Text) then
              FModel.AddTypedHirNode(
                'field-store-tstring-runtime', Decoded, 0, 0,
                ArgName + #9 +
                IntToStr(Value) + #9 + 'var ' + Arg.Text
              )
            else if (Arg.NodeKind = gnkDotAccess) and
              (Arg.ChildCount >= 2) and (Arg.ChildAt(0) <> nil) and
              (Arg.ChildAt(1) <> nil) and
              (Arg.ChildAt(0).NodeKind = gnkIdentifier) and
              (Arg.ChildAt(1).NodeKind = gnkIdentifier) and
              (LookupClassVar(Arg.ChildAt(0).Text) <> '') and
              TypeMetaFieldIsStr(LookupClassVar(Arg.ChildAt(0).Text),
                Arg.ChildAt(1).Text) then
            begin
              Inc(FBlockLabelCounter);
              FuncName := '$str_field_tmp_' + IntToStr(FBlockLabelCounter);
              RegisterRuntimeVar(FuncName);
              RegisterRuntimeStrVar(FuncName);
              FModel.AddTypedHirNode('var-decl-tstring-runtime', FuncName,
                0, 0, FuncName);
              FModel.AddTypedHirNode('assign-tstring-field-load-runtime',
                FuncName, 0, 0,
                Arg.ChildAt(0).Text + #9 +
                IntToStr(TypeMetaFieldIndex(
                  LookupClassVar(Arg.ChildAt(0).Text), Arg.ChildAt(1).Text)));
              FModel.AddTypedHirNode(
                'field-store-tstring-runtime', Decoded, 0, 0,
                ArgName + #9 +
                IntToStr(Value) + #9 + 'var ' + FuncName
              );
            end;
          end;
          Continue;
        end;
      end;
      if FNoFold and (Child.ChildCount >= 1) and
        (Child.ChildAt(0).NodeKind = gnkArrayAccess) and
        (Child.ChildAt(0).ChildCount >= 2) and
        (Child.ChildAt(0).ChildAt(0) <> nil) and
        (Child.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
        IsRuntimeArrVar(Child.ChildAt(0).ChildAt(0).Text) then
      begin
        Decoded := Child.ChildAt(0).ChildAt(0).Text;
        RhsNode := nil;
        if Child.ChildCount >= 2 then
          RhsNode := Child.ChildAt(1);
        if (RhsNode <> nil) and
          EncodeRuntimeIntExprFold(Child.ChildAt(0).ChildAt(1), Operand) then
        begin
          if EncodeRuntimeIntExprFold(RhsNode, StringValue) then
            AddArrayElementStoreRuntimeNode(
              Decoded,
              Decoded + #9 + Operand + #9 + StringValue,
              Child.ChildAt(0),
              RhsNode
            )
          else if (RhsNode.NodeKind = gnkFunctionCall) and
            (RhsNode.ChildCount >= 1) and (RhsNode.ChildAt(0) <> nil) and
            (RhsNode.ChildAt(0).NodeKind = gnkDotAccess) and
            (RhsNode.ChildAt(0).ChildCount >= 2) and
            (RhsNode.ChildAt(0).ChildAt(0) <> nil) and
            (TypeMetaSize(RhsNode.ChildAt(0).ChildAt(0).Text) > 0) then
          begin
            Inc(FBlockLabelCounter);
            FuncName := '$arr_obj_' + IntToStr(FBlockLabelCounter);
            Value := TypeMetaSize(RhsNode.ChildAt(0).ChildAt(0).Text);
            StringValue := FuncName + #9 +
              RhsNode.ChildAt(0).ChildAt(0).Text + '.' +
              RhsNode.ChildAt(0).ChildAt(1).Text;
            for K := 1 to RhsNode.ChildCount - 1 do
              if (RhsNode.ChildAt(K) <> nil) and
                EncodeRuntimeIntExprFold(RhsNode.ChildAt(K), ArgName) then
                StringValue := StringValue + #9 + ArgName;
            RegisterRuntimeVar(FuncName);
            RegisterClassVar(FuncName, RhsNode.ChildAt(0).ChildAt(0).Text);
            FModel.AddTypedHirNode(
              'class-new-runtime', IntToStr(Value), 0, 0, StringValue);
            if (TypeMetaVmtCount(RhsNode.ChildAt(0).ChildAt(0).Text) > 0) or
              (TypeMetaInterfaces(RhsNode.ChildAt(0).ChildAt(0).Text) <> '') then
              FModel.AddTypedHirNode('vmt-store-runtime',
                RhsNode.ChildAt(0).ChildAt(0).Text, 0, 0,
                FuncName + #9 + RhsNode.ChildAt(0).ChildAt(0).Text);
            FModel.AddTypedHirNode(
              'assign-arr-elem-runtime', Decoded, 0, 0,
              Decoded + #9 + Operand + #9 + 'var ' + FuncName + #10
            );
          end;
        end;
        Continue;
      end;
      if FNoFold and (FCurrentMethodClass <> '') and
        (Child.ChildCount >= 1) and
        (Child.ChildAt(0).NodeKind = gnkArrayAccess) and
        (Child.ChildAt(0).ChildCount >= 2) and
        TryCurrentClassFieldArrayAccess(Child.ChildAt(0), FuncName) then
      begin
        Value := TypeMetaFieldIndex(FCurrentMethodClass, FuncName);
        RhsNode := nil;
        if Child.ChildCount >= 2 then
          RhsNode := Child.ChildAt(1);
        if (RhsNode <> nil) and
          EncodeRuntimeIntExprFold(Child.ChildAt(0).ChildAt(1), Operand) and
          EncodeRuntimeIntExprFold(RhsNode, StringValue) then
          AddArrayElementStoreRuntimeNode(
            '__field_arr__',
            'self' + #9 + IntToStr(Value) + #9 + Operand + #9 + StringValue,
            Child.ChildAt(0),
            RhsNode
          );
        Continue;
      end;
      Arg := nil;
      if Child.ChildCount >= 2 then
        Arg := Child.ChildAt(1)
      else if (Child.ChildCount = 1) and
        (Child.ChildAt(0).NodeKind <> gnkIdentifier) and
        (Child.ChildAt(0).NodeKind <> gnkDotAccess) and
        (Child.ChildAt(0).NodeKind <> gnkArrayAccess) then
        Arg := Child.ChildAt(0);
      if FNoFold and (Arg <> nil) and
        (Arg.NodeKind = gnkFunctionCall) and (Arg.ChildCount >= 1) and
        (Arg.ChildAt(0) <> nil) and
        (Arg.ChildAt(0).NodeKind = gnkDotAccess) and
        (Arg.ChildAt(0).ChildCount >= 2) then
      begin
        InhParentName := Arg.ChildAt(0).ChildAt(0).Text;
        StringValue := InhParentName + '.' +
          Arg.ChildAt(0).ChildAt(1).Text;
        if TypeMetaSize(InhParentName) > 0 then
        begin
          Value := TypeMetaSize(InhParentName);
          if FModel.FindSymbolByName(StringValue) = 0 then
          begin
            InhTypeId := FModel.FindTypeByName(InhParentName);
            while (InhTypeId > 0) and
              (FModel.FindSymbolByName(InhParentName + '.' +
                Arg.ChildAt(0).ChildAt(1).Text) = 0) do
            begin
              InhParentName := NextClassAncestorName(InhParentName);
              if InhParentName = '' then
                Break;
              InhTypeId := FModel.FindTypeByName(InhParentName);
            end;
            StringValue := InhParentName + '.' +
              Arg.ChildAt(0).ChildAt(1).Text;
          end;
          Operand := Decoded + #9 + StringValue;
          for ArgIndex := 1 to Arg.ChildCount - 1 do
          begin
            RhsNode := Arg.ChildAt(ArgIndex);
            if RhsNode = nil then
              Continue;
            if (RhsNode.NodeKind = gnkStringLiteral) then
            begin
              Inc(FBlockLabelCounter);
              FuncName := '$str_arg_' + IntToStr(FBlockLabelCounter);
              RegisterRuntimeVar(FuncName);
              RegisterRuntimeStrVar(FuncName);
              FModel.AddTypedHirNode('var-decl-tstring-runtime', FuncName, 0, 0, FuncName);
              FModel.AddTypedHirNode('assign-tstring-literal-runtime',
                FuncName, 0, 0, DecodePascalStringLiteral(RhsNode.Text));
              Operand := Operand + #9 + 'strvar ' + FuncName + #10;
            end
            else if (RhsNode.NodeKind = gnkIdentifier) and
              IsRuntimeStrVar(RhsNode.Text) then
              Operand := Operand + #9 + 'strvar ' + RhsNode.Text + #10
            else if EncodeRuntimeIntExprFold(RhsNode, StringValue) then
              Operand := Operand + #9 + StringValue
            else if (RhsNode.NodeKind = gnkFunctionCall) and
              (RhsNode.ChildCount >= 1) and (RhsNode.ChildAt(0) <> nil) and
              (RhsNode.ChildAt(0).NodeKind = gnkDotAccess) and
              (RhsNode.ChildAt(0).ChildCount >= 2) and
              (RhsNode.ChildAt(0).ChildAt(0) <> nil) and
              (TypeMetaSize(RhsNode.ChildAt(0).ChildAt(0).Text) > 0) then
            begin
              Inc(FBlockLabelCounter);
              FuncName := '$arg_tmp_' + IntToStr(FBlockLabelCounter);
              Value := TypeMetaSize(RhsNode.ChildAt(0).ChildAt(0).Text);
              StringValue := FuncName + #9 +
                RhsNode.ChildAt(0).ChildAt(0).Text + '.' +
                RhsNode.ChildAt(0).ChildAt(1).Text;
              for K := 1 to RhsNode.ChildCount - 1 do
                if (RhsNode.ChildAt(K) <> nil) and
                  EncodeRuntimeIntExprFold(RhsNode.ChildAt(K), ArgName) then
                  StringValue := StringValue + #9 + ArgName;
              RegisterRuntimeVar(FuncName);
              RegisterClassVar(FuncName, RhsNode.ChildAt(0).ChildAt(0).Text);
              FModel.AddTypedHirNode(
                'class-new-runtime', IntToStr(Value), 0, 0, StringValue);
              if (TypeMetaVmtCount(RhsNode.ChildAt(0).ChildAt(0).Text) > 0) or
              (TypeMetaInterfaces(RhsNode.ChildAt(0).ChildAt(0).Text) <> '') then
                FModel.AddTypedHirNode('vmt-store-runtime',
                  RhsNode.ChildAt(0).ChildAt(0).Text, 0, 0,
                  FuncName + #9 + RhsNode.ChildAt(0).ChildAt(0).Text);
              Operand := Operand + #9 + 'var ' + FuncName + #10;
            end;
          end;
          CondValue := -1;
          if FCurrentMethodClass <> '' then
            CondValue := TypeMetaFieldIndex(FCurrentMethodClass, Decoded);
          if CondValue >= 0 then
          begin
            Inc(FBlockLabelCounter);
            FuncName := '$obj_tmp_' + IntToStr(FBlockLabelCounter);
            Operand := FuncName + #9 +
              Copy(Operand, Pos(#9, Operand) + 1, Length(Operand));
            RegisterRuntimeVar(FuncName);
            RegisterClassVar(FuncName, Arg.ChildAt(0).ChildAt(0).Text);
            FModel.AddTypedHirNode(
              'class-new-runtime', IntToStr(Value), 0, 0, Operand
            );
            if (TypeMetaVmtCount(Arg.ChildAt(0).ChildAt(0).Text) > 0) or
              (TypeMetaInterfaces(Arg.ChildAt(0).ChildAt(0).Text) <> '') then
              FModel.AddTypedHirNode('vmt-store-runtime',
                Arg.ChildAt(0).ChildAt(0).Text, 0, 0,
                FuncName + #9 + Arg.ChildAt(0).ChildAt(0).Text);
            FModel.AddTypedHirNode('field-store-runtime', Decoded, 0, 0,
              'self' + #9 + IntToStr(CondValue) + #9 +
              'var ' + FuncName + #10);
          end
          else
          begin
            RegisterRuntimeVar(Decoded);
            RegisterClassVar(Decoded, Arg.ChildAt(0).ChildAt(0).Text);
            FModel.AddTypedHirNode(
              'class-new-runtime', IntToStr(Value), 0, 0, Operand
            );
            if (TypeMetaVmtCount(Arg.ChildAt(0).ChildAt(0).Text) > 0) or
              (TypeMetaInterfaces(Arg.ChildAt(0).ChildAt(0).Text) <> '') then
              FModel.AddTypedHirNode('vmt-store-runtime',
                Arg.ChildAt(0).ChildAt(0).Text, 0, 0,
                Decoded + #9 + Arg.ChildAt(0).ChildAt(0).Text);
            if (LookupClassVar(Decoded) <> '') and
              (TypeMetaIsInterface(LookupClassVar(Decoded))) and
              FModel.LookupConstValue(
                Arg.ChildAt(0).ChildAt(0).Text + '$intf_offset_' + LookupClassVar(Decoded),
                Value) then
            begin
              FModel.AddTypedHirNode('intf-addref-runtime', Decoded, 0, 0, Decoded);
              FModel.AddTypedHirNode('intf-adjust-runtime', Decoded, 0, 0,
                Decoded + #9 + IntToStr(Value div 8));
            end;
          end;
          Continue;
        end;
      end;
      if FNoFold and (Arg <> nil) and
        (Arg.NodeKind = gnkDotAccess) and (Arg.ChildCount >= 2) and
        (Arg.ChildAt(0) <> nil) and (Arg.ChildAt(1) <> nil) then
      begin
        Value := TypeMetaSize(Arg.ChildAt(0).Text);
        if Value > 0 then
        begin
          InhParentName := Arg.ChildAt(0).Text;
          StringValue := InhParentName + '.' + Arg.ChildAt(1).Text;
          if FModel.FindSymbolByName(StringValue) = 0 then
          begin
            InhTypeId := FModel.FindTypeByName(InhParentName);
            while (InhTypeId > 0) and
              (FModel.FindSymbolByName(InhParentName + '.' +
                Arg.ChildAt(1).Text) = 0) do
            begin
              InhParentName := NextClassAncestorName(InhParentName);
              if InhParentName = '' then
                Break;
              InhTypeId := FModel.FindTypeByName(InhParentName);
            end;
            StringValue := InhParentName + '.' + Arg.ChildAt(1).Text;
          end;
          Operand := Decoded + #9 + StringValue;
          RegisterRuntimeVar(Decoded);
          RegisterClassVar(Decoded, Arg.ChildAt(0).Text);
          FModel.AddTypedHirNode(
            'class-new-runtime', IntToStr(Value), 0, 0, Operand
          );
          if (TypeMetaVmtCount(Arg.ChildAt(0).Text) > 0) or
            (TypeMetaInterfaces(Arg.ChildAt(0).Text) <> '') then
            FModel.AddTypedHirNode('vmt-store-runtime',
              Arg.ChildAt(0).Text, 0, 0,
              Decoded + #9 + Arg.ChildAt(0).Text);
          if (LookupClassVar(Decoded) <> '') and
            TypeMetaIsInterface(LookupClassVar(Decoded)) and
            FModel.LookupConstValue(
              Arg.ChildAt(0).Text + '$intf_offset_' + LookupClassVar(Decoded),
              Value) then
          begin
            FModel.AddTypedHirNode('intf-addref-runtime', Decoded, 0, 0, Decoded);
            FModel.AddTypedHirNode('intf-adjust-runtime', Decoded, 0, 0,
              Decoded + #9 + IntToStr(Value div 8));
          end;
          Continue;
        end;
      end;
      if Arg <> nil then
      begin
        { Check if destination is a class field — must use field-store,
          not assign-tstring-copy, because fields have no local alloca }
        if FNoFold and (FCurrentMethodClass <> '') and
          TypeMetaFieldIsStr(FCurrentMethodClass, Decoded) then
        begin
          Value := TypeMetaFieldIndex(FCurrentMethodClass, Decoded);
          if Arg.NodeKind = gnkStringLiteral then
            FModel.AddTypedHirNode(
              'field-store-tstring-runtime', Decoded, 0, 0,
              'self' + #9 +
              IntToStr(Value) + #9 + 'lit ' +
              DecodePascalStringLiteral(Arg.Text)
            )
          else if EvaluateStringConstant(Arg, StringValue) then
            FModel.AddTypedHirNode(
              'field-store-tstring-runtime', Decoded, 0, 0,
              'self' + #9 +
              IntToStr(Value) + #9 + 'lit ' + StringValue
            )
          else if (Arg.NodeKind = gnkIdentifier) and
            IsRuntimeStrVar(Arg.Text) then
          begin
            { Check if source is also a class field — needs temp + field-load }
            if (FCurrentMethodClass <> '') and
              TypeMetaFieldIsStr(FCurrentMethodClass, Arg.Text) then
            begin
              Inc(FBlockLabelCounter);
              FuncName := '$str_field_tmp_' + IntToStr(FBlockLabelCounter);
              RegisterRuntimeVar(FuncName);
              RegisterRuntimeStrVar(FuncName);
              FModel.AddTypedHirNode('var-decl-tstring-runtime', FuncName,
                0, 0, FuncName);
              FModel.AddTypedHirNode('assign-tstring-field-load-runtime',
                FuncName, 0, 0,
                'self' + #9 +
                IntToStr(TypeMetaFieldIndex(FCurrentMethodClass, Arg.Text)));
              FModel.AddTypedHirNode(
                'field-store-tstring-runtime', Decoded, 0, 0,
                'self' + #9 +
                IntToStr(Value) + #9 + 'var ' + FuncName
              );
            end
            else
              FModel.AddTypedHirNode(
                'field-store-tstring-runtime', Decoded, 0, 0,
                'self' + #9 +
                IntToStr(Value) + #9 + 'var ' + Arg.Text
              );
          end
          else if (Arg.NodeKind = gnkDotAccess) and
            (Arg.ChildCount >= 2) and (Arg.ChildAt(0) <> nil) and
            (Arg.ChildAt(1) <> nil) and
            (Arg.ChildAt(0).NodeKind = gnkIdentifier) and
            (Arg.ChildAt(1).NodeKind = gnkIdentifier) and
            (LookupClassVar(Arg.ChildAt(0).Text) <> '') and
            TypeMetaFieldIsStr(LookupClassVar(Arg.ChildAt(0).Text),
              Arg.ChildAt(1).Text) then
          begin
            Inc(FBlockLabelCounter);
            FuncName := '$str_field_tmp_' + IntToStr(FBlockLabelCounter);
            RegisterRuntimeVar(FuncName);
            RegisterRuntimeStrVar(FuncName);
            FModel.AddTypedHirNode('var-decl-tstring-runtime', FuncName,
              0, 0, FuncName);
            FModel.AddTypedHirNode('assign-tstring-field-load-runtime',
              FuncName, 0, 0,
              Arg.ChildAt(0).Text + #9 +
              IntToStr(TypeMetaFieldIndex(
                LookupClassVar(Arg.ChildAt(0).Text), Arg.ChildAt(1).Text)));
            FModel.AddTypedHirNode(
              'field-store-tstring-runtime', Decoded, 0, 0,
              'self' + #9 +
              IntToStr(Value) + #9 + 'var ' + FuncName
            );
          end
          else if (Arg.NodeKind = gnkBinaryExpression) and
            (Arg.Text = '+') and (Arg.ChildCount >= 2) and
            (Arg.ChildAt(0) <> nil) and (Arg.ChildAt(1) <> nil) then
          begin
            { String concat into a class field: load operands to temps,
              concat into result temp, then field-store }
            StringValue := EmitStrConcatOperand(Arg.ChildAt(0), Decoded);
            if StringValue <> '' then
            begin
              Operand := EmitStrConcatOperand(Arg.ChildAt(1), Decoded);
              if Operand <> '' then
              begin
                Inc(FBlockLabelCounter);
                FuncName := '$str_field_concat_tmp_' + IntToStr(FBlockLabelCounter);
                RegisterRuntimeVar(FuncName);
                RegisterRuntimeStrVar(FuncName);
                FModel.AddTypedHirNode('var-decl-tstring-runtime', FuncName,
                  0, 0, FuncName);
                FModel.AddTypedHirNode(
                  'assign-tstring-concat-runtime', FuncName, 0, 0,
                  FuncName + #9 + StringValue + #9 + Operand
                );
                EmitPendingStringTempReleases;
                FModel.AddTypedHirNode(
                  'field-store-tstring-runtime', Decoded, 0, 0,
                  'self' + #9 +
                  IntToStr(Value) + #9 + 'var ' + FuncName
                );
              end;
            end;
          end;
          Continue;
        end;
        if FNoFold and IsRuntimeStrVar(Decoded) then
        begin
          if (Arg.NodeKind = gnkStringLiteral) then
          begin
            StringValue := DecodePascalStringLiteral(Arg.Text);
            if FCurrentOwnedStringReturn and SameText(Decoded, FCurrentRetVarName) then
              FModel.AddTypedHirNode(
                'assign-tstring-literal-runtime', Decoded, 0, 0, StringValue)
            else
              FModel.AddTypedHirNode(
                'assign-tstring-literal-runtime', Decoded, 0, 0, StringValue
              );
          end
          else if EvaluateStringConstant(Arg, StringValue) then
          begin
            if FCurrentOwnedStringReturn and SameText(Decoded, FCurrentRetVarName) then
              FModel.AddTypedHirNode(
                'assign-tstring-literal-runtime', Decoded, 0, 0, StringValue)
            else
              FModel.AddTypedHirNode(
                'assign-tstring-literal-runtime', Decoded, 0, 0, StringValue
              );
          end
          else if (Arg.NodeKind = gnkIdentifier) and
            IsRuntimeStrVar(Arg.Text) and
            not LookupProcedureBody(Arg.Text, BranchNode, DeclNode) then
          begin
            if FCurrentOwnedStringReturn and SameText(Decoded, FCurrentRetVarName) and
              IsOwnedRuntimeStrVar(Arg.Text) then
              FModel.AddTypedHirNode(
                'assign-tstring-copy-runtime', Arg.Text, 0, 0, Decoded)
            else
              FModel.AddTypedHirNode(
                'assign-tstring-copy-runtime', Arg.Text, 0, 0, Decoded
              );
          end
          else if (Arg.NodeKind = gnkFunctionCall) and
            (Arg.ChildCount >= 2) and (Arg.ChildAt(0) <> nil) and
            SameText(Arg.ChildAt(0).Text, 'IntToStr') then
          begin
            if EncodeRuntimeIntExprFold(Arg.ChildAt(1), Operand) then
            begin
              FModel.AddTypedHirNode(
                'tstring-from-int-runtime', Decoded, 0, 0,
                Decoded + #9 + Operand
              );
            end;
          end
          else if (Arg.NodeKind = gnkFunctionCall) and
            (Arg.ChildCount >= 4) and (Arg.ChildAt(0) <> nil) and
            SameText(Arg.ChildAt(0).Text, 'Copy') then
          begin
            if not EmitOwnedStringCopyTemp(Arg, Decoded, Operand) then
            begin
              if (Arg.ChildAt(1) <> nil) and
                (Arg.ChildAt(1).NodeKind = gnkIdentifier) and
                IsRuntimeStrVar(Arg.ChildAt(1).Text) and
                EncodeRuntimeIntExprFold(Arg.ChildAt(2), Operand) and
                EncodeRuntimeIntExprFold(Arg.ChildAt(3), StringValue) then
                FModel.AddTypedHirNode(
                  'tstring-copy-runtime', Decoded, 0, 0,
                  Decoded + #9 + Arg.ChildAt(1).Text + #9 + Operand + #9 + StringValue
                );
            end;
          end
          else if (Arg.NodeKind = gnkIdentifier) and
            (FCurrentMethodClass <> '') and
            TypeMetaFieldIsStr(FCurrentMethodClass, Arg.Text) then
          begin
            Value := TypeMetaFieldIndex(FCurrentMethodClass, Arg.Text);
            FModel.AddTypedHirNode(
              'assign-tstring-field-load-runtime', Decoded, 0, 0,
              Decoded + #9 + IntToStr(Value)
            );
          end
          else if (Arg.NodeKind = gnkIdentifier) and
            LookupProcedureBody(Arg.Text, BranchNode, DeclNode) and
            IsOwnedStringReturnFunc(Arg.Text) then
          begin
            FModel.AddTypedHirNode(
              'assign-tstring-call-runtime', Decoded, 0, 0,
              Decoded + #9 + 'callee ' + Arg.Text
            );
          end
          else if (Arg.NodeKind = gnkIdentifier) and
            LookupProcedureBody(Arg.Text, BranchNode, DeclNode) and
            IsRuntimeStrVar(Arg.Text) then
          begin
            FModel.AddTypedHirNode(
              'assign-tstring-call-runtime', Decoded, 0, 0,
              Decoded + #9 + 'callee ' + Arg.Text
            );
          end
          else if (Arg.NodeKind = gnkFunctionCall) and
            LookupProcedureBody(Arg.Text, BranchNode, DeclNode) and
            IsOwnedStringReturnFunc(Arg.Text) then
          begin
            Operand := EncodeStrCallArgs(Arg, Decoded);
            FModel.AddTypedHirNode(
              'assign-tstring-call-runtime', Decoded, 0, 0,
              Decoded + #9 + 'callee ' + Arg.Text + #9 + Operand
            );
            EmitPendingStringTempReleases;
          end
          else if (Arg.NodeKind = gnkFunctionCall) and
            LookupProcedureBody(Arg.Text, BranchNode, DeclNode) and
            IsRuntimeStrVar(Arg.Text) then
          begin
            Operand := EncodeStrCallArgs(Arg, Decoded);
            FModel.AddTypedHirNode(
              'assign-tstring-call-runtime', Decoded, 0, 0,
              Decoded + #9 + 'callee ' + Arg.Text + #9 + Operand
            );
            EmitPendingStringTempReleases;
          end
          else if (Arg.NodeKind = gnkDotAccess) and
            (Arg.ChildCount >= 2) and
            (Arg.ChildAt(0) <> nil) and
            (Arg.ChildAt(1) <> nil) and
            (Arg.ChildAt(0).NodeKind = gnkIdentifier) and
            (Arg.ChildAt(1).NodeKind = gnkIdentifier) and
            (LookupClassVar(Arg.ChildAt(0).Text) <> '') then
          begin
            FuncName := LookupClassVar(Arg.ChildAt(0).Text);
            Value := TypeMetaVmtSlot(FuncName, Arg.ChildAt(1).Text);
            if (Value >= 0) and TypeMetaIsInterface(FuncName) then
              FModel.AddTypedHirNode(
                'assign-tstring-call-runtime', Arg.ChildAt(1).Text, 0, 0,
                Decoded + #9 + Arg.ChildAt(0).Text + #9 +
                IntToStr(Value)
              )
            else if Value >= 0 then
              FModel.AddTypedHirNode(
                'assign-tstring-call-runtime', Arg.ChildAt(1).Text, 0, 0,
                Decoded + #9 + Arg.ChildAt(0).Text + #9 +
                IntToStr(Value)
              )
            else
              FModel.AddTypedHirNode(
                'assign-tstring-call-runtime',
                FuncName + '.' + Arg.ChildAt(1).Text, 0, 0,
                Decoded + #9 + 'var ' + Arg.ChildAt(0).Text
              );
          end
          else if (Arg.NodeKind = gnkBinaryExpression) and
            (Arg.Text = '+') and (Arg.ChildCount >= 2) and
            (Arg.ChildAt(0) <> nil) and (Arg.ChildAt(1) <> nil) then
          begin
            StringValue := EmitStrConcatOperand(Arg.ChildAt(0), Decoded);
            if StringValue <> '' then
            begin
              Operand := EmitStrConcatOperand(Arg.ChildAt(1), Decoded);
              if Operand <> '' then
              begin
                if IsOwnedRuntimeStrVar(Decoded) then
                  FModel.AddTypedHirNode(
                    'assign-tstring-concat-runtime',
                    Decoded,
                    0, 0,
                    StringValue + #9 + Operand
                  )
                else
                  FModel.AddTypedHirNode(
                    'assign-tstring-concat-runtime',
                    StringValue + #9 + Operand,
                    0, 0, Decoded
                  );
                EmitPendingStringTempReleases;
              end;
            end;
          end;
        end
        else if FNoFold and (FCurrentMethodClass <> '') and
          TypeMetaFieldIsStr(FCurrentMethodClass, Decoded) then
        begin
          Value := TypeMetaFieldIndex(FCurrentMethodClass, Decoded);
          if AssignmentOwnsTopLevelStringReturn(Child) and
            StringReturnFunctionNameFromNode(Arg, FuncName) and
            IsOwnedStringReturnFunc(FuncName) then
          begin
            Inc(FBlockLabelCounter);
            StringValue := '$str_field_owned_tmp_' + IntToStr(FBlockLabelCounter);
            RegisterRuntimeVar(StringValue);
            RegisterRuntimeStrVar(StringValue);
            RegisterOwnedRuntimeStrVar(StringValue);
            FModel.AddTypedHirNode(
              'var-decl-tstring-runtime', StringValue, 0, 0, StringValue);
            if Arg.NodeKind = gnkIdentifier then
              FModel.AddTypedHirNode(
                'string-temp-owned-runtime', FuncName, 0, 0,
                StringValue + #9 + 'callee ' + FuncName + #9 +
                'ptr len owner alloc_size')
            else
            begin
              Operand := EncodeStrCallArgs(Arg, StringValue);
              if Operand <> '' then
                Operand := #9 + Operand;
              FModel.AddTypedHirNode(
                'assign-tstring-call-runtime', StringValue, 0, 0,
                StringValue + #9 + 'callee ' + FuncName + Operand);
              EmitPendingStringTempReleases;
            end;
            AddFieldStoreStrOwnedRuntimeNode(
              Decoded,
              'self' + #9 + IntToStr(Value) + #9 + StringValue,
              Child.ChildAt(0)
            );
            Continue;
          end;
          if (Arg.NodeKind = gnkStringLiteral) then
          begin
            StringValue := DecodePascalStringLiteral(Arg.Text);
            FModel.AddTypedHirNode(
              'field-store-tstring-runtime', Decoded, 0, 0,
              'self' + #9 + IntToStr(Value) + #9 + 'lit ' + StringValue
            );
          end
          else if EvaluateStringConstant(Arg, StringValue) then
            FModel.AddTypedHirNode(
              'field-store-tstring-runtime', Decoded, 0, 0,
              'self' + #9 + IntToStr(Value) + #9 + 'lit ' + StringValue
            )
          else if (Arg.NodeKind = gnkIdentifier) and
            IsRuntimeStrVar(Arg.Text) then
            FModel.AddTypedHirNode(
              'field-store-tstring-runtime', Decoded, 0, 0,
              'self' + #9 + IntToStr(Value) + #9 + 'var ' + Arg.Text
            )
          else if EmitStringFieldStoreRhsTemp(Arg, FuncName) then
            FModel.AddTypedHirNode(
              'field-store-tstring-runtime', Decoded, 0, 0,
              'self' + #9 + IntToStr(Value) + #9 + 'var ' + FuncName
            )
          else
            FModel.AddTypedHirNode(
              'field-store-tstring-runtime', Decoded, 0, 0,
              'self' + #9 + IntToStr(Value) + #9 + 'var ' + Decoded
            );
        end
        else if FNoFold and (Arg <> nil) and
          (Arg.NodeKind = gnkFunctionCall) and (Arg.ChildCount >= 1) and
          (Arg.ChildAt(0) <> nil) and
          (Arg.ChildAt(0).NodeKind = gnkIdentifier) and
          (LookupPtrReturnFunc(Arg.ChildAt(0).Text) <> '') then
        begin
          if EncodeRuntimeIntExprFold(Arg, Operand) then
          begin
            RegisterRuntimeVar(Decoded);
            RegisterClassVar(Decoded, LookupPtrReturnFunc(Arg.ChildAt(0).Text));
            FModel.AddTypedHirNode(
              'var-decl-ptr-runtime', Decoded, 0, 0, Decoded);
            NodeId := FModel.AddTypedHirNode(
              'assign-runtime', Decoded, 0, 0,
              Decoded + #9 + Operand
            );
            if BuildRuntimeScalarHirExpr(Arg, ExprId) then
              FModel.SetTypedHirNodeExprId(NodeId, ExprId);
          end;
        end
        else if FNoFold and IsRecordVar(Decoded) and
          (Arg <> nil) and (Arg.NodeKind = gnkFunctionCall) and
          (Arg.ChildCount >= 1) and (Arg.ChildAt(0) <> nil) and
          (Arg.ChildAt(0).NodeKind = gnkIdentifier) then
        begin
          if LookupProcedureBody(Arg.ChildAt(0).Text, BranchNode, DeclNode) then
          begin
            Operand := Arg.ChildAt(0).Text + #9 + 'recvar ' + Decoded + #10;
            for ArgIndex := 1 to Arg.ChildCount - 1 do
            begin
              RhsNode := Arg.ChildAt(ArgIndex);
              if (RhsNode <> nil) and EncodeRuntimeIntExprFold(RhsNode, StringValue) then
                Operand := Operand + #9 + StringValue;
            end;
            FModel.AddTypedHirNode('call-runtime',
              Arg.ChildAt(0).Text, 0, 0, Operand);
          end;
        end
        else if FNoFold and IsRecordVar(Decoded) and
          (Arg <> nil) and (Arg.NodeKind = gnkIdentifier) and
          IsRecordVar(Arg.Text) then
        begin
          StringValue := LookupRecordVar(Decoded);
          Value := TypeMetaSize(StringValue);
          if Value > 0 then
            FModel.AddTypedHirNode(
              'record-copy-runtime', Decoded, 0, 0,
              Decoded + #9 + Arg.Text + #9 + IntToStr(Value div 8)
            );
        end
        else if FNoFold then
        begin
          if EncodeRuntimeIntExprFold(Arg, Operand) then
          begin
            DotPos := Pos('.', Decoded);
            if (DotPos > 0) and (FCurrentMethodClass = '') then
            begin
              ArgName := Copy(Decoded, 1, DotPos - 1);
              FuncName := Copy(Decoded, DotPos + 1, Length(Decoded));
              StringValue := LookupClassVar(ArgName);
              if (StringValue <> '') and
                FModel.LookupStringConstValue(
                  StringValue + '.' + FuncName + '$write', ArgName) then
              begin
                FModel.AddTypedHirNode(
                  'call-runtime',
                  StringValue + '.' + ArgName, 0, 0,
                  StringValue + '.' + ArgName + #9 +
                  'var ' + Copy(Decoded, 1, DotPos - 1) + #10 + #9 +
                  Operand
                );
              end
              else if StringValue <> '' then
              begin
                Value := TypeMetaFieldIndex(StringValue, FuncName);
                if Value >= 0 then
                  AddFieldStoreRuntimeNode(
                    Decoded,
                    Copy(Decoded, 1, DotPos - 1) + #9 +
                    IntToStr(Value) + #9 + Operand,
                    Child.ChildAt(0),
                    Arg
                  )
                else
                begin
                  RegisterRuntimeVar(Decoded);
                  FModel.AddTypedHirNode(
                    'assign-runtime', Decoded, 0, 0,
                    Decoded + #9 + Operand
                  );
                end;
              end
            end
            else if FCurrentMethodClass <> '' then
            begin
              DotPos := Pos('.', Decoded);
              if (DotPos > 0) then
              begin
                ArgName := Copy(Decoded, 1, DotPos - 1);
                FuncName := Copy(Decoded, DotPos + 1, Length(Decoded));
                StringValue := LookupClassVar(ArgName);
                if (StringValue <> '') and
                  (TypeMetaFieldIndex(StringValue, FuncName) >= 0) then
                begin
                  Value := TypeMetaFieldIndex(StringValue, FuncName);
                  AddFieldStoreRuntimeNode(
                    Decoded,
                    ArgName + #9 + IntToStr(Value) + #9 + Operand,
                    Child.ChildAt(0),
                    Arg
                  );
                end
                else
                begin
                  RegisterRuntimeVar(Decoded);
                  FModel.AddTypedHirNode(
                    'assign-runtime', Decoded, 0, 0,
                    Decoded + #9 + Operand
                  );
                end;
              end
              else
              begin
                Value := TypeMetaFieldIndex(FCurrentMethodClass, Decoded);
                if Value >= 0 then
                  AddFieldStoreRuntimeNode(
                    Decoded,
                    'self' + #9 + IntToStr(Value) + #9 + Operand,
                    Child.ChildAt(0),
                    Arg
                  )
                else
                begin
                  RegisterRuntimeVar(Decoded);
                  AddScalarAssignRuntimeNode(Decoded, Arg, Operand);
                end;
              end;
            end
            else
            begin
              RegisterRuntimeVar(Decoded);
              AddScalarAssignRuntimeNode(Decoded, Arg, Operand);
              if (LookupClassVar(Decoded) <> '') and
                TypeMetaIsInterface(LookupClassVar(Decoded)) and
                (Arg <> nil) and (Arg.NodeKind = gnkIdentifier) and
                (LookupClassVar(Arg.Text) <> '') and
                FModel.LookupConstValue(
                  LookupClassVar(Arg.Text) + '$intf_offset_' + LookupClassVar(Decoded),
                  Value) then
              begin
                FModel.AddTypedHirNode('intf-addref-runtime', Decoded, 0, 0, Decoded);
                FModel.AddTypedHirNode('intf-adjust-runtime', Decoded, 0, 0,
                  Decoded + #9 + IntToStr(Value div 8));
              end;
            end;
          end;
        end
        else if EvaluateIntegerConstant(Arg, Value) then
          FModel.AddVarInitValue(Decoded, Value)
        else
          FModel.RemoveVarInitValue(Decoded);
      end;
      Continue;
    end;
    if Child.NodeKind = gnkProcedureCallStatement then
    begin
      if SameText(Child.Text, 'Halt') then
      begin
        Operand := '0';
        Arg := nil;
        if Child.ChildCount >= 1 then
        begin
          Arg := Child.ChildAt(0);
          if (Arg <> nil) and (Arg.NodeKind = gnkFunctionCall) and
            (Arg.ChildCount >= 2) and (Arg.ChildAt(0) <> nil) and
            SameText(Arg.ChildAt(0).Text, 'Halt') then
            Arg := Arg.ChildAt(1);
        end;
        if FNoFold and (Arg <> nil) then
        begin
          if EncodeRuntimeIntExprFold(Arg, Operand) then
          begin
            EmitOwnedManagedRecordCleanupNodes;
            EmitOwnedDynArrayCleanupNodes;
            EmitOwnedStringCleanupNodes;
            NodeId := FModel.AddTypedHirNode(
              'halt-call-runtime', 'Halt', 0, 0, Operand);
            if BuildRuntimeScalarHirExpr(Arg, ExprId) then
              FModel.SetTypedHirNodeExprId(NodeId, ExprId);
            FCurrentBlockTerminated := True;
            Continue;
          end;
        end;
        if Arg <> nil then
        begin
          if EvaluateIntegerConstant(Arg, Value) then
            Operand := IntToStr(Value);
        end;
        EmitOwnedManagedRecordCleanupNodes;
        EmitOwnedDynArrayCleanupNodes;
        EmitOwnedStringCleanupNodes;
        FModel.AddTypedHirNode('halt-call', 'Halt', 0, 0, Operand);
        FCurrentBlockTerminated := True;
        Continue;
      end;
      if FNoFold and (Pos('specialize ', Child.Text) = 1) then
      begin
        ArgName := Copy(Child.Text, 12, Length(Child.Text) - 11);
        DotPos := Pos('<', ArgName);
        if DotPos > 0 then
        begin
          FuncName := Copy(ArgName, 1, DotPos - 1);
          Operand := Copy(ArgName, DotPos + 1, Pos('>', ArgName) - DotPos - 1);
          ArgName := FuncName + '$' + StringReplace(StringReplace(Operand, ', ', '$', True), ',', '$', True);
          if not LookupProcedureBody(ArgName, BranchNode, DeclNode) then
          begin
            for K := 0 to Length(FProcedureBodies) - 1 do
              if (Pos(FuncName + '<', FProcedureBodies[K].Name) = 1) then
              begin
                RegisterProcedureBody(ArgName,
                  FProcedureBodies[K].Body, FProcedureBodies[K].Decl,
                  FProcedureBodies[K].OwnerUnitId);
                if FGenericWorkCount >= Length(FGenericWorkQueue) then
                  SetLength(FGenericWorkQueue, FGenericWorkCount + 64);
                FGenericWorkQueue[FGenericWorkCount] := Length(FProcedureBodies) - 1;
                Inc(FGenericWorkCount);
                Break;
              end;
          end;
          Decoded := ArgName;
          Operand := ArgName;
          Arg := nil;
          if (Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) and
            (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
            Arg := Child.ChildAt(0);
          if Arg <> nil then
          begin
            Operand := ArgName + #9;
            for ArgIndex := 1 to Arg.ChildCount - 1 do
            begin
              RhsNode := Arg.ChildAt(ArgIndex);
              if RhsNode = nil then Continue;
              if (RhsNode.NodeKind = gnkIdentifier) and
                IsRuntimeArrVar(RhsNode.Text) then
                Operand := Operand + #9 + 'arrvar ' + RhsNode.Text + #10
              else if EncodeRuntimeIntExprFold(RhsNode, StringValue) then
                Operand := Operand + #9 + StringValue;
            end;
            FModel.AddTypedHirNode('call-runtime', ArgName, 0, 0, Operand);
          end
          else
            FModel.AddTypedHirNode('call-runtime', ArgName, 0, 0, ArgName);
        end;
        Continue;
      end;
      if SameText(Child.Text, 'WriteLn') or SameText(Child.Text, 'Write') then
      begin
        Arg := nil;
        if (Child.ChildCount >= 1) and
          (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
          Arg := Child.ChildAt(0)
        else
          Arg := Child;
        if FNoFold then
        begin
          if (Arg <> nil) and (Arg.NodeKind = gnkFunctionCall) then
            ArgIndex := 1
          else
            ArgIndex := 0;
          while ArgIndex < Arg.ChildCount do
          begin
            RhsNode := Arg.ChildAt(ArgIndex);
            if RhsNode = nil then
            begin
              Inc(ArgIndex);
              Continue;
            end;
            if RhsNode.NodeKind = gnkStringLiteral then
              FModel.AddTypedHirNode(
                'write-string-runtime', 'Write', 0, 0,
                DecodePascalStringLiteral(RhsNode.Text)
              )
            else if EvaluateStringConstant(RhsNode, StringValue) then
              FModel.AddTypedHirNode(
                'write-string-runtime', 'Write', 0, 0, StringValue
              )
            else if (RhsNode.NodeKind = gnkIdentifier) and
              IsRuntimeStrVar(RhsNode.Text) and
              not LookupProcedureBody(RhsNode.Text, BranchNode, DeclNode) then
              FModel.AddTypedHirNode(
                'write-str-var-runtime', 'Write', 0, 0, RhsNode.Text
              )
            else if (RhsNode.NodeKind = gnkFunctionCall) and
              (RhsNode.ChildCount >= 2) and (RhsNode.ChildAt(0) <> nil) and
              SameText(RhsNode.ChildAt(0).Text, 'IntToStr') and
              EncodeRuntimeIntExprFold(RhsNode.ChildAt(1), Operand) then
              AddWriteIntRuntimeNode(RhsNode.ChildAt(1), Operand)
            else if EmitOwnedStringWriteTemp(RhsNode, Operand) then
              FModel.AddTypedHirNode(
                'write-str-var-runtime', 'Write', 0, 0, Operand
              )
            else if EmitOwnedStringConcatWriteTemp(RhsNode, Operand) then
              FModel.AddTypedHirNode(
                'write-str-var-runtime', 'Write', 0, 0, Operand
              )
            else if (RhsNode.NodeKind = gnkIdentifier) and
              LookupProcedureBody(RhsNode.Text, BranchNode, DeclNode) and
              IsRuntimeStrVar(RhsNode.Text) then
            begin
              Inc(FBlockLabelCounter);
              Operand := '$wrt_tmp_' + IntToStr(FBlockLabelCounter);
              RegisterRuntimeVar(Operand);
              RegisterRuntimeStrVar(Operand);
              FModel.AddTypedHirNode('var-decl-tstring-runtime', Operand, 0, 0, Operand);
              FModel.AddTypedHirNode(
                'assign-tstring-call-runtime', RhsNode.Text, 0, 0, Operand
              );
              FModel.AddTypedHirNode(
                'write-str-var-runtime', 'Write', 0, 0, Operand
              );
            end
            else if (RhsNode.NodeKind = gnkDotAccess) and
              (RhsNode.ChildCount >= 2) and
              (RhsNode.ChildAt(0) <> nil) and
              (RhsNode.ChildAt(1) <> nil) and
              (RhsNode.ChildAt(0).NodeKind = gnkIdentifier) and
              (RhsNode.ChildAt(1).NodeKind = gnkIdentifier) and
              (LookupClassVar(RhsNode.ChildAt(0).Text) <> '') then
            begin
              FuncName := LookupClassVar(RhsNode.ChildAt(0).Text);
              Value := TypeMetaVmtSlot(FuncName, RhsNode.ChildAt(1).Text);
              if (Value >= 0) and
                (not FModel.LookupConstValue(
                  FuncName + '$ret_str_' + RhsNode.ChildAt(1).Text, CondValue)) and
                EncodeRuntimeIntExprFold(RhsNode, Operand) then
                AddWriteIntRuntimeNode(RhsNode, Operand)
              else if Value >= 0 then
              begin
                Inc(FBlockLabelCounter);
                Operand := '$wrt_tmp_' + IntToStr(FBlockLabelCounter);
                RegisterRuntimeVar(Operand);
                RegisterRuntimeStrVar(Operand);
                FModel.AddTypedHirNode('var-decl-tstring-runtime', Operand, 0, 0, Operand);
                FModel.AddTypedHirNode(
                  'assign-tstring-call-runtime', RhsNode.ChildAt(1).Text, 0, 0,
                  Operand + #9 + RhsNode.ChildAt(0).Text + #9 +
                  IntToStr(Value)
                );
                FModel.AddTypedHirNode(
                  'write-str-var-runtime', 'Write', 0, 0, Operand
                );
              end;
            end
            else if EncodeRuntimeIntExprFold(RhsNode, Operand) then
              AddWriteIntRuntimeNode(RhsNode, Operand);
            Inc(ArgIndex);
          end;
          if SameText(Child.Text, 'WriteLn') then
            FModel.AddTypedHirNode(
              'write-string-runtime', 'Write', 0, 0, #10
            );
          EmitPendingStringTempReleases;
          Continue;
        end;
        Decoded := '';
        if (Arg <> nil) and (Arg.NodeKind = gnkFunctionCall) then
          ArgIndex := 1
        else
          ArgIndex := 0;
        while ArgIndex < Arg.ChildCount do
        begin
          RhsNode := Arg.ChildAt(ArgIndex);
          if RhsNode = nil then
          begin
            Inc(ArgIndex);
            Continue;
          end;
          if RhsNode.NodeKind = gnkStringLiteral then
            Decoded := Decoded + DecodePascalStringLiteral(RhsNode.Text)
          else if EvaluateStringConstant(RhsNode, StringValue) then
            Decoded := Decoded + StringValue
          else if EvaluateIntegerConstant(RhsNode, Value) then
            Decoded := Decoded + IntToStr(Value);
          Inc(ArgIndex);
        end;
        if SameText(Child.Text, 'WriteLn') then
          Decoded := Decoded + #10;
        FModel.AddTypedHirNode('write-call', Child.Text, 0, 0, Decoded);
        Continue;
      end;
      if FNoFold and SameText(Child.Text, 'SetLength') then
      begin
        Arg := nil;
        ArgIndex := 0;
        if (Child.ChildCount >= 1) and
          (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
        begin
          Arg := Child.ChildAt(0);
          ArgIndex := 1;
        end
        else
          Arg := Child;
        if (Arg <> nil) and (Arg.ChildCount >= ArgIndex + 2) then
        begin
          RhsNode := Arg.ChildAt(ArgIndex);
          if (RhsNode <> nil) and (RhsNode.NodeKind = gnkIdentifier) and
            IsRuntimeArrVar(RhsNode.Text) and
            (not IsBorrowedRuntimeArrVar(RhsNode.Text)) and
            (not IsStaticRuntimeArrVar(RhsNode.Text)) then
          begin
            if EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), Operand) then
              FModel.AddTypedHirNode(
                'setlength-arr-runtime', RhsNode.Text, 0, 0,
                RhsNode.Text + #9 + Operand + #9 +
                IntToStr(DynArrayElemSizeOfVar(RhsNode.Text))
              );
          end
          else if (RhsNode <> nil) and (RhsNode.NodeKind = gnkIdentifier) and
            (FCurrentMethodClass <> '') and
            TypeMetaFieldIsDynArray(FCurrentMethodClass, RhsNode.Text) then
          begin
            if EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), Operand) then
            begin
              Value := TypeMetaFieldIndex(FCurrentMethodClass, RhsNode.Text);
              FModel.AddTypedHirNode(
                'setlength-field-arr-runtime', RhsNode.Text, 0, 0,
                'self' + #9 + IntToStr(Value) + #9 + Operand + #9 +
                IntToStr(TypeMetaFieldDynArrayElemSize(
                  FCurrentMethodClass, RhsNode.Text))
              );
            end;
          end
          else if (RhsNode <> nil) and
            (RhsNode.NodeKind = gnkDotAccess) and
            (RhsNode.ChildCount >= 2) and
            (RhsNode.ChildAt(0) <> nil) and
            (RhsNode.ChildAt(1) <> nil) and
            (RhsNode.ChildAt(0).NodeKind = gnkIdentifier) and
            (RhsNode.ChildAt(1).NodeKind = gnkIdentifier) and
            SameText(RhsNode.ChildAt(0).Text, 'Self') and
            (FCurrentMethodClass <> '') and
            TypeMetaFieldIsDynArray(
              FCurrentMethodClass, RhsNode.ChildAt(1).Text) then
          begin
            if EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), Operand) then
            begin
              Value := TypeMetaFieldIndex(
                FCurrentMethodClass, RhsNode.ChildAt(1).Text);
              FModel.AddTypedHirNode(
                'setlength-field-arr-runtime',
                'Self.' + RhsNode.ChildAt(1).Text, 0, 0,
                'self' + #9 + IntToStr(Value) + #9 + Operand + #9 +
                IntToStr(TypeMetaFieldDynArrayElemSize(
                  FCurrentMethodClass, RhsNode.ChildAt(1).Text))
              );
            end;
          end;
        end;
        Continue;
      end;
      if FNoFold and (SameText(Child.Text, 'Inc') or
        SameText(Child.Text, 'Dec')) and
        not ((Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkDotAccess) and
          (Child.ChildAt(0).ChildCount >= 2) and
          (Child.ChildAt(0).ChildAt(0) <> nil) and
          (LookupClassVar(Child.ChildAt(0).ChildAt(0).Text) <> '')) then
      begin
        Arg := nil;
        ArgIndex := 0;
        if (Child.ChildCount >= 1) and
          (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
        begin
          Arg := Child.ChildAt(0);
          ArgIndex := 1;
        end
        else
          Arg := Child;
        if (Arg <> nil) and (Arg.ChildCount > ArgIndex) then
        begin
          RhsNode := Arg.ChildAt(ArgIndex);
          if (RhsNode <> nil) and (RhsNode.NodeKind = gnkIdentifier) then
          begin
            Decoded := RhsNode.Text;
            if SameText(Child.Text, 'Inc') then
              StringValue := 'add'
            else
              StringValue := 'sub';
            Value := -1;
            if FCurrentMethodClass <> '' then
              Value := TypeMetaFieldIndex(FCurrentMethodClass, Decoded);
            if Value >= 0 then
            begin
              if (Arg.ChildCount > ArgIndex + 1) and
                EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), Operand) then
                Operand := 'field self ' + IntToStr(Value) + #10 +
                  Operand + StringValue + #10
              else
                Operand := 'field self ' + IntToStr(Value) + #10 +
                  'int 1' + #10 + StringValue + #10;
              FModel.AddTypedHirNode('field-store-runtime', Decoded, 0, 0,
                'self' + #9 + IntToStr(Value) + #9 + Operand);
            end
            else
            begin
              if (Arg.ChildCount > ArgIndex + 1) and
                EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), Operand) then
                AddIncDecAssignRuntimeNode(Decoded, IncDecStructuredOp(StringValue),
                  Arg.ChildAt(ArgIndex + 1),
                  'var ' + Decoded + #10 + Operand + StringValue + #10)
              else
                AddIncDecAssignRuntimeNode(Decoded, IncDecStructuredOp(StringValue),
                  nil,
                  'var ' + Decoded + #10 + 'int 1' + #10 + StringValue + #10);
            end;
          end;
        end;
        Continue;
      end;
      if FNoFold and SameText(Child.Text, 'FillChar') then
      begin
        Arg := Child;
        ArgIndex := 0;
        if (Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
        begin
          Arg := Child.ChildAt(0);
          ArgIndex := 1;
        end;
        if (Arg <> nil) and (Arg.ChildCount >= ArgIndex + 3) then
        begin
          Decoded := Arg.ChildAt(ArgIndex).Text;
          if EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), Operand) then
          begin
            StringValue := '';
            EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 2), StringValue);
            FModel.AddTypedHirNode(
              'fillchar-runtime', Decoded, 0, 0,
              Decoded + #9 + Operand + #9 + StringValue);
          end;
        end;
        Continue;
      end;
      if FNoFold and SameText(Child.Text, 'Move') then
      begin
        Arg := Child;
        ArgIndex := 0;
        if (Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
        begin
          Arg := Child.ChildAt(0);
          ArgIndex := 1;
        end;
        if (Arg <> nil) and (Arg.ChildCount >= ArgIndex + 3) then
        begin
          Decoded := Arg.ChildAt(ArgIndex).Text;
          Operand := Arg.ChildAt(ArgIndex + 1).Text;
          if EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 2), StringValue) then
            FModel.AddTypedHirNode(
              'move-runtime', Decoded, 0, 0,
              Decoded + #9 + Operand + #9 + StringValue);
        end;
        Continue;
      end;
      if FNoFold and SameText(Child.Text, 'GetMem') then
      begin
        Arg := Child;
        ArgIndex := 0;
        if (Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
        begin
          Arg := Child.ChildAt(0);
          ArgIndex := 1;
        end;
        if (Arg <> nil) and (Arg.ChildCount >= ArgIndex + 2) then
        begin
          Decoded := Arg.ChildAt(ArgIndex).Text;
          if EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), Operand) then
            FModel.AddTypedHirNode(
              'getmem-runtime', Decoded, 0, 0,
              Decoded + #9 + Operand);
        end;
        Continue;
      end;
      if FNoFold and SameText(Child.Text, 'FreeMem') then
      begin
        Arg := Child;
        ArgIndex := 0;
        if (Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
        begin
          Arg := Child.ChildAt(0);
          ArgIndex := 1;
        end;
        if (Arg <> nil) and (Arg.ChildCount >= ArgIndex + 1) then
        begin
          Decoded := Arg.ChildAt(ArgIndex).Text;
          FModel.AddTypedHirNode(
            'freemem-runtime', Decoded, 0, 0, Decoded);
        end;
        Continue;
      end;
      if FNoFold and SameText(Child.Text, 'Assigned') then
      begin
        Arg := Child;
        ArgIndex := 0;
        if (Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
        begin
          Arg := Child.ChildAt(0);
          ArgIndex := 1;
        end;
        if (Arg <> nil) and (Arg.ChildCount >= ArgIndex + 1) then
        begin
          Decoded := Arg.ChildAt(ArgIndex).Text;
          FModel.AddTypedHirNode(
            'assigned-runtime', Decoded, 0, 0, Decoded);
        end;
        Continue;
      end;
      if FNoFold and (FCurrentMethodClass <> '') and
        (Pos('inherited ', Child.Text) = 1) then
      begin
        InhMethodName := Copy(Child.Text, 11, Length(Child.Text));
        InhTypeId := FModel.FindTypeByName(FCurrentMethodClass);
        if (InhTypeId > 0) then
        begin
          InhParentId := FModel.TypeAt(InhTypeId - 1).ParentTypeId;
          if InhParentId > 0 then
          begin
            InhParentName := FModel.TypeAt(InhParentId - 1).Name;
            Operand := InhParentName + '.' + InhMethodName + #9 +
              'var self' + #10;
            for ArgIndex := 0 to Child.ChildCount - 1 do
            begin
              RhsNode := Child.ChildAt(ArgIndex);
              if (RhsNode <> nil) and EncodeRuntimeIntExprFold(RhsNode, Decoded) then
                Operand := Operand + #9 + Decoded;
            end;
            NodeId := FModel.AddTypedHirNode('call-runtime',
              InhParentName + '.' + InhMethodName, 0, 0, Operand);
            AttachStatementCallExpr(NodeId, Child);
            Continue;
          end;
        end;
      end;
      if FNoFold and (Child.ChildCount >= 1) and
        (Child.ChildAt(0) <> nil) and
        (Child.ChildAt(0).NodeKind = gnkFunctionCall) and
        (Child.ChildAt(0).ChildCount >= 1) and
        (Child.ChildAt(0).ChildAt(0) <> nil) and
        (Child.ChildAt(0).ChildAt(0).NodeKind = gnkDotAccess) and
        (Child.ChildAt(0).ChildAt(0).ChildCount >= 2) and
        (Child.ChildAt(0).ChildAt(0).ChildAt(0) <> nil) and
        (Child.ChildAt(0).ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) then
      begin
        StringValue := LookupClassVar(
          Child.ChildAt(0).ChildAt(0).ChildAt(0).Text);
        if StringValue <> '' then
        begin
          InhParentName := StringValue;
          while (InhParentName <> '') and
            (FModel.FindSymbolByName(InhParentName + '.' +
              Child.ChildAt(0).ChildAt(0).ChildAt(1).Text) = 0) do
            InhParentName := NextClassAncestorName(InhParentName);
          if InhParentName = '' then InhParentName := StringValue;
          if TypeMetaIsInterface(StringValue) then
          begin
            Value := TypeMetaVmtSlot(StringValue,
              Child.ChildAt(0).ChildAt(0).ChildAt(1).Text);
            if Value >= 0 then
            begin
              Operand := 'var ' + Child.ChildAt(0).ChildAt(0).ChildAt(0).Text + #10;
              for ArgIndex := 1 to Child.ChildAt(0).ChildCount - 1 do
              begin
                RhsNode := Child.ChildAt(0).ChildAt(ArgIndex);
                if (RhsNode <> nil) and EncodeRuntimeIntExprFold(RhsNode, Decoded) then
                  Operand := Operand + Decoded;
              end;
              Operand := Operand + 'ivcall ' + IntToStr(Value) + ' ' +
                IntToStr(Child.ChildAt(0).ChildCount - 1) + #10;
              NodeId := FModel.AddTypedHirNode('halt-call-runtime', '__discard__', 0, 0, Operand);
              AttachStatementCallExpr(NodeId, Child.ChildAt(0));
              Continue;
            end;
          end;
          Operand := InhParentName + '.' +
            Child.ChildAt(0).ChildAt(0).ChildAt(1).Text + #9 +
            'var ' + Child.ChildAt(0).ChildAt(0).ChildAt(0).Text + #10;
          for ArgIndex := 1 to Child.ChildAt(0).ChildCount - 1 do
          begin
            RhsNode := Child.ChildAt(0).ChildAt(ArgIndex);
            if RhsNode = nil then
              Continue;
            if (RhsNode.NodeKind = gnkFunctionCall) and
              (RhsNode.ChildCount >= 1) and (RhsNode.ChildAt(0) <> nil) and
              (RhsNode.ChildAt(0).NodeKind = gnkDotAccess) and
              (RhsNode.ChildAt(0).ChildCount >= 2) and
              (RhsNode.ChildAt(0).ChildAt(0) <> nil) and
              (TypeMetaSize(RhsNode.ChildAt(0).ChildAt(0).Text) > 0) then
            begin
              Inc(FBlockLabelCounter);
              FuncName := '$arg_tmp_' + IntToStr(FBlockLabelCounter);
              Value := TypeMetaSize(RhsNode.ChildAt(0).ChildAt(0).Text);
              Decoded := FuncName + #9 +
                RhsNode.ChildAt(0).ChildAt(0).Text + '.' +
                RhsNode.ChildAt(0).ChildAt(1).Text;
              for K := 1 to RhsNode.ChildCount - 1 do
                if (RhsNode.ChildAt(K) <> nil) and
                  EncodeRuntimeIntExprFold(RhsNode.ChildAt(K), ArgName) then
                  Decoded := Decoded + #9 + ArgName;
              RegisterRuntimeVar(FuncName);
              RegisterClassVar(FuncName, RhsNode.ChildAt(0).ChildAt(0).Text);
              FModel.AddTypedHirNode(
                'class-new-runtime', IntToStr(Value), 0, 0, Decoded);
              if (TypeMetaVmtCount(RhsNode.ChildAt(0).ChildAt(0).Text) > 0) or
              (TypeMetaInterfaces(RhsNode.ChildAt(0).ChildAt(0).Text) <> '') then
                FModel.AddTypedHirNode('vmt-store-runtime',
                  RhsNode.ChildAt(0).ChildAt(0).Text, 0, 0,
                  FuncName + #9 + RhsNode.ChildAt(0).ChildAt(0).Text);
              Operand := Operand + #9 + 'var ' + FuncName + #10;
            end
            else if EncodeRuntimeIntExprFold(RhsNode, Decoded) then
              Operand := Operand + #9 + Decoded;
          end;
          NodeId := FModel.AddTypedHirNode('call-runtime',
            InhParentName + '.' +
            Child.ChildAt(0).ChildAt(0).ChildAt(1).Text,
            0, 0, Operand);
          AttachStatementCallExpr(NodeId, Child.ChildAt(0));
          Continue;
        end;
      end;
      if FNoFold and (Child.ChildCount >= 1) and
        (Child.ChildAt(0) <> nil) and
        (Child.ChildAt(0).NodeKind = gnkDotAccess) and
        (Child.ChildAt(0).ChildCount >= 2) and
        (Child.ChildAt(0).ChildAt(0) <> nil) and
        (Child.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
        SameText(Child.ChildAt(0).ChildAt(1).Text, 'Free') then
      begin
        StringValue := LookupClassVar(Child.ChildAt(0).ChildAt(0).Text);
        if StringValue <> '' then
        begin
          Value := TypeMetaVmtSlot(StringValue, 'Destroy');
          ReceiverName := Child.ChildAt(0).ChildAt(0).Text;
          DestroyFuncName := StringValue + '.Destroy';
          if (Value >= 0) and FModel.LookupStringConstValue(
            StringValue + '$vmt_func_' + IntToStr(Value),
            FuncName
          ) then
            DestroyFuncName := FuncName;
          FModel.AddTypedHirNode(
            'object-free-runtime',
            NPSYSTEM_OBJECT_FREE,
            0,
            0,
            'var ' + ReceiverName + #10 +
            'destroy ' + DestroyFuncName + #10 +
            'cleanup-class ' + StringValue + #10 +
            'nil-guard true' + #10 +
            'heap-release true' + #10
          );
          Operand := DestroyFuncName + #9 +
            'var ' + ReceiverName + #10;
          FModel.AddTypedHirNode('call-runtime',
            DestroyFuncName, 0, 0, Operand);
          Continue;
        end;
      end;
      if FNoFold and (Child.ChildCount >= 1) and
        (Child.ChildAt(0) <> nil) and
        (Child.ChildAt(0).NodeKind = gnkDotAccess) and
        (Child.ChildAt(0).ChildCount >= 2) and
        (Child.ChildAt(0).ChildAt(0) <> nil) and
        (Child.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) then
      begin
        StringValue := LookupClassVar(Child.ChildAt(0).ChildAt(0).Text);
        if StringValue <> '' then
        begin
          if TypeMetaIsInterface(StringValue) then
          begin
            Value := TypeMetaVmtSlot(StringValue,
              Child.ChildAt(0).ChildAt(1).Text);
            if Value >= 0 then
            begin
              Operand := 'var ' + Child.ChildAt(0).ChildAt(0).Text + #10 +
                'ivcall ' + IntToStr(Value) + ' 0' + #10;
              NodeId := FModel.AddTypedHirNode('halt-call-runtime', '__discard__', 0, 0, Operand);
              AttachStatementCallExpr(NodeId, Child.ChildAt(0));
              Continue;
            end;
          end;
          InhParentName := StringValue;
          while (InhParentName <> '') and
            (FModel.FindSymbolByName(InhParentName + '.' +
              Child.ChildAt(0).ChildAt(1).Text) = 0) do
            InhParentName := NextClassAncestorName(InhParentName);
          if InhParentName = '' then InhParentName := StringValue;
          Operand := InhParentName + '.' + Child.ChildAt(0).ChildAt(1).Text +
            #9 + 'var ' + Child.ChildAt(0).ChildAt(0).Text + #10;
          Arg := nil;
          if (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
            Arg := Child.ChildAt(0)
          else if (Child.ChildCount >= 2) and
            (Child.ChildAt(1) <> nil) and
            (Child.ChildAt(1).NodeKind = gnkFunctionCall) then
            Arg := Child.ChildAt(1);
          if Arg <> nil then
          begin
            for ArgIndex := 1 to Arg.ChildCount - 1 do
            begin
              RhsNode := Arg.ChildAt(ArgIndex);
              if (RhsNode <> nil) and EncodeRuntimeIntExprFold(RhsNode, Decoded) then
                Operand := Operand + #9 + Decoded;
            end;
          end;
          NodeId := FModel.AddTypedHirNode('call-runtime',
            InhParentName + '.' + Child.ChildAt(0).ChildAt(1).Text,
            0, 0, Operand);
          AttachStatementCallExpr(NodeId, Child);
          Continue;
        end;
      end;
      if (not FNoFold) and
        LookupProcedureBody(Child.Text, BranchNode, DeclNode) and
        (BranchNode <> nil) and
        not IsCurrentlyInlining(Child.Text) then
      begin
        PushInlining(Child.Text);
        if (Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
          ParamSnaps := BindCallArgs(DeclNode, Child.ChildAt(0), 1)
        else
          ParamSnaps := BindCallArgs(DeclNode, Child, 0);
        try
          WalkHaltCalls(BranchNode);
        finally
          PopInlining;
          RestoreCallArgs(ParamSnaps);
        end;
        Continue;
      end;
      if FNoFold and (FCurrentMethodClass <> '') and
        (not LookupProcedureBody(Child.Text, BranchNode, DeclNode)) and
        LookupProcedureBody(FCurrentMethodClass + '.' + Child.Text,
          BranchNode, DeclNode) then
      begin
        Operand := FCurrentMethodClass + '.' + Child.Text + #9 +
          'var self' + #10;
        Arg := nil;
        if (Child.ChildCount >= 1) and
          (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
          Arg := Child.ChildAt(0)
        else
          Arg := Child;
        if Arg <> nil then
        begin
          if Arg.NodeKind = gnkFunctionCall then
            ArgIndex := 1
          else
            ArgIndex := 0;
          while ArgIndex < Arg.ChildCount do
          begin
            RhsNode := Arg.ChildAt(ArgIndex);
            if (RhsNode <> nil) and EncodeRuntimeIntExprFold(RhsNode, Decoded) then
              Operand := Operand + #9 + Decoded;
            Inc(ArgIndex);
          end;
        end;
        NodeId := FModel.AddTypedHirNode('call-runtime',
          FCurrentMethodClass + '.' + Child.Text, 0, 0, Operand);
        AttachStatementCallExpr(NodeId, Child);
        Continue;
      end;
      if FNoFold and LookupProcedureBody(Child.Text, BranchNode, DeclNode) then
      begin
        Arg := nil;
        if (Child.ChildCount >= 1) and
          (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
          Arg := Child.ChildAt(0)
        else
          Arg := Child;
        ArgIndex := 0;
        if (Arg <> nil) then
        begin
          if Arg.NodeKind = gnkFunctionCall then
            ArgIndex := Arg.ChildCount - 1
          else
            ArgIndex := Arg.ChildCount;
        end;
        if HasOverload(Child.Text) then
        begin
          StringValue := '';
          if Arg <> nil then
          begin
            if Arg.NodeKind = gnkFunctionCall then
              DotPos := 1
            else
              DotPos := 0;
            while DotPos < Arg.ChildCount do
            begin
              RhsNode := Arg.ChildAt(DotPos);
              if (RhsNode <> nil) and (RhsNode.NodeKind = gnkIdentifier) and
                IsRuntimeStrVar(RhsNode.Text) then
                StringValue := StringValue + 's'
              else if (RhsNode <> nil) and (RhsNode.NodeKind = gnkStringLiteral) then
                StringValue := StringValue + 's'
              else
                StringValue := StringValue + 'i';
              Inc(DotPos);
            end;
          end;
          Operand := MangledNameSig(Child.Text, StringValue);
        end
        else
          Operand := Child.Text;
        if Arg <> nil then
          Operand := EncodeCallStatementArgs(Operand, Arg, DeclNode);
        NodeId := FModel.AddTypedHirNode('call-runtime', Child.Text, 0, 0, Operand);
        AttachStatementCallExpr(NodeId, Child);
        EmitPendingStringTempReleases;
        Continue;
      end;
    end;
    WalkHaltCalls(Child);
  end;
end;
procedure TSemanticAnalyzer.LowerRuntimeIfStatement(
  const AIfNode: TGreenNode; const ACondBlob: string);
var
  NodeId: LongInt;
  ThenLabel, ElseLabel, EndLabel: string;
  HasElse: Boolean;
begin
  HasElse := AIfNode.ChildCount >= 3;
  ThenLabel := NewBlockLabel('then');
  if HasElse then
    ElseLabel := NewBlockLabel('else')
  else
    ElseLabel := '';
  EndLabel := NewBlockLabel('endif');
  if not HasElse then
    ElseLabel := EndLabel;
  NodeId := FModel.AddTypedHirNode(
    'cond-br-runtime', 'if', 0, 0,
    ACondBlob + 'labels ' + ThenLabel + #9 + ElseLabel + #10
  );
  if AIfNode.ChildCount >= 1 then
    AttachRuntimeConditionExpr(NodeId, AIfNode.ChildAt(0));
  EmitPendingStringTempReleases;
  FCurrentBlockTerminated := True;
  EmitBlockLabel(ThenLabel);
  WalkHaltCalls(AIfNode.ChildAt(1));
  EmitGotoLabel(EndLabel);
  if HasElse then
  begin
    EmitBlockLabel(ElseLabel);
    WalkHaltCalls(AIfNode.ChildAt(2));
    EmitGotoLabel(EndLabel);
  end;
  EmitBlockLabel(EndLabel);
end;

procedure TSemanticAnalyzer.LowerRuntimeWhileStatement(const ANode: TGreenNode);
var
  NodeId: LongInt;
  CondNode, BodyNode: TGreenNode;
  CondBlob, CondLabel, BodyLabel, ExitLabel: string;
  UseOwnedCompareCondition: Boolean;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  CondNode := ANode.ChildAt(0);
  BodyNode := ANode.ChildAt(1);
  UseOwnedCompareCondition := BoolConditionHasSupportedOwnedStringCompare(
    CondNode);
  if (not UseOwnedCompareCondition) and
    (not EncodeRuntimeBoolExprFold(CondNode, CondBlob)) then
    Exit;
  CondLabel := NewBlockLabel('while-cond');
  BodyLabel := NewBlockLabel('while-body');
  ExitLabel := NewBlockLabel('while-end');
  FBreakLabels.Push(ExitLabel);
  FContinueLabels.Push(CondLabel);
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(CondLabel);
  if UseOwnedCompareCondition and
    (not EncodeRuntimeBoolExprFold(CondNode, CondBlob, True)) then
    Exit;
  NodeId := FModel.AddTypedHirNode(
    'cond-br-runtime', 'while', 0, 0,
    CondBlob + 'labels ' + BodyLabel + #9 + ExitLabel + #10
  );
  AttachRuntimeConditionExpr(NodeId, CondNode);
  EmitPendingStringTempReleases;
  FCurrentBlockTerminated := True;
  EmitBlockLabel(BodyLabel);
  WalkHaltCalls(BodyNode);
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(ExitLabel);
  FBreakLabels.Pop;
  FContinueLabels.Pop;
end;

procedure TSemanticAnalyzer.LowerRuntimeRepeatStatement(const ANode: TGreenNode);
var
  NodeId: LongInt;
  CondNode, BodyNode: TGreenNode;
  CondBlob, BodyLabel, CondLabel, ExitLabel: string;
  UseOwnedCompareCondition: Boolean;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  BodyNode := ANode.ChildAt(0);
  CondNode := ANode.ChildAt(1);
  UseOwnedCompareCondition := BoolConditionHasSupportedOwnedStringCompare(
    CondNode);
  if (not UseOwnedCompareCondition) and
    (not EncodeRuntimeBoolExprFold(CondNode, CondBlob)) then
    Exit;
  BodyLabel := NewBlockLabel('repeat-body');
  CondLabel := NewBlockLabel('repeat-cond');
  ExitLabel := NewBlockLabel('repeat-end');
  FBreakLabels.Push(ExitLabel);
  FContinueLabels.Push(CondLabel);
  EmitGotoLabel(BodyLabel);
  EmitBlockLabel(BodyLabel);
  WalkHaltCalls(BodyNode);
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(CondLabel);
  if UseOwnedCompareCondition and
    (not EncodeRuntimeBoolExprFold(CondNode, CondBlob, True)) then
    Exit;
  NodeId := FModel.AddTypedHirNode(
    'cond-br-runtime', 'until', 0, 0,
    CondBlob + 'labels ' + ExitLabel + #9 + BodyLabel + #10
  );
  AttachRuntimeConditionExpr(NodeId, CondNode);
  EmitPendingStringTempReleases;
  FCurrentBlockTerminated := True;
  EmitBlockLabel(ExitLabel);
  FBreakLabels.Pop;
  FContinueLabels.Pop;
end;

procedure TSemanticAnalyzer.LowerRuntimeCaseStatement(const ANode: TGreenNode);
var
  SelectorNode, SelectorChild, LabelNode, LabelExpr: TGreenNode;
  SelectorBlob, SwitchBlob, ExitLabel, BodyLabel, DefaultLabel: string;
  BodyLabels: array of string;
  I, J, K, CaseCount, SelectorCount: LongInt;
  Val, LoVal, HiVal: Int64;
  HasElse: Boolean;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  if not EncodeRuntimeIntExprFold(ANode.ChildAt(0), SelectorBlob) then
    Exit;

  SelectorCount := 0;
  HasElse := False;
  for I := 1 to ANode.ChildCount - 1 do
  begin
    SelectorChild := ANode.ChildAt(I);
    if (SelectorChild <> nil) and (SelectorChild.NodeKind = gnkCaseSelector) then
      Inc(SelectorCount)
    else
      HasElse := True;
  end;

  ExitLabel := NewBlockLabel('case-end');
  DefaultLabel := NewBlockLabel('case-default');
  SetLength(BodyLabels, SelectorCount);
  for I := 0 to SelectorCount - 1 do
    BodyLabels[I] := NewBlockLabel('case-body');

  CaseCount := 0;
  SwitchBlob := '';
  K := 0;
  for I := 1 to ANode.ChildCount - 1 do
  begin
    SelectorChild := ANode.ChildAt(I);
    if (SelectorChild = nil) or (SelectorChild.NodeKind <> gnkCaseSelector) then
      Continue;
    for J := 0 to SelectorChild.ChildCount - 1 do
    begin
      LabelNode := SelectorChild.ChildAt(J);
      if (LabelNode = nil) or (LabelNode.NodeKind <> gnkCaseLabel) then
        Continue;
      if LabelNode.ChildCount < 1 then
        Continue;
      LabelExpr := LabelNode.ChildAt(0);
      if (LabelExpr <> nil) and (LabelExpr.NodeKind = gnkRangeExpression) and
        (LabelExpr.ChildCount >= 2) then
      begin
        if EvaluateIntegerConstant(LabelExpr.ChildAt(0), LoVal) and
          EvaluateIntegerConstant(LabelExpr.ChildAt(1), HiVal) then
          for Val := LoVal to HiVal do
          begin
            SwitchBlob := SwitchBlob + IntToStr(Val) + #9 + BodyLabels[K] + #10;
            Inc(CaseCount);
          end;
      end
      else if EvaluateIntegerConstant(LabelExpr, Val) then
      begin
        SwitchBlob := SwitchBlob + IntToStr(Val) + #9 + BodyLabels[K] + #10;
        Inc(CaseCount);
      end;
    end;
    Inc(K);
  end;

  FModel.AddTypedHirNode(
    'switch-runtime', 'case', 0, 0,
    SelectorBlob + 'switch ' + IntToStr(CaseCount) + #10 +
    SwitchBlob + 'default' + #9 + DefaultLabel + #10
  );
  FCurrentBlockTerminated := True;

  K := 0;
  for I := 1 to ANode.ChildCount - 1 do
  begin
    SelectorChild := ANode.ChildAt(I);
    if (SelectorChild = nil) or (SelectorChild.NodeKind <> gnkCaseSelector) then
      Continue;
    EmitBlockLabel(BodyLabels[K]);
    for J := 0 to SelectorChild.ChildCount - 1 do
    begin
      LabelNode := SelectorChild.ChildAt(J);
      if (LabelNode <> nil) and (LabelNode.NodeKind <> gnkCaseLabel) then
        WalkHaltCalls(LabelNode);
    end;
    EmitGotoLabel(ExitLabel);
    Inc(K);
  end;

  EmitBlockLabel(DefaultLabel);
  if HasElse then
  begin
    for I := 1 to ANode.ChildCount - 1 do
    begin
      SelectorChild := ANode.ChildAt(I);
      if (SelectorChild <> nil) and (SelectorChild.NodeKind <> gnkCaseSelector) then
        WalkHaltCalls(SelectorChild);
    end;
  end;
  EmitGotoLabel(ExitLabel);
  EmitBlockLabel(ExitLabel);
end;

procedure TSemanticAnalyzer.LowerRuntimeForStatement(const ANode: TGreenNode);
var
  LoopVar, Direction: string;
  StartNode, EndNode, BodyNode: TGreenNode;
  StartBlob, EndBlob, CondBlob: string;
  CondLabel, BodyLabel, StepLabel, ExitLabel: string;
  Pred, Op: string;
begin
  if (ANode = nil) or (ANode.ChildCount < 4) then
    Exit;
  if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
    Exit;
  LoopVar := ANode.ChildAt(0).Text;
  RegisterRuntimeVar(LoopVar);
  StartNode := ANode.ChildAt(1);
  EndNode := ANode.ChildAt(2);
  BodyNode := ANode.ChildAt(3);
  Direction := ANode.Text;
  if not EncodeRuntimeIntExprFold(StartNode, StartBlob) then
    Exit;
  if not EncodeRuntimeIntExprFold(EndNode, EndBlob) then
    Exit;
  if SameText(Direction, 'to') then
  begin
    Pred := 'sle';
    Op := 'add';
  end
  else if SameText(Direction, 'downto') then
  begin
    Pred := 'sge';
    Op := 'sub';
  end
  else
    Exit;
  FModel.AddTypedHirNode(
    'assign-runtime', LoopVar, 0, 0,
    LoopVar + #9 + StartBlob
  );
  CondLabel := NewBlockLabel('for-cond');
  BodyLabel := NewBlockLabel('for-body');
  StepLabel := NewBlockLabel('for-step');
  ExitLabel := NewBlockLabel('for-end');
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(CondLabel);
  CondBlob := 'var ' + LoopVar + #10 + EndBlob + 'cmp ' + Pred + #10;
  FModel.AddTypedHirNode(
    'cond-br-runtime', 'for', 0, 0,
    CondBlob + 'labels ' + BodyLabel + #9 + ExitLabel + #10
  );
  FCurrentBlockTerminated := True;
  FBreakLabels.Push(ExitLabel);
  FContinueLabels.Push(StepLabel);
  EmitBlockLabel(BodyLabel);
  WalkHaltCalls(BodyNode);
  EmitGotoLabel(StepLabel);
  EmitBlockLabel(StepLabel);
  FModel.AddTypedHirNode(
    'assign-runtime', LoopVar, 0, 0,
    LoopVar + #9 + 'var ' + LoopVar + #10 + 'int 1' + #10 + Op + #10
  );
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(ExitLabel);
  FBreakLabels.Pop;
  FContinueLabels.Pop;
end;

procedure TSemanticAnalyzer.LowerRuntimeTryFinallyStatement(const ANode: TGreenNode);
var
  TryBody, FinallyBody: TGreenNode;
  FinallyLabel, EndLabel: string;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then Exit;
  TryBody := ANode.ChildAt(0);
  FinallyBody := ANode.ChildAt(1);
  FinallyLabel := NewBlockLabel('finally');
  EndLabel := NewBlockLabel('endtry');

  FModel.AddTypedHirNode('try-begin-runtime', 'finally', 0, 0,
    FinallyLabel + #10);
  WalkHaltCalls(TryBody);
  FModel.AddTypedHirNode('try-end-runtime', 'finally', 0, 0, '');
  EmitGotoLabel(FinallyLabel);

  EmitBlockLabel(FinallyLabel);
  FModel.AddTypedHirNode('finally-begin-runtime', '', 0, 0, '');
  WalkHaltCalls(FinallyBody);
  FModel.AddTypedHirNode('finally-end-runtime', '', 0, 0, '');
  EmitGotoLabel(EndLabel);

  EmitBlockLabel(EndLabel);
end;

procedure TSemanticAnalyzer.LowerRuntimeTryExceptStatement(const ANode: TGreenNode);
var
  TryBody, HandlerBody: TGreenNode;
  ExceptLabel, EndLabel: string;
  I: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then Exit;
  TryBody := ANode.ChildAt(0);
  ExceptLabel := NewBlockLabel('except');
  EndLabel := NewBlockLabel('endtry');

  FModel.AddTypedHirNode('try-begin-runtime', 'except', 0, 0,
    ExceptLabel + #10);
  WalkHaltCalls(TryBody);
  FModel.AddTypedHirNode('try-end-runtime', 'except', 0, 0, '');
  EmitGotoLabel(EndLabel);

  EmitBlockLabel(ExceptLabel);
  FModel.AddTypedHirNode('except-begin-runtime', '', 0, 0, '');
  for I := 1 to ANode.ChildCount - 1 do
  begin
    HandlerBody := ANode.ChildAt(I);
    if HandlerBody <> nil then
      WalkHaltCalls(HandlerBody);
  end;
  FModel.AddTypedHirNode('except-end-runtime', '', 0, 0, '');
  EmitGotoLabel(EndLabel);

  EmitBlockLabel(EndLabel);
end;

procedure TSemanticAnalyzer.UnrollHaltForLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  LoopVar: string;
  StartValue, EndValue, IterValue: Int64;
  Direction: string;
  BodyNode: TGreenNode;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 4) then
    Exit;
  if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
    Exit;
  LoopVar := ANode.ChildAt(0).Text;
  if not EvaluateIntegerConstant(ANode.ChildAt(1), StartValue) then
    Exit;
  if not EvaluateIntegerConstant(ANode.ChildAt(2), EndValue) then
    Exit;
  Direction := ANode.Text;
  BodyNode := ANode.ChildAt(3);
  IterCount := 0;
  IterValue := StartValue;
  if SameText(Direction, 'to') then
  begin
    while (IterValue <= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkHaltCalls(BodyNode);
      Inc(IterValue);
      Inc(IterCount);
    end;
  end
  else if SameText(Direction, 'downto') then
  begin
    while (IterValue >= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkHaltCalls(BodyNode);
      Dec(IterValue);
      Inc(IterCount);
    end;
  end;
end;

procedure TSemanticAnalyzer.UnrollHaltWhileLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  CondNode, BodyNode: TGreenNode;
  CondValue: Int64;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  CondNode := ANode.ChildAt(0);
  BodyNode := ANode.ChildAt(1);
  IterCount := 0;
  while IterCount < MaxIterations do
  begin
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue = 0 then
      Exit;
    WalkHaltCalls(BodyNode);
    Inc(IterCount);
  end;
end;

procedure TSemanticAnalyzer.UnrollHaltRepeatLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  BodyNode, CondNode: TGreenNode;
  CondValue: Int64;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  BodyNode := ANode.ChildAt(0);
  CondNode := ANode.ChildAt(1);
  IterCount := 0;
  while IterCount < MaxIterations do
  begin
    WalkHaltCalls(BodyNode);
    Inc(IterCount);
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue <> 0 then
      Exit;
  end;
end;

procedure TSemanticAnalyzer.WalkRuntimeVarDecls(const ANode: TGreenNode);
var
  I, J: LongInt;
  Child, Decl, TypeChild, ArrayTypeNode: TGreenNode;
  IsStr: Boolean;
  ArrOperand: string;
  Folded, Value: Int64;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if (Child.NodeKind = gnkProcedureDecl) or
      (Child.NodeKind = gnkFunctionDecl) then
      Continue;
    if Child.NodeKind = gnkVarSection then
    begin
      for J := 0 to Child.ChildCount - 1 do
      begin
        Decl := Child.ChildAt(J);
        if (Decl = nil) or (Decl.NodeKind <> gnkVarDecl) or
          (Decl.Text = '') then
          Continue;
        IsStr := False;
        ArrayTypeNode := nil;
        if Decl.ChildCount > 0 then
        begin
          TypeChild := Decl.ChildAt(0);
          if (TypeChild <> nil) and
            (SameText(TypeChild.Text, 'String') or
             SameText(TypeChild.Text, 'AnsiString')) then
            IsStr := True;
        end;
        ArrayTypeNode := FindArrayTypeNodeForVarDecl(Child, J);
        RegisterRuntimeVar(Decl.Text);
        if IsStr then
        begin
          RegisterRuntimeStrVar(Decl.Text);
          RegisterOwnedRuntimeStrVar(Decl.Text);
          FModel.AddTypedHirNode(
            'var-decl-tstring-runtime', Decl.Text, 0, 0, Decl.Text
          );
        end
        else if ArrayTypeNode <> nil then
        begin
          RegisterArrayVarMetadata(Decl.Text, ArrayTypeNode, ArrOperand);
          FModel.AddTypedHirNode(
            'var-decl-arr-runtime', Decl.Text, 0, 0, ArrOperand
          );
        end
        else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
          (Length(Decl.ChildAt(0).Text) > 1) and (Decl.ChildAt(0).Text[1] = '^') then
        begin
          RegisterRuntimeVar(Decl.Text);
          RegisterPointerVar(Decl.Text, Copy(Decl.ChildAt(0).Text, 2,
            Length(Decl.ChildAt(0).Text)));
          FModel.AddTypedHirNode(
            'var-decl-ptr-runtime', Decl.Text, 0, 0, Decl.Text
          );
        end
        else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
          (TypeMetaSize(Decl.ChildAt(0).Text) > 0) then
        begin
          if TypeMetaIsRecord(Decl.ChildAt(0).Text) then
          begin
            RegisterRecordVar(Decl.Text, Decl.ChildAt(0).Text);
            FModel.AddTypedHirNode(
              'var-decl-record-runtime', Decl.Text, 0, 0,
              Decl.Text + #9 + IntToStr(TypeMetaSize(Decl.ChildAt(0).Text) div 8)
            );
            { RAII: 如果 record 含 managed 字段, 注册为 managed record }
            if IsManagedRecord(Decl.ChildAt(0).Text) then
              FRuntimeVars.RegisterManagedRecordVar(Decl.Text, Decl.ChildAt(0).Text);
          end
          else
          begin
            RegisterClassVar(Decl.Text, Decl.ChildAt(0).Text);
            FModel.AddTypedHirNode(
              'var-decl-ptr-runtime', Decl.Text, 0, 0, Decl.Text
            );
          end;
        end
        else
          FModel.AddTypedHirNode(
            'var-decl-runtime', Decl.Text, 0, 0, Decl.Text
          );
      end;
      Continue;
    end;
    WalkRuntimeVarDecls(Child);
  end;
end;
