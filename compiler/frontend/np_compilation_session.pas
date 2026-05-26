unit np_compilation_session;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../backend}
{$UNITPATH ../diagnostics}
{$UNITPATH ../ir}
{$UNITPATH ../sema}
{$UNITPATH ../syntax}
{$UNITPATH ../toolchain}
{$UNITPATH ../targets}

interface

uses
  SysUtils, np_ast_facade, np_backend_plan, np_diagnostics_sink, np_green_tree,
  np_lexer, np_hir_types, np_hir_model, np_hir_builder,
  np_hir_printer, np_hir_llvm_emitter, np_source_database, np_target_facts,
  np_toolchain_plan, np_toolchain_profiles, np_toolchain_runner,
  np_unit_graph, np_unit_resolver,
  np_semantic_model, np_semantic_analyzer, np_workspace_model,
  nextpas_json_helpers;

type
  TBuildContext = record
    RequestedSourcePath: string;
    ResolvedSourcePath: string;
    RequestedTargetId: string;
    WorkspaceRootPath: string;
    WorkspaceDiscoveryKind: string;
    WorkspaceDescriptorPath: string;
    PackageManifestPath: string;
    ArtifactRootPath: string;
    OutputDirPath: string;
  end;

  TCompilationOptions = record
    CommandName: string;
    BuildContext: TBuildContext;
    WorkspaceModel: TWorkspaceModel;
    ExplicitUnitRoots: TStringArray;
    NoFold: Boolean;
  end;

  TToolStatusEventRecord = record
    EventKind: string;
    StepId: string;
    ToolRole: string;
    ProfileId: string;
    LogicalExecutable: string;
    SysrootRef: string;
    ResolvedPath: string;
    Status: string;
    ResultValue: string;
    Summary: string;
    ExitCode: LongInt;
    HasExitCode: Boolean;
  end;

  TCompilationSession = class
  private
    FSessionId: string;
    FSourceDatabase: TSourceDatabase;
    FTargetFacts: TTargetFactsView;
    FDiagnosticsSink: TDiagnosticsSink;
    FOptions: TCompilationOptions;
    FRootFileId: TSourceFileId;
    FUnitStateCount: LongInt;
    FLexerResult: TLexerResult;
    FGreenTree: TGreenTree;
    FAstFacade: TAstFacade;
    FSyntaxStatus: string;
    FSearchPathSet: TSearchPathSet;
    FUnitGraph: TUnitGraph;
    FResolutionStatus: string;
    FSearchIndexStatus: string;
    FIndexedSearchRootCount: LongInt;
    FSearchIndexScanCount: LongInt;
    FSemanticModel: TSemanticModel;
    FSemanticStatus: string;
    FMirStatus: string;
    FBackendPlan: TBackendPlan;
    FBackendStatus: string;
    FToolchainPlan: TToolchainPlan;
    FToolchainStatus: string;
    FToolRunStatus: string;
    FToolRunStepCount: LongInt;
    FPrimaryToolRunStatus: string;
    FToolStatusEvents: array of TToolStatusEventRecord;
    FBuildTraceRef: string;
    FBuildTraceJson: string;
    procedure ResetSyntaxState;
    procedure ResetResolutionState;
    procedure ResetSemanticState;
    procedure ResetIrState;
    procedure ResetBackendState;
    procedure ResetToolchainState;
    procedure ClearToolRunState;
    procedure ClearBuildTrace;
    procedure ClearToolStatusEvents;
    procedure AppendToolStatusEvent(
      const AEventKind: string;
      const AStepId: string;
      const AToolRole: string;
      const AProfileId: string;
      const ALogicalExecutable: string;
      const ASysrootRef: string;
      const AResolvedPath: string;
      const AStatus: string;
      const AResultValue: string;
      const ASummary: string;
      const AHasExitCode: Boolean;
      const AExitCode: LongInt
    );
    function BuildTracePlanId: string;
    function BuildTraceDocumentRef: string;
    function PrimaryToolResolvedPath: string;
    function BuildStepOutputsJson(const AToolStep: TToolInvocationStep): string;
    function CollectAdditionalAssemblyBaseNames: TStringArray;
    function FindToolInvocationStep(
      const AStepId: string
    ): TToolInvocationStep;
    function BuildDiagnosticRefsJson(const ADiagnosticId: string): string;
    function BuildToolchainBuildTraceJson(
      const ARunResult: TToolchainRunResult;
      const AResultValue: string;
      const AFailedStepId: string;
      const ADiagnosticId: string
    ): string;
    procedure PropagateSemanticLibraryRequestsToBackendPlan;
    procedure RecordToolStepFinished(
      const AToolStep: TToolInvocationStep;
      const AResolvedPath: string;
      const AStatus: string;
      const AHasExitCode: Boolean;
      const AExitCode: LongInt
    );
    procedure RecordToolPlanFinished(
      const AToolStep: TToolInvocationStep;
      const AResolvedPath: string;
      const AResultValue: string;
      const AHasExitCode: Boolean;
      const AExitCode: LongInt
    );
  public
    constructor CreateBuildSession(
      const Options: TCompilationOptions;
      const TargetFacts: TTargetFactsView
    );
    destructor Destroy; override;
    procedure AnalyzeSyntax;
    procedure ResolveUnits;
    procedure AnalyzeSemantics;
    procedure LowerToMir;
    procedure PlanBackend;
    procedure PlanToolchain;
    procedure RecordToolSelection(
      const AToolStep: TToolInvocationStep;
      const AResolvedPath: string
    );
    procedure RecordToolStepStarted(
      const AToolStep: TToolInvocationStep;
      const AResolvedPath: string
    );
    procedure RecordToolchainSuccess(
      const ARunResult: TToolchainRunResult
    );
    procedure RecordToolchainFailure(
      const ARunResult: TToolchainRunResult;
      const AToolStep: TToolInvocationStep;
      const AResolvedPath: string;
      const AMessageText: string;
      const AHasExitCode: Boolean;
      const AExitCode: LongInt
    );
    function ExecuteToolchain(
      const AExecutableSearchPath: string
    ): TToolchainRunResult;
    function SyntaxStatus: string;
    function ResolutionStatus: string;
    function UnitGraphStatus: string;
    function SemanticStatus: string;
    function SymbolGraphStatus: string;
    function TypeGraphStatus: string;
    function TypedHirStatus: string;
    function MirStatus: string;
    function BackendPlanStatus: string;
    function ToolchainPlanStatus: string;
    function WorkspaceRootPath: string;
    function WorkspaceDiscoveryKind: string;
    function WorkspaceDescriptorPath: string;
    function PackageManifestPath: string;
    function ArtifactRootPath: string;
    function OutputDirPath: string;
    function LexerTokenCount: LongInt;
    function GreenNodeCount: LongInt;
    function AstRootKindName: string;
    function AstDeclaredName: string;
    function HasSyntaxErrors: Boolean;
    function HasResolutionErrors: Boolean;
    function HasSemanticErrors: Boolean;
    function HasMirErrors: Boolean;
    function HasBackendErrors: Boolean;
    function HasToolchainErrors: Boolean;
    function SearchPathCount: LongInt;
    function SearchPathsJson: string;
    function ResolvedUnitCount: LongInt;
    function UnitGraphEdgeCount: LongInt;
    function UnitGraphRootName: string;
    function SymbolCount: LongInt;
    function SymbolsJson: string;
    function BindingsJson: string;
    function DefinitionsJson: string;
    function ScopeCount: LongInt;
    function ScopesJson: string;
    function TypeCount: LongInt;
    function TypesJson: string;
    function TypedHirNodeCount: LongInt;
    function RuntimeContractCount: LongInt;
    function TypedHirRootName: string;
    function MirBlockCount: LongInt;
    function MirOperationCount: LongInt;
    function MirEntryBlockLabel: string;
    function MirRootName: string;
    function BackendOutputKind: string;
    function BackendPrimaryArtifactKind: string;
    function BackendPrimaryArtifactPath: string;
    function BackendArtifactCount: LongInt;
    function BackendArtifactsJson: string;
    function HostId: string;
    function ToolchainBindingId: string;
    function BackendFamily: string;
    function AssemblerProfileId: string;
    function LinkerProfileId: string;
    function ArchiverProfileId: string;
    function ResourceToolProfileId: string;
    function TargetObjectFormat: string;
    function TargetAssemblerFlavor: string;
    function TargetLinkerFlavor: string;
    function TargetRuntimeLayoutKey: string;
    function TargetCSymbolPrefix: string;
    function TargetCLibraryNaming: string;
    function TargetLlvmTriple: string;
    function TargetLlvmDataLayout: string;
    function SysrootMode: string;
    function RuntimeSdkId: string;
    function AllowHostFallback: Boolean;
    function ToolRootKind: string;
    function RuntimeRootKind: string;
    function ResponseFilePolicy: string;
    function LinkScriptPolicy: string;
    function ToolchainPlanFamily: string;
    function ToolProfileRoot: string;
    function LogicalLinkRequestStatus: string;
    function LogicalLinkRequestOutputKind: string;
    function LogicalLibraryRequestCount: LongInt;
    function LogicalLinkRequestJson: string;
    function LlvmToolchainStatus: string;
    function LlvmExecutableSetId: string;
    function LlvmExecutableSetJson: string;
    function PrimaryToolProfileId: string;
    function PrimaryToolStepId: string;
    function PrimaryToolLogicalExecutable: string;
    function PrimaryToolSysrootRef: string;
    function PrimaryToolFailureMapping: string;
    function PrimaryToolWorkingDirectory: string;
    function PrimaryToolArgCount: LongInt;
    function PrimaryToolArgValue(const AIndex: LongInt): string;
    function ToolInvocationCount: LongInt;
    function ToolRunStatus: string;
    function ToolRunStepCount: LongInt;
    function PrimaryToolRunStatus: string;
    function PrimaryToolRole: string;
    function SourceFileCount: LongInt;
    function DiagnosticsCount: LongInt;
    function DiagnosticsErrorCount: LongInt;
    function DiagnosticsWarningCount: LongInt;
    function DiagnosticsPolicyName: string;
    function DiagnosticsJson: string;
    function DiagnosticsSummary: string;
    function SearchIndexStatus: string;
    function IndexedSearchRootCount: LongInt;
    function SearchIndexScanCount: LongInt;
    function ToolStatusEventCount: LongInt;
    function ToolStatusEventsJson: string;
    function ToolInvocationPlanRef: string;
    function ToolInvocationPlanJson: string;
    function LastDiagnosticId: string;
    function LastDiagnosticCode: string;
    function LastDiagnosticPhase: string;
    function LastDiagnosticMessage: string;
    function LastDiagnosticBindingId: string;
    function LastDiagnosticProfileId: string;
    function LastDiagnosticStepId: string;
    function LastDiagnosticLogicalExecutable: string;
    function LastDiagnosticSysrootRef: string;
    function LastDiagnosticResolvedPath: string;
    function LastDiagnosticPrimaryArtifactKind: string;
    function LastDiagnosticPrimaryArtifactPath: string;
    function LastDiagnosticExitCode: LongInt;
    function HasLastDiagnosticExitCode: Boolean;
    function BuildTraceRef: string;
    function BuildTraceJson: string;
    function SessionLifetimeSummary: string;
    function UnitLifetimeSummary: string;
    function StageLifetimeSummary: string;
    property SessionId: string read FSessionId;
    property SourceDatabase: TSourceDatabase read FSourceDatabase;
    property TargetFacts: TTargetFactsView read FTargetFacts;
    property RootFileId: TSourceFileId read FRootFileId;
    property UnitStateCount: LongInt read FUnitStateCount;
  end;

implementation

var
  GSessionNonce: LongInt = 0;

function BuildToolArtifactArrayJson(
  const AValues: array of TToolArtifactRef
): string;
var
  EntryFields: string;
  Index: SizeInt;
begin
  Result := '';
  for Index := 0 to High(AValues) do
  begin
    if Result <> '' then
      Result := Result + ',';
    EntryFields := '';
    AppendJsonField(EntryFields, 'kind', JsonString(AValues[Index].Kind));
    AppendJsonField(EntryFields, 'path', JsonString(AValues[Index].Path));
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := '[' + Result + ']';
end;

function BuildExecutedSidecarArrayJson(
  const AValues: TToolchainExecutedSidecarArray
): string;
var
  EntryFields: string;
  Index: SizeInt;
begin
  Result := '';
  for Index := 0 to High(AValues) do
  begin
    if Result <> '' then
      Result := Result + ',';
    EntryFields := '';
    AppendJsonField(EntryFields, 'kind', JsonString(AValues[Index].Kind));
    AppendJsonField(EntryFields, 'path', JsonString(AValues[Index].Path));
    AppendJsonField(EntryFields, 'ownerStepId', JsonString(AValues[Index].OwnerStepId));
    AppendJsonField(
      EntryFields,
      'materializationTiming',
      JsonString(AValues[Index].MaterializationTiming)
    );
    AppendJsonField(
      EntryFields,
      'cleanupPolicy',
      JsonString(AValues[Index].CleanupPolicy)
    );
    if AValues[Index].Materialized then
      AppendJsonField(EntryFields, 'materialized', 'true')
    else
      AppendJsonField(EntryFields, 'materialized', 'false');
    AppendJsonField(
      EntryFields,
      'cleanupStatus',
      JsonString(AValues[Index].CleanupStatus)
    );
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := '[' + Result + ']';
end;

function BuildSessionId(
  const ACommandName: string;
  const ATargetId: string;
  const ARootFileId: TSourceFileId
): string;
var
  EntropyToken: string;
  SessionNonceText: string;
begin
  Inc(GSessionNonce);
  SessionNonceText := IntToStr(GSessionNonce);
  while Length(SessionNonceText) < 2 do
    SessionNonceText := '0' + SessionNonceText;
  EntropyToken := FormatDateTime('yyyymmddhhnnsszzz', Now) + '-' +
    SessionNonceText;
  Result := ACommandName + '-' + ATargetId + '-' + EntropyToken +
    '-file-' + IntToStr(ARootFileId);
end;

constructor TCompilationSession.CreateBuildSession(
  const Options: TCompilationOptions;
  const TargetFacts: TTargetFactsView
);
begin
  inherited Create;

  FSourceDatabase := TSourceDatabase.Create;
  FDiagnosticsSink := TDiagnosticsSink.CreateDefault;
  FTargetFacts := TargetFacts;
  FOptions := Options;
  if FOptions.CommandName = '' then
    FOptions.CommandName := 'build';
  if FOptions.BuildContext.RequestedTargetId = '' then
    FOptions.BuildContext.RequestedTargetId := TargetFacts.TargetId;
  if FOptions.BuildContext.ResolvedSourcePath = '' then
    FOptions.BuildContext.ResolvedSourcePath := ExpandFileName(
      FOptions.BuildContext.RequestedSourcePath
    );
  FRootFileId := FSourceDatabase.RegisterRootSource(
    FOptions.BuildContext.RequestedSourcePath
  );
  FUnitStateCount := 1;
  FLexerResult := nil;
  FGreenTree := nil;
  FAstFacade := nil;
  FSyntaxStatus := 'deferred';
  FSearchPathSet := nil;
  FUnitGraph := nil;
  FResolutionStatus := 'deferred';
  FSearchIndexStatus := 'deferred';
  FIndexedSearchRootCount := 0;
  FSearchIndexScanCount := 0;
  FSemanticModel := nil;
  FSemanticStatus := 'deferred';
  FMirStatus := 'deferred';
  FBackendPlan := nil;
  FBackendStatus := 'deferred';
  FToolchainPlan := nil;
  FToolchainStatus := 'deferred';
  ClearToolRunState;
  ClearToolStatusEvents;
  ClearBuildTrace;
  FSessionId := BuildSessionId(
    FOptions.CommandName,
    FTargetFacts.TargetId,
    FRootFileId
  );
end;

destructor TCompilationSession.Destroy;
begin
  FOptions.WorkspaceModel.Free;
  FToolchainPlan.Free;
  FBackendPlan.Free;
  FSemanticModel.Free;
  FUnitGraph.Free;
  FSearchPathSet.Free;
  FAstFacade.Free;
  FGreenTree.Free;
  FLexerResult.Free;
  FDiagnosticsSink.Free;
  FSourceDatabase.Free;
  inherited Destroy;
end;

procedure TCompilationSession.ResetSyntaxState;
begin
  ResetResolutionState;
  FreeAndNil(FAstFacade);
  FreeAndNil(FGreenTree);
  FreeAndNil(FLexerResult);
end;

procedure TCompilationSession.ResetResolutionState;
begin
  ResetSemanticState;
  FreeAndNil(FUnitGraph);
  FreeAndNil(FSearchPathSet);
  FResolutionStatus := 'deferred';
  FSearchIndexStatus := 'deferred';
  FIndexedSearchRootCount := 0;
  FSearchIndexScanCount := 0;
end;

procedure TCompilationSession.ResetSemanticState;
begin
  ResetIrState;
  FreeAndNil(FSemanticModel);
  FSemanticStatus := 'deferred';
end;

procedure TCompilationSession.ResetIrState;
begin
  ResetBackendState;
  FMirStatus := 'deferred';
end;

procedure TCompilationSession.ResetBackendState;
begin
  ResetToolchainState;
  FreeAndNil(FBackendPlan);
  FBackendStatus := 'deferred';
end;

procedure TCompilationSession.ResetToolchainState;
begin
  FreeAndNil(FToolchainPlan);
  FToolchainStatus := 'deferred';
  ClearToolRunState;
  ClearToolStatusEvents;
  ClearBuildTrace;
end;

procedure TCompilationSession.ClearToolRunState;
begin
  FToolRunStatus := '';
  FToolRunStepCount := 0;
  FPrimaryToolRunStatus := '';
end;

procedure TCompilationSession.ClearBuildTrace;
begin
  FBuildTraceRef := '';
  FBuildTraceJson := '';
end;

procedure TCompilationSession.ClearToolStatusEvents;
begin
  SetLength(FToolStatusEvents, 0);
end;

procedure TCompilationSession.AppendToolStatusEvent(
  const AEventKind: string;
  const AStepId: string;
  const AToolRole: string;
  const AProfileId: string;
  const ALogicalExecutable: string;
  const ASysrootRef: string;
  const AResolvedPath: string;
  const AStatus: string;
  const AResultValue: string;
  const ASummary: string;
  const AHasExitCode: Boolean;
  const AExitCode: LongInt
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FToolStatusEvents);
  SetLength(FToolStatusEvents, NextIndex + 1);
  FToolStatusEvents[NextIndex].EventKind := AEventKind;
  FToolStatusEvents[NextIndex].StepId := AStepId;
  FToolStatusEvents[NextIndex].ToolRole := AToolRole;
  FToolStatusEvents[NextIndex].ProfileId := AProfileId;
  FToolStatusEvents[NextIndex].LogicalExecutable := ALogicalExecutable;
  FToolStatusEvents[NextIndex].SysrootRef := ASysrootRef;
  FToolStatusEvents[NextIndex].ResolvedPath := AResolvedPath;
  FToolStatusEvents[NextIndex].Status := AStatus;
  FToolStatusEvents[NextIndex].ResultValue := AResultValue;
  FToolStatusEvents[NextIndex].Summary := ASummary;
  FToolStatusEvents[NextIndex].HasExitCode := AHasExitCode;
  FToolStatusEvents[NextIndex].ExitCode := AExitCode;
end;

function TCompilationSession.BuildTracePlanId: string;
begin
  Result := 'plan-' + FSessionId + '-primary-tool';
end;

function TCompilationSession.BuildTraceDocumentRef: string;
begin
  Result := 'trace-' + FSessionId + '-toolchain-plan';
end;

function TCompilationSession.PrimaryToolResolvedPath: string;
var
  Index: LongInt;
begin
  for Index := High(FToolStatusEvents) downto 0 do
    if (FToolStatusEvents[Index].ResolvedPath <> '') and
      SameText(FToolStatusEvents[Index].StepId, PrimaryToolStepId) then
      Exit(FToolStatusEvents[Index].ResolvedPath);

  if FToolchainPlan <> nil then
    Exit(FToolchainPlan.PrimaryToolExecutableRef);

  Result := '';
end;

function TCompilationSession.BuildStepOutputsJson(
  const AToolStep: TToolInvocationStep
): string;
begin
  Result := BuildToolArtifactArrayJson(AToolStep.Outputs);
end;

function TCompilationSession.CollectAdditionalAssemblyBaseNames: TStringArray;
var
  CandidateBaseName: string;
  Index: LongInt;
  ResolvedSourcePath: string;
  ResolvedUnit: TResolvedUnit;

  procedure AddUniqueBaseName(const ABaseName: string);
  var
    ExistingIndex: LongInt;
    NextIndex: SizeInt;
  begin
    if Trim(ABaseName) = '' then
      Exit;
    for ExistingIndex := 0 to Length(Result) - 1 do
      if SameText(Result[ExistingIndex], ABaseName) then
        Exit;
    NextIndex := Length(Result);
    SetLength(Result, NextIndex + 1);
    Result[NextIndex] := ABaseName;
  end;
begin
  SetLength(Result, 0);
  if FUnitGraph = nil then
    Exit;
  if SameText(AstRootKindName, 'unit') then
    Exit;

  ResolvedSourcePath := ExpandFileName(FOptions.BuildContext.ResolvedSourcePath);
  for Index := 0 to FUnitGraph.ResolvedUnitCount - 1 do
  begin
    ResolvedUnit := FUnitGraph.ResolvedUnitAt(Index);
    if Trim(ResolvedUnit.SourcePath) = '' then
      Continue;
    if SameText(ResolvedUnit.OriginClass, 'implicit-runtime') then
      Continue;
    if SameText(ExpandFileName(ResolvedUnit.SourcePath), ResolvedSourcePath) then
      Continue;
    CandidateBaseName := ChangeFileExt(
      ExtractFileName(ResolvedUnit.SourcePath),
      ''
    );
    AddUniqueBaseName(CandidateBaseName);
  end;
end;

function TCompilationSession.FindToolInvocationStep(
  const AStepId: string
): TToolInvocationStep;
var
  Index: LongInt;
begin
  Result.StepId := '';
  Result.ToolRole := '';
  Result.ProfileId := '';
  Result.SysrootRef := '';
  Result.LogicalExecutable := '';
  Result.ExecutableRef := '';
  Result.WorkingDirectory := '';
  Result.FailureMapping := '';
  SetLength(Result.Argv, 0);
  SetLength(Result.EnvDelta, 0);
  SetLength(Result.Inputs, 0);
  SetLength(Result.Outputs, 0);
  SetLength(Result.Sidecars, 0);

  if FToolchainPlan = nil then
    Exit;

  for Index := 0 to FToolchainPlan.ToolInvocationCount - 1 do
    if SameText(FToolchainPlan.StepAt(Index).StepId, AStepId) then
      Exit(FToolchainPlan.StepAt(Index));
end;

function TCompilationSession.BuildDiagnosticRefsJson(
  const ADiagnosticId: string
): string;
begin
  if ADiagnosticId = '' then
    Exit('[]');

  Result := '[' + JsonString(ADiagnosticId) + ']';
end;

function TCompilationSession.BuildToolchainBuildTraceJson(
  const ARunResult: TToolchainRunResult;
  const AResultValue: string;
  const AFailedStepId: string;
  const ADiagnosticId: string
): string;
var
  ExecutedStep: TToolchainExecutedStep;
  PrimaryToolStep: TToolInvocationStep;
  StepFields: string;
  StepJson: string;
  ToolStep: TToolInvocationStep;
  TraceFields: string;
  StepIndex: LongInt;
begin
  if (ARunResult = nil) or (ARunResult.StepCount = 0) then
    Exit('');

  PrimaryToolStep := FindToolInvocationStep(ARunResult.StepAt(0).StepId);
  StepJson := '';
  for StepIndex := 0 to ARunResult.StepCount - 1 do
  begin
    ExecutedStep := ARunResult.StepAt(StepIndex);
    ToolStep := FindToolInvocationStep(ExecutedStep.StepId);
    if StepJson <> '' then
      StepJson := StepJson + ',';

    StepFields := '';
    AppendJsonField(StepFields, 'stepId', JsonString(ExecutedStep.StepId));
    AppendJsonField(StepFields, 'profileId', JsonString(ToolStep.ProfileId));
    AppendJsonField(StepFields, 'toolRole', JsonString(ToolStep.ToolRole));
    AppendJsonField(StepFields, 'status', JsonString(ExecutedStep.Status));
    AppendJsonField(
      StepFields,
      'logicalExecutable',
      JsonString(ToolStep.LogicalExecutable)
    );
    AppendJsonField(StepFields, 'sysrootRef', JsonString(ToolStep.SysrootRef));
    if ExecutedStep.ResolvedPath <> '' then
      AppendJsonField(
        StepFields,
        'resolvedPath',
        JsonString(ExecutedStep.ResolvedPath)
      );
    AppendJsonField(
      StepFields,
      'primaryOutputs',
      BuildStepOutputsJson(ToolStep)
    );
    AppendJsonField(
      StepFields,
      'sidecars',
      BuildExecutedSidecarArrayJson(ExecutedStep.Sidecars)
    );
    if SameText(ExecutedStep.StepId, AFailedStepId) then
      AppendJsonField(
        StepFields,
        'diagnosticRefs',
        BuildDiagnosticRefsJson(ADiagnosticId)
      )
    else
      AppendJsonField(StepFields, 'diagnosticRefs', '[]');
    if ExecutedStep.HasExitCode then
      AppendJsonField(StepFields, 'exitCode', IntToStr(ExecutedStep.ExitCode));
    StepJson := StepJson + '{' + StepFields + '}';
  end;

  TraceFields := '';
  AppendJsonField(
    TraceFields,
    'traceKind',
    JsonString('toolchain-build-trace')
  );
  AppendJsonField(TraceFields, 'sessionId', JsonString(FSessionId));
  AppendJsonField(TraceFields, 'planId', JsonString(BuildTracePlanId));
  AppendJsonField(TraceFields, 'bindingId', JsonString(ToolchainBindingId));
  AppendJsonField(TraceFields, 'hostId', JsonString(HostId));
  AppendJsonField(TraceFields, 'targetId', JsonString(FTargetFacts.TargetId));
  AppendJsonField(
    TraceFields,
    'profileId',
    JsonString(PrimaryToolStep.ProfileId)
  );
  AppendJsonField(
    TraceFields,
    'toolRole',
    JsonString(PrimaryToolStep.ToolRole)
  );
  AppendJsonField(
    TraceFields,
    'sysrootRef',
    JsonString(PrimaryToolStep.SysrootRef)
  );
  AppendJsonField(TraceFields, 'result', JsonString(AResultValue));
  AppendJsonField(TraceFields, 'steps', '[' + StepJson + ']');
  Result := '{' + TraceFields + '}';
end;

procedure TCompilationSession.AnalyzeSyntax;
begin
  ResetSyntaxState;
  FLexerResult := TLexerResult.Create(FSourceDatabase.RootSourceText);
  FGreenTree := ParseGreenTree(FLexerResult, FDiagnosticsSink, FRootFileId);
  FAstFacade := TAstFacade.Create(FGreenTree);

  if FDiagnosticsSink.HasErrors or (FGreenTree = nil) or not FGreenTree.IsValid then
    FSyntaxStatus := 'failure'
  else
    FSyntaxStatus := 'ready';
end;

procedure TCompilationSession.ResolveUnits;
var
  Resolver: TUnitResolver;
begin
  ResetResolutionState;
  if (FAstFacade = nil) or not FAstFacade.IsValid then
  begin
    FResolutionStatus := 'failure';
    Exit;
  end;

  Resolver := TUnitResolver.Create(
    FSourceDatabase,
    FTargetFacts,
    FDiagnosticsSink,
    FRootFileId,
    FOptions.WorkspaceModel.ProjectUnitRootInfos,
    FOptions.ExplicitUnitRoots
  );
  try
    Resolver.ResolveRoot(FAstFacade);
    FSearchIndexStatus := Resolver.SearchIndexStatus;
    FIndexedSearchRootCount := Resolver.IndexedRootCount;
    FSearchIndexScanCount := Resolver.SearchIndexScanCount;
    FSearchPathSet := Resolver.DetachSearchPaths;
    FUnitGraph := Resolver.DetachUnitGraph;
    FResolutionStatus := Resolver.ResolutionStatus;
  finally
    Resolver.Free;
  end;

  if (FUnitGraph <> nil) and (FUnitGraph.ResolvedUnitCount > FUnitStateCount) then
    FUnitStateCount := FUnitGraph.ResolvedUnitCount;
end;

procedure TCompilationSession.AnalyzeSemantics;
var
  Analyzer: TSemanticAnalyzer;
begin
  ResetSemanticState;
  if (FAstFacade = nil) or (FUnitGraph = nil) or (FResolutionStatus <> 'ready') then
  begin
    FSemanticStatus := 'failure';
    Exit;
  end;

  Analyzer := TSemanticAnalyzer.Create(
    FAstFacade,
    FUnitGraph,
    FDiagnosticsSink,
    FRootFileId,
    FOptions.NoFold
  );
  try
    Analyzer.Analyze;
    FSemanticModel := Analyzer.DetachModel;
    if FSemanticModel = nil then
      FSemanticStatus := 'deferred'
    else
      FSemanticStatus := FSemanticModel.Status;
  finally
    Analyzer.Free;
  end;
end;

procedure TCompilationSession.LowerToMir;
var
  HirBuilder: THIRBuilder;
  HirPrinter: THIRPrinter;
  HirPath: string;
begin
  ResetIrState;
  if (FSemanticModel = nil) or (FSemanticStatus <> 'ready') then
  begin
    FMirStatus := 'failure';
    Exit;
  end;

  FMirStatus := 'ready';

  if GetEnvironmentVariable('NEXTPAS_HIR_DUMP') = '1' then
  begin
    HirBuilder := THIRBuilder.Create(FSemanticModel);
    try
      HirBuilder.Build;
      HirPath := ChangeFileExt(FOptions.BuildContext.ResolvedSourcePath, '.hir');
      HirPrinter := THIRPrinter.Create(HirBuilder.Module);
      try
        HirPrinter.Print;
        HirPrinter.SaveToFile(HirPath);
      finally
        HirPrinter.Free;
      end;
    finally
      HirBuilder.Free;
    end;
  end;
end;

procedure TCompilationSession.PlanBackend;
var
  Planner: TBackendPlanner;
begin
  ResetBackendState;
  if (FSemanticModel = nil) or (FMirStatus <> 'ready') then
  begin
    FBackendStatus := 'failure';
    Exit;
  end;

  Planner := TBackendPlanner.Create(
    FSemanticModel,
    FTargetFacts,
    FOptions.BuildContext.RequestedSourcePath,
    ArtifactRootPath,
    OutputDirPath,
    AstRootKindName,
    FOptions.NoFold
  );
  try
    Planner.Plan;
    FBackendPlan := Planner.DetachPlan;
    if FBackendPlan = nil then
      FBackendStatus := 'deferred'
    else
      FBackendStatus := FBackendPlan.Status;
  finally
    Planner.Free;
  end;

  if FBackendStatus = 'ready' then
    PropagateSemanticLibraryRequestsToBackendPlan;
end;

procedure TCompilationSession.PropagateSemanticLibraryRequestsToBackendPlan;
var
  Index: LongInt;
  LibraryRequest: TSemanticLibraryRequest;
begin
  if (FBackendPlan = nil) or (FSemanticModel = nil) or
    (FSemanticStatus <> 'ready') then
    Exit;

  for Index := 0 to FSemanticModel.LibraryRequestCount - 1 do
  begin
    LibraryRequest := FSemanticModel.LibraryRequestAt(Index);
    FBackendPlan.AddLogicalLibraryRequest(
      LibraryRequest.LogicalId,
      LibraryRequest.LinkageKind,
      LibraryRequest.Strength
    );
  end;
end;

procedure TCompilationSession.PlanToolchain;
var
  PlanningProfileId: string;
  Planner: TToolchainPlanner;
begin
  ResetToolchainState;
  if (FBackendPlan = nil) or (FBackendStatus <> 'ready') then
  begin
    FToolchainStatus := 'failure';
    Exit;
  end;

  Planner := TToolchainPlanner.Create(
    FBackendPlan,
    FTargetFacts,
    FOptions.BuildContext.ResolvedSourcePath,
    ArtifactRootPath,
    FOptions.WorkspaceModel.ProjectUnitRoots,
    FOptions.ExplicitUnitRoots,
    CollectAdditionalAssemblyBaseNames
  );
  try
    Planner.PlanFromBackend;
    FToolchainPlan := Planner.DetachPlan;
  finally
    Planner.Free;
  end;

  if FToolchainPlan = nil then
  begin
    FToolchainStatus := 'deferred';
    Exit;
  end;

  FToolchainStatus := FToolchainPlan.Status;
  if (FToolchainStatus <> 'failure') or (FToolchainPlan.FailureCode = '') then
    Exit;

  PlanningProfileId := FToolchainPlan.PrimaryToolProfileId;
  if PlanningProfileId = '' then
    PlanningProfileId := FToolchainPlan.LlvmExecutableSetId;
  FDiagnosticsSink.EmitToolchainError(
    FToolchainPlan.FailureCode,
    ToolchainBindingId,
    PlanningProfileId,
    FToolchainPlan.PrimaryToolStepId,
    FToolchainPlan.PrimaryToolLogicalExecutable,
    FToolchainPlan.PrimaryToolSysrootRef,
    '',
    BackendPrimaryArtifactKind,
    BackendPrimaryArtifactPath,
    False,
    0,
    FToolchainPlan.FailureMessage
  );
end;

procedure TCompilationSession.RecordToolSelection(
  const AToolStep: TToolInvocationStep;
  const AResolvedPath: string
);
begin
  AppendToolStatusEvent(
    'toolchain.tool-selected',
    AToolStep.StepId,
    AToolStep.ToolRole,
    AToolStep.ProfileId,
    AToolStep.LogicalExecutable,
    AToolStep.SysrootRef,
    AResolvedPath,
    '',
    '',
    'tool selected',
    False,
    0
  );
end;

procedure TCompilationSession.RecordToolStepStarted(
  const AToolStep: TToolInvocationStep;
  const AResolvedPath: string
);
begin
  AppendToolStatusEvent(
    'toolchain.step-started',
    AToolStep.StepId,
    AToolStep.ToolRole,
    AToolStep.ProfileId,
    AToolStep.LogicalExecutable,
    AToolStep.SysrootRef,
    AResolvedPath,
    '',
    '',
    'step started',
    False,
    0
  );
end;

procedure TCompilationSession.RecordToolStepFinished(
  const AToolStep: TToolInvocationStep;
  const AResolvedPath: string;
  const AStatus: string;
  const AHasExitCode: Boolean;
  const AExitCode: LongInt
);
begin
  AppendToolStatusEvent(
    'toolchain.step-finished',
    AToolStep.StepId,
    AToolStep.ToolRole,
    AToolStep.ProfileId,
    AToolStep.LogicalExecutable,
    AToolStep.SysrootRef,
    AResolvedPath,
    AStatus,
    '',
    'step finished',
    AHasExitCode,
    AExitCode
  );
end;

procedure TCompilationSession.RecordToolPlanFinished(
  const AToolStep: TToolInvocationStep;
  const AResolvedPath: string;
  const AResultValue: string;
  const AHasExitCode: Boolean;
  const AExitCode: LongInt
);
begin
  AppendToolStatusEvent(
    'toolchain.plan-finished',
    AToolStep.StepId,
    AToolStep.ToolRole,
    AToolStep.ProfileId,
    AToolStep.LogicalExecutable,
    AToolStep.SysrootRef,
    AResolvedPath,
    '',
    AResultValue,
    'plan finished',
    AHasExitCode,
    AExitCode
  );
end;

procedure TCompilationSession.RecordToolchainSuccess(
  const ARunResult: TToolchainRunResult
);
var
  LastStep: TToolchainExecutedStep;
  LastToolStep: TToolInvocationStep;
  StepIndex: LongInt;
  ToolStep: TToolInvocationStep;
begin
  ClearToolStatusEvents;
  ClearBuildTrace;
  if ARunResult = nil then
    Exit;

  for StepIndex := 0 to ARunResult.StepCount - 1 do
  begin
    ToolStep := FindToolInvocationStep(ARunResult.StepAt(StepIndex).StepId);
    RecordToolSelection(ToolStep, ARunResult.StepAt(StepIndex).ResolvedPath);
    RecordToolStepStarted(ToolStep, ARunResult.StepAt(StepIndex).ResolvedPath);
    RecordToolStepFinished(
      ToolStep,
      ARunResult.StepAt(StepIndex).ResolvedPath,
      ARunResult.StepAt(StepIndex).Status,
      ARunResult.StepAt(StepIndex).HasExitCode,
      ARunResult.StepAt(StepIndex).ExitCode
    );
  end;

  if ARunResult.StepCount = 0 then
    Exit;

  LastStep := ARunResult.StepAt(ARunResult.StepCount - 1);
  LastToolStep := FindToolInvocationStep(LastStep.StepId);
  RecordToolPlanFinished(
    LastToolStep,
    LastStep.ResolvedPath,
    'success',
    LastStep.HasExitCode,
    LastStep.ExitCode
  );
  FBuildTraceRef := BuildTraceDocumentRef;
  FBuildTraceJson := BuildToolchainBuildTraceJson(
    ARunResult,
    'success',
    '',
    ''
  );
end;

procedure TCompilationSession.RecordToolchainFailure(
  const ARunResult: TToolchainRunResult;
  const AToolStep: TToolInvocationStep;
  const AResolvedPath: string;
  const AMessageText: string;
  const AHasExitCode: Boolean;
  const AExitCode: LongInt
);
var
  DiagnosticIdValue: string;
  LastStep: TToolchainExecutedStep;
  LastToolStep: TToolInvocationStep;
  StepIndex: LongInt;
  ToolStep: TToolInvocationStep;
begin
  FDiagnosticsSink.EmitToolchainError(
    AToolStep.FailureMapping,
    ToolchainBindingId,
    AToolStep.ProfileId,
    AToolStep.StepId,
    AToolStep.LogicalExecutable,
    AToolStep.SysrootRef,
    AResolvedPath,
    BackendPrimaryArtifactKind,
    BackendPrimaryArtifactPath,
    AHasExitCode,
    AExitCode,
    AMessageText
  );

  DiagnosticIdValue := FDiagnosticsSink.LastDiagnosticId;
  ClearToolStatusEvents;
  ClearBuildTrace;
  if ARunResult = nil then
    Exit;

  for StepIndex := 0 to ARunResult.StepCount - 1 do
  begin
    ToolStep := FindToolInvocationStep(ARunResult.StepAt(StepIndex).StepId);
    RecordToolSelection(ToolStep, ARunResult.StepAt(StepIndex).ResolvedPath);
    RecordToolStepStarted(ToolStep, ARunResult.StepAt(StepIndex).ResolvedPath);
    RecordToolStepFinished(
      ToolStep,
      ARunResult.StepAt(StepIndex).ResolvedPath,
      ARunResult.StepAt(StepIndex).Status,
      ARunResult.StepAt(StepIndex).HasExitCode,
      ARunResult.StepAt(StepIndex).ExitCode
    );
  end;

  if ARunResult.StepCount = 0 then
    Exit;

  LastStep := ARunResult.StepAt(ARunResult.StepCount - 1);
  LastToolStep := FindToolInvocationStep(LastStep.StepId);
  RecordToolPlanFinished(
    LastToolStep,
    LastStep.ResolvedPath,
    'failed',
    AHasExitCode,
    AExitCode
  );
  FBuildTraceRef := BuildTraceDocumentRef;
  FBuildTraceJson := BuildToolchainBuildTraceJson(
    ARunResult,
    'failed',
    AToolStep.StepId,
    DiagnosticIdValue
  );
end;

function TCompilationSession.ExecuteToolchain(
  const AExecutableSearchPath: string
): TToolchainRunResult;
var
  FailedStep: TToolchainExecutedStep;
  FailedToolStep: TToolInvocationStep;
  FailureMessageText: string;
  PrimaryStep: TToolchainExecutedStep;
  PrimaryToolStep: TToolInvocationStep;
  StepIndex: LongInt;
begin
  Result := ExecuteToolchainPlan(FToolchainPlan, AExecutableSearchPath);

  ClearToolRunState;
  if Result = nil then
    Exit;

  if Result.StepCount > 0 then
  begin
    PrimaryStep := Result.StepAt(0);
    PrimaryToolStep := FindToolInvocationStep(PrimaryStep.StepId);
    RecordToolSelection(PrimaryToolStep, PrimaryStep.ResolvedPath);
    RecordToolStepStarted(PrimaryToolStep, PrimaryStep.ResolvedPath);
  end
  else
  begin
    PrimaryToolStep.StepId := '';
    PrimaryToolStep.ToolRole := '';
    PrimaryToolStep.ProfileId := '';
    PrimaryToolStep.SysrootRef := '';
    PrimaryToolStep.LogicalExecutable := '';
    PrimaryToolStep.ExecutableRef := '';
    PrimaryToolStep.WorkingDirectory := '';
    PrimaryToolStep.FailureMapping := '';
    SetLength(PrimaryToolStep.Argv, 0);
    SetLength(PrimaryToolStep.EnvDelta, 0);
    SetLength(PrimaryToolStep.Inputs, 0);
    SetLength(PrimaryToolStep.Outputs, 0);
    SetLength(PrimaryToolStep.Sidecars, 0);
    PrimaryStep.StepId := '';
    PrimaryStep.LogicalExecutable := '';
    PrimaryStep.ResolvedPath := '';
    PrimaryStep.Status := '';
    PrimaryStep.ExitCode := 0;
    PrimaryStep.HasExitCode := False;
  end;

  if Result.Status = 'success' then
    RecordToolchainSuccess(Result)
  else
  begin
    FailedStep := PrimaryStep;
    FailedToolStep := PrimaryToolStep;
    for StepIndex := 0 to Result.StepCount - 1 do
      if Result.StepAt(StepIndex).Status = 'failed' then
      begin
        FailedStep := Result.StepAt(StepIndex);
        FailedToolStep := FindToolInvocationStep(FailedStep.StepId);
        Break;
      end;

    if FailedStep.HasExitCode then
      FailureMessageText := 'compiler exit code ' + IntToStr(FailedStep.ExitCode)
    else if Result.FailureMessage <> '' then
      FailureMessageText := Result.FailureMessage
    else
      FailureMessageText := 'toolchain execution failed';

    RecordToolchainFailure(
      Result,
      FailedToolStep,
      FailedStep.ResolvedPath,
      FailureMessageText,
      FailedStep.HasExitCode,
      FailedStep.ExitCode
    );
  end;

  FToolRunStatus := Result.Status;
  FToolRunStepCount := Result.StepCount;
  FPrimaryToolRunStatus := PrimaryStep.Status;
end;

function TCompilationSession.SyntaxStatus: string;
begin
  Result := FSyntaxStatus;
end;

function TCompilationSession.ResolutionStatus: string;
begin
  Result := FResolutionStatus;
end;

function TCompilationSession.UnitGraphStatus: string;
begin
  if FUnitGraph = nil then
    Exit('deferred');

  Result := FUnitGraph.Status;
end;

function TCompilationSession.SemanticStatus: string;
begin
  Result := FSemanticStatus;
end;

function TCompilationSession.SymbolGraphStatus: string;
begin
  if FSemanticStatus = 'ready' then
    Exit('ready');
  if FSemanticStatus = 'failure' then
    Exit('failure');

  Result := 'deferred';
end;

function TCompilationSession.TypeGraphStatus: string;
begin
  Result := SymbolGraphStatus;
end;

function TCompilationSession.TypedHirStatus: string;
begin
  Result := SymbolGraphStatus;
end;

function TCompilationSession.MirStatus: string;
begin
  Result := FMirStatus;
end;

function TCompilationSession.BackendPlanStatus: string;
begin
  Result := FBackendStatus;
end;

function TCompilationSession.ToolchainPlanStatus: string;
begin
  Result := FToolchainStatus;
end;

function TCompilationSession.WorkspaceRootPath: string;
begin
  if FOptions.WorkspaceModel <> nil then
    Exit(FOptions.WorkspaceModel.WorkspaceRootPath);

  Result := FOptions.BuildContext.WorkspaceRootPath;
end;

function TCompilationSession.WorkspaceDiscoveryKind: string;
begin
  if FOptions.WorkspaceModel <> nil then
    Exit(FOptions.WorkspaceModel.DiscoveryKind);

  Result := FOptions.BuildContext.WorkspaceDiscoveryKind;
end;

function TCompilationSession.WorkspaceDescriptorPath: string;
begin
  if FOptions.WorkspaceModel <> nil then
    Exit(FOptions.WorkspaceModel.WorkspaceDescriptorPath);

  Result := FOptions.BuildContext.WorkspaceDescriptorPath;
end;

function TCompilationSession.PackageManifestPath: string;
begin
  if FOptions.WorkspaceModel <> nil then
    Exit(FOptions.WorkspaceModel.PackageManifestPath);

  Result := FOptions.BuildContext.PackageManifestPath;
end;

function TCompilationSession.ArtifactRootPath: string;
begin
  if FOptions.WorkspaceModel <> nil then
    Exit(FOptions.WorkspaceModel.ArtifactRootPath);

  Result := FOptions.BuildContext.ArtifactRootPath;
end;

function TCompilationSession.OutputDirPath: string;
begin
  if FOptions.WorkspaceModel <> nil then
    Exit(FOptions.WorkspaceModel.OutputDirPath);

  Result := FOptions.BuildContext.OutputDirPath;
end;

function TCompilationSession.LexerTokenCount: LongInt;
begin
  if FLexerResult = nil then
    Exit(0);

  Result := FLexerResult.TokenCount;
end;

function TCompilationSession.GreenNodeCount: LongInt;
begin
  if FGreenTree = nil then
    Exit(0);

  Result := FGreenTree.NodeCount;
end;

function TCompilationSession.AstRootKindName: string;
begin
  if FAstFacade = nil then
    Exit('unknown');

  Result := FAstFacade.RootKindName;
end;

function TCompilationSession.AstDeclaredName: string;
begin
  if FAstFacade = nil then
    Exit('');

  Result := FAstFacade.DeclaredName;
end;

function TCompilationSession.HasSyntaxErrors: Boolean;
begin
  Result := FDiagnosticsSink.HasErrors;
end;

function TCompilationSession.HasResolutionErrors: Boolean;
begin
  Result := FResolutionStatus = 'failure';
end;

function TCompilationSession.HasSemanticErrors: Boolean;
begin
  Result := FSemanticStatus = 'failure';
end;

function TCompilationSession.HasMirErrors: Boolean;
begin
  Result := FMirStatus = 'failure';
end;

function TCompilationSession.HasBackendErrors: Boolean;
begin
  Result := FBackendStatus = 'failure';
end;

function TCompilationSession.HasToolchainErrors: Boolean;
begin
  Result := FToolchainStatus = 'failure';
end;

function TCompilationSession.SearchPathCount: LongInt;
begin
  if FSearchPathSet = nil then
    Exit(0);

  Result := FSearchPathSet.Count;
end;

function TCompilationSession.SearchIndexStatus: string;
begin
  Result := FSearchIndexStatus;
end;

function TCompilationSession.IndexedSearchRootCount: LongInt;
begin
  Result := FIndexedSearchRootCount;
end;

function TCompilationSession.SearchIndexScanCount: LongInt;
begin
  Result := FSearchIndexScanCount;
end;

function TCompilationSession.SearchPathsJson: string;
var
  Entry: TSearchPathEntry;
  EntryFields: string;
  Index: LongInt;
begin
  if FSearchPathSet = nil then
    Exit('[]');

  Result := '[';
  for Index := 0 to FSearchPathSet.Count - 1 do
  begin
    if Index > 0 then
      Result := Result + ',';

    Entry := FSearchPathSet.EntryAt(Index);
    EntryFields := '';
    AppendJsonField(EntryFields, 'scopeName', JsonString(Entry.ScopeName));
    AppendJsonField(
      EntryFields,
      'provenanceKind',
      JsonString(Entry.ProvenanceKind)
    );
    AppendJsonField(EntryFields, 'packageName', JsonString(Entry.PackageName));
    AppendJsonField(
      EntryFields,
      'manifestPath',
      JsonString(Entry.ManifestPath)
    );
    AppendJsonField(
      EntryFields,
      'workspaceMemberPath',
      JsonString(Entry.WorkspaceMemberPath)
    );
    AppendJsonField(EntryFields, 'rootPath', JsonString(Entry.RootPath));
    Result := Result + '{' + EntryFields + '}';
  end;
  Result := Result + ']';
end;

function TCompilationSession.ResolvedUnitCount: LongInt;
begin
  if FUnitGraph = nil then
    Exit(0);

  Result := FUnitGraph.ResolvedUnitCount;
end;

function TCompilationSession.UnitGraphEdgeCount: LongInt;
begin
  if FUnitGraph = nil then
    Exit(0);

  Result := FUnitGraph.EdgeCount;
end;

function TCompilationSession.UnitGraphRootName: string;
begin
  if FUnitGraph = nil then
    Exit('');

  Result := FUnitGraph.RootName;
end;

function TCompilationSession.SymbolCount: LongInt;
begin
  if FSemanticModel = nil then
    Exit(0);

  Result := FSemanticModel.SymbolCount;
end;

function SemanticScopeKindName(const AKind: TScopeKind): string;
begin
  case AKind of
    skCompilation:
      Result := 'compilation';
    skUnit:
      Result := 'unit';
    skInterface:
      Result := 'interface';
    skImplementation:
      Result := 'implementation';
    skCallable:
      Result := 'callable';
    skRecord:
      Result := 'record';
    skClass:
      Result := 'class';
    skBlock:
      Result := 'block';
  end;
end;

function TCompilationSession.SymbolsJson: string;
var
  Fields: string;
  Index: LongInt;
  Scope: TSemanticScope;
  Symbol: TSemanticSymbol;
  SymbolType: TSemanticType;
  UnitInfo: TResolvedUnit;
begin
  if FSemanticModel = nil then
    Exit('[]');

  Result := '[';
  for Index := 0 to FSemanticModel.SymbolCount - 1 do
  begin
    if Index > 0 then
      Result := Result + ',';

    Symbol := FSemanticModel.SymbolAt(Index);
    Fields := '';
    AppendJsonIntegerField(Fields, 'symbolId', Symbol.SymbolId, True);
    AppendJsonStringField(Fields, 'name', Symbol.Name);
    AppendJsonStringField(Fields, 'kind', Symbol.Kind);
    AppendJsonStringField(Fields, 'ownerUnitId', Symbol.OwnerUnitId);
    if (FUnitGraph <> nil) and
      FUnitGraph.FindUnit(Symbol.OwnerUnitId, UnitInfo) then
      AppendJsonStringField(Fields, 'ownerUnitName', UnitInfo.CanonicalName);
    AppendJsonIntegerField(Fields, 'scopeId', Symbol.ScopeId, True);
    if Symbol.ScopeId > 0 then
    begin
      Scope := FSemanticModel.ScopeAt(Symbol.ScopeId - 1);
      if Scope.ScopeId > 0 then
      begin
        AppendJsonStringField(
          Fields,
          'scopeKind',
          SemanticScopeKindName(Scope.Kind)
        );
        AppendJsonStringField(Fields, 'scopeName', Scope.Name);
        AppendJsonIntegerField(
          Fields,
          'scopeParentId',
          Scope.ParentScopeId,
          Scope.ParentScopeId > 0
        );
      end;
    end;
    AppendJsonIntegerField(Fields, 'typeId', Symbol.TypeId, True);
    if Symbol.TypeId > 0 then
    begin
      SymbolType := FSemanticModel.TypeAt(Symbol.TypeId - 1);
      if SymbolType.TypeId > 0 then
      begin
        AppendJsonStringField(Fields, 'typeName', SymbolType.Name);
        AppendJsonStringField(Fields, 'typeKind', SymbolType.Kind);
        AppendJsonIntegerField(
          Fields,
          'typeParentId',
          SymbolType.ParentTypeId,
          SymbolType.ParentTypeId > 0
        );
      end;
    end;
    AppendJsonIntegerField(
      Fields,
      'paramCount',
      Symbol.ParamCount,
      Symbol.ParamCount >= 0
    );
    if Symbol.ParamSignature <> '' then
      AppendJsonStringField(Fields, 'paramSignature', Symbol.ParamSignature);
    AppendJsonIntegerField(Fields, 'byteOffset', Symbol.ByteOffset, True);

    Result := Result + '{' + Fields + '}';
  end;
  Result := Result + ']';
end;

function TCompilationSession.BindingsJson: string;
var
  Binding: TSemanticBinding;
  Fields: string;
  Index: LongInt;
begin
  if FSemanticModel = nil then
    Exit('[]');

  Result := '[';
  for Index := 0 to FSemanticModel.BindingCount - 1 do
  begin
    if Index > 0 then
      Result := Result + ',';

    Binding := FSemanticModel.BindingAt(Index);
    Fields := '';
    AppendJsonIntegerField(Fields, 'bindingId', Binding.BindingId, True);
    AppendJsonStringField(Fields, 'kind', Binding.Kind);
    AppendJsonStringField(Fields, 'name', Binding.Name);
    AppendJsonStringField(Fields, 'ownerUnitId', Binding.OwnerUnitId);
    AppendJsonIntegerField(Fields, 'byteOffset', Binding.ByteOffset, True);
    AppendJsonIntegerField(
      Fields,
      'targetSymbolId',
      Binding.TargetSymbolId,
      True
    );

    Result := Result + '{' + Fields + '}';
  end;
  Result := Result + ']';
end;

function TCompilationSession.DefinitionsJson: string;
var
  Binding: TSemanticBinding;
  EntryJson: string;
  Fields: string;
  Index: LongInt;
  TargetSymbol: TSemanticSymbol;
  TargetUnit: TResolvedUnit;
begin
  if FSemanticModel = nil then
    Exit('[]');

  EntryJson := '';
  for Index := 0 to FSemanticModel.BindingCount - 1 do
  begin
    Binding := FSemanticModel.BindingAt(Index);
    if (Binding.TargetSymbolId <= 0) or
      (Binding.TargetSymbolId > FSemanticModel.SymbolCount) then
      Continue;

    TargetSymbol := FSemanticModel.SymbolAt(Binding.TargetSymbolId - 1);
    if TargetSymbol.SymbolId <> Binding.TargetSymbolId then
      Continue;

    if EntryJson <> '' then
      EntryJson := EntryJson + ',';

    Fields := '';
    AppendJsonIntegerField(Fields, 'bindingId', Binding.BindingId, True);
    AppendJsonStringField(Fields, 'bindingKind', Binding.Kind);
    AppendJsonStringField(Fields, 'bindingName', Binding.Name);
    AppendJsonStringField(Fields, 'bindingOwnerUnitId', Binding.OwnerUnitId);
    AppendJsonIntegerField(
      Fields,
      'bindingByteOffset',
      Binding.ByteOffset,
      True
    );
    AppendJsonIntegerField(
      Fields,
      'targetSymbolId',
      Binding.TargetSymbolId,
      True
    );
    AppendJsonStringField(Fields, 'targetName', TargetSymbol.Name);
    AppendJsonStringField(Fields, 'targetKind', TargetSymbol.Kind);
    AppendJsonIntegerField(
      Fields,
      'targetParamCount',
      TargetSymbol.ParamCount,
      TargetSymbol.ParamCount >= 0
    );
    if TargetSymbol.ParamSignature <> '' then
      AppendJsonStringField(
        Fields,
        'targetParamSignature',
        TargetSymbol.ParamSignature
      );
    AppendJsonStringField(
      Fields,
      'targetOwnerUnitId',
      TargetSymbol.OwnerUnitId
    );
    if (FUnitGraph <> nil) and
      FUnitGraph.FindUnit(TargetSymbol.OwnerUnitId, TargetUnit) then
    begin
      AppendJsonStringField(
        Fields,
        'targetOwnerUnitName',
        TargetUnit.CanonicalName
      );
      AppendJsonStringField(Fields, 'targetSourcePath', TargetUnit.SourcePath);
    end;
    AppendJsonIntegerField(
      Fields,
      'targetByteOffset',
      TargetSymbol.ByteOffset,
      True
    );

    EntryJson := EntryJson + '{' + Fields + '}';
  end;

  Result := '[' + EntryJson + ']';
end;

function TCompilationSession.ScopeCount: LongInt;
begin
  if FSemanticModel = nil then
    Exit(0);

  Result := FSemanticModel.ScopeCount;
end;

function TCompilationSession.ScopesJson: string;
var
  Fields: string;
  Index: LongInt;
  Scope: TSemanticScope;
begin
  if FSemanticModel = nil then
    Exit('[]');

  Result := '[';
  for Index := 0 to FSemanticModel.ScopeCount - 1 do
  begin
    if Index > 0 then
      Result := Result + ',';

    Scope := FSemanticModel.ScopeAt(Index);
    Fields := '';
    AppendJsonIntegerField(Fields, 'scopeId', Scope.ScopeId, True);
    AppendJsonStringField(Fields, 'kind', SemanticScopeKindName(Scope.Kind));
    AppendJsonStringField(Fields, 'name', Scope.Name);
    AppendJsonIntegerField(
      Fields,
      'parentScopeId',
      Scope.ParentScopeId,
      Scope.ParentScopeId > 0
    );

    Result := Result + '{' + Fields + '}';
  end;
  Result := Result + ']';
end;

function TCompilationSession.TypeCount: LongInt;
begin
  if FSemanticModel = nil then
    Exit(0);

  Result := FSemanticModel.TypeCount;
end;

function TCompilationSession.TypesJson: string;
var
  Fields: string;
  Index: LongInt;
  SymbolType: TSemanticType;
begin
  if FSemanticModel = nil then
    Exit('[]');

  Result := '[';
  for Index := 0 to FSemanticModel.TypeCount - 1 do
  begin
    if Index > 0 then
      Result := Result + ',';

    SymbolType := FSemanticModel.TypeAt(Index);
    Fields := '';
    AppendJsonIntegerField(Fields, 'typeId', SymbolType.TypeId, True);
    AppendJsonStringField(Fields, 'name', SymbolType.Name);
    AppendJsonStringField(Fields, 'kind', SymbolType.Kind);
    AppendJsonIntegerField(
      Fields,
      'parentTypeId',
      SymbolType.ParentTypeId,
      SymbolType.ParentTypeId > 0
    );

    Result := Result + '{' + Fields + '}';
  end;
  Result := Result + ']';
end;

function TCompilationSession.TypedHirNodeCount: LongInt;
begin
  if FSemanticModel = nil then
    Exit(0);

  Result := FSemanticModel.TypedHirNodeCount;
end;

function TCompilationSession.RuntimeContractCount: LongInt;
begin
  if FSemanticModel = nil then
    Exit(0);

  Result := FSemanticModel.RuntimeContractCount;
end;

function TCompilationSession.TypedHirRootName: string;
begin
  if FSemanticModel = nil then
    Exit('');

  Result := FSemanticModel.RootName;
end;

function TCompilationSession.MirBlockCount: LongInt;
begin
  Result := 0;
end;

function TCompilationSession.MirOperationCount: LongInt;
begin
  Result := 0;
end;

function TCompilationSession.MirEntryBlockLabel: string;
begin
  Result := '';
end;

function TCompilationSession.MirRootName: string;
begin
  if FSemanticModel = nil then
    Exit('');
  Result := FSemanticModel.RootName;
end;

function TCompilationSession.BackendOutputKind: string;
begin
  if FBackendPlan = nil then
    Exit('');

  Result := FBackendPlan.OutputKind;
end;

function TCompilationSession.BackendPrimaryArtifactKind: string;
begin
  if FBackendPlan = nil then
    Exit('');

  Result := FBackendPlan.PrimaryArtifactKind;
end;

function TCompilationSession.BackendPrimaryArtifactPath: string;
begin
  if FBackendPlan = nil then
    Exit('');

  Result := FBackendPlan.PrimaryArtifactPath;
end;

function TCompilationSession.BackendArtifactCount: LongInt;
begin
  if FBackendPlan = nil then
    Exit(0);

  Result := FBackendPlan.ArtifactCount;
end;

function TCompilationSession.BackendArtifactsJson: string;
begin
  if FBackendPlan = nil then
    Exit('');

  Result := FBackendPlan.ArtifactsJson;
end;

function TCompilationSession.HostId: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.HostId);

  Result := FTargetFacts.HostId;
end;

function TCompilationSession.ToolchainBindingId: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.ToolchainBindingId);

  Result := FTargetFacts.ToolchainBindingId;
end;

function TCompilationSession.BackendFamily: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.BackendFamily);

  Result := FTargetFacts.BackendFamily;
end;

function TCompilationSession.AssemblerProfileId: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.AssemblerProfileId);

  Result := FTargetFacts.AssemblerProfileId;
end;

function TCompilationSession.LinkerProfileId: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.LinkerProfileId);

  Result := FTargetFacts.LinkerProfileId;
end;

function TCompilationSession.ArchiverProfileId: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.ArchiverProfileId);

  Result := FTargetFacts.ArchiverProfileId;
end;

function TCompilationSession.ResourceToolProfileId: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.ResourceToolProfileId);

  Result := FTargetFacts.ResourceToolProfileId;
end;

function TCompilationSession.TargetObjectFormat: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.ObjectFormat);

  Result := FTargetFacts.ObjectFormat;
end;

function TCompilationSession.TargetAssemblerFlavor: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.AssemblerFlavor);

  Result := FTargetFacts.AssemblerFlavor;
end;

function TCompilationSession.TargetLinkerFlavor: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.LinkerFlavor);

  Result := FTargetFacts.LinkerFlavor;
end;

function TCompilationSession.TargetRuntimeLayoutKey: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.RuntimeLayoutKey);

  Result := FTargetFacts.RuntimeLayoutKey;
end;

function TCompilationSession.TargetCSymbolPrefix: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.TargetCSymbolPrefix);

  Result := FTargetFacts.CSymbolPrefix;
end;

function TCompilationSession.TargetCLibraryNaming: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.TargetCLibraryNaming);

  Result := FTargetFacts.CLibraryNaming;
end;

function TCompilationSession.TargetLlvmTriple: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.LlvmTriple);

  Result := FTargetFacts.LlvmTriple;
end;

function TCompilationSession.TargetLlvmDataLayout: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.LlvmDataLayout);

  Result := FTargetFacts.LlvmDataLayout;
end;

function TCompilationSession.SysrootMode: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.SysrootMode);

  Result := FTargetFacts.SysrootMode;
end;

function TCompilationSession.RuntimeSdkId: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.RuntimeSdkId);

  Result := FTargetFacts.RuntimeSdkId;
end;

function TCompilationSession.AllowHostFallback: Boolean;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.AllowHostFallback);

  Result := FTargetFacts.AllowHostFallback;
end;

function TCompilationSession.ToolRootKind: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.ToolRootKind);

  Result := FTargetFacts.ToolRootKind;
end;

function TCompilationSession.RuntimeRootKind: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.RuntimeRootKind);

  Result := FTargetFacts.RuntimeRootKind;
end;

function TCompilationSession.ResponseFilePolicy: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.ResponseFilePolicy);

  Result := FTargetFacts.ResponseFilePolicy;
end;

function TCompilationSession.LinkScriptPolicy: string;
begin
  if FBackendPlan <> nil then
    Exit(FBackendPlan.LinkScriptPolicy);

  Result := FTargetFacts.LinkScriptPolicy;
end;

function TCompilationSession.ToolchainPlanFamily: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PlanFamily;
end;

function TCompilationSession.ToolProfileRoot: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.ToolProfileRoot;
end;

function TCompilationSession.LogicalLinkRequestStatus: string;
begin
  if FToolchainPlan = nil then
    Exit('deferred');

  Result := FToolchainPlan.LogicalLinkRequestStatus;
end;

function TCompilationSession.LogicalLinkRequestOutputKind: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.LogicalLinkRequestOutputKind;
end;

function TCompilationSession.LogicalLibraryRequestCount: LongInt;
begin
  if FToolchainPlan = nil then
    Exit(0);

  Result := FToolchainPlan.LogicalLibraryRequestCount;
end;

function TCompilationSession.LogicalLinkRequestJson: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.LogicalLinkRequestJson;
end;

function TCompilationSession.LlvmToolchainStatus: string;
begin
  if FToolchainPlan = nil then
  begin
    if FTargetFacts.LlvmEnabled then
      Exit('deferred');
    Exit('disabled');
  end;

  Result := FToolchainPlan.LlvmToolchainStatus;
end;

function TCompilationSession.LlvmExecutableSetId: string;
begin
  if FToolchainPlan <> nil then
    Exit(FToolchainPlan.LlvmExecutableSetId);

  Result := FTargetFacts.LlvmExecutableSetId;
end;

function TCompilationSession.LlvmExecutableSetJson: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.LlvmExecutableSetJson;
end;

function TCompilationSession.PrimaryToolProfileId: string;
begin
  if FToolchainPlan = nil then
    Exit(FTargetFacts.HostCompilerProfileId);

  Result := FToolchainPlan.PrimaryToolProfileId;
end;

function TCompilationSession.PrimaryToolStepId: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PrimaryToolStepId;
end;

function TCompilationSession.PrimaryToolLogicalExecutable: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PrimaryToolLogicalExecutable;
end;

function TCompilationSession.PrimaryToolSysrootRef: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PrimaryToolSysrootRef;
end;

function TCompilationSession.PrimaryToolFailureMapping: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PrimaryToolFailureMapping;
end;

function TCompilationSession.PrimaryToolWorkingDirectory: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PrimaryToolWorkingDirectory;
end;

function TCompilationSession.PrimaryToolArgCount: LongInt;
begin
  if FToolchainPlan = nil then
    Exit(0);

  Result := FToolchainPlan.PrimaryToolArgCount;
end;

function TCompilationSession.PrimaryToolArgValue(const AIndex: LongInt): string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PrimaryToolArgValue(AIndex);
end;

function TCompilationSession.ToolInvocationCount: LongInt;
begin
  if FToolchainPlan = nil then
    Exit(0);

  Result := FToolchainPlan.ToolInvocationCount;
end;

function TCompilationSession.ToolRunStatus: string;
begin
  Result := FToolRunStatus;
end;

function TCompilationSession.ToolRunStepCount: LongInt;
begin
  Result := FToolRunStepCount;
end;

function TCompilationSession.PrimaryToolRunStatus: string;
begin
  Result := FPrimaryToolRunStatus;
end;

function TCompilationSession.PrimaryToolRole: string;
begin
  if FToolchainPlan = nil then
    Exit('');

  Result := FToolchainPlan.PrimaryToolRole;
end;

function TCompilationSession.SourceFileCount: LongInt;
begin
  Result := FSourceDatabase.FileCount;
end;

function TCompilationSession.DiagnosticsCount: LongInt;
begin
  Result := FDiagnosticsSink.TotalCount;
end;

function TCompilationSession.DiagnosticsErrorCount: LongInt;
begin
  Result := FDiagnosticsSink.ErrorCount;
end;

function TCompilationSession.DiagnosticsWarningCount: LongInt;
begin
  Result := FDiagnosticsSink.WarningCount;
end;

function TCompilationSession.DiagnosticsPolicyName: string;
begin
  Result := FDiagnosticsSink.PolicyName;
end;

function TCompilationSession.DiagnosticsJson: string;
begin
  Result := FDiagnosticsSink.DiagnosticsJson;
end;

function TCompilationSession.DiagnosticsSummary: string;
begin
  Result := FDiagnosticsSink.Summary;
end;

function TCompilationSession.ToolStatusEventCount: LongInt;
begin
  Result := Length(FToolStatusEvents);
end;

function TCompilationSession.ToolStatusEventsJson: string;
var
  EventFields: string;
  Index: SizeInt;
begin
  if Length(FToolStatusEvents) = 0 then
    Exit('');

  Result := '[';
  for Index := 0 to High(FToolStatusEvents) do
  begin
    if Index > 0 then
      Result := Result + ',';

    EventFields := '';
    AppendJsonField(
      EventFields,
      'eventKind',
      JsonString(FToolStatusEvents[Index].EventKind)
    );
    AppendJsonField(EventFields, 'sessionId', JsonString(FSessionId));
    AppendJsonField(EventFields, 'planId', JsonString(BuildTracePlanId));
    AppendJsonField(EventFields, 'bindingId', JsonString(ToolchainBindingId));
    AppendJsonField(EventFields, 'hostId', JsonString(HostId));
    AppendJsonField(EventFields, 'targetId', JsonString(FTargetFacts.TargetId));
    AppendJsonField(
      EventFields,
      'profileId',
      JsonString(FToolStatusEvents[Index].ProfileId)
    );
    AppendJsonField(
      EventFields,
      'stepId',
      JsonString(FToolStatusEvents[Index].StepId)
    );
    AppendJsonField(
      EventFields,
      'toolRole',
      JsonString(FToolStatusEvents[Index].ToolRole)
    );
    AppendJsonField(
      EventFields,
      'logicalExecutable',
      JsonString(FToolStatusEvents[Index].LogicalExecutable)
    );
    AppendJsonField(
      EventFields,
      'sysrootRef',
      JsonString(FToolStatusEvents[Index].SysrootRef)
    );
    if FToolStatusEvents[Index].ResolvedPath <> '' then
      AppendJsonField(
        EventFields,
        'resolvedPath',
        JsonString(FToolStatusEvents[Index].ResolvedPath)
      );
    if FToolStatusEvents[Index].Status <> '' then
      AppendJsonField(
        EventFields,
        'status',
        JsonString(FToolStatusEvents[Index].Status)
      );
    if FToolStatusEvents[Index].ResultValue <> '' then
      AppendJsonField(
        EventFields,
        'result',
        JsonString(FToolStatusEvents[Index].ResultValue)
      );
    if FToolStatusEvents[Index].HasExitCode then
      AppendJsonField(
        EventFields,
        'exitCode',
        IntToStr(FToolStatusEvents[Index].ExitCode)
      );
    if FToolStatusEvents[Index].Summary <> '' then
      AppendJsonField(
        EventFields,
        'summary',
        JsonString(FToolStatusEvents[Index].Summary)
      );
    Result := Result + '{' + EventFields + '}';
  end;
  Result := Result + ']';
end;

function TCompilationSession.ToolInvocationPlanRef: string;
begin
  if (FToolchainPlan = nil) or (FToolchainPlan.ToolInvocationCount = 0) then
    Exit('');

  Result := BuildTracePlanId;
end;

function TCompilationSession.ToolInvocationPlanJson: string;
begin
  if (FToolchainPlan = nil) or (FToolchainPlan.ToolInvocationCount = 0) then
    Exit('');

  Result := FToolchainPlan.ToolInvocationPlanJson(
    ToolInvocationPlanRef,
    PrimaryToolResolvedPath
  );
end;

function TCompilationSession.LastDiagnosticId: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticId;
end;

function TCompilationSession.LastDiagnosticCode: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticCode;
end;

function TCompilationSession.LastDiagnosticPhase: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticPhase;
end;

function TCompilationSession.LastDiagnosticMessage: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticMessage;
end;

function TCompilationSession.LastDiagnosticBindingId: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticBindingId;
end;

function TCompilationSession.LastDiagnosticProfileId: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticProfileId;
end;

function TCompilationSession.LastDiagnosticStepId: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticStepId;
end;

function TCompilationSession.LastDiagnosticLogicalExecutable: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticLogicalExecutable;
end;

function TCompilationSession.LastDiagnosticSysrootRef: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticSysrootRef;
end;

function TCompilationSession.LastDiagnosticResolvedPath: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticResolvedPath;
end;

function TCompilationSession.LastDiagnosticPrimaryArtifactKind: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticPrimaryArtifactKind;
end;

function TCompilationSession.LastDiagnosticPrimaryArtifactPath: string;
begin
  Result := FDiagnosticsSink.LastDiagnosticPrimaryArtifactPath;
end;

function TCompilationSession.LastDiagnosticExitCode: LongInt;
begin
  Result := FDiagnosticsSink.LastDiagnosticExitCode;
end;

function TCompilationSession.HasLastDiagnosticExitCode: Boolean;
begin
  Result := FDiagnosticsSink.HasLastDiagnosticExitCode;
end;

function TCompilationSession.BuildTraceRef: string;
begin
  Result := FBuildTraceRef;
end;

function TCompilationSession.BuildTraceJson: string;
begin
  Result := FBuildTraceJson;
end;

function TCompilationSession.SessionLifetimeSummary: string;
begin
  Result := 'source-db,target-facts,diagnostics-sink,compilation-options';
end;

function TCompilationSession.UnitLifetimeSummary: string;
begin
  Result := 'root-input-state';
end;

function TCompilationSession.StageLifetimeSummary: string;
begin
  Result :=
    'syntax:' + FSyntaxStatus +
    ',resolution:' + FResolutionStatus +
    ',sema:' + FSemanticStatus +
    ',ir:' + FMirStatus +
    ',backend:' + FBackendStatus +
    ',toolchain:' + FToolchainStatus;
end;

end.
