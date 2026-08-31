unit np_compilation_session;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../backend}
{$UNITPATH ../diagnostics}
{$UNITPATH ../ir}
{$UNITPATH ../lower}
{$UNITPATH ../sema}
{$UNITPATH ../syntax}
{$UNITPATH ../toolchain}
{$UNITPATH ../targets}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.core.collections.vec,
  nextpas.core.compiler.mem,
  nextpas.core.mem.intf, nextpas.core.mem.allocator.arena,
  np_ast_facade, np_backend_plan, np_diagnostics_sink, np_green_tree,
  np_lexer, np_source_database, np_target_facts,
  np_toolchain_plan, np_toolchain_runner,
  np_unit_graph, np_unit_resolver,
  np_semantic_model, np_workspace_model,
  np_compiler_phase, np_mir_model,
  np_query_database,
  np_file_change_detector,
  np_parallel_scheduler,
  np_incremental_cache;

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

  { Session-long tool events (outlive phase scratch Reset) — default-heap TVec. }
  TToolStatusEventVec = specialize TVec<TToolStatusEventRecord>;

  TCompilationSession = class
  private
    FSessionId: string;
    { Session-owned VirtualArena (compiler.mem). AnalyzeSyntax/ResolveUnits
      call UnitBegin + MemAlloc phase scratch + UnitEnd; do not FreeMem. }
    FMemScope: TCompilerSessionScope;
    { Session AST node storage (VirtualArena IAllocator). Not reset by UnitBegin;
      Reset on syntax reparse / session end. GreenTree TVec grows via alloc+copy. }
    FAstAllocator: IAllocator;
    { Phase scratch IAllocator (resolver dep trees, analyzer TVecs, HIR/MIR
      working maps). Reset after each consumer phase; independent of FAstAllocator. }
    FScratchAllocator: IAllocator;
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
    FIncrementalCache: TIncrementalCache;
    FMirModule: TMirModule;
    FMirStatus: string;
    FBackendPlan: TBackendPlan;
    FBackendStatus: string;
    FToolchainPlan: TToolchainPlan;
    FToolchainStatus: string;
    FToolRunStatus: string;
    FToolRunStepCount: LongInt;
    FPrimaryToolRunStatus: string;
    FToolStatusEvents: TToolStatusEventVec;
    FBuildTraceRef: string;
    FBuildTraceJson: string;
    procedure ResetScratchAllocator;
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
    {** Session VirtualArena scope active (compiler.mem product wire). }
    function MemScopeActive: Boolean;
    {** Peak across UnitBegin/UnitEnd (updated by AnalyzeSyntax/ResolveUnits). }
    function MemSessionPeak: SizeUInt;
    {** Units that called UnitBegin this session. }
    function MemUnitCount: SizeUInt;
    {** Current session arena used bytes (0 after UnitEnd Reset of next begin). }
    function MemTotalUsed: SizeUInt;
    {** Scratch alloc from session arena; nil if inactive. Do not FreeMem. }
    function MemAlloc(const ASize: SizeUInt): Pointer;
    {** Session AST IAllocator (VirtualArena); used by ParseGreenTree. }
    function MemAstAllocator: IAllocator;
    {** Phase scratch IAllocator (resolver/sema working storage). }
    function MemScratchAllocator: IAllocator;
    {** One-line session mem diagnostics (units/peak/ast/scratch). }
    function MemFormatSessionStats: string;
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

uses
  nextpas.core.text.conv, nextpas.core.path, nextpas.core.os.env,
  nextpas.core.time, nextpas.core.base.utils,
  np_preprocessor, np_hir_types, np_hir_model, np_hir_builder,
  np_hir_printer, np_hir_llvm_emitter, np_toolchain_profiles,
  np_semantic_analyzer, np_hir_to_mir, np_mir_optimize,
  np_mir_to_llvm, nextpas_json_helpers;

{$I np_compilation_session_helpers.inc}

{$I np_compilation_session_pipeline.inc}
{$I np_compilation_session_toolchain.inc}
{$I np_compilation_session_accessors.inc}

end.
