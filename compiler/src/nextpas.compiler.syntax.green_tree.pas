unit nextpas.compiler.syntax.green_tree;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$UNITPATH .}
{$UNITPATH ../diagnostics}
{$UNITPATH ../frontend}

interface

uses
  nextpas.compiler.syntax.green_tree.base,
  nextpas.compiler.syntax.green_tree.core,
  np_diagnostics_sink, nextpas.compiler.syntax.lexer, np_source_database,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

type
  { Base types — single source in nextpas.compiler.syntax.green_tree.base (four-piece base) }
  TForeignProcedureDecl = nextpas.compiler.syntax.green_tree.base.TForeignProcedureDecl;
  TGreenNodeKind = nextpas.compiler.syntax.green_tree.base.TGreenNodeKind;
  TGreenRootKind = nextpas.compiler.syntax.green_tree.base.TGreenRootKind;
  TGreenNodeData = nextpas.compiler.syntax.green_tree.base.TGreenNodeData;
  TGreenTreeData = nextpas.compiler.syntax.green_tree.base.TGreenTreeData;

const
  gnkUnknown = nextpas.compiler.syntax.green_tree.base.gnkUnknown;
  gnkProgram = nextpas.compiler.syntax.green_tree.base.gnkProgram;
  gnkUnit = nextpas.compiler.syntax.green_tree.base.gnkUnit;
  gnkLibrary = nextpas.compiler.syntax.green_tree.base.gnkLibrary;
  gnkPackage = nextpas.compiler.syntax.green_tree.base.gnkPackage;
  gnkUsesClause = nextpas.compiler.syntax.green_tree.base.gnkUsesClause;
  gnkUseEntry = nextpas.compiler.syntax.green_tree.base.gnkUseEntry;
  gnkInterfaceSection = nextpas.compiler.syntax.green_tree.base.gnkInterfaceSection;
  gnkImplementationSection = nextpas.compiler.syntax.green_tree.base.gnkImplementationSection;
  gnkInitializationSection = nextpas.compiler.syntax.green_tree.base.gnkInitializationSection;
  gnkFinalizationSection = nextpas.compiler.syntax.green_tree.base.gnkFinalizationSection;
  gnkForeignProcedureDecl = nextpas.compiler.syntax.green_tree.base.gnkForeignProcedureDecl;
  gnkBeginBlock = nextpas.compiler.syntax.green_tree.base.gnkBeginBlock;
  gnkAsmBlock = nextpas.compiler.syntax.green_tree.base.gnkAsmBlock;
  gnkEndBlock = nextpas.compiler.syntax.green_tree.base.gnkEndBlock;
  gnkStatementList = nextpas.compiler.syntax.green_tree.base.gnkStatementList;
  gnkIfStatement = nextpas.compiler.syntax.green_tree.base.gnkIfStatement;
  gnkWhileStatement = nextpas.compiler.syntax.green_tree.base.gnkWhileStatement;
  gnkForStatement = nextpas.compiler.syntax.green_tree.base.gnkForStatement;
  gnkForInStatement = nextpas.compiler.syntax.green_tree.base.gnkForInStatement;
  gnkRepeatStatement = nextpas.compiler.syntax.green_tree.base.gnkRepeatStatement;
  gnkWithStatement = nextpas.compiler.syntax.green_tree.base.gnkWithStatement;
  gnkCaseStatement = nextpas.compiler.syntax.green_tree.base.gnkCaseStatement;
  gnkCaseSelector = nextpas.compiler.syntax.green_tree.base.gnkCaseSelector;
  gnkCaseLabel = nextpas.compiler.syntax.green_tree.base.gnkCaseLabel;
  gnkAssignmentStatement = nextpas.compiler.syntax.green_tree.base.gnkAssignmentStatement;
  gnkProcedureCallStatement = nextpas.compiler.syntax.green_tree.base.gnkProcedureCallStatement;
  gnkGotoStatement = nextpas.compiler.syntax.green_tree.base.gnkGotoStatement;
  gnkBreakStatement = nextpas.compiler.syntax.green_tree.base.gnkBreakStatement;
  gnkContinueStatement = nextpas.compiler.syntax.green_tree.base.gnkContinueStatement;
  gnkExitStatement = nextpas.compiler.syntax.green_tree.base.gnkExitStatement;
  gnkTryExceptStatement = nextpas.compiler.syntax.green_tree.base.gnkTryExceptStatement;
  gnkTryFinallyStatement = nextpas.compiler.syntax.green_tree.base.gnkTryFinallyStatement;
  gnkExceptionHandler = nextpas.compiler.syntax.green_tree.base.gnkExceptionHandler;
  gnkRaiseStatement = nextpas.compiler.syntax.green_tree.base.gnkRaiseStatement;
  gnkVarSection = nextpas.compiler.syntax.green_tree.base.gnkVarSection;
  gnkThreadVarSection = nextpas.compiler.syntax.green_tree.base.gnkThreadVarSection;
  gnkConstSection = nextpas.compiler.syntax.green_tree.base.gnkConstSection;
  gnkTypeSection = nextpas.compiler.syntax.green_tree.base.gnkTypeSection;
  gnkLabelSection = nextpas.compiler.syntax.green_tree.base.gnkLabelSection;
  gnkVarDecl = nextpas.compiler.syntax.green_tree.base.gnkVarDecl;
  gnkConstDecl = nextpas.compiler.syntax.green_tree.base.gnkConstDecl;
  gnkTypeDecl = nextpas.compiler.syntax.green_tree.base.gnkTypeDecl;
  gnkProcedureDecl = nextpas.compiler.syntax.green_tree.base.gnkProcedureDecl;
  gnkFunctionDecl = nextpas.compiler.syntax.green_tree.base.gnkFunctionDecl;
  gnkRecordType = nextpas.compiler.syntax.green_tree.base.gnkRecordType;
  gnkArrayType = nextpas.compiler.syntax.green_tree.base.gnkArrayType;
  gnkClassType = nextpas.compiler.syntax.green_tree.base.gnkClassType;
  gnkEnumType = nextpas.compiler.syntax.green_tree.base.gnkEnumType;
  gnkClassField = nextpas.compiler.syntax.green_tree.base.gnkClassField;
  gnkClassMethod = nextpas.compiler.syntax.green_tree.base.gnkClassMethod;
  gnkClassProperty = nextpas.compiler.syntax.green_tree.base.gnkClassProperty;
  gnkVisibilityLabel = nextpas.compiler.syntax.green_tree.base.gnkVisibilityLabel;
  gnkTypeParamList = nextpas.compiler.syntax.green_tree.base.gnkTypeParamList;
  gnkIdentifier = nextpas.compiler.syntax.green_tree.base.gnkIdentifier;
  gnkStringLiteral = nextpas.compiler.syntax.green_tree.base.gnkStringLiteral;
  gnkIntegerLiteral = nextpas.compiler.syntax.green_tree.base.gnkIntegerLiteral;
  gnkRealLiteral = nextpas.compiler.syntax.green_tree.base.gnkRealLiteral;
  gnkCharLiteral = nextpas.compiler.syntax.green_tree.base.gnkCharLiteral;
  gnkBinaryExpression = nextpas.compiler.syntax.green_tree.base.gnkBinaryExpression;
  gnkUnaryExpression = nextpas.compiler.syntax.green_tree.base.gnkUnaryExpression;
  gnkDotAccess = nextpas.compiler.syntax.green_tree.base.gnkDotAccess;
  gnkArrayAccess = nextpas.compiler.syntax.green_tree.base.gnkArrayAccess;
  gnkFunctionCall = nextpas.compiler.syntax.green_tree.base.gnkFunctionCall;
  gnkDereference = nextpas.compiler.syntax.green_tree.base.gnkDereference;
  gnkAddressOf = nextpas.compiler.syntax.green_tree.base.gnkAddressOf;
  gnkSetConstructor = nextpas.compiler.syntax.green_tree.base.gnkSetConstructor;
  gnkRangeExpression = nextpas.compiler.syntax.green_tree.base.gnkRangeExpression;
  gnkParameterList = nextpas.compiler.syntax.green_tree.base.gnkParameterList;
  gnkParameterDecl = nextpas.compiler.syntax.green_tree.base.gnkParameterDecl;
  gnkFieldList = nextpas.compiler.syntax.green_tree.base.gnkFieldList;
  gnkError = nextpas.compiler.syntax.green_tree.base.gnkError;
  grkUnknown = nextpas.compiler.syntax.green_tree.base.grkUnknown;
  grkProgram = nextpas.compiler.syntax.green_tree.base.grkProgram;
  grkUnit = nextpas.compiler.syntax.green_tree.base.grkUnit;
  grkLibrary = nextpas.compiler.syntax.green_tree.base.grkLibrary;
  grkPackage = nextpas.compiler.syntax.green_tree.base.grkPackage;

type
  { Storage — single source in nextpas.compiler.syntax.green_tree.core (four-piece core) }
  TGreenNode = nextpas.compiler.syntax.green_tree.core.TGreenNode;
  TGreenStringVec = nextpas.compiler.syntax.green_tree.core.TGreenStringVec;
  TGreenForeignProcVec = nextpas.compiler.syntax.green_tree.core.TGreenForeignProcVec;
  TGreenTree = nextpas.compiler.syntax.green_tree.core.TGreenTree;

function ParseGreenTree(
  const ALexer: TLexerResult;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenTree; overload;

{** Parse with IAllocator-backed node vectors (session AST arena product path). }
function ParseGreenTree(
  const ALexer: TLexerResult;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const AAllocator: IAllocator
): TGreenTree; overload;

function GreenNodeKindLabel(const AKind: TGreenNodeKind): string;
function GreenNodeIsNil(const ANode: TGreenNode): Boolean;
function NilGreenNode: TGreenNode; inline;

implementation

uses
  nextpas.core.text.conv;

type
  TUseSectionKind = (
    uskInterface,
    uskImplementation
  );

  TTokenKindSet = set of TTokenKind;

{ ActiveExpressionTree now in nextpas.compiler.syntax.green_tree.core }

{ Parent terminator stack for nested statement parsing.
  When parsing if..then followed by while..do body, the body's
  statement list must also stop at ELSE (which belongs to the if). }
var
  GParentTerminators: TTokenKindSet = [];

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
  const ARootFileId: TSourceFileId;
  ANodeKind: TGreenNodeKind = gnkVarSection
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
): TGreenNode; overload; forward;

function ParseTypeReference(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const ATree: TGreenTree
): TGreenNode; overload; forward;

function ParseAnonymousRoutineExpression(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode; overload; forward;

function ParseAnonymousRoutineExpression(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const ATree: TGreenTree
): TGreenNode; overload; forward;


{--- inlined np_green_tree_parser_impl.inc ---}
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
    gnkAsmBlock: Result := 'asm-block';
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
    gnkThreadVarSection: Result := 'threadvar-section';
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
  Result := ANode.IsNil;
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
  { Soft keywords that are also legal as method/procedure names (FPC allows
    e.g. procedure TFoo.Register). Missing tkRegisterKeyword caused
    TAllocStatsCollector.Register to break name parse; the bare begin was then
    misread as unit initialization-section (body leak into np_unit_init_*). }
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
    (AKind = tkPlatformKeyword) or (AKind = tkExperimentalKeyword) or
    (AKind = tkForwardKeyword) or
    (AKind = tkRegisterKeyword) or (AKind = tkStdCallKeyword) or
    (AKind = tkCdeclKeyword) or (AKind = tkSafeCallKeyword) or
    (AKind = tkPascalKeyword) or (AKind = tkFarKeyword) or
    (AKind = tkNearKeyword) or (AKind = tkCppDeclKeyword) or
    (AKind = tkVarArgsKeyword);
end;

function IsOperatorNameToken(AKind: TTokenKind): Boolean;
begin
  { Include tkAssign (:=) — advanced-record class operators like
    TGreenNode.:= were rejected, leaving the cursor on := and desyncing
    ParseBlockDeclarations so later TGreenNode.Create/GetText vanished. }
  Result := AKind in [tkPlus, tkMinus, tkStar, tkSlash, tkEquals, tkAssign,
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
    tkStdCallKeyword, tkSafeCallKeyword, tkRegisterKeyword, tkPascalKeyword,
    tkFarKeyword, tkNearKeyword, tkCppDeclKeyword, tkVarArgsKeyword,
    tkVirtualKeyword, tkOverrideKeyword, tkAbstractKeyword, tkStaticKeyword,
    tkDynamicKeyword, tkReintroduceKeyword, tkMessageKeyword,
    tkDeprecatedKeyword, tkPlatformKeyword, tkExperimentalKeyword];
end;

{ Soft keywords legal as local/parameter names (FPC allows `var Forward: T`).
  Missing tkForwardKeyword left `var Forward` unparsed inside LookAt; the bare
  begin was then taken as unit initialization-section. }
function IsVarNameToken(AKind: TTokenKind): Boolean;
begin
  Result := IsMethodNameToken(AKind);
end;

procedure SkipDirectives(const ALexer: TLexerResult; var ACursor: LongInt);
begin
  while (ACursor < ALexer.TokenCount) and
    (ALexer.TokenAt(ACursor).Kind = tkCompilerDirective) do
    Inc(ACursor);
end;

function ParseCompilerDirective(const ALexeme: string;
  out ADirective: string): Boolean;
var
  Content: string;
begin
  Result := False;
  ADirective := '';
  if Length(ALexeme) < 3 then Exit;
  if (ALexeme[1] = '{') and (ALexeme[2] = '$') then
  begin
    Content := Copy(ALexeme, 3, Length(ALexeme) - 3);
    if (Content <> '') and (Content[Length(Content)] = '}') then
      SetLength(Content, Length(Content) - 1);
  end
  else if (Length(ALexeme) >= 4) and (ALexeme[1] = '(') and
    (ALexeme[2] = '*') and (ALexeme[3] = '$') then
    Content := Copy(ALexeme, 4, Length(ALexeme) - 5)
  else
    Exit;
  Content := Trim(Content);
  if Content = '' then Exit;
  ADirective := LowerCase(Content);
  Result := True;
end;

function CheckCompilerRootDirective(const ALexer: TLexerResult;
  var ACursor: LongInt): Boolean;
var
  Dir: string;
  SavedCursor: LongInt;
begin
  Result := False;
  SavedCursor := ACursor;
  while (ACursor < ALexer.TokenCount) and
    (ALexer.TokenAt(ACursor).Kind = tkCompilerDirective) do
  begin
    if ParseCompilerDirective(ALexer.TokenAt(ACursor).Lexeme, Dir) and
      (Dir = 'compiler_root') then
    begin
      Inc(ACursor);
      Result := True;
      Exit;
    end;
    Inc(ACursor);
  end;
  ACursor := SavedCursor;
end;

function CheckCompilerTypeKindDirective(const ALexer: TLexerResult;
  var ACursor: LongInt): Boolean;
var
  Dir: string;
  SavedCursor: LongInt;
begin
  Result := False;
  SavedCursor := ACursor;
  while (ACursor < ALexer.TokenCount) and
    (ALexer.TokenAt(ACursor).Kind = tkCompilerDirective) do
  begin
    if ParseCompilerDirective(ALexer.TokenAt(ACursor).Lexeme, Dir) and
      (Dir = 'compiler_type_kind') then
    begin
      Inc(ACursor);
      Result := True;
      Exit;
    end;
    Inc(ACursor);
  end;
  ACursor := SavedCursor;
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

{ Consume one routine directive after the signature semicolon, including optional
  message payload: deprecated 'msg' | platform 'msg' | experimental 'msg' |
  message 'msg'|N. Leaving the string uneaten desyncs the cursor so the next
  begin becomes a fake gnkInitializationSection (L3 residual @AData/@APathBuf). }
procedure ConsumeRoutineDirectiveToken(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  var AFullName: string
);
begin
  if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
    SameText(CurrentToken(ALexer, ACursor).Lexeme, 'compilerproc') then
    AFullName := AFullName + ';compilerproc';
  Inc(ACursor);
  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind in
      [tkStringLiteral, tkIntegerLiteral]) then
    Inc(ACursor);
  MatchTokenSilent(ALexer, ACursor, tkSemicolon);
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
    SkipDirectives(ALexer, ACursor);

    { FPC leniency: allow trailing comma before semicolon in uses clause.
      This happens when conditional compilation strips platform-specific units:
        uses Foo, {$IFDEF WINDOWS} Bar {$ENDIF} ;
      After preprocessing: uses Foo, ;  (dangling comma) }
    if (ACursor < ALexer.TokenCount) and
       (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) then
      Break;

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
      { { UsesNode.Free; } // record, no Free needed } // owned by tree FFacades
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

  if not MatchTokenSilent(
    ALexer,
    ACursor,
    tkSemicolon
  ) then
  begin
    { FPC leniency: allow uses clause without trailing semicolon
      when followed by a section-starting keyword like type/const/var/begin.
      e.g. "uses Foo\n type" is accepted by FPC. }
    SkipDirectives(ALexer, ACursor);
    if (ACursor < ALexer.TokenCount) and
       (CurrentToken(ALexer, ACursor).Kind in [
         tkTypeKeyword, tkConstKeyword, tkVarKeyword,
         tkBeginKeyword, tkProcedureKeyword, tkFunctionKeyword,
         tkClassKeyword, tkInterfaceKeyword
       ]) then
    begin
      { Recover: treat as valid uses clause without semicolon }
    end
    else
    begin
      EmitSyntaxError(
        ADiagnostics,
        ARootFileId,
        CurrentToken(ALexer, ACursor),
        ';'
      );
      { { UsesNode.Free; } // record, no Free needed } // owned by tree FFacades
      Exit(False);
    end;
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


{--- inlined np_green_tree_parse_expressions.inc ---}
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

{--- end np_green_tree_parse_expressions.inc ---}


{--- inlined np_green_tree_parse_declarations.inc ---}
function ParseAnonymousRoutineExpression(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const ATree: TGreenTree
): TGreenNode; overload;
var
  Node: TGreenNode;
  RoutineKind: TTokenKind;
  TypeNode: TGreenNode;
  function NewNode(const AKind: TGreenNodeKind; const AOff: LongInt; const ALen: LongInt; const ATxt: string): TGreenNode; inline;
  begin
    if ATree <> nil then
      NewNode := TGreenNode.Create(ATree, AKind, AOff, ALen, ATxt)
    else
      NewNode := TGreenNode.Create(AKind, AOff, ALen, ATxt);
  end;
begin
  Result := nil;
  if ATree = nil then
    Exit;

  RoutineKind := CurrentToken(ALexer, ACursor).Kind;
  case RoutineKind of
    tkFunctionKeyword:
      Node := NewNode(gnkFunctionDecl,
        CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
    tkProcedureKeyword:
      Node := NewNode(gnkProcedureDecl,
        CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  else
    Exit;
  end;

  Inc(ACursor);
  ParseParameterList(ALexer, ACursor, Node, ATree,
    ADiagnostics, ARootFileId);

  if RoutineKind = tkFunctionKeyword then
  begin
    if not MatchTokenSilent(ALexer, ACursor, tkColon) then
    begin
      EmitSyntaxError(ADiagnostics, ARootFileId,
        CurrentToken(ALexer, ACursor), ':');
      { Node.Free } // owned by tree FFacades
      Exit(nil);
    end;

    TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
    if TypeNode <> nil then
    begin
      Node.AppendChild(TypeNode);
      Inc(ATree.FNodeCount);
    end;
  end;

  while (ACursor < ALexer.TokenCount) and
    (IsDirectiveToken(CurrentToken(ALexer, ACursor).Kind) or
     ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
      IsCallingDirective(CurrentToken(ALexer, ACursor).Lexeme))) do
    Inc(ACursor);

  { Parse optional var/const/type declarations before begin }
  ParseBlockDeclarations(ALexer, ACursor, Node, ATree,
    ADiagnostics, ARootFileId);

  if not MatchTokenSilent(ALexer, ACursor, tkBeginKeyword) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'BEGIN');
    { Node.Free } // owned by tree FFacades
    Exit(nil);
  end;

  if not ParseBeginBlock(ALexer, ACursor, Node, ATree,
    ADiagnostics, ARootFileId) then
  begin
    { Node.Free } // owned by tree FFacades
    Exit(nil);
  end;

  Result := Node;
end;

function ParseAnonymousRoutineExpression(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenNode; overload;
begin
  Result := ParseAnonymousRoutineExpression(ALexer, ACursor, ADiagnostics, ARootFileId, ActiveExpressionTree);
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
      [tkVarKeyword, tkConstKeyword, tkConstRefKeyword, tkOutKeyword] then
    begin
      if CurrentToken(ALexer, ACursor).Kind = tkVarKeyword then
        ParamModifier := 'var:'
      else if CurrentToken(ALexer, ACursor).Kind = tkOutKeyword then
        ParamModifier := 'out:'
      else if CurrentToken(ALexer, ACursor).Kind = tkConstRefKeyword then
        ParamModifier := 'constref:';
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
      TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
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
  const ARootFileId: TSourceFileId;
  ANodeKind: TGreenNodeKind
): Boolean;
var
  Section: TGreenNode;
  Decl: TGreenNode;
  NameToken: TToken;
  TypeNode: TGreenNode;
  I: LongInt;
  Child: TGreenNode;
begin
  Section := TGreenNode.Create(ANodeKind,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  AParent.AppendChild(Section);
  Inc(ATree.FNodeCount);
  Inc(ACursor);

  while (ACursor < ALexer.TokenCount) and
    IsVarNameToken(CurrentToken(ALexer, ACursor).Kind) do
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
      if IsVarNameToken(CurrentToken(ALexer, ACursor).Kind) then
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
      TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
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

function ConstDeclHasArrayType(const ADecl: TGreenNode): Boolean;
var
  I: LongInt;
  Child: TGreenNode;
begin
  { Typed const `Name: array[...] of T = (...)` keeps the array type child.
    Only those paren lists are aggregate initializers; bare `(expr)` / `(a-b) div c`
    must go through ParseExpression or ProcessConstSection never seeds the value. }
  Result := False;
  if ADecl = nil then
    Exit;
  for I := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkArrayType) then
      Exit(True);
  end;
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
      ValueExpr := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
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
      { Aggregate skip only for typed array consts. Untyped/scalar
        `= (BAND0_MAX - BAND0_MIN) div STEP + 1` used to hit this branch,
        drop the value AST, and residual-call @BAND0_COUNT(). }
      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkLParen) and
        ConstDeclHasArrayType(Decl) then
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
  Nesting: LongInt;
  MethodModifiers: string;
  IsCompilerRoot: Boolean;
  IsCompilerTypeKind: Boolean;


{--- end np_green_tree_parse_declarations.inc ---}


{--- inlined np_green_tree_clone_type.inc ---}
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
  Section := TGreenNode.Create(ATree, gnkTypeSection,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  AParent.AppendChild(Section);
  Inc(ATree.FNodeCount);
  Inc(ACursor);

  while True do
  begin
    { Check for {$compiler_root} or {$compiler_type_kind} directive }
    IsCompilerRoot := CheckCompilerRootDirective(ALexer, ACursor);
    IsCompilerTypeKind := CheckCompilerTypeKindDirective(ALexer, ACursor);
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
    { Store directive info in node text }
    if IsCompilerRoot then
      Decl := TGreenNode.Create(ATree, gnkTypeDecl, NameToken.ByteOffset, 0,
        'compiler_root:' + NameToken.Lexeme)
    else if IsCompilerTypeKind then
      Decl := TGreenNode.Create(ATree, gnkTypeDecl, NameToken.ByteOffset, 0,
        'compiler_type_kind:' + NameToken.Lexeme)
    else
      Decl := TGreenNode.Create(ATree, gnkTypeDecl, NameToken.ByteOffset, 0,
        NameToken.Lexeme);
    Section.AppendChild(Decl);
    Inc(ATree.FNodeCount);
    Inc(ACursor);

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkLessThan) then
    begin
      TypeParamNode := TGreenNode.Create(ATree, gnkTypeParamList,
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
          ElementNode := TGreenNode.Create(ATree, gnkIdentifier,
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
            TypeNode := TGreenNode.Create(ATree, gnkRecordType,
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
                IndexNode := TGreenNode.Create(ATree, gnkVarDecl,
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
                    IndexNode := TGreenNode.Create(ATree, gnkVarDecl,
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
                    ADiagnostics, ARootFileId, ATree);
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
                ElementNode := TGreenNode.Create(ATree, gnkVisibilityLabel,
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
              else if CurrentToken(ALexer, ACursor).Kind = tkPropertyKeyword then
              begin
                { Record properties were token-skipped here, so sema never saw
                  the declared read/write targets — `S := Rec.Prop` residual-
                  called @Type.Prop (M2 B3b). Emit the same gnkClassProperty
                  shape the class branch below produces. }
                Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                begin
                  ElementNode := TGreenNode.Create(ATree, gnkClassProperty,
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
                      ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) or
                       (CurrentToken(ALexer, ACursor).Kind = tkStringKeyword)) then
                    begin
                      IndexNode := TGreenNode.Create(ATree, gnkIdentifier,
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
                        IndexNode := TGreenNode.Create(ATree, gnkIdentifier,
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
                        IndexNode := TGreenNode.Create(ATree, gnkIdentifier,
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
              else if CurrentToken(ALexer, ACursor).Kind in
                [tkClassKeyword, tkProcedureKeyword, tkFunctionKeyword,
                 tkConstructorKeyword, tkDestructorKeyword, tkOperatorKeyword,
                 tkStaticKeyword, tkGenericKeyword] then
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
                MethodModifiers := '';
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
              else if CurrentToken(ALexer, ACursor).Kind = tkTypeKeyword then
              begin
                { skip nested type section in record: may contain multiple decls }
                Inc(ACursor);
                Nesting := 0;
                while (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                begin
                  if (Nesting = 0) and
                    (CurrentToken(ALexer, ACursor).Kind in
                      [tkPublicKeyword, tkPrivateKeyword, tkProtectedKeyword,
                       tkPublishedKeyword, tkEndKeyword]) then
                    Break;
                  if (CurrentToken(ALexer, ACursor).Kind in
                    [tkRecordKeyword, tkObjectKeyword,
                     tkClassKeyword, tkInterfaceKeyword]) and
                    ((ACursor <= 0) or
                     (ALexer.TokenAt(ACursor - 1).Kind <> tkOfKeyword)) then
                  begin
                    if (CurrentToken(ALexer, ACursor).Kind = tkClassKeyword) and
                      (ACursor + 1 < ALexer.TokenCount) and
                      (ALexer.TokenAt(ACursor + 1).Kind in
                        [tkFunctionKeyword, tkProcedureKeyword,
                         tkConstructorKeyword, tkDestructorKeyword,
                         tkOperatorKeyword]) then
                      { class as method modifier, not type declaration }
                    else
                      Inc(Nesting);
                  end
                  else if (CurrentToken(ALexer, ACursor).Kind = tkEndKeyword) and
                    (Nesting > 0) then
                    Dec(Nesting);
                  Inc(ACursor);
                end;
              end
              else
                Inc(ACursor);
            end;
            MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
          end;
        tkArrayKeyword:
          begin
            TypeNode := TGreenNode.Create(ATree, gnkArrayType,
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
                ElementNode := TGreenNode.Create(ATree, gnkIdentifier,
                  CurrentToken(ALexer, ACursor).ByteOffset,
                  Length(CurrentToken(ALexer, ACursor).Lexeme),
                  CurrentToken(ALexer, ACursor).Lexeme);
                Inc(ACursor);
              end
              else
                ElementNode := ParseTypeReference(ALexer, ACursor, ADiagnostics,
                  ARootFileId, ATree);
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
              { { RangeNode.Free; } // record, no Free needed } // owned by tree FFacades
          end;
        tkClassKeyword:
          begin
            TypeNode := TGreenNode.Create(ATree, gnkClassType,
              CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
            Decl.AppendChild(TypeNode);
            Inc(ATree.FNodeCount);
            Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
            begin
              Inc(ACursor);
              ElementNode := ParseTypeReference(ALexer, ACursor, ADiagnostics,
                ARootFileId, ATree);
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
                  ARootFileId, ATree);
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
              { Mark class-of so sema can distinguish from empty
                `ClassName = class(Parent);` (also ChildCount=1). }
              TypeNode.Text := 'of';
              Inc(ACursor);
              ElementNode := ParseTypeReference(ALexer, ACursor, ADiagnostics,
                ARootFileId, ATree);
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
              if (CurrentToken(ALexer, ACursor).Kind in
                [tkRecordKeyword, tkObjectKeyword]) and
                ((ACursor <= 0) or
                 (ALexer.TokenAt(ACursor - 1).Kind <> tkOfKeyword)) then
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
                ElementNode := TGreenNode.Create(ATree, gnkVisibilityLabel,
                  CurrentToken(ALexer, ACursor).ByteOffset, 0,
                  CurrentToken(ALexer, ACursor).Lexeme);
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
                Inc(ACursor);
              end
              else if CurrentToken(ALexer, ACursor).Kind = tkTypeKeyword then
              begin
                { skip nested type section: may contain multiple decls }
                Inc(ACursor);
                Nesting := 0;
                while (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
                begin
                  if (Nesting = 0) and
                    (CurrentToken(ALexer, ACursor).Kind in
                      [tkPublicKeyword, tkPrivateKeyword, tkProtectedKeyword,
                       tkPublishedKeyword, tkEndKeyword]) then
                    Break;
                  if (CurrentToken(ALexer, ACursor).Kind in
                    [tkRecordKeyword, tkObjectKeyword,
                     tkClassKeyword, tkInterfaceKeyword]) and
                    ((ACursor <= 0) or
                     (ALexer.TokenAt(ACursor - 1).Kind <> tkOfKeyword)) then
                  begin
                    if (CurrentToken(ALexer, ACursor).Kind = tkClassKeyword) and
                      (ACursor + 1 < ALexer.TokenCount) and
                      (ALexer.TokenAt(ACursor + 1).Kind in
                        [tkFunctionKeyword, tkProcedureKeyword,
                         tkConstructorKeyword, tkDestructorKeyword,
                         tkOperatorKeyword]) then
                      { class as method modifier, not type declaration }
                    else
                      Inc(Nesting);
                  end
                  else if (CurrentToken(ALexer, ACursor).Kind = tkEndKeyword) and
                    (Nesting > 0) then
                    Dec(Nesting);
                  Inc(ACursor);
                end;
              end
              else if CurrentToken(ALexer, ACursor).Kind in
                [tkProcedureKeyword, tkFunctionKeyword,
                 tkConstructorKeyword, tkDestructorKeyword,
                 tkGenericKeyword, tkClassKeyword] then
              begin
                MethodModifiers := TokenKindName(CurrentToken(ALexer, ACursor).Kind);
                ElementNode := TGreenNode.Create(ATree, gnkClassMethod,
                  CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
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
                  ElementNode.AppendChild(TGreenNode.Create(ATree, gnkIdentifier,
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
                    ElementNode.AppendChild(TGreenNode.Create(ATree, gnkIdentifier,
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
                    MethodModifiers := MethodModifiers + ';virtual'
                  else if CurrentToken(ALexer, ACursor).Kind = tkOverrideKeyword then
                    MethodModifiers := MethodModifiers + ';override'
                  else if CurrentToken(ALexer, ACursor).Kind = tkAbstractKeyword then
                    MethodModifiers := MethodModifiers + ';virtual;abstract';
                  Inc(ACursor);
                  MatchTokenSilent(ALexer, ACursor, tkSemicolon);
                end;
                ElementNode.Text := MethodModifiers;
                TypeNode.AppendChild(ElementNode);
                Inc(ATree.FNodeCount);
              end
              else if CurrentToken(ALexer, ACursor).Kind = tkPropertyKeyword then
              begin
                Inc(ACursor);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                begin
                  ElementNode := TGreenNode.Create(ATree, gnkClassProperty,
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
                      IndexNode := TGreenNode.Create(ATree, gnkIdentifier,
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
                        IndexNode := TGreenNode.Create(ATree, gnkIdentifier,
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
                        IndexNode := TGreenNode.Create(ATree, gnkIdentifier,
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
                  ElementNode := TGreenNode.Create(ATree, gnkIdentifier,
                    CurrentToken(ALexer, ACursor - 1).ByteOffset, 0,
                    'where:' + SpecArgs);
                  TypeNode.AppendChild(ElementNode);
                  Inc(ATree.FNodeCount);
                end;
                MatchTokenSilent(ALexer, ACursor, tkSemicolon);
              end
              else if CurrentToken(ALexer, ACursor).Kind = tkIdentifier then
              begin
                ElementNode := TGreenNode.Create(ATree, gnkClassField,
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
                      ElementNode := TGreenNode.Create(ATree, gnkClassField,
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
                      ADiagnostics, ARootFileId, ATree);
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
                    ADiagnostics, ARootFileId, ATree);
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
                    if (CurrentToken(ALexer, ACursor).Kind in
                      [tkRecordKeyword, tkObjectKeyword]) and
                      ((ACursor <= 0) or
                       (ALexer.TokenAt(ACursor - 1).Kind <> tkOfKeyword)) then
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
            TypeNode := TGreenNode.Create(ATree, gnkClassType,
              CurrentToken(ALexer, ACursor).ByteOffset, 0, 'interface');
            Decl.AppendChild(TypeNode);
            Inc(ATree.FNodeCount);
            Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkLParen) then
            begin
              Inc(ACursor);
              ElementNode := ParseTypeReference(ALexer, ACursor, ADiagnostics,
                ARootFileId, ATree);
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
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkSemicolon) then
            begin
              { Forward interface declaration: interface; — semicolon consumed by ParseTypeSection }
            end
            else
            begin
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
                (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
                (CurrentToken(ALexer, ACursor).Kind <> tkBeginKeyword) and
                (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
              begin
                if CurrentToken(ALexer, ACursor).Kind in
                  [tkProcedureKeyword, tkFunctionKeyword] then
                begin
                  ElementNode := TGreenNode.Create(ATree, gnkClassMethod,
                    CurrentToken(ALexer, ACursor).ByteOffset, 0,
                    TokenKindName(CurrentToken(ALexer, ACursor).Kind));
                  Inc(ACursor);
                  if (ACursor < ALexer.TokenCount) and
                    (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
                  begin
                    ElementNode.AppendChild(TGreenNode.Create(ATree, gnkIdentifier,
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
                      ElementNode.AppendChild(TGreenNode.Create(ATree, gnkIdentifier,
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
                    ElementNode := TGreenNode.Create(ATree, gnkClassProperty,
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
                        IndexNode := TGreenNode.Create(ATree, gnkIdentifier,
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
                          IndexNode := TGreenNode.Create(ATree, gnkIdentifier,
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
                          IndexNode := TGreenNode.Create(ATree, gnkIdentifier,
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
          end;
        tkLParen:
          begin
            TypeNode := TGreenNode.Create(ATree, gnkEnumType,
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
                TypeNode.AppendChild(TGreenNode.Create(ATree, gnkIdentifier,
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
            TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
            if TypeNode <> nil then
            begin
              Decl.AppendChild(TypeNode);
              Inc(ATree.FNodeCount);
            end;
          end;
        tkCaret:
          begin
            Inc(ACursor);
            { Keep '^Pointee' text — same contract as ParseTypeReference.
              Dropping the caret made `PFoo = ^TFoo` look like a value alias of
              TFoo (often a record), so locals/returns became recvar/sret. }
            TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
            if TypeNode <> nil then
            begin
              if (Length(TypeNode.Text) = 0) or (TypeNode.Text[1] <> '^') then
              begin
                ElementNode := TypeNode;
                TypeNode := TGreenNode.Create(ElementNode.NodeKind,
                  ElementNode.ByteOffset, Length('^' + ElementNode.Text),
                  '^' + ElementNode.Text);
                Inc(ATree.FNodeCount);
              end;
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
                ARootFileId, ATree
              );
              { { TypeNode.Free; } // record, no Free needed } // owned by tree FFacades
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
              TypeNode := TGreenNode.Create(ATree, gnkRecordType,
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
        TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
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
        (CurrentToken(ALexer, ACursor).Kind <> tkBeginKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    end;
    { Consume calling conventions after procedure type semicolons:
      e.g. "procedure; cdecl;" — after the first ; is consumed, check for cdecl }
    while (ACursor < ALexer.TokenCount) and
      (IsDirectiveToken(CurrentToken(ALexer, ACursor).Kind) or
       ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
        IsCallingDirective(CurrentToken(ALexer, ACursor).Lexeme))) do
    begin
      Inc(ACursor);
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    end;
  end;

  Result := True;
end;


{--- end np_green_tree_clone_type.inc ---}


{--- inlined np_green_tree_parse_routines.inc ---}
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
  AsmNode: TGreenNode;
  NameToken: TToken;
  I: LongInt;
  J: LongInt;
  TypeParamText: string;
  FullName: string;
begin
  Node := TGreenNode.Create(gnkProcedureDecl,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  Inc(ACursor);

  if (ACursor >= ALexer.TokenCount) or
    not IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
  begin
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;

  NameToken := CurrentToken(ALexer, ACursor);
  FullName := NameToken.Lexeme;
  Inc(ACursor);

  if (ACursor < ALexer.TokenCount) and
    (NameToken.Kind = tkStar) and
    (CurrentToken(ALexer, ACursor).Kind = tkStar) then
  begin
    FullName := '**';
    Inc(ACursor);
  end;

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkDot) do
  begin
    Inc(ACursor);
    if (ACursor < ALexer.TokenCount) and
      IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
    begin
      FullName := FullName + '.' + CurrentToken(ALexer, ACursor).Lexeme;
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
      FullName := FullName + '<' + TypeParamText + '>';
  end;

  ParseParameterList(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId);

  MatchTokenSilent(ALexer, ACursor, tkSemicolon);

  while (ACursor < ALexer.TokenCount) and
    (IsDirectiveToken(CurrentToken(ALexer, ACursor).Kind) or
     ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
      IsCallingDirective(CurrentToken(ALexer, ACursor).Lexeme))) do
    ConsumeRoutineDirectiveToken(ALexer, ACursor, FullName);

  { external 'lib' name 'sym' — mark node and skip body }
  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkExternalKeyword) then
  begin
    Inc(ACursor);
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkStringLiteral) then
    begin
      FullName := FullName + ';external:' +
        DecodePascalStringLiteral(CurrentToken(ALexer, ACursor).Lexeme);
      Inc(ACursor);
      if (ACursor < ALexer.TokenCount) and
        ((CurrentToken(ALexer, ACursor).Kind = tkNameKeyword) or
         ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
          SameText(CurrentToken(ALexer, ACursor).Lexeme, 'name'))) then
      begin
        Inc(ACursor);
        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkStringLiteral) then
        begin
          FullName := FullName + ':' +
            DecodePascalStringLiteral(CurrentToken(ALexer, ACursor).Lexeme);
          Inc(ACursor);
        end;
      end;
    end;
    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    Node.Text := FullName;
    AParent.AppendChild(Node);
    Inc(ATree.FNodeCount);
    Result := True;
    Exit;
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
      else if CurrentToken(ALexer, ACursor).Kind = tkConstKeyword then
        { Local const (BUF_SIZE = 1024) must stay in AST — skip loses values. }
        ParseConstSection(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else if CurrentToken(ALexer, ACursor).Kind = tkTypeKeyword then
        ParseTypeSection(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else
      begin
        { label / unknown: skip section until next local-decl keyword or body. }
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
      AsmNode := TGreenNode.Create(gnkAsmBlock,
        CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
      Inc(ACursor);
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
      MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
      { FPC asm clobber list: end ['eax', 'ebx', ...] }
      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkLBracket) then
      begin
        Inc(ACursor);
        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind <> tkRBracket) and
          (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
          Inc(ACursor);
        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkRBracket) then
          Inc(ACursor);
      end;
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
      Node.AppendChild(AsmNode);
      Inc(ATree.FNodeCount);
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

  Node.Text := FullName;
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
  AsmNode: TGreenNode;
  NameToken: TToken;
  TypeNode: TGreenNode;
  I: LongInt;
  J: LongInt;
  TypeParamText: string;
  FullName: string;
begin
  Node := TGreenNode.Create(gnkFunctionDecl,
    CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
  Inc(ACursor);

  SkipDirectives(ALexer, ACursor);
  if (ACursor >= ALexer.TokenCount) or
    not IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
  begin
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;

  NameToken := CurrentToken(ALexer, ACursor);
  FullName := NameToken.Lexeme;
  Inc(ACursor);

  if (ACursor < ALexer.TokenCount) and
    (NameToken.Kind = tkStar) and
    (CurrentToken(ALexer, ACursor).Kind = tkStar) then
  begin
    FullName := '**';
    Inc(ACursor);
  end;

  while (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkDot) do
  begin
    Inc(ACursor);
    if (ACursor < ALexer.TokenCount) and
      IsDeclNameToken(CurrentToken(ALexer, ACursor).Kind) then
    begin
      FullName := FullName + '.' + CurrentToken(ALexer, ACursor).Lexeme;
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
      FullName := FullName + '<' + TypeParamText + '>';
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
    TypeNode := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
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
    ConsumeRoutineDirectiveToken(ALexer, ACursor, FullName);

  { external 'lib' name 'sym' — mark node and skip body }
  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkExternalKeyword) then
  begin
    Inc(ACursor);
    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkStringLiteral) then
    begin
      FullName := FullName + ';external:' +
        DecodePascalStringLiteral(CurrentToken(ALexer, ACursor).Lexeme);
      Inc(ACursor);
      if (ACursor < ALexer.TokenCount) and
        ((CurrentToken(ALexer, ACursor).Kind = tkNameKeyword) or
         ((CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
          SameText(CurrentToken(ALexer, ACursor).Lexeme, 'name'))) then
      begin
        Inc(ACursor);
        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkStringLiteral) then
        begin
          FullName := FullName + ':' +
            DecodePascalStringLiteral(CurrentToken(ALexer, ACursor).Lexeme);
          Inc(ACursor);
        end;
      end;
    end;
    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
    Node.Text := FullName;
    AParent.AppendChild(Node);
    Inc(ATree.FNodeCount);
    Result := True;
    Exit;
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
      else if CurrentToken(ALexer, ACursor).Kind = tkConstKeyword then
        { Local const (BUF_SIZE = 1024) must stay in AST — skip loses values. }
        ParseConstSection(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else if CurrentToken(ALexer, ACursor).Kind = tkTypeKeyword then
        ParseTypeSection(ALexer, ACursor, Node, ATree, ADiagnostics, ARootFileId)
      else
      begin
        { label / unknown: skip section until next local-decl keyword or body. }
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
      AsmNode := TGreenNode.Create(gnkAsmBlock,
        CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
      Inc(ACursor);
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
        (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
        Inc(ACursor);
      MatchTokenSilent(ALexer, ACursor, tkEndKeyword);
      { FPC asm clobber list: end ['eax', 'ebx', ...] }
      if (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkLBracket) then
      begin
        Inc(ACursor);
        while (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind <> tkRBracket) and
          (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
          Inc(ACursor);
        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkRBracket) then
          Inc(ACursor);
      end;
      MatchTokenSilent(ALexer, ACursor, tkSemicolon);
      Node.AppendChild(AsmNode);
      Inc(ATree.FNodeCount);
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

  Node.Text := FullName;
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
          ADiagnostics, ARootFileId, gnkThreadVarSection) and Result;
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
      tkClassKeyword:
        begin
          { implementation: `class operator` / `class function` / `class procedure`
            / `class constructor`. Consume the class prefix then parse the routine
            so the body is attached; bare `class` advance previously desynced the
            stream at advanced-record operators (TGreenNode.:=). }
          Inc(ACursor);
          SkipDirectives(ALexer, ACursor);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkOperatorKeyword) then
            Result := ParseFunctionDecl(ALexer, ACursor, AParent, ATree,
              ADiagnostics, ARootFileId) and Result
          else if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkFunctionKeyword) then
            Result := ParseFunctionDecl(ALexer, ACursor, AParent, ATree,
              ADiagnostics, ARootFileId) and Result
          else if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind in
              [tkProcedureKeyword, tkConstructorKeyword, tkDestructorKeyword]) then
            Result := ParseProcedureDecl(ALexer, ACursor, AParent, ATree,
              ADiagnostics, ARootFileId) and Result;
        end;
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


{--- end np_green_tree_parse_routines.inc ---}


{--- inlined np_green_tree_parse_statements.inc ---}
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
  SavedParentTerm: TTokenKindSet;
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
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;

  { Propagate ELSE as a parent terminator for nested loop bodies:
    while..do begin..end in a then-branch must stop at ELSE. }
  SavedParentTerm := GParentTerminators;
  Include(GParentTerminators, tkElseKeyword);
  ParseStatementList(ALexer, ACursor, Node,
    [tkElseKeyword, tkEndKeyword, tkSemicolon, tkEOF],
    ATree, ADiagnostics, ARootFileId);
  GParentTerminators := SavedParentTerm;

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
    { Node.Free } // owned by tree FFacades
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
  InitExpr: TGreenNode;
  VarNameNode: TGreenNode;
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
      { Node.Free } // owned by tree FFacades
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

  VarNameNode := TGreenNode.Create(gnkIdentifier, VarToken.ByteOffset,
    Length(VarToken.Lexeme), VarToken.Lexeme);

  if not MatchTokenSilent(ALexer, ACursor, tkAssign) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), ':=');
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;

  InitExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);

  if CurrentToken(ALexer, ACursor).Kind = tkToKeyword then
    Direction := 'to'
  else if CurrentToken(ALexer, ACursor).Kind = tkDownToKeyword then
    Direction := 'downto'
  else
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'TO/DOWNTO');
    { Node.Free } // owned by tree FFacades
    Exit(False);
  end;
  Inc(ACursor);

  { Create the for-statement node with the correct direction text from the start }
  Node := TGreenNode.Create(gnkForStatement, ForOffset, 0, Direction);
  Node.AppendChild(VarNameNode);
  if InitExpr <> nil then
    Node.AppendChild(InitExpr);

  RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
  if RHS <> nil then
    Node.AppendChild(RHS);

  if not MatchTokenSilent(ALexer, ACursor, tkDoKeyword) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'DO');
    { Node.Free } // owned by tree FFacades
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
    { Node.Free } // owned by tree FFacades
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
    { Node.Free } // owned by tree FFacades
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
    { Node.Free } // owned by tree FFacades
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
      { { SelectorNode.Free; } // record, no Free needed } // owned by tree FFacades
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
    { Node.Free } // owned by tree FFacades
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
    Node.NodeKind := gnkTryExceptStatement;
    Inc(ACursor);

    if (ACursor < ALexer.TokenCount) and
      (CurrentToken(ALexer, ACursor).Kind = tkOnKeyword) then
    begin
      while (ACursor < ALexer.TokenCount) and
        (CurrentToken(ALexer, ACursor).Kind = tkOnKeyword) do
      begin
        HandlerToken := CurrentToken(ALexer, ACursor);
        Inc(ACursor);

        if (ACursor < ALexer.TokenCount) and
          (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) then
        begin
          HandlerNode := TGreenNode.Create(gnkExceptionHandler,
            HandlerToken.ByteOffset, 0,
            CurrentToken(ALexer, ACursor).Lexeme);
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
    { Node.Free } // owned by tree FFacades
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
    DotNode, CaretNode, CallNode, ArgExpr: TGreenNode;
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
          Inc(ACursor);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind in
              [tkIdentifier, tkIntegerLiteral]) then
          begin
            StmtNode := TGreenNode.Create(gnkGotoStatement, Token.ByteOffset, 0,
              CurrentToken(ALexer, ACursor).Lexeme);
            List.AppendChild(StmtNode);
            Inc(ACursor);
          end
          else
          begin
            StmtNode := TGreenNode.Create(gnkGotoStatement, Token.ByteOffset, 0, '');
            List.AppendChild(StmtNode);
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
          { FPC asm clobber list: end ['eax', 'ebx', ...] }
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkLBracket) then
          begin
            Inc(ACursor);
            while (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind <> tkRBracket) and
              (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
              Inc(ACursor);
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkRBracket) then
              Inc(ACursor);
          end;
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
        tkRequiresKeyword, tkOnKeyword, tkInlineKeyword, tkOverloadKeyword,
        tkForwardKeyword:
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
              RHS := ParseTypeReference(ALexer, ACursor, ADiagnostics, ARootFileId, ATree);
              { RHS.Free; } // record, no Free needed
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
      tkLParen:
        begin
          { parenthesized expression as statement: (expr)^.field := value,
            (expr).method(), functionPointer^(args) etc. }
          StmtNode := TGreenNode.Create(gnkProcedureCallStatement,
            Token.ByteOffset, 0, '');
          Inc(ACursor);
          RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
          MatchTokenSilent(ALexer, ACursor, tkRParen);
          { apply postfix chains: .method, ^, () }
          while RHS <> nil do
          begin
            if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkDot) then
            begin
              Inc(ACursor);
              if (ACursor < ALexer.TokenCount) and
                IsMethodNameToken(CurrentToken(ALexer, ACursor).Kind) then
              begin
                DotNode := TGreenNode.Create(gnkDotAccess,
                  RHS.ByteOffset, 0, CurrentToken(ALexer, ACursor).Lexeme);
                DotNode.AppendChild(RHS);
                DotNode.AppendChild(TGreenNode.Create(gnkIdentifier,
                  CurrentToken(ALexer, ACursor).ByteOffset,
                  Length(CurrentToken(ALexer, ACursor).Lexeme),
                  CurrentToken(ALexer, ACursor).Lexeme));
                RHS := DotNode;
                Inc(ACursor);
              end
              else
                Break;
            end
            else if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkCaret) then
            begin
              CaretNode := TGreenNode.Create(gnkDereference,
                RHS.ByteOffset, 0, '');
              CaretNode.AppendChild(RHS);
              RHS := CaretNode;
              Inc(ACursor);
            end
            else if (ACursor < ALexer.TokenCount) and
              (CurrentToken(ALexer, ACursor).Kind = tkLParen) and
              (RHS.NodeKind in [gnkIdentifier, gnkDotAccess,
                gnkDereference, gnkFunctionCall]) then
            begin
              Inc(ACursor);
              CallNode := TGreenNode.Create(gnkFunctionCall,
                RHS.ByteOffset, 0, RHS.Text);
              CallNode.AppendChild(RHS);
              while (ACursor < ALexer.TokenCount) and
                (CurrentToken(ALexer, ACursor).Kind <> tkRParen) do
              begin
                ArgExpr := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
                if ArgExpr <> nil then
                  CallNode.AppendChild(ArgExpr);
                if (ACursor < ALexer.TokenCount) and
                  (CurrentToken(ALexer, ACursor).Kind = tkComma) then
                  Inc(ACursor)
                else
                  Break;
              end;
              MatchTokenSilent(ALexer, ACursor, tkRParen);
              RHS := CallNode;
            end
            else
              Break;
          end;
          if RHS <> nil then
            StmtNode.AppendChild(RHS);
          if (ACursor < ALexer.TokenCount) and
            (CurrentToken(ALexer, ACursor).Kind = tkAssign) then
          begin
            { assignment: (expr)^.field := value }
            StmtNode.NodeKind := gnkAssignmentStatement;
            Inc(ACursor);
            RHS := ParseExpression(ALexer, ACursor, ADiagnostics, ARootFileId);
            if RHS <> nil then
              StmtNode.AppendChild(RHS);
          end;
          List.AppendChild(StmtNode);
          Inc(ATree.FNodeCount);
          MatchTokenSilent(ALexer, ACursor, tkSemicolon);
          Result := True;
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
      (CurrentToken(ALexer, ACursor).Kind in (ATerminatorSet + GParentTerminators)) then
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

{--- end np_green_tree_parse_statements.inc ---}

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
  { interface keyword may be absent when preprocessor skipped it
    (e.g. {$IFDEF WINDOWS} wrapping the entire unit on Linux) }
  InterfaceNode := TGreenNode.Create(
    gnkInterfaceSection,
    0, 0, ''
  );
  AParent.AppendChild(InterfaceNode);
  Inc(ATree.FNodeCount);

  SkipDirectives(ALexer, ACursor);

  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkInterfaceKeyword) then
  begin
    Inc(ACursor);

    Result := ParseUsesClause(
      ALexer, ACursor, ATree, uskInterface,
      InterfaceNode, ADiagnostics, ARootFileId);
    if not Result then
      Exit;

    Result := ParseBlockDeclarations(
      ALexer, ACursor, InterfaceNode, ATree, ADiagnostics, ARootFileId);
    if not Result then
      Exit;
  end;

  { implementation keyword may also be absent when preprocessor skipped it }
  SkipDirectives(ALexer, ACursor);
  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkImplementationKeyword) then
  begin
    Inc(ACursor);

    ImplementationNode := TGreenNode.Create(
      gnkImplementationSection,
      CurrentToken(ALexer, ACursor - 1).ByteOffset, 0, ''
    );
    AParent.AppendChild(ImplementationNode);
    Inc(ATree.FNodeCount);

    Result := ParseUsesClause(
      ALexer, ACursor, ATree, uskImplementation,
      ImplementationNode, ADiagnostics, ARootFileId);
    if not Result then
      Exit;

    Result := ParseBlockDeclarations(
      ALexer, ACursor, ImplementationNode, ATree, ADiagnostics, ARootFileId);
    if not Result then
      Exit;
  end;

  { handle begin...end. initialization block (FPC syntax without 'initialization' keyword) }
  if (ACursor < ALexer.TokenCount) and
    (CurrentToken(ALexer, ACursor).Kind = tkBeginKeyword) then
  begin
    LInitNode := TGreenNode.Create(
      gnkInitializationSection,
      CurrentToken(ALexer, ACursor).ByteOffset, 0, '');
    Inc(ACursor);
    ParseStatementList(ALexer, ACursor, LInitNode,
      [tkEndKeyword, tkEOF],
      ATree, ADiagnostics, ARootFileId);
    ImplementationNode.AppendChild(LInitNode);
  end
  else if (ACursor < ALexer.TokenCount) and
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

{--- end np_green_tree_parser_impl.inc ---}


function NilGreenNode: TGreenNode;
begin
  Result := nextpas.compiler.syntax.green_tree.core.NilGreenNode;
end;

function ParseGreenTree(
  const ALexer: TLexerResult;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenTree;
begin
  Result := ParseGreenTree(ALexer, ADiagnostics, ARootFileId, nil);
end;

function ParseGreenTree(
  const ALexer: TLexerResult;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const AAllocator: IAllocator
): TGreenTree;
var
  Cursor: LongInt;
  Current: TToken;
  RootNode: TGreenNode;
  DeclaredName: string;
  DeclaredNameOffset: LongInt;
  PreviousExpressionTree: TGreenTree;
begin
  if AAllocator <> nil then
    Result := TGreenTree.Create(AAllocator)
  else
    Result := TGreenTree.Create;
  PreviousExpressionTree := nextpas.compiler.syntax.green_tree.core.ActiveExpressionTree;
  nextpas.compiler.syntax.green_tree.core.ActiveExpressionTree := Result;
  try
    Cursor := 0;
    SkipDirectives(ALexer, Cursor);
    Current := CurrentToken(ALexer, Cursor);
    Result.FRootKind := RootKindFromToken(Current.Kind);
    if Result.FRootKind = grkUnknown then
    begin
      EmitSyntaxError(ADiagnostics, ARootFileId, Current, 'program|unit|library|package');
      Exit;
    end;
    RootNode := TGreenNode.Create(
      GreenNodeKindFromRootKind(Result.FRootKind),
      Current.ByteOffset, Length(Current.Lexeme), Current.Lexeme);
    Result.FRootNode := RootNode;
    Result.FNodeCount := 1;
    AdvanceCursor(Cursor);
    if not ConsumeIdentifierPath(ALexer, Cursor, Result.FRootKind = grkUnit, DeclaredName, DeclaredNameOffset) then
    begin
      EmitSyntaxError(ADiagnostics, ARootFileId, CurrentToken(ALexer, Cursor), 'identifier');
      Exit;
    end;
    Result.FDeclaredName := DeclaredName;
    RootNode.AppendChild(TGreenNode.Create(gnkIdentifier, DeclaredNameOffset, Length(DeclaredName), DeclaredName));
    Inc(Result.FNodeCount);
    if not MatchToken(ALexer, Cursor, tkSemicolon, ADiagnostics, ARootFileId, ';') then Exit;
    Inc(Result.FNodeCount);
    case Result.FRootKind of
      grkProgram, grkLibrary, grkPackage:
        if not ParseProgramLikeRoot(ALexer, Cursor, Result, RootNode, ADiagnostics, ARootFileId) then Exit;
      grkUnit:
        if not ParseUnitRoot(ALexer, Cursor, Result, RootNode, ADiagnostics, ARootFileId) then Exit;
      grkUnknown: Exit;
    end;
    Result.FIsValid := not ADiagnostics.HasErrors;
    Result.Freeze;
  finally
    nextpas.compiler.syntax.green_tree.core.ActiveExpressionTree := PreviousExpressionTree;
  end;
end;

end.
