function IsIdentifierStart(const AChar: Char): Boolean;
begin
  Result := (AChar in ['A'..'Z']) or (AChar in ['a'..'z']) or (AChar = '_');
end;

function IsIdentifierContinue(const AChar: Char): Boolean;
begin
  Result := IsIdentifierStart(AChar) or (AChar in ['0'..'9']);
end;

function KeywordCharLower(const AChar: Char): Char; inline;
begin
  if (AChar >= 'A') and (AChar <= 'Z') then
    Result := Char(Ord(AChar) + 32)
  else
    Result := AChar;
end;

{ Case-insensitive equality vs a lowercase keyword; no heap allocation. }
function KeywordEquals(const ALexeme, AKeyword: string): Boolean; inline;
var
  Index: SizeInt;
  N: SizeInt;
begin
  N := Length(AKeyword);
  if Length(ALexeme) <> N then
    Exit(False);
  for Index := 1 to N do
    if KeywordCharLower(ALexeme[Index]) <> AKeyword[Index] then
      Exit(False);
  Result := True;
end;

function ResolveIdentifierKind(const ALexeme: string): TTokenKind;
var
  Len: SizeInt;
  First: Char;
begin
  Len := Length(ALexeme);
  { Shortest keyword length 2 ("if"), longest 14 ("implementation"). }
  if (Len < 2) or (Len > 14) then
    Exit(tkIdentifier);
  First := KeywordCharLower(ALexeme[1]);
  case Len of
    2:
      case First of
        'a':
          begin
            if KeywordEquals(ALexeme, 'as') then Exit(tkAsKeyword);
          end;
        'd':
          begin
            if KeywordEquals(ALexeme, 'do') then Exit(tkDoKeyword);
          end;
        'i':
          begin
            if KeywordEquals(ALexeme, 'if') then Exit(tkIfKeyword);
            if KeywordEquals(ALexeme, 'in') then Exit(tkInKeyword);
            if KeywordEquals(ALexeme, 'is') then Exit(tkIsKeyword);
          end;
        'o':
          begin
            if KeywordEquals(ALexeme, 'of') then Exit(tkOfKeyword);
            if KeywordEquals(ALexeme, 'or') then Exit(tkOrKeyword);
            if KeywordEquals(ALexeme, 'on') then Exit(tkOnKeyword);
          end;
        't':
          begin
            if KeywordEquals(ALexeme, 'to') then Exit(tkToKeyword);
          end;
      end;
    3:
      case First of
        'a':
          begin
            if KeywordEquals(ALexeme, 'asm') then Exit(tkAsmKeyword);
            if KeywordEquals(ALexeme, 'and') then Exit(tkAndKeyword);
          end;
        'd':
          begin
            if KeywordEquals(ALexeme, 'div') then Exit(tkDivKeyword);
          end;
        'e':
          begin
            if KeywordEquals(ALexeme, 'end') then Exit(tkEndKeyword);
          end;
        'f':
          begin
            if KeywordEquals(ALexeme, 'for') then Exit(tkForKeyword);
            if KeywordEquals(ALexeme, 'far') then Exit(tkFarKeyword);
          end;
        'm':
          begin
            if KeywordEquals(ALexeme, 'mod') then Exit(tkModKeyword);
          end;
        'n':
          begin
            if KeywordEquals(ALexeme, 'not') then Exit(tkNotKeyword);
            if KeywordEquals(ALexeme, 'nil') then Exit(tkNilKeyword);
          end;
        'o':
          begin
            if KeywordEquals(ALexeme, 'out') then Exit(tkOutKeyword);
          end;
        's':
          begin
            if KeywordEquals(ALexeme, 'set') then Exit(tkSetKeyword);
            if KeywordEquals(ALexeme, 'shl') then Exit(tkShlKeyword);
            if KeywordEquals(ALexeme, 'shr') then Exit(tkShrKeyword);
          end;
        't':
          begin
            if KeywordEquals(ALexeme, 'try') then Exit(tkTryKeyword);
          end;
        'v':
          begin
            if KeywordEquals(ALexeme, 'var') then Exit(tkVarKeyword);
          end;
        'x':
          begin
            if KeywordEquals(ALexeme, 'xor') then Exit(tkXorKeyword);
          end;
      end;
    4:
      case First of
        'c':
          begin
            if KeywordEquals(ALexeme, 'case') then Exit(tkCaseKeyword);
          end;
        'e':
          begin
            if KeywordEquals(ALexeme, 'else') then Exit(tkElseKeyword);
            if KeywordEquals(ALexeme, 'exit') then Exit(tkExitKeyword);
          end;
        'f':
          begin
            if KeywordEquals(ALexeme, 'file') then Exit(tkFileKeyword);
          end;
        'g':
          begin
            if KeywordEquals(ALexeme, 'goto') then Exit(tkGotoKeyword);
          end;
        'n':
          begin
            if KeywordEquals(ALexeme, 'near') then Exit(tkNearKeyword);
          end;
        's':
          begin
            if KeywordEquals(ALexeme, 'self') then Exit(tkSelfKeyword);
          end;
        't':
          begin
            if KeywordEquals(ALexeme, 'then') then Exit(tkThenKeyword);
            if KeywordEquals(ALexeme, 'type') then Exit(tkTypeKeyword);
          end;
        'u':
          begin
            if KeywordEquals(ALexeme, 'unit') then Exit(tkUnitKeyword);
            if KeywordEquals(ALexeme, 'uses') then Exit(tkUsesKeyword);
          end;
        'w':
          begin
            if KeywordEquals(ALexeme, 'with') then Exit(tkWithKeyword);
          end;
      end;
    5:
      case First of
        'a':
          begin
            if KeywordEquals(ALexeme, 'array') then Exit(tkArrayKeyword);
          end;
        'b':
          begin
            if KeywordEquals(ALexeme, 'begin') then Exit(tkBeginKeyword);
            if KeywordEquals(ALexeme, 'break') then Exit(tkBreakKeyword);
          end;
        'c':
          begin
            if KeywordEquals(ALexeme, 'cdecl') then Exit(tkCdeclKeyword);
            if KeywordEquals(ALexeme, 'const') then Exit(tkConstKeyword);
            if KeywordEquals(ALexeme, 'class') then Exit(tkClassKeyword);
          end;
        'l':
          begin
            if KeywordEquals(ALexeme, 'label') then Exit(tkLabelKeyword);
          end;
        'r':
          begin
            if KeywordEquals(ALexeme, 'raise') then Exit(tkRaiseKeyword);
          end;
        'u':
          begin
            if KeywordEquals(ALexeme, 'until') then Exit(tkUntilKeyword);
          end;
        'w':
          begin
            if KeywordEquals(ALexeme, 'while') then Exit(tkWhileKeyword);
          end;
      end;
    6:
      case First of
        'd':
          begin
            if KeywordEquals(ALexeme, 'downto') then Exit(tkDownToKeyword);
          end;
        'e':
          begin
            if KeywordEquals(ALexeme, 'except') then Exit(tkExceptKeyword);
          end;
        'i':
          begin
            if KeywordEquals(ALexeme, 'inline') then Exit(tkInlineKeyword);
          end;
        'o':
          begin
            if KeywordEquals(ALexeme, 'object') then Exit(tkObjectKeyword);
          end;
        'p':
          begin
            if KeywordEquals(ALexeme, 'public') then Exit(tkPublicKeyword);
            if KeywordEquals(ALexeme, 'pascal') then Exit(tkPascalKeyword);
            if KeywordEquals(ALexeme, 'packed') then Exit(tkPackedKeyword);
          end;
        'r':
          begin
            if KeywordEquals(ALexeme, 'repeat') then Exit(tkRepeatKeyword);
            if KeywordEquals(ALexeme, 'record') then Exit(tkRecordKeyword);
          end;
        's':
          begin
            if KeywordEquals(ALexeme, 'string') then Exit(tkStringKeyword);
            if KeywordEquals(ALexeme, 'static') then Exit(tkStaticKeyword);
            if KeywordEquals(ALexeme, 'strict') then Exit(tkStrictKeyword);
          end;
      end;
    7:
      case First of
        'c':
          begin
            if KeywordEquals(ALexeme, 'cppdecl') then Exit(tkCppDeclKeyword);
          end;
        'd':
          begin
            if KeywordEquals(ALexeme, 'dynamic') then Exit(tkDynamicKeyword);
          end;
        'e':
          begin
            if KeywordEquals(ALexeme, 'exports') then Exit(tkExportsKeyword);
          end;
        'f':
          begin
            if KeywordEquals(ALexeme, 'forward') then Exit(tkForwardKeyword);
            if KeywordEquals(ALexeme, 'finally') then Exit(tkFinallyKeyword);
          end;
        'g':
          begin
            if KeywordEquals(ALexeme, 'generic') then Exit(tkGenericKeyword);
          end;
        'l':
          begin
            if KeywordEquals(ALexeme, 'library') then Exit(tkLibraryKeyword);
          end;
        'm':
          begin
            if KeywordEquals(ALexeme, 'message') then Exit(tkMessageKeyword);
          end;
        'p':
          begin
            if KeywordEquals(ALexeme, 'program') then Exit(tkProgramKeyword);
            if KeywordEquals(ALexeme, 'package') then Exit(tkPackageKeyword);
            if KeywordEquals(ALexeme, 'private') then Exit(tkPrivateKeyword);
          end;
        's':
          begin
            if KeywordEquals(ALexeme, 'stdcall') then Exit(tkStdCallKeyword);
          end;
        'v':
          begin
            if KeywordEquals(ALexeme, 'virtual') then Exit(tkVirtualKeyword);
            if KeywordEquals(ALexeme, 'varargs') then Exit(tkVarArgsKeyword);
          end;
      end;
    8:
      case First of
        'a':
          begin
            if KeywordEquals(ALexeme, 'abstract') then Exit(tkAbstractKeyword);
            if KeywordEquals(ALexeme, 'absolute') then Exit(tkAbsoluteKeyword);
          end;
        'c':
          begin
            if KeywordEquals(ALexeme, 'continue') then Exit(tkContinueKeyword);
            if KeywordEquals(ALexeme, 'constref') then Exit(tkConstRefKeyword);
            if KeywordEquals(ALexeme, 'contains') then Exit(tkContainsKeyword);
          end;
        'e':
          begin
            if KeywordEquals(ALexeme, 'external') then Exit(tkExternalKeyword);
          end;
        'f':
          begin
            if KeywordEquals(ALexeme, 'function') then Exit(tkFunctionKeyword);
          end;
        'o':
          begin
            if KeywordEquals(ALexeme, 'override') then Exit(tkOverrideKeyword);
            if KeywordEquals(ALexeme, 'overload') then Exit(tkOverloadKeyword);
            if KeywordEquals(ALexeme, 'operator') then Exit(tkOperatorKeyword);
          end;
        'p':
          begin
            if KeywordEquals(ALexeme, 'property') then Exit(tkPropertyKeyword);
            if KeywordEquals(ALexeme, 'platform') then Exit(tkPlatformKeyword);
          end;
        'r':
          begin
            if KeywordEquals(ALexeme, 'register') then Exit(tkRegisterKeyword);
            if KeywordEquals(ALexeme, 'requires') then Exit(tkRequiresKeyword);
          end;
        's':
          begin
            if KeywordEquals(ALexeme, 'safecall') then Exit(tkSafeCallKeyword);
          end;
      end;
    9:
      case First of
        'i':
          begin
            if KeywordEquals(ALexeme, 'interface') then Exit(tkInterfaceKeyword);
            if KeywordEquals(ALexeme, 'inherited') then Exit(tkInheritedKeyword);
          end;
        'o':
          begin
            if KeywordEquals(ALexeme, 'otherwise') then Exit(tkElseKeyword);
          end;
        'p':
          begin
            if KeywordEquals(ALexeme, 'procedure') then Exit(tkProcedureKeyword);
            if KeywordEquals(ALexeme, 'published') then Exit(tkPublishedKeyword);
            if KeywordEquals(ALexeme, 'protected') then Exit(tkProtectedKeyword);
          end;
        'r':
          begin
            if KeywordEquals(ALexeme, 'reference') then Exit(tkReferenceKeyword);
          end;
        't':
          begin
            if KeywordEquals(ALexeme, 'threadvar') then Exit(tkThreadVarKeyword);
          end;
      end;
    10:
      case First of
        'd':
          begin
            if KeywordEquals(ALexeme, 'destructor') then Exit(tkDestructorKeyword);
            if KeywordEquals(ALexeme, 'deprecated') then Exit(tkDeprecatedKeyword);
          end;
        's':
          begin
            if KeywordEquals(ALexeme, 'specialize') then Exit(tkSpecializeKeyword);
          end;
      end;
    11:
      case First of
        'c':
          begin
            if KeywordEquals(ALexeme, 'constructor') then Exit(tkConstructorKeyword);
          end;
        'r':
          begin
            if KeywordEquals(ALexeme, 'reintroduce') then Exit(tkReintroduceKeyword);
          end;
      end;
    12:
      case First of
        'e':
          begin
            if KeywordEquals(ALexeme, 'experimental') then Exit(tkExperimentalKeyword);
          end;
        'f':
          begin
            if KeywordEquals(ALexeme, 'finalization') then Exit(tkFinalizationKeyword);
          end;
      end;
    14:
      case First of
        'i':
          begin
            if KeywordEquals(ALexeme, 'implementation') then Exit(tkImplementationKeyword);
            if KeywordEquals(ALexeme, 'initialization') then Exit(tkInitializationKeyword);
          end;
        'r':
          begin
            if KeywordEquals(ALexeme, 'resourcestring') then Exit(tkResourceStringKeyword);
          end;
      end;
  end;
  Result := tkIdentifier;
end;

procedure SkipBraceComment(const ASourceText: string; var AIndex: SizeInt);
begin
  Inc(AIndex);
  while (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] <> '}') do
    Inc(AIndex);
  if AIndex <= Length(ASourceText) then
    Inc(AIndex);
end;

procedure SkipParenStarComment(const ASourceText: string; var AIndex: SizeInt);
begin
  Inc(AIndex, 2);
  while AIndex <= Length(ASourceText) - 1 do
  begin
    if (ASourceText[AIndex] = '*') and (ASourceText[AIndex + 1] = ')') then
    begin
      Inc(AIndex, 2);
      Exit;
    end;
    Inc(AIndex);
  end;

  if AIndex <= Length(ASourceText) then
    Inc(AIndex);
end;

procedure SkipLineComment(const ASourceText: string; var AIndex: SizeInt);
begin
  Inc(AIndex, 2);
  while (AIndex <= Length(ASourceText)) and
    not (ASourceText[AIndex] in [#10, #13]) do
    Inc(AIndex);
end;

function ReadStringLiteral(
  const ASourceText: string;
  var AIndex: SizeInt;
  out AClosed: Boolean;
  out ASawQuoted: Boolean
): string; forward;
function IsControlCharLetter(const AChar: Char): Boolean; forward;
function IsHexDigit(const AChar: Char): Boolean; forward;
function IsDigit(const AChar: Char): Boolean; forward;

function ReadStringLiteral(
  const ASourceText: string;
  var AIndex: SizeInt;
  out AClosed: Boolean;
  out ASawQuoted: Boolean
): string;
var
  StartIndex: SizeInt;
  Ch: Char;
  SegmentClosed: Boolean;

  procedure ScanQuotedSegment;
  begin
    SegmentClosed := False;
    Inc(AIndex);
    while AIndex <= Length(ASourceText) do
    begin
      Ch := ASourceText[AIndex];
      if (Ch = #13) or (Ch = #10) then
        Exit;
      if Ch = '''' then
      begin
        Inc(AIndex);
        if (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] = '''') then
          Inc(AIndex)
        else
        begin
          SegmentClosed := True;
          Exit;
        end;
      end
      else
        Inc(AIndex);
    end;
  end;

  procedure ScanCharCodeSegment;
  begin
    Inc(AIndex);
    if AIndex > Length(ASourceText) then
      Exit;
    if ASourceText[AIndex] = '$' then
    begin
      Inc(AIndex);
      while (AIndex <= Length(ASourceText)) and IsHexDigit(ASourceText[AIndex]) do
        Inc(AIndex);
    end
    else if IsDigit(ASourceText[AIndex]) then
    begin
      while (AIndex <= Length(ASourceText)) and IsDigit(ASourceText[AIndex]) do
        Inc(AIndex);
    end;
  end;

  procedure ScanCaretSegment;
  begin
    Inc(AIndex);
    if (AIndex <= Length(ASourceText)) and IsControlCharLetter(ASourceText[AIndex]) then
      Inc(AIndex);
  end;

begin
  StartIndex := AIndex;
  AClosed := True;
  ASawQuoted := False;

  while AIndex <= Length(ASourceText) do
  begin
    Ch := ASourceText[AIndex];
    if Ch = '''' then
    begin
      ASawQuoted := True;
      ScanQuotedSegment;
      if not SegmentClosed then
      begin
        AClosed := False;
        Break;
      end;
    end
    else if Ch = '#' then
      ScanCharCodeSegment
    else if (Ch = '^') and (AIndex < Length(ASourceText)) and
            IsControlCharLetter(ASourceText[AIndex + 1]) then
      ScanCaretSegment
    else
      Break;
  end;

  Result := Copy(ASourceText, StartIndex, AIndex - StartIndex);
end;

function IsDigit(const AChar: Char): Boolean;
begin
  Result := AChar in ['0'..'9'];
end;

function IsHexDigit(const AChar: Char): Boolean;
begin
  Result := (AChar in ['0'..'9']) or (AChar in ['A'..'F']) or (AChar in ['a'..'f']);
end;

function IsOctalDigit(const AChar: Char): Boolean;
begin
  Result := AChar in ['0'..'7'];
end;

function IsBinaryDigit(const AChar: Char): Boolean;
begin
  Result := (AChar = '0') or (AChar = '1');
end;

function IsControlCharLetter(const AChar: Char): Boolean;
begin
  { Pascal "^X" control-character notation: X must be one of
    @, A-Z, [, \, ], ^, _ (mapping to control bytes #0..#31).
    Lowercase letters are also accepted by FPC for ergonomics. }
  Result := (AChar in ['A'..'Z']) or (AChar in ['a'..'z']) or
            (AChar = '@') or (AChar = '[') or (AChar = '\') or
            (AChar = ']') or (AChar = '^') or (AChar = '_');
end;

function ReadIntegerLiteral(const ASourceText: string;
  var AIndex: SizeInt; out ALexeme: string): Boolean;
var
  StartIndex: SizeInt;
begin
  StartIndex := AIndex;
  if (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] = '$') then
  begin
    Inc(AIndex);
    if (AIndex > Length(ASourceText)) or not IsHexDigit(ASourceText[AIndex]) then
    begin
      AIndex := StartIndex;
      ALexeme := '';
      Exit(False);
    end;
    while (AIndex <= Length(ASourceText)) and IsHexDigit(ASourceText[AIndex]) do
      Inc(AIndex);
  end
  else if (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] = '&') then
  begin
    Inc(AIndex);
    if (AIndex > Length(ASourceText)) or not IsOctalDigit(ASourceText[AIndex]) then
    begin
      AIndex := StartIndex;
      ALexeme := '';
      Exit(False);
    end;
    while (AIndex <= Length(ASourceText)) and IsOctalDigit(ASourceText[AIndex]) do
      Inc(AIndex);
  end
  else if (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] = '%') then
  begin
    Inc(AIndex);
    if (AIndex > Length(ASourceText)) or not IsBinaryDigit(ASourceText[AIndex]) then
    begin
      AIndex := StartIndex;
      ALexeme := '';
      Exit(False);
    end;
    while (AIndex <= Length(ASourceText)) and IsBinaryDigit(ASourceText[AIndex]) do
      Inc(AIndex);
  end
  else
  begin
    while (AIndex <= Length(ASourceText)) and IsDigit(ASourceText[AIndex]) do
      Inc(AIndex);
  end;
  ALexeme := Copy(ASourceText, StartIndex, AIndex - StartIndex);
  Result := True;
end;

function ReadCharLiteral(const ASourceText: string;
  var AIndex: SizeInt; out ALexeme: string): Boolean;
var
  StartIndex: SizeInt;
begin
  StartIndex := AIndex;
  Inc(AIndex);
  if (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] = '$') then
  begin
    Inc(AIndex);
    if (AIndex > Length(ASourceText)) or not IsHexDigit(ASourceText[AIndex]) then
    begin
      AIndex := StartIndex;
      ALexeme := '';
      Exit(False);
    end;
    while (AIndex <= Length(ASourceText)) and IsHexDigit(ASourceText[AIndex]) do
      Inc(AIndex);
  end
  else
  begin
    if (AIndex > Length(ASourceText)) or not IsDigit(ASourceText[AIndex]) then
    begin
      AIndex := StartIndex;
      ALexeme := '';
      Exit(False);
    end;
    while (AIndex <= Length(ASourceText)) and IsDigit(ASourceText[AIndex]) do
      Inc(AIndex);
  end;
  ALexeme := Copy(ASourceText, StartIndex, AIndex - StartIndex);
  Result := True;
end;

function TryReadCompilerDirective(const ASourceText: string;
  var AIndex: SizeInt; out ALexeme: string): Boolean;
var
  StartIndex: SizeInt;
begin
  if (AIndex > Length(ASourceText)) or (ASourceText[AIndex] <> '{') then
    Exit(False);
  if (AIndex >= Length(ASourceText)) or (ASourceText[AIndex + 1] <> '$') then
    Exit(False);

  StartIndex := AIndex;
  Inc(AIndex, 2);
  while (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] <> '}') do
    Inc(AIndex);
  if AIndex <= Length(ASourceText) then
    Inc(AIndex);
  ALexeme := Copy(ASourceText, StartIndex, AIndex - StartIndex);
  Exit(True);
end;

function TryReadParenStarDirective(const ASourceText: string;
  var AIndex: SizeInt; out ALexeme: string): Boolean;
var
  StartIndex: SizeInt;
begin
  if (AIndex + 2 > Length(ASourceText)) then
    Exit(False);
  if (ASourceText[AIndex] <> '(') or (ASourceText[AIndex + 1] <> '*') then
    Exit(False);
  if (AIndex + 2 > Length(ASourceText)) or (ASourceText[AIndex + 2] <> '$') then
    Exit(False);

  StartIndex := AIndex;
  Inc(AIndex, 3);
  while AIndex <= Length(ASourceText) - 1 do
  begin
    if (ASourceText[AIndex] = '*') and (ASourceText[AIndex + 1] = ')') then
    begin
      Inc(AIndex, 2);
      ALexeme := Copy(ASourceText, StartIndex, AIndex - StartIndex);
      Exit(True);
    end;
    Inc(AIndex);
  end;
  if AIndex <= Length(ASourceText) then
    Inc(AIndex);
  ALexeme := Copy(ASourceText, StartIndex, AIndex - StartIndex);
  Exit(True);
end;

constructor TLexerResult.Create(const ASourceText: string);
begin
  Create(ASourceText, nil, 0);
end;

constructor TLexerResult.Create(
  const ASourceText: string;
  const ADiagnostics: TDiagnosticsSink;
  const AFileId: TCoreId
);
var
  EstimatedCapacity: SizeInt;
begin
  inherited Create;
  { Pre-grow so the first ~256 tokens avoid capacity churn. }
  EstimatedCapacity := Length(ASourceText) div 4 + 16;
  if EstimatedCapacity < 64 then
    EstimatedCapacity := 64;
  FTokens := TTokenVec.Create;
  FTokens.EnsureCapacity(SizeUInt(EstimatedCapacity));
  FCurrentLine := 1;
  FLineStartByte := 0;
  FDiagnostics := ADiagnostics;
  FFileId := AFileId;
  FPendingTrivia := TTriviaPieceVec.Create;
  FPendingTrivia.EnsureCapacity(16);
  LexSource(ASourceText);
end;

constructor TLexerResult.CreateFromTokens(const ATokens: array of TToken;
  const ACount: LongInt);
var
  I: LongInt;
begin
  inherited Create;
  FTokens := TTokenVec.Create;
  if ACount > 0 then
    FTokens.EnsureCapacity(SizeUInt(ACount));
  { Clone nested trivia so caller retains ownership of source tokens. }
  for I := 0 to ACount - 1 do
    FTokens.Push(CloneTokenWithTrivia(ATokens[I]));
  FCurrentLine := 1;
  FLineStartByte := 0;
  FDiagnostics := nil;
  FFileId := 0;
  FPendingTrivia := TTriviaPieceVec.Create;
end;

destructor TLexerResult.Destroy;
begin
  FreeTokenVecNestedTrivia(FTokens);
  FTokens.Free;
  FTokens := nil;
  FPendingTrivia.Free;
  FPendingTrivia := nil;
  inherited Destroy;
end;

procedure TLexerResult.ReportError(
  const ACode: string;
  const AByteOffset: LongInt;
  const AMessageText: string
);
begin
  if FDiagnostics = nil then
    Exit;
  FDiagnostics.EmitError(ACode, 'lexer', FFileId, AByteOffset, AMessageText);
end;

procedure TLexerResult.CapturePendingTrivia(
  const AKind: TTriviaKind;
  const AByteOffset: LongInt;
  const ALength: LongInt
);
var
  Piece: TTriviaPiece;
begin
  if ALength <= 0 then
    Exit;
  if FPendingTrivia = nil then
    FPendingTrivia := TTriviaPieceVec.Create;
  Piece.Kind := AKind;
  Piece.ByteOffset := AByteOffset;
  Piece.Length := ALength;
  FPendingTrivia.Push(Piece);
end;

procedure TLexerResult.FlushPendingTriviaToToken(const ATokenIndex: SizeInt);
var
  TerminatorIndex, I, LeadingCount, TrailingCount: SizeInt;
  PrevTokenIndex: SizeInt;
  Token: PToken;
  PrevToken: PToken;
begin
  if (FPendingTrivia = nil) or (FPendingTrivia.Count = 0) then
    Exit;

  { Per spec §"Trivia 处理":
    - Trivia between two tokens that does NOT cross a line
      terminator belongs to the previous token's TrailingTrivia.
    - Trivia from the first line terminator onward belongs to
      the next token's LeadingTrivia.
    - If there is no previous token (this is the first token in
      the stream), all trivia goes into LeadingTrivia. }
  TerminatorIndex := -1;
  for I := 0 to SizeInt(FPendingTrivia.Count) - 1 do
    if FPendingTrivia[SizeUInt(I)].Kind = tvkLineTerminator then
    begin
      TerminatorIndex := I;
      Break;
    end;

  PrevTokenIndex := ATokenIndex - 1;
  Token := FTokens.GetPtr(SizeUInt(ATokenIndex));

  if PrevTokenIndex < 0 then
  begin
    LeadingCount := SizeInt(FPendingTrivia.Count);
    Token^.LeadingTrivia.Free;
    Token^.LeadingTrivia := TTriviaPieceVec.Create(SizeUInt(LeadingCount));
    for I := 0 to LeadingCount - 1 do
      Token^.LeadingTrivia.Push(FPendingTrivia[SizeUInt(I)]);
  end
  else if TerminatorIndex < 0 then
  begin
    PrevToken := FTokens.GetPtr(SizeUInt(PrevTokenIndex));
    TrailingCount := SizeInt(FPendingTrivia.Count);
    PrevToken^.TrailingTrivia.Free;
    PrevToken^.TrailingTrivia := TTriviaPieceVec.Create(SizeUInt(TrailingCount));
    for I := 0 to TrailingCount - 1 do
      PrevToken^.TrailingTrivia.Push(FPendingTrivia[SizeUInt(I)]);
  end
  else
  begin
    PrevToken := FTokens.GetPtr(SizeUInt(PrevTokenIndex));
    TrailingCount := TerminatorIndex;
    LeadingCount := SizeInt(FPendingTrivia.Count) - TerminatorIndex;
    PrevToken^.TrailingTrivia.Free;
    PrevToken^.TrailingTrivia := TTriviaPieceVec.Create(SizeUInt(TrailingCount));
    for I := 0 to TrailingCount - 1 do
      PrevToken^.TrailingTrivia.Push(FPendingTrivia[SizeUInt(I)]);
    Token^.LeadingTrivia.Free;
    Token^.LeadingTrivia := TTriviaPieceVec.Create(SizeUInt(LeadingCount));
    for I := 0 to LeadingCount - 1 do
      Token^.LeadingTrivia.Push(FPendingTrivia[SizeUInt(TerminatorIndex + I)]);
  end;

  FPendingTrivia.Clear;
end;

procedure TLexerResult.AddToken(
  const AKind: TTokenKind;
  const ALexeme: string;
  const AByteOffset: LongInt;
  const ALine: LongInt;
  const AColumn: LongInt
);
var
  NextIndex: SizeInt;
  Token: TToken;
begin
  if FTokens = nil then
    FTokens := TTokenVec.Create;
  Token := Default(TToken);
  Token.Kind := AKind;
  Token.Lexeme := ALexeme;
  Token.FileId := FFileId;
  Token.ByteOffset := AByteOffset;
  Token.Line := ALine;
  Token.Column := AColumn;
  NextIndex := SizeInt(FTokens.Count);
  FTokens.Push(Token);
  FlushPendingTriviaToToken(NextIndex);
end;

procedure TLexerResult.AdvanceNewline(
  const ASourceText: string;
  var AIndex: SizeInt
);
var
  Ch: Char;
begin
  Ch := ASourceText[AIndex];
  if Ch = #13 then
  begin
    Inc(AIndex);
    if (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] = #10) then
      Inc(AIndex);
  end
  else
    Inc(AIndex);
  Inc(FCurrentLine);
  FLineStartByte := AIndex - 1;
end;

function TLexerResult.CurrentColumn(const AIndex: SizeInt): LongInt;
begin
  Result := (AIndex - 1) - FLineStartByte + 1;
end;

procedure TLexerResult.SkipBraceCommentTracking(
  const ASourceText: string;
  var AIndex: SizeInt;
  out AClosed: Boolean
);
var
  Ch: Char;
  Depth: LongInt;
begin
  AClosed := False;
  Depth := 1;
  Inc(AIndex);
  while AIndex <= Length(ASourceText) do
  begin
    Ch := ASourceText[AIndex];
    if Ch = '{' then
    begin
      Inc(Depth);
      Inc(AIndex);
    end
    else if Ch = '}' then
    begin
      Inc(AIndex);
      Dec(Depth);
      if Depth = 0 then
      begin
        AClosed := True;
        Exit;
      end;
    end
    else if (Ch = #13) or (Ch = #10) then
      AdvanceNewline(ASourceText, AIndex)
    else
      Inc(AIndex);
  end;
end;

procedure TLexerResult.SkipParenStarCommentTracking(
  const ASourceText: string;
  var AIndex: SizeInt;
  out AClosed: Boolean
);
var
  Ch: Char;
begin
  AClosed := False;
  Inc(AIndex, 2);
  while AIndex <= Length(ASourceText) - 1 do
  begin
    Ch := ASourceText[AIndex];
    if (Ch = '*') and (ASourceText[AIndex + 1] = ')') then
    begin
      Inc(AIndex, 2);
      AClosed := True;
      Exit;
    end;
    if (Ch = #13) or (Ch = #10) then
      AdvanceNewline(ASourceText, AIndex)
    else
      Inc(AIndex);
  end;
  if AIndex <= Length(ASourceText) then
    Inc(AIndex);
end;

function TLexerResult.TryReadCompilerDirectiveTracking(
  const ASourceText: string;
  var AIndex: SizeInt;
  out ALexeme: string;
  out AClosed: Boolean
): Boolean;
var
  StartIndex: SizeInt;
  Ch: Char;
begin
  AClosed := False;
  if (AIndex > Length(ASourceText)) or (ASourceText[AIndex] <> '{') then
    Exit(False);
  if (AIndex >= Length(ASourceText)) or (ASourceText[AIndex + 1] <> '$') then
    Exit(False);

  StartIndex := AIndex;
  Inc(AIndex, 2);
  while AIndex <= Length(ASourceText) do
  begin
    Ch := ASourceText[AIndex];
    if Ch = '}' then
    begin
      Inc(AIndex);
      AClosed := True;
      Break;
    end;
    if (Ch = #13) or (Ch = #10) then
      AdvanceNewline(ASourceText, AIndex)
    else
      Inc(AIndex);
  end;
  ALexeme := Copy(ASourceText, StartIndex, AIndex - StartIndex);
  Exit(True);
end;

function TLexerResult.TryReadParenStarDirectiveTracking(
  const ASourceText: string;
  var AIndex: SizeInt;
  out ALexeme: string;
  out AClosed: Boolean
): Boolean;
var
  StartIndex: SizeInt;
  Ch: Char;
begin
  AClosed := False;
  if (AIndex + 2 > Length(ASourceText)) then
    Exit(False);
  if (ASourceText[AIndex] <> '(') or (ASourceText[AIndex + 1] <> '*') then
    Exit(False);
  if (AIndex + 2 > Length(ASourceText)) or (ASourceText[AIndex + 2] <> '$') then
    Exit(False);

  StartIndex := AIndex;
  Inc(AIndex, 3);
  while AIndex <= Length(ASourceText) - 1 do
  begin
    Ch := ASourceText[AIndex];
    if (Ch = '*') and (ASourceText[AIndex + 1] = ')') then
    begin
      Inc(AIndex, 2);
      AClosed := True;
      ALexeme := Copy(ASourceText, StartIndex, AIndex - StartIndex);
      Exit(True);
    end;
    if (Ch = #13) or (Ch = #10) then
      AdvanceNewline(ASourceText, AIndex)
    else
      Inc(AIndex);
  end;
  if AIndex <= Length(ASourceText) then
    Inc(AIndex);
  ALexeme := Copy(ASourceText, StartIndex, AIndex - StartIndex);
  Exit(True);
end;

procedure TLexerResult.AddTokenAt(
  const AKind: TTokenKind;
  const ALexeme: string;
  const AStartIndex: SizeInt;
  const ALine: LongInt
);
var
  Column: LongInt;
begin
  Column := AStartIndex - FLineStartByte;
  if Column < 1 then
    Column := 1;
  AddToken(AKind, ALexeme, AStartIndex - 1, ALine, Column);
end;

procedure TLexerResult.AddTokenAtPos(
  const AKind: TTokenKind;
  const ALexeme: string;
  const AStartIndex: SizeInt;
  const ALine: LongInt;
  const AColumn: LongInt
);
begin
  AddToken(AKind, ALexeme, AStartIndex - 1, ALine, AColumn);
end;

