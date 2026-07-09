function IsIdentifierStart(const AChar: Char): Boolean;
begin
  Result := (AChar in ['A'..'Z']) or (AChar in ['a'..'z']) or (AChar = '_');
end;

function IsIdentifierContinue(const AChar: Char): Boolean;
begin
  Result := IsIdentifierStart(AChar) or (AChar in ['0'..'9']);
end;

function ResolveIdentifierKind(const ALexeme: string): TTokenKind;
var
  Lowered: string;
begin
  Lowered := LowerCase(ALexeme);
  case Lowered of
    'program': Exit(tkProgramKeyword);
    'unit': Exit(tkUnitKeyword);
    'library': Exit(tkLibraryKeyword);
    'package': Exit(tkPackageKeyword);
    'uses': Exit(tkUsesKeyword);
    'interface': Exit(tkInterfaceKeyword);
    'implementation': Exit(tkImplementationKeyword);
    'procedure': Exit(tkProcedureKeyword);
    'function': Exit(tkFunctionKeyword);
    'external': Exit(tkExternalKeyword);
    'cdecl': Exit(tkCdeclKeyword);
    'begin': Exit(tkBeginKeyword);
    'end': Exit(tkEndKeyword);
    'if': Exit(tkIfKeyword);
    'then': Exit(tkThenKeyword);
    'else': Exit(tkElseKeyword);
    'otherwise': Exit(tkElseKeyword); { FPC 兼容: otherwise = else 的 case 别名 }
    'while': Exit(tkWhileKeyword);
    'do': Exit(tkDoKeyword);
    'for': Exit(tkForKeyword);
    'to': Exit(tkToKeyword);
    'downto': Exit(tkDownToKeyword);
    'repeat': Exit(tkRepeatKeyword);
    'until': Exit(tkUntilKeyword);
    'with': Exit(tkWithKeyword);
    'case': Exit(tkCaseKeyword);
    'of': Exit(tkOfKeyword);
    'goto': Exit(tkGotoKeyword);
    'break': Exit(tkBreakKeyword);
    'continue': Exit(tkContinueKeyword);
    'exit': Exit(tkExitKeyword);
    'var': Exit(tkVarKeyword);
    'const': Exit(tkConstKeyword);
    'constref': Exit(tkConstRefKeyword);
    'type': Exit(tkTypeKeyword);
    'array': Exit(tkArrayKeyword);
    'set': Exit(tkSetKeyword);
    'record': Exit(tkRecordKeyword);
    'string': Exit(tkStringKeyword);
    'class': Exit(tkClassKeyword);
    'object': Exit(tkObjectKeyword);
    'constructor': Exit(tkConstructorKeyword);
    'destructor': Exit(tkDestructorKeyword);
    'property': Exit(tkPropertyKeyword);
    'initialization': Exit(tkInitializationKeyword);
    'finalization': Exit(tkFinalizationKeyword);
    'exports': Exit(tkExportsKeyword);
    'label': Exit(tkLabelKeyword);
    'threadvar': Exit(tkThreadVarKeyword);
    'published': Exit(tkPublishedKeyword);
    'public': Exit(tkPublicKeyword);
    'private': Exit(tkPrivateKeyword);
    'protected': Exit(tkProtectedKeyword);
    'virtual': Exit(tkVirtualKeyword);
    'override': Exit(tkOverrideKeyword);
    'abstract': Exit(tkAbstractKeyword);
    'reintroduce': Exit(tkReintroduceKeyword);
    'overload': Exit(tkOverloadKeyword);
    'dynamic': Exit(tkDynamicKeyword);
    'message': Exit(tkMessageKeyword);
    'static': Exit(tkStaticKeyword);
    'inline': Exit(tkInlineKeyword);
    'forward': Exit(tkForwardKeyword);
    'deprecated': Exit(tkDeprecatedKeyword);
    'platform': Exit(tkPlatformKeyword);
    'experimental': Exit(tkExperimentalKeyword);
    'stdcall': Exit(tkStdCallKeyword);
    'safecall': Exit(tkSafeCallKeyword);
    'register': Exit(tkRegisterKeyword);
    'pascal': Exit(tkPascalKeyword);
    'far': Exit(tkFarKeyword);
    'near': Exit(tkNearKeyword);
    'cppdecl': Exit(tkCppDeclKeyword);
    'varargs': Exit(tkVarArgsKeyword);
    'out': Exit(tkOutKeyword);
    'absolute': Exit(tkAbsoluteKeyword);
    'asm': Exit(tkAsmKeyword);
    'and': Exit(tkAndKeyword);
    'or': Exit(tkOrKeyword);
    'not': Exit(tkNotKeyword);
    'xor': Exit(tkXorKeyword);
    'shl': Exit(tkShlKeyword);
    'shr': Exit(tkShrKeyword);
    'div': Exit(tkDivKeyword);
    'mod': Exit(tkModKeyword);
    'in': Exit(tkInKeyword);
    'is': Exit(tkIsKeyword);
    'as': Exit(tkAsKeyword);
    'nil': Exit(tkNilKeyword);
    'raise': Exit(tkRaiseKeyword);
    'try': Exit(tkTryKeyword);
    'except': Exit(tkExceptKeyword);
    'finally': Exit(tkFinallyKeyword);
    'on': Exit(tkOnKeyword);
    'inherited': Exit(tkInheritedKeyword);
    'self': Exit(tkSelfKeyword);
    'file': Exit(tkFileKeyword);
    'resourcestring': Exit(tkResourceStringKeyword);
    'strict': Exit(tkStrictKeyword);
    'operator': Exit(tkOperatorKeyword);
    'generic': Exit(tkGenericKeyword);
    'specialize': Exit(tkSpecializeKeyword);
    'reference': Exit(tkReferenceKeyword);
    'packed': Exit(tkPackedKeyword);
    'contains': Exit(tkContainsKeyword);
    'requires': Exit(tkRequiresKeyword);
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
  FTokenCount := 0;
  { Pre-grow to a sensible initial capacity so the first ~256
    tokens never trigger a copy. For larger files we still
    double on demand inside AddToken. }
  EstimatedCapacity := Length(ASourceText) div 4 + 16;
  if EstimatedCapacity < 64 then
    EstimatedCapacity := 64;
  SetLength(FTokens, EstimatedCapacity);
  FCurrentLine := 1;
  FLineStartByte := 0;
  FDiagnostics := ADiagnostics;
  FFileId := AFileId;
  SetLength(FPendingTrivia, 0);
  LexSource(ASourceText);
  { Trim to actual length so callers iterate the right range. }
  SetLength(FTokens, FTokenCount);
end;

constructor TLexerResult.CreateFromTokens(const ATokens: array of TToken;
  const ACount: LongInt);
var
  I: LongInt;
begin
  inherited Create;
  FTokenCount := ACount;
  SetLength(FTokens, ACount);
  for I := 0 to ACount - 1 do
    FTokens[I] := ATokens[I];
  FCurrentLine := 1;
  FLineStartByte := 0;
  FDiagnostics := nil;
  FFileId := 0;
  SetLength(FPendingTrivia, 0);
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
  NextIndex: SizeInt;
begin
  if ALength <= 0 then
    Exit;
  NextIndex := System.Length(FPendingTrivia);
  SetLength(FPendingTrivia, NextIndex + 1);
  FPendingTrivia[NextIndex].Kind := AKind;
  FPendingTrivia[NextIndex].ByteOffset := AByteOffset;
  FPendingTrivia[NextIndex].Length := ALength;
end;

procedure TLexerResult.FlushPendingTriviaToToken(const ATokenIndex: SizeInt);
var
  TerminatorIndex, I, LeadingCount, TrailingCount: SizeInt;
  PrevTokenIndex: SizeInt;
begin
  if System.Length(FPendingTrivia) = 0 then
    Exit;

  { Per spec §"Trivia 处理":
    - Trivia between two tokens that does NOT cross a line
      terminator belongs to the previous token's TrailingTrivia.
    - Trivia from the first line terminator onward belongs to
      the next token's LeadingTrivia.
    - If there is no previous token (this is the first token in
      the stream), all trivia goes into LeadingTrivia. }
  TerminatorIndex := -1;
  for I := 0 to System.Length(FPendingTrivia) - 1 do
    if FPendingTrivia[I].Kind = tvkLineTerminator then
    begin
      TerminatorIndex := I;
      Break;
    end;

  PrevTokenIndex := ATokenIndex - 1;

  if PrevTokenIndex < 0 then
  begin
    LeadingCount := System.Length(FPendingTrivia);
    SetLength(FTokens[ATokenIndex].LeadingTrivia, LeadingCount);
    for I := 0 to LeadingCount - 1 do
      FTokens[ATokenIndex].LeadingTrivia[I] := FPendingTrivia[I];
  end
  else if TerminatorIndex < 0 then
  begin
    TrailingCount := System.Length(FPendingTrivia);
    SetLength(FTokens[PrevTokenIndex].TrailingTrivia, TrailingCount);
    for I := 0 to TrailingCount - 1 do
      FTokens[PrevTokenIndex].TrailingTrivia[I] := FPendingTrivia[I];
  end
  else
  begin
    TrailingCount := TerminatorIndex;
    LeadingCount := System.Length(FPendingTrivia) - TerminatorIndex;
    SetLength(FTokens[PrevTokenIndex].TrailingTrivia, TrailingCount);
    for I := 0 to TrailingCount - 1 do
      FTokens[PrevTokenIndex].TrailingTrivia[I] := FPendingTrivia[I];
    SetLength(FTokens[ATokenIndex].LeadingTrivia, LeadingCount);
    for I := 0 to LeadingCount - 1 do
      FTokens[ATokenIndex].LeadingTrivia[I] := FPendingTrivia[TerminatorIndex + I];
  end;

  SetLength(FPendingTrivia, 0);
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
  NewCapacity: SizeInt;
begin
  NextIndex := FTokenCount;
  if NextIndex >= Length(FTokens) then
  begin
    NewCapacity := Length(FTokens) * 2;
    if NewCapacity < NextIndex + 16 then
      NewCapacity := NextIndex + 16;
    SetLength(FTokens, NewCapacity);
  end;
  FTokens[NextIndex].Kind := AKind;
  FTokens[NextIndex].Lexeme := ALexeme;
  FTokens[NextIndex].FileId := FFileId;
  FTokens[NextIndex].ByteOffset := AByteOffset;
  FTokens[NextIndex].Line := ALine;
  FTokens[NextIndex].Column := AColumn;
  SetLength(FTokens[NextIndex].LeadingTrivia, 0);
  SetLength(FTokens[NextIndex].TrailingTrivia, 0);
  Inc(FTokenCount);
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

