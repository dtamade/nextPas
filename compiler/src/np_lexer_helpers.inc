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

{ ── zero-copy / table-driven keyword dispatch ── }
const
  KEYWORD_HASH_SIZE = 256;
  KEYWORD_ENTRY_COUNT = 106;
  LEXEME_CACHE_SIZE = 256;

type
  TKeywordEntry = record
    Keyword: string;
    Kind: TTokenKind;
  end;

const
  KeywordEntries: array[0..105] of TKeywordEntry = (
    (Keyword: 'as'; Kind: tkAsKeyword),
    (Keyword: 'do'; Kind: tkDoKeyword),
    (Keyword: 'if'; Kind: tkIfKeyword),
    (Keyword: 'in'; Kind: tkInKeyword),
    (Keyword: 'is'; Kind: tkIsKeyword),
    (Keyword: 'of'; Kind: tkOfKeyword),
    (Keyword: 'or'; Kind: tkOrKeyword),
    (Keyword: 'on'; Kind: tkOnKeyword),
    (Keyword: 'to'; Kind: tkToKeyword),
    (Keyword: 'asm'; Kind: tkAsmKeyword),
    (Keyword: 'and'; Kind: tkAndKeyword),
    (Keyword: 'div'; Kind: tkDivKeyword),
    (Keyword: 'end'; Kind: tkEndKeyword),
    (Keyword: 'for'; Kind: tkForKeyword),
    (Keyword: 'far'; Kind: tkFarKeyword),
    (Keyword: 'mod'; Kind: tkModKeyword),
    (Keyword: 'not'; Kind: tkNotKeyword),
    (Keyword: 'nil'; Kind: tkNilKeyword),
    (Keyword: 'out'; Kind: tkOutKeyword),
    (Keyword: 'set'; Kind: tkSetKeyword),
    (Keyword: 'shl'; Kind: tkShlKeyword),
    (Keyword: 'shr'; Kind: tkShrKeyword),
    (Keyword: 'try'; Kind: tkTryKeyword),
    (Keyword: 'var'; Kind: tkVarKeyword),
    (Keyword: 'xor'; Kind: tkXorKeyword),
    (Keyword: 'case'; Kind: tkCaseKeyword),
    (Keyword: 'else'; Kind: tkElseKeyword),
    (Keyword: 'exit'; Kind: tkExitKeyword),
    (Keyword: 'file'; Kind: tkFileKeyword),
    (Keyword: 'goto'; Kind: tkGotoKeyword),
    (Keyword: 'near'; Kind: tkNearKeyword),
    (Keyword: 'self'; Kind: tkSelfKeyword),
    (Keyword: 'then'; Kind: tkThenKeyword),
    (Keyword: 'type'; Kind: tkTypeKeyword),
    (Keyword: 'unit'; Kind: tkUnitKeyword),
    (Keyword: 'uses'; Kind: tkUsesKeyword),
    (Keyword: 'with'; Kind: tkWithKeyword),
    (Keyword: 'array'; Kind: tkArrayKeyword),
    (Keyword: 'begin'; Kind: tkBeginKeyword),
    (Keyword: 'break'; Kind: tkBreakKeyword),
    (Keyword: 'cdecl'; Kind: tkCdeclKeyword),
    (Keyword: 'const'; Kind: tkConstKeyword),
    (Keyword: 'class'; Kind: tkClassKeyword),
    (Keyword: 'label'; Kind: tkLabelKeyword),
    (Keyword: 'raise'; Kind: tkRaiseKeyword),
    (Keyword: 'until'; Kind: tkUntilKeyword),
    (Keyword: 'while'; Kind: tkWhileKeyword),
    (Keyword: 'downto'; Kind: tkDownToKeyword),
    (Keyword: 'except'; Kind: tkExceptKeyword),
    (Keyword: 'inline'; Kind: tkInlineKeyword),
    (Keyword: 'object'; Kind: tkObjectKeyword),
    (Keyword: 'public'; Kind: tkPublicKeyword),
    (Keyword: 'pascal'; Kind: tkPascalKeyword),
    (Keyword: 'packed'; Kind: tkPackedKeyword),
    (Keyword: 'repeat'; Kind: tkRepeatKeyword),
    (Keyword: 'record'; Kind: tkRecordKeyword),
    (Keyword: 'string'; Kind: tkStringKeyword),
    (Keyword: 'static'; Kind: tkStaticKeyword),
    (Keyword: 'strict'; Kind: tkStrictKeyword),
    (Keyword: 'cppdecl'; Kind: tkCppDeclKeyword),
    (Keyword: 'dynamic'; Kind: tkDynamicKeyword),
    (Keyword: 'exports'; Kind: tkExportsKeyword),
    (Keyword: 'forward'; Kind: tkForwardKeyword),
    (Keyword: 'finally'; Kind: tkFinallyKeyword),
    (Keyword: 'generic'; Kind: tkGenericKeyword),
    (Keyword: 'library'; Kind: tkLibraryKeyword),
    (Keyword: 'message'; Kind: tkMessageKeyword),
    (Keyword: 'program'; Kind: tkProgramKeyword),
    (Keyword: 'package'; Kind: tkPackageKeyword),
    (Keyword: 'private'; Kind: tkPrivateKeyword),
    (Keyword: 'stdcall'; Kind: tkStdCallKeyword),
    (Keyword: 'virtual'; Kind: tkVirtualKeyword),
    (Keyword: 'varargs'; Kind: tkVarArgsKeyword),
    (Keyword: 'abstract'; Kind: tkAbstractKeyword),
    (Keyword: 'absolute'; Kind: tkAbsoluteKeyword),
    (Keyword: 'continue'; Kind: tkContinueKeyword),
    (Keyword: 'constref'; Kind: tkConstRefKeyword),
    (Keyword: 'contains'; Kind: tkContainsKeyword),
    (Keyword: 'external'; Kind: tkExternalKeyword),
    (Keyword: 'function'; Kind: tkFunctionKeyword),
    (Keyword: 'override'; Kind: tkOverrideKeyword),
    (Keyword: 'overload'; Kind: tkOverloadKeyword),
    (Keyword: 'operator'; Kind: tkOperatorKeyword),
    (Keyword: 'property'; Kind: tkPropertyKeyword),
    (Keyword: 'platform'; Kind: tkPlatformKeyword),
    (Keyword: 'register'; Kind: tkRegisterKeyword),
    (Keyword: 'requires'; Kind: tkRequiresKeyword),
    (Keyword: 'safecall'; Kind: tkSafeCallKeyword),
    (Keyword: 'interface'; Kind: tkInterfaceKeyword),
    (Keyword: 'inherited'; Kind: tkInheritedKeyword),
    (Keyword: 'otherwise'; Kind: tkElseKeyword),
    (Keyword: 'procedure'; Kind: tkProcedureKeyword),
    (Keyword: 'published'; Kind: tkPublishedKeyword),
    (Keyword: 'protected'; Kind: tkProtectedKeyword),
    (Keyword: 'reference'; Kind: tkReferenceKeyword),
    (Keyword: 'threadvar'; Kind: tkThreadVarKeyword),
    (Keyword: 'destructor'; Kind: tkDestructorKeyword),
    (Keyword: 'deprecated'; Kind: tkDeprecatedKeyword),
    (Keyword: 'specialize'; Kind: tkSpecializeKeyword),
    (Keyword: 'constructor'; Kind: tkConstructorKeyword),
    (Keyword: 'reintroduce'; Kind: tkReintroduceKeyword),
    (Keyword: 'experimental'; Kind: tkExperimentalKeyword),
    (Keyword: 'finalization'; Kind: tkFinalizationKeyword),
    (Keyword: 'implementation'; Kind: tkImplementationKeyword),
    (Keyword: 'initialization'; Kind: tkInitializationKeyword),
    (Keyword: 'resourcestring'; Kind: tkResourceStringKeyword)
  );

var
  KeywordHashTable: array[0..255] of Integer;
  KeywordTableInitialized: Boolean = False;
  LexemeCacheHash: array[0..255] of Cardinal;
  LexemeCacheStr: array[0..255] of string;
  LexemeCacheValid: array[0..255] of Boolean;

function HashSliceLower(const ASourceText: string; AStart, ALen: SizeInt): Cardinal; inline;
var
  I: SizeInt;
  H: Cardinal;
  C: Char;
begin
  H := Cardinal(2166136261);
  for I := 0 to ALen - 1 do
  begin
    C := ASourceText[AStart + I];
    if (C >= 'A') and (C <= 'Z') then
      C := Char(Ord(C) + 32);
    H := (H xor Cardinal(Ord(C))) * Cardinal(16777619);
  end;
  Result := H;
end;

function HashSliceCS(const ASourceText: string; AStart, ALen: SizeInt): Cardinal; inline;
var
  I: SizeInt;
  H: Cardinal;
begin
  H := Cardinal(2166136261);
  for I := 0 to ALen - 1 do
    H := (H xor Cardinal(Ord(ASourceText[AStart + I]))) * Cardinal(16777619);
  Result := H;
end;

function KeywordEqualsSlice(const ASourceText: string; AStart, ALen: SizeInt; const AKeyword: string): Boolean; inline;
var
  I: SizeInt;
begin
  if ALen <> Length(AKeyword) then Exit(False);
  for I := 0 to ALen - 1 do
    if KeywordCharLower(ASourceText[AStart + I]) <> AKeyword[I + 1] then Exit(False);
  Result := True;
end;

function SliceEqualsString(const ASourceText: string; AStart, ALen: SizeInt; const ACached: string): Boolean; inline;
var
  I: SizeInt;
begin
  if ALen <> Length(ACached) then Exit(False);
  for I := 0 to ALen - 1 do
    if ASourceText[AStart + I] <> ACached[I + 1] then Exit(False);
  Result := True;
end;

procedure InitKeywordTable;
var
  I, Idx, Probe: SizeInt;
  H: Cardinal;
  J: SizeInt;
begin
  if KeywordTableInitialized then Exit;
  for I := 0 to KEYWORD_HASH_SIZE - 1 do
    KeywordHashTable[I] := -1;
  for I := 0 to KEYWORD_ENTRY_COUNT - 1 do
  begin
    H := Cardinal(2166136261);
    for J := 1 to Length(KeywordEntries[I].Keyword) do
      H := (H xor Cardinal(Ord(KeywordEntries[I].Keyword[J]))) * Cardinal(16777619);
    Idx := H and (KEYWORD_HASH_SIZE - 1);
    for Probe := 0 to KEYWORD_HASH_SIZE - 1 do
    begin
      if KeywordHashTable[(Idx + Probe) and (KEYWORD_HASH_SIZE - 1)] = -1 then
      begin
        KeywordHashTable[(Idx + Probe) and (KEYWORD_HASH_SIZE - 1)] := I;
        Break;
      end;
    end;
  end;
  KeywordTableInitialized := True;
end;

function ResolveIdentifierKindSlice(const ASourceText: string; AStart, ALen: SizeInt): TTokenKind;
var
  H: Cardinal;
  Idx, Probe: SizeInt;
  EntryIdx: Integer;
  KW: string;
begin
  if (ALen < 2) or (ALen > 14) then Exit(tkIdentifier);
  if not KeywordTableInitialized then InitKeywordTable;
  H := HashSliceLower(ASourceText, AStart, ALen);
  Idx := H and (KEYWORD_HASH_SIZE - 1);
  for Probe := 0 to KEYWORD_HASH_SIZE - 1 do
  begin
    EntryIdx := KeywordHashTable[(Idx + Probe) and (KEYWORD_HASH_SIZE - 1)];
    if EntryIdx = -1 then Exit(tkIdentifier);
    KW := KeywordEntries[EntryIdx].Keyword;
    if Length(KW) <> ALen then Continue;
    if KeywordEqualsSlice(ASourceText, AStart, ALen, KW) then
      Exit(KeywordEntries[EntryIdx].Kind);
  end;
  Result := tkIdentifier;
end;

function ExtractLexeme(const ASourceText: string; AStart, ALen: SizeInt): string; inline;
var
  H: Cardinal;
  Idx: SizeInt;
  Cached: string;
begin
  if ALen <= 0 then Exit('');
  H := HashSliceCS(ASourceText, AStart, ALen);
  Idx := H and (LEXEME_CACHE_SIZE - 1);
  if LexemeCacheValid[Idx] and (LexemeCacheHash[Idx] = H) then
  begin
    Cached := LexemeCacheStr[Idx];
    if SliceEqualsString(ASourceText, AStart, ALen, Cached) then
      Exit(Cached);
  end;
  Result := Copy(ASourceText, AStart, ALen);
  LexemeCacheHash[Idx] := H;
  LexemeCacheStr[Idx] := Result;
  LexemeCacheValid[Idx] := True;
end;

function ContextSnippet(const ASourceText: string; AIndex: SizeInt; AMaxLen: SizeInt = 20): string; inline;
var
  StartPos, SnipLen: SizeInt;
begin
  if AIndex < 1 then AIndex := 1;
  if AIndex > Length(ASourceText) then Exit('');
  StartPos := AIndex;
  SnipLen := AMaxLen;
  if StartPos + SnipLen - 1 > Length(ASourceText) then
    SnipLen := Length(ASourceText) - StartPos + 1;
  { Replace control chars for diagnostics }
  Result := Copy(ASourceText, StartPos, SnipLen);
end;

function TryAdvanceIntegerLiteral(const ASourceText: string; var AIndex: SizeInt): Boolean;
var
  StartIndex: SizeInt;
begin
  StartIndex := AIndex;
  if (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] = '$') then
  begin
    Inc(AIndex);
    if (AIndex > Length(ASourceText)) or not IsHexDigit(ASourceText[AIndex]) then
    begin AIndex := StartIndex; Exit(False); end;
    while (AIndex <= Length(ASourceText)) and IsHexDigit(ASourceText[AIndex]) do Inc(AIndex);
  end
  else if (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] = '&') then
  begin
    Inc(AIndex);
    if (AIndex > Length(ASourceText)) or not IsOctalDigit(ASourceText[AIndex]) then
    begin AIndex := StartIndex; Exit(False); end;
    while (AIndex <= Length(ASourceText)) and IsOctalDigit(ASourceText[AIndex]) do Inc(AIndex);
  end
  else if (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] = '%') then
  begin
    Inc(AIndex);
    if (AIndex > Length(ASourceText)) or not IsBinaryDigit(ASourceText[AIndex]) then
    begin AIndex := StartIndex; Exit(False); end;
    while (AIndex <= Length(ASourceText)) and IsBinaryDigit(ASourceText[AIndex]) do Inc(AIndex);
  end
  else
    while (AIndex <= Length(ASourceText)) and IsDigit(ASourceText[AIndex]) do Inc(AIndex);
  Result := True;
end;

function TryAdvanceCharLiteral(const ASourceText: string; var AIndex: SizeInt): Boolean;
var
  StartIndex: SizeInt;
begin
  StartIndex := AIndex;
  Inc(AIndex);
  if (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] = '$') then
  begin
    Inc(AIndex);
    if (AIndex > Length(ASourceText)) or not IsHexDigit(ASourceText[AIndex]) then begin AIndex:=StartIndex; Exit(False); end;
    while (AIndex <= Length(ASourceText)) and IsHexDigit(ASourceText[AIndex]) do Inc(AIndex);
  end
  else
  begin
    if (AIndex > Length(ASourceText)) or not IsDigit(ASourceText[AIndex]) then begin AIndex:=StartIndex; Exit(False); end;
    while (AIndex <= Length(ASourceText)) and IsDigit(ASourceText[AIndex]) do Inc(AIndex);
  end;
  Result := True;
end;

function AdvanceStringLiteral(const ASourceText: string; var AIndex: SizeInt; out AClosed, ASawQuoted: Boolean): SizeInt;
var
  StartIndex: SizeInt;
  Ch: Char;
  SegmentClosed: Boolean;
  procedure ScanQuotedSegment;
  begin
    SegmentClosed := False; Inc(AIndex);
    while AIndex <= Length(ASourceText) do
    begin
      Ch := ASourceText[AIndex];
      if (Ch = #13) or (Ch = #10) then Exit;
      if Ch = '''' then
      begin Inc(AIndex); if (AIndex <= Length(ASourceText)) and (ASourceText[AIndex] = '''') then Inc(AIndex) else begin SegmentClosed:=True; Exit; end; end
      else Inc(AIndex);
    end;
  end;
  procedure ScanCharCodeSegment;
  begin Inc(AIndex); if AIndex > Length(ASourceText) then Exit; if ASourceText[AIndex] = '$' then begin Inc(AIndex); while (AIndex <= Length(ASourceText)) and IsHexDigit(ASourceText[AIndex]) do Inc(AIndex); end else if IsDigit(ASourceText[AIndex]) then while (AIndex <= Length(ASourceText)) and IsDigit(ASourceText[AIndex]) do Inc(AIndex); end;
  procedure ScanCaretSegment; begin Inc(AIndex); if (AIndex <= Length(ASourceText)) and IsControlCharLetter(ASourceText[AIndex]) then Inc(AIndex); end;
begin
  StartIndex := AIndex; AClosed := True; ASawQuoted := False;
  while AIndex <= Length(ASourceText) do
  begin Ch := ASourceText[AIndex];
    if Ch = '''' then begin ASawQuoted:=True; ScanQuotedSegment; if not SegmentClosed then begin AClosed:=False; Break; end; end
    else if Ch = '#' then ScanCharCodeSegment
    else if (Ch = '^') and (AIndex < Length(ASourceText)) and IsControlCharLetter(ASourceText[AIndex+1]) then ScanCaretSegment
    else Break;
  end;
  Result := StartIndex;
end;

function ResolveIdentifierKind(const ALexeme: string): TTokenKind;
begin
  if Length(ALexeme) = 0 then Exit(tkIdentifier);
  Result := ResolveIdentifierKindSlice(ALexeme, 1, Length(ALexeme));
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

  Result := ExtractLexeme(ASourceText, StartIndex, AIndex - StartIndex);
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
  Result := (AChar in ['A'..'Z']) or (AChar in ['a'..'z']) or
            (AChar = '@') or (AChar = '[') or (AChar = '\') or
            (AChar = ']') or (AChar = '^') or (AChar = '_');
end;

function ReadIntegerLiteral(const ASourceText: string;
  var AIndex: SizeInt; out ALexeme: string): Boolean;
var
  StartIndex: SizeInt;
  Save: SizeInt;
begin
  StartIndex := AIndex;
  Save := AIndex;
  if not TryAdvanceIntegerLiteral(ASourceText, AIndex) then
  begin
    AIndex := StartIndex;
    ALexeme := '';
    Exit(False);
  end;
  if AIndex = Save then
  begin
    { No progress means decimal integer may be empty; handle decimal-only path }
    if (AIndex <= Length(ASourceText)) and IsDigit(ASourceText[AIndex]) then
      while (AIndex <= Length(ASourceText)) and IsDigit(ASourceText[AIndex]) do Inc(AIndex)
    else
    begin AIndex := StartIndex; ALexeme:=''; Exit(False); end;
  end;
  ALexeme := ExtractLexeme(ASourceText, StartIndex, AIndex - StartIndex);
  Result := True;
end;

function ReadCharLiteral(const ASourceText: string;
  var AIndex: SizeInt; out ALexeme: string): Boolean;
var
  StartIndex: SizeInt;
begin
  StartIndex := AIndex;
  if not TryAdvanceCharLiteral(ASourceText, AIndex) then
  begin
    ALexeme := '';
    AIndex := StartIndex;
    Exit(False);
  end;
  ALexeme := ExtractLexeme(ASourceText, StartIndex, AIndex - StartIndex);
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
  ALexeme := ExtractLexeme(ASourceText, StartIndex, AIndex - StartIndex);
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
      ALexeme := ExtractLexeme(ASourceText, StartIndex, AIndex - StartIndex);
      Exit(True);
    end;
    Inc(AIndex);
  end;
  if AIndex <= Length(ASourceText) then
    Inc(AIndex);
  ALexeme := ExtractLexeme(ASourceText, StartIndex, AIndex - StartIndex);
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
  ALexeme := ExtractLexeme(ASourceText, StartIndex, AIndex - StartIndex);
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
      ALexeme := ExtractLexeme(ASourceText, StartIndex, AIndex - StartIndex);
      Exit(True);
    end;
    if (Ch = #13) or (Ch = #10) then
      AdvanceNewline(ASourceText, AIndex)
    else
      Inc(AIndex);
  end;
  if AIndex <= Length(ASourceText) then
    Inc(AIndex);
  ALexeme := ExtractLexeme(ASourceText, StartIndex, AIndex - StartIndex);
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

