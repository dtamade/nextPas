unit np_lexer;

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
  nextpas.compiler.diagnostics.sink;

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

{$I np_lexer_helpers.inc}
{$I np_lexer_lex_source.inc}

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
