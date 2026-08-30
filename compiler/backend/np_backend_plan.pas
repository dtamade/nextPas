unit np_backend_plan;

{$mode objfpc}{$H+}
{$UNITPATH ../ir}
{$UNITPATH ../targets}
{$UNITPATH ../diagnostics}
{$UNITPATH ../frontend}
{$UNITPATH ../../core/src}
{ backend layer: depends on ir/frontend, not sema direct — uses view intf }

interface

uses
  nextpas.core.collections.vec,
  nextpas.core.mem.intf, nextpas.core.compiler.mem,
  np_target_facts,
  np_mir_model,
  np_backend_view_intf;

type
  TBackendArtifact = record
    ArtifactId: LongInt;
    Kind: string;
    Path: string;
  end;

  TBackendLogicalLibraryRequest = record
    RequestId: LongInt;
    LogicalId: string;
    LinkageKind: string;
    Strength: string;
  end;

  TBackendArtifactVec = specialize TVec<TBackendArtifact>;
  TBackendLogicalLibraryRequestVec = specialize TVec<TBackendLogicalLibraryRequest>;

  TBackendPlan = class
  private
    FArtifacts: TBackendArtifactVec;
    FLogicalLibraryRequests: TBackendLogicalLibraryRequestVec;
    FStatus: string;
    FRootName: string;
    FOutputKind: string;
    FPrimaryArtifactKind: string;
    FPrimaryArtifactPath: string;
    FHostId: string;
    FToolchainBindingId: string;
    FHostCompilerProfileId: string;
    FBackendFamily: string;
    FAssemblerProfileId: string;
    FLinkerProfileId: string;
    FArchiverProfileId: string;
    FResourceToolProfileId: string;
    FObjectFormat: string;
    FAssemblerFlavor: string;
    FLinkerFlavor: string;
    FRuntimeLayoutKey: string;
    FTargetCSymbolPrefix: string;
    FTargetCLibraryNaming: string;
    FLlvmTriple: string;
    FLlvmDataLayout: string;
    FSysrootMode: string;
    FRuntimeSdkId: string;
    FAllowHostFallback: Boolean;
    FToolRootKind: string;
    FRuntimeRootKind: string;
    FResponseFilePolicy: string;
    FLinkScriptPolicy: string;
    FLlvmEnabled: Boolean;
    FLlvmExecutableSetId: string;
  public
    constructor Create;
    destructor Destroy; override;
    function AddArtifact(const AKind: string; const APath: string): LongInt;
    function ArtifactCount: LongInt;
    function ArtifactAt(const AIndex: LongInt): TBackendArtifact;
    function ArtifactPathByKind(const AKind: string): string;
    function ArtifactsJson: string;
    function AddLogicalLibraryRequest(
      const ALogicalId: string;
      const ALinkageKind: string;
      const AStrength: string
    ): LongInt;
    function LogicalLibraryRequestCount: LongInt;
    function LogicalLibraryRequestAt(
      const AIndex: LongInt
    ): TBackendLogicalLibraryRequest;
    procedure SetRootName(const AName: string);
    function RootName: string;
    procedure SetOutputKind(const AKind: string);
    function OutputKind: string;
    procedure SetPrimaryArtifact(const AKind: string; const APath: string);
    function PrimaryArtifactKind: string;
    function PrimaryArtifactPath: string;
    procedure SetTargetMetadata(const ATargetFacts: TTargetFactsView);
    function HostId: string;
    function ToolchainBindingId: string;
    function HostCompilerProfileId: string;
    function BackendFamily: string;
    function AssemblerProfileId: string;
    function LinkerProfileId: string;
    function ArchiverProfileId: string;
    function ResourceToolProfileId: string;
    function ObjectFormat: string;
    function AssemblerFlavor: string;
    function LinkerFlavor: string;
    function RuntimeLayoutKey: string;
    function TargetCSymbolPrefix: string;
    function TargetCLibraryNaming: string;
    function LlvmTriple: string;
    function LlvmDataLayout: string;
    function SysrootMode: string;
    function RuntimeSdkId: string;
    function AllowHostFallback: Boolean;
    function ToolRootKind: string;
    function RuntimeRootKind: string;
    function ResponseFilePolicy: string;
    function LinkScriptPolicy: string;
    function LlvmEnabled: Boolean;
    function LlvmExecutableSetId: string;
    procedure MarkReady;
    procedure MarkFailure;
    function Status: string;
  end;

  TBackendPlanner = class
  private
    FSemanticView: IBackendSemanticView;
    FRootNameCache: string;
    FTargetFacts: TTargetFactsView;
    FSourcePath: string;
    FArtifactRootPath: string;
    FOutputDirPath: string;
    FRootKindName: string;
    FNoFold: Boolean;
    FOptLevel: string;
    FPlan: TBackendPlan;
    function BackendIntermediateRootPath: string;
  public
    constructor Create(
      const ASemanticView: IBackendSemanticView;
      const ATargetFacts: TTargetFactsView;
      const ASourcePath: string;
      const AArtifactRootPath: string;
      const AOutputDirPath: string;
      const ARootKindName: string;
      const ANoFold: Boolean;
      const AOptLevel: string
    );
    { Legacy overload for transition — wraps RootName into view adapter }
    constructor CreateWithRootName(
      const ARootName: string;
      const ATargetFacts: TTargetFactsView;
      const ASourcePath: string;
      const AArtifactRootPath: string;
      const AOutputDirPath: string;
      const ARootKindName: string;
      const ANoFold: Boolean;
      const AOptLevel: string
    );
    destructor Destroy; override;
    procedure Plan;
    function DetachPlan: TBackendPlan;
  end;

implementation

uses
  nextpas.core.text.conv, nextpas.core.path, nextpas.core.fs.dir, nextpas.core.os.env,
  np_hir_types, np_hir_model, np_hir_builder,
  np_hir_llvm_emitter, nextpas_json_helpers,
  np_hir_to_mir, np_mir_to_llvm,
  np_mir_optimize, np_mir_pass_registry;

constructor TBackendPlan.Create;
begin
  inherited Create;
  FArtifacts := TBackendArtifactVec.Create;
  FLogicalLibraryRequests := TBackendLogicalLibraryRequestVec.Create;
  FStatus := 'deferred';
  FRootName := '';
  FOutputKind := '';
  FPrimaryArtifactKind := '';
  FPrimaryArtifactPath := '';
  FHostId := '';
  FToolchainBindingId := '';
  FHostCompilerProfileId := '';
  FBackendFamily := '';
  FAssemblerProfileId := '';
  FLinkerProfileId := '';
  FArchiverProfileId := '';
  FResourceToolProfileId := '';
  FObjectFormat := '';
  FAssemblerFlavor := '';
  FLinkerFlavor := '';
  FRuntimeLayoutKey := '';
  FTargetCSymbolPrefix := '';
  FTargetCLibraryNaming := '';
  FLlvmTriple := '';
  FLlvmDataLayout := '';
  FSysrootMode := '';
  FRuntimeSdkId := '';
  FAllowHostFallback := False;
  FToolRootKind := '';
  FRuntimeRootKind := '';
  FResponseFilePolicy := '';
  FLinkScriptPolicy := '';
  FLlvmEnabled := False;
  FLlvmExecutableSetId := '';
end;

destructor TBackendPlan.Destroy;
begin
  FLogicalLibraryRequests.Free;
  FLogicalLibraryRequests := nil;
  FArtifacts.Free;
  FArtifacts := nil;
  inherited Destroy;
end;

{$I np_backend_plan_accessors.inc}
function TBackendPlanner.BackendIntermediateRootPath: string;
begin
  if Trim(FArtifactRootPath) <> '' then
    Exit(
      ExpandFileName(
        IncludeTrailingPathDelimiter(FArtifactRootPath) + 'cache' +
        DirectorySeparator + 'backend' + DirectorySeparator +
        FTargetFacts.TargetId
      )
    );

  if Trim(FOutputDirPath) <> '' then
    Exit(ExpandFileName(FOutputDirPath));

  Result := ExtractFileDir(ExpandFileName(FSourcePath));
end;

procedure TBackendPlanner.Plan;
var
  AssemblyArtifactPath: string;
  BaseName: string;
  BitcodeArtifactPath: string;
  HirBuilder: THIRBuilder;
  HirEmitter: THIRLlvmEmitter;
  Lowering: THirToMirLowering;
  LlvmTranslator: TMirToLlvmTranslator;
  MirModule: TMirModule;
  PassManager: TMirPassManager;
  IntermediateRoot: string;
  LlvmIrArtifactPath: string;
  ObjectArtifactPath: string;
  OutputKindValue: string;
  PrimaryArtifactKindValue: string;
  PrimaryArtifactPath: string;
  PhaseScratch: IAllocator;
begin
  if FSemaModel = nil then
  begin
    FPlan.MarkFailure;
    Exit;
  end;

  FPlan.SetRootName(FSemaModel.RootName);
  FPlan.SetTargetMetadata(FTargetFacts);
  OutputKindValue := 'executable';
  PrimaryArtifactKindValue := 'executable';
  if SameText(Trim(FRootKindName), 'unit') then
  begin
    OutputKindValue := 'object-file';
    PrimaryArtifactKindValue := 'object-file';
  end;
  FPlan.SetOutputKind(OutputKindValue);
  BaseName := ChangeFileExt(ExtractFileName(FSourcePath), '');
  IntermediateRoot := BackendIntermediateRootPath;
  AssemblyArtifactPath := ExpandFileName(
    IncludeTrailingPathDelimiter(IntermediateRoot) + BaseName + '.s'
  );
  ObjectArtifactPath := ExpandFileName(
    IncludeTrailingPathDelimiter(IntermediateRoot) + BaseName + '.o'
  );
  if SameText(OutputKindValue, 'object-file') then
  begin
    if Trim(FOutputDirPath) <> '' then
      ObjectArtifactPath := ExpandFileName(
        IncludeTrailingPathDelimiter(FOutputDirPath) +
        BaseName + '.o'
      );
    PrimaryArtifactPath := ObjectArtifactPath;
  end
  else if Trim(FOutputDirPath) <> '' then
    PrimaryArtifactPath := ExpandFileName(
      IncludeTrailingPathDelimiter(FOutputDirPath) +
      BaseName
    )
  else
    PrimaryArtifactPath := ChangeFileExt(FSourcePath, '');

  if SameText(FTargetFacts.BackendFamily, 'llvm') then
  begin
    LlvmIrArtifactPath := ExpandFileName(
      IncludeTrailingPathDelimiter(IntermediateRoot) + BaseName + '.ll'
    );
    BitcodeArtifactPath := ExpandFileName(
      IncludeTrailingPathDelimiter(IntermediateRoot) + BaseName + '.bc'
    );
    FPlan.AddArtifact('llvm-ir', LlvmIrArtifactPath);
    FPlan.AddArtifact('llvm-bitcode', BitcodeArtifactPath);

    { FsMkdirAll is procedure (INV-5): failure raises; map to plan failure. }
    try
      FsMkdirAll(IntermediateRoot);
    except
      FPlan.MarkFailure;
      Exit;
    end;

    { Phase scratch for HIR builder / MIR value-map working storage.
      MIR/HIR modules themselves stay on the default heap. }
    PhaseScratch := CompilerCreateUnitAllocator;
    try
      HirBuilder := THIRBuilder.Create(FSemaModel, nil, 0, PhaseScratch);
      try
        HirBuilder.Build;
        if GetEnvironmentVariable('NEXTPAS_MIR') = '1' then
        begin
          { Opt-in: HIR -> MIR -> MIR passes -> LLVM IR pipeline }
          Lowering := THirToMirLowering.Create(HirBuilder.Module, PhaseScratch);
          try
            Lowering.Lower;
            MirModule := Lowering.DetachModule;
          finally
            Lowering.Free;
          end;

          { Run MIR optimization passes; registry TVec on PhaseScratch }
          if not FNoFold then
          begin
            PassManager := TMirPassManager.Create(PhaseScratch);
            try
              RegisterMirPassesForLevel(PassManager, FOptLevel);
              PassManager.RunAll(MirModule);
            finally
              PassManager.Free;
            end;
          end;

          { MIR→LLVM output lines on PhaseScratch TVec }
          LlvmTranslator := TMirToLlvmTranslator.Create(MirModule, PhaseScratch);
          try
            LlvmTranslator.SaveToFile(LlvmIrArtifactPath);
          finally
            LlvmTranslator.Free;
          end;
        end
        else
        begin
          { Default: HIR -> LLVM IR direct path; lines/refs on PhaseScratch }
          HirEmitter := THIRLlvmEmitter.Create(HirBuilder.Module,
            FTargetFacts.LlvmTriple, FTargetFacts.LlvmDataLayout,
            False, PhaseScratch);
          try
            HirEmitter.EmitModule;
            HirEmitter.SaveToFile(LlvmIrArtifactPath);
          finally
            HirEmitter.Free;
          end;
        end;
      finally
        HirBuilder.Free;
      end;
    finally
      PhaseScratch := nil;
    end;
  end
  else
    FPlan.AddArtifact('assembly-text', AssemblyArtifactPath);

  FPlan.AddArtifact('object-file', ObjectArtifactPath);
  if SameText(OutputKindValue, 'executable') then
    FPlan.AddArtifact('executable', PrimaryArtifactPath);
  FPlan.SetPrimaryArtifact(PrimaryArtifactKindValue, PrimaryArtifactPath);
  FPlan.MarkReady;
end;

function TBackendPlanner.DetachPlan: TBackendPlan;
begin
  Result := FPlan;
  FPlan := nil;
end;

end.
