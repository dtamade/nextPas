procedure ScanOwnedStringReturnConsumers(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; const AEntry: TProcedureBodyEntry;
  var AChanged: Boolean);
var
  I, J: LongInt;
  Child: TGreenNode;
  FuncName: string;
begin
  if ANode = nil then
    Exit;
  if AssignmentOwnsStringReturn(Ctx, ANode, AEntry) and
    StringReturnFunctionNameFromNode(Ctx, ANode.ChildAt(1), FuncName) and
    (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
  begin
    Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
    AChanged := True;
  end;
  if ANode.NodeKind = gnkFunctionCall then
  begin
    for J := 1 to ANode.ChildCount - 1 do
    begin
      if CallArgumentOwnsStringReturn(Ctx, 
        ANode, ANode.ChildAt(J), J - 1, FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
      if (SameText(ANode.Text, 'WriteLn') or SameText(ANode.Text, 'Write')) and
        WriteArgumentOwnsStringReturn(Ctx, ANode.ChildAt(J), FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
      if SameText(ANode.Text, 'WriteLn') or SameText(ANode.Text, 'Write') then
        RegisterConcatOwnedStringReturnConsumers(Ctx, ANode.ChildAt(J), AChanged);
    end;
    if LengthArgumentOwnsStringReturn(Ctx, ANode, FuncName) and
      (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
    begin
      Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
      AChanged := True;
    end;
    if (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
      SameText(ANode.ChildAt(0).Text, 'Length') then
      RegisterConcatOwnedStringReturnConsumers(Ctx, ANode.ChildAt(1), AChanged);
    if CopyArgumentOwnsStringReturn(Ctx, ANode, FuncName) and
      (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
    begin
      Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
      AChanged := True;
    end;
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') then
  begin
    for J := 0 to ANode.ChildCount - 1 do
    begin
      if ConcatOperandOwnsStringReturn(Ctx, ANode.ChildAt(J), FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
    end;
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and
    ((ANode.Text = '=') or (ANode.Text = '<>')) then
  begin
    for J := 0 to ANode.ChildCount - 1 do
    begin
      if CompareOperandOwnsStringReturn(Ctx, ANode.ChildAt(J), FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
    end;
  end;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child <> nil) and
      ((Child.NodeKind = gnkProcedureDecl) or
       (Child.NodeKind = gnkFunctionDecl)) then
      Continue;
    ScanOwnedStringReturnConsumers(Ctx, Child, AEntry, AChanged);
  end;
end;

procedure CheckDeferredOwnedStringReturnConsumers(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode);
begin
  if ANode = nil then
    Exit;
  if NodeConsumesOwnedStringReturnDeferred(Ctx, ANode, False) then
  begin
    Ctx.EmitSemaError(Ctx.CallbackCtx, 
      'sema.c6h4-owned-string-return-deferred-consumer',
      'C6-H4: owned string return used in deferred context; ' +
      'assign to a local variable first',
      ANode.ByteOffset);
    Exit;
  end;
end;

procedure PreRegisterOwnedStringReturnConsumers(var Ctx: TSemaOwnershipContext);
var
  I: LongInt;
  Changed: Boolean;
  Entry: TProcedureBodyEntry;
  RootNode: TGreenNode;
  SavedMethodClass, SavedRetVarName: string;
  SavedScopeId: LongInt;
begin
  repeat
    Changed := False;
    if (Ctx.RootAst <> nil) and Ctx.RootAst.IsValid then
    begin
      RootNode := Ctx.RootAst.RootNode;
      if RootNode <> nil then
        ScanTopLevelOwnedStringReturnConsumers(Ctx, RootNode, Changed);
    end;
    for I := 0 to LongInt(Ctx.ProcedureBodies.Count) - 1 do
    begin
      Entry := Ctx.ProcedureBodies[I];
      if (Entry.Body = nil) or (Entry.Decl = nil) or (Pos('<', Entry.Name) > 0) then
        Continue;
      SavedMethodClass := Ctx.CurrentMethodClass;
      SavedRetVarName := Ctx.CurrentRetVarName;
      SavedScopeId := Ctx.CurrentScopeId;
      if Pos('.', Entry.Name) > 0 then
        Ctx.CurrentMethodClass := Copy(Entry.Name, 1, Pos('.', Entry.Name) - 1)
      else
        Ctx.CurrentMethodClass := '';
      Ctx.CurrentRetVarName := Entry.Name;
      if Pos('.', Ctx.CurrentRetVarName) > 0 then
        Ctx.CurrentRetVarName := Copy(Ctx.CurrentRetVarName,
          Pos('.', Ctx.CurrentRetVarName) + 1, Length(Ctx.CurrentRetVarName));
      if Entry.ScopeId > 0 then
        Ctx.CurrentScopeId := Entry.ScopeId;
      try
        ScanOwnedStringReturnConsumers(Ctx, Entry.Body, Entry, Changed);
      finally
        Ctx.CurrentMethodClass := SavedMethodClass;
        Ctx.CurrentRetVarName := SavedRetVarName;
        Ctx.CurrentScopeId := SavedScopeId;
      end;
    end;
  until not Changed;
  { Root-level C6-H4 check removed: procedure body loop below already covers
    all root-unit bodies with OwnerUnitId filtering. The old root-level call
    traversed imported units' code and caused false positives. }
  if not Ctx.Diagnostics.HasErrors then
  begin
    for I := 0 to LongInt(Ctx.ProcedureBodies.Count) - 1 do
    begin
      Entry := Ctx.ProcedureBodies[I];
      if (Entry.Body = nil) or (Entry.Decl = nil) or (Pos('<', Entry.Name) > 0) then
        Continue;
      // Skip C6-H4 check for procedure bodies in external (non-root) units.
      // External units like SysUtils may use owned string returns in safe patterns
      // that the C6-H4 check does not fully support.
      if not SameText(NormalizeUnitIdentity(Entry.OwnerUnitId),
        NormalizeUnitIdentity(Ctx.UnitGraph.RootName)) then
        Continue;
      SavedMethodClass := Ctx.CurrentMethodClass;
      SavedRetVarName := Ctx.CurrentRetVarName;
      SavedScopeId := Ctx.CurrentScopeId;
      if Pos('.', Entry.Name) > 0 then
        Ctx.CurrentMethodClass := Copy(Entry.Name, 1, Pos('.', Entry.Name) - 1)
      else
        Ctx.CurrentMethodClass := '';
      Ctx.CurrentRetVarName := Entry.Name;
      if Pos('.', Ctx.CurrentRetVarName) > 0 then
        Ctx.CurrentRetVarName := Copy(Ctx.CurrentRetVarName,
          Pos('.', Ctx.CurrentRetVarName) + 1, Length(Ctx.CurrentRetVarName));
      if Entry.ScopeId > 0 then
        Ctx.CurrentScopeId := Entry.ScopeId;
      try
        CheckDeferredOwnedStringReturnConsumers(Ctx, Entry.Body);
      finally
        Ctx.CurrentMethodClass := SavedMethodClass;
        Ctx.CurrentRetVarName := SavedRetVarName;
        Ctx.CurrentScopeId := SavedScopeId;
      end;
      if Ctx.Diagnostics.HasErrors then
        Exit;
    end;
  end;
end;

procedure EmitOwnedStringCleanupNodes(const Ctx: TSemaOwnershipContext; const AExceptName: string);
var
  I: LongInt;
  VarName: string;
  OwnedNames: TStringArray;
begin
  OwnedNames := Ctx.RuntimeVars.GetOwnedRuntimeStrVarNames;
  for I := 0 to Length(OwnedNames) - 1 do
  begin
    VarName := OwnedNames[I];
    if (VarName = '') or Ctx.IsBorrowedRuntimeStrVar(Ctx.CallbackCtx, VarName) or
      SameText(VarName, AExceptName) then
      Continue;
    Ctx.Model.AddTypedHirNode(
      'tstring-cleanup-runtime',
      VarName,
      0,
      0,
      VarName
    );
  end;
end;

procedure EmitOwnedDynArrayCleanupNodes(const Ctx: TSemaOwnershipContext);
var
  I: LongInt;
  VarName: string;
  ArrNames: TStringArray;
begin
  ArrNames := Ctx.RuntimeVars.GetRuntimeArrVarNames;
  for I := 0 to Length(ArrNames) - 1 do
  begin
    VarName := ArrNames[I];
    if (VarName = '') or Ctx.IsBorrowedRuntimeArrVar(Ctx.CallbackCtx, VarName) or
      Ctx.IsStaticRuntimeArrVar(Ctx.CallbackCtx, VarName) then
      Continue;
    Ctx.Model.AddTypedHirNode(
      'dynarray-cleanup-runtime',
      VarName,
      0,
      0,
      VarName + #9 + 'int ' + IntToStr(Ctx.DynArrayElemSizeOfVar(Ctx.CallbackCtx, VarName)) + #10
    );
  end;
end;

procedure EmitOwnedManagedRecordCleanupNodes(const Ctx: TSemaOwnershipContext);
var
  I, J: LongInt;
  VarName, TypeName, Blob: string;
  Meta: TTypeMetadata;
  NeedCleanup: Boolean;
  MgrNames: TStringArray;
  MgrTypes: TStringArray;
begin
  MgrNames := Ctx.RuntimeVars.GetManagedRecordVarNames;
  MgrTypes := Ctx.RuntimeVars.GetManagedRecordVarTypes;
  for I := 0 to Length(MgrNames) - 1 do
  begin
    VarName := MgrNames[I];
    TypeName := MgrTypes[I];
    if not Ctx.Model.GetTypeMetaByName(TypeName, Meta) then
      Continue;
    Blob := VarName + #9 + TypeName;
    NeedCleanup := False;
    if Meta.Fields = nil then
      Continue;
    for J := 0 to LongInt(Meta.Fields.Count) - 1 do
    begin
      if Meta.Fields[SizeUInt(J)].IsString then
      begin
        Blob := Blob + #9 + Meta.Fields[SizeUInt(J)].Name + ':s';
        NeedCleanup := True;
      end
      else if Meta.Fields[SizeUInt(J)].IsDynArray then
      begin
        Blob := Blob + #9 + Meta.Fields[SizeUInt(J)].Name + ':d';
        NeedCleanup := True;
      end;
    end;
    if NeedCleanup then
      Ctx.Model.AddTypedHirNode(
        'managed-record-cleanup-runtime',
        VarName,
        0,
        0,
        Blob
      );
  end;
end;
