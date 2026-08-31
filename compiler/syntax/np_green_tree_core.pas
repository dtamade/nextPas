unit np_green_tree_core;

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
  TGreenTree = class;

  { TGreenNode - rowan-style value type, single source }
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
  public
    procedure AppendChild(const AChild: TGreenNode);
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
    { Explicit tree — 单一真源，零全局依赖 }
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
  public
    { Storage fields — public to allow rowan-style parser inc shared across
      facade/core split without friend-unit hacks. Encapsulation via Freeze(). }
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
    procedure AppendInterfaceUse(const AUseName: string);
    procedure AppendImplementationUse(const AUseName: string);
    procedure AppendForeignProcedureDecl(
      const AForeignProcedureDecl: TForeignProcedureDecl
    );
    procedure CheckMutable; inline;
  public
    constructor Create; overload;
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

var
  ActiveExpressionTree: TGreenTree = nil;

function GreenNodeKindLabel(const AKind: TGreenNodeKind): string;
function GreenNodeIsNil(const ANode: TGreenNode): Boolean;
function NilGreenNode: TGreenNode; inline;

implementation

uses
  nextpas.core.text.conv;

function RootKeywordLabel(const AKind: TGreenRootKind): string; forward;
function GreenNodeKindFromRootKind(const AKind: TGreenRootKind): TGreenNodeKind; forward;
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
    gnkEnumType: Result := 'enum-type';
    gnkClassField: Result := 'class-field';
    gnkClassMethod: Result := 'class-method';
    gnkClassProperty: Result := 'class-property';
    gnkVisibilityLabel: Result := 'visibility-label';
    gnkTypeParamList: Result := 'type-param-list';
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

function RootKeywordLabel(const AKind: TGreenRootKind): string;
begin
  case AKind of
    grkProgram: Result := 'program';
    grkUnit: Result := 'unit';
    grkLibrary: Result := 'library';
    grkPackage: Result := 'package';
  else
    Result := 'unknown';
  end;
end;

function GreenNodeKindFromRootKind(const AKind: TGreenRootKind): TGreenNodeKind;
begin
  case AKind of
    grkProgram: Result := gnkProgram;
    grkUnit: Result := gnkUnit;
    grkLibrary: Result := gnkLibrary;
    grkPackage: Result := gnkPackage;
  else
    Result := gnkUnknown;
  end;
end;

{ Keep original helpers local to this unit for GreenNodeKindLabel etc. }
function GreenNodeIsNil(const ANode: TGreenNode): Boolean;
begin
  Result := ANode.IsNil;
end;

function NilGreenNode: TGreenNode; inline;
begin
  Result.FOwner := nil;
  Result.FIndex := -1;
end;

{ TGreenTree storage }
procedure TGreenTree.CheckMutable;
begin
  Assert(not FFrozen, 'TGreenTree: attempt to mutate frozen tree');
end;

procedure TGreenTree.Freeze;
begin
  FFrozen := True;
end;

procedure TGreenTree.AppendInterfaceUse(const AUseName: string);
begin
  FInterfaceUses.Push(AUseName);
end;

procedure TGreenTree.AppendImplementationUse(const AUseName: string);
begin
  FImplementationUses.Push(AUseName);
end;

procedure TGreenTree.AppendForeignProcedureDecl(
  const AForeignProcedureDecl: TForeignProcedureDecl
);
begin
  FForeignProcedureDecls.Push(AForeignProcedureDecl);
end;

function TGreenTree.RootKindName: string;
begin
  Result := RootKeywordLabel(FRootKind);
end;

function TGreenTree.InterfaceUseCount: LongInt;
begin
  Result := LongInt(FInterfaceUses.Count);
end;

function TGreenTree.InterfaceUseAt(const AIndex: LongInt): string;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FInterfaceUses.Count)) then
    Exit('');
  Result := FInterfaceUses[AIndex];
end;

function TGreenTree.ImplementationUseCount: LongInt;
begin
  Result := LongInt(FImplementationUses.Count);
end;

function TGreenTree.ImplementationUseAt(const AIndex: LongInt): string;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FImplementationUses.Count)) then
    Exit('');
  Result := FImplementationUses[AIndex];
end;

function TGreenTree.ForeignProcedureDeclCount: LongInt;
begin
  Result := LongInt(FForeignProcedureDecls.Count);
end;

function TGreenTree.ForeignProcedureDeclAt(
  const AIndex: LongInt
): TForeignProcedureDecl;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FForeignProcedureDecls.Count)) then
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

constructor TGreenNode.Create(
  const ANodeKind: TGreenNodeKind;
  const AByteOffset: LongInt;
  const AByteLength: LongInt;
  const AText: string
);
begin
  if ActiveExpressionTree = nil then
  begin
    FOwner := nil;
    FIndex := -1;
    Exit;
  end;
  Self := TGreenNode.Create(ActiveExpressionTree, ANodeKind, AByteOffset, AByteLength, AText);
end;

constructor TGreenNode.Create(
  const ATree: TGreenTree;
  const ANodeKind: TGreenNodeKind;
  const AByteOffset: LongInt;
  const AByteLength: LongInt;
  const AText: string
);
var
  Data: TGreenNodeData;
  Idx: LongInt;
begin
  if (ATree = nil) or ATree.IsFrozen then
  begin
    FOwner := nil;
    FIndex := -1;
    Exit;
  end;
  FOwner := ATree;
  Data.Kind := ANodeKind;
  Data.ByteOffset := AByteOffset;
  Data.ByteLength := AByteLength;
  Data.TextStart := Length(FOwner.FNodeText);
  Data.TextLen := Length(AText);
  Data.ChildStart := -1;
  Data.ChildCount := 0;
  Data.ChildCapacity := 0;
  FOwner.FNodeText := FOwner.FNodeText + AText;
  Idx := FOwner.FNodes.Count;
  FOwner.FNodes.Push(Data);
  FIndex := Idx;
  FOwner.FFacades.Push(Self);
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
  ExistingChildIndex: LongInt;
  NewChildCapacity: LongInt;
  NewChildStart: LongInt;
  OldChildStart: LongInt;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count)
    or (AChild = nil) then
    Exit;
  if (AChild.FOwner = FOwner) and (AChild.FIndex = FIndex) then
    Exit;
  FOwner.CheckMutable;
  D := FOwner.FNodes[FIndex];
  if D.ChildCount >= D.ChildCapacity then
  begin
    OldChildStart := D.ChildStart;
    if D.ChildCapacity = 0 then
      NewChildCapacity := 1
    else
      NewChildCapacity := D.ChildCapacity * 2;
    NewChildStart := FOwner.FChildIndices.Count;
    for ExistingChildIndex := 0 to NewChildCapacity - 1 do
      FOwner.FChildIndices.Push(-1);
    for ExistingChildIndex := 0 to D.ChildCount - 1 do
      FOwner.FChildIndices[NewChildStart + ExistingChildIndex] :=
        FOwner.FChildIndices[OldChildStart + ExistingChildIndex];
    D.ChildStart := NewChildStart;
    D.ChildCapacity := NewChildCapacity;
  end;
  FOwner.FChildIndices[D.ChildStart + D.ChildCount] := AChild.FIndex;
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
  ChildLinkIndex: LongInt;
  ChildNodeIndex: LongInt;
begin
  if (FOwner = nil) or (FIndex < 0) or (FIndex >= FOwner.FNodes.Count) then
    Exit(nil);
  D := FOwner.FNodes[FIndex];
  if (AIndex < 0) or (AIndex >= D.ChildCount) or (D.ChildStart < 0) then
    Exit(nil);
  ChildLinkIndex := D.ChildStart + AIndex;
  if (ChildLinkIndex >= 0) and
    (ChildLinkIndex < FOwner.FChildIndices.Count) then
  begin
    ChildNodeIndex := FOwner.FChildIndices[ChildLinkIndex];
    if (ChildNodeIndex < 0) or (ChildNodeIndex >= FOwner.FFacades.Count) then
      Exit(nil);
    Result := FOwner.FFacades[ChildNodeIndex];
    if (Result <> nil) and (Result.FOwner = FOwner) and (Result.FIndex = FIndex) then
      Result := nil;
  end
  else
    Result := nil;
end;

end.
