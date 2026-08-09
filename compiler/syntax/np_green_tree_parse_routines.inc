function ParseProcedureDecl(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Node: TGreenNode;
  AsmNode: TGreenNode;
  NameToken: TToken;
  I: LongInt;
  J: LongInt;
  TypeParamText: string;
  FullName: string;
begin
  Node := TGreenNode.Create(gnkProcedureDecl,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  Inc(ACursor);

  if (ACursor >= ALexer.TokenCount) or
    not IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
  begin
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;

  NameToken := CurrentToken(ALexer, ACursor);
  FullName := NameToken.Lexeme;
  Inc(ACursor);

  if (ACursor < ALexer.TokenCount) and
    (NameToken.Kind = tkStar) and
    (CurrentToken(ALexer, ACursor).Kind = tkStar) then
  begin
    FullName := '**';
    Inc(ACursor);
  end;

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkDot) do
  begin
    Inc(ACursor);
    if (ACursor < ALexer.TokenCount) and
      IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
    begin
      FullName := FullName + '.' + CurrentToken(ALexer, ACursor).Lexeme;
      Inc(ACursor);
    end
    else
      Break;
  end;

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkLessThan) then
  begin
    Inc(ACursor);
    TypeParamText := '';
    while (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind <> tkGreaterThan) and
      (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
    begin
      if CurrentToken(ALexer, ACursor).Kind = tkIdentifier then
      begin
        if TypeParamText <> '' then
          TypeParamText := TypeParamText + ',';
        TypeParamText := TypeParamText + CurrentToken(ALexer, ACursor).Lexeme;
      end;
      Inc(ACursor);
    end;
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkGreaterThan) then
      Inc(ACursor);
    if TypeParamText <> '' then
      FullName := FullName + '<' + TypeParamText + '>';
  end;

  ParseParameterList(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId);

  MatchTokenSilent(ALexer, ACursor, tkSemicolon);

  while (ACursor < ALexer.TokenCount) and
    (IsDirectiveToken(CurrentToken(ALexer, ACursor).Kind) or
     ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
      IsCallingDirective(CurrentToken(ALexer, ACursor).Lexeme))) do
    ConsumeRoutineDirectiveToken(ALexer, ACursor, FullName);

  { external 'lib' name 'sym' — mark node and skip body }
  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkExternalKeyword) then
  begin
    Inc(ACursor);
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkStringLiteral) then
    begin
      FullName := FullName + ';external:' +
        DecodePascalStringLiteral(CurrentToken(ALexer, ACursor).Lexeme);
      Inc(ACursor);
      if (ACursor < ALexer.TokenCount) and
        ((CurrentToken(ALexer, ACursor).Kind = tkNameKeyword) or
         ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
          SameText(CurrentToken(ALexer, ACursor).Lexeme, 'name'))) then
      begin
        Inc(ACursor);
        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkStringLiteral) then
        begin
          FullName := FullName + ':' +
            DecodePascalStringLiteral(CurrentToken(ALexer, ACursor).Lexeme);
          Inc(ACursor);
        end;
      end;
    end;
    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    Node.Text := FullName;
    AParent.AppendChild(Node);
    Inc(ATree.FNodeCount);
    Result := True;
    Exit;
  end;

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkForwardKeyword) then
  begin
    Inc(ACursor);
    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
  end
  else if AParent.NodeKind <> gnkInterfaceSection then
  begin
    while (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind in
        [tkVarKeyword, tkConstKeyword, tkTypeKeyword, tkLabelKeyword,
         tkFunctionKeyword, tkProcedureKeyword]) do
    begin
      if (CurrentToken(ALexer, ACursor).Kind in [tkFunctionKeyword, tkProcedureKeyword]) then
      begin
        if (ACursor + 2 < ALexer.TokenCount) and
          (ALexer.TokenAt(ACursor + 2).Kind = tkDot) then
          Break;
        J := ACursor + 1;
        while (J < ALexer.TokenCount) and
          not (ALexer.TokenAt(J).Kind in [tkBeginKeyword, tkAsmKeyword,
            tkImplementationKeyword, tkInitializationKeyword, tkEOF]) do
          Inc(J);
        if (J >= ALexer.TokenCount) or
          not (ALexer.TokenAt(J).Kind in [tkBeginKeyword, tkAsmKeyword]) then
          Break;
      end;
      I := ACursor;
      if CurrentToken(ALexer, ACursor).Kind = tkFunctionKeyword then
        ParseFunctionDecl(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else if CurrentToken(ALexer, ACursor).Kind = tkProcedureKeyword then
        ParseProcedureDecl(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else if CurrentToken(ALexer, ACursor).Kind = tkVarKeyword then
        ParseVarSection(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else if CurrentToken(ALexer, ACursor).Kind = tkConstKeyword then
        { Local const (BUF_SIZE = 1024) must stay in AST — skip loses values. }
        ParseConstSection(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else if CurrentToken(ALexer, ACursor).Kind = tkTypeKeyword then
        ParseTypeSection(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else
      begin
        { label / unknown: skip section until next local-decl keyword or body. }
        Inc(ACursor);
        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind <> tkBeginKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkAsmKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkVarKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkConstKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkTypeKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkFunctionKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkProcedureKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
          Inc(ACursor);
      end;
      if ACursor = I then begin Inc(ACursor); Break; end;
    end;
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkBeginKeyword) then
    begin
      Inc(ACursor);
      ParseBeginBlock(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId);
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    end
    else if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkAsmKeyword) then
    begin
      AsmNode := TGreenNode.Create(gnkAsmBlock,
        CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
      Inc(ACursor);
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
      MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
      { FPC asm clobber list: end ['eax', 'ebx', ...] }
      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkLBracket) then
      begin
        Inc(ACursor);
        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind <> tkRBracket) and
          (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
          Inc(ACursor);
        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkRBracket) then
          Inc(ACursor);
      end;
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
      Node.AppendChild(AsmNode);
      Inc(ATree.FNodeCount);
    end
    else
    begin
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkProcedureKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkFunctionKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkConstructorKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkDestructorKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkBeginKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkInitializationKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkFinalizationKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkOperatorKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
    end;
  end;

  Node.Text := FullName;
  AParent.AppendChild(Node);
  Inc(ATree.FNodeCount);
  Result := True;
end;

function ParseFunctionDecl(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Node: TGreenNode;
  AsmNode: TGreenNode;
  NameToken: TToken;
  TypeNode: TGreenNode;
  I: LongInt;
  J: LongInt;
  TypeParamText: string;
  FullName: string;
begin
  Node := TGreenNode.Create(gnkFunctionDecl,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  Inc(ACursor);

  SkipDirectives(ALexer, ACursor);
  if (ACursor >= ALexer.TokenCount) or
    not IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
  begin
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;

  NameToken := CurrentToken(ALexer, ACursor);
  FullName := NameToken.Lexeme;
  Inc(ACursor);

  if (ACursor < ALexer.TokenCount) and
    (NameToken.Kind = tkStar) and
    (CurrentToken(ALexer, ACursor).Kind = tkStar) then
  begin
    FullName := '**';
    Inc(ACursor);
  end;

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkDot) do
  begin
    Inc(ACursor);
    if (ACursor < ALexer.TokenCount) and
      IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
    begin
      FullName := FullName + '.' + CurrentToken(ALexer, ACursor).Lexeme;
      Inc(ACursor);
    end
    else
      Break;
  end;

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkLessThan) then
  begin
    Inc(ACursor);
    TypeParamText := '';
    while (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind <> tkGreaterThan) and
      (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
    begin
      if CurrentToken(ALexer, ACursor).Kind = tkIdentifier then
      begin
        if TypeParamText <> '' then
          TypeParamText := TypeParamText + ',';
        TypeParamText := TypeParamText + CurrentToken(ALexer, ACursor).Lexeme;
      end;
      Inc(ACursor);
    end;
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkGreaterThan) then
      Inc(ACursor);
    if TypeParamText <> '' then
      FullName := FullName + '<' + TypeParamText + '>';
  end;

  ParseParameterList(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId);

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
    (ACursor + 1 < ALexer.TokenCount) and
    (ALexer.TokenAt(ACursor + 1).Kind = tkColon) then
    Inc(ACursor);

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkColon) then
  begin
    Inc(ACursor);
    TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
    if TypeNode <> nil then
    begin
      Node.AppendChild(TypeNode);
      Inc(ATree.FNodeCount);
    end;
  end;

  MatchTokenSilent(ALexer, ACursor, tkSemicolon);

  while (ACursor < ALexer.TokenCount) and
    (IsDirectiveToken(CurrentToken(ALexer, ACursor).Kind) or
     ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
      IsCallingDirective(CurrentToken(ALexer, ACursor).Lexeme))) do
    ConsumeRoutineDirectiveToken(ALexer, ACursor, FullName);

  { external 'lib' name 'sym' — mark node and skip body }
  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkExternalKeyword) then
  begin
    Inc(ACursor);
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkStringLiteral) then
    begin
      FullName := FullName + ';external:' +
        DecodePascalStringLiteral(CurrentToken(ALexer, ACursor).Lexeme);
      Inc(ACursor);
      if (ACursor < ALexer.TokenCount) and
        ((CurrentToken(ALexer, ACursor).Kind = tkNameKeyword) or
         ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
          SameText(CurrentToken(ALexer, ACursor).Lexeme, 'name'))) then
      begin
        Inc(ACursor);
        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkStringLiteral) then
        begin
          FullName := FullName + ':' +
            DecodePascalStringLiteral(CurrentToken(ALexer, ACursor).Lexeme);
          Inc(ACursor);
        end;
      end;
    end;
    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    Node.Text := FullName;
    AParent.AppendChild(Node);
    Inc(ATree.FNodeCount);
    Result := True;
    Exit;
  end;

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkForwardKeyword) then
  begin
    Inc(ACursor);
    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
  end
  else if AParent.NodeKind <> gnkInterfaceSection then
  begin
    while (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind in
        [tkVarKeyword, tkConstKeyword, tkTypeKeyword, tkLabelKeyword,
         tkFunctionKeyword, tkProcedureKeyword]) do
    begin
      if (CurrentToken(ALexer, ACursor).Kind in [tkFunctionKeyword, tkProcedureKeyword]) then
      begin
        if (ACursor + 2 < ALexer.TokenCount) and
          (ALexer.TokenAt(ACursor + 2).Kind = tkDot) then
          Break;
        J := ACursor + 1;
        while (J < ALexer.TokenCount) and
          not (ALexer.TokenAt(J).Kind in [tkBeginKeyword, tkAsmKeyword,
            tkImplementationKeyword, tkInitializationKeyword, tkEOF]) do
          Inc(J);
        if (J >= ALexer.TokenCount) or
          not (ALexer.TokenAt(J).Kind in [tkBeginKeyword, tkAsmKeyword]) then
          Break;
      end;
      I := ACursor;
      if CurrentToken(ALexer, ACursor).Kind = tkFunctionKeyword then
        ParseFunctionDecl(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else if CurrentToken(ALexer, ACursor).Kind = tkProcedureKeyword then
        ParseProcedureDecl(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else if CurrentToken(ALexer, ACursor).Kind = tkVarKeyword then
        ParseVarSection(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else if CurrentToken(ALexer, ACursor).Kind = tkConstKeyword then
        { Local const (BUF_SIZE = 1024) must stay in AST — skip loses values. }
        ParseConstSection(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else if CurrentToken(ALexer, ACursor).Kind = tkTypeKeyword then
        ParseTypeSection(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else
      begin
        { label / unknown: skip section until next local-decl keyword or body. }
        Inc(ACursor);
        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind <> tkBeginKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkAsmKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkVarKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkConstKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkTypeKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkFunctionKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkProcedureKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
          Inc(ACursor);
      end;
      if ACursor = I then begin Inc(ACursor); Break; end;
    end;
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkBeginKeyword) then
    begin
      Inc(ACursor);
      ParseBeginBlock(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId);
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    end
    else if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkAsmKeyword) then
    begin
      AsmNode := TGreenNode.Create(gnkAsmBlock,
        CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
      Inc(ACursor);
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
      MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
      { FPC asm clobber list: end ['eax', 'ebx', ...] }
      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkLBracket) then
      begin
        Inc(ACursor);
        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind <> tkRBracket) and
          (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
          Inc(ACursor);
        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkRBracket) then
          Inc(ACursor);
      end;
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
      Node.AppendChild(AsmNode);
      Inc(ATree.FNodeCount);
    end
    else
    begin
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkProcedureKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkFunctionKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkConstructorKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkDestructorKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkBeginKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkInitializationKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkFinalizationKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkOperatorKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
    end;
  end;

  Node.Text := FullName;
  AParent.AppendChild(Node);
  Inc(ATree.FNodeCount);
  Result := True;
end;

function ParseBlockDeclarations(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  DeclTerminatorSet: TTokenKindSet;
begin
  DeclTerminatorSet := [tkBeginKeyword, tkEndKeyword,
    tkImplementationKeyword, tkInitializationKeyword,
    tkFinalizationKeyword, tkEOF];

  Result := True;
  while True do
  begin
    SkipDirectives(ALexer, ACursor);
    if (ACursor >= ALexer.TokenCount) or
      (CurrentToken(ALexer, ACursor).Kind in DeclTerminatorSet) then
      Break;
    case CurrentToken(ALexer, ACursor).Kind of
      tkVarKeyword:
        Result := ParseVarSection(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkThreadVarKeyword:
        Result := ParseVarSection(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId, gnkThreadVarSection) and Result;
      tkConstKeyword:
        Result := ParseConstSection(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkResourceStringKeyword:
        Result := ParseConstSection(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkTypeKeyword:
        Result := ParseTypeSection(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkLabelKeyword:
        begin
          AParent.AppendChild(TGreenNode.Create(gnkLabelSection,
            CurrentToken(ALexer, ACursor).ByteOffset, 0, ''));
          Inc(ATree.FNodeCount);
          Inc(ACursor);
          while (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
            (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
            Inc(ACursor);
          MatchTokenSilent(ALexer, ACursor, tkSemicolon);
        end;
      tkProcedureKeyword:
        if not TryParseForeignProcedureDecl(ALexer, ACursor, ATree, AParent) then
          Result := ParseProcedureDecl(ALexer, ACursor, AParent, ATree,
            ADiagnostics, ARootFileId) and Result;
      tkFunctionKeyword:
        Result := ParseFunctionDecl(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkConstructorKeyword, tkDestructorKeyword:
        Result := ParseProcedureDecl(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkOperatorKeyword:
        Result := ParseFunctionDecl(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkClassKeyword:
        begin
          { implementation: `class operator` / `class function` / `class procedure`
            / `class constructor`. Consume the class prefix then parse the routine
            so the body is attached; bare `class` advance previously desynced the
            stream at advanced-record operators (TGreenNode.:=). }
          Inc(ACursor);
          SkipDirectives(ALexer, ACursor);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkOperatorKeyword) then
            Result := ParseFunctionDecl(ALexer, ACursor, AParent, ATree,
              ADiagnostics, ARootFileId) and Result
          else if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkFunctionKeyword) then
            Result := ParseFunctionDecl(ALexer, ACursor, AParent, ATree,
              ADiagnostics, ARootFileId) and Result
          else if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind in
              [tkProcedureKeyword, tkConstructorKeyword, tkDestructorKeyword]) then
            Result := ParseProcedureDecl(ALexer, ACursor, AParent, ATree,
              ADiagnostics, ARootFileId) and Result;
        end;
      tkGenericKeyword:
        begin
          Inc(ACursor);
          SkipDirectives(ALexer, ACursor);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkFunctionKeyword) then
            Result := ParseFunctionDecl(ALexer, ACursor, AParent, ATree,
              ADiagnostics, ARootFileId) and Result
          else if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkProcedureKeyword) then
            Result := ParseProcedureDecl(ALexer, ACursor, AParent, ATree,
              ADiagnostics, ARootFileId) and Result;
        end;
      tkEndKeyword:
        begin
          Inc(ACursor);
          MatchTokenSilent(ALexer, ACursor, tkSemicolon);
        end;
    else
      AdvanceCursor(ACursor);
    end;
  end;
end;

