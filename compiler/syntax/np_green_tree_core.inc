procedure TGreenTree.CheckMutable;
begin
  Assert(not FFrozen, 'TGreenTree: attempt to mutate frozen tree');
end;

procedure TGreenTree.Freeze;
begin
  FFrozen := True;
end;
procedure TGreenTree.AppendInterfaceUse(const AUseName: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FInterfaceUses);
  SetLength(FInterfaceUses, NextIndex + 1);
  FInterfaceUses[NextIndex] := AUseName;
end;

procedure TGreenTree.AppendImplementationUse(const AUseName: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FImplementationUses);
  SetLength(FImplementationUses, NextIndex + 1);
  FImplementationUses[NextIndex] := AUseName;
end;

procedure TGreenTree.AppendForeignProcedureDecl(
  const AForeignProcedureDecl: TForeignProcedureDecl
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FForeignProcedureDecls);
  SetLength(FForeignProcedureDecls, NextIndex + 1);
  FForeignProcedureDecls[NextIndex] := AForeignProcedureDecl;
end;

function TGreenTree.RootKindName: string;
begin
  Result := RootKeywordLabel(FRootKind);
end;

function TGreenTree.InterfaceUseCount: LongInt;
begin
  Result := Length(FInterfaceUses);
end;

function TGreenTree.InterfaceUseAt(const AIndex: LongInt): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FInterfaceUses)) then
    Exit('');

  Result := FInterfaceUses[AIndex];
end;

function TGreenTree.ImplementationUseCount: LongInt;
begin
  Result := Length(FImplementationUses);
end;

function TGreenTree.ImplementationUseAt(const AIndex: LongInt): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FImplementationUses)) then
    Exit('');

  Result := FImplementationUses[AIndex];
end;

function TGreenTree.ForeignProcedureDeclCount: LongInt;
begin
  Result := Length(FForeignProcedureDecls);
end;

function TGreenTree.ForeignProcedureDeclAt(
  const AIndex: LongInt
): TForeignProcedureDecl;
begin
  if (AIndex < 0) or (AIndex >= Length(FForeignProcedureDecls)) then
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
var
  Cursor: LongInt;
  Current: TToken;
  RootNode: TGreenNode;
  DeclaredName: string;
  DeclaredNameOffset: LongInt;
  PreviousExpressionTree: TGreenTree;
begin
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
 * TGreenNode.Create — backward-compatible factory
 *
 * Directly allocates node data in ActiveExpressionTree's compact storage
 * and registers Self as the facade in FFacades.
 * FNodes[i] and FFacades[i] are strictly 1:1.
 *}
constructor TGreenNode.Create(
  const ANodeKind: TGreenNodeKind;
  const AByteOffset: LongInt;
  const AByteLength: LongInt;
  const AText: string
);
var
  Data: TGreenNodeData;
  Idx: LongInt;
begin
  if ActiveExpressionTree <> nil then
  begin
    if ActiveExpressionTree.IsFrozen then
    begin
      FOwner := nil;
      FIndex := -1;
      Exit;
    end;
    FOwner := ActiveExpressionTree;

    Data.Kind := ANodeKind;
    Data.ByteOffset := AByteOffset;
    Data.ByteLength := AByteLength;
    Data.TextStart := Length(FOwner.FNodeText);
    Data.TextLen := Length(AText);
    Data.ChildStart := -1;
    Data.ChildCount := 0;

    FOwner.FNodeText := FOwner.FNodeText + AText;
    Idx := FOwner.FNodes.Count;
    FOwner.FNodes.Push(Data);
    FIndex := Idx;

    { Register Self as the facade for this index }
    FOwner.FFacades.Push(Self);
    Exit;
  end;

  { Fallback: no active tree (should not happen in normal parsing) }
  FOwner := nil;
  FIndex := -1;
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
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count)
    or (AChild = nil) then
    Exit;
  { Prevent cyclic AST: reject appending self as child }
  if (AChild.FOwner = FOwner) and (AChild.FIndex = FIndex) then
    Exit;
  FOwner.CheckMutable;
  D := FOwner.FNodes[FIndex];
  if D.ChildStart < 0 then
  begin
    D.ChildStart := AChild.FIndex;
    D.ChildCount := 1;
  end
  else
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


function TGreenNode.ChildCount: LongInt;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit(0);
  Result := FOwner.FNodes[FIndex].ChildCount;
end;

function TGreenNode.ChildAt(const AIndex: LongInt): TGreenNode;
var
  D: TGreenNodeData;
  ChildIdx: LongInt;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit(nil);
  D := FOwner.FNodes[FIndex];
  if (AIndex < 0) or (AIndex >= D.ChildCount) or (D.ChildStart < 0) then
    Exit(nil);
  ChildIdx := D.ChildStart + AIndex;
  if (ChildIdx >= 0) and (ChildIdx < FOwner.FFacades.Count) then
  begin
    Result := FOwner.FFacades[ChildIdx];
    { Guard against cyclic AST: if child is self, return nil to break recursion }
    if (Result <> nil) and (Result.FOwner = FOwner) and (Result.FIndex = FIndex) then
      Result := nil;
  end
  else
    Result := nil;
end;

