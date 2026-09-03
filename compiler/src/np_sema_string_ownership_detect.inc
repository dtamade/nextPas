function StringReturnFunctionNameFromNode(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode; out AName: string): Boolean;
var
  BodyNode, DeclNode: TGreenNode;
  SymbolId, TypeId: LongInt;
  TypeName: string;
begin
  AName := '';
  Result := False;
  if ANode = nil then
    Exit;
  if ANode.NodeKind = gnkIdentifier then
    AName := ANode.Text
  else if (ANode.NodeKind = gnkFunctionCall) then
  begin
    AName := ANode.Text;
    if (AName = '') and (ANode.ChildCount >= 1) and (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkIdentifier) then
      AName := ANode.ChildAt(0).Text;
  end;
  if AName = '' then
    Exit;
  if Ctx.LookupProcedureBody(Ctx.CallbackCtx, AName, BodyNode, DeclNode) and
    Ctx.DeclReturnsString(Ctx.CallbackCtx, DeclNode) then
    Exit(True);
  { Fallback: check semantic model for imported functions }
  SymbolId := Ctx.Model.LookupSymbol(AName, Ctx.CurrentScopeId);
  if SymbolId <= 0 then
    SymbolId := Ctx.Model.FindSymbolByName(AName);
  if SymbolId <= 0 then
    Exit;
  { Only accept actual function/procedure symbols }
  if not SameText(Ctx.Model.SymbolAt(SymbolId - 1).Kind, 'function') and
    not SameText(Ctx.Model.SymbolAt(SymbolId - 1).Kind, 'procedure') then
    Exit;
  TypeId := Ctx.Model.SymbolTypeId(SymbolId);
  if (TypeId > 0) and (TypeId <= Ctx.Model.TypeCount) then
  begin
    TypeName := Ctx.Model.TypeAt(TypeId - 1).Name;
    Result := SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString') or
      SameText(TypeName, 'ShortString') or SameText(TypeName, 'WideString') or
      SameText(TypeName, 'UnicodeString');
  end;
end;

function FunctionCallReturnsString(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode): Boolean;
var
  BodyNode, DeclNode: TGreenNode;
  SymbolId, TypeId: LongInt;
  TypeName: string;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.Text = '') then
    Exit;
  if Ctx.LookupProcedureBody(Ctx.CallbackCtx, ANode.Text, BodyNode, DeclNode) then
    Exit(Ctx.DeclReturnsString(Ctx.CallbackCtx, DeclNode));
  SymbolId := Ctx.Model.LookupSymbol(ANode.Text, Ctx.CurrentScopeId);
  if SymbolId <= 0 then
    SymbolId := Ctx.Model.FindSymbolByName(ANode.Text);
  if SymbolId <= 0 then
    Exit;
  if not SameText(Ctx.Model.SymbolAt(SymbolId - 1).Kind, 'function') and
    not SameText(Ctx.Model.SymbolAt(SymbolId - 1).Kind, 'procedure') then
    Exit;
  TypeId := Ctx.Model.SymbolTypeId(SymbolId);
  if (TypeId <= 0) or (TypeId > Ctx.Model.TypeCount) then
    Exit;
  TypeName := Ctx.Model.TypeAt(TypeId - 1).Name;
  Result := SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString');
end;

function MemberCallReturnsString(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode): Boolean;
var
  CalleeNode, ReceiverNode, MemberNode: TGreenNode;
  ReceiverTypeName: string;
  ReceiverSymbolId, ReceiverTypeId: LongInt;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount <> 1) then
    Exit;
  CalleeNode := ANode.ChildAt(0);
  if (CalleeNode = nil) or (CalleeNode.NodeKind <> gnkDotAccess) or
    (CalleeNode.ChildCount < 2) then
    Exit;
  ReceiverNode := CalleeNode.ChildAt(0);
  MemberNode := CalleeNode.ChildAt(1);
  if (ReceiverNode = nil) or (MemberNode = nil) or
    (ReceiverNode.NodeKind <> gnkIdentifier) or
    (MemberNode.NodeKind <> gnkIdentifier) then
    Exit;
  if SameText(ReceiverNode.Text, 'Self') and (Ctx.CurrentMethodClass <> '') then
    ReceiverTypeName := Ctx.CurrentMethodClass
  else
    ReceiverTypeName := Ctx.LookupClassVar(Ctx.CallbackCtx, ReceiverNode.Text);
  if ReceiverTypeName = '' then
  begin
    ReceiverSymbolId := Ctx.Model.FindSymbolByName(ReceiverNode.Text);
    if ReceiverSymbolId > 0 then
    begin
      ReceiverTypeId := Ctx.Model.SymbolTypeId(ReceiverSymbolId);
      if (ReceiverTypeId > 0) and (ReceiverTypeId <= Ctx.Model.TypeCount) then
        ReceiverTypeName := Ctx.Model.TypeAt(ReceiverTypeId - 1).Name;
    end;
  end;
  Result := (ReceiverTypeName <> '') and
    Ctx.TypeMetaRetStr(Ctx.CallbackCtx, ReceiverTypeName, MemberNode.Text);
end;

function TypeIdIsManagedString(const Ctx: TSemaOwnershipContext;
  const ATypeId: LongInt): Boolean;
begin
  Result := nextpas.compiler.sema.type_check.TypeIdIsManagedString(Ctx.Model, ATypeId);
end;


function IsRootOwnedStringReturnCandidate(const Ctx: TSemaOwnershipContext; 
  const AEntry: TProcedureBodyEntry; const AIsStrReturn: Boolean): Boolean;
begin
  Result := AIsStrReturn and (AEntry.Body <> nil) and
    (AEntry.Decl <> nil) and (AEntry.Decl.NodeKind = gnkFunctionDecl) and
    (Pos('.', AEntry.Name) = 0) and
    SameText(AEntry.OwnerUnitId, NormalizeUnitIdentity(Ctx.UnitGraph.RootName));
end;

function IsSupportedOwnedStringReturnIdentifierTarget(const Ctx: TSemaOwnershipContext; 
  const ATargetNode: TGreenNode): Boolean;
var
  LookupName, RetName: string;
  Symbol: TSemanticSymbol;
  SymbolId: LongInt;
begin
  Result := False;
  if (ATargetNode = nil) or (ATargetNode.NodeKind <> gnkIdentifier) then
    Exit;

  LookupName := ATargetNode.Text;
  if LookupName = '' then
    Exit;
  if SameText(LookupName, 'Result') and (Ctx.CurrentRetVarName <> '') then
    LookupName := Ctx.CurrentRetVarName;

  SymbolId := Ctx.Model.LookupSymbol(LookupName, Ctx.CurrentScopeId);
  if SymbolId <= 0 then
    SymbolId := Ctx.Model.FindSymbolByName(LookupName);
  if SymbolId <= 0 then
    Exit;

  Symbol := Ctx.Model.SymbolAt(SymbolId - 1);
  if SameText(Symbol.Kind, 'variable') then
    Exit(TypeIdIsManagedString(Ctx, Symbol.TypeId));

  RetName := Ctx.CurrentRetVarName;
  Result := SameText(Symbol.Kind, 'function') and (RetName <> '') and
    SameText(LookupName, RetName) and TypeIdIsManagedString(Ctx, Symbol.TypeId);
end;

function IsSupportedOwnedStringReturnStoreTarget(const Ctx: TSemaOwnershipContext; 
  const ATargetNode: TGreenNode): Boolean;
var
  BaseNode, FieldNode: TGreenNode;
  BaseName, ClassTypeName: string;
  BaseSymbolId, BaseTypeId: LongInt;
  FieldMeta: TFieldMeta;
begin
  Result := False;
  if (ATargetNode = nil) or (ATargetNode.NodeKind <> gnkDotAccess) or
    (ATargetNode.ChildCount < 2) then
    Exit;

  BaseNode := ATargetNode.ChildAt(0);
  FieldNode := ATargetNode.ChildAt(1);
  if (BaseNode = nil) or (FieldNode = nil) or
    (BaseNode.NodeKind <> gnkIdentifier) or
    (FieldNode.NodeKind <> gnkIdentifier) then
    Exit;

  BaseName := BaseNode.Text;
  if BaseName = '' then
    Exit;
  if SameText(BaseName, 'Self') then
  begin
    if Ctx.CurrentMethodClass = '' then
      Exit;
    BaseTypeId := Ctx.Model.FindTypeByName(Ctx.CurrentMethodClass);
  end
  else
  begin
    BaseSymbolId := Ctx.Model.LookupSymbol(BaseName, Ctx.CurrentScopeId);
    if BaseSymbolId <= 0 then
      BaseSymbolId := Ctx.Model.FindSymbolByName(BaseName);
    if BaseSymbolId <= 0 then
      Exit;
    BaseTypeId := Ctx.Model.SymbolTypeId(BaseSymbolId);
  end;
  if (BaseTypeId <= 0) or (BaseTypeId > Ctx.Model.TypeCount) then
    Exit;

  ClassTypeName := Ctx.Model.TypeAt(BaseTypeId - 1).Name;
  if ClassTypeName = '' then
    Exit;
  { Accept both class and record field assignments as safe targets for
    owned string returns. If type metadata is not fully resolved (e.g.
    imported record types), trust the assignment as safe. }
  if nextpas.compiler.sema.type_check.TypeMetaIsClass(Ctx.Model, ClassTypeName) or nextpas.compiler.sema.type_check.TypeMetaIsRecord(Ctx.Model, ClassTypeName) then
  begin
    if Ctx.Model.GetFieldMetaByName(BaseTypeId, FieldNode.Text, FieldMeta) then
      Exit(FieldMeta.IsString and TypeIdIsManagedString(Ctx, FieldMeta.TypeId));
  end;
  { Type exists but field metadata not fully resolved.
    Previously this was an unsound fallback returning True, which could hide
    leaks/double-frees. Tightened to False: only explicit class/record field
    string metadata is accepted; imported types without metadata are treated
    as unsafe and will be revisited once type metadata is fully populated
    during pre-registration (C6-H4). }
  Result := False;
end;

function IsSupportedOwnedStringReturnConsumerTarget(const Ctx: TSemaOwnershipContext; 
  const ATargetNode: TGreenNode): Boolean;
begin
  { Accept any valid assignment target as a safe consumer for owned string
    returns. The key invariant: if the node appears on the left side of an
    assignment, the owned string temporary is transferred to the target,
    which is always safe. }
  Result := (ATargetNode <> nil) and
    (ATargetNode.NodeKind in [gnkIdentifier, gnkDotAccess,
      gnkArrayAccess]);
end;

function AssignmentOwnsStringReturn(const Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  const AEntry: TProcedureBodyEntry): Boolean;
var
  DestNode, SourceNode: TGreenNode;
  FuncName: string;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkAssignmentStatement) or
    (ANode.ChildCount < 2) then
    Exit;
  DestNode := ANode.ChildAt(0);
  SourceNode := ANode.ChildAt(1);
  if (DestNode = nil) or
    (not StringReturnFunctionNameFromNode(Ctx, SourceNode, FuncName)) then
    Exit;
  if Ctx.HasOverload(Ctx.CallbackCtx, FuncName) then
    Exit;
  if IsSupportedOwnedStringReturnStoreTarget(Ctx, DestNode) then
    Exit(True);
  // Accept local variable assignments in any function context.
  // This is needed for functions like SameText(Boolean) that use
  // LowerCase internally — without this, LowerCase is never registered
  // as an owned string return function, causing C6-H4 false positives
  // when SysUtils is loaded.
  if IsSupportedOwnedStringReturnIdentifierTarget(Ctx, DestNode) then
    Exit(True);
  if not IsRootOwnedStringReturnCandidate(Ctx, AEntry, Ctx.DeclReturnsString(Ctx.CallbackCtx, AEntry.Decl)) then
    Exit;
  Result := False;
end;

function AssignmentOwnsTopLevelStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
var
  DestNode, SourceNode: TGreenNode;
  FuncName: string;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkAssignmentStatement) or
    (ANode.ChildCount < 2) then
    Exit;
  DestNode := ANode.ChildAt(0);
  SourceNode := ANode.ChildAt(1);
  if (DestNode = nil) or
    (not StringReturnFunctionNameFromNode(Ctx, SourceNode, FuncName)) then
    Exit;
  if Ctx.HasOverload(Ctx.CallbackCtx, FuncName) then
    Exit;
  Result := IsSupportedOwnedStringReturnConsumerTarget(Ctx, DestNode);
end;

function CallArgumentOwnsStringReturn(const Ctx: TSemaOwnershipContext; 
  const ACallNode, AArgNode: TGreenNode; AArgPosition: LongInt;
  out AFuncName: string): Boolean;
var
  BodyNode, DeclNode, FuncNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ACallNode = nil) or (AArgNode = nil) or
    (ACallNode.NodeKind <> gnkFunctionCall) or
    (AArgNode.NodeKind <> gnkFunctionCall) then
    Exit;
  if (ACallNode.Text = '') or Ctx.HasOverload(Ctx.CallbackCtx, ACallNode.Text) then
    Exit;
  if not Ctx.LookupProcedureBody(Ctx.CallbackCtx, ACallNode.Text, BodyNode, DeclNode) then
    Exit;
  if Ctx.IsVarParamAtPosition(Ctx.CallbackCtx, DeclNode, AArgPosition) then
    Exit;
  if not StringReturnFunctionNameFromNode(Ctx, AArgNode, AFuncName) then
    Exit;
  if Ctx.HasOverload(Ctx.CallbackCtx, AFuncName) then
    Exit;
  FuncNode := nil;
  if AArgNode.ChildCount > 0 then
    FuncNode := AArgNode.ChildAt(0);
  Result := (FuncNode <> nil) and (FuncNode.NodeKind = gnkIdentifier) and
    SameText(FuncNode.Text, AFuncName);
end;

function DirectOwnedStringReturnAssignmentNode(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
var
  DestNode: TGreenNode;
  SourceName: string;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkAssignmentStatement) or
    (ANode.ChildCount < 2) then
    Exit;
  DestNode := ANode.ChildAt(0);
  if not StringReturnFunctionNameFromNode(Ctx, ANode.ChildAt(1), SourceName) then
    Exit;
  Result := (DestNode <> nil) and Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, SourceName) and
    IsSupportedOwnedStringReturnConsumerTarget(Ctx, DestNode);
end;

function IsSupportedOwnedStringReturnArgument(const Ctx: TSemaOwnershipContext; 
  const ACallNode, AArgNode: TGreenNode; AArgPosition: LongInt): Boolean;
var
  SourceName: string;
begin
  Result := CallArgumentOwnsStringReturn(Ctx, 
    ACallNode, AArgNode, AArgPosition, SourceName) and
    Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, SourceName);
end;
