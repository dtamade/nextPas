procedure TSemanticAnalyzer.SeedCallBindingsInNode(
  const ANode: TGreenNode;
  const ACurrentMethodClass: string;
  const ACurrentOwnerUnitId: string
);
var
  ArgIndex: LongInt;
  ArgTypeIds: TTypeIdArray;
  ArgSignature: string;
  BodyNode: TGreenNode;
  CallableScopeId: LongInt;
  Child: TGreenNode;
  DeclNode: TGreenNode;
  HasArgSignature: Boolean;
  HasTypeMismatchEvidence: Boolean;
  ImplicitSelfBound: Boolean;
  Index: LongInt;
  MemberFailureName: string;
  MemberFailureOffset: LongInt;
  MemberActualArgCount: LongInt;
  MemberCandidates: TOverloadCandidateArray;
  Payload: TDiagnosticPayload;
  MethodClass: string;
  CallableOwnerUnitId: string;
  QualifiedPos: LongInt;
  ResolutionFailureKind: string;
  SavedResKind: string;
  SavedScopeId: LongInt;
  TypeCastTargetTypeId: LongInt;
begin
  if ANode = nil then
    Exit;

  MethodClass := ACurrentMethodClass;
  SavedScopeId := FCurrentScopeId;
  if ANode.NodeKind in [gnkProcedureDecl, gnkFunctionDecl] then
  begin
    QualifiedPos := Pos('.', ANode.Text);
    if QualifiedPos > 1 then
      MethodClass := Copy(ANode.Text, 1, QualifiedPos - 1);
    CallableScopeId := ProcedureBodyScopeIdForDecl(ANode);
    if CallableScopeId > 0 then
      FCurrentScopeId := CallableScopeId;
  end;

  if ANode.NodeKind in [gnkProcedureCallStatement, gnkFunctionCall] then
  begin
    if IsQualifiedCallNode(ANode) then
    begin
      if (not TryRegisterMemberCallBinding(
        ANode,
        MethodClass,
        ACurrentOwnerUnitId,
        ResolutionFailureKind,
        MemberFailureName,
        MemberFailureOffset,
        MemberActualArgCount,
        MemberCandidates
      )) and SameText(ResolutionFailureKind, 'ambiguous-overload') then
      begin
        EmitSemaError(
          'sema.ambiguous-overload',
          'ambiguous call to overloaded function "' + MemberFailureName + '"',
          MemberFailureOffset
        );
      end
      else if SameText(ResolutionFailureKind, 'wrong-argument-count') then
      begin
        Payload.Kind := dpkWrongArgumentCount;
        Payload.ActualCount := MemberActualArgCount;
        Payload.ExpectedCount := 0;
        if Length(MemberCandidates) > 0 then
          Payload.ExpectedCount := MemberCandidates[0].ParamCount;
        Payload.Candidates := MemberCandidates;
        FDiagnostics.EmitErrorWithPayload(
          'sema.wrong-argument-count', 'sema',
          BuildCoreSourceSpan(FRootFileId, MemberFailureOffset, 0),
          'wrong number of arguments for "' + MemberFailureName + '"',
          Payload);
        FModel.MarkFailure;
      end
      else if SameText(ResolutionFailureKind, 'type-mismatch') then
        EmitSemaError(
          'sema.type-mismatch',
          'argument type mismatch for "' + MemberFailureName + '"',
          MemberFailureOffset
        )
      else if SameText(ResolutionFailureKind, 'no-matching-overload') then
      begin
        Payload.Kind := dpkOverloadCandidates;
        Payload.Candidates := MemberCandidates;
        FDiagnostics.EmitErrorWithPayload(
          'sema.no-matching-overload', 'sema',
          BuildCoreSourceSpan(FRootFileId, MemberFailureOffset, 0),
          'no matching overload for "' + MemberFailureName + '"',
          Payload);
        FModel.MarkFailure;
      end
      else if SameText(ResolutionFailureKind, 'unknown-member') then
        EmitSemaError(
          'sema.unknown-member',
          'unknown member "' + MemberFailureName + '"',
          MemberFailureOffset
        )
      else if SameText(ResolutionFailureKind, 'invalid-call-shape') then
        EmitSemaError(
          'sema.invalid-call-shape',
          'member "' + MemberFailureName + '" is not callable',
          MemberFailureOffset
        )
      else if SameText(ResolutionFailureKind, 'inaccessible-member') then
        EmitSemaError(
          'sema.inaccessible-member',
          'cannot access private member "' + MemberFailureName + '"',
          MemberFailureOffset
        );
    end
    else if Pos('.', ANode.Text) = 0 then
    begin
      { Type cast: TypeId(Arg) — skip call binding for type casts }
      if TryGetTypeCastTargetTypeId(ANode, TypeCastTargetTypeId) then
      begin
        { Type cast detected; no call binding needed }
      end
      else
      begin
      MemberFailureName := ANode.Text;
      MemberFailureOffset := ANode.ByteOffset;
      if not CallArgumentTypeIds(ANode, ArgTypeIds) then
        SetLength(ArgTypeIds, 0);
      HasArgSignature := CallArgumentSignature(ANode, ArgSignature);
      HasTypeMismatchEvidence := HasArgSignature and
        CallArgumentSignatureIsStable(ANode, ACurrentOwnerUnitId);
      ImplicitSelfBound := False;
      if SameText(ANode.Text, 'ACallback') then
      if LookupCallBindingDeclaration(
        ANode.Text,
        CallArgumentCount(ANode),
        ArgTypeIds,
        ArgSignature,
        HasArgSignature,
        HasTypeMismatchEvidence,
        ResolutionFailureKind,
        BodyNode,
        DeclNode,
        CallableOwnerUnitId
      ) then
        RegisterCallBinding(ANode, DeclNode, CallableOwnerUnitId)
      else
      begin
        if (MethodClass <> '') and
          (SameText(ResolutionFailureKind, 'unknown-callable') or
           SameText(ResolutionFailureKind, 'wrong-argument-count') or
           SameText(ResolutionFailureKind, 'type-mismatch') or
           SameText(ResolutionFailureKind, 'no-matching-overload')) then
        begin
          SavedResKind := ResolutionFailureKind;
          ImplicitSelfBound := TryRegisterImplicitSelfBareMethodCallBinding(
            ANode,
            MethodClass,
            ACurrentOwnerUnitId,
            ResolutionFailureKind,
            MemberFailureName,
            MemberFailureOffset
          );
          if not ImplicitSelfBound then
            ResolutionFailureKind := SavedResKind;
        end;
        if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'ambiguous-overload') then
        begin
          EmitSemaError(
            'sema.ambiguous-overload',
            'ambiguous call to overloaded function "' + MemberFailureName + '"',
            MemberFailureOffset
          );
        end
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'wrong-argument-count') then
          EmitSemaError(
            'sema.wrong-argument-count',
            'wrong number of arguments for "' + MemberFailureName + '"',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'type-mismatch') then
          EmitSemaError(
            'sema.type-mismatch',
            'argument type mismatch for "' + MemberFailureName + '"',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'no-matching-overload') then
          EmitSemaError(
            'sema.no-matching-overload',
            'no matching overload for "' + MemberFailureName + '"',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'unknown-member') then
          EmitSemaError(
            'sema.unknown-member',
            'unknown member "' + MemberFailureName + '"',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'invalid-call-shape') then
          EmitSemaError(
            'sema.invalid-call-shape',
            'member "' + MemberFailureName + '" is not callable',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'unknown-callable') and
          (MethodClass = '') then
          EmitSemaError(
            'sema.unknown-callable',
            'unknown callable "' + ANode.Text + '"',
            ANode.ByteOffset
          );
      end;
      end; { not a type cast }
    end;
  end;

  for Index := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(Index);
    if Child = nil then
      Continue;
    if IsWrappedCallChild(ANode, Child) then
    begin
      for ArgIndex := 1 to Child.ChildCount - 1 do
        SeedCallBindingsInNode(
          Child.ChildAt(ArgIndex),
          MethodClass,
          ACurrentOwnerUnitId
        );
      Continue;
    end;
    if Child <> nil then
      SeedCallBindingsInNode(Child, MethodClass, ACurrentOwnerUnitId);
  end;
  FCurrentScopeId := SavedScopeId;
end;

procedure TSemanticAnalyzer.SeedCallBindings;
var
  Index: LongInt;
  RootOwnerUnitId: string;
begin
  if (FRootAst = nil) or (FRootAst.RootNode = nil) then
    Exit;

  RootOwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);
  FCurrentProcessingUnitId := RootOwnerUnitId;
  SeedCallBindingsInNode(FRootAst.RootNode, '', RootOwnerUnitId);
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if (Pos('.', FProcedureBodies[Index].Name) > 0) and
      OwnerUnitAllowsProjectSourceDiagnostic(
        FProcedureBodies[Index].OwnerUnitId
      ) then
    begin
      FCurrentProcessingUnitId :=
        NormalizeUnitIdentity(FProcedureBodies[Index].OwnerUnitId);
      SeedCallBindingsInNode(
        FProcedureBodies[Index].Decl,
        '',
        FProcedureBodies[Index].OwnerUnitId
      );
    end;
end;

function TSemanticAnalyzer.IsCurrentlyInlining(const AName: string): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to FInliningStack.Count - 1 do
    if SameText(FInliningStack[Index], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemanticAnalyzer.PushInlining(const AName: string);
begin
  FInliningStack.Push(AName);
end;

procedure TSemanticAnalyzer.PopInlining;
begin
  if FInliningStack.Count > 0 then
    FInliningStack.Pop;
end;

function EncodeRuntimeIntExpr(const ANode: TGreenNode;
  out ABlob: string): Boolean; forward;

function EncodeRuntimeBoolExpr(const ANode: TGreenNode;
  out ABlob: string): Boolean;
var
  LeftBlob, RightBlob, Op, Pred: string;
begin
  ABlob := '';
  if ANode = nil then
    Exit(False);
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
  else
    Exit(False);
  if not EncodeRuntimeIntExpr(ANode.ChildAt(0), LeftBlob) then
    Exit(False);
  if not EncodeRuntimeIntExpr(ANode.ChildAt(1), RightBlob) then
    Exit(False);
  ABlob := LeftBlob + RightBlob + 'cmp ' + Pred + #10;
  Result := True;
end;

function EncodeRuntimeIntExpr(const ANode: TGreenNode;
  out ABlob: string): Boolean;
var
  LeftBlob, RightBlob, Op: string;
  Parsed: Int64;
  ParseCode: Word;
begin
  ABlob := '';
  if ANode = nil then
    Exit(False);
  case ANode.NodeKind of
    gnkIntegerLiteral:
      begin
        Val(ANode.Text, Parsed, ParseCode);
        if ParseCode <> 0 then
          Exit(False);
        ABlob := 'int ' + IntToStr(Parsed) + #10;
        Exit(True);
      end;
    gnkIdentifier:
      begin
        if ANode.Text = '' then
          Exit(False);
        ABlob := 'var ' + ANode.Text + #10;
        Exit(True);
      end;
    gnkUnaryExpression:
      begin
        if ANode.ChildCount < 1 then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(0), LeftBlob) then
          Exit(False);
        Op := ANode.Text;
        if Op = '-' then
        begin
          ABlob := LeftBlob + 'neg' + #10;
          Exit(True);
        end
        else if Op = '+' then
        begin
          ABlob := LeftBlob;
          Exit(True);
        end
        else
          Exit(False);
      end;
    gnkBinaryExpression:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(0), LeftBlob) then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(1), RightBlob) then
          Exit(False);
        Op := ANode.Text;
        if Op = '+' then
          ABlob := LeftBlob + RightBlob + 'add' + #10
        else if Op = '-' then
          ABlob := LeftBlob + RightBlob + 'sub' + #10
        else if Op = '*' then
          ABlob := LeftBlob + RightBlob + 'mul' + #10
        else if SameText(Op, 'div') then
          ABlob := LeftBlob + RightBlob + 'div' + #10
        else if SameText(Op, 'mod') then
          ABlob := LeftBlob + RightBlob + 'mod' + #10
        else
          Exit(False);
        Exit(True);
      end;
    gnkFunctionCall:
      begin
        if ANode.ChildCount < 1 then
          Exit(False);
        if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
          Exit(False);
        if SameText(ANode.ChildAt(0).Text, 'Length') and
          (ANode.ChildCount = 2) and
          (ANode.ChildAt(1) <> nil) and
          (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
        begin
          ABlob := 'var ' + ANode.ChildAt(1).Text + '$len' + #10;
          Exit(True);
        end;
        ABlob := '';
        for Parsed := 1 to ANode.ChildCount - 1 do
        begin
          if not EncodeRuntimeIntExpr(ANode.ChildAt(Parsed), RightBlob) then
            Exit(False);
          ABlob := ABlob + RightBlob;
        end;
        ABlob := ABlob + 'call ' + ANode.ChildAt(0).Text + ' ' +
          IntToStr(ANode.ChildCount - 1) + #10;
        Exit(True);
      end;
    gnkDotAccess:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
          Exit(False);
        if ANode.ChildAt(1).NodeKind <> gnkIdentifier then
          Exit(False);
        ABlob := 'var ' + ANode.ChildAt(0).Text + '.' +
          ANode.ChildAt(1).Text + #10;
        Exit(True);
      end;
    gnkArrayAccess:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(1), LeftBlob) then
          Exit(False);
        ABlob := LeftBlob + 'arrload ' + ANode.ChildAt(0).Text + #10;
        Exit(True);
      end;
  end;
  Result := False;
end;

procedure TSemanticAnalyzer.EmitSemaError(
  const ACode: string;
  const AMessage: string;
  const AByteOffset: LongInt
);
var
  EmptyPayload: TDiagnosticPayload;
begin
  EmptyPayload.Kind := dpkNone;
  FDiagnostics.EmitErrorWithPayload(
    ACode, 'sema',
    BuildCoreSourceSpan(FRootFileId, AByteOffset, 0),
    AMessage, EmptyPayload);
  FModel.MarkFailure;
end;

function TSemanticAnalyzer.IsSimpleIdentifierName(const AName: string): Boolean;
begin
  Result := np_sema_type_check.IsSimpleIdentifierName(AName);
end;

function TSemanticAnalyzer.RegisterSymbol(
  const AName: string;
  const AKind: string;
  const AOwnerUnitId: string;
  const ATypeId: LongInt;
  const AByteOffset: LongInt
): LongInt;
var
  Existing: LongInt;
begin
  if (FCurrentScopeId > 0) and (AName <> '') then
  begin
    Existing := FModel.FindSymbolInScope(AName, FCurrentScopeId);
    if (Existing > 0) and
      not SameText(AKind, 'parameter') and
      not SameText(FModel.SymbolAt(Existing - 1).Kind, 'parameter') and
      not SameText(AKind, 'constant') and
      not SameText(FModel.SymbolAt(Existing - 1).Kind, 'constant') and
      not (SameText(AKind, 'type') and
           SameText(FModel.SymbolAt(Existing - 1).Kind, 'type')) then
    begin
      EmitSemaError(
        'sema.duplicate-declaration',
        'duplicate identifier "' + AName + '"',
        AByteOffset
      );
    end;
  end;
  Result := FModel.AddSymbol(AName, AKind, AOwnerUnitId, ATypeId, AByteOffset);
  if FCurrentScopeId > 0 then
    FModel.SetSymbolScope(Result, FCurrentScopeId);
end;

function TSemanticAnalyzer.IsBuiltinProcedure(const AName: string): Boolean;
begin
  Result := FBuiltinRegistry.IsBuiltinProcedure(AName);
end;

function TSemanticAnalyzer.InferExpressionType(const ANode: TGreenNode): LongInt;
var
  ArgNode: TGreenNode;
  BaseTypeId: LongInt;
  CallName: string;
  FieldMeta: TFieldMeta;
  LStrTypeId: LongInt;
  RType: LongInt;
  SymId: LongInt;
  TargetTypeId: LongInt;
  Sym: TSemanticSymbol;
  LReceiverTypeId: LongInt;
  LFieldMeta: TFieldMeta;
  LTypeName: string;
  LDotPos: LongInt;
  LReceiverName: string;
  LMemberName: string;
  LQualifiedName: string;
  LBodyIdx: LongInt;
begin
  Result := 0;
  if ANode = nil then
    Exit;
  case ANode.NodeKind of
    gnkIntegerLiteral:
      Result := FModel.FindTypeByName('Integer');
    gnkRealLiteral:
      Result := FModel.FindTypeByName('Double');
    gnkStringLiteral:
      Result := FModel.FindTypeByName('AnsiString');
    gnkCharLiteral:
      Result := FModel.FindTypeByName('Char');
    gnkIdentifier:
      begin
        if SameText(ANode.Text, 'True') or SameText(ANode.Text, 'False') then
          Exit(FModel.FindTypeByName('Boolean'));
        SymId := FModel.LookupSymbol(ANode.Text, FCurrentScopeId);
        if SymId <= 0 then
          SymId := FModel.FindSymbolByName(ANode.Text);
        if SymId > 0 then
        begin
          Sym := FModel.SymbolAt(SymId - 1);
          Result := Sym.TypeId;
        end
        else
          Result := FModel.FindTypeByName(ANode.Text);
      end;
    gnkBinaryExpression:
      begin
        if ANode.Text = '+' then
        begin
          LStrTypeId := FModel.FindTypeByName('AnsiString');
          Result := InferExpressionType(ANode.ChildAt(0));
          if Result = LStrTypeId then
            Exit;
          RType := InferExpressionType(ANode.ChildAt(1));
          if RType = LStrTypeId then
          begin
            Result := LStrTypeId;
            Exit;
          end;
          if Result = 0 then
            Result := RType;
          if Result = 0 then
            Result := FModel.FindTypeByName('Integer');
        end
        else if (ANode.Text = '=') or (ANode.Text = '<>') or
          (ANode.Text = '<') or (ANode.Text = '>') or
          (ANode.Text = '<=') or (ANode.Text = '>=') or
          (ANode.Text = 'in') or (ANode.Text = 'is') then
          Result := FModel.FindTypeByName('Boolean')
        else if (ANode.Text = 'and') or (ANode.Text = 'or') or
          (ANode.Text = 'xor') then
        begin
          Result := InferExpressionType(ANode.ChildAt(0));
          if Result = FModel.FindTypeByName('Boolean') then
            Exit;
          Result := FModel.FindTypeByName('Integer');
        end
        else if ANode.Text = '/' then
          Result := FModel.FindTypeByName('Double')
        else
        begin
          Result := InferExpressionType(ANode.ChildAt(0));
          if Result = 0 then
            Result := FModel.FindTypeByName('Integer');
        end;
      end;
    gnkUnaryExpression:
      begin
        if ANode.Text = '@' then
          Exit(FModel.FindTypeByName('Pointer'));
        if ANode.Text = 'not' then
          Result := InferExpressionType(ANode.ChildAt(0))
        else
          Result := InferExpressionType(ANode.ChildAt(0));
        if Result = 0 then
          Result := FModel.FindTypeByName('Integer');
      end;
    gnkFunctionCall:
      begin
        if TryGetTypeCastTargetTypeId(ANode, TargetTypeId) then
          Exit(TargetTypeId);
        if TryGetIntrinsicExprName(ANode, CallName) then
        begin
          if SameText(CallName, 'Default') and (ANode.ChildCount >= 2) then
          begin
            ArgNode := ANode.ChildAt(1);
            if (ArgNode <> nil) and (ArgNode.NodeKind = gnkIdentifier) then
            begin
              Result := ResolveTypeIdForOwner(
                ArgNode.Text,
                NormalizeUnitIdentity(FCurrentProcessingUnitId)
              );
              if Result <= 0 then
                Result := ResolveTypeIdForOwner(
                  ArgNode.Text,
                  NormalizeUnitIdentity(FUnitGraph.RootName)
                );
            end;
            if Result <= 0 then
              Result := InferExpressionType(ArgNode);
            Exit;
          end;
          if SameText(CallName, 'SizeOf') or SameText(CallName, 'High') or
            SameText(CallName, 'Low') or SameText(CallName, 'Length') or
            SameText(CallName, 'Ord') or SameText(CallName, 'Round') or
            SameText(CallName, 'Trunc') or SameText(CallName, 'Floor') or
            SameText(CallName, 'Ceil') then
            Exit(FModel.FindTypeByName('Integer'));
          if SameText(CallName, 'Chr') then
            Exit(FModel.FindTypeByName('Char'));
          if SameText(CallName, 'Assigned') then
            Exit(FModel.FindTypeByName('Boolean'));
          if SameText(CallName, 'Supports') or SameText(CallName, 'IsFinite') then
            Exit(FModel.FindTypeByName('Boolean'));
          if SameText(CallName, 'Min') or SameText(CallName, 'Max') then
          begin
            if ANode.ChildCount >= 2 then
              Result := InferExpressionType(ANode.ChildAt(1));
            if Result = 0 then
              Result := FModel.FindTypeByName('Integer');
            Exit;
          end;
          if SameText(CallName, 'Sqrt') then
            Exit(FModel.FindTypeByName('Double'));
          if SameText(CallName, 'Pred') or SameText(CallName, 'Succ') or
            SameText(CallName, 'Abs') or SameText(CallName, 'Sqr') then
          begin
            if ANode.ChildCount >= 2 then
              Result := InferExpressionType(ANode.ChildAt(1));
            if Result = 0 then
              Result := FModel.FindTypeByName('Integer');
            Exit;
          end;
        end;
        SymId := FModel.LookupSymbol(BareCallCalleeName(ANode), FCurrentScopeId);
        if SymId > 0 then
        begin
          Sym := FModel.SymbolAt(SymId - 1);
          Result := Sym.TypeId;
        end
        else if Pos('.', ANode.Text) > 1 then
        begin
          LDotPos := Pos('.', ANode.Text);
          LReceiverName := Copy(ANode.Text, 1, LDotPos - 1);
          LMemberName := Copy(ANode.Text, LDotPos + 1, Length(ANode.Text));
          LReceiverTypeId := 0;
          if SameText(LReceiverName, 'Self') and (FCurrentMethodClass <> '') then
            LReceiverTypeId := FModel.FindTypeByName(FCurrentMethodClass)
          else
          begin
            SymId := FModel.LookupSymbol(LReceiverName, FCurrentScopeId);
            if SymId > 0 then
            begin
              Sym := FModel.SymbolAt(SymId - 1);
              LReceiverTypeId := Sym.TypeId;
            end;
          end;
          if LReceiverTypeId > 0 then
          begin
            LTypeName := FModel.TypeAt(LReceiverTypeId - 1).Name;
            LQualifiedName := LTypeName + '.' + LMemberName;
            for LBodyIdx := 0 to Length(FProcedureBodies) - 1 do
              if SameText(FProcedureBodies[LBodyIdx].Name, LQualifiedName) then
              begin
                Result := DeclReturnTypeId(
                  FProcedureBodies[LBodyIdx].Decl,
                  FProcedureBodies[LBodyIdx].OwnerUnitId);
                if Result > 0 then
                  Break;
              end;
          end;
        end
        else if (ANode.ChildCount > 0) and (ANode.ChildAt(0) <> nil) and
          (ANode.ChildAt(0).NodeKind = gnkDotAccess) then
          Result := InferExpressionType(ANode.ChildAt(0));
      end;
    gnkDotAccess:
      begin
        if ANode.ChildCount < 2 then
          Exit;
        if (ANode.ChildAt(0) = nil) or (ANode.ChildAt(1) = nil) then
          Exit;
        LReceiverTypeId := 0;
        if SameText(ANode.ChildAt(0).Text, 'Self') and
          (FCurrentMethodClass <> '') then
        begin
          LReceiverTypeId := FModel.FindTypeByName(FCurrentMethodClass);
          if LReceiverTypeId <= 0 then
          begin
            SymId := FModel.LookupSymbol(FCurrentMethodClass, FCurrentScopeId);
            if SymId > 0 then
            begin
              Sym := FModel.SymbolAt(SymId - 1);
              if SameText(Sym.Kind, 'type') then
                LReceiverTypeId := Sym.TypeId;
            end;
          end;
        end
        else if ANode.ChildAt(0).NodeKind = gnkIdentifier then
        begin
          SymId := FModel.LookupSymbol(ANode.ChildAt(0).Text, FCurrentScopeId);
          if SymId > 0 then
          begin
            Sym := FModel.SymbolAt(SymId - 1);
            LReceiverTypeId := Sym.TypeId;
          end;
          { Fall back to FindTypeByName for type names used as
            class method receivers (e.g. TOffsetDateTime.Now) }
          if LReceiverTypeId <= 0 then
            LReceiverTypeId := FModel.FindTypeByName(
              ANode.ChildAt(0).Text);
        end
        else
          LReceiverTypeId := InferExpressionType(ANode.ChildAt(0));
        if LReceiverTypeId <= 0 then
          Exit;
        LTypeName := '';
        if LReceiverTypeId > 0 then
          LTypeName := FModel.TypeAt(LReceiverTypeId - 1).Name;
        if LTypeName <> '' then
        begin
          if FModel.GetFieldMetaByName(LReceiverTypeId, ANode.ChildAt(1).Text,
            LFieldMeta) then
            Result := LFieldMeta.TypeId
          else
          begin
            LQualifiedName := LTypeName + '.' + ANode.ChildAt(1).Text;
            for LBodyIdx := 0 to Length(FProcedureBodies) - 1 do
              if SameText(FProcedureBodies[LBodyIdx].Name, LQualifiedName) then
              begin
                Result := DeclReturnTypeId(
                  FProcedureBodies[LBodyIdx].Decl,
                  FProcedureBodies[LBodyIdx].OwnerUnitId);
                if Result > 0 then
                  Break;
              end;
            if Result <= 0 then
            begin
              if FModel.TypeAt(LReceiverTypeId - 1).InstantiatedFrom > 0 then
              begin
                LReceiverTypeId := FModel.TypeAt(LReceiverTypeId - 1).InstantiatedFrom;
                LTypeName := FModel.TypeAt(LReceiverTypeId - 1).Name;
                LQualifiedName := LTypeName + '.' + ANode.ChildAt(1).Text;
                for LBodyIdx := 0 to Length(FProcedureBodies) - 1 do
                  if SameText(FProcedureBodies[LBodyIdx].Name, LQualifiedName) then
                  begin
                    Result := DeclReturnTypeId(
                      FProcedureBodies[LBodyIdx].Decl,
                      FProcedureBodies[LBodyIdx].OwnerUnitId);
                    if Result > 0 then
                      Break;
                  end;
              end;
            end;
            if Result <= 0 then
            begin
              while FModel.TypeAt(LReceiverTypeId - 1).ParentTypeId > 0 do
              begin
                LReceiverTypeId := FModel.TypeAt(LReceiverTypeId - 1).ParentTypeId;
                if FModel.TypeAt(LReceiverTypeId - 1).InstantiatedFrom > 0 then
                  LReceiverTypeId := FModel.TypeAt(LReceiverTypeId - 1).InstantiatedFrom;
                LTypeName := FModel.TypeAt(LReceiverTypeId - 1).Name;
                LQualifiedName := LTypeName + '.' + ANode.ChildAt(1).Text;
                for LBodyIdx := 0 to Length(FProcedureBodies) - 1 do
                  if SameText(FProcedureBodies[LBodyIdx].Name, LQualifiedName) then
                  begin
                    Result := DeclReturnTypeId(
                      FProcedureBodies[LBodyIdx].Decl,
                      FProcedureBodies[LBodyIdx].OwnerUnitId);
                    if Result > 0 then
                      Break;
                  end;
                if Result > 0 then
                  Break;
              end;
            end;
            { Fall back to symbol table for class methods not in
              FProcedureBodies (e.g. TOffsetDateTime.Now) }
            if Result <= 0 then
            begin
              LQualifiedName := LTypeName + '.' + ANode.ChildAt(1).Text;
              for LBodyIdx := 0 to FModel.SymbolCount - 1 do
              begin
                Sym := FModel.SymbolAt(LBodyIdx);
                if SameText(Sym.Name, LQualifiedName) and
                  (SameText(Sym.Kind, 'method') or
                   SameText(Sym.Kind, 'function')) then
                begin
                  if Sym.ReturnTypeId > 0 then
                    Result := Sym.ReturnTypeId
                  else
                    Result := Sym.TypeId;
                  if Result > 0 then
                    Break;
                end;
              end;
            end;
          end;
        end;
      end;
    gnkDereference:
      begin
        if (ANode.ChildCount >= 1) and (ANode.ChildAt(0) <> nil) then
        begin
          BaseTypeId := InferExpressionType(ANode.ChildAt(0));
          if (BaseTypeId > 0) and (BaseTypeId <= FModel.TypeCount) then
          begin
            CallName := FModel.TypeAt(CanonicalTypeId(BaseTypeId) - 1).Name;
            if (Length(CallName) > 1) and (CallName[1] = 'P') then
            begin
              Result := FModel.FindTypeByName(Copy(CallName, 2, Length(CallName) - 1));
              if Result > 0 then
                Exit;
            end;
          end;
        end;
        Result := 0;
      end;
    gnkArrayAccess:
      Result := 0;
  end;
end;

function TSemanticAnalyzer.AreTypesCompatible(const ALhsTypeId, ARhsTypeId: LongInt): Boolean;
var Ctx: TSemaOverloadContext;
begin
  Ctx.Model := FModel;
  Ctx.UnitGraph := FUnitGraph;
  Ctx.RootAst := FRootAst;
  Ctx.CurrentProcessingUnitId := FCurrentProcessingUnitId;
  Ctx.CurrentScopeId := FCurrentScopeId;
  Ctx.ProcedureBodies := FProcedureBodies;
  Ctx.ImportedUnitOwners := FImportedUnitOwners;
  Ctx.ImportedUnitTrees := FImportedUnitTrees;
  Ctx.BuiltinRegistry := FBuiltinRegistry;
  Result := np_sema_overload.AreTypesCompatible(Ctx, ALhsTypeId, ARhsTypeId);
end;

