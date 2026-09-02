function TSemanticAnalyzer.EvaluateIntegerConstant(const ANode: TGreenNode;
  out AValue: Int64): Boolean;
var
  ArgNode: TGreenNode;
  Fact: TSemanticScalarTypeFact;
  Meta: TTypeMetadata;
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
    gnkDotAccess:
      begin
        { unit/type-qualified enum const: nextpas.core.exception.ecInvalidArgument
          → resolve rightmost identifier as const ordinal. }
        ArgNode := ANode;
        while (ArgNode <> nil) and (ArgNode.NodeKind = gnkDotAccess) and
          (ArgNode.ChildCount >= 2) do
          ArgNode := ArgNode.ChildAt(1);
        if (ArgNode <> nil) and (ArgNode.NodeKind = gnkIdentifier) and
          FModel.LookupConstValue(ArgNode.Text, Parsed) then
        begin
          AValue := Parsed;
          Exit(True);
        end;
        Exit(False);
      end;
    gnkStringLiteral:
      begin
        { Char ordinal: '/' / #10 style single-char string literals. }
        if (Length(ANode.Text) = 3) and (ANode.Text[1] = '''') and
          (ANode.Text[3] = '''') then
        begin
          AValue := Ord(ANode.Text[2]);
          Exit(True);
        end;
        Exit(False);
      end;
    gnkFunctionCall:
      begin
        { Type cast TypeName(const) — TryGetIntrinsicExprName rejects casts.
          Needed so `UNICODE_MAX = TUnicodeCodepoint($10FFFF)` / PtrUInt(1)
          seed via ProcessConstSection. }
        if (ANode.ChildCount = 2) and
          TryGetTypeCastTargetTypeId(ANode, TypeId) and
          EvaluateIntegerConstant(ANode.ChildAt(1), Parsed) then
        begin
          AValue := Parsed;
          Exit(True);
        end;
        if TryGetIntrinsicExprName(ANode, IntrinsicName) then
        begin
          ArgNode := nil;
          if ANode.ChildCount >= 2 then
            ArgNode := ANode.ChildAt(1);
          if SameText(IntrinsicName, 'SizeOf') and (ArgNode <> nil) then
          begin
            { Static/local array vars: arr_len * elem_size (bytes). Prefer this
              before type-id inference so Buf: array[0..N] of Char is not
              mis-sized as a pointer/scalar fact. }
            if (ArgNode.NodeKind = gnkIdentifier) and
              FModel.LookupConstValue(ArgNode.Text + '$arr_len', Parsed) and
              (Parsed > 0) then
            begin
              Left := DynArrayElemSizeOfVar(ArgNode.Text);
              if Left <= 0 then
                Left := 1;
              AValue := Parsed * Left;
              Exit(AValue > 0);
            end;
            { Dynarray type/var SizeOf is pointer width (descriptor). }
            if (ArgNode.NodeKind = gnkIdentifier) and
              (TypeMetaIsDynArrayType(ArgNode.Text) or
               IsRuntimeArrVar(ArgNode.Text)) and
              (not FModel.LookupConstValue(ArgNode.Text + '$arr_static', Parsed)) then
            begin
              AValue := 8;
              Exit(True);
            end;
            if (ArgNode.NodeKind = gnkIdentifier) then
            begin
              TypeName := LookupRecordVar(ArgNode.Text);
              if (TypeName <> '') and (TypeMetaSize(TypeName) > 0) then
              begin
                AValue := TypeMetaSize(TypeName);
                Exit(True);
              end;
              if TypeMetaSize(ArgNode.Text) > 0 then
              begin
                AValue := TypeMetaSize(ArgNode.Text);
                Exit(True);
              end;
            end;
            TypeId := 0;
            if ArgNode.NodeKind = gnkIdentifier then
              TypeId := ResolveTypeIdForOwner(
                ArgNode.Text,
                NormalizeUnitIdentity(FCurrentProcessingUnitId)
              );
            if TypeId <= 0 then
              TypeId := InferExpressionType(ArgNode);
            if TypeId > 0 then
              TypeId := CanonicalTypeId(TypeId);
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
                { TypeMetaSize is bytes for record/class metas. }
                AValue := TypeMetaSize(TypeName);
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
            if TypeId > 0 then
              TypeId := CanonicalTypeId(TypeId);
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
          end
          else if (SameText(IntrinsicName, 'High') or SameText(IntrinsicName, 'Low')) and
            (ArgNode <> nil) then
          begin
            { High/Low(type): needed so `MaxInt = High(Integer)` seeds via
              ProcessConstSection → AddConstValue (else residual @MaxInt()).
              High/Low(static array var): use $arr_high / $arr_low. }
            if ArgNode.NodeKind = gnkIdentifier then
            begin
              if SameText(IntrinsicName, 'High') and
                FModel.LookupConstValue(ArgNode.Text + '$arr_high', Parsed) then
              begin
                AValue := Parsed;
                Exit(True);
              end;
              if SameText(IntrinsicName, 'Low') and
                FModel.LookupConstValue(ArgNode.Text + '$arr_low', Parsed) then
              begin
                AValue := Parsed;
                Exit(True);
              end;
              { High/Low(static array type alias). }
              if SameText(IntrinsicName, 'High') and
                FModel.LookupConstValue(ArgNode.Text + '$arr_high', Parsed) then
              begin
                AValue := Parsed;
                Exit(True);
              end;
              TypeId := ResolveTypeIdForOwner(
                ArgNode.Text,
                NormalizeUnitIdentity(FCurrentProcessingUnitId)
              );
              if TypeId <= 0 then
                TypeId := FModel.FindTypeByName(ArgNode.Text);
              if TypeId > 0 then
                TypeId := CanonicalTypeId(TypeId);
              { Walk parent/alias chain — unit re-AddType can leave the head
                without a scalar fact even after CanonicalTypeId. }
              Parsed := 0;
              while (TypeId > 0) and (TypeId <= FModel.TypeCount) and
                (Parsed < 16) do
              begin
                if FModel.GetTypeScalarFact(TypeId, Fact) and
                  (Fact.Kind in [sskBool, sskInt]) and (Fact.BitWidth > 0) then
                begin
                  if SameText(IntrinsicName, 'Low') then
                  begin
                    if Fact.Signed then
                      AValue := -(Int64(1) shl (Fact.BitWidth - 1))
                    else
                      AValue := 0;
                  end
                  else
                  begin
                    if Fact.Signed then
                      AValue := (Int64(1) shl (Fact.BitWidth - 1)) - 1
                    else if Fact.BitWidth >= 64 then
                      AValue := Int64(-1) { all bits; QWord max as bit pattern }
                    else
                      AValue := (Int64(1) shl Fact.BitWidth) - 1;
                  end;
                  Exit(True);
                end;
                if FModel.GetTypeMeta(TypeId, Meta) and
                  (Meta.AliasTargetTypeId > 0) and
                  (Meta.AliasTargetTypeId <> TypeId) then
                  TypeId := Meta.AliasTargetTypeId
                else if FModel.TypeAt(TypeId - 1).ParentTypeId > 0 then
                  TypeId := FModel.TypeAt(TypeId - 1).ParentTypeId
                else
                  Break;
                Inc(Parsed);
              end;
              { Hardcoded ordinal extremes for well-known names if facts lost. }
              if SameText(ArgNode.Text, 'Integer') or
                SameText(ArgNode.Text, 'LongInt') then
              begin
                if SameText(IntrinsicName, 'Low') then
                  AValue := -2147483648
                else
                  AValue := 2147483647;
                Exit(True);
              end;
              if SameText(ArgNode.Text, 'PtrUInt') or
                SameText(ArgNode.Text, 'SizeUInt') or
                SameText(ArgNode.Text, 'NativeUInt') or
                SameText(ArgNode.Text, 'QWord') or
                SameText(ArgNode.Text, 'UInt64') then
              begin
                if SameText(IntrinsicName, 'Low') then
                  AValue := 0
                else
                  AValue := Int64(-1);
                Exit(True);
              end;
            end;
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


