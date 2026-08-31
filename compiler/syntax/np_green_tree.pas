unit np_green_tree;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$UNITPATH .}
{$UNITPATH ../diagnostics}
{$UNITPATH ../frontend}

interface

uses
  np_green_tree_base,
  np_diagnostics_sink, np_lexer, np_source_database,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

type
  { Forward declarations for rowan-style internal storage }
  TGreenTree = class;

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
    { Explicit tree — 单一真源，零全局依赖，推荐新代码使用 }
    constructor Create(
      const ATree: TGreenTree;
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

  TGreenStringVec = specialize TVec<string>;
  TGreenForeignProcVec = specialize TVec<TForeignProcedureDecl>;

 TGreenTree = class
 private
   FRootKind: TGreenRootKind;
   FDeclaredName: string;
   FNodeCount: LongInt;
   FIsValid: Boolean;
   FFrozen: Boolean;
   FInterfaceUses: TGreenStringVec;
   FImplementationUses: TGreenStringVec;
   FForeignProcedureDecls: TGreenForeignProcVec;
   FRootNode: TGreenNode;
   { Rowan-style compact storage: FNodes[i] <-> FFacades[i] strictly 1:1. }
   FNodes: specialize TVec<TGreenNodeData>;
   FNodeText: string;
   FFacades: specialize TVec<TGreenNode>;
   FChildIndices: specialize TVec<LongInt>;
   { Allocate node data and facade in the tree. Returns facade. }
   procedure AppendInterfaceUse(const AUseName: string);
   procedure AppendImplementationUse(const AUseName: string);
   procedure AppendForeignProcedureDecl(
     const AForeignProcedureDecl: TForeignProcedureDecl
   );
   procedure CheckMutable; inline;
 public
   constructor Create; overload;
   {** Node + uses/foreign metadata via IAllocator (e.g. session FAstAllocator). }
   constructor Create(const AAllocator: IAllocator); overload;
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

constructor TGreenTree.Create;
begin
  Create(nil);
end;

constructor TGreenTree.Create(const AAllocator: IAllocator);
begin
  inherited Create;
  FRootKind := grkUnknown;
  FDeclaredName := '';
  FNodeCount := 0;
  FIsValid := False;
  FFrozen := False;
  FRootNode := nil;
  if AAllocator <> nil then
  begin
    FInterfaceUses := TGreenStringVec.Create(0, AAllocator);
    FImplementationUses := TGreenStringVec.Create(0, AAllocator);
    FForeignProcedureDecls := TGreenForeignProcVec.Create(0, AAllocator);
    FNodes := specialize TVec<TGreenNodeData>.Create(0, AAllocator);
    FFacades := specialize TVec<TGreenNode>.Create(0, AAllocator);
    FChildIndices := specialize TVec<LongInt>.Create(0, AAllocator);
  end
  else
  begin
    FInterfaceUses := TGreenStringVec.Create;
    FImplementationUses := TGreenStringVec.Create;
    FForeignProcedureDecls := TGreenForeignProcVec.Create;
    FNodes := specialize TVec<TGreenNodeData>.Create;
    FFacades := specialize TVec<TGreenNode>.Create;
    FChildIndices := specialize TVec<LongInt>.Create;
  end;
  FNodeText := '';
end;

destructor TGreenTree.Destroy;
begin
  FChildIndices.Free;
  FFacades.Free;
  FNodes.Free;
  FForeignProcedureDecls.Free;
  FImplementationUses.Free;
  FInterfaceUses.Free;
  inherited Destroy;
end;

{$I np_green_tree_core.inc}
end.
