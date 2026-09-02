procedure TSemanticAnalyzer.CheckDuplicateDeclarations;
var
  Seen: specialize THashMap<string, LongInt>;
  I: LongInt;
  Sym: TSemanticSymbol;
  ExistingIdx: LongInt;
  ExistingSym: TSemanticSymbol;
  RootUnitId, Key: string;
  function IsExcludedKind(const AKind: string): Boolean; inline;
  begin
    Result :=
      SameText(AKind, 'parameter') or
      SameText(AKind, 'enum-value') or
      SameText(AKind, 'method') or
      SameText(AKind, 'field') or
      SameText(AKind, 'function') or
      SameText(AKind, 'procedure') or
      SameText(AKind, 'constant') or
      SameText(AKind, 'variable');
  end;
begin
  RootUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);
  Seen := specialize THashMap<string, LongInt>.Create;
  try
    for I := 0 to FModel.SymbolCount - 1 do
    begin
      Sym := FModel.SymbolAt(I);
      if SameText(Sym.Kind, 'unit') then
        Continue;
      if not SameText(Sym.OwnerUnitId, RootUnitId) then
        Continue;
      if IsExcludedKind(Sym.Kind) then
        Continue;
      if Sym.Name = '' then
        Continue;
      Key := LowerCase(Sym.Name) + '#' + IntToStr(Sym.ScopeId);
      if Seen.TryGetValue(Key, ExistingIdx) then
      begin
        if (ExistingIdx >= 0) and (ExistingIdx < FModel.SymbolCount) then
          ExistingSym := FModel.SymbolAt(ExistingIdx)
        else
          ExistingSym := Sym;
        if SameText(ExistingSym.Kind, 'type') and SameText(Sym.Kind, 'type') then
          Continue;
        EmitSemaError(
          'sema.duplicate-declaration',
          'duplicate identifier "' + Sym.Name + '"',
          Sym.ByteOffset
        );
        Exit;
      end
      else
        Seen.Add(Key, I);
    end;
  finally
    Seen.Free;
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
  DistArr: array of LongInt;
  Sym: TSemanticSymbol;
  Scp: TSemanticScope;
  Suggestion: string;
  IsVisible: Boolean;
  TmpStr: string;
  TmpDist: LongInt;
  CurScope: LongInt;
  Found: Boolean;
  CalleeChild: TGreenNode;
  HandlerVarCache: specialize TVec<string>;
  HandlerVarCacheReady: Boolean;
  MethodSuffixCache: specialize TVec<string>;
  MethodSuffixCacheReady: Boolean;
  function IsKnownUnitPrefix(const AUnitPrefix: string): Boolean;
  var
    Idx: LongInt;
    UName: string;
  begin
    Result := False;
    if FUnitGraph = nil then Exit;
    for Idx := 0 to FUnitGraph.ResolvedUnitCount - 1 do
    begin
      UName := FUnitGraph.ResolvedUnitAt(Idx).CanonicalName;
      if SameText(UName, AUnitPrefix) then Exit(True);
      if (Length(UName) > Length(AUnitPrefix) + 1) and
        SameText(Copy(UName, 1, Length(AUnitPrefix) + 1), AUnitPrefix + '.') then
        Exit(True);
    end;
  end;

  procedure EnsureHandlerVarCache;
  var
    Stk: specialize TVec<TGreenNode>;
    Cur, CCh: TGreenNode;
    SIdx: LongInt;
    VIdx: LongInt;
    Already: Boolean;
  begin
    if HandlerVarCacheReady then Exit;
    HandlerVarCacheReady := True;
    if (FRootAst = nil) or (FRootAst.RootNode = nil) then Exit;
    // from already registered vector
    if FExceptionHandlerVars <> nil then
      for VIdx := 0 to FExceptionHandlerVars.Count - 1 do
        HandlerVarCache.Push(FExceptionHandlerVars[VIdx]);
    // supplement by scanning tree once
    Stk := specialize TVec<TGreenNode>.Create;
    try
      Stk.Push(FRootAst.RootNode);
      while Stk.Count > 0 do
      begin
        Cur := Stk[Stk.Count - 1];
        Stk.Pop;
        if Cur = nil then Continue;
        if Cur.NodeKind = gnkExceptionHandler then
        begin
          Already := False;
          for VIdx := 0 to LongInt(HandlerVarCache.Count) - 1 do
            if SameText(HandlerVarCache[VIdx], Cur.Text) then begin Already := True; Break; end;
          if not Already and (Cur.Text <> '') then
            HandlerVarCache.Push(Cur.Text);
        end;
        for SIdx := 0 to Cur.ChildCount - 1 do
        begin
          CCh := Cur.ChildAt(SIdx);
          if CCh <> nil then Stk.Push(CCh);
        end;
      end;
    finally
      Stk.Free;
    end;
  end;

  function IsHandlerVarCached(const AVarName: string): Boolean;
  var
    VIdx: LongInt;
  begin
    EnsureHandlerVarCache;
    for VIdx := 0 to LongInt(HandlerVarCache.Count) - 1 do
      if SameText(HandlerVarCache[VIdx], AVarName) then Exit(True);
    Result := False;
  end;

  procedure EnsureMethodSuffixCache;
  var
    SIdx: LongInt;
    SymLoc: TSemanticSymbol;
    Suf: string;
    VIdx: LongInt;
    Already: Boolean;
    DotPos: LongInt;
  begin
    if MethodSuffixCacheReady then Exit;
    MethodSuffixCacheReady := True;
    for SIdx := 0 to FModel.SymbolCount - 1 do
    begin
      SymLoc := FModel.SymbolAt(SIdx);
      if not SameText(SymLoc.Kind, 'method') then Continue;
      DotPos := LastDelimiter('.', SymLoc.Name);
      if DotPos = 0 then Continue;
      Suf := Copy(SymLoc.Name, DotPos + 1, MaxInt);
      if Suf = '' then Continue;
      Already := False;
      for VIdx := 0 to LongInt(MethodSuffixCache.Count) - 1 do
        if SameText(MethodSuffixCache[VIdx], Suf) then begin Already := True; Break; end;
      if not Already then
        MethodSuffixCache.Push(Suf);
    end;
  end;

  function IsMethodSuffix(const AVarName: string): Boolean;
  var
    VIdx: LongInt;
  begin
    EnsureMethodSuffixCache;
    for VIdx := 0 to LongInt(MethodSuffixCache.Count) - 1 do
      if SameText(MethodSuffixCache[VIdx], AVarName) then Exit(True);
    Result := False;
  end;

  procedure DoCheck(const AName: string; AOffset: LongInt);
  var
    K, L: LongInt;
    Seen: specialize THashMap<string, Byte>;
    LowKey: string;
    procedure QuickSort(ALo, AHi: LongInt);
    var
      I, J, Pivot: LongInt;
      TmpS: string;
      TmpD: LongInt;
    begin
      if ALo >= AHi then Exit;
      I := ALo; J := AHi; Pivot := DistArr[(ALo + AHi) div 2];
      repeat
        while DistArr[I] < Pivot do Inc(I);
        while DistArr[J] > Pivot do Dec(J);
        if I <= J then
        begin
          TmpS := CandidateArr[I]; CandidateArr[I] := CandidateArr[J]; CandidateArr[J] := TmpS;
          TmpD := DistArr[I]; DistArr[I] := DistArr[J]; DistArr[J] := TmpD;
          Inc(I); Dec(J);
        end;
      until I > J;
      if ALo < J then QuickSort(ALo, J);
      if I < AHi then QuickSort(I, AHi);
    end;
  begin
    if (AName = '') or (AName = 'Result') then Exit;
    if SameText(AName, 'nil') or SameText(AName, 'true') or SameText(AName, 'false') then Exit;
    if IsKnownUnitPrefix(AName) then Exit;
    if IsExceptionHandlerVar(AName) then Exit;
    if IsHandlerVarCached(AName) then Exit;
    SymId := FModel.LookupSymbol(AName, FCurrentScopeId);
    if (SymId <> 0) or (FModel.FindSymbolByName(AName) <> 0) or (FModel.FindTypeByName(AName) <> 0) or
      IsBuiltinProcedure(AName) or IsRuntimeVar(AName) then Exit;
    if IsMethodSuffix(AName) then Exit;
    if FAllocator <> nil then
      CandidateNames := specialize TVec<string>.Create(0, FAllocator)
    else
      CandidateNames := specialize TVec<string>.Create;
    Seen := specialize THashMap<string, Byte>.Create;
    try
      for K := 0 to FModel.SymbolCount - 1 do
      begin
        Sym := FModel.SymbolAt(K);
        if Sym.Name = '' then Continue;
        if SameText(Sym.Name, AName) then Continue;
        IsVisible := False;
        if Sym.ScopeId = 0 then
          IsVisible := True
        else
        begin
          CurScope := FCurrentScopeId;
          while CurScope <> 0 do
          begin
            if Sym.ScopeId = CurScope then
            begin IsVisible := True; Break; end;
            if (CurScope <= FModel.ScopeCount) and (CurScope > 0) then
              CurScope := FModel.ScopeAt(CurScope - 1).ParentScopeId
            else
              Break;
          end;
          if not IsVisible then
            for L := 0 to FModel.ScopeCount - 1 do
            begin
              Scp := FModel.ScopeAt(L);
              if (Scp.Kind = skUnit) and (Scp.ParentScopeId = 1) and (Sym.ScopeId = Scp.ScopeId) then
              begin IsVisible := True; Break; end;
            end;
        end;
        if not IsVisible then Continue;
        LowKey := LowerCase(Sym.Name);
        if Seen.ContainsKey(LowKey) then Continue;
        Seen.Add(LowKey, 0);
        CandidateNames.Push(Sym.Name);
      end;
      SetLength(CandidateArr, LongInt(CandidateNames.Count));
      SetLength(DistArr, LongInt(CandidateNames.Count));
      for K := 0 to LongInt(CandidateNames.Count) - 1 do
      begin
        CandidateArr[K] := CandidateNames[K];
        DistArr[K] := ComputeEditDistance(AName, CandidateArr[K]);
      end;
      if Length(CandidateArr) > 1 then
        QuickSort(0, High(CandidateArr));
      if Length(CandidateArr) > 3 then
        SetLength(CandidateArr, 3);
      Suggestion := SuggestDidYouMean(AName, CandidateArr, 3);
    finally
      Seen.Free;
      CandidateNames.Free;
    end;
    if Suggestion <> '' then
      EmitSemaError('sema.undeclared-identifier', 'identifier not found "' + AName + '". ' + Suggestion, AOffset)
    else
      EmitSemaError('sema.undeclared-identifier', 'identifier not found "' + AName + '"', AOffset);
  end;
begin
  HandlerVarCache := specialize TVec<string>.Create;
  MethodSuffixCache := specialize TVec<string>.Create;
  HandlerVarCacheReady := False;
  MethodSuffixCacheReady := False;
  try
    if ANode = nil then Exit;
    case ANode.NodeKind of
    gnkIdentifier:
      begin
        DoCheck(ANode.Text, ANode.ByteOffset);
      end;
    gnkAssignmentStatement:
      begin
        Name := ANode.Text;
        if Pos('.', Name) = 0 then
          DoCheck(Name, ANode.ByteOffset);
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if Child <> nil then CheckIdentifiersInNode(Child);
        end;
        Exit;
      end;
    gnkProcedureCallStatement:
      begin
        Name := ANode.Text;
        // method calls like SL.Add appear as procedure call with Name='Add' and a dot child; skip bare method check
        if Pos('.', Name) = 0 then
        begin
          // if any child is a dot access, this is a method call — receiver already checked via dot handling
          for I := 0 to ANode.ChildCount - 1 do
          begin
            Child := ANode.ChildAt(I);
            if (Child <> nil) and (Child.NodeKind = gnkDotAccess) then
            begin
              Name := '';
              Break;
            end;
          end;
          if Name <> '' then
            DoCheck(Name, ANode.ByteOffset);
        end;
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if (I = 0) and (Child <> nil) and (Child.NodeKind = gnkIdentifier) and SameText(Child.Text, ANode.Text) then Continue;
          if Child <> nil then CheckIdentifiersInNode(Child);
        end;
        Exit;
      end;
    gnkFunctionCall:
      begin
        if ANode.ChildCount > 0 then
        begin
          CalleeChild := ANode.ChildAt(0);
          if (CalleeChild <> nil) and (CalleeChild.NodeKind = gnkIdentifier) then
            if Pos('.', CalleeChild.Text) = 0 then
              DoCheck(CalleeChild.Text, CalleeChild.ByteOffset);
          if (CalleeChild <> nil) and (CalleeChild.NodeKind = gnkDotAccess) then
          begin
            // method call via dot — receiver checked via dot handling, not callee bare
          end;
        end;
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if (I = 0) and (Child <> nil) and (Child.NodeKind = gnkIdentifier) then Continue;
          if (I = 0) and (Child <> nil) and (Child.NodeKind = gnkDotAccess) then Continue;
          if Child <> nil then CheckIdentifiersInNode(Child);
        end;
        Exit;
      end;
    gnkDotAccess:
      begin
        // receiver is child 0; field/method name (child 1) is not a bare identifier
        if ANode.ChildCount > 0 then
        begin
          Child := ANode.ChildAt(0);
          if Child <> nil then CheckIdentifiersInNode(Child);
          // handle possible additional indices (e.g. a.b[0] parsed as dot+array)
          for I := 1 to ANode.ChildCount - 1 do
          begin
            Child := ANode.ChildAt(I);
            if Child = nil then Continue;
            // second child is field/method name if it's a plain identifier — skip bare check
            if (I = 1) and (Child.NodeKind = gnkIdentifier) then Continue;
            CheckIdentifiersInNode(Child);
          end;
        end;
        Exit;
      end;
    gnkBinaryExpression, gnkUnaryExpression:
      begin
        // operators (+, -, *, /, <>, and, or, not, etc.) are not identifiers
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if Child <> nil then CheckIdentifiersInNode(Child);
        end;
        Exit;
      end;
    gnkArrayAccess, gnkDereference, gnkAddressOf, gnkSetConstructor, gnkRangeExpression:
      begin
        if ANode.Text <> '' then
          DoCheck(ANode.Text, ANode.ByteOffset);
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if Child <> nil then CheckIdentifiersInNode(Child);
        end;
        Exit;
      end;
    else
      begin
        if (ANode.Text <> '') and (ANode.ChildCount = 0) then
        begin
          if ANode.Text[1] in ['A'..'Z','a'..'z','_'] then
            DoCheck(ANode.Text, ANode.ByteOffset);
        end;
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if Child <> nil then CheckIdentifiersInNode(Child);
        end;
      end;
    end;
  finally
    HandlerVarCache.Free;
    MethodSuffixCache.Free;
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
