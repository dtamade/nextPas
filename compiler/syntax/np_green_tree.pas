unit np_green_tree;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$UNITPATH .}
{$UNITPATH ../diagnostics}
{$UNITPATH ../frontend}

interface

uses
  np_green_tree_base,
  np_green_tree_core,
  np_diagnostics_sink, np_lexer, np_source_database,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

type
  { Base types — single source in np_green_tree_base (four-piece base) }
  TForeignProcedureDecl = np_green_tree_base.TForeignProcedureDecl;
  TGreenNodeKind = np_green_tree_base.TGreenNodeKind;
  TGreenRootKind = np_green_tree_base.TGreenRootKind;
  TGreenNodeData = np_green_tree_base.TGreenNodeData;
  TGreenTreeData = np_green_tree_base.TGreenTreeData;

const
  gnkUnknown = np_green_tree_base.gnkUnknown;
  gnkProgram = np_green_tree_base.gnkProgram;
  gnkUnit = np_green_tree_base.gnkUnit;
  gnkLibrary = np_green_tree_base.gnkLibrary;
  gnkPackage = np_green_tree_base.gnkPackage;
  gnkUsesClause = np_green_tree_base.gnkUsesClause;
  gnkUseEntry = np_green_tree_base.gnkUseEntry;
  gnkInterfaceSection = np_green_tree_base.gnkInterfaceSection;
  gnkImplementationSection = np_green_tree_base.gnkImplementationSection;
  gnkInitializationSection = np_green_tree_base.gnkInitializationSection;
  gnkFinalizationSection = np_green_tree_base.gnkFinalizationSection;
  gnkForeignProcedureDecl = np_green_tree_base.gnkForeignProcedureDecl;
  gnkBeginBlock = np_green_tree_base.gnkBeginBlock;
  gnkAsmBlock = np_green_tree_base.gnkAsmBlock;
  gnkEndBlock = np_green_tree_base.gnkEndBlock;
  gnkStatementList = np_green_tree_base.gnkStatementList;
  gnkIfStatement = np_green_tree_base.gnkIfStatement;
  gnkWhileStatement = np_green_tree_base.gnkWhileStatement;
  gnkForStatement = np_green_tree_base.gnkForStatement;
  gnkForInStatement = np_green_tree_base.gnkForInStatement;
  gnkRepeatStatement = np_green_tree_base.gnkRepeatStatement;
  gnkWithStatement = np_green_tree_base.gnkWithStatement;
  gnkCaseStatement = np_green_tree_base.gnkCaseStatement;
  gnkCaseSelector = np_green_tree_base.gnkCaseSelector;
  gnkCaseLabel = np_green_tree_base.gnkCaseLabel;
  gnkAssignmentStatement = np_green_tree_base.gnkAssignmentStatement;
  gnkProcedureCallStatement = np_green_tree_base.gnkProcedureCallStatement;
  gnkGotoStatement = np_green_tree_base.gnkGotoStatement;
  gnkBreakStatement = np_green_tree_base.gnkBreakStatement;
  gnkContinueStatement = np_green_tree_base.gnkContinueStatement;
  gnkExitStatement = np_green_tree_base.gnkExitStatement;
  gnkTryExceptStatement = np_green_tree_base.gnkTryExceptStatement;
  gnkTryFinallyStatement = np_green_tree_base.gnkTryFinallyStatement;
  gnkExceptionHandler = np_green_tree_base.gnkExceptionHandler;
  gnkRaiseStatement = np_green_tree_base.gnkRaiseStatement;
  gnkVarSection = np_green_tree_base.gnkVarSection;
  gnkThreadVarSection = np_green_tree_base.gnkThreadVarSection;
  gnkConstSection = np_green_tree_base.gnkConstSection;
  gnkTypeSection = np_green_tree_base.gnkTypeSection;
  gnkLabelSection = np_green_tree_base.gnkLabelSection;
  gnkVarDecl = np_green_tree_base.gnkVarDecl;
  gnkConstDecl = np_green_tree_base.gnkConstDecl;
  gnkTypeDecl = np_green_tree_base.gnkTypeDecl;
  gnkProcedureDecl = np_green_tree_base.gnkProcedureDecl;
  gnkFunctionDecl = np_green_tree_base.gnkFunctionDecl;
  gnkRecordType = np_green_tree_base.gnkRecordType;
  gnkArrayType = np_green_tree_base.gnkArrayType;
  gnkClassType = np_green_tree_base.gnkClassType;
  gnkEnumType = np_green_tree_base.gnkEnumType;
  gnkClassField = np_green_tree_base.gnkClassField;
  gnkClassMethod = np_green_tree_base.gnkClassMethod;
  gnkClassProperty = np_green_tree_base.gnkClassProperty;
  gnkVisibilityLabel = np_green_tree_base.gnkVisibilityLabel;
  gnkTypeParamList = np_green_tree_base.gnkTypeParamList;
  gnkIdentifier = np_green_tree_base.gnkIdentifier;
  gnkStringLiteral = np_green_tree_base.gnkStringLiteral;
  gnkIntegerLiteral = np_green_tree_base.gnkIntegerLiteral;
  gnkRealLiteral = np_green_tree_base.gnkRealLiteral;
  gnkCharLiteral = np_green_tree_base.gnkCharLiteral;
  gnkBinaryExpression = np_green_tree_base.gnkBinaryExpression;
  gnkUnaryExpression = np_green_tree_base.gnkUnaryExpression;
  gnkDotAccess = np_green_tree_base.gnkDotAccess;
  gnkArrayAccess = np_green_tree_base.gnkArrayAccess;
  gnkFunctionCall = np_green_tree_base.gnkFunctionCall;
  gnkDereference = np_green_tree_base.gnkDereference;
  gnkAddressOf = np_green_tree_base.gnkAddressOf;
  gnkSetConstructor = np_green_tree_base.gnkSetConstructor;
  gnkRangeExpression = np_green_tree_base.gnkRangeExpression;
  gnkParameterList = np_green_tree_base.gnkParameterList;
  gnkParameterDecl = np_green_tree_base.gnkParameterDecl;
  gnkFieldList = np_green_tree_base.gnkFieldList;
  gnkError = np_green_tree_base.gnkError;
  grkUnknown = np_green_tree_base.grkUnknown;
  grkProgram = np_green_tree_base.grkProgram;
  grkUnit = np_green_tree_base.grkUnit;
  grkLibrary = np_green_tree_base.grkLibrary;
  grkPackage = np_green_tree_base.grkPackage;

type
  { Storage — single source in np_green_tree_core (four-piece core) }
  TGreenNode = np_green_tree_core.TGreenNode;
  TGreenStringVec = np_green_tree_core.TGreenStringVec;
  TGreenForeignProcVec = np_green_tree_core.TGreenForeignProcVec;
  TGreenTree = np_green_tree_core.TGreenTree;

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

{ ActiveExpressionTree now in np_green_tree_core }

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

{$I np_green_tree_parser_impl.inc}

function NilGreenNode: TGreenNode;
begin
  Result := np_green_tree_core.NilGreenNode;
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
  PreviousExpressionTree := np_green_tree_core.ActiveExpressionTree;
  np_green_tree_core.ActiveExpressionTree := Result;
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
    np_green_tree_core.ActiveExpressionTree := PreviousExpressionTree;
  end;
end;

end.
