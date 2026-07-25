{ Reachable body seed helpers (Batch 9 / Slice C) — TVec-adapted handport. }

procedure TSemanticAnalyzer.MarkClassMethodCohort(const AClassName: string);
var
  K: LongInt;
  Prefix: string;
  Entry: TProcedureBodyEntry;
begin
  { VMT: constructing Class requires sibling methods (GetVal, etc.). }
  if AClassName = '' then
    Exit;
  Prefix := AClassName + '.';
  for K := 0 to LongInt(FProcedureBodies.Count) - 1 do
    if (Length(FProcedureBodies[K].Name) > Length(Prefix)) and
      SameText(Copy(FProcedureBodies[K].Name, 1, Length(Prefix)), Prefix) then
    begin
      Entry := FProcedureBodies[K];
      Entry.Needed := True;
      FProcedureBodies[K] := Entry;
    end;
end;

procedure TSemanticAnalyzer.MarkProcedureBodyNeededByName(const AName: string);
var
  Bare, LClassName, LMethodName: string;
  Index, DotPos, J: LongInt;
  Entry: TProcedureBodyEntry;
begin
  { Exact mark via name walk. Cohort only for Create/Destroy. }
  if AName = '' then
    Exit;
  Bare := AName;
  if Pos('$', Bare) > 0 then
    Bare := Copy(Bare, 1, Pos('$', Bare) - 1);
  if Bare = '' then
    Exit;
  Index := FirstBodyIndexForName(FProcedureBodies, Bare);
  while Index >= 0 do
  begin
    Entry := FProcedureBodies[Index];
    Entry.Needed := True;
    FProcedureBodies[Index] := Entry;
    Index := NextBodyIndexForName(FProcedureBodies, Bare, Index);
  end;
  if not SameText(Bare, AName) then
  begin
    Index := FirstBodyIndexForName(FProcedureBodies, AName);
    while Index >= 0 do
    begin
      Entry := FProcedureBodies[Index];
      Entry.Needed := True;
      FProcedureBodies[Index] := Entry;
      Index := NextBodyIndexForName(FProcedureBodies, AName, Index);
    end;
  end;
  { Class.Create / Class.Destroy → mark class method cohort for VMT slots. }
  DotPos := 0;
  for J := Length(Bare) downto 1 do
    if Bare[J] = '.' then
    begin
      DotPos := J;
      Break;
    end;
  if DotPos > 1 then
  begin
    LClassName := Copy(Bare, 1, DotPos - 1);
    LMethodName := Copy(Bare, DotPos + 1, MaxInt);
    if SameText(LMethodName, 'Create') or (Pos('Create$', LMethodName) = 1) or
      SameText(LMethodName, 'Destroy') then
      MarkClassMethodCohort(LClassName);
  end;
end;

procedure TSemanticAnalyzer.MarkBodiesFromTypedHirCalls;
var
  I: LongInt;
  Node: TTypedHirNode;
  Target: string;
begin
  for I := 0 to FModel.TypedHirNodeCount - 1 do
  begin
    Node := FModel.TypedHirNodeAt(I);
    case Node.NodeKind of
      hnkCallRuntime, hnkHaltCallRuntime, hnkHaltCall,
      hnkAssignTStringCallRuntime, hnkClassNewRuntime,
      hnkObjectFreeRuntime:
        begin
          Target := Node.DisplayName;
          if Target = '' then
            Target := Node.Operand;
          if (Target <> '') and (Target[1] <> '_') and
            (not SameText(Target, 'Halt')) and
            (not SameText(Target, '__discard__')) and
            (not SameText(Target, '__halt_code__')) then
            MarkProcedureBodyNeededByName(Target);
        end;
    else
      ;
    end;
  end;
end;

procedure TSemanticAnalyzer.CollectReachableBodyRoots;
var
  I: LongInt;
  RootId: string;
  Queue: array of LongInt;
  QHead, QTail: LongInt;
  Visited: array of Boolean;
  NeededCount: LongInt;
  Entry: TProcedureBodyEntry;

  procedure EnqueueBody(const AIndex: LongInt);
  var
    Own, PName: string;
  begin
    if (AIndex < 0) or (AIndex >= LongInt(FProcedureBodies.Count)) then
      Exit;
    if not FProcedureBodies[AIndex].Needed then
      Exit;
    if Visited[AIndex] then
      Exit;
    Visited[AIndex] := True;
    if FProcedureBodies[AIndex].Body = nil then
      Exit;
    PName := FProcedureBodies[AIndex].Name;
    Own := LowerCase(FProcedureBodies[AIndex].OwnerUnitId);
    { Do not green-expand method bodies — Create cohort already marks VMT
      siblings; walking every Create body re-fans identifiers into Needed. }
    if Pos('.', PName) > 0 then
      Exit;
    { Flood-prone free-function units: keep exact Needed if marked, no expand. }
    if (Pos('simd', Own) > 0) or (Pos('nextpas.core.math', Own) > 0) or
      (Pos('nextpas.core.crypto', Own) > 0) then
      Exit;
    if QTail >= Length(Queue) then
      SetLength(Queue, QTail + 128);
    Queue[QTail] := AIndex;
    Inc(QTail);
  end;

  procedure MarkIndex(const AIndex: LongInt);
  begin
    if (AIndex < 0) or (AIndex >= LongInt(FProcedureBodies.Count)) then
      Exit;
    Entry := FProcedureBodies[AIndex];
    Entry.Needed := True;
    FProcedureBodies[AIndex] := Entry;
    EnqueueBody(AIndex);
  end;

  procedure MarkNameAndEnqueue(const AName: string);
  var
    Bare, LClassName, LMethodName: string;
    Index, DotPos, J: LongInt;
  begin
    if AName = '' then
      Exit;
    Bare := AName;
    if Pos('$', Bare) > 0 then
      Bare := Copy(Bare, 1, Pos('$', Bare) - 1);
    if Bare = '' then
      Exit;
    { Ignore bare Create/Destroy — only Class.Create via DotAccess. }
    if (Pos('.', Bare) = 0) and
      (SameText(Bare, 'Create') or SameText(Bare, 'Destroy') or
       SameText(Bare, '_AddRef') or SameText(Bare, '_Release')) then
      Exit;
    Index := FirstBodyIndexForName(FProcedureBodies, Bare);
    while Index >= 0 do
    begin
      MarkIndex(Index);
      Index := NextBodyIndexForName(FProcedureBodies, Bare, Index);
    end;
    if not SameText(Bare, AName) then
    begin
      Index := FirstBodyIndexForName(FProcedureBodies, AName);
      while Index >= 0 do
      begin
        MarkIndex(Index);
        Index := NextBodyIndexForName(FProcedureBodies, AName, Index);
      end;
    end;
    { Cohort only for Class.Create / Class.Destroy (VMT). }
    DotPos := 0;
    for J := Length(Bare) downto 1 do
      if Bare[J] = '.' then
      begin
        DotPos := J;
        Break;
      end;
    if DotPos > 1 then
    begin
      LClassName := Copy(Bare, 1, DotPos - 1);
      LMethodName := Copy(Bare, DotPos + 1, MaxInt);
      if SameText(LMethodName, 'Create') or (Pos('Create$', LMethodName) = 1) or
        SameText(LMethodName, 'Destroy') then
      begin
        MarkClassMethodCohort(LClassName);
        for Index := 0 to LongInt(FProcedureBodies.Count) - 1 do
          if FProcedureBodies[Index].Needed then
            EnqueueBody(Index);
      end;
    end;
  end;

  procedure WalkGreenForCallNames(const ANode: TGreenNode);
  var
    ChildIdx: LongInt;
    Child, C0, C1: TGreenNode;
    Qual: string;
  begin
    if ANode = nil then
      Exit;
    if ANode.Text <> '' then
    begin
      if (ANode.NodeKind = gnkIdentifier) or
        (ANode.NodeKind = gnkProcedureDecl) or
        (ANode.NodeKind = gnkFunctionDecl) or
        (ANode.NodeKind = gnkDotAccess) then
        MarkNameAndEnqueue(ANode.Text);
    end;
    if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) then
    begin
      C0 := ANode.ChildAt(0);
      C1 := ANode.ChildAt(1);
      if (C0 <> nil) and (C1 <> nil) and (C0.Text <> '') and (C1.Text <> '') then
      begin
        Qual := C0.Text + '.' + C1.Text;
        MarkNameAndEnqueue(Qual);
      end;
    end;
    for ChildIdx := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(ChildIdx);
      if Child <> nil then
        WalkGreenForCallNames(Child);
    end;
  end;

begin
  WriteLn(StdErr, '[sema] CollectReachableBodyRoots...');
  Flush(StdErr);
  SetLength(Visited, LongInt(FProcedureBodies.Count));
  for I := 0 to Length(Visited) - 1 do
    Visited[I] := False;
  SetLength(Queue, 64);
  QHead := 0;
  QTail := 0;

  RootId := '';
  if FUnitGraph <> nil then
    RootId := FUnitGraph.RootName;

  { Initial seeds: root unit + CLI + minimal System VMT. }
  for I := 0 to LongInt(FProcedureBodies.Count) - 1 do
  begin
    Entry := FProcedureBodies[I];
    if (RootId <> '') and SameText(Entry.OwnerUnitId, RootId) then
      Entry.Needed := True;
    if SameText(Entry.Name, 'ParamCount') or
      SameText(Entry.Name, 'ParamStr') then
      Entry.Needed := True;
    FProcedureBodies[I] := Entry;
  end;
  MarkNameAndEnqueue('TObject.Create');
  MarkNameAndEnqueue('TObject.Destroy');
  MarkNameAndEnqueue('TInterfacedObject.Create');
  MarkNameAndEnqueue('TInterfacedObject._AddRef');
  MarkNameAndEnqueue('TInterfacedObject._Release');
  MarkNameAndEnqueue('Exception.Create');
  MarkNameAndEnqueue('Exception.Destroy');

  for I := 0 to LongInt(FProcedureBodies.Count) - 1 do
    if FProcedureBodies[I].Needed then
      EnqueueBody(I);

  { Program green + unit init/fini greens. }
  if (FRootAst <> nil) and FRootAst.IsValid then
    WalkGreenForCallNames(FRootAst.RootNode);
  for I := 0 to FModel.TypedHirNodeCount - 1 do
    if (FModel.TypedHirNodeAt(I).NodeKind = hnkUnitInitRuntime) or
      (FModel.TypedHirNodeAt(I).NodeKind = hnkUnitFiniRuntime) then
      if not GreenNodeIsNil(FModel.TypedHirNodeAt(I).GreenNodeRef) then
        WalkGreenForCallNames(FModel.TypedHirNodeAt(I).GreenNodeRef);
  MarkBodiesFromTypedHirCalls;
  for I := 0 to LongInt(FProcedureBodies.Count) - 1 do
    if FProcedureBodies[I].Needed then
      EnqueueBody(I);

  while QHead < QTail do
  begin
    I := Queue[QHead];
    Inc(QHead);
    if (I >= 0) and (I < LongInt(FProcedureBodies.Count)) and
      (FProcedureBodies[I].Body <> nil) then
      WalkGreenForCallNames(FProcedureBodies[I].Body);
  end;
  MarkBodiesFromTypedHirCalls;
  for I := 0 to LongInt(FProcedureBodies.Count) - 1 do
    if FProcedureBodies[I].Needed and (not Visited[I]) then
      EnqueueBody(I);
  while QHead < QTail do
  begin
    I := Queue[QHead];
    Inc(QHead);
    if (I >= 0) and (I < LongInt(FProcedureBodies.Count)) and
      (FProcedureBodies[I].Body <> nil) then
      WalkGreenForCallNames(FProcedureBodies[I].Body);
  end;

  NeededCount := 0;
  for I := 0 to LongInt(FProcedureBodies.Count) - 1 do
    if FProcedureBodies[I].Needed then
      Inc(NeededCount);
  WriteLn(StdErr, '[sema] CollectReachableBodyRoots done needed=', NeededCount,
    ' registered=', LongInt(FProcedureBodies.Count));
  Flush(StdErr);
end;

procedure TSemanticAnalyzer.SeedFunctionBodies;
var
  I, J, K: LongInt;
  Entry: TProcedureBodyEntry;
  ParamCount: LongInt;
  Child, ParamChild, TypeChild, Decl, ArrayTypeNode: TGreenNode;
  SavedTerminated: Boolean;
  ParamTypes, RetVarName, EffName, ArrOperand: string;
  IsStrParam, IsStrReturn, IsPtrReturn, IsVarP, IsRecReturn: Boolean;
  OwnedStringReturn: Boolean;
  PtrReturnClass: string;
  Folded, Value: Int64;
  NodeId, WorkHead: LongInt;
  Found: Boolean;
  NeededCount, EncodedCount: LongInt;
begin
  FSeedingBodiesActive := True;
  try
    CollectReachableBodyRoots;
    FGenericWorkQueue.Clear;
    FGenericWorkQueue.EnsureCapacity(LongInt(FProcedureBodies.Count) + 64);
    WorkHead := 0;
    { Fixed-point: mid-seed RegisterProcedureBody may add/refresh Needed bodies.
      Only enqueue Needed and not yet Encoded (reachability budget). }
    while True do
    begin
      MarkBodiesFromTypedHirCalls;
      for I := 0 to LongInt(FProcedureBodies.Count) - 1 do
      begin
        if FProcedureBodies[I].Body = nil then
          Continue;
        if not FProcedureBodies[I].Needed then
          Continue;
        if FProcedureBodies[I].Encoded then
          Continue;
        { Keep specialized parent names with '<' (e.g. TFoo<string>.Destroy). }
        Found := False;
        for J := 0 to LongInt(FGenericWorkQueue.Count) - 1 do
          if FGenericWorkQueue[J] = I then
          begin
            Found := True;
            Break;
          end;
        if Found then
          Continue;
        FGenericWorkQueue.Push(I);
      end;
      if WorkHead >= LongInt(FGenericWorkQueue.Count) then
        Break;

  while WorkHead < LongInt(FGenericWorkQueue.Count) do
  begin
    I := FGenericWorkQueue[WorkHead];
    Inc(WorkHead);
    if I < 0 then Continue;
    Entry := FProcedureBodies[I];
    if (Entry.Body = nil) or (Entry.Decl = nil) then
    begin
      Entry.Encoded := True;
      FProcedureBodies[I] := Entry;
      Continue;
    end;
    if Entry.Encoded then
      Continue;
    FRuntimeVars.Reset;
    if HasOverload(Entry.Name) then
      EffName := MangledNameSig(Entry.Name, GetParamSignature(Entry.Decl))
    else
      EffName := Entry.Name;
    ParamCount := 0;
    ParamTypes := '';
    IsStrReturn := False;
    IsPtrReturn := False;
    IsRecReturn := False;
    OwnedStringReturn := False;
    PtrReturnClass := '';
    if Entry.Decl <> nil then
    begin
      for J := 0 to Entry.Decl.ChildCount - 1 do
      begin
        Child := Entry.Decl.ChildAt(J);
        if Child = nil then
          Continue;
        if Child.NodeKind = gnkParameterList then
        begin
          for K := 0 to Child.ChildCount - 1 do
          begin
            ParamChild := Child.ChildAt(K);
            if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
            begin
              ParamTypes := ParamTypes;
              RetVarName := ParamChild.Text;
              IsVarP := ParamNameIsByRef(RetVarName);
              if IsVarP then
                RetVarName := StripParamModifier(RetVarName);
              RegisterRuntimeVar(RetVarName);
              if IsVarP then
                RegisterVarParam(RetVarName);
              IsStrParam := False;
              if ParamChild.ChildCount > 0 then
              begin
                TypeChild := ParamChild.ChildAt(0);
                if (TypeChild <> nil) and
                  (SameText(TypeChild.Text, 'String') or
                   SameText(TypeChild.Text, 'AnsiString')) then
                begin
                  IsStrParam := True;
                  RegisterRuntimeStrVar(RetVarName);
                  RegisterBorrowedRuntimeStrVar(RetVarName);
                end
                else if (TypeChild <> nil) and
                  ((TypeChild.NodeKind = gnkArrayType) or
                   ((TypeChild.Text = '') and (K + 1 < Child.ChildCount) and
                    (Child.ChildAt(K + 1) <> nil) and
                    (Child.ChildAt(K + 1).NodeKind = gnkArrayType))) then
                begin
                  RegisterRuntimeArrVar(RetVarName);
                  RegisterBorrowedRuntimeArrVar(RetVarName);
                end
                else if (TypeChild <> nil) and
                  (Length(TypeChild.Text) > 1) and (TypeChild.Text[1] = '^') then
                begin
                  RegisterClassVar(RetVarName, 'Pointer');
                  RegisterPointerVar(RetVarName, Copy(TypeChild.Text, 2,
                    Length(TypeChild.Text)));
                end
                else if (TypeChild <> nil) and
                  (TypeMetaSize(TypeChild.Text) > 0) then
                begin
                  if TypeMetaIsRecord(TypeChild.Text) then
                    RegisterRecordVar(RetVarName, TypeChild.Text)
                  else
                    RegisterClassVar(RetVarName, TypeChild.Text);
                end;
              end;
              if IsStrParam then
                ParamTypes := ParamTypes + 's'
              else if IsRuntimeArrVar(RetVarName) then
                ParamTypes := ParamTypes + 'a'
              else if (ParamChild.ChildCount > 0) and
                (ParamChild.ChildAt(0) <> nil) and
                (Length(ParamChild.ChildAt(0).Text) > 1) and
                (ParamChild.ChildAt(0).Text[1] = '^') then
                ParamTypes := ParamTypes + 'p'
              else if (ParamChild.ChildCount > 0) and
                (ParamChild.ChildAt(0) <> nil) and
                (TypeMetaSize(ParamChild.ChildAt(0).Text) > 0) then
              begin
                if TypeMetaIsRecord(ParamChild.ChildAt(0).Text) then
                  ParamTypes := ParamTypes + 'r'
                else if IsVarP then
                  ParamTypes := ParamTypes + 'v'
                else
                  ParamTypes := ParamTypes + 'p';
              end
              else if IsVarP then
                ParamTypes := ParamTypes + 'v'
              else
                ParamTypes := ParamTypes + 'i';
              Inc(ParamCount);
            end;
          end;
        end
        else if (Child.NodeKind = gnkIdentifier) and
          (Child.NodeKind <> gnkBeginBlock) and
          (SameText(Child.Text, 'String') or
           SameText(Child.Text, 'AnsiString')) then
          IsStrReturn := True
        else if (Child.NodeKind = gnkIdentifier) and
          (Child.NodeKind <> gnkBeginBlock) and
          TypeMetaIsClass(Child.Text) then
        begin
          IsPtrReturn := True;
          PtrReturnClass := Child.Text;
        end
        else if (Child.NodeKind = gnkIdentifier) and
          (Child.NodeKind <> gnkBeginBlock) and
          TypeMetaIsRecord(Child.Text) then
        begin
          IsRecReturn := True;
          PtrReturnClass := Child.Text;
        end;
      end;
    end;
    if IsPtrReturn and (Pos('.', Entry.Name) = 0) then
      RegisterPtrReturnFunc(Entry.Name, PtrReturnClass);
    OwnedStringReturn := IsRootOwnedStringReturnCandidate(Entry, IsStrReturn) and
      IsOwnedStringReturnFunc(EffName);
    if Pos('.', Entry.Name) > 0 then
    begin
      FCurrentMethodClass := Copy(Entry.Name, 1, Pos('.', Entry.Name) - 1);
      if IsStrReturn then
        FModel.AddTypedHirNode('method-body-begin', Entry.Name, 0, 0,
          IntToStr(ParamCount + 1) + ':p' + ParamTypes + ':s')
      else if IsPtrReturn then
        FModel.AddTypedHirNode('method-body-begin', Entry.Name, 0, 0,
          IntToStr(ParamCount + 1) + ':p' + ParamTypes + ':p')
      else
        FModel.AddTypedHirNode('method-body-begin', Entry.Name, 0, 0,
          IntToStr(ParamCount + 1) + ':p' + ParamTypes);
      RegisterRuntimeVar('self');
    end
    else if IsStrReturn and OwnedStringReturn then
      FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
        IntToStr(ParamCount) + ':' + ParamTypes + ':so')
    else if IsStrReturn then
      FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
        IntToStr(ParamCount) + ':' + ParamTypes + ':s')
    else if IsPtrReturn then
      FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
        IntToStr(ParamCount) + ':' + ParamTypes + ':p')
    else if IsRecReturn then
    begin
      Folded := TypeMetaSize(PtrReturnClass);
      if Folded > 0 then
        FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
          IntToStr(ParamCount) + ':' + ParamTypes + ':r' + IntToStr(Folded div 8))
      else
        FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
          IntToStr(ParamCount) + ':' + ParamTypes);
    end
    else
      FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
        IntToStr(ParamCount) + ':' + ParamTypes);
    if Entry.Decl <> nil then
    begin
      for J := 0 to Entry.Decl.ChildCount - 1 do
      begin
        Child := Entry.Decl.ChildAt(J);
        if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
        begin
          for K := 0 to Child.ChildCount - 1 do
          begin
            ParamChild := Child.ChildAt(K);
            if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
            begin
              RetVarName := ParamChild.Text;
              if ParamNameIsByRef(RetVarName) then
                RetVarName := StripParamModifier(RetVarName);
              if IsRuntimeStrVar(RetVarName) then
                FModel.AddTypedHirNode('var-decl-tstring-runtime', RetVarName,
                  0, 0, RetVarName)
              else if IsRuntimeArrVar(RetVarName) then
              begin
                if IsBorrowedRuntimeArrVar(RetVarName) then
                  FModel.AddTypedHirNode('var-decl-arr-borrowed-runtime',
                    RetVarName, 0, 0, RetVarName)
                else
                  FModel.AddTypedHirNode('var-decl-arr-runtime', RetVarName,
                    0, 0, RetVarName);
              end
              else if IsRecordVar(RetVarName) then
                FModel.AddTypedHirNode('var-decl-ptr-runtime', RetVarName,
                  0, 0, RetVarName)
              else if IsVarParam(RetVarName) then
                FModel.AddTypedHirNode('var-decl-varref-runtime', RetVarName,
                  0, 0, RetVarName)
              else
                FModel.AddTypedHirNode('var-decl-runtime', RetVarName,
                  0, 0, ParamChild.Text);
            end;
          end;
          Break;
        end;
      end;
    end;
    if Pos('.', Entry.Name) > 0 then
      RetVarName := Copy(Entry.Name, Pos('.', Entry.Name) + 1, Length(Entry.Name))
    else
      RetVarName := Entry.Name;
    RegisterRuntimeVar(RetVarName);
    if (Entry.Decl <> nil) and (Entry.Decl.NodeKind = gnkFunctionDecl) then
      FCurrentRetVarName := RetVarName
    else if Pos('.', Entry.Name) > 0 then
      FCurrentRetVarName := RetVarName
    else
      FCurrentRetVarName := '';
    FCurrentOwnedStringReturn := OwnedStringReturn;
    if IsStrReturn then
    begin
      RegisterRuntimeStrVar(RetVarName);
      if OwnedStringReturn then
        RegisterOwnedRuntimeStrVar(RetVarName);
    end;
    if IsRecReturn then
      RegisterRecordVar(RetVarName, PtrReturnClass);
    if IsStrReturn and OwnedStringReturn then
      FModel.AddTypedHirNode('var-decl-tstring-runtime', RetVarName, 0, 0,
        RetVarName)
    else if IsStrReturn then
      FModel.AddTypedHirNode('var-decl-tstring-runtime', RetVarName, 0, 0, RetVarName)
    else if IsPtrReturn then
      FModel.AddTypedHirNode('var-decl-ptr-runtime', RetVarName, 0, 0, RetVarName)
    else if IsRecReturn then
      FModel.AddTypedHirNode('var-decl-ptr-runtime', RetVarName, 0, 0, RetVarName)
    else
      FModel.AddTypedHirNode('var-decl-runtime', RetVarName, 0, 0, RetVarName);
    if Entry.Decl <> nil then
      for J := 0 to Entry.Decl.ChildCount - 1 do
      begin
        Child := Entry.Decl.ChildAt(J);
        if (Child <> nil) and (Child.NodeKind = gnkVarSection) then
        begin
          for K := 0 to Child.ChildCount - 1 do
          begin
            Decl := Child.ChildAt(K);
            if (Decl = nil) or (Decl.NodeKind <> gnkVarDecl) or
              (Decl.Text = '') then
              Continue;
            RegisterRuntimeVar(Decl.Text);
            ArrayTypeNode := FindArrayTypeNodeForVarDecl(Child, K);
            if ArrayTypeNode <> nil then
            begin
              RegisterArrayVarMetadata(Decl.Text, ArrayTypeNode, ArrOperand);
              FModel.AddTypedHirNode(
                'var-decl-arr-runtime', Decl.Text, 0, 0, ArrOperand);
            end
            else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
              (TypeMetaSize(Decl.ChildAt(0).Text) > 0) and
              (not TypeMetaIsRecord(Decl.ChildAt(0).Text)) then
            begin
              RegisterClassVar(Decl.Text, Decl.ChildAt(0).Text);
              FModel.AddTypedHirNode(
                'var-decl-ptr-runtime', Decl.Text, 0, 0, Decl.Text);
            end
            else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
              (SameText(Decl.ChildAt(0).Text, 'String') or
               SameText(Decl.ChildAt(0).Text, 'AnsiString')) then
            begin
              RegisterRuntimeStrVar(Decl.Text);
              RegisterOwnedRuntimeStrVar(Decl.Text);
              FModel.AddTypedHirNode(
                'var-decl-tstring-runtime', Decl.Text, 0, 0, Decl.Text);
            end
            else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
              (Length(Decl.ChildAt(0).Text) > 1) and
              (Decl.ChildAt(0).Text[1] = '^') then
            begin
              RegisterPointerVar(Decl.Text, Copy(Decl.ChildAt(0).Text, 2,
                Length(Decl.ChildAt(0).Text)));
              FModel.AddTypedHirNode(
                'var-decl-ptr-runtime', Decl.Text, 0, 0, Decl.Text);
            end
            else
              FModel.AddTypedHirNode(
                'var-decl-runtime', Decl.Text, 0, 0, Decl.Text);
          end;
        end;
      end;
    SavedTerminated := FCurrentBlockTerminated;
    FCurrentBlockTerminated := False;
    WalkHaltCalls(Entry.Body);
    if not FCurrentBlockTerminated then
    begin
      EmitClassVarFreeCleanupNodes;
      EmitOwnedManagedRecordCleanupNodes;
      EmitOwnedDynArrayCleanupNodes;
      EmitOwnedStringCleanupNodes(RetVarName);
      if IsStrReturn and OwnedStringReturn then
        FModel.AddTypedHirNode('ret-tstring-runtime', RetVarName, 0, 0,
          RetVarName)
      else if IsStrReturn then
        FModel.AddTypedHirNode('ret-tstring-runtime', RetVarName, 0, 0, RetVarName)
      else
      begin
        NodeId := FModel.AddTypedHirNode('ret-runtime', RetVarName, 0, 0,
          'var ' + RetVarName + #10);
        AttachRuntimeReturnExpr(NodeId, RetVarName);
      end;
    end;
    FModel.AddTypedHirNode('function-body-end', EffName, 0, 0, '');
    FCurrentBlockTerminated := SavedTerminated;
    FCurrentMethodClass := '';
    FCurrentRetVarName := '';
    FCurrentOwnedStringReturn := False;
    Entry := FProcedureBodies[I];
    Entry.Encoded := True;
    FProcedureBodies[I] := Entry;
  end;
    end; { fixed-point outer while }

    NeededCount := 0;
    EncodedCount := 0;
    for I := 0 to LongInt(FProcedureBodies.Count) - 1 do
    begin
      if FProcedureBodies[I].Needed then
        Inc(NeededCount);
      if FProcedureBodies[I].Encoded then
        Inc(EncodedCount);
    end;
    WriteLn(StdErr, '[sema] body-seed-reachability registered=',
      LongInt(FProcedureBodies.Count), ' needed=', NeededCount, ' encoded=',
      EncodedCount, ' queue=', LongInt(FGenericWorkQueue.Count));
    Flush(StdErr);
  finally
    FSeedingBodiesActive := False;
  end;
end;