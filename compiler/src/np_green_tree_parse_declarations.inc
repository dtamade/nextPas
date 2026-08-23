function ParseAnonymousRoutineExpression(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode;
var
  Node: TGreenNode;
  RoutineKind: TTokenKind;
  TypeNode: TGreenNode;
begin
  Result := nil;
  if ActiveExpressionTree = nil then
    Exit;

  RoutineKind := CurrentToken(ALexer, ACursor).Kind;
  case RoutineKind of
    tkFunctionKeyword:
      Node := TGreenNode.Create(gnkFunctionDecl,
        CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
    tkProcedureKeyword:
      Node := TGreenNode.Create(gnkProcedureDecl,
        CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  else
    Exit;
  end;

  Inc(ACursor);
  ParseParameterList(ALexer, ACursor, Node, ActiveExpressionTree,
    ADiagnostics, ARootFileId);

  if RoutineKind = tkFunctionKeyword then
  begin
    if not MatchTokenSilent(ALexer, ACursor, tkColon) then
    begin
      EmitSyntaxError(ADiagnostics, ARootFileId,
        CurrentToken(ALexer, ACursor), ':');
      { Node.Free } // owned by tree FFacades
      Exit(nil);
    end;

    TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
    if TypeNode <> nil then
    begin
      Node.AppendChild(TypeNode);
      Inc(ActiveExpressionTree.FNodeCount);
    end;
  end;

  while (ACursor < ALexer.TokenCount) and
    (IsDirectiveToken(CurrentToken(ALexer, ACursor).Kind) or
     ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
      IsCallingDirective(CurrentToken(ALexer, ACursor).Lexeme))) do
    Inc(ACursor);

  { Parse optional var/const/type declarations before begin }
  ParseBlockDeclarations(ALexer, ACursor, Node, ActiveExpressionTree,
    ADiagnostics, ARootFileId);

  if not MatchTokenSilent(ALexer, ACursor, tkBeginKeyword) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'BEGIN');
    { Node.Free } // owned by tree FFacades
    Exit(nil);
  end;

  if not ParseBeginBlock(ALexer, ACursor, Node, ActiveExpressionTree,
    ADiagnostics, ARootFileId) then
  begin
    { Node.Free } // owned by tree FFacades
    Exit(nil);
  end;

  Result := Node;
end;

function ParseParameterList(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  List: TGreenNode;
  Decl: TGreenNode;
  NameToken: TToken;
  TypeNode, DefaultExpr: TGreenNode;
  I: LongInt;
  Child: TGreenNode;
  ParamModifier: string;
begin
  if (ACursor >= ALexer.TokenCount) or
    (CurrentToken(ALexer, ACursor).Kind <> tkLParen) then
    Exit(True);

  List := TGreenNode.Create(gnkParameterList,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  AParent.AppendChild(List);
  Inc(ATree.FNodeCount);
  Inc(ACursor);

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind <> tkRParen) do
  begin
    ParamModifier := '';
    if CurrentToken(ALexer, ACursor).Kind in
      [tkVarKeyword, tkConstKeyword, tkConstRefKeyword, tkOutKeyword] then
    begin
      if CurrentToken(ALexer, ACursor).Kind = tkVarKeyword then
        ParamModifier := 'var:'
      else if CurrentToken(ALexer, ACursor).Kind = tkOutKeyword then
        ParamModifier := 'out:'
      else if CurrentToken(ALexer, ACursor).Kind = tkConstRefKeyword then
        ParamModifier := 'constref:';
      Inc(ACursor);
    end;

    if not IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
    begin
      EmitSyntaxError(ADiagnostics, ARootFileId,
        CurrentToken(ALexer, ACursor), 'identifier');
      SkipToSyncSet(ALexer, ACursor, [tkRParen, tkSemicolon, tkEOF]);
      Break;
    end;

    while True do
    begin
      NameToken := CurrentToken(ALexer, ACursor);
      if ParamModifier <> '' then
        Decl := TGreenNode.Create(gnkParameterDecl, NameToken.ByteOffset, 0,
          ParamModifier + NameToken.Lexeme)
      else
        Decl := TGreenNode.Create(gnkParameterDecl, NameToken.ByteOffset, 0,
          NameToken.Lexeme);
      List.AppendChild(Decl);
      Inc(ATree.FNodeCount);
      Inc(ACursor);

      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkComma) then
        Inc(ACursor)
      else
        Break;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkColon) then
    begin
      Inc(ACursor);
      TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
      if TypeNode <> nil then
      begin
        for I := 0 to List.ChildCount - 1 do
        begin
          Child := List.ChildAt(I);
          if (Child <> nil) and (Child.NodeKind = gnkParameterDecl) and
            (Child.ChildCount = 0) then
          begin
            Child.AppendChild(TGreenNode.Create(gnkIdentifier,
              TypeNode.ByteOffset, TypeNode.ByteLength, TypeNode.Text));
            Inc(ATree.FNodeCount);
          end;
        end;
        List.AppendChild(TypeNode);
        Inc(ATree.FNodeCount);
      end;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkEquals) then
    begin
      Inc(ACursor);
      DefaultExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
      if (DefaultExpr <> nil) and (List.ChildCount > 0) then
      begin
        for I := List.ChildCount - 1 downto 0 do
        begin
          Child := List.ChildAt(I);
          if (Child <> nil) and (Child.NodeKind = gnkParameterDecl) then
          begin
            Child.AppendChild(DefaultExpr);
            Inc(ATree.FNodeCount);
            Break;
          end;
        end;
      end;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) then
      Inc(ACursor);
  end;

  MatchTokenSilent(ALexer, ACursor, tkRParen);
  Result := True;
end;

function ParseVarSection(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  ANodeKind: TGreenNodeKind
): Boolean;
var
  Section: TGreenNode;
  Decl: TGreenNode;
  NameToken: TToken;
  TypeNode: TGreenNode;
  I: LongInt;
  Child: TGreenNode;
begin
  Section := TGreenNode.Create(ANodeKind,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  AParent.AppendChild(Section);
  Inc(ATree.FNodeCount);
  Inc(ACursor);

  while (ACursor < ALexer.TokenCount) and
    IsVarNameToken(CurrentToken(ALexer, ACursor).Kind) do
  begin
    NameToken := CurrentToken(ALexer, ACursor);
    Decl := TGreenNode.Create(gnkVarDecl, NameToken.ByteOffset, 0,
      NameToken.Lexeme);
    Section.AppendChild(Decl);
    Inc(ATree.FNodeCount);
    Inc(ACursor);

    while (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkComma) do
    begin
      Inc(ACursor);
      if IsVarNameToken(CurrentToken(ALexer, ACursor).Kind) then
      begin
        NameToken := CurrentToken(ALexer, ACursor);
        Decl := TGreenNode.Create(gnkVarDecl, NameToken.ByteOffset, 0,
          NameToken.Lexeme);
        Section.AppendChild(Decl);
        Inc(ATree.FNodeCount);
        Inc(ACursor);
      end;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkColon) then
    begin
      Inc(ACursor);
      TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
      if TypeNode <> nil then
      begin
        for I := 0 to Section.ChildCount - 1 do
        begin
          Child := Section.ChildAt(I);
          if (Child <> nil) and (Child.NodeKind = gnkVarDecl) and
            (Child.ChildCount = 0) then
          begin
            Child.AppendChild(TGreenNode.Create(gnkIdentifier,
              TypeNode.ByteOffset, TypeNode.ByteLength, TypeNode.Text));
            Inc(ATree.FNodeCount);
          end;
        end;
        Section.AppendChild(TypeNode);
        Inc(ATree.FNodeCount);
      end;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkEquals) then
    begin
      Inc(ACursor);
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
    end;

    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
  end;

  Result := True;
end;

function ConstDeclHasArrayType(const ADecl: TGreenNode): Boolean;
var
  I: LongInt;
  Child: TGreenNode;
begin
  { Typed const `Name: array[...] of T = (...)` keeps the array type child.
    Only those paren lists are aggregate initializers; bare `(expr)` / `(a-b) div c`
    must go through ParseExpression or ProcessConstSection never seeds the value. }
  Result := False;
  if ADecl = nil then
    Exit;
  for I := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkArrayType) then
      Exit(True);
  end;
end;

function ParseConstSection(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Section: TGreenNode;
  Decl: TGreenNode;
  NameToken: TToken;
  ValueExpr: TGreenNode;
begin
  Section := TGreenNode.Create(gnkConstSection,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  AParent.AppendChild(Section);
  Inc(ATree.FNodeCount);
  Inc(ACursor);

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) do
  begin
    NameToken := CurrentToken(ALexer, ACursor);
    Decl := TGreenNode.Create(gnkConstDecl, NameToken.ByteOffset, 0,
      NameToken.Lexeme);
    Section.AppendChild(Decl);
    Inc(ATree.FNodeCount);
    Inc(ACursor);

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkColon) then
    begin
      Inc(ACursor);
      ValueExpr := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
      if ValueExpr <> nil then
      begin
        Decl.AppendChild(ValueExpr);
        Inc(ATree.FNodeCount);
      end;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkEquals) then
    begin
      Inc(ACursor);
      { Aggregate skip only for typed array consts. Untyped/scalar
        `= (BAND0_MAX - BAND0_MIN) div STEP + 1` used to hit this branch,
        drop the value AST, and residual-call @BAND0_COUNT(). }
      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkLParen) and
        ConstDeclHasArrayType(Decl) then
      begin
        Inc(ACursor);
        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind <> tkRParen) and
          (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        begin
          if CurrentToken(ALexer, ACursor).Kind = tkLParen then
          begin
            Inc(ACursor);
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkRParen) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
              Inc(ACursor);
            MatchTokenSilent(ALexer, ACursor, tkRParen);
          end
          else
            Inc(ACursor);
        end;
        MatchTokenSilent(ALexer, ACursor, tkRParen);
      end
      else
      begin
        ValueExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
        if ValueExpr <> nil then
        begin
          Decl.AppendChild(ValueExpr);
          Inc(ATree.FNodeCount);
        end;
      end;
    end;

    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
  end;

  Result := True;
end;

function ParseTypeSection(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Section: TGreenNode;
  Decl: TGreenNode;
  NameToken: TToken;
  TypeNode: TGreenNode;
  TypeParamNode: TGreenNode;
  IndexNode: TGreenNode;
  ElementNode: TGreenNode;
  FieldTypeNode: TGreenNode;
  RangeNode: TGreenNode;
  SpecArgs: string;
  FieldGroupStart, I, K: LongInt;
  FieldNode: TGreenNode;
  UsedOriginalTypeNode: Boolean;
  Nesting: LongInt;
  MethodModifiers: string;
  IsCompilerRoot: Boolean;
  IsCompilerTypeKind: Boolean;

