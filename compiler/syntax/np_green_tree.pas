unit np_green_tree;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$UNITPATH .}

interface

uses
  nextpas.compiler.syntax.green_tree,
  np_lexer, np_diagnostics_sink, np_source_database,
  nextpas.core.mem.intf;

type
  TForeignProcedureDecl = nextpas.compiler.syntax.green_tree.TForeignProcedureDecl;
  TGreenNodeKind = nextpas.compiler.syntax.green_tree.TGreenNodeKind;
  TGreenRootKind = nextpas.compiler.syntax.green_tree.TGreenRootKind;
  TGreenNodeData = nextpas.compiler.syntax.green_tree.TGreenNodeData;
  TGreenTreeData = nextpas.compiler.syntax.green_tree.TGreenTreeData;
  TGreenNode = nextpas.compiler.syntax.green_tree.TGreenNode;
  TGreenStringVec = nextpas.compiler.syntax.green_tree.TGreenStringVec;
  TGreenForeignProcVec = nextpas.compiler.syntax.green_tree.TGreenForeignProcVec;
  TGreenTree = nextpas.compiler.syntax.green_tree.TGreenTree;

const
  gnkUnknown = nextpas.compiler.syntax.green_tree.gnkUnknown;
  gnkProgram = nextpas.compiler.syntax.green_tree.gnkProgram;
  gnkUnit = nextpas.compiler.syntax.green_tree.gnkUnit;
  gnkLibrary = nextpas.compiler.syntax.green_tree.gnkLibrary;
  gnkPackage = nextpas.compiler.syntax.green_tree.gnkPackage;
  gnkUsesClause = nextpas.compiler.syntax.green_tree.gnkUsesClause;
  gnkUseEntry = nextpas.compiler.syntax.green_tree.gnkUseEntry;
  gnkInterfaceSection = nextpas.compiler.syntax.green_tree.gnkInterfaceSection;
  gnkImplementationSection = nextpas.compiler.syntax.green_tree.gnkImplementationSection;
  gnkInitializationSection = nextpas.compiler.syntax.green_tree.gnkInitializationSection;
  gnkFinalizationSection = nextpas.compiler.syntax.green_tree.gnkFinalizationSection;
  gnkForeignProcedureDecl = nextpas.compiler.syntax.green_tree.gnkForeignProcedureDecl;
  gnkBeginBlock = nextpas.compiler.syntax.green_tree.gnkBeginBlock;
  gnkAsmBlock = nextpas.compiler.syntax.green_tree.gnkAsmBlock;
  gnkEndBlock = nextpas.compiler.syntax.green_tree.gnkEndBlock;
  gnkStatementList = nextpas.compiler.syntax.green_tree.gnkStatementList;
  gnkIfStatement = nextpas.compiler.syntax.green_tree.gnkIfStatement;
  gnkWhileStatement = nextpas.compiler.syntax.green_tree.gnkWhileStatement;
  gnkForStatement = nextpas.compiler.syntax.green_tree.gnkForStatement;
  gnkForInStatement = nextpas.compiler.syntax.green_tree.gnkForInStatement;
  gnkRepeatStatement = nextpas.compiler.syntax.green_tree.gnkRepeatStatement;
  gnkWithStatement = nextpas.compiler.syntax.green_tree.gnkWithStatement;
  gnkCaseStatement = nextpas.compiler.syntax.green_tree.gnkCaseStatement;
  gnkCaseSelector = nextpas.compiler.syntax.green_tree.gnkCaseSelector;
  gnkCaseLabel = nextpas.compiler.syntax.green_tree.gnkCaseLabel;
  gnkAssignmentStatement = nextpas.compiler.syntax.green_tree.gnkAssignmentStatement;
  gnkProcedureCallStatement = nextpas.compiler.syntax.green_tree.gnkProcedureCallStatement;
  gnkGotoStatement = nextpas.compiler.syntax.green_tree.gnkGotoStatement;
  gnkBreakStatement = nextpas.compiler.syntax.green_tree.gnkBreakStatement;
  gnkContinueStatement = nextpas.compiler.syntax.green_tree.gnkContinueStatement;
  gnkExitStatement = nextpas.compiler.syntax.green_tree.gnkExitStatement;
  gnkTryExceptStatement = nextpas.compiler.syntax.green_tree.gnkTryExceptStatement;
  gnkTryFinallyStatement = nextpas.compiler.syntax.green_tree.gnkTryFinallyStatement;
  gnkExceptionHandler = nextpas.compiler.syntax.green_tree.gnkExceptionHandler;
  gnkRaiseStatement = nextpas.compiler.syntax.green_tree.gnkRaiseStatement;
  gnkVarSection = nextpas.compiler.syntax.green_tree.gnkVarSection;
  gnkThreadVarSection = nextpas.compiler.syntax.green_tree.gnkThreadVarSection;
  gnkConstSection = nextpas.compiler.syntax.green_tree.gnkConstSection;
  gnkTypeSection = nextpas.compiler.syntax.green_tree.gnkTypeSection;
  gnkLabelSection = nextpas.compiler.syntax.green_tree.gnkLabelSection;
  gnkVarDecl = nextpas.compiler.syntax.green_tree.gnkVarDecl;
  gnkConstDecl = nextpas.compiler.syntax.green_tree.gnkConstDecl;
  gnkTypeDecl = nextpas.compiler.syntax.green_tree.gnkTypeDecl;
  gnkProcedureDecl = nextpas.compiler.syntax.green_tree.gnkProcedureDecl;
  gnkFunctionDecl = nextpas.compiler.syntax.green_tree.gnkFunctionDecl;
  gnkRecordType = nextpas.compiler.syntax.green_tree.gnkRecordType;
  gnkArrayType = nextpas.compiler.syntax.green_tree.gnkArrayType;
  gnkClassType = nextpas.compiler.syntax.green_tree.gnkClassType;
  gnkEnumType = nextpas.compiler.syntax.green_tree.gnkEnumType;
  gnkClassField = nextpas.compiler.syntax.green_tree.gnkClassField;
  gnkClassMethod = nextpas.compiler.syntax.green_tree.gnkClassMethod;
  gnkClassProperty = nextpas.compiler.syntax.green_tree.gnkClassProperty;
  gnkVisibilityLabel = nextpas.compiler.syntax.green_tree.gnkVisibilityLabel;
  gnkTypeParamList = nextpas.compiler.syntax.green_tree.gnkTypeParamList;
  gnkIdentifier = nextpas.compiler.syntax.green_tree.gnkIdentifier;
  gnkStringLiteral = nextpas.compiler.syntax.green_tree.gnkStringLiteral;
  gnkIntegerLiteral = nextpas.compiler.syntax.green_tree.gnkIntegerLiteral;
  gnkRealLiteral = nextpas.compiler.syntax.green_tree.gnkRealLiteral;
  gnkCharLiteral = nextpas.compiler.syntax.green_tree.gnkCharLiteral;
  gnkBinaryExpression = nextpas.compiler.syntax.green_tree.gnkBinaryExpression;
  gnkUnaryExpression = nextpas.compiler.syntax.green_tree.gnkUnaryExpression;
  gnkDotAccess = nextpas.compiler.syntax.green_tree.gnkDotAccess;
  gnkArrayAccess = nextpas.compiler.syntax.green_tree.gnkArrayAccess;
  gnkFunctionCall = nextpas.compiler.syntax.green_tree.gnkFunctionCall;
  gnkDereference = nextpas.compiler.syntax.green_tree.gnkDereference;
  gnkAddressOf = nextpas.compiler.syntax.green_tree.gnkAddressOf;
  gnkSetConstructor = nextpas.compiler.syntax.green_tree.gnkSetConstructor;
  gnkRangeExpression = nextpas.compiler.syntax.green_tree.gnkRangeExpression;
  gnkParameterList = nextpas.compiler.syntax.green_tree.gnkParameterList;
  gnkParameterDecl = nextpas.compiler.syntax.green_tree.gnkParameterDecl;
  gnkFieldList = nextpas.compiler.syntax.green_tree.gnkFieldList;
  gnkError = nextpas.compiler.syntax.green_tree.gnkError;
  grkUnknown = nextpas.compiler.syntax.green_tree.grkUnknown;
  grkProgram = nextpas.compiler.syntax.green_tree.grkProgram;
  grkUnit = nextpas.compiler.syntax.green_tree.grkUnit;
  grkLibrary = nextpas.compiler.syntax.green_tree.grkLibrary;
  grkPackage = nextpas.compiler.syntax.green_tree.grkPackage;

function ParseGreenTree(const ALexer: TLexerResult; const ADiagnostics: TDiagnosticsSink; const ARootFileId: TSourceFileId): TGreenTree; overload; inline;
function ParseGreenTree(const ALexer: TLexerResult; const ADiagnostics: TDiagnosticsSink; const ARootFileId: TSourceFileId; const AAllocator: IAllocator): TGreenTree; overload; inline;
function GreenNodeKindLabel(const AKind: TGreenNodeKind): string; inline;
function GreenNodeIsNil(const ANode: TGreenNode): Boolean; inline;
function NilGreenNode: TGreenNode; inline;

implementation

function ParseGreenTree(const ALexer: TLexerResult; const ADiagnostics: TDiagnosticsSink; const ARootFileId: TSourceFileId): TGreenTree; inline;
begin
  Result := nextpas.compiler.syntax.green_tree.ParseGreenTree(ALexer, ADiagnostics, ARootFileId);
end;

function ParseGreenTree(const ALexer: TLexerResult; const ADiagnostics: TDiagnosticsSink; const ARootFileId: TSourceFileId; const AAllocator: IAllocator): TGreenTree; inline;
begin
  Result := nextpas.compiler.syntax.green_tree.ParseGreenTree(ALexer, ADiagnostics, ARootFileId, AAllocator);
end;

function GreenNodeKindLabel(const AKind: TGreenNodeKind): string; inline;
begin
  Result := nextpas.compiler.syntax.green_tree.GreenNodeKindLabel(AKind);
end;

function GreenNodeIsNil(const ANode: TGreenNode): Boolean; inline;
begin
  Result := nextpas.compiler.syntax.green_tree.GreenNodeIsNil(ANode);
end;

function NilGreenNode: TGreenNode; inline;
begin
  Result := nextpas.compiler.syntax.green_tree.NilGreenNode;
end;

end.
