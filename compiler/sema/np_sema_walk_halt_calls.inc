procedure TSemanticAnalyzer.WalkHaltCalls(const ANode: TGreenNode);
var
  I, ArgIndex, ExprId, NodeId: LongInt;
  Child, Arg, RhsNode, BranchNode, DeclNode: TGreenNode;
  Operand: string;
  Value, CondValue, Folded: Int64;
  Decoded, StringValue, FuncName, ArgName, DestroyFuncName: string;
  AncestorName: string;
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
    const AOperand: string; const ADisplayName: string);
  var
    LocalExprId, LocalNodeId: LongInt;
  begin
    { Batch 29: ADisplayName Write|WriteErr → write_i64_decimal fd. }
    LocalNodeId := FModel.AddTypedHirNode(
      'write-int-runtime', ADisplayName, 0, 0, AOperand
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
      { Do NOT WalkHaltCalls(if-node): that emits then+else unconditionally when
        the condition cannot be folded. Fall back to integer condition encoding
        (field loads, comparisons) before giving up. }
      if FNoFold and (Child.ChildCount >= 2) and
        EncodeRuntimeIntExprFold(Child.ChildAt(0), Operand) then
      begin
        Operand := Operand + 'int 0' + #10 + 'cmp ne' + #10;
        LowerRuntimeIfStatement(Child, Operand);
        Continue;
      end;
      if FNoFold then
        Continue;
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
      { Exit(expr) must assign into Result before cleanup/return. Bare Exit
        keeps the current Result value (or void for procedures). }
      if (Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) and
        (FCurrentRetVarName <> '') then
      begin
        if IsRuntimeStrVar(FCurrentRetVarName) then
        begin
          if Child.ChildAt(0).NodeKind = gnkStringLiteral then
            FModel.AddTypedHirNode('assign-tstring-literal-runtime',
              FCurrentRetVarName, 0, 0,
              DecodePascalStringLiteral(Child.ChildAt(0).Text))
          else if (Child.ChildAt(0).NodeKind = gnkIdentifier) and
            IsRuntimeStrVar(Child.ChildAt(0).Text) then
            FModel.AddTypedHirNode('assign-tstring-runtime',
              FCurrentRetVarName, 0, 0,
              FCurrentRetVarName + #9 + 'strvar ' +
              Child.ChildAt(0).Text + #10)
          else if (Child.ChildAt(0).NodeKind = gnkDotAccess) and
            (Child.ChildAt(0).ChildCount >= 2) and
            (Child.ChildAt(0).ChildAt(0) <> nil) and
            (Child.ChildAt(0).ChildAt(1) <> nil) and
            (Child.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
            (Child.ChildAt(0).ChildAt(1).NodeKind = gnkIdentifier) then
          begin
            { Exit(AState.SelectorName) / Exit(AState.CommandName) }
            FuncName := LookupClassVar(Child.ChildAt(0).ChildAt(0).Text);
            if FuncName = '' then
              FuncName := LookupRecordVar(Child.ChildAt(0).ChildAt(0).Text);
            if (FuncName <> '') and
              TypeMetaFieldIsStr(FuncName, Child.ChildAt(0).ChildAt(1).Text) then
            begin
              Value := TypeMetaFieldIndex(FuncName,
                Child.ChildAt(0).ChildAt(1).Text);
              if Value >= 0 then
                FModel.AddTypedHirNode(
                  'assign-tstring-field-load-runtime', FCurrentRetVarName, 0, 0,
                  Child.ChildAt(0).ChildAt(0).Text + #9 + IntToStr(Value));
            end;
          end;
        end
        else if EncodeRuntimeIntExprFold(Child.ChildAt(0), Operand) then
          FModel.AddTypedHirNode('assign-runtime', FCurrentRetVarName, 0, 0,
            FCurrentRetVarName + #9 + Operand);
      end;
      EmitClassVarFreeCleanupNodes;
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
            { Batch 25: string fields on records use TString field-store. }
            if (Arg <> nil) and (StringValue <> '') and
              (Child.ChildAt(0).ChildAt(1) <> nil) and
              TypeMetaFieldIsStr(StringValue, Child.ChildAt(0).ChildAt(1).Text) then
            begin
              if SameText(Child.ChildAt(0).ChildAt(0).Text, 'Result') and
                (FCurrentRetVarName <> '') then
                ReceiverName := FCurrentRetVarName
              else
                ReceiverName := Child.ChildAt(0).ChildAt(0).Text;
              if Arg.NodeKind = gnkStringLiteral then
                FModel.AddTypedHirNode(
                  'field-store-tstring-runtime', Decoded, 0, 0,
                  ReceiverName + #9 + IntToStr(Value) + #9 + 'lit ' +
                  DecodePascalStringLiteral(Arg.Text)
                )
              else if EvaluateStringConstant(Arg, Operand) then
                FModel.AddTypedHirNode(
                  'field-store-tstring-runtime', Decoded, 0, 0,
                  ReceiverName + #9 + IntToStr(Value) + #9 + 'lit ' + Operand
                )
              else if (Arg.NodeKind = gnkIdentifier) and
                IsRuntimeStrVar(Arg.Text) then
                FModel.AddTypedHirNode(
                  'field-store-tstring-runtime', Decoded, 0, 0,
                  ReceiverName + #9 + IntToStr(Value) + #9 + 'var ' + Arg.Text
                );
              Continue;
            end;
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
                  StringValue + #9 + 'callee ' + EffectiveRuntimeCalleeName(FuncName, nil) + #9 +
                  'ptr len owner alloc_size')
              else
              begin
                Operand := EncodeStrCallArgs(Arg, StringValue);
                if Operand <> '' then
                  Operand := #9 + Operand;
                FModel.AddTypedHirNode(
                  'assign-tstring-call-runtime', StringValue, 0, 0,
                  StringValue + #9 + 'callee ' + EffectiveRuntimeCalleeName(FuncName, nil) + Operand);
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
            OwnerClassName := RhsNode.ChildAt(0).ChildAt(0).Text;
            InhParentName := ResolveClassMethodCalleeName(OwnerClassName,
              RhsNode.ChildAt(0).ChildAt(1).Text);
            if InhParentName = '' then
              InhParentName := OwnerClassName + '.' +
                RhsNode.ChildAt(0).ChildAt(1).Text;
            Value := TypeMetaSize(OwnerClassName);
            StringValue := FuncName + #9 + InhParentName;
            for K := 1 to RhsNode.ChildCount - 1 do
              if (RhsNode.ChildAt(K) <> nil) and
                EncodeRuntimeIntExprFold(RhsNode.ChildAt(K), ArgName) then
                StringValue := StringValue + #9 + ArgName;
            RegisterRuntimeVar(FuncName);
            RegisterClassVar(FuncName, OwnerClassName);
            FModel.AddTypedHirNode(
              'class-new-runtime', IntToStr(Value), 0, 0, StringValue);
            if (TypeMetaVmtCount(OwnerClassName) > 0) or
              (TypeMetaInterfaces(OwnerClassName) <> '') then
              FModel.AddTypedHirNode('vmt-store-runtime',
                OwnerClassName, 0, 0,
                FuncName + #9 + OwnerClassName);
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
        { Keep source type; ancestor walk must not collapse to residual @.Ctor. }
        FuncName := Arg.ChildAt(0).ChildAt(0).Text;
        InhParentName := FuncName;
        StringValue := ResolveClassMethodCalleeName(InhParentName,
          Arg.ChildAt(0).ChildAt(1).Text);
        if StringValue = '' then
          StringValue := InhParentName + '.' + Arg.ChildAt(0).ChildAt(1).Text;
        if TypeMetaSize(InhParentName) > 0 then
        begin
          Value := TypeMetaSize(InhParentName);
          if (InhParentName = '') or (Copy(StringValue, 1, 1) = '.') then
          begin
            { skip broken ctor name }
          end
          else
          begin
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
              OwnerClassName := RhsNode.ChildAt(0).ChildAt(0).Text;
              InhParentName := ResolveClassMethodCalleeName(OwnerClassName,
                RhsNode.ChildAt(0).ChildAt(1).Text);
              if InhParentName = '' then
                InhParentName := OwnerClassName + '.' +
                  RhsNode.ChildAt(0).ChildAt(1).Text;
              Value := TypeMetaSize(OwnerClassName);
              StringValue := FuncName + #9 + InhParentName;
              for K := 1 to RhsNode.ChildCount - 1 do
                if (RhsNode.ChildAt(K) <> nil) and
                  EncodeRuntimeIntExprFold(RhsNode.ChildAt(K), ArgName) then
                  StringValue := StringValue + #9 + ArgName;
              RegisterRuntimeVar(FuncName);
              RegisterClassVar(FuncName, OwnerClassName);
              FModel.AddTypedHirNode(
                'class-new-runtime', IntToStr(Value), 0, 0, StringValue);
              if (TypeMetaVmtCount(OwnerClassName) > 0) or
              (TypeMetaInterfaces(OwnerClassName) <> '') then
                FModel.AddTypedHirNode('vmt-store-runtime',
                  OwnerClassName, 0, 0,
                  FuncName + #9 + OwnerClassName);
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
      end;
      if FNoFold and (Arg <> nil) and (Arg.NodeKind = gnkFunctionCall) and
        (Arg.ChildCount >= 1) and (Arg.ChildAt(0) <> nil) and
        (Arg.ChildAt(0).NodeKind = gnkIdentifier) and
        (Pos('specialize ', Arg.ChildAt(0).Text) = 1) and
        (Pos('.', Copy(Arg.ChildAt(0).Text, 12,
          Length(Arg.ChildAt(0).Text) - 11)) > 0) then
      begin
        { b4b-i7: F := specialize X<T>.M(...) — materialize the instance on
          demand and emit class-new with the resolved callee. The older walk
          branch only knew the compile-time free-function specialize form
          and dropped the method part, truncating cloned Create bodies at
          the FElementManager assignment (b4b-i7). }
        FuncName := ResolveSpecializedClassMethodCall(
          Copy(Arg.ChildAt(0).Text, 12, Length(Arg.ChildAt(0).Text) - 11));
        if FuncName <> '' then
        begin
          OwnerClassName := Copy(FuncName, 1, Pos('.', FuncName) - 1);
          Value := TypeMetaSize(OwnerClassName);
          CondValue := -1;
          if FCurrentMethodClass <> '' then
            CondValue := TypeMetaFieldIndex(FCurrentMethodClass, Decoded);
          if CondValue >= 0 then
          begin
            Inc(FBlockLabelCounter);
            ArgName := '$obj_tmp_' + IntToStr(FBlockLabelCounter);
            Operand := ArgName + #9 + FuncName;
            ArgIndex := 0;
            if Arg.NodeKind = gnkFunctionCall then
              ArgIndex := 1;
            while ArgIndex < Arg.ChildCount do
            begin
              RhsNode := Arg.ChildAt(ArgIndex);
              if (RhsNode <> nil) and
                EncodeRuntimeIntExprFold(RhsNode, StringValue) then
                Operand := Operand + #9 + StringValue;
              Inc(ArgIndex);
            end;
            RegisterRuntimeVar(ArgName);
            RegisterClassVar(ArgName, OwnerClassName);
            { The assigned field itself must also resolve as a class var so
              later `FElementManager.GetElementSize` finds its method via
              LookupClassVar instead of dropping the RHS (b4b-i7). }
            RegisterClassVar(Decoded, OwnerClassName);
            FModel.AddTypedHirNode('class-new-runtime',
              IntToStr(Value), 0, 0, Operand);
            if (TypeMetaVmtCount(OwnerClassName) > 0) or
              (TypeMetaInterfaces(OwnerClassName) <> '') then
              FModel.AddTypedHirNode('vmt-store-runtime', OwnerClassName, 0, 0,
                ArgName + #9 + OwnerClassName);
            FModel.AddTypedHirNode('field-store-runtime', Decoded, 0, 0,
              'self' + #9 + IntToStr(CondValue) + #9 + 'var ' + ArgName + #10);
          end
          else
          begin
            RegisterRuntimeVar(Decoded);
            RegisterClassVar(Decoded, OwnerClassName);
            Operand := Decoded + #9 + FuncName;
            ArgIndex := 0;
            if Arg.NodeKind = gnkFunctionCall then
              ArgIndex := 1;
            while ArgIndex < Arg.ChildCount do
            begin
              RhsNode := Arg.ChildAt(ArgIndex);
              if (RhsNode <> nil) and
                EncodeRuntimeIntExprFold(RhsNode, StringValue) then
                Operand := Operand + #9 + StringValue;
              Inc(ArgIndex);
            end;
            FModel.AddTypedHirNode('class-new-runtime',
              IntToStr(Value), 0, 0, Operand);
            if (TypeMetaVmtCount(OwnerClassName) > 0) or
              (TypeMetaInterfaces(OwnerClassName) <> '') then
              FModel.AddTypedHirNode('vmt-store-runtime', OwnerClassName, 0, 0,
                Decoded + #9 + OwnerClassName);
            if (LookupClassVar(Decoded) <> '') and
              TypeMetaIsInterface(LookupClassVar(Decoded)) and
              FModel.LookupConstValue(
                OwnerClassName + '$intf_offset_' + LookupClassVar(Decoded),
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
        { Prefer enum/const ordinals (qualified unit.path.ecX) over class-new. }
        if EvaluateIntegerConstant(Arg, Value) then
        begin
          FModel.AddVarInitValue(Decoded, Value);
          if FNoFold then
          begin
            RegisterRuntimeVar(Decoded);
            AddScalarAssignRuntimeNode(Decoded, Arg,
              'int ' + IntToStr(Value) + #10);
          end;
          Continue;
        end;
        { unit.qual.FreeFunc — nested DotAccess rightmost name is the callee.
          Must run before TypeMetaSize(left) class-new (left is not a class). }
        if (Arg.ChildAt(1).NodeKind = gnkIdentifier) and
          ((Arg.ChildAt(0).NodeKind = gnkDotAccess) or
           ((Arg.ChildAt(0).NodeKind = gnkIdentifier) and
            (TypeMetaSize(Arg.ChildAt(0).Text) <= 0) and
            (LookupClassVar(Arg.ChildAt(0).Text) = ''))) then
        begin
          FuncName := Arg.ChildAt(1).Text;
          if LookupProcedureBody(FuncName, BranchNode, DeclNode) or
            (LookupPtrReturnFunc(FuncName) <> '') then
          begin
            FuncName := EffectiveRuntimeCalleeName(FuncName, DeclNode);
            RegisterRuntimeVar(Decoded);
            if LookupPtrReturnFunc(Arg.ChildAt(1).Text) <> '' then
              RegisterClassVar(Decoded, LookupPtrReturnFunc(Arg.ChildAt(1).Text));
            Operand := 'call ' + FuncName + ' 0' + #10;
            NodeId := FModel.AddTypedHirNode(
              'assign-runtime', Decoded, 0, 0,
              Decoded + #9 + Operand);
            if (LookupClassVar(Decoded) <> '') and
              TypeMetaIsInterface(LookupClassVar(Decoded)) then
              FModel.AddTypedHirNode('intf-addref-runtime', Decoded, 0, 0, Decoded);
            Continue;
          end;
        end;
        Value := TypeMetaSize(Arg.ChildAt(0).Text);
        if Value > 0 then
        begin
          FuncName := Arg.ChildAt(0).Text;
          InhParentName := FuncName;
          StringValue := ResolveClassMethodCalleeName(InhParentName,
            Arg.ChildAt(1).Text);
          if StringValue = '' then
            StringValue := InhParentName + '.' + Arg.ChildAt(1).Text;
          { Empty class prefix → residual @.Ctor; not a real constructor. }
          if (InhParentName = '') or (Copy(StringValue, 1, 1) = '.') then
          begin
            { fall through to scalar encode }
          end
          else
          begin
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
              Decoded + #9 + 'callee ' + EffectiveRuntimeCalleeName(Arg.Text, nil)
            );
          end
          else if (Arg.NodeKind = gnkIdentifier) and
            LookupProcedureBody(Arg.Text, BranchNode, DeclNode) and
            IsRuntimeStrVar(Arg.Text) then
          begin
            FModel.AddTypedHirNode(
              'assign-tstring-call-runtime', Decoded, 0, 0,
              Decoded + #9 + 'callee ' + EffectiveRuntimeCalleeName(Arg.Text, nil)
            );
          end
          else if (Arg.NodeKind = gnkFunctionCall) and
            LookupProcedureBody(Arg.Text, BranchNode, DeclNode) and
            IsOwnedStringReturnFunc(Arg.Text) then
          begin
            Operand := EncodeStrCallArgs(Arg, Decoded);
            FModel.AddTypedHirNode(
              'assign-tstring-call-runtime', Decoded, 0, 0,
              Decoded + #9 + 'callee ' + EffectiveRuntimeCalleeName(Arg.Text, nil) + #9 + Operand
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
              Decoded + #9 + 'callee ' + EffectiveRuntimeCalleeName(Arg.Text, nil) + #9 + Operand
            );
            EmitPendingStringTempReleases;
          end
          else if (Arg.NodeKind = gnkDotAccess) and
            (Arg.ChildCount >= 2) and
            (Arg.ChildAt(0) <> nil) and
            (Arg.ChildAt(1) <> nil) and
            (Arg.ChildAt(0).NodeKind = gnkIdentifier) and
            (Arg.ChildAt(1).NodeKind = gnkIdentifier) and
            ((LookupClassVar(Arg.ChildAt(0).Text) <> '') or
             (LookupRecordVar(Arg.ChildAt(0).Text) <> '')) then
          begin
            { M := E.Message (class) or Result := A.S (record param/local).
              Batch 25: const record string field load was missing → empty sret. }
            FuncName := LookupClassVar(Arg.ChildAt(0).Text);
            if FuncName = '' then
              FuncName := LookupRecordVar(Arg.ChildAt(0).Text);
            if FuncName <> '' then
              FuncName := ResolveRecordAliasTypeName(FuncName);
            if TypeMetaFieldIsStr(FuncName, Arg.ChildAt(1).Text) then
            begin
              Value := TypeMetaFieldIndex(FuncName, Arg.ChildAt(1).Text);
              if Value >= 0 then
                FModel.AddTypedHirNode(
                  'assign-tstring-field-load-runtime', Decoded, 0, 0,
                  Arg.ChildAt(0).Text + #9 + IntToStr(Value)
                );
            end
            else
            begin
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
              begin
                { Non-vmt member: resolve the declared property read target.
                  Field target → direct load; getter (or no $read) → sret call
                  with record receivers passed by ref, not loaded as int
                  (M2 B3b: TGreenNode.Text → @TGreenNode.GetText). }
                if FModel.LookupStringConstValue(
                  FuncName + '.' + Arg.ChildAt(1).Text + '$read', Operand) and
                  (Operand <> '') and
                  (TypeMetaFieldIndex(FuncName, Operand) >= 0) then
                  FModel.AddTypedHirNode(
                    'assign-tstring-field-load-runtime', Decoded, 0, 0,
                    Arg.ChildAt(0).Text + #9 +
                    IntToStr(TypeMetaFieldIndex(FuncName, Operand))
                  )
                else
                begin
                  if Operand = '' then
                    Operand := Arg.ChildAt(1).Text;
                  if LookupRecordVar(Arg.ChildAt(0).Text) <> '' then
                    FModel.AddTypedHirNode(
                      'assign-tstring-call-runtime',
                      FuncName + '.' + Operand, 0, 0,
                      Decoded + #9 + 'recvar ' + Arg.ChildAt(0).Text
                    )
                  else
                    FModel.AddTypedHirNode(
                      'assign-tstring-call-runtime',
                      FuncName + '.' + Operand, 0, 0,
                      Decoded + #9 + 'var ' + Arg.ChildAt(0).Text
                    );
                end;
              end;
            end;
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
                StringValue + #9 + 'callee ' + EffectiveRuntimeCalleeName(FuncName, nil) + #9 +
                'ptr len owner alloc_size')
            else
            begin
              Operand := EncodeStrCallArgs(Arg, StringValue);
              if Operand <> '' then
                Operand := #9 + Operand;
              FModel.AddTypedHirNode(
                'assign-tstring-call-runtime', StringValue, 0, 0,
                StringValue + #9 + 'callee ' + EffectiveRuntimeCalleeName(FuncName, nil) + Operand);
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
        else if FNoFold and (Arg <> nil) and
          (Arg.NodeKind = gnkFunctionCall) and (Arg.ChildCount >= 1) and
          (Arg.ChildAt(0) <> nil) and
          (Arg.ChildAt(0).NodeKind = gnkDotAccess) and
          (Arg.ChildAt(0).ChildCount >= 2) and
          (Arg.ChildAt(0).ChildAt(1) <> nil) and
          (Arg.ChildAt(0).ChildAt(1).NodeKind = gnkIdentifier) and
          (TypeMetaSize(Arg.ChildAt(0).ChildAt(0).Text) <= 0) and
          ((LookupPtrReturnFunc(Arg.ChildAt(0).ChildAt(1).Text) <> '') or
           LookupProcedureBody(Arg.ChildAt(0).ChildAt(1).Text, BranchNode, DeclNode)) then
        begin
          { unit.qual.NewSHA256() — DotAccess callee is not Class.Create. }
          FuncName := Arg.ChildAt(0).ChildAt(1).Text;
          if EncodeRuntimeIntExprFold(Arg, Operand) then
          begin
            RegisterRuntimeVar(Decoded);
            if LookupPtrReturnFunc(FuncName) <> '' then
              RegisterClassVar(Decoded, LookupPtrReturnFunc(FuncName));
            NodeId := FModel.AddTypedHirNode(
              'assign-runtime', Decoded, 0, 0,
              Decoded + #9 + Operand);
            if (LookupClassVar(Decoded) <> '') and
              TypeMetaIsInterface(LookupClassVar(Decoded)) then
              FModel.AddTypedHirNode('intf-addref-runtime', Decoded, 0, 0, Decoded);
          end;
        end
        else if FNoFold and IsRecordVar(Decoded) and
          { Assignment Text is often the first LHS lexeme (Result for
            Result.f[i] := Abs(...)). Only plain `Result := Func(...)` is
            record-sret; field/array LHS must not residual-call bare @Func. }
          (Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkIdentifier) and
          (Arg <> nil) and (Arg.NodeKind = gnkFunctionCall) and
          (Arg.ChildCount >= 1) and (Arg.ChildAt(0) <> nil) and
          (Arg.ChildAt(0).NodeKind = gnkIdentifier) then
        begin
          if LookupProcedureBody(Arg.ChildAt(0).Text, BranchNode, DeclNode) then
          begin
            FuncName := EffectiveRuntimeCalleeName(Arg.ChildAt(0).Text, DeclNode);
            Operand := FuncName + #9 + 'recvar ' + Decoded + #10;
            for ArgIndex := 1 to Arg.ChildCount - 1 do
            begin
              RhsNode := Arg.ChildAt(ArgIndex);
              if (RhsNode <> nil) and EncodeRuntimeIntExprFold(RhsNode, StringValue) then
                Operand := Operand + #9 + StringValue;
            end;
            FModel.AddTypedHirNode('call-runtime',
              FuncName, 0, 0, Operand);
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
            EmitClassVarFreeCleanupNodes;
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
        EmitClassVarFreeCleanupNodes;
        EmitOwnedManagedRecordCleanupNodes;
        EmitOwnedDynArrayCleanupNodes;
        EmitOwnedStringCleanupNodes;
        FModel.AddTypedHirNode('halt-call', 'Halt', 0, 0, Operand);
        FCurrentBlockTerminated := True;
        Continue;
      end;
      if FNoFold and (Pos('specialize ', Child.Text) = 1) and
        (Pos('.', Copy(Child.Text, 12, Length(Child.Text) - 11)) > 0) then
      begin
        { b4b-i7: statement-form `specialize X<T>.M(...)` — same on-demand
          instantiation path as the assignment RHS branch above. }
        Decoded := ResolveSpecializedClassMethodCall(
          Copy(Child.Text, 12, Length(Child.Text) - 11));
        if Decoded <> '' then
        begin
          Arg := nil;
          if (Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) and
            (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
            Arg := Child.ChildAt(0);
          Operand := Decoded + #9 + 'var self' + #10;
          if Arg <> nil then
          begin
            for ArgIndex := 1 to Arg.ChildCount - 1 do
            begin
              RhsNode := Arg.ChildAt(ArgIndex);
              if (RhsNode <> nil) and
                EncodeRuntimeIntExprFold(RhsNode, StringValue) then
                Operand := Operand + #9 + StringValue;
            end;
          end;
          NodeId := FModel.AddTypedHirNode('call-runtime', Decoded, 0, 0,
            Operand);
          AttachStatementCallExpr(NodeId, Child);
          Continue;
        end;
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
        { Bare System.Write/WriteLn only. Method form LH.Write (DotAccess callee)
          must not fall into write_i64_decimal — that steals interface Write. }
        if (Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) and
          (((Child.ChildAt(0).NodeKind = gnkDotAccess)) or
           ((Child.ChildAt(0).NodeKind = gnkFunctionCall) and
            (Child.ChildAt(0).ChildCount >= 1) and
            (Child.ChildAt(0).ChildAt(0) <> nil) and
            (Child.ChildAt(0).ChildAt(0).NodeKind = gnkDotAccess))) then
        begin
          { fall through to member-call / ivcall paths below }
        end
        else
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
          { Batch 27: WriteLn(ErrOutput/StdErr, ...) maps host-free write to
            fd 2; Output/StdOut stay fd 1. ArgName = Write | WriteErr. }
          ArgName := 'Write';
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
            { Batch 25/27: textfile handle is not an integer payload. }
            if (RhsNode.NodeKind = gnkIdentifier) and
              (SameText(RhsNode.Text, 'ErrOutput') or
               SameText(RhsNode.Text, 'Output') or
               SameText(RhsNode.Text, 'StdOut') or
               SameText(RhsNode.Text, 'StdErr') or
               SameText(RhsNode.Text, 'Input')) then
            begin
              if SameText(RhsNode.Text, 'ErrOutput') or
                SameText(RhsNode.Text, 'StdErr') then
                ArgName := 'WriteErr'
              else if SameText(RhsNode.Text, 'Output') or
                SameText(RhsNode.Text, 'StdOut') then
                ArgName := 'Write';
              Inc(ArgIndex);
              Continue;
            end
            else if RhsNode.NodeKind = gnkStringLiteral then
              FModel.AddTypedHirNode(
                'write-string-runtime', ArgName, 0, 0,
                DecodePascalStringLiteral(RhsNode.Text)
              )
            else if EvaluateStringConstant(RhsNode, StringValue) then
              FModel.AddTypedHirNode(
                'write-string-runtime', ArgName, 0, 0, StringValue
              )
            else if (RhsNode.NodeKind = gnkIdentifier) and
              IsRuntimeStrVar(RhsNode.Text) and
              not LookupProcedureBody(RhsNode.Text, BranchNode, DeclNode) then
              FModel.AddTypedHirNode(
                'write-str-var-runtime', ArgName, 0, 0, RhsNode.Text
              )
            else if (RhsNode.NodeKind = gnkFunctionCall) and
              (RhsNode.ChildCount >= 2) and (RhsNode.ChildAt(0) <> nil) and
              SameText(RhsNode.ChildAt(0).Text, 'IntToStr') and
              EncodeRuntimeIntExprFold(RhsNode.ChildAt(1), Operand) then
              AddWriteIntRuntimeNode(RhsNode.ChildAt(1), Operand, ArgName)
            else if EmitOwnedStringWriteTemp(RhsNode, Operand) then
              FModel.AddTypedHirNode(
                'write-str-var-runtime', ArgName, 0, 0, Operand
              )
            else if EmitOwnedStringConcatWriteTemp(RhsNode, Operand) then
              FModel.AddTypedHirNode(
                'write-str-var-runtime', ArgName, 0, 0, Operand
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
                'assign-tstring-call-runtime',
                EffectiveRuntimeCalleeName(RhsNode.Text, DeclNode), 0, 0, Operand
              );
              FModel.AddTypedHirNode(
                'write-str-var-runtime', ArgName, 0, 0, Operand
              );
            end
            else if (RhsNode.NodeKind = gnkFunctionCall) and
              LookupProcedureBody(RhsNode.Text, BranchNode, DeclNode) and
              (IsOwnedStringReturnFunc(RhsNode.Text) or
               IsRuntimeStrVar(RhsNode.Text)) then
            begin
              { Batch 26: WriteLn(..., EnvelopeSelectorName(AState)) — string
                sret call as Write arg must use a private temp, not clobber the
                AState ptr slot (historical Fail SEGV) or fall through to
                write_i64_decimal. }
              Inc(FBlockLabelCounter);
              Operand := '$wrt_tmp_' + IntToStr(FBlockLabelCounter);
              RegisterRuntimeVar(Operand);
              RegisterRuntimeStrVar(Operand);
              FModel.AddTypedHirNode('var-decl-tstring-runtime', Operand, 0, 0, Operand);
              StringValue := EncodeStrCallArgs(RhsNode, Operand);
              if StringValue <> '' then
                FModel.AddTypedHirNode(
                  'assign-tstring-call-runtime', RhsNode.Text, 0, 0,
                  Operand + #9 + 'callee ' + EffectiveRuntimeCalleeName(RhsNode.Text, nil) + #9 + StringValue
                )
              else
                FModel.AddTypedHirNode(
                  'assign-tstring-call-runtime', RhsNode.Text, 0, 0,
                  Operand + #9 + 'callee ' + EffectiveRuntimeCalleeName(RhsNode.Text, nil)
                );
              FModel.AddTypedHirNode(
                'write-str-var-runtime', ArgName, 0, 0, Operand
              );
              EmitPendingStringTempReleases;
            end
            else if (RhsNode.NodeKind = gnkFunctionCall) and
              (RhsNode.ChildCount >= 1) and (RhsNode.ChildAt(0) <> nil) and
              (RhsNode.ChildAt(0).NodeKind = gnkDotAccess) and
              (RhsNode.ChildAt(0).ChildCount >= 2) and
              (RhsNode.ChildAt(0).ChildAt(0) <> nil) and
              (RhsNode.ChildAt(0).ChildAt(1) <> nil) then
            begin
              { WriteLn(Model.Status) — method string sret, not write_i64. }
              FuncName := LookupClassVar(RhsNode.ChildAt(0).ChildAt(0).Text);
              if FuncName = '' then
                FuncName := LookupRecordVar(RhsNode.ChildAt(0).ChildAt(0).Text);
              if FuncName = '' then
                FuncName := RhsNode.ChildAt(0).ChildAt(0).Text;
              if FuncName <> '' then
                FuncName := ResolveRecordAliasTypeName(FuncName);
              StringValue := FuncName + '.' + RhsNode.ChildAt(0).ChildAt(1).Text;
              if IsOwnedStringReturnFunc(StringValue) or
                IsOwnedStringReturnFunc(RhsNode.ChildAt(0).ChildAt(1).Text) or
                FModel.LookupConstValue(
                  FuncName + '$ret_str_' + RhsNode.ChildAt(0).ChildAt(1).Text,
                  CondValue) then
              begin
                Inc(FBlockLabelCounter);
                Operand := '$wrt_tmp_' + IntToStr(FBlockLabelCounter);
                RegisterRuntimeVar(Operand);
                RegisterRuntimeStrVar(Operand);
                FModel.AddTypedHirNode('var-decl-tstring-runtime', Operand, 0, 0, Operand);
                Decoded := EncodeStrCallArgs(RhsNode, Operand);
                if Decoded <> '' then
                  FModel.AddTypedHirNode(
                    'assign-tstring-call-runtime', StringValue, 0, 0,
                    Operand + #9 + 'callee ' + EffectiveRuntimeCalleeName(StringValue, nil) + #9 + Decoded
                  )
                else
                  FModel.AddTypedHirNode(
                    'assign-tstring-call-runtime', StringValue, 0, 0,
                    Operand + #9 + 'callee ' + EffectiveRuntimeCalleeName(StringValue, nil)
                  );
                FModel.AddTypedHirNode(
                  'write-str-var-runtime', ArgName, 0, 0, Operand
                );
                EmitPendingStringTempReleases;
              end
              else if EncodeRuntimeIntExprFold(RhsNode, Operand) then
                AddWriteIntRuntimeNode(RhsNode, Operand, ArgName);
            end
            else if (RhsNode.NodeKind = gnkDotAccess) and
              (RhsNode.ChildCount >= 2) and
              (RhsNode.ChildAt(0) <> nil) and
              (RhsNode.ChildAt(1) <> nil) and
              (RhsNode.ChildAt(0).NodeKind = gnkIdentifier) and
              (RhsNode.ChildAt(1).NodeKind = gnkIdentifier) and
              ((LookupClassVar(RhsNode.ChildAt(0).Text) <> '') or
               (LookupRecordVar(RhsNode.ChildAt(0).Text) <> '')) then
            begin
              { Write(E.Message) class or Write(AState.CommandName) record. }
              FuncName := LookupClassVar(RhsNode.ChildAt(0).Text);
              if FuncName = '' then
                FuncName := LookupRecordVar(RhsNode.ChildAt(0).Text);
              if FuncName <> '' then
                FuncName := ResolveRecordAliasTypeName(FuncName);
              if TypeMetaFieldIsStr(FuncName, RhsNode.ChildAt(1).Text) then
              begin
                Value := TypeMetaFieldIndex(FuncName, RhsNode.ChildAt(1).Text);
                if Value >= 0 then
                begin
                  Inc(FBlockLabelCounter);
                  Operand := '$wrt_tmp_' + IntToStr(FBlockLabelCounter);
                  RegisterRuntimeVar(Operand);
                  RegisterRuntimeStrVar(Operand);
                  FModel.AddTypedHirNode('var-decl-tstring-runtime', Operand, 0, 0, Operand);
                  FModel.AddTypedHirNode(
                    'assign-tstring-field-load-runtime', Operand, 0, 0,
                    RhsNode.ChildAt(0).Text + #9 + IntToStr(Value)
                  );
                  FModel.AddTypedHirNode(
                    'write-str-var-runtime', ArgName, 0, 0, Operand
                  );
                end;
              end
              else
              begin
                Value := TypeMetaVmtSlot(FuncName, RhsNode.ChildAt(1).Text);
                if (Value >= 0) and
                  (not FModel.LookupConstValue(
                    FuncName + '$ret_str_' + RhsNode.ChildAt(1).Text, CondValue)) and
                  EncodeRuntimeIntExprFold(RhsNode, Operand) then
                  AddWriteIntRuntimeNode(RhsNode, Operand, ArgName)
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
                    'write-str-var-runtime', ArgName, 0, 0, Operand
                  );
                end;
              end;
            end
            else if EncodeRuntimeIntExprFold(RhsNode, Operand) then
              AddWriteIntRuntimeNode(RhsNode, Operand, ArgName);
            Inc(ArgIndex);
          end;
          if SameText(Child.Text, 'WriteLn') then
            FModel.AddTypedHirNode(
              'write-string-runtime', ArgName, 0, 0, #10
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
            { Inc/Dec(Result): ret slot is seeded as FCurrentRetVarName, never
              bare "Result" (same remap as encode @Result path). Bare name
              would residual-call @Result() and re-alloca a detached slot. }
            if SameText(Decoded, 'Result') and (FCurrentRetVarName <> '') then
              Decoded := FCurrentRetVarName;
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
      { Interlocked* family (restored from 3d8121441; lost when the monolith
        was split into .inc files — M2 B6). Lowers to HIR interlocked-*
        intrinsics -> LLVM cmpxchg/atomicrmw instead of a direct call. }
      { InterlockedCompareExchange(Target, NewValue, CompareValue) -> old value }
      if FNoFold and SameText(Child.Text, 'InterlockedCompareExchange') then
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
          Operand := '';
          if EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), StringValue) then
            Operand := StringValue
          else
            Operand := 'int 0' + #10;
          if EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 2), StringValue) then
            Operand := Operand + #9 + StringValue
          else
            Operand := Operand + #9 + 'int 0' + #10;
          FModel.AddTypedHirNode(
            'interlocked-cas-runtime', Decoded, 0, 0,
            Decoded + #9 + Operand);
        end;
        Continue;
      end;
      { InterlockedExchange(Target, NewValue) -> old value }
      if FNoFold and SameText(Child.Text, 'InterlockedExchange') then
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
          if EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), StringValue) then
            FModel.AddTypedHirNode(
              'interlocked-xchg-runtime', Decoded, 0, 0,
              Decoded + #9 + StringValue);
        end;
        Continue;
      end;
      { InterlockedExchangeAdd(Target, Value) -> old value }
      if FNoFold and SameText(Child.Text, 'InterlockedExchangeAdd') then
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
          if EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), StringValue) then
            FModel.AddTypedHirNode(
              'interlocked-fetch-add-runtime', Decoded, 0, 0,
              Decoded + #9 + StringValue);
        end;
        Continue;
      end;
      { InterlockedCompareExchange64(Target, NewValue, CompareValue) -> old value }
      if FNoFold and SameText(Child.Text, 'InterlockedCompareExchange64') then
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
          Operand := '';
          if EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), StringValue) then
            Operand := StringValue
          else
            Operand := 'int 0' + #10;
          if EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 2), StringValue) then
            Operand := Operand + #9 + StringValue
          else
            Operand := Operand + #9 + 'int 0' + #10;
          FModel.AddTypedHirNode(
            'interlocked-cas64-runtime', Decoded, 0, 0,
            Decoded + #9 + Operand);
        end;
        Continue;
      end;
      { InterlockedExchangeAdd64(Target, Value) -> old value }
      if FNoFold and SameText(Child.Text, 'InterlockedExchangeAdd64') then
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
          if EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), StringValue) then
            FModel.AddTypedHirNode(
              'interlocked-fetch-add64-runtime', Decoded, 0, 0,
              Decoded + #9 + StringValue);
        end;
        Continue;
      end;
      { InterlockedIncrement(Target) -> new value (= old + 1) }
      if FNoFold and SameText(Child.Text, 'InterlockedIncrement') then
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
            'interlocked-fetch-add-runtime', Decoded, 0, 0,
            Decoded + #9 + 'int 1' + #10);
        end;
        Continue;
      end;
      { InterlockedDecrement(Target) -> new value (= old - 1) }
      if FNoFold and SameText(Child.Text, 'InterlockedDecrement') then
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
            'interlocked-fetch-add-runtime', Decoded, 0, 0,
            Decoded + #9 + 'int -1' + #10);
        end;
        Continue;
      end;
      if FNoFold and (FCurrentMethodClass <> '') and
        (Pos('inherited ', Child.Text) = 1) then
      begin
        InhMethodName := Copy(Child.Text, 11, Length(Child.Text));
        { Walk ancestors: prefer non-TObject with Create body/symbol. }
        InhParentName := NextClassAncestorName(FCurrentMethodClass);
        FuncName := '';
        OwnerClassName := '';
        while InhParentName <> '' do
        begin
          if LookupProcedureBody(InhParentName + '.' + InhMethodName,
            BranchNode, DeclNode) or
            (FModel.FindSymbolByName(InhParentName + '.' + InhMethodName) <> 0) then
          begin
            if not SameText(InhParentName, 'TObject') then
            begin
              FuncName := InhParentName;
              Break;
            end
            else if FuncName = '' then
              FuncName := InhParentName;
          end;
          if (OwnerClassName = '') and (not SameText(InhParentName, 'TObject')) then
            OwnerClassName := InhParentName;
          InhParentName := NextClassAncestorName(InhParentName);
        end;
        { Found-anywhere wins: a TObject-only hit must not be overridden by
          the method-blind direct-parent guess — TInterfacedObject declares
          no Destroy, so `inherited Destroy` must land on TObject.Destroy,
          not residual @TInterfacedObject.Destroy (M2 B4). The OwnerClassName
          guess only backstops chains where no ancestor symbol was found. }
        if FuncName <> '' then
          InhParentName := FuncName
        else if OwnerClassName <> '' then
          InhParentName := OwnerClassName;
        if InhParentName <> '' then
        begin
          StringValue := InhParentName + '.' + InhMethodName;
          { The matched ancestor may be an alias station (ECore): canonicalize
            via $resolve table / alias peel so the callee names a real body.
            The OwnerClassName backstop guess stays raw by design. }
          if (FuncName <> '') and (not SameText(FuncName, 'TObject')) then
          begin
            Decoded := ResolveClassMethodCalleeName(FuncName, InhMethodName);
            if Decoded <> '' then
              StringValue := Decoded;
          end;
          Operand := StringValue + #9 + 'var self' + #10;
          for ArgIndex := 0 to Child.ChildCount - 1 do
          begin
            RhsNode := Child.ChildAt(ArgIndex);
            if (RhsNode <> nil) and EncodeRuntimeIntExprFold(RhsNode, Decoded) then
              Operand := Operand + #9 + Decoded;
          end;
          NodeId := FModel.AddTypedHirNode('call-runtime',
            StringValue, 0, 0, Operand);
          AttachStatementCallExpr(NodeId, Child);
          Continue;
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
            { Multi-arg interface: ivcall with ExtraArgCount = actual stack
              pushes (not ChildCount). Const args must fold to int — bare
              `var SHA256_DIGEST_SIZE` has no alloca and was dropped, leaving
              @IHasher.Sum undefined via the old direct-call fallback. }
            Value := TypeMetaVmtSlot(StringValue,
              Child.ChildAt(0).ChildAt(0).ChildAt(1).Text);
            if Value >= 0 then
            begin
              Operand := 'var ' + Child.ChildAt(0).ChildAt(0).ChildAt(0).Text + #10;
              CondValue := 0; { ExtraArgCount }
              for ArgIndex := 1 to Child.ChildAt(0).ChildCount - 1 do
              begin
                RhsNode := Child.ChildAt(0).ChildAt(ArgIndex);
                if RhsNode = nil then
                  Continue;
                if (RhsNode.NodeKind = gnkIdentifier) and
                  SameText(RhsNode.Text, 'Result') and (FCurrentRetVarName <> '') then
                begin
                  Operand := Operand + 'varref ' + FCurrentRetVarName + #10;
                  Inc(CondValue);
                  Continue;
                end;
                if (RhsNode.NodeKind = gnkIdentifier) and
                  IsRuntimeArrVar(RhsNode.Text) then
                begin
                  Operand := Operand + 'var ' + RhsNode.Text + '$ptr' + #10;
                  Inc(CondValue);
                  Continue;
                end;
                if (RhsNode.NodeKind = gnkIdentifier) and
                  SameText(RhsNode.Text, 'Result') and
                  IsRuntimeArrVar(FCurrentRetVarName) then
                begin
                  Operand := Operand + 'var ' + FCurrentRetVarName + '$ptr' + #10;
                  Inc(CondValue);
                  Continue;
                end;
                if EvaluateIntegerConstant(RhsNode, Folded) then
                begin
                  Operand := Operand + 'int ' + IntToStr(Folded) + #10;
                  Inc(CondValue);
                  Continue;
                end;
                if EncodeRuntimeIntExprFold(RhsNode, Decoded) then
                begin
                  Operand := Operand + Decoded;
                  Inc(CondValue);
                end;
              end;
              Operand := Operand + 'ivcall ' + IntToStr(Value) + ' ' +
                IntToStr(CondValue);
              if TypeMetaRetPtr(StringValue,
                Child.ChildAt(0).ChildAt(0).ChildAt(1).Text) then
                Operand := Operand + ' p';
              Operand := Operand + #10;
              NodeId := FModel.AddTypedHirNode('halt-call-runtime', '__discard__',
                0, 0, Operand);
              { Prefer structured shekInterfaceCall when BuildRuntimeScalarHirExpr
                succeeds; blob ivcall is the reliable fallback. }
              AttachStatementCallExpr(NodeId, Child.ChildAt(0));
              Continue;
            end;
            { No VmtSlot — fall through to direct Intf.Method (should be rare). }
            InhParentName := StringValue;
          end;
          { class virtual: 语句位历来按 direct call 静态绑定到声明类符号,
            abstract virtual(无方法体, TCollection.Clear/AppendToUnchecked 即此)
            产生 undefined 符号。命中 vmt 槽改发 vcall 槽 dispatch, 与上方
            interface ivcall 分支同构(builder/emitter 已支持 vcall)。 }
          Value := TypeMetaVmtSlot(StringValue,
            Child.ChildAt(0).ChildAt(0).ChildAt(1).Text);
          if Value >= 0 then
          begin
            Operand := 'var ' + Child.ChildAt(0).ChildAt(0).ChildAt(0).Text + #10;
            CondValue := 0; { ExtraArgCount = 实际入栈数 }
            for ArgIndex := 1 to Child.ChildAt(0).ChildCount - 1 do
            begin
              RhsNode := Child.ChildAt(0).ChildAt(ArgIndex);
              if RhsNode = nil then
                Continue;
              if (RhsNode.NodeKind = gnkIdentifier) and
                SameText(RhsNode.Text, 'Result') and (FCurrentRetVarName <> '') then
              begin
                Operand := Operand + 'varref ' + FCurrentRetVarName + #10;
                Inc(CondValue);
                Continue;
              end;
              if (RhsNode.NodeKind = gnkIdentifier) and
                IsRuntimeArrVar(RhsNode.Text) then
              begin
                Operand := Operand + 'var ' + RhsNode.Text + '$ptr' + #10;
                Inc(CondValue);
                Continue;
              end;
              if EvaluateIntegerConstant(RhsNode, Folded) then
              begin
                Operand := Operand + 'int ' + IntToStr(Folded) + #10;
                Inc(CondValue);
                Continue;
              end;
              if EncodeRuntimeIntExprFold(RhsNode, Decoded) then
              begin
                Operand := Operand + Decoded;
                Inc(CondValue);
              end;
            end;
            Operand := Operand + 'vcall ' + IntToStr(Value) + ' ' +
              IntToStr(CondValue);
            if TypeMetaRetPtr(StringValue,
              Child.ChildAt(0).ChildAt(0).ChildAt(1).Text) then
              Operand := Operand + ' p';
            Operand := Operand + #10;
            NodeId := FModel.AddTypedHirNode('halt-call-runtime', '__discard__',
              0, 0, Operand);
            AttachStatementCallExpr(NodeId, Child.ChildAt(0));
            Continue;
          end;
          Operand := InhParentName + '.' +
            Child.ChildAt(0).ChildAt(0).ChildAt(1).Text + #9 +
            'var ' + Child.ChildAt(0).ChildAt(0).ChildAt(0).Text + #10;
          for ArgIndex := 1 to Child.ChildAt(0).ChildCount - 1 do
          begin
            RhsNode := Child.ChildAt(0).ChildAt(ArgIndex);
            if RhsNode = nil then
              Continue;
            { out/untyped + static-array Result need address, not loaded value. }
            if (RhsNode.NodeKind = gnkIdentifier) and
              SameText(RhsNode.Text, 'Result') and (FCurrentRetVarName <> '') then
            begin
              Operand := Operand + #9 + 'varref ' + FCurrentRetVarName + #10;
              Continue;
            end;
            if (RhsNode.NodeKind = gnkIdentifier) and
              IsRuntimeArrVar(RhsNode.Text) then
            begin
              Operand := Operand + #9 + 'var ' + RhsNode.Text + '$ptr' + #10;
              Continue;
            end;
            if EvaluateIntegerConstant(RhsNode, Folded) then
            begin
              Operand := Operand + #9 + 'int ' + IntToStr(Folded) + #10;
              Continue;
            end;
            if (RhsNode.NodeKind = gnkFunctionCall) and
              (RhsNode.ChildCount >= 1) and (RhsNode.ChildAt(0) <> nil) and
              (RhsNode.ChildAt(0).NodeKind = gnkDotAccess) and
              (RhsNode.ChildAt(0).ChildCount >= 2) and
              (RhsNode.ChildAt(0).ChildAt(0) <> nil) and
              (TypeMetaSize(RhsNode.ChildAt(0).ChildAt(0).Text) > 0) then
            begin
              Inc(FBlockLabelCounter);
              FuncName := '$arg_tmp_' + IntToStr(FBlockLabelCounter);
              OwnerClassName := RhsNode.ChildAt(0).ChildAt(0).Text;
              InhMethodName := ResolveClassMethodCalleeName(OwnerClassName,
                RhsNode.ChildAt(0).ChildAt(1).Text);
              if InhMethodName = '' then
                InhMethodName := OwnerClassName + '.' +
                  RhsNode.ChildAt(0).ChildAt(1).Text;
              Value := TypeMetaSize(OwnerClassName);
              Decoded := FuncName + #9 + InhMethodName;
              for K := 1 to RhsNode.ChildCount - 1 do
                if (RhsNode.ChildAt(K) <> nil) and
                  EncodeRuntimeIntExprFold(RhsNode.ChildAt(K), ArgName) then
                  Decoded := Decoded + #9 + ArgName;
              RegisterRuntimeVar(FuncName);
              RegisterClassVar(FuncName, OwnerClassName);
              FModel.AddTypedHirNode(
                'class-new-runtime', IntToStr(Value), 0, 0, Decoded);
              if (TypeMetaVmtCount(OwnerClassName) > 0) or
              (TypeMetaInterfaces(OwnerClassName) <> '') then
                FModel.AddTypedHirNode('vmt-store-runtime',
                  OwnerClassName, 0, 0,
                  FuncName + #9 + OwnerClassName);
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
          { 目标类无 Destroy 方法体($vmt_func_ 缺失或槽解析失败, 未声明
            destructor 的类如 TAstFacade 即此): 沿祖先链找第一个有方法体的
            X.Destroy(found-anywhere-wins), 避免 residual 成 undefined
            @Class.Destroy。TObject.Destroy 由根 seed 兜底。 }
          if not LookupProcedureBody(DestroyFuncName, BranchNode, DeclNode) then
          begin
            AncestorName := NextClassAncestorName(StringValue);
            while AncestorName <> '' do
            begin
              if LookupProcedureBody(AncestorName + '.Destroy',
                BranchNode, DeclNode) then
              begin
                DestroyFuncName := AncestorName + '.Destroy';
                Break;
              end;
              AncestorName := NextClassAncestorName(AncestorName);
            end;
          end;
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
        end
        else if (FCurrentMethodClass <> '') and
          (TypeMetaFieldIndex(FCurrentMethodClass,
             Child.ChildAt(0).ChildAt(0).Text) >= 0) then
        begin
          { .Free on a class-typed field receiver (FPlan.Free): no runtime
            var exists, so the flow above can't fire and the call fell to a
            residual @TX.Free. Load the field into a ptr temp and run the
            same object-free contract on the temp (M2 B3c). }
          for K := 1 to FModel.SymbolCount do
            if SameText(FModel.SymbolAt(K).Name,
                Child.ChildAt(0).ChildAt(0).Text) and
              SameText(FModel.SymbolAt(K).Kind, 'field') then
            begin
              if FModel.SymbolAt(K).TypeId > 0 then
                StringValue := FModel.TypeAt(
                  FModel.SymbolAt(K).TypeId - 1).Name;
              Break;
            end;
          if (StringValue <> '') and TypeMetaIsClass(StringValue) then
          begin
            Inc(FBlockLabelCounter);
            ReceiverName := '$objfree_tmp_' + IntToStr(FBlockLabelCounter);
            RegisterRuntimeVar(ReceiverName);
            RegisterClassVar(ReceiverName, StringValue);
            FModel.AddTypedHirNode('var-decl-ptr-runtime', ReceiverName,
              0, 0, ReceiverName);
            FModel.AddTypedHirNode('assign-runtime', ReceiverName, 0, 0,
              ReceiverName + #9 + 'field self ' + IntToStr(
                TypeMetaFieldIndex(FCurrentMethodClass,
                  Child.ChildAt(0).ChildAt(0).Text)) + ' p' + #10);
            Value := TypeMetaVmtSlot(StringValue, 'Destroy');
            DestroyFuncName := StringValue + '.Destroy';
            if (Value >= 0) and FModel.LookupStringConstValue(
              StringValue + '$vmt_func_' + IntToStr(Value),
              FuncName
            ) then
              DestroyFuncName := FuncName;
            { 同直接 receiver 分支: 无 Destroy 方法体时沿祖先链
              found-anywhere-wins, 防 residual undefined。 }
            if not LookupProcedureBody(DestroyFuncName, BranchNode, DeclNode) then
            begin
              AncestorName := NextClassAncestorName(StringValue);
              while AncestorName <> '' do
              begin
                if LookupProcedureBody(AncestorName + '.Destroy',
                  BranchNode, DeclNode) then
                begin
                  DestroyFuncName := AncestorName + '.Destroy';
                  Break;
                end;
                AncestorName := NextClassAncestorName(AncestorName);
              end;
            end;
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
          { class virtual 语句位(无参或带参 DotAccess): 与分支 1 同理,
            命中 vmt 槽改发 vcall dispatch, 避免 abstract virtual direct call
            产生 undefined 符号。 }
          Value := TypeMetaVmtSlot(StringValue,
            Child.ChildAt(0).ChildAt(1).Text);
          if Value >= 0 then
          begin
            Operand := 'var ' + Child.ChildAt(0).ChildAt(0).Text + #10;
            CondValue := 0; { ExtraArgCount }
            Arg := nil;
            if Child.ChildAt(0).NodeKind = gnkFunctionCall then
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
                if (RhsNode <> nil) and
                  EncodeRuntimeIntExprFold(RhsNode, Decoded) then
                begin
                  Operand := Operand + Decoded;
                  Inc(CondValue);
                end;
              end;
            end;
            Operand := Operand + 'vcall ' + IntToStr(Value) + ' ' +
              IntToStr(CondValue);
            if TypeMetaRetPtr(StringValue,
              Child.ChildAt(0).ChildAt(1).Text) then
              Operand := Operand + ' p';
            Operand := Operand + #10;
            NodeId := FModel.AddTypedHirNode('halt-call-runtime', '__discard__',
              0, 0, Operand);
            AttachStatementCallExpr(NodeId, Child.ChildAt(0));
            Continue;
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
        { implicit-self 语句位 class virtual(无 receiver 方法调用): 同理
          命中 vmt 槽改发 vcall, 避免 abstract virtual direct call undefined。 }
        Value := TypeMetaVmtSlot(FCurrentMethodClass, Child.Text);
        if Value >= 0 then
        begin
          Operand := 'var self' + #10;
          CondValue := 0; { ExtraArgCount }
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
              begin
                Operand := Operand + Decoded;
                Inc(CondValue);
              end;
              Inc(ArgIndex);
            end;
          end;
          Operand := Operand + 'vcall ' + IntToStr(Value) + ' ' +
            IntToStr(CondValue);
          if TypeMetaRetPtr(FCurrentMethodClass, Child.Text) then
            Operand := Operand + ' p';
          Operand := Operand + #10;
          NodeId := FModel.AddTypedHirNode('halt-call-runtime', '__discard__',
            0, 0, Operand);
          AttachStatementCallExpr(NodeId, Child);
          Continue;
        end;
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
        { Must match SeedFunctionBodies EffName (GetParamSignature, not s/i). }
        Operand := EffectiveRuntimeCalleeName(Child.Text, DeclNode);
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
