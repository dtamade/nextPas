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
  nextpas.core.text, nextpas.core.text.conv, nextpas.core.path, nextpas.core.os.env,
  nextpas.core.time, nextpas.core.base.utils,
  np_ast_facade, np_backend_plan, np_diagnostics_sink, np_green_tree,
  np_lexer, np_preprocessor, np_hir_types, np_hir_model, np_hir_builder,
  np_hir_printer, np_hir_llvm_emitter, np_source_database, np_target_facts,
  np_toolchain_plan, np_toolchain_profiles, np_toolchain_runner,
  np_unit_graph, np_unit_resolver,
  np_semantic_model, np_semantic_analyzer, np_workspace_model,
  np_compiler_phase, np_mir_model, np_hir_to_mir, np_mir_optimize,
  np_query_database,
  np_file_change_detector,
  np_parallel_scheduler,
  np_mir_to_llvm, nextpas_json_helpers;

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
    Incremental: Boolean;
    OptLevel: string;  { O0/O1/O2 — MIR optimization level }
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
    FQueryDB: TQueryDatabase;
    FFileDetector: TFileChangeDetector;
    FScheduler: TParallelScheduler;
    FMirModule: TMirModule;
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

    { Incremental compilation: check for file changes and invalidate caches }
    function PrepareIncrementalBuild: Boolean;
    function GetScheduler: TParallelScheduler;

    { Take snapshot after successful build }
    procedure FinalizeIncrementalBuild;
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
    function MirModule: TMirModule;
    function BackendPlanStatus: string;
    // Pipeline phase status helpers (ICompilerPhase integration)
    function PhaseStatusOf(const AStatus: string): TPhaseStatus;
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
    property Scheduler: TParallelScheduler read GetScheduler;
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
  EntropyToken := FormatDateTime('yyyymmddhhnnsszzz', DateTimeNow) + '-' +
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
  FQueryDB := TQueryDatabase.Create;
  FFileDetector := TFileChangeDetector.Create;
  FScheduler := nil;  { Created on-demand for parallel builds }
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
  FMirModule.Free;
  FSemanticModel.Free;
  FUnitGraph.Free;
  FSearchPathSet.Free;
  FAstFacade.Free;
  FGreenTree.Free;
  FLexerResult.Free;
  FDiagnosticsSink.Free;
  FSourceDatabase.Free;
  if FScheduler <> nil then FScheduler.Free;
  FFileDetector.Free;
  FQueryDB.Free;
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
  FreeAndNil(FMirModule);
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
      nextpas.core.text.SameText(FToolStatusEvents[Index].StepId, PrimaryToolStepId) then
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
      if nextpas.core.text.SameText(Result[ExistingIndex], ABaseName) then
        Exit;
    NextIndex := Length(Result);
    SetLength(Result, NextIndex + 1);
    Result[NextIndex] := ABaseName;
  end;
begin
  SetLength(Result, 0);
  if FUnitGraph = nil then
    Exit;
  if nextpas.core.text.SameText(AstRootKindName, 'unit') then
    Exit;

  ResolvedSourcePath := ExpandFileName(FOptions.BuildContext.ResolvedSourcePath);
  for Index := 0 to FUnitGraph.ResolvedUnitCount - 1 do
  begin
    ResolvedUnit := FUnitGraph.ResolvedUnitAt(Index);
    if Trim(ResolvedUnit.SourcePath) = '' then
      Continue;
    if nextpas.core.text.SameText(ResolvedUnit.OriginClass, 'implicit-runtime') then
      Continue;
    if nextpas.core.text.SameText(ExpandFileName(ResolvedUnit.SourcePath), ResolvedSourcePath) then
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
    if nextpas.core.text.SameText(FToolchainPlan.StepAt(Index).StepId, AStepId) then
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
    if nextpas.core.text.SameText(ExecutedStep.StepId, AFailedStepId) then
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

function TCompilationSession.GetScheduler: TParallelScheduler;
begin
  if FScheduler = nil then
    FScheduler := TParallelScheduler.Create;
  Result := FScheduler;
end;

function TCompilationSession.PrepareIncrementalBuild: Boolean;
var
  RootPath: string;
  Changed: TStringArray;
  I: LongInt;
begin
  Result := True;
  RootPath := FSourceDatabase.RootSourceCanonicalPath;

  { First build: no snapshots yet }
  if FFileDetector.SnapshotCount = 0 then
    Exit;

  { Check if any tracked file changed }
  if not FFileDetector.AnyChanged then
  begin
    { Nothing changed — all queries still valid }
    Exit;
  end;

  { Something changed — invalidate affected queries }
  Changed := FFileDetector.ChangedFiles;
  for I := 0 to Length(Changed) - 1 do
  begin
    FQueryDB.InvalidatePrefix('parse:' + Changed[I]);
    FQueryDB.InvalidatePrefix('semantic:' + Changed[I]);
  end;

  { Reset state for recompilation }
  Result := True;
end;

procedure TCompilationSession.FinalizeIncrementalBuild;
var
  RootPath: string;
begin
  RootPath := FSourceDatabase.RootSourceCanonicalPath;
  FFileDetector.TakeSnapshot(RootPath, []);
end;

procedure TCompilationSession.AnalyzeSyntax;
var
  RawLexer: TLexerResult;
  PP: TPreprocessor;
  Defines: TDefineTable;
  IncResolver: TFileIncludeResolver;
  SourceDir: string;
begin
  ResetSyntaxState;
  RawLexer := TLexerResult.Create(FSourceDatabase.RootSourceText,
    FDiagnosticsSink, FRootFileId);
  Defines := TDefineTable.Create;
  Defines.SeedFPCDefines;
  SourceDir := ExtractFileDir(FSourceDatabase.RootSourceCanonicalPath);
  IncResolver := TFileIncludeResolver.Create(SourceDir);
  IncResolver.AddSearchPath(SourceDir);
  PP := TPreprocessor.Create(Defines, True, IncResolver);
  PP.Process(RawLexer);
  FLexerResult := PP.ToLexerResult;
  PP.Free;
  RawLexer.Free;
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
  CacheKey: string;
  CachedModel: TObject;
begin
  { Query cache: if we already analyzed this file, skip }
  CacheKey := 'semantic:' + FSourceDatabase.RootSourceCanonicalPath;
  CachedModel := FQueryDB.Get(CacheKey, nil);
  if (CachedModel <> nil) and (CachedModel is TSemanticModel) then
  begin
    FSemanticModel := TSemanticModel(CachedModel);
    FSemanticStatus := FSemanticModel.Status;
    { Do NOT call ResetSemanticState — it would free the cached model }
    Exit;
  end;

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
    begin
      FSemanticStatus := FSemanticModel.Status;
      { Cache for incremental compilation — query DB owns the reference }
      if FSemanticStatus = 'ready' then
        FQueryDB.Store(CacheKey, FSemanticModel);
    end;
  finally
    Analyzer.Free;
  end;
end;

procedure TCompilationSession.LowerToMir;
var
  HirBuilder: THIRBuilder;
  HirPrinter: THIRPrinter;
  HirPath: string;
  Lowering: THirToMirLowering;
  LlvmTranslator: TMirToLlvmTranslator;
  LlvmOutput: string;
begin
  ResetIrState;
  if (FSemanticModel = nil) or (FSemanticStatus <> 'ready') then
  begin
    FMirStatus := 'failure';
    Exit;
  end;

  FMirStatus := 'ready';

  // MIR lowering is enabled via NEXTPAS_MIR=1 env var (opt-in during development)
  if GetEnvironmentVariable('NEXTPAS_MIR') = '1' then
  begin
    HirBuilder := THIRBuilder.Create(FSemanticModel, FSourceDatabase, FRootFileId);
    try
      HirBuilder.Build;

      Lowering := THirToMirLowering.Create(HirBuilder.Module);
      try
        Lowering.Lower;
        FMirModule := Lowering.DetachModule;
      finally
        Lowering.Free;
      end;

      if GetEnvironmentVariable('NEXTPAS_MIR_DUMP') = '1' then
      begin
        LlvmTranslator := TMirToLlvmTranslator.Create(FMirModule);
        try
          LlvmOutput := LlvmTranslator.Translate;
        finally
          LlvmTranslator.Free;
        end;
      end;
    finally
      HirBuilder.Free;
    end;
  end
  else if GetEnvironmentVariable('NEXTPAS_HIR_DUMP') = '1' then
  begin
    HirBuilder := THIRBuilder.Create(FSemanticModel, FSourceDatabase, FRootFileId);
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
    FOptions.NoFold,
    FOptions.OptLevel
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

{$I np_compilation_session_accessors.inc}

end.
