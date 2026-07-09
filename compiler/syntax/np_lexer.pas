unit np_lexer;

{$mode objfpc}{$H+}
{$UNITPATH ../diagnostics}
{$UNITPATH ../../rtl/core/base}

interface

uses
  nextpas.core.text.conv, np_base_types, np_diagnostics_sink;

type
  TTokenKind = (
    tkUnknown,
    tkError,
    tkProgramKeyword,
    tkUnitKeyword,
    tkLibraryKeyword,
    tkPackageKeyword,
    tkUsesKeyword,
    tkInterfaceKeyword,
    tkImplementationKeyword,
    tkProcedureKeyword,
    tkExternalKeyword,
    tkNameKeyword,
    tkCdeclKeyword,
    tkBeginKeyword,
    tkEndKeyword,
    tkIfKeyword,
    tkThenKeyword,
    tkElseKeyword,
    tkWhileKeyword,
    tkDoKeyword,
    tkForKeyword,
    tkToKeyword,
    tkDownToKeyword,
    tkRepeatKeyword,
    tkUntilKeyword,
    tkWithKeyword,
    tkCaseKeyword,
    tkOfKeyword,
    tkGotoKeyword,
    tkBreakKeyword,
    tkContinueKeyword,
    tkExitKeyword,
    tkVarKeyword,
    tkConstKeyword,
    tkConstRefKeyword,
    tkTypeKeyword,
    tkFunctionKeyword,
    tkArrayKeyword,
    tkSetKeyword,
    tkRecordKeyword,
    tkStringKeyword,
    tkClassKeyword,
    tkObjectKeyword,
    tkConstructorKeyword,
    tkDestructorKeyword,
    tkPropertyKeyword,
    tkInitializationKeyword,
    tkFinalizationKeyword,
    tkExportsKeyword,
    tkLabelKeyword,
    tkThreadVarKeyword,
    tkPublishedKeyword,
    tkPublicKeyword,
    tkPrivateKeyword,
    tkProtectedKeyword,
    tkVirtualKeyword,
    tkOverrideKeyword,
    tkAbstractKeyword,
    tkReintroduceKeyword,
    tkOverloadKeyword,
    tkDynamicKeyword,
    tkMessageKeyword,
    tkStaticKeyword,
    tkInlineKeyword,
    tkForwardKeyword,
    tkDeprecatedKeyword,
    tkPlatformKeyword,
    tkExperimentalKeyword,
    tkStdCallKeyword,
    tkSafeCallKeyword,
    tkRegisterKeyword,
    tkPascalKeyword,
    tkFarKeyword,
    tkNearKeyword,
    tkCppDeclKeyword,
    tkVarArgsKeyword,
    tkOutKeyword,
    tkAbsoluteKeyword,
    tkAsmKeyword,
    tkAndKeyword,
    tkOrKeyword,
    tkNotKeyword,
    tkXorKeyword,
    tkShlKeyword,
    tkShrKeyword,
    tkDivKeyword,
    tkModKeyword,
    tkInKeyword,
    tkIsKeyword,
    tkAsKeyword,
    tkNilKeyword,
    tkRaiseKeyword,
    tkTryKeyword,
    tkExceptKeyword,
    tkFinallyKeyword,
    tkOnKeyword,
    tkInheritedKeyword,
    tkSelfKeyword,
    tkFileKeyword,
    tkResourceStringKeyword,
    tkStrictKeyword,
    tkOperatorKeyword,
    tkGenericKeyword,
    tkSpecializeKeyword,
    tkReferenceKeyword,
    tkPackedKeyword,
    tkContainsKeyword,
    tkRequiresKeyword,
    tkIdentifier,
    tkStringLiteral,
    tkIntegerLiteral,
    tkRealLiteral,
    tkCharLiteral,
    tkCompilerDirective,
    tkSemicolon,
    tkDot,
    tkDotDot,
    tkComma,
    tkColon,
    tkAssign,
    tkPlusAssign,
    tkMinusAssign,
    tkStarAssign,
    tkSlashAssign,
    tkLParen,
    tkRParen,
    tkLBracket,
    tkRBracket,
    tkPlus,
    tkMinus,
    tkStar,
    tkSlash,
    tkEquals,
    tkNotEquals,
    tkLessThan,
    tkGreaterThan,
    tkLessEqual,
    tkGreaterEqual,
    tkAt,
    tkCaret,
    tkEOF
  );

  TTriviaKind = (
    tvkWhitespace,
    tvkLineTerminator,
    tvkLineComment,
    tvkBraceComment,
    tvkParenStarComment
  );

  TTriviaPiece = record
    Kind: TTriviaKind;
    ByteOffset: LongInt;
    Length: LongInt;
  end;

  TTriviaPieces = array of TTriviaPiece;

  TToken = record
    Kind: TTokenKind;
    Lexeme: string;
    FileId: TCoreId;
    ByteOffset: LongInt;
    Line: LongInt;
    Column: LongInt;
    LeadingTrivia: TTriviaPieces;
    TrailingTrivia: TTriviaPieces;
  end;

  TLexerResult = class
  private
    FTokens: array of TToken;
    FTokenCount: SizeInt;
    FCurrentLine: LongInt;
    FLineStartByte: LongInt;
    FDiagnostics: TDiagnosticsSink;
    FFileId: TCoreId;
    FPendingTrivia: TTriviaPieces;
    procedure ReportError(
      const ACode: string;
      const AByteOffset: LongInt;
      const AMessageText: string
    );
    procedure CapturePendingTrivia(
      const AKind: TTriviaKind;
      const AByteOffset: LongInt;
      const ALength: LongInt
    );
    procedure FlushPendingTriviaToToken(const ATokenIndex: SizeInt);
    procedure AdvanceNewline(
      const ASourceText: string;
      var AIndex: SizeInt
    );
    function CurrentColumn(const AIndex: SizeInt): LongInt;
    procedure SkipBraceCommentTracking(
      const ASourceText: string;
      var AIndex: SizeInt;
      out AClosed: Boolean
    );
    procedure SkipParenStarCommentTracking(
      const ASourceText: string;
      var AIndex: SizeInt;
      out AClosed: Boolean
    );
    function TryReadCompilerDirectiveTracking(
      const ASourceText: string;
      var AIndex: SizeInt;
      out ALexeme: string;
      out AClosed: Boolean
    ): Boolean;
    function TryReadParenStarDirectiveTracking(
      const ASourceText: string;
      var AIndex: SizeInt;
      out ALexeme: string;
      out AClosed: Boolean
    ): Boolean;
    procedure AddToken(
      const AKind: TTokenKind;
      const ALexeme: string;
      const AByteOffset: LongInt;
      const ALine: LongInt;
      const AColumn: LongInt
    );
    procedure AddTokenAt(
      const AKind: TTokenKind;
      const ALexeme: string;
      const AStartIndex: SizeInt;
      const ALine: LongInt
    );
    procedure AddTokenAtPos(
      const AKind: TTokenKind;
      const ALexeme: string;
      const AStartIndex: SizeInt;
      const ALine: LongInt;
      const AColumn: LongInt
    );
    procedure LexSource(const ASourceText: string);
  public
    constructor Create(const ASourceText: string); overload;
    constructor Create(
      const ASourceText: string;
      const ADiagnostics: TDiagnosticsSink;
      const AFileId: TCoreId
    ); overload;
    constructor CreateFromTokens(const ATokens: array of TToken;
      const ACount: LongInt);
    function TokenCount: LongInt;
    function TokenAt(const AIndex: LongInt): TToken;
  end;

function TokenKindName(const AKind: TTokenKind): string;

implementation

{$I np_lexer_helpers.inc}
procedure TLexerResult.LexSource(const ASourceText: string);
var
  CurrentChar: Char;
  ExponentSaveIndex: SizeInt;
  IntegerLexeme: string;
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
begin
  StartIndex := 1;
  { Skip UTF-8 BOM (EF BB BF) at the start of the source so the
    first real token still reports line=1, column=1. The 3 BOM
    bytes are simply not part of the token stream; their byte
    positions remain real (next token's ByteOffset = 3). }
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
            'compiler directive started with "{$" reached end-of-file without "}"'
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
          'brace comment started with "{" reached end-of-file without "}"'
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
            'compiler directive started with "(*$" reached end-of-file without "*)"'
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
          'paren-star comment started with "(*" reached end-of-file without "*)"'
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
      Lexeme := ReadStringLiteral(ASourceText, StartIndex, ClosedFlag, SawQuoted);
      if Length(Lexeme) = 0 then
      begin
        { Defensive: char-code prefix without any valid digits. }
        AddTokenAt(tkError, CurrentChar, SaveIndex, TokenLine);
        ReportError(
          'lexer.invalid-char-code',
          SaveIndex - 1,
          'expected decimal digits, "$", or quoted string after "' +
            CurrentChar + '"'
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
          'string literal started at byte ' + IntToStr(SaveIndex - 1) +
            ' was not terminated before end-of-line or end-of-file'
        );
      Continue;
    end;

    if CurrentChar = '^' then
    begin
      AddTokenAt(tkCaret, '^', StartIndex, TokenLine);
      Inc(StartIndex);
      Continue;
    end;

    { &keyword 逃逸标识符: & 后跟标识符首字符 → tkIdentifier }
    { 语法糖: & 不是标识符的一部分，Lexeme 不含 & }
    if (CurrentChar = '&') and (StartIndex + 1 <= Length(ASourceText)) and
       IsIdentifierStart(ASourceText[StartIndex + 1]) then
    begin
      SaveIndex := StartIndex; { '&' position, 用于 ByteOffset }
      Inc(StartIndex, 2); { skip '&' + first identifier char }
      while (StartIndex <= Length(ASourceText)) and
        IsIdentifierContinue(ASourceText[StartIndex]) do
        Inc(StartIndex);
      Lexeme := Copy(ASourceText, SaveIndex + 1, StartIndex - SaveIndex - 1);
      AddTokenAt(tkIdentifier, Lexeme, SaveIndex, TokenLine);
      Continue;
    end;

    if (CurrentChar = '$') or (CurrentChar = '&') or
       ((CurrentChar = '%') and (StartIndex + 1 <= Length(ASourceText)) and
        (ASourceText[StartIndex + 1] in ['0', '1'])) or
       IsDigit(CurrentChar) then
    begin
      SaveIndex := StartIndex;
      if not ReadIntegerLiteral(ASourceText, StartIndex, IntegerLexeme) then
      begin
        AddTokenAt(tkError, CurrentChar, SaveIndex, TokenLine);
        case CurrentChar of
          '$':
            ReportError(
              'lexer.invalid-numeric-literal',
              SaveIndex - 1,
              'expected hexadecimal digits after "$"'
            );
          '&':
            ReportError(
              'lexer.invalid-numeric-literal',
              SaveIndex - 1,
              'expected octal digits (0-7) after "&"'
            );
          '%':
            ReportError(
              'lexer.invalid-numeric-literal',
              SaveIndex - 1,
              'expected binary digits (0 or 1) after "%"'
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
      IntegerLexeme := Copy(ASourceText, NumberStartIndex,
        StartIndex - NumberStartIndex);
      if IsReal then
        AddTokenAt(tkRealLiteral, IntegerLexeme, NumberStartIndex, TokenLine)
      else
        AddTokenAt(tkIntegerLiteral, IntegerLexeme, NumberStartIndex, TokenLine);
      Continue;
    end;

    if IsIdentifierStart(CurrentChar) then
    begin
      SaveIndex := StartIndex;
      Inc(StartIndex);
      while (StartIndex <= Length(ASourceText)) and
        IsIdentifierContinue(ASourceText[StartIndex]) do
        Inc(StartIndex);
      Lexeme := Copy(ASourceText, SaveIndex, StartIndex - SaveIndex);
      AddTokenAt(ResolveIdentifierKind(Lexeme), Lexeme, SaveIndex, TokenLine);
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
          { AT&T assembly register prefix: %rax, %rdi, etc.
            Treat % followed by alpha as an identifier for asm compatibility.
            After this block, the main Inc(StartIndex) advances past %. }
          if (StartIndex + 1 <= Length(ASourceText)) and
            (ASourceText[StartIndex + 1] in ['a'..'z', 'A'..'Z', '_']) then
          begin
            { %register: scan full register name, emit as single identifier }
            LEnd := StartIndex + 2;
            while (LEnd <= Length(ASourceText)) and
              (ASourceText[LEnd] in ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
              Inc(LEnd);
            AddTokenAt(tkIdentifier,
              Copy(ASourceText, StartIndex, LEnd - StartIndex),
              StartIndex, TokenLine);
            StartIndex := LEnd - 1; { -1 because main loop does Inc }
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
          'illegal character "' + CurrentChar + '" (byte $' +
            IntToHex(Ord(CurrentChar), 2) + ') in source'
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

function TLexerResult.TokenCount: LongInt;
begin
  Result := FTokenCount;
end;

function TLexerResult.TokenAt(const AIndex: LongInt): TToken;
begin
  if (AIndex < 0) or (AIndex >= FTokenCount) then
  begin
    Result.Kind := tkEOF;
    Result.Lexeme := '';
    Result.ByteOffset := 0;
    Exit;
  end;

  Result := FTokens[AIndex];
end;

function TokenKindName(const AKind: TTokenKind): string;
begin
  case AKind of
    tkProgramKeyword: Result := 'program';
    tkUnitKeyword: Result := 'unit';
    tkLibraryKeyword: Result := 'library';
    tkPackageKeyword: Result := 'package';
    tkUsesKeyword: Result := 'uses';
    tkInterfaceKeyword: Result := 'interface';
    tkImplementationKeyword: Result := 'implementation';
    tkProcedureKeyword: Result := 'procedure';
    tkFunctionKeyword: Result := 'function';
    tkExternalKeyword: Result := 'external';
    tkNameKeyword: Result := 'name';
    tkCdeclKeyword: Result := 'cdecl';
    tkBeginKeyword: Result := 'begin';
    tkEndKeyword: Result := 'end';
    tkIfKeyword: Result := 'if';
    tkThenKeyword: Result := 'then';
    tkElseKeyword: Result := 'else';
    tkWhileKeyword: Result := 'while';
    tkDoKeyword: Result := 'do';
    tkForKeyword: Result := 'for';
    tkToKeyword: Result := 'to';
    tkDownToKeyword: Result := 'downto';
    tkRepeatKeyword: Result := 'repeat';
    tkUntilKeyword: Result := 'until';
    tkWithKeyword: Result := 'with';
    tkCaseKeyword: Result := 'case';
    tkOfKeyword: Result := 'of';
    tkGotoKeyword: Result := 'goto';
    tkBreakKeyword: Result := 'break';
    tkContinueKeyword: Result := 'continue';
    tkExitKeyword: Result := 'exit';
    tkVarKeyword: Result := 'var';
    tkConstKeyword: Result := 'const';
    tkConstRefKeyword: Result := 'constref';
    tkTypeKeyword: Result := 'type';
    tkArrayKeyword: Result := 'array';
    tkSetKeyword: Result := 'set';
    tkRecordKeyword: Result := 'record';
    tkStringKeyword: Result := 'string';
    tkClassKeyword: Result := 'class';
    tkObjectKeyword: Result := 'object';
    tkConstructorKeyword: Result := 'constructor';
    tkDestructorKeyword: Result := 'destructor';
    tkPropertyKeyword: Result := 'property';
    tkInitializationKeyword: Result := 'initialization';
    tkFinalizationKeyword: Result := 'finalization';
    tkExportsKeyword: Result := 'exports';
    tkLabelKeyword: Result := 'label';
    tkThreadVarKeyword: Result := 'threadvar';
    tkPublishedKeyword: Result := 'published';
    tkPublicKeyword: Result := 'public';
    tkPrivateKeyword: Result := 'private';
    tkProtectedKeyword: Result := 'protected';
    tkVirtualKeyword: Result := 'virtual';
    tkOverrideKeyword: Result := 'override';
    tkAbstractKeyword: Result := 'abstract';
    tkReintroduceKeyword: Result := 'reintroduce';
    tkOverloadKeyword: Result := 'overload';
    tkDynamicKeyword: Result := 'dynamic';
    tkMessageKeyword: Result := 'message';
    tkStaticKeyword: Result := 'static';
    tkInlineKeyword: Result := 'inline';
    tkForwardKeyword: Result := 'forward';
    tkDeprecatedKeyword: Result := 'deprecated';
    tkPlatformKeyword: Result := 'platform';
    tkExperimentalKeyword: Result := 'experimental';
    tkStdCallKeyword: Result := 'stdcall';
    tkSafeCallKeyword: Result := 'safecall';
    tkRegisterKeyword: Result := 'register';
    tkPascalKeyword: Result := 'pascal';
    tkFarKeyword: Result := 'far';
    tkNearKeyword: Result := 'near';
    tkCppDeclKeyword: Result := 'cppdecl';
    tkVarArgsKeyword: Result := 'varargs';
    tkOutKeyword: Result := 'out';
    tkAbsoluteKeyword: Result := 'absolute';
    tkAsmKeyword: Result := 'asm';
    tkAndKeyword: Result := 'and';
    tkOrKeyword: Result := 'or';
    tkNotKeyword: Result := 'not';
    tkXorKeyword: Result := 'xor';
    tkShlKeyword: Result := 'shl';
    tkShrKeyword: Result := 'shr';
    tkDivKeyword: Result := 'div';
    tkModKeyword: Result := 'mod';
    tkInKeyword: Result := 'in';
    tkIsKeyword: Result := 'is';
    tkAsKeyword: Result := 'as';
    tkNilKeyword: Result := 'nil';
    tkRaiseKeyword: Result := 'raise';
    tkTryKeyword: Result := 'try';
    tkExceptKeyword: Result := 'except';
    tkFinallyKeyword: Result := 'finally';
    tkOnKeyword: Result := 'on';
    tkInheritedKeyword: Result := 'inherited';
    tkSelfKeyword: Result := 'self';
    tkFileKeyword: Result := 'file';
    tkResourceStringKeyword: Result := 'resourcestring';
    tkStrictKeyword: Result := 'strict';
    tkOperatorKeyword: Result := 'operator';
    tkGenericKeyword: Result := 'generic';
    tkSpecializeKeyword: Result := 'specialize';
    tkReferenceKeyword: Result := 'reference';
    tkPackedKeyword: Result := 'packed';
    tkContainsKeyword: Result := 'contains';
    tkRequiresKeyword: Result := 'requires';
    tkIdentifier: Result := 'identifier';
    tkStringLiteral: Result := 'string-literal';
    tkIntegerLiteral: Result := 'integer-literal';
    tkRealLiteral: Result := 'real-literal';
    tkCharLiteral: Result := 'char-literal';
    tkCompilerDirective: Result := 'compiler-directive';
    tkSemicolon: Result := ';';
    tkDot: Result := '.';
    tkDotDot: Result := '..';
    tkComma: Result := ',';
    tkColon: Result := ':';
    tkAssign: Result := ':=';
    tkPlusAssign: Result := '+=';
    tkMinusAssign: Result := '-=';
    tkStarAssign: Result := '*=';
    tkSlashAssign: Result := '/=';
    tkLParen: Result := '(';
    tkRParen: Result := ')';
    tkLBracket: Result := '[';
    tkRBracket: Result := ']';
    tkPlus: Result := '+';
    tkMinus: Result := '-';
    tkStar: Result := '*';
    tkSlash: Result := '/';
    tkEquals: Result := '=';
    tkNotEquals: Result := '<>';
    tkLessThan: Result := '<';
    tkGreaterThan: Result := '>';
    tkLessEqual: Result := '<=';
    tkGreaterEqual: Result := '>=';
    tkAt: Result := '@';
    tkCaret: Result := '^';
    tkEOF: Result := 'end-of-file';
    tkError: Result := 'error';
  else
    Result := 'unknown';
  end;
end;

end.
