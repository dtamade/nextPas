procedure TGreenTree.CheckMutable;
begin
  Assert(not FFrozen, 'TGreenTree: attempt to mutate frozen tree');
end;

procedure TGreenTree.Freeze;
begin
  FFrozen := True;
end;
procedure TGreenTree.AppendInterfaceUse(const AUseName: string);
begin
  FInterfaceUses.Push(AUseName);
end;

procedure TGreenTree.AppendImplementationUse(const AUseName: string);
begin
  FImplementationUses.Push(AUseName);
end;

procedure TGreenTree.AppendForeignProcedureDecl(
  const AForeignProcedureDecl: TForeignProcedureDecl
);
begin
  FForeignProcedureDecls.Push(AForeignProcedureDecl);
end;

function TGreenTree.RootKindName: string;
begin
  Result := RootKeywordLabel(FRootKind);
end;

function TGreenTree.InterfaceUseCount: LongInt;
begin
  Result := LongInt(FInterfaceUses.Count);
end;

function TGreenTree.InterfaceUseAt(const AIndex: LongInt): string;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FInterfaceUses.Count)) then
    Exit('');

  Result := FInterfaceUses[AIndex];
end;

function TGreenTree.ImplementationUseCount: LongInt;
begin
  Result := LongInt(FImplementationUses.Count);
end;

function TGreenTree.ImplementationUseAt(const AIndex: LongInt): string;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FImplementationUses.Count)) then
    Exit('');

  Result := FImplementationUses[AIndex];
end;

function TGreenTree.ForeignProcedureDeclCount: LongInt;
begin
  Result := LongInt(FForeignProcedureDecls.Count);
end;

function TGreenTree.ForeignProcedureDeclAt(
  const AIndex: LongInt
): TForeignProcedureDecl;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FForeignProcedureDecls.Count)) then
  begin
    Result.ProcedureName := '';
    Result.CallingConvention := '';
    Result.LibraryId := '';
    Result.ExternalSymbolName := '';
    Result.HasExplicitSymbolName := False;
    Result.ByteOffset := 0;
    Exit;
  end;

  Result := FForeignProcedureDecls[AIndex];
end;

function TGreenTree.GreenNodeCount: LongInt;

  function CountNodes(const ANode: TGreenNode): LongInt;
  var
    Index: LongInt;
  begin
    if ANode = nil then
      Exit(0);
    Result := 1;
    for Index := 0 to ANode.ChildCount - 1 do
      Result := Result + CountNodes(ANode.ChildAt(Index));
  end;

begin
  Result := CountNodes(FRootNode);
end;

function ParseGreenTree(
  const ALexer: TLexerResult;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenTree;
begin
  Result := ParseGreenTree(ALexer, ADiagnostics, ARootFileId, nil);
end;

function ParseGreenTree(
  const ALexer: TLexerResult;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const AAllocator: IAllocator
): TGreenTree;
var
  Cursor: LongInt;
  Current: TToken;
  RootNode: TGreenNode;
  DeclaredName: string;
  DeclaredNameOffset: LongInt;
  PreviousExpressionTree: TGreenTree;
begin
  if AAllocator <> nil then
    Result := TGreenTree.Create(AAllocator)
  else
    Result := TGreenTree.Create;
  PreviousExpressionTree := ActiveExpressionTree;
  ActiveExpressionTree := Result;
  try
    Cursor := 0;
    SkipDirectives(ALexer, Cursor);
    Current := CurrentToken(ALexer, Cursor);

    Result.FRootKind := RootKindFromToken(Current.Kind);
    if Result.FRootKind = grkUnknown then
    begin
      EmitSyntaxError(
        ADiagnostics,
        ARootFileId,
        Current,
        'program|unit|library|package'
      );
      Exit;
    end;

    RootNode := TGreenNode.Create(
      GreenNodeKindFromRootKind(Result.FRootKind),
      Current.ByteOffset,
      Length(Current.Lexeme),
      Current.Lexeme
    );
    Result.FRootNode := RootNode;
    Result.FNodeCount := 1;
    AdvanceCursor(Cursor);

    if not ConsumeIdentifierPath(
      ALexer,
      Cursor,
      Result.FRootKind = grkUnit,
      DeclaredName,
      DeclaredNameOffset
    ) then
    begin
      EmitSyntaxError(
        ADiagnostics,
        ARootFileId,
        CurrentToken(ALexer, Cursor),
        'identifier'
      );
      Exit;
    end;

    Result.FDeclaredName := DeclaredName;
    RootNode.AppendChild(TGreenNode.Create(
      gnkIdentifier,
      DeclaredNameOffset,
      Length(DeclaredName),
      DeclaredName
    ));
    Inc(Result.FNodeCount);

    if not MatchToken(ALexer, Cursor, tkSemicolon, ADiagnostics, ARootFileId, ';') then
      Exit;
    Inc(Result.FNodeCount);

    case Result.FRootKind of
      grkProgram, grkLibrary, grkPackage:
        begin
          if not ParseProgramLikeRoot(
            ALexer,
            Cursor,
            Result,
            RootNode,
            ADiagnostics,
            ARootFileId
          ) then
            Exit;
        end;
      grkUnit:
        begin
          if not ParseUnitRoot(
            ALexer,
            Cursor,
            Result,
            RootNode,
            ADiagnostics,
            ARootFileId
          ) then
            Exit;
        end;
      grkUnknown:
        Exit;
    end;

    Result.FIsValid := not ADiagnostics.HasErrors;
    Result.Freeze;
  finally
    ActiveExpressionTree := PreviousExpressionTree;
  end;
end;

class operator TGreenNode.:=(const B: Pointer): TGreenNode;
begin
  Result.FOwner := nil;
  Result.FIndex := -1;
end;

class operator TGreenNode.=(const A: TGreenNode; const B: Pointer): Boolean;
begin
  Result := A.FIndex < 0;
end;

class operator TGreenNode.<>(const A: TGreenNode; const B: Pointer): Boolean;
begin
  Result := A.FIndex >= 0;
end;

class operator TGreenNode.=(const A: TGreenNode; const B: TGreenNode): Boolean;
begin
  Result := (A.FOwner = B.FOwner) and (A.FIndex = B.FIndex);
end;

class operator TGreenNode.<>(const A: TGreenNode; const B: TGreenNode): Boolean;
begin
  Result := not (A = B);
end;

function NilGreenNode: TGreenNode; inline;
begin
  Result.FOwner := nil;
  Result.FIndex := -1;
end;

{**
 * TGreenNode.Create — backward-compatible factory via ActiveExpressionTree
 * Prefer Create(ATree, ...) for explicit single-source allocation.
 * FNodes[i] and FFacades[i] are strictly 1:1.
 *}
constructor TGreenNode.Create(
  const ANodeKind: TGreenNodeKind;
  const AByteOffset: LongInt;
  const AByteLength: LongInt;
  const AText: string
);
begin
  if ActiveExpressionTree = nil then
  begin
    FOwner := nil;
    FIndex := -1;
    Exit;
  end;
  Self := TGreenNode.Create(ActiveExpressionTree, ANodeKind, AByteOffset, AByteLength, AText);
end;

constructor TGreenNode.Create(
  const ATree: TGreenTree;
  const ANodeKind: TGreenNodeKind;
  const AByteOffset: LongInt;
  const AByteLength: LongInt;
  const AText: string
);
var
  Data: TGreenNodeData;
  Idx: LongInt;
begin
  if (ATree = nil) or ATree.IsFrozen then
  begin
    FOwner := nil;
    FIndex := -1;
    Exit;
  end;
  FOwner := ATree;
  Data.Kind := ANodeKind;
  Data.ByteOffset := AByteOffset;
  Data.ByteLength := AByteLength;
  Data.TextStart := Length(FOwner.FNodeText);
  Data.TextLen := Length(AText);
  Data.ChildStart := -1;
  Data.ChildCount := 0;
  Data.ChildCapacity := 0;
  FOwner.FNodeText := FOwner.FNodeText + AText;
  Idx := FOwner.FNodes.Count;
  FOwner.FNodes.Push(Data);
  FIndex := Idx;
  FOwner.FFacades.Push(Self);
end;

constructor TGreenNode.CreateFacade(AOwner: TGreenTree; AIndex: LongInt);
begin
  FOwner := AOwner;
  FIndex := AIndex;
end;

function TGreenNode.IsNil: Boolean;
begin
  Result := FIndex < 0;
end;

procedure TGreenNode.AppendChild(const AChild: TGreenNode);
var
  D: TGreenNodeData;
  ExistingChildIndex: LongInt;
  NewChildCapacity: LongInt;
  NewChildStart: LongInt;
  OldChildStart: LongInt;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count)
    or (AChild = nil) then
    Exit;
  { Prevent cyclic AST: reject appending self as child }
  if (AChild.FOwner = FOwner) and (AChild.FIndex = FIndex) then
    Exit;
  FOwner.CheckMutable;
  D := FOwner.FNodes[FIndex];
  if D.ChildCount >= D.ChildCapacity then
  begin
    OldChildStart := D.ChildStart;
    if D.ChildCapacity = 0 then
      NewChildCapacity := 1
    else
      NewChildCapacity := D.ChildCapacity * 2;
    NewChildStart := FOwner.FChildIndices.Count;
    for ExistingChildIndex := 0 to NewChildCapacity - 1 do
      FOwner.FChildIndices.Push(-1);
    for ExistingChildIndex := 0 to D.ChildCount - 1 do
      FOwner.FChildIndices[NewChildStart + ExistingChildIndex] :=
        FOwner.FChildIndices[OldChildStart + ExistingChildIndex];
    D.ChildStart := NewChildStart;
    D.ChildCapacity := NewChildCapacity;
  end;
  FOwner.FChildIndices[D.ChildStart + D.ChildCount] := AChild.FIndex;
  Inc(D.ChildCount);
  FOwner.FNodes[FIndex] := D;
end;

function TGreenNode.NodeKindName: string;
begin
  Result := GreenNodeKindLabel(GetNodeKind);
end;
function TGreenNode.GetNodeKind: TGreenNodeKind;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit(gnkUnknown);
  Result := FOwner.FNodes[FIndex].Kind;
end;

procedure TGreenNode.SetNodeKind(AValue: TGreenNodeKind);
var
  D: TGreenNodeData;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit;
  FOwner.CheckMutable;
  D := FOwner.FNodes[FIndex];
  D.Kind := AValue;
  FOwner.FNodes[FIndex] := D;
end;

function TGreenNode.GetByteOffset: LongInt;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit(0);
  Result := FOwner.FNodes[FIndex].ByteOffset;
end;

function TGreenNode.GetByteLength: LongInt;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit(0);
  Result := FOwner.FNodes[FIndex].ByteLength;
end;

function TGreenNode.GetText: string;
var
  D: TGreenNodeData;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit('');
  D := FOwner.FNodes[FIndex];
  if (D.TextStart >= 0) and (D.TextLen > 0)
    and (D.TextStart + D.TextLen <= Length(FOwner.FNodeText)) then
    Result := Copy(FOwner.FNodeText, D.TextStart + 1, D.TextLen)
  else
    Result := '';
end;

procedure TGreenNode.SetText(const AValue: string);
var
  D: TGreenNodeData;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit;
  FOwner.CheckMutable;
  D := FOwner.FNodes[FIndex];
  D.TextStart := Length(FOwner.FNodeText);
  D.TextLen := Length(AValue);
  FOwner.FNodeText := FOwner.FNodeText + AValue;
  FOwner.FNodes[FIndex] := D;
end;

function TGreenNode.TextLen: LongInt;
var
  D: TGreenNodeData;
begin
  Result := 0;
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit;
  D := FOwner.FNodes[FIndex];
  if (D.TextStart >= 0) and (D.TextStart + D.TextLen <= Length(FOwner.FNodeText)) then
    Result := D.TextLen;
end;

function TGreenNode.TextEquals(const AValue: string; AIgnoreCase: Boolean): Boolean;
var
  D: TGreenNodeData;
  P, Q: PChar;
  I, L: LongInt;
  C1, C2: AnsiChar;
begin
  { Mirror GetText's validity rules exactly: an out-of-range node yields ''
    so it only ever equals an empty AValue. }
  Result := False;
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit(L = 0);
  D := FOwner.FNodes[FIndex];
  L := Length(AValue);
  if (D.TextStart < 0) or (D.TextLen <= 0) or
    (D.TextStart + D.TextLen > Length(FOwner.FNodeText)) then
    Exit(L = 0);
  if D.TextLen <> L then
    Exit;
  if L = 0 then
    Exit(True);
  P := @FOwner.FNodeText[D.TextStart + 1];
  Q := @AValue[1];
  for I := 0 to L - 1 do
  begin
    C1 := P[I];
    C2 := Q[I];
    if AIgnoreCase then
    begin
      if (C1 >= 'A') and (C1 <= 'Z') then
        Inc(C1, $20);
      if (C2 >= 'A') and (C2 <= 'Z') then
        Inc(C2, $20);
    end;
    if C1 <> C2 then
      Exit(False);
  end;
  Result := True;
end;


function TGreenNode.ChildCount: LongInt;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit(0);
  Result := FOwner.FNodes[FIndex].ChildCount;
end;

function TGreenNode.ChildAt(const AIndex: LongInt): TGreenNode;
var
  D: TGreenNodeData;
  ChildLinkIndex: LongInt;
  ChildNodeIndex: LongInt;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit(nil);
  D := FOwner.FNodes[FIndex];
  if (AIndex < 0) or (AIndex >= D.ChildCount) or (D.ChildStart < 0) then
    Exit(nil);
  ChildLinkIndex := D.ChildStart + AIndex;
  if (ChildLinkIndex >= 0) and
    (ChildLinkIndex < FOwner.FChildIndices.Count) then
  begin
    ChildNodeIndex := FOwner.FChildIndices[ChildLinkIndex];
    if (ChildNodeIndex < 0) or (ChildNodeIndex >= FOwner.FFacades.Count) then
      Exit(nil);
    Result := FOwner.FFacades[ChildNodeIndex];
    { Guard against cyclic AST: if child is self, return nil to break recursion }
    if (Result <> nil) and (Result.FOwner = FOwner) and (Result.FIndex = FIndex) then
      Result := nil;
  end
  else
    Result := nil;
end;

function TGreenNode.ChildIndexOf(const ANode: TGreenNode): LongInt;
var
  D: TGreenNodeData;
  ChildLinkIndex: LongInt;
  ChildNodeIndex: LongInt;
  I: LongInt;
begin
  Result := -1;
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit;
  { Identity is (FOwner, FIndex); a foreign-tree node can never match. }
  if ANode.FOwner <> FOwner then
    Exit;
  D := FOwner.FNodes[FIndex];
  if (D.ChildStart < 0) then
    Exit;
  for I := 0 to D.ChildCount - 1 do
  begin
    ChildLinkIndex := D.ChildStart + I;
    if (ChildLinkIndex < 0) or
      (ChildLinkIndex >= FOwner.FChildIndices.Count) then
      Exit;
    ChildNodeIndex := FOwner.FChildIndices[ChildLinkIndex];
    { Skip the cyclic self-child that ChildAt nils out. }
    if ChildNodeIndex = FIndex then
      Continue;
    if ChildNodeIndex = ANode.FIndex then
      Exit(I);
  end;
end;
