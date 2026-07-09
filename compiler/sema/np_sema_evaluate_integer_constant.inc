function TSemanticAnalyzer.EvaluateIntegerConstant(const ANode: TGreenNode;
  out AValue: Int64): Boolean;
var
  ArgNode: TGreenNode;
  Fact: TSemanticScalarTypeFact;
  IntrinsicName: string;
  Parsed: Int64;
  ParseCode: Word;
  Left, Right: Int64;
  Op: string;
  BodyNode, DeclNode: TGreenNode;
  ParamSnaps: TParamSnapshots;
  TypeId: LongInt;
  TypeName: string;
begin
  AValue := 0;
  if ANode = nil then
    Exit(False);
  case ANode.NodeKind of
    gnkIntegerLiteral:
      begin
        Val(ANode.Text, Parsed, ParseCode);
        if ParseCode <> 0 then
          Exit(False);
        AValue := Parsed;
        Exit(True);
      end;
    gnkIdentifier:
      begin
        if SameText(ANode.Text, 'true') then
        begin
          AValue := 1;
          Exit(True);
        end;
        if SameText(ANode.Text, 'false') then
        begin
          AValue := 0;
          Exit(True);
        end;
        if FModel.LookupConstValue(ANode.Text, Parsed) then
        begin
          AValue := Parsed;
          Exit(True);
        end;
        if FModel.LookupVarInitValue(ANode.Text, Parsed) then
        begin
          AValue := Parsed;
          Exit(True);
        end;
        if (not FNoFold) and
          LookupProcedureBody(ANode.Text, BodyNode, DeclNode) and
          (BodyNode <> nil) and
          not IsCurrentlyInlining(ANode.Text) then
        begin
          PushInlining(ANode.Text);
          ParamSnaps := nil;
          try
            WalkAssignmentStatements(BodyNode);
          finally
            PopInlining;
            RestoreCallArgs(ParamSnaps);
          end;
          if FModel.LookupVarInitValue(ANode.Text, Parsed) then
          begin
            AValue := Parsed;
            Exit(True);
          end;
        end;
        Exit(False);
      end;
    gnkFunctionCall:
      begin
        if TryGetIntrinsicExprName(ANode, IntrinsicName) then
        begin
          ArgNode := nil;
          if ANode.ChildCount >= 2 then
            ArgNode := ANode.ChildAt(1);
          if SameText(IntrinsicName, 'SizeOf') and (ArgNode <> nil) then
          begin
            TypeId := 0;
            if ArgNode.NodeKind = gnkIdentifier then
              TypeId := ResolveTypeIdForOwner(
                ArgNode.Text,
                NormalizeUnitIdentity(FCurrentProcessingUnitId)
              );
            if TypeId <= 0 then
              TypeId := InferExpressionType(ArgNode);
            if (TypeId > 0) and FModel.GetTypeScalarFact(TypeId, Fact) then
            begin
              AValue := Fact.BitWidth div 8;
              Exit(AValue > 0);
            end;
            if (TypeId > 0) and (TypeId <= FModel.TypeCount) then
            begin
              TypeName := FModel.TypeAt(TypeId - 1).Name;
              if TypeMetaSize(TypeName) > 0 then
              begin
                AValue := TypeMetaSize(TypeName) div 8;
                Exit(AValue > 0);
              end;
            end;
          end
          else if SameText(IntrinsicName, 'Length') and (ArgNode <> nil) and
            (ArgNode.NodeKind = gnkStringLiteral) then
          begin
            AValue := Length(DecodePascalStringLiteral(ArgNode.Text));
            Exit(True);
          end
          else if SameText(IntrinsicName, 'Default') and (ArgNode <> nil) then
          begin
            TypeId := 0;
            if ArgNode.NodeKind = gnkIdentifier then
              TypeId := ResolveTypeIdForOwner(
                ArgNode.Text,
                NormalizeUnitIdentity(FCurrentProcessingUnitId)
              );
            if TypeId <= 0 then
              TypeId := InferExpressionType(ArgNode);
            if (TypeId > 0) and FModel.GetTypeScalarFact(TypeId, Fact) and
              (Fact.Kind in [sskBool, sskInt]) then
            begin
              AValue := 0;
              Exit(True);
            end;
          end
          else if SameText(IntrinsicName, 'Ord') and (ArgNode <> nil) then
          begin
            if (ArgNode.NodeKind = gnkStringLiteral) and
              (Length(ArgNode.Text) = 3) and (ArgNode.Text[1] = '''') then
            begin
              AValue := Ord(ArgNode.Text[2]);
              Exit(True);
            end;
            if EvaluateIntegerConstant(ArgNode, Parsed) then
            begin
              AValue := Parsed;
              Exit(True);
            end;
          end
          else if SameText(IntrinsicName, 'Chr') and (ArgNode <> nil) and
            EvaluateIntegerConstant(ArgNode, Parsed) then
          begin
            AValue := Parsed;
            Exit(True);
          end
          else if SameText(IntrinsicName, 'Pred') and (ArgNode <> nil) and
            EvaluateIntegerConstant(ArgNode, Parsed) then
          begin
            AValue := Parsed - 1;
            Exit(True);
          end
          else if SameText(IntrinsicName, 'Succ') and (ArgNode <> nil) and
            EvaluateIntegerConstant(ArgNode, Parsed) then
          begin
            AValue := Parsed + 1;
            Exit(True);
          end;
        end;
        if LookupProcedureBody(ANode.Text, BodyNode, DeclNode) and
          (BodyNode <> nil) and
          not IsCurrentlyInlining(ANode.Text) then
        begin
          PushInlining(ANode.Text);
          ParamSnaps := BindCallArgs(DeclNode, ANode, 1);
          try
            WalkAssignmentStatements(BodyNode);
          finally
            PopInlining;
            RestoreCallArgs(ParamSnaps);
          end;
          if FModel.LookupVarInitValue(ANode.Text, Parsed) then
          begin
            AValue := Parsed;
            Exit(True);
          end;
        end;
        Exit(False);
      end;
    gnkUnaryExpression:
      begin
        if ANode.ChildCount < 1 then
          Exit(False);
        if not EvaluateIntegerConstant(ANode.ChildAt(0), Parsed) then
          Exit(False);
        Op := ANode.Text;
        if Op = '-' then
          AValue := -Parsed
        else if Op = '+' then
          AValue := Parsed
        else if SameText(Op, 'not') then
          AValue := Ord(Parsed = 0)
        else
          Exit(False);
        Exit(True);
      end;
    gnkBinaryExpression:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if not EvaluateIntegerConstant(ANode.ChildAt(0), Left) then
          Exit(False);
        if not EvaluateIntegerConstant(ANode.ChildAt(1), Right) then
          Exit(False);
        Op := ANode.Text;
        if Op = '+' then
          AValue := Left + Right
        else if Op = '-' then
          AValue := Left - Right
        else if Op = '*' then
          AValue := Left * Right
        else if SameText(Op, 'div') then
        begin
          if Right = 0 then
          begin
            EmitSemaError(
              'sema.division-by-zero',
              'division by zero in constant expression',
              ANode.ByteOffset
            );
            Exit(False);
          end;
          AValue := Left div Right;
        end
        else if SameText(Op, 'mod') then
        begin
          if Right = 0 then
          begin
            EmitSemaError(
              'sema.division-by-zero',
              'division by zero in constant expression',
              ANode.ByteOffset
            );
            Exit(False);
          end;
          AValue := Left mod Right;
        end
        else if Op = '=' then
          AValue := Ord(Left = Right)
        else if Op = '<>' then
          AValue := Ord(Left <> Right)
        else if Op = '<' then
          AValue := Ord(Left < Right)
        else if Op = '>' then
          AValue := Ord(Left > Right)
        else if Op = '<=' then
          AValue := Ord(Left <= Right)
        else if Op = '>=' then
          AValue := Ord(Left >= Right)
        else if SameText(Op, 'and') then
          AValue := Ord((Left <> 0) and (Right <> 0))
        else if SameText(Op, 'or') then
          AValue := Ord((Left <> 0) or (Right <> 0))
        else
          Exit(False);
        Exit(True);
      end;
  end;
  Result := False;
end;


