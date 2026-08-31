unit np_lexer;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.mem.intf,
  nextpas.compiler.syntax.lexer;

type
  TTokenKind = nextpas.compiler.syntax.lexer.TTokenKind;
  TTriviaKind = nextpas.compiler.syntax.lexer.TTriviaKind;
  TTriviaPiece = nextpas.compiler.syntax.lexer.TTriviaPiece;
  TTriviaPieceVec = nextpas.compiler.syntax.lexer.TTriviaPieceVec;
  TToken = nextpas.compiler.syntax.lexer.TToken;
  TTokenVec = nextpas.compiler.syntax.lexer.TTokenVec;
  TLexerResult = nextpas.compiler.syntax.lexer.TLexerResult;
  PToken = nextpas.compiler.syntax.lexer.PToken;

const
  tkUnknown = nextpas.compiler.syntax.lexer.tkUnknown;
  tkError = nextpas.compiler.syntax.lexer.tkError;
  tkProgramKeyword = nextpas.compiler.syntax.lexer.tkProgramKeyword;
  tkUnitKeyword = nextpas.compiler.syntax.lexer.tkUnitKeyword;
  tkLibraryKeyword = nextpas.compiler.syntax.lexer.tkLibraryKeyword;
  tkPackageKeyword = nextpas.compiler.syntax.lexer.tkPackageKeyword;
  tkUsesKeyword = nextpas.compiler.syntax.lexer.tkUsesKeyword;
  tkInterfaceKeyword = nextpas.compiler.syntax.lexer.tkInterfaceKeyword;
  tkImplementationKeyword = nextpas.compiler.syntax.lexer.tkImplementationKeyword;
  tkProcedureKeyword = nextpas.compiler.syntax.lexer.tkProcedureKeyword;
  tkExternalKeyword = nextpas.compiler.syntax.lexer.tkExternalKeyword;
  tkNameKeyword = nextpas.compiler.syntax.lexer.tkNameKeyword;
  tkCdeclKeyword = nextpas.compiler.syntax.lexer.tkCdeclKeyword;
  tkBeginKeyword = nextpas.compiler.syntax.lexer.tkBeginKeyword;
  tkEndKeyword = nextpas.compiler.syntax.lexer.tkEndKeyword;
  tkIfKeyword = nextpas.compiler.syntax.lexer.tkIfKeyword;
  tkThenKeyword = nextpas.compiler.syntax.lexer.tkThenKeyword;
  tkElseKeyword = nextpas.compiler.syntax.lexer.tkElseKeyword;
  tkWhileKeyword = nextpas.compiler.syntax.lexer.tkWhileKeyword;
  tkDoKeyword = nextpas.compiler.syntax.lexer.tkDoKeyword;
  tkForKeyword = nextpas.compiler.syntax.lexer.tkForKeyword;
  tkToKeyword = nextpas.compiler.syntax.lexer.tkToKeyword;
  tkDownToKeyword = nextpas.compiler.syntax.lexer.tkDownToKeyword;
  tkRepeatKeyword = nextpas.compiler.syntax.lexer.tkRepeatKeyword;
  tkUntilKeyword = nextpas.compiler.syntax.lexer.tkUntilKeyword;
  tkWithKeyword = nextpas.compiler.syntax.lexer.tkWithKeyword;
  tkCaseKeyword = nextpas.compiler.syntax.lexer.tkCaseKeyword;
  tkOfKeyword = nextpas.compiler.syntax.lexer.tkOfKeyword;
  tkGotoKeyword = nextpas.compiler.syntax.lexer.tkGotoKeyword;
  tkBreakKeyword = nextpas.compiler.syntax.lexer.tkBreakKeyword;
  tkContinueKeyword = nextpas.compiler.syntax.lexer.tkContinueKeyword;
  tkExitKeyword = nextpas.compiler.syntax.lexer.tkExitKeyword;
  tkVarKeyword = nextpas.compiler.syntax.lexer.tkVarKeyword;
  tkConstKeyword = nextpas.compiler.syntax.lexer.tkConstKeyword;
  tkConstRefKeyword = nextpas.compiler.syntax.lexer.tkConstRefKeyword;
  tkTypeKeyword = nextpas.compiler.syntax.lexer.tkTypeKeyword;
  tkFunctionKeyword = nextpas.compiler.syntax.lexer.tkFunctionKeyword;
  tkArrayKeyword = nextpas.compiler.syntax.lexer.tkArrayKeyword;
  tkSetKeyword = nextpas.compiler.syntax.lexer.tkSetKeyword;
  tkRecordKeyword = nextpas.compiler.syntax.lexer.tkRecordKeyword;
  tkStringKeyword = nextpas.compiler.syntax.lexer.tkStringKeyword;
  tkClassKeyword = nextpas.compiler.syntax.lexer.tkClassKeyword;
  tkObjectKeyword = nextpas.compiler.syntax.lexer.tkObjectKeyword;
  tkConstructorKeyword = nextpas.compiler.syntax.lexer.tkConstructorKeyword;
  tkDestructorKeyword = nextpas.compiler.syntax.lexer.tkDestructorKeyword;
  tkPropertyKeyword = nextpas.compiler.syntax.lexer.tkPropertyKeyword;
  tkInitializationKeyword = nextpas.compiler.syntax.lexer.tkInitializationKeyword;
  tkFinalizationKeyword = nextpas.compiler.syntax.lexer.tkFinalizationKeyword;
  tkExportsKeyword = nextpas.compiler.syntax.lexer.tkExportsKeyword;
  tkLabelKeyword = nextpas.compiler.syntax.lexer.tkLabelKeyword;
  tkThreadVarKeyword = nextpas.compiler.syntax.lexer.tkThreadVarKeyword;
  tkPublishedKeyword = nextpas.compiler.syntax.lexer.tkPublishedKeyword;
  tkPublicKeyword = nextpas.compiler.syntax.lexer.tkPublicKeyword;
  tkPrivateKeyword = nextpas.compiler.syntax.lexer.tkPrivateKeyword;
  tkProtectedKeyword = nextpas.compiler.syntax.lexer.tkProtectedKeyword;
  tkVirtualKeyword = nextpas.compiler.syntax.lexer.tkVirtualKeyword;
  tkOverrideKeyword = nextpas.compiler.syntax.lexer.tkOverrideKeyword;
  tkAbstractKeyword = nextpas.compiler.syntax.lexer.tkAbstractKeyword;
  tkReintroduceKeyword = nextpas.compiler.syntax.lexer.tkReintroduceKeyword;
  tkOverloadKeyword = nextpas.compiler.syntax.lexer.tkOverloadKeyword;
  tkDynamicKeyword = nextpas.compiler.syntax.lexer.tkDynamicKeyword;
  tkMessageKeyword = nextpas.compiler.syntax.lexer.tkMessageKeyword;
  tkStaticKeyword = nextpas.compiler.syntax.lexer.tkStaticKeyword;
  tkInlineKeyword = nextpas.compiler.syntax.lexer.tkInlineKeyword;
  tkForwardKeyword = nextpas.compiler.syntax.lexer.tkForwardKeyword;
  tkDeprecatedKeyword = nextpas.compiler.syntax.lexer.tkDeprecatedKeyword;
  tkPlatformKeyword = nextpas.compiler.syntax.lexer.tkPlatformKeyword;
  tkExperimentalKeyword = nextpas.compiler.syntax.lexer.tkExperimentalKeyword;
  tkStdCallKeyword = nextpas.compiler.syntax.lexer.tkStdCallKeyword;
  tkSafeCallKeyword = nextpas.compiler.syntax.lexer.tkSafeCallKeyword;
  tkRegisterKeyword = nextpas.compiler.syntax.lexer.tkRegisterKeyword;
  tkPascalKeyword = nextpas.compiler.syntax.lexer.tkPascalKeyword;
  tkFarKeyword = nextpas.compiler.syntax.lexer.tkFarKeyword;
  tkNearKeyword = nextpas.compiler.syntax.lexer.tkNearKeyword;
  tkCppDeclKeyword = nextpas.compiler.syntax.lexer.tkCppDeclKeyword;
  tkVarArgsKeyword = nextpas.compiler.syntax.lexer.tkVarArgsKeyword;
  tkOutKeyword = nextpas.compiler.syntax.lexer.tkOutKeyword;
  tkAbsoluteKeyword = nextpas.compiler.syntax.lexer.tkAbsoluteKeyword;
  tkAsmKeyword = nextpas.compiler.syntax.lexer.tkAsmKeyword;
  tkAndKeyword = nextpas.compiler.syntax.lexer.tkAndKeyword;
  tkOrKeyword = nextpas.compiler.syntax.lexer.tkOrKeyword;
  tkNotKeyword = nextpas.compiler.syntax.lexer.tkNotKeyword;
  tkXorKeyword = nextpas.compiler.syntax.lexer.tkXorKeyword;
  tkShlKeyword = nextpas.compiler.syntax.lexer.tkShlKeyword;
  tkShrKeyword = nextpas.compiler.syntax.lexer.tkShrKeyword;
  tkDivKeyword = nextpas.compiler.syntax.lexer.tkDivKeyword;
  tkModKeyword = nextpas.compiler.syntax.lexer.tkModKeyword;
  tkInKeyword = nextpas.compiler.syntax.lexer.tkInKeyword;
  tkIsKeyword = nextpas.compiler.syntax.lexer.tkIsKeyword;
  tkAsKeyword = nextpas.compiler.syntax.lexer.tkAsKeyword;
  tkNilKeyword = nextpas.compiler.syntax.lexer.tkNilKeyword;
  tkRaiseKeyword = nextpas.compiler.syntax.lexer.tkRaiseKeyword;
  tkTryKeyword = nextpas.compiler.syntax.lexer.tkTryKeyword;
  tkExceptKeyword = nextpas.compiler.syntax.lexer.tkExceptKeyword;
  tkFinallyKeyword = nextpas.compiler.syntax.lexer.tkFinallyKeyword;
  tkOnKeyword = nextpas.compiler.syntax.lexer.tkOnKeyword;
  tkInheritedKeyword = nextpas.compiler.syntax.lexer.tkInheritedKeyword;
  tkSelfKeyword = nextpas.compiler.syntax.lexer.tkSelfKeyword;
  tkFileKeyword = nextpas.compiler.syntax.lexer.tkFileKeyword;
  tkResourceStringKeyword = nextpas.compiler.syntax.lexer.tkResourceStringKeyword;
  tkStrictKeyword = nextpas.compiler.syntax.lexer.tkStrictKeyword;
  tkOperatorKeyword = nextpas.compiler.syntax.lexer.tkOperatorKeyword;
  tkGenericKeyword = nextpas.compiler.syntax.lexer.tkGenericKeyword;
  tkSpecializeKeyword = nextpas.compiler.syntax.lexer.tkSpecializeKeyword;
  tkReferenceKeyword = nextpas.compiler.syntax.lexer.tkReferenceKeyword;
  tkPackedKeyword = nextpas.compiler.syntax.lexer.tkPackedKeyword;
  tkContainsKeyword = nextpas.compiler.syntax.lexer.tkContainsKeyword;
  tkRequiresKeyword = nextpas.compiler.syntax.lexer.tkRequiresKeyword;
  tkIdentifier = nextpas.compiler.syntax.lexer.tkIdentifier;
  tkStringLiteral = nextpas.compiler.syntax.lexer.tkStringLiteral;
  tkIntegerLiteral = nextpas.compiler.syntax.lexer.tkIntegerLiteral;
  tkRealLiteral = nextpas.compiler.syntax.lexer.tkRealLiteral;
  tkCharLiteral = nextpas.compiler.syntax.lexer.tkCharLiteral;
  tkCompilerDirective = nextpas.compiler.syntax.lexer.tkCompilerDirective;
  tkSemicolon = nextpas.compiler.syntax.lexer.tkSemicolon;
  tkDot = nextpas.compiler.syntax.lexer.tkDot;
  tkDotDot = nextpas.compiler.syntax.lexer.tkDotDot;
  tkComma = nextpas.compiler.syntax.lexer.tkComma;
  tkColon = nextpas.compiler.syntax.lexer.tkColon;
  tkAssign = nextpas.compiler.syntax.lexer.tkAssign;
  tkPlusAssign = nextpas.compiler.syntax.lexer.tkPlusAssign;
  tkMinusAssign = nextpas.compiler.syntax.lexer.tkMinusAssign;
  tkStarAssign = nextpas.compiler.syntax.lexer.tkStarAssign;
  tkSlashAssign = nextpas.compiler.syntax.lexer.tkSlashAssign;
  tkLParen = nextpas.compiler.syntax.lexer.tkLParen;
  tkRParen = nextpas.compiler.syntax.lexer.tkRParen;
  tkLBracket = nextpas.compiler.syntax.lexer.tkLBracket;
  tkRBracket = nextpas.compiler.syntax.lexer.tkRBracket;
  tkPlus = nextpas.compiler.syntax.lexer.tkPlus;
  tkMinus = nextpas.compiler.syntax.lexer.tkMinus;
  tkStar = nextpas.compiler.syntax.lexer.tkStar;
  tkSlash = nextpas.compiler.syntax.lexer.tkSlash;
  tkEquals = nextpas.compiler.syntax.lexer.tkEquals;
  tkNotEquals = nextpas.compiler.syntax.lexer.tkNotEquals;
  tkLessThan = nextpas.compiler.syntax.lexer.tkLessThan;
  tkGreaterThan = nextpas.compiler.syntax.lexer.tkGreaterThan;
  tkLessEqual = nextpas.compiler.syntax.lexer.tkLessEqual;
  tkGreaterEqual = nextpas.compiler.syntax.lexer.tkGreaterEqual;
  tkAt = nextpas.compiler.syntax.lexer.tkAt;
  tkCaret = nextpas.compiler.syntax.lexer.tkCaret;
  tkEOF = nextpas.compiler.syntax.lexer.tkEOF;
  tvkWhitespace = nextpas.compiler.syntax.lexer.tvkWhitespace;
  tvkLineTerminator = nextpas.compiler.syntax.lexer.tvkLineTerminator;
  tvkLineComment = nextpas.compiler.syntax.lexer.tvkLineComment;
  tvkBraceComment = nextpas.compiler.syntax.lexer.tvkBraceComment;
  tvkParenStarComment = nextpas.compiler.syntax.lexer.tvkParenStarComment;

function CloneTriviaPieceVec(const ATrivia: TTriviaPieceVec; AAllocator: IAllocator = nil): TTriviaPieceVec;
function CloneTokenWithTrivia(const ASrc: TToken; AAllocator: IAllocator = nil): TToken;
procedure FreeTokenNestedTrivia(var AToken: TToken);
procedure FreeTokenVecNestedTrivia(const ATokens: TTokenVec);
function TokenKindName(const AKind: TTokenKind): string;

implementation

function CloneTriviaPieceVec(const ATrivia: TTriviaPieceVec; AAllocator: IAllocator): TTriviaPieceVec;
begin
  Result := nextpas.compiler.syntax.lexer.CloneTriviaPieceVec(ATrivia, AAllocator);
end;

function CloneTokenWithTrivia(const ASrc: TToken; AAllocator: IAllocator): TToken;
begin
  Result := nextpas.compiler.syntax.lexer.CloneTokenWithTrivia(ASrc, AAllocator);
end;

procedure FreeTokenNestedTrivia(var AToken: TToken);
begin
  nextpas.compiler.syntax.lexer.FreeTokenNestedTrivia(AToken);
end;

procedure FreeTokenVecNestedTrivia(const ATokens: TTokenVec);
begin
  nextpas.compiler.syntax.lexer.FreeTokenVecNestedTrivia(ATokens);
end;

function TokenKindName(const AKind: TTokenKind): string;
begin
  Result := nextpas.compiler.syntax.lexer.TokenKindName(AKind);
end;

end.