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
{$I np_green_tree_parse_declarations.inc}
{$I np_green_tree_clone_type.inc}
{$I np_green_tree_parse_routines.inc}
{$I np_green_tree_parse_statements.inc}
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

{$I np_green_tree_core.inc}
end.
