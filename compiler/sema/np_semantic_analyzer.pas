unit np_semantic_analyzer;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../diagnostics}
{$UNITPATH ../frontend}
{$UNITPATH ../syntax}

interface

uses
  np_ast_facade, np_diagnostics_sink, np_source_database, np_unit_graph,
  np_semantic_model, np_green_tree, np_lexer;

type
  TProcedureBodyEntry = record
    Name: string;
    Body: TGreenNode;
    Decl: TGreenNode;
    OwnerUnitId: string;
    ScopeId: LongInt;
  end;

  TParamSnapshot = record
    Name: string;
    HadValue: Boolean;
    PriorValue: Int64;
  end;
  TParamSnapshots = array of TParamSnapshot;

  TSemanticAnalyzer = class
  private
    FRootAst: TAstFacade;
    FUnitGraph: TUnitGraph;
    FDiagnostics: TDiagnosticsSink;
    FRootFileId: TSourceFileId;
    FNoFold: Boolean;
    FModel: TSemanticModel;
    FProcedureBodies: array of TProcedureBodyEntry;
    FInliningStack: array of string;
    FBlockLabelCounter: LongInt;
    FCurrentBlockTerminated: Boolean;
    FCurrentScopeId: LongInt;
    FBreakLabels: array of string;
    FContinueLabels: array of string;
    FRuntimeVarNames: array of string;
    FRuntimeStrVarNames: array of string;
    FRuntimeArrVarNames: array of string;
    FCurrentMethodClass: string;
    FCurrentRetVarName: string;
    FClassVarNames: array of string;
    FClassVarTypes: array of string;
    FRecordVarNames: array of string;
    FRecordVarTypes: array of string;
    FVarParamNames: array of string;
    FPtrReturnFuncs: array of string;
    FPtrReturnTypes: array of string;
    procedure RegisterRuntimeVar(const AName: string);
    procedure RegisterRuntimeStrVar(const AName: string);
    procedure RegisterRuntimeArrVar(const AName: string);
    procedure RegisterClassVar(const AName, AClassName: string);
    procedure RegisterRecordVar(const AName, ATypeName: string);
    procedure RegisterVarParam(const AName: string);
    procedure RegisterPtrReturnFunc(const AName, AClassName: string);
    function IsRuntimeVar(const AName: string): Boolean;
    function IsRuntimeStrVar(const AName: string): Boolean;
    function IsRuntimeArrVar(const AName: string): Boolean;
    function IsRecordVar(const AName: string): Boolean;
    function IsVarParam(const AName: string): Boolean;
    function IsVarParamAtPosition(const ADecl: TGreenNode; APosition: LongInt): Boolean;
    function LookupClassVar(const AName: string): string;
    function LookupRecordVar(const AName: string): string;
    function LookupPtrReturnFunc(const AName: string): string;
    function EmitStrConcatOperand(const ANode: TGreenNode;
      const ADestVar: string): string;
    function EncodeStrCallArgs(const ACallNode: TGreenNode;
      const ADestVar: string): string;
    function NewBlockLabel(const APrefix: string): string;
    procedure EmitBlockLabel(const ALabel: string);
    procedure EmitGotoLabel(const ALabel: string);
    procedure RegisterProcedureBody(const AName: string;
      const ABody: TGreenNode; const ADecl: TGreenNode;
      const AOwnerUnitId: string);
    function ProcedureBodyScopeIdForDecl(const ADecl: TGreenNode): LongInt;
    function ParamDeclTypeId(const AParamDecl: TGreenNode;
      const AOwnerUnitId: string): LongInt;
    function LookupProcedureBody(const AName: string;
      out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
    function LookupCallBindingDeclaration(const AName: string;
      const AArgCount: LongInt; const AArgSignature: string;
      const AHasArgSignature: Boolean;
      const AHasTypeMismatchEvidence: Boolean;
      out AResolutionFailureKind: string;
      out ABody: TGreenNode;
      out ADecl: TGreenNode; out AOwnerUnitId: string): Boolean;
    function OwnerUnitAllowsProjectSourceDiagnostic(
      const AOwnerUnitId: string
    ): Boolean;
    function HasInstalledSourceImports: Boolean;
    function IsCurrentlyInlining(const AName: string): Boolean;
    procedure PushInlining(const AName: string);
    procedure PopInlining;
    function CountDeclParams(const ADecl: TGreenNode): LongInt;
    function CountRequiredDeclParams(const ADecl: TGreenNode): LongInt;
    function DeclAcceptsArgCount(const ADecl: TGreenNode;
      const AArgCount: LongInt): Boolean;
    function DeclParamSignatureMatchesArgs(const ADecl: TGreenNode;
      const AArgSignature: string; const AArgCount: LongInt): Boolean;
    function GetParamSignature(const ADecl: TGreenNode): string;
    function MangledName(const AName: string; AParamCount: LongInt): string;
    function MangledNameSig(const AName: string; const ASig: string): string;
    function HasOverload(const AName: string): Boolean;
    function LookupOverload(const AName: string; AArgCount: LongInt;
      out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
    function CallArgumentCount(const ACallNode: TGreenNode): LongInt;
    function BareCallCalleeName(const ACallNode: TGreenNode): string;
    function IsWrappedCallChild(
      const AParent: TGreenNode;
      const AChild: TGreenNode
    ): Boolean;
    function IsQualifiedCallNode(const ACallNode: TGreenNode): Boolean;
    function ExtractDirectMemberCall(
      const ACallNode: TGreenNode;
      out AReceiverName: string;
      out AMemberName: string;
      out AMemberOffset: LongInt;
      out AArgCount: LongInt
    ): Boolean;
    function TypeIdForVariable(const AName: string): LongInt;
    function TypeIdForMemberReceiver(
      const AName: string;
      const ACurrentMethodClass: string;
      const ACurrentOwnerUnitId: string
    ): LongInt;
    function TypeSymbolForTypeId(
      const ATypeId: LongInt;
      out ASymbol: TSemanticSymbol
    ): Boolean;
    function ClassTypeHasKnownNonMethodMember(
      const AClassTypeId: LongInt;
      const AMemberName: string
    ): Boolean;
    function TypeIdHasKnownClassLayout(const ATypeId: LongInt): Boolean;
    function IsDeferredSystemObjectMember(const AMemberName: string): Boolean;
    function TypeSignatureForTypeId(const ATypeId: LongInt): string;
    function TypeIdHasStableScalarFact(const ATypeId: LongInt): Boolean;
    function CallArgumentSignature(
      const ACallNode: TGreenNode;
      out ASignature: string
    ): Boolean;
    function ExpressionTypeFactIsStable(const ANode: TGreenNode): Boolean;
    function CallArgumentSignatureIsStable(
      const ACallNode: TGreenNode
    ): Boolean;
    function MethodSymbolIdForExactClassTypeMember(
      const AClassTypeId: LongInt;
      const AMemberName: string;
      const AArgCount: LongInt;
      const AArgSignature: string;
      const AHasArgSignature: Boolean;
      const AHasTypeMismatchEvidence: Boolean;
      const AAllowNoMatchingOverloadDiagnostic: Boolean;
      out AMethodNameFound: Boolean;
      out AResolutionFailureKind: string
    ): LongInt;
    function MethodSymbolIdForClassTypeMember(
      const AClassTypeId: LongInt;
      const AMemberName: string;
      const AArgCount: LongInt;
      const AArgSignature: string;
      const AHasArgSignature: Boolean;
      const AHasTypeMismatchEvidence: Boolean;
      out AResolutionFailureKind: string
    ): LongInt;
    function TryRegisterMemberCallBinding(
      const ACallNode: TGreenNode;
      const ACurrentMethodClass: string;
      const ACurrentOwnerUnitId: string;
      out AResolutionFailureKind: string;
      out AFailureName: string;
      out AFailureOffset: LongInt
    ): Boolean;
    function TryRegisterImplicitSelfBareMethodCallBinding(
      const ACallNode: TGreenNode;
      const ACurrentMethodClass: string;
      const ACurrentOwnerUnitId: string;
      out AResolutionFailureKind: string;
      out AFailureName: string;
      out AFailureOffset: LongInt
    ): Boolean;
    function BindCallArgs(const ADecl: TGreenNode;
      const ACallNode: TGreenNode;
      const ANameSkip: LongInt): TParamSnapshots;
    procedure RestoreCallArgs(const ASnapshots: TParamSnapshots);
    function EnsureUnitScope(const AOwnerUnitId: string): LongInt;
    function CallableSymbolIdForDeclaration(const ADecl: TGreenNode;
      const AOwnerUnitId: string): LongInt;
    procedure RegisterCallBinding(const ACallNode: TGreenNode;
      const ADecl: TGreenNode; const AOwnerUnitId: string);
    procedure SeedCallBindings;
    procedure SeedCallBindingsInNode(
      const ANode: TGreenNode;
      const ACurrentMethodClass: string;
      const ACurrentOwnerUnitId: string
    );
    function DuplicateImportName: string;
    procedure EmitSemaError(
      const ACode: string;
      const AMessage: string;
      const AByteOffset: LongInt
    );
    function IsSimpleIdentifierName(const AName: string): Boolean;
    function RegisterSymbol(
      const AName: string;
      const AKind: string;
      const AOwnerUnitId: string;
      const ATypeId: LongInt;
      const AByteOffset: LongInt
    ): LongInt;
    function IsBuiltinProcedure(const AName: string): Boolean;
    function InferExpressionType(const ANode: TGreenNode): LongInt;
    function AreTypesCompatible(const ALhsTypeId, ARhsTypeId: LongInt): Boolean;
    procedure SeedBuiltinTypes;
    procedure AssignScopesToSymbols;
    procedure CheckDuplicateDeclarations;
    procedure CheckUndeclaredIdentifiers;
    procedure CheckIdentifiersInNode(const ANode: TGreenNode);
    procedure CheckTypeMismatches;
    procedure CheckTypeMismatchesInNode(const ANode: TGreenNode);
    procedure CheckUnusedSymbols;
    procedure CheckUnreachableCode;
    procedure CheckUnreachableInNode(const ANode: TGreenNode;
      var ATerminated: Boolean);
    procedure CheckDuplicateCaseLabels;
    procedure CheckCaseLabelsInNode(const ANode: TGreenNode);
    procedure SeedDeclarations;
    procedure CheckAssignmentTypes;
    procedure SeedUnitSymbolsAndHir;
    procedure SeedForeignProcedureBindings;
    procedure SeedRuntimeContracts;
    function ResolveTypeId(const ATypeName: string): LongInt;
    function ResolveTypeIdForOwner(
      const ATypeName: string;
      const APreferredOwnerUnitId: string
    ): LongInt;
    function ImplicitSystemObjectParentTypeId(const AClassName: string): LongInt;
    function FindSymbolByName(const AName: string): LongInt;
    procedure ProcessVarSection(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure ProcessConstSection(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure ProcessProcedureDecl(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure ProcessFunctionDecl(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure ProcessTypeSection(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure ProcessEnumType(const ANode: TGreenNode;
      const AOwnerUnitId: string; const ATypeId: LongInt);
    procedure ProcessRecordFields(const ANode: TGreenNode;
      const AOwnerUnitId: string; const ATypeId: LongInt);
    procedure ProcessClassFields(const ANode: TGreenNode;
      const AOwnerUnitId: string; const ATypeId: LongInt);
    procedure WalkDeclarations(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure WalkAssignmentStatements(const ANode: TGreenNode);
    procedure UnrollAssignmentForLoop(const ANode: TGreenNode);
    procedure UnrollAssignmentWhileLoop(const ANode: TGreenNode);
    procedure UnrollAssignmentRepeatLoop(const ANode: TGreenNode);
    function EvaluateIntegerConstant(const ANode: TGreenNode;
      out AValue: Int64): Boolean;
    function EvaluateStringConstant(const ANode: TGreenNode;
      out AValue: string): Boolean;
    procedure WalkHaltCalls(const ANode: TGreenNode);
    function EncodeRuntimeIntExprFold(const ANode: TGreenNode;
      out ABlob: string): Boolean;
    function EncodeRuntimeBoolExprFold(const ANode: TGreenNode;
      out ABlob: string): Boolean;
    procedure LowerRuntimeIfStatement(
      const AIfNode: TGreenNode; const ACondBlob: string);
    procedure LowerRuntimeWhileStatement(const ANode: TGreenNode);
    procedure LowerRuntimeForStatement(const ANode: TGreenNode);
    procedure LowerRuntimeRepeatStatement(const ANode: TGreenNode);
    procedure LowerRuntimeCaseStatement(const ANode: TGreenNode);
    procedure UnrollHaltForLoop(const ANode: TGreenNode);
    procedure UnrollHaltWhileLoop(const ANode: TGreenNode);
    procedure UnrollHaltRepeatLoop(const ANode: TGreenNode);
    procedure SeedRuntimeVarDecls;
    procedure WalkRuntimeVarDecls(const ANode: TGreenNode);
    procedure SeedHaltCalls;
    procedure PreRegisterFunctionReturnTypes;
    procedure SeedFunctionBodies;
    procedure SeedImportedUnitBodies;
  public
    constructor Create(
      const ARootAst: TAstFacade;
      const AUnitGraph: TUnitGraph;
      const ADiagnostics: TDiagnosticsSink;
      const ARootFileId: TSourceFileId;
      const ANoFold: Boolean
    );
    destructor Destroy; override;
    procedure Analyze;
    function DetachModel: TSemanticModel;
    function Status: string;
  end;

implementation

uses
  SysUtils;

type
  TStringArray = array of string;

function ContainsString(
  const AItems: TStringArray;
  const AValue: string
): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to Length(AItems) - 1 do
    if AItems[Index] = AValue then
      Exit(True);

  Result := False;
end;

procedure AppendString(var AItems: TStringArray; const AValue: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(AItems);
  SetLength(AItems, NextIndex + 1);
  AItems[NextIndex] := AValue;
end;

function DecodePascalStringLiteral(const AText: string): string; forward;

constructor TSemanticAnalyzer.Create(
  const ARootAst: TAstFacade;
  const AUnitGraph: TUnitGraph;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const ANoFold: Boolean
);
begin
  inherited Create;
  FRootAst := ARootAst;
  FUnitGraph := AUnitGraph;
  FDiagnostics := ADiagnostics;
  FRootFileId := ARootFileId;
  FNoFold := ANoFold;
  FModel := TSemanticModel.Create;
  FBlockLabelCounter := 0;
  FCurrentScopeId := 0;
end;

function TSemanticAnalyzer.NewBlockLabel(const APrefix: string): string;
begin
  Inc(FBlockLabelCounter);
  Result := APrefix + IntToStr(FBlockLabelCounter);
end;

procedure TSemanticAnalyzer.RegisterRuntimeVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  for Idx := 0 to Length(FRuntimeVarNames) - 1 do
    if SameText(FRuntimeVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FRuntimeVarNames);
  SetLength(FRuntimeVarNames, NextIndex + 1);
  FRuntimeVarNames[NextIndex] := AName;
end;

function TSemanticAnalyzer.IsRuntimeVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRuntimeVarNames) - 1 do
    if SameText(FRuntimeVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemanticAnalyzer.RegisterRuntimeStrVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  for Idx := 0 to Length(FRuntimeStrVarNames) - 1 do
    if SameText(FRuntimeStrVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FRuntimeStrVarNames);
  SetLength(FRuntimeStrVarNames, NextIndex + 1);
  FRuntimeStrVarNames[NextIndex] := AName;
end;

function TSemanticAnalyzer.IsRuntimeStrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRuntimeStrVarNames) - 1 do
    if SameText(FRuntimeStrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemanticAnalyzer.RegisterRuntimeArrVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  for Idx := 0 to Length(FRuntimeArrVarNames) - 1 do
    if SameText(FRuntimeArrVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FRuntimeArrVarNames);
  SetLength(FRuntimeArrVarNames, NextIndex + 1);
  FRuntimeArrVarNames[NextIndex] := AName;
end;

function TSemanticAnalyzer.IsRuntimeArrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRuntimeArrVarNames) - 1 do
    if SameText(FRuntimeArrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemanticAnalyzer.RegisterClassVar(const AName, AClassName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FClassVarNames) - 1 do
    if SameText(FClassVarNames[Idx], AName) then
    begin
      FClassVarTypes[Idx] := AClassName;
      Exit;
    end;
  Idx := Length(FClassVarNames);
  SetLength(FClassVarNames, Idx + 1);
  SetLength(FClassVarTypes, Idx + 1);
  FClassVarNames[Idx] := AName;
  FClassVarTypes[Idx] := AClassName;
end;

function TSemanticAnalyzer.LookupClassVar(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FClassVarNames) - 1 do
    if SameText(FClassVarNames[Idx], AName) then
      Exit(FClassVarTypes[Idx]);
  Result := '';
end;

procedure TSemanticAnalyzer.RegisterRecordVar(const AName, ATypeName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRecordVarNames) - 1 do
    if SameText(FRecordVarNames[Idx], AName) then
    begin
      FRecordVarTypes[Idx] := ATypeName;
      Exit;
    end;
  Idx := Length(FRecordVarNames);
  SetLength(FRecordVarNames, Idx + 1);
  SetLength(FRecordVarTypes, Idx + 1);
  FRecordVarNames[Idx] := AName;
  FRecordVarTypes[Idx] := ATypeName;
end;

function TSemanticAnalyzer.IsRecordVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRecordVarNames) - 1 do
    if SameText(FRecordVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemanticAnalyzer.RegisterVarParam(const AName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FVarParamNames) - 1 do
    if SameText(FVarParamNames[Idx], AName) then
      Exit;
  Idx := Length(FVarParamNames);
  SetLength(FVarParamNames, Idx + 1);
  FVarParamNames[Idx] := AName;
end;

function TSemanticAnalyzer.IsVarParam(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FVarParamNames) - 1 do
    if SameText(FVarParamNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemanticAnalyzer.IsVarParamAtPosition(
  const ADecl: TGreenNode; APosition: LongInt): Boolean;
var
  J, K, ParamIdx: LongInt;
  Child, ParamChild: TGreenNode;
begin
  Result := False;
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      ParamIdx := 0;
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild = nil) or (ParamChild.NodeKind <> gnkParameterDecl) then
          Continue;
        if ParamIdx = APosition then
        begin
          Result := (Length(ParamChild.Text) > 4) and
            (Copy(ParamChild.Text, 1, 4) = 'var:');
          Exit;
        end;
        Inc(ParamIdx);
      end;
      Exit;
    end;
  end;
end;

function TSemanticAnalyzer.LookupRecordVar(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRecordVarNames) - 1 do
    if SameText(FRecordVarNames[Idx], AName) then
      Exit(FRecordVarTypes[Idx]);
  Result := '';
end;

procedure TSemanticAnalyzer.RegisterPtrReturnFunc(const AName, AClassName: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FPtrReturnFuncs);
  SetLength(FPtrReturnFuncs, NextIndex + 1);
  SetLength(FPtrReturnTypes, NextIndex + 1);
  FPtrReturnFuncs[NextIndex] := AName;
  FPtrReturnTypes[NextIndex] := AClassName;
end;

function TSemanticAnalyzer.LookupPtrReturnFunc(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FPtrReturnFuncs) - 1 do
    if SameText(FPtrReturnFuncs[Idx], AName) then
      Exit(FPtrReturnTypes[Idx]);
  Result := '';
end;

function TSemanticAnalyzer.EmitStrConcatOperand(const ANode: TGreenNode;
  const ADestVar: string): string;
var
  TempName, LitValue: string;
  FieldIdx: Int64;
begin
  Result := '';
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkIdentifier) and IsRuntimeStrVar(ANode.Text) then
    Exit(ANode.Text);
  if (ANode.NodeKind = gnkIdentifier) and (FCurrentMethodClass <> '') and
    FModel.LookupConstValue(
      FCurrentMethodClass + '.' + ANode.Text + '$str', FieldIdx) and
    FModel.LookupConstValue(
      FCurrentMethodClass + '.' + ANode.Text + '$idx', FieldIdx) then
  begin
    Inc(FBlockLabelCounter);
    TempName := '$str_tmp_' + IntToStr(FBlockLabelCounter);
    RegisterRuntimeVar(TempName);
    RegisterRuntimeStrVar(TempName);
    FModel.AddTypedHirNode('var-decl-str-runtime', TempName, 0, 0, TempName);
    FModel.AddTypedHirNode(
      'assign-str-field-load-runtime', TempName, 0, 0,
      TempName + #9 + IntToStr(FieldIdx)
    );
    Exit(TempName);
  end;
  if ANode.NodeKind = gnkStringLiteral then
    LitValue := DecodePascalStringLiteral(ANode.Text)
  else if not EvaluateStringConstant(ANode, LitValue) then
    Exit;
  Inc(FBlockLabelCounter);
  TempName := '$str_tmp_' + IntToStr(FBlockLabelCounter);
  RegisterRuntimeVar(TempName);
  RegisterRuntimeStrVar(TempName);
  FModel.AddTypedHirNode('var-decl-str-runtime', TempName, 0, 0, TempName);
  FModel.AddTypedHirNode('assign-str-runtime', LitValue, 0, 0, TempName);
  Result := TempName;
end;

function TSemanticAnalyzer.EncodeStrCallArgs(const ACallNode: TGreenNode;
  const ADestVar: string): string;
var
  ArgIndex: LongInt;
  ArgNode: TGreenNode;
  Blob, LitValue: string;
begin
  Result := '';
  ArgIndex := 0;
  if ACallNode.NodeKind = gnkFunctionCall then
    ArgIndex := 1;
  while ArgIndex < ACallNode.ChildCount do
  begin
    ArgNode := ACallNode.ChildAt(ArgIndex);
    if ArgNode = nil then
    begin
      Inc(ArgIndex);
      Continue;
    end;
    if (ArgNode.NodeKind = gnkIdentifier) and IsRuntimeStrVar(ArgNode.Text) then
      Blob := 'strvar ' + ArgNode.Text + #10
    else if ArgNode.NodeKind = gnkStringLiteral then
    begin
      LitValue := DecodePascalStringLiteral(ArgNode.Text);
      Blob := EmitStrConcatOperand(ArgNode, ADestVar);
      if Blob <> '' then
        Blob := 'strvar ' + Blob + #10
      else
        Blob := '';
    end
    else if EncodeRuntimeIntExprFold(ArgNode, Blob) then
      { Blob already set }
    else
      Blob := '';
    if Blob <> '' then
    begin
      if Result <> '' then
        Result := Result + #9 + Blob
      else
        Result := Blob;
    end;
    Inc(ArgIndex);
  end;
end;

procedure TSemanticAnalyzer.EmitBlockLabel(const ALabel: string);
begin
  FModel.AddTypedHirNode('block-label-runtime', ALabel, 0, 0, ALabel);
  FCurrentBlockTerminated := False;
end;

procedure TSemanticAnalyzer.EmitGotoLabel(const ALabel: string);
begin
  if FCurrentBlockTerminated then
    Exit;
  FModel.AddTypedHirNode('br-runtime', ALabel, 0, 0, ALabel);
  FCurrentBlockTerminated := True;
end;

destructor TSemanticAnalyzer.Destroy;
begin
  FModel.Free;
  inherited Destroy;
end;

function TSemanticAnalyzer.DuplicateImportName: string;
var
  SeenImports: TStringArray;
  Index: LongInt;
  ImportName: string;
  ImportId: string;
begin
  SeenImports := nil;

  for Index := 0 to FRootAst.InterfaceUseCount - 1 do
  begin
    ImportName := FRootAst.InterfaceUseAt(Index);
    ImportId := NormalizeUnitIdentity(ImportName);
    if ContainsString(SeenImports, ImportId) then
      Exit(ImportName);
    AppendString(SeenImports, ImportId);
  end;

  for Index := 0 to FRootAst.ImplementationUseCount - 1 do
  begin
    ImportName := FRootAst.ImplementationUseAt(Index);
    ImportId := NormalizeUnitIdentity(ImportName);
    if ContainsString(SeenImports, ImportId) then
      Exit(ImportName);
    AppendString(SeenImports, ImportId);
  end;

  Result := '';
end;

function TSemanticAnalyzer.CountDeclParams(const ADecl: TGreenNode): LongInt;
var
  J, K: LongInt;
  Child, ParamChild: TGreenNode;
begin
  Result := 0;
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
          Inc(Result);
      end;
      Exit;
    end;
  end;
end;

function TSemanticAnalyzer.CountRequiredDeclParams(
  const ADecl: TGreenNode): LongInt;
var
  J, K: LongInt;
  Child, ParamChild: TGreenNode;
begin
  Result := 0;
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) and
          (ParamChild.ChildCount <= 1) then
          Inc(Result);
      end;
      Exit;
    end;
  end;
end;

function TSemanticAnalyzer.DeclAcceptsArgCount(const ADecl: TGreenNode;
  const AArgCount: LongInt): Boolean;
var
  MaxParamCount: LongInt;
  MinParamCount: LongInt;
begin
  MaxParamCount := CountDeclParams(ADecl);
  MinParamCount := CountRequiredDeclParams(ADecl);
  Result := (AArgCount >= MinParamCount) and (AArgCount <= MaxParamCount);
end;

function TSemanticAnalyzer.DeclParamSignatureMatchesArgs(
  const ADecl: TGreenNode;
  const AArgSignature: string;
  const AArgCount: LongInt
): Boolean;
var
  ParamSignature: string;
begin
  ParamSignature := GetParamSignature(ADecl);
  Result := (AArgCount >= 0) and (Length(ParamSignature) >= AArgCount) and
    SameText(Copy(ParamSignature, 1, AArgCount), AArgSignature);
end;

function TSemanticAnalyzer.GetParamSignature(const ADecl: TGreenNode): string;
var
  J, K: LongInt;
  Child, ParamChild, TypeChild: TGreenNode;
  TypeName: string;
  Dummy: Int64;
begin
  Result := '';
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild = nil) or (ParamChild.NodeKind <> gnkParameterDecl) then
          Continue;
        TypeName := '';
        TypeChild := nil;
        if ParamChild.ChildCount > 0 then
        begin
          TypeChild := ParamChild.ChildAt(0);
          if TypeChild <> nil then
            TypeName := LowerCase(TypeChild.Text);
        end;
        if (TypeName = 'string') or (TypeName = 'ansistring') then
          Result := Result + 's'
        else if (TypeName = 'boolean') or (TypeName = 'bool') then
          Result := Result + 'b'
        else if (TypeChild <> nil) and
          FModel.LookupConstValue(TypeChild.Text + '$record', Dummy) then
          Result := Result + 'r'
        else if (TypeChild <> nil) and
          FModel.LookupConstValue(TypeChild.Text + '$size', Dummy) then
          Result := Result + 'p'
        else
          Result := Result + 'i';
      end;
      Exit;
    end;
  end;
end;

function TSemanticAnalyzer.MangledName(const AName: string;
  AParamCount: LongInt): string;
begin
  if AParamCount = 0 then
    Result := AName
  else
    Result := AName + '$' + IntToStr(AParamCount);
end;

function TSemanticAnalyzer.MangledNameSig(const AName: string;
  const ASig: string): string;
begin
  if ASig = '' then
    Result := AName
  else
    Result := AName + '$' + ASig;
end;

procedure TSemanticAnalyzer.RegisterProcedureBody(const AName: string;
  const ABody: TGreenNode; const ADecl: TGreenNode;
  const AOwnerUnitId: string);
var
  Index: LongInt;
  NextIndex: SizeInt;
  Sig, ExistingSig: string;
begin
  Sig := GetParamSignature(ADecl);
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if SameText(FProcedureBodies[Index].Name, AName) and
      SameText(FProcedureBodies[Index].OwnerUnitId, AOwnerUnitId) then
    begin
      ExistingSig := GetParamSignature(FProcedureBodies[Index].Decl);
      if ExistingSig = Sig then
      begin
        FProcedureBodies[Index].Body := ABody;
        FProcedureBodies[Index].Decl := ADecl;
        FProcedureBodies[Index].OwnerUnitId := AOwnerUnitId;
        FProcedureBodies[Index].ScopeId := FCurrentScopeId;
        Exit;
      end;
    end;
  NextIndex := Length(FProcedureBodies);
  SetLength(FProcedureBodies, NextIndex + 1);
  FProcedureBodies[NextIndex].Name := AName;
  FProcedureBodies[NextIndex].Body := ABody;
  FProcedureBodies[NextIndex].Decl := ADecl;
  FProcedureBodies[NextIndex].OwnerUnitId := AOwnerUnitId;
  FProcedureBodies[NextIndex].ScopeId := FCurrentScopeId;
end;

function TSemanticAnalyzer.ProcedureBodyScopeIdForDecl(
  const ADecl: TGreenNode
): LongInt;
var
  Index: LongInt;
begin
  Result := 0;
  if ADecl = nil then
    Exit;
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if FProcedureBodies[Index].Decl = ADecl then
      Exit(FProcedureBodies[Index].ScopeId);
end;

function TSemanticAnalyzer.ParamDeclTypeId(
  const AParamDecl: TGreenNode;
  const AOwnerUnitId: string
): LongInt;
var
  TypeChild: TGreenNode;
begin
  Result := 0;
  if (AParamDecl = nil) or (AParamDecl.ChildCount <= 0) then
    Exit;
  TypeChild := AParamDecl.ChildAt(0);
  if (TypeChild = nil) or (TypeChild.NodeKind <> gnkIdentifier) then
    Exit;
  Result := ResolveTypeIdForOwner(TypeChild.Text, AOwnerUnitId);
end;

function TSemanticAnalyzer.LookupProcedureBody(const AName: string;
  out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
var
  Index: LongInt;
begin
  ABody := nil;
  ADecl := nil;
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if SameText(FProcedureBodies[Index].Name, AName) then
    begin
      ABody := FProcedureBodies[Index].Body;
      ADecl := FProcedureBodies[Index].Decl;
      Exit(True);
    end;
  Result := False;
end;

function TSemanticAnalyzer.HasOverload(const AName: string): Boolean;
var
  Index, Count: LongInt;
begin
  Count := 0;
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if SameText(FProcedureBodies[Index].Name, AName) then
      Inc(Count);
  Result := Count > 1;
end;

function TSemanticAnalyzer.LookupOverload(const AName: string;
  AArgCount: LongInt; out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
var
  Index: LongInt;
begin
  ABody := nil;
  ADecl := nil;
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if SameText(FProcedureBodies[Index].Name, AName) and
      DeclAcceptsArgCount(FProcedureBodies[Index].Decl, AArgCount) then
    begin
      ABody := FProcedureBodies[Index].Body;
      ADecl := FProcedureBodies[Index].Decl;
      Exit(True);
    end;
  Result := False;
end;

function TSemanticAnalyzer.LookupCallBindingDeclaration(
  const AName: string;
  const AArgCount: LongInt;
  const AArgSignature: string;
  const AHasArgSignature: Boolean;
  const AHasTypeMismatchEvidence: Boolean;
  out AResolutionFailureKind: string;
  out ABody: TGreenNode;
  out ADecl: TGreenNode;
  out AOwnerUnitId: string
): Boolean;
var
  Index: LongInt;
  ImportedDiagnosticMatchCount: LongInt;
  ImportedMatchCount: LongInt;
  ImportedMatchIndex: LongInt;
  ImportedDiagnosticNameCount: LongInt;
  ImportedNameCount: LongInt;
  ImportedDiagnosticSignatureMatchCount: LongInt;
  ImportedSignatureMatchCount: LongInt;
  ImportedSignatureMatchIndex: LongInt;
  KnownSymbolId: LongInt;
  RootMatchCount: LongInt;
  RootMatchIndex: LongInt;
  RootNameCount: LongInt;
  RootOwnerUnitId: string;
  RootSignatureMatchCount: LongInt;
  RootSignatureMatchIndex: LongInt;
begin
  ABody := nil;
  ADecl := nil;
  AOwnerUnitId := '';
  AResolutionFailureKind := '';
  ImportedDiagnosticMatchCount := 0;
  ImportedMatchCount := 0;
  ImportedMatchIndex := -1;
  ImportedDiagnosticNameCount := 0;
  ImportedDiagnosticSignatureMatchCount := 0;
  ImportedNameCount := 0;
  ImportedSignatureMatchCount := 0;
  ImportedSignatureMatchIndex := -1;
  RootMatchCount := 0;
  RootMatchIndex := -1;
  RootNameCount := 0;
  RootSignatureMatchCount := 0;
  RootSignatureMatchIndex := -1;
  RootOwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);

  for Index := 0 to Length(FProcedureBodies) - 1 do
    if SameText(FProcedureBodies[Index].Name, AName) then
    begin
      if SameText(FProcedureBodies[Index].OwnerUnitId, RootOwnerUnitId) then
      begin
        Inc(RootNameCount);
        if DeclAcceptsArgCount(FProcedureBodies[Index].Decl, AArgCount) then
        begin
          RootMatchIndex := Index;
          Inc(RootMatchCount);
          if AHasArgSignature and
            DeclParamSignatureMatchesArgs(
              FProcedureBodies[Index].Decl,
              AArgSignature,
              AArgCount
            ) then
          begin
            RootSignatureMatchIndex := Index;
            Inc(RootSignatureMatchCount);
          end;
        end;
      end
      else
      begin
        Inc(ImportedNameCount);
        if OwnerUnitAllowsProjectSourceDiagnostic(
          FProcedureBodies[Index].OwnerUnitId
        ) then
          Inc(ImportedDiagnosticNameCount);
        if DeclAcceptsArgCount(FProcedureBodies[Index].Decl, AArgCount) then
        begin
          ImportedMatchIndex := Index;
          Inc(ImportedMatchCount);
          if OwnerUnitAllowsProjectSourceDiagnostic(
            FProcedureBodies[Index].OwnerUnitId
          ) then
            Inc(ImportedDiagnosticMatchCount);
          if AHasArgSignature and
            DeclParamSignatureMatchesArgs(
              FProcedureBodies[Index].Decl,
              AArgSignature,
              AArgCount
            ) then
          begin
            ImportedSignatureMatchIndex := Index;
            Inc(ImportedSignatureMatchCount);
            if OwnerUnitAllowsProjectSourceDiagnostic(
              FProcedureBodies[Index].OwnerUnitId
            ) then
              Inc(ImportedDiagnosticSignatureMatchCount);
          end;
        end;
      end;
    end;

  if RootMatchCount > 0 then
  begin
    if RootMatchCount = 1 then
    begin
      if AHasArgSignature and
        (not DeclParamSignatureMatchesArgs(
          FProcedureBodies[RootMatchIndex].Decl,
          AArgSignature,
          AArgCount
        )) then
      begin
        if AHasTypeMismatchEvidence then
          AResolutionFailureKind := 'type-mismatch';
        Exit(False);
      end;
      RootSignatureMatchIndex := RootMatchIndex
    end
    else if (not AHasArgSignature) or (RootSignatureMatchCount > 1) then
    begin
      AResolutionFailureKind := 'ambiguous-overload';
      Exit(False);
    end
    else if RootSignatureMatchCount = 0 then
    begin
      if AHasTypeMismatchEvidence then
        AResolutionFailureKind := 'no-matching-overload';
      Exit(False);
    end;

    ABody := FProcedureBodies[RootSignatureMatchIndex].Body;
    ADecl := FProcedureBodies[RootSignatureMatchIndex].Decl;
    AOwnerUnitId := FProcedureBodies[RootSignatureMatchIndex].OwnerUnitId;
    Exit(True);
  end;

  if RootNameCount > 0 then
  begin
    AResolutionFailureKind := 'wrong-argument-count';
    Exit(False);
  end;

  if (RootNameCount = 0) and (ImportedNameCount = 0) then
  begin
    KnownSymbolId := FModel.LookupSymbol(AName, FCurrentScopeId);
    if IsSimpleIdentifierName(AName) and (KnownSymbolId = 0) and
      (FModel.FindTypeByName(AName) = 0) and
      (not IsBuiltinProcedure(AName)) and
      (not HasInstalledSourceImports) then
      AResolutionFailureKind := 'unknown-callable';
    Exit(False);
  end;

  if ImportedMatchCount = 0 then
  begin
    if ImportedDiagnosticNameCount > 0 then
      AResolutionFailureKind := 'wrong-argument-count';
    Exit(False);
  end;

  if ImportedMatchCount = 1 then
  begin
    if AHasArgSignature and
      (not DeclParamSignatureMatchesArgs(
        FProcedureBodies[ImportedMatchIndex].Decl,
        AArgSignature,
        AArgCount
      )) then
    begin
      if AHasTypeMismatchEvidence and
        OwnerUnitAllowsProjectSourceDiagnostic(
          FProcedureBodies[ImportedMatchIndex].OwnerUnitId
        ) then
        AResolutionFailureKind := 'type-mismatch';
      Exit(False);
    end;
    ImportedSignatureMatchIndex := ImportedMatchIndex
  end
  else if (not AHasArgSignature) or (ImportedSignatureMatchCount > 1) then
  begin
    if ((not AHasArgSignature) and (ImportedDiagnosticMatchCount > 1)) or
      (ImportedDiagnosticSignatureMatchCount > 1) then
      AResolutionFailureKind := 'ambiguous-overload';
    Exit(False);
  end
  else if ImportedSignatureMatchCount = 0 then
  begin
    if AHasTypeMismatchEvidence and
      (ImportedDiagnosticMatchCount = ImportedMatchCount) then
      AResolutionFailureKind := 'no-matching-overload';
    Exit(False);
  end;

  ABody := FProcedureBodies[ImportedSignatureMatchIndex].Body;
  ADecl := FProcedureBodies[ImportedSignatureMatchIndex].Decl;
  AOwnerUnitId := FProcedureBodies[ImportedSignatureMatchIndex].OwnerUnitId;
  Result := True;
end;

function TSemanticAnalyzer.OwnerUnitAllowsProjectSourceDiagnostic(
  const AOwnerUnitId: string
): Boolean;
var
  ResolvedUnit: TResolvedUnit;
begin
  Result := False;
  if Trim(AOwnerUnitId) = '' then
    Exit;
  if not FUnitGraph.FindUnit(AOwnerUnitId, ResolvedUnit) then
    Exit;
  Result := SameText(ResolvedUnit.OriginClass, 'project-source');
end;

function TSemanticAnalyzer.HasInstalledSourceImports: Boolean;
var
  Index: LongInt;
  ResolvedUnit: TResolvedUnit;
begin
  Result := False;
  for Index := 0 to FUnitGraph.ResolvedUnitCount - 1 do
  begin
    ResolvedUnit := FUnitGraph.ResolvedUnitAt(Index);
    if SameText(ResolvedUnit.OriginClass, 'installed-source') then
      Exit(True);
  end;
end;

function TSemanticAnalyzer.ExpressionTypeFactIsStable(
  const ANode: TGreenNode
): Boolean;
var
  Index: LongInt;
  RootOwnerUnitId: string;
  Sym: TSemanticSymbol;
  SymId: LongInt;
begin
  Result := False;
  if ANode = nil then
    Exit;

  case ANode.NodeKind of
    gnkIntegerLiteral, gnkRealLiteral, gnkStringLiteral, gnkCharLiteral:
      Exit(True);
    gnkIdentifier:
      begin
        if SameText(ANode.Text, 'True') or SameText(ANode.Text, 'False') then
          Exit(True);
        SymId := FModel.LookupSymbol(ANode.Text, FCurrentScopeId);
        if SymId <= 0 then
          Exit(False);
        Sym := FModel.SymbolAt(SymId - 1);
        if SameText(Sym.Kind, 'function') then
        begin
          RootOwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);
          Exit((Sym.ParamCount = 0) and
            SameText(Sym.OwnerUnitId, RootOwnerUnitId) and
            TypeIdHasStableScalarFact(Sym.TypeId));
        end
        else if (not SameText(Sym.Kind, 'variable')) and
          (not SameText(Sym.Kind, 'parameter')) then
          Exit(False);
        Exit(TypeIdHasStableScalarFact(Sym.TypeId));
      end;
    gnkFunctionCall:
      begin
        SymId := FModel.LookupSymbol(ANode.Text, FCurrentScopeId);
        if SymId <= 0 then
          Exit(False);
        Sym := FModel.SymbolAt(SymId - 1);
        RootOwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);
        Exit(SameText(Sym.Kind, 'function') and (Sym.ParamCount = 0) and
          SameText(Sym.OwnerUnitId, RootOwnerUnitId) and
          (ANode.ChildCount <= 1) and TypeIdHasStableScalarFact(Sym.TypeId));
      end;
    gnkBinaryExpression, gnkUnaryExpression:
      begin
        for Index := 0 to ANode.ChildCount - 1 do
          if not ExpressionTypeFactIsStable(ANode.ChildAt(Index)) then
            Exit(False);
        Exit(True);
      end;
  end;
end;

function TSemanticAnalyzer.CallArgumentSignatureIsStable(
  const ACallNode: TGreenNode
): Boolean;
var
  ArgRoot: TGreenNode;
  Index: LongInt;
begin
  Result := False;
  if ACallNode = nil then
    Exit;

  ArgRoot := ACallNode;
  if (ACallNode.NodeKind = gnkProcedureCallStatement) and
    (ACallNode.ChildCount > 0) and
    (ACallNode.ChildAt(0) <> nil) and
    (ACallNode.ChildAt(0).NodeKind = gnkFunctionCall) then
    ArgRoot := ACallNode.ChildAt(0);

  if ArgRoot.NodeKind <> gnkFunctionCall then
    Exit(True);

  for Index := 1 to ArgRoot.ChildCount - 1 do
    if not ExpressionTypeFactIsStable(ArgRoot.ChildAt(Index)) then
      Exit(False);
  Result := True;
end;

function TSemanticAnalyzer.CallArgumentCount(const ACallNode: TGreenNode): LongInt;
var
  InnerCall: TGreenNode;
begin
  Result := 0;
  if ACallNode = nil then
    Exit;

  if ACallNode.NodeKind = gnkFunctionCall then
  begin
    if ACallNode.ChildCount > 0 then
      Result := ACallNode.ChildCount - 1;
    Exit;
  end;

  if ACallNode.NodeKind = gnkProcedureCallStatement then
  begin
    if (ACallNode.ChildCount = 1) and
      (ACallNode.ChildAt(0) <> nil) and
      (ACallNode.ChildAt(0).NodeKind = gnkFunctionCall) then
    begin
      InnerCall := ACallNode.ChildAt(0);
      if InnerCall.ChildCount > 0 then
        Result := InnerCall.ChildCount - 1;
      Exit;
    end;

    Result := ACallNode.ChildCount;
  end;
end;

function TSemanticAnalyzer.BareCallCalleeName(
  const ACallNode: TGreenNode
): string;
var
  CalleeNode: TGreenNode;
  InnerCallNode: TGreenNode;
begin
  Result := '';
  if ACallNode = nil then
    Exit;
  if ACallNode.ChildCount = 0 then
    Exit(ACallNode.Text);

  CalleeNode := ACallNode.ChildAt(0);
  if (CalleeNode <> nil) and (CalleeNode.NodeKind = gnkIdentifier) then
    Exit(CalleeNode.Text);

  if (ACallNode.NodeKind = gnkProcedureCallStatement) and
    (CalleeNode <> nil) and (CalleeNode.NodeKind = gnkFunctionCall) then
  begin
    InnerCallNode := CalleeNode;
    if (InnerCallNode.ChildCount > 0) and
      (InnerCallNode.ChildAt(0) <> nil) and
      (InnerCallNode.ChildAt(0).NodeKind = gnkIdentifier) then
      Exit(InnerCallNode.ChildAt(0).Text);
  end;

  Result := ACallNode.Text;
end;

function TSemanticAnalyzer.IsWrappedCallChild(
  const AParent: TGreenNode;
  const AChild: TGreenNode
): Boolean;
begin
  Result := (AParent <> nil) and (AChild <> nil) and
    (AParent.NodeKind = gnkProcedureCallStatement) and
    (AChild.NodeKind = gnkFunctionCall) and
    (AParent.ByteOffset = AChild.ByteOffset) and
    SameText(AParent.Text, AChild.Text);
end;

function TSemanticAnalyzer.IsQualifiedCallNode(
  const ACallNode: TGreenNode
): Boolean;
var
  CalleeNode: TGreenNode;
begin
  Result := False;
  if (ACallNode = nil) or
    not (ACallNode.NodeKind in [gnkProcedureCallStatement, gnkFunctionCall]) or
    (ACallNode.ChildCount = 0) then
    Exit;

  CalleeNode := ACallNode.ChildAt(0);
  if CalleeNode = nil then
    Exit;

  if ACallNode.NodeKind = gnkFunctionCall then
  begin
    Result := CalleeNode.NodeKind in [gnkDotAccess, gnkArrayAccess,
      gnkDereference];
    Exit;
  end;

  if CalleeNode.ByteOffset <> ACallNode.ByteOffset then
    Exit;

  if CalleeNode.NodeKind in [gnkDotAccess, gnkArrayAccess, gnkDereference] then
    Exit(True);

  if (CalleeNode.NodeKind = gnkFunctionCall) and
    SameText(ACallNode.Text, CalleeNode.Text) and
    (CalleeNode.ChildCount > 0) then
  begin
    CalleeNode := CalleeNode.ChildAt(0);
    Result := (CalleeNode <> nil) and
      (CalleeNode.NodeKind in [gnkDotAccess, gnkArrayAccess,
       gnkDereference]);
  end;
end;

function TSemanticAnalyzer.ExtractDirectMemberCall(
  const ACallNode: TGreenNode;
  out AReceiverName: string;
  out AMemberName: string;
  out AMemberOffset: LongInt;
  out AArgCount: LongInt
): Boolean;
var
  CalleeNode: TGreenNode;
  DotNode: TGreenNode;
  InnerCallNode: TGreenNode;
  MemberNode: TGreenNode;
  ReceiverNode: TGreenNode;
begin
  Result := False;
  AReceiverName := '';
  AMemberName := '';
  AMemberOffset := 0;
  AArgCount := 0;
  if (ACallNode = nil) or
    not (ACallNode.NodeKind in [gnkProcedureCallStatement, gnkFunctionCall]) or
    (ACallNode.ChildCount = 0) then
    Exit;

  CalleeNode := ACallNode.ChildAt(0);
  if CalleeNode = nil then
    Exit;

  DotNode := nil;
  InnerCallNode := nil;
  if CalleeNode.NodeKind = gnkDotAccess then
    DotNode := CalleeNode
  else if (CalleeNode.NodeKind = gnkFunctionCall) and
    SameText(ACallNode.Text, CalleeNode.Text) and
    (CalleeNode.ChildCount > 0) and
    (CalleeNode.ChildAt(0) <> nil) and
    (CalleeNode.ChildAt(0).NodeKind = gnkDotAccess) then
  begin
    DotNode := CalleeNode.ChildAt(0);
    InnerCallNode := CalleeNode;
  end;

  if (DotNode = nil) or (DotNode.ChildCount < 2) then
    Exit;

  ReceiverNode := DotNode.ChildAt(0);
  MemberNode := DotNode.ChildAt(1);
  if (ReceiverNode = nil) or (MemberNode = nil) or
    (ReceiverNode.NodeKind <> gnkIdentifier) or
    (MemberNode.NodeKind <> gnkIdentifier) then
    Exit;

  AReceiverName := ReceiverNode.Text;
  AMemberName := MemberNode.Text;
  AMemberOffset := MemberNode.ByteOffset;
  if ACallNode.NodeKind = gnkFunctionCall then
    AArgCount := ACallNode.ChildCount - 1
  else if InnerCallNode <> nil then
    AArgCount := InnerCallNode.ChildCount - 1
  else
    AArgCount := 0;
  Result := (AReceiverName <> '') and (AMemberName <> '');
end;

function TSemanticAnalyzer.TypeIdForVariable(const AName: string): LongInt;
var
  Index: LongInt;
  Symbol: TSemanticSymbol;
begin
  Result := 0;
  if AName = '' then
    Exit;

  for Index := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(Index);
    if SameText(Symbol.Name, AName) and SameText(Symbol.Kind, 'variable') and
      (Symbol.TypeId > 0) and (Symbol.TypeId <= FModel.TypeCount) then
      Exit(Symbol.TypeId);
  end;
end;

function TSemanticAnalyzer.TypeIdForMemberReceiver(
  const AName: string;
  const ACurrentMethodClass: string;
  const ACurrentOwnerUnitId: string
): LongInt;
begin
  Result := 0;
  if SameText(AName, 'Self') and (ACurrentMethodClass <> '') then
    Exit(ResolveTypeIdForOwner(
      ACurrentMethodClass,
      ACurrentOwnerUnitId
    ));

  Result := TypeIdForVariable(AName);
  if Result > 0 then
    Exit;
  if AName = '' then
    Exit;

  Result := ResolveTypeIdForOwner(
    AName,
    NormalizeUnitIdentity(FUnitGraph.RootName)
  );
end;

function TSemanticAnalyzer.TypeSymbolForTypeId(
  const ATypeId: LongInt;
  out ASymbol: TSemanticSymbol
): Boolean;
var
  Index: LongInt;
  Symbol: TSemanticSymbol;
begin
  ASymbol.SymbolId := 0;
  ASymbol.Name := '';
  ASymbol.Kind := '';
  ASymbol.OwnerUnitId := '';
  ASymbol.ScopeId := 0;
  ASymbol.TypeId := 0;
  ASymbol.ParamCount := -1;
  ASymbol.ParamSignature := '';
  ASymbol.ByteOffset := 0;
  Result := False;
  if (ATypeId <= 0) or (ATypeId > FModel.TypeCount) then
    Exit;
  for Index := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(Index);
    if SameText(Symbol.Kind, 'type') and (Symbol.TypeId = ATypeId) then
    begin
      ASymbol := Symbol;
      Exit(True);
    end;
  end;
end;

function TSemanticAnalyzer.ClassTypeHasKnownNonMethodMember(
  const AClassTypeId: LongInt;
  const AMemberName: string
): Boolean;
var
  ConstValue: Int64;
  MemberPrefix: string;
  StringValue: string;
  TypeSymbol: TSemanticSymbol;
begin
  Result := False;
  if (AClassTypeId <= 0) or (AMemberName = '') then
    Exit;
  if not TypeSymbolForTypeId(AClassTypeId, TypeSymbol) then
    Exit;

  MemberPrefix := TypeSymbol.Name + '.' + AMemberName;
  Result :=
    FModel.LookupConstValue(MemberPrefix + '$idx', ConstValue) or
    FModel.LookupStringConstValue(MemberPrefix + '$read', StringValue) or
    FModel.LookupStringConstValue(MemberPrefix + '$write', StringValue);
end;

function TSemanticAnalyzer.TypeIdHasKnownClassLayout(
  const ATypeId: LongInt
): Boolean;
var
  ConstValue: Int64;
  TypeSymbol: TSemanticSymbol;
begin
  Result := False;
  if (ATypeId <= 0) or (ATypeId > FModel.TypeCount) then
    Exit;
  if not TypeSymbolForTypeId(ATypeId, TypeSymbol) then
    Exit;
  Result := FModel.LookupConstValue(TypeSymbol.Name + '$vmt_count', ConstValue);
end;

function TSemanticAnalyzer.IsDeferredSystemObjectMember(
  const AMemberName: string
): Boolean;
begin
  Result := SameText(AMemberName, 'Free');
end;

function TSemanticAnalyzer.TypeSignatureForTypeId(const ATypeId: LongInt): string;
var
  TypeName: string;
  TypeInfo: TSemanticType;
  Dummy: Int64;
begin
  Result := '';
  if (ATypeId <= 0) or (ATypeId > FModel.TypeCount) then
    Exit;

  TypeInfo := FModel.TypeAt(ATypeId - 1);
  TypeName := TypeInfo.Name;
  if (TypeName = '') then
    Exit;
  if SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString') or
    SameText(TypeName, 'ShortString') or SameText(TypeName, 'WideString') or
    SameText(TypeName, 'UnicodeString') then
    Exit('s');
  if SameText(TypeName, 'Boolean') then
    Exit('b');
  if FModel.LookupConstValue(TypeName + '$record', Dummy) then
    Exit('r');
  if FModel.LookupConstValue(TypeName + '$size', Dummy) then
    Exit('p');
  Result := 'i';
end;

function TSemanticAnalyzer.TypeIdHasStableScalarFact(
  const ATypeId: LongInt
): Boolean;
var
  TypeInfo: TSemanticType;
begin
  Result := False;
  if (ATypeId <= 0) or (ATypeId > FModel.TypeCount) then
    Exit;

  TypeInfo := FModel.TypeAt(ATypeId - 1);
  if not SameText(TypeInfo.Kind, 'builtin') then
    Exit;

  Result :=
    SameText(TypeInfo.Name, 'Boolean') or
    SameText(TypeInfo.Name, 'Integer') or
    SameText(TypeInfo.Name, 'Byte') or
    SameText(TypeInfo.Name, 'Word') or
    SameText(TypeInfo.Name, 'LongInt') or
    SameText(TypeInfo.Name, 'Int64') or
    SameText(TypeInfo.Name, 'QWord') or
    SameText(TypeInfo.Name, 'Single') or
    SameText(TypeInfo.Name, 'Double') or
    SameText(TypeInfo.Name, 'Char') or
    SameText(TypeInfo.Name, 'AnsiString') or
    SameText(TypeInfo.Name, 'ShortString') or
    SameText(TypeInfo.Name, 'WideString') or
    SameText(TypeInfo.Name, 'UnicodeString');
end;

function TSemanticAnalyzer.CallArgumentSignature(
  const ACallNode: TGreenNode;
  out ASignature: string
): Boolean;
var
  ArgNode: TGreenNode;
  ArgRoot: TGreenNode;
  ArgTypeId: LongInt;
  Index: LongInt;
  TypeSig: string;
begin
  ASignature := '';
  Result := False;
  if ACallNode = nil then
    Exit;

  ArgRoot := ACallNode;
  if (ACallNode.NodeKind = gnkProcedureCallStatement) and
    (ACallNode.ChildCount > 0) and
    (ACallNode.ChildAt(0) <> nil) and
    (ACallNode.ChildAt(0).NodeKind = gnkFunctionCall) then
    ArgRoot := ACallNode.ChildAt(0);

  if ArgRoot.NodeKind <> gnkFunctionCall then
    Exit(True);

  for Index := 1 to ArgRoot.ChildCount - 1 do
  begin
    ArgNode := ArgRoot.ChildAt(Index);
    ArgTypeId := InferExpressionType(ArgNode);
    TypeSig := TypeSignatureForTypeId(ArgTypeId);
    if TypeSig = '' then
      Exit(False);
    ASignature := ASignature + TypeSig;
  end;
  Result := True;
end;

function TSemanticAnalyzer.MethodSymbolIdForExactClassTypeMember(
  const AClassTypeId: LongInt;
  const AMemberName: string;
  const AArgCount: LongInt;
  const AArgSignature: string;
  const AHasArgSignature: Boolean;
  const AHasTypeMismatchEvidence: Boolean;
  const AAllowNoMatchingOverloadDiagnostic: Boolean;
  out AMethodNameFound: Boolean;
  out AResolutionFailureKind: string
): LongInt;
var
  BodyCandidateCount: LongInt;
  BodyMatchCount: LongInt;
  Index: LongInt;
  QualifiedName: string;
  Symbol: TSemanticSymbol;
  SignatureMatchCount: LongInt;
  SignatureSymbolId: LongInt;
  SymbolId: LongInt;
  SymbolMatchCount: LongInt;
  TypeSymbol: TSemanticSymbol;
begin
  Result := 0;
  AMethodNameFound := False;
  AResolutionFailureKind := '';
  if (AClassTypeId <= 0) or (AMemberName = '') then
    Exit;
  if not TypeSymbolForTypeId(AClassTypeId, TypeSymbol) then
    Exit;

  QualifiedName := TypeSymbol.Name + '.' + AMemberName;
  SymbolId := 0;
  SignatureSymbolId := 0;
  SymbolMatchCount := 0;
  SignatureMatchCount := 0;
  for Index := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(Index);
    if SameText(Symbol.Name, QualifiedName) and
      SameText(Symbol.Kind, 'method') and
      SameText(Symbol.OwnerUnitId, TypeSymbol.OwnerUnitId) then
    begin
      AMethodNameFound := True;
      if Symbol.ParamCount = AArgCount then
      begin
        Inc(SymbolMatchCount);
        SymbolId := Symbol.SymbolId;
        if AHasArgSignature and
          SameText(Symbol.ParamSignature, AArgSignature) then
        begin
          Inc(SignatureMatchCount);
          SignatureSymbolId := Symbol.SymbolId;
        end;
      end;
    end;
  end;
  if SymbolMatchCount = 0 then
  begin
    if AMethodNameFound and (
      SameText(
        TypeSymbol.OwnerUnitId,
        NormalizeUnitIdentity(FUnitGraph.RootName)
      ) or OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)
    ) then
      AResolutionFailureKind := 'wrong-argument-count';
    Exit;
  end;
  if AHasTypeMismatchEvidence and
    (SymbolMatchCount = 1) and AHasArgSignature and
    (SignatureMatchCount = 0) then
  begin
    if SameText(
      TypeSymbol.OwnerUnitId,
      NormalizeUnitIdentity(FUnitGraph.RootName)
    ) or OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId) then
    begin
      AResolutionFailureKind := 'type-mismatch';
      Exit;
    end;
  end;
  if SymbolMatchCount > 1 then
  begin
    if AHasArgSignature and (SignatureMatchCount = 1) then
      SymbolId := SignatureSymbolId
    else if (not AHasArgSignature) or (SignatureMatchCount > 1) then
    begin
      if SameText(
        TypeSymbol.OwnerUnitId,
        NormalizeUnitIdentity(FUnitGraph.RootName)
      ) or OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId) then
        AResolutionFailureKind := 'ambiguous-overload';
      Exit;
    end
    else if SignatureMatchCount = 0 then
    begin
      if AAllowNoMatchingOverloadDiagnostic and AHasTypeMismatchEvidence and
        (
          SameText(TypeSymbol.OwnerUnitId, NormalizeUnitIdentity(FUnitGraph.RootName)) or
          OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)
        ) then
        AResolutionFailureKind := 'no-matching-overload';
      Exit;
    end;
  end;
  if SymbolId <= 0 then
    Exit;

  BodyCandidateCount := 0;
  BodyMatchCount := 0;
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if SameText(FProcedureBodies[Index].Name, QualifiedName) and
      SameText(FProcedureBodies[Index].OwnerUnitId, TypeSymbol.OwnerUnitId) then
    begin
      Inc(BodyCandidateCount);
      if (CountDeclParams(FProcedureBodies[Index].Decl) = AArgCount) and
        ((not AHasArgSignature) or
         SameText(GetParamSignature(FProcedureBodies[Index].Decl), AArgSignature)) then
        Inc(BodyMatchCount);
    end;

  if BodyCandidateCount = 0 then
  begin
    if AArgCount = 0 then
      Exit(SymbolId);
    Exit;
  end;
  if BodyMatchCount > 1 then
  begin
    AResolutionFailureKind := 'ambiguous-overload';
    Exit;
  end;
  if BodyMatchCount = 0 then
    Exit;

  Result := SymbolId;
end;

function TSemanticAnalyzer.MethodSymbolIdForClassTypeMember(
  const AClassTypeId: LongInt;
  const AMemberName: string;
  const AArgCount: LongInt;
  const AArgSignature: string;
  const AHasArgSignature: Boolean;
  const AHasTypeMismatchEvidence: Boolean;
  out AResolutionFailureKind: string
): LongInt;
var
  CurrentTypeId: LongInt;
  Depth: LongInt;
  MethodNameFound: Boolean;
  TypeSymbol: TSemanticSymbol;
begin
  Result := 0;
  AResolutionFailureKind := '';
  CurrentTypeId := AClassTypeId;
  Depth := 0;
  if not TypeIdHasKnownClassLayout(CurrentTypeId) then
    Exit;
  while (CurrentTypeId > 0) and (Depth < 32) do
  begin
    if ClassTypeHasKnownNonMethodMember(CurrentTypeId, AMemberName) then
    begin
      if TypeSymbolForTypeId(CurrentTypeId, TypeSymbol) and
        (
          SameText(
            TypeSymbol.OwnerUnitId,
            NormalizeUnitIdentity(FUnitGraph.RootName)
          ) or
          OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)
        ) then
        AResolutionFailureKind := 'invalid-call-shape';
      Exit;
    end;

    Result := MethodSymbolIdForExactClassTypeMember(
      CurrentTypeId,
      AMemberName,
      AArgCount,
      AArgSignature,
      AHasArgSignature,
      AHasTypeMismatchEvidence,
      (Depth = 0) or (
        TypeSymbolForTypeId(CurrentTypeId, TypeSymbol) and
        (
          SameText(
            TypeSymbol.OwnerUnitId,
            NormalizeUnitIdentity(FUnitGraph.RootName)
          ) or
          OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)
        )
      ),
      MethodNameFound,
      AResolutionFailureKind
    );
    if Result > 0 then
      Exit;
    if AResolutionFailureKind <> '' then
      Exit;
    if MethodNameFound then
      Exit;
    if (CurrentTypeId <= 0) or (CurrentTypeId > FModel.TypeCount) then
      Exit;
    CurrentTypeId := FModel.TypeAt(CurrentTypeId - 1).ParentTypeId;
    Inc(Depth);
  end;
  if IsDeferredSystemObjectMember(AMemberName) then
    Exit;
  if TypeSymbolForTypeId(AClassTypeId, TypeSymbol) and
    (not SameText(
      TypeSymbol.OwnerUnitId,
      NormalizeUnitIdentity(FUnitGraph.RootName)
    )) and
    (not OwnerUnitAllowsProjectSourceDiagnostic(TypeSymbol.OwnerUnitId)) then
    Exit;
  AResolutionFailureKind := 'unknown-member';
end;

function TSemanticAnalyzer.TryRegisterMemberCallBinding(
  const ACallNode: TGreenNode;
  const ACurrentMethodClass: string;
  const ACurrentOwnerUnitId: string;
  out AResolutionFailureKind: string;
  out AFailureName: string;
  out AFailureOffset: LongInt
): Boolean;
var
  ArgCount: LongInt;
  ArgSignature: string;
  HasArgSignature: Boolean;
  HasTypeMismatchEvidence: Boolean;
  MemberName: string;
  MemberOffset: LongInt;
  ReceiverName: string;
  ReceiverTypeId: LongInt;
  TargetSymbolId: LongInt;
begin
  Result := False;
  AResolutionFailureKind := '';
  AFailureName := '';
  AFailureOffset := 0;
  if not ExtractDirectMemberCall(
    ACallNode,
    ReceiverName,
    MemberName,
    MemberOffset,
    ArgCount
  ) then
    Exit;
  AFailureName := MemberName;
  AFailureOffset := MemberOffset;
  ReceiverTypeId := TypeIdForMemberReceiver(
    ReceiverName,
    ACurrentMethodClass,
    ACurrentOwnerUnitId
  );
  if ReceiverTypeId <= 0 then
    Exit;
  HasArgSignature := CallArgumentSignature(ACallNode, ArgSignature);
  HasTypeMismatchEvidence := HasArgSignature and
    CallArgumentSignatureIsStable(ACallNode);

  TargetSymbolId := MethodSymbolIdForClassTypeMember(
    ReceiverTypeId,
    MemberName,
    ArgCount,
    ArgSignature,
    HasArgSignature,
    HasTypeMismatchEvidence,
    AResolutionFailureKind
  );
  if TargetSymbolId <= 0 then
    Exit;

  FModel.AddBinding(
    'member-call',
    MemberName,
    ACurrentOwnerUnitId,
    MemberOffset,
    TargetSymbolId
  );
  Result := True;
end;

function TSemanticAnalyzer.TryRegisterImplicitSelfBareMethodCallBinding(
  const ACallNode: TGreenNode;
  const ACurrentMethodClass: string;
  const ACurrentOwnerUnitId: string;
  out AResolutionFailureKind: string;
  out AFailureName: string;
  out AFailureOffset: LongInt
): Boolean;
var
  ArgCount: LongInt;
  ArgSignature: string;
  CallName: string;
  HasArgSignature: Boolean;
  HasTypeMismatchEvidence: Boolean;
  ReceiverTypeId: LongInt;
  TargetSymbolId: LongInt;
begin
  Result := False;
  AResolutionFailureKind := '';
  AFailureName := '';
  AFailureOffset := 0;
  if (ACurrentMethodClass = '') or (ACallNode = nil) or
    not (ACallNode.NodeKind in [gnkProcedureCallStatement, gnkFunctionCall]) then
    Exit;

  CallName := BareCallCalleeName(ACallNode);
  if CallName = '' then
    Exit;
  AFailureName := CallName;
  AFailureOffset := ACallNode.ByteOffset;

  ReceiverTypeId := TypeIdForMemberReceiver(
    'Self',
    ACurrentMethodClass,
    ACurrentOwnerUnitId
  );
  if ReceiverTypeId <= 0 then
    Exit;

  ArgCount := CallArgumentCount(ACallNode);
  HasArgSignature := CallArgumentSignature(ACallNode, ArgSignature);
  HasTypeMismatchEvidence := HasArgSignature and
    CallArgumentSignatureIsStable(ACallNode);
  TargetSymbolId := MethodSymbolIdForClassTypeMember(
    ReceiverTypeId,
    CallName,
    ArgCount,
    ArgSignature,
    HasArgSignature,
    HasTypeMismatchEvidence,
    AResolutionFailureKind
  );
  if TargetSymbolId <= 0 then
    Exit;

  FModel.AddBinding(
    'member-call',
    CallName,
    ACurrentOwnerUnitId,
    ACallNode.ByteOffset,
    TargetSymbolId
  );
  Result := True;
end;

function TSemanticAnalyzer.BindCallArgs(const ADecl: TGreenNode;
  const ACallNode: TGreenNode;
  const ANameSkip: LongInt): TParamSnapshots;
var
  ParamList: TGreenNode;
  ParamDecl, ArgNode: TGreenNode;
  Index, ParamIndex, ArgIndex: LongInt;
  Value, Prior: Int64;
  Snap: TParamSnapshot;
begin
  Result := nil;
  if (ADecl = nil) or (ACallNode = nil) then
    Exit;
  ParamList := nil;
  for Index := 0 to ADecl.ChildCount - 1 do
    if (ADecl.ChildAt(Index) <> nil) and
      (ADecl.ChildAt(Index).NodeKind = gnkParameterList) then
    begin
      ParamList := ADecl.ChildAt(Index);
      Break;
    end;
  if ParamList = nil then
    Exit;
  ParamIndex := 0;
  for Index := 0 to ParamList.ChildCount - 1 do
  begin
    ParamDecl := ParamList.ChildAt(Index);
    if (ParamDecl = nil) or (ParamDecl.NodeKind <> gnkParameterDecl) then
      Continue;
    ArgIndex := ANameSkip + ParamIndex;
    if ArgIndex >= ACallNode.ChildCount then
      Break;
    ArgNode := ACallNode.ChildAt(ArgIndex);
    if (ArgNode <> nil) and EvaluateIntegerConstant(ArgNode, Value) then
    begin
      Snap.Name := ParamDecl.Text;
      Snap.HadValue := FModel.LookupVarInitValue(ParamDecl.Text, Prior);
      Snap.PriorValue := Prior;
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Snap;
      FModel.AddVarInitValue(ParamDecl.Text, Value);
    end;
    Inc(ParamIndex);
  end;
end;

procedure TSemanticAnalyzer.RestoreCallArgs(const ASnapshots: TParamSnapshots);
var
  Index: LongInt;
begin
  for Index := High(ASnapshots) downto 0 do
  begin
    if ASnapshots[Index].HadValue then
      FModel.AddVarInitValue(ASnapshots[Index].Name,
        ASnapshots[Index].PriorValue)
    else
      FModel.RemoveVarInitValue(ASnapshots[Index].Name);
  end;
end;

function TSemanticAnalyzer.EnsureUnitScope(
  const AOwnerUnitId: string
): LongInt;
var
  Index: LongInt;
  Scope: TSemanticScope;
begin
  Result := 0;
  if Trim(AOwnerUnitId) = '' then
    Exit;

  for Index := 0 to FModel.ScopeCount - 1 do
  begin
    Scope := FModel.ScopeAt(Index);
    if (Scope.Kind = skUnit) and
      SameText(NormalizeUnitIdentity(Scope.Name), AOwnerUnitId) then
      Exit(Scope.ScopeId);
  end;

  Result := FModel.AddScope(skUnit, AOwnerUnitId, 1);
end;

function TSemanticAnalyzer.CallableSymbolIdForDeclaration(
  const ADecl: TGreenNode;
  const AOwnerUnitId: string
): LongInt;
var
  Child: TGreenNode;
  ExpectedKind: string;
  Index: LongInt;
  ParamCount: LongInt;
  ParamSignature: string;
  Symbol: TSemanticSymbol;
  TypeId: LongInt;
begin
  Result := 0;
  if ADecl = nil then
    Exit;

  if Pos('.', ADecl.Text) > 0 then
    Exit;

  if ADecl.NodeKind = gnkFunctionDecl then
    ExpectedKind := 'function'
  else if ADecl.NodeKind = gnkProcedureDecl then
    ExpectedKind := 'procedure'
  else
    ExpectedKind := '';
  ParamCount := CountDeclParams(ADecl);
  ParamSignature := GetParamSignature(ADecl);

  for Index := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(Index);
    if SameText(Symbol.Name, ADecl.Text) and
      ((AOwnerUnitId = '') or SameText(Symbol.OwnerUnitId, AOwnerUnitId)) and
      ((ExpectedKind = '') or SameText(Symbol.Kind, ExpectedKind)) and
      (Symbol.ParamCount = ParamCount) and
      SameText(Symbol.ParamSignature, ParamSignature) then
      Exit(Symbol.SymbolId);
  end;

  for Index := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(Index);
    if (Symbol.ByteOffset = ADecl.ByteOffset) and
      SameText(Symbol.Name, ADecl.Text) and
      ((AOwnerUnitId = '') or SameText(Symbol.OwnerUnitId, AOwnerUnitId)) and
      (SameText(Symbol.Kind, 'procedure') or
       SameText(Symbol.Kind, 'function') or
       SameText(Symbol.Kind, 'method')) then
      Exit(Symbol.SymbolId);
  end;

  if (ExpectedKind = '') or (AOwnerUnitId = '') then
    Exit;

  TypeId := 0;
  if ADecl.NodeKind = gnkFunctionDecl then
    for Index := 0 to ADecl.ChildCount - 1 do
    begin
      Child := ADecl.ChildAt(Index);
      if (Child <> nil) and (Child.NodeKind = gnkIdentifier) then
      begin
        TypeId := ResolveTypeIdForOwner(Child.Text, AOwnerUnitId);
        Break;
      end;
    end;

  Result := FModel.AddSymbol(
    ADecl.Text,
    ExpectedKind,
    AOwnerUnitId,
    TypeId,
    ADecl.ByteOffset
  );
  FModel.SetSymbolParamCount(Result, ParamCount);
  FModel.SetSymbolParamSignature(Result, ParamSignature);
  FModel.SetSymbolScope(Result, EnsureUnitScope(AOwnerUnitId));
end;

procedure TSemanticAnalyzer.RegisterCallBinding(
  const ACallNode: TGreenNode;
  const ADecl: TGreenNode;
  const AOwnerUnitId: string
);
var
  SymbolId: LongInt;
begin
  if (ACallNode = nil) or (ADecl = nil) then
    Exit;

  SymbolId := CallableSymbolIdForDeclaration(ADecl, AOwnerUnitId);
  if SymbolId <= 0 then
    Exit;

  FModel.AddBinding(
    'call',
    ACallNode.Text,
    NormalizeUnitIdentity(FUnitGraph.RootName),
    ACallNode.ByteOffset,
    SymbolId
  );
end;

procedure TSemanticAnalyzer.SeedCallBindingsInNode(
  const ANode: TGreenNode;
  const ACurrentMethodClass: string;
  const ACurrentOwnerUnitId: string
);
var
  ArgIndex: LongInt;
  ArgSignature: string;
  BodyNode: TGreenNode;
  CallableScopeId: LongInt;
  Child: TGreenNode;
  DeclNode: TGreenNode;
  HasArgSignature: Boolean;
  HasTypeMismatchEvidence: Boolean;
  ImplicitSelfBound: Boolean;
  Index: LongInt;
  MemberFailureName: string;
  MemberFailureOffset: LongInt;
  MethodClass: string;
  CallableOwnerUnitId: string;
  QualifiedPos: LongInt;
  ResolutionFailureKind: string;
  SavedScopeId: LongInt;
begin
  if ANode = nil then
    Exit;

  MethodClass := ACurrentMethodClass;
  SavedScopeId := FCurrentScopeId;
  if ANode.NodeKind in [gnkProcedureDecl, gnkFunctionDecl] then
  begin
    QualifiedPos := Pos('.', ANode.Text);
    if QualifiedPos > 1 then
      MethodClass := Copy(ANode.Text, 1, QualifiedPos - 1);
    CallableScopeId := ProcedureBodyScopeIdForDecl(ANode);
    if CallableScopeId > 0 then
      FCurrentScopeId := CallableScopeId;
  end;

  if ANode.NodeKind in [gnkProcedureCallStatement, gnkFunctionCall] then
  begin
    if IsQualifiedCallNode(ANode) then
    begin
      if (not TryRegisterMemberCallBinding(
        ANode,
        MethodClass,
        ACurrentOwnerUnitId,
        ResolutionFailureKind,
        MemberFailureName,
        MemberFailureOffset
      )) and SameText(ResolutionFailureKind, 'ambiguous-overload') then
        EmitSemaError(
          'sema.ambiguous-overload',
          'ambiguous overload for "' + MemberFailureName + '"',
          MemberFailureOffset
        )
      else if SameText(ResolutionFailureKind, 'wrong-argument-count') then
        EmitSemaError(
          'sema.wrong-argument-count',
          'wrong number of arguments for "' + MemberFailureName + '"',
          MemberFailureOffset
        )
      else if SameText(ResolutionFailureKind, 'type-mismatch') then
        EmitSemaError(
          'sema.type-mismatch',
          'argument type mismatch for "' + MemberFailureName + '"',
          MemberFailureOffset
        )
      else if SameText(ResolutionFailureKind, 'no-matching-overload') then
        EmitSemaError(
          'sema.no-matching-overload',
          'no matching overload for "' + MemberFailureName + '"',
          MemberFailureOffset
        )
      else if SameText(ResolutionFailureKind, 'unknown-member') then
        EmitSemaError(
          'sema.unknown-member',
          'unknown member "' + MemberFailureName + '"',
          MemberFailureOffset
        )
      else if SameText(ResolutionFailureKind, 'invalid-call-shape') then
        EmitSemaError(
          'sema.invalid-call-shape',
          'member "' + MemberFailureName + '" is not callable',
          MemberFailureOffset
        );
    end
    else if Pos('.', ANode.Text) = 0 then
    begin
      MemberFailureName := ANode.Text;
      MemberFailureOffset := ANode.ByteOffset;
      HasArgSignature := CallArgumentSignature(ANode, ArgSignature);
      HasTypeMismatchEvidence := HasArgSignature and
        CallArgumentSignatureIsStable(ANode);
      ImplicitSelfBound := False;
      if LookupCallBindingDeclaration(
        ANode.Text,
        CallArgumentCount(ANode),
        ArgSignature,
        HasArgSignature,
        HasTypeMismatchEvidence,
        ResolutionFailureKind,
        BodyNode,
        DeclNode,
        CallableOwnerUnitId
      ) then
        RegisterCallBinding(ANode, DeclNode, CallableOwnerUnitId)
      else
      begin
        if (MethodClass <> '') and
          SameText(ResolutionFailureKind, 'unknown-callable') then
          ImplicitSelfBound := TryRegisterImplicitSelfBareMethodCallBinding(
            ANode,
            MethodClass,
            ACurrentOwnerUnitId,
            ResolutionFailureKind,
            MemberFailureName,
            MemberFailureOffset
          );
        if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'ambiguous-overload') then
          EmitSemaError(
            'sema.ambiguous-overload',
            'ambiguous overload for "' + MemberFailureName + '"',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'wrong-argument-count') then
          EmitSemaError(
            'sema.wrong-argument-count',
            'wrong number of arguments for "' + MemberFailureName + '"',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'type-mismatch') then
          EmitSemaError(
            'sema.type-mismatch',
            'argument type mismatch for "' + MemberFailureName + '"',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'no-matching-overload') then
          EmitSemaError(
            'sema.no-matching-overload',
            'no matching overload for "' + MemberFailureName + '"',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'unknown-member') then
          EmitSemaError(
            'sema.unknown-member',
            'unknown member "' + MemberFailureName + '"',
            MemberFailureOffset
          )
        else if (not ImplicitSelfBound) and
          SameText(ResolutionFailureKind, 'unknown-callable') and
          (MethodClass = '') then
          EmitSemaError(
            'sema.unknown-callable',
            'unknown callable "' + ANode.Text + '"',
            ANode.ByteOffset
          );
      end;
    end;
  end;

  for Index := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(Index);
    if Child = nil then
      Continue;
    if IsWrappedCallChild(ANode, Child) then
    begin
      for ArgIndex := 1 to Child.ChildCount - 1 do
        SeedCallBindingsInNode(
          Child.ChildAt(ArgIndex),
          MethodClass,
          ACurrentOwnerUnitId
        );
      Continue;
    end;
    if Child <> nil then
      SeedCallBindingsInNode(Child, MethodClass, ACurrentOwnerUnitId);
  end;
  FCurrentScopeId := SavedScopeId;
end;

procedure TSemanticAnalyzer.SeedCallBindings;
var
  Index: LongInt;
  RootOwnerUnitId: string;
begin
  if (FRootAst = nil) or (FRootAst.RootNode = nil) then
    Exit;

  RootOwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);
  SeedCallBindingsInNode(FRootAst.RootNode, '', RootOwnerUnitId);
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if (Pos('.', FProcedureBodies[Index].Name) > 0) and
      OwnerUnitAllowsProjectSourceDiagnostic(
        FProcedureBodies[Index].OwnerUnitId
      ) then
      SeedCallBindingsInNode(
        FProcedureBodies[Index].Decl,
        '',
        FProcedureBodies[Index].OwnerUnitId
      );
end;

function TSemanticAnalyzer.IsCurrentlyInlining(const AName: string): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FInliningStack) - 1 do
    if SameText(FInliningStack[Index], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemanticAnalyzer.PushInlining(const AName: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FInliningStack);
  SetLength(FInliningStack, NextIndex + 1);
  FInliningStack[NextIndex] := AName;
end;

procedure TSemanticAnalyzer.PopInlining;
var
  Last: LongInt;
begin
  Last := Length(FInliningStack) - 1;
  if Last >= 0 then
    SetLength(FInliningStack, Last);
end;

function EncodeRuntimeIntExpr(const ANode: TGreenNode;
  out ABlob: string): Boolean; forward;

function EncodeRuntimeBoolExpr(const ANode: TGreenNode;
  out ABlob: string): Boolean;
var
  LeftBlob, RightBlob, Op, Pred: string;
begin
  ABlob := '';
  if ANode = nil then
    Exit(False);
  if ANode.NodeKind <> gnkBinaryExpression then
    Exit(False);
  if ANode.ChildCount < 2 then
    Exit(False);
  Op := ANode.Text;
  if Op = '=' then Pred := 'eq'
  else if Op = '<>' then Pred := 'ne'
  else if Op = '<' then Pred := 'slt'
  else if Op = '<=' then Pred := 'sle'
  else if Op = '>' then Pred := 'sgt'
  else if Op = '>=' then Pred := 'sge'
  else
    Exit(False);
  if not EncodeRuntimeIntExpr(ANode.ChildAt(0), LeftBlob) then
    Exit(False);
  if not EncodeRuntimeIntExpr(ANode.ChildAt(1), RightBlob) then
    Exit(False);
  ABlob := LeftBlob + RightBlob + 'cmp ' + Pred + #10;
  Result := True;
end;

function EncodeRuntimeIntExpr(const ANode: TGreenNode;
  out ABlob: string): Boolean;
var
  LeftBlob, RightBlob, Op: string;
  Parsed: Int64;
  ParseCode: Word;
begin
  ABlob := '';
  if ANode = nil then
    Exit(False);
  case ANode.NodeKind of
    gnkIntegerLiteral:
      begin
        Val(ANode.Text, Parsed, ParseCode);
        if ParseCode <> 0 then
          Exit(False);
        ABlob := 'int ' + IntToStr(Parsed) + #10;
        Exit(True);
      end;
    gnkIdentifier:
      begin
        if ANode.Text = '' then
          Exit(False);
        ABlob := 'var ' + ANode.Text + #10;
        Exit(True);
      end;
    gnkUnaryExpression:
      begin
        if ANode.ChildCount < 1 then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(0), LeftBlob) then
          Exit(False);
        Op := ANode.Text;
        if Op = '-' then
        begin
          ABlob := LeftBlob + 'neg' + #10;
          Exit(True);
        end
        else if Op = '+' then
        begin
          ABlob := LeftBlob;
          Exit(True);
        end
        else
          Exit(False);
      end;
    gnkBinaryExpression:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(0), LeftBlob) then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(1), RightBlob) then
          Exit(False);
        Op := ANode.Text;
        if Op = '+' then
          ABlob := LeftBlob + RightBlob + 'add' + #10
        else if Op = '-' then
          ABlob := LeftBlob + RightBlob + 'sub' + #10
        else if Op = '*' then
          ABlob := LeftBlob + RightBlob + 'mul' + #10
        else if SameText(Op, 'div') then
          ABlob := LeftBlob + RightBlob + 'div' + #10
        else if SameText(Op, 'mod') then
          ABlob := LeftBlob + RightBlob + 'mod' + #10
        else
          Exit(False);
        Exit(True);
      end;
    gnkFunctionCall:
      begin
        if ANode.ChildCount < 1 then
          Exit(False);
        if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
          Exit(False);
        if SameText(ANode.ChildAt(0).Text, 'Length') and
          (ANode.ChildCount = 2) and
          (ANode.ChildAt(1) <> nil) and
          (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
        begin
          ABlob := 'var ' + ANode.ChildAt(1).Text + '$len' + #10;
          Exit(True);
        end;
        ABlob := '';
        for Parsed := 1 to ANode.ChildCount - 1 do
        begin
          if not EncodeRuntimeIntExpr(ANode.ChildAt(Parsed), RightBlob) then
            Exit(False);
          ABlob := ABlob + RightBlob;
        end;
        ABlob := ABlob + 'call ' + ANode.ChildAt(0).Text + ' ' +
          IntToStr(ANode.ChildCount - 1) + #10;
        Exit(True);
      end;
    gnkDotAccess:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
          Exit(False);
        if ANode.ChildAt(1).NodeKind <> gnkIdentifier then
          Exit(False);
        ABlob := 'var ' + ANode.ChildAt(0).Text + '.' +
          ANode.ChildAt(1).Text + #10;
        Exit(True);
      end;
    gnkArrayAccess:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(1), LeftBlob) then
          Exit(False);
        ABlob := LeftBlob + 'arrload ' + ANode.ChildAt(0).Text + #10;
        Exit(True);
      end;
  end;
  Result := False;
end;

procedure TSemanticAnalyzer.EmitSemaError(
  const ACode: string;
  const AMessage: string;
  const AByteOffset: LongInt
);
begin
  FDiagnostics.EmitError(ACode, 'sema', FRootFileId, AByteOffset, AMessage);
  FModel.MarkFailure;
end;

function TSemanticAnalyzer.IsSimpleIdentifierName(const AName: string): Boolean;
var
  I: LongInt;
  Ch: Char;
begin
  if AName = '' then
    Exit(False);

  Ch := AName[1];
  if not (Ch in ['A'..'Z', 'a'..'z', '_']) then
    Exit(False);

  for I := 2 to Length(AName) do
  begin
    Ch := AName[I];
    if not (Ch in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit(False);
  end;

  Result := True;
end;

function TSemanticAnalyzer.RegisterSymbol(
  const AName: string;
  const AKind: string;
  const AOwnerUnitId: string;
  const ATypeId: LongInt;
  const AByteOffset: LongInt
): LongInt;
var
  Existing: LongInt;
begin
  if (FCurrentScopeId > 0) and (AName <> '') then
  begin
    Existing := FModel.FindSymbolInScope(AName, FCurrentScopeId);
    if Existing > 0 then
    begin
      EmitSemaError(
        'sema.duplicate-declaration',
        'duplicate identifier "' + AName + '"',
        AByteOffset
      );
    end;
  end;
  Result := FModel.AddSymbol(AName, AKind, AOwnerUnitId, ATypeId, AByteOffset);
  if FCurrentScopeId > 0 then
    FModel.SetSymbolScope(Result, FCurrentScopeId);
end;

function TSemanticAnalyzer.IsBuiltinProcedure(const AName: string): Boolean;
begin
  Result := SameText(AName, 'WriteLn') or SameText(AName, 'Write') or
    SameText(AName, 'ReadLn') or SameText(AName, 'Read') or
    SameText(AName, 'Inc') or SameText(AName, 'Dec') or
    SameText(AName, 'SetLength') or SameText(AName, 'Length') or
    SameText(AName, 'High') or SameText(AName, 'Low') or
    SameText(AName, 'Ord') or SameText(AName, 'Chr') or
    SameText(AName, 'Pred') or SameText(AName, 'Succ') or
    SameText(AName, 'Abs') or SameText(AName, 'Sqr') or
    SameText(AName, 'Sqrt') or SameText(AName, 'Round') or
    SameText(AName, 'Trunc') or SameText(AName, 'Halt') or
    SameText(AName, 'Exit') or SameText(AName, 'Break') or
    SameText(AName, 'Continue') or SameText(AName, 'Assigned') or
    SameText(AName, 'New') or SameText(AName, 'Dispose') or
    SameText(AName, 'SizeOf') or SameText(AName, 'TypeOf') or
    SameText(AName, 'Str') or SameText(AName, 'Val') or
    SameText(AName, 'Copy') or SameText(AName, 'Concat') or
    SameText(AName, 'Pos') or SameText(AName, 'Delete') or
    SameText(AName, 'Insert') or SameText(AName, 'IntToStr') or
    SameText(AName, 'StrToInt') or SameText(AName, 'Addr') or
    SameText(AName, 'FillChar') or SameText(AName, 'Move') or
    SameText(AName, 'Exclude') or SameText(AName, 'Include') or
    SameText(AName, 'Assert') or SameText(AName, 'Swap') or
    SameText(AName, 'Lo') or SameText(AName, 'Hi') or
    SameText(AName, 'Odd') or SameText(AName, 'Char') or
    SameText(AName, 'Free');
end;

function TSemanticAnalyzer.InferExpressionType(const ANode: TGreenNode): LongInt;
var
  SymId: LongInt;
  Sym: TSemanticSymbol;
begin
  Result := 0;
  if ANode = nil then
    Exit;
  case ANode.NodeKind of
    gnkIntegerLiteral:
      Result := FModel.FindTypeByName('Integer');
    gnkRealLiteral:
      Result := FModel.FindTypeByName('Double');
    gnkStringLiteral:
      Result := FModel.FindTypeByName('AnsiString');
    gnkCharLiteral:
      Result := FModel.FindTypeByName('Char');
    gnkIdentifier:
      begin
        if SameText(ANode.Text, 'True') or SameText(ANode.Text, 'False') then
          Exit(FModel.FindTypeByName('Boolean'));
        SymId := FModel.LookupSymbol(ANode.Text, FCurrentScopeId);
        if SymId > 0 then
        begin
          Sym := FModel.SymbolAt(SymId - 1);
          Result := Sym.TypeId;
        end
        else
          Result := FModel.FindTypeByName(ANode.Text);
      end;
    gnkBinaryExpression:
      begin
        if ANode.Text = '+' then
        begin
          Result := InferExpressionType(ANode.ChildAt(0));
          if Result = FModel.FindTypeByName('AnsiString') then
            Exit;
          if Result = 0 then
            Result := InferExpressionType(ANode.ChildAt(1));
          if Result = 0 then
            Result := FModel.FindTypeByName('Integer');
        end
        else if (ANode.Text = '=') or (ANode.Text = '<>') or
          (ANode.Text = '<') or (ANode.Text = '>') or
          (ANode.Text = '<=') or (ANode.Text = '>=') or
          (ANode.Text = 'in') or (ANode.Text = 'is') then
          Result := FModel.FindTypeByName('Boolean')
        else if (ANode.Text = 'and') or (ANode.Text = 'or') or
          (ANode.Text = 'xor') then
        begin
          Result := InferExpressionType(ANode.ChildAt(0));
          if Result = FModel.FindTypeByName('Boolean') then
            Exit;
          Result := FModel.FindTypeByName('Integer');
        end
        else
        begin
          Result := InferExpressionType(ANode.ChildAt(0));
          if Result = 0 then
            Result := FModel.FindTypeByName('Integer');
        end;
      end;
    gnkUnaryExpression:
      begin
        if ANode.Text = 'not' then
          Result := InferExpressionType(ANode.ChildAt(0))
        else
          Result := InferExpressionType(ANode.ChildAt(0));
        if Result = 0 then
          Result := FModel.FindTypeByName('Integer');
      end;
    gnkFunctionCall:
      begin
        SymId := FModel.LookupSymbol(ANode.Text, FCurrentScopeId);
        if SymId > 0 then
        begin
          Sym := FModel.SymbolAt(SymId - 1);
          Result := Sym.TypeId;
        end;
      end;
    gnkDotAccess, gnkArrayAccess, gnkDereference:
      Result := 0;
  end;
end;

function TSemanticAnalyzer.AreTypesCompatible(
  const ALhsTypeId, ARhsTypeId: LongInt): Boolean;
var
  IntIds: array[0..9] of LongInt;
  StrIds: array[0..3] of LongInt;
  I: LongInt;
  LhsIsInt, RhsIsInt, LhsIsStr, RhsIsStr: Boolean;
  LhsType, RhsType: TSemanticType;
begin
  if ALhsTypeId = ARhsTypeId then
    Exit(True);
  if (ALhsTypeId = 0) or (ARhsTypeId = 0) then
    Exit(True);

  LhsType := FModel.TypeAt(ALhsTypeId - 1);
  RhsType := FModel.TypeAt(ARhsTypeId - 1);
  if (LhsType.Kind = 'declared') or (RhsType.Kind = 'declared') or
    (LhsType.Kind = 'alias') or (RhsType.Kind = 'alias') then
  begin
    if FModel.IsTypeDescendantOf(ARhsTypeId, ALhsTypeId) then
      Exit(True);
    if FModel.IsTypeDescendantOf(ALhsTypeId, ARhsTypeId) then
      Exit(True);
    Exit(True);
  end;

  IntIds[0] := FModel.FindTypeByName('Byte');
  IntIds[1] := FModel.FindTypeByName('Word');
  IntIds[2] := FModel.FindTypeByName('LongInt');
  IntIds[3] := FModel.FindTypeByName('Integer');
  IntIds[4] := FModel.FindTypeByName('Int64');
  IntIds[5] := FModel.FindTypeByName('QWord');
  IntIds[6] := FModel.FindTypeByName('LongWord');
  IntIds[7] := FModel.FindTypeByName('Single');
  IntIds[8] := FModel.FindTypeByName('Double');
  IntIds[9] := FModel.FindTypeByName('Pointer');

  LhsIsInt := False;
  RhsIsInt := False;
  for I := 0 to 9 do
  begin
    if ALhsTypeId = IntIds[I] then LhsIsInt := True;
    if ARhsTypeId = IntIds[I] then RhsIsInt := True;
  end;
  if LhsIsInt and RhsIsInt then
    Exit(True);

  StrIds[0] := FModel.FindTypeByName('AnsiString');
  StrIds[1] := FModel.FindTypeByName('ShortString');
  StrIds[2] := FModel.FindTypeByName('WideString');
  StrIds[3] := FModel.FindTypeByName('UnicodeString');

  LhsIsStr := False;
  RhsIsStr := False;
  for I := 0 to 3 do
  begin
    if ALhsTypeId = StrIds[I] then LhsIsStr := True;
    if ARhsTypeId = StrIds[I] then RhsIsStr := True;
  end;
  if LhsIsStr and RhsIsStr then
    Exit(True);

  if ALhsTypeId = FModel.FindTypeByName('Boolean') then
    Exit(ARhsTypeId = FModel.FindTypeByName('Boolean'));

  if LhsIsStr and (ARhsTypeId = FModel.FindTypeByName('Char')) then
    Exit(True);
  if (ALhsTypeId = FModel.FindTypeByName('Char')) and RhsIsStr then
    Exit(True);
  if (ALhsTypeId = FModel.FindTypeByName('Char')) and
    (ARhsTypeId = FModel.FindTypeByName('Char')) then
    Exit(True);

  Result := False;
end;

procedure TSemanticAnalyzer.SeedBuiltinTypes;
begin
  FModel.AddType('Boolean', 'builtin');
  FModel.AddType('Integer', 'builtin');
  FModel.AddType('AnsiString', 'builtin');
  FModel.AddType('Char', 'builtin');
  FModel.AddType('Byte', 'builtin');
  FModel.AddType('Word', 'builtin');
  FModel.AddType('LongInt', 'builtin');
  FModel.AddType('Int64', 'builtin');
  FModel.AddType('QWord', 'builtin');
  FModel.AddType('Single', 'builtin');
  FModel.AddType('Double', 'builtin');
  FModel.AddType('Pointer', 'builtin');
  FModel.AddType('Text', 'builtin');
  FModel.AddType('ShortString', 'builtin');
  FModel.AddType('WideString', 'builtin');
  FModel.AddType('UnicodeString', 'builtin');
  FModel.AddType('Variant', 'builtin');
  FModel.AddType('OleVariant', 'builtin');
  FModel.AddType('String', 'alias');
  FModel.AddType('Cardinal', 'alias');
end;

procedure TSemanticAnalyzer.AssignScopesToSymbols;
var
  I: LongInt;
  Sym: TSemanticSymbol;
begin
  for I := 0 to FModel.SymbolCount - 1 do
  begin
    Sym := FModel.SymbolAt(I);
    if Sym.ScopeId = 0 then
      FModel.SetSymbolScope(Sym.SymbolId, FCurrentScopeId);
  end;
end;

procedure TSemanticAnalyzer.CheckDuplicateDeclarations;
var
  I, J: LongInt;
  SymI, SymJ: TSemanticSymbol;
begin
  for I := 0 to FModel.SymbolCount - 2 do
  begin
    SymI := FModel.SymbolAt(I);
    if SymI.Kind = 'unit' then
      Continue;
    for J := I + 1 to FModel.SymbolCount - 1 do
    begin
      SymJ := FModel.SymbolAt(J);
      if SymJ.Kind = 'unit' then
        Continue;
      if (SymI.ScopeId = SymJ.ScopeId) and SameText(SymI.Name, SymJ.Name) and
        (SymI.Kind <> 'parameter') and (SymJ.Kind <> 'parameter') and
        (SymI.Kind <> 'enum-value') and (SymJ.Kind <> 'enum-value') and
        (SymI.Kind <> 'method') and (SymJ.Kind <> 'method') and
        (SymI.Kind <> 'field') and (SymJ.Kind <> 'field') and
        (SymI.Kind <> 'function') and (SymJ.Kind <> 'function') and
        (SymI.Kind <> 'procedure') and (SymJ.Kind <> 'procedure') then
      begin
        EmitSemaError(
          'sema.duplicate-declaration',
          'duplicate identifier "' + SymJ.Name + '"',
          SymJ.ByteOffset
        );
        Exit;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.CheckIdentifiersInNode(const ANode: TGreenNode);
var
  I: LongInt;
  Child: TGreenNode;
  SymId: LongInt;
  Name: string;
begin
  if ANode = nil then
    Exit;
  case ANode.NodeKind of
    gnkAssignmentStatement:
      begin
        Name := ANode.Text;
        if (Name <> '') and (Name <> 'Result') then
        begin
          SymId := FModel.LookupSymbol(Name, FCurrentScopeId);
          if (SymId = 0) and (FModel.FindTypeByName(Name) = 0) and
            not IsBuiltinProcedure(Name) then
            EmitSemaError(
              'sema.undeclared-identifier',
              'identifier not found "' + Name + '"',
              ANode.ByteOffset
            );
        end;
      end;
    gnkStatementList, gnkBeginBlock, gnkIfStatement,
    gnkWhileStatement, gnkForStatement, gnkForInStatement,
    gnkRepeatStatement, gnkCaseStatement, gnkCaseSelector,
    gnkTryExceptStatement, gnkTryFinallyStatement:
      begin
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if Child <> nil then
            CheckIdentifiersInNode(Child);
        end;
      end;
  end;
end;

procedure TSemanticAnalyzer.CheckUndeclaredIdentifiers;
var
  RootNode: TGreenNode;
  I: LongInt;
  Child: TGreenNode;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  for I := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkBeginBlock) then
      CheckIdentifiersInNode(Child);
  end;
end;

procedure TSemanticAnalyzer.CheckTypeMismatchesInNode(const ANode: TGreenNode);
var
  I: LongInt;
  Child, RhsChild: TGreenNode;
  LhsName: string;
  LhsSymId: LongInt;
  LhsSym: TSemanticSymbol;
  LhsTypeId, RhsTypeId: LongInt;
begin
  if ANode = nil then
    Exit;

  case ANode.NodeKind of
    gnkAssignmentStatement:
      begin
        LhsName := ANode.Text;
        if LhsName = '' then
          Exit;
        LhsSymId := FModel.LookupSymbol(LhsName, FCurrentScopeId);
        if LhsSymId = 0 then
          Exit;
        LhsSym := FModel.SymbolAt(LhsSymId - 1);
        LhsTypeId := LhsSym.TypeId;
        if LhsTypeId = 0 then
          Exit;
        RhsChild := nil;
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if (Child <> nil) and (Child.NodeKind <> gnkDotAccess) and
            (Child.NodeKind <> gnkArrayAccess) and
            (Child.NodeKind <> gnkIdentifier) then
          begin
            RhsChild := Child;
            Break;
          end;
        end;
        if RhsChild = nil then
          Exit;
        RhsTypeId := InferExpressionType(RhsChild);
        if RhsTypeId = 0 then
          Exit;
        if AreTypesCompatible(LhsTypeId, RhsTypeId) then
          Exit;
        EmitSemaError(
          'sema.type-mismatch',
          'incompatible types: cannot assign to "' + LhsName + '"',
          ANode.ByteOffset
        );
      end;
    gnkProcedureCallStatement:
      begin
        LhsName := ANode.Text;
        if LhsName <> '' then
        begin
          LhsSymId := FModel.LookupSymbol(LhsName, FCurrentScopeId);
          if LhsSymId > 0 then
          begin
            LhsSym := FModel.SymbolAt(LhsSymId - 1);
            if (LhsSym.ParamCount >= 0) and
              (not HasOverload(LhsName)) and
              ((LhsSym.Kind = 'procedure') or (LhsSym.Kind = 'function')) then
            begin
              RhsChild := ANode.ChildAt(0);
              if (RhsChild <> nil) and (RhsChild.NodeKind = gnkFunctionCall) then
                LhsTypeId := RhsChild.ChildCount - 1
              else
                LhsTypeId := ANode.ChildCount;
              if LhsTypeId > LhsSym.ParamCount then
                EmitSemaError(
                  'sema.wrong-argument-count',
                  'too many arguments for "' + LhsName + '" (expected ' +
                    IntToStr(LhsSym.ParamCount) + ', got ' +
                    IntToStr(LhsTypeId) + ')',
                  ANode.ByteOffset
                );
            end;
          end;
        end;
      end;
    gnkStatementList, gnkBeginBlock, gnkIfStatement,
    gnkWhileStatement, gnkForStatement, gnkForInStatement,
    gnkRepeatStatement, gnkCaseStatement, gnkCaseSelector,
    gnkTryExceptStatement, gnkTryFinallyStatement:
      begin
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if Child <> nil then
            CheckTypeMismatchesInNode(Child);
        end;
      end;
  end;
end;

procedure TSemanticAnalyzer.CheckTypeMismatches;
var
  RootNode: TGreenNode;
  I: LongInt;
  Child: TGreenNode;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  for I := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkBeginBlock) then
      CheckTypeMismatchesInNode(Child);
  end;
end;

procedure TSemanticAnalyzer.CheckUnusedSymbols;

  function IsNameUsedInNode(const ANode: TGreenNode; const AName: string): Boolean;
  var
    I: LongInt;
    Child: TGreenNode;
  begin
    if ANode = nil then
      Exit(False);
    if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, AName) then
      Exit(True);
    if (ANode.NodeKind = gnkAssignmentStatement) and SameText(ANode.Text, AName) then
      Exit(True);
    if (ANode.NodeKind = gnkProcedureCallStatement) and SameText(ANode.Text, AName) then
      Exit(True);
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if IsNameUsedInNode(Child, AName) then
        Exit(True);
    end;
    Result := False;
  end;

var
  I: LongInt;
  Sym: TSemanticSymbol;
  RootNode, Child: TGreenNode;
  BeginBlock: TGreenNode;
  J: LongInt;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;

  BeginBlock := nil;
  for J := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkBeginBlock) then
    begin
      BeginBlock := Child;
      Break;
    end;
  end;
  if BeginBlock = nil then
    Exit;

  for I := 0 to FModel.SymbolCount - 1 do
  begin
    Sym := FModel.SymbolAt(I);
    if Sym.Kind <> 'variable' then
      Continue;
    if Sym.ScopeId <> FCurrentScopeId then
      Continue;
    if not IsNameUsedInNode(BeginBlock, Sym.Name) then
      FDiagnostics.EmitWarning(
        'sema.unused-variable',
        'sema',
        FRootFileId,
        Sym.ByteOffset,
        'variable "' + Sym.Name + '" is declared but never used'
      );
  end;
end;

procedure TSemanticAnalyzer.CheckUnreachableInNode(const ANode: TGreenNode;
  var ATerminated: Boolean);
var
  I: LongInt;
  Child: TGreenNode;
  ChildTerminated: Boolean;
begin
  if ANode = nil then
    Exit;
  ATerminated := False;

  if ANode.NodeKind = gnkStatementList then
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then
        Continue;
      if ATerminated then
      begin
        if (Child.NodeKind <> gnkError) then
          FDiagnostics.EmitWarning(
            'sema.unreachable-code',
            'sema',
            FRootFileId,
            Child.ByteOffset,
            'unreachable code after unconditional exit'
          );
        Exit;
      end;
      ChildTerminated := False;
      CheckUnreachableInNode(Child, ChildTerminated);
      if ChildTerminated then
        ATerminated := True;
    end;
  end
  else
  begin
    case ANode.NodeKind of
      gnkExitStatement:
        ATerminated := True;
      gnkBreakStatement:
        ATerminated := True;
      gnkContinueStatement:
        ATerminated := True;
      gnkProcedureCallStatement:
        if SameText(ANode.Text, 'Halt') then
          ATerminated := True;
      gnkBeginBlock, gnkIfStatement, gnkWhileStatement,
      gnkForStatement, gnkRepeatStatement, gnkCaseStatement,
      gnkTryExceptStatement, gnkTryFinallyStatement:
        begin
          for I := 0 to ANode.ChildCount - 1 do
          begin
            Child := ANode.ChildAt(I);
            if Child <> nil then
              CheckUnreachableInNode(Child, ChildTerminated);
          end;
        end;
    end;
  end;
end;

procedure TSemanticAnalyzer.CheckUnreachableCode;
var
  RootNode, Child: TGreenNode;
  I: LongInt;
  Terminated: Boolean;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  for I := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkBeginBlock) then
    begin
      Terminated := False;
      CheckUnreachableInNode(Child, Terminated);
    end;
  end;
end;

procedure TSemanticAnalyzer.CheckCaseLabelsInNode(const ANode: TGreenNode);
var
  I, J, K: LongInt;
  Child, Selector, Label1, Label2: TGreenNode;
  Val1, Val2: Int64;
  SeenValues: array of Int64;
  SeenCount: LongInt;
begin
  if ANode = nil then
    Exit;
  if ANode.NodeKind = gnkCaseStatement then
  begin
    SeenCount := 0;
    SetLength(SeenValues, 0);
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Selector := ANode.ChildAt(I);
      if (Selector = nil) or (Selector.NodeKind <> gnkCaseSelector) then
        Continue;
      for J := 0 to Selector.ChildCount - 1 do
      begin
        Label1 := Selector.ChildAt(J);
        if (Label1 = nil) or (Label1.NodeKind <> gnkCaseLabel) then
          Continue;
        if (Label1.ChildCount > 0) and
          EvaluateIntegerConstant(Label1.ChildAt(0), Val1) then
        begin
          for K := 0 to SeenCount - 1 do
          begin
            if SeenValues[K] = Val1 then
            begin
              FDiagnostics.EmitWarning(
                'sema.duplicate-case-label',
                'sema',
                FRootFileId,
                Label1.ByteOffset,
                'duplicate case label value ' + IntToStr(Val1)
              );
              Break;
            end;
          end;
          Inc(SeenCount);
          SetLength(SeenValues, SeenCount);
          SeenValues[SeenCount - 1] := Val1;
        end;
      end;
    end;
  end
  else
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child <> nil then
        CheckCaseLabelsInNode(Child);
    end;
  end;
end;

procedure TSemanticAnalyzer.CheckDuplicateCaseLabels;
var
  RootNode, Child: TGreenNode;
  I: LongInt;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  for I := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(I);
    if Child <> nil then
      CheckCaseLabelsInNode(Child);
  end;
end;

procedure TSemanticAnalyzer.SeedUnitSymbolsAndHir;
var
  Index: LongInt;
  ResolvedUnit: TResolvedUnit;
  SymbolId: LongInt;
begin
  FModel.SetRootName(FUnitGraph.RootName);
  FModel.AddTypedHirNode('compilation-root', FUnitGraph.RootName, 0, 0, '');

  for Index := 0 to FUnitGraph.ResolvedUnitCount - 1 do
  begin
    ResolvedUnit := FUnitGraph.ResolvedUnitAt(Index);
    SymbolId := FModel.AddSymbol(
      ResolvedUnit.CanonicalName,
      'unit',
      ResolvedUnit.UnitId,
      0,
      0
    );
    FModel.AddTypedHirNode(
      'resolved-unit',
      ResolvedUnit.CanonicalName,
      SymbolId,
      0,
      ''
    );
  end;
end;

procedure TSemanticAnalyzer.SeedRuntimeContracts;
const
  RuntimeContracts: array[0..1] of string = (
    'np.system.process_init',
    'np.system.process_fini'
  );
var
  Index: LongInt;
begin
  if (FRootAst.RootKindName <> 'program') and
    (FRootAst.RootKindName <> 'library') and
    (FRootAst.RootKindName <> 'package') then
    Exit;

  for Index := Low(RuntimeContracts) to High(RuntimeContracts) do
  begin
    FModel.AddRuntimeContract(RuntimeContracts[Index]);
    FModel.AddTypedHirNode('runtime-contract', RuntimeContracts[Index], 0, 0, '');
  end;
end;

procedure TSemanticAnalyzer.SeedForeignProcedureBindings;
var
  ForeignProcedureDecl: TForeignProcedureDecl;
  Index: LongInt;
  RootOwnerUnitId: string;
  SymbolId: LongInt;
begin
  if FRootAst = nil then
    Exit;

  RootOwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);
  for Index := 0 to FRootAst.ForeignProcedureDeclCount - 1 do
  begin
    ForeignProcedureDecl := FRootAst.ForeignProcedureDeclAt(Index);
    if not ForeignProcedureDecl.HasExplicitSymbolName then
    begin
      EmitSemaError(
        'sema.missing-external-symbol-name',
        'external procedure "' + ForeignProcedureDecl.ProcedureName +
          '" must declare explicit foreign symbol name via name ''<symbol>''',
        ForeignProcedureDecl.ByteOffset
      );
      Exit;
    end;

    SymbolId := FModel.AddSymbol(
      ForeignProcedureDecl.ProcedureName,
      'foreign-procedure',
      RootOwnerUnitId,
      0,
      ForeignProcedureDecl.ByteOffset
    );
    FModel.AddForeignProcedureBinding(
      ForeignProcedureDecl.ProcedureName,
      ForeignProcedureDecl.CallingConvention,
      ForeignProcedureDecl.LibraryId,
      ForeignProcedureDecl.ExternalSymbolName,
      SymbolId
    );
    FModel.AddTypedHirNode(
      'foreign-procedure-binding',
      ForeignProcedureDecl.ProcedureName,
      SymbolId,
      0,
      ''
    );
    FModel.AddLibraryRequest(
      ForeignProcedureDecl.LibraryId,
      'shared',
      'strong'
    );
  end;
end;

procedure TSemanticAnalyzer.Analyze;
var
  DuplicateName: string;
begin
  if (FRootAst = nil) or (FUnitGraph = nil) or not FRootAst.IsValid then
  begin
    FModel.MarkFailure;
    Exit;
  end;

  DuplicateName := DuplicateImportName;
  if DuplicateName <> '' then
  begin
    EmitSemaError(
      'sema.duplicate-declaration',
      'duplicate unit import: "' + DuplicateName + '"',
      0
    );
    Exit;
  end;

  SeedBuiltinTypes;
  FModel.AddScope(skCompilation, FUnitGraph.RootName, 0);
  FCurrentScopeId := FModel.AddScope(skUnit, FUnitGraph.RootName, 1);
  SeedImportedUnitBodies;
  SeedDeclarations;
  AssignScopesToSymbols;
  SeedCallBindings;
  CheckDuplicateDeclarations;
  CheckUndeclaredIdentifiers;
  CheckTypeMismatches;
  CheckAssignmentTypes;
  SeedUnitSymbolsAndHir;
  SeedForeignProcedureBindings;
  if FDiagnostics.HasErrors then
    Exit;
  SeedRuntimeContracts;
  SeedRuntimeVarDecls;
  if FNoFold then
    PreRegisterFunctionReturnTypes;
  SeedHaltCalls;
  if FNoFold then
    SeedFunctionBodies;
  CheckUnusedSymbols;
  CheckUnreachableCode;
  CheckDuplicateCaseLabels;

  if FDiagnostics.HasErrors then
    FModel.MarkFailure
  else
    FModel.MarkReady;
end;

function TSemanticAnalyzer.DetachModel: TSemanticModel;
begin
  Result := FModel;
  FModel := nil;
end;

function TSemanticAnalyzer.Status: string;
begin
  if FModel = nil then
    Exit('deferred');

  Result := FModel.Status;
end;

function TSemanticAnalyzer.ResolveTypeId(const ATypeName: string): LongInt;
begin
  Result := ResolveTypeIdForOwner(ATypeName, '');
end;

function TSemanticAnalyzer.ResolveTypeIdForOwner(
  const ATypeName: string;
  const APreferredOwnerUnitId: string
): LongInt;
var
  CandidateSeen: Boolean;
  Index: LongInt;
  NormalizedOwnerUnitId: string;
  PreferredMatchCount: LongInt;
  Symbol: TSemanticSymbol;
  UniqueTypeId: LongInt;
begin
  if ATypeName = '' then
    Exit(0);
  if SameText(ATypeName, 'String') then
    Exit(FModel.FindTypeByName('AnsiString'));
  if SameText(ATypeName, 'Cardinal') then
    Exit(FModel.FindTypeByName('LongWord'));
  if SameText(ATypeName, 'Real') then
    Exit(FModel.FindTypeByName('Double'));
  if SameText(ATypeName, 'Extended') then
    Exit(FModel.FindTypeByName('Double'));

  NormalizedOwnerUnitId := NormalizeUnitIdentity(APreferredOwnerUnitId);
  if NormalizedOwnerUnitId <> '' then
  begin
    PreferredMatchCount := 0;
    UniqueTypeId := 0;
    for Index := 0 to FModel.SymbolCount - 1 do
    begin
      Symbol := FModel.SymbolAt(Index);
      if SameText(Symbol.Kind, 'type') and
        SameText(Symbol.Name, ATypeName) and
        SameText(Symbol.OwnerUnitId, NormalizedOwnerUnitId) and
        (Symbol.TypeId > 0) and (Symbol.TypeId <= FModel.TypeCount) then
      begin
        Inc(PreferredMatchCount);
        if UniqueTypeId = 0 then
          UniqueTypeId := Symbol.TypeId
        else if UniqueTypeId <> Symbol.TypeId then
          Exit(0);
      end;
    end;
    if PreferredMatchCount = 1 then
      Exit(UniqueTypeId);
    if PreferredMatchCount > 1 then
      Exit(0);
  end;

  CandidateSeen := False;
  UniqueTypeId := 0;
  for Index := 0 to FModel.SymbolCount - 1 do
  begin
    Symbol := FModel.SymbolAt(Index);
    if SameText(Symbol.Kind, 'type') and SameText(Symbol.Name, ATypeName) and
      (Symbol.TypeId > 0) and (Symbol.TypeId <= FModel.TypeCount) then
    begin
      if not CandidateSeen then
      begin
        CandidateSeen := True;
        UniqueTypeId := Symbol.TypeId;
      end
      else if UniqueTypeId <> Symbol.TypeId then
        Exit(0);
    end;
  end;
  if CandidateSeen then
    Exit(UniqueTypeId);

  Result := FModel.FindTypeByName(ATypeName);
end;

function TSemanticAnalyzer.ImplicitSystemObjectParentTypeId(
  const AClassName: string
): LongInt;
var
  TypeSymbol: TSemanticSymbol;
begin
  Result := 0;
  if SameText(AClassName, 'TObject') then
    Exit;

  Result := ResolveTypeIdForOwner('TObject', 'system');
  if Result <= 0 then
    Exit;
  if not TypeSymbolForTypeId(Result, TypeSymbol) then
  begin
    Result := 0;
    Exit;
  end;
  if not SameText(TypeSymbol.OwnerUnitId, 'system') then
    Result := 0;
end;

function TSemanticAnalyzer.FindSymbolByName(const AName: string): LongInt;
begin
  if AName = '' then
    Exit(0);
  Result := FModel.FindSymbolByName(AName);
end;

procedure TSemanticAnalyzer.ProcessVarSection(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I, J: LongInt;
  Child, TypeChild: TGreenNode;
  TypeId: LongInt;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkVarDecl) then
      Continue;
    TypeId := 0;
    for J := 0 to Child.ChildCount - 1 do
    begin
      TypeChild := Child.ChildAt(J);
      if (TypeChild <> nil) and (TypeChild.NodeKind = gnkIdentifier) then
      begin
        TypeId := ResolveTypeIdForOwner(TypeChild.Text, AOwnerUnitId);
        Break;
      end;
    end;
    FModel.AddSymbol(Child.Text, 'variable', AOwnerUnitId, TypeId,
      Child.ByteOffset);
  end;
end;

procedure TSemanticAnalyzer.ProcessConstSection(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I, J: LongInt;
  Child, ValueChild: TGreenNode;
  Value: Int64;
  StringValue: string;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkConstDecl) then
      Continue;
    FModel.AddSymbol(Child.Text, 'constant', AOwnerUnitId, 0,
      Child.ByteOffset);
    for J := 0 to Child.ChildCount - 1 do
    begin
      ValueChild := Child.ChildAt(J);
      if EvaluateIntegerConstant(ValueChild, Value) then
      begin
        FModel.AddConstValue(Child.Text, Value);
        Break;
      end;
      if EvaluateStringConstant(ValueChild, StringValue) then
      begin
        FModel.AddStringConstValue(Child.Text, StringValue);
        Break;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.ProcessProcedureDecl(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  SymbolId: LongInt;
  Index, J: LongInt;
  Child, ParamChild: TGreenNode;
  CallableScopeId, SavedScopeId: LongInt;
  ParamTypeId: LongInt;
  ParamCount: LongInt;
begin
  if ANode = nil then
    Exit;
  SymbolId := FModel.AddSymbol(ANode.Text, 'procedure', AOwnerUnitId, 0,
    ANode.ByteOffset);
  FModel.AddTypedHirNode('procedure-decl', ANode.Text, SymbolId, 0, '');

  CallableScopeId := FModel.AddScope(skCallable, ANode.Text, FCurrentScopeId);
  SavedScopeId := FCurrentScopeId;
  FCurrentScopeId := CallableScopeId;
  ParamCount := 0;

  for Index := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(Index);
    if Child = nil then
      Continue;
    if Child.NodeKind = gnkParameterList then
    begin
      for J := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(J);
        if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
        begin
          ParamTypeId := ParamDeclTypeId(ParamChild, AOwnerUnitId);
          FModel.AddSymbol(ParamChild.Text, 'parameter', AOwnerUnitId, ParamTypeId,
            ParamChild.ByteOffset);
          FModel.SetSymbolScope(FModel.SymbolCount, CallableScopeId);
          Inc(ParamCount);
        end;
      end;
    end
    else if Child.NodeKind = gnkBeginBlock then
    begin
      RegisterProcedureBody(ANode.Text, Child, ANode, AOwnerUnitId);
      Break;
    end;
  end;

  FModel.SetSymbolParamCount(SymbolId, ParamCount);
  FModel.SetSymbolParamSignature(SymbolId, GetParamSignature(ANode));
  FCurrentScopeId := SavedScopeId;
end;

procedure TSemanticAnalyzer.ProcessFunctionDecl(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  SymbolId: LongInt;
  TypeId: LongInt;
  J: LongInt;
  Child, ParamChild: TGreenNode;
  CallableScopeId, SavedScopeId: LongInt;
  ParamTypeId: LongInt;
  ParamCount: LongInt;
begin
  if ANode = nil then
    Exit;
  TypeId := 0;
  for J := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkIdentifier) then
    begin
      TypeId := ResolveTypeIdForOwner(Child.Text, AOwnerUnitId);
      Break;
    end;
  end;
  SymbolId := FModel.AddSymbol(ANode.Text, 'function', AOwnerUnitId, TypeId,
    ANode.ByteOffset);
  FModel.AddTypedHirNode('function-decl', ANode.Text, SymbolId, TypeId, '');

  CallableScopeId := FModel.AddScope(skCallable, ANode.Text, FCurrentScopeId);
  SavedScopeId := FCurrentScopeId;
  FCurrentScopeId := CallableScopeId;
  ParamCount := 0;

  for J := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(J);
    if Child = nil then
      Continue;
    if Child.NodeKind = gnkParameterList then
    begin
      for TypeId := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(TypeId);
        if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
        begin
          ParamTypeId := ParamDeclTypeId(ParamChild, AOwnerUnitId);
          FModel.AddSymbol(ParamChild.Text, 'parameter', AOwnerUnitId, ParamTypeId,
            ParamChild.ByteOffset);
          FModel.SetSymbolScope(FModel.SymbolCount, CallableScopeId);
          Inc(ParamCount);
        end;
      end;
    end
    else if Child.NodeKind = gnkBeginBlock then
    begin
      RegisterProcedureBody(ANode.Text, Child, ANode, AOwnerUnitId);
      Break;
    end;
  end;

  FModel.SetSymbolParamCount(SymbolId, ParamCount);
  FModel.SetSymbolParamSignature(SymbolId, GetParamSignature(ANode));
  FCurrentScopeId := SavedScopeId;
end;

procedure TSemanticAnalyzer.ProcessEnumType(const ANode: TGreenNode;
  const AOwnerUnitId: string; const ATypeId: LongInt);
var
  I: LongInt;
  Child: TGreenNode;
  Ordinal: Int64;
begin
  if ANode = nil then
    Exit;
  Ordinal := 0;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkIdentifier) then
    begin
      FModel.AddSymbol(Child.Text, 'enum-value', AOwnerUnitId, ATypeId,
        Child.ByteOffset);
      FModel.AddConstValue(Child.Text, Ordinal);
      Inc(Ordinal);
    end;
  end;
end;

procedure TSemanticAnalyzer.ProcessRecordFields(const ANode: TGreenNode;
  const AOwnerUnitId: string; const ATypeId: LongInt);
var
  I: LongInt;
  Child: TGreenNode;
  RecordScopeId: LongInt;
  FieldTypeId: LongInt;
  TypeChild: TGreenNode;
  J: LongInt;
  FieldIndex: LongInt;
  RecName: string;
begin
  if ANode = nil then
    Exit;
  RecName := FModel.TypeAt(ATypeId - 1).Name;
  RecordScopeId := FModel.AddScope(skRecord, '', FCurrentScopeId);
  FieldIndex := 0;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkVarDecl) then
      Continue;
    FieldTypeId := 0;
    for J := 0 to Child.ChildCount - 1 do
    begin
      TypeChild := Child.ChildAt(J);
      if (TypeChild <> nil) and (TypeChild.NodeKind = gnkIdentifier) then
      begin
        FieldTypeId := ResolveTypeIdForOwner(TypeChild.Text, AOwnerUnitId);
        Break;
      end;
    end;
    FModel.AddSymbol(Child.Text, 'field', AOwnerUnitId, FieldTypeId,
      Child.ByteOffset);
    FModel.SetSymbolScope(FModel.SymbolCount, RecordScopeId);
    FModel.AddConstValue(RecName + '.' + Child.Text + '$idx', FieldIndex);
    Inc(FieldIndex);
  end;
  FModel.AddConstValue(RecName + '$size', FieldIndex * 8);
  FModel.AddConstValue(RecName + '$record', 1);
end;

procedure TSemanticAnalyzer.ProcessClassFields(const ANode: TGreenNode;
  const AOwnerUnitId: string; const ATypeId: LongInt);
var
  I, J: LongInt;
  Child, NameNode: TGreenNode;
  FieldTypeId: LongInt;
  FieldIndex: LongInt;
  ClassScopeId: LongInt;
  ClsName, ParentName, ConstName, FieldName: string;
  ParentFieldVal: Int64;
  DotPos, IdxPos: LongInt;
  ParentTypeId: LongInt;
  SymbolId: LongInt;
begin
  if ANode = nil then
    Exit;
  ClassScopeId := FModel.AddScope(skRecord, '', FCurrentScopeId);
  ClsName := FModel.TypeAt(ATypeId - 1).Name;
  FieldIndex := 1;
  ParentName := '';
  if (ANode.ChildCount > 0) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) then
    ParentName := ANode.ChildAt(0).Text
  else if (ATypeId > 0) and (ATypeId <= FModel.TypeCount) then
  begin
    ParentTypeId := FModel.TypeAt(ATypeId - 1).ParentTypeId;
    if (ParentTypeId > 0) and (ParentTypeId <= FModel.TypeCount) then
      ParentName := FModel.TypeAt(ParentTypeId - 1).Name;
  end;
  if ParentName <> '' then
  begin
    if FModel.LookupConstValue(ParentName + '$size', ParentFieldVal) then
    begin
      FieldIndex := LongInt(ParentFieldVal) div 8;
      for J := 0 to FModel.ConstValueCount - 1 do
      begin
        ConstName := FModel.ConstValueNameAt(J);
        if (Pos(ParentName + '.', ConstName) = 1) and
          (Pos('$idx', ConstName) > 0) then
        begin
          DotPos := Pos('.', ConstName);
          IdxPos := Pos('$idx', ConstName);
          FieldName := Copy(ConstName, DotPos + 1, IdxPos - DotPos - 1);
          FModel.AddConstValue(
            ClsName + '.' + FieldName + '$idx',
            FModel.ConstValueAt(J));
        end
        else if (Pos(ParentName + '.', ConstName) = 1) and
          (Pos('$str', ConstName) > 0) then
        begin
          DotPos := Pos('.', ConstName);
          IdxPos := Pos('$str', ConstName);
          FieldName := Copy(ConstName, DotPos + 1, IdxPos - DotPos - 1);
          FModel.AddConstValue(
            ClsName + '.' + FieldName + '$str',
            FModel.ConstValueAt(J));
        end
        else if (Pos(ParentName + '.', ConstName) = 1) and
          (Pos('$ptr', ConstName) > 0) then
        begin
          DotPos := Pos('.', ConstName);
          IdxPos := Pos('$ptr', ConstName);
          FieldName := Copy(ConstName, DotPos + 1, IdxPos - DotPos - 1);
          FModel.AddConstValue(
            ClsName + '.' + FieldName + '$ptr',
            FModel.ConstValueAt(J));
        end;
      end;
    end;
    if FModel.LookupConstValue(ParentName + '$vmt_count', ParentFieldVal) then
    begin
      FModel.AddConstValue(ClsName + '$vmt_count', ParentFieldVal);
      for J := 0 to FModel.ConstValueCount - 1 do
      begin
        ConstName := FModel.ConstValueNameAt(J);
        if (Pos(ParentName + '$vmt_slot_', ConstName) = 1) then
        begin
          FieldName := Copy(ConstName,
            Length(ParentName + '$vmt_slot_') + 1, Length(ConstName));
          FModel.AddConstValue(
            ClsName + '$vmt_slot_' + FieldName,
            FModel.ConstValueAt(J));
        end;
      end;
      for J := 0 to ParentFieldVal - 1 do
      begin
        ConstName := ParentName + '$vmt_func_' + IntToStr(J);
        if FModel.LookupStringConstValue(ConstName, FieldName) then
          FModel.AddStringConstValue(
            ClsName + '$vmt_func_' + IntToStr(J), FieldName);
      end;
    end;
    FModel.AddStringConstValue(ClsName + '$parent_class', ParentName);
  end;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if Child.NodeKind = gnkClassField then
    begin
      FieldTypeId := 0;
      if Child.ChildCount > 0 then
      begin
        NameNode := Child.ChildAt(0);
        if (NameNode <> nil) and (NameNode.NodeKind = gnkIdentifier) then
          FieldTypeId := ResolveTypeIdForOwner(NameNode.Text, AOwnerUnitId);
      end;
      FModel.AddSymbol(Child.Text, 'field', AOwnerUnitId, FieldTypeId,
        Child.ByteOffset);
      FModel.SetSymbolScope(FModel.SymbolCount, ClassScopeId);
      FModel.AddConstValue(
        ClsName + '.' + Child.Text + '$idx',
        FieldIndex);
      if (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        (FModel.LookupConstValue(Child.ChildAt(0).Text + '$size', ParentFieldVal) or
         SameText(Child.ChildAt(0).Text, ClsName)) then
        FModel.AddConstValue(
          ClsName + '.' + Child.Text + '$ptr', 1);
      if (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        (SameText(Child.ChildAt(0).Text, 'String') or
         SameText(Child.ChildAt(0).Text, 'AnsiString')) then
      begin
        FModel.AddConstValue(ClsName + '.' + Child.Text + '$str', 1);
        Inc(FieldIndex, 2);
      end
      else if (Child.ChildCount > 0) and (Child.ChildAt(0) <> nil) and
        FModel.LookupConstValue(Child.ChildAt(0).Text + '$record', ParentFieldVal) and
        FModel.LookupConstValue(Child.ChildAt(0).Text + '$size', ParentFieldVal) then
      begin
        for J := 0 to FModel.ConstValueCount - 1 do
        begin
          ConstName := FModel.ConstValueNameAt(J);
          if (Pos(Child.ChildAt(0).Text + '.', ConstName) = 1) and
            (Pos('$idx', ConstName) > 0) then
          begin
            DotPos := Pos('.', ConstName);
            IdxPos := Pos('$idx', ConstName);
            FieldName := Copy(ConstName, DotPos + 1, IdxPos - DotPos - 1);
            FModel.AddConstValue(
              ClsName + '.' + Child.Text + '.' + FieldName + '$idx',
              FieldIndex + FModel.ConstValueAt(J));
          end;
        end;
        Inc(FieldIndex, ParentFieldVal div 8);
      end
      else
        Inc(FieldIndex);
    end
    else if Child.NodeKind = gnkClassMethod then
    begin
      if Child.ChildCount > 0 then
      begin
        NameNode := Child.ChildAt(0);
        if (NameNode <> nil) and (NameNode.NodeKind = gnkIdentifier) then
        begin
          SymbolId := FModel.AddSymbol(
            ClsName + '.' + NameNode.Text,
            'method', AOwnerUnitId, ATypeId, Child.ByteOffset);
          FModel.SetSymbolParamCount(SymbolId, CountDeclParams(Child));
          FModel.SetSymbolParamSignature(SymbolId, GetParamSignature(Child));
          FModel.SetSymbolScope(SymbolId, ClassScopeId);
          if Pos(';virtual', Child.Text) > 0 then
          begin
            if not FModel.LookupConstValue(ClsName + '$vmt_count', ParentFieldVal) then
              ParentFieldVal := 0;
            FModel.AddConstValue(
              ClsName + '$vmt_slot_' + NameNode.Text, ParentFieldVal);
            FModel.AddStringConstValue(
              ClsName + '$vmt_func_' + IntToStr(ParentFieldVal),
              ClsName + '.' + NameNode.Text);
            FModel.AddConstValue(ClsName + '$vmt_count', ParentFieldVal + 1);
          end
          else if Pos(';override', Child.Text) > 0 then
          begin
            if FModel.LookupConstValue(
              ParentName + '$vmt_slot_' + NameNode.Text, ParentFieldVal) then
            begin
              FModel.AddConstValue(
                ClsName + '$vmt_slot_' + NameNode.Text, ParentFieldVal);
              FModel.AddStringConstValue(
                ClsName + '$vmt_func_' + IntToStr(ParentFieldVal),
                ClsName + '.' + NameNode.Text);
            end;
          end;
          if (Child.ChildCount > 1) and (Child.ChildAt(1) <> nil) and
            (Child.ChildAt(1).NodeKind = gnkIdentifier) and
            (FModel.LookupConstValue(Child.ChildAt(1).Text + '$size', ParentFieldVal) or
             SameText(Child.ChildAt(1).Text, ClsName)) then
            FModel.AddConstValue(
              ClsName + '$ret_ptr_' + NameNode.Text, 1);
        end;
      end;
    end
    else if Child.NodeKind = gnkClassProperty then
    begin
      for J := 0 to Child.ChildCount - 1 do
      begin
        NameNode := Child.ChildAt(J);
        if (NameNode <> nil) and (NameNode.NodeKind = gnkIdentifier) then
        begin
          if Pos('read:', NameNode.Text) = 1 then
            FModel.AddStringConstValue(
              ClsName + '.' + Child.Text + '$read',
              Copy(NameNode.Text, 6, Length(NameNode.Text)))
          else if Pos('write:', NameNode.Text) = 1 then
            FModel.AddStringConstValue(
              ClsName + '.' + Child.Text + '$write',
              Copy(NameNode.Text, 7, Length(NameNode.Text)));
        end;
      end;
    end;
  end;
  FModel.AddConstValue(
    ClsName + '$size',
    FieldIndex * 8);
  if not FModel.LookupConstValue(ClsName + '$vmt_count', ParentFieldVal) then
    FModel.AddConstValue(ClsName + '$vmt_count', 0);
end;

procedure TSemanticAnalyzer.ProcessTypeSection(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I, J: LongInt;
  Child, TypeChild: TGreenNode;
  SymbolId: LongInt;
  TypeId: LongInt;
  ParentTypeId: LongInt;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkTypeDecl) then
      Continue;
    if Child.Text = '' then
      Continue;
    TypeId := FModel.AddType(Child.Text, 'declared');
    SymbolId := FModel.AddSymbol(Child.Text, 'type', AOwnerUnitId, TypeId,
      Child.ByteOffset);
    if FCurrentScopeId > 0 then
      FModel.SetSymbolScope(SymbolId, FCurrentScopeId);
    for J := 0 to Child.ChildCount - 1 do
    begin
      TypeChild := Child.ChildAt(J);
      if TypeChild = nil then
        Continue;
      if TypeChild.NodeKind = gnkEnumType then
        ProcessEnumType(TypeChild, AOwnerUnitId, TypeId)
      else if TypeChild.NodeKind = gnkRecordType then
        ProcessRecordFields(TypeChild, AOwnerUnitId, TypeId)
      else if TypeChild.NodeKind = gnkClassType then
      begin
        ParentTypeId := 0;
        if TypeChild.ChildCount > 0 then
        begin
          if TypeChild.ChildAt(0).NodeKind = gnkIdentifier then
            ParentTypeId := ResolveTypeIdForOwner(
              TypeChild.ChildAt(0).Text,
              AOwnerUnitId
            );
        end
        else
          ParentTypeId := ImplicitSystemObjectParentTypeId(Child.Text);
        if ParentTypeId > 0 then
          FModel.SetTypeParent(TypeId, ParentTypeId);
        ProcessClassFields(TypeChild, AOwnerUnitId, TypeId);
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.WalkDeclarations(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I: LongInt;
  Child: TGreenNode;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    case Child.NodeKind of
      gnkVarSection:
        ProcessVarSection(Child, AOwnerUnitId);
      gnkConstSection:
        ProcessConstSection(Child, AOwnerUnitId);
      gnkTypeSection:
        ProcessTypeSection(Child, AOwnerUnitId);
      gnkProcedureDecl:
        ProcessProcedureDecl(Child, AOwnerUnitId);
      gnkFunctionDecl:
        ProcessFunctionDecl(Child, AOwnerUnitId);
      gnkInterfaceSection, gnkImplementationSection:
        WalkDeclarations(Child, AOwnerUnitId);
    end;
  end;
end;

procedure TSemanticAnalyzer.SeedDeclarations;
var
  OwnerUnitId: string;
  RootNode: TGreenNode;
begin
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  OwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkDeclarations(RootNode, OwnerUnitId);
end;

procedure TSemanticAnalyzer.WalkAssignmentStatements(const ANode: TGreenNode);
var
  I: LongInt;
  Child, RhsNode, BranchNode: TGreenNode;
  LhsSymbolId, RhsSymbolId: LongInt;
  LhsTypeId, RhsTypeId: LongInt;
  Value, CondValue: Int64;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if (Child.NodeKind = gnkProcedureDecl) or
      (Child.NodeKind = gnkFunctionDecl) then
      Continue;
    if Child.NodeKind = gnkIfStatement then
    begin
      if (Child.ChildCount >= 2) and
        EvaluateIntegerConstant(Child.ChildAt(0), CondValue) then
      begin
        if CondValue <> 0 then
          BranchNode := Child.ChildAt(1)
        else if Child.ChildCount >= 3 then
          BranchNode := Child.ChildAt(2)
        else
          BranchNode := nil;
        if BranchNode <> nil then
          WalkAssignmentStatements(BranchNode);
      end
      else
        WalkAssignmentStatements(Child);
      Continue;
    end;
    if Child.NodeKind = gnkForStatement then
    begin
      UnrollAssignmentForLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkWhileStatement then
    begin
      UnrollAssignmentWhileLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkRepeatStatement then
    begin
      UnrollAssignmentRepeatLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkAssignmentStatement then
    begin
      LhsSymbolId := FindSymbolByName(Child.Text);
      if LhsSymbolId = 0 then
        Continue;
      LhsTypeId := FModel.SymbolTypeId(LhsSymbolId);
      RhsNode := nil;
      if Child.ChildCount >= 2 then
        RhsNode := Child.ChildAt(1)
      else if (Child.ChildCount = 1) and
        (Child.ChildAt(0).NodeKind <> gnkIdentifier) and
        (Child.ChildAt(0).NodeKind <> gnkDotAccess) and
        (Child.ChildAt(0).NodeKind <> gnkArrayAccess) then
        RhsNode := Child.ChildAt(0);
      if RhsNode <> nil then
      begin
        if EvaluateIntegerConstant(RhsNode, Value) then
          FModel.AddVarInitValue(Child.Text, Value)
        else
          FModel.RemoveVarInitValue(Child.Text);
      end;
    end
    else
      WalkAssignmentStatements(Child);
  end;
end;

procedure TSemanticAnalyzer.UnrollAssignmentForLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  LoopVar: string;
  StartValue, EndValue, IterValue: Int64;
  Direction: string;
  BodyNode: TGreenNode;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 4) then
    Exit;
  if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
    Exit;
  LoopVar := ANode.ChildAt(0).Text;
  if not EvaluateIntegerConstant(ANode.ChildAt(1), StartValue) then
    Exit;
  if not EvaluateIntegerConstant(ANode.ChildAt(2), EndValue) then
    Exit;
  Direction := ANode.Text;
  BodyNode := ANode.ChildAt(3);
  IterCount := 0;
  IterValue := StartValue;
  if SameText(Direction, 'to') then
  begin
    while (IterValue <= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkAssignmentStatements(BodyNode);
      Inc(IterValue);
      Inc(IterCount);
    end;
  end
  else if SameText(Direction, 'downto') then
  begin
    while (IterValue >= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkAssignmentStatements(BodyNode);
      Dec(IterValue);
      Inc(IterCount);
    end;
  end;
end;

procedure TSemanticAnalyzer.UnrollAssignmentWhileLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  CondNode, BodyNode: TGreenNode;
  CondValue: Int64;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  CondNode := ANode.ChildAt(0);
  BodyNode := ANode.ChildAt(1);
  IterCount := 0;
  while IterCount < MaxIterations do
  begin
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue = 0 then
      Exit;
    WalkAssignmentStatements(BodyNode);
    Inc(IterCount);
  end;
end;

procedure TSemanticAnalyzer.UnrollAssignmentRepeatLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  BodyNode, CondNode: TGreenNode;
  CondValue: Int64;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  BodyNode := ANode.ChildAt(0);
  CondNode := ANode.ChildAt(1);
  IterCount := 0;
  while IterCount < MaxIterations do
  begin
    WalkAssignmentStatements(BodyNode);
    Inc(IterCount);
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue <> 0 then
      Exit;
  end;
end;

procedure TSemanticAnalyzer.CheckAssignmentTypes;
var
  RootNode: TGreenNode;
begin
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkAssignmentStatements(RootNode);
end;

function TSemanticAnalyzer.EvaluateIntegerConstant(const ANode: TGreenNode;
  out AValue: Int64): Boolean;
var
  Parsed: Int64;
  ParseCode: Word;
  Left, Right: Int64;
  Op: string;
  BodyNode, DeclNode: TGreenNode;
  ParamSnaps: TParamSnapshots;
begin
  AValue := 0;
  if ANode = nil then
    Exit(False);
  case ANode.NodeKind of
    gnkIntegerLiteral:
      begin
        Val(ANode.Text, Parsed, ParseCode);
        if ParseCode <> 0 then
          Exit(False);
        AValue := Parsed;
        Exit(True);
      end;
    gnkIdentifier:
      begin
        if SameText(ANode.Text, 'true') then
        begin
          AValue := 1;
          Exit(True);
        end;
        if SameText(ANode.Text, 'false') then
        begin
          AValue := 0;
          Exit(True);
        end;
        if FModel.LookupConstValue(ANode.Text, Parsed) then
        begin
          AValue := Parsed;
          Exit(True);
        end;
        if FModel.LookupVarInitValue(ANode.Text, Parsed) then
        begin
          AValue := Parsed;
          Exit(True);
        end;
        if (not FNoFold) and
          LookupProcedureBody(ANode.Text, BodyNode, DeclNode) and
          (BodyNode <> nil) and
          not IsCurrentlyInlining(ANode.Text) then
        begin
          PushInlining(ANode.Text);
          ParamSnaps := nil;
          try
            WalkAssignmentStatements(BodyNode);
          finally
            PopInlining;
            RestoreCallArgs(ParamSnaps);
          end;
          if FModel.LookupVarInitValue(ANode.Text, Parsed) then
          begin
            AValue := Parsed;
            Exit(True);
          end;
        end;
        Exit(False);
      end;
    gnkFunctionCall:
      begin
        if LookupProcedureBody(ANode.Text, BodyNode, DeclNode) and
          (BodyNode <> nil) and
          not IsCurrentlyInlining(ANode.Text) then
        begin
          PushInlining(ANode.Text);
          ParamSnaps := BindCallArgs(DeclNode, ANode, 1);
          try
            WalkAssignmentStatements(BodyNode);
          finally
            PopInlining;
            RestoreCallArgs(ParamSnaps);
          end;
          if FModel.LookupVarInitValue(ANode.Text, Parsed) then
          begin
            AValue := Parsed;
            Exit(True);
          end;
        end;
        Exit(False);
      end;
    gnkUnaryExpression:
      begin
        if ANode.ChildCount < 1 then
          Exit(False);
        if not EvaluateIntegerConstant(ANode.ChildAt(0), Parsed) then
          Exit(False);
        Op := ANode.Text;
        if Op = '-' then
          AValue := -Parsed
        else if Op = '+' then
          AValue := Parsed
        else if SameText(Op, 'not') then
          AValue := Ord(Parsed = 0)
        else
          Exit(False);
        Exit(True);
      end;
    gnkBinaryExpression:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if not EvaluateIntegerConstant(ANode.ChildAt(0), Left) then
          Exit(False);
        if not EvaluateIntegerConstant(ANode.ChildAt(1), Right) then
          Exit(False);
        Op := ANode.Text;
        if Op = '+' then
          AValue := Left + Right
        else if Op = '-' then
          AValue := Left - Right
        else if Op = '*' then
          AValue := Left * Right
        else if SameText(Op, 'div') then
        begin
          if Right = 0 then
          begin
            EmitSemaError(
              'sema.division-by-zero',
              'division by zero in constant expression',
              ANode.ByteOffset
            );
            Exit(False);
          end;
          AValue := Left div Right;
        end
        else if SameText(Op, 'mod') then
        begin
          if Right = 0 then
          begin
            EmitSemaError(
              'sema.division-by-zero',
              'division by zero in constant expression',
              ANode.ByteOffset
            );
            Exit(False);
          end;
          AValue := Left mod Right;
        end
        else if Op = '=' then
          AValue := Ord(Left = Right)
        else if Op = '<>' then
          AValue := Ord(Left <> Right)
        else if Op = '<' then
          AValue := Ord(Left < Right)
        else if Op = '>' then
          AValue := Ord(Left > Right)
        else if Op = '<=' then
          AValue := Ord(Left <= Right)
        else if Op = '>=' then
          AValue := Ord(Left >= Right)
        else if SameText(Op, 'and') then
          AValue := Ord((Left <> 0) and (Right <> 0))
        else if SameText(Op, 'or') then
          AValue := Ord((Left <> 0) or (Right <> 0))
        else
          Exit(False);
        Exit(True);
      end;
  end;
  Result := False;
end;


function TSemanticAnalyzer.EvaluateStringConstant(const ANode: TGreenNode;
  out AValue: string): Boolean;
var
  Op, Left, Right: string;
begin
  AValue := '';
  if ANode = nil then
    Exit(False);
  case ANode.NodeKind of
    gnkStringLiteral:
      begin
        AValue := DecodePascalStringLiteral(ANode.Text);
        Exit(True);
      end;
    gnkIdentifier:
      begin
        if FModel.LookupStringConstValue(ANode.Text, Left) then
        begin
          AValue := Left;
          Exit(True);
        end;
        Exit(False);
      end;
    gnkBinaryExpression:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        Op := ANode.Text;
        if Op <> '+' then
          Exit(False);
        if not EvaluateStringConstant(ANode.ChildAt(0), Left) then
          Exit(False);
        if not EvaluateStringConstant(ANode.ChildAt(1), Right) then
          Exit(False);
        AValue := Left + Right;
        Exit(True);
      end;
  end;
  Result := False;
end;

function DecodePascalStringLiteral(const AText: string): string;
var
  Raw: string;
  Index: SizeInt;
begin
  Result := '';
  if Length(AText) < 2 then
    Exit;
  if (AText[1] <> '''') or (AText[Length(AText)] <> '''') then
    Exit;
  Raw := Copy(AText, 2, Length(AText) - 2);
  Index := 1;
  while Index <= Length(Raw) do
  begin
    if (Raw[Index] = '''') and (Index < Length(Raw)) and (Raw[Index + 1] = '''') then
    begin
      Result := Result + '''';
      Inc(Index, 2);
    end
    else
    begin
      Result := Result + Raw[Index];
      Inc(Index);
    end;
  end;
end;

function TSemanticAnalyzer.EncodeRuntimeIntExprFold(
  const ANode: TGreenNode; out ABlob: string): Boolean;

  function NeedsFoldFallback(const N: TGreenNode): Boolean;
  var
    I: LongInt;
    Child: TGreenNode;
  begin
    if N = nil then
      Exit(False);
    if (N.NodeKind = gnkIdentifier) and (N.Text <> '') and
      not IsRuntimeVar(N.Text) then
      Exit(True);
    if N.NodeKind = gnkFunctionCall then
      Exit(True);
    for I := 0 to N.ChildCount - 1 do
    begin
      Child := N.ChildAt(I);
      if (Child <> nil) and NeedsFoldFallback(Child) then
        Exit(True);
    end;
    Result := False;
  end;

var
  Folded: Int64;
  FuncName, ArgName: string;
  StrCallIdx, StrCallArgCount, K, ArgIndex, DotPos: LongInt;
  BranchNode, DeclNode, RhsNode: TGreenNode;
  Operand: string;
begin
  ABlob := '';
  if ANode = nil then
    Exit(False);
  if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, 'nil') then
  begin
    ABlob := 'null' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    (IsRuntimeStrVar(ANode.ChildAt(1).Text) or
     IsRuntimeArrVar(ANode.ChildAt(1).Text)) then
  begin
    if LookupProcedureBody(ANode.ChildAt(1).Text, BranchNode, DeclNode) then
    begin
      Inc(FBlockLabelCounter);
      Operand := '$len_tmp_' + IntToStr(FBlockLabelCounter);
      RegisterRuntimeVar(Operand);
      RegisterRuntimeStrVar(Operand);
      FModel.AddTypedHirNode('var-decl-str-runtime', Operand, 0, 0, Operand);
      FModel.AddTypedHirNode(
        'assign-str-call-runtime', ANode.ChildAt(1).Text, 0, 0, Operand
      );
      ABlob := 'var ' + Operand + '$len' + #10;
    end
    else
      ABlob := 'var ' + ANode.ChildAt(1).Text + '$len' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    (FCurrentMethodClass <> '') and
    FModel.LookupConstValue(
      FCurrentMethodClass + '.' + ANode.ChildAt(1).Text + '$str', Folded) and
    FModel.LookupConstValue(
      FCurrentMethodClass + '.' + ANode.ChildAt(1).Text + '$idx', Folded) then
  begin
    ABlob := 'field self ' + IntToStr(Folded + 1) + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 3) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    SameText(ANode.ChildAt(0).Text, 'Pos') then
  begin
    ABlob := '';
    if (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkStringLiteral) then
      ABlob := ABlob + 'strlit ' + ANode.ChildAt(1).Text + #10
    else if (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
      IsRuntimeStrVar(ANode.ChildAt(1).Text) then
      ABlob := ABlob + 'strvar ' + ANode.ChildAt(1).Text + #10;
    if (ANode.ChildAt(2) <> nil) and
      (ANode.ChildAt(2).NodeKind = gnkIdentifier) and
      IsRuntimeStrVar(ANode.ChildAt(2).Text) then
      ABlob := ABlob + 'strvar ' + ANode.ChildAt(2).Text + #10;
    if ABlob <> '' then
    begin
      ABlob := ABlob + 'strpos' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (SameText(ANode.ChildAt(0).Text, 'Ord') or
     SameText(ANode.ChildAt(0).Text, 'Chr') or
     SameText(ANode.ChildAt(0).Text, 'Abs') or
     SameText(ANode.ChildAt(0).Text, 'Pred') or
     SameText(ANode.ChildAt(0).Text, 'Succ')) then
  begin
    if (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkStringLiteral) and
      (Length(ANode.ChildAt(1).Text) = 3) and
      (ANode.ChildAt(1).Text[1] = '''') then
    begin
      ABlob := 'int ' + IntToStr(Ord(ANode.ChildAt(1).Text[2])) + #10;
      if SameText(ANode.ChildAt(0).Text, 'Pred') then
        ABlob := ABlob + 'int 1' + #10 + 'sub' + #10
      else if SameText(ANode.ChildAt(0).Text, 'Succ') then
        ABlob := ABlob + 'int 1' + #10 + 'add' + #10
      else if SameText(ANode.ChildAt(0).Text, 'Abs') then
        ABlob := ABlob + 'abs' + #10;
      Exit(True);
    end;
    if EncodeRuntimeIntExprFold(ANode.ChildAt(1), ABlob) then
    begin
      if SameText(ANode.ChildAt(0).Text, 'Pred') then
        ABlob := ABlob + 'int 1' + #10 + 'sub' + #10
      else if SameText(ANode.ChildAt(0).Text, 'Succ') then
        ABlob := ABlob + 'int 1' + #10 + 'add' + #10
      else if SameText(ANode.ChildAt(0).Text, 'Abs') then
        ABlob := ABlob + 'abs' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) then
  begin
    ABlob := '';
    StrCallArgCount := 0;
    for StrCallIdx := 1 to ANode.ChildCount - 1 do
    begin
      if (ANode.ChildAt(StrCallIdx) <> nil) and
        (ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) and
        IsRuntimeStrVar(ANode.ChildAt(StrCallIdx).Text) then
      begin
        ABlob := ABlob + 'strvar ' + ANode.ChildAt(StrCallIdx).Text + #10;
        Inc(StrCallArgCount, 2);
      end
      else if (ANode.ChildAt(StrCallIdx) <> nil) and
        (ANode.ChildAt(StrCallIdx).NodeKind = gnkStringLiteral) then
      begin
        ABlob := ABlob + 'strlit ' + ANode.ChildAt(StrCallIdx).Text + #10;
        Inc(StrCallArgCount, 2);
      end
      else if EncodeRuntimeIntExprFold(ANode.ChildAt(StrCallIdx), FuncName) then
      begin
        ABlob := ABlob + FuncName;
        Inc(StrCallArgCount);
      end
      else
        Exit(False);
    end;
    if LookupProcedureBody(ANode.ChildAt(0).Text, BranchNode, DeclNode) and
      (DeclNode <> nil) then
    begin
      StrCallIdx := ANode.ChildCount - 1;
      for K := 0 to DeclNode.ChildCount - 1 do
      begin
        if (DeclNode.ChildAt(K) = nil) or
          (DeclNode.ChildAt(K).NodeKind <> gnkParameterList) then
          Continue;
        ArgIndex := 0;
        for DotPos := 0 to DeclNode.ChildAt(K).ChildCount - 1 do
        begin
          RhsNode := DeclNode.ChildAt(K).ChildAt(DotPos);
          if (RhsNode = nil) or (RhsNode.NodeKind <> gnkParameterDecl) then
            Continue;
          Inc(ArgIndex);
          if ArgIndex > StrCallIdx then
          begin
            if RhsNode.ChildCount > 1 then
            begin
              if EncodeRuntimeIntExprFold(
                RhsNode.ChildAt(RhsNode.ChildCount - 1), FuncName) then
              begin
                ABlob := ABlob + FuncName;
                Inc(StrCallArgCount);
              end;
            end;
          end;
        end;
        Break;
      end;
    end;
    if HasOverload(ANode.ChildAt(0).Text) then
    begin
      ArgName := '';
      for StrCallIdx := 1 to ANode.ChildCount - 1 do
      begin
        if (ANode.ChildAt(StrCallIdx) <> nil) and
          ((ANode.ChildAt(StrCallIdx).NodeKind = gnkStringLiteral) or
           ((ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) and
            IsRuntimeStrVar(ANode.ChildAt(StrCallIdx).Text))) then
          ArgName := ArgName + 's'
        else
          ArgName := ArgName + 'i';
      end;
      ABlob := ABlob + 'call ' + MangledNameSig(ANode.ChildAt(0).Text, ArgName) +
        ' ' + IntToStr(StrCallArgCount) + #10;
    end
    else
      ABlob := ABlob + 'call ' + ANode.ChildAt(0).Text + ' ' +
        IntToStr(StrCallArgCount) + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 1) and
    (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkDotAccess) and
    (ANode.ChildAt(0).ChildCount >= 2) and
    (ANode.ChildAt(0).ChildAt(0) <> nil) and
    (ANode.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(0).ChildAt(1) <> nil) and
    (ANode.ChildAt(0).ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    FuncName := LookupClassVar(ANode.ChildAt(0).ChildAt(0).Text);
    if FuncName <> '' then
    begin
      ABlob := '';
      StrCallArgCount := 0;
      for StrCallIdx := 1 to ANode.ChildCount - 1 do
      begin
        if ANode.ChildAt(StrCallIdx) = nil then
          Continue;
        if (ANode.ChildAt(StrCallIdx).NodeKind = gnkStringLiteral) then
        begin
          Inc(FBlockLabelCounter);
          ArgName := '$str_arg_' + IntToStr(FBlockLabelCounter);
          RegisterRuntimeVar(ArgName);
          RegisterRuntimeStrVar(ArgName);
          FModel.AddTypedHirNode('var-decl-str-runtime', ArgName, 0, 0, ArgName);
          FModel.AddTypedHirNode('assign-str-runtime',
            DecodePascalStringLiteral(ANode.ChildAt(StrCallIdx).Text),
            0, 0, ArgName);
          ABlob := ABlob + 'strvar ' + ArgName + #10;
          Inc(StrCallArgCount, 2);
        end
        else if (ANode.ChildAt(StrCallIdx).NodeKind = gnkIdentifier) and
          IsRuntimeStrVar(ANode.ChildAt(StrCallIdx).Text) then
        begin
          ABlob := ABlob + 'strvar ' + ANode.ChildAt(StrCallIdx).Text + #10;
          Inc(StrCallArgCount, 2);
        end
        else if EncodeRuntimeIntExprFold(ANode.ChildAt(StrCallIdx), ArgName) then
        begin
          ABlob := ABlob + ArgName;
          Inc(StrCallArgCount);
        end;
      end;
      if FModel.LookupConstValue(
        FuncName + '$vmt_slot_' + ANode.ChildAt(0).ChildAt(1).Text, Folded) then
      begin
        ABlob := 'var ' + ANode.ChildAt(0).ChildAt(0).Text + #10 +
          ABlob + 'vcall ' + IntToStr(Folded) + ' ' +
          IntToStr(StrCallArgCount);
        if FModel.LookupConstValue(
          FuncName + '$ret_ptr_' + ANode.ChildAt(0).ChildAt(1).Text, Folded) then
          ABlob := ABlob + ' p' + #10
        else
          ABlob := ABlob + #10;
      end
      else
      begin
        ArgName := FuncName;
        while (ArgName <> '') and
          (FModel.FindSymbolByName(ArgName + '.' +
            ANode.ChildAt(0).ChildAt(1).Text) = 0) do
        begin
          Folded := FModel.FindTypeByName(ArgName);
          if (Folded > 0) and (FModel.TypeAt(Folded - 1).ParentTypeId > 0) then
            ArgName := FModel.TypeAt(
              FModel.TypeAt(Folded - 1).ParentTypeId - 1).Name
          else
            ArgName := '';
        end;
        if ArgName = '' then ArgName := FuncName;
        ABlob := 'var ' + ANode.ChildAt(0).ChildAt(0).Text + #10 +
          ABlob + 'call ' + ArgName + '.' +
          ANode.ChildAt(0).ChildAt(1).Text + ' ' +
          IntToStr(StrCallArgCount + 1) + #10;
      end;
      Exit(True);
    end;
  end;
  if NeedsFoldFallback(ANode) then
  begin
    if (not FNoFold) or
      ((ANode.NodeKind = gnkIdentifier) and
       FModel.LookupConstValue(ANode.Text, Folded)) then
      if EvaluateIntegerConstant(ANode, Folded) then
      begin
        ABlob := 'int ' + IntToStr(Folded) + #10;
        Exit(True);
      end;
  end;
  if (FCurrentMethodClass <> '') and (ANode.NodeKind = gnkIdentifier) and
    (ANode.Text <> '') and
    FModel.LookupConstValue(FCurrentMethodClass + '.' + ANode.Text + '$idx', Folded) then
  begin
    ABlob := 'field self ' + IntToStr(Folded);
    if FModel.LookupConstValue(
      FCurrentMethodClass + '.' + ANode.Text + '$ptr', Folded) then
      ABlob := ABlob + ' p' + #10
    else
      ABlob := ABlob + #10;
    Exit(True);
  end;
  if (FCurrentMethodClass <> '') and (ANode.NodeKind = gnkDotAccess) and
    (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    FModel.LookupConstValue(
      FCurrentMethodClass + '.' + ANode.ChildAt(0).Text + '.' +
      ANode.ChildAt(1).Text + '$idx', Folded) then
  begin
    ABlob := 'field self ' + IntToStr(Folded) + #10;
    Exit(True);
  end;
  if (FCurrentMethodClass <> '') and (ANode.NodeKind = gnkIdentifier) and
    (ANode.Text <> '') and
    (FModel.FindSymbolByName(FCurrentMethodClass + '.' + ANode.Text) > 0) then
  begin
    if FModel.LookupConstValue(
      FCurrentMethodClass + '$vmt_slot_' + ANode.Text, Folded) then
    begin
      ABlob := 'var self' + #10 + 'vcall ' + IntToStr(Folded) + ' 0';
      if FModel.LookupConstValue(
        FCurrentMethodClass + '$ret_ptr_' + ANode.Text, Folded) then
        ABlob := ABlob + ' p' + #10
      else
        ABlob := ABlob + #10;
    end
    else
      ABlob := 'var self' + #10 +
        'call ' + FCurrentMethodClass + '.' + ANode.Text + ' 1' + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
  begin
    FuncName := LookupClassVar(ANode.ChildAt(0).Text);
    if (FuncName = '') and (FCurrentMethodClass <> '') and
      FModel.LookupConstValue(
        FCurrentMethodClass + '.' + ANode.ChildAt(0).Text + '$ptr', Folded) and
      FModel.LookupConstValue(
        FCurrentMethodClass + '.' + ANode.ChildAt(0).Text + '$idx', Folded) then
    begin
      ArgName := 'field self ' + IntToStr(Folded) + ' p' + #10;
      FuncName := '';
      for StrCallIdx := 1 to FModel.SymbolCount do
        if (FModel.SymbolAt(StrCallIdx).Name = ANode.ChildAt(0).Text) and
          (FModel.SymbolAt(StrCallIdx).Kind = 'field') then
        begin
          if FModel.SymbolAt(StrCallIdx).TypeId > 0 then
            FuncName := FModel.TypeAt(
              FModel.SymbolAt(StrCallIdx).TypeId - 1).Name;
          Break;
        end;
      if FuncName <> '' then
      begin
        if FModel.LookupConstValue(
          FuncName + '$vmt_slot_' + ANode.ChildAt(1).Text, Folded) then
        begin
          ABlob := ArgName + 'vcall ' + IntToStr(Folded) + ' 0';
          if FModel.LookupConstValue(
            FuncName + '$ret_ptr_' + ANode.ChildAt(1).Text, Folded) then
            ABlob := ABlob + ' p' + #10
          else
            ABlob := ABlob + #10;
        end
        else
          ABlob := ArgName +
            'call ' + FuncName + '.' + ANode.ChildAt(1).Text + ' 1' + #10;
        Exit(True);
      end;
      FuncName := '';
    end;
    if FuncName <> '' then
    begin
      if FModel.LookupStringConstValue(
        FuncName + '.' + ANode.ChildAt(1).Text + '$read', ArgName) then
        ABlob := 'var ' + ANode.ChildAt(0).Text + #10 +
          'call ' + FuncName + '.' + ArgName + ' 1' + #10
      else if FModel.LookupConstValue(
        FuncName + '.' + ANode.ChildAt(1).Text + '$idx', Folded) then
      begin
        ABlob := 'field ' + ANode.ChildAt(0).Text + ' ' + IntToStr(Folded);
        if FModel.LookupConstValue(
          FuncName + '.' + ANode.ChildAt(1).Text + '$ptr', Folded) then
          ABlob := ABlob + ' p' + #10
        else
          ABlob := ABlob + #10;
      end
      else if FModel.LookupConstValue(
        FuncName + '$vmt_slot_' + ANode.ChildAt(1).Text, Folded) then
      begin
        ABlob := 'var ' + ANode.ChildAt(0).Text + #10 +
          'vcall ' + IntToStr(Folded) + ' 0';
        if FModel.LookupConstValue(
          FuncName + '$ret_ptr_' + ANode.ChildAt(1).Text, Folded) then
          ABlob := ABlob + ' p' + #10
        else
          ABlob := ABlob + #10;
      end
      else
      begin
        ArgName := FuncName;
        while (ArgName <> '') and
          (FModel.FindSymbolByName(ArgName + '.' + ANode.ChildAt(1).Text) = 0) do
        begin
          Folded := FModel.FindTypeByName(ArgName);
          if (Folded > 0) and (FModel.TypeAt(Folded - 1).ParentTypeId > 0) then
            ArgName := FModel.TypeAt(
              FModel.TypeAt(Folded - 1).ParentTypeId - 1).Name
          else
            ArgName := '';
        end;
        if ArgName = '' then ArgName := FuncName;
        ABlob := 'var ' + ANode.ChildAt(0).Text + #10 +
          'call ' + ArgName + '.' + ANode.ChildAt(1).Text + ' 1' + #10;
      end;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and
    (ANode.ChildCount >= 2) then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(0), FuncName) and
      EncodeRuntimeIntExprFold(ANode.ChildAt(1), ArgName) then
    begin
      if ANode.Text = '+' then
        ABlob := FuncName + ArgName + 'add' + #10
      else if ANode.Text = '-' then
        ABlob := FuncName + ArgName + 'sub' + #10
      else if ANode.Text = '*' then
        ABlob := FuncName + ArgName + 'mul' + #10
      else if SameText(ANode.Text, 'div') then
        ABlob := FuncName + ArgName + 'div' + #10
      else if SameText(ANode.Text, 'mod') then
        ABlob := FuncName + ArgName + 'mod' + #10
      else
      begin
        Result := EncodeRuntimeIntExpr(ANode, ABlob);
        Exit;
      end;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkUnaryExpression) and
    (ANode.ChildCount >= 1) and (ANode.Text = '-') then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(0), FuncName) then
    begin
      ABlob := FuncName + 'neg' + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkIdentifier) and (ANode.Text = 'Result') and
    (FCurrentRetVarName <> '') then
  begin
    ABlob := 'var ' + FCurrentRetVarName + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkIdentifier) and (ANode.Text <> '') and
    IsRecordVar(ANode.Text) then
  begin
    ABlob := 'recvar ' + ANode.Text + #10;
    Exit(True);
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkArrayAccess) and
    (ANode.ChildAt(0).ChildCount >= 2) and
    (ANode.ChildAt(0).ChildAt(0) <> nil) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    IsRuntimeArrVar(ANode.ChildAt(0).ChildAt(0).Text) and
    FModel.LookupStringConstValue(
      ANode.ChildAt(0).ChildAt(0).Text + '$arr_elem_type', FuncName) then
  begin
    if FModel.LookupConstValue(
      FuncName + '.' + ANode.ChildAt(1).Text + '$idx', Folded) then
    begin
      StrCallIdx := LongInt(Folded);
      if FModel.LookupConstValue(
        ANode.ChildAt(0).ChildAt(0).Text + '$arr_elem_size', Folded) and
        EncodeRuntimeIntExprFold(ANode.ChildAt(0).ChildAt(1), ArgName) then
      begin
        ABlob := 'var ' + ANode.ChildAt(0).ChildAt(0).Text + '$ptr' + #10 +
          ArgName + 'int ' + IntToStr(Folded div 8) + #10 + 'mul' + #10 +
          'int ' + IntToStr(StrCallIdx) + #10 + 'add' + #10 + 'arr_load' + #10;
        Exit(True);
      end;
    end;
  end;
  if (ANode.NodeKind = gnkDotAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (ANode.ChildAt(1) <> nil) and (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    IsRecordVar(ANode.ChildAt(0).Text) then
  begin
    FuncName := LookupRecordVar(ANode.ChildAt(0).Text);
    if (FuncName <> '') and
      FModel.LookupConstValue(
        FuncName + '.' + ANode.ChildAt(1).Text + '$idx', Folded) then
    begin
      ABlob := 'rload ' + ANode.ChildAt(0).Text + ' ' +
        IntToStr(Folded) + #10;
      Exit(True);
    end;
  end;
  if (ANode.NodeKind = gnkArrayAccess) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    IsRuntimeStrVar(ANode.ChildAt(0).Text) then
  begin
    if EncodeRuntimeIntExprFold(ANode.ChildAt(1), FuncName) then
    begin
      ABlob := FuncName + 'strcharload ' + ANode.ChildAt(0).Text + #10;
      Exit(True);
    end;
  end;
  Result := EncodeRuntimeIntExpr(ANode, ABlob);
end;

function TSemanticAnalyzer.EncodeRuntimeBoolExprFold(
  const ANode: TGreenNode; out ABlob: string): Boolean;
var
  LeftBlob, RightBlob, Op, Pred: string;
begin
  ABlob := '';
  if ANode = nil then
    Exit(False);
  if (ANode.NodeKind = gnkUnaryExpression) and
    SameText(ANode.Text, 'not') and (ANode.ChildCount >= 1) then
  begin
    if not EncodeRuntimeBoolExprFold(ANode.ChildAt(0), LeftBlob) then
      Exit(False);
    ABlob := 'int 1' + #10 + LeftBlob + 'zext' + #10 + 'sub' + #10 +
      'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end;
  if ANode.NodeKind <> gnkBinaryExpression then
    Exit(False);
  if ANode.ChildCount < 2 then
    Exit(False);
  Op := ANode.Text;
  if Op = '=' then Pred := 'eq'
  else if Op = '<>' then Pred := 'ne'
  else if Op = '<' then Pred := 'slt'
  else if Op = '<=' then Pred := 'sle'
  else if Op = '>' then Pred := 'sgt'
  else if Op = '>=' then Pred := 'sge'
  else if SameText(Op, 'and') then
  begin
    if not EncodeRuntimeBoolExprFold(ANode.ChildAt(0), LeftBlob) then
      Exit(False);
    if not EncodeRuntimeBoolExprFold(ANode.ChildAt(1), RightBlob) then
      Exit(False);
    ABlob := LeftBlob + 'zext' + #10 + RightBlob + 'zext' + #10 +
      'mul' + #10 + 'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end
  else if SameText(Op, 'or') then
  begin
    if not EncodeRuntimeBoolExprFold(ANode.ChildAt(0), LeftBlob) then
      Exit(False);
    if not EncodeRuntimeBoolExprFold(ANode.ChildAt(1), RightBlob) then
      Exit(False);
    ABlob := LeftBlob + 'zext' + #10 + RightBlob + 'zext' + #10 +
      'add' + #10 + 'int 0' + #10 + 'cmp ne' + #10;
    Exit(True);
  end
  else if SameText(Op, 'is') then
  begin
    if (ANode.ChildAt(0) <> nil) and
      (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
      (ANode.ChildAt(1) <> nil) and
      (ANode.ChildAt(1).NodeKind = gnkIdentifier) then
    begin
      ABlob := 'var ' + ANode.ChildAt(0).Text + #10 +
        'is ' + ANode.ChildAt(1).Text + #10 +
        'int 0' + #10 + 'cmp ne' + #10;
      Exit(True);
    end;
    Exit(False);
  end
  else
    Exit(False);
  if ((ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    IsRuntimeStrVar(ANode.ChildAt(0).Text)) or
    (ANode.ChildAt(0).NodeKind = gnkStringLiteral) or
    ((ANode.ChildAt(1).NodeKind = gnkIdentifier) and
    IsRuntimeStrVar(ANode.ChildAt(1).Text)) or
    (ANode.ChildAt(1).NodeKind = gnkStringLiteral) then
  begin
    LeftBlob := '';
    RightBlob := '';
    if (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
      IsRuntimeStrVar(ANode.ChildAt(0).Text) then
      LeftBlob := 'strvar ' + ANode.ChildAt(0).Text + #10
    else if ANode.ChildAt(0).NodeKind = gnkStringLiteral then
      LeftBlob := 'strlit ' + ANode.ChildAt(0).Text + #10;
    if (ANode.ChildAt(1).NodeKind = gnkIdentifier) and
      IsRuntimeStrVar(ANode.ChildAt(1).Text) then
      RightBlob := 'strvar ' + ANode.ChildAt(1).Text + #10
    else if ANode.ChildAt(1).NodeKind = gnkStringLiteral then
      RightBlob := 'strlit ' + ANode.ChildAt(1).Text + #10;
    if (LeftBlob <> '') and (RightBlob <> '') then
    begin
      ABlob := LeftBlob + RightBlob + 'strcmp ' + Pred + #10 +
        'int 0' + #10 + 'cmp ne' + #10;
      Exit(True);
    end;
  end;
  if not EncodeRuntimeIntExprFold(ANode.ChildAt(0), LeftBlob) then
    Exit(False);
  if not EncodeRuntimeIntExprFold(ANode.ChildAt(1), RightBlob) then
    Exit(False);
  ABlob := LeftBlob + RightBlob + 'cmp ' + Pred + #10;
  Result := True;
end;

procedure TSemanticAnalyzer.WalkHaltCalls(const ANode: TGreenNode);
var
  I, ArgIndex: LongInt;
  Child, Arg, RhsNode, BranchNode, DeclNode: TGreenNode;
  Operand: string;
  Value, CondValue: Int64;
  Decoded, StringValue, FuncName, ArgName, DestroyFuncName: string;
  ReceiverName: string;
  ParamSnaps: TParamSnapshots;
  InhTypeId, InhParentId: LongInt;
  InhMethodName, InhParentName: string;
  DotPos, K: LongInt;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if (Child.NodeKind = gnkProcedureDecl) or
      (Child.NodeKind = gnkFunctionDecl) then
      Continue;
    if Child.NodeKind = gnkIfStatement then
    begin
      if (not FNoFold) and
        (Child.ChildCount >= 2) and
        EvaluateIntegerConstant(Child.ChildAt(0), CondValue) then
      begin
        if CondValue <> 0 then
          BranchNode := Child.ChildAt(1)
        else if Child.ChildCount >= 3 then
          BranchNode := Child.ChildAt(2)
        else
          BranchNode := nil;
        if BranchNode <> nil then
          WalkHaltCalls(BranchNode);
        Continue;
      end;
      if FNoFold and (Child.ChildCount >= 2) and
        EncodeRuntimeBoolExprFold(Child.ChildAt(0), Operand) then
      begin
        LowerRuntimeIfStatement(Child, Operand);
        Continue;
      end;
      WalkHaltCalls(Child);
      Continue;
    end;
    if Child.NodeKind = gnkForStatement then
    begin
      if FNoFold then
        LowerRuntimeForStatement(Child)
      else
        UnrollHaltForLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkWhileStatement then
    begin
      if FNoFold then
        LowerRuntimeWhileStatement(Child)
      else
        UnrollHaltWhileLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkRepeatStatement then
    begin
      if FNoFold then
        LowerRuntimeRepeatStatement(Child)
      else
        UnrollHaltRepeatLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkCaseStatement then
    begin
      if FNoFold then
        LowerRuntimeCaseStatement(Child)
      else
        WalkHaltCalls(Child);
      Continue;
    end;
    if (Child.NodeKind = gnkBreakStatement) and FNoFold then
    begin
      if Length(FBreakLabels) > 0 then
        EmitGotoLabel(FBreakLabels[High(FBreakLabels)]);
      FCurrentBlockTerminated := True;
      Continue;
    end;
    if (Child.NodeKind = gnkContinueStatement) and FNoFold then
    begin
      if Length(FContinueLabels) > 0 then
        EmitGotoLabel(FContinueLabels[High(FContinueLabels)]);
      FCurrentBlockTerminated := True;
      Continue;
    end;
    if (Child.NodeKind = gnkExitStatement) and FNoFold then
    begin
      if (FCurrentRetVarName <> '') and IsRuntimeStrVar(FCurrentRetVarName) then
        FModel.AddTypedHirNode('ret-str-runtime', FCurrentRetVarName, 0, 0, FCurrentRetVarName)
      else if FCurrentRetVarName <> '' then
        FModel.AddTypedHirNode('ret-runtime', FCurrentRetVarName, 0, 0,
          'var ' + FCurrentRetVarName + #10)
      else
        FModel.AddTypedHirNode('ret-runtime', '0', 0, 0, 'int 0' + #10);
      FCurrentBlockTerminated := True;
      Continue;
    end;
    if Child.NodeKind = gnkAssignmentStatement then
    begin
      Decoded := Child.Text;
      if (Decoded = 'Result') and (FCurrentRetVarName <> '') then
        Decoded := FCurrentRetVarName;
      if (Child.ChildCount >= 1) and
        (Child.ChildAt(0).NodeKind = gnkDotAccess) and
        (Child.ChildAt(0).ChildCount >= 2) then
      begin
        Decoded := Child.ChildAt(0).ChildAt(0).Text + '.' +
          Child.ChildAt(0).ChildAt(1).Text;
        if FNoFold and IsRecordVar(Child.ChildAt(0).ChildAt(0).Text) then
        begin
          StringValue := LookupRecordVar(Child.ChildAt(0).ChildAt(0).Text);
          if (StringValue <> '') and
            FModel.LookupConstValue(
              StringValue + '.' + Child.ChildAt(0).ChildAt(1).Text + '$idx',
              Value) then
          begin
            Arg := nil;
            if Child.ChildCount >= 2 then
              Arg := Child.ChildAt(1);
            if (Arg <> nil) and EncodeRuntimeIntExprFold(Arg, Operand) then
              FModel.AddTypedHirNode(
                'record-field-store-runtime', Decoded, 0, 0,
                Child.ChildAt(0).ChildAt(0).Text + #9 +
                IntToStr(Value) + #9 + Operand
              );
            Continue;
          end;
        end;
        if FNoFold and
          (Child.ChildAt(0).ChildAt(0) <> nil) and
          (Child.ChildAt(0).ChildAt(0).NodeKind = gnkArrayAccess) and
          (Child.ChildAt(0).ChildAt(0).ChildCount >= 2) and
          (Child.ChildAt(0).ChildAt(0).ChildAt(0) <> nil) and
          IsRuntimeArrVar(Child.ChildAt(0).ChildAt(0).ChildAt(0).Text) then
        begin
          FuncName := Child.ChildAt(0).ChildAt(0).ChildAt(0).Text;
          if FModel.LookupStringConstValue(FuncName + '$arr_elem_type', StringValue) and
            FModel.LookupConstValue(
              StringValue + '.' + Child.ChildAt(0).ChildAt(1).Text + '$idx', Value) and
            FModel.LookupConstValue(FuncName + '$arr_elem_size', CondValue) then
          begin
            Arg := nil;
            if Child.ChildCount >= 2 then
              Arg := Child.ChildAt(1);
            if (Arg <> nil) and
              EncodeRuntimeIntExprFold(Child.ChildAt(0).ChildAt(0).ChildAt(1), Operand) and
              EncodeRuntimeIntExprFold(Arg, StringValue) then
              FModel.AddTypedHirNode(
                'assign-arr-elem-runtime', FuncName, 0, 0,
                FuncName + #9 + Operand + 'int ' + IntToStr(CondValue div 8) +
                #10 + 'mul' + #10 + 'int ' + IntToStr(Value) + #10 + 'add' + #10 +
                #9 + StringValue
              );
            Continue;
          end;
        end;
      end;
      if FNoFold and (Child.ChildCount >= 1) and
        (Child.ChildAt(0).NodeKind = gnkArrayAccess) and
        (Child.ChildAt(0).ChildCount >= 2) and
        (Child.ChildAt(0).ChildAt(0) <> nil) and
        (Child.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
        IsRuntimeArrVar(Child.ChildAt(0).ChildAt(0).Text) then
      begin
        Decoded := Child.ChildAt(0).ChildAt(0).Text;
        RhsNode := nil;
        if Child.ChildCount >= 2 then
          RhsNode := Child.ChildAt(1);
        if (RhsNode <> nil) and
          EncodeRuntimeIntExprFold(Child.ChildAt(0).ChildAt(1), Operand) and
          EncodeRuntimeIntExprFold(RhsNode, StringValue) then
          FModel.AddTypedHirNode(
            'assign-arr-elem-runtime', Decoded, 0, 0,
            Decoded + #9 + Operand + #9 + StringValue
          );
        Continue;
      end;
      Arg := nil;
      if Child.ChildCount >= 2 then
        Arg := Child.ChildAt(1)
      else if (Child.ChildCount = 1) and
        (Child.ChildAt(0).NodeKind <> gnkIdentifier) and
        (Child.ChildAt(0).NodeKind <> gnkDotAccess) and
        (Child.ChildAt(0).NodeKind <> gnkArrayAccess) then
        Arg := Child.ChildAt(0);
      if FNoFold and (Arg <> nil) and
        (Arg.NodeKind = gnkFunctionCall) and (Arg.ChildCount >= 1) and
        (Arg.ChildAt(0) <> nil) and
        (Arg.ChildAt(0).NodeKind = gnkDotAccess) and
        (Arg.ChildAt(0).ChildCount >= 2) then
      begin
        InhParentName := Arg.ChildAt(0).ChildAt(0).Text;
        StringValue := InhParentName + '.' +
          Arg.ChildAt(0).ChildAt(1).Text;
        if FModel.LookupConstValue(InhParentName + '$size', Value) then
        begin
          if FModel.FindSymbolByName(StringValue) = 0 then
          begin
            InhTypeId := FModel.FindTypeByName(InhParentName);
            while (InhTypeId > 0) and
              (FModel.FindSymbolByName(InhParentName + '.' +
                Arg.ChildAt(0).ChildAt(1).Text) = 0) do
            begin
              if FModel.TypeAt(InhTypeId - 1).ParentTypeId > 0 then
              begin
                InhParentName := FModel.TypeAt(
                  FModel.TypeAt(InhTypeId - 1).ParentTypeId - 1).Name;
                InhTypeId := FModel.FindTypeByName(InhParentName);
              end
              else
                Break;
            end;
            StringValue := InhParentName + '.' +
              Arg.ChildAt(0).ChildAt(1).Text;
          end;
          Operand := Decoded + #9 + StringValue;
          for ArgIndex := 1 to Arg.ChildCount - 1 do
          begin
            RhsNode := Arg.ChildAt(ArgIndex);
            if RhsNode = nil then
              Continue;
            if (RhsNode.NodeKind = gnkStringLiteral) then
            begin
              Inc(FBlockLabelCounter);
              FuncName := '$str_arg_' + IntToStr(FBlockLabelCounter);
              RegisterRuntimeVar(FuncName);
              RegisterRuntimeStrVar(FuncName);
              FModel.AddTypedHirNode('var-decl-str-runtime', FuncName, 0, 0, FuncName);
              FModel.AddTypedHirNode('assign-str-runtime',
                DecodePascalStringLiteral(RhsNode.Text), 0, 0, FuncName);
              Operand := Operand + #9 + 'strvar ' + FuncName + #10;
            end
            else if (RhsNode.NodeKind = gnkIdentifier) and
              IsRuntimeStrVar(RhsNode.Text) then
              Operand := Operand + #9 + 'strvar ' + RhsNode.Text + #10
            else if EncodeRuntimeIntExprFold(RhsNode, StringValue) then
              Operand := Operand + #9 + StringValue;
          end;
          if (FCurrentMethodClass <> '') and
            FModel.LookupConstValue(
              FCurrentMethodClass + '.' + Decoded + '$idx', CondValue) then
          begin
            Inc(FBlockLabelCounter);
            FuncName := '$obj_tmp_' + IntToStr(FBlockLabelCounter);
            Operand := FuncName + #9 +
              Copy(Operand, Pos(#9, Operand) + 1, Length(Operand));
            RegisterRuntimeVar(FuncName);
            RegisterClassVar(FuncName, Arg.ChildAt(0).ChildAt(0).Text);
            FModel.AddTypedHirNode(
              'class-new-runtime', IntToStr(Value), 0, 0, Operand
            );
            if FModel.LookupConstValue(
              Arg.ChildAt(0).ChildAt(0).Text + '$vmt_count', Value) then
              FModel.AddTypedHirNode('vmt-store-runtime',
                Arg.ChildAt(0).ChildAt(0).Text, 0, 0,
                FuncName + #9 + Arg.ChildAt(0).ChildAt(0).Text);
            FModel.AddTypedHirNode('field-store-runtime', Decoded, 0, 0,
              'self' + #9 + IntToStr(CondValue) + #9 +
              'var ' + FuncName + #10);
          end
          else
          begin
            RegisterRuntimeVar(Decoded);
            RegisterClassVar(Decoded, Arg.ChildAt(0).ChildAt(0).Text);
            FModel.AddTypedHirNode(
              'class-new-runtime', IntToStr(Value), 0, 0, Operand
            );
            if FModel.LookupConstValue(
              Arg.ChildAt(0).ChildAt(0).Text + '$vmt_count', Value) then
              FModel.AddTypedHirNode('vmt-store-runtime',
                Arg.ChildAt(0).ChildAt(0).Text, 0, 0,
                Decoded + #9 + Arg.ChildAt(0).ChildAt(0).Text);
          end;
          Continue;
        end;
      end;
      if FNoFold and (Arg <> nil) and
        (Arg.NodeKind = gnkDotAccess) and (Arg.ChildCount >= 2) and
        (Arg.ChildAt(0) <> nil) and (Arg.ChildAt(1) <> nil) then
      begin
        if FModel.LookupConstValue(
          Arg.ChildAt(0).Text + '$size', Value) then
        begin
          InhParentName := Arg.ChildAt(0).Text;
          StringValue := InhParentName + '.' + Arg.ChildAt(1).Text;
          if FModel.FindSymbolByName(StringValue) = 0 then
          begin
            InhTypeId := FModel.FindTypeByName(InhParentName);
            while (InhTypeId > 0) and
              (FModel.FindSymbolByName(InhParentName + '.' +
                Arg.ChildAt(1).Text) = 0) do
            begin
              if FModel.TypeAt(InhTypeId - 1).ParentTypeId > 0 then
              begin
                InhParentName := FModel.TypeAt(
                  FModel.TypeAt(InhTypeId - 1).ParentTypeId - 1).Name;
                InhTypeId := FModel.FindTypeByName(InhParentName);
              end
              else
                Break;
            end;
            StringValue := InhParentName + '.' + Arg.ChildAt(1).Text;
          end;
          Operand := Decoded + #9 + StringValue;
          RegisterRuntimeVar(Decoded);
          RegisterClassVar(Decoded, Arg.ChildAt(0).Text);
          FModel.AddTypedHirNode(
            'class-new-runtime', IntToStr(Value), 0, 0, Operand
          );
          if FModel.LookupConstValue(
            Arg.ChildAt(0).Text + '$vmt_count', Value) then
            FModel.AddTypedHirNode('vmt-store-runtime',
              Arg.ChildAt(0).Text, 0, 0,
              Decoded + #9 + Arg.ChildAt(0).Text);
          Continue;
        end;
      end;
      if Arg <> nil then
      begin
        if FNoFold and IsRuntimeStrVar(Decoded) then
        begin
          if (Arg.NodeKind = gnkStringLiteral) then
          begin
            StringValue := DecodePascalStringLiteral(Arg.Text);
            FModel.AddTypedHirNode(
              'assign-str-runtime', StringValue, 0, 0, Decoded
            );
          end
          else if EvaluateStringConstant(Arg, StringValue) then
            FModel.AddTypedHirNode(
              'assign-str-runtime', StringValue, 0, 0, Decoded
            )
          else if (Arg.NodeKind = gnkIdentifier) and
            IsRuntimeStrVar(Arg.Text) and
            not LookupProcedureBody(Arg.Text, BranchNode, DeclNode) then
            FModel.AddTypedHirNode(
              'assign-str-copy-runtime', Arg.Text, 0, 0, Decoded
            )
          else if (Arg.NodeKind = gnkFunctionCall) and
            (Arg.ChildCount >= 2) and (Arg.ChildAt(0) <> nil) and
            SameText(Arg.ChildAt(0).Text, 'IntToStr') then
          begin
            if EncodeRuntimeIntExprFold(Arg.ChildAt(1), Operand) then
              FModel.AddTypedHirNode(
                'int-to-str-runtime', Decoded, 0, 0,
                Decoded + #9 + Operand
              );
          end
          else if (Arg.NodeKind = gnkFunctionCall) and
            (Arg.ChildCount >= 4) and (Arg.ChildAt(0) <> nil) and
            SameText(Arg.ChildAt(0).Text, 'Copy') then
          begin
            if (Arg.ChildAt(1) <> nil) and
              (Arg.ChildAt(1).NodeKind = gnkIdentifier) and
              IsRuntimeStrVar(Arg.ChildAt(1).Text) and
              EncodeRuntimeIntExprFold(Arg.ChildAt(2), Operand) and
              EncodeRuntimeIntExprFold(Arg.ChildAt(3), StringValue) then
              FModel.AddTypedHirNode(
                'copy-str-runtime', Decoded, 0, 0,
                Decoded + #9 + Arg.ChildAt(1).Text + #9 + Operand + #9 + StringValue
              );
          end
          else if (Arg.NodeKind = gnkIdentifier) and
            (FCurrentMethodClass <> '') and
            FModel.LookupConstValue(
              FCurrentMethodClass + '.' + Arg.Text + '$str', Value) and
            FModel.LookupConstValue(
              FCurrentMethodClass + '.' + Arg.Text + '$idx', Value) then
            FModel.AddTypedHirNode(
              'assign-str-field-load-runtime', Decoded, 0, 0,
              Decoded + #9 + IntToStr(Value)
            )
          else if (Arg.NodeKind = gnkIdentifier) and
            LookupProcedureBody(Arg.Text, BranchNode, DeclNode) and
            IsRuntimeStrVar(Arg.Text) then
            FModel.AddTypedHirNode(
              'assign-str-call-runtime', Arg.Text, 0, 0, Decoded
            )
          else if (Arg.NodeKind = gnkFunctionCall) and
            LookupProcedureBody(Arg.Text, BranchNode, DeclNode) and
            IsRuntimeStrVar(Arg.Text) then
          begin
            Operand := EncodeStrCallArgs(Arg, Decoded);
            FModel.AddTypedHirNode(
              'assign-str-call-runtime', Arg.Text, 0, 0,
              Decoded + #9 + Operand
            );
          end
          else if (Arg.NodeKind = gnkDotAccess) and
            (Arg.ChildCount >= 2) and
            (Arg.ChildAt(0) <> nil) and
            (Arg.ChildAt(1) <> nil) and
            (Arg.ChildAt(0).NodeKind = gnkIdentifier) and
            (Arg.ChildAt(1).NodeKind = gnkIdentifier) and
            (LookupClassVar(Arg.ChildAt(0).Text) <> '') then
          begin
            FuncName := LookupClassVar(Arg.ChildAt(0).Text);
            if FModel.LookupConstValue(
              FuncName + '$vmt_slot_' + Arg.ChildAt(1).Text, Value) then
              FModel.AddTypedHirNode(
                'assign-str-vcall-runtime', Arg.ChildAt(1).Text, 0, 0,
                Decoded + #9 + Arg.ChildAt(0).Text + #9 +
                IntToStr(Value)
              )
            else
              FModel.AddTypedHirNode(
                'assign-str-call-runtime',
                FuncName + '.' + Arg.ChildAt(1).Text, 0, 0,
                Decoded + #9 + 'var ' + Arg.ChildAt(0).Text
              );
          end
          else if (Arg.NodeKind = gnkBinaryExpression) and
            (Arg.Text = '+') and (Arg.ChildCount >= 2) and
            (Arg.ChildAt(0) <> nil) and (Arg.ChildAt(1) <> nil) then
          begin
            StringValue := EmitStrConcatOperand(Arg.ChildAt(0), Decoded);
            if StringValue <> '' then
            begin
              Operand := EmitStrConcatOperand(Arg.ChildAt(1), Decoded);
              if Operand <> '' then
                FModel.AddTypedHirNode(
                  'assign-str-concat-runtime',
                  StringValue + #9 + Operand,
                  0, 0, Decoded
                );
            end;
          end;
        end
        else if FNoFold and (FCurrentMethodClass <> '') and
          FModel.LookupConstValue(
            FCurrentMethodClass + '.' + Decoded + '$str', Value) and
          FModel.LookupConstValue(
            FCurrentMethodClass + '.' + Decoded + '$idx', Value) then
        begin
          if (Arg.NodeKind = gnkStringLiteral) then
          begin
            StringValue := DecodePascalStringLiteral(Arg.Text);
            FModel.AddTypedHirNode(
              'field-store-str-runtime', Decoded, 0, 0,
              'self' + #9 + IntToStr(Value) + #9 + 'lit ' + StringValue
            );
          end
          else if EvaluateStringConstant(Arg, StringValue) then
            FModel.AddTypedHirNode(
              'field-store-str-runtime', Decoded, 0, 0,
              'self' + #9 + IntToStr(Value) + #9 + 'lit ' + StringValue
            )
          else if (Arg.NodeKind = gnkIdentifier) and
            IsRuntimeStrVar(Arg.Text) then
            FModel.AddTypedHirNode(
              'field-store-str-runtime', Decoded, 0, 0,
              'self' + #9 + IntToStr(Value) + #9 + 'var ' + Arg.Text
            )
          else
            FModel.AddTypedHirNode(
              'field-store-str-runtime', Decoded, 0, 0,
              'self' + #9 + IntToStr(Value) + #9 + 'var ' + Decoded
            );
        end
        else if FNoFold and (Arg <> nil) and
          (Arg.NodeKind = gnkFunctionCall) and (Arg.ChildCount >= 1) and
          (Arg.ChildAt(0) <> nil) and
          (Arg.ChildAt(0).NodeKind = gnkIdentifier) and
          (LookupPtrReturnFunc(Arg.ChildAt(0).Text) <> '') then
        begin
          if EncodeRuntimeIntExprFold(Arg, Operand) then
          begin
            RegisterRuntimeVar(Decoded);
            RegisterClassVar(Decoded, LookupPtrReturnFunc(Arg.ChildAt(0).Text));
            FModel.AddTypedHirNode(
              'var-decl-ptr-runtime', Decoded, 0, 0, Decoded);
            FModel.AddTypedHirNode(
              'assign-runtime', Decoded, 0, 0,
              Decoded + #9 + Operand
            );
          end;
        end
        else if FNoFold and IsRecordVar(Decoded) and
          (Arg <> nil) and (Arg.NodeKind = gnkFunctionCall) and
          (Arg.ChildCount >= 1) and (Arg.ChildAt(0) <> nil) and
          (Arg.ChildAt(0).NodeKind = gnkIdentifier) then
        begin
          if LookupProcedureBody(Arg.ChildAt(0).Text, BranchNode, DeclNode) then
          begin
            Operand := Arg.ChildAt(0).Text + #9 + 'recvar ' + Decoded + #10;
            for ArgIndex := 1 to Arg.ChildCount - 1 do
            begin
              RhsNode := Arg.ChildAt(ArgIndex);
              if (RhsNode <> nil) and EncodeRuntimeIntExprFold(RhsNode, StringValue) then
                Operand := Operand + #9 + StringValue;
            end;
            FModel.AddTypedHirNode('call-runtime',
              Arg.ChildAt(0).Text, 0, 0, Operand);
          end;
        end
        else if FNoFold and IsRecordVar(Decoded) and
          (Arg <> nil) and (Arg.NodeKind = gnkIdentifier) and
          IsRecordVar(Arg.Text) then
        begin
          StringValue := LookupRecordVar(Decoded);
          if FModel.LookupConstValue(StringValue + '$size', Value) then
            FModel.AddTypedHirNode(
              'record-copy-runtime', Decoded, 0, 0,
              Decoded + #9 + Arg.Text + #9 + IntToStr(Value div 8)
            );
        end
        else if FNoFold then
        begin
          if EncodeRuntimeIntExprFold(Arg, Operand) then
          begin
            DotPos := Pos('.', Decoded);
            if (DotPos > 0) and (FCurrentMethodClass = '') then
            begin
              ArgName := Copy(Decoded, 1, DotPos - 1);
              FuncName := Copy(Decoded, DotPos + 1, Length(Decoded));
              StringValue := LookupClassVar(ArgName);
              if (StringValue <> '') and
                FModel.LookupStringConstValue(
                  StringValue + '.' + FuncName + '$write', ArgName) then
              begin
                FModel.AddTypedHirNode(
                  'call-runtime',
                  StringValue + '.' + ArgName, 0, 0,
                  StringValue + '.' + ArgName + #9 +
                  'var ' + Copy(Decoded, 1, DotPos - 1) + #10 + #9 +
                  Operand
                );
              end
              else if (StringValue <> '') and
                FModel.LookupConstValue(
                  StringValue + '.' + FuncName + '$idx', Value) then
                FModel.AddTypedHirNode(
                  'field-store-runtime', Decoded, 0, 0,
                  Copy(Decoded, 1, DotPos - 1) + #9 +
                  IntToStr(Value) + #9 + Operand
                )
              else
              begin
                RegisterRuntimeVar(Decoded);
                FModel.AddTypedHirNode(
                  'assign-runtime', Decoded, 0, 0,
                  Decoded + #9 + Operand
                );
              end;
            end
            else if (FCurrentMethodClass <> '') and
              FModel.LookupConstValue(
                FCurrentMethodClass + '.' + Decoded + '$idx', Value) then
              FModel.AddTypedHirNode(
                'field-store-runtime', Decoded, 0, 0,
                'self' + #9 + IntToStr(Value) + #9 + Operand
              )
            else
            begin
              RegisterRuntimeVar(Decoded);
              FModel.AddTypedHirNode(
                'assign-runtime', Decoded, 0, 0,
                Decoded + #9 + Operand
              );
            end;
          end;
        end
        else if EvaluateIntegerConstant(Arg, Value) then
          FModel.AddVarInitValue(Decoded, Value)
        else
          FModel.RemoveVarInitValue(Decoded);
      end;
      Continue;
    end;
    if Child.NodeKind = gnkProcedureCallStatement then
    begin
      if SameText(Child.Text, 'Halt') then
      begin
        Operand := '0';
        Arg := nil;
        if Child.ChildCount >= 1 then
        begin
          Arg := Child.ChildAt(0);
          if (Arg <> nil) and (Arg.NodeKind = gnkFunctionCall) and
            (Arg.ChildCount >= 2) then
            Arg := Arg.ChildAt(1);
        end;
        if FNoFold and (Arg <> nil) then
        begin
          if EncodeRuntimeIntExprFold(Arg, Operand) then
          begin
            FModel.AddTypedHirNode('halt-call-runtime', 'Halt', 0, 0, Operand);
            FCurrentBlockTerminated := True;
            Continue;
          end;
        end;
        if Arg <> nil then
        begin
          if EvaluateIntegerConstant(Arg, Value) then
            Operand := IntToStr(Value);
        end;
        FModel.AddTypedHirNode('halt-call', 'Halt', 0, 0, Operand);
        FCurrentBlockTerminated := True;
        Continue;
      end;
      if SameText(Child.Text, 'WriteLn') or SameText(Child.Text, 'Write') then
      begin
        Arg := nil;
        if (Child.ChildCount >= 1) and
          (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
          Arg := Child.ChildAt(0)
        else
          Arg := Child;
        if FNoFold then
        begin
          if (Arg <> nil) and (Arg.NodeKind = gnkFunctionCall) then
            ArgIndex := 1
          else
            ArgIndex := 0;
          while ArgIndex < Arg.ChildCount do
          begin
            RhsNode := Arg.ChildAt(ArgIndex);
            if RhsNode = nil then
            begin
              Inc(ArgIndex);
              Continue;
            end;
            if RhsNode.NodeKind = gnkStringLiteral then
              FModel.AddTypedHirNode(
                'write-string-runtime', 'Write', 0, 0,
                DecodePascalStringLiteral(RhsNode.Text)
              )
            else if EvaluateStringConstant(RhsNode, StringValue) then
              FModel.AddTypedHirNode(
                'write-string-runtime', 'Write', 0, 0, StringValue
              )
            else if (RhsNode.NodeKind = gnkIdentifier) and
              IsRuntimeStrVar(RhsNode.Text) and
              not LookupProcedureBody(RhsNode.Text, BranchNode, DeclNode) then
              FModel.AddTypedHirNode(
                'write-str-var-runtime', 'Write', 0, 0, RhsNode.Text
              )
            else if (RhsNode.NodeKind = gnkFunctionCall) and
              (RhsNode.ChildCount >= 2) and (RhsNode.ChildAt(0) <> nil) and
              SameText(RhsNode.ChildAt(0).Text, 'IntToStr') and
              EncodeRuntimeIntExprFold(RhsNode.ChildAt(1), Operand) then
              FModel.AddTypedHirNode(
                'write-int-runtime', 'Write', 0, 0, Operand
              )
            else if (RhsNode.NodeKind = gnkIdentifier) and
              LookupProcedureBody(RhsNode.Text, BranchNode, DeclNode) and
              IsRuntimeStrVar(RhsNode.Text) then
            begin
              Inc(FBlockLabelCounter);
              Operand := '$wrt_tmp_' + IntToStr(FBlockLabelCounter);
              RegisterRuntimeVar(Operand);
              RegisterRuntimeStrVar(Operand);
              FModel.AddTypedHirNode('var-decl-str-runtime', Operand, 0, 0, Operand);
              FModel.AddTypedHirNode(
                'assign-str-call-runtime', RhsNode.Text, 0, 0, Operand
              );
              FModel.AddTypedHirNode(
                'write-str-var-runtime', 'Write', 0, 0, Operand
              );
            end
            else if (RhsNode.NodeKind = gnkDotAccess) and
              (RhsNode.ChildCount >= 2) and
              (RhsNode.ChildAt(0) <> nil) and
              (RhsNode.ChildAt(1) <> nil) and
              (RhsNode.ChildAt(0).NodeKind = gnkIdentifier) and
              (RhsNode.ChildAt(1).NodeKind = gnkIdentifier) and
              (LookupClassVar(RhsNode.ChildAt(0).Text) <> '') then
            begin
              FuncName := LookupClassVar(RhsNode.ChildAt(0).Text);
              if FModel.LookupConstValue(
                FuncName + '$vmt_slot_' + RhsNode.ChildAt(1).Text, Value) then
              begin
                Inc(FBlockLabelCounter);
                Operand := '$wrt_tmp_' + IntToStr(FBlockLabelCounter);
                RegisterRuntimeVar(Operand);
                RegisterRuntimeStrVar(Operand);
                FModel.AddTypedHirNode('var-decl-str-runtime', Operand, 0, 0, Operand);
                FModel.AddTypedHirNode(
                  'assign-str-vcall-runtime', RhsNode.ChildAt(1).Text, 0, 0,
                  Operand + #9 + RhsNode.ChildAt(0).Text + #9 +
                  IntToStr(Value)
                );
                FModel.AddTypedHirNode(
                  'write-str-var-runtime', 'Write', 0, 0, Operand
                );
              end;
            end
            else if EncodeRuntimeIntExprFold(RhsNode, Operand) then
              FModel.AddTypedHirNode(
                'write-int-runtime', 'Write', 0, 0, Operand
              );
            Inc(ArgIndex);
          end;
          if SameText(Child.Text, 'WriteLn') then
            FModel.AddTypedHirNode(
              'write-string-runtime', 'Write', 0, 0, #10
            );
          Continue;
        end;
        Decoded := '';
        if (Arg <> nil) and (Arg.NodeKind = gnkFunctionCall) then
          ArgIndex := 1
        else
          ArgIndex := 0;
        while ArgIndex < Arg.ChildCount do
        begin
          RhsNode := Arg.ChildAt(ArgIndex);
          if RhsNode = nil then
          begin
            Inc(ArgIndex);
            Continue;
          end;
          if RhsNode.NodeKind = gnkStringLiteral then
            Decoded := Decoded + DecodePascalStringLiteral(RhsNode.Text)
          else if EvaluateStringConstant(RhsNode, StringValue) then
            Decoded := Decoded + StringValue
          else if EvaluateIntegerConstant(RhsNode, Value) then
            Decoded := Decoded + IntToStr(Value);
          Inc(ArgIndex);
        end;
        if SameText(Child.Text, 'WriteLn') then
          Decoded := Decoded + #10;
        FModel.AddTypedHirNode('write-call', Child.Text, 0, 0, Decoded);
        Continue;
      end;
      if FNoFold and SameText(Child.Text, 'SetLength') then
      begin
        Arg := nil;
        ArgIndex := 0;
        if (Child.ChildCount >= 1) and
          (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
        begin
          Arg := Child.ChildAt(0);
          ArgIndex := 1;
        end
        else
          Arg := Child;
        if (Arg <> nil) and (Arg.ChildCount >= ArgIndex + 2) then
        begin
          RhsNode := Arg.ChildAt(ArgIndex);
          if (RhsNode <> nil) and (RhsNode.NodeKind = gnkIdentifier) and
            IsRuntimeArrVar(RhsNode.Text) then
          begin
            if EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), Operand) then
            begin
              if FModel.LookupConstValue(RhsNode.Text + '$arr_elem_size', Value) then
                FModel.AddTypedHirNode(
                  'setlength-arr-runtime', RhsNode.Text, 0, 0,
                  RhsNode.Text + #9 + Operand + #9 + IntToStr(Value)
                )
              else
                FModel.AddTypedHirNode(
                  'setlength-arr-runtime', RhsNode.Text, 0, 0,
                  RhsNode.Text + #9 + Operand
                );
            end;
          end;
        end;
        Continue;
      end;
      if FNoFold and (SameText(Child.Text, 'Inc') or
        SameText(Child.Text, 'Dec')) and
        not ((Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkDotAccess) and
          (Child.ChildAt(0).ChildCount >= 2) and
          (Child.ChildAt(0).ChildAt(0) <> nil) and
          (LookupClassVar(Child.ChildAt(0).ChildAt(0).Text) <> '')) then
      begin
        Arg := nil;
        ArgIndex := 0;
        if (Child.ChildCount >= 1) and
          (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
        begin
          Arg := Child.ChildAt(0);
          ArgIndex := 1;
        end
        else
          Arg := Child;
        if (Arg <> nil) and (Arg.ChildCount > ArgIndex) then
        begin
          RhsNode := Arg.ChildAt(ArgIndex);
          if (RhsNode <> nil) and (RhsNode.NodeKind = gnkIdentifier) then
          begin
            Decoded := RhsNode.Text;
            if SameText(Child.Text, 'Inc') then
              StringValue := 'add'
            else
              StringValue := 'sub';
            if (FCurrentMethodClass <> '') and
              FModel.LookupConstValue(
                FCurrentMethodClass + '.' + Decoded + '$idx', Value) then
            begin
              if (Arg.ChildCount > ArgIndex + 1) and
                EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), Operand) then
                Operand := 'field self ' + IntToStr(Value) + #10 +
                  Operand + StringValue + #10
              else
                Operand := 'field self ' + IntToStr(Value) + #10 +
                  'int 1' + #10 + StringValue + #10;
              FModel.AddTypedHirNode('field-store-runtime', Decoded, 0, 0,
                'self' + #9 + IntToStr(Value) + #9 + Operand);
            end
            else
            begin
              if (Arg.ChildCount > ArgIndex + 1) and
                EncodeRuntimeIntExprFold(Arg.ChildAt(ArgIndex + 1), Operand) then
                FModel.AddTypedHirNode('assign-runtime', Decoded, 0, 0,
                  Decoded + #9 + 'var ' + Decoded + #10 + Operand +
                  StringValue + #10)
              else
                FModel.AddTypedHirNode('assign-runtime', Decoded, 0, 0,
                  Decoded + #9 + 'var ' + Decoded + #10 + 'int 1' + #10 +
                  StringValue + #10);
            end;
          end;
        end;
        Continue;
      end;
      if FNoFold and (FCurrentMethodClass <> '') and
        (Pos('inherited ', Child.Text) = 1) then
      begin
        InhMethodName := Copy(Child.Text, 11, Length(Child.Text));
        InhTypeId := FModel.FindTypeByName(FCurrentMethodClass);
        if (InhTypeId > 0) then
        begin
          InhParentId := FModel.TypeAt(InhTypeId - 1).ParentTypeId;
          if InhParentId > 0 then
          begin
            InhParentName := FModel.TypeAt(InhParentId - 1).Name;
            Operand := InhParentName + '.' + InhMethodName + #9 +
              'var self' + #10;
            for ArgIndex := 0 to Child.ChildCount - 1 do
            begin
              RhsNode := Child.ChildAt(ArgIndex);
              if (RhsNode <> nil) and EncodeRuntimeIntExprFold(RhsNode, Decoded) then
                Operand := Operand + #9 + Decoded;
            end;
            FModel.AddTypedHirNode('call-runtime',
              InhParentName + '.' + InhMethodName, 0, 0, Operand);
            Continue;
          end;
        end;
      end;
      if FNoFold and (Child.ChildCount >= 1) and
        (Child.ChildAt(0) <> nil) and
        (Child.ChildAt(0).NodeKind = gnkFunctionCall) and
        (Child.ChildAt(0).ChildCount >= 1) and
        (Child.ChildAt(0).ChildAt(0) <> nil) and
        (Child.ChildAt(0).ChildAt(0).NodeKind = gnkDotAccess) and
        (Child.ChildAt(0).ChildAt(0).ChildCount >= 2) and
        (Child.ChildAt(0).ChildAt(0).ChildAt(0) <> nil) and
        (Child.ChildAt(0).ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) then
      begin
        StringValue := LookupClassVar(
          Child.ChildAt(0).ChildAt(0).ChildAt(0).Text);
        if StringValue <> '' then
        begin
          InhParentName := StringValue;
          while (InhParentName <> '') and
            (FModel.FindSymbolByName(InhParentName + '.' +
              Child.ChildAt(0).ChildAt(0).ChildAt(1).Text) = 0) do
          begin
            InhTypeId := FModel.FindTypeByName(InhParentName);
            if (InhTypeId > 0) and
              (FModel.TypeAt(InhTypeId - 1).ParentTypeId > 0) then
              InhParentName := FModel.TypeAt(
                FModel.TypeAt(InhTypeId - 1).ParentTypeId - 1).Name
            else
              InhParentName := '';
          end;
          if InhParentName = '' then InhParentName := StringValue;
          Operand := InhParentName + '.' +
            Child.ChildAt(0).ChildAt(0).ChildAt(1).Text + #9 +
            'var ' + Child.ChildAt(0).ChildAt(0).ChildAt(0).Text + #10;
          for ArgIndex := 1 to Child.ChildAt(0).ChildCount - 1 do
          begin
            RhsNode := Child.ChildAt(0).ChildAt(ArgIndex);
            if (RhsNode <> nil) and EncodeRuntimeIntExprFold(RhsNode, Decoded) then
              Operand := Operand + #9 + Decoded;
          end;
          FModel.AddTypedHirNode('call-runtime',
            InhParentName + '.' +
            Child.ChildAt(0).ChildAt(0).ChildAt(1).Text,
            0, 0, Operand);
          Continue;
        end;
      end;
      if FNoFold and (Child.ChildCount >= 1) and
        (Child.ChildAt(0) <> nil) and
        (Child.ChildAt(0).NodeKind = gnkDotAccess) and
        (Child.ChildAt(0).ChildCount >= 2) and
        (Child.ChildAt(0).ChildAt(0) <> nil) and
        (Child.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) and
        SameText(Child.ChildAt(0).ChildAt(1).Text, 'Free') then
      begin
        StringValue := LookupClassVar(Child.ChildAt(0).ChildAt(0).Text);
        if StringValue <> '' then
        begin
          if FModel.LookupConstValue(
            StringValue + '$vmt_slot_Destroy', Value) then
          begin
            ReceiverName := Child.ChildAt(0).ChildAt(0).Text;
            DestroyFuncName := StringValue + '.Destroy';
            if FModel.LookupStringConstValue(
              StringValue + '$vmt_func_' + IntToStr(Value),
              FuncName
            ) then
              DestroyFuncName := FuncName;
            FModel.AddTypedHirNode(
              'object-free-runtime',
              'np.system.object_free',
              0,
              0,
              'var ' + ReceiverName + #10 +
              'destroy ' + DestroyFuncName + #10 +
              'nil-guard true' + #10 +
              'heap-release true' + #10
            );
            Operand := DestroyFuncName + #9 +
              'var ' + ReceiverName + #10;
            FModel.AddTypedHirNode('call-runtime',
              DestroyFuncName, 0, 0, Operand);
          end;
          Continue;
        end;
      end;
      if FNoFold and (Child.ChildCount >= 1) and
        (Child.ChildAt(0) <> nil) and
        (Child.ChildAt(0).NodeKind = gnkDotAccess) and
        (Child.ChildAt(0).ChildCount >= 2) and
        (Child.ChildAt(0).ChildAt(0) <> nil) and
        (Child.ChildAt(0).ChildAt(0).NodeKind = gnkIdentifier) then
      begin
        StringValue := LookupClassVar(Child.ChildAt(0).ChildAt(0).Text);
        if StringValue <> '' then
        begin
          InhParentName := StringValue;
          while (InhParentName <> '') and
            (FModel.FindSymbolByName(InhParentName + '.' +
              Child.ChildAt(0).ChildAt(1).Text) = 0) do
          begin
            InhTypeId := FModel.FindTypeByName(InhParentName);
            if (InhTypeId > 0) and
              (FModel.TypeAt(InhTypeId - 1).ParentTypeId > 0) then
              InhParentName := FModel.TypeAt(
                FModel.TypeAt(InhTypeId - 1).ParentTypeId - 1).Name
            else
              InhParentName := '';
          end;
          if InhParentName = '' then InhParentName := StringValue;
          Operand := InhParentName + '.' + Child.ChildAt(0).ChildAt(1).Text +
            #9 + 'var ' + Child.ChildAt(0).ChildAt(0).Text + #10;
          Arg := nil;
          if (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
            Arg := Child.ChildAt(0)
          else if (Child.ChildCount >= 2) and
            (Child.ChildAt(1) <> nil) and
            (Child.ChildAt(1).NodeKind = gnkFunctionCall) then
            Arg := Child.ChildAt(1);
          if Arg <> nil then
          begin
            for ArgIndex := 1 to Arg.ChildCount - 1 do
            begin
              RhsNode := Arg.ChildAt(ArgIndex);
              if (RhsNode <> nil) and EncodeRuntimeIntExprFold(RhsNode, Decoded) then
                Operand := Operand + #9 + Decoded;
            end;
          end;
          FModel.AddTypedHirNode('call-runtime',
            InhParentName + '.' + Child.ChildAt(0).ChildAt(1).Text,
            0, 0, Operand);
          Continue;
        end;
      end;
      if (not FNoFold) and
        LookupProcedureBody(Child.Text, BranchNode, DeclNode) and
        (BranchNode <> nil) and
        not IsCurrentlyInlining(Child.Text) then
      begin
        PushInlining(Child.Text);
        if (Child.ChildCount >= 1) and (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
          ParamSnaps := BindCallArgs(DeclNode, Child.ChildAt(0), 1)
        else
          ParamSnaps := BindCallArgs(DeclNode, Child, 0);
        try
          WalkHaltCalls(BranchNode);
        finally
          PopInlining;
          RestoreCallArgs(ParamSnaps);
        end;
        Continue;
      end;
      if FNoFold and (FCurrentMethodClass <> '') and
        (not LookupProcedureBody(Child.Text, BranchNode, DeclNode)) and
        LookupProcedureBody(FCurrentMethodClass + '.' + Child.Text,
          BranchNode, DeclNode) then
      begin
        Operand := FCurrentMethodClass + '.' + Child.Text + #9 +
          'var self' + #10;
        Arg := nil;
        if (Child.ChildCount >= 1) and
          (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
          Arg := Child.ChildAt(0)
        else
          Arg := Child;
        if Arg <> nil then
        begin
          if Arg.NodeKind = gnkFunctionCall then
            ArgIndex := 1
          else
            ArgIndex := 0;
          while ArgIndex < Arg.ChildCount do
          begin
            RhsNode := Arg.ChildAt(ArgIndex);
            if (RhsNode <> nil) and EncodeRuntimeIntExprFold(RhsNode, Decoded) then
              Operand := Operand + #9 + Decoded;
            Inc(ArgIndex);
          end;
        end;
        FModel.AddTypedHirNode('call-runtime',
          FCurrentMethodClass + '.' + Child.Text, 0, 0, Operand);
        Continue;
      end;
      if FNoFold and LookupProcedureBody(Child.Text, BranchNode, DeclNode) then
      begin
        Arg := nil;
        if (Child.ChildCount >= 1) and
          (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
          Arg := Child.ChildAt(0)
        else
          Arg := Child;
        ArgIndex := 0;
        if (Arg <> nil) then
        begin
          if Arg.NodeKind = gnkFunctionCall then
            ArgIndex := Arg.ChildCount - 1
          else
            ArgIndex := Arg.ChildCount;
        end;
        if HasOverload(Child.Text) then
        begin
          StringValue := '';
          if Arg <> nil then
          begin
            if Arg.NodeKind = gnkFunctionCall then
              DotPos := 1
            else
              DotPos := 0;
            while DotPos < Arg.ChildCount do
            begin
              RhsNode := Arg.ChildAt(DotPos);
              if (RhsNode <> nil) and (RhsNode.NodeKind = gnkIdentifier) and
                IsRuntimeStrVar(RhsNode.Text) then
                StringValue := StringValue + 's'
              else if (RhsNode <> nil) and (RhsNode.NodeKind = gnkStringLiteral) then
                StringValue := StringValue + 's'
              else
                StringValue := StringValue + 'i';
              Inc(DotPos);
            end;
          end;
          Operand := MangledNameSig(Child.Text, StringValue);
        end
        else
          Operand := Child.Text;
        if Arg <> nil then
        begin
          if Arg.NodeKind = gnkFunctionCall then
            ArgIndex := 1
          else
            ArgIndex := 0;
          DotPos := 0;
          while ArgIndex < Arg.ChildCount do
          begin
            RhsNode := Arg.ChildAt(ArgIndex);
            if (RhsNode <> nil) and (RhsNode.NodeKind = gnkIdentifier) and
              IsVarParamAtPosition(DeclNode, DotPos) and
              IsRuntimeVar(RhsNode.Text) then
              Operand := Operand + #9 + 'varref ' + RhsNode.Text + #10
            else if (RhsNode <> nil) and (RhsNode.NodeKind = gnkIdentifier) and
              IsRuntimeStrVar(RhsNode.Text) then
              Operand := Operand + #9 + 'strvar ' + RhsNode.Text + #10
            else if (RhsNode <> nil) and (RhsNode.NodeKind = gnkStringLiteral) then
              Operand := Operand + #9 + 'strlit ' + RhsNode.Text + #10
            else if (RhsNode <> nil) and EncodeRuntimeIntExprFold(RhsNode, Decoded) then
              Operand := Operand + #9 + Decoded;
            Inc(ArgIndex);
            Inc(DotPos);
          end;
          if DeclNode <> nil then
          begin
            K := 0;
            for ArgIndex := 0 to DeclNode.ChildCount - 1 do
            begin
              if (DeclNode.ChildAt(ArgIndex) = nil) or
                (DeclNode.ChildAt(ArgIndex).NodeKind <> gnkParameterList) then
                Continue;
              for K := 0 to DeclNode.ChildAt(ArgIndex).ChildCount - 1 do
              begin
                RhsNode := DeclNode.ChildAt(ArgIndex).ChildAt(K);
                if (RhsNode = nil) or (RhsNode.NodeKind <> gnkParameterDecl) then
                  Continue;
                Dec(DotPos);
                if DotPos < 0 then
                begin
                  if RhsNode.ChildCount > 1 then
                  begin
                    if EncodeRuntimeIntExprFold(RhsNode.ChildAt(
                      RhsNode.ChildCount - 1), Decoded) then
                      Operand := Operand + #9 + Decoded;
                  end;
                end;
              end;
              Break;
            end;
          end;
        end;
        FModel.AddTypedHirNode('call-runtime', Child.Text, 0, 0, Operand);
        Continue;
      end;
    end;
    WalkHaltCalls(Child);
  end;
end;

procedure TSemanticAnalyzer.LowerRuntimeIfStatement(
  const AIfNode: TGreenNode; const ACondBlob: string);
var
  ThenLabel, ElseLabel, EndLabel: string;
  HasElse: Boolean;
begin
  HasElse := AIfNode.ChildCount >= 3;
  ThenLabel := NewBlockLabel('then');
  if HasElse then
    ElseLabel := NewBlockLabel('else')
  else
    ElseLabel := '';
  EndLabel := NewBlockLabel('endif');
  if not HasElse then
    ElseLabel := EndLabel;
  FModel.AddTypedHirNode(
    'cond-br-runtime', 'if', 0, 0,
    ACondBlob + 'labels ' + ThenLabel + #9 + ElseLabel + #10
  );
  FCurrentBlockTerminated := True;
  EmitBlockLabel(ThenLabel);
  WalkHaltCalls(AIfNode.ChildAt(1));
  EmitGotoLabel(EndLabel);
  if HasElse then
  begin
    EmitBlockLabel(ElseLabel);
    WalkHaltCalls(AIfNode.ChildAt(2));
    EmitGotoLabel(EndLabel);
  end;
  EmitBlockLabel(EndLabel);
end;

procedure TSemanticAnalyzer.LowerRuntimeWhileStatement(const ANode: TGreenNode);
var
  CondNode, BodyNode: TGreenNode;
  CondBlob, CondLabel, BodyLabel, ExitLabel: string;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  CondNode := ANode.ChildAt(0);
  BodyNode := ANode.ChildAt(1);
  if not EncodeRuntimeBoolExprFold(CondNode, CondBlob) then
    Exit;
  CondLabel := NewBlockLabel('while-cond');
  BodyLabel := NewBlockLabel('while-body');
  ExitLabel := NewBlockLabel('while-end');
  SetLength(FBreakLabels, Length(FBreakLabels) + 1);
  FBreakLabels[High(FBreakLabels)] := ExitLabel;
  SetLength(FContinueLabels, Length(FContinueLabels) + 1);
  FContinueLabels[High(FContinueLabels)] := CondLabel;
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(CondLabel);
  FModel.AddTypedHirNode(
    'cond-br-runtime', 'while', 0, 0,
    CondBlob + 'labels ' + BodyLabel + #9 + ExitLabel + #10
  );
  FCurrentBlockTerminated := True;
  EmitBlockLabel(BodyLabel);
  WalkHaltCalls(BodyNode);
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(ExitLabel);
  SetLength(FBreakLabels, Length(FBreakLabels) - 1);
  SetLength(FContinueLabels, Length(FContinueLabels) - 1);
end;

procedure TSemanticAnalyzer.LowerRuntimeRepeatStatement(const ANode: TGreenNode);
var
  CondNode, BodyNode: TGreenNode;
  CondBlob, BodyLabel, CondLabel, ExitLabel: string;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  BodyNode := ANode.ChildAt(0);
  CondNode := ANode.ChildAt(1);
  if not EncodeRuntimeBoolExprFold(CondNode, CondBlob) then
    Exit;
  BodyLabel := NewBlockLabel('repeat-body');
  CondLabel := NewBlockLabel('repeat-cond');
  ExitLabel := NewBlockLabel('repeat-end');
  SetLength(FBreakLabels, Length(FBreakLabels) + 1);
  FBreakLabels[High(FBreakLabels)] := ExitLabel;
  SetLength(FContinueLabels, Length(FContinueLabels) + 1);
  FContinueLabels[High(FContinueLabels)] := CondLabel;
  EmitGotoLabel(BodyLabel);
  EmitBlockLabel(BodyLabel);
  WalkHaltCalls(BodyNode);
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(CondLabel);
  FModel.AddTypedHirNode(
    'cond-br-runtime', 'until', 0, 0,
    CondBlob + 'labels ' + ExitLabel + #9 + BodyLabel + #10
  );
  FCurrentBlockTerminated := True;
  EmitBlockLabel(ExitLabel);
  SetLength(FBreakLabels, Length(FBreakLabels) - 1);
  SetLength(FContinueLabels, Length(FContinueLabels) - 1);
end;

procedure TSemanticAnalyzer.LowerRuntimeCaseStatement(const ANode: TGreenNode);
var
  SelectorNode, SelectorChild, LabelNode, LabelExpr: TGreenNode;
  SelectorBlob, SwitchBlob, ExitLabel, BodyLabel, DefaultLabel: string;
  BodyLabels: array of string;
  I, J, K, CaseCount, SelectorCount: LongInt;
  Val, LoVal, HiVal: Int64;
  HasElse: Boolean;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  if not EncodeRuntimeIntExprFold(ANode.ChildAt(0), SelectorBlob) then
    Exit;

  SelectorCount := 0;
  HasElse := False;
  for I := 1 to ANode.ChildCount - 1 do
  begin
    SelectorChild := ANode.ChildAt(I);
    if (SelectorChild <> nil) and (SelectorChild.NodeKind = gnkCaseSelector) then
      Inc(SelectorCount)
    else
      HasElse := True;
  end;

  ExitLabel := NewBlockLabel('case-end');
  DefaultLabel := NewBlockLabel('case-default');
  SetLength(BodyLabels, SelectorCount);
  for I := 0 to SelectorCount - 1 do
    BodyLabels[I] := NewBlockLabel('case-body');

  CaseCount := 0;
  SwitchBlob := '';
  K := 0;
  for I := 1 to ANode.ChildCount - 1 do
  begin
    SelectorChild := ANode.ChildAt(I);
    if (SelectorChild = nil) or (SelectorChild.NodeKind <> gnkCaseSelector) then
      Continue;
    for J := 0 to SelectorChild.ChildCount - 1 do
    begin
      LabelNode := SelectorChild.ChildAt(J);
      if (LabelNode = nil) or (LabelNode.NodeKind <> gnkCaseLabel) then
        Continue;
      if LabelNode.ChildCount < 1 then
        Continue;
      LabelExpr := LabelNode.ChildAt(0);
      if (LabelExpr <> nil) and (LabelExpr.NodeKind = gnkRangeExpression) and
        (LabelExpr.ChildCount >= 2) then
      begin
        if EvaluateIntegerConstant(LabelExpr.ChildAt(0), LoVal) and
          EvaluateIntegerConstant(LabelExpr.ChildAt(1), HiVal) then
          for Val := LoVal to HiVal do
          begin
            SwitchBlob := SwitchBlob + IntToStr(Val) + #9 + BodyLabels[K] + #10;
            Inc(CaseCount);
          end;
      end
      else if EvaluateIntegerConstant(LabelExpr, Val) then
      begin
        SwitchBlob := SwitchBlob + IntToStr(Val) + #9 + BodyLabels[K] + #10;
        Inc(CaseCount);
      end;
    end;
    Inc(K);
  end;

  FModel.AddTypedHirNode(
    'switch-runtime', 'case', 0, 0,
    SelectorBlob + 'switch ' + IntToStr(CaseCount) + #10 +
    SwitchBlob + 'default' + #9 + DefaultLabel + #10
  );
  FCurrentBlockTerminated := True;

  K := 0;
  for I := 1 to ANode.ChildCount - 1 do
  begin
    SelectorChild := ANode.ChildAt(I);
    if (SelectorChild = nil) or (SelectorChild.NodeKind <> gnkCaseSelector) then
      Continue;
    EmitBlockLabel(BodyLabels[K]);
    for J := 0 to SelectorChild.ChildCount - 1 do
    begin
      LabelNode := SelectorChild.ChildAt(J);
      if (LabelNode <> nil) and (LabelNode.NodeKind <> gnkCaseLabel) then
        WalkHaltCalls(LabelNode);
    end;
    EmitGotoLabel(ExitLabel);
    Inc(K);
  end;

  EmitBlockLabel(DefaultLabel);
  if HasElse then
  begin
    for I := 1 to ANode.ChildCount - 1 do
    begin
      SelectorChild := ANode.ChildAt(I);
      if (SelectorChild <> nil) and (SelectorChild.NodeKind <> gnkCaseSelector) then
        WalkHaltCalls(SelectorChild);
    end;
  end;
  EmitGotoLabel(ExitLabel);
  EmitBlockLabel(ExitLabel);
end;

procedure TSemanticAnalyzer.LowerRuntimeForStatement(const ANode: TGreenNode);
var
  LoopVar, Direction: string;
  StartNode, EndNode, BodyNode: TGreenNode;
  StartBlob, EndBlob, CondBlob: string;
  CondLabel, BodyLabel, StepLabel, ExitLabel: string;
  Pred, Op: string;
begin
  if (ANode = nil) or (ANode.ChildCount < 4) then
    Exit;
  if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
    Exit;
  LoopVar := ANode.ChildAt(0).Text;
  RegisterRuntimeVar(LoopVar);
  StartNode := ANode.ChildAt(1);
  EndNode := ANode.ChildAt(2);
  BodyNode := ANode.ChildAt(3);
  Direction := ANode.Text;
  if not EncodeRuntimeIntExprFold(StartNode, StartBlob) then
    Exit;
  if not EncodeRuntimeIntExprFold(EndNode, EndBlob) then
    Exit;
  if SameText(Direction, 'to') then
  begin
    Pred := 'sle';
    Op := 'add';
  end
  else if SameText(Direction, 'downto') then
  begin
    Pred := 'sge';
    Op := 'sub';
  end
  else
    Exit;
  FModel.AddTypedHirNode(
    'assign-runtime', LoopVar, 0, 0,
    LoopVar + #9 + StartBlob
  );
  CondLabel := NewBlockLabel('for-cond');
  BodyLabel := NewBlockLabel('for-body');
  StepLabel := NewBlockLabel('for-step');
  ExitLabel := NewBlockLabel('for-end');
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(CondLabel);
  CondBlob := 'var ' + LoopVar + #10 + EndBlob + 'cmp ' + Pred + #10;
  FModel.AddTypedHirNode(
    'cond-br-runtime', 'for', 0, 0,
    CondBlob + 'labels ' + BodyLabel + #9 + ExitLabel + #10
  );
  FCurrentBlockTerminated := True;
  SetLength(FBreakLabels, Length(FBreakLabels) + 1);
  FBreakLabels[High(FBreakLabels)] := ExitLabel;
  SetLength(FContinueLabels, Length(FContinueLabels) + 1);
  FContinueLabels[High(FContinueLabels)] := StepLabel;
  EmitBlockLabel(BodyLabel);
  WalkHaltCalls(BodyNode);
  EmitGotoLabel(StepLabel);
  EmitBlockLabel(StepLabel);
  FModel.AddTypedHirNode(
    'assign-runtime', LoopVar, 0, 0,
    LoopVar + #9 + 'var ' + LoopVar + #10 + 'int 1' + #10 + Op + #10
  );
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(ExitLabel);
  SetLength(FBreakLabels, Length(FBreakLabels) - 1);
  SetLength(FContinueLabels, Length(FContinueLabels) - 1);
end;

procedure TSemanticAnalyzer.UnrollHaltForLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  LoopVar: string;
  StartValue, EndValue, IterValue: Int64;
  Direction: string;
  BodyNode: TGreenNode;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 4) then
    Exit;
  if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
    Exit;
  LoopVar := ANode.ChildAt(0).Text;
  if not EvaluateIntegerConstant(ANode.ChildAt(1), StartValue) then
    Exit;
  if not EvaluateIntegerConstant(ANode.ChildAt(2), EndValue) then
    Exit;
  Direction := ANode.Text;
  BodyNode := ANode.ChildAt(3);
  IterCount := 0;
  IterValue := StartValue;
  if SameText(Direction, 'to') then
  begin
    while (IterValue <= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkHaltCalls(BodyNode);
      Inc(IterValue);
      Inc(IterCount);
    end;
  end
  else if SameText(Direction, 'downto') then
  begin
    while (IterValue >= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkHaltCalls(BodyNode);
      Dec(IterValue);
      Inc(IterCount);
    end;
  end;
end;

procedure TSemanticAnalyzer.UnrollHaltWhileLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  CondNode, BodyNode: TGreenNode;
  CondValue: Int64;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  CondNode := ANode.ChildAt(0);
  BodyNode := ANode.ChildAt(1);
  IterCount := 0;
  while IterCount < MaxIterations do
  begin
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue = 0 then
      Exit;
    WalkHaltCalls(BodyNode);
    Inc(IterCount);
  end;
end;

procedure TSemanticAnalyzer.UnrollHaltRepeatLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  BodyNode, CondNode: TGreenNode;
  CondValue: Int64;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  BodyNode := ANode.ChildAt(0);
  CondNode := ANode.ChildAt(1);
  IterCount := 0;
  while IterCount < MaxIterations do
  begin
    WalkHaltCalls(BodyNode);
    Inc(IterCount);
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue <> 0 then
      Exit;
  end;
end;

procedure TSemanticAnalyzer.WalkRuntimeVarDecls(const ANode: TGreenNode);
var
  I, J, K: LongInt;
  Child, Decl, TypeChild, NextSibling: TGreenNode;
  IsStr, IsArr: Boolean;
  Folded, Value: Int64;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if (Child.NodeKind = gnkProcedureDecl) or
      (Child.NodeKind = gnkFunctionDecl) then
      Continue;
    if Child.NodeKind = gnkVarSection then
    begin
      for J := 0 to Child.ChildCount - 1 do
      begin
        Decl := Child.ChildAt(J);
        if (Decl = nil) or (Decl.NodeKind <> gnkVarDecl) or
          (Decl.Text = '') then
          Continue;
        IsStr := False;
        IsArr := False;
        if Decl.ChildCount > 0 then
        begin
          TypeChild := Decl.ChildAt(0);
          if (TypeChild <> nil) and
            (SameText(TypeChild.Text, 'String') or
             SameText(TypeChild.Text, 'AnsiString')) then
            IsStr := True;
          if (TypeChild <> nil) and (TypeChild.Text = '') then
          begin
            for K := J + 1 to Child.ChildCount - 1 do
            begin
              NextSibling := Child.ChildAt(K);
              if (NextSibling <> nil) and
                (NextSibling.NodeKind <> gnkVarDecl) then
              begin
                if NextSibling.NodeKind = gnkArrayType then
                  IsArr := True;
                Break;
              end;
            end;
          end;
        end;
        RegisterRuntimeVar(Decl.Text);
        if IsStr then
        begin
          RegisterRuntimeStrVar(Decl.Text);
          FModel.AddTypedHirNode(
            'var-decl-str-runtime', Decl.Text, 0, 0, Decl.Text
          );
        end
        else if IsArr then
        begin
          RegisterRuntimeArrVar(Decl.Text);
          if (NextSibling <> nil) and (NextSibling.NodeKind = gnkArrayType) and
            (NextSibling.ChildCount > 0) and (NextSibling.ChildAt(0) <> nil) and
            FModel.LookupConstValue(NextSibling.ChildAt(0).Text + '$record', Folded) and
            FModel.LookupConstValue(NextSibling.ChildAt(0).Text + '$size', Folded) then
          begin
            FModel.AddConstValue(Decl.Text + '$arr_elem_size', Folded);
            FModel.AddStringConstValue(Decl.Text + '$arr_elem_type', NextSibling.ChildAt(0).Text);
          end;
          FModel.AddTypedHirNode(
            'var-decl-arr-runtime', Decl.Text, 0, 0, Decl.Text
          );
        end
        else if (Decl.ChildCount > 0) and (Decl.ChildAt(0) <> nil) and
          FModel.LookupConstValue(Decl.ChildAt(0).Text + '$size', Folded) then
        begin
          if FModel.LookupConstValue(Decl.ChildAt(0).Text + '$record', Value) then
          begin
            RegisterRecordVar(Decl.Text, Decl.ChildAt(0).Text);
            FModel.AddTypedHirNode(
              'var-decl-record-runtime', Decl.Text, 0, 0,
              Decl.Text + #9 + IntToStr(Folded div 8)
            );
          end
          else
          begin
            RegisterClassVar(Decl.Text, Decl.ChildAt(0).Text);
            FModel.AddTypedHirNode(
              'var-decl-ptr-runtime', Decl.Text, 0, 0, Decl.Text
            );
          end;
        end
        else
          FModel.AddTypedHirNode(
            'var-decl-runtime', Decl.Text, 0, 0, Decl.Text
          );
      end;
      Continue;
    end;
    WalkRuntimeVarDecls(Child);
  end;
end;

procedure TSemanticAnalyzer.SeedRuntimeVarDecls;
var
  RootNode: TGreenNode;
begin
  if not FNoFold then
    Exit;
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  if (FRootAst.RootKindName <> 'program') and
    (FRootAst.RootKindName <> 'library') and
    (FRootAst.RootKindName <> 'package') then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkRuntimeVarDecls(RootNode);
end;

procedure TSemanticAnalyzer.SeedHaltCalls;
var
  RootNode: TGreenNode;
begin
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  if (FRootAst.RootKindName <> 'program') and
    (FRootAst.RootKindName <> 'library') and
    (FRootAst.RootKindName <> 'package') then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkHaltCalls(RootNode);
  if FNoFold and not FCurrentBlockTerminated then
  begin
    FModel.AddTypedHirNode('halt-call-runtime', 'Halt', 0, 0, 'int 0' + #10);
    FCurrentBlockTerminated := True;
  end;
end;

procedure TSemanticAnalyzer.PreRegisterFunctionReturnTypes;
var
  I, J: LongInt;
  Entry: TProcedureBodyEntry;
  Child: TGreenNode;
  Folded: Int64;
begin
  for I := 0 to Length(FProcedureBodies) - 1 do
  begin
    Entry := FProcedureBodies[I];
    if (Entry.Decl = nil) or (Entry.Body = nil) then
      Continue;
    for J := 0 to Entry.Decl.ChildCount - 1 do
    begin
      Child := Entry.Decl.ChildAt(J);
      if Child = nil then
        Continue;
      if (Child.NodeKind = gnkIdentifier) and
        (SameText(Child.Text, 'String') or
         SameText(Child.Text, 'AnsiString')) then
      begin
        RegisterRuntimeVar(Entry.Name);
        RegisterRuntimeStrVar(Entry.Name);
        Break;
      end;
      if (Child.NodeKind = gnkIdentifier) and
        (Child.NodeKind <> gnkBeginBlock) and
        FModel.LookupConstValue(Child.Text + '$size', Folded) and
        (Pos('.', Entry.Name) = 0) then
      begin
        if not FModel.LookupConstValue(Child.Text + '$record', Folded) then
          RegisterPtrReturnFunc(Entry.Name, Child.Text);
        Break;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.SeedFunctionBodies;
var
  I, J, K: LongInt;
  Entry: TProcedureBodyEntry;
  ParamCount: LongInt;
  Child, ParamChild, TypeChild: TGreenNode;
  SavedTerminated: Boolean;
  ParamTypes, RetVarName, EffName: string;
  IsStrParam, IsStrReturn, IsPtrReturn, IsVarP, IsRecReturn: Boolean;
  PtrReturnClass: string;
  Folded, Value: Int64;
begin
  for I := 0 to Length(FProcedureBodies) - 1 do
  begin
    Entry := FProcedureBodies[I];
    if Entry.Body = nil then
      Continue;
    SetLength(FVarParamNames, 0);
    if HasOverload(Entry.Name) then
      EffName := MangledNameSig(Entry.Name, GetParamSignature(Entry.Decl))
    else
      EffName := Entry.Name;
    ParamCount := 0;
    ParamTypes := '';
    IsStrReturn := False;
    IsPtrReturn := False;
    IsRecReturn := False;
    PtrReturnClass := '';
    if Entry.Decl <> nil then
    begin
      for J := 0 to Entry.Decl.ChildCount - 1 do
      begin
        Child := Entry.Decl.ChildAt(J);
        if Child = nil then
          Continue;
        if Child.NodeKind = gnkParameterList then
        begin
          for K := 0 to Child.ChildCount - 1 do
          begin
            ParamChild := Child.ChildAt(K);
            if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
            begin
              ParamTypes := ParamTypes;
              RetVarName := ParamChild.Text;
              IsVarP := (Length(RetVarName) > 4) and
                (Copy(RetVarName, 1, 4) = 'var:');
              if IsVarP then
                RetVarName := Copy(RetVarName, 5, Length(RetVarName));
              RegisterRuntimeVar(RetVarName);
              if IsVarP then
                RegisterVarParam(RetVarName);
              IsStrParam := False;
              if ParamChild.ChildCount > 0 then
              begin
                TypeChild := ParamChild.ChildAt(0);
                if (TypeChild <> nil) and
                  (SameText(TypeChild.Text, 'String') or
                   SameText(TypeChild.Text, 'AnsiString')) then
                begin
                  IsStrParam := True;
                  RegisterRuntimeStrVar(RetVarName);
                end
                else if (TypeChild <> nil) and
                  FModel.LookupConstValue(TypeChild.Text + '$size', Folded) then
                begin
                  if FModel.LookupConstValue(TypeChild.Text + '$record', Value) then
                    RegisterRecordVar(RetVarName, TypeChild.Text)
                  else
                    RegisterClassVar(RetVarName, TypeChild.Text);
                end;
              end;
              if IsStrParam then
                ParamTypes := ParamTypes + 's'
              else if (ParamChild.ChildCount > 0) and
                (ParamChild.ChildAt(0) <> nil) and
                FModel.LookupConstValue(
                  ParamChild.ChildAt(0).Text + '$size', Folded) then
              begin
                if FModel.LookupConstValue(
                  ParamChild.ChildAt(0).Text + '$record', Value) then
                  ParamTypes := ParamTypes + 'r'
                else if IsVarP then
                  ParamTypes := ParamTypes + 'v'
                else
                  ParamTypes := ParamTypes + 'p';
              end
              else if IsVarP then
                ParamTypes := ParamTypes + 'v'
              else
                ParamTypes := ParamTypes + 'i';
              Inc(ParamCount);
            end;
          end;
        end
        else if (Child.NodeKind = gnkIdentifier) and
          (Child.NodeKind <> gnkBeginBlock) and
          (SameText(Child.Text, 'String') or
           SameText(Child.Text, 'AnsiString')) then
          IsStrReturn := True
        else if (Child.NodeKind = gnkIdentifier) and
          (Child.NodeKind <> gnkBeginBlock) and
          FModel.LookupConstValue(Child.Text + '$size', Folded) and
          (not FModel.LookupConstValue(Child.Text + '$record', Value)) then
        begin
          IsPtrReturn := True;
          PtrReturnClass := Child.Text;
        end
        else if (Child.NodeKind = gnkIdentifier) and
          (Child.NodeKind <> gnkBeginBlock) and
          FModel.LookupConstValue(Child.Text + '$size', Folded) and
          FModel.LookupConstValue(Child.Text + '$record', Value) then
        begin
          IsRecReturn := True;
          PtrReturnClass := Child.Text;
        end;
      end;
    end;
    if IsPtrReturn and (Pos('.', Entry.Name) = 0) then
      RegisterPtrReturnFunc(Entry.Name, PtrReturnClass);
    if Pos('.', Entry.Name) > 0 then
    begin
      FCurrentMethodClass := Copy(Entry.Name, 1, Pos('.', Entry.Name) - 1);
      if IsStrReturn then
        FModel.AddTypedHirNode('method-body-begin', Entry.Name, 0, 0,
          IntToStr(ParamCount + 1) + ':p' + ParamTypes + ':s')
      else if IsPtrReturn then
        FModel.AddTypedHirNode('method-body-begin', Entry.Name, 0, 0,
          IntToStr(ParamCount + 1) + ':p' + ParamTypes + ':p')
      else
        FModel.AddTypedHirNode('method-body-begin', Entry.Name, 0, 0,
          IntToStr(ParamCount + 1) + ':p' + ParamTypes);
      RegisterRuntimeVar('self');
    end
    else if IsStrReturn then
      FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
        IntToStr(ParamCount) + ':' + ParamTypes + ':s')
    else if IsPtrReturn then
      FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
        IntToStr(ParamCount) + ':' + ParamTypes + ':p')
    else if IsRecReturn then
    begin
      if FModel.LookupConstValue(PtrReturnClass + '$size', Folded) then
        FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
          IntToStr(ParamCount) + ':' + ParamTypes + ':r' + IntToStr(Folded div 8))
      else
        FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
          IntToStr(ParamCount) + ':' + ParamTypes);
    end
    else
      FModel.AddTypedHirNode('function-body-begin', EffName, 0, 0,
        IntToStr(ParamCount) + ':' + ParamTypes);
    if Entry.Decl <> nil then
    begin
      for J := 0 to Entry.Decl.ChildCount - 1 do
      begin
        Child := Entry.Decl.ChildAt(J);
        if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
        begin
          for K := 0 to Child.ChildCount - 1 do
          begin
            ParamChild := Child.ChildAt(K);
            if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
            begin
              RetVarName := ParamChild.Text;
              if (Length(RetVarName) > 4) and
                (Copy(RetVarName, 1, 4) = 'var:') then
                RetVarName := Copy(RetVarName, 5, Length(RetVarName));
              if IsRuntimeStrVar(RetVarName) then
                FModel.AddTypedHirNode('var-decl-str-runtime', RetVarName,
                  0, 0, RetVarName)
              else if IsRecordVar(RetVarName) then
                FModel.AddTypedHirNode('var-decl-ptr-runtime', RetVarName,
                  0, 0, RetVarName)
              else if IsVarParam(RetVarName) then
                FModel.AddTypedHirNode('var-decl-varref-runtime', RetVarName,
                  0, 0, RetVarName)
              else
                FModel.AddTypedHirNode('var-decl-runtime', RetVarName,
                  0, 0, ParamChild.Text);
            end;
          end;
          Break;
        end;
      end;
    end;
    if Pos('.', Entry.Name) > 0 then
      RetVarName := Copy(Entry.Name, Pos('.', Entry.Name) + 1, Length(Entry.Name))
    else
      RetVarName := Entry.Name;
    RegisterRuntimeVar(RetVarName);
    if (Entry.Decl <> nil) and (Entry.Decl.NodeKind = gnkFunctionDecl) then
      FCurrentRetVarName := RetVarName
    else if Pos('.', Entry.Name) > 0 then
      FCurrentRetVarName := RetVarName
    else
      FCurrentRetVarName := '';
    if IsStrReturn then
      RegisterRuntimeStrVar(RetVarName);
    if IsRecReturn then
      RegisterRecordVar(RetVarName, PtrReturnClass);
    if IsStrReturn then
      FModel.AddTypedHirNode('var-decl-str-runtime', RetVarName, 0, 0, RetVarName)
    else if IsPtrReturn then
      FModel.AddTypedHirNode('var-decl-ptr-runtime', RetVarName, 0, 0, RetVarName)
    else if IsRecReturn then
      FModel.AddTypedHirNode('var-decl-ptr-runtime', RetVarName, 0, 0, RetVarName)
    else
      FModel.AddTypedHirNode('var-decl-runtime', RetVarName, 0, 0, RetVarName);
    SavedTerminated := FCurrentBlockTerminated;
    FCurrentBlockTerminated := False;
    WalkHaltCalls(Entry.Body);
    if not FCurrentBlockTerminated then
    begin
      if IsStrReturn then
        FModel.AddTypedHirNode('ret-str-runtime', RetVarName, 0, 0, RetVarName)
      else
        FModel.AddTypedHirNode('ret-runtime', RetVarName, 0, 0,
          'var ' + RetVarName + #10);
    end;
    FModel.AddTypedHirNode('function-body-end', EffName, 0, 0, '');
    FCurrentBlockTerminated := SavedTerminated;
    FCurrentMethodClass := '';
    FCurrentRetVarName := '';
  end;
end;

procedure TSemanticAnalyzer.SeedImportedUnitBodies;

  procedure SeedImportedCallableSymbol(
    const ANode: TGreenNode;
    const AOwnerUnitId: string;
    const AUnitScopeId: LongInt
  );
  var
    Child: TGreenNode;
    ChildIndex: LongInt;
    KindName: string;
    ParamCount: LongInt;
    ParamSignature: string;
    ScopeId: LongInt;
    Symbol: TSemanticSymbol;
    SymbolId: LongInt;
    SymbolIndex: LongInt;
    TypeId: LongInt;
  begin
    if (ANode = nil) or (Trim(AOwnerUnitId) = '') or
      (Trim(ANode.Text) = '') or (Pos('.', ANode.Text) > 0) then
      Exit;

    if ANode.NodeKind = gnkFunctionDecl then
      KindName := 'function'
    else if ANode.NodeKind = gnkProcedureDecl then
      KindName := 'procedure'
    else
      Exit;

    ParamCount := CountDeclParams(ANode);
    ParamSignature := GetParamSignature(ANode);
    for SymbolIndex := 0 to FModel.SymbolCount - 1 do
    begin
      Symbol := FModel.SymbolAt(SymbolIndex);
      if SameText(Symbol.OwnerUnitId, AOwnerUnitId) and
        SameText(Symbol.Name, ANode.Text) and
        SameText(Symbol.Kind, KindName) and
        (Symbol.ParamCount = ParamCount) and
        SameText(Symbol.ParamSignature, ParamSignature) then
        Exit;
    end;

    TypeId := 0;
    if ANode.NodeKind = gnkFunctionDecl then
      for ChildIndex := 0 to ANode.ChildCount - 1 do
      begin
        Child := ANode.ChildAt(ChildIndex);
        if (Child <> nil) and (Child.NodeKind = gnkIdentifier) then
        begin
          TypeId := ResolveTypeIdForOwner(Child.Text, AOwnerUnitId);
          Break;
        end;
      end;

    SymbolId := FModel.AddSymbol(
      ANode.Text,
      KindName,
      AOwnerUnitId,
      TypeId,
      ANode.ByteOffset
    );
    FModel.SetSymbolParamCount(SymbolId, ParamCount);
    FModel.SetSymbolParamSignature(SymbolId, ParamSignature);

    if AUnitScopeId > 0 then
      ScopeId := AUnitScopeId
    else
      ScopeId := EnsureUnitScope(AOwnerUnitId);
    if ScopeId > 0 then
      FModel.SetSymbolScope(SymbolId, ScopeId);
  end;

  procedure RegisterBodiesInNode(
    const ANode: TGreenNode;
    const AOwnerUnitId: string
  );
  var
    ChildIdx, BodyIdx: LongInt;
    Child, BodyChild: TGreenNode;
    SavedScopeId: LongInt;
    UnitScopeId: LongInt;
  begin
    if ANode = nil then
      Exit;
    for ChildIdx := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(ChildIdx);
      if Child = nil then
        Continue;
      if Child.NodeKind = gnkTypeSection then
      begin
        UnitScopeId := EnsureUnitScope(AOwnerUnitId);
        SavedScopeId := FCurrentScopeId;
        if UnitScopeId > 0 then
          FCurrentScopeId := UnitScopeId;
        try
          ProcessTypeSection(Child, AOwnerUnitId);
        finally
          FCurrentScopeId := SavedScopeId;
        end;
      end
      else if (Child.NodeKind = gnkProcedureDecl) or
        (Child.NodeKind = gnkFunctionDecl) then
      begin
        UnitScopeId := EnsureUnitScope(AOwnerUnitId);
        SavedScopeId := FCurrentScopeId;
        if UnitScopeId > 0 then
          FCurrentScopeId := UnitScopeId;
        try
          SeedImportedCallableSymbol(Child, AOwnerUnitId, UnitScopeId);
          for BodyIdx := 0 to Child.ChildCount - 1 do
          begin
            BodyChild := Child.ChildAt(BodyIdx);
            if (BodyChild <> nil) and (BodyChild.NodeKind = gnkBeginBlock) then
            begin
              RegisterProcedureBody(Child.Text, BodyChild, Child, AOwnerUnitId);
              Break;
            end;
          end;
        finally
          FCurrentScopeId := SavedScopeId;
        end;
      end
      else if (Child.NodeKind = gnkInterfaceSection) or
        (Child.NodeKind = gnkImplementationSection) then
        RegisterBodiesInNode(Child, AOwnerUnitId);
    end;
  end;

var
  OwnerUnitId: string;
  Index: LongInt;
  ResolvedUnit: TResolvedUnit;
  SourceText, Line: string;
  UnitLexer: TLexerResult;
  UnitTree: TGreenTree;
  F: Text;
  SourcePath: string;
  TmpDiag: TDiagnosticsSink;
begin
  if FUnitGraph = nil then
    Exit;
  TmpDiag := TDiagnosticsSink.Create;
  try
    for Index := 0 to FUnitGraph.ResolvedUnitCount - 1 do
    begin
      ResolvedUnit := FUnitGraph.ResolvedUnitAt(Index);
      if SameText(ResolvedUnit.CanonicalName, FUnitGraph.RootName) then
        Continue;
      SourcePath := ResolvedUnit.SourcePath;
      if Trim(SourcePath) = '' then
        Continue;
      if not FileExists(SourcePath) then
        Continue;
      Assign(F, SourcePath);
      {$I-}
      Reset(F);
      {$I+}
      if IOResult <> 0 then
        Continue;
      SourceText := '';
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        if SourceText <> '' then
          SourceText := SourceText + #10;
        SourceText := SourceText + Line;
      end;
      Close(F);
      UnitLexer := TLexerResult.Create(SourceText);
      UnitTree := ParseGreenTree(UnitLexer, TmpDiag, 0);
      if (UnitTree <> nil) and UnitTree.IsValid and
        (UnitTree.RootNode <> nil) then
      begin
        OwnerUnitId := ResolvedUnit.UnitId;
        if OwnerUnitId = '' then
          OwnerUnitId := NormalizeUnitIdentity(ResolvedUnit.CanonicalName);
        RegisterBodiesInNode(UnitTree.RootNode, OwnerUnitId);
      end
      else if UnitTree <> nil then
        UnitTree.Free;
      UnitLexer.Free;
    end;
  finally
    TmpDiag.Free;
  end;
end;

end.
