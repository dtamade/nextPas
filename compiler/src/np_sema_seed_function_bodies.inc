{ Reachable body seed helpers (Batch 9 / Slice C) — TVec-adapted handport. }

procedure TSemanticAnalyzer.MarkClassMethodCohort(const AClassName: string);
var
  K: LongInt;
  Prefix: string;
  PEntry: ^TProcedureBodyEntry;
  CurName, ParentName: string;
  TypeId: LongInt;
  Meta: TTypeMetadata;
  Depth: LongInt;
begin
  { VMT: constructing Class requires sibling methods (GetVal, etc.). }
  if AClassName = '' then
    Exit;
  { 子类 vmt 表引用祖先方法槽(TFileStream.vmt = [TStream.vmt, …]);只标
    记类自身时,祖先方法若无 direct call 缺 define → vmt 表项 undefined
    (TStream 6 方法,B5e method-object 家族)。沿祖先链全部标记。 }
  CurName := AClassName;
  Depth := 0;
  while (CurName <> '') and (Depth < 16) do
  begin
    Prefix := CurName + '.';
    for K := 0 to LongInt(FProcedureBodies.Count) - 1 do
    begin
      { Pointer access: GetItem copies the record (managed fields) twice
        per hit; the table is scanned per cohort over 15k+ bodies. }
      PEntry := FProcedureBodies.GetPtrUnchecked(K);
      if (Length(PEntry^.Name) > Length(Prefix)) and
        SameText(Copy(PEntry^.Name, 1, Length(Prefix)), Prefix) then
        PEntry^.Needed := True;
    end;
    ParentName := '';
    TypeId := FModel.FindTypeByName(CurName);
    if (TypeId > 0) and (TypeId <= FModel.TypeCount) then
    begin
      if FModel.TypeAt(TypeId - 1).ParentTypeId > 0 then
        ParentName := FModel.TypeAt(FModel.TypeAt(TypeId - 1).ParentTypeId - 1).Name
      else if FModel.GetTypeMeta(TypeId, Meta) and (Meta.ParentClassName <> '') then
        ParentName := Meta.ParentClassName;
    end;
    if (ParentName = '') or SameText(ParentName, CurName) then
      Break;
    CurName := ParentName;
    Inc(Depth);
  end;
end;

procedure TSemanticAnalyzer.MarkProcedureBodyNeededByName(const AName: string);
var
  Bare, LClassName, LMethodName, Resolved: string;
  Index, DotPos, J: LongInt;
begin
  { Exact mark via name walk. Cohort only for Create/Destroy. }
  if AName = '' then
    Exit;
  Bare := AName;
  if Pos('$', Bare) > 0 then
    Bare := Copy(Bare, 1, Pos('$', Bare) - 1);
  if Bare = '' then
    Exit;
  Index := FirstBodyIndexForNameLocal(Bare);
  while Index >= 0 do
  begin
    FProcedureBodies.GetPtrUnchecked(Index)^.Needed := True;
    Index := NextBodyIndexForNameLocal(Index);
  end;
  if not SameText(Bare, AName) then
  begin
    Index := FirstBodyIndexForNameLocal(AName);
    while Index >= 0 do
    begin
      FProcedureBodies.GetPtrUnchecked(Index)^.Needed := True;
      Index := NextBodyIndexForNameLocal(Index);
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
    { Empty subclass / alias: follow declaration-time $resolve_ only.
      Do not walk ancestors here — Resolve+cohort fixed-point explodes seed. }
    if FModel.LookupStringConstValue(LClassName + '.$resolve_' + LMethodName,
      Resolved) and (Resolved <> '') and (not SameText(Resolved, Bare)) then
      MarkProcedureBodyNeededByName(Resolved)
    else if SameText(LMethodName, 'CreateFmt') and
      FModel.LookupStringConstValue(LClassName + '.$resolve_Create', Resolved) and
      (Resolved <> '') then
      MarkProcedureBodyNeededByName(Resolved);
  end;
end;

procedure TSemanticAnalyzer.MarkBodiesFromTypedHirCalls;
var
  I, LineStart, LineEnd, NameStart, NameEnd, TabPos: LongInt;
  Node: TTypedHirNode;
  Target, Operand, Rest: string;
begin
  for I := 0 to FModel.TypedHirNodeCount - 1 do
  begin
    Node := FModel.TypedHirNodeAt(I);
    case Node.NodeKind of
      hnkClassNewRuntime:
        begin
          { Operand = VarName #9 Type.Ctor [#9 args...]; DisplayName is size. }
          Operand := Node.Operand;
          TabPos := Pos(#9, Operand);
          if TabPos > 0 then
          begin
            Rest := Copy(Operand, TabPos + 1, MaxInt);
            TabPos := Pos(#9, Rest);
            if TabPos > 0 then
              Target := Copy(Rest, 1, TabPos - 1)
            else
              Target := Rest;
            if (Target <> '') and (Target[1] <> '.') and (Target[1] <> '_') then
              MarkProcedureBodyNeededByName(Target);
          end;
        end;
      hnkCallRuntime, hnkHaltCallRuntime, hnkHaltCall,
      hnkAssignTStringCallRuntime,
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
    { Expression-position calls are embedded as "call Name N" lines inside
      assign/return operand blobs — not standalone call-runtime nodes. }
    Operand := Node.Operand;
    if Operand = '' then
      Continue;
    LineStart := 1;
    while LineStart <= Length(Operand) do
    begin
      LineEnd := LineStart;
      while (LineEnd <= Length(Operand)) and (Operand[LineEnd] <> #10) and
        (Operand[LineEnd] <> #9) do
        Inc(LineEnd);
      if (LineEnd - LineStart >= 6) and
        (Copy(Operand, LineStart, 5) = 'call ') then
      begin
        NameStart := LineStart + 5;
        NameEnd := NameStart;
        while (NameEnd <= LineEnd - 1) and (Operand[NameEnd] <> ' ') do
          Inc(NameEnd);
        if NameEnd > NameStart then
        begin
          Target := Copy(Operand, NameStart, NameEnd - NameStart);
          if (Target <> '') and (Target[1] <> '_') and
            (not SameText(Target, 'Halt')) then
            MarkProcedureBodyNeededByName(Target);
        end;
      end;
      if LineEnd > Length(Operand) then
        Break;
      LineStart := LineEnd + 1;
    end;
  end;
end;

{ 接口实现方法可达性:imt 常量(thunk)静态调 实现类.方法,而接口调用点
  (ivcall) 只经 slot/thunk,可达性收集看不到实现类方法 — thunk 引用悬空
  (opt: use of undefined value '@TImpl.Foo1')。只 mark root 单元的实现类:
  导入单元全量 seed 会爆泛型/克隆家族,留待专用口。 }
procedure TSemanticAnalyzer.MarkInterfaceImplementorMethods(
  const ARootOwnerUnitId: string);
var
  I, J, K: LongInt;
  T: TSemanticType;
  Meta, IntfMeta: TTypeMetadata;
begin
  for I := 0 to FModel.TypeCount - 1 do
  begin
    T := FModel.TypeAt(I);
    if (T.Name = '') or (not SameText(T.Kind, 'declared')) then
      Continue;
    if (ARootOwnerUnitId <> '') and
      (not SameText(T.OwnerUnitId, ARootOwnerUnitId)) then
      Continue;
    if not FModel.GetTypeMeta(T.TypeId, Meta) then
      Continue;
    if (Meta.InterfaceSlots = nil) or (Meta.InterfaceSlots.Count = 0) then
      Continue;
    for J := 0 to LongInt(Meta.InterfaceSlots.Count) - 1 do
    begin
      if not FModel.GetTypeMetaByName(
        Meta.InterfaceSlots[SizeUInt(J)].InterfaceName, IntfMeta) then
        Continue;
      if (IntfMeta.VmtSlots = nil) or (IntfMeta.VmtCount <= 0) then
        Continue;
      for K := 0 to IntfMeta.VmtCount - 1 do
        if K < LongInt(IntfMeta.VmtSlots.Count) then
          MarkProcedureBodyNeededByName(
            T.Name + '.' + IntfMeta.VmtSlots[SizeUInt(K)].MethodName);
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
  PEntry: ^TProcedureBodyEntry;

  procedure EnqueueBody(const AIndex: LongInt);
  begin
    if (AIndex < 0) or (AIndex >= LongInt(FProcedureBodies.Count)) then
      Exit;
    PEntry := FProcedureBodies.GetPtrUnchecked(AIndex);
    if not PEntry^.Needed then
      Exit;
    if Visited[AIndex] then
      Exit;
    Visited[AIndex] := True;
    if PEntry^.Body = nil then
      Exit;
    { Always enqueue Needed bodies. Flood-prone units (simd/math/crypto) expand
      via WalkGreenForCallTargets only (see WalkBodyForReachability) — never the
      full identifier walk — so helper callees like CreateDispatchPublishedState
      get Needed without re-fanning field/global names into the body table. }
    if QTail >= Length(Queue) then
      SetLength(Queue, QTail + 128);
    Queue[QTail] := AIndex;
    Inc(QTail);
  end;

  procedure MarkIndex(const AIndex: LongInt);
  begin
    if (AIndex < 0) or (AIndex >= LongInt(FProcedureBodies.Count)) then
      Exit;
    FProcedureBodies.GetPtrUnchecked(AIndex)^.Needed := True;
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
    Index := FirstBodyIndexForNameLocal(Bare);
    while Index >= 0 do
    begin
      MarkIndex(Index);
      Index := NextBodyIndexForNameLocal(Index);
    end;
    if not SameText(Bare, AName) then
    begin
      Index := FirstBodyIndexForNameLocal(AName);
      while Index >= 0 do
      begin
        MarkIndex(Index);
        Index := NextBodyIndexForNameLocal(Index);
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
    if ANode.TextLen <> 0 then
    begin
      { Bare `Foo;` is gnkProcedureCallStatement with Text=Foo and no children.
        Unit-init reachability must mark those or np_unit_init_* emits
        call @Foo with no define (DetectSHA1Features / InitSHA256Dispatch). }
      if (ANode.NodeKind = gnkIdentifier) or
        (ANode.NodeKind = gnkProcedureDecl) or
        (ANode.NodeKind = gnkFunctionDecl) or
        (ANode.NodeKind = gnkDotAccess) or
        (ANode.NodeKind = gnkProcedureCallStatement) or
        (ANode.NodeKind = gnkFunctionCall) then
        MarkNameAndEnqueue(ANode.Text);
    end;
    if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) then
    begin
      C0 := ANode.ChildAt(0);
      C1 := ANode.ChildAt(1);
      if (C0 <> nil) and (C1 <> nil) and (C0.TextLen <> 0) and (C1.TextLen <> 0) then
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

  { Method-body walk: only real call targets. Full identifier walk on Create
    re-fans field/param names into Needed; free helpers still get marked when
    they appear as gnkFunctionCall callees.
    Also: bare identifiers that resolve to a registered procedure body
    (ObjFPC allows `X := Foo;` without () for zero-arg functions) — without
    this, simd CallTargets-only expand leaves CreateDispatchPublishedState
    undefined while PublishBackendDispatchTable is encoded. }
  procedure WalkGreenForCallTargets(const ANode: TGreenNode);
  var
    ChildIdx: LongInt;
    Child, Callee, C0, C1: TGreenNode;
    Qual: string;
  begin
    if ANode = nil then
      Exit;
    if ANode.NodeKind = gnkFunctionCall then
    begin
      if ANode.TextLen <> 0 then
        MarkNameAndEnqueue(ANode.Text);
      Callee := nil;
      if ANode.ChildCount >= 1 then
        Callee := ANode.ChildAt(0);
      if Callee <> nil then
      begin
        if (Callee.NodeKind = gnkIdentifier) and (Callee.TextLen <> 0) then
          MarkNameAndEnqueue(Callee.Text)
        else if (Callee.NodeKind = gnkDotAccess) and (Callee.ChildCount >= 2) then
        begin
          C0 := Callee.ChildAt(0);
          C1 := Callee.ChildAt(1);
          if (C0 <> nil) and (C1 <> nil) and (C0.TextLen <> 0) and
            (C1.TextLen <> 0) then
          begin
            Qual := C0.Text + '.' + C1.Text;
            MarkNameAndEnqueue(Qual);
            MarkNameAndEnqueue(C1.Text);
          end;
        end;
      end;
    end
    else if ANode.NodeKind = gnkProcedureCallStatement then
    begin
      { Bare procedure statement: Text holds callee; optional child0 is
        expression-form callee (DotAccess / FunctionCall). Args are children. }
      if ANode.TextLen <> 0 then
        MarkNameAndEnqueue(ANode.Text);
      Callee := nil;
      if ANode.ChildCount >= 1 then
        Callee := ANode.ChildAt(0);
      if Callee <> nil then
      begin
        if (Callee.NodeKind = gnkIdentifier) and (Callee.TextLen <> 0) then
          MarkNameAndEnqueue(Callee.Text)
        else if (Callee.NodeKind = gnkDotAccess) and (Callee.ChildCount >= 2) then
        begin
          C0 := Callee.ChildAt(0);
          C1 := Callee.ChildAt(1);
          if (C0 <> nil) and (C1 <> nil) and (C0.TextLen <> 0) and
            (C1.TextLen <> 0) then
          begin
            Qual := C0.Text + '.' + C1.Text;
            MarkNameAndEnqueue(Qual);
            MarkNameAndEnqueue(C1.Text);
          end;
        end
        else if (Callee.NodeKind = gnkFunctionCall) and (Callee.TextLen <> 0) then
          MarkNameAndEnqueue(Callee.Text);
      end;
    end
    else if (ANode.NodeKind = gnkIdentifier) and (ANode.TextLen <> 0) and
      (FirstBodyIndexForNameLocal(ANode.Text) >= 0) then
      MarkNameAndEnqueue(ANode.Text);
    for ChildIdx := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(ChildIdx);
      if Child <> nil then
        WalkGreenForCallTargets(Child);
    end;
  end;

  function OwnerIsFloodProne(const AOwnerUnitId: string): Boolean;
  var
    Own: string;
  begin
    Own := LowerCase(AOwnerUnitId);
    Result := (Pos('simd', Own) > 0) or (Pos('nextpas.core.math', Own) > 0) or
      (Pos('nextpas.core.crypto', Own) > 0);
  end;

  procedure WalkBodyForReachability(const AIndex: LongInt);
  begin
    if (AIndex < 0) or (AIndex >= LongInt(FProcedureBodies.Count)) then
      Exit;
    if FProcedureBodies[AIndex].Body = nil then
      Exit;
    { Methods + flood-prone free-function units: strict call-target walk only.
      Full identifier walk on those re-fans fields/globals into Needed and
      historically forced a hard no-expand Exit (which left callees undefined). }
    if (Pos('.', FProcedureBodies[AIndex].Name) > 0) or
      OwnerIsFloodProne(FProcedureBodies[AIndex].OwnerUnitId) then
      WalkGreenForCallTargets(FProcedureBodies[AIndex].Body)
    else
      WalkGreenForCallNames(FProcedureBodies[AIndex].Body);
  end;

begin
  SemaTrace('CollectReachableBodyRoots...');
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
    PEntry := FProcedureBodies.GetPtrUnchecked(I);
    if (RootId <> '') and SameText(PEntry^.OwnerUnitId, RootId) then
      PEntry^.Needed := True;
    if SameText(PEntry^.Name, 'ParamCount') or
      SameText(PEntry^.Name, 'ParamStr') or
      { L3 residual: method WalkGreenForCallTargets misses some free helpers
        (ChangeFileExt$ss / ResolveExecutablePath$sis /
        CompilerCreateUnitAllocator). Force-seed until the callee-token mark
        path is complete. }
      SameText(PEntry^.Name, 'ChangeFileExt') or
      SameText(PEntry^.Name, 'ResolveExecutablePath') or
      SameText(PEntry^.Name, 'CompilerCreateUnitAllocator') then
      PEntry^.Needed := True;
  end;
  MarkNameAndEnqueue('TObject.Create');
  MarkNameAndEnqueue('TObject.Destroy');
  MarkNameAndEnqueue('TInterfacedObject.Create');
  MarkNameAndEnqueue('TInterfacedObject._AddRef');
  MarkNameAndEnqueue('TInterfacedObject._Release');
  MarkNameAndEnqueue('Exception.Create');
  MarkNameAndEnqueue('Exception.Destroy');

  MarkInterfaceImplementorMethods(RootId);

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
    WalkBodyForReachability(I);
  end;
  MarkBodiesFromTypedHirCalls;
  for I := 0 to LongInt(FProcedureBodies.Count) - 1 do
    if FProcedureBodies[I].Needed and (not Visited[I]) then
      EnqueueBody(I);
  while QHead < QTail do
  begin
    I := Queue[QHead];
    Inc(QHead);
    WalkBodyForReachability(I);
  end;

  NeededCount := 0;
  for I := 0 to LongInt(FProcedureBodies.Count) - 1 do
    if FProcedureBodies[I].Needed then
      Inc(NeededCount);
  WriteLn(StdErr, '[sema] CollectReachableBodyRoots done needed=', NeededCount,
    ' registered=', LongInt(FProcedureBodies.Count));
  Flush(StdErr);
  SemaTrace('CollectReachableBodyRoots done needed=' + IntToStr(NeededCount) +
    ' registered=' + IntToStr(LongInt(FProcedureBodies.Count)));
end;

procedure TSemanticAnalyzer.SeedFunctionBodies;
var
  I, J, K: LongInt;
  Entry: TProcedureBodyEntry;
  PEntry: ^TProcedureBodyEntry;
  ParamCount: LongInt;
  Child, ParamChild, TypeChild, Decl, ArrayTypeNode: TGreenNode;
  SavedTerminated: Boolean;
  ParamTypes, RetVarName, EffName, ArrOperand: string;
  IsStrParam, IsStrReturn, IsPtrReturn, IsVarP, IsRecReturn, IsArrReturn: Boolean;
  OwnedStringReturn: Boolean;
  PtrReturnClass: string;
  Folded, Value: Int64;
  NodeId, WorkHead: LongInt;
  NeededCount, EncodedCount: LongInt;
  OuterFrame, WalkDecl: TGreenNode;
  InstName: string;

  { Nested local bodies capture outer params/locals (CopyChunk→ABuf). Without
    outer-frame registration, encode residual becomes call @ABuf() and opt
    fails. Freestanding LLVM still uses zeroed local allocas (no static link). }
  function FindOuterDeclOf(const ANested: TGreenNode): TGreenNode;
  var
    BI: LongInt;
    Cand: TGreenNode;
  begin
    Result := nil;
    if ANested = nil then
      Exit;
    for BI := 0 to LongInt(FProcedureBodies.Count) - 1 do
    begin
      { In-place entry access: indexing copies the whole managed record. }
      Cand := FProcedureBodies.GetPtrUnchecked(BI)^.Decl;
      if Cand = nil then
        Continue;
      if Cand.ChildIndexOf(ANested) >= 0 then
        Exit(Cand);
    end;
  end;

  procedure RegisterOneOuterFrame(const AOuter: TGreenNode;
    const AOwnerUnitId: string);
  var
    OJ, OK: LongInt;
    OChild, OParam, OType, OVar: TGreenNode;
    OName: string;
    OIsVarP: Boolean;
  begin
    if AOuter = nil then
      Exit;
    for OJ := 0 to AOuter.ChildCount - 1 do
    begin
      OChild := AOuter.ChildAt(OJ);
      if OChild = nil then
        Continue;
      if OChild.NodeKind = gnkParameterList then
      begin
        for OK := 0 to OChild.ChildCount - 1 do
        begin
          OParam := OChild.ChildAt(OK);
          if (OParam = nil) or (OParam.NodeKind <> gnkParameterDecl) then
            Continue;
          OName := OParam.Text;
          OIsVarP := ParamNameIsByRef(OName);
          OName := StripParamModifier(OName);
          if (OName = '') or IsRuntimeVar(OName) then
            Continue;
          RegisterRuntimeVar(OName);
          if OIsVarP then
            RegisterVarParam(OName);
          OType := nil;
          if OParam.ChildCount > 0 then
            OType := OParam.ChildAt(0);
          if (OType <> nil) and
            (OType.TextEquals('String', True) or
             OType.TextEquals('AnsiString', True)) then
          begin
            RegisterRuntimeStrVar(OName);
            RegisterBorrowedRuntimeStrVar(OName);
            FModel.AddTypedHirNode('var-decl-tstring-runtime', OName, 0, 0,
              OName);
          end
          else if (OType <> nil) and
            ((OType.NodeKind = gnkArrayType) or
             TypeMetaIsDynArrayType(OType.Text)) then
          begin
            RegisterRuntimeArrVar(OName);
            RegisterBorrowedRuntimeArrVar(OName);
            FModel.AddTypedHirNode('var-decl-arr-borrowed-runtime', OName,
              0, 0, OName);
          end
          else if (OType <> nil) and
            (((Length(OType.Text) > 1) and (OType.Text[1] = '^')) or
             TypeMetaIsPointer(OType.Text) or
             TypeMetaIsClass(OType.Text)) then
          begin
            { 嵌套捕获的 class 参数必须用真实类型名注册 (与普通参数注册
              RegisterClassVar(RetVarName, TypeChild.Text) 一致), 否则
              ALexer.TokenCount 编码成 @Pointer.TokenCount 未定义。 }
            if TypeMetaIsClass(OType.Text) then
              RegisterClassVar(OName, OType.Text)
            else
              RegisterClassVar(OName, 'Pointer');
            if (Length(OType.Text) > 1) and (OType.Text[1] = '^') then
              RegisterPointerVar(OName, Copy(OType.Text, 2, MaxInt))
            else if not TypeMetaIsClass(OType.Text) then
              RegisterPointerVar(OName, OType.Text);
            FModel.AddTypedHirNode('var-decl-ptr-runtime', OName, 0, 0, OName);
          end
          else if OIsVarP then
            FModel.AddTypedHirNode('var-decl-varref-runtime', OName, 0, 0, OName)
          else
            FModel.AddTypedHirNode('var-decl-runtime', OName, 0, 0, OName);
        end;
      end
      else if OChild.NodeKind = gnkConstSection then
        ProcessConstSection(OChild, AOwnerUnitId)
      else if OChild.NodeKind = gnkVarSection then
      begin
        for OK := 0 to OChild.ChildCount - 1 do
        begin
          OVar := OChild.ChildAt(OK);
          if (OVar = nil) or (OVar.NodeKind <> gnkVarDecl) or
            (OVar.TextLen = 0) or IsRuntimeVar(OVar.Text) then
            Continue;
          RegisterRuntimeVar(OVar.Text);
          OType := nil;
          if OVar.ChildCount > 0 then
            OType := OVar.ChildAt(0);
          if (OType <> nil) and
            (OType.TextEquals('String', True) or
             OType.TextEquals('AnsiString', True)) then
          begin
            RegisterRuntimeStrVar(OVar.Text);
            FModel.AddTypedHirNode('var-decl-tstring-runtime', OVar.Text,
              0, 0, OVar.Text);
          end
          else if (OType <> nil) and
            (((Length(OType.Text) > 1) and (OType.Text[1] = '^')) or
             TypeMetaIsPointer(OType.Text) or
             TypeMetaIsClass(OType.Text)) then
          begin
            if TypeMetaIsClass(OType.Text) then
              RegisterClassVar(OVar.Text, OType.Text)
            else
              RegisterClassVar(OVar.Text, 'Pointer');
            FModel.AddTypedHirNode('var-decl-ptr-runtime', OVar.Text, 0, 0,
              OVar.Text);
          end
          else
            FModel.AddTypedHirNode('var-decl-runtime', OVar.Text, 0, 0,
              OVar.Text);
        end;
      end;
    end;
  end;

  procedure RegisterOuterFrameCapturesFor(const ANestedDecl: TGreenNode;
    const AOwnerUnitId: string);
  var
    FrameDepth: LongInt;
  begin
    WalkDecl := ANestedDecl;
    for FrameDepth := 0 to 7 do
    begin
      OuterFrame := FindOuterDeclOf(WalkDecl);
      if OuterFrame = nil then
        Break;
      RegisterOneOuterFrame(OuterFrame, AOwnerUnitId);
      WalkDecl := OuterFrame;
    end;
  end;

  { Fresh scalar locals/params (Int32/SizeUInt/…) are register-passed ints,
    not class refs. Without this, TypeMetaSize>0 pushed them into
    RegisterClassVar / 'p' ptr slots (aShift of ScalarArrayShrI32 became a
    ptr formal → load-ptr ABI chaos at the SarLongint call site). 8-bit
    scalars (Char/Byte/Boolean) stay on the old ptr-slot path: Char formals
    conventionally receive the character slot address (IsSep(C: Char)
    callers pass P[I] element addresses), so flipping them would break those
    call sites. }
  function ParamTypeIsScalarCode(const ATypeName: string): Boolean;
  var
    TypeIdTmp: LongInt;
    FactTmp: TSemanticScalarTypeFact;
  begin
    Result := False;
    if ATypeName = '' then
      Exit;
    TypeIdTmp := FModel.FindTypeByName(ATypeName);
    if TypeIdTmp > 0 then
      Result := FModel.GetTypeScalarFact(TypeIdTmp, FactTmp) and
        (FactTmp.Kind in [sskBool, sskInt, sskFloat]) and
        (FactTmp.BitWidth >= 16);
  end;

  { Mid-seed callee discovery: TypedHir "call Name" scan misses structured
    shekCall expr operands. Walk green call targets of every Needed body so
    helpers like CreateDispatchPublishedState become Needed after their caller
    is first marked mid-encode. }
  procedure MarkCallTargetsInGreen(const ANode: TGreenNode);
  var
    ChildIdx: LongInt;
    Child, Callee, C0, C1: TGreenNode;
    Qual: string;
  begin
    if ANode = nil then
      Exit;
    if ANode.NodeKind = gnkFunctionCall then
    begin
      if ANode.TextLen <> 0 then
        MarkProcedureBodyNeededByName(ANode.Text);
      Callee := nil;
      if ANode.ChildCount >= 1 then
        Callee := ANode.ChildAt(0);
      if Callee <> nil then
      begin
        if (Callee.NodeKind = gnkIdentifier) and (Callee.TextLen <> 0) then
          MarkProcedureBodyNeededByName(Callee.Text)
        else if (Callee.NodeKind = gnkDotAccess) and (Callee.ChildCount >= 2) then
        begin
          C0 := Callee.ChildAt(0);
          C1 := Callee.ChildAt(1);
          if (C0 <> nil) and (C1 <> nil) and (C0.TextLen <> 0) and
            (C1.TextLen <> 0) then
          begin
            Qual := C0.Text + '.' + C1.Text;
            MarkProcedureBodyNeededByName(Qual);
            MarkProcedureBodyNeededByName(C1.Text);
          end;
        end;
      end;
    end
    else if ANode.NodeKind = gnkProcedureCallStatement then
    begin
      if ANode.TextLen <> 0 then
        MarkProcedureBodyNeededByName(ANode.Text);
      Callee := nil;
      if ANode.ChildCount >= 1 then
        Callee := ANode.ChildAt(0);
      if Callee <> nil then
      begin
        if (Callee.NodeKind = gnkIdentifier) and (Callee.TextLen <> 0) then
          MarkProcedureBodyNeededByName(Callee.Text)
        else if (Callee.NodeKind = gnkDotAccess) and (Callee.ChildCount >= 2) then
        begin
          C0 := Callee.ChildAt(0);
          C1 := Callee.ChildAt(1);
          if (C0 <> nil) and (C1 <> nil) and (C0.TextLen <> 0) and
            (C1.TextLen <> 0) then
          begin
            Qual := C0.Text + '.' + C1.Text;
            MarkProcedureBodyNeededByName(Qual);
            MarkProcedureBodyNeededByName(C1.Text);
          end;
        end
        else if (Callee.NodeKind = gnkFunctionCall) and (Callee.TextLen <> 0) then
          MarkProcedureBodyNeededByName(Callee.Text);
      end;
    end
    else if (ANode.NodeKind = gnkIdentifier) and (ANode.TextLen <> 0) and
      (FirstBodyIndexForNameLocal(ANode.Text) >= 0) then
      MarkProcedureBodyNeededByName(ANode.Text);
    for ChildIdx := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(ChildIdx);
      if Child <> nil then
        MarkCallTargetsInGreen(Child);
    end;
  end;

  procedure ExpandNeededBodiesCallTargets;
  var
    BI: LongInt;
  begin
    for BI := 0 to LongInt(FProcedureBodies.Count) - 1 do
      if FProcedureBodies[BI].Needed and (FProcedureBodies[BI].Body <> nil) then
        MarkCallTargetsInGreen(FProcedureBodies[BI].Body);
  end;

begin
  FSeedingBodiesActive := True;
  try
    PhaseBegin('seed.reach');
    try
      CollectReachableBodyRoots;
    finally
      PhaseEnd('seed.reach');
    end;
    FGenericWorkQueue.Clear;
    FGenericWorkQueue.EnsureCapacity(LongInt(FProcedureBodies.Count) + 64);
    WorkHead := 0;
    EncodedCount := 0;
    SemaTrace('SeedFunctionBodies encode start...');
    { Fixed-point: mid-seed RegisterProcedureBody may add/refresh Needed bodies.
      Only enqueue Needed and not yet Encoded (reachability budget).
      Queued flag replaces O(n) membership scan of FGenericWorkQueue. }
    while True do
    begin
      PhaseBegin('seed.plan');
      try
        MarkBodiesFromTypedHirCalls;
        ExpandNeededBodiesCallTargets;
      finally
        PhaseEnd('seed.plan');
      end;
      for I := 0 to LongInt(FProcedureBodies.Count) - 1 do
      begin
        PEntry := FProcedureBodies.GetPtrUnchecked(I);
        if PEntry^.Body = nil then
          Continue;
        if not PEntry^.Needed then
          Continue;
        if PEntry^.Encoded then
          Continue;
        if PEntry^.Queued then
          Continue;
        PEntry^.Queued := True;
        FGenericWorkQueue.Push(I);
      end;
      if WorkHead >= LongInt(FGenericWorkQueue.Count) then
        Break;

    PhaseBegin('seed.encode');
    try
      while WorkHead < LongInt(FGenericWorkQueue.Count) do
      begin
    I := FGenericWorkQueue[WorkHead];
    Inc(WorkHead);
    if (WorkHead mod 50 = 0) or (WorkHead = 1) then
      SemaTrace('SeedFunctionBodies progress head=' + IntToStr(WorkHead) +
        '/' + IntToStr(LongInt(FGenericWorkQueue.Count)));
    if I < 0 then Continue;
    Entry := FProcedureBodies[I];
    if (Entry.Body = nil) or (Entry.Decl = nil) then
    begin
      FProcedureBodies.GetPtrUnchecked(I)^.Encoded := True;
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
    IsArrReturn := False;
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
              RetVarName := StripParamModifier(RetVarName);
              RegisterRuntimeVar(RetVarName);
              if IsVarP then
                RegisterVarParam(RetVarName);
              IsStrParam := False;
              if ParamChild.ChildCount > 0 then
              begin
                TypeChild := ParamChild.ChildAt(0);
                if (TypeChild <> nil) and
                  (TypeChild.TextEquals('String', True) or
                   TypeChild.TextEquals('AnsiString', True)) then
                begin
                  IsStrParam := True;
                  RegisterRuntimeStrVar(RetVarName);
                  RegisterBorrowedRuntimeStrVar(RetVarName);
                end
                else if (TypeChild <> nil) and
                  ((TypeChild.NodeKind = gnkArrayType) or
                   ((TypeChild.TextLen = 0) and (K + 1 < Child.ChildCount) and
                    (Child.ChildAt(K + 1) <> nil) and
                    (Child.ChildAt(K + 1).NodeKind = gnkArrayType)) or
                   ((TypeChild.NodeKind = gnkIdentifier) and
                    TypeMetaIsDynArrayType(TypeChild.Text))) then
                begin
                  RegisterRuntimeArrVar(RetVarName);
                  RegisterBorrowedRuntimeArrVar(RetVarName);
                  if (TypeChild.NodeKind = gnkIdentifier) and
                    FModel.LookupConstValue(TypeChild.Text + '$arr_elem_size',
                      Folded) then
                    FModel.AddConstValue(RetVarName + '$arr_elem_size', Folded);
                  if (TypeChild.NodeKind = gnkIdentifier) and
                    FModel.LookupStringConstValue(
                      TypeChild.Text + '$arr_elem_type', PtrReturnClass) then
                    FModel.AddStringConstValue(RetVarName + '$arr_elem_type',
                      PtrReturnClass);
                end
                else if (TypeChild <> nil) and
                  (Length(TypeChild.Text) > 1) and (TypeChild.Text[1] = '^') then
                begin
                  RegisterClassVar(RetVarName, 'Pointer');
                  RegisterPointerVar(RetVarName, Copy(TypeChild.Text, 2,
                    Length(TypeChild.Text)));
                end
                else if (TypeChild <> nil) and
                  TypeMetaIsPointer(TypeChild.Text) then
                begin
                  RegisterClassVar(RetVarName, 'Pointer');
                  RegisterPointerVar(RetVarName, TypeChild.Text);
                end
                else if (TypeChild <> nil) and
                  (TypeMetaIsInterface(TypeChild.Text) or
                   TypeMetaIsClass(TypeChild.Text)) then
                  RegisterClassVar(RetVarName, TypeChild.Text)
                else if (TypeChild <> nil) and
                  (TypeMetaSize(TypeChild.Text) > 0) then
                begin
                  if TypeMetaIsRecord(TypeChild.Text) then
                    RegisterRecordVar(RetVarName, TypeChild.Text)
                  else if (not TypeMetaIsInterface(TypeChild.Text)) and
                    (not ParamTypeIsScalarCode(TypeChild.Text)) then
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
                TypeMetaIsPointer(ParamChild.ChildAt(0).Text) then
                ParamTypes := ParamTypes + 'p'
              else if (ParamChild.ChildCount > 0) and
                (ParamChild.ChildAt(0) <> nil) and
                (TypeMetaSize(ParamChild.ChildAt(0).Text) > 0) then
              begin
                if TypeMetaIsRecord(ParamChild.ChildAt(0).Text) then
                  ParamTypes := ParamTypes + 'r'
                else if IsVarP then
                  ParamTypes := ParamTypes + 'v'
                else if ParamTypeIsScalarCode(ParamChild.ChildAt(0).Text) then
                  ParamTypes := ParamTypes + 'i'
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
          (Child.TextEquals('String', True) or
           Child.TextEquals('AnsiString', True)) then
          IsStrReturn := True
        else if (Child.NodeKind = gnkIdentifier) and
          (Child.NodeKind <> gnkBeginBlock) and
          ((Length(Child.Text) > 1) and (Child.Text[1] = '^')) then
        begin
          IsPtrReturn := True;
          PtrReturnClass := 'Pointer';
        end
        else if (Child.NodeKind = gnkIdentifier) and
          (Child.NodeKind <> gnkBeginBlock) and
          TypeMetaIsDynArrayType(Child.Text) then
        begin
          { Before class/pointer: dynarray Size=8 used to look like a class. }
          IsArrReturn := True;
          PtrReturnClass := Child.Text;
        end
        else if (Child.NodeKind = gnkIdentifier) and
          (Child.NodeKind <> gnkBeginBlock) and
          TypeMetaIsPointer(Child.Text) then
        begin
          IsPtrReturn := True;
          PtrReturnClass := Child.Text;
        end
        else if (Child.NodeKind = gnkIdentifier) and
          (Child.NodeKind <> gnkBeginBlock) and
          (TypeMetaIsInterface(Child.Text) or TypeMetaIsClass(Child.Text)) then
        begin
          { IHasher / IChild returns are interface refs (ptr), not records. }
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
      (IsOwnedStringReturnFunc(EffName) or IsOwnedStringReturnFunc(Entry.Name));
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
    else
    begin
      { Nested local of a method (AttachArray… inside WalkHaltCalls): bare
        Entry.Name has no Class. prefix, so FCurrentMethodClass would stay empty
        and bare BuildTargetAddressExpr residual-calls @Name instead of
        Class.Name(self,…). Walk outer decls until a method body is found. }
      FCurrentMethodClass := '';
      WalkDecl := Entry.Decl;
      while WalkDecl <> nil do
      begin
        OuterFrame := FindOuterDeclOf(WalkDecl);
        if OuterFrame = nil then
          Break;
        for J := 0 to LongInt(FProcedureBodies.Count) - 1 do
          if FProcedureBodies[J].Decl = OuterFrame then
          begin
            if Pos('.', FProcedureBodies[J].Name) > 0 then
            begin
              FCurrentMethodClass := Copy(FProcedureBodies[J].Name, 1,
                Pos('.', FProcedureBodies[J].Name) - 1);
              RegisterRuntimeVar('self');
            end;
            Break;
          end;
        if FCurrentMethodClass <> '' then
          Break;
        WalkDecl := OuterFrame;
      end;
      if IsStrReturn and OwnedStringReturn then
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
      else if IsArrReturn then
        FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
          IntToStr(ParamCount) + ':' + ParamTypes + ':a')
      else
        FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
          IntToStr(ParamCount) + ':' + ParamTypes);
    end;
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
                { Operand must be the clean name: HIR registers the parameter
                  alloca under AOperand, and encode references it by bare name.
                  'constref:a' here made FindAlloca('a') miss -> residual call
                  @a() in simd_cmpneq_pd(a, b: TM128). }
                FModel.AddTypedHirNode('var-decl-runtime', RetVarName,
                  0, 0, RetVarName);
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
    if IsPtrReturn and (PtrReturnClass <> '') then
      RegisterClassVar(RetVarName, PtrReturnClass);
    if IsArrReturn then
    begin
      RegisterRuntimeArrVar(RetVarName);
      if (PtrReturnClass <> '') and
        FModel.LookupConstValue(PtrReturnClass + '$arr_elem_size', Folded) then
        FModel.AddConstValue(RetVarName + '$arr_elem_size', Folded);
      if (PtrReturnClass <> '') and
        FModel.LookupStringConstValue(PtrReturnClass + '$arr_elem_type',
          ArrOperand) then
        FModel.AddStringConstValue(RetVarName + '$arr_elem_type', ArrOperand);
    end;
    if IsStrReturn and OwnedStringReturn then
      FModel.AddTypedHirNode('var-decl-tstring-runtime', RetVarName, 0, 0,
        RetVarName)
    else if IsStrReturn then
      FModel.AddTypedHirNode('var-decl-tstring-runtime', RetVarName, 0, 0, RetVarName)
    else if IsPtrReturn then
      FModel.AddTypedHirNode('var-decl-ptr-runtime', RetVarName, 0, 0, RetVarName)
    else if IsRecReturn then
      FModel.AddTypedHirNode('var-decl-ptr-runtime', RetVarName, 0, 0, RetVarName)
    else if IsArrReturn then
      FModel.AddTypedHirNode('var-decl-arr-runtime', RetVarName, 0, 0, RetVarName)
    else
      FModel.AddTypedHirNode('var-decl-runtime', RetVarName, 0, 0, RetVarName);
    if Entry.Decl <> nil then
      for J := 0 to Entry.Decl.ChildCount - 1 do
      begin
        Child := Entry.Decl.ChildAt(J);
        { Local const (BUF_SIZE = 1024 inside FsReadlink): unit-level ProcessConst
          never sees these. Without AddConstValue, encode/EmitExprVar residual
          call @BUF_SIZE(). Typed const arrays (AbsMask) also need arr runtime
          decl + RegisterRuntimeVar so @Name encodes to Name$ptr, not funcref. }
        if (Child <> nil) and (Child.NodeKind = gnkConstSection) then
        begin
          ProcessConstSection(Child, Entry.OwnerUnitId);
          for K := 0 to Child.ChildCount - 1 do
          begin
            Decl := Child.ChildAt(K);
            if (Decl = nil) or (Decl.NodeKind <> gnkConstDecl) or
              (Decl.TextLen = 0) then
              Continue;
            ArrayTypeNode := nil;
            if Decl.ChildCount > 0 then
            begin
              TypeChild := Decl.ChildAt(0);
              if (TypeChild <> nil) and (TypeChild.NodeKind = gnkArrayType) then
                ArrayTypeNode := TypeChild;
            end;
            if ArrayTypeNode = nil then
              Continue;
            RegisterRuntimeVar(Decl.Text);
            RegisterArrayVarMetadata(Decl.Text, ArrayTypeNode, ArrOperand);
            FModel.AddTypedHirNode(
              'var-decl-arr-runtime', Decl.Text, 0, 0, ArrOperand);
          end;
        end
        else if (Child <> nil) and (Child.NodeKind = gnkVarSection) then
        begin
          for K := 0 to Child.ChildCount - 1 do
          begin
            Decl := Child.ChildAt(K);
            if (Decl = nil) or (Decl.NodeKind <> gnkVarDecl) or
              (Decl.TextLen = 0) then
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
              (Decl.ChildAt(0).TextEquals('String', True) or
               Decl.ChildAt(0).TextEquals('AnsiString', True)) then
            begin
              RegisterRuntimeStrVar(Decl.Text);
              RegisterOwnedRuntimeStrVar(Decl.Text);
              FModel.AddTypedHirNode(
                'var-decl-tstring-runtime', Decl.Text, 0, 0, Decl.Text);
            end
            else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
              TypeMetaIsDynArrayType(Decl.ChildAt(0).Text) then
            begin
              { Before TypeMetaSize/class: TStringArray Size=8 looked like class. }
              RegisterRuntimeArrVar(Decl.Text);
              if FModel.LookupConstValue(
                Decl.ChildAt(0).Text + '$arr_elem_size', Folded) then
                FModel.AddConstValue(Decl.Text + '$arr_elem_size', Folded);
              if FModel.LookupStringConstValue(
                Decl.ChildAt(0).Text + '$arr_elem_type', ArrOperand) then
                FModel.AddStringConstValue(Decl.Text + '$arr_elem_type',
                  ArrOperand);
              FModel.AddTypedHirNode(
                'var-decl-arr-runtime', Decl.Text, 0, 0, Decl.Text);
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
            else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
              TypeMetaIsInterface(Decl.ChildAt(0).Text) then
            begin
              { Interface refs are always ptr-sized even if $size seed lagged. }
              RegisterClassVar(Decl.Text, Decl.ChildAt(0).Text);
              FModel.AddTypedHirNode(
                'var-decl-ptr-runtime', Decl.Text, 0, 0, Decl.Text);
            end
            else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
              (TypeMetaSize(Decl.ChildAt(0).Text) > 0) then
            begin
              { Match np_sema_codegen: record locals must RegisterRecordVar so
                Pos/X.Field residual can LookupRecordVar (TypeChild.Text bug).
                Pointer aliases (PFoo = ^T) must stay ptr — never recvar. }
              if TypeMetaIsPointer(Decl.ChildAt(0).Text) then
              begin
                RegisterClassVar(Decl.Text, 'Pointer');
                RegisterPointerVar(Decl.Text, Decl.ChildAt(0).Text);
                FModel.AddTypedHirNode(
                  'var-decl-ptr-runtime', Decl.Text, 0, 0, Decl.Text);
              end
              else if TypeMetaIsRecord(Decl.ChildAt(0).Text) then
              begin
                RegisterRecordVar(Decl.Text, Decl.ChildAt(0).Text);
                FModel.AddTypedHirNode(
                  'var-decl-record-runtime', Decl.Text, 0, 0,
                  Decl.Text + #9 +
                  IntToStr(TypeMetaSize(Decl.ChildAt(0).Text) div 8));
                if IsManagedRecord(Decl.ChildAt(0).Text) then
                  FRuntimeVars.RegisterManagedRecordVar(Decl.Text,
                    Decl.ChildAt(0).Text);
              end
              else if TypeMetaIsClass(Decl.ChildAt(0).Text) then
              begin
                RegisterClassVar(Decl.Text, Decl.ChildAt(0).Text);
                FModel.AddTypedHirNode(
                  'var-decl-ptr-runtime', Decl.Text, 0, 0, Decl.Text);
              end
              else
                { Scalar with known size (LongInt/Integer/…) — not a class. }
                FModel.AddTypedHirNode(
                  'var-decl-runtime', Decl.Text, 0, 0, Decl.Text);
            end
            else
              FModel.AddTypedHirNode(
                'var-decl-runtime', Decl.Text, 0, 0, Decl.Text);
          end;
        end;
      end;
    RegisterOuterFrameCapturesFor(Entry.Decl, Entry.OwnerUnitId);
    SavedTerminated := FCurrentBlockTerminated;
    FCurrentBlockTerminated := False;
    { B4b 缺口乙: while encoding a cloned generic instance body, expose the
      instance name so TypeMetaSize can resolve template type params (T).
      Only method names (last '.' segment stripped) that carry a
      $generic_inst marker are treated as instance contexts. }
    FCurrentGenericInstance := '';
    InstName := Entry.Name;
    J := Length(InstName);
    while (J > 0) and (InstName[J] <> '.') do
      Dec(J);
    if J > 1 then
    begin
      InstName := Copy(InstName, 1, J - 1);
      if FModel.LookupStringConstValue(
        InstName + '.$generic_inst', ArrOperand) then
        FCurrentGenericInstance := InstName;
    end;
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
      else if IsArrReturn then
      begin
        { Dual-slot Result: ABI returns data ptr half only. }
        NodeId := FModel.AddTypedHirNode('ret-runtime', RetVarName, 0, 0,
          'var ' + RetVarName + '$ptr' + #10);
        AttachRuntimeReturnExpr(NodeId, RetVarName);
      end
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
    FCurrentGenericInstance := '';
    FProcedureBodies.GetPtrUnchecked(I)^.Encoded := True;
      end;
      finally
        PhaseEnd('seed.encode');
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
    SemaTrace('body-seed-reachability registered=' +
      IntToStr(LongInt(FProcedureBodies.Count)) + ' needed=' +
      IntToStr(NeededCount) + ' encoded=' + IntToStr(EncodedCount) +
      ' queue=' + IntToStr(LongInt(FGenericWorkQueue.Count)));
    { Temporary L3 residual probe: dump body-table rows for missing-define class. }
    for I := 0 to LongInt(FProcedureBodies.Count) - 1 do
      if SameText(FProcedureBodies[I].Name, 'ChangeFileExt') or
        SameText(FProcedureBodies[I].Name, 'ResolveExecutablePath') or
        SameText(FProcedureBodies[I].Name, 'getenv') or
        SameText(FProcedureBodies[I].Name, 'CreateDispatchPublishedState') or
        SameText(FProcedureBodies[I].Name, 'TObject.Create') or
        SameText(FProcedureBodies[I].Name, 'TObject.Destroy') or
        SameText(FProcedureBodies[I].Name, 'TGreenNode.Create') or
        SameText(FProcedureBodies[I].Name, 'TGreenNode.GetText') or
        SameText(FProcedureBodies[I].Name, 'TGreenNode.Text') or
        SameText(FProcedureBodies[I].Name, 'TGreenNode.AppendChild') then
      begin
        Entry := FProcedureBodies[I];
        WriteLn(StdErr, '[sema] body-row name=', Entry.Name,
          ' owner=', Entry.OwnerUnitId,
          ' needed=', Ord(Entry.Needed),
          ' encoded=', Ord(Entry.Encoded),
          ' bodyNil=', Ord(Entry.Body = nil),
          ' declNil=', Ord(Entry.Decl = nil),
          ' overload=', Ord(HasOverload(Entry.Name)),
          ' sig=', GetParamSignature(Entry.Decl),
          ' idSig=', GetParamIdentitySignature(Entry.Decl));
        Flush(StdErr);
      end;
  finally
    FSeedingBodiesActive := False;
  end;
end;