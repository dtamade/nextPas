procedure TSemanticAnalyzer.CheckDuplicateDeclarations;
var
  I, J: LongInt;
  SymI, SymJ: TSemanticSymbol;
  RootUnitId: string;
begin
  RootUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);
  for I := 0 to FModel.SymbolCount - 2 do
  begin
    SymI := FModel.SymbolAt(I);
    if SymI.Kind = 'unit' then
      Continue;
    if not SameText(SymI.OwnerUnitId, RootUnitId) then
      Continue;
    for J := I + 1 to FModel.SymbolCount - 1 do
    begin
      SymJ := FModel.SymbolAt(J);
      if SymJ.Kind = 'unit' then
        Continue;
      if not SameText(SymJ.OwnerUnitId, RootUnitId) then
        Continue;
      if (SymI.ScopeId = SymJ.ScopeId) and SameText(SymI.Name, SymJ.Name) and
        (SymI.Kind <> 'parameter') and (SymJ.Kind <> 'parameter') and
        (SymI.Kind <> 'enum-value') and (SymJ.Kind <> 'enum-value') and
        (SymI.Kind <> 'method') and (SymJ.Kind <> 'method') and
        (SymI.Kind <> 'field') and (SymJ.Kind <> 'field') and
        (SymI.Kind <> 'function') and (SymJ.Kind <> 'function') and
        (SymI.Kind <> 'procedure') and (SymJ.Kind <> 'procedure') and
        { 函数类型参数在 var/const 节中被注册为 constant/variable }
        (SymI.Kind <> 'constant') and (SymJ.Kind <> 'constant') and
        (SymI.Kind <> 'variable') and (SymJ.Kind <> 'variable') and
        { 允许 type 的前向声明后重新声明 (如 TConfig = class; → TConfig = class ... end) }
        not (SameText(SymI.Kind, 'type') and SameText(SymJ.Kind, 'type')) then
      begin
        EmitSemaError(
          'sema.duplicate-declaration',
          'duplicate identifier "' + SymJ.Name + '"',
          SymJ.ByteOffset
        );
        Exit;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.CheckIdentifiersInNode(const ANode: TGreenNode);
var
  I: LongInt;
  Child: TGreenNode;
  SymId: LongInt;
  Name: string;
  CandidateNames: specialize TVec<string>;
  CandidateArr: array of string;
  Sym: TSemanticSymbol;
  Suggestion: string;
begin
  if ANode = nil then
    Exit;
  case ANode.NodeKind of
    gnkAssignmentStatement:
      begin
        Name := ANode.Text;
        if (Name <> '') and (Name <> 'Result') then
        begin
          SymId := FModel.LookupSymbol(Name, FCurrentScopeId);
          if (SymId = 0) and (FModel.FindTypeByName(Name) = 0) and
            not IsBuiltinProcedure(Name) and
            not IsRuntimeVar(Name) then
          begin
            { Build candidate list for "Did you mean?" suggestion }
            if FAllocator <> nil then
              CandidateNames := specialize TVec<string>.Create(0, FAllocator)
            else
              CandidateNames := specialize TVec<string>.Create;
            try
              for I := 0 to FModel.SymbolCount - 1 do
              begin
                Sym := FModel.SymbolAt(I);
                if (Sym.ScopeId = FCurrentScopeId) and (Sym.Name <> '') then
                  CandidateNames.Push(Sym.Name);
              end;
              SetLength(CandidateArr, LongInt(CandidateNames.Count));
              for I := 0 to LongInt(CandidateNames.Count) - 1 do
                CandidateArr[I] := CandidateNames[I];
              Suggestion := SuggestDidYouMean(Name, CandidateArr, 3);
            finally
              CandidateNames.Free;
            end;
            if Suggestion <> '' then
              EmitSemaError(
                'sema.undeclared-identifier',
                'identifier not found "' + Name + '". ' + Suggestion,
                ANode.ByteOffset
              )
            else
              EmitSemaError(
                'sema.undeclared-identifier',
                'identifier not found "' + Name + '"',
                ANode.ByteOffset
              );
          end;
        end;
      end;
    gnkStatementList, gnkBeginBlock, gnkIfStatement,
    gnkWhileStatement, gnkForStatement, gnkForInStatement,
    gnkRepeatStatement, gnkCaseStatement, gnkCaseSelector,
    gnkTryExceptStatement, gnkTryFinallyStatement:
      begin
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if Child <> nil then
            CheckIdentifiersInNode(Child);
        end;
      end;
  end;
end;

procedure TSemanticAnalyzer.CheckUndeclaredIdentifiers;
var
  RootNode: TGreenNode;
  I: LongInt;
  Child: TGreenNode;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  for I := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkBeginBlock) then
      CheckIdentifiersInNode(Child);
  end;
end;

procedure TSemanticAnalyzer.CheckTypeMismatchesInNode(const ANode: TGreenNode);
var
  I: LongInt;
  Child, LhsChild, RhsChild: TGreenNode;
  LhsName: string;
  LhsSymId: LongInt;
  LhsSym: TSemanticSymbol;
  LhsTypeId, RhsTypeId: LongInt;
  LhsTypeName, RhsTypeName: string;
begin
  if ANode = nil then
    Exit;

  case ANode.NodeKind of
    gnkAssignmentStatement:
      begin
        LhsName := ANode.Text;
        if LhsName = '' then
          Exit;
        LhsTypeId := 0;
        LhsChild := nil;
        if ANode.ChildCount > 0 then
          LhsChild := ANode.ChildAt(0);
        if (LhsChild <> nil) and (LhsChild.NodeKind = gnkIdentifier) then
        begin
          LhsSymId := FModel.LookupSymbol(LhsName, FCurrentScopeId);
          if LhsSymId = 0 then
            Exit;
          LhsSym := FModel.SymbolAt(LhsSymId - 1);
          LhsTypeId := LhsSym.TypeId;
        end
        else if LhsChild <> nil then
          LhsTypeId := InferExpressionType(LhsChild);
        if LhsTypeId = 0 then
          Exit;
        RhsChild := nil;
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if (Child <> nil) and (Child.NodeKind <> gnkDotAccess) and
            (Child.NodeKind <> gnkArrayAccess) and
            (Child.NodeKind <> gnkIdentifier) then
          begin
            RhsChild := Child;
            Break;
          end;
        end;
        if RhsChild = nil then
          Exit;
        RhsTypeId := InferExpressionType(RhsChild);
        if RhsTypeId = 0 then
          Exit;
        if AreTypesCompatible(LhsTypeId, RhsTypeId) then
          Exit;
        { Include type names in error message }
        LhsTypeName := '';
        RhsTypeName := '';
        if (LhsTypeId > 0) and (LhsTypeId <= FModel.TypeCount) then
          LhsTypeName := FModel.TypeAt(LhsTypeId - 1).Name;
        if (RhsTypeId > 0) and (RhsTypeId <= FModel.TypeCount) then
          RhsTypeName := FModel.TypeAt(RhsTypeId - 1).Name;
        if (LhsTypeName <> '') and (RhsTypeName <> '') then
          EmitSemaError(
            'sema.type-mismatch',
            'incompatible types: cannot assign ' + RhsTypeName +
              ' to ' + LhsTypeName + ' variable "' + LhsName + '"',
            ANode.ByteOffset
          )
        else
          EmitSemaError(
            'sema.type-mismatch',
            'incompatible types: cannot assign to "' + LhsName + '"',
            ANode.ByteOffset
          );
      end;
    gnkProcedureCallStatement:
      begin
        LhsName := ANode.Text;
        if LhsName <> '' then
        begin
          LhsSymId := FModel.LookupSymbol(LhsName, FCurrentScopeId);
          if LhsSymId > 0 then
          begin
            LhsSym := FModel.SymbolAt(LhsSymId - 1);
            if (LhsSym.ParamCount >= 0) and
              (not HasOverload(LhsName)) and
              (not IsBuiltinProcedure(LhsName)) and
              ((LhsSym.Kind = 'procedure') or (LhsSym.Kind = 'function')) then
            begin
              RhsChild := ANode.ChildAt(0);
              if (RhsChild <> nil) and (RhsChild.NodeKind = gnkFunctionCall) then
                LhsTypeId := RhsChild.ChildCount - 1
              else
                LhsTypeId := ANode.ChildCount;
              if LhsTypeId > LhsSym.ParamCount then
                EmitSemaError(
                  'sema.wrong-argument-count',
                  'too many arguments for "' + LhsName + '" (expected ' +
                    IntToStr(LhsSym.ParamCount) + ', got ' +
                    IntToStr(LhsTypeId) + ')',
                  ANode.ByteOffset
                );
            end;
          end;
        end;
      end;
    gnkStatementList, gnkBeginBlock, gnkIfStatement,
    gnkWhileStatement, gnkForStatement, gnkForInStatement,
    gnkRepeatStatement, gnkCaseStatement, gnkCaseSelector,
    gnkTryExceptStatement, gnkTryFinallyStatement:
      begin
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if Child <> nil then
            CheckTypeMismatchesInNode(Child);
        end;
      end;
  end;
end;

procedure TSemanticAnalyzer.CheckTypeMismatches;
var
  RootNode: TGreenNode;
  I: LongInt;
  Child: TGreenNode;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  for I := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkBeginBlock) then
      CheckTypeMismatchesInNode(Child);
  end;
end;

procedure TSemanticAnalyzer.CheckUnusedSymbols;

  function IsNameUsedInNode(const ANode: TGreenNode; const AName: string): Boolean;
  var
    I: LongInt;
    Child: TGreenNode;
  begin
    if ANode = nil then
      Exit(False);
    if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, AName) then
      Exit(True);
    if (ANode.NodeKind = gnkAssignmentStatement) and SameText(ANode.Text, AName) then
      Exit(True);
    if (ANode.NodeKind = gnkProcedureCallStatement) and SameText(ANode.Text, AName) then
      Exit(True);
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if IsNameUsedInNode(Child, AName) then
        Exit(True);
    end;
    Result := False;
  end;

var
  I: LongInt;
  Sym: TSemanticSymbol;
  RootNode, Child: TGreenNode;
  BeginBlock: TGreenNode;
  J: LongInt;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;

  BeginBlock := nil;
  for J := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkBeginBlock) then
    begin
      BeginBlock := Child;
      Break;
    end;
  end;
  if BeginBlock = nil then
    Exit;

  for I := 0 to FModel.SymbolCount - 1 do
  begin
    Sym := FModel.SymbolAt(I);
    if Sym.Kind <> 'variable' then
      Continue;
    if Sym.ScopeId <> FCurrentScopeId then
      Continue;
    if not IsNameUsedInNode(BeginBlock, Sym.Name) then
      FDiagnostics.EmitWarning(
        'sema.unused-variable',
        'sema',
        FRootFileId,
        Sym.ByteOffset,
        'variable "' + Sym.Name + '" is declared but never used'
      );
  end;
end;

procedure TSemanticAnalyzer.CheckUnreachableInNode(const ANode: TGreenNode;
  var ATerminated: Boolean);
var
  I: LongInt;
  Child: TGreenNode;
  ChildTerminated: Boolean;
begin
  if ANode = nil then
    Exit;
  ATerminated := False;

  if ANode.NodeKind = gnkStatementList then
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then
        Continue;
      if ATerminated then
      begin
        if (Child.NodeKind <> gnkError) then
          FDiagnostics.EmitWarning(
            'sema.unreachable-code',
            'sema',
            FRootFileId,
            Child.ByteOffset,
            'unreachable code after unconditional exit'
          );
        Exit;
      end;
      ChildTerminated := False;
      CheckUnreachableInNode(Child, ChildTerminated);
      if ChildTerminated then
        ATerminated := True;
    end;
  end
  else
  begin
    case ANode.NodeKind of
      gnkExitStatement:
        ATerminated := True;
      gnkBreakStatement:
        ATerminated := True;
      gnkContinueStatement:
        ATerminated := True;
      gnkProcedureCallStatement:
        if SameText(ANode.Text, 'Halt') then
          ATerminated := True;
      gnkBeginBlock, gnkIfStatement, gnkWhileStatement,
      gnkForStatement, gnkRepeatStatement, gnkCaseStatement,
      gnkTryExceptStatement, gnkTryFinallyStatement:
        begin
          for I := 0 to ANode.ChildCount - 1 do
          begin
            Child := ANode.ChildAt(I);
            if Child <> nil then
              CheckUnreachableInNode(Child, ChildTerminated);
          end;
        end;
    end;
  end;
end;

procedure TSemanticAnalyzer.CheckUnreachableCode;
var
  RootNode, Child: TGreenNode;
  I: LongInt;
  Terminated: Boolean;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  for I := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkBeginBlock) then
    begin
      Terminated := False;
      CheckUnreachableInNode(Child, Terminated);
    end;
  end;
end;

procedure TSemanticAnalyzer.CheckCaseLabelsInNode(const ANode: TGreenNode);
var
  I, J, K: LongInt;
  Child, Selector, Label1, Label2: TGreenNode;
  Val1, Val2: Int64;
  SeenValues: specialize TVec<Int64>;
begin
  if ANode = nil then
    Exit;
  if ANode.NodeKind = gnkCaseStatement then
  begin
    if FAllocator <> nil then
      SeenValues := specialize TVec<Int64>.Create(0, FAllocator)
    else
      SeenValues := specialize TVec<Int64>.Create;
    try
      for I := 0 to ANode.ChildCount - 1 do
      begin
        Selector := ANode.ChildAt(I);
        if (Selector = nil) or (Selector.NodeKind <> gnkCaseSelector) then
          Continue;
        for J := 0 to Selector.ChildCount - 1 do
        begin
          Label1 := Selector.ChildAt(J);
          if (Label1 = nil) or (Label1.NodeKind <> gnkCaseLabel) then
            Continue;
          if (Label1.ChildCount > 0) and
            EvaluateIntegerConstant(Label1.ChildAt(0), Val1) then
          begin
            for K := 0 to LongInt(SeenValues.Count) - 1 do
            begin
              if SeenValues[K] = Val1 then
              begin
                FDiagnostics.EmitWarning(
                  'sema.duplicate-case-label',
                  'sema',
                  FRootFileId,
                  Label1.ByteOffset,
                  'duplicate case label value ' + IntToStr(Val1)
                );
                Break;
              end;
            end;
            SeenValues.Push(Val1);
          end;
        end;
      end;
    finally
      SeenValues.Free;
    end;
  end
  else
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child <> nil then
        CheckCaseLabelsInNode(Child);
    end;
  end;
end;

procedure TSemanticAnalyzer.CheckDuplicateCaseLabels;
var
  RootNode, Child: TGreenNode;
  I: LongInt;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  for I := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(I);
    if Child <> nil then
      CheckCaseLabelsInNode(Child);
  end;
end;
