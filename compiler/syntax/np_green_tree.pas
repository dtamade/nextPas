unit np_green_tree;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../diagnostics}
{$UNITPATH ../frontend}

interface

uses
  np_diagnostics_sink, np_lexer, np_source_database;

type
  TForeignProcedureDecl = record
    ProcedureName: string;
    CallingConvention: string;
    LibraryId: string;
    ExternalSymbolName: string;
    HasExplicitSymbolName: Boolean;
    ByteOffset: LongInt;
  end;

  TGreenNodeKind = (
    gnkUnknown,
    gnkProgram, gnkUnit, gnkLibrary, gnkPackage,
    gnkUsesClause, gnkUseEntry,
    gnkInterfaceSection, gnkImplementationSection,
    gnkInitializationSection, gnkFinalizationSection,
    gnkForeignProcedureDecl,
    gnkBeginBlock, gnkEndBlock,
    gnkStatementList,
    gnkIfStatement, gnkWhileStatement, gnkForStatement,
    gnkForInStatement,
    gnkRepeatStatement, gnkWithStatement, gnkCaseStatement,
    gnkCaseSelector, gnkCaseLabel,
    gnkAssignmentStatement, gnkProcedureCallStatement,
    gnkGotoStatement, gnkBreakStatement, gnkContinueStatement,
    gnkExitStatement,
    gnkTryExceptStatement, gnkTryFinallyStatement,
    gnkExceptionHandler, gnkRaiseStatement,
    gnkVarSection, gnkConstSection, gnkTypeSection,
    gnkLabelSection,
    gnkVarDecl, gnkConstDecl, gnkTypeDecl,
    gnkProcedureDecl, gnkFunctionDecl,
    gnkRecordType, gnkArrayType, gnkClassType, gnkEnumType,
    gnkClassField, gnkClassMethod, gnkClassProperty,
    gnkVisibilityLabel,
    gnkTypeParamList,
    gnkIdentifier, gnkStringLiteral, gnkIntegerLiteral,
    gnkRealLiteral, gnkCharLiteral,
    gnkBinaryExpression, gnkUnaryExpression,
    gnkDotAccess, gnkArrayAccess, gnkFunctionCall,
    gnkDereference, gnkAddressOf,
    gnkSetConstructor, gnkRangeExpression,
    gnkParameterList, gnkParameterDecl,
    gnkFieldList,
    gnkError
  );

  TGreenRootKind = (
    grkUnknown,
    grkProgram,
    grkUnit,
    grkLibrary,
    grkPackage
  );

  TGreenNode = class
  private
    FNodeKind: TGreenNodeKind;
    FByteOffset: LongInt;
    FByteLength: LongInt;
    FText: string;
    FChildren: array of TGreenNode;
    procedure AppendChild(const AChild: TGreenNode);
  public
    constructor Create(
      const ANodeKind: TGreenNodeKind;
      const AByteOffset: LongInt;
      const AByteLength: LongInt;
      const AText: string
    );
    destructor Destroy; override;
    function NodeKindName: string;
    function ChildCount: LongInt;
    function ChildAt(const AIndex: LongInt): TGreenNode;
    property NodeKind: TGreenNodeKind read FNodeKind;
    property ByteOffset: LongInt read FByteOffset;
    property ByteLength: LongInt read FByteLength;
    property Text: string read FText;
  end;

  TGreenTree = class
  private
    FRootKind: TGreenRootKind;
    FDeclaredName: string;
    FNodeCount: LongInt;
    FIsValid: Boolean;
    FInterfaceUses: array of string;
    FImplementationUses: array of string;
    FForeignProcedureDecls: array of TForeignProcedureDecl;
    FRootNode: TGreenNode;
    procedure AppendInterfaceUse(const AUseName: string);
    procedure AppendImplementationUse(const AUseName: string);
    procedure AppendForeignProcedureDecl(
      const AForeignProcedureDecl: TForeignProcedureDecl
    );
  public
    constructor Create;
    destructor Destroy; override;
    function RootKindName: string;
    function InterfaceUseCount: LongInt;
    function InterfaceUseAt(const AIndex: LongInt): string;
    function ImplementationUseCount: LongInt;
    function ImplementationUseAt(const AIndex: LongInt): string;
    function ForeignProcedureDeclCount: LongInt;
    function ForeignProcedureDeclAt(
      const AIndex: LongInt
    ): TForeignProcedureDecl;
    function GreenNodeCount: LongInt;
    property RootKind: TGreenRootKind read FRootKind;
    property DeclaredName: string read FDeclaredName;
    property NodeCount: LongInt read FNodeCount;
    property IsValid: Boolean read FIsValid;
    property RootNode: TGreenNode read FRootNode;
  end;

function ParseGreenTree(
  const ALexer: TLexerResult;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenTree;

function GreenNodeKindLabel(const AKind: TGreenNodeKind): string;
function GreenNodeIsNil(const ANode: TGreenNode): Boolean;
function GreenNodeKindNameOf(const ANode: TGreenNode): string;

implementation

uses
  nextpas.core.text.conv;

type
  TUseSectionKind = (
    uskInterface,
    uskImplementation
  );

  TTokenKindSet = set of TTokenKind;

var
  ActiveExpressionTree: TGreenTree = nil;

function CurrentToken(const ALexer: TLexerResult; const ACursor: LongInt): TToken;
  forward;

procedure SkipToSyncSet(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ASyncSet: TTokenKindSet
); forward;

function ParseExpression(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode; forward;

function ParseStatementList(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATerminatorSet: TTokenKindSet;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseBeginBlock(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseIfStatement(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseWhileStatement(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseForStatement(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseRepeatStatement(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseWithStatement(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseCaseStatement(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseTryStatement(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseAssignmentOrCall(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseBlockDeclarations(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseVarSection(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseConstSection(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseTypeSection(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseProcedureDecl(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseFunctionDecl(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseParameterList(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean; forward;

function ParseTypeReference(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode; forward;

function ParseAnonymousRoutineExpression(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode; forward;

function DecodePascalStringLiteral(const ALexeme: string): string;
var
  Index: SizeInt;
begin
  if (Length(ALexeme) < 2) or (ALexeme[1] <> '''') or
    (ALexeme[Length(ALexeme)] <> '''') then
    Exit(ALexeme);

  Result := '';
  Index := 2;
  while Index < Length(ALexeme) do
  begin
    if (ALexeme[Index] = '''') and (Index + 1 < Length(ALexeme)) and
      (ALexeme[Index + 1] = '''') then
    begin
      Result := Result + '''';
      Inc(Index, 2);
      Continue;
    end;

    Result := Result + ALexeme[Index];
    Inc(Index);
  end;
end;

function RootKindFromToken(const AKind: TTokenKind): TGreenRootKind;
begin
  case AKind of
    tkProgramKeyword:
      Result := grkProgram;
    tkUnitKeyword:
      Result := grkUnit;
    tkLibraryKeyword:
      Result := grkLibrary;
    tkPackageKeyword:
      Result := grkPackage;
  else
    Result := grkUnknown;
  end;
end;

function GreenNodeKindFromRootKind(const AKind: TGreenRootKind): TGreenNodeKind;
begin
  case AKind of
    grkProgram:
      Result := gnkProgram;
    grkUnit:
      Result := gnkUnit;
    grkLibrary:
      Result := gnkLibrary;
    grkPackage:
      Result := gnkPackage;
  else
    Result := gnkUnknown;
  end;
end;

function RootKeywordLabel(const AKind: TGreenRootKind): string;
begin
  case AKind of
    grkProgram:
      Result := 'program';
    grkUnit:
      Result := 'unit';
    grkLibrary:
      Result := 'library';
    grkPackage:
      Result := 'package';
  else
    Result := 'unknown';
  end;
end;

function GreenNodeKindLabel(const AKind: TGreenNodeKind): string;
begin
  case AKind of
    gnkUnknown: Result := 'unknown';
    gnkProgram: Result := 'program';
    gnkUnit: Result := 'unit';
    gnkLibrary: Result := 'library';
    gnkPackage: Result := 'package';
    gnkUsesClause: Result := 'uses-clause';
    gnkUseEntry: Result := 'use-entry';
    gnkInterfaceSection: Result := 'interface-section';
    gnkImplementationSection: Result := 'implementation-section';
    gnkInitializationSection: Result := 'initialization-section';
    gnkFinalizationSection: Result := 'finalization-section';
    gnkForeignProcedureDecl: Result := 'foreign-procedure-decl';
    gnkBeginBlock: Result := 'begin-block';
    gnkEndBlock: Result := 'end-block';
    gnkStatementList: Result := 'statement-list';
    gnkIfStatement: Result := 'if-statement';
    gnkWhileStatement: Result := 'while-statement';
    gnkForStatement: Result := 'for-statement';
    gnkForInStatement: Result := 'for-in-statement';
    gnkRepeatStatement: Result := 'repeat-statement';
    gnkWithStatement: Result := 'with-statement';
    gnkCaseStatement: Result := 'case-statement';
    gnkCaseSelector: Result := 'case-selector';
    gnkCaseLabel: Result := 'case-label';
    gnkAssignmentStatement: Result := 'assignment-statement';
    gnkProcedureCallStatement: Result := 'procedure-call-statement';
    gnkGotoStatement: Result := 'goto-statement';
    gnkBreakStatement: Result := 'break-statement';
    gnkContinueStatement: Result := 'continue-statement';
    gnkExitStatement: Result := 'exit-statement';
    gnkTryExceptStatement: Result := 'try-except-statement';
    gnkTryFinallyStatement: Result := 'try-finally-statement';
    gnkExceptionHandler: Result := 'exception-handler';
    gnkRaiseStatement: Result := 'raise-statement';
    gnkVarSection: Result := 'var-section';
    gnkConstSection: Result := 'const-section';
    gnkTypeSection: Result := 'type-section';
    gnkLabelSection: Result := 'label-section';
    gnkVarDecl: Result := 'var-decl';
    gnkConstDecl: Result := 'const-decl';
    gnkTypeDecl: Result := 'type-decl';
    gnkProcedureDecl: Result := 'procedure-decl';
    gnkFunctionDecl: Result := 'function-decl';
    gnkRecordType: Result := 'record-type';
    gnkArrayType: Result := 'array-type';
    gnkClassType: Result := 'class-type';
    gnkClassField: Result := 'class-field';
    gnkClassMethod: Result := 'class-method';
    gnkClassProperty: Result := 'class-property';
    gnkVisibilityLabel: Result := 'visibility-label';
    gnkTypeParamList: Result := 'type-param-list';
    gnkEnumType: Result := 'enum-type';
    gnkIdentifier: Result := 'identifier';
    gnkStringLiteral: Result := 'string-literal';
    gnkIntegerLiteral: Result := 'integer-literal';
    gnkRealLiteral: Result := 'real-literal';
    gnkCharLiteral: Result := 'char-literal';
    gnkBinaryExpression: Result := 'binary-expression';
    gnkUnaryExpression: Result := 'unary-expression';
    gnkDotAccess: Result := 'dot-access';
    gnkArrayAccess: Result := 'array-access';
    gnkFunctionCall: Result := 'function-call';
    gnkDereference: Result := 'dereference';
    gnkAddressOf: Result := 'address-of';
    gnkSetConstructor: Result := 'set-constructor';
    gnkRangeExpression: Result := 'range-expression';
    gnkParameterList: Result := 'parameter-list';
    gnkParameterDecl: Result := 'parameter-decl';
    gnkFieldList: Result := 'field-list';
    gnkError: Result := 'error';
  else
    Result := 'unknown';
  end;
end;

function GreenNodeIsNil(const ANode: TGreenNode): Boolean;
begin
  Result := ANode = nil;
end;

function GreenNodeKindNameOf(const ANode: TGreenNode): string;
begin
  if ANode = nil then
    Exit('unknown');
  Result := ANode.NodeKindName;
end;

function TokenLabel(const AToken: TToken): string;
begin
  if AToken.Kind = tkEOF then
    Exit('end-of-file');

  if AToken.Lexeme <> '' then
    Exit(UpperCase(AToken.Lexeme));

  Result := UpperCase(TokenKindName(AToken.Kind));
end;

function BuildExpectedButFoundMessage(
  const AExpected: string;
  const AFoundToken: TToken
): string;
var
  FoundLabel: string;
begin
  FoundLabel := TokenLabel(AFoundToken);
  if FoundLabel = 'end-of-file' then
    Exit('Syntax error, "' + AExpected + '" expected but end-of-file found');

  Result := 'Syntax error, "' + AExpected + '" expected but "' + FoundLabel + '" found';
end;

procedure EmitSyntaxError(
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const AToken: TToken;
  const AExpected: string
);
var
  EffectiveFileId: TSourceFileId;
begin
  EffectiveFileId := ARootFileId;
  if AToken.FileId <> 0 then
    EffectiveFileId := AToken.FileId;
  ADiagnostics.EmitError(
    'parser.syntax-error',
    'syntax',
    EffectiveFileId,
    AToken.ByteOffset,
    BuildExpectedButFoundMessage(AExpected, AToken)
  );
end;

procedure AdvanceCursor(var ACursor: LongInt);
begin
  Inc(ACursor);
end;

function IsCallingDirective(const ALexeme: string): Boolean;
var
  L: string;
begin
  L := LowerCase(ALexeme);
  Result := (L = 'inline') or (L = 'overload') or (L = 'cdecl') or
    (L = 'stdcall') or (L = 'register') or (L = 'pascal') or
    (L = 'safecall') or (L = 'static') or (L = 'virtual') or
    (L = 'override') or (L = 'abstract') or (L = 'reintroduce') or
    (L = 'export') or (L = 'far') or (L = 'near') or
    (L = 'nostackframe') or (L = 'assembler') or (L = 'compilerproc') or
    (L = 'platform') or (L = 'deprecated') or (L = 'experimental') or
    (L = 'unimplemented') or (L = 'library') or (L = 'interrupt');
end;


function IsMethodNameToken(AKind: TTokenKind): Boolean;
begin
  Result := (AKind = tkIdentifier) or
    (AKind = tkContainsKeyword) or (AKind = tkRequiresKeyword) or
    (AKind = tkNameKeyword) or (AKind = tkMessageKeyword) or
    (AKind = tkStringKeyword) or (AKind = tkFileKeyword) or
    (AKind = tkOnKeyword) or (AKind = tkIsKeyword) or
    (AKind = tkAsKeyword) or (AKind = tkInKeyword) or
    (AKind = tkSelfKeyword) or (AKind = tkInlineKeyword) or
    (AKind = tkOverloadKeyword) or (AKind = tkVirtualKeyword) or
    (AKind = tkOverrideKeyword) or (AKind = tkAbstractKeyword) or
    (AKind = tkStaticKeyword) or (AKind = tkDynamicKeyword) or
    (AKind = tkReintroduceKeyword) or (AKind = tkDeprecatedKeyword) or
    (AKind = tkPlatformKeyword) or (AKind = tkExperimentalKeyword);
end;

function IsOperatorNameToken(AKind: TTokenKind): Boolean;
begin
  Result := AKind in [tkPlus, tkMinus, tkStar, tkSlash, tkEquals,
    tkNotEquals, tkLessThan, tkGreaterThan, tkLessEqual, tkGreaterEqual,
    tkModKeyword, tkDivKeyword, tkShlKeyword, tkShrKeyword, tkAndKeyword,
    tkOrKeyword, tkXorKeyword, tkNotKeyword, tkInKeyword];
end;

function IsDeclNameToken(AKind: TTokenKind): Boolean;
begin
  Result := IsMethodNameToken(AKind) or IsOperatorNameToken(AKind);
end;

function IsDirectiveToken(AKind: TTokenKind): Boolean;
begin
  Result := AKind in [tkInlineKeyword, tkOverloadKeyword, tkCdeclKeyword,
    tkVirtualKeyword, tkOverrideKeyword, tkAbstractKeyword, tkStaticKeyword,
    tkDeprecatedKeyword, tkPlatformKeyword, tkExperimentalKeyword];
end;

procedure SkipDirectives(const ALexer: TLexerResult; var ACursor: LongInt);
begin
  while (ACursor < ALexer.TokenCount) and
    (ALexer.TokenAt(ACursor).Kind = tkCompilerDirective) do
    Inc(ACursor);
end;

function CurrentToken(const ALexer: TLexerResult; const ACursor: LongInt): TToken;
begin
  Result := ALexer.TokenAt(ACursor);
end;

function ConsumeIdentifierPath(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AAllowDots: Boolean;
  out AName: string;
  out AByteOffset: LongInt
): Boolean;
begin
  AName := '';
  AByteOffset := 0;
  if (ACursor >= ALexer.TokenCount) or
    (CurrentToken(ALexer, ACursor).Kind <> tkIdentifier) then
    Exit(False);

  AByteOffset := CurrentToken(ALexer, ACursor).ByteOffset;
  AName := CurrentToken(ALexer, ACursor).Lexeme;
  AdvanceCursor(ACursor);

  if AAllowDots then
    while (ACursor + 1 < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkDot) and
      IsMethodNameToken(ALexer.TokenAt(ACursor + 1).Kind) do
    begin
      AdvanceCursor(ACursor);
      AName := AName + '.' + CurrentToken(ALexer, ACursor).Lexeme;
      AdvanceCursor(ACursor);
    end;

  Result := True;
end;

procedure SkipToSyncSet(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ASyncSet: TTokenKindSet
);
begin
  while (ACursor < ALexer.TokenCount) and
    not (CurrentToken(ALexer, ACursor).Kind in ASyncSet) do
    Inc(ACursor);
end;

function MatchToken(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AExpected: TTokenKind;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const AExpectedLabel: string
): Boolean;
begin
  SkipDirectives(ALexer, ACursor);
  if ACursor >= ALexer.TokenCount then
  begin
    Result := False;
    Exit;
  end;
  Result := CurrentToken(ALexer, ACursor).Kind = AExpected;
  if not Result then
  begin
    EmitSyntaxError(
      ADiagnostics,
      ARootFileId,
      CurrentToken(ALexer, ACursor),
      AExpectedLabel
    );
    Exit;
  end;

  AdvanceCursor(ACursor);
end;

function MatchTokenSilent(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AExpected: TTokenKind
): Boolean;
begin
  SkipDirectives(ALexer, ACursor);
  if ACursor >= ALexer.TokenCount then
    Exit(False);
  Result := CurrentToken(ALexer, ACursor).Kind = AExpected;
  if Result then
    AdvanceCursor(ACursor);
end;

function ParseUsesClause(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ATree: TGreenTree;
  const ASectionKind: TUseSectionKind;
  const AParent: TGreenNode;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  UseName: string;
  UseOffset: LongInt;
  UsesNode: TGreenNode;
begin
  Result := True;
  if CurrentToken(ALexer, ACursor).Kind <> tkUsesKeyword then
    Exit;

  UsesNode := TGreenNode.Create(
    gnkUsesClause,
    CurrentToken(ALexer, ACursor).ByteOffset,
    0,
    ''
  );
  Inc(ATree.FNodeCount);
  AdvanceCursor(ACursor);

  while True do
  begin
    if not ConsumeIdentifierPath(
      ALexer,
      ACursor,
      True,
      UseName,
      UseOffset
    ) then
    begin
      EmitSyntaxError(
        ADiagnostics,
        ARootFileId,
        CurrentToken(ALexer, ACursor),
        'identifier'
      );
      UsesNode.Free;
      Exit(False);
    end;

    if ASectionKind = uskInterface then
      ATree.AppendInterfaceUse(UseName)
    else
      ATree.AppendImplementationUse(UseName);

    UsesNode.AppendChild(TGreenNode.Create(
      gnkUseEntry,
      UseOffset,
      Length(UseName),
      UseName
    ));

    Inc(ATree.FNodeCount);

    if CurrentToken(ALexer, ACursor).Kind <> tkComma then
      Break;

    Inc(ATree.FNodeCount);
    AdvanceCursor(ACursor);
  end;

  if not MatchToken(
    ALexer,
    ACursor,
    tkSemicolon,
    ADiagnostics,
    ARootFileId,
    ';'
  ) then
  begin
    UsesNode.Free;
    Exit(False);
  end;

  AParent.AppendChild(UsesNode);
  Inc(ATree.FNodeCount);
end;

function FindTokenKind(
  const ALexer: TLexerResult;
  const AStartIndex: LongInt;
  const AExpected: TTokenKind
): LongInt;
var
  Index: LongInt;
begin
  for Index := AStartIndex to ALexer.TokenCount - 1 do
    if ALexer.TokenAt(Index).Kind = AExpected then
      Exit(Index);

  Result := -1;
end;

function TryParseForeignProcedureDecl(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ATree: TGreenTree;
  const AParent: TGreenNode
): Boolean;
var
  ForeignProcedureDecl: TForeignProcedureDecl;
  LookaheadCursor: LongInt;
  DeclNode: TGreenNode;
begin
  Result := False;
  if CurrentToken(ALexer, ACursor).Kind <> tkProcedureKeyword then
    Exit;

  LookaheadCursor := ACursor;
  ForeignProcedureDecl.ProcedureName := '';
  ForeignProcedureDecl.CallingConvention := '';
  ForeignProcedureDecl.LibraryId := '';
  ForeignProcedureDecl.ExternalSymbolName := '';
  ForeignProcedureDecl.HasExplicitSymbolName := False;
  ForeignProcedureDecl.ByteOffset :=
    CurrentToken(ALexer, LookaheadCursor).ByteOffset;
  AdvanceCursor(LookaheadCursor);

  if CurrentToken(ALexer, LookaheadCursor).Kind <> tkIdentifier then
    Exit;
  ForeignProcedureDecl.ProcedureName :=
    CurrentToken(ALexer, LookaheadCursor).Lexeme;
  AdvanceCursor(LookaheadCursor);

  if CurrentToken(ALexer, LookaheadCursor).Kind <> tkSemicolon then
    Exit;
  AdvanceCursor(LookaheadCursor);

  if CurrentToken(ALexer, LookaheadCursor).Kind <> tkCdeclKeyword then
    Exit;
  ForeignProcedureDecl.CallingConvention := 'cdecl';
  AdvanceCursor(LookaheadCursor);

  if CurrentToken(ALexer, LookaheadCursor).Kind <> tkSemicolon then
    Exit;
  AdvanceCursor(LookaheadCursor);

  if CurrentToken(ALexer, LookaheadCursor).Kind <> tkExternalKeyword then
    Exit;
  AdvanceCursor(LookaheadCursor);

  if CurrentToken(ALexer, LookaheadCursor).Kind <> tkStringLiteral then
    Exit;
  ForeignProcedureDecl.LibraryId := DecodePascalStringLiteral(
    CurrentToken(ALexer, LookaheadCursor).Lexeme
  );
  AdvanceCursor(LookaheadCursor);

  if (CurrentToken(ALexer, LookaheadCursor).Kind = tkNameKeyword) or
    ((CurrentToken(ALexer, LookaheadCursor).Kind = tkIdentifier) and
     SameText(CurrentToken(ALexer, LookaheadCursor).Lexeme, 'name')) then
  begin
    AdvanceCursor(LookaheadCursor);
    if CurrentToken(ALexer, LookaheadCursor).Kind <> tkStringLiteral then
      Exit;
    ForeignProcedureDecl.ExternalSymbolName := DecodePascalStringLiteral(
      CurrentToken(ALexer, LookaheadCursor).Lexeme
    );
    ForeignProcedureDecl.HasExplicitSymbolName := True;
    AdvanceCursor(LookaheadCursor);
  end;

  if CurrentToken(ALexer, LookaheadCursor).Kind <> tkSemicolon then
    Exit;
  AdvanceCursor(LookaheadCursor);

  ATree.AppendForeignProcedureDecl(ForeignProcedureDecl);

  DeclNode := TGreenNode.Create(
    gnkForeignProcedureDecl,
    ForeignProcedureDecl.ByteOffset,
    0,
    ForeignProcedureDecl.ProcedureName
  );
  AParent.AppendChild(DeclNode);

  Inc(ATree.FNodeCount);
  ACursor := LookaheadCursor;
  Result := True;
end;

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
      tkInheritedKeyword, tkContainsKeyword, tkRequiresKeyword,
      tkOnKeyword, tkIsKeyword, tkAsKeyword, tkInKeyword,
      tkInlineKeyword, tkOverloadKeyword:
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
            Result.Free;
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
     gnkDereference]) then
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
            if Result.NodeKind in [gnkIdentifier, gnkDotAccess] then
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
      Left.Free;
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
      Left.Free;
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
      Left.Free;
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
                  [tkMinus, tkPlus, tkIntegerLiteral]) then
                Inc(ACursor);
              if (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind = tkColon) then
              begin
                Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind in
                    [tkMinus, tkPlus, tkIntegerLiteral]) then
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
                    [tkMinus, tkPlus, tkIntegerLiteral]) then
                  Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                begin
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind in
                      [tkMinus, tkPlus, tkIntegerLiteral]) then
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
      LhsNode.Free;
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
      LhsNode.Free;
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

  LowExpr.Free;
  HighExpr.Free;
end;

function ParseTypeReference(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode;
var
  Token: TToken;
  NameNode, ArgNode, RangeNode: TGreenNode;
  SpecArgs: string;
  Depth: LongInt;
begin
  if ACursor >= ALexer.TokenCount then
    Exit(nil);

  Token := CurrentToken(ALexer, ACursor);
  case Token.Kind of
    tkIdentifier:
      begin
        NameNode := TGreenNode.Create(gnkIdentifier, Token.ByteOffset,
          Length(Token.Lexeme), Token.Lexeme);
        Inc(ACursor);

        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkLBracket) then
        begin
          Inc(ACursor);
          Result := TGreenNode.Create(gnkArrayType, Token.ByteOffset, 0, '');
          Result.AppendChild(NameNode);
          ArgNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
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
          NameNode.FText := NameNode.FText + SpecArgs;
        end;

        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkDot) do
        begin
          Inc(ACursor);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
          begin
            NameNode.FText := NameNode.FText + '.' +
              CurrentToken(ALexer, ACursor).Lexeme;
            Inc(ACursor);
          end
          else
            Break;
        end;

        Result := NameNode;
      end;
    tkStringKeyword, tkFileKeyword:
      begin
        Result := TGreenNode.Create(gnkIdentifier, Token.ByteOffset,
          Length(Token.Lexeme), Token.Lexeme);
        Inc(ACursor);
      end;
    tkArrayKeyword:
      begin
        Result := TGreenNode.Create(gnkArrayType, Token.ByteOffset, 0, '');
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
            ArgNode := TGreenNode.Create(gnkIdentifier,
              CurrentToken(ALexer, ACursor).ByteOffset,
              Length(CurrentToken(ALexer, ACursor).Lexeme),
              CurrentToken(ALexer, ACursor).Lexeme);
            Inc(ACursor);
          end
          else
            ArgNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
          if ArgNode <> nil then
            Result.AppendChild(ArgNode);
          if RangeNode <> nil then
            Result.AppendChild(RangeNode);
        end
        else
          RangeNode.Free;
      end;
    tkSetKeyword:
      begin
        Result := TGreenNode.Create(gnkIdentifier, Token.ByteOffset, 0, 'set');
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
        Result := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
        if Result <> nil then
          Result.FText := '^' + Result.FText;
      end;
    tkSpecializeKeyword:
      begin
        Inc(ACursor);
        Result := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
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
          Result.FText := Result.FText + SpecArgs;
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
              ALexer, ACursor, ADiagnostics, ARootFileId);
            NameNode.Free;
          end;
        end;
        Result := TGreenNode.Create(gnkIdentifier, Token.ByteOffset,
          Length(Token.Lexeme), Token.Lexeme);
      end;
  else
    Exit(nil);
  end;
end;

function ParseAnonymousRoutineExpression(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode;
var
  Node: TGreenNode;
  RoutineKind: TTokenKind;
  TypeNode: TGreenNode;
begin
  Result := nil;
  if ActiveExpressionTree = nil then
    Exit;

  RoutineKind := CurrentToken(ALexer, ACursor).Kind;
  case RoutineKind of
    tkFunctionKeyword:
      Node := TGreenNode.Create(gnkFunctionDecl,
        CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
    tkProcedureKeyword:
      Node := TGreenNode.Create(gnkProcedureDecl,
        CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  else
    Exit;
  end;

  Inc(ACursor);
  ParseParameterList(ALexer, ACursor, Node, ActiveExpressionTree,
    ADiagnostics, ARootFileId);

  if RoutineKind = tkFunctionKeyword then
  begin
    if not MatchTokenSilent(ALexer, ACursor, tkColon) then
    begin
      EmitSyntaxError(ADiagnostics, ARootFileId,
        CurrentToken(ALexer, ACursor), ':');
      Node.Free;
      Exit(nil);
    end;

    TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
    if TypeNode <> nil then
    begin
      Node.AppendChild(TypeNode);
      Inc(ActiveExpressionTree.FNodeCount);
    end;
  end;

  while (ACursor < ALexer.TokenCount) and
    (IsDirectiveToken(CurrentToken(ALexer, ACursor).Kind) or
     ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
      IsCallingDirective(CurrentToken(ALexer, ACursor).Lexeme))) do
    Inc(ACursor);

  if not MatchTokenSilent(ALexer, ACursor, tkBeginKeyword) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'BEGIN');
    Node.Free;
    Exit(nil);
  end;

  if not ParseBeginBlock(ALexer, ACursor, Node, ActiveExpressionTree,
    ADiagnostics, ARootFileId) then
  begin
    Node.Free;
    Exit(nil);
  end;

  Result := Node;
end;

function ParseParameterList(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  List: TGreenNode;
  Decl: TGreenNode;
  NameToken: TToken;
  TypeNode, DefaultExpr: TGreenNode;
  I: LongInt;
  Child: TGreenNode;
  ParamModifier: string;
begin
  if (ACursor >= ALexer.TokenCount) or
    (CurrentToken(ALexer, ACursor).Kind <> tkLParen) then
    Exit(True);

  List := TGreenNode.Create(gnkParameterList,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  AParent.AppendChild(List);
  Inc(ATree.FNodeCount);
  Inc(ACursor);

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind <> tkRParen) do
  begin
    ParamModifier := '';
    if CurrentToken(ALexer, ACursor).Kind in
      [tkVarKeyword, tkConstKeyword, tkOutKeyword] then
    begin
      if CurrentToken(ALexer, ACursor).Kind = tkVarKeyword then
        ParamModifier := 'var:'
      else if CurrentToken(ALexer, ACursor).Kind = tkOutKeyword then
        ParamModifier := 'out:';
      Inc(ACursor);
    end;

    if not IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
    begin
      EmitSyntaxError(ADiagnostics, ARootFileId,
        CurrentToken(ALexer, ACursor), 'identifier');
      SkipToSyncSet(ALexer, ACursor, [tkRParen, tkSemicolon, tkEOF]);
      Break;
    end;

    while True do
    begin
      NameToken := CurrentToken(ALexer, ACursor);
      if ParamModifier <> '' then
        Decl := TGreenNode.Create(gnkParameterDecl, NameToken.ByteOffset, 0,
          ParamModifier + NameToken.Lexeme)
      else
        Decl := TGreenNode.Create(gnkParameterDecl, NameToken.ByteOffset, 0,
          NameToken.Lexeme);
      List.AppendChild(Decl);
      Inc(ATree.FNodeCount);
      Inc(ACursor);

      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkComma) then
        Inc(ACursor)
      else
        Break;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkColon) then
    begin
      Inc(ACursor);
      TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
      if TypeNode <> nil then
      begin
        for I := 0 to List.ChildCount - 1 do
        begin
          Child := List.ChildAt(I);
          if (Child <> nil) and (Child.NodeKind = gnkParameterDecl) and
            (Child.ChildCount = 0) then
          begin
            Child.AppendChild(TGreenNode.Create(gnkIdentifier,
              TypeNode.ByteOffset, TypeNode.ByteLength, TypeNode.Text));
            Inc(ATree.FNodeCount);
          end;
        end;
        List.AppendChild(TypeNode);
        Inc(ATree.FNodeCount);
      end;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkEquals) then
    begin
      Inc(ACursor);
      DefaultExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
      if (DefaultExpr <> nil) and (List.ChildCount > 0) then
      begin
        for I := List.ChildCount - 1 downto 0 do
        begin
          Child := List.ChildAt(I);
          if (Child <> nil) and (Child.NodeKind = gnkParameterDecl) then
          begin
            Child.AppendChild(DefaultExpr);
            Inc(ATree.FNodeCount);
            Break;
          end;
        end;
      end;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) then
      Inc(ACursor);
  end;

  MatchTokenSilent(ALexer, ACursor, tkRParen);
  Result := True;
end;

function ParseVarSection(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Section: TGreenNode;
  Decl: TGreenNode;
  NameToken: TToken;
  TypeNode: TGreenNode;
  I: LongInt;
  Child: TGreenNode;
begin
  Section := TGreenNode.Create(gnkVarSection,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  AParent.AppendChild(Section);
  Inc(ATree.FNodeCount);
  Inc(ACursor);

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) do
  begin
    NameToken := CurrentToken(ALexer, ACursor);
    Decl := TGreenNode.Create(gnkVarDecl, NameToken.ByteOffset, 0,
      NameToken.Lexeme);
    Section.AppendChild(Decl);
    Inc(ATree.FNodeCount);
    Inc(ACursor);

    while (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkComma) do
    begin
      Inc(ACursor);
      if CurrentToken(ALexer, ACursor).Kind = tkIdentifier then
      begin
        NameToken := CurrentToken(ALexer, ACursor);
        Decl := TGreenNode.Create(gnkVarDecl, NameToken.ByteOffset, 0,
          NameToken.Lexeme);
        Section.AppendChild(Decl);
        Inc(ATree.FNodeCount);
        Inc(ACursor);
      end;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkColon) then
    begin
      Inc(ACursor);
      TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
      if TypeNode <> nil then
      begin
        for I := 0 to Section.ChildCount - 1 do
        begin
          Child := Section.ChildAt(I);
          if (Child <> nil) and (Child.NodeKind = gnkVarDecl) and
            (Child.ChildCount = 0) then
          begin
            Child.AppendChild(TGreenNode.Create(gnkIdentifier,
              TypeNode.ByteOffset, TypeNode.ByteLength, TypeNode.Text));
            Inc(ATree.FNodeCount);
          end;
        end;
        Section.AppendChild(TypeNode);
        Inc(ATree.FNodeCount);
      end;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkEquals) then
    begin
      Inc(ACursor);
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
    end;

    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
  end;

  Result := True;
end;

function ParseConstSection(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Section: TGreenNode;
  Decl: TGreenNode;
  NameToken: TToken;
  ValueExpr: TGreenNode;
begin
  Section := TGreenNode.Create(gnkConstSection,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  AParent.AppendChild(Section);
  Inc(ATree.FNodeCount);
  Inc(ACursor);

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) do
  begin
    NameToken := CurrentToken(ALexer, ACursor);
    Decl := TGreenNode.Create(gnkConstDecl, NameToken.ByteOffset, 0,
      NameToken.Lexeme);
    Section.AppendChild(Decl);
    Inc(ATree.FNodeCount);
    Inc(ACursor);

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkColon) then
    begin
      Inc(ACursor);
      ValueExpr := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
      if ValueExpr <> nil then
      begin
        Decl.AppendChild(ValueExpr);
        Inc(ATree.FNodeCount);
      end;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkEquals) then
    begin
      Inc(ACursor);
      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
      begin
        Inc(ACursor);
        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind <> tkRParen) and
          (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        begin
          if CurrentToken(ALexer, ACursor).Kind = tkLParen then
          begin
            Inc(ACursor);
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkRParen) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
              Inc(ACursor);
            MatchTokenSilent(ALexer, ACursor, tkRParen);
          end
          else
            Inc(ACursor);
        end;
        MatchTokenSilent(ALexer, ACursor, tkRParen);
      end
      else
      begin
        ValueExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
        if ValueExpr <> nil then
        begin
          Decl.AppendChild(ValueExpr);
          Inc(ATree.FNodeCount);
        end;
      end;
    end;

    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
  end;

  Result := True;
end;

function ParseTypeSection(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Section: TGreenNode;
  Decl: TGreenNode;
  NameToken: TToken;
  TypeNode: TGreenNode;
  TypeParamNode: TGreenNode;
  IndexNode: TGreenNode;
  ElementNode: TGreenNode;
  FieldTypeNode: TGreenNode;
  RangeNode: TGreenNode;
  SpecArgs: string;
  FieldGroupStart, I, K: LongInt;
  FieldNode: TGreenNode;
  UsedOriginalTypeNode: Boolean;

  function CloneTypeNode(const ANode: TGreenNode): TGreenNode;
  var
    ChildClone: TGreenNode;
    ChildIndex: LongInt;
  begin
    Result := nil;
    if ANode = nil then
      Exit;
    Result := TGreenNode.Create(ANode.NodeKind, ANode.ByteOffset,
      ANode.ByteLength, ANode.Text);
    Inc(ATree.FNodeCount);
    for ChildIndex := 0 to ANode.ChildCount - 1 do
    begin
      ChildClone := CloneTypeNode(ANode.ChildAt(ChildIndex));
      if ChildClone <> nil then
        Result.AppendChild(ChildClone);
    end;
  end;
begin
  Section := TGreenNode.Create(gnkTypeSection,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  AParent.AppendChild(Section);
  Inc(ATree.FNodeCount);
  Inc(ACursor);

  while True do
  begin
    SkipDirectives(ALexer, ACursor);
    if (ACursor >= ALexer.TokenCount) or
      ((CurrentToken(ALexer, ACursor).Kind <> tkIdentifier) and
       (CurrentToken(ALexer, ACursor).Kind <> tkGenericKeyword)) then
      Break;
    if (CurrentToken(ALexer, ACursor).Kind = tkGenericKeyword) and
      (ACursor + 1 < ALexer.TokenCount) and
      (ALexer.TokenAt(ACursor + 1).Kind = tkIdentifier) then
      Inc(ACursor)
    else if CurrentToken(ALexer, ACursor).Kind = tkGenericKeyword then
      Break;
    if (ACursor >= ALexer.TokenCount) or
      (CurrentToken(ALexer, ACursor).Kind <> tkIdentifier) then
      Break;
    NameToken := CurrentToken(ALexer, ACursor);
    Decl := TGreenNode.Create(gnkTypeDecl, NameToken.ByteOffset, 0,
      NameToken.Lexeme);
    Section.AppendChild(Decl);
    Inc(ATree.FNodeCount);
    Inc(ACursor);

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkLessThan) then
    begin
      TypeParamNode := TGreenNode.Create(gnkTypeParamList,
        CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
      Inc(ACursor);
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkGreaterThan) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
      begin
        if CurrentToken(ALexer, ACursor).Kind = tkIdentifier then
        begin
          SpecArgs := CurrentToken(ALexer, ACursor).Lexeme;
          Inc(ACursor);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkColon) then
          begin
            Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind in
                [tkIdentifier, tkClassKeyword, tkRecordKeyword]) then
            begin
              SpecArgs := SpecArgs + ':' + CurrentToken(ALexer, ACursor).Lexeme;
              Inc(ACursor);
            end;
          end;
          ElementNode := TGreenNode.Create(gnkIdentifier,
            CurrentToken(ALexer, ACursor - 1).ByteOffset, 0, SpecArgs);
          TypeParamNode.AppendChild(ElementNode);
          Inc(ATree.FNodeCount);
        end
        else
          Inc(ACursor);
      end;
      MatchTokenSilent(ALexer, ACursor, tkGreaterThan);
      Decl.AppendChild(TypeParamNode);
      Inc(ATree.FNodeCount);
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkEquals) then
      Inc(ACursor);

    { type X = type Y: 跳过 distinct type 标记
      但不跳过 type helper (type + identifier + for) }
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkTypeKeyword) and
      not ((ACursor + 2 < ALexer.TokenCount) and
        (ALexer.TokenAt(ACursor + 1).Kind = tkIdentifier) and
        (ALexer.TokenAt(ACursor + 2).Kind = tkForKeyword)) then
      Inc(ACursor);

    if (ACursor < ALexer.TokenCount) then
    begin
      case CurrentToken(ALexer, ACursor).Kind of
        tkRecordKeyword:
          begin
            TypeNode := TGreenNode.Create(gnkRecordType,
              CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
            Decl.AppendChild(TypeNode);
            Inc(ATree.FNodeCount);
            Inc(ACursor);
            SkipDirectives(ALexer, ACursor);
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
              (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
            begin
              if CurrentToken(ALexer, ACursor).Kind = tkIdentifier then
              begin
                IndexNode := TGreenNode.Create(gnkVarDecl,
                  CurrentToken(ALexer, ACursor).ByteOffset, 0,
                  CurrentToken(ALexer, ACursor).Lexeme);
                TypeNode.AppendChild(IndexNode);
                Inc(ATree.FNodeCount);
                Inc(ACursor);
                while (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkComma) do
                begin
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                  begin
                    IndexNode := TGreenNode.Create(gnkVarDecl,
                      CurrentToken(ALexer, ACursor).ByteOffset, 0,
                      CurrentToken(ALexer, ACursor).Lexeme);
                    TypeNode.AppendChild(IndexNode);
                    Inc(ATree.FNodeCount);
                    Inc(ACursor);
                  end;
                end;
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                begin
                  Inc(ACursor);
                  ElementNode := ParseTypeReference(ALexer, ACursor,
                    ADiagnostics, ARootFileId);
                  if ElementNode <> nil then
                  begin
                    IndexNode.AppendChild(ElementNode);
                    Inc(ATree.FNodeCount);
                  end;
                end;
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
              end
              else if CurrentToken(ALexer, ACursor).Kind in
                [tkPublicKeyword, tkPrivateKeyword, tkProtectedKeyword,
                 tkPublishedKeyword] then
              begin
                ElementNode := TGreenNode.Create(gnkVisibilityLabel,
                  CurrentToken(ALexer, ACursor).ByteOffset, 0,
                  CurrentToken(ALexer, ACursor).Lexeme);
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
                Inc(ACursor);
              end
              else if CurrentToken(ALexer, ACursor).Kind = tkCaseKeyword then
              begin
                I := 1;
                Inc(ACursor);
                while (ACursor < ALexer.TokenCount) and (I > 0) and
                  (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                begin
                  if CurrentToken(ALexer, ACursor).Kind in
                    [tkRecordKeyword, tkCaseKeyword] then
                    Inc(I)
                  else if CurrentToken(ALexer, ACursor).Kind = tkEndKeyword then
                    Dec(I);
                  if I > 0 then
                    Inc(ACursor);
                end;
              end
              else if CurrentToken(ALexer, ACursor).Kind in
                [tkClassKeyword, tkProcedureKeyword, tkFunctionKeyword,
                 tkConstructorKeyword, tkDestructorKeyword, tkOperatorKeyword,
                 tkPropertyKeyword, tkStaticKeyword, tkGenericKeyword] then
              begin
                I := 0;
                while (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                  (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
                  (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                begin
                  if CurrentToken(ALexer, ACursor).Kind = tkLParen then Inc(I)
                  else if CurrentToken(ALexer, ACursor).Kind = tkRParen then Dec(I)
                  else if (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) and (I <= 0) then
                    Break;
                  Inc(ACursor);
                end;
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                while (ACursor < ALexer.TokenCount) and
                  (IsDirectiveToken(CurrentToken(ALexer, ACursor).Kind) or
                   ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                    IsCallingDirective(CurrentToken(ALexer, ACursor).Lexeme))) do
                begin
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkStringLiteral) then
                    Inc(ACursor);
                  MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                end;
              end
              else
                Inc(ACursor);
            end;
            MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
          end;
        tkArrayKeyword:
          begin
            TypeNode := TGreenNode.Create(gnkArrayType,
              CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
            RangeNode := nil;
            Decl.AppendChild(TypeNode);
            Inc(ATree.FNodeCount);
            Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkLBracket) then
            begin
              Inc(ACursor);
              RangeNode := ParseArrayBoundsRange(ALexer, ACursor,
                ADiagnostics, ARootFileId);
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
                ElementNode := TGreenNode.Create(gnkIdentifier,
                  CurrentToken(ALexer, ACursor).ByteOffset,
                  Length(CurrentToken(ALexer, ACursor).Lexeme),
                  CurrentToken(ALexer, ACursor).Lexeme);
                Inc(ACursor);
              end
              else
                ElementNode := ParseTypeReference(ALexer, ACursor, ADiagnostics,
                  ARootFileId);
              if ElementNode <> nil then
              begin
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
              end;
              if RangeNode <> nil then
              begin
                TypeNode.AppendChild(RangeNode);
                Inc(ATree.FNodeCount);
              end;
            end
            else
              RangeNode.Free;
          end;
        tkClassKeyword:
          begin
            TypeNode := TGreenNode.Create(gnkClassType,
              CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
            Decl.AppendChild(TypeNode);
            Inc(ATree.FNodeCount);
            Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
            begin
              Inc(ACursor);
              ElementNode := ParseTypeReference(ALexer, ACursor, ADiagnostics,
                ARootFileId);
              if ElementNode <> nil then
              begin
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
              end;
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind = tkComma) do
              begin
                Inc(ACursor);
                ElementNode := ParseTypeReference(ALexer, ACursor, ADiagnostics,
                  ARootFileId);
                if ElementNode <> nil then
                begin
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                end;
              end;
              MatchTokenSilent(ALexer, ACursor, tkRParen);
            end;
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) then
            begin
              // Forward class declaration: class; or class(parent);
            end
            else if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkOfKeyword) then
            begin
              Inc(ACursor);
              ElementNode := ParseTypeReference(ALexer, ACursor, ADiagnostics,
                ARootFileId);
              if ElementNode <> nil then
              begin
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
              end;
            end
            else
            begin
            I := 0;
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) and
              not ((I = 0) and (CurrentToken(ALexer, ACursor).Kind = tkEndKeyword)) do
            begin
              if CurrentToken(ALexer, ACursor).Kind in
                [tkRecordKeyword, tkObjectKeyword] then
                Inc(I)
              else if (CurrentToken(ALexer, ACursor).Kind = tkEndKeyword) and (I > 0) then
              begin
                Dec(I);
                Inc(ACursor);
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                Continue;
              end;
              if CurrentToken(ALexer, ACursor).Kind in
                [tkPublicKeyword, tkPrivateKeyword, tkProtectedKeyword,
                 tkPublishedKeyword] then
              begin
                ElementNode := TGreenNode.Create(gnkVisibilityLabel,
                  CurrentToken(ALexer, ACursor).ByteOffset, 0,
                  CurrentToken(ALexer, ACursor).Lexeme);
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
                Inc(ACursor);
              end
              else if CurrentToken(ALexer, ACursor).Kind in
                [tkProcedureKeyword, tkFunctionKeyword,
                 tkConstructorKeyword, tkDestructorKeyword,
                 tkGenericKeyword, tkClassKeyword] then
              begin
                ElementNode := TGreenNode.Create(gnkClassMethod,
                  CurrentToken(ALexer, ACursor).ByteOffset, 0,
                  TokenKindName(CurrentToken(ALexer, ACursor).Kind));
                Inc(ACursor);
                while (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind in
                    [tkClassKeyword, tkProcedureKeyword, tkFunctionKeyword,
                     tkConstructorKeyword, tkDestructorKeyword,
                     tkGenericKeyword, tkOperatorKeyword]) do
                  Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
                begin
                  ElementNode.AppendChild(TGreenNode.Create(gnkIdentifier,
                    CurrentToken(ALexer, ACursor).ByteOffset, 0,
                    CurrentToken(ALexer, ACursor).Lexeme));
                  Inc(ATree.FNodeCount);
                  Inc(ACursor);
                end;
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkLessThan) then
                begin
                  while (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkGreaterThan) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                    Inc(ACursor);
                  if ACursor < ALexer.TokenCount then Inc(ACursor);
                end;
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
                  ParseParameterList(ALexer, ACursor, ElementNode, ATree,
                    ADiagnostics, ARootFileId);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                begin
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) or
                     (CurrentToken(ALexer, ACursor).Kind = tkStringKeyword)) then
                  begin
                    ElementNode.AppendChild(TGreenNode.Create(gnkIdentifier,
                      CurrentToken(ALexer, ACursor).ByteOffset, 0,
                      CurrentToken(ALexer, ACursor).Lexeme));
                    Inc(ATree.FNodeCount);
                    Inc(ACursor);
                  end;
                end;
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                while (ACursor < ALexer.TokenCount) and
                  (IsDirectiveToken(CurrentToken(ALexer, ACursor).Kind) or
                   (CurrentToken(ALexer, ACursor).Kind in
                    [tkVirtualKeyword, tkOverrideKeyword, tkAbstractKeyword,
                     tkOverloadKeyword]) or
                   ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                    IsCallingDirective(CurrentToken(ALexer, ACursor).Lexeme))) do
                begin
                  if CurrentToken(ALexer, ACursor).Kind = tkVirtualKeyword then
                    ElementNode.FText := ElementNode.FText + ';virtual'
                  else if CurrentToken(ALexer, ACursor).Kind = tkOverrideKeyword then
                    ElementNode.FText := ElementNode.FText + ';override'
                  else if CurrentToken(ALexer, ACursor).Kind = tkAbstractKeyword then
                    ElementNode.FText := ElementNode.FText + ';virtual;abstract';
                  Inc(ACursor);
                  MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                end;
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
              end
              else if CurrentToken(ALexer, ACursor).Kind = tkPropertyKeyword then
              begin
                Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                begin
                  ElementNode := TGreenNode.Create(gnkClassProperty,
                    CurrentToken(ALexer, ACursor).ByteOffset, 0,
                    CurrentToken(ALexer, ACursor).Lexeme);
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                  begin
                    Inc(ACursor);
                    if (ACursor < ALexer.TokenCount) and
                      (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                    begin
                      IndexNode := TGreenNode.Create(gnkIdentifier,
                        CurrentToken(ALexer, ACursor).ByteOffset, 0,
                        CurrentToken(ALexer, ACursor).Lexeme);
                      ElementNode.AppendChild(IndexNode);
                      Inc(ATree.FNodeCount);
                      Inc(ACursor);
                    end;
                  end;
                  while (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                  begin
                    if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                      (LowerCase(CurrentToken(ALexer, ACursor).Lexeme) = 'read') then
                    begin
                      Inc(ACursor);
                      if (ACursor < ALexer.TokenCount) and
                        (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                      begin
                        IndexNode := TGreenNode.Create(gnkIdentifier,
                          CurrentToken(ALexer, ACursor).ByteOffset, 0,
                          'read:' + CurrentToken(ALexer, ACursor).Lexeme);
                        ElementNode.AppendChild(IndexNode);
                        Inc(ATree.FNodeCount);
                        Inc(ACursor);
                      end;
                    end
                    else if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                      (LowerCase(CurrentToken(ALexer, ACursor).Lexeme) = 'write') then
                    begin
                      Inc(ACursor);
                      if (ACursor < ALexer.TokenCount) and
                        (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                      begin
                        IndexNode := TGreenNode.Create(gnkIdentifier,
                          CurrentToken(ALexer, ACursor).ByteOffset, 0,
                          'write:' + CurrentToken(ALexer, ACursor).Lexeme);
                        ElementNode.AppendChild(IndexNode);
                        Inc(ATree.FNodeCount);
                        Inc(ACursor);
                      end;
                    end
                    else
                      Inc(ACursor);
                  end;
                end
                else
                begin
                  while (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                    Inc(ACursor);
                end;
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
              end
              else if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                (LowerCase(CurrentToken(ALexer, ACursor).Lexeme) = 'where') then
              begin
                Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                begin
                  SpecArgs := CurrentToken(ALexer, ACursor).Lexeme;
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                  begin
                    Inc(ACursor);
                    SpecArgs := SpecArgs + ':';
                    if (ACursor < ALexer.TokenCount) and
                      (CurrentToken(ALexer, ACursor).Kind in
                        [tkIdentifier, tkClassKeyword, tkRecordKeyword]) then
                    begin
                      SpecArgs := SpecArgs + CurrentToken(ALexer, ACursor).Lexeme;
                      Inc(ACursor);
                      while (ACursor < ALexer.TokenCount) and
                        (CurrentToken(ALexer, ACursor).Kind = tkComma) do
                      begin
                        Inc(ACursor);
                        if (ACursor < ALexer.TokenCount) and
                          (CurrentToken(ALexer, ACursor).Kind in
                            [tkIdentifier, tkClassKeyword, tkRecordKeyword]) then
                        begin
                          SpecArgs := SpecArgs + '|' +
                            CurrentToken(ALexer, ACursor).Lexeme;
                          Inc(ACursor);
                        end;
                      end;
                    end;
                  end;
                  ElementNode := TGreenNode.Create(gnkIdentifier,
                    CurrentToken(ALexer, ACursor - 1).ByteOffset, 0,
                    'where:' + SpecArgs);
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                end;
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
              end
              else if CurrentToken(ALexer, ACursor).Kind = tkIdentifier then
              begin
                ElementNode := TGreenNode.Create(gnkClassField,
                  CurrentToken(ALexer, ACursor).ByteOffset, 0,
                  CurrentToken(ALexer, ACursor).Lexeme);
                Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkComma) then
                begin
                  FieldGroupStart := TypeNode.ChildCount;
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                  while (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkComma) do
                  begin
                    Inc(ACursor);
                    if (ACursor < ALexer.TokenCount) and
                      (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                    begin
                      ElementNode := TGreenNode.Create(gnkClassField,
                        CurrentToken(ALexer, ACursor).ByteOffset, 0,
                        CurrentToken(ALexer, ACursor).Lexeme);
                      TypeNode.AppendChild(ElementNode);
                      Inc(ATree.FNodeCount);
                      Inc(ACursor);
                    end;
                  end;
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                  begin
                    Inc(ACursor);
                    FieldTypeNode := ParseTypeReference(ALexer, ACursor,
                      ADiagnostics, ARootFileId);
                    UsedOriginalTypeNode := False;
                    if FieldTypeNode <> nil then
                      for K := FieldGroupStart to TypeNode.ChildCount - 1 do
                      begin
                        FieldNode := TypeNode.ChildAt(K);
                        if (FieldNode = nil) or
                          (FieldNode.NodeKind <> gnkClassField) or
                          (FieldNode.ChildCount <> 0) then
                          Continue;
                        if not UsedOriginalTypeNode then
                        begin
                          FieldNode.AppendChild(FieldTypeNode);
                          Inc(ATree.FNodeCount);
                          UsedOriginalTypeNode := True;
                        end
                        else
                          FieldNode.AppendChild(CloneTypeNode(FieldTypeNode));
                      end;
                  end;
                  MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                end
                else if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                begin
                  Inc(ACursor);
                  FieldTypeNode := ParseTypeReference(ALexer, ACursor,
                    ADiagnostics, ARootFileId);
                  if FieldTypeNode <> nil then
                  begin
                    ElementNode.AppendChild(FieldTypeNode);
                    Inc(ATree.FNodeCount);
                  end;
                  MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                end
                else
                begin
                  I := 0;
                  while (ACursor < ALexer.TokenCount) and
                    not ((I = 0) and (CurrentToken(ALexer, ACursor).Kind in
                      [tkSemicolon, tkEndKeyword, tkEOF])) do
                  begin
                    if CurrentToken(ALexer, ACursor).Kind in
                      [tkRecordKeyword, tkObjectKeyword] then
                      Inc(I)
                    else if (CurrentToken(ALexer, ACursor).Kind = tkEndKeyword) and
                      (I > 0) then
                      Dec(I);
                    Inc(ACursor);
                  end;
                  MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                end;
              end
              else
                Inc(ACursor);
            end;
            MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
            end;
          end;
        tkInterfaceKeyword:
          begin
            TypeNode := TGreenNode.Create(gnkClassType,
              CurrentToken(ALexer, ACursor).ByteOffset, 0, 'interface');
            Decl.AppendChild(TypeNode);
            Inc(ATree.FNodeCount);
            Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
            begin
              Inc(ACursor);
              ElementNode := ParseTypeReference(ALexer, ACursor, ADiagnostics,
                ARootFileId);
              if ElementNode <> nil then
              begin
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
              end;
              MatchTokenSilent(ALexer, ACursor, tkRParen);
            end;
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkLBracket) then
            begin
              Inc(ACursor);
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkRBracket) and
                (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                Inc(ACursor);
              MatchTokenSilent(ALexer, ACursor, tkRBracket);
            end;
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
            begin
              if CurrentToken(ALexer, ACursor).Kind in
                [tkProcedureKeyword, tkFunctionKeyword] then
              begin
                ElementNode := TGreenNode.Create(gnkClassMethod,
                  CurrentToken(ALexer, ACursor).ByteOffset, 0,
                  TokenKindName(CurrentToken(ALexer, ACursor).Kind));
                Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                begin
                  ElementNode.AppendChild(TGreenNode.Create(gnkIdentifier,
                    CurrentToken(ALexer, ACursor).ByteOffset, 0,
                    CurrentToken(ALexer, ACursor).Lexeme));
                  Inc(ATree.FNodeCount);
                  Inc(ACursor);
                end;
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
                  ParseParameterList(ALexer, ACursor, ElementNode, ATree,
                    ADiagnostics, ARootFileId);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                begin
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) or
                     (CurrentToken(ALexer, ACursor).Kind = tkStringKeyword)) then
                  begin
                    ElementNode.AppendChild(TGreenNode.Create(gnkIdentifier,
                      CurrentToken(ALexer, ACursor).ByteOffset, 0,
                      CurrentToken(ALexer, ACursor).Lexeme));
                    Inc(ATree.FNodeCount);
                    Inc(ACursor);
                  end;
                end;
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
              end
              else if CurrentToken(ALexer, ACursor).Kind = tkPropertyKeyword then
              begin
                Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                begin
                  ElementNode := TGreenNode.Create(gnkClassProperty,
                    CurrentToken(ALexer, ACursor).ByteOffset, 0,
                    CurrentToken(ALexer, ACursor).Lexeme);
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkColon) then
                  begin
                    Inc(ACursor);
                    if (ACursor < ALexer.TokenCount) and
                      (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                    begin
                      IndexNode := TGreenNode.Create(gnkIdentifier,
                        CurrentToken(ALexer, ACursor).ByteOffset, 0,
                        CurrentToken(ALexer, ACursor).Lexeme);
                      ElementNode.AppendChild(IndexNode);
                      Inc(ATree.FNodeCount);
                      Inc(ACursor);
                    end;
                  end;
                  while (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                  begin
                    if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                      (LowerCase(CurrentToken(ALexer, ACursor).Lexeme) = 'read') then
                    begin
                      Inc(ACursor);
                      if (ACursor < ALexer.TokenCount) and
                        (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                      begin
                        IndexNode := TGreenNode.Create(gnkIdentifier,
                          CurrentToken(ALexer, ACursor).ByteOffset, 0,
                          'read:' + CurrentToken(ALexer, ACursor).Lexeme);
                        ElementNode.AppendChild(IndexNode);
                        Inc(ATree.FNodeCount);
                        Inc(ACursor);
                      end;
                    end
                    else if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
                      (LowerCase(CurrentToken(ALexer, ACursor).Lexeme) = 'write') then
                    begin
                      Inc(ACursor);
                      if (ACursor < ALexer.TokenCount) and
                        (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                      begin
                        IndexNode := TGreenNode.Create(gnkIdentifier,
                          CurrentToken(ALexer, ACursor).ByteOffset, 0,
                          'write:' + CurrentToken(ALexer, ACursor).Lexeme);
                        ElementNode.AppendChild(IndexNode);
                        Inc(ATree.FNodeCount);
                        Inc(ACursor);
                      end;
                    end
                    else
                      Inc(ACursor);
                  end;
                end
                else
                begin
                  while (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                    (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                    Inc(ACursor);
                end;
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
              end
              else
                Inc(ACursor);
            end;
            MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
          end;
        tkLParen:
          begin
            TypeNode := TGreenNode.Create(gnkEnumType,
              CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
            Decl.AppendChild(TypeNode);
            Inc(ATree.FNodeCount);
            Inc(ACursor);
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkRParen) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
            begin
              if CurrentToken(ALexer, ACursor).Kind = tkIdentifier then
              begin
                TypeNode.AppendChild(TGreenNode.Create(gnkIdentifier,
                  CurrentToken(ALexer, ACursor).ByteOffset,
                  Length(CurrentToken(ALexer, ACursor).Lexeme),
                  CurrentToken(ALexer, ACursor).Lexeme));
                Inc(ATree.FNodeCount);
                Inc(ACursor);
              end;
              if (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind = tkEquals) then
              begin
                Inc(ACursor);
                ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
              end;
              if (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind = tkComma) then
                Inc(ACursor);
            end;
            MatchTokenSilent(ALexer, ACursor, tkRParen);
          end;
        tkSetKeyword:
          begin
            Inc(ACursor);
            MatchTokenSilent(ALexer, ACursor, tkOfKeyword);
            TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
            if TypeNode <> nil then
            begin
              Decl.AppendChild(TypeNode);
              Inc(ATree.FNodeCount);
            end;
          end;
        tkCaret:
          begin
            Inc(ACursor);
            TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
            if TypeNode <> nil then
            begin
              Decl.AppendChild(TypeNode);
              Inc(ATree.FNodeCount);
            end;
          end;
        tkProcedureKeyword, tkFunctionKeyword:
          begin
            Inc(ACursor);
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
              TypeNode := ParseTypeReference(
                ALexer,
                ACursor,
                ADiagnostics,
                ARootFileId
              );
              TypeNode.Free;
            end;
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
              Inc(ACursor);
          end;
        tkTypeKeyword:
          begin
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
              Inc(ACursor);
            MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
          end;
        tkPackedKeyword:
          begin
            Inc(ACursor);
            SkipDirectives(ALexer, ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkRecordKeyword) then
            begin
              TypeNode := TGreenNode.Create(gnkRecordType,
                CurrentToken(ALexer, ACursor).ByteOffset, 0, 'packed');
              Decl.AppendChild(TypeNode);
              Inc(ATree.FNodeCount);
              Inc(ACursor);
              SkipDirectives(ALexer, ACursor);
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
                (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                Inc(ACursor);
              MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
            end
            else
            begin
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
                (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                Inc(ACursor);
            end;
          end;
        tkMinus, tkPlus, tkIntegerLiteral, tkCharLiteral:
          begin
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
              Inc(ACursor);
          end;
      else
        TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
        if TypeNode <> nil then
        begin
          Decl.AppendChild(TypeNode);
          Inc(ATree.FNodeCount);
        end;
      end;
    end;

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind in
        [tkDeprecatedKeyword, tkPlatformKeyword, tkExperimentalKeyword]) then
    begin
      Inc(ACursor);
      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkStringLiteral) then
        Inc(ACursor);
    end;
    if not MatchTokenSilent(ALexer, ACursor, tkSemicolon) then
    begin
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    end;
  end;

  Result := True;
end;

function ParseProcedureDecl(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Node: TGreenNode;
  NameToken: TToken;
  I: LongInt;
  J: LongInt;
  TypeParamText: string;
begin
  Node := TGreenNode.Create(gnkProcedureDecl,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  Inc(ACursor);

  if (ACursor >= ALexer.TokenCount) or
    (CurrentToken(ALexer, ACursor).Kind <> tkIdentifier) then
  begin
    Node.Free;
    Exit(False);
  end;

  NameToken := CurrentToken(ALexer, ACursor);
  Node.FText := NameToken.Lexeme;
  Inc(ACursor);

  if (ACursor < ALexer.TokenCount) and
    (NameToken.Kind = tkStar) and
    (CurrentToken(ALexer, ACursor).Kind = tkStar) then
  begin
    Node.FText := '**';
    Inc(ACursor);
  end;

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkDot) do
  begin
    Inc(ACursor);
    if (ACursor < ALexer.TokenCount) and
      IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
    begin
      Node.FText := Node.FText + '.' + CurrentToken(ALexer, ACursor).Lexeme;
      Inc(ACursor);
    end
    else
      Break;
  end;

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkLessThan) then
  begin
    Inc(ACursor);
    TypeParamText := '';
    while (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind <> tkGreaterThan) and
      (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
    begin
      if CurrentToken(ALexer, ACursor).Kind = tkIdentifier then
      begin
        if TypeParamText <> '' then
          TypeParamText := TypeParamText + ',';
        TypeParamText := TypeParamText + CurrentToken(ALexer, ACursor).Lexeme;
      end;
      Inc(ACursor);
    end;
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkGreaterThan) then
      Inc(ACursor);
    if TypeParamText <> '' then
      Node.FText := Node.FText + '<' + TypeParamText + '>';
  end;

  ParseParameterList(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId);

  MatchTokenSilent(ALexer, ACursor, tkSemicolon);

  while (ACursor < ALexer.TokenCount) and
    (IsDirectiveToken(CurrentToken(ALexer, ACursor).Kind) or
     ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
      IsCallingDirective(CurrentToken(ALexer, ACursor).Lexeme))) do
  begin
    if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
      SameText(CurrentToken(ALexer, ACursor).Lexeme, 'compilerproc') then
      Node.FText := Node.FText + ';compilerproc';
    Inc(ACursor);
    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
  end;

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkForwardKeyword) then
  begin
    Inc(ACursor);
    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
  end
  else if AParent.NodeKind <> gnkInterfaceSection then
  begin
    while (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind in
        [tkVarKeyword, tkConstKeyword, tkTypeKeyword, tkLabelKeyword,
         tkFunctionKeyword, tkProcedureKeyword]) do
    begin
      if (CurrentToken(ALexer, ACursor).Kind in [tkFunctionKeyword, tkProcedureKeyword]) then
      begin
        if (ACursor + 2 < ALexer.TokenCount) and
          (ALexer.TokenAt(ACursor + 2).Kind = tkDot) then
          Break;
        J := ACursor + 1;
        while (J < ALexer.TokenCount) and
          not (ALexer.TokenAt(J).Kind in [tkBeginKeyword, tkAsmKeyword,
            tkImplementationKeyword, tkInitializationKeyword, tkEOF]) do
          Inc(J);
        if (J >= ALexer.TokenCount) or
          not (ALexer.TokenAt(J).Kind in [tkBeginKeyword, tkAsmKeyword]) then
          Break;
      end;
      I := ACursor;
      if CurrentToken(ALexer, ACursor).Kind = tkFunctionKeyword then
        ParseFunctionDecl(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else if CurrentToken(ALexer, ACursor).Kind = tkProcedureKeyword then
        ParseProcedureDecl(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else if CurrentToken(ALexer, ACursor).Kind = tkVarKeyword then
        ParseVarSection(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else
      begin
        Inc(ACursor);
        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind <> tkBeginKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkAsmKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkVarKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkConstKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkTypeKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkFunctionKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkProcedureKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
          Inc(ACursor);
      end;
      if ACursor = I then begin Inc(ACursor); Break; end;
    end;
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkBeginKeyword) then
    begin
      Inc(ACursor);
      ParseBeginBlock(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId);
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    end
    else if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkAsmKeyword) then
    begin
      Inc(ACursor);
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
      MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    end
    else
    begin
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkProcedureKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkFunctionKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkConstructorKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkDestructorKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkBeginKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkInitializationKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkFinalizationKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkOperatorKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
    end;
  end;

  AParent.AppendChild(Node);
  Inc(ATree.FNodeCount);
  Result := True;
end;

function ParseFunctionDecl(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  Node: TGreenNode;
  NameToken: TToken;
  TypeNode: TGreenNode;
  I: LongInt;
  J: LongInt;
  TypeParamText: string;
begin
  Node := TGreenNode.Create(gnkFunctionDecl,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  Inc(ACursor);

  SkipDirectives(ALexer, ACursor);
  if (ACursor >= ALexer.TokenCount) or
    not IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
  begin
    Node.Free;
    Exit(False);
  end;

  NameToken := CurrentToken(ALexer, ACursor);
  Node.FText := NameToken.Lexeme;
  Inc(ACursor);

  if (ACursor < ALexer.TokenCount) and
    (NameToken.Kind = tkStar) and
    (CurrentToken(ALexer, ACursor).Kind = tkStar) then
  begin
    Node.FText := '**';
    Inc(ACursor);
  end;

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkDot) do
  begin
    Inc(ACursor);
    if (ACursor < ALexer.TokenCount) and
      IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
    begin
      Node.FText := Node.FText + '.' + CurrentToken(ALexer, ACursor).Lexeme;
      Inc(ACursor);
    end
    else
      Break;
  end;

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkLessThan) then
  begin
    Inc(ACursor);
    TypeParamText := '';
    while (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind <> tkGreaterThan) and
      (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
    begin
      if CurrentToken(ALexer, ACursor).Kind = tkIdentifier then
      begin
        if TypeParamText <> '' then
          TypeParamText := TypeParamText + ',';
        TypeParamText := TypeParamText + CurrentToken(ALexer, ACursor).Lexeme;
      end;
      Inc(ACursor);
    end;
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkGreaterThan) then
      Inc(ACursor);
    if TypeParamText <> '' then
      Node.FText := Node.FText + '<' + TypeParamText + '>';
  end;

  ParseParameterList(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId);

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
    (ACursor + 1 < ALexer.TokenCount) and
    (ALexer.TokenAt(ACursor + 1).Kind = tkColon) then
    Inc(ACursor);

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkColon) then
  begin
    Inc(ACursor);
    TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId);
    if TypeNode <> nil then
    begin
      Node.AppendChild(TypeNode);
      Inc(ATree.FNodeCount);
    end;
  end;

  MatchTokenSilent(ALexer, ACursor, tkSemicolon);

  while (ACursor < ALexer.TokenCount) and
    (IsDirectiveToken(CurrentToken(ALexer, ACursor).Kind) or
     ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
      IsCallingDirective(CurrentToken(ALexer, ACursor).Lexeme))) do
  begin
    if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
      SameText(CurrentToken(ALexer, ACursor).Lexeme, 'compilerproc') then
      Node.FText := Node.FText + ';compilerproc';
    Inc(ACursor);
    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
  end;

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkForwardKeyword) then
  begin
    Inc(ACursor);
    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
  end
  else if AParent.NodeKind <> gnkInterfaceSection then
  begin
    while (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind in
        [tkVarKeyword, tkConstKeyword, tkTypeKeyword, tkLabelKeyword,
         tkFunctionKeyword, tkProcedureKeyword]) do
    begin
      if (CurrentToken(ALexer, ACursor).Kind in [tkFunctionKeyword, tkProcedureKeyword]) then
      begin
        if (ACursor + 2 < ALexer.TokenCount) and
          (ALexer.TokenAt(ACursor + 2).Kind = tkDot) then
          Break;
        J := ACursor + 1;
        while (J < ALexer.TokenCount) and
          not (ALexer.TokenAt(J).Kind in [tkBeginKeyword, tkAsmKeyword,
            tkImplementationKeyword, tkInitializationKeyword, tkEOF]) do
          Inc(J);
        if (J >= ALexer.TokenCount) or
          not (ALexer.TokenAt(J).Kind in [tkBeginKeyword, tkAsmKeyword]) then
          Break;
      end;
      I := ACursor;
      if CurrentToken(ALexer, ACursor).Kind = tkFunctionKeyword then
        ParseFunctionDecl(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else if CurrentToken(ALexer, ACursor).Kind = tkProcedureKeyword then
        ParseProcedureDecl(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else if CurrentToken(ALexer, ACursor).Kind = tkVarKeyword then
        ParseVarSection(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else
      begin
        Inc(ACursor);
        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind <> tkBeginKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkAsmKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkVarKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkConstKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkTypeKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkFunctionKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkProcedureKeyword) and
          (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
          Inc(ACursor);
      end;
      if ACursor = I then begin Inc(ACursor); Break; end;
    end;
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkBeginKeyword) then
    begin
      Inc(ACursor);
      ParseBeginBlock(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId);
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    end
    else if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkAsmKeyword) then
    begin
      Inc(ACursor);
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
      MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    end
    else
    begin
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkProcedureKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkFunctionKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkConstructorKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkDestructorKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkBeginKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkInitializationKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkFinalizationKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkOperatorKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
    end;
  end;

  AParent.AppendChild(Node);
  Inc(ATree.FNodeCount);
  Result := True;
end;

function ParseBlockDeclarations(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AParent: TGreenNode;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  DeclTerminatorSet: TTokenKindSet;
begin
  DeclTerminatorSet := [tkBeginKeyword, tkEndKeyword,
    tkImplementationKeyword, tkInitializationKeyword,
    tkFinalizationKeyword, tkEOF];

  Result := True;
  while True do
  begin
    SkipDirectives(ALexer, ACursor);
    if (ACursor >= ALexer.TokenCount) or
      (CurrentToken(ALexer, ACursor).Kind in DeclTerminatorSet) then
      Break;
    case CurrentToken(ALexer, ACursor).Kind of
      tkVarKeyword:
        Result := ParseVarSection(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkThreadVarKeyword:
        Result := ParseVarSection(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkConstKeyword:
        Result := ParseConstSection(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkResourceStringKeyword:
        Result := ParseConstSection(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkTypeKeyword:
        Result := ParseTypeSection(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkLabelKeyword:
        begin
          AParent.AppendChild(TGreenNode.Create(gnkLabelSection,
            CurrentToken(ALexer, ACursor).ByteOffset, 0, ''));
          Inc(ATree.FNodeCount);
          Inc(ACursor);
          while (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind <> tkSemicolon) and
            (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
            Inc(ACursor);
          MatchTokenSilent(ALexer, ACursor, tkSemicolon);
        end;
      tkProcedureKeyword:
        if not TryParseForeignProcedureDecl(ALexer, ACursor, ATree, AParent) then
          Result := ParseProcedureDecl(ALexer, ACursor, AParent, ATree,
            ADiagnostics, ARootFileId) and Result;
      tkFunctionKeyword:
        Result := ParseFunctionDecl(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkConstructorKeyword, tkDestructorKeyword:
        Result := ParseProcedureDecl(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkOperatorKeyword:
        Result := ParseFunctionDecl(ALexer, ACursor, AParent, ATree,
          ADiagnostics, ARootFileId) and Result;
      tkGenericKeyword:
        begin
          Inc(ACursor);
          SkipDirectives(ALexer, ACursor);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkFunctionKeyword) then
            Result := ParseFunctionDecl(ALexer, ACursor, AParent, ATree,
              ADiagnostics, ARootFileId) and Result
          else if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkProcedureKeyword) then
            Result := ParseProcedureDecl(ALexer, ACursor, AParent, ATree,
              ADiagnostics, ARootFileId) and Result;
        end;
      tkEndKeyword:
        begin
          Inc(ACursor);
          MatchTokenSilent(ALexer, ACursor, tkSemicolon);
        end;
    else
      AdvanceCursor(ACursor);
    end;
  end;
end;

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
    Node.Free;
    Exit(False);
  end;

  ParseStatementList(ALexer, ACursor, Node,
    [tkElseKeyword, tkEndKeyword, tkSemicolon, tkEOF],
    ATree, ADiagnostics, ARootFileId);

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
    Node.Free;
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
      Node.Free;
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

  Node := TGreenNode.Create(gnkForStatement, ForOffset, 0, '');
  Node.AppendChild(TGreenNode.Create(gnkIdentifier, VarToken.ByteOffset,
    Length(VarToken.Lexeme), VarToken.Lexeme));

  if not MatchTokenSilent(ALexer, ACursor, tkAssign) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), ':=');
    Node.Free;
    Exit(False);
  end;

  RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
  if RHS <> nil then
    Node.AppendChild(RHS);

  if CurrentToken(ALexer, ACursor).Kind = tkToKeyword then
    Direction := 'to'
  else if CurrentToken(ALexer, ACursor).Kind = tkDownToKeyword then
    Direction := 'downto'
  else
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'TO/DOWNTO');
    Node.Free;
    Exit(False);
  end;
  Inc(ACursor);

  RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
  if RHS <> nil then
    Node.AppendChild(RHS);
  Node.FText := Direction;

  if not MatchTokenSilent(ALexer, ACursor, tkDoKeyword) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'DO');
    Node.Free;
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
    Node.Free;
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
    Node.Free;
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
    Node.Free;
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
      SelectorNode.Free;
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
    Node.Free;
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
    Node.FNodeKind := gnkTryExceptStatement;
    Inc(ACursor);

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkOnKeyword) then
    begin
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkOnKeyword) do
      begin
        HandlerToken := CurrentToken(ALexer, ACursor);
        Inc(ACursor);
        HandlerNode := TGreenNode.Create(gnkExceptionHandler,
          HandlerToken.ByteOffset, 0, '');

        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
        begin
          HandlerNode.FText := CurrentToken(ALexer, ACursor).Lexeme;
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
    Node.Free;
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
          StmtNode := TGreenNode.Create(gnkGotoStatement, Token.ByteOffset, 0, '');
          List.AppendChild(StmtNode);
          Inc(ACursor);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind in
              [tkIdentifier, tkIntegerLiteral]) then
          begin
            StmtNode.FText := CurrentToken(ALexer, ACursor).Lexeme;
            Inc(ACursor);
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
        tkRequiresKeyword, tkOnKeyword, tkInlineKeyword, tkOverloadKeyword:
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
              RHS := ParseTypeReference(
                ALexer,
                ACursor,
                ADiagnostics,
                ARootFileId
              );
              RHS.Free;
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
      (CurrentToken(ALexer, ACursor).Kind in ATerminatorSet) then
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

function ParseProgramLikeRoot(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ATree: TGreenTree;
  const AParent: TGreenNode;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
begin
  SkipDirectives(ALexer, ACursor);
  Result := ParseUsesClause(
    ALexer,
    ACursor,
    ATree,
    uskInterface,
    AParent,
    ADiagnostics,
    ARootFileId
  );
  if not Result then
    Exit;

  Result := ParseBlockDeclarations(
    ALexer, ACursor, AParent, ATree, ADiagnostics, ARootFileId);

  Result := MatchToken(
    ALexer,
    ACursor,
    tkBeginKeyword,
    ADiagnostics,
    ARootFileId,
    'BEGIN'
  );
  if not Result then
    Exit;

  Result := ParseBeginBlock(ALexer, ACursor, AParent, ATree,
    ADiagnostics, ARootFileId);
end;

function ParseUnitRoot(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ATree: TGreenTree;
  const AParent: TGreenNode;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  InterfaceNode: TGreenNode;
  ImplementationNode: TGreenNode;
  LInitNode: TGreenNode;
  LFiniNode: TGreenNode;
begin
  Result := MatchToken(
    ALexer,
    ACursor,
    tkInterfaceKeyword,
    ADiagnostics,
    ARootFileId,
    'INTERFACE'
  );
  if not Result then
    Exit;

  InterfaceNode := TGreenNode.Create(
    gnkInterfaceSection,
    CurrentToken(ALexer, ACursor - 1).ByteOffset,
    0,
    ''
  );
  AParent.AppendChild(InterfaceNode);
  Inc(ATree.FNodeCount);

  Result := ParseUsesClause(
    ALexer,
    ACursor,
    ATree,
    uskInterface,
    InterfaceNode,
    ADiagnostics,
    ARootFileId
  );
  if not Result then
    Exit;

  Result := ParseBlockDeclarations(
    ALexer, ACursor, InterfaceNode, ATree, ADiagnostics, ARootFileId);

  Result := MatchToken(
    ALexer,
    ACursor,
    tkImplementationKeyword,
    ADiagnostics,
    ARootFileId,
    'IMPLEMENTATION'
  );
  if not Result then
    Exit;

  ImplementationNode := TGreenNode.Create(
    gnkImplementationSection,
    CurrentToken(ALexer, ACursor - 1).ByteOffset,
    0,
    ''
  );
  AParent.AppendChild(ImplementationNode);
  Inc(ATree.FNodeCount);

  Result := ParseUsesClause(
    ALexer,
    ACursor,
    ATree,
    uskImplementation,
    ImplementationNode,
    ADiagnostics,
    ARootFileId
  );
  if not Result then
    Exit;

  Result := ParseBlockDeclarations(
    ALexer, ACursor, ImplementationNode, ATree, ADiagnostics, ARootFileId);

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkInitializationKeyword) then
  begin
    LInitNode := TGreenNode.Create(
      gnkInitializationSection,
      CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
    Inc(ACursor);
    ParseStatementList(ALexer, ACursor, LInitNode,
      [tkFinalizationKeyword, tkEndKeyword, tkEOF],
      ATree, ADiagnostics, ARootFileId);
    ImplementationNode.AppendChild(LInitNode);
  end;

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkFinalizationKeyword) then
  begin
    LFiniNode := TGreenNode.Create(
      gnkFinalizationSection,
      CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
    Inc(ACursor);
    ParseStatementList(ALexer, ACursor, LFiniNode,
      [tkEndKeyword, tkEOF], ATree, ADiagnostics, ARootFileId);
    ImplementationNode.AppendChild(LFiniNode);
  end;

  Result := MatchToken(
    ALexer,
    ACursor,
    tkEndKeyword,
    ADiagnostics,
    ARootFileId,
    'END'
  );
  if not Result then
    Exit;

  AParent.AppendChild(TGreenNode.Create(
    gnkEndBlock,
    CurrentToken(ALexer, ACursor - 1).ByteOffset,
    0,
    ''
  ));
  Inc(ATree.FNodeCount);
end;

constructor TGreenTree.Create;
begin
  inherited Create;
  FRootKind := grkUnknown;
  FDeclaredName := '';
  FNodeCount := 0;
  FIsValid := False;
  FRootNode := nil;
  SetLength(FInterfaceUses, 0);
  SetLength(FImplementationUses, 0);
  SetLength(FForeignProcedureDecls, 0);
end;

destructor TGreenTree.Destroy;
begin
  FRootNode.Free;
  inherited Destroy;
end;

procedure TGreenTree.AppendInterfaceUse(const AUseName: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FInterfaceUses);
  SetLength(FInterfaceUses, NextIndex + 1);
  FInterfaceUses[NextIndex] := AUseName;
end;

procedure TGreenTree.AppendImplementationUse(const AUseName: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FImplementationUses);
  SetLength(FImplementationUses, NextIndex + 1);
  FImplementationUses[NextIndex] := AUseName;
end;

procedure TGreenTree.AppendForeignProcedureDecl(
  const AForeignProcedureDecl: TForeignProcedureDecl
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FForeignProcedureDecls);
  SetLength(FForeignProcedureDecls, NextIndex + 1);
  FForeignProcedureDecls[NextIndex] := AForeignProcedureDecl;
end;

function TGreenTree.RootKindName: string;
begin
  Result := RootKeywordLabel(FRootKind);
end;

function TGreenTree.InterfaceUseCount: LongInt;
begin
  Result := Length(FInterfaceUses);
end;

function TGreenTree.InterfaceUseAt(const AIndex: LongInt): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FInterfaceUses)) then
    Exit('');

  Result := FInterfaceUses[AIndex];
end;

function TGreenTree.ImplementationUseCount: LongInt;
begin
  Result := Length(FImplementationUses);
end;

function TGreenTree.ImplementationUseAt(const AIndex: LongInt): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FImplementationUses)) then
    Exit('');

  Result := FImplementationUses[AIndex];
end;

function TGreenTree.ForeignProcedureDeclCount: LongInt;
begin
  Result := Length(FForeignProcedureDecls);
end;

function TGreenTree.ForeignProcedureDeclAt(
  const AIndex: LongInt
): TForeignProcedureDecl;
begin
  if (AIndex < 0) or (AIndex >= Length(FForeignProcedureDecls)) then
  begin
    Result.ProcedureName := '';
    Result.CallingConvention := '';
    Result.LibraryId := '';
    Result.ExternalSymbolName := '';
    Result.HasExplicitSymbolName := False;
    Result.ByteOffset := 0;
    Exit;
  end;

  Result := FForeignProcedureDecls[AIndex];
end;

function TGreenTree.GreenNodeCount: LongInt;

  function CountNodes(const ANode: TGreenNode): LongInt;
  var
    Index: LongInt;
  begin
    if ANode = nil then
      Exit(0);
    Result := 1;
    for Index := 0 to ANode.ChildCount - 1 do
      Result := Result + CountNodes(ANode.ChildAt(Index));
  end;

begin
  Result := CountNodes(FRootNode);
end;

function ParseGreenTree(
  const ALexer: TLexerResult;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenTree;
var
  Cursor: LongInt;
  Current: TToken;
  RootNode: TGreenNode;
  DeclaredName: string;
  DeclaredNameOffset: LongInt;
  PreviousExpressionTree: TGreenTree;
begin
  Result := TGreenTree.Create;
  PreviousExpressionTree := ActiveExpressionTree;
  ActiveExpressionTree := Result;
  try
    Cursor := 0;
    SkipDirectives(ALexer, Cursor);
    Current := CurrentToken(ALexer, Cursor);

    Result.FRootKind := RootKindFromToken(Current.Kind);
    if Result.FRootKind = grkUnknown then
    begin
      EmitSyntaxError(
        ADiagnostics,
        ARootFileId,
        Current,
        'program|unit|library|package'
      );
      Exit;
    end;

    RootNode := TGreenNode.Create(
      GreenNodeKindFromRootKind(Result.FRootKind),
      Current.ByteOffset,
      Length(Current.Lexeme),
      Current.Lexeme
    );
    Result.FRootNode := RootNode;
    Result.FNodeCount := 1;
    AdvanceCursor(Cursor);

    if not ConsumeIdentifierPath(
      ALexer,
      Cursor,
      Result.FRootKind = grkUnit,
      DeclaredName,
      DeclaredNameOffset
    ) then
    begin
      EmitSyntaxError(
        ADiagnostics,
        ARootFileId,
        CurrentToken(ALexer, Cursor),
        'identifier'
      );
      Exit;
    end;

    Result.FDeclaredName := DeclaredName;
    RootNode.AppendChild(TGreenNode.Create(
      gnkIdentifier,
      DeclaredNameOffset,
      Length(DeclaredName),
      DeclaredName
    ));
    Inc(Result.FNodeCount);

    if not MatchToken(ALexer, Cursor, tkSemicolon, ADiagnostics, ARootFileId, ';') then
      Exit;
    Inc(Result.FNodeCount);

    case Result.FRootKind of
      grkProgram, grkLibrary, grkPackage:
        begin
          if not ParseProgramLikeRoot(
            ALexer,
            Cursor,
            Result,
            RootNode,
            ADiagnostics,
            ARootFileId
          ) then
            Exit;
        end;
      grkUnit:
        begin
          if not ParseUnitRoot(
            ALexer,
            Cursor,
            Result,
            RootNode,
            ADiagnostics,
            ARootFileId
          ) then
            Exit;
        end;
      grkUnknown:
        Exit;
    end;

    Result.FIsValid := not ADiagnostics.HasErrors;
  finally
    ActiveExpressionTree := PreviousExpressionTree;
  end;
end;

constructor TGreenNode.Create(
  const ANodeKind: TGreenNodeKind;
  const AByteOffset: LongInt;
  const AByteLength: LongInt;
  const AText: string
);
begin
  inherited Create;
  FNodeKind := ANodeKind;
  FByteOffset := AByteOffset;
  FByteLength := AByteLength;
  FText := AText;
  SetLength(FChildren, 0);
end;

destructor TGreenNode.Destroy;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FChildren) - 1 do
    FChildren[Index].Free;
  SetLength(FChildren, 0);
  inherited Destroy;
end;

procedure TGreenNode.AppendChild(const AChild: TGreenNode);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FChildren);
  SetLength(FChildren, NextIndex + 1);
  FChildren[NextIndex] := AChild;
end;

function TGreenNode.NodeKindName: string;
begin
  Result := GreenNodeKindLabel(FNodeKind);
end;

function TGreenNode.ChildCount: LongInt;
begin
  Result := Length(FChildren);
end;

function TGreenNode.ChildAt(const AIndex: LongInt): TGreenNode;
begin
  if (AIndex < 0) or (AIndex >= Length(FChildren)) then
    Exit(nil);
  Result := FChildren[AIndex];
end;

end.
