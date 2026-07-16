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
begin
  FGenericWorkQueue.EnsureCapacity(LongInt(FProcedureBodies.Count) + 64);
  WorkHead := 0;
  for I := 0 to LongInt(FProcedureBodies.Count) - 1 do
  begin
    if (FProcedureBodies[I].Body = nil) then
      Continue;
    if Pos('<', FProcedureBodies[I].Name) > 0 then
      Continue;
    Found := False;
    for J := 0 to LongInt(FGenericWorkQueue.Count) - 1 do
      if FGenericWorkQueue[J] = I then begin Found := True; Break; end;
    if Found then Continue;
    FGenericWorkQueue.Push(I);
  end;

  while WorkHead < LongInt(FGenericWorkQueue.Count) do
  begin
    I := FGenericWorkQueue[WorkHead];
    Inc(WorkHead);
    if I < 0 then Continue;
    Entry := FProcedureBodies[I];
    if (Entry.Body = nil) or (Entry.Decl = nil) then
      Continue;
    if (Entry.Body = nil) or (Entry.Decl = nil) then
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
  end;
end;

