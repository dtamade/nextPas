unit nextpas.compiler.syntax.lexer;

{$mode objfpc}{$H+}
{$UNITPATH ../diagnostics}
{$UNITPATH ../../rtl/core/base}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.text.conv,
  nextpas.core.collections.vec,
  np_base_types,
  np_diagnostics_sink;

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

  { Nested product table owned by token entry (default heap / optional alloc). }
  TTriviaPieceVec = specialize TVec<TTriviaPiece>;

  TToken = record
    Kind: TTokenKind;
    Lexeme: string;
    FileId: TCoreId;
    ByteOffset: LongInt;
    Line: LongInt;
    Column: LongInt;
    LeadingTrivia: TTriviaPieceVec;
    TrailingTrivia: TTriviaPieceVec;
  end;
  PToken = ^TToken;
  TTokenVec = specialize TVec<TToken>;

  TLexerResult = class
  private
    FTokens: TTokenVec;
    FCurrentLine: LongInt;
    FLineStartByte: LongInt;
    FDiagnostics: TDiagnosticsSink;
    FFileId: TCoreId;
    FPendingTrivia: TTriviaPieceVec;
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
    destructor Destroy; override;
    function TokenCount: LongInt;
    function TokenAt(const AIndex: LongInt): TToken;
  end;

{ Deep-copy trivia for token value copies (EmitToken / CreateFromTokens). }
function CloneTriviaPieceVec(
  const ASrc: TTriviaPieceVec;
  AAllocator: IAllocator = nil
): TTriviaPieceVec;
function CloneTokenWithTrivia(
  const ASrc: TToken;
  AAllocator: IAllocator = nil
): TToken;
procedure FreeTokenNestedTrivia(var AToken: TToken);
procedure FreeTokenVecNestedTrivia(const ATokens: TTokenVec);

function TokenKindName(const AKind: TTokenKind): string;

implementation


{--- inlined np_lexer_helpers.inc ---}
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


{--- end np_lexer_helpers.inc ---}


{--- inlined np_lexer_lex_source.inc ---}
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

{--- end np_lexer_lex_source.inc ---}


function CloneTriviaPieceVec(
  const ASrc: TTriviaPieceVec;
  AAllocator: IAllocator
): TTriviaPieceVec;
var
  I: SizeInt;
begin
  if ASrc = nil then
    Exit(nil);
  if AAllocator <> nil then
    Result := TTriviaPieceVec.Create(ASrc.Count, AAllocator)
  else
    Result := TTriviaPieceVec.Create(ASrc.Count);
  for I := 0 to SizeInt(ASrc.Count) - 1 do
    Result.Push(ASrc[SizeUInt(I)]);
end;

function CloneTokenWithTrivia(
  const ASrc: TToken;
  AAllocator: IAllocator
): TToken;
begin
  Result := ASrc;
  Result.LeadingTrivia := CloneTriviaPieceVec(ASrc.LeadingTrivia, AAllocator);
  Result.TrailingTrivia := CloneTriviaPieceVec(ASrc.TrailingTrivia, AAllocator);
end;

procedure FreeTokenNestedTrivia(var AToken: TToken);
begin
  AToken.LeadingTrivia.Free;
  AToken.LeadingTrivia := nil;
  AToken.TrailingTrivia.Free;
  AToken.TrailingTrivia := nil;
end;

procedure FreeTokenVecNestedTrivia(const ATokens: TTokenVec);
var
  I: SizeInt;
begin
  if ATokens = nil then
    Exit;
  for I := 0 to SizeInt(ATokens.Count) - 1 do
    FreeTokenNestedTrivia(ATokens.GetPtr(SizeUInt(I))^);
end;

function TLexerResult.TokenCount: LongInt;
begin
  if FTokens = nil then
    Exit(0);
  Result := LongInt(FTokens.Count);
end;

function TLexerResult.TokenAt(const AIndex: LongInt): TToken;
begin
  if (FTokens = nil) or (AIndex < 0) or (AIndex >= LongInt(FTokens.Count)) then
  begin
    Result := Default(TToken);
    Result.Kind := tkEOF;
    Exit;
  end;

  { Shallow copy of entry; nested trivia remain owned by FTokens. }
  Result := FTokens[SizeUInt(AIndex)];
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
