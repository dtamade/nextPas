function ParseBeginBlock(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Block: TGreenNode;
  BeginOffset: LongInt;
begin
  BeginOffset := CurrentToken(ALexer, ACursor - 1).ByteOffset;
  Block := TGreenNode.Create(gnkBeginBlock, BeginOffset, 0, '');
  AParent.AppendChild(Block);
  Inc(ATree.FNodeCount);

  Result := ParseStatementList(ALexer, ACursor, Block,
    [tkEndKeyword, tkEOF], ATree, ADiagnostics, ARootFileId);

  if not MatchTokenSilent(ALexer, ACursor, tkEndKeyword) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'END');
    Exit(False);
  end;
  Inc(ATree.FNodeCount);
end;

function ParseIfStatement(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Node: TGreenNode;
  CondExpr: TGreenNode;
  SavedParentTerm: TTokenKindSet;
begin
  Node := TGreenNode.Create(gnkIfStatement,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  Inc(ACursor);

  CondExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
  if CondExpr <> nil then
    Node.AppendChild(CondExpr);

  if not MatchTokenSilent(ALexer, ACursor, tkThenKeyword) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'THEN');
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;

  { Propagate ELSE as a parent terminator for nested loop bodies:
    while..do begin..end in a then-branch must stop at ELSE. }
  SavedParentTerm := GParentTerminators;
  Include(GParentTerminators, tkElseKeyword);
  ParseStatementList(ALexer, ACursor, Node,
    [tkElseKeyword, tkEndKeyword, tkSemicolon, tkEOF],
    ATree, ADiagnostics, ARootFileId);
  GParentTerminators := SavedParentTerm;

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkElseKeyword) then
  begin
    Inc(ACursor);
    ParseStatementList(ALexer, ACursor, Node,
      [tkEndKeyword, tkSemicolon, tkEOF],
      ATree, ADiagnostics, ARootFileId);
  end;

  AParent.AppendChild(Node);
  Inc(ATree.FNodeCount);
  Result := True;
end;

function ParseWhileStatement(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Node: TGreenNode;
  CondExpr: TGreenNode;
begin
  Node := TGreenNode.Create(gnkWhileStatement,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  Inc(ACursor);

  CondExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
  if CondExpr <> nil then
    Node.AppendChild(CondExpr);

  if not MatchTokenSilent(ALexer, ACursor, tkDoKeyword) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'DO');
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;

  ParseStatementList(ALexer, ACursor, Node,
    [tkEndKeyword, tkSemicolon, tkEOF],
    ATree, ADiagnostics, ARootFileId);

  AParent.AppendChild(Node);
  Inc(ATree.FNodeCount);
  Result := True;
end;

function ParseForStatement(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Node: TGreenNode;
  VarToken: TToken;
  Direction: string;
  RHS: TGreenNode;
  InitExpr: TGreenNode;
  VarNameNode: TGreenNode;
  ForOffset: LongInt;
begin
  ForOffset := CurrentToken(ALexer, ACursor).ByteOffset;
  Inc(ACursor);

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkVarKeyword) then
    Inc(ACursor);

  if CurrentToken(ALexer, ACursor).Kind <> tkIdentifier then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'identifier');
    Exit(False);
  end;
  VarToken := CurrentToken(ALexer, ACursor);
  Inc(ACursor);

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkInKeyword) then
  begin
    Node := TGreenNode.Create(gnkForInStatement, ForOffset, 0, '');
    Node.AppendChild(TGreenNode.Create(gnkIdentifier, VarToken.ByteOffset,
      Length(VarToken.Lexeme), VarToken.Lexeme));
    Inc(ACursor);
    RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
    if RHS <> nil then
      Node.AppendChild(RHS);

    if not MatchTokenSilent(ALexer, ACursor, tkDoKeyword) then
    begin
      EmitSyntaxError(ADiagnostics, ARootFileId,
        CurrentToken(ALexer, ACursor), 'DO');
      { Node.Free } // owned by tree FFacades
      Exit(False);
    end;

    ParseStatementList(ALexer, ACursor, Node,
      [tkEndKeyword, tkSemicolon, tkEOF],
      ATree, ADiagnostics, ARootFileId);

    AParent.AppendChild(Node);
    Inc(ATree.FNodeCount);
    Result := True;
    Exit;
  end;

  VarNameNode := TGreenNode.Create(gnkIdentifier, VarToken.ByteOffset,
    Length(VarToken.Lexeme), VarToken.Lexeme);

  if not MatchTokenSilent(ALexer, ACursor, tkAssign) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), ':=');
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;

  InitExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);

  if CurrentToken(ALexer, ACursor).Kind = tkToKeyword then
    Direction := 'to'
  else if CurrentToken(ALexer, ACursor).Kind = tkDownToKeyword then
    Direction := 'downto'
  else
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'TO/DOWNTO');
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;
  Inc(ACursor);

  { Create the for-statement node with the correct direction text from the start }
  Node := TGreenNode.Create(gnkForStatement, ForOffset, 0, Direction);
  Node.AppendChild(VarNameNode);
  if InitExpr <> nil then
    Node.AppendChild(InitExpr);

  RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
  if RHS <> nil then
    Node.AppendChild(RHS);

  if not MatchTokenSilent(ALexer, ACursor, tkDoKeyword) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'DO');
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;

  ParseStatementList(ALexer, ACursor, Node,
    [tkEndKeyword, tkSemicolon, tkEOF],
    ATree, ADiagnostics, ARootFileId);

  AParent.AppendChild(Node);
  Inc(ATree.FNodeCount);
  Result := True;
end;

function ParseRepeatStatement(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Node: TGreenNode;
  CondExpr: TGreenNode;
begin
  Node := TGreenNode.Create(gnkRepeatStatement,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  Inc(ACursor);

  ParseStatementList(ALexer, ACursor, Node,
    [tkUntilKeyword, tkEOF], ATree, ADiagnostics, ARootFileId);

  if not MatchTokenSilent(ALexer, ACursor, tkUntilKeyword) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'UNTIL');
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;

  CondExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
  if CondExpr <> nil then
    Node.AppendChild(CondExpr);

  AParent.AppendChild(Node);
  Inc(ATree.FNodeCount);
  Result := True;
end;

function ParseWithStatement(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Node: TGreenNode;
  RHS: TGreenNode;
begin
  Node := TGreenNode.Create(gnkWithStatement,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  Inc(ACursor);

  RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
  if RHS <> nil then
    Node.AppendChild(RHS);

  if not MatchTokenSilent(ALexer, ACursor, tkDoKeyword) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'DO');
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;

  ParseStatementList(ALexer, ACursor, Node,
    [tkEndKeyword, tkSemicolon, tkEOF],
    ATree, ADiagnostics, ARootFileId);

  AParent.AppendChild(Node);
  Inc(ATree.FNodeCount);
  Result := True;
end;

function ParseCaseStatement(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Node, SelectorNode, LabelNode: TGreenNode;
  SelectorExpr, LabelExpr, HighExpr: TGreenNode;
  RangeNode: TGreenNode;
begin
  Node := TGreenNode.Create(gnkCaseStatement,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  Inc(ACursor);

  SelectorExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
  if SelectorExpr <> nil then
    Node.AppendChild(SelectorExpr);

  if not MatchTokenSilent(ALexer, ACursor, tkOfKeyword) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'OF');
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
    (CurrentToken(ALexer, ACursor).Kind <> tkElseKeyword) and
    (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
  begin
    SelectorNode := TGreenNode.Create(gnkCaseSelector,
      CurrentToken(ALexer, ACursor).ByteOffset, 0, '');

    repeat
      LabelExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
      if LabelExpr = nil then
        Break;

      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkDotDot) then
      begin
        Inc(ACursor);
        HighExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
        RangeNode := TGreenNode.Create(gnkRangeExpression,
          LabelExpr.ByteOffset, 0, '');
        RangeNode.AppendChild(LabelExpr);
        if HighExpr <> nil then
          RangeNode.AppendChild(HighExpr);
        LabelNode := TGreenNode.Create(gnkCaseLabel,
          RangeNode.ByteOffset, 0, '');
        LabelNode.AppendChild(RangeNode);
      end
      else
      begin
        LabelNode := TGreenNode.Create(gnkCaseLabel,
          LabelExpr.ByteOffset, 0, '');
        LabelNode.AppendChild(LabelExpr);
      end;
      SelectorNode.AppendChild(LabelNode);
      Inc(ATree.FNodeCount);

      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkComma) then
        Inc(ACursor)
      else
        Break;
    until False;

    if not MatchTokenSilent(ALexer, ACursor, tkColon) then
    begin
      EmitSyntaxError(ADiagnostics, ARootFileId,
        CurrentToken(ALexer, ACursor), ':');
      { { SelectorNode.Free; } // record, no Free needed } // owned by tree FFacades
      SkipToSyncSet(ALexer, ACursor, [tkSemicolon, tkEndKeyword, tkElseKeyword, tkEOF]);
      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) then
        Inc(ACursor);
      Continue;
    end;

    ParseStatementList(ALexer, ACursor, SelectorNode,
      [tkSemicolon, tkEndKeyword, tkElseKeyword, tkEOF],
      ATree, ADiagnostics, ARootFileId);

    Node.AppendChild(SelectorNode);
    Inc(ATree.FNodeCount);

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) then
      Inc(ACursor);
  end;

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkElseKeyword) then
  begin
    Inc(ACursor);
    ParseStatementList(ALexer, ACursor, Node,
      [tkEndKeyword, tkEOF], ATree, ADiagnostics, ARootFileId);
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) then
      Inc(ACursor);
  end;

  if not MatchTokenSilent(ALexer, ACursor, tkEndKeyword) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'END');
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;

  AParent.AppendChild(Node);
  Inc(ATree.FNodeCount);
  Result := True;
end;

function ParseTryStatement(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Node, HandlerNode: TGreenNode;
  TryOffset: LongInt;
  HandlerToken: TToken;
begin
  TryOffset := CurrentToken(ALexer, ACursor).ByteOffset;
  Inc(ACursor);

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkFinallyKeyword) then
  begin
    Node := TGreenNode.Create(gnkTryFinallyStatement, TryOffset, 0, '');
    Inc(ACursor);
    ParseStatementList(ALexer, ACursor, Node,
      [tkEndKeyword, tkEOF], ATree, ADiagnostics, ARootFileId);
    MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
    AParent.AppendChild(Node);
    Inc(ATree.FNodeCount);
    Result := True;
    Exit;
  end;

  Node := TGreenNode.Create(gnkTryFinallyStatement, TryOffset, 0, '');

  ParseStatementList(ALexer, ACursor, Node,
    [tkExceptKeyword, tkFinallyKeyword, tkEOF],
    ATree, ADiagnostics, ARootFileId);

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkFinallyKeyword) then
  begin
    Inc(ACursor);
    ParseStatementList(ALexer, ACursor, Node,
      [tkEndKeyword, tkEOF], ATree, ADiagnostics, ARootFileId);
    MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
    AParent.AppendChild(Node);
    Inc(ATree.FNodeCount);
    Result := True;
  end
  else if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkExceptKeyword) then
  begin
    Node.NodeKind := gnkTryExceptStatement;
    Inc(ACursor);

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkOnKeyword) then
    begin
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkOnKeyword) do
      begin
        HandlerToken := CurrentToken(ALexer, ACursor);
        Inc(ACursor);

        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
        begin
          HandlerNode := TGreenNode.Create(gnkExceptionHandler,
            HandlerToken.ByteOffset, 0,
            CurrentToken(ALexer, ACursor).Lexeme);
          Inc(ACursor);
          if MatchTokenSilent(ALexer, ACursor, tkColon) then
          begin
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
            begin
              HandlerNode.AppendChild(TGreenNode.Create(gnkIdentifier,
                CurrentToken(ALexer, ACursor).ByteOffset,
                Length(CurrentToken(ALexer, ACursor).Lexeme),
                CurrentToken(ALexer, ACursor).Lexeme));
              Inc(ACursor);
            end;
          end;
        end;

        if MatchTokenSilent(ALexer, ACursor, tkDoKeyword) then
        begin
          ParseStatementList(ALexer, ACursor, HandlerNode,
            [tkSemicolon, tkOnKeyword, tkEndKeyword, tkElseKeyword, tkEOF],
            ATree, ADiagnostics, ARootFileId);
        end;

        Node.AppendChild(HandlerNode);
        Inc(ATree.FNodeCount);

        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) then
          Inc(ACursor);
      end;
    end
    else
    begin
      ParseStatementList(ALexer, ACursor, Node,
        [tkEndKeyword, tkEOF], ATree, ADiagnostics, ARootFileId);
    end;

    MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
    AParent.AppendChild(Node);
    Inc(ATree.FNodeCount);
    Result := True;
  end
  else
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'EXCEPT/FINALLY');
    { Node.Free } // owned by tree FFacades
    Result := False;
  end;
end;

function ParseStatementList(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATerminatorSet: TTokenKindSet;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;

var
  List: TGreenNode;

  function ParseStatement: Boolean;
  var
    StmtNode: TGreenNode;
    RHS: TGreenNode;
    Token: TToken;
    DotNode, CaretNode, CallNode, ArgExpr: TGreenNode;
  begin
    if (ACursor >= ALexer.TokenCount) or
      (CurrentToken(ALexer, ACursor).Kind in ATerminatorSet) then
      Exit(True);

    Token := CurrentToken(ALexer, ACursor);
    case Token.Kind of
      tkIfKeyword:
        Result := ParseIfStatement(ALexer, ACursor, List, ATree,
          ADiagnostics, ARootFileId);
      tkWhileKeyword:
        Result := ParseWhileStatement(ALexer, ACursor, List, ATree,
          ADiagnostics, ARootFileId);
      tkForKeyword:
        Result := ParseForStatement(ALexer, ACursor, List, ATree,
          ADiagnostics, ARootFileId);
      tkRepeatKeyword:
        Result := ParseRepeatStatement(ALexer, ACursor, List, ATree,
          ADiagnostics, ARootFileId);
      tkWithKeyword:
        Result := ParseWithStatement(ALexer, ACursor, List, ATree,
          ADiagnostics, ARootFileId);
      tkCaseKeyword:
        Result := ParseCaseStatement(ALexer, ACursor, List, ATree,
          ADiagnostics, ARootFileId);
      tkTryKeyword:
        Result := ParseTryStatement(ALexer, ACursor, List, ATree,
          ADiagnostics, ARootFileId);
      tkBeginKeyword:
        begin
          Inc(ACursor);
          Result := ParseBeginBlock(ALexer, ACursor, List, ATree,
            ADiagnostics, ARootFileId);
        end;
      tkBreakKeyword:
        begin
          StmtNode := TGreenNode.Create(gnkBreakStatement, Token.ByteOffset, 0, '');
          List.AppendChild(StmtNode);
          Inc(ACursor);
          Inc(ATree.FNodeCount);
          Result := True;
        end;
      tkContinueKeyword:
        begin
          StmtNode := TGreenNode.Create(gnkContinueStatement, Token.ByteOffset, 0, '');
          List.AppendChild(StmtNode);
          Inc(ACursor);
          Inc(ATree.FNodeCount);
          Result := True;
        end;
      tkExitKeyword:
        begin
          StmtNode := TGreenNode.Create(gnkExitStatement, Token.ByteOffset, 0, '');
          List.AppendChild(StmtNode);
          Inc(ACursor);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
          begin
            Inc(ACursor);
            RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
            if RHS <> nil then
              StmtNode.AppendChild(RHS);
            MatchTokenSilent(ALexer, ACursor, tkRParen);
          end;
          Inc(ATree.FNodeCount);
          Result := True;
        end;
      tkGotoKeyword:
        begin
          Inc(ACursor);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind in
              [tkIdentifier, tkIntegerLiteral]) then
          begin
            StmtNode := TGreenNode.Create(gnkGotoStatement, Token.ByteOffset, 0,
              CurrentToken(ALexer, ACursor).Lexeme);
            List.AppendChild(StmtNode);
            Inc(ACursor);
          end
          else
          begin
            StmtNode := TGreenNode.Create(gnkGotoStatement, Token.ByteOffset, 0, '');
            List.AppendChild(StmtNode);
          end;
          Inc(ATree.FNodeCount);
          Result := True;
        end;
      tkRaiseKeyword:
        begin
          StmtNode := TGreenNode.Create(gnkRaiseStatement, Token.ByteOffset, 0, '');
          List.AppendChild(StmtNode);
          Inc(ACursor);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
          begin
            RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
            if RHS <> nil then
              StmtNode.AppendChild(RHS);
          end;
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
            (LowerCase(CurrentToken(ALexer, ACursor).Lexeme) = 'at') then
          begin
            Inc(ACursor);
            ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkComma) then
            begin
              Inc(ACursor);
              ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
            end;
          end;
          Inc(ATree.FNodeCount);
          Result := True;
        end;
      tkInheritedKeyword:
        begin
          Inc(ACursor);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
          begin
            StmtNode := TGreenNode.Create(gnkProcedureCallStatement,
              Token.ByteOffset, 0, 'inherited ' + CurrentToken(ALexer, ACursor).Lexeme);
            Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
            begin
              Inc(ACursor);
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkRParen) do
              begin
                RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
                if RHS <> nil then
                  StmtNode.AppendChild(RHS);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkComma) then
                  Inc(ACursor)
                else
                  Break;
              end;
              MatchTokenSilent(ALexer, ACursor, tkRParen);
            end;
            List.AppendChild(StmtNode);
            Inc(ATree.FNodeCount);
          end
          else
          begin
            StmtNode := TGreenNode.Create(gnkProcedureCallStatement,
              Token.ByteOffset, 0, 'inherited');
            List.AppendChild(StmtNode);
            Inc(ATree.FNodeCount);
          end;
          Result := True;
        end;
      tkAsmKeyword:
        begin
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
          Result := True;
        end;
      tkSemicolon:
        begin
          { 空语句: case label: ; 或 if cond then ; }
          Inc(ACursor);
          Result := True;
        end;
      tkSpecializeKeyword:
        begin
          RHS := ParsePrimaryExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
          if RHS <> nil then
          begin
            StmtNode := TGreenNode.Create(gnkProcedureCallStatement,
              RHS.ByteOffset, 0, RHS.Text);
            StmtNode.AppendChild(RHS);
            List.AppendChild(StmtNode);
            Inc(ATree.FNodeCount);
          end;
          MatchTokenSilent(ALexer, ACursor, tkSemicolon);
          Result := True;
        end;
      tkIdentifier, tkSelfKeyword, tkNameKeyword, tkStringKeyword,
        tkMessageKeyword, tkFileKeyword, tkContainsKeyword,
        tkRequiresKeyword, tkOnKeyword, tkInlineKeyword, tkOverloadKeyword,
        tkForwardKeyword:
        begin
          if (ACursor + 1 < ALexer.TokenCount) and
            (ALexer.TokenAt(ACursor + 1).Kind = tkColon) then
          begin
            Inc(ACursor, 2);
            Result := True;
          end
          else
            Result := ParseAssignmentOrCall(ALexer, ACursor, List, ATree,
              ADiagnostics, ARootFileId);
        end;
      tkVarKeyword:
        begin
          Inc(ACursor);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind in
              [tkIdentifier, tkNameKeyword, tkStringKeyword,
               tkMessageKeyword, tkFileKeyword]) then
          begin
            StmtNode := TGreenNode.Create(gnkVarDecl,
              Token.ByteOffset, 0, CurrentToken(ALexer, ACursor).Lexeme);
            List.AppendChild(StmtNode);
            Inc(ATree.FNodeCount);
            Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkColon) then
            begin
              Inc(ACursor);
              RHS := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
              { RHS.Free; } // record, no Free needed
            end;
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkAssign) then
            begin
              Inc(ACursor);
              RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
              if RHS <> nil then
                StmtNode.AppendChild(RHS);
            end;
          end;
          Result := True;
        end;
      tkIntegerLiteral:
        begin
          if (ACursor + 1 < ALexer.TokenCount) and
            (ALexer.TokenAt(ACursor + 1).Kind = tkColon) then
          begin
            Inc(ACursor, 2);
            Result := True;
          end
          else
            Result := False;
        end;
      tkLParen:
        begin
          { parenthesized expression as statement: (expr)^.field := value,
            (expr).method(), functionPointer^(args) etc. }
          StmtNode := TGreenNode.Create(gnkProcedureCallStatement,
            Token.ByteOffset, 0, '');
          Inc(ACursor);
          RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
          MatchTokenSilent(ALexer, ACursor, tkRParen);
          { apply postfix chains: .method, ^, () }
          while RHS <> nil do
          begin
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkDot) then
            begin
              Inc(ACursor);
              if (ACursor < ALexer.TokenCount) and
                IsMethodNameToken(CurrentToken(ALexer, ACursor).Kind) then
              begin
                DotNode := TGreenNode.Create(gnkDotAccess,
                  RHS.ByteOffset, 0, CurrentToken(ALexer, ACursor).Lexeme);
                DotNode.AppendChild(RHS);
                DotNode.AppendChild(TGreenNode.Create(gnkIdentifier,
                  CurrentToken(ALexer, ACursor).ByteOffset,
                  Length(CurrentToken(ALexer, ACursor).Lexeme),
                  CurrentToken(ALexer, ACursor).Lexeme));
                RHS := DotNode;
                Inc(ACursor);
              end
              else
                Break;
            end
            else if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkCaret) then
            begin
              CaretNode := TGreenNode.Create(gnkDereference,
                RHS.ByteOffset, 0, '');
              CaretNode.AppendChild(RHS);
              RHS := CaretNode;
              Inc(ACursor);
            end
            else if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkLParen) and
              (RHS.NodeKind in [gnkIdentifier, gnkDotAccess,
                gnkDereference, gnkFunctionCall]) then
            begin
              Inc(ACursor);
              CallNode := TGreenNode.Create(gnkFunctionCall,
                RHS.ByteOffset, 0, RHS.Text);
              CallNode.AppendChild(RHS);
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkRParen) do
              begin
                ArgExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
                if ArgExpr <> nil then
                  CallNode.AppendChild(ArgExpr);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkComma) then
                  Inc(ACursor)
                else
                  Break;
              end;
              MatchTokenSilent(ALexer, ACursor, tkRParen);
              RHS := CallNode;
            end
            else
              Break;
          end;
          if RHS <> nil then
            StmtNode.AppendChild(RHS);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkAssign) then
          begin
            { assignment: (expr)^.field := value }
            StmtNode.NodeKind := gnkAssignmentStatement;
            Inc(ACursor);
            RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
            if RHS <> nil then
              StmtNode.AppendChild(RHS);
          end;
          List.AppendChild(StmtNode);
          Inc(ATree.FNodeCount);
          MatchTokenSilent(ALexer, ACursor, tkSemicolon);
          Result := True;
        end;
    else
      Result := False;
    end;
  end;

begin
  List := TGreenNode.Create(gnkStatementList, 0, 0, '');
  AParent.AppendChild(List);
  Inc(ATree.FNodeCount);

  Result := True;
  while True do
  begin
    SkipDirectives(ALexer, ACursor);
    if (ACursor >= ALexer.TokenCount) or
      (CurrentToken(ALexer, ACursor).Kind in (ATerminatorSet + GParentTerminators)) then
      Break;
    if not ParseStatement then
    begin
      List.AppendChild(TGreenNode.Create(gnkError,
        CurrentToken(ALexer, ACursor).ByteOffset, 0,
        CurrentToken(ALexer, ACursor).Lexeme));
      Inc(ATree.FNodeCount);
      EmitSyntaxError(ADiagnostics, ARootFileId,
        CurrentToken(ALexer, ACursor), 'statement');
      SkipToSyncSet(ALexer, ACursor,
        ATerminatorSet + [tkSemicolon]);
      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) then
        Inc(ACursor);
      Result := False;
      Continue;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) and
      not (tkSemicolon in ATerminatorSet) then
      Inc(ACursor);
  end;
end;
