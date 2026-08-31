unit nextpas.compiler.syntax.green_tree;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$UNITPATH .}

interface

uses
  nextpas.compiler.syntax.green_tree.base,
  nextpas.compiler.syntax.green_tree.core,
  np_diagnostics_sink, np_lexer, np_source_database,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

type
  { Base types — single source in green_tree.base }
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
  { Storage — single source in green_tree.core }
  TGreenNode = nextpas.compiler.syntax.green_tree.core.TGreenNode;
  TGreenStringVec = nextpas.compiler.syntax.green_tree.core.TGreenStringVec;
  TGreenForeignProcVec = nextpas.compiler.syntax.green_tree.core.TGreenForeignProcVec;
  TGreenTree = nextpas.compiler.syntax.green_tree.core.TGreenTree;

function ParseGreenTree(
  const ALexer: TLexerResult;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenTree; overload;

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
  nextpas.core.text.conv,
  np_green_tree;

{ Thin delegates — green_tree.core is single source for storage; parser
  still lives in legacy np_green_tree during flat migration phase. The flat
  facade therefore bridges to legacy implementation via hard cast; once parser
  inc are migrated, this will directly use core helpers. }
function GreenNodeKindLabel(const AKind: TGreenNodeKind): string;
begin
  Result := nextpas.compiler.syntax.green_tree.core.GreenNodeKindLabel(AKind);
end;

function GreenNodeIsNil(const ANode: TGreenNode): Boolean;
begin
  Result := nextpas.compiler.syntax.green_tree.core.GreenNodeIsNil(ANode);
end;

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
  Result := np_green_tree.ParseGreenTree(ALexer, ADiagnostics, ARootFileId);
end;

function ParseGreenTree(
  const ALexer: TLexerResult;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const AAllocator: IAllocator
): TGreenTree;
begin
  Result := np_green_tree.ParseGreenTree(ALexer, ADiagnostics, ARootFileId, AAllocator);
end;

end.
