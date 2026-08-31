unit nextpas.compiler.syntax.green_tree;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$UNITPATH .}

interface

uses
<<<<<<<< HEAD:compiler/syntax/np_green_tree.pas
  nextpas.compiler.syntax.green_tree,
  np_lexer, np_diagnostics_sink, np_source_database,
  nextpas.core.mem.intf;
========
  nextpas.compiler.diagnostics.sink, nextpas.compiler.syntax.lexer, nextpas.compiler.frontend.source_database,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;
>>>>>>>> codex/compiler-system:compiler/src/nextpas.compiler.syntax.green_tree.pas

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

<<<<<<<< HEAD:compiler/syntax/np_green_tree.pas
function ParseGreenTree(const ALexer: TLexerResult; const ADiagnostics: TDiagnosticsSink; const ARootFileId: TSourceFileId): TGreenTree; overload; inline;
function ParseGreenTree(const ALexer: TLexerResult; const ADiagnostics: TDiagnosticsSink; const ARootFileId: TSourceFileId; const AAllocator: IAllocator): TGreenTree; overload; inline;
function GreenNodeKindLabel(const AKind: TGreenNodeKind): string; inline;
function GreenNodeIsNil(const ANode: TGreenNode): Boolean; inline;
========
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
   * 32 bytes per node, stored contiguously in TVec.
   * Text is centralized in TGreenTreeData.Text.
   * Children referenced by a range in TGreenTree.FChildIndices.
   *}
  TGreenNodeData = packed record
    Kind: TGreenNodeKind;
    ByteOffset: LongInt;
    ByteLength: LongInt;
    TextStart: LongInt;
    TextLen: LongInt;
    ChildStart: LongInt;
    ChildCount: LongInt;
    ChildCapacity: LongInt;
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
    { Zero-allocation text accessors: TextLen mirrors GetText's validity
      rules without materializing the substring; TextEquals compares in
      place (AIgnoreCase folds ASCII 'A'..'Z' — same table semantics as
      nextpas.core.text SameText). }
    function TextLen: LongInt;
    function TextEquals(const AValue: string; AIgnoreCase: Boolean = False): Boolean;
    { Zero-copy membership probe: index of ANode among Self's children, or
      -1. Mirrors ChildAt traversal (including the cyclic self-child skip)
      without materializing facade records. }
    function ChildIndexOf(const ANode: TGreenNode): LongInt;
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
>>>>>>>> codex/compiler-system:compiler/src/nextpas.compiler.syntax.green_tree.pas
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
