unit np_green_tree;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$UNITPATH .}
{$UNITPATH ../diagnostics}
{$UNITPATH ../frontend}

interface

uses
  np_diagnostics_sink, np_lexer, np_source_database,
  nextpas.core.collections.vec;

type
  { Forward declarations for rowan-style internal storage }
  TGreenTree = class;

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
    gnkBeginBlock, gnkAsmBlock, gnkEndBlock,
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
    gnkVarSection, gnkThreadVarSection, gnkConstSection, gnkTypeSection,
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

  {**
   * TGreenNodeData — Compact rowan-style node storage
   *
   * 28 bytes per node, stored contiguously in TVec.
   * Text is centralized in TGreenTreeData.Text.
   * Children referenced by (ChildStart, ChildCount) — contiguous in FFacades.
   *}
  TGreenNodeData = packed record
    Kind: TGreenNodeKind;
    ByteOffset: LongInt;
    ByteLength: LongInt;
    TextStart: LongInt;
    TextLen: LongInt;
    ChildStart: LongInt;
    ChildCount: LongInt;
  end;

  {**
   * TGreenTreeData — Centralized tree storage
   *
   * FNodes[i] and FFacades[i] are strictly 1:1 corresponding.
   *}
  TGreenTreeData = record
    Nodes: specialize TVec<TGreenNodeData>;
    Text: string;
    RootIndex: LongInt;
  end;

  {**
   * TGreenNode - rowan-style value type
   *
   * Value-semantics record, freely copyable, no VMT overhead.
   * nil represented by FIndex = -1.
   * class operators provide full backward compatibility with = nil / <> nil / := nil.
   * All properties delegate to TGreenTree compact storage.
   *}
  TGreenNode = record
  private
    FOwner: TGreenTree;
    FIndex: LongInt;
    function GetNodeKind: TGreenNodeKind;
    procedure SetNodeKind(AValue: TGreenNodeKind);
    function GetByteOffset: LongInt;
    function GetByteLength: LongInt;
    function GetText: string;
    procedure SetText(const AValue: string);
    procedure AppendChild(const AChild: TGreenNode);
  public
    class operator :=(const B: Pointer): TGreenNode;
    class operator =(const A: TGreenNode; const B: Pointer): Boolean;
    class operator <>(const A: TGreenNode; const B: Pointer): Boolean;
    class operator =(const A: TGreenNode; const B: TGreenNode): Boolean;
    class operator <>(const A: TGreenNode; const B: TGreenNode): Boolean;
    constructor Create(
      const ANodeKind: TGreenNodeKind;
      const AByteOffset: LongInt;
      const AByteLength: LongInt;
      const AText: string
    );
    constructor CreateFacade(AOwner: TGreenTree; AIndex: LongInt);
    function NodeKindName: string;
    function ChildCount: LongInt;
    function ChildAt(const AIndex: LongInt): TGreenNode;
    function IsNil: Boolean; inline;
    property NodeKind: TGreenNodeKind read GetNodeKind write SetNodeKind;
    property ByteOffset: LongInt read GetByteOffset;
    property ByteLength: LongInt read GetByteLength;
    property Text: string read GetText write SetText;
    property Owner: TGreenTree read FOwner;
    property Index: LongInt read FIndex;
  end;

 TGreenTree = class
 private
   FRootKind: TGreenRootKind;
   FDeclaredName: string;
   FNodeCount: LongInt;
   FIsValid: Boolean;
   FFrozen: Boolean;
   FInterfaceUses: array of string;
   FImplementationUses: array of string;
   FForeignProcedureDecls: array of TForeignProcedureDecl;
   FRootNode: TGreenNode;
   { Rowan-style compact storage: FNodes[i] <-> FFacades[i] strictly 1:1 }
   FNodes: specialize TVec<TGreenNodeData>;
   FNodeText: string;
   FFacades: specialize TVec<TGreenNode>;
   { Allocate node data and facade in the tree. Returns facade. }
   procedure AppendInterfaceUse(const AUseName: string);
   procedure AppendImplementationUse(const AUseName: string);
   procedure AppendForeignProcedureDecl(
     const AForeignProcedureDecl: TForeignProcedureDecl
   );
   procedure CheckMutable; inline;
 public
   constructor Create;
   destructor Destroy; override;
   procedure Freeze;
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
   property IsFrozen: Boolean read FFrozen;
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

var
  ActiveExpressionTree: TGreenTree = nil;

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
    (AKind = tkForwardKeyword);
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
    tkStdCallKeyword, tkSafeCallKeyword, tkRegisterKeyword, tkPascalKeyword,
    tkFarKeyword, tkNearKeyword, tkCppDeclKeyword, tkVarArgsKeyword,
    tkVirtualKeyword, tkOverrideKeyword, tkAbstractKeyword, tkStaticKeyword,
    tkDynamicKeyword, tkReintroduceKeyword, tkMessageKeyword,
    tkDeprecatedKeyword, tkPlatformKeyword, tkExperimentalKeyword];
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

{$I np_green_tree_parse_expressions.inc}
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
      { Node.Free } // owned by tree FFacades
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

  { Parse optional var/const/type declarations before begin }
  ParseBlockDeclarations(ALexer, ACursor, Node, ActiveExpressionTree,
    ADiagnostics, ARootFileId);

  if not MatchTokenSilent(ALexer, ACursor, tkBeginKeyword) then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId,
      CurrentToken(ALexer, ACursor), 'BEGIN');
    { Node.Free } // owned by tree FFacades
    Exit(nil);
  end;

  if not ParseBeginBlock(ALexer, ACursor, Node, ActiveExpressionTree,
    ADiagnostics, ARootFileId) then
  begin
    { Node.Free } // owned by tree FFacades
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
  Nesting: LongInt;
  MethodModifiers: string;
  IsCompilerRoot: Boolean;
  IsCompilerTypeKind: Boolean;

{$I np_green_tree_clone_type.inc}
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
    (CurrentToken(ALexer, ACursor).Kind <> tkIdentifier) then
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
  begin
    if (CurrentToken(ALexer, ACursor).Kind = tkIdentifier) and
      SameText(CurrentToken(ALexer, ACursor).Lexeme, 'compilerproc') then
      FullName := FullName + ';compilerproc';
    Inc(ACursor);
    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
  end;

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
      FullName := FullName + ';compilerproc';
    Inc(ACursor);
    MatchTokenSilent(ALexer, ACursor, tkSemicolon);
  end;

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
              RHS := ParseTypeReference(
                ALexer,
                ACursor,
                ADiagnostics,
                ARootFileId
              );
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

constructor TGreenTree.Create;
begin
  inherited Create;
  FRootKind := grkUnknown;
  FDeclaredName := '';
  FNodeCount := 0;
  FIsValid := False;
  FFrozen := False;
  FRootNode := nil;
  SetLength(FInterfaceUses, 0);
  SetLength(FImplementationUses, 0);
  SetLength(FForeignProcedureDecls, 0);
  FNodes := specialize TVec<TGreenNodeData>.Create;
  FFacades := specialize TVec<TGreenNode>.Create;
  FNodeText := '';
end;

destructor TGreenTree.Destroy;
begin
  FFacades.Free;
  FNodes.Free;
  inherited Destroy;
end;

procedure TGreenTree.CheckMutable;
begin
  Assert(not FFrozen, 'TGreenTree: attempt to mutate frozen tree');
end;

procedure TGreenTree.Freeze;
begin
  FFrozen := True;
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
    Result.Freeze;
  finally
    ActiveExpressionTree := PreviousExpressionTree;
  end;
end;

class operator TGreenNode.:=(const B: Pointer): TGreenNode;
begin
  Result.FOwner := nil;
  Result.FIndex := -1;
end;

class operator TGreenNode.=(const A: TGreenNode; const B: Pointer): Boolean;
begin
  Result := A.FIndex < 0;
end;

class operator TGreenNode.<>(const A: TGreenNode; const B: Pointer): Boolean;
begin
  Result := A.FIndex >= 0;
end;

class operator TGreenNode.=(const A: TGreenNode; const B: TGreenNode): Boolean;
begin
  Result := (A.FOwner = B.FOwner) and (A.FIndex = B.FIndex);
end;

class operator TGreenNode.<>(const A: TGreenNode; const B: TGreenNode): Boolean;
begin
  Result := not (A = B);
end;

function NilGreenNode: TGreenNode; inline;
begin
  Result.FOwner := nil;
  Result.FIndex := -1;
end;

{**
 * TGreenNode.Create — backward-compatible factory
 *
 * Directly allocates node data in ActiveExpressionTree's compact storage
 * and registers Self as the facade in FFacades.
 * FNodes[i] and FFacades[i] are strictly 1:1.
 *}
constructor TGreenNode.Create(
  const ANodeKind: TGreenNodeKind;
  const AByteOffset: LongInt;
  const AByteLength: LongInt;
  const AText: string
);
var
  Data: TGreenNodeData;
  Idx: LongInt;
begin
  if ActiveExpressionTree <> nil then
  begin
    if ActiveExpressionTree.IsFrozen then
    begin
      FOwner := nil;
      FIndex := -1;
      Exit;
    end;
    FOwner := ActiveExpressionTree;

    Data.Kind := ANodeKind;
    Data.ByteOffset := AByteOffset;
    Data.ByteLength := AByteLength;
    Data.TextStart := Length(FOwner.FNodeText);
    Data.TextLen := Length(AText);
    Data.ChildStart := -1;
    Data.ChildCount := 0;

    FOwner.FNodeText := FOwner.FNodeText + AText;
    Idx := FOwner.FNodes.Count;
    FOwner.FNodes.Push(Data);
    FIndex := Idx;

    { Register Self as the facade for this index }
    FOwner.FFacades.Push(Self);
    Exit;
  end;

  { Fallback: no active tree (should not happen in normal parsing) }
  FOwner := nil;
  FIndex := -1;
end;

constructor TGreenNode.CreateFacade(AOwner: TGreenTree; AIndex: LongInt);
begin
  FOwner := AOwner;
  FIndex := AIndex;
end;

function TGreenNode.IsNil: Boolean;
begin
  Result := FIndex < 0;
end;

procedure TGreenNode.AppendChild(const AChild: TGreenNode);
var
  D: TGreenNodeData;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count)
    or (AChild = nil) then
    Exit;
  { Prevent cyclic AST: reject appending self as child }
  if (AChild.FOwner = FOwner) and (AChild.FIndex = FIndex) then
    Exit;
  FOwner.CheckMutable;
  D := FOwner.FNodes[FIndex];
  if D.ChildStart < 0 then
  begin
    D.ChildStart := AChild.FIndex;
    D.ChildCount := 1;
  end
  else
    Inc(D.ChildCount);
  FOwner.FNodes[FIndex] := D;
end;

function TGreenNode.NodeKindName: string;
begin
  Result := GreenNodeKindLabel(GetNodeKind);
end;
function TGreenNode.GetNodeKind: TGreenNodeKind;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit(gnkUnknown);
  Result := FOwner.FNodes[FIndex].Kind;
end;

procedure TGreenNode.SetNodeKind(AValue: TGreenNodeKind);
var
  D: TGreenNodeData;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit;
  FOwner.CheckMutable;
  D := FOwner.FNodes[FIndex];
  D.Kind := AValue;
  FOwner.FNodes[FIndex] := D;
end;

function TGreenNode.GetByteOffset: LongInt;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit(0);
  Result := FOwner.FNodes[FIndex].ByteOffset;
end;

function TGreenNode.GetByteLength: LongInt;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit(0);
  Result := FOwner.FNodes[FIndex].ByteLength;
end;

function TGreenNode.GetText: string;
var
  D: TGreenNodeData;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit('');
  D := FOwner.FNodes[FIndex];
  if (D.TextStart >= 0) and (D.TextLen > 0)
    and (D.TextStart + D.TextLen <= Length(FOwner.FNodeText)) then
    Result := Copy(FOwner.FNodeText, D.TextStart + 1, D.TextLen)
  else
    Result := '';
end;

procedure TGreenNode.SetText(const AValue: string);
var
  D: TGreenNodeData;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit;
  FOwner.CheckMutable;
  D := FOwner.FNodes[FIndex];
  D.TextStart := Length(FOwner.FNodeText);
  D.TextLen := Length(AValue);
  FOwner.FNodeText := FOwner.FNodeText + AValue;
  FOwner.FNodes[FIndex] := D;
end;


function TGreenNode.ChildCount: LongInt;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit(0);
  Result := FOwner.FNodes[FIndex].ChildCount;
end;

function TGreenNode.ChildAt(const AIndex: LongInt): TGreenNode;
var
  D: TGreenNodeData;
  ChildIdx: LongInt;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit(nil);
  D := FOwner.FNodes[FIndex];
  if (AIndex < 0) or (AIndex >= D.ChildCount) or (D.ChildStart < 0) then
    Exit(nil);
  ChildIdx := D.ChildStart + AIndex;
  if (ChildIdx >= 0) and (ChildIdx < FOwner.FFacades.Count) then
  begin
    Result := FOwner.FFacades[ChildIdx];
    { Guard against cyclic AST: if child is self, return nil to break recursion }
    if (Result <> nil) and (Result.FOwner = FOwner) and (Result.FIndex = FIndex) then
      Result := nil;
  end
  else
    Result := nil;
end;

end.
