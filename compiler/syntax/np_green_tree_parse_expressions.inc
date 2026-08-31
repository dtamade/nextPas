function ParsePrimaryExpression(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode;
var
  Token: TToken;
  RHS, RangeNode: TGreenNode;
  J: LongInt;
begin
  if ACursor >= ALexer.TokenCount then
    Exit(nil);

  Token := CurrentToken(ALexer, ACursor);
  case Token.Kind of
    tkSpecializeKeyword:
      begin
        Inc(ACursor);
        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
        begin
          Token := CurrentToken(ALexer, ACursor);
          Token.Lexeme := 'specialize ' + Token.Lexeme;
          Inc(ACursor);
          while (ACursor + 1 < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkDot) and
            (ALexer.TokenAt(ACursor + 1).Kind = tkIdentifier) do
          begin
            Token.Lexeme := Token.Lexeme + '.' + ALexer.TokenAt(ACursor + 1).Lexeme;
            Inc(ACursor, 2);
          end;
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkLessThan) then
          begin
            Token.Lexeme := Token.Lexeme + '<';
            Inc(ACursor);
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkGreaterThan) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
            begin
              Token.Lexeme := Token.Lexeme + CurrentToken(ALexer, ACursor).Lexeme;
              Inc(ACursor);
            end;
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkGreaterThan) then
            begin
              Token.Lexeme := Token.Lexeme + '>';
              Inc(ACursor);
            end;
          end;
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
          begin
            Inc(ACursor);
            Result := TGreenNode.Create(gnkFunctionCall, Token.ByteOffset, 0,
              Token.Lexeme);
            Result.AppendChild(TGreenNode.Create(gnkIdentifier,
              Token.ByteOffset, 0, Token.Lexeme));
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkRParen) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
            begin
              RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
              if RHS <> nil then
                Result.AppendChild(RHS);
              if (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind = tkComma) then
                Inc(ACursor)
              else
                Break;
            end;
            MatchTokenSilent(ALexer, ACursor, tkRParen);
          end
          else
            Result := TGreenNode.Create(gnkIdentifier, Token.ByteOffset, 0,
              Token.Lexeme);
        end
        else
          Result := nil;
      end;
    tkIdentifier, tkNameKeyword, tkMessageKeyword, tkFileKeyword,
      tkStringKeyword, tkInheritedKeyword, tkContainsKeyword,
      tkRequiresKeyword, tkOnKeyword, tkIsKeyword, tkAsKeyword,
      tkInKeyword, tkInlineKeyword, tkOverloadKeyword,
      tkForwardKeyword:
      begin
        Inc(ACursor);
        if (Token.Kind = tkInheritedKeyword) and (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
        begin
          Token.Lexeme := 'inherited ' + CurrentToken(ALexer, ACursor).Lexeme;
          Inc(ACursor);
        end;
        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkLessThan) then
        begin
          J := ACursor + 1;
          while (J < ALexer.TokenCount) and
            (ALexer.TokenAt(J).Kind in [tkIdentifier, tkComma,
              tkLessThan, tkGreaterThan, tkDot]) do
            Inc(J);
          if (J < ALexer.TokenCount) and
            (ALexer.TokenAt(J - 1).Kind = tkGreaterThan) and
            (ALexer.TokenAt(J).Kind = tkLParen) then
          begin
            Token.Lexeme := 'specialize ' + Token.Lexeme + '<';
            Inc(ACursor);
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkGreaterThan) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
            begin
              Token.Lexeme := Token.Lexeme + CurrentToken(ALexer, ACursor).Lexeme;
              Inc(ACursor);
            end;
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkGreaterThan) then
            begin
              Token.Lexeme := Token.Lexeme + '>';
              Inc(ACursor);
            end;
          end;
        end;
        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
        begin
          Inc(ACursor);
          Result := TGreenNode.Create(gnkFunctionCall, Token.ByteOffset, 0,
            Token.Lexeme);
          Result.AppendChild(TGreenNode.Create(gnkIdentifier, Token.ByteOffset,
            Length(Token.Lexeme), Token.Lexeme));
          while (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind <> tkRParen) do
          begin
            RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
            if RHS <> nil then
              Result.AppendChild(RHS)
            else
            begin
              if (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkRParen) and
                (CurrentToken(ALexer, ACursor).Kind <> tkComma) then
                Inc(ACursor);
              if (ACursor >= ALexer.TokenCount) or
                (CurrentToken(ALexer, ACursor).Kind = tkEOF) then Break;
            end;
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkComma) then
              Inc(ACursor);
          end;
          MatchTokenSilent(ALexer, ACursor, tkRParen);
        end
        else
          Result := TGreenNode.Create(gnkIdentifier, Token.ByteOffset,
            Length(Token.Lexeme), Token.Lexeme);
      end;
    tkIntegerLiteral:
      begin
        Inc(ACursor);
        Result := TGreenNode.Create(gnkIntegerLiteral, Token.ByteOffset,
          Length(Token.Lexeme), Token.Lexeme);
      end;
    tkRealLiteral:
      begin
        Inc(ACursor);
        Result := TGreenNode.Create(gnkRealLiteral, Token.ByteOffset,
          Length(Token.Lexeme), Token.Lexeme);
      end;
    tkStringLiteral:
      begin
        Inc(ACursor);
        Result := TGreenNode.Create(gnkStringLiteral, Token.ByteOffset,
          Length(Token.Lexeme), Token.Lexeme);
      end;
    tkCharLiteral:
      begin
        Inc(ACursor);
        Result := TGreenNode.Create(gnkCharLiteral, Token.ByteOffset,
          Length(Token.Lexeme), Token.Lexeme);
      end;
    tkNilKeyword:
      begin
        Inc(ACursor);
        Result := TGreenNode.Create(gnkIdentifier, Token.ByteOffset,
          Length(Token.Lexeme), 'nil');
      end;
    tkSelfKeyword:
      begin
        Inc(ACursor);
        Result := TGreenNode.Create(gnkIdentifier, Token.ByteOffset,
          Length(Token.Lexeme), 'Self');
      end;
    tkLParen:
      begin
        Inc(ACursor);
        Result := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
        if not MatchTokenSilent(ALexer, ACursor, tkRParen) then
        begin
          EmitSyntaxError(ADiagnostics, ARootFileId,
            CurrentToken(ALexer, ACursor), ')');
          if Result <> nil then
            { Result.Free; } // record, no Free needed
          Exit(nil);
        end;
        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkCaret) do
        begin
          RHS := TGreenNode.Create(gnkDereference, Result.ByteOffset, 0, '');
          RHS.AppendChild(Result);
          Result := RHS;
          Inc(ACursor);
        end;
      end;
    tkLBracket:
      begin
        Inc(ACursor);
        Result := TGreenNode.Create(gnkSetConstructor, Token.ByteOffset, 0, '');
        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind <> tkRBracket) then
        begin
          RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
          if RHS <> nil then
          begin
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkDotDot) then
            begin
              Inc(ACursor);
              RangeNode := TGreenNode.Create(gnkRangeExpression,
                RHS.ByteOffset, 0, '');
              RangeNode.AppendChild(RHS);
              RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
              if RHS <> nil then
                RangeNode.AppendChild(RHS);
              Result.AppendChild(RangeNode);
            end
            else
              Result.AppendChild(RHS);
          end;
          while (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkComma) do
          begin
            Inc(ACursor);
            RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
            if RHS <> nil then
            begin
              if (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind = tkDotDot) then
              begin
                Inc(ACursor);
                RangeNode := TGreenNode.Create(gnkRangeExpression,
                  RHS.ByteOffset, 0, '');
                RangeNode.AppendChild(RHS);
                RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
                if RHS <> nil then
                  RangeNode.AppendChild(RHS);
                Result.AppendChild(RangeNode);
              end
              else
                Result.AppendChild(RHS);
            end;
          end;
        end;
        MatchTokenSilent(ALexer, ACursor, tkRBracket);
      end;
    tkFunctionKeyword, tkProcedureKeyword:
      Result := ParseAnonymousRoutineExpression(ALexer, ACursor, ADiagnostics,
        ARootFileId);
  else
    Result := nil;
  end;

  if (Result <> nil) and (Result.NodeKind in
    [gnkIdentifier, gnkDotAccess, gnkArrayAccess, gnkFunctionCall,
     gnkDereference, gnkStringLiteral, gnkCharLiteral,
     gnkIntegerLiteral, gnkRealLiteral]) then
  begin
    while ACursor < ALexer.TokenCount do
    begin
      case CurrentToken(ALexer, ACursor).Kind of
        tkDot:
          begin
            Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              IsMethodNameToken(CurrentToken(ALexer, ACursor).Kind) then
            begin
              Token := CurrentToken(ALexer, ACursor);
              RHS := TGreenNode.Create(gnkDotAccess, Result.ByteOffset, 0,
                Token.Lexeme);
              RHS.AppendChild(Result);
              RHS.AppendChild(TGreenNode.Create(gnkIdentifier, Token.ByteOffset,
                Length(Token.Lexeme), Token.Lexeme));
              Result := RHS;
              Inc(ACursor);
            end
            else
              Break;
          end;
        tkLBracket:
          begin
            Inc(ACursor);
            RHS := TGreenNode.Create(gnkArrayAccess, Result.ByteOffset, 0, '');
            RHS.AppendChild(Result);
            Result := RHS;
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkRBracket) do
            begin
              RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
              if RHS <> nil then
                Result.AppendChild(RHS);
              if (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind = tkComma) then
                Inc(ACursor)
              else
                Break;
            end;
            MatchTokenSilent(ALexer, ACursor, tkRBracket);
          end;
        tkCaret:
          begin
            RHS := TGreenNode.Create(gnkDereference, Result.ByteOffset, 0, '');
            RHS.AppendChild(Result);
            Result := RHS;
            Inc(ACursor);
          end;
        tkLParen:
          begin
            if Result.NodeKind in [gnkIdentifier, gnkDotAccess,
              gnkDereference, gnkFunctionCall] then
            begin
              Inc(ACursor);
              RHS := TGreenNode.Create(gnkFunctionCall, Result.ByteOffset, 0,
                Result.Text);
              RHS.AppendChild(Result);
              Result := RHS;
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkRParen) do
              begin
                RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
                if RHS <> nil then
                  Result.AppendChild(RHS);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkComma) then
                  Inc(ACursor)
                else
                  Break;
              end;
              MatchTokenSilent(ALexer, ACursor, tkRParen);
            end
            else
              Break;
          end;
      else
        Break;
      end;
    end;
  end;
end;

function ParseUnaryExpression(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode;
var
  Token: TToken;
  Operand: TGreenNode;
begin
  if ACursor >= ALexer.TokenCount then
    Exit(ParsePrimaryExpression(ALexer, ACursor, ADiagnostics, ARootFileId));

  Token := CurrentToken(ALexer, ACursor);
  if (Token.Kind = tkNotKeyword) or (Token.Kind = tkMinus) or
    (Token.Kind = tkPlus) or (Token.Kind = tkAt) then
  begin
    Inc(ACursor);
    Operand := ParseUnaryExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
    if Operand = nil then
      Exit(nil);
    Result := TGreenNode.Create(gnkUnaryExpression, Token.ByteOffset, 0,
      Token.Lexeme);
    Result.AppendChild(Operand);
  end
  else
    Result := ParsePrimaryExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
  { postfix ^ dereference and (...) function call chains }
  while Result <> nil do
  begin
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkCaret) then
    begin
      Operand := TGreenNode.Create(gnkDereference, Result.ByteOffset, 0, '');
      Operand.AppendChild(Result);
      Result := Operand;
      Inc(ACursor);
    end
    else if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
    begin
      Inc(ACursor);
      Operand := TGreenNode.Create(gnkFunctionCall, Result.ByteOffset, 0,
        Result.Text);
      Operand.AppendChild(Result);
      Result := Operand;
      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkRParen) then
      begin
        Operand := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
        if Operand <> nil then
          Result.AppendChild(Operand);
        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkComma) do
        begin
          Inc(ACursor);
          Operand := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
          if Operand <> nil then
            Result.AppendChild(Operand);
        end;
      end;
      MatchTokenSilent(ALexer, ACursor, tkRParen);
    end
    else if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkDot) then
    begin
      Inc(ACursor);
      if (ACursor < ALexer.TokenCount) and
        IsMethodNameToken(CurrentToken(ALexer, ACursor).Kind) then
      begin
        Operand := TGreenNode.Create(gnkDotAccess, Result.ByteOffset, 0,
          CurrentToken(ALexer, ACursor).Lexeme);
        Operand.AppendChild(Result);
        Operand.AppendChild(TGreenNode.Create(gnkIdentifier,
          CurrentToken(ALexer, ACursor).ByteOffset,
          Length(CurrentToken(ALexer, ACursor).Lexeme),
          CurrentToken(ALexer, ACursor).Lexeme));
        Result := Operand;
        Inc(ACursor);
      end
      else
        Break;
    end
    else
      Break;
  end;
end;

function ParseMulExpression(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode;
var
  Left, Right: TGreenNode;
  OpToken: TToken;
begin
  Left := ParseUnaryExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
  if Left = nil then
    Exit(nil);

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind in [tkStar, tkSlash,
      tkDivKeyword, tkModKeyword, tkAndKeyword, tkShlKeyword, tkShrKeyword]) do
  begin
    OpToken := CurrentToken(ALexer, ACursor);
    Inc(ACursor);
    Right := ParseUnaryExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
    if Right = nil then
    begin
      { Left.Free; } // record, no Free needed
      Exit(nil);
    end;
    Result := TGreenNode.Create(gnkBinaryExpression, OpToken.ByteOffset, 0,
      OpToken.Lexeme);
    Result.AppendChild(Left);
    Result.AppendChild(Right);
    Left := Result;
  end;

  Result := Left;
end;

function ParseAddExpression(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode;
var
  Left, Right: TGreenNode;
  OpToken: TToken;
begin
  Left := ParseMulExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
  if Left = nil then
    Exit(nil);

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind in [tkPlus, tkMinus,
      tkOrKeyword, tkXorKeyword]) do
  begin
    OpToken := CurrentToken(ALexer, ACursor);
    Inc(ACursor);
    Right := ParseMulExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
    if Right = nil then
    begin
      { Left.Free; } // record, no Free needed
      Exit(nil);
    end;
    Result := TGreenNode.Create(gnkBinaryExpression, OpToken.ByteOffset, 0,
      OpToken.Lexeme);
    Result.AppendChild(Left);
    Result.AppendChild(Right);
    Left := Result;
  end;

  Result := Left;
end;

function ParseExpression(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode;
var
  Left, Right: TGreenNode;
  OpToken: TToken;
begin
  Left := ParseAddExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
  if Left = nil then
    Exit(nil);

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind in [tkEquals, tkNotEquals,
      tkLessThan, tkGreaterThan, tkLessEqual, tkGreaterEqual,
      tkInKeyword, tkIsKeyword, tkAsKeyword]) do
  begin
    OpToken := CurrentToken(ALexer, ACursor);
    Inc(ACursor);
    Right := ParseAddExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
    if Right = nil then
    begin
      { Left.Free; } // record, no Free needed
      Exit(nil);
    end;
    Result := TGreenNode.Create(gnkBinaryExpression, OpToken.ByteOffset, 0,
      OpToken.Lexeme);
    Result.AppendChild(Left);
    Result.AppendChild(Right);
    Left := Result;
  end;

  Result := Left;
end;

function ParseAssignmentOrCall(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Node, BinaryNode, LhsNode: TGreenNode;
  NameToken: TToken;
  RHS: TGreenNode;
  CompoundOp: string;
  CompoundKind: TTokenKind;
begin
  NameToken := CurrentToken(ALexer, ACursor);
  Inc(ACursor);

  LhsNode := TGreenNode.Create(gnkIdentifier, NameToken.ByteOffset,
    Length(NameToken.Lexeme), NameToken.Lexeme);

  while ACursor < ALexer.TokenCount do
  begin
    case CurrentToken(ALexer, ACursor).Kind of
      tkDot:
        begin
          Inc(ACursor);
          if (ACursor < ALexer.TokenCount) and
            IsMethodNameToken(CurrentToken(ALexer, ACursor).Kind) then
          begin
            RHS := TGreenNode.Create(gnkDotAccess, LhsNode.ByteOffset, 0,
              CurrentToken(ALexer, ACursor).Lexeme);
            RHS.AppendChild(LhsNode);
            RHS.AppendChild(TGreenNode.Create(gnkIdentifier,
              CurrentToken(ALexer, ACursor).ByteOffset,
              Length(CurrentToken(ALexer, ACursor).Lexeme),
              CurrentToken(ALexer, ACursor).Lexeme));
            LhsNode := RHS;
            Inc(ACursor);
          end
          else
            Break;
        end;
      tkLBracket:
        begin
          Inc(ACursor);
          RHS := TGreenNode.Create(gnkArrayAccess, LhsNode.ByteOffset, 0, '');
          RHS.AppendChild(LhsNode);
          LhsNode := RHS;
          while (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind <> tkRBracket) do
          begin
            RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
            if RHS <> nil then
              LhsNode.AppendChild(RHS);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkComma) then
              Inc(ACursor)
            else
              Break;
          end;
          MatchTokenSilent(ALexer, ACursor, tkRBracket);
        end;
      tkCaret:
        begin
          RHS := TGreenNode.Create(gnkDereference, LhsNode.ByteOffset, 0, '');
          RHS.AppendChild(LhsNode);
          LhsNode := RHS;
          Inc(ACursor);
        end;
      tkLParen:
        begin
          Inc(ACursor);
          RHS := TGreenNode.Create(gnkFunctionCall, LhsNode.ByteOffset, 0,
            LhsNode.Text);
          RHS.AppendChild(LhsNode);
          LhsNode := RHS;
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind <> tkRParen) then
          begin
            RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
            if RHS <> nil then
              LhsNode.AppendChild(RHS);
            { Pascal format specifier: expr:width[:precision] }
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkColon) then
            begin
              Inc(ACursor);
              if (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind in
                  [tkMinus, tkPlus, tkIntegerLiteral, tkIdentifier]) then
                Inc(ACursor);
              if (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind = tkColon) then
              begin
                Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind in
                    [tkMinus, tkPlus, tkIntegerLiteral, tkIdentifier]) then
                  Inc(ACursor);
              end;
            end;
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkComma) do
            begin
              Inc(ACursor);
              RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
              if RHS <> nil then
                LhsNode.AppendChild(RHS);
              { Pascal format specifier: expr:width[:precision] }
              if (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind = tkColon) then
              begin
                Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind in
                    [tkMinus, tkPlus, tkIntegerLiteral, tkIdentifier]) then
                  Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                begin
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind in
                      [tkMinus, tkPlus, tkIntegerLiteral, tkIdentifier]) then
                    Inc(ACursor);
                end;
              end;
            end;
          end;
          MatchTokenSilent(ALexer, ACursor, tkRParen);
        end;
    else
      Break;
    end;
  end;

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkAssign) then
  begin
    Inc(ACursor);
    RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
    Node := TGreenNode.Create(gnkAssignmentStatement, NameToken.ByteOffset, 0,
      NameToken.Lexeme);
    Node.AppendChild(LhsNode);
    if RHS <> nil then
      Node.AppendChild(RHS);
    AParent.AppendChild(Node);
    Inc(ATree.FNodeCount);
  end
  else if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind in
      [tkPlusAssign, tkMinusAssign, tkStarAssign, tkSlashAssign]) then
  begin
    CompoundKind := CurrentToken(ALexer, ACursor).Kind;
    case CompoundKind of
      tkPlusAssign: CompoundOp := '+';
      tkMinusAssign: CompoundOp := '-';
      tkStarAssign: CompoundOp := '*';
      tkSlashAssign: CompoundOp := '/';
    else
      CompoundOp := '+';
    end;
    Inc(ACursor);
    RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
    Node := TGreenNode.Create(gnkAssignmentStatement, NameToken.ByteOffset, 0,
      NameToken.Lexeme);
    BinaryNode := TGreenNode.Create(gnkBinaryExpression, NameToken.ByteOffset,
      0, CompoundOp);
    BinaryNode.AppendChild(LhsNode);
    if RHS <> nil then
      BinaryNode.AppendChild(RHS);
    Node.AppendChild(BinaryNode);
    AParent.AppendChild(Node);
    Inc(ATree.FNodeCount);
  end
  else
  begin
    if LhsNode.NodeKind in [gnkFunctionCall, gnkDotAccess, gnkArrayAccess,
      gnkDereference] then
    begin
      Node := TGreenNode.Create(gnkProcedureCallStatement, NameToken.ByteOffset, 0,
        LhsNode.Text);
      Node.AppendChild(LhsNode);
      AParent.AppendChild(Node);
      Inc(ATree.FNodeCount);
    end
    else if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
    begin
      Inc(ACursor);
      Node := TGreenNode.Create(gnkProcedureCallStatement, NameToken.ByteOffset, 0,
        NameToken.Lexeme);
      { { LhsNode.Free; } // record, no Free needed } // owned by tree FFacades
      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkRParen) then
      begin
        RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
        if RHS <> nil then
          Node.AppendChild(RHS);
        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkComma) do
        begin
          Inc(ACursor);
          RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
          if RHS <> nil then
            Node.AppendChild(RHS);
        end;
      end;
      MatchTokenSilent(ALexer, ACursor, tkRParen);
      AParent.AppendChild(Node);
      Inc(ATree.FNodeCount);
    end
    else
    begin
      Node := TGreenNode.Create(gnkProcedureCallStatement, NameToken.ByteOffset, 0,
        NameToken.Lexeme);
      { { LhsNode.Free; } // record, no Free needed } // owned by tree FFacades
      AParent.AppendChild(Node);
      Inc(ATree.FNodeCount);
    end;
  end;

  Result := True;
end;

function ParseArrayBoundsRange(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode;
var
  LowExpr, HighExpr: TGreenNode;
  RangeOffset: LongInt;
begin
  Result := nil;
  LowExpr := nil;
  HighExpr := nil;
  if ACursor >= ALexer.TokenCount then
    Exit;

  RangeOffset := CurrentToken(ALexer, ACursor).ByteOffset;
  LowExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
  if LowExpr = nil then
    Exit;

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkDotDot) then
  begin
    Inc(ACursor);
    HighExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
    if HighExpr <> nil then
    begin
      Result := TGreenNode.Create(gnkRangeExpression, RangeOffset, 0, '');
      Result.AppendChild(LowExpr);
      Result.AppendChild(HighExpr);
      LowExpr := nil;
      HighExpr := nil;
    end;
  end;

  { LowExpr.Free; } // record, no Free needed
  { HighExpr.Free; } // record, no Free needed
end;

function ParseTypeReference(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const ATree: TGreenTree
): TGreenNode; overload;
var
  Token: TToken;
  NameNode, ArgNode, RangeNode: TGreenNode;
  SpecArgs: string;
  FullName: string;
  Depth: LongInt;
  function NewNode(const AKind: TGreenNodeKind; const AOff, ALen: LongInt; const ATxt: string): TGreenNode; inline;
  begin
    if ATree <> nil then
      NewNode := TGreenNode.Create(ATree, AKind, AOff, ALen, ATxt)
    else
      NewNode := TGreenNode.Create(AKind, AOff, ALen, ATxt);
  end;
begin
  if ACursor >= ALexer.TokenCount then
    Exit(nil);

  Token := CurrentToken(ALexer, ACursor);
  case Token.Kind of
    tkIdentifier:
      begin
        FullName := Token.Lexeme;
        Inc(ACursor);

        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkLBracket) then
        begin
          Inc(ACursor);
          Result := NewNode(gnkArrayType, Token.ByteOffset, 0, '');
          Result.AppendChild(NewNode(gnkIdentifier, Token.ByteOffset,
            Length(FullName), FullName));
          ArgNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
          if ArgNode <> nil then
            Result.AppendChild(ArgNode);
          MatchTokenSilent(ALexer, ACursor, tkRBracket);
          Exit;
        end;

        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkLessThan) then
        begin
          SpecArgs := '<';
          Inc(ACursor);
          Depth := 1;
          while (ACursor < ALexer.TokenCount) and (Depth > 0) and
            (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
          begin
            if CurrentToken(ALexer, ACursor).Kind = tkLessThan then
              Inc(Depth)
            else if CurrentToken(ALexer, ACursor).Kind = tkGreaterThan then
            begin
              Dec(Depth);
              if Depth = 0 then
                Break;
            end;
            SpecArgs := SpecArgs + CurrentToken(ALexer, ACursor).Lexeme;
            Inc(ACursor);
          end;
          SpecArgs := SpecArgs + '>';
          MatchTokenSilent(ALexer, ACursor, tkGreaterThan);
          FullName := FullName + SpecArgs;
        end;

        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkDot) do
        begin
          Inc(ACursor);
          if (ACursor < ALexer.TokenCount) and
            IsMethodNameToken(CurrentToken(ALexer, ACursor).Kind) then
          begin
            FullName := FullName + '.' +
              CurrentToken(ALexer, ACursor).Lexeme;
            Inc(ACursor);
          end
          else
            Break;
        end;

        Result := NewNode(gnkIdentifier, Token.ByteOffset,
          Length(FullName), FullName);
      end;
    tkStringKeyword, tkFileKeyword:
      begin
        Result := NewNode(gnkIdentifier, Token.ByteOffset,
          Length(Token.Lexeme), Token.Lexeme);
        Inc(ACursor);
      end;
    tkArrayKeyword:
      begin
        Result := NewNode(gnkArrayType, Token.ByteOffset, 0, '');
        RangeNode := nil;
        Inc(ACursor);
        if MatchTokenSilent(ALexer, ACursor, tkLBracket) then
        begin
          RangeNode := ParseArrayBoundsRange(ALexer, ACursor, ADiagnostics,
            ARootFileId);
          while (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind <> tkRBracket) and
            (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
            Inc(ACursor);
          MatchTokenSilent(ALexer, ACursor, tkRBracket);
        end;
        if MatchTokenSilent(ALexer, ACursor, tkOfKeyword) then
        begin
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkConstKeyword) then
          begin
            ArgNode := NewNode(gnkIdentifier,
              CurrentToken(ALexer, ACursor).ByteOffset,
              Length(CurrentToken(ALexer, ACursor).Lexeme),
              CurrentToken(ALexer, ACursor).Lexeme);
            Inc(ACursor);
          end
          else
            ArgNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
          if ArgNode <> nil then
            Result.AppendChild(ArgNode);
          if RangeNode <> nil then
            Result.AppendChild(RangeNode);
        end
        else
          { { RangeNode.Free; } // record, no Free needed } // owned by tree FFacades
      end;
    tkSetKeyword:
      begin
        Result := NewNode(gnkIdentifier, Token.ByteOffset, 0, 'set');
        Inc(ACursor);
        MatchTokenSilent(ALexer, ACursor, tkOfKeyword);
        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
          (CurrentToken(ALexer, ACursor).Kind <> tkRParen) and
          (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
          Inc(ACursor);
      end;
    tkCaret:
      begin
        Inc(ACursor);
        Result := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
        if Result <> nil then
        begin
          FullName := '^' + Result.Text;
          NameNode := Result;
          Result := NewNode(NameNode.NodeKind, NameNode.ByteOffset,
            Length(FullName), FullName);
          { { NameNode.Free; } // record, no Free needed } // owned by tree FFacades
        end;
      end;
    tkSpecializeKeyword:
      begin
        Inc(ACursor);
        Result := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
        if (Result <> nil) and (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkLessThan) then
        begin
          SpecArgs := '<';
          Inc(ACursor);
          Depth := 1;
          while (ACursor < ALexer.TokenCount) and (Depth > 0) and
            (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
          begin
            if CurrentToken(ALexer, ACursor).Kind = tkLessThan then
              Inc(Depth)
            else if CurrentToken(ALexer, ACursor).Kind = tkGreaterThan then
            begin
              Dec(Depth);
              if Depth = 0 then
                Break;
            end;
            SpecArgs := SpecArgs + CurrentToken(ALexer, ACursor).Lexeme;
            Inc(ACursor);
          end;
          SpecArgs := SpecArgs + '>';
          MatchTokenSilent(ALexer, ACursor, tkGreaterThan);
          FullName := Result.Text + SpecArgs;
          NameNode := Result;
          Result := NewNode(NameNode.NodeKind, NameNode.ByteOffset,
            Length(FullName), FullName);
          { { NameNode.Free; } // record, no Free needed } // owned by tree FFacades
        end;
      end;
    tkReferenceKeyword:
      begin
        Inc(ACursor); // consume 'reference'
        if MatchTokenSilent(ALexer, ACursor, tkToKeyword) and
          (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind in
            [tkProcedureKeyword, tkFunctionKeyword]) then
        begin
          Inc(ACursor); // consume 'procedure'/'function'
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
          begin
            Inc(ACursor);
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkRParen) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
              Inc(ACursor);
            MatchTokenSilent(ALexer, ACursor, tkRParen);
          end;
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkColon) then
          begin
            Inc(ACursor);
            NameNode := ParseTypeReference(
              ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
            { { NameNode.Free; } // record, no Free needed } // owned by tree FFacades
          end;
        end;
        Result := NewNode(gnkIdentifier, Token.ByteOffset,
          Length(Token.Lexeme), Token.Lexeme);
      end;
    tkRecordKeyword, tkObjectKeyword:
      begin
        if Token.Kind = tkRecordKeyword then
          Result := NewNode(gnkRecordType, Token.ByteOffset, 0, '')
        else
          Result := NewNode(gnkRecordType, Token.ByteOffset, 0, 'object');
        Inc(ACursor);
        SkipDirectives(ALexer, ACursor);
        Depth := 1;
        while (ACursor < ALexer.TokenCount) and (Depth > 0) and
          (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        begin
          if CurrentToken(ALexer, ACursor).Kind = tkRecordKeyword then
          begin
            if (ACursor > 0) and
              (ALexer.TokenAt(ACursor - 1).Kind <> tkOfKeyword) then
              Inc(Depth);
          end
          else if CurrentToken(ALexer, ACursor).Kind = tkCaseKeyword then
          begin
            if (ACursor > 0) and
              (ALexer.TokenAt(ACursor - 1).Kind <> tkOfKeyword) then
              Inc(Depth);
          end
          else if CurrentToken(ALexer, ACursor).Kind = tkEndKeyword then
            Dec(Depth);
          if Depth > 0 then
            Inc(ACursor);
        end;
        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkEndKeyword) then
          Inc(ACursor);
      end;
  else
    Exit(nil);
  end;
end;


function ParseTypeReference(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode; overload;
begin
  Result := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ActiveExpressionTree);
end;
