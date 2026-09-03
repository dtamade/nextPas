procedure TLexerResult.LexSource(const ASourceText: string);
var
  CurrentChar: Char;
  ExponentSaveIndex: SizeInt;
  IsReal: Boolean;
  Lexeme: string;
  NumberStartIndex: SizeInt;
  SaveIndex: SizeInt;
  StartIndex: SizeInt;
  TokenLine: LongInt;
  TokenColumn: LongInt;
  ClosedFlag: Boolean;
  SawQuoted: Boolean;
  LEnd: SizeInt;
  IdLen: SizeInt;
  Kind: TTokenKind;
begin
  StartIndex := 1;
  if (Length(ASourceText) >= 3) and
    (ASourceText[1] = #$EF) and
    (ASourceText[2] = #$BB) and
    (ASourceText[3] = #$BF) then
  begin
    StartIndex := 4;
    FLineStartByte := 3;
  end;
  while StartIndex <= Length(ASourceText) do
  begin
    CurrentChar := ASourceText[StartIndex];
    if (CurrentChar = #13) or (CurrentChar = #10) then
    begin
      SaveIndex := StartIndex;
      AdvanceNewline(ASourceText, StartIndex);
      CapturePendingTrivia(tvkLineTerminator,
        SaveIndex - 1, StartIndex - SaveIndex);
      Continue;
    end;
    if CurrentChar in [#0..#32] then
    begin
      SaveIndex := StartIndex;
      while (StartIndex <= Length(ASourceText)) and
        (ASourceText[StartIndex] in [#0..#32]) and
        (ASourceText[StartIndex] <> #10) and
        (ASourceText[StartIndex] <> #13) do
        Inc(StartIndex);
      CapturePendingTrivia(tvkWhitespace,
        SaveIndex - 1, StartIndex - SaveIndex);
      Continue;
    end;
    TokenLine := FCurrentLine;
    TokenColumn := StartIndex - FLineStartByte;
    if TokenColumn < 1 then
      TokenColumn := 1;
    if CurrentChar = '{' then
    begin
      SaveIndex := StartIndex;
      if TryReadCompilerDirectiveTracking(ASourceText, StartIndex, Lexeme, ClosedFlag) then
      begin
        AddTokenAt(tkCompilerDirective, Lexeme, SaveIndex, TokenLine);
        if not ClosedFlag then
          ReportError(
            'lexer.unterminated-compiler-directive',
            SaveIndex - 1,
            'compiler directive started with "{$" at line ' + IntToStr(TokenLine) + ', col ' + IntToStr(TokenColumn) + ' near "' + ContextSnippet(ASourceText, SaveIndex) + '" reached EOF without "}"'
          );
        Continue;
      end;
      SkipBraceCommentTracking(ASourceText, StartIndex, ClosedFlag);
      if ClosedFlag then
        CapturePendingTrivia(tvkBraceComment,
          SaveIndex - 1, StartIndex - SaveIndex)
      else
      begin
        AddTokenAtPos(tkError, '{', SaveIndex, TokenLine, TokenColumn);
        ReportError(
          'lexer.unterminated-brace-comment',
          SaveIndex - 1,
          'brace comment started with "{" at line ' + IntToStr(TokenLine) + ', col ' + IntToStr(TokenColumn) + ' near "' + ContextSnippet(ASourceText, SaveIndex) + '" reached EOF without "}"'
        );
      end;
      Continue;
    end;
    if (CurrentChar = '(') and
      (StartIndex < Length(ASourceText)) and
      (ASourceText[StartIndex + 1] = '*') then
    begin
      SaveIndex := StartIndex;
      if TryReadParenStarDirectiveTracking(ASourceText, StartIndex, Lexeme, ClosedFlag) then
      begin
        AddTokenAt(tkCompilerDirective, Lexeme, SaveIndex, TokenLine);
        if not ClosedFlag then
          ReportError(
            'lexer.unterminated-compiler-directive',
            SaveIndex - 1,
            'compiler directive started with "(*$" at line ' + IntToStr(TokenLine) + ', col ' + IntToStr(TokenColumn) + ' near "' + ContextSnippet(ASourceText, SaveIndex) + '" reached EOF without "*)"'
          );
        Continue;
      end;
      SkipParenStarCommentTracking(ASourceText, StartIndex, ClosedFlag);
      if ClosedFlag then
        CapturePendingTrivia(tvkParenStarComment,
          SaveIndex - 1, StartIndex - SaveIndex)
      else
      begin
        AddTokenAtPos(tkError, '(*', SaveIndex, TokenLine, TokenColumn);
        ReportError(
          'lexer.unterminated-paren-star-comment',
          SaveIndex - 1,
          'paren-star comment started with "(*" at line ' + IntToStr(TokenLine) + ', col ' + IntToStr(TokenColumn) + ' near "' + ContextSnippet(ASourceText, SaveIndex) + '" reached EOF without "*)"'
        );
      end;
      Continue;
    end;
    if (CurrentChar = '/') and
      (StartIndex < Length(ASourceText)) and
      (ASourceText[StartIndex + 1] = '/') then
    begin
      SaveIndex := StartIndex;
      SkipLineComment(ASourceText, StartIndex);
      CapturePendingTrivia(tvkLineComment,
        SaveIndex - 1, StartIndex - SaveIndex);
      Continue;
    end;
    if (CurrentChar = '''') or (CurrentChar = '#') or
       ((CurrentChar = '^') and (StartIndex < Length(ASourceText)) and
        IsControlCharLetter(ASourceText[StartIndex + 1]) and
        ((StartIndex + 1 >= Length(ASourceText)) or
         not (ASourceText[StartIndex + 2] in ['A'..'Z', 'a'..'z', '0'..'9', '_']))) then
    begin
      SaveIndex := StartIndex;
      { zero-copy string scan: advance without intermediate Copy, then interned Extract }
      AdvanceStringLiteral(ASourceText, StartIndex, ClosedFlag, SawQuoted);
      if StartIndex = SaveIndex then
      begin
        AddTokenAt(tkError, CurrentChar, SaveIndex, TokenLine);
        ReportError(
          'lexer.invalid-char-code',
          SaveIndex - 1,
          'expected decimal digits, "$", or quoted string after "' + CurrentChar + '" at line ' + IntToStr(TokenLine) + ', col ' + IntToStr(TokenColumn) + ' near "' + ContextSnippet(ASourceText, SaveIndex) + '"'
        );
        Inc(StartIndex);
        Continue;
      end;
      Lexeme := ExtractLexeme(ASourceText, SaveIndex, StartIndex - SaveIndex);
      if Length(Lexeme) = 0 then
      begin
        AddTokenAt(tkError, CurrentChar, SaveIndex, TokenLine);
        ReportError(
          'lexer.invalid-char-code',
          SaveIndex - 1,
          'expected decimal digits, "$", or quoted string after "' + CurrentChar + '" at line ' + IntToStr(TokenLine) + ', col ' + IntToStr(TokenColumn) + ' near "' + ContextSnippet(ASourceText, SaveIndex) + '"'
        );
        Inc(StartIndex);
        Continue;
      end;
      if SawQuoted then
        AddTokenAt(tkStringLiteral, Lexeme, SaveIndex, TokenLine)
      else
        AddTokenAt(tkCharLiteral, Lexeme, SaveIndex, TokenLine);
      if not ClosedFlag then
        ReportError(
          'lexer.unterminated-string-literal',
          SaveIndex - 1,
          'string literal started at byte ' + IntToStr(SaveIndex - 1) + ' (line ' + IntToStr(TokenLine) + ', col ' + IntToStr(TokenColumn) + ') near "' + ContextSnippet(ASourceText, SaveIndex) + '" was not terminated before EOL/EOF'
        );
      Continue;
    end;
    if CurrentChar = '^' then
    begin
      AddTokenAt(tkCaret, '^', StartIndex, TokenLine);
      Inc(StartIndex);
      Continue;
    end;
    if (CurrentChar = '&') and (StartIndex + 1 <= Length(ASourceText)) and
       IsIdentifierStart(ASourceText[StartIndex + 1]) then
    begin
      SaveIndex := StartIndex;
      Inc(StartIndex, 2);
      while (StartIndex <= Length(ASourceText)) and
        IsIdentifierContinue(ASourceText[StartIndex]) do
        Inc(StartIndex);
      Lexeme := ExtractLexeme(ASourceText, SaveIndex + 1, StartIndex - SaveIndex - 1);
      AddTokenAt(tkIdentifier, Lexeme, SaveIndex, TokenLine);
      Continue;
    end;
    if (CurrentChar = '$') or (CurrentChar = '&') or
       ((CurrentChar = '%') and (StartIndex + 1 <= Length(ASourceText)) and
        (ASourceText[StartIndex + 1] in ['0', '1'])) or
       IsDigit(CurrentChar) then
    begin
      SaveIndex := StartIndex;
      if not TryAdvanceIntegerLiteral(ASourceText, StartIndex) then
      begin
        AddTokenAt(tkError, CurrentChar, SaveIndex, TokenLine);
        case CurrentChar of
          '$':
            ReportError(
              'lexer.invalid-numeric-literal',
              SaveIndex - 1,
              'expected hex digits after "$" at line ' + IntToStr(TokenLine) + ', col ' + IntToStr(TokenColumn) + ' near "' + ContextSnippet(ASourceText, SaveIndex) + '"'
            );
          '&':
            ReportError(
              'lexer.invalid-numeric-literal',
              SaveIndex - 1,
              'expected octal digits (0-7) after "&" at line ' + IntToStr(TokenLine) + ', col ' + IntToStr(TokenColumn) + ' near "' + ContextSnippet(ASourceText, SaveIndex) + '"'
            );
          '%':
            ReportError(
              'lexer.invalid-numeric-literal',
              SaveIndex - 1,
              'expected binary digits (0 or 1) after "%" at line ' + IntToStr(TokenLine) + ', col ' + IntToStr(TokenColumn) + ' near "' + ContextSnippet(ASourceText, SaveIndex) + '"'
            );
        end;
        Inc(StartIndex);
        Continue;
      end;
      NumberStartIndex := SaveIndex;
      IsReal := False;
      if (CurrentChar <> '$') and (CurrentChar <> '&') and
         (CurrentChar <> '%') and
        (StartIndex <= Length(ASourceText)) and (ASourceText[StartIndex] = '.') and
        ((StartIndex >= Length(ASourceText)) or (ASourceText[StartIndex + 1] <> '.')) then
      begin
        if (StartIndex + 1 <= Length(ASourceText)) and IsDigit(ASourceText[StartIndex + 1]) then
        begin
          Inc(StartIndex);
          while (StartIndex <= Length(ASourceText)) and IsDigit(ASourceText[StartIndex]) do
            Inc(StartIndex);
          IsReal := True;
          if (StartIndex <= Length(ASourceText)) and
            ((ASourceText[StartIndex] = 'e') or (ASourceText[StartIndex] = 'E')) then
          begin
            ExponentSaveIndex := StartIndex;
            Inc(StartIndex);
            if (StartIndex <= Length(ASourceText)) and
              ((ASourceText[StartIndex] = '+') or (ASourceText[StartIndex] = '-')) then
              Inc(StartIndex);
            if (StartIndex <= Length(ASourceText)) and IsDigit(ASourceText[StartIndex]) then
            begin
              while (StartIndex <= Length(ASourceText)) and IsDigit(ASourceText[StartIndex]) do
                Inc(StartIndex);
            end
            else
              StartIndex := ExponentSaveIndex;
          end;
        end
        else if (StartIndex + 1 <= Length(ASourceText)) and
          ((ASourceText[StartIndex + 1] = 'e') or (ASourceText[StartIndex + 1] = 'E')) then
        begin
          ExponentSaveIndex := StartIndex;
          Inc(StartIndex, 2);
          if (StartIndex <= Length(ASourceText)) and
            ((ASourceText[StartIndex] = '+') or (ASourceText[StartIndex] = '-')) then
            Inc(StartIndex);
          if (StartIndex <= Length(ASourceText)) and IsDigit(ASourceText[StartIndex]) then
          begin
            while (StartIndex <= Length(ASourceText)) and IsDigit(ASourceText[StartIndex]) do
              Inc(StartIndex);
            IsReal := True;
          end
          else
            StartIndex := ExponentSaveIndex;
        end;
      end
      else if (CurrentChar <> '$') and (CurrentChar <> '&') and
        (CurrentChar <> '%') and (StartIndex <= Length(ASourceText)) and
        ((ASourceText[StartIndex] = 'e') or (ASourceText[StartIndex] = 'E')) then
      begin
        ExponentSaveIndex := StartIndex;
        Inc(StartIndex);
        if (StartIndex <= Length(ASourceText)) and
          ((ASourceText[StartIndex] = '+') or (ASourceText[StartIndex] = '-')) then
          Inc(StartIndex);
        if (StartIndex <= Length(ASourceText)) and IsDigit(ASourceText[StartIndex]) then
        begin
          while (StartIndex <= Length(ASourceText)) and IsDigit(ASourceText[StartIndex]) do
            Inc(StartIndex);
          IsReal := True;
        end
        else
          StartIndex := ExponentSaveIndex;
      end;
      Lexeme := ExtractLexeme(ASourceText, NumberStartIndex, StartIndex - NumberStartIndex);
      if IsReal then
        AddTokenAt(tkRealLiteral, Lexeme, NumberStartIndex, TokenLine)
      else
        AddTokenAt(tkIntegerLiteral, Lexeme, NumberStartIndex, TokenLine);
      Continue;
    end;
    if IsIdentifierStart(CurrentChar) then
    begin
      SaveIndex := StartIndex;
      Inc(StartIndex);
      while (StartIndex <= Length(ASourceText)) and
        IsIdentifierContinue(ASourceText[StartIndex]) do
        Inc(StartIndex);
      IdLen := StartIndex - SaveIndex;
      Kind := ResolveIdentifierKindSlice(ASourceText, SaveIndex, IdLen);
      Lexeme := ExtractLexeme(ASourceText, SaveIndex, IdLen);
      AddTokenAt(Kind, Lexeme, SaveIndex, TokenLine);
      Continue;
    end;
    case CurrentChar of
      ';':
        AddTokenAt(tkSemicolon, ';', StartIndex, TokenLine);
      '.':
        begin
          if (StartIndex < Length(ASourceText)) and
            (ASourceText[StartIndex + 1] = '.') then
          begin
            AddTokenAt(tkDotDot, '..', StartIndex, TokenLine);
            Inc(StartIndex);
          end
          else
            AddTokenAt(tkDot, '.', StartIndex, TokenLine);
        end;
      ',':
        AddTokenAt(tkComma, ',', StartIndex, TokenLine);
      ':':
        begin
          if (StartIndex < Length(ASourceText)) and
            (ASourceText[StartIndex + 1] = '=') then
          begin
            AddTokenAt(tkAssign, ':=', StartIndex, TokenLine);
            Inc(StartIndex);
          end
          else
            AddTokenAt(tkColon, ':', StartIndex, TokenLine);
        end;
      '+':
        begin
          if (StartIndex < Length(ASourceText)) and
            (ASourceText[StartIndex + 1] = '=') then
          begin
            AddTokenAt(tkPlusAssign, '+=', StartIndex, TokenLine);
            Inc(StartIndex);
          end
          else
            AddTokenAt(tkPlus, '+', StartIndex, TokenLine);
        end;
      '-':
        begin
          if (StartIndex < Length(ASourceText)) and
            (ASourceText[StartIndex + 1] = '=') then
          begin
            AddTokenAt(tkMinusAssign, '-=', StartIndex, TokenLine);
            Inc(StartIndex);
          end
          else
            AddTokenAt(tkMinus, '-', StartIndex, TokenLine);
        end;
      '*':
        begin
          if (StartIndex < Length(ASourceText)) and
            (ASourceText[StartIndex + 1] = '=') then
          begin
            AddTokenAt(tkStarAssign, '*=', StartIndex, TokenLine);
            Inc(StartIndex);
          end
          else
            AddTokenAt(tkStar, '*', StartIndex, TokenLine);
        end;
      '/':
        begin
          if (StartIndex < Length(ASourceText)) and
            (ASourceText[StartIndex + 1] = '=') then
          begin
            AddTokenAt(tkSlashAssign, '/=', StartIndex, TokenLine);
            Inc(StartIndex);
          end
          else
            AddTokenAt(tkSlash, '/', StartIndex, TokenLine);
        end;
      '=':
        AddTokenAt(tkEquals, '=', StartIndex, TokenLine);
      '<':
        begin
          if (StartIndex < Length(ASourceText)) and
            (ASourceText[StartIndex + 1] = '>') then
          begin
            AddTokenAt(tkNotEquals, '<>', StartIndex, TokenLine);
            Inc(StartIndex);
          end
          else if (StartIndex < Length(ASourceText)) and
            (ASourceText[StartIndex + 1] = '=') then
          begin
            AddTokenAt(tkLessEqual, '<=', StartIndex, TokenLine);
            Inc(StartIndex);
          end
          else
            AddTokenAt(tkLessThan, '<', StartIndex, TokenLine);
        end;
      '>':
        begin
          if (StartIndex < Length(ASourceText)) and
            (ASourceText[StartIndex + 1] = '=') then
          begin
            AddTokenAt(tkGreaterEqual, '>=', StartIndex, TokenLine);
            Inc(StartIndex);
          end
          else
            AddTokenAt(tkGreaterThan, '>', StartIndex, TokenLine);
        end;
      '(':
        AddTokenAt(tkLParen, '(', StartIndex, TokenLine);
      ')':
        AddTokenAt(tkRParen, ')', StartIndex, TokenLine);
      '[':
        AddTokenAt(tkLBracket, '[', StartIndex, TokenLine);
      ']':
        AddTokenAt(tkRBracket, ']', StartIndex, TokenLine);
      '@':
        AddTokenAt(tkAt, '@', StartIndex, TokenLine);
      '%':
        begin
          if (StartIndex + 1 <= Length(ASourceText)) and
            (ASourceText[StartIndex + 1] in ['a'..'z', 'A'..'Z', '_']) then
          begin
            LEnd := StartIndex + 2;
            while (LEnd <= Length(ASourceText)) and
              (ASourceText[LEnd] in ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
              Inc(LEnd);
            Lexeme := ExtractLexeme(ASourceText, StartIndex, LEnd - StartIndex);
            AddTokenAt(tkIdentifier, Lexeme, StartIndex, TokenLine);
            StartIndex := LEnd - 1;
          end
          else
            AddTokenAt(tkIdentifier, '%', StartIndex, TokenLine);
        end;
    else
      begin
        AddTokenAt(tkError, CurrentChar, StartIndex, TokenLine);
        ReportError(
          'lexer.illegal-character',
          StartIndex - 1,
          'illegal character "' + CurrentChar + '" (byte $' + IntToHex(Ord(CurrentChar), 2) + ') at line ' + IntToStr(TokenLine) + ', col ' + IntToStr(TokenColumn) + ' near "' + ContextSnippet(ASourceText, StartIndex) + '" in source'
        );
      end;
    end;
    Inc(StartIndex);
  end;
  AddToken(
    tkEOF, '', Length(ASourceText),
    FCurrentLine,
    Length(ASourceText) - FLineStartByte + 1
  );
end;
